extends SceneTree

const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCENE_OUTPUT := "res://evidence/phase_2r/localization/ui_literal_disposition.json"
const SCRIPT_OUTPUT := "res://evidence/phase_2r/localization/script_ui_disposition.json"
const EN_CATALOG := "res://localization/ui/en.json"
const CATALOGS := [EN_CATALOG, "res://localization/ui/zh_CN.json", "res://localization/ui/zh_HK.json"]
const SCENE_PROPERTIES := ["text", "placeholder_text", "tooltip_text", "accessibility_name", "accessibility_description"]
const SCRIPT_PROPERTIES := ["text", "placeholder_text", "tooltip_text", "accessibility_name", "accessibility_description", "dialog_text"]
const SCRIPT_CALLS := ["set_text", "add_item", "set_item_text"]
const VALID_DISPOSITIONS := ["localized_binding", "localized_call", "runtime_data", "decorative", "narrative_owned_by_dialogic", "unclassified"]

## Exact dormant scene values with a current, inspectable presenter. Including the literal in the
## key prevents changed copy from silently inheriting an obsolete disposition.
const SCENE_LITERAL_OWNERS := {
	"res://scenes/desktop/ComputerDesktop.tscn|NotificationLayer/MinesweeperMessageNotification/NotifContent/NotificationTitle|text|New message": {
		"disposition": "localized_call", "key": "desktop.notification.new_message_title",
		"reason": "ComputerDesktop catalogs the hidden notification before show",
		"owner_path": "res://scripts/ui/ComputerDesktop.gd",
		"markers": ['notification_title.text = _localization.t("desktop.notification.new_message_title")', "message_notification.show()"]},
	"res://scenes/desktop/ComputerDesktop.tscn|NotificationLayer/MinesweeperMessageNotification/NotifContent/NotificationBody|text|Angela received a new message.": {
		"disposition": "localized_call", "key": "desktop.notification.new_message_from_friend",
		"reason": "ComputerDesktop catalogs the hidden notification before show",
		"owner_path": "res://scripts/ui/ComputerDesktop.gd",
		"markers": ['notification_body.text = _localization.t("desktop.notification.new_message_from_friend"', "message_notification.show()"]},
	"res://scenes/hospital/HospitalScene.tscn|FaintNotice/Margin/Content/Message|text|You fainted.": {
		"disposition": "runtime_data", "key": "",
		"reason": "HospitalScene replaces the dormant hidden notice from its five-locale presentation table",
		"owner_path": "res://scripts/ui/HospitalScene.gd",
		"markers": ['_message_label.text = {"en": "You fainted.", "zh-CN": "你晕倒了。", "zh-HK": "你暈倒了。", "ja": "気を失いました。", "ko": "정신을 잃었습니다."}[locale]', "_notice_panel.visible = not sylvia_present"]},
	"res://scenes/hospital/HospitalScene.tscn|FaintNotice/Margin/Content/ContinueButton|text|Continue": {
		"disposition": "runtime_data", "key": "",
		"reason": "HospitalScene replaces the dormant hidden control from its five-locale presentation table",
		"owner_path": "res://scripts/ui/HospitalScene.gd",
		"markers": ['_continue_button.text = {"en": "Continue", "zh-CN": "继续", "zh-HK": "繼續", "ja": "続ける", "ko": "계속"}[locale]', "_notice_panel.visible = not sylvia_present"]},
	"res://scenes/shared/AppWindowBase.tscn|VBoxContainer/TopBar/TopBarHBox/TitleLabel|text|App": {
		"disposition": "localized_call", "key": "dynamic", "reason": "AppWindowBase catalogs the configured app title",
		"owner_path": "res://scripts/ui/AppWindowBase.gd", "markers": ["_title_label.text = get_node(\"/root/LocalizationManager\").t(title_key)"]},
	"res://scenes/shared/BoxMeter.tscn|VBoxContainer/HeaderHBox/NameLabel|text|Stat": {
		"disposition": "localized_call", "key": "dynamic", "reason": "BoxMeter catalogs the configured stat name",
		"owner_path": "res://scripts/ui/BoxMeter.gd", "markers": ["_name_label.text = get_node(\"/root/LocalizationManager\").t(display_name_key)"]},
	"res://scenes/shared/ChatBubble.tscn|VBox/SpeakerLabel|text|Speaker": {
		"disposition": "narrative_owned_by_dialogic", "key": "", "reason": "ChatBubble projects the active narrative speaker",
		"owner_path": "res://scripts/ui/ChatBubble.gd", "markers": ["speaker_label.text = speaker_name"]},
	"res://scenes/shared/ContactBox.tscn|HBox/TextVBox/NameLabel|text|Friend": {
		"disposition": "runtime_data", "key": "", "reason": "ContactBox projects the supplied contact display name",
		"owner_path": "res://scripts/ui/ContactBox.gd", "markers": ["name_label.text = display_name"]},
	"res://scenes/shared/IconButton.tscn|VBoxContainer/IconLabel|text|Icon": {
		"disposition": "localized_call", "key": "dynamic", "reason": "IconButton catalogs the configured launcher label",
		"owner_path": "res://scripts/ui/IconButton.gd", "markers": ["_icon_label.text = get_node(\"/root/LocalizationManager\").t(label_key)"]},
	"res://scenes/shared/SaveSlotRow.tscn|VBox/SlotTitleLabel|text|Slot": {
		"disposition": "runtime_data", "key": "",
		"reason": "unmounted SaveSlotRow scaffold placeholder; no production scene or script instances this resource",
		"owner_path": "res://scripts/ui/SaveSlotRow.gd", "markers": ["class_name SaveSlotRow", "slot_title_label: Label"]},
}

