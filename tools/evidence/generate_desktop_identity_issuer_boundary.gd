extends SceneTree

## Generator for evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json
## (Plan 02 Task 1 Step 1.6, dwm-p2r.16).
##
## Runs via `-s`, so this path must extend SceneTree and does its work in `_init()`, matching
## tools/evidence/validate_evidence.gd. CONSEQUENCE FOR TESTS: probe this file with
## DynamicScriptProbe.load_script() and NEVER instantiate() -- instantiating constructs a SceneTree
## and executes the tool.
##
## THE STATIC SURFACE (dwm-p2r.16 DECISION 11.1). DECISION 9.6 requires the boundary test to prove
## that this generator DERIVES the plan-line-851 preimages and to pin the four-flag CLI contract,
## but neither is observable through `_init()` without constructing a SceneTree. The three statics
## below are therefore the real implementation, and `_init()` is a thin shell that reads
## OS.get_cmdline_user_args() and delegates to them -- so the path the tests exercise IS the path
## the tool ships. This is free to define: the plan freezes no generator interface, and the
## generator itself is not surface-hashed by the boundary record.
##
## STEP 1.3 SCOPE (dwm-p2r.16 DECISION 12.10). The three statics are real; the RECORD GENERATION
## body is not. Proving the named commit is an ancestor of HEAD, hashing every bound source from
## that commit's tree, hashing the focused log, validating the 22-key schema, writing the canonical
## record and byte-comparing under --check all belong to Step 1.6, and their inputs -- the .16 code
## commit and evidence/phase_2r/logs/p2r16-identity-catalog-green.log -- do not exist until Steps
## 1.5 and 1.6 respectively. `_init()` therefore validates its arguments for real and then exits
## nonzero with a typed marker, the exit-code analogue of the `not_implemented` envelope
## (DECISION 8.7). Step 1.4 never invokes `_init()`; only the three statics are tested.
##
## `public_surface_sha256` and its two siblings are DERIVED by parsing the public func declarations
## of the issuer, root store, and day advance port in source order with types stripped -- never
## hardcoded -- so that a rename, reorder, or arity change genuinely breaks the hash (DECISION 8.1).

const _VALUED_FLAGS := ["boundary-commit", "focused-log", "output"]
const _MODE_FLAGS := ["write", "check"]
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const _OWNER_BEADS_ID := "dwm-p2r.16"
const _BOUNDARY_SUBJECT := "feat(desktop): bind production identity issuance and catalog projections"
const _FOCUSED_LOG_PATH := "res://evidence/phase_2r/logs/p2r16-identity-catalog-green.log"
const _OUTPUT_PATH := "res://evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json"
const _RECORD_KEYS := [
	"boundary_commit",
	"boundary_subject",
	"data_catalog_path",
	"data_catalog_sha256",
	"day_advance_identity_port_path",
	"day_advance_identity_port_public_surface_sha256",
	"day_advance_identity_port_sha256",
	"focused_log_path",
	"focused_log_sha256",
	"issuer_path",
	"issuer_sha256",
	"operation_journal_path",
	"operation_journal_sha256",
	"owner_beads_id",
	"public_surface_sha256",
	"root_store_path",
	"root_store_public_surface_sha256",
	"root_store_sha256",
	"schedule_registry_path",
	"schedule_registry_sha256",
	"schema_version",
	"shop_registry_path",
	"shop_registry_sha256",
]
const _SOURCE_BINDINGS := [
	{"path_field": "issuer_path", "hash_field": "issuer_sha256",
		"path": "scripts/application/desktop/DesktopIdentityNonceIssuer.gd"},
	{"path_field": "root_store_path", "hash_field": "root_store_sha256",
		"path": "scripts/infrastructure/identity/DesktopIssuerRootStore.gd"},
	{"path_field": "day_advance_identity_port_path", "hash_field": "day_advance_identity_port_sha256",
		"path": "scripts/application/run/CausalDayAdvanceIdentityPort.gd"},
	{"path_field": "operation_journal_path", "hash_field": "operation_journal_sha256",
		"path": "scripts/infrastructure/save/DesktopContinuationOperationJournal.gd"},
	{"path_field": "data_catalog_path", "hash_field": "data_catalog_sha256",
		"path": "scripts/data/DataCatalog.gd"},
	{"path_field": "schedule_registry_path", "hash_field": "schedule_registry_sha256",
		"path": "scripts/domain/schedule/ScheduleActionRegistry.gd"},
	{"path_field": "shop_registry_path", "hash_field": "shop_registry_sha256",
		"path": "scripts/domain/shop/MinesweeperShopRegistry.gd"},
]
const _SURFACE_BINDINGS := [
	{"path": "scripts/application/desktop/DesktopIdentityNonceIssuer.gd",
		"field": "public_surface_sha256"},
	{"path": "scripts/infrastructure/identity/DesktopIssuerRootStore.gd",
		"field": "root_store_public_surface_sha256"},
	{"path": "scripts/application/run/CausalDayAdvanceIdentityPort.gd",
		"field": "day_advance_identity_port_public_surface_sha256"},
]


