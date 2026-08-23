class_name MinesweeperAmendmentContractEvidence
extends RefCounted

## Builder and validator for evidence/phase_2r/contracts/minesweeper_contract.json
## (dwm-p2r.32 Plan 02 Task 9, req.test.desktop_amendment_gate).
##
## NAMED "MinesweeperAmendmentContractEvidence", NOT the brief's literal "MinesweeperContractEvidence":
## that path/class name is already owned by the retained `.9`-era Plan-06-Task-3 evidence builder
## (tools/evidence/MinesweeperContractEvidence.gd), a hard Godot global-name collision bound to a
## completely different artifact at a different path. Mirrors DesktopAmendmentContractEvidence.gd's
## own identical resolution; see the Task-9 report, Ruling 3.
##
## Every hash comes from `git show <subject_commit>:<path>`, never HEAD, never the working tree.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")
const _GIT := preload("res://tools/evidence/DesktopAmendmentEvidenceGit.gd")

const SCHEMA_PATH := "res://data/schemas/minesweeper-contract.schema.json"
const ARTIFACT_PATH := "res://evidence/phase_2r/contracts/minesweeper_contract.json"
const SUBJECT_COMMIT_SUBJECT := "feat(phase2r): seal desktop board and shop handoff contracts"
const SCHEMA_VERSION := 1

const FIELD_KEYS: Array[String] = [
	"action_matrix_records", "child_derivation_table", "desktop_board_lock",
	"generator_kernel_verifier_versions", "honest_gaps", "publication_recipes",
	"red_green_command_records", "requirement_ids", "rng_stream_contracts", "schema_version",
	"shop_capability_registry", "source_bindings", "stage_graphs", "subject_commit",
	"subject_commit_subject",
]

## Every Plan-02 minesweeper/shop production file this amendment seals, sorted by UTF-8 path
## bytes.
const SOURCE_BINDING_PATHS: Array[String] = [
	"scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd",
	"scripts/application/minesweeper/MinesweeperRoundCoordinator.gd",
	"scripts/application/shop/MinesweeperShopPurchaseParticipant.gd",
	"scripts/domain/desktop/DesktopActionReceipt.gd",
	"scripts/domain/minesweeper/MinesweeperBoardGenerator.gd",
	"scripts/domain/minesweeper/MinesweeperBoardSchema.gd",
	"scripts/domain/minesweeper/MinesweeperCapabilityRules.gd",
	"scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd",
	"scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd",
	"scripts/domain/shop/MinesweeperShopRegistry.gd",
]

const REQUIREMENT_IDS: Array[String] = _GIT.REQUIREMENT_IDS


static func _shop_capability_registry() -> Array:
	return [
		{"id": "lucky_charm", "currency": "minesweeper_coin", "price": 1,
			"cap": "once per saved branch", "effect": "future candidate gets first_cell_zero and floor-halved extras"},
		{"id": "debug_key", "currency": "minesweeper_coin", "price": 3,
			"cap": "once per saved branch", "effect": "future candidate gets forced-cell deterministic no-guess certification"},
		{"id": "supportz", "currency": "money", "price": 45,
			"cap": "once per causal day; three per saved branch", "effect": "future capacity floor decreases by one to minimum -3"},
	]


static func _rng_stream_contracts() -> Dictionary:
	return {
		"placement": {"stream_id": "minesweeper_placement_v1", "determines": "mine permutations alone"},
		"debug": {"stream_id": "minesweeper_debug_v1", "determines": "forced-cell selection and deterministic search control alone"},
		"explosion": {"stream_id": "minesweeper_explosion_v1", "determines": "hidden H/U/A assignment alone"},
	}


static func _generator_kernel_verifier_versions() -> Dictionary:
	return {"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1"}


