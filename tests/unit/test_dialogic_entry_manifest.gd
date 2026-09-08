extends "res://addons/gut/test.gd"
## Closed semantic Dialogic entry manifest (Seven-Day Flow Plan 01 Task 2, sub-commit 2A, dwm-oyo.2).
##
## WHAT THIS SUITE BINDS. data/manifests/dialogic_entries.json holds all 137 externally callable
## entries: the 119 day entries enumerated bullet by bullet in specification sections 13.1 through
## 13.7, plus the 18 ending presentation entries the 13.8 table expands to. No identifier here was
## typed from memory. The suite re-parses the specification off disk at runtime and rebuilds the
## same ordered entry list a second, independent way, so a defect in whatever generated the
## manifest cannot vouch for itself.
##
## DECLARED PATHS, NOT FILES. The eight masters under res://dialogic/timelines/en/ do not exist
## yet; Task 3 creates them. Every locator assertion below is about the declared path STRING and
## never about a file existing, exactly as the Task 1 suite does for the same eight paths.
##
## day MEANS THE OWNING MASTER FILE. Specification 12.2 asks for "role and owning day/ending
## layer". A Day 1 carryover such as contact.invitation.solo.priscilla.day1.nevermind is authored
## in day_2.dtl and therefore records day 2; its source day is frozen CONTEXT, which the 12.3
## Consequence/follow-up row asks for separately as display day and source invitation. Under this
## reading the per-day tallies are exactly 8/24/20/13/13/24/17 and day is null on all 18 ending
## entries, which is the Phase 01 Verification Gate figure 8/24/20/13/13/24/17/18.
##
## ROLE ENUM. Fourteen closed values. Twelve are the specification 12.3 role-family rows in table
## order. DEVIATION-3 Ruling 5 adds echo.fallback.day7, which 12.3 has no row for. The last
## is Ruling 6: the three Day 7 boardless ending invitations own ending_invitation_offer, whose
## required frozen fields are identical to the Solo invitation offer row, so no new required field
## is invented, and whose ending_id stays null because 13.8 is an exact capability map that does
## not list them.
##
## context_schema_id CONVENTION, chosen here and consumed by sub-commit 2D:
## "context." + role + "." + entry_id + ".v1". It is deterministic, unique per entry because
## entry_id is unique, and carries the role so a consumer never re-parses an entry id to find its
## role family, which 12.2 forbids. Every record is re-derived under that rule below.
##
## allowed_signals IS CLOSED BY DEFAULT, AND THE RULE IS ENTRY-FAMILY BASED. Specification 12.8
## fixes five signal ids and gives each one a Valid source; the grant follows that column and the
## entry families 11.1 names. An earlier revision of this suite argued the echo grant from atom
## registration instead. That rationale was self-defeating - structural mode registers no atom for
## the six ordinary entries either, yet they are granted - and it is withdrawn.
##
##   history.line.witness      All 137. The 12.8 Valid source is a manifest-owned line in the
##                             current entry, which every entry has.
##   message.reply.commit      The six ordinary-message entries only; 12.8 names them.
##   message.echo.satisfy      Those six, the TWELVE Day 6 Priscilla, Lavinia and Priscilla-Lavinia
##                             follow-ups that day_7.dtl presents, and echo.fallback.day7. 11.1 says
##                             Day 7 first presents those follow-ups, that they may naturally
##                             satisfy echoes, and that the fallback then receives the REMAINING
##                             pending-echo list. If the follow-ups could not satisfy an echo,
##                             "remaining" could never differ from the whole pending list, so the
##                             twelve are load bearing. 13.7 carries no Sylvia carryover, which is
##                             why the family is exactly twelve.
##   pair.combination.witness  The four canonical visible P-L post-board entries only. The 12.8
##                             Valid source is such an entry after its full Perfect/Solved
##                             observation atom, and the plan registers exactly four such atoms.
##   observer.evidence.commit  NO entry. The plan states production Observer evidence capabilities
##                             remain absent or disabled until an approved content card supplies an
##                             exact source entry/atom.
##
## atom_namespace IS A DECLARED HOME, NOT A STRING PREFIX (maintainer ruling, binding on sub-commit
## 2B and restated at length in DialogicEntryManifest.gd). The plan's own mandated atom ids nest
## under neither owning entry. The law asserted here is only that the FIELD is derived from the
## entry id; nothing here entitles a later validate_atom_id to require a string prefix.
##
## THE SCHEMA/CODE SPLIT IS DELIBERATE (DEVIATION-3 Ruling 3). scripts/validation/JsonSchemaValidator
## .gd implements exactly ten keywords - type, const, enum, required, properties,
## additionalProperties, items, minItems, minLength, uniqueItems - and silently ignores everything
## else, so four of the laws Task 2 demands are NOT expressible in a manifest schema: a duplicate
## {path,label} locator pair, an absolute OS path, a non-res:// path, and a label unequal to its
## registered entry. Those four live in DialogicEntryManifest.validate_document as named codes, and
## test_the_schema_alone_catches_none_of_the_four_code_laws proves the schema does not cover them,
## so a later agent cannot delete a code law believing the schema still does. The converse also
## holds and is deliberate: locale closure and every closed vocabulary live in the schema alone,
## because the validator really does enforce enum and additionalProperties, and duplicating them in
## code would create a law no mutation could reach.
##
## ONE MUTATION SURVIVOR, CLOSED RATHER THAN LEFT STANDING. In the sub-commit 2A campaign, site
## S08 deleted minItems from the schema's entries array and all 65 tests still passed, because the
## exact record count was pinned only by this suite and by the validate_document cross-check. The
## floor is now asserted directly above, and the remedy is generalised by
## test_the_published_schema_pins_its_own_literals, which pins every other literal the schema
## declares so no second S08 can hide. Two further layerings were observed and are deliberate rather than redundant: with the
## duplicate-locator-pair law removed (site G01) the same document is still rejected, but as
## ENTRY_MANIFEST_LABEL_ENTRY_MISMATCH, and with the absolute-OS-path law removed (site G02) it is
## still rejected, but as ENTRY_MANIFEST_NON_RES_PATH. Both tests assert the exact code, so neither
## half can be deleted to make a campaign look clean.
##
## KNOWN UNTESTED PATHS IN THE PRODUCTION SOURCE, recorded rather than hidden. The backslash
## branch of _is_absolute_os_path, the per-record ENTRY_MANIFEST_DOCUMENT_SHAPE branch and
## fingerprint's empty-string return need a malformed Variant to reach; ENTRY_MANIFEST_FILE_MISSING,
## ENTRY_MANIFEST_PARSE_FAILED and ENTRY_MANIFEST_SCHEMA_MISSING need filesystem manipulation. All
## six are KNOWINGLY UNCOVERED here, and the three code names are pinned by
## test_every_declared_failure_code_exists_in_the_production_source so a rename cannot pass
## unnoticed. ENTRY_MANIFEST_ABSOLUTE_OS_PATH is a diagnostic refinement of
## ENTRY_MANIFEST_NON_RES_PATH and never fires where the latter would not: campaign site G02 removed
## it and the document was still rejected, only with the coarser code.
##
## ACCESS IDIOM. Dictionary dot access works in this project, but a missing key raises "Invalid
## access to property or key" and aborts the test body. Every accessor below uses get()/[] so that
## RED reports a clean assertion failure instead of a script error. Two parsed documents are
## compared through CanonicalJsonWriter rather than with ==, because this engine's Dictionary
## equality is not a deep comparison; CanonicalJsonWriter carries its own _deep_same for the same
## reason.

const MANIFEST_PATH := "res://data/manifests/dialogic_entries.json"
const SCHEMA_PATH := "res://schemas/manifests/dialogic-entries.schema.json"
const SCRIPT_PATH := "res://scripts/narrative/DialogicEntryManifest.gd"
const SPEC_PATH := "res://docs/design/2026-08-07-seven-day-dialogic-flow-design.md"

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

const EXPECTED_ENTRY_COUNT := 137
const EXPECTED_DAY_ENTRY_COUNT := 119
const EXPECTED_ENDING_ENTRY_COUNT := 18
const EXPECTED_ENDING_ID_COUNT := 13

## Specification 13.1 through 13.7, measured bullet by bullet, and independently named by the
## Phase 01 Verification Gate as 8/24/20/13/13/24/17/18.
const EXPECTED_PER_DAY_TALLIES := [8, 24, 20, 13, 13, 24, 17]

const TOP_LEVEL_KEYS := [
	"day_entry_count", "default_locale", "ending_entry_count", "entries", "entry_count",
	"kind", "locales", "schema_version",
]

const RECORD_KEYS := [
	"allowed_ending_forms", "allowed_signals", "atom_namespace", "content_version",
	"context_schema_id", "day", "ending_id", "entry_id", "line_namespace", "locators",
	"role", "visual_ids",
]

const LOCATOR_KEYS := ["label", "path"]
const VISUAL_KEYS := ["optional", "required"]

## The ten keywords scripts/validation/JsonSchemaValidator.gd actually implements, plus the two
## pure annotations that assert nothing. Anything else in a manifest schema is inert.
const IMPLEMENTED_KEYWORDS := [
	"type", "const", "enum", "required", "properties", "additionalProperties", "items",
	"minItems", "minLength", "uniqueItems",
]
const SCHEMA_ANNOTATIONS := ["$schema", "description"]

## Specification 12.3, in the order the closed union is written there.
const ENDING_FORM_UNION := [
	"derived_sweet", "derived_dark", "special_forced_dark", "deck_sweet", "deck_dark",
	"alone_normal", "alone_dark_mode", "observer_full", "observer_residue", "special_full",
	"special_residue",
]

## Specification 12.8, in the order the allowlist table rows are written there.
const SIGNAL_UNION := [
	"message.reply.commit", "history.line.witness", "message.echo.satisfy",
	"observer.evidence.commit", "pair.combination.witness",
]

## Twelve specification 12.3 rows in table order, then DEVIATION-3 Ruling 5, then Ruling 6.
const ROLE_ENUM := [
	"ordinary_message", "solo_invitation_offer", "group_contact_offer", "consequence_followup",
	"solo_pre_challenge", "solo_post_challenge", "hospital", "pair_pre_challenge_scene",
	"pair_post_challenge_scene", "solo_ending_step", "pair_ending_step", "alone_step",
	"echo_fallback", "ending_invitation_offer",
]

