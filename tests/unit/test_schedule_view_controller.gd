extends "res://addons/gut/test.gd"
# Editable saved-ScheduleView controller behavior law (Amendment Plan 03 Task 2 Step 2,
# dwm-oyo.3).
#
# The controller derives kind, participants, repeatability and eligibility from the injected
# immutable registry at the expected fingerprint; drafting reserves and spends no motivation
# and never touches the canonical committed Schedule (proved here against a REAL GameState
# holding a schedule committed through the production GameStateScheduleCommitPort, the
# production issuer, and the production publication ledger). The condition-departure receipt
# index is append-only: byte-identical retries return unchanged, conflicts are typed and
# never partially applied, and the index survives open_day() while the optimistic
# fingerprint ignores its growth.
#
# RED VALIDITY (plan Global Constraints line 40): the compiling ScheduleViewController
# skeleton exists and every method returns the typed not_implemented envelope, so every
# failure below is a typed wrong-behavior result, never a missing file/preload/parse error.

const CONTROLLER := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const GAME_STATE := preload("res://autoload/GameState.gd")
const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const PUBLICATION_LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")

const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const VIEW_FINGERPRINT := "schedule_view.22222222222222222222222222222222"
const VIEW_KEYS: Array = [
	"causal_day_instance", "condition_departure_receipts", "consumed_warning_receipts",
	"date_entry_seen", "day", "entries", "pending_warning",
]

var _registry: Object = null
var _fingerprint := ""
var _root_counter := 0


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))


# ---- helpers ----

func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


func _keys_of(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _open(day: int) -> Object:
	var controller: Object = CONTROLLER.new()
	var configured: Dictionary = controller.configure(_registry, RULES, _fingerprint)
	assert_true(configured.get("ok", false), "configure: " + str(configured))
	var opened: Dictionary = controller.open_day(day, CAUSAL_DAY)
	assert_true(opened.get("ok", false), "open_day: " + str(opened))
	return controller


func _apply(controller: Object, prepared: Dictionary, context: String) -> void:
	assert_true(prepared.get("ok", false), context + ": " + str(prepared))
	if not prepared.get("ok", false):
		return
	var value: Dictionary = prepared.get("value", {})
	assert_true(value.has("candidate"), context + " success value carries {candidate}")
	var committed: Dictionary = controller.commit(value.get("candidate", {}))
	assert_true(committed.get("ok", false), context + " commit: " + str(committed))


func _add(controller: Object, action_id: String, source_receipt_id: Variant, slot_index: int,
		draft_entry_id: String) -> void:
	_apply(controller,
		controller.prepare_add(action_id, source_receipt_id, slot_index, draft_entry_id),
		"prepare_add " + draft_entry_id)


func _view_of(controller: Object) -> Dictionary:
	var snap: Dictionary = controller.snapshot()
	assert_true(snap.get("ok", false), "snapshot: " + str(snap))
	return ((snap.get("value", {}) as Dictionary).get("view", {}) as Dictionary)


func _entry_by_id(view: Dictionary, draft_entry_id: String) -> Dictionary:
	for entry: Dictionary in (view.get("entries", []) as Array):
		if str(entry.get("draft_entry_id", "")) == draft_entry_id:
			return entry
	return {}


func _refused(result: Dictionary, code: String, context: String) -> void:
	assert_false(result.get("ok", true), context + " must refuse: " + str(result))
	assert_eq(_code(result), code, context + " typed code")


func _fingerprint_of(controller: Object) -> String:
	var result: Dictionary = controller.fingerprint()
	assert_true(result.get("ok", false), "fingerprint: " + str(result))
	return str((result.get("value", {}) as Dictionary).get("fingerprint", ""))


func _empty_view(day: int) -> Dictionary:
	return {
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"entries": [],
		"date_entry_seen": false,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": {},
	}


func _condition_candidate(before_view: Dictionary, after_view: Dictionary,
		source_id: String) -> Dictionary:
	return {
		"schedule_view_before": before_view.duplicate(true),
		"schedule_view_after": after_view.duplicate(true),
		"schedule_view_commit_receipt": {
			"source_condition_receipt_id": source_id,
			"source_condition_receipt_provenance": {
				"schema_version": 1, "parent_receipt_id": "cmd-root",
				"child_kind": "condition_departure", "ordinal": 0, "source_ids": [],
				"child_id": source_id,
			},
			"schedule_view_before_sha256": _sha256(_canonical(before_view)),
			"schedule_view_after_sha256": _sha256(_canonical(after_view)),
			"disposition": "condition_departure_view_committed",
		},
	}


## Commits one real ordinary Day-1 schedule into a REAL GameState through the production
## commit port, issuer, and publication ledger (the exact substrate of
## test_game_state_schedule_commit_port.gd). Returns {} when any production step fails.
func _committed_game_state() -> Dictionary:
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root := wrapper.path_join("schedule-view-controller-%d" % _root_counter)
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var storage: RefCounted = JsonFileStorage.new(root)
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root_store).get("ok", false))
	var game_state: Node = GAME_STATE.new()
	autofree(game_state)
	game_state.reset_game()
	var ledger: Object = PUBLICATION_LEDGER.new()
	assert_true(ledger.configure(storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	var port: Object = COMMIT_PORT.new(game_state, _registry, issuer, ledger)
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), str(issued))
	var token: Dictionary = issued.get("value", {})
	var request := {
		"transaction_id": str(token.get("token", "")),
		"transaction_issuer_receipt":
			(token.get("issuer_receipt", {}) as Dictionary).duplicate(true),
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": 1,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": [{
			"draft_entry_id": "d-rest", "day": 1, "slot_index": 0, "action_id": "rest",
			"action_kind": "ordinary", "participants": [], "source_receipt_id": null,
		}],
		"registry_fingerprint": _fingerprint,
	}
	var prepared: Dictionary = port.prepare_commit(request)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return {}
	var committed: Dictionary = port.commit(
		(prepared.get("value", {}) as Dictionary).get("game_state_candidate", {}))
	assert_true(committed.get("ok", false), str(committed))
	if not committed.get("ok", false):
		return {}
	return {"game_state": game_state}


