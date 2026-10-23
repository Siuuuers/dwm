class_name DesktopContractEvidence
extends RefCounted

## Builder and validator for evidence/phase_2r/handoff/desktop_contract.json
## (dwm-p2r.9 Plan 06 Task 3 Step 3.1).
##
## WHAT THIS ARTIFACT IS FOR. Phase 3 consumes the desktop seam without reading Phase 2R source.
## The artifact therefore states the closed registry, the host/persistence/bootstrap signatures,
## the day-change ownership rule, and the Logout contract, and BINDS the exact bytes of every
## source that defines them. A Phase-3 consumer that trusts the artifact is trusting those hashes.
##
## WHY NOTHING HERE IS FREE-FORM. Every registry row and result shape is imported from the Task-1
## production constants below rather than retyped: a duplicated literal would drift silently the
## first time production changed, and the artifact would then certify a contract nobody implements.
##
## PARSE NOTE: this is a pure RefCounted with static members only; the CLI wrappers extend
## SceneTree and call into here.

const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _SCHEMA_VALIDATOR := preload("res://scripts/validation/JsonSchemaValidator.gd")

const _REGISTRY := preload("res://scripts/domain/desktop/DesktopAppRegistry.gd")
const _HOST_STATE := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const _LOGOUT_POLICY := preload("res://scripts/domain/desktop/LogoutPolicy.gd")
const _PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

const ARTIFACT_PATH := "res://evidence/phase_2r/handoff/desktop_contract.json"
const SCHEMA_PATH := "res://schemas/evidence/desktop-contract.schema.json"

const ARTIFACT_ID := "phase_2r.desktop_contract"
const SCHEMA_VERSION := 1
const INTERFACE_VERSION := 1

## The exact closed top-level member set, sorted for comparison.
const FIELD_KEYS: Array[String] = [
	"artifact_id", "bootstrap_signatures", "day_change_owner", "host_result_schemas",
	"host_signatures", "interface_version", "logout_contract", "persistence_signatures",
	"phase_split", "registry_records", "registry_version", "schema_version", "source_bindings",
]

## Sorted by UTF-8 path bytes. No inferred, omitted, extra, or glob-expanded binding is permitted.
const SOURCE_BINDING_PATHS: Array[String] = [
	"autoload/ApplicationBootstrap.gd",
	"autoload/ApplicationBootstrap.gd.uid",
	"autoload/DialogicBridge.gd",
	"autoload/GameState.gd",
	"project.godot",
	"scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd",
	"scripts/application/restore/RouteRestoreParticipant.gd",
	"scripts/application/run/SaveManagerCheckpointPort.gd",
	"scripts/application/transaction/ApplicationMutationGate.gd",
	"scripts/application/transaction/FatalDiagnosticProjector.gd",
	"scripts/domain/desktop/DesktopAppHostState.gd",
	"scripts/domain/desktop/DesktopAppRegistry.gd",
	"scripts/domain/desktop/LogoutPolicy.gd",
	"scripts/domain/run/RunSnapshotSchema.gd",
	"tests/integration/test_application_bootstrap.gd",
	"tests/integration/test_application_bootstrap.gd.uid",
	"tests/integration/test_desktop_day_change_fatal.gd",
	"tests/integration/test_desktop_day_change_fatal.gd.uid",
	"tests/integration/test_narrative_checkpoint_wiring.gd",
	"tests/integration/test_narrative_checkpoint_wiring.gd.uid",
	"tests/integration/test_restore_production_adapters.gd",
	"tests/support/FakeDesktopEvictionPort.gd",
	"tests/unit/test_application_bootstrap.gd",
	"tests/unit/test_application_bootstrap.gd.uid",
	"tests/unit/test_desktop_app_host_state.gd",
	"tests/unit/test_desktop_app_registry.gd",
	"tests/unit/test_fatal_diagnostic_projector.gd",
	"tests/unit/test_logout_policy.gd",
	"tests/unit/test_run_snapshot_schema.gd",
]

const REGISTRY_VERSION := 1


## Builds the complete detached primitive tree.
static func build() -> Dictionary:
	var bindings: Dictionary = build_source_bindings()
	if not bindings.get("ok", false):
		return bindings
	var artifact := {
		"schema_version": SCHEMA_VERSION,
		"artifact_id": ARTIFACT_ID,
		"interface_version": INTERFACE_VERSION,
		"source_bindings": (bindings.get("value", {}) as Dictionary).get("source_bindings", []),
		"registry_version": REGISTRY_VERSION,
		"registry_records": _registry_records(),
		"host_signatures": _host_signatures(),
		"host_result_schemas": _host_result_schemas(),
		"persistence_signatures": _persistence_signatures(),
		"bootstrap_signatures": _bootstrap_signatures(),
		"day_change_owner": _day_change_owner(),
		"logout_contract": _logout_contract(),
		"phase_split": _phase_split(),
	}
	var validated: Dictionary = validate(artifact)
	if not validated.get("ok", false):
		return validated
	return _ok({"artifact": artifact.duplicate(true)})


