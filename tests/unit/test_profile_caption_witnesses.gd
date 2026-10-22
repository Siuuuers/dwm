extends "res://addons/gut/test.gd"

const LEDGER := preload("res://scripts/profile/CaptionWitnessLedger.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const STORE_ROOT := "caption-witness-profile"

class CountingStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var writes := 0
	var failure: Dictionary = {}
	func _init(file_ops: RefCounted) -> void:
		super("caption-witness-profile", file_ops)
	func write_atomic(path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		writes += 1
		if not failure.is_empty(): return failure.duplicate(true)
		return super.write_atomic(path, text, validator, keep_backup)

func _beat(variant: String = "a", revision: String = "fixture-r1") -> Dictionary:
	return {"beat_id": "fixture.caption", "line_id": "fixture.caption.line",
		"owning_entry_id": "fixture.caption.entry", "presentation_signature": {
			"content_revision": revision, "variant_id": variant, "tone": "sweet"}}

func _registry(beat: Dictionary) -> Dictionary:
	return {"kind": "narrative_caption_registry", "schema_version": 1, "beats": [beat.duplicate(true)]}

func _key(beat: Dictionary) -> String:
	var described := LEDGER.describe(beat)
	assert_true(described.ok, str(described))
	return str(described.value.witness_id)

func _manager(storage: RefCounted) -> Node:
	var manager := MANAGER.new()
	autofree(manager)
	var initialized: Dictionary = manager.initialize(storage)
	assert_true(initialized.get("ok", false), str(initialized))
	return manager

func _fixture(seed: Dictionary = {}) -> Dictionary:
	var ops := OPS.new(seed)
	var storage := CountingStorage.new(ops)
	return {"ops": ops, "storage": storage, "manager": _manager(storage)}

func test_exact_descriptor_and_canonical_order_define_membership_without_occurrence_ids() -> void:
	var f := _fixture()
	var beat := _beat()
	var before: Dictionary = f.manager.get_profile_snapshot()
	assert_false(f.manager.is_caption_variant_witnessed(beat))
	assert_eq(f.manager.get_profile_snapshot(), before, "membership is a pure query")
	assert_true(f.manager.mark_caption_variant_witnessed(beat, _registry(beat)).ok)
	assert_true(f.manager.is_line_visited(beat.line_id), "one commit retains base-line compatibility")
	assert_false(f.manager.is_caption_variant_witnessed(_beat("b")), "same base line does not prove another variant")
	assert_false(f.manager.is_caption_variant_witnessed(_beat("a", "fixture-r2")), "revised content is unseen")
	var reordered := {"presentation_signature": {"tone": "sweet", "variant_id": "a", "content_revision": "fixture-r1"},
		"owning_entry_id": beat.owning_entry_id, "line_id": beat.line_id, "beat_id": beat.beat_id}
	assert_eq(_key(reordered), _key(beat))
	assert_true(f.manager.is_caption_variant_witnessed(reordered), "object insertion order is not a variant")
	for field: String in ["run_id", "attempt_id", "publication_id"]:
		var occurrence := beat.duplicate(true)
		occurrence[field] = "causal-only"
		assert_false(LEDGER.describe(occurrence).ok, "occurrence fields cannot enter the semantic descriptor")

func test_mark_is_durable_detached_and_duplicate_is_write_and_signal_free() -> void:
	var f := _fixture()
	var beat := _beat()
	watch_signals(f.manager)
	var writes: int = f.storage.writes
	assert_true(f.manager.mark_caption_variant_witnessed(beat, _registry(beat)).ok)
	assert_eq(f.storage.writes, writes + 1)
	assert_signal_emit_count(f.manager, "visited_history_changed", 1)
	assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 1)
	var saved: Dictionary = f.manager.get_profile_snapshot()
	var revision: int = f.manager.get_profile_revision()
	assert_true(f.manager.mark_caption_variant_witnessed(beat, _registry(beat)).unchanged)
	assert_eq(f.storage.writes, writes + 1)
	assert_eq(f.manager.get_profile_revision(), revision)
	assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 1)
	beat.presentation_signature.tone = "dark"
	assert_eq(f.manager.get_profile_snapshot(), saved, "caller mutation cannot alter the witness")
	var restarted := _manager(STORAGE.new(STORE_ROOT, OPS.new(f.ops.snapshot_persisted())))
	assert_eq(restarted.get_profile_snapshot(), saved)
	assert_true(restarted.is_caption_variant_witnessed(_beat()))

