class_name MinesweeperContractEvidence
extends RefCounted

## Builder and validator for evidence/phase_2r/handoff/minesweeper_contract.json
## (dwm-p2r.9 Plan 06 Task 3 Step 3.1).
##
## WHAT THIS ARTIFACT IS FOR. Phase 3 drives real Minesweeper rounds through GameState's begin and
## complete methods without reading Phase 2R source. The artifact states the frozen vocabularies,
## port signatures, prepared/receipt/pending schemas, failure codes, transaction orderings, and the
## fatal-latch delegation, and BINDS the exact bytes of every source that defines them.
##
## WHY THE VOCABULARIES ARE IMPORTED. DIFFICULTIES, OUTCOMES and the failure-code set are read from
## the production contract and coordinator rather than retyped, so a vocabulary change breaks the
## artifact instead of silently certifying a stale one.
##
## PARSE NOTE: a pure RefCounted with static members only; the CLI wrappers extend SceneTree.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

const _CONTRACT := preload("res://scripts/domain/minesweeper/MinesweeperRoundContract.gd")
const _COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")
const _PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

const ARTIFACT_PATH := "res://evidence/phase_2r/handoff/minesweeper_contract.json"
const SCHEMA_PATH := "res://schemas/evidence/minesweeper-contract.schema.json"
const FIXTURE_PATH := "res://tests/fixtures/minesweeper/results.json"

const ARTIFACT_ID := "phase_2r.minesweeper_contract"
const SCHEMA_VERSION := 1
const INTERFACE_VERSION := 1

const FIELD_KEYS: Array[String] = [
	"active_round_schema", "artifact_id", "completion_order", "completion_receipt_schema",
	"difficulties", "failure_codes", "fatal_latch_contract", "fixture_ids", "interface_version",
	"outcomes", "pending_record_schema", "phase_split", "port_signatures",
	"prepared_value_schemas", "save_lock_contract", "schema_version", "source_bindings",
	"start_order", "start_request_schema",
]

## Sorted by UTF-8 path bytes. No inferred, omitted, extra, or glob-expanded binding is permitted.
const SOURCE_BINDING_PATHS: Array[String] = [
	"autoload/ApplicationBootstrap.gd",
	"autoload/ApplicationBootstrap.gd.uid",
	"autoload/GameState.gd",
	"project.godot",
	"scripts/application/minesweeper/GameStateMinesweeperPort.gd",
	"scripts/application/minesweeper/SaveManagerMinesweeperPort.gd",
	"scripts/application/transaction/ApplicationMutationGate.gd",
	"scripts/application/transaction/FatalDiagnosticProjector.gd",
	"scripts/domain/minesweeper/MinesweeperRoundContract.gd",
	"scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd",
	"tests/fixtures/minesweeper/results.json",
	"tests/integration/test_application_bootstrap.gd",
	"tests/integration/test_application_bootstrap.gd.uid",
	"tests/integration/test_minesweeper_round_coordinator.gd",
	"tests/integration/test_minesweeper_save_lock.gd",
	"tests/integration/test_restore_mutation_gate.gd",
	"tests/support/FakeApplicationMutationGate.gd",
	"tests/support/FakeMinesweeperSavePort.gd",
	"tests/support/FakeMinesweeperStatePort.gd",
	"tests/unit/test_application_bootstrap.gd",
	"tests/unit/test_application_bootstrap.gd.uid",
	"tests/unit/test_fatal_diagnostic_projector.gd",
	"tests/unit/test_minesweeper_rewards.gd",
	"tests/unit/test_minesweeper_round_contract.gd",
]


