class_name Phase2RCloseoutInventory
extends RefCounted

## Strict Phase-2R closeout inventory.
##
## Binds the exact sixteen declared contract records to their requirement packets and evidence, and
## reports the two named non-contract child classes separately and unmerged. Every seam is pure: it
## reads files and the Git object database and mutates nothing.
##
## `prompt_docs/metadata/phase_2r_beads.v1.json` is the closed ordered sixteen-contract set, not a
## discovery hint, and it is the sole authority for declared evidence links. Live Beads metadata is
## consulted only for child topology, status and notes.

const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _GIT := preload("res://tools/evidence/DesktopAmendmentEvidenceGit.gd")

const MODE_PREREQUISITE := "PREREQUISITE"
const MODE_PRE_SEAL := "PRE_SEAL"
const MODE_SEALED_PRE_ATTACH := "SEALED_PRE_ATTACH"
const MODE_ATTACHED_PRE_CLOSE := "ATTACHED_PRE_CLOSE"
const MODE_POST_CLOSE := "POST_CLOSE"

const MODES: Array[String] = [
	MODE_PREREQUISITE,
	MODE_PRE_SEAL,
	MODE_SEALED_PRE_ATTACH,
	MODE_ATTACHED_PRE_CLOSE,
	MODE_POST_CLOSE,
]

const EPIC_ID := "dwm-p2r"
const CLOSEOUT_ISSUE_ID := "dwm-p2r.10"
const EXTERNAL_CONTRACT_ID := "dwm-wks"
const CONTRACT_COUNT := 16

const EVIDENCE_ROOT_RELATIVE := "evidence/phase_2r/closeout"
const EVIDENCE_LOG_ROOT_RELATIVE := "evidence/phase_2r/closeout/logs"
const EVIDENCE_COMMIT_SUBJECT := "test(phase2r): record the final foundation closeout gate"
const NOTE_PREFIX := "PHASE2R_CLOSEOUT_EVIDENCE_V1 "
const EPIC_NOTE_PREFIX := "PHASE2R_EPIC_CLOSEOUT_V1 "
const EPIC_VERDICT := "all_phase2r_contracts_closed"
const TRANSITIONS_ROOT := "evidence/phase_2r/closeout/transitions"

## The exact nine-key epic attachment, with every constant path pinned.
const EPIC_ATTACHMENT_PATHS: Dictionary = {
	"postclose_inventory_path": TRANSITIONS_ROOT + "/postclose-beads.json",
	"postclose_export_path": TRANSITIONS_ROOT + "/postclose-issues.jsonl",
	"postclose_validation_log_path": TRANSITIONS_ROOT + "/postclose-validation.log",
}
const EPIC_ATTACHMENT_KEYS: Array[String] = [
	"schema_version", "postclose_inventory_path", "postclose_inventory_sha256",
	"postclose_export_path", "postclose_export_sha256", "postclose_validation_log_path",
	"postclose_validation_log_sha256", "contract_count", "verdict",
]

## Declaration order from Plan-04 Global Constraints. Deliberately NOT sorted; sorting either list
## is a reordering that fails closed.
const HISTORICAL_HELPER_IDS: Array[String] = ["dwm-p2r.11", "dwm-p2r.7.1"]
const EXECUTION_REMEDIATION_IDS: Array[String] = [
	"dwm-p2r.17", "dwm-p2r.18", "dwm-p2r.19", "dwm-p2r.20", "dwm-p2r.21", "dwm-p2r.22",
	"dwm-p2r.23", "dwm-p2r.24", "dwm-p2r.25", "dwm-p2r.26", "dwm-p2r.27", "dwm-p2r.28",
	"dwm-p2r.29", "dwm-p2r.30", "dwm-p2r.31", "dwm-p2r.32", "dwm-p2r.33", "dwm-p2r.34",
	"dwm-p2r.35", "dwm-p2r.36", "dwm-p2r.37", "dwm-p2r.38",
]

## The sole living-path historical evidence exception: exact and closed.
const HISTORICAL_INDEX_OWNER := "dwm-p2r.1"
const HISTORICAL_INDEX_PATH := "prompt_docs/INDEX.md"
const HISTORICAL_INDEX_COMMAND := "task4-docs-after-delete"
const HISTORICAL_INDEX_SHA256 := "d30741719d690629d1d32ce3185053775bc19e058b01732cc2bbe7600dbfd408"
const HISTORICAL_INDEX_COMMIT := "d229ba82e4990336fb5309f3d6b21d16d4cae675"
const HISTORICAL_INDEX_SUBJECT := "docs: add validated Phase 2R requirement packets"
const HISTORICAL_INDEX_PARENT := "0e9ffc5232b8c79f257f3c83275714df5ee24c15"

const DEFERRED_REQUIREMENTS: Array = [
	{"obligation_id": "schedule_view_warning_done_and_terminal_intent", "owner_beads_id": "dwm-oyo.3",
		"requirement_ids": ["req.run.day7_terminal_intent", "req.schedule.done_board_fate",
			"req.schedule.warning_queue", "req.test.schedule_gate"]},
	{"obligation_id": "relationship_witness_and_dating_completion", "owner_beads_id": "dwm-oyo.4",
		"requirement_ids": []},
	{"obligation_id": "final_ending_plan_and_playback", "owner_beads_id": "dwm-oyo.6",
		"requirement_ids": ["req.ending.epilogue", "req.ending.ids", "req.ending.playback",
			"req.ending.primary"]},
	{"obligation_id": "final_full_run_evidence", "owner_beads_id": "dwm-oyo.7",
		"requirement_ids": ["req.run.day7_terminal"]},
]

const VERDICT_DECLARED := "declared"
const VERDICT_PENDING := "pending_final_gate"
const VERDICT_SATISFIED := "satisfied_by_final_gate"


# =============================================================================================
# Master seam.
# =============================================================================================

