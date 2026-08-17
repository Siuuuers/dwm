extends "res://addons/gut/test.gd"
# Day-7 Schedule provenance handoff (Plan 01 Task 6, dwm-p2r.13, Step 6.1).
#
# SUBSTRATE. Every dependency is the production object, exactly as in
# tests/unit/test_game_state_schedule_commit_port.gd: the real ScheduleActionRegistry from the
# shipped v1 manifest, the real DesktopIdentityNonceIssuer over the real DesktopIssuerRootStore over
# the real JsonFileStorage on a GUID-isolated root, real ContactInvitationState source receipts
# issued by that same issuer, the real GameState autoload script, one real
# ScheduleFoundationPublicationLedger over that same storage object, and the real
# GameStateScheduleCommitPort. The Day-7 commits fed to the service are therefore genuinely
# committed aggregates, not hand-built dictionaries -- plan Step 5.7 bans handwaved fingerprints and
# receipts, and a fake aggregate here would prove nothing about the row being derived.
#
# Day7ScheduleProvenance.gd does not exist during RED, so it is loaded through DynamicScriptProbe and
# its absence is reported as one named assertion per test instead of a parse crash.
#
# WHAT THIS FILE OWNS (plan lines 462-505 and matrix row P01.schedule.day7_provenance at line 91):
#   * the frozen two-method surface, and that nothing else is public;
#   * configure() idempotency for the same retained pair and refusal of replacement;
#   * both accepted causes -- a receipt-backed Day-7 empty commit and exactly one registry-valid solo
#     at slot zero -- and the exact 11-member terminal_provenance each produces;
#   * byte-exact consumption of row P01.schedule.day7_provenance, with the expected source tokens
#     recomputed INDEPENDENTLY in this file rather than read back from the service;
#   * every rejection the plan names, and mutation-freedom.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const SERVICE_PATH := "res://scripts/domain/schedule/Day7ScheduleProvenance.gd"
const PORT_PATH := "res://scripts/application/schedule/GameStateScheduleCommitPort.gd"
const LEDGER_PATH := "res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd"
const GAME_STATE_PATH := "res://autoload/GameState.gd"

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")

const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const VIEW_FINGERPRINT := "schedule_view.22222222222222222222222222222222"

const CHILD_KIND := &"day7_schedule_provenance"
const HANDOFF_KEYS: Array[String] = [
	"causal_day_instance", "committed_schedule", "source_receipt_index", "transaction_id",
	"transaction_issuer_receipt",
]
## Exact terminal_provenance members (sorted), plan lines 487-501.
const TERMINAL_KEYS: Array[String] = [
	"action_id", "causal_day_instance", "cause", "day", "kind", "receipt_id",
	"receipt_provenance", "registry_fingerprint", "schedule_commit_receipt_id",
	"schedule_entry_id", "source_receipt_id",
]
## Plan line 503: the handoff carries none of this.
const FORBIDDEN_MEMBERS: Array[String] = [
	"alias", "friend_alias", "tier", "tone", "relationship_tier", "dark_mode", "dark",
	"faint", "condition", "ending_id", "ending_step", "presentation_form", "playback_stage",
]

var _service_script: Script = null
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
var _service: Object = null
var _commands: Dictionary = {}
var _source_receipts: Dictionary = {}
var _root_counter := 0
var _last_rejection := ""


func before_each() -> void:
	_commands = {}
	_source_receipts = {}
	var service_loaded: Dictionary = PROBE.load_script(SERVICE_PATH)
	_service_script = service_loaded["value"] if service_loaded.get("ok", false) else null
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
	if _service_script != null:
		_service = _service_script.new()


## The wrapper's GUID-isolated DWM_TEST_ROOT is the only storage root this suite may use.
func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	var root: String = wrapper.path_join("day7-provenance-%d" % _root_counter)
	var production: String = ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	assert_ne(root.simplify_path().trim_suffix("/").nocasecmp_to(production), 0,
		"an isolated root is never the production user directory")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	return root


func _require_service() -> bool:
	var absent: Array[String] = []
	if _service_script == null:
		absent.append(SERVICE_PATH)
	if _port_script == null:
		absent.append(PORT_PATH)
	if _ledger_script == null:
		absent.append(LEDGER_PATH)
	if not absent.is_empty():
		assert_true(false, "the Day-7 provenance substrate is absent: " + str(absent))
		return false
	if _service == null or _port == null:
		assert_true(false, "the Day-7 provenance service or its commit port did not instantiate")
		return false
	return true