static func build() -> Dictionary:
	var bindings: Dictionary = build_source_bindings()
	if not bindings.get("ok", false):
		return bindings
	var fixtures: Dictionary = _fixture_ids()
	if not fixtures.get("ok", false):
		return fixtures
	var artifact := {
		"schema_version": SCHEMA_VERSION,
		"artifact_id": ARTIFACT_ID,
		"interface_version": INTERFACE_VERSION,
		"source_bindings": (bindings.get("value", {}) as Dictionary).get("source_bindings", []),
		"difficulties": _difficulties(),
		"outcomes": _outcomes(),
		"start_request_schema": _start_request_schema(),
		"active_round_schema": _active_round_schema(),
		"port_signatures": _port_signatures(),
		"prepared_value_schemas": _prepared_value_schemas(),
		"completion_receipt_schema": _completion_receipt_schema(),
		"pending_record_schema": _pending_record_schema(),
		"fatal_latch_contract": _fatal_latch_contract(),
		"failure_codes": _failure_codes(),
		"start_order": _start_order(),
		"completion_order": _completion_order(),
		"fixture_ids": (fixtures.get("value", {}) as Dictionary).get("fixture_ids", []),
		"save_lock_contract": _save_lock_contract(),
		"phase_split": _phase_split(),
	}
	var validated: Dictionary = validate(artifact)
	if not validated.get("ok", false):
		return validated
	return _ok({"artifact": artifact.duplicate(true)})


static func validate(artifact: Dictionary) -> Dictionary:
	var lawful: Dictionary = validate_law(artifact)
	if not lawful.get("ok", false):
		return lawful
	return validate_schema(artifact)


static func validate_law(artifact: Dictionary) -> Dictionary:
	var keys: Array = artifact.keys()
	keys.sort()
	if keys != Array(FIELD_KEYS):
		return _fail(&"artifact_member_set_invalid", "the top-level member set is not exact",
			{"expected": FIELD_KEYS, "actual": keys})
	if typeof(artifact["schema_version"]) != TYPE_INT or int(artifact["schema_version"]) != SCHEMA_VERSION:
		return _fail(&"artifact_schema_version_invalid", "schema_version must be exactly one", {})
	if str(artifact["artifact_id"]) != ARTIFACT_ID:
		return _fail(&"artifact_id_invalid", "artifact_id is not the frozen identifier", {})
	if typeof(artifact["interface_version"]) != TYPE_INT \
			or int(artifact["interface_version"]) != INTERFACE_VERSION:
		return _fail(&"artifact_interface_version_invalid", "interface_version must be exactly one", {})
	var bindings_valid: Dictionary = validate_source_bindings(artifact["source_bindings"])
	if not bindings_valid.get("ok", false):
		return bindings_valid
	var fixtures: Dictionary = _fixture_ids()
	if not fixtures.get("ok", false):
		return fixtures
	for pair: Array in [
		["difficulties", _difficulties()],
		["outcomes", _outcomes()],
		["start_request_schema", _start_request_schema()],
		["active_round_schema", _active_round_schema()],
		["port_signatures", _port_signatures()],
		["prepared_value_schemas", _prepared_value_schemas()],
		["completion_receipt_schema", _completion_receipt_schema()],
		["pending_record_schema", _pending_record_schema()],
		["fatal_latch_contract", _fatal_latch_contract()],
		["failure_codes", _failure_codes()],
		["start_order", _start_order()],
		["completion_order", _completion_order()],
		["fixture_ids", (fixtures.get("value", {}) as Dictionary).get("fixture_ids", [])],
		["save_lock_contract", _save_lock_contract()],
		["phase_split", _phase_split()],
	]:
		if artifact[str(pair[0])] != pair[1]:
			return _fail(&"artifact_field_invalid", "field differs from the production contract",
				{"field": str(pair[0])})
	return _ok({"artifact": artifact.duplicate(true)})


static func validate_schema(artifact: Dictionary) -> Dictionary:
	var schema: Dictionary = load_schema()
	if not schema.get("ok", false):
		return schema
	var against: Dictionary = _SCHEMA_VALIDATOR.validate(
		artifact, (schema.get("value", {}) as Dictionary).get("schema", {}) as Dictionary)
	if not against.get("ok", false):
		return _fail(&"artifact_schema_rejected", str(against.get("message", "")),
			{"errors": against.get("errors", [])})
	return _ok({"artifact": artifact.duplicate(true)})


static func build_source_bindings() -> Dictionary:
	var bindings: Array = []
	for path: String in SOURCE_BINDING_PATHS:
		var resource_path := "res://" + path
		if not FileAccess.file_exists(resource_path):
			return _fail(&"source_binding_missing", "a bound source is absent", {"path": path})
		bindings.append({
			"path": path,
			"sha256": digest_bytes(FileAccess.get_file_as_bytes(resource_path)),
		})
	return _ok({"source_bindings": bindings})


