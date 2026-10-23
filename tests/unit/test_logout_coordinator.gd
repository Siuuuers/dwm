extends "res://addons/gut/test.gd"

## LogoutCoordinator (Plan 02 Task 6, dwm-p2r.32, req.desktop.logout), amendment SS9.2.
##
## stable_board_port's contract was not written down anywhere in the Task-6 brief's own Interfaces
## block; it was frozen by controller ruling on the bead instead:
##   func is_slice_executing() -> Dictionary   # success value = {executing: bool}
##   func capture_stable_board() -> Dictionary # success value = the latest stable board capture
## This suite exercises exactly that frozen contract via FakeStableBoardPort below.

const COORDINATOR_PATH := "res://scripts/application/desktop/LogoutCoordinator.gd"

const _ISSUER_RECEIPT_KEYS: Array[String] = ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]


class FakeStableBoardPort extends RefCounted:
	var executing := false
	var capture_result: Dictionary = {"ok": true, "code": &"ok", "value": {"board": "stable-board-capture"}}
	var executing_calls := 0
	var capture_calls := 0

	func is_slice_executing() -> Dictionary:
		executing_calls += 1
		return {"ok": true, "code": &"ok", "value": {"executing": executing}}

	func capture_stable_board() -> Dictionary:
		capture_calls += 1
		return capture_result.duplicate(true)


class FakeSaveManager extends RefCounted:
	var save_result: Dictionary = {"ok": true, "code": &"ok",
		"value": {"kind": "autosave", "slot_id": null, "save_reason": "logout",
			"checkpoint_id": "checkpoint-logout-1", "written": true}}
	var save_calls := 0

	func save_for_logout() -> Dictionary:
		save_calls += 1
		return save_result.duplicate(true)


class FakeRoutePort extends RefCounted:
	var goto_menu_calls := 0

	func goto_menu() -> void:
		goto_menu_calls += 1


func _exists() -> bool:
	return ResourceLoader.exists(COORDINATOR_PATH, "Script")


func _coordinator() -> RefCounted:
	return load(COORDINATOR_PATH).new()


func _receipt(transaction_id: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + transaction_id, "purpose": "transaction_id",
		"namespace": "fixturenamespace", "counter": 1, "token": transaction_id, "numeric_value": null}


func _request(transaction_id: String, confirmed: bool) -> Dictionary:
	return {"transaction_id": transaction_id, "transaction_issuer_receipt": _receipt(transaction_id),
		"confirmed": confirmed}


func _configured() -> Dictionary:
	var coordinator: RefCounted = _coordinator()
	var board := FakeStableBoardPort.new()
	var save_manager := FakeSaveManager.new()
	var route := FakeRoutePort.new()
	var configured: Dictionary = coordinator.configure(save_manager, route, board)
	assert_true(configured.get("ok", false), "configure: " + str(configured))
	return {"coordinator": coordinator, "board": board, "save_manager": save_manager, "route": route}


func test_logout_coordinator_exists() -> void:
	assert_true(_exists(), "LogoutCoordinator.gd must exist")


func test_configure_rejects_a_save_manager_missing_save_for_logout() -> void:
	if not _exists(): return
	var coordinator: RefCounted = _coordinator()
	var broken := RefCounted.new()
	var result: Dictionary = coordinator.configure(broken, FakeRoutePort.new(), FakeStableBoardPort.new())
	assert_false(result.get("ok", true), "a save_manager without save_for_logout must be rejected")


func test_configure_rejects_a_route_port_missing_goto_menu() -> void:
	if not _exists(): return
	var coordinator: RefCounted = _coordinator()
	var broken := RefCounted.new()
	var result: Dictionary = coordinator.configure(FakeSaveManager.new(), broken, FakeStableBoardPort.new())
	assert_false(result.get("ok", true), "a route_port without goto_menu must be rejected")


func test_configure_rejects_a_stable_board_port_missing_the_frozen_contract() -> void:
	if not _exists(): return
	var coordinator: RefCounted = _coordinator()
	var broken := RefCounted.new()
	var result: Dictionary = coordinator.configure(FakeSaveManager.new(), FakeRoutePort.new(), broken)
	assert_false(result.get("ok", true), "a stable_board_port missing is_slice_executing/capture_stable_board must be rejected")


func test_configure_is_idempotent_for_the_same_triple_and_rejects_replacement() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var again: Dictionary = coordinator.configure(rig["save_manager"], rig["route"], rig["board"])
	assert_true(again.get("ok", false), "reconfiguring with the identical triple is idempotent")
	var replaced: Dictionary = coordinator.configure(FakeSaveManager.new(), rig["route"], rig["board"])
	assert_false(replaced.get("ok", true), "configure may not replace an already-configured save_manager")


