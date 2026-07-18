extends SceneTree
## Required by prompt_docs/requirements/verification.md.
## Loads and instantiates every required scene. No input, no auto-routing.
## Exit 0 if all required scenes load and instantiate; exit 1 if any fail.

const REQUIRED_SCENE_PATHS := [
	"res://scenes/menu/MenuScene.tscn",
	"res://scenes/menu/GalleryScene.tscn",
	"res://scenes/menu/Setting.tscn",
	"res://scenes/opening/OpeningScene.tscn",
	"res://scenes/main/MainGameScene.tscn",
	"res://scenes/desktop/ComputerDesktop.tscn",
	"res://scenes/apps/MinesweeperApp.tscn",
	"res://scenes/apps/ContactListApp.tscn",
	"res://scenes/apps/ShopApp.tscn",
	"res://scenes/apps/ScheduleApp.tscn",
	"res://scenes/apps/SettingsApp.tscn",
	"res://scenes/apps/LogOutApp.tscn",
	"res://scenes/apps/BackupApp.tscn",
	"res://scenes/overlay/TutorialOverlay.tscn",
	"res://scenes/ending/EndingScene.tscn",
	"res://scenes/hospital/HospitalScene.tscn",
	"res://scenes/dating/DatingScene.tscn",
	"res://scenes/dating/MinesweeperChallengeOverlay.tscn",
	"res://scenes/shared/BoxMeter.tscn",
	"res://scenes/shared/StatHud.tscn",
	"res://scenes/shared/AppWindowBase.tscn",
	"res://scenes/shared/IconButton.tscn",
	"res://scenes/shared/ContactBox.tscn",
	"res://scenes/shared/ChatBubble.tscn",
	"res://scenes/shared/ShopItemBox.tscn",
	"res://scenes/shared/ScheduleEntryBox.tscn",
	"res://scenes/shared/SaveSlotRow.tscn",
	"res://scenes/shared/DialogueBox.tscn",
]

func _init() -> void:
	var failures: Array[String] = []
	for path in REQUIRED_SCENE_PATHS:
		var packed := load(path)
		if packed == null or not (packed is PackedScene):
			print("LOAD_FAIL: ", path)
			failures.append(path)
			continue
		var instance := (packed as PackedScene).instantiate()
		if instance == null:
			print("INSTANTIATE_FAIL: ", path)
			failures.append(path)
			continue
		print("OK: ", path)
		instance.free()

	if failures.is_empty():
		print("SMOKE_LOAD_SCENES: PASS (%d/%d)" % [REQUIRED_SCENE_PATHS.size(), REQUIRED_SCENE_PATHS.size()])
		quit(0)
	else:
		print("SMOKE_LOAD_SCENES: FAIL (%d failed of %d)" % [failures.size(), REQUIRED_SCENE_PATHS.size()])
		for f in failures:
			print("  - ", f)
		quit(1)
