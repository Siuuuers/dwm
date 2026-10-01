extends DialogicLayoutLayer
## Transient public caption copies, not canonical History, receipts, or restore ownership.

const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const HISTORY := preload("res://scripts/ui/witnessed/WitnessedHistory.gd")
const RUN_PRESENTATION := preload("res://scripts/ui/witnessed/WitnessedRunPresentation.gd")
const FIELD_TOP := {100: 448, 125: 392, 150: 328}
const FIELD_BOTTOM := 656
const PROFILE_COLOUR_PRESETS := {
	"standard": "standard", "protan": "protan", "deutan": "deutan", "tritan": "tritan",
}

var _locale := "en"
var _text_percent := 100
var _font_style := "pixel"
var _palette := "AfterHours"
var _day := 1
var _run_owner: Object
var _high_contrast := false
var _colour_preset := "standard"
var _large_targets := false
var _caption_theme: Theme
var _dating_overlay := false
var _scene_art_bridge: Node
var _dating_split_surface: Control
var _last_text := ""
var _last_content_height := -1
var _had_caption := false
var _profile: Node
var _localization: Node
var _retained: Array[String] = []
var _scrollback: Array[String] = []
var _review_offset := 0
var _live_scroll := 0.0
var _current_copy := ""
var _layout_generation := 0
var _layout_pending := false
var _publication_pending := false
var _scroll_restore_waiting := false
var _scroll_restore_value := 0.0
var _scroll_restore_retries := 0
var _pause_capture_id := 0
var _pause_anchor: Dictionary = {}
var _pause_view: Dictionary = {}
var _pause_covered := false
var _transport_bridge: Object
var _transport_configured := false
var _transport_input_bound := false
var _rail_focus_key := ""
var _presented_line: Dictionary = {}
var _line_waiting_for_text := false
var _auto_configured := false
var _auto_input_bound := false
var _auto_resume_pending := true
var _backup_load_router: Node
var _load_input_bound := false
var _save_input_bound := false
var _history_input_bound := false
var _history_overlay: Control
var _history_open := false
var _history_pending := false
var _history_source: Dictionary = {}
var _load_pending := false
var _load_focus_restore_id := 0
var _load_activation_focus_id := 0
var _reading_input_owner: Node
var _reading_profile: Object
var _reading_owner_generation := 0
var _reading_recovery: Dictionary = {}
var _reading_retry_in_progress := false
var _recovery_bound := false
var _speech_profile: Object
var _speech_bridge: Object
var _speech_owner: Object
var _speech_generation := 0
var _speech_candidate := false
var _speech_pending := false
var _speech_source := ""
var _speech_token := 0
var _speech_identity: Dictionary = {}
var _speech_status: Label

@onready var canvas: Control = $Canvas
@onready var scroll: ScrollContainer = $Canvas/Scroll
@onready var stack: Control = $Canvas/Scroll/Stack
@onready var caption_text: DialogicNode_DialogText = $Canvas/Scroll/Stack/Caption
@onready var older: RichTextLabel = $Canvas/Scroll/Stack/Older
@onready var previous: RichTextLabel = $Canvas/Scroll/Stack/Previous
@onready var review_current: RichTextLabel = $Canvas/Scroll/Stack/ReviewCurrent
@onready var background_input: Control = $Canvas/BackgroundInput
@onready var overlay: Control = $Canvas/Overlay
@onready var accept_input: Node = $AcceptInput
@onready var skip_controller: Node = $SkipController
@onready var auto_controller: Node = $AutoController
@onready var transport_rail: Control = $Canvas/TransportRail
@onready var recovery_overlay: Control = $RecoveryLayer/Recovery
@onready var recovery_layer: CanvasLayer = $RecoveryLayer

func _ready() -> void:
	super._ready()
	if caption_text.gui_input.is_connected(caption_text.on_gui_input):
		caption_text.gui_input.disconnect(caption_text.on_gui_input)
	caption_text.gui_input.connect(_on_caption_input)
	caption_text.visibility_changed.connect(_on_caption_visibility_changed)
	caption_text.started_revealing_text.connect(_sync_native_processing)
	caption_text.focus_entered.connect(caption_text.queue_redraw)
	caption_text.focus_exited.connect(caption_text.queue_redraw)
	caption_text.draw.connect(_draw_current_frame)
	background_input.gui_input.connect(_on_background_input)
	scroll.gui_input.connect(_on_passive_input.bind(scroll))
	stack.gui_input.connect(_on_passive_input.bind(stack))
	canvas.draw.connect(_draw_canvas)
	overlay.draw.connect(_draw_seam)
	get_scroll_bar().focus_mode = Control.FOCUS_NONE
	configure_presentation(_locale, _text_percent, _palette, _high_contrast, _colour_preset, _large_targets, _day, _font_style)
	_profile = get_node_or_null("/root/ProfileManager")
	_localization = get_node_or_null("/root/LocalizationManager")
	_speech_status = load("res://scripts/ui/witnessed/WitnessedSpeechStatus.gd").new()
	_speech_status.name = "SpeechStatus"
	overlay.add_child(_speech_status)
	transport_rail.bind_localization(_localization)
	if _profile != null and _profile.has_signal("preference_changed"):
		_profile.connect("preference_changed", _on_preference_changed)
	if _localization != null and _localization.has_signal("locale_changed"):
		_localization.connect("locale_changed", _on_locale_changed)
	var run_owner: Object = _run_owner if is_instance_valid(_run_owner) else get_node_or_null("/root/GameState")
	_apply_preferences()
	configure_run_presentation(run_owner)
	_scene_art_bridge = get_node_or_null("/root/DialogicBridge")
	if _scene_art_bridge != null and _scene_art_bridge.has_signal("scene_art_changed"):
		_scene_art_bridge.connect("scene_art_changed", _refresh_dating_overlay)
	_refresh_dating_overlay()
	var runtime := get_node_or_null("/root/Dialogic")
	accept_input.bind(caption_text, scroll, runtime)
	accept_input.bind_scene_input(background_input)
	accept_input.bind_presentation_admission(_before_normal_accept, _automatic_line_admitted)
	accept_input.bind_local_admission(_reading_source_admitted)
	accept_input.normal_accept_requested.connect(_on_normal_accept_requested)
	transport_rail.skip_requested.connect(_on_skip_requested)
	transport_rail.auto_requested.connect(_on_auto_requested)
	transport_rail.load_requested.connect(_on_load_requested)
	transport_rail.save_requested.connect(_on_save_requested)
	transport_rail.history_requested.connect(_on_history_requested)
	skip_controller.state_changed.connect(_sync_transport)
	auto_controller.state_changed.connect(_on_auto_state_changed)
	configure_reading_transport(_profile, get_node_or_null("/root/DialogicBridge"))
	configure_speech(_profile, get_node_or_null("/root/DialogicBridge"), get_node_or_null("/root/SystemTtsCoordinator"))
	auto_controller.bind_completion_barrier(_speech_allows_auto)
	var input_owner := get_node_or_null("/root/InputManager")
	_reading_input_owner = input_owner
	_backup_load_router = get_node_or_null("/root/SceneRouter")
	_recovery_bound = recovery_overlay.bind_owners(_localization, input_owner, _recovery_action_admitted)
	recovery_overlay.retry_requested.connect(_retry_reading_command)
	recovery_overlay.cancel_requested.connect(_cancel_reading_recovery)
	_configure_recovery_presentation()
	_transport_input_bound = transport_rail.bind_admission(_transport_admitted, input_owner)
	_auto_input_bound = transport_rail.bind_auto_admission(_auto_button_admitted, input_owner)
	_load_input_bound = transport_rail.bind_load_admission(_load_admitted, input_owner)
	_save_input_bound = transport_rail.bind_save_admission(_save_admitted, input_owner)
	_history_input_bound = transport_rail.bind_history_admission(_history_admitted, input_owner)
	var history_layer := CanvasLayer.new()
	history_layer.name = "HistoryLayer"
	history_layer.layer = 101
	add_child(history_layer)
	move_child(history_layer, canvas.get_index())
	_history_overlay = HISTORY.new()
	_history_overlay.name = "History"
	history_layer.add_child(_history_overlay)
	_history_overlay.close_requested.connect(_on_history_close_requested)
	_configure_history_presentation()
	if input_owner != null and input_owner.has_signal("source_input_custody_changed"):
		input_owner.connect("source_input_custody_changed", _retire_transport)
	if runtime != null and runtime.has_method("get_subsystem"):
		var text_owner: Object = runtime.call("get_subsystem", "Text")
		if text_owner != null:
			text_owner.connect("about_to_show_text", _on_about_to_show_text)
			text_owner.connect("text_started", _on_text_started)
			text_owner.connect("text_finished", _on_text_finished)
		if runtime.has_signal("timeline_started"):
			runtime.connect("timeline_started", _on_timeline_started)
		runtime.connect("timeline_ended", _on_playback_ended)
		runtime.connect("dialogic_paused", _retire_transport)
	_sync_transport()

