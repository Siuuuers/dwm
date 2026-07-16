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
	# Queue finished (day already advanced by the state method if the flag was set).
	if gs.has_method("clear_schedule_without_refund"):
		gs.clear_schedule_without_refund()
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


func get_current_scene_id() -> String:
	return _current_scene_id
