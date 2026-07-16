class_name ArtManifest
extends RefCounted
# Stub skeleton. Required API from prompt_docs/09_ART_MANIFEST_SAFE_IMAGES.md.
# Provides expected art paths / sizes; never crashes on missing art.

static func get_expected_art_paths() -> Dictionary: return {}
static func get_path(category: String, id: String) -> String: return ""
static func get_expected_size(path: String) -> Vector2i: return Vector2i.ZERO
static func get_daily_main_scene_paths(day: int) -> Dictionary: return {}
static func get_missing_art_report() -> Dictionary: return {}
static func set_overlay_info(category: String, asset_id: String, path: String, expected_size: Vector2i, status: String) -> void: pass