## MEASURED over the 137 records this commit ships, sorted by role, and asserted against 137 so a
## silently reclassified entry moves two numbers and cannot hide in the total. This table is a
## CHANGE DETECTOR, not a derivation: it is not independent proof that the specification assigns
## those roles. The role argument itself is the 12.3 table plus DEVIATION-3 Rulings 5 and 6, set out
## above; do not cite these counts as spec proof.
const ROLE_COUNTS := [
	["alone_step", 2],
	["consequence_followup", 44],
	["echo_fallback", 1],
	["ending_invitation_offer", 3],
	["group_contact_offer", 14],
	["hospital", 7],
	["ordinary_message", 6],
	["pair_ending_step", 4],
	["pair_post_challenge_scene", 4],
	["pair_pre_challenge_scene", 4],
	["solo_ending_step", 12],
	["solo_invitation_offer", 12],
	["solo_post_challenge", 12],
	["solo_pre_challenge", 12],
]

## Specification 7.1 fixes exactly six ordinary replyable messages; the plan's own presentation
## registry table names these six rows.
const ORDINARY_ENTRIES := [
	"contact.ordinary.lavinia.day1",
	"contact.ordinary.sylvia.day2",
	"contact.ordinary.priscilla.day3",
	"contact.ordinary.lavinia.day4",
	"contact.ordinary.priscilla.day5",
	"contact.ordinary.sylvia.day6",
]

## Specification 12.8 valid source for pair.combination.witness: a canonical visible P-L post-board
## entry after its full Perfect/Solved observation atom. The plan registers exactly four such atoms.
const PAIR_POST_BOARD_ENTRIES := [
	"dating.group.priscilla_lavinia.day2.post_challenge",
	"dating.group.priscilla_lavinia.day6.post_challenge",
	"dating.twofriends.priscilla_lavinia.day2.post_challenge",
	"dating.twofriends.priscilla_lavinia.day6.post_challenge",
]

const ECHO_FALLBACK_ENTRY := "echo.fallback.day7"

## DEVIATION-3 Ruling 6.
const ENDING_INVITATION_ENTRIES := [
	"contact.invitation.ending.priscilla.day7.offer",
	"contact.invitation.ending.lavinia.day7.offer",
	"contact.invitation.ending.sylvia.day7.offer",
]

## DEVIATION-3 Ruling 5.
const GAP_ROLE_ENTRIES := [
	["echo.fallback.day7", "echo_fallback"],
]

## BINDING MAINTAINER RULING A. Specification 11.1's "due Day 6 Priscilla, Lavinia, and
## Priscilla-Lavinia follow-ups" are exactly the day_7.dtl entries whose role is
## consequence_followup. test_the_twelve_day_seven_follow_ups_are_the_ones_eleven_one_names
## re-derives the set from role and day rather than trusting this list.
const DAY_SEVEN_ECHO_ENTRIES := [
	"contact.invitation.solo.priscilla.day6.nevermind",
	"contact.invitation.solo.priscilla.day6.missed_question",
	"contact.invitation.solo.lavinia.day6.nevermind",
	"contact.invitation.solo.lavinia.day6.missed_question",
	"contact.invitation.group.priscilla_lavinia.day6.busy_priscilla",
	"contact.invitation.group.priscilla_lavinia.day6.busy_lavinia",
	"contact.invitation.group.priscilla_lavinia.day6.nevermind_priscilla",
	"contact.invitation.group.priscilla_lavinia.day6.nevermind_lavinia",
	"contact.invitation.group.priscilla_lavinia.day6.judge_priscilla",
	"contact.invitation.group.priscilla_lavinia.day6.judge_lavinia",
	"contact.invitation.group.priscilla_lavinia.day6.missed_question_priscilla",
	"contact.invitation.group.priscilla_lavinia.day6.missed_question_lavinia",
]

const EXPECTED_ECHO_HOLDER_COUNT := 19

## Every distinct sorted allowlist and how many records carry it. Four shapes, summing to 137.
const EXPECTED_SIGNAL_SHAPES := [
	["history.line.witness", 114],
	["history.line.witness|message.echo.satisfy", 13],
	["history.line.witness|message.echo.satisfy|message.reply.commit", 6],
	["history.line.witness|pair.combination.witness", 4],
]

## I-2 fixture host. No Chinese .dtl file is fabricated anywhere; the Global Constraint forbids
## fabricating FILES, and an in-memory Dictionary locator is not one.
const CHINESE_MASTER := "res://dialogic/timelines/zh/day_1.dtl"
const ENGLISH_DAY_ONE_MASTER := "res://dialogic/timelines/en/contacts/lavinia_day1.dtl"


const CODE_DOCUMENT_SHAPE := &"ENTRY_MANIFEST_DOCUMENT_SHAPE"
const CODE_SCHEMA_INVALID := &"ENTRY_MANIFEST_SCHEMA_INVALID"
const CODE_ENTRY_COUNT_MISMATCH := &"ENTRY_MANIFEST_ENTRY_COUNT_MISMATCH"
const CODE_DUPLICATE_ENTRY_ID := &"ENTRY_MANIFEST_DUPLICATE_ENTRY_ID"
const CODE_DUPLICATE_CONTEXT_SCHEMA_ID := &"ENTRY_MANIFEST_DUPLICATE_CONTEXT_SCHEMA_ID"
const CODE_ABSOLUTE_OS_PATH := &"ENTRY_MANIFEST_ABSOLUTE_OS_PATH"
const CODE_NON_RES_PATH := &"ENTRY_MANIFEST_NON_RES_PATH"
const CODE_LABEL_ENTRY_MISMATCH := &"ENTRY_MANIFEST_LABEL_ENTRY_MISMATCH"
const CODE_DUPLICATE_LOCATOR_PAIR := &"ENTRY_MANIFEST_DUPLICATE_LOCATOR_PAIR"
const CODE_ENDING_PARTITION_INVALID := &"ENTRY_MANIFEST_ENDING_PARTITION_INVALID"
const CODE_ENDING_FORMS_INVALID := &"ENTRY_MANIFEST_ENDING_FORMS_INVALID"
const CODE_NAMESPACE_MISMATCH := &"ENTRY_MANIFEST_NAMESPACE_MISMATCH"
const CODE_CONTEXT_SCHEMA_ID_MISMATCH := &"ENTRY_MANIFEST_CONTEXT_SCHEMA_ID_MISMATCH"
const CODE_SIGNAL_LIST_INVALID := &"ENTRY_MANIFEST_SIGNAL_LIST_INVALID"
const CODE_UNKNOWN_ENTRY := &"ENTRY_MANIFEST_UNKNOWN_ENTRY"
const CODE_ENGLISH_LOCATOR_MISSING := &"ENTRY_MANIFEST_ENGLISH_LOCATOR_MISSING"
const CODE_ENGLISH_LOCATOR_AMBIGUOUS := &"ENTRY_MANIFEST_ENGLISH_LOCATOR_AMBIGUOUS"

## KNOWINGLY UNCOVERED: reaching these three needs the manifest or the schema to be absent or
## corrupt on disk, which this suite does not do. They are declared anyway so their spelling is
## pinned and their absence from the coverage set is explicit rather than accidental.
const CODE_FILE_MISSING := &"ENTRY_MANIFEST_FILE_MISSING"
const CODE_PARSE_FAILED := &"ENTRY_MANIFEST_PARSE_FAILED"
const CODE_SCHEMA_MISSING := &"ENTRY_MANIFEST_SCHEMA_MISSING"

const ALL_FAILURE_CODES := [
	CODE_DOCUMENT_SHAPE, CODE_SCHEMA_INVALID, CODE_ENTRY_COUNT_MISMATCH, CODE_DUPLICATE_ENTRY_ID,
	CODE_DUPLICATE_CONTEXT_SCHEMA_ID, CODE_ABSOLUTE_OS_PATH, CODE_NON_RES_PATH,
	CODE_LABEL_ENTRY_MISMATCH, CODE_DUPLICATE_LOCATOR_PAIR, CODE_ENDING_PARTITION_INVALID,
	CODE_ENDING_FORMS_INVALID, CODE_NAMESPACE_MISMATCH, CODE_CONTEXT_SCHEMA_ID_MISMATCH,
	CODE_SIGNAL_LIST_INVALID, CODE_UNKNOWN_ENTRY, CODE_ENGLISH_LOCATOR_MISSING,
	CODE_ENGLISH_LOCATOR_AMBIGUOUS, CODE_FILE_MISSING, CODE_PARSE_FAILED, CODE_SCHEMA_MISSING,
]

## Sub-commit 2B landed these five on the same class. Their BEHAVIOUR is owned by
## tests/unit/test_dialogic_ids_manifest.gd, which also owns the ids registry they read; this
## suite asserts only that the method surface it depends on is present, so a deletion in 2B
## territory cannot pass unnoticed here either.
const SUB_COMMIT_2B_METHOD_NAMES := [
	"load_ids_default", "validate_ids_document", "validate_signal", "validate_line_id",
	"validate_atom_id",
]
const DECLARED_METHOD_NAMES := ["load_default", "validate_document", "resolve_entry", "fingerprint"]


# --------------------------------------------------------------------------------------------
# Loading helpers. Everything fails soft so RED is an assertion, never a script error.
# --------------------------------------------------------------------------------------------

