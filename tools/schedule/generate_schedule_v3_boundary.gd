extends SceneTree

## Writer and verifier for evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json
## (Plan 01 Task 5 Step 5.10, dwm-p2r.13).
##
## Runs via `-s`, so this path extends SceneTree and performs its work in `_init()`, matching
## tools/evidence/validate_evidence.gd and tools/evidence/generate_desktop_identity_issuer_boundary.gd.
## CONSEQUENCE FOR TESTS: probe this file with DynamicScriptProbe.load_script() or a preloaded const
## and NEVER instantiate() -- instantiating constructs a SceneTree and executes the tool.
##
## WHAT THE RECORD IS FOR. Step 5.9 committed the v3 code boundary. The record produced here names
## that commit and pins the exact bytes of the three modules that define what v3 MEANS -- the
## snapshot validator, the document validator, and the migration ladder -- together with the one
## permanent focused log proving those suites were green on that tree. Plan 02 Task 6 consumes the
## record by reading it; it must never infer either boundary by searching commit subjects.
##
## WHY NOTHING HASHED IS READ FROM THE WORKING TREE. A boundary that hashed working-tree files would
## re-bind itself every time those files lawfully evolve, which is the opposite of evidence. Both
## CLI forms therefore hash blobs out of named commits. The single exception is --write's read of
## the focused log: at write time that log exists only in the working tree, because it is created
## after the code commit and committed together with this record one commit later. --check hashes
## the same log out of the evidence commit instead, so the pair is closed.
##
## The JSON schema at res://schemas/evidence/phase2r-schedule-v3-boundary.schema.json IS read from
## the working tree in both forms. That is deliberate and is not an exception to the rule above: the
## schema is this tool's declarative rulebook, in the same category as this tool's own source, and
## it constrains the record rather than being evidence about the boundary. The imperative law below
## repeats every constraint the schema expresses, so a deleted or weakened schema cannot widen what
## is accepted -- it can only cause a hard failure.
##
## TWO CLOSED CLI FORMS (plan line 901). Neither is a superset of the other, and no flag is shared
## across them except the mode flag position itself:
##   --write --boundary-commit=<40hex> --focused-log=<frozen log> --output=<frozen record>
##   --check --evidence-commit=<40hex> --record=<frozen record>
## Missing, extra, duplicate, and mixed flags all fail before any git or filesystem work happens.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

const OWNER_BEADS_ID := "dwm-p2r.13"
const BOUNDARY_SUBJECT := "feat(save): persist canonical committed Schedule"
const EVIDENCE_SUBJECT := "chore(evidence): bind committed Schedule v3 boundary"
const FOCUSED_LOG_PATH := "res://evidence/phase_2r/logs/p2r13-schedule-v3-green.log"
const RECORD_PATH := "res://evidence/phase_2r/contracts/phase2r_schedule_v3_boundary.json"
const RECORD_SCHEMA_PATH := "res://schemas/evidence/phase2r-schedule-v3-boundary.schema.json"

## Mode flag -> the exact valued flags that mode requires. Membership is exact in both directions:
## a flag absent from the selected mode's list is rejected as an extra flag even though the other
## mode would have accepted it, which is what makes the two forms closed rather than overlapping.
const MODE_FLAGS := {
	"write": ["boundary-commit", "focused-log", "output"],
	"check": ["evidence-commit", "record"],
}

## The three modules whose bytes define v3. Order here is presentation only; the record is emitted
## through CanonicalJsonWriter, which sorts keys by UTF-8 byte order.
const SOURCE_BINDINGS := [
	{
		"path": "scripts/domain/run/RunSnapshotSchema.gd",
		"path_field": "run_snapshot_schema_path",
		"hash_field": "run_snapshot_schema_sha256",
	},
	{
		"path": "scripts/infrastructure/save/SaveDocumentSchema.gd",
		"path_field": "save_document_schema_path",
		"hash_field": "save_document_schema_sha256",
	},
	{
		"path": "scripts/infrastructure/save/SaveMigrations.gd",
		"path_field": "migration_path",
		"hash_field": "migration_sha256",
	},
]

const RECORD_KEYS := [
	"boundary_commit",
	"boundary_subject",
	"focused_log_path",
	"focused_log_sha256",
	"migration_path",
	"migration_sha256",
	"owner_beads_id",
	"run_snapshot_schema_path",
	"run_snapshot_schema_sha256",
	"save_document_schema_path",
	"save_document_schema_sha256",
	"schema_version",
]

