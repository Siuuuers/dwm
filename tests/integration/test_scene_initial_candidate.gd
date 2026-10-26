extends "res://addons/gut/test.gd"
## Current initial reading and normal save admission. Retired assignment and
## creation-recovery proof tests are pinned in canonical-test-disposition.json.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
var fixture: RefCounted
var fixture_ready := false
var document: Dictionary
var context: Dictionary
var bundle: Dictionary

func before_all() -> void:
	fixture = FIXTURE.new()
	var result: Dictionary = fixture.setup(get_tree())
	if result.get("ok", false): result = fixture.start()
	assert_eq(result.get("code"), &"scene_activation_pending", str(result))
	fixture_ready = result.get("code") == &"scene_activation_pending"
	if fixture_ready: fixture.confirm_activation()

func after_all() -> void:
	if fixture != null: fixture.close()

func _prepare() -> bool:
	assert_true(fixture_ready)
	if not fixture_ready: return false
	bundle = MANIFEST.scene_contract_tables().bundle
	var snapshot: Dictionary = fixture.manager.get_latest_stable_checkpoint().value.bundle.snapshot
	document = {"schema_version": 9, "kind": "autosave", "slot_id": null,
		"saved_time": {"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"},
		"current_snapshot": {"checkpoint_kind": "day_start", "snapshot": snapshot.duplicate(true)}, "recovery_journal": []}
	var reading: Dictionary = BRIDGE._build_current_scene_initial_checkpoint(snapshot.scene, bundle)
	assert_true(reading.ok, str(reading))
	if not reading.ok: return false
	context = {"dialogic_checkpoint": reading.value}
	return true

func _validate(value: Dictionary) -> Dictionary:
	return SAVE.validate(value)

func test_registration_without_authored_audio_derives_valid_silence() -> void:
	if not _prepare(): return
	assert_ne(bundle.schema_version, 3)
	var snapshot: Dictionary = document.current_snapshot.snapshot.duplicate(true)
	snapshot["audio_context"] = {"music_context_id": "obsolete-track"}
	var derived: Dictionary = RUN.derive_scene_audio_context(snapshot, bundle)
	assert_true(derived.ok, str(derived))
	if not derived.ok: return
	assert_eq(derived.value, {"ambience_context": {}, "ambience_context_id": "",
		"music_context": {}, "music_context_id": ""})
	var audio: Node = preload("res://autoload/AudioManager.gd").new()
	var accepted: Dictionary = audio._validate_snapshot(derived.value)
	audio.free()
	assert_true(accepted.ok, str(accepted))
	assert_false(document.current_snapshot.snapshot.has("audio_context"), "canonical silence is transient participant input")



func test_configuration_fork_keeps_fresh_mutable_session_state() -> void:
	if not _prepare(): return
	var reading: Dictionary = RUN._validate_scene_reading(document.current_snapshot.snapshot)
	assert_true(reading.ok, str(reading))
	if not reading.ok: return
	var sibling: RefCounted = reading.session._fork_scene_configuration()
	assert_null(sibling.ledger)
	assert_eq(sibling.command_id, "")
	assert_eq(sibling.latest_entry, "")
	assert_eq(sibling.scene_occurrence, "")
	assert_eq(sibling.scene_index, 0)
	assert_eq(sibling.boundary, "between_entries")
	assert_true(sibling.next_operation.is_empty())
	assert_true(sibling.catalogue.is_read_only())
	assert_true(sibling.registry.is_read_only())
	assert_false(is_same(sibling._scene_nodes, reading.session._scene_nodes))
	for nodes: Array in sibling._scene_nodes.values(): assert_true(nodes.is_read_only())
	assert_true(sibling.manifest.is_read_only())
	assert_true(sibling._caption_variants_by_line.is_read_only())
	assert_true(is_same(sibling.manifest, reading.session.manifest), "frozen manifest is shared")
	assert_true(is_same(sibling._caption_variants_by_line, reading.session._caption_variants_by_line), "frozen lookup is shared")
	assert_true(BRIDGE._build_current_scene_initial_checkpoint(document.current_snapshot.snapshot.scene, bundle).ok, "private fork cannot change public reconstruction")


