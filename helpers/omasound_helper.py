#!/usr/bin/env python3
"""One bounded fixture request on stdin, one bounded reply. No child processes."""
import os
from pathlib import Path
import signal
import sys
from state_store import MAX_BYTES, StateStore, StoreError, encode, keys, parse


def handle(request, root):
    keys(request, ('version', 'operation'), ('expectedRevision', 'transaction', 'value'))
    if type(request['version']) is not int or request['version'] != 1:
        raise StoreError('invalid')
    store = StateStore(root)
    if request['operation'] == 'load':
        keys(request, ('version', 'operation'))
        return store.load()
    if request['operation'] == 'commit':
        keys(request, ('version', 'operation', 'expectedRevision', 'transaction', 'value'))
        return store.commit(request['expectedRevision'], request['transaction'], request['value'])
    raise StoreError('invalid')


def main():
    # Alarm also bounds partial input and lock waits; QML owns an outer deadline.
    signal.alarm(5)
    try:
        if len(sys.argv) != 1:
            raise StoreError('invalid')
        base = os.environ.get('XDG_STATE_HOME') or str(Path.home() / '.local' / 'state')
        if not Path(base).is_absolute():
            raise StoreError('invalid')
        data = sys.stdin.buffer.read(MAX_BYTES + 1)
        request = parse(data)
        result = handle(request, Path(base) / 'omasound-fixture')
        output = encode(result)
    except StoreError as error:
        output = encode({'ok': False, 'code': error.code})
    except (OSError, ValueError, TypeError, RecursionError, OverflowError):
        output = encode({'ok': False, 'code': 'unavailable'})
    # Output is bounded before the QML collector receives it; no diagnostics or
    # private profile names go to stderr. No untrusted process is being wrapped.
    sys.stdout.buffer.write(output + b'\n')
    sys.stdout.buffer.flush()


if __name__ == '__main__':
    main()
