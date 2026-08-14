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


# ---------------------------------------------------------------------------------------------
# Clause 16 -- no API lowers the counter
# ---------------------------------------------------------------------------------------------

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
	var new_run := _store.prepare_allocation(_new_run_request(new_run_transaction))
	if not _require_ok(new_run, "prepare real new-run continuation bundle"):
		return
	var new_candidate: Dictionary = new_run.get("value", {})
	assert_eq(new_candidate.get("kind"), "new_run", "the candidate preserves the requested kind")
	assert_true(str(new_candidate.get("run_id", "")).begins_with("run_id."),
		"new run mints a fresh run identity")
	assert_true(str(new_candidate.get("branch_id", "")).begins_with("branch_id."),
		"new run mints a fresh branch identity")
	assert_ne(new_candidate.get("run_id"), new_candidate.get("branch_id"), "run and branch identities differ")
	assert_eq(new_candidate.get("desktop_timeline_generation"), 0, "new run opens generation zero")
	assert_true(str(new_candidate.get("causal_day_instance", "")).begins_with("causal_day_instance."),
		"new run receives a causal-day identity")
	assert_eq(new_candidate.get("remap_transaction_issuer_receipts"), {}, "new run mints no remap receipts")
	assert_eq((new_candidate.get("run_id_issuer_receipt", {}) as Dictionary).get("token"), new_candidate.get("run_id"),
		"the new-run candidate binds its run receipt coherently")
	assert_eq((new_candidate.get("branch_id_issuer_receipt", {}) as Dictionary).get("token"), new_candidate.get("branch_id"),
		"the new-run candidate binds its branch receipt coherently")

	var restore_transaction := _issue_transaction_receipt()
	if restore_transaction.is_empty():
		return
	var restore_request := _restore_request(
		restore_transaction, "run_id.existing", 4, ["transaction.source.a", "transaction.source.b"])
	var prepared_restore := _store.prepare_allocation(restore_request)
	if not _require_ok(prepared_restore, "prepare real restore continuation bundle"):
		return
	var restore_candidate: Dictionary = prepared_restore.get("value", {})
	assert_eq(restore_candidate.get("run_id"), "run_id.existing", "restore preserves existing_run_id")
	assert_null(restore_candidate.get("run_id_issuer_receipt"), "restore does not mint a second run receipt")
	assert_true(str(restore_candidate.get("branch_id", "")).begins_with("branch_id."),
		"restore mints a fresh branch")
	assert_eq(restore_candidate.get("desktop_timeline_generation"), 5,
		"restore advances source generation by one")
	assert_eq((restore_candidate.get("desktop_timeline_generation_issuer_receipt", {}) as Dictionary).get("numeric_value"), 5,
		"the generation receipt agrees with the restored generation")
	var remaps: Dictionary = restore_candidate.get("remap_transaction_issuer_receipts", {})
	assert_eq(remaps.keys(), ["transaction.source.a", "transaction.source.b"],
		"restore mints one remap receipt for each sorted source in request order")
	var first_remap: Dictionary = remaps["transaction.source.a"]
	var second_remap: Dictionary = remaps["transaction.source.b"]
	assert_eq(first_remap.get("purpose"), "transaction_id", "each remap receipt has transaction purpose")
	assert_eq(second_remap.get("purpose"), "transaction_id", "each remap receipt has transaction purpose")
	assert_eq(int(second_remap.get("counter")), int(first_remap.get("counter")) + 1,
		"remap transaction receipts are minted in sorted request order")
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


func _commit_exact_day_advance(source_receipt: Dictionary) -> bool:
	var issuer := ISSUER.new()
	if not _require_ok(issuer.configure(_store), "configure issuer for exact day advance"):
		return false
	var parent := _store.issue(&"transaction_id")
	if not _require_ok(parent, "issue day-resolution parent"):
		return false
	var parent_receipt := _issuer_receipt(parent)
	var derived: Dictionary = issuer.derive_child({
		"parent_receipt_id": str(parent_receipt.get("receipt_id", "")),
		"child_kind": &"day_resolution_stage",
		"ordinal": 0,
		"source_ids": [],
	})
	if not _require_ok(derived, "derive day-resolution receipt"):
		return false
	var derived_value: Dictionary = derived.get("value", {})
	var port := DAY_ADVANCE_PORT.new()
	if not _require_ok(port.configure(issuer), "configure day-advance port"):
		return false
	var prepared: Dictionary = port.prepare_advance({
		"resolution_kind": "schedule_done",
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
	})
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
