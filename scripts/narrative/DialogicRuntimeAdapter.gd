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
signal reading_seek_finished(result: Dictionary)

const CLEAR_KEEP_VARIABLES := 1
const CLEAR_KEEP_TEXT := 4
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
var _retain_caption_layout := false
var _retained_caption_layout: Node
var _retained_caption_layer: Node
var _retained_caption_ledger: NarrativeCaptionLedger
var _retained_caption_token := ""
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
var _prepared_reading_seek: Dictionary = {}
var _reading_seek_serial := 0
var _caption_seek_frontier: Dictionary = {}
var _caption_seek_result: Dictionary = {}
var _caption_seek_queued := false


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
	if _qualified_runtime and dialogic.has_method("set_caption_handoff_guard"):
		dialogic.set_caption_handoff_guard(_begin_caption_handoff)
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
func bind_caption_ledger(ledger: NarrativeCaptionLedger, token: String, entry_id: String, retain_layout: bool = false) -> Dictionary:
	if not _bound or not _qualified_runtime or has_active_playback() or _caption_ledger != null:
		return _fail(&"caption_binding_unavailable", "no idle qualified publication slot")
	if ledger == null: return _fail(&"caption_ledger_missing", "ledger is required")
	var checked := ledger.check_session(token, entry_id)
	if not checked.ok: return checked
	var text: Object = _dialogic.get_subsystem("Text")
	if not text.has_signal("about_to_show_text"):
		return _fail(&"caption_publication_signal_missing", "publication start signal is required")
	if is_instance_valid(_retained_caption_layout) and (not retain_layout or ledger != _retained_caption_ledger or token != _retained_caption_token):
		release_retained_caption_layout()
	_retain_caption_layout = retain_layout
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
	if not _caption_seek_frontier.is_empty():
		if _caption_line != _caption_seek_frontier.line_id:
			_fail_reading_seek(_fail(&"reading_seek_changed", "the destination publication changed"))
			return
		_caption_publication = _caption_seek_frontier.publication_id
		return
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
	if not _caption_seek_frontier.is_empty():
		if not result.ok or not result.value.get("duplicate", false):
			_fail_reading_seek(_fail(&"reading_seek_changed", "the destination must reuse its committed occurrence"))
			return
		if not _caption_seek_queued:
			_caption_seek_queued = true
			# Let the ordinary visible publication and its first speech admission
			# finish. Unlike Load, Next leaves this unseen caption revealing.
			_finish_reading_seek.call_deferred(_request_id, _caption_event)
	if not _caption_restore_frontier.is_empty():
		if not result.ok or not result.value.get("duplicate", false):
			_fail_reading_restore(_fail(&"reading_frontier_occurrence_changed", "resume must reuse the saved occurrence"))
			return
		if not _caption_restore_queued:
			_caption_restore_queued = true
			# Native text_started precedes the text event's text_finished await.
			# A synchronous reveal here would strand that coroutine forever.
			_finish_reading_restore.call_deferred(_request_id, _caption_event)


## Only the current admitted ending occurrence may keep its mounted view after Return.
func _begin_caption_handoff() -> bool:
	if not _retain_caption_layout or not _caption_source_is_current() or _caption_event == null \
			or _caption_event.state != DialogicTextEvent.States.DONE \
			or not _caption_ledger.is_current_occurrence(_caption_token, _caption_entry,
				{"line_id": _caption_line, "publication_id": _caption_publication}): return false
	var layout: Node = _dialogic.Styles.get_layout_node()
	if not is_instance_valid(layout) or not layout.is_inside_tree(): return false
	for layer: Node in layout.get_layers():
		if layer.has_method("begin_ending_caption_handoff") and layer.call("begin_ending_caption_handoff", _caption_token) == true:
			_retained_caption_layout = layout
			_retained_caption_layer = layer
			_retained_caption_ledger = _caption_ledger
			_retained_caption_token = _caption_token
			return true
	return false


func release_retained_caption_layout(dispose: bool = true) -> void:
	_retain_caption_layout = false
	var layout := _retained_caption_layout
	var layer := _retained_caption_layer
	_retained_caption_layout = null
	_retained_caption_layer = null
	_retained_caption_ledger = null
	_retained_caption_token = ""
	if is_instance_valid(layer):
		if layer.has_method("end_ending_caption_handoff"): layer.call("end_ending_caption_handoff")
		layer.call("reset_caption_stack")
	if dispose and is_instance_valid(layout):
		if layout.get_parent() != null: layout.get_parent().remove_child(layout)
		layout.queue_free()