## The Plan-02 rows of the one authoritative production derivation table
## (plan02-frozen-contracts.md's own table) relevant to minesweeper/desktop production.
static func _child_derivation_table() -> Array:
	return [
		{"child_kind": "board_command", "parent": "command request's purpose-transaction_id receipt",
			"ordinal": "0", "source_value_set": ["H({request_fingerprint,identity_fingerprint,command_kind,pre_revision,post_revision})"]},
		{"child_kind": "board_start", "parent": "first-Reveal request's purpose-transaction_id receipt",
			"ordinal": "0", "source_value_set": ["H({identity,difficulty_id,first_cell,board_revision,rounds_before,rounds_after,motivation_before,motivation_after,layout_sha256,proof_sha256,checkpoint_id})"]},
		{"child_kind": "shop_quote", "parent": "quote allocation's purpose-transaction_id receipt",
			"ordinal": "0", "source_value_set": ["request_fingerprint"]},
		{"child_kind": "desktop_action", "parent": "prepared action's purpose-transaction_id receipt",
			"ordinal": "0", "source_value_set": ["action_kind", "source_commit_receipt_id", "H(action_candidate)"]},
		{"child_kind": "causal_sequence", "parent": "sequence_candidate.transaction_issuer_receipt",
			"ordinal": "0", "source_value_set": ["source_commit_receipt_id", "H({run_id,branch_id,desktop_timeline_generation,causal_day_instance,causal_sequence,run_revision})"]},
		{"child_kind": "board_fate", "parent": "Schedule command root for schedule_done; validated action root for condition_departure",
			"ordinal": "0", "source_value_set": ["H({board_identity,board_revision,causal_day_instance,fate})", "source_action_commit_receipt_id (when nonnull)"]},
		{"child_kind": "continuation_operation", "parent": "checkpoint_header.transaction_issuer_receipt",
			"ordinal": "exact stage/progress/cleanup ordinal frozen above", "source_value_set": ["checkpoint_sha256", "recovery_payload_sha256", "source_commit_receipt_id"]},
	]


static func _stage_graphs() -> Dictionary:
	return {
		"action_source": {
			"kinds": ["minesweeper_round", "shop_purchase"],
			"stages": ["action_checkpointed", "action_prepared", "sequence_committed", "action_committed",
				"condition_committed", "board_fate_committed", "schedule_view_committed",
				"consequence_checkpointed", "publication_pending"],
			"ordinals": {"action_checkpointed": 0, "action_prepared": 1, "sequence_committed": 2,
				"action_committed": 3, "condition_committed": 4, "board_fate_committed": 5,
				"schedule_view_committed": 6, "consequence_checkpointed": 7, "publication_pending": 8},
			"appended_callback_ordinals": {"causal_sequence": 9, "action_source": 10, "board_fate": 11, "terminal_cleanup": 12},
		},
		"schedule_done": {
			"stages": ["prepared_checkpointed", "sequence_committed", "schedule_committed",
				"board_fate_committed", "day_start_committed", "departure_checkpointed", "publication_pending"],
			"ordinals": {"prepared_checkpointed": 0, "sequence_committed": 1, "schedule_committed": 2,
				"board_fate_committed": 3, "day_start_committed": 4, "departure_checkpointed": 5,
				"publication_pending": 6},
			"appended_callback_ordinals": {"causal_sequence": 7, "schedule_commit": 8, "board_fate": 9,
				"day_resolution_start": 10, "resolution_resume": 11, "terminal_cleanup": 12},
			"not_owned_by_this_plan": true,
		},
	}


static func _publication_recipes() -> Dictionary:
	return {
		"action_source_no_departure": ["causal_sequence", "action_source"],
		"action_source_departure": ["causal_sequence", "action_source", "board_fate"],
		"schedule_done": ["causal_sequence", "schedule_commit", "board_fate", "day_resolution_start"],
		"recipe_never_contains": ["admission_checkpoint_receipt", "current checkpoint_receipt",
			"checkpoint candidate", "publication_plan_sha256", "recovery_payload_sha256"],
	}


