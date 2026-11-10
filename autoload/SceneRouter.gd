extends Node

const _SCENE_PATHS := {
	"menu": "res://scenes/menu/MenuScene.tscn",
	"gallery": "res://scenes/menu/GalleryScene.tscn",
	"main": "res://scenes/main/MainGameScene.tscn",
	"ending": "res://scenes/ending/EndingScene.tscn",
}

var _current_scene_id: String = ""
var _mutation_gate: Object = null

var _route_custody_revision := 0
var _return_title_counter := 0
var _return_title_prepared: Dictionary = {}
var _return_title_published: Dictionary = {}
var _return_title_publishing := false

signal restore_publication_released()
signal scene_activation_confirmed(operation_id: String)
var _scene_host_path := ""
var _scene_activation: Dictionary = {}
var _scene_pause_restore_validator: Callable

func configure_scene_host(path: String) -> Dictionary:
	if not _scene_host_path.is_empty():
		return {"ok": true} if _scene_host_path == path else _startup_failure("scene_host_already_configured")
	if path.is_empty() or not ResourceLoader.load(path) is PackedScene:
		return _startup_failure("scene_host_unavailable")
	_scene_host_path = path
	return {"ok": true}

func begin_scene_publication_hold(operation_id: String) -> Dictionary:
	if operation_id.is_empty(): return _startup_failure("scene_activation_unavailable")
	var handle := {"scene_restore_operation_id": operation_id}
	if _restore_publication_handle == handle: return {"ok": true}
	if not _scene_pause_publication.is_empty():
		return {"ok": true} if _scene_pause_publication.operation_id == operation_id \
			and _scene_pause_publication.handle == _restore_publication_handle else _startup_failure("restore_publication_busy")
	if is_restore_publication_held():
		var current := get_tree().current_scene
		if _restore_publication_publishing or _restore_publication_published or current == null \
				or not _restore_publication_scene_id.is_empty() \
				or current.get_instance_id() != _restore_publication_source_id \
				or not _scene_pause_restore_validator.is_valid():
			return _startup_failure("restore_publication_busy")
		var retained := _restore_publication_handle.duplicate(true)
		var suspended: Dictionary = _scene_pause_restore_validator.call(retained)
		if not suspended.get("ok", false): return suspended
		if retained != _restore_publication_handle or get_tree().current_scene != current:
			return _startup_failure("stale_restore_publication_hold")
		_scene_pause_publication = {"operation_id": operation_id,
			"handle": _restore_publication_handle.duplicate(true), "acknowledged": false}
		return {"ok": true}
	if is_restore_publication_held() or _restore_publication_publishing:
		return _startup_failure("restore_publication_busy")
	_restore_publication_handle = handle
	_restore_publication_source_id = get_tree().current_scene.get_instance_id() if get_tree().current_scene != null else 0
	_restore_publication_scene_id = "scene"
	_restore_publication_published = false
	return {"ok": true}


func capture_scene_host_projection(scene: Object) -> Dictionary:
	if not is_instance_valid(scene) or not is_inside_tree() or scene != get_tree().current_scene \
			or _current_scene_id != "scene" or _scene_host_path.is_empty() \
			or scene.scene_file_path != _scene_host_path or not scene.is_node_ready() or scene.is_queued_for_deletion():
		return _startup_failure("scene_host_unavailable")
	return {"ok": true, "value": {"route_id": "scene", "scene_id": scene.get_instance_id()}}


func cancel_scene_publication_hold(operation_id: String) -> Dictionary:
	if _scene_pause_publication.is_empty():
		return cancel_restore_publication_hold({"scene_restore_operation_id": operation_id})
	if _scene_pause_publication.operation_id != operation_id or _scene_pause_publication.acknowledged \
			or _scene_pause_publication.handle != _restore_publication_handle \
			or get_tree().current_scene == null \
			or get_tree().current_scene.get_instance_id() != _restore_publication_source_id:
		return _startup_failure("stale_restore_publication_hold")
	_scene_pause_publication.clear()
	_restore_publication_scene_id = ""
	return {"ok": true}


