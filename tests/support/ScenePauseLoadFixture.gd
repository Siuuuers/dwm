extends "res://tests/support/SceneFirstRevealConnectedFixture.gd"
## Real Pause/Backup, input/audio, native Text, Run/Profile/Save and router owners.
## TEST-authored scene content and empty configured host remain explicit; this is
## connected integration, not shipped panel or rendered journey acceptance.
const INPUT_OWNER := preload("res://autoload/InputManager.gd")
const AUDIO_OWNER := preload("res://autoload/AudioManager.gd")
const LOCALIZATION_OWNER := preload("res://autoload/LocalizationManager.gd")
const AUDIO_PARTICIPANT := preload("res://scripts/application/restore/AudioRestoreParticipant.gd")
class RefuseNextWrite extends ProfileWriteRefusal:
	var armed := false
	var refusal_count := 0
	var refused_path := ""
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if armed and path.ends_with(".next"):
			armed = false
			refusal_count += 1
			refused_path = path
			return {"ok": false, "code": &"TEST.pause_load_write_refused", "message": path}
		return super.write_bytes(path, bytes)

var input_owner: Node
var audio_owner: Node
var localization_owner: Node
var pause: Node
var write_fault: RefuseNextWrite
var pause_closed_count := 0
var input_backup: Dictionary = {}
var pending_observation: Dictionary = {}
var diagnostic_phase := "unstarted"
var default_style_before: Dictionary = {}
func default_style_projection() -> Dictionary:
	var key := "dialogic/layout/default_style"
	return {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}

static func _scalar_fields(value: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in value:
		var item: Variant = value[key]
		if typeof(item) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NIL]:
			result[str(key)] = item
		elif item is Dictionary:
			result[str(key) + "_keys"] = item.keys()
	return result

static func _transient_state(owner: Object) -> Dictionary:
	var result := {}
	if not is_instance_valid(owner): return {"valid": false}
	for property: Dictionary in owner.get_property_list():
		var key: String = str(property.name)
		if not (key.begins_with("_scene_") or key.begins_with("_pause") or key.begins_with("_restore") \
			or key in ["_activity_phase", "_caption_restore_queued", "_caption_restore_frontier", "_caption_seek_frontier",
				"paused", "current_state", "current_event_idx"]): continue
		var value: Variant = owner.get(key)
		if value is Dictionary: result[key] = _scalar_fields(value)
		elif typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]: result[key] = value
	return result

func diagnostic_state() -> Dictionary:
	var result := {"fixture_phase": diagnostic_phase, "ready_count": ready_count,
		"route_confirmations": route_confirmations.size(), "narrative_confirmations": narrative_confirmations.size(),
		"pause_closed_count": pause_closed_count}
	if is_instance_valid(pause):
		result["pause"] = {"loading": pause._loading, "pending": pause._pending_scene_load,
			"state": pause.coordinator.get_state().value.state}
	if is_instance_valid(manager):
		result["save_activation"] = _scalar_fields(manager._scene_restore_activation)
		result["save_failure"] = _scalar_fields(manager._scene_restore_activation.get("failure", {}))
	result["router"] = _transient_state(router)
	result["bridge"] = _transient_state(bridge)
	result["adapter"] = _transient_state(adapter)
	result["native"] = _transient_state(runtime)
	return result

