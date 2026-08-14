extends "res://addons/gut/test.gd"
# Behavioral RED contract tests for the durable continuation-operation journal
# (Plan 02 Task 1, dwm-p2r.16).
#
# OBLIGATION MAP (plan line 797; dwm-p2r.16 DECISION 9.13 puts the per-clause map beside the code).
#   36 external-journal exact schema ........................ DEEP
#   37 intent-before-allocation ............................. breadth
#   38 every legal/illegal stage edge ....................... breadth + full 8-key participant
#                                                             walk (DECISION 10.4); the complete
#                                                             stage adjacency matrix -> 16.1
#   39 source locator / hash mismatch ....................... breadth
#   40 duplicate equality ................................... DEEP
#   41 changed transaction conflict ......................... DEEP
#   42 incomplete listing ................................... breadth (complete at breadth)
#   43 startup forward reconciliation ....................... DEEP
#   44 pre-allocation abort ................................. breadth
#   45 irreversible allocation retention .................... breadth (journal side only)
#
# CLAUSE 45 IS JOURNAL-SIDE ONLY (DECISION 10.2). Child bead dwm-p2r.16.1 states that clause 45
# wants "the plan-line-1714 law that rollback_silent() returns exactly {retained_allocation: true}".
# That is wrong: plan line 1714 assigns rollback_silent() to DesktopIdentityAllocationRestoreParti-
# cipant, a TASK 6 participant, and this journal's frozen seven-method surface (plan lines 707-714)
# declares no rollback method at all. Asserting it here would freeze a contract dwm-p2r.16 never
# calls -- exactly what DECISION 9.5 refused for collect_rewindable_transaction_ids(). What is
# tested below is the retention law the JOURNAL actually owns (plan line 593).
#
# CLAUSE 38 (DECISION 10.4). The complete stage adjacency matrix and its evidence cross-product
# are pinned below together with the exact eight-participant walk.
#
# TWO SUBSTRATES IN ONE FILE -- deliberate, not an oversight.
#   * The JOURNAL's own document uses FakeDesktopContinuationJournalStorage (DECISION 8.5). That
#     double already enforces JsonFileStorage's reconcile-lease protocol, so a Step-1.3 journal
#     cannot skip reconciliation, pass here, and then fail against real storage.
#   * reconcile_startup(transaction_id, issuer) takes the REAL DesktopIdentityNonceIssuer over the
#     REAL DesktopIssuerRootStore over the REAL JsonFileStorage over FakeFileOps (DECISION 9.4).
#     There is no issuer fake and creating one would be a 21st create, breaking Step 1.5's
#     twenty-two-path count.
#
# THE SOURCE LOADER IS AN INNER CLASS (DECISION 10.6). Its contract is pinned by DECISION 9.5 to
# exactly load_context(source_locator) -> {ok, value={context, context_sha256}}. A fourth
# tests/support fake would be a 21st create. Inner-class doubles are an established repo pattern
# (see test_restore_production_adapters.gd and 17 others). Like the session-1 fakes, it NEVER
# returns not_implemented, so no rejection assertion here can be satisfied by an unarmed double.
#
# REJECTION ASSERTIONS (DECISION 9.9). Every skeleton method returns {ok:false, code:
# &"not_implemented"}, so a bare assert_false(result["ok"]) would PASS against the stub and prove
# nothing. Every rejection asserts failure AND code != &"not_implemented". The plan freezes NO
# rejection code for this file -- it says operations "conflict" without ever naming one -- so no
# code literal is asserted anywhere below, per DECISION 5's refusal to hardcode what the plan never
# froze. Contrast the port file, where plan line 778 freezes two codes and both are asserted.
#
# Each test guards on _require_ok() and returns early, so a stubbed method yields exactly one clear
# failure rather than a cascade -- condition (2) of the DECISION 9.11 RED gate. Because configure()
# is itself stubbed at RED, every test fails at its first guard; the test NAME, not the failure
# message, is what tells Step 1.3 which law is unmet.

# GLOBAL CLASS NAMES ARE NOT AVAILABLE for the 20 new Task-1 scripts (DECISION 9.18): they have
# never been through an editor import pass, so they are absent from the global script class cache.
# Preloading by path is this repo's established answer.
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const FAKE_STORAGE := preload("res://tests/support/FakeDesktopContinuationJournalStorage.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const FAKE_NAMESPACE_SOURCE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")

const SKELETON_PATHS := {
	"DesktopContinuationOperationJournal":
		"res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd",
	"FakeDesktopContinuationJournalStorage":
		"res://tests/support/FakeDesktopContinuationJournalStorage.gd",
}

# Plan line 555: one strict primitive document, outside Save slots, autosaves and profiles.
const JOURNAL_PATH := "desktop-continuation-operations.json"

const IDENTITY_ROOT := "sandbox/identity"
const NAMESPACE_A := "1111111111111111111111111111111111111111111111111111111111111111"

# Plan line 555: the document is exactly {schema_version, operations}. Sorted, for a set comparison.
const DOCUMENT_KEYS: Array[String] = ["operations", "schema_version"]

# Exact operation record member set, plan lines 558-588. Sorted, for a set comparison.
const OPERATION_KEYS: Array[String] = [
	"allocation_candidate_fingerprint",
	"allocation_receipt",
	"failure",
	"initial_context",
	"initial_context_sha256",
	"kind",
	"next_participant_index",
	"participant_receipts",
	"request_fingerprint",
	"source_locator",
	"stage",
	"transaction_id",
	"transaction_issuer_receipt",
]

# Exact prepare_intent() request member set, plan line 780. Sorted.
const PREPARE_INTENT_KEYS: Array[String] = [
	"allocation_candidate_fingerprint",
	"initial_context",
	"initial_context_sha256",
	"kind",
	"request_fingerprint",
	"source_locator",
	"transaction_id",
	"transaction_issuer_receipt",
]

# Exact advance() request member set, plan line 780. Sorted.
const ADVANCE_KEYS: Array[String] = [
	"allocation_receipt",
	"expected_next_participant_index",
	"expected_stage",
	"failure",
	"next_stage",
	"participant_name",
	"participant_receipt",
	"request_fingerprint",
	"transaction_id",
]

# The closed stage union, plan lines 572-574.
const STAGE_INTENT := "intent_committed"
const STAGE_ALLOCATED := "identity_allocation_committed"
const STAGE_APPLYING := "participants_applying"
const STAGE_APPLIED := "participants_applied"
const STAGE_COMPLETED := "completed"
const STAGE_ABORTED := "aborted"

# Plan line 591: "the exact live participant order is the eight keys above."
const PARTICIPANT_ORDER: Array[String] = [
	"run",
	"desktop_consequence",
	"desktop_board",
	"profile",
	"localization",
	"audio",
	"route",
	"narrative",
]

# Plan line 591 freezes this exact detached New-Run context, with a matching canonical hash.
const NEW_RUN_INITIAL_CONTEXT := {
	"route_id": "opening",
	"dialogic_checkpoint": {},
	"active_app_id": null,
	"audio_context": {},
	"content_version": 1,
}

# Plan line 591: slot_id is exactly slot:1..slot:7, quick, or autosave.
const RESTORE_SLOT_ID := "slot:3"

var _storage
var _loader: FakeSourceLoader
var _journal
var _identity_root_store: ROOT_STORE
var _identity_file_ops: FakeFileOps
var _identity_issuer: ISSUER
var _transaction_receipts: Dictionary = {}


## The DECISION 9.5 source-loader contract, whole: exactly one method, which only re-reads. Every
## judgment about what it returns belongs to the journal. Programmable and spying, and -- like the
## session-1 fakes under DECISION 9.12's refinement -- it NEVER returns `not_implemented`, so an
## unarmed loader can never satisfy a DECISION 9.9 rejection assertion by accident.
class FakeSourceLoader extends RefCounted:
	var call_log: Array[Dictionary] = []
	var _armed_context: Dictionary = {}
	var _armed_sha256: String = ""
	var _armed_failure: StringName = &""

	func arm(context: Dictionary, context_sha256: String) -> void:
		_armed_context = context.duplicate(true)
		_armed_sha256 = context_sha256
		_armed_failure = &""

	func arm_failure(code: StringName) -> void:
		_armed_failure = code

	func load_context(source_locator: Variant) -> Dictionary:
		call_log.append({"source_locator": source_locator})
		if _armed_failure != &"":
			return {
				"ok": false,
				"code": _armed_failure,
				"message": "FakeSourceLoader: armed source failure",
			}
		if _armed_sha256 == "":
			return {
				"ok": false,
				"code": &"fake_source_not_armed",
				"message": "FakeSourceLoader: load_context called before arm()",
			}
		return {
			"ok": true,
			"value": {"context": _armed_context.duplicate(true), "context_sha256": _armed_sha256},
		}


func before_each() -> void:
	_storage = FAKE_STORAGE.new()
	_loader = FakeSourceLoader.new()
	_journal = JOURNAL.new()
	_identity_root_store = null
	_identity_file_ops = null
	_identity_issuer = null
	_transaction_receipts = {}


