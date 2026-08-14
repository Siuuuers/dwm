extends "res://addons/gut/test.gd"
# Behavioral RED contract tests for the shared causal-day advance allocator
# (Plan 02 Task 1, dwm-p2r.16).
#
# OBLIGATION MAP (plan line 797; dwm-p2r.16 DECISION 9.13 puts the per-clause map beside the code).
#   18 both day-advance variants ............................ DEEP   TABLE (2 resolution kinds)
#   19 exact request/result/record shapes ................... DEEP
#   20 derived target day ................................... DEEP   TABLE (source_day 1..6)
#   21 full source/target issuer receipts ................... DEEP   (3 rejection families)
#   22 identical key retry across restart ................... DEEP
#   23 changed-key/request conflict ......................... DEEP   (frozen code asserted)
#   24 duplicate source-day tuple rejection ................. DEEP   (frozen code asserted)
#   25 interleaving stale prepare/reprepare ................. DEEP   (frozen code asserted)
#   26 atomic receipt/map/counter commit .................... DEEP
#   27 every crash cut before/after root commit ............. DEEP   (port half)
#   -- unclaused frozen law, plan line 731 (configure) ...... DEEP
#   -- unclaused frozen law, plan line 746 (source_day 1..6)  breadth
#
# CLAUSE 27 IS SHARED, NOT MOVED (DECISION 10.1). test_desktop_issuer_root_store.gd owns clause 27
# for the ROOT: that its own document survives a cut. This file owns the PORT half: that a cut
# between prepare_advance() and commit_advance() exposes no target causal-day receipt and never
# advances next_counter. Session 1 already shares clauses 16-17 across two files the same way.
#
# THE TWO UNCLAUSED ROWS (DECISION 10.3). Plan line 731 freezes "configure() retains the exact
# already-loaded issuer once; identical replay succeeds and replacement fails" and plan line 746
# freezes source_day 1..6. Neither carries a number among the 46 obligations, and session 1's files
# call configure() only as fixture plumbing. Without these two tests Step 1.3 would implement both
# laws with zero RED coverage anywhere in Task 1. They are listed as unclaused rather than given a
# borrowed clause number so that DECISION 9.11 condition (4) still accounts for every test here.
#
# SUBSTRATE (DECISION 9.4). The REAL DesktopIdentityNonceIssuer over the REAL DesktopIssuerRootStore
# over the REAL JsonFileStorage over FakeFileOps. There is no issuer fake and creating one would be
# a 21st create, breaking Step 1.5's twenty-two-path count. Required anyway: clauses 26 and 27 demand
# proof of an atomic receipt/map/counter commit and of every crash cut, which only a real root write
# can witness. Accepted cost, per 9.4: a Step-1.3 root-store bug surfaces as port failures too.
#
# REJECTION ASSERTIONS (DECISION 9.9). Every skeleton method returns {ok:false, code:
# &"not_implemented"}, so a bare assert_false(result["ok"]) would PASS against the stub and prove
# nothing. Every rejection below asserts failure AND code != &"not_implemented". The plan freezes
# exactly two codes for this file -- causal_day_advance_identity_conflict and
# causal_day_advance_identity_stale (plan line 778) -- and only those two are asserted as literals.
# No other rejection code is invented, per DECISION 5's precedent.
#
# CROSS-VARIANT ANCESTRY. Plan line 746 says the port "rejects cross-variant ancestry" but never
# publishes a resolution_kind -> child_kind mapping. The test below pairs two FROZEN plan-line-537
# child kinds against the wrong resolution_kind and asserts rejection; it does not invent the
# mapping itself, per DECISION 5.
#
# Each test guards on _require_ok() and returns early, so a stubbed method yields exactly one clear
# failure rather than a cascade of index errors -- condition (2) of the DECISION 9.11 RED gate.
# Because configure() is itself stubbed at RED, every test here fails at its first guard; the test
# NAME, not the failure message, is what tells Step 1.3 which law is unmet.

# GLOBAL CLASS NAMES ARE NOT AVAILABLE for the 20 new Task-1 scripts (DECISION 9.18): they have
# never been through an editor import pass, so they are absent from the global script class cache.
# Preloading by path is this repo's established answer. Pre-existing registered classes
# (FakeFileOps, JsonFileStorage, StrictJson, DynamicScriptProbe) are still referenced by name.
const PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const FAKE_NAMESPACE_SOURCE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")

