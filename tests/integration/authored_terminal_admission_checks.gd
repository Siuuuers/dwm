extends "res://tests/integration/authored_week_child.gd"
## Run against an isolated copy of the genuine post-replay root, with slot 2 intact.
## This checks admission boundaries, not physical playback or uninterrupted route coverage.
const TERMINAL_CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const TERMINAL_TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")
const TERMINAL_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const OTHER_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const TERMINAL_FROZEN := preload("res://scripts/narrative/FrozenRunContext.gd")
const TERMINAL_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
var _profile_bytes := PackedByteArray()

# A public semantic delegate deliberately cannot select the actual-owner shortcut.
class FreshSemanticOwner:
	extends RefCounted
	var delegate: Object
	var calls := 0
	func validate_scene_snapshot_semantics(snapshot: Dictionary, bundle: Dictionary) -> Dictionary:
		calls += 1
		return delegate.validate_scene_snapshot_semantics(snapshot, bundle)

# Keep the genuine issuer script and root proofs, but replace the matching owner group during the
# first Frozen callback. The new group agrees internally, so only a retained
# pre-call identity check can distinguish it from the original group.
class SwitchingRoot:
	extends RefCounted
	var delegate: Object
	var switch_owner: Callable
	var switches := 0
	func _maybe_switch() -> void:
		if switches != 0 or not switch_owner.is_valid(): return
		var frozen_checkpoint := false
		var schema_reading := false
		for frame: Dictionary in get_stack():
			if frame.get("function") == "validate_reading_checkpoint" \
					and String(frame.get("source", "")).ends_with("/FrozenRunContext.gd"):
				frozen_checkpoint = true
			if frame.get("function") == "_validate_scene_reading" \
					and String(frame.get("source", "")).ends_with("/RunSnapshotSchema.gd"):
				schema_reading = true
		if frozen_checkpoint and schema_reading:
			switches += 1
			switch_owner.call()
	func verify_receipt(receipt: Dictionary, purpose: StringName) -> Dictionary:
		var result: Dictionary = delegate.verify_receipt(receipt, purpose)
		_maybe_switch()
		return result
	func prepare_allocation(request: Dictionary) -> Dictionary:
		var result: Dictionary = delegate.prepare_allocation(request)
		_maybe_switch()
		return result
	func capture() -> Dictionary:
		var result: Dictionary = delegate.capture()
		_maybe_switch()
		return result

func _selected(record: Dictionary, receipts: Dictionary, contacts: Dictionary) -> Dictionary:
	return TERMINAL_CONTRACT.validate_selected_scene_terminal_admission(record,
		game._identity_issuer, receipts, saves, contacts)

func _restore_profile_bytes() -> bool:
	if _profile_bytes.is_empty(): return true
	var file := FileAccess.open("user://profile.json", FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(_profile_bytes)
	file.close()
	return FileAccess.get_file_as_bytes("user://profile.json") == _profile_bytes

func after_all() -> void:
	assert_true(_restore_profile_bytes(), "restore original Profile bytes even after an early test return")

func _measured_run(source: Dictionary, label: String) -> Dictionary:
	assert_true(TERMINAL_TIMING.begin_scope(label, "ENDING", "PRIMARY_PENDING", 0))
	var result: Dictionary = TERMINAL_SCHEMA.validate(source)
	var counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(result.get("ok", false)))
	return {"result": result, "counts": counts}

