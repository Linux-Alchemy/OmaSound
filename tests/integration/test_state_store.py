"""Real filesystem, subprocess, failure injection and restart checks in temp roots."""
import copy
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'helpers'))
from state_store import MAX_BYTES, StateStore, StoreError, parse

HELPER = Path(__file__).resolve().parents[2] / 'helpers' / 'omasound_helper.py'


def value():
    neutral = {'enabled': False, 'gains': [0] * 10}
    return {'profiles': [], 'effective': {s: {'eq': copy.deepcopy(neutral), 'source': None} for s in ('input', 'output')}}


def profile():
    return {'schemaVersion': 1, 'bandSchema': 'ten-band-v1', 'id': 'custom-test', 'revision': 1, 'origin': 'custom', 'name': '<b>../music</b>', 'output': {'enabled': True, 'gains': [3] * 10}}


class StateStoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.root = self.base / 'omasound-fixture'
        self.store = StateStore(self.root)
        self.file = self.root / 'state.json'

    def write(self):
        return self.store.commit(0, 'tx-one', value())

    def helper(self, data):
        return subprocess.run([sys.executable, '-B', str(HELPER)], input=data, capture_output=True, timeout=7,
                              env={**os.environ, 'XDG_STATE_HOME': str(self.base)})

    def test_absent_is_distinct_and_private(self):
        self.assertEqual(self.store.load(), {'ok': True, 'status': 'absent', 'snapshot': None})
        self.assertFalse(self.file.exists())
        self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)
        self.write()
        self.assertEqual(self.file.stat().st_mode & 0o777, 0o600)

    def test_single_snapshot_restores_mixed_provenance_and_profiles(self):
        v = value(); p = profile(); v['profiles'] = [p]
        v['effective']['input'] = {'eq': {'enabled': True, 'gains': [2] * 10}, 'source': {'id': 'factory-fixture-gaming', 'revision': 1, 'name': 'Fixture Gaming'}}
        v['effective']['output'] = {'eq': p['output'], 'source': {'id': p['id'], 'revision': 1, 'name': p['name']}}
        self.store.commit(0, 'tx-one', v)
        self.assertEqual(StateStore(self.root).load()['snapshot']['value'], v)
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), ['lock', 'state.json'])

    def test_conflicting_revision_preserves_last_commit(self):
        self.write(); before = self.file.read_bytes()
        with self.assertRaisesRegex(StoreError, 'conflict'):
            self.store.commit(0, 'tx-two', value())
        self.assertEqual(self.file.read_bytes(), before)

    def test_retry_same_transaction_is_idempotent_not_overwrite(self):
        self.write(); before = self.file.read_bytes()
        self.assertEqual(self.store.commit(0, 'tx-one', value())['revision'], 1)
        changed = value(); changed['effective']['output']['eq']['gains'][0] = 9
        with self.assertRaises(StoreError):
            self.store.commit(0, 'tx-one', changed)
        self.assertEqual(self.file.read_bytes(), before)

    def test_corrupt_oversized_and_wrong_version_never_reinitialize(self):
        self.write()
        for data in [b'{broken', b'x' * (MAX_BYTES + 1), b'{"version":2}', b'{"x":1,"x":2}', b'[[[[']:
            self.file.write_bytes(data)
            with self.assertRaises(StoreError): self.store.load()
            with self.assertRaises(StoreError): self.store.commit(0, 'new', value())
            self.assertEqual(self.file.read_bytes(), data)

    def test_store_and_root_symlinks_fifo_and_hardlinks_rejected(self):
        self.store.load()
        target = self.base / 'keep'; target.write_text('preserve'); target.chmod(0o600)
        for kind in ('symlink', 'fifo', 'hardlink'):
            if kind == 'symlink': self.file.symlink_to(target)
            elif kind == 'fifo': os.mkfifo(self.file, 0o600)
            else: os.link(target, self.file)
            with self.assertRaises((OSError, StoreError)): self.store.commit(0, 'new', value())
            self.file.unlink()
            self.assertEqual(target.read_text(), 'preserve')
        alias = self.base / 'alias'; alias.symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(OSError): StateStore(alias).load()

    def test_nonprivate_state_and_lock_rejected_without_repair(self):
        self.write(); self.file.chmod(0o644)
        with self.assertRaises(StoreError): self.store.load()
        self.assertEqual(self.file.stat().st_mode & 0o777, 0o644)
        self.file.chmod(0o600); (self.root / 'lock').chmod(0o666)
        with self.assertRaises(StoreError): self.store.load()

    def test_lock_contention_is_bounded(self):
        self.write()
        with open(self.root / 'lock', 'r') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            response = self.helper(b'{"version":1,"operation":"load"}')
            self.assertEqual(json.loads(response.stdout)['code'], 'busy')

    def test_prepublication_failures_preserve_previous_document(self):
        self.write(); before = self.file.read_bytes()
        for method in ('fsync', 'replace'):
            with patch('state_store.os.' + method, side_effect=OSError('injected')):
                with self.assertRaisesRegex(StoreError, 'unavailable'): self.store.commit(1, 'tx-two', value())
            self.assertEqual(self.file.read_bytes(), before)
            self.assertFalse(list(self.root.glob('.pending-*')))

    def test_postpublication_sync_failure_is_uncertain_and_retry_confirms(self):
        self.write()
        actual = os.fsync; calls = []
        def fail_directory(fd):
            calls.append(fd)
            if len(calls) == 2: raise OSError('injected directory fsync')
            return actual(fd)
        with patch('state_store.os.fsync', side_effect=fail_directory):
            with self.assertRaisesRegex(StoreError, 'uncertain'): self.store.commit(1, 'tx-two', value())
        self.assertEqual(self.store.commit(1, 'tx-two', value())['revision'], 2)

    def test_abrupt_exit_before_replace_keeps_old_complete_snapshot(self):
        self.write(); before = self.file.read_bytes()
        code = "import os,sys;sys.path.insert(0,sys.argv[1]);import state_store as s;store=s.StateStore(sys.argv[2]);v=store.load()['snapshot']['value'];s.os.replace=lambda *a,**k:os._exit(77);store.commit(1,'interrupted',v)"
        run = subprocess.run([sys.executable, '-B', '-c', code, str(HELPER.parent), str(self.root)], timeout=5)
        self.assertEqual(run.returncode, 77)
        self.assertEqual(self.file.read_bytes(), before)
        self.assertTrue(list(self.root.glob('.pending-*')))
        self.assertEqual(self.store.load()['snapshot']['revision'], 1)

    def test_schema_rejects_foreign_state_counts_names_and_nonfinite(self):
        mutations = [lambda v: v.update(device='not EQ'), lambda v: v['effective']['input']['eq'].update(volume=4),
                     lambda v: v['effective']['output']['eq']['gains'].__setitem__(0, float('nan')),
                     lambda v: v['profiles'].extend([profile()] * 257),
                     lambda v: v['profiles'].extend([profile(), profile()])]
        for change in mutations:
            v = value(); change(v)
            with self.assertRaises(StoreError): self.store.commit(0, 'new', v)
            self.assertFalse(self.file.exists())
        for bad in ('../traversal', 'custom-../traversal'):
            v = value(); p = profile(); p['id'] = bad; v['profiles'] = [p]
            with self.assertRaises(StoreError): self.store.commit(0, 'new', v)

    def test_helper_protocol_is_bounded_and_has_no_command_dispatch(self):
        for request in [b'x' * (MAX_BYTES + 1), b'{"version":1,"operation":"exec","command":"touch /tmp/no"}', b'{"version":1,"operation":"load","root":"/tmp/other"}', b'NaN']:
            result = self.helper(request)
            self.assertEqual(result.returncode, 0)
            self.assertFalse(json.loads(result.stdout)['ok'])
            self.assertLess(len(result.stdout), 100)
            self.assertEqual(result.stderr, b'')
        good = self.helper(b'{"version":1,"operation":"load"}')
        self.assertEqual(json.loads(good.stdout)['status'], 'absent')

    def test_concurrent_process_writers_accept_exactly_one_revision(self):
        self.write()
        processes = []
        for tx in ('writer-a', 'writer-b'):
            request = json.dumps({'version':1,'operation':'commit','expectedRevision':1,'transaction':tx,'value':value()}).encode()
            p = subprocess.Popen([sys.executable, '-B', str(HELPER)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 env={**os.environ, 'XDG_STATE_HOME':str(self.base)})
            p.stdin.write(request); p.stdin.close(); p.stdin = None; processes.append(p)
        results = [json.loads(p.communicate(timeout=7)[0]) for p in processes]
        self.assertEqual(sum(r['ok'] for r in results), 1)
        self.assertEqual([r['code'] for r in results if not r['ok']], ['conflict'])
        self.assertEqual(self.store.load()['snapshot']['revision'], 2)


if __name__ == '__main__': unittest.main()
