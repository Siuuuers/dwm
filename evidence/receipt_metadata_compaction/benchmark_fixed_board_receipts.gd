extends SceneTree
## Fixed component microbenchmark. It reads one validated save, restores one board component,
## accepts an existing public shell command, and never writes a save or fixture.

const SOURCE := "res://evidence/localized_json_encoding/baseline-zh-CN-autosave.json"
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SAVE_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SAMPLE_COUNT := 5
const TX_ID := "benchmark.receipt_metadata_compaction.v1"
const BOARD_KEYS := ["board", "candidate", "command_receipts", "identity", "phase",
	"revision", "schema_version", "settlement", "terminal_receipts"]
const FULL_RECEIPT_KEYS := ["command_kind", "identity_fingerprint", "post_revision",
	"pre_revision", "request_fingerprint", "result"]
const ERASED_METADATA := ["command_kind", "identity_fingerprint", "pre_revision", "post_revision"]

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition: _failures.append(message)
	return condition

func _keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys

func _canonical(value: Variant, label: String) -> String:
	var emitted: Dictionary = CANONICAL.stringify(value)
	if not _check(emitted.get("ok", false), label + " canonical emission failed"):
		return ""
	return str(emitted["value"])

func _bytes(value: Variant, label: String) -> int:
	return _canonical(value, label).to_utf8_buffer().size()

func _mode() -> String:
	var value := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expected-metadata="):
			value = argument.trim_prefix("--expected-metadata=")
	_check(value in ["full", "compact"],
		"exactly --expected-metadata=full or --expected-metadata=compact is required")
	return value

func _ack(post_revision: int) -> Dictionary:
	return {"ok": true, "code": &"board_command_already_applied",
		"value": {"already_applied": true, "revision": post_revision}, "receipt": {}}

func _is_ack(result: Variant) -> bool:
	return result is Dictionary and str(result.get("code", "")) == "board_command_already_applied"

func _expected_existing(before: Dictionary, mode: String) -> Dictionary:
	var expected := before.duplicate(true)
	var changed_results := 0
	var minimal_receipts := 0
	for receipt_id: String in expected:
		var entry: Variant = expected[receipt_id]
		if not entry is Dictionary or _keys(entry) != Array(FULL_RECEIPT_KEYS): continue
		if str(entry.get("command_kind", "")) not in ["board_command", "visibility"]: continue
		if not entry.get("result") is Dictionary or not entry.get("post_revision") is int: continue
		if not _is_ack(entry["result"]):
			entry["result"] = _ack(int(entry["post_revision"]))
			changed_results += 1
		if mode == "compact":
			for field: String in ERASED_METADATA: entry.erase(field)
			minimal_receipts += 1
	return {"receipts": expected, "changed_results": changed_results,
		"minimal_receipts": minimal_receipts}

func _ledger_metrics(board: Dictionary, label: String) -> Dictionary:
	var commands: Dictionary = board["command_receipts"]
	var terminal: Dictionary = board["terminal_receipts"]
	var full_results := 0
	var full_metadata_ack_results := 0
	var minimal_receipts := 0
	for entry: Variant in commands.values():
		if not entry is Dictionary: continue
		if _keys(entry) == ["request_fingerprint", "result"] and _is_ack(entry.get("result")):
			minimal_receipts += 1
		elif str(entry.get("command_kind", "")) in ["board_command", "visibility"]:
			if _is_ack(entry.get("result")): full_metadata_ack_results += 1
			else: full_results += 1
	return {"command_entries": commands.size(), "terminal_entries": terminal.size(),
		"canonical_bytes": _bytes({"command_receipts": commands,
			"terminal_receipts": terminal}, label), "full_results": full_results,
		"full_metadata_ack_results": full_metadata_ack_results,
		"minimal_receipts": minimal_receipts}

func _request(revision: int) -> Dictionary:
	var semantic := {"kind": "configure_unpaid_shell", "difficulty_id": "beginner",
		"shell": {"flagged_indices": [], "actions": []}}
	return {"transaction_id": TX_ID,
		"request_fingerprint": _canonical(semantic, "request").sha256_text(),
		"expected_revision": revision, "identity": null}

