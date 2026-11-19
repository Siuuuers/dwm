extends "res://tests/support/ScenePlayableFixture.gd"
## Install once through the real immutable registration owner, before FINAL startup.
func _install_registration() -> Dictionary:
	var built: Dictionary = _registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	bundle.schema_version = 3
	var bindings: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		bindings.append({"entry_id": entry.entry_id,
			"plan_id": "TEST.audio.01" if entry.entry_id == BASE_READING.B else null})
	bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle["audio_catalogue"] = {"kind": "scene_audio_catalogue", "schema_version": 1,
		"assets": [{"asset_id": "TEST.audio.asset.01", "path": "res://audio/bgm/story_theme.nsf",
			"sha256": "cd59503c221ec4e5b7949008642aabd6f4a3f5df748452e2564e80909903eac8", "duration_ms": 0}],
		"plans": [{"plan_id": "TEST.audio.01", "revision": 1, "variant_id": "base",
			"ambience_asset_id": "TEST.audio.asset.01", "entrance_ms": 0,
			"load_anchor_id": "load.01", "load_anchor_ms": 1000,
			"authorial": true, "essential": false, "missing_media": "silence", "music": null, "cues": []}],
		"bindings": bindings}
	return BASE_READING.MANIFEST.configure_test_scene_registration(bundle)
