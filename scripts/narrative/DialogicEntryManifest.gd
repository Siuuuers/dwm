class_name DialogicEntryManifest
extends RefCounted
## Closed semantic entry contract (Seven-Day Flow Plan 01 Task 2, sub-commit 2A, dwm-oyo.2).
##
## data/manifests/dialogic_entries.json registers all 139 externally callable entries: the 121 day
## entries of specification sections 13.1 through 13.7 and the 18 ending presentation entries the
## 13.8 table expands to. The manifest is closed. An unknown suffix never resolves through
## permissive pattern parsing, and resolve_entry fails by name rather than guessing a neighbour.
##
## WHY SOME LAWS LIVE HERE AND NOT IN THE SCHEMA (dwm-oyo.2 DEVIATION-3 Ruling 3).
## scripts/validation/JsonSchemaValidator.gd implements exactly ten keywords - type, const, enum,
## required, properties, additionalProperties, items, minItems, minLength, uniqueItems - and
## silently ignores every other keyword, pattern and oneOf included. So four of the laws Task 2
## demands cannot be written into schemas/manifests/dialogic-entries.schema.json at all:
##
##   ENTRY_MANIFEST_DUPLICATE_LOCATOR_PAIR   two entries naming one physical {path,label}
##   ENTRY_MANIFEST_ABSOLUTE_OS_PATH         a locator escaping the resource sandbox
##   ENTRY_MANIFEST_NON_RES_PATH             a locator that is not a shipped res:// master
##   ENTRY_MANIFEST_LABEL_ENTRY_MISMATCH     a label unequal to its registered semantic entry
##
## tests/unit/test_dialogic_entry_manifest.gd proves, executably, that the published schema alone
## accepts all four. Do not delete any of them believing the schema still covers it. The converse
## also holds: locale closure and every closed vocabulary live in the schema alone, because enum
## and additionalProperties really are enforced, and restating them here would create a law no
## mutation could reach.
##
## BINDING ON SUB-COMMIT 2B: atom_namespace IS A DECLARED HOME, NOT A STRING PREFIX. The plan's
## own mandated atom ids nest under NEITHER owning entry - atom.echo.lavinia.day1.reply.a.fallback
## .day7 belongs to contact.ordinary.lavinia.day1, and atom.pair.day2.group.full belongs to
## dating.group.priscilla_lavinia.day2.post_challenge. Specification 12.6 says an atom record
## declares "kind, owning entry/stage, and optional associated line ID", so ownership is DECLARED,
## and 12.2 asks only that the line and atom namespaces be "compatible". validate_atom_id MUST
## resolve ownership from the atom record's declared owning entry and MUST NEVER require the atom id
## to carry atom_namespace as a string prefix; requiring one would reject every atom id the plan
## mandates. The ENTRY_MANIFEST_NAMESPACE_MISMATCH law below constrains only the FIELD on this
## record - that the declared home is derived from the stable entry id rather than from a path -
## and grants no licence to derive membership from string shape.
##
## KNOWN UNTESTED PATHS, recorded rather than hidden. The backslash branch of
## _is_absolute_os_path, the per-record ENTRY_MANIFEST_DOCUMENT_SHAPE branch, fingerprint's
## empty-string return, and the three load-time codes ENTRY_MANIFEST_FILE_MISSING,
## ENTRY_MANIFEST_PARSE_FAILED and ENTRY_MANIFEST_SCHEMA_MISSING need filesystem manipulation or a
## malformed Variant to reach, and are KNOWINGLY UNCOVERED by the sub-commit 2A suite. The suite
## does pin their spelling by reading this file as text, so a rename cannot pass unnoticed.
## _check_allowlist takes a typed Array and relies on the schema having already proved the type;
## that reliance is the reason its old type guard was removed rather than kept as a dead law.
##
## TWO LAYERINGS MEASURED IN THE SUB-COMMIT 2A MUTATION CAMPAIGN, both deliberate. Disabling the
## duplicate-locator-pair law (site G01) still rejects the same document, but as
## ENTRY_MANIFEST_LABEL_ENTRY_MISMATCH; disabling the absolute-OS-path law (site G02) still rejects
## its document, but as ENTRY_MANIFEST_NON_RES_PATH. Neither outer law is therefore redundant: it
## is what turns a vague rejection into the specific one a caller can act on, and the suite asserts
## the exact code, so removing either half is caught.
##
## LAW ORDER IS LOAD BEARING. Two entries can only share a locator pair by also breaking
## label-equals-entry on one of them, so the pair check runs first; a label mismatch on its own
## leaves the pair unique, so both laws stay independently reachable. For the same reason the
## duplicate entry_id check precedes the label check, and the duplicate context_schema_id check
## precedes the convention check. Reordering these silently collapses two laws into one.
##
## FALLBACK LAW (specification 14.1). A missing selected-locale locator falls back only to the
## exact same semantic label in English. A missing or duplicated English locator is a FAILURE, not
## a fallback: it starts nothing and preserves the pending event. Fallback may change language
## only, never day, route, friend, entry, ending or consequence, which holds structurally here
## because the fallback is read from the same record.
##
## SUB-COMMIT 2B adds load_ids_default, validate_ids_document, validate_signal, validate_line_id
## and validate_atom_id over data/manifests/dialogic_ids.json, and gives resolve_entry one distinct
## code for a retired label. Its own header, further down this file, states those laws, the order
## they run in and what they deliberately do not promise.

