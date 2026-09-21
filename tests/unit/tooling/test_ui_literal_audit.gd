extends "res://addons/gut/test.gd"

const AUDIT_PATH := "res://tools/localization/UiLiteralAudit.gd"


func _audit_script() -> Script:
	return load(AUDIT_PATH) as Script


func _has_script_method(script: Script, method_name: String) -> bool:
	for record: Dictionary in script.get_script_method_list():
		if record.get("name") == method_name:
			return true
	return false


func _scene(path: String, source: String) -> Dictionary:
	var audit := _audit_script()
	assert_true(_has_script_method(audit, "scan_scene_source"), "the audit exposes its stateless scene scanner")
	if not _has_script_method(audit, "scan_scene_source"):
		return {}
	var result: Variant = audit.call("scan_scene_source", path, source)
	assert_eq(typeof(result), TYPE_DICTIONARY)
	return result if result is Dictionary else {}


func _script(path: String, source: String) -> Dictionary:
	var audit := _audit_script()
	assert_true(_has_script_method(audit, "scan_script_source"), "the audit exposes its stateless script scanner")
	if not _has_script_method(audit, "scan_script_source"):
		return {}
	var result: Variant = audit.call("scan_script_source", path, source)
	assert_eq(typeof(result), TYPE_DICTIONARY)
	return result if result is Dictionary else {}


func _inventory(expected: Array, supplied: Dictionary) -> Dictionary:
	var audit := _audit_script()
	assert_true(_has_script_method(audit, "validate_source_inventory"), "the audit exposes inventory validation")
	if not _has_script_method(audit, "validate_source_inventory"):
		return {}
	var result: Variant = audit.call("validate_source_inventory", expected, supplied)
	assert_eq(typeof(result), TYPE_DICTIONARY)
	return result if result is Dictionary else {}


func _record(records: Array, sink: String, expression: String) -> Dictionary:
	for value: Variant in records:
		if value is Dictionary and value.get("sink") == sink \
				and value.get("source_expression") == expression:
			return value
	return {}


func test_current_dormant_scene_copy_has_literal_specific_demonstrated_owners() -> void:
	var desktop_path := "res://scenes/desktop/ComputerDesktop.tscn"
	var desktop := _scene(desktop_path, FileAccess.get_file_as_string(desktop_path))
	assert_true(desktop.get("ok", false), JSON.stringify(desktop))
	if not desktop.get("ok", false): return
	var title := _record(desktop.value, "text", "\"New message\"")
	var body := _record(desktop.value, "text", "\"Angela received a new message.\"")
	assert_eq(title.get("disposition"), "localized_call")
	assert_eq(title.get("key"), "desktop.notification.new_message_title")
	assert_false(str(title.get("reason", "")).is_empty())
	assert_eq(body.get("disposition"), "localized_call")
	assert_eq(body.get("key"), "desktop.notification.new_message_from_friend")
	assert_false(str(body.get("reason", "")).is_empty())

	var hospital_path := "res://scenes/hospital/HospitalScene.tscn"
	var hospital := _scene(hospital_path, FileAccess.get_file_as_string(hospital_path))
	assert_true(hospital.get("ok", false), JSON.stringify(hospital))
	if not hospital.get("ok", false): return
	var message := _record(hospital.value, "text", "\"You fainted.\"")
	var continue_button := _record(hospital.value, "text", "\"Continue\"")
	assert_eq(message.get("disposition"), "runtime_data")
	assert_true(str(message.get("reason", "")).contains("HospitalScene"))
	assert_eq(continue_button.get("disposition"), "runtime_data")
	assert_true(str(continue_button.get("reason", "")).contains("HospitalScene"))


func test_scene_owner_is_location_and_literal_specific() -> void:
	var path := "res://scenes/desktop/ComputerDesktop.tscn"
	var source := FileAccess.get_file_as_string(path).replace(
		'text = "New message"', 'text = "Changed message"')
	var result := _scene(path, source)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"unclassified_scene_literal")


func test_spoofed_binding_and_unknown_catalog_key_are_refused() -> void:
	var spoof := _scene("res://scenes/fixture/Spoof.tscn", """
[gd_scene format=3]
[node name="Root" type="Control"]
[node name="Label" type="Label" parent="."]
text = "Unowned"
[node name="Spoof" type="Node" parent="."]
target_path = NodePath("../Label")
key = "button.close"
""".strip_edges())
	assert_false(spoof.get("ok", true))
	assert_eq(spoof.get("code"), &"unclassified_scene_literal")

	var unknown_key := _scene("res://scenes/fixture/UnknownKey.tscn", """
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" uid="uid://fixture" path="res://scripts/ui/LocalizedBinding.gd" id="1_binding"]
[node name="Root" type="Control"]
[node name="Label" type="Label" parent="."]
text = "Unowned"
[node name="L10n" type="Node" parent="."]
script = ExtResource("1_binding")
target_path = NodePath("../Label")
key = "fixture.missing"
""".strip_edges())
	assert_false(unknown_key.get("ok", true))
	assert_eq(unknown_key.get("code"), &"unknown_translation_key")