func _configured() -> bool:
	if not _require_service():
		return false
	var configured: Dictionary = _service.call(&"configure", _registry, _issuer)
	assert_true(configured.get("ok", false),
		"configure must accept the retained registry/issuer pair: %s" % str(configured.get("code", &"")))
	return configured.get("ok", false)


# ---- the frozen surface ----

func test_service_exposes_exactly_the_frozen_two_method_surface() -> void:
	if not _require_service():
		return
	var public_names: Array[String] = []
	for entry: Dictionary in _service_script.get_script_method_list():
		var method_name: String = str(entry["name"])
		if not method_name.begins_with("_"):
			public_names.append(method_name)
	public_names.sort()
	assert_eq(public_names, ["configure", "validate_handoff"],
		"plan lines 464-469 freeze exactly configure() and validate_handoff()")


func test_configure_is_idempotent_for_the_same_pair_and_refuses_replacement() -> void:
	if not _configured():
		return
	var again: Dictionary = _service.call(&"configure", _registry, _issuer)
	assert_true(again.get("ok", false), "the same retained pair must be idempotent")
	var other_issuer: RefCounted = ISSUER.new()
	assert_true(other_issuer.configure(_root_store).get("ok", false))
	var replaced: Dictionary = _service.call(&"configure", _registry, other_issuer)
	assert_false(replaced.get("ok", true), "replacement must be refused, not silently adopted")


func test_configure_refuses_an_incapable_registry_or_issuer() -> void:
	if not _require_service():
		return
	for pair: Array in [[null, _issuer], [_registry, null], [RefCounted.new(), _issuer],
			[_registry, RefCounted.new()]]:
		var configured: Dictionary = _service.call(&"configure", pair[0], pair[1])
		assert_false(configured.get("ok", true),
			"an incapable dependency must be refused before anything is retained")


func test_validate_handoff_requires_the_exact_request_member_set() -> void:
	if not _configured():
		return
	var request: Dictionary = _empty_done_request()
	if request.is_empty():
		return
	var keys: Array = request.keys()
	keys.sort()
	assert_eq(keys, HANDOFF_KEYS, "this suite must build the exact plan-475 request")
	for missing: String in HANDOFF_KEYS:
		var short: Dictionary = request.duplicate(true)
		short.erase(missing)
		assert_false(_service.call(&"validate_handoff", short).get("ok", true),
			"a request missing %s must be refused" % missing)
	var extra: Dictionary = request.duplicate(true)
	extra["unexpected"] = true
	assert_false(_service.call(&"validate_handoff", extra).get("ok", true),
		"an extra request member must be refused")


# ---- the two accepted causes ----

func test_empty_done_handoff_returns_the_exact_terminal_provenance() -> void:
	if not _configured():
		return
	var request: Dictionary = _empty_done_request()
	if request.is_empty():
		return
	var handed: Dictionary = _service.call(&"validate_handoff", request)
	assert_true(handed.get("ok", false),
		"a receipt-backed Day-7 empty commit is an accepted cause: %s" % str(handed.get("code", &"")))
	if not handed.get("ok", false):
		return
	var terminal: Dictionary = _terminal_of(handed)
	_assert_terminal_shape(terminal, "empty_done", request)
	for nullable: String in ["schedule_entry_id", "action_id", "source_receipt_id"]:
		assert_null(terminal[nullable], "%s is null for empty_done (plan line 503)" % nullable)


func test_scheduled_solo_handoff_returns_the_exact_terminal_provenance() -> void:
	if not _configured():
		return
	var built: Dictionary = _solo_request()
	if built.is_empty():
		return
	var request: Dictionary = built["request"]
	var handed: Dictionary = _service.call(&"validate_handoff", request)
	assert_true(handed.get("ok", false),
		"one registry-valid solo at slot zero is an accepted cause: %s" % str(handed.get("code", &"")))
	if not handed.get("ok", false):
		return
	var terminal: Dictionary = _terminal_of(handed)
	_assert_terminal_shape(terminal, "scheduled_solo", request)
	var entry: Dictionary = ((request["committed_schedule"] as Dictionary)["entries"] as Array)[0]
	assert_eq(str(terminal["schedule_entry_id"]), str(entry["schedule_entry_id"]), "entry id")
	assert_eq(str(terminal["action_id"]), str(entry["action_id"]), "action id")
	assert_eq(str(terminal["source_receipt_id"]), str(entry["source_receipt_id"]), "source id")


