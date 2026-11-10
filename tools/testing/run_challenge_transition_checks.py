import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
GROUPS = (
    ('reading', 'reading', True, (
        'tests/unit/test_scene_challenge_command_lookup.gd',
        'tests/unit/test_scene_playable_preparation.gd',
        'tests/integration/test_scene_owner_composition.gd',
    )),
    ('acknowledgement', 'acknowledgement', False, ('tests/unit/test_scene_checkpoint_ack.gd',)),
    ('native-control', 'native-control', False, ('tests/integration/test_scene_playable_native_control.gd',)),
    ('continuation', 'continuation', False, ('tests/unit/test_scene_control_continuation.gd',)),
    ('authored-end', 'authored-end', False, ('tests/integration/test_scene_challenge_transition_authored.gd',)),
    ('create', 'save-load', False, ('tests/integration/test_scene_first_reveal_connected_create.gd',)),
    ('load', 'save-load', False, ('tests/integration/test_scene_first_reveal_connected_load.gd',)),
)


def expected_tests(paths):
    expected = []
    for path in paths:
        methods = re.findall(r'^func (test_\w+)\(', (ROOT / path).read_text(), re.M)
        assert methods, path
        expected.extend((path, method) for method in methods)
    return expected


def assert_tests_pass(report, expected):
    cases = report.findall('.//testcase')
    actual = [(case.get('classname'), case.get('name')) for case in cases]
    assert expected and sorted(actual) == sorted(expected), actual
    assert not any(report.findall('.//' + tag) for tag in ('failure', 'error', 'skipped'))
    for case in cases:
        assert case.get('status') == 'pass' and int(case.get('assertions', '0')) > 0, case.attrib


def run(godot):
    selected = [(group, expected_tests(group[3])) for group in GROUPS]
    output = ROOT / '.godot/ci/challenge-transition'
    output.mkdir(parents=True, exist_ok=True)
    storage = ROOT / '.godot/phase2r_tests/challenge-transition'
    storage.mkdir(parents=True, exist_ok=True)
    storage = Path(tempfile.mkdtemp(prefix='run-', dir=storage))
    base_env = dict(os.environ)
    base_env.pop('DWM_SCENE_READING_FIXTURE', None)
    import_log = output / 'import.log'
    import_log.unlink(missing_ok=True)
    subprocess.run([godot, '--headless', '--path', str(ROOT), '--import',
                    '--log-file', str(import_log)], cwd=ROOT,
                   env=dict(base_env, XDG_DATA_HOME=str(storage / 'import')), check=True, timeout=480)
    imported = import_log.read_text()
    assert 'SCRIPT ERROR:' not in imported and 'ERROR: Failed to load' not in imported, imported
    subprocess.run(['git', 'restore', '--', 'project.godot'], cwd=ROOT, check=True)
    for (name, shared_root, reading_fixture, paths), expected in selected:
        isolated = storage / shared_root
        env = dict(base_env, XDG_DATA_HOME=str(isolated / 'data'),
                   DWM_TEST_ROOT=str(isolated / 'test-root'))
        if reading_fixture:
            env['DWM_SCENE_READING_FIXTURE'] = '1'
        Path(env['XDG_DATA_HOME']).mkdir(parents=True, exist_ok=True)
        Path(env['DWM_TEST_ROOT']).mkdir(parents=True, exist_ok=True)
        log = output / (name + '.log')
        report = output / (name + '.xml')
        log.unlink(missing_ok=True)
        report.unlink(missing_ok=True)
        subprocess.run([godot, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy',
            '--log-file', str(log), '-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
            '-gtest=' + ','.join('res://' + path for path in paths), '-gexit', '-glog=1',
            '-gjunit_xml_file=' + str(report)], cwd=ROOT, env=env, check=True, timeout=300)
        contents = log.read_text()
        assert 'SCRIPT ERROR:' not in contents and 'ERROR: Failed to load' not in contents, name
        result = ET.parse(report).getroot()
        assert_tests_pass(result, expected)
        assertions = sum(int(case.get('assertions')) for case in result.findall('.//testcase'))
        print(f'PASS {name}: {len(expected)} tests, {assertions} assertions', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    run(parser.parse_args().godot)