## Representative, real, and mutation-tested Lucky/Debug/Supportz certification rows this
## amendment proves against real production ports; each row's status is honestly reported
## (`proven` where a real production port reaches it, `fail_closed_unreachable` where an honest
## gap keeps it unreachable through this graph -- see honest_gaps).
## Every row's status is honestly reported against the REAL Bootstrap-constructed production
## graph (tests/integration/test_desktop_action_matrix.gd), not a separately hand-wired stack.
## `quote()` rows are `proven` -- it never reads the placeholder identity context, so registry/
## price/currency/quote_id contracts are genuinely provable. Every row that would go on to spend
## currency, grant a capability, or admit a causal transaction is `fail_closed_unreachable`: both
## honest gaps (missing generation/checkpoint adapter; placeholder identity context) block it, and
## the matrix proves the REJECTION, not a fabricated success.
static func _action_matrix_records() -> Array:
	return [
		{"row_id": "shop.lucky_charm.quote", "app_id": "shop", "difficulty_or_item": "lucky_charm",
			"expected_capability": "registry price 1 minesweeper_coin, cap once per saved branch", "status": "proven"},
		{"row_id": "shop.debug_key.quote", "app_id": "shop", "difficulty_or_item": "debug_key",
			"expected_capability": "registry price 3 minesweeper_coin, cap once per saved branch", "status": "proven"},
		{"row_id": "shop.supportz.quote", "app_id": "shop", "difficulty_or_item": "supportz",
			"expected_capability": "registry price 45 money, cap once per causal day/three per branch", "status": "proven"},
		{"row_id": "shop.lucky_charm.prepare_purchase", "app_id": "shop", "difficulty_or_item": "lucky_charm",
			"expected_capability": "first_cell_zero and floor-halved extras", "status": "fail_closed_unreachable"},
		{"row_id": "shop.debug_key.prepare_purchase", "app_id": "shop", "difficulty_or_item": "debug_key",
			"expected_capability": "forced-cell deterministic no-guess certification", "status": "fail_closed_unreachable"},
		{"row_id": "shop.supportz.prepare_purchase", "app_id": "shop", "difficulty_or_item": "supportz",
			"expected_capability": "capacity floor decreases by one to minimum -3", "status": "fail_closed_unreachable"},
		{"row_id": "minesweeper.round.complete_round", "app_id": "minesweeper", "difficulty_or_item": "beginner",
			"expected_capability": "action_consequence_accepted with no-departure disposition", "status": "fail_closed_unreachable"},
		{"row_id": "minesweeper.round.reveal", "app_id": "minesweeper", "difficulty_or_item": "beginner",
			"expected_capability": "first Reveal materializes a certified board", "status": "fail_closed_unreachable"},
	]


static func _desktop_board_lock() -> Dictionary:
	return {
		"removed": false, "owner_present": "minesweeper_board",
		"reason": "SaveManagerMinesweeperPort.gd (retained .9-era, still wired into production via " \
			+ "ApplicationBootstrap._configure_minesweeper_rounds) still declares BOARD_LOCK_OWNER " \
			+ "= minesweeper_board and still delegates lock-owner operations for it; removing the " \
			+ "owner would break that live production consumer's own save-lock behavior during an " \
			+ "active Minesweeper round.",
		"deferred_to": "dwm-oyo.3",
	}


static func _honest_gaps() -> Array:
	return _GIT.honest_gaps()


static func build(repository_root: String, subject_commit: String) -> Dictionary:
	if not _GIT.is_commit_id(subject_commit):
		return _fail(&"subject_commit_invalid", "subject_commit is not forty lowercase hex", {})
	var subject: Dictionary = _GIT.commit_subject(repository_root, subject_commit)
	if not subject.get("ok", false):
		return _fail(&"subject_commit_missing", "the subject commit cannot be read", {"subject_commit": subject_commit})
	if str((subject.get("value", {}) as Dictionary).get("subject", "")) != SUBJECT_COMMIT_SUBJECT:
		return _fail(&"subject_commit_subject_mismatch", "the subject commit subject differs",
			{"actual": str((subject.get("value", {}) as Dictionary).get("subject", ""))})
	var ancestry: Dictionary = _GIT.git_run(repository_root, PackedStringArray(
		["merge-base", "--is-ancestor", subject_commit, "HEAD"]))
	if not ancestry.get("ok", false):
		return _fail(&"subject_commit_not_ancestor", "subject_commit is not an ancestor of HEAD",
			{"subject_commit": subject_commit})
	var bindings: Dictionary = build_source_bindings(repository_root, subject_commit)
	if not bindings.get("ok", false):
		return bindings
	var document := {
		"schema_version": SCHEMA_VERSION,
		"subject_commit": subject_commit,
		"subject_commit_subject": SUBJECT_COMMIT_SUBJECT,
		"requirement_ids": REQUIREMENT_IDS.duplicate(),
		"source_bindings": (bindings.get("value", {}) as Dictionary).get("source_bindings", []),
		"shop_capability_registry": _shop_capability_registry(),
		"rng_stream_contracts": _rng_stream_contracts(),
		"generator_kernel_verifier_versions": _generator_kernel_verifier_versions(),
		"child_derivation_table": _child_derivation_table(),
		"stage_graphs": _stage_graphs(),
		"publication_recipes": _publication_recipes(),
		"action_matrix_records": _action_matrix_records(),
		"desktop_board_lock": _desktop_board_lock(),
		"honest_gaps": _honest_gaps(),
		"red_green_command_records": _GIT.build_red_green_command_records(repository_root),
	}
	var validated: Dictionary = validate(document, repository_root)
	if not validated.get("ok", false):
		return validated
	return _ok({"document": document.duplicate(true)})