static func validate(mode: Variant, metadata_path: Variant, beads_snapshot_path: Variant,
		requirement_index_path: Variant, evidence_root: Variant) -> Dictionary:
	if typeof(mode) != TYPE_STRING or not MODES.has(mode):
		return _fail(&"invalid_closeout_mode", "the closeout mode is not one of the five closed modes",
			{"mode": mode})
	var mode_name: String = mode
	if typeof(metadata_path) != TYPE_STRING or typeof(beads_snapshot_path) != TYPE_STRING \
			or typeof(requirement_index_path) != TYPE_STRING or typeof(evidence_root) != TYPE_STRING:
		return _fail(&"invalid_closeout_mode", "every inventory input must be a path String", {})

	var metadata_result: Dictionary = _read_object(metadata_path)
	if not metadata_result.get("ok", false):
		return _fail(&"metadata_unreadable", "the Phase-2R metadata cannot be read as strict JSON",
			{"path": metadata_path})
	var metadata: Dictionary = metadata_result["value"]

	var snapshot_text: String = _read_text(beads_snapshot_path)
	if snapshot_text.is_empty():
		return _fail(&"beads_snapshot_unreadable", "the Beads snapshot is absent or empty",
			{"path": beads_snapshot_path})
	var snapshot_result: Dictionary = _STRICT_JSON._parse_value_document(snapshot_text)
	if not snapshot_result.get("ok", false) or typeof(snapshot_result.get("value")) != TYPE_ARRAY:
		return _fail(&"beads_snapshot_invalid", "the Beads snapshot is not a strict JSON array",
			{"path": beads_snapshot_path})
	var snapshot: Array = snapshot_result["value"]

	var index_text: String = _read_text(requirement_index_path)
	if index_text.is_empty():
		return _fail(&"requirement_index_unreadable", "the generated requirement index is absent",
			{"path": requirement_index_path})
	var indexed: Dictionary = _parse_requirement_index(index_text)

	var repository_root: String = _resolve_repository_root(evidence_root)
	if repository_root.is_empty():
		return _fail(&"metadata_unreadable", "the evidence root is not inside a Git repository",
			{"evidence_root": evidence_root})

	var contracts_result: Dictionary = _declared_contracts(metadata)
	if not contracts_result.get("ok", false):
		return contracts_result
	var declared: Array = contracts_result["value"]

	var by_id: Dictionary = {}
	var duplicates: Dictionary = {}
	for entry: Variant in snapshot:
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"beads_snapshot_invalid", "a snapshot record is not an object", {})
		var issue_id: String = str((entry as Dictionary).get("id", ""))
		if by_id.has(issue_id):
			duplicates[issue_id] = true
		by_id[issue_id] = entry

	var topology: Dictionary = _validate_topology(by_id, duplicates, declared)
	if not topology.get("ok", false):
		return topology

	var statuses: Dictionary = _validate_statuses(mode_name, by_id, declared)
	if not statuses.get("ok", false):
		return statuses

	var evidence: Dictionary = _validate_declared_evidence(declared, repository_root, indexed, by_id)
	if not evidence.get("ok", false):
		return evidence

	var closeout: Dictionary = by_id[CLOSEOUT_ISSUE_ID]
	var absolute_root: String = _globalize(evidence_root)

	if mode_name == MODE_PREREQUISITE:
		if DirAccess.dir_exists_absolute(absolute_root):
			return _fail(&"output_root_present", "PREREQUISITE requires the output root absent",
				{"evidence_root": evidence_root})
		var blocked: Dictionary = _reject_oyo_dependency(closeout)
		if not blocked.get("ok", false):
			return blocked
		var attached: Dictionary = _closeout_attachment_lines(closeout)
		if not (attached["lines"] as Array).is_empty():
			return _fail(&"closeout_attachment_present",
				"PREREQUISITE requires no closeout attachment", {})
		return _ok(_envelope(mode_name, evidence["value"], {}, null))

	var gate_path: String = absolute_root.path_join("gate.json")
	var gate_text: String = _read_text(gate_path)
	if gate_text.is_empty():
		return _fail(&"gate_unreadable", "the closeout gate is absent or empty", {"path": gate_path})
	var gate_result: Dictionary = _STRICT_JSON.parse_object(gate_text)
	if not gate_result.get("ok", false):
		return _fail(&"gate_unreadable", "the closeout gate is not a strict JSON object",
			{"path": gate_path})
	var gate: Dictionary = gate_result["value"]

	if mode_name == MODE_PRE_SEAL:
		var mapping: Dictionary = _validate_requirement_mapping(gate, declared, absolute_root)
		if not mapping.get("ok", false):
			return mapping
		var blocked_pre_seal: Dictionary = _reject_oyo_dependency(closeout)
		if not blocked_pre_seal.get("ok", false):
			return blocked_pre_seal
		var pre_seal_attachment: Dictionary = _closeout_attachment_lines(closeout)
		if not (pre_seal_attachment["lines"] as Array).is_empty():
			return _fail(&"closeout_attachment_present",
				"PRE_SEAL requires the closure note still absent", {})
		if _head_touches_evidence_root(repository_root):
			return _fail(&"evidence_commit_present",
				"PRE_SEAL runs before the evidence commit exists", {})
		for absent_relative: String in ["validation_receipt.json", "logs/validation-command.jsonl"]:
			if FileAccess.file_exists(absolute_root.path_join(absent_relative)):
				return _fail(&"validation_receipt_present",
					"PRE_SEAL runs before the receipt and command record are written",
					{"path": absent_relative})
		return _ok(_envelope(mode_name, evidence["value"], mapping["value"], null))

	return _validate_committed(mode_name, repository_root, absolute_root, gate, gate_text,
		snapshot_text, closeout, evidence["value"], declared)


# =============================================================================================
# Declared contracts.
# =============================================================================================

static func _declared_contracts(metadata: Dictionary) -> Dictionary:
	var declared: Array = metadata.get("child_contracts", [])
	if typeof(declared) != TYPE_ARRAY or declared.size() != CONTRACT_COUNT:
		return _fail(&"contract_count_mismatch",
			"the retained metadata must declare exactly sixteen contract records",
			{"declared": declared.size() if typeof(declared) == TYPE_ARRAY else -1})
	var seen: Dictionary = {}
	for entry: Variant in declared:
		if typeof(entry) != TYPE_DICTIONARY:
			return _fail(&"contract_count_mismatch", "a declared contract record is not an object", {})
		var issue_id: String = str((entry as Dictionary).get("issue_id", ""))
		if issue_id.is_empty() or seen.has(issue_id):
			return _fail(&"contract_count_mismatch",
				"a declared contract record is absent or duplicated", {"issue_id": issue_id})
		seen[issue_id] = true
	return _ok(declared)