## Extracts the public surface preimage from GDScript source text.
##
## Pure by design (dwm-p2r.16 DECISION 11.2): taking text rather than a path is the only way to
## prove the parser's own rules without mutating a real production file -- in particular DECISION
## 8.2's trap, that `configure(_root_store)` must NOT reduce to `configure(root_store)`. A parser
## that helpfully stripped a leading underscore would give the right answer for today's source and
## the wrong one after a genuine rename.
##
## Frozen rules (dwm-p2r.16 DECISION 11.3): only lines beginning exactly with `func ` at column
## zero are recognized, so `@warning_ignore` annotations, `##` doc comments, and indented
## inner-class methods are all skipped; underscore-prefixed names are excluded; parameter types and
## default values are stripped, leaving the parameter NAME as the frozen unit; `static func` is
## deliberately NOT recognized, so converting a surface method to static breaks the hash loudly.
## Entries join their parameters with a bare comma and no space, and every entry ends in a newline.
##
## The `## ` skip rule is load-bearing rather than decorative: DesktopIdentityNonceIssuer.gd's own
## header literally contains the frozen preimage lines as doc comments, so a parser matching
## `name(args)` anywhere in a line would read its documentation instead of its code.
static func parse_public_surface(source_text: String) -> Dictionary:
	var preimage: String = ""
	for raw_line: String in source_text.split("\n"):
		if not raw_line.begins_with("func "):
			continue
		var signature: String = raw_line.substr(5)
		var open_at: int = signature.find("(")
		var close_at: int = signature.rfind(")")
		if open_at < 0 or close_at < open_at:
			continue
		var method_name: String = signature.substr(0, open_at).strip_edges()
		if method_name.begins_with("_"):
			continue
		var parameter_names: PackedStringArray = PackedStringArray()
		var parameter_text: String = signature.substr(open_at + 1, close_at - open_at - 1)
		for parameter: String in parameter_text.split(",", false):
			var trimmed: String = parameter.strip_edges()
			if trimmed.is_empty():
				continue
			var cut: int = trimmed.length()
			var colon_at: int = trimmed.find(":")
			if colon_at >= 0:
				cut = colon_at
			var equals_at: int = trimmed.find("=")
			if equals_at >= 0 and equals_at < cut:
				cut = equals_at
			parameter_names.append(trimmed.substr(0, cut).strip_edges())
		preimage += "%s(%s)\n" % [method_name, ",".join(parameter_names)]
	return _ok({"preimage": preimage})


## Reads a GDScript file, delegates to parse_public_surface(), and adds the lowercase SHA-256 of
## the resulting preimage. Returns value={preimage, sha256}.
static func derive_public_surface(source_path: String) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return _fail(&"missing_surface_source", "the bound source file is absent",
			{"path": source_path})
	var parsed: Dictionary = parse_public_surface(FileAccess.get_file_as_string(source_path))
	if not parsed.get("ok", false):
		return parsed
	var preimage: String = str((parsed.get("value", {}) as Dictionary).get("preimage", ""))
	return _ok({"preimage": preimage, "sha256": _digest(preimage)})