func configure_speech(profile: Object, bridge: Object, owner: Object) -> bool:
	_cancel_speech()
	if is_instance_valid(_speech_owner) and _speech_owner.has_signal("speech_completed") \
			and _speech_owner.is_connected("speech_completed", _on_speech_completed):
		_speech_owner.disconnect("speech_completed", _on_speech_completed)
	_speech_profile = profile
	_speech_bridge = bridge
	_speech_owner = owner
	if is_instance_valid(owner) and owner.has_signal("speech_completed"):
		owner.connect("speech_completed", _on_speech_completed)
	return is_instance_valid(profile) and profile.has_method("get_preference") \
		and is_instance_valid(bridge) and bridge.has_method("capture_current_speech_presentation") \
		and is_instance_valid(owner) and owner.has_method("request_speech") \
		and owner.has_method("stop_source") and owner.has_method("is_speaking")

func _cancel_speech() -> void:
	_speech_generation += 1
	_speech_candidate = false
	_speech_pending = false
	var retired_source := _speech_source
	_speech_source = ""
	_speech_token = 0
	_speech_identity.clear()
	if is_instance_valid(_speech_status): _speech_status.clear_status()
	if not retired_source.is_empty() and is_instance_valid(_speech_owner):
		_speech_owner.stop_source(retired_source, &"source_retired")

func _speech_admitted() -> bool:
	return _review_offset == 0 and not _pause_covered and _reading_source_admitted() and _has_caption() \
		and accept_input.is_source_admitted() and not skip_controller.is_skip_active()

func _speech_allows_auto(expected_frontier: Dictionary) -> bool:
	return expected_frontier == _presented_line and not _speech_pending \
		and (_speech_source.is_empty() or not is_instance_valid(_speech_owner) \
		or not _speech_owner.is_speaking(_speech_source))

func _speak_publication(generation: int) -> void:
	if generation != _speech_generation or not _speech_candidate: return
	# Consume once even when Off, unavailable, restored, or denied. Preferences,
	# focus return and duplicate native signals cannot replay this publication.
	_speech_candidate = false
	_speech_pending = false
	if not _speech_admitted() or not is_instance_valid(_speech_profile) \
			or not is_instance_valid(_speech_bridge) or not is_instance_valid(_speech_owner) \
			or not _speech_bridge.has_method("capture_current_speech_presentation"): return
	var captured: Dictionary = _speech_bridge.capture_current_speech_presentation()
	if not captured.get("ok", false): return
	var publication: Dictionary = captured.value
	if publication.suppress_replay or publication.display_text != caption_text.get_parsed_text(): return
	if not bool(_speech_profile.get_preference(&"preferences.reading.read_aloud_enabled", false)): return
	_speech_source = "witnessed.%d.%d" % [get_instance_id(), generation]
	_speech_identity = publication.identity.duplicate(true)
	var result: Dictionary = _speech_owner.request_speech(publication.primary_text, publication.content_locale,
		StringName(_speech_profile.get_preference(&"preferences.reading.read_aloud_rate", "normal")), _speech_source)
	if generation != _speech_generation or _speech_source.is_empty(): return
	_speech_token = int(result.get("value", {}).get("token", 0))
	if not result.get("ok", false) and _speech_failure_is_current(): _speech_status.show_failure()

func _speech_failure_is_current() -> bool:
	if not _speech_admitted() or _speech_identity.is_empty() or not is_instance_valid(_speech_status) \
			or not is_instance_valid(_speech_bridge): return false
	var current: Dictionary = _speech_bridge.capture_current_speech_presentation()
	return current.get("ok", false) and current.value.identity == _speech_identity

func _on_speech_completed(token: int, outcome: StringName) -> void:
	if token <= 0 or token != _speech_token: return
	_speech_token = 0
	if outcome == &"failed" and _speech_failure_is_current(): _speech_status.show_failure()

func _configure_speech_status() -> void:
	if not is_instance_valid(_speech_status): return
	_speech_status.update_presentation(_localization, _locale, _caption_theme, _text_percent)
	_speech_status.position = Vector2(24, FIELD_TOP[_text_percent] - 64)
	_speech_status.size = Vector2(1232, 64)

func _exit_tree() -> void:
	_cancel_speech()
	if is_instance_valid(_dating_split_surface): _dating_split_surface.cancel_split_input()

func configure_reading_transport(profile: Object, bridge: Object) -> bool:
	if not is_node_ready() or not is_instance_valid(bridge) \
			or not bridge.has_method("can_skip_current_line"):
		return false
	if not skip_controller.configure(profile, bridge, _skip_controller_admitted): return false
	_dismiss_reading_recovery(false)
	if is_instance_valid(_reading_profile) and _reading_profile.has_signal("profile_restored") \
			and _reading_profile.is_connected("profile_restored", _on_reading_profile_restored):
		_reading_profile.disconnect("profile_restored", _on_reading_profile_restored)
	_reading_profile = profile
	_reading_owner_generation += 1
	if _reading_profile.has_signal("profile_restored"):
		_reading_profile.connect("profile_restored", _on_reading_profile_restored)
	if is_instance_valid(_transport_bridge) and _transport_bridge.has_signal("reading_session_changed") \
			and _transport_bridge.is_connected("reading_session_changed", _on_reading_session_changed):
		_transport_bridge.disconnect("reading_session_changed", _on_reading_session_changed)
	_transport_bridge = bridge
	if bridge.has_signal("reading_session_changed"):
		bridge.connect("reading_session_changed", _on_reading_session_changed)
	_transport_configured = true
	_auto_configured = auto_controller.configure(profile, bridge, _auto_controller_admitted)
	accept_input.bind_presentation_admission(_before_normal_accept, _automatic_line_admitted)
	_capture_presented_line()
	_acknowledge_visible_line()
	_sync_transport()
	return _transport_configured


func _before_normal_accept() -> bool:
	if _review_offset > 0:
		_set_review_offset(0)
		return false
	return _acknowledge_visible_line()

