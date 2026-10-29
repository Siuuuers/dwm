extends SceneTree
const RAIL := preload("res://scripts/ui/witnessed/WitnessedTransportRail.gd")
const THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
var viewport: SubViewport
var rail: Control
var records: Array = []
var activations := 0
var folder := "res://.godot/ci/interaction/rail-states"

func _initialize() -> void: _run.call_deferred()
func _admit() -> bool: return true
func _activated() -> void: activations += 1
func _settle() -> void:
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
	var profile := PROFILE.new()
	assert(profile.initialize(STORAGE.new("rail-states", FILES.new())).ok)
	var locale := LOCALIZATION.new()
	assert(locale.initialize(profile).ok)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.global_canvas_transform = Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2.ZERO)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	root.add_child(viewport)
	var manager := INPUT.new()
	viewport.add_child(manager)
	rail = RAIL.new()
	viewport.add_child(rail)
	assert(rail.bind_localization(locale))
	assert(rail.bind_history_admission(_admit, manager))
	rail.history_requested.connect(_activated)
	for palette: String in ["AfterHours", "Midnight"]:
		for style: String in ["pixel", "readable"]:
			for percent: int in [125, 150]:
				assert(rail.configure_presentation(THEME.build("en", percent, palette, false, "standard", false, 1, false, style), "en", percent, style))
				var id := "%s-%s-%d" % [palette, style, percent]
				assert(rail.project(false, false, true))
				await _capture(id + "-disabled-after")
				for button: Button in rail.get_children():
					var disabled := button.get_theme_stylebox("disabled") as StyleBoxFlat
					disabled.set_border_width_all(4)
				await _capture(id + "-disabled-before")
				assert(rail.project(true, false, true, true, true, true, true, true, true))
				await _settle()
				var history: Button = rail.get_node("History")
				var point := viewport.global_canvas_transform * history.get_global_rect().get_center()
				var motion := InputEventMouseMotion.new()
				motion.position = point
				viewport.push_input(motion, true)
				var press := InputEventMouseButton.new()
				press.button_index = MOUSE_BUTTON_LEFT
				press.position = point
				press.pressed = true
				viewport.push_input(press, true)
				await _capture(id + "-physical-held")
				assert(not history._candidate.is_empty(), "held physical contact admitted")
				var before := activations
				press.pressed = false
				viewport.push_input(press, true)
				await _settle()
				assert(activations == before + 1, "one physical release activates exactly once")
				await _capture(id + "-released-focus")
	var report := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"records": records, "activations": activations,
		"baseline": "Before reconstructs the original disabled material by restoring all four border widths to four; every other property uses current production."}, "\t"))
	report.close()
	viewport.free()
	locale.free()
	profile.free()
	print("RAIL_STATES_COMPLETED ", records.size(), " captures; activations=", activations)
	quit()

func _capture(id: String) -> void:
	await _settle()
	var history: Button = rail.get_node("History")
	var image := viewport.get_texture().get_image()
	assert(image.save_png(folder.path_join(id + ".png")) == OK)
	records.append({"id": id, "draw_mode": history.get_draw_mode(), "focused": history.has_focus(),
		"disabled": history.disabled, "candidate": not history._candidate.is_empty()})
