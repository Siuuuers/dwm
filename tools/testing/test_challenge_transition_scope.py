"""Exercise method boundaries using real git snapshots, without Godot."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from challenge_transition_scope import METHODS, is_challenge_transition


class ChallengeTransitionScopeTests(unittest.TestCase):
    def test_real_git_method_changes_and_neighbor_boundaries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', directory], check=True)
            for path, methods in METHODS.items():
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text('extends Node\nvar retained := 1\n\n' + ''.join(
                    f'func {name}():\n\treturn 1\n\n' for name in sorted(methods)
                    if name not in {'validate_live_scene_event_anchor', '_retained_scene_challenge_command'}
                ) + '## Saved-anchor contract.\nfunc validate_scene_event_anchor():\n\treturn 1\n')
            subprocess.run(['git', '-C', directory, 'add', '.'], check=True)
            commit = ['git', '-C', directory, '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                      'commit', '-qm']
            subprocess.run(commit + ['before'], check=True)
            base = subprocess.check_output(['git', '-C', directory, 'rev-parse', 'HEAD'], text=True).strip()
            for path, methods in METHODS.items():
                target = root / path
                source = target.read_text()
                for name in methods:
                    source = source.replace(f'func {name}():\n\treturn 1', f'func {name}():\n\treturn 2')
                source = source.replace('_capture_retained_scene_challenge_command', '_retained_scene_challenge_command')
                if path == 'autoload/DialogicBridge.gd':
                    source = source.replace('## Saved-anchor', 'func validate_live_scene_event_anchor():\n\treturn 2\n\n## Saved-anchor')
                target.write_text(source)
            subprocess.run(['git', '-C', directory, 'add', '.'], check=True)
            subprocess.run(commit + ['reviewed methods'], check=True)
            previous = Path.cwd()
            try:
                os.chdir(directory)
                paths = set(METHODS)
                self.assertTrue(is_challenge_transition(paths, base))
                self.assertTrue(is_challenge_transition(paths | {'docs/agent/2026-11-10-challenge-ci-coverage-handoff.md'}, base))
                target = root / 'autoload/DialogicBridge.gd'
                reviewed = target.read_text()
                for source in (
                    reviewed.replace('func validate_scene_event_anchor():\n\treturn 1',
                                     'func validate_scene_event_anchor():\n\treturn 2'),
                    reviewed.replace('var retained := 1', 'var retained := 2'),
                    reviewed.replace('## Saved-anchor contract.', '## Different contract.'),
                ):
                    target.write_text(source)
                    subprocess.run(['git', 'add', '.'], check=True)
                    subprocess.run(commit + ['outside reviewed scope'], check=True)
                    self.assertFalse(is_challenge_transition(paths, base))
            finally:
                os.chdir(previous)

    def test_workflow_companions_only_change_the_reviewed_jobs_and_gates(self):
        main = '.github/workflows/windows-tests.yml'
        dtl = '.github/workflows/dtl-first-preflight.yml'
        before = {
            main: "permissions:\n  contents: read\njobs:\n  test-scope:\n    run: select-old\n"
                  "  windows-export:\n    if: enabled\n    run: export\n",
            dtl: "on:\n  pull_request:\n    paths:\n      - 'autoload/**'\n"
                 "permissions:\n  contents: read\njobs:\n  scope:\n    run: select-old\n"
                 "  authoring:\n    run: author\n",
        }
        after = {
            main: before[main].replace('select-old', 'select-challenge').replace(
                '    if: enabled',
                "    if: enabled && needs.test-scope.outputs.challenge_transition != 'true'",
            ) + '\n  challenge-transition:\n    run: challenge\n',
            dtl: before[dtl].replace('select-old', 'select-challenge').replace(
                "      - 'autoload/**'", "      - 'autoload/**'\n      - 'tools/testing/challenge_transition_scope.py'",
            ),
        }
        paths = {main, dtl, 'tools/testing/run_challenge_transition_checks.py'}

        def check(candidate, missing=None):
            def show(command, **_kwargs):
                ref, path = command[2].split(':', 1)
                if command[2] == missing:
                    return subprocess.CompletedProcess(command, 128, b'')
                source = before[path] if ref == 'base' else candidate[path]
                return subprocess.CompletedProcess(command, 0, source.encode())
            with patch('subprocess.run', side_effect=show):
                return is_challenge_transition(paths, 'base')

        self.assertTrue(check(after))
        for path, old, new in (
            (main, 'run: export', 'run: different-export'),
            (main, 'contents: read', 'contents: write'),
            (main, 'if: enabled', 'if: false'),
            (main, '  test-scope:', '  missing-scope:'),
            (dtl, 'run: author', 'run: different-authoring'),
            (dtl, 'contents: read', 'contents: write'),
            (dtl, "      - 'autoload/**'", "      - 'scripts/**'"),
            (dtl, '  scope:', '  missing-scope:'),
        ):
            with self.subTest(path=path, old=old):
                changed = dict(after)
                changed[path] = changed[path].replace(old, new)
                self.assertFalse(check(changed))
        for path in (main, dtl):
            with self.subTest(missing=path):
                self.assertFalse(check(after, missing='base:' + path))

    def test_paths_require_an_anchor_and_exclude_unrelated_content(self):
        anchor = {'tools/testing/challenge_transition_scope.py'}
        self.assertTrue(is_challenge_transition(anchor, 'base'))
        for extra in ('autoload/SaveManager.gd', 'dialogic/timelines/authored_week/Day1.dtl',
                      'scripts/domain/run/RunSnapshotSchema.gd', 'docs/agent/execution-map.md'):
            self.assertFalse(is_challenge_transition(anchor | {extra}, 'base'))
        self.assertFalse(is_challenge_transition(set(), 'base'))
        self.assertFalse(is_challenge_transition({'docs/agent/2026-11-10-challenge-ci-coverage-handoff.md'}, 'base'))
        self.assertFalse(is_challenge_transition({'.github/workflows/windows-tests.yml'}, 'base'))
        with patch('subprocess.run', return_value=subprocess.CompletedProcess([], 128, b'')):
            self.assertFalse(is_challenge_transition({'autoload/GameState.gd'}, 'missing'))


if __name__ == '__main__':
    unittest.main()