## Validates the exact plan-line-851 command line: --boundary-commit, --focused-log, --output, and
## exactly one of --write|--check. Returns value={boundary_commit, focused_log, output, mode}.
##
## No rejection code below is asserted by the boundary test, which requires only failure plus
## `code != not_implemented` (DECISION 9.9): plan line 851 freezes no code literals for this tool,
## and DECISION 5 refuses to hardcode what the plan never froze. validate_evidence.gd sets the repo
## precedent of rejecting a mode-flag count other than one.
static func parse_arguments(args: PackedStringArray) -> Dictionary:
	var values: Dictionary = {}
	var mode: String = ""
	for raw_argument: String in args:
		var argument: String = String(raw_argument)
		if argument.begins_with("--") and argument.substr(2) in _MODE_FLAGS:
			if not mode.is_empty():
				return _fail(&"ambiguous_generator_mode",
					"exactly one of --write or --check is accepted",
					{"first": mode, "second": argument.substr(2)})
			mode = argument.substr(2)
			continue
		var split_at: int = argument.find("=")
		if not argument.begins_with("--") or split_at < 0:
			return _fail(&"unknown_generator_argument", "the argument is not part of the contract",
				{"argument": argument})
		var flag: String = argument.substr(2, split_at - 2)
		if not (flag in _VALUED_FLAGS):
			return _fail(&"unknown_generator_argument", "the flag is not part of the contract",
				{"flag": flag})
		if values.has(flag):
			return _fail(&"duplicate_generator_argument", "a flag is supplied twice",
				{"flag": flag})
		var value: String = argument.substr(split_at + 1)
		if value.is_empty():
			return _fail(&"blank_generator_argument", "a flag value is never blank", {"flag": flag})
		values[flag] = value
	if mode.is_empty():
		return _fail(&"generator_mode_required", "exactly one of --write or --check is required",
			{})
	for required: String in _VALUED_FLAGS:
		if not values.has(required):
			return _fail(&"missing_generator_argument", "a required flag is absent",
				{"flag": required})
	return _ok({
		"boundary_commit": str(values["boundary-commit"]),
		"focused_log": str(values["focused-log"]),
		"output": str(values["output"]),
		"mode": mode,
	})


## Builds the immutable candidate exclusively from the named commit tree and permanent focused
## log. The working-tree source files are deliberately not inputs: after `.9` closes, the v1
## record remains historical evidence even when those files lawfully evolve.
static func build_boundary_record(boundary_commit: String, focused_log: String) -> Dictionary:
	if not _is_commit_id(boundary_commit):
		return _fail(&"boundary_commit_invalid", "boundary_commit must be forty lowercase hex characters",
			{"boundary_commit": boundary_commit})
	if focused_log != _FOCUSED_LOG_PATH:
		return _fail(&"focused_log_path_invalid", "focused_log is not the frozen path",
			{"path": focused_log})
	var commit_proof: Dictionary = _prove_commit(boundary_commit)
	if not commit_proof.get("ok", false):
		return commit_proof
	if not FileAccess.file_exists(focused_log):
		return _fail(&"focused_log_missing", "the permanent focused log is absent", {"path": focused_log})
	var record: Dictionary = {
		"schema_version": 1,
		"owner_beads_id": _OWNER_BEADS_ID,
		"boundary_subject": _BOUNDARY_SUBJECT,
		"boundary_commit": boundary_commit,
		"focused_log_path": focused_log.trim_prefix("res://"),
		"focused_log_sha256": _digest_bytes(FileAccess.get_file_as_bytes(focused_log)),
	}
	var source_texts: Dictionary = {}
	for binding: Dictionary in _SOURCE_BINDINGS:
		var path: String = str(binding["path"])
		var source: Dictionary = _source_at_commit(boundary_commit, path)
		if not source.get("ok", false):
			return source
		var text: String = str((source.get("value", {}) as Dictionary).get("text", ""))
		source_texts[path] = text
		record[str(binding["path_field"])] = path
		record[str(binding["hash_field"])] = _digest_bytes(
			(source.get("value", {}) as Dictionary).get("bytes", PackedByteArray()))
	for binding: Dictionary in _SURFACE_BINDINGS:
		var path: String = str(binding["path"])
		var parsed_surface: Dictionary = parse_public_surface(str(source_texts[path]))
		if not parsed_surface.get("ok", false):
			return parsed_surface
		var preimage: String = str((parsed_surface.get("value", {}) as Dictionary).get("preimage", ""))
		record[str(binding["field"])] = _digest(preimage)
	var valid: Dictionary = validate_boundary_record(record, false)
	if not valid.get("ok", false):
		return valid
	return _ok({"record": record})