## Private translation helpers are path-specific. A coincidentally named helper elsewhere gets no waiver.
const SCRIPT_LOCALIZATION_HELPERS := {
	"res://scripts/ui/BackupApp.gd": ["_t("],
	"res://scripts/ui/ComputerDesktop.gd": ["LABELS["],
	"res://scripts/ui/DatingScene.gd": ["presentation_copy(", "CHROME_COPY.get_copy("],
	"res://scripts/ui/gallery/GalleryRehearsalHost.gd": ["_copy(", "VIEW_SAVE_COPY["],
	"res://scripts/ui/GalleryScene.gd": ["_localized(", "_record_title("],
	"res://scripts/ui/schedule/SchedulePanel.gd": ["COPY["],
	"res://scripts/ui/SettingsContent.gd": ["text("],
	"res://scripts/ui/SettingsControlsSheet.gd": ["_text(", "_action_label("],
	"res://scripts/ui/SettingsPanelController.gd": ["_content.text("],
	"res://scripts/ui/ShopApp.gd": ["_t(", "_supportz_accessible_name("],
	"res://scripts/ui/ShopItemBox.gd": ["_copy["],
	"res://scripts/ui/StatHud.gd": ["COPY["],
	"res://scripts/ui/desktop/QuickStatusEdge.gd": ["COPY["],
	"res://scripts/ui/desktop/RoutineClock.gd": ["NAMES[", "UNAVAILABLE["],
}

const SCRIPT_LITERAL_OWNERS := {
	"res://scripts/ui/ComputerDesktop.gd|text|\"New message\"": {"disposition": "localized_call",
		"key": "desktop.notification.new_message_title", "reason": "English fallback for the adjacent catalog lookup",
		"marker": 'notification_title.text = _localization.t("desktop.notification.new_message_title")'},
	"res://scripts/ui/ComputerDesktop.gd|text|\"Angela received a new message from %s.\" % friend_name": {"disposition": "localized_call",
		"key": "desktop.notification.new_message_from_friend", "reason": "English fallback for the adjacent catalog lookup",
		"marker": 'notification_body.text = _localization.t("desktop.notification.new_message_from_friend"'},
	"res://scripts/ui/desktop/TitleWelcome.gd|text|\"DWM\"": {"disposition": "decorative", "key": "", "reason": "product mark"},
	"res://scripts/ui/desktop/TitleWelcome.gd|text|\"Welcome! :)\"": {"disposition": "decorative", "key": "", "reason": "fixed title brand line required verbatim by current UI authority"},
	"res://scripts/ui/GalleryScene.gd|text|\"\\u7df4\\u7fd2\" if locale.replace(\"_\", \"-\") == \"zh-HK\" else (\"\\u7ec3\\u4e60\" if locale.begins_with(\"zh\") else \"Practice\")": {
		"disposition": "localized_call", "key": "GalleryScene.practice.inline", "reason": "explicit English and both Chinese projections"},
	"res://scripts/ui/GalleryScene.gd|add_item|(\"版本 %d\" if locale.begins_with(\"zh\") else \"Version %d\") % (index + 1))": {
		"disposition": "localized_call", "key": "GalleryScene.version.inline", "reason": "explicit English and shared Chinese projection"},
	"res://scripts/ui/HospitalScene.gd|text|{\"en\": \"You fainted.\", \"zh-CN\": \"你晕倒了。\", \"zh-HK\": \"你暈倒了。\", \"ja\": \"気を失いました。\", \"ko\": \"정신을 잃었습니다.\"}[locale]": {
		"disposition": "localized_call", "key": "HospitalScene.message.inline", "reason": "exact five-locale Hospital projection"},
	"res://scripts/ui/HospitalScene.gd|text|{\"en\": \"Continue\", \"zh-CN\": \"继续\", \"zh-HK\": \"繼續\", \"ja\": \"続ける\", \"ko\": \"계속\"}[locale]": {
		"disposition": "localized_call", "key": "HospitalScene.continue.inline", "reason": "exact five-locale Hospital projection"},
}

