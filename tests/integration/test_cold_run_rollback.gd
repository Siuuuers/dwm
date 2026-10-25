extends "res://addons/gut/test.gd"

var _scene_validation_scope := preload("res://tests/support/SceneValidationScope.gd").new()

const GAME_STATE := preload("res://autoload/GameState.gd")
const PARTICIPANT := preload("res://scripts/application/restore/RunRestoreParticipant.gd")

func _installed_plan() -> Dictionary:
	var template: Node = autofree(GAME_STATE.new())
	template.reset_game()
	return {"snapshot": template.capture_run_snapshot_input()}

func test_cold_compensation_restores_exact_baseline_and_allows_retry() -> void:
	var owner: Node = autofree(GAME_STATE.new())
	var participant := PARTICIPANT.new(owner)
	var captured: Dictionary = participant.capture()
	assert_true(captured.ok)
	var baseline: Dictionary = captured.value.duplicate(true)
	assert_false(baseline.backup.run_configuration_installed)
	assert_eq(baseline.backup.lifecycle.run_id, "")
	var plan := _installed_plan()
	watch_signals(owner)
	for attempt: int in 2:
		assert_true(participant.apply_silent(plan).get("ok", false), "retry can install a validated run")
		assert_true(owner.capture_restore_state().value.backup.run_configuration_installed)
		var rolled: Dictionary = participant.rollback_silent(captured.value)
		assert_true(rolled.get("ok", false), str(rolled))
		assert_eq(owner.capture_restore_state().value, baseline, "all captured owner state returns exactly")
		assert_true(participant.rollback_silent(captured.value).get("ok", false), "compensation is retryable")
	assert_eq(captured.value, baseline, "retained backup remains detached")
	assert_signal_not_emitted(owner, "save_relevant_state_changed")

func test_cold_backup_cannot_bypass_installed_or_session_validation() -> void:
	var owner: Node = autofree(GAME_STATE.new())
	var captured: Dictionary = owner.capture_restore_state().value
	assert_true(owner.apply_restore_silent(_installed_plan()).get("ok", false))
	var installed: Dictionary = owner.capture_restore_state().value
	var forged := captured.duplicate(true)
	forged.backup.run_configuration_installed = true
	assert_false(owner.rollback_restore_silent(forged).get("ok", false))
	assert_eq(owner.capture_restore_state().value, installed)
	forged = captured.duplicate(true)
	forged.backup.lifecycle.day = 2
	assert_false(owner.rollback_restore_silent(forged).get("ok", false), "only exact cold lifecycle is admitted")
	assert_eq(owner.capture_restore_state().value, installed)
	forged = captured.duplicate(true)
	forged.backup.session_generation += 1
	assert_eq(owner.rollback_restore_silent(forged).get("code"), &"stale_run_backup")
	assert_eq(owner.capture_restore_state().value, installed)
	assert_false(owner._run_lifecycle.prepare_restore(captured.backup.lifecycle).get("ok", false), "persisted run validation stays strict")

func test_scene_install_compensation_preserves_cold_state_and_configured_owners() -> void:
	var fixture := preload("res://tests/support/SceneRunSaveFixture.gd").new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	if not setup.get("ok", false):
		fixture.close()
		return
	var owner: Node = fixture.game
	var participant := PARTICIPANT.new(owner)
	var captured: Dictionary = participant.capture()
	var lifecycle_owner: RefCounted = owner._run_lifecycle
	var bridge_owner: Object = owner._scene_event_bridge
	assert_false(captured.value.backup.run_configuration_installed)
	assert_eq(captured.value.backup.lifecycle.run_id, "")
	watch_signals(owner)
	for attempt: int in 2:
		var applied: Dictionary = participant.apply_silent({"snapshot": fixture.snapshot})
		assert_true(applied.get("ok", false), str(applied))
		if not applied.get("ok", false): break
		assert_true(owner.capture_restore_state().value.backup.lifecycle.has("scene_assignment"))
		# Simulate progress installed before a later restore participant refuses.
		# The empty fixture alone cannot expose leaked progress during compensation.
		owner.scene_choices = {"test.opportunity": "second"}
		owner.scene_challenge_outcomes = {"test.occurrence".sha256_text(): {
			"challenge_id": "test.challenge", "outcome": "perfect"}}
		var rolled: Dictionary = participant.rollback_silent(captured.value)
		assert_true(rolled.get("ok", false), str(rolled))
		assert_eq(owner.capture_restore_state().value, captured.value, "scene identity, references, receipts and contacts return exactly")
		assert_true(owner.scene_choices.is_empty(), "cold compensation clears partially installed choices")
		assert_true(owner.scene_challenge_outcomes.is_empty(), "cold compensation clears partially installed outcomes")
		assert_same(owner._run_lifecycle, lifecycle_owner)
		assert_same(owner._run_lifecycle._scene_issuer, fixture.issuer)
		assert_same(owner._scene_event_bridge, bridge_owner)
	assert_signal_not_emitted(owner, "save_relevant_state_changed")
	fixture.close()

