extends "res://addons/gut/test.gd"

# RED-first via dynamic load (dwm-p2r.8, Plan-05 Task 2 Step 2.2). Covers configuration identity,
# the atomic boundary owner (provider order, boundary-id derivation, duplicate/conflict, commit
# failure rollback), the pure preview proxy, and the low-level transaction seam.

const PORT_PATH := "res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd"
const CONTEXT := preload("res://tests/support/FakeNarrativeCheckpointContext.gd")

var _port_script: GDScript


func before_all() -> void:
	if ResourceLoader.exists(PORT_PATH, "Script"):
		_port_script = load(PORT_PATH)


func _configured() -> Array:
	# returns [port, context]
	var context: RefCounted = CONTEXT.new()
	var port: Object = _port_script.new()
	var result: Dictionary = port.configure(context, context.provider_callables())
	assert_true(result.get("ok", false), str(result))
	return [port, context]


func _start_checkpoint() -> Dictionary:
	return {"timeline_id": "T", "boundary": {"transaction_id": ""}, "event": {"event_id": null}}


func test_port_script_exists() -> void:
	assert_true(ResourceLoader.exists(PORT_PATH, "Script"), "missing %s" % PORT_PATH)


func test_configure_first_returns_instance_ids() -> void:
	if _port_script == null:
		return
	var context: RefCounted = CONTEXT.new()
	var port: Object = _port_script.new()
	var result: Dictionary = port.configure(context, context.provider_callables())
	assert_true(result.get("ok", false), str(result))
	assert_false(result["value"]["already_configured"], "first config not already_configured")
	assert_eq(int(result["value"]["port_instance_id"]), port.get_instance_id(), "port instance id retained")
	assert_eq(int(result["value"]["checkpoint_port_instance_id"]), context.get_instance_id(), "real port id")


func test_configure_same_is_idempotent() -> void:
	if _port_script == null:
		return
	var context: RefCounted = CONTEXT.new()
	var port: Object = _port_script.new()
	port.configure(context, context.provider_callables())
	var again: Dictionary = port.configure(context, context.provider_callables())
	assert_true(again.get("ok", false), str(again))
	assert_true(again["value"]["already_configured"], "second identical config is already_configured")


func test_configure_rejects_replacement_with_different_port() -> void:
	if _port_script == null:
		return
	var context: RefCounted = CONTEXT.new()
	var other: RefCounted = CONTEXT.new()
	var port: Object = _port_script.new()
	port.configure(context, context.provider_callables())
	var replaced: Dictionary = port.configure(other, other.provider_callables())
	assert_false(replaced.get("ok", false), "replacement rejected")
	assert_eq(str(replaced.get("code")), "narrative_checkpoint_port_already_configured")


func test_configure_rejects_missing_provider_key() -> void:
	if _port_script == null:
		return
	var context: RefCounted = CONTEXT.new()
	var providers: Dictionary = context.provider_callables()
	providers.erase("route_id")
	assert_false(_port_script.new().configure(context, providers).get("ok", false), "missing key rejected")


func test_configure_rejects_extra_provider_key() -> void:
	if _port_script == null:
		return
	var context: RefCounted = CONTEXT.new()
	var providers: Dictionary = context.provider_callables()
	providers["extra"] = Callable(context, "_provide_route_id")
	assert_false(_port_script.new().configure(context, providers).get("ok", false), "extra key rejected")


func test_configure_rejects_non_callable_provider() -> void:
	if _port_script == null:
		return
	var context: RefCounted = CONTEXT.new()
	var providers: Dictionary = context.provider_callables()
	providers["route_id"] = "not a callable"
	assert_false(_port_script.new().configure(context, providers).get("ok", false), "non-callable rejected")


func test_configure_rejects_missing_real_port_method() -> void:
	if _port_script == null:
		return
	var context: RefCounted = CONTEXT.new()
	# a bare object missing the real-port methods
	var bad := RefCounted.new()
	assert_false(_port_script.new().configure(bad, context.provider_callables()).get("ok", false), "bad port rejected")