func test_second_variant_publishes_exact_change_after_atomic_profile_adoption() -> void:
	var f := _fixture()
	assert_true(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok)
	var signals: Array = []
	f.manager.caption_variant_witness_changed.connect(func(id: String, witnessed: bool) -> void:
		signals.append({"id": id, "witnessed": witnessed, "profile": f.manager.get_profile_snapshot(),
			"disk": f.ops.snapshot_persisted()}))
	watch_signals(f.manager)
	var b := _beat("b")
	assert_true(f.manager.mark_caption_variant_witnessed(b, _registry(b)).ok)
	assert_eq(signals.size(), 1)
	assert_eq(signals[0].id, _key(b))
	assert_true(signals[0].witnessed)
	assert_eq(signals[0].profile, f.manager.get_profile_snapshot())
	assert_eq(signals[0].disk, f.ops.snapshot_persisted())
	assert_signal_emit_count(f.manager, "visited_history_changed", 0, "the base line did not change")
	assert_eq(f.manager.get_profile_snapshot().visited_line_ids, [b.line_id])
	assert_eq(f.manager.get_profile_snapshot().witnessed_caption_variants.size(), 2)

func test_registry_and_descriptor_refusals_do_not_write_even_after_base_line_visit() -> void:
	var f := _fixture()
	assert_true(f.manager.configure_line_registry({"reply_lines": [{"line_id": _beat().line_id}]}).ok)
	assert_true(f.manager.mark_line_visited(_beat().line_id).ok)
	assert_false(f.manager.is_caption_variant_witnessed(_beat()))
	var before: Dictionary = f.manager.get_profile_snapshot()
	var writes: int = f.storage.writes
	assert_eq(f.manager.mark_caption_variant_witnessed(_beat("b"), _registry(_beat())).get("code"), &"unregistered_caption_variant")
	var invalid := _registry(_beat())
	invalid.beats.append({"line_id": "incomplete"})
	assert_eq(f.manager.mark_caption_variant_witnessed(_beat(), invalid).get("code"), &"invalid_caption_witness_registry")
	assert_false(f.manager.mark_caption_variant_witnessed({}, _registry(_beat())).ok)
	var integer := _beat()
	integer.presentation_signature.number = 1
	var floating := integer.duplicate(true)
	floating.presentation_signature.number = 1.0
	assert_false(f.manager.mark_caption_variant_witnessed(floating, _registry(integer)).ok,
		"exact registered bytes retain scalar types")
	assert_eq(f.storage.writes, writes)
	assert_eq(f.manager.get_profile_snapshot(), before)

func test_schema_checks_keys_descriptors_and_base_line_consistency() -> void:
	var profile := SCHEMA.make_defaults()
	var beat := _beat()
	profile.visited_line_ids = [beat.line_id]
	profile.witnessed_caption_variants[_key(beat)] = beat
	assert_true(SCHEMA.validate(profile).ok)
	for malformed: Variant in [null, [], {"wrong-hash": beat}, {_key(beat): _beat("b")}, {_key(beat): {}}]:
		var candidate := profile.duplicate(true)
		candidate.witnessed_caption_variants = malformed
		assert_false(SCHEMA.validate(candidate).ok)
	var missing_base := profile.duplicate(true)
	missing_base.visited_line_ids = []
	assert_false(SCHEMA.validate(missing_base).ok)
	var missing_field := profile.duplicate(true)
	missing_field.erase("witnessed_caption_variants")
	assert_false(SCHEMA.validate(missing_field).ok, "v10 never silently fills a missing exact ledger")

