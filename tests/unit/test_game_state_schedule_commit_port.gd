extends "res://addons/gut/test.gd"
# Reversible committed-Schedule commit port (Plan 01 Task 4, dwm-p2r.13, Steps 4.2/4.3/4.6).
#
# SUBSTRATE. Every dependency below is the production object: the real ScheduleActionRegistry loaded
# from the shipped v1 manifest, the real DesktopIdentityNonceIssuer over the real
# DesktopIssuerRootStore over the real JsonFileStorage on a GUID-isolated root, the real
# ContactInvitationState source receipts issued by that same issuer, the real GameState autoload
# script, and one real ScheduleFoundationPublicationLedger over the SAME root-scoped storage object
# that owns the issuer root. Nothing here invents a parallel identity, a fallback ID, a service
# locator, or a clock/RNG-derived token.
#
# The port and the ledger do not exist during RED, so both are loaded through DynamicScriptProbe and
# their absence is reported as one named assertion per test instead of a parse crash.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/schedule/GameStateScheduleCommitPort.gd"
const LEDGER_PATH := "res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"
const SCHEMA_PATH := "res://scripts/domain/schedule/ScheduleStateSchema.gd"
const GAME_STATE_PATH := "res://autoload/GameState.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")

const LEDGER_FIXED_PATH := "schedule-foundation-publications.json"
const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const VIEW_FINGERPRINT := "schedule_view.22222222222222222222222222222222"

const LEGACY_NAMES: Array[String] = [
	"schedule_entries", "validate_date_candidate", "clear_schedule_with_refund",
	"clear_schedule_without_refund", "add_schedule_action", "add_schedule_date_entry",
	"remove_schedule_entry",
]

var _port_script: Script = null
var _ledger_script: Script = null
var _root := ""
var _storage: RefCounted = null
var _root_store: RefCounted = null
var _issuer: RefCounted = null
var _registry: RefCounted = null
var _fingerprint := ""
var _game_state: Node = null
var _ledger: Object = null
var _port: Object = null
var _commands: Dictionary = {}
var _signals: Array[String] = []
var _root_counter := 0


func before_each() -> void:
	_commands = {}
	_signals = []
	var port_loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_port_script = port_loaded["value"] if port_loaded.get("ok", false) else null
	var ledger_loaded: Dictionary = PROBE.load_script(LEDGER_PATH)
	_ledger_script = ledger_loaded["value"] if ledger_loaded.get("ok", false) else null

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

	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()

	if _ledger_script != null:
		_ledger = _ledger_script.new()
		assert_true(_ledger.configure(_storage).get("ok", false))
		assert_true(_ledger.load().get("ok", false))
	if _port_script != null and _ledger != null:
		_port = _port_script.new(_game_state, _registry, _issuer, _ledger)
	_watch_signals(_game_state)


## The wrapper's GUID-isolated `DWM_TEST_ROOT` is the only storage root this suite may use. The one
## adapter built on it owns the issuer root AND the publication ledger, exactly as bootstrap does.
func _isolated_root() -> String:
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("schedule-commit-port-%d" % _root_counter)
	var production := ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


func _require_port() -> bool:
	var absent: Array[String] = []
	if _ledger_script == null:
		absent.append(LEDGER_PATH)
	if _port_script == null:
		absent.append(PORT_PATH)
	if not absent.is_empty():
		assert_true(false, "the committed-Schedule modules are absent: " + str(absent))
		return false
	if _port == null:
		assert_true(false, "the four-dependency port constructor did not produce an instance")
		return false
	return true


# ---- signal watch ----

func _watch_signals(target: Node) -> void:
	for entry: Dictionary in target.get_script().get_script_signal_list():
		var signal_name := str(entry.get("name", ""))
		var arity: int = (entry.get("args", []) as Array).size()
		match arity:
			0: target.connect(signal_name, Callable(self, "_signal0").bind(signal_name))
			1: target.connect(signal_name, Callable(self, "_signal1").bind(signal_name))
			2: target.connect(signal_name, Callable(self, "_signal2").bind(signal_name))
			3: target.connect(signal_name, Callable(self, "_signal3").bind(signal_name))
			4: target.connect(signal_name, Callable(self, "_signal4").bind(signal_name))


func _signal0(signal_name: String) -> void:
	_signals.append(signal_name)


func _signal1(_a, signal_name: String) -> void:
	_signals.append(signal_name)


func _signal2(_a, _b, signal_name: String) -> void:
	_signals.append(signal_name)


func _signal3(_a, _b, _c, signal_name: String) -> void:
	_signals.append(signal_name)


func _signal4(_a, _b, _c, _d, signal_name: String) -> void:
	_signals.append(signal_name)


# ---- production fixtures ----

func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)


func _record(action_id: String) -> Dictionary:
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	return ((found.get("value", {}) as Dictionary).get("record", {}) as Dictionary)


func _seed_solo_source(friend_id: String, day: int, target: Node = null) -> String:
	var state: Node = target if target != null else _game_state
	var action_id := "solo:%s:day%d" % [friend_id, day]
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		state.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	var command := _command("open.%s.day%d" % [friend_id, day])
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, day, command["id"], command["receipt"],
		_issuer, _record(action_id))
	assert_true(opened.get("ok", false), str(opened))
	state.contacts = opened["value"]["candidate"]
	return str(opened["receipt"]["receipt_id"])


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