func test_commit_current_boundary_success_and_receipt() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var checkpoint := _start_checkpoint()
	var request := {"boundary_id": "timeline:T:start", "checkpoint_kind": &"timeline_start", "narrative_checkpoint": checkpoint}
	var result: Dictionary = port.commit_current_boundary(request)
	assert_true(result.get("ok", false), str(result))
	assert_false(result["value"]["duplicate"], "fresh commit is not a duplicate")
	assert_eq(result["receipt"]["boundary_id"], "timeline:T:start")
	assert_eq(str(result["receipt"]["checkpoint_kind"]), "timeline_start")
	assert_true(str(result["receipt"]["narrative_fingerprint"]).length() == 64, "sha256 hex fingerprint")


func test_commit_current_boundary_calls_providers_in_order() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var context: RefCounted = pair[1]
	port.commit_current_boundary({"boundary_id": "timeline:T:start", "checkpoint_kind": &"timeline_start", "narrative_checkpoint": _start_checkpoint()})
	assert_eq(context.provider_order, ["snapshot_input", "route_id", "active_app_id", "audio_context", "content_version"], "exact provider order, no narrative provider")


func test_commit_current_boundary_rejects_boundary_id_mismatch() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var result: Dictionary = port.commit_current_boundary({"boundary_id": "timeline:WRONG:start", "checkpoint_kind": &"timeline_start", "narrative_checkpoint": _start_checkpoint()})
	assert_false(result.get("ok", false), "boundary_id must be derived and matched")
	assert_eq(str(result.get("code")), "boundary_id_mismatch")


func test_commit_current_boundary_duplicate_returns_stored_receipt() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var context: RefCounted = pair[1]
	var request := {"boundary_id": "timeline:T:start", "checkpoint_kind": &"timeline_start", "narrative_checkpoint": _start_checkpoint()}
	var first: Dictionary = port.commit_current_boundary(request)
	context.provider_order.clear()
	var second: Dictionary = port.commit_current_boundary(request)
	assert_true(second.get("ok", false), str(second))
	assert_true(second["value"]["duplicate"], "identical boundary is a duplicate")
	assert_eq(second["value"]["checkpoint_id"], first["value"]["checkpoint_id"], "same checkpoint id")
	assert_eq(context.provider_order, [], "duplicate consumes no providers")


func test_commit_current_boundary_conflict_on_different_bytes() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	port.commit_current_boundary({"boundary_id": "timeline:T:start", "checkpoint_kind": &"timeline_start", "narrative_checkpoint": _start_checkpoint()})
	# same boundary id, different checkpoint bytes
	var altered := _start_checkpoint()
	altered["last_committed_line_id"] = "T.line.9"
	var conflict: Dictionary = port.commit_current_boundary({"boundary_id": "timeline:T:start", "checkpoint_kind": &"timeline_start", "narrative_checkpoint": altered})
	assert_false(conflict.get("ok", false), "conflicting bytes rejected")
	assert_eq(str(conflict.get("code")), "duplicate_transaction_conflict")


func test_commit_current_boundary_rolls_back_on_commit_failure() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var context: RefCounted = pair[1]
	context.commit_ok = false
	var result: Dictionary = port.commit_current_boundary({"boundary_id": "timeline:T:start", "checkpoint_kind": &"timeline_start", "narrative_checkpoint": _start_checkpoint()})
	assert_false(result.get("ok", false), "commit failure surfaces")
	assert_true("rollback" in context.calls, "real port rollback called on failed commit")


func test_line_boundary_derives_event_id() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var checkpoint := {"timeline_id": "T", "boundary": {"transaction_id": ""}, "event": {"event_id": "T@3:text"}}
	var result: Dictionary = port.commit_current_boundary({"boundary_id": "T@3:text", "checkpoint_kind": &"line", "narrative_checkpoint": checkpoint})
	assert_true(result.get("ok", false), str(result))
	assert_eq(result["receipt"]["boundary_id"], "T@3:text")


