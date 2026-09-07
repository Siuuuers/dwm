extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/SaveManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const PARTICIPANT := preload("res://tests/support/FakeRestoreParticipant.gd")
const CALL_LOG := preload("res://tests/support/RestoreCallLog.gd")
const OWNERS := ["run", "desktop_consequence", "desktop_board", "schedule_view",
	"profile", "localization", "audio", "route", "narrative"]

func _fixture() -> Dictionary:
	var manager: Node = autofree(MANAGER.new())
	var path := OS.get_environment("DWM_TEST_ROOT").path_join("unified_restore").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(path)
	assert_true(manager.initialize(STORAGE.new(path)).get("ok", false))
	var gate: RefCounted = GATE.new()
	assert_true(manager.configure_mutation_gate(gate).get("ok", false))
	var log: RefCounted = CALL_LOG.new()
	var participants := {}
	var plans := {}
	for owner: String in OWNERS:
		participants[owner] = PARTICIPANT.new(owner, log)
		plans[owner] = {}
	var configured: Dictionary = manager.configure_restore_participants(participants)
	assert_true(configured.get("ok", false), "Schedule must participate in the same restore: " + JSON.stringify(configured))
	return {"manager": manager, "gate": gate, "participants": participants,
		"log": log, "configured": configured.get("ok", false),
		"prepared": {"participant_plans": plans, "checkpoint_id": "unified:1", "route_id": "main"}}

func test_schedule_restores_with_the_other_owners_before_route_dispatch() -> void:
	var fixture := _fixture()
	if not fixture.configured: return
	var result: Dictionary = fixture.manager.commit_prepared_restore(fixture.prepared)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_true(fixture.participants.schedule_view.was_applied())
	var finals: Array[String] = []
	for entry: String in fixture.log.entries:
		if entry.ends_with(".finalize"): finals.append(entry.trim_suffix(".finalize"))
	assert_lt(finals.find("schedule_view"), finals.find("route"), "Scene dispatch follows Schedule finalization")
	assert_eq(finals.back(), "route", "Irreversible route dispatch remains last")
	assert_false(fixture.gate.is_active())

func test_late_failure_rolls_back_schedule_without_dispatching_the_route() -> void:
	var fixture := _fixture()
	if not fixture.configured: return
	fixture.participants.narrative.set_failure(&"finalize")
	var result: Dictionary = fixture.manager.commit_prepared_restore(fixture.prepared)
	assert_false(result.get("ok", true))
	assert_false(fixture.participants.schedule_view.was_applied(), "Failed restore compensates Schedule too")
	assert_does_not_have(fixture.log.entries, "route.finalize", "Failure must not dispatch another scene")
	assert_false(fixture.gate.is_active(), "Fully compensated failure releases custody")

func test_failed_first_restore_returns_schedule_to_its_unopened_state() -> void:
	var fixture := _fixture()
	if not fixture.configured: return
	var registry: RefCounted = preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd").load_current().value.registry
	var view: RefCounted = preload("res://scripts/application/schedule/ScheduleViewController.gd").new()
	assert_true(view.configure(registry, preload("res://scripts/domain/schedule/ScheduleRules.gd"), registry.fingerprint()).ok)
	var participant: RefCounted = preload("res://scripts/application/restore/ScheduleViewRestoreParticipant.gd").new(
		view, registry, null, preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd"))
	fixture.participants.schedule_view = participant
	assert_true(fixture.manager.configure_restore_participants(fixture.participants).ok)
	var empty: Dictionary = preload("res://scripts/domain/schedule/ScheduleViewState.gd").make_empty(3, "causal-restored").value.view
	var prepared: Dictionary = participant.prepare({"schedule_view": empty, "registry_fingerprint": registry.fingerprint()})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	fixture.prepared.participant_plans.schedule_view = prepared.value.schedule_view_plan
	fixture.participants.narrative.set_failure(&"finalize")
	assert_eq(view.capture().get("code"), &"day_not_open")
	var result: Dictionary = fixture.manager.commit_prepared_restore(fixture.prepared)
	assert_false(result.get("ok", true))
	assert_eq(view.capture().get("code"), &"day_not_open", "Compensation must undo the first installed view too")
	assert_does_not_have(fixture.log.entries, "route.finalize")
	assert_false(fixture.gate.is_active())