## Exact expression digests keep component-owned locale tables reviewable without granting a
## general exemption to any expression that happens to contain locale names.
const SCRIPT_EXPRESSION_OWNERS := {
	"res://scripts/ui/ComputerDesktop.gd|text|7b1f861b7d8a5f75a97cad819f510ed4ad13adc64754f6459f7b95ccdf599ab8": {"key": "ComputerDesktop.launcher.inline", "reason": "exact localized launcher label with complete three-locale unavailable fallback"},
	"res://scripts/ui/ComputerDesktop.gd|accessibility_name|1c2117f764f304b74d023b945e3a86e66d53b2b7dc26a38bddc55776f981ea17": {"key": "ComputerDesktop.local_time.inline", "reason": "exact three-locale local-time label"},
	"res://scripts/ui/ComputerDesktop.gd|text|15a5427cd300c95fddb2bbdc872b6735e0b4680dd4006db5d3eace9ef45ea0b2": {"key": "ComputerDesktop.unavailable.inline", "reason": "exact three-locale unavailable status"},
	"res://scripts/ui/ComputerDesktop.gd|accessibility_name|52c0617d8a7c2ec41f50e0da0f47fd2fd4666aaabad54ca5f245e5f74a766ca5": {"key": "ComputerDesktop.unread.inline", "reason": "exact three-locale unread accessibility suffix"},
	"res://scripts/ui/ComputerDesktop.gd|accessibility_description|602b33f9d12df877dcfead78497301a74199f1316c973ae08cffa7a202dbcb53": {"key": "ComputerDesktop.time_unavailable.inline", "reason": "exact three-locale clock availability description"},
	"res://scripts/ui/ContactListApp.gd|text|88268794607df1839e375e9779a22a6f4a505c306b332e4c2dd03d43f1a2abe3": {"key": "ContactListApp.title.inline", "reason": "exact three-locale Contacts title"},
	"res://scripts/ui/ContactListApp.gd|accessibility_name|296c8b33851da4c172df8087c04e08b3604098f0b3eec1f5c70c6e51cb75a3e7": {"key": "ContactListApp.back.inline", "reason": "exact three-locale back label"},
	"res://scripts/ui/ContactListApp.gd|text|ed708873309db354445be81a1104d5b21b6aeff4dbffc91c62a070f7641911d6": {"key": "ContactListApp.unavailable.inline", "reason": "exact three-locale unavailable status"},
	"res://scripts/ui/ContactListApp.gd|text|6ee54144674bebdc62c81f74b3dc9f4c95cd9c782d32bd011cedff4d8a46d27f": {"key": "ContactListApp.reply.inline", "reason": "exact three-locale Reply control"},
	"res://scripts/ui/ContactListApp.gd|text|69fa4a662c542ebc0f4c573a11aadfa768e62c75964e644530f58637be6ab19c": {"key": "ContactListApp.failure.inline", "reason": "exact three-locale reply failure"},
	"res://scripts/ui/LogOutApp.gd|text|398d77227e83e0b9a74652c53dadc255e97fe6519cd36b279d96bfca3a664ef8": {"key": "LogOutApp.prompt.inline", "reason": "exact three-locale logout prompt"},
	"res://scripts/ui/LogOutApp.gd|text|e2379bcc62ed1dce475ed6566a0e2ae540e3f5be3d906aec2c4eaf10d861e2bf": {"key": "LogOutApp.failure.inline", "reason": "exact three-locale logout failure"},
	"res://scripts/ui/MenuScene.gd|accessibility_name|d64daaa57285e651f898f2ef57e395b750530598561a9ebc9354383e4eafbaf6": {"key": "MenuScene.return.inline", "reason": "exact three-locale Return projection"},
	"res://scripts/ui/MenuScene.gd|text|f821301dd49e52a83e6763d0f48b0dacf0fe41bb7bf943525e6e95d613008c87": {"key": "MenuScene.unavailable.inline", "reason": "exact three-locale unavailable projection"},
	"res://scripts/ui/MenuScene.gd|text|4681aad1314c04a7d1b9d28f4a9048e586270a11c861d79ed8d6ade3a0014504": {"key": "dynamic", "reason": "exact catalog lookup with matching English fail-closed menu labels"},
	"res://scripts/ui/minesweeper/MinesweeperScrollRail.gd|accessibility_name|83f1428a93f2041ec5409af4a75dcdacf349024b16869a0033d20910f120be84": {"key": "MinesweeperScrollRail.name.inline", "reason": "exact Simplified Chinese branch of the three-locale scroll projection", "group": "scroll"},
	"res://scripts/ui/minesweeper/MinesweeperScrollRail.gd|accessibility_description|6dd7175fb4e6ea843a2a8fc107b3b42c51ed44146f7ff2b5ebd9d5d862fadb94": {"key": "MinesweeperScrollRail.position.inline", "reason": "exact shared Chinese branch of the three-locale scroll projection", "group": "scroll"},
	"res://scripts/ui/minesweeper/MinesweeperScrollRail.gd|accessibility_name|a6a49202e2b131662916bf536b35bb6561fd69744bbdf0550e9ebf86c3cafdbf": {"key": "MinesweeperScrollRail.name.inline", "reason": "exact Traditional Chinese branch of the three-locale scroll projection", "group": "scroll"},
	"res://scripts/ui/minesweeper/MinesweeperScrollRail.gd|accessibility_name|d66da7d74b497a8bc139186b0c0a875ff137c14432d7efdcdefb4ceba4f7371d": {"key": "MinesweeperScrollRail.name.inline", "reason": "exact English branch of the three-locale scroll projection", "group": "scroll"},
	"res://scripts/ui/minesweeper/MinesweeperScrollRail.gd|accessibility_description|f903b033daa374eb58b1260edd1a2d8f272e578a13a536418ca5b4bc1dca0bf2": {"key": "MinesweeperScrollRail.position.inline", "reason": "exact English branch of the three-locale scroll projection", "group": "scroll"},
	"res://scripts/ui/witnessed/SceneArtHoldSurface.gd|text|e801ceb24e8ac1a3d5bbe9e357fb8176c25abc77959436fe6b7a9d4429b755e4": {"key": "SceneArtHoldSurface.continue.inline", "reason": "exact three-locale Continue projection"},
	"res://scripts/ui/DatingScene.gd|text|bff246e7d990bb1b0c821baf376c255284c95b50393e025236c4e9be876fdcee": {"key": "MinesweeperChromeCopy.rules.inline", "reason": "exact Rules fallback backed by the complete three-locale chrome table", "group": "chrome_rules"},
}


func _init() -> void:
	var scene_records: Array = []
	var scene_failures: Array = []
	var scene_inventory := inventory_below("res://scenes", ".tscn")
	scene_failures.append_array(scene_inventory.failures)
	for path: String in scene_inventory.source_paths:
		var read := _read_source(path)
		if not read.ok:
			scene_failures.append(read)
			continue
		var scanned := scan_scene_source(path, read.value)
		scene_records.append_array(scanned.get("value", []))
		scene_failures.append_array(scanned.get("failures", []))
	var script_records: Array = []
	var script_failures: Array = []
	var script_paths: Array = []
	for root in ["res://autoload", "res://scripts"]:
		var inventory := inventory_below(root, ".gd")
		script_failures.append_array(inventory.failures)
		for path: String in inventory.source_paths:
			if path.ends_with("/UiLiteralAudit.gd"):
				continue
			script_paths.append(path)
			var read := _read_source(path)
			if not read.ok:
				script_failures.append(read)
				continue
			var scanned := scan_script_source(path, read.value)
			script_records.append_array(scanned.get("value", []))
			script_failures.append_array(scanned.get("failures", []))
	script_paths.sort()
	var scene_write := _validate_and_write(SCENE_OUTPUT, scene_records, scene_failures, scene_inventory.source_paths)
	if not scene_write.get("ok", false):
		_fail(scene_write)
		return
	var script_write := _validate_and_write(SCRIPT_OUTPUT, script_records, script_failures, script_paths)
	if not script_write.get("ok", false):
		_fail(script_write)
		return
	var failures := scene_failures + script_failures
	if not failures.is_empty():
		_fail({"ok": false, "code": &"unclassified_literals", "failures": failures,
			"scene_records": scene_records.size(), "script_records": script_records.size()})
		return
	quit(0)


