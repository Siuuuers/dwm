extends "res://addons/gut/test.gd"
## Preparation only: real GameState helper, receipt contract, causal gate and issuer;
## real identity/root over existing FakeFileOps. Reading, registration selection and
## Run input capture are injected. No native proof, Save9, physical disk, or Load.
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const IDENTITY := preload("res://tests/support/SceneTransitionIdentityFixture.gd")
const CHALLENGE := preload("res://tests/support/SceneChallengeFixture.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

class PreparationState:
	extends "res://autoload/GameState.gd"
	var context := {}
	var bundle := {}
	var input := {}
	var on_context: Callable
	func _ready() -> void: pass
	func _scene_runtime_event_context() -> Dictionary:
		if on_context.is_valid(): on_context.call()
		return {"ok": true, "value": context.duplicate(true)}
	func scene_event_registration(candidate: Dictionary) -> Dictionary:
		var inspected := _SCENE_EVENT.inspect_scene(candidate, bundle)
		return {"ok": true, "value": bundle.duplicate(true)} if inspected.ok else inspected
	func capture_run_snapshot_input() -> Dictionary:
		var result := input.duplicate(true)
		result["command_receipts"] = _command_receipts.duplicate(true)
		return result

class ReadingProof:
	extends RefCounted
	var on_validate: Callable
	var refuse := false
	func validate_scene_event_anchor(_anchor: Dictionary, _checkpoint: Dictionary) -> Dictionary:
		if on_validate.is_valid(): on_validate.call()
		return {"ok": not refuse, "code": &"TEST.anchor_refused"}

class CheckpointTrap:
	extends RefCounted
	var calls := 0
	func commit_scene_event(_input: Dictionary, _checkpoint: Dictionary) -> Dictionary:
		calls += 1
		return {"ok": false, "code": &"TEST.unexpected_checkpoint_call"}

var state: PreparationState
var reading: ReadingProof
var checkpoint: CheckpointTrap
var identity_fixture: RefCounted
var gate: RefCounted
var issuer: RefCounted
var event: Dictionary
var lease := ""
var digest := ""

func before_each() -> void:
	identity_fixture = IDENTITY.new()
	var configured: Dictionary = identity_fixture.setup()
	assert_true(configured.ok, str(configured))
	if not configured.ok: return
	issuer = identity_fixture.issuer
	gate = GATE.new()
	var acquired: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(acquired.ok, str(acquired))
	if not acquired.ok: return
	lease = acquired.value.token
	state = PreparationState.new()
	add_child(state)
	state._mutation_gate = gate
	state._identity_issuer = issuer
	state.bundle = CHALLENGE.bundle()
	reading = ReadingProof.new()
	checkpoint = CheckpointTrap.new()
	state._scene_event_bridge = reading
	state._narrative_checkpoint_port = checkpoint
	var identity: Dictionary = identity_fixture.identity(identity_fixture.lifecycle)
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return
	var admitted: Dictionary = CONTRACT.make_scene_admission(identity, issued.value.issuer_receipt,
		"TEST.target", {"checkpoint_id": "TEST.source", "checkpoint_sequence": 1,
		"snapshot_sha256": "a".repeat(64)}, null, null, state.bundle, issuer)
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	var admission: Dictionary = admitted.value
	state._command_receipts = {admission.transaction_id: admission.duplicate(true)}
	issued = issuer.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return
	event = {"schema_version": 2, "source": {"run_id": identity.run_id,
		"branch_id": identity.branch_id, "causal_day_instance": identity.causal_day_instance,
		"scene_occurrence": admission.transaction_id, "entry_id": "TEST.scene", "content_version": 1},
		"event_id": "TEST.playable", "kind": "challenge.playable", "payload": {"challenge_id": "TEST.challenge"},
		"ordinal": 0, "predecessor": "", "command_id": issued.value.token,
		"issuer_receipt": issued.value.issuer_receipt.duplicate(true), "playback_token": "TEST.current"}
	var inspected: Dictionary = CONTRACT.inspect_scene(event, state.bundle)
	assert_true(inspected.ok, str(inspected))
	if not inspected.ok: return
	digest = inspected.value.digest
	var fingerprint: String = inspected.value.registration_fingerprint
	state.context = {"family": "scene", "mode": "canonical", "suspended": false, "computer_held": false,
		"source": event.source.duplicate(true), "playback_token": event.playback_token,
		"next_ordinal": 0, "predecessor": "", "notification": {},
		"anchor": {"session_id": admission.transaction_id, "entry_id": "TEST.scene", "content_version": 1,
			"catalogue_fingerprint": fingerprint, "publication_id": "TEST.publication", "line_id": "TEST.line"},
		"checkpoint": {"stage": "scene", "reading_session": {"schema_version": 5, "boundary": "line",
			"ledger": {"captions": [{"TEST": "unchanged caption"}]}}}}
	state.input = {"lifecycle": identity.duplicate(true), "gameplay": {"route_context": {}, "pressure": 0},
		"contacts": {}, "desktop": {}, "scene": {"registration_sha256": fingerprint,
			"active_occurrence_id": admission.transaction_id, "active_admission_receipt_id": admission.transaction_id},
		"applied_effect_transaction_ids": [], "applied_variable_transaction_ids": []}

func after_each() -> void:
	if checkpoint != null: assert_eq(checkpoint.calls, 0, "preparation and guarded dispatch never write")
	if is_instance_valid(state): state.free()
	state = null
	reading = null
	checkpoint = null
	identity_fixture = null
	issuer = null
	gate = null

func _prepare(candidate: Dictionary = {}) -> Dictionary:
	return state._prepare_scene_playable_event(event if candidate.is_empty() else candidate, digest, lease)

func test_prepares_exact_receipt_and_only_detached_run_input() -> void:
	var before: Dictionary = state.capture_run_snapshot_input()
	var root_before: Dictionary = identity_fixture.root.capture()
	var context_before := state.context.duplicate(true)
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_false(prepared["duplicate"])
	var material: Dictionary = prepared.value
	assert_eq(material.result, {"kind": "challenge_playable", "challenge_occurrence":
		CONTRACT._sha([event.source.scene_occurrence, "TEST.challenge"])})
	assert_eq(material.receipt.request_fingerprint, digest)
	assert_false(material.receipt.scene_event.semantic.has("playback_token"))
	assert_eq(material.source_context, context_before)
	assert_eq(material.source_input, before)
	var restored_input: Dictionary = material.snapshot_input.duplicate(true)
	restored_input.command_receipts.erase(event.command_id)
	assert_eq(restored_input, before, "the proposed receipt is the only Run input change")
	assert_eq(material.snapshot_input.command_receipts[event.command_id], material.receipt)
	assert_true(CONTRACT.validate_scene_receipts(material.snapshot_input.command_receipts, state.bundle, issuer).ok)
	assert_eq(state.capture_run_snapshot_input(), before)
	assert_eq(state.context, context_before)
	assert_eq(identity_fixture.root.capture(), root_before, "no root, allocation or attempt is issued")

func test_returned_material_is_detached_and_preparation_reuses_issued_command() -> void:
	var first := _prepare()
	assert_true(first.ok, str(first))
	if not first.ok: return
	var expected := first.duplicate(true)
	first.value.snapshot_input.gameplay.pressure = 9
	first.value.source_input.gameplay.pressure = 8
	first.value.source_context.anchor.line_id = "TEST.changed"
	first.value.receipt.scene_event.result.kind = "TEST.changed"
	first.value.result.kind = "TEST.other"
	assert_eq(_prepare(), expected)
	assert_eq(state._command_receipts.size(), 1, "preparation never installs its new receipt")

func test_wrong_family_version_kind_and_non_line_source_refuse() -> void:
	for version: Variant in [1, 2.0, "2"]:
		var bad := event.duplicate(true)
		bad.schema_version = version
		assert_false(_prepare(bad).ok)
	var wrong_kind := event.duplicate(true)
	wrong_kind.kind = "challenge.end"
	assert_false(_prepare(wrong_kind).ok)
	state.context.family = "legacy_day"
	assert_false(_prepare().ok)
	state.context.family = "scene"
	state.context.checkpoint.reading_session.boundary = "control"
	assert_eq(_prepare().get("code"), &"scene_playable_source_required")

func test_stale_token_foreign_issuer_and_changed_digest_refuse() -> void:
	var bad := event.duplicate(true)
	bad.playback_token = "TEST.stale"
	assert_eq(_prepare(bad).get("code"), &"event_stale_token")
	assert_eq(state._prepare_scene_playable_event(event, "0".repeat(64), lease).get("code"), &"event_digest_mismatch")
	var foreign := ISSUER.new()
	assert_true(foreign.configure(ROOT.new("cd".repeat(32), 1)).ok)
	var issued: Dictionary = foreign.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return
	bad = event.duplicate(true)
	bad.command_id = issued.value.token
	bad.issuer_receipt = issued.value.issuer_receipt
	var foreign_digest: String = CONTRACT.inspect_scene(bad, state.bundle).value.digest
	assert_false(state._prepare_scene_playable_event(bad, foreign_digest, lease).ok)

func test_marker_payload_source_and_reading_anchor_mismatch_refuse() -> void:
	for field: String in ["event_id", "payload", "source"]:
		var bad := event.duplicate(true)
		match field:
			"event_id": bad.event_id = "TEST.end"
			"payload": bad.payload.challenge_id = "TEST.unknown"
			"source": bad.source.scene_occurrence = "TEST.foreign"
		assert_false(_prepare(bad).ok, field)
	state.context.anchor.line_id = "TEST.other_line"
	assert_eq(_prepare().get("code"), &"event_anchor_invalid")
	state.context.anchor.line_id = "TEST.line"
	reading.refuse = true
	assert_eq(_prepare().get("code"), &"TEST.anchor_refused")

func test_frontier_and_registration_mismatch_refuse() -> void:
	state.context.next_ordinal = 1
	assert_eq(_prepare().get("code"), &"event_frontier_mismatch")
	state.context.next_ordinal = 0
	state.input.scene.registration_sha256 = "0".repeat(64)
	assert_eq(_prepare().get("code"), &"event_registration_mismatch")
	state.input.scene.registration_sha256 = state.context.anchor.catalogue_fingerprint
	state.context.anchor.catalogue_fingerprint = "0".repeat(64)
	assert_eq(_prepare().get("code"), &"event_registration_mismatch")

func test_complete_receipt_map_requires_admission_and_rejects_duplicate_marker() -> void:
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var original := state._command_receipts.duplicate(true)
	state._command_receipts.clear()
	assert_false(_prepare().ok, "no playable receipt without its admitted occurrence")
	state._command_receipts = original
	state._command_receipts[event.command_id] = prepared.value.receipt.duplicate(true)
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return
	var replay := event.duplicate(true)
	replay.command_id = issued.value.token
	replay.issuer_receipt = issued.value.issuer_receipt
	replay.ordinal = 1
	replay.predecessor = event.event_id
	state.context.next_ordinal = 1
	state.context.predecessor = event.event_id
	var replay_digest: String = CONTRACT.inspect_scene(replay, state.bundle).value.digest
	assert_false(state._prepare_scene_playable_event(replay, replay_digest, lease).ok)

func test_duplicate_requires_current_authentication_and_produces_no_save_candidate() -> void:
	var prepared := _prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	# Unit-only retained-receipt injection is not a claim that a checkpoint committed.
	state._command_receipts[event.command_id] = prepared.value.receipt.duplicate(true)
	state.context.next_ordinal = 1
	state.context.predecessor = event.event_id
	state.context.checkpoint.reading_session.boundary = "control"
	var repeated := _prepare()
	assert_true(repeated.ok, str(repeated))
	if not repeated.ok: return
	assert_true(repeated["duplicate"])
	assert_eq(repeated.value, {"result": prepared.value.result})
	var bad := event.duplicate(true)
	bad.playback_token = "TEST.old_process"
	assert_eq(_prepare(bad).get("code"), &"event_stale_token")
	state.on_context = func() -> void: state.input.gameplay.pressure += 1
	assert_eq(_prepare().get("code"), &"event_adoption_source_changed", "duplicates recheck callback stability")

func test_owner_change_during_anchor_callback_refuses_without_adoption() -> void:
	var receipts := state._command_receipts.duplicate(true)
	reading.on_validate = func() -> void: state.input.gameplay.pressure = 1
	assert_eq(_prepare().get("code"), &"event_adoption_source_changed")
	assert_eq(state._command_receipts, receipts)

func test_stale_or_callback_released_lease_refuses() -> void:
	assert_eq(state._prepare_scene_playable_event(event, digest, "TEST.stale").get("code"), &"event_lease_lost")
	reading.on_validate = func() -> void: gate.release(&"causal_transaction", lease)
	assert_eq(_prepare().get("code"), &"event_lease_lost")

func test_ordinary_scene_dispatch_still_refuses_playable_without_control_handoff() -> void:
	var before: Dictionary = state.capture_run_snapshot_input()
	var result: Dictionary = state._accept_scene_runtime_event(event, digest, lease)
	assert_eq(result.get("code"), &"event_dependency_invalid")
	assert_eq(state.capture_run_snapshot_input(), before)
