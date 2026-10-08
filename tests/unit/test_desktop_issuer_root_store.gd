extends "res://addons/gut/test.gd"
# Behavioral RED contract tests for the durable external issuer root (Plan 02 Task 1, dwm-p2r.16).
#
# OBLIGATION MAP (plan line 797; dwm-p2r.16 DECISION 9.13 puts the per-clause map beside the code).
#   13 namespace initialization ............................. breadth
#   14 occupied-counter conflict ............................ DEEP   (stale/conflict path)
#   15 durable-write failure returns no token ............... DEEP   (crash cut)
#   16 no API lowers the counter ............................ breadth
#   17 post-call mutation ................................... breadth
#   27 every crash cut before/after root commit ............. DEEP
#   28 exact root-document key set .......................... breadth (complete at breadth)
#   29 empty day_advance_allocation_receipts default ........ breadth (complete at breadth)
#   30 schema rejection missing/extra/malformed ............. SHALLOW -> dwm-p2r.16.1
#   31 capture detachment ................................... breadth (complete at breadth)
#   32 disjoint allocation-map key laws ..................... DEEP   (conflict path)
#   33 persistence/reload ................................... breadth (complete at breadth)
#   34 rejection of deletion/replacement .................... SHALLOW -> dwm-p2r.16.1
#   35 source/target receipt not byte-equal to receipts ..... SHALLOW -> dwm-p2r.16.1
#
# SUBSTRATE (DECISION 9.3). The subject under test is the REAL DesktopIssuerRootStore over the REAL
# JsonFileStorage over FakeFileOps. FakeFileOps supplies fail_after(ordinal) for genuine crash cuts
# and retains its persisted bytes, so a restart is modelled by rebuilding the whole stack over those
# same bytes rather than by simulating one. A hand-rolled storage double was rejected: it would
# verify the double's idea of atomicity instead of JsonFileStorage's.
#
# REJECTION ASSERTIONS (DECISION 9.9). Every skeleton method returns {ok:false, code:
# &"not_implemented"}, so a bare assert_false(result["ok"]) would PASS against the stub and prove
# nothing. Every rejection below therefore asserts failure AND code != &"not_implemented" via
# _assert_rejected(). Exact code literals are asserted only where the plan freezes them; the plan
# freezes none for this file, so none are invented (DECISION 5's precedent).
#
# Each test guards on _require_ok() and returns early, so a stubbed method yields exactly one clear
# failure rather than a cascade of index errors -- condition (2) of the DECISION 9.11 RED gate.

# GLOBAL CLASS NAMES ARE NOT AVAILABLE for the 20 new Task-1 scripts: they have never been through
# an editor import pass, so they are absent from the global script class cache -- the same root
# cause as the DECISION 8 CORRECTION about missing .uid siblings. Preloading by path is this repo's
# established answer (see ScheduleRegistryFixtures and test_json_file_storage) and keeps the working
# tree exactly as that correction describes. Pre-existing registered classes (FakeFileOps,
# JsonFileStorage, StrictJson, DynamicScriptProbe) are still referenced by name.
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const DAY_ADVANCE_PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const FAKE_NAMESPACE_SOURCE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

const SKELETON_PATHS := {
	"DesktopIssuerRootStore": "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd",
	"CryptoDesktopNamespaceSource": "res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd",
	"FakeDesktopNamespaceSource": "res://tests/support/FakeDesktopNamespaceSource.gd",
	"FakeDesktopIssuerRootStore": "res://tests/support/FakeDesktopIssuerRootStore.gd",
}

const ROOT := "sandbox/identity"
const ROOT_DOCUMENT := "desktop-issuer-root.json"
const ROOT_FINAL_PATH := ROOT + "/" + ROOT_DOCUMENT

# The plan's own Step 1.1 fixture uses this namespace.
const NAMESPACE_A := "1111111111111111111111111111111111111111111111111111111111111111"
const NAMESPACE_B := "2222222222222222222222222222222222222222222222222222222222222222"

# Exact append-only document, plan line 1682. Sorted, for a set comparison.
const ROOT_DOCUMENT_KEYS: Array[String] = [
	"allocation_receipts",
	"day_advance_allocation_receipts",
	"namespace",
	"next_counter",
	"receipts",
	"schema_version",
]

# Exact receipt member set, plan line 535. Sorted, for a set comparison.
const RECEIPT_KEYS: Array[String] = [
	"counter",
	"namespace",
	"numeric_value",
	"purpose",
	"receipt_id",
	"token",
]

# The root-private persisted continuation candidate. Plan line 1712 adds transaction_remap to the
# candidate that prepare, commit, and restart reconstruction must reproduce byte-for-byte.
const CONTINUATION_CANDIDATE_KEYS: Array[String] = [
	"branch_id",
	"branch_id_issuer_receipt",
	"causal_day_instance",
	"causal_day_instance_issuer_receipt",
	"desktop_timeline_generation",
	"desktop_timeline_generation_issuer_receipt",
	"kind",
	"remap_transaction_issuer_receipts",
	"request",
	"root_namespace",
	"root_next_counter",
	"run_id",
	"run_id_issuer_receipt",
	"schema_version",
	"transaction_remap",
]

# The closed v1 purpose union, plan line 535. The ROOT accepts all ten: refusing the two allocator
# purposes is the ISSUER's law (plan line 729), and a root that refused them could never allocate a
# generation or a causal day at all.
const PURPOSE_UNION: Array[StringName] = [
	&"run_id",
	&"branch_id",
	&"desktop_timeline_generation",
	&"causal_day_instance",
	&"board_id",
	&"transaction_id",
	&"placement_nonce",
	&"debug_nonce",
	&"explosion_nonce",
	&"receipt_id",
]

var _file_ops: FakeFileOps
var _storage: JsonFileStorage
var _namespace_source: FAKE_NAMESPACE_SOURCE
var _store: ROOT_STORE


func before_each() -> void:
	_file_ops = FakeFileOps.new()
	_storage = JsonFileStorage.new(ROOT, _file_ops)
	_namespace_source = FAKE_NAMESPACE_SOURCE.new(NAMESPACE_A)
	_store = ROOT_STORE.new()


# ---------------------------------------------------------------------------------------------
# Retained skeleton probes (Step 1.1 first half). A load failure is a setup defect that invalidates
# RED, so these must keep passing while every behavioral test below fails.
# ---------------------------------------------------------------------------------------------

func test_issuer_root_store_skeletons_load() -> void:
	for label: String in SKELETON_PATHS:
		var probe := DynamicScriptProbe.load_script(str(SKELETON_PATHS[label]))
		assert_true(probe.get("ok", false),
			"%s must parse and load: %s" % [label, str(probe.get("message", ""))])


# ---------------------------------------------------------------------------------------------
# Clause 13 -- namespace initialization
# ---------------------------------------------------------------------------------------------

func test_load_or_create_persists_the_namespace_and_opens_at_counter_one() -> void:
	if not _require_ok(_store.configure(_storage, _namespace_source), "configure"):
		return
	if not _require_ok(_store.load_or_create(), "load_or_create"):
		return
	assert_eq(_namespace_source.generate_calls, 1,
		"the namespace comes from the injected source exactly once")
	var document := _captured_document()
	if document.is_empty():
		return
	assert_eq(document.get("namespace"), NAMESPACE_A, "the generated namespace is persisted")
	assert_eq(document.get("next_counter"), 1,
		"plan line 1682: the store commits lowercase hex and counter 1 before anything is issued")
	assert_eq(document.get("receipts"), {}, "a fresh root has no receipts")


func test_the_namespace_is_never_regenerated_after_the_first_use() -> void:
	if not _require_ok(_store.configure(_storage, _namespace_source), "configure"):
		return
	if not _require_ok(_store.load_or_create(), "load_or_create"):
		return
	_store.load_or_create()
	_store.issue(&"debug_nonce")
	_store.issue(&"transaction_id")
	assert_eq(_namespace_source.generate_calls, 1,
		"plan line 535: a namespace is never reconstructed once persisted")


func test_a_namespace_source_failure_leaves_no_usable_root() -> void:
	_namespace_source.fail_with()
	if not _require_ok(_store.configure(_storage, _namespace_source), "configure"):
		return
	_assert_rejected(_store.load_or_create(), "load_or_create without a namespace")
	_assert_rejected(_store.issue(&"debug_nonce"), "issue before a namespace exists")


# ---------------------------------------------------------------------------------------------
# Clauses 28, 29, 31 -- root document shape
# ---------------------------------------------------------------------------------------------

func test_the_root_document_has_exactly_the_frozen_key_set() -> void:
	var document := _opened_document()
	if document.is_empty():
		return
	var keys := document.keys()
	keys.sort()
	assert_eq(keys, ROOT_DOCUMENT_KEYS, "plan line 1682 freezes exactly these six members")
	assert_eq(document.get("schema_version"), 1, "schema_version is exactly 1")


func test_day_advance_allocation_receipts_defaults_to_an_empty_map() -> void:
	var document := _opened_document()
	if document.is_empty():
		return
	assert_eq(document.get("day_advance_allocation_receipts"), {},
		"plan line 1682: day_advance_allocation_receipts defaults to {} and is schema-required")
	assert_eq(document.get("allocation_receipts"), {},
		"the transaction-keyed map is independently empty on a fresh root")


func test_capture_is_detached_from_the_store() -> void:
	var document := _opened_document()
	if document.is_empty():
		return
	document["next_counter"] = 9999
	(document.get("receipts", {}) as Dictionary)["forged"] = {"purpose": "run_id"}
	var reread := _captured_document()
	if reread.is_empty():
		return
	assert_eq(reread.get("next_counter"), 1, "mutating a captured document cannot reach the store")
	assert_eq(reread.get("receipts"), {}, "the captured receipt map is a detached copy")


# ---------------------------------------------------------------------------------------------
# Issuance -- the frozen preimages and the counter law
# ---------------------------------------------------------------------------------------------