# Each public call proves current state. The supported production root is synchronous
# and read-only during terminal reconstruction; injected mid-call mutation is not its contract.
func _root_between_call_checks(source: Dictionary) -> Dictionary:
	var before := source.duplicate(true)
	var live_before: Dictionary = game.capture_restore_state()
	var root: Object = game._identity_issuer._root
	assert_eq(root.get_script(), load("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"),
		"between-call checks retain the concrete production root")
	var document: Dictionary = root._document.duplicate(true)
	var initial_id := ""
	for id: String in source.command_receipts:
		var receipt: Dictionary = source.command_receipts[id]
		if receipt.get("kind") == "scene_admission" and receipt.scene_admission.get("schema_version") == 3:
			initial_id = id
	assert_false(initial_id.is_empty())
	if initial_id.is_empty(): return {}
	assert_true(TERMINAL_FROZEN.validate(source).ok, "first public call admits current root")
	# Preserve identity fields so terminal shape passes; complete creation proof must
	# still reject the altered allocation at the next public call.
	root._document.allocation_receipts[initial_id]["TEST.changed_between_calls"] = true
	assert_true(TERMINAL_TIMING.begin_scope("terminal_root_changed_before_call", "ENDING", "PRIMARY_PENDING", 0))
	var refused: Dictionary = TERMINAL_FROZEN.validate(source)
	var counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(refused.get("ok", false)))
	var checkpoint_refused := TERMINAL_FROZEN.validate_reading_checkpoint(source.narrative_checkpoint, source)
	root._document = document.duplicate(true)
	assert_eq(refused.get("code"), &"scene_creation_allocation_unproven")
	assert_eq(checkpoint_refused.get("code"), &"scene_creation_allocation_unproven",
		"independent checkpoint calls also recheck the current root")
	assert_eq(counts.receipt_validation_calls, 1, "the one ledger refuses changed creation proof")
	assert_true(TERMINAL_FROZEN.validate(source).ok, "a later call admits the restored original root")
	assert_eq(source, before)
	assert_eq(game.capture_restore_state(), live_before, "refusal applies no gameplay consequence")
	assert_eq(root._document, document)
	return {"code": str(refused.get("code", "")), "counts": counts}

func _same_call_terminal_checks(source: Dictionary, frozen_counts: Dictionary) -> Dictionary:
	var original_source := source.duplicate(true)
	var original_live: Dictionary = game.capture_restore_state()
	var original_authority: Object = TERMINAL_SCHEMA._scene_authority
	var original_issuer: Object = TERMINAL_SCHEMA._scene_issuer
	var original_frozen_issuer: Object = TERMINAL_FROZEN._scene_issuer
	var original_game_issuer: Object = game._identity_issuer
	assert_eq(original_authority, game, "genuine terminal Run uses the actual semantic owner")
	assert_false(TERMINAL_SCHEMA._scene_terminal_reading_owners().is_empty())
	var reused := _measured_run(source, "terminal_run_reused")
	var fresh_owner := FreshSemanticOwner.new()
	fresh_owner.delegate = game
	TERMINAL_SCHEMA._scene_authority = fresh_owner
	var fresh := _measured_run(source, "terminal_run_fresh")
	TERMINAL_SCHEMA._scene_authority = original_authority
	assert_true(reused.result.get("ok", false), str(reused.result))
	assert_eq(reused.result, fresh.result, "same-call reuse preserves the complete public Run result")
	assert_eq(fresh_owner.calls, 1, "custom authority still receives its public semantic call")
	assert_eq(fresh.counts.receipt_validation_calls - reused.counts.receipt_validation_calls,
		frozen_counts.receipt_validation_calls, "exactly one duplicate Frozen receipt proof is removed")
	assert_eq(fresh.counts.physical_proof_calls - reused.counts.physical_proof_calls,
		frozen_counts.physical_proof_calls, "only the same-call Frozen proof is reused")
	assert_gt(int(reused.counts.physical_proof_calls), 0, "current physical Profile is still proved")

	var replacement_game: Node = load("res://autoload/GameState.gd").new()
	get_tree().root.add_child(replacement_game)
	replacement_game._scene_event_bridge = game._scene_event_bridge
	var first_root := SwitchingRoot.new()
	first_root.delegate = original_issuer._root
	var first_issuer := TERMINAL_ISSUER.new()
	assert_true(first_issuer.configure(first_root).ok)
	var second_issuer := TERMINAL_ISSUER.new()
	assert_true(second_issuer.configure(original_issuer._root).ok)
	replacement_game._identity_issuer = second_issuer
	first_root.switch_owner = func() -> void:
		TERMINAL_SCHEMA._scene_authority = replacement_game
		TERMINAL_SCHEMA._scene_issuer = second_issuer
		TERMINAL_FROZEN._scene_issuer = second_issuer
	game._identity_issuer = first_issuer
	TERMINAL_SCHEMA._scene_issuer = first_issuer
	TERMINAL_FROZEN._scene_issuer = first_issuer
	assert_false(TERMINAL_SCHEMA._scene_terminal_reading_owners().is_empty())
	var replaced := _measured_run(source, "terminal_run_replaced_owners")
	var new_group_matches := not TERMINAL_SCHEMA._scene_terminal_reading_owners().is_empty()
	TERMINAL_SCHEMA._scene_authority = original_authority
	TERMINAL_SCHEMA._scene_issuer = original_issuer
	TERMINAL_FROZEN._scene_issuer = original_frozen_issuer
	game._identity_issuer = original_game_issuer
	replacement_game.free()
	assert_eq(first_root.switches, 1, "replacement occurred inside the first Frozen validation")
	assert_true(new_group_matches, "replacement group agrees internally after the callback")
	assert_eq(replaced.result, fresh.result, "changed owners use fresh validation and preserve valid output")
	assert_eq(replaced.counts.receipt_validation_calls, fresh.counts.receipt_validation_calls,
		"coordinated replacement cannot consume the original group's retained proof")
	assert_eq(replaced.counts.physical_proof_calls, fresh.counts.physical_proof_calls)

	var empty := source.duplicate(true)
	empty.narrative_checkpoint = {}
	var empty_reused := _measured_run(empty, "terminal_empty_actual_owner")
	TERMINAL_SCHEMA._scene_authority = fresh_owner
	var empty_fresh := _measured_run(empty, "terminal_empty_fresh_owner")
	TERMINAL_SCHEMA._scene_authority = original_authority
	assert_true(empty_reused.result.get("ok", false), str(empty_reused.result))
	assert_eq(empty_reused.result, empty_fresh.result)
	assert_eq(empty_reused.counts.receipt_validation_calls, empty_fresh.counts.receipt_validation_calls,
		"empty terminal checkpoint retains the fresh semantic fallback")
	assert_eq(empty_reused.counts.physical_proof_calls, empty_fresh.counts.physical_proof_calls)
	assert_eq(source, original_source)
	assert_eq(game.capture_restore_state(), original_live, "validation never applies gameplay consequences")
	return {"reused": reused.counts, "fresh": fresh.counts, "replaced": replaced.counts,
		"empty": empty_reused.counts}

