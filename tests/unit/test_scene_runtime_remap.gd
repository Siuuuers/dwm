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
			"entry_id": "TEST.contact.entry", "notification": {}, "active_challenge": {},
			"return_to": {"parent": {"active_occurrence_id": "TEST.parent", "entry_id": "TEST.parent.entry",
				"notification": {}, "active_challenge": {"challenge_id": "TEST.challenge", "playable_command_id": "TEST.playable"}},
				"target_id": "TEST.parent.target", "contact_event_id": "TEST.contact.event"}},
		"desktop": {"board": BOARD.new().capture(), "consequence": consequence},
		"contacts": {"TEST.historical": "TEST.old.branch"},
		"narrative_checkpoint": {"TEST.logical_occurrence": "TEST.contact.occurrence"},
		"gameplay": {"TEST.physical_history": {"branch_id": "TEST.old.branch", "preimage": "unchanged"}}}

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
	for key: String in ["scene", "contacts", "narrative_checkpoint", "gameplay"]:
		assert_eq(candidate[key], source[key], key)
	assert_false(candidate.has("audio_context"), "remapping keeps presentation metadata out of player state")
	assert_eq(candidate.lifecycle.scene_assignment, source.lifecycle.scene_assignment, "Load preserves assigned form and creation receipt")
	assert_eq(candidate.lifecycle.branch_id, "TEST.new.branch")
	assert_eq(candidate.lifecycle.causal_day_instance, "TEST.new.causal")
	assert_null(candidate.lifecycle.restore_provenance, "A attaches new provenance in its lifecycle participant")
	assert_eq(candidate.desktop.consequence.causal_day_instance, "TEST.new.causal")
	assert_eq(source, before, "pure remap retains selected source")
	assert_true(REMAPPER.validate_remap(source, candidate, bundle).ok)
	candidate.scene.return_to.parent.active_occurrence_id = "TEST.forged"
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

func test_scene_same_day_load_preserves_supportz_eligibility_and_purchase_limits() -> void:
	var rules := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
	for purchased: bool in [false, true]:
		var source := _source()
		var ledger: Dictionary = source.desktop.consequence.shop_ledger
		ledger.base_completion_receipts = [
			{"kind": "complete", "app_round_ordinal": 1, "causal_day_instance": "TEST.previous.day"},
			{"kind": "complete", "app_round_ordinal": 1, "causal_day_instance": "TEST.old.causal"},
			{"kind": "complete", "app_round_ordinal": 2, "causal_day_instance": "TEST.old.causal"}]
		ledger.supportz_branch_purchase_count = 1 if purchased else 0
		ledger.supportz_last_purchase_causal_day_instance = "TEST.old.causal" if purchased else "TEST.previous.day"
		var before := source.duplicate(true)
		var bundle := _bundle()
		for load_index: int in range(2):
			var result := REMAPPER.prepare(source, bundle.transaction_id, bundle)
			assert_true(result.ok, str(result))
			if not result.ok: return
			var candidate: Dictionary = result.value.snapshot
			var projected: Dictionary = candidate.desktop.consequence.shop_ledger
			assert_eq(projected.base_completion_receipts[0], before.desktop.consequence.shop_ledger.base_completion_receipts[0])
			assert_eq(projected.base_completion_receipts.size(), 3)
			for index: int in [1, 2]:
				assert_eq(projected.base_completion_receipts[index], {"kind": "complete", "app_round_ordinal": index,
					"causal_day_instance": bundle.causal_day_instance})
			assert_eq(projected.supportz_branch_purchase_count, 1 if purchased else 0)
			assert_eq(projected.supportz_last_purchase_causal_day_instance,
				bundle.causal_day_instance if purchased else "TEST.previous.day")
			var eligibility := rules.supportz_eligible({"causal_day_instance": bundle.causal_day_instance,
				"completion_receipts": projected.base_completion_receipts,
				"branch_purchase_count": projected.supportz_branch_purchase_count,
				"daily_purchase_done": projected.supportz_last_purchase_causal_day_instance == bundle.causal_day_instance})
			assert_true(eligibility.ok)
			assert_eq(eligibility.value.eligible, not purchased)
			assert_eq(candidate.scene, before.scene)
			assert_true(REMAPPER.validate_remap(source, candidate, bundle).ok)
			if load_index == 0: assert_eq(source, before, "remapping never edits the selected save")
			source = candidate
			bundle.causal_day_instance = "TEST.next.causal"
			bundle.causal_day_instance_issuer_receipt = _receipt("causal_day_instance", bundle.causal_day_instance)
			bundle.branch_id = "TEST.next.branch"
			bundle.desktop_timeline_generation = 2

func test_completed_scene_content_provenance_survives_identity_remap() -> void:
	var source := _source()
	source.lifecycle.state = "COMPLETED"
	source.scene.return_to = null
	source.lifecycle["completed_registration_sha256"] = "b".repeat(64)
	var before := source.duplicate(true)
	var allocation := _bundle()
	var result := REMAPPER.prepare(source, "TEST.restore", allocation)
	assert_true(result.ok, str(result))
	if not result.ok: return
	var candidate: Dictionary = result.value.snapshot
	assert_eq(candidate.lifecycle.state, "COMPLETED")
	assert_eq(candidate.lifecycle.completed_registration_sha256, "b".repeat(64))
	assert_ne(candidate.lifecycle.branch_id, source.lifecycle.branch_id)
	assert_true(REMAPPER.validate_remap(source, candidate, allocation).ok)
	assert_eq(source, before)
	candidate.lifecycle.completed_registration_sha256 = "c".repeat(64)
	assert_false(REMAPPER.validate_remap(source, candidate, allocation).ok, "remapping cannot alter completion provenance")

func test_scene_remap_refuses_malformed_or_playing_completion_provenance() -> void:
	var source := _source()
	source.lifecycle.state = "COMPLETED"
	for invalid: Variant in [null, 1, "", "g".repeat(64), "a".repeat(63)]:
		source.lifecycle["completed_registration_sha256"] = invalid
		assert_false(REMAPPER.prepare(source, "TEST.restore", _bundle()).ok)
	source.lifecycle.completed_registration_sha256 = "a".repeat(64)
	source.lifecycle.state = "PLAYING"
	assert_false(REMAPPER.prepare(source, "TEST.restore", _bundle()).ok)
