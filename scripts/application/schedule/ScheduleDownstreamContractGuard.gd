class_name ScheduleDownstreamContractGuard
extends RefCounted

## Executable downstream-contract guard (Amendment Plan 03 Task 1 Step 4, dwm-oyo.3, created under
## the full dwm-oyo.3 grant recorded 2026-09-02 on the bead). It locks the `.7` Schedule and `.9`
## desktop transaction contracts this plan composes but never reimplements: every shape it checks
## comes from the consumed-interface-lock section of
## docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-03-seven-day-flow-integration.md,
## which is the sole authority over this file -- with ONE recorded exception below.
##
## DEVIATION-18 RULING 18-A (maintainer AskUserQuestion, recorded 2026-09-02 on dwm-oyo.3; HYBRID:
## fix safety, defer shapes). `validate_day_resolution_start_result()` validates the SHIPPED
## Plan-01 day-start shapes -- success value {start_receipt, committed_schedule, route_plan,
## schedule_commit_receipt_id, board_fate_receipt_id} with the shipped eight-member start receipt
## (no registry_fingerprint) -- rather than the lock's {day_resolution_candidate, resolution_plan,
## day_resolution_start_receipt} shape; that divergence is reconciled by the first consuming task
## (Task 6/7), never patched in a second owner. One further characterized-from-shipped shape,
## recorded honestly beside it: the lock fixes prepare_admission's SEMANTICS but pins no
## success-value schema (plan line 99), so `validate_causal_admission_result()` checks the
## combined-candidate value the shipped DesktopCausalSequencePort returns. Every other validator
## checks the lock verbatim.
##
## PURE BY LAW (plan Task 1 "Interfaces"): no domain state, no mutation authority. Every method is
## a static function of its arguments. `validate_ports()` checks frozen method presence on the six
## injected production participants without calling any mutation; the board-fate check requires
## BOTH the current-board and the projected-action prepare methods, and the coordinator check
## requires the (Ruling 18-A stubbed) Schedule-departure extension pair.
##
## VERDICT SEMANTICS (frozen by the Task-1 RED suite): each `validate_*_result()` checks one
## participant result against the master envelope. A conforming SUCCESS -- exactly
## {ok, code, value, receipt} with that participant's exact candidate/receipt schema (the
## board-fate validator requires both nullable source-action receipt members in every fate
## receipt) -- and a conforming FAILURE -- exactly {ok, code, message, details} -- both return
## ok:true with value naming which form was seen. Any deviation fails closed naming the exact
## member or schema difference, so a predecessor mismatch is returned to Plan 01 or Plan 02.

const _SUCCESS_KEYS: Array = ["code", "ok", "receipt", "value"]
const _FAILURE_KEYS: Array = ["code", "details", "message", "ok"]

const _SOURCE_KINDS: Array[String] = ["minesweeper_round", "shop_purchase", "schedule_done"]
const _FATES: Array[String] = ["none", "discarded_unstarted", "forfeited_started"]
const _DISPOSITIONS: Array[String] = ["no_departure", "departure_committed"]
const _DAY7_CAUSES: Array[String] = ["empty_done", "scheduled_solo"]