func test_request_logout_before_configure_fails_closed() -> void:
	if not _exists(): return
	var coordinator: RefCounted = _coordinator()
	var result: Dictionary = coordinator.request_logout(_request("logout-tx-1", true))
	assert_false(result.get("ok", true), "request_logout before configure must fail")


func test_unconfirmed_request_is_a_no_op() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var board: FakeStableBoardPort = rig["board"]
	var save_manager: FakeSaveManager = rig["save_manager"]
	var route: FakeRoutePort = rig["route"]
	var result: Dictionary = coordinator.request_logout(_request("logout-tx-2", false))
	assert_true(result.get("ok", false), "confirmed=false succeeds as a no-op: " + str(result))
	assert_false(bool(result["value"]["confirmed"]), "the result reports confirmed=false")
	assert_eq(save_manager.save_calls, 0, "an unconfirmed request never saves")
	assert_eq(route.goto_menu_calls, 0, "an unconfirmed request never routes")
	assert_eq(board.capture_calls, 0, "an unconfirmed request never captures the board")


func test_confirmed_request_while_a_bounded_slice_executes_returns_busy_without_saving() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var board: FakeStableBoardPort = rig["board"]
	var save_manager: FakeSaveManager = rig["save_manager"]
	var route: FakeRoutePort = rig["route"]
	board.executing = true
	var result: Dictionary = coordinator.request_logout(_request("logout-tx-3", true))
	assert_false(result.get("ok", true), "a confirmed logout must be refused while a slice executes")
	assert_eq(str(result.get("code", "")), "logout_busy_bounded_slice")
	assert_eq(save_manager.save_calls, 0, "a busy refusal never reaches save_for_logout")
	assert_eq(route.goto_menu_calls, 0, "a busy refusal never routes")
	# No internal busy-wait/await loop: exactly one is_slice_executing() probe per call.
	assert_eq(board.executing_calls, 1, "request_logout probes the slice exactly once, never spins")


func test_retry_logout_succeeds_once_the_slice_settles() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var board: FakeStableBoardPort = rig["board"]
	var save_manager: FakeSaveManager = rig["save_manager"]
	var route: FakeRoutePort = rig["route"]
	board.executing = true
	var busy: Dictionary = coordinator.request_logout(_request("logout-tx-4", true))
	assert_false(busy.get("ok", true))
	board.executing = false
	var retried: Dictionary = coordinator.retry_logout("logout-tx-4")
	assert_true(retried.get("ok", false), "retry after the slice settles succeeds: " + str(retried))
	assert_eq(save_manager.save_calls, 1, "exactly one durable save happens once unblocked")
	assert_eq(route.goto_menu_calls, 1, "a successful logout routes to the title/menu scene exactly once")
	assert_eq(board.capture_calls, 1, "the stable board is captured before the save")
	assert_eq(str(retried["value"]["transaction_id"]), "logout-tx-4")
	assert_true(bool(retried["value"]["routed"]))


func test_retry_logout_for_an_unknown_transaction_fails_closed() -> void:
	if not _exists(): return
	var rig := _configured()
	var result: Dictionary = rig["coordinator"].retry_logout("never-seen-tx")
	assert_false(result.get("ok", true), "retrying an unknown transaction must fail")


func test_save_failure_reports_logout_save_failed_and_never_routes() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var save_manager: FakeSaveManager = rig["save_manager"]
	var route: FakeRoutePort = rig["route"]
	save_manager.save_result = {"ok": false, "code": &"save_locked", "message": "disk unavailable"}
	var result: Dictionary = coordinator.request_logout(_request("logout-tx-5", true))
	assert_false(result.get("ok", true), "a disk failure must not report success")
	assert_eq(str(result.get("code", "")), "logout_save_failed")
	assert_eq(route.goto_menu_calls, 0, "a failed save must never route to the title/menu scene")


func test_retry_after_disk_failure_reuses_the_same_transaction_identity_and_succeeds() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var save_manager: FakeSaveManager = rig["save_manager"]
	var route: FakeRoutePort = rig["route"]
	save_manager.save_result = {"ok": false, "code": &"save_locked", "message": "disk unavailable"}
	var failed: Dictionary = coordinator.request_logout(_request("logout-tx-6", true))
	assert_false(failed.get("ok", true))
	# The transient failure clears: a real disk becoming available again is modeled as the fake
	# starting to succeed on the next call, exactly as save_for_logout's own idempotent checkpoint
	# re-attempt would behave against a real StorageAdapter.
	save_manager.save_result = {"ok": true, "code": &"ok",
		"value": {"kind": "autosave", "slot_id": null, "save_reason": "logout",
			"checkpoint_id": "checkpoint-logout-6", "written": true}}
	var retried: Dictionary = coordinator.retry_logout("logout-tx-6")
	assert_true(retried.get("ok", false), "retry succeeds once the disk write succeeds: " + str(retried))
	assert_eq(route.goto_menu_calls, 1, "the retried success routes exactly once")


