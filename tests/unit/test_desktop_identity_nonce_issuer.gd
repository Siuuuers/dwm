extends "res://addons/gut/test.gd"
# Behavioral RED contract tests for the production identity issuer (Plan 02 Task 1, dwm-p2r.16).
#
# OBLIGATION MAP (plan line 797; dwm-p2r.16 DECISION 9.13 puts the per-clause map beside the code).
#    1 full purpose union, ordinary direct issuance ......... breadth TABLE (8 ordinary purposes)
#    2 the two atomic allocators ........................... DEEP
#    3 direct generation rejection ......................... DEEP   (frozen code asserted)
#    4 direct causal-day rejection ......................... DEEP   (frozen code asserted)
#    5 exact generation 0 / source+1 ....................... DEEP
#    6 initial causal-day + full-receipt allocation ........ DEEP
#    7 full-receipt verification ........................... DEEP   (4 rejection families)
#    8 every anchored child kind ........................... breadth TABLE (all 22 kinds)
#    9 forged / missing parent rejection ................... DEEP
#   10 New-Run / restore bundle allocation ................. DEEP
#   11 duplicate allocation equality ...................... DEEP
#   12 changed allocation conflict ........................ DEEP
#   16 no API lowers the counter (issuer half) ............ breadth
#   17 post-call mutation (issuer half) ................... breadth
#
# SUBSTRATE. The issuer is tested against FakeDesktopIssuerRootStore, not the real root store. This
# is forced by the plan's own Step 1.1 fixture, which reads `_issuer_root.last_committed_receipt` --
# a spy field only a double can have. Per DECISION 9.12 the double is REAL for counter/receipt/
# capture (frozen plan-line-535 preimages inline, giving double-entry on the formula) and
# PROGRAMMABLE for the four allocation methods, whose semantics belong to the root store and are
# proven against the real one in test_desktop_issuer_root_store.gd.
#
# GLOBAL CLASS NAMES ARE NOT AVAILABLE for the 20 new Task-1 scripts: they have never been through
# an editor import pass, so they are absent from the global script class cache -- the same root
# cause as the DECISION 8 CORRECTION about missing .uid siblings. Preloading by path is this repo's
# established answer and keeps the working tree exactly as that correction describes.
#
# REJECTION ASSERTIONS (DECISION 9.9). Every skeleton method returns {ok:false, code:
# &"not_implemented"}, so a bare assert_false(result["ok"]) would PASS against the stub. Every
# rejection asserts failure AND code != &"not_implemented". The plan freezes exactly two codes for
# this file -- generation_allocation_required and causal_day_advance_allocation_required -- and only
# those two are asserted as literals; no other rejection code is invented (DECISION 5's precedent).

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"

# The plan's own Step 1.1 fixture values.
const NAMESPACE := "1111111111111111111111111111111111111111111111111111111111111111"
const START_COUNTER := 7

# The purpose union minus the two the ISSUER refuses to mint directly (plan line 729).
const ORDINARY_PURPOSES: Array[StringName] = [
	&"run_id",
	&"branch_id",
	&"board_id",
	&"transaction_id",
	&"placement_nonce",
	&"debug_nonce",
	&"explosion_nonce",
	&"receipt_id",
]

# The v1 child-kind union, plan line 537. 22 members were frozen; Task 8's Review-fix pass
# (dwm-p2r.32.8) additively registered a 23rd, "action_consequence" -- mirrored here so this
# enumeration test covers it too. See DesktopIdentityNonceIssuer.CHILD_KINDS's own doc comment.
const CHILD_KINDS: Array[StringName] = [
	&"schedule_entry",
	&"schedule_commit",
	&"day7_schedule_provenance",
	&"empty_schedule_done",
	&"contact_source",
	&"hospital_resolution",
	&"hospital_miss",
	&"sylvia_hospital_witness",
	&"day_resolution_stage",
	&"board_command",
	&"board_start",
	&"shop_quote",
	&"desktop_action",
	&"causal_sequence",
	&"condition",
	&"board_fate",
	&"destination_intent",
	&"notification_intent",
	&"continuation_operation",
	&"warning",
	&"navigation",
	&"terminal_intent",
	&"action_consequence",
]