const _SCHEDULE_VALUE_KEYS: Array = [
	"committed_schedule", "game_state_candidate", "route_plan", "schedule_commit_receipt",
]
const _SCHEDULE_RECEIPT_KEYS: Array = [
	"causal_day_instance", "day", "motivation_charged", "receipt_id", "receipt_provenance",
	"registry_fingerprint", "schedule_entry_ids", "source_receipt_ids", "transaction_id",
	"transaction_issuer_receipt", "view_fingerprint",
]
const _AGGREGATE_KEYS: Array = [
	"commit_receipt", "day", "entries", "registry_fingerprint", "schema_version",
]
const _DAY7_TERMINAL_KEYS: Array = [
	"action_id", "causal_day_instance", "cause", "day", "kind", "receipt_id",
	"receipt_provenance", "registry_fingerprint", "schedule_commit_receipt_id",
	"schedule_entry_id", "source_receipt_id",
]
const _RESERVATION_VALUE_KEYS: Array = ["causal_sequence_receipt", "sequence_candidate"]
const _SEQUENCE_RECEIPT_KEYS: Array = [
	"branch_id", "causal_day_instance", "causal_sequence", "desktop_timeline_generation",
	"receipt_id", "receipt_provenance", "run_id", "run_revision", "source_commit_receipt_id",
	"source_commit_receipt_provenance", "source_kind", "transaction_id",
	"transaction_issuer_receipt",
]
const _ADMISSION_CANDIDATE_KEYS: Array = [
	"admission_checkpoint_candidate", "recovery_payload_sha256", "sequence_candidate",
	"transaction_id",
]
const _CAUSAL_COMMIT_KEYS: Array = ["admission_checkpoint_receipt", "causal_sequence_receipt"]
const _BOARD_FATE_VALUE_KEYS: Array = ["board_candidate", "board_fate_receipt"]
const _BOARD_FATE_RECEIPT_KEYS: Array = [
	"board_identity", "board_revision", "causal_day_instance", "command_id",
	"command_issuer_receipt", "fate", "receipt_id", "receipt_provenance",
	"source_action_commit_receipt_id", "source_action_commit_receipt_provenance",
]
const _CONSEQUENCE_VALUE_KEYS: Array = [
	"board_fate_receipt", "causal_sequence", "condition_receipt", "destination_intent",
	"notification_intent", "schedule_view_commit_receipt",
]
const _CONSEQUENCE_RECEIPT_KEYS: Array = [
	"action_commit_receipt_id", "action_commit_receipt_provenance", "causal_sequence",
	"disposition", "receipt_id", "receipt_provenance",
]
const _DAY_START_VALUE_KEYS: Array = [
	"board_fate_receipt_id", "committed_schedule", "route_plan", "schedule_commit_receipt_id",
	"start_receipt",
]
const _DAY_START_RECEIPT_KEYS: Array = [
	"board_fate_receipt_id", "causal_day_instance", "receipt_id", "receipt_provenance",
	"resolution_id", "schedule_commit_receipt_id", "schedule_entry_ids", "source_day",
]

## Frozen method census per injected participant, in validate_ports() argument order.
const _PORT_METHOD_ROWS: Array = [
	["schedule_port", ["prepare_commit", "capture", "commit", "rollback", "publish"]],
	["day7_provenance", ["configure", "validate_handoff"]],
	["causal_sequence_port", ["configure", "prepare_reservation", "prepare_admission", "capture",
		"commit", "rollback", "publish"]],
	["board_fate_port", ["prepare_causal_departure", "prepare_projected_causal_departure",
		"capture", "commit", "rollback", "publish"]],
	["consequence_coordinator", ["accept_prepared_action", "configure_schedule_departure_ports",
		"request_schedule_departure"]],
	["day_resolution_start_port", ["prepare_from_committed_schedule", "capture", "commit",
		"rollback", "publish"]],
]


# -------------------------------------------------------------------------------------------------
# validate_ports() -- method presence only; calls no mutation.
# -------------------------------------------------------------------------------------------------

static func validate_ports(schedule_port: Object, day7_provenance: Object,
		causal_sequence_port: Object, board_fate_port: Object, consequence_coordinator: Object,
		day_resolution_start_port: Object) -> Dictionary:
	var ports: Array = [schedule_port, day7_provenance, causal_sequence_port, board_fate_port,
		consequence_coordinator, day_resolution_start_port]
	for index: int in range(_PORT_METHOD_ROWS.size()):
		var row: Array = _PORT_METHOD_ROWS[index]
		var port_name := str(row[0])
		var port: Object = ports[index]
		if port == null:
			return _fail(&"contract_port_missing", port_name + " is null", {"port": port_name})
		for method_name: String in (row[1] as Array):
			if not port.has_method(method_name):
				return _fail(&"contract_method_missing",
					"%s is missing the frozen method %s" % [port_name, method_name],
					{"port": port_name, "method": method_name})
	return _ok({"ports_validated": true})


# -------------------------------------------------------------------------------------------------
# Result validators -- one per downstream participant result.
# -------------------------------------------------------------------------------------------------

