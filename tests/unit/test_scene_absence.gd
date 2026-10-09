extends "res://addons/gut/test.gd"
## Injected selected-document/session authority. Real physical, Profile, ledger,
## issuer and causal lease owners; this does not prove Save9 or source-disk recovery.
const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const HASH := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const ENVELOPE := preload("res://scripts/application/run/DatingChallengeEnvelope.gd")
const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")

class AbsenceState extends FIXTURE.State:
	var delegate: RefCounted
	var gate: RefCounted
	var profile: Node
	var physical: RefCounted
	var selected := false
	var session := 1
	var admission := {}
	var admitted_session := 0
	var validations := 0
	var fail_at := 0
	var attack := ""
	var attack_at := 0
	var last_lease := ""
	func validate_scene_challenge_command(command: Dictionary, bundle: Dictionary) -> Dictionary:
		return delegate.validate_scene_challenge_command(command, bundle)
	func validate_scene_challenge_end(command: Dictionary) -> Dictionary:
		return delegate.validate_scene_challenge_end(command)
	func capture_scene_challenge_closure(context: Dictionary) -> Dictionary:
		return delegate.capture_scene_challenge_closure(context)
	func commit_scene_challenge_checkpoint(record: Dictionary, reference: Dictionary) -> Dictionary:
		return delegate.commit_scene_challenge_checkpoint(record, reference)
	func commit_scene_challenge_closure(command: Dictionary, result: Dictionary) -> Dictionary:
		return delegate.commit_scene_challenge_closure(command, result)
	func prepare_selected_scene_absence(command: Dictionary, bundle: Dictionary) -> Dictionary:
		if not selected or not validate_scene_challenge_command(command, bundle).ok or not route_context.is_empty():
			return {"ok": false}
		var source := {"run_id": lifecycle.run_id, "branch_id": "TEST.scene.branch", "desktop_timeline_generation": 0,
			"causal_day_instance": "TEST.causal.source", "causal_day_instance_issuer_receipt": {"TEST.injected": true}}
		var destination := source.duplicate(true)
		destination.branch_id = lifecycle.branch_id
		destination.desktop_timeline_generation = 2
		admission = {"restore_transaction_id": "TEST.selected.restore", "source_locator": {"slot_id": "slot.1",
			"bundle_id": "a".repeat(64), "checkpoint_id": "TEST.prestart", "document_sha256": "b".repeat(64)},
			"source_identity": source, "destination_identity": destination, "allocation_receipt_id": "TEST.allocation",
			"remap_receipt_id": "TEST.remap", "transaction_remap_sha256": "c".repeat(64), "challenge_key": {
				"run_id": lifecycle.run_id, "scene_occurrence": command.context.scene_occurrence,
				"challenge_id": command.context.challenge_id, "playable_command_id": command.context.playable_command_id,
				"registration_sha256": command.context.registration_sha256}}
		admitted_session = session
		return {"ok": true, "value": admission}
	func validate_selected_scene_absence(candidate: Dictionary, command: Dictionary, bundle: Dictionary, lease: String) -> Dictionary:
		validations += 1
		last_lease = lease
		var valid: bool = selected and is_same(candidate, admission) and admitted_session == session \
			and candidate.destination_identity.branch_id == lifecycle.branch_id \
			and validate_scene_challenge_command(command, bundle).ok \
			and gate.is_lease_active(&"causal_transaction", lease)
		if validations == attack_at:
			match attack:
				"command": command.context.challenge_id = "TEST.forged"
				"admission": candidate.challenge_key.challenge_id = "TEST.forged"
				"bundle": bundle.contacts.append({"TEST.forged": true})
				"reentry": profile.commit_dating_attempt({})
				"physical_reentry": physical.begin_physical(command)
				"lease": gate.release(&"causal_transaction", lease)
				"material": profile._scene_absence_material.request.selection.generation += 1
				"session": session += 1; valid = false
				"identity": lifecycle.branch_id = "TEST.switched"
		return {"ok": valid and validations != fail_at}
	func custody() -> bool: return gate.is_lease_active(&"causal_transaction", last_lease)
	func bad_arity(_value: Dictionary) -> Dictionary: return {"ok": true}

var f: RefCounted
var state: AbsenceState
func before_each() -> void:
	f = FIXTURE.new()
	state = AbsenceState.new()
	f.state = state
	assert_true(f.setup("TEST.absence").ok)
	state.delegate = f.authority
	state.gate = f.gate
	state.profile = f.profile
	assert_true(f.profile.configure_scene_absence_validator(state.validate_selected_scene_absence).ok)
	_recreate()
