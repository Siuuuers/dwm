extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

# Plan 01 matrix conformance for the presentation producer (dwm-p2r.18, Step 8.1's negative half).
#
# WHAT THIS FILE OWNS, and why it is not a duplicate of the port suites. The port suites prove the
# PORT validates what it is handed. The resume suite proves the producer is deterministic across a
# crash. Neither proves the producer emits the bytes the MATRIX specifies -- a producer that omitted
# `source_day` from its projection, or sorted `input_receipt_ids` differently, would sail through
# both of them, and would then fork the identity chain the moment anyone else derived the same row.
#
# HOW IT AVOIDS TESTING THE IMPLEMENTATION AGAINST ITSELF. Every expectation below is built from
# plan lines 97, 98 and 100 read as text, not from the producer's code path. The test constructs the
# exact `P(path,value)` token set the matrix names, asks the SAME issuer to derive a child from it,
# and requires the resulting child id to equal the one the producer actually put in the request.
# `derive_child` is a deterministic function of (parent, kind, ordinal, sorted sources), so equal
# ids mean the two projections agreed member for member. A missing, extra, renamed, reordered or
# differently serialised member cannot survive that comparison.
#
# THE LOAD-BEARING SWEEP. For each named member in turn, the same derivation is repeated with that
# ONE member perturbed and the child id is required to CHANGE. This is what catches an omitted
# projection member: if `stage_index` were silently absent from the producer's token set, mutating
# it would leave the derived id untouched and the exact-match test above would still pass.
#
# WHERE THE INDEPENDENCE STOPS, named rather than assumed. ONE value cannot be rebuilt from the
# plan text: a timeline locator, because the plan requires the locator to be REGISTERED in
# `DialogicTimelineCatalog` but never constructs one. The locators are therefore named as literal
# constants below instead of read off the request.
#
# The `P01.hospital.miss` child ids carried inside the Hospital context used to be a second
# exception -- the one deliberate read-back this file carried -- because rebuilding them meant
# deriving two matrix rows this suite did not cover. They are now derived from plan lines 94 and 95
# like everything else, and those two rows carry their own conformance and sweep tests. Nothing in
# this file is read back off the producer any more.
#
# SUBSTRATE. Real throughout -- GUID-isolated root, real DesktopIssuerRootStore over real
# JsonFileStorage, the real DesktopIdentityNonceIssuer, the production ScheduleActionRegistry, the
# real GameStateScheduleCommitPort, a real GameState in the tree. The only fixture is the Plan-02
# desktop-consequence source, authorised by plan line 532 until Plan 02 exists.

const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CONSEQUENCE_SOURCE := preload("res://tests/support/FakeDesktopConsequenceSource.gd")
const STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const MINESWEEPER_PORT := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd")

const CAUSAL_DAY := "causal_day_instance.6666666666666666666666666666666666666666666666666666666666666666"
const VIEW_FINGERPRINT := "schedule_view.66666666666666666666666666666666"
const MAX_WALK_STEPS := 40

## Plan line 97 / 98: the exact child kind both presentation rows derive under.
const PRESENTATION_CHILD_KIND := &"day_resolution_stage"
## Plan lines 94 / 95: the child kinds the two Hospital ancestry rows derive under.
const HOSPITAL_RESOLUTION_CHILD_KIND := &"hospital_resolution"
const HOSPITAL_MISS_CHILD_KIND := &"hospital_miss"
## Plan line 95: the one reason a Hospital supersession records.
const MISS_REASON := "prevented_by_fainting"
## Plan line 94: at most one Hospital aggregate hangs off the resolution root.
const HOSPITAL_RESOLUTION_ORDINAL := 0
## Plan line 100: the frozen D1-6 stage array positions `stage_index` names.
const HOSPITAL_STAGE_INDEX := 4
const DATES_STAGE_INDEX := 5
const PAIR_STAGE_INDEX := 6
## Plan line 100: the deferred pair's own stage name, which is also its `stage_name` member.
const PAIR_STAGE := "twofriends_if_deferred"
## The registered locators for the two scenarios below. `DialogicTimelineCatalog` is their only
## authority -- the plan text does not construct a locator -- so they are named here as literals
## rather than read back off the request the producer built.
const DATE_TIMELINE_ID := "dating.solo.lavinia.day3.pre_challenge"
const PAIR_TIMELINE_ID := "dating.twofriends.priscilla_lavinia.day2.pre_challenge"
const HOSPITAL_TIMELINE_ID := "hospital.faint"

var _root := ""
var _root_counter := 0
var _registry: RefCounted
var _fingerprint := ""
var _issuer: RefCounted
var _game_state: Node
var _state_port: RefCounted
var _consequence: RefCounted
var _commands: Dictionary = {}


func before_each() -> void:
	_commands = {}
	_root = ""
	_root_counter += 1
	var result: Dictionary = TEMPORARY_STORAGE.create("presentation-matrix-%d" % _root_counter)
	assert_true(result.get("ok", false), result.get("message", ""))
	if not result.get("ok", false):
		return
	_root = str(result["value"])

	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	var storage := JsonFileStorage.new(_root)
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(store).get("ok", false))

	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()

	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	_state_port = STATE_PORT.new(_game_state)
	_consequence = CONSEQUENCE_SOURCE.new()
	assert_true(_consequence.configure(_issuer).get("ok", false))
	assert_true(_state_port.configure_desktop_consequence_source(_consequence).get("ok", false))
	assert_true(_state_port.configure_resolution_identity(
		_issuer, START_PORT.new(_state_port, _registry, _issuer, ledger)).get("ok", false))


# -------------------------------------------------------------------------------------------------
# Plan line 100: the exact variant discriminator tuples
# -------------------------------------------------------------------------------------------------

## Line 100 freezes `(presentation_kind, stage_name, route_id, schedule_entry_id,
## input_receipt_ids)` per variant. A producer that got any one of these wrong would derive a
## well-formed child under the wrong row, which is exactly the failure a shape-only check misses.
func test_the_surviving_date_variant_carries_its_exact_discriminator_tuple() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var entry := _committed_entry_at(0)
	assert_eq(str((request["context"] as Dictionary)["kind"]), "solo",
		"presentation_kind is the registry-owned action kind")
	assert_eq(str(request["route_id"]), "dating", "a date routes to dating")
	assert_eq(str((request["context"] as Dictionary)["schedule_entry_id"]),
		str(entry["schedule_entry_id"]), "schedule_entry_id is nonnull for a date")
	assert_eq(str(request["timeline_id"]), DATE_TIMELINE_ID,
		"the locator is the registered pre-challenge timeline for this friend and day")


func test_the_hospital_variant_carries_its_exact_discriminator_tuple() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var request := _await_presentation()
	if request.is_empty():
		return
	var context: Dictionary = request["context"]
	assert_eq(str(context["kind"]), "hospital", "presentation_kind is hospital")
	assert_eq(str(request["route_id"]), "hospital", "Hospital routes to hospital")
	assert_eq(str(request["timeline_id"]), HOSPITAL_TIMELINE_ID, "the frozen Hospital locator")
	assert_true(context.has("source_entry_ids") and context.has("miss_receipt_ids"),
		"the Hospital context is the four-member Hospital shape, not the Dating shape")
	assert_false(context.has("schedule_entry_id"),
		"schedule_entry_id is null for Hospital, so it is absent from the Hospital context")