func _schema_reading_checks(source: Dictionary, frozen_counts: Dictionary) -> Dictionary:
	var before := source.duplicate(true)
	assert_true(TERMINAL_TIMING.begin_scope("terminal_schema_reading", "ENDING", "PRIMARY_PENDING", 0))
	var reading: Dictionary = TERMINAL_SCHEMA._validate_scene_reading(source)
	var counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(reading.get("ok", false)))
	if not _ok(reading): return {}
	assert_eq(counts.receipt_validation_calls, frozen_counts.receipt_validation_calls,
		"Run reading delegates one complete terminal ledger proof to the matching frame owner")
	assert_eq(counts.physical_proof_calls, frozen_counts.physical_proof_calls,
		"delegation keeps the frame validator's fresh physical proofs")
	assert_gt(int(counts.physical_proof_calls), 0)
	assert_eq(source, before)
	var owner: Object = TERMINAL_SCHEMA._scene_creation_owner
	TERMINAL_SCHEMA._scene_creation_owner = null
	var unbound: Dictionary = TERMINAL_SCHEMA._validate_scene_reading(source)
	TERMINAL_SCHEMA._scene_creation_owner = owner
	assert_false(unbound.ok, "a mismatched creation owner cannot borrow the frame owner's proof")
	var original_issuer: Object = TERMINAL_SCHEMA._scene_issuer
	var other_issuer := TERMINAL_ISSUER.new()
	if not _ok(other_issuer.configure(OTHER_ROOT.new("eb".repeat(32), 1))): return {}
	TERMINAL_SCHEMA._scene_issuer = other_issuer
	var wrong_issuer: Dictionary = TERMINAL_SCHEMA._validate_scene_reading(source)
	TERMINAL_SCHEMA._scene_issuer = original_issuer
	assert_false(wrong_issuer.ok, "another issuer retains independent admission validation")
	var changed := source.duplicate(true)
	changed.narrative_checkpoint = {}
	assert_true(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "admitted pre-playback may have no current checkpoint")
	changed.command_receipts.erase(changed.lifecycle.ending_plan.admission.trigger_command_id)
	assert_false(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "empty checkpoint still requires the terminal trigger")
	changed = source.duplicate(true)
	changed.narrative_checkpoint = {}
	changed.lifecycle.state = "COMPLETED"
	assert_false(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "completed playback cannot use the empty-checkpoint exception")
	changed = source.duplicate(true)
	changed.command_receipts.erase(changed.lifecycle.ending_plan.admission.trigger_command_id)
	assert_false(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "delegated validation still requires the trigger")
	changed = source.duplicate(true)
	changed.lifecycle.ending_plan.admission.trigger_sha256 = "f".repeat(64)
	assert_false(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "changed trigger proof is refused")
	changed = source.duplicate(true)
	changed.lifecycle.ending_plan.admission = {}
	assert_false(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "malformed admission never reaches unchecked field access")
	changed = source.duplicate(true)
	changed.lifecycle.ending_plan.source_reading_checkpoint = {}
	assert_false(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "source reading remains required")
	changed = source.duplicate(true)
	changed.scene.active_admission_receipt_id = "TEST.changed.admission"
	assert_false(TERMINAL_SCHEMA._validate_scene_reading(changed).ok, "source admission remains joined to the active scene")
	assert_true(TERMINAL_SCHEMA._validate_scene_reading(source).ok, "later valid call is independent of rejected inputs")
	return counts