func test_live_run_backup_restores_detached_scene_progress() -> void:
	var manifest := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var loaded: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		FileAccess.get_file_as_string("res://data/manifests/scene_story_registration.json"))
	assert_true(loaded.ok, str(loaded))
	if not loaded.ok: return
	var installed: Dictionary = manifest.configure_test_scene_registration(loaded.value)
	assert_true(installed.ok, str(installed))
	if not installed.ok: return
	var opportunity := ""
	var choice := ""
	for entry: Dictionary in loaded.value.scene_programme.entries:
		for marker: Dictionary in entry.markers:
			if marker.kind == "thought.pass":
				opportunity = marker.payload.opportunity_id
				choice = "yes"
			elif marker.kind == "thought.options":
				opportunity = marker.payload.opportunity_id
				choice = marker.payload.options[0].choice_id
	assert_false(opportunity.is_empty(), "installed story supplies an actual choice")
	assert_false(loaded.value.challenges.is_empty(), "installed story supplies an actual challenge")
	if opportunity.is_empty() or loaded.value.challenges.is_empty(): return
	var challenge_id: String = loaded.value.challenges[0].challenge_id
	var owner: Node = autofree(GAME_STATE.new())
	owner.reset_game()
	var occurrence := "test.occurrence".sha256_text()
	owner.scene_choices = {opportunity: choice}
	owner.scene_challenge_outcomes = {occurrence: {"challenge_id": challenge_id, "outcome": "perfect"}}
	var captured: Dictionary = owner.capture_live_run_state()
	assert_true(captured.ok)
	var baseline: Dictionary = captured.value.duplicate(true)
	for attempt: int in 2:
		owner.scene_choices[opportunity] = "pass"
		owner.scene_challenge_outcomes[occurrence].outcome = "lost"
		assert_eq(captured.value, baseline, "live mutation cannot alter the retained backup")
		var restored: Dictionary = owner.restore_live_run_state(captured.value)
		assert_true(restored.get("ok", false), str(restored))
		assert_eq(owner.scene_choices, baseline.backup.scene_choices)
		assert_eq(owner.scene_challenge_outcomes, baseline.backup.scene_challenge_outcomes)
		assert_eq(owner.capture_live_run_state().value, baseline, "retry restores the complete captured live state")
	# Restored nested dictionaries must also detach from caller-owned backup bytes.
	captured.value.backup.scene_choices[opportunity] = "pass"
	captured.value.backup.scene_challenge_outcomes[occurrence].outcome = "unfinished"
	assert_eq(owner.scene_choices, baseline.backup.scene_choices)
	assert_eq(owner.scene_challenge_outcomes, baseline.backup.scene_challenge_outcomes)

func test_nested_registration_scope_restores_matching_derived_tables() -> void:
	var manifest := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var parsed: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		FileAccess.get_file_as_string("res://data/manifests/scene_story_registration.json"))
	assert_true(parsed.ok, str(parsed))
	if not parsed.ok: return
	var installed: Dictionary = manifest.configure_test_scene_registration(parsed.value)
	assert_true(installed.ok, str(installed))
	if not installed.ok: return
	var original: Dictionary = manifest.scene_contract_tables()
	assert_true(original.ok, str(original))
	if not original.ok: return
	var nested := preload("res://tests/support/SceneValidationScope.gd").new()
	nested.install(true)
	assert_true(manifest._scene_contract_tables.is_empty(), "registration reset clears its derived tables")
	var replacement: Dictionary = preload("res://tests/support/SceneContactFixture.gd").install_registration()
	assert_true(replacement.ok, str(replacement))
	if replacement.ok:
		assert_ne(manifest.scene_contract_tables().value.fingerprint, original.value.fingerprint)
	nested.restore()
	var restored: Dictionary = manifest.scene_contract_tables()
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	assert_eq(restored.value, original.value, "nested fixture restores all outer registration tables")
	assert_eq(restored.bundle, original.bundle)
	assert_eq(restored.value.fingerprint, manifest.scene_registration_fingerprint())

func before_each() -> void:
	_scene_validation_scope.install(true)

func after_each() -> void:
	_scene_validation_scope.restore()
