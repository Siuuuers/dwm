extends "res://addons/gut/test.gd"
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PATH := "res://tests/fixtures/dialogic/_scene_compiler_cache_probe.dtl"
const COUNTED_PATH := "res://tests/fixtures/dialogic/_scene_compiler_cache_probe.counted_timeline"
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const SCOPE := preload("res://tests/support/SceneValidationScope.gd")
const READING := preload("res://tests/support/SceneDayReadingFixture.gd")
const SHARED_SOURCE := "label first\n\\TEST first. #id:line.cache.one\nlabel first.marker\nreturn\nlabel second\n\\TEST second. #id:line.cache.two\nreturn\n"
const CALLABLES := ["first", "second"]


class CountingTimelineLoader extends ResourceFormatLoader:
	var loads := 0

	func _get_recognized_extensions() -> PackedStringArray:
		return PackedStringArray(["counted_timeline"])

	func _get_resource_type(_path: String) -> String:
		return "Resource"

	func _handles_type(type: StringName) -> bool:
		return ClassDB.is_parent_class(type, "Resource")

	func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
		loads += 1
		var text := FileAccess.get_file_as_string(path)
		if text.begins_with("not a timeline"): return Resource.new()
		var timeline := DialogicTimeline.new()
		timeline.from_text(text)
		return timeline

var _counting_loader: CountingTimelineLoader
var _translation: Translation
var _translation_enabled_before: Variant
var _translation_setting_existed := false
var _locale_before := ""
var _scope: RefCounted
var _prepared_before: Dictionary

func before_each() -> void:
	_prepared_before = SESSION._prepared_scene_configuration
	SESSION._prepared_scene_configuration = {}
	_translation_setting_existed = ProjectSettings.has_setting("dialogic/translation/enabled")
	_translation_enabled_before = ProjectSettings.get_setting("dialogic/translation/enabled", false)
	_locale_before = TranslationServer.get_locale()
	ProjectSettings.set_setting("dialogic/translation/enabled", false)

func _write(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()

func after_each() -> void:
	if _scope != null:
		_scope.restore()
		_scope = null
	SESSION._prepared_scene_configuration = _prepared_before
	if _translation != null:
		TranslationServer.remove_translation(_translation)
		_translation = null
	TranslationServer.set_locale(_locale_before)
	ProjectSettings.set_setting("dialogic/translation/enabled", _translation_enabled_before if _translation_setting_existed else null)
	DirAccess.remove_absolute(PATH)
	ADAPTER._scene_compile_cache.erase(PATH)
	DirAccess.remove_absolute(COUNTED_PATH)
	ADAPTER._scene_compile_cache.erase(COUNTED_PATH)
	if _counting_loader != null:
		ResourceLoader.remove_resource_format_loader(_counting_loader)
		_counting_loader = null

func _write_counted(text: String) -> void:
	var file := FileAccess.open(COUNTED_PATH, FileAccess.WRITE)
	assert_not_null(file)
	file.store_string(text)
	file.close()

func test_resource_type_is_checked_once_per_physical_revision_across_entries() -> void:
	_counting_loader = CountingTimelineLoader.new()
	ResourceLoader.add_resource_format_loader(_counting_loader, true)
	var original := "label first\n\\TEST first. #id:line.cache.one\nreturn\nlabel second\n\\TEST second. #id:line.cache.two\nreturn\n"
	_write_counted(original)
	var first: Dictionary = ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"])
	assert_true(first.ok, "supported timeline loaders are not restricted to the dtl extension")
	assert_true(ADAPTER.compile_scene_programme(COUNTED_PATH, "second", ["first", "second"]).ok)
	assert_eq(ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"]), first)
	assert_eq(_counting_loader.loads, 1, "separate entries and repeat calls share the physical type check")
	_write_counted(original.replace("TEST first.", "TEST changed."))
	var changed: Dictionary = ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"])
	assert_true(changed.ok)
	assert_eq(_counting_loader.loads, 2, "changed physical bytes require a new loader check")
	if first.ok and changed.ok: assert_ne(first.value.content_sha256, changed.value.content_sha256)
	_write_counted("not a timeline")
	var refused: Dictionary = ADAPTER.compile_scene_programme(COUNTED_PATH, "first", ["first", "second"])
	assert_false(refused.ok)
	assert_eq(refused.code, &"scene_programme_unavailable")
	assert_eq(_counting_loader.loads, 3, "a replacement of the wrong resource type is rejected")

func test_compiled_values_are_detached_and_follow_physical_source_and_arguments() -> void:
	var original := "label cache\n\\TEST first. #id:line.cache.one\nreturn\n"
	_write(original)
	var first: Dictionary = ADAPTER.compile_scene_programme(PATH, "cache", ["cache"])
	assert_true(first.ok)
	if not first.ok: return
	var pristine: Dictionary = first.duplicate(true)
	first.value.nodes.clear()
	assert_eq(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]), pristine,
		"caller mutation cannot poison a later proof")
	var changed_markers: Dictionary = ADAPTER.compile_scene_programme(PATH, "cache", ["cache"],
		[{"label": "missing", "marker_id": "missing"}])
	assert_false(changed_markers.ok, "marker arguments are not interchangeable")
	assert_false(ADAPTER.compile_scene_programme(PATH, "cache", []).ok,
		"callable labels still authorize the selected entry")
	_write(original.replace("TEST first.", "TEST changed."))
	var changed: Dictionary = ADAPTER.compile_scene_programme(PATH, "cache", ["cache"])
	assert_true(changed.ok)
	if not changed.ok: return
	assert_ne(changed.value.content_sha256, pristine.value.content_sha256)
	assert_ne(changed.value.program_sha256, pristine.value.program_sha256,
		"changed bytes compile fresh even while ResourceLoader retains the old resource")
	_write("label cache\n\\TEST missing stable id.\nreturn\n")
	assert_false(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]).ok,
		"malformed replacement cannot reuse previously valid output")
	_write(original)
	assert_eq(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]), pristine)
	DirAccess.remove_absolute(PATH)
	assert_false(ADAPTER.compile_scene_programme(PATH, "cache", ["cache"]).ok,
		"deleted source cannot reuse a valid cache")

