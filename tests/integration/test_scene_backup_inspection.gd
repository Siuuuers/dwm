extends "res://addons/gut/test.gd"
## Real filesystem/issuer/Profile/Run/Save owners. Activation and ancillary
## restore participants are diagnostic; no rendered or production UI claim.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")
const ADMISSION := preload("res://scripts/infrastructure/save/SaveMigrations.gd")

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
	assert_eq(consent.value.record, shown)
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
	assert_eq(refused.get("message"), "selected checkpoint identity or content conflicts")
	assert_eq(_observed(), before, "source admission changes no saved or live gameplay state")
