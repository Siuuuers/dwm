class_name DialogicRuntimeAdapter
extends RefCounted
## Low-level wrapper over ONLY the physically-audited Dialogic API (dwm-p2r.8, Plan-05 Task 2).
##
## Connects each audited signal exactly once, never serializes full addon state, and preserves the
## installed-version ordering `clear -> preference reapply -> first event` in start_timeline. It
## owns no semantic-checkpoint logic; the bridge builds those from the manifest. Restore-flow
## methods (prepare_runtime_restore/apply_restore/classify/advance) carry the minimal contract the
## Task-2 restore state machine wires and deepens.

signal timeline_started_signal
signal timeline_ended_signal
signal event_handled_signal(resource)
signal runtime_signal_event(argument)
signal preference_reapply_requested
signal playback_start_failed(result: Dictionary)
signal caption_publication_recorded(result: Dictionary)
signal reading_frontier_restored(result: Dictionary)

const CLEAR_KEEP_VARIABLES := 1
const REQUIRED_METHODS := ["start", "start_timeline", "end_timeline", "handle_next_event", "handle_event", "clear", "has_subsystem", "get_subsystem"]
const REQUIRED_SIGNALS := ["timeline_started", "timeline_ended", "event_handled", "signal_event"]
const REQUIRED_SUBSYSTEMS := {
	"Text": {"signals": ["text_started", "text_finished"], "methods": ["skip_text_reveal"]},
	"Choices": {"signals": ["question_shown", "choice_selected"], "methods": ["select_choice"]},
}

var _dialogic: Node = null
var _bound := false
var _activity_phase := ""
var _start_generation := 0
var _pending_layout: Node
var _pending_start: Callable
var _requested_path := ""
var _runtime_generation := 0
var _qualified_runtime := false
var _request_id := ""
var _caption_ledger: NarrativeCaptionLedger
var _caption_token := ""
var _caption_entry := ""
var _caption_request := ""
var _caption_generation := 0
var _caption_publication := ""
var _caption_event: DialogicTextEvent
var _caption_line := ""
var _caption_restore_frontier: Dictionary = {}
var _caption_restore_queued := false


func bind_runtime(dialogic: Node) -> Dictionary:
	if _bound:
		if dialogic == _dialogic:
			return {"ok": true, "code": &"ok", "value": {"already_bound": true}}
		return _fail(&"runtime_already_bound", "adapter is already bound to a runtime")
	if dialogic == null:
		return _fail(&"invalid_runtime", "dialogic runtime is null")
	for method in REQUIRED_METHODS:
		if not dialogic.has_method(method):
			return _fail(&"invalid_runtime", "missing method " + method)
	for signal_name in REQUIRED_SIGNALS:
		if not dialogic.has_signal(signal_name):
			return _fail(&"invalid_runtime", "missing signal " + signal_name)
	for subsystem_name in REQUIRED_SUBSYSTEMS:
		if not dialogic.has_subsystem(subsystem_name):
			return _fail(&"missing_subsystem", subsystem_name)
		var subsystem: Object = dialogic.get_subsystem(subsystem_name)
		if subsystem == null:
			return _fail(&"missing_subsystem", subsystem_name)
		for signal_name in REQUIRED_SUBSYSTEMS[subsystem_name]["signals"]:
			if not subsystem.has_signal(signal_name):
				return _fail(&"missing_subsystem", "%s.%s" % [subsystem_name, signal_name])
		for method in REQUIRED_SUBSYSTEMS[subsystem_name]["methods"]:
			if not subsystem.has_method(method):
				return _fail(&"missing_subsystem", "%s.%s" % [subsystem_name, method])
	if dialogic.has_signal("timeline_started_with_generation") or dialogic.has_signal("timeline_ended_with_generation"):
		if not (dialogic.has_signal("timeline_started_with_generation") and dialogic.has_signal("timeline_ended_with_generation") \
			and dialogic.has_method("get_timeline_generation") and dialogic.has_method("is_ending_timeline")):
			return _fail(&"invalid_runtime", "qualified lifecycle requires both signals and generation queries")
		_qualified_runtime = true
	_dialogic = dialogic
	_activity_phase = "live" if _dialogic.get("current_timeline") != null else ""
	if _qualified_runtime:
		_runtime_generation = int(dialogic.get_timeline_generation())
		if dialogic.is_ending_timeline(): _activity_phase = "stopping"
		_connect_once(dialogic, "timeline_started_with_generation", _on_qualified_timeline_started)
		_connect_once(dialogic, "timeline_ended_with_generation", _on_qualified_timeline_ended)
	else:
		_connect_once(dialogic, "timeline_started", _on_timeline_started)
		_connect_once(dialogic, "timeline_ended", _on_timeline_ended)
	_connect_once(dialogic, "event_handled", _on_event_handled)
	_connect_once(dialogic, "signal_event", _on_signal_event)
	_bound = true
	return {"ok": true, "code": &"ok", "value": {"already_bound": false}}


