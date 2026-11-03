import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import run_progression_checks as runner
from run_progression_checks import BATCH_METHODS, assert_filter_matches, assert_tests_pass


class ProgressionRunnerTests(unittest.TestCase):
    def report(self, methods):
        report = ET.Element('testsuites')
        suite = ET.SubElement(report, 'testsuite')
        for method in methods:
            ET.SubElement(suite, 'testcase', name=method, assertions='1', status='pass')
        return report

    def test_accepts_exact_pair_and_single_method(self):
        assert_tests_pass(self.report(BATCH_METHODS['write_refusal_keeps_']), BATCH_METHODS['write_refusal_keeps_'])
        assert_tests_pass(self.report(('test_single',)), ('test_single',))

    def test_rejects_missing_extra_duplicate_or_wrong_method(self):
        first, second = BATCH_METHODS['write_refusal_keeps_']
        for methods in ((first,), (first, second, 'extra'), (first, first), (first, 'wrong')):
            with self.subTest(methods=methods), self.assertRaises(AssertionError):
                assert_tests_pass(self.report(methods), BATCH_METHODS['write_refusal_keeps_'])

    def test_declared_filters_match_the_actual_source_before_launch(self):
        for _name, path, method in runner.CASES:
            assert_filter_matches((runner.ROOT / path).read_text(), method, BATCH_METHODS.get(method, (method,)))
        for _name, path, method, _storage, _marker in runner.JOURNEYS:
            assert_filter_matches((runner.ROOT / path).read_text(), method, (method,))

    def test_batch_filter_rejects_wrong_missing_or_extra_matches(self):
        for method_filter, expected in BATCH_METHODS.items():
            source = ''.join('func ' + method + '():\n\tpass\n' for method in expected)
            assert_filter_matches(source + 'func test_unrelated():\n\tpass\n', method_filter, expected)
            for changed, selected in (
                (source, method_filter.upper()),
                (source.replace(expected[0], 'test_renamed'), method_filter),
                (source + 'func test_extra_' + method_filter + '():\n\tpass\n', method_filter),
            ):
                with self.subTest(batch=method_filter, selected=selected), self.assertRaises(AssertionError):
                    assert_filter_matches(changed, selected, expected)

    def test_bad_filter_fails_before_any_godot_process(self):
        with patch.object(runner, 'CASES', [('bad', runner.NEXT, 'missing_filter')]), \
                patch.object(runner.subprocess, 'run') as launch:
            with self.assertRaises(AssertionError):
                runner.run()
            launch.assert_not_called()

    def test_each_method_requires_assertions_and_pass_status(self):
        for index in (0, 1):
            for attribute, value in (('assertions', '0'), ('status', 'fail')):
                report = self.report(BATCH_METHODS['write_refusal_keeps_'])
                report.findall('.//testcase')[index].set(attribute, value)
                with self.subTest(index=index, attribute=attribute), self.assertRaises(AssertionError):
                    assert_tests_pass(report, BATCH_METHODS['write_refusal_keeps_'])
        for tag in ('failure', 'error', 'skipped'):
            report = self.report(BATCH_METHODS['write_refusal_keeps_'])
            ET.SubElement(report.findall('.//testcase')[1], tag)
            with self.subTest(tag=tag), self.assertRaises(AssertionError):
                assert_tests_pass(report, BATCH_METHODS['write_refusal_keeps_'])


if __name__ == '__main__':
    unittest.main()