const PORT_PATH := "res://scripts/application/run/CausalDayAdvanceIdentityPort.gd"

const ROOT := "sandbox/identity"
const ROOT_DOCUMENT := "desktop-issuer-root.json"
const ROOT_FINAL_PATH := ROOT + "/" + ROOT_DOCUMENT

const NAMESPACE_A := "1111111111111111111111111111111111111111111111111111111111111111"
const NAMESPACE_B := "2222222222222222222222222222222222222222222222222222222222222222"

# Plan line 735. Both variants of the one shared allocator.
const RESOLUTION_KINDS: Array[String] = ["schedule_done", "condition_hospital"]

# Exact prepare_advance() request member set, plan lines 733-743. Sorted, for a set comparison.
const REQUEST_KEYS: Array[String] = [
	"branch_id",
	"desktop_timeline_generation",
	"resolution_kind",
	"run_id",
	"source_causal_day_instance",
	"source_causal_day_instance_issuer_receipt",
	"source_day",
	"source_resolution_receipt",
]

# Exact day_advance_identity_receipt member set, plan lines 750-773. Sorted, for a set comparison.
const RECEIPT_KEYS: Array[String] = [
	"allocation_key",
	"branch_id",
	"counter_end",
	"counter_start",
	"desktop_timeline_generation",
	"disposition",
	"request_sha256",
	"resolution_kind",
	"root_before_fingerprint",
	"run_id",
	"schema_version",
	"source_causal_day_instance",
	"source_causal_day_instance_issuer_receipt",
	"source_causal_day_instance_receipt_id",
	"source_day",
	"source_resolution_receipt_id",
	"source_resolution_receipt_provenance",
	"source_resolution_receipt_sha256",
	"target_causal_day_instance",
	"target_causal_day_instance_issuer_receipt",
	"target_day",
]

# Plan line 748: prepare succeeds exactly as value={day_advance_identity_candidate,
# day_advance_identity_receipt}, and the candidate is exactly {day_advance_identity_receipt}.
const PREPARE_VALUE_KEYS: Array[String] = [
	"day_advance_identity_candidate",
	"day_advance_identity_receipt",
]
const CANDIDATE_KEYS: Array[String] = ["day_advance_identity_receipt"]

# Plan line 776: commit succeeds exactly as value={day_advance_identity_receipt}.
const COMMIT_VALUE_KEYS: Array[String] = ["day_advance_identity_receipt"]

# Two members of the closed v1 child-kind union, plan line 537. Used only to pair a provenance with
# the WRONG resolution_kind; the correct pairing is deliberately not asserted (DECISION 5).
const SCHEDULE_VARIANT_CHILD_KIND := &"day_resolution_stage"
const HOSPITAL_VARIANT_CHILD_KIND := &"hospital_resolution"

var _file_ops: FakeFileOps
var _storage: JsonFileStorage
var _namespace_source: FAKE_NAMESPACE_SOURCE
var _root: ROOT_STORE
var _issuer: ISSUER
var _port: PORT


func before_each() -> void:
	_file_ops = FakeFileOps.new()
	_storage = JsonFileStorage.new(ROOT, _file_ops)
	_namespace_source = FAKE_NAMESPACE_SOURCE.new(NAMESPACE_A)
	_root = ROOT_STORE.new()
	_issuer = ISSUER.new()
	_port = PORT.new()


# ---------------------------------------------------------------------------------------------
# Retained skeleton probe (Step 1.1 first half). A load failure is a setup defect that invalidates
# RED, so this assertion stays for the life of the file.
# ---------------------------------------------------------------------------------------------

func test_causal_day_advance_identity_port_skeleton_loads() -> void:
	var probe := DynamicScriptProbe.load_script(PORT_PATH)
	assert_true(probe.get("ok", false),
		"CausalDayAdvanceIdentityPort must parse and load: " + str(probe.get("message", "")))


# ---------------------------------------------------------------------------------------------
# Unclaused frozen law, plan line 731 -- configure() retention
# ---------------------------------------------------------------------------------------------