func _ordinary(draft_entry_id: String, slot_index: int, action_id: String, day := 1) -> Dictionary:
	return _draft(draft_entry_id, slot_index, action_id, "ordinary", [], null, day)


func _solo(draft_entry_id: String, slot_index: int, friend_id: String, day: int,
		source_receipt_id: String) -> Dictionary:
	return _draft(draft_entry_id, slot_index, "solo:%s:day%d" % [friend_id, day], "solo",
		[friend_id], source_receipt_id, day)


func _request(label: String, day: int, drafts: Array, view := VIEW_FINGERPRINT) -> Dictionary:
	var command := _command(label)
	return {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": view,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	}


# ---- canonical projection helpers (the plan's exact J/P/S/H notation) ----

func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _project(path: String, value: Variant) -> String:
	return path + "=" + _canonical(value)


func _slot_ordered(drafts: Array) -> Array:
	var ordered: Array = drafts.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["slot_index"]) < int(right["slot_index"]))
	return ordered


func _expected_entry_sources(request: Dictionary, entry: Dictionary) -> Array:
	var tokens: Array = [
		_project("role", "schedule.entry"),
		_project("transaction_id", request["transaction_id"]),
		_project("view_fingerprint", request["expected_view_fingerprint"]),
		_project("causal_day_instance", request["causal_day_instance"]),
		_project("registry_fingerprint", request["registry_fingerprint"]),
		_project("draft_entry_id", entry["draft_entry_id"]),
		_project("day", entry["day"]),
		_project("slot_index", entry["slot_index"]),
		_project("action_id", entry["action_id"]),
		_project("action_kind", entry["action_kind"]),
		_project("participants", entry["participants"]),
		_project("source_receipt_id", entry["source_receipt_id"]),
	]
	tokens.sort()
	return tokens


func _expected_aggregate_sources(request: Dictionary, entry_ids: Array,
		source_ids: Array) -> Array:
	var ordered := _slot_ordered(request["draft_entries"])
	var empty := ordered.is_empty()
	var tokens: Array = [
		_project("role", "schedule.empty_done" if empty else "schedule.commit"),
		_project("transaction_id", request["transaction_id"]),
		_project("view_fingerprint", request["expected_view_fingerprint"]),
		_project("day", request["day"]),
		_project("causal_day_instance", request["causal_day_instance"]),
		_project("registry_fingerprint", request["registry_fingerprint"]),
		_project("draft_entries_sha256", _sha256(_canonical(ordered))),
		_project("schedule_entry_ids", entry_ids),
		_project("source_receipt_ids", source_ids),
		_project("motivation_charged", ordered.size()),
	]
	tokens.sort()
	return tokens


func _prepared(label: String, day: int, drafts: Array) -> Dictionary:
	var request := _request(label, day, drafts)
	var prepared: Dictionary = _port.prepare_commit(request)
	assert_true(prepared.get("ok", false), str(prepared))
	return prepared


func _motivation() -> int:
	return int(_game_state.stats["motivation"])


func _live_committed() -> Dictionary:
	var captured: Dictionary = _game_state.capture_schedule_commit_state()
	assert_true(captured.get("ok", false), str(captured))
	return captured["value"]["committed_schedule"]


func _raw_ledger_document() -> String:
	return FileAccess.get_file_as_string(_root.path_join(LEDGER_FIXED_PATH))


# ---- tests ----

func test_zero_entries_derive_the_empty_done_row_and_charge_no_motivation() -> void:
	if not _require_port():
		return
	var request := _request("empty-done", 1, [])
	var before_state: Dictionary = _game_state.to_save_dict()
	var prepared: Dictionary = _port.prepare_commit(request)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return
	var value: Dictionary = prepared["value"]
	var value_keys: Array = value.keys()
	value_keys.sort()
	assert_eq(value_keys, ["committed_schedule", "game_state_candidate", "route_plan",
		"schedule_commit_receipt"], "the prepare success value is exact")
	var receipt: Dictionary = value["schedule_commit_receipt"]
	assert_eq(prepared["receipt"], receipt, "the outer receipt is a detached copy of the commit receipt")
	assert_eq(int(receipt["motivation_charged"]), 0, "empty Done charges zero motivation")
	assert_eq(receipt["schedule_entry_ids"], [])
	assert_eq(receipt["source_receipt_ids"], [])
	assert_eq(str(receipt["transaction_id"]), str(request["transaction_id"]))
	assert_eq(receipt["transaction_issuer_receipt"], request["transaction_issuer_receipt"])
	assert_eq(str(receipt["view_fingerprint"]), VIEW_FINGERPRINT)
	assert_eq(str(receipt["causal_day_instance"]), CAUSAL_DAY)
	assert_eq(str(receipt["registry_fingerprint"]), _fingerprint)
	var provenance: Dictionary = receipt["receipt_provenance"]
	assert_eq(str(provenance["child_kind"]), "empty_schedule_done",
		"zero entries consume exactly P01.schedule.empty_done")
	assert_eq(int(provenance["ordinal"]), 0)
	assert_eq(str(provenance["parent_receipt_id"]),
		str(request["transaction_issuer_receipt"]["receipt_id"]))
	assert_eq(str(provenance["child_id"]), str(receipt["receipt_id"]))
	assert_eq(provenance["source_ids"], _expected_aggregate_sources(request, [], []),
		"the empty aggregate binds the exact P01.schedule.empty_done projection")
	assert_true(_issuer.validate_child(provenance, &"empty_schedule_done").get("ok", false),
		"the production issuer reproduces the aggregate child")
	assert_eq(value["committed_schedule"]["entries"], [])
	assert_eq(value["committed_schedule"]["commit_receipt"], receipt,
		"the aggregate embeds its exact commit receipt")
	assert_eq(value["route_plan"], [], "an empty Done projects no route")
	assert_eq(int(value["game_state_candidate"]["motivation"]), 7, "no motivation is spent")
	assert_eq(_game_state.to_save_dict(), before_state, "prepare mutates nothing")
	assert_eq(_signals, [] as Array[String], "prepare emits nothing")


