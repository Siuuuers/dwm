extends Node
## Transient production composition of the existing Pause, suspension and session-exit owners.
## No Pause token is saved; exact live scene/session and native reading frontier own admission.
const COORDINATOR := preload("res://scripts/application/lifecycle/ApplicationLifecycleCoordinator.gd")
const SURFACE := preload("res://scenes/overlay/PauseSurface.tscn")
const EXIT := preload("res://scripts/application/desktop/SessionExitCoordinator.gd")
const BACKUP := preload("res://scenes/apps/BackupApp.tscn")
const BACKUP_PORT := preload("res://scripts/application/lifecycle/PauseBackupPresentationPort.gd")
const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const PRELUDE := preload("res://scripts/ui/Day7PreludeSurface.gd")

## Idle desktop/challenge sources have no narrative to suspend. A real reading source
## delegates to the bridge's exact retained runtime; foreign activity is never accepted as idle.
class NarrativeSuspension extends RefCounted:
	var bridge: Object
	var held: Dictionary = {}
	var live := false
	var restored_handle: Dictionary = {}
	var restoring_idle := false
	func begin_suspend(handle: Dictionary) -> Dictionary:
		if not held.is_empty(): return {"ok": false, "code": &"narrative_suspended"}
		live = bridge.has_active_playback()
		if live:
			var result: Dictionary = bridge.begin_suspend(handle)
			# A failed begin may retain physical custody, so retain the same handle for compensation.
			var state: Dictionary = bridge.get_state()
			if not state.get("ok", false) or state.value.state != &"Active": held = handle.duplicate(true)
			return result
		held = handle.duplicate(true)
		return {"ok": true}
	func get_state() -> Dictionary:
		if held.is_empty(): return {"ok": true, "value": {"state": &"Active"}}
		if live: return bridge.get_state()
		if bridge.has_active_playback(): return {"ok": false, "code": &"pause_source_changed"}
		return {"ok": true, "value": {"state": &"Suspended"}}
	func resume(handle: Dictionary) -> Dictionary:
		if handle != held: return {"ok": false, "code": &"invalid_suspension_handle"}
		var result: Dictionary = bridge.resume(handle) if live else get_state()
		if result.get("ok", false): held.clear()
		return result
	func begin_restore(handle: Dictionary) -> Dictionary:
		if handle.is_empty() or handle != held: return {"ok": false, "code": &"invalid_suspension_handle"}
		if not live:
			if not get_state().get("ok", false): return {"ok": false, "code": &"pause_source_changed"}
			restoring_idle = true
			return {"ok": true}
		return bridge.begin_pause_restore(handle)
	func cancel_restore(handle: Dictionary) -> Dictionary:
		if handle.is_empty() or handle != held: return {"ok": false, "code": &"invalid_suspension_handle"}
		if not live:
			if not restoring_idle: return {"ok": false, "code": &"invalid_suspension_handle"}
			restoring_idle = false
			return {"ok": true}
		return bridge.cancel_pause_restore(handle)
	func complete_restore(handle: Dictionary) -> Dictionary:
		if handle.is_empty(): return {"ok": false, "code": &"invalid_suspension_handle"}
		if held.is_empty() and handle == restored_handle: return {"ok": true}
		if handle != held: return {"ok": false, "code": &"invalid_suspension_handle"}
		if not live:
			if not restoring_idle: return {"ok": false, "code": &"invalid_suspension_handle"}
			restored_handle = handle.duplicate(true)
			held.clear()
			restoring_idle = false
			return {"ok": true}
		var completed: Dictionary = await bridge.complete_pause_restore(handle)
		if completed.get("ok", false):
			restored_handle = handle.duplicate(true)
			held.clear()
		return completed
	func retire_suspended_source(handle: Dictionary) -> Dictionary:
		if handle != held: return {"ok": false, "code": &"invalid_suspension_handle"}
		var result: Dictionary = bridge.retire_suspended_source(handle) if live else get_state()
		if result.get("ok", false): held.clear()
		return result