const MANIFEST_PATH := "res://data/manifests/dialogic_entries.json"
const SCHEMA_PATH := "res://schemas/manifests/dialogic-entries.schema.json"

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const RESOURCE_SCHEME := "res://"
const FIRST_DAY := 1
const LAST_DAY := 7
const LINE_PREFIX := "line."
const ATOM_PREFIX := "atom."
const CONTEXT_PREFIX := "context."
const CONTEXT_SUFFIX := ".v1"
const WITNESS_SIGNAL := "history.line.witness"


# --------------------------------------------------------------------------------------------
# Sub-commit 2B: the exact ID registries.
# --------------------------------------------------------------------------------------------

## Sub-commit 2B: load_ids_default, validate_ids_document, validate_signal, validate_line_id and
## validate_atom_id, over data/manifests/dialogic_ids.json.
##
## HOW THE TWO DOCUMENTS RELATE. The `document` parameter of validate_signal, validate_line_id and
## validate_atom_id is the ENTRIES document, uniformly with validate_document and resolve_entry, so
## a caller that already holds one manifest never has to hold two. The ids registry is read from
## disk by _load_ids_registry, mirroring _load_schema. validate_ids_document is the one public entry
## point that takes the ids document EXPLICITLY, so every named IDS_MANIFEST_ failure code is
## reachable from a fixture and can be killed individually in a mutation campaign.
##
## THE SCHEMA/CODE SPLIT, again (DEVIATION-3 Ruling 3). schemas/manifests/dialogic-ids.schema.json
## owns every closed vocabulary and every record shape, because enum, additionalProperties, minItems,
## minLength and uniqueItems really are enforced. The laws below are exactly the ones no implemented
## keyword can express, and none of them restates the schema:
##
##   IDS_MANIFEST_BLOCK_SHAPE                a registry block that is not an array of records
##   IDS_MANIFEST_COUNT_MISMATCH             a declared count that disagrees with its collection
##   IDS_MANIFEST_DUPLICATE_ID               one id registered twice inside a block
##   IDS_MANIFEST_UNKNOWN_OWNING_ENTRY       a declared owner absent from the 2A entries manifest
##   IDS_MANIFEST_UNKNOWN_PRESENTATION_ENTRY a declared presentation site absent from it
##   IDS_MANIFEST_ATOM_PARTITION_INVALID     an echo atom without an echo id, or a pair atom with one
##   IDS_MANIFEST_ECHO_BINDING_INVALID       an echo id that is not Ruling G's derivation
##   IDS_MANIFEST_ASSOCIATED_LINE_INVALID    an associated line id that is not a registered line
##   IDS_MANIFEST_SIGNAL_PAYLOAD_INVALID     a payload list missing its envelope or stored unsorted
##   IDS_MANIFEST_SIGNAL_STAGE_INVALID       a source stage outside this document's own vocabulary
##   IDS_MANIFEST_RETIRED_ID_INVALID         a retired label that restores, or that is also callable
##   IDS_MANIFEST_PAIR_WITNESS_MISMATCH      the pair.combination.witness / pair atom iff law
##   IDS_MANIFEST_ORDINARY_TRIPLE_MISMATCH   three replies, three lines, three atoms apiece
##
## LAW ORDER IS LOAD BEARING HERE TOO. Block shape runs before the schema so a non-array block is
## named rather than reported as a bare type error. Counts run before duplicates, because appending
## a duplicate record breaks both; the duplicate law stays independently reachable by appending a
## duplicate AND raising the declared count to match. Duplicates in turn run before the two tally
## laws, because a duplicated atom also breaks the three-apiece tally. The atom partition check runs
## before the echo derivation, so a null echo id on an echo atom is named as a partition break rather
## than as a failed derivation. Reordering any of these silently collapses two laws into one.
##
## RULING B, RESTATED WHERE IT IS IMPLEMENTED. validate_atom_id resolves ownership from the atom
## record's declared owning_entry_id and its declared presented_in_entry_ids. It NEVER requires the
## atom id to carry the owning entry's atom_namespace as a string prefix, because not one of the 22
## atom ids the plan mandates does: atom.echo.lavinia.day1.reply.a.fallback.day7 belongs to
## contact.ordinary.lavinia.day1, whose atom_namespace is atom.contact.ordinary.lavinia.day1. The
## same holds for validate_line_id under DEVIATION-4 Ruling E: specification 12.6 forbids deriving a
## line id from path, line number, translated text or label position, and a namespace prefix is the
## same kind of derivation. The suite measures the prefix relation separately and labels that
## measurement a CHANGE DETECTOR rather than a proof.
##
## RULING C, AND WHAT THE SUCCESS VALUE REPORTS. An atom resolves at the entry that OWNS it or at an
## entry that PRESENTS it, and the success value's `match` field says which, so a caller can tell a
## Day-7 fallback presentation from an ordinary-entry ownership claim. The owner is tested first, so
## the four pair atoms, whose owner and only presentation site are the same entry, report "owner".
##
## WHAT validate_signal DOES NOT PROMISE. Four payload fields have no registry in this phase.
## playback_token is minted per entry by the bridge and receipt_id per command by the state owner,
## so specification 12.8 gives neither any vocabulary at all; evidence_id and combination_id await
## the approved content card the plan defers Observer evidence and pair combinations to. All four are
## constrained to a non-empty string and to nothing stronger. That is deliberately weaker than a
## registry lookup and is written down here rather than dressed up as a closed law.
##
## observer.evidence.commit IS REGISTERED AND UNGRANTABLE. The plan holds production Observer
## evidence capabilities absent until an approved content card supplies an exact source entry and
## atom, and no entry in the 2A manifest lists the signal, so every emission is refused as
## SIGNAL_NOT_GRANTED. The registry still carries its payload row, because 12.8 declares it.
##
## THE ONE 2A BEHAVIOUR CHANGE. resolve_entry now consults the retired-id block before reporting
## ENTRY_MANIFEST_UNKNOWN_ENTRY, so a legacy ending.<friend>.true label arriving from an old save is
## refused as ENTRY_MANIFEST_RETIRED_ENTRY, by name, rather than as an anonymous stranger. It is
## additive over exactly three strings; every other entry id reaches the same code it did before.
## When the ids registry is unreadable the check falls through to the old code, so a missing registry
## degrades a diagnostic rather than changing which ids resolve.
##
## KNOWN UNTESTED PATHS ADDED BY THIS SUB-COMMIT, recorded rather than hidden.
## IDS_MANIFEST_FILE_MISSING, IDS_MANIFEST_PARSE_FAILED, IDS_MANIFEST_SCHEMA_MISSING and
## IDS_MANIFEST_ENTRIES_UNAVAILABLE all need a file to be absent or corrupt on disk, which the suite
## does not do; the false branch of _is_retired_label's reject_on_restore guard needs a registry
## validate_ids_document already forbids; and the evidence_id half of the opaque-field guard cannot
## be reached at all while no entry grants observer.evidence.commit. All are KNOWINGLY UNCOVERED and
## their spellings are pinned by the suite reading this file as text.