func _parse(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return {}
	return parsed["value"]


func _parse_diagnostic(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "%s: file does not exist" % path
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if parsed.get("ok", false):
		return ""
	return "%s: StrictJson rejected the document, code %s at line %s column %s: %s" % [
		path, str(parsed.get("code", "")), str(parsed.get("line", "")),
		str(parsed.get("column", "")), str(parsed.get("message", "")),
	]


func _document() -> Dictionary:
	return _parse(MANIFEST_PATH)


func _records() -> Array:
	var entries: Variant = _document().get("entries", [])
	return entries if entries is Array else []


func _manifest_script() -> Script:
	var loaded: Dictionary = PROBE.load_script(SCRIPT_PATH)
	if not loaded.get("ok", false):
		return null
	return loaded["value"] as Script


func _record_by_entry_id(entry_id: String) -> Dictionary:
	for entry: Variant in _records():
		if entry is Dictionary and str((entry as Dictionary).get("entry_id", "")) == entry_id:
			return entry
	return {}


## This engine's Dictionary == is not a deep comparison, so two independently parsed documents are
## compared through their canonical serialization instead.
func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	return str(emitted.get("value", "")) if emitted.get("ok", false) else ""


# --------------------------------------------------------------------------------------------
# Second, independent derivation: re-parse the design specification off disk.
# --------------------------------------------------------------------------------------------

func _spec_text() -> String:
	if not FileAccess.file_exists(SPEC_PATH):
		return ""
	return FileAccess.get_file_as_string(SPEC_PATH)


## Returns [[entry_id, owning_day], ...] in specification 13.1 through 13.7 bullet order.
func _spec_day_entries() -> Array:
	var out: Array = []
	var current := 0
	for line: String in _spec_text().split("\n"):
		if line.begins_with("### 13."):
			var digit := line.substr(7, 1)
			current = int(digit) if digit.is_valid_int() else 0
			if current > 7:
				current = 0
			continue
		if line.begins_with("## 14"):
			current = 0
		if current == 0 or not line.begins_with("- `"):
			continue
		var rest := line.substr(3)
		var close := rest.find("`")
		if close < 0:
			continue
		var entry_id := rest.substr(0, close)
		if entry_id in ["opening.day1", "tutorial.desktop_day1"]:
			continue
		out.append([entry_id, current])
	return out


## Returns [[ending_id, [entry_id, ...], form_selection_text], ...] in 13.8 table order.
func _spec_ending_rows() -> Array:
	var out: Array = []
	var inside := false
	for line: String in _spec_text().split("\n"):
		if line.begins_with("### 13.8"):
			inside = true
			continue
		if not inside:
			continue
		if line.begins_with("## 14"):
			break
		if not line.begins_with("|"):
			continue
		var cells: Array = []
		for cell: String in line.strip_edges().trim_prefix("|").trim_suffix("|").split("|"):
			cells.append(cell.strip_edges())
		if cells.size() != 3:
			continue
		var head: String = str(cells[0])
		if head.begins_with("---") or head.contains("Stable"):
			continue
		var entry_ids: Array = []
		for piece: String in str(cells[1]).split(","):
			entry_ids.append(piece.strip_edges().lstrip("`").rstrip("`"))
		out.append([head.lstrip("`").rstrip("`"), entry_ids, str(cells[2])])
	return out


## The 137 entry ids the specification itself dictates, day entries first in 13.1-13.7 order and
## then the 13.8 table expansion, which is the order the manifest must store them in.
func _spec_entry_ids() -> Array:
	var out: Array = []
	for pair: Array in _spec_day_entries():
		out.append(str(pair[0]))
	for row: Array in _spec_ending_rows():
		for entry_id: Variant in row[1]:
			out.append(str(entry_id))
	return out


func _expected_context_schema_id(role: String, entry_id: String) -> String:
	return "context." + role + "." + entry_id + ".v1"


func _expected_signals(entry_id: String) -> Array:
	var out: Array = ["history.line.witness"]
	if ORDINARY_ENTRIES.has(entry_id):
		out.append("message.reply.commit")
		out.append("message.echo.satisfy")
	if entry_id == ECHO_FALLBACK_ENTRY:
		out.append("message.echo.satisfy")
	if DAY_SEVEN_ECHO_ENTRIES.has(entry_id):
		out.append("message.echo.satisfy")
	if PAIR_POST_BOARD_ENTRIES.has(entry_id):
		out.append("pair.combination.witness")
	var unique: Array = []
	for signal_id: Variant in out:
		if not unique.has(signal_id):
			unique.append(signal_id)
	unique.sort()
	return unique


# --------------------------------------------------------------------------------------------
# Manifest shape.
# --------------------------------------------------------------------------------------------

func test_the_manifest_file_exists_and_parses_as_strict_json() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "expected RED: missing " + MANIFEST_PATH)
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed.get("ok", false),
		"the manifest must parse under StrictJson: " + _parse_diagnostic(MANIFEST_PATH))


func test_the_manifest_top_level_is_exact_key() -> void:
	var document := _document()
	assert_false(document.is_empty(),
		"expected RED: manifest absent or unparseable: " + _parse_diagnostic(MANIFEST_PATH))
	if document.is_empty():
		return
	var keys: Array = document.keys()
	keys.sort()
	assert_eq(keys, TOP_LEVEL_KEYS, "the top level is exact-key")
	assert_eq(document.get("schema_version"), 1, "schema_version is exactly 1")
	assert_eq(typeof(document.get("schema_version")), TYPE_INT, "schema_version is an int")
	assert_eq(document.get("kind"), "dialogic_entries", "kind is dialogic_entries")
	assert_eq(document.get("default_locale"), "en",
		"specification 14.1 makes English the only fallback locale")
	assert_eq(document.get("locales"), ["en"],
		"the Global Constraint forbids fabricating Chinese DTL files, so only English is declared")
	assert_eq(document.get("entry_count"), EXPECTED_ENTRY_COUNT, "137 callable entries")
	assert_eq(document.get("day_entry_count"), EXPECTED_DAY_ENTRY_COUNT, "119 day entries")
	assert_eq(document.get("ending_entry_count"), EXPECTED_ENDING_ENTRY_COUNT,
		"18 ending presentation entries")


func test_every_declared_count_equals_its_real_collection_length() -> void:
	var document := _document()
	assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
	if document.is_empty():
		return
	var records := _records()
	assert_eq(document.get("entry_count"), records.size(),
		"entry_count equals the real number of records")
	var day_entries := 0
	var ending_entries := 0
	for record: Dictionary in records:
		if record.get("day") == null:
			ending_entries += 1
		else:
			day_entries += 1
	assert_eq(document.get("day_entry_count"), day_entries,
		"day_entry_count equals the records that own a day")
	assert_eq(document.get("ending_entry_count"), ending_entries,
		"ending_entry_count equals the records that own no day")
	assert_eq(day_entries + ending_entries, EXPECTED_ENTRY_COUNT,
		"the two tallies partition all 137 records")


# --------------------------------------------------------------------------------------------
# The entry ids themselves, re-derived from the specification at runtime.
# --------------------------------------------------------------------------------------------

func test_the_specification_still_dictates_one_hundred_thirty_seven_entries() -> void:
	var day_entries := _spec_day_entries()
	var ending_rows := _spec_ending_rows()
	assert_eq(day_entries.size(), EXPECTED_DAY_ENTRY_COUNT,
		"sections 13.1-13.7 enumerate 119 day entries")
	assert_eq(ending_rows.size(), EXPECTED_ENDING_ID_COUNT,
		"the 13.8 table holds one row per stable ending id")
	var expanded := 0
	for row: Array in ending_rows:
		expanded += (row[1] as Array).size()
	assert_eq(expanded, EXPECTED_ENDING_ENTRY_COUNT,
		"the 13.8 cells expand to 18 callable presentation entries")
	assert_eq(day_entries.size() + expanded, EXPECTED_ENTRY_COUNT,
		"119 plus 18 is the current closed vocabulary's 137")


func test_the_entries_are_exactly_the_specification_ids_in_specification_order() -> void:
	var records := _records()
	var expected := _spec_entry_ids()
	assert_eq(expected.size(), EXPECTED_ENTRY_COUNT,
		"the specification parse itself found 137 ids")
	assert_eq(records.size(), expected.size(),
		"expected RED: the manifest holds exactly %d records" % EXPECTED_ENTRY_COUNT)
	if records.size() != expected.size():
		return
	var actual: Array = []
	for record: Dictionary in records:
		actual.append(str(record.get("entry_id", "")))
	assert_eq(actual, expected,
		"every entry id, in 13.1-13.7 bullet order then 13.8 table order, with zero inventions")


func test_every_entry_id_appears_verbatim_in_the_design_specification() -> void:
	var text := _spec_text()
	assert_false(text.is_empty(), "the design specification must be readable at " + SPEC_PATH)
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to check")
	if text.is_empty() or records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		assert_true(text.contains("`" + entry_id + "`"),
			"%s: appears verbatim in the specification; no id is invented" % entry_id)


func test_every_entry_id_is_unique() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to check")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var seen: Dictionary = {}
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		assert_false(seen.has(entry_id), "%s: an entry id is registered exactly once" % entry_id)
		seen[entry_id] = true


func test_no_entry_id_uses_a_wildcard_or_shorthand_family() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to check")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		for forbidden: String in ["*", "|", "{", "}", "?", " "]:
			assert_false(entry_id.contains(forbidden),
				"%s: the manifest is closed and expands every member explicitly" % entry_id)


# --------------------------------------------------------------------------------------------
# Day and ending partition.
# --------------------------------------------------------------------------------------------

func test_the_per_day_tallies_are_the_verification_gate_figures() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to tally")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var tallies: Array = [0, 0, 0, 0, 0, 0, 0]
	for record: Dictionary in records:
		var day: Variant = record.get("day")
		if day == null:
			continue
		assert_eq(typeof(day), TYPE_INT, "%s: day is an int" % str(record.get("entry_id", "")))
		if typeof(day) != TYPE_INT:
			continue
		var index: int = int(day) - 1
		assert_true(index >= 0 and index < 7,
			"%s: day is 1 through 7" % str(record.get("entry_id", "")))
		if index >= 0 and index < 7:
			tallies[index] += 1
	assert_eq(tallies, EXPECTED_PER_DAY_TALLIES,
		"the owning-master tallies are the Phase 01 Verification Gate figures")


func test_the_manifest_day_agrees_with_the_specification_section_that_owns_the_entry() -> void:
	var records := _records()
	var day_entries := _spec_day_entries()
	assert_eq(day_entries.size(), EXPECTED_DAY_ENTRY_COUNT, "expected RED: specification unread")
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to compare")
	if records.size() != EXPECTED_ENTRY_COUNT or day_entries.size() != EXPECTED_DAY_ENTRY_COUNT:
		return
	var owning: Dictionary = {}
	for pair: Array in day_entries:
		owning[str(pair[0])] = int(pair[1])
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		if not owning.has(entry_id):
			continue
		assert_eq(record.get("day"), owning[entry_id],
			"%s: day is the section that authors it, not the day it refers back to" % entry_id)


func test_ending_id_is_non_null_on_exactly_the_eighteen_ending_entries() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to partition")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var with_ending: Array = []
	var without_day: Array = []
	var ending_ids: Dictionary = {}
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		if record.get("ending_id") != null:
			with_ending.append(entry_id)
			ending_ids[str(record.get("ending_id"))] = true
		if record.get("day") == null:
			without_day.append(entry_id)
	assert_eq(with_ending.size(), EXPECTED_ENDING_ENTRY_COUNT,
		"ending_id is non-null on exactly the 18 ending presentation entries")
	assert_eq(with_ending, without_day,
		"the same 18 records carry an ending id and no day; the partition has no third case")
	assert_eq(ending_ids.size(), EXPECTED_ENDING_ID_COUNT,
		"the 18 entries collapse onto the 13 stable ending identities of 11.2 and 13.8")


func test_the_three_day_seven_ending_invitations_offer_but_never_present_an_ending() -> void:
	for entry_id: String in ENDING_INVITATION_ENTRIES:
		var record := _record_by_entry_id(entry_id)
		assert_false(record.is_empty(), "expected RED: %s is not registered" % entry_id)
		if record.is_empty():
			continue
		assert_eq(record.get("role"), "ending_invitation_offer",
			"%s: DEVIATION-3 Ruling 6 gives the boardless ending invitations their own role"
			% entry_id)
		assert_eq(record.get("ending_id"), null,
			"%s: 13.8 does not list it, so it offers an ending and never presents one" % entry_id)
		assert_eq(record.get("day"), 7, "%s: it is authored in day_7.dtl" % entry_id)
		assert_eq(record.get("allowed_ending_forms"), [],
			"%s: an entry that presents no ending declares no ending form" % entry_id)