func _retire_caption_binding() -> void:
	_marker_hold = {}
	_marker_binding = {}
	_marker_restore = {}
	_scene_event_hold = {}
	_retain_caption_layout = false
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
	_prepared_reading_seek = {}
	_caption_seek_frontier = {}
	_caption_seek_result = {}
	_caption_seek_queued = false


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


## Pause hides the caption, so Text.skip_text_reveal() intentionally cannot find
## it. Finish only the exact retained node of the current layout, without showing
## it, stopping suspended audio or exposing a next event to the foreground.
func complete_paused_reading_frontier(text_node: DialogicNode_DialogText) -> Dictionary:
	if not _bound or _dialogic == null:
		return _fail(&"reading_frontier_unavailable", "the exact hidden suspended caption is required")
	var before := {}
	if _marker_hold.is_empty():
		before = capture_reading_frontier()
		if not before.get("ok", false): return before
	var layout: Node = _dialogic.Styles.get_layout_node()
	if not _dialogic.paused or not is_instance_valid(text_node) or not is_instance_valid(layout) \
			or not layout.is_ancestor_of(text_node) or not text_node.is_inside_tree() \
			or text_node.is_queued_for_deletion() or text_node.is_visible_in_tree() \
			or not text_node.enabled or text_node.text != _dialogic.current_state_info.get("text"):
		return _fail(&"reading_frontier_unavailable", "the exact hidden suspended caption is required")
	if not _marker_hold.is_empty():
		# The marker's ledger may include witnessed captions that were never
		# rendered here. Pause still owns this exact completed native source;
		# do not reveal it again or demand that it be the ledger's new tail.
		if not _marker_hold_current() or text_node.revealing or text_node.visible_ratio != 1.0:
			return _fail(&"reading_frontier_changed", "the held marker source is no longer complete")
		var held_native := capture_pause_frontier()
		if not held_native.ok:
			return _fail(&"reading_frontier_unavailable", "the marker has no suspended native source")
		return {"ok": true, "value": {"reveal_generation": text_node.get_reveal_generation(), "completed": false}}
	var event := _caption_event
	var native := capture_pause_frontier()
	var generation := text_node.get_reveal_generation()
	var needs_reveal := event.state != DialogicTextEvent.States.DONE
	if needs_reveal:
		_dialogic.set_meta(&"dwm_boundary_safe_skip_reveal", true)
		text_node.finish_text()
		_dialogic.remove_meta(&"dwm_boundary_safe_skip_reveal")
	var after := capture_reading_frontier()
	if not after.get("ok", false) or after.value != before.value or native != capture_pause_frontier() \
			or event != _caption_event or event.state != DialogicTextEvent.States.DONE \
			or not is_instance_valid(text_node) or text_node.is_visible_in_tree() or text_node.revealing \
			or text_node.visible_ratio != 1.0 \
			or text_node.get_reveal_generation() != generation + int(needs_reveal):
		return _fail(&"reading_frontier_changed", "completion changed the held native publication")
	return {"ok": true, "value": {"reveal_generation": text_node.get_reveal_generation(),
		"completed": needs_reveal}}


## Pure authored lookup for the owner's pre-install compatibility check. Its
## locator is supplied by the admitted entry manifest, never by the checkpoint.
func validate_reading_line(path: String, entry_label: String, line_id: String, expected_text: String = "") -> Dictionary:
	var checked := _resolve_reading_line(path, entry_label, line_id, expected_text)
	return {"ok": true} if checked.ok else checked


## This fixed-prose increment admits the whole native programme, not just its
## registered subset. A saved line may not skip an unregistered caption/effect.
func validate_reading_entry(path: String, entry_label: String, lines: Array, marker: Dictionary = {}) -> Dictionary:
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
	var marker_count := 0
	for event: DialogicEvent in detached.events:
		if event is DialogicLabelEvent:
			if str(event.name).begins_with("scene.marker."):
				if not selected or ended or marker.is_empty() or event.name != marker.get("label") or ordinal == 0 \
						or ordinal >= lines.size() or lines[ordinal - 1].line_id != marker.get("after_line_id") \
						or lines[ordinal].line_id != marker.get("before_line_id"):
					return _fail(&"reading_marker_position_invalid", "unregistered marker locator")
				marker_count += 1
				continue
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
	if labels != 1 or not ended or ordinal != lines.size() or marker_count != (0 if marker.is_empty() else 1):
		return _fail(&"reading_entry_mismatch", "the complete fixed entry must end with return")
	return {"ok": true}


