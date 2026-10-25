extends GutTest
## Temporary ordinary-DTL ranges; these captions select no production ending.
const CATALOG := preload("res://scripts/narrative/ScenePassageCatalog.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const REPLAY := preload("res://scripts/application/ending/GalleryReplayOwner.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const ID := "passage.TEST.finish"
const TRANSACTION := "passage:TEST.run:gallery:" + ID

static func _bundle() -> Dictionary:
	return {"caption_registry": {"entries": [{"entry_id": "TEST.scene", "lines": [
		{"line_id": "TEST.before", "text": "TEST before."},
		{"line_id": "TEST.first", "text": "TEST first."},
		{"line_id": "TEST.last", "text": "TEST last."},
		{"line_id": "TEST.after", "text": "TEST after."}]}]},
		"scene_programme": {"entries": [{"entry_id": "TEST.scene", "markers": [
		{"kind": "passage.start", "label": "TEST.start", "marker_id": "TEST.start", "after_line_id": "TEST.before", "payload": {"passage_id": ID}},
		{"kind": "passage.finish", "label": "TEST.finish", "marker_id": "TEST.finish", "after_line_id": "TEST.last", "payload": {"passage_id": ID}}]}]}}

class Bridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var starts: Array[String] = []
	var active := ""
	var catalogue := {}
	func configure_reached_replay(_profile: Object) -> Dictionary: return {"ok": true}
	func get_scene_passage(id: String) -> Dictionary:
		return {"ok": true, "value": catalogue[id].duplicate(true)} if catalogue.has(id) else {"ok": false}
	func replay_scene_passage(id: String) -> Dictionary:
		starts.append(id)
		active = id
		return {"ok": true, "receipt": {"playback_token": "TEST.replay"}}
	func cancel_reached_replay(id: String) -> Dictionary:
		if active != id: return {"ok": false}
		finish("cancelled")
		return {"ok": true}
	func finish(outcome: String = "completed") -> void:
		var id := active
		active = ""
		reached_replay_finished.emit({"signature_id": id, "playback_token": "TEST.replay", "outcome": outcome})

func _fixture() -> Dictionary:
	var ops := OPS.new()
	var storage := STORAGE.new("passage-gallery/root", ops)
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(storage).ok)
	var gate := GATE.new()
	assert_true(profile.configure_mutation_gate(gate).ok)
	return {"profile": profile, "gate": gate, "ops": ops, "storage": storage}

func _finish(fixture: Dictionary) -> Dictionary:
	var lease: Dictionary = fixture.gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	var result: Dictionary = fixture.profile.record_scene_passage_completion(ID, TRANSACTION)
	assert_true(fixture.gate.release(&"causal_transaction", lease.value.token).ok)
	return result

func test_passage_catalogue_selects_only_between_the_two_markers_and_detaches() -> void:
	var bundle := _bundle()
	var result := CATALOG.inspect(bundle)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.records[ID].line_ids, ["TEST.first", "TEST.last"])
	assert_eq(result.value.records[ID].start_label, "TEST.start")
	assert_eq(result.value.records[ID].finish_label, "TEST.finish")
	bundle.caption_registry.entries[0].lines[1].text = "changed"
	assert_eq(result.value.records[ID].captions[0].text, "TEST first.")

func test_unpaired_reversed_duplicate_and_interrupted_ranges_refuse() -> void:
	var bundle := _bundle()
	bundle.scene_programme.entries[0].markers.pop_back()
	assert_false(CATALOG.inspect(bundle).ok)
	bundle = _bundle()
	bundle.scene_programme.entries[0].markers[1].after_line_id = "TEST.before"
	assert_false(CATALOG.inspect(bundle).ok)
	bundle = _bundle()
	bundle.scene_programme.entries.append(bundle.scene_programme.entries[0].duplicate(true))
	assert_false(CATALOG.inspect(bundle).ok)
	bundle = _bundle()
	bundle.scene_programme.entries[0].markers.append({"kind": "challenge.playable", "after_line_id": "TEST.first"})
	assert_false(CATALOG.inspect(bundle).ok)
	for id: Variant in ["passage.", "ending.unselected", "passage.bad id", "passage.bad/id", 1, null]:
		assert_false(CATALOG.valid_id(id), str(id))