const IDS_MANIFEST_PATH := "res://data/manifests/dialogic_ids.json"
const IDS_SCHEMA_PATH := "res://schemas/manifests/dialogic-ids.schema.json"

const FALLBACK_SUFFIX := ".fallback.day7"
const ECHO_FALLBACK_KIND := "echo_fallback"
const PAIR_OBSERVATION_KIND := "pair_full_observation"
const REPLY_SIGNAL := "message.reply.commit"
const PAIR_WITNESS_SIGNAL := "pair.combination.witness"
const REPLIES_PER_ORDINARY_ENTRY := 3

## Each declared count beside the collection it counts.
const REGISTRY_COUNTS := [
	["atom_count", "atoms"],
	["ending_form_count", "ending_form_union"],
	["ending_id_count", "ending_ids"],
	["reply_id_count", "reply_ids"],
	["reply_line_count", "reply_lines"],
	["retired_id_count", "retired_ids"],
	["signal_count", "signals"],
	["source_stage_count", "source_stages"],
]

## Each block of records beside the field that identifies one.
const REGISTRY_RECORDS := [
	["atoms", "atom_id"],
	["reply_ids", "reply_id"],
	["reply_lines", "line_id"],
	["retired_ids", "label_id"],
	["signals", "signal_id"],
]

## Every block whose records declare an owning entry.
const OWNED_BLOCKS := ["atoms", "reply_ids", "reply_lines"]

## Specification 12.4 makes the playback token mandatory and 12.5 makes every command an idempotent
## receipt, so no registered payload may drop either; 12.8 prints entry_id on all five rows.
const PAYLOAD_ENVELOPE := ["entry_id", "playback_token", "receipt_id"]

## The four payload fields with no registry in this phase. See the header.
const OPAQUE_PAYLOAD_FIELDS := ["combination_id", "evidence_id", "playback_token", "receipt_id"]


static func load_default() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _fail(&"ENTRY_MANIFEST_FILE_MISSING", MANIFEST_PATH + " is absent")
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed.get("ok", false):
		return _fail(&"ENTRY_MANIFEST_PARSE_FAILED",
			"%s: %s" % [MANIFEST_PATH, str(parsed.get("message", ""))])
	return {"ok": true, "value": parsed["value"]}


