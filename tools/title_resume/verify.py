"""Two real production processes share one isolated, initially empty user root."""
from pathlib import Path
import runpy
import sys

ROOT = Path(__file__).resolve().parents[2]


if __name__ == '__main__':
    if len(sys.argv) != 1:
        raise SystemExit('Usage: python tools/title_resume/verify.py')
    shared = runpy.run_path(str(ROOT / 'tools/save_load_loop/verify.py'), run_name='startup_runner')
    sys.exit(shared['main']({
        'observer': 'tests/title_resume/Observe.gd',
        'name': 'title-resume',
        'runner': 'tools/title_resume/verify.py',
        'evidence_dir': 'tools/title_resume/evidence',
        'summary_prefix': 'TITLE_RESUME_SUMMARY ',
        'runtime_phases': [('seed', 'TITLE_RESUME_SEED_PASS'), ('resume', 'TITLE_RESUME_PASS')],
        'scope': 'Two distinct actual production processes with shared isolated user storage: create and save a run, then cold title Log in resumes it. Original main scene and autoloads plus first observer; headless control activation, no physical-input/GPU proof.',
    }))
