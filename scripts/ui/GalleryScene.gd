extends Control
class_name GalleryScene

## Registrar presentation adapted from Settings checkpoint 26de279. The current
## Replay uses exact reached records supplied by the title host.
const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const PRESENTATION := preload("res://scripts/ui/gallery/GalleryTheme.gd")
const RECORD := preload("res://scripts/ui/gallery/GalleryRecordButton.gd")
const RECORD_PAPER := preload("res://scripts/ui/gallery/GalleryRecordPaper.gd")
const ART_MANIFEST := preload("res://scripts/data/ArtManifest.gd")
const REPLAY_OWNER := preload("res://scripts/application/ending/GalleryReplayOwner.gd")
const PRACTICE_HOST := preload("res://scripts/ui/gallery/GalleryRehearsalHost.gd")
const DATING_PRESENTATION := preload("res://scripts/ui/DatingScene.gd")
signal practice_visibility_changed(active: bool)
const RECORD_CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const STATUS_FALLBACK := {
	"gallery.replay.playing": "Playing this record. Return stops replay.",
	"gallery.replay.failed": "This record could not play. Please try again.",
	"gallery.replay.start_failed": "Replay did not begin",
	"gallery.replay.unavailable": "This replay is unavailable.",
	"gallery.retry": "Retry",
	"gallery.replay.unreached": "No exact presentation is recorded for replay yet.",
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
var _retry_signature_id := ""
var _announced_start_signature_id := ""
var _selected_id := ""
var _index_offset := 0.0
var _index_extent := 0.0
var _host_return: Button
var _replay_owner: RefCounted
var _versions: Array[Dictionary] = []
var _version_selector: OptionButton
var _selected_version := 0
var _replay_bridge: Object
var _practice_game: Object
var _practice_input: Object
var _practice_button: Button
var _practice_host: CanvasLayer
var _record_title_label: Label
var _record_paper: Control
var _replay_return_hidden := false
var _record_catalog: RefCounted = RECORD_CATALOG.new()

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

func configure_replay(bridge: Object) -> Dictionary:
	if _replay_owner != null: return _replay_owner.configure(_profile, bridge)
	var replay_owner := REPLAY_OWNER.new()
	var configured: Dictionary = replay_owner.configure(_profile, bridge)
	if not configured.get("ok", false): return configured
	_replay_owner = replay_owner
	_replay_bridge = bridge
	_replay_owner.playback_finished.connect(_on_replay_finished)
	if is_node_ready(): _refresh_tiles()
	return {"ok":true}

func configure_rehearsal(game_state: Object, input_owner: Object) -> Dictionary:
	if game_state == null or not game_state.has_method("capture_run_snapshot_input"):
		return {"ok": false, "code": &"rehearsal_game_unavailable"}
	if _practice_game != null and [_practice_game, _practice_input] != [game_state, input_owner]:
		return {"ok": false, "code": &"rehearsal_already_configured"}
	_practice_game = game_state
	_practice_input = input_owner
	if is_node_ready(): _sync_practice_button()
	return {"ok": true}

func has_active_rehearsal() -> bool:
	return is_instance_valid(_practice_host)

func _sync_practice_button() -> void:
	if not is_node_ready(): return
	if _practice_button == null:
		_practice_button = Button.new()
		_practice_button.name = "Practice"
		_practice_button.theme_type_variation = &"GalleryPaperAction"
		_practice_button.pressed.connect(_on_practice_pressed)
		_practice_button.focus_entered.connect(_reveal_paper_action.bind(_practice_button))
		_canvas.add_child(_practice_button)
	var locale := str(_localization.get_locale()) if _localization != null else "en"
	_practice_button.language = locale.replace("_", "-")
	_practice_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_practice_button.text = "\u7df4\u7fd2" if locale.replace("_", "-") == "zh-HK" else ("\u7ec3\u4e60" if locale.begins_with("zh") else "Practice")
	_practice_button.visible = _practice_game != null and _replay_bridge != null and _profile != null \
		and _profile.has_method("has_completed_ending") and _profile.has_completed_ending()
	# Practice shares the written record paper.
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_practice_button.add_theme_color_override(state, theme.get_color("paper_ink", "Gallery"))
	_practice_button.disabled = _replay_owner != null and _replay_owner.is_playing()
	_practice_button.focus_mode = Control.FOCUS_ALL if _practice_button.visible and not _practice_button.disabled else Control.FOCUS_NONE
	_ensure_record_paper()
	_record_paper.set_actions(_version_selector, _practice_button)
	_record_paper.set_interactive(not _practice_button.disabled)
	refresh_return_navigation()

func _on_practice_pressed() -> void:
	if has_active_rehearsal() or _practice_game == null or _replay_bridge == null \
		or (_replay_owner != null and _replay_owner.is_playing()): return
	var host := PRACTICE_HOST.new()
	var locale := str(_localization.get_locale()) if _localization != null else "en"
	var configured: Dictionary = host.configure(_profile, _practice_game, _replay_bridge, _practice_input,
		locale, int(_preference(&"preferences.accessibility.text_size", 100)), theme)
	if not configured.get("ok", false):
		host.free()
		_set_replay_status("gallery.replay.failed")
		return
	_practice_host = host
	host.closed.connect(_on_practice_closed)
	_canvas.hide()
	add_child(host)
	practice_visibility_changed.emit(true)

func _on_practice_closed() -> void:
	if not has_active_rehearsal(): return
	remove_child(_practice_host)
	_practice_host.queue_free()
	_practice_host = null
	_canvas.show()
	practice_visibility_changed.emit(false)
	_sync_practice_button()
	_practice_button.grab_focus.call_deferred()

func _ensure_version_selector() -> void:
	if _version_selector != null: return
	_version_selector = OptionButton.new()
	_version_selector.name = "ReachedVersion"
	_version_selector.theme_type_variation = &"GalleryPaperAction"
	_version_selector.item_selected.connect(_on_version_selected)
	_version_selector.focus_entered.connect(_reveal_paper_action.bind(_version_selector))
	_canvas.add_child(_version_selector)
	_version_selector.hide()

func _ensure_record_paper() -> void:
	if _record_paper != null: return
	_record_paper = RECORD_PAPER.new()
	_record_paper.name = "RecordPaper"
	_record_paper.position = Vector2(392, 32)
	_record_paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.add_child(_record_paper)
	_record_title_label = _record_paper.title_label
	_record_paper.presentation_changed.connect(_on_paper_changed)
	_record_paper.focus_target_removed.connect(_on_paper_focus_removed)

func _refresh_record_copy() -> void:
	_ensure_record_paper()
	var visible_record := not _selected_id.is_empty() and _status_key not in [
		"gallery.empty", "gallery.record.unavailable", "gallery.archive.unavailable"]
	var locale := str(_localization.get_locale()) if _localization != null else "en"
	var details := {"sentence": "", "media_asset_id": ""}
	if visible_record and not _selected_signature_id().is_empty():
		details = _record_catalog.projection(_selected_id, _selected_signature_id(), locale)
	var media: Texture2D = null
	if not str(details.media_asset_id).is_empty():
		media = ART_MANIFEST.get_texture(str(details.media_asset_id), Vector2i(258, 78))
	# Missing or unregistered exports never borrow scene art or reserve an aperture.
	_record_paper.set_copy(_record_title(_selected_id) if visible_record else "",
		str(details.sentence), locale, false, media)

func _on_paper_changed() -> void:
	_canvas.paper_extent = _record_paper.content_extent
	_canvas.paper_offset = _record_paper.scroll_offset
	_canvas.paper_focus = _record_paper.has_focus(true)
	_canvas.queue_redraw()
	refresh_return_navigation()

func _on_paper_focus_removed(hide_focus: bool) -> void:
	if _replay_owner != null and _replay_owner.is_playing(): return
	for row: Button in _ending_tile_grid.get_children():
		if str(row.get_meta(&"gallery_record_id")) == _selected_id:
			row.grab_focus(hide_focus)
			break

func _reveal_paper_action(control: Control) -> void:
	if is_instance_valid(_record_paper): _record_paper.reveal_control(control)

func open_in_title_host() -> void:
	show()
	_retry_signature_id = ""
	_selected_id = ""
	_refresh_presentation()
	_refresh_tiles()
	_focus_entry.call_deferred()

func close_for_title_host() -> bool:
	if has_active_rehearsal():
		_practice_host.request_return()
		return false # One Return closes one practice layer.
	if _replay_owner != null and not _replay_owner.close().get("ok", false): return false
	_retry_signature_id = ""
	_set_replay_status("")
	hide()
	return true

func _ready() -> void:
	if _localization == null: _localization = get_node_or_null("/root/LocalizationManager")
	if _localization != null and _localization.has_signal(&"locale_changed"):
		_localization.locale_changed.connect(_on_locale_changed)
	if _host_return == null:
		_router = get_node_or_null("/root/SceneRouter")
		_profile = get_node_or_null("/root/ProfileManager")
	if _host_return == null:
		_return_button.theme_type_variation = &"GalleryDarkAction"
		_return_button.pressed.connect(_on_return_pressed)
	_index_viewport.gui_input.connect(_on_index_input)
	_replay_button.theme_type_variation = &"GalleryDarkAction"
	_replay_button.pressed.connect(_on_replay_pressed)
	_ensure_version_selector()
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
	var previous_paper_offset: float = _record_paper.scroll_offset if _record_paper != null else 0.0
	var previous_focus := get_viewport().gui_get_focus_owner()
	var hide_focus := previous_focus != null and not previous_focus.has_focus(true)
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
		_clear_replay_versions()
		_set_replay_status("gallery.archive.unavailable")
		_focus_return()
		_relayout_rows()
		return
	var snapshot: Variant = _profile.get_gallery_discovery_snapshot()
	if not _valid_snapshot(snapshot):
		_clear_replay_versions()
		_set_replay_status("gallery.archive.unavailable")
		_focus_return()
		_relayout_rows()
		return
	# Reached date scenes share the existing picker; they create no ending discovery identity.
	var record_ids: Array = snapshot.value.ending_ids.duplicate()
	if _replay_owner != null:
		var reached: Dictionary = _replay_owner.get_reached_entry_variants()
		if reached.get("ok", false):
			for record: Dictionary in reached.value.records:
				var caption: Dictionary = DATING_PRESENTATION.reached_presentation_copy(record.signature)
				if caption.get("ok", false) and record.signature.entry_id not in record_ids:
					record_ids.append(record.signature.entry_id)
	_set_replay_status("gallery.empty" if record_ids.is_empty() else "")
	_replay_button.visible = not record_ids.is_empty()
	for ending_id: String in record_ids:
		var tile := RECORD.new()
		tile.focus_mode = Control.FOCUS_ALL
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		# Physical locators stay private. Configured replay uses the separate public
		# title catalog and exact reached records; unconfigured registrars stay unavailable.
		tile.set_meta(&"gallery_title_key", "gallery.record.unavailable")
		tile.set_meta(&"gallery_record_id", ending_id)
		tile.text = _record_title(str(tile.get_meta(&"gallery_record_id")))
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
		if retained_row != null: _selected_id = previous_id
		_select_record(retained_row if retained_row != null else _ending_tile_grid.get_child(0))
		if retained_row != null: _record_paper.scroll_to(previous_paper_offset)
		if restore_focus:
			if retained_row != null: retained_row.grab_focus(hide_focus)
			else: _focus_return()
	else:
		_clear_replay_versions()
		_update_scroll()
		_focus_return()
	if retained_row == null and previous_focus in [_record_paper, _version_selector, _replay_button]:
		_on_paper_focus_removed(hide_focus)
	elif previous_focus == _record_paper and _record_paper.focus_mode != Control.FOCUS_NONE:
		_record_paper.grab_focus(hide_focus)
	elif previous_focus == _practice_button and _practice_button.visible and not _practice_button.disabled:
		_practice_button.grab_focus(hide_focus)
	elif previous_focus == _replay_button and _replay_button.visible and not _replay_button.disabled:
		_replay_button.grab_focus(hide_focus)
	elif previous_focus == _version_selector and _version_selector.visible and not _version_selector.disabled:
		_version_selector.grab_focus(hide_focus)
	elif previous_focus in [_record_paper, _practice_button, _replay_button, _version_selector] and (_replay_owner == null or not _replay_owner.is_playing()):
		for row: Button in _ending_tile_grid.get_children():
			if str(row.get_meta(&"gallery_record_id")) == _selected_id:
				row.grab_focus(hide_focus)
				break

func _focus_return() -> void:
	if is_visible_in_tree() and _return_button.focus_mode != Control.FOCUS_NONE:
		_return_button.grab_focus()

func _focus_entry() -> void:
	if not is_visible_in_tree(): return
	if _ending_tile_grid.get_child_count() > 0:
		_ending_tile_grid.get_child(0).grab_focus()
	else: _return_button.grab_focus()

func _select_record(tile: Button) -> void:
	var changed := _selected_id != str(tile.get_meta(&"gallery_record_id"))
	if changed: _retry_signature_id = ""
	_selected_id = tile.get_meta(&"gallery_record_id")
	for row: Button in _ending_tile_grid.get_children(): row.selected = row == tile
	_refresh_replay_selection()
	if changed: _record_paper.scroll_to(0)
	_reveal_row.call_deferred(tile)

func _activate_record(tile: Button) -> void:
	if not tile.has_focus(): tile.grab_focus()
	_select_record(tile)

func _record_title(ending_id: String) -> String:
	if _replay_owner != null:
		var locale := str(_localization.get_locale()) if _localization != null else "en"
		var public_title := RECORD_CATALOG.title(ending_id, locale)
		if not public_title.is_empty(): return public_title
		var available: Dictionary = _replay_owner.get_reached_entry_variants(ending_id)
		if available.get("ok", false) and not available.value.records.is_empty():
			var caption: Dictionary = DATING_PRESENTATION.reached_presentation_copy(available.value.records[0].signature, locale)
			if caption.get("ok", false):
				var post := ending_id.ends_with(".post_challenge")
				var phase := "After" if post else "Before"
				if locale.replace("_", "-") == "zh-CN": phase = "\u7ed3\u675f\u540e" if post else "\u5f00\u59cb\u524d"
				elif locale.replace("_", "-") == "zh-HK": phase = "\u7d50\u675f\u5f8c" if post else "\u958b\u59cb\u524d"
				return str(caption.value.title) + " / " + phase
	return _localized("gallery.record.unavailable")

func _refresh_replay_selection() -> void:
	_ensure_version_selector()
	var previous := str(_versions[_selected_version].signature_id) if _selected_version < _versions.size() else ""
	_versions.clear()
	_selected_version = 0
	_version_selector.clear()
	if _replay_owner != null and not _selected_id.is_empty():
		var available: Dictionary = _replay_owner.get_reached_entry_variants(_selected_id) if _selected_id.begins_with("dating.") \
			else _replay_owner.get_variants(_selected_id)
		if available.get("ok", false):
			for record: Dictionary in available.value.records: _versions.append(record.duplicate(true))
	for index: int in range(_versions.size()):
		var locale := str(_localization.get_locale()) if _localization != null else "en"
		_version_selector.add_item(("版本 %d" if locale.begins_with("zh") else "Version %d") % (index + 1))
		_version_selector.get_popup().set_item_language(index, locale.replace("_", "-"))
		if str(_versions[index].signature_id) == previous: _selected_version = index
	if not _versions.is_empty(): _version_selector.select(_selected_version)
	_version_selector.visible = _versions.size() > 1
	_sync_replay_controls()
	if not _retry_signature_id.is_empty() and _retry_signature_id == _selected_signature_id():
		_set_replay_status("gallery.replay.start_failed")
	else:
		_retry_signature_id = ""
		var key := "gallery.replay.playing" if _replay_owner != null and _replay_owner.is_playing() else ""
		_set_replay_status(key if not _versions.is_empty() else ("gallery.replay.unreached" if _replay_owner != null else "gallery.record.unavailable"))

func _clear_replay_versions() -> void:
	_retry_signature_id = ""
	_versions.clear()
	_selected_version = 0
	_ensure_version_selector()
	_version_selector.clear()
	_version_selector.hide()
	_refresh_record_copy()
	_sync_replay_controls()

func _sync_replay_controls() -> void:
	var playing: bool = _replay_owner != null and _replay_owner.is_playing()
	_replay_button.disabled = playing or _versions.is_empty()
	_replay_button.focus_mode = Control.FOCUS_NONE if _replay_button.disabled else Control.FOCUS_ALL
	_version_selector.disabled = playing
	_version_selector.focus_mode = Control.FOCUS_ALL if _version_selector.visible and not playing else Control.FOCUS_NONE
	for row: Button in _ending_tile_grid.get_children(): row.disabled = playing
	_sync_practice_button()

func _on_version_selected(index: int) -> void:
	if index < 0 or index >= _versions.size() or (_replay_owner != null and _replay_owner.is_playing()): return
	if str(_versions[index].signature_id) == _selected_signature_id():
		return
	_retry_signature_id = ""
	_selected_version = index
	_set_replay_status("")

func _selected_signature_id() -> String:
	return str(_versions[_selected_version].signature_id) if _selected_version >= 0 and _selected_version < _versions.size() else ""

func _on_replay_pressed() -> void:
	if _replay_owner == null or _replay_owner.is_playing() or _selected_signature_id().is_empty(): return
	var signature_id := _selected_signature_id()
	_replay_return_hidden = _replay_button.has_focus() and not _replay_button.has_focus(true)
	var started: Dictionary = _replay_owner.begin(signature_id)
	_sync_replay_controls()
	if not started.get("ok", false):
		if started.get("failure_phase") == &"start" and str(started.get("signature_id", "")) == signature_id:
			_retry_signature_id = signature_id
			_set_replay_status("gallery.replay.start_failed")
		elif _retry_signature_id.is_empty():
			_set_replay_status("gallery.replay.unavailable")
	elif _replay_owner.is_playing():
		_retry_signature_id = ""
		_set_replay_status("gallery.replay.playing")

func _on_replay_finished(result: Dictionary) -> void:
	if not is_node_ready(): return
	_retry_signature_id = ""
	var start_failure: bool = result.get("outcome") == "failed" and result.get("failure_phase") == &"start" \
		and str(result.get("signature_id", "")) == _selected_signature_id()
	if start_failure: _retry_signature_id = _selected_signature_id()
	_sync_replay_controls()
	_set_replay_status("gallery.replay.start_failed" if start_failure else ("gallery.replay.failed" if result.get("outcome") == "failed" else ""))
	if is_visible_in_tree() and not _replay_button.disabled: _replay_button.grab_focus(_replay_return_hidden)

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
	if not close_for_title_host(): return
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
	_replay_status.accessibility_live = DisplayServer.LIVE_OFF
	if _retry_signature_id.is_empty(): _announced_start_signature_id = ""
	if key == "gallery.replay.start_failed" and _announced_start_signature_id != _retry_signature_id and is_visible_in_tree():
		_replay_status.text = ""
		_replay_status.accessibility_name = ""
		_replay_status.accessibility_live = DisplayServer.LIVE_POLITE
		_announced_start_signature_id = _retry_signature_id
	_replay_status.text = "" if key.is_empty() else _localized(key)
	_replay_status.accessibility_name = _replay_status.text
	_refresh_replay_caption()
	_canvas.replay_start_failed = key == "gallery.replay.start_failed"
	_canvas.replay_unavailable = key == "gallery.replay.unavailable"
	_canvas.unavailable_record = key == "gallery.record.unavailable"
	_refresh_record_copy()
	if _canvas.replay_start_failed or _canvas.replay_unavailable or (not _selected_id.is_empty() and key.begins_with("gallery.replay.")):
		_replay_status.position = Vector2(408, 568)
		_replay_status.size = Vector2(360, 64)
		_replay_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_replay_status.add_theme_color_override("font_color", theme.get_color("error_ink", "Gallery"))
		_canvas.queue_redraw()
		return
	_replay_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_replay_status.remove_theme_color_override("font_color")
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
		tile.text = _record_title(str(tile.get_meta(&"gallery_record_id")))
	_relayout_rows()
	if _replay_owner != null: _refresh_replay_selection()
	else: _set_replay_status(_status_key)

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
	var text_controls: Array[Control] = [_replay_status, _replay_button]
	if is_instance_valid(_version_selector):
		text_controls.append(_version_selector)
		_version_selector.get_popup().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_version_selector.add_theme_color_override(state, theme.get_color("paper_ink", "Gallery"))
	if _host_return == null:
		text_controls.append(%TitleLabel)
		text_controls.append(_return_button)
		%TitleLabel.add_theme_color_override("font_color", theme.get_color("ink", "Gallery"))
		_return_button.text = _localized("button.return")
		%TitleLabel.text = _localized("gallery.title")
	for control: Control in text_controls:
		control.set("language", locale.replace("_", "-"))
		control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh_replay_caption()
	_sync_practice_button()
	_canvas.queue_redraw()
	queue_redraw()

func _refresh_replay_caption() -> void:
	_replay_button.text = _localized("gallery.retry" if not _retry_signature_id.is_empty() else "gallery.replay")
	_replay_button.accessibility_name = _replay_button.text

func _draw() -> void:
	if theme == null: return
	draw_rect(Rect2(Vector2.ZERO, size), theme.get_color("habitat", "Gallery"))
	if _host_return == null: draw_rect(Rect2(320, 0, 960, 64), theme.get_color("face", "Gallery"))

func _relayout_rows() -> void:
	var rows := _ending_tile_grid.get_children()
	var extent := 16.0
	var locale := str(_localization.get_locale()) if _localization != null else "en"
	for i: int in range(rows.size()):
		var row: Button = rows[i]
		row.language = locale.replace("_", "-")
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
	var sequence: Array[Control] = []
	var selected_row: Button = null
	for row: Button in rows:
		if str(row.get_meta(&"gallery_record_id")) == _selected_id: selected_row = row
		if not row.disabled: sequence.append(row)
	var deeper: Array[Control] = []
	for control: Control in [_record_paper, _version_selector, _replay_button]:
		if is_instance_valid(control) and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			deeper.append(control)
	sequence.append_array(deeper)
	if is_instance_valid(_practice_button) and _practice_button.visible and not _practice_button.disabled:
		sequence.append(_practice_button)
	sequence.append(_return_button)
	for index: int in range(sequence.size()):
		sequence[index].focus_previous = sequence[posmod(index - 1, sequence.size())].get_path()
		sequence[index].focus_next = sequence[(index + 1) % sequence.size()].get_path()
	for row: Button in rows:
		row.focus_neighbor_right = deeper[0].get_path() if not deeper.is_empty() else row.get_path()
	for index: int in range(deeper.size()):
		deeper[index].focus_neighbor_left = selected_row.get_path() if selected_row != null else deeper[index].get_path()
		deeper[index].focus_neighbor_right = deeper[mini(index + 1, deeper.size() - 1)].get_path()

func _reveal_focused_row() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and focus.get_parent() == _ending_tile_grid: _reveal_row(focus)

func _reveal_row(row: Variant) -> void:
	# A queued reveal may outlive a replaced row; validate before a typed access.
	if not is_instance_valid(row) or row.get_parent() != _ending_tile_grid: return
	var top: float = row.position.y
	var bottom: float = top + row.size.y + 16
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