# Exact child provenance member set, plan line 537. Sorted, for a set comparison.
const PROVENANCE_KEYS: Array[String] = [
	"child_id",
	"child_kind",
	"ordinal",
	"parent_receipt_id",
	"schema_version",
	"source_ids",
]

var _issuer_root: FAKE_ROOT_STORE
var _issuer: ISSUER


## Keeps the allocation half of the issuer test double faithful to the corrected real root without
## widening tests/support. All ordinary root behavior and spy state still belong to `_issuer_root`.
class CandidateFaithfulRootAdapter extends RefCounted:
	var root: Object

	func _init(root_store: Object) -> void:
		root = root_store

	func issue(purpose: StringName) -> Dictionary:
		return root.call(&"issue", purpose)

	func issue_deferred(purpose: StringName) -> Dictionary:
		return root.call(&"issue_deferred", purpose)

	func flush() -> Dictionary:
		return root.call(&"flush")

	func verify_receipt(receipt: Dictionary, expected_purpose: StringName) -> Dictionary:
		return root.call(&"verify_receipt", receipt, expected_purpose)

	func prepare_allocation(request: Dictionary) -> Dictionary:
		var prepared: Dictionary = root.call(&"prepare_allocation", request)
		if not prepared.get("ok", false):
			return prepared
		var candidate: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
		var sources: Array = (candidate.get("request", {}) as Dictionary).get(
			"remap_source_transaction_ids", [])
		var minted: Dictionary = candidate.get("remap_transaction_issuer_receipts", {})
		var transaction_remap := {}
		for source in sources:
			var source_id := str(source)
			var receipt: Dictionary = minted.get(source_id, {})
			transaction_remap[source_id] = {
				"source_transaction_id": source_id,
				"new_transaction_id": str(receipt.get("token", "")),
				"new_transaction_issuer_receipt": receipt.duplicate(true),
			}
		candidate["transaction_remap"] = transaction_remap
		return {"ok": true, "value": candidate}

	func commit_allocation(candidate: Dictionary) -> Dictionary:
		return root.call(&"commit_allocation", candidate)

	func prepare_causal_day_advance(request: Dictionary) -> Dictionary:
		return root.call(&"prepare_causal_day_advance", request)

	func commit_causal_day_advance(candidate: Dictionary) -> Dictionary:
		return root.call(&"commit_causal_day_advance", candidate)

	func capture() -> Dictionary:
		return root.call(&"capture")


func before_each() -> void:
	_issuer_root = null
	_issuer = null


# ---------------------------------------------------------------------------------------------
# Retained skeleton probe (Step 1.1 first half)
# ---------------------------------------------------------------------------------------------

func test_desktop_identity_nonce_issuer_skeleton_loads() -> void:
	var probe := DynamicScriptProbe.load_script(ISSUER_PATH)
	assert_true(probe.get("ok", false),
		"DesktopIdentityNonceIssuer must parse and load: " + str(probe.get("message", "")))


# ---------------------------------------------------------------------------------------------
# The plan's own Step 1.1 fixture, reproduced verbatim (plan lines 789-794)
# ---------------------------------------------------------------------------------------------

func test_issuer_advances_persisted_counter_before_returning_a_token() -> void:
	var issued := _issuer_with_namespace(NAMESPACE, START_COUNTER).issue(&"debug_nonce")
	if not _require_ok(issued, "issue(debug_nonce)"):
		return
	assert_eq((issued.get("receipt", {}) as Dictionary).get("counter"), START_COUNTER,
		"the issued receipt takes the root's current counter")
	var captured := _issuer_root.capture()
	if not _require_ok(captured, "root capture"):
		return
	assert_eq((captured.get("value", {}) as Dictionary).get("next_counter"), START_COUNTER + 1,
		"the root counter advances before the token is observable")
	assert_eq(_issuer_root.last_committed_receipt, issued.get("receipt"),
		"the root's last committed receipt IS the receipt the issuer returned")


# ---------------------------------------------------------------------------------------------
# Clause 1 -- the full purpose union across ordinary direct issuance
# ---------------------------------------------------------------------------------------------