# ---------------------------------------------------------------------------------------------
# Retained skeleton probes (Step 1.1 first half). A load failure is a setup defect that invalidates
# RED, so these assertions stay for the life of the file.
# ---------------------------------------------------------------------------------------------

func test_continuation_journal_skeletons_load() -> void:
	for label: String in SKELETON_PATHS:
		var probe: Variant = DynamicScriptProbe.load_script(str(SKELETON_PATHS[label]))
		assert_true(probe.get("ok", false),
			"%s must parse and load: %s" % [label, str(probe.get("message", ""))])


# ---------------------------------------------------------------------------------------------
# Clause 36 -- external-journal exact schema (DEEP)
# ---------------------------------------------------------------------------------------------

func test_the_journal_document_and_operation_record_have_exactly_the_frozen_key_sets() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return
	if not _commit_new_run_intent(journal):
		return
	var restore_request: Variant = _restore_intent_request_for(_restore_transaction_id())
	var prepared_restore: Variant = journal.prepare_intent(restore_request)
	if not _require_ok(prepared_restore, "prepare_intent(restore)"):
		return
	if not _require_ok(journal.commit_intent(_intent_candidate(prepared_restore)), "commit_intent(restore)"):
		return

	var document: Variant = _stored_document()
	if document.is_empty():
		return
	var document_keys: Variant = document.keys()
	document_keys.sort()
	assert_eq(document_keys, DOCUMENT_KEYS,
		"plan line 555: the document is exactly {schema_version, operations}")
	assert_eq(document.get("schema_version"), 1, "schema_version is exactly 1")

	var base_document: Dictionary = (document as Dictionary).duplicate(true)
	var operations: Variant = base_document.get("operations", {}) as Dictionary
	var operation_ids: Array = operations.keys()
	operation_ids.sort()
	var expected_ids: Array = [_new_run_transaction_id(), _restore_transaction_id()]
	expected_ids.sort()
	assert_eq(operation_ids, expected_ids,
		"both new-run and restore operations are stored and no other operation ids are present")
	for id: String in operation_ids:
		var record: Variant = operations.get(id, {}) as Dictionary
		var record_keys: Variant = record.keys()
		record_keys.sort()
		assert_eq(record_keys, OPERATION_KEYS,
			"plan lines 558-588 freeze exactly these thirteen members for " + id)
		assert_eq(str(record.get("transaction_id", "")), id,
			"the operation's transaction_id is exactly its document key for " + id)

	# Each envelope member is exact-key checked; the remaining rows name wrong-type and meaningful
	# same-type value mutations rather than merely repeating the happy-path shape assertion.
	var document_profiles: Array[Dictionary] = [
		{"label": "missing schema_version", "mode": "erase", "member": "schema_version"},
		{"label": "missing operations", "mode": "erase", "member": "operations"},
		{"label": "extra envelope member", "mode": "extra"},
		{"label": "schema_version wrong type", "mode": "replace", "member": "schema_version", "value": "one"},
		{"label": "operations wrong type", "mode": "replace", "member": "operations", "value": []},
		{"label": "schema_version unsupported value", "mode": "replace", "member": "schema_version", "value": 2},
	]
	for profile: Dictionary in document_profiles:
		var malformed_document: Dictionary = base_document.duplicate(true)
		match str(profile["mode"]):
			"erase":
				malformed_document.erase(str(profile["member"]))
			"extra":
				malformed_document["rogue_member"] = true
			"replace":
				malformed_document[str(profile["member"])] = profile["value"]
		_assert_rejects_stored_document(malformed_document, str(profile["label"]))

	var first_txid: String = operation_ids[0]
	for member: String in OPERATION_KEYS:
		var missing_member: Dictionary = (operations[first_txid] as Dictionary).duplicate(true)
		missing_member.erase(member)
		_assert_rejects_operation_mutation(base_document, first_txid, missing_member,
			"operation missing exact member %s" % member)

	var extra_member: Dictionary = (operations[first_txid] as Dictionary).duplicate(true)
	extra_member["rogue_member"] = true
	_assert_rejects_operation_mutation(base_document, first_txid, extra_member,
		"operation with an extra member")

	var operation_profiles: Array[Dictionary] = [
		{"label": "transaction_id wrong type", "member": "transaction_id", "value": 7},
		{"label": "transaction issuer receipt wrong type", "member": "transaction_issuer_receipt", "value": "receipt"},
		{"label": "kind wrong type", "member": "kind", "value": []},
		{"label": "stage wrong type", "member": "stage", "value": []},
		{"label": "participant index wrong type", "member": "next_participant_index", "value": "0"},
		{"label": "participant receipt map wrong type", "member": "participant_receipts", "value": []},
		{"label": "transaction_id mismatches its map key", "member": "transaction_id", "value": "wrong-id"},
		{"label": "unknown operation kind", "member": "kind", "value": "alien-kind"},
		{"label": "unknown operation stage", "member": "stage", "value": "not_a_stage"},
		{"label": "negative participant index", "member": "next_participant_index", "value": -1},
		{"label": "participant index beyond eight", "member": "next_participant_index", "value": 9},
	]
	for profile: Dictionary in operation_profiles:
		var mutated_operation: Dictionary = (operations[first_txid] as Dictionary).duplicate(true)
		mutated_operation[str(profile["member"])] = profile["value"]
		_assert_rejects_operation_mutation(
			base_document, first_txid, mutated_operation, str(profile["label"]))

	var malformed_receipt_profiles: Array[Dictionary] = [
		{"label": "missing participant receipt key", "mode": "erase", "member": PARTICIPANT_ORDER[0]},
		{"label": "extra participant receipt key", "mode": "extra", "member": "rogue"},
		{"label": "participant receipt wrong type", "mode": "replace", "member": PARTICIPANT_ORDER[0]},
	]
	for profile: Dictionary in malformed_receipt_profiles:
		var mutated_operation: Dictionary = (operations[first_txid] as Dictionary).duplicate(true)
		var receipts: Dictionary = (mutated_operation["participant_receipts"] as Dictionary).duplicate(true)
		match str(profile["mode"]):
			"erase":
				receipts.erase(str(profile["member"]))
			"extra":
				receipts[str(profile["member"])] = null
			"replace":
				receipts[str(profile["member"])] = "not-a-receipt"
		mutated_operation["participant_receipts"] = receipts
		_assert_rejects_operation_mutation(
			base_document, first_txid, mutated_operation, str(profile["label"]))

	var blank_key_document: Dictionary = base_document.duplicate(true)
	var blank_key_operations: Dictionary = (blank_key_document["operations"] as Dictionary).duplicate(true)
	var blank_key_operation: Dictionary = (blank_key_operations[first_txid] as Dictionary).duplicate(true)
	blank_key_operations.erase(first_txid)
	blank_key_operation["transaction_id"] = ""
	blank_key_operations[""] = blank_key_operation
	blank_key_document["operations"] = blank_key_operations
	_assert_rejects_stored_document(blank_key_document, "blank operation map key and transaction_id")


func _assert_rejects_operation_mutation(base_document: Dictionary, transaction_id: String,
		mutated_operation: Dictionary, label: String) -> void:
	var malformed_document: Dictionary = base_document.duplicate(true)
	var malformed_operations: Dictionary = (malformed_document["operations"] as Dictionary).duplicate(true)
	malformed_operations[transaction_id] = mutated_operation
	malformed_document["operations"] = malformed_operations
	_assert_rejects_stored_document(malformed_document, label)


func _assert_rejects_stored_document(document: Dictionary, label: String) -> void:
	_storage.seed(JOURNAL_PATH, JSON.stringify(document))
	_storage.restart()
	var durable_before: Dictionary = _storage.snapshot()
	var restarted: Object = JOURNAL.new()
	if not _require_ok(restarted.configure(_storage, _loader), "configure restart for %s" % label):
		return
	var rejected: Dictionary = restarted.prepare_intent(_new_run_intent_request_for("schema-validated-transaction"))
	_assert_rejected(rejected,
		"malformed document must not pass schema: " + label)
	assert_eq(_storage.write_count, 0,
		"schema rejection must not perform a durable write: " + label)
	assert_eq(_storage.snapshot(), durable_before,
		"schema rejection must preserve the malformed durable bytes: " + label)


func test_every_legal_and_illegal_stage_transition_is_enforced() -> void:
	var txid_index: int = 0
	for profile: Dictionary in _stage_transition_matrix():
		var txid := "tx-stage-matrix-%d" % txid_index
		txid_index += 1
		_storage.restart()
		var scenario: Object = JOURNAL.new()
		if not _require_ok(scenario.configure(_storage, _loader),
				"configure stage transition matrix journal for %s" % profile.get("label", "")):
			return
		if not _journal_with_stage(
				scenario, txid, str(profile.get("from_stage", "")),
				bool(profile.get("from_full_participants", false)),
				bool(profile.get("with_diagnostic", false)),
				int(profile.get("seeded_participant_count", 0))):
			return
		var request: Dictionary = _advance_request_for_stage_transition(txid, profile)
		var result: Dictionary = scenario.advance(request)
		if profile.get("legal", false):
			if not _require_ok(result, "legal stage transition should pass: %s" % profile.get("label", "")):
				return
			var record: Dictionary = _operation_record_for(txid)
			if record.is_empty():
				return
			assert_eq(record.get("stage"), profile.get("to_stage", ""),
				"legal stage transition records the requested stage")
		else:
			_assert_rejected(result,
				"illegal stage transition must fail: %s" % profile.get("label", ""))


