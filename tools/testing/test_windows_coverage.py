"""Exercise the workflow's real coverage selector without Godot or a checkout fetch."""
import ast
import contextlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = (ROOT / '.github/workflows/windows-tests.yml').read_text()
SELECTOR = textwrap.dedent(WORKFLOW.split('        shell: python\n        run: |\n', 1)[1].split('\n  focused-tests:', 1)[0])
DAY = 'dialogic/timelines/authored_week/Day1.dtl'
GENERATED = {
    'data/manifests/scene_story_registration.json',
    'data/manifests/dialogue_library_registration.json',
    'data/manifests/story_start.json',
}


def select(paths, event_name='pull_request', sources=None, selector=SELECTOR, diff_code=0, event_data=None, commands=None, check_code=0):
    def git(args, **kwargs):
        if commands is not None:
            commands.append(args)
        if args[:3] == ['git', 'diff', '--check']:
            if check_code and kwargs.get('check'):
                raise subprocess.CalledProcessError(check_code, args)
            return subprocess.CompletedProcess(args, check_code, b'')
        if args[:3] == ['git', 'diff', '--name-only']:
            return subprocess.CompletedProcess(args, diff_code, ('\0'.join(sorted(paths)) + '\0').encode())
        if args[:2] == ['git', 'show'] and args[2].startswith('HEAD^:'):
            args = args[:2] + [args[2].replace('HEAD^:', 'a' * 40 + ':', 1)]
        if args[:2] == ['git', 'show'] and sources and args[2] in sources:
            return subprocess.CompletedProcess(args, 0, sources[args[2]].encode())
        if args[:2] == ['git', 'show'] and args[2].endswith(':.github/workflows/windows-tests.yml'):
            return subprocess.CompletedProcess(args, 1, b'')
        # An unrelated runtime edit may invoke the existing archived benchmark
        # compatibility check. Supply an intentionally incompatible old fixture.
        if args[:2] == ['git', 'show'] and args[2].endswith('.zip'):
            archive = io.BytesIO()
            with zipfile.ZipFile(archive, 'w') as output:
                output.writestr('terminal-root/saves/slot_2.json', json.dumps({
                    'current_snapshot': {'snapshot': {'gameplay': {}}}}))
            return subprocess.CompletedProcess(args, 0, archive.getvalue())
        if args[:2] == ['git', 'show'] and args[2].endswith(':scripts/domain/run/RunSnapshotSchema.gd'):
            return subprocess.CompletedProcess(args, 0, b'const SCENE_GAMEPLAY_KEYS := ["current"]')
        raise AssertionError('Unexpected selector command: ' + repr(args))

    with tempfile.TemporaryDirectory() as temporary:
        event = Path(temporary) / 'event.json'
        output = Path(temporary) / 'output'
        event.write_text(json.dumps(event_data if event_data is not None else {'pull_request': {'base': {'sha': 'a' * 40}}}))
        with patch.dict(os.environ, {'GITHUB_EVENT_NAME': event_name,
                                     'GITHUB_EVENT_PATH': str(event), 'GITHUB_OUTPUT': str(output)}), \
                patch('subprocess.run', side_effect=git), contextlib.redirect_stdout(io.StringIO()):
            exec(compile(selector, 'workflow:scope', 'exec'), {})
        return dict(line.split('=', 1) for line in output.read_text().splitlines())


