extends "res://addons/gut/test.gd"
## Real filesystem/issuer/Profile/Run/Save owners. Activation and ancillary
## restore participants are diagnostic; no rendered or production UI claim.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const ADMISSION := preload("res://scripts/infrastructure/save/SaveMigrations.gd")
const RUN_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const VALIDATION_TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")

class RefusingRun extends "res://scripts/application/restore/RunRestoreParticipant.gd":
	var calls := 0
	func _init(owner: Object) -> void:
		super(owner)
	func prepare(_input: Dictionary) -> Dictionary:
		calls += 1
		return {"ok": false, "code": &"custom_run_refusal"}

class EditingNarrative extends RefCounted:
	var delegate: RefCounted
	var calls := 0
	func prepare(input: Dictionary) -> Dictionary:
		calls += 1
		# Deliberate injected participant violation after successful admission.
		input.snapshot.content_version = -1
		return delegate.prepare(input)

var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false): return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	fixture_ready = fixture.manager.capture_committed_scene_creation(started.transaction_id).get("ok", false)
	assert_true(fixture_ready)

func after_all() -> void:
	if fixture != null: fixture.close()

func test_admitted_scene_inspection_and_cancelled_consent_preserve_physical_and_live_state() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var before: Dictionary = _observed()
	var retained_before: Array = fixture.manager._scene_restore_preparations.keys()
	var inspected: Dictionary = fixture.manager.inspect_backup("autosave")
	assert_true(inspected.get("ok", false), str(inspected))
	if not inspected.get("ok", false): return
	assert_eq(fixture.manager._scene_restore_preparations.keys(), retained_before,
		"metadata inspection creates no private preparation")
	var record: Dictionary = inspected.value
	assert_eq(record.state, "occupied")
	assert_eq(record.family, "scene")
	assert_eq(record.load_family, "scene")
	assert_null(record.day)
	assert_null(record.load_day)
	assert_true(record.loadable)
	assert_false(record.fallback)
	assert_eq(record.revision, fixture.storage.inspect_revision("autosave.json").value.revision)
	var document: Dictionary = fixture.read_autosave().value
	assert_eq(record.saved_time, document.saved_time.hhmm)
	assert_eq(record.load_saved_time, record.saved_time)
	assert_false(record.has("prepared_restore"))
	var port := PORT.new()
	assert_true(port.configure(fixture.manager, "title").ok)
	var projection: Dictionary = port.get_projection()
	assert_true(projection.ok, str(projection))
	assert_eq(fixture.manager._scene_restore_preparations.keys(), retained_before,
		"listing nine slots retains no discarded preparation")
	var shown: Dictionary = projection.value.records[0]
	assert_eq(shown.family, "scene")
	assert_eq(shown.load_family, "scene")
	assert_null(shown.day)
	assert_null(shown.load_day)
	assert_true(shown.actions.load)
	assert_false(shown.actions.save)
	for key: String in ["revision", "prepared_restore", "snapshot", "scene_preparation_token"]:
		assert_false(shown.has(key), "private custody stays with SaveManager")
	var empty: Dictionary = projection.value.records[1]
	assert_eq(empty.state, "empty")
	assert_null(empty.family)
	assert_null(empty.load_family)
	var consent: Dictionary = port.prepare_action("load", "autosave")
	assert_true(consent.ok, str(consent))
	if not consent.ok: return
	var expected_consent := shown.duplicate(true)
	expected_consent.actions = {"save": false, "load": true, "delete": false}
	assert_eq(consent.value.record, expected_consent)
	assert_false(consent.value.confirmation_required, "Title loads the selected current state without extra confirmation")
	var held: Dictionary = fixture.manager._backup_actions[consent.value.token].prepared_restore.duplicate(true)
	var retained: Dictionary = fixture.manager._scene_restore_preparations.duplicate(true)
	assert_eq(retained.size(), retained_before.size() + 1, "selected Load retains its own preparation")
	for refresh: int in range(2):
		assert_eq(fixture.manager.inspect_backup("autosave"), inspected, "inspection metadata stays identical")
		assert_eq(port.get_projection(), projection, "refreshed slot metadata stays identical")
		assert_true(fixture.manager._same_scene_preparation(fixture.manager._scene_restore_preparations, retained),
			"refresh %d neither grows retained plans nor changes selected custody" % refresh)
		assert_true(fixture.manager._validate_scene_restore_preparation(held).get("ok", false),
			"a separately prepared Load remains valid after refresh")
	port.cancel_action(consent.value.token)
	assert_eq(port.commit_action(consent.value.token).get("code"), &"stale_backup_action")
	assert_true(fixture.manager._backup_actions.is_empty())
	assert_eq(fixture.manager._scene_restore_preparations.keys(), retained_before, "cancel releases only the selected Load preparation")
	assert_eq(_observed(), before, "inspection/prepare/cancel does not write, allocate or publish")