## Line 100: `L([condition_receipt_id] + hospital_miss_receipt_ids)` -- so the Hospital source set
## contains the condition id EVEN WHEN there are no misses, and is flattened, unique and sorted.
func test_the_hospital_source_set_contains_the_condition_id_with_and_without_misses() -> void:
	if _root.is_empty():
		return
	# WITH a miss: one committed date that Hospital supersedes.
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var with_miss := _await_presentation()
	if with_miss.is_empty():
		return
	var condition_id := _condition_receipt_id(3)
	var miss_ids: Array = (with_miss["context"] as Dictionary)["miss_receipt_ids"]
	assert_eq(miss_ids.size(), 1, "the one superseded date produced exactly one miss child")
	var expected_with := _sorted_unique([condition_id] + miss_ids)
	assert_eq(_intent_input_receipt_ids(with_miss), expected_with,
		"input_receipt_ids is exactly L([condition_receipt_id] + hospital_miss_receipt_ids)")
	assert_true(condition_id in expected_with, "the condition id is a member")


func test_a_hospital_with_no_committed_date_still_names_its_condition_id() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_ordinary("w1", 0, "working", 3)])
	_game_state.pending_hospital = true
	var request := _await_presentation()
	if request.is_empty():
		return
	assert_eq(((request["context"] as Dictionary)["miss_receipt_ids"] as Array).size(), 0,
		"no committed date means no miss child")
	assert_eq(_intent_input_receipt_ids(request), [_condition_receipt_id(3)],
		"the set is still exactly the condition id -- L() flattens a concatenation, "
			+ "so an empty miss list does not empty the set")


# -------------------------------------------------------------------------------------------------
# Plan lines 94 and 95: exact conformance and the load-bearing sweep, for the Hospital ancestry
# -------------------------------------------------------------------------------------------------

## THE TEST THAT CLOSES THE READ-BACK. The Hospital context carries `P01.hospital.miss` child ids,
## and until now this suite took them off the request because rebuilding them meant deriving two
## matrix rows it did not cover. Both are rebuilt here from plan text: line 94's nine members for
## the aggregate, then line 95's nine for each miss -- and because line 95 projects
## `hospital_resolution_id`, an aggregate that disagreed with line 94 could not produce miss ids
## that match. So this single equality is conformance for BOTH rows at once.
func test_the_hospital_ancestry_children_are_exactly_the_matrix_rows() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var request := _await_presentation()
	if request.is_empty():
		return
	var produced: Array = (request["context"] as Dictionary)["miss_receipt_ids"]
	assert_eq(produced.size(), 1, "the one committed date Hospital superseded produced one miss")
	assert_eq(_derived_hospital_miss_ids(), produced,
		"the producer's P01.hospital.miss children are byte-for-byte the line-95 rows, "
			+ "derived under a line-94 aggregate this test rebuilt independently")


## The miss ordinal is POSITIONAL -- line 95 words it as the index among the superseded dates in
## committed `slot_index` order. Two dates make that visible: swapping the two derived ids must not
## still match, or an implementation that ordered misses by anything else would pass unnoticed.
func test_the_hospital_miss_ordinal_follows_committed_slot_order() -> void:
	if _root.is_empty():
		return
	# Day 6, because that is the day the registry carries a solo action for BOTH friends; day 3 has
	# only lavinia, so it cannot produce the two misses this ordinal check needs.
	_commit_and_begin(6, [
		_date("d-lav", 0, "lavinia", 6),
		_date("d-pri", 1, "priscilla", 6),
	])
	_game_state.pending_hospital = true
	var request := _await_presentation()
	if request.is_empty():
		return
	var produced: Array = (request["context"] as Dictionary)["miss_receipt_ids"]
	assert_eq(produced.size(), 2, "both committed dates were superseded")
	var derived := _derived_hospital_miss_ids()
	assert_eq(_sorted_unique(derived), produced,
		"both miss children reproduce at their own slot-order ordinals")
	var swapped: Array = [derived[1], derived[0]]
	assert_ne(swapped, derived,
		"the two ordinals genuinely produce different children, so the order is load-bearing")


## The sweep for line 94. Each of the nine aggregate members is perturbed alone, and the MISS ids
## must move -- they bind the aggregate through `hospital_resolution_id`, so this is the only
## externally visible consequence of an aggregate that projected different bytes.
func test_every_projected_hospital_resolution_member_is_load_bearing() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_hospital_resolution_projection()
	var baseline := _derived_hospital_resolution_id()
	var entry := (_hospital_dates_in_slot_order()[0] as Dictionary)
	var baseline_miss := _derive(_root_receipt_id(), HOSPITAL_MISS_CHILD_KIND, 0,
		_tokens(_expected_hospital_miss_projection(entry, baseline)))
	assert_eq([baseline_miss], (request["context"] as Dictionary)["miss_receipt_ids"],
		"the baseline aggregate is the real one")
	for index: int in range(projection.size()):
		var mutated := _mutate_member(projection, index)
		var path := str((projection[index] as Array)[0])
		var moved := _derive(_root_receipt_id(), HOSPITAL_RESOLUTION_CHILD_KIND,
			HOSPITAL_RESOLUTION_ORDINAL, _tokens(mutated))
		assert_ne(moved, baseline,
			"mutating %s must change the aggregate: it is a projected member" % path)
		assert_ne(_derive(_root_receipt_id(), HOSPITAL_MISS_CHILD_KIND, 0,
			_tokens(_expected_hospital_miss_projection(entry, moved))), baseline_miss,
			"and must carry through to the miss child that binds it: %s" % path)


## The sweep for line 95, plus the parent and ordinal the derivation request owns rather than the
## source set.
func test_every_projected_hospital_miss_member_is_load_bearing() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var request := _await_presentation()
	if request.is_empty():
		return
	var entry := (_hospital_dates_in_slot_order()[0] as Dictionary)
	var projection := _expected_hospital_miss_projection(entry, _derived_hospital_resolution_id())
	var baseline := _derive(_root_receipt_id(), HOSPITAL_MISS_CHILD_KIND, 0, _tokens(projection))
	assert_eq([baseline], (request["context"] as Dictionary)["miss_receipt_ids"],
		"the baseline projection is the real row")
	for index: int in range(projection.size()):
		var mutated := _mutate_member(projection, index)
		var path := str((projection[index] as Array)[0])
		assert_ne(_derive(_root_receipt_id(), HOSPITAL_MISS_CHILD_KIND, 0, _tokens(mutated)),
			baseline, "mutating %s must change the derived child: it is a projected member" % path)

	var other_root: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(other_root.get("ok", false), str(other_root))
	var foreign_parent := str(((other_root["value"] as Dictionary)["issuer_receipt"] as Dictionary)["receipt_id"])
	assert_ne(_derive(foreign_parent, HOSPITAL_MISS_CHILD_KIND, 0, _tokens(projection)), baseline,
		"a miss under another resolution root is a different child")
	assert_ne(_derive(_root_receipt_id(), HOSPITAL_MISS_CHILD_KIND, 1, _tokens(projection)),
		baseline, "the same bytes at another ordinal are a different child")
	assert_ne(_derive(_root_receipt_id(), HOSPITAL_RESOLUTION_CHILD_KIND, 0, _tokens(projection)),
		baseline, "the same bytes under the aggregate kind are a different child")


# -------------------------------------------------------------------------------------------------
# Plan line 97: exact conformance and the load-bearing sweep, for the intent
# -------------------------------------------------------------------------------------------------

## THE CENTRAL TEST. The 13 members of line 97 are rebuilt here from the plan text and derived
## through the same issuer; the resulting child id must equal the one the producer emitted.
func test_the_intent_child_is_exactly_the_matrix_row_p01_presentation_intent() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_date_intent_projection(3, 0, DATE_TIMELINE_ID)
	var derived := _derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection))
	assert_eq(derived, str(request["substage_id"]),
		"the producer's P01.presentation.intent child is byte-for-byte the matrix row")


