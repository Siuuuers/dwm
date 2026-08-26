extends SceneTree

# =================================================================================================
# The Phase-2R closeout gate command-line validator.
#
# Layering, and why it is drawn here.
#   * Phase2RCloseoutInventory owns every Beads-topology and committed-evidence law. This script
#     never re-implements one of them; it dispatches and surfaces the seam's own verdict unchanged.
#   * EvidenceValidator owns the gate document's schema and its cross-field laws, dispatched on the
#     document's own `kind`.
#   * What is left, and all this script owns, is: the six closed flag sets, the --gate/--receipt
#     path assertions, the four authority digests, and the validation-command/receipt laws.
#
# --gate and --receipt are ASSERTIONS, not inputs. validate() takes five paths and resolves
# gate.json, validation_receipt.json and preclose_beads_snapshot.json internally from evidence_root,
# so a --gate naming another document would otherwise be accepted and silently ignored. Rejecting a
# --gate that does not resolve to <evidence-root>/gate.json is the only thing that makes the flag
# mean anything.
#
# PREREQUISITE is deliberately absent from MODE_FLAGS. It runs while the output root does not yet
# exist, which only the runner can arrange, so it stays runner-internal and unreachable from here.
#
# Both pure seams are static, so tests exercise plan() and run() without ever constructing a
# SceneTree.
# =================================================================================================