func test_the_three_entries_with_no_twelve_three_row_carry_their_named_gap_roles() -> void:
	for pair: Array in GAP_ROLE_ENTRIES:
		var entry_id: String = str(pair[0])
		var record := _record_by_entry_id(entry_id)
		assert_false(record.is_empty(), "expected RED: %s is not registered" % entry_id)
		if record.is_empty():
			continue
		assert_eq(record.get("role"), str(pair[1]),
			"%s: DEVIATION-3 Ruling 5 records this as a named gap in 12.3, not an invention"
			% entry_id)


# --------------------------------------------------------------------------------------------
# Record shape, locators, namespaces.
# --------------------------------------------------------------------------------------------

func test_every_record_is_exact_key() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var keys: Array = record.keys()
		keys.sort()
		assert_eq(keys, RECORD_KEYS, "%s: exact record keys" % entry_id)
		assert_eq(record.get("content_version"), 1, "%s: content_version is 1" % entry_id)
		assert_eq(typeof(record.get("content_version")), TYPE_INT,
			"%s: content_version is an int" % entry_id)


func test_every_locator_declares_english_only_and_points_at_its_owning_master() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var locators: Variant = record.get("locators")
		assert_eq(typeof(locators), TYPE_DICTIONARY, "%s: locators is an object" % entry_id)
		if typeof(locators) != TYPE_DICTIONARY:
			continue
		assert_eq((locators as Dictionary).keys(), ["en"],
			"%s: only English exists; a missing locale falls back to the same label" % entry_id)
		var english: Variant = (locators as Dictionary).get("en")
		assert_eq(typeof(english), TYPE_DICTIONARY,
			"%s: the English locator is an object" % entry_id)
		if typeof(english) != TYPE_DICTIONARY:
			continue
		var keys: Array = (english as Dictionary).keys()
		keys.sort()
		assert_eq(keys, LOCATOR_KEYS, "%s: exact locator keys" % entry_id)
		var path: String = str((english as Dictionary).get("path", ""))
		assert_true(path.begins_with("res://dialogic/timelines/en/"), entry_id)
		assert_true(path.trim_prefix("res://dialogic/timelines/en/").contains("/"),
			"%s: the locator names a scene, independently of its delivery day" % entry_id)


func test_every_locator_label_equals_its_registered_entry_id() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var locators: Variant = record.get("locators", {})
		if typeof(locators) != TYPE_DICTIONARY:
			continue
		for locale: Variant in (locators as Dictionary):
			var locator: Variant = (locators as Dictionary)[locale]
			if typeof(locator) != TYPE_DICTIONARY:
				continue
			assert_eq(str((locator as Dictionary).get("label", "")), entry_id,
				"%s: the %s label equals the registered semantic entry" % [entry_id, str(locale)])


func test_no_two_entries_share_a_locator_pair() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var seen: Dictionary = {}
	for record: Dictionary in records:
		var locators: Variant = record.get("locators", {})
		if typeof(locators) != TYPE_DICTIONARY:
			continue
		for locale: Variant in (locators as Dictionary):
			var locator: Dictionary = (locators as Dictionary)[locale]
			var key: String = "%s|%s|%s" % [
				str(locale), str(locator.get("path", "")), str(locator.get("label", "")),
			]
			assert_false(seen.has(key), "%s: a locator pair is owned by exactly one entry" % key)
			seen[key] = true


func test_line_and_atom_namespaces_are_derived_from_the_entry_id() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		assert_eq(record.get("line_namespace"), "line." + entry_id,
			"%s: stable line namespace" % entry_id)
		assert_eq(record.get("atom_namespace"), "atom." + entry_id,
			"%s: stable presentation-atom namespace" % entry_id)


func test_context_schema_ids_follow_the_declared_convention_and_are_unique() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var seen: Dictionary = {}
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var expected := _expected_context_schema_id(str(record.get("role", "")), entry_id)
		assert_eq(record.get("context_schema_id"), expected,
			"%s: context.<role>.<entry_id>.v1" % entry_id)
		var actual: String = str(record.get("context_schema_id", ""))
		assert_false(seen.has(actual), "%s: one frozen context schema per entry" % actual)
		seen[actual] = true


func test_visual_ids_are_empty_in_structural_mode() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var visual_ids: Variant = record.get("visual_ids")
		assert_eq(typeof(visual_ids), TYPE_DICTIONARY, "%s: visual_ids is an object" % entry_id)
		if typeof(visual_ids) != TYPE_DICTIONARY:
			continue
		var keys: Array = (visual_ids as Dictionary).keys()
		keys.sort()
		assert_eq(keys, VISUAL_KEYS, "%s: exact visual_ids keys" % entry_id)
		assert_eq((visual_ids as Dictionary).get("required"), [],
			"%s: plan Task 6 keeps structural-mode visual lists empty" % entry_id)
		assert_eq((visual_ids as Dictionary).get("optional"), [],
			"%s: no invented art path is added in this phase" % entry_id)


# --------------------------------------------------------------------------------------------
# Roles, ending forms, signals.
# --------------------------------------------------------------------------------------------

func test_the_role_enum_is_closed_with_exact_per_role_counts() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to count")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var counts: Dictionary = {}
	for record: Dictionary in records:
		var role: String = str(record.get("role", ""))
		assert_true(ROLE_ENUM.has(role),
			"%s: role %s is a member of the closed enum" % [str(record.get("entry_id", "")), role])
		counts[role] = int(counts.get(role, 0)) + 1
	var total := 0
	for pair: Array in ROLE_COUNTS:
		var role: String = str(pair[0])
		assert_eq(counts.get(role, 0), int(pair[1]), "%s: exact population" % role)
		total += int(pair[1])
	assert_eq(total, EXPECTED_ENTRY_COUNT, "the per-role counts sum to 137 and hide nothing")
	var observed: Array = counts.keys()
	observed.sort()
	var declared: Array = []
	for pair: Array in ROLE_COUNTS:
		declared.append(str(pair[0]))
	assert_eq(observed, declared, "every declared role is populated and no other role appears")


func test_the_published_schema_declares_exactly_the_closed_vocabularies() -> void:
	var schema := _parse(SCHEMA_PATH)
	assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
	if schema.is_empty():
		return
	var record_properties: Dictionary = _record_schema(schema)
	assert_false(record_properties.is_empty(), "expected RED: the record schema is absent")
	if record_properties.is_empty():
		return
	assert_eq((record_properties.get("role", {}) as Dictionary).get("enum"), ROLE_ENUM,
		"the schema closes the role vocabulary at the sixteen derived values")
	var forms: Dictionary = record_properties.get("allowed_ending_forms", {})
	assert_eq((forms.get("items", {}) as Dictionary).get("enum"), ENDING_FORM_UNION,
		"the schema closes ending_form at the eleven-value 12.3 union")
	var signal_ids: Dictionary = record_properties.get("allowed_signals", {})
	assert_eq((signal_ids.get("items", {}) as Dictionary).get("enum"), SIGNAL_UNION,
		"the schema closes the signal vocabulary at the five 12.8 ids")
	var entries: Dictionary = (schema.get("properties", {}) as Dictionary).get("entries", {})
	assert_eq(entries.get("minItems"), EXPECTED_ENTRY_COUNT,
		"the schema floors the record array at 137, which mutation site S08 removed unnoticed")


func _record_schema(schema: Dictionary) -> Dictionary:
	var properties: Dictionary = schema.get("properties", {})
	var entries: Dictionary = properties.get("entries", {})
	var items: Dictionary = entries.get("items", {})
	return items.get("properties", {})


func test_allowed_ending_forms_are_empty_on_day_entries_and_exact_on_ending_entries() -> void:
	var records := _records()
	var ending_rows := _spec_ending_rows()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	assert_eq(ending_rows.size(), EXPECTED_ENDING_ID_COUNT, "expected RED: specification unread")
	if records.size() != EXPECTED_ENTRY_COUNT or ending_rows.size() != EXPECTED_ENDING_ID_COUNT:
		return
	var union_seen: Dictionary = {}
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var forms: Variant = record.get("allowed_ending_forms", [])
		assert_eq(typeof(forms), TYPE_ARRAY, "%s: allowed_ending_forms is an array" % entry_id)
		if typeof(forms) != TYPE_ARRAY:
			continue
		if record.get("ending_id") == null:
			assert_eq(forms, [], "%s: a day entry presents no ending identity" % entry_id)
			continue
		assert_false((forms as Array).is_empty(),
			"%s: an ending entry declares at least one legal playback form" % entry_id)
		for form: Variant in (forms as Array):
			assert_true(ENDING_FORM_UNION.has(str(form)),
				"%s: %s is a member of the closed 12.3 union" % [entry_id, str(form)])
			union_seen[str(form)] = true
	var covered: Array = union_seen.keys()
	covered.sort()
	var expected: Array = ENDING_FORM_UNION.duplicate()
	expected.sort()
	assert_eq(covered, expected, "all eleven union members are reachable from some ending entry")


func test_the_sylvia_dark_entry_carries_both_forms_thirteen_eight_allows() -> void:
	var record := _record_by_entry_id("ending.sylvia.dark")
	assert_false(record.is_empty(), "expected RED: ending.sylvia.dark is not registered")
	if record.is_empty():
		return
	assert_eq(record.get("allowed_ending_forms"), ["derived_dark", "special_forced_dark"],
		"13.8 gives this row derived Dark or special_forced_dark, and nothing else")
	assert_eq(record.get("ending_id"), "ending.sylvia.dark", "its stable identity")


func test_the_ending_forms_match_the_thirteen_eight_table_read_at_runtime() -> void:
	var records := _records()
	var ending_rows := _spec_ending_rows()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to compare")
	if records.size() != EXPECTED_ENTRY_COUNT or ending_rows.is_empty():
		return
	var owner: Dictionary = {}
	var selection: Dictionary = {}
	for row: Array in ending_rows:
		for entry_id: Variant in row[1]:
			owner[str(entry_id)] = str(row[0])
			selection[str(entry_id)] = str(row[2])
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		if not owner.has(entry_id):
			continue
		assert_eq(record.get("ending_id"), owner[entry_id],
			"%s: the 13.8 row that owns this entry" % entry_id)
		var text: String = str(selection[entry_id]).replace("`", "")
		var expected := _expected_ending_forms(entry_id, str(owner[entry_id]), text)
		assert_false(expected.is_empty(),
			"%s: the derivation must yield a form, never an empty expectation" % entry_id)
		assert_eq(record.get("allowed_ending_forms"), expected,
			"%s: the exact form array the 13.8 identity/entry map allows" % entry_id)