# ---- lifecycle ----

func test_an_unconfigured_controller_fails_closed() -> void:
	var bare: Object = CONTROLLER.new()
	_refused(bare.open_day(3, CAUSAL_DAY), "not_configured", "open_day before configure")
	_refused(bare.prepare_add("rest", null, 0, "d1"), "not_configured",
		"prepare_add before configure")


func test_configure_accepts_the_live_fingerprint_and_rejects_a_stale_one() -> void:
	var accepted: Object = CONTROLLER.new()
	var configured: Dictionary = accepted.configure(_registry, RULES, _fingerprint)
	assert_true(configured.get("ok", false), str(configured))
	var refused: Object = CONTROLLER.new()
	_refused(refused.configure(_registry, RULES, "0".repeat(64)),
		"stale_registry_fingerprint", "configure with a mismatched fingerprint")


func test_open_day_rejects_days_zero_and_eight() -> void:
	var controller: Object = CONTROLLER.new()
	var configured: Dictionary = controller.configure(_registry, RULES, _fingerprint)
	assert_true(configured.get("ok", false), str(configured))
	_refused(controller.open_day(0, CAUSAL_DAY), "invalid_day", "open_day(0)")
	_refused(controller.open_day(8, CAUSAL_DAY), "invalid_day", "open_day(8)")


func test_open_day_produces_the_canonical_empty_view() -> void:
	var controller := _open(3)
	var view := _view_of(controller)
	assert_eq(_keys_of(view), VIEW_KEYS, "the view is exactly the seven-key shape")
	assert_eq(int(view.get("day", -1)), 3, "day")
	assert_eq(str(view.get("causal_day_instance", "")), CAUSAL_DAY, "causal day instance")
	assert_eq((view.get("entries", ["x"]) as Array).size(), 0, "entries start empty")
	assert_eq(view.get("date_entry_seen", true), false, "date_entry_seen starts false")


# ---- edits ----

func test_seven_ordinary_slots_fill_with_repeats_and_distinct_draft_ids() -> void:
	var controller := _open(3)
	for slot: int in range(7):
		_add(controller, ["rest", "training", "working"][slot % 3], null, slot, "d%d" % slot)
	var view := _view_of(controller)
	assert_eq((view.get("entries", []) as Array).size(), 7,
		"seven Days-1-6 boxes fill, Training/Working/Rest repeating as distinct drafts")