func _acknowledge_visible_line() -> bool:
	if _review_offset > 0: return false
	if _line_waiting_for_text: return false
	var has_proof: bool = _presented_line.get("ok", false)
	if not is_instance_valid(_transport_bridge) \
			or not _transport_bridge.has_method("requires_line_presentation_acknowledgement"):
		return not has_proof
	if not has_proof:
		return not _transport_bridge.call("requires_line_presentation_acknowledgement")
	# A rendered canonical proof stays mandatory if a callback replaces its owner.
	if _pause_covered or not _has_caption() or not caption_text.is_visible_in_tree(): return false
	var result: Dictionary = _transport_bridge.call("acknowledge_current_line_presentation", _presented_line)
	if result.get("ok", false): _auto_resume_pending = true
	return result.get("ok", false)


func _capture_presented_line() -> void:
	_presented_line.clear()
	_line_waiting_for_text = not _has_caption()
	if _has_caption() and is_instance_valid(_transport_bridge) \
			and _transport_bridge.has_method("capture_current_line_presentation_frontier"):
		_presented_line = _transport_bridge.call("capture_current_line_presentation_frontier")


func _automatic_line_admitted() -> bool:
	if _review_offset > 0: return false
	if _line_waiting_for_text: return false
	var has_proof: bool = _presented_line.get("ok", false)
	if not is_instance_valid(_transport_bridge) \
			or not _transport_bridge.has_method("requires_line_presentation_acknowledgement"):
		return not has_proof
	if not has_proof:
		return not _transport_bridge.call("requires_line_presentation_acknowledgement")
	return _presented_line == _transport_bridge.call("capture_current_line_presentation_frontier") \
		and bool(_transport_bridge.call("is_current_line_presentation_acknowledged"))

func _transport_admitted() -> bool:
	if _review_offset > 0: return false
	return _transport_configured and _transport_input_bound and not _pause_covered \
		and not _line_waiting_for_text and is_instance_valid(transport_rail) \
		and transport_rail.is_visible_in_tree() and accept_input.is_source_admitted() \
		and is_instance_valid(_transport_bridge) \
		and bool(_transport_bridge.call("can_skip_current_line"))

func _reading_source_admitted() -> bool:
	return _reading_recovery.is_empty() and not _load_pending and not _history_pending and not _history_open

func _load_admitted() -> bool:
	return _load_input_bound and not _load_pending and not _pause_covered \
		and not _line_waiting_for_text and _reading_recovery.is_empty() and _has_caption() \
		and transport_rail.is_visible_in_tree() and accept_input.is_source_admitted() \
		and is_instance_valid(_backup_load_router) \
		and _backup_load_router.can_open_witnessed_backup_load(self)

func _on_load_requested() -> void:
	if not _load_admitted(): return
	var source_identity := _pause_runtime_identity()
	_load_activation_focus_id = transport_rail.get_node("Load").get_instance_id()
	_load_pending = true
	_retire_transport()
	accept_input.retire_input()
	var opened: Dictionary = await _backup_load_router.open_witnessed_backup_load(self)
	_load_pending = false
	_load_activation_focus_id = 0
	_sync_transport()
	var focused := get_viewport().gui_get_focus_owner()
	if not opened.get("ok", false) and source_identity == _pause_runtime_identity() and _load_admitted() \
			and (focused == null or focused == transport_rail.get_node("Load")):
		transport_rail.get_node("Load").grab_focus()

func _save_admitted() -> bool:
	return _save_input_bound and not _load_pending and not _history_pending and not _history_open \
		and not _pause_covered and not _line_waiting_for_text and _reading_recovery.is_empty() \
		and _has_caption() and transport_rail.is_visible_in_tree() and accept_input.is_source_admitted() \
		and is_instance_valid(_transport_bridge) and _transport_bridge.has_method("can_capture_reading_checkpoint") \
		and _transport_bridge.call("can_capture_reading_checkpoint") == true \
		and is_instance_valid(_backup_load_router) and _backup_load_router.has_method("can_open_witnessed_backup_save") \
		and _backup_load_router.call("can_open_witnessed_backup_save", self) == true

func _on_save_requested() -> void:
	if not _save_admitted(): return
	var source_identity := _pause_runtime_identity()
	_load_activation_focus_id = transport_rail.get_node("Save").get_instance_id()
	_load_pending = true
	_retire_transport()
	accept_input.retire_input()
	var opened: Dictionary = await _backup_load_router.call("open_witnessed_backup_save", self)
	_load_pending = false
	_load_activation_focus_id = 0
	_sync_transport()
	var focused := get_viewport().gui_get_focus_owner()
	if not opened.get("ok", false) and source_identity == _pause_runtime_identity() and _save_admitted() \
			and (focused == null or focused == transport_rail.get_node("Save")):
		transport_rail.get_node("Save").grab_focus()

func _history_admitted() -> bool:
	if not _history_input_bound or _load_pending or _history_pending or _history_open or _pause_covered \
			or _line_waiting_for_text or not _reading_recovery.is_empty() or not _has_caption() \
			or not transport_rail.is_visible_in_tree() or not accept_input.is_source_admitted(): return false
	return is_instance_valid(_transport_bridge) and _transport_bridge.has_method("get_reading_history") \
		and is_instance_valid(_backup_load_router) and _backup_load_router.has_method("can_open_witnessed_history") \
		and _backup_load_router.call("can_open_witnessed_history", self) == true

func _on_history_requested() -> void:
	if not _history_admitted() or not _configure_history_presentation(): return
	var history: Dictionary = _transport_bridge.call("get_reading_history")
	if not history.get("ok", false): return
	var source: Dictionary = history.value
	var captions: Array[String] = []
	for row: Variant in source.get("captions", []):
		if not row is Dictionary or typeof(row.get("text")) != TYPE_STRING or String(row.text).strip_edges().is_empty(): return
		captions.append(row.text)
	if captions.is_empty(): return
	_history_source = {"session_id": source.session_id, "frontier": source.frontier.duplicate(true)}
	var focused := get_viewport().gui_get_focus_owner()
	_load_activation_focus_id = focused.get_instance_id() if focused != null and _owns_caption_focus(focused) else 0
	_history_pending = true
	_retire_transport()
	accept_input.retire_input()
	var opened: Dictionary = await _backup_load_router.call("open_witnessed_history", self)
	_history_pending = false
	_load_activation_focus_id = 0
	if not opened.get("ok", false):
		_history_source.clear()
		_sync_transport()
		return
	_history_open = true
	if not _history_overlay.present(captions):
		await _on_history_close_requested()

func _history_overlay_admitted() -> bool:
	if not _history_open or _history_pending or _history_source.is_empty() \
			or not is_instance_valid(_backup_load_router) \
			or _backup_load_router.call("is_witnessed_history_open", self) != true: return false
	var current: Dictionary = _transport_bridge.call("get_reading_history")
	return current.get("ok", false) and current.value.get("session_id") == _history_source.session_id \
		and current.value.get("frontier") == _history_source.frontier

func _on_history_close_requested() -> void:
	if not _history_open or _history_pending: return
	_history_pending = true
	_history_overlay.set_interactive(false)
	var closed: Dictionary = await _backup_load_router.call("close_witnessed_history", self)
	_history_pending = false
	if not closed.get("ok", false):
		_history_overlay.set_interactive(true)
		return
	_history_open = false
	_history_source.clear()
	_history_overlay.dismiss()
	_sync_transport()
	_restore_load_focus.call_deferred()

func _configure_history_presentation() -> bool:
	return is_instance_valid(_history_overlay) and _history_overlay.configure(
		_caption_theme, _localization, _reading_input_owner, _history_overlay_admitted)

func _on_reading_session_changed() -> void:
	_refresh_reading_session.call_deferred()

func _refresh_reading_session() -> void:
	if not is_instance_valid(_transport_bridge) or not _transport_bridge.has_method("capture_current_line_presentation_frontier"): return
	if _presented_line == _transport_bridge.call("capture_current_line_presentation_frontier"): return
	_capture_presented_line()
	_acknowledge_visible_line()
	_sync_transport()