## The coordinator owns exact witnessing, exclusive custody and durable source /
## destination commits. This transient capability admits only the already fixed
## native programme; no event index or runtime identity belongs in its Run record.
func prepare_reading_seek(source_frontier: Dictionary, entry_label: String,
		ordered_lines: Array, destination_line_id: String = "") -> Dictionary:
	var source := capture_reading_frontier()
	if not source.ok or source.value != source_frontier or _dialogic.paused \
			or not _caption_seek_result.is_empty() or _dialogic.Inputs.auto_skip.enabled \
			or _dialogic.Inputs.auto_advance.is_enabled():
		return _fail(&"reading_seek_unavailable", "an exact current frontier with ordinary transport is required")
	var checked := validate_reading_entry(_requested_path, entry_label, ordered_lines)
	if not checked.ok: return checked
	var indices := _reading_seek_indices(entry_label, ordered_lines, destination_line_id)
	if not indices.ok: return indices
	var intent := {"source": source_frontier.duplicate(true), "entry_id": _caption_entry,
		"destination_line_id": destination_line_id, "terminal": destination_line_id.is_empty()}
	if not _prepared_reading_seek.is_empty():
		var previous: Dictionary = _prepared_reading_seek.plan.duplicate(true)
		previous.erase("seek_id")
		if previous == intent and _reading_seek_source_matches(_prepared_reading_seek) \
				and _prepared_reading_seek.lines == ordered_lines and _prepared_reading_seek.entry_label == entry_label:
			return {"ok": true, "value": _prepared_reading_seek.plan.duplicate(true)}
	_reading_seek_serial += 1
	intent["seek_id"] = "reading-seek:%d:%d" % [get_instance_id(), _reading_seek_serial]
	_prepared_reading_seek = {"plan": intent.duplicate(true), "lines": ordered_lines.duplicate(true),
		"entry_label": entry_label, "indices": indices.value, "event": _caption_event,
		"ledger": _caption_ledger, "snapshot": _caption_ledger.snapshot(),
		"request_id": _request_id, "generation": _runtime_generation}
	return {"ok": true, "value": intent.duplicate(true)}


## Install the durable candidate into the existing live playback without running
## any crossed caption. Completing and unwinding the source coroutine first is
## essential: jumping straight to handle_event() would leave its await alive.
func apply_reading_seek(plan: Dictionary, destination_ledger: NarrativeCaptionLedger,
		destination_frontier: Dictionary = {}) -> Dictionary:
	if _prepared_reading_seek.is_empty() or plan != _prepared_reading_seek.plan \
			or not _reading_seek_source_matches(_prepared_reading_seek):
		return _fail(&"reading_seek_stale", "the prepared native source is no longer current")
	var prepared := _prepared_reading_seek
	var native := _reading_seek_indices(prepared.entry_label, prepared.lines, plan.destination_line_id)
	if not native.ok: return native
	if native.value != prepared.indices:
		return _fail(&"reading_seek_changed", "the admitted native programme changed")
	var target := _check_reading_seek_target(prepared, destination_ledger, destination_frontier)
	if not target.ok: return target
	var completed := complete_reading_frontier()
	if not completed.ok: return completed
	if not _reading_seek_source_matches(prepared):
		return _fail(&"reading_seek_stale", "source reveal replaced the prepared native source")
	var after_reveal := _reading_seek_indices(prepared.entry_label, prepared.lines, plan.destination_line_id)
	if not after_reveal.ok or after_reveal.value != prepared.indices:
		return _fail(&"reading_seek_changed", "source reveal changed the admitted native programme")
	target = _check_reading_seek_target(prepared, destination_ledger, destination_frontier)
	if not target.ok: return target
	# A same-caption Next completes an unseen partial line and stops. It does
	# not end its coroutine, manufacture another occurrence, or restart speech.
	if plan.destination_line_id == plan.source.line_id:
		_caption_ledger = destination_ledger
		_prepared_reading_seek = {}
		var result := {"ok": true, "value": {"frontier": destination_frontier.duplicate(true), "terminal": false}}
		reading_seek_finished.emit(result)
		return result
	var event: DialogicTextEvent = prepared.event
	var continuation := Callable(_dialogic, "handle_next_event")
	if not event.event_finished.is_connected(continuation):
		return _fail(&"reading_seek_unavailable", "the native source continuation is missing")
	var completion := {"finished": false}
	var observe := func(_event: DialogicEvent) -> void: completion.finished = true
	event.event_finished.connect(observe, CONNECT_ONE_SHOT)
	event.event_finished.disconnect(continuation)
	event.advance.emit()
	if event.event_finished.is_connected(observe): event.event_finished.disconnect(observe)
	# Restore the exact native connection even on refusal. handle_event's own
	# cleanup retires it and the source's input signals on a successful seek.
	if not event.event_finished.is_connected(continuation): event.event_finished.connect(continuation)
	if not completion.finished or not _reading_seek_source_matches(prepared):
		return _fail(&"reading_seek_changed", "the exact source coroutine did not finish at its held boundary")
	var after_finish := _reading_seek_indices(prepared.entry_label, prepared.lines, plan.destination_line_id)
	if not after_finish.ok or after_finish.value != prepared.indices:
		return _fail(&"reading_seek_changed", "source completion changed the admitted native programme")
	target = _check_reading_seek_target(prepared, destination_ledger, destination_frontier)
	if not target.ok: return target
	_caption_ledger = destination_ledger
	_prepared_reading_seek = {}
	_caption_seek_frontier = destination_frontier.duplicate(true)
	_caption_seek_queued = false
	_caption_seek_result = {"ok": true, "value": {"frontier": destination_frontier.duplicate(true),
		"terminal": bool(plan.terminal)}}
	_dialogic.handle_event(int(native.value.target_index))
	return {"ok": true, "value": {"pending": true}}


