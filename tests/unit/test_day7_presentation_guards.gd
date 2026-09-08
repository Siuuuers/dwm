extends "res://addons/gut/test.gd"

const BOARD := preload("res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd")
const SHOP := preload("res://scripts/application/shop/GameStateMinesweeperShopPort.gd")
const SCHEDULE := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const FOLLOWUPS := preload("res://scripts/domain/contact/Day7FollowupState.gd")
const PRESENTATION := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const CATALOG := preload("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd")

class State extends RefCounted:
	var pending := true
	var guard_calls := 0
	var day := 7
	var contacts: Dictionary = CONTACTS.make_defaults()
	var missed_invitations: Array = []
	var _run_lifecycle: RefCounted = RefCounted.new()
	func require_day7_presentations_complete() -> Dictionary:
		guard_calls += 1
		return {"ok": false, "code": &"day7_presentations_pending"} if pending else {"ok": true}
	func get_stat(_id: String) -> int: return 10
	func _canonical_committed_schedule() -> Dictionary: return {}
	func capture_schedule_commit_state() -> Dictionary: return {}
	func prepare_schedule_commit_candidate(_a: Dictionary, _b: int) -> Dictionary: return {}
	func commit_schedule_commit_candidate(_a: Dictionary) -> Dictionary: return {}
	func rollback_schedule_commit_state(_a: Dictionary) -> Dictionary: return {}
	func publish_schedule_commit(_a: Dictionary) -> Dictionary: return {}
	func get_contact_view(friend: String) -> Dictionary:
		return CONTACTS.get_contact_view(contacts, friend, day)

class Dependencies extends RefCounted:
	var mutations := 0
	func issue(_a: StringName) -> Dictionary:
		mutations += 1
		return {"ok": false}
	func fingerprint() -> String: return "fixture"
	func find_record(_a: String) -> Dictionary: return {}
	func verify_issued(_a: Dictionary, _b: StringName) -> Dictionary: return {}
	func derive_child(_a: Dictionary) -> Dictionary:
		mutations += 1
		return {}
	func validate_child(_a: Dictionary) -> Dictionary: return {}
	func record_before_emit(_a: Dictionary) -> Dictionary:
		mutations += 1
		return {}
	func request_open_contact(_friend: String, _guard: Callable) -> Dictionary:
		mutations += 1
		return {"ok": false}
	func request_reply_invitation(_friend: String) -> Dictionary:
		mutations += 1
		return {"ok": false}

class ResolutionProbe extends "res://scripts/application/run/GameStateDayResolutionPort.gd":
	var saved_plan: Dictionary = {}
	func _init(state: Object) -> void: super(state)
	func _active_plan() -> Dictionary: return saved_plan.duplicate(true)
	func _frozen_route_plan(_aggregate: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"reached_existing_resolution_validation"}

func test_stale_board_commands_require_presentations_before_any_board_work() -> void:
	var state := State.new()
	var dependency := Dependencies.new()
	var port := BOARD.new()
	assert_true(port.configure(state, dependency, {"run_id": "r", "branch_id": "b",
		"desktop_timeline_generation": 1, "causal_day_instance": "d"}).ok)
	for operation: StringName in [&"reveal", &"set_flag", &"chord", &"begin_debug_preparation", &"complete_round"]:
		assert_eq(port.guard_external(operation).code, &"day7_presentations_pending")
	assert_eq(dependency.mutations, 0)
	var before := state.contacts.duplicate(true)
	for operation: StringName in [&"resume", &"suspend"]:
		assert_true(port.guard_external(operation).ok, "visibility-only restoration may continue")
	assert_eq(state.contacts, before)
	assert_eq(dependency.mutations, 0)
	assert_eq(port.guard_external(&"reveal").code, &"day7_presentations_pending")
	state.pending = false
	assert_true(port.guard_external(&"reveal").ok)

func test_direct_shop_prepare_cannot_bypass_unused_external_guard() -> void:
	var state := State.new()
	var port := SHOP.new()
	assert_true(port.configure(state, {"run_id": "r", "branch_id": "b",
		"desktop_timeline_generation": 1, "causal_day_instance": "d"}).ok)
	assert_eq(port.prepare_purchase({}, {}, "stale", {}).code, &"day7_presentations_pending")
	state.pending = false
	assert_eq(port.prepare_purchase({}, {}, "stale", {}).code, &"invalid_transaction_issuer_receipt")