func test_unadmitted_scene_shaped_bytes_have_no_family_or_load_permission() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	# Deliberate corrupt-file diagnostic; never used as a positive scene source.
	var raw := '{"schema_version":9,"kind":"slot","slot_id":7}'
	var written: Dictionary = fixture.storage.write_atomic("slot_7.json", raw,
		func(_text: String) -> Dictionary: return {"ok": true, "value": {}})
	assert_true(written.ok, str(written))
	if not written.ok: return
	var before: Dictionary = fixture.storage.inspect_revision("slot_7.json")
	var retained_before: Array = fixture.manager._scene_restore_preparations.keys()
	var inspected: Dictionary = fixture.manager.inspect_backup("slot:7")
	assert_true(inspected.ok)
	assert_eq(inspected.value.state, "unavailable")
	assert_eq(inspected.value.reason, "unreadable", "supported schema number is not a future version or admission")
	assert_null(inspected.value.family)
	assert_null(inspected.value.load_family)
	assert_null(inspected.value.day)
	assert_false(inspected.value.loadable)
	assert_eq(fixture.manager.prepare_backup_action("load", "slot:7").get("code"), &"backup_load_unavailable")
	assert_eq(fixture.storage.inspect_revision("slot_7.json"), before)
	assert_eq(fixture.manager._scene_restore_preparations.keys(), retained_before)
	assert_true(fixture.manager._backup_actions.is_empty())

func test_player_format_check_accepts_only_current_integral_version_without_mutation() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	for version: Variant in [9, 9.0]:
		assert_eq(fixture.manager._player_save_format_reason({"schema_version": version}), "")
	for version: Variant in [0, 7, 8, 8.0, 10, 9.5, "9", null, true, {}, [], INF]:
		var raw := {"schema_version": version}
		var before := raw.duplicate(true)
		assert_ne(fixture.manager._player_save_format_reason(raw), "", str(version))
		assert_eq(raw, before)
	assert_eq(fixture.manager._player_save_format_reason({}), "unreadable")

func test_player_load_refuses_old_slot_quick_and_autosave_before_restoration() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	for item: Dictionary in [{"locator": "slot:6", "path": "slot_6.json", "method": "prepare_restore_slot"},
			{"locator": "quick", "path": "quicksave.json", "method": "prepare_restore_quick"},
			{"locator": "autosave", "path": "autosave.json", "method": "prepare_restore_autosave"}]:
		var existed: bool = fixture.storage.exists(item.path)
		var original: Dictionary = fixture.storage.read_text(item.path) if existed else {}
		# This is a version-boundary diagnostic, not a relabeled valid Run9.
		var raw := '{"schema_version":8,"current_snapshot":{"snapshot":{"schema_version":8}}}'
		var written: Dictionary = fixture.storage.write_atomic(item.path, raw,
			func(_text: String) -> Dictionary: return {"ok": true, "value": {}})
		assert_true(written.ok, str(written))
		if not written.ok: continue
		var before := _observed()
		var physical: Dictionary = fixture.storage.inspect_revision(item.path)
		var inspected: Dictionary = fixture.manager.inspect_backup(item.locator)
		assert_true(inspected.ok, str(inspected))
		assert_eq(inspected.value.reason, "older_version")
		assert_false(inspected.value.loadable)
		assert_null(inspected.value.family)
		assert_eq(fixture.manager.prepare_backup_action("load", item.locator).get("code"), &"unsupported_save_format")
		var direct: Dictionary = fixture.manager.call(item.method, 6) if item.locator == "slot:6" \
			else fixture.manager.call(item.method)
		assert_eq(direct.get("code"), &"unsupported_save_format", str(direct))
		assert_eq(fixture.storage.inspect_revision(item.path), physical)
		assert_eq(_observed(), before, "refusal does not allocate, apply, publish or write")
		assert_true(fixture.manager._backup_actions.is_empty())
		if existed:
			assert_true(fixture.storage.write_atomic(item.path, original.value,
				func(_text: String) -> Dictionary: return {"ok": true, "value": {}}).ok)
		else:
			assert_true(fixture.storage.remove(item.path).ok)

