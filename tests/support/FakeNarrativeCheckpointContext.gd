extends RefCounted
## Test double for the real SaveManagerCheckpointPort plus the six narrative-checkpoint providers
## (dwm-p2r.8, Plan-05 Task 2 Step 2.2). Hosts the fake real-port surface and all six provider
## methods on one object; records call order and exposes controllable results for rejection tests.

var calls: Array = []
var provider_order: Array = []

var next_sequence := 7
var prepare_ok := true
var commit_ok := true
var rollback_ok := true

var snapshot_input_value: Dictionary = {"lifecycle": {"run_id": "run-1"}}
var route_id_value: Variant = "main"
var active_app_id_value: Variant = null
var audio_context_value: Dictionary = {}
var content_version_value: Variant = 1

var narrative_ok := true
var narrative_checkpoint_value: Dictionary = {}


# --- fake real SaveManagerCheckpointPort surface ---

func preview_checkpoint_id(run_id: String) -> Dictionary:
	calls.append("preview:%s" % run_id)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": "%s:%d" % [run_id, next_sequence]}, "receipt": {}}


func capture() -> Dictionary:
	calls.append("capture")
	return {"ok": true, "code": &"ok", "value": {"backup": {"journal_backup": {"run_id": "run-1"}}}}


func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary:
	calls.append("prepare:%s:%s" % [String(checkpoint_kind), str(disk_write)])
	if not prepare_ok:
		return {"ok": false, "code": &"prepare_failed", "message": ""}
	var run_id := str(((checkpoint_inputs.get("snapshot_input", {}) as Dictionary).get("lifecycle", {}) as Dictionary).get("run_id", ""))
	var checkpoint_id := "%s:%d" % [run_id, next_sequence]
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {"journal_candidate": {"checkpoint_id": checkpoint_id}, "checkpoint_id": checkpoint_id},
		"checkpoint_id": checkpoint_id,
	}}


func commit(candidate: Dictionary) -> Dictionary:
	calls.append("commit")
	if not commit_ok:
		return {"ok": false, "code": &"commit_failed", "message": ""}
	return {"ok": true, "code": &"ok", "value": {"checkpoint_id": str(candidate.get("checkpoint_id", ""))}}


func rollback(backup: Dictionary) -> Dictionary:
	calls.append("rollback")
	if not rollback_ok:
		return {"ok": false, "code": &"APPLICATION_FATAL", "message": "rollback failed"}
	return {"ok": true, "code": &"ok"}


# --- the six providers, all on this object ---

func provider_callables() -> Dictionary:
	return {
		"snapshot_input": Callable(self, "_provide_snapshot_input"),
		"narrative_checkpoint": Callable(self, "_provide_narrative_checkpoint"),
		"route_id": Callable(self, "_provide_route_id"),
		"active_app_id": Callable(self, "_provide_active_app_id"),
		"audio_context": Callable(self, "_provide_audio_context"),
		"content_version": Callable(self, "_provide_content_version"),
	}


func _provide_snapshot_input() -> Dictionary:
	provider_order.append("snapshot_input")
	return snapshot_input_value.duplicate(true)


func _provide_narrative_checkpoint(transaction_id: String, source_id: String, checkpoint_kind: StringName) -> Dictionary:
	provider_order.append("narrative_checkpoint")
	if not narrative_ok:
		return {"ok": false, "code": &"no_active_transaction", "message": ""}
	return {"ok": true, "code": &"ok", "value": {"narrative_checkpoint": narrative_checkpoint_value.duplicate(true)}}


func _provide_route_id() -> Variant:
	provider_order.append("route_id")
	return route_id_value


func _provide_active_app_id() -> Variant:
	provider_order.append("active_app_id")
	return active_app_id_value


func _provide_audio_context() -> Dictionary:
	provider_order.append("audio_context")
	return audio_context_value.duplicate(true)


func _provide_content_version() -> Variant:
	provider_order.append("content_version")
	return content_version_value