## Opt-in internal publication capture only. This is not visible-witness admission,
## Profile history, durable History, or a save participant. Bind before start():
## the installed runtime may publish its first caption synchronously.
func bind_caption_ledger(ledger: NarrativeCaptionLedger, token: String, entry_id: String) -> Dictionary:
	if not _bound or not _qualified_runtime or has_active_playback() or _caption_ledger != null:
		return _fail(&"caption_binding_unavailable", "no idle qualified publication slot")
	if ledger == null: return _fail(&"caption_ledger_missing", "ledger is required")
	var checked := ledger.check_session(token, entry_id)
	if not checked.ok: return checked
	var text: Object = _dialogic.get_subsystem("Text")
	if not text.has_signal("about_to_show_text"):
		return _fail(&"caption_publication_signal_missing", "publication start signal is required")
	_caption_ledger = ledger
	_caption_token = token
	_caption_entry = entry_id
	_connect_once(text, "about_to_show_text", _on_caption_about_to_show)
	_connect_once(text, "text_started", _on_caption_text_started)
	return {"ok": true}


func _caption_source_is_current() -> bool:
	return _caption_ledger != null and _activity_phase == "live" \
		and not _caption_request.is_empty() and _caption_request == _request_id \
		and _caption_generation == _runtime_generation \
		and _dialogic.get_timeline_generation() == _caption_generation \
		and not _dialogic.is_ending_timeline() and _dialogic.current_timeline != null \
		and str(_dialogic.current_timeline.resource_path) == _requested_path


func _on_caption_about_to_show(_info: Dictionary) -> void:
	if not _caption_source_is_current(): return
	_caption_event = _current_skip_text(true)
	_caption_line = _authored_line_id(_caption_event)
	if not _caption_restore_frontier.is_empty():
		if _caption_line != _caption_restore_frontier.line_id:
			_fail_reading_restore(_fail(&"reading_frontier_changed", "the resumed publication changed"))
			return
		_caption_publication = _caption_restore_frontier.publication_id
		return
	var allocated := _caption_ledger.allocate_publication(_caption_token, _caption_entry)
	_caption_publication = allocated.value if allocated.ok else ""


func _on_caption_text_started(_info: Dictionary) -> void:
	if not _caption_source_is_current(): return
	if _caption_event == null or _caption_event != _current_skip_text(true):
		caption_publication_recorded.emit(_fail(&"caption_publication_source_invalid", "no matching single-beat publication"))
		return
	# An authored #id identifies the registered semantic beat. The independent
	# opaque publication identity is reused if text_started is delivered twice.
	var result := _caption_ledger.publish_line(_caption_token, _caption_publication,
		_caption_entry, _caption_line)
	caption_publication_recorded.emit(result)
	if not _caption_restore_frontier.is_empty():
		if not result.ok or not result.value.get("duplicate", false):
			_fail_reading_restore(_fail(&"reading_frontier_occurrence_changed", "resume must reuse the saved occurrence"))
			return
		if not _caption_restore_queued:
			_caption_restore_queued = true
			# Native text_started precedes the text event's text_finished await.
			# A synchronous reveal here would strand that coroutine forever.
			_finish_reading_restore.call_deferred(_request_id, _caption_event)