func test_configure_accepts_an_identical_replay_and_refuses_a_replacement() -> void:
	if not _require_ok(_root.configure(_storage, _namespace_source), "root configure"):
		return
	if not _require_ok(_root.load_or_create(), "load_or_create"):
		return
	if not _require_ok(_issuer.configure(_root), "issuer configure"):
		return

	if not _require_ok(_port.configure(_issuer), "port configure"):
		return
	# Plan line 731: "identical replay succeeds and replacement fails."
	_require_ok(_port.configure(_issuer), "identical configure replay")

	var replacement := ISSUER.new()
	replacement.configure(_root)
	_assert_rejected(_port.configure(replacement),
		"plan line 731: replacing an already-retained issuer")


# ---------------------------------------------------------------------------------------------
# Clause 18 -- both day-advance variants (DEEP, table over the two resolution kinds)
# ---------------------------------------------------------------------------------------------

func test_both_resolution_variants_allocate_a_day_advance_identity() -> void:
	var port := _configured_port()
	if port == null:
		return
	for kind: String in RESOLUTION_KINDS:
		var request := _advance_request(kind, 3)
		var prepared := port.prepare_advance(request)
		if not _require_ok(prepared, "prepare_advance for %s" % kind):
			return
		var receipt := _prepared_receipt(prepared)
		assert_eq(receipt.get("resolution_kind"), kind,
			"plan line 735: the receipt carries the requesting variant for %s" % kind)
		assert_eq(receipt.get("disposition"), "causal_day_advance_identity_allocated",
			"plan line 772 freezes the disposition for %s" % kind)

		var committed := port.commit_advance(_prepared_candidate(prepared))
		if not _require_ok(committed, "commit_advance for %s" % kind):
			return
		var commit_keys := (committed.get("value", {}) as Dictionary).keys()
		commit_keys.sort()
		assert_eq(commit_keys, COMMIT_VALUE_KEYS,
			"plan line 776: commit succeeds exactly as value={day_advance_identity_receipt}")


# ---------------------------------------------------------------------------------------------
# Clause 19 -- exact request/result/record shapes (DEEP)
# ---------------------------------------------------------------------------------------------

func test_prepare_advance_returns_the_exact_frozen_result_shape() -> void:
	var port := _configured_port()
	if port == null:
		return
	var prepared := port.prepare_advance(_advance_request("schedule_done", 1))
	if not _require_ok(prepared, "prepare_advance"):
		return

	var value := prepared.get("value", {}) as Dictionary
	var value_keys := value.keys()
	value_keys.sort()
	assert_eq(value_keys, PREPARE_VALUE_KEYS, "plan line 748 freezes exactly these two members")

	var candidate := value.get("day_advance_identity_candidate", {}) as Dictionary
	var candidate_keys := candidate.keys()
	candidate_keys.sort()
	assert_eq(candidate_keys, CANDIDATE_KEYS,
		"plan line 748: the candidate is exactly {day_advance_identity_receipt}")

	# Plan line 748: "with outer receipt byte-equal to day_advance_identity_receipt."
	assert_eq(candidate.get("day_advance_identity_receipt"),
		value.get("day_advance_identity_receipt"),
		"plan line 748: the candidate's receipt is byte-equal to the returned receipt")


func test_the_day_advance_receipt_carries_exactly_the_frozen_member_set() -> void:
	var port := _configured_port()
	if port == null:
		return
	var prepared := port.prepare_advance(_advance_request("condition_hospital", 2))
	if not _require_ok(prepared, "prepare_advance"):
		return
	var receipt := _prepared_receipt(prepared)
	var keys := receipt.keys()
	keys.sort()
	assert_eq(keys, RECEIPT_KEYS, "plan lines 750-773 freeze exactly these twenty-one members")
	assert_eq(receipt.get("schema_version"), 1, "schema_version is exactly 1")


func test_prepare_advance_exact_key_validates_its_request() -> void:
	var port := _configured_port()
	if port == null:
		return

	for missing: String in REQUEST_KEYS:
		var short_request := _advance_request("schedule_done", 4)
		short_request.erase(missing)
		_assert_rejected(port.prepare_advance(short_request),
			"plan line 746: a request missing %s is exact-key-invalid" % missing)

	# Plan line 746: "no caller supplies a target day, target identity, counter, key, or hash."
	for extra: String in ["target_day", "target_causal_day_instance", "allocation_key",
			"counter_start", "request_sha256"]:
		var wide_request := _advance_request("schedule_done", 4)
		wide_request[extra] = 0
		_assert_rejected(port.prepare_advance(wide_request),
			"plan line 746: a caller may not supply %s" % extra)