static func validate_source_bindings(bindings: Variant) -> Dictionary:
	if typeof(bindings) != TYPE_ARRAY:
		return _fail(&"source_bindings_invalid", "source_bindings must be an array", {})
	var actual := bindings as Array
	if actual.size() != SOURCE_BINDING_PATHS.size():
		return _fail(&"source_bindings_invalid", "source binding cardinality differs",
			{"expected": SOURCE_BINDING_PATHS.size(), "actual": actual.size()})
	var fresh: Dictionary = build_source_bindings()
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
			return _fail(&"source_bindings_invalid", "a binding member set is not exact",
				{"index": index})
		if str(record["path"]) != str((expected[index] as Dictionary)["path"]):
			return _fail(&"source_binding_path_mismatch", "a bound path is not frozen or is misordered",
				{"index": index, "expected": str((expected[index] as Dictionary)["path"]),
				"actual": str(record["path"])})
		if not _is_sha256(str(record["sha256"])):
			return _fail(&"source_binding_digest_invalid", "a digest is not lowercase SHA-256",
				{"path": str(record["path"])})
		if str(record["sha256"]) != str((expected[index] as Dictionary)["sha256"]):
			return _fail(&"source_binding_hash_mismatch", "a bound source has drifted",
				{"path": str(record["path"])})
	return _ok({"source_bindings": expected})


static func canonical_bytes(artifact: Dictionary) -> Dictionary:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(artifact)
	if not emitted.get("ok", false):
		return _fail(&"artifact_serialization_failed", "the artifact does not serialize canonically",
			{"code": str(emitted.get("code", &""))})
	return _ok({"bytes": (str(emitted["value"]) + "\n").to_utf8_buffer()})


static func load_schema() -> Dictionary:
	if not FileAccess.file_exists(SCHEMA_PATH):
		return _fail(&"artifact_schema_missing", "the published schema is absent", {"path": SCHEMA_PATH})
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_string(SCHEMA_PATH))
	if not parsed.get("ok", false):
		return _fail(&"artifact_schema_unparsable", "the published schema is not a strict object",
			{"message": str(parsed.get("message", ""))})
	return _ok({"schema": parsed.get("value", {}) as Dictionary})


static func digest_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


# ---- production-derived contract records ----

static func _difficulties() -> Array:
	var out: Array = []
	for value: StringName in _CONTRACT.DIFFICULTIES:
		out.append(String(value))
	return out


static func _outcomes() -> Array:
	var out: Array = []
	for value: StringName in _CONTRACT.OUTCOMES:
		out.append(String(value))
	return out


static func _failure_codes() -> Array:
	var out: Array = []
	for value: StringName in _COORDINATOR.FAILURE_CODES:
		out.append(String(value))
	return out


static func _start_request_schema() -> Dictionary:
	return {
		"keys": ["context", "difficulty"],
		"context": ["app", "dating"],
		"difficulty": _difficulties(),
		"untrusted": true,
		"carries_no_friend_or_entry_identifier": true,
	}


static func _active_round_schema() -> Dictionary:
	return {
		"keys": ["context", "dating_evidence", "day", "difficulty", "ordinal", "round_id", "run_id"],
		"round_id_form": "run-1:day-2:round-3",
		"app_requires_null_dating_evidence": true,
		"dating_evidence_keys": ["entry_id", "friend_ids", "route_transaction_id"],
		"dating_friend_id_count": [1, 2],
		"trusted_identity_source": "the active round, never the untrusted result input",
	}