func _retire_caption_binding() -> void:
	_caption_ledger = null
	_caption_token = ""
	_caption_entry = ""
	_caption_request = ""
	_caption_generation = 0
	_caption_publication = ""
	_caption_event = null
	_caption_line = ""
	_caption_restore_frontier = {}
	_caption_restore_queued = false


## Opt-in durable frontier. Publication identity comes from the session ledger;
## native event positions and runtime identities never cross this boundary.
## Pause/History may inspect it while the native runtime is suspended.
func can_capture_reading_frontier() -> bool:
	if not _caption_source_is_current() or is_reading_frontier_restoring() \
			or _caption_event == null or _caption_event != _current_skip_text(true) \
			or _authored_line_id(_caption_event) != _caption_line:
		return false
	return _caption_ledger.is_current_occurrence(_caption_token, _caption_entry,
		{"line_id": _caption_line, "publication_id": _caption_publication})


func capture_reading_frontier() -> Dictionary:
	if not can_capture_reading_frontier():
		return _fail(&"reading_frontier_unavailable", "no admitted semantic publication")
	return {"ok": true, "value": {"line_id": _caption_line, "publication_id": _caption_publication}}


func is_reading_frontier_restoring() -> bool:
	return not _caption_restore_frontier.is_empty()


## Save finishes only the current reveal, preserving the semantic boundary even
## when a choice follows. Recheck after reveal callbacks before returning proof.
func complete_reading_frontier() -> Dictionary:
	var before := capture_reading_frontier()
	if not before.ok: return before
	if _caption_event.state != DialogicTextEvent.States.DONE:
		var revealed := reveal_current_line(true)
		if not revealed.ok: return revealed
	var after := capture_reading_frontier()
	if not after.ok or after.value != before.value or _caption_event.state != DialogicTextEvent.States.DONE:
		return _fail(&"reading_frontier_changed", "reveal did not retain the current semantic boundary")
	return after


## Pure authored lookup for the owner's pre-install compatibility check. Its
## locator is supplied by the admitted entry manifest, never by the checkpoint.
func validate_reading_line(path: String, entry_label: String, line_id: String, expected_text: String = "") -> Dictionary:
	var checked := _resolve_reading_line(path, entry_label, line_id, expected_text)
	return {"ok": true} if checked.ok else checked


## This fixed-prose increment admits the whole native programme, not just its
## registered subset. A saved line may not skip an unregistered caption/effect.
func validate_reading_entry(path: String, entry_label: String, lines: Array) -> Dictionary:
	if path.is_empty() or entry_label.is_empty() or lines.is_empty() or not ResourceLoader.exists(path):
		return _fail(&"reading_entry_invalid", "an authored entry and ordered captions are required")
	var identifiers := {}
	for line: Variant in lines:
		if not line is Dictionary or not line.get("line_id") is String or line.line_id.is_empty() \
				or not line.get("text") is String or line.text.is_empty() or identifiers.has(line.line_id):
			return _fail(&"reading_entry_invalid", "the catalogue requires unique ordered captions")
		identifiers[line.line_id] = true
	var resource := load(path)
	if not resource is DialogicTimeline:
		return _fail(&"reading_entry_invalid", "the entry locator is not a timeline")
	var detached := DialogicTimeline.new()
	detached.from_text((resource as DialogicTimeline).as_text())
	detached.process()
	var selected := false
	var labels := 0
	var ordinal := 0
	var ended := false
	for event: DialogicEvent in detached.events:
		if event is DialogicLabelEvent:
			selected = event.name == entry_label
			if selected:
				labels += 1
				if labels > 1: return _fail(&"reading_entry_mismatch", "the entry label is ambiguous")
			continue
		if not selected or event is DialogicCommentEvent: continue
		if ended:
			return _fail(&"reading_entry_mismatch", "the entry contains events after its return")
		if event is DialogicReturnEvent:
			if ordinal != lines.size():
				return _fail(&"reading_entry_mismatch", "the entry returns before its registered captions")
			ended = true
			continue
		if not event is DialogicTextEvent or ordinal >= lines.size() \
				or _authored_line_id(event) != lines[ordinal].line_id or not _is_single_skip_line(event):
			return _fail(&"reading_entry_mismatch", "the native programme differs from its ordered catalogue")
		if not _reading_text_matches(event, lines[ordinal].text):
			return _fail(&"reading_line_content_mismatch", "the authored plain caption differs from its catalogue")
		ordinal += 1
	if labels != 1 or not ended or ordinal != lines.size():
		return _fail(&"reading_entry_mismatch", "the complete fixed entry must end with return")
	return {"ok": true}