func test_every_ordinary_purpose_issues_the_exact_value_and_outer_receipt() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var counter := 1
	for purpose: StringName in ORDINARY_PURPOSES:
		var issued := issuer.issue(purpose)
		if not _require_ok(issued, "issue(%s)" % String(purpose)):
			return
		var value: Dictionary = issued.get("value", {})
		var keys := value.keys()
		keys.sort()
		assert_eq(keys, ["issuer_receipt", "token"] as Array,
			"plan line 729: issue returns exactly value={token,issuer_receipt} for %s"
				% String(purpose))
		var receipt: Dictionary = value.get("issuer_receipt", {})
		assert_eq(issued.get("receipt"), receipt,
			"the outer receipt is byte-equal to the issuer_receipt for %s" % String(purpose))
		assert_eq(value.get("token"),
			FAKE_ROOT_STORE.token_for(NAMESPACE, counter, purpose),
			"the frozen token preimage holds for %s" % String(purpose))
		counter += 1


func test_the_issuer_delegates_exactly_one_counter_advance_per_issuance() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	if not _require_ok(issuer.issue(&"debug_nonce"), "issue(debug_nonce)"):
		return
	assert_eq(_issuer_root.calls_to(&"issue").size(), 1,
		"plan line 729: the issuer delegates ONE append-only counter advance to the root store")


# ---------------------------------------------------------------------------------------------
# Clauses 3 and 4 -- the two directly unissuable purposes (frozen codes)
# ---------------------------------------------------------------------------------------------

func test_direct_generation_issuance_is_refused_with_the_frozen_code() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var refused := issuer.issue(&"desktop_timeline_generation")
	_assert_rejected(refused, "direct issue(desktop_timeline_generation)")
	assert_eq(refused.get("code"), &"generation_allocation_required",
		"plan line 729 freezes this exact code")
	assert_eq(_issuer_root.calls_to(&"issue").size(), 0,
		"a refused direct issuance burns no counter at the root")


func test_direct_causal_day_issuance_is_refused_with_the_frozen_code() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var refused := issuer.issue(&"causal_day_instance")
	_assert_rejected(refused, "direct issue(causal_day_instance)")
	assert_eq(refused.get("code"), &"causal_day_advance_allocation_required",
		"plan line 729 freezes this exact code, so a crash cannot burn an unkeyed next-day identity")
	assert_eq(_issuer_root.calls_to(&"issue").size(), 0,
		"a refused direct issuance burns no counter at the root")


# ---------------------------------------------------------------------------------------------
# Clause 7 -- full-receipt verification (four rejection families)
# ---------------------------------------------------------------------------------------------

func test_verify_issued_accepts_only_the_exact_ledger_receipt() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var issued := issuer.issue(&"transaction_id")
	if not _require_ok(issued, "issue(transaction_id)"):
		return
	var receipt: Dictionary = issued.get("receipt", {})
	if not _require_ok(issuer.verify_issued(receipt, &"transaction_id"),
			"verify_issued on the genuine receipt"):
		return

	# ID-only: a caller may never prove provenance with the identifier alone (plan line 535).
	_assert_rejected(issuer.verify_issued({"receipt_id": receipt.get("receipt_id")}, &"transaction_id"),
		"verify_issued with an ID-only receipt")

	# Structurally valid but absent from the ledger.
	var absent := receipt.duplicate(true)
	absent["counter"] = int(receipt.get("counter", 0)) + 500
	absent["receipt_id"] = FAKE_ROOT_STORE.receipt_id_for(
		NAMESPACE, int(absent["counter"]), &"transaction_id", str(absent.get("token", "")))
	_assert_rejected(issuer.verify_issued(absent, &"transaction_id"),
		"verify_issued on a structurally valid but absent receipt")

	# Wrong expected purpose.
	_assert_rejected(issuer.verify_issued(receipt, &"run_id"),
		"verify_issued against the wrong purpose")

	# Byte-changed.
	var changed := receipt.duplicate(true)
	changed["token"] = "transaction_id.deadbeef"
	_assert_rejected(issuer.verify_issued(changed, &"transaction_id"),
		"verify_issued on a byte-changed receipt")


