extends GutTest

const RAIL := preload("res://scripts/ui/witnessed/WitnessedTransportRail.gd")
const HISTORY := preload("res://scripts/ui/witnessed/WitnessedHistory.gd")
const THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")

class Admission extends RefCounted:
	var allowed := true
	func is_admitted() -> bool:
		return allowed

class InputOwner extends Node:
	signal source_input_custody_changed
	signal input_bindings_changed
	var contacts: Dictionary = {}
	func get_physical_contacts() -> Dictionary:
		return contacts.duplicate()
	func observe_physical_contact(_event: InputEvent) -> void:
		pass
	func get_physical_contact_id(_event: InputEvent) -> String:
		return ""
	func is_source_input_admitted() -> bool:
		return true

var _localization: Node
var _input_owner: InputOwner
var _admission: Admission

func before_each() -> void:
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(STORAGE.new("reading-rail-localization", FILES.new())).get("ok", false))
	_localization = autofree(LOCALIZATION.new())
	assert_true(_localization.initialize(profile).get("ok", false))
	_input_owner = InputOwner.new()
	add_child_autofree(_input_owner)
	_admission = Admission.new()

func _rail() -> Control:
	var rail := RAIL.new()
	assert_true(rail.bind_localization(_localization))
	assert_true(rail.configure_presentation(THEME.build("en", 100, "AfterHours"), "en"))
	add_child_autofree(rail)
	return rail

func test_history_and_save_require_their_own_projection_and_final_admission() -> void:
	var rail := _rail()
	assert_true(rail.bind_history_admission(_admission.is_admitted, _input_owner))
	assert_true(rail.bind_save_admission(_admission.is_admitted, _input_owner))
	assert_true(rail.project(true, false, false, true, true))
	assert_true(rail.get_node("History").disabled, "legacy projection does not claim a reading session")
	assert_true(rail.get_node("Save").disabled)
	assert_true(rail.project(false, false, false, false, false, true, true))
	assert_false(rail.get_node("History").disabled)
	assert_false(rail.get_node("Save").disabled)
	assert_true(rail.get_node("Load").disabled, "reading capability cannot authorize Load")
	assert_true(rail.get_node("Next").disabled, "this slice creates no Next owner")
	watch_signals(rail)
	for name: String in ["History", "Save"]:
		rail.get_node(name).pressed.emit()
	assert_signal_not_emitted(rail, "history_requested")
	assert_signal_not_emitted(rail, "save_requested")
	rail.get_node("History").activated.emit()
	rail.get_node("Save").activated.emit()
	assert_signal_emit_count(rail, "history_requested", 1)
	assert_signal_emit_count(rail, "save_requested", 1)
	_admission.allowed = false
	rail.get_node("History").activated.emit()
	rail.get_node("Save").activated.emit()
	assert_signal_emit_count(rail, "history_requested", 1)
	assert_signal_emit_count(rail, "save_requested", 1)

func test_history_and_save_retire_stale_native_activation_when_capability_changes() -> void:
	var rail := _rail()
	assert_true(rail.bind_history_admission(_admission.is_admitted, _input_owner))
	assert_true(rail.bind_save_admission(_admission.is_admitted, _input_owner))
	assert_true(rail.project(false, false, false, false, false, true, true))
	await get_tree().process_frame
	var history := rail.get_node("History")
	var save := rail.get_node("Save")
	var old_history: int = history._generation
	var old_save: int = save._generation
	assert_true(rail.project(false, false, false, false, false, true, true))
	assert_eq(history._generation, old_history)
	assert_eq(save._generation, old_save)
	assert_true(rail.project(false, false, false, false, false, false, false))
	assert_true(rail.project(false, false, false, false, false, true, true))
	await get_tree().process_frame
	watch_signals(rail)
	history._on_accessibility_click(null, old_history)
	save._on_accessibility_click(null, old_save)
	assert_signal_not_emitted(rail, "history_requested")
	assert_signal_not_emitted(rail, "save_requested")
	history._on_accessibility_click(null, int(history._generation))
	save._on_accessibility_click(null, int(save._generation))
	assert_signal_emit_count(rail, "history_requested", 1)
	assert_signal_emit_count(rail, "save_requested", 1)

