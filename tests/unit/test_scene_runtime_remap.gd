extends "res://addons/gut/test.gd"
## Remapper projection fixtures only. A owns full Run9/Save9, installed content,
## real selected-document provenance and silent participant admission.
const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const BOARD := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const CONSEQUENCE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")

func _receipt(purpose: String, token: String) -> Dictionary:
	return {"counter": 1, "namespace": "TEST.namespace", "numeric_value": null,
		"purpose": purpose, "receipt_id": "TEST.receipt." + token, "token": token}

func _source() -> Dictionary:
	var consequence: Dictionary = CONSEQUENCE.new().capture().value.state
	consequence.causal_day_instance = "TEST.old.causal"
	consequence.causal_day_instance_issuer_receipt = _receipt("causal_day_instance", "TEST.old.causal")
	return {"schema_version": 9, "route_id": "scene", "run_id": "TEST.run",
		"lifecycle": {"run_id": "TEST.run", "branch_id": "TEST.old.branch", "desktop_timeline_generation": 0,
			"causal_day_instance": "TEST.old.causal", "causal_day_instance_issuer_receipt": consequence.causal_day_instance_issuer_receipt,
			"restore_provenance": null, "state": "PLAYING",
			"scene_assignment": {"ruleset_id": "scene.new_run.alternating.v1", "form": "sweet",
				"selection_kind": "initial_random", "rng_nonce": 0, "predecessor_run_id": null,
				"predecessor_assignment_sha256": null, "creation_transaction_id": "TEST.creation"}},
		"scene": {"registration_sha256": "a".repeat(64), "active_occurrence_id": "TEST.contact.occurrence",
			"active_admission_receipt_id": "TEST.contact.admission"},
		"desktop": {"board": BOARD.new().capture(), "consequence": consequence},
		"command_receipts": {"TEST.contact.admission": {"TEST.historical": {"return_to": {
			"scene_occurrence": "TEST.parent", "admission_receipt_id": "TEST.parent.admission",
			"entry_id": "TEST.parent.entry", "target_id": "TEST.parent.target", "source_checkpoint": "TEST.checkpoint"}}}},
		"contacts": {"TEST.historical": "TEST.old.branch"},
		"narrative_checkpoint": {"TEST.logical_occurrence": "TEST.contact.occurrence"},
		"gameplay": {"TEST.physical_history": {"branch_id": "TEST.old.branch", "preimage": "unchanged"}},
		"applied_effect_transaction_ids": ["TEST.effect"], "applied_variable_transaction_ids": ["TEST.variable"]}

func _bundle() -> Dictionary:
	return {"transaction_id": "TEST.restore", "transaction_issuer_receipt": _receipt("transaction_id", "TEST.restore"),
		"branch_id": "TEST.new.branch", "desktop_timeline_generation": 1, "causal_day_instance": "TEST.new.causal",
		"causal_day_instance_issuer_receipt": _receipt("causal_day_instance", "TEST.new.causal"), "transaction_remap": {}}

func test_scene_without_live_commands_preserves_all_historical_and_logical_references() -> void:
	var source := _source()
	var before := source.duplicate(true)
	var bundle := _bundle()
	var census := REMAPPER.collect_rewindable_transaction_ids(source)
	assert_true(census.ok)
	if not census.ok: return
	assert_eq(census.value.transaction_ids, [])
	var result := REMAPPER.prepare(source, "TEST.restore", bundle)
	assert_true(result.ok, str(result))
	if not result.ok: return
	var candidate: Dictionary = result.value.snapshot
	for key: String in ["scene", "command_receipts", "contacts", "narrative_checkpoint", "gameplay",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_eq(candidate[key], source[key], key)
	assert_eq(candidate.lifecycle.scene_assignment, source.lifecycle.scene_assignment, "Load preserves assigned form and creation receipt")
	assert_eq(candidate.lifecycle.branch_id, "TEST.new.branch")
	assert_eq(candidate.lifecycle.causal_day_instance, "TEST.new.causal")
	assert_null(candidate.lifecycle.restore_provenance, "A attaches new provenance in its lifecycle participant")
	assert_eq(candidate.desktop.consequence.causal_day_instance, "TEST.new.causal")
	assert_eq(source, before, "pure remap retains selected source")
	assert_true(REMAPPER.validate_remap(source, candidate, bundle).ok)
	candidate.command_receipts["TEST.contact.admission"]["TEST.historical"].return_to.scene_occurrence = "TEST.forged"
	assert_false(REMAPPER.validate_remap(source, candidate, bundle).ok)

func test_scene_live_desktop_keys_move_without_importing_scene_history_into_census() -> void:
	var source := _source()
	source.desktop.board.command_receipts = {"TEST.live": {"result": {"TEST.historical_preimage": "TEST.old.branch"}}}
	var bundle := _bundle()
	bundle.transaction_remap = {"TEST.live": {"source_transaction_id": "TEST.live",
		"new_transaction_id": "TEST.live.next", "new_transaction_issuer_receipt": _receipt("transaction_id", "TEST.live.next")}}
	var census := REMAPPER.collect_rewindable_transaction_ids(source)
	assert_true(census.ok)
	if not census.ok: return
	assert_eq(census.value.transaction_ids, ["TEST.live"])
	var result := REMAPPER.prepare(source, "TEST.restore", bundle)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.snapshot.desktop.board.command_receipts.keys(), ["TEST.live.next"])
	assert_eq(result.value.snapshot.desktop.board.command_receipts["TEST.live.next"], source.desktop.board.command_receipts["TEST.live"])
	assert_true(REMAPPER.validate_remap(source, result.value.snapshot, bundle).ok)

func test_scene_family_and_live_calendar_mismatches_refuse_before_remapping() -> void:
	var variants: Array = []
	var wrong := _source()
	wrong.schema_version = 8
	variants.append(wrong)
	wrong = _source()
	wrong.lifecycle.day = 1
	variants.append(wrong)
	wrong = _source()
	wrong.schedule_view = {}
	variants.append(wrong)
	wrong = _source()
	wrong.desktop.consequence.pending = {"source_kind": "schedule_done"}
	variants.append(wrong)
	wrong = _source()
	wrong.desktop.consequence.outbox.hospital = {"status": "pending", "consumer": "day7_terminal"}
	variants.append(wrong)
	for source: Dictionary in variants:
		var before := source.duplicate(true)
		assert_false(REMAPPER.collect_rewindable_transaction_ids(source).ok)
		assert_false(REMAPPER.prepare(source, "TEST.restore", _bundle()).ok)
		assert_eq(source, before)

func test_scene_verification_requires_retained_allocation_and_preserves_published_history() -> void:
	var source := _source()
	source.desktop.consequence.outbox.hospital = {"status": "published", "consumer": "day7_terminal", "TEST.history": "retained"}
	var result := REMAPPER.prepare(source, "TEST.restore", _bundle())
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.snapshot.desktop.consequence.outbox, source.desktop.consequence.outbox)
	assert_false(REMAPPER.validate_remap(source, result.value.snapshot).ok, "no historical receipt borrowed as restore authority")
	var wrong := _bundle()
	wrong.desktop_timeline_generation = 1.0
	assert_false(REMAPPER.prepare(source, "TEST.restore", wrong).ok)
	wrong = _bundle()
	wrong.transaction_issuer_receipt.token = "TEST.foreign"
	assert_false(REMAPPER.prepare(source, "TEST.restore", wrong).ok)