func _registration_compile(entry: String, scope: Dictionary, markers: Array = [],
		callables: Array = CALLABLES) -> Dictionary:
	return ADAPTER._compile_scene_programme_in_registration(PATH, entry, callables, markers, scope)

func test_shared_source_preserves_each_entry_graph_native_indices_hashes_and_detachment() -> void:
	_write(SHARED_SOURCE)
	var marker := {"label": "first.marker", "marker_id": "first.control", "kind": "scene.transition"}
	var first: Dictionary = ADAPTER.compile_scene_programme(PATH, "first", CALLABLES, [marker])
	var second: Dictionary = ADAPTER.compile_scene_programme(PATH, "second", CALLABLES)
	assert_true(first.ok)
	assert_true(second.ok)
	if not first.ok or not second.ok: return
	assert_eq(first.value.native_indices, [1, 2, 3], "held marker remains at its actual native event")
	assert_eq(second.value.native_indices, [5, 6], "second entry retains full-file native indices")
	assert_eq(first.value.nodes, [{"kind": "caption", "line_id": "line.cache.one", "next": 1},
		{"kind": "control", "marker_id": "first.control"}, {"kind": "completion"}])
	assert_eq(second.value.nodes, [{"kind": "caption", "line_id": "line.cache.two", "next": 1},
		{"kind": "completion"}])
	assert_eq(first.value.content_sha256, SHARED_SOURCE.sha256_text())
	assert_eq(second.value.content_sha256, first.value.content_sha256)
	assert_ne(first.value.program_sha256, second.value.program_sha256)
	# Establish public API expectations, then exercise new entry projections in one scope.
	ADAPTER._scene_compile_cache.erase(PATH)
	var scope := {}
	var shared_first := _registration_compile("first", scope, [marker])
	assert_eq(shared_first, first)
	assert_eq(_registration_compile("second", scope), second)
	shared_first.value.nodes.clear()
	shared_first.value.events.clear()
	assert_eq(_registration_compile("first", scope, [marker]), first, "returned arrays remain detached")
	var alternate_marker := marker.duplicate(true)
	alternate_marker.marker_id = "alternate.control"
	var alternate := _registration_compile("first", scope, [alternate_marker])
	assert_true(alternate.ok)
	if alternate.ok:
		assert_eq(alternate.value.nodes[1].marker_id, "alternate.control", "parsed source cannot retain another entry's marker projection")
		assert_eq(alternate.value.program_sha256, first.value.program_sha256, "marker identity does not change authored event bytes")
	var wider := _registration_compile("first", scope, [], ["first"])
	assert_true(wider.ok)
	if wider.ok:
		assert_eq(wider.value.native_indices, [1, 3, 5, 6], "callable labels determine the selected entry boundary")
		assert_ne(wider.value.program_sha256, first.value.program_sha256)
	assert_false(_registration_compile("first", scope, [], []).ok, "a prior parse cannot authorize a non-callable entry")