static func validate_schedule_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "schedule prepare")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, _SCHEDULE_VALUE_KEYS, "schedule prepare value")
	if not shape.get("ok", false):
		return shape
	if typeof(value["game_state_candidate"]) != TYPE_DICTIONARY:
		return _member_fail("schedule prepare", "game_state_candidate", "a Dictionary")
	if typeof(value["route_plan"]) != TYPE_ARRAY:
		return _member_fail("schedule prepare", "route_plan", "an Array")
	if typeof(value["schedule_commit_receipt"]) != TYPE_DICTIONARY:
		return _member_fail("schedule prepare", "schedule_commit_receipt", "a Dictionary")
	var receipt: Dictionary = value["schedule_commit_receipt"]
	if result["receipt"] != receipt:
		return _fail(&"contract_receipt_schema_mismatch",
			"the outer receipt is not an exact detached copy of schedule_commit_receipt", {})
	shape = _exact_keys(receipt, _SCHEDULE_RECEIPT_KEYS, "schedule commit receipt")
	if not shape.get("ok", false):
		return shape
	for field: String in ["receipt_id", "transaction_id", "causal_day_instance",
			"registry_fingerprint", "view_fingerprint"]:
		if not _is_nonblank_string(receipt[field]):
			return _member_fail("schedule commit receipt", field, "a nonblank String")
	for field: String in ["receipt_provenance", "transaction_issuer_receipt"]:
		if typeof(receipt[field]) != TYPE_DICTIONARY:
			return _member_fail("schedule commit receipt", field, "a Dictionary")
	for field: String in ["day", "motivation_charged"]:
		if typeof(receipt[field]) != TYPE_INT:
			return _member_fail("schedule commit receipt", field, "an int")
	for field: String in ["schedule_entry_ids", "source_receipt_ids"]:
		if typeof(receipt[field]) != TYPE_ARRAY:
			return _member_fail("schedule commit receipt", field, "an Array")
	if typeof(value["committed_schedule"]) != TYPE_DICTIONARY:
		return _member_fail("schedule prepare", "committed_schedule", "a Dictionary")
	var aggregate: Dictionary = value["committed_schedule"]
	shape = _exact_keys(aggregate, _AGGREGATE_KEYS, "committed_schedule aggregate")
	if not shape.get("ok", false):
		return shape
	if typeof(aggregate["schema_version"]) != TYPE_INT or int(aggregate["schema_version"]) != 1:
		return _member_fail("committed_schedule", "schema_version", "exactly 1")
	if typeof(aggregate["entries"]) != TYPE_ARRAY:
		return _member_fail("committed_schedule", "entries", "an Array")
	var entries: Array = aggregate["entries"]
	if aggregate["commit_receipt"] != receipt:
		return _fail(&"contract_receipt_schema_mismatch",
			"the aggregate does not embed the exact commit receipt byte-for-byte", {})
	if int(receipt["motivation_charged"]) != entries.size():
		return _fail(&"contract_member_invalid",
			"motivation_charged must equal the committed-entry count",
			{"motivation_charged": receipt["motivation_charged"], "entries": entries.size()})
	if (receipt["schedule_entry_ids"] as Array).size() != entries.size() \
			or (receipt["source_receipt_ids"] as Array).size() != entries.size():
		return _fail(&"contract_member_invalid",
			"schedule_entry_ids and source_receipt_ids align by index with the committed entries",
			{"entries": entries.size()})
	return _ok({"form": "success"})


static func validate_day7_provenance_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "day7 handoff")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, ["terminal_provenance"], "day7 handoff value")
	if not shape.get("ok", false):
		return shape
	if typeof(value["terminal_provenance"]) != TYPE_DICTIONARY:
		return _member_fail("day7 handoff", "terminal_provenance", "a Dictionary")
	var terminal: Dictionary = value["terminal_provenance"]
	if result["receipt"] != terminal:
		return _fail(&"contract_receipt_schema_mismatch",
			"the outer receipt is not an exact detached copy of terminal provenance", {})
	shape = _exact_keys(terminal, _DAY7_TERMINAL_KEYS, "terminal provenance")
	if not shape.get("ok", false):
		return shape
	if str(terminal["kind"]) != "day7_schedule_provenance":
		return _member_fail("terminal provenance", "kind", "exactly day7_schedule_provenance")
	if typeof(terminal["day"]) != TYPE_INT or int(terminal["day"]) != 7:
		return _member_fail("terminal provenance", "day", "exactly 7")
	if str(terminal["cause"]) not in _DAY7_CAUSES:
		return _member_fail("terminal provenance", "cause", "empty_done | scheduled_solo")
	for field: String in ["receipt_id", "causal_day_instance", "registry_fingerprint",
			"schedule_commit_receipt_id"]:
		if not _is_nonblank_string(terminal[field]):
			return _member_fail("terminal provenance", field, "a nonblank String")
	if typeof(terminal["receipt_provenance"]) != TYPE_DICTIONARY:
		return _member_fail("terminal provenance", "receipt_provenance", "a Dictionary")
	var trio_null: bool = terminal["schedule_entry_id"] == null and terminal["action_id"] == null \
		and terminal["source_receipt_id"] == null
	var trio_full: bool = _is_nonblank_string(terminal["schedule_entry_id"]) \
		and _is_nonblank_string(terminal["action_id"]) \
		and _is_nonblank_string(terminal["source_receipt_id"])
	if str(terminal["cause"]) == "empty_done" and not trio_null:
		return _fail(&"contract_member_invalid",
			"empty_done carries all three trailing members null", {})
	if str(terminal["cause"]) == "scheduled_solo" and not trio_full:
		return _fail(&"contract_member_invalid",
			"scheduled_solo carries all three trailing members nonempty", {})
	return _ok({"form": "success"})