func test_entry_ordinals_follow_validated_slot_order_not_input_or_raw_slot() -> void:
	if not _require_port():
		return
	var drafts: Array = [
		_ordinary("draft-c", 5, "rest"),
		_ordinary("draft-a", 0, "training"),
		_ordinary("draft-b", 3, "working"),
	]
	var request := _request("slot-order", 1, drafts)
	var prepared: Dictionary = _port.prepare_commit(request)
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false):
		return
	var entries: Array = prepared["value"]["committed_schedule"]["entries"]
	assert_eq(entries.size(), 3)
	var slots: Array = []
	var entry_ids: Array = []
	var source_ids: Array = []
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		slots.append(int(entry["slot_index"]))
		entry_ids.append(str(entry["schedule_entry_id"]))
		source_ids.append(entry["source_receipt_id"])
		var provenance: Dictionary = entry["schedule_entry_provenance"]
		assert_eq(int(provenance["ordinal"]), index,
			"the ordinal is the zero-based validated slot-order index")
		assert_eq(str(provenance["child_kind"]), "schedule_entry",
			"every committed entry consumes exactly P01.schedule.entry")
		assert_eq(str(provenance["child_id"]), str(entry["schedule_entry_id"]))
		assert_eq(str(entry["commit_transaction_id"]), str(request["transaction_id"]))
		assert_eq(str(entry["state"]), "committed")
		var matching_draft: Dictionary = _slot_ordered(drafts)[index]
		assert_eq(provenance["source_ids"], _expected_entry_sources(request, matching_draft),
			"entry %d binds the exact P01.schedule.entry projection" % index)
		assert_true(_issuer.validate_child(provenance, &"schedule_entry").get("ok", false))
	assert_eq(slots, [0, 3, 5], "canonical execution sorts occupied slots ascending")
	assert_ne(int(entries[1]["slot_index"]), 1,
		"the second ordinal is not the raw slot number")
	var receipt: Dictionary = prepared["value"]["schedule_commit_receipt"]
	assert_eq(receipt["schedule_entry_ids"], entry_ids, "the ID array follows committed slot order")
	assert_eq(receipt["source_receipt_ids"], source_ids)
	assert_eq(int(receipt["motivation_charged"]), 3, "exactly one motivation per entry")
	assert_eq(str(receipt["receipt_provenance"]["child_kind"]), "schedule_commit",
		"a nonempty aggregate consumes exactly P01.schedule.commit")
	assert_eq(receipt["receipt_provenance"]["source_ids"],
		_expected_aggregate_sources(request, entry_ids, source_ids),
		"the aggregate binds the exact P01.schedule.commit projection after entry derivation")
	assert_true(_issuer.validate_child(receipt["receipt_provenance"], &"schedule_commit").get("ok", false))
	var routes: Array = prepared["value"]["route_plan"]
	assert_eq(routes.size(), 3, "the transient route projection follows committed order")
	assert_eq(int(routes[0]["slot_index"]), 0)
	assert_eq(str(routes[0]["schedule_entry_id"]), str(entry_ids[0]))


func test_seven_entries_with_two_dates_and_repeats_charge_one_motivation_each() -> void:
	if not _require_port():
		return
	var priscilla := _seed_solo_source("priscilla", 1)
	var sylvia := _seed_solo_source("sylvia", 1)
	var drafts: Array = [
		_ordinary("d0", 0, "training"),
		_ordinary("d1", 1, "working"),
		_ordinary("d2", 2, "rest"),
		_ordinary("d3", 3, "training"),
		_ordinary("d4", 4, "working"),
		_solo("d5", 5, "priscilla", 1, priscilla),
		_solo("d6", 6, "sylvia", 1, sylvia),
	]
	var prepared := _prepared("seven", 1, drafts)
	var receipt: Dictionary = prepared["value"]["schedule_commit_receipt"]
	assert_eq(int(receipt["motivation_charged"]), 7,
		"a date charges one motivation exactly like an ordinary action")
	assert_eq(receipt["source_receipt_ids"],
		[null, null, null, null, null, priscilla, sylvia],
		"the source array aligns with committed slot order")
	assert_eq(int(prepared["value"]["game_state_candidate"]["motivation"]), 0)
	var committed: Dictionary = _port.commit(prepared["value"]["game_state_candidate"])
	assert_true(committed.get("ok", false), str(committed))
	assert_eq(_motivation(), 0, "commit charges exactly one motivation per entry")
	assert_eq(_live_committed(), prepared["value"]["committed_schedule"])