func test_an_occupied_slot_and_an_out_of_range_slot_are_refused() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	_refused(controller.prepare_add("training", null, 0, "d-clash"),
		"duplicate_slot_index", "an occupied slot")
	_refused(controller.prepare_add("training", null, 7, "d-high"),
		"invalid_slot_index", "slot seven on Days 1-6")


func test_a_reused_draft_entry_id_is_refused() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-same")
	_refused(controller.prepare_add("training", null, 1, "d-same"),
		"duplicate_draft_entry_id", "a reused draft id")


func test_a_non_repeatable_date_cannot_repeat() -> void:
	var controller := _open(3)
	_add(controller, "solo:lavinia:day3", "src:solo:lavinia:day3", 0, "d-first")
	_refused(controller.prepare_add("solo:lavinia:day3", "src:solo:lavinia:day3-b", 1,
		"d-second"), "action_not_repeatable", "a repeated date")


func test_kind_and_participants_are_registry_derived() -> void:
	var controller := _open(2)
	_add(controller, "solo:lavinia:day2", "src:solo:lavinia:day2", 0, "d-solo")
	var solo := _entry_by_id(_view_of(controller), "d-solo")
	assert_eq(_keys_of(solo), ["action_id", "action_kind", "day", "draft_entry_id",
		"participants", "slot_index", "source_receipt_id"], "the exact seven-key entry")
	assert_eq(str(solo.get("action_kind", "")), "solo", "kind comes from the registry")
	assert_eq(solo.get("participants", []), ["lavinia"], "participants come from the registry")
	assert_eq(int(solo.get("day", -1)), 2, "the entry carries the opened day")
	assert_eq(str(solo.get("source_receipt_id", "")), "src:solo:lavinia:day2",
		"the caller's source receipt id is retained")
	var group_controller := _open(2)
	_add(group_controller, "group:priscilla_lavinia:day2", "src:group:day2", 0, "d-group")
	var group := _entry_by_id(_view_of(group_controller), "d-group")
	assert_eq(group.get("participants", []), ["priscilla", "lavinia"],
		"the canonical ordered pair comes from the registry")


func test_source_receipt_class_is_enforced_at_add_time() -> void:
	var controller := _open(3)
	_refused(controller.prepare_add("rest", "src:rest", 0, "d-bad-ordinary"),
		"invalid_source_receipt", "an ordinary action with a source receipt")
	_refused(controller.prepare_add("solo:lavinia:day3", null, 1, "d-bad-date"),
		"invalid_source_receipt", "a date without its acceptance receipt")


func test_an_unregistered_action_is_refused() -> void:
	var controller := _open(3)
	_refused(controller.prepare_add("nap", null, 0, "d-nap"), "unregistered_action",
		"an unregistered action id")


func test_an_action_outside_its_day_window_is_refused() -> void:
	var controller := _open(5)
	_refused(controller.prepare_add("solo:lavinia:day3", "src:solo:lavinia:day3", 0, "d-off"),
		"action_not_allowed_on_day", "a day-3 date on day 5")


# ---- date law ----

func test_a_third_date_on_day_six_is_refused() -> void:
	var controller := _open(6)
	_add(controller, "solo:priscilla:day6", "src:solo:priscilla:day6", 0, "d-p")
	_add(controller, "solo:lavinia:day6", "src:solo:lavinia:day6", 1, "d-l")
	_refused(controller.prepare_add("group:priscilla_lavinia:day6", "src:group:day6", 2,
		"d-g"), "too_many_dates", "a third registered date")


func test_group_and_solo_dates_exclude_each_other_in_both_orders() -> void:
	var solo_first := _open(6)
	_add(solo_first, "solo:priscilla:day6", "src:solo:priscilla:day6", 0, "d-p")
	_refused(solo_first.prepare_add("group:priscilla_lavinia:day6", "src:group:day6", 1,
		"d-g"), "superseded_solo_date", "the group after a participant's solo")
	var group_first := _open(6)
	_add(group_first, "group:priscilla_lavinia:day6", "src:group:day6", 0, "d-g")
	_refused(group_first.prepare_add("solo:lavinia:day6", "src:solo:lavinia:day6", 1,
		"d-l"), "superseded_solo_date", "a participant's solo after the group")