static func _validate_topology(by_id: Dictionary, duplicates: Dictionary, declared: Array) -> Dictionary:
	for entry: Variant in declared:
		var issue_id: String = str((entry as Dictionary)["issue_id"])
		if not by_id.has(issue_id):
			return _fail(&"contract_record_missing", "a declared contract record is absent from Beads",
				{"issue_id": issue_id})
		if duplicates.has(issue_id):
			return _fail(&"contract_record_duplicate", "a contract record appears twice in the snapshot",
				{"issue_id": issue_id})
		var record: Dictionary = by_id[issue_id]
		var expected_spec: String = str((entry as Dictionary).get("expected_spec_id", ""))
		if expected_spec.is_empty() or str(record.get("spec_id", "")) != expected_spec:
			return _fail(&"contract_spec_mismatch", "a contract record carries the wrong specification",
				{"issue_id": issue_id, "expected": expected_spec, "spec_id": record.get("spec_id")})
		var expected_parent: String = "" if issue_id == EXTERNAL_CONTRACT_ID else EPIC_ID
		if str(record.get("parent", "")) != expected_parent:
			return _fail(&"contract_record_missing", "a contract record is not a direct epic child",
				{"issue_id": issue_id, "parent": record.get("parent")})

	var admitted: Dictionary = {}
	for entry: Variant in declared:
		var declared_id: String = str((entry as Dictionary)["issue_id"])
		if declared_id != EXTERNAL_CONTRACT_ID:
			admitted[declared_id] = "contract"
	for member: String in HISTORICAL_HELPER_IDS:
		if admitted.has(member):
			return _fail(&"class_membership_conflict", "an id is claimed by a class and the contract set",
				{"issue_id": member})
		admitted[member] = "historical_helpers"
	for member: String in EXECUTION_REMEDIATION_IDS:
		if admitted.has(member):
			return _fail(&"class_membership_conflict", "an id is claimed by two admitted sets",
				{"issue_id": member})
		admitted[member] = "execution_remediation_children"

	for member: String in HISTORICAL_HELPER_IDS + EXECUTION_REMEDIATION_IDS:
		if not by_id.has(member) or str((by_id[member] as Dictionary).get("parent", "")) != EPIC_ID:
			return _fail(&"class_member_missing", "a named non-contract child is absent from the epic",
				{"issue_id": member})
		if str((by_id[member] as Dictionary).get("status", "")) != "closed":
			return _fail(&"class_member_open", "a named non-contract child is not closed",
				{"issue_id": member})

	for issue_id: Variant in by_id:
		var record: Dictionary = by_id[issue_id]
		if str(record.get("parent", "")) != EPIC_ID:
			continue
		if not admitted.has(str(issue_id)):
			return _fail(&"direct_child_unadmitted",
				"a direct epic child is in neither the contract set nor either named class",
				{"issue_id": issue_id})
	return _ok({})


static func _validate_statuses(mode_name: String, by_id: Dictionary, declared: Array) -> Dictionary:
	var closeout: Dictionary = by_id[CLOSEOUT_ISSUE_ID]
	var closeout_status: String = str(closeout.get("status", ""))
	if mode_name != MODE_POST_CLOSE and closeout_status != "open":
		return _fail(&"closeout_issue_not_open", "the closeout issue must still be open in this mode",
			{"status": closeout_status})
	for entry: Variant in declared:
		var issue_id: String = str((entry as Dictionary)["issue_id"])
		if mode_name != MODE_POST_CLOSE and issue_id == CLOSEOUT_ISSUE_ID:
			continue
		if str((by_id[issue_id] as Dictionary).get("status", "")) != "closed":
			return _fail(&"contract_record_open", "a contract record is not closed",
				{"issue_id": issue_id})
	return _ok({})


static func _reject_oyo_dependency(closeout: Dictionary) -> Dictionary:
	for dependency: Variant in (closeout.get("dependencies", []) as Array):
		var record: Dictionary = dependency
		if str(record.get("type", "")) != "blocks":
			continue
		if str(record.get("depends_on_id", "")).begins_with("dwm-oyo"):
			return _fail(&"closeout_oyo_dependency", "the closeout issue carries an OYO dependency",
				{"depends_on_id": record.get("depends_on_id")})
	return _ok({})


# =============================================================================================
# Declared evidence links.
# =============================================================================================

static func _validate_declared_evidence(declared: Array, repository_root: String,
		indexed: Dictionary, by_id: Dictionary) -> Dictionary:
	var records: Array = []
	var living_exceptions: int = 0
	for entry: Variant in declared:
		var contract: Dictionary = entry
		var issue_id: String = str(contract["issue_id"])
		var plan_path: String = str(contract.get("plan_path", ""))
		if plan_path.is_empty() or not FileAccess.file_exists(repository_root.path_join(plan_path)):
			return _fail(&"contract_plan_path_missing", "a contract record binds an absent plan file",
				{"issue_id": issue_id, "plan_path": plan_path})
		var declared_metadata: Dictionary = contract.get("expected_metadata", {})
		var requirement_ids: Array = declared_metadata.get("requirement_ids", [])
		for requirement_id: Variant in requirement_ids:
			if not indexed.has(str(requirement_id)):
				return _fail(&"requirement_not_indexed",
					"a declared requirement does not resolve in the generated index",
					{"issue_id": issue_id, "requirement_id": requirement_id})
		var links: Array = declared_metadata.get("evidence_links", [])
		var reported: Array = []
		for link_entry: Variant in links:
			var link: Dictionary = link_entry
			var path: String = str(link.get("path", ""))
			var sha256: String = str(link.get("sha256", ""))
			if path == HISTORICAL_INDEX_PATH:
				living_exceptions += 1
				if living_exceptions > 1 or issue_id != HISTORICAL_INDEX_OWNER:
					return _fail(&"historical_exception_extra",
						"only one living-path historical exception is accepted", {"issue_id": issue_id})
				var historical: Dictionary = _validate_historical_exception(link, repository_root)
				if not historical.get("ok", false):
					return historical
			else:
				var absolute: String = repository_root.path_join(path)
				if not FileAccess.file_exists(absolute):
					return _fail(&"evidence_link_path_missing", "a declared evidence path is absent",
						{"issue_id": issue_id, "path": path})
				var actual: String = _GIT.digest_bytes(FileAccess.get_file_as_bytes(absolute))
				if actual != sha256:
					return _fail(&"evidence_link_hash_mismatch",
						"a declared evidence link does not match current repository bytes",
						{"issue_id": issue_id, "path": path, "actual": actual, "declared": sha256})
			reported.append({
				"command_record_id": str(link.get("command_record_id", "")),
				"path": path,
				"requirement_id": str(link.get("requirement_id", "")),
				"sha256": sha256,
			})
		var requirement_list: Array = []
		for requirement_id: Variant in requirement_ids:
			requirement_list.append(str(requirement_id))
		records.append({
			"issue_id": issue_id,
			"status": str((by_id[issue_id] as Dictionary).get("status", "")),
			"plan_path": plan_path,
			"spec_id": str(contract.get("expected_spec_id", "")),
			"requirement_ids": requirement_list,
			"evidence_links": reported,
			"evidence_verdict": VERDICT_DECLARED if not reported.is_empty() else VERDICT_PENDING,
		})
	return _ok(records)


