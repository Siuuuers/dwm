import re

from check_history import SESSION, function_body, source

BOOTSTRAP = 'autoload/ApplicationBootstrap.gd'
BRIDGE = 'autoload/DialogicBridge.gd'
PROFILE = 'autoload/ProfileManager.gd'
GAME = 'autoload/GameState.gd'
ADAPTER = 'scripts/narrative/DialogicRuntimeAdapter.gd'
EVENT_PORT = 'scripts/application/narrative/SceneEventCommandPort.gd'
LIVE_FUNCTIONS = (
    '_fork_scene_live', '_fork_scene_transition',
    'prepare_scene_next', 'prepare_scene_control_continuation',
)
SAVE = 'autoload/SaveManager.gd'
CONTACTS = 'scripts/domain/contact/ContactInvitationState.gd'
PAUSE = 'scripts/application/lifecycle/ProductionPauseController.gd'
BINDINGS = 'scripts/ui/SettingsControlsSheet.gd'
CAPTION = 'scripts/ui/witnessed/WitnessedCaptionLayer.gd'
STRICT_JSON = 'scripts/validation/StrictJson.gd'
BOARD_PRESENTATION = 'scripts/application/minesweeper/MinesweeperPresentationPort.gd'
DATING = 'scripts/application/run/DatingPhysicalOwner.gd'
BOARD_STATE = 'scripts/domain/minesweeper/DesktopBoardState.gd'
REDUCER = 'scripts/domain/minesweeper/MinesweeperBoardReducer.gd'
RUN_SNAPSHOT = 'scripts/domain/run/RunSnapshotSchema.gd'
ROUND = 'scripts/application/minesweeper/MinesweeperRoundCoordinator.gd'
REWARDS = (
    (GAME, '_commit_scene_round_owned', '_scene_round_board', '_scene_round_reward.prepare_scene_complete'),
    (ROUND, 'complete_round', '_board_state', '_reward_port.prepare_complete'),
)
RULES = (
    (REDUCER, ('reveal', 'set_flag', 'chord', '_append_action'),
     r'\bvar\s+actions\s*(?::\s*Array\s*)?:?=\s*[^\n]*\.duplicate\s*\(\s*true\s*\)',
     'Append the next action without deep-copying the entire move history'),
    (RUN_SNAPSHOT, ('normalize_scene_content',),
     r'\b(?:outcome\s*\.\s*physical_slot\s*=(?!=)|SCENE_ATTEMPTS\s*\.\s*semantic_slot\s*\()',
     'Use the saved Challenge outcome without reconstructing its physical slot'),
    (PROFILE, ('initialize', 'prepare_profile_document', '_profile_text_validator'),
     r'\b(?:MIGRATION\s*\.\s*prepare_document\s*\(|_profile_migration_text_validator\b|'
     r'_import_legacy_input_mappings\s*\()',
     'Admit the current profile at startup without importing obsolete development data'),
    (DATING, ('_board_action',), r'\bfor\s+\w+(?:\s*:\s*Dictionary)?\s+in\s+_record\.board\.actions\s*:',
     'Record the current board action at the reducer instead of revisiting the history'),
    (DATING, ('_board_action',), r'\bclear_debug_flags\s*\(',
     'Clear flags when certifying the forced opening'),
    (BOARD_STATE, ('prepare_restore',), r'\bclear_debug_flags\s*\(',
     'Restore the certified board as saved'),
    (STRICT_JSON, ('parse_object',), r'\.\s*duplicate\s*\(\s*true\s*\)',
     'Return the document already owned by the parser'),
    (SESSION, ('_configure_scene_observed_body',), r'\bentry\s*\.\s*duplicate\s*\(\s*true\s*\)',
     'Copy the catalogue row shallowly to reuse its frozen caption lines'),
    (ADAPTER, ('_check_reading_seek_target',), r'\b(?:old|snapshot)\s*\.\s*duplicate\s*\(\s*true\s*\)',
     'Copy only the headers when comparing reading seek targets'),
    (BOARD_PRESENTATION, ('_published_projection', '_failure'), r'\b_?projection\s*\.\s*duplicate\s*\(\s*true\s*\)',
     'Return the read-only board projection already published by the owner'),
    (BOOTSTRAP, ('_scene_desktop_phase', '_scene_desktop_dispatch'), r'\b_desktop_board_state\s*\.\s*capture\s*\(',
     'Read phase and revision from the shared board view'),
    (BOOTSTRAP, ('_run_stage',),
     r'\bload_ids_default\s*\(\s*(?:true\s*)?\)',
     'Bootstrap reads registered story IDs; use the shared read-only registry'),
    (GAME, ('_prepare_scene_day_renewal',),
     r'\bcapture_run_snapshot_input\s*\(',
     'Capture the desktop, lifecycle and gameplay needed for day renewal'),
    (GAME, ('validate_live_session', 'validate_live_session_activation', 'retire_live_session'),
     r'\b_run_lifecycle\s*\.\s*to_dict\s*\(',
     'Use the current run ID accessor for live session identity checks'),
    (GAME, ('prepare_scene_audio_arrival', 'prepare_scene_presentation_arrival'),
     r'\bcompile_runtime_scene_programme\s*\(',
     'Resolve the authored arrival node through the shared scene entry lookup'),
    (BRIDGE, ('_prepare_scene_entry',),
     r'\bscene_registration_fingerprint\s*\(',
     'Compare the binding with the fingerprint from the selected registration'),
    (SAVE, ('prepare_new_run_action',),
     r'\b_scene_title_new_run_context\b',
     'New Game consent needs a token and replacement status; commit owns the registered scene context'),
    (GAME, ('_retained_scene_challenge_command',),
     r'\b_scene_runtime_event_context\s*\(',
     'Retained Challenge command lookup must not capture runtime context; checkpoint and End boundaries own capture'),
    (CAPTION, ('_ready',),
     r'\bconfigure_presentation\s*\([\s\S]*?\b_apply_preferences\s*\(|\b_configure_recovery_presentation\s*\(',
     'Apply actual caption preferences first and defer recovery styling until requested'),
    (BINDINGS, ('_ready',),
     r'\b(?:set_presentation|refresh)\s*\(|\bPRESENTATION\s*\.\s*build\s*\(',
     'SettingsContent applies the actual player theme; do not initialize a temporary binding theme'),
    (PAUSE, ('request_pause',),
     r'\b_ensure_hosts\s*\(\s*\)',
     'History/direct sheets must not eagerly build unrelated Settings'),
    (BINDINGS, ('set_presentation',),
     r'\b_style_button\s*\(',
     'Refresh owns binding-button styling; do not style the same buttons twice'),
    (SAVE, ('_commit_backup_action_profiled',),
     r'\bcommit_prepared\s*\(|\b(?:RUN_SNAPSHOT_SCHEMA|SAVE_DOCUMENT_SCHEMA)\s*\.\s*validate\s*\(',
     'Commit the owned Save candidate without repeating snapshot/document validation'),
    (CONTACTS, ('capture_scene_definitions',),
     r'\b(?:scene_registration|_s_hash|canonical_sha256|sha256_text)\s*\(',
     'Reuse the immutable registration owner bundle and fingerprint'),
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
    code_by_path = {path: NON_CODE.sub(lambda match: re.sub(r'[^\n]', ' ', match.group()), content)
                    for path, content in sources.items()}
    for path, functions, pattern, message in RULES:
        for name in functions:
            body = function_body(code_by_path[path], name)
            if not body:
                errors.append(f'{path}::{name}: guarded function missing; update its lint scope')
            elif re.search(pattern, body):
                errors.append(f'{path}::{name}: {message}')
    for path, name, board, reward in REWARDS:
        body = function_body(code_by_path[path], name)
        if not body:
            errors.append(f'{path}::{name}: guarded function missing; update its lint scope')
            continue
        preparation = re.search(r'\b' + reward.replace('.', r'\s*\.\s*') + r'\s*\(', body)
        if preparation:
            guard = rf'(?m)^\s*if\s+{board}\s*\.\s*has_settled_inspection\s*\(\s*\)[^\n:]*:\s*return\b'
            if not re.search(guard, body[:preparation.start()]):
                errors.append(f'{path}::{name}: return a settled round before preparing rewards')
    return errors


if __name__ == '__main__':
    errors = violations({path: source(path) for path in dict.fromkeys(rule[0] for rule in (*RULES, *REWARDS))})
    for error in errors:
        print(error)
    print(f'Live transition lint: {len(errors)} violation(s)')
    raise SystemExit(bool(errors))
