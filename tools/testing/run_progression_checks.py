import os
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / '.godot/ci/progression'
NEXT = 'tests/integration/test_dialogic_next_traversal.gd'
SKIP = 'tests/integration/test_dialogic_skip.gd'
WRITE_REFUSAL_METHODS = (
    'test_source_write_refusal_keeps_native_source_and_retries_the_same_operation',
    'test_destination_write_refusal_keeps_exact_durable_source_then_retry_uses_identical_plan',
)
CASES = [
    ('next-partial', NEXT, 'test_partial_unseen_next_finishes_and_witnesses_current_line_then_seeks_in_same_activation'),
    ('next-nested', NEXT, 'test_next_acknowledgement_and_completion_signals_keep_outer_command_ownership'),
    ('next-exclusive', NEXT, 'test_exclusive_next_coalesces_identical_activation_and_blocks_every_intermediate_command'),
    ('next-write-refusal', NEXT, 'write_refusal_keeps_'),
    ('skip-nested', SKIP, 'test_skip_acknowledgement_blocks_competitors_and_returns_to_its_outer_step'),
    ('skip-refusal', SKIP, 'test_profile_write_failure_halts_advancement'),
    ('skip-unread', SKIP, 'test_read_only_stops_at_the_first_unread_line'),
    ('skip-boundary', SKIP, 'test_every_boundary_stops_the_skip_without_being_consumed'),
    ('auto-source', SKIP, 'test_auto_step_requires_acknowledged_complete_exact_source'),
    ('auto-boundary', SKIP, 'test_auto_step_stops_before_every_nontext_boundary_with_preference_on'),
]
JOURNEYS = [
    ('thought-create', 'tests/ui/render_self_talk_journey.gd',
     'test_rendered_current_thought_clear_and_physical_save_load', 'thought', 'SELF_TALK_JOURNEY_COMPLETED'),
    ('thought-load', 'tests/ui/render_self_talk_load.gd',
     'test_fresh_process_load_restores_current_thought_and_empty_frame', 'thought', 'SELF_TALK_FRESH_LOAD_COMPLETED'),
    ('transport', 'tests/ui/render_self_talk_transport.gd',
     'test_auto_and_skip_cross_paired_text_without_executing_transition', 'transport', 'SELF_TALK_TRANSPORT_COMPLETED'),
    ('transition-create', 'tests/ui/render_scene_transition_create.gd',
     'test_manual_transition_discards_input_then_saves_visible_destination', 'transition', 'SCENE_TRANSITION_CREATE_COMPLETED'),
    ('transition-load', 'tests/ui/render_scene_transition_load.gd',
     'test_fresh_process_load_restores_destination_without_transition', 'transition', 'SCENE_TRANSITION_LOAD_COMPLETED'),
    ('transition-auto', 'tests/ui/render_scene_transition_auto.gd',
     'test_auto_waits_for_visible_transition_destination', 'transition-auto', 'SCENE_TRANSITION_AUTO_COMPLETED'),
]


def assert_tests_pass(report, expected_methods):
    cases = report.findall('.//testcase')
    names = [case.get('name') for case in cases]
    assert len(names) == len(expected_methods) and set(names) == set(expected_methods), names
    assert not any(report.findall('.//' + tag) for tag in ('failure', 'error', 'skipped'))
    for case in cases:
        assert int(case.get('assertions', '0')) > 0, case.attrib
        assert case.get('status') == 'pass', case.attrib


def run():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    godot = os.environ['GODOT_CONSOLE_PATH']
    env = dict(os.environ, XDG_DATA_HOME=str(OUTPUT / 'import-user'))
    subprocess.run([godot, '--headless', '--path', str(ROOT), '--import',
                    '--log-file', str(OUTPUT / 'import.log')], env=env, check=True, timeout=480)
    imported = (OUTPUT / 'import.log').read_text()
    assert 'SCRIPT ERROR:' not in imported and 'ERROR: Failed to load' not in imported, imported
    subprocess.run(['git', 'restore', '--', 'project.godot'], cwd=ROOT, check=True)
    suites = [(name, path, method, name, '', False) for name, path, method in CASES]
    suites += [(*journey, True) for journey in JOURNEYS]
    for name, path, method, storage, marker, rendered in suites:
        isolated = ROOT / '.godot/phase2r_tests/progression' / storage
        env = dict(os.environ, XDG_DATA_HOME=str(isolated / 'data'),
                   DWM_TEST_ROOT=str(isolated / 'test-root'))
        Path(env['XDG_DATA_HOME']).mkdir(parents=True, exist_ok=True)
        Path(env['DWM_TEST_ROOT']).mkdir(parents=True, exist_ok=True)
        prefix = ['xvfb-run', '-a', '-s', '-screen 0 1920x1080x24', godot,
                  '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3'] if rendered else [godot, '--headless']
        subprocess.run(prefix + ['--path', str(ROOT), '--audio-driver', 'Dummy',
            '--log-file', str(OUTPUT / (name + '.log')), '-s', 'res://addons/gut/gut_cmdln.gd',
            '-gconfig=', '-gtest=res://' + path, '-gunit_test_name=' + method, '-gexit', '-glog=1',
            '-gjunit_xml_file=' + str(OUTPUT / (name + '.xml'))], env=env, check=True, timeout=300)
        log = (OUTPUT / (name + '.log')).read_text()
        assert 'SCRIPT ERROR:' not in log and 'ERROR: Failed to load' not in log, name
        assert not marker or marker in log, name
        report = ET.parse(OUTPUT / (name + '.xml')).getroot()
        expected = WRITE_REFUSAL_METHODS if method == 'write_refusal_keeps_' else (method,)
        assert_tests_pass(report, expected)
        print('PASS', name, flush=True)


if __name__ == '__main__':
    run()