static func _validate_historical_exception(link: Dictionary, repository_root: String) -> Dictionary:
	if str(link.get("command_record_id", "")) != HISTORICAL_INDEX_COMMAND \
			or str(link.get("sha256", "")) != HISTORICAL_INDEX_SHA256:
		return _fail(&"historical_exception_mismatch",
			"the living-path historical exception does not match its frozen record", {})
	var blob: Dictionary = _GIT.blob_bytes_at_commit(repository_root, HISTORICAL_INDEX_COMMIT,
		HISTORICAL_INDEX_PATH)
	if not blob.get("ok", false):
		return _fail(&"historical_exception_mismatch",
			"the historical blob is absent from its named commit", {})
	if _GIT.digest_bytes((blob["value"] as Dictionary)["bytes"]) != HISTORICAL_INDEX_SHA256:
		return _fail(&"historical_exception_mismatch",
			"the historical blob does not hash to its frozen value", {})
	var subject: Dictionary = _GIT.commit_subject(repository_root, HISTORICAL_INDEX_COMMIT)
	if not subject.get("ok", false) \
			or str((subject["value"] as Dictionary)["subject"]) != HISTORICAL_INDEX_SUBJECT:
		return _fail(&"historical_exception_mismatch",
			"the historical source commit carries another subject", {})
	var parents: Dictionary = _GIT.git_run(repository_root,
		PackedStringArray(["show", "-s", "--format=%P", HISTORICAL_INDEX_COMMIT]))
	if not parents.get("ok", false) or str(parents["output"]).strip_edges() != HISTORICAL_INDEX_PARENT:
		return _fail(&"historical_exception_mismatch",
			"the historical source commit does not have its sole recorded parent", {})
	return _ok({})


# =============================================================================================
# Requirement mapping.
# =============================================================================================

static func _expected_requirement_ids(declared: Array) -> Array:
	var deferred: Dictionary = {}
	for obligation: Dictionary in DEFERRED_REQUIREMENTS:
		for requirement_id: Variant in (obligation["requirement_ids"] as Array):
			deferred[str(requirement_id)] = true
	var union: Dictionary = {}
	for entry: Variant in declared:
		var declared_metadata: Dictionary = (entry as Dictionary).get("expected_metadata", {})
		for requirement_id: Variant in (declared_metadata.get("requirement_ids", []) as Array):
			var id: String = str(requirement_id)
			if deferred.has(id) or id.begins_with("req.ending."):
				continue
			union[id] = true
	var ids: Array = union.keys()
	ids.sort()
	return ids


static func _validate_requirement_mapping(gate: Dictionary, declared: Array,
		absolute_root: String) -> Dictionary:
	var mapping: Variant = gate.get("requirement_evidence", null)
	if typeof(mapping) != TYPE_DICTIONARY:
		return _fail(&"requirement_evidence_key_set_mismatch",
			"the gate does not carry a requirement mapping object", {})
	var expected: Array = _expected_requirement_ids(declared)
	var actual: Array = (mapping as Dictionary).keys()
	var sorted_actual: Array = actual.duplicate()
	sorted_actual.sort()
	if sorted_actual != expected:
		return _fail(&"requirement_evidence_key_set_mismatch",
			"the requirement mapping key set is not the exact fully satisfied set",
			{"expected": expected.size(), "actual": sorted_actual.size()})
	if actual != sorted_actual:
		return _fail(&"requirement_evidence_key_order",
			"the requirement mapping is not inserted in sorted requirement-ID order", {})

	var command_records: Dictionary = {}
	for entry: Variant in (gate.get("command_records", []) as Array):
		var record: Dictionary = entry
		command_records["%s|%s" % [str(record.get("command_id", "")), str(record.get("sha256", ""))]] = record
	var primary_logs: Dictionary = {}
	for entry: Variant in (gate.get("primary_logs", []) as Array):
		var log_record: Dictionary = entry
		primary_logs[str(log_record.get("path", ""))] = str(log_record.get("sha256", ""))

	var reported: Dictionary = {}
	for requirement_id: Variant in expected:
		var records: Variant = (mapping as Dictionary)[requirement_id]
		if typeof(records) != TYPE_ARRAY or (records as Array).is_empty():
			return _fail(&"requirement_evidence_record_missing",
				"a requirement maps to no fresh command record", {"requirement_id": requirement_id})
		var previous: String = ""
		var seen: Dictionary = {}
		var projected: Array = []
		for record_entry: Variant in (records as Array):
			if typeof(record_entry) != TYPE_DICTIONARY:
				return _fail(&"requirement_evidence_record_missing",
					"a requirement evidence record is not an object", {"requirement_id": requirement_id})
			var record: Dictionary = record_entry
			var command_id: String = str(record.get("command_id", ""))
			var command_record_sha256: String = str(record.get("command_record_sha256", ""))
			var log_path: String = str(record.get("log_path", ""))
			var log_sha256: String = str(record.get("log_sha256", ""))
			var ordering_key: String = "%s|%s" % [command_id, log_path]
			if seen.has(ordering_key):
				return _fail(&"requirement_evidence_record_duplicate",
					"a requirement repeats one command and log", {"requirement_id": requirement_id})
			seen[ordering_key] = true
			if not previous.is_empty() and ordering_key < previous:
				return _fail(&"requirement_evidence_record_order",
					"requirement evidence records are not ordered by command_id then log_path",
					{"requirement_id": requirement_id})
			previous = ordering_key
			var bound: String = "%s|%s" % [command_id, command_record_sha256]
			if not command_records.has(bound):
				return _fail(&"requirement_evidence_command_unbound",
					"a requirement evidence record matches no exact gate command record",
					{"requirement_id": requirement_id, "command_id": command_id})
			if not log_path.begins_with(EVIDENCE_LOG_ROOT_RELATIVE + "/") \
					or log_path.contains("..") or log_path.contains("\\"):
				return _fail(&"requirement_evidence_log_outside_root",
					"a bound log is not strictly below the closeout log root",
					{"requirement_id": requirement_id, "log_path": log_path})
			var absolute_log: String = absolute_root.path_join(log_path.trim_prefix(
				EVIDENCE_ROOT_RELATIVE + "/"))
			if not FileAccess.file_exists(absolute_log):
				return _fail(&"requirement_evidence_log_hash_mismatch", "a bound log is absent",
					{"requirement_id": requirement_id, "log_path": log_path})
			var actual_log: String = _GIT.digest_bytes(FileAccess.get_file_as_bytes(absolute_log))
			var command_record: Dictionary = command_records[bound]
			if actual_log != log_sha256 or actual_log != str(command_record.get("log_sha256", "")) \
					or actual_log != str(primary_logs.get(log_path, "")):
				return _fail(&"requirement_evidence_log_hash_mismatch",
					"a bound log does not match its command record and primary log hash",
					{"requirement_id": requirement_id, "log_path": log_path})
			projected.append({"command_id": command_id,
				"command_record_sha256": command_record_sha256, "log_path": log_path,
				"log_sha256": log_sha256})
		reported[str(requirement_id)] = projected
	return _ok(reported)


# =============================================================================================
# Committed-evidence modes.
# =============================================================================================