func start_reading_frontier(path: String, frontier: Dictionary, entry_label: String = "") -> Dictionary:
	if not _bound or not _qualified_runtime or has_active_playback() or _caption_ledger == null:
		return _fail(&"reading_frontier_unavailable", "an idle bound caption session is required")
	var checked := _check_reading_occurrence(frontier)
	if not checked.ok: return checked
	var resolved := _resolve_reading_line(path, _caption_entry if entry_label.is_empty() else entry_label,
		frontier.line_id)
	if not resolved.ok: return resolved
	_caption_restore_frontier = frontier.duplicate(true)
	_caption_restore_queued = false
	var started := start_timeline(path, resolved.value)
	if not started.ok:
		_caption_restore_frontier = {}
		_caption_restore_queued = false
		return started
	return {"ok": true}


func _check_reading_occurrence(frontier: Dictionary) -> Dictionary:
	if _caption_ledger == null or frontier.size() != 2 \
			or not frontier.get("line_id") is String or str(frontier.line_id).is_empty() \
			or not frontier.get("publication_id") is String or str(frontier.publication_id).is_empty():
		return _fail(&"reading_frontier_invalid", "exact semantic line and occurrence are required")
	if not _caption_ledger.is_current_occurrence(_caption_token, _caption_entry, frontier):
		return _fail(&"reading_frontier_invalid", "the frontier must be the session's final occurrence")
	return {"ok": true}


func _resolve_reading_line(path: String, entry_label: String, line_id: String, expected_text: String = "") -> Dictionary:
	if path.is_empty() or entry_label.is_empty() or line_id.is_empty() or not ResourceLoader.exists(path):
		return _fail(&"reading_line_unavailable", "an authored entry and line are required")
	var resource := load(path)
	if not resource is DialogicTimeline:
		return _fail(&"reading_line_unavailable", "the entry locator is not a timeline")
	# Process a detached timeline: compatibility checks must not mutate cached
	# resources, a standing event coroutine, or the runtime's current event list.
	var detached := DialogicTimeline.new()
	detached.from_text((resource as DialogicTimeline).as_text())
	detached.process()
	var selected := false
	var labels := 0
	var found := -1
	for index: int in detached.events.size():
		var event: DialogicEvent = detached.events[index]
		if event is DialogicLabelEvent:
			selected = event.name == entry_label
			if selected: labels += 1
		elif selected and event is DialogicTextEvent and _authored_line_id(event) == line_id:
			if found >= 0 or not _is_single_skip_line(event):
				return _fail(&"reading_line_ambiguous", "the authored line must name one single-beat event")
			if not expected_text.is_empty() and not _reading_text_matches(event, expected_text):
				return _fail(&"reading_line_content_mismatch", "the authored plain caption differs from its catalogue")
			found = index
	if labels != 1 or found < 0:
		return _fail(&"reading_line_unavailable", "the line is absent from its unique entry label")
	return {"ok": true, "value": found}


func _reading_text_matches(event: DialogicTextEvent, expected_text: String) -> bool:
	# Do not execute the mutable variable/effect parser during pure validation.
	var prose := event.get_property_translated("text")
	return prose == expected_text and event.character == null and event.character_identifier.is_empty() \
		and not "[" in prose and not "{" in prose and not "<" in prose \
		and str(ProjectSettings.get_setting("dialogic/text/dialog_text_prefix", "")).is_empty()