func after_each() -> void: f.dispose()
func _recreate() -> void:
	f.owner = OWNER.new()
	assert_true(f.owner.configure(f.issuer, state, f.profile, f.generation).ok)
	assert_true(f.owner.configure_attempt_history(f.gate).ok)
	assert_true(f.owner.configure_scene_challenges(f.authority.bundle, state).ok)
	state.physical = f.owner
func _first_attempt() -> Dictionary:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	return f.attempt().value.duplicate(true)
func _select_absence(branch: String = "TEST.selected.branch") -> void:
	state.route_context = {}
	state.lifecycle.branch_id = branch
	state.selected = true
	state.session += 1
	_recreate()

func test_selected_absence_opens_and_closes_without_copying_future_progress() -> void:
	var original := _first_attempt()
	assert_true(f.action("reveal", 323).ok)
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok)
	var original_proof: Dictionary = closed.value.attempt_proof
	_select_absence()
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.state, "never_started")
	assert_eq(f.record(), {})
	assert_false(f.profile.get_dating_attempt(state.lifecycle.run_id, original.slot_id, original.attempt_id, state.lifecycle.branch_id).ok)
	var never: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(never.ok, str(never))
	if never.ok: assert_null(never.value.attempt_proof)
	assert_true(LEDGER.resolve_attempt_proof(f.profile.get_profile_snapshot().dating_attempts, original_proof).ok)

func test_absent_start_reuses_only_original_entry_and_new_branch_revision_one() -> void:
	var original := _first_attempt()
	assert_true(f.action("reveal", 323).ok)
	var future: Dictionary = f.attempt().value.duplicate(true)
	_select_absence()
	state.inventory = {"debug_key": 1}
	state.pressure = 12
	assert_true(f.begin().ok)
	var started: Dictionary = f.action("start")
	assert_true(started.ok, str(started))
	if not started.ok: return
	var actual: Dictionary = f.attempt(state.lifecycle.branch_id).value
	assert_eq(actual.entry_receipt, original.entry_receipt)
	assert_eq(actual.record.spec, original.record.spec)
	assert_eq(actual.record.phase, "ready")
	assert_eq(actual.record.envelope, ENVELOPE.make())
	assert_null(actual.record.board)
	assert_eq(actual.revision, 1)
	assert_eq(actual.generation, original.generation)
	assert_eq(f.attempt("TEST.scene.branch").value, future)
	assert_false(f.action("start").ok)
	assert_eq(state.validations, 3, "before preparation, Profile preparation, and immediate precommit")

func test_absent_profile_failure_preserves_absence_and_retry_frozen_entry() -> void:
	var original := _first_attempt()
	_select_absence()
	assert_true(f.begin().ok)
	f.storage.refuse = true
	assert_false(f.action("start").ok)
	assert_eq(f.record(), {})
	assert_false(f.profile.get_dating_attempt(state.lifecycle.run_id, original.slot_id, original.attempt_id, state.lifecycle.branch_id).ok)
	f.storage.refuse = false
	assert_true(f.action("start").ok)
	assert_eq(f.record().spec, original.record.spec)

func test_profile_ahead_destination_recovers_after_owner_and_profile_restart() -> void:
	var original := _first_attempt()
	_select_absence()
	assert_true(f.begin().ok)
	f.authority.reject_checkpoint = true
	assert_false(f.action("start").ok)
	var retained: Dictionary = f.attempt(state.lifecycle.branch_id).value
	assert_eq(retained.revision, 1)
	state.route_context = {}
	f.profile.free()
	f.profile = PROFILE.new()
	assert_true(f.profile.initialize(f.storage).ok)
	assert_true(f.profile.configure_mutation_gate(f.gate).ok)
	assert_true(f.profile.configure_scene_absence_validator(state.validate_selected_scene_absence).ok)
	state.profile = f.profile
	f.authority.profile = f.profile
	state.selected = false # Exact committed destination wins, no new absence grant.
	_recreate()
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.phase, "checkpoint_retry")
	f.authority.reject_checkpoint = false
	assert_true(f.action("retry").ok)
	assert_eq(f.attempt(state.lifecycle.branch_id).value, retained)
	assert_eq(f.record().spec, original.record.spec)

func test_callback_reentry_mutation_lease_and_stale_session_refuse_before_profile_write() -> void:
	var original := _first_attempt()
	for attack: String in ["command", "admission", "bundle", "reentry", "physical_reentry", "lease", "material", "session", "identity"]:
		_select_absence("TEST.branch." + attack)
		assert_true(f.begin().ok)
		state.validations = 0
		state.attack = attack
		state.attack_at = 3 if attack != "physical_reentry" else 1
		var destination: String = state.lifecycle.branch_id
		var started: Dictionary = f.action("start")
		assert_false(started.ok, attack)
		assert_false(f.profile.get_dating_attempt(state.lifecycle.run_id, original.slot_id, original.attempt_id, destination).ok, attack)
		assert_eq(f.record(), {}, attack)
		state.attack = ""
		# Mutated owner inputs are discarded with the failed owner; authority keeps
		# an independent canonical registration/command for the next seam case.
		f.command = f.authority.command.duplicate(true)