func publish_scene_activation(operation_id: String) -> Dictionary:
	var checked := validate_scene_activation(operation_id)
	if not checked.get("ok", false): return checked
	if not _scene_pause_publication.is_empty():
		if _scene_pause_publication.operation_id != operation_id \
				or _scene_pause_publication.handle != _restore_publication_handle:
			return _startup_failure("stale_restore_publication_hold")
		_scene_pause_publication.acknowledged = true
		return {"ok": true}
	var handle := {"scene_restore_operation_id": operation_id}
	var published := publish_restore_publication_hold(handle)
	if not published.get("ok", false): return published
	return release_restore_publication_hold(handle)

func begin_scene_activation(operation_id: String) -> Dictionary:
	if operation_id.is_empty() or _pending_restore_scene_id not in ["scene", "ending"] \
			or (_pending_restore_scene_id == "scene" and _scene_host_path.is_empty()):
		return _startup_failure("scene_activation_unavailable")
	if not _scene_activation.is_empty():
		if _scene_activation.operation_id != operation_id:
			return _startup_failure("scene_activation_conflict")
		if _scene_activation.node_id != 0: return validate_scene_activation(operation_id)
		return {"ok": true, "value": {"pending": true}}
	var tree := get_tree()
	if tree == null or _return_title_publishing or _startup_publishing:
		return _startup_failure("scene_activation_unavailable")
	var target_path: String = _SCENE_PATHS.ending if _pending_restore_scene_id == "ending" else _scene_host_path
	var packed := ResourceLoader.load(target_path) as PackedScene
	if packed == null: return _startup_failure("scene_host_unavailable")
	_scene_activation = {"operation_id": operation_id, "generation": _route_generation,
		"path": target_path, "route_id": _pending_restore_scene_id, "node_id": 0, "revision": _route_custody_revision + 1}
	if _pending_restore_scene_id == "ending":
		var mounted := _change_to_ending(target_path)
		if not mounted.get("ok", false):
			_scene_activation.clear()
			return mounted
		_on_scene_activation_mounted()
		return validate_scene_activation(operation_id)
	if not tree.scene_changed.is_connected(_on_scene_activation_mounted):
		tree.scene_changed.connect(_on_scene_activation_mounted)
	var changed := tree.change_scene_to_packed(packed)
	if changed != OK:
		_scene_activation.clear()
		return _startup_failure("scene_change_failed")
	_route_custody_revision += 1
	_current_scene_id = "scene"
	return {"ok": true, "value": {"pending": true}}

func _on_scene_activation_mounted() -> void:
	if _scene_activation.is_empty() or _scene_activation.node_id != 0: return
	var tree := get_tree()
	if tree == null or tree.current_scene == null: return
	var mounted := tree.current_scene
	if _scene_activation.generation != _route_generation \
			or _scene_activation.revision != _route_custody_revision \
			or _current_scene_id != _scene_activation.route_id or mounted.scene_file_path != _scene_activation.path \
			or not mounted.is_node_ready(): return
	_scene_activation.node_id = mounted.get_instance_id()
	scene_activation_confirmed.emit(str(_scene_activation.operation_id))

func validate_scene_activation(operation_id: String) -> Dictionary:
	var tree := get_tree()
	if _scene_activation.is_empty() or _scene_activation.operation_id != operation_id \
			or _scene_activation.generation != _route_generation \
			or _scene_activation.revision != _route_custody_revision \
			or _current_scene_id != _scene_activation.route_id or tree == null or tree.current_scene == null \
			or tree.current_scene.get_instance_id() != _scene_activation.node_id \
			or tree.current_scene.scene_file_path != _scene_activation.path \
			or not tree.current_scene.is_node_ready():
		return _startup_failure("scene_activation_unproven")
	return {"ok": true, "value": {"pending": false}}

