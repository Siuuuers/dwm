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
## Sub-commit 2B adds validate_signal, validate_line_id and validate_atom_id. They are deliberately
## absent rather than stubbed: an empty stub would advertise a capability this contract cannot yet
## honour.

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
