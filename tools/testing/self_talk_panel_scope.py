"""Recognize the presentation-only self-talk slice shared by cloud workflows."""
import re
import subprocess

PATHS = {
    '.github/workflows/windows-tests.yml', '.github/workflows/dtl-first-preflight.yml',
    'tools/testing/test_windows_coverage.py', 'tools/testing/self_talk_panel_scope.py',
    'autoload/DialogicBridge.gd', 'scripts/narrative/SoloReadingSession.gd',
    'scripts/ui/witnessed/WitnessedCaptionLayer.gd',
    'scripts/ui/witnessed/WitnessedSelfTalk.gd',
    'tests/unit/test_scene_self_talk.gd', 'tests/unit/test_witnessed_self_talk.gd',
    'tests/ui/render_self_talk_base.gd', 'tests/ui/render_self_talk_journey.gd',
    'tests/ui/render_self_talk_load.gd', 'tests/ui/render_self_talk_transport.gd',
    'tests/ui/render_self_talk_choices.gd',
    'tests/integration/test_witnessed_caption_runtime.gd',
    'docs/agent/2026-10-30-self-talk-panel-handoff.md',
    'docs/agent/2026-10-30-self-talk-panel-implementation.md',
    'docs/agent/2026-10-28-self-talk-implementation-plan.md',
}
METHODS = {
    'autoload/DialogicBridge.gd': 'get_reading_history',
    'scripts/narrative/SoloReadingSession.gd': 'project_self_talk',
    'scripts/ui/witnessed/WitnessedCaptionLayer.gd': '_sync_transport',
}


def is_self_talk_panel(paths, base):
    if not paths or not paths <= PATHS or not paths & {
        'scripts/ui/witnessed/WitnessedSelfTalk.gd', 'tests/unit/test_scene_self_talk.gd',
        'tests/ui/render_self_talk_journey.gd',
    }:
        return False
    for path, method in METHODS.items():
        if path not in paths:
            continue
        bodies = []
        pattern = rb'(?ms)^(?:static )?func ' + method.encode() + rb'\([^\n]*\n.*?(?=^(?:static )?func |\Z)'
        for ref in (base, 'HEAD'):
            source = subprocess.run(['git', 'show', ref + ':' + path], capture_output=True)
            if source.returncode != 0:
                return False
            rest, count = re.subn(pattern, b'', source.stdout)
            if count != 1:
                return False
            bodies.append(rest)
        if bodies[0] != bodies[1]:
            return False
    return True
