extends RefCounted
## TEST ONLY: real physical/reducer/Profile owners; injected admission, source
## checkpoint and closure seams. This is not a Save8 or native story integration.
const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const CANONICAL := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

class State extends RefCounted:
	var inventory := {}
	var penalty_points_today := 0
	var pressure := 0
	var route_context := {}
	var lifecycle := {"run_id": "TEST.scene.run", "branch_id": "TEST.scene.branch"}
	var effects := 0
	func get_stat(_name: String) -> int: return pressure
	func capture_run_snapshot_input() -> Dictionary: return {"lifecycle": lifecycle.duplicate(true), "gameplay": {"route_context": route_context.duplicate(true)}}
	func capture_dating_challenge_state() -> Dictionary: return {"ok": true, "value": route_context.get("active_dating_challenge", {}).duplicate(true)}
	func store_dating_challenge_state(record: Dictionary, _emit: bool = true) -> Dictionary:
		route_context.active_dating_challenge = record.duplicate(true)
		return {"ok": true, "value": {}}
	func capture_restore_state() -> Dictionary: return {"ok": true, "value": {"backup": {"route_context": route_context.duplicate(true), "lifecycle": lifecycle.duplicate(true)}}}
	func rollback_restore_silent(backup: Dictionary) -> Dictionary:
		route_context = backup.route_context.duplicate(true)
		lifecycle = backup.lifecycle.duplicate(true)
		return {"ok": true, "value": {}}
	func apply_dating_challenge_result(_entry: Dictionary, _fact: Dictionary) -> Dictionary:
		effects += 1
		return {"ok": false, "code": &"TEST.forbidden_dating_effect"}
	func prepare_dating_challenge_effect(_entry: Dictionary, _fact: Dictionary) -> Dictionary:
		effects += 1
		return {"ok": false, "code": &"TEST.forbidden_dating_effect"}
	func apply_dating_challenge_effect_receipt(_entry: Dictionary, _fact: Dictionary, _emit: bool = true) -> Dictionary:
		effects += 1
		return {"ok": false, "code": &"TEST.forbidden_dating_effect"}

class ProfileStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var refuse := false
	func _init(root: String, ops: RefCounted = null) -> void:
		super(root, ops)
	func write_atomic(path: String, text: String, validator: Callable, backup: bool = true) -> Dictionary:
		if refuse: return {"ok": false, "code": &"TEST.profile_refused"}
		return super.write_atomic(path, text, validator, backup)

class Authority extends RefCounted:
	var state: RefCounted
	var profile: Node
	var command: Dictionary
	var bundle: Dictionary
	var closures := {}
	var checkpoints: Array = []
	var reject_checkpoint := false
	var reject_closure := false
	var held_end := true
	var unconfirmed := false
	var checkpoint_failure: Dictionary = {}
	var malformed_closure := false
	func validate_scene_challenge_command(candidate: Dictionary, registration: Dictionary) -> Dictionary:
		var detached := candidate.duplicate(true)
		detached.erase("physical_token")
		return {"ok": detached == command and registration == bundle, "code": &"TEST.admission", "value": {}}
	func validate_scene_challenge_end(_candidate: Dictionary) -> Dictionary:
		return {"ok": held_end, "code": &"TEST.end_not_held", "value": {}}
	func capture_scene_challenge_closure(_context: Dictionary) -> Dictionary:
		return {"ok": true, "value": closures.get(state.lifecycle.branch_id, {}).duplicate(true)}
	func commit_scene_challenge_checkpoint(record: Dictionary, reference: Dictionary) -> Dictionary:
		var retained: Dictionary = profile.get_dating_attempt(state.lifecycle.run_id, LEDGER.semantic_slot(record.context), reference.attempt_id, reference.branch_id)
		if not retained.ok or retained.value.record != record: return {"ok": false, "code": &"TEST.profile_not_before_run"}
		if not checkpoint_failure.is_empty(): return checkpoint_failure.duplicate(true)
		if reject_checkpoint: return {"ok": false, "code": &"TEST.run_refused", "committed": false}
		checkpoints.append(record.duplicate(true))
		if unconfirmed: return {"ok": true, "value": {}}
		return {"ok": true, "value": {"checkpoint_reference": {"checkpoint_id": "TEST.source.%d" % checkpoints.size(),
			"checkpoint_sequence": checkpoints.size(), "snapshot_sha256": CANONICAL.canonical_sha256({"TEST.injected_snapshot": record}).value.sha256}}}
	func commit_scene_challenge_closure(candidate: Dictionary, result: Dictionary) -> Dictionary:
		if not validate_scene_challenge_command(candidate, bundle).ok or not held_end or reject_closure:
			return {"ok": false, "code": &"TEST.closure_refused", "committed": false}
		if closures.has(state.lifecycle.branch_id): return {"ok": false, "code": &"TEST.closed"}
		if result.attempt_proof != null:
			var proof: Dictionary = result.attempt_proof
			var attempt: Dictionary = profile.get_dating_attempt(proof.run_id, proof.slot_id, proof.attempt_id, proof.branch_id)
			if not attempt.ok or not LEDGER.validate_attempt_proof(attempt.value, proof).ok: return {"ok": false, "code": &"TEST.proof_invalid"}
		closures[state.lifecycle.branch_id] = result.duplicate(true)
		if malformed_closure: return {"ok": true, "value": {}}
		return {"ok": true, "value": result.duplicate(true)}

