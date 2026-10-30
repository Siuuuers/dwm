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


def select(paths, event_name='pull_request', sources=None, selector=SELECTOR):
    def git(args, **kwargs):
        if args[:3] == ['git', 'diff', '--name-only']:
            return subprocess.CompletedProcess(args, 0, ('\0'.join(sorted(paths)) + '\0').encode())
        if args[:2] == ['git', 'show'] and sources and args[2] in sources:
            return subprocess.CompletedProcess(args, 0, sources[args[2]].encode())
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
        event.write_text(json.dumps({'pull_request': {'base': {'sha': 'a' * 40}}}))
        with patch.dict(os.environ, {'GITHUB_EVENT_NAME': event_name,
                                     'GITHUB_EVENT_PATH': str(event), 'GITHUB_OUTPUT': str(output)}), \
                patch('subprocess.run', side_effect=git), contextlib.redirect_stdout(io.StringIO()):
            exec(compile(selector, 'workflow:scope', 'exec'), {})
        return dict(line.split('=', 1) for line in output.read_text().splitlines())


class WindowsCoverageTests(unittest.TestCase):
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