static func validate_causal_reservation_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "causal reservation")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, _RESERVATION_VALUE_KEYS, "causal reservation value")
	if not shape.get("ok", false):
		return shape
	if typeof(value["causal_sequence_receipt"]) != TYPE_DICTIONARY:
		return _member_fail("causal reservation", "causal_sequence_receipt", "a Dictionary")
	var receipt: Dictionary = value["causal_sequence_receipt"]
	if result["receipt"] != receipt:
		return _fail(&"contract_receipt_schema_mismatch",
			"the outer receipt is not an exact detached copy of causal_sequence_receipt", {})
	var receipt_valid := _validate_sequence_receipt(receipt, "causal_sequence_receipt")
	if not receipt_valid.get("ok", false):
		return receipt_valid
	if typeof(value["sequence_candidate"]) != TYPE_DICTIONARY:
		return _member_fail("causal reservation", "sequence_candidate", "a Dictionary")
	if str((value["sequence_candidate"] as Dictionary).get("transaction_id", "")) \
			!= str(receipt["transaction_id"]):
		return _fail(&"contract_member_invalid",
			"sequence_candidate.transaction_id must equal the reserved transaction", {})
	return _ok({"form": "success"})


static func validate_causal_admission_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "causal admission")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, ["candidate"], "causal admission value")
	if not shape.get("ok", false):
		return shape
	if result["receipt"] != {}:
		return _fail(&"contract_receipt_schema_mismatch",
			"prepare_admission allocates nothing and issues no receipt", {})
	if typeof(value["candidate"]) != TYPE_DICTIONARY:
		return _member_fail("causal admission", "candidate", "a Dictionary")
	var candidate: Dictionary = value["candidate"]
	shape = _exact_keys(candidate, _ADMISSION_CANDIDATE_KEYS, "admission candidate")
	if not shape.get("ok", false):
		return shape
	if not _is_nonblank_string(candidate["transaction_id"]):
		return _member_fail("admission candidate", "transaction_id", "a nonblank String")
	if typeof(candidate["sequence_candidate"]) != TYPE_DICTIONARY:
		return _member_fail("admission candidate", "sequence_candidate", "a Dictionary")
	if str((candidate["sequence_candidate"] as Dictionary).get("transaction_id", "")) \
			!= str(candidate["transaction_id"]):
		return _fail(&"contract_member_invalid",
			"the bound sequence candidate must name the same transaction", {})
	if typeof(candidate["admission_checkpoint_candidate"]) != TYPE_DICTIONARY:
		return _member_fail("admission candidate", "admission_checkpoint_candidate", "a Dictionary")
	var checkpoint_candidate: Dictionary = candidate["admission_checkpoint_candidate"]
	if typeof(checkpoint_candidate.get("candidate")) != TYPE_DICTIONARY \
			or typeof(checkpoint_candidate.get("checkpoint_receipt")) != TYPE_DICTIONARY:
		return _fail(&"contract_member_invalid",
			"admission_checkpoint_candidate must carry candidate and checkpoint_receipt", {})
	if not _is_lowercase_sha256(candidate["recovery_payload_sha256"]):
		return _member_fail("admission candidate", "recovery_payload_sha256",
			"lowercase sha256 hex")
	return _ok({"form": "success"})