# ---------------------------------------------------------------------------------------------
# Clause 8 -- every anchored child kind
# ---------------------------------------------------------------------------------------------

func test_every_registered_child_kind_derives_the_frozen_child_id() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var parent := issuer.issue(&"transaction_id")
	if not _require_ok(parent, "issue(transaction_id) as the anchor"):
		return
	var parent_receipt: Dictionary = parent.get("receipt", {})
	var source_ids: Array = ["source.a", "source.b"]

	for child_kind: StringName in CHILD_KINDS:
		var derived := issuer.derive_child({
			"parent_receipt_id": parent_receipt.get("receipt_id"),
			"child_kind": child_kind,
			"ordinal": 0,
			"source_ids": source_ids,
		})
		if not _require_ok(derived, "derive_child(%s)" % String(child_kind)):
			return
		var value: Dictionary = derived.get("value", {})
		var provenance: Dictionary = value.get("provenance", {})
		var keys := provenance.keys()
		keys.sort()
		assert_eq(keys, PROVENANCE_KEYS,
			"plan line 537 freezes the provenance member set for %s" % String(child_kind))
		assert_eq(value.get("child_id"),
			_expected_child_id(parent_receipt, child_kind, 0, source_ids),
			"the frozen domain-separated child preimage holds for %s" % String(child_kind))
		assert_eq(derived.get("receipt"), provenance,
			"the outer receipt is byte-equal to provenance for %s" % String(child_kind))
		if not _require_ok(issuer.validate_child(provenance, child_kind),
				"validate_child(%s)" % String(child_kind)):
			return


func test_an_unregistered_child_kind_is_refused() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var parent := issuer.issue(&"transaction_id")
	if not _require_ok(parent, "issue(transaction_id) as the anchor"):
		return
	_assert_rejected(issuer.derive_child({
		"parent_receipt_id": (parent.get("receipt", {}) as Dictionary).get("receipt_id"),
		"child_kind": &"not_a_registered_kind",
		"ordinal": 0,
		"source_ids": [],
	}), "plan line 537: the v1 child-kind union is closed")


# ---------------------------------------------------------------------------------------------
# Clause 9 -- forged and missing parent rejection
# ---------------------------------------------------------------------------------------------

func test_a_child_may_not_anchor_to_a_forged_absent_or_wrong_purpose_parent() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var wrong_purpose := issuer.issue(&"run_id")
	if not _require_ok(wrong_purpose, "issue(run_id)"):
		return

	_assert_rejected(issuer.derive_child({
		"parent_receipt_id": "issuer_receipt.0000000000000000",
		"child_kind": &"shop_quote",
		"ordinal": 0,
		"source_ids": [],
	}), "an absent parent receipt ID cannot anchor a child")

	# Plan line 30: "No child may anchor to a run/board/nonce/receipt-purpose token."
	_assert_rejected(issuer.derive_child({
		"parent_receipt_id": (wrong_purpose.get("receipt", {}) as Dictionary).get("receipt_id"),
		"child_kind": &"shop_quote",
		"ordinal": 0,
		"source_ids": [],
	}), "plan line 537: the parent purpose must be exactly transaction_id")


func test_source_ids_must_arrive_already_sorted_unique_and_nonblank() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var parent := issuer.issue(&"transaction_id")
	if not _require_ok(parent, "issue(transaction_id) as the anchor"):
		return
	var parent_receipt_id: Variant = (parent.get("receipt", {}) as Dictionary).get("receipt_id")

	var scenarios: Array[Dictionary] = [
		{"label": "unsorted", "source_ids": ["source.b", "source.a"]},
		{"label": "duplicated", "source_ids": ["source.a", "source.a"]},
		{"label": "blank", "source_ids": [""]},
	]
	for scenario: Dictionary in scenarios:
		_assert_rejected(issuer.derive_child({
			"parent_receipt_id": parent_receipt_id,
			"child_kind": &"shop_quote",
			"ordinal": 0,
			"source_ids": scenario["source_ids"],
		}), "plan line 537: %s source IDs are refused, not repaired" % str(scenario["label"]))

	_assert_rejected(issuer.derive_child({
		"parent_receipt_id": parent_receipt_id,
		"child_kind": &"shop_quote",
		"ordinal": -1,
		"source_ids": [],
	}), "plan line 537: the ordinal must be nonnegative")