var _services: Dictionary = {}
var _router: Object
var coordinator: Node
var surface: Control
var last_result: Dictionary = {}
var _layer: CanvasLayer
var _scene: Control
var _caption: Node
var _caption_anchor: Dictionary = {}
var _prelude: Node
var _prelude_anchor: Dictionary = {}
var _view_anchor: Dictionary = {}
var _captured_source: Dictionary = {}
var _handle: Dictionary = {}
var _exit: RefCounted
var _backup_port: RefCounted
var _busy := false
var _loading := false
var _witnessed_load := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(services: Dictionary, router: Object) -> Dictionary:
	if not _services.is_empty(): return _failure(&"pause_already_configured")
	for key: String in ["game_state", "saves", "bridge", "input", "audio", "gate", "profile", "localization"]:
		if not is_instance_valid(services.get(key)): return _failure(&"invalid_pause_dependency")
	_services = services.duplicate()
	_router = router
	var narrative := NarrativeSuspension.new()
	narrative.bridge = _services.bridge
	coordinator = COORDINATOR.new()
	add_child(coordinator)
	var configured: Dictionary = coordinator.configure(self, narrative, _services.input, _services.audio, _services.gate, router)
	if not configured.get("ok", false): return configured
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	surface = SURFACE.instantiate()
	_layer.add_child(surface)
	surface.continue_requested.connect(request_continue)
	surface.return_confirmed.connect(request_return)
	_services.profile.preference_changed.connect(_preferences_changed)
	_services.localization.locale_changed.connect(_locale_changed)
	return {"ok": true}

## Called after GUI and the current scene's input. Text fields, open sheets and consumed
## Back actions retain priority. The same press cannot both open and close Pause.
func _unhandled_input(event: InputEvent) -> void:
	if _busy or not _handle.is_empty() or not event.is_action_pressed(&"ui_cancel", false): return
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return
	if not _services.input.is_source_input_admitted(): return
	var source := capture_pause_source()
	if not source.get("ok", false): return
	get_viewport().set_input_as_handled()
	request_pause()

func request_pause() -> Dictionary:
	if _busy or not _handle.is_empty(): return _failure(&"pause_busy")
	var source := capture_pause_source()
	if not source.get("ok", false): return source
	_scene = get_tree().current_scene as Control
	_captured_source = source.value.duplicate(true)
	var bound: Dictionary = coordinator.bind_source(_scene, self)
	if not bound.get("ok", false): return bound
	_exit = EXIT.new()
	var configured: Dictionary = _exit.configure(_services.game_state, _services.saves, _router,
		_services.gate, Callable(self, "_unused_save_capture"))
	if not configured.get("ok", false): return configured
	configured = _exit.configure_retirement(Callable(self, "_retire_pause"))
	if not configured.get("ok", false): return configured
	_busy = true
	last_result = await coordinator.request_pause(&"production_pause")
	_busy = false
	if not last_result.get("ok", false):
		# Preserve the coordinator's actual recovery handle; a failed partial acquisition
		# cannot leave a silently frozen game with no Retry/Continue surface.
		var state: Dictionary = coordinator.get_state()
		if state.value.state != &"Recovery": return last_result
		_handle = state.value.handle.duplicate(true)
	else:
		_handle = last_result.value.duplicate(true)
	_ensure_hosts()
	_refresh_presentation()
	surface.open_surface()
	return last_result

func request_continue() -> Dictionary:
	if _busy or _handle.is_empty(): return _failure(&"pause_busy")
	_busy = true
	surface.set_interactive(false)
	last_result = await coordinator.request_resume(_handle)
	_busy = false
	if last_result.get("ok", false):
		surface.close_surface()
		_handle.clear()
		_captured_source.clear()
	surface.set_interactive(true)
	return last_result

func request_return() -> Dictionary:
	if _busy or _handle.is_empty() or _exit == null: return _failure(&"pause_busy")
	var state: Dictionary = coordinator.get_state()
	if state.value.state == &"Suspended":
		var admitted: Dictionary = coordinator.request_lifecycle_command(&"pause.return")
		if not admitted.get("ok", false): return admitted
	elif state.value.state not in [&"Retiring", &"Retired"]:
		return _failure(&"pause_busy")
	_busy = true
	surface.set_interactive(false)
	last_result = _exit.return_to_title(false)
	_busy = false
	if last_result.get("ok", false):
		last_result = coordinator.finish_retirement(_handle)
		if last_result.get("ok", false):
			surface.close_surface()
			_handle.clear()
			_captured_source.clear()
	elif coordinator.get_state().value.state in [&"Retiring", &"Retired"]:
		surface.retain_return_retry()
	surface.set_interactive(true)
	return last_result