const INVENTORY := preload("res://tools/evidence/Phase2RCloseoutInventory.gd")
const EVIDENCE_VALIDATOR := preload("res://tools/evidence/EvidenceValidator.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const SCHEMA_PATH := "res://schemas/evidence/phase2r-closeout-gate.schema.json"

const GATE_RELATIVE := "gate.json"
const RECEIPT_RELATIVE := "validation_receipt.json"
const SNAPSHOT_RELATIVE := "preclose_beads_snapshot.json"
const COMMAND_RECORD_RELATIVE := "logs/validation-command.jsonl"
const VALIDATION_LOG_RELATIVE := "logs/phase2r-closeout-validate.log"

const VALIDATION_COMMAND_ID := "phase2r-closeout-validate"
const VALIDATION_GATE_PATH := "evidence/phase_2r/closeout/gate.json"
const VALIDATION_LOG_PATH := "evidence/phase_2r/closeout/logs/phase2r-closeout-validate.log"

## The exact nine keys of logs/validation-command.jsonl.
const VALIDATION_COMMAND_KEYS: Array[String] = [
	"schema_version", "command_id", "argv", "subject_commit", "gate_path", "gate_sha256",
	"log_path", "log_sha256", "exit_code",
]

## The exact seven keys of validation_receipt.json.
const RECEIPT_KEYS: Array[String] = [
	"schema_version", "subject_commit", "gate_sha256", "validation_command_record_sha256",
	"validation_log_sha256", "validator_exit_code", "sealed_at_utc",
]

## The four authority documents whose digests the gate carries, and which this script re-verifies
## against their committed bytes rather than trusting the gate's own numbers.
const DIGEST_KEYS: Array[String] = [
	"authority", "plan", "requirement_index", "design_authority_registry",
]

## The six closed modes and their exact flag sets. No mode has a default and no flag is optional:
## a missing, extra, repeated or borrowed flag is rejected before anything is read.
const MODE_FLAGS: Dictionary = {
	"preseal": ["metadata", "beads", "requirements", "evidence-root", "gate"],
	"sealed-pre-attach": ["metadata", "beads", "requirements", "evidence-root", "gate", "receipt"],
	"attached-preclose": ["metadata", "beads", "requirements", "evidence-root", "gate", "receipt"],
	"postclose": ["metadata", "beads", "requirements", "evidence-root", "gate", "receipt"],
	"export-equivalence": ["beads", "export"],
	"final-epic-transition": ["postclose-export", "final-export", "attachment"],
}

## Each inventory mode's own closed constant. The auxiliary modes carry none, which is what keeps
## an auxiliary invocation from reaching validate() at all.
const MODE_INVENTORY: Dictionary = {
	"preseal": "PRE_SEAL",
	"sealed-pre-attach": "SEALED_PRE_ATTACH",
	"attached-preclose": "ATTACHED_PRE_CLOSE",
	"postclose": "POST_CLOSE",
}

const MODE_SEAM: Dictionary = {
	"preseal": "validate",
	"sealed-pre-attach": "validate",
	"attached-preclose": "validate",
	"postclose": "validate",
	"export-equivalence": "validate_export_equivalence",
	"final-epic-transition": "validate_final_epic_transition",
}

## The modes that run after the receipt and command record exist. PRE_SEAL runs before both, and
## the inventory itself refuses a PRE_SEAL run that finds either present.
const RECEIPT_BEARING_MODES: Array[String] = [
	"sealed-pre-attach", "attached-preclose", "postclose",
]


# =================================================================================================
# Pure seam: argument vector to plan.
# =================================================================================================

static func plan(arguments: PackedStringArray) -> Dictionary:
	var values: Dictionary = {}
	var order: Array[String] = []
	## DEFENCE IN DEPTH, proven by mutation: removing this shape check alone changes nothing,
	## because a positional argument then parses into a name that no mode declares and is
	## rejected below with the same code. Removing BOTH is what lets a positional through.
	for argument: String in arguments:
		if not argument.begins_with("--") or not argument.contains("="):
			return _usage(&"cli_flag_unknown", "an argument is not a --name=value flag",
				{"argument": argument})
		var separator: int = argument.find("=")
		var name: String = argument.substr(2, separator - 2)
		var value: String = argument.substr(separator + 1)
		if name.is_empty():
			return _usage(&"cli_flag_unknown", "an argument carries an empty flag name",
				{"argument": argument})
		if not values.has(name):
			values[name] = []
			order.append(name)
		(values[name] as Array).append(value)

	if not values.has("mode"):
		return _usage(&"cli_mode_missing", "every invocation must name exactly one closed mode", {})
	if (values["mode"] as Array).size() != 1:
		return _usage(&"cli_mode_duplicate", "the mode flag is repeated",
			{"count": (values["mode"] as Array).size()})
	var mode: String = str((values["mode"] as Array)[0])
	if not MODE_FLAGS.has(mode):
		return _usage(&"cli_mode_unknown", "the mode is not one of the six closed command modes",
			{"mode": mode})
	var declared: Array = MODE_FLAGS[mode]

	for name: String in order:
		if name == "mode":
			continue
		if not declared.has(name):
			return _usage(&"cli_flag_unknown", "the mode does not accept this flag",
				{"mode": mode, "flag": name})
		if (values[name] as Array).size() != 1:
			return _usage(&"cli_flag_duplicate", "a flag is repeated",
				{"mode": mode, "flag": name})
	var flags: Dictionary = {}
	for entry: Variant in declared:
		var name: String = str(entry)
		if not values.has(name):
			return _usage(&"cli_flag_missing", "the mode requires this flag",
				{"mode": mode, "flag": name})
		flags[name] = str((values[name] as Array)[0])

	var planned: Dictionary = {"mode": mode, "seam": str(MODE_SEAM[mode]), "flags": flags}
	if not MODE_INVENTORY.has(mode):
		return _ok(planned)

	planned["inventory_mode"] = str(MODE_INVENTORY[mode])
	var root: String = _normalise(str(flags["evidence-root"]))
	planned["evidence_root"] = root
	if _normalise(str(flags["gate"])) != root.path_join(GATE_RELATIVE):
		return _usage(&"cli_gate_path_mismatch",
			"--gate must resolve to <evidence-root>/gate.json",
			{"gate": flags["gate"], "expected": root.path_join(GATE_RELATIVE)})
	if RECEIPT_BEARING_MODES.has(mode) \
			and _normalise(str(flags["receipt"])) != root.path_join(RECEIPT_RELATIVE):
		return _usage(&"cli_receipt_path_mismatch",
			"--receipt must resolve to <evidence-root>/validation_receipt.json",
			{"receipt": flags["receipt"], "expected": root.path_join(RECEIPT_RELATIVE)})
	return _ok(planned)


# =================================================================================================
# Pure seam: plan to verdict.
# =================================================================================================

static func run(arguments: PackedStringArray) -> Dictionary:
	var planned: Dictionary = plan(arguments)
	if not planned.get("ok", false):
		return planned
	var value: Dictionary = planned["value"]
	var flags: Dictionary = value["flags"]
	var mode: String = str(value["mode"])

	if mode == "export-equivalence":
		return INVENTORY.validate_export_equivalence(str(flags["beads"]), str(flags["export"]))
	if mode == "final-epic-transition":
		return INVENTORY.validate_final_epic_transition(str(flags["postclose-export"]),
			str(flags["final-export"]), str(flags["attachment"]))

	var root: String = str(value["evidence_root"])
	var gate_path: String = root.path_join(GATE_RELATIVE)
	## DEFENCE IN DEPTH, proven by mutation, and it covers the next check too: absent, non-UTF-8 and
	## non-strict-JSON all return one code, and the strict-JSON parse below catches all three on its
	## own, so removing either of these two alone changes no verdict. They are kept for the precise
	## diagnostic. Removing the parse check IS killed, so the verdict itself is never at risk, and
	## removing this one together with the parse check is killed as well.
	if not FileAccess.file_exists(gate_path):
		return _fail(&"cli_gate_unreadable", "the closeout gate is absent", {"path": gate_path})
	var gate_bytes: PackedByteArray = FileAccess.get_file_as_bytes(gate_path)
	var gate_text: String = gate_bytes.get_string_from_utf8()
	if gate_text.to_utf8_buffer() != gate_bytes:
		return _fail(&"cli_gate_unreadable", "the closeout gate is not valid UTF-8",
			{"path": gate_path})
	var gate_parsed: Dictionary = STRICT_JSON.parse_object(gate_text)
	if not gate_parsed.get("ok", false):
		return _fail(&"cli_gate_unreadable", "the closeout gate is not one strict JSON object",
			{"path": gate_path, "errors": gate_parsed.get("errors", [])})
	var gate: Dictionary = gate_parsed["value"]

	var schema: Dictionary = EVIDENCE_VALIDATOR.validate_file(gate_path, SCHEMA_PATH)
	if not schema.get("ok", false):
		return _fail(&"gate_schema_invalid", "the closeout gate does not satisfy its schema",
			{"errors": schema.get("errors", [])})

	var digests: Dictionary = _verify_digests(gate)
	if not digests.get("ok", false):
		return digests

	if RECEIPT_BEARING_MODES.has(mode):
		var sealed: Dictionary = _verify_seal(root, gate, _sha256(gate_bytes), flags)
		if not sealed.get("ok", false):
			return sealed

	return INVENTORY.validate(str(value["inventory_mode"]), str(flags["metadata"]),
		str(flags["beads"]), str(flags["requirements"]), root)


static func exit_code_for(result: Dictionary) -> int:
	if result.get("ok", false):
		return 0
	return 2 if result.get("usage", false) else 1


# =================================================================================================
# The four authority digests.
#
# The gate states them; this re-derives them from the committed bytes, so a gate that names the
# right documents with the wrong hashes cannot pass by self-assertion.
# =================================================================================================

static func _verify_digests(gate: Dictionary) -> Dictionary:
	var digests: Dictionary = gate.get("digests", {})
	for key: String in DIGEST_KEYS:
		var record: Dictionary = digests.get(key, {})
		var relative: String = str(record.get("path", ""))
		var resource: String = "res://" + relative
		if relative.is_empty() or not FileAccess.file_exists(resource):
			return _fail(&"gate_digest_unreadable", "a bound authority document is absent",
				{"digest": key, "path": relative})
		if _sha256(FileAccess.get_file_as_bytes(resource)) != str(record.get("sha256", "")):
			return _fail(&"gate_digest_mismatch",
				"a bound authority document does not match its recorded digest",
				{"digest": key, "path": relative})
	return _ok({})


# =================================================================================================
# logs/validation-command.jsonl and validation_receipt.json.
#
# The command record binds the observed pre-seal invocation to the gate and to its own log; the
# receipt binds the whole LF-terminated record file. Every check below fails closed, and the key
# check runs before any member is read so a dropped key never surfaces as a hash mismatch.
# =================================================================================================

static func _verify_seal(root: String, gate: Dictionary, gate_sha256: String,
		flags: Dictionary) -> Dictionary:
	var record_path: String = root.path_join(COMMAND_RECORD_RELATIVE)
	if not FileAccess.file_exists(record_path):
		return _fail(&"validation_command_record_missing", "the validation command record is absent",
			{"path": record_path})
	var record_text: String = FileAccess.get_file_as_string(record_path)
	if not record_text.ends_with("\n") or record_text.trim_suffix("\n").contains("\n") \
			or record_text.trim_suffix("\n").is_empty():
		return _fail(&"validation_command_record_not_single_line",
			"the record is not exactly one LF-terminated line", {"path": record_path})
	var record_line: String = record_text.trim_suffix("\n")
	var record_parsed: Dictionary = STRICT_JSON.parse_object(record_line)
	if not record_parsed.get("ok", false):
		return _fail(&"validation_command_record_noncanonical",
			"the record line is not one strict JSON object", {"path": record_path})
	var record: Dictionary = record_parsed["value"]
	if record_line != _canonical(record):
		return _fail(&"validation_command_record_noncanonical",
			"the record bytes are not canonical", {"path": record_path})
	if not _exact_keys(record, VALIDATION_COMMAND_KEYS):
		return _fail(&"validation_command_record_keys",
			"the record does not carry exactly the nine declared keys",
			{"keys": record.keys()})
	if str(record["command_id"]) != VALIDATION_COMMAND_ID:
		return _fail(&"validation_command_record_command_id", "the record names another command",
			{"command_id": record["command_id"]})
	if str(record["gate_path"]) != VALIDATION_GATE_PATH \
			or str(record["log_path"]) != VALIDATION_LOG_PATH:
		return _fail(&"validation_command_record_path",
			"the record names another gate or log path",
			{"gate_path": record["gate_path"], "log_path": record["log_path"]})
	if int(record["exit_code"]) != 0:
		return _fail(&"validation_command_record_exit_code",
			"the record admits a nonzero validator exit", {"exit_code": record["exit_code"]})
	if str(record["subject_commit"]) != str(gate.get("subject_commit", "")):
		return _fail(&"validation_command_record_subject", "the record names another subject",
			{"subject_commit": record["subject_commit"]})
	if record["argv"] != _preseal_argv(root, flags):
		return _fail(&"validation_command_record_argv",
			"the record does not carry the exact pre-seal argument vector",
			{"argv": record["argv"], "expected": _preseal_argv(root, flags)})
	if str(record["gate_sha256"]) != gate_sha256:
		return _fail(&"validation_command_record_gate_hash",
			"the record was taken against another gate", {"gate_sha256": record["gate_sha256"]})
	var log_path: String = root.path_join(VALIDATION_LOG_RELATIVE)
	if not FileAccess.file_exists(log_path) \
			or _sha256(FileAccess.get_file_as_bytes(log_path)) != str(record["log_sha256"]):
		return _fail(&"validation_command_record_log_hash",
			"the validation log is absent or does not match the record", {"path": log_path})

	var receipt_path: String = root.path_join(RECEIPT_RELATIVE)
	if not FileAccess.file_exists(receipt_path):
		return _fail(&"validation_receipt_missing", "the validation receipt is absent",
			{"path": receipt_path})
	var receipt_text: String = FileAccess.get_file_as_string(receipt_path)
	if not receipt_text.ends_with("\n") or receipt_text.trim_suffix("\n").contains("\n"):
		return _fail(&"validation_receipt_noncanonical",
			"the receipt is not exactly one LF-terminated line", {"path": receipt_path})
	var receipt_parsed: Dictionary = STRICT_JSON.parse_object(receipt_text.trim_suffix("\n"))
	if not receipt_parsed.get("ok", false):
		return _fail(&"validation_receipt_noncanonical",
			"the receipt is not one strict JSON object", {"path": receipt_path})
	var receipt: Dictionary = receipt_parsed["value"]
	if receipt_text.trim_suffix("\n") != _canonical(receipt):
		return _fail(&"validation_receipt_noncanonical", "the receipt bytes are not canonical",
			{"path": receipt_path})
	if not _exact_keys(receipt, RECEIPT_KEYS):
		return _fail(&"validation_receipt_keys",
			"the receipt does not carry exactly the seven declared keys", {"keys": receipt.keys()})
	if str(receipt["gate_sha256"]) != gate_sha256:
		return _fail(&"validation_receipt_gate_hash", "the receipt seals another gate",
			{"gate_sha256": receipt["gate_sha256"]})
	## The receipt's command hash covers the whole LF-terminated file, not the trimmed line.
	if str(receipt["validation_command_record_sha256"]) != _sha256(record_text.to_utf8_buffer()):
		return _fail(&"validation_receipt_command_hash",
			"the receipt does not hash the whole command record file", {"path": record_path})
	if str(receipt["validation_log_sha256"]) != str(record["log_sha256"]):
		return _fail(&"validation_receipt_log_hash",
			"the receipt and the command record disagree about the validation log", {})
	if str(receipt["subject_commit"]) != str(gate.get("subject_commit", "")):
		return _fail(&"validation_receipt_subject", "the receipt names another subject",
			{"subject_commit": receipt["subject_commit"]})
	if int(receipt["validator_exit_code"]) != 0:
		return _fail(&"validation_receipt_exit_code", "the receipt admits a nonzero validator exit",
			{"validator_exit_code": receipt["validator_exit_code"]})
	return _ok({})


## The pre-seal vector the runner must have used, rebuilt from this invocation's own flags so a
## record copied from another evidence root cannot pass.
static func _preseal_argv(root: String, flags: Dictionary) -> Array:
	return [
		"--mode=preseal",
		"--metadata=" + str(flags["metadata"]),
		"--beads=" + root.path_join(SNAPSHOT_RELATIVE),
		"--requirements=" + str(flags["requirements"]),
		"--evidence-root=" + root,
		"--gate=" + root.path_join(GATE_RELATIVE),
	]


# =================================================================================================
# Primitives.
# =================================================================================================

## Trailing separators only. `..` is deliberately NOT resolved: a --gate that merely traverses back
## to the right file is a different path and is rejected.
static func _normalise(path: String) -> String:
	return path.replace("\\", "/").trim_suffix("/")


static func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	var actual: Array = value.keys()
	actual.sort()
	var wanted: Array = expected.duplicate()
	wanted.sort()
	return actual == wanted


static func _canonical(value: Variant) -> String:
	var written: Dictionary = CANONICAL_JSON.stringify(value)
	if not written.get("ok", false):
		return "uncanonicalisable"
	return str(written.get("value", ""))


static func _sha256(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


## A usage failure is anything plan() rejects, and only that. The distinction is carried as a flag
## rather than inferred from the code name, so exit_code_for cannot drift from it.
static func _usage(code: StringName, message: String, details: Dictionary) -> Dictionary:
	var result: Dictionary = _fail(code, message, details)
	result["usage"] = true
	return result


# =================================================================================================
# Command-line entry.
# =================================================================================================

func _init() -> void:
	var result: Dictionary = run(PackedStringArray(OS.get_cmdline_user_args()))
	var code: int = exit_code_for(result)
	if code != 0:
		printerr("PHASE2R_CLOSEOUT_GATE_INVALID: %s %s %s" % [str(result.get("code", "")),
			str(result.get("message", "")), JSON.stringify(result.get("details", {}))])
		quit(code)
		return
	print("PHASE2R_CLOSEOUT_GATE_VALIDATION: PASS")
	quit(0)