var _restore_publication_handle: Dictionary = {}
var _restore_publication_scene_id := ""
var _restore_publication_source_id := 0
var _restore_publication_publishing := false
var _restore_publication_published := false
var _scene_pause_publication: Dictionary = {}
var _production_pause: Node

func configure_pause_services(services: Dictionary) -> Dictionary:
	if is_instance_valid(_production_pause): return {"ok": true, "value": {"already_configured": true}}
	var host := preload("res://scripts/application/lifecycle/ProductionPauseController.gd").new()
	add_child(host)
	var configured: Dictionary = host.configure(services, self)
	if not configured.get("ok", false):
		host.queue_free()
		return configured
	_production_pause = host
	_scene_pause_restore_validator = Callable()
	var bridge: Object = services.get("bridge")
	if bridge != null and bridge.has_method("validate_scene_pause_restore_handle"):
		_scene_pause_restore_validator = Callable(bridge, "validate_scene_pause_restore_handle")
	return {"ok": true}

func capture_pause_backup_checkpoint_inputs() -> Dictionary:
	if not is_instance_valid(_production_pause):
		return {"ok": false, "code": &"pause_backup_unavailable"}
	return _production_pause.capture_backup_checkpoint_inputs()

func can_capture_pause_backup_checkpoint_inputs() -> bool:
	return is_instance_valid(_production_pause) and _production_pause.can_save_backup()


func can_open_witnessed_backup_load(caption: Node) -> bool:
	return is_instance_valid(_production_pause) \
		and _production_pause.can_open_witnessed_backup_load(caption)


func open_witnessed_backup_load(caption: Node) -> Dictionary:
	if not is_instance_valid(_production_pause):
		return {"ok": false, "code": &"pause_backup_unavailable"}
	return await _production_pause.open_witnessed_backup_load(caption)

func open_witnessed_quick_load(caption: Node) -> Dictionary:
	if not is_instance_valid(_production_pause): return {"ok": false, "code": &"pause_load_unavailable"}
	return await _production_pause.open_witnessed_quick_load(caption)


func can_open_witnessed_backup_save(caption: Node) -> bool:
	return is_instance_valid(_production_pause) \
		and _production_pause.can_open_witnessed_backup_save(caption)


func open_witnessed_backup_save(caption: Node) -> Dictionary:
	if not is_instance_valid(_production_pause):
		return {"ok": false, "code": &"pause_backup_unavailable"}
	return await _production_pause.open_witnessed_backup_save(caption)


func can_open_witnessed_history(caption: Node) -> bool:
	return is_instance_valid(_production_pause) and _production_pause.can_open_witnessed_history(caption)


func open_witnessed_history(caption: Node) -> Dictionary:
	if not is_instance_valid(_production_pause): return {"ok": false, "code": &"pause_history_unavailable"}
	return await _production_pause.open_witnessed_history(caption)


func is_witnessed_history_open(caption: Node) -> bool:
	return is_instance_valid(_production_pause) and _production_pause.is_witnessed_history_open(caption)


func close_witnessed_history(caption: Node) -> Dictionary:
	if not is_instance_valid(_production_pause): return {"ok": false, "code": &"pause_history_unavailable"}
	return await _production_pause.close_witnessed_history(caption)


func is_restore_publication_held() -> bool:
	return not _restore_publication_handle.is_empty()


func begin_restore_publication_hold(handle: Dictionary) -> Dictionary:
	if is_restore_publication_held() or _startup_hold_active or _return_title_publishing \
			or get_tree().current_scene == null or handle.is_empty():
		return _startup_failure("restore_publication_busy")
	_restore_publication_handle = handle.duplicate(true)
	_restore_publication_source_id = get_tree().current_scene.get_instance_id()
	_restore_publication_published = false
	_restore_publication_scene_id = ""
	return {"ok": true}


