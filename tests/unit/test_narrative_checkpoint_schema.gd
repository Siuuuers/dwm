extends "res://addons/gut/test.gd"

# RED-first via dynamic load so a missing production script fails by assertion, not parse error
# (dwm-p2r.8, Plan-05 Task 2 Step 2.1/2.2).

const SCHEMA_PATH := "res://scripts/narrative/NarrativeCheckpointSchema.gd"
const FINGERPRINT := "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

var _schema: GDScript


func before_all() -> void:
	if ResourceLoader.exists(SCHEMA_PATH, "Script"):
		_schema = load(SCHEMA_PATH)


func _record() -> Dictionary:
	# Synthetic linear list: choice(0) -> effect(1) -> variable(2) -> text(3).
	return {
		"id": "T",
		"content_fingerprint": FINGERPRINT,
		"events": [
			{"event_id": "T@0:choice", "event_index": 0, "event_kind": "choice", "semantic_id": "T.choice.1", "post_event_id": "T@1:effect_transaction", "post_event_index": 1},
			{"event_id": "T@1:effect_transaction", "event_index": 1, "event_kind": "effect_transaction", "semantic_id": "T.effect.tx", "post_event_id": "T@2:variable_transaction", "post_event_index": 2},
			{"event_id": "T@2:variable_transaction", "event_index": 2, "event_kind": "variable_transaction", "semantic_id": "T.variable.tx", "post_event_id": "T@3:text", "post_event_index": 3},
			{"event_id": "T@3:text", "event_index": 3, "event_kind": "text", "semantic_id": "T.line.1", "post_event_id": null, "post_event_index": null},
		],
	}


func _null_event() -> Dictionary:
	return {"event_id": null, "event_index": null, "event_kind": null, "semantic_id": null}


func _evt(index: int) -> Dictionary:
	var event: Dictionary = _record()["events"][index]
	return {"event_id": event["event_id"], "event_index": event["event_index"], "event_kind": event["event_kind"], "semantic_id": event["semantic_id"]}


func _post(position: String, fields: Dictionary) -> Dictionary:
	var out := {"position": position}
	out.merge(fields)
	return out


func test_schema_script_exists() -> void:
	assert_true(ResourceLoader.exists(SCHEMA_PATH, "Script"), "missing %s" % SCHEMA_PATH)


func test_effect_boundary_builds_and_validates() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "effect_transaction", "semantic_id": "T.effect.tx", "transaction_id": "run:effect:1"}
	var built: Dictionary = _schema.build(_record(), boundary, _evt(1), _post("before_event", _evt(2)), null, false)
	assert_true(built.get("ok", false), str(built))
	assert_true(_schema.validate(built["value"], _record()).get("ok", false), "round-trip validate")


func test_line_boundary_uses_revealed_event() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "line", "semantic_id": "T.line.1", "transaction_id": ""}
	var built: Dictionary = _schema.build(_record(), boundary, _evt(3), _post("revealed_event", _evt(3)), "T.line.1", false)
	assert_true(built.get("ok", false), str(built))


func test_choice_boundary_uses_before_event() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "choice", "semantic_id": "T.choice.1", "transaction_id": "run:choice:1"}
	var built: Dictionary = _schema.build(_record(), boundary, _evt(0), _post("before_event", _evt(1)), null, false)
	assert_true(built.get("ok", false), str(built))


func test_timeline_start_stages_first_event() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "timeline_start", "semantic_id": null, "transaction_id": ""}
	var built: Dictionary = _schema.build(_record(), boundary, _null_event(), _post("before_event", _evt(0)), null, false)
	assert_true(built.get("ok", false), str(built))


func test_timeline_complete_is_terminal() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "timeline_complete", "semantic_id": null, "transaction_id": ""}
	var built: Dictionary = _schema.build(_record(), boundary, _null_event(), _post("timeline_complete", _null_event()), "T.line.1", true)
	assert_true(built.get("ok", false), str(built))


func test_scene_transition_is_external_route() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "scene_transition", "semantic_id": "T.transition.1", "transaction_id": "run:transition:1"}
	var built: Dictionary = _schema.build(_record(), boundary, _null_event(), _post("external_route", _null_event()), "T.line.1", false)
	assert_true(built.get("ok", false), str(built))


func test_reject_wrong_fingerprint() -> void:
	if _schema == null:
		return
	var checkpoint := {
		"schema_version": 1, "timeline_id": "T", "content_fingerprint": "sha256:deadbeef",
		"last_committed_line_id": null, "boundary": {"kind": "effect_transaction", "semantic_id": "T.effect.tx", "transaction_id": "run:effect:1"},
		"event": _evt(1), "post_event": _post("before_event", _evt(2)), "timeline_completed": false,
	}
	assert_false(_schema.validate(checkpoint, _record()).get("ok", false), "wrong fingerprint must reject")


func test_reject_illegal_successor() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "effect_transaction", "semantic_id": "T.effect.tx", "transaction_id": "run:effect:1"}
	# effect(1)'s legal successor is variable(2), not text(3).
	var built: Dictionary = _schema.build(_record(), boundary, _evt(1), _post("before_event", _evt(3)), null, false)
	assert_false(built.get("ok", false), "illegal successor must reject")


func test_reject_timeline_start_with_semantic_id() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "timeline_start", "semantic_id": "nope", "transaction_id": ""}
	var built: Dictionary = _schema.build(_record(), boundary, _null_event(), _post("before_event", _evt(0)), null, false)
	assert_false(built.get("ok", false), "timeline_start must have null semantic_id")


func test_reject_line_with_transaction_id() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "line", "semantic_id": "T.line.1", "transaction_id": "nope"}
	var built: Dictionary = _schema.build(_record(), boundary, _evt(3), _post("revealed_event", _evt(3)), null, false)
	assert_false(built.get("ok", false), "line must have empty transaction_id")


func test_reject_unregistered_event() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "effect_transaction", "semantic_id": "X", "transaction_id": "run:effect:1"}
	var bogus := {"event_id": "T@9:effect_transaction", "event_index": 9, "event_kind": "effect_transaction", "semantic_id": "X"}
	var built: Dictionary = _schema.build(_record(), boundary, bogus, _post("before_event", _evt(2)), null, false)
	assert_false(built.get("ok", false), "unregistered event must reject")


func test_reject_event_kind_mismatch() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "variable_transaction", "semantic_id": "T.effect.tx", "transaction_id": "run:v:1"}
	var lie := {"event_id": "T@1:effect_transaction", "event_index": 1, "event_kind": "variable_transaction", "semantic_id": "T.effect.tx"}
	var built: Dictionary = _schema.build(_record(), boundary, lie, _post("before_event", _evt(2)), null, false)
	assert_false(built.get("ok", false), "event_kind mismatch must reject")


func test_reject_timeline_completed_flag_on_nonterminal() -> void:
	if _schema == null:
		return
	var boundary := {"kind": "effect_transaction", "semantic_id": "T.effect.tx", "transaction_id": "run:effect:1"}
	var built: Dictionary = _schema.build(_record(), boundary, _evt(1), _post("before_event", _evt(2)), null, true)
	assert_false(built.get("ok", false), "timeline_completed must match a timeline_complete boundary")