func _reading_seek_source_matches(prepared: Dictionary) -> bool:
	var source := capture_reading_frontier()
	return source.ok and source.value == prepared.plan.source and not _dialogic.paused \
		and not _dialogic.Inputs.auto_skip.enabled and not _dialogic.Inputs.auto_advance.is_enabled() \
		and _caption_seek_result.is_empty() and prepared.ledger == _caption_ledger \
		and prepared.event == _current_skip_text() and prepared.request_id == _request_id \
		and prepared.generation == _runtime_generation and prepared.snapshot == _caption_ledger.snapshot()


func _check_reading_seek_target(prepared: Dictionary, candidate: NarrativeCaptionLedger,
		frontier: Dictionary) -> Dictionary:
	if candidate == null or not candidate.check_session(_caption_token, _caption_entry).ok:
		return _fail(&"reading_seek_target_invalid", "the destination requires the same admitted session")
	var snapshot := candidate.snapshot()
	var old: Dictionary = prepared.snapshot
	var original_headers := old.duplicate(true)
	var target_headers := snapshot.duplicate(true)
	original_headers.erase("captions")
	target_headers.erase("captions")
	if original_headers != target_headers:
		return _fail(&"reading_seek_target_invalid", "the destination changed its immutable session frame")
	var crossed: Array = prepared.indices.crossed_lines
	if snapshot.captions.size() != old.captions.size() + crossed.size():
		return _fail(&"reading_seek_target_invalid", "the candidate must retain the source and every crossed caption")
	for index: int in old.captions.size():
		if snapshot.captions[index] != old.captions[index]:
			return _fail(&"reading_seek_target_invalid", "the candidate changed source History")
	for index: int in crossed.size():
		var row: Dictionary = snapshot.captions[old.captions.size() + index]
		if row.beat.owning_entry_id != _caption_entry or row.beat.line_id != crossed[index]:
			return _fail(&"reading_seek_target_invalid", "the candidate skipped or reordered a caption")
	if prepared.plan.terminal:
		if not frontier.is_empty(): return _fail(&"reading_seek_target_invalid", "terminal Return has no text frontier")
	elif frontier.get("line_id") != prepared.plan.destination_line_id \
			or not candidate.is_current_occurrence(_caption_token, _caption_entry, frontier):
		return _fail(&"reading_seek_target_invalid", "the exact destination occurrence is required")
	return {"ok": true}


