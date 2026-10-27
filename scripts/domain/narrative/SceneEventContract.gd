class_name SceneEventContract
extends RefCounted
const _VALIDATION_TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")
## Isolated, nonwired contract foundation. Registration is supplied by a trusted owner,
## never by DTL. This validates semantic input, not content approval or disk durability.
## A production adapter must bind registration/identity/frontier to one supported Run.

const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const SCENE_RECEIPT_ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ENVELOPE_KEYS := ["schema_version", "source", "event_id", "ordinal", "predecessor",
	"kind", "payload", "command_id", "issuer_receipt", "playback_token"]
const SOURCE_KEYS := ["run_id", "branch_id", "causal_day_instance", "scene_occurrence",
	"entry_id", "content_version"]
const RECORD_KEYS := ["event_id", "ordinal", "predecessor", "kind", "payload", "command_id"]
const PAYLOAD_KEYS := {
	"scene.enter": ["scene_id", "entry_id", "context_id"],
	"day.begin": ["source_phase", "target_day"],
	"day.complete": ["source_day", "successor_id"],
	"background.set": ["art_id"],
	"self_talk.trigger": ["entry_id", "segment_id"],
	"notification.set": ["notification_id", "content_id", "parameters"],
	"notification.clear": ["notification_id"],
	"appointment.admit": ["appointment_id", "invitation_receipt_id"],
	"appointment.complete": ["appointment_id", "completion_receipt_id"],
}

static func inspect(envelope: Variant) -> Dictionary:
	if not _keys(envelope, ENVELOPE_KEYS): return _fail(&"event_shape_invalid")
	if typeof(envelope.schema_version) != TYPE_INT or envelope.schema_version != 1:
		return _fail(&"event_version_invalid")
	if not _keys(envelope.source, SOURCE_KEYS): return _fail(&"event_source_invalid")
	for key: String in SOURCE_KEYS:
		if key == "content_version":
			if typeof(envelope.source[key]) != TYPE_INT or envelope.source[key] < 1:
				return _fail(&"event_source_invalid")
		elif not _id(envelope.source[key]): return _fail(&"event_source_invalid")
	for key: String in ["event_id", "kind", "command_id", "playback_token"]:
		if not _id(envelope[key]): return _fail(&"event_identity_invalid")
	if typeof(envelope.ordinal) != TYPE_INT or envelope.ordinal < 0:
		return _fail(&"event_ordinal_invalid")
	if typeof(envelope.predecessor) != TYPE_STRING or (envelope.predecessor != "" and not _id(envelope.predecessor)):
		return _fail(&"event_predecessor_invalid")
	if not envelope.issuer_receipt is Dictionary: return _fail(&"event_issuer_invalid")
	if not PAYLOAD_KEYS.has(envelope.kind): return _fail(&"event_kind_unregistered")
	if not _keys(envelope.payload, PAYLOAD_KEYS[envelope.kind]): return _fail(&"event_payload_invalid")
	for key: String in PAYLOAD_KEYS[envelope.kind]:
		var value: Variant = envelope.payload[key]
		if key in ["target_day", "source_day"]:
			if typeof(value) != TYPE_INT or value < 1 or value > 7: return _fail(&"event_payload_invalid")
		elif key == "parameters":
			if not value is Dictionary: return _fail(&"event_payload_invalid")
			for parameter: Variant in value:
				if not _id(parameter) or typeof(value[parameter]) not in [TYPE_STRING, TYPE_INT, TYPE_BOOL]:
					return _fail(&"event_payload_invalid")
		elif not _id(value): return _fail(&"event_payload_invalid")
	# The live token is deliberately not semantic identity. Receipt authentication is
	# delegated to the existing issuer by the application port, not reimplemented here.
	var semantic: Dictionary = envelope.duplicate(true)
	semantic.erase("playback_token")
	var encoded: Dictionary = WRITER.stringify(semantic)
	if not encoded.get("ok", false): return _fail(&"event_not_canonical")
	return {"ok": true, "value": {"semantic": semantic,
		"digest": str(encoded.value).sha256_text()}}

static func match_registration(envelope: Dictionary, record: Variant) -> Dictionary:
	var shaped: Dictionary = inspect(envelope)
	if not shaped.get("ok", false): return shaped
	if not _keys(record, RECORD_KEYS): return _fail(&"event_registration_invalid")
	for key: String in RECORD_KEYS:
		if typeof(envelope[key]) != typeof(record[key]): return _fail(&"event_registration_invalid")
		if envelope[key] != record[key]: return _fail(&"event_registration_mismatch")
	return {"ok": true}

const RECEIPT_KEYS := ["transaction_id", "request_fingerprint", "kind", "source_id", "scene_event"]
const SAVED_EVENT_KEYS := ["schema_version", "semantic", "registration_fingerprint", "reading_anchor", "result"]
const ANCHOR_KEYS := ["session_id", "entry_id", "content_version", "catalogue_fingerprint", "publication_id", "line_id"]
const RESULT_KEYS := ["event_id", "ordinal", "notification"]

static func occurrence_key(source: Dictionary) -> String:
	# IDs can contain colons; a canonical tuple keeps distinct occurrences distinct.
	return str(WRITER.stringify([source.scene_occurrence, source.entry_id]).value)

static func registration_fingerprint(record: Dictionary) -> Dictionary:
	if not _keys(record, RECORD_KEYS): return _fail(&"event_registration_invalid")
	var encoded: Dictionary = WRITER.stringify(record)
	if not encoded.get("ok", false): return _fail(&"event_registration_invalid")
	return {"ok": true, "value": str(encoded.value).sha256_text()}

static func make_receipt(envelope: Dictionary, anchor: Dictionary) -> Dictionary:
	var shaped: Dictionary = inspect(envelope)
	if not shaped.ok: return shaped
	if typeof(envelope.issuer_receipt.get("token")) != TYPE_STRING or envelope.issuer_receipt.get("token") != envelope.command_id:
		return _fail(&"event_issuer_invalid")
	if envelope.kind not in ["notification.set", "notification.clear"]:
		return _fail(&"event_kind_unsupported")
	if not _valid_anchor(anchor, envelope.source): return _fail(&"event_anchor_invalid")
	var record := {}
	for key: String in RECORD_KEYS: record[key] = envelope[key]
	var fingerprint: Dictionary = registration_fingerprint(record)
	if not fingerprint.ok: return fingerprint
	return {"ok": true, "value": {"transaction_id": envelope.command_id,
		"request_fingerprint": shaped.value.digest, "kind": "scene_event",
		"source_id": envelope.source.scene_occurrence, "scene_event": {
			"schema_version": 1, "semantic": shaped.value.semantic,
			"registration_fingerprint": fingerprint.value, "reading_anchor": anchor.duplicate(true),
			"result": {"event_id": envelope.event_id, "ordinal": envelope.ordinal,
				"notification": envelope.payload.duplicate(true) if envelope.kind == "notification.set" else {}}}}}

static func validate_receipts(receipts: Dictionary) -> Dictionary:
	var occurrences := {}
	for command: Variant in receipts:
		var receipt: Variant = receipts[command]
		# The owning Run schema validates legacy variants.
		if not receipt is Dictionary or receipt.get("kind") != "scene_event": continue
		if not _keys(receipt, RECEIPT_KEYS): return _fail(&"event_receipt_invalid")
		if typeof(command) != TYPE_STRING or receipt.transaction_id != command:
			return _fail(&"event_receipt_identity_invalid")
		var saved: Variant = receipt.scene_event
		if not _keys(saved, SAVED_EVENT_KEYS): return _fail(&"event_receipt_invalid")
		if typeof(saved.schema_version) != TYPE_INT or saved.schema_version != 1:
			return _fail(&"event_receipt_invalid")
		if not saved.semantic is Dictionary or saved.semantic.has("playback_token"):
			return _fail(&"event_receipt_invalid")
		var envelope: Dictionary = saved.semantic.duplicate(true)
		envelope["playback_token"] = "receipt.validation"
		if not saved.reading_anchor is Dictionary: return _fail(&"event_anchor_invalid")
		var rebuilt: Dictionary = make_receipt(envelope, saved.reading_anchor)
		if not rebuilt.ok: return rebuilt
		# Canonical comparison checks nested field types as well as values (1 != 1.0).
		var actual: Dictionary = WRITER.stringify(receipt)
		var expected: Dictionary = WRITER.stringify(rebuilt.value)
		if not actual.get("ok", false) or actual.value != expected.value or not _same_types(receipt, rebuilt.value):
			return _fail(&"event_receipt_mismatch")
		var key: String = occurrence_key(envelope.source)
		if not occurrences.has(key):
			occurrences[key] = {"source": envelope.source.duplicate(true), "next_ordinal": 0,
				"predecessor": "", "notification": {}, "receipts": []}
		var group: Dictionary = occurrences[key]
		if group.source != envelope.source: return _fail(&"event_receipt_source_changed")
		if not group.receipts.is_empty():
			var prior_anchor: Dictionary = group.receipts[0].scene_event.reading_anchor
			# Publication and line may advance; the owner binds each to its ledger.
			for field: String in ["session_id", "entry_id", "content_version", "catalogue_fingerprint"]:
				if prior_anchor[field] != saved.reading_anchor[field]: return _fail(&"event_anchor_changed")
		group.receipts.append(receipt.duplicate(true))
	for key: String in occurrences:
		var group: Dictionary = occurrences[key]
		group.receipts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.scene_event.semantic.ordinal < b.scene_event.semantic.ordinal)
		var seen_events := {}
		for receipt: Dictionary in group.receipts:
			var semantic: Dictionary = receipt.scene_event.semantic
			if semantic.ordinal != group.next_ordinal or semantic.predecessor != group.predecessor \
					or seen_events.has(semantic.event_id): return _fail(&"event_receipt_chain_invalid")
			if semantic.kind == "notification.clear" and group.notification.get("notification_id", "") != semantic.payload.notification_id:
				return _fail(&"event_notification_clear_invalid")
			seen_events[semantic.event_id] = true
			group.notification = receipt.scene_event.result.notification.duplicate(true)
			group.next_ordinal += 1
			group.predecessor = semantic.event_id
	return {"ok": true, "value": {"occurrences": occurrences}}

static func _same_types(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected): return false
	if actual is Dictionary:
		if actual.size() != expected.size(): return false
		for key: Variant in actual:
			if typeof(key) != TYPE_STRING or not expected.has(key) or not _same_types(actual[key], expected[key]): return false
	elif actual is Array:
		if actual.size() != expected.size(): return false
		for index in range(actual.size()):
			if not _same_types(actual[index], expected[index]): return false
	return true

static func _valid_anchor(anchor: Dictionary, source: Dictionary) -> bool:
	if not _keys(anchor, ANCHOR_KEYS): return false
	for key: String in ANCHOR_KEYS:
		if key == "content_version":
			if typeof(anchor[key]) != TYPE_INT or anchor[key] < 1: return false
		elif not _id(anchor[key]): return false
	return anchor.session_id == source.scene_occurrence and anchor.entry_id == source.entry_id \
		and anchor.content_version == source.content_version

static func _id(value: Variant) -> bool:
	# Semantic identifiers, never resource paths or executable snippets. Content text
	# and localized parameters are registry-owned and compared in full at admission.
	if typeof(value) != TYPE_STRING or value.is_empty() or value.length() > 256: return false
	for index in range(value.length()):
		var code: int = value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
				or code in [45, 46, 58, 95]): return false
	return true

static func _keys(value: Variant, expected: Array) -> bool:
	if not value is Dictionary or value.size() != expected.size(): return false
	for key: Variant in value:
		if typeof(key) != TYPE_STRING or key not in expected: return false
	return true

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code}

# Nonwired scene2 helpers. The selected DialogicEntryManifest owner must validate
# its four nested registries and actual DTL bytes/compiled positions before use.
# These pure checks cannot authenticate disk durability, Profile history, live
# issuer custody or programme installation. Legacy receipt generation stays exact.
const SCENE_PAYLOAD_KEYS := {
	"thought.pass": ["opportunity_id", "yes_target_id", "pass_target_id"],
	"thought.accept": ["opportunity_id", "yes_target_id", "pass_target_id"],
	"thought.options": ["opportunity_id", "options", "pass_target_id"],
	"thought.select": ["opportunity_id", "options", "pass_target_id", "choice_id"],
	"passage.start": ["passage_id"], "passage.finish": ["passage_id"],
	"scene.transition": ["target_id"], "challenge.playable": ["challenge_id"],
	"challenge.end": ["challenge_id"], "contact.enter": ["contact_event_id"],
	"challenge.recall": ["challenge_id", "never_started_target_id", "unfinished_target_id", "won_target_id", "lost_target_id", "perfect_target_id"],
	"contact.return": ["contact_event_id"],
	"notification.set": ["notification_id", "content_id", "parameters"],
	"notification.clear": ["notification_id"],
}
const TARGET_KEYS := ["kind", "entry_id", "label", "content_version", "program_sha256"]
const PROGRAMME_ENTRY_KEYS := ["entry_id", "content_version", "content_sha256", "program_sha256", "markers"]
const MARKER_KEYS := ["marker_id", "label", "after_line_id", "kind", "payload"]
const CHECKPOINT_KEYS := ["checkpoint_id", "checkpoint_sequence", "snapshot_sha256"]
const LEGACY_OUTCOMES := ["never_started", "unfinished", "lost", "won"]
const OUTCOMES := ["never_started", "unfinished", "lost", "won", "perfect"]