func _finish_reading_restore(request_id: String, event: DialogicTextEvent) -> void:
	if not is_reading_frontier_restoring() or request_id != _request_id \
			or not _caption_source_is_current() or event != _current_skip_text(true): return
	var expected := _caption_restore_frontier.duplicate(true)
	var revealed := {"ok": true} if event.state == DialogicTextEvent.States.DONE else reveal_current_line(true)
	if not revealed.ok or not _caption_source_is_current() or event != _current_skip_text(true) \
			or event.state != DialogicTextEvent.States.DONE:
		_fail_reading_restore(_fail(&"reading_frontier_changed", "the resumed reveal did not retain its boundary"))
		return
	_caption_restore_frontier = {}
	_caption_restore_queued = false
	var captured := capture_reading_frontier()
	if not captured.ok or captured.value != expected:
		_fail_reading_restore(_fail(&"reading_frontier_changed", "the resumed occurrence changed"))
		return
	reading_frontier_restored.emit(captured)


func _fail_reading_restore(result: Dictionary) -> void:
	halt_with_error(result)
	reading_frontier_restored.emit(result)
	playback_start_failed.emit(result)


## Task 5 (dwm-oyo.2 R-BB): widened to Dialogic's own two-argument vocabulary - the second
## argument is a String label to jump to or an int event index, exactly like
## DialogicGameHandler.start(timeline, label_or_idx). The default stays 0 so every existing int
## caller (the restore state machine) is byte-compatible.
func start_timeline(path: String, label_or_index: Variant = 0) -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	if path.is_empty():
		return _fail(&"invalid_timeline_path", "path is required")
	if has_active_playback():
		return _fail(&"runtime_playback_active", "complete or cancel the standing playback first")
	_start_generation += 1
	var generation := _start_generation
	_request_id = "%d:%d" % [get_instance_id(), generation]
	if _caption_ledger != null: _caption_request = _request_id
	_activity_phase = "starting"
	_requested_path = path
	_runtime_generation = 0
	_dialogic.clear(CLEAR_KEEP_VARIABLES)
	preference_reapply_requested.emit()
	if generation != _start_generation:
		return _fail(&"runtime_start_cancelled", "playback was cancelled during startup")
	var layout: Variant = _dialogic.start(path, label_or_index, _request_id) if _qualified_runtime else _dialogic.start(path, label_or_index)
	if generation != _start_generation:
		return _fail(&"runtime_start_cancelled", "playback was cancelled during startup")
	if _activity_phase == "starting":
		if is_instance_valid(layout) and layout is Node:
			_pending_layout = layout
			_pending_start = Callable(_dialogic, "start_timeline").bind(path, label_or_index)
			if _qualified_runtime: _pending_start = Callable(_dialogic, "start_timeline").bind(path, label_or_index, _request_id)
		if not is_instance_valid(layout) or not layout is Node or layout.is_node_ready():
			_retire_caption_binding()
			_activity_phase = ""
			_requested_path = ""
			_discard_pending_layout()
			return _fail(&"runtime_start_failed", "runtime did not start or admit a deferred layout")
		_pending_layout.ready.connect(_verify_pending_start.bind(generation),CONNECT_DEFERRED | CONNECT_ONE_SHOT)
		_pending_layout.tree_exited.connect(_pending_layout_exited.bind(generation),CONNECT_ONE_SHOT)
	return {"ok": true, "code": &"ok", "value": {"path": path, "label_or_index": label_or_index}}


## Frozen is a reserved, transient DTL namespace. The variable tree is read-only for
## this entry; gameplay changes still travel through acknowledged semantic signals.
var _frozen_variables_before: Dictionary = {}
var _frozen_variables_installed := false

func install_frozen_presentation(presentation: Dictionary) -> Dictionary:
	if not _bound or has_active_playback() or _frozen_variables_installed:
		return _fail(&"frozen_context_runtime_busy", "no idle presentation slot")
	if not presentation.get("fields") is Dictionary:
		return _fail(&"frozen_context_schema_mismatch", "fields must be a dictionary")
	var checked := preload("res://scripts/narrative/FrozenPresentationContext.gd").validate(
		str(presentation.get("fields", {}).get("entry_id", "")), presentation)
	if not checked.ok: return checked
	return _install_frozen_projection(checked.value)

## Historical replay has its own exact signature schema. It never borrows absent
## canonical receipts or prose selectors from the current Run.
func install_frozen_replay(signature: Dictionary, mode: String = "gallery_replay") -> Dictionary:
	if not _bound or has_active_playback() or _frozen_variables_installed:
		return _fail(&"frozen_context_runtime_busy", "no idle presentation slot")
	var checked := preload("res://scripts/narrative/FrozenReplayContext.gd").build(signature, mode)
	if not checked.ok: return checked
	return _install_frozen_projection(checked.value)

