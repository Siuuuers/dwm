extends "res://addons/gut/test.gd"
# Physical Dialogic fixture contract (dwm-p2r.8, Plan-05 Task 5). RED-first on the physical files:
# no assertion here may be unconditional, and none may mutate a gameplay autoload.

const FIXTURE_PATH := "res://tests/fixtures/dialogic/phase2r_contract_fixture.dtl"
const FIXTURE_MANIFEST := "res://tests/fixtures/dialogic/manifest.json"
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")


func _manifest() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_MANIFEST):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(FIXTURE_MANIFEST))
	return parsed.get("value", {}) if parsed.get("ok", false) else {}


func test_physical_fixture_and_manifest_are_required() -> void:
	assert_true(FileAccess.file_exists(FIXTURE_PATH), "missing physical Dialogic fixture")
	assert_true(FileAccess.file_exists(FIXTURE_MANIFEST), "missing fixture manifest")


func test_fixture_manifest_is_strict_and_separate_from_production() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	assert_eq(str(manifest.get("timeline_id", "")), "fixture.phase2r.contract", "the fixture owns its own timeline id")
	assert_eq(int(manifest.get("schema_version", 0)), 1, "fixture manifest schema_version")
	# It must NOT be one of the 61 production records.
	var production := STRICT_JSON.parse_object(FileAccess.get_file_as_string("res://data/manifests/timelines.json"))
	if production.get("ok", false):
		for record in (production["value"] as Dictionary).get("records", []):
			assert_false(str((record as Dictionary).get("id", "")) == "fixture.phase2r.contract",
				"the test fixture must never enter the production manifest")


func test_fixture_registers_every_declared_semantic_id() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	var lines: Array = manifest.get("line_ids", [])
	assert_eq(lines, ["fixture.line.start", "fixture.line.after_choice", "fixture.line.after_effect"],
		"three text events map in order")
	assert_eq(manifest.get("choice_ids", []), ["fixture.choice.continue"], "one registered choice")
	assert_eq(manifest.get("signal_ids", []), ["fixture.marker.safe", "fixture.effect.tx", "fixture.variable.tx"],
		"safe marker, effect transaction and variable transaction signals")


func test_fixture_signal_descriptors_are_exact_and_non_gameplay() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	var descriptors: Dictionary = manifest.get("signal_descriptors", {})
	assert_eq(str((descriptors.get("fixture.marker.safe", {}) as Dictionary).get("kind", "")), "safe_marker")
	assert_eq(str((descriptors.get("fixture.effect.tx", {}) as Dictionary).get("kind", "")), "effect_transaction")
	assert_eq(str((descriptors.get("fixture.variable.tx", {}) as Dictionary).get("kind", "")), "variable_transaction")
	for id in ["fixture.marker.safe", "fixture.effect.tx", "fixture.variable.tx"]:
		var descriptor: Dictionary = descriptors.get(id, {})
		assert_true(str(descriptor.get("owner", "")) == "fixture",
			"a fixture signal never routes to a gameplay autoload: " + id)


func test_physical_fixture_text_declares_its_header_and_labels() -> void:
	if not FileAccess.file_exists(FIXTURE_PATH):
		assert_true(false, "missing physical Dialogic fixture")
		return
	var text := FileAccess.get_file_as_string(FIXTURE_PATH)
	assert_true("# timeline_id: fixture.phase2r.contract" in text, "declares its timeline id")
	assert_true("label fixture.start" in text, "declares its entry label")
	for signal_id in ["fixture.marker.safe", "fixture.effect.tx", "fixture.variable.tx"]:
		assert_true(signal_id in text, "raises " + signal_id)
	assert_true(text.strip_edges().ends_with("return"), "terminates with return")


func test_fixture_event_indices_are_recorded_after_import() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	var events: Array = manifest.get("events", [])
	assert_true(events.size() >= 3, "the manifest records imported event indices")
	var seen := {}
	for event in events:
		var index := int((event as Dictionary).get("event_index", -1))
		assert_true(index >= 0, "each recorded event has a real index")
		assert_false(seen.has(index), "event indices are unique")
		seen[index] = true
		assert_false(str((event as Dictionary).get("event_kind", "")).is_empty(), "each event records its kind")