func setup_pause(scene_tree: SceneTree) -> Dictionary:
	default_style_before = default_style_projection()
	diagnostic_phase = "parent_setup"
	var checked: Dictionary = await setup_connected(scene_tree)
	if not checked.get("ok", false): return checked
	for action: StringName in InputMap.get_actions():
		input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true)}
	input_owner = INPUT_OWNER.new()
	audio_owner = AUDIO_OWNER.new()
	localization_owner = LOCALIZATION_OWNER.new()
	_replace_owner("InputManager", input_owner)
	_replace_owner("AudioManager", audio_owner)
	_replace_owner("LocalizationManager", localization_owner)
	checked = input_owner.initialize(profile)
	if checked.get("ok", false): checked = input_owner.configure_mutation_gate(gate)
	if checked.get("ok", false): checked = audio_owner.initialize(profile)
	if checked.get("ok", false): checked = audio_owner.configure_mutation_gate(gate)
	if checked.get("ok", false): checked = localization_owner.initialize(profile)
	if not checked.get("ok", false): return checked
	participants.audio = AUDIO_PARTICIPANT.new(audio_owner)
	checked = manager.configure_scene_restore_participants(participants)
	if not checked.get("ok", false): return checked
	checked = router.configure_mutation_gate(gate)
	if not checked.get("ok", false): return checked
	# Remove the inherited manual style. Initial admission and selected Load must
	# obtain their actual witnessed layout from the production Bridge owner.
	var inherited_layout: Node = runtime.Styles.get_layout_node()
	if is_instance_valid(inherited_layout):
		diagnostic_phase = "retire_inherited_layout"
		inherited_layout.queue_free()
		# setup_restart resumes from this layout's ready signal; its emitter is
		# still locked until that callback unwinds. Await actual retirement.
		for frame: int in 4:
			await tree.process_frame
			if not is_instance_valid(inherited_layout): break
		if is_instance_valid(inherited_layout):
			return {"ok": false, "code": &"TEST.pause_inherited_style_not_retired"}
	if runtime.Styles.has_active_layout_node():
		return {"ok": false, "code": &"TEST.pause_inherited_style_still_active"}
	checked = router.configure_pause_services({"game_state": game, "saves": manager,
		"bridge": bridge, "input": input_owner, "audio": audio_owner, "gate": gate,
		"profile": profile, "localization": localization_owner,
		"settings_services": {"tts": null, "window": null,
			"profile_reset_admission": func() -> bool: return false}})
	if not checked.get("ok", false): return checked
	pause = router._production_pause
	if pause._find_caption(tree.root) != null:
		return {"ok": false, "code": &"TEST.pause_caption_survived_setup"}
	if default_style_projection() != default_style_before:
		return {"ok": false, "code": &"TEST.pause_default_style_changed"}
	pause.coordinator.pause_closed.connect(func() -> void: pause_closed_count += 1)
	write_fault = RefuseNextWrite.new()
	files = write_fault
	storage._file_ops = write_fault
	diagnostic_phase = "setup_complete"
	return {"ok": true}

func audio_context() -> Dictionary:
	return audio_owner.get_semantic_audio_context()

func start(nonce: Variant = null) -> Dictionary:
	return manager.start_scene_new_run("target_b", {"audio_context": audio_context(),
		"content_version": 1, "route_id": "scene"}, nonce)

func start_text() -> Dictionary:
	diagnostic_phase = "start_scene"
	var started: Dictionary = start()
	if started.get("code") != &"scene_activation_pending": return started
	diagnostic_phase = "await_initial_activation"
	var activated: Dictionary = await await_activation()
	if not activated.get("ok", false): return activated
	return manager.save_latest_to_slot(1)

func settle_load() -> Dictionary:
	for frame: int in 240:
		if not pause._loading and pause.coordinator.get_state().value.state == &"Active":
			return {"ok": true}
		if not manager._scene_restore_activation.get("failure", {}).is_empty():
			return manager._scene_restore_activation.failure.duplicate(true)
		await tree.process_frame
	return {"ok": false, "code": &"TEST.pause_load_timeout", "pause": pause.coordinator.get_state()}

func observe_pending_load() -> void:
	for frame: int in 240:
		if not is_instance_valid(pause): return
		var operation_id: String = pause._pending_scene_load
		if not operation_id.is_empty():
			pending_observation = {"operation_id": operation_id, "tree_paused": tree.paused,
				"input_state": input_owner.get_state().value.state,
				"ready_count": ready_count, "closed_count": pause_closed_count,
				"foreign_retry": manager.retry_scene_activation("TEST.foreign_scene_restore")}
			return
		if ready_count > 0: return
		await tree.process_frame

func close_restart() -> void:
	if tree == null: return
	tree.paused = false
	if is_instance_valid(pause): pause.free()
	pause = null
	await super.close_restart()
	var audio_runtime: Node = audio_owner._playback_port._root if is_instance_valid(audio_owner) \
		and audio_owner._playback_port != null else null
	for owner: Node in [input_owner, audio_owner, localization_owner]:
		if is_instance_valid(owner): owner.free()
	if is_instance_valid(audio_runtime): audio_runtime.free()
	for name: String in ["InputManager", "AudioManager", "LocalizationManager"]:
		if not original_owners.has(name): continue
		var original: Node = original_owners[name].node
		if is_instance_valid(original) and original.get_parent() == null:
			tree.root.add_child(original)
			tree.root.move_child(original, mini(original_owners[name].index, tree.root.get_child_count() - 1))
	if not input_backup.is_empty():
		for action: StringName in InputMap.get_actions():
			if not input_backup.has(action): InputMap.erase_action(action)
		for action: StringName in input_backup:
			if not InputMap.has_action(action): InputMap.add_action(action, input_backup[action].deadzone)
			InputMap.action_set_deadzone(action, input_backup[action].deadzone)
			InputMap.action_erase_events(action)
			for event: InputEvent in input_backup[action].events: InputMap.action_add_event(action, event)
