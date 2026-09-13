extends Node
## Runs the real FINAL bootstrap and Profile autoload against wrapper-isolated data.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const UNKNOWN_LINE := "fixture.unregistered.live.line"

var _restore_count := 0
var _ready_count := 0
var _early_refusal: Dictionary = {}
var _early_unchanged := false
var _finished := false

func _enter_tree() -> void:
	if OS.get_environment("DWM_TEST_ROOT").strip_edges().is_empty():
		_abort("DWM_TEST_ROOT is required")
		return
	get_node("/root/ProfileManager").profile_restored.connect(_on_profile_restored)
	get_node("/root/ApplicationBootstrap").application_ready.connect(_on_application_ready)

func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(func() -> void:
		if not _finished: _abort("FINAL startup did not complete"))

func _on_profile_restored(_snapshot: Dictionary) -> void:
	_restore_count += 1
	var profile: Node = get_node("/root/ProfileManager")
	var before: Dictionary = profile.get_profile_snapshot()
	var revision: int = profile.get_profile_revision()
	_early_refusal = profile.mark_line_visited(UNKNOWN_LINE)
	_early_unchanged = profile.get_profile_snapshot() == before and profile.get_profile_revision() == revision

func _on_application_ready() -> void:
	_ready_count += 1
	call_deferred("_verify")

func _verify() -> void:
	var bootstrap: Node = get_node("/root/ApplicationBootstrap")
	var profile: Node = get_node("/root/ProfileManager")
	if not _check(bootstrap.get_startup_state().ready and _ready_count == 1 and _restore_count == 1,
			"real FINAL startup and profile publication occur once"): return
	if not _check(not _early_refusal.get("ok", true) and _early_refusal.get("code") == &"unregistered_line_id",
			"registry refuses unknown IDs before profile_restored observers can write"): return
	if not _check(_early_unchanged, "early refusal leaves profile and revision unchanged"): return
	var loaded: Dictionary = MANIFEST.load_ids_default()
	if not _check(loaded.get("ok", false), "shipped IDs load"): return
	var ids: Dictionary = loaded.value
	var admitted: Array[String] = [ids.reply_lines[0].line_id]
	for atom: Dictionary in ids.atoms:
		if atom.kind == "observer_presentation": admitted.append(atom.associated_line_id)
	if not _check(admitted.size() == 3, "one reply and both Observer lines selected"): return
	for line_id: String in admitted:
		var marked: Dictionary = profile.mark_line_visited(line_id)
		if not _check(marked.get("ok", false) and profile.is_line_visited(line_id),
				"live configured writer accepts " + line_id): return
	var path: String = str(bootstrap.get("_selected_root")).path_join("profile.json")
	var disk_before := FileAccess.get_file_as_string(path)
	var snapshot: Dictionary = profile.get_profile_snapshot()
	var revision: int = profile.get_profile_revision()
	var refused: Dictionary = profile.mark_line_visited(UNKNOWN_LINE)
	if not _check(not refused.get("ok", true) and refused.get("code") == &"unregistered_line_id",
			"READY live writer rejects an unregistered ID"): return
	if not _check(profile.get_profile_snapshot() == snapshot and profile.get_profile_revision() == revision
			and FileAccess.get_file_as_string(path) == disk_before,
			"refusal changes neither memory, revision nor disk"): return
	var persisted: Variant = JSON.parse_string(disk_before)
	if not _check(persisted is Dictionary, "profile file remains readable"): return
	for line_id: String in admitted:
		if not _check(line_id in persisted.visited_line_ids, "admitted line persisted " + line_id): return
	_finished = true
	print("VISITED_LINE_REGISTRY_PASS: FINAL bootstrap arms writer before profile_restored; reply and both Observer IDs persist; unknown ID leaves memory, revision and disk unchanged")
	get_tree().quit(0)

func _check(condition: bool, message: String) -> bool:
	if not condition: _abort(message)
	return condition

func _abort(message: String) -> void:
	_finished = true
	push_error("VISITED_LINE_REGISTRY_FAIL: " + message)
	get_tree().quit(1)