func test_validate_child_repeats_the_ledger_lookup_and_the_byte_derivation() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var parent := issuer.issue(&"transaction_id")
	if not _require_ok(parent, "issue(transaction_id) as the anchor"):
		return
	var derived := issuer.derive_child({
		"parent_receipt_id": (parent.get("receipt", {}) as Dictionary).get("receipt_id"),
		"child_kind": &"board_start",
		"ordinal": 0,
		"source_ids": [],
	})
	if not _require_ok(derived, "derive_child(board_start)"):
		return
	var provenance: Dictionary = (derived.get("value", {}) as Dictionary).get("provenance", {})

	_assert_rejected(issuer.validate_child(provenance, &"shop_quote"),
		"validate_child against a different expected kind")

	var tampered := provenance.duplicate(true)
	tampered["ordinal"] = int(tampered.get("ordinal", 0)) + 1
	_assert_rejected(issuer.validate_child(tampered, &"board_start"),
		"a provenance whose child_id no longer derives from its own members is refused")


# ---------------------------------------------------------------------------------------------
# Clauses 2, 5, 6, 10, 11, 12 -- the continuation allocator (DEEP)
# ---------------------------------------------------------------------------------------------

func test_a_new_run_request_requires_null_sources_and_an_empty_remap() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var receipt: Dictionary = transaction.get("receipt", {})

	var scenarios: Array[Dictionary] = [
		{"label": "a nonnull existing run", "patch": {"existing_run_id": "run_id.previous"}},
		{"label": "a nonnull source generation", "patch": {"source_desktop_timeline_generation": 0}},
		{"label": "a nonempty remap array",
			"patch": {"remap_source_transaction_ids": ["transaction_id.old"]}},
	]
	for scenario: Dictionary in scenarios:
		var request := _new_run_request(receipt)
		for key: String in (scenario["patch"] as Dictionary):
			request[key] = (scenario["patch"] as Dictionary)[key]
		_assert_rejected(issuer.prepare_continuation_allocation(request),
			"plan line 729: New Run rejects %s" % str(scenario["label"]))


func test_a_restore_request_requires_a_run_a_generation_and_a_sorted_unique_source_set() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var receipt: Dictionary = transaction.get("receipt", {})

	var scenarios: Array[Dictionary] = [
		{"label": "a blank existing run", "patch": {"existing_run_id": ""}},
		{"label": "a negative source generation",
			"patch": {"source_desktop_timeline_generation": -1}},
		{"label": "an unsorted source set",
			"patch": {"remap_source_transaction_ids": ["transaction_id.b", "transaction_id.a"]}},
		{"label": "a duplicated source set",
			"patch": {"remap_source_transaction_ids": ["transaction_id.a", "transaction_id.a"]}},
	]
	for scenario: Dictionary in scenarios:
		var request := _restore_request(receipt)
		for key: String in (scenario["patch"] as Dictionary):
			request[key] = (scenario["patch"] as Dictionary)[key]
		_assert_rejected(issuer.prepare_continuation_allocation(request),
			"plan line 729: restore rejects %s" % str(scenario["label"]))


func test_prepare_continuation_allocation_is_mutation_free() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var before := _issuer_root.capture()
	if not _require_ok(before, "root capture before prepare"):
		return
	var prepared := issuer.prepare_continuation_allocation(
		_new_run_request(transaction.get("receipt", {})))
	if not _require_ok(prepared, "prepare_continuation_allocation"):
		return
	var after := _issuer_root.capture()
	if not _require_ok(after, "root capture after prepare"):
		return
	assert_eq(after.get("value"), before.get("value"),
		"plan line 729: prepare is mutation-free")
	assert_eq(_issuer_root.calls_to(&"commit_allocation").size(), 0,
		"prepare never reaches the root's commit path")