static func _inspect_scene_shape(envelope: Variant) -> Dictionary:
	if not _json_data(envelope) or not _keys(envelope, ENVELOPE_KEYS) or not _keys(envelope.source, SOURCE_KEYS):
		return _fail(&"scene_event_shape_invalid")
	for key: String in SOURCE_KEYS:
		if key == "content_version":
			if not _positive_int(envelope.source[key]): return _fail(&"scene_event_source_invalid")
		elif not _id(envelope.source[key]): return _fail(&"scene_event_source_invalid")
	for key: String in ["event_id", "kind", "command_id", "playback_token"]:
		if not _id(envelope[key]): return _fail(&"scene_event_identity_invalid")
	if typeof(envelope.ordinal) != TYPE_INT or envelope.ordinal < 0:
		return _fail(&"event_ordinal_invalid")
	if typeof(envelope.predecessor) != TYPE_STRING or (envelope.predecessor != "" and not _id(envelope.predecessor)):
		return _fail(&"event_predecessor_invalid")
	if not envelope.issuer_receipt is Dictionary or envelope.issuer_receipt.get("token") != envelope.command_id:
		return _fail(&"event_issuer_invalid")
	if not _scene_payload(envelope.kind, envelope.payload): return _fail(&"event_payload_invalid")
	var semantic: Dictionary = envelope.duplicate(true)
	semantic.erase("playback_token")
	var encoded: Dictionary = WRITER.stringify(semantic)
	if not encoded.get("ok", false): return _fail(&"event_not_canonical")
	return {"ok": true, "value": {"semantic": semantic, "digest": str(encoded.value).sha256_text()}}

static func _scene_payload(kind: String, payload: Variant) -> bool:
	if not SCENE_PAYLOAD_KEYS.has(kind) or not _keys(payload, SCENE_PAYLOAD_KEYS[kind]): return false
	for key: String in payload:
		if key == "options":
			if not _thought_options(payload[key], payload.pass_target_id): return false
		elif key == "parameters":
			if not payload[key] is Dictionary: return false
			for parameter: Variant in payload[key]:
				if not _id(parameter) or typeof(payload[key][parameter]) not in [TYPE_STRING, TYPE_INT, TYPE_BOOL]: return false
		elif not _id(payload[key]): return false
	if kind == "thought.select" and thought_option_target(payload, payload.choice_id).is_empty(): return false
	return true

static func _thought_options(options: Variant, pass_target_id: Variant) -> bool:
	if not options is Array or options.is_empty(): return false
	var ids := {}
	var targets := {str(pass_target_id): true}
	for option: Variant in options:
		if not _keys(option, ["choice_id", "text", "target_id"]) or not _id(option.choice_id) \
				or option.choice_id == "pass" or ids.has(option.choice_id) or not _id(option.target_id) \
				or targets.has(option.target_id) or not option.text is String or option.text.strip_edges().is_empty(): return false
		ids[option.choice_id] = true
		targets[option.target_id] = true
	return true

static func thought_option_target(payload: Dictionary, choice_id: String) -> String:
	for option: Dictionary in payload.get("options", []):
		if option.choice_id == choice_id: return option.target_id
	return ""

static func thought_targets(payload: Dictionary) -> Array:
	var targets: Array = [payload.pass_target_id]
	if payload.has("options"):
		for option: Dictionary in payload.options: targets.append(option.target_id)
	else: targets.append(payload.yes_target_id)
	return targets

static func thought_result(envelope: Dictionary) -> Dictionary:
	var choice := "pass"
	var target_id: String = envelope.payload.pass_target_id
	if envelope.kind == "thought.accept":
		choice = "yes"
		target_id = envelope.payload.yes_target_id
	elif envelope.kind == "thought.select":
		choice = envelope.payload.choice_id
		target_id = thought_option_target(envelope.payload, choice)
	return {"kind": "thought_resolved", "opportunity_id": envelope.payload.opportunity_id,
		"choice": choice, "target_id": target_id}

static func validate_bundle_structure(bundle: Variant) -> Dictionary:
	var manifest: Script = load("res://scripts/narrative/DialogicEntryManifest.gd")
	if manifest == null: return _fail(&"scene_bundle_invalid")
	var prepared: Dictionary = manifest.prepared_scene_contract(bundle)
	if not prepared.is_empty(): return prepared
	var started_us: int = _VALIDATION_TIMING.start_sample()
	var result: Dictionary = _validate_bundle_structure_observed_body(bundle)
	_VALIDATION_TIMING.finish_sample("bundle_validation", started_us, bool(result.get("ok", false)))
	return result

static func _validate_bundle_structure_observed_body(bundle: Variant) -> Dictionary:
	if not _json_data(bundle):
		return _fail(&"scene_bundle_invalid")
	# One envelope/Contacts definition owner; no full DTL admission or cache here.
	var manifest: Script = load("res://scripts/narrative/DialogicEntryManifest.gd")
	if manifest == null: return _fail(&"scene_bundle_invalid")
	var header: Dictionary = manifest.validate_scene_bundle_header(bundle)
	if not header.get("ok", false): return _fail(&"scene_bundle_invalid")
	# Deliberately no replacement for A's nested validators or caller trust flag.
	var nested_encodings := {}
	for key: String in ["entry_manifest", "context_registry", "ids_registry", "caption_registry"]:
		if not bundle[key] is Dictionary or bundle[key].is_empty():
			return _fail(&"scene_bundle_nested_invalid")
		var encoded: Dictionary = WRITER.stringify(bundle[key])
		if not encoded.get("ok", false): return _fail(&"scene_bundle_nested_invalid")
		nested_encodings[key] = encoded.value
	var programme: Variant = bundle.scene_programme
	var programme_keys := ["kind", "schema_version", "entries"]
	if programme is Dictionary and programme.has("story_days"): programme_keys.append("story_days")
	if not _keys(programme, programme_keys) or programme.kind != "scene_programme" \
			or typeof(programme.schema_version) != TYPE_INT or programme.schema_version != 1:
		return _fail(&"scene_programme_invalid")
	var tables := {}
	for pair: Array in [["entries", "entry_id"], ["targets", "target_id"], ["board_profiles", "board_profile_id"],
			["challenges", "challenge_id"], ["contacts", "contact_event_id"]]:
		var rows: Variant = programme.entries if pair[0] == "entries" else bundle[pair[0]]
		var indexed := _index_sorted(rows, pair[1])
		if not indexed.ok: return indexed
		tables[pair[0]] = indexed.value
	if tables.entries.is_empty(): return _fail(&"scene_programme_invalid")
	var days := validate_story_days(programme)
	if not days.ok: return days
	var markers := {}
	for entry: Dictionary in tables.entries.values():
		if not _keys(entry, PROGRAMME_ENTRY_KEYS) or not _positive_int(entry.content_version) \
				or not _hash(entry.content_sha256) or not _hash(entry.program_sha256) or not entry.markers is Array:
			return _fail(&"scene_programme_invalid")
		var labels := {}
		for marker: Variant in entry.markers:
			if not _keys(marker, MARKER_KEYS): return _fail(&"scene_marker_invalid")
			for key: String in ["marker_id", "label", "after_line_id", "kind"]:
				if key == "after_line_id" and marker.kind == "passage.start" and marker[key] == "": continue
				if not _id(marker[key]): return _fail(&"scene_marker_invalid")
			if markers.has(marker.marker_id) or labels.has(marker.label) or not _scene_payload(marker.kind, marker.payload):
				return _fail(&"scene_marker_invalid")
			markers[marker.marker_id] = {"entry_id": entry.entry_id, "marker": marker}
			labels[marker.label] = true
	for row: Dictionary in tables.targets.values():
		if not _keys(row, ["target_id", "target"]) or not _target_valid(row.target, tables.entries):
			return _fail(&"scene_target_invalid")
	for profile: Dictionary in tables.board_profiles.values():
		if not _keys(profile, ["board_profile_id", "board_kind", "difficulty_id", "width", "height", "base_mine_count",
				"generator_version", "verifier_version", "capability_policy_id"]): return _fail(&"scene_board_profile_invalid")
		for key: String in ["board_kind", "difficulty_id", "generator_version", "verifier_version", "capability_policy_id"]:
			if not _id(profile[key]): return _fail(&"scene_board_profile_invalid")
		if not _positive_int(profile.width) or not _positive_int(profile.height) or not _positive_int(profile.base_mine_count) \
				or profile.width > 9223372036854775807 / profile.height or profile.base_mine_count >= profile.width * profile.height:
			return _fail(&"scene_board_profile_invalid")
	for challenge: Dictionary in tables.challenges.values():
		if not _keys(challenge, ["challenge_id", "entry_id", "playable_marker_id", "end_marker_id", "board_profile_id", "targets"]) \
				or not (_keys(challenge.targets, LEGACY_OUTCOMES) or _keys(challenge.targets, OUTCOMES)): return _fail(&"scene_challenge_registration_invalid")
		if not _table_has(tables.entries, challenge.entry_id) or not _table_has(tables.board_profiles, challenge.board_profile_id):
			return _fail(&"scene_challenge_registration_invalid")
		for pair: Array in [["playable_marker_id", "challenge.playable"], ["end_marker_id", "challenge.end"]]:
			if not _table_has(markers, challenge[pair[0]]): return _fail(&"scene_challenge_registration_invalid")
			var bound: Dictionary = markers[challenge[pair[0]]]
			if bound.entry_id != challenge.entry_id or bound.marker.kind != pair[1] \
					or bound.marker.payload.challenge_id != challenge.challenge_id: return _fail(&"scene_challenge_registration_invalid")
		for target_id: Variant in challenge.targets.values():
			if not _table_has(tables.targets, target_id): return _fail(&"scene_target_unregistered")
	for contact: Dictionary in tables.contacts.values():
		if not _keys(contact, ["contact_event_id", "entry_id", "source_fact_ids", "return_target_id"]) \
				or not _table_has(tables.entries, contact.entry_id) or not _sorted_ids(contact.source_fact_ids) \
				or not _table_has(tables.targets, contact.return_target_id): return _fail(&"scene_contact_registration_invalid")
		if tables.targets[contact.return_target_id].target.kind != "return": return _fail(&"scene_contact_registration_invalid")
	var opportunities := {}
	for bound: Dictionary in markers.values():
		var marker: Dictionary = bound.marker
		match marker.kind:
			"thought.accept", "thought.select":
				return _fail(&"scene_thought_accept_not_authored")
			"thought.pass", "thought.options":
				if opportunities.has(marker.payload.opportunity_id): return _fail(&"scene_thought_binding_duplicate")
				opportunities[marker.payload.opportunity_id] = true
				if marker.kind == "thought.pass" and marker.payload.yes_target_id == marker.payload.pass_target_id: return _fail(&"scene_thought_targets_invalid")
				for target_id: String in thought_targets(marker.payload):
					if not _table_has(tables.targets, target_id) or tables.targets[target_id].target.kind != "scene":
						return _fail(&"scene_thought_targets_invalid")
			"scene.transition":
				if not _table_has(tables.targets, marker.payload.target_id): return _fail(&"scene_target_unregistered")
			"challenge.recall":
				if not _table_has(tables.challenges, marker.payload.challenge_id): return _fail(&"scene_challenge_registration_invalid")
				for outcome: String in OUTCOMES:
					var target_id: String = marker.payload[outcome + "_target_id"]
					if not _table_has(tables.targets, target_id) or tables.targets[target_id].target.kind != "scene":
						return _fail(&"scene_target_unregistered")
			"challenge.playable", "challenge.end":
				if not _table_has(tables.challenges, marker.payload.challenge_id): return _fail(&"scene_challenge_registration_invalid")
				var challenge: Dictionary = tables.challenges[marker.payload.challenge_id]
				var marker_field := "playable_marker_id" if marker.kind == "challenge.playable" else "end_marker_id"
				if challenge.entry_id != bound.entry_id or challenge[marker_field] != marker.marker_id:
					return _fail(&"scene_challenge_registration_invalid")
			"contact.enter", "contact.return":
				if not _table_has(tables.contacts, marker.payload.contact_event_id): return _fail(&"scene_contact_registration_invalid")
				if marker.kind == "contact.return" and tables.contacts[marker.payload.contact_event_id].entry_id != bound.entry_id:
					return _fail(&"scene_contact_registration_invalid")
	# The header admits only fixed ASCII member names. The intervening checks are
	# synchronous and callback-free, so reuse this call's checked registry encodings.
	# Every remaining value still reaches the canonical writer at this final stage.
	var members: Array = bundle.keys()
	members.sort()
	var parts: Array[String] = []
	for key: String in members:
		var value: String
		if nested_encodings.has(key):
			value = nested_encodings[key]
		else:
			var encoded: Dictionary = WRITER.stringify(bundle[key])
			if not encoded.get("ok", false): return _fail(&"scene_bundle_invalid")
			value = encoded.value
		parts.append('"' + key + '":' + value)
	var canonical := "{" + ",".join(parts) + "}"

	# Legacy low-level callers fingerprint opaque caption registries. Only the
	# new passage contract requires inspecting their nested caption structure.
	for registered: Dictionary in markers.values():
		if registered.marker.kind not in ["passage.start", "passage.finish"]: continue
		var passages: Dictionary = preload("res://scripts/narrative/ScenePassageCatalog.gd").inspect(bundle)
		if not passages.ok: return passages
		break
	tables["markers"] = markers
	tables["fingerprint"] = canonical.sha256_text()
	return {"ok": true, "value": tables.duplicate(true)}