## The sweep. Each of the 13 members is perturbed alone; every one must move the child id.
func test_every_projected_intent_member_is_load_bearing() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_date_intent_projection(3, 0, DATE_TIMELINE_ID)
	var baseline := _derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection))
	assert_eq(baseline, str(request["substage_id"]), "the baseline projection is the real row")
	for index: int in range(projection.size()):
		var mutated := _mutate_member(projection, index)
		var path := str((projection[index] as Array)[0])
		assert_ne(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(mutated)),
			baseline, "mutating %s must change the derived child: it is a projected member" % path)


## Parent and ordinal are part of the derivation request rather than the source set, so they need
## their own check: a child derived under another root, or at another ordinal, must differ.
func test_the_intent_parent_and_ordinal_are_load_bearing() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var tokens := _tokens(_expected_date_intent_projection(3, 0, DATE_TIMELINE_ID))
	var baseline := _derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, tokens)
	assert_eq(baseline, str(request["substage_id"]))

	var other_root: Dictionary = _issuer.issue(&"transaction_id")
	assert_true(other_root.get("ok", false), str(other_root))
	var foreign_parent := str(((other_root["value"] as Dictionary)["issuer_receipt"] as Dictionary)["receipt_id"])
	assert_ne(_derive(foreign_parent, PRESENTATION_CHILD_KIND, 0, tokens), baseline,
		"a child under another resolution root is a different child")
	assert_ne(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 1, tokens), baseline,
		"the same bytes at another ordinal are a different child")


## Source ORDER is owned by the issuer's sort, not by the producer. Handing the same members in a
## different order must reach the same child -- otherwise two honest producers of the same row
## would disagree purely on iteration order.
func test_the_source_set_is_order_independent_but_membership_is_not() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_date_intent_projection(3, 0, DATE_TIMELINE_ID)
	var baseline := _derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection))
	var reversed_projection: Array = projection.duplicate()
	reversed_projection.reverse()
	assert_eq(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(reversed_projection)),
		baseline, "S(...) sorts, so member ORDER cannot change the identity")

	var dropped: Array = projection.duplicate()
	dropped.remove_at(0)
	assert_ne(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(dropped)), baseline,
		"but dropping a member does change it")


# -------------------------------------------------------------------------------------------------
# Plan line 98 / 100: the completion row, and the prerequisite it binds
# -------------------------------------------------------------------------------------------------

## Line 98's 7 members, rebuilt from the plan text. The provenance travels in the request, so this
## one compares the stored `source_ids` directly rather than by re-derivation.
func test_the_completion_child_is_exactly_the_matrix_row_p01_presentation_completion() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var provenance: Dictionary = request["completion_transaction_provenance"]
	assert_eq(str(provenance["child_kind"]), String(PRESENTATION_CHILD_KIND))
	assert_eq(str(provenance["parent_receipt_id"]), _root_receipt_id(),
		"the completion hangs off the resolution root, like its intent")
	assert_eq(int(provenance["ordinal"]), 0,
		"line 98: the SAME within-stage ordinal its intent used")
	assert_eq(str(provenance["child_id"]), str(request["completion_transaction_id"]),
		"the id agrees with its own provenance")
	assert_eq(provenance["source_ids"], _tokens(_expected_completion_projection(
			_expected_date_intent_projection(3, 0, DATE_TIMELINE_ID), 0)),
		"the completion source set is exactly line 98's 7 members")


## Line 100: "the completion projection binds its prerequisite without including itself." So
## `substage_id` is the INTENT child id, and the completion id itself never appears.
func test_the_completion_binds_its_intent_and_never_includes_itself() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var intent_id := str(request["substage_id"])
	var completion_id := str(request["completion_transaction_id"])
	assert_ne(intent_id, completion_id, "the two rows are distinct children")
	var sources: Array = (request["completion_transaction_provenance"] as Dictionary)["source_ids"]
	var joined := "\n".join(PackedStringArray(sources))
	assert_true(joined.contains(intent_id),
		"the completion names its intent, so it cannot be derived before the intent exists")
	assert_false(joined.contains(completion_id),
		"and never names itself")


## Line 100 names the TOP-LEVEL `P01.day_resolution.stage` child, and explicitly distinguishes a
## top-level row (`role="day_resolution.stage"`) from an entry-substage row
## (`role="day_resolution.entry_substage"`). A surviving date is the one variant driven from a
## substage cursor, so it is the one variant where the two ids differ -- and it projected the
## substage id until this was caught. Hospital and the deferred pair are top-level stages, so they
## are correct by shape rather than by rule.
func test_the_completion_names_the_top_level_stage_and_not_the_entry_substage() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var top_level := _top_level_stage_transaction_id("execute_schedule_dates")
	var substage := _surviving_date_substage_transaction_id()
	assert_ne(top_level, substage,
		"the two ids genuinely differ here, so this test can tell them apart")
	assert_eq(str(request["stage_id"]), top_level,
		"line 100: stage_id is the exact top-level P01.day_resolution.stage child id")
	assert_ne(str(request["stage_id"]), substage,
		"and never the entry substage the surviving-date presentation is driven from")


func test_every_projected_completion_member_is_load_bearing() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_completion_projection(
		_expected_date_intent_projection(3, 0, DATE_TIMELINE_ID), 0)
	var baseline := str(request["completion_transaction_id"])
	assert_eq(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection)),
		baseline, "the baseline projection is the real completion row")
	for index: int in range(projection.size()):
		var mutated := _mutate_member(projection, index)
		var path := str((projection[index] as Array)[0])
		assert_ne(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(mutated)),
			baseline, "mutating %s must change the completion child" % path)


# -------------------------------------------------------------------------------------------------
# Reject before physical start or stage mutation
# -------------------------------------------------------------------------------------------------

## Step 8.1 requires rejection "before physical start/stage mutation". With no Plan-02 consequence
## source there is no lawful root, so the producer must refuse with the stage still PENDING -- not
## begin it, not present anything, and not complete it with an empty envelope.
func test_an_underivable_presentation_refuses_with_the_stage_still_pending() -> void:
	if _root.is_empty():
		return
	var bare_port: RefCounted = STATE_PORT.new(_game_state)
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)], bare_port)
	# Walk the UNCONFIGURED port to the date substage; every earlier stage resolves normally.
	var steps := 0
	while steps < MAX_WALK_STEPS:
		steps += 1
		var cursor: Dictionary = bare_port.inspect_next_stage()
		assert_true(cursor.get("ok", false) and bool(cursor["value"]["has_stage"]),
			"the walk still has work")
		if not cursor.get("ok", false):
			return
		var record: Dictionary = cursor["value"]["stage"]
		if str(record.get("substage_id", "")).begins_with("surviving_date:"):
			var refused: Dictionary = bare_port.begin_next_stage()
			assert_false(refused.get("ok", true), "an underivable presentation refuses")
			assert_eq(str(refused.get("code", "")), "presentation_intent_unavailable",
				"and names the missing Plan-02 input rather than failing obscurely")
			assert_eq(_active_plan()["resolution_issuer_receipt"], null,
				"the resolution genuinely persisted no root, which is why nothing is derivable")
			var state := _substage_state(str(record["substage_id"]))
			assert_eq(state, "pending",
				"the stage is left PENDING: refusal happened before any stage mutation")
			return
		var begun: Dictionary = bare_port.begin_next_stage()
		assert_true(begun.get("ok", false), JSON.stringify(begun))
		if not begun.get("ok", false):
			return
		var receipt: Dictionary = (begun["value"] as Dictionary)["receipt"]
		assert_true(_game_state._run_lifecycle.complete_active_stage(
			str((begun["value"] as Dictionary)["stage"]["transaction_id"]),
			{"value": (receipt["value"] as Dictionary).duplicate(true)}).get("ok", false))
	assert_true(false, "the walk never reached the date substage")


