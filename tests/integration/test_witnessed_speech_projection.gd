extends GutTest
## Transient speech presentation proof. These fixtures model Dialogic's native Text signals and
## current_state_info without creating a visited-line owner or a durable narrative receipt.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")


class TextSubsystem extends Node:
	signal about_to_show_text(info: Dictionary)
	signal text_started(info: Dictionary)
	signal text_finished(info: Dictionary)


class Runtime extends Node:
	var Text := TextSubsystem.new()
	var current_event_idx := 0
	var current_state_info := {"text_sub_idx": 0, "text_parsed": ""}
	var generation := 1

	func _init() -> void:
		Text.name = "Text"
		add_child(Text)

	func has_subsystem(subsystem_name: String) -> bool:
		return subsystem_name == "Text"

	func get_subsystem(subsystem_name: String) -> Object:
		return Text if subsystem_name == "Text" else null

	func get_timeline_generation() -> int:
		return generation


class RuntimeAdapter extends RefCounted:
	signal timeline_ended_signal
	signal runtime_signal_event(argument: Variant)
	signal playback_start_failed(failure: Dictionary)


class Localization extends Node:
	var locale := "zh_CN"
	func get_locale() -> String: return locale


var bridge: Node
var runtime: Runtime
var localization: Localization
var _original_runtime: Node
var _original_runtime_index := 0
var _original_localization: Node
var _original_localization_index := 0


func before_each() -> void:
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	get_tree().root.remove_child(_original_runtime)
	runtime = Runtime.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)

	_original_localization = get_node("/root/LocalizationManager")
	_original_localization_index = _original_localization.get_index()
	get_tree().root.remove_child(_original_localization)
	localization = Localization.new()
	localization.name = "LocalizationManager"
	get_tree().root.add_child(localization)

	bridge = BRIDGE.new()
	add_child(bridge)
	assert_true(bridge.initialize(null, RuntimeAdapter.new()).get("ok", false))


func after_each() -> void:
	if is_instance_valid(bridge): bridge.free()
	if is_instance_valid(runtime): runtime.free()
	if is_instance_valid(localization): localization.free()
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	get_tree().root.add_child(_original_localization)
	get_tree().root.move_child(_original_localization, _original_localization_index)


func _has_projection_api() -> bool:
	assert_true(bridge.has_method("capture_current_speech_presentation"),
		"DialogicBridge must expose the transient Primary speech presentation")
	return bridge.has_method("capture_current_speech_presentation")


func _publish(text: String, signal_text: String = "[b]unparsed[/b]", append: bool = false) -> void:
	runtime.current_state_info["text_parsed"] = text
	runtime.Text.about_to_show_text.emit({"text": signal_text, "append": append})
	runtime.Text.text_started.emit({"text": signal_text, "append": append})


func _capture() -> Dictionary:
	return bridge.call("capture_current_speech_presentation")


func test_semantic_entry_projects_native_primary_and_resolved_fallback_locale_without_read_identity() -> void:
	if not _has_projection_api(): return
	var resolved: Dictionary = bridge.call("_resolve_entry_for_playback",
		"contact.invitation.ending.priscilla.day7.offer", -1)
	assert_true(resolved.get("ok", false), str(resolved))
	assert_eq(str(resolved.get("value", {}).get("content_locale", "")), "en",
		"the English catalog fallback is retained instead of the zh_CN UI locale")
	bridge.set("_active_entry", {"token": "playback-1", "entry_id": "contact.invitation.ending.priscilla.day7.offer",
		"content_locale": "en", "suppress_first_speech": false})
	runtime.generation = 7
	runtime.current_event_idx = 11
	runtime.current_state_info["text_sub_idx"] = 0
	_publish("Exact parsed Primary", "[b]Exact parsed Primary[/b]")

	var result := _capture()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(result.value.primary_text, "Exact parsed Primary",
		"speech uses Dialogic's displayed parsed text, not signal markup")
	assert_eq(result.value.content_locale, "en")
	assert_eq(result.value.suppress_replay, false)
	assert_eq(result.value.identity.owner_kind, &"entry")
	assert_eq(result.value.identity.owner_token, "playback-1")
	assert_eq(result.value.identity.runtime_generation, 7)
	assert_eq(result.value.identity.event_index, 11)
	assert_eq(result.value.identity.segment_index, 0)
	for forbidden: String in ["line_id", "visited", "receipt_id", "speaker"]:
		assert_false(result.value.has(forbidden) or result.value.identity.has(forbidden),
			"speech projection must not invent " + forbidden)