func test_unknown_shared_placeholder_is_not_blanket_runtime_data() -> void:
	var result := _scene("res://scenes/shared/UnknownFixture.tscn", """
[gd_scene format=3]
[node name="UnknownFixture" type="Control"]
[node name="Label" type="Label" parent="."]
text = "Stable shared copy"
""".strip_edges())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"unclassified_scene_literal")


func test_script_scanner_refuses_stable_literals_inside_expressions_and_later_arguments() -> void:
	for fixture: Dictionary in [
		{"line": 'label.text = "Retry" if failed else "Continue"', "sink": "text"},
		{"line": 'label.text = "Version %d" % version', "sink": "text"},
		{"line": 'option.set_item_text(index, "Unowned")', "sink": "set_item_text"},
		{"line": 'label.text = ["Untranslated"][0]', "sink": "text"},
		{"line": 'label.text = values["Retry"] if ready else "Retry"', "sink": "text"},
	]:
		var result := _script("res://scripts/ui/fixture/Unowned.gd", str(fixture.line))
		assert_false(result.get("ok", true), str(fixture.line))
		assert_eq(result.get("code"), &"unclassified_script_literal")
		assert_eq(result.get("sink"), fixture.sink)


func test_script_scanner_collects_every_failure_instead_of_stopping_at_the_first() -> void:
	var result := _script("res://scripts/ui/fixture/TwoFailures.gd", """
func refresh() -> void:
	first.text = "First unowned label"
	options.set_item_text(0, "Second unowned label")
""".strip_edges())
	assert_false(result.get("ok", true))
	assert_eq(result.get("value", []).size(), 2)
	assert_eq(result.get("failures", []).size(), 2)
	if result.get("value", []).size() == 2:
		assert_eq(result.value[0].get("disposition"), "unclassified")
		assert_eq(result.value[1].get("disposition"), "unclassified")


func test_script_scanner_accepts_registered_lookup_and_dynamic_presenter_value() -> void:
	var source := """
func refresh() -> void:
	title.text = _localization.t("desktop.notification.new_message_title")
	body.text = presented_text
""".strip_edges()
	var result := _script("res://scripts/ui/fixture/Owned.gd", source)
	assert_true(result.get("ok", false), JSON.stringify(result))
	if not result.get("ok", false): return
	assert_eq(result.value.size(), 2)
	assert_eq(result.value[0].get("disposition"), "localized_call")
	assert_eq(result.value[0].get("key"), "desktop.notification.new_message_title")
	assert_eq(result.value[1].get("disposition"), "runtime_data")
	assert_false(str(result.value[1].get("reason", "")).is_empty())


func test_direct_properties_and_accessibility_descriptions_are_sinks() -> void:
	for fixture: Dictionary in [
		{"line": 'text = "Untranslated"', "sink": "text"},
		{"line": 'label.accessibility_description = "Untranslated description"', "sink": "accessibility_description"},
		{"line": 'accessibility_description = "Untranslated description"', "sink": "accessibility_description"},
	]:
		var result := _script("res://scripts/ui/fixture/Direct.gd",
			"extends Label\nfunc refresh() -> void:\n\t" + str(fixture.line))
		assert_false(result.get("ok", true), str(fixture.line))
		assert_eq(result.get("code"), &"unclassified_script_literal")
		assert_eq(result.get("sink"), fixture.sink)
		assert_eq(result.get("value", []).size(), 1)


func test_comments_cannot_spoof_localization_or_create_sinks() -> void:
	var spoof := _script("res://scripts/ui/fixture/Comment.gd", """
func refresh() -> void:
	label.text = "Untranslated" # LocalizationManager.t("button.close")
	# phantom.text = "Phantom"
""".strip_edges())
	assert_false(spoof.get("ok", true))
	assert_eq(spoof.get("value", []).size(), 1)
	if spoof.get("value", []).size() == 1:
		assert_eq(spoof.value[0].get("source_expression"), '"Untranslated"')

	var comments_only := _script("res://scripts/ui/fixture/CommentsOnly.gd",
		'# label.text = "Phantom"\n# accessibility_description = "Phantom"')
	assert_true(comments_only.get("ok", false), JSON.stringify(comments_only))
	assert_true(comments_only.get("value", []).is_empty())