## Decode only detached future events. Inspect the live event list as well as the
## resource preflight so a replaced/mutated runtime cannot inherit a locator.
func _reading_seek_indices(entry_label: String, lines: Array, destination: String) -> Dictionary:
	if _dialogic.current_timeline == null or not _dialogic.has_subsystem("Jump") \
			or not _dialogic.Jump.is_jump_stack_empty():
		return _fail(&"reading_seek_unavailable", "Return must be a proved natural completion")
	var selected := false
	var labels := 0
	var ordinal := 0
	var source_ordinal := -1
	var target_ordinal := -1
	var target_index := -1
	var ended := false
	var markers := 0
	for index: int in _dialogic.current_timeline_events.size():
		var event: DialogicEvent = _dialogic.current_timeline_events[index]
		if not event.event_node_ready:
			var detached: DialogicEvent = event.get_script().new()
			detached._load_from_string(event.event_node_as_text)
			event = detached
		if event is DialogicLabelEvent:
			if str(event.name).begins_with("scene.marker."):
				if not selected or ended or _marker_binding.is_empty() or event.name != _marker_binding.label \
						or ordinal == 0 or ordinal >= lines.size() \
						or lines[ordinal - 1].line_id != _marker_binding.after_line_id \
						or lines[ordinal].line_id != _marker_binding.before_line_id:
					return _fail(&"reading_seek_changed", "marker locator changed")
				markers += 1
				continue
			selected = event.name == entry_label
			if selected: labels += 1
			continue
		if not selected or event is DialogicCommentEvent: continue
		if ended: return _fail(&"reading_seek_changed", "the native entry continues after Return")
		if event is DialogicReturnEvent:
			if ordinal != lines.size(): return _fail(&"reading_seek_changed", "the native entry returns early")
			ended = true
			if destination.is_empty():
				target_index = index
				target_ordinal = ordinal
			continue
		if not event is DialogicTextEvent or ordinal >= lines.size() \
				or _authored_line_id(event) != lines[ordinal].line_id or not _is_single_skip_line(event) \
				or not _reading_text_matches(event, lines[ordinal].text):
			return _fail(&"reading_seek_changed", "the native entry differs from the complete fixed catalogue")
		if _marker_hold.is_empty():
			if index == int(_dialogic.current_event_idx) and event == _caption_event: source_ordinal = ordinal
		elif _authored_line_id(event) == _marker_hold.source_line: source_ordinal = ordinal
		if _authored_line_id(event) == destination:
			target_index = index
			target_ordinal = ordinal
		ordinal += 1
	if labels != 1 or not ended or ordinal != lines.size() or source_ordinal < 0 \
			or target_index < 0 or target_ordinal < source_ordinal or markers != (0 if _marker_binding.is_empty() else 1):
		return _fail(&"reading_seek_changed", "the target must be in the current fixed entry at or after its source")
	var crossed: Array[String] = []
	for index: int in range(source_ordinal + 1, mini(target_ordinal + 1, lines.size())):
		crossed.append(lines[index].line_id)
	return {"ok": true, "value": {"target_index": target_index, "crossed_lines": crossed}}


func _finish_reading_seek(request_id: String, event: DialogicTextEvent) -> void:
	if _caption_seek_result.is_empty() or request_id != _request_id: return
	if not _caption_source_is_current() or event != _current_skip_text(true):
		_fail_reading_seek(_fail(&"reading_seek_changed", "the visible destination was replaced"))
		return
	var result := _caption_seek_result.duplicate(true)
	var captured := capture_reading_frontier()
	if not captured.ok or captured.value != _caption_seek_frontier:
		_fail_reading_seek(_fail(&"reading_seek_changed", "the committed destination occurrence changed"))
		return
	_caption_seek_frontier = {}
	_caption_seek_result = {}
	_caption_seek_queued = false
	reading_seek_finished.emit(result)


func _fail_reading_seek(result: Dictionary) -> void:
	var seeking := not _caption_seek_result.is_empty()
	halt_with_error(result)
	if not seeking: reading_seek_finished.emit(result)
	playback_start_failed.emit(result)


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
			if str(event.name).begins_with("scene.marker."): continue
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
	if not _marker_restore.is_empty():
		var parked := hold_marker_source(captured.value)
		if not parked.ok:
			_fail_reading_restore(parked)
			return
		_marker_hold.source_line = _marker_restore.anchor.line_id
		_marker_hold.frontier = _marker_restore.duplicate(true)
		_marker_restore = {}
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
	var keep_text := is_instance_valid(_retained_caption_layout) and _retain_caption_layout \
		and _caption_ledger == _retained_caption_ledger and _caption_token == _retained_caption_token
	if not keep_text and is_instance_valid(_retained_caption_layout): release_retained_caption_layout()
	_dialogic.clear(CLEAR_KEEP_VARIABLES | (CLEAR_KEEP_TEXT if keep_text else 0))
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