func _restore_load_focus() -> void:
	if _load_focus_restore_id == 0: return
	if not _valid_pause_anchor(_pause_anchor) or not _reading_recovery.is_empty():
		_load_focus_restore_id = 0
		return
	if _pause_covered or not is_instance_valid(_reading_input_owner) \
			or not _reading_input_owner.is_source_input_admitted(): return
	var focused := get_viewport().gui_get_focus_owner()
	var command := instance_from_id(_load_focus_restore_id) as Control
	var admitted := (command == transport_rail.get_node("Load") and _load_admitted()) \
		or (command == transport_rail.get_node("Save") and _save_admitted()) \
		or (command == transport_rail.get_node("History") and _history_admitted())
	if admitted and (focused == null or focused == command):
		command.grab_focus()
	_load_focus_restore_id = 0

func _on_reading_profile_restored(_snapshot: Dictionary) -> void:
	_cancel_speech()
	_reading_owner_generation += 1

func _reading_profile_revision() -> int:
	return int(_reading_profile.call("get_profile_revision")) \
		if is_instance_valid(_reading_profile) and _reading_profile.has_method("get_profile_revision") else -1

func _skip_controller_admitted() -> bool:
	return _transport_admitted() or (_reading_retry_in_progress \
		and _reading_recovery.get("kind") == &"skip" and _recovery_action_admitted())

func _auto_controller_admitted() -> bool:
	return _auto_timer_admitted() or (_reading_retry_in_progress \
		and _reading_recovery.get("kind") == &"auto" and _recovery_action_admitted())

func _auto_button_admitted() -> bool:
	return _review_offset == 0 and _auto_configured and _auto_input_bound and not _pause_covered \
		and not _line_waiting_for_text and _presented_line.get("ok", false) \
		and transport_rail.is_visible_in_tree() and accept_input.is_source_admitted() \
		and is_instance_valid(_transport_bridge) \
		and _presented_line == _transport_bridge.call("capture_current_line_presentation_frontier")

func _auto_timer_admitted() -> bool:
	return _auto_button_admitted() and is_instance_valid(_reading_input_owner) \
		and _reading_input_owner.get_physical_contacts().is_empty()

func _try_arm_auto() -> void:
	if _auto_configured and not caption_text.revealing and _auto_timer_admitted():
		auto_controller.arm_after_reveal(_presented_line)

func _on_auto_state_changed() -> void:
	_auto_resume_pending = true
	_sync_transport()

func _on_text_finished(_info: Dictionary) -> void:
	_on_auto_state_changed()

func _on_auto_requested() -> void:
	if _auto_button_admitted():
		_request_reading_command(&"auto", not auto_controller.is_auto_enabled())

func _on_normal_accept_requested() -> void:
	auto_controller.retire_current()
	_retire_transport()
	# Text's own coroutine settles after this signal and before the deferred arm.
	_try_arm_auto.call_deferred()

func _on_playback_ended() -> void:
	reset_caption_stack()
	_dismiss_reading_recovery(false)
	auto_controller.retire_current()
	_retire_transport()

func _sync_transport() -> void:
	if not is_instance_valid(transport_rail): return
	var rehearsal := is_instance_valid(_transport_bridge) \
		and _transport_bridge.has_method("is_rehearsal_playback") \
		and bool(_transport_bridge.call("is_rehearsal_playback"))
	transport_rail.visible = not rehearsal
	transport_rail.project(_transport_admitted(), skip_controller.is_skip_active(),
		skip_controller.is_auto_enabled(), _auto_button_admitted(), _load_admitted(), _history_admitted(), _save_admitted())
	var ring: Array[Control] = [review_current if _review_offset > 0 else caption_text]
	var names: PackedStringArray = []
	if is_instance_valid(_dating_split_surface) and is_dating_split_input_admitted():
		var handle: Control = _dating_split_surface.get_split_handle()
		if is_instance_valid(handle) and handle.is_visible_in_tree() and handle.focus_mode != Control.FOCUS_NONE:
			ring.append(handle)
			names.append("Split:%d" % handle.get_instance_id())
	for name: String in ["History", "Skip", "Auto", "Save", "Load"]:
		var command: Control = transport_rail.get_node(name)
		if command.focus_mode != Control.FOCUS_NONE:
			ring.append(command)
			names.append(name)
	var focus_key := ("review:" if _review_offset > 0 else "live:") + ",".join(names)
	if focus_key == _rail_focus_key: return
	_rail_focus_key = focus_key
	for index: int in ring.size():
		ring[index].focus_next = ring[index].get_path_to(ring[(index + 1) % ring.size()]) if ring.size() > 1 else NodePath()
		ring[index].focus_previous = ring[index].get_path_to(ring[posmod(index - 1, ring.size())]) if ring.size() > 1 else NodePath()

func _on_skip_requested() -> void:
	if _transport_admitted():
		_request_reading_command(&"skip", not skip_controller.is_skip_active())

func _request_reading_command(kind: StringName, target: bool) -> void:
	if not _recovery_bound or not _reading_recovery.is_empty(): return
	_cancel_speech()
	var focused := get_viewport().gui_get_focus_owner()
	var request := {"kind": kind, "target": target, "frontier": _presented_line.duplicate(true),
		"profile_id": _reading_profile.get_instance_id(), "bridge_id": _transport_bridge.get_instance_id(),
		"profile_revision": _reading_profile_revision(), "owner_generation": _reading_owner_generation,
		"runtime": _pause_runtime_identity(), "focus_id": focused.get_instance_id() if focused != null else 0,
		"focus_behavior": canvas.focus_behavior_recursive, "mouse_behavior": canvas.mouse_behavior_recursive}
	var result: Dictionary = _execute_reading_command(request)
	if not result.get("ok", false) and _reading_request_matches(request):
		_reading_recovery = request
		_show_reading_failure(result)
	_sync_transport()

func _execute_reading_command(request: Dictionary) -> Dictionary:
	if request.kind == &"auto": return auto_controller.set_auto_enabled(request.target)
	return skip_controller.set_skip_active(request.target)

func _reading_request_matches(request: Dictionary) -> bool:
	if request.is_empty(): return false
	var revision := _reading_profile_revision()
	# The retry may commit exactly one Auto preference before Skip rechecks admission.
	var revision_matches: bool = revision == request.profile_revision or (_reading_retry_in_progress \
		and request.profile_revision >= 0 and revision == request.profile_revision + 1)
	return not request.is_empty() and is_instance_valid(_reading_profile) \
		and revision_matches and request.owner_generation == _reading_owner_generation \
		and is_instance_valid(_transport_bridge) and request.profile_id == _reading_profile.get_instance_id() \
		and request.bridge_id == _transport_bridge.get_instance_id() and not _line_waiting_for_text \
		and request.frontier == _presented_line and request.runtime == _pause_runtime_identity() \
		and request.frontier == _transport_bridge.call("capture_current_line_presentation_frontier")

func _recovery_action_admitted() -> bool:
	return not _pause_covered and not get_tree().paused and _reading_request_matches(_reading_recovery) \
		and not _reading_recovery.get("fatal", false) and is_instance_valid(_reading_input_owner) \
		and _reading_input_owner.is_source_input_admitted()

func _show_reading_failure(result: Dictionary) -> void:
	_reading_recovery["fatal"] = bool(result.get("fatal", false)) or String(result.get("code", "")) \
		in ["indeterminate_commit", "indeterminate_transaction", "APPLICATION_FATAL"]
	accept_input.retire_input()
	_retire_transport()
	canvas.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	canvas.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	canvas.set("accessibility_withdrawn", true)
	_sync_native_processing()
	_sync_focus()
	_configure_recovery_presentation()
	recovery_overlay.present(not _reading_recovery.fatal, not _reading_recovery.fatal)

