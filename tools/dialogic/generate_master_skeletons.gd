extends SceneTree
## Generates the eight plot-neutral master timelines from the closed entry manifest
## (Seven-Day Flow Plan 01 Task 3, sub-commit 3A, dwm-oyo.2).
##
## Run: tools/testing/Invoke-IsolatedGodot.ps1 -GodotArgs @('-s',
##      'res://tools/dialogic/generate_master_skeletons.gd')
##
## THE MANIFEST IS THE ONLY INPUT. data/manifests/dialogic_entries.json owns every entry id, its
## owning master, its role and its allowed signal array. This generator invents nothing: it does
## not read the specification, does not parse an entry id to guess a role, and does not sort,
## dedupe or reorder anything. Regenerating over an unchanged manifest is a byte-identical no-op,
## which is the property that makes the masters safe to overwrite rather than hand-edit.
##
## IT VALIDATES ITS OWN OUTPUT BEFORE WRITING IT. Every master is built in memory, run through
## DtlStructureValidator, and only written if it validates clean. A generator that emits bytes its
## own validator rejects is a defect that must never reach disk, and this is the cheapest place to
## catch it.
##
## THE SIGNAL ANNOTATION IS JOINED HERE INDEPENDENTLY OF THE VALIDATOR, deliberately. The
## validator recomputes the same annotation from the same manifest array and compares. Two
## independent implementations of one rule mean a defect in either is caught by the other; sharing
## one helper would make both halves agree while both were wrong.
##
## PLOT NEUTRALITY IS STRUCTURAL, NOT A PROMISE. The only free text this generator can emit is an
## entry id and a registered role, both of which are schema vocabulary. There is no code path here
## that can emit dialogue, a character, a portrait or a resource path, because no such value is
## read from anywhere.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const VALIDATOR := preload("res://tools/dialogic/DtlStructureValidator.gd")

const EXPECTED_MASTER_COUNT := 8
const EXPECTED_ENTRY_COUNT := 139


func _init() -> void:
	quit(_run())


func _run() -> int:
	var loaded: Dictionary = MANIFEST.load_default()
	if not loaded.get("ok", false):
		return _fail("load manifest", loaded)

	var document: Dictionary = loaded["value"]
	var validated: Dictionary = MANIFEST.validate_document(document)
	if not validated.get("ok", false):
		return _fail("validate manifest", validated)

	var partition: Dictionary = VALIDATOR.partition_by_master(document)
	if partition.size() != EXPECTED_MASTER_COUNT:
		print("GENERATE_MASTERS: FAIL expected %d masters, manifest declares %d" %
			[EXPECTED_MASTER_COUNT, partition.size()])
		return 1

	var total := 0
	for path: Variant in partition:
		total += (partition[path] as Array).size()
	if total != EXPECTED_ENTRY_COUNT:
		print("GENERATE_MASTERS: FAIL expected %d entries, partitioned %d" %
			[EXPECTED_ENTRY_COUNT, total])
		return 1

	var written := 0
	for path: Variant in partition:
		var master_path := str(path)
		var records: Array = partition[path]
		var text := _build(records)

		var check: Dictionary = VALIDATOR.validate_text(master_path, text, records)
		if not check.get("ok", false):
			print("GENERATE_MASTERS: FAIL %s did not validate before writing" % master_path)
			for failure: Variant in (check["failures"] as Array).slice(0, 10):
				var entry: Dictionary = failure
				print("  %s line %d: %s" % [str(entry["code"]), int(entry["line"]), str(entry["message"])])
			return 1

		var handle := FileAccess.open(master_path, FileAccess.WRITE)
		if handle == null:
			print("GENERATE_MASTERS: FAIL cannot open %s for writing (%d)" %
				[master_path, FileAccess.get_open_error()])
			return 1
		handle.store_string(text)
		handle.close()
		written += 1
		print("GENERATE_MASTERS: wrote %s (%d labels)" % [master_path, records.size()])

	print("GENERATE_MASTERS: OK %d masters / %d entries" % [written, total])
	return 0


## Builds one master's exact text. The shape is the plan's Task 3 format example, with no
## `# timeline_id:` or `# locale:` header: the new contract identifies an entry through the
## manifest, and under Ruling O the legacy header-parsing builder never sees these files.
static func _build(records: Array) -> String:
	var lines: PackedStringArray = []
	lines.append(VALIDATOR.HEADER_COMMENT)
	lines.append(VALIDATOR.TERMINATOR)
	for candidate: Variant in records:
		var record: Dictionary = candidate
		lines.append("")
		lines.append(VALIDATOR.LABEL_PREFIX + str(record["label"]))
		lines.append(VALIDATOR.PURPOSE_PREFIX + str(record["role"]))
		lines.append(VALIDATOR.CAUSAL_LINE)
		lines.append(VALIDATOR.VARIATION_LINE)
		lines.append(VALIDATOR.SIGNALS_PREFIX + _annotate(record["allowed_signals"]))
		lines.append(VALIDATOR.TERMINATOR)
	return "\n".join(lines) + "\n"


## Joins a registered signal array in its STORED order. Independent of the validator's own join
## by design; see the header.
static func _annotate(allowed: Variant) -> String:
	var parts: PackedStringArray = []
	if allowed is Array:
		for signal_id: Variant in (allowed as Array):
			parts.append(str(signal_id))
	return ", ".join(parts)


func _fail(stage: String, result: Dictionary) -> int:
	print("GENERATE_MASTERS: FAIL %s -> %s %s" %
		[stage, str(result.get("code", "")), str(result.get("message", ""))])
	return 1