static func validate_causal_commit_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "causal commit")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, _CAUSAL_COMMIT_KEYS, "causal commit value")
	if not shape.get("ok", false):
		return shape
	var receipt: Dictionary = result["receipt"]
	shape = _exact_keys(receipt, _CAUSAL_COMMIT_KEYS, "causal commit receipt")
	if not shape.get("ok", false):
		return shape
	if typeof(value["causal_sequence_receipt"]) != TYPE_DICTIONARY \
			or typeof(value["admission_checkpoint_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"contract_member_invalid",
			"causal commit value carries the two receipts as Dictionaries", {})
	if receipt["causal_sequence_receipt"] != value["causal_sequence_receipt"] \
			or receipt["admission_checkpoint_receipt"] != value["admission_checkpoint_receipt"]:
		return _fail(&"contract_receipt_schema_mismatch",
			"the outer receipt is not the exact combined causal/admission-checkpoint receipt", {})
	var receipt_valid := _validate_sequence_receipt(value["causal_sequence_receipt"],
		"committed causal_sequence_receipt")
	if not receipt_valid.get("ok", false):
		return receipt_valid
	return _ok({"form": "success"})


static func validate_board_fate_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "board fate")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, _BOARD_FATE_VALUE_KEYS, "board fate value")
	if not shape.get("ok", false):
		return shape
	if typeof(value["board_candidate"]) != TYPE_DICTIONARY:
		return _member_fail("board fate", "board_candidate", "a Dictionary")
	if typeof(value["board_fate_receipt"]) != TYPE_DICTIONARY:
		return _member_fail("board fate", "board_fate_receipt", "a Dictionary")
	var receipt: Dictionary = value["board_fate_receipt"]
	if result["receipt"] != receipt:
		return _fail(&"contract_receipt_schema_mismatch",
			"the outer receipt is not an exact detached copy of board_fate_receipt", {})
	shape = _exact_keys(receipt, _BOARD_FATE_RECEIPT_KEYS, "board fate receipt")
	if not shape.get("ok", false):
		return shape
	for field: String in ["receipt_id", "command_id", "causal_day_instance"]:
		if not _is_nonblank_string(receipt[field]):
			return _member_fail("board fate receipt", field, "a nonblank String")
	for field: String in ["receipt_provenance", "command_issuer_receipt"]:
		if typeof(receipt[field]) != TYPE_DICTIONARY:
			return _member_fail("board fate receipt", field, "a Dictionary")
	if str(receipt["fate"]) not in _FATES:
		return _member_fail("board fate receipt", "fate",
			"none | discarded_unstarted | forfeited_started")
	if typeof(receipt["board_revision"]) != TYPE_INT:
		return _member_fail("board fate receipt", "board_revision", "an int")
	if receipt["board_identity"] != null and typeof(receipt["board_identity"]) != TYPE_DICTIONARY:
		return _member_fail("board fate receipt", "board_identity", "a Dictionary or null")
	if (receipt["board_identity"] == null) != (int(receipt["board_revision"]) == -1):
		return _fail(&"contract_member_invalid",
			"board_revision is -1 exactly when board_identity is null",
			{"board_revision": receipt["board_revision"]})
	var source_id: Variant = receipt["source_action_commit_receipt_id"]
	var source_provenance: Variant = receipt["source_action_commit_receipt_provenance"]
	if source_id == null:
		if source_provenance != null:
			return _fail(&"contract_member_invalid",
				"both nullable source-action receipt members are null together (Schedule Done)", {})
	else:
		if not _is_nonblank_string(source_id) or typeof(source_provenance) != TYPE_DICTIONARY:
			return _fail(&"contract_member_invalid",
				"a projected departure carries the nonnull source-action id and provenance pair", {})
	return _ok({"form": "success"})