# ---------------------------------------------------------------------------------------------
# Clause 20 -- derived target day (DEEP, table over the legal source days)
# ---------------------------------------------------------------------------------------------

func test_target_day_is_derived_as_source_day_plus_one() -> void:
	var port := _configured_port()
	if port == null:
		return
	for source_day: int in range(1, 7):
		var prepared := port.prepare_advance(_advance_request("schedule_done", source_day))
		if not _require_ok(prepared, "prepare_advance from day %d" % source_day):
			return
		var receipt := _prepared_receipt(prepared)
		assert_eq(receipt.get("source_day"), source_day,
			"the receipt echoes source_day %d" % source_day)
		assert_eq(receipt.get("target_day"), source_day + 1,
			"plan line 746: the port derives target_day = source_day + 1 for day %d" % source_day)


# ---------------------------------------------------------------------------------------------
# Unclaused frozen law, plan line 746 -- source_day is 1..6
# ---------------------------------------------------------------------------------------------

func test_a_source_day_outside_one_to_six_is_rejected() -> void:
	var port := _configured_port()
	if port == null:
		return
	for illegal: int in [-1, 0, 7, 8]:
		_assert_rejected(port.prepare_advance(_advance_request("schedule_done", illegal)),
			"plan line 746: source_day is 1..6, so %d is rejected" % illegal)


# ---------------------------------------------------------------------------------------------
# Clause 21 -- full source/target issuer receipts (DEEP, three rejection families)
# ---------------------------------------------------------------------------------------------

func test_the_target_receipt_is_a_causal_day_receipt_one_counter_above_the_source() -> void:
	var port := _configured_port()
	if port == null:
		return
	var prepared := port.prepare_advance(_advance_request("schedule_done", 1))
	if not _require_ok(prepared, "prepare_advance"):
		return
	var receipt := _prepared_receipt(prepared)
	var target := receipt.get("target_causal_day_instance_issuer_receipt", {}) as Dictionary

	# Plan line 776: "a normal existing issuer receipt with purpose causal_day_instance, token equal
	# to target_causal_day_instance, and counter_end == counter_start + 1."
	assert_eq(target.get("purpose"), &"causal_day_instance",
		"plan line 776: the target receipt's purpose is causal_day_instance")
	assert_eq(target.get("token"), receipt.get("target_causal_day_instance"),
		"plan line 776: the target receipt's token equals target_causal_day_instance")
	assert_eq(receipt.get("counter_end"), int(receipt.get("counter_start", 0)) + 1,
		"plan line 776: counter_end == counter_start + 1")


func test_the_source_receipt_must_be_the_full_byte_equal_ledger_receipt() -> void:
	var port := _configured_port()
	if port == null:
		return
	var request := _advance_request("schedule_done", 1)

	# Plan line 746: the port "requires that receipt's purpose/token equal causal_day_instance /
	# source_causal_day_instance". An ID-only stand-in is not a full receipt.
	var id_only := request.duplicate(true)
	id_only["source_causal_day_instance_issuer_receipt"] = {
		"receipt_id": str((request["source_causal_day_instance_issuer_receipt"] as Dictionary)
			.get("receipt_id", "")),
	}
	_assert_rejected(port.prepare_advance(id_only),
		"plan line 746: an ID-only source causal-day receipt is not the full receipt")

	# Byte-changed: structurally complete, but no longer equal to the ledger record.
	var mutated := request.duplicate(true)
	(mutated["source_causal_day_instance_issuer_receipt"] as Dictionary)["counter"] = 999_999
	_assert_rejected(port.prepare_advance(mutated),
		"plan line 776: the embedded source receipt must be byte-equal to the external-root record")

	# Token disagreement between the two request members that must name the same identity.
	var mismatched := request.duplicate(true)
	mismatched["source_causal_day_instance"] = "not-the-receipts-token"
	_assert_rejected(port.prepare_advance(mismatched),
		"plan line 746: the receipt's token must equal source_causal_day_instance")