func _retire_pause() -> Dictionary:
	return coordinator.retire_suspended_source(_handle)

func _unused_save_capture() -> Dictionary:
	return _failure(&"pause_save_unavailable")

## The bridge proves a native Text or transient artwork frontier; the current scene and
## full live-session handle prove its run custody. Artwork never fabricates a text witness.
func capture_pause_source() -> Dictionary:
	if _services.is_empty() or not is_inside_tree(): return _failure(&"pause_source_unavailable")
	var scene := get_tree().current_scene as Control
	if scene == null or scene.is_queued_for_deletion(): return _failure(&"pause_source_unavailable")
	var route: String = _router.get_current_route_id()
	if route not in ["main", "dating", "hospital", "ending"]: return _failure(&"pause_source_unavailable")
	var guarded: Dictionary = _services.gate.guard_external(&"universal_pause")
	if not guarded.get("ok", false): return guarded
	var session: Dictionary = _services.game_state.capture_live_session()
	if not session.get("ok", false): return session
	var admitted: Dictionary = _services.game_state.validate_live_session(session.value)
	if not admitted.get("ok", false): return admitted
	var source := capture_scene_projection(scene)
	if source.is_empty(): return _failure(&"pause_source_unavailable")
	source["session"] = session.value.duplicate(true)
	var prelude := _capture_day7_projection()
	if not prelude.get("ok", false): return prelude
	if not prelude.value.is_empty() and route != "main": return _failure(&"pause_source_changed")
	source["day7_prelude"] = prelude.value
	if _services.bridge.has_active_playback():
		if not source.day7_prelude.is_empty(): return _failure(&"pause_frontier_unavailable")
		var frontier: Dictionary = _services.bridge.capture_pause_frontier(source.timeline_id if route == "hospital" else "")
		if not frontier.get("ok", false): return frontier
		source["frontier"] = frontier.value.duplicate(true)
	elif route in ["hospital", "ending"]:
		return _failure(&"pause_frontier_unavailable")
	else:
		source["frontier"] = {}
	return {"ok": true, "value": source}

func _capture_day7_projection() -> Dictionary:
	var projection := {}
	for candidate: Node in get_tree().get_nodes_in_group("day7_prelude_surface"):
		if candidate.get_script() != PRELUDE or candidate.is_queued_for_deletion() \
				or candidate.get_viewport() != get_viewport(): continue
		var current: Dictionary = candidate.get_pause_projection()
		if current.is_empty():
			if candidate.visible: return _failure(&"pause_frontier_unavailable")
			continue
		if not projection.is_empty(): return _failure(&"pause_source_changed")
		projection = current
	return {"ok": true, "value": projection}

## Independent scene projection is reread at every acquisition/resume boundary.
func capture_scene_projection(scene: Object) -> Dictionary:
	if not is_instance_valid(scene) or scene != get_tree().current_scene: return {}
	var route: String = _router.get_current_route_id()
	var paths := {"main": "res://scenes/main/MainGameScene.tscn", "dating": "res://scenes/dating/DatingScene.tscn",
		"hospital": "res://scenes/hospital/HospitalScene.tscn", "ending": "res://scenes/ending/EndingScene.tscn"}
	if scene.scene_file_path != paths.get(route, ""): return {}
	var command: Dictionary = scene.get_presentation_projection() if scene.has_method("get_presentation_projection") else {}
	if route in ["dating", "hospital"] and command.is_empty(): return {}
	return {"route_id": route, "scene_id": scene.get_instance_id(), "command": command,
		"timeline_id": str(command.get("timeline_id", "")), "physical_token": str(command.get("physical_token", "")),
		"command_sha256": str(command.get("command_sha256", "")), "completion_transaction_id": str(command.get("completion_transaction_id", ""))}

