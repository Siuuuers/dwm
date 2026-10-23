extends SceneTree
## Process-exit regression for Dialogic speaker resource lifetimes.
##
## Run through tools/testing/Invoke-IsolatedGodot.ps1 with this script. The VERIFIED
## marker proves the in-engine checks completed; the wrapper's exit_code proves that
## process-root cleanup also completed instead of crashing after the marker.

const DIRECTORY_SETTING := "dialogic/directories/dch_directory"
const REGISTERED_ID := "RegisteredProbe"
const UNKNOWN_ID := "Narrator"

var _runtime: DialogicGameHandler
var _settings_directory: Dictionary
var _registered_path := ""
var _timelines: Array[DialogicTimeline] = []
var _failures: Array[String] = []
var _checks := 0
var _started := 0
var _ended := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("DIALOGIC_RUNTIME_SPEAKER_PROBE_FAILED: " + message)
	return condition


func _run() -> void:
	var isolated_root := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	if not _check(not isolated_root.is_empty(), "DWM_TEST_ROOT is required"):
		_finish()
		return
	_runtime = root.get_node_or_null("Dialogic") as DialogicGameHandler
	if not _check(_runtime != null, "installed Dialogic autoload exists"):
		_finish()
		return
	if not _check(_runtime.current_timeline == null, "installed runtime begins idle"):
		_finish()
		return
	_runtime.timeline_started.connect(func() -> void: _started += 1)
	_runtime.timeline_ended.connect(func() -> void: _ended += 1)
	var configured: Variant = ProjectSettings.get_setting(DIRECTORY_SETTING, {})
	if not _check(typeof(configured) == TYPE_DICTIONARY, "character setting is a dictionary"):
		_finish()
		return
	_settings_directory = (configured as Dictionary).duplicate(true)
	if not _create_registered_fixture(isolated_root):
		_finish()
		return
	var directory := DialogicResourceUtil.get_directory("dch").duplicate()
	directory.erase(UNKNOWN_ID)
	directory[REGISTERED_ID] = _registered_path
	DialogicResourceUtil.set_directory("dch", directory)
	if not _check(DialogicResourceUtil.get_directory("dch").get(REGISTERED_ID) is String,
			"registered fixture stays a path string") or not _check_settings_unchanged("fixture install"):
		_finish()
		return
	for speaker: String in ["anonymous", "registered", "unknown"]:
		if not await _exercise(speaker):
			_finish()
			return
	_check(_started == 6, "three speakers each start twice")
	_check(_ended == 6, "cancellation and natural completion each end all three speakers")
	_check(_runtime.current_timeline == null, "runtime is idle before process-root shutdown")
	_check(DialogicResourceUtil.get_directory("dch").get(REGISTERED_ID) is String,
		"path registration survives every clear")
	_check(DialogicResourceUtil.get_directory("dch").get(UNKNOWN_ID) is Resource,
		"runtime-created speaker remains registered until process-root shutdown")
	_check_settings_unchanged("final playback")
	_finish()


func _create_registered_fixture(isolated_root: String) -> bool:
	var folder := isolated_root.path_join("dialogic-runtime-speaker-probe")
	if not _check(DirAccess.make_dir_recursive_absolute(folder) == OK,
			"registered fixture directory is writable"):
		return false
	_registered_path = folder.path_join("registered_probe.tres")
	var character := DialogicCharacter.new()
	character.display_name = "Registered Probe"
	if not _check(ResourceSaver.save(character, _registered_path) == OK,
			"registered character saves under the isolated root"):
		return false
	return _check(ResourceLoader.exists(_registered_path), "registered character path loads")