## 12.3 says the ending identity/entry map determines which values are legal, so the expectation is
## DERIVED from the owning ending id and the entry suffix. An earlier revision matched the Form
## selection prose instead, which collapsed observer_full, observer_residue, special_full and
## special_residue into one bucket and alone_normal with alone_dark_mode into another. Under that
## check a full/residue swap passed, inverting 11.10 where first discovery plays full and
## rediscovery plays residue, and a cross-family leak such as observer.full declaring special_full
## also passed. The only value still read out of the cell is special_forced_dark, which 13.8 grants
## to exactly one row by name. The array is compared whole, so storage order is pinned too.
func _expected_ending_forms(entry_id: String, ending_id: String, selection_text: String) -> Array:
	var expected: Array = []
	var deck: bool = ending_id.begins_with("ending.priscilla_lavinia.")
	if ending_id == "ending.alone":
		if entry_id.ends_with(".dark_mode"):
			expected.append("alone_dark_mode")
		elif entry_id.ends_with(".normal"):
			expected.append("alone_normal")
	elif ending_id.ends_with(".observer"):
		if entry_id.ends_with(".observer.full"):
			expected.append("observer_full")
		elif entry_id.ends_with(".observer.residue"):
			expected.append("observer_residue")
	elif ending_id.ends_with(".special"):
		if entry_id.ends_with(".special.full"):
			expected.append("special_full")
		elif entry_id.ends_with(".special.residue"):
			expected.append("special_residue")
	elif ending_id.ends_with(".sweet"):
		expected.append("deck_sweet" if deck else "derived_sweet")
	elif ending_id.ends_with(".dark"):
		expected.append("deck_dark" if deck else "derived_dark")
	if selection_text.contains("special_forced_dark"):
		expected.append("special_forced_dark")
	expected.sort()
	return expected


func test_allowed_signals_are_closed_by_default() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var signal_ids: Variant = record.get("allowed_signals", [])
		assert_eq(typeof(signal_ids), TYPE_ARRAY, "%s: allowed_signals is an array" % entry_id)
		if typeof(signal_ids) != TYPE_ARRAY:
			continue
		for signal_id: Variant in (signal_ids as Array):
			assert_true(SIGNAL_UNION.has(str(signal_id)),
				"%s: %s is one of the five 12.8 signal ids" % [entry_id, str(signal_id)])
		assert_eq(signal_ids, _expected_signals(entry_id),
			"%s: exactly the signals 12.8 lets this entry request, sorted" % entry_id)


func test_every_entry_may_witness_a_line() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var signal_ids: Array = record.get("allowed_signals", [])
		assert_true(signal_ids.has("history.line.witness"),
			"%s: a manifest-owned line in the current entry is always witnessable"
			% str(record.get("entry_id", "")))


func test_only_the_six_ordinary_entries_may_commit_a_reply() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var holders: Array = []
	for record: Dictionary in records:
		var signal_ids: Array = record.get("allowed_signals", [])
		if signal_ids.has("message.reply.commit"):
			holders.append(str(record.get("entry_id", "")))
	holders.sort()
	var expected: Array = ORDINARY_ENTRIES.duplicate()
	expected.sort()
	assert_eq(holders, expected,
		"12.8 names the six ordinary-message entries as the only reply-commit source")


func test_only_the_ruled_entry_families_may_satisfy_an_echo() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var holders: Array = []
	for record: Dictionary in records:
		var signal_ids: Array = record.get("allowed_signals", [])
		if signal_ids.has("message.echo.satisfy"):
			holders.append(str(record.get("entry_id", "")))
	holders.sort()
	var expected: Array = ORDINARY_ENTRIES.duplicate()
	expected.append(ECHO_FALLBACK_ENTRY)
	expected.append_array(DAY_SEVEN_ECHO_ENTRIES)
	expected.sort()
	assert_eq(holders.size(), EXPECTED_ECHO_HOLDER_COUNT,
		"six ordinary entries, twelve Day 7 follow-ups, and the Day 7 fallback")
	assert_eq(holders, expected,
		"11.1: the follow-ups may naturally satisfy echoes, and the fallback drains what REMAINS")


## The echo grant is a claim about an entry FAMILY, so the family is re-derived from role and day
## rather than read back out of the same literal list that produced the manifest.
func test_the_twelve_day_seven_follow_ups_are_the_ones_eleven_one_names() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var measured: Array = []
	for record: Dictionary in records:
		if record.get("day") == 7 and str(record.get("role", "")) == "consequence_followup":
			measured.append(str(record.get("entry_id", "")))
	measured.sort()
	var declared: Array = DAY_SEVEN_ECHO_ENTRIES.duplicate()
	declared.sort()
	assert_eq(measured.size(), DAY_SEVEN_ECHO_ENTRIES.size(),
		"day_7.dtl carries exactly twelve follow-up entries")
	assert_eq(measured, declared,
		"the echo grant covers the whole day_7.dtl follow-up family and nothing else")
	for entry_id: String in measured:
		assert_false(entry_id.contains("sylvia"),
			"%s: 11.1 names only Priscilla, Lavinia and Priscilla-Lavinia follow-ups" % entry_id)
		var signal_ids: Array = _record_by_entry_id(entry_id).get("allowed_signals", [])
		assert_true(signal_ids.has("message.echo.satisfy"),
			"%s: without this grant, the fallback's REMAINING list could never shrink" % entry_id)


func test_the_signal_shape_distribution_is_the_ruled_partition() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to tally")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var shapes: Dictionary = {}
	for record: Dictionary in records:
		var key := ""
		for part: Variant in (record.get("allowed_signals", []) as Array):
			key = str(part) if key.is_empty() else key + "|" + str(part)
		shapes[key] = int(shapes.get(key, 0)) + 1
	var keys: Array = shapes.keys()
	keys.sort()
	var observed: Array = []
	var total := 0
	for key: Variant in keys:
		observed.append([str(key), int(shapes[key])])
		total += int(shapes[key])
	assert_eq(observed, EXPECTED_SIGNAL_SHAPES,
		"114 witness-only, 13 witness plus echo, 6 ordinary, 4 P-L post-board")
	assert_eq(total, EXPECTED_ENTRY_COUNT, "the four shapes partition all 137 records")


func test_only_the_four_pair_post_board_entries_may_witness_a_combination() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	var holders: Array = []
	for record: Dictionary in records:
		var signal_ids: Array = record.get("allowed_signals", [])
		if signal_ids.has("pair.combination.witness"):
			holders.append(str(record.get("entry_id", "")))
	holders.sort()
	var expected: Array = PAIR_POST_BOARD_ENTRIES.duplicate()
	expected.sort()
	assert_eq(holders, expected,
		"12.8 valid source is a canonical visible P-L post-board entry after its full atom")


func test_no_entry_may_commit_observer_evidence_in_this_phase() -> void:
	var records := _records()
	assert_eq(records.size(), EXPECTED_ENTRY_COUNT, "expected RED: no records to inspect")
	if records.size() != EXPECTED_ENTRY_COUNT:
		return
	for record: Dictionary in records:
		var signal_ids: Array = record.get("allowed_signals", [])
		assert_false(signal_ids.has("observer.evidence.commit"),
			"%s: production Observer evidence stays absent until an approved content card names it"
			% str(record.get("entry_id", "")))


# --------------------------------------------------------------------------------------------
# Byte canonicality.
# --------------------------------------------------------------------------------------------

func test_the_manifest_is_stored_byte_canonically() -> void:
	var document := _document()
	assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
	if document.is_empty():
		return
	var canonical := _canonical(document)
	assert_false(canonical.is_empty(), "the document round-trips through CanonicalJsonWriter")
	if canonical.is_empty():
		return
	assert_eq(FileAccess.get_file_as_string(MANIFEST_PATH), canonical + "\n",
		"the file holds one canonical sorted-key line and a single trailing newline")


# --------------------------------------------------------------------------------------------
# Published schema: what it really enforces, and what it provably does not.
# --------------------------------------------------------------------------------------------

func test_the_published_schema_accepts_the_manifest() -> void:
	assert_true(FileAccess.file_exists(SCHEMA_PATH), "expected RED: missing " + SCHEMA_PATH)
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
		return
	var result: Dictionary = JsonSchemaValidator.validate(document, schema)
	assert_true(result.get("ok", false),
		"the published schema accepts the shipped manifest: " + str(result.get("message", "")))


func test_the_schema_closes_every_object_level() -> void:
	var schema := _parse(SCHEMA_PATH)
	assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
	if schema.is_empty():
		return
	assert_eq(schema.get("$schema"), "https://json-schema.org/draft/2020-12/schema",
		"draft 2020-12, as every other manifest schema in this repo")
	var open_objects: Array = []
	_collect_open_objects(schema, "$", open_objects)
	assert_eq(open_objects, [], "every object level sets additionalProperties false")


func _collect_open_objects(node: Variant, path: String, found: Array) -> void:
	if node is Array:
		var items: Array = node
		for index in range(items.size()):
			_collect_open_objects(items[index], "%s[%d]" % [path, index], found)
		return
	if not (node is Dictionary):
		return
	var object: Dictionary = node
	if str(object.get("type", "")) == "object" and object.get("additionalProperties", true) != false:
		found.append(path)
	for key: Variant in object:
		_collect_open_objects(object[key], "%s.%s" % [path, str(key)], found)


func test_the_schema_uses_only_keywords_the_validator_implements() -> void:
	var schema := _parse(SCHEMA_PATH)
	assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
	if schema.is_empty():
		return
	var inert: Array = []
	_collect_inert_keywords(schema, "$", inert)
	assert_eq(inert, [],
		"DEVIATION-3 Ruling 3 forbids an inert keyword; JsonSchemaValidator ignores it silently")


## Walks only real schema nodes: from a node, descend through properties.<name> and items. enum
## members and required lists are values, never schema nodes, so they are never scanned.
func _collect_inert_keywords(node: Variant, path: String, found: Array) -> void:
	if not (node is Dictionary):
		return
	var object: Dictionary = node
	for key: Variant in object:
		var keyword: String = str(key)
		if not IMPLEMENTED_KEYWORDS.has(keyword) and not SCHEMA_ANNOTATIONS.has(keyword):
			found.append("%s.%s" % [path, keyword])
	var properties: Variant = object.get("properties")
	if properties is Dictionary:
		for name: Variant in (properties as Dictionary):
			_collect_inert_keywords((properties as Dictionary)[name],
				"%s.properties.%s" % [path, str(name)], found)
	if object.has("items"):
		_collect_inert_keywords(object["items"], path + ".items", found)


func test_the_schema_rejects_an_unknown_record_property() -> void:
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var mutated: Dictionary = document.duplicate(true)
	((mutated["entries"] as Array)[0] as Dictionary)["unexpected"] = true
	assert_false(JsonSchemaValidator.validate(mutated, schema).get("ok", true),
		"an unknown record property is rejected")
	var top_level: Dictionary = document.duplicate(true)
	top_level["unexpected"] = true
	assert_false(JsonSchemaValidator.validate(top_level, schema).get("ok", true),
		"an unknown top-level property is rejected")