func capture_pause_view(source: Dictionary) -> Dictionary:
	if source != _captured_source or not is_instance_valid(_scene): return _failure(&"pause_source_changed")
	var focused := get_viewport().gui_get_focus_owner()
	_view_anchor = {"scene_id": _scene.get_instance_id(), "source": source.duplicate(true), "visible": _scene.visible,
		"focus_id": focused.get_instance_id() if focused != null and (_scene == focused or _scene.is_ancestor_of(focused)) else 0}
	_caption = null
	_caption_anchor.clear()
	_prelude = null
	_prelude_anchor.clear()
	var prelude_projection: Dictionary = source.get("day7_prelude", {})
	if not prelude_projection.is_empty():
		_prelude = instance_from_id(int(prelude_projection.view_id))
		if not is_instance_valid(_prelude) or _prelude.get_script() != PRELUDE \
				or _prelude.get_pause_projection() != prelude_projection: return _failure(&"pause_source_changed")
		var captured: Dictionary = _prelude.capture_pause_view(source)
		if not captured.get("ok", false): return captured
		_prelude_anchor = captured.value.duplicate(true)
	if not source.frontier.is_empty():
		var bridge: Object = _services.get("bridge")
		_caption = bridge.get_art_hold_view() if bridge != null and bridge.has_method("get_art_hold_view") else null
		if _caption == null: _caption = _find_caption(get_tree().root)
		if _caption == null: return _failure(&"pause_view_unavailable")
		var captured: Dictionary = _caption.capture_pause_view(source)
		if not captured.get("ok", false): return captured
		_caption_anchor = captured.value.duplicate(true)
	return {"ok": true, "value": _view_anchor.duplicate(true)}

func cover_pause_view(anchor: Dictionary) -> bool:
	if not _valid_anchor(anchor): return false
	if is_instance_valid(_caption) and not _caption.cover_pause_view(_caption_anchor): return false
	if not _prelude_anchor.is_empty() and (not is_instance_valid(_prelude) \
			or not _prelude.cover_pause_view(_prelude_anchor)): return false
	_scene.hide()
	return true

func restore_pause_view(anchor: Dictionary) -> bool:
	if not _valid_anchor(anchor): return false
	if not _prelude_anchor.is_empty() and (not is_instance_valid(_prelude) \
			or not _prelude.restore_pause_view(_prelude_anchor)): return false
	_scene.visible = bool(anchor.visible)
	if is_instance_valid(_caption) and not _caption.restore_pause_view(_caption_anchor): return false
	var focused: Object = instance_from_id(int(anchor.focus_id)) if int(anchor.focus_id) != 0 else null
	if focused is Control and focused.is_visible_in_tree() and focused.get_focus_mode_with_override() != Control.FOCUS_NONE:
		focused.grab_focus()
	return true

func _valid_anchor(anchor: Dictionary) -> bool:
	return anchor == _view_anchor and is_instance_valid(_scene) and _scene == get_tree().current_scene \
		and not _scene.is_queued_for_deletion() and _scene.get_instance_id() == anchor.get("scene_id")

func _find_caption(node: Node) -> Node:
	if node.get_script() == CAPTION:
		var canvas: Control = node.get("canvas")
		if is_instance_valid(canvas) and canvas.is_visible_in_tree(): return node
	for child: Node in node.get_children():
		var found: Node = _find_caption(child)
		if found != null: return found
	return null

func _ensure_hosts() -> void:
	if _backup_port != null: return
	_backup_port = BACKUP_PORT.new()
	_backup_port.configure_pause(_services.saves, self)
	var backup: Control = BACKUP.instantiate()
	surface.set_host(&"backup", backup)
	backup.configure_backup(_backup_port, _services.localization, _services.profile)
	var settings: Control = SETTINGS.instantiate()
	var settings_services: Dictionary = _services.get("settings_services", {}).duplicate()
	settings_services.merge({"profile": _services.profile, "localization": _services.localization,
		"input": _services.input, "audio": _services.audio, "volume": _services.audio}, true)
	settings.get_node("SettingsContent").configure_services(settings_services)
	surface.set_host(&"settings", settings)

func _backup_admission() -> Dictionary:
	if _loading:
		var current := capture_pause_source()
		return {"ok": true} if current.get("ok", false) and current.value == _captured_source else _failure(&"pause_source_changed")
	if _handle.is_empty() or _busy: return _failure(&"pause_backup_unavailable")
	return coordinator.request_lifecycle_command(&"pause.backup")