func test_receipts_of_superseded_solos_do_not_linger() -> void:
	var controller := _open(6)
	_add(controller, "solo:priscilla:day6", "src:solo:priscilla:day6", 0, "d-p")
	_apply(controller, controller.prepare_remove("d-p"), "prepare_remove d-p")
	_add(controller, "group:priscilla_lavinia:day6", "src:group:day6", 0, "d-g")
	var view := _view_of(controller)
	assert_eq((view.get("entries", []) as Array).size(), 1, "only the group remains")
	assert_eq(str(_entry_by_id(view, "d-g").get("source_receipt_id", "")), "src:group:day6",
		"the group carries its own reply-acceptance receipt")
	assert_false(_canonical(view).contains("src:solo:priscilla:day6"),
		"the superseded solo's receipt id is gone from the whole view")


func test_date_entry_seen_latches_and_removal_never_clears_it() -> void:
	var controller := _open(2)
	assert_eq(_view_of(controller).get("date_entry_seen", true), false, "starts false")
	_add(controller, "solo:lavinia:day2", "src:solo:lavinia:day2", 0, "d-date")
	assert_eq(_view_of(controller).get("date_entry_seen", false), true,
		"adding any date latches the flag")
	_apply(controller, controller.prepare_remove("d-date"), "prepare_remove d-date")
	var view := _view_of(controller)
	assert_eq((view.get("entries", []) as Array).size(), 0, "the date is removed")
	assert_eq(view.get("date_entry_seen", false), true,
		"removing the last date never clears the latch")


# ---- Day 7 ----

func test_day_seven_is_empty_or_one_solo_at_slot_zero() -> void:
	var controller := _open(7)
	assert_eq((_view_of(controller).get("entries", ["x"]) as Array).size(), 0,
		"Day 7 Alone is a legal empty view")
	_add(controller, "solo:sylvia:day7", "src:solo:sylvia:day7", 0, "d-s")
	assert_eq((_view_of(controller).get("entries", []) as Array).size(), 1,
		"one eligible solo destination at slot zero")
	_refused(controller.prepare_add("solo:lavinia:day7", "src:solo:lavinia:day7", 1,
		"d-second"), "too_many_entries", "a second Day-7 entry")


func test_day_seven_refuses_off_day_actions_and_nonzero_slots() -> void:
	var controller := _open(7)
	_refused(controller.prepare_add("rest", null, 0, "d-rest"), "action_not_allowed_on_day",
		"an ordinary action on Day 7")
	_refused(controller.prepare_add("group:priscilla_lavinia:day2", "src:group:day2", 0,
		"d-g"), "action_not_allowed_on_day", "a day-2 group on Day 7")
	_refused(controller.prepare_add("solo:sylvia:day7", "src:solo:sylvia:day7", 1, "d-s"),
		"invalid_day7_entry", "a Day-7 destination outside slot zero")


func test_priscilla_may_occupy_any_day_four_slot() -> void:
	var low := _open(4)
	_add(low, "solo:priscilla:day4", "src:solo:priscilla:day4", 0, "d-p0")
	var high := _open(4)
	_add(high, "solo:priscilla:day4", "src:solo:priscilla:day4", 6, "d-p6")
	assert_eq(int(_entry_by_id(_view_of(high), "d-p6").get("slot_index", -1)), 6,
		"there is no Day-4 first-slot rule")


# ---- move / remove ----

func test_prepare_move_and_prepare_remove_change_only_their_entry() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	_add(controller, "training", null, 1, "d-train")
	_apply(controller, controller.prepare_move("d-rest", 5), "prepare_move d-rest")
	var moved := _view_of(controller)
	assert_eq(int(_entry_by_id(moved, "d-rest").get("slot_index", -1)), 5,
		"the moved entry sits at its target slot")
	assert_eq(int(_entry_by_id(moved, "d-train").get("slot_index", -1)), 1,
		"the other entry is untouched")
	_apply(controller, controller.prepare_remove("d-train"), "prepare_remove d-train")
	var removed := _view_of(controller)
	assert_eq((removed.get("entries", []) as Array).size(), 1, "one entry remains")
	assert_eq(str(_entry_by_id(removed, "d-rest").get("draft_entry_id", "")), "d-rest",
		"the surviving entry is the moved one")