const DIGEST_FIELDS := [
	"focused_log_sha256",
	"migration_sha256",
	"run_snapshot_schema_sha256",
	"save_document_schema_sha256",
]


## Validates one complete command line and reports which closed form it named.
##
## Returns value={mode, values}, where `values` carries only the flags that mode owns. Rejection
## codes are named rather than generic because the boundary test asserts the distinct failure
## classes plan line 901 enumerates -- missing, extra, duplicate, mixed.
static func parse_arguments(args: PackedStringArray) -> Dictionary:
	var mode: String = ""
	var values: Dictionary = {}
	for raw_argument: String in args:
		var argument: String = String(raw_argument)
		if not argument.begins_with("--"):
			return _fail(&"generator_argument_unknown", "arguments are long flags only",
				{"argument": argument})
		var body: String = argument.substr(2)
		var split_at: int = body.find("=")
		if split_at < 0:
			if not MODE_FLAGS.has(body):
				return _fail(&"generator_argument_unknown", "the valueless flag is not a mode",
					{"flag": body})
			if not mode.is_empty():
				return _fail(&"generator_mode_mixed", "exactly one of --write or --check is accepted",
					{"first": mode, "second": body})
			mode = body
			continue
		var flag: String = body.substr(0, split_at)
		var value: String = body.substr(split_at + 1)
		if values.has(flag):
			return _fail(&"generator_argument_duplicate", "a flag is supplied more than once",
				{"flag": flag})
		if value.is_empty():
			return _fail(&"generator_argument_blank", "a flag value is never blank", {"flag": flag})
		values[flag] = value
	if mode.is_empty():
		return _fail(&"generator_mode_missing", "exactly one of --write or --check is required", {})
	var accepted: Array = MODE_FLAGS[mode] as Array
	for flag: String in values.keys():
		if not (flag in accepted):
			return _fail(&"generator_argument_extra", "the flag does not belong to this mode",
				{"mode": mode, "flag": flag})
	for required: String in accepted:
		if not values.has(required):
			return _fail(&"generator_argument_missing", "a flag required by this mode is absent",
				{"mode": mode, "flag": required})
	return _ok({"mode": mode, "values": values.duplicate(true)})


## Builds the immutable candidate for --write.
##
## Every hashed source comes out of `boundary_commit`'s tree. The focused log is the sole
## working-tree read, for the reason given in the file header.
static func build_boundary_record(boundary_commit: String, focused_log: String) -> Dictionary:
	if focused_log != FOCUSED_LOG_PATH:
		return _fail(&"focused_log_path_invalid", "focused_log is not the frozen path",
			{"expected": FOCUSED_LOG_PATH, "actual": focused_log})
	var proven: Dictionary = prove_boundary_commit(boundary_commit)
	if not proven.get("ok", false):
		return proven
	if not FileAccess.file_exists(focused_log):
		return _fail(&"focused_log_missing", "the permanent focused log is absent",
			{"path": focused_log})
	var record: Dictionary = {
		"schema_version": 1,
		"owner_beads_id": OWNER_BEADS_ID,
		"boundary_subject": BOUNDARY_SUBJECT,
		"boundary_commit": boundary_commit,
		"focused_log_path": FOCUSED_LOG_PATH.trim_prefix("res://"),
		"focused_log_sha256": digest_bytes(FileAccess.get_file_as_bytes(focused_log)),
	}
	for binding: Dictionary in SOURCE_BINDINGS:
		var path: String = str(binding["path"])
		var blob: Dictionary = blob_bytes_at_commit(boundary_commit, path)
		if not blob.get("ok", false):
			return blob
		record[str(binding["path_field"])] = path
		record[str(binding["hash_field"])] = digest_bytes(
			(blob.get("value", {}) as Dictionary).get("bytes", PackedByteArray()))
	var validated: Dictionary = validate_boundary_record(
		record, FileAccess.get_file_as_bytes(focused_log))
	if not validated.get("ok", false):
		return validated
	return _ok({"record": record.duplicate(true)})


