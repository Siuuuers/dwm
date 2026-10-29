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


def select(paths, event_name='pull_request'):
    def git(args, **kwargs):
        if args[:3] == ['git', 'diff', '--name-only']:
            return subprocess.CompletedProcess(args, 0, ('\0'.join(sorted(paths)) + '\0').encode())
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
            exec(compile(SELECTOR, 'windows-tests.yml:scope', 'exec'), {})
        return dict(line.split('=', 1) for line in output.read_text().splitlines())


class WindowsCoverageTests(unittest.TestCase):
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

    def test_readability_matrix_retains_required_registered_suites(self):
        matrix = re.search(r"needs.test-scope.outputs.readability == 'true' && '([^']+)'", WORKFLOW)
        self.assertIsNotNone(matrix)
        actual = json.loads(matrix[1])
        required = {'settings', 'minesweeper', 'shop', 'desktop', 'localization', 'reading_delivery',
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

    def test_empty_metadata_only_and_manual_dispatch_do_not_select_readability(self):
        for paths in (set(), {'.github/workflows/windows-tests.yml'},
                      {'evidence/readability/2026-10-30/completion.md'}):
            self.assertEqual(select(paths)['readability'], 'false')
        self.assertEqual(select(self.approved_paths(), 'workflow_dispatch')['readability'], 'false')


if __name__ == '__main__':
    unittest.main()