func test_cross_variant_ancestry_is_rejected() -> void:
	var port := _configured_port()
	if port == null:
		return

	var schedule_with_hospital_ancestry := _advance_request("schedule_done", 1)
	_set_resolution_child_kind(schedule_with_hospital_ancestry, HOSPITAL_VARIANT_CHILD_KIND)
	_assert_rejected(port.prepare_advance(schedule_with_hospital_ancestry),
		"plan line 746: schedule_done may not carry hospital-variant resolution ancestry")

	var hospital_with_schedule_ancestry := _advance_request("condition_hospital", 1)
	_set_resolution_child_kind(hospital_with_schedule_ancestry, SCHEDULE_VARIANT_CHILD_KIND)
	_assert_rejected(port.prepare_advance(hospital_with_schedule_ancestry),
		"plan line 746: condition_hospital may not carry schedule-variant resolution ancestry")


# ---------------------------------------------------------------------------------------------
# Clause 22 -- identical key retry across restart (DEEP)
# ---------------------------------------------------------------------------------------------

func test_an_identical_key_and_request_returns_the_original_receipt_after_a_restart() -> void:
	var port := _configured_port()
	if port == null:
		return
	var request := _advance_request("schedule_done", 2)
	var prepared := port.prepare_advance(request.duplicate(true))
	if not _require_ok(prepared, "prepare_advance"):
		return
	var committed := port.commit_advance(_prepared_candidate(prepared))
	if not _require_ok(committed, "commit_advance"):
		return
	var original := (committed.get("value", {}) as Dictionary)\
		.get("day_advance_identity_receipt", {}) as Dictionary

	# A genuine process restart: the whole stack is rebuilt over the same persisted bytes, and the
	# restarted store is given a DIFFERENT namespace source so that silently regenerating a
	# namespace instead of loading the persisted one is observable rather than quietly passing.
	var restarted := _port_over_bytes(_file_ops.snapshot_persisted(), NAMESPACE_B)
	if restarted == null:
		return
	var replayed := restarted.prepare_advance(request.duplicate(true))
	if not _require_ok(replayed, "identical prepare_advance after restart"):
		return
	assert_eq(_prepared_receipt(replayed), original,
		"plan line 778: an occupied key plus byte-identical request returns the original receipt")


# ---------------------------------------------------------------------------------------------
# Clause 23 -- changed-key/request conflict (DEEP, frozen code asserted)
# ---------------------------------------------------------------------------------------------

func test_changed_request_bytes_against_an_occupied_key_conflict() -> void:
	var port := _configured_port()
	if port == null:
		return
	var request := _advance_request("schedule_done", 2)
	var prepared := port.prepare_advance(request.duplicate(true))
	if not _require_ok(prepared, "prepare_advance"):
		return
	if not _require_ok(port.commit_advance(_prepared_candidate(prepared)), "commit_advance"):
		return

	# Same allocation_key (resolution_kind + ":" + source_resolution_receipt_id is unchanged), but
	# different request bytes. Plan line 778: "changed request bytes ... returns
	# causal_day_advance_identity_conflict."
	var changed := request.duplicate(true)
	changed["branch_id"] = "a-different-branch"
	_assert_rejected_with(port.prepare_advance(changed),
		&"causal_day_advance_identity_conflict",
		"plan line 778: changed request bytes for an occupied key")


# ---------------------------------------------------------------------------------------------
# Clause 24 -- duplicate source-day tuple rejection (DEEP, frozen code asserted)
# ---------------------------------------------------------------------------------------------

func test_a_second_allocation_key_for_the_same_tuple_conflicts() -> void:
	var port := _configured_port()
	if port == null:
		return
	var request := _advance_request("schedule_done", 2)
	var prepared := port.prepare_advance(request.duplicate(true))
	if not _require_ok(prepared, "prepare_advance"):
		return
	if not _require_ok(port.commit_advance(_prepared_candidate(prepared)), "commit_advance"):
		return

	# Plan line 778: the tuple (run_id, branch_id, desktop_timeline_generation,
	# source_causal_day_instance, source_day) "may belong to only one allocation key across both
	# variants". Changing only the resolution receipt changes the KEY while holding the tuple fixed.
	var second_key := request.duplicate(true)
	second_key["source_resolution_receipt"] = _resolution_receipt("schedule_done")
	_assert_rejected_with(port.prepare_advance(second_key),
		&"causal_day_advance_identity_conflict",
		"plan line 778: a second allocation key for one source-day tuple")

	# ... and across the two variants, not merely within one.
	var other_variant := _advance_request("condition_hospital", 2)
	other_variant["run_id"] = request["run_id"]
	other_variant["branch_id"] = request["branch_id"]
	other_variant["desktop_timeline_generation"] = request["desktop_timeline_generation"]
	other_variant["source_causal_day_instance"] = request["source_causal_day_instance"]
	other_variant["source_causal_day_instance_issuer_receipt"] = \
		(request["source_causal_day_instance_issuer_receipt"] as Dictionary).duplicate(true)
	_assert_rejected_with(port.prepare_advance(other_variant),
		&"causal_day_advance_identity_conflict",
		"plan line 778: the tuple is unique ACROSS both variants, not within one")


