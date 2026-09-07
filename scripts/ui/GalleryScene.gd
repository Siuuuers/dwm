extends Control
class_name GalleryScene

## Registrar presentation adapted from Settings checkpoint 26de279. The current
## Profile proves discovery only; no public metadata/version or replay is inferred.
const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const PRESENTATION := preload("res://scripts/ui/gallery/GalleryTheme.gd")
const RECORD := preload("res://scripts/ui/gallery/GalleryRecordButton.gd")
const STATUS_FALLBACK := {
	"gallery.record.unavailable": "Unavailable record",
	"gallery.archive.unavailable": "Gallery is unavailable.",
	"gallery.empty": "No records are filed here yet.",
	"gallery.title": "Gallery", "gallery.replay": "Replay", "button.return": "Return",
}

@onready var _ending_tile_grid: GridContainer = %EndingTileGrid
@onready var _return_button: Button = _host_return if _host_return != null else %ReturnButton
@onready var _replay_status: Label = %ReplayStatus
@onready var _replay_button: Button = %ReplayButton
@onready var _canvas: Control = %GalleryHost
@onready var _index_viewport: Control = %IndexViewport
var _profile: Object
var _router: Object
var _localization: Node
var _status_key := ""
var _selected_id := ""
var _index_offset := 0.0
var _index_extent := 0.0
var _host_return: Button

func configure_title_host(home: Button, localization: Node, profile: Object) -> Dictionary:
	if is_node_ready() or _host_return != null or not is_instance_valid(home) \
		or not is_instance_valid(profile) or not profile.has_method("get_gallery_discovery_snapshot") \
		or not profile.has_method("get_preference"):
		return {"ok": false, "code": &"invalid_gallery_host"}
	if localization != null and (not is_instance_valid(localization) or not localization.has_method("get_locale") or not localization.has_method("t")):
		return {"ok": false, "code": &"invalid_gallery_host"}
	_host_return = home
	_localization = localization
	_profile = profile
	%GalleryHost.position = Vector2.ZERO
	get_node("TitleChrome").hide()
	for child: Node in get_children():
		if child.name == &"LocalePresentationRoot" or String(child.name).begins_with("L10n"):
			child.set("_localization", localization)
	return {"ok": true, "code": &"ok"}

func open_in_title_host() -> void:
	show()
	_selected_id = ""
	_refresh_presentation()
	_refresh_tiles()
	_focus_entry.call_deferred()

func close_for_title_host() -> bool:
	hide()
	return true

func _ready() -> void:
	if _localization == null: _localization = get_node_or_null("/root/LocalizationManager")
	if _localization != null and _localization.has_signal(&"locale_changed"):
		_localization.locale_changed.connect(_on_locale_changed)
	if _host_return == null:
		_router = get_node_or_null("/root/SceneRouter")
		_profile = get_node_or_null("/root/ProfileManager")
	if _host_return == null: _return_button.pressed.connect(_on_return_pressed)
	_index_viewport.gui_input.connect(_on_index_input)
	if _profile != null and _profile.has_signal(&"preference_changed"):
		_profile.preference_changed.connect(_on_preference_changed)
	if _profile != null and _profile.has_signal(&"gallery_changed"):
		_profile.gallery_changed.connect(_on_gallery_changed)
	if _profile != null and _profile.has_signal(&"profile_restored"):
		_profile.profile_restored.connect(_on_profile_restored)
	_refresh_presentation()
	_refresh_tiles()
	_focus_entry.call_deferred()

