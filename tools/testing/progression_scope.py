import re
import subprocess

BRIDGE = 'autoload/DialogicBridge.gd'
MODEL_PATHS = {
    'tools/verification/story_progression/StoryProgression.tla',
    'tools/verification/story_progression/StoryProgression.cfg',
    'tools/verification/story_progression/README.md',
}
PATHS = {
    BRIDGE, '.github/workflows/windows-tests.yml', '.github/workflows/dtl-first-preflight.yml',
    'tools/testing/progression_scope.py', 'tools/testing/run_progression_checks.py',
    'tools/testing/test_windows_coverage.py',
    'tests/integration/test_dialogic_next_traversal.gd', 'tests/integration/test_dialogic_skip.gd',
    'tests/integration/test_scene_next_notification.gd',
    'docs/agent/2026-11-03-story-progression-implementation.md',
    'docs/agent/2026-11-03-story-progression-handoff.md',
}
METHODS = {
    'can_skip_current_line', 'can_next_current_line', '_can_prepare_next',
    'is_next_traversal_active', '_perform_next', '_perform_caption_next',
    '_finish_next', 'can_auto_advance_current_line', 'request_auto_step',
    'acknowledge_current_line_presentation', '_record_line_presentation',
    'request_skip_step',
    '_acknowledge_next_source',
}
DECLARATIONS = {
    'var _next_active := false', 'var _next_command: Dictionary = {}',
    'var _skip_step_in_progress := false', 'var _line_ack_in_progress := false',
    'var _auto_step_in_progress := false', 'var _next_admitting := false',
    'var _next_acknowledging := false',
    'enum ProgressionPhase { IDLE, NEXT_ADMITTING, NEXT_ACKNOWLEDGING, NEXT_ACTIVE, AUTO, SKIP, ACKNOWLEDGING }',
    'var _progression_phase := ProgressionPhase.IDLE',
}


def unrelated_source(source):
    pattern = r'(?ms)^(?:static )?func (' + '|'.join(sorted(METHODS)) + r')\([^\n]*\n.*?(?=^(?:static )?func |^(?:var |const |enum |signal |class |@)|\Z)'
    source = re.sub(pattern, '', source)
    for method, before, after in (
        ('_perform_marker_next',
         '\tif _line_ack_in_progress or _auto_step_in_progress or _skip_step_in_progress or is_pause_restore_pending():\n',
         '\tif is_pause_restore_pending():\n'),
        ('_run_marker_next',
         '\t_next_active = true\n\t_next_command = expected.duplicate(true)\n',
         '\t_progression_phase = ProgressionPhase.NEXT_ACTIVE\n'),
    ):
        body = r'(?ms)^func ' + method + r'\([^\n]*\n.*?(?=^func |\Z)'
        source = re.sub(body, lambda match: match[0].replace(before, after), source)
    source = '\n'.join(line for line in source.splitlines() if line not in DECLARATIONS)
    source = source.replace('not _next_active', '_progression_phase != ProgressionPhase.NEXT_ACTIVE')
    source = source.replace('_next_active', '_progression_phase == ProgressionPhase.NEXT_ACTIVE')
    return source


def is_progression(paths, base):
    if not paths or not paths <= PATHS | MODEL_PATHS:
        return False
    if BRIDGE not in paths:
        return bool(paths & MODEL_PATHS)
    sources = []
    for ref in (base, 'HEAD'):
        result = subprocess.run(['git', 'show', ref + ':' + BRIDGE], capture_output=True)
        if result.returncode:
            return False
        sources.append(unrelated_source(result.stdout.decode()))
    return sources[0] == sources[1]