func test_stage_transition_evidence_is_permitted_only_at_the_frozen_edges() -> void:
	var scenario_index: int = 0
	for evidence_kind: String in ["allocation", "participant"]:
		for transition: Dictionary in _stage_transition_matrix():
			var txid := "tx-evidence-%s-%d" % [evidence_kind, scenario_index]
			scenario_index += 1
			_storage.restart()
			var scenario: Object = JOURNAL.new()
			if not _require_ok(scenario.configure(_storage, _loader),
					"configure %s evidence cross for %s" % [evidence_kind, transition.get("label", "")]):
				return
			if not _journal_with_stage(
					scenario, txid, str(transition["from_stage"]), false, false, 0):
				return
			var request: Dictionary = _advance_request_for_stage_transition(txid, transition)
			if evidence_kind == "allocation":
				request["allocation_receipt"] = _allocation_receipt("cross-%s" % txid)
			else:
				request["participant_name"] = PARTICIPANT_ORDER[0]
				request["participant_receipt"] = _participant_receipt(PARTICIPANT_ORDER[0])
			var only_frozen_edge: bool = (
				evidence_kind == "allocation"
				and transition["from_stage"] == STAGE_INTENT
				and transition["to_stage"] == STAGE_ALLOCATED
			) or (
				evidence_kind == "participant"
				and transition["from_stage"] == STAGE_APPLYING
				and transition["to_stage"] == STAGE_APPLYING
			)
			var writes_before: int = _storage.write_count
			var durable_before: Dictionary = _stored_document()
			var result: Dictionary = scenario.advance(request)
			if only_frozen_edge:
				if not _require_ok(result,
						"%s evidence is legal only at %s" % [evidence_kind, transition.get("label", "")]):
					return
				assert_eq(_operation_record_for(txid).get("stage"), transition["to_stage"],
					"the frozen %s evidence edge records its requested stage" % evidence_kind)
			else:
				_assert_rejected(result,
					"%s evidence is forbidden at %s" % [evidence_kind, transition.get("label", "")])
				assert_eq(_storage.write_count, writes_before,
					"forbidden %s evidence conflicts before storage mutation" % evidence_kind)
				assert_eq(_stored_document(), durable_before,
					"forbidden %s evidence preserves durable bytes" % evidence_kind)


func test_new_run_and_restore_have_mutually_exclusive_source_and_context_fields() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return

	# Plan line 591: "New Run requires source_locator=null and exact detached initial_context ...
	# restore requires both initial-context fields null."
	var new_run_with_locator: Variant = _new_run_intent_request()
	new_run_with_locator["source_locator"] = _restore_locator()
	_assert_rejected(journal.prepare_intent(new_run_with_locator),
		"plan line 591: New Run requires source_locator = null")

	var restore_with_context: Variant = _restore_intent_request()
	restore_with_context["initial_context"] = NEW_RUN_INITIAL_CONTEXT.duplicate(true)
	_assert_rejected(journal.prepare_intent(restore_with_context),
		"plan line 591: restore requires both initial-context fields null")

	# Plan line 780 freezes the request member set exactly.
	for missing: String in PREPARE_INTENT_KEYS:
		var short_request: Variant = _new_run_intent_request()
		short_request.erase(missing)
		_assert_rejected(journal.prepare_intent(short_request),
			"plan line 780: prepare_intent missing %s is exact-key-invalid" % missing)


# ---------------------------------------------------------------------------------------------
# Clause 37 -- intent before allocation (breadth)
# ---------------------------------------------------------------------------------------------

func test_the_intent_must_be_committed_before_any_allocation_is_recorded() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return

	# Plan line 591: "The journal first commits intent_committed, then the issuer allocation may
	# commit." Advancing to the allocated stage without a committed intent has no operation to
	# advance and must be refused before anything is stored.
	var writes_before: Variant = _storage.write_count
	var premature: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_INTENT, STAGE_ALLOCATED, 0)
	premature["allocation_receipt"] = _allocation_receipt()
	_assert_rejected(journal.advance(premature),
		"plan line 591: an allocation cannot precede its committed intent")
	assert_eq(_storage.write_count, writes_before,
		"plan line 780: the refusal happens before storage mutation")

	# Prepare alone is mutation-free; only commit_intent installs the candidate.
	var prepared: Variant = journal.prepare_intent(_new_run_intent_request())
	if not _require_ok(prepared, "prepare_intent"):
		return
	assert_eq(_storage.write_count, writes_before,
		"plan line 780: prepare_intent returns a mutation-free candidate")


# ---------------------------------------------------------------------------------------------
# Clause 38 -- legal and illegal stage edges (breadth + the full participant walk, DECISION 10.4)
# ---------------------------------------------------------------------------------------------

func test_the_eight_participants_apply_in_exactly_the_frozen_order() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return

	if not _require_ok(journal.advance(_advance_request(
			_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_APPLYING, 0)),
			"advance to participants_applying"):
		return

	for index: int in range(PARTICIPANT_ORDER.size()):
		var participant: Variant = PARTICIPANT_ORDER[index]
		var wrong_participant: String = PARTICIPANT_ORDER[(index + 1) % PARTICIPANT_ORDER.size()]
		var wrong_request: Dictionary = _advance_request(
			_new_run_transaction_id(), STAGE_APPLYING, STAGE_APPLYING, index)
		wrong_request["participant_name"] = wrong_participant
		wrong_request["participant_receipt"] = _participant_receipt(wrong_participant)
		var writes_before_wrong_name: int = _storage.write_count
		var durable_before_wrong_name: Dictionary = _stored_document()
		_assert_rejected(journal.advance(wrong_request),
			"index %d admits only exact next participant %s, not %s" % [
				index, participant, wrong_participant])
		assert_eq(_storage.write_count, writes_before_wrong_name,
			"wrong participant at index %d conflicts before storage mutation" % index)
		assert_eq(_stored_document(), durable_before_wrong_name,
			"wrong participant at index %d preserves durable bytes" % index)

		var request: Variant = _advance_request(
			_new_run_transaction_id(), STAGE_APPLYING, STAGE_APPLYING, index)
		request["participant_name"] = participant
		request["participant_receipt"] = _participant_receipt(participant)
		if not _require_ok(journal.advance(request), "apply participant %s" % participant):
			return

		var record: Variant = _operation_record()
		if record.is_empty():
			return
		# Plan line 591: "Before each apply, all lower-index receipts must be nonnull and all
		# current/higher receipts null; after an apply, its exact receipt is durably recorded and
		# the index advances before the next participant."
		assert_eq(int(record.get("next_participant_index", -1)), index + 1,
			"the index advances to %d after applying %s" % [index + 1, participant])
		var receipts: Variant = record.get("participant_receipts", {}) as Dictionary
		for lower: int in range(index + 1):
			assert_true(receipts.get(PARTICIPANT_ORDER[lower]) != null,
				"%s is recorded once applied" % PARTICIPANT_ORDER[lower])
		for higher: int in range(index + 1, PARTICIPANT_ORDER.size()):
			assert_true(receipts.get(PARTICIPANT_ORDER[higher]) == null,
				"%s stays null until its turn" % PARTICIPANT_ORDER[higher])

	# Plan line 591: "participants_applied requires index 8 and every receipt nonnull."
	if not _require_ok(journal.advance(_advance_request(
			_new_run_transaction_id(), STAGE_APPLYING, STAGE_APPLIED, 8)),
			"advance to participants_applied"):
		return
	var applied: Variant = _operation_record()
	if applied.is_empty():
		return
	assert_eq(int(applied.get("next_participant_index", -1)), 8,
		"plan line 591: participants_applied requires index 8")
	var applied_receipts: Variant = applied.get("participant_receipts", {}) as Dictionary
	for participant: String in PARTICIPANT_ORDER:
		assert_true(applied_receipts.get(participant) != null,
			"plan line 591: %s must be nonnull at participants_applied" % participant)


func test_a_skipped_participant_index_is_refused() -> void:
	var journal: Variant = _applying_journal()
	if journal == null:
		return
	var writes_before: Variant = _storage.write_count

	# Index 0 is next; index 1 skips `run`.
	var skipped: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_APPLYING, STAGE_APPLYING, 1)
	skipped["participant_name"] = PARTICIPANT_ORDER[1]
	skipped["participant_receipt"] = _participant_receipt(PARTICIPANT_ORDER[1])
	_assert_rejected(journal.advance(skipped),
		"plan line 780: a skipped participant index conflicts")
	assert_eq(_storage.write_count, writes_before,
		"plan line 780: the skipped index conflicts BEFORE storage mutation")

	# The right index but the wrong participant name is equally refused: plan line 780 says the
	# participant fields are nonnull "only for the exact next ordered participant".
	var wrong_name: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_APPLYING, STAGE_APPLYING, 0)
	wrong_name["participant_name"] = PARTICIPANT_ORDER[3]
	wrong_name["participant_receipt"] = _participant_receipt(PARTICIPANT_ORDER[3])
	_assert_rejected(journal.advance(wrong_name),
		"plan line 780: index 0 admits only the exact next ordered participant")


