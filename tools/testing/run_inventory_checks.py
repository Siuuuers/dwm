import os
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
TEST = 'tests/unit/tooling/test_public_surface_inventory.gd'
TARGETS = {'game_state': 'GameState', 'save_manager': 'SaveManager'}


def assert_tests_pass(report, expected):
    cases = report.findall('.//testcase')
    assert expected and sorted(case.get('name', '') for case in cases) == sorted(expected)
    assert not any(report.findall('.//' + tag) for tag in ('failure', 'error', 'skipped'))
    for case in cases:
        assert case.get('classname') == TEST, case.attrib
        assert case.get('status') == 'pass' and int(case.get('assertions', '0')) > 0, case.attrib


def run():
    output = ROOT / '.godot/ci/inventory-tooling'
    output.mkdir(parents=True, exist_ok=True)
    paths = [ROOT / f'evidence/phase_2r/runtime/{target}_surface.json' for target in TARGETS]
    canonical = {path: path.read_bytes() for path in paths}
    expected = re.findall(r'^func (test_\w+)\(', (ROOT / TEST).read_text(), re.M)
    assert expected, TEST
    report = output / 'tooling.xml'
    suites = [('tooling', ['-s', 'res://addons/gut/gut_cmdln.gd', '-gconfig=',
                          '-gtest=res://' + TEST, '-gexit', '-glog=1', '-gjunit_xml_file=' + str(report)])]
    for target, owner in TARGETS.items():
        suites.append((target, ['-s', 'res://tools/runtime/generate_public_surface_inventory.gd', '--',
            '--script=res://autoload/' + owner + '.gd',
            '--required=res://evidence/phase_2r/runtime/' + target + '_required_surface.json',
            '--output=res://evidence/phase_2r/runtime/' + target + '_surface.json',
            '--search-root=res://autoload', '--search-root=res://scripts',
            '--search-root=res://scenes', '--search-root=res://tests', '--check']))
    report.unlink(missing_ok=True)
    for name, arguments in suites:
        isolated = ROOT / '.godot/phase2r_tests/inventory-tooling' / name
        env = dict(os.environ, XDG_DATA_HOME=str(isolated / 'data'), DWM_TEST_ROOT=str(isolated / 'test-root'))
        Path(env['XDG_DATA_HOME']).mkdir(parents=True, exist_ok=True)
        Path(env['DWM_TEST_ROOT']).mkdir(parents=True, exist_ok=True)
        log = output / (name + '.log')
        log.unlink(missing_ok=True)
        subprocess.run([os.environ['GODOT_CONSOLE_PATH'], '--headless', '--path', str(ROOT),
                        '--audio-driver', 'Dummy', '--log-file', str(log)] + arguments,
                       cwd=ROOT, env=env, check=True, timeout=300)
        contents = log.read_text()
        assert not re.search(r'SCRIPT ERROR:|ERROR: Failed to load|Unicode parsing error|Unexpected NUL character', contents), name
        if name == 'tooling':
            assert_tests_pass(ET.parse(report).getroot(), expected)
        else:
            assert contents.splitlines().count('SURFACE_INVENTORY: PASS') == 1, name
        for path, before in canonical.items():
            assert path.read_bytes() == before, str(path) + ' changed during read-only acceptance'
        print('PASS', name, flush=True)


if __name__ == '__main__':
    run()
