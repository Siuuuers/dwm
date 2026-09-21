extends RefCounted

## The Dating half of the frozen Schedule-Done presentation-port contract (Plan 01 Task 8,
## dwm-p2r.14).
##
## Bootstrap retains and configures DatingPhysicalOwner. Unconfigured instances still fail
## closed, and every command/receipt remains bound to the same admitted Schedule or Hospital
## presentation identity. This port neither decides board outcomes nor applies relationship effects.
##
## THE PARTICIPANT ORDER IS SEMANTIC, NOT ALPHABETICAL. The P-L group/pair order is exactly
## `priscilla,lavinia` and is NOT sorted, because that order is owned by the pair's own invitation
## law rather than by this port.
##
## ANCESTRY NOTE (DEVIATION-4, recorded on dwm-p2r.14). As with the Hospital port, `stage_id` is
## carried and projected exactly as the producer supplies it, because Plan 01 Tasks 6/7 never lit up
## `P01.day_resolution.stage` as an issuer-derived child on the production path. The completion
## transaction IS a real issuer child and is fully verified here.

const _STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

const ROUTE_ID := "dating"
const OWNER_KIND := "dating_challenge"
const COMPLETION_CHILD_KIND := &"day_resolution_stage"
const ROOT_PURPOSE := &"transaction_id"
const COMPLETION_ROLE := "presentation.completion"
const STATUS_COMPLETED := "completed"

## The three accepted dating context kinds, frozen by the plan.
const CONTEXT_KINDS: Array[String] = ["group", "solo", "twofriends_if_deferred"]
## The canonical pair order. Owned by the invitation law, so it is asserted rather than sorted.
const PAIR_PARTICIPANTS: Array[String] = ["priscilla", "lavinia"]

## Exact `begin()` request members (sorted), frozen by the plan.
const REQUEST_KEYS: Array[String] = [
	"completion_transaction_id", "completion_transaction_provenance", "context", "resolution_id",
	"resolution_issuer_receipt", "route_id", "stage_id", "substage_id", "timeline_id",
]
## Exact Dating `context` members (sorted), frozen by the plan.
const CONTEXT_KEYS: Array[String] = [
	"day", "kind", "participants", "schedule_entry_id",
]
## Exact `complete()` request members (sorted).
const COMPLETE_KEYS: Array[String] = [
	"physical_completion_receipt", "presentation_command",
]
## Exact physical-owner receipt members (sorted).
const OWNER_RECEIPT_KEYS: Array[String] = [
	"command_sha256", "completion_transaction_id", "owner_kind", "physical_token", "result",
	"status",
]
## Exact port completion-receipt members (sorted), frozen by the plan.
const COMPLETION_RECEIPT_KEYS: Array[String] = [
	"command_sha256", "physical_completion_receipt", "physical_owner_kind", "physical_token",
	"receipt_id", "receipt_provenance", "resolution_id", "route_id", "stage_id", "substage_id",
	"timeline_id",
]

const _ISSUER_METHODS: Array[String] = ["verify_issued", "derive_child", "validate_child"]
const _OWNER_METHODS: Array[String] = ["begin_physical", "validate_physical_completion"]

signal completion_ready(completion_result: Dictionary)
signal completion_failed(failure: Dictionary)

var _identity_issuer: Object = null
var _physical_owner: Object = null
var _narrative_playback: Object = null
## completion_transaction_id -> the exact canonical command this port issued. Ephemeral projection
## of the coordinator-owned pending command, never a second canonical gameplay ledger.
var _commands: Dictionary = {}
## completion_transaction_id -> the exact settled completion receipt. Replay returns these bytes.
var _settled: Dictionary = {}


## Retains the exact `.16` issuer and the ONE dating-challenge owner, and connects that exact
## owner's two physical-completion signals once. Identical replay is idempotent; a replacement in
## either position is refused. Bootstrap supplies the one retained physical owner.
func configure(identity_issuer: Object, physical_owner: Object) -> Dictionary:
	if identity_issuer == null or not _has_methods(identity_issuer, _ISSUER_METHODS):
		return _fail(&"invalid_identity_issuer", "the issuer contract is incomplete", {})
	var owner_error := _owner_error(physical_owner)
	if owner_error != "":
		return _fail(&"invalid_physical_owner", owner_error, {})
	if _identity_issuer != null or _physical_owner != null:
		if _identity_issuer == identity_issuer and _physical_owner == physical_owner:
			return _ok({"configured": true, "already_configured": true,
				"owner_instance_id": physical_owner.get_instance_id()})
		return _fail(&"presentation_port_already_configured",
			"a configured port never adopts a replacement dependency", {})
	_identity_issuer = identity_issuer
	_physical_owner = physical_owner
	if not physical_owner.is_connected("physical_completion_ready", _on_physical_completion_ready):
		physical_owner.connect("physical_completion_ready", _on_physical_completion_ready)
	if not physical_owner.is_connected("physical_completion_failed", _on_physical_completion_failed):
		physical_owner.connect("physical_completion_failed", _on_physical_completion_failed)
	return _ok({"configured": true, "already_configured": false,
		"owner_instance_id": physical_owner.get_instance_id()})