func can_save_backup() -> bool:
	var capture: Callable = _services.get("backup_capture", Callable())
	var route: String = str(_captured_source.get("route_id", ""))
	return capture.is_valid() and route in ["main", "dating"] \
		and (route == "main" or is_instance_valid(_services.get("dating_presentation"))) \
		and _captured_source.get("frontier", {}).is_empty() \
		and _backup_admission().get("ok", false)


## Save keeps the exact source suspended. The configured provider captures live canonical
## owners; the retained Dating port proves that these bytes belong to this scene's command.
func capture_backup_checkpoint_inputs() -> Dictionary:
	if not can_save_backup(): return _failure(&"pause_save_unavailable")
	if _captured_source.route_id == "main":
		var captured: Variant = (_services.backup_capture as Callable).call()
		if not captured is Dictionary or not captured.get("ok", false):
			return captured if captured is Dictionary else _failure(&"invalid_backup_capture")
		var inputs: Dictionary = captured.get("value", {})
		if inputs.get("route_id") != "main" or inputs.get("dialogic_checkpoint") != {} \
				or inputs.get("snapshot_input", {}).get("lifecycle", {}).get("run_id") != _captured_source.session.get("run_id") \
				or not _backup_admission().get("ok", false):
			return _failure(&"pause_source_changed")
		return {"ok": true, "value": inputs.duplicate(true)}
	var command: Dictionary = _captured_source.command
	var physical: Dictionary = _services.dating_presentation.pull_physical(command)
	if not physical.get("ok", false): return physical
	if physical.value.get("phase") not in ["pre_challenge", "preparing", "challenge",
			"cleared_awaiting_terminal_choice", "post_challenge"]:
		return _failure(&"pause_save_unavailable")
	var prior: Dictionary = _services.game_state.capture_dating_challenge_state()
	if not prior.get("ok", false): return prior
	var record: Dictionary = prior.value
	for key: String in ["physical_token", "command_sha256", "completion_transaction_id", "context"]:
		if not command.has(key) or record.get(key) != command[key]:
			return _failure(&"pause_source_changed")
	var captured: Variant = (_services.backup_capture as Callable).call()
	if not captured is Dictionary or not captured.get("ok", false):
		return captured if captured is Dictionary else _failure(&"invalid_backup_capture")
	var inputs: Dictionary = captured.get("value", {})
	var snapshot: Dictionary = inputs.get("snapshot_input", {})
	var saved_record: Dictionary = snapshot.get("gameplay", {}).get("route_context", {}).get("active_dating_challenge", {})
	var current: Dictionary = _services.game_state.capture_dating_challenge_state()
	if inputs.get("route_id") != "dating" or inputs.get("dialogic_checkpoint") != {} \
			or snapshot.get("lifecycle", {}).get("run_id") != _captured_source.session.get("run_id") \
			or saved_record != record or not current.get("ok", false) or current.value != record \
			or not _backup_admission().get("ok", false):
		return _failure(&"pause_source_changed")
	return {"ok": true, "value": inputs.duplicate(true)}


func can_load_backup() -> bool:
	return not _captured_source.is_empty() and _backup_admission().get("ok", false)


func capture_restore_destination_session() -> Dictionary:
	var captured: Dictionary = _services.game_state.capture_live_session()
	if not captured.get("ok", false): return captured
	# SaveManager still holds its restore lease while the handoff publishes. The
	# retained session bytes must stay exact; admission was proved before that lease.
	if not _services.gate.is_internal_owner_active(&"restore"):
		var valid: Dictionary = _services.game_state.validate_live_session(captured.value)
		if not valid.get("ok", false): return valid
	return captured

func release_for_backup_load() -> Dictionary:
	if not can_load_backup(): return _failure(&"pause_load_unavailable")
	_busy = true
	surface.set_interactive(false)
	# The Day 7 overlay has no Dialogic frontier, but is still a held reading view.
	_witnessed_load = not _captured_source.get("frontier", {}).is_empty() \
		or not _captured_source.get("day7_prelude", {}).is_empty()
	var released: Dictionary = coordinator.begin_restore_handoff(_handle) if _witnessed_load \
		else await coordinator.request_resume(_handle)
	if not released.get("ok", false):
		_witnessed_load = false
		_busy = false
		surface.set_interactive(true)
		return released
	_loading = true
	return {"ok": true}