static func scan_scene_source(path: String, source: String) -> Dictionary:
	var lines := source.split("\n")
	var binding_result := _scene_binding_targets(lines)
	var bindings: Dictionary = binding_result.get("value", {})
	var records: Array = []
	var failures: Array = binding_result.get("failures", []).duplicate(true)
	var current_node := ""
	var catalog_keys := _catalog_keys()
	for index in range(lines.size()):
		var line: String = lines[index].trim_suffix("\r")
		if line.begins_with("[node "):
			current_node = _scene_node_path(line)
			continue
		for property in SCENE_PROPERTIES:
			var prefix := "%s = " % property
			if not line.begins_with(prefix):
				continue
			var expression := line.substr(prefix.length())
			var decoded: Variant = JSON.parse_string(expression)
			if typeof(decoded) != TYPE_STRING:
				failures.append(_failure(&"invalid_scene_literal", path, index + 1, property))
				continue
			var target_key := "%s:%s" % [current_node, property]
			var disposition: Dictionary
			if bindings.has(target_key):
				var binding: Dictionary = bindings[target_key]
				var key := str(binding.key)
				if not catalog_keys.has(key):
					disposition = _unclassified("LocalizedBinding key is absent from the English source catalog")
					failures.append(_failure(&"unknown_translation_key", path, index + 1, property))
				elif not _binding_parameters_match(key, binding.parameters):
					disposition = _unclassified("LocalizedBinding parameters do not exactly match catalog placeholders")
					failures.append(_failure(&"localized_binding_parameter_mismatch", path, index + 1, property))
				else:
					disposition = {"disposition": "localized_binding", "key": key,
						"reason": "explicit authentic LocalizedBinding target"}
			else:
				disposition = _scene_disposition(path, current_node, property, str(decoded))
				if disposition.disposition == "unclassified":
					failures.append(_failure(&"unclassified_scene_literal", path, index + 1, property))
			records.append(_record(path, index + 1, property, expression, disposition, line))
	return _scan_result(records, failures)


static func _scene_disposition(path: String, node_path: String, property: String, text: String) -> Dictionary:
	if text.is_empty() or text.is_valid_int() or text.is_valid_float():
		return {"disposition": "runtime_data", "key": "", "reason": "empty or numeric runtime placeholder"}
	if text in ["+", "-", "X"]:
		return {"disposition": "decorative", "key": "", "reason": "symbol-only control glyph"}
	var owner_key := "%s|%s|%s|%s" % [path, node_path, property, text]
	if not SCENE_LITERAL_OWNERS.has(owner_key):
		return _unclassified("stable literal requires an exact localization owner or specific disposition")
	var owner: Dictionary = SCENE_LITERAL_OWNERS[owner_key]
	var owner_path := str(owner.get("owner_path", ""))
	var owner_source := FileAccess.get_file_as_string(owner_path)
	if owner_path.is_empty() or owner_source.is_empty():
		return _unclassified("declared scene literal owner source is missing")
	for marker: String in owner.get("markers", []):
		if not _source_contains_code_marker(owner_source, marker):
			return _unclassified("declared scene literal owner seam is missing")
	return {"disposition": owner.disposition, "key": owner.key, "reason": owner.reason}


static func _scene_binding_targets(lines: PackedStringArray) -> Dictionary:
	var binding_script_ids := {}
	for line_value in lines:
		var line: String = line_value.trim_suffix("\r")
		if line.begins_with("[ext_resource ") and 'path="res://scripts/ui/LocalizedBinding.gd"' in line:
			var resource_id := _quoted_attribute(line, "id")
			if not resource_id.is_empty():
				binding_script_ids[resource_id] = true
	var nodes: Array = []
	var current: Dictionary = {}
	for line_value in lines:
		var line: String = line_value.trim_suffix("\r")
		if line.begins_with("[node "):
			if not current.is_empty():
				nodes.append(current)
			current = {"path": _scene_node_path(line), "script_id": "", "target": "",
				"property": "text", "key": "", "parameters": {}}
		elif not current.is_empty() and line.begins_with("script = ExtResource("):
			current.script_id = line.get_slice('"', 1)
		elif not current.is_empty() and line.begins_with("target_path = NodePath("):
			current.target = line.get_slice('"', 1)
		elif not current.is_empty() and line.begins_with("target_property = "):
			current.property = line.get_slice('"', 1)
		elif not current.is_empty() and line.begins_with("key = "):
			current.key = line.get_slice('"', 1)
		elif not current.is_empty() and line.begins_with("parameters = "):
			var decoded: Variant = JSON.parse_string(line.trim_prefix("parameters = "))
			current.parameters = decoded if decoded is Dictionary else null
	if not current.is_empty():
		nodes.append(current)
	var output := {}
	var failures: Array = []
	for node: Dictionary in nodes:
		if not binding_script_ids.has(node.script_id):
			continue
		if str(node.target).is_empty() or str(node.key).is_empty():
			failures.append({"ok": false, "code": &"invalid_localized_binding", "path": str(node.path), "line": 0})
			continue
		if not node.parameters is Dictionary:
			failures.append({"ok": false, "code": &"invalid_localized_binding", "path": str(node.path), "line": 0})
			continue
		var resolved := _resolve_scene_target(str(node.path), str(node.target))
		if not resolved.ok:
			failures.append({"ok": false, "code": &"invalid_localized_binding_target", "path": str(node.path), "line": 0})
			continue
		var location := "%s:%s" % [resolved.value, str(node.property)]
		if output.has(location):
			failures.append({"ok": false, "code": &"duplicate_localized_binding_target", "path": str(node.path), "line": 0})
			continue
		output[location] = {"key": str(node.key), "parameters": node.parameters.duplicate(true)}
	return {"value": output, "failures": failures}