func _frozen_checks(source: Dictionary) -> Dictionary:
	assert_true(TERMINAL_FROZEN.scene_validation_uses(game._identity_issuer, saves))
	assert_false(source.narrative_checkpoint.is_empty(), "saved ending exercises the nonempty checkpoint branch")
	assert_true(TERMINAL_TIMING.begin_scope("terminal_frozen_full", "ENDING", "PRIMARY_PENDING", 0))
	var full: Dictionary = TERMINAL_FROZEN.validate(source)
	var full_counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(full.get("ok", false)))
	if not _ok(full): return {}
	assert_true(TERMINAL_TIMING.begin_scope("terminal_frozen_checkpoint", "ENDING", "PRIMARY_PENDING", 0))
	var checkpoint: Dictionary = TERMINAL_FROZEN.validate_reading_checkpoint(source.narrative_checkpoint, source)
	var checkpoint_counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(checkpoint.get("ok", false)))
	if not _ok(checkpoint): return {}
	assert_eq(full, checkpoint, "both public paths admit the same ending frames")
	assert_eq(full_counts.receipt_validation_calls, checkpoint_counts.receipt_validation_calls,
		"full validation authenticates terminal authority once, like direct checkpoint validation")
	assert_eq(full_counts.physical_proof_calls, checkpoint_counts.physical_proof_calls)
	assert_eq(full_counts.receipt_validation_calls, 1,
		"terminal and retained source share one locally authenticated ledger")
	assert_eq(full_counts.physical_proof_calls, 1,
		"the same synchronous terminal call proves current Profile once")
	assert_gt(int(full_counts.physical_proof_calls), 0, "same-call reuse still proves current physical Profile")
	var ledger: Dictionary = TERMINAL_CONTRACT.validate_selected_scene_receipts(
		source.command_receipts, game._identity_issuer, saves, source.contacts)
	if not _ok(ledger): return {}
	assert_eq(full.scene_commands, ledger.value.commands, "terminal frames expose only freshly authenticated source commands")
	var standalone_source := source.duplicate(true)
	standalone_source.route_id = "scene"
	standalone_source.lifecycle.ending_plan = null
	assert_true(TERMINAL_TIMING.begin_scope("terminal_standalone_source", "PLAYING", "", 0))
	var source_reading := TERMINAL_FROZEN.validate_reading_checkpoint(
		source.lifecycle.ending_plan.source_reading_checkpoint, standalone_source)
	var source_counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(source_reading.get("ok", false)))
	if not _ok(source_reading): return {}
	assert_eq(source_counts.receipt_validation_calls, 1,
		"standalone source validation obtains its own fresh ledger")
	assert_eq(source_counts.physical_proof_calls, 1)
	assert_eq(source_reading.scene_commands, ledger.value.commands)
	var source_before := source.duplicate(true)
	var live_before: Dictionary = game.capture_restore_state()
	assert_true(TERMINAL_TIMING.begin_scope("terminal_semantic_reuse", "ENDING", "PRIMARY_PENDING", 0))
	var semantic: Dictionary = game._prepare_scene_snapshot_semantics(source, AUTHORED_MANIFEST.scene_registration().value)
	var semantic_counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(semantic.get("ok", false)))
	if not _ok(semantic): return {}
	assert_eq(semantic_counts.receipt_validation_calls, full_counts.receipt_validation_calls,
		"semantic validation reuses source commands instead of authenticating the ledger once more")
	assert_gt(int(semantic_counts.physical_proof_calls), 0)
	assert_eq(semantic.pending_anchors.size(), ledger.value.commands.size())
	assert_false(semantic.pending_anchors.is_empty(), "genuine terminal source carries native anchors")
	if not semantic.pending_anchors.is_empty():
		var invented: Array[Dictionary] = []
		invented.assign(semantic.pending_anchors.duplicate(true))
		invented[0].publication_id = "TEST.invented.publication"
		assert_false(game._validate_scene_snapshot_anchors(invented, semantic.checkpoint).ok,
			"authenticated commands never bypass the native publication join")
	assert_true(game.validate_scene_snapshot_semantics(source, AUTHORED_MANIFEST.scene_registration().value).ok,
		"reused commands still pass the real native anchor join")
	full.scene_commands.clear()
	assert_eq(TERMINAL_FROZEN.validate(source).scene_commands, ledger.value.commands,
		"editing returned commands cannot change a later validation")
	assert_eq(source, source_before)
	assert_eq(game.capture_restore_state(), live_before, "validation never applies or repeats gameplay consequences")
	var original_issuer: Object = game._identity_issuer
	var unbound_issuer := TERMINAL_ISSUER.new()
	if not _ok(unbound_issuer.configure(OTHER_ROOT.new("ed".repeat(32), 1))): return {}
	assert_false(TERMINAL_FROZEN.scene_validation_uses(unbound_issuer, saves))
	assert_false(TERMINAL_FROZEN.scene_validation_uses(original_issuer, null))
	game._identity_issuer = unbound_issuer
	var unbound: Dictionary = game._prepare_scene_snapshot_semantics(source, AUTHORED_MANIFEST.scene_registration().value)
	game._identity_issuer = original_issuer
	assert_false(unbound.ok, "another issuer cannot reuse the bound owner's command proof")
	var wrong_bundle: Dictionary = AUTHORED_MANIFEST.scene_registration().value.duplicate(true)
	wrong_bundle.extra_table = []
	assert_false(game._prepare_scene_snapshot_semantics(source, wrong_bundle).ok, "registration mismatch still rejects")
	for field: String in ["active_occurrence_id", "active_admission_receipt_id", "registration_sha256"]:
		var wrong_context: Dictionary = source.duplicate(true)
		wrong_context.scene[field] = "TEST.changed.context"
		assert_false(game._prepare_scene_snapshot_semantics(wrong_context, AUTHORED_MANIFEST.scene_registration().value).ok,
			"reused commands remain bound to " + field)

	var changed: Dictionary = source.duplicate(true)
	changed.lifecycle.ending_plan.source_reading_checkpoint = {}
	assert_false(TERMINAL_FROZEN.validate(changed).ok, "full validation rechecks later source history")
	assert_false(TERMINAL_FROZEN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok,
		"public checkpoint validation independently rechecks later source history")
	changed = source.duplicate(true)
	var changed_reading: Dictionary = changed.lifecycle.ending_plan.source_reading_checkpoint.reading_session
	var historical_frame := ""
	for key: String in changed_reading.ledger.entry_contexts:
		if changed_reading.ledger.entry_contexts[key].playback_id != changed_reading.occurrence_id:
			historical_frame = key
			break
	assert_false(historical_frame.is_empty(), "genuine source includes earlier immutable scene frames")
	if historical_frame.is_empty(): return {}
	changed_reading.ledger.entry_contexts[historical_frame].presentation.fields.admission_receipt_id = "TEST.missing.admission"
	assert_false(TERMINAL_FROZEN.validate(changed).ok,
		"local ledger reuse still checks historical source frames against admissions")
	assert_false(TERMINAL_FROZEN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok,
		"standalone terminal checkpoint also validates historical source frames")
	changed = source.duplicate(true)
	changed.command_receipts.erase(source.lifecycle.ending_plan.admission.trigger_command_id)
	assert_false(TERMINAL_FROZEN.validate(changed).ok, "full validation rechecks later receipts")
	assert_false(TERMINAL_FROZEN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok,
		"public checkpoint validation independently rechecks later receipts")
	changed = source.duplicate(true)
	changed.narrative_checkpoint = {}
	var empty: Dictionary = TERMINAL_FROZEN.validate(changed)
	assert_true(empty.ok, "initial terminal admission retains its allowed empty checkpoint")
	assert_eq(empty.get("scene_commands"), ledger.value.commands)
	assert_true(game._prepare_scene_snapshot_semantics(changed, AUTHORED_MANIFEST.scene_registration().value).ok)
	assert_eq(TERMINAL_FROZEN.validate_reading_checkpoint({}, changed).code, &"reading_session_invalid",
		"standalone checkpoint API still requires a checkpoint envelope")
	changed.narrative_checkpoint = null
	assert_eq(TERMINAL_FROZEN.validate(changed).code, &"reading_session_invalid")
	changed.lifecycle.ending_plan.admission.trigger_sha256 = "f".repeat(64)
	assert_eq(TERMINAL_FROZEN.validate(changed).code, &"scene_terminal_admission_mismatch",
		"terminal authority refusal precedes malformed current checkpoint")
	assert_eq(TERMINAL_FROZEN.validate_reading_checkpoint({}, changed).code, &"scene_terminal_admission_mismatch",
		"standalone checkpoint preserves the same terminal-first error order")
	return {"full_counts": full_counts, "checkpoint_counts": checkpoint_counts,
		"source_counts": source_counts, "semantic_counts": semantic_counts}