func test_localized_call_does_not_own_an_untranslated_sibling_fallback() -> void:
	var result := _script("res://scripts/ui/fixture/Mixed.gd",
		'label.text = LocalizationManager.t("button.close") if ready else "Untranslated fallback"')
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"unclassified_script_literal")


func test_lowercase_one_word_and_inline_locale_spoof_are_refused() -> void:
	var lowercase := _script("res://scripts/ui/fixture/Lower.gd", 'label.text = "retry"')
	assert_false(lowercase.get("ok", true))
	assert_eq(lowercase.get("code"), &"unclassified_script_literal")
	var spoof := _script("res://scripts/ui/fixture/Inline.gd",
		'label.text = "Untranslated" + str({"en": 0, "zh-CN": 1, "zh-HK": 2})')
	assert_false(spoof.get("ok", true))
	assert_eq(spoof.get("code"), &"unclassified_script_literal")


func test_localized_binding_refuses_root_escape_and_requires_exact_format_parameters() -> void:
	var header := """
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/ui/LocalizedBinding.gd" id="1_binding"]
[node name="Root" type="Control"]
[node name="Label" type="Label" parent="."]
text = "Angela received a new message."
[node name="L10n" type="Node" parent="."]
script = ExtResource("1_binding")
""".strip_edges()
	var escaped := _scene("res://scenes/fixture/Escape.tscn", header + "\n" + """
target_path = NodePath("../../Label")
key = "button.close"
""".strip_edges())
	assert_false(escaped.get("ok", true))
	assert_eq(escaped.get("code"), &"invalid_localized_binding_target")

	var missing := _scene("res://scenes/fixture/Parameters.tscn", header + "\n" + """
target_path = NodePath("../Label")
key = "desktop.notification.new_message_from_friend"
""".strip_edges())
	assert_false(missing.get("ok", true))
	assert_eq(missing.get("code"), &"localized_binding_parameter_mismatch")

	var complete := _scene("res://scenes/fixture/Parameters.tscn", header + "\n" + """
target_path = NodePath("../Label")
key = "desktop.notification.new_message_from_friend"
parameters = {"friend_name": "Angela"}
""".strip_edges())
	assert_true(complete.get("ok", false), JSON.stringify(complete))


func test_source_inventory_is_sorted_complete_and_reports_unreadable_sources() -> void:
	var complete := _inventory(["res://B.gd", "res://A.gd"], {
		"res://A.gd": "extends Node", "res://B.gd": 'label.text = value'})
	assert_true(complete.get("ok", false), JSON.stringify(complete))
	assert_eq(complete.get("source_paths"), ["res://A.gd", "res://B.gd"])
	assert_eq(complete.get("source_count"), 2)
	var unreadable := _inventory(["res://A.gd", "res://B.gd"], {"res://A.gd": "extends Node", "res://B.gd": null})
	assert_false(unreadable.get("ok", true))
	assert_eq(unreadable.get("code"), &"source_read_failed")
	assert_eq(unreadable.get("source_paths"), ["res://A.gd", "res://B.gd"])
	var mismatch := _inventory(["res://A.gd"], {"res://A.gd": "", "res://Extra.gd": ""})
	assert_false(mismatch.get("ok", true))
	assert_eq(mismatch.get("code"), &"source_inventory_mismatch")


func test_scene_accessibility_description_is_audited() -> void:
	var result := _scene("res://scenes/fixture/Description.tscn", """
[gd_scene format=3]
[node name="Description" type="Control"]
accessibility_description = "Untranslated help"
""".strip_edges())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"unclassified_scene_literal")
	assert_eq(result.get("value", []).size(), 1)
	if result.get("value", []).size() == 1:
		assert_eq(result.value[0].get("sink"), "accessibility_description")


func test_direct_inherited_property_is_audited_in_every_script_root() -> void:
	var result := _script("res://autoload/Fixture.gd", """
extends Label
func refresh() -> void:
	text = "Untranslated"
""".strip_edges())
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"unclassified_script_literal")
	assert_eq(result.get("value", []).size(), 1)