func test_fixture_content_fingerprint_matches_the_physical_file() -> void:
	var manifest := _manifest()
	if manifest.is_empty() or not FileAccess.file_exists(FIXTURE_PATH):
		assert_true(false, "fixture and manifest are required")
		return
	assert_eq(str(manifest.get("content_fingerprint", "")), "sha256:" + FileAccess.get_sha256(FIXTURE_PATH),
		"the manifest is bound to the exact fixture bytes")


# -------------------------------------------------------------------------------------------------
# Plan 01 Task 8 (dwm-p2r.14): the bridge's completion seam is no longer caller-forgeable.
#
# The bridge used to expose a public `finish_current_timeline(result)`. Any caller could announce
# that a timeline had finished and hand it whatever `result` it liked, which is exactly the forgery
# `DialogicPresentationOwnerAdapter` exists to make impossible. Task 8 removes it: the ONLY way a
# generic timeline can be declared finished is the runtime's own end-of-timeline signal.
# -------------------------------------------------------------------------------------------------

const BRIDGE_SCRIPT_PATH := "res://autoload/DialogicBridge.gd"


func _fresh_bridge() -> Node:
	var bridge: Node = load(BRIDGE_SCRIPT_PATH).new()
	add_child_autofree(bridge)
	return bridge


func test_the_caller_forgeable_finisher_is_gone_from_source_and_from_the_instance() -> void:
	var bridge := _fresh_bridge()
	assert_false(bridge.has_method("finish_current_timeline"),
		"no caller may declare a timeline finished")
	# Source-level too: a private rename that kept the same forgeable behaviour would still be a way
	# in, so the identifier itself must not appear.
	var source := FileAccess.get_file_as_string(BRIDGE_SCRIPT_PATH)
	assert_false(source.contains("func finish_current_timeline"),
		"the method is removed, not merely undeclared")


func test_the_runtime_end_signal_finalizes_the_retained_timeline_exactly_once() -> void:
	var bridge := _fresh_bridge()
	var finished: Array = []
	bridge.timeline_finished.connect(func(timeline_id: String, result: Dictionary) -> void:
		finished.append({"timeline_id": timeline_id, "result": result.duplicate(true)}))

	var started: Dictionary = bridge.start_timeline_id("hospital.faint", {"kind": "hospital"})
	if not started.get("ok", false):
		# No Dialogic runtime in this environment; the removal assertions above still stand.
		return
	assert_eq(bridge.get_current_timeline_id(), "hospital.faint")

	bridge.call(&"_on_runtime_timeline_ended")
	assert_eq(finished.size(), 1, "the runtime signal produces exactly one completion")
	assert_eq(str((finished[0] as Dictionary)["timeline_id"]), "hospital.faint")
	assert_eq(bridge.get_current_timeline_id(), "",
		"the retained timeline is finalized before the completion is emitted")

	# Clearing BEFORE the emit is what makes a duplicate runtime signal a no-op rather than a second
	# completion for the same presentation.
	bridge.call(&"_on_runtime_timeline_ended")
	assert_eq(finished.size(), 1, "a repeated runtime signal emits nothing new")


func test_an_idle_bridge_emits_no_completion_at_all() -> void:
	var bridge := _fresh_bridge()
	var finished: Array = []
	bridge.timeline_finished.connect(func(_timeline_id: String, _result: Dictionary) -> void:
		finished.append(1))
	bridge.call(&"_on_runtime_timeline_ended")
	assert_true(finished.is_empty(), "a bridge with no retained timeline finishes nothing")