# -------------------------------------------------------------------------------------------------
# expected projections, built from the plan text
# -------------------------------------------------------------------------------------------------

## Line 97's 13 members for a surviving-date intent, as [path, value] pairs in the plan's order.
##
## NOTHING HERE IS READ OUT OF THE PRODUCER'S REQUEST. It used to take the entry, the locator and
## the context straight off the request, which made those members agree with the producer by
## construction. `entry` is now the surviving committed date at line 97's own ordinal, `timeline_id`
## is the locator the caller expects (`DialogicTimelineCatalog` is its only authority; the plan text
## does not construct it), and the context is rebuilt to the exact Dating shape plan line 1147
## freezes -- so a producer that hashed different context bytes cannot be matched by an expectation
## that hashed those same bytes back.
func _expected_date_intent_projection(source_day: int, ordinal: int,
		timeline_id: String) -> Array:
	var plan := _active_plan()
	var start: Dictionary = plan["day_resolution_start_receipt"]
	var entry := _surviving_date_at(ordinal)
	return [
		["role", "presentation.intent"],
		["resolution_id", str(plan["resolution_id"])],
		["causal_day_instance", str(start["causal_day_instance"])],
		["source_day", source_day],
		["day_resolution_start_receipt_id", str(start["receipt_id"])],
		["stage_name", "execute_schedule_dates"],
		["stage_index", DATES_STAGE_INDEX],
		["presentation_kind", str(entry["action_kind"])],
		["schedule_entry_id", str(entry["schedule_entry_id"])],
		["route_id", "dating"],
		["timeline_id", timeline_id],
		["context_sha256", _sha256(
			_expected_dating_context(str(entry["action_kind"]), source_day, entry))],
		["input_receipt_ids", _sorted_unique([
			str(entry["schedule_entry_id"]), str(entry["source_receipt_id"])])],
	]


## Plan line 1147: the Dating context is exactly
## `{kind,day:int,schedule_entry_id:String|null,participants:Array[String]}`, and the P-L pair keeps
## its invitation-owned `priscilla,lavinia` order.
func _expected_dating_context(kind: String, day: int, entry: Dictionary) -> Dictionary:
	var participants: Array[String] = []
	if kind == "group" or kind == PAIR_STAGE:
		participants = ["priscilla", "lavinia"]
	else:
		for participant: Variant in (entry["participants"] as Array):
			participants.append(str(participant))
	return {"kind": kind, "day": day,
		"schedule_entry_id": str(entry["schedule_entry_id"]), "participants": participants}


## Line 97's surviving-date ordinal read as the plan states it -- the index among the SURVIVING
## committed dates in `slot_index` order -- rather than the request's word for which entry the
## producer chose.
func _surviving_date_at(ordinal: int) -> Dictionary:
	var superseded := _hospital_superseded_entry_ids()
	var dates: Array = []
	for entry_value: Variant in ((_active_plan()["committed_schedule"] as Dictionary)["entries"] as Array):
		var entry: Dictionary = entry_value
		if not (str(entry["action_kind"]) in ["solo", "group"]):
			continue
		if str(entry["schedule_entry_id"]) in superseded:
			continue
		dates.append(entry)
	dates.sort_custom(func(left: Variant, right: Variant) -> bool:
		return int((left as Dictionary)["slot_index"]) < int((right as Dictionary)["slot_index"]))
	assert_true(ordinal < dates.size(),
		"the plan carries a surviving committed date at ordinal %d" % ordinal)
	return (dates[ordinal] as Dictionary) if ordinal < dates.size() else {}


## Line 98's 7 members, rebuilt from the plan rather than read back out of the producer.
##
## WHY THIS USED TO PROVE NOTHING. Every member except `role` was taken straight off the producer's
## own request, so the completion row could only ever agree with itself: a producer projecting the
## WRONG `stage_id` still matched, because the expectation moved with it. That is exactly how the
## surviving-date completion came to name its entry substage instead of the top-level stage line 100
## requires, and it is why the load-bearing sweep could not help -- perturbing a member sourced from
## the producer moves both sides of the comparison at once.
##
## Each member now has an independent source. `resolution_id` and `stage_id` are read out of the
## PERSISTED plan -- for `stage_id`, the top-level `P01.day_resolution.stage` record line 100 names.
## `substage_id` is the intent child RE-DERIVED here from line 97. `route_id`, `timeline_id` and
## `context_sha256` come from that same independently rebuilt intent projection, because line 100
## binds the completion to the intent it settles.
func _expected_completion_projection(intent_projection: Array, ordinal: int) -> Array:
	return [
		["role", "presentation.completion"],
		["resolution_id", str(_active_plan()["resolution_id"])],
		["stage_id", _top_level_stage_transaction_id(
			str(_projection_member(intent_projection, "stage_name")))],
		["substage_id", _derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, ordinal,
			_tokens(intent_projection))],
		["route_id", _projection_member(intent_projection, "route_id")],
		["timeline_id", _projection_member(intent_projection, "timeline_id")],
		["context_sha256", _projection_member(intent_projection, "context_sha256")],
	]


## The exact top-level `P01.day_resolution.stage` child id for `stage_name`, read out of the
## PERSISTED plan. A surviving date is driven from an ENTRY SUBSTAGE cursor, so the record the
## producer happens to be holding is NOT the top-level one line 100 names.
func _top_level_stage_transaction_id(stage_name: String) -> String:
	for stage_value: Variant in (_active_plan().get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage["stage_id"]) == stage_name:
			return str(stage["transaction_id"])
	assert_true(false, "the plan carries no top-level stage named " + stage_name)
	return ""


func _projection_member(projection: Array, path: String) -> Variant:
	for pair_value: Variant in projection:
		var pair: Array = pair_value
		if str(pair[0]) == path:
			return pair[1]
	assert_true(false, "the projection carries no member " + path)
	return null


## `S(...)`: the listed `P(path,value)` tokens sorted into strict ascending String order.
func _tokens(projection: Array) -> Array:
	var tokens: Array = []
	for pair_value: Variant in projection:
		var pair: Array = pair_value
		var canonical: Dictionary = STATE_SCHEMA.canonical_json(pair[1])
		assert_true(canonical.get("ok", false), "member is canonically representable: " + str(pair[0]))
		tokens.append(str(pair[0]) + "=" + str((canonical["value"] as Dictionary)["text"]))
	tokens.sort()
	return tokens


## Returns a copy of `projection` with member `index` changed and nothing else touched.
func _mutate_member(projection: Array, index: int) -> Array:
	var mutated: Array = projection.duplicate(true)
	var pair: Array = mutated[index]
	var value: Variant = pair[1]
	match typeof(value):
		TYPE_INT:
			pair[1] = int(value) + 1
		TYPE_ARRAY:
			var altered: Array = (value as Array).duplicate()
			altered.append("zzz.extra.member")
			pair[1] = altered
		_:
			pair[1] = str(value) + ".mutated"
	mutated[index] = pair
	return mutated


func _derive(parent_receipt_id: String, child_kind: StringName, ordinal: int,
		sources: Array) -> String:
	var derived: Dictionary = _issuer.derive_child({
		"parent_receipt_id": parent_receipt_id,
		"child_kind": child_kind,
		"ordinal": ordinal,
		"source_ids": sources.duplicate(),
	})
	assert_true(derived.get("ok", false), JSON.stringify(derived))
	if not derived.get("ok", false):
		return ""
	return str((derived["value"] as Dictionary)["child_id"])


