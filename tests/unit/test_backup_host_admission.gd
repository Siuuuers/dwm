extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/backup/BackupPresentationPort.gd")


class BackupOwner extends RefCounted:
	signal slot_metadata_changed
	signal save_capability_changed(capability: Dictionary)

	var inspections: Array[String] = []
	var prepares: Array[Dictionary] = []
	var commits: Array[String] = []
	var cancels: Array[String] = []
	var _sequence := 0
	var save_capability_calls := 0
	var save_enabled := true

	func inspect_backup(locator: String) -> Dictionary:
		inspections.append(locator)
		return {"ok": true, "value": _record(locator)}

	func get_backup_save_capability() -> Dictionary:
		save_capability_calls += 1
		return {"enabled": save_enabled, "reason": "" if save_enabled else "capture_unavailable"}

	func prepare_backup_action(action: String, locator: String) -> Dictionary:
		prepares.append({"action": action, "locator": locator})
		_sequence += 1
		return {"ok": true, "value": {
			"token": "owner-%d" % _sequence,
			"record": _record(locator),
		}}

	func commit_backup_action(token: String) -> Dictionary:
		commits.append(token)
		return {"ok": true, "value": {"written": true}}

	func cancel_backup_action(token: String) -> void:
		cancels.append(token)

	func _record(locator: String) -> Dictionary:
		return {
			"locator": locator,
			"state": "occupied",
			"day": 3,
			"saved_time": "12:34",
			"fallback": false,
			"load_day": 3,
			"load_saved_time": "12:34",
			"reason": "",
			"revision": "revision:" + locator,
			"operation_allowed": true,
			"loadable": true,
		}


class QuickOwner extends BackupOwner:
	var quick_condition_current := true
	var quick_capability_calls := 0
	var quick_condition_calls := 0
	func get_backup_quick_capability(action: String) -> Dictionary:
		quick_capability_calls += 1
		return {"ok": true, "value": {"enabled": true, "status_key": "",
			"condition": {"action": action, "signature": "fixture"}}}
	func prepare_quick_backup_action(action: String) -> Dictionary:
		var prepared := prepare_backup_action(action, "quick")
		prepared.value["condition"] = {"action": action, "signature": "fixture"}
		return prepared
	func is_quick_condition_current(_condition: Dictionary) -> bool:
		quick_condition_calls += 1
		return quick_condition_current


class LoadMaskedPort extends "res://scripts/application/backup/BackupPresentationPort.gd":
	func _project_record(source: Dictionary, capability: Dictionary, admitted: bool) -> Dictionary:
		var record: Dictionary = super._project_record(source, capability, admitted)
		record.actions.load = false
		return record


class Admission extends RefCounted:
	var allowed := true
	var refusal_code: StringName = &"pause_source_changed"
	var calls := 0

	func guard() -> Dictionary:
		calls += 1
		if allowed:
			return {"ok": true, "code": &"ok", "value": {"admitted": true}}
		return {"ok": false, "code": refusal_code, "value": null}

	func guard_with_argument(_command: StringName) -> Dictionary:
		return guard()


class MalformedAdmission extends RefCounted:
	var ok_value: Variant = "true"

	func guard() -> Dictionary:
		return {"ok": ok_value, "code": &"invented_success"}


class MortalAdmission extends Node:
	func guard() -> Dictionary:
		return {"ok": true, "code": &"ok"}


func test_refused_projection_keeps_nine_records_and_masks_actions_without_owner_mutation() -> void:
	var owner := BackupOwner.new()
	var admission := Admission.new()
	admission.allowed = false
	var port := PORT.new()
	assert_true(port.configure(owner, "in_run", Callable(admission, "guard")).get("ok", false))

	var projection: Dictionary = port.get_projection()
	assert_true(projection.get("ok", false))
	assert_eq(projection.value.records.size(), 9)
	assert_eq(projection.value.save_capability, {"enabled": true, "reason": ""})
	for index: int in range(PORT.LOCATORS.size()):
		var record: Dictionary = projection.value.records[index]
		assert_eq(record.locator, PORT.LOCATORS[index])
		assert_eq(record.state, "occupied")
		assert_eq(record.reason, "")
		assert_eq(record.actions, {"save": false, "load": false, "delete": false})
	assert_eq(owner.inspections, PORT.LOCATORS)
	assert_eq(port.prepare_action("save", "slot:1").get("code"), &"pause_source_changed")
	assert_eq(owner.inspections.size(), 9, "refused preparation performs no extra owner inspection")
	assert_eq(owner.prepares, [])
	assert_eq(owner.commits, [])
	assert_eq(owner.cancels, [])


func test_source_change_after_prepare_cancels_owner_plan_without_committing() -> void:
	var owner := BackupOwner.new()
	var admission := Admission.new()
	var port := PORT.new()
	assert_true(port.configure(owner, "in_run", Callable(admission, "guard")).get("ok", false))
	var prepared: Dictionary = port.prepare_action("save", "slot:1")
	assert_true(prepared.get("ok", false))
	var token: String = prepared.value.token

	admission.allowed = false
	var refused: Dictionary = port.commit_action(token)
	assert_eq(refused, {"ok": false, "code": &"pause_source_changed", "value": null})
	assert_eq(owner.commits, [])
	assert_eq(owner.cancels, [token])