class WindowsCoverageTests(unittest.TestCase):
    def test_native_audio_integration_selects_its_own_workflow(self):
        paths = {
            '.github/workflows/native-audio.yml',
            '.github/workflows/windows-tests.yml',
            '.gitignore',
            'autoload/ApplicationBootstrap.gd',
            'autoload/AudioManager.gd',
            'export_presets.cfg',
            'project.godot',
            'scripts/audio/AudioPlaybackPort.gd',
            'scripts/data/AudioManifest.gd',
            'scripts/narrative/DialogicEntryManifest.gd',
            'scripts/ui/MenuScene.gd',
            'tests/support/FakeAudioPlaybackPort.gd',
            'tests/unit/test_audio_manager.gd',
            'tests/unit/test_inline_audio_authoring.gd',
            'tests/unit/test_scene_audio_manager.gd',
            'tests/unit/test_scene_audio_manifest.gd',
            'tools/audio_prototype/build_gd_libvgm.py',
            'tools/audio_prototype/game_smoke.gd',
            'tools/audio_prototype/verify_game.py',
            'tools/audio_prototype/README.md',
            'tools/authoring/AuthoredWeekRegistration.gd',
            'tools/testing/test_windows_coverage.py',
            'docs/audio/native-audio.md',
        }
        for event, data in (
            ('pull_request', {'pull_request': {'base': {'sha': 'a' * 40}}}),
            ('push', {'before': 'a' * 40}),
            ('pull_request', {'action': 'synchronize', 'before': 'b' * 40,
                              'pull_request': {'base': {'sha': 'a' * 40}}}),
        ):
            commands = []
            result = select(paths, event_name=event, event_data=data, commands=commands)
            self.assertEqual(result['native_audio'], 'true')
            self.assertEqual(result['inventory_tooling'], 'false')
            self.assertEqual(result['comparison'], 'false')
            self.assertFalse(any('b' * 40 in arg for args in commands for arg in args))
        self.assertEqual(select(paths | {'tools/audio_prototype/game_smoke.gd.uid'})['native_audio'], 'true')
        for unrelated in ('autoload/GameState.gd', 'autoload/SaveManager.gd',
                          'scripts/ui/Other.gd.uid', 'tools/audio_prototype/other.py',
                          'docs/audio/other.md', '.github/workflows/other.yml'):
            sources = {'a' * 40 + ':autoload/ApplicationBootstrap.gd': '',
                       'HEAD:autoload/ApplicationBootstrap.gd': ''}
            self.assertEqual(select(paths | {unrelated}, sources=sources)['native_audio'], 'false', unrelated)

    def test_native_audio_requires_its_anchor_and_a_known_diff(self):
        self.assertEqual(select({'autoload/AudioManager.gd'})['native_audio'], 'false')
        paths = {'.github/workflows/native-audio.yml', 'autoload/AudioManager.gd'}
        for kwargs in ({'event_name': 'workflow_dispatch'}, {'diff_code': 128}, {'event_data': {}}):
            self.assertEqual(select(paths, **kwargs)['native_audio'], 'false')

    def test_native_audio_gates_broad_runtime_export_and_render_jobs(self):
        for job in ('focused-tests', 'windows-export', 'public-surfaces',
                    'rendered-journeys', 'rendered-desktop'):
            section = WORKFLOW.split('  ' + job + ':', 1)[1].split('    steps:', 1)[0]
            self.assertIn("needs.test-scope.outputs.native_audio != 'true'", section)

    def test_ci_job_edits_select_only_their_owners(self):
        workflow = '.github/workflows/windows-tests.yml'
        test = 'tools/testing/test_inventory_runner.py'
        for names, paths in (
            (['inventory-tooling'], {workflow}),
            (['rendered-desktop'], {workflow}),
            (['inventory-tooling', 'rendered-desktop'], {workflow, test}),
            (['inventory-tooling'], {test}),
        ):
            before = WORKFLOW
            for name in names:
                label = {'inventory-tooling': 'Linux / inventory tooling',
                         'rendered-desktop': 'Rendered desktop and dialogue / Linux software OpenGL'}[name]
                before = before.replace('    name: ' + label, '    name: Previous ' + label, 1)
            for event, data in (
                ('pull_request', {'pull_request': {'base': {'sha': 'a' * 40}}}),
                ('push', {'before': 'a' * 40}),
                ('pull_request', {'action': 'synchronize', 'before': 'b' * 40,
                                  'pull_request': {'base': {'sha': 'a' * 40}}}),
            ):
                commands = []
                result = select(paths, event_name=event, event_data=data, commands=commands,
                                sources={'a' * 40 + ':' + workflow: before, 'HEAD:' + workflow: WORKFLOW})
                self.assertEqual(json.loads(result['ci_jobs']), names)
                self.assertEqual(result['inventory_tooling'], str('inventory-tooling' in names).lower())
                for key in ('comparison', 'progression', 'self_talk_panel'):
                    self.assertEqual(result[key], 'false', key)
                self.assertFalse(any('b' * 40 in arg or '.zip' in arg for args in commands for arg in args))

    def test_ci_route_keeps_shared_workflow_changes_broad(self):
        workflow = '.github/workflows/windows-tests.yml'
        variants = (
            WORKFLOW.replace('contents: read', 'contents: write', 1),
            WORKFLOW.replace('cancel-in-progress: true', 'cancel-in-progress: false', 1),
            WORKFLOW.replace('  test-scope:', '  test-scope: # changed', 1),
            WORKFLOW.replace('  windows-export:', '  windows-export: # changed', 1),
            WORKFLOW.replace('  inventory-tooling:', '  renamed-inventory:', 1),
            WORKFLOW + '\n  inventory-tooling:\n    runs-on: ubuntu-24.04\n',
            WORKFLOW + '\n  "other-job":\n    runs-on: ubuntu-24.04\n',
            WORKFLOW + '\nenv:\n  EXTRA: value\n',
        )
        for before in variants:
            result = select({workflow}, sources={'a' * 40 + ':' + workflow: before, 'HEAD:' + workflow: WORKFLOW})
            self.assertEqual(result['ci_jobs'], '[]')
        for path in ('tools/testing/test_windows_coverage.py', 'tools/testing/run_inventory_checks.py',
                     'autoload/GameState.gd', '.github/workflows/source-lint.yml'):
            result = select({workflow, path}, sources={'a' * 40 + ':' + workflow: WORKFLOW,
                                                       'HEAD:' + workflow: WORKFLOW})
            self.assertEqual(result['ci_jobs'], '[]', path)
        for kwargs in ({}, {'event_name': 'workflow_dispatch'}, {'diff_code': 128}, {'event_data': {}}):
            self.assertEqual(select({workflow}, **kwargs)['ci_jobs'], '[]')

    def test_ci_route_gates_unrelated_jobs(self):
        for name in ('focused-tests', 'windows-export', 'public-surfaces', 'rendered-journeys'):
            header = WORKFLOW.split('  ' + name + ':', 1)[1].split('    steps:', 1)[0]
            self.assertIn("needs.test-scope.outputs.ci_jobs == '[]'", header)
        header = WORKFLOW.split('  rendered-desktop:', 1)[1].split('    steps:', 1)[0]
        self.assertIn("contains(needs.test-scope.outputs.ci_jobs, '\"rendered-desktop\"')", header)
        self.assertIn("needs.test-scope.outputs.ci_jobs == '[]'", header)

    def test_reviewed_prose_selects_docs_checks_for_pr_and_push(self):
        paths = {'docs/agent/new-technical-handoff.md', 'docs/agent/2026-11-04-f5-baseline.md'}
        for event, data, base in (
            ('pull_request', {'pull_request': {'base': {'sha': 'a' * 40}}}, 'HEAD^'),
            ('push', {'before': 'a' * 40}, 'a' * 40),
        ):
            commands = []
            result = select(paths, event_name=event, event_data=data, commands=commands)
            self.assertEqual(result['docs_only'], 'true')
            self.assertIn(['git', 'diff', '--check', base, 'HEAD', '--', *sorted(paths)], commands)
            for key in ('inventory_tooling', 'self_talk_panel', 'progression', 'comparison'):
                self.assertEqual(result[key], 'false', key)

    def test_proven_narrow_scopes_ignore_superseded_runtime_changes(self):
        event = {'action': 'synchronize', 'before': 'b' * 40,
                 'pull_request': {'base': {'sha': 'a' * 40}}}
        for path, scope in (('docs/agent/prose.md', 'docs_only'),
                            ('tools/runtime/PublicSurfaceInventory.gd', 'inventory_only')):
            commands = []
            result = select({path}, event_data=event, commands=commands)
            self.assertEqual(result[scope], 'true')
            self.assertEqual(result['comparison'], 'false')
            self.assertFalse(any('b' * 40 in arg or '.zip' in arg for args in commands for arg in args))

    def test_docs_contracts_other_markdown_and_mixed_changes_retain_coverage(self):
        prose = 'docs/agent/new-technical-handoff.md'
        for path in ('docs/agent/execution-map.md', 'docs/agent/2026-09-23-next-session-handoff.md',
                     'docs/agent/nested/note.md', 'story/README.md', 'README.md', 'AGENTS.md',
                     'docs/design/rule.md', 'docs/superpowers/plans/plan.md', 'evidence/result.md',
                     'tests/fixtures/README.md', 'autoload/GameState.gd', 'autoload/SaveManager.gd',
                     DAY, 'autoload/AudioManager.gd', 'tools/runtime/PublicSurfaceInventory.gd',
                     'tests/unit/tooling/test_public_surface_inventory.gd',
                     'tools/testing/test_windows_coverage.py', '.github/workflows/windows-tests.yml',
                     'docs/agent/result.json'):
            with self.subTest(path=path):
                result = select({prose, path})
                self.assertEqual(result['docs_only'], 'false')
        for kwargs in ({'event_name': 'workflow_dispatch'}, {'diff_code': 128}, {'event_data': {}}):
            self.assertEqual(select({prose}, **kwargs)['docs_only'], 'false')
        self.assertEqual(select(set())['docs_only'], 'false')
        result = select({prose, 'tests/unit/tooling/test_public_surface_inventory.gd'})
        self.assertEqual(result['inventory_tooling'], 'true')

    def test_docs_route_gates_broad_jobs_and_reports_whitespace_failure(self):
        with self.assertRaises(subprocess.CalledProcessError):
            select({'docs/agent/prose.md'}, check_code=2)
        for job in ('focused-tests', 'windows-export', 'public-surfaces', 'rendered-journeys', 'rendered-desktop'):
            section = WORKFLOW.split('  ' + job + ':', 1)[1].split('    steps:', 1)[0]
            self.assertIn("needs.test-scope.outputs.docs_only != 'true'", section)
        with tempfile.TemporaryDirectory() as directory:
            subprocess.run(['git', 'init', '-q', directory], check=True)
            path = Path(directory, 'docs/agent/prose.md')
            path.parent.mkdir(parents=True)
            path.write_text('Clean prose.\n')
            subprocess.run(['git', '-C', directory, 'add', '.'], check=True)
            path.write_text('Trailing whitespace.  \n')
            result = subprocess.run(['git', '-C', directory, 'diff', '--check', '--', 'docs/agent/prose.md'],
                                    capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'trailing whitespace', result.stdout)

    def test_closed_pr_cancels_its_group_without_starting_validation(self):
        triggers = WORKFLOW.split('\non:\n', 1)[1].split('\npermissions:', 1)[0]
        pull_request = triggers.split('  pull_request:\n', 1)[1].split('  push:', 1)[0]
        types = re.search(r'^    types: \[(.*?)\]$', pull_request, re.M)[1]
        self.assertEqual([value.strip() for value in types.split(',')],
                         ['opened', 'synchronize', 'reopened', 'closed'])
        self.assertIn('  push:\n    branches: [master]', triggers)
        self.assertIn('  workflow_dispatch:', triggers)
        concurrency = WORKFLOW.split('\nconcurrency:\n', 1)[1].split('\njobs:', 1)[0]
        self.assertIn('group: windows-tests-${{ github.event.pull_request.number || github.ref }}', concurrency)
        self.assertIn('cancel-in-progress: true', concurrency)
        jobs = dict(re.findall(r'(?ms)^  ([\w-]+):\n(.*?)(?=^  [\w-]+:|\Z)',
                               WORKFLOW.split('\njobs:\n', 1)[1]))
        self.assertIn("    if: github.event.action != 'closed'\n", jobs['test-scope'])
        closed = jobs.pop('closed-pr')
        self.assertIn("    if: github.event.action == 'closed'\n", closed)
        self.assertNotIn('uses:', closed)
        self.assertEqual(closed.count('      - run:'), 1)
        for name, job in jobs.items():
            if name == 'test-scope':
                continue
            with self.subTest(job=name):
                header = job.split('    steps:', 1)[0]
                self.assertIn('    needs: test-scope\n', header)
                condition = re.search(r'^    if: (.*)$', header, re.M)[1]
                self.assertNotRegex(condition, r'\b(?:always|cancelled|failure)\s*\(')

    def test_inventory_sources_and_test_only_select_linux(self):
        for path in ('tools/runtime/PublicSurfaceInventory.gd',
                     'tools/runtime/generate_public_surface_inventory.gd',
                     'tests/unit/tooling/test_public_surface_inventory.gd'):
            for paths in ({path}, {path, path + '.uid',
                                  'evidence/phase_2r/runtime/game_state_surface.json',
                                  'evidence/phase_2r/runtime/save_manager_surface.json'}):
                with self.subTest(paths=paths):
                    result = select(paths)
                    self.assertEqual(result['inventory_tooling'], 'true')
                    self.assertEqual(result['inventory_only'], 'true')
                    self.assertEqual(result['comparison'], 'false')

    def test_inventory_mixed_changes_preserve_runtime_coverage(self):
        source = 'tools/runtime/PublicSurfaceInventory.gd'
        for companion in ('autoload/GameState.gd', 'autoload/SaveManager.gd', DAY,
                          'scenes/Title.tscn', 'autoload/AudioManager.gd',
                          'unknown.gd', 'tools/testing/Invoke-PublicSurfaceValidation.ps1',
                          'evidence/phase_2r/runtime/game_state_required_surface.json',
                          '.github/workflows/windows-tests.yml',
                          'tools/testing/test_windows_coverage.py'):
            with self.subTest(companion=companion):
                result = select({source, companion})
                self.assertEqual(result['inventory_tooling'], 'true')
                self.assertEqual(result['inventory_only'], 'false')
                for key in ('focused', 'self_talk_panel', 'progression', 'dtl_content'):
                    self.assertEqual(result[key], 'false', key)
        for path in ('evidence/phase_2r/runtime/game_state_surface.json',
                     'docs/agent/2026-11-04-inventory-preflight-efficiency.md',
                     source + '.uid'):
            self.assertEqual(select({path})['inventory_only'], 'false')

    def test_inventory_events_and_unavailable_base(self):
        paths = {'tools/runtime/PublicSurfaceInventory.gd'}
        commands = []
        self.assertEqual(select(paths, commands=commands)['inventory_only'], 'true')
        self.assertIn(['git', 'diff', '--name-only', '-z', '--no-renames', 'HEAD^', 'HEAD'], commands)
        commands.clear()
        result = select(paths, 'push', event_data={'before': 'b' * 40}, commands=commands)
        self.assertEqual(result['inventory_only'], 'true')
        self.assertIn(['git', 'diff', '--name-only', '-z', '--no-renames', 'b' * 40, 'HEAD'], commands)
        for kwargs in ({'event_name': 'workflow_dispatch'}, {'diff_code': 128},
                       {'event_data': {}}, {'event_name': 'push', 'event_data': {'before': '0' * 40}}):
            self.assertEqual(select(paths, **kwargs)['inventory_only'], 'false')

    def test_inventory_renames_keep_both_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            def git(*args):
                return subprocess.check_output(['git', '-C', directory, *args])
            git('init', '-q')
            git('config', 'user.email', 'test@example.invalid')
            git('config', 'user.name', 'Test')
            old = Path(directory, 'runtime.gd')
            old.write_text('extends RefCounted\n')
            git('add', '.')
            git('commit', '-qm', 'base')
            new = Path(directory, 'tools/runtime/PublicSurfaceInventory.gd')
            new.parent.mkdir(parents=True)
            old.rename(new)
            git('add', '-A')
            git('commit', '-qm', 'rename')
            paths = set(git('diff', '--name-only', '-z', '--no-renames', 'HEAD^', 'HEAD').decode().strip('\0').split('\0'))
            self.assertEqual(paths, {'runtime.gd', 'tools/runtime/PublicSurfaceInventory.gd'})
            self.assertEqual(select(paths)['inventory_only'], 'false')
            self.assertEqual(select({'tools/runtime/PublicSurfaceInventory.gd'})['inventory_tooling'], 'true')

    def test_inventory_job_is_required_and_broad_jobs_are_gated(self):
        for job in ('focused-tests', 'windows-export', 'public-surfaces', 'rendered-journeys', 'rendered-desktop'):
            section = WORKFLOW.split('  ' + job + ':', 1)[1].split('    steps:', 1)[0]
            self.assertIn("needs.test-scope.outputs.inventory_only != 'true'", section)
        section = WORKFLOW.split('  inventory-tooling:', 1)[1]
        self.assertIn('needs: test-scope', section)
        self.assertIn("if: needs.test-scope.outputs.inventory_tooling == 'true'", section)
        self.assertNotIn('continue-on-error:', section)
        self.assertIn('run: python tools/testing/run_inventory_checks.py', section)
        self.assertIn('python tools/testing/test_inventory_runner.py', WORKFLOW)
        self.assertIn('/tools/testing/test_inventory_runner.py', WORKFLOW)
        for path in ('tools/testing/run_inventory_checks.py', 'tools/testing/test_inventory_runner.py',
                     'tools/testing/test_windows_coverage.py', '.github/workflows/windows-tests.yml'):
            self.assertEqual(select({path})['inventory_tooling'], 'true')
            self.assertEqual(select({path})['inventory_only'], 'false')
        dtl = (ROOT / '.github/workflows/dtl-first-preflight.yml').read_text()
        triggers = dtl.split('  pull_request:', 1)[1].split('permissions:', 1)[0]
        self.assertNotIn('tools/runtime', triggers)
        self.assertNotIn('tests/unit/tooling', triggers)

    def test_lint_only_paths_skip_gameplay_for_push_and_pull_request(self):
        triggers = WORKFLOW.split('\non:\n', 1)[1].split('\npermissions:', 1)[0]
        expected = {
            '.github/workflows/audio-prototype.yml',
            'tools/audio_prototype/**',
            '.github/workflows/source-lint.yml',
            'tools/lint/check_comments.py',
            'tools/lint/test_comments.py',
            'tools/lint/check_python.py',
            'tools/lint/test_python.py',
            'docs/agent/2026-11-03-ci-efficiency-handoff.md',
        }
        for event in ('pull_request', 'push'):
            block = re.search(r'(?ms)^  ' + event + r':\n(.*?)(?=^  \w+:|\Z)', triggers)[1]
            ignored = re.findall(r"^      - '([^']+)'$", block, re.M)
            self.assertIn('    paths-ignore:\n', block)
            self.assertEqual(set(ignored), expected)
            self.assertEqual(len(ignored), len(expected))
        self.assertIn('  workflow_dispatch:', triggers)

    def test_audio_prototype_uses_its_workflow_and_retains_runtime_coverage(self):
        paths = {
            'tools/audio_prototype/project.godot',
            'tools/audio_prototype/fixtures/loop.txt',
            'CLAUDE.md',
            '.github/workflows/audio-prototype.yml',
            '.github/workflows/windows-tests.yml',
            'tools/testing/test_windows_coverage.py',
        }
        result = select(paths)
        self.assertEqual(result['audio_prototype'], 'true')
        self.assertEqual(result['comparison'], 'false')
        self.assertEqual(select(paths, 'workflow_dispatch')['audio_prototype'], 'false')
        self.assertEqual(select({'.github/workflows/windows-tests.yml'})['audio_prototype'], 'false')
        for unrelated in ('autoload/AudioManager.gd', 'scripts/audio/AudioPlaybackPort.gd',
                          'project.godot', 'tools/audio_prototype_other/check.py'):
            self.assertEqual(select(paths | {unrelated})['audio_prototype'], 'false')
        for job in ('focused-tests', 'windows-export', 'public-surfaces',
                    'rendered-journeys', 'rendered-desktop'):
            section = WORKFLOW.split('  ' + job + ':', 1)[1].split('    steps:', 1)[0]
            self.assertIn("needs.test-scope.outputs.audio_prototype != 'true'", section)

    def test_self_talk_panel_uses_linux_only_for_the_reviewed_shared_methods(self):
        owners = {
            'autoload/DialogicBridge.gd': 'get_reading_history',
            'scripts/narrative/SoloReadingSession.gd': 'project_self_talk',
            'scripts/ui/witnessed/WitnessedCaptionLayer.gd': '_sync_transport',
        }
        paths = set(owners) | {
            'scripts/ui/witnessed/WitnessedSelfTalk.gd',
            'tests/unit/test_scene_self_talk.gd', 'tests/unit/test_witnessed_self_talk.gd',
            'tests/ui/render_self_talk_journey.gd', 'tests/ui/render_self_talk_load.gd',
            'tests/ui/render_self_talk_base.gd', 'tests/ui/render_self_talk_transport.gd',
            'tests/ui/render_self_talk_choices.gd', '.github/workflows/windows-tests.yml',
            'tests/integration/test_witnessed_caption_runtime.gd',
            'tools/testing/test_windows_coverage.py', 'tools/testing/self_talk_panel_scope.py',
            '.github/workflows/dtl-first-preflight.yml',
            'docs/agent/2026-10-30-self-talk-panel-implementation.md',
        }
        sources = {}
        for path, method in owners.items():
            for ref, value in [('a' * 40, 1), ('HEAD', 2)]:
                sources[ref + ':' + path] = f'func {method}():\n\treturn {value}\nfunc unrelated():\n\treturn 1\n'
        self.assertEqual(select(paths, sources=sources)['self_talk_panel'], 'true')
        self.assertEqual(select(paths | {'autoload/SaveManager.gd'}, sources=sources)['self_talk_panel'], 'false')
        self.assertEqual(select(paths, 'workflow_dispatch', sources=sources)['self_talk_panel'], 'false')
        for path in owners:
            changed = dict(sources)
            changed['HEAD:' + path] += 'func new_behavior():\n\tpass\n'
            self.assertEqual(select(paths, sources=changed)['self_talk_panel'], 'false')
        dtl = (ROOT / '.github/workflows/dtl-first-preflight.yml').read_text()
        dtl_selector = textwrap.dedent(dtl.split('        shell: python\n        run: |\n', 1)[1].split('  authoring:', 1)[0])
        self.assertEqual(select(paths, sources=sources, selector=dtl_selector)['presentation_only'], 'true')
        self.assertEqual(select(paths | {DAY}, sources=sources, selector=dtl_selector)['presentation_only'], 'false')
        self.assertEqual(select(paths, 'workflow_dispatch', sources=sources, selector=dtl_selector)['presentation_only'], 'false')
        self.assertIn('from self_talk_panel_scope import is_self_talk_panel', dtl)
        self.assertIn("if: needs.scope.outputs.presentation_only != 'true'", dtl)
        linux = WORKFLOW.split('  self-talk-panel:', 1)[1]
        self.assertIn("if: needs.test-scope.outputs.self_talk_panel == 'true'", linux)
        for job in ('focused-tests', 'windows-export', 'public-surfaces', 'rendered-journeys', 'rendered-desktop'):
            section = WORKFLOW.split('  ' + job + ':', 1)[1].split('    steps:', 1)[0]
            self.assertIn("needs.test-scope.outputs.self_talk_panel != 'true'", section)

    def test_progression_selects_linux_and_retains_unrelated_owner_coverage(self):
        path = 'autoload/DialogicBridge.gd'
        paths = {path, 'tools/testing/progression_scope.py',
                 'tools/testing/run_progression_checks.py',
                 'tools/verification/story_progression/StoryProgression.tla',
                 'tests/integration/test_dialogic_next_traversal.gd'}
        before = ('var _next_active := false\nfunc _perform_next():\n\treturn 1\n'
                  'func capture_reading_checkpoint():\n\treturn not _next_active\n')
        after = ('var _progression_phase := ProgressionPhase.IDLE\n'
                 'func _perform_next():\n\treturn 2\n'
                 'func capture_reading_checkpoint():\n'
                 '\treturn _progression_phase != ProgressionPhase.NEXT_ACTIVE\n')
        sources = {'a' * 40 + ':' + path: before, 'HEAD:' + path: after}
        self.assertEqual(select(paths, sources=sources)['progression'], 'true')
        self.assertEqual(select(paths, sources=sources)['comparison'], 'false')
        self.assertEqual(select(paths, 'workflow_dispatch', sources=sources)['progression'], 'false')
        self.assertEqual(select(paths | {'autoload/SaveManager.gd'}, sources=sources)['progression'], 'false')
        for addition in ('func unrelated():\n\tpass\n', 'var extra_owner := true\n'):
            changed = dict(sources)
            changed['HEAD:' + path] += addition
            self.assertEqual(select(paths, sources=changed)['progression'], 'false')
        changed = dict(sources)
        changed['HEAD:' + path] = after.replace('!= ProgressionPhase.NEXT_ACTIVE', '== ProgressionPhase.IDLE')
        self.assertEqual(select(paths, sources=changed)['progression'], 'false')
        dtl = (ROOT / '.github/workflows/dtl-first-preflight.yml').read_text()
        dtl_selector = textwrap.dedent(dtl.split('        shell: python\n        run: |\n', 1)[1].split('  authoring:', 1)[0])
        self.assertEqual(select(paths, sources=sources, selector=dtl_selector)['presentation_only'], 'true')
        self.assertEqual(select(paths | {DAY}, sources=sources, selector=dtl_selector)['presentation_only'], 'false')
        for job in ('focused-tests', 'windows-export', 'public-surfaces', 'rendered-journeys', 'rendered-desktop'):
            section = WORKFLOW.split('  ' + job + ':', 1)[1].split('    steps:', 1)[0]
            self.assertIn("needs.test-scope.outputs.progression != 'true'", section)
        self.assertIn("if: needs.test-scope.outputs.progression == 'true'", WORKFLOW)

    def test_legacy_marker_methods_allow_only_the_reviewed_phase_substitutions(self):
        path = 'autoload/DialogicBridge.gd'
        before = (
            'func _perform_marker_next(expected: Dictionary) -> Dictionary:\n'
            '\tif _line_ack_in_progress or _auto_step_in_progress or _skip_step_in_progress or is_pause_restore_pending():\n'
            '\t\treturn _command_failure(&"reading_next_unavailable")\n'
            '\treturn await _run_marker_next(source, expected)\n'
            'func _run_marker_next(source: Dictionary, expected: Dictionary) -> Dictionary:\n'
            '\t_next_active = true\n\t_next_command = expected.duplicate(true)\n'
            '\tcommitted = _scene_event_port.dispatch_owned(event, _marker_lease, _marker_seal.duplicate(true))\n'
            '\treturn _narrative_checkpoint_port.commit_reading_next(destination, operation_id, "destination")\n'
        )
        after = before.replace(
            '_line_ack_in_progress or _auto_step_in_progress or _skip_step_in_progress or ', ''
        ).replace('\t_next_active = true\n\t_next_command = expected.duplicate(true)\n',
                  '\t_progression_phase = ProgressionPhase.NEXT_ACTIVE\n')
        sources = {'a' * 40 + ':' + path: before, 'HEAD:' + path: after}
        self.assertEqual(select({path}, sources=sources)['progression'], 'true')
        for old, new in (
            ('dispatch_owned(event,', 'dispatch_owned(other_event,'),
            ('commit_reading_next(destination,', 'commit_reading_next(source,'),
            ('if is_pause_restore_pending():', 'if false:'),
        ):
            with self.subTest(changed=old):
                changed = dict(sources)
                changed['HEAD:' + path] = after.replace(old, new)
                self.assertEqual(select({path}, sources=changed)['progression'], 'false')

    def test_model_only_changes_keep_the_protocol_check(self):
        paths = {'tools/verification/story_progression/StoryProgression.tla',
                 'tools/verification/story_progression/README.md',
                 'tools/verification/story_progression/check_witnesses.py',
                 'tools/verification/story_progression/test_check_witnesses.py',
                 'tools/testing/run_progression_checks.py',
                 'tools/testing/test_progression_runner.py'}
        self.assertEqual(select(paths)['progression'], 'true')
        self.assertEqual(select(paths)['comparison'], 'false')
        self.assertEqual(select(paths | {'autoload/SaveManager.gd'})['progression'], 'false')
        self.assertEqual(select({'tools/verification/story_progression/unreviewed.py'})['progression'], 'false')
        self.assertEqual(select({'tools/testing/progression_scope.py'})['progression'], 'false')
        progression = WORKFLOW.split('  progression:', 1)[1]
        self.assertIn('speech-dispatcher-espeak-ng', progression)
        self.assertIn('run: bash tools/testing/start_cloud_speech.sh', progression)

    def test_progression_job_only_changes_keep_focused_coverage(self):
        path = '.github/workflows/windows-tests.yml'
        prefix = 'jobs:\n  test-scope:\n    run: select\n'
        block = '  progression:\n    run: old-setup\n'
        before = prefix + block
        after = before.replace('old-setup', 'new-setup')
        sources = {'a' * 40 + ':' + path: before, 'HEAD:' + path: after}
        paths = {path, 'tools/testing/progression_scope.py',
                 'tools/testing/test_windows_coverage.py',
                 'docs/agent/2026-11-03-ci-efficiency-handoff.md'}
        self.assertEqual(select(paths, sources=sources)['progression'], 'true')
        self.assertEqual(select(paths, sources=sources)['comparison'], 'false')
        self.assertEqual(select(paths)['progression'], 'false')
        for companion in ('.github/workflows/dtl-first-preflight.yml', '.github/workflows/source-lint.yml',
                          'tests/integration/test_dialogic_skip.gd'):
            self.assertEqual(select(paths | {companion}, sources=sources)['progression'], 'false')
        following = '  another-job:\n    run: unchanged\n'
        followed = {key: value + following for key, value in sources.items()}
        self.assertEqual(select(paths, sources=followed)['progression'], 'true')
        for old, new in (
            (before, after.replace('run: select', 'run: different-selector')),
            (before, after + following),
            (before, after + '  another-job: {runs-on: ubuntu-latest}\n'),
            (before, after + '  "another-job":\n    run: changed\n'),
            (before, after + 'env:\n  GLOBAL: changed\n'),
            (before + following, after + following.replace('unchanged', 'changed')),
            (prefix, after),
            (before, prefix),
            (before, after + block),
        ):
            with self.subTest(before=old, after=new):
                changed = {'a' * 40 + ':' + path: old, 'HEAD:' + path: new}
                self.assertEqual(select(paths, sources=changed)['progression'], 'false')

    def test_runner_and_lint_changes_keep_focused_runtime_coverage(self):
        lint = {'.github/workflows/source-lint.yml', 'tools/lint/check_python.py',
                'tools/lint/test_python.py', 'docs/agent/2026-11-03-ci-efficiency-handoff.md'}
        runner = {'tools/testing/run_progression_checks.py',
                  'tools/testing/test_progression_runner.py'}
        self.assertEqual(select(lint)['progression'], 'false')
        self.assertEqual(select(runner)['progression'], 'true')
        self.assertEqual(select(lint | runner)['progression'], 'true')
        self.assertEqual(select(lint | runner | {'autoload/SaveManager.gd'})['progression'], 'false')

    def test_dtl_only_and_generated_companions_select_content(self):
        for paths in ({DAY}, {DAY} | GENERATED | {'docs/agent/dtl-story-authoring.md'}):
            with self.subTest(paths=paths):
                result = select(paths)
                self.assertEqual(result['dtl_content'], 'true')
                self.assertEqual(result['dtl_first'], 'false')
                self.assertEqual(result['comparison'], 'false')

    def test_new_nested_timeline_selects_content(self):
        self.assertEqual(select({'dialogic/timelines/authored_week/chapter/opening.dtl'})['dtl_content'], 'true')

    def test_companions_without_dtl_do_not_select_content(self):
        self.assertEqual(select(GENERATED)['dtl_content'], 'false')

    def test_unreviewed_sources_keep_broad_coverage(self):
        for path in ('autoload/GameState.gd', 'scripts/domain/run/RunSnapshotSchema.gd',
                     'data/manifests/authored_week_source.json', 'localization/story/en.csv',
                     'dialogic/timelines/other.dtl', 'tools/testing/test_windows_coverage.py'):
            with self.subTest(path=path):
                result = select({DAY, path})
                for mode in ('dtl_content', 'dtl_first', 'inline_audio', 'reading_layout', 'focused'):
                    self.assertEqual(result[mode], 'false', mode)

    def test_full_matrix_retains_cosmetic_purchase_load_and_new_run(self):
        expression = next(line for line in WORKFLOW.splitlines() if 'suite: ${{ fromJSON' in line)
        full = json.loads(expression.rsplit("|| '", 1)[1].split("'", 1)[0])
        self.assertEqual(full.count('shop_cosmetic_journey'), 1)

    def test_shop_layout_and_preview_select_existing_shop_coverage(self):
        paths = {'scripts/ui/ShopApp.gd', 'scripts/ui/ShopItemBox.gd',
                 'tests/ui/render_shop_mounted_sizing.gd', '.github/workflows/shop-sizing-preview.yml'}
        self.assertEqual(select(paths)['shop_cosmetics'], 'true')
        self.assertEqual(select(paths | {'autoload/GameState.gd'})['shop_cosmetics'], 'false')

    def test_scene_mount_changes_are_scoped_only_inside_layout_method(self):
        path = 'autoload/ApplicationBootstrap.gd'
        baseline = 'func _layout_scene_desktop(host, desktop):\n\tdesktop.size = Vector2(800, 720)\n\nfunc other():\n\tpass\n'
        sources = {'a' * 40 + ':' + path: baseline,
                   'HEAD:' + path: baseline.replace('800', '920')}
        paths = {path, 'scripts/ui/ShopApp.gd'}
        self.assertEqual(select(paths, sources=sources)['shop_cosmetics'], 'true')
        sources['HEAD:' + path] = sources['HEAD:' + path].replace('pass', 'return false')
        self.assertEqual(select(paths, sources=sources)['shop_cosmetics'], 'false')

    def test_empty_and_manual_dispatch_keep_broad_coverage(self):
        self.assertEqual(select(set())['dtl_content'], 'false')
        result = select({DAY}, 'workflow_dispatch')
        self.assertEqual(result.pop('ci_jobs'), '[]')
        self.assertTrue(all(value == 'false' for value in result.values()))

    def test_existing_reviewed_migration_still_selects_dtl_first(self):
        result = select({DAY, 'tools/authoring/DtlStorySource.gd'})
        self.assertEqual(result['dtl_first'], 'true')
        self.assertEqual(result['dtl_content'], 'false')

    def test_content_matrix_retains_all_manual_edit_suites(self):
        # Read the actual matrix expansion and runner's accepted suite names.
        include = re.search(r"include: \$\{\{ fromJSON\(needs.test-scope.outputs.dtl_content == 'true' && '([^']+)'", WORKFLOW)
        self.assertIsNotNone(include)
        actual = {item['suite'] for item in json.loads(include[1])}
        runner = (ROOT / 'tools/testing/Invoke-CloudTests.ps1').read_text()
        accepted = set(re.findall(r"'(scene_content_update_\w+)'", runner.split('[string]$Suite', 1)[0]))
        self.assertEqual(len(accepted), 12)
        self.assertEqual(actual, accepted)
        base = re.search(r"fromJSON\(\(needs.test-scope.outputs.dtl_content == 'true' \|\| needs.test-scope.outputs.dtl_first == 'true'\) && '([^']+)'", WORKFLOW)
        self.assertIsNotNone(base)
        self.assertEqual(len(json.loads(base[1])), 29)


