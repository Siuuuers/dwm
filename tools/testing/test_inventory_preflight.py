import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = (ROOT / '.github/workflows/dtl-first-preflight.yml').read_text()
STEP = re.search(
    r'(?ms)^      - name: Verify public inventories or explicitly regenerate\n(.*?)(?=^      - name:)',
    WORKFLOW,
)[1]
SCRIPT = textwrap.dedent(STEP.split('        run: |\n', 1)[1].split('      #', 1)[0])
MOCK_GODOT = '''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
args = sys.argv[1:]
output = next(value.split('=', 1)[1] for value in args if value.startswith('--output='))
path = Path(os.environ['GITHUB_WORKSPACE']) / output.removeprefix('res://')
mode = 'check' if '--check' in args else 'generate'
with Path(os.environ['GITHUB_WORKSPACE'], 'calls').open('a') as calls:
    calls.write(path.stem + ':' + mode + '\\n')
log = Path(args[args.index('--log-file') + 1])
if mode == 'check' and path.read_text() != 'current':
    log.write_text('SURFACE_INVENTORY: STALE\\n')
    sys.exit(1)
if mode == 'generate':
    path.write_text('current')
log.write_text('SURFACE_INVENTORY: PASS\\n')
'''


class InventoryPreflightTests(unittest.TestCase):
    def run_step(self, event, check_generated, initial='current'):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.godot/ci/dtl-first').mkdir(parents=True)
            inventory = root / 'evidence/phase_2r/runtime'
            inventory.mkdir(parents=True)
            targets = [inventory / (target + '_surface.json') for target in ('game_state', 'save_manager')]
            for path in targets:
                path.write_text(initial)
            godot = root / 'godot'
            godot.write_text(MOCK_GODOT)
            godot.chmod(0o755)
            result = subprocess.run(
                ['bash', '-e', '-o', 'pipefail', '-c', SCRIPT],
                env={**os.environ, 'GITHUB_WORKSPACE': directory, 'GODOT_CONSOLE_PATH': str(godot),
                     'GITHUB_EVENT_NAME': event, 'DWM_CHECK_GENERATED': check_generated},
                capture_output=True, text=True,
            )
            return result.returncode, (root / 'calls').read_text().splitlines(), [p.read_text() for p in targets]

    def test_acceptance_checks_each_target_once_without_regeneration(self):
        for event, strict in [('pull_request', ''), ('pull_request', 'false'),
                              ('workflow_dispatch', 'true')]:
            with self.subTest(event=event, strict=strict):
                self.assertEqual(self.run_step(event, strict),
                                 (0, ['game_state_surface:check', 'save_manager_surface:check'],
                                  ['current', 'current']))

    def test_stale_pr_inventory_fails_without_rewriting_either_file(self):
        code, calls, contents = self.run_step('pull_request', '', 'stale')
        self.assertNotEqual(code, 0)
        self.assertEqual(calls, ['game_state_surface:check'])
        self.assertEqual(contents, ['stale', 'stale'])

    def test_explicit_regeneration_generates_then_checks_each_target(self):
        self.assertEqual(self.run_step('workflow_dispatch', 'false', 'stale'),
                         (0, ['game_state_surface:generate', 'game_state_surface:check',
                              'save_manager_surface:generate', 'save_manager_surface:check'],
                          ['current', 'current']))

    def test_workflow_supplies_input_and_runs_regression(self):
        self.assertIn('DWM_CHECK_GENERATED: ${{ inputs.check_generated }}', STEP)
        self.assertIn('/tools/testing/test_inventory_preflight.py', WORKFLOW)
        self.assertIn('run: python tools/testing/test_inventory_preflight.py', WORKFLOW)


if __name__ == '__main__':
    unittest.main()