func test_unsupported_slot_can_be_deleted_or_overwritten_with_current_scene() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var raw := '{"schema_version":8,"current_snapshot":{"snapshot":{"schema_version":8}}}'
	var before := _observed()
	for action: String in ["delete", "save"]:
		assert_true(fixture.storage.write_atomic("slot_6.json", raw,
			func(_text: String) -> Dictionary: return {"ok": true, "value": {}}).ok)
		var port := PORT.new()
		assert_true(port.configure(fixture.manager, "in_run").ok)
		var projected: Dictionary = port.get_projection()
		assert_true(projected.ok, str(projected))
		var record: Dictionary = projected.value.records[7]
		assert_eq(record.locator, "slot:6")
		assert_false(record.actions.load)
		assert_true(record.actions[action], str(record))
		var prepared: Dictionary = port.prepare_action(action, "slot:6")
		assert_true(prepared.ok, str(prepared))
		if not prepared.ok: continue
		var committed: Dictionary = port.commit_action(prepared.value.token)
		assert_true(committed.ok, str(committed))
		if action == "delete":
			assert_false(fixture.storage.exists("slot_6.json"))
		else:
			var saved: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
				fixture.storage.read_text("slot_6.json").value)
			assert_true(saved.ok, str(saved))
			assert_eq(saved.value.schema_version, 9)
			assert_eq(saved.value.recovery_journal, [])
			assert_true(fixture.manager.inspect_backup("slot:6").value.loadable)
		assert_eq(_observed(), before, "Save/Delete leave current gameplay and its chronology unchanged")
	assert_true(fixture.storage.remove("slot_6.json").ok)

func _observed() -> Dictionary:
	return {"autosave": fixture.storage.read_text("autosave.json"),
		"profile": fixture.storage.read_text("profile.json"), "root": fixture.issuer.capture_root(),
		"game": fixture.game.capture_restore_state(), "profile_state": fixture.profile.get_profile_snapshot(),
		"profile_revision": fixture.profile.get_profile_revision(), "journal": fixture.manager._journal.capture_state(),
		"route_publications": fixture.participants.route.publications,
		"narrative_publications": fixture.participants.narrative.publications}