func test_an_illegal_backward_stage_edge_is_refused() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return
	var writes_before: Variant = _storage.write_count

	# Plan line 593: "identity_allocation_committed is irreversible; recovery from there can only
	# advance through participants_applying, participants_applied, and completed."
	_assert_rejected(journal.advance(_advance_request(
		_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_INTENT, 0)),
		"plan line 593: identity_allocation_committed may not fall back to intent_committed")
	_assert_rejected(journal.advance(_advance_request(
		_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_COMPLETED, 0)),
		"plan line 593: recovery may not jump straight to completed")
	assert_eq(_storage.write_count, writes_before,
		"plan line 780: an illegal stage conflicts before storage mutation")


# ---------------------------------------------------------------------------------------------
# Clause 39 -- source locator / hash mismatch (breadth)
# ---------------------------------------------------------------------------------------------

func test_a_restore_source_that_no_longer_hashes_the_same_is_refused() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return

	# Plan line 591: "Reload must reproduce all four values, not merely find a compatible slot."
	_loader.arm({"restored": true}, "a".repeat(64))
	var request: Variant = _restore_intent_request()
	var prepared: Variant = journal.prepare_intent(request)
	if not _require_ok(prepared, "prepare_intent for restore"):
		return
	if not _require_ok(journal.commit_intent(_intent_candidate(prepared)), "commit_intent"):
		return

	_loader.arm_failure(&"fake_source_missing")
	_assert_rejected(
		journal.reconcile_startup(_restore_transaction_id(), _real_issuer()),
		"plan line 593: a proven missing restore source cannot reconcile forward")

	# DECISION 9.5: the loader is consulted only for restore, never for new_run.
	assert_true(_loader.call_log.size() > 0,
		"DECISION 9.5: reconcile_startup re-reads a restore source through load_context")


func test_a_new_run_context_is_rehashed_without_consulting_the_loader() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return
	if not _commit_new_run_intent(journal):
		return

	var calls_before: Variant = _loader.call_log.size()
	journal.reconcile_startup(_new_run_transaction_id(), _real_issuer())
	# DECISION 9.5: "for new_run the journal recomputes initial_context_sha256 over its own
	# retained initial_context" and never consults the loader.
	assert_eq(_loader.call_log.size(), calls_before,
		"DECISION 9.5: a new_run startup never calls load_context")

	# A New-Run context whose hash does not match its bytes is refused at intent time.
	var mismatched: Variant = _new_run_intent_request()
	mismatched["initial_context_sha256"] = "b".repeat(64)
	_assert_rejected(journal.prepare_intent(mismatched),
		"plan line 591: the New-Run context requires a matching canonical hash")


# ---------------------------------------------------------------------------------------------
# Clause 40 -- duplicate equality (DEEP)
# ---------------------------------------------------------------------------------------------

func test_identical_replays_return_the_retained_operation_at_every_stage() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return

	# prepare_intent is mutation-free, so an identical replay must return an identical candidate.
	var request: Variant = _new_run_intent_request()
	var first: Variant = journal.prepare_intent(request.duplicate(true))
	if not _require_ok(first, "prepare_intent"):
		return
	var replayed: Variant = journal.prepare_intent(request.duplicate(true))
	if not _require_ok(replayed, "identical prepare_intent replay"):
		return
	assert_eq(replayed.get("value"), first.get("value"),
		"an identical prepare_intent replay returns an identical candidate")

	# commit_intent installs "only that exact candidate" (plan line 780); replaying it is a no-op
	# that returns the retained operation rather than a second install.
	var candidate: Variant = _intent_candidate(first)
	var committed: Variant = journal.commit_intent(candidate.duplicate(true))
	if not _require_ok(committed, "commit_intent"):
		return
	var writes_after_commit: Variant = _storage.write_count
	var recommitted: Variant = journal.commit_intent(candidate.duplicate(true))
	if not _require_ok(recommitted, "identical commit_intent replay"):
		return
	assert_eq(recommitted.get("value"), committed.get("value"),
		"plan line 780: an identical commit_intent replay returns the retained operation")
	assert_eq(_storage.write_count, writes_after_commit,
		"an identical commit_intent replay writes nothing further")

	# Plan line 780: "Duplicate identical advancement returns the retained operation."
	var advance: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_INTENT, STAGE_ALLOCATED, 0)
	advance["allocation_receipt"] = _allocation_receipt()
	var advanced: Variant = journal.advance(advance.duplicate(true))
	if not _require_ok(advanced, "advance to identity_allocation_committed"):
		return
	var writes_after_advance: Variant = _storage.write_count
	var readvanced: Variant = journal.advance(advance.duplicate(true))
	if not _require_ok(readvanced, "identical advance replay"):
		return
	assert_eq(readvanced.get("value"), advanced.get("value"),
		"plan line 780: duplicate identical advancement returns the retained operation")
	assert_eq(_storage.write_count, writes_after_advance,
		"a duplicate identical advancement writes nothing further")


# ---------------------------------------------------------------------------------------------
# Clause 41 -- changed transaction conflict (DEEP)
# ---------------------------------------------------------------------------------------------

func test_every_changed_advancement_family_conflicts_before_storage_mutation() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return

	# Plan line 780 names exactly five conflict families: "a skipped index, overwritten receipt,
	# changed fingerprint, illegal stage, or different diagnostic conflicts before storage
	# mutation." Each is driven from the same committed, allocated operation.
	var families: Array[Dictionary] = [
		{
			"label": "skipped index",
			"mutate": {"expected_next_participant_index": 4},
		},
		{
			"label": "overwritten receipt",
			"mutate": {"allocation_receipt": _allocation_receipt("a-different-allocation")},
		},
		{
			"label": "changed fingerprint",
			"mutate": {"request_fingerprint": "c".repeat(64)},
		},
		{
			"label": "illegal stage",
			"mutate": {"next_stage": STAGE_ABORTED},
		},
		{
			"label": "different diagnostic",
			"mutate": {
				"next_stage": STAGE_ALLOCATED,
				"failure": _failure("a_different_diagnostic", "a different diagnostic"),
			},
		},
	]

	for family: Dictionary in families:
		var writes_before: Variant = _storage.write_count
		var request: Variant = _advance_request(
			_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_APPLYING, 0)
		var mutate: Variant = family.get("mutate", {}) as Dictionary
		for key: String in mutate:
			request[key] = mutate[key]
		var label: Variant = str(family.get("label", ""))
		_assert_rejected(journal.advance(request),
			"plan line 780: %s conflicts" % label)
		assert_eq(_storage.write_count, writes_before,
			"plan line 780: %s conflicts BEFORE storage mutation" % label)

	# Plan line 780 also freezes the advance() request member set exactly.
	for missing: String in ADVANCE_KEYS:
		var short_request: Variant = _advance_request(
			_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_APPLYING, 0)
		short_request.erase(missing)
		_assert_rejected(journal.advance(short_request),
			"plan line 780: advance missing %s is exact-key-invalid" % missing)


# ---------------------------------------------------------------------------------------------
# Clause 42 -- incomplete listing (breadth, complete at breadth)
# ---------------------------------------------------------------------------------------------

func test_list_incomplete_returns_only_nonterminal_operations() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return

	# Plan line 593: "Startup lists nonterminal operations before input."
	var listed: Variant = journal.list_incomplete()
	if not _require_ok(listed, "list_incomplete"):
		return
	var incomplete: Variant = listed.get("value", []) as Array
	assert_eq(incomplete.size(), 1,
		"an allocated, unfinished operation is nonterminal and must be listed")

	if not _require_ok(journal.advance(_advance_request(
			_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_APPLYING, 0)),
			"advance to participants_applying"):
		return
	if not _require_ok(journal.advance(_advance_request(
			_new_run_transaction_id(), STAGE_APPLYING, STAGE_COMPLETED, 8)),
			"advance to completed"):
		return
	var after: Variant = journal.list_incomplete()
	if not _require_ok(after, "list_incomplete after completion"):
		return
	assert_eq((after.get("value", []) as Array).size(), 0,
		"plan line 593: a completed operation is terminal and is not listed")


# ---------------------------------------------------------------------------------------------
# Clause 43 -- startup forward reconciliation (SHALLOW -> dwm-p2r.16.1)
# ---------------------------------------------------------------------------------------------

func test_startup_reconciles_a_clean_restart_forward() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return

	# A genuine process restart over the same stored bytes: leases drop, documents remain.
	_storage.restart()
	var restarted: Variant = JOURNAL.new()
	if not _require_ok(restarted.configure(_storage, _loader), "configure after restart"):
		return

	var reconciled: Variant = restarted.reconcile_startup(_new_run_transaction_id(), _real_issuer())
	if not _require_ok(reconciled, "reconcile_startup after a clean restart"):
		return
	var record: Variant = _operation_record()
	if record.is_empty():
		return
	# Plan line 593: recovery "can only advance through participants_applying, participants_applied,
	# and completed" -- it never rewinds and never relabels.
	assert_ne(record.get("stage"), STAGE_ABORTED,
		"plan line 593: startup never relabels an allocated operation aborted")
	assert_eq(record.get("stage"), STAGE_ALLOCATED,
		"a clean restart leaves the retained forward stage untouched")