func _sample(original: Dictionary, mode: String, before_metrics: Dictionary,
		index: int) -> Dictionary:
	var state := BOARD_STATE.new()
	var restore: Dictionary = state.prepare_restore(original.duplicate(true))
	if not _check(restore.get("ok", false), "sample %d restore prepares" % index): return {}
	if not _check(state.commit(restore["value"]["candidate"]).get("ok", false),
			"sample %d restore commits" % index): return {}
	_check(state.capture() == original, "sample %d restores exact input" % index)
	var request := _request(int(original["revision"]))
	var start := Time.get_ticks_usec()
	var prepared: Dictionary = state.prepare_unpaid_shell(request, "beginner",
		{"flagged_indices": [], "actions": []})
	var prepare_usec := Time.get_ticks_usec() - start
	if not _check(prepared.get("ok", false), "sample %d shell prepares" % index): return {}
	_check(state.capture() == original, "sample %d prepare is pure" % index)
	start = Time.get_ticks_usec()
	var result: Dictionary = state.commit(prepared["value"]["candidate"])
	var commit_usec := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var after: Dictionary = state.capture()
	var capture_usec := Time.get_ticks_usec() - start
	if not _check(result.get("ok", false), "sample %d shell commits" % index): return {}

	_check(_keys(after) == Array(BOARD_KEYS), "sample %d board keyset" % index)
	_check(after["phase"] == "UNPAID_UNSTARTED" and after["revision"] == 210,
		"sample %d exact NONE 209 to UNPAID 210 transition" % index)
	_check(after["identity"] == null and after["board"] == null and after["settlement"] == null,
		"sample %d unpaid null-owned slots" % index)
	_check(after["candidate"] == {"difficulty_id": "beginner", "width": 8, "height": 8,
		"flagged_indices": [], "actions": []}, "sample %d exact beginner shell" % index)
	_check(after["terminal_receipts"] == original["terminal_receipts"],
		"sample %d terminal proofs preserved" % index)
	var commands: Dictionary = after["command_receipts"]
	var existing := commands.duplicate(true)
	var added: Variant = existing.get(TX_ID)
	existing.erase(TX_ID)
	var expected := _expected_existing(original["command_receipts"], mode)
	_check(commands.size() == 207 and existing == expected["receipts"],
		"sample %d existing receipts match exact %s representation" % [index, mode])
	_check(int(expected["changed_results"]) == int(before_metrics["full_results"])
		and int(expected["changed_results"]) > 0,
		"sample %d reaches the existing result-compaction boundary" % index)
	_check(added is Dictionary and _keys(added) == Array(FULL_RECEIPT_KEYS)
		and added["command_kind"] == "shell"
		and added["request_fingerprint"] == request["request_fingerprint"]
		and added["identity_fingerprint"] == ""
		and added["pre_revision"] == 209 and added["post_revision"] == 210
		and added["result"] == result, "sample %d exact new shell receipt" % index)
	_check(BOARD_STATE.new().prepare_restore(after).get("ok", false),
		"sample %d result remains production-restorable" % index)
	var after_metrics := _ledger_metrics(after, "after ledger")
	_check(after_metrics["minimal_receipts"] == expected["minimal_receipts"],
		"sample %d exact minimal receipt count" % index)
	return {"sample": index + 1, "prepare_usec": prepare_usec,
		"commit_usec": commit_usec, "capture_usec": capture_usec,
		"prepare_commit_capture_usec": prepare_usec + commit_usec + capture_usec,
		"board_canonical_bytes": _bytes(after, "after board"),
		"after_ledger": after_metrics}

func _range(samples: Array[Dictionary], field: String) -> Dictionary:
	var values: Array[int] = []
	for sample: Dictionary in samples: values.append(int(sample[field]))
	values.sort()
	return {"min": values[0], "median": values[int(values.size() / 2)], "max": values[-1]}

func _run() -> void:
	var mode := _mode()
	if mode.is_empty(): _finish({}); return
	var source_hash := FileAccess.get_sha256(SOURCE)
	var source_bytes := FileAccess.get_file_as_bytes(SOURCE)
	var parsed: Dictionary = STRICT.parse_object(source_bytes.get_string_from_utf8())
	if not _check(parsed.get("ok", false), "fixed source StrictJson failed"): _finish({}); return
	var validated: Dictionary = SAVE_SCHEMA.validate(parsed["value"])
	if not _check(validated.get("ok", false), "fixed source schema failed"): _finish({}); return
	var document: Dictionary = validated["value"]["candidate"]
	var board: Dictionary = document["current_snapshot"]["snapshot"]["desktop"]["board"]
	_check(_keys(board) == Array(BOARD_KEYS) and board["phase"] == "NONE"
		and board["revision"] == 209, "fixed board identity")
	_check(board["command_receipts"].size() == 206 and board["terminal_receipts"].size() == 2,
		"fixed receipt counts")
	for record: Dictionary in document["recovery_journal"]:
		_check(record["snapshot"]["desktop"]["board"] == board, "identical recovery board")
	var original := board.duplicate(true)
	var before_metrics := _ledger_metrics(original, "before ledger")
	_check(before_metrics["full_results"] == 1, "fixed ledger has one full result")
	var before_board_bytes := _bytes(original, "before board")
	var samples: Array[Dictionary] = []
	for index: int in range(SAMPLE_COUNT):
		var measured := _sample(original, mode, before_metrics, index)
		if not measured.is_empty(): samples.append(measured)
	_check(samples.size() == SAMPLE_COUNT, "five samples complete")
	_check(board == original, "parsed board remains detached")
	_check(FileAccess.get_sha256(SOURCE) == source_hash
		and FileAccess.get_file_as_bytes(SOURCE) == source_bytes, "source bytes remain exact")
	var summary := {"scope": "DesktopBoardState component microbenchmark; not autosave latency",
		"expected_metadata": mode, "source": SOURCE, "source_sha256": source_hash,
		"source_bytes": source_bytes.size(), "validated_document": true,
		"identical_board_occurrences": 3, "transition": "NONE:209 -> UNPAID_UNSTARTED:210",
		"before_board_canonical_bytes": before_board_bytes, "before_ledger": before_metrics,
		"samples": samples, "checks": _checks, "failures": _failures}
	if samples.size() == SAMPLE_COUNT:
		for field: String in ["prepare_usec", "commit_usec", "capture_usec",
				"prepare_commit_capture_usec"]: summary[field] = _range(samples, field)
		summary["after_board_canonical_bytes"] = samples[0]["board_canonical_bytes"]
		summary["after_ledger"] = samples[0]["after_ledger"]
		summary["three_component_bytes_before"] = 3 * before_board_bytes
		summary["three_component_bytes_after_estimate"] = 3 * int(samples[0]["board_canonical_bytes"])
	_finish(summary)

func _finish(summary: Dictionary) -> void:
	for failure: String in _failures: printerr(failure)
	var prefix := "RECEIPT_METADATA_COMPACTION_BENCHMARK " if _failures.is_empty() \
		else "RECEIPT_METADATA_COMPACTION_FAILED "
	print(prefix + JSON.stringify(summary))
	quit(0 if _failures.is_empty() else 1)
