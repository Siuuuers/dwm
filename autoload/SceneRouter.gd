extends Node
# SceneRouter (CONTRACTS §4): ONLY changes scenes and stores safe route context through
# GameState. It never applies stat/economy/affection/schedule/condition/dating rules.
# GameState never auto-routes; the caller performs the scene change here.

const _SCENE_PATHS := {
	"menu": "res://scenes/menu/MenuScene.tscn",
	"gallery": "res://scenes/menu/GalleryScene.tscn",
	"opening": "res://scenes/opening/OpeningScene.tscn",
	"main": "res://scenes/main/MainGameScene.tscn",
	"ending": "res://scenes/ending/EndingScene.tscn",
	"hospital": "res://scenes/hospital/HospitalScene.tscn",
	"dating": "res://scenes/dating/DatingScene.tscn",
}

var _current_scene_id: String = ""
var _mutation_gate: Object = null


## Common mutation-gate seam (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md
## Task 7). Matches the frozen contract the other seven final targets use.
func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return {"ok": false, "code": &"invalid_mutation_gate", "message": "gate contract incomplete"}
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method):
			return {"ok": false, "code": &"invalid_mutation_gate", "message": "missing method"}
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id():
		return {"ok": false, "code": &"mutation_gate_already_configured", "message": ""}
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}


## Ending port injection (dwm-p2r.8, Plan-05 Task 2). SceneRouter stores the exact instances and
## configures an off-tree EndingScene before it is added to the tree, so no ending scene can reach
## _ready() unconfigured.
const _ENDING_STATE_PORT_METHODS := ["request_next_ending_command", "complete_ending_playback_stage"]
const _ENDING_PLAYBACK_PORT_METHODS := ["start_ending_id", "is_ready"]

var _ending_state_port: Object = null
var _ending_playback_port: Object = null


func configure_ending_ports(state_port: Object, playback_port: Object) -> Dictionary:
	if state_port == null or not _has_ending_methods(state_port, _ENDING_STATE_PORT_METHODS):
		return {"ok": false, "code": &"invalid_state_port", "message": "state port is missing required methods"}
	if playback_port == null or not _has_ending_methods(playback_port, _ENDING_PLAYBACK_PORT_METHODS):
		return {"ok": false, "code": &"invalid_playback_port", "message": "playback port is missing required methods"}
	if _ending_state_port != null:
		if _ending_state_port.get_instance_id() != state_port.get_instance_id() \
				or _ending_playback_port.get_instance_id() != playback_port.get_instance_id():
			return {"ok": false, "code": &"ending_ports_already_configured", "message": ""}
		return {"ok": true, "code": &"ok", "value": {
			"state_port_instance_id": state_port.get_instance_id(),
			"playback_port_instance_id": playback_port.get_instance_id(),
			"already_configured": true}, "receipt": {}}
	_ending_state_port = state_port
	_ending_playback_port = playback_port
	return {"ok": true, "code": &"ok", "value": {
		"state_port_instance_id": state_port.get_instance_id(),
		"playback_port_instance_id": playback_port.get_instance_id(),
		"already_configured": false}, "receipt": {}}


func is_ending_ports_configured() -> bool:
	return _ending_state_port != null and _ending_playback_port != null


## ---- Schedule-Done presentation port injection (Plan 01 Task 8, dwm-p2r.14) ----
##
## SceneRouter retains the EXACT Hospital/Dating ports Bootstrap composed and injects them into each
## off-tree scene before `add_child()`, so no presentation scene can reach `_ready()` unconfigured.
## Routing carries no Schedule law of its own: this router no longer clears or advances Schedule
## state, and it cannot route an unconfigured Dating presentation.

const _PRESENTATION_PORT_METHODS: Array[String] = ["begin", "complete", "is_ready"]

var _hospital_presentation_port: Object = null
var _dating_presentation_port: Object = null


## Accepts the exact production instances once. Identical replay is idempotent and a replacement in
## either position is refused, mirroring the ending-port seam above.
func configure_schedule_presentation_ports(hospital_port: Object, dating_port: Object) -> Dictionary:
	if hospital_port == null or not _has_ending_methods(hospital_port, _PRESENTATION_PORT_METHODS):
		return {"ok": false, "code": &"invalid_hospital_presentation_port", "message": ""}
	if dating_port == null or not _has_ending_methods(dating_port, _PRESENTATION_PORT_METHODS):
		return {"ok": false, "code": &"invalid_dating_presentation_port", "message": ""}
	if _hospital_presentation_port != null or _dating_presentation_port != null:
		if _hospital_presentation_port != hospital_port \
				or _dating_presentation_port != dating_port:
			return {"ok": false, "code": &"schedule_presentation_ports_already_configured",
				"message": ""}
		return _presentation_port_result(true)
	_hospital_presentation_port = hospital_port
	_dating_presentation_port = dating_port
	return _presentation_port_result(false)