static func _validate_committed(mode_name: String, repository_root: String, absolute_root: String,
		gate: Dictionary, gate_text: String, snapshot_text: String, closeout: Dictionary,
		contracts: Array, declared: Array) -> Dictionary:
	var head: String = str(_GIT.git_run(repository_root,
		PackedStringArray(["rev-parse", "HEAD"]))["output"]).strip_edges()
	if not _GIT.is_commit_id(head):
		return _fail(&"evidence_commit_not_head", "the repository head cannot be resolved", {})

	var parents_output: String = str(_GIT.git_run(repository_root,
		PackedStringArray(["show", "-s", "--format=%P", head]))["output"]).strip_edges()
	var parents: PackedStringArray = PackedStringArray(parents_output.split(" ", false))
	if parents.size() != 1:
		return _fail(&"evidence_commit_not_single_parent",
			"the evidence commit must have exactly one parent", {"parents": parents.size()})

	## --raw rather than --name-only, so every changed entry's destination mode is inspected and a
	## 100755 blob or a 120000 symlink cannot pass as a regular evidence file.
	var diff: Dictionary = _GIT.git_run(repository_root,
		PackedStringArray(["diff-tree", "-r", "--no-commit-id", "--raw", head]))
	if not diff.get("ok", false):
		return _fail(&"evidence_commit_not_head", "the evidence commit diff cannot be read", {})
	var changed: Array = []
	var modes: Dictionary = {}
	for raw_line: String in str(diff["output"]).split("\n"):
		var line: String = raw_line.trim_suffix("\r")
		if line.strip_edges().is_empty():
			continue
		var tab: int = line.find("\t")
		if not line.begins_with(":") or tab < 1:
			return _fail(&"evidence_commit_not_head", "the evidence commit diff is unreadable", {})
		var fields: PackedStringArray = line.substr(1, tab - 1).split(" ", false)
		if fields.size() < 2:
			return _fail(&"evidence_commit_not_head", "the evidence commit diff is unreadable", {})
		var path: String = line.substr(tab + 1).strip_edges()
		changed.append(path)
		modes[path] = fields[1]
	if changed.is_empty():
		return _fail(&"evidence_commit_not_head", "the evidence commit is empty", {})
	var touches_root: bool = false
	for path: String in changed:
		if path.begins_with(EVIDENCE_ROOT_RELATIVE + "/"):
			touches_root = true
	if not touches_root:
		return _fail(&"evidence_commit_not_head",
			"the head commit does not carry the closeout evidence", {})

	var subject: Dictionary = _GIT.commit_subject(repository_root, head)
	if not subject.get("ok", false) \
			or str((subject["value"] as Dictionary)["subject"]) != EVIDENCE_COMMIT_SUBJECT:
		return _fail(&"evidence_commit_subject_mismatch",
			"the evidence commit carries another subject", {})

	for path: String in changed:
		if not path.begins_with(EVIDENCE_ROOT_RELATIVE + "/"):
			return _fail(&"evidence_commit_path_outside_root",
				"the evidence commit changed a path outside the closeout root", {"path": path})
		if str(modes.get(path, "")) != "100644":
			return _fail(&"evidence_commit_mode_invalid",
				"the evidence commit carries an entry that is not a regular 100644 blob",
				{"path": path, "mode": modes.get(path)})
	## The gate's own integrity is settled before any of its contents are trusted, so a tampered
	## working gate never masquerades as a path or class drift.
	var committed_gate: Dictionary = _GIT.blob_bytes_at_commit(repository_root, head,
		EVIDENCE_ROOT_RELATIVE + "/gate.json")
	if not committed_gate.get("ok", false):
		return _fail(&"gate_hash_mismatch", "the gate is absent from the evidence commit", {})
	var committed_digest: String = _GIT.digest_bytes((committed_gate["value"] as Dictionary)["bytes"])
	if committed_digest != _GIT.digest_bytes(gate_text.to_utf8_buffer()):
		return _fail(&"gate_hash_mismatch",
			"the working gate differs from the committed gate blob", {})

	## Only now that the gate matches its committed blob may its own fields be trusted.
	var attested: String = str(gate.get("subject_commit", ""))
	if not _GIT.is_commit_id(attested) or parents[0] != attested:
		return _fail(&"evidence_commit_parent_mismatch",
			"the evidence commit's sole parent is not the attested tooling subject",
			{"parent": parents[0], "attested": attested})

	changed.sort()
	var generated: Array = []
	for path: Variant in (gate.get("generated_paths", []) as Array):
		generated.append(str(path))
	if changed != generated:
		return _fail(&"generated_paths_mismatch",
			"the evidence commit path set differs from the frozen generated inventory",
			{"changed": changed.size(), "generated": generated.size()})

	var mapping_result: Dictionary = _validate_requirement_mapping(gate, declared, absolute_root)
	if not mapping_result.get("ok", false):
		return mapping_result
	var mapping: Dictionary = mapping_result["value"]

	var preclose_path: String = absolute_root.path_join("preclose_beads_snapshot.json")
	var preclose_text: String = _read_text(preclose_path)
	if preclose_text.is_empty():
		return _fail(&"preclose_snapshot_hash_mismatch", "the committed preclose snapshot is absent", {})
	var preclose_digest: String = _GIT.digest_bytes(preclose_text.to_utf8_buffer())

	var drift: Dictionary = _compare_snapshots(mode_name, preclose_text, snapshot_text)
	if not drift.get("ok", false):
		return drift

	if preclose_digest != str(gate.get("preclose_beads_snapshot_sha256", "")):
		return _fail(&"preclose_snapshot_hash_mismatch",
			"the gate records another preclose snapshot hash", {})

	var expected_classes: Dictionary = _non_contract_children()
	if gate.get("non_contract_children", null) != expected_classes:
		return _fail(&"gate_non_contract_children_mismatch",
			"the gate carries a merged, summed, reordered or miscounted class record", {})

	var receipt_text: String = _read_text(absolute_root.path_join("validation_receipt.json"))
	if receipt_text.is_empty():
		return _fail(&"validation_receipt_hash_mismatch",
			"the committed validation receipt is absent", {})
	var committed_receipt: Dictionary = _GIT.blob_bytes_at_commit(repository_root, head,
		EVIDENCE_ROOT_RELATIVE + "/validation_receipt.json")
	if not committed_receipt.get("ok", false):
		return _fail(&"validation_receipt_hash_mismatch",
			"the validation receipt is absent from the evidence commit", {})
	var receipt_digest: String = _GIT.digest_bytes((committed_receipt["value"] as Dictionary)["bytes"])
	if receipt_digest != _GIT.digest_bytes(receipt_text.to_utf8_buffer()):
		return _fail(&"validation_receipt_hash_mismatch",
			"the working validation receipt differs from the committed blob", {})
	var receipt_parsed: Dictionary = _STRICT_JSON.parse_object(receipt_text)
	if not receipt_parsed.get("ok", false) \
			or str((receipt_parsed["value"] as Dictionary).get("subject_commit", "")) != attested:
		return _fail(&"validation_receipt_subject_mismatch",
			"the validation receipt names another tooling subject", {})
	var binding: Dictionary = {
		"subject_commit": attested,
		"gate_sha256": committed_digest,
		"validation_receipt_sha256": receipt_digest,
		"evidence_commit": head,
	}

	var attachment: Dictionary = _closeout_attachment_lines(closeout)
	var lines: Array = attachment["lines"]
	if mode_name == MODE_SEALED_PRE_ATTACH:
		if not lines.is_empty():
			return _fail(&"closeout_attachment_present",
				"SEALED_PRE_ATTACH requires no attachment", {})
	else:
		if lines.is_empty():
			return _fail(&"closeout_attachment_missing", "the canonical attachment is absent", {})
		if lines.size() > 1:
			return _fail(&"closeout_attachment_duplicate",
				"the closeout issue carries more than one attachment", {})
		var expected_line: String = NOTE_PREFIX + _canonical({
			"schema_version": 1,
			"subject_commit": attested,
			"evidence_commit": head,
			"gate_sha256": committed_digest,
			"validation_receipt_sha256": str(binding["validation_receipt_sha256"]),
		})
		if str(lines[0]) != expected_line:
			return _fail(&"closeout_attachment_mismatch",
				"the attachment is not the exact canonical binding line", {})
		var preclose_notes: String = str((_index_snapshot(preclose_text).get(CLOSEOUT_ISSUE_ID,
			{}) as Dictionary).get("notes", ""))
		var appended_notes: String = expected_line if preclose_notes.is_empty() \
			else preclose_notes + "\n" + expected_line
		if str(closeout.get("notes", "")) != appended_notes:
			return _fail(&"closeout_attachment_not_appended",
				"the attachment replaced rather than appended the existing notes", {})

	if mode_name == MODE_POST_CLOSE:
		var expected_reason: String = "phase2r_closeout_v1 subject=%s evidence=%s gate=%s receipt=%s" % [
			attested, head, committed_digest, str(binding["validation_receipt_sha256"])]
		if str(closeout.get("close_reason", "")) != expected_reason:
			return _fail(&"close_reason_mismatch", "the closeout issue carries another close reason",
				{"actual": closeout.get("close_reason")})
		for record: Variant in contracts:
			if (record as Dictionary)["evidence_verdict"] == VERDICT_PENDING:
				(record as Dictionary)["evidence_verdict"] = VERDICT_SATISFIED

	return _ok(_envelope(mode_name, contracts, mapping, binding))