func test_scene_admission_seed_matches_generic_and_detaches_all_owned_material() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var raw: Dictionary = fixture.read_autosave().value
	# Schema diagnostic from a real admitted creation, not a played checkpoint journey.
	var first: Dictionary = raw.current_snapshot.duplicate(true)
	var second: Dictionary = first.duplicate(true)
	second.checkpoint_kind = "safe_marker"
	second.snapshot.checkpoint_sequence = 2
	second.snapshot.checkpoint_id = second.snapshot.run_id + ":2"
	raw.current_snapshot.checkpoint_kind = "safe_marker"
	raw.current_snapshot.snapshot.checkpoint_sequence = 3
	raw.current_snapshot.snapshot.checkpoint_id = raw.current_snapshot.snapshot.run_id + ":3"
	raw.recovery_journal = [second, first]
	var source := raw.duplicate(true)
	var material := {}
	var admitted: Dictionary = ADMISSION.migrate_document(raw, {"kind": "autosave", "slot_id": null},
		fixture.manager._capture_scene_seed_material.bind(material))
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	assert_eq(admitted.value.keys(), ["document", "legacy_profile_patch_input", "migration_receipts"])
	assert_false(material.is_empty())
	var document: Dictionary = admitted.value.document
	var selected: Dictionary = document.current_snapshot
	var before := _observed()
	var generic: Dictionary = fixture.manager._journal.prepare_seed(document, selected)
	var reused: Dictionary = fixture.manager._prepare_restore_seed(document, selected, material)
	assert_true(generic.ok, str(generic))
	assert_eq(reused, generic, "candidate and diagnostics equal full validation")
	for earlier: Dictionary in document.recovery_journal:
		assert_eq(fixture.manager._prepare_restore_seed(document, earlier, material),
			fixture.manager._journal.prepare_seed(document, earlier),
			"earlier selection excludes later history with identical order, bounds and diagnostics")
	var invalid := source.duplicate(true)
	invalid.recovery_journal.append(invalid.recovery_journal[0].duplicate(true))
	var refused_material := {}
	var refused: Dictionary = ADMISSION.migrate_document(invalid, {"kind": "autosave", "slot_id": null},
		fixture.manager._capture_scene_seed_material.bind(refused_material))
	assert_eq(refused, ADMISSION.migrate_document(invalid, {"kind": "autosave", "slot_id": null}))
	assert_false(refused.ok, "duplicate scene history is refused before producing reuse material")
	assert_true(refused_material.is_empty())
	var observer_result: Dictionary = ADMISSION.migrate_document(raw, {"kind": "autosave", "slot_id": null},
		func(received: Dictionary, bundles: Array) -> void:
			received.clear()
			bundles.clear())
	assert_eq(observer_result, admitted, "receiver cannot mutate the public validated candidate")
	assert_eq(_observed(), before, "pure seeding changes no owner or file")
	if not reused.ok: return
	reused.value.candidate.current.snapshot.content_version = -1
	assert_eq(reused.value.candidate.earlier.size(), 2)
	if reused.value.candidate.earlier.size() == 2:
		reused.value.candidate.earlier[0].snapshot.content_version = -1
	assert_eq(fixture.manager._prepare_restore_seed(document, selected, material), generic,
		"returned candidate cannot mutate retained admission material")
	assert_eq(raw, source)
	var selected_drift := selected.duplicate(true)
	selected_drift.snapshot.checkpoint_id = "not-admitted"
	assert_eq(fixture.manager._prepare_restore_seed(document, selected_drift, material),
		fixture.manager._journal.prepare_seed(document, selected_drift), "unknown selection uses ordinary refusal")
	document.current_snapshot.snapshot.content_version = -1
	var changed: Dictionary = fixture.manager._prepare_restore_seed(document, document.current_snapshot, material)
	assert_eq(changed, fixture.manager._journal.prepare_seed(document, document.current_snapshot),
		"edited admission result cannot borrow its earlier proof")
	assert_false(changed.ok)
	assert_eq(material.document, source, "private proof does not alias the mutable admission result")
	assert_eq(raw, source)

func test_scene_restore_participant_edit_reenters_generic_seed_validation() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var before := _observed()
	var retained_before: Array = fixture.manager._scene_restore_preparations.keys()
	var original: RefCounted = fixture.manager._restore_participants.narrative
	var editor := EditingNarrative.new()
	editor.delegate = original
	fixture.manager._restore_participants.narrative = editor
	var refused: Dictionary = fixture.manager.prepare_restore_autosave()
	fixture.manager._restore_participants.narrative = original
	assert_eq(editor.calls, 1, "edit occurs after full admission and earlier participant prepares")
	assert_eq(refused.get("code"), &"selected_bundle_missing", str(refused))
	assert_eq(fixture.manager._scene_restore_preparations.keys(), retained_before)
	assert_eq(_observed(), before, "a callback edit cannot install a seed or change stored/live state")

func _measure_run_prepare(operation: Callable) -> Dictionary:
	var had_environment := OS.has_environment("DWM_SCENE_VALIDATION_PROFILE")
	var previous := OS.get_environment("DWM_SCENE_VALIDATION_PROFILE")
	OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", "1")
	var started := VALIDATION_TIMING.begin_scope("restore_run_diagnostic", "", "", 0)
	var result: Dictionary = {}
	var validations := -1
	if started:
		result = operation.call()
		validations = VALIDATION_TIMING._record.snapshot_validations.size()
		VALIDATION_TIMING.end_scope(bool(result.get("ok", false)))
	if had_environment:
		OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", previous)
	else:
		OS.unset_environment("DWM_SCENE_VALIDATION_PROFILE")
	assert_true(started, "diagnostic scope is independent and restores its environment")
	return {"result": result, "validations": validations}

func _admitted_run_material() -> Dictionary:
	var material := {}
	var admitted: Dictionary = ADMISSION.migrate_document(fixture.read_autosave().value,
		{"kind": "autosave", "slot_id": null}, fixture.manager._capture_scene_seed_material.bind(material))
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return {}
	return {"document": admitted.value.document, "material": material}

