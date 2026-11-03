import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import run_inventory_checks as runner


class InventoryRunnerTests(unittest.TestCase):
    def test_checkout_keeps_scanner_inputs_and_only_required_evidence(self):
        workflow = (runner.ROOT / '.github/workflows/windows-tests.yml').read_text()
        job = workflow.split('\n  inventory-tooling:', 1)[1]
        patterns = textwrap.dedent(job.split('          sparse-checkout: |\n', 1)[1].split('      - name:', 1)[0])
        self.assertIn('sparse-checkout-cone-mode: false', job)
        keep = {'evidence/.gdignore', 'project.godot', 'assets/nested/image.png', 'tools/testing/run_inventory_checks.py'}
        keep.update(root + '/nested/input.gd' for root in ('autoload', 'scripts', 'scenes', 'tests'))
        keep.update(f'evidence/phase_2r/runtime/{target}{suffix}.json'
                    for target in runner.TARGETS for suffix in ('_surface', '_required_surface'))
        omit = {'evidence/archive.zip', 'evidence/old/result.json',
                'evidence/phase_2r/runtime/unrelated.json', 'evidence/phase_2r/old/archive.tar.gz.part01'}
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            for name in keep | omit:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(name)
            subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
            subprocess.run(['git', '-C', str(root), '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                            'commit', '-qm', 'fixture'], check=True)
            subprocess.run(['git', '-C', str(root), 'sparse-checkout', 'set', '--no-cone', '--stdin'],
                           input=patterns, text=True, check=True)
            self.assertEqual({name for name in keep | omit if (root / name).exists()}, keep)

    def report(self, methods=('test_first', 'test_second')):
        report = ET.Element('testsuites')
        suite = ET.SubElement(report, 'testsuite')
        for method in methods:
            ET.SubElement(suite, 'testcase', name=method, classname=runner.TEST, assertions='1', status='pass')
        return report

    def test_requires_exact_methods_and_passing_assertions(self):
        expected = ['test_first', 'test_second']
        runner.assert_tests_pass(self.report(), expected)
        for names in ((), ('test_first',), ('test_first', 'test_first'), (*expected, 'test_extra')):
            with self.subTest(names=names), self.assertRaises(AssertionError):
                runner.assert_tests_pass(self.report(names), expected)
        for attribute, value in [('assertions', '0'), ('status', 'fail'), ('classname', 'wrong')]:
            report = self.report()
            report.find('.//testcase').set(attribute, value)
            with self.subTest(attribute=attribute), self.assertRaises(AssertionError):
                runner.assert_tests_pass(report, expected)
        for tag in ('failure', 'error', 'skipped'):
            report = self.report()
            ET.SubElement(report.find('.//testcase'), tag)
            with self.subTest(tag=tag), self.assertRaises(AssertionError):
                runner.assert_tests_pass(report, expected)

    def exercise(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / runner.TEST
            source.parent.mkdir(parents=True)
            source.write_text('func test_first():\n\tpass\nfunc test_second():\n\tpass\n')
            for target in runner.TARGETS:
                path = root / f'evidence/phase_2r/runtime/{target}_surface.json'
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('canonical')
            calls = []

            def launch(args, **kwargs):
                self.assertTrue(kwargs['check'])
                self.assertEqual(kwargs['cwd'], root)
                self.assertTrue(Path(kwargs['env']['XDG_DATA_HOME']).is_dir())
                self.assertTrue(Path(kwargs['env']['DWM_TEST_ROOT']).is_dir())
                calls.append(args)
                log = Path(args[args.index('--log-file') + 1])
                if log.stem == 'tooling':
                    report = next(arg.split('=', 1)[1] for arg in args if arg.startswith('-gjunit_xml_file='))
                    ET.ElementTree(self.report()).write(report)
                    log.write_text('done')
                else:
                    self.assertIn('--check', args)
                    self.assertEqual([arg for arg in args if arg.startswith('--search-root=')],
                                     ['--search-root=res://' + name for name in ('autoload', 'scripts', 'scenes', 'tests')])
                    log.write_text('SURFACE_INVENTORY: PASS\n')

            with patch.object(runner, 'ROOT', root), patch.object(runner.subprocess, 'run', side_effect=launch), \
                    patch.dict(os.environ, {'GODOT_CONSOLE_PATH': 'godot'}):
                runner.run()
            self.assertEqual(len(calls), 3)
            for args, target, owner in zip(calls[1:], runner.TARGETS, runner.TARGETS.values()):
                self.assertIn('--script=res://autoload/' + owner + '.gd', args)
                self.assertIn('--required=res://evidence/phase_2r/runtime/' + target + '_required_surface.json', args)
                self.assertIn('--output=res://evidence/phase_2r/runtime/' + target + '_surface.json', args)

    def test_executes_tooling_and_both_read_only_targets(self):
        self.exercise()



if __name__ == '__main__':
    unittest.main()
