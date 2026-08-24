class_name DesktopAmendmentContractEvidence
extends RefCounted

## Builder and validator for evidence/phase_2r/contracts/desktop_contract.json
## (dwm-p2r.32 Plan 02 Task 9, req.test.desktop_amendment_gate).
##
## NAMED "DesktopAmendmentContractEvidence", NOT the brief's literal "DesktopContractEvidence":
## that path/class name is already owned by the retained `.9`-era Plan-06-Task-3 evidence builder
## (tools/evidence/DesktopContractEvidence.gd, class_name DesktopContractEvidence, a hard Godot
## global-name collision, not a documentation overlap) bound to a completely different artifact at
## a different path (evidence/phase_2r/handoff/desktop_contract.json). Mirrors this codebase's own
## established precedent for the identical situation (SaveManagerMinesweeperPort.gd ->
## SaveManagerDesktopBoardPort.gd). See the Task-9 report, Ruling 3.
##
## WHY EVERY HASH COMES FROM `git show <subject_commit>:<path>`. A document that hashed
## working-tree bytes would re-bind itself every time those files lawfully evolve after this
## amendment closes, which is the opposite of evidence (mirrors tools/schedule/
## generate_schedule_v3_boundary.gd's own stated law). `subject_commit` must be a forty-hex ancestor
## of HEAD carrying the exact frozen subject; every bound path is read from that commit's tree,
## never from HEAD and never from the working tree. Git/hash plumbing itself lives in the shared
## DesktopAmendmentEvidenceGit.gd, used by both this file and MinesweeperAmendmentContractEvidence.gd.
##
## PARSE NOTE: this is a pure RefCounted with static members only; the CLI wrapper
## (generate_desktop_amendment_evidence.gd) extends SceneTree and calls into here.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")
const _GIT := preload("res://tools/evidence/DesktopAmendmentEvidenceGit.gd")

const SCHEMA_PATH := "res://data/schemas/desktop-contract.schema.json"
const ARTIFACT_PATH := "res://evidence/phase_2r/contracts/desktop_contract.json"
const SUBJECT_COMMIT_SUBJECT := "feat(phase2r): seal desktop board and shop handoff contracts"
const SCHEMA_VERSION := 1

const FIELD_KEYS: Array[String] = [
	"action_source_recovery_apis", "board_fate_port_contract", "bootstrap_probe",
	"cas_before_mutation_law", "causal_sequence_port_contract", "causal_transaction_gate_owners",
	"checkpoint_law", "consequence_coordinator_contract", "destination_composition_owner",
	"external_stores", "honest_gaps", "red_green_command_records", "requirement_ids",
	"restore_order", "run_snapshot_v4", "schedule_view_owner", "schema_version",
	"source_bindings", "startup_order", "subject_commit", "subject_commit_subject",
]

## Every Plan-02 desktop/consequence/causal production file this amendment seals, sorted by UTF-8
## path bytes. No inferred, omitted, extra, or glob-expanded binding is permitted.
const SOURCE_BINDING_PATHS: Array[String] = [
	"autoload/ApplicationBootstrap.gd",
	"autoload/SaveManager.gd",
	"scripts/application/desktop/DesktopCausalSequencePort.gd",
	"scripts/application/desktop/DesktopConsequenceCoordinator.gd",
	"scripts/application/desktop/DesktopIdentityNonceIssuer.gd",
	"scripts/application/desktop/LogoutCoordinator.gd",
	"scripts/application/minesweeper/DesktopBoardFatePort.gd",
	"scripts/application/minesweeper/GameStateDesktopBoardPort.gd",
	"scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd",
	"scripts/application/restore/DesktopBoardRestoreParticipant.gd",
	"scripts/application/restore/DesktopConsequenceRestoreParticipant.gd",
	"scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd",
	"scripts/application/run/SaveManagerCheckpointPort.gd",
	"scripts/application/shop/GameStateMinesweeperShopPort.gd",
	"scripts/domain/desktop/DesktopAppHostState.gd",
	"scripts/domain/desktop/DesktopConsequenceState.gd",
	"scripts/domain/desktop/DesktopContinuationRemapper.gd",
	"scripts/domain/minesweeper/DesktopBoardState.gd",
	"scripts/infrastructure/identity/DesktopIssuerRootStore.gd",
	"scripts/infrastructure/save/DesktopContinuationOperationJournal.gd",
	"scripts/infrastructure/save/DesktopPublicationLedger.gd",
	"tests/integration/test_desktop_bootstrap_wiring.gd",
]

const REQUIREMENT_IDS: Array[String] = _GIT.REQUIREMENT_IDS