func _install_frozen_projection(presentation: Dictionary) -> Dictionary:
	var prior: Variant = _dialogic.current_state_info.get("variables", {})
	if not prior is Dictionary: return _fail(&"frozen_context_variables_invalid", "variables must be a dictionary")
	var fields: Dictionary = preload("res://scripts/narrative/FrozenPresentationContext.gd").immutable_fields(presentation)
	var projected: Dictionary = prior.duplicate(true)
	_frozen_variables_before = prior.duplicate(true)
	projected["Frozen"] = fields
	projected.make_read_only()
	_dialogic.current_state_info["variables"] = projected
	_frozen_variables_installed = true
	return {"ok": true}

func release_frozen_presentation() -> void:
	if not _frozen_variables_installed: return
	_dialogic.current_state_info["variables"] = _frozen_variables_before.duplicate(true)
	_frozen_variables_before = {}
	_frozen_variables_installed = false

func has_active_playback() -> bool:
	return _activity_phase != ""


func is_bound_to_runtime(runtime: Node) -> bool:
	return _bound and runtime == _dialogic


## Ephemeral reading frontier only. Startup, cleanup and non-text events cannot open Pause.
func capture_pause_frontier() -> Dictionary:
	if not _bound or not _qualified_runtime or _activity_phase != "live" \
		or _request_id.is_empty() or _requested_path.is_empty() or _dialogic.current_timeline == null \
		or _dialogic.is_ending_timeline():
		return _fail(&"pause_frontier_unavailable", "no admitted live reading frontier")
	var index := int(_dialogic.current_event_idx)
	if index < 0 or index >= _dialogic.current_timeline_events.size() \
		or not _dialogic.current_timeline_events[index] is DialogicTextEvent \
		or _dialogic.current_state not in [DialogicGameHandler.States.IDLE, DialogicGameHandler.States.REVEALING_TEXT]:
		return _fail(&"pause_frontier_unavailable", "the current event has no reading frontier")
	return {"ok": true, "code": &"ok", "value": {
		"generation": _runtime_generation, "event_index": index,
		"request_id": _request_id, "paused": bool(_dialogic.paused),
	}}


func _verify_pending_start(generation: int) -> void:
	if generation != _start_generation or _activity_phase != "starting":
		return
	_retire_caption_binding()
	_activity_phase = ""
	_requested_path = ""
	_discard_pending_layout()
	release_frozen_presentation()
	playback_start_failed.emit(_fail(&"runtime_start_failed", "ready layout did not start its timeline"))


func _pending_layout_exited(generation: int) -> void:
	_verify_pending_start(generation)


func _discard_pending_layout() -> void:
	if is_instance_valid(_pending_layout):
		if _pending_layout.ready.is_connected(_pending_start):
			_pending_layout.ready.disconnect(_pending_start)
		var clear_call := Callable(_dialogic,"clear").bind(CLEAR_KEEP_VARIABLES)
		if _pending_layout.ready.is_connected(clear_call):
			_pending_layout.ready.disconnect(clear_call)
		# A failure observer may retry synchronously. Styles must not reuse this layout.
		var tree := _dialogic.get_tree() if _dialogic.is_inside_tree() else null
		if tree != null and tree.get_meta("dialogic_layout_node", null) == _pending_layout:
			tree.remove_meta("dialogic_layout_node")
		# Styles already queued add_child. Let that mount finish before deletion.
		_pending_layout.call_deferred("queue_free")
	_pending_layout = null
	_pending_start = Callable()


func capture_checkpoint() -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	# Semantic cursor only; never Dialogic.get_full_state().
	return {"ok": true, "code": &"ok", "value": {
		"timeline_active": _dialogic.current_timeline != null,
		"current_event_idx": int(_dialogic.current_event_idx),
	}}


func capture_restore_state() -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"timeline_active": _dialogic.current_timeline != null,
		"current_event_idx": int(_dialogic.current_event_idx),
		"paused": bool(_dialogic.paused) if "paused" in _dialogic else false,
	}}}


