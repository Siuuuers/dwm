extends "res://addons/gut/test.gd"
## Real Profile/ledger/revision-write owners over injected FileOps. Issuer and
## completed Run creation chronology remain the joint New Run owner's obligation.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const DRAW := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class RefusingStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var refuse := false
	func _init(root: String, ops: RefCounted) -> void: super(root, ops)
	func write_atomic_if_revision(path: String, text: String, validator: Callable, revision: String) -> Dictionary:
		if refuse: return {"ok": false, "code": &"TEST.profile_write_refused"}
		return super.write_atomic_if_revision(path, text, validator, revision)

func _fixture() -> Dictionary:
	var ops := OPS.new()
	var storage := RefusingStorage.new("TEST.scene.assignment", ops)
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(storage).ok)
	assert_true(profile.configure_new_run_storage(storage).ok)
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.preferences.dark_mode = {"available": true, "next_run_enabled": true}
	assert_true(profile.commit_prepared_profile(candidate).ok)
	var gate := GATE.new()
	assert_true(profile.configure_mutation_gate(gate).ok)
	return {"profile": profile, "ops": ops, "storage": storage, "gate": gate}

func _prepare(f: Dictionary, run_id: String, transaction: String, nonce: Variant = null) -> Dictionary:
	return f.profile.prepare_scene_new_run_consumption(f.profile.get_profile_revision(), run_id, transaction, nonce)

func _persist_and_adopt(f: Dictionary, material: Dictionary) -> void:
	var lease: Dictionary = f.gate.acquire(&"new_run")
	assert_true(lease.ok)
	assert_true(f.profile.persist_new_run_consumption(material).ok)
	assert_true(f.profile.prove_new_run_consumption(material).ok)
	assert_true(f.profile.apply_restore_silent({"profile": material.candidate}).ok)
	assert_true(f.gate.release(&"new_run", lease.value.token).ok)

func test_first_uint32_draw_has_both_forms_and_exact_receipt_types() -> void:
	for nonce: int in [0, 1, 4294967294, 4294967295]:
		var result: Dictionary = DRAW.prepare_scene_assignment({}, "run-a", "create-a", nonce)
		assert_true(result.ok, str(result))
		if not result.ok: continue
		assert_eq(result.value.form, "sweet" if nonce % 2 == 0 else "dark")
		assert_eq(result.value.selection_kind, "initial_random")
		assert_eq(result.value.size(), 7)
		assert_null(result.value.predecessor_run_id)
		assert_true(DRAW.validate(result.value).ok)
	for nonce: Variant in [null, -1, 4294967296, 1.0, true, "1"]:
		assert_false(DRAW.prepare_scene_assignment({}, "run-a", "create-a", nonce).ok)
	var malformed: Dictionary = DRAW.prepare_scene_assignment({}, "run-a", "create-a", 0).value
	malformed.ruleset_id = {}
	assert_false(DRAW.validate(malformed).ok)
	malformed = DRAW.prepare_scene_assignment({}, "run-a", "create-a", 0).value
	malformed.form = &"sweet"
	assert_false(DRAW.validate(malformed).ok)
	malformed = DRAW.prepare_scene_assignment({}, "run-a", "create-a", 0).value
	malformed[&"extra"] = 1
	assert_false(DRAW.validate(malformed).ok)

func test_chain_alternates_from_unique_tail_independent_of_dictionary_order_and_retries() -> void:
	var first: Dictionary = DRAW.prepare_scene_assignment({}, "run-z", "create-z", 0).value
	var second: Dictionary = DRAW.prepare_scene_assignment({"run-z": first}, "run-a", "create-a").value
	var ledger := {"run-a": second, "run-z": first}
	var third: Dictionary = DRAW.prepare_scene_assignment(ledger, "run-m", "create-m")
	assert_true(third.ok)
	assert_eq(third.value.form, "sweet")
	assert_eq(third.value.predecessor_run_id, "run-a")
	assert_eq(third.value.selection_kind, "alternate")
	assert_null(third.value.rng_nonce)
	assert_eq(third.value.predecessor_assignment_sha256, str(WRITER.stringify(second).value).sha256_text())
	assert_eq(DRAW.prepare_scene_assignment(ledger, "run-z", "create-z", 1).value, first, "retry cannot reroll")
	assert_false(DRAW.prepare_scene_assignment(ledger, "run-z", "different", 0).ok)
	assert_false(DRAW.prepare_scene_assignment(ledger, "different", "create-z").ok)
	assert_false(DRAW.prepare_scene_assignment(ledger, "run-m", "create-m", 0).ok)