## Frozen live restore order (task-9-brief.md's bootstrap composition law): identity_allocation
## applies once, before the ordinary 8-participant loop SaveManager itself drives.
const RESTORE_ORDER: Array[String] = [
	"identity_allocation", "run", "desktop_consequence", "desktop_board",
	"profile", "localization", "audio", "route", "narrative",
]

## The startup order named by task-9-brief.md's "Final startup order" paragraph, as short tokens.
const STARTUP_ORDER: Array[String] = [
	"open_or_create_issuer_root_and_external_journal",
	"configure_desktop_publication_ledger",
	"construct_issuer_scoped_host_board_consequence_owners_and_action_sources",
	"inject_ledger_into_causal_round_shop_board_fate",
	"configure_v4_capture_source_loader_and_restore_participants",
	"reconcile_external_continuation_journal",
	"configure_generation_first_reveal_board_fate_shop_pending_causal_ports",
	"configure_consequence_coordinator_action_source_pair",
	"construct_but_leave_condition_departure_slots_unconfigured",
	"resume_pending_action_source_transaction_under_disabled_input",
	"configure_logout",
	"validate_evidence_bound_registries",
	"emit_application_ready",
]

## Each function is the exact production law one top-level document field must equal, mirroring
## DesktopContractEvidence.gd's own established "law function per field" pattern. Kept as static
## functions (not inline literals) so `validate_law()` can compare a document's field against a
## single production-derived source of truth.

static func _external_stores() -> Dictionary:
	return {
		"issuer_root": {
			"owner": "DesktopIssuerRootStore", "shared_with": "DesktopIdentityNonceIssuer",
			"storage": "root-scoped StorageAdapter shared with the profile", "selectable": false,
		},
		"continuation_journal": {
			"owner": "DesktopContinuationOperationJournal", "fixed_path": "desktop-continuation-operations.json",
			"constructed_by": "SaveManager.initialize()", "selectable": false,
		},
		"desktop_publication_ledger": {
			"owner": "DesktopPublicationLedger", "fixed_path": "desktop-publications.json",
			"kinds": ["minesweeper_round", "shop_purchase", "schedule_done"],
			"constructed_by": "ApplicationBootstrap._configure_desktop_production_graph()",
			"selectable": false, "distinct_from": "ScheduleFoundationPublicationLedger",
		},
	}


static func _run_snapshot_v4() -> Dictionary:
	return {
		"schema_version": 4,
		"desktop_member_keys": ["board", "consequence"],
		"admission_checkpoint_receipt_law": "immutable once set at sequence_committed; " \
			+ "byte-equal to that stage's admitted checkpoint_receipt; preserved unchanged through " \
			+ "every later forward/progress operation while checkpoint_receipt itself rotates",
		"publication_progress_prefix_ledger": "independent of recovery_payload_sha256/" \
			+ "publication_plan_sha256; advances by one appended callback-progress checkpoint per " \
			+ "successful callback, never renumbering the frozen stage ordinals",
	}


static func _causal_sequence_port_contract() -> Dictionary:
	return {
		"class": "DesktopCausalSequencePort",
		"configure_seams": ["configure_publication_ledger(publication_ledger)",
			"configure(state, mutation_gate, admission_checkpoint_port)"],
		"methods": ["prepare_reservation", "prepare_admission", "capture", "commit", "rollback", "publish"],
		"admission_point": "the final causal-sequence/run-revision compare-and-swap inside commit()",
		"gate_owner": "causal_transaction",
	}


static func _board_fate_port_contract() -> Dictionary:
	return {
		"class": "DesktopBoardFatePort",
		"configure_seams": ["configure_publication_ledger(publication_ledger)",
			"configure(board_state, identity_issuer)"],
		"methods": ["prepare_causal_departure", "prepare_projected_causal_departure",
			"capture", "commit", "rollback", "publish"],
		"fates": ["none", "discarded_unstarted", "forfeited_started"],
		"matches_plan03_consumer_seam": true,
		"owns_schedule_composition": false,
	}


static func _consequence_coordinator_contract() -> Dictionary:
	return {
		"class": "DesktopConsequenceCoordinator",
		"configure_seams": [
			"configure(state_port, causal_sequence_port, board_fate_port, checkpoint_port, mutation_gate)",
			"configure_action_source_ports(minesweeper_round_source_port, shop_purchase_source_port)",
			"configure_identity_issuer(identity_issuer)",
			"configure_condition_departure_ports(condition_policy_port, schedule_view_port) -- Plan 03 only, never called by this amendment",
		],
		"accept_prepared_action_value_keys": ["causal_sequence", "condition_receipt",
			"board_fate_receipt", "schedule_view_commit_receipt", "destination_intent",
			"notification_intent"],
		"accept_prepared_action_receipt_keys": ["receipt_id", "receipt_provenance",
			"action_commit_receipt_id", "action_commit_receipt_provenance", "causal_sequence",
			"disposition"],
		"fail_closed_until": "Plan 03 configures both configure_condition_departure_ports() arguments together",
		"resume_pending_is_boot_wired": true,
	}