func test_startup_reconciliation_is_no_op_for_terminal_operations() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return
	if not _require_ok(journal.advance(_advance_request(
			_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_COMPLETED, 8)),
			"advance allocated to completed before terminal startup"):
		return
	var completed_snapshot_before: Dictionary = _stored_document()
	if completed_snapshot_before.is_empty():
		return

	_storage.restart()
	var completed_restart: Variant = JOURNAL.new()
	if not _require_ok(completed_restart.configure(_storage, _loader), "configure completed restart"):
		return
	var completed_writes_before: Variant = _storage.write_count
	if not _require_ok(completed_restart.reconcile_startup(_new_run_transaction_id(), _real_issuer()),
			"reconcile_startup keeps a completed terminal stage"):
		return
	assert_eq(_storage.write_count, completed_writes_before,
		"reconcile_startup on completed does not write")
	var completed_snapshot_after: Dictionary = _stored_document()
	assert_eq(completed_snapshot_after, completed_snapshot_before,
		"completed startup must preserve a terminal document exactly")

	var aborted: Variant = _configured_journal()
	if aborted == null:
		return
	var aborted_txid: String = "transaction-startup-aborted"
	var aborted_request: Dictionary = _new_run_intent_request_for(aborted_txid)
	var prepared: Dictionary = aborted.prepare_intent(aborted_request)
	if not _require_ok(prepared, "prepare_intent for aborted startup"):
		return
	if not _require_ok(aborted.commit_intent(_intent_candidate(prepared)), "commit_intent for aborted startup"):
		return
	var abort: Dictionary = _advance_request(
		aborted_txid, STAGE_INTENT, STAGE_ABORTED, 0)
	abort["failure"] = _failure("source_proof_failed", "terminal startup no-op path")
	if not _require_ok(aborted.advance(abort), "advance to aborted for startup no-op"):
		return
	var aborted_snapshot_before: Dictionary = _stored_document()
	if aborted_snapshot_before.is_empty():
		return

	_storage.restart()
	var aborted_restart: Variant = JOURNAL.new()
	if not _require_ok(aborted_restart.configure(_storage, _loader), "configure aborted restart"):
		return
	var aborted_writes_before: Variant = _storage.write_count
	if not _require_ok(aborted_restart.reconcile_startup(aborted_txid, _real_issuer()),
			"reconcile_startup keeps an aborted terminal stage"):
		return
	assert_eq(_storage.write_count, aborted_writes_before,
		"reconcile_startup on aborted does not write")
	var aborted_snapshot_after: Dictionary = _stored_document()
	assert_eq(aborted_snapshot_after, aborted_snapshot_before,
		"aborted startup must preserve a terminal document exactly")


func test_startup_rejects_malformed_issued_transaction_receipts() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return
	if not _commit_new_run_intent(journal):
		return

	var document: Dictionary = _stored_document()
	if document.is_empty():
		return
	var operations: Dictionary = document.get("operations", {}) as Dictionary
	if not operations.has(_new_run_transaction_id()):
		return
	var malformed_operations: Dictionary = operations.duplicate(true)
	malformed_operations[_new_run_transaction_id()] = (operations.get(_new_run_transaction_id(), {}) as Dictionary).duplicate(true)
	malformed_operations[_new_run_transaction_id()]["transaction_issuer_receipt"] = "not-a-receipt"
	document["operations"] = malformed_operations
	_storage.seed(JOURNAL_PATH, JSON.stringify(document))

	_storage.restart()
	var restarted: Variant = JOURNAL.new()
	if not _require_ok(restarted.configure(_storage, _loader), "configure for malformed receipt startup"):
		return
	var reconciled: Variant = restarted.reconcile_startup(_new_run_transaction_id(), _real_issuer())
	_assert_rejected(reconciled, "reconcile_startup rejects malformed transaction_issuer_receipt")


func test_startup_proves_the_original_restore_source_before_clearing_an_identical_diagnostic() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return
	var txid: String = _restore_transaction_id()
	var prepared: Dictionary = journal.prepare_intent(_restore_intent_request_for(txid))
	if not _require_ok(prepared, "prepare restore intent for diagnostic reconciliation"):
		return
	if not _require_ok(journal.commit_intent(_intent_candidate(prepared)),
			"commit restore intent for diagnostic reconciliation"):
		return
	var allocate: Dictionary = _advance_request_for_transaction(
		txid, STAGE_INTENT, STAGE_ALLOCATED, 0)
	allocate["allocation_receipt"] = _allocation_receipt("retained-restore-allocation")
	if not _require_ok(journal.advance(allocate), "allocate restore before diagnostic reconciliation"):
		return

	var retained_before: Dictionary = _operation_record_for(txid)
	if retained_before.is_empty():
		return
	var diagnostic: Dictionary = _advance_request_for_transaction(
		txid, STAGE_ALLOCATED, STAGE_ALLOCATED, 0)
	diagnostic["failure"] = _failure(
		"source_unprovable", "source state was unrecoverable during recovery")
	if not _require_ok(journal.advance(diagnostic), "record startup diagnostic"):
		return
	var writes_after_diagnostic: int = _storage.write_count
	var document_after_diagnostic: Dictionary = _stored_document()

	if not _require_ok(journal.advance(diagnostic.duplicate(true)),
			"replay the identical retained diagnostic"):
		return
	assert_eq(_storage.write_count, writes_after_diagnostic,
		"an identical diagnostic replay returns retained bytes without another write")
	var mismatched: Dictionary = diagnostic.duplicate(true)
	mismatched["failure"] = _failure("source_unprovable", "a different diagnostic body")
	_assert_rejected(journal.advance(mismatched),
		"a startup retry with a different diagnostic must be rejected")
	assert_eq(_storage.write_count, writes_after_diagnostic,
		"a different diagnostic conflicts before storage mutation")

	_storage.restart()
	var restarted: Variant = JOURNAL.new()
	if not _require_ok(restarted.configure(_storage, _loader), "configure after diagnostic restart"):
		return
	_loader.arm_failure(&"fake_source_missing")
	var calls_before_failed_proof: int = _loader.call_log.size()
	var failed_proof: Dictionary = restarted.reconcile_startup(txid, _real_issuer())
	assert_false(failed_proof.get("ok", true),
		"a retained diagnostic must not bypass load_context proof on startup")
	if failed_proof.get("ok", false):
		return
	assert_eq(_loader.call_log.size(), calls_before_failed_proof + 1,
		"restore reconciliation re-reads the exact original source locator")
	assert_eq(_loader.call_log[-1].get("source_locator"), retained_before.get("source_locator"),
		"load_context receives the byte-identical journaled source locator")
	assert_eq(_storage.write_count, 0,
		"failed source proof cannot clear or rewrite the retained diagnostic")
	assert_eq(_stored_document(), document_after_diagnostic,
		"failed source proof preserves the durable journal byte-for-byte")
	var still_diagnostic: Dictionary = _operation_record_for(txid)
	assert_eq(still_diagnostic.get("failure"), diagnostic.get("failure"),
		"failed proof retains the identical diagnostic bytes")
	assert_eq(still_diagnostic.get("stage"), STAGE_ALLOCATED,
		"failed proof never relabels the irreversible operation terminal")
	assert_eq(still_diagnostic.get("allocation_receipt"), retained_before.get("allocation_receipt"),
		"failed proof preserves the irreversible allocation receipt byte-for-byte")
	var blocked: Dictionary = restarted.list_incomplete()
	if not _require_ok(blocked, "list incomplete while diagnostic blocks startup"):
		return
	assert_eq((blocked.get("value", []) as Array).size(), 1,
		"the diagnosed nonterminal operation remains an input-blocking startup obligation")

	_loader.arm({"restored": true}, str((_restore_locator()).get("document_sha256", "")))
	var writes_before_clear: int = _storage.write_count
	var cleared: Dictionary = restarted.reconcile_startup(txid, _real_issuer())
	if not _require_ok(cleared, "reconcile_startup after byte-identical restore proof"):
		return
	assert_eq(_loader.call_log.size(), calls_before_failed_proof + 2,
		"successful diagnostic clearing performs a fresh source proof")
	assert_eq(_storage.write_count, writes_before_clear + 1,
		"successful source proof durably clears the retained diagnostic exactly once")
	var record: Dictionary = _operation_record_for(txid)
	assert_eq(record.get("stage"), STAGE_ALLOCATED,
		"clearing the diagnostic preserves the irreversible forward stage")
	assert_eq(record.get("failure"), null,
		"byte-identical source proof clears only the retained diagnostic")
	assert_eq(record.get("allocation_receipt"), retained_before.get("allocation_receipt"),
		"diagnostic clearing preserves allocation receipt bytes")
	if not _require_ok(restarted.advance(_advance_request_for_transaction(
			txid, STAGE_ALLOCATED, STAGE_APPLYING, 0)),
			"resume normal forward advancement after diagnostic proof"):
		return
	assert_eq(_operation_record_for(txid).get("stage"), STAGE_APPLYING,
		"normal forward advancement resumes only after the diagnostic is proven and cleared")