# ---------------------------------------------------------------------------------------------
# Clause 25 -- interleaving stale prepare/reprepare (DEEP, frozen code asserted)
# ---------------------------------------------------------------------------------------------

func test_an_intervening_allocation_makes_a_prepared_candidate_stale() -> void:
	var port := _configured_port()
	if port == null:
		return
	var first := port.prepare_advance(_advance_request("schedule_done", 2))
	if not _require_ok(first, "first prepare_advance"):
		return

	# An unrelated allocation lands between prepare and commit, moving the root fingerprint/counter.
	var interleaved := port.prepare_advance(_advance_request("condition_hospital", 5))
	if not _require_ok(interleaved, "interleaved prepare_advance"):
		return
	if not _require_ok(port.commit_advance(_prepared_candidate(interleaved)),
			"interleaved commit_advance"):
		return

	# Plan line 778: "For an absent key, commit requires the exact prepared root
	# fingerprint/counter; an intervening allocation returns causal_day_advance_identity_stale."
	_assert_rejected_with(port.commit_advance(_prepared_candidate(first)),
		&"causal_day_advance_identity_stale",
		"plan line 778: committing a candidate prepared before an intervening allocation")


func test_a_reprepared_candidate_commits_after_a_stale_rejection() -> void:
	var port := _configured_port()
	if port == null:
		return
	var request := _advance_request("schedule_done", 2)
	var stale := port.prepare_advance(request.duplicate(true))
	if not _require_ok(stale, "first prepare_advance"):
		return
	var interleaved := port.prepare_advance(_advance_request("condition_hospital", 5))
	if not _require_ok(interleaved, "interleaved prepare_advance"):
		return
	if not _require_ok(port.commit_advance(_prepared_candidate(interleaved)),
			"interleaved commit_advance"):
		return
	port.commit_advance(_prepared_candidate(stale))

	# Plan line 778: "the caller must reprepare before exposing or checkpointing a target."
	var reprepared := port.prepare_advance(request.duplicate(true))
	if not _require_ok(reprepared, "reprepare after stale"):
		return
	_require_ok(port.commit_advance(_prepared_candidate(reprepared)),
		"plan line 778: a reprepared candidate commits cleanly")


# ---------------------------------------------------------------------------------------------
# Clause 26 -- atomic receipt/map/counter commit (DEEP)
# ---------------------------------------------------------------------------------------------

func test_commit_adds_the_target_receipt_the_record_and_the_counter_in_one_write() -> void:
	var port := _configured_port()
	if port == null:
		return
	var request := _advance_request("schedule_done", 3)
	var before := _captured_document()
	if before.is_empty():
		return
	var counter_before := int(before.get("next_counter", 0))

	var prepared := port.prepare_advance(request)
	if not _require_ok(prepared, "prepare_advance"):
		return

	# Plan line 748: prepare is mutation-free.
	var between := _captured_document()
	assert_eq(between, before, "plan line 748: prepare_advance mutates nothing")

	var receipt := _prepared_receipt(prepared)
	if not _require_ok(port.commit_advance(_prepared_candidate(prepared)), "commit_advance"):
		return

	var after := _captured_document()
	if after.is_empty():
		return
	# Plan line 776: "That ONE atomic root write adds the target issuer receipt, adds the exact
	# allocation record, and advances next_counter; no target becomes durable separately from its
	# key."
	assert_eq(int(after.get("next_counter", 0)), counter_before + 1,
		"plan line 776: the commit advances next_counter by exactly one")
	var records := after.get("day_advance_allocation_receipts", {}) as Dictionary
	assert_true(records.has(str(receipt.get("allocation_key", ""))),
		"plan line 776: the commit adds the allocation record under its exact key")
	assert_eq(records.get(str(receipt.get("allocation_key", ""))), receipt,
		"plan line 776: the stored record is byte-equal to the prepared receipt")
	var receipts := after.get("receipts", {}) as Dictionary
	assert_true(receipts.has(str(receipt.get("target_causal_day_instance_receipt_id", ""))) or
		receipts.has(str((receipt.get("target_causal_day_instance_issuer_receipt", {})
			as Dictionary).get("receipt_id", ""))),
		"plan line 776: the same write adds the target issuer receipt")


