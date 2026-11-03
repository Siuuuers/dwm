extends "res://addons/gut/test.gd"

const WEEK := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const BASE := preload("res://tests/templates/seven_day/SevenDayTemplates.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SOURCE := "res://tests/fixtures/dialogic/Day1.dtl"
const PROBE := "res://tests/fixtures/dialogic/_inline_audio_authoring.dtl"
const BED := "res://tests/fixtures/audio/scene_test_bed.tres"
const NATIVE_BED := "res://tests/fixtures/audio/_inline_native_bed.nsf"
const NATIVE_CUE := "res://tests/fixtures/audio/_inline_native_cue.nsfe"

func after_each() -> void:
	DirAccess.remove_absolute(PROBE)
	DirAccess.remove_absolute(NATIVE_BED)
	DirAccess.remove_absolute(NATIVE_CUE)
	ADAPTER._scene_compile_cache.erase(PROBE)

func test_native_export_uses_unbounded_music_and_finite_cue_metadata() -> void:
	if not ClassDB.class_exists("VGMStream"):
		pending("Run with the staged gd_libvgm extension to verify native authoring")
		return
	for pair: Array in [
		["res://tools/audio_prototype/fixtures/loop_a.nsf", NATIVE_BED],
		["res://tools/audio_prototype/fixtures/confirm.nsfe", NATIVE_CUE]]:
		var copied := DirAccess.copy_absolute(pair[0], pair[1])
		assert_eq(copied, OK)
		if copied != OK: return
	var fallback := {"kind": "scene_audio_catalogue", "schema_version": 3,
		"assets": [], "plans": [], "bindings": []}
	var authored := {"music": [{"id": "quiet_room", "path": NATIVE_BED, "entrance_ms": 1250}],
		"sfx": [{"id": "confirm", "path": NATIVE_CUE}], "initial_music": "quiet_room"}
	var result := WEEK.prepare_audio_catalogue(authored, fallback, ["first"], "first")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_gt(result.value.assets[0].duration_ms, 0, "NSFe metadata bounds the one-shot")
	assert_eq(result.value.assets[1].duration_ms, 0, "raw NSF reports no finite endpoint")
	assert_eq(result.value.assets[1].sha256, FileAccess.get_sha256(NATIVE_BED))
	assert_eq(result.value.plans[0].load_anchor_ms, 1250)
	authored.sfx[0].path = NATIVE_BED
	assert_false(WEEK.prepare_audio_catalogue(authored, fallback, ["first"], "first").ok,
		"unbounded NSF cannot be authored as a finite SFX")
	authored.sfx[0].path = NATIVE_CUE
	authored.music[0].path = NATIVE_CUE
	assert_false(WEEK.prepare_audio_catalogue(authored, fallback, ["first"], "first").ok,
		"timed NSFe cannot stand in for continuously looping music")

func test_export_derives_media_metadata_and_initial_binding() -> void:
	var fallback := {"kind": "scene_audio_catalogue", "schema_version": 2,
		"assets": [], "plans": [], "bindings": []}
	var authored := {"music": [{"id": "quiet_room", "path": BED, "gain_db": -6.0, "entrance_ms": 250}],
		"sfx": [{"id": "door_knock", "path": BED}], "initial_music": "quiet_room"}
	var result := WEEK.prepare_audio_catalogue(authored, fallback, ["later", "first"], "first")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.schema_version, 3)
	assert_eq(result.value.assets[0].asset_id, "door_knock", "export sorts stable IDs")
	assert_eq(result.value.assets[1].sha256, FileAccess.get_sha256(BED))
	assert_eq(result.value.assets[1].duration_ms, 4000)
	assert_eq(result.value.assets[1].gain_db, -6.0)
	assert_eq(result.value.plans[0].entrance_ms, 250)
	assert_eq(result.value.plans[0].load_anchor_ms, 250, "Load starts at the authored entrance")
	assert_eq(result.value.bindings, [{"entry_id": "first", "plan_id": "quiet_room"},
		{"entry_id": "later", "plan_id": null}], "ordinary entries do not reset music")
	assert_eq(WEEK.prepare_audio_catalogue(authored, fallback, ["later", "first"], "first"), result)
	assert_true(fallback.assets.is_empty(), "generation leaves the supplied fallback untouched")

func test_explicit_silent_start_does_not_need_a_music_asset() -> void:
	var fallback := {"kind": "scene_audio_catalogue", "schema_version": 2,
		"assets": [], "plans": [], "bindings": []}
	var result := WEEK.prepare_audio_catalogue({"initial_music": ""}, fallback, ["first"], "first")
	assert_true(result.ok, str(result))
	if result.ok: assert_eq(result.value.bindings[0].plan_id, null)

func test_authoring_mistakes_are_rejected_before_export() -> void:
	var fallback := {"kind": "scene_audio_catalogue", "schema_version": 2,
		"assets": [], "plans": [], "bindings": []}
	for authored: Dictionary in [
		{"initial_music": "unknown"},
		{"music": [{"id": "quiet_room", "path": BED, "entrance_ms": 5000}]},
		{"sfx": [{"id": "door_knock", "path": BED}, {"id": "door_knock", "path": BED}]},
		{"music": [{"id": "quiet_room", "path": BED, "gain_db": "quiet"}]}]:
		assert_false(WEEK.prepare_audio_catalogue(authored, fallback, ["first"], "first").ok, str(authored))

func test_registration_checks_compiled_cue_references_without_per_cue_lists() -> void:
	var prepared := BASE.prepare()
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var original: Dictionary = prepared.value.registration
	var labels: Array = []
	for entry: Dictionary in original.entry_manifest.entries: labels.append(entry.entry_id)
	for cue: String in ["music " + BASE.MUSIC_PLAN_ID, "music stop", "sfx " + BASE.MUSIC_ASSET_ID,
		"music missing_plan", "sfx missing_asset", "sfx native_unbounded"]:
		var bundle: Dictionary = original.duplicate(true)
		bundle.audio_catalogue.schema_version = 3
		bundle.audio_catalogue.assets.append({"asset_id": "native_unbounded",
			"path": "res://audio/bgm/quiet_room.nsf", "sha256": "a".repeat(64), "duration_ms": 0})
		bundle.audio_catalogue.assets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.asset_id < b.asset_id)
		var source := FileAccess.get_file_as_string(SOURCE).replace("label Day1\n", "label Day1\n# audio " + cue + "\n")
		var file := FileAccess.open(PROBE, FileAccess.WRITE)
		assert_not_null(file)
		if file == null: return
		file.store_string(source)
		file.close()
		for entry: Dictionary in bundle.entry_manifest.entries:
			if entry.entry_id == "Day1": entry.locators.en.path = PROBE
		for programme: Dictionary in bundle.scene_programme.entries:
			if programme.entry_id != "Day1": continue
			var compiled := ADAPTER.compile_scene_programme(PROBE, "Day1", labels, programme.markers)
			assert_true(compiled.ok, str(compiled))
			if not compiled.ok: return
			programme.content_sha256 = compiled.value.content_sha256
			programme.program_sha256 = compiled.value.program_sha256
			for target: Dictionary in bundle.targets:
				if target.target.get("entry_id") == "Day1": target.target.program_sha256 = compiled.value.program_sha256
		var checked := MANIFEST.validate_scene_registration(bundle)
		assert_eq(checked.ok, not "missing_" in cue and cue != "sfx native_unbounded",
			cue + ": " + str(checked.get("code", "")))