## Permanent verifier used by the default boundary test. With require_current=true it additionally
## enforces the temporary current-working-tree invariant required at `.9` entry and close.
static func validate_boundary_record(record: Dictionary, require_current: bool) -> Dictionary:
	var keys: Array = record.keys()
	keys.sort()
	if keys != _RECORD_KEYS:
		return _fail(&"boundary_member_set_invalid", "the boundary record member set is not exact",
			{"expected": _RECORD_KEYS, "actual": keys})
	if typeof(record["schema_version"]) != TYPE_INT or int(record["schema_version"]) != 1:
		return _fail(&"boundary_schema_version_invalid", "schema_version must be exactly one", {})
	if str(record["owner_beads_id"]) != _OWNER_BEADS_ID \
			or str(record["boundary_subject"]) != _BOUNDARY_SUBJECT:
		return _fail(&"boundary_owner_invalid", "owner or subject does not match the frozen contract", {})
	var boundary_commit: String = str(record["boundary_commit"])
	if not _is_commit_id(boundary_commit):
		return _fail(&"boundary_commit_invalid", "boundary_commit must be forty lowercase hex characters", {})
	var commit_proof: Dictionary = _prove_commit(boundary_commit)
	if not commit_proof.get("ok", false):
		return commit_proof
	if str(record["focused_log_path"]) != _FOCUSED_LOG_PATH.trim_prefix("res://"):
		return _fail(&"focused_log_path_invalid", "focused_log_path is not frozen", {})
	if not FileAccess.file_exists(_FOCUSED_LOG_PATH):
		return _fail(&"focused_log_missing", "the permanent focused log is absent", {})
	if _digest_bytes(FileAccess.get_file_as_bytes(_FOCUSED_LOG_PATH)) != str(record["focused_log_sha256"]):
		return _fail(&"focused_log_hash_mismatch", "the permanent focused log bytes differ", {})
	var source_texts: Dictionary = {}
	for binding: Dictionary in _SOURCE_BINDINGS:
		var path: String = str(binding["path"])
		if str(record[str(binding["path_field"])]) != path:
			return _fail(&"boundary_source_path_invalid", "a bound source path differs", {"path": path})
		var source: Dictionary = _source_at_commit(boundary_commit, path)
		if not source.get("ok", false):
			return source
		var text: String = str((source.get("value", {}) as Dictionary).get("text", ""))
		source_texts[path] = text
		if _digest_bytes((source.get("value", {}) as Dictionary).get("bytes", PackedByteArray())) \
				!= str(record[str(binding["hash_field"])]):
			return _fail(&"boundary_source_hash_mismatch", "a named-commit source hash differs",
				{"path": path})
		if require_current:
			var current_path: String = "res://" + path
			if not FileAccess.file_exists(current_path) \
					or _digest_bytes(FileAccess.get_file_as_bytes(current_path)) \
						!= str(record[str(binding["hash_field"])]):
				return _fail(&"boundary_current_source_hash_mismatch",
					"the temporary current-file invariant differs", {"path": path})
	for binding: Dictionary in _SURFACE_BINDINGS:
		var path: String = str(binding["path"])
		var parsed_surface: Dictionary = parse_public_surface(str(source_texts[path]))
		var preimage: String = str((parsed_surface.get("value", {}) as Dictionary).get("preimage", ""))
		if _digest(preimage) != str(record[str(binding["field"])]):
			return _fail(&"boundary_public_surface_hash_mismatch", "a public surface differs",
				{"path": path})
	for field: String in ["issuer_sha256", "root_store_sha256", "day_advance_identity_port_sha256",
			"operation_journal_sha256", "data_catalog_sha256", "schedule_registry_sha256",
			"shop_registry_sha256", "public_surface_sha256", "root_store_public_surface_sha256",
			"day_advance_identity_port_public_surface_sha256", "focused_log_sha256"]:
		if not _is_sha256(str(record[field])):
			return _fail(&"boundary_hash_invalid", "a digest is not lowercase SHA-256", {"field": field})
	return _ok({"record": record.duplicate(true)})


# ---- helpers ----

static func _digest(text: String) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func _digest_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for byte: int in value.to_utf8_buffer():
		if not (byte >= 48 and byte <= 57) and not (byte >= 97 and byte <= 102):
			return false
	return true


static func _is_commit_id(value: String) -> bool:
	return value.length() == 40 and _is_sha256(value + "0".repeat(24))


static func _repository_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")


static func _git(arguments: PackedStringArray) -> Dictionary:
	var repository: String = _repository_root()
	var full: PackedStringArray = PackedStringArray([
		"-c", "safe.directory=%s" % repository, "-C", repository,
	])
	full.append_array(arguments)
	var output: Array = []
	var exit_code: int = OS.execute("git", full, output, true)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": "".join(PackedStringArray(output)),
	}


static func _prove_commit(boundary_commit: String) -> Dictionary:
	var subject: Dictionary = _git(PackedStringArray([
		"show", "-s", "--format=%s", boundary_commit,
	]))
	if not subject.get("ok", false):
		return _fail(&"boundary_commit_missing", "the named commit cannot be read",
			{"boundary_commit": boundary_commit})
	if str(subject["output"]).strip_edges() != _BOUNDARY_SUBJECT:
		return _fail(&"boundary_subject_mismatch", "the named commit subject differs",
			{"actual": str(subject["output"]).strip_edges()})
	var ancestry: Dictionary = _git(PackedStringArray([
		"merge-base", "--is-ancestor", boundary_commit, "HEAD",
	]))
	if not ancestry.get("ok", false):
		return _fail(&"boundary_commit_not_ancestor", "the named commit is not an ancestor of HEAD",
			{"boundary_commit": boundary_commit})
	return _ok({"boundary_commit": boundary_commit})