func test_consumed_consent_cannot_replay_after_guard_repairs_and_cancel_stays_available() -> void:
	var owner := BackupOwner.new()
	var admission := Admission.new()
	var port := PORT.new()
	assert_true(port.configure(owner, "in_run", Callable(admission, "guard")).get("ok", false))
	var first_token: String = port.prepare_action("delete", "slot:2").value.token
	admission.allowed = false
	assert_false(port.commit_action(first_token).get("ok", false))
	admission.allowed = true
	assert_eq(port.commit_action(first_token).get("code"), &"stale_backup_action")
	assert_eq(owner.commits, [])

	var second_token: String = port.prepare_action("delete", "slot:2").value.token
	admission.allowed = false
	port.cancel_action(second_token)
	admission.allowed = true
	assert_eq(port.commit_action(second_token).get("code"), &"stale_backup_action")
	assert_eq(owner.cancels, [first_token, second_token])


func test_default_context_behavior_and_immutable_configuration_remain_compatible() -> void:
	var owner := BackupOwner.new()
	var port := PORT.new()
	assert_true(port.configure(owner).get("ok", false))
	assert_true(port.configure(owner).get("ok", false), "the identical legacy configuration is idempotent")
	var projection: Dictionary = port.get_projection()
	assert_true(projection.value.records[2].actions.save)
	assert_true(projection.value.records[2].actions.load)
	assert_true(projection.value.records[2].actions.delete)
	assert_null(projection.value.records[2].family, "injected day alone cannot establish a family")
	assert_null(projection.value.records[2].load_family)
	var token: String = port.prepare_action("save", "slot:1").value.token
	assert_true(port.commit_action(token).get("ok", false))

	var admission := Admission.new()
	assert_eq(port.configure(owner, "in_run", Callable(admission, "guard")).get("code"),
		&"backup_already_configured")
	var title_port := PORT.new()
	assert_true(title_port.configure(owner, "title").get("ok", false))
	var title_record: Dictionary = title_port.get_projection().value.records[2]
	assert_false(title_record.actions.save)
	assert_true(title_record.actions.load)
	assert_true(title_record.actions.delete)
	assert_eq(title_port.configure(owner, "in_run").get("code"), &"backup_already_configured")

	var guarded_port := PORT.new()
	var guard := Callable(admission, "guard")
	assert_true(guarded_port.configure(owner, "in_run", guard).get("ok", false))
	assert_true(guarded_port.configure(owner, "in_run", guard).get("ok", false))
	assert_eq(guarded_port.configure(owner, "in_run", Callable()).get("code"),
		&"backup_already_configured")
	var invalid_port := PORT.new()
	assert_eq(invalid_port.configure(owner, "in_run", Callable(admission, "guard_with_argument")).get("code"),
		&"invalid_backup_admission")
	var missing_method := Callable(admission, "missing_guard")
	assert_false(missing_method.is_null())
	assert_false(missing_method.is_valid())
	assert_eq(PORT.new().configure(owner, "in_run", missing_method).get("code"),
		&"invalid_backup_admission")


func test_non_boolean_guard_results_fail_closed() -> void:
	var owner := BackupOwner.new()
	var admission := MalformedAdmission.new()
	var port := PORT.new()
	assert_true(port.configure(owner, "in_run", Callable(admission, "guard")).get("ok", false))
	for malformed: Variant in ["true", 1]:
		admission.ok_value = malformed
		var projection: Dictionary = port.get_projection()
		assert_eq(projection.value.records.size(), 9)
		for record: Dictionary in projection.value.records:
			assert_eq(record.actions, {"save": false, "load": false, "delete": false})
		assert_eq(port.prepare_action("save", "slot:1").get("code"),
			&"backup_action_unavailable")
	assert_eq(owner.prepares, [])


func test_configured_admission_target_freed_later_fails_closed() -> void:
	var owner := BackupOwner.new()
	var admission := MortalAdmission.new()
	var guard := Callable(admission, "guard")
	var port := PORT.new()
	assert_true(port.configure(owner, "in_run", guard).get("ok", false))
	admission.free()
	assert_false(guard.is_valid())

	var projection: Dictionary = port.get_projection()
	assert_eq(projection.value.records.size(), 9)
	for record: Dictionary in projection.value.records:
		assert_eq(record.actions, {"save": false, "load": false, "delete": false})
	assert_eq(port.prepare_action("save", "slot:1").get("code"),
		&"backup_action_unavailable")
	assert_eq(owner.prepares, [])


func test_preparation_uses_one_authoritative_owner_inspection() -> void:
	var owner := BackupOwner.new()
	var port := PORT.new()
	assert_true(port.configure(owner).get("ok", false))
	var prepared: Dictionary = port.prepare_action("load", "slot:1")
	assert_true(prepared.get("ok", false))
	assert_eq(owner.prepares.size(), 1)
	assert_eq(owner.inspections.size(), 0, "owner preparation already inspects the selected file")
	assert_eq(prepared.value.record.day, 3)


