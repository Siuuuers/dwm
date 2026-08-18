extends "res://addons/gut/test.gd"
# Committed Schedule -> day resolution, END TO END (Plan 01 Task 6, dwm-p2r.13, Steps 6.1/6.2/6.3/6.6).
#
# SUBSTRATE. The same real-object substrate as tests/unit/test_day_resolution_start_port.gd and
# tests/unit/test_game_state_schedule_commit_port.gd: a GUID-isolated root, a real
# DesktopIssuerRootStore over real JsonFileStorage, the real DesktopIdentityNonceIssuer, the
# production ScheduleActionRegistry through load_current(), a real GameState, and ONE
# ScheduleFoundationPublicationLedger shared by the commit port and the start port. Step 6.6 is
# explicit that a fake may observe but may never be the production success source here, so there is
# no fake in this file at all -- every aggregate this suite starts from was minted by the real
# GameStateScheduleCommitPort and installed into the real owner.
#
# READ THIS BEFORE TRUSTING ANY ASSERTION BELOW: TWO HONEST LIMITS.
#
# 1. THERE IS NO PRODUCTION CALLER OF DayResolutionStartPort YET. Step 6.5 charters Bootstrap to
#    CONSTRUCT and RETAIN the port; nothing calls prepare_from_committed_schedule/capture/commit/
#    rollback/publish outside tests. The port also has no install seam of its own:
#    prepare_from_committed_schedule returns a detached candidate with no lifecycle in it, while its
#    commit() forwards to the retained state port, which requires a whole lifecycle. This suite
#    therefore bridges the two by hand in _install_by_hand() -- the test is that bridge, and a future
#    production start path may well be shaped differently. What the bridge does prove is real: the
#    port's own prepare, commit, rollback and publish all run, over real objects, against a real
#    aggregate. The one path production actually uses today is GameStateDayResolutionPort
#    .begin_or_resume, exercised separately in the two Step 6.6 tests below.
#
# 2. THE START PORT'S capture()/rollback() ARE WIDE, NOT NARROW. They delegate to the retained state
#    port, whose backup is the WHOLE lifecycle (GameStateDayResolutionPort.capture). RunLifecycle DID
#    gain the narrow capture_active_plan/commit_active_plan/rollback_active_plan seams Step 6.5 asks
#    for, and tests/unit/test_run_lifecycle_plan_seams.gd proves they are narrow -- but no port routes
#    through them yet. So this file must not claim narrowness: it asserts what the wide path really
#    does, and the gap is recorded for Task 7 rather than papered over.
#
# WHAT THIS FILE OWNS, as distinct from the two unit suites. The unit suites own the identity row
# P01.day_resolution.start and the publish/restart contract in isolation, both over an EMPTY
# aggregate. This file owns what only a nonempty real commit can reach:
#   * a real commit -- empty and nonempty -- becoming a real active resolution plan that carries the
#     committed aggregate, its registry-derived route projection, and both receipt ids (line 963);
#   * the two Step 6.1 rejections that need committed entries to exist at all (altered source,
#     mismatched order) -- unreachable from the unit suite, whose aggregate is always empty;
#   * the frozen slot order surviving a serialize/restore round trip, and the load-side re-proof;
#   * publication as the only start signal, and both publication kinds in ONE ledger document;
#   * the two Step 6.6 removals, proven through the REAL GameStateDayResolutionPort rather than by
#     reading the source.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

const CAUSAL_DAY := "causal_day_instance.3333333333333333333333333333333333333333333333333333333333333333"
const VIEW_FINGERPRINT := "schedule_view.44444444444444444444444444444444"
const LEDGER_FIXED_PATH := "schedule-foundation-publications.json"

var _root := ""
var _storage: RefCounted = null
var _root_store: RefCounted = null
var _issuer: RefCounted = null
var _registry: RefCounted = null
var _fingerprint := ""
var _game_state: Node = null
var _ledger: Object = null
var _commit_port: Object = null
var _state_port: Object = null
var _start_port: Object = null
var _commands: Dictionary = {}
var _root_counter := 0
var _signals: Array[String] = []