func _retry_reading_command() -> void:
	if _reading_retry_in_progress or not _recovery_action_admitted(): return
	var retained := _reading_recovery.duplicate(true)
	_reading_retry_in_progress = true
	var result := _execute_reading_command(retained)
	var still_current := _reading_request_matches(retained)
	_reading_retry_in_progress = false
	# Profile publication can synchronously replace the whole scene/source.
	if not still_current:
		_dismiss_reading_recovery(false)
	else:
		_reading_recovery.profile_revision = _reading_profile_revision()
		if result.get("ok", false):
			_dismiss_reading_recovery()
		else:
			_show_reading_failure(result)
	_sync_transport()

func _cancel_reading_recovery() -> void:
	if _reading_retry_in_progress or not _recovery_action_admitted(): return
	_dismiss_reading_recovery()

func _dismiss_reading_recovery(restore_focus: bool = true) -> void:
	if _reading_recovery.is_empty(): return
	var retained := _reading_recovery
	_reading_recovery = {}
	recovery_overlay.dismiss()
	canvas.focus_behavior_recursive = retained.focus_behavior
	canvas.mouse_behavior_recursive = retained.mouse_behavior
	canvas.set("accessibility_withdrawn", false)
	accept_input.retire_input()
	transport_rail.retire_input()
	if not restore_focus: _had_caption = false
	_sync_native_processing()
	_sync_focus()
	_sync_transport()
	_auto_resume_pending = true
	if is_instance_valid(_dating_split_surface):
		_dating_split_surface.set_split_input_admission(is_dating_split_input_admitted)
	if restore_focus and _reading_request_matches(retained):
		var focused: Object = instance_from_id(int(retained.focus_id)) if int(retained.focus_id) != 0 else null
		if focused is Control and _owns_caption_focus(focused) and focused.is_visible_in_tree() \
				and focused.focus_mode != Control.FOCUS_NONE:
			focused.grab_focus()
		elif caption_text.focus_mode != Control.FOCUS_NONE: caption_text.grab_focus()

func _configure_recovery_presentation() -> void:
	if is_instance_valid(recovery_overlay) and _recovery_bound:
		recovery_overlay.configure_presentation(_locale, _text_percent, _palette,
			_high_contrast, _colour_preset, _large_targets, _font_style)

func _retire_transport() -> void:
	_cancel_speech()
	_auto_resume_pending = true
	if is_instance_valid(auto_controller): auto_controller.suspend_current()
	if is_instance_valid(skip_controller): skip_controller.stop_skip()
	if is_instance_valid(transport_rail): transport_rail.retire_input()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_retire_transport()

func configure_run_presentation(owner: Object) -> bool:
	var context := RUN_PRESENTATION.read(owner)
	if context.is_empty(): return false
	if not configure_presentation(_locale, _text_percent, context.palette,
			_high_contrast, _colour_preset, _large_targets, context.day, _font_style): return false
	_run_owner = owner
	return true

func _on_timeline_started() -> void:
	_dismiss_reading_recovery(false)
	_retire_transport()
	# A reused layout observes the installed run at this boundary, never during reveal.
	var owner: Object = _run_owner if is_instance_valid(_run_owner) else get_node_or_null("/root/GameState")
	configure_run_presentation(owner)
	reset_caption_stack()

func is_reading_recovery_active() -> bool:
	return not _reading_recovery.is_empty()

## Transient navigation anchor only. Canonical source admission belongs to the coordinator.
func capture_pause_view(source: Dictionary) -> Dictionary:
	if (source.is_empty() or not is_inside_tree() or not is_node_ready() or _pause_covered
		or is_reading_recovery_active() or not canvas.is_visible_in_tree() or not _has_caption()):
		return {"ok":false,"code":&"pause_view_unavailable","value":{}}
	_pause_capture_id += 1
	_pause_anchor = {"view_id":get_instance_id(),"capture_id":_pause_capture_id,"source":source.duplicate(true)}
	var focused := get_viewport().gui_get_focus_owner()
	var focus_id := focused.get_instance_id() if focused != null and _owns_caption_focus(focused) else 0
	if _load_pending or _history_pending: focus_id = _load_activation_focus_id
	_pause_view = {"caption_id":caption_text.get_instance_id(),"reveal_generation":caption_text.get_reveal_generation(),
		"runtime":_pause_runtime_identity(),"focus_id":focus_id,"scroll":get_scroll_bar().value,
		"canvas_visible":canvas.visible,"layer_processing":is_processing(),"caption_processing":caption_text.is_processing()}
	return {"ok":true,"code":&"ok","value":_pause_anchor.duplicate(true)}

func cover_pause_view(anchor: Dictionary) -> bool:
	if not _valid_pause_anchor(anchor): return false
	if _pause_covered: return true
	_pause_covered = true
	recovery_layer.hide()
	_retire_transport()
	accept_input.cancel_pending_accept()
	# Ancestor visibility hides the complete source from pointer and assistive traversal,
	# without assigning empty text or changing the native node's own visibility flag.
	canvas.hide()
	_sync_focus()
	caption_text.set_process(false)
	set_process(false)
	return true

func restore_pause_view(anchor: Dictionary) -> bool:
	if not _valid_pause_anchor(anchor): return false
	if not _pause_covered: return true
	_pause_covered = false
	recovery_layer.show()
	canvas.visible = bool(_pause_view.canvas_visible)
	_sync_focus()
	if is_instance_valid(_dating_split_surface):
		_dating_split_surface.set_split_input_admission(is_dating_split_input_admitted)
	var focused: Object = instance_from_id(int(_pause_view.focus_id)) if int(_pause_view.focus_id) != 0 else null
	if (focused is Control and _owns_caption_focus(focused) and focused.is_visible_in_tree()
		and focused.focus_mode != Control.FOCUS_NONE):
		focused.grab_focus()
	if focused in [transport_rail.get_node("History"), transport_rail.get_node("Save"), transport_rail.get_node("Load")]:
		_load_focus_restore_id = int(_pause_view.focus_id)
	# Focus restoration and container settling must never replace the user's pan.
	_layout_generation += 1
	_publication_pending = false
	_scroll_restore_waiting = false
	_scroll_restore_retries = 3
	var retained_scroll := float(_pause_view.scroll)
	get_scroll_bar().value = clampf(retained_scroll,0,maxf(0,get_scroll_bar().max_value-get_scroll_bar().page))
	call_deferred("_restore_scroll",_layout_generation,retained_scroll,false)
	caption_text.set_process(bool(_pause_view.caption_processing) and caption_text.is_visible_in_tree())
	set_process(bool(_pause_view.layer_processing))
	if not _reading_recovery.is_empty():
		_sync_native_processing()
		recovery_overlay.present(not _reading_recovery.fatal, not _reading_recovery.fatal)
	return true

func _valid_pause_anchor(anchor: Dictionary) -> bool:
	return (is_inside_tree() and is_node_ready() and not _pause_anchor.is_empty() and anchor == _pause_anchor
		and is_instance_valid(caption_text) and int(_pause_view.caption_id) == caption_text.get_instance_id()
		and int(_pause_view.reveal_generation) == caption_text.get_reveal_generation()
		and _pause_view.runtime == _pause_runtime_identity())