func test_invalid_sibling_is_refused_only_when_selected_from_shared_source() -> void:
	_write(SHARED_SOURCE.replace("TEST second. #id:line.cache.two", "TEST missing stable ID."))
	var scope := {}
	assert_true(_registration_compile("first", scope).ok, "unselected invalid text does not invalidate a separate entry")
	var invalid := _registration_compile("second", scope)
	assert_false(invalid.ok, "shared parsing does not skip entry-specific validation")
	assert_eq(invalid.code, &"scene_text_invalid")
	assert_false(_registration_compile("first", scope, [{"label": "missing", "marker_id": "missing"}]).ok,
		"each projection still checks its own marker labels")

func test_registration_scope_observes_changed_and_deleted_physical_source() -> void:
	_write(SHARED_SOURCE)
	var scope := {}
	var first := _registration_compile("first", scope)
	assert_true(first.ok)
	var changed_source := SHARED_SOURCE.replace("TEST second.", "TEST replacement.")
	_write(changed_source)
	var changed := _registration_compile("second", scope)
	assert_true(changed.ok)
	if changed.ok:
		assert_eq(changed.value.content_sha256, changed_source.sha256_text())
		assert_eq(changed.value.events[1].text, "TEST replacement.")
		assert_ne(changed.value.content_sha256, first.value.content_sha256)
	_write("label second\n\\TEST malformed replacement.\nreturn\n")
	assert_false(_registration_compile("second", scope).ok, "changed malformed bytes cannot reuse the earlier parse")
	DirAccess.remove_absolute(PATH)
	assert_false(_registration_compile("first", scope).ok, "deleted source cannot be supplied by the scope")

func test_translation_changes_are_fresh_even_with_the_same_registration_scope() -> void:
	_write(SHARED_SOURCE)
	var scope := {}
	var original := _registration_compile("first", scope)
	assert_true(original.ok)
	ProjectSettings.set_setting("dialogic/translation/enabled", true)
	_translation = Translation.new()
	_translation.set_locale("en")
	_translation.add_message("Text/line.cache.one/text", "TEST translated once.")
	TranslationServer.add_translation(_translation)
	TranslationServer.set_locale("en")
	var translated := _registration_compile("first", scope)
	assert_true(translated.ok)
	if not translated.ok: return
	assert_eq(translated.value.events[1].text, "TEST translated once.")
	_translation.add_message("Text/line.cache.one/text", "TEST translated again.")
	var refreshed := _registration_compile("first", scope)
	assert_true(refreshed.ok)
	if not refreshed.ok: return
	assert_eq(refreshed.value.events[1].text, "TEST translated again.")
	assert_eq(refreshed.value.content_sha256, translated.value.content_sha256)
	assert_ne(refreshed.value.program_sha256, translated.value.program_sha256,
		"unchanged physical bytes cannot authenticate an obsolete translation")

func test_separate_registration_validations_recheck_physical_bytes_and_keep_approved_hashes() -> void:
	var bundle: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/dialogic/scene_reading_registration.json")).value
	var source := FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_day_terminal.dtl")
	_write(source)
	for entry: Dictionary in bundle.entry_manifest.entries: entry.locators.en.path = PATH
	var original_bundle := bundle.duplicate(true)
	assert_true(MANIFEST.validate_scene_registration(bundle).ok,
		"all three shared-file entries must retain the checked-in programme and content hashes")
	assert_eq(bundle, original_bundle, "validation does not rewrite the caller's registration")
	_write(source + "\n# changed physical revision\n")
	var changed := MANIFEST.validate_scene_registration(bundle)
	assert_false(changed.ok, "a separate call must not reuse old physical content authentication")
	assert_eq(changed.get("message"), "programme hash", "changed bytes reach physical content authentication")
	_write(source)
	assert_true(MANIFEST.validate_scene_registration(bundle).ok, "restored bytes validate after a failed call")
	DirAccess.remove_absolute(PATH)
	var deleted := MANIFEST.validate_scene_registration(bundle)
	assert_false(deleted.ok, "a separate call cannot validate a deleted source")
	assert_eq(deleted.get("code"), &"scene_programme_unavailable", "deleted bytes reach the physical source check")