func test_append_projects_only_new_primary_suffix_while_retaining_full_display_proof() -> void:
	if not _has_projection_api(): return
	bridge.set("_active_entry", {"token": "playback-append", "entry_id": "echo.fallback.day7",
		"content_locale": "en", "suppress_first_speech": false})
	runtime.generation = 8
	runtime.current_event_idx = 4
	runtime.current_state_info["text_sub_idx"] = 0
	_publish("First Primary fragment.", "First Primary fragment.")

	var first := _capture()
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	assert_eq(first.value.primary_text, "First Primary fragment.")
	assert_eq(first.value.display_text, "First Primary fragment.",
		"a non-appended publication speaks and proves the same complete display")

	runtime.current_state_info["text_sub_idx"] = 1
	_publish("First Primary fragment. Newly appended words.", " Newly appended words.", true)
	var appended := _capture()
	assert_true(appended.get("ok", false), str(appended))
	if not appended.get("ok", false): return
	assert_eq(appended.value.display_text, "First Primary fragment. Newly appended words.",
		"append retains the exact complete native Primary display")
	assert_eq(appended.value.primary_text, " Newly appended words.",
		"append speaks only the proven fresh suffix and never repeats the old card")
	assert_ne(appended.value.identity, first.value.identity)


func test_ordinary_hospital_projects_without_registered_line_or_visited_receipt() -> void:
	if not _has_projection_api(): return
	bridge.set("_ordinary_playback", {"timeline_id": "hospital.faint",
		"context": {"kind": "hospital", "day": 3}, "speech_token": "ordinary-3",
		"content_locale": "en", "suppress_first_speech": false})
	runtime.generation = 9
	runtime.current_event_idx = 2
	_publish("You wake under the hospital light.")

	assert_false(bridge.requires_line_presentation_acknowledgement(),
		"Hospital remains outside the registered visited-line ledger")
	var result := _capture()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(result.value.primary_text, "You wake under the hospital light.")
	assert_eq(result.value.content_locale, "en")
	assert_eq(result.value.identity.owner_kind, &"ordinary")
	assert_eq(result.value.identity.owner_token, "ordinary-3")
	assert_eq(result.value.identity.timeline_id, "hospital.faint")


func test_ordered_ending_projects_from_active_playback_without_semantic_entry_receipt() -> void:
	if not _has_projection_api(): return
	bridge.set("_active_playback", {"token": "playback-4", "ending_id": "ending.sylvia.dark",
		"timeline_id": "sylvia", "content_locale": "en", "suppress_first_speech": false,
		"presentation_signature": {"entry_id": "ending.sylvia.dark"}})
	runtime.generation = 12
	runtime.current_event_idx = 5
	_publish("The ordered ending continues.")

	assert_false(bridge.requires_line_presentation_acknowledgement(),
		"ending speech projection does not fabricate an active-entry visited receipt")
	var result := _capture()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_eq(result.value.identity.owner_kind, &"ending")
	assert_eq(result.value.identity.owner_token, "playback-4")
	assert_eq(result.value.identity.timeline_id, "sylvia")
	assert_eq(result.value.primary_text, "The ordered ending continues.")