static func validate_consequence_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "consequence accept")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, _CONSEQUENCE_VALUE_KEYS, "consequence accept value")
	if not shape.get("ok", false):
		return shape
	if typeof(value["causal_sequence"]) != TYPE_INT or int(value["causal_sequence"]) < 1:
		return _member_fail("consequence accept", "causal_sequence", "an int of at least 1")
	if typeof(value["condition_receipt"]) != TYPE_DICTIONARY:
		return _member_fail("consequence accept", "condition_receipt", "a Dictionary")
	for field: String in ["board_fate_receipt", "schedule_view_commit_receipt",
			"destination_intent", "notification_intent"]:
		if value[field] != null and typeof(value[field]) != TYPE_DICTIONARY:
			return _member_fail("consequence accept", field, "a Dictionary or null")
	var receipt: Dictionary = result["receipt"]
	shape = _exact_keys(receipt, _CONSEQUENCE_RECEIPT_KEYS, "consequence receipt")
	if not shape.get("ok", false):
		return shape
	for field: String in ["receipt_id", "action_commit_receipt_id"]:
		if not _is_nonblank_string(receipt[field]):
			return _member_fail("consequence receipt", field, "a nonblank String")
	for field: String in ["receipt_provenance", "action_commit_receipt_provenance"]:
		if typeof(receipt[field]) != TYPE_DICTIONARY:
			return _member_fail("consequence receipt", field, "a Dictionary")
	if str(receipt["disposition"]) not in _DISPOSITIONS:
		return _member_fail("consequence receipt", "disposition",
			"no_departure | departure_committed")
	if typeof(receipt["causal_sequence"]) != TYPE_INT \
			or int(receipt["causal_sequence"]) != int(value["causal_sequence"]):
		return _fail(&"contract_member_invalid",
			"the receipt's causal_sequence must equal the value's", {})
	return _ok({"form": "success"})


## SHIPPED shapes per DEVIATION-18 Ruling 18-A (see the class doc): value
## {start_receipt, committed_schedule, route_plan, schedule_commit_receipt_id,
## board_fate_receipt_id}, receipt an exact detached copy of the shipped eight-member
## start_receipt. The lock-shape divergence is reconciled by the first consuming task (Task 6/7).
static func validate_day_resolution_start_result(result: Dictionary) -> Dictionary:
	var form := _validate_envelope(result, "day-resolution start")
	if not form.get("ok", false):
		return form
	if str((form["value"] as Dictionary)["form"]) == "failure":
		return _ok({"form": "failure"})
	var value: Dictionary = result["value"]
	var shape := _exact_keys(value, _DAY_START_VALUE_KEYS, "day-resolution start value")
	if not shape.get("ok", false):
		return shape
	if typeof(value["committed_schedule"]) != TYPE_DICTIONARY:
		return _member_fail("day-resolution start", "committed_schedule", "a Dictionary")
	if typeof(value["route_plan"]) != TYPE_ARRAY:
		return _member_fail("day-resolution start", "route_plan", "an Array")
	for field: String in ["schedule_commit_receipt_id", "board_fate_receipt_id"]:
		if not _is_nonblank_string(value[field]):
			return _member_fail("day-resolution start", field, "a nonblank String")
	if typeof(value["start_receipt"]) != TYPE_DICTIONARY:
		return _member_fail("day-resolution start", "start_receipt", "a Dictionary")
	var receipt: Dictionary = value["start_receipt"]
	if result["receipt"] != receipt:
		return _fail(&"contract_receipt_schema_mismatch",
			"the outer receipt is not an exact detached copy of start_receipt", {})
	shape = _exact_keys(receipt, _DAY_START_RECEIPT_KEYS, "day-resolution start receipt")
	if not shape.get("ok", false):
		return shape
	for field: String in ["receipt_id", "resolution_id", "causal_day_instance",
			"schedule_commit_receipt_id", "board_fate_receipt_id"]:
		if not _is_nonblank_string(receipt[field]):
			return _member_fail("day-resolution start receipt", field, "a nonblank String")
	if typeof(receipt["receipt_provenance"]) != TYPE_DICTIONARY:
		return _member_fail("day-resolution start receipt", "receipt_provenance", "a Dictionary")
	if typeof(receipt["schedule_entry_ids"]) != TYPE_ARRAY:
		return _member_fail("day-resolution start receipt", "schedule_entry_ids", "an Array")
	if typeof(receipt["source_day"]) != TYPE_INT or int(receipt["source_day"]) < 1 \
			or int(receipt["source_day"]) > 7:
		return _member_fail("day-resolution start receipt", "source_day", "an int in 1..7")
	if str(receipt["schedule_commit_receipt_id"]) != str(value["schedule_commit_receipt_id"]) \
			or str(receipt["board_fate_receipt_id"]) != str(value["board_fate_receipt_id"]):
		return _fail(&"contract_member_invalid",
			"the start receipt and value must name the same commit/board-fate identities", {})
	return _ok({"form": "success"})


# -------------------------------------------------------------------------------------------------
# Internal helpers -- pure, static, stateless.
# -------------------------------------------------------------------------------------------------