# -------------------------------------------------------------------------------------------------
# Seven-Day Flow Plan 01 Task 5 (dwm-oyo.2 DEVIATION-9, rulings R-CC and R-DD).
#
# The production path start is retired BODY-first: its declared signature must stay byte-exact
# because the frozen schedule gate pins the bridge's declared surface, so retirement means the
# body fails closed in the legacy failure shape while the spelling survives. The bridge's legacy
# timeline vocabulary now resolves through the exact locator API (get_path_for_id) instead of the
# deprecated permissive resolver. The scans below are scoped to production code and to tokens the
# frozen positive scan does not require, so they cannot collide with the schedule-gate law that
# REQUIRES the literal start_timeline_id call inside DialogicPresentationOwnerAdapter.
# -------------------------------------------------------------------------------------------------


func _gd_files(root: String) -> Array[String]:
	var output: Array[String] = []
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var current: String = directories.pop_back()
		var handle := DirAccess.open(current)
		if handle == null:
			continue
		handle.list_dir_begin()
		var name := handle.get_next()
		while name != "":
			var path := current + "/" + name
			if handle.current_is_dir():
				directories.append(path)
			elif name.ends_with(".gd"):
				output.append(path)
			name = handle.get_next()
		handle.list_dir_end()
	return output


func _comment_stripped(source: String) -> String:
	var kept: Array[String] = []
	for line: String in source.split("\n"):
		var hash_index := line.find("#")
		kept.append(line.substr(0, hash_index) if hash_index >= 0 else line)
	return "\n".join(kept)


func test_start_timeline_path_is_retired_for_production() -> void:
	var bridge := _fresh_bridge()
	var failures: Array = []
	bridge.timeline_failed.connect(func(result: Dictionary) -> void: failures.append(result.duplicate(true)))
	var refused: Dictionary = bridge.start_timeline_path("res://dialogic/timelines/en/contacts/lavinia_day1.dtl")
	if refused.get("ok", false):
		# RED-phase tidy-up only: never leave a physically started timeline running behind a failure.
		var dialogic := bridge.get_node_or_null("/root/Dialogic")
		if dialogic != null and dialogic.has_method("clear"):
			dialogic.call("clear", 1)
	assert_false(refused.get("ok", true), "a production path start must fail closed (R-CC)")
	assert_eq(str(refused.get("reason", "")), "start_timeline_path_retired",
		"the legacy surface keeps its legacy failure shape: " + str(refused))
	assert_false(str(refused.get("message", "")).is_empty(), "the refusal explains itself")
	assert_eq(failures.size(), 1, "the refusal is announced on timeline_failed")
	var source := FileAccess.get_file_as_string(BRIDGE_SCRIPT_PATH)
	assert_true(source.contains("func start_timeline_path(path: String, context: Dictionary = {}) -> Dictionary:"),
		"the declared signature stays byte-exact while the body fails closed (frozen gate law)")


func test_no_production_code_calls_the_retired_path_start() -> void:
	var checked := 0
	for root: String in ["res://autoload", "res://scripts"]:
		for path: String in _gd_files(root):
			if path == BRIDGE_SCRIPT_PATH:
				continue
			checked += 1
			var code := _comment_stripped(FileAccess.get_file_as_string(path))
			assert_false(code.contains("start_timeline_path("),
				path + " must not call the retired production path start")
	assert_true(checked > 100, "the scan actually walked the production tree: %d files" % checked)


func test_the_bridge_resolves_legacy_ids_through_the_exact_locator_api() -> void:
	var code := _comment_stripped(FileAccess.get_file_as_string(BRIDGE_SCRIPT_PATH))
	assert_false(code.contains("get_timeline_path("),
		"the deprecated permissive resolver is gone from the bridge (R-DD)")
	assert_true(code.contains("get_path_for_id("),
		"the exact locator API answers the legacy timeline vocabulary")


func test_an_unregistered_timeline_marker_is_ignored_and_a_safe_marker_passes() -> void:
	var bridge := _fresh_bridge()
	var markers: Array = []
	bridge.timeline_marker_received.connect(func(marker_id: String, _payload: Dictionary) -> void: markers.append(marker_id))
	bridge.timeline_marker("not.a.registered.marker")
	assert_true(markers.is_empty(), "an unregistered marker emits nothing (fails closed)")
	bridge.timeline_marker("opening_done")
	assert_eq(markers, ["opening_done"], "a whitelisted marker still passes")
