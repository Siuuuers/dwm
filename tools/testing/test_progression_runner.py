import unittest
import xml.etree.ElementTree as ET

from run_progression_checks import WRITE_REFUSAL_METHODS, assert_tests_pass


class ProgressionRunnerTests(unittest.TestCase):
    def report(self, methods):
        report = ET.Element('testsuites')
        suite = ET.SubElement(report, 'testsuite')
        for method in methods:
            ET.SubElement(suite, 'testcase', name=method, assertions='1', status='pass')
        return report

    def test_accepts_exact_pair_and_single_method(self):
        assert_tests_pass(self.report(WRITE_REFUSAL_METHODS), WRITE_REFUSAL_METHODS)
        assert_tests_pass(self.report(('test_single',)), ('test_single',))

    def test_rejects_missing_extra_duplicate_or_wrong_method(self):
        first, second = WRITE_REFUSAL_METHODS
        for methods in ((first,), (first, second, 'extra'), (first, first), (first, 'wrong')):
            with self.subTest(methods=methods), self.assertRaises(AssertionError):
                assert_tests_pass(self.report(methods), WRITE_REFUSAL_METHODS)

    def test_each_method_requires_assertions_and_pass_status(self):
        for index in (0, 1):
            for attribute, value in (('assertions', '0'), ('status', 'fail')):
                report = self.report(WRITE_REFUSAL_METHODS)
                report.findall('.//testcase')[index].set(attribute, value)
                with self.subTest(index=index, attribute=attribute), self.assertRaises(AssertionError):
                    assert_tests_pass(report, WRITE_REFUSAL_METHODS)
        for tag in ('failure', 'error', 'skipped'):
            report = self.report(WRITE_REFUSAL_METHODS)
            ET.SubElement(report.findall('.//testcase')[1], tag)
            with self.subTest(tag=tag), self.assertRaises(AssertionError):
                assert_tests_pass(report, WRITE_REFUSAL_METHODS)


if __name__ == '__main__':
    unittest.main()