# The independent half of the double entry: this file recomputes row P01.schedule.day7_provenance
# from plan line 91 and requires the service's stored provenance to match it exactly. Reading the
# tokens back out of the service would prove only that it agrees with itself.
func test_terminal_provenance_consumes_byte_exact_row_p01_schedule_day7_provenance() -> void:
	if not _configured():
		return
	var built: Dictionary = _solo_request()
	if built.is_empty():
		return
	var request: Dictionary = built["request"]
	var handed: Dictionary = _service.call(&"validate_handoff", request)
	assert_true(handed.get("ok", false), str(handed.get("code", &"")))
	if not handed.get("ok", false):
		return
	var terminal: Dictionary = _terminal_of(handed)
	var provenance: Dictionary = terminal["receipt_provenance"]
	var commit_receipt: Dictionary = (request["committed_schedule"] as Dictionary)["commit_receipt"]
	var entry: Dictionary = ((request["committed_schedule"] as Dictionary)["entries"] as Array)[0]
	assert_eq(str(provenance["child_kind"]), String(CHILD_KIND), "exact child_kind")
	assert_eq(int(provenance["ordinal"]), 0, "one handoff child for the commit root")
	assert_eq(str(provenance["parent_receipt_id"]),
		str((commit_receipt["transaction_issuer_receipt"] as Dictionary)["receipt_id"]),
		"the parent is the commit's transaction issuer receipt")
	assert_eq(str(provenance["child_id"]), str(terminal["receipt_id"]),
		"the stored provenance names the receipt it minted")
	assert_eq(provenance["source_ids"], _expected_sources(request, "scheduled_solo",
		str(commit_receipt["receipt_id"]), str(entry["schedule_entry_id"]),
		str(entry["action_id"]), str(entry["source_receipt_id"])),
		"the exact sorted plan-line-91 source tokens")


func test_empty_done_row_uses_the_three_null_projections() -> void:
	if not _configured():
		return
	var request: Dictionary = _empty_done_request()
	if request.is_empty():
		return
	var handed: Dictionary = _service.call(&"validate_handoff", request)
	assert_true(handed.get("ok", false), str(handed.get("code", &"")))
	if not handed.get("ok", false):
		return
	var terminal: Dictionary = _terminal_of(handed)
	var commit_receipt: Dictionary = (request["committed_schedule"] as Dictionary)["commit_receipt"]
	assert_eq((terminal["receipt_provenance"] as Dictionary)["source_ids"],
		_expected_sources(request, "empty_done", str(commit_receipt["receipt_id"]), null, null, null),
		"empty_done projects null into all three identity paths rather than omitting them")


# ---- rejections ----

func test_handoff_rejects_everything_outside_the_two_accepted_causes() -> void:
	if not _configured():
		return
	var built: Dictionary = _solo_request()
	if built.is_empty():
		return
	var request: Dictionary = built["request"]

	var wrong_day: Dictionary = request.duplicate(true)
	((wrong_day["committed_schedule"] as Dictionary))["day"] = 6
	assert_false(_service.call(&"validate_handoff", wrong_day).get("ok", true),
		"only a Day-7 commit may produce the handoff")

	var receiptless: Dictionary = request.duplicate(true)
	((receiptless["committed_schedule"] as Dictionary))["commit_receipt"] = null
	assert_false(_service.call(&"validate_handoff", receiptless).get("ok", true),
		"a receiptless empty is not an accepted cause")

	var moved_slot: Dictionary = request.duplicate(true)
	(((moved_slot["committed_schedule"] as Dictionary)["entries"] as Array)[0] as Dictionary)["slot_index"] = 1
	assert_false(_service.call(&"validate_handoff", moved_slot).get("ok", true),
		"the solo must sit at slot zero")

	var forged_fingerprint: Dictionary = request.duplicate(true)
	((forged_fingerprint["committed_schedule"] as Dictionary))["registry_fingerprint"] = \
		"0".repeat(64)
	assert_false(_service.call(&"validate_handoff", forged_fingerprint).get("ok", true),
		"the saved fingerprint must resolve through the configured registry")

	var unresolvable: Dictionary = request.duplicate(true)
	unresolvable["source_receipt_index"] = {}
	assert_false(_service.call(&"validate_handoff", unresolvable).get("ok", true),
		"the solo's source_receipt_id must resolve in source_receipt_index")

	var forged_root: Dictionary = request.duplicate(true)
	var root_receipt: Dictionary = (forged_root["transaction_issuer_receipt"] as Dictionary).duplicate(true)
	root_receipt["receipt_id"] = "forged.receipt"
	forged_root["transaction_issuer_receipt"] = root_receipt
	assert_false(_service.call(&"validate_handoff", forged_root).get("ok", true),
		"the full transaction issuer receipt must verify against the issuer")