func cancel_restore_publication_hold(handle: Dictionary) -> Dictionary:
	if not _scene_pause_publication.is_empty(): return _startup_failure("restore_publication_busy")
	if handle.has("scene_restore_operation_id") and handle == _restore_publication_handle \
			and not _restore_publication_published and _scene_activation.is_empty():
		var current := get_tree().current_scene
		if (current == null and _restore_publication_source_id == 0) \
				or (current != null and current.get_instance_id() == _restore_publication_source_id):
			_restore_publication_handle.clear()
			_restore_publication_scene_id = ""
			_restore_publication_source_id = 0
			return {"ok": true}
	if handle != _restore_publication_handle or _restore_publication_publishing or _restore_publication_published \
			or get_tree().current_scene == null \
			or get_tree().current_scene.get_instance_id() != _restore_publication_source_id:
		return _startup_failure("stale_restore_publication_hold")
	_restore_publication_handle.clear()
	_restore_publication_scene_id = ""
	_restore_publication_source_id = 0
	return {"ok": true}


func publish_restore_publication_hold(handle: Dictionary) -> Dictionary:
	if handle != _restore_publication_handle or _restore_publication_scene_id.is_empty() \
			or _restore_publication_publishing:
		return _startup_failure("stale_restore_publication_hold")
	if _restore_publication_published: return {"ok": true, "value": {"already_published": true}}
	if _restore_publication_scene_id == "scene" or (_restore_publication_scene_id == "ending" and not _scene_activation.is_empty()):
		if not _scene_pause_publication.is_empty() and (not _scene_pause_publication.acknowledged \
				or _scene_pause_publication.handle != handle):
			return _startup_failure("scene_activation_unproven")
		var checked := validate_scene_activation(str(_scene_activation.get("operation_id", "")))
		if not checked.get("ok", false): return checked
		_restore_publication_published = true
		return {"ok": true}
	_restore_publication_publishing = true
	var published := _change_to(_restore_publication_scene_id)
	_restore_publication_publishing = false
	if not published.get("ok", false): return published
	_restore_publication_published = true
	return published


func release_restore_publication_hold(handle: Dictionary) -> Dictionary:
	if handle != _restore_publication_handle or not _restore_publication_published:
		return _startup_failure("stale_restore_publication_hold")
	_restore_publication_handle.clear()
	_restore_publication_scene_id = ""
	_restore_publication_source_id = 0
	_restore_publication_published = false
	_scene_pause_publication.clear()
	_pending_restore_scene_id = ""
	restore_publication_released.emit()
	return {"ok": true}


func prepare_return_to_title() -> Dictionary:
	var admitted := _return_title_admission(false)
	if not admitted.get("ok", false): return admitted
	var tree := get_tree()
	var source: Node = tree.current_scene if tree != null else null
	if not _return_source_alive(source): return _startup_failure("return_title_source_unavailable")
	if not _return_title_prepared.is_empty():
		if _return_title_preparation_current(): return _return_title_receipt(_return_title_prepared)
		_free_prepared_return_title()
	var revision := _route_custody_revision
	var generation := _route_generation
	var packed := ResourceLoader.load(_SCENE_PATHS.menu) as PackedScene
	if packed == null: return _startup_failure("return_title_scene_unavailable")
	var target: Node = packed.instantiate()
	if not target is Control:
		if is_instance_valid(target): target.free()
		return _startup_failure("return_title_scene_unavailable")
	admitted = _return_title_admission(false)
	if not admitted.get("ok", false) or not _return_source_alive(source) \
			or get_tree().current_scene != source or revision != _route_custody_revision \
			or generation != _route_generation:
		target.free()
		return admitted if not admitted.get("ok", false) else _startup_failure("stale_return_title_source")
	_return_title_counter += 1
	_return_title_prepared = {"token": "return-title:%d:%d" % [get_instance_id(), _return_title_counter],
		"source": weakref(source), "target": target, "revision": revision, "generation": generation}
	return _return_title_receipt(_return_title_prepared)

func validate_prepared_return_to_title(token: String) -> Dictionary:
	var admitted := _return_title_admission(true)
	if not admitted.get("ok", false): return admitted
	if token.is_empty() or token != _return_title_prepared.get("token", "") \
			or not _return_title_preparation_current():
		return _startup_failure("stale_return_title_preparation")
	return _return_title_receipt(_return_title_prepared)