func test_admitted_run_plan_reuses_one_validation_and_remains_detached() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	assert_true(RUN_SCHEMA._scene_can_reuse_reading(), "fixture uses the real GameState, bridge and SaveManager owners")
	var source := _admitted_run_material()
	if source.is_empty(): return
	var document: Dictionary = source.document
	var source_before := document.duplicate(true)
	var before := _observed()
	var participant: RefCounted = fixture.manager._restore_participants.run
	var generic := _measure_run_prepare(func() -> Dictionary:
		return participant.prepare({"snapshot": document.current_snapshot.snapshot}))
	participant._scene_creation_plan = {"stale": true}
	participant._scene_creation_owner = fixture.manager
	var reused := _measure_run_prepare(func() -> Dictionary:
		return fixture.manager._prepare_run_restore(document.current_snapshot, document, source.material))
	assert_true(reused.result.get("ok", false), str(reused))
	assert_eq(reused.result, generic.result)
	assert_eq(generic.validations, 1, "real initial snapshot performs one complete validation")
	assert_eq(reused.validations, 0, "same-call admission discharges only that repeated validation")
	assert_true(participant._scene_creation_plan.is_empty())
	assert_null(participant._scene_creation_owner)
	if not reused.result.get("ok", false): return
	reused.result.value.run_plan.snapshot.lifecycle.state = "INVALID"
	assert_eq(document, source_before, "returned plan cannot mutate its source")
	assert_eq(source.material.document, source_before, "returned plan cannot mutate private admission material")
	assert_eq(_observed(), before, "preparing either plan changes no physical or live owner")

func test_run_reuse_falls_back_for_missing_material_changed_input_and_owner() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source := _admitted_run_material()
	if source.is_empty(): return
	var document: Dictionary = source.document
	var participant: RefCounted = fixture.manager._restore_participants.run
	var missing := _measure_run_prepare(func() -> Dictionary:
		return fixture.manager._prepare_run_restore(document.current_snapshot, document, {}))
	assert_true(missing.result.get("ok", false), str(missing))
	assert_eq(missing.validations, 1)
	var owner: Object = participant._owner
	participant._owner = fixture.profile
	var foreign := _measure_run_prepare(func() -> Dictionary:
		return fixture.manager._prepare_run_restore(document.current_snapshot, document, source.material))
	participant._owner = owner
	assert_eq(foreign.result, missing.result, "mismatched participant owner keeps ordinary validation")
	assert_eq(foreign.validations, 1)
	var changed: Dictionary = document.duplicate(true)
	changed.current_snapshot.snapshot.content_version = -1
	participant._scene_creation_plan = {"stale": true}
	participant._scene_creation_owner = fixture.manager
	var refused := _measure_run_prepare(func() -> Dictionary:
		return fixture.manager._prepare_run_restore(changed.current_snapshot, changed, source.material))
	assert_false(refused.result.get("ok", true), str(refused))
	assert_eq(refused.validations, 1, "mutated source cannot borrow its prior admission")
	assert_true(participant._scene_creation_plan.is_empty(), "failed ordinary preparation clears stale creation")
	assert_null(participant._scene_creation_owner)
	assert_eq(refused.result, participant.prepare({"snapshot": changed.current_snapshot.snapshot}))
	var retried := _measure_run_prepare(func() -> Dictionary:
		return fixture.manager._prepare_run_restore(document.current_snapshot, document, source.material))
	assert_eq(retried.result, missing.result, "a refusal does not poison later valid admission")
	assert_eq(retried.validations, 0)

func test_run_reuse_preserves_custom_participant_refusal_on_public_load() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var before := _observed()
	var retained: Array = fixture.manager._scene_restore_preparations.keys()
	var original: RefCounted = fixture.manager._restore_participants.run
	var custom := RefusingRun.new(fixture.game)
	fixture.manager._restore_participants.run = custom
	var refused: Dictionary = fixture.manager.prepare_restore_autosave()
	fixture.manager._restore_participants.run = original
	assert_eq(refused.get("code"), &"custom_run_refusal")
	assert_eq(custom.calls, 1, "a subclass keeps control of its own prepare contract")
	assert_eq(fixture.manager._scene_restore_preparations.keys(), retained)
	assert_eq(_observed(), before)