func test_history_is_plain_opaque_caption_projection_with_two_focus_anchors() -> void:
	var history := HISTORY.new()
	add_child_autofree(history)
	var presentation: Theme = THEME.build("en", 150, "AfterHours", false, "standard", true, 7, true)
	assert_true(history.configure(presentation, _localization, _input_owner, _admission.is_admitted))
	var source := ["First public caption.", "[b]Literal brackets are not new markup.[/b]", "Final public caption."]
	assert_true(history.present(source))
	await get_tree().process_frame
	assert_eq(history.get_captions(), source)
	source[0] = "This must not change the mounted projection."
	assert_eq(history.get_captions()[0], "First public caption.")
	assert_eq(history._roles[&"field"].a, 1.0, "scene art cannot show through the canvas")
	assert_eq(history._roles[&"current"].a, 1.0)
	assert_eq(history.reading_scroll.get_node(history.reading_scroll.focus_next), history.close_button)
	assert_eq(history.close_button.get_node(history.close_button.focus_next), history.reading_scroll)
	assert_true(history.reading_scroll.has_focus(), "initial focus belongs to the semantic reading anchor")
	var labels := 0
	for row: Node in history._rows.get_children():
		if row is RichTextLabel:
			labels += 1
			assert_eq(row.focus_mode, Control.FOCUS_NONE)
			assert_false(row.selection_enabled)
			assert_false(row.bbcode_enabled)
			assert_eq(row.get_theme_constant(&"outline_size"), 0, "Dating text outline does not leak into History")
	assert_eq(labels, 3, "only public captions enter the ledger")
	assert_false(history.present([{"text": "Private source structure"}]))
	assert_eq(history.get_captions().size(), 3, "malformed publication changes nothing")
	history.dismiss()
	assert_false(history.visible)
	assert_true(history.get_captions().is_empty())

func test_history_localizes_existing_operational_copy_and_refuses_revoked_custody() -> void:
	var history := HISTORY.new()
	add_child_autofree(history)
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		assert_true(_localization.set_locale(locale).get("ok", false))
		assert_true(history.configure(THEME.build(locale, 150, "Midnight"), _localization, _input_owner, _admission.is_admitted))
		assert_eq(history._heading.text, _localization.t("witnessed.transport.history"))
		assert_eq(history.close_button.text, _localization.t("button.close"))
		assert_true(history.present(["One public caption."]))
		assert_eq(history.close_button.language, locale.replace("_", "-"))
	watch_signals(history)
	_admission.allowed = false
	history.close_button.pressed.emit()
	assert_signal_not_emitted(history, "close_requested")
	assert_false(history.present(["Refused replacement."]))
	assert_eq(history.get_captions(), ["One public caption."])

func test_history_retires_old_assistive_close_and_background_input() -> void:
	var history := HISTORY.new()
	add_child_autofree(history)
	assert_true(history.configure(THEME.build("en", 100, "AfterHours"), _localization, _input_owner, _admission.is_admitted))
	assert_true(history.present(["A public caption."]))
	var old_generation: int = history.close_button.generation
	history.dismiss()
	assert_true(history.present(["A later public caption."]))
	watch_signals(history)
	history.close_button._activate(null, old_generation)
	assert_signal_not_emitted(history, "close_requested")
	history._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	history.close_button.pressed.emit()
	assert_signal_not_emitted(history, "close_requested", "background History cannot close or submit another owner command")
	history._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	history.close_button._activate(null, int(history.close_button.generation))
	assert_signal_emit_count(history, "close_requested", 1)

