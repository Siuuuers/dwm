extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/InputManager.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const HANDLE := {"generation": 1, "handle_id": "return-input-1", "holder": &"pause", "reason": &"universal_pause"}
var _manager: Node
var _gate: RefCounted

func before_each() -> void:
	_manager = add_child_autofree(MANAGER.new())
	_gate = GATE.new()
	assert_true(_manager.configure_mutation_gate(_gate).ok)

func _retire(handle: Variant) -> Dictionary:
	if not _manager.has_method("retire_suspended_source"):
		return {"ok": false, "code": &"retirement_unavailable"}
	return _manager.retire_suspended_source(handle)

func _contact(pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	return event

func test_abandonment_custody_excludes_other_owners_and_external_commands() -> void:
	var acquired: Dictionary = _gate.acquire(&"session_abandonment")
	assert_true(acquired.ok)
	if not acquired.ok: return
	assert_eq(_gate.guard_external(&"new_acc").code, &"TRANSACTION_ACTIVE")
	for owner: StringName in [&"restore", &"new_run", &"causal_transaction"]:
		assert_eq(_gate.acquire(owner).code, &"TRANSACTION_ACTIVE")
	assert_false(_gate.release(&"restore", acquired.value.token).ok)
	assert_true(_gate.release(&"session_abandonment", acquired.value.token).ok)
	assert_true(_gate.guard_external(&"new_acc").ok)

func test_retirement_requires_exact_suspended_handle_and_dedicated_custody() -> void:
	assert_true(_manager.begin_suspend(HANDLE).ok)
	assert_false(_retire(HANDLE).ok)
	var restore: Dictionary = _gate.acquire(&"restore")
	assert_false(_retire(HANDLE).ok)
	assert_true(_gate.release(&"restore", restore.value.token).ok)
	var acquired: Dictionary = _gate.acquire(&"session_abandonment")
	assert_true(acquired.ok)
	if not acquired.ok: return
	for invalid: Variant in [null, {}, {"handle_id": "return-input-1"}]:
		assert_false(_retire(invalid).ok)
	var foreign := HANDLE.duplicate(true)
	foreign.generation = 2
	assert_false(_retire(foreign).ok)
	assert_eq(_manager.get_state().value.state, &"Suspended")
	assert_true(_retire(HANDLE).ok)
	assert_eq(_manager.get_state().value.state, &"Active")
	assert_false(_manager.resume(HANDLE).ok, "retired Pause cannot resume the old source")

func test_held_contact_survives_retirement_until_release_and_next_frame() -> void:
	_manager.observe_physical_contact(_contact(true))
	var contacts: Dictionary = _manager.get_physical_contacts()
	assert_true(_manager.begin_suspend(HANDLE).ok)
	var acquired: Dictionary = _gate.acquire(&"session_abandonment")
	assert_true(acquired.ok)
	if not acquired.ok: return
	assert_true(_retire(HANDLE).ok)
	assert_eq(_manager.get_physical_contacts(), contacts, "retirement must not fabricate a physical release")
	assert_false(_manager.is_source_input_admitted())
	await get_tree().process_frame
	assert_false(_manager.is_source_input_admitted(), "held Return cannot activate successor Title")
	_manager.observe_physical_contact(_contact(false))
	assert_true(_manager.is_source_input_admitted())
	_manager.observe_physical_contact(_contact(true))
	var next: Dictionary = _manager.get_physical_contacts()
	assert_gt(int(next.values()[0]), int(contacts.values()[0]), "new contact keeps monotonically increasing identity")
	_manager.observe_physical_contact(_contact(false))

func test_retry_does_not_requarantine_fresh_input_or_retire_new_pause() -> void:
	assert_true(_manager.begin_suspend(HANDLE).ok)
	var acquired: Dictionary = _gate.acquire(&"session_abandonment")
	assert_true(acquired.ok)
	if not acquired.ok: return
	assert_true(_retire(HANDLE).ok)
	await get_tree().process_frame
	_manager.observe_physical_contact(_contact(true))
	assert_true(_retire(HANDLE).ok, "same operation retry proves its completed retirement")
	assert_true(_manager.is_source_input_admitted(), "retry must not restart closing-frame quarantine")
	var next := HANDLE.duplicate(true)
	next.generation = 2
	next.handle_id = "return-input-2"
	assert_true(_manager.begin_suspend(next).ok)
	assert_false(_retire(HANDLE).ok, "old retirement may not consume new suspension")
	assert_eq(_manager.get_state().value.state, &"Suspended")
	_manager.observe_physical_contact(_contact(false))

func test_retirement_refuses_fatal_gate_and_leaves_suspension_intact() -> void:
	assert_true(_manager.begin_suspend(HANDLE).ok)
	assert_true(_gate.latch_fatal({"source": "test", "phase": "retire", "code": "indeterminate", "details": {}}).ok)
	assert_false(_retire(HANDLE).ok)
	assert_eq(_manager.get_state().value.state, &"Suspended")

func test_retired_handles_cannot_be_reacquired_even_after_another_retirement() -> void:
	var acquired: Dictionary = _gate.acquire(&"session_abandonment")
	assert_true(acquired.ok)
	assert_true(_manager.begin_suspend(HANDLE).ok)
	assert_true(_retire(HANDLE).ok)
	assert_false(_manager.begin_suspend(HANDLE).ok)
	assert_false(_manager.resume(HANDLE).ok)
	var next := HANDLE.duplicate(true)
	next.generation = 2
	next.handle_id = "return-input-2"
	assert_true(_manager.begin_suspend(next).ok)
	assert_true(_retire(next).ok)
	assert_false(_manager.begin_suspend(HANDLE).ok, "a later retirement cannot revive an older abandoned capability")
	assert_false(_manager.begin_suspend(next).ok)