static func _action_source_recovery_apis() -> Dictionary:
	return {
		"shared_signature": ["validate_recovery_action(action_candidate, action_receipt)",
			"commit_recovery_action(action_candidate, action_receipt)",
			"publish_recovery_action(publication)"],
		"minesweeper_round": {"class": "MinesweeperRoundCoordinator (application layer, no class_name)",
			"registered_without_base_configure": true},
		"shop_purchase": {"class": "MinesweeperShopPurchaseParticipant",
			"registered_without_base_configure": false},
	}


static func _checkpoint_law() -> Dictionary:
	return {
		"preimage_producer": "DesktopConsequenceState.checkpoint_content_preimage(checkpoint_header, stage_candidate)",
		"checkpoint_port": "SaveManagerCheckpointPort.prepare_consequence_checkpoint/commit_consequence_checkpoint",
		"header_fields": ["transaction_id", "transaction_issuer_receipt", "source_kind",
			"source_commit_receipt_id", "recovery_payload_sha256", "continuation_operation_ordinal"],
		"cleanup_receipt": {"pending_stage": null, "disposition": "terminal_cleanup",
			"lives_only_in_checkpoint_journal": true},
	}


static func _cas_before_mutation_law() -> Dictionary:
	return {
		"rule": "no cost, Schedule commit, board fate, ScheduleView, day start, action result, " \
			+ "or outbox may mutate live state before sequence_committed",
		"admission_point": "DesktopCausalSequencePort.commit()'s final compare-and-swap",
		"post_admission_rollback": "forbidden; recovery resumes the source-kind path forward exactly once",
	}


## The desktop-contract probe fields this amendment added to ApplicationBootstrap.
## get_desktop_contract_state() (Task 9 Phase 1), the equality/distinctness relations Phase 1's own
## tests bind, and the test-log bindings proving those relations were exercised against real
## production ports. Relation verdicts only -- never a numeric instance ID.
static func _bootstrap_probe() -> Dictionary:
	return {
		"field_keys": [
			"mutation_gate_instance_id", "continuation_journal_instance_id",
			"desktop_publication_ledger_instance_id", "host_instance_id", "board_state_instance_id",
			"consequence_state_instance_id", "causal_sequence_port_instance_id",
			"admission_checkpoint_port_instance_id", "board_fate_port_instance_id",
			"minesweeper_round_source_port_instance_id", "shop_purchase_source_port_instance_id",
			"consequence_coordinator_instance_id", "game_state_desktop_board_port_instance_id",
			"game_state_minesweeper_shop_port_instance_id", "save_manager_desktop_board_port_instance_id",
			"snapshot_provider_instance_id", "restore_order", "restore_participant_instance_ids",
			"run_snapshot_schema_version", "save_document_schema_version", "registry_versions",
			"desktop_graph_constructed", "destination_composition_ready",
		],
		"role_relations": [
			{"relation": "ledger_shared_by_causal_round_shop_board_fate", "verdict": "equal"},
			{"relation": "round_and_board_fate_share_the_same_live_board_state", "verdict": "equal"},
			{"relation": "round_and_shop_action_sources", "verdict": "distinct"},
			{"relation": "snapshot_provider_equals_game_state_instance", "verdict": "equal"},
			{"relation": "old_simulator_install_seam_untouched", "verdict": "never_written"},
			{"relation": "identical_replay_reuses_every_instance", "verdict": "stable"},
		],
		"test_log_bindings": [
			{"suite_id": "p2r9_bootstrap_wiring_check3", "log_path": "evidence/phase_2r/logs/p2r9-bootstrap-wiring-check3.log"},
		],
	}


## The repository-relative log paths _bootstrap_probe() commits this document to. Public so the
## amendment gate can assert they resolve rather than trusting the literal.
static func bootstrap_probe_log_paths() -> Array:
	var paths: Array = []
	for binding: Variant in (_bootstrap_probe()["test_log_bindings"] as Array):
		paths.append(str((binding as Dictionary)["log_path"]))
	return paths


static func _honest_gaps() -> Array:
	return _GIT.honest_gaps()