func test_a_new_run_bundle_proposes_generation_zero_and_an_initial_causal_day() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var prepared := issuer.prepare_continuation_allocation(
		_new_run_request(transaction.get("receipt", {})))
	if not _require_ok(prepared, "prepare_continuation_allocation"):
		return
	var bundle: Dictionary = prepared.get("value", {})
	assert_eq(bundle.get("kind"), "new_run", "the bundle echoes its own kind")
	assert_eq(bundle.get("desktop_timeline_generation"), 0,
		"plan line 729: New Run proposes generation zero exactly")
	assert_eq(bundle.get("transaction_remap"), {}, "plan line 1712: New Run requires {}")
	assert_true(str(bundle.get("causal_day_instance", "")).begins_with("causal_day_instance."),
		"the continuation allocator alone mints the INITIAL causal-day token")
	var causal_receipt: Dictionary = bundle.get("causal_day_instance_issuer_receipt", {})
	assert_eq(causal_receipt.get("token"), bundle.get("causal_day_instance"),
		"plan line 1712: the full causal-day receipt's token equals the adjacent field")
	assert_eq(causal_receipt.get("purpose"), "causal_day_instance",
		"the initial causal-day receipt carries the causal_day_instance purpose")


func test_a_restore_bundle_proposes_source_plus_one_and_a_fresh_branch() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var request := _restore_request(transaction.get("receipt", {}))
	request["source_desktop_timeline_generation"] = 4
	var prepared := issuer.prepare_continuation_allocation(request)
	if not _require_ok(prepared, "prepare_continuation_allocation(restore)"):
		return
	var bundle: Dictionary = prepared.get("value", {})
	assert_eq(bundle.get("desktop_timeline_generation"), 5,
		"plan line 729: restore proposes source generation plus one exactly")
	assert_eq(bundle.get("run_id"), "run_id.previous",
		"plan line 1712: for restore the run is validated source provenance, not newly allocated")
	assert_true(str(bundle.get("branch_id", "")).begins_with("branch_id."),
		"every other lifecycle identity is freshly allocated on restore")


func test_a_restore_bundle_includes_every_requested_source_remap_entry() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var source_receipt: Dictionary = transaction.get("receipt", {})

	var request: Dictionary = _restore_request(source_receipt)
	var source_set: Array[String] = ["transaction_id.a", "transaction_id.b", "transaction_id.c"]
	request["remap_source_transaction_ids"] = source_set
	var prepared := issuer.prepare_continuation_allocation(request)
	if not _require_ok(prepared, "prepare_continuation_allocation(restore)"):
		return
	var bundle: Dictionary = prepared.get("value", {})

	var remap: Dictionary = bundle.get("transaction_remap", {})
	var ordered: Array = request.get("remap_source_transaction_ids", [])
	var remap_keys: Array = remap.keys()
	remap_keys.sort()
	var requested_keys: Array = ordered.duplicate()
	requested_keys.sort()
	assert_eq(remap_keys, requested_keys,
		"restore transaction remap is exactly the requested source set")
	for index: int in range(ordered.size()):
		var source_id := str(ordered[index])
		var entry: Dictionary = remap.get(source_id, {})
		var entry_keys: Array = entry.keys()
		entry_keys.sort()
		assert_eq(entry_keys, ["new_transaction_id", "new_transaction_issuer_receipt",
			"source_transaction_id"] as Array,
			"transaction remap source %s has exactly the frozen three-member shape" % source_id)
		assert_eq(entry.get("source_transaction_id", ""), source_id,
			"transaction remap key %s must preserve its source transaction id" % source_id)
		assert_eq(str(entry.get("new_transaction_id", "")),
			str((entry.get("new_transaction_issuer_receipt", {}) as Dictionary).get("token", "")),
			"new transaction id matches its minted token for source %s" % source_id)
		assert_eq((entry.get("new_transaction_issuer_receipt", {}) as Dictionary).get("purpose", ""),
			"transaction_id",
			"transaction remap for source %s must mint a transaction_id receipt" % source_id)