func test_issue_advances_the_persisted_counter_before_returning_a_token() -> void:
	if _opened_document().is_empty():
		return
	var issued := _store.issue(&"debug_nonce")
	if not _require_ok(issued, "issue(debug_nonce)"):
		return
	var receipt := _issuer_receipt(issued)
	assert_eq(receipt.get("counter"), 1, "the first issued receipt takes counter 1")
	assert_eq(issued.get("receipt"), receipt,
		"plan line 535: the outer receipt is byte-equal to the issuer_receipt")
	var document := _captured_document()
	if document.is_empty():
		return
	assert_eq(document.get("next_counter"), 2,
		"plan line 535: issuance advances the monotonic counter BEFORE returning any token")


func test_every_purpose_mints_the_frozen_token_and_receipt_preimages() -> void:
	if _opened_document().is_empty():
		return
	var counter := 1
	for purpose: StringName in PURPOSE_UNION:
		var issued := _store.issue(purpose)
		if not _require_ok(issued, "issue(%s)" % String(purpose)):
			return
		var receipt := _issuer_receipt(issued)
		var keys := receipt.keys()
		keys.sort()
		assert_eq(keys, RECEIPT_KEYS, "receipt member set is frozen for %s" % String(purpose))
		var expected_token := FAKE_ROOT_STORE.token_for(NAMESPACE_A, counter, purpose)
		assert_eq(receipt.get("token"), expected_token,
			"frozen token preimage for %s" % String(purpose))
		assert_eq(receipt.get("receipt_id"),
			FAKE_ROOT_STORE.receipt_id_for(NAMESPACE_A, counter, purpose, expected_token),
			"frozen structural receipt key for %s" % String(purpose))
		assert_eq((issued.get("value", {}) as Dictionary).get("token"), expected_token,
			"value.token equals the receipt token for %s" % String(purpose))
		counter += 1


func test_numeric_value_is_null_for_every_nonnumeric_purpose() -> void:
	if _opened_document().is_empty():
		return
	for purpose: StringName in PURPOSE_UNION:
		if purpose == &"desktop_timeline_generation":
			continue
		var issued := _store.issue(purpose)
		if not _require_ok(issued, "issue(%s)" % String(purpose)):
			return
		assert_null(_issuer_receipt(issued).get("numeric_value"),
			"plan line 535: numeric_value is nonnull only for desktop_timeline_generation, not %s"
				% String(purpose))


# ---------------------------------------------------------------------------------------------
# Clause 15 -- durable-write failure (DEEP)
# ---------------------------------------------------------------------------------------------

func test_a_failed_durable_advance_returns_no_token_and_burns_no_counter() -> void:
	if _opened_document().is_empty():
		return
	var before := _captured_document()
	if before.is_empty():
		return
	_file_ops.fail_after(_file_ops.operation_count() + 1)
	var issued := _store.issue(&"debug_nonce")
	_assert_rejected(issued, "issue across a failed durable write")
	assert_false(issued.has("value"), "plan line 729: a failed durable advance returns no token")
	var after := _reloaded_document()
	if after.is_empty():
		return
	assert_eq(after.get("next_counter"), before.get("next_counter"),
		"a failed write leaves the persisted counter exactly where it was")
	assert_eq(after.get("receipts"), before.get("receipts"), "a failed write adds no receipt")
	var retried := _store.issue(&"debug_nonce")
	assert_true(retried.get("ok", false), "the same process can retry after the one-shot storage failure: " + str(retried))
	if retried.get("ok", false):
		assert_eq(int(_issuer_receipt(retried)["counter"]), int(before["next_counter"]),
			"retry mints the unburned counter exactly once")


# ---------------------------------------------------------------------------------------------
# Clause 16 -- no API lowers the counter
# ---------------------------------------------------------------------------------------------

func test_atomic_write_witnesses_are_exact_bounded_and_do_not_skip_cold_parsing() -> void:
	if _opened_document().is_empty(): return
	for index in 5:
		if not _require_ok(_store.issue(&"transaction_id"), "issue for bounded witness"): return
	assert_eq(_store._validated_write_texts.size(), 3)
	var text: String = _store._validated_write_texts.back()
	var canonical: Dictionary = CanonicalJsonWriter.stringify(_captured_document())
	assert_true(canonical.get("ok", false), str(canonical))
	assert_eq(text, str(canonical.get("value", "")),
		"the issue-only assembly remains byte-identical to the canonical whole document")
	assert_true(_store._parse_known_write_document(text).ok)
	assert_false(_store._parse_known_write_document(text + "!").ok, "changed bytes must strict-parse")
	var parsed: Dictionary = _store._parse_document(text)
	assert_true(parsed.ok)
	assert_eq(parsed.value, _captured_document(), "ordinary parsing returns complete document")
	parsed.value.receipts.clear()
	assert_eq(_store._parse_document(text).value.receipts.size(), 5, "returned parse is detached")
	assert_eq(_reloaded_document(), _captured_document(), "cold load still verifies durable receipts")


func test_no_api_lowers_the_counter() -> void:
	if _opened_document().is_empty():
		return
	for purpose: StringName in [&"run_id", &"board_id", &"transaction_id"]:
		if not _require_ok(_store.issue(purpose), "issue(%s)" % String(purpose)):
			return
	var high := int(_captured_document().get("next_counter", -1))
	assert_eq(high, 4, "three issuances from counter 1 leave next_counter at 4")

	# Every remaining public entry point is exercised; none may lower the high-water counter.
	_store.load_or_create()
	_store.capture()
	_store.verify_receipt({}, &"run_id")
	_store.prepare_allocation({})
	_store.commit_allocation({})
	_store.prepare_causal_day_advance({})
	_store.commit_causal_day_advance({})
	var final := _captured_document()
	if final.is_empty():
		return
	assert_eq(final.get("next_counter"), high,
		"plan line 1682: no API accepts a lower counter, and none of these advances it either")


# ---------------------------------------------------------------------------------------------
# Clause 17 -- post-call mutation
# ---------------------------------------------------------------------------------------------

func test_mutating_a_returned_receipt_cannot_reach_the_store() -> void:
	if _opened_document().is_empty():
		return
	var issued := _store.issue(&"transaction_id")
	if not _require_ok(issued, "issue(transaction_id)"):
		return
	var receipt := _issuer_receipt(issued)
	var receipt_id := str(receipt.get("receipt_id", ""))
	receipt["counter"] = -1
	receipt["token"] = "forged"
	var stored: Dictionary = (_captured_document().get("receipts", {}) as Dictionary).get(receipt_id, {})
	assert_eq(stored.get("counter"), 1, "the ledger copy is unaffected by caller mutation")
	assert_ne(stored.get("token"), "forged", "the ledger token is unaffected by caller mutation")


# ---------------------------------------------------------------------------------------------
# Clause 33 -- persistence and reload
# ---------------------------------------------------------------------------------------------

func test_the_root_reloads_byte_for_byte_across_a_restart() -> void:
	if _opened_document().is_empty():
		return
	for purpose: StringName in [&"run_id", &"branch_id", &"debug_nonce"]:
		if not _require_ok(_store.issue(purpose), "issue(%s)" % String(purpose)):
			return
	var before := _captured_document()
	if before.is_empty():
		return
	var reloaded := _reloaded_document()
	if reloaded.is_empty():
		return
	assert_eq(reloaded, before,
		"a restarted store over the same bytes reproduces the exact document, and does NOT mint a "
		+ "second namespace")


# ---------------------------------------------------------------------------------------------
# Clause 30 -- schema rejection (SHALLOW -> dwm-p2r.16.1)
# ---------------------------------------------------------------------------------------------

func test_missing_extra_or_malformed_root_members_are_rejected() -> void:
	var base := {
		"schema_version": 1,
		"namespace": NAMESPACE_A,
		"next_counter": 1,
		"receipts": {},
		"allocation_receipts": {},
		"day_advance_allocation_receipts": {},
	}
	var malformed := {
		"schema_version": "1",
		"namespace": 111,
		"next_counter": "one",
		"receipts": [],
		"allocation_receipts": [],
		"day_advance_allocation_receipts": [],
	}
	var scenarios: Array[Dictionary] = []

	for member: String in ROOT_DOCUMENT_KEYS:
		var missing_member := base.duplicate(true)
		missing_member.erase(member)
		scenarios.append({
			"label": "missing %s" % member,
			"document": missing_member,
		})
	for member: String in malformed.keys():
		var malformed_member := base.duplicate(true)
		malformed_member[member] = malformed[member]
		scenarios.append({
			"label": "malformed %s member" % member,
			"document": malformed_member,
		})

	var extra_member := base.duplicate(true)
	extra_member["unexpected"] = true
	scenarios.append({
		"label": "extra member",
		"document": extra_member,
	})

	for scenario: Dictionary in scenarios:
		var seeded := _store_over_seeded_root(JSON.stringify(scenario["document"]))
		_assert_rejected(seeded.load_or_create(),
			"load_or_create over a root with a %s" % str(scenario["label"]))


# ---------------------------------------------------------------------------------------------
# Clause 34 -- deletion and replacement (SHALLOW -> dwm-p2r.16.1)
# ---------------------------------------------------------------------------------------------

