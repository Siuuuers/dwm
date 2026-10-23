"""Focused real Menu scene checks; reuse the existing disposable UI runner."""
from pathlib import Path
import runpy
import sys

if __name__ == '__main__':
    if len(sys.argv) != 1:
        raise SystemExit('Usage: python tools/title_shell/verify.py')
    root = Path(__file__).resolve().parents[2]
    runpy.run_path(str(root / 'tools/backup_ui/verify.py'), init_globals={
        'TEST_SCRIPT': 'tests/title_shell/test_title_shell.gd',
        'PASS_MARKER': 'TITLE_SHELL_PASS',
        'SCRATCH_PREFIX': 'title-shell-',
        'EVIDENCE_DIR': 'tools/title_shell/evidence',
        'WRAPPER_SOURCE': 'tools/title_shell/verify.py',
        'SCOPE': 'Actual Menu scene and inherited production controller, clock and confirmation UI. Minimal fake locale/profile and external command counters; only process quit is overridden. Headless geometry/input checks, no production autoloads, user persistence or GPU proof.',
    }, run_name='focused_ui_runner')
