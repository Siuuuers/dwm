class_name LocalizationCatalog
extends RefCounted

const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SCHEMA := preload("res://scripts/localization/LocalizationSchema.gd")

static func load_bundle(manifest_path: String) -> Dictionary:
	var manifest_read := _read_object(manifest_path)
	if not manifest_read.get("ok", false): return manifest_read
	var manifest: Dictionary = manifest_read["value"]
	var base_path := manifest_path.get_base_dir() + "/"
	var manifest_validation := SCHEMA.validate_manifest(manifest, base_path)
	if not manifest_validation.get("ok", false): return manifest_validation
	var catalogs := {}
	for record in manifest["locales"]:
		var catalog_read := _read_object(base_path + String(record["ui_file"]))
		if not catalog_read.get("ok", false): return catalog_read
		catalogs[record["id"]] = catalog_read["value"]
	var bundle_validation := SCHEMA.validate_bundle(manifest, catalogs)
	if not bundle_validation.get("ok", false): return bundle_validation
	return {"ok": true, "value": {"manifest": manifest.duplicate(true), "catalogs": catalogs.duplicate(true)}}

static func _read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "code": &"localization_file_missing", "message": path}
	return STRICT.parse_object(FileAccess.get_file_as_string(path))