# -------------------------------------------------------------------------------------------------
# walk / substrate helpers
# -------------------------------------------------------------------------------------------------

## Drives to the first presentation boundary and returns the producer's exact request.
func _await_presentation() -> Dictionary:
	var steps := 0
	while steps < MAX_WALK_STEPS:
		steps += 1
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false) or not bool(cursor["value"]["has_stage"]):
			assert_true(false, "the walk ended before any presentation")
			return {}
		var begun: Dictionary = _state_port.begin_next_stage()
		assert_true(begun.get("ok", false), JSON.stringify(begun))
		if not begun.get("ok", false):
			return {}
		var value: Dictionary = begun["value"]
		if str(value["mode"]) == "await_registered_command":
			return ((value["command"] as Dictionary)["presentation_request"] as Dictionary)
		var receipt: Dictionary = value["receipt"]
		assert_true(_game_state._run_lifecycle.complete_active_stage(
			str((value["stage"] as Dictionary)["transaction_id"]),
			{"value": (receipt["value"] as Dictionary).duplicate(true)}).get("ok", false))
	assert_true(false, "the walk stopped advancing before a presentation")
	return {}


func _active_plan() -> Dictionary:
	var plan: Variant = _game_state._run_lifecycle.to_dict()["active_resolution_plan"]
	return (plan as Dictionary) if typeof(plan) == TYPE_DICTIONARY else {}


func _root_receipt_id() -> String:
	var root: Variant = _active_plan().get("resolution_issuer_receipt")
	return str((root as Dictionary)["receipt_id"]) if typeof(root) == TYPE_DICTIONARY else ""


## Recovers `input_receipt_ids` by finding the one sorted-unique id set that reproduces the intent.
## Read back off the derivation rather than off a producer accessor, so the assertion is about the
## bytes that were actually anchored.
func _intent_input_receipt_ids(request: Dictionary) -> Array:
	var context: Dictionary = request["context"]
	if str(context["kind"]) != "hospital":
		return []
	var candidate := _sorted_unique(
		[_condition_receipt_id(int(_active_plan()["source_day"]))]
			+ _derived_hospital_miss_ids())
	var projection: Array = [
		["role", "presentation.intent"],
		["resolution_id", str(_active_plan()["resolution_id"])],
		["causal_day_instance", str((_active_plan()["day_resolution_start_receipt"] as Dictionary)["causal_day_instance"])],
		["source_day", int(_active_plan()["source_day"])],
		["day_resolution_start_receipt_id", str((_active_plan()["day_resolution_start_receipt"] as Dictionary)["receipt_id"])],
		["stage_name", "hospital_if_triggered"],
		["stage_index", HOSPITAL_STAGE_INDEX],
		["presentation_kind", "hospital"],
		["schedule_entry_id", null],
		["route_id", "hospital"],
		["timeline_id", HOSPITAL_TIMELINE_ID],
		["context_sha256", _sha256(_expected_hospital_context())],
		["input_receipt_ids", candidate],
	]
	assert_eq(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection)),
		str(request["substage_id"]),
		"the Hospital intent reproduces from line 97 with this exact input_receipt_ids set")
	return candidate


## Plan line 1147: the Hospital context is exactly
## `{kind:"hospital",day:int,source_entry_ids:Array[String],miss_receipt_ids:Array[String]}`, with
## both arrays sorted and unique because Hospital owns no semantic order for either.
##
## NO READ-BACK REMAINS. `miss_receipt_ids` are `P01.hospital.miss` child ids (plan line 95), and
## they are now DERIVED here from the plan text rather than read off the request, which is what
## closes the last deliberate read-back this file carried. Deriving them requires the
## `P01.hospital.resolution` row too, because line 95 projects `hospital_resolution_id`; both rows
## are built below and both are covered by their own conformance and sweep tests.
func _expected_hospital_context() -> Dictionary:
	var plan := _active_plan()
	var date_entry_ids: Array = []
	for entry_value: Variant in ((plan["committed_schedule"] as Dictionary)["entries"] as Array):
		var entry: Dictionary = entry_value
		if str(entry["action_kind"]) in ["solo", "group"]:
			date_entry_ids.append(str(entry["schedule_entry_id"]))
	return {"kind": "hospital", "day": int(plan["source_day"]),
		"source_entry_ids": _sorted_unique(date_entry_ids),
		"miss_receipt_ids": _sorted_unique(_derived_hospital_miss_ids())}


# -------------------------------------------------------------------------------------------------
# Plan lines 94 and 95: the Hospital ancestry rows, rebuilt from the plan text
# -------------------------------------------------------------------------------------------------

## The committed DATE entries in `slot_index` order -- the filtered, ordered list both Hospital rows
## are indexed against. Line 95 words the miss ordinal as the "index among all Hospital-superseded
## committed date entries in committed `slot_index` order", and Hospital supersedes every committed
## date, so this list IS that index. Rebuilt from the plan's own frozen aggregate, never from the
## producer's supersession receipt.
func _hospital_dates_in_slot_order() -> Array:
	var dates: Array = []
	for entry_value: Variant in ((_active_plan()["committed_schedule"] as Dictionary)["entries"] as Array):
		var entry: Dictionary = entry_value
		if str(entry["action_kind"]) in ["solo", "group"]:
			dates.append(entry.duplicate(true))
	dates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["slot_index"]) < int(right["slot_index"]))
	return dates


## Plan line 94's nine members for `P01.hospital.resolution`, in plan order.
func _expected_hospital_resolution_projection() -> Array:
	var plan := _active_plan()
	var start: Dictionary = plan["day_resolution_start_receipt"]
	var date_entry_ids: Array = []
	for entry_value: Variant in _hospital_dates_in_slot_order():
		date_entry_ids.append(str((entry_value as Dictionary)["schedule_entry_id"]))
	return [
		["role", "hospital.resolution"],
		["resolution_id", str(plan["resolution_id"])],
		["causal_day_instance", str(start["causal_day_instance"])],
		["source_day", int(plan["source_day"])],
		["day_resolution_start_receipt_id", str(start["receipt_id"])],
		["schedule_commit_receipt_id", plan.get("schedule_commit_receipt_id")],
		["condition_receipt_id", _condition_receipt_id(int(plan["source_day"]))],
		["date_schedule_entry_ids", date_entry_ids],
		["required", true],
	]


func _derived_hospital_resolution_id() -> String:
	return _derive(_root_receipt_id(), HOSPITAL_RESOLUTION_CHILD_KIND, HOSPITAL_RESOLUTION_ORDINAL,
		_tokens(_expected_hospital_resolution_projection()))


## Plan line 95's nine members for one `P01.hospital.miss`, in plan order.
func _expected_hospital_miss_projection(entry: Dictionary, hospital_resolution_id: String) -> Array:
	var plan := _active_plan()
	var start: Dictionary = plan["day_resolution_start_receipt"]
	return [
		["role", "hospital.miss"],
		["resolution_id", str(plan["resolution_id"])],
		["causal_day_instance", str(start["causal_day_instance"])],
		["source_day", int(plan["source_day"])],
		["hospital_resolution_id", hospital_resolution_id],
		["schedule_entry_id", str(entry["schedule_entry_id"])],
		["action_id", str(entry["action_id"])],
		["source_receipt_id", entry["source_receipt_id"]],
		["reason", MISS_REASON],
	]


