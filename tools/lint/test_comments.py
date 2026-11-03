import unittest

from check_comments import comment_lines, owned, violations


class CommentTests(unittest.TestCase):
    def test_gdscript_strings_and_inline_comments(self):
        source = 'var a = "# text"\nvar b = \'# text\' # explanation\n'
        self.assertEqual(comment_lines(source, '.gd'), {2: '# explanation'})

    def test_multiline_and_escaped_strings(self):
        source = 'var a = """\n# text\n"""\nvar b = "escaped \\" # text" # real\n'
        self.assertEqual(comment_lines(source, '.gd'), {4: '# real'})

    def test_python_strings_and_comments(self):
        self.assertEqual(violations('', 'x = "# text"\n# explanation\n', '.py'), [2])

    def test_existing_comments_are_retained_but_edits_fail(self):
        before = '# existing\nvar a = 1\n'
        self.assertEqual(violations(before, '\n' + before, '.gd'), [])
        self.assertEqual(violations(before, '# rewritten\nvar a = 1\n', '.gd'), [1])

    def test_deleting_string_delimiters_exposes_comments(self):
        self.assertEqual(violations('"""\n# text\n"""\n', '# text\n', '.gd'), [1])

    def test_legal_and_machine_directives(self):
        source = '# SPDX-License-Identifier: MIT\n# Copyright 2026 Example\n# gdlint: disable=max-line-length\n# explanation\n'
        self.assertEqual(violations('', source, '.gd'), [4])

    def test_documentation_comments_are_comments(self):
        self.assertEqual(violations('', '## description\n', '.gd'), [1])

    def test_encoding_directive_is_limited_to_python_header(self):
        self.assertEqual(violations('', '# coding: utf-8\n', '.py'), [])
        self.assertEqual(violations('', '# explanation coding: anything\n', '.py'), [1])
        self.assertEqual(violations('', '\n\n# coding: utf-8\n', '.py'), [3])
        self.assertEqual(violations('', '# coding: utf-8\n', '.gd'), [1])

    def test_scope_excludes_dependencies_and_generated_files(self):
        for path in ['scripts/game.gd', 'autoload/Run.gd', 'tests/test.gd', 'tools/check.py']:
            self.assertTrue(owned(path))
        for path in ['addons/plugin.gd', 'scripts/generated/table.gd', 'tools/vendor/lib.py', 'docs/example.py', 'tools/editor.js']:
            self.assertFalse(owned(path))


if __name__ == '__main__':
    unittest.main()
