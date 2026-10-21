extends "res://tests/integration/test_witnessed_caption_runtime.gd"
## Diagnostic lane selects only test_continue_initial_registration_observation.
## Rendered official Windows with --accessibility always; real isolated fixture.
## Observes callables supplied by the real native notification, not fresh captures.

var _early_observation: Dictionary = {}
var _observation_armed := false

func _continue_registration_phase(phase: String) -> void:
	if _early_observation.is_empty(): return
	_early_observation.phase = phase
	if not _early_observation.phases.has(phase):
		_early_observation.phases[phase] = {"counts": _early_observation.zero_counts.duplicate(), "last": {}}
	var boundary := {"phase": phase, "usec": Time.get_ticks_usec(),
		"surface_id": _early_observation.get("owner_id", 0)}
	if is_instance_valid(caption):
		boundary["layout_id"] = layout.get_instance_id()
		boundary["layout_parent_id"] = layout.get_parent().get_instance_id()
		boundary["surface_id"] = caption.background_input.get_instance_id()
	_early_observation.boundaries.append(boundary)

func after_each() -> void:
	if _observation_armed:
		Engine.remove_meta(&"dwm_continue_registration_seed")
		_observation_armed = false
	await super.after_each()

class ContinuePublicationProbe extends "res://scripts/ui/witnessed/WitnessedAccessibleContinue.gd":
	var publications: Array[Dictionary] = []
	func capture_continue_action() -> Callable:
		_observe_registration("capture_enter")
		var action := super.capture_continue_action()
		publications.append({"action": action,
			"reveal": _accept_input._caption.get_reveal_generation(),
			"custody": _accept_input._accessibility_generation,
			"target": _accept_input._focus_caption().get_instance_id()})
		_observe_registration("capture_return", {"publications": publications.size(),
			"reveal": publications.back().reveal, "custody": publications.back().custody})
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
	assert_false(Engine.has_meta(&"dwm_continue_registration_seed"), "observation seed is isolated")
	if Engine.has_meta(&"dwm_continue_registration_seed"): return null
	var zeros := {"instance_init": 0, "enter_tree": 0, "exit_tree": 0,
		"bind_enter": 0, "bind_return": 0, "retirement_queue_request": 0, "retirement_queue_return": 0, "projection_changed": 0, "queue_request": 0, "queue_return": 0,
		"notification": 0, "element": 0, "admission": 0, "owner_capture_enter": 0,
		"owner_capture_return": 0, "capture_enter": 0, "capture_return": 0, "action_registered": 0}
	_early_observation = {"window": "ordinary instance construction through post-rebind wait",
		"owner_id": 0, "zero_counts": zeros, "counts": zeros.duplicate(), "last": {},
		"events": [], "boundaries": [], "phases": {}, "phase": "armed"}
	_continue_registration_phase("armed")
	Engine.set_meta(&"dwm_continue_registration_seed", _early_observation)
	_observation_armed = true
	var mounted: bool = await _mount_root_accept_fixture("Current.\nFollowing.")
	Engine.remove_meta(&"dwm_continue_registration_seed")
	_observation_armed = false
	if not mounted: return null
	var surface: Control = caption.background_input
	assert_true(surface.has_meta(&"continue_registration_observation"), "actual Continue instance was observed before tree entry")
	if not surface.has_meta(&"continue_registration_observation"): return null
	assert_eq(int(_early_observation.owner_id), surface.get_instance_id(), "observation belongs to the mounted Continue")
	_continue_registration_phase("script_replacement")
	surface._observe_registration("before_install", {"script": str(surface.get_script())})
	surface.set_script(ContinuePublicationProbe)
	surface._observe_registration("after_install", {"script": str(surface.get_script()),
		"publications": surface.publications.size()})
	_continue_registration_phase("post_mount_rebind")
	surface.bind_accessible_continue(caption.accept_input, get_node("/root/LocalizationManager"))
	surface._observe_registration("after_rebind", {"label": surface._label,
		"source_visible": surface._source_visible, "available": surface._available})
	surface.set_process(true)
	assert_eq(surface._label, localization.t("button.continue"))
	assert_true(surface._source_visible, "mounted Continue source is admitted")
	assert_true(surface._available, "mounted Continue action is admitted")
	return surface

func _await_publication(surface: Control, reveal: int) -> Dictionary:
	_continue_registration_phase("initial_wait")
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		for publication: Dictionary in surface.publications:
			if publication.reveal == reveal: return publication
		await get_tree().create_timer(0.01).timeout
	_emit_registration_snapshot(surface, "timeout")
	assert_true(false, "Continue did not register a native action for reveal %d" % reveal)
	return {}

func _emit_registration_snapshot(surface: Control, outcome: String) -> void:
	var observation: Dictionary = surface.get_meta(&"continue_registration_observation")
	observation["final"] = {"outcome": outcome, "usec": Time.get_ticks_usec(),
		"surface_id": surface.get_instance_id(), "script": str(surface.get_script()),
		"publications": surface.publications.size(), "label": surface._label,
		"available": surface._available, "source_visible": surface._source_visible,
		"visible_in_tree": surface.is_visible_in_tree(),
		"reveal": caption.caption_text.get_reveal_generation()}
	print("CONTINUE_REGISTRATION_OBSERVATION " + JSON.stringify(observation))

func test_continue_initial_registration_observation() -> void:
	var surface: Control = await _mount_continue_publication_probe()
	if surface == null: return
	var reveal: int = caption.caption_text.get_reveal_generation()
	var publication := await _await_publication(surface, reveal)
	if publication.is_empty(): return
	_emit_registration_snapshot(surface, "initial_registration_observed")
	# Deliberately stop before completion or invoking the registered action.

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


