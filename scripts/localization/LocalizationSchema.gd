class_name LocalizationSchema
extends RefCounted

static func validate_manifest(manifest: Dictionary, base_path: String) -> Dictionary:
	if not _exact_keys(manifest, ["schema_version", "source_locale", "aliases", "font_profiles", "locales"]): return _fail("invalid_manifest_keys")
	if manifest["schema_version"] != 1 or typeof(manifest["source_locale"]) != TYPE_STRING: return _fail("invalid_manifest_header")
	var locale_ids := {}
	var records := {}
	var source_count := 0
	for record_value in manifest["locales"]:
		if typeof(record_value) != TYPE_DICTIONARY: return _fail("invalid_locale_record")
		var record: Dictionary = record_value
		if not _exact_keys(record, ["id", "native_name", "fallback_locale", "release_status", "selectable", "ui_file", "font_profile", "layout_direction"]): return _fail("invalid_locale_record")
		var id: String = record["id"]
		if id.is_empty() or locale_ids.has(id): return _fail("duplicate_locale_id")
		if not _safe_relative(record["ui_file"]): return _fail("invalid_locale_path")
		if record["layout_direction"] not in ["ltr", "rtl"] or record["release_status"] not in ["source", "draft", "released"]: return _fail("invalid_locale_record")
		locale_ids[id] = true; records[id] = record.duplicate(true)
		if record["release_status"] == "source": source_count += 1
	if source_count != 1 or not records.has(manifest["source_locale"]) or records[manifest["source_locale"]]["release_status"] != "source" or records[manifest["source_locale"]]["fallback_locale"] != null: return _fail("invalid_source_locale")
	var aliases := {}
	for alias_value in manifest["aliases"]:
		if typeof(alias_value) != TYPE_DICTIONARY or not _exact_keys(alias_value, ["input", "locale"]): return _fail("invalid_alias")
		if aliases.has(alias_value["input"]) or not locale_ids.has(alias_value["locale"]): return _fail("duplicate_or_unknown_alias")
		aliases[alias_value["input"]] = alias_value["locale"]
	var fonts := {}
	for font_value in manifest["font_profiles"]:
		if typeof(font_value) != TYPE_DICTIONARY or not _exact_keys(font_value, ["id", "font_files", "fallback_profile"]): return _fail("invalid_font_profile")
		if fonts.has(font_value["id"]): return _fail("duplicate_font_profile")
		for path in font_value["font_files"]:
			if not _safe_relative(path): return _fail("invalid_font_path")
		fonts[font_value["id"]] = font_value.duplicate(true)
	for id in records:
		if not fonts.has(records[id]["font_profile"]): return _fail("unknown_font_profile")
		if not _chain_terminates(id, records, "fallback_locale", manifest["source_locale"]): return _fail("locale_fallback_cycle")
	for id in fonts:
		if not _nullable_chain_terminates(id, fonts, "fallback_profile"): return _fail("font_fallback_cycle")
	return {"ok": true, "value": manifest.duplicate(true), "base_path": base_path}

static func validate_locale_file(catalog: Dictionary, expected_locale: String) -> Dictionary:
	if not _exact_keys(catalog, ["schema_version", "locale", "messages"]) or catalog.get("schema_version") != 1 or catalog.get("locale") != expected_locale: return _fail("invalid_locale_file")
	var ids := {}
	for message_value in catalog["messages"]:
		if typeof(message_value) != TYPE_DICTIONARY or not _exact_keys(message_value, ["id", "text"]): return _fail("invalid_message")
		if typeof(message_value["id"]) != TYPE_STRING or message_value["id"].is_empty() or ids.has(message_value["id"]) or typeof(message_value["text"]) != TYPE_STRING: return _fail("duplicate_or_invalid_message")
		ids[message_value["id"]] = true
	return {"ok": true, "value": catalog.duplicate(true)}

static func extract_named_placeholders(text: String) -> PackedStringArray:
	var output := PackedStringArray(); var seen := {}; var regex := RegEx.new(); regex.compile("\\{([A-Za-z_][A-Za-z0-9_]*)\\}")
	for match in regex.search_all(text):
		var key := match.get_string(1)
		if not seen.has(key): seen[key] = true; output.append(key)
	output.sort(); return output

static func validate_bundle(manifest: Dictionary, catalogs: Dictionary) -> Dictionary:
	var manifest_result := validate_manifest(manifest, "res://localization/")
	if not manifest_result.get("ok", false): return manifest_result
	var source_id: String = manifest["source_locale"]
	if not catalogs.has(source_id): return _fail("missing_source_catalog")
	var source_messages := _message_map(catalogs[source_id])
	for record in manifest["locales"]:
		var id: String = record["id"]
		if not catalogs.has(id): return _fail("missing_locale_catalog")
		var valid := validate_locale_file(catalogs[id], id)
		if not valid.get("ok", false): return valid
		for message_id in _message_map(catalogs[id]):
			if not source_messages.has(message_id) or extract_named_placeholders(_message_map(catalogs[id])[message_id]) != extract_named_placeholders(source_messages[message_id]): return _fail("placeholder_mismatch")
	return {"ok": true, "value": {"manifest": manifest.duplicate(true), "catalogs": catalogs.duplicate(true)}}

static func build_legacy_subset_records(tables: Dictionary) -> Dictionary:
	var records: Array[Dictionary] = []
	for locale in tables:
		for id in tables[locale]: records.append({"locale": locale, "id": id, "text": tables[locale][id]})
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return [a["locale"], a["id"]] < [b["locale"], b["id"]])
	return {"ok": true, "value": records.duplicate(true)}

static func fingerprint_records(records: Array[Dictionary]) -> String:
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256)
	for record in records:
		for field in [record["locale"], record["id"], record["text"]]: context.update((field as String).to_utf8_buffer()); context.update(PackedByteArray([0]))
	return context.finish().hex_encode()

static func _message_map(catalog: Dictionary) -> Dictionary:
	var output := {}; for message in catalog.get("messages", []): output[message["id"]] = message["text"]
	return output
static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true
static func _safe_relative(path: Variant) -> bool:
	if typeof(path) != TYPE_STRING or path.is_empty() or path.is_absolute_path() or ":" in path or "\\" in path: return false
	var parts: PackedStringArray = (path as String).split("/", true)
	return "" not in parts and "." not in parts and ".." not in parts and (path as String).simplify_path() == path
static func _chain_terminates(start: String, records: Dictionary, key: String, expected: String) -> bool:
	var seen := {}; var cursor: Variant = start
	while cursor != null:
		if seen.has(cursor) or not records.has(cursor): return false
		seen[cursor] = true
		if cursor == expected: return records[cursor][key] == null
		cursor = records[cursor][key]
	return false
static func _nullable_chain_terminates(start: String, records: Dictionary, key: String) -> bool:
	var seen := {}; var cursor: Variant = start
	while cursor != null:
		if seen.has(cursor) or not records.has(cursor): return false
		seen[cursor] = true; cursor = records[cursor][key]
	return true
static func _fail(code: StringName) -> Dictionary: return {"ok": false, "code": code, "message": String(code)}
