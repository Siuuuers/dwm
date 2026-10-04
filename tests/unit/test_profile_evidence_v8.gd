extends "res://addons/gut/test.gd"
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const OBSERVER := preload("res://scripts/profile/ObserverEvidence.gd")
const RULES := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")
const DECK := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class RejectingStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var reject_write := false
	func _init(root_dir: String, file_ops: RefCounted) -> void: super(root_dir, file_ops)
	func write_atomic(path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		if reject_write: return {"ok": false, "code": &"fixture_write_failed"}
		return super.write_atomic(path, text, validator, keep_backup)

func _receipt(kind: String, run_id: String = "run-a") -> Dictionary:
	var atom: Dictionary = RULES.OBSERVER_ATOMS["lavinia" if kind == "restraint" else "priscilla"]
	var receipt := {"kind": kind, "run_id": run_id, "receipt_id": run_id + ":" + kind,
		"entry_id": atom.entry_id, "line_id": atom.line_id, "presentation_atom_id": atom.presentation_atom_id,
		"comparison_key": atom.comparison_key, "playback_token": "canonical-token"}
	if kind == "capture": receipt["text_variant"] = "original"
	elif kind == "verification": receipt["capture_receipt_id"] = "run-a:capture"
	else:
		receipt["window_id"] = run_id + ":window"
		receipt["duration_ms"] = RULES.OBSERVER_WITHHOLDING_MS
		receipt["intervened"] = false
	return receipt

func _manager(storage: RefCounted = null) -> Node:
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(storage if storage != null else STORAGE.new("evidence-v8", OPS.new())).ok)
	return manager

func test_v7_upgrade_adds_empty_evidence_without_inventing_proofs() -> void:
	var old := SCHEMA.make_defaults()
	old["schema_version"] = 7
	old.erase("reached_presentation_chronology")
	old.erase("witnessed_caption_variants")
	for key: String in ["observer_evidence", "pair_deck_draws", "reached_presentations"]: old.erase(key)
	var before := old.duplicate(true)
	var migrated := MIGRATION.prepare_document(old)
	assert_true(migrated.ok, str(migrated))
	if not migrated.ok: return
	assert_eq(migrated.value.schema_version, SCHEMA.SCHEMA_VERSION)
	for key: String in ["observer_evidence", "pair_deck_draws", "reached_presentations"]: assert_eq(migrated.value[key], {})
	assert_eq(old, before)
	old["observer_evidence"] = {}
	assert_false(MIGRATION.prepare_document(old).ok, "historical source shape remains exact")

func test_verification_requires_registered_capture_from_another_run() -> void:
	var captured := OBSERVER.prepare({}, _receipt("capture"))
	assert_true(captured.ok)
	assert_false(OBSERVER.prepare(captured.value, _receipt("verification")).ok)
	var verified := OBSERVER.prepare(captured.value, _receipt("verification", "run-b"))
	assert_true(verified.ok)
	assert_eq(OBSERVER.evidence(verified.value), {"priscilla": true, "lavinia": false})
	var wrong := _receipt("verification", "run-c")
	wrong["line_id"] = "unregistered"
	assert_false(OBSERVER.prepare(captured.value, wrong).ok)
	assert_false(OBSERVER.prepare({}, _receipt("verification", "run-b")).ok)

func test_restraint_needs_exact_completed_window_without_intervention() -> void:
	var receipt := _receipt("restraint")
	assert_true(OBSERVER.prepare({}, receipt).ok)
	receipt["intervened"] = true
	assert_false(OBSERVER.prepare({}, receipt).ok)
	receipt["intervened"] = false
	receipt["duration_ms"] = 1
	assert_false(OBSERVER.prepare({}, receipt).ok)
	var malformed := SCHEMA.make_defaults()
	malformed["reached_presentations"] = []
	assert_false(SCHEMA.validate(malformed).ok)

func test_profile_evidence_failed_write_retry_and_detached_reads() -> void:
	var storage := RejectingStorage.new("evidence-failure", OPS.new())
	var manager := _manager(storage)
	var before: Dictionary = manager.get_profile_snapshot()
	storage.reject_write = true
	assert_false(manager.record_observer_evidence(_receipt("capture")).ok)
	assert_eq(manager.get_profile_snapshot(), before)
	storage.reject_write = false
	assert_true(manager.record_observer_evidence(_receipt("capture")).ok)
	var revision: int = manager.get_profile_revision()
	assert_true(manager.record_observer_evidence(_receipt("capture")).ok)
	assert_eq(manager.get_profile_revision(), revision)
	var detached: Dictionary = manager.get_observer_evidence().value
	detached.receipts.clear()
	assert_eq(manager.get_observer_evidence().value.receipts.size(), 1)

func test_pair_draw_requires_custody_and_reuses_profile_ahead_record() -> void:
	var manager := _manager()
	var gate := GATE.new()
	assert_true(manager.configure_mutation_gate(gate).ok)
	var draw := DECK.build_draw([], 7)
	var prepared: Dictionary = manager.prepare_pair_deck_draw("run-a", draw.value)
	assert_true(prepared.ok)
	assert_false(manager.commit_pair_deck_draw(prepared.value).ok)
	var lease := gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	assert_true(manager.commit_pair_deck_draw(prepared.value).ok)
	var revision: int = manager.get_profile_revision()
	assert_true(manager.commit_pair_deck_draw(prepared.value).ok)
	assert_eq(manager.get_profile_revision(), revision)
	assert_eq(manager.get_pair_deck_draw("run-a").value, draw.value)
	assert_false(manager.prepare_pair_deck_draw("run-a", DECK.build_draw([], 8).value).ok)
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)

func test_clear_gallery_preserves_observer_and_draw_but_clears_reached_signatures() -> void:
	var manager := _manager()
	assert_true(manager.record_observer_evidence(_receipt("restraint")).ok)
	assert_true(manager.commit_pair_deck_draw(manager.prepare_pair_deck_draw("run-a", DECK.build_legacy("love_sweet").value).value).ok)
	var signature := {"schema_version": 1, "entry_id": "ending.alone.normal", "fields": {"ending_role": "core", "ending_form": "alone_normal"}}
	var reached: Dictionary = manager.record_reached_presentation(signature)
	assert_true(reached.ok, str(reached))
	if not reached.ok: return
	var revision: int = manager.get_profile_revision()
	assert_true(manager.record_reached_presentation(signature).ok)
	assert_eq(manager.get_profile_revision(), revision)
	assert_eq(manager.get_reached_presentations().value.records.size(), 1)
	var before: Dictionary = manager.get_profile_snapshot()
	var rewind := before.duplicate(true)
	rewind["observer_evidence"] = {}
	assert_false(manager.commit_prepared_profile(rewind).ok)
	assert_false(manager.apply_restore_silent(rewind).ok)
	assert_true(manager.reset_gallery().ok)
	assert_eq(manager.get_reached_presentations().value.records, [])
	assert_eq(manager.get_profile_snapshot().observer_evidence, before.observer_evidence)
	assert_eq(manager.get_profile_snapshot().pair_deck_draws, before.pair_deck_draws)
	assert_true(manager.reset_entire_profile().ok)
	assert_eq(manager.get_observer_evidence().value.receipts, {})
	assert_null(manager.get_pair_deck_draw("run-a").value)