func test_direct_schedule_prepare_checks_before_memo_or_identity_derivation() -> void:
	var state := State.new()
	var dependency := Dependencies.new()
	var port := SCHEDULE.new(state, dependency, dependency, dependency)
	var request := {"causal_day_instance": "d", "day": 7, "draft_entries": [],
		"expected_view_fingerprint": "v", "registry_fingerprint": "fixture",
		"transaction_id": "stale", "transaction_issuer_receipt": {"token": "stale"}}
	port._prepared["stale"] = {"prepared": {"stale": true}}
	assert_eq(port.prepare_commit(request).code, &"day7_presentations_pending")
	assert_eq(dependency.mutations, 0)
	state.pending = false
	assert_eq(port.prepare_commit({}).code, &"invalid_schedule_commit_request")

func test_direct_done_blocks_day7_plan_but_allows_exact_prior_day_continuation() -> void:
	var state := State.new()
	var port := ResolutionProbe.new(state)
	assert_eq(port.begin_or_resume("new").code, &"day7_presentations_pending")
	port.saved_plan = {"command_id": "saved", "source_day": 7}
	assert_eq(port.begin_or_resume("saved").code, &"day7_presentations_pending")
	port.saved_plan["source_day"] = 6
	assert_eq(port.begin_or_resume("other").code, &"day7_presentations_pending")
	var before := state.guard_calls
	assert_eq(port.begin_or_resume("saved").code, &"reached_existing_resolution_validation")
	assert_eq(state.guard_calls, before, "only exact admitted prior-day continuation reaches existing validation")
	state.pending = false
	assert_eq(port.begin_or_resume("new").code, &"reached_existing_resolution_validation")

func _message(friend: String, sequence: int, kind: String = "missed_question", target_day: int = 7) -> Dictionary:
	return {"message_id": "%s:%s:day%d" % [kind, friend, target_day], "sequence": sequence,
		"type": kind, "variant": "default", "target_day": target_day, "parameters": {},
		"visibility": "visible", "transaction_id": "message:" + str(sequence)}

func test_due_query_is_finite_sorted_detached_and_uses_existing_acknowledged_read_law() -> void:
	var state := CONTACTS.make_defaults()
	state.messages.priscilla = [_message("priscilla", 8), _message("priscilla", 2, "nevermind", 3),
		_message("priscilla", 6, "solo_offer")]
	state.messages.lavinia = [_message("lavinia", 4, "judge"), _message("lavinia", 5, "busy")]
	state.messages.lavinia[1]["visibility"] = "superseded_hidden"
	state.messages.sylvia = [_message("sylvia", 3)]
	var before := state.duplicate(true)
	var rows := FOLLOWUPS.pending_day7_followups(state)
	assert_eq(rows.size(), 2)
	assert_eq(rows[0].friend_id, "lavinia")
	assert_eq(rows[1].message.sequence, 8)
	rows[0].message["variant"] = "mutated"
	assert_eq(state, before)
	state.read_watermarks.lavinia = 4
	assert_eq(FOLLOWUPS.pending_day7_followups(state).size(), 1)
	state.read_watermarks.priscilla = 8
	assert_true(FOLLOWUPS.pending_day7_followups(state).is_empty())

func test_cards_reuse_hospital_reactions_and_never_acknowledge_from_projection() -> void:
	var state := State.new()
	state.contacts.messages.priscilla = [_message("priscilla", 2)]
	state.contacts.messages.lavinia = [_message("lavinia", 1, "judge")]
	state.missed_invitations = [{"friend_id": "priscilla", "day": 6,
		"missed_reason": "hospital", "hospital_miss_receipt_id": "h"}]
	var dependency := Dependencies.new()
	var port := PRESENTATION.new()
	assert_true(port.configure(state, dependency, CATALOG.build()).ok)
	var before := state.contacts.duplicate(true)
	var result: Dictionary = port.get_day7_followup_cards("en", "zh-CN")
	assert_true(result.ok, str(result))
	if not result.ok: return
	var cards: Array = result.value.cards
	assert_eq(cards.size(), 2)
	assert_eq(cards[0].friend_id, "lavinia")
	assert_eq(cards[1].entries.size(), 3)
	assert_true(cards[1].entries[1].outgoing)
	assert_true(cards[1].entries[1].texts.en.contains("hospital"))
	assert_eq(state.contacts, before)
	assert_eq(dependency.mutations, 0)
	state.day = 6
	assert_true(port.get_day7_followup_cards().value.cards.is_empty())

func test_missing_card_translation_refuses_without_acknowledging_any_parent_message() -> void:
	var state := State.new()
	state.contacts.messages.priscilla = [_message("priscilla", 1)]
	var catalog := CATALOG.build()
	catalog["missed_question:priscilla:day7"].texts.erase("zh-CN")
	var port := PRESENTATION.new()
	assert_true(port.configure(state, Dependencies.new(), catalog).ok)
	var before := state.contacts.duplicate(true)
	assert_eq(port.get_day7_followup_cards("en", "zh-CN").code, &"contact_translation_unavailable")
	assert_eq(state.contacts, before)