func test_path_specific_helper_does_not_own_sibling_fallback() -> void:
	var result := _script("res://scripts/ui/SettingsContent.gd",
		'label.text = text("settings.cancel") if ready else "Untranslated fallback"')
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"unclassified_script_literal")
	var owned := _script("res://scripts/ui/BackupApp.gd", 'label.text = _t("unavailable")')
	assert_true(owned.get("ok", false), JSON.stringify(owned))
	var quoted := _script("res://scripts/ui/BackupApp.gd", 'label.text = "_t(owned)"')
	assert_false(quoted.get("ok", true))
	assert_eq(quoted.get("code"), &"unclassified_script_literal")


func test_quoted_dead_code_cannot_authenticate_an_owner_marker() -> void:
	var audit := _audit_script()
	assert_true(_has_script_method(audit, "_source_contains_code_marker"))
	if not _has_script_method(audit, "_source_contains_code_marker"): return
	var marker := 'notification_title.text = _localization.t("desktop.notification.new_message_title")'
	assert_false(bool(audit.call("_source_contains_code_marker", "var fake = '" + marker + "'", marker)))
	assert_false(bool(audit.call("_source_contains_code_marker",
		'var fake = """\n' + marker + '\n"""', marker)))
	assert_true(bool(audit.call("_source_contains_code_marker", marker, marker)))


func test_dating_copy_has_concrete_five_locale_ownership() -> void:
	var path := "res://scripts/ui/DatingScene.gd"
	var source := FileAccess.get_file_as_string(path)
	var result := _script(path, source)
	assert_true(result.get("ok", false), JSON.stringify(result))
	var retry := _record(result.get("value", []), "text", '_ui_text("Retry")')
	assert_eq(retry.get("disposition"), "localized_call")
	assert_eq(retry.get("key"), "DatingScene.ui.inline")
	for changed: String in [
		source.replace('"Retry": "重试"', '"Other": "重试"'),
		source.replace('"Retry": "重試"', '"Retry": ""'),
		source.replace('"Retry": "再試行"', '"Retry": "Retry"'),
		source.replace('"ko": {', '"unsupported": {'),
		source.replace('return str(DRAFT_UI_COPY.get(_locale.replace("_", "-"), {}).get(english, english))', 'return english'),
	]:
		assert_ne(changed, source, "the fixture changes an actual locale or helper seam")
		var rejected := _script(path, changed)
		assert_false(rejected.get("ok", true))
		assert_eq(rejected.get("code"), &"unclassified_script_literal")


func test_notification_copy_exists_in_all_five_catalogs_with_the_friend_parameter() -> void:
	for locale: String in ["en", "zh_CN", "zh_HK", "ja", "ko"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/ui/%s.json" % locale))
		var translated := ""
		for message: Dictionary in catalog.messages:
			if message.id == "desktop.notification.new_message_from_friend":
				translated = message.text
		assert_false(translated.is_empty(), locale)
		assert_eq(translated.count("{friend_name}"), 1, locale)


func test_dating_copy_rejects_unknown_phrases_untranslated_siblings_and_spoofed_helpers() -> void:
	var path := "res://scripts/ui/DatingScene.gd"
	var source := FileAccess.get_file_as_string(path)
	for expression: String in [
		'_ui_text("Unregistered phrase")',
		'_ui_text("Retry") + "Untranslated sibling"',
		'_ui_text("Retry") if ready else "Untranslated fallback"',
		'_ui_text(dynamic_phrase)',
		'"_ui_text(Retry)"',
	]:
		var result := _script(path, source + "\nfunc fixture() -> void:\n\tlabel.text = " + expression)
		assert_false(result.get("ok", true), expression)
		assert_eq(result.get("code"), &"unclassified_script_literal")
	assert_false(_script("res://scripts/ui/fixture/Spoof.gd", source).get("ok", true))
	var table_start := source.find("const DRAFT_UI_COPY := ")
	var table_end := source.find("\n\n", table_start)
	var table := source.substr(table_start, table_end - table_start)
	var quoted_table := source.replace(table, 'var fake = """\n' + table + '\n"""')
	assert_false(_script(path, quoted_table).get("ok", true), "quoted table data grants no ownership")
	assert_false(_script(path, source.replace("const DRAFT_UI_COPY := ", "# const DRAFT_UI_COPY := ")).get("ok", true),
		"commented table declaration grants no ownership")
	var helper := 'func _ui_text(english: String) -> String:\n\treturn str(DRAFT_UI_COPY.get(_locale.replace("_", "-"), {}).get(english, english))'
	var quoted_helper := source.replace(helper, 'func _ui_text(english: String) -> String:\n\treturn english') \
		+ '\nvar fake_helper = """\n' + helper + '\n"""'
	assert_false(_script(path, quoted_helper).get("ok", true), "quoted helper code grants no ownership")