class Generation extends "res://tests/support/FakeMinesweeperGenerationPort.gd":
	func begin_search(spec: Dictionary) -> Dictionary:
		return preload("res://scripts/application/minesweeper/MinesweeperBoardGenerationPort.gd").new().begin_search(spec)

var state := State.new()
var profile: Node
var storage: RefCounted
var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
var issuer := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
var generation := Generation.new()
var owner: RefCounted
var authority := Authority.new()
var command := {}
var token := ""

func setup(root: String = "TEST.scene.challenge", disk: bool = false) -> Dictionary:
	storage = ProfileStorage.new(root, null if disk else preload("res://tests/support/FakeFileOps.gd").new())
	profile = PROFILE.new()
	var initialized: Dictionary = profile.initialize(storage)
	if not initialized.ok: return initialized
	var gated: Dictionary = profile.configure_mutation_gate(gate)
	if not gated.ok: return gated
	var issued: Dictionary = issuer.configure(preload("res://tests/support/FakeDesktopIssuerRootStore.gd").new("93".repeat(32), 1))
	if not issued.ok: return issued
	var mines: Array = []
	for index in 36: mines.append(index)
	generation.arm_materialize({"schema_version": 1, "width": 18, "height": 18, "mine_indices": mines, "mine_count": 36})
	var registration := bundle()
	command = {"completion_transaction_id": "TEST.scene.playable", "command_sha256": "TEST.scene.command".sha256_text(), "context": {
		"kind": "scene_challenge", "scene_occurrence": "TEST.scene.occurrence", "challenge_id": "TEST.challenge",
		"playable_command_id": "TEST.scene.playable", "registration_sha256": CANONICAL.canonical_sha256(registration).value.sha256}}
	authority.state = state; authority.profile = profile; authority.command = command.duplicate(true); authority.bundle = registration
	return recreate_owner()

func recreate_owner() -> Dictionary:
	owner = OWNER.new()
	var configured: Dictionary = owner.configure(issuer, state, profile, generation)
	if not configured.ok: return configured
	configured = owner.configure_attempt_history(gate)
	if not configured.ok: return configured
	configured = owner.configure_scene_challenges(authority.bundle, authority)
	if not configured.ok: return configured
	token = owner._token(command.completion_transaction_id, command.command_sha256)
	return {"ok": true}

func begin() -> Dictionary: return owner.begin_physical(command)
func action(kind: String, index: int = -1) -> Dictionary:
	var view: Dictionary = owner.pull_physical(token)
	if not view.ok: return view
	return owner.dispatch_physical(token, kind, index, int(view.value.get("revision", 0)))
func record() -> Dictionary: return state.capture_dating_challenge_state().value
func attempt(branch: String = "") -> Dictionary:
	return profile.get_dating_attempt(state.lifecycle.run_id, LEDGER.semantic_slot(command.context), "", branch)
func dispose() -> void:
	if is_instance_valid(profile): profile.free()

static func bundle() -> Dictionary:
	return {"kind": "scene_reading_registration", "schema_version": 1,
		"entry_manifest": {"TEST": "manifest"}, "context_registry": {"TEST": "contexts"},
		"ids_registry": {"TEST": "ids"}, "caption_registry": {"TEST": "captions"},
		"scene_programme": {"kind": "scene_programme", "schema_version": 1, "entries": [
			{"entry_id": "TEST.scene", "content_version": 1, "content_sha256": "a".repeat(64), "program_sha256": "b".repeat(64), "markers": [
				{"marker_id": "TEST.playable", "label": "TEST.playable.label", "after_line_id": "TEST.line", "kind": "challenge.playable", "payload": {"challenge_id": "TEST.challenge"}},
				{"marker_id": "TEST.end", "label": "TEST.end.label", "after_line_id": "TEST.line", "kind": "challenge.end", "payload": {"challenge_id": "TEST.challenge"}}]}]},
		"targets": [{"target_id": "TEST.target", "target": {"kind": "scene", "entry_id": "TEST.scene", "label": "TEST.scene", "content_version": 1, "program_sha256": "b".repeat(64)}}],
		"board_profiles": [{"board_profile_id": "TEST.profile", "board_kind": "solo_challenge", "difficulty_id": "canonical_solo", "width": 18, "height": 18,
			"base_mine_count": 36, "generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1", "capability_policy_id": "owned_inventory_v1"}],
		"challenges": [{"challenge_id": "TEST.challenge", "entry_id": "TEST.scene", "playable_marker_id": "TEST.playable", "end_marker_id": "TEST.end", "board_profile_id": "TEST.profile",
			"targets": {"never_started": "TEST.target", "unfinished": "TEST.target", "lost": "TEST.target", "won": "TEST.target"}}], "contacts": []}