# ---------------------------------------------------------------------------------------------
# Clause 27 (port half) -- every crash cut before/after root commit (DEEP)
# ---------------------------------------------------------------------------------------------

func test_no_crash_cut_around_commit_exposes_a_target_without_its_key() -> void:
	var port := _configured_port()
	if port == null:
		return
	var request := _advance_request("schedule_done", 3)
	var baseline := _captured_document()
	if baseline.is_empty():
		return
	var baseline_counter := int(baseline.get("next_counter", 0))
	var baseline_bytes := _file_ops.snapshot_persisted()

	for cut: int in range(1, 13):
		var cut_ops := FakeFileOps.new(baseline_bytes.duplicate(true))
		var cut_port := _port_over_ops(cut_ops, NAMESPACE_A)
		if cut_port == null:
			return
		var prepared := cut_port.prepare_advance(request.duplicate(true))
		if not _require_ok(prepared, "prepare_advance at cut %d" % cut):
			return
		cut_ops.fail_after(cut_ops.operation_count() + cut)
		cut_port.commit_advance(_prepared_candidate(prepared))

		var recovered := _document_from_bytes(cut_ops.snapshot_persisted())
		if recovered.is_empty():
			assert_true(false, "the root must remain recoverable after a crash at cut %d" % cut)
			return
		var recovered_counter := int(recovered.get("next_counter", -1))
		assert_true(
			recovered_counter == baseline_counter or recovered_counter == baseline_counter + 1,
			"cut %d leaves the counter at exactly the old or the new value, never torn" % cut)

		# The port half of clause 27: a target identity is never durable without its allocation key.
		var records := recovered.get("day_advance_allocation_receipts", {}) as Dictionary
		var receipts := recovered.get("receipts", {}) as Dictionary
		var target_id := str((_prepared_receipt(prepared)
			.get("target_causal_day_instance_issuer_receipt", {}) as Dictionary).get("receipt_id", ""))
		if receipts.has(target_id):
			assert_eq(records.size(), 1,
				"cut %d: a durable target receipt implies its allocation record is durable too" % cut)
		else:
			assert_eq(records.size(), 0,
				"cut %d: no allocation record may outlive a target receipt that never landed" % cut)


# ---------------------------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------------------------

func _require_ok(result: Dictionary, label: String) -> bool:
	var ok: bool = result.get("ok", false)
	assert_true(ok, "%s must succeed: %s" % [label, result])
	return ok


## DECISION 9.9: a rejection must be distinguishable from an unimplemented skeleton.
func _assert_rejected(result: Dictionary, label: String) -> void:
	assert_false(result.get("ok", true), "%s must be rejected" % label)
	assert_ne(result.get("code", &"not_implemented"), &"not_implemented",
		"%s must fail with a real typed code, not the skeleton envelope" % label)


## For the two codes plan line 778 actually freezes. No other code is asserted as a literal.
func _assert_rejected_with(result: Dictionary, code: StringName, label: String) -> void:
	_assert_rejected(result, label)
	assert_eq(result.get("code"), code, "%s must fail with %s" % [label, String(code)])


## Builds the full real stack: port over issuer over root store over JsonFileStorage over
## FakeFileOps (DECISION 9.4). Returns null once any layer refuses, so the caller returns early
## with exactly one failure instead of a cascade.
func _configured_port() -> PORT:
	if not _require_ok(_root.configure(_storage, _namespace_source), "root configure"):
		return null
	if not _require_ok(_root.load_or_create(), "load_or_create"):
		return null
	if not _require_ok(_issuer.configure(_root), "issuer configure"):
		return null
	if not _require_ok(_port.configure(_issuer), "port configure"):
		return null
	return _port