func finish_backup_load(result: Dictionary) -> Dictionary:
	if not _loading: return _failure(&"pause_load_unavailable")
	if _witnessed_load: return await _finish_witnessed_load(result)
	_loading = false
	var current_session: Dictionary = _services.game_state.capture_live_session()
	var changed: bool = current_session.get("ok", false) and current_session.value != _captured_source.session
	if result.get("ok", false) and changed:
		# The normal restore owns the new route/session. No old view or audio is restored.
		surface.close_surface()
		_handle.clear()
		_captured_source.clear()
		_busy = false
		surface.set_interactive(true)
		return result
	var source := capture_pause_source()
	if not source.get("ok", false) or source.value != _captured_source:
		# An indeterminate/foreign restore cannot be advertised as a reversible failure.
		# Keep its owner recovery boundary inert rather than resuming either session.
		get_tree().paused = true
		last_result = {"ok": false, "code": &"pause_load_recovery_required", "recovery_required": true, "details": {"cause": result}}
		return last_result
	var rebound: Dictionary = coordinator.bind_source(_scene, self)
	if not rebound.get("ok", false): return rebound
	var reacquired: Dictionary = await coordinator.request_pause(&"production_pause")
	if reacquired.get("ok", false):
		_handle = reacquired.value.duplicate(true)
	else:
		var state: Dictionary = coordinator.get_state()
		if state.value.state == &"Recovery": _handle = state.value.handle.duplicate(true)
		else:
			# Source is unchanged but reacquisition failed cleanly: the exact original view
			# is still active. Close the stale overlay; the failed Load made no new session.
			surface.close_surface()
			_handle.clear()
			_captured_source.clear()
	_busy = false
	surface.set_interactive(true)
	return result if not result.get("ok", false) else _failure(&"pause_load_not_activated")

func _finish_witnessed_load(result: Dictionary) -> Dictionary:
	var destination: Dictionary = capture_restore_destination_session()
	var changed: bool = destination.get("ok", false) and destination.value != _captured_source.session
	if result.get("ok", false) and changed:
		var completed: Dictionary = await coordinator.complete_restore_handoff(_handle)
		if completed.get("ok", false):
			surface.close_surface()
			_handle.clear()
			_captured_source.clear()
			_loading = false
			_witnessed_load = false
			_busy = false
			surface.set_interactive(true)
			return result
		last_result = {"ok": false, "code": &"pause_load_recovery_required", "recovery_required": true,
			"details": {"cause": completed}}
		return last_result
	var source := capture_pause_source()
	if not changed and source.get("ok", false) and source.value == _captured_source:
		var cancelled: Dictionary = coordinator.cancel_restore_handoff(_handle)
		if cancelled.get("ok", false):
			_loading = false
			_witnessed_load = false
			_busy = false
			surface.set_interactive(true)
			return result if not result.get("ok", false) else _failure(&"pause_load_not_activated")
	last_result = {"ok": false, "code": &"pause_load_recovery_required", "recovery_required": true,
		"details": {"cause": result}}
	return last_result


func _refresh_presentation() -> void:
	if surface == null: return
	var locale: String = str(_services.profile.get_preference("preferences.language.primary_locale_id", "en")).replace("_", "-")
	var percent: int = int(_services.profile.get_preference("preferences.accessibility.text_size", 100))
	var config: Dictionary = _services.game_state.get_run_configuration()
	var palette := "Midnight" if config.get("value", {}).get("dark_mode", false) else "AfterHours"
	surface.configure_presentation(locale, percent, palette,
		bool(_services.profile.get_preference("preferences.accessibility.high_contrast", false)),
		str(_services.profile.get_preference("preferences.accessibility.colour_differentiation", "standard")),
		bool(_services.profile.get_preference("preferences.accessibility.large_targets", false)),
		int(_services.game_state.day))
	var copy := {}
	for key: String in surface.COPY_KEYS:
		copy[key] = _services.localization.t("ui.pause." + key)
	surface.configure_copy(copy)

func _preferences_changed(_path: Variant, _value: Variant) -> void: _refresh_presentation()
func _locale_changed(_locale: Variant) -> void: _refresh_presentation()
static func _failure(code: StringName) -> Dictionary: return {"ok": false, "code": code}