## Ephemeral text or authored silent-hold frontier. This is never a save cursor.
## Startup, cleanup and other native events remain unavailable to Pause.
func capture_pause_frontier() -> Dictionary:
	if not _bound or not _qualified_runtime or _activity_phase != "live" \
		or _request_id.is_empty() or _requested_path.is_empty() or _dialogic.current_timeline == null \
		or _dialogic.is_ending_timeline():
		return _fail(&"pause_frontier_unavailable", "no admitted live reading frontier")
	var index := int(_dialogic.current_event_idx)
	if index < 0 or index >= _dialogic.current_timeline_events.size():
		return _fail(&"pause_frontier_unavailable", "the current event has no reading frontier")
	var event: Variant = _dialogic.current_timeline_events[index]
	var frontier := {
		"generation": _runtime_generation, "event_index": index,
		"request_id": _request_id, "paused": bool(_dialogic.paused),
	}
	if event is DialogicTextEvent and _dialogic.current_state in [DialogicGameHandler.States.IDLE, DialogicGameHandler.States.REVEALING_TEXT]:
		return {"ok": true, "code": &"ok", "value": frontier}
	if not event is DialogicWaitEvent or _dialogic.current_state != DialogicGameHandler.States.WAITING:
		return _fail(&"pause_frontier_unavailable", "the current event has no admitted silent hold")
	var wait_event := event as DialogicWaitEvent
	if not wait_event.hide_text or wait_event.skippable or not is_finite(wait_event.time) or wait_event.time <= 0.0 \
			or not wait_event.has_method("get_wait_execution_state"):
		return _fail(&"pause_frontier_unavailable", "silent hold requires a finite authored non-skippable duration")
	var hold: Dictionary = wait_event.call("get_wait_execution_state")
	if typeof(hold.get("execution_token")) != TYPE_INT or int(hold.get("execution_token", 0)) <= 0 \
			or hold.get("timeline_generation") != _runtime_generation \
			or hold.get("event_index") != index or hold.get("paused") != bool(_dialogic.paused) \
			or hold.get("hide_text") != true or hold.get("skippable") != false:
		return _fail(&"pause_frontier_unavailable", "silent hold no longer owns the native timer")
	# Stable invocation identity survives Pause; continuously changing remaining
	# time must never enter the Bridge's exact suspension/source comparisons.
	frontier["kind"] = "timed_hold"
	frontier["execution_token"] = hold.execution_token
	return {"ok": true, "code": &"ok", "value": frontier}


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
	release_retained_caption_layout()
	var seeking := not _caption_seek_result.is_empty()
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
	if seeking:
		var stopped := result.duplicate(true) if result.has("ok") and not result.ok else \
			_fail(&"reading_seek_cancelled", "the admitted seek was halted before publication")
		reading_seek_finished.emit(stopped)
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
	var seek := _caption_seek_result.duplicate(true)
	_retire_caption_binding()
	release_frozen_presentation()
	_activity_phase = ""
	_runtime_generation = 0
	_pending_layout = null
	_requested_path = ""
	timeline_ended_signal.emit()
	if not seek.is_empty():
		reading_seek_finished.emit(seek if seek.value.terminal else \
			_fail(&"reading_seek_changed", "the timeline ended before its destination publication"))


func _on_qualified_timeline_started(generation: int, request_id: String) -> void:
	if is_instance_valid(_retained_caption_layout) and request_id != _request_id:
		release_retained_caption_layout(false)
	var replaced := not _requested_path.is_empty() and (_activity_phase != "starting" \
		or request_id != _request_id or str(_dialogic.current_timeline.resource_path) != _requested_path)
	_runtime_generation = generation
	if replaced:
		var seeking := not _caption_seek_result.is_empty()
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
		var result := _fail(&"runtime_playback_replaced", "native playback replaced the admitted timeline")
		playback_start_failed.emit(result)
		if seeking: reading_seek_finished.emit(result)
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


var _scene_event_hold: Dictionary = {}
var _scene_event_ack_active := false

## Synchronous transport hold. A refused command remains at its exact caption;
## retry may acknowledge it, while a fatal committed interruption requires restart.
func dispatch_scene_event_acknowledged(envelope: Dictionary, dispatch: Callable) -> Dictionary:
	if not dispatch.is_valid() or _scene_event_ack_active:
		return _fail(&"event_handoff_unavailable", "")
	var frontier := capture_reading_frontier()
	if not frontier.ok: return frontier
	var identity := {"frontier": frontier.value, "session": _caption_token, "entry": _caption_entry}
	if _scene_event_hold.is_empty():
		if _dialogic.paused: return _fail(&"event_presentation_held", "")
		_scene_event_hold = identity.duplicate(true)
	elif _scene_event_hold != identity:
		return _fail(&"event_handoff_source_changed", "")
	var held := set_paused(true)
	if not held.ok: return held
	_scene_event_ack_active = true
	var result: Dictionary = dispatch.call(envelope.duplicate(true))
	_scene_event_ack_active = false
	if not result.get("ok", false): return result
	var after := capture_reading_frontier()
	if not after.ok or after.value != _scene_event_hold.frontier \
			or _caption_token != _scene_event_hold.session or _caption_entry != _scene_event_hold.entry:
		return {"ok": false, "code": &"event_ack_source_changed", "committed": true}
	var resumed := set_paused(false)
	if not resumed.ok: return {"ok": false, "code": &"event_ack_resume_failed", "committed": true}
	_scene_event_hold = {}
	return result