func test_finish_profile_write_is_gated_retryable_and_survives_reload_and_gallery_clear() -> void:
	var fixture := _fixture()
	var profile: Node = fixture.profile
	assert_false(profile.has_gallery_unlock(ID))
	assert_false(profile.record_scene_passage_completion(ID, TRANSACTION).ok)
	assert_false(profile.unlock_ending(ID, TRANSACTION).ok, "legacy generic unlock is not passage Finish")
	assert_true(_finish(fixture).ok)
	assert_eq(profile.get_gallery_discovery_snapshot().value.ending_ids, [ID])
	var revision: int = profile.get_profile_revision()
	assert_true(_finish(fixture).ok)
	assert_eq(profile.get_profile_revision(), revision, "retry does not rewrite Profile")
	var restored: Node = autofree(PROFILE.new())
	assert_true(restored.initialize(fixture.storage).ok)
	assert_true(restored.has_gallery_unlock(ID))
	assert_true(restored.has_completed_ending())
	assert_true(restored.reset_gallery().ok)
	assert_false(restored.has_gallery_unlock(ID))
	assert_true(restored.has_completed_ending(), "completion milestone outlives Clear Gallery")
	assert_true(SCHEMA.validate(restored.get_profile_snapshot()).ok)

func test_failed_finish_profile_write_does_not_unlock_and_can_retry() -> void:
	var fixture := _fixture()
	var before: Dictionary = fixture.profile.get_profile_snapshot()
	var bytes: Dictionary = fixture.ops.snapshot_persisted()
	fixture.ops.fail_after(fixture.ops.operation_count() + 1)
	assert_false(_finish(fixture).ok)
	assert_eq(fixture.profile.get_profile_snapshot(), before)
	assert_eq(fixture.ops.snapshot_persisted(), bytes)
	assert_true(_finish(fixture).ok)
	assert_true(fixture.profile.has_gallery_unlock(ID))

func test_gallery_requires_finish_and_routes_bounded_replay_without_profile_writes() -> void:
	var fixture := _fixture()
	var bridge := Bridge.new()
	bridge.catalogue = CATALOG.inspect(_bundle()).value.records
	var replay := REPLAY.new()
	assert_true(replay.configure(fixture.profile, bridge).ok)
	assert_false(replay.get_variants(ID).ok)
	assert_false(replay.begin(ID).ok)
	assert_eq(bridge.starts, [])
	assert_true(_finish(fixture).ok)
	assert_eq(replay.get_variants(ID).value.records, [{"signature_id": ID}])
	assert_eq(replay.passage_title(ID, "en"), "Ending 1")
	var before: Dictionary = fixture.profile.get_profile_snapshot()
	var bytes: Dictionary = fixture.ops.snapshot_persisted()
	assert_true(replay.begin(ID).ok)
	assert_true(replay.is_playing())
	bridge.reached_replay_finished.emit({"signature_id": ID, "playback_token": "stale"})
	assert_true(replay.is_playing(), "stale completion cannot retire the active replay")
	bridge.finish()
	assert_false(replay.is_playing())
	assert_true(replay.begin(ID).ok)
	assert_true(replay.close().ok)
	assert_false(replay.is_playing())
	assert_eq(fixture.profile.get_profile_snapshot(), before)
	assert_eq(fixture.ops.snapshot_persisted(), bytes)

func test_native_passage_registration_refuses_jump_that_skips_a_caption() -> void:
	var fixture := preload("res://tests/support/ScenePassageRegistrationFixture.gd").new()
	var manifest := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var valid: Dictionary = fixture._registration_bundle()
	assert_true(valid.ok, str(valid))
	if not valid.ok: return
	var accepted: Dictionary = manifest.validate_scene_registration(valid.value)
	assert_true(accepted.ok, str(accepted))
	fixture.source_path = "res://tests/fixtures/dialogic/scene_passage_jump_refused.dtl"
	var jumped: Dictionary = fixture._registration_bundle()
	assert_true(jumped.ok, str(jumped))
	if not jumped.ok: return
	var rejected: Dictionary = manifest.validate_scene_registration(jumped.value)
	assert_false(rejected.ok, "Gallery cannot show a caption skipped by native playback")
	assert_eq(rejected.get("message"), "passage entry must be linear")