static func _port_signatures() -> Dictionary:
	return {
		"state_port": [
			"capture() -> Dictionary",
			"prepare_begin(request: Dictionary, round_id: String) -> Dictionary",
			"prepare_complete(active_round: Dictionary, result: Dictionary, transaction_id: String) -> Dictionary",
			"finalize_complete(prepared_completion: Dictionary, checkpoint_id: String) -> Dictionary",
			"prepare_abort(active_round: Dictionary, reason: StringName, transaction_id: String) -> Dictionary",
			"commit(candidate: Dictionary) -> Dictionary",
			"rollback(backup: Dictionary) -> Dictionary",
			"publish(receipt: Dictionary, domain_events: Array[Dictionary]) -> Dictionary",
			"latch_fatal(failure: Dictionary) -> Dictionary",
			"is_fatal_latched() -> bool",
			"guard_external(operation_id: StringName) -> Dictionary",
		],
		"save_port": [
			"capture() -> Dictionary",
			"preview_checkpoint_id(run_id: String) -> Dictionary",
			"prepare_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary",
			"commit_checkpoint(candidate: Dictionary) -> Dictionary",
			"rollback(backup: Dictionary) -> Dictionary",
			"acquire_board_lock() -> Dictionary",
			"release_board_lock() -> Dictionary",
			"owns_board_lock() -> bool",
		],
		"coordinator": [
			"configure(save_port: Object, state_port: Object) -> Dictionary",
			"begin_round(request: Dictionary) -> Dictionary",
			"complete_round(round_id: String, result: Dictionary, transaction_id: String) -> Dictionary",
			"abort_round(round_id: String, reason: StringName, transaction_id: String) -> Dictionary",
			"get_active_round() -> Dictionary",
		],
		"duck_typed_alternatives_rejected_during_configure": true,
	}


static func _prepared_value_schemas() -> Dictionary:
	return {
		"prepare_begin": ["active_round", "candidate", "pre_board_checkpoint_inputs", "start_receipt"],
		"prepare_complete": ["checkpoint_input_template", "domain_events", "prepared_candidate",
			"prepared_domain_receipt"],
		"finalize_complete": ["candidate", "domain_events", "domain_receipt",
			"post_result_checkpoint_inputs"],
		"prepare_abort": ["abort_receipt", "candidate"],
		"start_receipt": ["context", "day", "difficulty", "ordinal", "round_id"],
		"round_started_event": ["context", "day", "difficulty", "event_id", "ordinal", "round_id"],
		"prepared_receipt_checkpoint_id": "",
	}


static func _completion_receipt_schema() -> Dictionary:
	return {
		"keys": ["checkpoint_id", "context", "counter_deltas", "dating_outcome_id",
			"difficulty", "effect_transaction_ids", "group_activation_transaction_id",
			"message_transaction_ids", "outcome", "round_id", "task_ids", "transaction_id"],
		"counter_delta_keys": ["app_rounds", "health", "money", "motivation", "pressure"],
		"app_requires_null_dating_outcome_id": true,
		"dating_requires_zero_app_deltas": true,
		"dating_requires_null_group_activation": true,
		"dating_requires_nonempty_dating_outcome_id": true,
	}


static func _pending_record_schema() -> Dictionary:
	return {
		"keys": ["checkpoint_id", "domain_events", "normalized_result", "phase", "receipt",
			"round_id", "transaction_id"],
		"phase": ["publish", "release_lock"],
		"normalized_result": {"keys": ["outcome"], "value_type": "String"},
		"checkpoint_id_equals_receipt_checkpoint_id": true,
		"retained_byte_equivalent_across_retries": true,
		"completed_record": ["normalized_result", "receipt"],
		"never_stores_a_bare_receipt": true,
	}


static func _fatal_latch_contract() -> Dictionary:
	return {
		"gate_methods": ["guard_external", "is_fatal_latched", "latch_fatal"],
		"shared_gate_identity": 1,
		"adapter_owns_local_fatal_field": false,
		"adapter_owns_retained_failure_cache": false,
		"first_operation_guard_precedence": true,
		"guard_operation_ids": ["minesweeper_abort_round", "minesweeper_begin_round",
			"minesweeper_complete_round", "minesweeper_recovery"],
		"recovery_order": ["complete every required recovery attempt",
			"project through the source-bound projector", "validate the full failure",
			"substitute the constant invariant fallback only on a projection or validation miss",
			"latch exactly once", "one final guard", "return the gate's exact retained result"],
		"projector": "scripts/application/transaction/FatalDiagnosticProjector.gd",
		"invariant_fallback": _PROJECTOR.get_invariant_fallback(),
		"returns": "APPLICATION_FATAL carrying the retained failure details",
		"forbidden_after_the_fence": ["outer ROLLBACK_FAILED", "a latch ok result",
			"APPLICATION_FATAL_CONFLICT", "empty fatal details"],
		"rollback_failed_is": "the retained inner FatalFailure.code and projected diagnostic identity only",
		"first_failure_remains_authoritative": true,
		"fatal_acquire_owner": null,
		"input_permanently_blocked": true,
	}