func restore_captured_state(backup: Dictionary) -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	if typeof(backup) != TYPE_DICTIONARY:
		return _fail(&"invalid_backup", "backup must be a dictionary")
	if "paused" in _dialogic:
		_dialogic.paused = bool(backup.get("paused", false))
	return {"ok": true, "code": &"ok", "value": {}}


func halt_with_error(result: Dictionary) -> Dictionary:
	_retire_caption_binding()
	release_frozen_presentation()
	_start_generation += 1
	if _activity_phase == "starting":
		# Cancel only the queued native start this adapter admitted. No prose ran.
		_discard_pending_layout()
		_activity_phase = ""
	_requested_path = ""
	if _bound and _dialogic.current_timeline != null:
		_activity_phase = "stopping"
		_dialogic.end_timeline(true)
	return {"ok": false, "code": &"runtime_halted", "message": "timeline halted", "details": result.duplicate(true)}


func set_paused(value: bool) -> Dictionary:
	# Used by the before_event restore position to suspend the staged successor.
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	_dialogic.paused = value
	if bool(_dialogic.paused) != value:
		return _fail(&"runtime_pause_not_applied", "runtime pause readback did not match")
	return {"ok": true, "code": &"ok", "value": {"paused": value}}


func reveal_current_line(preserve_next_boundary: bool = false) -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	var text: Object = _dialogic.get_subsystem("Text")
	if text == null:
		return _fail(&"missing_subsystem", "Text")
	# Literal reveal count/tween state is intentionally not restored; finish the reveal instantly.
	if text.has_method("skip_text_reveal"):
		if preserve_next_boundary:
			_dialogic.set_meta(&"dwm_boundary_safe_skip_reveal", true)
		text.skip_text_reveal()
		if preserve_next_boundary:
			_dialogic.remove_meta(&"dwm_boundary_safe_skip_reveal")
	return {"ok": true, "code": &"ok", "value": {}}


## The authored #id is a semantic identity, never a path/index/prose-derived fallback.
## The bridge checks its registered owner before revealing or writing visited history.
func current_line_id() -> String:
	return _authored_line_id(_current_skip_text())


func _authored_line_id(event: DialogicTextEvent) -> String:
	if event == null:
		return ""
	var parts := event.get_property_translation_key("text").split("/")
	return parts[1] if parts.size() == 3 and parts[0] == "Text" and parts[2] == "text" else ""


func is_current_line_complete() -> bool:
	var event := _current_skip_text()
	return event != null and event.state == DialogicTextEvent.States.DONE


func _current_skip_text(allow_paused: bool = false) -> DialogicTextEvent:
	if not _bound or _activity_phase != "live" or _dialogic.current_timeline == null \
		or (_dialogic.paused and not allow_paused) or _dialogic.current_state not in [
			DialogicGameHandler.States.IDLE, DialogicGameHandler.States.REVEALING_TEXT]:
		return null
	var index := int(_dialogic.current_event_idx)
	if index < 0 or index >= _dialogic.current_timeline_events.size():
		return null
	var event: Resource = _dialogic.current_timeline_events[index]
	if not event is DialogicTextEvent or not _is_single_skip_line(event):
		return null
	return event


## A single text event may contain several separately revealed segments. Until those
## have individual authored identities, skip must not mark unseen segments as read.
func _is_single_skip_line(event: DialogicTextEvent) -> bool:
	var prose := event.get_property_translated("text")
	return not prose.strip_edges().is_empty() and not "[n]" in prose \
		and not "[n+]" in prose and not ("\n" in prose \
			and ProjectSettings.get_setting("dialogic/text/split_at_new_lines", false))