func _port_over_ops(ops: FakeFileOps, namespace_hex: String) -> PORT:
	var storage := JsonFileStorage.new(ROOT, ops)
	var root := ROOT_STORE.new()
	if not _require_ok(root.configure(storage, FAKE_NAMESPACE_SOURCE.new(namespace_hex)),
			"root configure over supplied bytes"):
		return null
	if not _require_ok(root.load_or_create(), "load_or_create over supplied bytes"):
		return null
	var issuer := ISSUER.new()
	if not _require_ok(issuer.configure(root), "issuer configure over supplied bytes"):
		return null
	var port := PORT.new()
	if not _require_ok(port.configure(issuer), "port configure over supplied bytes"):
		return null
	return port


func _port_over_bytes(persisted: Dictionary, namespace_hex: String) -> PORT:
	return _port_over_ops(FakeFileOps.new(persisted), namespace_hex)


func _captured_document() -> Dictionary:
	var captured := _root.capture()
	if not _require_ok(captured, "capture"):
		return {}
	return captured.get("value", {})


func _document_from_bytes(persisted: Dictionary) -> Dictionary:
	if not persisted.has(ROOT_FINAL_PATH):
		return {}
	var bytes: PackedByteArray = persisted[ROOT_FINAL_PATH]
	var parsed := StrictJson.parse_object(bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		return {}
	return parsed.get("value", {})


func _prepared_receipt(prepared: Dictionary) -> Dictionary:
	return (prepared.get("value", {}) as Dictionary).get("day_advance_identity_receipt", {})


func _prepared_candidate(prepared: Dictionary) -> Dictionary:
	return (prepared.get("value", {}) as Dictionary).get("day_advance_identity_candidate", {})


## The frozen prepare_advance() request, plan lines 733-743. Source identities are drawn from the
## real ledger where the ledger will answer; at RED it does not, and the empty receipts that result
## still exercise the exact request SHAPE, so each test fails on its own law rather than on a
## missing fixture (session 1's _issue_transaction_receipt precedent).
func _advance_request(resolution_kind: String, source_day: int) -> Dictionary:
	var resolution_receipt := _resolution_receipt(resolution_kind)
	var source_receipt := _causal_day_receipt()
	return {
		"resolution_kind": resolution_kind,
		"source_resolution_receipt": resolution_receipt,
		"run_id": "run-" + resolution_kind,
		"branch_id": "branch-" + resolution_kind,
		"desktop_timeline_generation": 0,
		"source_day": source_day,
		"source_causal_day_instance": str(source_receipt.get("token", "")),
		"source_causal_day_instance_issuer_receipt": source_receipt,
	}


## Session 1's precedent: the root store answers value={token, issuer_receipt}, so the receipt is
## read out of `issuer_receipt` (see _issuer_receipt in test_desktop_issuer_root_store.gd).
func _issuer_receipt(issued: Dictionary) -> Dictionary:
	if not issued.get("ok", false):
		return {}
	return (issued.get("value", {}) as Dictionary).get("issuer_receipt", {})


func _resolution_receipt(resolution_kind: String) -> Dictionary:
	var parent_receipt := _issuer_receipt(_root.issue(&"transaction_id"))
	if parent_receipt.is_empty():
		return {}
	var child_kind := &"day_resolution_stage"
	if resolution_kind == "condition_hospital":
		child_kind = &"hospital_resolution"
	var derived: Dictionary = _issuer.derive_child({
		"parent_receipt_id": str(parent_receipt.get("receipt_id", "")),
		"child_kind": child_kind,
		"ordinal": 0,
		"source_ids": [],
	})
	if not _require_ok(derived, "derive anchored %s resolution receipt" % resolution_kind):
		return {}
	var value: Dictionary = derived.get("value", {})
	return {
		"receipt_id": str(value.get("child_id", "")),
		"provenance": (value.get("provenance", {}) as Dictionary).duplicate(true),
	}


func _causal_day_receipt() -> Dictionary:
	return _issuer_receipt(_root.issue(&"causal_day_instance"))


func _causal_day_token() -> String:
	return str(_causal_day_receipt().get("token", ""))


## Sets the child_kind on the request's resolution provenance without asserting which kind belongs
## to which variant -- only that a MISMATCHED pairing is refused (DECISION 5, DECISION 10.3).
func _set_resolution_child_kind(request: Dictionary, child_kind: StringName) -> void:
	var receipt := request.get("source_resolution_receipt", {}) as Dictionary
	var provenance := receipt.get("provenance", {}) as Dictionary
	provenance["child_kind"] = child_kind
	receipt["provenance"] = provenance
	request["source_resolution_receipt"] = receipt