## Every `P01.hospital.miss` child id, at its own line-95 ordinal, in that ordinal order.
func _derived_hospital_miss_ids() -> Array:
	var hospital_resolution_id := _derived_hospital_resolution_id()
	var ids: Array = []
	var dates := _hospital_dates_in_slot_order()
	for ordinal: int in range(dates.size()):
		ids.append(_derive(_root_receipt_id(), HOSPITAL_MISS_CHILD_KIND, ordinal,
			_tokens(_expected_hospital_miss_projection(
				dates[ordinal] as Dictionary, hospital_resolution_id))))
	return ids


## The condition receipt the producer consumed. The fixture caches per causal day, so asking it
## again returns the same record rather than minting a second one.
func _condition_receipt_id(source_day: int) -> String:
	var resolved: Dictionary = _consequence.resolve_condition_receipt({
		"causal_day_instance": CAUSAL_DAY, "source_day": source_day})
	assert_true(resolved.get("ok", false), str(resolved))
	return str(((resolved["value"] as Dictionary)["condition_receipt"] as Dictionary)["receipt_id"])


func _substage_state(substage_id: String) -> String:
	for stage_value: Variant in (_active_plan().get("stages", []) as Array):
		for substage_value: Variant in ((stage_value as Dictionary).get("substages", []) as Array):
			var substage: Dictionary = substage_value
			if str(substage["substage_id"]) == substage_id:
				return str(substage["state"])
	return ""


## The transaction id of the entry substage a surviving date is driven from -- the id line 100
## does NOT want in `stage_id`.
func _surviving_date_substage_transaction_id() -> String:
	for stage_value: Variant in (_active_plan().get("stages", []) as Array):
		for substage_value: Variant in ((stage_value as Dictionary).get("substages", []) as Array):
			var substage: Dictionary = substage_value
			if str(substage["substage_id"]).begins_with("surviving_date:"):
				return str(substage["transaction_id"])
	assert_true(false, "the plan carries no surviving_date substage")
	return ""


func _committed_entry_at(index: int) -> Dictionary:
	var entries: Array = (_active_plan()["committed_schedule"] as Dictionary)["entries"]
	return entries[index] as Dictionary


func _sha256(value: Variant) -> String:
	var hashed: Dictionary = STATE_SCHEMA.canonical_sha256(value)
	assert_true(hashed.get("ok", false), str(hashed))
	return str((hashed["value"] as Dictionary)["sha256"])


## `L(id...)`: nonblank, unique, strictly sorted.
func _sorted_unique(ids: Array) -> Array:
	var seen := {}
	var listed: Array = []
	for id_value: Variant in ids:
		var id_text := str(id_value)
		if id_text.is_empty() or seen.has(id_text):
			continue
		seen[id_text] = true
		listed.append(id_text)
	listed.sort()
	return listed


## `begin_port` decides WHICH port begins the resolution, because that is what decides whether a
## root is minted at all. Defaults to the configured port.
func _commit_and_begin(day: int, drafts: Array, begin_port: RefCounted = null) -> void:
	_game_state._lifecycle_set_playing_day(day)
	var storage := JsonFileStorage.new(_root)
	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	var commit_port: RefCounted = COMMIT_PORT.new(_game_state, _registry, _issuer, ledger)
	var command: Dictionary = _command("commit.day%d" % day)
	var prepared: Dictionary = commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	var value: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
	assert_true(commit_port.call(&"commit", value["game_state_candidate"]).get("ok", false))
	var opener: RefCounted = begin_port if begin_port != null else _state_port
	assert_true(opener.begin_or_resume(str(command["id"]) + ":resolution").get("ok", false))


func _date(draft_entry_id: String, slot_index: int, friend: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend, day]
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "solo",
		"participants": [friend],
		"source_receipt_id": _seed_solo_source(friend, day, action_id),
	}


func _ordinary(draft_entry_id: String, slot_index: int, action_id: String, day: int) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "ordinary",
		"participants": [],
		"source_receipt_id": null,
	}


func _seed_solo_source(friend_id: String, day: int, action_id: String) -> String:
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		_game_state.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	if not offered.get("ok", false):
		return ""
	var command: Dictionary = _command("open.%s.day%d" % [friend_id, day])
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	if not found.get("ok", false):
		return ""
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, day, command["id"], command["receipt"],
		_issuer, ((found["value"] as Dictionary)["record"] as Dictionary))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	_game_state.contacts = opened["value"]["candidate"]
	return str(opened["receipt"]["receipt_id"])


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


# -------------------------------------------------------------------------------------------------
# Plan line 100: the deferred-pair variant
# -------------------------------------------------------------------------------------------------

## Line 97 gives the deferred pair ordinal `0`; line 100 freezes its discriminator tuple as
## `("twofriends_if_deferred","twofriends_if_deferred","dating",schedule_entry_id,
## L(schedule_entry_id,source_receipt_id))`. Hospital and surviving-date are covered above; this is
## the third variant, driven end to end over the same real substrate.
##
## THE DEFERRAL IS PRODUCED BY THE REAL RESOLUTION, never written into state by hand. Plan line
## 1057 says Hospital "marks every committed date prevented_by_fainting ... completes recovery, then
## permits deferred pair presentation", so the pair is owed exactly when Hospital took its committed
## group entry away earlier in this same walk.
func test_hospital_supersession_is_what_owes_the_pair_a_presentation() -> void:
	if _root.is_empty():
		return
	var source_receipt_id := _seed_group_source(2)
	if source_receipt_id.is_empty():
		return
	_commit_and_begin(2, [_group_draft("g-pl", 0, 2, source_receipt_id)])
	_game_state.pending_hospital = true
	var request := _await_stage_presentation(PAIR_STAGE)
	if request.is_empty():
		return
	# The pair's own entry is the one Hospital superseded: the date stage could not run it, and
	# this stage is where it is finally presented.
	var superseded: Array = _hospital_superseded_entry_ids()
	assert_eq(superseded, [str(_committed_entry_at(0)["schedule_entry_id"])],
		"Hospital superseded exactly the committed pair entry")
	assert_eq(str((request["context"] as Dictionary)["schedule_entry_id"]), superseded[0],
		"and the deferred-pair presentation is for exactly that entry")


## The matrix row itself: ordinal 0, the Dating context shape, and
## `L(schedule_entry_id,source_receipt_id)`.
func test_the_deferred_pair_variant_carries_its_exact_matrix_row() -> void:
	if _root.is_empty():
		return
	var source_receipt_id := _seed_group_source(2)
	if source_receipt_id.is_empty():
		return
	_commit_and_begin(2, [_group_draft("g-pl", 0, 2, source_receipt_id)])
	_game_state.pending_hospital = true
	var request := _await_stage_presentation(PAIR_STAGE)
	if request.is_empty():
		return
	var entry := _committed_entry_at(0)
	var context: Dictionary = request["context"]

	assert_eq(str(context["kind"]), "twofriends_if_deferred",
		"presentation_kind is the deferred-pair discriminator, not the entry action_kind")
	assert_eq(str(request["route_id"]), "dating", "the deferred pair routes to dating")
	assert_eq(str(request["timeline_id"]), PAIR_TIMELINE_ID,
		"the registered deferred-pair locator")
	assert_eq(str(context["schedule_entry_id"]), str(entry["schedule_entry_id"]),
		"schedule_entry_id is nonnull and names the pair committed entry")
	assert_eq(context["participants"], ["priscilla", "lavinia"],
		"the Dating context carries the canonical pair")
	assert_false(context.has("miss_receipt_ids"),
		"the pair carries the Dating context shape, never the Hospital one")

	# Line 97's 13 members rebuilt from the plan text, at line 97's reserved ordinal 0, derived
	# through the SAME issuer the producer used.
	var projection := _expected_pair_intent_projection(entry, 2, PAIR_TIMELINE_ID)
	assert_eq(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection)),
		str(request["substage_id"]),
		"the deferred-pair intent is exactly line 97 at ordinal 0")

	# And every member of it is load-bearing, so a silently omitted one cannot hide here either.
	var baseline := str(request["substage_id"])
	for index: int in range(projection.size()):
		assert_ne(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0,
			_tokens(_mutate_member(projection, index))), baseline,
			"member is load-bearing: " + str((projection[index] as Array)[0]))