static func _start_order() -> Array:
	return [
		"state_port.guard_external(minesweeper_begin_round) as the first operation",
		"validate difficulty/context and domain availability without mutation; resolve trusted dating evidence",
		"capture the state-port backup, build the stable round id, prepare the active-round candidate",
		"prepare a pre_board checkpoint from the still-unconsumed live run",
		"commit the checkpoint journal and autosave.json as one recoverable save transaction",
		"acquire save lock owner minesweeper_board",
		"commit the prepared active-round candidate and the context-specific cost",
		"construct one detached round_started event and call state_port.publish before any emission",
		"only publication success returns the immutable active-round record",
	]


static func _completion_order() -> Array:
	return [
		"state_port.guard_external(minesweeper_complete_round) as the first operation",
		"validate a nonempty transaction_id and normalize the result for identity",
		"look up completed transactions BEFORE active-round validation",
		"resume an existing pending record only at its recorded phase",
		"validate the matching active round and the normalized result",
		"capture pre-result state/save backups and prepare the completion",
		"apply context-allowed effects to the detached candidate",
		"pass exact completed-round counts before/after to ContactInvitationState",
		"preview the checkpoint id, then finalize_complete inserts it",
		"prepare_checkpoint(post_result_checkpoint_inputs, post_result, {kind: none, reason: stage}) and reject any id disagreement",
		"commit the checkpoint, then commit the finalized state candidate without signals",
		"write the non-failing pending record with phase=publish: the post-durable boundary",
		"call the pre-emission state_port.publish",
		"change the pending phase to release_lock after successful publication",
		"store the completed record, clear active/pending state, and return a detached receipt",
	]


static func _fixture_ids() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_PATH):
		return _fail(&"fixture_set_missing", "the fixture set is absent", {"path": FIXTURE_PATH})
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_string(FIXTURE_PATH))
	if not parsed.get("ok", false):
		return _fail(&"fixture_set_unparsable", "the fixture set is not a strict object",
			{"message": str(parsed.get("message", ""))})
	var fixtures: Variant = (parsed.get("value", {}) as Dictionary).get("fixtures", [])
	if typeof(fixtures) != TYPE_ARRAY or (fixtures as Array).size() != 15:
		return _fail(&"fixture_set_invalid", "exactly fifteen fixtures are required", {})
	var ids: Array = []
	for fixture: Variant in (fixtures as Array):
		if typeof(fixture) != TYPE_DICTIONARY:
			return _fail(&"fixture_set_invalid", "a fixture is not an object", {})
		ids.append(str((fixture as Dictionary).get("fixture_id", "")))
	ids.sort()
	return _ok({"fixture_ids": ids})


static func _save_lock_contract() -> Dictionary:
	return {
		"owner": "minesweeper_board",
		"adapter_delegates_only_this_owner": true,
		"capability_while_active": {"enabled": false, "silent": true, "deferred": false},
		"manual_save_result": "save_locked",
		"quick_save_input": "consumed and ignored",
		"deferred_save_queued": false,
		"notification_toast_dialog_or_recommendation": false,
		"pre_board_autosave_precedes": ["round consumption", "save lock acquisition"],
		"pre_board_disk_write": {"kind": "autosave", "reason": "pre_board"},
		"post_result_disk_write": {"kind": "none", "reason": "stage"},
		"post_result_checkpoint_kind": "post_result",
	}


static func _phase_split() -> Dictionary:
	return {
		"phase_3_labels_its_selector": "a deterministic result simulator",
		"phase_3_calls_only": ["GameState.begin_minesweeper_round", "GameState.complete_minesweeper_round"],
		"phase_3_never_mutates": ["rewards", "counters", "invitations", "the fatal gate"],
		"phase_6_replaces": "only the simulator adapter",
		"phase_6_retains": "every contract and domain test",
		"phase_2r_implements_no_random_or_fake_board": true,
	}


# ---- helpers ----

static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for byte: int in value.to_utf8_buffer():
		var decimal: bool = byte >= 48 and byte <= 57
		var lower_af: bool = byte >= 97 and byte <= 102
		if not decimal and not lower_af:
			return false
	return true


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
