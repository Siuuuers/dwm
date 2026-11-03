from pathlib import Path
import subprocess
import sys
import tempfile
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


class GitRenameTests(unittest.TestCase):
    def test_rename_preserves_legacy_and_rejects_new_comments(self):
        checker = Path(__file__).with_name('check_comments.py').resolve()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args], stderr=subprocess.STDOUT).decode().strip()
            git('init')
            git('config', 'user.name', 'Lint Test')
            git('config', 'user.email', 'lint@example.invalid')
            (root / 'scripts').mkdir()
            old = root / 'scripts/old.gd'
            old.write_text('# legacy\n' + ''.join(f'var value_{i} = {i}\n' for i in range(20)))
            git('add', '.')
            git('commit', '-m', 'base')
            base = git('rev-parse', 'HEAD')
            new = root / 'scripts/new name.gd'
            old.rename(new)
            git('add', '-A')
            git('commit', '-m', 'rename')
            result = subprocess.run([sys.executable, str(checker), '--base', base], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            new.write_text(new.read_text() + '# added\n')
            git('add', '-A')
            git('commit', '-m', 'new comment')
            result = subprocess.run([sys.executable, str(checker), '--base', base], cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn('scripts/new name.gd:22:', result.stdout)
            self.assertIn('Comment lint: 1 violation(s)', result.stdout)


if __name__ == '__main__':
    unittest.main()