func before_each() -> void:
	_commands = {}
	_signals = []

	_root = _isolated_root()
	_storage = JsonFileStorage.new(_root)

	_root_store = ROOT_STORE.new()
	assert_true(_root_store.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(_root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(_root_store).get("ok", false))

	var loaded_registry: Dictionary = REGISTRY.load_current()
	assert_true(loaded_registry.get("ok", false), str(loaded_registry))
	_registry = (loaded_registry.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded_registry.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	# IN THE TREE since Task 7: an ordinary_action substage commits real effects, and
	# GameState resolves /root/EffectResolver by node path, which a detached instance cannot reach.
	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()
	# BOTH signals the state port is able to emit are recorded by name, not merely counted: a publish
	# that started emitting `day_changed` as well would leave a size-only assertion green.
	_game_state.save_relevant_state_changed.connect(
		func() -> void: _signals.append("save_relevant_state_changed"))
	_game_state.day_changed.connect(
		func(_day: int) -> void: _signals.append("day_changed"))

	# ONE ledger for both ports, exactly as ApplicationBootstrap retains it: the commit port's
	# schedule_commit publications and the start port's day_resolution_start publications must land in
	# the same document, or a cold restart could replay one without ever seeing the other. Asserted
	# directly in test_both_publication_kinds_land_in_the_one_shared_ledger_document.
	_ledger = LEDGER.new()
	assert_true(_ledger.configure(_storage).get("ok", false))
	assert_true(_ledger.load().get("ok", false))
	_commit_port = COMMIT_PORT.new(_game_state, _registry, _issuer, _ledger)
	_state_port = STATE_PORT.new(_game_state)
	_start_port = START_PORT.new(_state_port, _registry, _issuer, _ledger)


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("committed-schedule-resolution-%d" % _root_counter)
	var production: String = ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


# ---- the accepted start ----

func test_a_real_nonempty_commit_starts_a_resolution_that_freezes_the_committed_order() -> void:
	# Drafts arrive out of slot order; the commit port emits `entries` already slot-sorted, so what
	# this test pins is the plan's correspondence to the AGGREGATE -- one substage per committed
	# entry, in the aggregate's own order, under the exact substage id format. (That the commit port
	# sorts at all is owned by tests/unit/test_game_state_schedule_commit_port.gd.)
	var committed: Dictionary = _commit("day1-three", 1, [
		_ordinary("draft-c", 5, "rest", 1),
		_ordinary("draft-a", 0, "training", 1),
		_ordinary("draft-b", 3, "working", 1),
	])
	if committed.is_empty():
		return
	var aggregate: Dictionary = committed["committed_schedule"]
	assert_eq((aggregate["entries"] as Array).size(), 3, "the real port committed three entries")
	assert_false((committed["route_plan"] as Array).is_empty(),
		"a nonempty commit carries the registry-derived route projection")

	var request: Dictionary = _start_request(committed)
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, "a real committed Schedule starts a resolution: %s" % str(prepared))
		return
	var installed: Dictionary = _install_by_hand(str(request["resolution_id"]), prepared)
	assert_true(installed.get("ok", false), str(installed))
	if not installed.get("ok", false):
		return
	var plan: Variant = _live_plan()
	if typeof(plan) != TYPE_DICTIONARY:
		assert_true(false, "the start installed no plan")
		return

	assert_eq((plan as Dictionary)["committed_schedule"], aggregate,
		"the plan persists the exact real aggregate, byte for byte")
	assert_eq((plan as Dictionary)["route_plan"], committed["route_plan"],
		"the plan persists the registry-derived route projection as-is")
	assert_eq(str((plan as Dictionary)["schedule_commit_receipt_id"]),
		str((aggregate["commit_receipt"] as Dictionary)["receipt_id"]),
		"the plan binds the Schedule commit it began from")
	assert_eq(str((plan as Dictionary)["board_fate_receipt_id"]),
		str((request["board_fate_receipt"] as Dictionary)["receipt_id"]),
		"the plan binds Plan 02's board-fate receipt id")
	assert_eq(_substage_ids(plan as Dictionary), _expected_substage_ids(1, aggregate),
		"one substage per committed entry, in the aggregate's slot order")
	assert_eq(str(((prepared["value"] as Dictionary)["start_receipt"] as Dictionary)["schedule_commit_receipt_id"]),
		str((aggregate["commit_receipt"] as Dictionary)["receipt_id"]),
		"the start receipt names the same commit the plan froze")


# Step 6.1 requires rejecting an "altered source" and a "mismatched order". BOTH need committed
# entries to exist, so neither is reachable from tests/unit/test_day_resolution_start_port.gd, whose
# aggregate is always the empty Done -- its own altered-source block sits behind
# `if not entries.is_empty()` and never executes. This suite is the only place they can be proven.
#
# The two rejections are owned by DIFFERENT layers, and the assertions below name which:
# an unregistered action survives ScheduleStateSchema (which knows no registry) and is caught by the
# start port's own _revalidate_entries; a descending slot order is caught EARLIER, by the schema's
# own ascent rule, so the port's matching order check is defence in depth rather than the first line.
func test_a_nonempty_aggregate_is_revalidated_entry_by_entry_before_any_start() -> void:
	var committed: Dictionary = _commit("day1-reject", 1, [
		_ordinary("draft-a", 0, "training", 1),
		_ordinary("draft-b", 1, "working", 1),
	])
	if committed.is_empty():
		return
	var request: Dictionary = _start_request(committed)
	assert_true(_prepare(request).get("ok", false), "the untampered aggregate starts cleanly")

	var altered: Dictionary = request.duplicate(true)
	var altered_entries: Array = (altered["committed_schedule"] as Dictionary)["entries"]
	((altered_entries[0]) as Dictionary)["action_id"] = "tampered"
	var refused_source: Dictionary = _prepare(altered)
	assert_false(refused_source.get("ok", true),
		"an altered committed entry must not survive revalidation")
	assert_eq(str(refused_source.get("code", &"")), "day_resolution_entry_unregistered",
		"the start port's own registry revalidation is what catches an unregistered action")

	var reordered: Dictionary = request.duplicate(true)
	var reordered_entries: Array = (reordered["committed_schedule"] as Dictionary)["entries"]
	reordered_entries.reverse()
	var refused_order: Dictionary = _prepare(reordered)
	assert_false(refused_order.get("ok", true), "a mismatched slot order must not start a resolution")
	assert_eq(str(refused_order.get("code", &"")), "invalid_committed_entry",
		"the aggregate schema's ascent rule rejects a descending order before the port's own check")


func test_a_receipt_backed_empty_commit_starts_a_day_seven_resolution_with_no_substages() -> void:
	# Empty Done is admitted only through its REAL receipt (Step 6.5), so this begins from a genuine
	# empty commit rather than from an aggregate with the receipt left off.
	var committed: Dictionary = _commit("day7-empty", 7, [])
	if committed.is_empty():
		return
	var aggregate: Dictionary = committed["committed_schedule"]
	assert_eq(aggregate["entries"], [], "the empty commit committed no entries")
	assert_eq(typeof(aggregate["commit_receipt"]), TYPE_DICTIONARY,
		"an empty Done is still receipt-backed")

	var request: Dictionary = _start_request(committed)
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, "a receipt-backed empty Done starts a resolution: %s" % str(prepared))
		return
	assert_true(_install_by_hand(str(request["resolution_id"]), prepared).get("ok", false))
	var plan: Variant = _live_plan()
	if typeof(plan) != TYPE_DICTIONARY:
		assert_true(false, "the empty start installed no plan")
		return

	assert_eq(int((plan as Dictionary)["source_day"]), 7, "the resolution froze the aggregate's own day")
	assert_eq(_substage_ids(plan as Dictionary), [] as Array[String],
		"a genuinely empty commit produces no substages at all")
	assert_eq((plan as Dictionary)["committed_schedule"], aggregate,
		"the empty aggregate is persisted whole, receipt included")