static func validate_document(document: Dictionary) -> Dictionary:
	var entries: Variant = document.get("entries")
	if not (entries is Array):
		return _fail(&"ENTRY_MANIFEST_DOCUMENT_SHAPE", "the document declares no entries array")
	var records: Array = entries
	for candidate: Variant in records:
		if not (candidate is Dictionary):
			return _fail(&"ENTRY_MANIFEST_DOCUMENT_SHAPE", "every entry record is an object")

	var schema := _load_schema()
	if not schema.get("ok", false):
		return schema
	var schema_result: Dictionary = JsonSchemaValidator.validate(document, schema["value"])
	if not schema_result.get("ok", false):
		return _fail(&"ENTRY_MANIFEST_SCHEMA_INVALID",
			"the published schema rejected the document: " + str(schema_result.get("message", "")))

	if int(document.get("entry_count", -1)) != records.size():
		return _fail(&"ENTRY_MANIFEST_ENTRY_COUNT_MISMATCH",
			"entry_count %s does not equal the %d records present"
			% [str(document.get("entry_count")), records.size()])

	var seen_entry_ids: Dictionary = {}
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		if seen_entry_ids.has(entry_id):
			return _fail(&"ENTRY_MANIFEST_DUPLICATE_ENTRY_ID",
				"%s is registered more than once" % entry_id)
		seen_entry_ids[entry_id] = true
		for locale: Variant in _locators(record):
			var path: String = str(_locator(record, str(locale)).get("path", ""))
			if _is_absolute_os_path(path):
				return _fail(&"ENTRY_MANIFEST_ABSOLUTE_OS_PATH",
					"%s: the %s locator names an absolute OS path: %s"
					% [entry_id, str(locale), path])
			if not path.begins_with(RESOURCE_SCHEME):
				return _fail(&"ENTRY_MANIFEST_NON_RES_PATH",
					"%s: the %s locator is not a res:// master: %s" % [entry_id, str(locale), path])

	var seen_pairs: Dictionary = {}
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		for locale: Variant in _locators(record):
			var locator := _locator(record, str(locale))
			var key: String = "%s|%s|%s" % [
				str(locale), str(locator.get("path", "")), str(locator.get("label", "")),
			]
			if seen_pairs.has(key):
				return _fail(&"ENTRY_MANIFEST_DUPLICATE_LOCATOR_PAIR",
					"%s: the locator %s is already owned by %s"
					% [entry_id, key, str(seen_pairs[key])])
			seen_pairs[key] = entry_id

	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		for locale: Variant in _locators(record):
			var label: String = str(_locator(record, str(locale)).get("label", ""))
			if label != entry_id:
				return _fail(&"ENTRY_MANIFEST_LABEL_ENTRY_MISMATCH",
					"%s: the %s label is %s, which is not its registered semantic entry"
					% [entry_id, str(locale), label])

	var seen_context_ids: Dictionary = {}
	var day_entries := 0
	var ending_entries := 0
	for record: Dictionary in records:
		var entry_id: String = str(record.get("entry_id", ""))
		var day: Variant = record.get("day")
		var ending_id: Variant = record.get("ending_id")
		var presents_ending: bool = ending_id != null
		if presents_ending:
			ending_entries += 1
			if day != null:
				return _fail(&"ENTRY_MANIFEST_ENDING_PARTITION_INVALID",
					"%s: an ending entry owns the ending layer, never a day master" % entry_id)
			if typeof(ending_id) != TYPE_STRING or str(ending_id).is_empty():
				return _fail(&"ENTRY_MANIFEST_ENDING_PARTITION_INVALID",
					"%s: ending_id is a non-empty stable identity" % entry_id)
		else:
			day_entries += 1
			if typeof(day) != TYPE_INT or int(day) < FIRST_DAY or int(day) > LAST_DAY:
				return _fail(&"ENTRY_MANIFEST_ENDING_PARTITION_INVALID",
					"%s: a day entry owns one of the seven day masters, not %s"
					% [entry_id, str(day)])
		var forms: Variant = record.get("allowed_ending_forms", [])
		var declares_form: bool = forms is Array and not (forms as Array).is_empty()
		if declares_form != presents_ending:
			return _fail(&"ENTRY_MANIFEST_ENDING_FORMS_INVALID",
				"%s: exactly the entries that present an ending identity declare a playback form"
				% entry_id)
		if str(record.get("line_namespace", "")) != LINE_PREFIX + entry_id:
			return _fail(&"ENTRY_MANIFEST_NAMESPACE_MISMATCH",
				"%s: line_namespace is derived from the stable entry, never from a path" % entry_id)
		if str(record.get("atom_namespace", "")) != ATOM_PREFIX + entry_id:
			return _fail(&"ENTRY_MANIFEST_NAMESPACE_MISMATCH",
				"%s: atom_namespace is derived from the stable entry, never from a path" % entry_id)
		var context_id: String = str(record.get("context_schema_id", ""))
		if seen_context_ids.has(context_id):
			return _fail(&"ENTRY_MANIFEST_DUPLICATE_CONTEXT_SCHEMA_ID",
				"%s: the frozen context schema %s is already owned by %s"
				% [entry_id, context_id, str(seen_context_ids[context_id])])
		seen_context_ids[context_id] = entry_id
		var expected_context: String = (CONTEXT_PREFIX + str(record.get("role", "")) + "."
			+ entry_id + CONTEXT_SUFFIX)
		if context_id != expected_context:
			return _fail(&"ENTRY_MANIFEST_CONTEXT_SCHEMA_ID_MISMATCH",
				"%s: context_schema_id is %s but the convention requires %s"
				% [entry_id, context_id, expected_context])
		var allowlist := _check_allowlist(entry_id, record.get("allowed_signals", []))
		if not allowlist.get("ok", false):
			return allowlist

	if int(document.get("day_entry_count", -1)) != day_entries:
		return _fail(&"ENTRY_MANIFEST_ENTRY_COUNT_MISMATCH",
			"day_entry_count %s does not equal the %d records that own a day"
			% [str(document.get("day_entry_count")), day_entries])
	if int(document.get("ending_entry_count", -1)) != ending_entries:
		return _fail(&"ENTRY_MANIFEST_ENTRY_COUNT_MISMATCH",
			"ending_entry_count %s does not equal the %d records that own no day"
			% [str(document.get("ending_entry_count")), ending_entries])
	return {"ok": true, "value": document}


static func resolve_entry(document: Dictionary, entry_id: String, locale: String) -> Dictionary:
	var entries: Variant = document.get("entries")
	if not (entries is Array):
		return _fail(&"ENTRY_MANIFEST_DOCUMENT_SHAPE", "the document declares no entries array")
	var records: Array = entries
	var default_locale: String = str(document.get("default_locale", "en"))
	var record: Dictionary = {}
	for candidate: Variant in records:
		if candidate is Dictionary and str((candidate as Dictionary).get("entry_id", "")) == entry_id:
			record = candidate as Dictionary
			break
	if record.is_empty():
		if _is_retired_label(entry_id):
			return _fail(&"ENTRY_MANIFEST_RETIRED_ENTRY",
				"%s was retired by the 61-to-8 migration, so a save that still carries it is refused"
				% entry_id)
		return _fail(&"ENTRY_MANIFEST_UNKNOWN_ENTRY",
			"%s is not a registered semantic entry" % entry_id)

	var english := _locator(record, default_locale)
	if not _locator_is_usable(english, entry_id):
		return _fail(&"ENTRY_MANIFEST_ENGLISH_LOCATOR_MISSING",
			"%s: no usable %s locator, so nothing starts and the event stays pending"
			% [entry_id, default_locale])
	var owners := 0
	for candidate: Variant in records:
		if not (candidate is Dictionary):
			continue
		var other := _locator(candidate as Dictionary, default_locale)
		if (str(other.get("path", "")) == str(english.get("path", ""))
				and str(other.get("label", "")) == str(english.get("label", ""))):
			owners += 1
	if owners != 1:
		return _fail(&"ENTRY_MANIFEST_ENGLISH_LOCATOR_AMBIGUOUS",
			"%s: %d entries claim the same English path and label" % [entry_id, owners])

	if locale == default_locale:
		return _resolved(entry_id, default_locale, locale, english, false)
	var selected := _locator(record, locale)
	if _locator_is_usable(selected, entry_id):
		return _resolved(entry_id, locale, locale, selected, false)
	return _resolved(entry_id, default_locale, locale, english, true)