static func _resolve_scene_target(node_path: String, target: String) -> Dictionary:
	var parts := Array(node_path.split("/", false))
	for part: String in target.split("/", false):
		if part == ".":
			continue
		if part == "..":
			if parts.is_empty():
				return {"ok": false, "code": &"invalid_localized_binding_target"}
			parts.pop_back()
		else:
			parts.append(part)
	if parts.is_empty():
		return {"ok": false, "code": &"invalid_localized_binding_target"}
	return {"ok": true, "value": "/".join(parts)}


static func _quoted_attribute(line: String, attribute: String) -> String:
	var marker := " %s=\"" % attribute
	var start := line.find(marker)
	if start < 0:
		return ""
	return line.substr(start + marker.length()).get_slice('"', 0)


static func scan_script_source(path: String, source: String) -> Dictionary:
	var records: Array = []
	var failures: Array = []
	var lines := source.split("\n")
	var index := 0
	var catalog_keys := _catalog_keys()
	while index < lines.size():
		var line: String = lines[index].trim_suffix("\r")
		var code := _strip_comment(line)
		var found := _script_sink(code, path)
		if found.is_empty():
			index += 1
			continue
		var collected := _collect_expression(lines, index, str(found.expression), bool(found.call))
		var expression := str(collected.expression)
		var disposition := _script_disposition(path, str(found.sink), expression, source)
		if disposition.disposition == "localized_call" and _requires_catalog_key(str(disposition.key)) \
				and not catalog_keys.has(disposition.key):
			disposition = _unclassified("literal translation key is absent from the English source catalog")
			failures.append(_failure(&"unknown_translation_key", path, index + 1, str(found.sink)))
		elif disposition.disposition == "unclassified":
			failures.append(_failure(&"unclassified_script_literal", path, index + 1, str(found.sink)))
		records.append(_record(path, index + 1, str(found.sink), expression, disposition, line))
		index = int(collected.end) + 1
	return _scan_result(records, failures)


static func _script_sink(line: String, path: String) -> Dictionary:
	for property in SCRIPT_PROPERTIES:
		var marker := ".%s =" % property
		var position := line.find(marker)
		if position >= 0:
			return {"sink": property, "expression": line.substr(position + marker.length()).strip_edges(), "call": false}
		var direct := line.strip_edges()
		var direct_marker := "%s =" % property
		if direct.begins_with(direct_marker):
			return {"sink": property, "expression": direct.substr(direct_marker.length()).strip_edges(), "call": false}
	for call_name in SCRIPT_CALLS:
		var marker := ".%s(" % call_name
		var position := line.find(marker)
		if position >= 0:
			return {"sink": call_name, "expression": line.substr(position + marker.length()).strip_edges(), "call": true}
	return {}