func cancel_prepared_return_to_title(token: String) -> Dictionary:
	var admitted := _return_title_admission(true)
	if not admitted.get("ok", false): return admitted
	if token.is_empty() or token != _return_title_prepared.get("token", ""):
		return _startup_failure("stale_return_title_preparation")
	_free_prepared_return_title()
	return {"ok": true, "value": {"canceled": true}}

func publish_prepared_return_to_title(token: String) -> Dictionary:
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if not is_instance_valid(_mutation_gate) or not _mutation_gate.is_internal_owner_active(&"session_abandonment"):
		return _startup_failure("session_abandonment_required")
	if token != "" and token == _return_title_published.get("token", ""):
		var prior: Node = _return_title_published.target.get_ref()
		if _return_source_alive(prior) and get_tree().current_scene == prior \
				and _return_title_published.revision == _route_custody_revision:
			return _return_title_published.receipt.duplicate(true)
		return _startup_failure("stale_return_title_publication")
	var validated := validate_prepared_return_to_title(token)
	if not validated.get("ok", false): return validated
	_return_title_publishing = true
	var target: Node = _return_title_prepared.target
	var source: Node = _return_title_prepared.source.get_ref()
	var tree := get_tree()
	var revision := _route_custody_revision
	var generation := _route_generation
	tree.root.add_child(target)
	if not _return_source_alive(source) or tree.current_scene != source \
			or not _return_source_alive(target) or revision != _route_custody_revision \
			or generation != _route_generation or not is_instance_valid(_mutation_gate) \
			or not _mutation_gate.is_internal_owner_active(&"session_abandonment"):
		if is_instance_valid(target) and target.get_parent() != null: target.get_parent().remove_child(target)
		_free_prepared_return_title()
		_return_title_publishing = false
		return _startup_failure("stale_return_title_source")
	tree.current_scene = target
	_current_scene_id = "menu"
	_route_custody_revision += 1
	_route_generation += 1
	_return_title_prepared.clear()
	var receipt := {"ok": true, "value": {"token": token, "route_id": "menu", "scene_instance_id": target.get_instance_id()}}
	_return_title_published = {"token": token, "target": weakref(target),
		"revision": _route_custody_revision, "receipt": receipt.duplicate(true)}
	source.queue_free()
	_return_title_publishing = false
	return receipt

func _return_title_admission(allow_internal: bool) -> Dictionary:
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if not _pending_restore_scene_id.is_empty(): return _startup_failure("route_restore_pending")
	if _startup_hold_active or _startup_publishing: return _startup_failure("startup_route_hold_active")
	if not is_inside_tree(): return _startup_failure("scene_tree_unavailable")
	if not is_instance_valid(_mutation_gate): return _startup_failure("mutation_gate_unconfigured")
	if allow_internal and _mutation_gate.is_internal_owner_active(&"session_abandonment"):
		return {"ok": true}
	return _mutation_gate.guard_external(&"prepare_return_to_title")

func _return_title_preparation_current() -> bool:
	if _return_title_prepared.is_empty() or not is_inside_tree(): return false
	var source: Node = _return_title_prepared.source.get_ref()
	var target: Node = _return_title_prepared.target
	return (_return_source_alive(source) and get_tree().current_scene == source
		and is_instance_valid(target) and not target.is_inside_tree() and not target.is_queued_for_deletion()
		and _return_title_prepared.revision == _route_custody_revision
		and _return_title_prepared.generation == _route_generation)

static func _return_source_alive(source: Node) -> bool:
	if not is_instance_valid(source) or not source.is_inside_tree(): return false
	var ancestor: Node = source
	while ancestor != null:
		if ancestor.is_queued_for_deletion(): return false
		ancestor = ancestor.get_parent()
	return true

