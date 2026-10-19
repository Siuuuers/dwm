import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('game_patch', Path(__file__).with_name('game_patch.py'))
patch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch)
ROOT = Path(__file__).resolve().parents[1]

class GamePatchTests(unittest.TestCase):
    def sources(self):
        return {path: (ROOT/path).read_text() for path in patch.PINNED}

    def test_pinned_sources(self):
        for path, expected in patch.PINNED.items():
            self.assertEqual(hashlib.sha256((ROOT/path).read_bytes()).hexdigest(), expected)

    def test_original_bodies_preserved_exactly(self):
        before = self.sources()
        after = patch.transform(before)
        for path, original in before.items():
            # Every original body remains verbatim apart from the intentionally
            # replaced goto_menu (one call, now capturing its already-existing result).
            functions = original.split('\nfunc ')[1:]
            for fn in functions:
                signature, body = fn.split('\n', 1)
                if signature.startswith('goto_menu('):
                    continue
                self.assertIn(body.rstrip(), after[path], (path, signature))
            self.assertEqual(original.count('await '), after[path].count('await '))

    def test_helper_is_bounded_opt_in_and_reports_io_failure(self):
        for token in ['MAX_RECORDS: int = 256', 'MAX_BYTES: int = 262144',
                      'DWM_TITLE_TIMING_PATH', 'DWM_TITLE_TIMING_WRITE_FAILURE',
                      'file.get_error()', 'Time.get_ticks_usec()', 'Time.get_unix_time_from_system()',
                      'CONNECT_ONE_SHOT', 'same_menu']:
            self.assertIn(token, patch.HELPER)
        self.assertNotIn('await ', patch.HELPER)

    def test_anchor_drift_rejected(self):
        before = self.sources()
        path = 'autoload/SceneRouter.gd'
        before[path] = before[path].replace('func goto_menu()', 'func goto_menu_drift()')
        with self.assertRaises(ValueError): patch.transform(before)

    def test_duplicate_anchor_rejected(self):
        with self.assertRaises(ValueError): patch.once('same same', 'same', 'new')

    def test_generation_inventory_and_unchanged_input(self):
        before = {p: (ROOT/p).read_bytes() for p in patch.PINNED}
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp)/'overlay'
            patch.generate(ROOT, output)
            inventory = json.loads((output/'timing-inventory.json').read_text())
            self.assertEqual(len(inventory['files']), 5)
            for row in inventory['files']:
                self.assertEqual(row['output_sha256'], patch.digest((output/row['path']).read_bytes()))
            self.assertIn('/dev/null', (output/'timing.patch').read_text())
            with self.assertRaises(ValueError): patch.generate(ROOT, output)
        for p, raw in before.items(): self.assertEqual(raw, (ROOT/p).read_bytes())

    def test_source_directory_output_rejected(self):
        with self.assertRaises(ValueError): patch.generate(ROOT, ROOT/'timing-overlay')

    def test_hash_drift_fails_before_output(self):
        with tempfile.TemporaryDirectory() as temp:
            root, output = Path(temp)/'source', Path(temp)/'output'
            for path in patch.PINNED:
                target = root/path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text((ROOT/path).read_text() + '\n')
            with self.assertRaises(ValueError): patch.generate(root, output)
            self.assertFalse(output.exists())

if __name__ == '__main__': unittest.main()