func is_schedule_presentation_ports_configured() -> bool:
	return _hospital_presentation_port != null and _dating_presentation_port != null


## Routes ONE committed D1-6 presentation intent, injecting the exact retained port into the scene
## while it is still off-tree.
##
## A route whose port is not ready is refused rather than shown: an unconfigured Dating presentation
## must fail closed, not open an improvised board. Nothing here mutates Schedule state, advances a
## day, or selects an ending, and Day-7 provenance can never reach this method because Plan 01 makes
## no Day-7 presentation intent at all.
func route_presentation(route_id: String, presentation_command: Dictionary) -> Dictionary:
	if not is_schedule_presentation_ports_configured():
		return {"ok": false, "code": &"schedule_presentation_ports_unconfigured", "message": ""}
	if not _SCENE_PATHS.has(route_id) or not ["hospital", "dating"].has(route_id):
		return {"ok": false, "code": &"invalid_presentation_route", "message": route_id}
	if typeof(presentation_command) != TYPE_DICTIONARY or presentation_command.is_empty():
		return {"ok": false, "code": &"invalid_presentation_command", "message": ""}
	if str(presentation_command.get("route_id", "")) != route_id:
		return {"ok": false, "code": &"invalid_presentation_route", "message": route_id}
	var port: Object = _hospital_presentation_port if route_id == "hospital" \
		else _dating_presentation_port
	if not bool(port.call(&"is_ready")):
		# Phase 2R always lands here for `dating`: dwm-oyo.4 owns that owner.
		return {"ok": false, "code": &"presentation_port_not_ready", "message": route_id}
	var path: String = _SCENE_PATHS[route_id]
	if not ResourceLoader.exists(path):
		return {"ok": false, "code": &"presentation_scene_missing", "message": path}
	var packed: PackedScene = load(path)
	var scene: Node = packed.instantiate()
	if not scene.has_method("configure_presentation"):
		scene.queue_free()
		return {"ok": false, "code": &"presentation_scene_unconfigurable", "message": route_id}
	# OFF-TREE injection: the scene is configured before it can reach _ready() or take input.
	var configured: Dictionary = scene.call(&"configure_presentation", port,
		presentation_command.duplicate(true))
	if not configured.get("ok", false):
		scene.queue_free()
		return configured
	var tree := get_tree()
	if tree == null:
		scene.queue_free()
		return {"ok": false, "code": &"presentation_tree_unavailable", "message": ""}
	var current := tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if current != null and current != scene:
		current.queue_free()
	_current_scene_id = route_id
	return {"ok": true, "code": &"ok", "value": {
		"route_id": route_id,
		"port_instance_id": port.get_instance_id(),
		"scene_instance_id": scene.get_instance_id(),
	}, "receipt": {}}


func _presentation_port_result(already_configured: bool) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {
		"hospital_port_instance_id": _hospital_presentation_port.get_instance_id(),
		"dating_port_instance_id": _dating_presentation_port.get_instance_id(),
		"hospital_ready": bool(_hospital_presentation_port.call(&"is_ready")),
		"dating_ready": bool(_dating_presentation_port.call(&"is_ready")),
		"already_configured": already_configured,
	}, "receipt": {}}


## Zero-argument route provider for the narrative checkpoint adapter; always a registered id.
func get_current_route_id() -> String:
	return _current_scene_id if _current_scene_id != "" else "menu"


static func _has_ending_methods(target: Object, methods: Array) -> bool:
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true


func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func _change_to(scene_id: String) -> void:
	if not _SCENE_PATHS.has(scene_id):
		push_warning("SceneRouter: unknown scene id '%s'." % scene_id)
		return
	var path: String = _SCENE_PATHS[scene_id]
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: scene path missing '%s' (deferred/placeholder)." % path)
		_current_scene_id = scene_id
		return
	_current_scene_id = scene_id
	var tree := get_tree()
	if tree != null:
		tree.change_scene_to_file(path)


func start_game_from_menu() -> void:
	var gs := _gs()
	if gs != null and gs.has_method("reset_game"):
		gs.reset_game()
	if gs != null and gs.day == 1 and not gs.opening_seen:
		goto_opening()
	else:
		goto_main()


func goto_menu() -> void:
	_change_to("menu")


func goto_opening() -> void:
	_change_to("opening")


func goto_main() -> void:
	_change_to("main")