static func bundle_fingerprint(bundle: Variant) -> Dictionary:
	var checked := validate_bundle_structure(bundle)
	if not checked.ok: return checked
	return {"ok": true, "value": checked.value.fingerprint}

static func inspect_scene(envelope: Variant, bundle: Variant) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	return context.inspection if context.ok else context

## Call-local computed material only. Public entrypoints always inspect fresh inputs.
## No issuer, Profile, saved-data or cross-call validation authority is retained here.
static func _inspect_scene_context(envelope: Variant, bundle: Variant) -> Dictionary:
	var shaped := _inspect_scene_versioned_shape(envelope)
	if not shaped.ok: return shaped
	var registered := validate_bundle_structure(bundle)
	if not registered.ok: return registered
	return _bind_scene_context(envelope, shaped, registered)

static func _inspect_scene_versioned_shape(envelope: Variant) -> Dictionary:
	if not envelope is Dictionary or typeof(envelope.get("schema_version")) != TYPE_INT or envelope.schema_version != 2:
		return _fail(&"scene_event_version_invalid")
	return _inspect_scene_shape(envelope)

static func _bind_scene_context(envelope: Variant, shaped: Dictionary, registered: Dictionary) -> Dictionary:
	var entries: Dictionary = registered.value.entries
	var markers: Dictionary = registered.value.markers
	if not entries.has(envelope.source.entry_id) or not markers.has(envelope.event_id): return _fail(&"scene_marker_unregistered")
	var bound: Dictionary = markers[envelope.event_id]
	var authored_payload: Dictionary = envelope.payload.duplicate(true)
	if envelope.kind == "thought.select": authored_payload.erase("choice_id")
	if bound.entry_id != envelope.source.entry_id or entries[bound.entry_id].content_version != envelope.source.content_version \
			or not (bound.marker.kind == envelope.kind or (bound.marker.kind == "thought.pass" and envelope.kind == "thought.accept") \
				or (bound.marker.kind == "thought.options" and envelope.kind == "thought.select")) \
			or not _equal(bound.marker.payload, authored_payload):
		return _fail(&"scene_marker_mismatch")
	shaped.value["registration_fingerprint"] = registered.value.fingerprint
	shaped.value["programme_entry"] = entries[bound.entry_id].duplicate(true)
	return {"ok": true, "inspection": shaped, "registered": registered}

static func validate_target(target: Variant, bundle: Variant) -> Dictionary:
	var checked := validate_bundle_structure(bundle)
	if not checked.ok: return checked
	for row: Dictionary in checked.value.targets.values():
		if _equal(row.target, target): return {"ok": true}
	return _fail(&"scene_target_unregistered")

static func scene_completion_request(envelope: Dictionary, anchor: Dictionary, bundle: Dictionary) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	if not context.ok: return context
	return _scene_completion_request_inspected(envelope, anchor, context.inspection, context.registered)

static func _scene_completion_request_inspected(envelope: Dictionary, anchor: Dictionary,
		checked: Dictionary, registered: Dictionary) -> Dictionary:
	if envelope.kind != "scene.transition" or not _valid_anchor(anchor, envelope.source): return _fail(&"scene_completion_source_invalid")
	var target: Dictionary = registered.value.targets[envelope.payload.target_id].target
	if anchor.line_id != registered.value.markers[envelope.event_id].marker.after_line_id:
		return _fail(&"event_anchor_invalid")
	if target.kind not in ["scene", "ending"]: return _fail(&"scene_completion_target_invalid")
	if not _id(envelope.issuer_receipt.get("receipt_id")): return _fail(&"event_issuer_invalid")
	var projections := {"command_id": envelope.command_id,
		"content_sha256": checked.value.programme_entry.content_sha256, "event_digest": checked.value.digest,
		"marker_program_fingerprint": _sha(checked.value.programme_entry), "reading_anchor_sha256": _sha(anchor),
		"registration_fingerprint": checked.value.registration_fingerprint,
		"role": "scene_terminal_complete" if target.kind == "ending" else "scene_day_complete",
		"source_scene_occurrence": envelope.source.scene_occurrence, "successor_id": envelope.payload.target_id}
	var source_ids: Array[String] = []
	for key: String in projections:
		source_ids.append(key + "=" + str(WRITER.stringify(projections[key]).value))
	source_ids.sort()
	return {"ok": true, "value": {"parent_receipt_id": envelope.issuer_receipt.receipt_id,
		"child_kind": "scene_day_completion", "ordinal": 0, "source_ids": source_ids}}

static func make_scene_receipt(envelope: Dictionary, anchor: Dictionary, result: Dictionary, bundle: Dictionary) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	if not context.ok: return context
	return _make_scene_receipt_from_context(envelope, anchor, result, context)

static func _make_scene_receipt_from_context(envelope: Dictionary, anchor: Dictionary,
		result: Dictionary, context: Dictionary) -> Dictionary:
	var checked: Dictionary = context.inspection
	var registered: Dictionary = context.registered
	if not _valid_anchor(anchor, envelope.source): return _fail(&"event_anchor_invalid")
	if anchor.line_id != registered.value.markers[envelope.event_id].marker.after_line_id:
		return _fail(&"event_anchor_invalid")
	var validated := _validate_scene_result_inspected(envelope, result, registered)
	if not validated.ok: return validated
	if result.kind == "scene_transition_accepted":
		var request := _scene_completion_request_inspected(envelope, anchor, checked, registered)
		if not request.ok: return request
		if not _completion_matches(envelope.issuer_receipt, request.value, result.resolution_receipt):
			return _fail(&"scene_completion_mismatch")
	return {"ok": true, "value": {"transaction_id": envelope.command_id, "request_fingerprint": checked.value.digest,
		"kind": "scene_event", "source_id": envelope.source.scene_occurrence, "scene_event": {
			"schema_version": 2, "semantic": checked.value.semantic, "registration_fingerprint": checked.value.registration_fingerprint,
			"reading_anchor": anchor.duplicate(true), "result": result.duplicate(true)}}}

static func validate_scene_result(envelope: Dictionary, result: Variant, bundle: Dictionary) -> Dictionary:
	var context := _inspect_scene_context(envelope, bundle)
	if not context.ok: return context
	return _validate_scene_result_inspected(envelope, result, context.registered)

static func _validate_scene_result_inspected(envelope: Dictionary, result: Variant,
		registered: Dictionary) -> Dictionary:
	if not _json_data(result) or not result is Dictionary or typeof(result.get("kind")) != TYPE_STRING: return _fail(&"scene_result_invalid")
	var targets: Dictionary = registered.value.targets
	match result.kind:
		"passage_finished":
			if envelope.kind != "passage.finish" or not _equal(result, {"kind": "passage_finished", "passage_id": envelope.payload.passage_id}):
				return _fail(&"scene_result_invalid")
		"thought_resolved":
			if envelope.kind not in ["thought.accept", "thought.pass", "thought.options", "thought.select"] \
					or not _equal(result, thought_result(envelope)):
				return _fail(&"scene_result_invalid")
			if not _table_has(targets, result.target_id) or targets[result.target_id].target.kind != "scene":
				return _fail(&"scene_result_invalid")
		"notification_updated":
			if not _keys(result, ["kind", "notification"]) or envelope.kind not in ["notification.set", "notification.clear"]:
				return _fail(&"scene_result_invalid")
			var expected: Dictionary = envelope.payload if envelope.kind == "notification.set" else {}
			if not _equal(result.notification, expected): return _fail(&"scene_result_invalid")
		"scene_transition_accepted":
			if not _keys(result, ["kind", "source_scene_occurrence", "target_id", "target", "resolution_receipt"]) \
					or envelope.kind != "scene.transition" or not _id(result.source_scene_occurrence) \
					or result.source_scene_occurrence != envelope.source.scene_occurrence \
					or result.target_id != envelope.payload.target_id or not _table_has(targets, result.target_id): return _fail(&"scene_result_invalid")
			if not _equal(targets[result.target_id].target, result.target) or result.target.kind not in ["scene", "ending"] \
					or not _keys(result.resolution_receipt, ["receipt_id", "provenance"]) \
					or not _id(result.resolution_receipt.receipt_id) or not result.resolution_receipt.provenance is Dictionary:
				return _fail(&"scene_result_invalid")
		"challenge_playable":
			if not _keys(result, ["kind", "challenge_occurrence"]) or envelope.kind != "challenge.playable" \
					or not _hash(result.challenge_occurrence): return _fail(&"scene_result_invalid")
			if result.challenge_occurrence != _sha([envelope.source.scene_occurrence, envelope.payload.challenge_id]):
				return _fail(&"scene_result_invalid")
		"challenge_closed":
			if not _keys(result, ["kind", "challenge_occurrence", "playable_command_id", "attempt_proof", "outcome", "target_id"]) \
					or envelope.kind != "challenge.end" or typeof(result.outcome) != TYPE_STRING \
					or result.outcome not in OUTCOMES or not _id(result.target_id) or not _hash(result.challenge_occurrence):
				return _fail(&"scene_result_invalid")
			var challenge: Dictionary = registered.value.challenges[envelope.payload.challenge_id]
			var occurrence := _sha([envelope.source.scene_occurrence, envelope.payload.challenge_id])
			if result.challenge_occurrence != occurrence or not _id(result.playable_command_id) \
					or not challenge.targets.has(result.outcome) or result.target_id != challenge.targets[result.outcome]: return _fail(&"scene_result_invalid")
			if result.outcome == "never_started":
				if result.attempt_proof != null: return _fail(&"scene_attempt_proof_invalid")
			elif not _attempt_proof(result.attempt_proof, envelope.source.run_id): return _fail(&"scene_attempt_proof_invalid")
		"challenge_recalled":
			if not _keys(result, ["kind", "outcome", "target_id"]) \
					or envelope.kind != "challenge.recall" \
					or typeof(result.outcome) != TYPE_STRING or result.outcome not in OUTCOMES \
					or result.target_id != envelope.payload[result.outcome + "_target_id"] \
					or not _table_has(targets, result.target_id) or targets[result.target_id].target.kind != "scene":
				return _fail(&"scene_result_invalid")
		"contact_entry_accepted":
			if not _keys(result, ["kind", "target_id", "source_fact_ids"]) or envelope.kind != "contact.enter":
				return _fail(&"scene_result_invalid")
			var contact: Dictionary = registered.value.contacts[envelope.payload.contact_event_id]
			var target_id := ""
			for id: String in targets:
				if targets[id].target.kind == "contact" and targets[id].target.entry_id == contact.entry_id:
					if not target_id.is_empty(): return _fail(&"scene_contact_target_ambiguous")
					target_id = id
			if target_id.is_empty() or result.target_id != target_id or not _equal(result.source_fact_ids, contact.source_fact_ids):
				return _fail(&"scene_result_invalid")
		"contact_returned":
			if not _keys(result, ["kind", "contact_admission_receipt_id", "target_id", "parent_occurrence_id"]) \
					or envelope.kind != "contact.return" or not _id(result.contact_admission_receipt_id) \
					or not _id(result.parent_occurrence_id) or not _id(result.target_id): return _fail(&"scene_result_invalid")
			if result.target_id != registered.value.contacts[envelope.payload.contact_event_id].return_target_id:
				return _fail(&"scene_result_invalid")
		_:
			return _fail(&"scene_result_unsupported")
	return {"ok": true}

## Current recall reads only this Run's explicit outcomes. It never closes a board,
## consults newer Profile attempts, or reapplies consequences.
static func resolve_scene_challenge_recall(event: Dictionary, outcomes: Variant, bundle: Dictionary) -> Dictionary:
	var checked := _inspect_scene_context(event, bundle)
	if not checked.ok: return checked
	if event.kind != "challenge.recall" or not _positive_int(event.issuer_receipt.get("counter")):
		return _fail(&"scene_challenge_recall_invalid")
	# This selector uses its explicitly validated bundle, not a second global
	# registration lookup. Save admission separately checks all registered facts.
	if not outcomes is Dictionary: return _fail(&"scene_challenge_recall_invalid")
	for occurrence: Variant in outcomes:
		var outcome: Variant = outcomes[occurrence]
		if not _hash(occurrence) or (not _keys(outcome, ["challenge_id", "outcome"]) \
				and not _keys(outcome, ["challenge_id", "outcome", "physical_slot"])) \
				or not _id(outcome.challenge_id) \
				or outcome.outcome not in ["never_started", "unfinished", "lost", "won", "perfect"]:
			return _fail(&"scene_challenge_recall_invalid")
		var slot: Variant = outcome.get("physical_slot", "")
		if not slot is String or (slot != "" and (not slot.begins_with("scene.challenge.") \
				or not _hash(slot.trim_prefix("scene.challenge.")))) \
				or (outcome.outcome == "never_started" and slot != ""):
			return _fail(&"scene_challenge_recall_invalid")
	var found := {}
	for outcome: Dictionary in outcomes.values():
		if outcome.challenge_id != event.payload.challenge_id: continue
		if not found.is_empty(): return _fail(&"scene_challenge_recall_ambiguous")
		found = {"kind": "challenge_recalled", "outcome": outcome.outcome,
			"target_id": event.payload[outcome.outcome + "_target_id"]}
	if found.is_empty(): return _fail(&"scene_challenge_recall_missing")
	return {"ok": true, "value": found}

