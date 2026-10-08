extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

# Crash-cut recovery for the shared logical-day identity (Plan 01 Task 7 Step 7.3a, dwm-p2r.14).
#
# WHAT THIS FILE OWNS, as distinct from tests/unit/test_causal_day_advance_identity_port.gd. The
# unit suite proves the port's SHAPE and rejections over in-memory file ops. This file proves
# DURABILITY: it runs over a real on-disk root, then destroys and recreates every process owner
# (root store, issuer, port) from those same bytes -- which is what a crash actually is.
#
# ROOT ALLOCATION IS IRREVERSIBLE. A crash before the root commit leaves no allocation. A crash
# after it re-prepares the SAME key and must receive the SAME bytes rather than minting a second
# identity. Retry can only ever move forward.
#
# THERE IS NO DAY 8. source_day is bounded 1..6, so six successive advances yield Days 2..7 and a
# seventh is structurally impossible rather than merely unused.

const PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")

var _root := ""
var _root_counter := 0


func before_each() -> void:
	_root = ""
	_root_counter += 1
	var result: Dictionary = TEMPORARY_STORAGE.create("causal-day-recovery-%d" % _root_counter)
	assert_true(result.get("ok", false), result.get("message", ""))
	if not result.get("ok", false):
		return
	_root = str(result["value"])


## One complete set of process owners over the SHARED on-disk root. Calling this again after
## discarding the previous set is exactly a process restart.
func _owners() -> Dictionary:
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(
		JsonFileStorage.new(_root), NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))
	var port: RefCounted = PORT.new()
	assert_true(port.configure(issuer).get("ok", false))
	return {"root_store": root_store, "issuer": issuer, "port": port}


# ---- the crash cuts ----