func test_receipt_deletion_and_replacement_are_refused() -> void:
	if _opened_document().is_empty():
		return
	if not _require_ok(_store.issue(&"run_id"), "issue(run_id)"):
		return
	if not _require_ok(_store.issue(&"branch_id"), "issue(branch_id)"):
		return
	var transaction := _store.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var prepared_allocation := _store.prepare_allocation(_new_run_request(_issuer_receipt(transaction)))
	if not _require_ok(prepared_allocation, "prepare_allocation(new_run)"):
		return
	if not _require_ok(_store.commit_allocation(prepared_allocation.get("value", {})),
		"commit_allocation(new_run)"):
		return

	var day_source := _store.issue(&"causal_day_instance")
	if not _require_ok(day_source, "issue(causal_day_instance)"):
		return
	if not _commit_exact_day_advance(_issuer_receipt(day_source)):
		return
	var document: Dictionary = _captured_document()
	if document.is_empty():
		return
	var receipt_ids: Array = (document.get("receipts", {}) as Dictionary).keys()
	if receipt_ids.is_empty():
		return
	for id: String in receipt_ids:
		var receipt_id := str(id)
		var without: Dictionary = document.duplicate(true)
		(without.get("receipts", {}) as Dictionary).erase(receipt_id)
		_assert_rejected(_store_over_seeded_root(JSON.stringify(without)).load_or_create(),
			"plan line 1682: %s deletion from an append-only ledger is forbidden" % receipt_id)

		var replaced: Dictionary = _replace_receipt_member(
			document.duplicate(true), "receipts", receipt_id, "token", "run_id.deadbeef")
		_assert_rejected(_store_over_seeded_root(JSON.stringify(replaced)).load_or_create(),
			"plan line 1682: %s replacement of a receipt is forbidden" % receipt_id)

		var drifted_key := "%s.mismatched" % receipt_id
		var key_mismatch: Dictionary = document.duplicate(true)
		var drifted: Dictionary = (
			(key_mismatch.get("receipts", {}) as Dictionary)[receipt_id] as Dictionary
		).duplicate(true)
		drifted["receipt_id"] = drifted_key
		var key_bucket: Dictionary = key_mismatch.get("receipts", {}) as Dictionary
		key_bucket.erase(receipt_id)
		key_bucket[drifted_key] = drifted
		_assert_rejected(_store_over_seeded_root(JSON.stringify(key_mismatch)).load_or_create(),
			"plan line 1682: %s cannot drift its receipt_id key" % receipt_id)

	var allocation_ids: Array = (document.get("allocation_receipts", {}) as Dictionary).keys()
	for allocation_id: String in allocation_ids:
		var without_allocation := document.duplicate(true)
		(without_allocation.get("allocation_receipts", {}) as Dictionary).erase(allocation_id)
		_assert_rejected(_store_over_seeded_root(JSON.stringify(without_allocation)).load_or_create(),
			"plan line 1682: allocation map entry %s cannot be deleted" % allocation_id)

		var allocation_record := (
			(document.get("allocation_receipts", {}) as Dictionary).get(allocation_id, {}) as Dictionary
		).duplicate(true)
		var run_reference := (allocation_record.get("run_id_issuer_receipt", {}) as Dictionary).duplicate(true)
		if not run_reference.is_empty():
			run_reference["token"] = "allocation.%s.mismatched" % str(allocation_id)
			allocation_record["run_id_issuer_receipt"] = run_reference
			var replaced_allocation := _replace_map_record(document, "allocation_receipts", allocation_id, allocation_record)
			_assert_rejected(_store_over_seeded_root(JSON.stringify(replaced_allocation)).load_or_create(),
				"plan line 1682: allocation map entry %s replacement is forbidden" % allocation_id)

	var day_advance_ids: Array = (document.get("day_advance_allocation_receipts", {}) as Dictionary).keys()
	for day_advance_id: String in day_advance_ids:
		var without_day_advance := document.duplicate(true)
		(without_day_advance.get("day_advance_allocation_receipts", {}) as Dictionary).erase(day_advance_id)
		_assert_rejected(_store_over_seeded_root(JSON.stringify(without_day_advance)).load_or_create(),
			"plan line 1682: day-advance map entry %s cannot be deleted" % day_advance_id)

		var day_advance_record := (
			(document.get("day_advance_allocation_receipts", {}) as Dictionary).get(day_advance_id, {}) as Dictionary
		).duplicate(true)
		var target_reference := (day_advance_record.get("target_causal_day_instance_issuer_receipt", {}) as Dictionary).duplicate(true)
		if not target_reference.is_empty():
			target_reference["token"] = "day-advance.%s.mismatched" % str(day_advance_id)
			day_advance_record["target_causal_day_instance_issuer_receipt"] = target_reference
			var replaced_day_advance := _replace_map_record(document, "day_advance_allocation_receipts", day_advance_id, day_advance_record)
			_assert_rejected(_store_over_seeded_root(JSON.stringify(replaced_day_advance)).load_or_create(),
				"plan line 1682: day-advance map entry %s replacement is forbidden" % day_advance_id)


# ---------------------------------------------------------------------------------------------
# Clause 35 -- allocation receipts must be byte-equal to `receipts` (SHALLOW -> dwm-p2r.16.1)
# ---------------------------------------------------------------------------------------------

func test_allocation_receipt_references_are_valid_and_byte_exact() -> void:
	if _opened_document().is_empty():
		return
	var transaction := _store.issue(&"transaction_id")
	if not _require_ok(transaction, "issue(transaction_id)"):
		return
	var prepared_allocation := _store.prepare_allocation(_new_run_request(_issuer_receipt(transaction)))
	if not _require_ok(prepared_allocation, "prepare_allocation(new_run)"):
		return
	if not _require_ok(_store.commit_allocation(prepared_allocation.get("value", {})),
		"commit_allocation(new_run)"):
		return

	var day_source := _store.issue(&"causal_day_instance")
	if not _require_ok(day_source, "issue(causal_day_instance)"):
		return
	if not _commit_exact_day_advance(_issuer_receipt(day_source)):
		return

	var document := _captured_document()
	if document.is_empty():
		return
	var allocation_key: String = (document.get("allocation_receipts", {}) as Dictionary).keys()[0]
	var day_advance_key: String = (document.get("day_advance_allocation_receipts", {}) as Dictionary).keys()[0]

	var allocation_references: Array[Dictionary] = [
		{
			"member": "run_id_issuer_receipt",
			"label": "run_id",
		},
		{
			"member": "branch_id_issuer_receipt",
			"label": "branch_id",
		},
		{
			"member": "desktop_timeline_generation_issuer_receipt",
			"label": "desktop_timeline_generation",
		},
		{
			"member": "causal_day_instance_issuer_receipt",
			"label": "causal_day_instance",
		},
	]
	for reference: Dictionary in allocation_references:
		var reference_name := str(reference["member"])
		var allocation_entry := (document.get("allocation_receipts", {}) as Dictionary).get(allocation_key, {}) as Dictionary
		if not allocation_entry.has(reference_name):
			continue
		var referenced := (allocation_entry.get(reference_name, {}) as Dictionary).duplicate(true)
		if referenced.is_empty():
			continue
		var missing_reference: Dictionary = referenced.duplicate(true)
		missing_reference["receipt_id"] = "issuer_receipt.absent_%s" % reference_name
		var missing_allocation_reference := _replace_receipt_member(
			document,
			"allocation_receipts",
			allocation_key,
			reference_name,
			missing_reference
		)
		_assert_rejected(_store_over_seeded_root(JSON.stringify(missing_allocation_reference)).load_or_create(),
			"plan line 1682: allocation %s receipt %s must exist in the ledger" % [allocation_key, reference_name])
		for member: String in RECEIPT_KEYS:
			var mismatched_reference: Dictionary = _mutated_receipt_reference(referenced, member)
			var mismatched_allocation_reference := _replace_receipt_member(
				document,
				"allocation_receipts",
				allocation_key,
				reference_name,
				mismatched_reference
			)
			_assert_rejected(_store_over_seeded_root(JSON.stringify(mismatched_allocation_reference)).load_or_create(),
				"plan line 1682: allocation %s receipt %s must match receipts (%s)" % [allocation_key, reference_name, member])

	var day_advance_references: Array[Dictionary] = [
		{
			"member": "source_causal_day_instance_issuer_receipt",
			"label": "source_causal_day_instance",
		},
		{
			"member": "target_causal_day_instance_issuer_receipt",
			"label": "target_causal_day_instance",
		},
	]
	for reference: Dictionary in day_advance_references:
		var reference_name := str(reference["member"])
		var day_entry := (document.get("day_advance_allocation_receipts", {}) as Dictionary).get(day_advance_key, {}) as Dictionary
		if not day_entry.has(reference_name):
			continue
		var referenced := (day_entry.get(reference_name, {}) as Dictionary).duplicate(true)
		if referenced.is_empty():
			continue
		var missing_reference: Dictionary = referenced.duplicate(true)
		missing_reference["receipt_id"] = "issuer_receipt.absent_%s" % reference_name
		var missing_day_reference := _replace_receipt_member(
			document,
			"day_advance_allocation_receipts",
			day_advance_key,
			reference_name,
			missing_reference
		)
		_assert_rejected(_store_over_seeded_root(JSON.stringify(missing_day_reference)).load_or_create(),
			"plan line 1682: day-advance %s %s must exist in the ledger" % [day_advance_key, reference_name])
		for member: String in RECEIPT_KEYS:
			var mismatched_reference: Dictionary = _mutated_receipt_reference(referenced, member)
			var mismatched_day_reference := _replace_receipt_member(
				document,
				"day_advance_allocation_receipts",
				day_advance_key,
				reference_name,
				mismatched_reference
			)
			_assert_rejected(_store_over_seeded_root(JSON.stringify(mismatched_day_reference)).load_or_create(),
				"plan line 1682: day-advance %s %s must match receipts (%s)" % [day_advance_key, reference_name, member])


# ---------------------------------------------------------------------------------------------
# Clauses 30, 34, 35 -- deep root-document rejection and replay obligations (dwm-p2r.16.1)
# ---------------------------------------------------------------------------------------------

func test_each_required_root_member_rejects_missing_wrong_type_and_meaningful_malformed_values() -> void:
	# These literals name the mutations this test catches: missing a required member, accepting a
	# wrong JSON type, or accepting a same-type value that violates the member's durable law.
	var base := {
		"schema_version": 1,
		"namespace": NAMESPACE_A,
		"next_counter": 1,
		"receipts": {},
		"allocation_receipts": {},
		"day_advance_allocation_receipts": {},
	}
	var wrong_types := {
		"schema_version": "1",
		"namespace": 1,
		"next_counter": "one",
		"receipts": [],
		"allocation_receipts": [],
		"day_advance_allocation_receipts": [],
	}
	var malformed_values := {
		"schema_version": 2,
		"namespace": "g".repeat(64),
		"next_counter": 0,
		"receipts": {"unexpected_receipt": {}},
		"allocation_receipts": {"unexpected_allocation": {}},
		"day_advance_allocation_receipts": {"unexpected_day_advance": {}},
	}
	var scenarios: Array[Dictionary] = []
	for member: String in ROOT_DOCUMENT_KEYS:
		var missing := base.duplicate(true)
		missing.erase(member)
		scenarios.append({"label": "missing %s" % member, "document": missing})
		var wrong_type := base.duplicate(true)
		wrong_type[member] = wrong_types[member]
		scenarios.append({"label": "wrong-type %s" % member, "document": wrong_type})
		var malformed := base.duplicate(true)
		malformed[member] = malformed_values[member]
		scenarios.append({"label": "malformed %s" % member, "document": malformed})
	var extra := base.duplicate(true)
	extra["unexpected"] = true
	scenarios.append({"label": "extra root member", "document": extra})

	for scenario: Dictionary in scenarios:
		_assert_seeded_root_rejected_without_write(
			scenario["document"], "root document with %s" % str(scenario["label"]))