func test_v9_upgrade_preserves_old_facts_and_grants_no_exact_credit() -> void:
	var old := SCHEMA.make_defaults()
	old.schema_version = 9
	old.erase("witnessed_caption_variants")
	old.visited_line_ids = [_beat().line_id]
	old.preferences.audio.music_volume = 0.37
	var before := old.duplicate(true)
	var upgraded := MIGRATION.prepare_document(old)
	assert_true(upgraded.ok, str(upgraded))
	if not upgraded.ok: return
	assert_eq(upgraded.value.schema_version, 10)
	assert_eq(upgraded.migration_id, &"profile_v9_to_v10")
	assert_eq(upgraded.value.witnessed_caption_variants, {})
	assert_eq(upgraded.value.visited_line_ids, old.visited_line_ids)
	assert_eq(upgraded.value.preferences, old.preferences)
	assert_eq(old, before)
	var extra := old.duplicate(true)
	extra.witnessed_caption_variants = {}
	assert_false(MIGRATION.prepare_document(extra).ok, "v9 remains an exact source format")
	var f := _fixture({STORE_ROOT + "/profile.json": WRITER.stringify(old).value})
	assert_eq(f.manager.get_profile_snapshot(), upgraded.value)
	assert_false(f.manager.is_caption_variant_witnessed(_beat()))
	assert_eq(_manager(STORAGE.new(STORE_ROOT, OPS.new(f.ops.snapshot_persisted()))).get_profile_snapshot(), upgraded.value)

func test_generic_commits_and_restore_cannot_erase_exact_history() -> void:
	var f := _fixture()
	assert_true(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok)
	var older: Dictionary = f.manager.get_profile_snapshot()
	assert_true(f.manager.mark_caption_variant_witnessed(_beat("b"), _registry(_beat("b"))).ok)
	var before: Dictionary = f.manager.get_profile_snapshot()
	var writes: int = f.storage.writes
	assert_true(SCHEMA.validate(older).ok)
	assert_eq(f.manager.commit_prepared_profile(older).get("code"), &"caption_witness_rewind")
	assert_eq(f.manager.apply_restore_silent({"profile": older}).get("code"), &"caption_witness_rewind")
	assert_eq(f.storage.writes, writes)
	assert_eq(f.manager.get_profile_snapshot(), before)
	assert_true(f.manager.apply_restore_silent({"profile": before}).ok)
	assert_true(f.manager.rollback_restore_silent({"profile": before}).ok, "compensation retains its exact captured Profile")
	assert_eq(f.manager.get_profile_snapshot(), before)

func test_only_visited_or_entire_reset_clears_exact_history() -> void:
	var f := _fixture()
	assert_true(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok)
	for method: String in ["reset_preferences", "reset_controls", "reset_gallery"]:
		assert_true(f.manager.call(method).ok)
		assert_true(f.manager.is_caption_variant_witnessed(_beat()), method)
	var stale: int = f.manager.get_profile_revision()
	assert_true(f.manager.mark_caption_variant_witnessed(_beat("b"), _registry(_beat("b"))).ok)
	assert_false(f.manager.reset_visited_history(stale).ok)
	watch_signals(f.manager)
	assert_true(f.manager.reset_visited_history(f.manager.get_profile_revision()).ok)
	assert_eq(f.manager.get_profile_snapshot().witnessed_caption_variants, {})
	assert_eq(f.manager.get_profile_snapshot().visited_line_ids, [])
	assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 2)
	assert_true(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok)
	assert_true(f.manager.reset_entire_profile().ok)
	assert_false(f.manager.is_caption_variant_witnessed(_beat()))