static func _return_title_receipt(prepared: Dictionary) -> Dictionary:
	return {"ok": true, "value": {"token": prepared.token, "route_id": "menu",
		"scene_instance_id": prepared.target.get_instance_id()}}

func _free_prepared_return_title() -> void:
	var target: Node = _return_title_prepared.get("target")
	_return_title_prepared.clear()
	if is_instance_valid(target) and not target.is_inside_tree(): target.free()

func _exit_tree() -> void:
	_free_prepared_return_title()
	_return_title_published.clear()


var _startup_hold_token := ""
var _startup_hold_active := false
var _startup_publishing := false
var _startup_request: Dictionary = {}
var _startup_published_result: Dictionary = {}

func begin_startup_route_hold() -> Dictionary:
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if not _startup_published_result.is_empty(): return _startup_failure("startup_route_hold_completed")
	if _startup_publishing: return _startup_failure("startup_route_publication_busy")
	if not _startup_hold_active:
		_startup_hold_token = "startup-route:%d" % get_instance_id()
		_startup_hold_active = true
		_route_custody_revision += 1
	return {"ok": true, "value": {"token": _startup_hold_token}}

func publish_startup_route_hold(token: String) -> Dictionary:
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if token.is_empty() or token != _startup_hold_token: return _startup_failure("stale_startup_route_hold")
	if _startup_publishing: return _startup_failure("startup_route_publication_busy")
	if not _startup_published_result.is_empty(): return _startup_published_result.duplicate(true)
	if not _startup_hold_active: return _startup_failure("stale_startup_route_hold")
	_startup_publishing = true
	var result: Dictionary = {"ok": true, "value": {"route_id": get_current_route_id()}}
	if not _startup_request.is_empty():
		result = _change_to(_startup_request.route_id, true)
	_startup_publishing = false
	if not result.get("ok", false): return result
	_startup_hold_active = false
	var value: Dictionary = result.get("value", {}).duplicate(true)
	value["deferred"] = false
	value["route_id"] = get_current_route_id()
	result["value"] = value
	_startup_published_result = result.duplicate(true)
	return result

func complete_startup_scene_activation(token: String, operation_id: String) -> Dictionary:
	if token.is_empty() or token != _startup_hold_token or _startup_publishing:
		return _startup_failure("stale_startup_route_hold")
	var checked := validate_scene_activation(operation_id)
	if not checked.get("ok", false): return checked
	_startup_request.clear()
	_startup_hold_active = false
	_startup_published_result = {"ok": true, "value": {"route_id": "scene", "deferred": false}}
	return _startup_published_result.duplicate(true)

func _hold_startup_request(request: Dictionary) -> Dictionary:
	_route_custody_revision += 1
	_startup_request = request.duplicate(true)
	_current_scene_id = request.route_id
	var value := {"route_id": request.route_id, "deferred": true}
	if request.has("port_instance_id"): value["port_instance_id"] = request.port_instance_id
	return {"ok": true, "code": &"ok", "value": value}

static func _startup_failure(code: String) -> Dictionary:
	return {"ok": false, "code": code, "message": ""}

static func _plain_startup_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_ARRAY:
			for item: Variant in value:
				if not _plain_startup_value(item): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not _plain_startup_value(value[key]): return false
			return true
	return false

func _valid_startup_request(request: Variant) -> bool:
	if not request is Dictionary or not _plain_startup_value(request): return false
	if request.is_empty(): return true
	if not request.get("route_id") is String or not _SCENE_PATHS.has(request.route_id): return false
	return request.get("kind") == "scene" and request.size() == 2



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


func get_current_route_id() -> String:
	return _current_scene_id if _current_scene_id != "" else "menu"


static func _has_ending_methods(target: Object, methods: Array) -> bool:
	for method: String in methods:
		if not target.has_method(method):
			return false
	return true


func _gs() -> Node:
	return get_node_or_null("/root/GameState")


