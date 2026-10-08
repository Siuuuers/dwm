class_name DialogicEntryManifest
extends RefCounted
## Closed semantic entry contract (Seven-Day Flow Plan 01 Task 2, sub-commit 2A, dwm-oyo.2).
##
## data/manifests/dialogic_entries.json registers all 137 externally callable entries: the 119 day
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

const SCENE_SCHEMA_PATH := "res://schemas/manifests/dialogic-scene-entries.schema.json"
static var _scene_bundle: Dictionary = {}
static var _registration_used := false
static var _startup_selection_checked := false
static var _startup_selection_error: Dictionary = {}
const SCENE_TEST_FLAG := "--scene-reading-fixture"
const SCENE_TEST_BUNDLE_PATH := "res://tests/fixtures/dialogic/scene_reading_registration.json"

## First owner access precedes consumers' caches, including autoload consumers.
## Only the explicit debug process switch selects this one shipped TEST fixture.
## The exact environment value supports GUT, which rejects unknown CLI flags.
static func _select_startup_fixture() -> Dictionary:
	if _startup_selection_checked:
		return {"ok": true} if _startup_selection_error.is_empty() else _startup_selection_error.duplicate(true)
	_startup_selection_checked = true
	if not OS.get_cmdline_user_args().has(SCENE_TEST_FLAG) and not OS.get_cmdline_args().has(SCENE_TEST_FLAG) \
			and OS.get_environment("DWM_SCENE_READING_FIXTURE") != "1":
		return {"ok": true}
	if not OS.has_feature("debug"):
		_startup_selection_error = _scene_fail("test_only")
		return _startup_selection_error.duplicate(true)
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(SCENE_TEST_BUNDLE_PATH))
	if not parsed.ok:
		_startup_selection_error = _scene_fail("startup fixture unavailable")
		return _startup_selection_error.duplicate(true)
	var selected := configure_test_scene_registration(parsed.value)
	if not selected.ok: _startup_selection_error = selected.duplicate(true)
	return selected

## Process-local engineering seam. Save data is never a configuration source.
static func configure_test_scene_registration(bundle: Dictionary) -> Dictionary:
	if not OS.has_feature("debug"):
		return _scene_fail("test_only")
	if _registration_used or not _scene_bundle.is_empty():
		return _scene_fail("registration_already_selected")
	var checked := validate_scene_registration(bundle)
	if not checked.ok: return checked
	_scene_bundle = bundle.duplicate(true)
	_scene_freeze(_scene_bundle)
	return {"ok": true, "value": _scene_hash(_scene_bundle)}

static func scene_registration() -> Dictionary:
	var startup := _select_startup_fixture()
	if not startup.ok: return startup
	_registration_used = true
	if _scene_bundle.is_empty(): return _fail(&"scene_registration_absent", "no TEST scene registration selected")
	return {"ok": true, "value": _scene_bundle.duplicate(true)}

static func scene_registration_fingerprint() -> String:
	if not _select_startup_fixture().ok: return ""
	_registration_used = true
	return "" if _scene_bundle.is_empty() else _scene_hash(_scene_bundle)

static func _scene_hash(value: Variant) -> String:
	var encoded := CANONICAL_JSON.stringify(value)
	return str(encoded.value).sha256_text() if encoded.ok else ""