func test_duplicate_mark_still_obeys_mutation_custody_and_fatal_latch() -> void:
	var f := _fixture()
	assert_true(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok)
	var gate := GATE.new()
	assert_true(f.manager.configure_mutation_gate(gate).ok)
	var held: Dictionary = gate.acquire(&"restore")
	assert_true(held.ok)
	var writes: int = f.storage.writes
	assert_eq(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).get("code"), &"MUTATION_ACTIVE")
	assert_eq(f.storage.writes, writes)
	assert_true(gate.release(&"restore", held.value.token).ok)
	f.storage.failure = {"ok": false, "code": &"indeterminate_commit", "fatal": true}
	assert_eq(f.manager.mark_caption_variant_witnessed(_beat("b"), _registry(_beat("b"))).get("code"), &"indeterminate_commit")
	f.storage.failure.clear()
	writes = f.storage.writes
	assert_eq(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).get("code"), &"indeterminate_commit")
	assert_eq(f.manager.mark_caption_variant_witnessed(_beat("b"), _registry(_beat("b"))).get("code"), &"indeterminate_commit")
	assert_eq(f.storage.writes, writes)
	assert_false(f.manager.is_caption_variant_witnessed(_beat("b")))

func test_real_atomic_file_failures_recover_one_coherent_profile_and_allow_retry() -> void:
	var initial := WRITER.stringify(SCHEMA.make_defaults())
	assert_true(initial.ok)
	var seed := {STORE_ROOT + "/profile.json": initial.value}
	var baseline := _fixture(seed)
	var start: int = baseline.ops.operation_count()
	assert_true(baseline.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok)
	var operations: int = baseline.ops.operation_count() - start
	assert_gt(operations, 0)
	var recovered_failures := 0
	for offset: int in range(1, operations + 1):
		var f := _fixture(seed)
		var before: Dictionary = f.manager.get_profile_snapshot()
		watch_signals(f.manager)
		f.ops.fail_after(f.ops.operation_count() + offset)
		var result: Dictionary = f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat()))
		if not result.ok:
			recovered_failures += 1
			assert_eq(f.manager.get_profile_snapshot(), before, "failed mutation has no live adoption")
			assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 0)
			if not result.get("fatal", false):
				assert_true(f.manager.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok,
					"consumed single FileOps fault permits exact live retry")
		var restarted := _manager(STORAGE.new(STORE_ROOT, OPS.new(f.ops.snapshot_persisted())))
		assert_true(SCHEMA.validate(restarted.get_profile_snapshot()).ok)
		assert_eq(restarted.is_caption_variant_witnessed(_beat()), restarted.is_line_visited(_beat().line_id),
			"restart cannot split the exact witness and its base visit")
		if result.ok: assert_true(restarted.is_caption_variant_witnessed(_beat()))
		assert_true(restarted.mark_caption_variant_witnessed(_beat(), _registry(_beat())).ok)
		assert_true(restarted.is_caption_variant_witnessed(_beat()))
	assert_gt(recovered_failures, 0, "the sweep must actually exercise refused persistence")


class MergeFaultFiles extends "res://tests/support/FakeFileOps.gd":
	var refuse_writes := false
	var refuse_cleanup := false
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if refuse_writes and "/profile.json" in path:
			_record(&"write_bytes", path)
			return _injected_failure()
		return super.write_bytes(path, bytes)
	func remove_path(path: String) -> Dictionary:
		if refuse_cleanup and path.ends_with("/profile.json.txn.json"):
			_record(&"remove_path", path)
			return _injected_failure()
		return super.remove_path(path)

# Merge fixtures exercise real FileOps refusals, not a synthetic storage result.
func _merge_fixture() -> Dictionary:
	var ops := MergeFaultFiles.new()
	var storage := CountingStorage.new(ops)
	return {"ops": ops, "storage": storage, "manager": _manager(storage)}

func _merge_beat(id: String = "one", variant: String = "a") -> Dictionary:
	return {"beat_id": "fixture." + id, "line_id": "fixture.line." + id,
		"owning_entry_id": "fixture.entry", "presentation_signature": {
			"content_revision": "TEST-r1", "variant_id": variant}}