## The SHA-256 of the document's canonical serialization. Empty only when the document cannot be
## canonicalized at all, which CanonicalJsonWriter reports for a non-JSON Variant.
static func fingerprint(document: Dictionary) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(document)
	if not emitted.get("ok", false):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(str(emitted["value"]).to_utf8_buffer())
	return "sha256:" + context.finish().hex_encode()


static func _load_schema() -> Dictionary:
	if not FileAccess.file_exists(SCHEMA_PATH):
		return _fail(&"ENTRY_MANIFEST_SCHEMA_MISSING", SCHEMA_PATH + " is absent")
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(SCHEMA_PATH))
	if not parsed.get("ok", false):
		return _fail(&"ENTRY_MANIFEST_SCHEMA_MISSING",
			"%s: %s" % [SCHEMA_PATH, str(parsed.get("message", ""))])
	return {"ok": true, "value": parsed["value"]}


## Only the two laws the published schema cannot express live here. The schema already declares
## allowed_signals as an array with uniqueItems, and validate_document runs it first, so a type
## guard and a duplicate scan in this function would be laws no mutation could reach - exactly what
## the header warns against. They were present in the first revision of this file and are removed.
static func _check_allowlist(entry_id: String, signal_ids: Array) -> Dictionary:
	if not signal_ids.has(WITNESS_SIGNAL):
		return _fail(&"ENTRY_MANIFEST_SIGNAL_LIST_INVALID",
			"%s: every entry may witness a manifest-owned line in the current entry" % entry_id)
	var sorted_ids: Array = signal_ids.duplicate()
	sorted_ids.sort()
	for index in range(signal_ids.size()):
		if str(sorted_ids[index]) != str(signal_ids[index]):
			return _fail(&"ENTRY_MANIFEST_SIGNAL_LIST_INVALID",
				"%s: allowed_signals is stored sorted, so equal capabilities cannot differ in bytes"
				% entry_id)
	return {"ok": true, "value": signal_ids}


static func _locators(record: Dictionary) -> Dictionary:
	var value: Variant = record.get("locators", {})
	return value if value is Dictionary else {}


static func _locator(record: Dictionary, locale: String) -> Dictionary:
	var value: Variant = _locators(record).get(locale, {})
	return value if value is Dictionary else {}


static func _locator_is_usable(locator: Dictionary, entry_id: String) -> bool:
	if locator.is_empty():
		return false
	var path: String = str(locator.get("path", ""))
	if path.is_empty() or _is_absolute_os_path(path) or not path.begins_with(RESOURCE_SCHEME):
		return false
	return str(locator.get("label", "")) == entry_id


## A drive-letter prefix or a leading separator means the locator has left the resource sandbox.
## res:// and user:// both carry a non-colon second character, so neither is misread as a drive.
static func _is_absolute_os_path(path: String) -> bool:
	if path.begins_with("/") or path.begins_with("\\"):
		return true
	if path.length() < 2 or path[1] != ":":
		return false
	var drive: String = path[0].to_lower()
	return drive >= "a" and drive <= "z"


static func _resolved(entry_id: String, locale: String, requested_locale: String,
		locator: Dictionary, used_fallback: bool) -> Dictionary:
	return {
		"ok": true,
		"value": {
			"entry_id": entry_id,
			"locale": locale,
			"requested_locale": requested_locale,
			"path": str(locator.get("path", "")),
			"label": str(locator.get("label", "")),
			"used_fallback": used_fallback,
		},
	}


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


static func load_ids_default() -> Dictionary:
	if not FileAccess.file_exists(IDS_MANIFEST_PATH):
		return _fail(&"IDS_MANIFEST_FILE_MISSING", IDS_MANIFEST_PATH + " is absent")
	var parsed: Dictionary = STRICT_JSON.parse_object(
		FileAccess.get_file_as_string(IDS_MANIFEST_PATH))
	if not parsed.get("ok", false):
		return _fail(&"IDS_MANIFEST_PARSE_FAILED",
			"%s: %s" % [IDS_MANIFEST_PATH, str(parsed.get("message", ""))])
	return {"ok": true, "value": parsed["value"]}