func test_the_schema_rejects_an_unknown_role() -> void:
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var mutated: Dictionary = document.duplicate(true)
	((mutated["entries"] as Array)[0] as Dictionary)["role"] = "narrator_aside"
	assert_false(JsonSchemaValidator.validate(mutated, schema).get("ok", true),
		"a role outside the closed 12.3 vocabulary is rejected")


func test_the_schema_rejects_an_unknown_ending_form_and_an_unknown_signal() -> void:
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var bad_form: Dictionary = document.duplicate(true)
	for record: Dictionary in (bad_form["entries"] as Array):
		if record.get("ending_id") != null:
			record["allowed_ending_forms"] = ["derived_bittersweet"]
			break
	assert_false(JsonSchemaValidator.validate(bad_form, schema).get("ok", true),
		"an ending form outside the closed eleven-value union is rejected")
	var bad_signal: Dictionary = document.duplicate(true)
	((bad_signal["entries"] as Array)[0] as Dictionary)["allowed_signals"] = ["state.mutate.now"]
	assert_false(JsonSchemaValidator.validate(bad_signal, schema).get("ok", true),
		"a signal outside the closed 12.8 allowlist is rejected")


## I-4 removed a duplicate scan from DialogicEntryManifest._check_allowlist because the schema
## already enforced uniqueItems and validate_document runs the schema first, so the code branch was
## unreachable. Removing a law obliges proving the surviving half really works, so the ownership
## transfer is asserted behaviourally here as well as literally in
## test_the_published_schema_pins_its_own_literals.
func test_the_schema_owns_duplicate_detection_inside_a_record_list() -> void:
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
		return
	var repeated_signal: Dictionary = document.duplicate(true)
	((repeated_signal["entries"] as Array)[0] as Dictionary)["allowed_signals"] = [
		"history.line.witness", "history.line.witness",
	]
	assert_false(JsonSchemaValidator.validate(repeated_signal, schema).get("ok", true),
		"a repeated signal id is rejected by the schema, which now solely owns that law")
	var repeated_form: Dictionary = document.duplicate(true)
	for record: Dictionary in (repeated_form["entries"] as Array):
		if record.get("ending_id") != null:
			record["allowed_ending_forms"] = ["derived_sweet", "derived_sweet"]
			break
	assert_false(JsonSchemaValidator.validate(repeated_form, schema).get("ok", true),
		"a repeated ending form is rejected the same way")
	var repeated_visual: Dictionary = document.duplicate(true)
	((repeated_visual["entries"] as Array)[0] as Dictionary)["visual_ids"] = {
		"optional": [], "required": ["visual.x", "visual.x"],
	}
	assert_false(JsonSchemaValidator.validate(repeated_visual, schema).get("ok", true),
		"and a repeated visual id is too")


func test_the_schema_owns_locale_closure() -> void:
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		return
	var fabricated: Dictionary = document.duplicate(true)
	var locators: Dictionary = ((fabricated["entries"] as Array)[0] as Dictionary)["locators"]
	locators["zh"] = {"label": "x", "path": "res://dialogic/timelines/zh/day_1.dtl"}
	assert_false(JsonSchemaValidator.validate(fabricated, schema).get("ok", true),
		"the Global Constraint forbids fabricating a Chinese locator")
	var without_english: Dictionary = document.duplicate(true)
	((without_english["entries"] as Array)[0] as Dictionary)["locators"] = {}
	assert_false(JsonSchemaValidator.validate(without_english, schema).get("ok", true),
		"every entry owns an English locator because English is the only legal fallback")
	var declared: Dictionary = document.duplicate(true)
	declared["locales"] = ["en", "zh"]
	assert_false(JsonSchemaValidator.validate(declared, schema).get("ok", true),
		"the declared locale list is closed at English too")


## DEVIATION-3 Ruling 3, stated as an executable fact rather than as prose. If a later agent
## deletes one of the four code laws believing the schema still covers it, this test is the
## evidence that it does not.
func test_the_schema_alone_catches_none_of_the_four_code_laws() -> void:
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	var script := _manifest_script()
	if schema.is_empty() or document.is_empty() or script == null:
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
		assert_true(script != null, "expected RED: missing " + SCRIPT_PATH)
		return
	var rows: Array = [
		["duplicate locator pair", _with_duplicate_locator_pair(document),
			CODE_DUPLICATE_LOCATOR_PAIR],
		["absolute OS path", _with_locator_path(document, "C:/dwm/dialogic/day_1.dtl"),
			CODE_ABSOLUTE_OS_PATH],
		["non-res path", _with_locator_path(document, "user://dialogic/day_1.dtl"),
			CODE_NON_RES_PATH],
		["label unequal to entry", _with_locator_label(document, "daily_message"),
			CODE_LABEL_ENTRY_MISMATCH],
	]
	for row: Array in rows:
		var label: String = str(row[0])
		var mutated: Dictionary = row[1]
		assert_true(JsonSchemaValidator.validate(mutated, schema).get("ok", false),
			"%s: the published schema alone accepts it, which is exactly why a code law exists"
			% label)
		var result: Dictionary = script.call(&"validate_document", mutated)
		assert_false(result.get("ok", true), "%s: the code law rejects it" % label)
		assert_eq(result.get("code"), row[2], "%s: with its own named code" % label)


# --------------------------------------------------------------------------------------------
# Mutation builders. Each returns a fresh deep copy; the shipped document is never touched.
# --------------------------------------------------------------------------------------------

## Two entries end up naming one physical {path,label} pair. That necessarily also breaks
## label-equals-entry on the second record, so validate_document checks the pair before the label;
## the two laws stay independently reachable because a label mismatch alone leaves the pair unique.
func _with_duplicate_locator_pair(document: Dictionary) -> Dictionary:
	var mutated: Dictionary = document.duplicate(true)
	var entries: Array = mutated["entries"]
	var first: Dictionary = (entries[0] as Dictionary)["locators"]
	var second: Dictionary = (entries[1] as Dictionary)["locators"]
	second["en"] = (first["en"] as Dictionary).duplicate(true)
	return mutated


func _with_locator_path(document: Dictionary, path: String) -> Dictionary:
	var mutated: Dictionary = document.duplicate(true)
	var locators: Dictionary = ((mutated["entries"] as Array)[0] as Dictionary)["locators"]
	(locators["en"] as Dictionary)["path"] = path
	return mutated


func _with_locator_label(document: Dictionary, label: String) -> Dictionary:
	var mutated: Dictionary = document.duplicate(true)
	var locators: Dictionary = ((mutated["entries"] as Array)[0] as Dictionary)["locators"]
	(locators["en"] as Dictionary)["label"] = label
	return mutated


# --------------------------------------------------------------------------------------------
# DialogicEntryManifest: the four methods this sub-commit owns.
# --------------------------------------------------------------------------------------------

func test_the_manifest_script_exists_and_declares_its_expected_method_surface() -> void:
	var script := _manifest_script()
	assert_true(script != null, "expected RED: missing " + SCRIPT_PATH)
	if script == null:
		return
	var names: Array = []
	for method: Dictionary in script.get_script_method_list():
		names.append(str(method.get("name", "")))
	for declared: String in DECLARED_METHOD_NAMES:
		assert_true(names.has(declared), "%s is implemented in this commit" % declared)
	for landed: String in SUB_COMMIT_2B_METHOD_NAMES:
		assert_true(names.has(landed),
			"%s landed in sub-commit 2B; test_dialogic_ids_manifest.gd owns its behaviour" % landed)


func test_load_default_returns_the_shipped_document() -> void:
	var script := _manifest_script()
	assert_true(script != null, "expected RED: missing " + SCRIPT_PATH)
	if script == null:
		return
	var result: Dictionary = script.call(&"load_default")
	assert_true(result.get("ok", false), "load_default succeeds: " + str(result.get("message", "")))
	if not result.get("ok", false):
		return
	var loaded := _canonical(result.get("value"))
	assert_false(loaded.is_empty(), "the loaded value serializes canonically")
	assert_eq(loaded, _canonical(_document()), "it returns the parsed manifest document")


func test_validate_document_accepts_the_shipped_manifest() -> void:
	var script := _manifest_script()
	var document := _document()
	if script == null or document.is_empty():
		assert_true(script != null, "expected RED: missing " + SCRIPT_PATH)
		assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
		return
	var result: Dictionary = script.call(&"validate_document", document)
	assert_true(result.get("ok", false),
		"the shipped manifest satisfies every code law: " + str(result.get("message", "")))


func _reject(mutated: Dictionary, code: StringName, why: String) -> void:
	var script := _manifest_script()
	if script == null:
		assert_true(false, "expected RED: missing " + SCRIPT_PATH)
		return
	var result: Dictionary = script.call(&"validate_document", mutated)
	assert_false(result.get("ok", true), why)
	assert_eq(result.get("code"), code, why + " (named code)")


func _guard() -> bool:
	var document := _document()
	if document.is_empty() or _manifest_script() == null:
		assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
		assert_true(_manifest_script() != null, "expected RED: missing " + SCRIPT_PATH)
		return false
	return true


func test_validate_document_rejects_a_non_document() -> void:
	if not _guard():
		return
	_reject({}, CODE_DOCUMENT_SHAPE, "a document without an entries array is rejected")


func test_validate_document_rejects_a_duplicate_entry_id() -> void:
	if not _guard():
		return
	var mutated: Dictionary = _document().duplicate(true)
	var entries: Array = mutated["entries"]
	(entries[1] as Dictionary)["entry_id"] = str((entries[0] as Dictionary).get("entry_id", ""))
	_reject(mutated, CODE_DUPLICATE_ENTRY_ID, "an entry id is registered exactly once")


func test_validate_document_rejects_a_duplicate_locator_pair() -> void:
	if not _guard():
		return
	_reject(_with_duplicate_locator_pair(_document()), CODE_DUPLICATE_LOCATOR_PAIR,
		"two entries may not share one physical path and label pair")


func test_validate_document_rejects_an_absolute_os_path() -> void:
	if not _guard():
		return
	_reject(_with_locator_path(_document(), "C:/dwm/dialogic/day_1.dtl"), CODE_ABSOLUTE_OS_PATH,
		"a Windows drive-letter locator escapes the resource sandbox")
	_reject(_with_locator_path(_document(), "/srv/dwm/dialogic/day_1.dtl"), CODE_ABSOLUTE_OS_PATH,
		"a POSIX absolute locator escapes the resource sandbox")


func test_validate_document_rejects_a_non_res_path() -> void:
	if not _guard():
		return
	_reject(_with_locator_path(_document(), "user://dialogic/day_1.dtl"), CODE_NON_RES_PATH,
		"a writable-storage locator is not a shipped master")
	_reject(_with_locator_path(_document(), "dialogic/timelines/en/day_1.dtl"), CODE_NON_RES_PATH,
		"a relative locator is not a shipped master")