static func _strip_comment(line: String) -> String:
	var quote := ""
	var escaped := false
	for position in range(line.length()):
		var character := line.substr(position, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			continue
		if character == "#" and quote.is_empty():
			return line.left(position).strip_edges()
	return line


static func _source_contains_code_marker(source: String, marker: String) -> bool:
	var quote := ""
	var escaped := false
	var position := 0
	while position < source.length():
		if quote.is_empty() and source.substr(position, marker.length()) == marker:
			return true
		if quote.is_empty() and source.substr(position, 3) in ['"""', "'''"]:
			quote = source.substr(position, 3)
			position += 3
			continue
		if not quote.is_empty() and quote.length() == 3 and source.substr(position, 3) == quote:
			quote = ""
			position += 3
			continue
		var character := source.substr(position, 1)
		if quote.is_empty() and character == "#":
			var newline := source.find("\n", position + 1)
			if newline < 0:
				return false
			position = newline + 1
			continue
		if escaped:
			escaped = false
			position += 1
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			position += 1
			continue
		if quote.length() < 3 and character in ['"', "'"]:
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
		position += 1
	return false


static func _collect_expression(lines: PackedStringArray, start: int, first: String, is_call: bool) -> Dictionary:
	var expression := first
	var balance := (1 if is_call else 0) + _delimiter_delta(first)
	var end := start
	while end + 1 < lines.size() and (balance > 0 or lines[end].trim_suffix("\r").strip_edges().ends_with("\\")):
		end += 1
		var continuation: String = _strip_comment(lines[end].trim_suffix("\r")).strip_edges()
		expression += "\n" + continuation
		balance += _delimiter_delta(continuation)
	return {"expression": expression, "end": end}


static func _delimiter_delta(text: String) -> int:
	var delta := 0
	var quote := ""
	var escaped := false
	for position in range(text.length()):
		var character := text.substr(position, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty():
				quote = character
			elif quote == character:
				quote = ""
			continue
		if not quote.is_empty():
			continue
		if character in ["(", "[", "{"]:
			delta += 1
		elif character in [")", "]", "}"]:
			delta -= 1
	return delta


static func _script_disposition(path: String, sink: String, expression: String, source: String) -> Dictionary:
	var exact_key := "%s|%s|%s" % [path, sink, expression]
	if SCRIPT_LITERAL_OWNERS.has(exact_key):
		var owner: Dictionary = SCRIPT_LITERAL_OWNERS[exact_key]
		if owner.has("marker") and not _source_contains_code_marker(
				FileAccess.get_file_as_string(path), str(owner.marker)):
			return _unclassified("declared script literal localization seam is missing")
		return {"disposition": owner.disposition, "key": owner.key, "reason": owner.reason}
	var digest_key := "%s|%s|%s" % [path, sink, expression.sha256_text()]
	if SCRIPT_EXPRESSION_OWNERS.has(digest_key):
		var owner: Dictionary = SCRIPT_EXPRESSION_OWNERS[digest_key]
		if owner.get("group") == "scroll" and not _scroll_locale_group_is_complete(
				FileAccess.get_file_as_string(path)):
			return _unclassified("the exact scroll locale group is incomplete")
		if owner.get("group") == "chrome_rules" and not _chrome_rules_group_is_complete():
			return _unclassified("the exact Rules chrome locale group is incomplete")
		return {"disposition": "localized_call", "key": owner.key, "reason": owner.reason}
	if expression in ['"\\u25c6"', '"\\u2196"', '"◆"', '"↖"']:
		return {"disposition": "decorative", "key": "", "reason": "symbol-only control glyph"}
	if path == "res://scripts/ui/DatingScene.gd":
		var dating_copy := _dating_copy_disposition(expression, source)
		if not dating_copy.is_empty():
			return dating_copy
	if ".t(" in expression or "LocalizationManager" in expression:
		var translation_key := _literal_translation_key(expression)
		for literal: String in _string_literals(expression):
			if literal != translation_key and _is_stable_display_literal(literal) \
					and not _literal_is_structural(expression, literal):
				return _unclassified("a localized call does not own its sibling display literal")
		return {"disposition": "localized_call", "key": translation_key, "reason": "LocalizationManager lookup"}
	for marker: String in SCRIPT_LOCALIZATION_HELPERS.get(path, []):
		var removed := _remove_owned_helper_spans(expression, marker)
		if removed.found:
			var helper_key := _helper_translation_key(expression) if path in [
				"res://scripts/ui/GalleryScene.gd", "res://scripts/ui/SettingsContent.gd",
				"res://scripts/ui/SettingsControlsSheet.gd", "res://scripts/ui/SettingsPanelController.gd"] else "dynamic"
			for literal: String in _string_literals(removed.remainder):
				if literal != helper_key and _is_stable_display_literal(literal) \
						and not _literal_is_structural(removed.remainder, literal):
					return _unclassified("a component translation helper does not own its sibling display literal")
			return {"disposition": "localized_call", "key": helper_key,
				"reason": "path-specific component translation projection"}
	var stable_literals: Array[String] = []
	for literal: String in _string_literals(expression):
		if _is_stable_display_literal(literal) and not _literal_is_structural(expression, literal):
			stable_literals.append(literal)
	if stable_literals.is_empty():
		return {"disposition": "runtime_data", "key": "", "reason": "dynamic presenter value or punctuation-only formatting"}
	return _unclassified("stable script literal requires a demonstrated translation owner or specific disposition")


static func _dating_copy_disposition(expression: String, source: String) -> Dictionary:
	var owned := _remove_owned_helper_spans(expression, "_ui_text(")
	if not owned.found:
		return {}
	var helper := 'func _ui_text(english: String) -> String:\n\treturn str(DRAFT_UI_COPY.get(_locale.replace("_", "-"), {}).get(english, english))'
	if not _source_contains_code_marker(source, helper):
		return _unclassified("the Dating copy helper does not match its locale projection")
	var table: Dictionary = {}
	var lines := source.split("\n")
	var prefix := "const DRAFT_UI_COPY := "
	for index in range(lines.size()):
		if not lines[index].begins_with(prefix):
			continue
		var collected := _collect_expression(lines, index, lines[index].trim_prefix(prefix), false)
		if not _source_contains_code_marker(source, lines[index]):
			continue
		var decoded: Variant = JSON.parse_string(str(collected.expression))
		if decoded is Dictionary:
			table = decoded
		break
	for argument: String in owned.arguments:
		var english: Variant = JSON.parse_string(argument)
		if not english is String or str(english).strip_edges().is_empty():
			return _unclassified("Dating UI copy requires a registered literal source phrase")
		for locale: String in ["zh-CN", "zh-HK", "ja", "ko"]:
			var translated: Variant = table.get(locale, {}).get(english) if table.get(locale) is Dictionary else null
			if not translated is String or str(translated).strip_edges().is_empty() or translated == english:
				return _unclassified("Dating UI copy is missing a translated source phrase")
	for literal: String in _string_literals(owned.remainder):
		if _is_stable_display_literal(literal) and not _literal_is_structural(owned.remainder, literal):
			return _unclassified("Dating UI copy does not own its sibling display literal")
	return {"disposition": "localized_call", "key": "DatingScene.ui.inline",
		"reason": "literal English source phrase with four complete translations and the exact locale helper"}


static func _scroll_locale_group_is_complete(source: String) -> bool:
	for marker in ['accessibility_name = "垂直滚动" if vertical else "水平滚动"',
		'accessibility_name = "垂直捲動" if vertical else "水平捲動"',
		'accessibility_name = "Vertical scroll" if vertical else "Horizontal scroll"',
		'accessibility_description = "位置%d，共%d" % [value,maximum]',
		'accessibility_description = "Position %d of %d" % [value,maximum]']:
		if not _source_contains_code_marker(source, marker):
			return false
	return true


static func _chrome_rules_group_is_complete() -> bool:
	var source := FileAccess.get_file_as_string("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")
	for marker in ['"rules":"Rules"', '"rules":"规则"', '"rules":"規則"']:
		if not _source_contains_code_marker(source, marker):
			return false
	return true


static func _remove_owned_helper_spans(expression: String, marker: String) -> Dictionary:
	var remainder := expression
	var found := false
	var arguments: Array[String] = []
	var search_from := 0
	while search_from < remainder.length():
		var start := remainder.find(marker, search_from)
		if start < 0:
			break
		if _position_is_in_string(remainder, start) or (start > 0 and marker.substr(0, 1).is_valid_identifier() \
				and (remainder.substr(start - 1, 1) == "_" or remainder.substr(start - 1, 1).is_valid_identifier())):
			search_from = start + marker.length()
			continue
		var open_position := start + marker.length() - 1
		var close_position := _matching_delimiter(remainder, open_position)
		if close_position < 0:
			break
		arguments.append(remainder.substr(open_position + 1, close_position - open_position - 1).strip_edges())
		remainder = remainder.left(start) + " ".repeat(close_position - start + 1) + remainder.substr(close_position + 1)
		found = true
		search_from = start + 1
	return {"found": found, "remainder": remainder, "arguments": arguments}


static func _matching_delimiter(text: String, open_position: int) -> int:
	var opener := text.substr(open_position, 1)
	var closer := ")" if opener == "(" else "]"
	var depth := 0
	var quote := ""
	var escaped := false
	for position in range(open_position, text.length()):
		var character := text.substr(position, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty(): quote = character
			elif quote == character: quote = ""
			continue
		if not quote.is_empty(): continue
		if character == opener: depth += 1
		elif character == closer:
			depth -= 1
			if depth == 0: return position
	return -1


static func _position_is_in_string(text: String, stop: int) -> bool:
	var quote := ""
	var escaped := false
	for position in range(stop):
		var character := text.substr(position, 1)
		if escaped:
			escaped = false
			continue
		if character == "\\" and not quote.is_empty():
			escaped = true
			continue
		if character in ['"', "'"]:
			if quote.is_empty(): quote = character
			elif quote == character: quote = ""
	return not quote.is_empty()


static func _requires_catalog_key(key: String) -> bool:
	return key not in ["", "dynamic"] and not key.ends_with(".inline")


static func _helper_translation_key(expression: String) -> String:
	for marker in ["_t(\"", "_text(\"", "_localized(\"", "text(\""]:
		var start := expression.find(marker)
		if start >= 0:
			var key := expression.substr(start + marker.length()).get_slice('"', 0)
			return "dynamic" if "%" in key or key.ends_with(".") else key
	return "dynamic"


static func _literal_translation_key(expression: String) -> String:
	var marker := ".t(\""
	var start := expression.find(marker)
	if start < 0:
		return "dynamic"
	var key := expression.substr(start + marker.length()).get_slice('"', 0)
	return "dynamic" if "%" in key or key.ends_with(".") else key


static func _string_literals(expression: String) -> Array[String]:
	var output: Array[String] = []
	var quote := ""
	var value := ""
	var escaped := false
	for position in range(expression.length()):
		var character := expression.substr(position, 1)
		if quote.is_empty():
			if character in ['"', "'"]:
				quote = character
				value = ""
			continue
		if escaped:
			value += "\\" + character
			escaped = false
			continue
		if character == "\\":
			escaped = true
			continue
		if character == quote:
			output.append(value)
			quote = ""
			continue
		value += character
	return output


static func _is_stable_display_literal(value: String) -> bool:
	var stripped := value.strip_edges()
	if stripped.is_empty():
		return false
	var without_formats := stripped.replace("%02d", "").replace("%s", "").replace("%d", "") \
		.replace("\\n", "").replace("\\r", "").replace("\\t", "")
	var has_letter := false
	for position in range(without_formats.length()):
		var code := without_formats.unicode_at(position)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code >= 0x3400:
			has_letter = true
			break
	if not has_letter:
		return false
	return true


static func _literal_is_structural(expression: String, literal: String) -> bool:
	var found := false
	for quote in ['"', "'"]:
		var token: String = quote + literal + quote
		var start := expression.find(token)
		while start >= 0:
			found = true
			var before := expression.left(start).strip_edges()
			var after := expression.substr(start + token.length()).strip_edges()
			var postfix_index := before.ends_with("[") and after.begins_with("]") \
				and _bracket_has_postfix_owner(before)
			if not (after.begins_with(":") or postfix_index \
					or before.ends_with("==") or before.ends_with("!=") \
					or before.ends_with(".get(") or before.ends_with("get_meta(") \
					or before.ends_with("get_node(") \
					or before.ends_with("has_meta(")):
				return false
			start = expression.find(token, start + token.length())
	return found


static func _bracket_has_postfix_owner(before: String) -> bool:
	var bracket := before.length() - 1
	if bracket < 0 or before.substr(bracket, 1) != "[":
		return false
	var position := bracket - 1
	while position >= 0 and before.substr(position, 1) in [" ", "\t", "\r", "\n"]:
		position -= 1
	if position < 0:
		return false
	var owner_end := before.substr(position, 1)
	var code := owner_end.unicode_at(0)
	var identifier_end := owner_end == "_" or (code >= 48 and code <= 57) \
		or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code >= 0x80
	return identifier_end or owner_end in ["]", ")", "}", "'", '"']


static func _scan_result(records: Array, failures: Array) -> Dictionary:
	if failures.is_empty():
		return {"ok": true, "value": records, "failures": []}
	var first: Dictionary = failures[0]
	var result := {"ok": false, "value": records, "failures": failures,
		"code": first.get("code", &"audit_failed"), "path": first.get("path", ""),
		"line": first.get("line", 0)}
	if first.has("sink"):
		result.sink = first.sink
	return result


static func _scene_node_path(header: String) -> String:
	var name := header.get_slice('"', 1)
	var parent := ""
	if header.contains(" parent=\""):
		parent = header.get_slice(" parent=\"", 1).get_slice('"', 0)
	if parent.is_empty() or parent == ".":
		return name
	return "%s/%s" % [parent, name]


static func _catalog_keys() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EN_CATALOG))
	var output := {}
	if not parsed is Dictionary or not parsed.get("messages") is Array:
		return output
	for message: Variant in parsed.messages:
		if message is Dictionary and not str(message.get("id", "")).is_empty():
			output[str(message.id)] = true
	return output


static func _binding_parameters_match(key: String, parameters: Dictionary) -> bool:
	var expected: Array[String] = []
	var found_source := false
	for catalog_path in CATALOGS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
		if not parsed is Dictionary or not parsed.get("messages") is Array:
			return false
		for message: Variant in parsed.messages:
			if not message is Dictionary or str(message.get("id", "")) != key:
				continue
			var placeholders := _placeholders(str(message.get("text", "")))
			if not found_source:
				expected = placeholders
				found_source = true
			elif placeholders != expected:
				return false
			break
	var supplied: Array[String] = []
	for parameter: Variant in parameters.keys():
		supplied.append(str(parameter))
	supplied.sort()
	return found_source and supplied == expected


static func _placeholders(text: String) -> Array[String]:
	var output: Array[String] = []
	var start := text.find("{")
	while start >= 0:
		var finish := text.find("}", start + 1)
		if finish < 0:
			break
		var name := text.substr(start + 1, finish - start - 1)
		if not name.is_empty() and name not in output:
			output.append(name)
		start = text.find("{", finish + 1)
	output.sort()
	return output


static func _unclassified(reason: String) -> Dictionary:
	return {"disposition": "unclassified", "key": "", "reason": reason}


static func _record(path: String, line_number: int, sink: String, expression: String,
		disposition: Dictionary, line_text: String) -> Dictionary:
	return {
		"source_path": path.trim_prefix("res://"),
		"line": line_number,
		"line_sha256": line_text.sha256_text(),
		"sink": sink,
		"source_expression": expression,
		"disposition": disposition.disposition,
		"key": disposition.key,
		"reason": disposition.reason,
	}


static func _validate_and_write(path: String, records: Array, failures: Array, source_paths: Array) -> Dictionary:
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return [a.source_path, a.line, a.sink] < [b.source_path, b.line, b.sink])
	var seen := {}
	for record: Dictionary in records:
		var id := "%s:%d:%s" % [record.source_path, record.line, record.sink]
		if seen.has(id):
			return _failure(&"duplicate_literal_location", record.source_path, record.line)
		seen[id] = true
		if record.disposition not in VALID_DISPOSITIONS:
			return _failure(&"invalid_disposition", record.source_path, record.line)
	var inventory := validate_source_inventory(source_paths, _source_presence(source_paths))
	if not inventory.ok:
		return inventory
	var encoded := WRITER.stringify({"schema_version": 1, "records": records, "failures": failures,
		"source_paths": inventory.source_paths, "source_count": inventory.source_count})
	if not encoded.get("ok", false):
		return encoded
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure(&"evidence_write_failed", path, 0)
	file.store_string(encoded.value)
	file.flush()
	return {"ok": true}