func test_an_identical_allocation_replay_returns_the_original_bundle() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var request := _new_run_request(transaction.get("receipt", {}))
	var prepared := issuer.prepare_continuation_allocation(request)
	if not _require_ok(prepared, "prepare_continuation_allocation"):
		return
	var committed := issuer.commit_continuation_allocation(prepared.get("value", {}))
	if not _require_ok(committed, "commit_continuation_allocation"):
		return
	var replayed := issuer.commit_continuation_allocation(prepared.get("value", {}))
	if not _require_ok(replayed, "identical replay of commit_continuation_allocation"):
		return
	assert_eq(replayed.get("value"), committed.get("value"),
		"plan line 729: identical allocation transaction and request bytes return the original bundle")


func test_changed_allocation_bytes_at_the_same_transaction_conflict() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var transaction := issuer.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var receipt: Dictionary = transaction.get("receipt", {})
	var prepared := issuer.prepare_continuation_allocation(_new_run_request(receipt))
	if not _require_ok(prepared, "prepare_continuation_allocation"):
		return
	if not _require_ok(issuer.commit_continuation_allocation(prepared.get("value", {})),
			"commit_continuation_allocation"):
		return

	var changed: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
	changed["desktop_timeline_generation"] = 99
	_assert_rejected(issuer.commit_continuation_allocation(changed),
		"plan line 729: changed bytes at an occupied allocation transaction conflict")


func test_a_failed_durable_advance_yields_no_token() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	_issuer_root.fail_next_issue()
	var issued := issuer.issue(&"debug_nonce")
	_assert_rejected(issued, "issue across a failed durable root advance")
	assert_false(issued.has("value"), "plan line 729: a failed durable advance returns no token")


# ---------------------------------------------------------------------------------------------
# Clauses 16 and 17 -- counter monotonicity and detachment at the issuer boundary
# ---------------------------------------------------------------------------------------------

func test_no_issuer_api_lowers_the_root_counter() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	for purpose: StringName in [&"run_id", &"transaction_id"]:
		if not _require_ok(issuer.issue(purpose), "issue(%s)" % String(purpose)):
			return
	var high := _issuer_root.next_counter

	issuer.verify_issued({}, &"run_id")
	issuer.derive_child({})
	issuer.validate_child({}, &"shop_quote")
	issuer.prepare_continuation_allocation({})
	issuer.commit_continuation_allocation({})
	issuer.prepare_causal_day_advance({})
	issuer.commit_causal_day_advance({})
	issuer.capture_root()
	assert_eq(_issuer_root.next_counter, high,
		"plan line 1682: no API lowers the counter, and none of these advances it either")


func test_capture_root_is_detached_and_never_restores_root_state() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	if not _require_ok(issuer.issue(&"run_id"), "issue(run_id)"):
		return
	var captured := issuer.capture_root()
	if not _require_ok(captured, "capture_root"):
		return
	var document: Dictionary = captured.get("value", {})
	document["next_counter"] = 1
	(document.get("receipts", {}) as Dictionary).clear()
	assert_eq(_issuer_root.next_counter, 2,
		"plan line 729: a captured root can never lower, replace, or restore root state")
	assert_eq(_issuer_root.receipts.size(), 1, "the ledger is unaffected by caller mutation")


# ---------------------------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------------------------

## The plan's own fixture name (plan line 790). Builds the seeded double, configures a real issuer
## over it, and retains the double as `_issuer_root` so tests can read its spy surface.
func _issuer_with_namespace(namespace_hex: String, next_counter: int) -> ISSUER:
	_issuer_root = FAKE_ROOT_STORE.new(namespace_hex, next_counter)
	_issuer = ISSUER.new()
	_issuer.configure(CandidateFaithfulRootAdapter.new(_issuer_root))
	return _issuer


func _require_ok(result: Dictionary, label: String) -> bool:
	var ok: bool = result.get("ok", false)
	assert_true(ok, "%s must succeed: %s" % [label, result])
	return ok


## DECISION 9.9: a rejection must be distinguishable from an unimplemented skeleton.
func _assert_rejected(result: Dictionary, label: String) -> void:
	assert_false(result.get("ok", true), "%s must be rejected" % label)
	assert_ne(result.get("code", &"not_implemented"), &"not_implemented",
		"%s must fail with a real typed code, not the skeleton envelope" % label)