## The registry document, taken explicitly so every law below is reachable from a fixture.
static func validate_ids_document(ids_document: Dictionary) -> Dictionary:
	for pair: Array in REGISTRY_COUNTS:
		if not ids_document.has(str(pair[1])):
			return _fail(&"IDS_MANIFEST_DOCUMENT_SHAPE",
				"the document declares no %s block" % str(pair[1]))
		if not (ids_document[str(pair[1])] is Array):
			return _fail(&"IDS_MANIFEST_BLOCK_SHAPE",
				"%s is a registry block and must be an array" % str(pair[1]))
	for pair: Array in REGISTRY_RECORDS:
		for candidate: Variant in _registry_block(ids_document, str(pair[0])):
			if not (candidate is Dictionary):
				return _fail(&"IDS_MANIFEST_BLOCK_SHAPE",
					"every %s record is an object" % str(pair[0]))

	var schema := _load_ids_schema()
	if not schema.get("ok", false):
		return schema
	var schema_result: Dictionary = JsonSchemaValidator.validate(ids_document, schema["value"])
	if not schema_result.get("ok", false):
		return _fail(&"IDS_MANIFEST_SCHEMA_INVALID",
			"the published schema rejected the registry: " + str(schema_result.get("message", "")))

	for pair: Array in REGISTRY_COUNTS:
		var declared: int = int(ids_document.get(str(pair[0]), -1))
		var present: int = _registry_block(ids_document, str(pair[1])).size()
		if declared != present:
			return _fail(&"IDS_MANIFEST_COUNT_MISMATCH",
				"%s declares %d but %s holds %d records"
				% [str(pair[0]), declared, str(pair[1]), present])

	for pair: Array in REGISTRY_RECORDS:
		var seen: Dictionary = {}
		for record: Dictionary in _registry_block(ids_document, str(pair[0])):
			var id_value: String = str(record.get(str(pair[1]), ""))
			if seen.has(id_value):
				return _fail(&"IDS_MANIFEST_DUPLICATE_ID",
					"%s: %s is registered more than once" % [str(pair[0]), id_value])
			seen[id_value] = true

	var entries := load_default()
	if not entries.get("ok", false):
		return _fail(&"IDS_MANIFEST_ENTRIES_UNAVAILABLE",
			"the entry manifest this registry is measured against is unreadable: "
			+ str(entries.get("message", "")))
	var known := _entry_index(entries["value"])

	for block_name: String in OWNED_BLOCKS:
		for record: Dictionary in _registry_block(ids_document, block_name):
			var owner: String = str(record.get("owning_entry_id", ""))
			if not known.has(owner):
				return _fail(&"IDS_MANIFEST_UNKNOWN_OWNING_ENTRY",
					"%s: %s is not a registered semantic entry" % [block_name, owner])
	for record: Dictionary in _registry_block(ids_document, "atoms"):
		for site: Variant in _string_array(record, "presented_in_entry_ids"):
			if not known.has(str(site)):
				return _fail(&"IDS_MANIFEST_UNKNOWN_PRESENTATION_ENTRY",
					"%s: %s presents nothing because it is not a registered entry"
					% [str(record.get("atom_id", "")), str(site)])

	var registered_lines: Dictionary = {}
	for record: Dictionary in _registry_block(ids_document, "reply_lines"):
		registered_lines[str(record.get("line_id", ""))] = str(record.get("owning_entry_id", ""))

	for record: Dictionary in _registry_block(ids_document, "atoms"):
		var atom_id: String = str(record.get("atom_id", ""))
		var kind: String = str(record.get("kind", ""))
		var echo_id: Variant = record.get("echo_id")
		if kind == ECHO_FALLBACK_KIND:
			if typeof(echo_id) != TYPE_STRING or str(echo_id).is_empty():
				return _fail(&"IDS_MANIFEST_ATOM_PARTITION_INVALID",
					"%s: an %s atom binds one echo id" % [atom_id, ECHO_FALLBACK_KIND])
			var derived: String = atom_id.trim_prefix(ATOM_PREFIX).trim_suffix(FALLBACK_SUFFIX)
			if derived == atom_id or str(echo_id) != derived:
				return _fail(&"IDS_MANIFEST_ECHO_BINDING_INVALID",
					"%s: the echo id is derived from this atom id, so it must be %s, not %s"
					% [atom_id, derived, str(echo_id)])
		elif echo_id != null:
			return _fail(&"IDS_MANIFEST_ATOM_PARTITION_INVALID",
				"%s: a %s atom binds no echo id" % [atom_id, PAIR_OBSERVATION_KIND])
		var associated: Variant = record.get("associated_line_id")
		if associated != null and not registered_lines.has(str(associated)):
			return _fail(&"IDS_MANIFEST_ASSOCIATED_LINE_INVALID",
				"%s: %s is not a registered line id" % [atom_id, str(associated)])

	var stages: Array = _registry_block(ids_document, "source_stages")
	for record: Dictionary in _registry_block(ids_document, "signals"):
		var signal_id: String = str(record.get("signal_id", ""))
		var fields: Array = _string_array(record, "payload_fields")
		for required: String in PAYLOAD_ENVELOPE:
			if not fields.has(required):
				return _fail(&"IDS_MANIFEST_SIGNAL_PAYLOAD_INVALID",
					"%s: every registered payload carries %s" % [signal_id, required])
		var sorted_fields: Array = fields.duplicate()
		sorted_fields.sort()
		for index in range(fields.size()):
			if str(sorted_fields[index]) != str(fields[index]):
				return _fail(&"IDS_MANIFEST_SIGNAL_PAYLOAD_INVALID",
					"%s: payload_fields is stored sorted, so equal payloads cannot differ in bytes"
					% signal_id)
		for stage: Variant in _string_array(record, "allowed_source_stages"):
			if not stages.has(str(stage)):
				return _fail(&"IDS_MANIFEST_SIGNAL_STAGE_INVALID",
					"%s: %s is not one of this registry's declared source stages"
					% [signal_id, str(stage)])

	for record: Dictionary in _registry_block(ids_document, "retired_ids"):
		var label_id: String = str(record.get("label_id", ""))
		if record.get("reject_on_restore") != true:
			return _fail(&"IDS_MANIFEST_RETIRED_ID_INVALID",
				"%s: a registered retired label rejects a restore, it never aliases one" % label_id)
		if known.has(label_id):
			return _fail(&"IDS_MANIFEST_RETIRED_ID_INVALID",
				"%s: a retired label may not also be a callable entry" % label_id)

	var ordinary: Array = []
	for entry_id: Variant in known:
		var granted: Array = _string_array(known[str(entry_id)], "allowed_signals")
		if granted.has(REPLY_SIGNAL):
			ordinary.append(str(entry_id))
		var owned := 0
		for record: Dictionary in _registry_block(ids_document, "atoms"):
			if (str(record.get("kind", "")) == PAIR_OBSERVATION_KIND
					and str(record.get("owning_entry_id", "")) == str(entry_id)):
				owned += 1
		if granted.has(PAIR_WITNESS_SIGNAL) and owned != 1:
			return _fail(&"IDS_MANIFEST_PAIR_WITNESS_MISMATCH",
				"%s witnesses a combination, so it owns exactly one %s atom, not %d"
				% [str(entry_id), PAIR_OBSERVATION_KIND, owned])
		if not granted.has(PAIR_WITNESS_SIGNAL) and owned != 0:
			return _fail(&"IDS_MANIFEST_PAIR_WITNESS_MISMATCH",
				"%s owns %d %s atoms but may not witness a combination"
				% [str(entry_id), owned, PAIR_OBSERVATION_KIND])

	for block_name: String in OWNED_BLOCKS:
		for record: Dictionary in _registry_block(ids_document, block_name):
			if str(record.get("kind", ECHO_FALLBACK_KIND)) != ECHO_FALLBACK_KIND:
				continue
			var owner: String = str(record.get("owning_entry_id", ""))
			if not ordinary.has(owner):
				return _fail(&"IDS_MANIFEST_ORDINARY_TRIPLE_MISMATCH",
					"%s: %s owns a reply presentation but may not commit a reply"
					% [block_name, owner])
	for entry_id: Variant in ordinary:
		for block_name: String in OWNED_BLOCKS:
			var tally := 0
			for record: Dictionary in _registry_block(ids_document, block_name):
				if str(record.get("kind", ECHO_FALLBACK_KIND)) != ECHO_FALLBACK_KIND:
					continue
				if str(record.get("owning_entry_id", "")) == str(entry_id):
					tally += 1
			if tally != REPLIES_PER_ORDINARY_ENTRY:
				return _fail(&"IDS_MANIFEST_ORDINARY_TRIPLE_MISMATCH",
					"%s owns %d %s records, and an ordinary entry owns exactly %d"
					% [str(entry_id), tally, block_name, REPLIES_PER_ORDINARY_ENTRY])

	return {"ok": true, "value": ids_document}