func test_all_shipped_entries_match_independent_cold_compilation_exactly() -> void:
	var bundle: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(
		"res://data/manifests/scene_story_registration.json")).value
	var entries: Array = bundle.entry_manifest.entries
	assert_eq(entries.size(), bundle.entry_manifest.entry_count, "this comparison covers the complete declared registration")
	var labels: Array = []
	var programmes := {}
	var paths := {}
	for row: Dictionary in bundle.scene_programme.entries: programmes[row.entry_id] = row
	for entry: Dictionary in entries:
		labels.append(entry.entry_id)
		paths[entry.locators.en.path] = true
	for path: String in paths: ADAPTER._scene_compile_cache.erase(path)

	var independent := {}
	for entry: Dictionary in entries:
		var row: Dictionary = programmes[entry.entry_id]
		var compiled: Dictionary = ADAPTER.compile_scene_programme(entry.locators.en.path,
			entry.entry_id, labels, row.markers)
		assert_true(compiled.ok, entry.entry_id + ": independent compilation")
		if compiled.ok:
			assert_eq(compiled.value.content_sha256, row.content_sha256, entry.entry_id + ": registered content hash")
			assert_eq(compiled.value.program_sha256, row.program_sha256, entry.entry_id + ": registered programme hash")
		independent[entry.entry_id] = compiled
	# Discard compiled-result hits before the registration-local pass.
	for path: String in paths: ADAPTER._scene_compile_cache.erase(path)
	var scope := {}
	for entry: Dictionary in entries:
		var compiled: Dictionary = ADAPTER._compile_scene_programme_in_registration(
			entry.locators.en.path, entry.entry_id, labels, programmes[entry.entry_id].markers, scope)
		assert_eq(compiled, independent[entry.entry_id],
			entry.entry_id + ": exact events, graph, labels, native indices and hashes")
	for path: String in paths: ADAPTER._scene_compile_cache.erase(path)

func _install_reading_source() -> Dictionary:
	_scope = SCOPE.new()
	_scope.install(true)
	var bundle: Dictionary = STRICT.parse_object(FileAccess.get_file_as_string(READING.REGISTRATION)).value
	_write(FileAccess.get_file_as_string("res://tests/fixtures/dialogic/scene_day_terminal.dtl"))
	for entry: Dictionary in bundle.entry_manifest.entries: entry.locators.en.path = PATH
	assert_true(MANIFEST.configure_test_scene_registration(bundle).ok)
	return bundle

func test_prepared_configuration_shares_frozen_data_but_not_reading_progress() -> void:
	var bundle := _install_reading_source()
	var first := SESSION.new()
	var second := SESSION.new()
	assert_true(first.configure_scene().ok)
	assert_true(second.configure_scene().ok)
	for field: String in ["manifest", "catalogue", "registry", "_scene_nodes", "_scene_bundle", "_caption_variants_by_line"]:
		assert_true(is_same(first.get(field), second.get(field)), field + " has one immutable owner")
		assert_true(first.get(field).is_read_only(), field)
	assert_true(first._scene_nodes[READING.A].is_read_only())
	assert_true(first._scene_nodes[READING.A][0].is_read_only())
	assert_true(first.begin_scene(READING.TOKEN).ok)
	assert_true(second.begin_scene(READING.TOKEN).ok)
	assert_false(is_same(first.ledger, second.ledger))
	assert_true(READING.enter(first, READING.A, "test:first").ok)
	assert_true(READING.enter(second, READING.A, "test:second").ok)
	var retained := READING.checkpoint(second)
	assert_true(READING.advance_detached(first).ok)
	assert_eq(READING.checkpoint(second), retained, "advancing one session cannot advance the other")
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries: labels.append(entry.entry_id)
	var programme: Dictionary = bundle.scene_programme.entries[0]
	var compiled := ADAPTER.compile_scene_programme(PATH, programme.entry_id, labels, programme.markers)
	assert_true(compiled.ok)
	if not compiled.ok: return
	var pristine: Dictionary = compiled.duplicate(true)
	compiled.value.nodes[0]["caller_mutation"] = true
	compiled.value.nodes.clear()
	assert_eq(ADAPTER.compile_scene_programme(PATH, programme.entry_id, labels, programme.markers), pristine,
		"freezing prepared data must not freeze or alias public compiler results")
	assert_eq(first._scene_nodes[programme.entry_id], pristine.value.nodes)
	assert_eq(second._scene_nodes[programme.entry_id], pristine.value.nodes)