static func validate(document: Dictionary, repository_root: String) -> Dictionary:
	var lawful: Dictionary = validate_law(document, repository_root)
	if not lawful.get("ok", false):
		return lawful
	return validate_schema(document)


static func validate_law(document: Dictionary, repository_root: String) -> Dictionary:
	var keys: Array = document.keys()
	keys.sort()
	var expected: Array = FIELD_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return _fail(&"document_member_set_invalid", "the top-level member set is not exact",
			{"expected": expected, "actual": keys})
	if typeof(document["schema_version"]) != TYPE_INT or int(document["schema_version"]) != SCHEMA_VERSION:
		return _fail(&"document_schema_version_invalid", "schema_version must be exactly one", {})
	if not _GIT.is_commit_id(str(document["subject_commit"])):
		return _fail(&"subject_commit_invalid", "subject_commit is not forty lowercase hex", {})
	if str(document["subject_commit_subject"]) != SUBJECT_COMMIT_SUBJECT:
		return _fail(&"subject_commit_subject_mismatch", "subject_commit_subject is not the frozen subject", {})
	var req_ids: Array = (document["requirement_ids"] as Array).duplicate()
	req_ids.sort()
	var expected_req_ids: Array = REQUIREMENT_IDS.duplicate()
	expected_req_ids.sort()
	if req_ids != expected_req_ids:
		return _fail(&"requirement_ids_invalid", "requirement_ids is not the exact frozen set", {})
	if bool((document["desktop_board_lock"] as Dictionary).get("removed", true)) != false:
		return _fail(&"desktop_board_lock_invalid", "desktop_board_lock.removed must be false", {})
	var bindings_valid: Dictionary = validate_source_bindings(document["source_bindings"], repository_root,
		str(document["subject_commit"]))
	if not bindings_valid.get("ok", false):
		return bindings_valid
	for pair: Array in [
		["shop_capability_registry", _shop_capability_registry()],
		["rng_stream_contracts", _rng_stream_contracts()],
		["generator_kernel_verifier_versions", _generator_kernel_verifier_versions()],
		["child_derivation_table", _child_derivation_table()],
		["stage_graphs", _stage_graphs()],
		["publication_recipes", _publication_recipes()],
		["action_matrix_records", _action_matrix_records()],
		["desktop_board_lock", _desktop_board_lock()],
		["honest_gaps", _honest_gaps()],
		["red_green_command_records", _GIT.build_red_green_command_records(repository_root)],
	]:
		if document[str(pair[0])] != pair[1]:
			return _fail(&"document_field_invalid", "field differs from the production contract",
				{"field": str(pair[0])})
	return _ok({"document": document.duplicate(true)})


static func validate_schema(document: Dictionary) -> Dictionary:
	var schema: Dictionary = load_schema()
	if not schema.get("ok", false):
		return schema
	var against: Dictionary = _SCHEMA_VALIDATOR.validate(
		document, (schema.get("value", {}) as Dictionary).get("schema", {}) as Dictionary)
	if not against.get("ok", false):
		return _fail(&"document_schema_rejected", str(against.get("message", "")),
			{"errors": against.get("errors", [])})
	return _ok({"document": document.duplicate(true)})