func test_whole_ledger_refuses_forks_cycles_missing_predecessors_hashes_and_duplicate_transactions() -> void:
	var first: Dictionary = DRAW.prepare_scene_assignment({}, "run-a", "create-a", 0).value
	var second: Dictionary = DRAW.prepare_scene_assignment({"run-a": first}, "run-b", "create-b").value
	var fork: Dictionary = DRAW.prepare_scene_assignment({"run-a": first}, "run-c", "create-c").value
	assert_false(DRAW.validate_ledger({"run-a": first, "run-b": second, "run-c": fork}).ok)
	assert_false(DRAW.validate_ledger({"run-b": second}).ok)
	for field: String in ["predecessor_run_id", "predecessor_assignment_sha256", "form", "creation_transaction_id"]:
		var bad := second.duplicate(true)
		match field:
			"predecessor_run_id": bad[field] = "run-b"
			"predecessor_assignment_sha256": bad[field] = "0".repeat(64)
			"form": bad[field] = first.form
			"creation_transaction_id": bad[field] = first.creation_transaction_id
		assert_false(DRAW.validate_ledger({"run-a": first, "run-b": bad}).ok, field)
	var cycle_a := second.duplicate(true)
	cycle_a.predecessor_run_id = "run-b"
	cycle_a.creation_transaction_id = "create-a"
	assert_false(DRAW.validate_ledger({"run-a": cycle_a, "run-b": second}).ok)
	var extra_root: Dictionary = DRAW.prepare_scene_assignment({}, "run-x", "create-x", 1).value
	assert_false(DRAW.validate_ledger({"run-a": first, "run-x": extra_root}).ok)
	var profile: Dictionary = SCHEMA.make_defaults()
	profile.pair_deck_draws = {"run-a": first, "run-b": second, "run-c": fork}
	assert_false(SCHEMA.validate(profile).ok)

func test_scene_material_only_appends_assignment_and_preserves_unrelated_profile_and_legacy_material() -> void:
	var f := _fixture()
	var files: Dictionary = f.ops.snapshot_persisted()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var prepared := _prepare(f, "run-a", "create-a", 0)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var material: Dictionary = prepared.value
	assert_eq(material.size(), 7)
	assert_false(material.has("captured_dark"))
	assert_true(PROFILE.validate_scene_new_run_material(material).ok)
	var unrelated: Dictionary = material.candidate.duplicate(true)
	unrelated.pair_deck_draws = before.pair_deck_draws.duplicate(true)
	assert_eq(unrelated, before)
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.ops.snapshot_persisted(), files)
	var old: Dictionary = f.profile.prepare_new_run_consumption(f.profile.get_profile_revision())
	assert_true(old.ok)
	assert_true(old.value.has("captured_dark"))
	assert_false(old.value.has("scene_assignment"))
	assert_false(old.value.candidate.preferences.dark_mode.next_run_enabled)
	assert_true(material.candidate.preferences.dark_mode.next_run_enabled)

func test_revision_bound_persistence_failure_retry_and_startup_proof_reuse_same_receipt() -> void:
	var f := _fixture()
	var prepared := _prepare(f, "run-a", "create-a", 1)
	assert_true(prepared.ok)
	if not prepared.ok: return
	var material: Dictionary = prepared.value
	assert_false(f.profile.persist_new_run_consumption(material).ok, "joint New Run custody required")
	var lease: Dictionary = f.gate.acquire(&"new_run")
	assert_true(lease.ok)
	f.storage.refuse = true
	var before: Dictionary = f.ops.snapshot_persisted()
	assert_false(f.profile.persist_new_run_consumption(material).ok)
	assert_eq(f.ops.snapshot_persisted(), before)
	f.storage.refuse = false
	assert_true(f.profile.persist_new_run_consumption(material).ok)
	assert_true(f.profile.persist_new_run_consumption(material).value.already_persisted)
	assert_true(f.profile.prove_new_run_consumption(material).ok)
	assert_eq(f.profile.get_profile_snapshot(), material.before, "durable write does not adopt or publish")
	var startup: Node = autofree(PROFILE.new())
	assert_true(startup.configure_new_run_storage(f.storage).ok)
	assert_true(startup.prove_new_run_consumption(material).ok)
	assert_true(f.gate.release(&"new_run", lease.value.token).ok)