## The master envelope law: exactly {ok, code, value, receipt} with ok=true, or exactly
## {ok, code, message, details} with ok=false. Returns value={form:"success"|"failure"}.
static func _validate_envelope(result: Dictionary, context: String) -> Dictionary:
	var keys: Array = result.keys()
	keys.sort()
	if keys == _SUCCESS_KEYS:
		if typeof(result["ok"]) != TYPE_BOOL or not bool(result["ok"]):
			return _fail(&"contract_envelope_invalid",
				context + ": a success-shaped envelope must carry ok=true", {"keys": keys})
		if not _is_code(result["code"]):
			return _fail(&"contract_envelope_invalid",
				context + ": code must be a nonblank StringName or String", {})
		if typeof(result["value"]) != TYPE_DICTIONARY:
			return _fail(&"contract_envelope_invalid",
				context + ": success value must be a Dictionary", {})
		if typeof(result["receipt"]) != TYPE_DICTIONARY:
			return _fail(&"contract_envelope_invalid",
				context + ": success receipt must be a Dictionary", {})
		return _ok({"form": "success"})
	if keys == _FAILURE_KEYS:
		if typeof(result["ok"]) != TYPE_BOOL or bool(result["ok"]):
			return _fail(&"contract_envelope_invalid",
				context + ": a failure-shaped envelope must carry ok=false", {"keys": keys})
		if not _is_code(result["code"]):
			return _fail(&"contract_envelope_invalid",
				context + ": code must be a nonblank StringName or String", {})
		if typeof(result["message"]) != TYPE_STRING:
			return _fail(&"contract_envelope_invalid",
				context + ": failure message must be a String", {})
		if typeof(result["details"]) != TYPE_DICTIONARY:
			return _fail(&"contract_envelope_invalid",
				context + ": failure details must be a Dictionary", {})
		return _ok({"form": "failure"})
	return _fail(&"contract_envelope_invalid",
		context + ": the member set is neither {ok, code, value, receipt} nor {ok, code, message, details}",
		{"keys": keys})


static func _validate_sequence_receipt(receipt: Variant, context: String) -> Dictionary:
	if typeof(receipt) != TYPE_DICTIONARY:
		return _member_fail(context, "receipt", "a Dictionary")
	var record: Dictionary = receipt
	var shape := _exact_keys(record, _SEQUENCE_RECEIPT_KEYS, context)
	if not shape.get("ok", false):
		return shape
	for field: String in ["receipt_id", "transaction_id", "run_id", "branch_id",
			"causal_day_instance", "source_commit_receipt_id"]:
		if not _is_nonblank_string(record[field]):
			return _member_fail(context, field, "a nonblank String")
	for field: String in ["receipt_provenance", "transaction_issuer_receipt",
			"source_commit_receipt_provenance"]:
		if typeof(record[field]) != TYPE_DICTIONARY:
			return _member_fail(context, field, "a Dictionary")
	for field: String in ["causal_sequence", "run_revision", "desktop_timeline_generation"]:
		if typeof(record[field]) != TYPE_INT:
			return _member_fail(context, field, "an int")
	if str(record["source_kind"]) not in _SOURCE_KINDS:
		return _member_fail(context, "source_kind",
			"minesweeper_round | shop_purchase | schedule_done")
	if int(record["causal_sequence"]) < 1 or int(record["run_revision"]) < 1:
		return _fail(&"contract_member_invalid",
			context + " proposes causal_sequence and run_revision of at least 1", {})
	return {"ok": true}


static func _exact_keys(value: Dictionary, expected: Array, context: String) -> Dictionary:
	var keys: Array = value.keys()
	keys.sort()
	if keys != expected:
		return _fail(&"contract_schema_mismatch",
			"%s member set is exactly %s" % [context, str(expected)],
			{"expected": expected, "actual": keys})
	return {"ok": true}


static func _member_fail(context: String, field: String, expectation: String) -> Dictionary:
	return _fail(&"contract_member_invalid",
		"%s.%s must be %s" % [context, field, expectation], {"field": field})


static func _is_code(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING_NAME and typeof(value) != TYPE_STRING:
		return false
	return not str(value).strip_edges().is_empty()


static func _is_nonblank_string(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).strip_edges().is_empty()


static func _is_lowercase_sha256(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if text.length() != 64:
		return false
	for codepoint in text.to_utf8_buffer():
		if not (codepoint >= 48 and codepoint <= 57) and not (codepoint >= 97 and codepoint <= 102):
			return false
	return true


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details.duplicate(true)}
