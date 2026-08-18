extends "res://addons/gut/test.gd"
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
const HOSPITAL_RULES := preload("res://scripts/domain/hospital/HospitalRules.gd")
const CONSEQUENCE_SOURCE := preload("res://tests/support/FakeDesktopConsequenceSource.gd")
const STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const CAUSAL_DAY := "causal_day_instance.6666666666666666666666666666666666666666666666666666666666666666"
const VIEW_FINGERPRINT := "schedule_view.66666666666666666666666666666666"
const MAX_WALK_STEPS := 40

## Plan line 97 / 98: the exact child kind both presentation rows derive under.
const PRESENTATION_CHILD_KIND := &"day_resolution_stage"
## Plan line 100: the frozen D1-6 stage array positions `stage_index` names.
const HOSPITAL_STAGE_INDEX := 4
const DATES_STAGE_INDEX := 5

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
	_root_counter += 1
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root = wrapper.path_join("presentation-matrix-%d" % _root_counter)
	assert_eq(DirAccess.make_dir_recursive_absolute(_root), OK)

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
	assert_eq(str(request["timeline_id"]), "dating.solo.lavinia.day3.pre_challenge",
		"the locator is the registered pre-challenge timeline for this friend and day")


func test_the_hospital_variant_carries_its_exact_discriminator_tuple() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	_game_state.pending_hospital = true
	var request := _await_presentation()
	if request.is_empty():
		return
	var context: Dictionary = request["context"]
	assert_eq(str(context["kind"]), "hospital", "presentation_kind is hospital")
	assert_eq(str(request["route_id"]), "hospital", "Hospital routes to hospital")
	assert_eq(str(request["timeline_id"]), "hospital.faint", "the frozen Hospital locator")
	assert_true(context.has("source_entry_ids") and context.has("miss_receipt_ids"),
		"the Hospital context is the four-member Hospital shape, not the Dating shape")
	assert_false(context.has("schedule_entry_id"),
		"schedule_entry_id is null for Hospital, so it is absent from the Hospital context")


## Line 100: `L([condition_receipt_id] + hospital_miss_receipt_ids)` -- so the Hospital source set
## contains the condition id EVEN WHEN there are no misses, and is flattened, unique and sorted.
func test_the_hospital_source_set_contains_the_condition_id_with_and_without_misses() -> void:
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
# Plan line 97: exact conformance and the load-bearing sweep, for the intent
# -------------------------------------------------------------------------------------------------

## THE CENTRAL TEST. The 13 members of line 97 are rebuilt here from the plan text and derived
## through the same issuer; the resulting child id must equal the one the producer emitted.
func test_the_intent_child_is_exactly_the_matrix_row_p01_presentation_intent() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_date_intent_projection(request, 3, 0)
	var derived := _derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection))
	assert_eq(derived, str(request["substage_id"]),
		"the producer's P01.presentation.intent child is byte-for-byte the matrix row")


## The sweep. Each of the 13 members is perturbed alone; every one must move the child id.
func test_every_projected_intent_member_is_load_bearing() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_date_intent_projection(request, 3, 0)
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
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var tokens := _tokens(_expected_date_intent_projection(request, 3, 0))
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
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_date_intent_projection(request, 3, 0)
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
	assert_eq(provenance["source_ids"], _tokens(_expected_completion_projection(request)),
		"the completion source set is exactly line 98's 7 members")


## Line 100: "the completion projection binds its prerequisite without including itself." So
## `substage_id` is the INTENT child id, and the completion id itself never appears.
func test_the_completion_binds_its_intent_and_never_includes_itself() -> void:
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


func test_every_projected_completion_member_is_load_bearing() -> void:
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var projection := _expected_completion_projection(request)
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
func _expected_date_intent_projection(request: Dictionary, source_day: int,
		ordinal: int) -> Array:
	var plan := _active_plan()
	var start: Dictionary = plan["day_resolution_start_receipt"]
	var entry := _committed_entry_by_id(str((request["context"] as Dictionary)["schedule_entry_id"]))
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
		["timeline_id", str(request["timeline_id"])],
		["context_sha256", _sha256(request["context"])],
		["input_receipt_ids", _sorted_unique([
			str(entry["schedule_entry_id"]), str(entry["source_receipt_id"])])],
	]


## Line 98's 7 members.
func _expected_completion_projection(request: Dictionary) -> Array:
	return [
		["role", "presentation.completion"],
		["resolution_id", str(request["resolution_id"])],
		["stage_id", str(request["stage_id"])],
		["substage_id", str(request["substage_id"])],
		["route_id", str(request["route_id"])],
		["timeline_id", str(request["timeline_id"])],
		["context_sha256", _sha256(request["context"])],
	]


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
		[_condition_receipt_id(int(context["day"]))] + (context["miss_receipt_ids"] as Array))
	var projection: Array = [
		["role", "presentation.intent"],
		["resolution_id", str(request["resolution_id"])],
		["causal_day_instance", str((_active_plan()["day_resolution_start_receipt"] as Dictionary)["causal_day_instance"])],
		["source_day", int(context["day"])],
		["day_resolution_start_receipt_id", str((_active_plan()["day_resolution_start_receipt"] as Dictionary)["receipt_id"])],
		["stage_name", "hospital_if_triggered"],
		["stage_index", HOSPITAL_STAGE_INDEX],
		["presentation_kind", "hospital"],
		["schedule_entry_id", null],
		["route_id", "hospital"],
		["timeline_id", str(request["timeline_id"])],
		["context_sha256", _sha256(request["context"])],
		["input_receipt_ids", candidate],
	]
	assert_eq(_derive(_root_receipt_id(), PRESENTATION_CHILD_KIND, 0, _tokens(projection)),
		str(request["substage_id"]),
		"the Hospital intent reproduces from line 97 with this exact input_receipt_ids set")
	return candidate


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


func _committed_entry_at(index: int) -> Dictionary:
	var entries: Array = (_active_plan()["committed_schedule"] as Dictionary)["entries"]
	return entries[index] as Dictionary


func _committed_entry_by_id(schedule_entry_id: String) -> Dictionary:
	for entry_value: Variant in ((_active_plan()["committed_schedule"] as Dictionary)["entries"] as Array):
		var entry: Dictionary = entry_value
		if str(entry["schedule_entry_id"]) == schedule_entry_id:
			return entry
	return {}


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