## Compares the committed preclose baseline with the fresh snapshot. Sealed mode permits no delta at
## all; attached mode permits only the note append plus updated_at on the closeout issue; postclose
## additionally permits the exact close transition.
static func _compare_snapshots(mode_name: String, preclose_text: String, fresh_text: String) -> Dictionary:
	if mode_name == MODE_SEALED_PRE_ATTACH:
		if preclose_text != fresh_text:
			return _fail(&"preclose_snapshot_drift",
				"the fresh snapshot is not byte-equal to the committed preclose baseline", {})
		return _ok({})
	var preclose: Dictionary = _index_snapshot(preclose_text)
	var fresh: Dictionary = _index_snapshot(fresh_text)
	if preclose.is_empty() or fresh.is_empty():
		return _fail(&"preclose_snapshot_drift", "a snapshot could not be indexed", {})
	if (preclose.keys() as Array).size() != (fresh.keys() as Array).size():
		return _fail(&"preclose_snapshot_drift", "the snapshot gained or lost an issue", {})
	var permitted: Array[String] = ["notes", "updated_at"]
	if mode_name == MODE_POST_CLOSE:
		permitted = ["notes", "updated_at", "status", "closed_at", "close_reason"]
	for issue_id: Variant in preclose:
		if not fresh.has(issue_id):
			return _fail(&"preclose_snapshot_drift", "an issue vanished from the fresh snapshot",
				{"issue_id": issue_id})
		var before: Dictionary = preclose[issue_id]
		var after: Dictionary = fresh[issue_id]
		var keys: Dictionary = {}
		for key: Variant in before:
			keys[key] = true
		for key: Variant in after:
			keys[key] = true
		for key: Variant in keys:
			if before.get(key, null) == after.get(key, null):
				continue
			if str(issue_id) != CLOSEOUT_ISSUE_ID or not permitted.has(str(key)):
				return _fail(&"preclose_snapshot_drift", "an unauthorised snapshot delta was found",
					{"issue_id": issue_id, "field": key})
	if mode_name == MODE_POST_CLOSE:
		var closed: Dictionary = fresh[CLOSEOUT_ISSUE_ID]
		if str(closed.get("status", "")) != "closed" or str(closed.get("closed_at", "")).is_empty():
			return _fail(&"preclose_snapshot_drift",
				"the closeout transition is missing its status or closed_at", {})
	return _ok({})


static func _index_snapshot(text: String) -> Dictionary:
	var parsed: Dictionary = _STRICT_JSON._parse_value_document(text)
	if not parsed.get("ok", false) or typeof(parsed.get("value")) != TYPE_ARRAY:
		return {}
	var indexed: Dictionary = {}
	for entry: Variant in (parsed["value"] as Array):
		if typeof(entry) == TYPE_DICTIONARY:
			indexed[str((entry as Dictionary).get("id", ""))] = entry
	return indexed


static func _head_touches_evidence_root(repository_root: String) -> bool:
	var diff: Dictionary = _GIT.git_run(repository_root,
		PackedStringArray(["diff-tree", "-r", "--no-commit-id", "--name-only", "HEAD"]))
	if not diff.get("ok", false):
		return false
	for raw_line: String in str(diff["output"]).split("\n"):
		if raw_line.trim_suffix("\r").strip_edges().begins_with(EVIDENCE_ROOT_RELATIVE + "/"):
			return true
	return false


static func _closeout_attachment_lines(closeout: Dictionary) -> Dictionary:
	var lines: Array = []
	for raw_line: String in str(closeout.get("notes", "")).split("\n"):
		var line: String = raw_line.trim_suffix("\r")
		if line.begins_with(NOTE_PREFIX):
			lines.append(line)
	return {"lines": lines}


# =============================================================================================
# Export equivalence.
# =============================================================================================