func test_next_has_independent_admission_and_contextual_help_without_a_mode() -> void:
	var rail := _rail()
	assert_true(rail.bind_next_admission(_admission.is_admitted, _input_owner))
	assert_true(rail.project(false, false, false, false, false, false, false, true))
	var next: Button = rail.get_node("Next")
	assert_false(next.disabled)
	assert_eq(next.focus_mode, Control.FOCUS_ALL)
	assert_eq(next.text, "Next", "Next is a one-shot command, never an On/Off mode")
	assert_eq(next.tooltip_text, "Skip witnessed content to the next unseen beat or challenge.")
	assert_eq(next.accessibility_description, next.tooltip_text)
	for name: String in ["History", "Save", "Load", "Auto", "Skip"]:
		assert_true(rail.get_node(name).disabled, "Next cannot authorize " + name)
	watch_signals(rail)
	next.pressed.emit()
	assert_signal_not_emitted(rail, "next_requested", "programmatic pressed is not a physical activation")
	next.emit_signal(&"activated")
	assert_signal_emit_count(rail, "next_requested", 1)
	_admission.allowed = false
	next.emit_signal(&"activated")
	assert_signal_emit_count(rail, "next_requested", 1, "the Next owner is checked at activation")

func test_next_cannot_reuse_old_or_repeated_native_callbacks_after_exclusive_custody() -> void:
	var rail := _rail()
	assert_true(rail.bind_next_admission(_admission.is_admitted, _input_owner))
	assert_true(rail.project(false, false, false, false, false, false, false, true))
	await get_tree().process_frame
	var next := rail.get_node("Next")
	next.grab_focus()
	var generation: int = next._generation
	assert_true(rail.project(false, false, false, false, false, false, false, true))
	assert_eq(next._generation, generation, "unchanged availability preserves a fresh physical candidate")
	assert_true(rail.project(false, false, false, false, false, false, false, false))
	assert_false(next.has_focus())
	assert_true(rail.project(false, false, false, false, false, false, false, true))
	await get_tree().process_frame
	watch_signals(rail)
	next._on_accessibility_click(null, generation)
	assert_signal_not_emitted(rail, "next_requested", "an old action cannot cross traversal custody")
	var current_generation: int = next._generation
	next._on_accessibility_click(null, current_generation)
	next._on_accessibility_click(null, current_generation)
	assert_signal_emit_count(rail, "next_requested", 1, "one native generation cannot submit two seeks")

class NextBridge extends RefCounted:
	signal next_request_finished(expected_frontier: Dictionary, result: Dictionary)
	var trace: Array[String] = []
	var result := {"ok": true, "value": {"action": "stopped"}}
	var requested: Dictionary = {}
	var finish_immediately := true
	func can_next_current_line() -> bool: return true
	func request_next(frontier: Dictionary) -> Dictionary:
		trace.append("request")
		requested = frontier.duplicate(true)
		if finish_immediately: next_request_finished.emit(requested.duplicate(true), result)
		return result

class NextHost extends "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd":
	var trace: Array[String] = []
	var owner_current := true
	var source_current := true
	var revision := 8
	var completed: Array[Dictionary] = []
	func _reading_request_owner_matches(_request: Dictionary) -> bool: return owner_current
	func _reading_request_matches(_request: Dictionary) -> bool: return source_current and owner_current
	func _reading_profile_revision() -> int: return revision
	func _sync_next_presentation(_allow_focus_grab: bool = true) -> void: trace.append("custody")
	func _sync_transport() -> void: pass
	func _complete_next_presentation() -> void:
		trace.append("release")
		_next_pending = false
	func _finish_reading_command(request: Dictionary, result: Dictionary, retry: bool) -> void:
		completed.append({"request": request.duplicate(true), "result": result.duplicate(true), "retry": retry})
		_reading_retry_in_progress = false

class NextAuto extends Node:
	var host: NextHost
	var result := {"ok": true}
	var replace_source := false
	func set_auto_enabled(target: bool) -> Dictionary:
		host.trace.append("auto_on" if target else "auto_off")
		if result.get("ok", false): host.revision += 1
		if replace_source: host.owner_current = false
		return result