## Declarative pass: the record as an external consumer would judge it, against the published
## schema alone. Kept separate from the imperative pass so the boundary test can prove each layer
## catches what it claims to, rather than proving only that one of them fired.
static func validate_record_schema(record: Dictionary) -> Dictionary:
	var schema: Dictionary = load_record_schema()
	if not schema.get("ok", false):
		return schema
	var against: Dictionary = _SCHEMA_VALIDATOR.validate(
		record, (schema.get("value", {}) as Dictionary).get("schema", {}) as Dictionary)
	if not against.get("ok", false):
		return _fail(&"record_schema_rejected", str(against.get("message", "")),
			{"errors": against.get("errors", [])})
	return _ok({"record": record.duplicate(true)})


## Imperative pass: exact member set, frozen constants, frozen paths, and digest FORM. No git, no
## evidence IO.
##
## This repeats every constraint the schema expresses and adds the ones a draft-2020-12 subset
## cannot reach here -- most importantly digest case, since the repo's JsonSchemaValidator honours
## `minLength` but not `pattern`, so an uppercase SHA-256 satisfies the schema and is rejected only
## here. A deleted or weakened schema therefore cannot widen what is accepted.
static func validate_record_law(record: Dictionary) -> Dictionary:
	var keys: Array = record.keys()
	keys.sort()
	if keys != RECORD_KEYS:
		return _fail(&"record_member_set_invalid", "the record member set is not exact",
			{"expected": RECORD_KEYS, "actual": keys})
	if typeof(record["schema_version"]) != TYPE_INT or int(record["schema_version"]) != 1:
		return _fail(&"record_schema_version_invalid", "schema_version must be exactly one", {})
	if str(record["owner_beads_id"]) != OWNER_BEADS_ID:
		return _fail(&"record_owner_invalid", "owner_beads_id is not the frozen owner", {})
	if str(record["boundary_subject"]) != BOUNDARY_SUBJECT:
		return _fail(&"record_subject_invalid", "boundary_subject is not the frozen subject", {})
	if not _is_commit_id(str(record["boundary_commit"])):
		return _fail(&"record_commit_invalid", "boundary_commit is not forty lowercase hex", {})
	if str(record["focused_log_path"]) != FOCUSED_LOG_PATH.trim_prefix("res://"):
		return _fail(&"record_log_path_invalid", "focused_log_path is not the frozen path", {})
	for binding: Dictionary in SOURCE_BINDINGS:
		if str(record[str(binding["path_field"])]) != str(binding["path"]):
			return _fail(&"record_source_path_invalid", "a bound source path is not frozen",
				{"field": str(binding["path_field"])})
	for field: String in DIGEST_FIELDS:
		if not _is_sha256(str(record[field])):
			return _fail(&"record_digest_invalid", "a digest is not lowercase SHA-256",
				{"field": field})
	return _ok({"record": record.duplicate(true)})


## Both record passes, imperative first.
##
## The imperative law runs first so the reported code names the violated rule rather than a
## generic schema message; the schema pass then runs unconditionally on records the law accepted,
## so the published contract is never bypassed.
static func validate_record_shape(record: Dictionary) -> Dictionary:
	var lawful: Dictionary = validate_record_law(record)
	if not lawful.get("ok", false):
		return lawful
	return validate_record_schema(record)


## Re-derives the three bound source digests from the record's own boundary commit.
static func validate_boundary_sources(record: Dictionary) -> Dictionary:
	var boundary_commit: String = str(record["boundary_commit"])
	var proven: Dictionary = prove_boundary_commit(boundary_commit)
	if not proven.get("ok", false):
		return proven
	for binding: Dictionary in SOURCE_BINDINGS:
		var path: String = str(binding["path"])
		var blob: Dictionary = blob_bytes_at_commit(boundary_commit, path)
		if not blob.get("ok", false):
			return blob
		var actual: String = digest_bytes(
			(blob.get("value", {}) as Dictionary).get("bytes", PackedByteArray()))
		if actual != str(record[str(binding["hash_field"])]):
			return _fail(&"boundary_source_hash_mismatch",
				"a source differs from the boundary-commit tree", {"path": path})
	return _ok({"boundary_commit": boundary_commit})


## Shape plus boundary-tree sources plus the caller's focused-log bytes.
##
## The caller supplies the log bytes rather than a path so the two forms cannot drift: --write and
## the permanent boundary test pass the working-tree file, --check passes the blob it read out of
## the evidence commit, and both then travel the identical comparison.
static func validate_boundary_record(record: Dictionary, focused_log_bytes: PackedByteArray) -> Dictionary:
	var shaped: Dictionary = validate_record_shape(record)
	if not shaped.get("ok", false):
		return shaped
	if digest_bytes(focused_log_bytes) != str(record["focused_log_sha256"]):
		return _fail(&"focused_log_hash_mismatch", "the permanent focused log bytes differ", {})
	var sources: Dictionary = validate_boundary_sources(record)
	if not sources.get("ok", false):
		return sources
	return _ok({"record": record.duplicate(true)})