func _merge_registry(beats: Array[Dictionary]) -> Dictionary:
	return {"kind": "narrative_caption_registry", "schema_version": 1, "beats": beats.duplicate(true)}

func _merge_before(f: Dictionary) -> Dictionary:
	return {"profile": f.manager.get_profile_snapshot(), "revision": f.manager.get_profile_revision(),
		"bytes": f.ops.snapshot_persisted(), "writes": f.storage.writes, "operations": f.ops.operation_count()}

func _merge_assert_live_unchanged(f: Dictionary, before: Dictionary) -> void:
	assert_eq(f.manager.get_profile_snapshot(), before.profile)
	assert_eq(f.manager.get_profile_revision(), before.revision)

func _merge_assert_no_io(f: Dictionary, before: Dictionary) -> void:
	_merge_assert_live_unchanged(f, before)
	assert_eq(f.ops.snapshot_persisted(), before.bytes)
	assert_eq(f.storage.writes, before.writes)
	assert_eq(f.ops.operation_count(), before.operations)

func test_atomic_union_is_one_commit_detached_and_changes_only_two_history_fields() -> void:
	var f := _merge_fixture()
	assert_true(f.manager.set_preference(&"preferences.audio.music_volume", 0.37).ok)
	assert_true(f.manager.unlock_ending("ending.alone", "history-merge:fixture").ok)
	var prior: Array[Dictionary] = [_merge_beat("prior")]
	assert_true(f.manager.mark_caption_variant_witnessed(prior[0], _merge_registry(prior)).ok)
	var beats: Array[Dictionary] = [_merge_beat(), _merge_beat("two"), _merge_beat()]
	var registry_beats: Array[Dictionary] = [_merge_beat(), _merge_beat("two")]
	var registry := _merge_registry(registry_beats)
	var before := _merge_before(f)
	var publications: Array[Dictionary] = []
	f.manager.caption_variant_witness_changed.connect(func(_id: String, _value: bool) -> void:
		publications.append({"profile": f.manager.get_profile_snapshot(), "bytes": f.ops.snapshot_persisted()}))
	var result: Dictionary = f.manager.merge_caption_history(beats, registry, before.revision)
	assert_true(result.ok, str(result))
	assert_eq(result.value, {"history_added": true})
	assert_eq(f.storage.writes, before.writes + 1, "the whole batch shares one Profile transaction")
	assert_eq(f.manager.get_profile_revision(), before.revision + 1)
	var saved: Dictionary = f.manager.get_profile_snapshot()
	assert_eq(saved.visited_line_ids.size(), 3)
	assert_eq(saved.witnessed_caption_variants.size(), 3)
	assert_true(f.manager.is_caption_variant_witnessed(prior[0]))
	assert_true(f.manager.is_caption_variant_witnessed(_merge_beat()))
	assert_true(f.manager.is_caption_variant_witnessed(_merge_beat("two")))
	var unchanged_fields := saved.duplicate(true)
	var previous_fields: Dictionary = before.profile.duplicate(true)
	for field: String in ["visited_line_ids", "witnessed_caption_variants"]:
		unchanged_fields.erase(field)
		previous_fields.erase(field)
	assert_eq(unchanged_fields, previous_fields, "preferences, discovery and all unrelated Profile facts are exact")
	assert_eq(publications.size(), 2, "duplicate input is not another witness publication")
	for publication: Dictionary in publications:
		assert_eq(publication.profile, saved, "no observer sees a partial batch")
		assert_eq(publication.bytes, f.ops.snapshot_persisted(), "all publications follow durable adoption")
	beats[0].presentation_signature.variant_id = "caller mutation"
	registry.beats.clear()
	result.value.history_added = false
	assert_eq(f.manager.get_profile_snapshot(), saved)
	var restarted := _manager(STORAGE.new(STORE_ROOT, OPS.new(f.ops.snapshot_persisted())))
	assert_eq(restarted.get_profile_snapshot(), saved)