func test_the_exact_real_schedule_survives_serialize_and_restore() -> void:
	var committed: Dictionary = _commit("day1-roundtrip", 1, [
		_ordinary("draft-a", 0, "training", 1),
		_ordinary("draft-b", 2, "working", 1),
	])
	if committed.is_empty():
		return
	var request: Dictionary = _start_request(committed)
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, str(prepared))
		return
	assert_true(_install_by_hand(str(request["resolution_id"]), prepared).get("ok", false))

	var snapshot: Dictionary = _game_state._run_lifecycle.to_dict()
	var restored: RefCounted = RUN_LIFECYCLE.new()
	var candidate: Dictionary = restored.prepare_restore(snapshot.duplicate(true))
	assert_true(candidate.get("ok", false), str(candidate))
	if not candidate.get("ok", false):
		return
	assert_true(restored.commit_restore((candidate["value"] as Dictionary)["candidate"]).get("ok", false))
	assert_eq(restored.to_dict(), snapshot, "the serialized lifecycle restores byte-identically")
	assert_eq((restored.to_dict()["active_resolution_plan"] as Dictionary)["committed_schedule"],
		committed["committed_schedule"],
		"the exact real schedule survives the round trip")

	# The load-side re-proof (Step 6.3). Nothing else rejects this bundle: DayResolutionPlan.from_dict
	# performs no aggregate-level validation, so an entry added to the restored aggregate passes every
	# shape check and is caught ONLY by the substage-correspondence re-proof.
	var tampered: Dictionary = snapshot.duplicate(true)
	var entries: Array = ((tampered["active_resolution_plan"] as Dictionary)["committed_schedule"] as Dictionary)["entries"]
	entries.append((entries[0] as Dictionary).duplicate(true))
	((entries[-1]) as Dictionary)["slot_index"] = 9
	((entries[-1]) as Dictionary)["schedule_entry_id"] = "forged-entry"
	var refused: Dictionary = RUN_LIFECYCLE.new().prepare_restore(tampered)
	assert_false(refused.get("ok", true),
		"a snapshot whose aggregate gained an entry is refused on load: " + str(refused))