func test_day7_accepts_empty_done_and_one_eligible_solo_at_slot_zero() -> void:
	if not _require_port():
		return
	_game_state._lifecycle_set_playing_day(7)
	var empty := _prepared("day7-empty", 7, [])
	assert_eq(str(empty["value"]["schedule_commit_receipt"]["receipt_provenance"]["child_kind"]),
		"empty_schedule_done")
	assert_eq(int(empty["value"]["committed_schedule"]["day"]), 7)

	var source := _seed_solo_source("priscilla", 7)
	var solo := _prepared("day7-solo", 7, [_solo("d0", 0, "priscilla", 7, source)])
	var receipt: Dictionary = solo["value"]["schedule_commit_receipt"]
	assert_eq(int(receipt["motivation_charged"]), 1)
	assert_eq(receipt["source_receipt_ids"], [source])
	assert_eq(solo["value"]["route_plan"], [],
		"a Day-7 destination emits no physical route descriptor")

	var wrong_slot: Dictionary = _port.prepare_commit(
		_request("day7-slot", 7, [_solo("d1", 1, "priscilla", 7, source)]))
	assert_false(wrong_slot.get("ok", true), "the Day-7 destination sits at slot zero")
	var two_entries: Dictionary = _port.prepare_commit(
		_request("day7-two", 7, [_solo("d2", 0, "priscilla", 7, source), _ordinary("d3", 1, "rest", 7)]))
	assert_false(two_entries.get("ok", true), "Day 7 holds at most one entry")


func test_insufficient_motivation_stale_registry_and_source_tamper_yield_no_candidate() -> void:
	if not _require_port():
		return
	var source := _seed_solo_source("priscilla", 1)
	var drafts: Array = [_ordinary("d0", 0, "training"), _solo("d1", 1, "priscilla", 1, source)]
	var before_contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)

	_game_state.stats["motivation"] = 1
	var poor: Dictionary = _port.prepare_commit(_request("poor", 1, drafts))
	assert_false(poor.get("ok", true), "two entries cannot be charged against one motivation")
	assert_false(poor.has("value"), "a failure returns no candidate")
	assert_eq(_motivation(), 1, "a rejected prepare charges nothing")
	_game_state.stats["motivation"] = 7

	var stale := _request("stale", 1, drafts)
	stale["registry_fingerprint"] = "0".repeat(64)
	var stale_result: Dictionary = _port.prepare_commit(stale)
	assert_false(stale_result.get("ok", true), "a stale registry fingerprint fails closed")

	var tampered: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	tampered["schedule_source_receipts"][source]["participants"] = ["sylvia"]
	_game_state.contacts = tampered
	var tampered_result: Dictionary = _port.prepare_commit(_request("tampered", 1, drafts))
	assert_false(tampered_result.get("ok", true), "a tampered source receipt fails closed")
	_game_state.contacts = before_contacts

	var unknown: Dictionary = _port.prepare_commit(
		_request("unknown", 1, [_ordinary("d0", 0, "meditation")]))
	assert_false(unknown.get("ok", true), "only registered actions are schedulable")

	var sourceless: Dictionary = _port.prepare_commit(
		_request("sourceless", 1, [_draft("d0", 0, "solo:priscilla:day1", "solo", ["priscilla"], null, 1)]))
	assert_false(sourceless.get("ok", true), "a date requires its acceptance receipt")

	var foreign_source: Dictionary = _port.prepare_commit(
		_request("foreign", 1, [_solo("d0", 0, "priscilla", 1, "contact_source." + "a".repeat(64))]))
	assert_false(foreign_source.get("ok", true), "an unresolvable source receipt fails closed")

	var wrong_day: Dictionary = _port.prepare_commit(_request("wrong-day", 2, drafts))
	assert_false(wrong_day.get("ok", true), "the request day must match the owner's aggregate day")
	assert_eq(_signals, [] as Array[String], "no rejection emits a signal")
	assert_eq(_live_committed()["entries"], [], "no rejection changes canonical state")


func test_forged_or_identifier_only_issuer_input_is_refused() -> void:
	if not _require_port():
		return
	var drafts: Array = [_ordinary("d0", 0, "training")]
	var id_only := _request("id-only", 1, drafts)
	id_only["transaction_issuer_receipt"] = {}
	assert_false(_port.prepare_commit(id_only).get("ok", true),
		"a caller-authored identifier alone never proves a transaction")

	var forged := _request("forged", 1, drafts)
	forged["transaction_issuer_receipt"]["token"] = "transaction_id." + "f".repeat(64)
	assert_false(_port.prepare_commit(forged).get("ok", true), "a forged receipt is refused")

	var mismatch := _request("mismatch", 1, drafts)
	mismatch["transaction_id"] = str(_command("other-root")["id"])
	assert_false(_port.prepare_commit(mismatch).get("ok", true),
		"transaction_id must equal the receipt token")

	var wrong_purpose: Dictionary = _issuer.issue(&"receipt_id")
	assert_true(wrong_purpose.get("ok", false), str(wrong_purpose))
	var purpose_request := _request("purpose", 1, drafts)
	purpose_request["transaction_id"] = str(wrong_purpose["value"]["token"])
	purpose_request["transaction_issuer_receipt"] = wrong_purpose["value"]["issuer_receipt"]
	assert_false(_port.prepare_commit(purpose_request).get("ok", true),
		"only a transaction_id root may anchor a Schedule commit")

	for key: String in ["transaction_id", "transaction_issuer_receipt", "expected_view_fingerprint",
			"day", "causal_day_instance", "draft_entries", "registry_fingerprint"]:
		var missing := _request("missing-" + key, 1, drafts)
		missing.erase(key)
		assert_false(_port.prepare_commit(missing).get("ok", true), "the request requires " + key)
	var widened := _request("widened", 1, drafts)
	widened["draft_entries_sha256"] = "0".repeat(64)
	assert_false(_port.prepare_commit(widened).get("ok", true),
		"the request member set is exact")
	var blank_view := _request("blank-view", 1, drafts)
	blank_view["expected_view_fingerprint"] = ""
	assert_false(_port.prepare_commit(blank_view).get("ok", true),
		"the opaque view fingerprint must be a nonblank String")