func test_each_append_only_root_member_rejects_deletion_and_replacement_but_exact_replay_succeeds() -> void:
	var document := _document_with_all_receipt_members()
	if document.is_empty():
		return
	for map_name: String in ["receipts", "allocation_receipts", "day_advance_allocation_receipts"]:
		var entries: Dictionary = document.get(map_name, {}) as Dictionary
		var keys: Array = entries.keys()
		if keys.is_empty():
			assert_true(false, "%s must contain a committed record for this append-only test" % map_name)
			return
		var key := str(keys[0])
		var deleted := document.duplicate(true)
		(deleted[map_name] as Dictionary).erase(key)
		_assert_seeded_root_rejected_without_write(deleted, "%s deletion at %s" % [map_name, key])

		var replacement := document.duplicate(true)
		var replacement_record: Dictionary = (replacement[map_name] as Dictionary)[key]
		if map_name == "receipts":
			replacement_record["token"] = "forged.%s" % key
		elif map_name == "allocation_receipts":
			replacement_record["root_next_counter"] = int(replacement_record["root_next_counter"]) + 1
		else:
			replacement_record["counter_end"] = int(replacement_record["counter_end"]) + 1
		(replacement[map_name] as Dictionary)[key] = replacement_record
		_assert_seeded_root_rejected_without_write(replacement, "%s replacement at %s" % [map_name, key])

	var allocation_key: String = (document["allocation_receipts"] as Dictionary).keys()[0]
	var allocation: Dictionary = (document["allocation_receipts"] as Dictionary)[allocation_key]
	var before_replay := _captured_document()
	var allocation_replay := _store.commit_allocation(allocation.duplicate(true))
	if not _require_ok(allocation_replay, "byte-identical continuation allocation replay"):
		return
	assert_eq(allocation_replay.get("value"), allocation,
		"the same allocation key and byte-identical candidate replay its recorded bundle")
	assert_eq(_captured_document(), before_replay, "an exact allocation replay writes no new root state")

	var day_key: String = (document["day_advance_allocation_receipts"] as Dictionary).keys()[0]
	var day_advance: Dictionary = (document["day_advance_allocation_receipts"] as Dictionary)[day_key]
	var day_replay := _store.commit_causal_day_advance(day_advance.duplicate(true))
	if not _require_ok(day_replay, "byte-identical day-advance allocation replay"):
		return
	assert_eq(day_replay.get("value"), day_advance,
		"the same day-advance key and byte-identical receipt replay its recorded bundle")
	assert_eq(_captured_document(), before_replay, "an exact day-advance replay writes no new root state")


func test_source_and_target_receipt_members_must_be_present_and_byte_identical_without_writing() -> void:
	var document := _document_with_all_receipt_members()
	if document.is_empty():
		return
	var day_key: String = (document["day_advance_allocation_receipts"] as Dictionary).keys()[0]
	var day_record: Dictionary = (document["day_advance_allocation_receipts"] as Dictionary)[day_key]
	var ledger: Dictionary = document["receipts"]
	for reference_name: String in [
		"source_causal_day_instance_issuer_receipt",
		"target_causal_day_instance_issuer_receipt",
	]:
		var reference: Dictionary = day_record[reference_name]
		var absent := reference.duplicate(true)
		absent["receipt_id"] = "issuer_receipt.absent.%s" % reference_name
		assert_false(ledger.has(str(absent["receipt_id"])), "the absent case is genuinely absent from receipts")
		_assert_seeded_root_rejected_without_write(
			_replace_receipt_member(
				document, "day_advance_allocation_receipts", day_key, reference_name, absent),
			"%s absent from receipts" % reference_name)

		for member: String in RECEIPT_KEYS:
			var mismatch := _present_but_mismatched_receipt(ledger, reference, member)
			assert_true(ledger.has(str(mismatch["receipt_id"])),
				"the %s %s mismatch remains present in receipts" % [reference_name, member])
			assert_ne(ledger[str(mismatch["receipt_id"])], mismatch,
				"the %s %s mismatch is not byte-equal to its ledger receipt" % [reference_name, member])
			_assert_seeded_root_rejected_without_write(
				_replace_receipt_member(
					document, "day_advance_allocation_receipts", day_key, reference_name, mismatch),
				"%s member %s present-but-not-byte-equal" % [reference_name, member])


# ---------------------------------------------------------------------------------------------
# Obligations 8/10 -- real continuation-bundle contract and persisted reconstruction
# ---------------------------------------------------------------------------------------------

func test_real_root_new_run_and_restore_continuation_bundles_are_coherent_across_restart() -> void:
	if _opened_document().is_empty():
		return
	var new_run_transaction := _issue_transaction_receipt()
	if new_run_transaction.is_empty():
		return
	var before_new_run := _captured_document()
	var new_namespace := str(before_new_run.get("namespace", ""))
	var new_counter := int(before_new_run.get("next_counter", -1))
	var new_ledger: Dictionary = before_new_run.get("receipts", {})
	var expected_new_run := _expected_receipt(new_namespace, new_counter, &"run_id", null)
	var expected_new_branch := _expected_receipt(new_namespace, new_counter + 1, &"branch_id", null)
	var expected_new_generation := _expected_receipt(
		new_namespace, new_counter + 2, &"desktop_timeline_generation", 0)
	var expected_new_day := _expected_receipt(
		new_namespace, new_counter + 3, &"causal_day_instance", null)
	var expected_new_receipts: Array[Dictionary] = [
		expected_new_run, expected_new_branch, expected_new_generation, expected_new_day,
	]
	_assert_receipts_are_fresh_against_ledger(expected_new_receipts, new_ledger, "new run")
	var new_run := _store.prepare_allocation(_new_run_request(new_run_transaction))
	if not _require_ok(new_run, "prepare real new-run continuation bundle"):
		return
	var new_candidate: Dictionary = new_run.get("value", {})
	assert_eq(new_candidate.get("kind"), "new_run", "the candidate preserves the requested kind")
	assert_eq(new_candidate.get("request"), _new_run_request(new_run_transaction),
		"new-run candidate preserves the requested transaction bundle")
	assert_eq(new_candidate.get("root_namespace"), new_namespace,
		"new-run candidate is prepared against the captured durable namespace")
	assert_eq(new_candidate.get("root_next_counter"), new_counter,
		"new-run candidate is prepared against the captured durable counter")
	_assert_candidate_token_receipt(new_candidate, "run_id", "run_id_issuer_receipt", expected_new_run, "new run")
	_assert_candidate_token_receipt(new_candidate, "branch_id", "branch_id_issuer_receipt", expected_new_branch, "new branch")
	assert_eq(new_candidate.get("desktop_timeline_generation"), 0, "new run opens generation zero")
	assert_eq(new_candidate.get("desktop_timeline_generation_issuer_receipt"), expected_new_generation,
		"new run binds the independently derived generation receipt")
	_assert_candidate_token_receipt(
		new_candidate, "causal_day_instance", "causal_day_instance_issuer_receipt", expected_new_day, "new causal day")
	assert_eq(new_candidate.get("remap_transaction_issuer_receipts"), {}, "new run mints no remap receipts")
	var actual_new_receipts: Array[Dictionary] = [
		new_candidate.get("run_id_issuer_receipt", {}) as Dictionary,
		new_candidate.get("branch_id_issuer_receipt", {}) as Dictionary,
		new_candidate.get("desktop_timeline_generation_issuer_receipt", {}) as Dictionary,
		new_candidate.get("causal_day_instance_issuer_receipt", {}) as Dictionary,
	]
	assert_eq(actual_new_receipts, expected_new_receipts,
		"new-run candidate contains exactly the four independently derived minted receipts")
	_assert_distinct_receipts(actual_new_receipts, "new-run bundle")
	assert_eq(_captured_document(), before_new_run, "new-run preparation does not mutate the durable root")
	if not _require_ok(_store.commit_allocation(new_candidate), "commit prior new-run continuation bundle"):
		return
	var after_new_run_commit := _captured_document()
	assert_eq(after_new_run_commit.get("next_counter"), new_counter + expected_new_receipts.size(),
		"committing the prior new run consumes its four independently derived counters")
	assert_eq((after_new_run_commit.get("receipts", {}) as Dictionary).get(expected_new_branch["receipt_id"]),
		expected_new_branch, "the prior new-run branch is durably recorded before restore prepares")

	var restore_transaction := _issue_transaction_receipt()
	if restore_transaction.is_empty():
		return
	var restore_request := _restore_request(
		restore_transaction, "run_id.existing", 4, ["transaction.source.a", "transaction.source.b"])
	var before_restore := _captured_document()
	var restore_namespace := str(before_restore.get("namespace", ""))
	var restore_counter := int(before_restore.get("next_counter", -1))
	var restore_ledger: Dictionary = before_restore.get("receipts", {})
	var expected_restore_branch := _expected_receipt(restore_namespace, restore_counter, &"branch_id", null)
	var expected_restore_generation := _expected_receipt(
		restore_namespace, restore_counter + 1, &"desktop_timeline_generation", 5)
	var expected_restore_day := _expected_receipt(
		restore_namespace, restore_counter + 2, &"causal_day_instance", null)
	var expected_first_remap := _expected_receipt(
		restore_namespace, restore_counter + 3, &"transaction_id", null)
	var expected_second_remap := _expected_receipt(
		restore_namespace, restore_counter + 4, &"transaction_id", null)
	var expected_restore_receipts: Array[Dictionary] = [
		expected_restore_branch, expected_restore_generation, expected_restore_day,
		expected_first_remap, expected_second_remap,
	]
	_assert_receipts_are_fresh_against_ledger(expected_restore_receipts, restore_ledger, "restore")
	var prepared_restore := _store.prepare_allocation(restore_request)
	if not _require_ok(prepared_restore, "prepare real restore continuation bundle"):
		return
	var restore_candidate: Dictionary = prepared_restore.get("value", {})
	assert_eq(restore_candidate.get("request"), restore_request,
		"restore candidate preserves the requested transaction bundle")
	assert_eq(restore_candidate.get("root_namespace"), restore_namespace,
		"restore candidate is prepared against the captured durable namespace")
	assert_eq(restore_candidate.get("root_next_counter"), restore_counter,
		"restore candidate is prepared against the captured durable counter")
	assert_eq(restore_candidate.get("run_id"), "run_id.existing", "restore preserves existing_run_id")
	assert_null(restore_candidate.get("run_id_issuer_receipt"), "restore does not mint a second run receipt")
	_assert_candidate_token_receipt(
		restore_candidate, "branch_id", "branch_id_issuer_receipt", expected_restore_branch, "restore branch")
	assert_ne(restore_candidate.get("branch_id"), new_candidate.get("branch_id"),
		"restore branch is fresh rather than the prior new-run branch")
	assert_eq(restore_candidate.get("desktop_timeline_generation"), 5,
		"restore advances source generation by one")
	assert_eq(restore_candidate.get("desktop_timeline_generation_issuer_receipt"), expected_restore_generation,
		"restore binds the independently derived generation receipt")
	_assert_candidate_token_receipt(
		restore_candidate, "causal_day_instance", "causal_day_instance_issuer_receipt", expected_restore_day, "restore causal day")
	var remaps: Dictionary = restore_candidate.get("remap_transaction_issuer_receipts", {})
	assert_eq(remaps.keys(), ["transaction.source.a", "transaction.source.b"],
		"restore mints one remap receipt for each sorted source in request order")
	var first_remap: Dictionary = remaps["transaction.source.a"]
	var second_remap: Dictionary = remaps["transaction.source.b"]
	assert_eq(first_remap, expected_first_remap, "the first remap receipt follows the first request source")
	assert_eq(second_remap, expected_second_remap, "the second remap receipt follows the second request source")
	var actual_restore_receipts: Array[Dictionary] = [
		restore_candidate.get("branch_id_issuer_receipt", {}) as Dictionary,
		restore_candidate.get("desktop_timeline_generation_issuer_receipt", {}) as Dictionary,
		restore_candidate.get("causal_day_instance_issuer_receipt", {}) as Dictionary,
		first_remap,
		second_remap,
	]
	assert_eq(actual_restore_receipts, expected_restore_receipts,
		"restore candidate contains exactly the independently derived receipts in request order")
	_assert_distinct_receipts(actual_restore_receipts, "restore bundle")
	assert_eq(_captured_document(), before_restore, "restore preparation does not mutate the durable root")
	if not _require_ok(_store.commit_allocation(restore_candidate), "commit restore continuation bundle"):
		return
	var before_restart := _captured_document()
	var restarted := _restart_store()
	var reloaded := restarted.load_or_create()
	assert_true(reloaded.get("ok", false),
		"reloading a persisted restore allocation must reconstruct its existing run id: %s" % reloaded)
	if not reloaded.get("ok", false):
		return
	var restarted_capture: Dictionary = restarted.capture()
	var restarted_document: Dictionary = restarted_capture.get("value", {})
	assert_eq(restarted_document, before_restart,
		"a real restart preserves the committed restore candidate byte-for-byte")


