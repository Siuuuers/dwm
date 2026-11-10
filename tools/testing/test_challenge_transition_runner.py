from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import run_challenge_transition_checks as runner


class ChallengeTransitionRunnerTests(unittest.TestCase):
    def report(self, expected):
        root = ET.Element('testsuites')
        suite = ET.SubElement(root, 'testsuite')
        for path, method in expected:
            ET.SubElement(suite, 'testcase', classname=path, name=method, status='pass', assertions='1')
        return root

    def test_requires_every_selected_method_in_its_actual_suite(self):
        expected = [('one.gd', 'test_same'), ('two.gd', 'test_same')]
        runner.assert_tests_pass(self.report(expected), expected)
        for actual in ([], expected[:1], expected + expected[:1], [expected[0]] * 2):
            with self.subTest(actual=actual), self.assertRaises(AssertionError):
                runner.assert_tests_pass(self.report(actual), expected)

    def test_rejects_empty_assertions_failures_and_skips(self):
        expected = [('one.gd', 'test_one')]
        for attribute, value in (('assertions', '0'), ('status', 'fail')):
            report = self.report(expected)
            report.find('.//testcase').set(attribute, value)
            with self.subTest(attribute=attribute), self.assertRaises(AssertionError):
                runner.assert_tests_pass(report, expected)
        for tag in ('failure', 'error', 'skipped'):
            report = self.report(expected)
            ET.SubElement(report.find('.//testcase'), tag)
            with self.subTest(tag=tag), self.assertRaises(AssertionError):
                runner.assert_tests_pass(report, expected)

    def test_extracts_only_test_methods_with_their_source_identity(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'one.gd').write_text('func helper():\n\tpass\nfunc test_first():\n\tpass\n')
            (root / 'two.gd').write_text('func test_second():\n\tpass\n')
            with patch.object(runner, 'ROOT', root):
                self.assertEqual(runner.expected_tests(('one.gd', 'two.gd')),
                                 [('one.gd', 'test_first'), ('two.gd', 'test_second')])

    def test_missing_tests_fail_before_import(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'empty.gd').write_text('extends Node\n')
            with patch.object(runner, 'ROOT', root), \
                    patch.object(runner, 'GROUPS', [('empty', 'empty', False, ('empty.gd',))]), \
                    patch.object(runner.subprocess, 'run') as launch:
                with self.assertRaises(AssertionError):
                    runner.run('godot')
                launch.assert_not_called()

    def test_processes_isolate_registrations_but_creator_and_loader_share_storage(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for _name, _storage, _fixture, paths in runner.GROUPS:
                for path in paths:
                    (root / path).parent.mkdir(parents=True, exist_ok=True)
                    (root / path).write_text('func test_one():\n\tpass\n')
            calls = []

            def launch(command, **kwargs):
                if command[0] == 'git':
                    return
                Path(command[command.index('--log-file') + 1]).write_text('')
                if '--import' in command:
                    return
                calls.append(kwargs['env'])
                paths = next(arg[7:] for arg in command if arg.startswith('-gtest=')).split(',')
                expected = [(path.removeprefix('res://'), 'test_one') for path in paths]
                destination = next(arg.split('=', 1)[1] for arg in command if arg.startswith('-gjunit_xml_file='))
                ET.ElementTree(self.report(expected)).write(destination)

            with patch.object(runner, 'ROOT', root), \
                    patch.dict(runner.os.environ, {'DWM_SCENE_READING_FIXTURE': 'inherited'}), \
                    patch.object(runner.subprocess, 'run', side_effect=launch):
                runner.run('godot')
                self.assertEqual(len(calls), 7)
                self.assertEqual(calls[0]['DWM_SCENE_READING_FIXTURE'], '1')
                self.assertTrue(all('DWM_SCENE_READING_FIXTURE' not in env for env in calls[1:]))
                roots = [env['DWM_TEST_ROOT'] for env in calls]
                self.assertEqual(len(set(roots)), 6)
                self.assertEqual(roots[-2], roots[-1])
                runner.run('godot')
                self.assertNotEqual(calls[0]['DWM_TEST_ROOT'], calls[7]['DWM_TEST_ROOT'])


if __name__ == '__main__':
    unittest.main()
