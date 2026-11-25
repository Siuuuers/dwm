import unittest

from check_live_transitions import (
    ADAPTER, BINDINGS, BOARD_PRESENTATION, BOARD_STATE, BOOTSTRAP, BRIDGE, CAPTION, CONTACTS,
    DATING, EVENT_PORT, GAME, PAUSE, PROFILE, REDUCER, REWARDS, RULES, RUN_SNAPSHOT, SAVE, SESSION,
    STRICT_JSON, violations,
)


class LiveTransitionDependencies(unittest.TestCase):
    def setUp(self):
        owners = {(path, name) for path, functions, _, _ in RULES for name in functions}
        owners.update((path, name) for path, name, _, _ in REWARDS)
        self.sources = {}
        for path, name in sorted(owners):
            self.sources[path] = self.sources.get(path, '') + f'func {name}():\n\tpass\n\n'

    def insert(self, path, name, code):
        self.sources[path] = self.sources[path].replace(f'func {name}():\n', f'func {name}():\n\t{code}\n')

    def test_allowed_live_operations(self):
        self.insert(STRICT_JSON, 'parse_object', 'return result')
        self.insert(SESSION, '_configure_scene_observed_body', 'row = entry.duplicate()')
        self.insert(ADAPTER, '_check_reading_seek_target', 'headers = old.duplicate()')
        self.insert(BOARD_PRESENTATION, '_published_projection', 'return _success(_projection)')
        self.insert(BOOTSTRAP, '_scene_desktop_dispatch', 'board = _desktop_board_state.read_state()')
        self.sources[BOOTSTRAP] += 'func prepare_editable_board():\n\treturn _desktop_board_state.capture()\n'
        self.insert(BOOTSTRAP, '_run_stage', 'ids = MANIFEST.load_ids_default(false)')
        self.insert(GAME, '_prepare_scene_day_renewal', 'desktop = _capture_desktop_snapshot()')
        self.insert(GAME, 'validate_live_session', 'return _run_lifecycle.get_run_id()')
        self.insert(GAME, 'prepare_scene_audio_arrival', 'node = _scene_entry_node(scene, bundle, label)')
        self.insert(BRIDGE, '_prepare_scene_entry', 'fingerprint = registration.value.fingerprint')
        self.insert(SESSION, '_fork_scene_live', 'sibling.ledger = ledger.fork_live()')
        self.insert(SESSION, '_fork_scene_configuration', 'sibling._scene_nodes = _scene_nodes.duplicate()')
        self.insert(GAME, 'scene_event_registration', 'return registered.bundle')
        self.insert(PROFILE, 'stage_caption_history', '_reading_history_dirty = true')
        self.insert(SAVE, 'prepare_new_run_action', '_storage.exists("autosave.json")')
        self.sources[SAVE] += 'func commit_prepared_new_run(token):\n\tstart(target, _scene_title_new_run_context)\n'
        self.assertEqual(violations(self.sources), [])

    def test_settlement_precedes_reward_preparation(self):
        for path, name, board, reward in REWARDS:
            guard = f'if {board}.has_settled_inspection():\n\t\treturn settled'
            prepare = f'var result = {reward}(candidate)'
            cases = (
                (guard + '\n\t' + prepare, 0),
                (prepare + '\n\t' + guard, 1),
                (prepare, 1),
                (f'if not {board}.has_settled_inspection(): return error\n\t' + prepare, 1),
            )
            for code, expected in cases:
                with self.subTest(owner=name, code=code):
                    self.setUp()
                    self.insert(path, name, code)
                    self.assertEqual(len(violations(self.sources)), expected)

    def test_current_save_and_debug_certification_are_allowed(self):
        self.insert(REDUCER, '_append_action', 'var actions := history.duplicate()')
        self.insert(REDUCER, '_append_action', 'var owned := prior.duplicate(true)')
        self.insert(PROFILE, 'initialize', '_profile_text_validator(text)')
        self.insert(PROFILE, '_profile_text_validator', 'return SCHEMA.validate(parsed.value)')
        self.insert(RUN_SNAPSHOT, 'normalize_scene_content', 'if outcome.physical_slot == slot: return candidate')
        self.insert(DATING, '_board_action', 'REDUCER.reveal(_record.board, index, transaction_id)')
        self.insert(BOARD_STATE, 'prepare_restore', 'return prepare(snapshot)')
        self.sources[BOARD_STATE] += 'func prepare_debug_slice():\n\t_BOARD_SCHEMA.clear_debug_flags(candidate)\n'
        self.assertEqual(violations(self.sources), [])

    def test_rejects_each_regression(self):
        cases = [
            (REDUCER, 'reveal', 'var actions: Array = (parsed["actions"] as Array).duplicate(true)'),
            (REDUCER, '_append_action', 'var actions := history.duplicate(true)'),
            (PROFILE, 'initialize', 'MIGRATION.prepare_document(parsed.value)'),
            (PROFILE, 'initialize', '_import_legacy_input_mappings()'),
            (PROFILE, 'initialize', 'reconcile(path, _profile_migration_text_validator)'),
            (PROFILE, 'prepare_profile_document', 'return MIGRATION.prepare_document(raw)'),
            (RUN_SNAPSHOT, 'normalize_scene_content', 'outcome.physical_slot = slot'),
            (RUN_SNAPSHOT, 'normalize_scene_content', 'var slot = SCENE_ATTEMPTS.semantic_slot(record.context)'),
            (DATING, '_board_action', 'for entry: Dictionary in _record.board.actions: entry.kind = str(entry.kind)'),
            (DATING, '_board_action', 'SCHEMA.clear_debug_flags(_record.envelope.shell)'),
            (BOARD_STATE, 'prepare_restore', '_BOARD_SCHEMA.clear_debug_flags(restored.candidate)'),
            (STRICT_JSON, 'parse_object', 'return (result["value"] as Dictionary).duplicate(true)'),
            (SESSION, '_configure_scene_observed_body', 'row = entry.duplicate(true)'),
            (ADAPTER, '_check_reading_seek_target', 'headers = snapshot.duplicate(true)'),
            (BOARD_PRESENTATION, '_published_projection', 'return _success(_projection.duplicate(true))'),
            (BOARD_PRESENTATION, '_failure', 'result.value = projection.duplicate(true)'),
            (BOOTSTRAP, '_scene_desktop_phase', 'return _desktop_board_state.capture().phase'),
            (BOOTSTRAP, '_scene_desktop_dispatch', 'board = _desktop_board_state.capture()'),
            (BOOTSTRAP, '_run_stage', 'MANIFEST.load_ids_default()'),
            (BOOTSTRAP, '_run_stage', 'MANIFEST.load_ids_default(true)'),
            (GAME, '_prepare_scene_day_renewal', 'before = capture_run_snapshot_input().duplicate(true)'),
            (GAME, 'validate_live_session', 'run_id = _run_lifecycle.to_dict().run_id'),
            (GAME, 'prepare_scene_audio_arrival', 'adapter.compile_runtime_scene_programme(path, entry, markers)'),
            (BRIDGE, '_prepare_scene_entry', 'fingerprint = MANIFEST.scene_registration_fingerprint()'),
            (SAVE, 'prepare_new_run_action', 'prepared.context = _scene_title_new_run_context'),
            (GAME, '_retained_scene_challenge_command', '_scene_runtime_event_context()'),
            (CAPTION, '_ready', 'configure_presentation()\n\t_apply_preferences()'),
            (CAPTION, '_ready', '_configure_recovery_presentation()'),
            (BINDINGS, '_ready', 'set_presentation(fallback, 24, false)'),
            (BINDINGS, '_ready', 'refresh()'),
            (PAUSE, 'request_pause', '_ensure_hosts()'),
            (BINDINGS, 'set_presentation', '_style_button(button)'),
            (SAVE, '_commit_backup_action_profiled', '_journal.commit_prepared(candidate)'),
            (CONTACTS, 'capture_scene_definitions', '_SCENE_MANIFEST.scene_registration()'),
            (CONTACTS, 'capture_scene_definitions', '_s_hash(bundle)'),
            (SESSION, '_fork_scene_live', 'reader.restore(saved, entry)'),
            (SESSION, '_fork_scene_transition', 'ledger.restore_snapshot(saved)'),
            (SESSION, 'prepare_scene_next', '_validate_scene_base(saved, entry)'),
            (SESSION, 'prepare_scene_control_continuation', 'reader.restore_player(saved, entry)'),
            (PROFILE, 'stage_caption_history', '_commit_profile_candidate(candidate)'),
            (PROFILE, 'stage_caption_history', 'flush_reading_history()'),
            (PROFILE, 'stage_caption_history', '_storage.write_text(document)'),
            (PROFILE, 'stage_caption_history', 'FileAccess.open(path, mode)'),
            (SESSION, '_matches_scene_live', 'WRITER.stringify(checkpoint)'),
            (ADAPTER, 'validate_scene_source', '_fingerprint(checkpoint)'),
            (GAME, 'scene_event_registration', 'registered.bundle.duplicate(\n\ttrue\n\t)'),
            (EVENT_PORT, '_installed_scene_registration', 'installed.bundle.duplicate(true)'),
            (SESSION, '_fork_scene_configuration', '_scene_bundle.duplicate(true)'),
        ]
        for path, name, code in cases:
            with self.subTest(code=code):
                self.setUp()
                self.insert(path, name, code)
                self.assertEqual(len(violations(self.sources)), 1)

    def test_save_restore_and_other_functions_are_outside_scope(self):
        self.sources[GAME] += 'func commit_scene_challenge_checkpoint():\n\t_scene_runtime_event_context()\n'
        self.sources[SESSION] += 'func restore_player():\n\treturn restore(saved, entry)\n'
        self.sources[PROFILE] += 'func flush_reading_history():\n\t_persist_candidate(profile)\n'
        self.sources[ADAPTER] += 'static func content_hash():\n\treturn text.sha256_text()\n'
        self.assertEqual(violations(self.sources), [])

    def test_comments_and_strings_are_not_calls_or_function_boundaries(self):
        self.insert(SESSION, '_fork_scene_live', '# restore(saved)')
        self.insert(SESSION, '_fork_scene_live', 'var example = "restore(saved)"')
        self.insert(SESSION, '_fork_scene_live', 'var example = """\nfunc example():\nrestore(saved)\n"""')
        self.assertEqual(violations(self.sources), [])
        self.insert(SESSION, '_fork_scene_live', 'restore(saved)')
        self.assertEqual(len(violations(self.sources)), 1)

    def test_missing_guarded_function_is_not_silently_skipped(self):
        self.sources[GAME] = ''
        self.assertIn('guarded function missing', violations(self.sources)[0])

    def test_static_owner_is_checked(self):
        self.sources[CONTACTS] = self.sources[CONTACTS].replace("func ", "static func ")
        self.assertEqual(violations(self.sources), [])
        self.insert(CONTACTS, "capture_scene_definitions", "_s_hash(bundle)")
        self.assertEqual(len(violations(self.sources)), 1)