## The frozen anchored-child preimage, plan line 537:
##   child_kind + "." + sha256("desktop_child_v1\n" + parent.namespace + "\n" + str(parent.counter)
##     + "\n" + parent.receipt_id + "\n" + child_kind + "\n" + str(ordinal) + "\n"
##     + CanonicalJsonWriter.stringify(source_ids))
func _expected_child_id(parent_receipt: Dictionary, child_kind: StringName, ordinal: int,
		source_ids: Array) -> String:
	var canonical := CanonicalJsonWriter.stringify(source_ids)
	if not canonical.get("ok", false):
		return ""
	return "%s.%s" % [
		String(child_kind),
		FAKE_ROOT_STORE.sha256_hex("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
			str(parent_receipt.get("namespace", "")),
			int(parent_receipt.get("counter", 0)),
			str(parent_receipt.get("receipt_id", "")),
			String(child_kind),
			ordinal,
			str(canonical.get("value", "")),
		]),
	]


## Plan line 729: New Run requires both nullable source fields null and an empty remap array.
func _new_run_request(transaction_receipt: Dictionary) -> Dictionary:
	return {
		"transaction_id": str(transaction_receipt.get("token", "")),
		"transaction_issuer_receipt": transaction_receipt,
		"kind": "new_run",
		"existing_run_id": null,
		"source_desktop_timeline_generation": null,
		"remap_source_transaction_ids": [],
	}


## Plan line 729: restore requires a nonblank existing run, a nonnegative source generation, and the
## already sorted unique complete set of rewindable source transaction IDs.
func _restore_request(transaction_receipt: Dictionary) -> Dictionary:
	return {
		"transaction_id": str(transaction_receipt.get("token", "")),
		"transaction_issuer_receipt": transaction_receipt,
		"kind": "restore",
		"existing_run_id": "run_id.previous",
		"source_desktop_timeline_generation": 0,
		"remap_source_transaction_ids": ["transaction_id.a", "transaction_id.b"],
	}


# ---------------------------------------------------------------------------------------------
# Deferred issuance (dwm-634.1): the issuer offers the root's in-memory mint and flush under the
# same allocator-purpose refusals as issue().
# ---------------------------------------------------------------------------------------------

func test_issue_deferred_delegates_once_and_refuses_the_two_allocator_purposes() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	var issued: Dictionary = issuer.issue_deferred(&"transaction_id")
	if not _require_ok(issued, "issue_deferred(transaction_id)"):
		return
	assert_eq(_issuer_root.calls_to(&"issue_deferred").size(), 1,
		"the issuer delegates ONE in-memory mint to the root store")
	assert_eq(_issuer_root.calls_to(&"issue").size(), 0, "a deferred issue never takes the durable path")
	var value: Dictionary = issued.get("value", {})
	var keys := value.keys()
	keys.sort()
	assert_eq(keys, ["issuer_receipt", "token"] as Array, "issue_deferred returns exactly value={token,issuer_receipt}")
	assert_eq(value.get("token"), FAKE_ROOT_STORE.token_for(NAMESPACE, 1, &"transaction_id"))
	assert_eq(issued.get("receipt"), value.get("issuer_receipt"))
	for purpose: StringName in [&"desktop_timeline_generation", &"causal_day_instance"]:
		var refused: Dictionary = issuer.issue_deferred(purpose)
		assert_false(refused.get("ok", true), "%s is allocated, never issued directly" % String(purpose))
	assert_eq(_issuer_root.calls_to(&"issue_deferred").size(), 1,
		"allocator purposes are refused before the root is reached")


func test_flush_delegates_to_the_root_store() -> void:
	var issuer := _issuer_with_namespace(NAMESPACE, 1)
	if not _require_ok(issuer.issue_deferred(&"transaction_id"), "issue_deferred"):
		return
	var flushed: Dictionary = issuer.flush()
	if not _require_ok(flushed, "flush"):
		return
	assert_eq(_issuer_root.calls_to(&"flush").size(), 1)
	assert_true(bool(flushed.get("value", {}).get("written", false)), "a pending receipt is written")
	var idle: Dictionary = issuer.flush()
	if not _require_ok(idle, "idle flush"):
		return
	assert_false(bool(idle.get("value", {}).get("written", true)))