## The whole --check form, expressed so the boundary test can call it directly.
##
## Reads the record and the focused log out of `evidence_commit`, the three production sources out
## of the commit the record itself names, and compares the record's own bytes against a fresh
## canonical serialization. The working tree contributes nothing except the schema rulebook.
static func verify_evidence_commit(evidence_commit: String, record_path: String) -> Dictionary:
	if record_path != RECORD_PATH:
		return _fail(&"record_path_invalid", "record is not the frozen path",
			{"expected": RECORD_PATH, "actual": record_path})
	if not _is_commit_id(evidence_commit):
		return _fail(&"evidence_commit_invalid", "evidence_commit is not forty lowercase hex",
			{"evidence_commit": evidence_commit})
	var subject: Dictionary = commit_subject(evidence_commit)
	if not subject.get("ok", false):
		return _fail(&"evidence_commit_missing", "the evidence commit cannot be read",
			{"evidence_commit": evidence_commit})
	if str((subject.get("value", {}) as Dictionary).get("subject", "")) != EVIDENCE_SUBJECT:
		return _fail(&"evidence_subject_mismatch", "the evidence commit subject differs",
			{"actual": str((subject.get("value", {}) as Dictionary).get("subject", ""))})
	var record_blob: Dictionary = blob_bytes_at_commit(
		evidence_commit, RECORD_PATH.trim_prefix("res://"))
	if not record_blob.get("ok", false):
		return _fail(&"evidence_record_missing", "the record is absent from the evidence commit",
			{"path": RECORD_PATH})
	var record_bytes: PackedByteArray = (record_blob.get("value", {}) as Dictionary).get(
		"bytes", PackedByteArray())
	var parsed: Dictionary = _STRICT_JSON.parse_object(record_bytes.get_string_from_utf8())
	if not parsed.get("ok", false):
		return _fail(&"evidence_record_unparsable", "the committed record is not a strict object",
			{"message": str(parsed.get("message", ""))})
	var record: Dictionary = parsed.get("value", {}) as Dictionary
	var shaped: Dictionary = validate_record_shape(record)
	if not shaped.get("ok", false):
		return shaped
	var parents: Dictionary = commit_parents(evidence_commit)
	if not parents.get("ok", false):
		return parents
	var parent_ids: PackedStringArray = (parents.get("value", {}) as Dictionary).get(
		"parents", PackedStringArray())
	if parent_ids.size() != 1 or parent_ids[0] != str(record["boundary_commit"]):
		return _fail(&"evidence_parent_mismatch",
			"the evidence commit is not the sole direct child of the recorded boundary",
			{"parents": parent_ids, "boundary_commit": str(record["boundary_commit"])})
	var log_blob: Dictionary = blob_bytes_at_commit(
		evidence_commit, str(record["focused_log_path"]))
	if not log_blob.get("ok", false):
		return _fail(&"evidence_log_missing", "the focused log is absent from the evidence commit",
			{"path": str(record["focused_log_path"])})
	var validated: Dictionary = validate_boundary_record(
		record, (log_blob.get("value", {}) as Dictionary).get("bytes", PackedByteArray()))
	if not validated.get("ok", false):
		return validated
	var canonical: Dictionary = canonical_record_bytes(record)
	if not canonical.get("ok", false):
		return canonical
	if (canonical.get("value", {}) as Dictionary).get("bytes", PackedByteArray()) != record_bytes:
		return _fail(&"evidence_record_not_canonical",
			"the committed record bytes are not the canonical serialization", {})
	return _ok({"record": record.duplicate(true), "boundary_commit": str(record["boundary_commit"])})


## Canonical JSON plus exactly one trailing newline. Returns value={bytes}.
static func canonical_record_bytes(record: Dictionary) -> Dictionary:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(record)
	if not emitted.get("ok", false):
		return _fail(&"record_serialization_failed", "the record does not serialize canonically",
			{"code": str(emitted.get("code", &""))})
	return _ok({"bytes": (str(emitted["value"]) + "\n").to_utf8_buffer()})


