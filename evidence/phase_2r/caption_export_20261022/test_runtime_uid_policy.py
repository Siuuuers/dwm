"""Focused regression for the newly admitted runtime UID and package mapping."""
import copy
import hashlib
import importlib.util
from pathlib import Path
import sys
import tempfile
import types
import unittest

custody = types.ModuleType('capture_import')
sys.modules['capture_import'] = custody
spec = importlib.util.spec_from_file_location('preparation', Path(__file__).with_name('prepare_delivery.py'))
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class RuntimeUIDPolicy(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        p.ROOT = p.OUTPUT = custody.OUT = Path(self.temp.name)
        self.uid = p.ROOT / p.RUNTIME_UID
        self.uid.parent.mkdir(parents=True)
        self.uid.write_bytes(b'uid://b\n')
        self.peer = p.ROOT / 'peer.gd.uid'
        self.peer.write_bytes(b'uid://c\n')
        self.baseline = {'head_entries': {
            p.RUNTIME_UID[:-4]: {'oid': p.RUNTIME_SOURCE_BLOB, 'mode': '100644'},
            'peer.gd.uid': {'oid': 'sidecar', 'mode': '100644'}}}
        custody.git = lambda *args: types.SimpleNamespace(stdout=p.RUNTIME_UID.encode() + b'\0')
        custody.sha = lambda data: hashlib.sha256(data).hexdigest()
        custody.retain = lambda data: {'sha256': custody.sha(data), 'size': len(data), 'file': 'retained'}
        p.write = lambda *args: None

    def entry(self):
        entry = {'path': p.RUNTIME_UID, 'bytes': custody.retain(self.uid.read_bytes())}
        p.check_runtime_uid(entry, self.baseline)
        return entry

    def test_exact_owner_and_distinct_peer(self):
        entry = self.entry()
        self.assertTrue(entry['uid_comparisons_complete'])
        self.assertEqual(entry['uid'], '1')

    def test_wrong_owner_rejected(self):
        self.baseline['head_entries'][p.RUNTIME_UID[:-4]]['oid'] = 'wrong'
        with self.assertRaisesRegex(RuntimeError, 'SOURCE_NOT_PINNED'):
            self.entry()

    def test_effective_peer_collision_rejected(self):
        self.peer.write_bytes(b'\xef\xbb\xbfuid://b\rtrailing bytes')
        with self.assertRaisesRegex(RuntimeError, 'RUNTIME_UID_COLLISION'):
            self.entry()

    def test_malformed_peer_rejected(self):
        self.peer.write_bytes(b'broken')
        with self.assertRaisesRegex(RuntimeError, 'UID_COMPARISON_FAILED'):
            self.entry()

    def final(self, records):
        entry = self.entry()
        p.package_uid_cache = lambda _: ([], records, {})
        p.final_generated([entry], [copy.deepcopy(entry)], self.baseline, Path('package.zip'))

    def test_package_mapping_matches(self):
        self.final([{'uid': '1', 'path': 'res://' + p.RUNTIME_UID[:-4]}])

    def test_package_missing_or_conflicting_mapping_rejected(self):
        for records in ([], [{'uid': '2', 'path': 'res://' + p.RUNTIME_UID[:-4]}],
                        [{'uid': '1', 'path': 'res://other.gd'}]):
            with self.subTest(records=records), self.assertRaisesRegex(RuntimeError, 'MAPPING_MISSING_OR_CONFLICTING'):
                self.final(records)


if __name__ == '__main__':
    unittest.main()