func test_next_public_build_reuses_installed_content_and_ci_checks_physical_edits() -> void:
	if not _prepare(): return
	var source_path := ""
	for entry: Dictionary in bundle.entry_manifest.entries:
		if entry.entry_id == document.current_snapshot.snapshot.scene.entry_id: source_path = entry.locators.en.path
	assert_false(source_path.is_empty())
	if source_path.is_empty(): return
	var original := FileAccess.get_file_as_string(source_path)
	var source := FileAccess.open(source_path, FileAccess.WRITE)
	assert_not_null(source)
	if source == null: return
	source.store_string(original + "\n")
	source.close()
	# A trailing empty line preserves the programme but changes its physical hash.
	# Runtime reuses installed content; the explicit artifact check owns disk edits.
	var rebuilt: Dictionary = BRIDGE._build_current_scene_initial_checkpoint(document.current_snapshot.snapshot.scene, bundle)
	var checked := _validate(document)
	var authored := MANIFEST.validate_scene_registration(bundle)
	source = FileAccess.open(source_path, FileAccess.WRITE)
	assert_not_null(source)
	if source == null: return
	source.store_string(original)
	source.close()
	assert_true(rebuilt.ok, str(rebuilt))
	if rebuilt.ok: assert_eq(rebuilt.value, context.dialogic_checkpoint)
	assert_true(checked.ok, str(checked))
	assert_false(authored.ok, "CI must reject changed physical content")
	var restored: Dictionary = BRIDGE._build_current_scene_initial_checkpoint(document.current_snapshot.snapshot.scene, bundle)
	assert_true(restored.ok, str(restored))
	if restored.ok: assert_eq(restored.value, context.dialogic_checkpoint)
	assert_true(_validate(document).ok)
	assert_true(MANIFEST.validate_scene_registration(bundle).ok, "restored bytes pass the artifact check")


func test_current_frame_must_agree_with_saved_position() -> void:
	if not _prepare(): return
	var changed: Dictionary = document.duplicate(true)
	changed.current_snapshot.snapshot.narrative_checkpoint.frozen_context.transaction_id = "TEST.foreign.saved.frame"
	var reading: Dictionary = RUN._validate_scene_reading(changed.current_snapshot.snapshot)
	assert_false(reading.ok, "compact position must agree with its current frame")
	assert_false(_validate(changed).ok)
	assert_true(_validate(document).ok)

func test_old_assignment_is_ignored_without_changing_saved_progress() -> void:
	if not _prepare(): return
	var historical: Dictionary = document.duplicate(true)
	historical.current_snapshot.snapshot.lifecycle["scene_assignment"] = {"form": "dark", "retired": true}
	historical.current_snapshot.snapshot.gameplay.money = 23
	var admitted: Dictionary = _validate(historical)
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	assert_eq(admitted.value.candidate.current_snapshot.snapshot.gameplay.money, 23)
	assert_false(admitted.value.candidate.current_snapshot.snapshot.lifecycle.has("scene_assignment"))
	assert_true(historical.current_snapshot.snapshot.lifecycle.has("scene_assignment"), "admission does not mutate input")

func test_save_metadata_is_optional_and_does_not_change_progress() -> void:
	if not _prepare(): return
	for metadata: Dictionary in [{}, {"saved_time": null}, {"saved_time": "obsolete"}, {"save_reason": "day_start"}]:
		var changed: Dictionary = document.duplicate(true)
		changed.erase("saved_time")
		changed.merge(metadata)
		var admitted: Dictionary = _validate(changed)
		assert_true(admitted.ok, str(admitted))
		if admitted.ok: assert_eq(admitted.value.candidate.current_snapshot, document.current_snapshot)