func _change_to(scene_id: String, startup_publish: bool = false) -> Dictionary:
	if is_restore_publication_held() and not _restore_publication_publishing:
		return _startup_failure("restore_publication_held")
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if _startup_publishing and not startup_publish: return _startup_failure("startup_route_publication_busy")
	if not _SCENE_PATHS.has(scene_id):
		return {"ok": false, "code": &"unknown_scene_id", "message": scene_id}
	var path: String = _SCENE_PATHS[scene_id]
	if not ResourceLoader.exists(path):
		return {"ok": false, "code": &"scene_missing", "message": path}
	var tree := get_tree()
	if tree == null:
		return {"ok": false, "code": &"scene_tree_unavailable", "message": scene_id}
	if _startup_hold_active and not startup_publish:
		if not ResourceLoader.load(path) is PackedScene: return _startup_failure("scene_missing")
		return _hold_startup_request({"kind": "scene", "route_id": scene_id})
	if scene_id == "ending":
		return _change_to_ending(path)
	var changed := tree.change_scene_to_file(path)
	if changed != OK:
		return {"ok": false, "code": &"scene_change_failed", "message": str(changed)}
	_route_custody_revision += 1
	_current_scene_id = scene_id
	return {"ok": true, "code": &"ok"}


func start_game_from_menu() -> void:
	if _return_title_publishing: return
	var gs := _gs()
	if gs != null and gs.has_method("reset_game"):
		gs.reset_game()
	goto_main()


func goto_menu() -> void:
	_change_to("menu")


func goto_main() -> void:
	_change_to("main")


func goto_ending() -> void:
	var result := _change_to("ending")
	if not result.get("ok", false):
		push_warning("SceneRouter: ending route refused: %s" % str(result))


func _change_to_ending(path: String) -> Dictionary:
	if not is_ending_ports_configured():
		return {"ok": false, "code": &"ending_ports_not_configured"}
	var packed: PackedScene = load(path) as PackedScene
	if packed == null: return {"ok": false, "code": &"scene_missing"}
	var scene: Node = packed.instantiate()
	var configured: Dictionary = scene.configure_ending_ports(_ending_state_port, _ending_playback_port)
	if configured.get("ok", false): configured = scene.configure_ending_navigation(self)
	if not configured.get("ok", false):
		scene.free()
		return configured
	var tree := get_tree()
	var previous: Node = tree.current_scene
	_route_custody_revision += 1
	_current_scene_id = "ending"
	tree.root.add_child(scene)
	tree.current_scene = scene
	if is_instance_valid(previous): previous.queue_free()
	return {"ok": true, "code": &"ok"}


func goto_scene_id(scene_id: String, context: Dictionary = {}) -> void:
	if _return_title_publishing: return
	var gs := _gs()
	if gs != null and not context.is_empty():
		gs.route_context = context.duplicate(true)
	_change_to(scene_id)



var _route_restore_backup: Dictionary = {}
var _route_generation: int = 0
var _pending_restore_scene_id: String = ""


func prepare_route_restore(route_id: String, route_context: Dictionary) -> Dictionary:
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if route_id.is_empty():
		return {"ok": false, "code": &"invalid_route_id", "message": "route_id must be nonempty"}
	if not _SCENE_PATHS.has(route_id) and not (route_id == "scene" and not _scene_host_path.is_empty()):
		return {"ok": false, "code": &"unknown_scene_id", "message": route_id}
	var path: String = _scene_host_path if route_id == "scene" else _SCENE_PATHS[route_id]
	if not ResourceLoader.exists(path) or not ResourceLoader.load(path) is PackedScene:
		return {"ok": false, "code": &"scene_missing", "message": path}
	return {"ok": true, "code": &"ok", "value": {
		"route_id": route_id,
		"route_context": route_context.duplicate(true),
		"route_ready_token": {
			"route_id": route_id,
			"layout_id": route_id + "_layout",
			"generation": _route_generation + 1,
		},
	}}


func capture_restore_state() -> Dictionary:
	var backup := {"scene_id": _current_scene_id, "route_generation": _route_generation}
	if _startup_hold_active:
		backup["startup_route_hold"] = {"token": _startup_hold_token,
			"request": _startup_request.duplicate(true), "pending_scene_id": _pending_restore_scene_id}
	return {"ok": true, "code": &"ok", "value": {"backup": backup}}