static func validate_export_equivalence(list_snapshot_path: Variant, export_jsonl_path: Variant) -> Dictionary:
	if typeof(list_snapshot_path) != TYPE_STRING or typeof(export_jsonl_path) != TYPE_STRING:
		return _fail(&"export_jsonl_malformed", "both export inputs must be path Strings", {})
	var list_text: String = _read_text(list_snapshot_path)
	var list_parsed: Dictionary = _STRICT_JSON._parse_value_document(list_text)
	if not list_parsed.get("ok", false) or typeof(list_parsed.get("value")) != TYPE_ARRAY:
		return _fail(&"export_jsonl_malformed", "the list snapshot is not one strict JSON array", {})
	var export_text: String = _read_text(export_jsonl_path)
	if export_text.is_empty() or not export_text.ends_with("\n"):
		return _fail(&"export_jsonl_malformed", "the export is not LF terminated", {})

	var exported: Dictionary = {}
	for raw_line: String in export_text.trim_suffix("\n").split("\n"):
		if raw_line.is_empty():
			return _fail(&"export_jsonl_malformed", "the export carries a blank line", {})
		var parsed: Dictionary = _STRICT_JSON.parse_object(raw_line)
		if not parsed.get("ok", false):
			return _fail(&"export_jsonl_malformed", "an export line is not one strict JSON object", {})
		var record: Dictionary = parsed["value"]
		if str(record.get("_type", "")) != "issue":
			return _fail(&"export_type_invalid", "an export record is not typed as an issue",
				{"id": record.get("id")})
		exported[str(record.get("id", ""))] = record

	var complete: Dictionary = _projection_complete(list_parsed["value"] as Array)
	if not complete.get("ok", false):
		return complete

	for entry: Variant in (list_parsed["value"] as Array):
		var listed: Dictionary = entry
		var issue_id: String = str(listed.get("id", ""))
		var parent: String = str(listed.get("parent", ""))
		var derived: String = ""
		var parent_edges: int = 0
		for dependency: Variant in (listed.get("dependencies", []) as Array):
			var edge: Dictionary = dependency
			if str(edge.get("type", "")) == "parent-child" and str(edge.get("issue_id", "")) == issue_id:
				derived = str(edge.get("depends_on_id", ""))
				parent_edges += 1
		if parent.is_empty():
			if parent_edges != 0:
				return _fail(&"export_parent_inconsistent",
					"a root or external record carries a parent-child dependency", {"id": issue_id})
		elif parent_edges != 1 or derived != parent:
			return _fail(&"export_parent_inconsistent",
				"a child record's parent does not equal its sole parent-child dependency",
				{"id": issue_id, "parent": parent, "derived": derived})
		if not exported.has(issue_id):
			return _fail(&"export_record_missing", "a list record is absent from the export",
				{"id": issue_id})
		var projected: Dictionary = listed.duplicate(true)
		projected.erase("parent")
		var candidate: Dictionary = (exported[issue_id] as Dictionary).duplicate(true)
		candidate.erase("_type")
		if _canonical(projected) != _canonical(candidate):
			return _fail(&"export_record_mismatch", "an export record is not byte-equivalent",
				{"id": issue_id})
	if exported.size() != (list_parsed["value"] as Array).size():
		return _fail(&"export_record_missing", "the export and list record counts differ", {})
	return _ok({"records": exported.size()})


# =============================================================================================
# Final epic transition.
# =============================================================================================

static func validate_final_epic_transition(postclose_export_path: Variant, final_export_path: Variant,
		attachment_path: Variant) -> Dictionary:
	if typeof(postclose_export_path) != TYPE_STRING or typeof(final_export_path) != TYPE_STRING \
			or typeof(attachment_path) != TYPE_STRING:
		return _fail(&"epic_attachment_mismatch", "every transition input must be a path String", {})
	var attachment_text: String = _read_text(attachment_path)
	if attachment_text.is_empty() or not attachment_text.ends_with("\n"):
		return _fail(&"epic_attachment_mismatch", "the attachment file is not LF terminated", {})
	var attachment_line: String = attachment_text.trim_suffix("\n")
	var attachment_parsed: Dictionary = _STRICT_JSON.parse_object(attachment_line)
	if not attachment_parsed.get("ok", false):
		return _fail(&"epic_attachment_mismatch", "the attachment is not one canonical JSON object", {})
	var attachment: Dictionary = attachment_parsed["value"]
	if attachment_line != _canonical(attachment):
		return _fail(&"epic_attachment_mismatch", "the attachment bytes are not canonical", {})

	var postclose: Dictionary = _jsonl_records(postclose_export_path)
	if postclose.is_empty():
		return _fail(&"epic_attachment_mismatch", "the postclose export could not be parsed", {})
	var final_records: Dictionary = _jsonl_records(final_export_path)
	if final_records.is_empty():
		return _fail(&"epic_attachment_mismatch", "the final export could not be parsed", {})

	var attachment_keys: Array = attachment.keys()
	attachment_keys.sort()
	var expected_keys: Array = EPIC_ATTACHMENT_KEYS.duplicate()
	expected_keys.sort()
	if attachment_keys != expected_keys:
		return _fail(&"epic_attachment_mismatch",
			"the attachment key set is not the exact nine declared keys", {"keys": attachment_keys})
	for path_key: String in EPIC_ATTACHMENT_PATHS:
		if str(attachment.get(path_key, "")) != str(EPIC_ATTACHMENT_PATHS[path_key]):
			return _fail(&"epic_attachment_mismatch",
				"the attachment names another tracked transition path", {"key": path_key})
	for digest_key: String in ["postclose_inventory_sha256", "postclose_export_sha256",
			"postclose_validation_log_sha256"]:
		if not _GIT.is_sha256(str(attachment.get(digest_key, ""))):
			return _fail(&"epic_attachment_mismatch",
				"an attachment digest is not a SHA-256", {"key": digest_key})
	if int(attachment.get("schema_version", 0)) != 1:
		return _fail(&"epic_attachment_mismatch", "the attachment schema version is not 1", {})

	var postclose_text: String = _read_text(postclose_export_path)
	if int(attachment.get("contract_count", 0)) != CONTRACT_COUNT \
			or str(attachment.get("verdict", "")) != EPIC_VERDICT \
			or str(attachment.get("postclose_export_sha256", "")) \
				!= _GIT.digest_bytes(postclose_text.to_utf8_buffer()):
		return _fail(&"epic_attachment_mismatch",
			"the attachment does not bind the tracked postclose baseline", {})

	if postclose.size() != final_records.size():
		return _fail(&"epic_transition_extra_delta", "the final export gained or lost an issue", {})
	for issue_id: Variant in postclose:
		if not final_records.has(issue_id):
			return _fail(&"epic_transition_extra_delta", "an issue vanished from the final export",
				{"id": issue_id})
		if str(issue_id) == EPIC_ID:
			continue
		if _canonical(postclose[issue_id]) != _canonical(final_records[issue_id]):
			return _fail(&"epic_transition_extra_delta", "a non-epic issue changed", {"id": issue_id})

	var before: Dictionary = postclose[EPIC_ID]
	var after: Dictionary = final_records[EPIC_ID]
	if str(before.get("status", "")) != "open" or str(after.get("status", "")) != "closed" \
			or str(after.get("closed_at", "")).is_empty():
		return _fail(&"epic_transition_status_invalid",
			"the epic did not make the exact open to closed transition", {})

	var appended: Array = []
	for raw_line: String in str(after.get("notes", "")).split("\n"):
		var line: String = raw_line.trim_suffix("\r")
		if line.begins_with(EPIC_NOTE_PREFIX):
			appended.append(line)
	if appended.size() > 1:
		return _fail(&"epic_attachment_duplicate", "the epic carries more than one closeout note", {})
	if appended.size() != 1 or str(appended[0]) != EPIC_NOTE_PREFIX + attachment_line:
		return _fail(&"epic_attachment_mismatch",
			"the epic note is not the exact canonical attachment line", {})

	var expected_reason: String = "phase2r_epic_closeout_v1 postclose_export=%s postclose_log=%s contracts=16" % [
		str(attachment.get("postclose_export_sha256", "")),
		str(attachment.get("postclose_validation_log_sha256", ""))]
	if str(after.get("close_reason", "")) != expected_reason:
		return _fail(&"epic_close_reason_mismatch", "the epic carries another close reason",
			{"actual": after.get("close_reason")})

	var permitted: Array[String] = ["notes", "status", "updated_at", "closed_at", "close_reason"]
	var keys: Dictionary = {}
	for key: Variant in before:
		keys[key] = true
	for key: Variant in after:
		keys[key] = true
	for key: Variant in keys:
		if before.get(key, null) == after.get(key, null):
			continue
		if not permitted.has(str(key)):
			return _fail(&"epic_transition_extra_delta", "an unauthorised epic field changed",
				{"field": key})
	return _ok({"epic_id": EPIC_ID, "verdict": EPIC_VERDICT, "contract_count": CONTRACT_COUNT})