func test_identical_retry_of_request_logout_with_the_same_receipt_is_accepted() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var first: Dictionary = coordinator.request_logout(_request("logout-tx-7", true))
	assert_true(first.get("ok", false))
	var replay: Dictionary = coordinator.request_logout(_request("logout-tx-7", true))
	assert_true(replay.get("ok", false), "an identical replay of the same transaction/receipt is accepted")


func test_a_different_receipt_at_an_occupied_transaction_id_conflicts() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var first: Dictionary = coordinator.request_logout(_request("logout-tx-8", true))
	assert_true(first.get("ok", false))
	var conflicting := _request("logout-tx-8", true)
	conflicting["transaction_issuer_receipt"] = _receipt("logout-tx-8-other")
	conflicting["transaction_issuer_receipt"]["token"] = "logout-tx-8"
	conflicting["transaction_issuer_receipt"]["receipt_id"] = "issuer_receipt.fixture-different"
	var conflict: Dictionary = coordinator.request_logout(conflicting)
	assert_false(conflict.get("ok", true), "changed receipt bytes at an occupied transaction id must conflict")
	assert_eq(str(conflict.get("code", "")), "logout_transaction_conflict")


func test_cancel_logout_erases_a_known_transaction_and_rejects_unknown_ones() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	coordinator.request_logout(_request("logout-tx-9", false))
	var cancelled: Dictionary = coordinator.cancel_logout("logout-tx-9")
	assert_true(cancelled.get("ok", false), "cancelling a known transaction succeeds: " + str(cancelled))
	var unknown: Dictionary = coordinator.cancel_logout("logout-tx-9")
	assert_false(unknown.get("ok", true), "the same id is unknown once cancelled")
	var never: Dictionary = coordinator.cancel_logout("never-existed")
	assert_false(never.get("ok", true), "cancelling a never-seen transaction fails")


func test_request_rejects_unexpected_member_sets_and_malformed_receipts() -> void:
	if not _exists(): return
	var rig := _configured()
	var coordinator: RefCounted = rig["coordinator"]
	var missing_key := _request("logout-tx-10", true)
	missing_key.erase("confirmed")
	assert_false(coordinator.request_logout(missing_key).get("ok", true), "a missing member must reject")
	var extra_key := _request("logout-tx-11", true)
	extra_key["unexpected"] = 1
	assert_false(coordinator.request_logout(extra_key).get("ok", true), "an extra member must reject")
	var wrong_purpose := _request("logout-tx-12", true)
	wrong_purpose["transaction_issuer_receipt"]["purpose"] = "run_id"
	assert_false(coordinator.request_logout(wrong_purpose).get("ok", true), "a wrong receipt purpose must reject")
	var token_mismatch := _request("logout-tx-13", true)
	token_mismatch["transaction_issuer_receipt"]["token"] = "some-other-token"
	assert_false(coordinator.request_logout(token_mismatch).get("ok", true), "a token/id mismatch must reject")
	var receipt_shape := _request("logout-tx-14", true)
	(receipt_shape["transaction_issuer_receipt"] as Dictionary).erase("counter")
	assert_false(coordinator.request_logout(receipt_shape).get("ok", true), "an incomplete receipt must reject")


func test_numbered_slots_are_never_touched_by_a_stub_that_would_fail_loudly() -> void:
	# Structural guard, not a real slot double: the frozen contract names only save_for_logout as
	# the durable seam (amendment SS9.2: "numbered slots are never called"). A save_manager stub that
	# has NO slot methods at all still satisfies configure() and a full logout flow, proving nothing
	# in LogoutCoordinator's own code path reaches for save_latest_to_slot/save_slot.
	if not _exists(): return
	var coordinator: RefCounted = _coordinator()
	var slotless_save_manager := FakeSaveManager.new()
	assert_false(slotless_save_manager.has_method("save_latest_to_slot"))
	assert_false(slotless_save_manager.has_method("save_slot"))
	var configured: Dictionary = coordinator.configure(slotless_save_manager, FakeRoutePort.new(), FakeStableBoardPort.new())
	assert_true(configured.get("ok", false))
	var result: Dictionary = coordinator.request_logout(_request("logout-tx-15", true))
	assert_true(result.get("ok", false), str(result))