static func build_source_bindings(repository_root: String, subject_commit: String) -> Dictionary:
	var bindings: Array = []
	for path: String in SOURCE_BINDING_PATHS:
		var blob: Dictionary = _GIT.blob_bytes_at_commit(repository_root, subject_commit, path)
		if not blob.get("ok", false):
			return _fail(&"source_binding_missing", "a bound source is absent from the subject commit",
				{"path": path})
		bindings.append({
			"path": path,
			"sha256": _GIT.digest_bytes((blob.get("value", {}) as Dictionary).get("bytes", PackedByteArray())),
		})
	return _ok({"source_bindings": bindings})


static func validate_source_bindings(bindings: Variant, repository_root: String, subject_commit: String) -> Dictionary:
	if typeof(bindings) != TYPE_ARRAY:
		return _fail(&"source_bindings_invalid", "source_bindings must be an array", {})
	var actual := bindings as Array
	if actual.size() != SOURCE_BINDING_PATHS.size():
		return _fail(&"source_bindings_invalid", "source binding cardinality differs",
			{"expected": SOURCE_BINDING_PATHS.size(), "actual": actual.size()})
	var fresh: Dictionary = build_source_bindings(repository_root, subject_commit)
	if not fresh.get("ok", false):
		return fresh
	var expected: Array = (fresh.get("value", {}) as Dictionary).get("source_bindings", [])
	for index: int in range(expected.size()):
		var recorded: Variant = actual[index]
		if typeof(recorded) != TYPE_DICTIONARY:
			return _fail(&"source_bindings_invalid", "a binding is not an object", {"index": index})
		var record := recorded as Dictionary
		var keys: Array = record.keys()
		keys.sort()
		if keys != ["path", "sha256"]:
			return _fail(&"source_bindings_invalid", "a binding member set is not exact", {"index": index})
		if str(record["path"]) != str((expected[index] as Dictionary)["path"]):
			return _fail(&"source_binding_path_mismatch", "a bound path is not frozen or is misordered",
				{"index": index, "expected": str((expected[index] as Dictionary)["path"])})
		if not _GIT.is_sha256(str(record["sha256"])):
			return _fail(&"source_binding_digest_invalid", "a digest is not lowercase SHA-256",
				{"path": str(record["path"])})
		if str(record["sha256"]) != str((expected[index] as Dictionary)["sha256"]):
			return _fail(&"source_binding_hash_mismatch", "a bound source has drifted",
				{"path": str(record["path"])})
	return _ok({"source_bindings": expected})


static func canonical_bytes(document: Dictionary) -> Dictionary:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(document)
	if not emitted.get("ok", false):
		return _fail(&"document_serialization_failed", "the document does not serialize canonically",
			{"code": str(emitted.get("code", &""))})
	return _ok({"bytes": (str(emitted["value"]) + "\n").to_utf8_buffer()})


static func write_canonical(path: String, document: Dictionary) -> Dictionary:
	var canonical: Dictionary = canonical_bytes(document)
	if not canonical.get("ok", false):
		return canonical
	var bytes: PackedByteArray = (canonical.get("value", {}) as Dictionary).get("bytes", PackedByteArray())
	var absolute: String = ProjectSettings.globalize_path(path)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		return _fail(&"output_directory_failed", "the output directory cannot be created", {"error": directory_error})
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		return _fail(&"output_open_failed", "the scratch document cannot be opened", {"path": scratch})
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var reread: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	if reread != bytes:
		DirAccess.remove_absolute(scratch)
		return _fail(&"output_reread_mismatch", "the staged bytes differ from the serialization", {})
	var parsed: Dictionary = _STRICT_JSON.parse_object(reread.get_string_from_utf8())
	if not parsed.get("ok", false):
		DirAccess.remove_absolute(scratch)
		return _fail(&"output_unparsable", "the staged document is not a strict object", {})
	var rename_error: int = DirAccess.rename_absolute(scratch, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(scratch)
		return _fail(&"output_rename_failed", "the document cannot be published atomically", {"error": rename_error})
	return _ok({"path": path})


static func load_schema() -> Dictionary:
	if not FileAccess.file_exists(SCHEMA_PATH):
		return _fail(&"document_schema_missing", "the published schema is absent", {"path": SCHEMA_PATH})
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_string(SCHEMA_PATH))
	if not parsed.get("ok", false):
		return _fail(&"document_schema_unparsable", "the published schema is not a strict object",
			{"message": str(parsed.get("message", ""))})
	return _ok({"schema": parsed.get("value", {}) as Dictionary})


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