func test_move_and_remove_refuse_unknown_and_colliding_targets() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	_add(controller, "training", null, 1, "d-train")
	_refused(controller.prepare_remove("d-ghost"), "draft_entry_not_found",
		"removing an unknown draft id")
	_refused(controller.prepare_move("d-ghost", 2), "draft_entry_not_found",
		"moving an unknown draft id")
	_refused(controller.prepare_move("d-rest", 1), "duplicate_slot_index",
		"moving onto an occupied slot")


# ---- transaction seam ----

func test_capture_and_rollback_round_trip_byte_equal() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var expected := _canonical(_view_of(controller))
	var captured: Dictionary = controller.capture()
	assert_true(captured.get("ok", false), str(captured))
	assert_eq(_keys_of(captured.get("value", {})), ["backup"],
		"the capture value is exactly {backup}")
	_add(controller, "training", null, 1, "d-train")
	var rolled: Dictionary = controller.rollback(
		(captured.get("value", {}) as Dictionary).get("backup", {}))
	assert_true(rolled.get("ok", false), str(rolled))
	assert_eq(_canonical(_view_of(controller)), expected,
		"rollback restores the captured view byte-for-byte")


# ---- condition-departure receipt index ----

func test_condition_departure_commit_appends_and_installs_the_after_view() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var before_view := _view_of(controller)
	var after_view: Dictionary = before_view.duplicate(true)
	after_view["entries"] = []
	var candidate := _condition_candidate(before_view, after_view, "cond-1")
	var committed: Dictionary = controller.commit_condition_departure_transition(candidate)
	assert_true(committed.get("ok", false), str(committed))
	var installed := _view_of(controller)
	assert_eq((installed.get("entries", ["x"]) as Array).size(), 0,
		"the after-view's editable fields are installed")
	var ledger: Dictionary = installed.get("condition_departure_receipts", {})
	assert_true(ledger.has("cond-1"), "the receipt is appended under its exact source id")
	assert_eq(_canonical(ledger.get("cond-1", {})),
		_canonical(candidate["schedule_view_commit_receipt"]),
		"the appended receipt is byte-identical")


func test_a_byte_identical_retry_returns_unchanged() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var before_view := _view_of(controller)
	var after_view: Dictionary = before_view.duplicate(true)
	after_view["entries"] = []
	var candidate := _condition_candidate(before_view, after_view, "cond-1")
	assert_true(controller.commit_condition_departure_transition(candidate).get("ok", false),
		"the first application succeeds")
	var applied := _canonical(_view_of(controller))
	var retried: Dictionary = controller.commit_condition_departure_transition(
		candidate.duplicate(true))
	assert_true(retried.get("ok", false),
		"a byte-identical retry returns the retained entry: " + str(retried))
	assert_eq(_canonical(_view_of(controller)), applied,
		"the retry applies no view and appends nothing")


func test_a_conflicting_retry_is_typed_and_leaves_no_partial_mutation() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var before_view := _view_of(controller)
	var after_view: Dictionary = before_view.duplicate(true)
	after_view["entries"] = []
	var candidate := _condition_candidate(before_view, after_view, "cond-1")
	assert_true(controller.commit_condition_departure_transition(candidate).get("ok", false),
		"the first application succeeds")
	var applied := _canonical(_view_of(controller))
	var conflicting := _condition_candidate(before_view, before_view, "cond-1")
	_refused(controller.commit_condition_departure_transition(conflicting),
		"condition_departure_receipt_conflict", "changed bytes under an occupied source id")
	assert_eq(_canonical(_view_of(controller)), applied,
		"a conflicting retry mutates nothing")
	var retained: Dictionary = controller.lookup_condition_departure_receipt("cond-1")
	assert_true(retained.get("ok", false), str(retained))
	assert_eq(_canonical((retained.get("value", {}) as Dictionary).get("receipt", {})),
		_canonical(candidate["schedule_view_commit_receipt"]),
		"the originally retained receipt is unchanged")


func test_a_third_live_state_is_a_typed_conflict_without_partial_mutation() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-live")
	var live := _canonical(_view_of(controller))
	var foreign := _condition_candidate(_empty_view(3), _empty_view(3), "cond-x")
	_refused(controller.commit_condition_departure_transition(foreign),
		"condition_departure_receipt_conflict",
		"a live view matching neither before nor after")
	assert_eq(_canonical(_view_of(controller)), live, "the live view is untouched")
	_refused(controller.lookup_condition_departure_receipt("cond-x"),
		"condition_departure_receipt_not_found", "nothing was appended")