func test_duplicate_and_empty_batches_are_write_signal_and_revision_free() -> void:
	var f := _merge_fixture()
	var beats: Array[Dictionary] = [_merge_beat(), _merge_beat("two")]
	var registry := _merge_registry(beats)
	assert_true(f.manager.merge_caption_history(beats, registry).ok)
	watch_signals(f.manager)
	var before := _merge_before(f)
	var duplicate: Dictionary = f.manager.merge_caption_history(beats, registry, before.revision)
	assert_true(duplicate.ok)
	assert_true(duplicate.unchanged)
	assert_eq(duplicate.value, {"history_added": false})
	var empty: Array[Dictionary] = []
	var result: Dictionary = f.manager.merge_caption_history(empty, {}, before.revision)
	assert_true(result.ok)
	assert_true(result.unchanged)
	assert_eq(result.value, {"history_added": false})
	_merge_assert_no_io(f, before)
	assert_signal_emit_count(f.manager, "visited_history_changed", 0)
	assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 0)

func test_new_exact_variant_of_visited_line_commits_without_history_added_status() -> void:
	var f := _merge_fixture()
	var first: Array[Dictionary] = [_merge_beat()]
	assert_true(f.manager.merge_caption_history(first, _merge_registry(first)).value.history_added)
	var next: Array[Dictionary] = [_merge_beat("one", "b")]
	var before := _merge_before(f)
	watch_signals(f.manager)
	var result: Dictionary = f.manager.merge_caption_history(next, _merge_registry(next), before.revision)
	assert_true(result.ok)
	assert_eq(result.value, {"history_added": false}, "new exact credit is not a newly visited base line")
	assert_false(result.get("unchanged", false))
	assert_eq(f.storage.writes, before.writes + 1)
	assert_true(f.manager.is_caption_variant_witnessed(first[0]))
	assert_true(f.manager.is_caption_variant_witnessed(next[0]))
	assert_eq(f.manager.get_profile_snapshot().visited_line_ids, before.profile.visited_line_ids)
	assert_signal_emit_count(f.manager, "visited_history_changed", 0)
	assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 1)

func test_invalid_late_member_or_registry_rejects_entire_batch_before_storage() -> void:
	var f := _merge_fixture()
	var registered: Array[Dictionary] = [_merge_beat(), _merge_beat("two")]
	var registry := _merge_registry(registered)
	var before := _merge_before(f)
	var unregistered: Array[Dictionary] = [_merge_beat(), _merge_beat("two", "absent")]
	assert_eq(f.manager.merge_caption_history(unregistered, registry).get("code"), &"unregistered_caption_variant")
	var malformed: Array[Dictionary] = [_merge_beat(), {"line_id": "raw caller ID"}]
	assert_false(f.manager.merge_caption_history(malformed, registry).ok)
	var invalid_registry := registry.duplicate(true)
	invalid_registry.beats.append({"line_id": "incomplete"})
	assert_eq(f.manager.merge_caption_history(registered, invalid_registry).get("code"), &"invalid_caption_witness_registry")
	_merge_assert_no_io(f, before)
	assert_false(f.manager.is_caption_variant_witnessed(_merge_beat()), "the valid prefix of a refused batch was not adopted")

func test_stale_revision_and_mutation_custody_refuse_even_empty_and_duplicate_batches() -> void:
	var f := _merge_fixture()
	var beats: Array[Dictionary] = [_merge_beat()]
	var registry := _merge_registry(beats)
	var stale: int = f.manager.get_profile_revision()
	assert_true(f.manager.merge_caption_history(beats, registry, stale).ok)
	var before := _merge_before(f)
	var empty: Array[Dictionary] = []
	assert_eq(f.manager.merge_caption_history(beats, registry, stale).get("code"), &"profile_revision_changed")
	assert_eq(f.manager.merge_caption_history(empty, {}, stale).get("code"), &"profile_revision_changed")
	var fresh := MANAGER.new()
	autofree(fresh)
	assert_eq(fresh.merge_caption_history(empty, {}).get("code"), &"not_initialized")
	var gate := GATE.new()
	assert_true(f.manager.configure_mutation_gate(gate).ok)
	var held: Dictionary = gate.acquire(&"restore")
	assert_true(held.ok)
	assert_eq(f.manager.merge_caption_history(beats, registry).get("code"), &"MUTATION_ACTIVE")
	assert_eq(f.manager.merge_caption_history(empty, {}).get("code"), &"MUTATION_ACTIVE")
	_merge_assert_no_io(f, before)
	assert_true(gate.release(&"restore", held.value.token).ok)
	assert_true(f.manager.merge_caption_history(beats, registry).unchanged)

