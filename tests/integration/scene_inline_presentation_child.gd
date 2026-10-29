extends "res://tests/integration/scene_inline_audio_child.gd"
## Shared real-runtime fixture for same-process and fresh-process art restoration.
const ART := preload("res://scripts/data/ArtManifest.gd")

class CountingFiles extends "res://scripts/infrastructure/storage/FileOps.gd":
	var autosave_writes := 0
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if path.replace("\\", "/").ends_with("/autosave.json.next"): autosave_writes += 1
		return super.write_bytes(path, bytes)

func _inline_path() -> String:
	return "res://tests/fixtures/dialogic/scene_inline_presentation.dtl"

func _inline_bundle() -> Dictionary:
	if not ART.reload_placements("res://tests/fixtures/presentation/named_checkpoints.json"):
		return {"ok": false}
	return super._inline_bundle()

func _advance_to(line: String) -> bool:
	if _caption().caption_text.revealing: await _accept()
	await _accept()
	for frame: int in 240:
		if bridge._runtime_adapter.current_line_id() == line:
			for settle: int in 3: await get_tree().process_frame
			return true
		await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), line)
	return false

func _assert_art(background: String, slots: Array) -> void:
	var state: Dictionary = game.capture_run_snapshot_input().scene.presentation
	assert_eq(state.background, background)
	var actual: Array = []
	for overlay: Dictionary in state.overlays: actual.append(overlay.slot)
	assert_eq(actual, slots)
	var mounted := false
	for view: Node in get_tree().root.find_children("SceneArt", "", true, false):
		if view.get_script() == preload("res://scripts/ui/art/SceneArtView.gd") and view.is_visible_in_tree():
			mounted = true
			assert_eq(view._overlays.get_child_count(), slots.size())
	assert_true(mounted, "inline composition is mounted on the visible native caption")

