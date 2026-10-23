extends "res://tests/integration/authored_week_child.gd"
## Run against an isolated copy of the genuine post-replay root, with slot 2 intact.
## This checks admission boundaries, not physical playback or uninterrupted route coverage.
const TERMINAL_CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const TERMINAL_TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")
const TERMINAL_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const OTHER_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const TERMINAL_FROZEN := preload("res://scripts/narrative/FrozenRunContext.gd")
var _profile_bytes := PackedByteArray()

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
	assert_gt(int(full_counts.physical_proof_calls), 0, "same-call reuse still proves current physical Profile")

	var changed: Dictionary = source.duplicate(true)
	changed.lifecycle.ending_plan.source_reading_checkpoint = {}
	assert_false(TERMINAL_FROZEN.validate(changed).ok, "full validation rechecks later source history")
	assert_false(TERMINAL_FROZEN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok,
		"public checkpoint validation independently rechecks later source history")
	changed = source.duplicate(true)
	changed.command_receipts.erase(source.lifecycle.ending_plan.admission.trigger_command_id)
	assert_false(TERMINAL_FROZEN.validate(changed).ok, "full validation rechecks later receipts")
	assert_false(TERMINAL_FROZEN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok,
		"public checkpoint validation independently rechecks later receipts")
	changed = source.duplicate(true)
	changed.narrative_checkpoint = {}
	assert_true(TERMINAL_FROZEN.validate(changed).ok, "initial terminal admission retains its allowed empty checkpoint")
	assert_eq(TERMINAL_FROZEN.validate_reading_checkpoint({}, changed).code, &"reading_session_invalid",
		"standalone checkpoint API still requires a checkpoint envelope")
	changed.narrative_checkpoint = null
	assert_eq(TERMINAL_FROZEN.validate(changed).code, &"reading_session_invalid")
	changed.lifecycle.ending_plan.admission.trigger_sha256 = "f".repeat(64)
	assert_eq(TERMINAL_FROZEN.validate(changed).code, &"scene_terminal_admission_mismatch",
		"terminal authority refusal precedes malformed current checkpoint")
	assert_eq(TERMINAL_FROZEN.validate_reading_checkpoint({}, changed).code, &"scene_terminal_admission_mismatch",
		"standalone checkpoint preserves the same terminal-first error order")
	return {"full_counts": full_counts, "checkpoint_counts": checkpoint_counts}

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
	assert_eq(generic_counts.bundle_validation_calls - selected_counts.bundle_validation_calls, 2,
		"selected terminal admission removes the two repeated structural checks")
	assert_eq(selected_counts.receipt_validation_calls, generic_counts.receipt_validation_calls)
	assert_eq(selected_counts.physical_proof_calls, generic_counts.physical_proof_calls)
	assert_gt(int(selected_counts.physical_proof_calls), 0, "actual current Profile proof is exercised")
	var frozen_counts := _frozen_checks(source)
	if frozen_counts.is_empty(): return

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
	var restored := _restore_profile_bytes()
	assert_true(restored, "original Profile bytes restored immediately")
	assert_false(physical_refusal.ok, "later changed physical Profile is not replaced by cached proof")
	assert_false(full_physical_refusal.ok, "full validation rechecks physical Profile on each call")
	assert_false(checkpoint_physical_refusal.ok, "standalone checkpoint validation rechecks physical Profile on each call")
	if not restored: return
	assert_true(_selected(record, receipts, contacts).ok, "original valid inputs remain admissible after all mutations")
	assert_true(TERMINAL_FROZEN.validate(source).ok, "valid full context recovers after physical bytes are restored")
	assert_eq(profile.get_profile_snapshot(), live_profile, "boundary checks do not adopt Profile changes")
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), slot_hash, "saved source remains untouched")
	_write_json("res://.godot/ci/authored-terminal-admission-checks.json", {
		"process_id": OS.get_process_id(), "slot_sha256": slot_hash,
		"generic_counts": generic_counts, "selected_counts": selected_counts,
		"frozen_counts": frozen_counts,
		"physical_refusal_code": str(physical_refusal.get("code", "")),
		"profile_restored": restored})