func test_validate_document_rejects_a_label_that_is_not_its_entry_id() -> void:
	if not _guard():
		return
	_reject(_with_locator_label(_document(), "daily_message"), CODE_LABEL_ENTRY_MISMATCH,
		"a locator label equals its registered semantic entry")


func test_validate_document_rejects_a_broken_ending_partition() -> void:
	if not _guard():
		return
	var day_with_ending: Dictionary = _document().duplicate(true)
	((day_with_ending["entries"] as Array)[0] as Dictionary)["ending_id"] = "ending.alone"
	_reject(day_with_ending, CODE_ENDING_PARTITION_INVALID,
		"a day entry never claims an ending identity")
	var ending_with_day: Dictionary = _document().duplicate(true)
	for record: Dictionary in (ending_with_day["entries"] as Array):
		if record.get("ending_id") != null:
			record["day"] = 7
			break
	_reject(ending_with_day, CODE_ENDING_PARTITION_INVALID,
		"an ending entry owns the ending layer, never a day master")
	var out_of_range: Dictionary = _document().duplicate(true)
	((out_of_range["entries"] as Array)[0] as Dictionary)["day"] = 8
	_reject(out_of_range, CODE_ENDING_PARTITION_INVALID, "there is no day 8 master")


func test_validate_document_rejects_wrong_ending_forms() -> void:
	if not _guard():
		return
	var day_with_form: Dictionary = _document().duplicate(true)
	((day_with_form["entries"] as Array)[0] as Dictionary)["allowed_ending_forms"] = [
		"derived_sweet",
	]
	_reject(day_with_form, CODE_ENDING_FORMS_INVALID, "a day entry declares no playback form")
	var ending_without_form: Dictionary = _document().duplicate(true)
	for record: Dictionary in (ending_without_form["entries"] as Array):
		if record.get("ending_id") != null:
			record["allowed_ending_forms"] = []
			break
	_reject(ending_without_form, CODE_ENDING_FORMS_INVALID,
		"an ending entry that allows no form could never legally play")


func test_validate_document_rejects_a_derived_namespace_mismatch() -> void:
	if not _guard():
		return
	var line_broken: Dictionary = _document().duplicate(true)
	((line_broken["entries"] as Array)[0] as Dictionary)["line_namespace"] = "line.something.else"
	_reject(line_broken, CODE_NAMESPACE_MISMATCH,
		"12.6 forbids deriving a line id from anything but the stable entry")
	var atom_broken: Dictionary = _document().duplicate(true)
	((atom_broken["entries"] as Array)[0] as Dictionary)["atom_namespace"] = "atom.something.else"
	_reject(atom_broken, CODE_NAMESPACE_MISMATCH,
		"12.6 forbids deriving an atom id from anything but the stable entry")


func test_validate_document_rejects_a_context_schema_id_that_breaks_the_convention() -> void:
	if not _guard():
		return
	var mutated: Dictionary = _document().duplicate(true)
	((mutated["entries"] as Array)[0] as Dictionary)["context_schema_id"] = "context.v1"
	_reject(mutated, CODE_CONTEXT_SCHEMA_ID_MISMATCH,
		"sub-commit 2D dispatches on this id, so its shape is a law")


func test_validate_document_rejects_a_duplicate_context_schema_id() -> void:
	if not _guard():
		return
	var mutated: Dictionary = _document().duplicate(true)
	var entries: Array = mutated["entries"]
	(entries[1] as Dictionary)["context_schema_id"] = str(
		(entries[0] as Dictionary).get("context_schema_id", ""))
	_reject(mutated, CODE_DUPLICATE_CONTEXT_SCHEMA_ID,
		"two entries may not share one frozen context schema")


func test_validate_document_rejects_a_signal_list_that_drops_the_witness() -> void:
	if not _guard():
		return
	var mutated: Dictionary = _document().duplicate(true)
	((mutated["entries"] as Array)[0] as Dictionary)["allowed_signals"] = []
	_reject(mutated, CODE_SIGNAL_LIST_INVALID, "every entry may witness a manifest-owned line")
	var unsorted: Dictionary = _document().duplicate(true)
	for record: Dictionary in (unsorted["entries"] as Array):
		if str(record.get("entry_id", "")) == ORDINARY_ENTRIES[0]:
			record["allowed_signals"] = [
				"message.reply.commit", "history.line.witness", "message.echo.satisfy",
			]
			break
	_reject(unsorted, CODE_SIGNAL_LIST_INVALID,
		"the allowlist is stored sorted so two equal capabilities cannot differ in bytes")


func test_validate_document_rejects_a_count_that_disagrees_with_the_records() -> void:
	if not _guard():
		return
	var mutated: Dictionary = _document().duplicate(true)
	var entries: Array = mutated["entries"]
	var clone: Dictionary = (entries[0] as Dictionary).duplicate(true)
	clone["entry_id"] = str(clone.get("entry_id", "")) + ".clone"
	entries.append(clone)
	_reject(mutated, CODE_ENTRY_COUNT_MISMATCH, "entry_count must equal the real record length")
	var day_tally: Dictionary = _document().duplicate(true)
	day_tally["day_entry_count"] = EXPECTED_DAY_ENTRY_COUNT - 1
	_reject(day_tally, CODE_ENTRY_COUNT_MISMATCH,
		"day_entry_count must equal the records that really own a day")
	var ending_tally: Dictionary = _document().duplicate(true)
	ending_tally["ending_entry_count"] = EXPECTED_ENDING_ENTRY_COUNT + 1
	_reject(ending_tally, CODE_ENTRY_COUNT_MISMATCH,
		"ending_entry_count must equal the records that really own no day")


func test_validate_document_rejects_a_document_the_schema_refuses() -> void:
	if not _guard():
		return
	var mutated: Dictionary = _document().duplicate(true)
	((mutated["entries"] as Array)[0] as Dictionary)["role"] = "narrator_aside"
	_reject(mutated, CODE_SCHEMA_INVALID,
		"validate_document runs the published schema before its own laws")


# --------------------------------------------------------------------------------------------
# resolve_entry: exact locator, English-only fallback, closed failure.
# --------------------------------------------------------------------------------------------

func test_resolve_entry_returns_the_exact_english_locator() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var document := _document()
	var entry_id: String = ORDINARY_ENTRIES[0]
	var result: Dictionary = script.call(&"resolve_entry", document, entry_id, "en")
	assert_true(result.get("ok", false), "English resolves: " + str(result.get("message", "")))
	if not result.get("ok", false):
		return
	var value: Dictionary = result["value"]
	assert_eq(value.get("entry_id"), entry_id, "the same semantic entry")
	assert_eq(value.get("locale"), "en", "the selected locale")
	assert_eq(value.get("used_fallback"), false, "English is not a fallback of itself")
	assert_eq(value.get("label"), entry_id, "the exact label")
	assert_eq(value.get("path"), ENGLISH_DAY_ONE_MASTER, "the owning scene")


func test_resolve_entry_falls_back_to_english_and_changes_only_language() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var document := _document()
	for entry_id: String in [ORDINARY_ENTRIES[0], "ending.alone.normal", ECHO_FALLBACK_ENTRY]:
		var english: Dictionary = script.call(&"resolve_entry", document, entry_id, "en")
		var chinese: Dictionary = script.call(&"resolve_entry", document, entry_id, "zh")
		assert_true(chinese.get("ok", false),
			"%s: an absent locale falls back rather than failing" % entry_id)
		if not (chinese.get("ok", false) and english.get("ok", false)):
			continue
		var fallback: Dictionary = chinese["value"]
		var exact: Dictionary = english["value"]
		assert_eq(fallback.get("used_fallback"), true, "%s: the fallback is reported" % entry_id)
		assert_eq(fallback.get("locale"), "en", "%s: fallback language is English" % entry_id)
		assert_eq(fallback.get("requested_locale"), "zh",
			"%s: the requested locale is preserved for diagnostics" % entry_id)
		assert_eq(fallback.get("entry_id"), exact.get("entry_id"),
			"%s: fallback may change language only, never the entry" % entry_id)
		assert_eq(fallback.get("path"), exact.get("path"),
			"%s: fallback may change language only, never the day or ending layer" % entry_id)
		assert_eq(fallback.get("label"), exact.get("label"),
			"%s: fallback may change language only, never the exact label" % entry_id)


func test_resolve_entry_fails_closed_on_an_unknown_entry_id() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var document := _document()
	# ending.lavinia.true moved out of this list in sub-commit 2B: the three labels Task 1
	# retired now fail closed with ENTRY_MANIFEST_RETIRED_ENTRY instead, which
	# test_dialogic_ids_manifest.gd asserts for all three. Everything below is still a
	# stranger nobody ever registered.
	for unknown: String in [
		"contact.ordinary.nobody.day9",
		"contact.ordinary.lavinia.day1.extra",
		"",
	]:
		var result: Dictionary = script.call(&"resolve_entry", document, unknown, "en")
		assert_false(result.get("ok", true), "%s: an unknown suffix does not resolve" % unknown)
		assert_eq(result.get("code"), CODE_UNKNOWN_ENTRY, "%s: fails closed by name" % unknown)


func test_resolve_entry_fails_on_a_missing_english_label() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var entry_id: String = ORDINARY_ENTRIES[0]
	var mutated: Dictionary = _document().duplicate(true)
	for record: Dictionary in (mutated["entries"] as Array):
		if str(record.get("entry_id", "")) == entry_id:
			record["locators"] = {}
			break
	var result: Dictionary = script.call(&"resolve_entry", mutated, entry_id, "zh")
	assert_false(result.get("ok", true),
		"14.1: a missing English label starts nothing and preserves the pending event")
	assert_eq(result.get("code"), CODE_ENGLISH_LOCATOR_MISSING, "with its own named code")


func test_resolve_entry_fails_on_a_duplicated_english_label() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var mutated := _with_duplicate_locator_pair(_document())
	var entry_id: String = str(((mutated["entries"] as Array)[0] as Dictionary).get("entry_id", ""))
	var result: Dictionary = script.call(&"resolve_entry", mutated, entry_id, "en")
	assert_false(result.get("ok", true),
		"14.1: a duplicated English label is a failure, never a fallback")
	assert_eq(result.get("code"), CODE_ENGLISH_LOCATOR_AMBIGUOUS, "with its own named code")


func test_resolve_entry_never_falls_back_to_the_top_of_a_master() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var document := _document()
	for record: Dictionary in _records():
		var entry_id: String = str(record.get("entry_id", ""))
		var result: Dictionary = script.call(&"resolve_entry", document, entry_id, "zh")
		if not result.get("ok", false):
			assert_true(false, "%s: every registered entry resolves under fallback" % entry_id)
			continue
		var value: Dictionary = result["value"]
		assert_eq(value.get("label"), entry_id,
			"%s: the bridge never starts a merged file at its beginning" % entry_id)