func test_source_revision_and_candidate_tampering_refuse_without_new_assignment() -> void:
	var f := _fixture()
	var prepared := _prepare(f, "run-a", "create-a", 0)
	assert_true(prepared.ok)
	if not prepared.ok: return
	var material: Dictionary = prepared.value
	for field: String in ["captured_dark", "candidate", "outgoing_hash", "scene_assignment"]:
		var bad := material.duplicate(true)
		match field:
			"captured_dark": bad[field] = false
			"candidate": bad.candidate.preferences.dark_mode.next_run_enabled = false
			"outgoing_hash": bad[field] = "0".repeat(64)
			"scene_assignment": bad[field].receipt.creation_transaction_id = "different"
		assert_false(PROFILE.validate_scene_new_run_material(bad).ok, field)
	assert_false(f.profile.prepare_scene_new_run_consumption(f.profile.get_profile_revision() - 1, "run-b", "create-b", 0).ok)
	var changed: Dictionary = f.profile.get_profile_snapshot()
	changed.preferences.dark_mode.next_run_enabled = false
	assert_true(f.profile.commit_prepared_profile(changed).ok)
	var lease: Dictionary = f.gate.acquire(&"new_run")
	assert_true(lease.ok)
	assert_false(f.profile.persist_new_run_consumption(material).ok)
	assert_true(f.gate.release(&"new_run", lease.value.token).ok)
	assert_eq(f.profile.get_profile_snapshot().pair_deck_draws, {})

func test_standalone_generic_commit_and_silent_adoption_cannot_persist_scene_assignment() -> void:
	var f := _fixture()
	var prepared := _prepare(f, "run-a", "create-a", 0)
	assert_true(prepared.ok)
	if not prepared.ok: return
	var material: Dictionary = prepared.value
	var receipt: Dictionary = material.scene_assignment.receipt
	assert_false(f.profile.prepare_pair_deck_draw("run-a", receipt).ok)
	assert_false(f.profile.commit_pair_deck_draw({"run_id": "run-a", "receipt": receipt,
		"profile_revision": f.profile.get_profile_revision()}).ok)
	assert_false(f.profile.commit_prepared_profile(material.candidate).ok)
	var files: Dictionary = f.ops.snapshot_persisted()
	assert_true(f.profile.apply_restore_silent({"profile": material.candidate}).ok, "A owns eventual verified joint adoption")
	assert_false(f.profile.commit_prepared_profile(f.profile.get_profile_snapshot()).ok, "silent adoption cannot grant durable append")
	assert_eq(f.ops.snapshot_persisted(), files)

func test_legacy_receipts_remain_exact_and_unresolved_boundary_refuses_new_policy() -> void:
	var f := _fixture()
	var legacy: Dictionary = DRAW.build_legacy("love_dark").value
	var prepared: Dictionary = f.profile.prepare_pair_deck_draw("legacy-run", legacy)
	assert_true(prepared.ok)
	var lease: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	assert_true(f.profile.commit_pair_deck_draw(prepared.value).ok)
	assert_true(f.gate.release(&"causal_transaction", lease.value.token).ok)
	assert_eq(f.profile.get_pair_deck_draw("legacy-run").value, legacy)
	var boundary := _prepare(f, "run-a", "create-a", 0)
	assert_false(boundary.ok)
	assert_eq(boundary.code, &"scene_assignment_legacy_boundary_required")
	assert_eq(f.profile.get_profile_snapshot().pair_deck_draws, {"legacy-run": legacy})

func test_joint_adoption_alternates_next_run_and_full_reset_remains_explicit() -> void:
	var f := _fixture()
	var initial := _prepare(f, "run-z", "create-z", 1)
	assert_true(initial.ok)
	if not initial.ok: return
	_persist_and_adopt(f, initial.value)
	var next := _prepare(f, "run-a", "create-a")
	assert_true(next.ok, str(next))
	if not next.ok: return
	assert_eq(next.value.scene_assignment.receipt.form, "sweet")
	_persist_and_adopt(f, next.value)
	assert_true(f.profile.commit_prepared_profile(f.profile.get_profile_snapshot()).ok, "already durable assignments remain allowed")
	assert_true(f.profile.reset_entire_profile().ok)
	assert_eq(f.profile.get_profile_snapshot().pair_deck_draws, {})
