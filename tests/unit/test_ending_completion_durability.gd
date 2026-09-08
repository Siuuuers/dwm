extends GutTest

const PROFILE := preload("res://autoload/ProfileManager.gd")
const MASTERY_FIXTURE := preload("res://tests/support/CanonicalDatingMasteryFixture.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")

class Source extends RefCounted:
	var allowed := false
	var calls := 0
	func read() -> Dictionary:
		calls += 1
		return {"ok": true, "value": {"source_kind": "schedule_done"}} if allowed else {"ok": false, "code": &"day7_resolution_incomplete"}

class Writer extends RefCounted:
	var state: Node
	var gate: RefCounted
	var fail_next := false
	var snapshots: Array[Dictionary] = []
	func write() -> Dictionary:
		if not gate.is_internal_owner_active(&"causal_transaction"):
			return {"ok": false, "code": &"missing_causal_lease"}
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"fixture_disk_failure"}
		snapshots.append(state.capture_restore_state().value.backup)
		return {"ok": true}

func _profile(storage: RefCounted, gate: RefCounted) -> Node:
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(storage).ok)
	assert_true(profile.configure_mutation_gate(gate).ok)
	return profile


func test_causal_completion_commits_gallery_and_pair_witness_atomically_and_keeps_general_guard() -> void:
	var gate: RefCounted = GATE.new()
	var storage: RefCounted = STORAGE.new("ending-profile/root", OPS.new())
	var profile := _profile(storage, gate)
	var token := "ending:run-one:gallery:ending.priscilla_lavinia.sweet"
	assert_false(profile.has_completed_ending())
	assert_true(profile.prepare_ending_unlock("ending.priscilla_lavinia.sweet", token).ok)
	assert_false(profile.has_completed_ending(), "preparation has no achievement")
	assert_false(profile.record_ending_completion("ending.priscilla_lavinia.sweet", token, "love_sweet").ok)
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	assert_false(profile.set_preference(&"preferences.language.primary_locale_id", "zh-CN").ok,
		"ordinary external Profile writes stay fenced")
	assert_false(profile.record_ending_completion("ending.priscilla_lavinia.sweet", token, "love_dark").ok)
	assert_false(profile.has_completed_ending())
	assert_true(profile.record_ending_completion("ending.priscilla_lavinia.sweet", token, "love_sweet").ok)
	assert_true(profile.has_completed_ending())
	assert_eq(profile.get_pair_form_witnesses().value, ["love_sweet"])
	var revision: int = profile.get_profile_revision()
	assert_true(profile.record_ending_completion("ending.priscilla_lavinia.sweet", token, "love_sweet").ok)
	assert_eq(profile.get_profile_revision(), revision, "exact replay does not rewrite Profile")
	assert_false(profile.record_ending_completion("ending.priscilla_lavinia.sweet", token, "ambiguous_sweet").ok)
	assert_false(profile.record_ending_completion("ending.priscilla_lavinia.sweet", token).ok)
	assert_eq(profile.get_profile_revision(), revision, "changed same-tone form is a refused replay")
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)
	assert_true(profile.reset_gallery().ok)
	assert_eq(profile.get_profile_snapshot().gallery_unlocks, [])
	assert_true(profile.has_completed_ending(), "Clear Gallery cannot rewind the first-ending milestone")
	var restored := _profile(storage, gate)
	assert_true(restored.has_completed_ending(), "the milestone survives actual storage reload")
	assert_true(restored.reset_entire_profile().ok)
	assert_false(restored.has_completed_ending(), "only full Profile reset removes the milestone")
	assert_false(_profile(storage, gate).has_completed_ending(), "the full-reset exception is durable")
	lease = gate.acquire(&"causal_transaction")
	assert_true(restored.record_ending_completion("ending.alone", "ending:new-run:gallery:ending.alone").ok)
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)
	assert_true(restored.has_completed_ending(), "a later physical ending earns the milestone again")


func test_legacy_gallery_only_discovery_keeps_its_milestone_when_gallery_is_cleared() -> void:
	var gate: RefCounted = GATE.new()
	var storage: RefCounted = STORAGE.new("ending-legacy/root", OPS.new())
	var profile := _profile(storage, gate)
	var legacy: Dictionary = profile.get_profile_snapshot()
	legacy.gallery_unlocks = ["ending.alone"]
	assert_true(profile.commit_prepared_profile(legacy).ok)
	assert_true(profile.has_completed_ending())
	assert_true(profile.reset_gallery().ok)
	assert_true(profile.has_completed_ending())
	assert_true(_profile(storage, gate).has_completed_ending())
	assert_true(profile.reset_entire_profile().ok)
	assert_false(profile.has_completed_ending(), "full reset also removes legacy milestone evidence")


func test_terminal_admission_requires_source_then_rolls_back_failed_save_and_retries_same_design() -> void:
	var state: Node = autofree(MASTERY_FIXTURE.Game.new())
	state.reset_game()
	state._lifecycle_set_playing_day(7)
	var gate: RefCounted = GATE.new()
	assert_true(state.configure_mutation_gate(gate).ok)
	var source := Source.new()
	var writer := Writer.new()
	writer.state = state
	writer.gate = gate
	assert_true(state.configure_ending_source_reader(source.read).ok)
	assert_true(state.configure_ending_checkpoint_writer(writer.write).ok)
	assert_false(state.resume_terminal_ending().ok)
	assert_eq(state._run_lifecycle.get_state(), &"PLAYING")
	assert_false(gate.is_active())
	state.pending_hospital = true
	state.daily_opened_contacts["day:7:friend:sylvia"] = true
	state.inter_friend_route_state["priscilla_lavinia"] = {}
	state.inter_friend_route_state["priscilla_lavinia"]["frozen_form"] = "love_sweet"
	state.inter_friend_route_state["priscilla_lavinia"]["ending_eligible"] = true
	state.route_context["observer_variant_by_scope"] = {"priscilla_lavinia": "residue"}
	var evidence: Dictionary = MASTERY_FIXTURE.profile_for_scope(state, "priscilla_lavinia")
	assert_true(evidence.ok, str(evidence))
	if not evidence.ok: return
	autofree(evidence.value.profile)
	var before: Dictionary = state.capture_restore_state().value.backup
	source.allowed = true
	writer.fail_next = true
	var failed: Dictionary = state.resume_terminal_ending()
	assert_eq(str(failed.code), "fixture_disk_failure")
	assert_eq(state.capture_restore_state().value.backup, before, "failed ending entry restores run and unfrozen route context")
	assert_false(gate.is_active())
	assert_true(state.resume_terminal_ending().ok)
	assert_eq(state._run_lifecycle.get_state(), &"ENDING")
	var plan: Dictionary = writer.snapshots.back().lifecycle.ending_plan
	assert_eq(plan.steps.size(), 4)
	assert_eq(plan.steps[0].ending_id, "ending.sylvia.special")
	assert_eq(plan.steps[1].ending_id, "ending.sylvia.dark")
	assert_eq(plan.steps[2].ending_id, "ending.priscilla_lavinia.sweet")
	assert_eq(plan.steps[3].presentation_variant, "residue")
	assert_eq(plan.next_step_index, 0, "admission starts no physical timeline")
	assert_true(state.resume_terminal_ending().ok)
	assert_eq(writer.snapshots.size(), 1, "already admitted ending routes without refreezing")
	assert_false(gate.is_active())