func test_new_run_proof_clears_diagnostics_at_every_nonterminal_post_allocation_stage() -> void:
	var profiles: Array[Dictionary] = [
		{"stage": STAGE_ALLOCATED, "participant_count": 0},
		{"stage": STAGE_APPLYING, "participant_count": 3},
		{"stage": STAGE_APPLIED, "participant_count": PARTICIPANT_ORDER.size()},
	]
	var profile_index: int = 0
	for profile: Dictionary in profiles:
		var txid := "tx-diagnostic-stage-%d" % profile_index
		profile_index += 1
		_storage.restart()
		var scenario: Object = JOURNAL.new()
		if not _require_ok(scenario.configure(_storage, _loader),
				"configure diagnostic stage scenario %s" % profile["stage"]):
			return
		var stage: String = str(profile["stage"])
		var participant_count: int = int(profile["participant_count"])
		if stage == STAGE_ALLOCATED:
			if not _journal_with_stage(scenario, txid, STAGE_ALLOCATED):
				return
		else:
			if not _journal_with_stage(
					scenario, txid, STAGE_APPLYING,
					participant_count == PARTICIPANT_ORDER.size(), false, participant_count):
				return
			if stage == STAGE_APPLIED:
				if not _require_ok(scenario.advance(_advance_request_for_transaction(
						txid, STAGE_APPLYING, STAGE_APPLIED, PARTICIPANT_ORDER.size())),
						"advance fully applied diagnostic scenario"):
					return

		var retained_before: Dictionary = _operation_record_for(txid)
		if retained_before.is_empty():
			return
		var diagnostic: Dictionary = _advance_request_for_transaction(
			txid, stage, stage, participant_count)
		diagnostic["failure"] = _failure(
			"source_unprovable", "source proof unavailable at %s" % stage)
		if not _require_ok(scenario.advance(diagnostic),
				"record irreversible diagnostic at %s" % stage):
			return
		var diagnosed: Dictionary = _operation_record_for(txid)
		assert_eq(diagnosed.get("stage"), stage,
			"a diagnostic never relabels %s terminal" % stage)
		assert_eq(diagnosed.get("next_participant_index"), participant_count,
			"a diagnostic preserves the participant index at %s" % stage)
		assert_eq(diagnosed.get("allocation_receipt"), retained_before.get("allocation_receipt"),
			"a diagnostic preserves allocation receipt bytes at %s" % stage)
		assert_eq(diagnosed.get("participant_receipts"), retained_before.get("participant_receipts"),
			"a diagnostic preserves participant receipt bytes at %s" % stage)
		assert_eq(diagnosed.get("failure"), diagnostic.get("failure"),
			"the exact typed diagnostic is durable at %s" % stage)

		var different: Dictionary = diagnostic.duplicate(true)
		different["failure"] = _failure(
			"source_unprovable", "different diagnostic at %s" % stage)
		var writes_before_conflict: int = _storage.write_count
		var durable_before_conflict: Dictionary = _stored_document()
		_assert_rejected(scenario.advance(different),
			"a different retained diagnostic conflicts at %s" % stage)
		assert_eq(_storage.write_count, writes_before_conflict,
			"different diagnostic conflicts before storage mutation at %s" % stage)
		assert_eq(_stored_document(), durable_before_conflict,
			"different diagnostic preserves durable bytes at %s" % stage)

		var incomplete: Dictionary = scenario.list_incomplete()
		if not _require_ok(incomplete, "list diagnosed operation at %s" % stage):
			return
		var listed: bool = false
		for operation: Dictionary in (incomplete.get("value", []) as Array):
			if str(operation.get("transaction_id", "")) == txid:
				listed = true
		assert_true(listed,
			"the diagnosed %s operation remains an input-blocking startup obligation" % stage)

		_storage.restart()
		var restarted: Object = JOURNAL.new()
		if not _require_ok(restarted.configure(_storage, _loader),
				"configure New-Run diagnostic restart at %s" % stage):
			return
		var loader_calls_before: int = _loader.call_log.size()
		if not _require_ok(restarted.reconcile_startup(txid, _real_issuer()),
				"rehash journaled New-Run context at %s" % stage):
			return
		assert_eq(_loader.call_log.size(), loader_calls_before,
			"New-Run diagnostic proof never calls the restore source loader")
		assert_eq(_storage.write_count, 1,
			"successful New-Run proof durably clears one diagnostic at %s" % stage)
		var cleared: Dictionary = _operation_record_for(txid)
		assert_eq(cleared.get("failure"), null,
			"successful New-Run context proof clears the diagnostic at %s" % stage)
		assert_eq(cleared.get("stage"), stage,
			"diagnostic clearing preserves the forward stage %s" % stage)
		assert_eq(cleared.get("allocation_receipt"), retained_before.get("allocation_receipt"),
			"diagnostic clearing preserves allocation receipt bytes at %s" % stage)


# ---------------------------------------------------------------------------------------------
# Clause 44 -- pre-allocation abort (breadth)
# ---------------------------------------------------------------------------------------------

func test_a_pre_allocation_failure_aborts_with_a_typed_failure_and_no_live_mutation() -> void:
	var journal: Variant = _configured_journal()
	if journal == null:
		return
	if not _commit_new_run_intent(journal):
		return

	# Plan line 593: "Before allocation, a proven missing/hash-changed restore source or mismatched
	# New-Run context records `aborted` with typed failure and no live mutation."
	var abort: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_INTENT, STAGE_ABORTED, 0)
	abort["failure"] = _failure("source_proof_failed", "the retained context no longer matches")
	if not _require_ok(journal.advance(abort), "pre-allocation abort"):
		return

	var record: Variant = _operation_record()
	if record.is_empty():
		return
	assert_eq(record.get("stage"), STAGE_ABORTED, "a pre-allocation abort reaches `aborted`")
	assert_eq(record.get("allocation_receipt"), null,
		"plan line 593: nothing was allocated, so allocation_receipt stays null")
	var failure: Variant = record.get("failure", {}) as Dictionary
	var failure_keys: Variant = failure.keys()
	failure_keys.sort()
	assert_eq(failure_keys, ["code", "details", "message"],
		"plan line 591: failure is exactly {code, message, details}")
	assert_false(str(failure.get("code", "")).is_empty(),
		"plan line 591: the failure code is nonblank")
	assert_false(str(failure.get("message", "")).is_empty(),
		"plan line 591: the failure message is nonblank")

	# Plan line 780: a nonnull failure "either accompanies pre-allocation `aborted`" -- so an abort
	# without one is not a legal edge.
	var untyped: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_INTENT, STAGE_ABORTED, 0)
	_assert_rejected(journal.advance(untyped),
		"plan line 780: `aborted` requires a typed failure")


# ---------------------------------------------------------------------------------------------
# Clause 45 -- irreversible allocation retention, JOURNAL SIDE ONLY (breadth; DECISION 10.2)
# ---------------------------------------------------------------------------------------------

func test_an_allocated_operation_retains_its_receipt_and_can_never_be_aborted() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return
	var allocated: Variant = _operation_record()
	if allocated.is_empty():
		return
	var retained: Variant = allocated.get("allocation_receipt")

	# Plan line 593: "identity_allocation_committed is irreversible." Every post-allocation stage
	# must keep the same receipt, byte for byte, and none of them may become `aborted`.
	var allocated_abort: Dictionary = _advance_request(
		_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_ABORTED, 0)
	allocated_abort["failure"] = _failure("late_abort", "an abort attempted at allocation")
	var allocated_writes_before: int = _storage.write_count
	var allocated_durable_before: Dictionary = _stored_document()
	_assert_rejected(journal.advance(allocated_abort),
		"plan line 593: identity_allocation_committed may never be relabelled aborted")
	assert_eq(_storage.write_count, allocated_writes_before,
		"the refused allocated-stage abort mutates nothing")
	assert_eq(_stored_document(), allocated_durable_before,
		"the refused allocated-stage abort preserves durable bytes")
	assert_eq(_operation_record().get("allocation_receipt"), retained,
		"the allocated-stage abort preserves allocation receipt bytes")

	var forward: Array[String] = [STAGE_APPLYING, STAGE_APPLIED, STAGE_COMPLETED]
	var current: Variant = STAGE_ALLOCATED
	for next_stage: String in forward:
		var index: Variant = 0 if next_stage == STAGE_APPLYING else 8
		if not _require_ok(journal.advance(_advance_request(
				_new_run_transaction_id(), current, next_stage, index)),
				"advance to %s" % next_stage):
			return

		var writes_before: Variant = _storage.write_count
		var abort: Variant = _advance_request(
			_new_run_transaction_id(), next_stage, STAGE_ABORTED, index)
		abort["failure"] = _failure("late_abort", "an abort attempted after allocation")
		_assert_rejected(journal.advance(abort),
			"plan line 593: `%s` may never be relabelled aborted" % next_stage)
		assert_eq(_storage.write_count, writes_before,
			"the refused abort mutates nothing at %s" % next_stage)

		var record: Variant = _operation_record()
		if record.is_empty():
			return
		assert_eq(record.get("allocation_receipt"), retained,
			"plan line 593: the allocation receipt is retained byte-equal at %s" % next_stage)
		current = next_stage


