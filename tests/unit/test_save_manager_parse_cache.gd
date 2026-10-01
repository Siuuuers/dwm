extends "res://addons/gut/test.gd"

const SAVE := preload("res://autoload/SaveManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _previous_control := ""

class ReadFaultOps extends "res://tests/support/FakeFileOps.gd":
	var refuse_reads := false
	var promoted_replacement := ""
	var promotion_changed := false
	func read_bytes(path: String) -> Dictionary:
		if refuse_reads: return {"ok": false, "code": &"fixture_read_refused"}
		return super.read_bytes(path)
	func rename_path(from_path: String, to_path: String) -> Dictionary:
		var result := super.rename_path(from_path, to_path)
		if result.get("ok", false) and from_path.ends_with(".next") and not promoted_replacement.is_empty():
			var changed := super.write_bytes(to_path, promoted_replacement.to_utf8_buffer())
			if not changed.get("ok", false): return changed
			changed = super.flush_path(to_path)
			if not changed.get("ok", false): return changed
			promotion_changed = true
		return result

class ValidationProbe extends "res://autoload/SaveManager.gd":
	var validation_texts: Array[String] = []
	var validation_override := {}
	func _document_text_validator(text: String) -> Dictionary:
		validation_texts.append(text)
		if not validation_override.is_empty(): return validation_override.duplicate(true)
		return super._document_text_validator(text)
	func _capture_saved_time() -> Dictionary:
		# Equal saves across separate calls must not miss reuse merely because the clock advanced.
		return {"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"}

class WitnessValidationProbe extends "res://tests/support/ManualSaveWitnessPort.gd":
	var validation_texts: Array[String] = []
	var validation_override := {}
	func _init() -> void: write_variant = "witness"
	func _document_text_validator(text: String) -> Dictionary:
		validation_texts.append(text)
		if not validation_override.is_empty(): return validation_override.duplicate(true)
		return super._document_text_validator(text)
	func _capture_saved_time() -> Dictionary:
		return {"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"}

class JournalReadProbe extends "res://scripts/infrastructure/save/CheckpointJournal.gd":
	var disk_bundle_reads := 0
	func get_bundles_for_disk() -> Array[Dictionary]:
		disk_bundle_reads += 1
		return super.get_bundles_for_disk()

class BackupCapture extends RefCounted:
	var result: Dictionary = {"ok": false, "code": &"fixture_capture_unavailable"}
	func capture() -> Dictionary:
		return result.duplicate(true)

class Participant extends RefCounted:
	var plan_key := ""
	var unavailable := false
	var preparations := 0
	func _init(key: String) -> void: plan_key = key
	func prepare(_input: Dictionary) -> Dictionary:
		preparations += 1
		if unavailable: return {"ok": false, "code": &"NARRATIVE_CONTENT_UNAVAILABLE"}
		return {"ok": true, "value": {plan_key: {}, "locale_id": "en"}}
	func capture() -> Dictionary: return {"ok": true, "value": {}}
	func apply_silent(_plan: Dictionary) -> Dictionary: return {"ok": true}
	func rollback_silent(_backup: Dictionary) -> Dictionary: return {"ok": true}
	func finalize() -> Dictionary: return {"ok": true}

func before_each() -> void:
	_previous_control = OS.get_environment("DWM_SAVE_PARSE_CACHE_DISABLED")
	OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", "")

func after_each() -> void:
	OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", _previous_control)

func _manager() -> Node:
	return autofree(SAVE.new())

func _fixture(validation_probe: bool = false, witness: bool = false) -> Dictionary:
	var snapshot := STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json"))
	assert_true(snapshot.get("ok", false), str(snapshot))
	if not snapshot.get("ok", false): return {}
	var built := SCHEMA.build(&"slot", 1, &"manual",
		{"checkpoint_kind": "manual_save", "snapshot": snapshot.value}, [])
	assert_true(built.get("ok", false), str(built))
	if not built.get("ok", false): return {}
	var emitted := CANONICAL.stringify(built.value)
	assert_true(emitted.get("ok", false), str(emitted))
	if not emitted.get("ok", false): return {}
	var text: String = emitted.value + "\n"
	var ops := ReadFaultOps.new({"parse-cache/slot_1.json": text})
	var storage := STORAGE.new("parse-cache", ops)
	var manager: Node
	if witness:
		manager = autofree(WitnessValidationProbe.new())
	else:
		manager = autofree(ValidationProbe.new()) if validation_probe else _manager()
	assert_true(manager.initialize(storage).get("ok", false))
	return {"manager": manager, "ops": ops, "storage": storage, "text": text}

func _write_fixture(witness: bool = false) -> Dictionary:
	var f := _fixture(true, witness)
	if f.is_empty(): return {}
	var parsed := STRICT.parse_object(f.text)
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	assert_true(f.manager._journal.reset(snapshot.run_id).get("ok", false))
	var prepared: Dictionary = f.manager._journal.prepare_record(snapshot, &"day_start")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return {}
	assert_true(f.manager._journal.commit_prepared(prepared.value.candidate).get("ok", false))
	return f

func _history_write_fixture() -> Dictionary:
	var f := _fixture(true)
	if f.is_empty(): return {}
	var snapshot: Dictionary = STRICT.parse_object(f.text).value.current_snapshot.snapshot
	var journal := JournalReadProbe.new()
	f.manager._journal = journal
	assert_true(journal.reset(snapshot.run_id).get("ok", false))
	var kinds: Array[StringName] = [&"day_start", &"line", &"manual_save"]
	for index: int in kinds.size():
		snapshot.checkpoint_sequence = index + 1
		snapshot.checkpoint_id = str(snapshot.run_id) + ":" + str(index + 1)
		var prepared := journal.prepare_record(snapshot, kinds[index])
		assert_true(prepared.get("ok", false), str(prepared))
		if not prepared.get("ok", false): return {}
		assert_true(journal.commit_prepared(prepared.value.candidate).get("ok", false))
	var capture := BackupCapture.new()
	capture.result = {"ok": true, "value": {"snapshot_input": snapshot.duplicate(true),
		"dialogic_checkpoint": {}, "route_id": "main", "active_app_id": "backup",
		"audio_context": snapshot.audio_context.duplicate(true), "content_version": int(snapshot.content_version)}}
	f["capture"] = capture
	return f

func _replace(fixture: Dictionary, path: String, text: String) -> void:
	assert_true(fixture.ops.write_bytes(path, text.to_utf8_buffer()).get("ok", false))
	assert_true(fixture.ops.flush_path(path).get("ok", false))

func test_configured_backup_capture_uses_fresh_history_without_reading_discarded_bundles() -> void:
	for locator: String in ["slot:1", "quick"]:
		var f := _history_write_fixture()
		if f.is_empty(): return
		assert_true(f.manager.configure_backup_capture_provider(f.capture.capture).get("ok", false))
		var prior: Dictionary = f.manager._journal.capture_state()
		var persisted: Dictionary = f.ops.snapshot_persisted()
		var expected_earlier: Array = prior.value.backup.earlier.duplicate(true)
		expected_earlier.append(prior.value.backup.current.duplicate(true))
		assert_eq(expected_earlier.size(), 3, "fixture retains semantic, line and manual checkpoints")
		var prepared: Dictionary = f.manager.prepare_backup_action("save", locator)
		assert_true(prepared.get("ok", false), str(prepared))
		if not prepared.get("ok", false): return
		assert_eq(f.manager._journal.disk_bundle_reads, 0)
		assert_eq(f.manager._journal.capture_state(), prior, "prepare does not publish the fresh checkpoint")
		assert_eq(f.ops.snapshot_persisted(), persisted, "prepare cannot write")
		var candidate: Dictionary = f.manager._backup_actions[prepared.value.token].duplicate(true)
		assert_true(CANONICAL._deep_same(candidate.document.recovery_journal, expected_earlier))
		assert_true(CANONICAL._deep_same(candidate.journal_candidate.earlier, expected_earlier))
		assert_eq(candidate.document.current_snapshot.snapshot.checkpoint_sequence, 4)
		assert_eq(candidate.document.current_snapshot.snapshot.active_app_id, "backup")
		assert_eq(prior.value.backup.current.snapshot.active_app_id, null,
			"the fresh capture differs from the stable source")
		var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
		assert_true(committed.get("ok", false), str(committed))
		if not committed.get("ok", false): return
		var path := "slot_1.json" if locator == "slot:1" else "quicksave.json"
		assert_eq(f.storage.read_text(path).value, CANONICAL.stringify(candidate.document).value + "\n")
		var expected_journal: Dictionary = candidate.journal_candidate.duplicate(true)
		expected_journal.erase("candidate_kind")
		assert_true(CANONICAL._deep_same(f.manager._journal.capture_state().value.backup, expected_journal))
		assert_false(f.manager._backup_actions.has(prepared.value.token), "commit consumes consent")

func test_refused_backup_capture_preserves_history_disk_and_existing_consent_without_bundle_read() -> void:
	var f := _history_write_fixture()
	if f.is_empty(): return
	var pending: Dictionary = f.manager.prepare_backup_action("save", "slot:2")
	assert_true(pending.get("ok", false), str(pending))
	if not pending.get("ok", false): return
	f.capture.result = {"ok": false, "code": &"fixture_capture_unavailable"}
	assert_true(f.manager.configure_backup_capture_provider(f.capture.capture).get("ok", false))
	f.manager._journal.disk_bundle_reads = 0
	var prior: Dictionary = f.manager._journal.capture_state()
	var persisted: Dictionary = f.ops.snapshot_persisted()
	var actions: Dictionary = f.manager._backup_actions.duplicate(true)
	var sequence: int = f.manager._backup_action_sequence
	for locator: String in ["slot:1", "quick"]:
		assert_eq(f.manager.prepare_backup_action("save", locator).get("code"), &"fixture_capture_unavailable")
		assert_eq(f.manager._journal.disk_bundle_reads, 0)
		assert_eq(f.manager._journal.capture_state(), prior)
		assert_eq(f.ops.snapshot_persisted(), persisted)
		assert_eq(f.manager._backup_actions, actions, "refusal retains prior consent and creates none")
		assert_eq(f.manager._backup_action_sequence, sequence)
	f.manager.cancel_backup_action(pending.value.token)

func test_unconfigured_backup_capture_reads_and_preserves_stable_retained_history() -> void:
	for locator: String in ["slot:1", "quick"]:
		var f := _history_write_fixture()
		if f.is_empty(): return
		var prior: Dictionary = f.manager._journal.capture_state()
		var persisted: Dictionary = f.ops.snapshot_persisted()
		assert_eq(prior.value.backup.earlier.size(), 2)
		var prepared: Dictionary = f.manager.prepare_backup_action("save", locator)
		assert_true(prepared.get("ok", false), str(prepared))
		if not prepared.get("ok", false): return
		assert_eq(f.manager._journal.disk_bundle_reads, 1)
		var candidate: Dictionary = f.manager._backup_actions[prepared.value.token]
		assert_false(candidate.has("journal_candidate"), "unconfigured save never fabricates a capture")
		assert_true(CANONICAL._deep_same(candidate.document.current_snapshot, prior.value.backup.current))
		assert_true(CANONICAL._deep_same(candidate.document.recovery_journal, prior.value.backup.earlier))
		assert_eq(f.manager._journal.capture_state(), prior)
		assert_eq(f.ops.snapshot_persisted(), persisted)
		f.manager.cancel_backup_action(prepared.value.token)
		assert_true(f.manager._backup_actions.is_empty())
		assert_eq(f.manager._journal.capture_state(), prior, "cancel preserves history")
		assert_eq(f.ops.snapshot_persisted(), persisted, "cancel preserves disk")

func test_cold_and_warm_results_preserve_types_and_are_detached() -> void:
	var manager := _manager()
	var text := '{"integer":1,"decimal":1.0,"nested":{"items":["中文",null]}}'
	var expected := STRICT.parse_object(text)
	var first: Dictionary = manager._parse_document_text(text)
	assert_true(CANONICAL._deep_same(first, expected))
	first.value.nested.items[0] = "first caller edit"
	var second: Dictionary = manager._parse_document_text(text)
	assert_true(CANONICAL._deep_same(second, expected))
	assert_eq(typeof(second.value.integer), TYPE_INT)
	assert_eq(typeof(second.value.decimal), TYPE_FLOAT)
	second.value.nested.items.append("second caller edit")
	assert_true(CANONICAL._deep_same(manager._parse_document_text(text), expected))

func test_exact_text_changes_and_malformed_inputs_keep_strict_results() -> void:
	var manager := _manager()
	for text: String in ['{"value":1}', '{ "value":1}', '{"value":2}']:
		assert_true(CANONICAL._deep_same(manager._parse_document_text(text), STRICT.parse_object(text)))
	assert_eq(manager._document_parse_cache.size(), 2)
	for text: String in ['{"value":1,"value":2}', '{"value":', '[1,2]', '{"value":NaN}']:
		var expected := STRICT.parse_object(text)
		assert_false(expected.get("ok", true))
		assert_eq(manager._parse_document_text(text), expected)
		assert_eq(manager._parse_document_text(text), expected)
		for entry: Dictionary in manager._document_parse_cache:
			assert_ne(entry.text, text, "malformed input is never admitted")

func test_entry_eviction_utf8_budget_and_oversize_bypass() -> void:
	var manager := _manager()
	for text: String in ['{"value":1}', '{"value":2}', '{"value":1}', '{"value":3}']:
		assert_true(manager._parse_document_text(text).get("ok", false))
	assert_eq(manager._document_parse_cache.size(), 2)
	assert_eq(manager._document_parse_cache[0].text, '{"value":1}')
	assert_eq(manager._document_parse_cache[1].text, '{"value":3}')
	# Each source is just over half the UTF-8 budget but under half in characters.
	# Keep the large span ASCII so this bound test does not benchmark Unicode parsing.
	var padding := "x".repeat(4 * 1024 * 1024 - 32)
	var medium := '{"value":"' + padding + "中".repeat(8) + '"}'
	var large := '{"value":"' + padding + "文".repeat(8) + '"}'
	assert_true(manager._parse_document_text(medium).get("ok", false))
	assert_true(manager._parse_document_text(large).get("ok", false))
	assert_eq(manager._document_parse_cache.size(), 1, "UTF-8 bytes, not character count, bound admission")
	assert_eq(manager._document_parse_cache_text_bytes, large.to_utf8_buffer().size())
	var oversized := '{"value":"' + "x".repeat(SAVE._PARSE_CACHE_MAX_TEXT_BYTES) + '"}'
	var parsed: Dictionary = manager._parse_document_text(oversized)
	assert_true(parsed.get("ok", false), "budget does not introduce a parser refusal")
	assert_eq(parsed.value.value.length(), SAVE._PARSE_CACHE_MAX_TEXT_BYTES)
	assert_eq(manager._document_parse_cache.size(), 1)
	assert_eq(manager._document_parse_cache[0].text, large)

func test_initialize_resets_cache_and_disabled_control_preserves_results() -> void:
	var manager := _manager()
	var text := '{"value":[1,2,3]}'
	assert_true(manager._parse_document_text(text).get("ok", false))
	assert_eq(manager._document_parse_cache.size(), 1)
	assert_true(manager.initialize(STORAGE.new("parse-cache", ReadFaultOps.new())).get("ok", false))
	assert_true(manager._document_parse_cache.is_empty())
	assert_eq(manager._document_parse_cache_text_bytes, 0)
	OS.set_environment("DWM_SAVE_PARSE_CACHE_DISABLED", "1")
	assert_eq(manager._parse_document_text(text), STRICT.parse_object(text))
	assert_true(manager._document_parse_cache.is_empty())

func test_warm_inspection_does_not_accept_a_changed_external_target() -> void:
	var f := _fixture()
	if f.is_empty(): return
	var prepared: Dictionary = f.manager.prepare_backup_action("delete", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var changed: String = " " + f.text
	_replace(f, "parse-cache/slot_1.json", changed)
	var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
	assert_false(committed.get("ok", true))
	assert_eq(committed.get("code"), &"stale_backup_target")
	var inspected: Dictionary = f.manager.inspect_backup("slot:1")
	assert_true(inspected.get("ok", false))
	assert_eq(inspected.value.revision, changed.sha256_text())
	assert_eq(f.ops.read_bytes("parse-cache/slot_1.json").value.get_string_from_utf8(), changed)

func test_warm_cache_keeps_storage_refusals_absence_and_schema_validation() -> void:
	var f := _fixture()
	if f.is_empty(): return
	assert_eq(f.manager.inspect_backup("slot:1").value.state, "occupied")
	var validated: Dictionary = f.manager._document_text_validator(f.text)
	assert_true(validated.get("ok", false))
	validated.value.schema_version = -1
	assert_true(f.manager._document_text_validator(f.text).get("ok", false))
	f.ops.refuse_reads = true
	assert_eq(f.manager.inspect_backup("slot:1").get("code"), &"fixture_read_refused")
	f.ops.refuse_reads = false
	var marker: String = f.storage._marker_path("slot_1.json")
	_replace(f, marker, "{}")
	assert_eq(f.manager.inspect_backup("slot:1").get("code"), &"reconcile_required")
	assert_true(f.ops.remove_path(marker).get("ok", false))
	assert_true(f.ops.remove_path("parse-cache/slot_1.json").get("ok", false))
	assert_eq(f.manager.inspect_backup("slot:1").value.state, "empty")
	var invalid := '{"schema_version":999}'
	assert_true(f.manager._parse_document_text(invalid).get("ok", false))
	assert_false(f.manager._document_text_validator(invalid).get("ok", true))
	_replace(f, "parse-cache/slot_1.json", invalid)
	assert_eq(f.manager.inspect_backup("slot:1").value.reason, "newer_version")

func test_warm_inspection_reprepares_participants_and_current_guard() -> void:
	var f := _fixture()
	if f.is_empty(): return
	var participants := {}
	for pair: Array in [["run", "run_plan"], ["desktop_consequence", "consequence_plan"],
		["desktop_board", "board_plan"], ["schedule_view", "schedule_view_plan"],
		["profile", "profile_plan"], ["localization", "localization_plan"],
		["audio", "audio_plan"], ["route", "route_plan"], ["narrative", "narrative_plan"]]:
		participants[pair[0]] = Participant.new(pair[1])
	assert_true(f.manager.configure_restore_participants(participants).get("ok", false))
	var initial: Dictionary = f.manager.inspect_backup("slot:1")
	assert_true(initial.value.loadable, str(initial))
	participants.narrative.unavailable = true
	var changed: Dictionary = f.manager.inspect_backup("slot:1")
	assert_false(changed.value.loadable)
	assert_eq(changed.value.reason, "no_compatible_checkpoint")
	assert_eq(participants.narrative.preparations, 2)
	assert_true(f.manager.acquire_save_lock(&"restore").get("ok", false))
	assert_false(f.manager.inspect_backup("slot:1").value.operation_allowed)
	assert_true(f.manager.release_save_lock(&"restore").get("ok", false))

func test_backup_write_validates_exact_text_once_but_separate_writes_start_fresh() -> void:
	for witness: bool in [false, true]:
		for locator: String in ["slot:1", "quick"]:
			var f := _write_fixture(witness)
			if f.is_empty(): return
			var path := "slot_1.json" if locator == "slot:1" else "quicksave.json"
			var first_text := ""
			for index: int in 2:
				var prepared: Dictionary = f.manager.prepare_backup_action("save", locator)
				assert_true(prepared.get("ok", false), str(prepared))
				if not prepared.get("ok", false): return
				var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
				assert_true(committed.get("ok", false), str(committed))
				if not committed.get("ok", false): return
				var read: Dictionary = f.storage.read_text(path)
				assert_true(read.get("ok", false), str(read))
				if not read.get("ok", false): return
				if index == 0: first_text = read.value
				assert_eq(read.value, first_text, "both writes use identical bytes, including saved_time")
				assert_eq(f.storage.inspect_revision(path).value.revision, first_text.sha256_text())
				assert_eq(f.manager.validation_texts.size(), index + 1,
					"each write validates once; promoted reread reuses only its own proof")
				assert_eq(f.manager.validation_texts[index], first_text)
				assert_false(f.manager.commit_backup_action(prepared.value.token).get("ok", true),
					"reuse never keeps consumed consent alive")

func test_backup_write_validation_results_are_detached_and_refusals_are_not_memoized() -> void:
	var f := _fixture(true)
	if f.is_empty(): return
	var memo := {}
	var first: Dictionary = f.manager._write_document_text_validator(f.text, memo)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	first.value.current_snapshot.snapshot.lifecycle.day = 99
	var second: Dictionary = f.manager._write_document_text_validator(f.text, memo)
	assert_eq(second.value.current_snapshot.snapshot.lifecycle.day, 1)
	second.value.recovery_journal.append({"caller": "edit"})
	assert_true(f.manager._write_document_text_validator(f.text, memo).value.recovery_journal.is_empty())
	assert_eq(f.manager.validation_texts.size(), 1)
	var changed: String = " " + f.text
	assert_true(f.manager._write_document_text_validator(changed, memo).get("ok", false))
	assert_eq(f.manager.validation_texts.size(), 2, "semantically equal JSON still has distinct exact text")
	for invalid: String in ['{"schema_version":999}', '{"duplicate":1,"duplicate":2}']:
		var expected: Dictionary = f.manager._document_text_validator(invalid)
		var count: int = f.manager.validation_texts.size()
		assert_false(expected.get("ok", true))
		for attempt: int in 2:
			assert_eq(f.manager._write_document_text_validator(invalid, memo), expected)
		assert_eq(f.manager.validation_texts.size(), count + 2, "every refused text takes the full validator")
		assert_false(memo.has(invalid))

func test_backup_write_revalidates_changed_or_corrupt_promoted_bytes_and_preserves_custody() -> void:
	for witness: bool in [false, true]:
		for corrupt: bool in [false, true]:
			var f := _write_fixture(witness)
			if f.is_empty(): return
			var before_journal: Dictionary = f.manager._journal.capture_state()
			var prepared: Dictionary = f.manager.prepare_backup_action("save", "slot:1")
			assert_true(prepared.get("ok", false), str(prepared))
			if not prepared.get("ok", false): return
			var document: Dictionary = f.manager._backup_actions[prepared.value.token].document
			var emitted := CANONICAL.stringify(document)
			assert_true(emitted.get("ok", false), str(emitted))
			if not emitted.get("ok", false): return
			var outgoing: String = emitted.value + "\n"
			var replacement := "{" if corrupt else " " + outgoing
			f.ops.promoted_replacement = replacement
			var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
			assert_false(committed.get("ok", true), str(committed))
			assert_eq(committed.get("code"), &"indeterminate_commit")
			assert_true(f.ops.promotion_changed, "fault occurs after actual final promotion")
			assert_eq(f.manager.validation_texts, [outgoing, replacement],
				"changed physical text cannot inherit the outgoing proof")
			var persisted: Dictionary = f.ops.snapshot_persisted()
			assert_eq(persisted["parse-cache/slot_1.json"].get_string_from_utf8(), replacement,
				"unbound evidence is preserved")
			assert_eq(persisted["parse-cache/slot_1.json.revision-prior"].get_string_from_utf8(), f.text,
				"previous save remains in exact custody")
			assert_true(persisted.has("parse-cache/slot_1.json.txn.json"))
			assert_false(f.storage._leases.has("slot_1.json"), "changed final earns no playable lease")
			assert_eq(f.manager._journal.capture_state(), before_journal)
			assert_false(f.manager._backup_actions.has(prepared.value.token))

func test_backup_write_invalid_outgoing_document_keeps_prior_bytes_without_starting_transaction() -> void:
	for witness: bool in [false, true]:
		var f := _write_fixture(witness)
		if f.is_empty(): return
		var prepared: Dictionary = f.manager.prepare_backup_action("save", "slot:1")
		assert_true(prepared.get("ok", false), str(prepared))
		if not prepared.get("ok", false): return
		# Fault injection proves the memo is not seeded from a prepared in-memory document.
		f.manager._backup_actions[prepared.value.token].document.schema_version = 999
		var before: Dictionary = f.ops.snapshot_persisted()
		var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
		assert_false(committed.get("ok", true), str(committed))
		assert_eq(committed.get("code"), &"outgoing_validation_failed")
		assert_eq(f.manager.validation_texts.size(), 1)
		assert_eq(f.ops.snapshot_persisted(), before)
		assert_false(f.manager._backup_actions.has(prepared.value.token))

func test_diagnostic_witness_is_detached_and_requires_each_new_exact_text_admission() -> void:
	var f := _fixture(true, true)
	if f.is_empty(): return
	var memo := {}
	var expected := {"ok": true, "code": &"ok", "value": {}}
	var first: Dictionary = f.manager._write_document_text_validator(f.text, memo)
	assert_eq(first, expected)
	first.value["caller"] = "first edit"
	var second: Dictionary = f.manager._write_document_text_validator(f.text, memo)
	assert_eq(second, expected)
	second.value["caller"] = "later edit"
	assert_eq(f.manager._write_document_text_validator(f.text, memo), expected)
	assert_eq(memo[f.text], expected, "caller edits cannot contaminate the compact proof")
	assert_eq(f.manager.validation_texts, [f.text])
	var changed: String = " " + f.text
	assert_eq(f.manager._write_document_text_validator(changed, memo), expected)
	assert_eq(f.manager.validation_texts, [f.text, changed], "same JSON value is a new exact text")
	for invalid: String in ['{"schema_version":999}', '{"duplicate":1,"duplicate":2}']:
		var refused: Dictionary = f.manager._document_text_validator(invalid)
		assert_false(refused.get("ok", true))
		var count: int = f.manager.validation_texts.size()
		for attempt: int in 2:
			assert_eq(f.manager._write_document_text_validator(invalid, memo), refused)
		assert_eq(f.manager.validation_texts.size(), count + 2)
		assert_false(memo.has(invalid), "refused text never earns a witness")

func test_diagnostic_witness_preserves_malformed_success_and_storage_refuses_before_mutation() -> void:
	var results: Array[Dictionary] = [
		{"ok": false, "code": &"fixture_refusal", "message": "unchanged reason"},
		{"ok": true}, {"ok": true, "value": null},
		{"ok": true, "value": []}, {"ok": true, "value": "not a document"}]
	for witness: bool in [false, true]:
		for forced: Dictionary in results:
			var f := _write_fixture(witness)
			if f.is_empty(): return
			var prepared: Dictionary = f.manager.prepare_backup_action("save", "slot:1")
			assert_true(prepared.get("ok", false), str(prepared))
			if not prepared.get("ok", false): return
			f.manager.validation_override = forced.duplicate(true)
			var memo := {}
			assert_eq(f.manager._write_document_text_validator(f.text, memo), forced,
				"neither helper can turn malformed success or refusal into valid admission")
			if witness: assert_true(memo.is_empty(), "malformed success never earns a witness")
			var before: Dictionary = f.ops.snapshot_persisted()
			var journal: Dictionary = f.manager._journal.capture_state()
			var validation_count: int = f.manager.validation_texts.size()
			var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
			assert_eq(committed.get("code"), &"outgoing_validation_failed", str(committed))
			assert_false(committed.get("ok", true))
			assert_eq(f.manager.validation_texts.size(), validation_count + 1,
				"the public write starts its own memo even after a direct helper call")
			assert_eq(f.ops.snapshot_persisted(), before)
			assert_eq(f.manager._journal.capture_state(), journal)
			assert_false(f.storage._leases.has("slot_1.json"))
			assert_false(f.manager._backup_actions.has(prepared.value.token))

func test_backup_write_rechecks_exact_revision_after_validation_and_retry_starts_fresh() -> void:
	for witness: bool in [false, true]:
		var f := _write_fixture(witness)
		if f.is_empty(): return
		var prepared: Dictionary = f.manager.prepare_backup_action("save", "slot:1")
		assert_true(prepared.get("ok", false), str(prepared))
		if not prepared.get("ok", false): return
		var before_journal: Dictionary = f.manager._journal.capture_state()
		var changed: String = " " + f.text
		var hook_calls := [0]
		var ops: RefCounted = f.ops
		var hook := func() -> Dictionary:
			hook_calls[0] += 1
			if hook_calls[0] == 1:
				var written: Dictionary = ops.write_bytes("parse-cache/slot_1.json", changed.to_utf8_buffer())
				if not written.get("ok", false): return written
				return ops.flush_path("parse-cache/slot_1.json")
			return {"ok": true}
		assert_true(f.storage.configure_before_write(hook).get("ok", false))
		var committed: Dictionary = f.manager.commit_backup_action(prepared.value.token)
		assert_eq(committed.get("code"), &"revision_changed", str(committed))
		assert_false(committed.get("ok", true))
		assert_eq(f.manager.validation_texts.size(), 1, "fault follows full outgoing admission")
		assert_eq(f.ops.snapshot_persisted(), {"parse-cache/slot_1.json": changed.to_utf8_buffer()})
		assert_eq(f.storage.inspect_revision("slot_1.json").value.revision, changed.sha256_text())
		assert_eq(f.manager._journal.capture_state(), before_journal)
		assert_false(f.storage._leases.has("slot_1.json"))
		assert_eq(f.manager.commit_backup_action(prepared.value.token).get("code"), &"stale_backup_action")
		var retry: Dictionary = f.manager.prepare_backup_action("save", "slot:1")
		assert_true(retry.get("ok", false), str(retry))
		if not retry.get("ok", false): return
		assert_true(f.manager.commit_backup_action(retry.value.token).get("ok", false))
		assert_eq(hook_calls[0], 2)
		assert_eq(f.manager.validation_texts.size(), 2, "a refused write cannot seed its retry")
		assert_eq(f.manager.validation_texts[0], f.manager.validation_texts[1], "identical outgoing retry bytes")
		assert_eq(f.storage.read_text("slot_1.json").value, f.manager.validation_texts[1])
