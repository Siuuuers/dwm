extends GutTest
const FIXTURE := preload("res://tests/support/DialogueLibraryFixture.gd")
const CATALOGUE := preload("res://scripts/narrative/DialogueLibraryCatalogue.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")

func before_each() -> void:
	assert_true(FIXTURE.install().ok)

func after_each() -> void:
	assert_true(CATALOGUE.configure([], [], {}).ok)

func _fixture() -> Dictionary:
	var files := FILES.new()
	var storage := STORAGE.new("TEST.dialogue-library", files)
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(storage).ok)
	return {"profile": profile, "files": files, "storage": storage}

func _read(profile: Node, beat: Dictionary = {}) -> Dictionary:
	if beat.is_empty(): beat = FIXTURE.beat()
	return profile.mark_caption_variant_witnessed(beat, FIXTURE.registry(beat), FIXTURE.CHECKPOINT)

func test_discovery_is_durable_and_queries_and_repeated_reads_do_not_write() -> void:
	var f := _fixture()
	assert_eq(f.profile.get_dialogue_library(), {"checkpoints": [], "witnesses": {}})
	assert_true(_read(f.profile).ok)
	assert_eq(f.profile.get_dialogue_library(), FIXTURE.discovery())
	var before: Dictionary = f.files.snapshot_persisted()
	var revision: int = f.profile.get_profile_revision()
	var discovery: Dictionary = f.profile.get_dialogue_library()
	discovery.checkpoints.clear()
	assert_eq(f.profile.get_dialogue_library(), FIXTURE.discovery(), "callers receive detached data")
	assert_true(_read(f.profile).ok)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.files.snapshot_persisted(), before)
	var restarted: Node = autofree(PROFILE.new())
	assert_true(restarted.initialize(STORAGE.new("TEST.dialogue-library", FILES.new(before))).ok)
	assert_eq(restarted.get_dialogue_library(), FIXTURE.discovery())

func test_reset_is_separate_and_old_read_history_never_refills_without_new_reading() -> void:
	var f := _fixture()
	assert_true(_read(f.profile).ok)
	assert_true(f.profile.unlock_ending("ending.alone", "TEST.library:ending").ok)
	var before: Dictionary = f.profile.get_profile_snapshot()
	watch_signals(f.profile)
	assert_true(f.profile.reset_dialogue_library().ok)
	assert_signal_emit_count(f.profile, "dialogue_library_changed", 1)
	var after: Dictionary = f.profile.get_profile_snapshot()
	before.erase("dialogue_library")
	after.erase("dialogue_library")
	assert_eq(after, before, "library reset changes neither Skip, Artwork, endings nor preferences")
	assert_eq(CATALOGUE.reached_passages(f.profile.get_dialogue_library()), [])
	assert_true(f.profile.is_caption_variant_witnessed(FIXTURE.beat()))
	assert_true(_read(f.profile).ok, "already-read text must rediscover after explicit reset")
	assert_eq(f.profile.get_dialogue_library(), FIXTURE.discovery())
	assert_signal_emit_count(f.profile, "dialogue_library_changed", 2)
	for method: String in ["reset_visited_history", "reset_gallery", "reset_preferences", "reset_controls"]:
		assert_true(f.profile.call(method).ok)
		assert_eq(f.profile.get_dialogue_library(), FIXTURE.discovery(), method)
	assert_true(f.profile.reset_entire_profile().ok)
	assert_eq(f.profile.get_dialogue_library(), {"checkpoints": [], "witnesses": {}})

func test_same_line_variant_and_thought_need_their_own_visible_read() -> void:
	var f := _fixture()
	assert_true(_read(f.profile).ok)
	var rows: Array = CATALOGUE.reached_passages(f.profile.get_dialogue_library())
	assert_false(rows[0].entries[1].read)
	assert_false(rows[0].entries[2].read)
	assert_true(_read(f.profile, FIXTURE.beat("read", true)).ok)
	rows = CATALOGUE.reached_passages(f.profile.get_dialogue_library())
	assert_true(rows[0].entries[1].read)
	assert_false(rows[0].entries[2].read)
	assert_true(_read(f.profile, FIXTURE.beat("short")).ok)
	rows = CATALOGUE.reached_passages(f.profile.get_dialogue_library())
	assert_true(rows[0].entries[2].read)
	assert_false(rows[0].entries[3].read)

func test_read_history_without_checkpoint_is_not_backfilled_and_restore_cannot_rewind() -> void:
	var f := _fixture()
	var beat := FIXTURE.beat()
	assert_true(f.profile.mark_caption_variant_witnessed(beat, FIXTURE.registry(beat)).ok)
	var older: Dictionary = f.profile.get_profile_snapshot()
	assert_eq(f.profile.get_dialogue_library(), {"checkpoints": [], "witnesses": {}})
	assert_true(_read(f.profile).ok)
	assert_false(f.profile.apply_restore_silent({"profile": older}).ok)
	assert_eq(f.profile.get_dialogue_library(), FIXTURE.discovery())
	var legacy := SCHEMA.make_defaults()
	legacy.erase("dialogue_library")
	legacy.visited_line_ids = [beat.line_id]
	legacy.witnessed_caption_variants[FIXTURE.key(beat)] = beat
	var normalized: Dictionary = SCHEMA.validate(legacy)
	assert_true(normalized.ok)
	if normalized.ok: assert_eq(normalized.value.dialogue_library, {"checkpoints": [], "witnesses": {}})

func test_write_real_profile_for_fresh_process() -> void:
	assert_false(OS.get_environment("DWM_TEST_ROOT").is_empty(), "isolated cloud root required")
	var root := ProjectSettings.globalize_path("user://TEST.dialogue-library-process")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(STORAGE.new(root)).ok)
	assert_true(_read(profile).ok)
	assert_eq(profile.get_dialogue_library(), FIXTURE.discovery())