func test_proven_write_refusal_preserves_whole_profile_and_allows_one_fresh_batch() -> void:
	var f := _merge_fixture()
	var beats: Array[Dictionary] = [_merge_beat(), _merge_beat("two")]
	var registry := _merge_registry(beats)
	var before := _merge_before(f)
	watch_signals(f.manager)
	f.ops.refuse_writes = true
	var refused: Dictionary = f.manager.merge_caption_history(beats, registry, before.revision)
	assert_false(refused.ok)
	assert_false(refused.get("fatal", false))
	_merge_assert_live_unchanged(f, before)
	assert_eq(f.ops.snapshot_persisted(), before.bytes)
	assert_signal_emit_count(f.manager, "visited_history_changed", 0)
	assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 0)
	f.ops.refuse_writes = false
	var writes: int = f.storage.writes
	var retried: Dictionary = f.manager.merge_caption_history(beats, registry, before.revision)
	assert_true(retried.ok, str(retried))
	assert_true(retried.value.history_added)
	assert_eq(f.storage.writes, writes + 1)
	assert_true(f.manager.is_caption_variant_witnessed(beats[0]))
	assert_true(f.manager.is_caption_variant_witnessed(beats[1]))

func test_indeterminate_promotion_preserves_live_profile_and_fences_all_further_batches() -> void:
	var f := _merge_fixture()
	var old: Array[Dictionary] = [_merge_beat("old")]
	assert_true(f.manager.merge_caption_history(old, _merge_registry(old)).ok)
	var beats: Array[Dictionary] = [_merge_beat(), _merge_beat("two")]
	var registry := _merge_registry(beats)
	var before := _merge_before(f)
	watch_signals(f.manager)
	f.ops.refuse_cleanup = true
	var result: Dictionary = f.manager.merge_caption_history(beats, registry, before.revision)
	assert_false(result.ok)
	assert_eq(result.get("code"), &"indeterminate_commit")
	_merge_assert_live_unchanged(f, before)
	assert_signal_emit_count(f.manager, "visited_history_changed", 0)
	assert_signal_emit_count(f.manager, "caption_variant_witness_changed", 0)
	var bytes: Dictionary = f.ops.snapshot_persisted()
	assert_true(bytes.has(STORE_ROOT + "/profile.json.txn.json"))
	var durable: Dictionary = JSON.parse_string(bytes[STORE_ROOT + "/profile.json"].get_string_from_utf8())
	assert_eq(durable.visited_line_ids.size(), 3, "promotion installed the entire candidate, despite uncertain cleanup")
	assert_eq(durable.witnessed_caption_variants.size(), 3)
	f.ops.refuse_cleanup = false
	var fenced := _merge_before(f)
	var empty: Array[Dictionary] = []
	assert_eq(f.manager.merge_caption_history(old, _merge_registry(old)).get("code"), &"indeterminate_commit")
	assert_eq(f.manager.merge_caption_history(empty, {}).get("code"), &"indeterminate_commit")
	assert_eq(f.manager.merge_caption_history(beats, registry).get("code"), &"indeterminate_commit")
	assert_eq(f.manager.set_preference(&"preferences.audio.music_volume", 0.3).get("code"), &"indeterminate_commit")
	_merge_assert_no_io(f, fenced)