## Validates one committed-Schedule dating intent end to end, then starts the physical presentation.
##
## An unconfigured port refuses before any routing or physical start.
func configure_narrative_playback(playback: Object) -> Dictionary:
	if playback == null or not _has_methods(playback, ["begin_presentation", "begin_phase", "pull_phase", "finish_phase"]):
		return _fail(&"dating_narrative_unavailable", "", {})
	if _narrative_playback != null and _narrative_playback != playback:
		return _fail(&"dating_narrative_already_configured", "", {})
	_narrative_playback = playback
	return _ok({})

func attach_narrative_presentation(presentation_command: Dictionary) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.ok: return trusted
	if _narrative_playback == null: return _fail(&"dating_narrative_unavailable", "", {})
	return _narrative_playback.begin_presentation(trusted.value)

func begin_narrative_phase(presentation_command: Dictionary, retry: bool = false) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.ok: return trusted
	if _narrative_playback == null: return _fail(&"dating_narrative_unavailable", "", {})
	var pulled := pull_physical(presentation_command)
	if not pulled.get("ok", false): return pulled
	if _is_pair_explosion_cutoff(trusted.value, pulled.value):
		return _ok({"status": "completed", "reason": "pair_explosion_cutoff"})
	return _narrative_playback.begin_phase(trusted.value, str(pulled.value.phase), retry)

func pull_narrative_phase(presentation_command: Dictionary) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.ok: return trusted
	if _narrative_playback == null: return _fail(&"dating_narrative_unavailable", "", {})
	var pulled := pull_physical(presentation_command)
	if not pulled.get("ok", false): return pulled
	if _is_pair_explosion_cutoff(trusted.value, pulled.value):
		return _ok({"status": "completed", "reason": "pair_explosion_cutoff"})
	return _narrative_playback.pull_phase(trusted.value, str(pulled.value.phase))

## Angela-absent pair explosions end the encounter. This is a physical cutoff, not
## a manufactured Dialogic completion or a witnessed post-challenge presentation.
static func _is_pair_explosion_cutoff(command: Dictionary, view: Dictionary) -> bool:
	return command.get("context", {}).get("kind") == "twofriends_if_deferred" \
		and view.get("phase") == "post_challenge" and view.get("outcome") == "exploded"

func begin(request: Dictionary) -> Dictionary:
	if _identity_issuer == null or _physical_owner == null:
		return _fail(&"dating_physical_owner_unconfigured",
			"The canonical Dating physical owner has not been configured", {})
	var validated := _validate_request(request)
	if not validated.get("ok", false):
		return validated

	var completion_id := str(request["completion_transaction_id"])
	var hashed: Dictionary = _STATE_SCHEMA.canonical_sha256(request)
	if not hashed.get("ok", false):
		return _fail(&"invalid_presentation_intent",
			"the request is not canonically representable", {})
	var command_sha256 := str((hashed["value"] as Dictionary)["sha256"])

	if _commands.has(completion_id):
		var existing: Dictionary = _commands[completion_id]
		if str(existing["command_sha256"]) != command_sha256:
			return _fail(&"presentation_command_conflict",
				"this completion transaction already carries different command bytes", {})
		# Loading an earlier active date can supersede the physical owner's last admitted date.
		# Re-adopt the exact cached command; the owner restores its saved board and never rerolls it.
		var resumed: Variant = _physical_owner.call(&"begin_physical", existing.duplicate(true))
		if not resumed is Dictionary or not resumed.get("ok", false):
			return resumed if resumed is Dictionary else _fail(
				&"physical_presentation_unavailable", "the owner returned no result", {})
		if not resumed.get("value") is Dictionary or str(resumed.value.get("physical_token", "")) != str(existing.physical_token) \
				or str(resumed.value.get("command_sha256", "")) != command_sha256:
			return _fail(&"physical_presentation_unavailable", "restored command binding changed", {})
		return _ok({"presentation_command": existing.duplicate(true)})

	var command := request.duplicate(true)
	command["command_sha256"] = command_sha256
	var started: Variant = _physical_owner.call(&"begin_physical", command.duplicate(true))
	if typeof(started) != TYPE_DICTIONARY or not (started as Dictionary).get("ok", false):
		return started if typeof(started) == TYPE_DICTIONARY else _fail(
			&"physical_presentation_unavailable", "the owner returned no result", {})
	var value: Dictionary = (started as Dictionary)["value"]
	var physical_token := str(value.get("physical_token", ""))
	if physical_token.strip_edges().is_empty() \
			or str(value.get("command_sha256", "")) != command_sha256:
		return _fail(&"physical_presentation_unavailable",
			"the owner returned no nonblank token bound to these command bytes", {})
	command["physical_token"] = physical_token
	_commands[completion_id] = command.duplicate(true)
	return _ok({"presentation_command": command.duplicate(true)})


