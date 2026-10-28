extends "res://tests/integration/scene_computer_child.gd"
## Separate-process acceptance: current Profile languages present an older slot.
const STORY := preload("res://scripts/localization/StoryLocalization.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")

class UnavailableSpeechDisplay extends RefCounted:
	func has_feature(_feature: int) -> bool: return false
	func tts_get_voices() -> Array: return []
	func tts_set_utterance_callback(_event: int, _callback: Callable) -> void: pass
	func tts_speak(_text: String, _voice: String, _volume: int, _pitch: float,
			_rate: float, _id: int, _interrupt: bool) -> void: pass
	func tts_stop() -> void: pass

func _install_content_registration() -> Dictionary:
	return MANIFEST.scene_registration()

func test_bilingual_preferences_and_pair_survive_fresh_process_load() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://bilingual-restart-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_eq(ProjectSettings.globalize_path("user://"), proof.user_dir)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	get_node("/root/SystemTtsCoordinator")._port._display = UnavailableSpeechDisplay.new()
	if not _start_services(): return
	assert_eq(profile.get_preference(&"preferences.language.primary_locale_id", ""), "ja")
	assert_eq(profile.get_preference(&"preferences.language.secondary_locale_id", ""), "en")
	assert_true(profile.get_preference(&"preferences.language.dual_enabled", false))
	assert_eq(profile.get_profile_snapshot().witnessed_caption_variants, proof.witnesses)
	assert_eq(profile.get_dialogue_library(), proof.library)
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	for frame: int in 6: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.003")
	var caption: Node = _caption()
	assert_not_null(caption)
	if caption == null: return
	assert_eq(caption.caption_text.get_parsed_text(), STORY.catalog("ja")["line.Day1.003"])
	assert_eq(caption.secondary_caption.get_parsed_text(), STORY.catalog("en")["line.Day1.003"])
	assert_true(caption.secondary_caption.visible)
	assert_eq(caption.secondary_caption.language, "en")
	assert_eq(caption.caption_text.visible_ratio, 1.0)
	assert_eq(caption.secondary_caption.visible_ratio, 1.0)
	assert_eq(profile.get_preference(&"preferences.language.primary_locale_id", ""), "ja")
	assert_eq(profile.get_preference(&"preferences.language.secondary_locale_id", ""), "en")
	assert_true(profile.get_preference(&"preferences.language.dual_enabled", false))
	assert_eq(game.capture_run_snapshot_input().command_receipts, proof.command_receipts, "Load executes no entry commands")
	assert_eq(profile.get_profile_snapshot().witnessed_caption_variants, proof.witnesses)
	assert_eq(profile.get_dialogue_library(), proof.library, "restored text adds no discovery")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	await _screenshot("bilingual-fresh-process-load")
	proof["loader_process_id"] = OS.get_process_id()
	_write_json("res://.godot/ci/bilingual-restart-proof.json", proof)