func test_same_transaction_replay_is_byte_identical_and_changed_bytes_conflict() -> void:
	if not _require_port():
		return
	var drafts: Array = [_ordinary("d0", 0, "training")]
	var request := _request("replay", 1, drafts)
	var first: Dictionary = _port.prepare_commit(request)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false):
		return
	var replay: Dictionary = _port.prepare_commit(_request("replay", 1, drafts))
	assert_true(replay.get("ok", false), str(replay))
	assert_eq(replay["value"], first["value"], "an identical request replays byte-identically")
	assert_eq(replay["receipt"], first["receipt"])

	var changed := _request("replay", 1, drafts)
	changed["expected_view_fingerprint"] = "schedule_view.changed"
	var conflict: Dictionary = _port.prepare_commit(changed)
	assert_false(conflict.get("ok", true), "the same transaction with changed bytes conflicts")
	assert_eq(conflict.get("code"), &"command_conflict")

	var changed_drafts := _request("replay", 1, [_ordinary("d0", 1, "training")])
	assert_false(_port.prepare_commit(changed_drafts).get("ok", true),
		"a changed draft under the same transaction conflicts")

	var second: Dictionary = _port.prepare_commit(_request("second", 1, drafts))
	assert_true(second.get("ok", false), str(second))
	assert_ne(str(second["value"]["schedule_commit_receipt"]["receipt_id"]),
		str(first["value"]["schedule_commit_receipt"]["receipt_id"]),
		"a different issued transaction derives a different aggregate identity")


func test_every_row_projection_is_load_bearing_in_the_derived_identity() -> void:
	if not _require_port():
		return
	var source := _seed_solo_source("priscilla", 1)
	var prepared := _prepared("matrix", 1, [
		_ordinary("d0", 0, "training"),
		_solo("d1", 2, "priscilla", 1, source),
	])
	var entry: Dictionary = prepared["value"]["committed_schedule"]["entries"][1]
	var receipt: Dictionary = prepared["value"]["schedule_commit_receipt"]
	var rows: Array[Dictionary] = [
		{"name": "P01.schedule.entry", "provenance": entry["schedule_entry_provenance"],
			"kind": &"schedule_entry"},
		{"name": "P01.schedule.commit", "provenance": receipt["receipt_provenance"],
			"kind": &"schedule_commit"},
	]
	for row: Dictionary in rows:
		var provenance: Dictionary = row["provenance"]
		assert_true(_issuer.validate_child(provenance, row["kind"]).get("ok", false),
			"the unmodified row validates: " + str(row["name"]))
		var sources: Array = provenance["source_ids"]
		for index: int in range(sources.size()):
			var changed: Dictionary = provenance.duplicate(true)
			(changed["source_ids"] as Array)[index] = "role=\"forged\""
			(changed["source_ids"] as Array).sort()
			assert_false(_issuer.validate_child(changed, row["kind"]).get("ok", true),
				"%s token %d is load-bearing" % [str(row["name"]), index])
		var deleted: Dictionary = provenance.duplicate(true)
		(deleted["source_ids"] as Array).remove_at(0)
		assert_false(_issuer.validate_child(deleted, row["kind"]).get("ok", true),
			"a deleted projection is rejected: " + str(row["name"]))
		var added: Dictionary = provenance.duplicate(true)
		(added["source_ids"] as Array).append('zz_extra="x"')
		assert_false(_issuer.validate_child(added, row["kind"]).get("ok", true),
			"an added projection is rejected: " + str(row["name"]))
		var swapped: Dictionary = provenance.duplicate(true)
		var ordered: Array = swapped["source_ids"]
		var head: Variant = ordered[0]
		ordered[0] = ordered[1]
		ordered[1] = head
		assert_false(_issuer.validate_child(swapped, row["kind"]).get("ok", true),
			"a reordered projection is rejected: " + str(row["name"]))
		var wrong_parent: Dictionary = provenance.duplicate(true)
		wrong_parent["parent_receipt_id"] = "issuer_receipt." + "c".repeat(64)
		assert_false(_issuer.validate_child(wrong_parent, row["kind"]).get("ok", true),
			"a foreign parent is rejected: " + str(row["name"]))
		var wrong_ordinal: Dictionary = provenance.duplicate(true)
		wrong_ordinal["ordinal"] = int(provenance["ordinal"]) + 3
		assert_false(_issuer.validate_child(wrong_ordinal, row["kind"]).get("ok", true),
			"a changed ordinal is rejected: " + str(row["name"]))
		assert_false(_issuer.validate_child(provenance, &"contact_source").get("ok", true),
			"a substituted child kind is rejected: " + str(row["name"]))

	# The H() preimage inside the aggregate row is the validated slot-order draft array itself.
	var ordered_drafts := _slot_ordered([
		_ordinary("d0", 0, "training"),
		_solo("d1", 2, "priscilla", 1, source),
	])
	assert_true((receipt["receipt_provenance"]["source_ids"] as Array).has(
		_project("draft_entries_sha256", _sha256(_canonical(ordered_drafts)))),
		"the aggregate projects H() over the validated slot-order drafts")
	var mutated_preimage := ordered_drafts.duplicate(true)
	mutated_preimage[0]["slot_index"] = 4
	assert_ne(_sha256(_canonical(mutated_preimage)), _sha256(_canonical(ordered_drafts)),
		"a changed preimage changes the projected digest")


