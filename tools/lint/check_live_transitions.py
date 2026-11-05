import re

from check_history import SESSION, function_body, source

PROFILE = 'autoload/ProfileManager.gd'
GAME = 'autoload/GameState.gd'
ADAPTER = 'scripts/narrative/DialogicRuntimeAdapter.gd'
EVENT_PORT = 'scripts/application/narrative/SceneEventCommandPort.gd'
LIVE_FUNCTIONS = (
    '_fork_scene_live', '_fork_scene_transition',
    'prepare_scene_next', 'prepare_scene_control_continuation',
)
RULES = (
    (SESSION, LIVE_FUNCTIONS,
     r'\b(?:restore|restore_player|restore_snapshot|_validate_scene_saved|_validate_scene_base)\s*\(',
     'Live planning must fork admitted state; serialized restoration belongs to Load'),
    (PROFILE, ('stage_caption_history',),
     r'\b(?:_persist_candidate|_commit_profile_candidate|flush_reading_history|write_text|write_revision|store_string|store_buffer)\s*\(|\bFileAccess\s*\.',
     'Caption staging must stay in memory; flush at checkpoint/save boundaries'),
    (SESSION, ('_matches_scene_live',),
     r'\b(?:stringify|_fingerprint|canonical_sha256|sha256_text|var_to_bytes|var_to_str)\s*\(',
     'Retained live-state comparison must not serialize or hash checkpoints'),
    (ADAPTER, ('validate_scene_source',),
     r'\b(?:stringify|_fingerprint|canonical_sha256|sha256_text|var_to_bytes|var_to_str)\s*\(',
     'Retained source validation must not serialize or hash checkpoints'),
    (GAME, ('scene_event_registration',),
     r'\bduplicate\s*\(\s*true\s*\)',
     'Reuse the immutable installed registration instead of deep-copying it'),
    (EVENT_PORT, ('_installed_scene_registration',),
     r'\bduplicate\s*\(\s*true\s*\)',
     'Reuse the immutable installed registration instead of deep-copying it'),
    (SESSION, ('_fork_scene_configuration',),
     r'\b(?:manifest|catalogue|registry|_scene_bundle|_caption_variants_by_line)\s*\.\s*duplicate\s*\(',
     'Share immutable configuration; copy only per-reader mutable containers'),
)
NON_CODE = re.compile(r'"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27|#[^\n]*')


def violations(sources):
    errors = []
    for path, functions, pattern, message in RULES:
        code = NON_CODE.sub(lambda match: re.sub(r'[^\n]', ' ', match.group()), sources[path])
        for name in functions:
            body = function_body(code, name)
            if not body:
                errors.append(f'{path}::{name}: guarded function missing; update its lint scope')
            elif re.search(pattern, body):
                errors.append(f'{path}::{name}: {message}')
    return errors


if __name__ == '__main__':
    errors = violations({path: source(path) for path in dict.fromkeys(rule[0] for rule in RULES)})
    for error in errors:
        print(error)
    print(f'Live transition lint: {len(errors)} violation(s)')
    raise SystemExit(bool(errors))