func test_authoritative_preparation_cannot_bypass_projected_action_policy() -> void:
	var owner := BackupOwner.new()
	var port := PORT.new()
	assert_true(port.configure(owner).get("ok", false))
	assert_false(port.prepare_action("save", "autosave").get("ok", false))
	assert_eq(owner.commits, [])
	assert_eq(port._pending, {})
	assert_eq(owner.cancels.size(), owner.prepares.size(), "any refused owner candidate is discarded")


func test_title_metadata_does_not_query_live_save_capability() -> void:
	var owner := BackupOwner.new()
	owner.save_enabled = false
	var port := PORT.new()
	assert_true(port.configure(owner, "title").ok)
	var projection: Dictionary = port.get_projection()
	assert_eq(owner.save_capability_calls, 0)
	assert_eq(projection.value.save_capability, {"enabled": false, "reason": "title_load_only"})
	for record: Dictionary in projection.value.records:
		assert_eq(record.actions, {"save": false, "load": true, "delete": true})
	assert_eq(owner.inspections, PORT.LOCATORS)


func test_load_delete_confirmations_do_not_require_save_capture() -> void:
	for context: String in ["title", "in_run"]:
		var owner := BackupOwner.new()
		owner.save_enabled = false
		var port := PORT.new()
		assert_true(port.configure(owner, context).ok)
		for action: String in ["load", "delete"]:
			var prepared: Dictionary = port.prepare_action(action, "slot:1")
			assert_true(prepared.ok)
			if not prepared.ok: continue
			assert_eq(prepared.value.record.saved_time, "12:34")
			assert_eq(prepared.value.record.actions, {"save": false, "load": action == "load", "delete": action == "delete"})
			port.cancel_action(prepared.value.token)
		assert_eq(owner.save_capability_calls, 0)
		assert_eq(owner.cancels.size(), 2)
		assert_eq(owner.commits, [])


func test_save_confirmation_still_requires_current_save_capability() -> void:
	var owner := BackupOwner.new()
	var port := PORT.new()
	assert_true(port.configure(owner).ok)
	var prepared: Dictionary = port.prepare_action("save", "slot:1")
	assert_true(prepared.ok)
	assert_eq(prepared.value.record.actions, {"save": true, "load": false, "delete": false})
	port.cancel_action(prepared.value.token)
	owner.save_enabled = false
	assert_eq(port.prepare_action("save", "slot:1").get("code"), &"backup_action_unavailable")
	assert_eq(owner.save_capability_calls, 2)
	assert_eq(owner.cancels.size(), 2)
	assert_true(port._pending.is_empty())
	assert_eq(owner.commits, [])


func test_quick_load_confirmation_skips_save_capability_and_keeps_admission() -> void:
	var owner := QuickOwner.new()
	owner.save_enabled = false
	var admission := Admission.new()
	var port := PORT.new()
	assert_true(port.configure(owner, "in_run", admission.guard).ok)
	var prepared: Dictionary = port.prepare_quick_action("load")
	assert_true(prepared.ok)
	assert_eq(prepared.value.record.actions, {"save": false, "load": true, "delete": false})
	assert_eq(prepared.value.confirmation_kind, "replace_progress")
	assert_true(prepared.value.confirmation_required)
	assert_eq(owner.save_capability_calls, 0)
	admission.allowed = false
	assert_false(port.commit_action(prepared.value.token).ok)
	assert_eq(owner.cancels, [prepared.value.token])
	assert_eq(owner.commits, [])
	admission.allowed = true
	owner.quick_condition_current = false
	assert_false(port.prepare_quick_action("load").ok)
	assert_eq(owner.cancels.size(), 2, "stale preparation releases only its new token")
	assert_eq(owner.save_capability_calls, 0)
	assert_true(port._pending.is_empty())

	owner.quick_condition_current = true
	owner.save_enabled = true
	var capability_calls := owner.quick_capability_calls
	var condition_calls := owner.quick_condition_calls
	var saved: Dictionary = port.prepare_quick_action("save")
	assert_true(saved.ok)
	assert_eq(owner.quick_condition_calls, condition_calls, "Quick Save source freshness stays with owner preparation and commit")
	assert_eq(owner.quick_capability_calls, capability_calls, "Quick Save delegates capability to owner preparation")
	assert_eq(saved.value.record.actions, {"save": true, "load": false, "delete": false})
	assert_eq(owner.save_capability_calls, 1, "Quick Save still queries its own capability")
	port.cancel_action(saved.value.token)


func test_prepared_record_preserves_specialized_host_action_mask() -> void:
	var owner := BackupOwner.new()
	var port := LoadMaskedPort.new()
	assert_true(port.configure(owner).ok)
	assert_eq(port.prepare_action("load", "slot:1").get("code"), &"backup_action_unavailable")
	assert_eq(owner.save_capability_calls, 0)
	assert_eq(owner.cancels.size(), 1)
	assert_true(port._pending.is_empty())
	assert_eq(owner.commits, [])