func _refresh_tiles() -> void:
	if not is_instance_valid(_ending_tile_grid): return
	var previous_id := _selected_id
	var previous_offset := _index_offset
	var previous_focus := get_viewport().gui_get_focus_owner()
	var restore_focus := previous_focus != null and previous_focus.get_parent() == _ending_tile_grid
	var retained_row: Button = null
	_replay_button.hide()
	_index_offset = 0
	_selected_id = ""
	for child: Node in _ending_tile_grid.get_children():
		_ending_tile_grid.remove_child(child)
		child.queue_free()
	_index_extent = 0
	_update_scroll()
	if not is_instance_valid(_profile) or not _profile.has_method("get_gallery_discovery_snapshot"):
		_set_replay_status("gallery.archive.unavailable")
		_focus_return()
		_relayout_rows()
		return
	var snapshot: Variant = _profile.get_gallery_discovery_snapshot()
	if not _valid_snapshot(snapshot):
		_set_replay_status("gallery.archive.unavailable")
		_focus_return()
		_relayout_rows()
		return
	_set_replay_status("gallery.empty" if snapshot.value.ending_ids.is_empty() else "")
	_replay_button.visible = not snapshot.value.ending_ids.is_empty()
	for ending_id: String in snapshot.value.ending_ids:
		var tile := RECORD.new()
		tile.focus_mode = Control.FOCUS_ALL
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		# The shipped ending registry provides private locators only. It supplies
		# no authored public record title/sentence or exact witnessed-version
		# projection. A localization key containing an ending class is not proof
		# of trustworthy public copy and must never become visible or assistive.
		tile.set_meta(&"gallery_title_key", "gallery.record.unavailable")
		tile.set_meta(&"gallery_record_id", ending_id)
		tile.text = _localized(String(tile.get_meta(&"gallery_title_key")))
		tile.pressed.connect(_activate_record.bind(tile))
		tile.focus_entered.connect(_select_record.bind(tile))
		_ending_tile_grid.add_child(tile)
		if ending_id == previous_id: retained_row = tile
		# Directional boundaries never wrap or jump into disabled/empty paper.
		tile.focus_neighbor_left = tile.get_path()
		tile.focus_neighbor_right = tile.get_path()
	if retained_row != null: _index_offset = previous_offset
	_relayout_rows()
	if _ending_tile_grid.get_child_count() > 0:
		_select_record(retained_row if retained_row != null else _ending_tile_grid.get_child(0))
		if restore_focus:
			if retained_row != null: retained_row.grab_focus()
			else: _focus_return()
	else:
		_update_scroll()
		_focus_return()

func _focus_return() -> void:
	if is_visible_in_tree() and _return_button.focus_mode != Control.FOCUS_NONE:
		_return_button.grab_focus()

func _focus_entry() -> void:
	if not is_visible_in_tree(): return
	if _ending_tile_grid.get_child_count() > 0:
		_ending_tile_grid.get_child(0).grab_focus()
	else: _return_button.grab_focus()

func _select_record(tile: Button) -> void:
	_selected_id = tile.get_meta(&"gallery_record_id")
	for row: Button in _ending_tile_grid.get_children(): row.selected = row == tile
	_show_unavailable_record()
	_reveal_row.call_deferred(tile)

func _activate_record(tile: Button) -> void:
	tile.grab_focus()
	_select_record(tile)

func _show_unavailable_record() -> void:
	_set_replay_status("gallery.record.unavailable")

func _on_gallery_changed(_ending_id: String, _unlocked: bool) -> void:
	if not is_visible_in_tree(): return
	_refresh_tiles()

func _on_profile_restored(_snapshot: Dictionary) -> void:
	if not is_visible_in_tree(): return
	_refresh_presentation()
	_refresh_tiles()

func _on_return_pressed() -> void:
	if is_instance_valid(_router) and _router.has_method("goto_menu"): _router.goto_menu()

func _valid_snapshot(snapshot: Variant) -> bool:
	if typeof(snapshot) != TYPE_DICTIONARY or typeof(snapshot.get("ok")) != TYPE_BOOL or snapshot.get("ok") != true: return false
	var value: Variant = snapshot.get("value")
	if typeof(value) != TYPE_DICTIONARY or value.size() != 2 or not value.has_all(["revision", "ending_ids"]): return false
	if typeof(value.revision) != TYPE_INT or value.revision < 0 or typeof(value.ending_ids) != TYPE_ARRAY: return false
	var seen := {}
	for ending_id: Variant in value.ending_ids:
		if typeof(ending_id) != TYPE_STRING or ending_id not in PROFILE_SCHEMA.ENDING_IDS or seen.has(ending_id): return false
		seen[ending_id] = true
	return true

func _set_replay_status(key: String) -> void:
	_status_key = key
	if not is_instance_valid(_replay_status): return
	_replay_status.text = "" if key.is_empty() else _localized(key)
	_canvas.unavailable_record = key == "gallery.record.unavailable"
	var measure := 464 if _canvas.unavailable_record else 520
	_replay_status.size = Vector2(measure, 0)
	var height := ceilf(_replay_status.get_minimum_size().y / 2) * 2
	_replay_status.position = Vector2(408, 40) if _canvas.unavailable_record else Vector2(392, 32)
	_replay_status.size = Vector2(measure, height)
	_canvas.unavailable_height = height + 16
	_canvas.queue_redraw()

