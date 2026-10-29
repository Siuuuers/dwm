extends "res://addons/gut/test.gd"

const MANIFEST := preload("res://scripts/data/AudioManifest.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _catalogue() -> Dictionary:
	return {"kind": "scene_audio_catalogue", "schema_version": 1,
		"assets": [{"asset_id": "TEST.audio.asset.01", "path": "res://tests/fixtures/audio/not_installed.tres", "sha256": "a".repeat(64), "duration_ms": 4000}],
		"plans": [{"plan_id": "TEST.audio.01", "revision": 1, "variant_id": "base", "ambience_asset_id": "TEST.audio.asset.01", "entrance_ms": 0, "load_anchor_id": "load.01", "load_anchor_ms": 1000, "authorial": true, "essential": false, "missing_media": "silence", "music": null, "cues": []}],
		"bindings": [{"entry_id": "scene.test.a", "plan_id": null}, {"entry_id": "scene.test.b", "plan_id": "TEST.audio.01"}]}

func _registration() -> Dictionary:
	# Only audio's delegated inputs; full registration authority stays with A.
	return {"kind": "scene_reading_registration", "schema_version": 3,
		"entry_manifest": {"entries": [{"entry_id": "scene.test.a"}, {"entry_id": "scene.test.b"}]},
		"audio_catalogue": _catalogue()}

func _valid(catalogue: Variant) -> bool:
	return MANIFEST.validate_scene_catalogue(catalogue, ["scene.test.a", "scene.test.b"]).ok

func test_catalogue_is_pure_and_returns_detached_value() -> void:
	var catalogue: Dictionary = _catalogue()
	var checked: Dictionary = MANIFEST.validate_scene_catalogue(catalogue, ["scene.test.b", "scene.test.a"])
	assert_true(checked.ok, "Missing media does not invalidate definitions")
	checked.value.assets[0].path = "changed"
	assert_eq(catalogue, _catalogue())

func test_exact_keys_at_all_catalogue_levels() -> void:
	for level: String in ["root", "assets", "plans", "bindings"]:
		var catalogue: Dictionary = _catalogue()
		var target: Dictionary = catalogue if level == "root" else catalogue[level][0]
		target["extra"] = true
		assert_false(_valid(catalogue), level)
		target.erase("extra")
		target.erase(target.keys()[0])
		assert_false(_valid(catalogue), level + " missing key")

func test_malformed_containers_refuse_without_indexing() -> void:
	for bad: Variant in [null, [], 1, {}, {"kind": "scene_audio_catalogue"}]:
		assert_false(_valid(bad))
	for field: String in ["assets", "plans", "bindings"]:
		for bad: Variant in [null, {}, [null], [7]]:
			var catalogue: Dictionary = _catalogue()
			catalogue[field] = bad
			assert_false(_valid(catalogue))

func test_asset_digest_and_path_restrictions() -> void:
	for bad: Variant in ["A".repeat(64), "a".repeat(63), "z".repeat(64), 42]:
		var catalogue: Dictionary = _catalogue()
		catalogue.assets[0].sha256 = bad
		assert_false(_valid(catalogue))
	for path: String in ["res://audio/test.tres", "res://tests/fixtures/audio/../bad.tres", "res://tests/fixtures/audio//bad.tres", "res://tests/fixtures/audio/./bad.tres", "res://tests/fixtures/audio/", "res://tests/fixtures/audio/x\\bad.tres"]:
		var catalogue: Dictionary = _catalogue()
		catalogue.assets[0].path = path
		assert_false(_valid(catalogue), path)

func test_numeric_types_and_position_bounds() -> void:
	for field: String in ["revision", "entrance_ms", "load_anchor_ms"]:
		for bad: Variant in [1.0, true, "1", -1]:
			var catalogue: Dictionary = _catalogue()
			catalogue.plans[0][field] = bad
			assert_false(_valid(catalogue))
	for field: String in ["entrance_ms", "load_anchor_ms"]:
		var catalogue: Dictionary = _catalogue()
		catalogue.plans[0][field] = 4000
		assert_false(_valid(catalogue))
		catalogue.plans[0][field] = 3999
		assert_true(_valid(catalogue))
	for bad: Variant in [0, -1, 4000.0, true]:
		var catalogue: Dictionary = _catalogue()
		catalogue.assets[0].duration_ms = bad
		assert_false(_valid(catalogue))

func test_bounded_authorial_subset() -> void:
	var bad_fields: Dictionary = {"variant_id": "random", "revision": 0, "authorial": false, "essential": true, "missing_media": "inherit", "music": {}, "cues": ["cue"], "load_anchor_id": ""}
	for field: String in bad_fields:
		var catalogue: Dictionary = _catalogue()
		catalogue.plans[0][field] = bad_fields[field]
		assert_false(_valid(catalogue), field)

func test_duplicate_unsorted_and_unresolved_definitions() -> void:
	for field: String in ["assets", "plans", "bindings"]:
		var catalogue: Dictionary = _catalogue()
		catalogue[field].append(catalogue[field][0].duplicate(true))
		assert_false(_valid(catalogue))
	var catalogue: Dictionary = _catalogue()
	catalogue.bindings.reverse()
	assert_false(_valid(catalogue))
	catalogue = _catalogue()
	catalogue.plans[0].ambience_asset_id = "missing"
	assert_false(_valid(catalogue))
	catalogue = _catalogue()
	catalogue.bindings[1].plan_id = "missing"
	assert_false(_valid(catalogue))

func test_binding_coverage_and_duplicate_entry_ids() -> void:
	var catalogue: Dictionary = _catalogue()
	catalogue.bindings.pop_back()
	assert_false(_valid(catalogue))
	catalogue = _catalogue()
	catalogue.bindings[1].entry_id = "unknown"
	assert_false(_valid(catalogue))
	assert_false(MANIFEST.validate_scene_catalogue(_catalogue(), ["scene.test.a", "scene.test.a"]).ok)

func test_context_contains_only_selection_and_full_registration_digest() -> void:
	var registration: Dictionary = _registration()
	var made: Dictionary = MANIFEST.make_scene_context(registration, "scene.test.b", "receipt.1")
	assert_true(made.ok)
	assert_eq(made.value, {"kind": "scene_audio", "schema_version": 1,
		"registration_sha256": str(WRITER.stringify(registration).value).sha256_text(), "admission_receipt_id": "receipt.1",
		"selection": {"plan_id": "TEST.audio.01", "plan_revision": 1, "variant_id": "base", "anchor_id": "load.01"}})
	assert_false(MANIFEST.make_scene_context(registration, "unknown", "receipt.1").ok)
	assert_false(MANIFEST.make_scene_context(registration, "scene.test.b", "").ok)

func test_resolve_positions_and_all_returned_values_detached() -> void:
	var registration: Dictionary = _registration()
	var context: Dictionary = MANIFEST.make_scene_context(registration, "scene.test.b", "receipt.1").value
	var resolved: Dictionary = MANIFEST.resolve_scene_context(context, registration)
	assert_true(resolved.ok)
	assert_eq(resolved.value.entrance_seconds, 0.0)
	assert_eq(resolved.value.load_seconds, 1.0)
	resolved.value.snapshot.selection.anchor_id = "changed"
	resolved.value.record.asset.path = "changed"
	resolved.value.record.plan.revision = 99
	assert_eq(context.selection.anchor_id, "load.01")
	assert_eq(registration, _registration())

func test_explicit_silence_has_no_record_or_positions() -> void:
	var registration: Dictionary = _registration()
	var context: Dictionary = MANIFEST.make_scene_context(registration, "scene.test.a", "receipt.1").value
	assert_null(context.selection)
	var resolved: Dictionary = MANIFEST.resolve_scene_context(context, registration)
	assert_true(resolved.ok)
	assert_null(resolved.value.record)
	assert_eq(resolved.value.entrance_seconds, 0.0)
	assert_eq(resolved.value.load_seconds, 0.0)

func test_context_and_selection_tampering_refused_without_mutation() -> void:
	var registration: Dictionary = _registration()
	var context: Dictionary = MANIFEST.make_scene_context(registration, "scene.test.b", "receipt.1").value
	for field: String in ["plan_id", "plan_revision", "variant_id", "anchor_id"]:
		var changed: Dictionary = context.duplicate(true)
		changed.selection[field] = 7 if field == "plan_revision" else "unknown"
		assert_false(MANIFEST.resolve_scene_context(changed, registration).ok)
	for selection: Variant in [{}, [], "bad", {"plan_id": "TEST.audio.01", "plan_revision": 1.0, "variant_id": "base", "anchor_id": "load.01"}]:
		var changed: Dictionary = context.duplicate(true)
		changed.selection = selection
		assert_false(MANIFEST.resolve_scene_context(changed, registration).ok)
	var changed: Dictionary = context.duplicate(true)
	changed.playhead = 1.0
	assert_false(MANIFEST.resolve_scene_context(changed, registration).ok)
	changed = context.duplicate(true)
	changed.registration_sha256 = "b".repeat(64)
	assert_false(MANIFEST.resolve_scene_context(changed, registration).ok)
	registration["other_registration_definition"] = "changed"
	assert_false(MANIFEST.resolve_scene_context(context, registration).ok)
	assert_eq(context, MANIFEST.make_scene_context(_registration(), "scene.test.b", "receipt.1").value)

func test_old_registration_is_not_reinterpreted_as_scene_audio() -> void:
	for version: int in [1, 2]:
		var registration: Dictionary = _registration()
		registration.schema_version = version
		assert_false(MANIFEST.make_scene_context(registration, "scene.test.b", "receipt.1").ok)


func test_music_bed_requires_version_two_and_one_unambiguous_channel() -> void:
	var catalogue: Dictionary = _catalogue()
	catalogue.plans[0].music = "TEST.audio.asset.01"
	catalogue.plans[0].ambience_asset_id = null
	assert_false(_valid(catalogue), "version 1 keeps its ambience-only contract")
	catalogue.schema_version = 2
	assert_true(_valid(catalogue))
	catalogue.plans[0].ambience_asset_id = "TEST.audio.asset.01"
	assert_false(_valid(catalogue), "two competing beds are not silently combined")
	catalogue.plans[0].ambience_asset_id = null
	for invalid: Variant in [null, {}, "missing", 3]:
		catalogue.plans[0].music = invalid
		assert_false(_valid(catalogue), str(invalid))
	catalogue.plans[0].music = "TEST.audio.asset.01"
	catalogue.assets[0].path = "res://audio/bgm/menu_theme.ogg"
	assert_true(_valid(catalogue), "version 2 admits original shipped music bytes")
	for path: String in ["res://audio/bgm/../menu_theme.ogg", "res://audio/bgm//menu_theme.ogg", "res://audio/bgm/menu_theme.gd", "res://audio/bgm/x\\menu_theme.ogg", "res://audio/other/menu_theme.ogg"]:
		catalogue.assets[0].path = path
		assert_false(_valid(catalogue), path)


func test_music_resolves_to_music_channel_without_new_saved_snapshot_fields() -> void:
	var registration: Dictionary = _registration()
	registration.audio_catalogue.schema_version = 2
	registration.audio_catalogue.plans[0].ambience_asset_id = null
	registration.audio_catalogue.plans[0].music = "TEST.audio.asset.01"
	var made: Dictionary = MANIFEST.make_scene_context(registration, "scene.test.b", "receipt.music")
	assert_true(made.ok)
	var resolved: Dictionary = MANIFEST.resolve_scene_context(made.value, registration)
	assert_true(resolved.ok)
	assert_eq(resolved.value.channel, &"music")
	assert_eq(resolved.value.record.asset.asset_id, "TEST.audio.asset.01")
	assert_eq(resolved.value.load_seconds, 1.0)
	assert_eq(made.value.keys().size(), 5, "persistent snapshot shape is unchanged")
	assert_eq(made.value.schema_version, 1)
	assert_false(made.value.has("channel"))
	registration.audio_catalogue.plans[0].music = "changed"
	assert_false(MANIFEST.resolve_scene_context(made.value, registration).ok)


func test_selected_registration_matches_independent_audio_validation_and_detaches_playback() -> void:
	var scope := preload("res://tests/support/SceneValidationScope.gd").new()
	scope.install(true)
	var fixture := preload("res://tests/support/SceneAudioRegistrationFixture.gd").new()
	var installed: Dictionary = fixture._install_registration()
	assert_true(installed.ok, str(installed))
	if not installed.ok:
		scope.restore()
		return
	var owner := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var selected: Dictionary = owner.scene_contract_tables().bundle
	var detached: Dictionary = selected.duplicate(true)
	var made: Dictionary = MANIFEST.make_scene_context(selected, "scene.test.b", "receipt.1")
	var independent: Dictionary = MANIFEST.make_scene_context(detached, "scene.test.b", "receipt.1")
	assert_true(made.ok, str(made))
	assert_eq(made, independent, "prepared fingerprint and catalogue preserve the independently computed result")
	if made.ok:
		var resolved := MANIFEST.resolve_scene_context(made.value, selected)
		var expected := MANIFEST.resolve_scene_context(made.value, detached)
		assert_true(resolved.ok, str(resolved))
		assert_eq(resolved, expected)
		if resolved.ok:
			resolved.value.record.asset.path = "changed"
			resolved.value.record.plan.revision = 99
			resolved.value.snapshot.selection.anchor_id = "changed"
			assert_eq(selected, detached, "playback data cannot mutate the prepared story")
			assert_eq(MANIFEST.resolve_scene_context(made.value, selected), expected)
		detached.audio_catalogue.plans[0].revision = 2
		assert_false(MANIFEST.resolve_scene_context(made.value, detached).ok,
			"modified arbitrary registration cannot reuse the selected fingerprint")
	scope.restore()

func test_named_presentation_selects_existing_plan_without_entry_binding() -> void:
	var registration := _registration()
	var named := MANIFEST.make_named_presentation_context(registration, "TEST.audio.01", "receipt.1")
	assert_true(named.ok)
	assert_eq(named, MANIFEST.make_scene_context(registration, "scene.test.b", "receipt.1"))
	var resolved := MANIFEST.resolve_scene_context(named.value, registration)
	assert_true(resolved.ok)
	assert_eq(resolved.value.load_seconds, 1.0)
	assert_eq(resolved.value.record.plan.plan_id, "TEST.audio.01")
	var silence := MANIFEST.make_named_presentation_context(registration, "", "receipt.1")
	assert_true(silence.ok)
	assert_null(silence.value.selection)
	assert_null(MANIFEST.resolve_scene_context(silence.value, registration).value.record)
	var missing := MANIFEST.make_named_presentation_context(registration, "missing", "receipt.1")
	assert_false(missing.ok)
	assert_eq(missing.code, &"reading_content_error")
	assert_eq(missing.details.audio_plan_id, "missing")
	assert_true(str(missing.message).contains("missing"))
	assert_false(MANIFEST.make_named_presentation_context(registration, "TEST.audio.01", "").ok)


func test_inline_catalogue_supports_story_assets_gain_and_music_start_on_load() -> void:
	var registration := _registration()
	var catalogue: Dictionary = registration.audio_catalogue
	catalogue.schema_version = 3
	catalogue.assets[0].path = "res://audio/sfx/door_knock.ogg"
	catalogue.assets[0]["gain_db"] = -4.0
	catalogue.plans[0].music = catalogue.plans[0].ambience_asset_id
	catalogue.plans[0].ambience_asset_id = null
	assert_true(_valid(catalogue))
	var context := MANIFEST.make_named_presentation_context(registration, "TEST.audio.01", "admission.inline")
	assert_true(context.ok)
	var resolved := MANIFEST.resolve_scene_context(context.value, registration)
	assert_true(resolved.ok)
	assert_true(resolved.value.inline_audio)
	assert_eq(resolved.value.load_seconds, resolved.value.entrance_seconds)
	assert_eq(resolved.value.record.asset.gain_db, -4.0)
	catalogue.assets[0].gain_db = "loud"
	assert_false(_valid(catalogue), "manually edited gain must be numeric")