func goto_ending() -> void:
	# Reads GameState.route_context["ending_id"]; EndingScene falls back to "alone" if empty/unknown.
	_change_to("ending")


func goto_hospital() -> void:
	_change_to("hospital")


func goto_dating_entries(entries: Array) -> void:
	# MUST populate pending date state via GameState.prepare_dating_entries, then show DatingScene.
	var gs := _gs()
	if gs != null and gs.has_method("prepare_dating_entries"):
		gs.prepare_dating_entries(entries)
	_change_to("dating")


func finish_current_dating_and_route() -> void:
	var gs := _gs()
	if gs == null:
		goto_main()
		return
	# advance_date_queue_or_day() is STATE-ONLY: advances the index, returns true while entries
	# remain; when none remain it advances the day ONLY IF pending_date_advance_day_after_finish.
	var more := false
	if gs.has_method("advance_date_queue_or_day"):
		more = gs.advance_date_queue_or_day()
	if more:
		_change_to("dating")
		return
	# Queue finished (day already advanced by the state method if the flag was set). The Schedule is
	# NOT cleared here: the day-end owner resets the committed aggregate, and routing adds no
	# Schedule law of its own (Plan 01 Task 5, dwm-p2r.13).
	# CONTRACTS §4 step 3: route to ending iff route_context["ending_id"] is set (non-empty);
	# otherwise return to main. The day-8 sentinel is not used here to decide routing.
	var ending_id := ""
	if gs != null:
		var rc: Variant = gs.get("route_context")
		if typeof(rc) == TYPE_DICTIONARY:
			ending_id = rc.get("ending_id", "")
	if ending_id != "":
		goto_ending()
	else:
		goto_main()


func goto_scene_id(scene_id: String, context: Dictionary = {}) -> void:
	var gs := _gs()
	if gs != null and not context.is_empty():
		# Store only safe context; SceneRouter never mutates gameplay rules.
		gs.route_context = context.duplicate(true)
	_change_to(scene_id)


## ---- Semantic route restore seams (dwm-p2r.5 Task 7) ----
## Restore suppresses ordinary route signals; apply reports the target scene's
## narrative layout ready via a route-ready token the narrative participant
## validates. Phase 2R scenes are placeholder, so readiness resolves synchronously.

var _route_restore_backup: Dictionary = {}
var _route_generation: int = 0
var _pending_restore_scene_id: String = ""


func prepare_route_restore(route_id: String, route_context: Dictionary) -> Dictionary:
	if route_id.is_empty():
		return {"ok": false, "code": &"invalid_route_id", "message": "route_id must be nonempty"}
	_route_generation += 1
	return {"ok": true, "code": &"ok", "value": {
		"route_id": route_id,
		"route_context": route_context.duplicate(true),
		"route_ready_token": {
			"route_id": route_id,
			"layout_id": route_id + "_layout",
			"generation": _route_generation,
		},
	}}


func capture_restore_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {"scene_id": _current_scene_id}}}


func apply_route_restore_silent(plan: Dictionary) -> Dictionary:
	var route_id := str(plan.get("route_id", ""))
	if route_id.is_empty() and typeof(plan.get("route_ready_token")) == TYPE_DICTIONARY:
		route_id = str((plan["route_ready_token"] as Dictionary).get("route_id", ""))
	if route_id.is_empty():
		return {"ok": false, "code": &"invalid_route_plan", "message": "route plan requires a route_id"}
	# Semantic apply: record the target route and safe context without changing the
	# live scene (finalize performs the navigation). Ordinary route signals stay silent.
	_pending_restore_scene_id = route_id
	var gs := _gs()
	if gs != null and typeof(plan.get("route_context")) == TYPE_DICTIONARY:
		gs.route_context = (plan["route_context"] as Dictionary).duplicate(true)
	var token: Variant = plan.get("route_ready_token", {
		"route_id": route_id, "layout_id": route_id + "_layout", "generation": _route_generation})
	return {"ok": true, "code": &"ok", "value": {"route_ready_token": token}}


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or not (source as Dictionary).has("scene_id"):
		return {"ok": false, "code": &"invalid_route_backup", "message": "route backup requires a scene_id"}
	_pending_restore_scene_id = ""
	_current_scene_id = str((source as Dictionary)["scene_id"])
	return {"ok": true, "code": &"ok"}


func finalize_restore() -> Dictionary:
	if _pending_restore_scene_id != "":
		_change_to(_pending_restore_scene_id)
		_pending_restore_scene_id = ""
	_route_restore_backup = {}
	return {"ok": true, "code": &"ok"}


func get_current_scene_id() -> String:
	return _current_scene_id