func classify_next_event() -> StringName:
	if _current_skip_text() == null:
		return &"validation_error"
	var index := int(_dialogic.current_event_idx) + 1
	if index >= _dialogic.current_timeline_events.size():
		return &"scene_transition"
	# Decode a detached copy: peeking never changes or executes the standing event.
	var next: Resource = _dialogic.current_timeline_events[index]
	if not next.event_node_ready:
		var source: String = next.event_node_as_text
		next = next.get_script().new()
		next._load_from_string(source)
	if next is DialogicTextEvent:
		return &"text" if _is_single_skip_line(next) else &"validation_error"
	if next is DialogicChoiceEvent:
		return &"choice"
	if next is DialogicVariableEvent:
		return &"variable_transaction"
	if next is DialogicEndTimelineEvent or next is DialogicReturnEvent or next is DialogicJumpEvent:
		return &"scene_transition"
	if next is DialogicSignalEvent and next.argument_type == DialogicSignalEvent.ArgumentTypes.DICTIONARY:
		var payload: Variant = JSON.parse_string(str(next.argument))
		if payload is Dictionary and payload.get("kind") in [
			"effect_transaction", "variable_transaction", "safe_marker", "scene_transition", "minesweeper_entry"]:
			return StringName(payload.kind)
	return &"validation_error"


func advance_one_event() -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	var current := _current_skip_text()
	if current == null or current.state != DialogicTextEvent.States.DONE:
		return _fail(&"no_current_line", "the revealed text frontier is no longer active")
	# Complete the real text coroutine, including its signal cleanup.
	current.advance.emit()
	return {"ok": true, "code": &"ok", "value": {"current_event_idx": int(_dialogic.current_event_idx)}}


func prepare_runtime_restore(checkpoint: Dictionary, manifest: Dictionary) -> Dictionary:
	# Pure: copies a detached restore plan. The participant state machine (Step 2.4) stages it.
	if typeof(checkpoint) != TYPE_DICTIONARY or checkpoint.is_empty():
		return _fail(&"invalid_checkpoint", "checkpoint is required")
	if typeof(manifest) != TYPE_DICTIONARY:
		return _fail(&"invalid_manifest", "manifest record is required")
	return {"ok": true, "code": &"ok", "value": {"plan": checkpoint.duplicate(true)}}


func apply_restore(plan: Dictionary) -> Dictionary:
	if not _bound:
		return _fail(&"runtime_not_bound", "bind_runtime must be called first")
	if typeof(plan) != TYPE_DICTIONARY:
		return _fail(&"invalid_plan", "plan is required")
	return {"ok": true, "code": &"ok", "value": {}}


func _connect_once(source: Object, signal_name: String, callable: Callable) -> void:
	if not source.is_connected(signal_name, callable):
		source.connect(signal_name, callable)


func _on_timeline_started() -> void:
	_activity_phase = "live"
	_pending_layout = null
	timeline_started_signal.emit()


func _on_timeline_ended() -> void:
	_retire_caption_binding()
	release_frozen_presentation()
	_activity_phase = ""
	_runtime_generation = 0
	_pending_layout = null
	_requested_path = ""
	timeline_ended_signal.emit()


func _on_qualified_timeline_started(generation: int, request_id: String) -> void:
	var replaced := not _requested_path.is_empty() and (_activity_phase != "starting" \
		or request_id != _request_id or str(_dialogic.current_timeline.resource_path) != _requested_path)
	_runtime_generation = generation
	if replaced:
		_retire_caption_binding()
		release_frozen_presentation()
		_start_generation += 1
		_requested_path = ""
		# Never delete a layout now used by foreign native playback.
		if is_instance_valid(_pending_layout) and _pending_layout.ready.is_connected(_pending_start):
			_pending_layout.ready.disconnect(_pending_start)
		var clear_call := Callable(_dialogic, "clear").bind(CLEAR_KEEP_VARIABLES)
		if is_instance_valid(_pending_layout) and _pending_layout.ready.is_connected(clear_call):
			_pending_layout.ready.disconnect(clear_call)
		_pending_layout = null
		_pending_start = Callable()
		_activity_phase = "live"
		playback_start_failed.emit(_fail(&"runtime_playback_replaced", "native playback replaced the admitted timeline"))
		return
	if _caption_ledger != null and _caption_request == request_id:
		_caption_generation = generation
	_on_timeline_started()


func _on_qualified_timeline_ended(generation: int) -> void:
	if generation == _runtime_generation:
		_on_timeline_ended()


func _on_event_handled(resource: Variant) -> void:
	event_handled_signal.emit(resource)


func _on_signal_event(argument: Variant) -> void:
	runtime_signal_event.emit(argument)


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