func apply_route_restore_silent(plan: Dictionary) -> Dictionary:
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if _startup_publishing: return _startup_failure("startup_route_publication_busy")
	var route_id := str(plan.get("route_id", ""))
	if route_id.is_empty() and typeof(plan.get("route_ready_token")) == TYPE_DICTIONARY:
		route_id = str((plan["route_ready_token"] as Dictionary).get("route_id", ""))
	if route_id.is_empty():
		return {"ok": false, "code": &"invalid_route_plan", "message": "route plan requires a route_id"}
	var token: Variant = plan.get("route_ready_token", {
		"route_id": route_id, "layout_id": route_id + "_layout", "generation": _route_generation + 1})
	if typeof(token) != TYPE_DICTIONARY or token.get("route_id") != route_id \
			or typeof(token.get("generation")) != TYPE_INT \
			or int(token["generation"]) != _route_generation + 1:
		return {"ok": false, "code": &"stale_route_plan", "message": "route preparation is no longer current"}
	_scene_activation.clear()
	_route_custody_revision += 1
	_route_generation = int(token["generation"])
	_pending_restore_scene_id = route_id
	var gs := _gs()
	if route_id != "scene" and gs != null and typeof(plan.get("route_context")) == TYPE_DICTIONARY \
			and not plan.route_context.has("scene"):
		var combined: Dictionary = gs.route_context.duplicate(true)
		combined.merge((plan["route_context"] as Dictionary).duplicate(true), true)
		gs.route_context = combined
	return {"ok": true, "code": &"ok", "value": {"route_ready_token": token}}


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or not (source as Dictionary).has("scene_id"):
		return {"ok": false, "code": &"invalid_route_backup", "message": "route backup requires a scene_id"}
	if _startup_publishing: return _startup_failure("startup_route_publication_busy")
	var held: Variant = source.get("startup_route_hold")
	if _startup_hold_active or held != null:
		if not _startup_hold_active or not held is Dictionary or held.size() != 3 \
				or held.get("token") != _startup_hold_token or not _valid_startup_request(held.get("request")) \
				or not held.get("pending_scene_id") is String \
				or (held.pending_scene_id != "" and not _SCENE_PATHS.has(held.pending_scene_id)):
			return _startup_failure("stale_startup_route_backup")
		_startup_request = held.request.duplicate(true)
	_pending_restore_scene_id = held.pending_scene_id if _startup_hold_active else ""
	_scene_activation.clear()
	_route_custody_revision += 1
	_current_scene_id = str((source as Dictionary)["scene_id"])
	_route_generation = int(source.get("route_generation", _route_generation))
	return {"ok": true, "code": &"ok"}


func finalize_restore() -> Dictionary:
	if _pending_restore_scene_id == "scene" or (_pending_restore_scene_id == "ending" and _restore_publication_handle.has("scene_restore_operation_id")):
		if is_restore_publication_held(): _restore_publication_scene_id = _pending_restore_scene_id
		return {"ok": true, "value": {"deferred": true}}
	if is_restore_publication_held():
		if _pending_restore_scene_id.is_empty(): return _startup_failure("restore_route_unavailable")
		_restore_publication_scene_id = _pending_restore_scene_id
		return {"ok": true, "value": {"deferred": true}}
	if _return_title_publishing: return _startup_failure("return_title_publication_busy")
	if _pending_restore_scene_id != "":
		var changed := _change_to(_pending_restore_scene_id)
		if not changed.get("ok", false):
			return changed
		_pending_restore_scene_id = ""
	_route_restore_backup = {}
	if _startup_hold_active:
		return {"ok": true, "code": &"ok", "value": {"deferred": true, "route_id": get_current_route_id()}}
	return {"ok": true, "code": &"ok"}


func get_current_scene_id() -> String:
	return _current_scene_id

