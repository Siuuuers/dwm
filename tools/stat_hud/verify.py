"""Exercise the actual StatHud in the existing disposable, autoload-free UI runner."""
from pathlib import Path
import runpy
import sys

if __name__ == '__main__':
    if len(sys.argv) != 1:
        raise SystemExit('Usage: python tools/stat_hud/verify.py')
    root = Path(__file__).resolve().parents[2]
    runpy.run_path(str(root / 'tools/backup_ui/verify.py'), init_globals={
        'TEST_SCRIPT': 'tests/stat_hud/test_stat_hud.gd',
        'PASS_MARKER': 'STAT_HUD_PASS',
        'SCRATCH_PREFIX': 'stat-hud-',
        'EVIDENCE_DIR': 'tools/stat_hud/evidence',
        'WRAPPER_SOURCE': 'tools/stat_hud/verify.py',
        'SCOPE': 'Actual StatHud scene, bundled fonts and production presenter with injected read-only GameState-shaped fixture, locale and preference fixtures. Verifies public clamping/non-disclosure, signals, localized layout and owner nonmutation. Headless Control geometry, not GPU or physical assistive-technology certification; no production autoloads or player storage.',
    }, run_name='focused_ui_runner')