func test_real_issuer_new_run_and_restore_candidates_survive_durable_restart() -> void:
	if _opened_document().is_empty():
		return
	var issuer := ISSUER.new()
	if not _require_ok(issuer.configure(_store), "configure real issuer over real root"):
		return

	var profiles: Array[Dictionary] = [
		{"kind": "new_run", "sources": []},
		{"kind": "restore", "sources": ["transaction.source.a", "transaction.source.b"]},
	]
	for profile: Dictionary in profiles:
		var issued: Dictionary = issuer.issue(&"transaction_id")
		if not _require_ok(issued, "issue real %s allocation transaction" % profile["kind"]):
			return
		var transaction_receipt: Dictionary = _issuer_receipt(issued)
		var request: Dictionary
		if profile["kind"] == "new_run":
			request = _new_run_request(transaction_receipt)
		else:
			request = _restore_request(
				transaction_receipt, "run_id.durable-source", 7, profile["sources"])
		var prepared: Dictionary = issuer.prepare_continuation_allocation(request)
		if not _require_ok(prepared, "prepare real issuer %s allocation" % profile["kind"]):
			return
		var candidate: Dictionary = prepared.get("value", {})
		var candidate_keys: Array = candidate.keys()
		candidate_keys.sort()
		assert_eq(candidate_keys, CONTINUATION_CANDIDATE_KEYS,
			"%s prepare returns the one exact persisted candidate shape" % profile["kind"])
		var expected_sources: Array = (profile["sources"] as Array).duplicate()
		expected_sources.sort()
		var remap: Dictionary = candidate.get("transaction_remap", {})
		var remap_keys: Array = remap.keys()
		remap_keys.sort()
		assert_eq(remap_keys, expected_sources,
			"%s candidate carries the deterministic complete transaction_remap" % profile["kind"])
		if not _require_ok(issuer.commit_continuation_allocation(candidate),
				"commit real issuer %s allocation" % profile["kind"]):
			return

		var restarted := _restart_store()
		var reloaded: Dictionary = restarted.load_or_create()
		assert_true(reloaded.get("ok", false),
			"real issuer %s allocation must reload from durable bytes: %s" % [
				profile["kind"], reloaded,
			])
		if not reloaded.get("ok", false):
			return
		var restarted_capture: Dictionary = restarted.capture()
		var restarted_document: Dictionary = restarted_capture.get("value", {})
		assert_eq((restarted_document.get("allocation_receipts", {}) as Dictionary).get(
			str(request["transaction_id"])), candidate,
			"%s restart reconstructs the byte-identical committed candidate" % profile["kind"])


func test_commit_rejects_altered_or_extra_candidate_semantics_before_storage_mutation() -> void:
	if _opened_document().is_empty():
		return
	var issuer := ISSUER.new()
	if not _require_ok(issuer.configure(_store), "configure real issuer for candidate rejection"):
		return
	var mutations: Array[Dictionary] = [
		{"label": "altered branch semantic", "member": "branch_id", "value": "branch_id.forged"},
		{"label": "extra semantic member", "member": "purpose", "value": "continuation"},
	]
	for mutation: Dictionary in mutations:
		var issued: Dictionary = issuer.issue(&"transaction_id")
		if not _require_ok(issued, "issue transaction for %s" % mutation["label"]):
			return
		var request: Dictionary = _new_run_request(_issuer_receipt(issued))
		var prepared: Dictionary = issuer.prepare_continuation_allocation(request)
		if not _require_ok(prepared, "prepare candidate for %s" % mutation["label"]):
			return
		var changed: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
		changed[mutation["member"]] = mutation["value"]
		var bytes_before: Dictionary = _file_ops.snapshot_persisted()
		var root_before: Dictionary = _captured_document()
		_assert_rejected(issuer.commit_continuation_allocation(changed),
			"commit refuses %s" % mutation["label"])
		assert_eq(_file_ops.snapshot_persisted(), bytes_before,
			"%s is rejected before durable storage mutation" % mutation["label"])
		assert_eq(_captured_document(), root_before,
			"%s is rejected before in-memory root mutation" % mutation["label"])


# ---------------------------------------------------------------------------------------------
# Clause 32 -- the two allocation maps are disjoint (DEEP)
# ---------------------------------------------------------------------------------------------

func test_the_two_allocation_maps_are_keyed_disjointly() -> void:
	var document := _opened_document()
	if document.is_empty():
		return
	assert_true(
		document.has("allocation_receipts") and document.has("day_advance_allocation_receipts"),
		"both maps exist independently on the root document")

	# allocation_receipts is keyed by transaction_id; day_advance_allocation_receipts is keyed by the
	# exact allocation key `resolution_kind + ":" + source_resolution_receipt_id` (plan lines 776,
	# 1682). The maps are disjoint, so one key may never occupy both.
	var shared_key := "transaction_id.0000"
	(document.get("allocation_receipts", {}) as Dictionary)[shared_key] = {"kind": "new_run"}
	(document.get("day_advance_allocation_receipts", {}) as Dictionary)[shared_key] = {"schema_version": 1}
	_assert_rejected(_store_over_seeded_root(JSON.stringify(document)).load_or_create(),
		"one key may not occupy both disjoint allocation maps")


# ---------------------------------------------------------------------------------------------
# Clause 14 -- occupied-counter conflict and allocation replay (DEEP)
# ---------------------------------------------------------------------------------------------

func test_committing_a_candidate_prepared_against_a_superseded_counter_conflicts() -> void:
	if _opened_document().is_empty():
		return
	var prepared := _store.prepare_allocation(_new_run_request(_issue_transaction_receipt()))
	if not _require_ok(prepared, "prepare_allocation"):
		return

	# An intervening issuance moves the root past the counter the candidate was prepared against.
	if not _require_ok(_store.issue(&"debug_nonce"), "intervening issue"):
		return
	_assert_rejected(_store.commit_allocation(prepared.get("value", {})),
		"plan line 729: commit repeats root namespace/counter validation, so a superseded candidate fails")


func test_an_identical_allocation_replay_returns_the_recorded_bundle() -> void:
	if _opened_document().is_empty():
		return
	var request := _new_run_request(_issue_transaction_receipt())
	var prepared := _store.prepare_allocation(request)
	if not _require_ok(prepared, "prepare_allocation"):
		return
	var committed := _store.commit_allocation(prepared.get("value", {}))
	if not _require_ok(committed, "commit_allocation"):
		return
	var replayed := _store.prepare_allocation(request.duplicate(true))
	if not _require_ok(replayed, "identical replay of prepare_allocation"):
		return
	assert_eq(replayed.get("value"), committed.get("value"),
		"plan line 535: identical replay of the same allocation transaction returns its recorded bundle")


func test_a_changed_request_at_an_occupied_transaction_identity_conflicts() -> void:
	if _opened_document().is_empty():
		return
	var receipt := _issue_transaction_receipt()
	var request := _new_run_request(receipt)
	var prepared := _store.prepare_allocation(request)
	if not _require_ok(prepared, "prepare_allocation"):
		return
	if not _require_ok(_store.commit_allocation(prepared.get("value", {})), "commit_allocation"):
		return

	# Same transaction identity, different request bytes.
	var changed := _new_run_request(receipt)
	changed["kind"] = "restore"
	changed["existing_run_id"] = "run_id.previous"
	changed["source_desktop_timeline_generation"] = 0
	_assert_rejected(_store.prepare_allocation(changed),
		"plan line 535: a different request at an occupied transaction identity conflicts")