static func inventory_below(root: String, suffix: String) -> Dictionary:
	var output: Array = []
	var failures: Array = []
	var directory := DirAccess.open(root)
	if directory == null:
		return {"ok": false, "code": &"source_root_missing", "source_paths": [], "source_count": 0,
			"failures": [_failure(&"source_root_missing", root, 0)]}
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if directory.current_is_dir():
			var child := inventory_below("%s/%s" % [root, name], suffix)
			output.append_array(child.source_paths)
			failures.append_array(child.failures)
		elif name.ends_with(suffix):
			output.append("%s/%s" % [root, name])
		name = directory.get_next()
	directory.list_dir_end()
	output.sort()
	return {"ok": failures.is_empty(), "code": &"ok" if failures.is_empty() else failures[0].code,
		"source_paths": output, "source_count": output.size(), "failures": failures}


static func validate_source_inventory(expected_paths: Array, supplied: Dictionary) -> Dictionary:
	var source_paths: Array = []
	var seen := {}
	var failures: Array = []
	for value: Variant in expected_paths:
		var path := str(value)
		if seen.has(path):
			failures.append(_failure(&"source_inventory_mismatch", path, 0))
			continue
		seen[path] = true
		source_paths.append(path)
	source_paths.sort()
	for supplied_path: Variant in supplied.keys():
		if not seen.has(str(supplied_path)):
			failures.append(_failure(&"source_inventory_mismatch", str(supplied_path), 0))
	for path: String in source_paths:
		if not supplied.has(path) or supplied[path] == null or typeof(supplied[path]) != TYPE_STRING:
			failures.append(_failure(&"source_read_failed", path, 0))
	var code: StringName = &"ok" if failures.is_empty() else failures[0].code
	return {"ok": failures.is_empty(), "code": code, "source_paths": source_paths,
		"source_count": source_paths.size(), "failures": failures}


static func _source_presence(source_paths: Array) -> Dictionary:
	var supplied := {}
	for path: String in source_paths:
		supplied[path] = "present"
	return supplied


static func _read_source(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure(&"source_read_failed", path, 0)
	var value := file.get_as_text()
	file.close()
	return {"ok": true, "value": value}


static func _failure(code: StringName, path: String, line_number: int, sink: String = "") -> Dictionary:
	var result := {"ok": false, "code": code, "path": path, "line": line_number}
	if not sink.is_empty():
		result.sink = sink
	return result


func _fail(result: Dictionary) -> void:
	push_error("UiLiteralAudit: %s" % JSON.stringify(result))
	quit(1)