func test_current_scene_source_admission_preserves_state_and_rejects_changed_hash() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var before: Dictionary = _observed()
	var document: Dictionary = fixture.read_autosave().value
	var locator: Dictionary = fixture.manager._build_source_locator(document.kind, document.slot_id, document.current_snapshot)
	# The real created Save9 is the source. This diagnostic exercises only the
	# journal's source binding, without allocating or committing a new operation.
	var operation := {"kind": "scene_restore", "transaction_id": "source-binding-diagnostic",
		"selected_document": document, "source_locator": locator}
	operation["request_fingerprint"] = fixture.manager._canonical_sha256(operation)
	var journal: RefCounted = fixture.manager._continuation_journal
	var accepted: Dictionary = journal._validate_scene_source(operation)
	assert_true(accepted.get("ok", false), str(accepted))
	var changed := operation.duplicate(true)
	changed.source_locator.document_sha256 = "0".repeat(64)
	# Bind the changed request itself so rejection must come from the source hash.
	var request := changed.duplicate(true)
	request.erase("request_fingerprint")
	changed.request_fingerprint = fixture.manager._canonical_sha256(request)
	var refused: Dictionary = journal._validate_scene_source(changed)
	assert_false(refused.get("ok", true))
	assert_eq(refused.get("message"), "DesktopContinuationOperationJournal: selected checkpoint identity or content conflicts")
	assert_eq(_observed(), before, "source admission changes no saved or live gameplay state")

func test_new_scene_writes_omit_fallback_snapshots_without_changing_admitted_history() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var before := _observed()
	var source: Dictionary = fixture.read_autosave().value
	var original: Dictionary = source.current_snapshot.duplicate(true)
	source.recovery_journal = [original]
	source.current_snapshot.snapshot.checkpoint_sequence = 2
	source.current_snapshot.snapshot.checkpoint_id = original.snapshot.run_id + ":2"
	var admitted: Dictionary = ADMISSION.migrate_document(source, {"kind": "autosave", "slot_id": null})
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	var unchanged: Dictionary = admitted.value.document.duplicate(true)
	var journal := preload("res://scripts/infrastructure/save/CheckpointJournal.gd").new()
	var seeded: Dictionary = journal.prepare_seed(admitted.value.document, admitted.value.document.current_snapshot)
	assert_true(seeded.ok, str(seeded))
	if not seeded.ok: return
	assert_true(journal.commit_prepared(seeded.value.candidate).ok)
	var rollback: Dictionary = journal.capture_state().value.backup
	assert_eq(rollback.earlier, [original], "existing source history is still admitted and retained for rollback")
	assert_eq(journal.get_bundles_for_disk(), [], "a new direct Save omits existing fallback history")
	for kind: StringName in [&"autosave", &"quick", &"slot"]:
		var reason: StringName = &"automatic" if kind == &"autosave" else (&"quick" if kind == &"quick" else &"manual")
		var slot: Variant = 1 if kind == &"slot" else null
		var built: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").build(
			kind, slot, reason, journal.get_current_bundle().value.bundle, journal.get_bundles_for_disk())
		assert_true(built.ok, str(built))
		if not built.ok: return
		assert_eq(built.value.recovery_journal, [])
		assert_eq(built.value.current_snapshot, unchanged.current_snapshot,
			"writing preserves the complete selected snapshot, including receipts and creation authority")
	for kind: StringName in [&"line", &"manual_save", &"safe_marker"]:
		var next: Dictionary = journal.get_current_bundle().value.bundle.snapshot
		next.checkpoint_sequence = journal.peek_next_sequence(next.run_id).value.checkpoint_sequence
		next.checkpoint_id = next.run_id + ":" + str(next.checkpoint_sequence)
		var prepared: Dictionary = journal.prepare_record(next, kind)
		assert_true(prepared.ok, str(prepared))
		if not prepared.ok: return
		assert_eq(prepared.value.candidate.earlier, [], "all new scene checkpoint kinds discard full fallback copies")
		assert_true(journal.commit_prepared(prepared.value.candidate).ok)
		assert_eq(journal.get_current_bundle().value.bundle.snapshot, next)
		assert_eq(journal.peek_next_sequence(next.run_id).value.checkpoint_sequence, next.checkpoint_sequence + 1)
		assert_false(journal.commit_prepared(prepared.value.candidate).ok, "duplicate commit remains refused")
	assert_true(journal.restore_state(rollback).ok)
	assert_eq(journal.capture_state().value.backup, rollback, "rollback restores prior cursor and admitted history exactly")
	assert_eq(admitted.value.document, unchanged, "new writing never edits the admitted source document")
	assert_eq(_observed(), before, "isolated journal writes do not alter live or durable creation owners")