func test_selected_terminal_admission_rechecks_genuine_saved_authority() -> void:
	_phase = "terminal-admission"
	if not _setup_authored(): return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_2.json"))
	if not _ok(parsed): return
	var source: Dictionary = parsed.value.current_snapshot.snapshot
	assert_eq(source.lifecycle.state, "ENDING")
	assert_eq(source.lifecycle.ending_plan.playback_stage, "PRIMARY_PENDING")
	assert_eq(source.checkpoint_sequence, 71)
	assert_eq(source.command_receipts.size(), 61)
	var record: Dictionary = source.lifecycle.ending_plan.admission
	var receipts: Dictionary = source.command_receipts
	var contacts: Dictionary = source.contacts
	var bundle: Dictionary = AUTHORED_MANIFEST.scene_registration().value
	var issuer: Object = game._identity_issuer
	var slot_hash := FileAccess.get_sha256("user://saves/slot_2.json")
	var live_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	_profile_bytes = FileAccess.get_file_as_bytes("user://profile.json")
	assert_false(_profile_bytes.is_empty())
	if _profile_bytes.is_empty(): return

	if not TERMINAL_TIMING.begin_scope("terminal_generic", "ENDING", "PRIMARY_PENDING", 0):
		fail_test("terminal comparison requires DWM_SCENE_VALIDATION_PROFILE=1")
		return
	var generic := TERMINAL_CONTRACT.validate_scene_terminal_admission(record, bundle, issuer, receipts, saves, contacts)
	var generic_counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(generic.get("ok", false)))
	if not _ok(generic): return
	assert_true(TERMINAL_TIMING.begin_scope("terminal_selected", "ENDING", "PRIMARY_PENDING", 0))
	var selected := _selected(record, receipts, contacts)
	var selected_counts: Dictionary = TERMINAL_TIMING._record.duplicate(true)
	TERMINAL_TIMING.end_scope(bool(selected.get("ok", false)))
	if not _ok(selected): return
	assert_eq(selected, generic, "selected owner retains public admission result")
	assert_eq(generic_counts.bundle_validation_calls - selected_counts.bundle_validation_calls, 3,
		"selected terminal admission removes two structural checks plus the retained recall check")
	assert_eq(selected_counts.receipt_validation_calls, generic_counts.receipt_validation_calls)
	assert_eq(selected_counts.physical_proof_calls, generic_counts.physical_proof_calls)
	assert_gt(int(selected_counts.physical_proof_calls), 0, "actual current Profile proof is exercised")
	var frozen_counts := _frozen_checks(source)
	if frozen_counts.is_empty(): return
	var schema_reading_counts := _schema_reading_checks(source, frozen_counts.checkpoint_counts)
	if schema_reading_counts.is_empty(): return
	var same_call_counts := _same_call_terminal_checks(source, frozen_counts.full_counts)
	var root_between_call_counts := _root_between_call_checks(source)

	var changed: Dictionary = receipts.duplicate(true)
	changed.erase(record.trigger_command_id)
	assert_false(_selected(record, changed, contacts).ok, "a later missing trigger cannot borrow the valid call")
	changed = receipts.duplicate(true)
	changed[record.trigger_command_id].scene_event.reading_anchor.publication_id = "TEST.changed.publication"
	assert_false(_selected(record, changed, contacts).ok, "changed receipt is freshly authenticated")
	var changed_record: Dictionary = record.duplicate(true)
	changed_record.trigger_sha256 = "f".repeat(64)
	assert_false(_selected(changed_record, receipts, contacts).ok, "changed terminal record is freshly authenticated")
	assert_false(TERMINAL_CONTRACT.validate_selected_scene_terminal_admission(record, null,
		receipts, saves, contacts).ok, "later unbound issuer cannot borrow prior authority")
	var other_issuer := TERMINAL_ISSUER.new()
	if not _ok(other_issuer.configure(OTHER_ROOT.new("ec".repeat(32), 1))): return
	assert_false(TERMINAL_CONTRACT.validate_selected_scene_terminal_admission(record, other_issuer,
		receipts, saves, contacts).ok, "same issuer class with another root cannot borrow prior authority")
	assert_false(TERMINAL_CONTRACT.validate_selected_scene_terminal_admission(record, issuer,
		receipts, null, contacts).ok, "creation proof still requires its actual owner")
	var changed_bundle: Dictionary = bundle.duplicate(true)
	changed_bundle.extra_table = []
	assert_false(TERMINAL_CONTRACT.validate_scene_terminal_admission(record, changed_bundle,
		issuer, receipts, saves, contacts).ok, "arbitrary-bundle API continues to inspect supplied registration")

	# Mutate only this process's disposable physical copy. Restore before asserting
	# the refusal, so an assertion failure cannot leak the corrupt bytes to later checks.
	var file := FileAccess.open("user://profile.json", FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return
	file.store_string("{}")
	file.close()
	var physical_refusal := _selected(record, receipts, contacts)
	var full_physical_refusal: Dictionary = TERMINAL_FROZEN.validate(source)
	var checkpoint_physical_refusal: Dictionary = TERMINAL_FROZEN.validate_reading_checkpoint(source.narrative_checkpoint, source)
	var semantic_physical_refusal: Dictionary = game._prepare_scene_snapshot_semantics(source, bundle)
	var schema_physical_refusal: Dictionary = TERMINAL_SCHEMA._validate_scene_reading(source)
	var run_physical_refusal: Dictionary = TERMINAL_SCHEMA.validate(source)
	var restored := _restore_profile_bytes()
	assert_true(restored, "original Profile bytes restored immediately")
	assert_false(physical_refusal.ok, "later changed physical Profile is not replaced by cached proof")
	assert_false(full_physical_refusal.ok, "full validation rechecks physical Profile on each call")
	assert_false(checkpoint_physical_refusal.ok, "standalone checkpoint validation rechecks physical Profile on each call")
	assert_false(semantic_physical_refusal.ok, "semantic reuse never caches physical Profile proof")
	assert_false(schema_physical_refusal.ok, "Run reading delegation rechecks changed physical Profile")
	assert_false(run_physical_refusal.ok, "full Run never reuses a prior call after physical Profile changes")
	if not restored: return
	assert_true(_selected(record, receipts, contacts).ok, "original valid inputs remain admissible after all mutations")
	assert_true(TERMINAL_FROZEN.validate(source).ok, "valid full context recovers after physical bytes are restored")
	assert_eq(profile.get_profile_snapshot(), live_profile, "boundary checks do not adopt Profile changes")
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), slot_hash, "saved source remains untouched")
	_write_json("res://.godot/ci/authored-terminal-admission-checks.json", {
		"process_id": OS.get_process_id(), "slot_sha256": slot_hash,
		"generic_counts": generic_counts, "selected_counts": selected_counts,
		"frozen_counts": frozen_counts,
		"schema_reading_counts": schema_reading_counts,
		"same_call_counts": same_call_counts,
		"root_between_call_counts": root_between_call_counts,
		"physical_refusal_code": str(physical_refusal.get("code", "")),
		"profile_restored": restored})