func _pause_runtime_identity() -> Dictionary:
	var runtime := get_node_or_null("/root/Dialogic")
	if runtime == null: return {}
	return {"instance_id":runtime.get_instance_id(),
		"generation":int(runtime.call("get_timeline_generation")) if runtime.has_method("get_timeline_generation") else 0,
		"event_index":runtime.get("current_event_idx")}

func _refresh_dating_overlay() -> void:
	var source: Dictionary = _scene_art_bridge.get_current_scene_art() if is_instance_valid(_scene_art_bridge) \
		and _scene_art_bridge.has_method("get_current_scene_art") else {}
	configure_dating_overlay(str(source.get("entry_id", "")).begins_with("dating."))

func configure_dating_overlay(enabled: bool) -> void:
	_bind_dating_split_surface()
	if _dating_overlay == enabled: return
	_dating_overlay = enabled
	if not is_instance_valid(canvas): return
	for leaf: RichTextLabel in [older, previous, review_current, caption_text]:
		leaf.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if enabled else HORIZONTAL_ALIGNMENT_LEFT
	configure_presentation(_locale, _text_percent, _palette, _high_contrast, _colour_preset, _large_targets, _day, _font_style)
	_layout_stack()

func _bind_dating_split_surface() -> void:
	if not is_inside_tree(): return
	# Only the sibling Dialogic art layer belongs to this caption owner. A retained
	# physical challenge or art-only hold must keep its own input admission.
	for surface: Node in get_tree().get_nodes_in_group("dating_split_surface"):
		var layer := surface.get_parent()
		if layer == null or layer.get_parent() != get_parent() or layer.get_script() == null \
				or layer.get_script().resource_path != "res://scripts/ui/witnessed/WitnessedArtLayer.gd": continue
		_dating_split_surface = surface as Control
		_dating_split_surface.set_split_input_admission(is_dating_split_input_admitted)
		return

func is_dating_split_input_admitted() -> bool:
	return _dating_overlay and not _pause_covered and _reading_source_admitted() \
		and is_instance_valid(canvas) and canvas.is_visible_in_tree() \
		and is_instance_valid(accept_input) and accept_input.is_source_admitted()

func _owns_caption_focus(control: Control) -> bool:
	return canvas.is_ancestor_of(control) or (is_instance_valid(_dating_split_surface) \
		and control == _dating_split_surface.get_split_handle())

func _forward_split_input(event: InputEvent, source_control: Control) -> bool:
	if not is_instance_valid(_dating_split_surface): return false
	if not is_dating_split_input_admitted():
		_dating_split_surface.cancel_split_input()
		return false
	if not _dating_split_surface.handle_split_input(event, source_control): return false
	accept_input.cancel_pending_accept()
	_retire_transport()
	source_control.accept_event()
	return true

func configure_presentation(locale: String = "en", text_percent: int = 100, palette: String = "AfterHours", high_contrast: bool = false, colour_preset: String = "standard", large_targets: bool = false, day: int = 1, font_style: String = "pixel") -> bool:
	var next_theme := CAPTION_THEME.build(locale, text_percent, palette, high_contrast, colour_preset, large_targets, day, _dating_overlay, font_style)
	if next_theme == null:
		return false
	# Caption and rail publish one locale tuple. Refusal leaves both unchanged.
	if is_instance_valid(transport_rail) and not transport_rail.configure_presentation(next_theme, locale):
		return false
	var metrics_changed := _caption_theme == null or _locale != locale.replace("_", "-") or _text_percent != text_percent or _large_targets != large_targets or _font_style != font_style
	_locale = locale.replace("_", "-")
	_text_percent = text_percent
	_font_style = font_style
	_palette = palette
	_day = day
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_large_targets = large_targets
	_caption_theme = next_theme
	_configure_speech_status()
	_configure_history_presentation()
	if is_instance_valid(canvas):
		var first_mount := canvas.theme == null
		if metrics_changed:
			var bar := get_scroll_bar()
			if bar.visible:
				# Native ScrollBar retires its held drag on hide. Restore visibility
				# synchronously before layout, keeping its value and focus owner.
				bar.hide()
				bar.show()
		canvas.theme = next_theme
		# Colour-only updates preserve native reveal, scroll and pending contacts.
		if metrics_changed or first_mount:
			_retire_transport()
			accept_input.cancel_pending_accept()
			_layout_stack()
		canvas.queue_redraw()
		overlay.queue_redraw()
		caption_text.queue_redraw()
	return true

func reset_caption_stack() -> void:
	var was_reviewing := _review_offset > 0
	_cancel_speech()
	if is_instance_valid(auto_controller): auto_controller.retire_current()
	_line_waiting_for_text = true
	_presented_line.clear()
	_retained.clear()
	_scrollback.clear()
	_review_offset = 0
	if is_instance_valid(accept_input): accept_input.set_review_caption(null)
	if was_reviewing and is_instance_valid(caption_text) and not caption_text.get_parsed_text().is_empty():
		caption_text.show()
	_current_copy = ""
	_publication_pending = false
	if is_instance_valid(stack):
		_layout_stack()

func reproject_retained_captions(captions: Array) -> bool:
	if captions.size() > 2:
		return false
	for copy: Variant in captions:
		if typeof(copy) != TYPE_STRING or String(copy).strip_edges().is_empty():
			return false
	if _review_offset > 0: _set_review_offset(0)
	_cancel_speech()
	_retained.assign(captions)
	_scrollback.assign(captions)
	_review_offset = 0
	accept_input.set_review_caption(null)
	if is_instance_valid(stack):
		_current_copy = caption_text.get_parsed_text()
		_layout_stack()
	return true

func get_scroll_bar() -> VScrollBar:
	return scroll.get_v_scroll_bar() if is_instance_valid(scroll) else null

func get_caption_projection() -> Dictionary:
	var mounted := is_instance_valid(caption_text)
	var bar := get_scroll_bar()
	var leaves: Array[Rect2] = []
	var visible_leaves: Array[Rect2] = []
	if mounted:
		for leaf: RichTextLabel in [older, previous, review_current, caption_text]:
			if not leaf.visible or leaf.get_parsed_text().is_empty():
				continue
			var rect := _leaf_rect(leaf)
			leaves.append(rect)
			var visible_rect := rect.intersection(_field_rect())
			if visible_rect.has_area():
				visible_leaves.append(visible_rect)
	var current_rect := _leaf_rect(caption_text) if mounted else Rect2()
	return {
		"locale": _locale, "text_percent": _text_percent, "palette": _palette, "day": _day,
		"high_contrast": _high_contrast, "colour_preset": _colour_preset,
		"large_targets": _large_targets,
		"dating_overlay": _dating_overlay,
		"font_style": _font_style,
		"font_size": _caption_theme.default_font_size if _caption_theme != null else 0,
		"text": caption_text.get_parsed_text() if mounted else "",
		"visible_characters": caption_text.visible_characters if mounted else 0,
		"total_characters": caption_text.get_total_character_count() if mounted else 0,
		"revealing": caption_text.revealing and _has_caption() if mounted else false,
		"caption_visible": _has_caption() if mounted else false,
		"field_rect": _field_rect(), "caption_rect": current_rect,
		"caption_visible_rect": current_rect.intersection(_field_rect()) if mounted and _has_caption() else Rect2(),
		"retained_captions": _retained.duplicate(), "leaf_rects": leaves,
		"caption_window": _caption_window(), "review_offset": _review_offset,
		"visible_leaf_rects": visible_leaves,
		"scroll_offset": bar.value if bar != null else 0.0,
		"scroll_extent": maxf(0.0, bar.max_value - bar.page) if bar != null else 0.0,
	}