## Private join for _validate_scene_receipts_registered only: its first pass has
## reconstructed and authenticated every command and bound the recall event.
## Historical recalls exclude closures issued later, even when current facts include them.
static func _resolve_scene_challenge_recall_history(event: Dictionary, commands: Dictionary) -> Dictionary:
	var found := {}
	for receipt: Dictionary in commands.values():
		var saved: Dictionary = receipt.scene_event
		if saved.result.kind != "challenge_closed": continue
		var semantic: Dictionary = saved.semantic
		if semantic.source.run_id != event.source.run_id \
				or semantic.payload.challenge_id != event.payload.challenge_id \
				or semantic.issuer_receipt.counter >= event.issuer_receipt.counter: continue
		if not found.is_empty(): return _fail(&"scene_challenge_recall_ambiguous")
		found = {"kind": "challenge_recalled", "outcome": saved.result.outcome,
			"target_id": event.payload[saved.result.outcome + "_target_id"]}
	if found.is_empty(): return _fail(&"scene_challenge_recall_missing")
	return {"ok": true, "value": found}

static func _completion_matches(parent: Dictionary, request: Dictionary, completion: Dictionary) -> bool:
	if not _id(parent.get("namespace")) or not _positive_int(parent.get("counter")): return false
	var child := "scene_day_completion." + ("desktop_child_v1\n%s\n%d\n%s\n%s\n%d\n%s" % [
		parent.namespace, parent.counter, request.parent_receipt_id, request.child_kind, request.ordinal,
		WRITER.stringify(request.source_ids).value]).sha256_text()
	return _equal(completion, {"receipt_id": child, "provenance": {"schema_version": 1,
		"parent_receipt_id": request.parent_receipt_id, "child_kind": request.child_kind,
		"ordinal": request.ordinal, "source_ids": request.source_ids, "child_id": child}})

## Shape only: GameState closure admission joins this retained physical slot to
## the exact selected record/ref and the current authenticated story binding.
static func _attempt_proof(proof: Variant, run_id: String) -> bool:
	if not _keys(proof, ["run_id", "slot_id", "attempt_id", "branch_id", "generation", "revision", "record_sha256", "publication"]): return false
	if not _id(proof.run_id) or not _id(proof.slot_id) or proof.run_id != run_id \
			or not str(proof.slot_id).begins_with("scene.challenge.") \
			or not _hash(str(proof.slot_id).trim_prefix("scene.challenge.")): return false
	return _id(proof.attempt_id) and _id(proof.branch_id) and _positive_int(proof.generation) \
		and _positive_int(proof.revision) and _hash(proof.record_sha256) \
		and _keys(proof.publication, ["kind", "state_sha256"]) \
		and proof.publication.kind == "live" and _hash(proof.publication.state_sha256)

static func validate_scene_admission(result: Variant, bundle: Dictionary) -> Dictionary:
	var checked := validate_bundle_structure(bundle)
	if not checked.ok: return checked
	return _validate_scene_admission_registered(result, checked)

# Reuse only immediately computed pure tables, never across an authority callback.
static func _validate_scene_admission_registered(result: Variant, checked: Dictionary) -> Dictionary:
	if not _json_data(result) or not _keys(result, ["kind", "occurrence_id", "entry_id", "target_id", "source_checkpoint", "trigger_command_id", "return_to"]) \
			or typeof(result.kind) != TYPE_STRING or result.kind != "scene_admitted" \
			or not _id(result.occurrence_id) or not _id(result.entry_id) \
			or not _table_has(checked.value.targets, result.target_id) or not _checkpoint(result.source_checkpoint):
		return _fail(&"scene_admission_invalid")
	var target: Dictionary = checked.value.targets[result.target_id].target
	if target.entry_id != result.entry_id or target.kind not in ["scene", "contact"]: return _fail(&"scene_admission_invalid")
	if result.trigger_command_id != null and not _id(result.trigger_command_id): return _fail(&"scene_admission_invalid")
	if target.kind != "contact":
		if result.return_to != null: return _fail(&"scene_admission_invalid")
	else:
		var back: Variant = result.return_to
		if not _id(result.trigger_command_id) or not _keys(back, ["scene_occurrence", "admission_receipt_id", "entry_id", "target_id", "source_checkpoint"]):
			return _fail(&"scene_admission_invalid")
		if not _id(back.scene_occurrence) or not _id(back.admission_receipt_id) or not _id(back.entry_id) or not _checkpoint(back.source_checkpoint) \
				or not _table_has(checked.value.targets, back.target_id): return _fail(&"scene_admission_invalid")
		var return_target: Dictionary = checked.value.targets[back.target_id].target
		if return_target.kind != "return" or return_target.entry_id != back.entry_id: return _fail(&"scene_admission_invalid")
	# Pristine NewRun, issuer-backed occurrence and checkpoint/parent receipt resolution
	# are authenticated by the live owner, not by this structural helper.
	return {"ok": true}

static func _checkpoint(value: Variant) -> bool:
	return _keys(value, CHECKPOINT_KEYS) and _id(value.checkpoint_id) and _positive_int(value.checkpoint_sequence) and _hash(value.snapshot_sha256)


## Full scene command ledger admission. The Run owner separately checks the applied
## effect/variable partitions, physical Profile proofs and anchors against the actual ledger.
static func validate_scene_receipts(receipts: Dictionary, bundle: Dictionary, issuer: Object,
		creation_owner: Object = null, contacts: Dictionary = {}) -> Dictionary:
	var started_us: int = _VALIDATION_TIMING.start_sample()
	var result: Dictionary = _validate_scene_receipts_observed_body(receipts, bundle, issuer, creation_owner, contacts)
	_VALIDATION_TIMING.finish_sample("receipt_validation", started_us, bool(result.get("ok", false)))
	return result

## Bound callers select the canonical owner directly; no caller-supplied proof.
static func validate_selected_scene_receipts(receipts: Dictionary, issuer: Object,
		creation_owner: Object = null, contacts: Dictionary = {}) -> Dictionary:
	var started_us: int = _VALIDATION_TIMING.start_sample()
	var result := _validate_selected_scene_receipts(receipts, issuer, creation_owner, contacts)
	_VALIDATION_TIMING.finish_sample("receipt_validation", started_us, bool(result.get("ok", false)))
	return result

static func _validate_selected_scene_receipts(receipts: Dictionary, issuer: Object,
		creation_owner: Object, contacts: Dictionary) -> Dictionary:
	if not _json_data(receipts): return _fail(&"scene_receipt_invalid")
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	var manifest: Script = load("res://scripts/narrative/DialogicEntryManifest.gd")
	var registered: Dictionary = manifest.scene_contract_tables()
	if not registered.ok: return registered
	return _validate_scene_receipts_registered(receipts, registered.bundle, registered, issuer, creation_owner, contacts)

static func _validate_scene_receipts_observed_body(receipts: Dictionary, bundle: Dictionary, issuer: Object,
		creation_owner: Object = null, contacts: Dictionary = {}) -> Dictionary:
	if not _json_data(receipts): return _fail(&"scene_receipt_invalid")
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	var registered := validate_bundle_structure(bundle)
	if not registered.ok: return registered
	return _validate_scene_receipts_registered(receipts, bundle, registered, issuer, creation_owner, contacts)