## Reads and strict-parses the published record schema. Returns value={schema}.
static func load_record_schema() -> Dictionary:
	if not FileAccess.file_exists(RECORD_SCHEMA_PATH):
		return _fail(&"record_schema_missing", "the published record schema is absent",
			{"path": RECORD_SCHEMA_PATH})
	var parsed: Dictionary = _STRICT_JSON.parse_object(
		FileAccess.get_file_as_string(RECORD_SCHEMA_PATH))
	if not parsed.get("ok", false):
		return _fail(&"record_schema_unparsable", "the published record schema is not an object",
			{"message": str(parsed.get("message", ""))})
	return _ok({"schema": parsed.get("value", {}) as Dictionary})


## Requires a resolvable forty-hex commit that carries the frozen boundary subject and is an
## ancestor of HEAD. Returns value={boundary_commit}.
static func prove_boundary_commit(boundary_commit: String) -> Dictionary:
	if not _is_commit_id(boundary_commit):
		return _fail(&"boundary_commit_invalid", "boundary_commit is not forty lowercase hex",
			{"boundary_commit": boundary_commit})
	var subject: Dictionary = commit_subject(boundary_commit)
	if not subject.get("ok", false):
		return _fail(&"boundary_commit_missing", "the boundary commit cannot be read",
			{"boundary_commit": boundary_commit})
	if str((subject.get("value", {}) as Dictionary).get("subject", "")) != BOUNDARY_SUBJECT:
		return _fail(&"boundary_subject_mismatch", "the boundary commit subject differs",
			{"actual": str((subject.get("value", {}) as Dictionary).get("subject", ""))})
	var ancestry: Dictionary = _git(PackedStringArray([
		"merge-base", "--is-ancestor", boundary_commit, "HEAD",
	]))
	if not ancestry.get("ok", false):
		return _fail(&"boundary_commit_not_ancestor",
			"the boundary commit is not an ancestor of HEAD", {"boundary_commit": boundary_commit})
	return _ok({"boundary_commit": boundary_commit})


## Returns value={subject} for a resolvable commit.
static func commit_subject(commit: String) -> Dictionary:
	var shown: Dictionary = _git(PackedStringArray(["show", "-s", "--format=%s", commit]))
	if not shown.get("ok", false):
		return _fail(&"commit_unreadable", "the commit cannot be read", {"commit": commit})
	return _ok({"subject": str(shown["output"]).strip_edges()})


## Returns value={parents} as an ordered PackedStringArray of full parent ids.
static func commit_parents(commit: String) -> Dictionary:
	var shown: Dictionary = _git(PackedStringArray(["show", "-s", "--format=%P", commit]))
	if not shown.get("ok", false):
		return _fail(&"commit_unreadable", "the commit cannot be read", {"commit": commit})
	var parents: PackedStringArray = PackedStringArray()
	for token: String in str(shown["output"]).strip_edges().split(" ", false):
		var trimmed: String = token.strip_edges()
		if not trimmed.is_empty():
			parents.append(trimmed)
	return _ok({"parents": parents})


## Reads a blob's exact bytes from a named commit. Returns value={bytes}.
##
## OS.execute() hands stdout back as decoded lines with their separators dropped, so it cannot
## reproduce a source that ends in anything other than a single newline. Git therefore writes the
## blob to a process-local scratch file through the platform shell and FileAccess reads those bytes
## back unchanged. The scratch name mixes the process id with a digest of the object name so two
## concurrent reads inside one process cannot collide.
static func blob_bytes_at_commit(commit: String, path: String) -> Dictionary:
	var repository: String = _repository_root()
	var object_name: String = "%s:%s" % [commit, path]
	var scratch: String = OS.get_user_data_dir().path_join("p2r13-v3-blob-%d-%s.tmp" % [
		OS.get_process_id(), digest_text(object_name).substr(0, 16),
	])
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var windows: bool = OS.get_name() == "Windows"
	var shell: String = "cmd.exe" if windows else "sh"
	var shell_flag: String = "/c" if windows else "-c"
	var command: String = "git -c safe.directory=\"%s\" -C \"%s\" cat-file blob \"%s\" > \"%s\"" % [
		repository, repository, object_name, scratch,
	]
	var output: Array = []
	var exit_code: int = OS.execute(shell, PackedStringArray([shell_flag, command]), output, true)
	if exit_code != 0 or not FileAccess.file_exists(scratch):
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(scratch)
		return _fail(&"blob_missing", "the object is absent from the named commit",
			{"object": object_name})
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	DirAccess.remove_absolute(scratch)
	return _ok({"bytes": bytes})