func _next_command_fixture() -> Dictionary:
	var host: NextHost = autofree(NextHost.new())
	var auto: NextAuto = autofree(NextAuto.new())
	auto.host = host
	host.auto_controller = auto
	var bridge := NextBridge.new()
	bridge.trace = host.trace
	host._transport_bridge = bridge
	var request := {"kind": &"next", "frontier": {"ok": true, "line": "fixture.pre.a"},
		"profile_revision": 8}
	return {"host": host, "auto": auto, "bridge": bridge, "request": request}

func test_next_preference_refusal_cannot_take_traversal_custody_or_call_bridge() -> void:
	var fixture := _next_command_fixture()
	fixture.auto.result = {"ok": false, "code": &"candidate_write_failed"}
	var result: Dictionary = fixture.host._execute_reading_command(fixture.request)
	assert_eq(result.code, &"candidate_write_failed")
	assert_eq(fixture.host.trace, ["auto_off"], "Auto Off must commit before any traversal side effect")
	assert_false(fixture.host._next_pending)
	assert_true(fixture.bridge.requested.is_empty())
	assert_eq(fixture.request.stage, &"preference", "recovery must describe the failed preference, not traversal")

func test_next_rechecks_source_after_auto_off_and_submits_only_its_exact_frontier() -> void:
	var fixture := _next_command_fixture()
	fixture.auto.replace_source = true
	var retired: Dictionary = fixture.host._execute_reading_command(fixture.request)
	assert_false(retired.ok)
	assert_eq(fixture.host.trace, ["auto_off"])
	assert_true(fixture.bridge.requested.is_empty(), "a synchronous Profile listener cannot authorize stale Next")
	fixture = _next_command_fixture()
	var expected: Dictionary = fixture.request.frontier.duplicate(true)
	var result: Dictionary = fixture.host._execute_reading_command(fixture.request)
	assert_true(result.pending, "the synchronous submitter never owns Bridge's suspended function state")
	assert_eq(fixture.host.completed.size(), 1, "an immediate unseen stop settles before submission returns")
	assert_eq(fixture.host.completed[0].result, fixture.bridge.result)
	assert_eq(fixture.host.trace, ["auto_off", "custody", "request", "release"])
	assert_eq(fixture.bridge.requested, expected)
	assert_eq(fixture.request.profile_revision, 9, "storage Retry retains the committed Auto revision")
	assert_eq(fixture.request.stage, &"next")
	assert_false(fixture.host._next_pending, "one shot releases local custody after the Bridge settles")
	assert_true(fixture.host._next_request.is_empty())
	assert_eq(fixture.bridge.get_signal_connection_list("next_request_finished").size(), 0)

func test_next_completion_requires_exact_source_and_current_callback_generation() -> void:
	var fixture := _next_command_fixture()
	fixture.bridge.finish_immediately = false
	assert_true(fixture.host._execute_reading_command(fixture.request).pending)
	var old_callback: Callable = fixture.host._next_completion_callback
	fixture.bridge.next_request_finished.emit({"ok": true, "line": "other-source"}, fixture.bridge.result)
	assert_true(fixture.host._next_pending, "another request's result cannot release this source's custody")
	assert_true(fixture.host.completed.is_empty())
	fixture.host._retire_next_request()
	assert_eq(fixture.bridge.get_signal_connection_list("next_request_finished").size(), 0)
	assert_true(fixture.host._execute_reading_command(fixture.request, true).pending)
	old_callback.call(fixture.request.frontier, fixture.bridge.result)
	assert_true(fixture.host._next_pending, "retired callback cannot settle a later retry of identical bytes")
	assert_true(fixture.host.completed.is_empty())
	fixture.bridge.next_request_finished.emit(fixture.request.frontier, fixture.bridge.result)
	assert_false(fixture.host._next_pending)
	assert_eq(fixture.host.completed.size(), 1)
	assert_true(fixture.host.completed[0].retry)
	fixture.bridge.next_request_finished.emit(fixture.request.frontier, fixture.bridge.result)
	assert_eq(fixture.host.completed.size(), 1, "the terminal notification cannot be consumed twice")
