extends "res://tests/integration/test_witnessed_caption_runtime.gd"
## Run only the two test_continue_registered_* cases in a rendered official Windows
## process with --accessibility always. Inherits the real isolated Dialogic fixture.
## Observes callables supplied by the real native notification, not fresh captures.

class ContinuePublicationProbe extends "res://scripts/ui/witnessed/WitnessedAccessibleContinue.gd":
	var publications: Array[Dictionary] = []
	func capture_continue_action() -> Callable:
		var action := super.capture_continue_action()
		publications.append({"action": action,
			"reveal": _accept_input._caption.get_reveal_generation(),
			"custody": _accept_input._accessibility_generation,
			"target": _accept_input._focus_caption().get_instance_id()})
		return action

func _mount_continue_publication_probe() -> Control:
	assert_ne(DisplayServer.get_name(), "headless", "this test requires native accessibility registration")
	if DisplayServer.get_name() == "headless": return null
	# Isolated tests skip application startup; use the real display owners with
	# in-memory storage, as in the inherited font/style fixture.
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	var storage: RefCounted = preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"continue-publication-fixture", preload("res://tests/support/FakeFileOps.gd").new())
	_replace_caption_display_source("ProfileManager", profile)
	var profile_result: Dictionary = profile.initialize(storage)
	assert_true(profile_result.get("ok", false), "isolated Continue profile initializes")
	if not profile_result.get("ok", false): return null
	var localization: Node = preload("res://autoload/LocalizationManager.gd").new()
	_replace_caption_display_source("LocalizationManager", localization)
	var localization_result: Dictionary = localization.initialize(profile)
	assert_true(localization_result.get("ok", false), "isolated Continue localization initializes")
	if not localization_result.get("ok", false): return null
	assert_eq(localization.get_readiness(), &"ready")
	assert_true(localization.has_key("button.continue"))
	if not await _mount_root_accept_fixture("Current.\nFollowing."): return null
	var surface: Control = caption.background_input
	surface.set_script(ContinuePublicationProbe)
	surface.bind_accessible_continue(caption.accept_input, get_node("/root/LocalizationManager"))
	surface.set_process(true)
	assert_eq(surface._label, localization.t("button.continue"))
	assert_true(surface._source_visible, "mounted Continue source is admitted")
	assert_true(surface._available, "mounted Continue action is admitted")
	return surface

func _await_publication(surface: Control, reveal: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		for publication: Dictionary in surface.publications:
			if publication.reveal == reveal: return publication
		await get_tree().create_timer(0.01).timeout
	assert_true(false, "Continue did not register a native action for reveal %d" % reveal)
	return {}

func _check_registered_completion(organic: bool) -> void:
	var surface: Control = await _mount_continue_publication_probe()
	if surface == null: return
	var reveal_before: int = caption.caption_text.get_reveal_generation()
	var before := await _await_publication(surface, reveal_before)
	if before.is_empty(): return
	var unchanged := {"label": surface._label, "available": surface._available,
		"visible": surface._source_visible, "focus": get_viewport().gui_get_focus_owner(),
		"target": caption.accept_input._focus_caption().get_instance_id(),
		"surface_id": surface.get_instance_id(), "surface_rect": surface.get_global_rect(),
		"caption_rect": caption.caption_text.get_global_rect()}
	assert_true(caption.caption_text.revealing)
	if organic:
		# Resume the real typewriter; no finish_text(), notification, fresh action,
		# focus change or custody event is injected to trigger republication.
		caption.caption_text.active_speed = 0.001
		caption.caption_text.set_process(true)
		var deadline := Time.get_ticks_msec() + 5000
		while _finished == 0 and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(0.01).timeout
	else:
		before.action.call(null)
	assert_false(caption.caption_text.revealing)
	assert_eq(runtime.current_event_idx, 0, "finishing is not advancement")
	assert_eq(_finished, 1)
	var reveal_after: int = caption.caption_text.get_reveal_generation()
	assert_gt(reveal_after, reveal_before)
	assert_gt(caption.accept_input._accessibility_generation, before.custody,
		"completion explicitly retires the registered action lifetime")
	var after := await _await_publication(surface, reveal_after)
	if after.is_empty(): return
	assert_eq(surface._label, unchanged.label)
	assert_eq(surface._available, unchanged.available)
	assert_eq(surface._source_visible, unchanged.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), unchanged.focus)
	assert_eq(after.target, unchanged.target)
	assert_eq(surface.get_instance_id(), unchanged.surface_id)
	assert_eq(surface.get_global_rect(), unchanged.surface_rect)
	assert_eq(caption.caption_text.get_global_rect(), unchanged.caption_rect)
	# Let the real post-organic input block expire; do not stop its timer.
	var block_deadline := Time.get_ticks_msec() + 5000
	while not runtime.Inputs.input_block_timer.is_stopped() and Time.get_ticks_msec() < block_deadline:
		await get_tree().create_timer(0.01).timeout
	assert_true(runtime.Inputs.input_block_timer.is_stopped())
	before.action.call(null)
	await _settle()
	assert_eq(runtime.current_event_idx, 0, "old published action stays stale after completion")
	after.action.call(null)
	after.action.call(null)
	await _settle()
	assert_eq(runtime.current_event_idx, 1, "newly registered action advances once")
	assert_true(caption.caption_text.revealing, "successor keeps its reveal")
	assert_eq(_finished, 1)

func test_continue_registered_action_refreshes_after_organic_finish() -> void:
	await _check_registered_completion(true)

func test_continue_registered_action_refreshes_after_manual_finish() -> void:
	await _check_registered_completion(false)
