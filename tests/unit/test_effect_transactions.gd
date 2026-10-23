extends "res://addons/gut/test.gd"
# Atomic, idempotent effect/variable transactions (dwm-p2r.8, Plan-05 Task 3 Step 3.1).
# RED-first: assertions are guarded by has_method so a missing API fails by assertion, never by a
# parse error, and no test mutates state before its intended assertion.

func before_each() -> void:
	GameState.reset_game()


func _has(method: String) -> bool:
	return GameState.has_method(method)


func _ids(values: Array) -> Array[String]:
	var out: Array[String] = []
	for v in values:
		out.append(str(v))
	return out


func _snapshot() -> Dictionary:
	return GameState.to_save_dict()


func test_variable_transaction_api_is_required() -> void:
	assert_true(_has("commit_variable_transaction"), "GameState.commit_variable_transaction is required")


func test_effect_transaction_api_is_required() -> void:
	assert_true(_has("commit_effect_transaction"), "GameState.commit_effect_transaction is required")


func test_resolver_exposes_pure_resolution() -> void:
	assert_true(EffectResolver.has_method("resolve_effects"), "EffectResolver.resolve_effects is required")
	if not EffectResolver.has_method("resolve_effects"):
		return
	var before := _snapshot()
	var resolved: Dictionary = EffectResolver.resolve_effects(["pressure:+2"])
	assert_true(resolved.get("ok", false), str(resolved))
	assert_eq(_snapshot(), before, "resolution must not mutate GameState")


func test_resolver_rejects_unknown_id_without_mutation() -> void:
	if not EffectResolver.has_method("resolve_effects"):
		return
	var before := _snapshot()
	assert_false(EffectResolver.resolve_effects(["pressure:+2", "not:a:real:effect"]).get("ok", false), "unknown id rejects")
	assert_eq(_snapshot(), before, "rejected resolution mutates nothing")


func test_effect_transaction_is_atomic_on_invalid_member() -> void:
	if not _has("commit_effect_transaction"):
		return
	var before := _snapshot()
	var result: Dictionary = GameState.commit_effect_transaction("run:effect:1", _ids(["pressure:+2", "money:+5", "not:a:real:effect"]), "test_source")
	assert_false(result.get("ok", false), "a batch containing an invalid effect must fail")
	assert_eq(_snapshot(), before, "no partial application: the whole snapshot is unchanged")


func test_effect_transaction_applies_once_and_is_idempotent() -> void:
	if not _has("commit_effect_transaction"):
		return
	var first: Dictionary = GameState.commit_effect_transaction("run:effect:2", _ids(["pressure:+2", "money:+5"]), "test_source")
	assert_true(first.get("ok", false), str(first))
	var after_first := _snapshot()
	assert_eq(GameState.get_stat("pressure"), 5, "pressure applied once")
	assert_eq(GameState.money, 5, "money applied once")
	var second: Dictionary = GameState.commit_effect_transaction("run:effect:2", _ids(["pressure:+2", "money:+5"]), "test_source")
	assert_true(second.get("ok", false), str(second))
	assert_eq(_snapshot(), after_first, "a duplicate transaction id applies nothing further")
	assert_eq(second.get("receipt"), first.get("receipt"), "the duplicate returns the stored receipt")


func test_effect_transaction_conflict_on_same_id_different_payload() -> void:
	if not _has("commit_effect_transaction"):
		return
	GameState.commit_effect_transaction("run:effect:3", _ids(["pressure:+2"]), "test_source")
	var after := _snapshot()
	var conflict: Dictionary = GameState.commit_effect_transaction("run:effect:3", _ids(["money:+5"]), "test_source")
	assert_false(conflict.get("ok", false), "same id with different bytes conflicts")
	assert_eq(str(conflict.get("code")), "duplicate_transaction_conflict")
	assert_eq(_snapshot(), after, "a conflict mutates nothing")


func test_variable_transaction_commits_registered_value_once() -> void:
	if not _has("commit_variable_transaction"):
		return
	var result: Dictionary = GameState.commit_variable_transaction("run:variable:1", "unregistered.variable", 1, "test_source")
	# No production narrative variables are registered yet, so an unknown id must reject cleanly.
	assert_false(result.get("ok", false), "unregistered variable id rejects")
	assert_eq(str(result.get("code")), "unknown_variable_id")


func test_variable_transaction_rejects_without_mutation() -> void:
	if not _has("commit_variable_transaction"):
		return
	var before := _snapshot()
	GameState.commit_variable_transaction("run:variable:2", "unregistered.variable", 1, "test_source")
	assert_eq(_snapshot(), before, "invalid variable input leaves state unchanged")


func test_command_receipts_are_present_and_detached() -> void:
	if not _has("capture_run_snapshot_input"):
		return
	var captured: Dictionary = GameState.capture_run_snapshot_input()
	assert_true(captured.has("command_receipts"), "snapshot input carries a mandatory command_receipts map")
	if not captured.has("command_receipts"):
		return
	assert_eq(typeof(captured["command_receipts"]), TYPE_DICTIONARY, "command_receipts is a Dictionary")
	captured["command_receipts"]["injected"] = true
	assert_false(GameState.capture_run_snapshot_input()["command_receipts"].has("injected"), "capture returns a detached copy")


func test_applied_transaction_id_sets_start_empty() -> void:
	if not _has("capture_run_snapshot_input"):
		return
	var captured: Dictionary = GameState.capture_run_snapshot_input()
	assert_eq(captured.get("applied_effect_transaction_ids"), [], "effect id set starts empty")
	assert_eq(captured.get("applied_variable_transaction_ids"), [], "variable id set starts empty")


func test_game_state_never_touches_the_gallery_ledger() -> void:
	# Task 3's ledger is disjoint from ProfileManager.gallery_transaction_receipts (.7 owns that).
	var source := FileAccess.get_file_as_string("res://autoload/GameState.gd")
	assert_false("gallery_transaction_receipts" in source, "GameState must never read or write the ending-gallery ledger")