# ---- the reversible surface (Step 6.2) ----

func test_publication_is_the_only_start_signal_and_replays_without_a_second_one() -> void:
	var committed: Dictionary = _commit("day1-publish", 1, [_ordinary("draft-a", 0, "training", 1)])
	if committed.is_empty():
		return
	var request: Dictionary = _start_request(committed)
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, str(prepared))
		return

	_signals = []
	assert_true(_install_by_hand(str(request["resolution_id"]), prepared).get("ok", false))
	assert_eq(_signals, [] as Array[String], "the commit installs the plan silently")

	var publication: Dictionary = _publication(prepared)
	var first: Dictionary = _start_port.publish(publication.duplicate(true))
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false):
		return
	assert_eq(first.get("value"), {"published": true}, "the exact success value")
	assert_eq(_signals, ["save_relevant_state_changed"] as Array[String],
		"publication emits that one signal and no other")

	var replay: Dictionary = _start_port.publish(publication.duplicate(true))
	assert_true(replay.get("ok", false), str(replay))
	assert_eq(replay.get("value"), first.get("value"), "the replayed success is identical")
	assert_eq(_signals, ["save_relevant_state_changed"] as Array[String],
		"a replayed publication emits nothing further")


# The shared-ledger identity claim, observed in the document itself rather than inferred from the
# wiring: one storage, one file, both frozen kinds. If the two ports ever held separate ledgers, a
# cold restart could replay one kind while never seeing the other.
func test_both_publication_kinds_land_in_the_one_shared_ledger_document() -> void:
	var committed: Dictionary = _commit("day1-ledger", 1, [_ordinary("draft-a", 0, "training", 1)])
	if committed.is_empty():
		return
	var commit_published: Dictionary = _commit_port.call(&"publish", {
		"committed_schedule": (committed["committed_schedule"] as Dictionary).duplicate(true),
		"schedule_commit_receipt": (committed["schedule_commit_receipt"] as Dictionary).duplicate(true),
	})
	assert_true(commit_published.get("ok", false), str(commit_published))

	var request: Dictionary = _start_request(committed)
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, str(prepared))
		return
	assert_true(_install_by_hand(str(request["resolution_id"]), prepared).get("ok", false))
	assert_true(_start_port.publish(_publication(prepared)).get("ok", false))

	assert_eq(_ledger_record_kinds(), ["day_resolution_start", "schedule_commit"] as Array[String],
		"both frozen kinds are recorded in the single shared document")