# Two independent layers, asserted separately. The commit port already refuses a two-entry Day 7, so
# no REAL aggregate of that shape can exist -- that refusal is asserted here rather than assumed.
# The service must still refuse the shape on its own, because it validates saved aggregates it did
# not produce, so the second half feeds it a real aggregate mutated to carry a second entry.
func test_a_multi_entry_or_non_solo_day7_commit_is_refused_by_both_layers() -> void:
	if not _configured():
		return
	var source: String = _seed_solo_source("priscilla", 7)
	assert_true(_commit("day7-two", 7, [
		_solo("d0", 0, "priscilla", 7, source), _ordinary("d1", 1, "rest", 7),
	]).is_empty(), "the commit port must refuse a two-entry Day 7 outright")

	var built: Dictionary = _solo_request()
	if built.is_empty():
		return
	var doubled: Dictionary = (built["request"] as Dictionary).duplicate(true)
	var entries: Array = (doubled["committed_schedule"] as Dictionary)["entries"]
	entries.append((entries[0] as Dictionary).duplicate(true))
	assert_false(_service.call(&"validate_handoff", doubled).get("ok", true),
		"more than one committed Day-7 entry is not an accepted cause")

	var ordinary_only: Dictionary = (built["request"] as Dictionary).duplicate(true)
	((((ordinary_only["committed_schedule"] as Dictionary)["entries"] as Array)[0]) as Dictionary)["action_kind"] = "ordinary"
	assert_false(_service.call(&"validate_handoff", ordinary_only).get("ok", true),
		"a lone ordinary action is not a scheduled_solo cause")


func test_validate_handoff_performs_no_canonical_mutation() -> void:
	if not _configured():
		return
	var built: Dictionary = _solo_request()
	if built.is_empty():
		return
	var request: Dictionary = built["request"]
	var before: String = _canonical(request)
	var handed: Dictionary = _service.call(&"validate_handoff", request)
	assert_true(handed.get("ok", false), str(handed.get("code", &"")))
	assert_eq(_canonical(request), before, "validate_handoff must not mutate its request")
	if not handed.get("ok", false):
		return
	var terminal: Dictionary = _terminal_of(handed)
	assert_eq(_canonical(handed.get("receipt", {})), _canonical(terminal),
		"the outer receipt is an exact detached copy of terminal_provenance")
	(handed.get("receipt", {}) as Dictionary)["receipt_id"] = "mutated"
	assert_ne(str(terminal["receipt_id"]), "mutated",
		"the outer receipt must be detached, not the same reference")


func test_terminal_provenance_carries_no_forbidden_member() -> void:
	if not _configured():
		return
	var request: Dictionary = _empty_done_request()
	if request.is_empty():
		return
	var handed: Dictionary = _service.call(&"validate_handoff", request)
	assert_true(handed.get("ok", false), str(handed.get("code", &"")))
	if not handed.get("ok", false):
		return
	var serialized: String = _canonical(_terminal_of(handed))
	for forbidden: String in FORBIDDEN_MEMBERS:
		assert_false(serialized.contains("\"%s\"" % forbidden),
			"plan line 503 forbids %s anywhere in the handoff" % forbidden)


# ---- helpers ----

func _terminal_of(handed: Dictionary) -> Dictionary:
	return ((handed.get("value", {}) as Dictionary).get("terminal_provenance", {}) as Dictionary)


func _assert_terminal_shape(terminal: Dictionary, cause: String, request: Dictionary) -> void:
	var keys: Array = terminal.keys()
	keys.sort()
	assert_eq(keys, TERMINAL_KEYS, "the exact 11-member terminal_provenance")
	if keys != TERMINAL_KEYS:
		return
	var committed: Dictionary = request["committed_schedule"]
	assert_eq(str(terminal["kind"]), String(CHILD_KIND), "kind")
	assert_eq(int(terminal["day"]), 7, "day is exactly 7")
	assert_eq(str(terminal["cause"]), cause, "cause")
	assert_eq(str(terminal["causal_day_instance"]), str(request["causal_day_instance"]),
		"causal_day_instance")
	assert_eq(str(terminal["registry_fingerprint"]), str(committed["registry_fingerprint"]),
		"the saved fingerprint, not a current one")
	assert_eq(str(terminal["schedule_commit_receipt_id"]),
		str((committed["commit_receipt"] as Dictionary)["receipt_id"]), "commit receipt id")
	assert_typeof(terminal["receipt_provenance"], TYPE_DICTIONARY, "the full stored provenance")