func test_lookup_condition_departure_receipt_is_detached_and_typed_when_absent() -> void:
	var controller := _open(3)
	_refused(controller.lookup_condition_departure_receipt("cond-ghost"),
		"condition_departure_receipt_not_found", "an unknown source id")
	var before_view := _view_of(controller)
	var candidate := _condition_candidate(before_view, before_view, "cond-1")
	assert_true(controller.commit_condition_departure_transition(candidate).get("ok", false),
		"the application succeeds")
	var found: Dictionary = controller.lookup_condition_departure_receipt("cond-1")
	assert_true(found.get("ok", false), str(found))
	assert_eq(_keys_of(found.get("value", {})), ["receipt"],
		"the lookup value is exactly {receipt}")
	var receipt: Dictionary = (found.get("value", {}) as Dictionary).get("receipt", {})
	receipt["disposition"] = "tampered"
	var again: Dictionary = controller.lookup_condition_departure_receipt("cond-1")
	assert_eq(_canonical((again.get("value", {}) as Dictionary).get("receipt", {})),
		_canonical(candidate["schedule_view_commit_receipt"]),
		"the retained receipt is detached from returned copies")


func test_the_ledger_survives_open_day_with_an_unchanged_optimistic_fingerprint() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var digest_before := _fingerprint_of(controller)
	var live := _view_of(controller)
	var candidate := _condition_candidate(live, live, "cond-keep")
	assert_true(controller.commit_condition_departure_transition(candidate).get("ok", false),
		"the ledger-only application succeeds")
	assert_eq(_fingerprint_of(controller), digest_before,
		"only the ledger grew; the optimistic fingerprint is unchanged")
	assert_true(controller.open_day(4, CAUSAL_DAY).get("ok", false), "open_day(4)")
	var reopened := _view_of(controller)
	assert_eq(int(reopened.get("day", -1)), 4, "the day-local fields are replaced")
	assert_eq((reopened.get("entries", ["x"]) as Array).size(), 0, "entries reset")
	assert_eq(reopened.get("date_entry_seen", true), false, "the latch is day-local")
	var kept: Dictionary = controller.lookup_condition_departure_receipt("cond-keep")
	assert_true(kept.get("ok", false),
		"open_day preserves the append-only receipt index: " + str(kept))
	assert_eq(_canonical((kept.get("value", {}) as Dictionary).get("receipt", {})),
		_canonical(candidate["schedule_view_commit_receipt"]),
		"the preserved receipt is byte-identical")


# ---- detachment and canonical-state isolation ----

func test_snapshot_is_detached() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var view := _view_of(controller)
	(view.get("entries", []) as Array).clear()
	view["date_entry_seen"] = true
	var fresh := _view_of(controller)
	assert_eq((fresh.get("entries", []) as Array).size(), 1,
		"mutating a snapshot never reaches the controller's view")
	assert_eq(fresh.get("date_entry_seen", true), false,
		"snapshot members are detached, not aliased")


func test_every_edit_leaves_motivation_and_the_committed_schedule_byte_equal() -> void:
	var fixture := _committed_game_state()
	if fixture.is_empty():
		return
	var game_state: Node = fixture["game_state"]
	var before: Dictionary = game_state.capture_schedule_commit_state()
	assert_true(before.get("ok", false), str(before))
	var before_value: Dictionary = before.get("value", {})
	var motivation_before := int(before_value.get("motivation", -1))
	var committed_before := _canonical(before_value.get("committed_schedule", {}))
	assert_false(committed_before.is_empty(), "a real committed Schedule exists")

	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	_add(controller, "solo:lavinia:day3", "src:solo:lavinia:day3", 1, "d-date")
	_apply(controller, controller.prepare_move("d-rest", 5), "prepare_move d-rest")
	_apply(controller, controller.prepare_remove("d-date"), "prepare_remove d-date")
	var live := _view_of(controller)
	var departed: Dictionary = controller.commit_condition_departure_transition(
		_condition_candidate(live, live, "cond-1"))
	assert_true(departed.get("ok", false), str(departed))
	var captured: Dictionary = controller.capture()
	assert_true(captured.get("ok", false), str(captured))
	_add(controller, "training", null, 2, "d-train")
	assert_true(controller.rollback(
		(captured.get("value", {}) as Dictionary).get("backup", {})).get("ok", false),
		"rollback succeeds")

	var after: Dictionary = game_state.capture_schedule_commit_state()
	assert_true(after.get("ok", false), str(after))
	var after_value: Dictionary = after.get("value", {})
	assert_eq(int(after_value.get("motivation", -2)), motivation_before,
		"no edit reserves or spends motivation")
	assert_eq(_canonical(after_value.get("committed_schedule", {})), committed_before,
		"no edit touches the canonical committed Schedule")