## dwm-p2r.28, the guard AGAINST over-refusal, GREEN ON ARRIVAL. The settle seam refuses stage
## transactions for never-presenting stages, and Hospital's own settles are pinned all over this
## file and the resume suite -- but nothing anywhere settled the deferred PAIR through the seam,
## so a gate narrowed to Hospital alone would have passed every existing test. This pin settles
## the pair's own stage transaction through the seam and holds its answer: the pair PRESENTS, so
## it is allowlisted, and the published completion is folded onto its envelope verbatim.
func test_the_deferred_pair_settles_through_the_presentation_seam() -> void:
	if _root.is_empty():
		return
	var source_receipt_id := _seed_group_source(2)
	if source_receipt_id.is_empty():
		return
	_commit_and_begin(2, [_group_draft("g-pl", 0, 2, source_receipt_id)])
	_game_state.pending_hospital = true
	var request := _await_stage_presentation(PAIR_STAGE)
	if request.is_empty():
		return
	var transaction_id := _active_stage_transaction_id()
	assert_true(transaction_id.ends_with(":" + PAIR_STAGE),
		"the walk really paused on the pair stage itself: " + transaction_id)

	var settled: Dictionary = _state_port.presentation_stage_receipt(
		transaction_id, {"receipt_id": str(request["completion_transaction_id"])})

	assert_true(settled.get("ok", false),
		"the deferred pair PRESENTS, so the seam answers it: " + JSON.stringify(settled))
	if not settled.get("ok", false):
		return
	var receipt: Dictionary = (settled["value"] as Dictionary)["receipt"]
	assert_eq((receipt["value"] as Dictionary).get("presentation_completion_receipt"),
		{"receipt_id": str(request["completion_transaction_id"])},
		"with the published completion folded on verbatim")


## dwm-p2r.30. The deferred pair PRESENTS AS A TOP-LEVEL STAGE, and its registered timelines
## carry the same pre_challenge/post_challenge split as every other dating kind -- the board
## between them IS the challenge -- yet `_resolve_dating_evidence` resolved only surviving_date
## SUBSTAGES, so a dating round could never begin during the pair presentation. With the walk
## genuinely paused on the pair stage, prepare_begin(dating) must stamp the pair's trusted
## evidence from the plan itself: the Hospital-superseded committed GROUP entry's id and
## participants, and the pair stage's own transaction. (The .23 superseded-date REFUSAL scopes
## to the substage branch by design: the pair is the PRESENTATION OF a superseded entry --
## refusing superseded entries here would refuse the pair's whole reason to exist.)
func test_a_dating_round_begins_during_the_deferred_pair_presentation() -> void:
	if _root.is_empty():
		return
	var source_receipt_id := _seed_group_source(2)
	if source_receipt_id.is_empty():
		return
	_commit_and_begin(2, [_group_draft("g-pl", 0, 2, source_receipt_id)])
	_game_state.pending_hospital = true
	var request := _await_stage_presentation(PAIR_STAGE)
	if request.is_empty():
		return
	var transaction_id := _active_stage_transaction_id()
	assert_true(transaction_id.ends_with(":" + PAIR_STAGE),
		"the walk really paused on the pair stage itself")
	var entry := _committed_entry_at(0)
	var port: RefCounted = MINESWEEPER_PORT.new(_game_state)

	var prepared: Dictionary = port.prepare_begin(
		{"context": "dating", "difficulty": "beginner"}, "run-1:day-2:pair-round-1")

	assert_true(prepared.get("ok", false),
		"the pair presentation hosts a board, so a dating round begins during it: "
		+ str(prepared))
	if not prepared.get("ok", false):
		return
	var evidence: Dictionary = ((prepared["value"] as Dictionary)["active_round"]
		as Dictionary)["dating_evidence"]
	assert_eq(str(evidence.get("entry_id", "")), str(entry["schedule_entry_id"]),
		"the entry is the superseded committed GROUP entry the pair presents")
	assert_eq(evidence.get("friend_ids"), ["priscilla", "lavinia"],
		"the friends are the frozen entry's participants, from the plan, not the request")
	assert_eq(str(evidence.get("route_transaction_id", "")), transaction_id,
		"the route transaction is the pair stage's own")


## dwm-p2r.30's stage-STATE law, GREEN ON ARRIVAL (the review-designed M2 killer). Only an
## ACTIVE pair stage hosts a board. After the pair settles through the seam and its stage
## COMPLETES, the presentation is over -- a dating round prepared then must be refused, or a
## board could open against a finished presentation whose superseded group entry still sits
## durably in the plan. (The owner-receipt gate has no twofriends case, so the settle receipt
## completes the stage exactly as the suite's own walker does.)
func test_no_dating_round_begins_after_the_pair_presentation_completes() -> void:
	if _root.is_empty():
		return
	var source_receipt_id := _seed_group_source(2)
	if source_receipt_id.is_empty():
		return
	_commit_and_begin(2, [_group_draft("g-pl", 0, 2, source_receipt_id)])
	_game_state.pending_hospital = true
	var request := _await_stage_presentation(PAIR_STAGE)
	if request.is_empty():
		return
	var transaction_id := _active_stage_transaction_id()
	var settled: Dictionary = _state_port.presentation_stage_receipt(
		transaction_id, {"receipt_id": str(request["completion_transaction_id"])})
	assert_true(settled.get("ok", false), "the settle must succeed first: " + str(settled))
	if not settled.get("ok", false):
		return
	var receipt: Dictionary = (settled["value"] as Dictionary)["receipt"]
	var completed: Dictionary = _game_state._run_lifecycle.complete_active_stage(
		transaction_id, {"value": (receipt["value"] as Dictionary).duplicate(true)})
	assert_true(completed.get("ok", false), "the pair stage completes: " + str(completed))

	var prepared: Dictionary = MINESWEEPER_PORT.new(_game_state).prepare_begin(
		{"context": "dating", "difficulty": "beginner"}, "run-1:day-2:pair-done-round")

	assert_false(prepared.get("ok", false),
		"a finished pair presentation hosts nothing: " + str(prepared))
	assert_eq(str(prepared.get("code", "")), "DATING_ROUTE_NOT_ACTIVE",
		"refused through the resolver's fail-closed door")