## The seam receives no metadata, so completeness is derived structurally: the epic, every member
## of both named classes, the external contract record, and exactly sixteen contract records must
## all be present. Two mutually consistent but truncated files must not validate.
static func _projection_complete(records: Array) -> Dictionary:
	var listed: Dictionary = {}
	for entry: Variant in records:
		if typeof(entry) == TYPE_DICTIONARY:
			listed[str((entry as Dictionary).get("id", ""))] = entry
	if not listed.has(EPIC_ID):
		return _fail(&"export_projection_incomplete", "the epic is absent from the projection", {})
	var class_members: Array = HISTORICAL_HELPER_IDS + EXECUTION_REMEDIATION_IDS
	for member: String in class_members:
		if not listed.has(member):
			return _fail(&"export_projection_incomplete",
				"a named non-contract child is absent from the projection", {"issue_id": member})
	if not listed.has(EXTERNAL_CONTRACT_ID):
		return _fail(&"export_projection_incomplete",
			"the external contract record is absent from the projection", {})
	var contracts: int = 1
	for issue_id: Variant in listed:
		if str((listed[issue_id] as Dictionary).get("parent", "")) != EPIC_ID:
			continue
		if not class_members.has(str(issue_id)):
			contracts += 1
	## Residual limit: this seam receives no metadata, so it counts contract records rather than
	## naming them. Dropping one real contract while adding one unadmitted direct child still
	## totals sixteen here; validate()'s own topology check names them exactly.
	if contracts != CONTRACT_COUNT:
		return _fail(&"export_projection_incomplete",
			"the projection does not carry exactly sixteen contract records",
			{"contracts": contracts})
	return _ok({})


static func _jsonl_records(path: Variant) -> Dictionary:
	var text: String = _read_text(path)
	if text.is_empty() or not text.ends_with("\n"):
		return {}
	var records: Dictionary = {}
	for raw_line: String in text.trim_suffix("\n").split("\n"):
		var parsed: Dictionary = _STRICT_JSON.parse_object(raw_line)
		if not parsed.get("ok", false):
			return {}
		records[str((parsed["value"] as Dictionary).get("id", ""))] = parsed["value"]
	return records


# =============================================================================================
# Envelope and primitives.
# =============================================================================================

static func _envelope(mode_name: String, contracts: Array, mapping: Dictionary,
		binding: Variant) -> Dictionary:
	return {
		"mode": mode_name,
		"epic_id": EPIC_ID,
		"closeout_issue_id": CLOSEOUT_ISSUE_ID,
		"child_contracts": contracts,
		"non_contract_children": _non_contract_children(),
		"requirement_evidence": mapping,
		"deferred_requirements": DEFERRED_REQUIREMENTS.duplicate(true),
		"closeout_evidence": binding,
	}


## Both classes are reported separately and never merged, summed, reordered or folded into
## child_contracts. Each ids Array is declaration order, deliberately not sorted.
static func _non_contract_children() -> Dictionary:
	return {
		"historical_helpers": {"count": HISTORICAL_HELPER_IDS.size(),
			"ids": HISTORICAL_HELPER_IDS.duplicate()},
		"execution_remediation_children": {"count": EXECUTION_REMEDIATION_IDS.size(),
			"ids": EXECUTION_REMEDIATION_IDS.duplicate()},
	}


static func _resolve_repository_root(evidence_root: String) -> String:
	var cursor: String = _globalize(evidence_root)
	for _depth: int in range(24):
		if FileAccess.file_exists(cursor.path_join(".git")) \
				or DirAccess.dir_exists_absolute(cursor.path_join(".git")):
			return cursor
		var parent: String = cursor.get_base_dir()
		if parent == cursor or parent.is_empty():
			break
		cursor = parent
	return ""


static func _globalize(path: String) -> String:
	var resolved: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	return resolved.trim_suffix("/").trim_suffix("\\")


static func _read_text(path: Variant) -> String:
	var resolved: String = str(path)
	if not FileAccess.file_exists(resolved):
		return ""
	return FileAccess.get_file_as_string(resolved)


static func _read_object(path: Variant) -> Dictionary:
	var text: String = _read_text(path)
	if text.is_empty():
		return {"ok": false}
	return _STRICT_JSON.parse_object(text)


static func _parse_requirement_index(text: String) -> Dictionary:
	var indexed: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if not line.begins_with("| `req."):
			continue
		var closing: int = line.find("`", 3)
		if closing > 3:
			indexed[line.substr(3, closing - 3)] = true
	return indexed


## Returns a strictly distinct sentinel on every failure, so two uncanonicalisable values can
## never compare equal and reopen a fail-open hole in an equality gate.
static var _uncanonicalisable_count: int = 0

static func _canonical(value: Variant) -> String:
	var written: Dictionary = _CANONICAL_JSON.stringify(value)
	if written.get("ok", false):
		return str(written.get("value", ""))
	_uncanonicalisable_count += 1
	return "\u0000uncanonicalisable:%d" % _uncanonicalisable_count


static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}