func _on_about_to_show_text(_info: Dictionary) -> void:
	if not _current_copy.is_empty():
		_current_copy = caption_text.get_parsed_text()
		if caption_text.visible_characters >= 0:
			_current_copy = _current_copy.left(caption_text.visible_characters)
	_cancel_speech()
	_dismiss_reading_recovery(false)
	auto_controller.retire_current()
	# Old caption text can remain in the node until the next text_started signal.
	# It must not borrow legacy admission while the replacement has no proof yet.
	_line_waiting_for_text = true
	_presented_line.clear()
	# A press or queued assistive action belongs to its presented beat. The Skip
	# session itself may continue across ordinary text through the bridge policy.
	if is_instance_valid(transport_rail): transport_rail.retire_input()
	# Runs before replacement, catching a clear even when its native node was already hidden.
	if caption_text.get_parsed_text().is_empty():
		reset_caption_stack()
	_speech_candidate = true

func _on_text_started(info: Dictionary) -> void:
	if not _has_caption():
		return
	if not bool(info.get("append", false)) and not _current_copy.is_empty():
		_scrollback.append(_current_copy)
		_retained.append(_current_copy)
		if _retained.size() > 2:
			_retained.pop_front()
	# Only already-parsed display text crosses this seam; never character/portrait data.
	_current_copy = caption_text.get_parsed_text()
	_review_offset = 0
	accept_input.set_review_caption(null)
	_layout_stack(true)
	_capture_presented_line()
	_acknowledge_visible_line()
	if _speech_candidate:
		_speech_pending = true
		_speak_publication.call_deferred(_speech_generation)

func _on_caption_visibility_changed() -> void:
	if not caption_text.is_visible_in_tree(): _cancel_speech()
	if is_instance_valid(transport_rail): transport_rail.retire_input()
	_sync_native_processing()
	if caption_text.get_parsed_text().is_empty():
		_retained.clear()
		_scrollback.clear()
		_review_offset = 0
		accept_input.set_review_caption(null)
		_current_copy = ""
		_publication_pending = false
		older.hide()
		previous.hide()
	_sync_focus()
	_request_layout()

func _sync_native_processing() -> void:
	if _review_offset > 0 or _pause_covered or not _reading_recovery.is_empty():
		caption_text.set_process(false)
		return
	if caption_text.get_parsed_text().is_empty():
		# Native empty clears can leave revealing true; cancellation must emit no finish.
		caption_text.revealing = false
		caption_text.visible_characters = -1
		caption_text.set_process(false)
		if not _retained.is_empty() or not _current_copy.is_empty():
			_retained.clear()
			_scrollback.clear()
			_review_offset = 0
			accept_input.set_review_caption(null)
			_current_copy = ""
			_publication_pending = false
			older.hide()
			previous.hide()
			_request_layout()
	else:
		# Hidden real text pauses without discarding its native reveal position.
		caption_text.set_process(caption_text.is_visible_in_tree())

func _apply_preferences() -> void:
	var locale := str(_localization.call("get_locale")) if _localization != null and _localization.has_method("get_locale") else _locale
	var text_size: Variant = _profile.call("get_preference", &"preferences.accessibility.text_size", 100) if _profile != null and _profile.has_method("get_preference") else _text_percent
	if typeof(text_size) != TYPE_INT or text_size not in [100, 125, 150]:
		return
	var high_contrast: Variant = _high_contrast
	var large_targets: Variant = _large_targets
	var colour_preset := _colour_preset
	var font_style: Variant = _font_style
	if _profile != null and _profile.has_method("get_preference"):
		high_contrast = _profile.call("get_preference", &"preferences.accessibility.high_contrast", false)
		large_targets = _profile.call("get_preference", &"preferences.accessibility.large_targets", false)
		font_style = _profile.call("get_preference", &"preferences.accessibility.font_style", "pixel")
		var colour_mode: Variant = _profile.call("get_preference", &"preferences.accessibility.colour_differentiation", "standard")
		if typeof(colour_mode) != TYPE_STRING or not PROFILE_COLOUR_PRESETS.has(colour_mode):
			return
		colour_preset = PROFILE_COLOUR_PRESETS[colour_mode]
	if typeof(high_contrast) != TYPE_BOOL or typeof(large_targets) != TYPE_BOOL or typeof(font_style) != TYPE_STRING:
		return
	configure_presentation(locale, int(text_size), _palette, high_contrast, colour_preset, large_targets, _day, font_style)

func _on_locale_changed(_locale_id: String) -> void:
	_cancel_speech()
	_apply_preferences()
	_configure_recovery_presentation()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path in [&"preferences.reading.read_aloud_enabled", &"preferences.reading.read_aloud_rate"]:
		_cancel_speech()
	if path in [&"preferences.accessibility.text_size", &"preferences.accessibility.font_style", &"preferences.accessibility.high_contrast", &"preferences.accessibility.colour_differentiation", &"preferences.accessibility.large_targets"]:
		_apply_preferences()
		_configure_recovery_presentation()

func _process(_delta: float) -> void:
	if (_speech_pending or not _speech_source.is_empty()) and not _speech_admitted(): _cancel_speech()
	if not _reading_recovery.is_empty() and not _reading_request_matches(_reading_recovery):
		_dismiss_reading_recovery(false)
	_sync_transport()
	_restore_load_focus()
	if not _auto_timer_admitted():
		_auto_resume_pending = true
	elif _auto_resume_pending:
		_auto_resume_pending = false
		_try_arm_auto.call_deferred()
	if _caption_theme == null:
		return
	_sync_native_processing()
	if _scroll_restore_waiting:
		_scroll_restore_waiting = false
		_restore_scroll(_layout_generation, _scroll_restore_value, _publication_pending)
	if caption_text.text != _last_text or caption_text.get_content_height() != _last_content_height:
		_request_layout()
	_sync_focus()

func _request_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	call_deferred("_settle_layout")

func _settle_layout() -> void:
	_layout_pending = false
	_layout_stack()

func _layout_stack(publication: bool = false, desired_scroll: float = -1.0) -> void:
	if not is_instance_valid(stack) or _caption_theme == null:
		return
	_publication_pending = _publication_pending or publication
	var retained_scroll := get_scroll_bar().value if desired_scroll < 0 else desired_scroll
	scroll.position = Vector2(16, FIELD_TOP[_text_percent])
	scroll.size = Vector2(1248, FIELD_BOTTOM - FIELD_TOP[_text_percent])
	var window := _caption_window()
	older.text = window[0] if window.size() == 3 else ""
	previous.text = window[window.size() - 2] if window.size() >= 2 else ""
	review_current.text = window.back() if _review_offset > 0 and not window.is_empty() else ""
	older.visible = _has_caption() and window.size() == 3
	previous.visible = _has_caption() and window.size() >= 2
	review_current.visible = _has_caption() and _review_offset > 0
	var leaves: Array[RichTextLabel] = []
	for leaf: RichTextLabel in [older, previous, review_current, caption_text]:
		if leaf.visible and not leaf.get_parsed_text().is_empty():
			leaves.append(leaf)
	var width := 1248.0
	var left_inset := 0.0
	var total := _measure_leaves(leaves, width)
	if total > scroll.size.y:
		var gutter := get_scroll_bar().get_combined_minimum_size().x
		left_inset = gutter if _dating_overlay else 0.0
		width -= gutter + left_inset
		total = _measure_leaves(leaves, width)
	var cursor := maxf(0, scroll.size.y - total)
	for leaf: RichTextLabel in leaves:
		leaf.position = Vector2(left_inset, cursor)
		cursor += leaf.size.y
	stack.custom_minimum_size = Vector2(0, maxf(scroll.size.y, total))
	stack.update_minimum_size()
	stack.size = Vector2(width + left_inset, maxf(scroll.size.y, total))
	_last_text = caption_text.text
	_last_content_height = caption_text.get_content_height()
	_sync_focus()
	_layout_generation += 1
	_scroll_restore_waiting = false
	_scroll_restore_retries = 3
	call_deferred("_restore_scroll", _layout_generation, retained_scroll, publication)