var _marker_binding: Dictionary = {}
var _marker_hold: Dictionary = {}
var _marker_restore: Dictionary = {}

func bind_reading_marker(marker: Dictionary, restore_frontier: Dictionary = {}) -> Dictionary:
	if has_active_playback() or _caption_ledger == null: return _fail(&"reading_marker_binding_unavailable", "")
	if not marker.is_empty():
		for field: String in ["event_id", "label", "after_line_id", "before_line_id"]:
			if not marker.get(field) is String or str(marker[field]).is_empty():
				return _fail(&"reading_marker_binding_invalid", "the trusted marker locator is incomplete")
		if marker.label != "scene.marker." + marker.event_id or marker.after_line_id == marker.before_line_id:
			return _fail(&"reading_marker_binding_invalid", "the trusted marker locator is invalid")
	if not restore_frontier.is_empty():
		if marker.is_empty() or restore_frontier.get("event_id") != marker.event_id \
				or not restore_frontier.get("anchor") is Dictionary:
			return _fail(&"reading_marker_binding_invalid", "the restore must name the registered marker")
		var anchor: Dictionary = restore_frontier.anchor
		if anchor.get("line_id") != marker.after_line_id or anchor.get("session_id") != _caption_token \
				or anchor.get("entry_id") != _caption_entry:
			return _fail(&"reading_marker_binding_invalid", "the restore must retain its session anchor")
		var occurrence := _check_reading_occurrence({"line_id": anchor.line_id, "publication_id": anchor.get("publication_id")})
		if not occurrence.ok: return occurrence
	_marker_binding = marker.duplicate(true)
	_marker_restore = restore_frontier.duplicate(true)
	return {"ok": true}

func is_marker_source_held() -> bool:
	return _marker_hold_current()

func marker_source_identity() -> Dictionary:
	if not _marker_hold.is_empty():
		if not _marker_hold_current(): return _fail(&"reading_marker_source_changed", "")
		return {"ok": true, "value": _marker_hold.identity.duplicate(true)}
	var captured := capture_reading_frontier()
	if not captured.ok: return captured
	return {"ok": true, "value": {"request": _request_id, "generation": _runtime_generation,
		"session": _caption_token, "entry": _caption_entry, "event_index": int(_dialogic.current_event_idx),
		"frontier": captured.value.duplicate(true)}}

func _marker_hold_current() -> bool:
	return not _marker_hold.is_empty() and _caption_source_is_current() \
		and _marker_hold.identity.request == _request_id and _marker_hold.identity.generation == _runtime_generation \
		and _marker_hold.identity.session == _caption_token and _marker_hold.identity.entry == _caption_entry \
		and _marker_hold.identity.event_index == int(_dialogic.current_event_idx) \
		and _marker_hold.ledger == _caption_ledger and _marker_hold.snapshot == _caption_ledger.snapshot() \
		and _marker_hold.event == _caption_event and _caption_event == _current_skip_text(true) \
		and _caption_event.state == DialogicTextEvent.States.DONE \
		and _caption_event._execution_generation == _marker_hold.execution_generation \
		and not _caption_event.event_finished.is_connected(Callable(_dialogic, "handle_next_event"))

