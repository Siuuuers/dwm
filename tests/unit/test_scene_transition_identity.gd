extends "res://addons/gut/test.gd"
## Nonwired semantic integration of real identity/storage owners. G's table
## registration is TEST content; this does not activate the production save schema.
const FIXTURE := preload("res://tests/support/SceneTransitionIdentityFixture.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
var fixture: RefCounted

func before_each() -> void:
	fixture = FIXTURE.new()

func _ready_fixture() -> bool:
	var result: Dictionary = fixture.setup()
	assert_true(result.get("ok", false), "real scene fixture setup: " + str(result))
	return result.get("ok", false)

func _ok(result: Dictionary, context: String) -> bool:
	assert_true(result.get("ok", false), context + ": " + str(result))
	return result.get("ok", false)

func test_original_completion_is_exact_nine_projections_and_returned_detached() -> void:
	if not _ready_fixture(): return
	var provenance: Dictionary = fixture.original_completion.provenance
	var inspected: Dictionary = CONTRACT.inspect_scene(fixture.event, fixture.bundle)
	if not _ok(inspected, "registered event"): return
	var expected: Array = []
	var fields := {"command_id": fixture.event.command_id, "content_sha256": "a".repeat(64),
		"event_digest": inspected.value.digest,
		"marker_program_fingerprint": FIXTURE.hash_value(fixture.bundle.scene_programme.entries[0]),
		"reading_anchor_sha256": FIXTURE.hash_value(fixture.anchor),
		"registration_fingerprint": FIXTURE.hash_value(fixture.bundle), "role": "scene_day_complete",
		"source_scene_occurrence": "TEST.occurrence", "successor_id": "TEST.target"}
	for key: String in fields: expected.append(FIXTURE.projection(key, fields[key]))
	expected.sort()
	assert_eq(provenance.source_ids, expected)
	assert_eq(provenance.ordinal, 0)
	assert_eq(provenance.parent_receipt_id, fixture.event.issuer_receipt.receipt_id)
	assert_eq(provenance.child_kind, "scene_day_completion")
	var result: Dictionary = fixture.source()
	if not _ok(result, "durable original source"): return
	assert_eq(result.value.source_resolution_receipt, fixture.original_completion)
	result.value.source_resolution_receipt.receipt_id = "TEST.mutated"
	assert_ne(fixture.original_completion.receipt_id, "TEST.mutated")

func test_completed_checkpoint_in_memory_is_insufficient_and_locator_is_bound() -> void:
	if not _ready_fixture(): return
	var captured: Dictionary = fixture.root.capture()
	if not _ok(captured, "root capture"): return
	assert_false(REMAPPER.scene_day_advance_source(fixture.lifecycle, fixture.command_receipts,
		fixture.bundle, captured.value, {}).get("ok", false))
	for key: String in ["document_sha256", "bundle_id", "checkpoint_id", "slot_id"]:
		var bad: Dictionary = fixture.durable_source.duplicate(true)
		bad.locator[key] = "f".repeat(64)
		assert_false(REMAPPER.scene_day_advance_source(fixture.lifecycle, fixture.command_receipts,
			fixture.bundle, captured.value, bad).get("ok", false), "forged " + key)
	var bad: Dictionary = fixture.durable_source.duplicate(true)
	bad.document_text = "{}"
	assert_false(REMAPPER.scene_day_advance_source(fixture.lifecycle, fixture.command_receipts,
		fixture.bundle, captured.value, bad).get("ok", false))

func test_saved_plan_command_map_and_exact_five_member_source_identity_are_required() -> void:
	if not _ready_fixture(): return
	var original: Dictionary = fixture.lifecycle.duplicate(true)
	fixture.lifecycle.active_resolution_plan.source.identity.day = 1
	assert_false(fixture.source().get("ok", false), "legacy day cannot enter scene I")
	fixture.lifecycle = original.duplicate(true)
	fixture.lifecycle.active_resolution_plan.source.event_command_id = "TEST.missing"
	assert_false(fixture.source().get("ok", false), "canonical map lookup is mandatory")
	fixture.lifecycle = original.duplicate(true)
	fixture.lifecycle.active_resolution_plan.stages[0].state = "pending"
	assert_false(fixture.source().get("ok", false), "checkpoint must complete")
	fixture.lifecycle = original.duplicate(true)
	fixture.lifecycle.active_resolution_plan.stages[1].state = "completed"
	assert_false(fixture.source().get("ok", false), "completed allocation is not a new source")
	fixture.lifecycle = original.duplicate(true)
	fixture.command_receipts[fixture.event.command_id].scene_event.result.resolution_receipt.receipt_id = "TEST.forged"
	assert_false(fixture.source().get("ok", false), "unreproducible C0")

func test_restore_derives_exact_four_quoted_projections_and_active_retry_reuses_allocation() -> void:
	if not _ready_fixture(): return
	var selected: Dictionary = FIXTURE.identity(fixture.lifecycle)
	var original_map: Dictionary = fixture.command_receipts.duplicate(true)
	var original_source: Dictionary = fixture.lifecycle.active_resolution_plan.source.duplicate(true)
	if not _ok(fixture.restore_selected(selected), "committed selected Load"): return
	var source: Dictionary = fixture.source()
	if not _ok(source, "restored source"): return
	var request: Dictionary = source.value.derivation_request
	var expected: Array = [FIXTURE.projection("original_completion_sha256", FIXTURE.hash_value(fixture.original_completion)),
		FIXTURE.projection("restore_provenance_sha256", FIXTURE.hash_value(fixture.lifecycle.restore_provenance)),
		FIXTURE.projection("role", "scene_day.advance_continuation"),
		FIXTURE.projection("source_identity_sha256", FIXTURE.hash_value(FIXTURE.identity(fixture.lifecycle)))]
	expected.sort()
	assert_eq(request.source_ids, expected)
	assert_eq(request.ordinal, 1)
	assert_eq(request.parent_receipt_id, fixture.event.issuer_receipt.receipt_id)
	var completion: Dictionary = fixture.completion(source)
	if not _ok(completion, "real restored child"): return
	var first: Dictionary = fixture.advance(completion.value)
	if not _ok(first, "first restored allocation"): return
	fixture.lifecycle.active_resolution_plan.stages[1].state = "active"
	var retry_source: Dictionary = fixture.source()
	if not _ok(retry_source, "active stage retry"): return
	assert_eq(retry_source, source)
	var retry: Dictionary = fixture.advance(completion.value)
	if not _ok(retry, "retry allocation"): return
	assert_eq(retry, first)
	assert_eq(fixture.command_receipts, original_map)
	assert_eq(fixture.lifecycle.active_resolution_plan.source, original_source)

func test_repeated_selected_load_and_load_of_restored_checkpoint_have_distinct_children() -> void:
	if not _ready_fixture(): return
	var selected: Dictionary = FIXTURE.identity(fixture.lifecycle)
	if not _ok(fixture.restore_selected(selected), "first Load"): return
	var first: Dictionary = fixture.completion(fixture.source())
	if not _ok(first, "first child"): return
	var allocated: Dictionary = fixture.advance(first.value)
	if not _ok(allocated, "first allocation"): return
	if not _ok(fixture.restore_selected(selected), "second Load same selected source"): return
	var second: Dictionary = fixture.completion(fixture.source())
	if not _ok(second, "second child"): return
	assert_ne(first.value.receipt_id, second.value.receipt_id)
	var second_allocation: Dictionary = fixture.advance(second.value)
	if not _ok(second_allocation, "second allocation"): return
	assert_ne(allocated.value.day_advance_identity_receipt.allocation_key,
		second_allocation.value.day_advance_identity_receipt.allocation_key)
	# Select a checkpoint already on a restored branch. Its source is not I0.
	if not _ok(fixture.persist_source(), "persist restored checkpoint"): return
	selected = FIXTURE.identity(fixture.lifecycle)
	if not _ok(fixture.restore_selected(selected), "Load restored checkpoint"): return
	var third: Dictionary = fixture.completion(fixture.source())
	if not _ok(third, "third child"): return
	assert_ne(third.value.receipt_id, second.value.receipt_id)

func test_changed_identity_requires_real_committed_restore_and_rejects_forged_proof() -> void:
	if not _ready_fixture(): return
	var selected: Dictionary = FIXTURE.identity(fixture.lifecycle)
	fixture.lifecycle.branch_id = "TEST.unissued"
	assert_false(fixture.source().get("ok", false))
	fixture.lifecycle.branch_id = selected.branch_id
	if not _ok(fixture.restore_selected(selected), "restore"): return
	var proof: Dictionary = fixture.lifecycle.restore_provenance.duplicate(true)
	for key: String in ["source_branch_id", "source_causal_day_instance", "restore_transaction_id", "transaction_remap_sha256"]:
		fixture.lifecycle.restore_provenance = proof.duplicate(true)
		fixture.lifecycle.restore_provenance[key] = "TEST.forged"
		assert_false(fixture.source().get("ok", false), "forged " + key)
	fixture.lifecycle.restore_provenance = proof
	var captured: Dictionary = fixture.root.capture()
	if not _ok(captured, "capture root"): return
	captured.value.allocation_receipts.erase(proof.restore_transaction_id)
	assert_false(REMAPPER.scene_day_advance_source(fixture.lifecycle, fixture.command_receipts,
		fixture.bundle, captured.value, fixture.durable_source).get("ok", false), "uncommitted restore")

func test_same_scene_source_refuses_second_valid_completion_for_different_target() -> void:
	if not _ready_fixture(): return
	var first: Dictionary = fixture.advance(fixture.original_completion)
	if not _ok(first, "original completion allocation"): return
	var other_bundle: Dictionary = fixture.bundle.duplicate(true)
	other_bundle.targets[0].target_id = "TEST.other-target"
	other_bundle.scene_programme.entries[0].markers[0].payload.target_id = "TEST.other-target"
	var other_event: Dictionary = fixture.event.duplicate(true)
	other_event.payload.target_id = "TEST.other-target"
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id")
	if not _ok(issued, "other genuine event parent"): return
	other_event.command_id = issued.value.issuer_receipt.token
	other_event.issuer_receipt = issued.value.issuer_receipt
	var request: Dictionary = CONTRACT.scene_completion_request(other_event, fixture.anchor, other_bundle)
	if not _ok(request, "other valid target completion request"): return
	var child: Dictionary = fixture.issuer.derive_child(request.value)
	if not _ok(child, "other genuine completion"): return
	var before: Dictionary = fixture.root.capture()
	if not _ok(before, "before refusal"): return
	var conflict: Dictionary = fixture.advance({"receipt_id": child.value.child_id, "provenance": child.value.provenance})
	assert_false(conflict.get("ok", false))
	assert_eq(conflict.get("code"), &"causal_day_advance_identity_conflict")
	assert_eq(fixture.root.capture(), before, "conflict cannot consume counter or append allocation")