# --------------------------------------------------------------------------------------------
# fingerprint.
# --------------------------------------------------------------------------------------------

func test_fingerprint_is_deterministic_and_content_sensitive() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var document := _document()
	var first: String = str(script.call(&"fingerprint", document))
	var second: String = str(script.call(&"fingerprint", _document()))
	assert_false(first.is_empty(), "the fingerprint is produced")
	assert_eq(first, second, "the same document always fingerprints the same way")
	assert_true(first.begins_with("sha256:"), "the digest names its own algorithm")
	assert_eq(first.length(), 71, "sha256: plus 64 lowercase hex digits")
	var mutated: Dictionary = document.duplicate(true)
	((mutated["entries"] as Array)[0] as Dictionary)["content_version"] = 2
	assert_ne(str(script.call(&"fingerprint", mutated)), first,
		"any content change moves the fingerprint")
	var reordered: Dictionary = document.duplicate(true)
	var entries: Array = reordered["entries"]
	entries.reverse()
	assert_ne(str(script.call(&"fingerprint", reordered)), first,
		"record order is part of the contract, so reordering moves the fingerprint")


func test_fingerprint_matches_the_canonical_bytes_on_disk() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var canonical := _canonical(_document())
	assert_false(canonical.is_empty(), "the document round-trips through CanonicalJsonWriter")
	if canonical.is_empty():
		return
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(canonical.to_utf8_buffer())
	assert_eq(str(script.call(&"fingerprint", _document())),
		"sha256:" + context.finish().hex_encode(),
		"the fingerprint is the SHA-256 of the canonical serialization, recomputed here")


# --------------------------------------------------------------------------------------------
# Schema literals, empty identifiers, and the failure-code vocabulary.
# --------------------------------------------------------------------------------------------

## Generalised from mutation survivor S08: a literal the schema declares but no test reads can be
## deleted unnoticed, so every one of them is read here.
func test_the_published_schema_pins_its_own_literals() -> void:
	var schema := _parse(SCHEMA_PATH)
	assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
	if schema.is_empty():
		return
	var properties: Dictionary = schema.get("properties", {})
	var record: Dictionary = _record_schema(schema)
	var top_required: Array = schema.get("required", [])
	top_required.sort()
	assert_eq(top_required, TOP_LEVEL_KEYS, "the schema requires exactly the eight top-level keys")
	assert_eq(schema.get("additionalProperties"), false, "the top level is closed")
	assert_eq((properties.get("schema_version", {}) as Dictionary).get("const"), 1,
		"schema_version is pinned")
	assert_eq((properties.get("kind", {}) as Dictionary).get("const"), "dialogic_entries",
		"kind is pinned")
	assert_eq((properties.get("default_locale", {}) as Dictionary).get("const"), "en",
		"default_locale is pinned; 14.1 makes English the only fallback")
	assert_eq((properties.get("entry_count", {}) as Dictionary).get("const"), EXPECTED_ENTRY_COUNT,
		"entry_count is pinned in the schema as well as cross-checked in code")
	var locales: Dictionary = properties.get("locales", {})
	assert_eq(locales.get("minItems"), 1, "the declared locale list has a floor")
	assert_eq(locales.get("uniqueItems"), true, "the declared locale list is a set")
	assert_eq((locales.get("items", {}) as Dictionary).get("enum"), ["en"],
		"the declared locale vocabulary is closed at English")
	var entries: Dictionary = properties.get("entries", {})
	var items: Dictionary = entries.get("items", {})
	var record_required: Array = items.get("required", [])
	record_required.sort()
	assert_eq(record_required, RECORD_KEYS, "the schema requires exactly the twelve record keys")
	assert_eq(items.get("additionalProperties"), false, "the record level is closed")
	assert_eq((record.get("content_version", {}) as Dictionary).get("const"), 1,
		"content_version is pinned")
	assert_eq((record.get("allowed_signals", {}) as Dictionary).get("uniqueItems"), true,
		"the schema owns duplicate detection for allowed_signals, so no code law duplicates it")
	assert_eq((record.get("allowed_ending_forms", {}) as Dictionary).get("uniqueItems"), true,
		"the schema owns duplicate detection for allowed_ending_forms")
	var locators: Dictionary = record.get("locators", {})
	assert_eq(locators.get("required"), ["en"], "every record must carry an English locator")
	assert_eq(locators.get("additionalProperties"), false, "locators is closed at English")
	var visual: Dictionary = record.get("visual_ids", {})
	assert_eq(visual.get("additionalProperties"), false, "visual_ids is closed")
	var visual_properties: Dictionary = visual.get("properties", {})
	for half: String in VISUAL_KEYS:
		assert_eq((visual_properties.get(half, {}) as Dictionary).get("uniqueItems"), true,
			"%s: the visual id list is a set" % half)


## Plan Task 2 requires the schema to reject empty identifiers. minLength 1 sits at eight sites and
## none of them had executable proof, so deleting any one was silent.
const EMPTY_IDENTIFIER_SITES := [
	"entry_id", "context_schema_id", "line_namespace", "atom_namespace",
	"locator_path", "locator_label", "visual_required", "visual_optional",
]


func test_the_schema_rejects_every_empty_identifier() -> void:
	var schema := _parse(SCHEMA_PATH)
	var document := _document()
	if schema.is_empty() or document.is_empty():
		assert_false(schema.is_empty(), "expected RED: schema absent or unparseable")
		assert_false(document.is_empty(), "expected RED: manifest absent or unparseable")
		return
	for site: String in EMPTY_IDENTIFIER_SITES:
		var mutated: Dictionary = document.duplicate(true)
		var record: Dictionary = (mutated["entries"] as Array)[0]
		match site:
			"entry_id", "context_schema_id", "line_namespace", "atom_namespace":
				record[site] = ""
			"locator_path":
				((record["locators"] as Dictionary)["en"] as Dictionary)["path"] = ""
			"locator_label":
				((record["locators"] as Dictionary)["en"] as Dictionary)["label"] = ""
			"visual_required":
				(record["visual_ids"] as Dictionary)["required"] = [""]
			"visual_optional":
				(record["visual_ids"] as Dictionary)["optional"] = [""]
		assert_false(JsonSchemaValidator.validate(mutated, schema).get("ok", true),
			"%s: an empty identifier is rejected by the published schema" % site)


func test_every_declared_failure_code_exists_in_the_production_source() -> void:
	assert_true(FileAccess.file_exists(SCRIPT_PATH), "expected RED: missing " + SCRIPT_PATH)
	if not FileAccess.file_exists(SCRIPT_PATH):
		return
	var source := FileAccess.get_file_as_string(SCRIPT_PATH)
	for code: StringName in ALL_FAILURE_CODES:
		assert_true(source.contains("&\"" + str(code) + "\""),
			"%s: the production source still declares this exact failure code" % str(code))


# --------------------------------------------------------------------------------------------
# resolve_entry with a real selected-locale locator, built in memory.
# --------------------------------------------------------------------------------------------

func _with_selected_locale(entry_id: String, path: String, label: String) -> Dictionary:
	var mutated: Dictionary = _document().duplicate(true)
	for record: Dictionary in (mutated["entries"] as Array):
		if str(record.get("entry_id", "")) == entry_id:
			(record["locators"] as Dictionary)["zh"] = {"label": label, "path": path}
			break
	return mutated


func test_resolve_entry_returns_a_selected_locale_locator_that_validates() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var entry_id: String = ORDINARY_ENTRIES[0]
	var document := _with_selected_locale(entry_id, CHINESE_MASTER, entry_id)
	var result: Dictionary = script.call(&"resolve_entry", document, entry_id, "zh")
	assert_true(result.get("ok", false),
		"a selected locale that validates resolves: " + str(result.get("message", "")))
	if not result.get("ok", false):
		return
	var value: Dictionary = result["value"]
	assert_eq(value.get("locale"), "zh", "the selected locale is used, not English")
	assert_eq(value.get("requested_locale"), "zh", "and it is reported as the requested one")
	assert_eq(value.get("used_fallback"), false, "a locale that validates is not a fallback")
	assert_eq(value.get("path"), CHINESE_MASTER, "its own master")
	assert_eq(value.get("label"), entry_id, "the exact same semantic label")
	assert_eq(value.get("entry_id"), entry_id, "the exact same semantic entry")


func test_resolve_entry_refuses_a_selected_locale_locator_that_does_not_validate() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var entry_id: String = ORDINARY_ENTRIES[0]
	var rows: Array = [
		["a label that is not the entry", CHINESE_MASTER, "daily_message"],
		["a path outside res://", "user://dialogic/timelines/zh/day_1.dtl", entry_id],
		["an absolute OS path", "C:/dwm/dialogic/timelines/zh/day_1.dtl", entry_id],
	]
	for row: Array in rows:
		var why: String = str(row[0])
		var document := _with_selected_locale(entry_id, str(row[1]), str(row[2]))
		var result: Dictionary = script.call(&"resolve_entry", document, entry_id, "zh")
		assert_true(result.get("ok", false), "%s: it falls back rather than failing" % why)
		if not result.get("ok", false):
			continue
		var value: Dictionary = result["value"]
		assert_eq(value.get("used_fallback"), true, "%s: the fallback is reported" % why)
		assert_eq(value.get("locale"), "en", "%s: fallback language is English" % why)
		assert_eq(value.get("path"), ENGLISH_DAY_ONE_MASTER, "%s: never a wrong master" % why)
		assert_eq(value.get("label"), entry_id, "%s: never a wrong label" % why)


func test_resolve_entry_refuses_a_malformed_english_locator() -> void:
	if not _guard():
		return
	var script := _manifest_script()
	var entry_id: String = ORDINARY_ENTRIES[0]
	var rows: Array = [
		["a label that is not the entry", ENGLISH_DAY_ONE_MASTER, "daily_message"],
		["a path outside res://", "user://dialogic/timelines/en/day_1.dtl", entry_id],
		["an absolute OS path", "C:/dwm/dialogic/timelines/en/day_1.dtl", entry_id],
	]
	for row: Array in rows:
		var mutated: Dictionary = _document().duplicate(true)
		for record: Dictionary in (mutated["entries"] as Array):
			if str(record.get("entry_id", "")) == entry_id:
				(record["locators"] as Dictionary)["en"] = {
					"label": str(row[2]), "path": str(row[1]),
				}
				break
		var result: Dictionary = script.call(&"resolve_entry", mutated, entry_id, "zh")
		assert_false(result.get("ok", true),
			"%s: 14.1 starts nothing rather than falling back to a wrong label" % str(row[0]))
		assert_eq(result.get("code"), CODE_ENGLISH_LOCATOR_MISSING,
			"%s: with its own named code" % str(row[0]))