## Finish precisely once and remove its native continuation. A compensated retry
## retains this capability; it never sends advance into a retired coroutine.
func hold_marker_source(source: Dictionary) -> Dictionary:
	if not _marker_hold.is_empty():
		return {"ok": true} if _marker_hold_current() and _marker_hold.identity.frontier == source else _fail(&"reading_marker_source_changed", "")
	var identity := marker_source_identity()
	if not identity.ok or identity.value.frontier != source: return _fail(&"reading_marker_source_changed", "")
	var ledger := _caption_ledger
	var snapshot := ledger.snapshot()
	var completed := complete_reading_frontier()
	if not completed.ok: return completed
	var after := marker_source_identity()
	if not after.ok or after.value != identity.value or ledger != _caption_ledger or snapshot != ledger.snapshot():
		return _fail(&"reading_marker_source_changed", "")
	var event := _caption_event
	var continuation := Callable(_dialogic, "handle_next_event")
	if not event.event_finished.is_connected(continuation): return _fail(&"reading_marker_continuation_missing", "")
	var observed := {"finished": false}
	var callback := func(_event: DialogicEvent) -> void: observed.finished = true
	event.event_finished.connect(callback, CONNECT_ONE_SHOT)
	event.event_finished.disconnect(continuation)
	event.advance.emit()
	if event.event_finished.is_connected(callback): event.event_finished.disconnect(callback)
	after = marker_source_identity()
	if not observed.finished or not after.ok or after.value != identity.value \
			or ledger != _caption_ledger or snapshot != ledger.snapshot():
		# Once continuation is detached the source is no longer retryable unless
		# its exact finished coroutine is proved. Fail closed instead of reviving it.
		var failed := _fail(&"reading_marker_source_changed", "source retirement could not be proved")
		halt_with_error(failed)
		return failed
	event._clear_state()
	after = marker_source_identity()
	if not after.ok or after.value != identity.value or ledger != _caption_ledger or snapshot != ledger.snapshot():
		var failed := _fail(&"reading_marker_source_changed", "source cleanup changed the admitted occurrence")
		halt_with_error(failed)
		return failed
	_marker_hold = {"identity": identity.value.duplicate(true), "source_line": source.line_id,
		"frontier": {}, "ledger": _caption_ledger, "snapshot": _caption_ledger.snapshot(),
		"event": event, "execution_generation": event._execution_generation}
	return {"ok": true}

func prepare_marker_seek(entry_label: String, lines: Array, destination_line: String) -> Dictionary:
	if _marker_binding.is_empty() or _dialogic == null or _dialogic.paused \
			or not _caption_seek_result.is_empty() or is_reading_frontier_restoring() \
			or _dialogic.Inputs.auto_skip.enabled or _dialogic.Inputs.auto_advance.is_enabled():
		return _fail(&"reading_seek_unavailable", "ordinary transport at the exact source is required")
	var source := marker_source_identity()
	if not source.ok: return source
	var valid := validate_reading_entry(_requested_path, entry_label, lines, _marker_binding)
	if not valid.ok: return valid
	var indices := _reading_seek_indices(entry_label, lines, destination_line)
	if not indices.ok: return indices
	return {"ok": true, "value": {"identity": source.value.duplicate(true), "entry_label": entry_label,
		"lines": lines.duplicate(true), "destination": destination_line, "indices": indices.value}}

func install_marker_candidate(plan: Dictionary, candidate: NarrativeCaptionLedger, frontier: Dictionary) -> Dictionary:
	if not _marker_hold_current() or _marker_hold.identity != plan.get("identity") \
			or _dialogic.paused or _dialogic.Inputs.auto_skip.enabled or _dialogic.Inputs.auto_advance.is_enabled():
		return _fail(&"reading_marker_source_changed", "")
	var indices := _reading_seek_indices(plan.entry_label, plan.lines, plan.destination)
	if not indices.ok or indices.value != plan.indices: return _fail(&"reading_seek_changed", "")
	var target_frontier := frontier.duplicate(true)
	if frontier.has("anchor"):
		if not frontier.anchor is Dictionary or frontier.get("event_id") != _marker_binding.event_id \
				or frontier.anchor.get("line_id") != _marker_binding.after_line_id \
				or frontier.anchor.get("session_id") != _caption_token \
				or frontier.anchor.get("entry_id") != _caption_entry:
			return _fail(&"reading_seek_target_invalid", "the exact registered marker anchor is required")
		target_frontier = {"line_id": frontier.anchor.line_id, "publication_id": frontier.anchor.get("publication_id")}
	var prepared := {"snapshot": _marker_hold.snapshot, "indices": plan.indices,
		"plan": {"terminal": plan.destination.is_empty(), "destination_line_id": plan.destination}}
	var checked := _check_reading_seek_target(prepared, candidate, target_frontier)
	if not checked.ok: return checked
	var after: Dictionary = candidate.snapshot()
	_caption_ledger = candidate
	_marker_hold.ledger = candidate
	_marker_hold.snapshot = after
	if frontier.has("anchor"):
		_marker_hold.frontier = frontier.duplicate(true)
		_marker_hold.source_line = frontier.anchor.line_id
		return {"ok": true, "value": {"pending": false}}
	_caption_seek_frontier = frontier.duplicate(true)
	_caption_seek_result = {"ok": true, "value": {"frontier": frontier.duplicate(true), "terminal": frontier.is_empty()}}
	_caption_seek_queued = false
	_marker_hold = {}
	_dialogic.handle_event(int(indices.value.target_index))
	return {"ok": true, "value": {"pending": true}}