static func _validate_scene_receipts_registered(receipts: Dictionary, bundle: Dictionary, registered: Dictionary, issuer: Object,
		creation_owner: Object, contacts: Dictionary) -> Dictionary:
	var occurrences := {}
	var commands := {}
	var admissions := {}
	var admission_receipts := {}
	var shop_purchases := {}
	var completed_rounds := {}
	var resolved_thoughts := {}
	for command: Variant in receipts:
		var receipt: Variant = receipts[command]
		if not _id(command) or not receipt is Dictionary or receipt.get("transaction_id") != command:
			return _fail(&"scene_receipt_identity_invalid")
		if receipt.get("kind") in ["effect_transaction", "variable_transaction"]:
			if not _keys(receipt, ["kind", "request_fingerprint", "source_id", "transaction_id"]) \
					or not _hash(receipt.request_fingerprint) or not _id(receipt.source_id):
				return _fail(&"scene_receipt_invalid")
			continue
		if receipt.get("kind") == "scene_round_completion":
			var completed := validate_scene_round_completion(receipt, issuer)
			if not completed.ok: return completed
			var board_key := _sha(receipt.scene_round_completion.completion.board_identity)
			if completed_rounds.has(board_key): return _fail(&"scene_round_already_completed")
			completed_rounds[board_key] = command
			shop_purchases[command] = receipt
			continue
		if receipt.get("kind") == "scene_shop_purchase":
			var purchased := validate_scene_shop_purchase(receipt, issuer)
			if not purchased.ok: return purchased
			shop_purchases[command] = receipt
			continue
		if receipt.get("kind") == "scene_admission":
			var admitted: Dictionary
			if receipt.get("scene_admission") is Dictionary and receipt.scene_admission.get("schema_version") == 3:
				admitted = _validate_committed_initial_admission(receipt, registered, issuer, creation_owner)
			else:
				admitted = _validate_scene_admission_receipt(receipt, registered, issuer)
			if not admitted.ok: return admitted
			admissions[command] = receipt.scene_admission.result.duplicate(true)
			admission_receipts[command] = receipt.duplicate(true)
			continue
		if receipt.get("kind") != "scene_event" or not _keys(receipt, RECEIPT_KEYS):
			return _fail(&"scene_receipt_kind_invalid")
		var saved: Variant = receipt.scene_event
		if not _keys(saved, SAVED_EVENT_KEYS) or typeof(saved.schema_version) != TYPE_INT \
				or saved.schema_version != 2 or not saved.semantic is Dictionary \
				or saved.semantic.has("playback_token") or not saved.reading_anchor is Dictionary \
				or not saved.result is Dictionary:
			return _fail(&"scene_receipt_invalid")
		var envelope: Dictionary = saved.semantic.duplicate(true)
		envelope["playback_token"] = "receipt.validation"
		# This call already admitted the bundle; only the receipt's envelope is new.
		var shaped := _inspect_scene_versioned_shape(envelope)
		if not shaped.ok: return shaped
		var context := _bind_scene_context(envelope, shaped, registered)
		if not context.ok: return context
		var rebuilt := _make_scene_receipt_from_context(envelope, saved.reading_anchor, saved.result, context)
		if not rebuilt.ok: return rebuilt
		if not _equal(receipt, rebuilt.value): return _fail(&"scene_receipt_mismatch")
		var issued: Dictionary = issuer.call(&"verify_issued", envelope.issuer_receipt.duplicate(true), &"transaction_id")
		if not issued.get("ok", false): return issued
		if saved.result.kind == "scene_transition_accepted":
			var child: Dictionary = issuer.call(&"validate_child", saved.result.resolution_receipt.provenance.duplicate(true), &"scene_day_completion")
			if not child.get("ok", false): return child
		if saved.result.kind == "thought_resolved":
			var thought_key := _sha([envelope.source.run_id, saved.result.opportunity_id])
			if resolved_thoughts.has(thought_key): return _fail(&"scene_thought_already_resolved")
			resolved_thoughts[thought_key] = command
		var key := occurrence_key(envelope.source)
		if not occurrences.has(key):
			occurrences[key] = {"source": envelope.source.duplicate(true), "next_ordinal": 0,
				"predecessor": "", "receipts": [], "notification": {}}
		var group: Dictionary = occurrences[key]
		if not _equal(group.source, envelope.source): return _fail(&"scene_receipt_source_changed")
		if not group.receipts.is_empty():
			var prior_anchor: Dictionary = group.receipts[0].scene_event.reading_anchor
			for field: String in ["session_id", "entry_id", "content_version", "catalogue_fingerprint"]:
				if not _equal(prior_anchor[field], saved.reading_anchor[field]): return _fail(&"event_anchor_changed")
		group.receipts.append(receipt.duplicate(true))
		commands[command] = receipt.duplicate(true)
	for purchase_receipt: Dictionary in shop_purchases.values():
		var source_id: String = purchase_receipt.source_id
		if not admission_receipts.has(source_id): return _fail(&"scene_shop_admission_missing")
		var source_admission: Dictionary = admission_receipts[source_id].scene_admission
		var purchase: Dictionary = purchase_receipt.get("scene_shop_purchase", purchase_receipt.get("scene_round_completion", {}))
		if source_admission.source_identity.run_id != purchase.source_identity.run_id \
				or source_admission.issuer_receipt.counter >= purchase.issuer_receipt.counter:
			return _fail(&"scene_shop_admission_mismatch")
	for group: Dictionary in occurrences.values():
		var occurrence: String = group.source.scene_occurrence
		if not admissions.has(occurrence): return _fail(&"scene_admission_missing")
		var admission: Dictionary = admissions[occurrence]
		if admission.entry_id != group.source.entry_id \
				or admission_receipts[occurrence].scene_admission.source_identity.run_id != group.source.run_id:
			return _fail(&"scene_admission_source_mismatch")
		group.receipts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.scene_event.semantic.ordinal < b.scene_event.semantic.ordinal)
		var seen := {}
		var transitioned := false
		var contact_child: bool = admission.get("return_to") != null
		for receipt: Dictionary in group.receipts:
			var semantic: Dictionary = receipt.scene_event.semantic
			if transitioned or semantic.ordinal != group.next_ordinal or semantic.predecessor != group.predecessor \
					or seen.has(semantic.event_id): return _fail(&"scene_receipt_chain_invalid")
			if semantic.kind == "notification.clear" and group.notification.get("notification_id") != semantic.payload.notification_id:
				return _fail(&"event_notification_clear_invalid")
			if semantic.kind in ["notification.set", "notification.clear"]:
				group.notification = receipt.scene_event.result.notification.duplicate(true)
			if contact_child and semantic.kind in ["passage.finish", "contact.enter", "scene.transition", "challenge.end", "challenge.recall", "thought.accept", "thought.pass", "thought.options", "thought.select"]:
				return _fail(&"scene_contact_exit_refused")
			transitioned = semantic.kind in ["passage.finish", "scene.transition", "contact.return", "challenge.recall", "thought.accept", "thought.pass", "thought.options", "thought.select"]
			seen[semantic.event_id] = true
			group.next_ordinal += 1
			group.predecessor = semantic.event_id
	for receipt: Dictionary in commands.values():
		var semantic: Dictionary = receipt.scene_event.semantic
		var result: Dictionary = receipt.scene_event.result
		if result.kind == "challenge_closed":
			if not commands.has(result.playable_command_id): return _fail(&"scene_playable_receipt_missing")
			var playable: Dictionary = commands[result.playable_command_id].scene_event.semantic
			var playable_result: Dictionary = commands[result.playable_command_id].scene_event.result
			if playable.kind != "challenge.playable" or not _equal(playable.source, semantic.source) \
					or playable.payload.challenge_id != semantic.payload.challenge_id or playable.ordinal >= semantic.ordinal \
					or playable_result.kind != "challenge_playable" or playable_result.challenge_occurrence != result.challenge_occurrence:
				return _fail(&"scene_playable_receipt_mismatch")
		elif result.kind == "challenge_recalled":
			var recalled := _resolve_scene_challenge_recall_history(semantic, commands)
			if not recalled.ok: return recalled
			if not _equal(result, recalled.value): return _fail(&"scene_challenge_recall_mismatch")
		elif result.kind == "contact_entry_accepted":
			var contact_owner: Script = load("res://scripts/domain/contact/ContactInvitationState.gd")
			if contact_owner == null: return _fail(&"scene_contact_owner_unavailable")
			var facts: Dictionary = contact_owner.validate_scene_facts(
				contacts, result.source_fact_ids, registered.value.fingerprint, issuer)
			if not facts.get("ok", false): return facts
			for fact: Dictionary in facts.value.receipts:
				if fact.receipt.context.identity.run_id != semantic.source.run_id \
						or fact.receipt.command_issuer_receipt.counter >= semantic.issuer_receipt.counter:
					return _fail(&"scene_contact_fact_source_mismatch")
			if admissions[semantic.source.scene_occurrence].get("return_to") != null:
				return _fail(&"scene_contact_nested")
		elif result.kind == "contact_returned":
			if result.contact_admission_receipt_id != semantic.source.scene_occurrence \
					or not admissions.has(result.contact_admission_receipt_id): return _fail(&"scene_contact_admission_missing")
			var called: Dictionary = admissions[result.contact_admission_receipt_id]
			if called.get("return_to") == null or not commands.has(called.trigger_command_id):
				return _fail(&"scene_contact_return_mismatch")
			var entry_event: Dictionary = commands[called.trigger_command_id].scene_event
			if semantic.issuer_receipt.counter <= admission_receipts[result.contact_admission_receipt_id].scene_admission.issuer_receipt.counter \
					or entry_event.semantic.kind != "contact.enter" \
					or entry_event.semantic.payload.contact_event_id != semantic.payload.contact_event_id \
					or result.parent_occurrence_id != called.return_to.scene_occurrence \
					or result.target_id != called.return_to.target_id:
				return _fail(&"scene_contact_return_mismatch")
	var roots := {}
	var triggers := {}
	for admission_id: String in admissions:
		var admission: Dictionary = admissions[admission_id]
		var identity: Dictionary = admission_receipts[admission_id].scene_admission.source_identity
		if admission.kind == "scene_initial_admitted":
			if roots.has(identity.run_id): return _fail(&"scene_admission_root_conflict")
			roots[identity.run_id] = admission_id
			continue
		if admission.trigger_command_id == null:
			if admission.return_to != null or roots.has(identity.run_id): return _fail(&"scene_admission_root_conflict")
			roots[identity.run_id] = admission_id
			continue
		if not commands.has(admission.trigger_command_id) or triggers.has(admission.trigger_command_id):
			return _fail(&"scene_admission_trigger_missing")
		triggers[admission.trigger_command_id] = admission_id
		var trigger: Dictionary = commands[admission.trigger_command_id].scene_event
		if trigger.semantic.source.run_id != identity.run_id: return _fail(&"scene_admission_source_mismatch")
		if admission.return_to != null:
			var back: Dictionary = admission.return_to
			var parent: Dictionary = admissions.get(back.admission_receipt_id, {})
			if trigger.result.kind != "contact_entry_accepted" or trigger.result.target_id != admission.target_id \
					or parent.is_empty() or parent.get("return_to") != null \
					or back.scene_occurrence != parent.occurrence_id or back.entry_id != parent.entry_id \
					or trigger.semantic.source.scene_occurrence != back.scene_occurrence \
					or not _equal(back.source_checkpoint, admission.source_checkpoint) \
					or back.target_id != registered.value.contacts[trigger.semantic.payload.contact_event_id].return_target_id:
				return _fail(&"scene_contact_parent_mismatch")
		elif trigger.result.kind not in ["scene_transition_accepted", "challenge_closed", "challenge_recalled", "thought_resolved"] or trigger.result.target_id != admission.target_id:
			return _fail(&"scene_admission_trigger_mismatch")
		var boundary := scene_day_boundary(bundle, trigger.semantic.source.entry_id, admission.entry_id)
		if not boundary.ok: return boundary
		if boundary.value:
			if trigger.result.kind != "scene_transition_accepted" or admission.return_to != null:
				return _fail(&"scene_day_transition_required")
			var day_allocation := validate_scene_day_allocation(commands[admission.trigger_command_id], identity, issuer)
			if not day_allocation.ok: return day_allocation
		var source_admission: Dictionary = admission_receipts.get(trigger.semantic.source.scene_occurrence, {})
		if source_admission.is_empty() or source_admission.scene_admission.issuer_receipt.counter >= admission_receipts[admission_id].scene_admission.issuer_receipt.counter:
			return _fail(&"scene_admission_cycle")
	# A suspended parent cannot allocate another exit until its child has returned.
	# Issuer order is already the admission ancestry order; Load retains these bytes.
	for entry_receipt: Dictionary in commands.values():
		if entry_receipt.scene_event.result.kind != "contact_entry_accepted": continue
		var entered: Dictionary = entry_receipt.scene_event.semantic
		var child_id: String = str(triggers.get(entered.command_id, ""))
		var returned_counter := -1
		for receipt: Dictionary in commands.values():
			var event: Dictionary = receipt.scene_event
			if event.result.kind == "contact_returned" and event.result.contact_admission_receipt_id == child_id:
				if returned_counter != -1: return _fail(&"scene_contact_return_duplicate")
				returned_counter = event.semantic.issuer_receipt.counter
		for receipt: Dictionary in commands.values():
			var event: Dictionary = receipt.scene_event.semantic
			if event.source.scene_occurrence != entered.source.scene_occurrence or event.ordinal <= entered.ordinal: continue
			if event.kind in ["contact.enter", "scene.transition", "challenge.end", "challenge.recall", "thought.accept", "thought.pass", "thought.options", "thought.select"] \
					and (returned_counter < 0 or event.issuer_receipt.counter <= returned_counter):
				return _fail(&"scene_contact_exit_refused")
	for receipt: Dictionary in admission_receipts.values():
		if not roots.has(receipt.scene_admission.source_identity.run_id): return _fail(&"scene_admission_root_missing")
	return {"ok": true, "value": {"admissions": admissions, "admission_receipts": admission_receipts,
		"occurrences": occurrences, "commands": commands}}

## A scene admission has its own issued command root; it is not a fabricated DTL
## marker. The existing child derivation authenticates the complete request.
static func make_scene_admission(identity: Dictionary, root_issuer_receipt: Dictionary,
		target_id: String, source_checkpoint: Dictionary, trigger_command_id: Variant,
		return_to: Variant, bundle: Dictionary, issuer: Object) -> Dictionary:
	var identity_ok := _validate_scene_admission_identity(identity, root_issuer_receipt, issuer)
	if not identity_ok.ok: return identity_ok
	var registered := validate_bundle_structure(bundle)
	if not registered.ok: return registered
	return _make_scene_admission_registered(identity, root_issuer_receipt, target_id,
		source_checkpoint, trigger_command_id, return_to, registered, issuer)