func test_a_crash_before_the_root_commit_leaves_no_allocation() -> void:
	if _root.is_empty():
		return
	var owners := _owners()
	var request := _advance_request(owners, 3)
	var prepared: Dictionary = owners["port"].prepare_advance(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	# THE CRASH: prepared but never committed. Every owner is discarded.
	owners = {}

	# A fresh process re-prepares the same request. Because nothing was committed, this is a first
	# allocation, not a replay -- and it must succeed rather than reporting a phantom prior one.
	var restarted := _owners()
	var again: Dictionary = restarted["port"].prepare_advance(request)
	assert_true(again.get("ok", false),
		"an uncommitted prepare leaves nothing behind: " + JSON.stringify(again))


func test_a_crash_after_the_root_commit_replays_the_same_bytes() -> void:
	if _root.is_empty():
		return
	var owners := _owners()
	var request := _advance_request(owners, 3)
	var prepared: Dictionary = owners["port"].prepare_advance(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	var receipt: Dictionary = (prepared["value"] as Dictionary)["day_advance_identity_receipt"]
	var committed: Dictionary = owners["port"].commit_advance(
		{"day_advance_identity_receipt": receipt.duplicate(true)})
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	if not committed.get("ok", false):
		return
	var target_token := str(receipt["target_causal_day_instance"])
	var counter_end: int = int(receipt["counter_end"])

	# THE CRASH: the root allocation is durable, but the stage checkpoint never happened.
	owners = {}
	var restarted := _owners()
	var replayed: Dictionary = restarted["port"].prepare_advance(request)
	assert_true(replayed.get("ok", false), JSON.stringify(replayed))
	if not replayed.get("ok", false):
		return
	var replayed_receipt: Dictionary = (replayed["value"] as Dictionary)["day_advance_identity_receipt"]

	assert_eq(str(replayed_receipt["target_causal_day_instance"]), target_token,
		"the SAME target token comes back; retry never mints a second identity")
	assert_eq(int(replayed_receipt["counter_end"]), counter_end,
		"the counter advanced exactly once across the crash")
	assert_eq(replayed_receipt, receipt,
		"recovery replays byte-identical bytes, not a newly derived equivalent")


func test_recovery_is_idempotent_across_repeated_restarts() -> void:
	if _root.is_empty():
		return
	var owners := _owners()
	var request := _advance_request(owners, 2)
	var first: Dictionary = owners["port"].prepare_advance(request)
	assert_true(first.get("ok", false), JSON.stringify(first))
	if not first.get("ok", false):
		return
	var receipt: Dictionary = (first["value"] as Dictionary)["day_advance_identity_receipt"]
	assert_true(owners["port"].commit_advance(
		{"day_advance_identity_receipt": receipt.duplicate(true)}).get("ok", false))

	# Three successive restarts must all land on the same allocation.
	for restart: int in range(3):
		owners = {}
		var restarted := _owners()
		var replayed: Dictionary = restarted["port"].prepare_advance(request)
		assert_true(replayed.get("ok", false), "restart %d: %s" % [restart, JSON.stringify(replayed)])
		if not replayed.get("ok", false):
			return
		assert_eq((replayed["value"] as Dictionary)["day_advance_identity_receipt"], receipt,
			"restart %d returns the identical allocation" % restart)


func test_a_changed_request_under_a_committed_key_fails_closed() -> void:
	if _root.is_empty():
		return
	var owners := _owners()
	var request := _advance_request(owners, 3)
	var prepared: Dictionary = owners["port"].prepare_advance(request)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	assert_true(owners["port"].commit_advance({"day_advance_identity_receipt":
		((prepared["value"] as Dictionary)["day_advance_identity_receipt"] as Dictionary).duplicate(true)
	}).get("ok", false))

	# Same allocation key (same start receipt), different source day. Target drift must fail
	# rather than silently re-point a committed identity.
	owners = {}
	var restarted := _owners()
	var drifted: Dictionary = request.duplicate(true)
	drifted["source_day"] = 4
	var result: Dictionary = restarted["port"].prepare_advance(drifted)
	assert_false(result.get("ok", true),
		"a committed key cannot be re-prepared with different bytes")


func test_six_successive_advances_yield_days_two_through_seven_and_no_day_eight() -> void:
	if _root.is_empty():
		return
	var owners := _owners()
	var targets: Array[int] = []
	for source_day: int in range(1, 7):
		var request := _advance_request(owners, source_day)
		var prepared: Dictionary = owners["port"].prepare_advance(request)
		assert_true(prepared.get("ok", false),
			"day %d advances: %s" % [source_day, JSON.stringify(prepared)])
		if not prepared.get("ok", false):
			return
		var receipt: Dictionary = (prepared["value"] as Dictionary)["day_advance_identity_receipt"]
		assert_true(owners["port"].commit_advance(
			{"day_advance_identity_receipt": receipt.duplicate(true)}).get("ok", false))
		targets.append(int(receipt["target_day"]))

	assert_eq(targets, [2, 3, 4, 5, 6, 7], "six advances yield exactly Days 2..7")

	# THERE IS NO DAY 8. Day 7 is terminal, so no source day can allocate past it.
	var day_seven := _advance_request(owners, 7)
	assert_false(owners["port"].prepare_advance(day_seven).get("ok", true),
		"no Day-8 allocation exists; source_day 7 is refused outright")


func test_each_source_day_allocates_a_distinct_target_identity() -> void:
	if _root.is_empty():
		return
	var owners := _owners()
	var tokens: Dictionary = {}
	for source_day: int in range(1, 7):
		var request := _advance_request(owners, source_day)
		var prepared: Dictionary = owners["port"].prepare_advance(request)
		if not prepared.get("ok", false):
			assert_true(false, JSON.stringify(prepared))
			return
		var receipt: Dictionary = (prepared["value"] as Dictionary)["day_advance_identity_receipt"]
		assert_true(owners["port"].commit_advance(
			{"day_advance_identity_receipt": receipt.duplicate(true)}).get("ok", false))
		var token := str(receipt["target_causal_day_instance"])
		assert_false(tokens.has(token), "day %d reused an existing target token" % source_day)
		tokens[token] = true
	assert_eq(tokens.size(), 6, "six distinct target identities")


# ---- request construction over real owners ----

## A distinct Schedule-Done request per source day: each carries its own resolution start receipt,
## so each has its own allocation key.
func _advance_request(owners: Dictionary, source_day: int) -> Dictionary:
	var issuer: RefCounted = owners["issuer"]
	var resolution_receipt := _resolution_receipt(issuer, source_day)
	var source_receipt := _causal_day_receipt(owners)
	return {
		"resolution_kind": "schedule_done",
		"source_resolution_receipt": resolution_receipt,
		"run_id": "run-recovery",
		"branch_id": "branch-recovery",
		"desktop_timeline_generation": 0,
		"source_day": source_day,
		"source_causal_day_instance": str(source_receipt.get("token", "")),
		"source_causal_day_instance_issuer_receipt": source_receipt,
	}


## The day_resolution_stage child that stands in for this day's P01.day_resolution.start receipt.
func _resolution_receipt(issuer: RefCounted, source_day: int) -> Dictionary:
	var parent := _root_receipt(issuer)
	var derived: Dictionary = issuer.derive_child({
		"parent_receipt_id": str(parent.get("receipt_id", "")),
		"child_kind": &"day_resolution_stage",
		"ordinal": 0,
		"source_ids": ["role=day_resolution.start", "source_day=%d" % source_day],
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	if not derived.get("ok", false):
		return {}
	# The port takes the {receipt_id, provenance} pair, not the raw provenance: the child id IS the
	# receipt id at this seam.
	var value: Dictionary = derived["value"]
	return {
		"receipt_id": str(value.get("child_id", "")),
		"provenance": (value.get("provenance", {}) as Dictionary).duplicate(true),
	}


func _root_receipt(issuer: RefCounted) -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	if not issued.get("ok", false):
		return {}
	return ((issued["value"] as Dictionary)["issuer_receipt"] as Dictionary).duplicate(true)


## The SOURCE causal-day identity the advance departs from.
##
## Minted from the ROOT STORE, not the issuer: the issuer deliberately refuses
## issue(&"causal_day_instance") because a logical day is ALLOCATED through this very port, never
## issued directly. That refusal is the law this suite exists to protect, so the fixture respects it.
func _causal_day_receipt(owners: Dictionary) -> Dictionary:
	var issued: Dictionary = (owners["root_store"] as RefCounted).issue(&"causal_day_instance")
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	if not issued.get("ok", false):
		return {}
	return ((issued["value"] as Dictionary)["issuer_receipt"] as Dictionary).duplicate(true)


func test_scene_restart_before_and_after_commit_reuses_one_opaque_identity() -> void:
	if _root.is_empty():
		return
	var owners := _owners()
	var issuer: RefCounted = owners["issuer"]
	var parent := _root_receipt(issuer)
	var proof: Dictionary = issuer.derive_child({
		"parent_receipt_id": str(parent["receipt_id"]),
		"child_kind": &"scene_day_completion",
		"ordinal": 0,
		"source_ids": ["scene=authored-source", "successor=authored-target"],
	})
	assert_true(proof.get("ok", false), "requires released real scene child-kind support")
	if not proof.get("ok", false):
		return
	var source := _causal_day_receipt(owners)
	var request := {
		"resolution_kind": "scene_day_complete",
		"source_resolution_receipt": {
			"receipt_id": proof["value"]["child_id"],
			"provenance": proof["value"]["provenance"],
		},
		"run_id": "scene-run", "branch_id": "scene-branch",
		"desktop_timeline_generation": 0,
		"source_causal_day_instance": source["token"],
		"source_causal_day_instance_issuer_receipt": source,
	}
	var prepared: Dictionary = owners["port"].prepare_advance(request)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return
	var expected: Dictionary = prepared["value"]["day_advance_identity_receipt"]
	owners = {}
	owners = _owners()
	var recovered: Dictionary = owners["port"].prepare_advance(request)
	assert_true(recovered.get("ok", false), str(recovered))
	if not recovered.get("ok", false):
		return
	assert_eq(recovered["value"]["day_advance_identity_receipt"], expected,
		"uncommitted prepare leaves no phantom allocation")
	var committed: Dictionary = owners["port"].commit_advance(
		recovered["value"]["day_advance_identity_candidate"])
	assert_true(committed.get("ok", false), str(committed))
	if not committed.get("ok", false):
		return
	owners = {}
	owners = _owners()
	var replayed: Dictionary = owners["port"].prepare_advance(request)
	assert_true(replayed.get("ok", false), str(replayed))
	if not replayed.get("ok", false):
		return
	assert_eq(replayed["value"]["day_advance_identity_receipt"], expected,
		"durable scene commit replays the original receipt")
	var root: Dictionary = owners["root_store"].capture()
	assert_eq(root["value"]["next_counter"], expected["counter_end"],
		"restarts never consume a second scene identity")