# Step 6.2 requires that a failed start leaves no changed active plan and no executed stage.
#
# NOTE THE WIDTH, because the file header explains why it matters: capture()/rollback() delegate to
# the state port, whose backup is the WHOLE lifecycle, so this proves restoration of the active plan
# WITHOUT proving that a concurrent unrelated change would survive. RunLifecycle's narrow seams exist
# for exactly that and are proven in tests/unit/test_run_lifecycle_plan_seams.gd; wiring a port
# through them is Task 7 work, not something this test may assert today.
func test_rollback_leaves_no_active_plan_and_no_executed_stage() -> void:
	var committed: Dictionary = _commit("day1-rollback", 1, [_ordinary("draft-a", 0, "training", 1)])
	if committed.is_empty():
		return
	var backup_result: Dictionary = _start_port.capture()
	assert_true(backup_result.get("ok", false), str(backup_result))
	if not backup_result.get("ok", false):
		return
	var backup: Dictionary = (backup_result["value"] as Dictionary)["backup"]
	assert_eq(_live_plan(), null, "the run had no resolution before the start")

	var request: Dictionary = _start_request(committed)
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, str(prepared))
		return
	assert_true(_install_by_hand(str(request["resolution_id"]), prepared).get("ok", false))
	assert_eq(typeof(_live_plan()), TYPE_DICTIONARY, "the start installed a plan")

	_signals = []
	var rolled: Dictionary = _start_port.rollback(backup)
	assert_true(rolled.get("ok", false), str(rolled))
	assert_eq(_live_plan(), null, "rollback leaves no active plan and so no executed stage")
	assert_eq(_signals, [] as Array[String], "rollback emits nothing")


# ---- succession (Step 6.3) ----

# Driven through the same prepare + install composition the rest of this file uses, so it exercises
# the ports rather than repeating tests/unit/test_run_lifecycle_plan_seams.gd, which already owns the
# same two laws at the bare RunLifecycle level.
func test_a_same_resolution_replay_returns_the_existing_plan_and_a_rival_conflicts() -> void:
	var committed: Dictionary = _commit("day1-succession", 1, [_ordinary("draft-a", 0, "training", 1)])
	if committed.is_empty():
		return
	var request: Dictionary = _start_request(committed)
	var prepared: Dictionary = _prepare(request)
	if not prepared.get("ok", false):
		assert_true(false, str(prepared))
		return
	var resolution_id: String = str(request["resolution_id"])
	assert_true(_install_by_hand(resolution_id, prepared).get("ok", false))
	var installed_plan: Variant = _live_plan()
	if typeof(installed_plan) != TYPE_DICTIONARY:
		assert_true(false, "the first start installed no plan")
		return

	var replayed: Dictionary = _install_by_hand(resolution_id, prepared)
	assert_true(replayed.get("ok", false), "replaying the same resolution is admitted: " + str(replayed))
	assert_eq(_live_plan(), installed_plan,
		"the replay reinstalls the EXISTING plan rather than a fresh one")

	var rival: Dictionary = _install_by_hand(resolution_id + ".rival", prepared)
	assert_false(rival.get("ok", true), "a rival resolution conflicts while this one is incomplete")
	assert_eq(str(rival.get("code", &"")), "resolution_conflict", "the exact conflict code")
	assert_eq(_live_plan(), installed_plan, "a refused rival leaves the installed plan untouched")


# ---- the Step 6.6 removals, through the real production port ----