static func _source_at_commit(boundary_commit: String, path: String) -> Dictionary:
	var bytes: Dictionary = _blob_bytes_at_commit(boundary_commit, path)
	if not bytes.get("ok", false):
		return bytes
	var raw: PackedByteArray = (bytes.get("value", {}) as Dictionary).get("bytes", PackedByteArray())
	return _ok({"text": raw.get_string_from_utf8(), "bytes": raw})


## Reads a blob's exact bytes from the named commit. OS.execute() decodes stdout into lines and
## drops their separators, so it cannot reproduce sources that end in several newlines. Git writes
## the blob directly to a process-local scratch path; FileAccess then reads those bytes unchanged.
static func _blob_bytes_at_commit(boundary_commit: String, path: String) -> Dictionary:
	var repository: String = _repository_root()
	var object_name: String = "%s:%s" % [boundary_commit, path]
	var scratch: String = OS.get_user_data_dir().path_join("p2r16-blob-%s-%s.tmp" % [
		OS.get_process_id(), _digest(path).substr(0, 12),
	])
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var redirect: String = "git -c safe.directory=\"%s\" -C \"%s\" cat-file blob %s > \"%s\"" % [
		repository, repository, object_name, scratch,
	]
	var output: Array = []
	var shell: String = "cmd.exe" if OS.get_name() == "Windows" else "sh"
	var flag: String = "/c" if OS.get_name() == "Windows" else "-c"
	var exit_code: int = OS.execute(shell, PackedStringArray([flag, redirect]), output, true)
	if exit_code != 0 or not FileAccess.file_exists(scratch):
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(scratch)
		return _fail(&"boundary_source_missing", "a bound source is absent from the named commit",
			{"path": path})
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	DirAccess.remove_absolute(scratch)
	return _ok({"bytes": raw})


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


func _init() -> void:
	var parsed: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	if not parsed.get("ok", false):
		printerr("BOUNDARY_GENERATOR_ARGUMENTS_REJECTED: %s: %s" % [
			str(parsed.get("code", &"")), str(parsed.get("message", "")),
		])
		quit(1)
		return
	var arguments: Dictionary = parsed.get("value", {})
	if str(arguments.get("output", "")) != _OUTPUT_PATH:
		printerr("BOUNDARY_GENERATOR_OUTPUT_REJECTED: output is not the frozen path")
		quit(1)
		return
	var built: Dictionary = build_boundary_record(
		str(arguments["boundary_commit"]), str(arguments["focused_log"])
	)
	if not built.get("ok", false):
		printerr("BOUNDARY_GENERATOR_BUILD_REJECTED: %s: %s" % [
			str(built.get("code", &"")), str(built.get("message", "")),
		])
		quit(1)
		return
	var record: Dictionary = (built.get("value", {}) as Dictionary).get("record", {})
	var emitted: Dictionary = _CANONICAL_JSON.stringify(record)
	if not emitted.get("ok", false):
		printerr("BOUNDARY_GENERATOR_SERIALIZATION_REJECTED: %s" % str(emitted.get("code", &"")))
		quit(1)
		return
	var expected: PackedByteArray = (str(emitted["value"]) + "\n").to_utf8_buffer()
	var mode: String = str(arguments["mode"])
	if mode == "check":
		if not FileAccess.file_exists(_OUTPUT_PATH) \
				or FileAccess.get_file_as_bytes(_OUTPUT_PATH) != expected:
			printerr("BOUNDARY_GENERATOR_CHECK_FAILED: output bytes differ")
			quit(1)
			return
	else:
		var absolute_output: String = ProjectSettings.globalize_path(_OUTPUT_PATH)
		var parent: String = absolute_output.get_base_dir()
		var directory_error: int = DirAccess.make_dir_recursive_absolute(parent)
		if directory_error != OK:
			printerr("BOUNDARY_GENERATOR_WRITE_FAILED: cannot create output directory")
			quit(1)
			return
		var file: FileAccess = FileAccess.open(_OUTPUT_PATH, FileAccess.WRITE)
		if file == null:
			printerr("BOUNDARY_GENERATOR_WRITE_FAILED: cannot open output")
			quit(1)
			return
		file.store_buffer(expected)
		file.flush()
		file.close()
	print("BOUNDARY_GENERATOR_OK: %s" % mode)
	quit(0)