## dwm-p2r.23's trusted-source law one level up, GREEN ON ARRIVAL (the review-designed M5
## killer). The pair's friends come from the FROZEN committed entry inside the plan, never
## from live contacts -- whose default group_action record happens to name the same pair, so
## only a scrambled roster can tell the two sources apart. With live contacts claiming an
## impostor, the evidence still names the frozen pair.
func test_the_pair_evidence_ignores_scrambled_live_contacts() -> void:
	if _root.is_empty():
		return
	var source_receipt_id := _seed_group_source(2)
	if source_receipt_id.is_empty():
		return
	_commit_and_begin(2, [_group_draft("g-pl", 0, 2, source_receipt_id)])
	_game_state.pending_hospital = true
	var request := _await_stage_presentation(PAIR_STAGE)
	if request.is_empty():
		return
	var scrambled: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	(scrambled["group_action"] as Dictionary)["participant_ids"] = ["sylvia"]
	_game_state.contacts = scrambled

	var prepared: Dictionary = MINESWEEPER_PORT.new(_game_state).prepare_begin(
		{"context": "dating", "difficulty": "beginner"}, "run-1:day-2:pair-scramble-round")

	assert_true(prepared.get("ok", false), "the scramble is invisible: " + str(prepared))
	if not prepared.get("ok", false):
		return
	var evidence: Dictionary = ((prepared["value"] as Dictionary)["active_round"]
		as Dictionary)["dating_evidence"]
	assert_eq(evidence.get("friend_ids"), ["priscilla", "lavinia"],
		"the friends are the frozen entry's participants, whatever live contacts claim")


## The transaction id of the one ACTIVE top-level stage, read from the live plan.
func _active_stage_transaction_id() -> String:
	for stage_value: Variant in (_active_plan().get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("state", "")) == "active":
			return str(stage.get("transaction_id", ""))
	return ""


## Line 97's 13 members for a deferred-pair intent, as [path, value] pairs in the plan's order.
## Independent of the request for the same reason `_expected_date_intent_projection` is.
func _expected_pair_intent_projection(entry: Dictionary, source_day: int,
		timeline_id: String) -> Array:
	var plan := _active_plan()
	var start: Dictionary = plan["day_resolution_start_receipt"]
	return [
		["role", "presentation.intent"],
		["resolution_id", str(plan["resolution_id"])],
		["causal_day_instance", str(start["causal_day_instance"])],
		["source_day", source_day],
		["day_resolution_start_receipt_id", str(start["receipt_id"])],
		["stage_name", PAIR_STAGE],
		["stage_index", PAIR_STAGE_INDEX],
		["presentation_kind", "twofriends_if_deferred"],
		["schedule_entry_id", str(entry["schedule_entry_id"])],
		["route_id", "dating"],
		["timeline_id", timeline_id],
		["context_sha256", _sha256(_expected_dating_context(PAIR_STAGE, source_day, entry))],
		["input_receipt_ids", _sorted_unique([
			str(entry["schedule_entry_id"]), str(entry["source_receipt_id"])])],
	]


## Walks until the producer pauses on a presentation belonging to `stage_name`, completing every
## earlier stage normally. A pause on some EARLIER presentation is settled through the port's own
## envelope, so reaching the pair does not require the date stage to be empty.
func _await_stage_presentation(stage_name: String) -> Dictionary:
	var steps := 0
	while steps < MAX_WALK_STEPS:
		steps += 1
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false) or not bool(cursor["value"]["has_stage"]):
			return _walk_failed("the walk ended before the %s presentation" % stage_name)
		var begun: Dictionary = _state_port.begin_next_stage()
		if not begun.get("ok", false):
			return _walk_failed("a stage before %s refused: %s"
				% [stage_name, JSON.stringify(begun)])
		var value: Dictionary = begun["value"]
		var stage: Dictionary = value["stage"]
		if str(value["mode"]) == "await_registered_command":
			var request: Dictionary = (value["command"] as Dictionary)["presentation_request"]
			if str(stage["stage_id"]) == stage_name:
				return request
			var settled: Dictionary = _state_port.presentation_stage_receipt(
				str(stage["transaction_id"]),
				{"receipt_id": str(request["completion_transaction_id"])})
			if not settled.get("ok", false):
				return _walk_failed("an earlier presentation would not settle: "
					+ JSON.stringify(settled))
			var closed := _complete_walked_stage(stage, (settled["value"] as Dictionary)["receipt"])
			if not closed.get("ok", false):
				return _walk_failed("an earlier presentation stage would not complete: "
					+ JSON.stringify(closed))
			continue
		# The target stage came up and answered immediately: it derived no presentation at all.
		# Reported here rather than letting the walk run on to a stage this harness cannot satisfy,
		# so the failure names the missing presentation instead of some later casualty.
		if str(stage["stage_id"]) == stage_name:
			return _walk_failed("the %s stage completed with mode=%s and no presentation, so the"
				% [stage_name, str(value["mode"])]
				+ " producer derived no presentation intent for it")
		var advanced := _complete_walked_stage(stage, value["receipt"])
		if not advanced.get("ok", false):
			return _walk_failed("a stage before %s would not complete: %s"
				% [stage_name, JSON.stringify(advanced)])
	return _walk_failed("the walk stopped advancing before the %s presentation" % stage_name)


## ONE failure, ONE message. A walk that cannot reach its presentation is a single fact, and
## reporting it once per step buries that fact under repetition.
func _walk_failed(message: String) -> Dictionary:
	assert_true(false, message)
	return {}


func _complete_walked_stage(stage: Dictionary, receipt: Dictionary) -> Dictionary:
	return _game_state._run_lifecycle.complete_active_stage(
		str(stage["transaction_id"]),
		{"value": (receipt["value"] as Dictionary).duplicate(true)})


## One committed group draft for the canonical pair, on a group-window day.
func _group_draft(draft_entry_id: String, slot_index: int, day: int,
		source_receipt_id: String) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": "group:priscilla_lavinia:day%d" % day,
		"action_kind": "group",
		"participants": ["priscilla", "lavinia"],
		"source_receipt_id": source_receipt_id,
	}


## The supersession the Hospital stage DURABLY committed, read back out of its stage receipt --
## the same bytes the producer reads, not a recomputation.
func _hospital_superseded_entry_ids() -> Array:
	for stage_value: Variant in (_active_plan().get("stages", []) as Array):
		var stage: Dictionary = stage_value
		if str(stage.get("stage_id", "")) != "hospital_if_triggered":
			continue
		var receipt: Variant = stage.get("receipt")
		if typeof(receipt) != TYPE_DICTIONARY:
			return []
		return ((receipt as Dictionary)["value"] as Dictionary).get("superseded_entry_ids", [])
	return []


## Drives the canonical pair to ACCEPTED through the real Contacts owner and returns the exact
## acceptance receipt id a committed group entry must resolve to.
func _seed_group_source(day: int) -> String:
	var state: Dictionary = _game_state.contacts
	for participant: String in ["priscilla", "lavinia"]:
		var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
			state, participant, day, "offer.%s.day%d" % [participant, day],
			"solo.%s.day%d" % [participant, day])
		assert_true(offered.get("ok", false), str(offered))
		if not offered.get("ok", false):
			return ""
		state = offered["value"]["candidate"]
	var activated: Dictionary = CONTACT_STATE.prepare_activate_group_after_round(
		state, day, 2, 3, "group.activate.day%d" % day)
	assert_true(activated.get("ok", false), str(activated))
	if not activated.get("ok", false):
		return ""
	state = activated["value"]["candidate"]
	var action_id := "group:priscilla_lavinia:day%d" % day
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	if not found.get("ok", false):
		return ""
	var record: Dictionary = (found["value"] as Dictionary)["record"]
	var open_command := _command("group.open.day%d" % day)
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(state, "priscilla", day,
		open_command["id"], open_command["receipt"], _issuer, record)
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	state = opened["value"]["candidate"]
	var reply_command := _command("group.reply.day%d" % day)
	var replied: Dictionary = CONTACT_STATE.prepare_reply(state, "priscilla", day,
		reply_command["id"], reply_command["receipt"], _issuer, record)
	assert_true(replied.get("ok", false), str(replied))
	if not replied.get("ok", false):
		return ""
	_game_state.contacts = replied["value"]["candidate"]
	return str((replied["receipt"] as Dictionary)["receipt_id"])
