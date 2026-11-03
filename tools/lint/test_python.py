from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class PythonSyntaxTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.git('init')
        self.git('config', 'user.name', 'Lint Test')
        self.git('config', 'user.email', 'lint@example.invalid')
        self.write('tools/existing.py', 'value = 1\n')
        self.write('tools/deleted.py', 'invalid syntax\n')
        self.commit()
        self.base = self.git('rev-parse', 'HEAD')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.root), *args], stderr=subprocess.STDOUT).decode().strip()

    def write(self, path, source):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source)

    def commit(self):
        self.git('add', '-A')
        self.git('commit', '-m', 'fixture')

    def check(self, *args):
        checker = Path(__file__).with_name('check_python.py').resolve()
        return subprocess.run([sys.executable, '-B', str(checker), '--base', self.base, *args],
                              cwd=self.root, capture_output=True, text=True)

    def test_valid_source_is_compiled_without_execution_or_bytecode(self):
        self.write('tools/added.py', 'raise RuntimeError("must not execute")\n')
        self.write('tools/existing.py', 'value = 2\n')
        self.commit()
        head = self.git('rev-parse', 'HEAD')
        self.write('tools/added.py', 'broken(\n')
        result = self.check('--head', head)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('2 file(s), 0 error(s)', result.stdout)
        self.assertEqual(list(self.root.rglob('*.pyc')), [])

    def test_changed_syntax_error_reports_path_and_line(self):
        self.write('tools/existing.py', 'value = (\n')
        self.commit()
        result = self.check()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('tools/existing.py:1:', result.stdout)
        self.assertIn('1 file(s), 1 error(s)', result.stdout)

    def test_renamed_destination_checked_deleted_and_unowned_files_skipped(self):
        self.git('mv', 'tools/existing.py', 'tools/new name.py')
        self.git('rm', 'tools/deleted.py')
        self.write('tools/vendor/external.py', 'invalid syntax\n')
        self.write('docs/example.py', 'invalid syntax\n')
        self.write('scripts/example.gd', 'not python\n')
        self.commit()
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('1 file(s), 0 error(s)', result.stdout)


if __name__ == '__main__':
    unittest.main()