func test_prepare_and_capture_are_pure_and_silent() -> void:
	if not _require_port():
		return
	var captured: Dictionary = _port.capture()
	assert_true(captured.get("ok", false), str(captured))
	if not captured.get("ok", false):
		return
	assert_eq(captured["receipt"], {}, "capture issues no receipt")
	var backup: Dictionary = captured["value"]["backup"]
	var backup_keys: Array = backup.keys()
	backup_keys.sort()
	assert_eq(backup_keys, ["committed_schedule", "motivation"], "the backup is exactly narrow")
	assert_eq(int(backup["motivation"]), 7)
	assert_eq(backup["committed_schedule"], {
		"schema_version": 1, "day": 1, "registry_fingerprint": null,
		"entries": [], "commit_receipt": null,
	}, "an uninitialized owner exposes the empty aggregate for its day")

	var before_state: Dictionary = _game_state.to_save_dict()
	var before_contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	var prepared := _prepared("pure", 1, [_ordinary("d0", 0, "training")])
	assert_eq(_game_state.to_save_dict(), before_state, "prepare mutates no whitelisted state")
	assert_eq(_game_state.contacts, before_contacts, "prepare mutates no Contacts state")
	assert_eq(_live_committed()["entries"], [], "prepare installs no candidate")
	assert_eq(_motivation(), 7, "prepare charges no motivation")
	assert_eq(_signals, [] as Array[String], "prepare and capture emit nothing")
	assert_eq(int(prepared["value"]["game_state_candidate"]["motivation"]), 6,
		"the candidate carries the charged motivation without applying it")
	var candidate_keys: Array = prepared["value"]["game_state_candidate"].keys()
	candidate_keys.sort()
	assert_eq(candidate_keys, ["before_fingerprint", "committed_schedule", "motivation"],
		"the internal candidate is exactly narrow")


func test_commit_changes_only_motivation_and_committed_schedule_silently() -> void:
	if not _require_port():
		return
	var prepared := _prepared("commit", 1, [_ordinary("d0", 0, "training")])
	var before_state: Dictionary = _game_state.to_save_dict()
	var before_contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	var committed: Dictionary = _port.commit(prepared["value"]["game_state_candidate"])
	assert_true(committed.get("ok", false), str(committed))
	if not committed.get("ok", false):
		return
	assert_eq(committed["value"]["committed_schedule"], prepared["value"]["committed_schedule"])
	assert_eq(committed["receipt"], prepared["value"]["schedule_commit_receipt"],
		"commit returns the exact Schedule receipt")
	assert_eq(_signals, [] as Array[String], "commit installs the candidate silently")
	assert_eq(_motivation(), 6, "commit charges exactly the prepared motivation")
	assert_eq(_live_committed(), prepared["value"]["committed_schedule"])
	assert_eq(_game_state.contacts, before_contacts, "commit does not touch Contacts")
	var after_state: Dictionary = _game_state.to_save_dict()
	var changed: Array[String] = []
	for key: Variant in after_state:
		if after_state[key] != before_state.get(key):
			changed.append(str(key))
	assert_eq(changed, ["stats"] as Array[String],
		"only motivation inside stats changes in the whitelisted bag")
	assert_eq(int(after_state["stats"]["pressure"]), int(before_state["stats"]["pressure"]))
	assert_eq(int(after_state["stats"]["health"]), int(before_state["stats"]["health"]))
	assert_eq(after_state["schedule_entries"], before_state["schedule_entries"],
		"the legacy Schedule transport is untouched")


func test_rollback_restores_exactly_the_backup_and_preserves_concurrent_changes() -> void:
	if not _require_port():
		return
	var backup: Dictionary = _port.capture()["value"]["backup"]
	var prepared := _prepared("rollback", 1, [_ordinary("d0", 0, "training")])
	assert_true(_port.commit(prepared["value"]["game_state_candidate"]).get("ok", false))
	# A concurrent, unrelated owner change lands between commit and rollback.
	var concurrent_source := _seed_solo_source("priscilla", 1)
	var concurrent_contacts: Dictionary = (_game_state.contacts as Dictionary).duplicate(true)
	_game_state.money = 41
	_signals = []

	var rolled: Dictionary = _port.rollback(backup)
	assert_true(rolled.get("ok", false), str(rolled))
	if not rolled.get("ok", false):
		return
	assert_eq(rolled["value"], {"restored": true})
	assert_eq(rolled["receipt"], {})
	assert_eq(_signals, [] as Array[String], "rollback emits nothing")
	assert_eq(_motivation(), 7, "rollback restores the captured motivation")
	assert_eq(_live_committed(), backup["committed_schedule"],
		"rollback restores the captured aggregate")
	assert_eq(_game_state.contacts, concurrent_contacts,
		"rollback never clobbers a concurrent Contacts change")
	assert_true((_game_state.contacts as Dictionary)["schedule_source_receipts"].has(concurrent_source))
	assert_eq(int(_game_state.money), 41, "rollback never clobbers unrelated settings state")
	assert_false(_port.rollback({"motivation": 7}).get("ok", true),
		"a backup not issued by capture is refused")