func test_profile_private_material_copy_and_configuration_conflicts_refuse() -> void:
	assert_false(f.profile.configure_scene_absence_validator(state.bad_arity).ok)
	var other := AbsenceState.new()
	assert_false(f.profile.configure_scene_absence_validator(other.validate_selected_scene_absence).ok)
	assert_true(f.profile.configure_scene_absence_validator(state.validate_selected_scene_absence).ok)
	var original := _first_attempt()
	_select_absence()
	assert_true(f.begin().ok)
	var acquired: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_true(acquired.ok)
	var admission: Dictionary = state.prepare_selected_scene_absence(f.command, f.authority.bundle).value
	var selection := {"mode": "start_from_absence", "admission": admission, "attempt_id": original.attempt_id,
		"generation": original.generation, "entry_sha256": HASH.canonical_sha256(original.entry_receipt).value.sha256}
	state.last_lease = acquired.value.token
	var prepared: Dictionary = f.profile.prepare_dating_attempt(state.lifecycle.run_id, original.slot_id, state.lifecycle.branch_id,
		original.record, 0, -1, {}, selection, f.command, f.authority.bundle, acquired.value.token, state.custody)
	assert_true(prepared.ok, str(prepared))
	if prepared.ok:
		assert_false(f.profile.commit_dating_attempt(prepared.value.duplicate(true)).ok)
		assert_true(f.profile.commit_dating_attempt(prepared.value).ok)
		assert_false(f.profile.commit_dating_attempt(prepared.value).ok)
	assert_true(f.gate.release(&"causal_transaction", acquired.value.token).ok)

func test_selected_absence_must_be_authorized_and_cannot_overload_saved_prefix() -> void:
	var original := _first_attempt()
	_select_absence()
	state.selected = false
	assert_false(f.begin().ok)
	assert_false(f.profile.prepare_dating_continuation(state.lifecycle.run_id, original.slot_id,
		original.attempt_id, original.branch_id, state.lifecycle.branch_id, {}).ok)
	state.selected = true
	assert_true(f.begin().ok)
	state.fail_at = 3
	assert_false(f.action("start").ok, "precommit refusal cannot be bypassed by prior successful checks")
	assert_eq(f.record(), {})

func test_physical_reentry_at_each_profile_callback_refuses_before_persistence() -> void:
	var original := _first_attempt()
	for stage: int in [2, 3]:
		_select_absence("TEST.reentry.branch.%d" % stage)
		assert_true(f.begin().ok)
		state.validations = 0
		state.attack = "physical_reentry"
		state.attack_at = stage
		assert_false(f.action("start").ok, "physical reentry at validation %d" % stage)
		assert_false(f.profile.get_dating_attempt(state.lifecycle.run_id, original.slot_id, original.attempt_id, state.lifecycle.branch_id).ok)
		assert_eq(f.record(), {})
		state.attack = ""

func test_original_debug_entry_restarts_only_its_initial_search_frontier() -> void:
	state.inventory = {"debug_key": 1}
	var original := _first_attempt()
	assert_eq(original.record.phase, "preparing")
	# One real generator slice supplies retained future progress without a full
	# search loop; new Start must reproduce the original initial frontier.
	assert_true(f.action("prepare").ok)
	var future: Dictionary = f.attempt().value.duplicate(true)
	_select_absence()
	state.inventory = {}
	state.pressure = 12
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_eq(f.record(), original.record)
	assert_eq(f.attempt("TEST.scene.branch").value, future)
	assert_eq(f.attempt(state.lifecycle.branch_id).value.revision, 1)

func test_later_destination_progress_wins_over_selected_absence_after_missing_run_write() -> void:
	_first_attempt()
	_select_absence()
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	var progressed: Dictionary = f.attempt(state.lifecycle.branch_id).value.duplicate(true)
	assert_gt(progressed.revision, 1)
	state.route_context = {}
	_recreate()
	assert_true(f.begin().ok)
	assert_eq(f.owner.pull_physical(f.token).value.phase, "checkpoint_retry")
	assert_true(f.action("retry").ok)
	assert_eq(f.attempt(state.lifecycle.branch_id).value, progressed)
	assert_eq(f.record(), progressed.record)
