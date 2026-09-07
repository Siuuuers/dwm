extends SceneTree
## Validates the shipped Dialogic contract: the closed entry manifest and the eight masters it
## owns (Seven-Day Flow Plan 01 Task 3, sub-commit 3A, dwm-oyo.2).
##
## Run: tools/testing/Invoke-IsolatedGodot.ps1 -GodotArgs @('-s',
##      'res://tools/dialogic/validate_dialogic_contract.gd')
##
## WHY THIS IS NOT tools/dialogic/validate_manifests.gd, WHICH THE PLAN NAMES (dwm-oyo.2
## DEVIATION-7 Ruling N). That path is already taken by a dwm-p2r.8 Plan-05 GENERATOR which scans
## every .dtl under en/ and REWRITES timelines.json, endings.json, effects.json, routes.json and
## narrative_variables.json plus two evidence files. Running it is a mutation, not a check, and
## running it after Task 3 would take timelines.json from 61 records to 69, break
## WriteDialogicGateSummary's 59/24/35 production floor inside the FROZEN tooling gate, and stale
## the sealed manifest_hashes in evidence/phase_2r/dialogic/gate_summary.json. It also exits 1 on
## the masters regardless, because its parser demands a `# timeline_id:` header the masters do not
## carry. So this task's CLI lands under a new name and the legacy generator stays byte-untouched.
## This is the third instance of one pattern already ruled on twice, after DEVIATION-3 Ruling 1 and
## DEVIATION-4 Ruling F.
##
## WHAT IT PROVES, in order, stopping at the first stage that fails because every later stage
## depends on it:
##
##   1. the entry manifest loads and validates against its published schema;
##   2. it partitions into EXACTLY eight masters holding EXACTLY 139 entries;
##   3. every registered master path is a res:// path under the masters directory;
##   4. every master validates structurally, with every failure reported, not just the first.
##
## DIAGNOSTICS ARE BOUNDED. A structural defect in a generated file usually repeats on every one
## of its entries, so an unbounded dump buries the one line that matters under hundreds of
## identical ones. Each master prints at most MAX_REPORTED failures and then says how many more it
## withheld, and the exit code is unaffected by the bound.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const VALIDATOR := preload("res://tools/dialogic/DtlStructureValidator.gd")

const MASTER_DIR := "res://dialogic/timelines/en/"
const EXPECTED_MASTER_COUNT := 8
const EXPECTED_ENTRY_COUNT := 137
const MAX_REPORTED := 10


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
		print("DIALOGIC_CONTRACT: FAIL expected %d masters, manifest declares %d" %
			[EXPECTED_MASTER_COUNT, partition.size()])
		return 1

	var total := 0
	for path: Variant in partition:
		total += (partition[path] as Array).size()
	if total != EXPECTED_ENTRY_COUNT:
		print("DIALOGIC_CONTRACT: FAIL expected %d entries, partitioned %d" %
			[EXPECTED_ENTRY_COUNT, total])
		return 1

	var failed := 0
	for path: Variant in partition:
		var master_path := str(path)
		if not master_path.begins_with(MASTER_DIR):
			print("DIALOGIC_CONTRACT: FAIL %s is not a master path under %s" %
				[master_path, MASTER_DIR])
			failed += 1
			continue

		var records: Array = partition[path]
		var result: Dictionary = VALIDATOR.validate_file(master_path, records)
		if result.get("ok", false):
			print("DIALOGIC_CONTRACT: OK %s (%d labels)" % [master_path, records.size()])
			continue

		failed += 1
		var failures: Array = result["failures"]
		print("DIALOGIC_CONTRACT: FAIL %s (%d failures)" % [master_path, failures.size()])
		for failure: Variant in failures.slice(0, MAX_REPORTED):
			var entry: Dictionary = failure
			print("  %s line %d: %s" %
				[str(entry["code"]), int(entry["line"]), str(entry["message"])])
		if failures.size() > MAX_REPORTED:
			print("  ... %d further failures withheld" % (failures.size() - MAX_REPORTED))

	if failed > 0:
		print("DIALOGIC_CONTRACT: FAIL %d of %d masters" % [failed, partition.size()])
		return 1

	print("DIALOGIC_CONTRACT: PASS masters=%d entries=%d" % [partition.size(), total])
	return 0


func _fail(stage: String, result: Dictionary) -> int:
	print("DIALOGIC_CONTRACT: FAIL %s -> %s %s" %
		[stage, str(result.get("code", "")), str(result.get("message", ""))])
	return 1