## DEVIATION-4 Ruling E. Ownership is the record's declared owning_entry_id and NOTHING about the
## shape of line_id. A stranger that happens to sit under the owner's line_namespace is still
## refused, because membership here is registration.
static func validate_line_id(document: Dictionary, entry_id: String, line_id: String) -> Dictionary:
	var registry := load_ids_default()
	if not registry.get("ok", false):
		return registry
	if not _entry_index(document).has(entry_id):
		return _fail(&"LINE_ID_UNKNOWN_ENTRY", "%s is not a registered semantic entry" % entry_id)
	for record: Dictionary in _registry_block(registry["value"], "reply_lines"):
		if str(record.get("line_id", "")) != line_id:
			continue
		var owner: String = str(record.get("owning_entry_id", ""))
		if owner != entry_id:
			return _fail(&"LINE_ID_NOT_OWNED",
				"%s: the line is registered, but its declared home is %s" % [line_id, owner])
		return {"ok": true, "value": {"line_id": line_id, "owning_entry_id": owner}}
	return _fail(&"LINE_ID_UNREGISTERED", "%s is not a registered line id" % line_id)


## DEVIATION-4 Ruling C. An atom resolves at the entry that OWNS it or at an entry that PRESENTS it,
## and the success value's match field reports which. RULING B: nothing here reads the shape of
## atom_id, because no atom id the plan mandates nests under its owner's atom_namespace.
static func validate_atom_id(document: Dictionary, entry_id: String, atom_id: String) -> Dictionary:
	var registry := load_ids_default()
	if not registry.get("ok", false):
		return registry
	if not _entry_index(document).has(entry_id):
		return _fail(&"ATOM_ID_UNKNOWN_ENTRY", "%s is not a registered semantic entry" % entry_id)
	for record: Dictionary in _registry_block(registry["value"], "atoms"):
		if str(record.get("atom_id", "")) != atom_id:
			continue
		if str(record.get("owning_entry_id", "")) == entry_id:
			return _atom_resolved(record, "owner")
		if _string_array(record, "presented_in_entry_ids").has(entry_id):
			return _atom_resolved(record, "presentation_site")
		return _fail(&"ATOM_ID_NOT_PRESENTABLE",
			"%s: %s neither owns the atom nor is registered to present it" % [atom_id, entry_id])
	return _fail(&"ATOM_ID_UNREGISTERED", "%s is not a registered presentation atom" % atom_id)