# ---------------------------------------------------------------------------------------------
# Clause 27 -- every crash cut before and after the atomic root commit (DEEP)
# ---------------------------------------------------------------------------------------------

func test_every_crash_cut_around_the_atomic_root_commit_leaves_a_consistent_root() -> void:
	# The exact operation ordinals JsonFileStorage performs are an implementation detail, so this
	# sweeps every cut point rather than hardcoding a count. At EVERY cut the recovered root must be
	# either the pre-write document or the fully committed one -- never a torn intermediate -- and
	# the counter must never move backwards.
	if _opened_document().is_empty():
		return
	var baseline := _captured_document()
	if baseline.is_empty():
		return
	var baseline_counter := int(baseline.get("next_counter", 0))
	var baseline_bytes := _file_ops.snapshot_persisted()

	for cut: int in range(1, 13):
		var cut_ops := FakeFileOps.new(baseline_bytes.duplicate(true))
		var cut_storage := JsonFileStorage.new(ROOT, cut_ops)
		var cut_store := ROOT_STORE.new()
		if not _require_ok(
				cut_store.configure(cut_storage, FAKE_NAMESPACE_SOURCE.new(NAMESPACE_A)),
				"configure at cut %d" % cut):
			return
		if not _require_ok(cut_store.load_or_create(), "load_or_create at cut %d" % cut):
			return
		cut_ops.fail_after(cut_ops.operation_count() + cut)
		cut_store.issue(&"debug_nonce")

		var recovered := _document_from_bytes(cut_ops.snapshot_persisted())
		if recovered.is_empty():
			assert_true(false, "the root must remain recoverable after a crash at cut %d" % cut)
			return
		var recovered_counter := int(recovered.get("next_counter", -1))
		assert_true(
			recovered_counter == baseline_counter or recovered_counter == baseline_counter + 1,
			"cut %d leaves the counter at exactly the old or the new value, never torn" % cut)
		assert_eq((recovered.get("receipts", {}) as Dictionary).size(), recovered_counter - 1,
			"cut %d keeps the receipt count and the counter in agreement" % cut)


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


func _issuer_receipt(issued: Dictionary) -> Dictionary:
	return (issued.get("value", {}) as Dictionary).get("issuer_receipt", {})


func _opened_document() -> Dictionary:
	if not _require_ok(_store.configure(_storage, _namespace_source), "configure"):
		return {}
	if not _require_ok(_store.load_or_create(), "load_or_create"):
		return {}
	return _captured_document()


func _captured_document() -> Dictionary:
	var captured := _store.capture()
	if not _require_ok(captured, "capture"):
		return {}
	return captured.get("value", {})


## Rebuilds the entire stack over the same persisted bytes -- a genuine process restart. The
## restarted store is given a DIFFERENT namespace source so that silently regenerating a namespace
## instead of loading the persisted one is observable as a mismatch rather than passing quietly.
func _reloaded_document() -> Dictionary:
	var restarted_ops := FakeFileOps.new(_file_ops.snapshot_persisted())
	var restarted_storage := JsonFileStorage.new(ROOT, restarted_ops)
	var restarted := ROOT_STORE.new()
	if not _require_ok(
			restarted.configure(restarted_storage, FAKE_NAMESPACE_SOURCE.new(NAMESPACE_B)),
			"configure after restart"):
		return {}
	if not _require_ok(restarted.load_or_create(), "load_or_create after restart"):
		return {}
	var captured := restarted.capture()
	if not _require_ok(captured, "capture after restart"):
		return {}
	return captured.get("value", {})


func _store_over_seeded_root(text: String) -> ROOT_STORE:
	var seeded_ops := FakeFileOps.new({ROOT_FINAL_PATH: text.to_utf8_buffer()})
	var seeded_storage := JsonFileStorage.new(ROOT, seeded_ops)
	var seeded := ROOT_STORE.new()
	seeded.configure(seeded_storage, FAKE_NAMESPACE_SOURCE.new(NAMESPACE_A))
	return seeded


func _assert_seeded_root_rejected_without_write(document: Dictionary, label: String) -> void:
	# Load validation is intentionally observed through the real JsonFileStorage/FakeFileOps stack:
	# a rejected document must not be repaired, rewritten, or otherwise alter durable bytes.
	var encoded := JSON.stringify(document)
	var seeded_ops := FakeFileOps.new({ROOT_FINAL_PATH: encoded.to_utf8_buffer()})
	var seeded_storage := JsonFileStorage.new(ROOT, seeded_ops)
	var seeded := ROOT_STORE.new()
	if not _require_ok(seeded.configure(seeded_storage, FAKE_NAMESPACE_SOURCE.new(NAMESPACE_A)),
		"configure seeded root for %s" % label):
		return
	var before := seeded_ops.snapshot_persisted()
	_assert_rejected(seeded.load_or_create(), label)
	assert_eq(seeded_ops.snapshot_persisted(), before,
		"%s must leave the rejected durable root bytes unchanged" % label)


func _document_with_all_receipt_members() -> Dictionary:
	if _opened_document().is_empty():
		return {}
	var transaction := _issue_transaction_receipt()
	if transaction.is_empty():
		return {}
	var prepared := _store.prepare_allocation(_new_run_request(transaction))
	if not _require_ok(prepared, "prepare allocation fixture"):
		return {}
	if not _require_ok(_store.commit_allocation(prepared.get("value", {})), "commit allocation fixture"):
		return {}
	var source := _store.issue(&"causal_day_instance")
	if not _require_ok(source, "issue causal-day fixture source"):
		return {}
	if not _commit_exact_day_advance(_issuer_receipt(source)):
		return {}
	return _captured_document()


func _present_but_mismatched_receipt(ledger: Dictionary, reference: Dictionary,
		member: String) -> Dictionary:
	var mismatch := _mutated_receipt_reference(reference, member)
	if member == "receipt_id":
		for candidate_id in ledger.keys():
			if str(candidate_id) != str(reference["receipt_id"]):
				mismatch["receipt_id"] = str(candidate_id)
				break
	return mismatch


func _restart_store() -> ROOT_STORE:
	var restarted_ops := FakeFileOps.new(_file_ops.snapshot_persisted())
	var restarted_storage := JsonFileStorage.new(ROOT, restarted_ops)
	var restarted := ROOT_STORE.new()
	if not _require_ok(
			restarted.configure(restarted_storage, FAKE_NAMESPACE_SOURCE.new(NAMESPACE_B)),
			"configure restart store"):
		return restarted
	return restarted