func test_the_production_state_port_begins_from_the_owners_real_committed_schedule() -> void:
	var committed: Dictionary = _commit("day1-production", 1, [
		_ordinary("draft-a", 0, "training", 1),
		_ordinary("draft-b", 1, "working", 1),
	])
	if committed.is_empty():
		return
	var aggregate: Dictionary = committed["committed_schedule"]

	var begun: Dictionary = _state_port.begin_or_resume("resolution.production.day1")
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false):
		return
	var plan: Variant = _live_plan()
	if typeof(plan) != TYPE_DICTIONARY:
		assert_true(false, "begin_or_resume installed no plan")
		return
	assert_eq((plan as Dictionary)["committed_schedule"], aggregate,
		"production begins from the owner's REAL aggregate, not a synthetic seed")
	assert_eq(_substage_ids(plan as Dictionary), _expected_substage_ids(1, aggregate),
		"the committed entries reached the plan; a seeded [] would have produced none")

	# TASK 7 CLOSED TWO OF THE THREE GAPS Task 6 pinned here (dwm-p2r.14 Steps 7.2/7.5). The
	# production start path now persists the frozen registry projection -- the execute stages read
	# each entry's effects out of it -- and the committed aggregate's own commit-receipt id, which
	# the Day-7 provenance handoff consumes.
	var projection: Array = (plan as Dictionary)["route_plan"]
	assert_eq(projection.size(), (aggregate["entries"] as Array).size(),
		"the production start path persists one projected record per committed entry")
	for projected: Variant in projection:
		var record := projected as Dictionary
		assert_true(record.has("effect_ids"),
			"each projected record carries the registry's effect ids")
		assert_true(record.has("action_kind"),
			"each projected record carries the registry-owned action kind")
	assert_eq((plan as Dictionary)["schedule_commit_receipt_id"],
		((aggregate["commit_receipt"] as Dictionary)["receipt_id"]),
		"the plan binds the exact commit receipt the aggregate was minted with")

	# STILL OPEN, and deliberately so. board_fate_receipt_id remains null because dwm-p2r.9 never
	# delivered the integrated DesktopBoardFatePort its Plan-02 gate names (recorded as Deviation-2
	# on dwm-p2r.14). Pinned exactly as Task 6 pinned the others: when that port lands, this fails
	# loudly rather than drifting silently.
	assert_eq((plan as Dictionary)["board_fate_receipt_id"], null,
		"DEVIATION-2: no integrated DesktopBoardFatePort exists to bind yet")

	assert_true(_state_port.begin_or_resume("resolution.production.day1").get("ok", false),
		"repeating the same Done command stays idempotent")
	assert_eq(_live_plan(), plan, "the idempotent replay changed nothing")


func test_the_execute_stage_receipt_reads_entry_ids_from_the_committed_substages() -> void:
	var committed: Dictionary = _commit("day1-entryids", 1, [
		_ordinary("draft-a", 0, "training", 1),
		_ordinary("draft-b", 1, "working", 1),
	])
	if committed.is_empty():
		return
	var aggregate: Dictionary = committed["committed_schedule"]
	assert_true(_state_port.begin_or_resume("resolution.entryids.day1").get("ok", false))

	# Advance to the execute boundary through the port's own seam. lock_day and validate_schedule
	# carry no owner-receipt law, so completing them needs nothing this suite has to invent.
	assert_eq(_advance_stage(), "lock_day")
	assert_eq(_advance_stage(), "validate_schedule")

	# The cursor now points at the FIRST ENTRY SUBSTAGE, not at the execute stage record.
	#
	# TASK 7 (dwm-p2r.14 Step 7.2) SPLIT WHAT USED TO BE CONFLATED. The port previously keyed its
	# immediate receipt off stage_id alone, so a substage silently received its PARENT's aggregate
	# envelope. A substage now returns its own `schedule_entry_complete` receipt naming the one
	# entry it executed, which is what makes per-entry effect application addressable at all.
	var execute: Dictionary = _state_port.begin_next_stage()
	assert_true(execute.get("ok", false), str(execute))
	if not execute.get("ok", false):
		return
	var receipt: Dictionary = (execute["value"] as Dictionary)["receipt"]
	assert_eq(str(receipt["kind"]), "schedule_entry_complete", "the entry-substage receipt kind")
	var committed_ids: Array = _committed_entry_ids(aggregate)
	assert_false(committed_ids.is_empty(),
		"a nonempty commit can no longer report an empty entry-receipt list")
	assert_eq(str((receipt["value"] as Dictionary)["entry_receipt_id"]), str(committed_ids[0]),
		"the substage names the FIRST committed ordinary entry, read from the frozen substages")
	assert_true((receipt["value"] as Dictionary).has("outcome_ids"),
		"the substage reports the registry effects it applied")