func test_about_to_show_and_native_or_owner_replacement_refuse_the_stale_publication() -> void:
	if not _has_projection_api(): return
	bridge.set("_active_entry", {"token": "playback-5", "entry_id": "echo.fallback.day7",
		"content_locale": "en", "suppress_first_speech": false})
	runtime.generation = 15
	runtime.current_event_idx = 3
	_publish("Standing source")
	var exact := _capture()
	assert_true(exact.get("ok", false), str(exact))

	runtime.Text.about_to_show_text.emit({"text": "Replacement", "append": false})
	assert_false(_capture().get("ok", true), "replacement announcement retires old speech text")
	_publish("Replacement")
	assert_true(_capture().get("ok", false))
	runtime.current_event_idx = 4
	assert_false(_capture().get("ok", true), "event replacement invalidates the retained projection")
	runtime.current_event_idx = 3
	runtime.generation = 16
	assert_false(_capture().get("ok", true), "timeline replacement invalidates the retained projection")
	runtime.generation = 15
	bridge.set("_active_entry", {"token": "playback-6", "entry_id": "echo.fallback.day7",
		"content_locale": "en", "suppress_first_speech": false})
	assert_false(_capture().get("ok", true), "owner replacement invalidates the retained projection")


func test_resume_suppresses_only_the_first_exact_native_publication() -> void:
	if not _has_projection_api(): return
	bridge.set("_active_entry", {"token": "resume-1", "entry_id": "echo.fallback.day7",
		"content_locale": "en", "suppress_first_speech": true})
	runtime.generation = 21
	runtime.current_event_idx = 6
	_publish("Restored current content")
	var restored := _capture()
	assert_true(restored.get("ok", false), str(restored))
	if not restored.get("ok", false): return
	assert_true(restored.value.suppress_replay, "the restored current publication never replays speech")
	assert_eq(_capture(), restored, "read-only capture is stable and does not consume suppression")

	runtime.current_event_idx = 7
	_publish("A newly presented successor")
	var successor := _capture()
	assert_true(successor.get("ok", false), str(successor))
	if not successor.get("ok", false): return
	assert_false(successor.value.suppress_replay, "only the restored current publication is suppressed")
	assert_ne(successor.value.identity, restored.value.identity)


func test_restored_append_retains_suppressed_display_as_base_for_the_next_fresh_suffix() -> void:
	if not _has_projection_api(): return
	bridge.set("_active_entry", {"token": "resume-append-1", "entry_id": "echo.fallback.day7",
		"content_locale": "en", "suppress_first_speech": true})
	runtime.generation = 22
	runtime.current_event_idx = 6
	runtime.current_state_info["text_sub_idx"] = 1
	_publish("Restored first fragment. Restored appended fragment.", " Restored appended fragment.", true)

	var restored_append := _capture()
	assert_true(restored_append.get("ok", false), str(restored_append))
	if not restored_append.get("ok", false): return
	assert_true(restored_append.value.suppress_replay,
		"the first restored append retains its full native display but cannot replay it")
	assert_eq(restored_append.value.display_text,
		"Restored first fragment. Restored appended fragment.")

	runtime.current_state_info["text_sub_idx"] = 2
	_publish("Restored first fragment. Restored appended fragment. Fresh appended words.",
		" Fresh appended words.", true)
	var fresh_append := _capture()
	assert_true(fresh_append.get("ok", false), str(fresh_append))
	if not fresh_append.get("ok", false): return
	assert_false(fresh_append.value.suppress_replay,
		"restoration suppresses only the already displayed append")
	assert_eq(fresh_append.value.display_text,
		"Restored first fragment. Restored appended fragment. Fresh appended words.")
	assert_eq(fresh_append.value.primary_text, " Fresh appended words.",
		"the next append speaks only the exact suffix proven against the suppressed restored display")


func test_idle_empty_and_unparsed_publications_fail_closed() -> void:
	if not _has_projection_api(): return
	assert_false(_capture().get("ok", true), "idle Bridge has no speech source")
	bridge.set("_ordinary_playback", {"timeline_id": "hospital.faint", "speech_token": "ordinary-empty",
		"content_locale": "en", "suppress_first_speech": false})
	_publish("")
	assert_false(_capture().get("ok", true), "empty display content is not a speech presentation")
	bridge.set("_ordinary_playback", {"timeline_id": "hospital.faint", "speech_token": "ordinary-locale",
		"content_locale": "", "suppress_first_speech": false})
	_publish("Text without a resolved content locale")
	assert_false(_capture().get("ok", true), "UI locale is never substituted for missing content locale")