static func _scene_freeze(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for child: Variant in (value.values() if value is Dictionary else value):
			_scene_freeze(child)
		value.make_read_only()

static func _scene_exact(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key: Variant in value:
		if not key is String or key not in keys: return false
	return true

static func _scene_id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _scene_version(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0

static func _scene_fail(detail: String) -> Dictionary:
	return _fail(&"scene_registration_invalid", detail)

static func _scene_table(value: Variant, id: String, keys: Array) -> Dictionary:
	if not value is Array: return _scene_fail(id + ": array required")
	var rows := {}
	var previous := ""
	for row: Variant in value:
		if not _scene_exact(row, keys) or not _scene_id(row.get(id)) or str(row[id]) <= previous:
			return _scene_fail(id + ": exact sorted unique rows required")
		previous = row[id]
		rows[row[id]] = row
	return {"ok": true, "value": rows}

static func _validate_scene_manifest(document: Dictionary) -> Dictionary:
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(SCENE_SCHEMA_PATH))
	if not parsed.ok: return _scene_fail("scene schema missing")
	var shape := JsonSchemaValidator.validate(document, parsed.value)
	if not shape.ok: return shape
	if typeof(document.schema_version) != TYPE_INT or typeof(document.entry_count) != TYPE_INT \
			or document.entry_count != document.entries.size(): return _scene_fail("entry count")
	var seen := {}
	var previous := ""
	for row: Dictionary in document.entries:
		if row.entry_id <= previous or not _scene_version(row.content_version): return _scene_fail("entry order/version")
		previous = row.entry_id
		if row.context_schema_id != "context.scene." + row.entry_id + ".v1" \
				or row.line_namespace != "line." + row.entry_id or row.atom_namespace != "atom." + row.entry_id:
			return _scene_fail("namespace")
		var locator: Dictionary = row.locators.en
		if not _locator_is_usable(locator, row.entry_id) or not locator.path.begins_with("res://tests/fixtures/dialogic/") \
				or ".." in locator.path or not locator.path.ends_with(".dtl"): return _scene_fail("TEST locator")
		var pair: String = locator.path + "|" + locator.label
		if seen.has(pair): return _scene_fail("duplicate locator")
		seen[pair] = true
		var signals := _check_allowlist(row.entry_id, row.allowed_signals)
		if not signals.ok: return signals
	return {"ok": true, "value": document.duplicate(true)}

## Validate the complete bundle before any consumer can populate a cache.
static func validate_scene_registration(bundle: Dictionary) -> Dictionary:
	if not _scene_exact(bundle, ["kind", "schema_version", "entry_manifest", "context_registry",
			"ids_registry", "caption_registry", "scene_programme", "targets", "board_profiles", "challenges", "contacts"]) \
			or bundle.kind != "scene_reading_registration" or typeof(bundle.schema_version) != TYPE_INT \
			or bundle.schema_version != 1: return _scene_fail("bundle shape")
	for field: String in ["entry_manifest", "context_registry", "ids_registry", "caption_registry", "scene_programme"]:
		if not bundle[field] is Dictionary: return _scene_fail(field)
	var manifest := _validate_scene_manifest(bundle.entry_manifest)
	if not manifest.ok: return manifest
	var entries := _entry_index(bundle.entry_manifest)
	var contexts: Dictionary = bundle.context_registry
	if not _scene_exact(contexts, ["kind", "schema_version", "schemas"]) \
			or contexts.kind != "dialogic_frozen_context_registry" or typeof(contexts.schema_version) != TYPE_INT \
			or contexts.schema_version != 1: return _scene_fail("contexts shape")
	var schemas := _scene_table(contexts.schemas, "entry_id", ["schema_id", "schema_version", "entry_id", "fields"])
	if not schemas.ok or schemas.value.size() != entries.size(): return _scene_fail("context coverage")
	for id: String in entries:
		var row: Dictionary = schemas.value.get(id, {})
		if row.get("schema_id") != entries[id].context_schema_id or typeof(row.get("schema_version")) != TYPE_INT \
				or row.schema_version != 1 or row.get("fields") != {"entry_id": {"const": id},
				"entry_role": {"const": "scene"}, "occurrence_id": "id", "admission_receipt_id": "id"}:
			return _scene_fail("context fields")
	var captions: Dictionary = bundle.caption_registry
	if not _scene_exact(captions, ["kind", "schema_version", "entries"]) or captions.kind != "scene_caption_registry" \
			or typeof(captions.schema_version) != TYPE_INT or captions.schema_version != 1: return _scene_fail("captions shape")
	var caption_entries := _scene_table(captions.entries, "entry_id", ["entry_id", "lines"])
	if not caption_entries.ok or caption_entries.value.size() != entries.size(): return _scene_fail("caption coverage")
	var lines := {}
	var beats := {}
	for id: String in entries:
		var row: Dictionary = caption_entries.value.get(id, {})
		if not row.get("lines") is Array or row.lines.is_empty(): return _scene_fail("caption lines")
		for line: Variant in row.lines:
			if not _scene_exact(line, ["beat_id", "line_id", "text", "revision"]): return _scene_fail("caption shape")
			for field: String in ["beat_id", "line_id", "text", "revision"]:
				if not _scene_id(line[field]): return _scene_fail("caption value")
			if lines.has(line.line_id) or beats.has(line.beat_id): return _scene_fail("caption duplicate")
			lines[line.line_id] = id
			beats[line.beat_id] = true
	var ids: Dictionary = bundle.ids_registry
	if not _scene_exact(ids, ["kind", "schema_version", "lines", "signals"]) or ids.kind != "scene_ids_registry" \
			or typeof(ids.schema_version) != TYPE_INT or ids.schema_version != 1: return _scene_fail("ids shape")
	var ids_lines := _scene_table(ids.lines, "line_id", ["line_id", "owning_entry_id"])
	var signals := _scene_table(ids.signals, "signal_id", ["signal_id", "payload_fields"])
	if not ids_lines.ok or not signals.ok or ids_lines.value.size() != lines.size(): return _scene_fail("ids coverage")
	for id: String in lines:
		if ids_lines.value.get(id, {}).get("owning_entry_id") != lines[id]: return _scene_fail("line owner")
	var payloads := {"scene.transition": ["target_id"], "challenge.playable": ["challenge_id"],
		"challenge.end": ["challenge_id"], "contact.enter": ["contact_event_id"], "contact.return": ["contact_event_id"],
		"history.line.witness": ["entry_id", "line_id", "playback_token", "receipt_id"]}
	for id: String in signals.value:
		if not payloads.has(id) or signals.value[id].payload_fields != payloads[id]: return _scene_fail("signal shape")
	for row: Dictionary in entries.values():
		for signal_id: String in row.allowed_signals:
			if not signals.value.has(signal_id): return _scene_fail("unbound signal")
	var programme: Dictionary = bundle.scene_programme
	if not _scene_exact(programme, ["kind", "schema_version", "entries"]) or programme.kind != "scene_programme" \
			or typeof(programme.schema_version) != TYPE_INT or programme.schema_version != 1: return _scene_fail("programme shape")
	var programmes := _scene_table(programme.entries, "entry_id", ["entry_id", "content_version", "content_sha256", "program_sha256", "markers"])
	if not programmes.ok or programmes.value.size() != entries.size(): return _scene_fail("programme coverage")
	var compiled := {}
	var markers := {}
	for id: String in entries:
		var row: Dictionary = programmes.value.get(id, {})
		if not _scene_version(row.get("content_version")) or row.content_version != entries[id].content_version \
				or not row.get("markers") is Array: return _scene_fail("programme version")
		# Shape-check before the native compiler consumes any marker fields.
		for marker: Variant in row.markers:
			if not _scene_exact(marker, ["marker_id", "label", "after_line_id", "kind", "payload"]):
				return _scene_fail("marker shape")
			for field: String in ["marker_id", "label", "after_line_id", "kind"]:
				if not _scene_id(marker[field]): return _scene_fail("marker value")
			if not marker.payload is Dictionary: return _scene_fail("marker payload")
		var native := DialogicRuntimeAdapter.compile_scene_programme(entries[id].locators.en.path, id, entries.keys(), row.markers)
		if not native.ok: return native
		if row.content_sha256 != native.value.content_sha256 or row.program_sha256 != native.value.program_sha256:
			return _scene_fail("programme hash")
		compiled[id] = native.value
		var native_lines: Array = []
		var native_signals: Array = []
		var labels: Array = []
		for event: Dictionary in native.value.events:
			if event.kind == "label": labels.append(event.label)
			elif event.kind == "text": native_lines.append({"line_id": event.line_id, "text": event.text})
			elif event.kind == "signal": native_signals.append(event.signal_id)
		var expected_lines: Array = []
		for line: Dictionary in caption_entries.value[id].lines:
			expected_lines.append({"line_id": line.line_id, "text": line.text})
		if native_lines != expected_lines: return _scene_fail("DTL captions")
		var expected_signals: Array = []
		var marker_labels := {}
		for marker: Variant in row.markers:
			if not _scene_exact(marker, ["marker_id", "label", "after_line_id", "kind", "payload"]) \
					or not _scene_id(marker.marker_id) or markers.has(marker.marker_id) \
					or marker_labels.has(marker.label) or marker.label not in labels \
					or lines.get(marker.after_line_id) != id or marker.kind not in payloads \
					or marker.kind == WITNESS_SIGNAL or marker.kind not in entries[id].allowed_signals \
					or not _scene_exact(marker.payload, payloads[marker.kind]): return _scene_fail("marker")
			for value: Variant in marker.payload.values():
				if not _scene_id(value): return _scene_fail("marker payload")
			markers[marker.marker_id] = {"entry_id": id, "row": marker}
			marker_labels[marker.label] = true
			expected_signals.append(marker.kind)
		for signal_id: String in native_signals:
			if signal_id not in expected_signals: return _scene_fail("DTL signal coverage")
		# A marker must immediately follow its authenticated source caption label boundary.
		var last_line := ""
		var actual_marker_order: Array = []
		for event: Dictionary in native.value.events:
			if event.kind == "text": last_line = event.line_id
			if event.kind == "label" and marker_labels.has(event.label):
				actual_marker_order.append(event.label)
				for marker: Dictionary in row.markers:
					if marker.label == event.label and marker.after_line_id != last_line:
						return _scene_fail("marker position")
		var declared_marker_order: Array = []
		var expected_grants: Array = [WITNESS_SIGNAL]
		for marker: Dictionary in row.markers:
			declared_marker_order.append(marker.label)
			if marker.kind not in expected_grants: expected_grants.append(marker.kind)
		expected_grants.sort()
		if actual_marker_order != declared_marker_order or entries[id].allowed_signals != expected_grants:
			return _scene_fail("marker order/grants")
	var tables := _validate_scene_tables(bundle, entries, programmes.value, compiled, markers)
	if not tables.ok: return tables
	return {"ok": true, "value": bundle.duplicate(true)}

static func _validate_scene_tables(bundle: Dictionary, entries: Dictionary, programmes: Dictionary,
		compiled: Dictionary, markers: Dictionary) -> Dictionary:
	var targets := _scene_table(bundle.targets, "target_id", ["target_id", "target"])
	var profiles := _scene_table(bundle.board_profiles, "board_profile_id", ["board_profile_id", "board_kind",
		"difficulty_id", "width", "height", "base_mine_count", "generator_version", "verifier_version", "capability_policy_id"])
	var challenges := _scene_table(bundle.challenges, "challenge_id",
		["challenge_id", "entry_id", "playable_marker_id", "end_marker_id", "board_profile_id", "targets"])
	var contacts := _scene_table(bundle.contacts, "contact_event_id", ["contact_event_id", "entry_id", "source_fact_ids", "return_target_id"])
	for table: Dictionary in [targets, profiles, challenges, contacts]:
		if not table.ok: return table
	for row: Dictionary in targets.value.values():
		var target: Variant = row.target
		if not _scene_exact(target, ["kind", "entry_id", "label", "content_version", "program_sha256"]) \
				or target.kind not in ["local", "scene", "ending", "contact", "return"] \
				or not entries.has(target.entry_id): return _scene_fail("target shape")
		if not _scene_version(target.content_version) or target.content_version != programmes[target.entry_id].content_version \
				or target.program_sha256 != programmes[target.entry_id].program_sha256: return _scene_fail("target version")
		if target.kind in ["scene", "ending", "contact"]:
			if target.label != target.entry_id: return _scene_fail("callable target")
		elif not compiled[target.entry_id].label_nodes.has(target.label): return _scene_fail("internal target")
	for row: Dictionary in profiles.value.values():
		for key: String in ["width", "height", "base_mine_count"]:
			if typeof(row[key]) != TYPE_INT: return _scene_fail("board integer")
		if row.width <= 0 or row.height <= 0 or row.base_mine_count < 0 \
				or row.base_mine_count >= row.width * row.height: return _scene_fail("board geometry")
		var host: String = {"desktop": "desktop_app", "solo_challenge": "canonical_solo",
			"pair_challenge": "canonical_pair"}.get(row.board_kind, "")
		if not row.difficulty_id is String: return _scene_fail("board difficulty")
		var geometry := MinesweeperBoardCatalog.lookup(host, row.difficulty_id if host == "desktop_app" else "")
		if not geometry.ok or (host != "desktop_app" and row.difficulty_id != host) \
				or geometry.value != {"width": row.width, "height": row.height, "base_mine_count": row.base_mine_count}:
			return _scene_fail("unsupported board profile")
		# Explicit scene discriminator selects the existing inventory capability projection.
		if row.generator_version != "dwm_generator_v1" or row.verifier_version != "visible_deduction_v1" \
				or row.capability_policy_id != "owned_inventory_v1": return _scene_fail("unsupported board policy")
	for row: Dictionary in challenges.value.values():
		if not entries.has(row.entry_id) or not profiles.value.has(row.board_profile_id) \
				or not _scene_exact(row.targets, ["never_started", "unfinished", "lost", "won"]):
			return _scene_fail("challenge shape")
		for pair: Array in [["playable_marker_id", "challenge.playable"], ["end_marker_id", "challenge.end"]]:
			var marker: Dictionary = markers.get(row[pair[0]], {})
			if marker.get("entry_id") != row.entry_id or marker.row.kind != pair[1] \
					or marker.row.payload != {"challenge_id": row.challenge_id}: return _scene_fail("challenge marker")
		for target_id: Variant in row.targets.values():
			if not targets.value.has(target_id): return _scene_fail("challenge target")
			var target: Dictionary = targets.value[target_id].target
			if target.kind == "local" and target.entry_id != row.entry_id: return _scene_fail("local challenge target")
		var ordered: Array = programmes[row.entry_id].markers
		if ordered.find(markers[row.playable_marker_id].row) >= ordered.find(markers[row.end_marker_id].row):
			return _scene_fail("challenge marker order")
	for row: Dictionary in contacts.value.values():
		if not entries.has(row.entry_id) or not targets.value.has(row.return_target_id) \
				or targets.value[row.return_target_id].target.kind != "return" or not row.source_fact_ids is Array:
			return _scene_fail("contact target")
		var previous := ""
		for fact: Variant in row.source_fact_ids:
			if not _scene_id(fact) or fact <= previous: return _scene_fail("contact facts")
			previous = fact
	for value: Dictionary in markers.values():
		var marker: Dictionary = value.row
		match marker.kind:
			"scene.transition":
				if not targets.value.has(marker.payload.target_id): return _scene_fail("dangling transition")
				var target: Dictionary = targets.value[marker.payload.target_id].target
				if target.kind == "local" and target.entry_id != value.entry_id: return _scene_fail("local transition target")
			"challenge.playable", "challenge.end":
				if not challenges.value.has(marker.payload.challenge_id): return _scene_fail("dangling challenge")
			"contact.enter", "contact.return":
				if not contacts.value.has(marker.payload.contact_event_id): return _scene_fail("dangling contact")
				if marker.kind == "contact.return" and contacts.value[marker.payload.contact_event_id].entry_id != value.entry_id:
					return _scene_fail("contact return owner")
	return {"ok": true}


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
## does not do; the evidence_id half of the opaque-field guard cannot be reached at all while no
## entry grants observer.evidence.commit. All are KNOWINGLY UNCOVERED and their spellings are pinned
## by the suite reading this file as text. resolve_entry's explicit registry seam covers the otherwise
## unreachable reject_on_restore=false diagnostic branch without accepting that invalid registry.

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
	var startup := _select_startup_fixture()
	if not startup.ok: return startup
	_registration_used = true
	if not _scene_bundle.is_empty():
		return {"ok": true, "value": _scene_bundle.entry_manifest.duplicate(true)}
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _fail(&"ENTRY_MANIFEST_FILE_MISSING", MANIFEST_PATH + " is absent")
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed.get("ok", false):
		return _fail(&"ENTRY_MANIFEST_PARSE_FAILED",
			"%s: %s" % [MANIFEST_PATH, str(parsed.get("message", ""))])
	return {"ok": true, "value": parsed["value"]}


static func validate_document(document: Dictionary) -> Dictionary:
	if document.get("schema_version") == 2:
		return _validate_scene_manifest(document)
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


static func resolve_entry(document: Dictionary, entry_id: String, locale: String,
		retired_registry: Variant = null) -> Dictionary:
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
		if _is_retired_label(entry_id, retired_registry):
			return _fail(&"ENTRY_MANIFEST_RETIRED_ENTRY",
				"%s is a retired semantic ID, so a save that still carries it is refused"
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
	if document.get("schema_version") == 2:
		if not _select_startup_fixture().ok: return ""
		if _scene_bundle.is_empty() or document != _scene_bundle.entry_manifest: return ""
		return scene_registration_fingerprint()
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
	var startup := _select_startup_fixture()
	if not startup.ok: return startup
	_registration_used = true
	if not _scene_bundle.is_empty():
		return {"ok": true, "value": _scene_bundle.ids_registry.duplicate(true)}
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
	if ids_document.get("kind") == "scene_ids_registry":
		if _scene_bundle.is_empty() or ids_document != _scene_bundle.ids_registry:
			return _scene_fail("unselected ids registry")
		return {"ok": true, "value": ids_document.duplicate(true)}
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
	for entry_id: String in known:
		for observer: Dictionary in known[entry_id].get("observer_atoms", []):
			registered_lines[str(observer.line_id)] = entry_id
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
	if document.get("schema_version") == 2:
		var selected := scene_registration()
		if not selected.ok or document != selected.value.entry_manifest: return _scene_fail("unselected entries")
		for row: Dictionary in selected.value.ids_registry.lines:
			if row.line_id == line_id and row.owning_entry_id == entry_id:
				return {"ok": true, "value": row.duplicate(true)}
		return _fail(&"LINE_ID_UNREGISTERED", line_id)
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
	for owner: String in _entry_index(document):
		for observer: Dictionary in _entry_index(document)[owner].get("observer_atoms", []):
			if str(observer.line_id) != line_id: continue
			if owner != entry_id: return _fail(&"LINE_ID_NOT_OWNED", line_id)
			return {"ok": true, "value": {"line_id": line_id, "owning_entry_id": owner}}
	return _fail(&"LINE_ID_UNREGISTERED", "%s is not a registered line id" % line_id)


## Separate opt-in caption registration; the reply/Observer registry is not a
## complete narrative beat catalog. This never grants Profile visited membership.
static func validate_caption_registry(document: Dictionary, registry: Dictionary) -> Dictionary:
	return preload("res://scripts/narrative/NarrativeCaptionRegistry.gd").validate_document(
		registry, _entry_index(document).keys())


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


## True only for a label the registry both lists as retired AND marks reject_on_restore. Omission
## loads the shipped registry; an explicit empty registry never reads disk. If the shipped registry
## cannot be read, resolve_entry degrades to its old generic code without resolving the entry.
static func _is_retired_label(entry_id: String, retired_registry: Variant = null) -> bool:
	var registry: Dictionary = {}
	if retired_registry == null:
		var loaded := load_ids_default()
		if not loaded.get("ok", false):
			return false
		registry = loaded["value"]
	elif retired_registry is Dictionary:
		registry = retired_registry
	else:
		return false
	for record: Dictionary in _registry_block(registry, "retired_ids"):
		if str(record.get("label_id", "")) == entry_id:
			return record.get("reject_on_restore") == true
	return false