func test_stale_before_fingerprint_and_caller_mutation_after_prepare_are_refused() -> void:
	if not _require_port():
		return
	var prepared := _prepared("stale-commit", 1, [_ordinary("d0", 0, "training")])
	var candidate: Dictionary = prepared["value"]["game_state_candidate"]
	_game_state.stats["motivation"] = 5
	var stale: Dictionary = _port.commit(candidate)
	assert_false(stale.get("ok", true), "a candidate prepared against stale owner state is refused")
	assert_eq(_motivation(), 5, "a refused commit changes nothing")
	assert_eq(_live_committed()["entries"], [])
	_game_state.stats["motivation"] = 7

	var mutated: Dictionary = candidate.duplicate(true)
	mutated["motivation"] = 0
	assert_false(_port.commit(mutated).get("ok", true), "a caller-changed candidate is refused")
	var mutated_schedule: Dictionary = candidate.duplicate(true)
	mutated_schedule["committed_schedule"]["entries"][0]["slot_index"] = 6
	assert_false(_port.commit(mutated_schedule).get("ok", true),
		"a caller-changed aggregate is refused")
	prepared["value"]["committed_schedule"]["entries"].append({"forged": true})
	assert_eq(_live_committed()["entries"], [],
		"mutating a returned value cannot reach the owner")
	assert_false(_port.commit({}).get("ok", true), "an empty candidate is refused")


func test_publish_requires_current_state_and_is_at_most_once_across_restart() -> void:
	if not _require_port():
		return
	var prepared := _prepared("publish", 1, [_ordinary("d0", 0, "training")])
	var publication := {
		"committed_schedule": prepared["value"]["committed_schedule"],
		"schedule_commit_receipt": prepared["value"]["schedule_commit_receipt"],
	}
	var premature: Dictionary = _port.publish(publication)
	assert_false(premature.get("ok", true), "publishing state the owner does not hold is refused")
	assert_eq(_signals, [] as Array[String], "a refused publish emits nothing")
	assert_eq(_raw_ledger_document(), '{"records":{},"schema_version":1}' + "\n",
		"a refused publish records nothing")

	assert_true(_port.commit(prepared["value"]["game_state_candidate"]).get("ok", false))
	_signals = []
	var first: Dictionary = _port.publish(publication)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false):
		return
	assert_eq(first["value"], {"published": true})
	assert_eq(first["receipt"], publication["schedule_commit_receipt"],
		"the publish receipt is byte-equal to the request receipt")
	assert_eq(_signals.size(), 1, "a first delivery emits exactly one declared signal")
	var durable := _raw_ledger_document()
	assert_true(durable.contains(str(publication["schedule_commit_receipt"]["receipt_id"])),
		"the record is durable before the signal")

	var replayed: Dictionary = _port.publish(publication)
	assert_true(replayed.get("ok", false), str(replayed))
	assert_eq(replayed, first, "either delivery returns the byte-identical success")
	assert_eq(_signals.size(), 1, "a replay emits no second signal")

	# Cold restart: a new storage adapter, ledger and port over the same durable bytes.
	var restarted_ledger: Object = _ledger_script.new()
	assert_true(restarted_ledger.configure(JsonFileStorage.new(_root)).get("ok", false))
	assert_true(restarted_ledger.load().get("ok", false))
	var restarted_port: Object = _port_script.new(_game_state, _registry, _issuer, restarted_ledger)
	var after_restart: Dictionary = restarted_port.publish(publication)
	assert_true(after_restart.get("ok", false), str(after_restart))
	assert_eq(after_restart, first, "a cold retry returns the byte-identical success")
	assert_eq(_signals.size(), 1, "a cold retry emits no second signal")
	assert_eq(_raw_ledger_document(), durable, "a cold retry rewrites nothing")


func test_a_changed_publication_byte_at_an_occupied_key_conflicts_without_a_signal() -> void:
	if not _require_port():
		return
	var prepared := _prepared("conflict", 1, [_ordinary("d0", 0, "training")])
	assert_true(_port.commit(prepared["value"]["game_state_candidate"]).get("ok", false))
	var publication := {
		"committed_schedule": prepared["value"]["committed_schedule"],
		"schedule_commit_receipt": prepared["value"]["schedule_commit_receipt"],
	}
	assert_true(_port.publish(publication).get("ok", false))
	var durable := _raw_ledger_document()
	_signals = []

	# Reaching the ledger's occupied key requires the owner to actually hold the changed bytes, so
	# the mutated aggregate is installed through the narrow restore seam first. Otherwise publish
	# stops earlier, at the state-equality law proved in the previous test.
	var changed: Dictionary = publication.duplicate(true)
	changed["committed_schedule"]["entries"][0]["slot_index"] = 4
	var reinstalled: Dictionary = _game_state.rollback_schedule_commit_state({
		"motivation": _motivation(), "committed_schedule": changed["committed_schedule"],
	})
	assert_true(reinstalled.get("ok", false), str(reinstalled))
	var conflict: Dictionary = _port.publish(changed)
	assert_false(conflict.get("ok", true), "a changed publication byte cannot reuse its key")
	assert_eq(conflict.get("code"), &"schedule_publication_conflict")
	assert_eq(_signals, [] as Array[String], "a conflict emits nothing")
	assert_eq(_raw_ledger_document(), durable, "a conflict rewrites nothing")

	for key: String in ["committed_schedule", "schedule_commit_receipt"]:
		var missing: Dictionary = publication.duplicate(true)
		missing.erase(key)
		assert_false(_port.publish(missing).get("ok", true), "the publication requires " + key)
	var widened: Dictionary = publication.duplicate(true)
	widened["route_plan"] = []
	assert_false(_port.publish(widened).get("ok", true), "the publication member set is exact")
	var unbound: Dictionary = publication.duplicate(true)
	unbound["schedule_commit_receipt"] = prepared["value"]["schedule_commit_receipt"].duplicate(true)
	unbound["schedule_commit_receipt"]["motivation_charged"] = 9
	assert_false(_port.publish(unbound).get("ok", true),
		"the publication receipt must be the aggregate's own receipt")
	assert_eq(_raw_ledger_document(), durable)