func test_an_irreversible_recovery_diagnostic_holds_the_stage_and_never_permits_input() -> void:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return
	var before: Variant = _operation_record()
	if before.is_empty():
		return

	# Plan line 780: a nonnull failure may "record an irreversible-recovery diagnostic while
	# next_stage == expected_stage at/after identity_allocation_committed with all allocation/
	# participant fields null; the latter never relabels the operation terminal or permits input."
	var diagnostic: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_ALLOCATED, 0)
	diagnostic["failure"] = _failure("source_unprovable", "the original source can no longer be proven")
	if not _require_ok(journal.advance(diagnostic), "record an irreversible-recovery diagnostic"):
		return

	var record: Variant = _operation_record()
	if record.is_empty():
		return
	assert_eq(record.get("stage"), STAGE_ALLOCATED,
		"plan line 780: the diagnostic holds next_stage == expected_stage")
	assert_eq(record.get("allocation_receipt"), before.get("allocation_receipt"),
		"plan line 593: the diagnostic leaves the retained allocation untouched")
	assert_true(record.get("failure") != null, "the typed diagnostic is persisted")

	# Plan line 780: the diagnostic must carry all allocation and participant fields null.
	var with_allocation: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_ALLOCATED, 0)
	with_allocation["failure"] = _failure("source_unprovable", "same diagnostic, illegal shape")
	with_allocation["allocation_receipt"] = _allocation_receipt()
	_assert_rejected(journal.advance(with_allocation),
		"plan line 780: a diagnostic requires all allocation fields null")


# ---------------------------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------------------------

func _require_ok(result: Dictionary, label: String) -> bool:
	var ok: bool = result.get("ok", false)
	assert_true(ok, "%s must succeed: %s" % [label, result])
	return ok


## DECISION 9.9: a rejection must be distinguishable from an unimplemented skeleton. The plan
## freezes no rejection code for this file, so only distinctness is asserted -- never a literal.
func _assert_rejected(result: Dictionary, label: String) -> void:
	assert_false(result.get("ok", true), "%s must be rejected" % label)
	assert_ne(result.get("code", &"not_implemented"), &"not_implemented",
		"%s must fail with a real typed code, not the skeleton envelope" % label)


func _configured_journal() -> Object:
	if not _require_ok(_journal.configure(_storage, _loader), "configure"):
		return null
	return _journal


## A journal with a committed New-Run intent.
func _commit_new_run_intent(journal: Object) -> bool:
	return _commit_new_run_intent_for_id(journal, _new_run_transaction_id())


func _commit_new_run_intent_for_id(journal: Object, transaction_id: String) -> bool:
	var prepared: Variant = journal.prepare_intent(_new_run_intent_request_for(transaction_id))
	if not _require_ok(prepared, "prepare_intent"):
		return false
	return _require_ok(journal.commit_intent(_intent_candidate(prepared)), "commit_intent")


## A journal advanced to identity_allocation_committed -- the irreversible frontier.
func _allocated_journal() -> Object:
	var journal: Variant = _configured_journal()
	if journal == null:
		return null
	if not _commit_new_run_intent(journal):
		return null
	var advance: Variant = _advance_request(
		_new_run_transaction_id(), STAGE_INTENT, STAGE_ALLOCATED, 0)
	advance["allocation_receipt"] = _allocation_receipt()
	if not _require_ok(journal.advance(advance), "advance to identity_allocation_committed"):
		return null
	return journal


## A journal at participants_applying with index 0 -- `run` is the next legal participant.
func _applying_journal() -> Object:
	var journal: Variant = _allocated_journal()
	if journal == null:
		return null
	if not _require_ok(journal.advance(_advance_request(
			_new_run_transaction_id(), STAGE_ALLOCATED, STAGE_APPLYING, 0)),
			"advance to participants_applying"):
		return null
	return journal


func _stored_document() -> Dictionary:
	var stored: Variant = _storage.snapshot()
	if not stored.has(JOURNAL_PATH):
		assert_true(false,
			"plan line 555: the journal stores %s, but nothing was written there" % JOURNAL_PATH)
		return {}
	var parsed: Variant = StrictJson.parse_object(str(stored[JOURNAL_PATH]))
	if not parsed.get("ok", false):
		assert_true(false, "the stored journal document must be strict JSON")
		return {}
	return parsed.get("value", {}) as Dictionary


func _operation_record() -> Dictionary:
	return _operation_record_for(_new_run_transaction_id())


func _operation_record_for(transaction_id: String) -> Dictionary:
	var document: Variant = _stored_document()
	if document.is_empty():
		return {}
	var operations: Variant = document.get("operations", {}) as Dictionary
	return operations.get(transaction_id, {}) as Dictionary


func _journal_with_stage(journal: Object, txid: String, stage: String, full_participants: bool = false,
	with_diagnostic: bool = false, seeded_participant_count: int = 0) -> bool:
	var prepared: Variant = journal.prepare_intent(_new_run_intent_request_for(txid))
	if not _require_ok(prepared, "prepare_intent %s" % txid):
		return false
	if not _require_ok(journal.commit_intent(_intent_candidate(prepared)), "commit_intent %s" % txid):
		return false
	if stage == STAGE_INTENT:
		if with_diagnostic:
			return false
		return true

	if stage == STAGE_ABORTED:
		var abort: Dictionary = _advance_request_for_transaction(txid, STAGE_INTENT, STAGE_ABORTED, 0)
		abort["failure"] = _failure("source_proof_failed", "setup aborted stage for matrix")
		return _require_ok(journal.advance(abort),
				"advance %s -> %s" % [txid, STAGE_ABORTED])

	var into_allocated: Variant = _advance_request_for_transaction(txid, STAGE_INTENT, STAGE_ALLOCATED, 0)
	into_allocated["allocation_receipt"] = _allocation_receipt("allocated-%s" % txid)
	if not _require_ok(journal.advance(into_allocated), "advance %s -> %s" % [txid, STAGE_ALLOCATED]):
		return false
	if stage == STAGE_ALLOCATED:
		if with_diagnostic:
			var diagnostic: Dictionary = _advance_request_for_transaction(txid, STAGE_ALLOCATED, STAGE_ALLOCATED, 0)
			diagnostic["failure"] = _failure("source_unprovable", "a staged recovery diagnostic")
			return _require_ok(journal.advance(diagnostic), "record diagnostic %s" % txid)
		return true

	if stage == STAGE_APPLYING:
		if not _require_ok(journal.advance(_advance_request_for_transaction(
				txid, STAGE_ALLOCATED, STAGE_APPLYING, 0)),
				"advance %s -> %s" % [txid, STAGE_APPLYING]):
			return false
		var seeded_count: int = clamp(seeded_participant_count, 0, PARTICIPANT_ORDER.size())
		for index: int in range(seeded_count):
			var seeded_request: Dictionary = _advance_request_for_transaction(
				txid, STAGE_APPLYING, STAGE_APPLYING, index)
			seeded_request["participant_name"] = PARTICIPANT_ORDER[index]
			seeded_request["participant_receipt"] = _participant_receipt(PARTICIPANT_ORDER[index])
			if not _require_ok(journal.advance(seeded_request),
					"seed participant %s in %s" % [PARTICIPANT_ORDER[index], txid]):
				return false
		if not full_participants:
			return true
		for index: int in range(seeded_count, PARTICIPANT_ORDER.size()):
			var request: Dictionary = _advance_request_for_transaction(
				txid, STAGE_APPLYING, STAGE_APPLYING, index)
			request["participant_name"] = PARTICIPANT_ORDER[index]
			request["participant_receipt"] = _participant_receipt(PARTICIPANT_ORDER[index])
			if not _require_ok(journal.advance(request), "apply participant %s in %s" % [PARTICIPANT_ORDER[index], txid]):
				return false
		return true

	if stage == STAGE_APPLIED:
		return _require_ok(journal.advance(_advance_request_for_transaction(
				txid, STAGE_ALLOCATED, STAGE_APPLIED, PARTICIPANT_ORDER.size())),
				"advance %s -> %s" % [txid, STAGE_APPLIED])

	if stage == STAGE_COMPLETED:
		return _require_ok(journal.advance(_advance_request_for_transaction(
				txid, STAGE_ALLOCATED, STAGE_COMPLETED, PARTICIPANT_ORDER.size())),
				"advance %s -> %s" % [txid, STAGE_COMPLETED])

	return false