static func digest_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func digest_text(text: String) -> String:
	return digest_bytes(text.to_utf8_buffer())


# ---- helpers ----

static func _is_lower_hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for byte: int in value.to_utf8_buffer():
		var decimal: bool = byte >= 48 and byte <= 57
		var lower_af: bool = byte >= 97 and byte <= 102
		if not decimal and not lower_af:
			return false
	return true


static func _is_sha256(value: String) -> bool:
	return _is_lower_hex(value, 64)


static func _is_commit_id(value: String) -> bool:
	return _is_lower_hex(value, 40)


static func _repository_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


## Runs git against the repository that owns res://. stderr is deliberately NOT captured: every
## caller parses the stdout of a --format query, and a git advice or warning line merged into that
## stream would be indistinguishable from a subject or a parent id. Failure is read from the exit
## code instead, which is the only signal these callers act on.
static func _git(arguments: PackedStringArray) -> Dictionary:
	var repository: String = _repository_root()
	var full: PackedStringArray = PackedStringArray([
		"-c", "safe.directory=%s" % repository, "-C", repository,
	])
	full.append_array(arguments)
	var output: Array = []
	var exit_code: int = OS.execute("git", full, output, false)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": "".join(PackedStringArray(output)),
	}


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


func _init() -> void:
	var parsed: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	if not parsed.get("ok", false):
		_reject("ARGUMENTS", parsed)
		return
	var arguments: Dictionary = parsed.get("value", {}) as Dictionary
	var values: Dictionary = arguments.get("values", {}) as Dictionary
	if str(arguments["mode"]) == "check":
		_run_check(str(values["evidence-commit"]), str(values["record"]))
		return
	_run_write(str(values["boundary-commit"]), str(values["focused-log"]), str(values["output"]))


func _run_check(evidence_commit: String, record_path: String) -> void:
	var verified: Dictionary = verify_evidence_commit(evidence_commit, record_path)
	if not verified.get("ok", false):
		_reject("CHECK", verified)
		return
	print("SCHEDULE_V3_BOUNDARY_OK: check %s" % evidence_commit)
	quit(0)


func _run_write(boundary_commit: String, focused_log: String, output: String) -> void:
	if output != RECORD_PATH:
		_reject("WRITE", _fail(&"output_path_invalid", "output is not the frozen path",
			{"expected": RECORD_PATH, "actual": output}))
		return
	if FileAccess.file_exists(RECORD_PATH):
		_reject("WRITE", _fail(&"output_already_exists",
			"the record already exists and is never overwritten", {"path": RECORD_PATH}))
		return
	var built: Dictionary = build_boundary_record(boundary_commit, focused_log)
	if not built.get("ok", false):
		_reject("WRITE", built)
		return
	var canonical: Dictionary = canonical_record_bytes(
		(built.get("value", {}) as Dictionary).get("record", {}) as Dictionary)
	if not canonical.get("ok", false):
		_reject("WRITE", canonical)
		return
	var written: Dictionary = _store_atomically(
		(canonical.get("value", {}) as Dictionary).get("bytes", PackedByteArray()))
	if not written.get("ok", false):
		_reject("WRITE", written)
		return
	print("SCHEDULE_V3_BOUNDARY_OK: write %s" % boundary_commit)
	quit(0)


## Writes the record through a process-local scratch file and one rename, so an interrupted run
## leaves either no record at all or a complete one -- never a truncated record that a later
## --check would have to interpret.
func _store_atomically(bytes: PackedByteArray) -> Dictionary:
	var absolute: String = ProjectSettings.globalize_path(RECORD_PATH)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return _fail(&"output_directory_failed", "the output directory cannot be created",
			{"error": directory_error})
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		return _fail(&"output_open_failed", "the scratch record cannot be opened",
			{"path": scratch})
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var rename_error: int = DirAccess.rename_absolute(scratch, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(scratch)
		return _fail(&"output_rename_failed", "the record cannot be published atomically",
			{"error": rename_error})
	return _ok({"path": RECORD_PATH})


func _reject(stage: String, envelope: Dictionary) -> void:
	printerr("SCHEDULE_V3_BOUNDARY_%s_REJECTED: %s: %s" % [
		stage, str(envelope.get("code", &"")), str(envelope.get("message", "")),
	])
	quit(1)