func test_new_run_and_rollback_cannot_erase_or_lower_the_external_record() -> void:
	if not _require_port():
		return
	var backup: Dictionary = _port.capture()["value"]["backup"]
	var prepared := _prepared("durable", 1, [_ordinary("d0", 0, "training")])
	assert_true(_port.commit(prepared["value"]["game_state_candidate"]).get("ok", false))
	var publication := {
		"committed_schedule": prepared["value"]["committed_schedule"],
		"schedule_commit_receipt": prepared["value"]["schedule_commit_receipt"],
	}
	assert_true(_port.publish(publication).get("ok", false))
	var durable := _raw_ledger_document()

	assert_true(_port.rollback(backup).get("ok", false))
	_game_state.reset_game()
	_game_state.apply_save_dict({"day": 1, "money": 0})
	assert_eq(_raw_ledger_document(), durable,
		"an ordinary rollback and a New Run leave the external record byte-identical")

	var reconstructed: Object = _ledger_script.new()
	assert_true(reconstructed.configure(JsonFileStorage.new(_root)).get("ok", false))
	var loaded: Dictionary = reconstructed.load()
	assert_true(loaded.get("ok", false), str(loaded))
	var records: Dictionary = loaded["value"]["document"]["records"]
	assert_eq(records.size(), 1, "the record survives selectable state changes")
	var key := "schedule_commit:" + str(publication["schedule_commit_receipt"]["receipt_id"])
	assert_true(records.has(key))
	assert_eq(records[key]["publication"], publication)


func test_candidate_and_commit_bytes_are_independent_of_every_legacy_field() -> void:
	if not _require_port():
		return
	var source := _seed_solo_source("priscilla", 1)
	var drafts: Array = [
		_ordinary("d0", 0, "training"),
		_solo("d1", 1, "priscilla", 1, source),
	]

	# A second owner over the SAME issuer, registry and ledger, differing only in legacy fields.
	var twin: Node = load(GAME_STATE_PATH).new()
	autofree(twin)
	twin.reset_game()
	twin.contacts = (_game_state.contacts as Dictionary).duplicate(true)
	var twin_port: Object = _port_script.new(twin, _registry, _issuer, _ledger)

	_game_state.schedule_entries = [{"type": "solo", "friend_id": "priscilla", "action_id": "legacy"}]
	_game_state.pending_date_entries = [{"type": "solo"}]
	_game_state.date_unlocks = {"day:1:friend:priscilla": true}
	var legacy_before: Array = (_game_state.schedule_entries as Array).duplicate(true)

	var request := _request("legacy", 1, drafts)
	var with_legacy: Dictionary = _port.prepare_commit(request)
	var without_legacy: Dictionary = twin_port.prepare_commit(request)
	assert_true(with_legacy.get("ok", false), str(with_legacy))
	assert_true(without_legacy.get("ok", false), str(without_legacy))
	if not with_legacy.get("ok", false) or not without_legacy.get("ok", false):
		return
	assert_eq(with_legacy["value"]["committed_schedule"],
		without_legacy["value"]["committed_schedule"],
		"the committed aggregate bytes ignore every legacy field")
	assert_eq(with_legacy["value"]["schedule_commit_receipt"],
		without_legacy["value"]["schedule_commit_receipt"],
		"the commit receipt bytes ignore every legacy field")
	assert_eq(with_legacy["value"]["game_state_candidate"],
		without_legacy["value"]["game_state_candidate"],
		"the narrow candidate bytes ignore every legacy field")

	var backup: Dictionary = _port.capture()["value"]["backup"]
	assert_true(_port.commit(with_legacy["value"]["game_state_candidate"]).get("ok", false))
	assert_eq(_game_state.schedule_entries, legacy_before, "commit never writes the legacy array")
	assert_true(_port.rollback(backup).get("ok", false))
	assert_eq(_game_state.schedule_entries, legacy_before, "rollback never writes the legacy array")
	assert_eq(_game_state.date_unlocks, {"day:1:friend:priscilla": true},
		"neither commit nor rollback synchronizes legacy unlocks")


func test_new_modules_never_name_the_legacy_schedule_api() -> void:
	if not _require_port():
		return
	for path: String in [PORT_PATH, SCHEMA_PATH]:
		var source := FileAccess.get_file_as_string(path)
		assert_true(source.length() > 0, "the module must be readable: " + path)
		for legacy_name: String in LEGACY_NAMES:
			assert_false(source.contains(legacy_name),
				"%s must not name the legacy Schedule API member %s" % [path, legacy_name])
		for forbidden: String in ["/root/", "Time.", "randi(", "snapshot(", "lookup("]:
			assert_false(source.contains(forbidden),
				"%s must not reach for %s" % [path, forbidden])