## Builds the complete detached primitive tree against the named subject commit's tree, never
## HEAD, never the working tree (except the schema itself, which is this tool's own rulebook, not
## evidence about the subject commit -- matching generate_schedule_v3_boundary.gd's identical rule).
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
	var red_green: Dictionary = _GIT.build_red_green_command_records(repository_root, subject_commit)
	if not red_green.get("ok", false):
		return red_green
	var document := {
		"schema_version": SCHEMA_VERSION,
		"subject_commit": subject_commit,
		"subject_commit_subject": SUBJECT_COMMIT_SUBJECT,
		"requirement_ids": REQUIREMENT_IDS.duplicate(),
		"source_bindings": (bindings.get("value", {}) as Dictionary).get("source_bindings", []),
		"external_stores": _external_stores(),
		"restore_order": RESTORE_ORDER.duplicate(),
		"startup_order": STARTUP_ORDER.duplicate(),
		"run_snapshot_v4": _run_snapshot_v4(),
		"causal_sequence_port_contract": _causal_sequence_port_contract(),
		"board_fate_port_contract": _board_fate_port_contract(),
		"consequence_coordinator_contract": _consequence_coordinator_contract(),
		"action_source_recovery_apis": _action_source_recovery_apis(),
		"checkpoint_law": _checkpoint_law(),
		"causal_transaction_gate_owners": ["causal_transaction", "restore", "new_run"],
		"cas_before_mutation_law": _cas_before_mutation_law(),
		"bootstrap_probe": _bootstrap_probe(),
		"schedule_view_owner": "dwm-oyo.3",
		"destination_composition_owner": "dwm-oyo.3",
		"honest_gaps": _honest_gaps(),
		"red_green_command_records": (red_green.get("value", {}) as Dictionary).get("records", []),
	}
	var validated: Dictionary = validate(document, repository_root)
	if not validated.get("ok", false):
		return validated
	return _ok({"document": document.duplicate(true)})


## Imperative law plus the published schema, law first so the reported code names the violated
## rule rather than a generic schema message (mirrors DesktopContractEvidence.gd's own precedent).
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
	if str(document["schedule_view_owner"]) != "dwm-oyo.3":
		return _fail(&"schedule_view_owner_invalid", "schedule_view_owner must be dwm-oyo.3", {})
	if str(document["destination_composition_owner"]) != "dwm-oyo.3":
		return _fail(&"destination_composition_owner_invalid", "destination_composition_owner must be dwm-oyo.3", {})
	var req_ids: Array = (document["requirement_ids"] as Array).duplicate()
	req_ids.sort()
	var expected_req_ids: Array = REQUIREMENT_IDS.duplicate()
	expected_req_ids.sort()
	if req_ids != expected_req_ids:
		return _fail(&"requirement_ids_invalid", "requirement_ids is not the exact frozen set", {})
	if (document["restore_order"] as Array) != Array(RESTORE_ORDER):
		return _fail(&"restore_order_invalid", "restore_order is not the frozen live order", {})
	if (document["startup_order"] as Array) != Array(STARTUP_ORDER):
		return _fail(&"startup_order_invalid", "startup_order is not the frozen final startup order", {})
	var bindings_valid: Dictionary = validate_source_bindings(document["source_bindings"], repository_root,
		str(document["subject_commit"]))
	if not bindings_valid.get("ok", false):
		return bindings_valid
	# Recomputed from the subject commit's own tree, exactly like source_bindings above, so an
	# empty, shrunken or dangling record set cannot pass as proof (dwm-p2r.35.5, finding B-C5).
	var red_green: Dictionary = _GIT.build_red_green_command_records(repository_root,
		str(document["subject_commit"]))
	if not red_green.get("ok", false):
		return red_green
	# Finding B-I1: the probe's declared test logs must resolve in that same tree.
	var probe_logs: Dictionary = _GIT.validate_log_paths_at_commit(repository_root,
		str(document["subject_commit"]), bootstrap_probe_log_paths())
	if not probe_logs.get("ok", false):
		return probe_logs
	for pair: Array in [
		["external_stores", _external_stores()],
		["run_snapshot_v4", _run_snapshot_v4()],
		["causal_sequence_port_contract", _causal_sequence_port_contract()],
		["board_fate_port_contract", _board_fate_port_contract()],
		["consequence_coordinator_contract", _consequence_coordinator_contract()],
		["action_source_recovery_apis", _action_source_recovery_apis()],
		["checkpoint_law", _checkpoint_law()],
		["cas_before_mutation_law", _cas_before_mutation_law()],
		["bootstrap_probe", _bootstrap_probe()],
		["honest_gaps", _honest_gaps()],
		["causal_transaction_gate_owners", ["causal_transaction", "restore", "new_run"]],
		["red_green_command_records", (red_green.get("value", {}) as Dictionary).get("records", [])],
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


## Recomputes every binding from the exact subject-commit tree, in the frozen sorted order.
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


## Atomic write through a process-local scratch file, reread+reparsed+revalidated before rename.
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


static func digest_bytes(bytes: PackedByteArray) -> String:
	return _GIT.digest_bytes(bytes)


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