# ---- helpers ----

## Commits `drafts` for `day` through the REAL commit port AND installs the result in the owner, so
## every later assertion runs against an aggregate the production path actually holds. Returns the
## prepared value, or {} after reporting the port's own rejection.
func _commit(label: String, day: int, drafts: Array) -> Dictionary:
	# The owner refuses a commit for a day other than the one it holds, so the run must really be on
	# that day before the port will produce a real aggregate.
	_game_state._lifecycle_set_playing_day(day)
	var command: Dictionary = _command(label)
	var prepared: Dictionary = _commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	})
	if not prepared.get("ok", false):
		assert_true(false, "the production commit port must produce a real aggregate for %s: %s %s" % [
			label, str(prepared.get("code", &"")), str(prepared.get("message", "")),
		])
		return {}
	var value: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
	var installed: Dictionary = _commit_port.call(&"commit", value["game_state_candidate"])
	if not installed.get("ok", false):
		assert_true(false, "the owner must accept its own prepared candidate: " + str(installed))
		return {}
	_signals = []
	return value


## Wraps a real commit in the exact six-member start request.
func _start_request(committed: Dictionary) -> Dictionary:
	var aggregate: Dictionary = committed["committed_schedule"]
	var resolution: Dictionary = _command("resolution.day%d" % int(aggregate["day"]))
	return {
		"resolution_id": str(resolution["id"]),
		"resolution_issuer_receipt": (resolution["receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": CAUSAL_DAY,
		"committed_schedule": aggregate.duplicate(true),
		"route_plan": (committed["route_plan"] as Array).duplicate(true),
		"board_fate_receipt": _board_fate_receipt(),
	}


func _prepare(request: Dictionary) -> Dictionary:
	return _start_port.call(&"prepare_from_committed_schedule", request)


## Installs a prepared start BY HAND, because Task 6 built no port-level seam that does it (see the
## file header). The plan itself comes from RunLifecycle's PURE prepare, which is where the admission
## law -- idempotent replay, rival conflict, day window -- actually lives; this helper then splices
## that candidate into the live lifecycle dictionary the retained state port's commit() demands, and
## routes it through DayResolutionStartPort.commit so the port under test really runs.
##
## Do not read this as a model of production: production's only start path today is
## GameStateDayResolutionPort.begin_or_resume, covered by the two Step 6.6 tests above.
func _install_by_hand(resolution_id: String, prepared: Dictionary) -> Dictionary:
	var value: Dictionary = prepared["value"]
	var lifecycle: RefCounted = _game_state._run_lifecycle
	var candidate: Dictionary = lifecycle.prepare_day_resolution(
		resolution_id, value["committed_schedule"], value["route_plan"],
		value["schedule_commit_receipt_id"], value["board_fate_receipt_id"])
	if not candidate.get("ok", false):
		return candidate
	var installed: Dictionary = lifecycle.to_dict()
	installed["active_resolution_plan"] = (candidate["value"] as Dictionary)["candidate"]
	return _start_port.call(&"commit", {"lifecycle": installed})


## The ledger froze this publication member set for kind day_resolution_start in Task 4.
func _publication(prepared: Dictionary) -> Dictionary:
	var value: Dictionary = prepared["value"]
	return {
		"day_resolution_start_receipt": (value["start_receipt"] as Dictionary).duplicate(true),
		"resolution_plan": {
			"committed_schedule": (value["committed_schedule"] as Dictionary).duplicate(true),
			"route_plan": (value["route_plan"] as Array).duplicate(true),
		},
	}


## The distinct kinds the one shared ledger document holds on disk, sorted.
func _ledger_record_kinds() -> Array[String]:
	var text: String = FileAccess.get_file_as_string(_root.path_join(LEDGER_FIXED_PATH))
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		assert_true(false, "the shared ledger document must be readable JSON: " + text)
		return []
	var kinds: Array[String] = []
	for record: Variant in ((parsed as Dictionary).get("records", {}) as Dictionary).values():
		var kind: String = str((record as Dictionary).get("kind", ""))
		if not kinds.has(kind):
			kinds.append(kind)
	kinds.sort()
	return kinds


## Begins and completes the next stage through the port, returning the stage id it advanced.
func _advance_stage() -> String:
	var begun: Dictionary = _state_port.begin_next_stage()
	assert_true(begun.get("ok", false), str(begun))
	if not begun.get("ok", false):
		return ""
	var stage: Dictionary = (begun["value"] as Dictionary)["stage"]
	var receipt: Dictionary = (begun["value"] as Dictionary)["receipt"]
	var completed: Dictionary = _game_state._run_lifecycle.complete_active_stage(
		str(stage["transaction_id"]), {"value": (receipt["value"] as Dictionary).duplicate(true)})
	assert_true(completed.get("ok", false), str(completed))
	return str(stage["stage_id"])


func _live_plan() -> Variant:
	return _game_state._run_lifecycle.to_dict()["active_resolution_plan"]


func _substage_ids(plan: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for stage: Dictionary in (plan["stages"] as Array):
		for substage: Dictionary in (stage["substages"] as Array):
			ids.append(str(substage["substage_id"]))
	return ids


## The substage ids the aggregate alone implies, rebuilt here from its entries in slot order. This
## duplicates what DayResolutionPlan.from_dict re-proves on load, so it is a format lock rather than
## the only guard: it pins the literal "<kind>:day:slot:entry_id" shape the persisted plan exposes.
##
## Task 7 (dwm-p2r.14): ordinary entries and date entries land in DIFFERENT stages that run on
## opposite sides of Hospital, so the prefix is chosen by the registry-owned action_kind. The
## ordinary stage precedes the date stage, which is why the ordinary ids come first here.
func _expected_substage_ids(source_day: int, aggregate: Dictionary) -> Array[String]:
	var ordinary_ids: Array[String] = []
	var date_ids: Array[String] = []
	for entry: Variant in _slot_ordered(aggregate):
		var record := entry as Dictionary
		var is_ordinary := str(record.get("action_kind", "")) == "ordinary"
		var id := "%s:%d:%d:%s" % [
			"ordinary_action" if is_ordinary else "surviving_date",
			source_day, int(record["slot_index"]), str(record["schedule_entry_id"]),
		]
		if is_ordinary:
			ordinary_ids.append(id)
		else:
			date_ids.append(id)
	return ordinary_ids + date_ids


## Scoped to ONE entry stage. The execute_schedule_actions receipt reports only the ordinary
## entries; the dates it must not touch are reported later by execute_schedule_dates.
func _committed_entry_ids(aggregate: Dictionary, action_kind: String = "ordinary") -> Array:
	var ids: Array = []
	for entry: Variant in _slot_ordered(aggregate):
		if str((entry as Dictionary).get("action_kind", "")) != action_kind:
			continue
		ids.append(str((entry as Dictionary)["schedule_entry_id"]))
	return ids


func _slot_ordered(aggregate: Dictionary) -> Array:
	var ordered: Array = (aggregate["entries"] as Array).duplicate(true)
	ordered.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary)["slot_index"]) < int((b as Dictionary)["slot_index"]))
	return ordered


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


## An opaque Plan-02 board-fate receipt. Task 6 binds it whole and never reads inside it, so this
## fixture deliberately carries a member Task 6 has no vocabulary for.
func _board_fate_receipt() -> Dictionary:
	var issued: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	return {
		"receipt_id": str(((issued.get("value", {}) as Dictionary)
			.get("issuer_receipt", {}) as Dictionary)["receipt_id"]),
		"opaque_plan02_member": "board_fate",
	}


func _draft(draft_entry_id: String, slot_index: int, action_id: String, action_kind: String,
		participants: Array, source_receipt_id: Variant, day: int) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": action_kind,
		"participants": participants.duplicate(),
		"source_receipt_id": source_receipt_id,
	}


func _ordinary(draft_entry_id: String, slot_index: int, action_id: String, day: int) -> Dictionary:
	return _draft(draft_entry_id, slot_index, action_id, "ordinary", [], null, day)
