extends SceneTree

const MANAGER_PATH := "res://autoload/LocalizationManager.gd"
const SCHEMA := preload("res://scripts/localization/LocalizationSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _init() -> void:
	var manager_script: Script = load(MANAGER_PATH)
	var manager: Node = manager_script.new()
	manager.call(&"_build_tables")
	var tables: Dictionary = (manager.get("_tables") as Dictionary).duplicate(true)
	manager.free()
	if tables.get("en", {}).size() != 50 or tables.get("zh_CN", {}).size() != 25 or tables.get("zh_HK", {}).size() != 25:
		_fail("legacy table counts differ from 50/25/25")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://localization/ui"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/phase_2r/localization"))
	for locale in ["en", "zh_CN", "zh_HK"]:
		var messages: Array[Dictionary] = []
		var ids: Array = tables[locale].keys(); ids.sort()
		for id in ids: messages.append({"id": id, "text": tables[locale][id]})
		if not _write_canonical("res://localization/ui/%s.json" % locale, {"locale": locale, "messages": messages, "schema_version": 1}): return
	var records_result := SCHEMA.build_legacy_subset_records(tables)
	var by_locale := {}
	for locale in ["en", "zh_CN", "zh_HK"]:
		var entries: Array[Dictionary] = []
		for record in records_result["value"]:
			if record["locale"] == locale: entries.append({"id": record["id"], "text": record["text"]})
		by_locale[locale] = entries
	var evidence := {"combined_sha256": SCHEMA.fingerprint_records(records_result["value"]), "counts": {"en": 50, "zh_CN": 25, "zh_HK": 25}, "oracle_path": MANAGER_PATH, "oracle_sha256": FileAccess.get_sha256(MANAGER_PATH), "records": by_locale, "schema_version": 1}
	var evidence_path := "res://evidence/phase_2r/localization/legacy_subset_fingerprint.json"
	if FileAccess.file_exists(evidence_path):
		var existing := FileAccess.get_file_as_string(evidence_path)
		var emitted: Dictionary = WRITER.stringify(evidence)
		if not emitted.get("ok", false) or existing != emitted["value"]: _fail("existing immutable fingerprint differs"); return
	else:
		if not _write_canonical(evidence_path, evidence): return
	quit(0)

func _write_canonical(path: String, value: Dictionary) -> bool:
	var emitted: Dictionary = WRITER.stringify(value)
	if not emitted.get("ok", false): _fail(str(emitted)); return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: _fail("cannot write " + path); return false
	file.store_string(emitted["value"]); file.close(); return true

func _fail(message: String) -> void:
	push_error("ExtractLegacyLocalization: " + message)
	quit(1)