func test_preview_checkpoint_id_proxies() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var result: Dictionary = port.preview_checkpoint_id("run-1")
	assert_true(result.get("ok", false), str(result))
	assert_eq(result["value"], {"checkpoint_id": "run-1:7"}, "pure exact proxy")


func test_low_level_prepare_commit_roundtrip() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var context: RefCounted = pair[1]
	context.narrative_checkpoint_value = {"timeline_id": "T", "boundary": {"transaction_id": "run-1:effect:1"}}
	var prepared: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "effect_source", &"effect_transaction", "run-1:7")
	assert_true(prepared.get("ok", false), str(prepared))
	var committed: Dictionary = port.commit(&"game_state_narrative_transaction", prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(committed["value"]["checkpoint_id"], "run-1:7")


func test_low_level_rejects_foreign_owner() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var result: Dictionary = port.prepare_candidate(&"someone_else", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "s", &"effect_transaction", "run-1:7")
	assert_false(result.get("ok", false), "foreign owner rejected")


# ---- dwm-p2r.8 (Plan-05 Task 3): low-level transaction seam hardening ----

func test_narrative_provider_refusal_blocks_prepare() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var context: RefCounted = pair[1]
	context.narrative_ok = false
	var prepared: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "src", &"effect_transaction", "run-1:7")
	assert_false(prepared.get("ok", false), "no validated transaction checkpoint means no candidate")
	assert_false("prepare:effect_transaction" in str(context.calls), "the real port is never reached")


func test_prepare_rejects_checkpoint_id_mismatch() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var prepared: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "src", &"effect_transaction", "run-1:999")
	assert_false(prepared.get("ok", false), "a previewed id mismatch rejects")
	assert_eq(str(prepared.get("code")), "checkpoint_id_mismatch")


func test_commit_rejects_modified_candidate() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var prepared: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "src", &"effect_transaction", "run-1:7")
	var tampered: Dictionary = (prepared["value"]["candidate"] as Dictionary).duplicate(true)
	tampered["checkpoint_id"] = "run-1:8"
	var committed: Dictionary = port.commit(&"game_state_narrative_transaction", tampered)
	assert_false(committed.get("ok", false), "byte-modified candidates reject")
	assert_eq(str(committed.get("code")), "candidate_altered")


func test_commit_rejects_foreign_owner() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var prepared: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "src", &"effect_transaction", "run-1:7")
	assert_false(port.commit(&"someone_else", prepared["value"]["candidate"]).get("ok", false), "foreign owner cannot commit")


func test_only_one_candidate_may_exist_at_a_time() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "src", &"effect_transaction", "run-1:7")
	var second: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:2", "src", &"effect_transaction", "run-1:7")
	assert_false(second.get("ok", false), "a second in-flight candidate rejects")
	assert_eq(str(second.get("code")), "transaction_in_progress")


func test_rollback_releases_the_owner_for_a_later_transaction() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:1", "src", &"effect_transaction", "run-1:7")
	assert_true(port.rollback(&"game_state_narrative_transaction", {"journal_backup": {"run_id": "run-1"}}).get("ok", false), "rollback ok")
	var again: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", {"lifecycle": {"run_id": "run-1"}}, "run-1:effect:2", "src", &"effect_transaction", "run-1:7")
	assert_true(again.get("ok", false), "the owner is free after rollback")


func test_prepare_result_is_recursively_detached() -> void:
	if _port_script == null:
		return
	var pair := _configured()
	var port: Object = pair[0]
	var snapshot_input := {"lifecycle": {"run_id": "run-1"}}
	var prepared: Dictionary = port.prepare_candidate(&"game_state_narrative_transaction", snapshot_input, "run-1:effect:1", "src", &"effect_transaction", "run-1:7")
	(prepared["value"]["candidate"] as Dictionary)["injected"] = true
	snapshot_input["lifecycle"]["run_id"] = "mutated"
	var committed: Dictionary = port.commit(&"game_state_narrative_transaction", prepared["value"]["candidate"])
	assert_false(committed.get("ok", false), "an externally mutated candidate cannot commit")