## Specification 12.8's allowlist, composed rather than duplicated: the payload must name the same
## entry, the entry must be registered and must grant the signal, the stage must be one the signal
## allows, the payload field set must be EXACTLY the registered list, and every id it carries is
## delegated to the validator that owns it, so the caller sees that validator's own named code.
static func validate_signal(document: Dictionary, entry_id: String, stage: StringName,
		signal_id: String, payload: Dictionary) -> Dictionary:
	if str(payload.get("entry_id", "")) != entry_id:
		return _fail(&"SIGNAL_ENTRY_MISMATCH",
			"the payload names %s but the entry is %s"
			% [str(payload.get("entry_id", "")), entry_id])
	var index := _entry_index(document)
	if not index.has(entry_id):
		return _fail(&"SIGNAL_UNKNOWN_ENTRY", "%s is not a registered semantic entry" % entry_id)
	var registry := load_ids_default()
	if not registry.get("ok", false):
		return registry
	var record: Dictionary = _signal_record(registry["value"], signal_id)
	if record.is_empty():
		return _fail(&"SIGNAL_UNKNOWN_SIGNAL", "%s is not a registered signal" % signal_id)
	if not _string_array(index[entry_id], "allowed_signals").has(signal_id):
		return _fail(&"SIGNAL_NOT_GRANTED", "%s does not grant %s" % [entry_id, signal_id])
	if not _string_array(record, "allowed_source_stages").has(str(stage)):
		return _fail(&"SIGNAL_STAGE_NOT_ALLOWED",
			"%s is not a legal source stage for %s" % [str(stage), signal_id])

	var fields: Array = _string_array(record, "payload_fields")
	for required: Variant in fields:
		if not payload.has(str(required)):
			return _fail(&"SIGNAL_PAYLOAD_FIELD_MISSING",
				"%s: the payload omits %s" % [signal_id, str(required)])
	for key: Variant in payload:
		if not fields.has(str(key)):
			return _fail(&"SIGNAL_PAYLOAD_FIELD_UNKNOWN",
				"%s: %s is not a registered payload field" % [signal_id, str(key)])
	for opaque: String in OPAQUE_PAYLOAD_FIELDS:
		if not fields.has(opaque):
			continue
		var value: Variant = payload[opaque]
		if typeof(value) != TYPE_STRING or str(value).is_empty():
			return _fail(&"SIGNAL_OPAQUE_FIELD_INVALID",
				"%s: %s has no registry in this phase, so it must at least be a non-empty string"
				% [signal_id, opaque])

	for line_field: String in ["line_id", "witnessed_line_id"]:
		if not payload.has(line_field):
			continue
		var line := validate_line_id(document, entry_id, str(payload[line_field]))
		if not line.get("ok", false):
			return line
	if payload.has("presentation_atom_id"):
		var atom := validate_atom_id(document, entry_id, str(payload["presentation_atom_id"]))
		if not atom.get("ok", false):
			return atom
		if payload.has("echo_id"):
			var partner: Variant = (atom["value"] as Dictionary).get("echo_id")
			if partner == null or str(partner) != str(payload["echo_id"]):
				return _fail(&"SIGNAL_ECHO_BINDING_INVALID",
					"%s: the registered echo of %s is %s, not %s" % [
						signal_id, str(payload["presentation_atom_id"]), str(partner),
						str(payload["echo_id"]),
					])
	if payload.has("reply_id"):
		var owner := _reply_owner(registry["value"], str(payload["reply_id"]))
		if owner != entry_id:
			return _fail(&"SIGNAL_REPLY_ID_INVALID",
				"%s: %s is not a reply this entry may commit"
				% [entry_id, str(payload["reply_id"])])
	return {
		"ok": true,
		"value": {"entry_id": entry_id, "signal_id": signal_id, "stage": str(stage)},
	}


static func _load_ids_schema() -> Dictionary:
	if not FileAccess.file_exists(IDS_SCHEMA_PATH):
		return _fail(&"IDS_MANIFEST_SCHEMA_MISSING", IDS_SCHEMA_PATH + " is absent")
	var parsed: Dictionary = STRICT_JSON.parse_object(
		FileAccess.get_file_as_string(IDS_SCHEMA_PATH))
	if not parsed.get("ok", false):
		return _fail(&"IDS_MANIFEST_SCHEMA_MISSING",
			"%s: %s" % [IDS_SCHEMA_PATH, str(parsed.get("message", ""))])
	return {"ok": true, "value": parsed["value"]}


static func _registry_block(registry: Dictionary, block_name: String) -> Array:
	var value: Variant = registry.get(block_name, [])
	return value if value is Array else []


static func _string_array(record: Dictionary, key: String) -> Array:
	var value: Variant = record.get(key, [])
	return value if value is Array else []


static func _entry_index(document: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	var entries: Variant = document.get("entries", [])
	if not (entries is Array):
		return index
	for candidate: Variant in (entries as Array):
		if candidate is Dictionary:
			index[str((candidate as Dictionary).get("entry_id", ""))] = candidate
	return index


static func _signal_record(registry: Dictionary, signal_id: String) -> Dictionary:
	for record: Dictionary in _registry_block(registry, "signals"):
		if str(record.get("signal_id", "")) == signal_id:
			return record
	return {}


static func _reply_owner(registry: Dictionary, reply_id: String) -> String:
	for record: Dictionary in _registry_block(registry, "reply_ids"):
		if str(record.get("reply_id", "")) == reply_id:
			return str(record.get("owning_entry_id", ""))
	return ""


static func _atom_resolved(record: Dictionary, match_kind: String) -> Dictionary:
	return {
		"ok": true,
		"value": {
			"atom_id": str(record.get("atom_id", "")),
			"kind": str(record.get("kind", "")),
			"owning_entry_id": str(record.get("owning_entry_id", "")),
			"echo_id": record.get("echo_id"),
			"match": match_kind,
		},
	}


## True only for a label the registry both lists as retired AND marks reject_on_restore. A registry
## that cannot be read at all returns false, so resolve_entry degrades to its old generic code
## rather than resolving something it should not.
static func _is_retired_label(entry_id: String) -> bool:
	var registry := load_ids_default()
	if not registry.get("ok", false):
		return false
	for record: Dictionary in _registry_block(registry["value"], "retired_ids"):
		if str(record.get("label_id", "")) == entry_id:
			return record.get("reject_on_restore") == true
	return false