func _localized(key: String) -> String:
	if is_instance_valid(_localization) and _localization.has_method(&"t"):
		var translated: String = _localization.t(key)
		if not translated.is_empty() and translated != key: return translated
	return STATUS_FALLBACK.get(key, "Gallery is unavailable.")

func _on_locale_changed(_locale: String) -> void:
	if not is_visible_in_tree(): return
	_refresh_presentation()
	for tile: Node in _ending_tile_grid.get_children():
		tile.text = _localized(String(tile.get_meta(&"gallery_title_key")))
	_relayout_rows()
	_set_replay_status(_status_key)

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if not is_visible_in_tree(): return
	if path in [&"preferences.accessibility.text_size", &"preferences.dark_mode.available", &"preferences.dark_mode.next_run_enabled"]:
		_refresh_presentation()
		_relayout_rows()
		_set_replay_status(_status_key)

func _preference(path: StringName, fallback: Variant) -> Variant:
	return _profile.get_preference(path, fallback) if _profile != null and _profile.has_method("get_preference") else fallback

func _refresh_presentation() -> void:
	var locale := str(_localization.get_locale()) if _localization != null else "en"
	var midnight: bool = _preference(&"preferences.dark_mode.available", false) and _preference(&"preferences.dark_mode.next_run_enabled", false)
	theme = PRESENTATION.build(locale, int(_preference(&"preferences.accessibility.text_size", 100)), &"midnight" if midnight else &"after_hours")
	if _host_return == null:
		%TitleLabel.add_theme_color_override("font_color", theme.get_color("ink", "Gallery"))
		_return_button.text = _localized("button.return")
		%TitleLabel.text = _localized("gallery.title")
	_replay_button.text = _localized("gallery.replay")
	_canvas.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if theme == null: return
	draw_rect(Rect2(Vector2.ZERO, size), theme.get_color("habitat", "Gallery"))
	if _host_return == null: draw_rect(Rect2(320, 0, 960, 64), theme.get_color("face", "Gallery"))

func _relayout_rows() -> void:
	var rows := _ending_tile_grid.get_children()
	var extent := 16.0
	for i: int in range(rows.size()):
		var row: Button = rows[i]
		row.refresh_caption()
		extent += row.custom_minimum_size.y + (8 if i > 0 else 0)
		row.focus_neighbor_top = rows[maxi(0, i - 1)].get_path()
		row.focus_neighbor_bottom = rows[mini(rows.size() - 1, i + 1)].get_path()
		row.focus_previous = rows[i - 1].get_path() if i > 0 else _return_button.get_path()
		row.focus_next = rows[i + 1].get_path() if i + 1 < rows.size() else _return_button.get_path()
	_index_extent = extent if not rows.is_empty() else 0.0
	refresh_return_navigation()
	_update_scroll()
	# Container layout settles after minimum-size publication.
	_reveal_focused_row.call_deferred()

func refresh_return_navigation() -> void:
	if not is_node_ready() or not is_visible_in_tree() or not is_instance_valid(_return_button): return
	var rows := _ending_tile_grid.get_children()
	_return_button.focus_next = rows[0].get_path() if not rows.is_empty() else _return_button.get_path()
	_return_button.focus_previous = rows[-1].get_path() if not rows.is_empty() else _return_button.get_path()

func _reveal_focused_row() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and focus.get_parent() == _ending_tile_grid: _reveal_row(focus)

func _reveal_row(row: Control) -> void:
	if not is_instance_valid(row) or row.get_parent() != _ending_tile_grid: return
	var top := row.position.y
	var bottom := top + row.size.y + 16
	if top < _index_offset: _index_offset = top
	elif bottom > _index_offset + 592: _index_offset = bottom - 592
	_update_scroll()

func _update_scroll() -> void:
	_index_offset = clampf(floorf(_index_offset / 2) * 2, 0, maxf(0, _index_extent - 592))
	_ending_tile_grid.position = Vector2(8, 8 - _index_offset)
	_canvas.index_extent = _index_extent
	_canvas.index_offset = _index_offset
	_canvas.queue_redraw()

func _on_index_input(event: InputEvent) -> void:
	var amount := 0.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: amount = 72 * event.factor
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: amount = -72 * event.factor
	elif event is InputEventPanGesture: amount = event.delta.y * 32
	elif event is InputEventScreenDrag: amount = -event.relative.y
	if amount != 0:
		for row: Node in _ending_tile_grid.get_children(): row.cancel_pointer_press()
		_index_offset += amount
		_update_scroll()
		_index_viewport.accept_event()