func _measure_leaves(leaves: Array[RichTextLabel], width: float) -> float:
	var total := 0.0
	for leaf: RichTextLabel in leaves:
		leaf.size.x = width
		var minimum := 64 if _large_targets and leaf == caption_text else 52
		var height := maxi(minimum, int(ceil((leaf.get_content_height() + 32) / 2.0)) * 2)
		leaf.update_minimum_size()
		leaf.size = Vector2(width, height)
		total += leaf.size.y
	return total

func _restore_scroll(generation: int, value: float, publication: bool) -> void:
	if generation != _layout_generation:
		return
	var bar := get_scroll_bar()
	var expected_extent := maxf(0, stack.size.y - scroll.size.y)
	if not is_equal_approx(maxf(0, bar.max_value - bar.page), expected_extent):
		# Container range updates can follow this deferred callback. Keep publication
		# intent until a later frame sees the real range; never spin in deferred calls.
		if _scroll_restore_retries > 0:
			_scroll_restore_retries -= 1
			_scroll_restore_value = value
			_scroll_restore_waiting = true
		return
	if (publication or _publication_pending) and _has_caption():
		var top := caption_text.position.y
		var bottom := top + caption_text.size.y
		if caption_text.size.y > scroll.size.y or top < value:
			value = top
		elif bottom > value + scroll.size.y:
			value = bottom - scroll.size.y
	bar.value = clampf(value, 0, maxf(0, stack.size.y - scroll.size.y))
	_publication_pending = false

func _has_caption() -> bool:
	return (caption_text.visible or _review_offset > 0) and not caption_text.get_parsed_text().is_empty()

func _sync_focus() -> void:
	if _pause_covered or not _reading_recovery.is_empty():
		background_input.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption_text.focus_mode = Control.FOCUS_NONE
		review_current.focus_mode = Control.FOCUS_NONE
		if review_current.has_focus(): review_current.release_focus()
		caption_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if caption_text.has_focus(): caption_text.release_focus()
		return
	var has_caption := _has_caption()
	background_input.mouse_filter = Control.MOUSE_FILTER_STOP if has_caption else Control.MOUSE_FILTER_IGNORE
	var focused_caption: RichTextLabel = review_current if _review_offset > 0 else caption_text
	caption_text.focus_mode = Control.FOCUS_ALL if has_caption and _review_offset == 0 else Control.FOCUS_NONE
	review_current.focus_mode = Control.FOCUS_ALL if has_caption and _review_offset > 0 else Control.FOCUS_NONE
	caption_text.mouse_filter = Control.MOUSE_FILTER_STOP if has_caption and _review_offset == 0 else Control.MOUSE_FILTER_IGNORE
	if has_caption and not _had_caption:
		focused_caption.grab_focus()
	_had_caption = has_caption
	if not has_caption and caption_text.has_focus():
		caption_text.release_focus()

func _on_background_input(event: InputEvent) -> void:
	if _forward_split_input(event, background_input): return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_handle_input(event, false)
	else:
		accept_input.handle_background_gui_input(event, background_input)

func _on_passive_input(event: InputEvent, source_control: Control) -> void:
	_handle_input(event, false, source_control)

func _on_caption_input(event: InputEvent) -> void:
	_handle_input(event, true)

func _handle_input(event: InputEvent, current: bool, source_control: Control = null) -> void:
	if _pause_covered or not _reading_recovery.is_empty(): return
	if _forward_split_input(event, caption_text if current else (source_control if source_control != null else scroll)): return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		scroll.accept_event()
		return
	var bar := get_scroll_bar()
	if current and accept_input.handle_page_input(event):
		scroll.accept_event()
		return
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			accept_input.cancel_pending_accept()
			if accept_input.is_source_admitted():
				_set_review_offset(_review_offset + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if current: accept_input.handle_caption_gui_input(event)
			else: accept_input.handle_background_gui_input(event, source_control if source_control != null else scroll)
	elif event is InputEventPanGesture:
		accept_input.cancel_pending_accept()
		bar.value += event.delta.y * 20
	elif event is InputEventScreenTouch:
		if current: accept_input.handle_caption_gui_input(event)
		else: accept_input.handle_background_gui_input(event, source_control if source_control != null else scroll)
	elif event is InputEventScreenDrag:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			accept_input.cancel_pending_accept()
			bar.value -= event.relative.y
	else:
		return
	scroll.accept_event()

func _caption_window() -> Array[String]:
	if _review_offset == 0:
		var result := _retained.duplicate()
		if is_instance_valid(caption_text) and not caption_text.get_parsed_text().is_empty():
			result.append(caption_text.get_parsed_text())
		return result
	var end := _scrollback.size() - _review_offset
	return _scrollback.slice(maxi(0, end - 2), end + 1)

func _set_review_offset(value: int) -> void:
	var next := clampi(value, 0, maxi(0, _scrollback.size() - 2))
	if next == _review_offset: return
	if _review_offset == 0: _live_scroll = get_scroll_bar().value
	_review_offset = next
	_retire_transport()
	accept_input.cancel_pending_accept()
	review_current.visible = next > 0
	accept_input.set_review_caption(review_current if next > 0 else null)
	caption_text.visible = next == 0
	_layout_stack(false, 0.0 if next > 0 else _live_scroll)
	_sync_native_processing()
	(review_current if next > 0 else caption_text).grab_focus()

func _field_rect() -> Rect2:
	return Rect2(0, FIELD_TOP[_text_percent], 1280, FIELD_BOTTOM - FIELD_TOP[_text_percent])

func _leaf_rect(leaf: RichTextLabel) -> Rect2:
	return Rect2(scroll.position + stack.position + leaf.position, leaf.size)

func _draw_canvas() -> void:
	if _caption_theme == null:
		return
	if not _dating_overlay:
		canvas.draw_rect(_field_rect(), _color(&"field"))
	canvas.draw_rect(Rect2(0, FIELD_BOTTOM, 1280, 64), _color(&"deep"))

func _draw_seam() -> void:
	if _caption_theme != null and not _dating_overlay:
		overlay.draw_rect(Rect2(0, FIELD_TOP[_text_percent], 1280, 2), _color(&"rule"))

func _draw_current_frame() -> void:
	if _caption_theme == null or _dating_overlay:
		return
	var frame_size := caption_text.size
	# These rails and protected padding belong to the full leaf and scroll with it.
	caption_text.draw_rect(Rect2(0, 2, frame_size.x, 14), _color(&"current"))
	caption_text.draw_rect(Rect2(0, frame_size.y - 16, frame_size.x, 16), _color(&"current"))
	caption_text.draw_rect(Rect2(0, 2, 16, frame_size.y - 2), _color(&"current"))
	caption_text.draw_rect(Rect2(frame_size.x - 16, 2, 16, frame_size.y - 2), _color(&"current"))
	caption_text.draw_rect(Rect2(0, 0, frame_size.x, 2), _color(&"rule"))
	if caption_text.has_focus():
		caption_text.draw_rect(Rect2(Vector2(3, 3), frame_size - Vector2(6, 6)), _color(&"focus_outer"), false, 2)
		caption_text.draw_rect(Rect2(Vector2(7, 7), frame_size - Vector2(14, 14)), _color(&"focus_inner"), false, 2)

func _color(role: StringName) -> Color:
	return _caption_theme.get_color(role, &"WitnessedCaption")