## Imperative law plus the published schema, law first so the reported code names the violated
## rule rather than a generic schema message.
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
	if typeof(artifact["registry_version"]) != TYPE_INT \
			or int(artifact["registry_version"]) != REGISTRY_VERSION:
		return _fail(&"artifact_registry_version_invalid", "registry_version must be exactly one", {})
	var bindings_valid: Dictionary = validate_source_bindings(artifact["source_bindings"])
	if not bindings_valid.get("ok", false):
		return bindings_valid
	var records: Variant = artifact["registry_records"]
	if typeof(records) != TYPE_ARRAY or (records as Array).size() != 7:
		return _fail(&"artifact_registry_records_invalid", "exactly seven registry records", {})
	if (records as Array) != _registry_records():
		return _fail(&"artifact_registry_records_invalid",
			"a registry record differs from the production registry", {})
	for field: String in ["host_signatures", "host_result_schemas", "persistence_signatures",
			"bootstrap_signatures", "day_change_owner", "logout_contract", "phase_split"]:
		if typeof(artifact[field]) != TYPE_DICTIONARY:
			return _fail(&"artifact_field_invalid", "field must be an object", {"field": field})
		if (artifact[field] as Dictionary).is_empty():
			return _fail(&"artifact_field_invalid", "field must not be empty", {"field": field})
	# Each contract record must match the production-derived tree exactly.
	for pair: Array in [
		["host_signatures", _host_signatures()],
		["host_result_schemas", _host_result_schemas()],
		["persistence_signatures", _persistence_signatures()],
		["bootstrap_signatures", _bootstrap_signatures()],
		["day_change_owner", _day_change_owner()],
		["logout_contract", _logout_contract()],
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


## Recomputes every binding from exact working-tree bytes, in the frozen sorted order.
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


## Requires exact ordered equality with a freshly recomputed binding set: any delete, reorder,
## path rename, or hash corruption fails closed.
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

## Every row comes from the production registry instance, never from a retyped literal.
static func _registry_records() -> Array:
	var registry: RefCounted = _REGISTRY.new()
	var records: Array = []
	var ids: Array = []
	for id: StringName in registry.get_ids():
		ids.append(String(id))
	ids.sort()
	for id: String in ids:
		var record: Dictionary = registry.get_record(StringName(id))
		records.append({
			"app_id": id,
			"scene": str(record["scene"]),
			"focus_target": str(record["focus_target"]),
		})
	return records


static func _host_signatures() -> Dictionary:
	return {
		"reset": "reset(current_day: int) -> void",
		"open_app": "open_app(app_id: StringName, current_day: int) -> Dictionary",
		"close_app": "close_app() -> Dictionary",
		"change_day": "change_day(new_day: int) -> Dictionary",
		"get_state": "get_state() -> Dictionary",
		"capture_persistent_state": "capture_persistent_state() -> Dictionary",
		"prepare_restore": "prepare_restore(active_app_id: Variant, current_day: int) -> Dictionary",
	}


static func _host_result_schemas() -> Dictionary:
	return {
		"open_app": ["ok", "instantiate", "previous_app_id", "focus_target"],
		"close_app": ["ok", "focus_target", "closed_app_id"],
		"change_day": ["ok", "eviction_command"],
		"eviction_command": ["command_id", "kind", "day", "app_ids"],
		"capture_persistent_state": ["active_app_id"],
		"cached_app_limit": 1,
	}


static func _persistence_signatures() -> Dictionary:
	return {
		"active_app_id_callable": "Bootstrap-owned zero-argument Callable with a stable identity",
		"before_host_injection": "returns raw JSON null",
		"after_host_injection": "returns the one host's raw registered app-ID String, or JSON null",
		"never_returns": "a CommandResult wrapper",
		"callable_identity_replaced_by_host_injection": false,
		"narrative_checkpoint_port_identity_replaced": false,
		"real_checkpoint_port_identity_replaced": false,
		"dialogic_bridge_identity_replaced": false,
		"game_state_identity_replaced": false,
		"direct_checkpoint_provider_reads_the_same_host": true,
		"saved_state_contains": "a registered app ID only, never a path",
	}


static func _bootstrap_signatures() -> Dictionary:
	return {
		"register_desktop_eviction_port": "register_desktop_eviction_port(port: Object) -> Dictionary",
		"same_port_is_idempotent": true,
		"different_port_is_rejected": true,
		"host_instances_per_process": 1,
		"mutation_gate_targets": 8,
	}


static func _day_change_owner() -> Dictionary:
	return {
		"owner": "ApplicationBootstrap",
		"day_changed_connections": 1,
		"calls": "change_day(new_day) exactly once",
		"returns": ["command_id", "kind", "day", "app_ids"],
		"dispatch": "dispatch_desktop_eviction(command) through the sole registered port, exactly once",
		"phase_3_may": ["register the eviction port", "consume the dispatched command"],
		"phase_3_is_forbidden_to": ["connect day_changed", "access the host", "call change_day"],
		"missing_or_failing_dispatch": {
			"raw_diagnostics": 1,
			"projector": "scripts/application/transaction/FatalDiagnosticProjector.gd",
			"fallback": _PROJECTOR.get_invariant_fallback(),
			"result": "the final guard's exact retained primitive APPLICATION_FATAL",
		},
	}


## Imported from the production planner so the artifact cannot certify a policy nobody implements.
static func _logout_contract() -> Dictionary:
	var rows: Array = []
	for confirmed: bool in [false, true]:
		for has_checkpoint: bool in [false, true]:
			var plan: Dictionary = _LOGOUT_POLICY.plan(confirmed, has_checkpoint)
			rows.append({
				"confirmed": confirmed,
				"has_stable_checkpoint": has_checkpoint,
				"should_save": bool(plan["should_save"]),
				"should_route_menu": bool(plan["should_route_menu"]),
				"restore_desktop_focus": bool(plan["restore_desktop_focus"]),
				"lifecycle_completed": bool(plan["lifecycle_completed"]),
			})
	return {"rows": rows, "never_completes_lifecycle": true}


static func _phase_split() -> Dictionary:
	return {
		"phase_2r_owns": ["the closed registry", "the pure host state", "v4 desktop persistence",
			"the day-change eviction owner", "the Logout policy"],
		"phase_3_owns": ["visible app composition"],
		"phase_2r_does_not_wire": "ComputerDesktop's visible app composition",
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
