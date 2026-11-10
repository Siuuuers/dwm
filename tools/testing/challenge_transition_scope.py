"""Recognize the reviewed Challenge transition slice in both CI workflows."""
import re
import subprocess

METHODS = {
    'autoload/GameState.gd': {
        '_prepare_scene_playable_event', '_capture_retained_scene_challenge_command',
        '_retained_scene_challenge_command', 'validate_scene_challenge_command',
        '_accept_scene_end', 'validate_scene_challenge_end', 'commit_scene_challenge_closure',
        'commit_scene_challenge_checkpoint', '_validate_scene_challenge_checkpoint',
    },
    'autoload/DialogicBridge.gd': {
        '_commit_scene_playable_owned', '_scene_playable_current', 'validate_live_scene_event_anchor',
    },
    'scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd': {'_publish_scene_event'},
}
TESTS = {
    'tests/integration/test_scene_challenge_transition_authored.gd',
    'tests/unit/test_scene_challenge_command_lookup.gd',
    'tests/unit/test_scene_playable_preparation.gd',
    'tests/integration/test_scene_owner_composition.gd',
    'tests/unit/test_scene_checkpoint_ack.gd',
    'tests/integration/test_scene_playable_native_control.gd',
    'tests/unit/test_scene_control_continuation.gd',
    'tests/integration/scene_first_reveal_connected_child.gd',
    'tests/integration/test_scene_first_reveal_connected_create.gd',
    'tests/integration/test_scene_first_reveal_connected_load.gd',
}
TOOLS = {
    'tools/testing/challenge_transition_scope.py',
    'tools/testing/test_challenge_transition_scope.py',
    'tools/testing/run_challenge_transition_checks.py',
    'tools/testing/test_challenge_transition_runner.py',
}
COMPANIONS = {
    '.github/workflows/windows-tests.yml', '.github/workflows/dtl-first-preflight.yml',
    'tools/testing/test_windows_coverage.py', 'tools/testing/test_inventory_preflight.py',
    'tools/lint/check_live_transitions.py', 'tools/lint/test_live_transitions.py',
    'docs/agent/2026-11-05-passage-latency-handoff.md',
    'docs/agent/2026-11-10-challenge-ci-coverage-handoff.md',
}


def is_challenge_transition(paths, base):
    paths = {path[:-4] if path.endswith('.gd.uid') else path for path in paths}
    if not paths or not paths <= METHODS.keys() | TESTS | TOOLS | COMPANIONS:
        return False
    if not paths & (METHODS.keys() | TESTS | TOOLS):
        return False
    for path, owner in (
        ('.github/workflows/windows-tests.yml', 'test-scope'),
        ('.github/workflows/dtl-first-preflight.yml', 'scope'),
    ):
        if path not in paths:
            continue
        remaining = []
        for ref in (base, 'HEAD'):
            source = subprocess.run(['git', 'show', ref + ':' + path], capture_output=True)
            if source.returncode:
                return False
            rest, count = re.subn(
                r'(?ms)^  ' + owner + r':[ \t]*\n.*?(?=^\S|^  \S|\Z)',
                '', source.stdout.decode(),
            )
            if count != 1:
                return False
            if owner == 'test-scope':
                rest, count = re.subn(
                    r'(?ms)^  challenge-transition:[ \t]*\n.*?(?=^\S|^  \S|\Z)', '', rest,
                )
                if count > 1:
                    return False
                rest = rest.replace(" && needs.test-scope.outputs.challenge_transition != 'true'", '')
            else:
                rest = rest.replace("      - 'tools/testing/challenge_transition_scope.py'\n", '')
            remaining.append('\n'.join(line for line in rest.splitlines() if line.strip()))
        if remaining[0] != remaining[1]:
            return False
    for path in paths & METHODS.keys():
        remaining = []
        pattern = r'(?m)^(?:static )?func (' + '|'.join(sorted(METHODS[path])) + r')\([^\n]*\n(?:(?:[ \t]+[^\n]*|)\n)*'
        for ref in (base, 'HEAD'):
            source = subprocess.run(['git', 'show', ref + ':' + path], capture_output=True)
            if source.returncode:
                return False
            rest = re.sub(pattern, '', source.stdout.decode())
            remaining.append('\n'.join(line for line in rest.splitlines() if line.strip()))
        if remaining[0] != remaining[1]:
            return False
    return True