class ReadabilityCoverageTests(unittest.TestCase):
    @staticmethod
    def approved_paths():
        for node in ast.walk(ast.parse(SELECTOR)):
            if isinstance(node, ast.Assign) and any(
                    isinstance(target, ast.Name) and target.id == 'readability_paths'
                    for target in node.targets):
                return ast.literal_eval(node.value)
        raise AssertionError('Readability allowlist missing')

    def test_complete_readability_slice_selects_its_coverage(self):
        paths = self.approved_paths()
        for candidate in (paths, {'scripts/settings/SettingsPreferenceRegistry.gd'},
                          {'scripts/display/WindowModePort.gd'}, {'scripts/ui/ShopApp.gd'},
                          {'scripts/ui/GalleryScene.gd'}, {'tools/dtl-editor/index.html'}):
            with self.subTest(paths=candidate):
                result = select(candidate)
                self.assertEqual(result['readability'], 'true')
                self.assertEqual(result['focused'], 'false')
                self.assertEqual(result['comparison'], 'false')

    def test_complete_pr_includes_the_already_committed_measurement_harness(self):
        # PR 159 base a0e3bb4 -> head 73d6c2f. The first measurement commit
        # predates the working-tree edits and must still participate in selection.
        paths = {
            '.github/workflows/readability.yml',
            '.github/workflows/windows-tests.yml',
            'docs/design/current-ui/settings-window-output.md',
            'docs/design/current-ui/settings.md',
            'evidence/readability/2026-10-30/measurements.json',
            'scripts/settings/SettingsPreferenceRegistry.gd',
            'scripts/ui/GalleryScene.gd',
            'tests/manual/verify_window_mode_native.gd',
            'tests/scene/test_settings_localization_scene.gd',
            'tests/scene/test_settings_window_mode_live.gd',
            'tests/ui/render_readability_measurements.gd',
            'tests/ui/render_ui_readability.gd',
            'tests/unit/test_bootstrap_window_output.gd',
            'tests/unit/test_profile_manager.gd',
            'tests/unit/test_profile_window_restore.gd',
            'tests/unit/test_settings_preference_registry.gd',
            'tests/unit/test_settings_window_transactions.gd',
            'tests/unit/test_window_mode_manager.gd',
            'tools/dtl-editor/README.md',
            'tools/dtl-editor/index.html',
            'tools/dtl-editor/readability-profile.json',
            'tools/dtl-editor/test.cjs',
            'tools/dtl-editor/update-profile.cjs',
            'tools/testing/Invoke-CloudTests.ps1',
            'tools/testing/test_windows_coverage.py',
        }
        self.assertEqual(select(paths)['readability'], 'true')
        self.assertEqual(select(paths | {'scripts/display/WindowModePort.gd',
                                       'tests/unit/test_window_mode_port.gd',
                                       'tools/testing/Get-NativeWindowBounds.ps1',
                                       'tests/integration/scene_computer_child.gd',
                                       'scripts/ui/ShopApp.gd',
                                       'tests/scene/test_shop_plate.gd',
                                       'evidence/phase_2r/runtime/game_state_surface.json',
                                       'evidence/phase_2r/runtime/save_manager_surface.json'})['readability'], 'true')

    def test_unreviewed_runtime_and_evidence_keep_broad_coverage(self):
        for extra in ('autoload/SaveManager.gd', 'autoload/ProfileManager.gd',
                      'autoload/GameState.gd', 'scripts/narrative/DialogicRuntimeAdapter.gd',
                      'scripts/ui/witnessed/WitnessedCaptionLayer.gd',
                      'scripts/settings/SettingsOutputTransactions.gd',
                      'scripts/ui/UnknownPanel.gd', 'localization/ui/en.json',
                      'evidence/readability/2026-10-30/unreviewed.json'):
            with self.subTest(extra=extra):
                result = select(self.approved_paths() | {extra})
                for mode in ('readability', 'reading_layout', 'dtl_content', 'dtl_first',
                             'inline_audio', 'bilingual_reading', 'dialogue_library',
                             'playtest_polish', 'self_talk', 'shop_cosmetics',
                             'save_ink', 'scene_transition', 'focused'):
                    self.assertEqual(result[mode], 'false', mode)

    def test_runtime_allowlist_has_only_the_four_reviewed_owners(self):
        runtime = {path for path in self.approved_paths()
                   if path.startswith(('autoload/', 'scripts/', 'scenes/', 'data/', 'dialogic/'))}
        self.assertEqual(runtime, {'scripts/display/WindowModePort.gd',
                                   'scripts/settings/SettingsPreferenceRegistry.gd',
                                   'scripts/ui/GalleryScene.gd', 'scripts/ui/ShopApp.gd'})

    def test_interaction_slice_keeps_focus_and_input_coverage(self):
        paths = {'.github/workflows/windows-tests.yml', '.github/workflows/readability.yml',
                 'tools/testing/test_windows_coverage.py', 'tools/testing/Invoke-CloudTests.ps1',
                 'scripts/ui/SceneHost.gd',
                 'scripts/ui/gallery/DialogueLibrary.gd',
                 'scripts/ui/witnessed/WitnessedCaptionLayer.gd',
                 'scripts/ui/witnessed/WitnessedTransportRail.gd',
                 'scripts/ui/witnessed/WitnessedTransportButton.gd',
                 'tests/integration/scene_apps_connected_child.gd',
                 'tests/scene/test_scene_host_controls.gd',
                 'tests/ui/render_dialogue_library.gd', 'tests/ui/render_interaction_states.gd',
                 'tests/unit/test_witnessed_transport_rail.gd',
                 'tests/unit/test_witnessed_transport_button.gd'}
        self.assertEqual(select(paths)['readability'], 'true')
        self.assertEqual(select(paths)['comparison'], 'false')
        paths |= {'evidence/phase_2r/runtime/game_state_surface.json',
                  'evidence/phase_2r/runtime/save_manager_surface.json'}
        self.assertEqual(select(paths)['readability'], 'true')
        for extra in ('autoload/SaveManager.gd', 'scripts/narrative/DialogicRuntimeAdapter.gd'):
            self.assertEqual(select(paths | {extra})['readability'], 'false')

    def test_initial_frame_batch_preserves_creation_in_narrow_routes(self):
        matrix = next(line for line in WORKFLOW.splitlines() if '        suite: ${{ fromJSON(' in line)
        arrays = [json.loads(value) for value in re.findall(r"'(\[[^']*\])'", matrix)]
        self.assertIn('scene_current_frames', arrays[-1])
        for suites in arrays:
            self.assertEqual(len(suites), len(set(suites)))
            if 'scene_current_frames' in suites:
                self.assertNotIn('scene_current_creation', suites)
        for scope in ('dtl_first', 'inline_audio'):
            selected = re.search(r"needs.test-scope.outputs." + scope + r" == 'true'\)? && '([^']+)'", matrix)
            self.assertIsNotNone(selected, scope)
            self.assertIn('scene_current_creation', json.loads(selected[1]))
            self.assertNotIn('scene_current_frames', json.loads(selected[1]))
        step = WORKFLOW.split('      - name: Run new-run creation with a fresh process and profile\n', 1)[1].split('      - name:', 1)[0]
        self.assertIn("if: ${{ !cancelled() && matrix.suite == 'scene_current_frames' && steps.focused_regression.outcome != 'skipped' }}", step)
        self.assertIn('run: ./tools/testing/Invoke-CloudTests.ps1 -Suite scene_current_creation', step)
        self.assertNotIn('continue-on-error', step)

    def test_readability_matrix_retains_required_registered_suites(self):
        matrix = re.search(r"needs.test-scope.outputs.readability == 'true' && '([^']+)'", WORKFLOW)
        self.assertIsNotNone(matrix)
        actual = json.loads(matrix[1])
        required = {'backup_current_build',
                    'scene_apps', 'scene_computer', 'self_talk_ui', 'scene_direct_controls',
                    'scene_day_history', 'current_quick_load',
                    'settings', 'minesweeper', 'shop', 'desktop', 'localization', 'reading_delivery',
                    'dialogue_library', 'bilingual_reading', 'self_talk_choices',
                    'authored_self_talk_choices', 'scene_controls_localization',
                    'current_title', 'new_account', 'persistence',
                    'scene_transition_pixels', 'scene_transition_journey',
                    'scene_transition_auto', 'scene_transition_reduced', 'scene_caption_challenge'}
        self.assertEqual(set(actual), required)
        self.assertEqual(len(actual), len(required), 'No duplicate suite jobs')
        runner = (ROOT / 'tools/testing/Invoke-CloudTests.ps1').read_text()
        accepted = set(re.findall(r"'([a-z_]+)'", runner.split('[string]$Suite', 1)[0]))
        self.assertTrue(required <= accepted)
        settings = re.search(r"(?ms)^    settings = @\((.*?)^    \)", runner)
        self.assertIsNotNone(settings)
        self.assertEqual(settings[1].count("'tests/unit/test_profile_window_restore.gd'"), 1)
        reading = re.search(r"(?ms)^    reading_delivery = @\((.*?)^    \)", runner)
        self.assertIsNotNone(reading)
        self.assertEqual(reading[1].count("'tests/unit/test_witnessed_transport_button.gd'"), 1)

    def test_empty_metadata_only_and_manual_dispatch_do_not_select_readability(self):
        for paths in (set(), {'.github/workflows/windows-tests.yml'},
                      {'evidence/readability/2026-10-30/completion.md'}):
            self.assertEqual(select(paths)['readability'], 'false')
        self.assertEqual(select(self.approved_paths(), 'workflow_dispatch')['readability'], 'false')


if __name__ == '__main__':
    unittest.main()
