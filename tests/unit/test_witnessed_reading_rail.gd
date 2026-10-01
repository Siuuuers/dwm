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
