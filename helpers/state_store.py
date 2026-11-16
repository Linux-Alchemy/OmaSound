"""Versioned fixture snapshot store; standard library, no audio access."""
from contextlib import contextmanager
import fcntl
import json
import math
import os
from pathlib import Path
import re
import stat
import time
import unicodedata
import uuid

MAX_BYTES = 1024 * 1024
MAX_PROFILES = 256
MAX_INT = 9007199254740991
SIDES = ('input', 'output')
FACTORIES = {'factory-fixture-gaming': 'Fixture Gaming', 'factory-fixture-music': 'Fixture Music'}


class StoreError(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def require(condition):
    if not condition:
        raise StoreError('invalid')


def keys(value, required, optional=()):
    require(type(value) is dict and set(required) <= value.keys() and value.keys() <= set(required) | set(optional))


def integer(value, minimum=0):
    require(type(value) is int and minimum <= value <= MAX_INT)


def name(value):
    require(type(value) is str and 1 <= len(value) <= 64)
    require(value == unicodedata.normalize('NFC', value.strip()))
    require(not any(ord(c) < 32 or 127 <= ord(c) <= 159 or 0xD800 <= ord(c) <= 0xDFFF for c in value))


def identity(value, origin=None):
    require(type(value) is str and re.fullmatch(r'(custom|factory)-[a-zA-Z0-9-]{1,72}', value) is not None)
    if origin:
        require(value.startswith(origin + '-'))


def eq(value):
    keys(value, ('enabled', 'gains'))
    require(type(value['enabled']) is bool and type(value['gains']) is list and len(value['gains']) == 10)
    require(all(type(v) in (int, float) and math.isfinite(v) and -12 <= v <= 12 for v in value['gains']))


def validate(value):
    keys(value, ('profiles', 'effective'))
    require(type(value['profiles']) is list and len(value['profiles']) <= MAX_PROFILES)
    ids, names = set(FACTORIES), {n.lower() for n in FACTORIES.values()}
    for p in value['profiles']:
        keys(p, ('schemaVersion', 'bandSchema', 'id', 'revision', 'origin', 'name'), SIDES)
        require(type(p['schemaVersion']) is int and p['schemaVersion'] == 1 and p['bandSchema'] == 'ten-band-v1' and p['origin'] == 'custom')
        identity(p['id'], 'custom'); integer(p['revision'], 1); name(p['name'])
        require(p['id'] not in ids and p['name'].lower() not in names)
        ids.add(p['id']); names.add(p['name'].lower())
        require(any(s in p for s in SIDES))
        for side in SIDES:
            if side in p:
                eq(p[side])
    keys(value['effective'], SIDES)
    for side in SIDES:
        row = value['effective'][side]
        keys(row, ('eq', 'source')); eq(row['eq'])
        source = row['source']
        if source is not None:
            keys(source, ('id', 'revision', 'name'))
            identity(source['id']); integer(source['revision'], 1); name(source['name'])
            # Provenance can refer to an older revision after editing one side.
            require(source['id'] in ids)
    encode(value)
    return value


def encode(value):
    data = json.dumps(value, ensure_ascii=True, allow_nan=False, separators=(',', ':')).encode('ascii')
    if len(data) > MAX_BYTES:
        raise StoreError('oversized')
    return data


def parse(data):
    if len(data) > MAX_BYTES:
        raise StoreError('oversized')
    def pairs(items):
        result = {}
        for k, v in items:
            require(k not in result)
            result[k] = v
        return result
    try:
        return json.loads(data, object_pairs_hook=pairs, parse_constant=lambda _: (_ for _ in ()).throw(StoreError('invalid')))
    except (ValueError, UnicodeError, RecursionError):
        raise StoreError('invalid') from None


def snapshot(value):
    keys(value, ('version', 'revision', 'transaction', 'value'))
    require(type(value['version']) is int and value['version'] == 1)
    integer(value['revision'], 1)
    transaction(value['transaction']); validate(value['value'])
    return value


def transaction(value):
    require(type(value) is str and re.fullmatch(r'[a-zA-Z0-9-]{1,96}', value) is not None)


def private(info, directory=False):
    expected = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or (not directory and info.st_nlink != 1):
        raise StoreError('unsafe')


class StateStore:
    def __init__(self, root):
        self.root = Path(root)

    @contextmanager
    def locked(self):
        # Parent is the user's chosen XDG location. Own only the final directory.
        self.root.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        try:
            self.root.mkdir(mode=0o700)
            parent = os.open(self.root.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(parent)
            finally:
                os.close(parent)
        except FileExistsError:
            pass
        fd = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        lock = None
        try:
            private(os.fstat(fd), directory=True)
            lock = os.open('lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600, dir_fd=fd)
            private(os.fstat(lock))
            deadline = time.monotonic() + 1
            while True:
                try:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    if time.monotonic() >= deadline:
                        raise StoreError('busy') from None
                    time.sleep(.02)
            yield fd
        finally:
            if lock is not None:
                os.close(lock)
            os.close(fd)

    def read(self, directory):
        try:
            fd = os.open('state.json', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        except FileNotFoundError:
            return None
        try:
            info = os.fstat(fd); private(info)
            if info.st_size > MAX_BYTES:
                raise StoreError('oversized')
            with os.fdopen(fd, 'rb', closefd=False) as stream:
                return snapshot(parse(stream.read(MAX_BYTES + 1)))
        finally:
            os.close(fd)

    def load(self):
        with self.locked() as directory:
            value = self.read(directory)
            return {'ok': True, 'status': 'loaded' if value else 'absent', 'snapshot': value}

    def commit(self, expected, tx, value):
        integer(expected); transaction(tx); validate(value)
        with self.locked() as directory:
            previous = self.read(directory)
            if previous and previous['transaction'] == tx:
                require(previous['value'] == value and previous['revision'] == expected + 1)
                try:
                    os.fsync(directory)
                except OSError:
                    raise StoreError('uncertain') from None
                return {'ok': True, 'status': 'committed', 'revision': previous['revision'], 'transaction': tx}
            revision = previous['revision'] if previous else 0
            if expected != revision:
                raise StoreError('conflict')
            integer(revision + 1, 1)
            document = {'version': 1, 'revision': revision + 1, 'transaction': tx, 'value': value}
            data = encode(document)
            temporary = '.pending-' + uuid.uuid4().hex
            published = False
            fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=directory)
            try:
                with os.fdopen(fd, 'wb') as stream:
                    stream.write(data); stream.flush(); os.fsync(stream.fileno())
                os.replace(temporary, 'state.json', src_dir_fd=directory, dst_dir_fd=directory)
                published = True
                os.fsync(directory)
            except OSError:
                raise StoreError('uncertain' if published else 'unavailable') from None
            finally:
                if not published:
                    try:
                        os.unlink(temporary, dir_fd=directory)
                    except FileNotFoundError:
                        pass
            return {'ok': True, 'status': 'committed', 'revision': revision + 1, 'transaction': tx}