func test_prepared_configuration_trusts_installed_process_but_strict_validation_reads_edits() -> void:
	var bundle := _install_reading_source()
	var original := FileAccess.get_file_as_string(PATH)
	assert_true(SESSION.new().configure_scene().ok)
	var prepared: Dictionary = SESSION._prepared_scene_configuration
	_write(original + "\n# changed source\n")
	assert_true(SESSION.new().configure_scene().ok, "prepared process content is immutable")
	assert_true(is_same(SESSION._prepared_scene_configuration, prepared))
	assert_false(MANIFEST.validate_scene_registration(bundle).ok,
		"the separate release validator must still detect changed physical content")

func test_prepared_configuration_bypasses_translation_enabled_compilation() -> void:
	var bundle := _install_reading_source()
	var canonical := SESSION.new()
	assert_true(canonical.configure_scene().ok)
	ProjectSettings.set_setting("dialogic/translation/enabled", true)
	var translated := SESSION.new()
	assert_true(translated.configure_scene().ok)
	assert_false(is_same(canonical._scene_nodes, translated._scene_nodes), "translation mode recompiles independently")
	var line: Dictionary = bundle.caption_registry.entries[0].lines[0]
	_translation = Translation.new()
	_translation.set_locale("en")
	_translation.add_message("Text/%s/text" % line.line_id, "TEST changed translation.")
	TranslationServer.add_translation(_translation)
	TranslationServer.set_locale("en")
	assert_true(SESSION.new().configure_scene().ok, "runtime reads translated prose without re-proving the shipped hash")
	ProjectSettings.set_setting("dialogic/translation/enabled", false)
	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	assert_true(is_same(restored._scene_nodes, canonical._scene_nodes))

func test_prepared_configuration_follows_selected_registration_identity() -> void:
	var bundle := _install_reading_source()
	var first := SESSION.new()
	assert_true(first.configure_scene().ok)
	var inner := SCOPE.new()
	inner.install(true)
	assert_true(MANIFEST.configure_test_scene_registration(bundle).ok)
	var replacement := SESSION.new()
	assert_true(replacement.configure_scene().ok)
	assert_eq(first.fingerprint, replacement.fingerprint, "equal content is not equal selected-registration lifetime")
	assert_false(is_same(first._scene_bundle, replacement._scene_bundle))
	assert_false(is_same(first._scene_nodes, replacement._scene_nodes))
	inner.restore()
	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	assert_true(is_same(first._scene_bundle, restored._scene_bundle))
	assert_eq(first._scene_nodes, restored._scene_nodes)

func test_runtime_compiler_reuses_frozen_selected_mapping_without_rereading_source() -> void:
	var bundle := _install_reading_source()
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries: labels.append(entry.entry_id)
	var programme: Dictionary = bundle.scene_programme.entries[0]
	var first := ADAPTER.compile_runtime_scene_programme(PATH, programme.entry_id, labels, programme.markers)
	assert_true(first.ok)
	if not first.ok: return
	assert_true(first.is_read_only())
	assert_true(first.value.nodes.is_read_only())
	_write("not the installed programme")
	var reused := ADAPTER.compile_runtime_scene_programme(PATH, programme.entry_id, labels, programme.markers)
	assert_true(is_same(first, reused), "same process keeps its installed immutable programme")
	assert_false(ADAPTER.compile_scene_programme(PATH, programme.entry_id, labels, programme.markers).ok,
		"explicit artifact checking still reads physical input")