func test_scene_gameplay_adoption_and_recapture_preserve_progress_without_relationship_fields() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source: Dictionary = fixture.read_autosave().value.current_snapshot.snapshot.duplicate(true)
	source.gameplay.money = 37
	source.gameplay.coins = 4
	source.gameplay.inventory = {"lucky_charm": 1}
	source.gameplay.stats.pressure = 7
	source.gameplay.minesweeper_rounds_left = 1
	source.gameplay.minesweeper_app_rounds_finished_today = 1
	source.gameplay.minesweeper_money_earned_today = 9
	source.gameplay.minesweeper_task_rewards_claimed = {"complete_beginner": true}
	source.gameplay.penalty_points_today = 2
	source.gameplay.penalty_points_total = 5
	source.gameplay.story_flags = {"TEST.retained": true}
	var admitted := RUN_SCHEMA.validate(source)
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	# Exercise actual silent GameState adoption/capture, not SaveManager or native Load.
	var restored := preload("res://autoload/GameState.gd").new()
	restored.reset_game()
	var configured: Dictionary = restored._run_lifecycle.configure_scene_issuer(fixture.issuer)
	assert_true(configured.ok, str(configured))
	var installed: Dictionary = restored._install_scene_snapshot_silent(admitted.value.candidate)
	assert_true(installed.ok, str(installed))
	if installed.ok:
		var captured: Dictionary = restored.capture_run_snapshot_input()
		assert_eq(captured.gameplay, source.gameplay, "adoption preserves every saved gameplay value")
		for key: String in ["affection", "friend_attitude", "friends", "inter_friend_affection"]:
			assert_false(captured.gameplay.has(key), "scene capture cannot reintroduce " + key)
		assert_eq(captured.desktop, source.desktop, "board state is untouched")
		assert_eq(captured.contacts, source.contacts, "contact progress is untouched")
		captured.gameplay.inventory.lucky_charm = 99
		assert_eq(restored.inventory.lucky_charm, 1, "captured inventory stays detached")
	restored.free()

func test_scene_progress_without_matching_command_is_refused_without_mutation() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source: Dictionary = fixture.read_autosave().value.current_snapshot.snapshot.duplicate(true)
	assert_true(RUN_SCHEMA.validate(source).ok)
	var before := _observed()
	for field: String in ["scene_choices", "scene_challenge_outcomes"]:
		var changed := source.duplicate(true)
		changed.gameplay[field] = {"TEST.opportunity": "pass"} if field == "scene_choices" else {
			"a".repeat(64): {"challenge_id": "TEST.challenge", "outcome": "never_started"}}
		var unchanged := changed.duplicate(true)
		var refused := RUN_SCHEMA.validate(changed)
		assert_false(refused.ok, "well-shaped facts require matching committed events")
		assert_eq(refused.get("code"), &"scene_progress_mismatch", str(refused))
		assert_eq(changed, unchanged, "refusal does not rewrite submitted facts")
	assert_eq(_observed(), before, "invalid progress does not alter owners or files")

func test_scene_app_metadata_is_omitted_and_cannot_select_restore_surface() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var source: Dictionary = fixture.read_autosave().value.current_snapshot.snapshot.duplicate(true)
	assert_false(source.has("active_app_id"), "current player saves omit transient app selection")
	var before := _observed()
	var context := RUN_SCHEMA.derive_route_restore_context(source)
	assert_true(context.ok, str(context))
	if not context.ok: return
	assert_null(context.value.active_app_id, "a scene without an active visible desktop board resumes with no app")
	assert_eq(context.value.contacts, source.contacts, "Contacts progress is independent of its window")
	for old_app: Variant in ["contacts", "shop", "backup", "settings", "minesweeper", "unknown-app", 42, {"invalid": true}]:
		var with_metadata := source.duplicate(true)
		with_metadata["active_app_id"] = old_app
		var unchanged := with_metadata.duplicate(true)
		var admitted := RUN_SCHEMA.validate(with_metadata)
		assert_true(admitted.ok, str(admitted))
		if not admitted.ok: continue
		assert_eq(admitted.value.candidate, source, "optional app metadata cannot alter progress")
		assert_eq(RUN_SCHEMA.derive_route_restore_context(with_metadata), context,
			"required surface comes from current gameplay, not saved window selection")
		assert_eq(with_metadata, unchanged, "admission never edits selected bytes")
	assert_eq(_observed(), before, "metadata admission changes no live or durable owner")