## Turns one owner-validated physical completion into the exact frozen completion receipt. The
## physical receipt is proved by the CONFIGURED OWNER; any drift returns
## `physical_completion_untrusted` before a domain stage mutation can be requested.
func complete(request: Dictionary) -> Dictionary:
	if _identity_issuer == null or _physical_owner == null:
		return _fail(&"dating_physical_owner_unconfigured",
			"The canonical Dating physical owner has not been configured", {})
	var shaped := _exact_keys(request, COMPLETE_KEYS, &"invalid_presentation_completion")
	if not shaped.is_empty():
		return shaped
	if typeof(request["presentation_command"]) != TYPE_DICTIONARY \
			or typeof(request["physical_completion_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_presentation_completion", "both members must be dictionaries", {})
	var command: Dictionary = request["presentation_command"]
	var owner_receipt: Dictionary = request["physical_completion_receipt"]
	var completion_id := str(command.get("completion_transaction_id", ""))
	if not _commands.has(completion_id):
		return _fail(&"physical_completion_untrusted",
			"this port issued no command for that completion transaction", {})
	if command != (_commands[completion_id] as Dictionary):
		return _fail(&"presentation_command_conflict",
			"the supplied command is not the one this port issued", {})
	var owner_shape := _exact_keys(owner_receipt, OWNER_RECEIPT_KEYS,
		&"physical_completion_untrusted")
	if not owner_shape.is_empty():
		return owner_shape
	if str(owner_receipt["owner_kind"]) != OWNER_KIND \
			or str(owner_receipt["status"]) != STATUS_COMPLETED \
			or str(owner_receipt["physical_token"]) != str(command["physical_token"]) \
			or str(owner_receipt["command_sha256"]) != str(command["command_sha256"]) \
			or str(owner_receipt["completion_transaction_id"]) != completion_id:
		return _fail(&"physical_completion_untrusted",
			"the physical receipt does not bind this exact command", {})

	var proven: Variant = _physical_owner.call(&"validate_physical_completion", {
		"presentation_command": command.duplicate(true),
		"physical_completion_receipt": owner_receipt.duplicate(true),
	})
	if typeof(proven) != TYPE_DICTIONARY or not (proven as Dictionary).get("ok", false):
		return _fail(&"physical_completion_untrusted",
			"the configured owner refused the physical receipt",
			{"cause": (proven as Dictionary).get("code", &"") if typeof(proven) == TYPE_DICTIONARY else &"invalid_result"})

	var receipt := {
		"receipt_id": completion_id,
		"receipt_provenance": (command["completion_transaction_provenance"] as Dictionary).duplicate(true),
		"resolution_id": str(command["resolution_id"]),
		"stage_id": str(command["stage_id"]),
		"substage_id": str(command["substage_id"]),
		"route_id": ROUTE_ID,
		"timeline_id": str(command["timeline_id"]),
		"command_sha256": str(command["command_sha256"]),
		"physical_owner_kind": OWNER_KIND,
		"physical_token": str(command["physical_token"]),
		"physical_completion_receipt": owner_receipt.duplicate(true),
	}
	var keys: Array = receipt.keys()
	keys.sort()
	if keys != COMPLETION_RECEIPT_KEYS:
		return _fail(&"invalid_presentation_completion",
			"the completion receipt member set is not exact", {})
	if _settled.has(completion_id):
		if receipt != (_settled[completion_id] as Dictionary):
			return _fail(&"physical_completion_conflict",
				"this completion transaction already settled with different bytes", {})
		return _completion_result(receipt)
	_settled[completion_id] = receipt.duplicate(true)
	return _completion_result(receipt)


## Deliberately FALSE in the Phase-2R production graph. Bootstrap evidence reports it as such, so a
## fail-closed Dating route is visible rather than mistaken for a working board.
func is_ready() -> bool:
	return _identity_issuer != null and _physical_owner != null


## UI facade over the sole configured owner. The scene supplies the exact command returned by
## begin(); the port never accepts a token detached from its issuer-bound command bytes.
func pull_physical(presentation_command: Dictionary) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.get("ok", false):
		return trusted
	if not _physical_owner.has_method("pull_physical"):
		return _fail(&"physical_presentation_unavailable",
			"the configured owner exposes no physical view", {})
	var command: Dictionary = trusted["value"]
	var result: Variant = _physical_owner.call(&"pull_physical", str(command["physical_token"]))
	return result if result is Dictionary else _fail(&"physical_presentation_unavailable",
		"the owner returned no physical view", {})


func acknowledge_pre_challenge_render(presentation_command: Dictionary) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.ok: return trusted
	if not _physical_owner.has_method("acknowledge_pre_challenge_render"):
		return _fail(&"presentation_history_unavailable", "No canonical rendered-presentation owner", {})
	return _physical_owner.acknowledge_pre_challenge_render(str(trusted.value.physical_token))

func acknowledge_post_challenge_render(presentation_command: Dictionary) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.ok: return trusted
	if not _physical_owner.has_method("acknowledge_post_challenge_render"):
		return _fail(&"presentation_history_unavailable", "No canonical rendered-presentation owner", {})
	return _physical_owner.acknowledge_post_challenge_render(str(trusted.value.physical_token))

func pull_observer(presentation_command: Dictionary) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.ok: return trusted
	if not _physical_owner.has_method("pull_observer"): return _ok({})
	return _physical_owner.pull_observer(str(trusted.value.physical_token))

func dispatch_observer(presentation_command: Dictionary, atom_id: String, action: String,
		elapsed_ms: int = 0) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.ok: return trusted
	if not _physical_owner.has_method("dispatch_observer"):
		return _fail(&"observer_unavailable", "No admitted scene moment", {})
	return _physical_owner.dispatch_observer(str(trusted.value.physical_token), atom_id, action, elapsed_ms)

func dispatch_physical(presentation_command: Dictionary, action: String, cell_index: int,
		expected_revision: int) -> Dictionary:
	var trusted := _trusted_physical_command(presentation_command)
	if not trusted.get("ok", false):
		return trusted
	if not _physical_owner.has_method("dispatch_physical"):
		return _fail(&"physical_presentation_unavailable",
			"the configured owner exposes no physical commands", {})
	var command: Dictionary = trusted["value"]
	var narrative_phase := ""
	if _narrative_playback != null and action == "continue":
		var pulled: Dictionary = pull_physical(command)
		if not pulled.get("ok", false): return pulled
		if str(pulled.value.phase) in ["pre_challenge", "post_challenge"] \
				and not _is_pair_explosion_cutoff(command, pulled.value):
			narrative_phase = str(pulled.value.phase)
			var playback: Dictionary = _narrative_playback.pull_phase(command, narrative_phase)
			if not playback.get("ok", false): return playback
			if playback.value.get("status") != "completed":
				return _fail(&"dating_narrative_not_complete", "", {})
	var result: Variant = _physical_owner.call(&"dispatch_physical",
		str(command["physical_token"]), action, cell_index, expected_revision)
	if result is Dictionary and result.get("ok", false) and not narrative_phase.is_empty():
		_narrative_playback.finish_phase(command, narrative_phase)
	return result if result is Dictionary else _fail(&"physical_presentation_unavailable",
		"the owner returned no physical command result", {})


func _trusted_physical_command(candidate: Dictionary) -> Dictionary:
	if _physical_owner == null:
		return _fail(&"dating_physical_owner_unconfigured",
			"the dating presentation has no physical owner", {})
	var completion_id := str(candidate.get("completion_transaction_id", ""))
	if completion_id.is_empty() or not _commands.has(completion_id) \
			or candidate != (_commands[completion_id] as Dictionary):
		return _fail(&"presentation_command_conflict",
			"the UI command is not the exact command issued by this port", {})
	return _ok(candidate.duplicate(true))


# -------------------------------------------------------------------------------------------------
# validation
# -------------------------------------------------------------------------------------------------

func _validate_request(request: Dictionary) -> Dictionary:
	if typeof(request) != TYPE_DICTIONARY:
		return _fail(&"invalid_presentation_intent", "the request must be a dictionary", {})
	var shaped := _exact_keys(request, REQUEST_KEYS, &"invalid_presentation_intent")
	if not shaped.is_empty():
		return shaped
	for field: String in ["resolution_id", "stage_id", "substage_id", "timeline_id",
			"completion_transaction_id"]:
		if not _is_nonblank_string(request[field]):
			return _fail(&"invalid_presentation_intent", field + " must be a nonblank String", {})
	if str(request["route_id"]) != ROUTE_ID:
		return _fail(&"presentation_route_mismatch",
			"this port routes only " + ROUTE_ID, {"route_id": request["route_id"]})
	if not DialogicTimelineCatalog.has_timeline_id(str(request["timeline_id"])):
		return _fail(&"unregistered_presentation_timeline",
			"the locator is not registered in DialogicTimelineCatalog",
			{"timeline_id": request["timeline_id"]})
	var context_error := _context_error(request["context"])
	if context_error != "":
		return _fail(&"invalid_presentation_context", context_error, {})
	if typeof(request["resolution_issuer_receipt"]) != TYPE_DICTIONARY \
			or typeof(request["completion_transaction_provenance"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_presentation_intent",
			"the root receipt and child provenance must be dictionaries", {})

	var root: Dictionary = request["resolution_issuer_receipt"]
	var verified: Variant = _identity_issuer.call(&"verify_issued", root.duplicate(true),
		ROOT_PURPOSE)
	if typeof(verified) != TYPE_DICTIONARY or not (verified as Dictionary).get("ok", false):
		return _fail(&"presentation_root_unverified",
			"the resolution issuer receipt did not verify", {})
	return _validate_completion_child(request, root)


## Proves `completion_transaction_id` / `completion_transaction_provenance` are exactly the
## `P01.presentation.completion` child for THIS request. The projection is re-derived from the
## request's own bytes, so a changed participant list, day, entry, route, timeline, stage or
## substage cannot reuse a completion child anchored to different bytes.
func _validate_completion_child(request: Dictionary, root: Dictionary) -> Dictionary:
	var provenance: Dictionary = request["completion_transaction_provenance"]
	var revalidated: Variant = _identity_issuer.call(&"validate_child", provenance.duplicate(true),
		COMPLETION_CHILD_KIND)
	if typeof(revalidated) != TYPE_DICTIONARY or not (revalidated as Dictionary).get("ok", false):
		return _fail(&"presentation_completion_unverified",
			"the completion provenance did not revalidate through the issuer", {})
	if str(provenance.get("child_id", "")) != str(request["completion_transaction_id"]):
		return _fail(&"presentation_completion_unverified",
			"the completion id disagrees with its own provenance", {})
	if str(provenance.get("parent_receipt_id", "")) != str(root.get("receipt_id", "")):
		return _fail(&"presentation_completion_unverified",
			"the completion child is not parented to this resolution root", {})

	var expected := _completion_sources(request)
	if expected.is_empty():
		return _fail(&"invalid_presentation_intent",
			"the completion projection is not canonically representable", {})
	var actual: Variant = provenance.get("source_ids")
	if typeof(actual) != TYPE_ARRAY or (actual as Array) != expected:
		return _fail(&"presentation_completion_unverified",
			"the completion provenance does not project these exact bytes",
			{"expected": expected, "actual": actual})
	return _ok({"validated": true})


## The exact `P01.presentation.completion` source projection (plan line 98), sorted.
func _completion_sources(request: Dictionary) -> Array:
	var context_hash: Dictionary = _STATE_SCHEMA.canonical_sha256(request["context"])
	if not context_hash.get("ok", false):
		return []
	var tokens: Array = [
		_project("role", COMPLETION_ROLE),
		_project("resolution_id", str(request["resolution_id"])),
		_project("stage_id", str(request["stage_id"])),
		_project("substage_id", str(request["substage_id"])),
		_project("route_id", ROUTE_ID),
		_project("timeline_id", str(request["timeline_id"])),
		_project("context_sha256", str((context_hash["value"] as Dictionary)["sha256"])),
	]
	for token: String in tokens:
		if token.is_empty():
			return []
	tokens.sort()
	return tokens


## The exact dating context. `schedule_entry_id` is nullable only where the plan allows it, and the
## participant list is checked against its OWNED order rather than sorted.
func _context_error(context: Variant) -> String:
	if typeof(context) != TYPE_DICTIONARY:
		return "context must be a dictionary"
	var keys: Array = (context as Dictionary).keys()
	keys.sort()
	if keys != CONTEXT_KEYS:
		return "the context member set is not exact: " + str(keys)
	var detached: Dictionary = context as Dictionary
	var kind := str(detached["kind"])
	if not CONTEXT_KINDS.has(kind):
		return "the dating context kind is one of " + str(CONTEXT_KINDS)
	if typeof(detached["day"]) != TYPE_INT or int(detached["day"]) < 1 or int(detached["day"]) > 7:
		return "day must be an int in 1..7"
	if detached["schedule_entry_id"] != null \
			and not _is_nonblank_string(detached["schedule_entry_id"]):
		return "schedule_entry_id must be null or a nonblank String"
	var participants: Variant = detached["participants"]
	if typeof(participants) != TYPE_ARRAY:
		return "participants must be an Array of String"
	for element: Variant in (participants as Array):
		if typeof(element) != TYPE_STRING or str(element).strip_edges().is_empty():
			return "participants must be an Array of nonblank String"
	if kind == "solo":
		if (participants as Array).size() != 1:
			return "a solo names exactly one participant"
		return ""
	# Both the group date and the deferred pair are the canonical P-L pair, in that exact order.
	if (participants as Array) != PAIR_PARTICIPANTS:
		return "the pair order is exactly " + str(PAIR_PARTICIPANTS)
	return ""


# -------------------------------------------------------------------------------------------------
# the async trusted completion path
# -------------------------------------------------------------------------------------------------

func _on_physical_completion_ready(receipt: Dictionary) -> void:
	if typeof(receipt) != TYPE_DICTIONARY:
		completion_failed.emit(_fail(&"physical_completion_untrusted",
			"the owner emitted a non-dictionary receipt", {}))
		return
	var completion_id := str(receipt.get("completion_transaction_id", ""))
	if not _commands.has(completion_id):
		completion_failed.emit(_fail(&"physical_completion_untrusted",
			"no in-flight command matches the emitted completion",
			{"completion_transaction_id": completion_id}))
		return
	var already_settled := _settled.has(completion_id)
	var result := complete({
		"presentation_command": (_commands[completion_id] as Dictionary).duplicate(true),
		"physical_completion_receipt": receipt.duplicate(true),
	})
	if not result.get("ok", false):
		completion_failed.emit(result)
		return
	if already_settled:
		return
	completion_ready.emit(result)


func _on_physical_completion_failed(failure: Dictionary) -> void:
	completion_failed.emit(failure.duplicate(true) if typeof(failure) == TYPE_DICTIONARY
		else _fail(&"physical_presentation_failed", "the owner failed without a result", {}))


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

## Accepts any owner that DECLARES the dating-challenge kind, deliberately not a fixed class: the
## real owner is `dwm-oyo.4`'s to write, and pinning this port to a script that does not exist yet
## would make the handoff impossible to satisfy. The narrative adapter declares `narrative` and so
## can never be mistaken for a dating board here.
func _owner_error(physical_owner: Object) -> String:
	if physical_owner == null or not _has_methods(physical_owner, _OWNER_METHODS):
		return "the physical owner contract is incomplete"
	if not physical_owner.has_signal("physical_completion_ready") \
			or not physical_owner.has_signal("physical_completion_failed"):
		return "the physical owner declares no completion signals"
	if not physical_owner.has_method("owner_kind") \
			or str(physical_owner.call(&"owner_kind")) != OWNER_KIND:
		return "the Dating port accepts only an owner declaring owner_kind=" + OWNER_KIND
	return ""


static func _completion_result(receipt: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok",
		"value": {"completion_receipt": receipt.duplicate(true)},
		"receipt": receipt.duplicate(true)}


static func _project(path: String, value: Variant) -> String:
	var canonical: Dictionary = _STATE_SCHEMA.canonical_json(value)
	if not canonical.get("ok", false):
		return ""
	return path + "=" + str((canonical["value"] as Dictionary)["text"])


func _exact_keys(value: Dictionary, expected: Array[String], code: StringName) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(code, "the member set is not exact", {"expected": expected, "actual": keys})
	return {}


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true


static func _is_nonblank_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty()


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