# ---- review fixes: after-adoption, transition refusals, configure guards ----

func test_a_live_after_view_adopts_the_receipt_without_reapplying() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var before_view := _view_of(controller)
	var after_view: Dictionary = before_view.duplicate(true)
	after_view["entries"] = []
	var candidate := _condition_candidate(before_view, after_view, "cond-adopt")
	var applied: Dictionary = controller.commit(after_view.duplicate(true))
	assert_true(applied.get("ok", false),
		"the after-view lands first via commit: " + str(applied))
	var digest := _fingerprint_of(controller)
	var adopted: Dictionary = controller.commit_condition_departure_transition(candidate)
	assert_true(adopted.get("ok", false),
		"a live view already at the after state adopts the receipt: " + str(adopted))
	assert_eq(_fingerprint_of(controller), digest,
		"adoption appends the receipt without reapplying any view")
	assert_eq((_view_of(controller).get("entries", ["x"]) as Array).size(), 0,
		"the editable fields are byte-unchanged")
	var kept: Dictionary = controller.lookup_condition_departure_receipt("cond-adopt")
	assert_true(kept.get("ok", false), str(kept))
	assert_eq(_canonical((kept.get("value", {}) as Dictionary).get("receipt", {})),
		_canonical(candidate["schedule_view_commit_receipt"]),
		"the adopted receipt is byte-identical")


func test_a_malformed_condition_candidate_shape_is_refused() -> void:
	var controller := _open(3)
	_refused(controller.commit_condition_departure_transition(
		{"schedule_view_before": {}, "schedule_view_after": {}}),
		"invalid_condition_departure_candidate", "a missing candidate member")
	var widened := _condition_candidate(_empty_view(3), _empty_view(3), "cond-x")
	widened["extra"] = true
	_refused(controller.commit_condition_departure_transition(widened),
		"invalid_condition_departure_candidate", "an extra candidate member")


func test_a_non_dictionary_transition_receipt_is_refused() -> void:
	var controller := _open(3)
	var candidate := _condition_candidate(_empty_view(3), _empty_view(3), "cond-x")
	candidate["schedule_view_commit_receipt"] = "not-a-receipt"
	_refused(controller.commit_condition_departure_transition(candidate),
		"invalid_condition_departure_receipt", "a primitive commit receipt")


func test_an_invalid_after_view_is_refused_without_mutation() -> void:
	var controller := _open(3)
	_add(controller, "rest", null, 0, "d-rest")
	var before_view := _view_of(controller)
	var after_view: Dictionary = before_view.duplicate(true)
	after_view["route_plan"] = []
	var candidate := _condition_candidate(before_view, after_view, "cond-bad")
	_refused(controller.commit_condition_departure_transition(candidate),
		"invalid_schedule_view", "an invalid after-view")
	assert_eq(_canonical(_view_of(controller)), _canonical(before_view),
		"a refused transition mutates nothing")
	_refused(controller.lookup_condition_departure_receipt("cond-bad"),
		"condition_departure_receipt_not_found", "nothing was appended")


func test_configure_refuses_null_dependencies() -> void:
	var no_registry: Object = CONTROLLER.new()
	_refused(no_registry.configure(null, RULES, _fingerprint), "invalid_registry",
		"a null registry")
	var no_rules: Object = CONTROLLER.new()
	_refused(no_rules.configure(_registry, null, _fingerprint), "invalid_schedule_rules",
		"null ScheduleRules")
	var no_fingerprint: Object = CONTROLLER.new()
	_refused(no_fingerprint.configure(_registry, RULES, ""), "invalid_expected_fingerprint",
		"a blank fingerprint")