func _exercise(speaker: String) -> bool:
	if not await _start_line(speaker, "cancel"):
		return false
	var registry_after_start := DialogicResourceUtil.get_directory("dch").duplicate()
	_runtime.end_timeline(true)
	if not await _wait_until(func() -> bool:
		return _runtime.current_timeline == null and _ended == _started):
		return _check(false, speaker + " cancellation did not settle")
	if not _check(_ended == _started, speaker + " cancellation emits one end") \
			or not _check_registry(speaker, registry_after_start, "cancellation") \
			or not _check_settings_unchanged(speaker + " cancellation"):
		return false
	if not await _start_line(speaker, "natural"):
		return false
	if not _check_registry(speaker, registry_after_start, "restart"):
		return false
	_runtime.Text.skip_text_reveal()
	if not await _wait_until(func() -> bool:
		return _runtime.current_state != DialogicGameHandler.States.REVEALING_TEXT):
		return _check(false, speaker + " text did not finish revealing")
	_runtime.Inputs.input_block_timer.stop()
	_runtime.Inputs.handle_input()
	if not await _wait_until(func() -> bool:
		return _runtime.current_timeline == null and _ended == _started):
		return _check(false, speaker + " timeline did not complete naturally")
	return _check(_ended == _started, speaker + " natural completion emits one end") \
		and _check_registry(speaker, registry_after_start, "natural completion") \
		and _check_settings_unchanged(speaker + " natural completion")


func _start_line(speaker: String, phase: String) -> bool:
	var prefix := ""
	match speaker:
		"registered": prefix = REGISTERED_ID + ": "
		"unknown": prefix = UNKNOWN_ID + ": "
		"anonymous": pass
		_: return _check(false, "unsupported speaker mode " + speaker)
	var timeline := DialogicTimeline.new()
	timeline.from_text(prefix + "Speaker lifecycle " + phase + ".")
	_timelines.append(timeline)
	_runtime.start(timeline)
	if not await _wait_until(func() -> bool:
		return _runtime.current_timeline == timeline and _runtime.current_event_idx == 0 \
			and _runtime.current_state == DialogicGameHandler.States.REVEALING_TEXT):
		return _check(false, "%s %s playback did not start" % [speaker, phase])
	var event := _runtime.current_timeline_events[0] as DialogicTextEvent
	if not _check(event != null, "%s %s uses a real Text event" % [speaker, phase]):
		return false
	match speaker:
		"anonymous":
			return _check(event.character == null, "anonymous text has no character")
		"registered":
			return _check(event.character != null and event.character.display_name == "Registered Probe",
				"registered text resolves the path-backed character") \
				and _check(DialogicResourceUtil.get_directory("dch").get(REGISTERED_ID) is String,
					"registered playback does not replace its path with a Resource")
		"unknown":
			return _check(event.character != null and event.character.display_name == UNKNOWN_ID,
				"unknown text creates its runtime character") \
				and _check(DialogicResourceUtil.get_directory("dch").get(UNKNOWN_ID) is Resource,
					"unknown speaker is present only in the runtime directory")
	return false


func _check_registry(speaker: String, expected: Dictionary, phase: String) -> bool:
	var actual := DialogicResourceUtil.get_directory("dch")
	if speaker == "unknown":
		return _check(actual.get(UNKNOWN_ID) is Resource,
			"unknown registration survives " + phase) \
			and _check(actual.get(UNKNOWN_ID) == expected.get(UNKNOWN_ID),
				"the same runtime character survives " + phase) \
			and _check(actual.get(REGISTERED_ID) is String,
				"registered path survives " + phase)
	return _check(actual == expected, "%s registry survives %s" % [speaker, phase])


func _check_settings_unchanged(phase: String) -> bool:
	var configured: Variant = ProjectSettings.get_setting(DIRECTORY_SETTING, {})
	if not _check(typeof(configured) == TYPE_DICTIONARY, phase + " keeps dictionary settings"):
		return false
	var current := configured as Dictionary
	if not _check(current == _settings_directory, phase + " leaves ProjectSettings unchanged"):
		return false
	for value: Variant in current.values():
		if not _check(not value is Resource, phase + " keeps live Resources out of ProjectSettings"):
			return false
	return true


func _wait_until(predicate: Callable, frames: int = 120) -> bool:
	for frame: int in frames:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()


func _finish() -> void:
	var success := _failures.is_empty()
	print("DIALOGIC_RUNTIME_SPEAKER_PROBE_", "VERIFIED" if success else "FAILED",
		" speakers=3 lifecycles=6 checks=", _checks, " failures=", _failures.size())
	quit(0 if success else 1)