## Row P01.schedule.day7_provenance, plan line 91, rebuilt here from the plan text alone.
func _expected_sources(request: Dictionary, cause: String, commit_receipt_id: String,
		schedule_entry_id: Variant, action_id: Variant, source_receipt_id: Variant) -> Array:
	var committed: Dictionary = request["committed_schedule"]
	var tokens: Array = [
		_project("role", "schedule.day7_provenance"),
		_project("transaction_id", str(request["transaction_id"])),
		_project("causal_day_instance", str(request["causal_day_instance"])),
		_project("day", 7),
		_project("cause", cause),
		_project("registry_fingerprint", str(committed["registry_fingerprint"])),
		_project("schedule_commit_receipt_id", commit_receipt_id),
		_project("schedule_entry_id", schedule_entry_id),
		_project("action_id", action_id),
		_project("source_receipt_id", source_receipt_id),
	]
	tokens.sort()
	return tokens


func _project(path: String, value: Variant) -> String:
	return path + "=" + _canonical(value)


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


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


func _seed_solo_source(friend_id: String, day: int) -> String:
	var action_id: String = "solo:%s:day%d" % [friend_id, day]
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		_game_state.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	var command: Dictionary = _command("open.%s.day%d" % [friend_id, day])
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, day, command["id"], command["receipt"],
		_issuer, _record(action_id))
	assert_true(opened.get("ok", false), str(opened))
	_game_state.contacts = opened["value"]["candidate"]
	var receipt: Dictionary = (opened["receipt"] as Dictionary).duplicate(true)
	_source_receipts[str(receipt["receipt_id"])] = receipt
	return str(receipt["receipt_id"])


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


func _solo(draft_entry_id: String, slot_index: int, friend_id: String, day: int,
		source_receipt_id: String) -> Dictionary:
	return _draft(draft_entry_id, slot_index, "solo:%s:day%d" % [friend_id, day], "solo",
		[friend_id], source_receipt_id, day)


## Runs a REAL commit through the production port and returns {request, prepared}, or {} when the
## port refused -- callers then skip that row rather than assert against a phantom aggregate.
func _commit(label: String, day: int, drafts: Array) -> Dictionary:
	# The owner refuses a commit for a day other than the one it currently holds, so the run has to
	# actually be on that day before the port will produce a real aggregate.
	_game_state._lifecycle_set_playing_day(day)
	var command: Dictionary = _command(label)
	var request: Dictionary = {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	}
	var prepared: Dictionary = _port.call(&"prepare_commit", request)
	if not prepared.get("ok", false):
		_last_rejection = "%s: %s %s" % [
			label, str(prepared.get("code", &"")), str(prepared.get("message", "")),
		]
		return {}
	_last_rejection = ""
	return {"request": request, "prepared": (prepared.get("value", {}) as Dictionary).duplicate(true)}


func _handoff(committed: Dictionary) -> Dictionary:
	var request: Dictionary = committed["request"]
	var prepared: Dictionary = committed["prepared"]
	return {
		"transaction_id": str(request["transaction_id"]),
		"transaction_issuer_receipt": (request["transaction_issuer_receipt"] as Dictionary).duplicate(true),
		"causal_day_instance": str(request["causal_day_instance"]),
		"committed_schedule": (prepared["committed_schedule"] as Dictionary).duplicate(true),
		"source_receipt_index": _source_receipts.duplicate(true),
	}


func _empty_done_request() -> Dictionary:
	var committed: Dictionary = _commit("day7-empty", 7, [])
	if committed.is_empty():
		assert_true(false, "the production port must be able to commit a Day-7 empty aggregate: " + _last_rejection)
		return {}
	return _handoff(committed)


func _solo_request() -> Dictionary:
	var source: String = _seed_solo_source("priscilla", 7)
	var committed: Dictionary = _commit("day7-solo", 7, [_solo("d0", 0, "priscilla", 7, source)])
	if committed.is_empty():
		assert_true(false, "the production port must be able to commit one Day-7 solo at slot zero: " + _last_rejection)
		return {}
	return {"request": _handoff(committed), "source_receipt_id": source}