func _stage_transition_matrix() -> Array[Dictionary]:
	var ordered_stages: Array[String] = [
		STAGE_INTENT,
		STAGE_ALLOCATED,
		STAGE_APPLYING,
		STAGE_APPLIED,
		STAGE_COMPLETED,
		STAGE_ABORTED,
	]
	var legal_profiles: Dictionary = {
		"%s->%s" % [STAGE_INTENT, STAGE_ALLOCATED]: {
			"label": "intent to allocated",
			"legal": true,
			"expected_next_participant_index": 0,
			"allocation": true,
		},
		"%s->%s" % [STAGE_INTENT, STAGE_ABORTED]: {
			"label": "intent to aborted",
			"legal": true,
			"expected_next_participant_index": 0,
			"failure": _failure("source_proof_failed", "new run could not pre-allocate"),
		},
		"%s->%s" % [STAGE_ALLOCATED, STAGE_APPLYING]: {
			"label": "allocated to applying",
			"legal": true,
			"expected_next_participant_index": 0,
		},
		"%s->%s" % [STAGE_ALLOCATED, STAGE_APPLIED]: {
			"label": "allocated to applied",
			"expected_next_participant_index": PARTICIPANT_ORDER.size(),
			"legal": true,
		},
		"%s->%s" % [STAGE_ALLOCATED, STAGE_COMPLETED]: {
			"label": "allocated to completed",
			"expected_next_participant_index": PARTICIPANT_ORDER.size(),
			"legal": true,
		},
		"%s->%s" % [STAGE_ALLOCATED, STAGE_ALLOCATED]: {
			"label": "allocated diagnostic",
			"legal": true,
			"expected_next_participant_index": 0,
			"failure": _failure("source_unprovable", "source is unrecoverable"),
		},
		"%s->%s" % [STAGE_APPLYING, STAGE_APPLYING]: {
			"label": "applying to applying",
			"legal": true,
			"expected_next_participant_index": 0,
			"participant_name": PARTICIPANT_ORDER[0],
		},
		"%s->%s" % [STAGE_APPLYING, STAGE_APPLIED]: {
			"label": "applying to applied",
			"legal": true,
			"expected_next_participant_index": PARTICIPANT_ORDER.size(),
		},
		"%s->%s" % [STAGE_APPLYING, STAGE_COMPLETED]: {
			"label": "applying to completed",
			"legal": true,
			"expected_next_participant_index": PARTICIPANT_ORDER.size(),
		},
		"%s->%s" % [STAGE_APPLIED, STAGE_COMPLETED]: {
			"label": "applied to completed",
			"legal": true,
			"expected_next_participant_index": PARTICIPANT_ORDER.size(),
		},
	}
	var transition_matrix: Array[Dictionary] = []
	for from_stage: String in ordered_stages:
		for to_stage: String in ordered_stages:
			var key := "%s->%s" % [from_stage, to_stage]
			var transition := {
				"from_stage": from_stage,
				"to_stage": to_stage,
				"label": "%s cannot transition to %s" % [from_stage, to_stage],
				"expected_next_participant_index": 0,
				"legal": false,
			}
			if legal_profiles.has(key):
				for field in legal_profiles[key].keys():
					transition[field] = legal_profiles[key][field]
			transition_matrix.append(transition)
	return transition_matrix


func _advance_request_for_stage_transition(transaction_id: String, transition: Dictionary) -> Dictionary:
	var request: Dictionary = _advance_request_for_transaction(
		transaction_id,
		str(transition.get("from_stage", STAGE_INTENT)),
		str(transition.get("to_stage", STAGE_ALLOCATED)),
		int(transition.get("expected_next_participant_index", 0))
	)
	if transition.has("allocation"):
		request["allocation_receipt"] = _allocation_receipt("matrix-%s" % transaction_id)
	if transition.has("participant_name"):
		var participant: String = str(transition["participant_name"])
		request["participant_name"] = participant
		request["participant_receipt"] = _participant_receipt(participant)
	if transition.has("failure"):
		request["failure"] = transition["failure"]
	return request


## The REAL issuer over the REAL root store over real JsonFileStorage over FakeFileOps
## (DECISION 9.4). reconcile_startup() takes it directly; there is no issuer fake and a 21st create
## would break Step 1.5's twenty-two-path count.
func _real_issuer() -> Object:
	var issuer := _ensure_real_issuer()
	return issuer


func _ensure_real_issuer() -> Object:
	if _identity_issuer != null:
		return _identity_issuer
	_identity_file_ops = FakeFileOps.new()
	_identity_root_store = ROOT_STORE.new()
	var configured: Dictionary = _identity_root_store.configure(
		JsonFileStorage.new(IDENTITY_ROOT, _identity_file_ops),
		FAKE_NAMESPACE_SOURCE.new(NAMESPACE_A))
	if not configured.get("ok", false):
		assert_true(false, "test identity root must configure: %s" % configured)
		return null
	var loaded: Dictionary = _identity_root_store.load_or_create()
	if not loaded.get("ok", false):
		assert_true(false, "test identity root must load: %s" % loaded)
		return null
	_identity_issuer = ISSUER.new()
	var issued: Dictionary = _identity_issuer.configure(_identity_root_store)
	if not issued.get("ok", false):
		assert_true(false, "test identity issuer must configure: %s" % issued)
		return null
	return _identity_issuer


func _new_run_transaction_id() -> String:
	return "transaction-new-run"


func _restore_transaction_id() -> String:
	return "transaction-restore"


## The frozen prepare_intent() request, plan line 780, in its New-Run shape (plan line 591).
func _new_run_intent_request_for(transaction_id: String) -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": _transaction_receipt(transaction_id),
		"kind": "new_run",
		"request_fingerprint": "1".repeat(64),
		"source_locator": null,
		"initial_context": NEW_RUN_INITIAL_CONTEXT.duplicate(true),
		"initial_context_sha256": _canonical_sha256(NEW_RUN_INITIAL_CONTEXT),
		"allocation_candidate_fingerprint": "2".repeat(64),
	}


func _new_run_intent_request() -> Dictionary:
	return _new_run_intent_request_for(_new_run_transaction_id())


## The same frozen request in its restore shape: locator present, both context fields null.
func _restore_intent_request_for(transaction_id: String) -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": _transaction_receipt(transaction_id),
		"kind": "restore",
		"request_fingerprint": "3".repeat(64),
		"source_locator": _restore_locator(),
		"initial_context": null,
		"initial_context_sha256": null,
		"allocation_candidate_fingerprint": "4".repeat(64),
	}


func _restore_intent_request() -> Dictionary:
	return _restore_intent_request_for(_restore_transaction_id())


## Plan line 591: slot_id is exactly slot:1..slot:7, quick or autosave; the other three members are
## all lowercase SHA-256 or the nonblank checkpoint ID inside the selected snapshot.
func _restore_locator() -> Dictionary:
	return {
		"slot_id": RESTORE_SLOT_ID,
		"bundle_id": "5".repeat(64),
		"checkpoint_id": "checkpoint-1",
		"document_sha256": "6".repeat(64),
	}


## Plan line 591: the full byte-exact purpose-`transaction_id` issuer receipt, whose token equals
## the operations map key.
func _transaction_receipt(transaction_id: String) -> Dictionary:
	if _transaction_receipts.has(transaction_id):
		return _transaction_receipts[transaction_id]
	var issuer: Object = _ensure_real_issuer()
	if issuer == null:
		return {}
	var issued: Dictionary = issuer.call(&"issue", &"transaction_id")
	if not issued.get("ok", false):
		assert_true(false, "test transaction receipt must issue: %s" % issued)
		return {}
	var receipt: Dictionary = (issued.get("value", {}) as Dictionary).get("issuer_receipt", {})
	var cached := receipt.duplicate(true)
	_transaction_receipts[transaction_id] = cached
	return cached


func _allocation_receipt(marker: String = "allocation-1") -> Dictionary:
	return {"schema_version": 1, "allocation_id": marker}


func _participant_receipt(participant: String) -> Dictionary:
	return {"schema_version": 1, "participant": participant}


## Plan line 591: failure is exactly {code, message, details} with nonblank code/message and
## detached primitive details.
func _failure(code: String, message: String) -> Dictionary:
	return {"code": code, "message": message, "details": {}}


## The frozen advance() request, plan line 780. Allocation and participant fields default to null;
## each test sets only the ones its law requires nonnull.
func _advance_request(transaction_id: String, expected_stage: String, next_stage: String,
		expected_next_participant_index: int) -> Dictionary:
	var request_fingerprint := "1".repeat(64)
	if transaction_id == _restore_transaction_id():
		request_fingerprint = "3".repeat(64)
	return {
		"transaction_id": transaction_id,
		"request_fingerprint": request_fingerprint,
		"expected_stage": expected_stage,
		"expected_next_participant_index": expected_next_participant_index,
		"next_stage": next_stage,
		"allocation_receipt": null,
		"participant_name": null,
		"participant_receipt": null,
		"failure": null,
	}


func _advance_request_for_transaction(transaction_id: String, expected_stage: String, next_stage: String,
		expected_next_participant_index: int) -> Dictionary:
	return _advance_request(transaction_id, expected_stage, next_stage, expected_next_participant_index)


func _intent_candidate(prepared: Dictionary) -> Dictionary:
	return (prepared.get("value", {}) as Dictionary).duplicate(true)


func _canonical_sha256(value: Dictionary) -> String:
	var canonical: Variant = CanonicalJsonWriter.stringify(value)
	if not canonical.get("ok", false):
		assert_true(false, "the frozen New-Run context must be canonicalizable: %s" % canonical)
		return ""
	return FAKE_STORAGE.sha256_hex(str(canonical.get("value", "")))