static func _validate_scene_admission_identity(identity: Dictionary,
		root_issuer_receipt: Dictionary, issuer: Object) -> Dictionary:
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	if not _json_data(identity) or not _keys(identity, ["run_id", "branch_id",
			"desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]):
		return _fail(&"scene_admission_identity_invalid")
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if not _id(identity[key]): return _fail(&"scene_admission_identity_invalid")
	if typeof(identity.desktop_timeline_generation) != TYPE_INT or identity.desktop_timeline_generation < 0 \
			or not identity.causal_day_instance_issuer_receipt is Dictionary \
			or identity.causal_day_instance_issuer_receipt.get("token") != identity.causal_day_instance:
		return _fail(&"scene_admission_identity_invalid")
	var issued: Dictionary = issuer.verify_issued(root_issuer_receipt, &"transaction_id")
	if not issued.get("ok", false): return issued
	var causal: Dictionary = issuer.verify_issued(identity.causal_day_instance_issuer_receipt, &"causal_day_instance")
	if not causal.get("ok", false): return causal
	var allocated := _scene_admission_identity_proof(identity, issuer)
	if not allocated.ok: return allocated
	return {"ok": true}


## Call-local structural tables; identity proofs remain freshly checked by both callers.
static func _make_scene_admission_registered(identity: Dictionary, root_issuer_receipt: Dictionary,
		target_id: String, source_checkpoint: Dictionary, trigger_command_id: Variant,
		return_to: Variant, registered: Dictionary, issuer: Object) -> Dictionary:
	if not registered.value.targets.has(target_id): return _fail(&"scene_target_unregistered")
	var target: Dictionary = registered.value.targets[target_id].target
	if target.kind not in ["scene", "contact"]: return _fail(&"scene_admission_invalid")
	var result := {"kind": "scene_admitted", "occurrence_id": root_issuer_receipt.token,
		"entry_id": target.entry_id, "target_id": target_id, "source_checkpoint": source_checkpoint.duplicate(true),
		"trigger_command_id": trigger_command_id, "return_to": _scene_detach(return_to)}
	var valid := _validate_scene_admission_registered(result, registered)
	if not valid.ok: return valid
	var request := {"schema_version": 2, "kind": "scene_admission",
		"source_identity": identity.duplicate(true), "registration_fingerprint": registered.value.fingerprint,
		"issuer_receipt": root_issuer_receipt.duplicate(true), "target_id": target_id,
		"source_checkpoint": source_checkpoint.duplicate(true), "trigger_command_id": trigger_command_id,
		"return_to": _scene_detach(return_to)}
	var fingerprint := _sha(request)
	if fingerprint.is_empty(): return _fail(&"scene_admission_invalid")
	var source_ids: Array[String] = [
		"request_fingerprint=" + str(WRITER.stringify(fingerprint).value), 'role="scene.admission"']
	source_ids.sort()
	var child: Dictionary = issuer.derive_child({"parent_receipt_id": root_issuer_receipt.receipt_id,
		"child_kind": "continuation_operation", "ordinal": 0, "source_ids": source_ids})
	if not child.get("ok", false): return child
	return {"ok": true, "value": {"transaction_id": root_issuer_receipt.token,
		"request_fingerprint": fingerprint, "kind": "scene_admission", "source_id": root_issuer_receipt.token,
		"scene_admission": {"schema_version": 2, "registration_fingerprint": registered.value.fingerprint,
			"source_identity": identity.duplicate(true), "issuer_receipt": root_issuer_receipt.duplicate(true),
			"provenance": child.value.provenance.duplicate(true), "result": result}}}


static func _validate_scene_admission_receipt(receipt: Dictionary, registered: Dictionary, issuer: Object) -> Dictionary:
	if not _keys(receipt, ["transaction_id", "request_fingerprint", "kind", "source_id", "scene_admission"]):
		return _fail(&"scene_admission_receipt_invalid")
	var saved: Variant = receipt.scene_admission
	if not _keys(saved, ["schema_version", "registration_fingerprint", "source_identity", "issuer_receipt", "provenance", "result"]) \
			or typeof(saved.schema_version) != TYPE_INT or saved.schema_version != 2 \
			or not saved.source_identity is Dictionary or not saved.issuer_receipt is Dictionary \
			or not saved.provenance is Dictionary or not saved.result is Dictionary:
		return _fail(&"scene_admission_receipt_invalid")
	var result: Dictionary = saved.result
	var result_ok := _validate_scene_admission_registered(result, registered)
	if not result_ok.ok: return result_ok
	var identity_ok := _validate_scene_admission_identity(saved.source_identity, saved.issuer_receipt, issuer)
	if not identity_ok.ok: return identity_ok
	var rebuilt := _make_scene_admission_registered(saved.source_identity, saved.issuer_receipt, result.target_id,
		result.source_checkpoint, result.trigger_command_id, result.return_to, registered, issuer)
	if not rebuilt.ok: return rebuilt
	if not _equal(receipt, rebuilt.value): return _fail(&"scene_admission_receipt_mismatch")
	var proven: Dictionary = issuer.validate_child(saved.provenance, &"continuation_operation")
	if not proven.get("ok", false): return proven
	return {"ok": true}


## Prepared initial admission proves reproducible material only. It never grants
## committed Load authority or a live session before the owning creation completes.
static func prepare_scene_initial_admission(allocation_candidate: Dictionary,
		profile_material: Dictionary, target_id: String, bundle: Dictionary, issuer: Object) -> Dictionary:
	var materials := _validate_initial_materials(allocation_candidate, profile_material, issuer)
	if not materials.ok: return materials
	var registered := validate_bundle_structure(bundle)
	if not registered.ok: return registered
	return _prepare_scene_initial_admission_registered(allocation_candidate, profile_material, target_id, registered, issuer)


## Only structural registration tables are reused; materials and creation proofs stay fresh.
static func _prepare_scene_initial_admission_registered(allocation_candidate: Dictionary,
		profile_material: Dictionary, target_id: String, registered: Dictionary, issuer: Object) -> Dictionary:
	if not registered.value.targets.has(target_id): return _fail(&"scene_target_unregistered")
	var target: Dictionary = registered.value.targets[target_id].target
	if target.kind != "scene": return _fail(&"scene_initial_target_invalid")
	var identity := {}
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]:
		identity[key] = _scene_detach(allocation_candidate[key])
	var root: Dictionary = allocation_candidate.request.transaction_issuer_receipt
	var request := {"schema_version": 3, "kind": "scene_initial_admission",
		"registration_fingerprint": registered.value.fingerprint, "source_identity": identity,
		"issuer_receipt": root.duplicate(true), "allocation_candidate_sha256": _sha(allocation_candidate),
		"scene_assignment_sha256": _sha(profile_material.scene_assignment.receipt), "target_id": target_id}
	var fingerprint := _sha(request)
	var projections: Array[String] = ["request_fingerprint=" + str(WRITER.stringify(fingerprint).value), 'role="scene.initial_admission"']
	projections.sort()
	var child: Dictionary = issuer.derive_child({"parent_receipt_id": root.receipt_id,
		"child_kind": "continuation_operation", "ordinal": 0, "source_ids": projections})
	if not child.get("ok", false): return child
	return {"ok": true, "value": {"transaction_id": root.token, "request_fingerprint": fingerprint,
		"kind": "scene_admission", "source_id": root.token, "scene_admission": {
			"schema_version": 3, "registration_fingerprint": registered.value.fingerprint,
			"source_identity": identity, "issuer_receipt": root.duplicate(true),
			"allocation_candidate_sha256": request.allocation_candidate_sha256,
			"scene_assignment_sha256": request.scene_assignment_sha256,
			"provenance": child.value.provenance.duplicate(true), "result": {
				"kind": "scene_initial_admitted", "occurrence_id": root.token,
				"entry_id": target.entry_id, "target_id": target_id}}}}


static func validate_scene_initial_admission_candidate(receipt: Dictionary,
		allocation_candidate: Dictionary, profile_material: Dictionary,
		bundle: Dictionary, issuer: Object) -> Dictionary:
	var shaped := _validate_scene_initial_receipt_shape(receipt)
	if not shaped.ok: return shaped
	var materials := _validate_initial_materials(allocation_candidate, profile_material, issuer)
	if not materials.ok: return materials
	var registered := validate_bundle_structure(bundle)
	if not registered.ok: return registered
	return _validate_scene_initial_admission_registered(receipt, allocation_candidate, profile_material, registered, issuer)


static func _validate_scene_initial_receipt_shape(receipt: Dictionary) -> Dictionary:
	if not _json_data(receipt) or not _keys(receipt, ["transaction_id", "request_fingerprint", "kind", "source_id", "scene_admission"]):
		return _fail(&"scene_initial_receipt_invalid")
	var saved: Variant = receipt.scene_admission
	if not _keys(saved, ["schema_version", "registration_fingerprint", "source_identity", "issuer_receipt",
			"allocation_candidate_sha256", "scene_assignment_sha256", "provenance", "result"]) \
			or typeof(saved.schema_version) != TYPE_INT or saved.schema_version != 3 \
			or not _keys(saved.result, ["kind", "occurrence_id", "entry_id", "target_id"]) \
			or not _id(saved.result.target_id): return _fail(&"scene_initial_receipt_invalid")
	return {"ok": true}


static func _validate_scene_initial_admission_registered(receipt: Dictionary,
		allocation_candidate: Dictionary, profile_material: Dictionary,
		registered: Dictionary, issuer: Object) -> Dictionary:
	var saved: Dictionary = receipt.scene_admission
	var rebuilt := _prepare_scene_initial_admission_registered(allocation_candidate, profile_material,
		saved.result.target_id, registered, issuer)
	if not rebuilt.ok: return rebuilt
	if not _equal(receipt, rebuilt.value): return _fail(&"scene_initial_receipt_mismatch")
	var child: Dictionary = issuer.validate_child(saved.provenance, &"continuation_operation")
	if not child.get("ok", false): return child
	return {"ok": true, "value": rebuilt.value.duplicate(true)}


static func _validate_initial_materials(candidate: Dictionary, profile: Dictionary, issuer: Object) -> Dictionary:
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	if not _json_data(candidate) or not _keys(candidate, ["branch_id", "branch_id_issuer_receipt",
			"causal_day_instance", "causal_day_instance_issuer_receipt", "desktop_timeline_generation",
			"desktop_timeline_generation_issuer_receipt", "kind", "remap_transaction_issuer_receipts",
			"request", "root_namespace", "root_next_counter", "run_id", "run_id_issuer_receipt", "schema_version", "transaction_remap"]) \
			or typeof(candidate.schema_version) != TYPE_INT or candidate.schema_version != 1 \
			or candidate.kind != "new_run" or not _hash(candidate.root_namespace) \
			or typeof(candidate.root_next_counter) != TYPE_INT or candidate.root_next_counter < 1 \
			or typeof(candidate.desktop_timeline_generation) != TYPE_INT or candidate.desktop_timeline_generation != 0:
		return _fail(&"scene_initial_allocation_invalid")
	var request: Variant = candidate.request
	if not _keys(request, ["existing_run_id", "kind", "remap_source_transaction_ids", "source_desktop_timeline_generation", "transaction_id", "transaction_issuer_receipt"]) \
			or request.kind != "new_run" or request.existing_run_id != null or request.source_desktop_timeline_generation != null \
			or not request.remap_source_transaction_ids is Array or not request.remap_source_transaction_ids.is_empty() \
			or not candidate.transaction_remap is Dictionary or not candidate.transaction_remap.is_empty() \
			or not candidate.remap_transaction_issuer_receipts is Dictionary or not candidate.remap_transaction_issuer_receipts.is_empty() \
			or not _id(request.transaction_id): return _fail(&"scene_initial_allocation_invalid")
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if not _id(candidate[key]): return _fail(&"scene_initial_allocation_invalid")
	# Strict integer/null/string receipts precede issuer methods, whose historical
	# internals may coerce types. Full reproduction then authenticates their values.
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "transaction_id"]:
		var receipt: Variant = request.transaction_issuer_receipt if key == "transaction_id" else candidate[key + "_issuer_receipt"]
		if not _keys(receipt, ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]) \
				or typeof(receipt.counter) != TYPE_INT or receipt.counter < 0 \
				or not _hash(receipt.namespace) or receipt.namespace != candidate.root_namespace \
				or typeof(receipt.purpose) != TYPE_STRING or receipt.purpose != key \
				or not _id(receipt.receipt_id) or not _id(receipt.token): return _fail(&"scene_initial_allocation_invalid")
		if key == "desktop_timeline_generation":
			if typeof(receipt.numeric_value) != TYPE_INT or receipt.numeric_value != 0: return _fail(&"scene_initial_allocation_invalid")
		elif receipt.numeric_value != null or receipt.token != (request.transaction_id if key == "transaction_id" else candidate[key]):
			return _fail(&"scene_initial_allocation_invalid")
	var issued: Dictionary = issuer.verify_issued(request.transaction_issuer_receipt, &"transaction_id")
	if not issued.get("ok", false): return issued
	var reproduced: Dictionary = issuer.prepare_continuation_allocation(request.duplicate(true))
	if not reproduced.get("ok", false): return reproduced
	if not _equal(candidate, reproduced.value): return _fail(&"scene_initial_allocation_mismatch")
	if not _json_data(profile): return _fail(&"scene_initial_profile_invalid")
	var profile_owner: Script = load("res://autoload/ProfileManager.gd")
	var checked: Dictionary = profile_owner.validate_scene_new_run_material(profile)
	if not checked.get("ok", false): return checked
	if profile.scene_assignment.run_id != candidate.run_id \
			or profile.scene_assignment.receipt.creation_transaction_id != request.transaction_id:
		return _fail(&"scene_initial_assignment_mismatch")
	return {"ok": true}


static func _validate_committed_initial_admission(receipt: Dictionary, registered: Dictionary,
		issuer: Object, creation_owner: Object) -> Dictionary:
	# Caller-supplied dictionaries/callbacks cannot assert durable creation authority.
	if creation_owner == null or creation_owner.get_script() != load("res://autoload/SaveManager.gd"):
		return _fail(&"scene_creation_owner_unbound")
	var captured: Dictionary = creation_owner.call(&"capture_committed_scene_creation", receipt.transaction_id)
	if not captured.get("ok", false): return captured
	var proof: Variant = captured.get("value")
	if not proof is Dictionary or not proof.get("allocation_candidate") is Dictionary \
			or not proof.get("profile_material") is Dictionary \
			or not proof.get("initial_receipt") is Dictionary: return _fail(&"scene_creation_proof_invalid")
	var shaped := _validate_scene_initial_receipt_shape(receipt)
	if not shaped.ok: return shaped
	var materials := _validate_initial_materials(proof.allocation_candidate, proof.profile_material, issuer)
	if not materials.ok: return materials
	var validated := _validate_scene_initial_admission_registered(receipt, proof.allocation_candidate,
		proof.profile_material, registered, issuer)
	if not validated.ok: return validated
	if not _equal(receipt, proof.initial_receipt):
		return _fail(&"scene_initial_committed_receipt_mismatch")
	var root: Dictionary = issuer.capture_root()
	if not root.get("ok", false): return root
	if not _equal(root.value.get("allocation_receipts", {}).get(receipt.transaction_id), proof.allocation_candidate):
		return _fail(&"scene_initial_allocation_uncommitted")
	return validated