func _document_from_bytes(persisted: Dictionary) -> Dictionary:
	if not persisted.has(ROOT_FINAL_PATH):
		return {}
	var bytes: PackedByteArray = persisted[ROOT_FINAL_PATH]
	var parsed := StrictJson.parse_object(bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		return {}
	return parsed.get("value", {})


func _replace_receipt_member(document: Dictionary, map_name: String, map_id: String,
		member_name: String, replacement: Variant) -> Dictionary:
	var seeded := document.duplicate(true)
	var container: Dictionary = (seeded.get(map_name, {}) as Dictionary).duplicate(true)
	if not container.has(map_id):
		return seeded
	var record: Dictionary = (container.get(map_id, {}) as Dictionary).duplicate(true)
	record[member_name] = replacement
	container[map_id] = record
	seeded[map_name] = container
	return seeded


func _replace_map_record(document: Dictionary, map_name: String, map_id: String, replacement: Dictionary) -> Dictionary:
	var seeded := document.duplicate(true)
	var container: Dictionary = (seeded.get(map_name, {}) as Dictionary).duplicate(true)
	if not container.has(map_id):
		return seeded
	container[map_id] = replacement
	seeded[map_name] = container
	return seeded


func _mutated_receipt_reference(reference: Dictionary, member: String) -> Dictionary:
	var mutated := reference.duplicate(true)
	match member:
		"counter":
			mutated["counter"] = int(reference.get("counter", 0)) + 1
		"namespace":
			mutated["namespace"] = "mutated.%s" % str(reference.get("namespace", ""))
		"numeric_value":
			if typeof(reference.get("numeric_value", null)) == TYPE_INT:
				mutated["numeric_value"] = int(reference.get("numeric_value")) + 1
			else:
				mutated["numeric_value"] = 1
		"purpose":
			mutated["purpose"] = "mismatched.%s" % str(reference.get("purpose", ""))
		"receipt_id":
			mutated["receipt_id"] = "issuer_receipt.absent_%s" % str(reference.get("receipt_id", ""))
		"token":
			mutated["token"] = "mismatched.%s" % str(reference.get("token", ""))
	return mutated


func _issue_transaction_receipt() -> Dictionary:
	var issued := _store.issue(&"transaction_id")
	if not issued.get("ok", false):
		# The skeleton path: return an empty receipt so the caller still exercises the real request
		# shape and fails on the allocation assertion rather than on a missing fixture.
		return {}
	return _issuer_receipt(issued)


func _commit_exact_day_advance(source_receipt: Dictionary, scene: bool = false) -> bool:
	var issuer := ISSUER.new()
	if not _require_ok(issuer.configure(_store), "configure issuer for exact day advance"):
		return false
	var parent := _store.issue(&"transaction_id")
	if not _require_ok(parent, "issue day-resolution parent"):
		return false
	var parent_receipt := _issuer_receipt(parent)
	var derived: Dictionary = issuer.derive_child({
		"parent_receipt_id": str(parent_receipt.get("receipt_id", "")),
		"child_kind": &"scene_day_completion" if scene else &"day_resolution_stage",
		"ordinal": 0,
		"source_ids": [],
	})
	if not _require_ok(derived, "derive day-resolution receipt"):
		return false
	var derived_value: Dictionary = derived.get("value", {})
	var port := DAY_ADVANCE_PORT.new()
	if not _require_ok(port.configure(issuer), "configure day-advance port"):
		return false
	var request := {
		"resolution_kind": "scene_day_complete" if scene else "schedule_done",
		"source_resolution_receipt": {
			"receipt_id": str(derived_value.get("child_id", "")),
			"provenance": (derived_value.get("provenance", {}) as Dictionary).duplicate(true),
		},
		"run_id": "root-store-test-run",
		"branch_id": "root-store-test-branch",
		"desktop_timeline_generation": 0,
		"source_day": 1,
		"source_causal_day_instance": str(source_receipt.get("token", "")),
		"source_causal_day_instance_issuer_receipt": source_receipt.duplicate(true),
	}
	if scene:
		request.erase("source_day")
	var prepared: Dictionary = port.prepare_advance(request)
	if not _require_ok(prepared, "prepare exact day advance"):
		return false
	var candidate: Dictionary = (prepared.get("value", {}) as Dictionary).get(
		"day_advance_identity_candidate", {}
	)
	return _require_ok(port.commit_advance(candidate), "commit exact day advance")


## The frozen New-Run continuation request, plan line 729: New Run requires both nullable source
## fields null and an empty remap array. The map key equals the receipt's own token.
func _new_run_request(transaction_receipt: Dictionary) -> Dictionary:
	return {
		"transaction_id": str(transaction_receipt.get("token", "")),
		"transaction_issuer_receipt": transaction_receipt,
		"kind": "new_run",
		"existing_run_id": null,
		"source_desktop_timeline_generation": null,
		"remap_source_transaction_ids": [],
	}


func _restore_request(transaction_receipt: Dictionary, existing_run_id: String,
		source_generation: int, remap_sources: Array) -> Dictionary:
	return {
		"transaction_id": str(transaction_receipt.get("token", "")),
		"transaction_issuer_receipt": transaction_receipt.duplicate(true),
		"kind": "restore",
		"existing_run_id": existing_run_id,
		"source_desktop_timeline_generation": source_generation,
		"remap_source_transaction_ids": remap_sources.duplicate(true),
	}


## Derives receipt literals from a captured durable root identity, using the established frozen
## token/receipt preimages rather than either continuation-candidate implementation.
func _expected_receipt(namespace_value: String, counter: int, purpose: StringName,
		numeric_value: Variant) -> Dictionary:
	var token := FAKE_ROOT_STORE.token_for(namespace_value, counter, purpose)
	return {
		"receipt_id": FAKE_ROOT_STORE.receipt_id_for(namespace_value, counter, purpose, token),
		"purpose": String(purpose),
		"namespace": namespace_value,
		"counter": counter,
		"token": token,
		"numeric_value": numeric_value,
	}


func _assert_candidate_token_receipt(candidate: Dictionary, identity_member: String,
		receipt_member: String, expected: Dictionary, label: String) -> void:
	assert_eq(candidate.get(receipt_member), expected,
		"%s receipt has the independently derived purpose, counter, token, and receipt id" % label)
	assert_eq(candidate.get(identity_member), expected.get("token"),
		"%s identity binds exactly to the independently derived receipt token" % label)


func _assert_receipts_are_fresh_against_ledger(receipts: Array[Dictionary], ledger: Dictionary,
		label: String) -> void:
	for receipt: Dictionary in receipts:
		assert_false(ledger.has(str(receipt["receipt_id"])),
			"%s receipt counter %d is not already consumed in the captured durable ledger" % [
				label, int(receipt["counter"]),
			])


func _assert_distinct_receipts(receipts: Array[Dictionary], label: String) -> void:
	var receipt_ids := {}
	var tokens := {}
	var counters := {}
	for receipt: Dictionary in receipts:
		receipt_ids[str(receipt["receipt_id"])] = true
		tokens[str(receipt["token"])] = true
		counters[int(receipt["counter"])] = true
	assert_eq(receipt_ids.size(), receipts.size(), "%s receipt IDs are unique" % label)
	assert_eq(tokens.size(), receipts.size(), "%s tokens are unique" % label)
	assert_eq(counters.size(), receipts.size(), "%s counters are unique" % label)

func test_cold_strict_parse_proves_atomic_write_bytes_without_authorizing_schema() -> void:
	var store := ROOT_STORE.new()
	var text := '{"schema_version":999}'
	assert_true(store._parse_document(text).ok)
	assert_true(store._parse_known_write_document(text).value.is_empty(), "atomic syntax proof reuses cold parsed bytes")
	assert_false(store._validate_document(store._parse_document(text).value).ok, "root ledger laws still reject the foreign schema")
	assert_false(store._parse_document('{"duplicate":1,"duplicate":2}').ok)
	assert_false(store._validated_write_texts.has('{"duplicate":1,"duplicate":2}'))

func test_atomic_write_proof_keeps_only_three_recently_used_texts() -> void:
	var store := ROOT_STORE.new()
	for text: String in ['{"a":1}', '{"b":2}', '{"c":3}']:
		assert_true(store._parse_document(text).ok)
	store._parse_known_write_document('{"a":1}')
	store._parse_document('{"d":4}')
	assert_eq(store._validated_write_texts.size(), 3)
	assert_has(store._validated_write_texts, '{"a":1}')
	assert_does_not_have(store._validated_write_texts, '{"b":2}')


# ---------------------------------------------------------------------------------------------
# Deferred issuance (dwm-634.1). Routine board commands mint in memory; the ledger is written
# when the board itself is saved, so a click never pays for a root write.
# ---------------------------------------------------------------------------------------------

func test_issue_deferred_mints_in_memory_and_flush_persists_every_pending_receipt() -> void:
	if _opened_document().is_empty():
		return
	var durable_before := _document_from_bytes(_file_ops.snapshot_persisted())
	var first: Dictionary = _store.issue_deferred(&"transaction_id")
	var second: Dictionary = _store.issue_deferred(&"transaction_id")
	if not _require_ok(first, "issue_deferred #1") or not _require_ok(second, "issue_deferred #2"):
		return
	assert_eq(_issuer_receipt(first).get("counter"), 1)
	assert_eq(_issuer_receipt(second).get("counter"), 2)
	assert_eq(first.get("receipt"), _issuer_receipt(first), "the outer receipt is byte-equal to the issuer_receipt")
	assert_eq(_captured_document().get("next_counter"), 3, "the live document advances in memory")
	assert_true(_store.verify_receipt(_issuer_receipt(second), &"transaction_id").get("ok", false),
		"a deferred receipt verifies before it is durable")
	assert_eq(_document_from_bytes(_file_ops.snapshot_persisted()), durable_before,
		"issue_deferred writes nothing to storage")
	var flushed: Dictionary = _store.flush()
	if not _require_ok(flushed, "flush"):
		return
	assert_true(bool(flushed.get("value", {}).get("written", false)), "a pending ledger is written")
	var durable := _document_from_bytes(_file_ops.snapshot_persisted())
	assert_eq(durable.get("next_counter"), 3)
	assert_eq((durable.get("receipts", {}) as Dictionary).size(), 2)
	assert_eq(_reloaded_document(), _captured_document(), "the flushed root reloads byte for byte")
	var idle: Dictionary = _store.flush()
	if not _require_ok(idle, "idle flush"):
		return
	assert_false(bool(idle.get("value", {}).get("written", true)), "nothing pending means nothing written")


func test_a_durable_issue_persists_earlier_deferred_receipts_in_the_same_write() -> void:
	if _opened_document().is_empty():
		return
	if not _require_ok(_store.issue_deferred(&"transaction_id"), "issue_deferred"):
		return
	var writes_before := _root_candidate_writes()
	if not _require_ok(_store.issue(&"debug_nonce"), "issue"):
		return
	assert_eq(_root_candidate_writes(), writes_before + 1, "one durable write carries both receipts")
	var durable := _document_from_bytes(_file_ops.snapshot_persisted())
	assert_eq(durable.get("next_counter"), 3)
	assert_eq((durable.get("receipts", {}) as Dictionary).size(), 2)
	var idle: Dictionary = _store.flush()
	if not _require_ok(idle, "flush after durable issue"):
		return
	assert_false(bool(idle.get("value", {}).get("written", true)), "the durable issue already flushed")


func test_unflushed_deferred_receipts_do_not_survive_a_restart_and_burn_no_durable_counter() -> void:
	if _opened_document().is_empty():
		return
	if not _require_ok(_store.issue(&"debug_nonce"), "issue"):
		return
	if not _require_ok(_store.issue_deferred(&"transaction_id"), "issue_deferred"):
		return
	var reloaded := _reloaded_document()
	if reloaded.is_empty():
		return
	assert_eq(reloaded.get("next_counter"), 2, "a restart resumes at the last durable counter")
	assert_eq((reloaded.get("receipts", {}) as Dictionary).size(), 1)


func test_issue_deferred_refuses_unknown_purposes_and_an_unloaded_root() -> void:
	_assert_rejected(_store.issue_deferred(&"transaction_id"), "issue_deferred before load")
	if _opened_document().is_empty():
		return
	_assert_rejected(_store.issue_deferred(&"not_a_purpose"), "issue_deferred(not_a_purpose)")
	assert_eq(_captured_document().get("next_counter"), 1, "a refusal mints nothing")
	var idle: Dictionary = _store.flush()
	if not _require_ok(idle, "flush with nothing pending"):
		return
	assert_false(bool(idle.get("value", {}).get("written", true)))


func _root_candidate_writes() -> int:
	var count := 0
	for entry: Dictionary in _file_ops.operation_trace():
		if entry.get("operation") == &"write_bytes" and str(entry.get("path")) == ROOT_FINAL_PATH + ".next":
			count += 1
	return count


# ---------------------------------------------------------------------------------------------
# In-place deferred minting (dwm-634.3). issue_deferred mints straight into the live document
# instead of copying the whole issuer root first, because the deferred path never writes and so
# can never need to abandon a copy. The rows below pin what that copy used to guarantee: identical
# durable bytes, refusals that mutate nothing, and returned values that stay detached.
# ---------------------------------------------------------------------------------------------

# Six allowed purposes, in issue order. The ROOT accepts every PURPOSE_UNION member (the two
# allocator purposes are refused by the ISSUER, not here), so any six would do.
const DEFERRED_EQUIVALENCE_PURPOSES: Array[StringName] = [
	&"transaction_id",
	&"debug_nonce",
	&"board_id",
	&"placement_nonce",
	&"explosion_nonce",
	&"receipt_id",
]


## The deferred mint must not route through the helper that duplicates the entire root document.
## A source pin rather than a timing assertion: the cost is one deep copy per call, and nothing in
## the returned envelope or the durable bytes can distinguish a copy from an in-place mint.
func test_issue_deferred_mints_without_copying_the_whole_issuer_root() -> void:
	var body := _issue_deferred_source_body()
	assert_false(body.is_empty(), "the issue_deferred body must be readable from source")
	assert_false(body.contains("_minted_document("),
		"issue_deferred must not mint through _minted_document, which copies the whole root")
	assert_false(body.contains("_document.duplicate(true)"),
		"issue_deferred must not deep-copy the live document")


## GREEN BEFORE AND AFTER BY DESIGN. This row does not witness the in-place mint; it pins the
## equivalence the in-place mint must preserve, so it is the row that fails if the optimisation
## ever changes what reaches storage.
func test_six_deferred_mints_flush_the_bytes_six_durable_issues_write() -> void:
	if _opened_document().is_empty():
		return
	var twin := _opened_twin_stack()
	if twin.is_empty():
		return
	var twin_store: ROOT_STORE = twin["store"]
	var twin_ops: FakeFileOps = twin["ops"]
	var durable: Array[Dictionary] = []
	var deferred: Array[Dictionary] = []
	for purpose: StringName in DEFERRED_EQUIVALENCE_PURPOSES:
		var issued: Dictionary = twin_store.issue(purpose)
		var minted: Dictionary = _store.issue_deferred(purpose)
		if not _require_ok(issued, "issue(%s)" % purpose):
			return
		if not _require_ok(minted, "issue_deferred(%s)" % purpose):
			return
		durable.append(_issuer_receipt(issued))
		deferred.append(_issuer_receipt(minted))
	if not _require_ok(_store.flush(), "flush after six deferred mints"):
		return
	for index: int in range(durable.size()):
		assert_eq(deferred[index].get("token"), durable[index].get("token"),
			"deferred token #%d matches the durable token" % index)
		assert_eq(deferred[index].get("receipt_id"), durable[index].get("receipt_id"),
			"deferred receipt_id #%d matches the durable receipt_id" % index)
	assert_eq(_persisted_root_bytes(_file_ops), _persisted_root_bytes(twin_ops),
		"six deferred mints flush exactly the bytes six durable issues write")


## Both refusals are decided before the first mutation, so a refused mint is invisible to the live
## counter, to the pending receipts, and to the bytes the next flush writes.
func test_a_refused_deferred_mint_leaves_the_live_root_and_its_flushed_bytes_untouched() -> void:
	if _opened_document().is_empty():
		return
	var twin := _opened_twin_stack()
	if twin.is_empty():
		return
	var twin_store: ROOT_STORE = twin["store"]
	var twin_ops: FakeFileOps = twin["ops"]
	if not _require_ok(_store.issue_deferred(&"transaction_id"), "issue_deferred"):
		return
	if not _require_ok(twin_store.issue_deferred(&"transaction_id"), "twin issue_deferred"):
		return
	var before := _captured_document()
	_assert_rejected(_store.issue_deferred(&"not_a_purpose"), "issue_deferred(not_a_purpose)")
	var after := _captured_document()
	assert_eq(after.get("next_counter"), before.get("next_counter"),
		"a refused deferred mint advances no counter")
	assert_eq((after.get("receipts", {}) as Dictionary).size(),
		(before.get("receipts", {}) as Dictionary).size(),
		"a refused deferred mint records no receipt")
	if not _require_ok(_store.flush(), "flush after the refusal"):
		return
	if not _require_ok(twin_store.flush(), "twin flush"):
		return
	assert_eq(_persisted_root_bytes(_file_ops), _persisted_root_bytes(twin_ops),
		"the refusal leaves the flushed bytes identical to a twin that never attempted it")
	var idle: Dictionary = _store.flush()
	if not _require_ok(idle, "idle flush"):
		return
	assert_false(bool(idle.get("value", {}).get("written", true)), "the flush left nothing pending")


## Minting in place must not hand the caller a live alias: neither the returned receipt nor the
## captured document may reach the bytes a later flush writes.
func test_mutating_a_deferred_receipt_or_a_capture_cannot_reach_the_flushed_bytes() -> void:
	if _opened_document().is_empty():
		return
	var twin := _opened_twin_stack()
	if twin.is_empty():
		return
	var twin_store: ROOT_STORE = twin["store"]
	var twin_ops: FakeFileOps = twin["ops"]
	var minted: Dictionary = _store.issue_deferred(&"transaction_id")
	if not _require_ok(minted, "issue_deferred"):
		return
	if not _require_ok(twin_store.issue_deferred(&"transaction_id"), "twin issue_deferred"):
		return
	var issuer_receipt := _issuer_receipt(minted)
	issuer_receipt["counter"] = 999
	issuer_receipt["token"] = "tampered"
	var outer_receipt: Dictionary = minted.get("receipt", {})
	outer_receipt["purpose"] = "tampered"
	var captured := _captured_document()
	captured["next_counter"] = 999
	var captured_receipts: Dictionary = captured.get("receipts", {})
	captured_receipts.clear()
	assert_eq(_captured_document().get("next_counter"), 2,
		"the live counter ignores a mutated capture")
	if not _require_ok(_store.flush(), "flush after the mutations"):
		return
	if not _require_ok(twin_store.flush(), "twin flush"):
		return
	assert_eq(_persisted_root_bytes(_file_ops), _persisted_root_bytes(twin_ops),
		"mutating a returned receipt or capture cannot reach the flushed bytes")


## The in-place mint composes with a canonical cache that a durable write has already seeded.
func test_one_durable_issue_then_two_deferred_mints_flush_three_durable_bytes() -> void:
	var pair := _durable_then_deferred_byte_pair(false)
	if pair.is_empty():
		return
	var flushed: PackedByteArray = pair["flushed"]
	var twin_written: PackedByteArray = pair["twin_written"]
	assert_eq(flushed, twin_written,
		"one durable issue then two deferred mints flush what three durable issues write")


## The same composition with an EMPTY incremental cache, where _write_pending_document falls back
## to a whole-document canonical write. A successful load always leaves that cache populated, so
## the fallback is reached here the only way production reaches it: by clearing the cache the way
## a refused canonical stringify does.
func test_deferred_mints_flush_durable_bytes_with_an_empty_canonical_cache() -> void:
	var pair := _durable_then_deferred_byte_pair(true)
	if pair.is_empty():
		return
	var flushed: PackedByteArray = pair["flushed"]
	var twin_written: PackedByteArray = pair["twin_written"]
	assert_eq(flushed, twin_written,
		"the whole-document fallback flushes what three durable issues write")


# ---------------------------------------------------------------------------------------------
# In-place deferred minting helpers
# ---------------------------------------------------------------------------------------------

## One durable issue then two deferred mints on this store, three durable issues on the twin.
## Returns {flushed, twin_written} bytes, or {} when a guard already reported the failure.
func _durable_then_deferred_byte_pair(clear_canonical_cache: bool) -> Dictionary:
	if _opened_document().is_empty():
		return {}
	var twin := _opened_twin_stack()
	if twin.is_empty():
		return {}
	var twin_store: ROOT_STORE = twin["store"]
	var twin_ops: FakeFileOps = twin["ops"]
	var purposes: Array[StringName] = [&"transaction_id", &"debug_nonce", &"board_id"]
	for purpose: StringName in purposes:
		if not _require_ok(twin_store.issue(purpose), "twin issue(%s)" % purpose):
			return {}
	if not _require_ok(_store.issue(purposes[0]), "issue(%s)" % purposes[0]):
		return {}
	if clear_canonical_cache:
		_store._canonical_field_values = {}
		_store._canonical_receipt_entries = {}
	if not _require_ok(_store.issue_deferred(purposes[1]), "issue_deferred(%s)" % purposes[1]):
		return {}
	if not _require_ok(_store.issue_deferred(purposes[2]), "issue_deferred(%s)" % purposes[2]):
		return {}
	if not _require_ok(_store.flush(), "flush after the mixed sequence"):
		return {}
	return {
		"flushed": _persisted_root_bytes(_file_ops),
		"twin_written": _persisted_root_bytes(twin_ops),
	}


## The exact source text of issue_deferred, from its own declaration to the next top-level one.
func _issue_deferred_source_body() -> String:
	var source := FileAccess.get_file_as_string(str(SKELETON_PATHS["DesktopIssuerRootStore"]))
	var opened := source.find("func issue_deferred(")
	if opened < 0:
		return ""
	var closed := source.find("\nfunc ", opened)
	if closed < 0:
		return ""
	return source.substr(opened, closed - opened)


## A second complete stack over its own in-memory filesystem, opened at the same namespace. Two
## FakeFileOps are two independent durable roots, so the twin's bytes witness the other path.
func _opened_twin_stack() -> Dictionary:
	var ops := FakeFileOps.new()
	var store := ROOT_STORE.new()
	if not _require_ok(
			store.configure(JsonFileStorage.new(ROOT, ops), FAKE_NAMESPACE_SOURCE.new(NAMESPACE_A)),
			"configure twin"):
		return {}
	if not _require_ok(store.load_or_create(), "load_or_create twin"):
		return {}
	return {"ops": ops, "store": store}


func _persisted_root_bytes(ops: FakeFileOps) -> PackedByteArray:
	var persisted := ops.snapshot_persisted()
	if not persisted.has(ROOT_FINAL_PATH):
		return PackedByteArray()
	var bytes: PackedByteArray = persisted[ROOT_FINAL_PATH]
	return bytes


func test_scene_receipt_version_and_calendar_members_fail_closed_on_reload() -> void:
	if _opened_document().is_empty():
		return
	var source := _store.issue(&"causal_day_instance")
	if not _require_ok(source, "scene source"):
		return
	if not _commit_exact_day_advance(_issuer_receipt(source), true):
		return
	var document := _captured_document()
	var key: String = str((document["day_advance_allocation_receipts"] as Dictionary).keys()[0])
	for field in ["schema_version", "source_day", "target_day"]:
		var changed := document.duplicate(true)
		changed["day_advance_allocation_receipts"][key][field] = 1
		_assert_seeded_root_rejected_without_write(changed, "scene receipt rejects " + field)