static func _scene_detach(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


static func _scene_admission_identity_proof(identity: Dictionary, issuer: Object) -> Dictionary:
	var captured: Dictionary = issuer.capture_root()
	if not captured.get("ok", false): return captured
	var document: Dictionary = captured.value
	for allocation: Dictionary in document.get("allocation_receipts", {}).values():
		var exact := true
		for key: String in identity:
			if not _equal(identity[key], allocation.get(key)): exact = false
		if exact: return {"ok": true}
	for allocation: Dictionary in document.get("day_advance_allocation_receipts", {}).values():
		if allocation.get("resolution_kind") != "scene_day_complete": continue
		var projected := {"run_id": allocation.get("run_id"), "branch_id": allocation.get("branch_id"),
			"desktop_timeline_generation": allocation.get("desktop_timeline_generation"),
			"causal_day_instance": allocation.get("target_causal_day_instance"),
			"causal_day_instance_issuer_receipt": allocation.get("target_causal_day_instance_issuer_receipt")}
		if _equal(identity, projected): return {"ok": true}
	return _fail(&"scene_admission_identity_unallocated")

static func _target_valid(target: Variant, entries: Dictionary) -> bool:
	if not _keys(target, TARGET_KEYS) or target.kind not in ["local", "scene", "ending", "contact", "return"] \
			or not _table_has(entries, target.entry_id) or not _id(target.label) or not _positive_int(target.content_version) \
			or not _hash(target.program_sha256): return false
	var entry: Dictionary = entries[target.entry_id]
	if target.content_version != entry.content_version or target.program_sha256 != entry.program_sha256: return false
	if target.kind in ["scene", "ending", "contact"]: return target.label == target.entry_id
	# Internal labels need not be effect markers. The trusted registration/DTL
	# owner authenticates their existence in the installed compiled programme.
	return true

static func _index_sorted(rows: Variant, key: String) -> Dictionary:
	if not rows is Array: return _fail(&"scene_table_invalid")
	var previous := ""
	var indexed := {}
	for row: Variant in rows:
		if not row is Dictionary or not _id(row.get(key)) or str(row[key]) <= previous: return _fail(&"scene_table_invalid")
		previous = row[key]
		indexed[previous] = row
	return {"ok": true, "value": indexed}

static func _sorted_ids(ids: Variant) -> bool:
	if not ids is Array: return false
	var previous := ""
	for value: Variant in ids:
		if not _id(value) or value <= previous: return false
		previous = value
	return true

static func _table_has(table: Dictionary, key: Variant) -> bool:
	return _id(key) and table.has(key)

static func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value > 0

static func _hash(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64: return false
	for index in range(64):
		if value[index] not in "0123456789abcdef": return false
	return true

static func _sha(value: Variant) -> String:
	var encoded: Dictionary = WRITER.stringify(value)
	return str(encoded.value).sha256_text() if encoded.get("ok", false) else ""

static func _equal(actual: Variant, expected: Variant) -> bool:
	if not _same_types(actual, expected): return false
	var actual_hash := _sha(actual)
	return actual_hash != "" and actual_hash == _sha(expected)

static func _json_data(value: Variant, depth: int = 0) -> bool:
	# Writer intentionally normalizes StringName; scene contracts instead require
	# JSON primitive types before hashing. Bound recursion also refuses cyclic input.
	if depth > 128: return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_ARRAY:
			for item: Variant in value:
				if not _json_data(item, depth + 1): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not _json_data(value[key], depth + 1): return false
			return true
	return false



## Terminal authority remains separate from an ordinary scene admission. The
## issued root binds the already-durable final event and its source checkpoint.
const SCENE_TERMINAL_KEYS := ["schema_version", "kind", "admission_id", "source_identity", "issuer_receipt",
	"source_occurrence_id", "source_admission_receipt_id", "trigger_command_id", "trigger_sha256",
	"source_checkpoint", "target_id", "target", "registration_fingerprint", "request_fingerprint", "provenance"]

static func make_scene_terminal_admission(identity: Dictionary, root_issuer_receipt: Dictionary,
		source_occurrence_id: String, source_admission_receipt_id: String, trigger_receipt: Dictionary,
		source_checkpoint: Dictionary, target_id: String, bundle: Dictionary, issuer: Object) -> Dictionary:
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	var registered := validate_bundle_structure(bundle)
	if not registered.ok: return registered
	return _make_scene_terminal_admission_registered(identity, root_issuer_receipt, source_occurrence_id,
		source_admission_receipt_id, trigger_receipt, source_checkpoint, target_id, registered, issuer)

static func _make_scene_terminal_admission_registered(identity: Dictionary, root_issuer_receipt: Dictionary,
		source_occurrence_id: String, source_admission_receipt_id: String, trigger_receipt: Dictionary,
		source_checkpoint: Dictionary, target_id: String, registered: Dictionary, issuer: Object) -> Dictionary:
	if not registered.value.targets.has(target_id): return _fail(&"scene_target_unregistered")
	var target: Dictionary = registered.value.targets[target_id].target
	if target.kind != "ending" or target.entry_id != "ending.alone.normal":
		return _fail(&"scene_terminal_target_invalid")
	if not trigger_receipt.get("scene_event") is Dictionary: return _fail(&"scene_terminal_trigger_invalid")
	var event: Dictionary = trigger_receipt.scene_event
	if not event.get("semantic") is Dictionary or not event.get("reading_anchor") is Dictionary \
			or not event.get("result") is Dictionary: return _fail(&"scene_terminal_trigger_invalid")
	var envelope: Dictionary = event.semantic.duplicate(true)
	envelope["playback_token"] = "terminal.validation"
	var shaped := _inspect_scene_versioned_shape(envelope)
	if not shaped.ok: return shaped
	var context := _bind_scene_context(envelope, shaped, registered)
	if not context.ok: return context
	var rebuilt := _make_scene_receipt_from_context(envelope, event.reading_anchor, event.result, context)
	if not rebuilt.ok: return rebuilt
	if not _equal(trigger_receipt, rebuilt.value) or event.result.kind != "scene_transition_accepted" \
			or event.result.target_id != target_id or event.semantic.source.scene_occurrence != source_occurrence_id \
			or source_admission_receipt_id != source_occurrence_id:
		return _fail(&"scene_terminal_trigger_invalid")
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if event.semantic.source.get(key) != identity.get(key): return _fail(&"scene_terminal_source_changed")
	var proven: Dictionary = issuer.verify_issued(event.semantic.issuer_receipt, &"transaction_id")
	if not proven.get("ok", false): return proven
	proven = issuer.validate_child(event.result.resolution_receipt.provenance, &"scene_day_completion")
	if not proven.get("ok", false): return proven
	if typeof(root_issuer_receipt.get("counter")) != TYPE_INT \
			or root_issuer_receipt.counter <= event.semantic.issuer_receipt.counter:
		return _fail(&"scene_terminal_issuer_order_invalid")
	var record := {"schema_version": 1, "kind": "scene_terminal_admission",
		"admission_id": root_issuer_receipt.get("token"), "source_identity": identity.duplicate(true),
		"issuer_receipt": root_issuer_receipt.duplicate(true), "source_occurrence_id": source_occurrence_id,
		"source_admission_receipt_id": source_admission_receipt_id,
		"trigger_command_id": trigger_receipt.get("transaction_id"), "trigger_sha256": _sha(trigger_receipt),
		"source_checkpoint": source_checkpoint.duplicate(true), "target_id": target_id,
		"target": target.duplicate(true), "registration_fingerprint": registered.value.fingerprint}
	var fingerprint := _sha(record)
	var request := _scene_terminal_child_request(root_issuer_receipt, fingerprint)
	var derived: Dictionary = issuer.derive_child(request)
	if not derived.get("ok", false): return derived
	record["request_fingerprint"] = fingerprint
	record["provenance"] = derived.value.provenance.duplicate(true)
	var checked := validate_scene_terminal_admission_shape(record, issuer)
	return {"ok": true, "value": record} if checked.ok else checked

static func _scene_terminal_child_request(root: Dictionary, fingerprint: String) -> Dictionary:
	var ids: Array[String] = ["request_fingerprint=" + str(WRITER.stringify(fingerprint).value),
		'role="scene.terminal.admission"']
	ids.sort()
	return {"parent_receipt_id": root.get("receipt_id"), "child_kind": "continuation_operation",
		"ordinal": 0, "source_ids": ids}

static func validate_scene_terminal_admission_shape(record: Variant, issuer: Object) -> Dictionary:
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	if not _json_data(record) or not _keys(record, SCENE_TERMINAL_KEYS) \
			or typeof(record.schema_version) != TYPE_INT or record.schema_version != 1 \
			or record.kind != "scene_terminal_admission" or not record.issuer_receipt is Dictionary \
			or not record.provenance is Dictionary or not _checkpoint(record.source_checkpoint) \
			or not _hash(record.trigger_sha256) or not _hash(record.registration_fingerprint) \
			or not _hash(record.request_fingerprint): return _fail(&"scene_terminal_admission_invalid")
	for key: String in ["admission_id", "source_occurrence_id", "source_admission_receipt_id", "trigger_command_id", "target_id"]:
		if not _id(record[key]): return _fail(&"scene_terminal_admission_invalid")
	if record.source_occurrence_id != record.source_admission_receipt_id \
			or record.admission_id != record.issuer_receipt.get("token") \
			or not _keys(record.target, TARGET_KEYS) or record.target.kind != "ending" \
			or record.target.entry_id != "ending.alone.normal" or record.target.label != record.target.entry_id \
			or not _positive_int(record.target.content_version) or not _hash(record.target.program_sha256):
		return _fail(&"scene_terminal_admission_invalid")
	var identity: Variant = record.source_identity
	if not _keys(identity, ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]) \
			or typeof(identity.desktop_timeline_generation) != TYPE_INT or identity.desktop_timeline_generation < 0 \
			or not identity.causal_day_instance_issuer_receipt is Dictionary \
			or identity.causal_day_instance_issuer_receipt.get("token") != identity.causal_day_instance:
		return _fail(&"scene_terminal_admission_invalid")
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if not _id(identity[key]): return _fail(&"scene_terminal_admission_invalid")
	var issued: Dictionary = issuer.verify_issued(record.issuer_receipt, &"transaction_id")
	if not issued.get("ok", false): return issued
	issued = issuer.verify_issued(identity.causal_day_instance_issuer_receipt, &"causal_day_instance")
	if not issued.get("ok", false): return issued
	var allocated := _scene_admission_identity_proof(identity, issuer)
	if not allocated.ok: return allocated
	var request: Dictionary = record.duplicate(true)
	request.erase("request_fingerprint")
	request.erase("provenance")
	if _sha(request) != record.request_fingerprint: return _fail(&"scene_terminal_admission_mismatch")
	var derived: Dictionary = issuer.derive_child(_scene_terminal_child_request(record.issuer_receipt, record.request_fingerprint))
	if not derived.get("ok", false): return derived
	if not _equal(derived.value.provenance, record.provenance): return _fail(&"scene_terminal_admission_mismatch")
	return issuer.validate_child(record.provenance, &"continuation_operation")

static func validate_scene_terminal_admission(record: Dictionary, bundle: Dictionary, issuer: Object,
		receipts: Dictionary, creation_owner: Object = null, contacts: Dictionary = {}) -> Dictionary:
	var shaped := validate_scene_terminal_admission_shape(record, issuer)
	if not shaped.get("ok", false): return shaped
	var ledger := validate_scene_receipts(receipts, bundle, issuer, creation_owner, contacts)
	if not ledger.ok: return ledger
	var source: Dictionary = ledger.value.admissions.get(record.source_admission_receipt_id, {})
	if source.is_empty() or source.get("return_to") != null:
		return _fail(&"scene_terminal_source_invalid")
	var trigger: Dictionary = ledger.value.commands.get(record.trigger_command_id, {})
	if trigger.is_empty() or _sha(trigger) != record.trigger_sha256:
		return _fail(&"scene_terminal_trigger_invalid")
	var source_receipt: Dictionary = ledger.value.admission_receipts[record.source_admission_receipt_id]
	if source_receipt.scene_admission.issuer_receipt.counter >= trigger.scene_event.semantic.issuer_receipt.counter:
		return _fail(&"scene_terminal_issuer_order_invalid")
	var rebuilt := make_scene_terminal_admission(record.source_identity, record.issuer_receipt,
		record.source_occurrence_id, record.source_admission_receipt_id, trigger, record.source_checkpoint,
		record.target_id, bundle, issuer)
	if not rebuilt.ok: return rebuilt
	if not _equal(rebuilt.value, record): return _fail(&"scene_terminal_admission_mismatch")
	return {"ok": true}

## Only the selected owner supplies structural tables; receipt and physical proofs stay fresh.
static func validate_selected_scene_terminal_admission(record: Dictionary, issuer: Object,
		receipts: Dictionary, creation_owner: Object = null, contacts: Dictionary = {}) -> Dictionary:
	var checked := _validate_selected_scene_terminal_with_ledger(record, issuer, receipts, creation_owner, contacts)
	return {"ok": true} if checked.ok else checked

## Call-local authenticated material for the synchronous terminal/source reading join.
## Concrete production issuer verification only reads the already-loaded root.
static func _validate_selected_scene_terminal_with_ledger(record: Dictionary, issuer: Object,
		receipts: Dictionary, creation_owner: Object, contacts: Dictionary) -> Dictionary:
	var shaped := validate_scene_terminal_admission_shape(record, issuer)
	if not shaped.get("ok", false): return shaped
	var ledger := validate_selected_scene_receipts(receipts, issuer, creation_owner, contacts)
	if not ledger.ok: return ledger
	var source: Dictionary = ledger.value.admissions.get(record.source_admission_receipt_id, {})
	if source.is_empty() or source.get("return_to") != null:
		return _fail(&"scene_terminal_source_invalid")
	var trigger: Dictionary = ledger.value.commands.get(record.trigger_command_id, {})
	if trigger.is_empty() or _sha(trigger) != record.trigger_sha256:
		return _fail(&"scene_terminal_trigger_invalid")
	var source_receipt: Dictionary = ledger.value.admission_receipts[record.source_admission_receipt_id]
	if source_receipt.scene_admission.issuer_receipt.counter >= trigger.scene_event.semantic.issuer_receipt.counter:
		return _fail(&"scene_terminal_issuer_order_invalid")
	var manifest: Script = load("res://scripts/narrative/DialogicEntryManifest.gd")
	var registered: Dictionary = manifest.scene_contract_tables()
	if not registered.ok: return registered
	var rebuilt := _make_scene_terminal_admission_registered(record.source_identity, record.issuer_receipt,
		record.source_occurrence_id, record.source_admission_receipt_id, trigger, record.source_checkpoint,
		record.target_id, registered, issuer)
	if not rebuilt.ok: return rebuilt
	if not _equal(rebuilt.value, record): return _fail(&"scene_terminal_admission_mismatch")
	return {"ok": true, "value": ledger.value}

## A saved quote authenticates the accepted purchase, never a later catalogue price.
## Purchases are outside authored marker order; the Run ledger joins their admission.
static func scene_shop_purchase_shape_valid(receipt: Variant) -> bool:
	if not _json_data(receipt) or not _keys(receipt,
			["transaction_id", "request_fingerprint", "kind", "source_id", "scene_shop_purchase"]): return false
	if receipt.kind != "scene_shop_purchase" or not _id(receipt.transaction_id) \
			or not _id(receipt.source_id) or not _hash(receipt.request_fingerprint): return false
	var saved: Variant = receipt.scene_shop_purchase
	if not _keys(saved, ["schema_version", "source_identity", "issuer_receipt", "purchase", "provenance"]) \
			or typeof(saved.schema_version) != TYPE_INT or saved.schema_version != 1 \
			or not saved.issuer_receipt is Dictionary or not saved.provenance is Dictionary: return false
	return _scene_shop_identity_valid(saved.source_identity) and _scene_shop_quote_valid(saved.purchase)

static func _scene_shop_identity_valid(identity: Variant) -> bool:
	if not _keys(identity, ["run_id", "branch_id", "desktop_timeline_generation",
			"causal_day_instance", "causal_day_instance_issuer_receipt"]): return false
	for key: String in ["run_id", "branch_id", "causal_day_instance"]:
		if not _id(identity[key]): return false
	return typeof(identity.desktop_timeline_generation) == TYPE_INT and identity.desktop_timeline_generation >= 0 \
		and identity.causal_day_instance_issuer_receipt is Dictionary \
		and identity.causal_day_instance_issuer_receipt.get("token") == identity.causal_day_instance

static func _scene_shop_quote_valid(purchase: Variant) -> bool:
	if not _keys(purchase, ["item_id", "quantity", "currency", "unit_price", "effect_ids"]) \
			or not _id(purchase.item_id) or not _positive_int(purchase.quantity) \
			or not _positive_int(purchase.unit_price) or typeof(purchase.currency) != TYPE_STRING \
			or purchase.currency not in ["money", "minesweeper_coin"] \
			or not purchase.effect_ids is Array or purchase.effect_ids.is_empty(): return false
	@warning_ignore("integer_division")
	var maximum_quantity: int = 9223372036854775807 / purchase.unit_price
	if purchase.quantity > maximum_quantity: return false
	var seen := {}
	for effect: Variant in purchase.effect_ids:
		if typeof(effect) != TYPE_STRING or seen.has(effect): return false
		seen[effect] = true
		if effect == "minesweeper:round_floor:-1" and purchase.item_id == "supportz": continue
		if effect == "inventory:add:" + purchase.item_id: continue
		if effect.begins_with("pressure:"):
			var amount: String = effect.trim_prefix("pressure:")
			if amount.is_valid_int() and amount.to_int() < 0 and str(amount.to_int()) == amount: continue
		return false
	return true

static func make_scene_shop_purchase(identity: Dictionary, root_issuer_receipt: Dictionary,
		source_id: String, purchase: Dictionary, issuer: Object) -> Dictionary:
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	if not _json_data(identity) or not _scene_shop_identity_valid(identity) or not _id(source_id) \
			or not _json_data(purchase) or not _scene_shop_quote_valid(purchase):
		return _fail(&"scene_shop_purchase_invalid")
	var issued: Dictionary = issuer.verify_issued(root_issuer_receipt, &"transaction_id")
	if not issued.get("ok", false): return issued
	var causal: Dictionary = issuer.verify_issued(identity.causal_day_instance_issuer_receipt, &"causal_day_instance")
	if not causal.get("ok", false): return causal
	var allocated := _scene_admission_identity_proof(identity, issuer)
	if not allocated.ok: return allocated
	if root_issuer_receipt.counter <= identity.causal_day_instance_issuer_receipt.counter:
		return _fail(&"scene_shop_purchase_identity_invalid")
	var request := {"kind": "scene_shop_purchase", "schema_version": 1, "source_id": source_id,
		"source_identity": identity.duplicate(true), "issuer_receipt": root_issuer_receipt.duplicate(true),
		"purchase": purchase.duplicate(true)}
	var fingerprint := _sha(request)
	if fingerprint.is_empty(): return _fail(&"scene_shop_purchase_invalid")
	var source_ids: Array[String] = [
		"request_fingerprint=" + str(WRITER.stringify(fingerprint).value), 'role="scene.shop_purchase"']
	source_ids.sort()
	var child: Dictionary = issuer.derive_child({"parent_receipt_id": root_issuer_receipt.receipt_id,
		"child_kind": "continuation_operation", "ordinal": 0, "source_ids": source_ids})
	if not child.get("ok", false): return child
	return {"ok": true, "value": {"transaction_id": root_issuer_receipt.token,
		"request_fingerprint": fingerprint, "kind": "scene_shop_purchase", "source_id": source_id,
		"scene_shop_purchase": {"schema_version": 1, "source_identity": identity.duplicate(true),
			"issuer_receipt": root_issuer_receipt.duplicate(true), "purchase": purchase.duplicate(true),
			"provenance": child.value.provenance.duplicate(true)}}}

static func validate_scene_shop_purchase(receipt: Dictionary, issuer: Object) -> Dictionary:
	if not scene_shop_purchase_shape_valid(receipt): return _fail(&"scene_shop_purchase_invalid")
	var saved: Dictionary = receipt.scene_shop_purchase
	var rebuilt := make_scene_shop_purchase(saved.source_identity, saved.issuer_receipt,
		receipt.source_id, saved.purchase, issuer)
	if not rebuilt.ok: return rebuilt
	if not _equal(receipt, rebuilt.value): return _fail(&"scene_shop_purchase_mismatch")
	var proven: Dictionary = issuer.validate_child(saved.provenance, &"continuation_operation")
	if not proven.get("ok", false): return proven
	return {"ok": true}


static func scene_round_completion_shape_valid(receipt: Variant) -> bool:
	if not _json_data(receipt) or not _keys(receipt,
			["transaction_id", "request_fingerprint", "kind", "source_id", "scene_round_completion"]): return false
	if receipt.kind != "scene_round_completion" or not _id(receipt.transaction_id) \
			or not _id(receipt.source_id) or not _hash(receipt.request_fingerprint): return false
	var saved: Variant = receipt.scene_round_completion
	return _keys(saved, ["schema_version", "source_identity", "issuer_receipt", "completion", "provenance"]) \
		and typeof(saved.schema_version) == TYPE_INT and saved.schema_version == 1 \
		and saved.issuer_receipt is Dictionary and saved.provenance is Dictionary \
		and _scene_shop_identity_valid(saved.source_identity) and _scene_round_result_valid(saved.completion)

static func _scene_round_result_valid(completion: Variant) -> bool:
	if not _keys(completion, ["board_identity", "board_sha256", "revision", "difficulty", "outcome", "gameplay_sha256"]): return false
	var identity: Variant = completion.board_identity
	return identity is Dictionary and preload("res://scripts/domain/desktop/DesktopIdentity.gd").validate(identity).get("ok", false) \
		and _hash(completion.board_sha256) and _hash(completion.gameplay_sha256) \
		and typeof(completion.revision) == TYPE_INT and completion.revision >= 0 \
		and completion.difficulty in ["beginner", "intermediate", "expert"] \
		and completion.outcome in ["exploded", "cleared", "perfect"]

static func make_scene_round_completion(identity: Dictionary, root_issuer_receipt: Dictionary,
		source_id: String, completion: Dictionary, issuer: Object) -> Dictionary:
	if issuer == null or issuer.get_script() != SCENE_RECEIPT_ISSUER:
		return _fail(&"scene_receipt_issuer_unbound")
	if not _json_data(identity) or not _scene_shop_identity_valid(identity) or not _id(source_id) \
			or not _json_data(completion) or not _scene_round_result_valid(completion):
		return _fail(&"scene_round_completion_invalid")
	for field: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"]:
		if completion.board_identity.get(field) != identity.get(field): return _fail(&"scene_round_identity_mismatch")
	var issued: Dictionary = issuer.verify_issued(root_issuer_receipt, &"transaction_id")
	if not issued.get("ok", false): return issued
	var causal: Dictionary = issuer.verify_issued(identity.causal_day_instance_issuer_receipt, &"causal_day_instance")
	if not causal.get("ok", false): return causal
	var allocated := _scene_admission_identity_proof(identity, issuer)
	if not allocated.ok: return allocated
	if root_issuer_receipt.counter <= identity.causal_day_instance_issuer_receipt.counter:
		return _fail(&"scene_round_completion_identity_invalid")
	var request := {"kind": "scene_round_completion", "schema_version": 1, "source_id": source_id,
		"source_identity": identity.duplicate(true), "issuer_receipt": root_issuer_receipt.duplicate(true),
		"completion": completion.duplicate(true)}
	var fingerprint := _sha(request)
	if fingerprint.is_empty(): return _fail(&"scene_round_completion_invalid")
	var source_ids: Array[String] = [
		"request_fingerprint=" + str(WRITER.stringify(fingerprint).value), 'role="scene.round_completion"']
	source_ids.sort()
	var child: Dictionary = issuer.derive_child({"parent_receipt_id": root_issuer_receipt.receipt_id,
		"child_kind": "continuation_operation", "ordinal": 0, "source_ids": source_ids})
	if not child.get("ok", false): return child
	return {"ok": true, "value": {"transaction_id": root_issuer_receipt.token,
		"request_fingerprint": fingerprint, "kind": "scene_round_completion", "source_id": source_id,
		"scene_round_completion": {"schema_version": 1, "source_identity": identity.duplicate(true),
			"issuer_receipt": root_issuer_receipt.duplicate(true), "completion": completion.duplicate(true),
			"provenance": child.value.provenance.duplicate(true)}}}

static func validate_scene_round_completion(receipt: Dictionary, issuer: Object) -> Dictionary:
	if not scene_round_completion_shape_valid(receipt): return _fail(&"scene_round_completion_invalid")
	var saved: Dictionary = receipt.scene_round_completion
	var rebuilt := make_scene_round_completion(saved.source_identity, saved.issuer_receipt,
		receipt.source_id, saved.completion, issuer)
	if not rebuilt.ok: return rebuilt
	if not _equal(receipt, rebuilt.value): return _fail(&"scene_round_completion_mismatch")
	var proven: Dictionary = issuer.validate_child(saved.provenance, &"continuation_operation")
	if not proven.get("ok", false): return proven
	return {"ok": true}


## Optional explicit authoring metadata. Historical programmes without this map
## keep their original transition semantics and exact hashes.
static func validate_story_days(programme: Dictionary) -> Dictionary:
	if not programme.has("story_days"): return {"ok": true, "value": {}}
	var days: Variant = programme.story_days
	if not days is Dictionary or not programme.get("entries") is Array or days.size() != programme.entries.size():
		return _fail(&"scene_story_days_invalid")
	for entry: Variant in programme.entries:
		if not entry is Dictionary or not days.has(entry.get("entry_id")):
			return _fail(&"scene_story_days_invalid")
		var day: Variant = days[entry.entry_id]
		if typeof(day) != TYPE_INT or day < 1 or day > 7: return _fail(&"scene_story_days_invalid")
	return {"ok": true, "value": days.duplicate(true)}

static func scene_day_boundary(bundle: Dictionary, source_entry: String, target_entry: String) -> Dictionary:
	var days := validate_story_days(bundle.scene_programme)
	if not days.ok: return days
	if days.value.is_empty(): return {"ok": true, "value": false}
	if not days.value.has(source_entry) or not days.value.has(target_entry): return _fail(&"scene_story_days_invalid")
	var difference: int = days.value[target_entry] - days.value[source_entry]
	if difference not in [0, 1]: return _fail(&"scene_story_day_order_invalid")
	return {"ok": true, "value": difference == 1}

## The original event survives Load; the live causal identity does not. Bind the
## allocation to both, so retry is stable without sharing a day token across branches.
static func scene_day_renewal_request(trigger: Dictionary, identity: Dictionary) -> Dictionary:
	var event: Dictionary = trigger.scene_event
	var source_ids: Array[String] = ["identity=" + _sha(identity),
		"resolution=" + event.result.resolution_receipt.receipt_id,
		"role=scene_daily_renewal", "transition=" + _sha(trigger)]
	source_ids.sort()
	return {"parent_receipt_id": event.semantic.issuer_receipt.receipt_id,
		"child_kind": "scene_day_completion", "ordinal": 1, "source_ids": source_ids}

static func validate_scene_day_allocation(trigger: Dictionary, identity: Dictionary, issuer: Object) -> Dictionary:
	var captured: Dictionary = issuer.capture_root()
	if not captured.get("ok", false): return captured
	for allocation: Dictionary in captured.value.get("day_advance_allocation_receipts", {}).values():
		if allocation.get("resolution_kind") != "scene_day_complete" \
				or allocation.get("target_causal_day_instance") != identity.causal_day_instance: continue
		var source := identity.duplicate(true)
		source.causal_day_instance = allocation.source_causal_day_instance
		source.causal_day_instance_issuer_receipt = allocation.source_causal_day_instance_issuer_receipt.duplicate(true)
		for key: String in ["run_id", "branch_id", "desktop_timeline_generation"]:
			if allocation.get(key) != identity.get(key): return _fail(&"scene_day_allocation_mismatch")
		var derived: Dictionary = issuer.derive_child(scene_day_renewal_request(trigger, source))
		if not derived.get("ok", false): return derived
		if allocation.source_resolution_receipt_id != derived.value.child_id \
				or not _equal(allocation.source_resolution_receipt_provenance, derived.value.provenance):
			return _fail(&"scene_day_allocation_mismatch")
		return {"ok": true}
	return _fail(&"scene_day_allocation_missing")

