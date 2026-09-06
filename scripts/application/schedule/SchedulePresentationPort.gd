class_name SchedulePresentationPort
extends RefCounted

const _SOURCE_QUERY := preload("res://scripts/application/schedule/ScheduleSourceQuery.gd")
const _ART := preload("res://scripts/ui/schedule/ScheduleArtRegistry.gd")
const _CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const _LOCALES := ["en", "zh-CN", "zh-HK"]
const _NAME_KEYS := ["en", "zh-CN", "zh-HK"]
const _PROBE_ID := "schedule-presentation-availability-probe"

var _contacts_owner: Object
var _view_controller: Object
var _registry: Object
var _registry_fingerprint := ""
var _identity_issuer: Object
var _names: Dictionary = {}


func configure(contacts_owner: Object, view_controller: Object, registry: Object,
		registry_fingerprint: String, identity_issuer: Object, names: Dictionary) -> Dictionary:
	if _contacts_owner != null:
		return _fail(&"schedule_presentation_already_configured")
	if contacts_owner == null or typeof(contacts_owner.get("contacts")) != TYPE_DICTIONARY \
			or typeof(contacts_owner.get("day")) != TYPE_INT:
		return _fail(&"invalid_contacts_owner")
	if view_controller == null:
		return _fail(&"invalid_view_controller")
	for method: String in ["snapshot", "fingerprint", "prepare_add", "apply_docket_edit"]:
		if not view_controller.has_method(method):
			return _fail(&"invalid_view_controller")
	if registry == null or not registry.has_method("lookup") \
			or not registry.has_method("snapshot") or registry_fingerprint.is_empty():
		return _fail(&"invalid_registry")
	var registry_check: Dictionary = registry.snapshot(registry_fingerprint)
	if not registry_check.get("ok", false):
		return registry_check
	if identity_issuer == null or not identity_issuer.has_method("issue"):
		return _fail(&"invalid_identity_issuer")
	var names_error := _validate_names(names, registry, registry_fingerprint)
	if not names_error.is_empty():
		return names_error
	_contacts_owner = contacts_owner
	_view_controller = view_controller
	_registry = registry
	_registry_fingerprint = registry_fingerprint
	_identity_issuer = identity_issuer
	_names = names.duplicate(true)
	return _ok({"configured": true})


func project(locale: String) -> Dictionary:
	return _project(locale,false)


func project_modal_background(locale: String) -> Dictionary:
	# Restored warnings still need their exact undimmed desk. Edit entry points
	# continue to call project(), so this read does not grant mutation access.
	return _project(locale,true)


func _project(locale: String, modal_background: bool) -> Dictionary:
	if _contacts_owner == null:
		return _fail(&"schedule_presentation_unconfigured")
	if locale not in _LOCALES:
		return _fail(&"unsupported_locale")
	var snapshot: Dictionary = _view_controller.snapshot()
	if not snapshot.get("ok", false):
		return snapshot
	var view: Dictionary = snapshot["value"]["view"]
	if int(view["day"]) != int(_contacts_owner.get("day")):
		return _fail(&"schedule_owner_day_mismatch")
	if view["pending_warning"] != null and not modal_background:
		return _fail(&"warning_modal_active")
	var entries_error := _packed_error(view["entries"])
	if not entries_error.is_empty():
		return entries_error
	var contacts: Dictionary = (_contacts_owner.get("contacts") as Dictionary).duplicate(true)
	var existing_error := _existing_entries_error(view["entries"], contacts, int(view["day"]))
	if not existing_error.is_empty():
		return existing_error
	var fingerprint_result: Dictionary = _view_controller.fingerprint()
	if not fingerprint_result.get("ok", false):
		return fingerprint_result
	var view_fingerprint := str(fingerprint_result["value"]["fingerprint"])
	var queried: Dictionary = _SOURCE_QUERY.project(
		contacts, int(view["day"]),
		_registry, _registry_fingerprint)
	if not queried.get("ok", false):
		return queried

	var sources: Array = []
	for source: Dictionary in queried["value"]["sources"]:
		var source_id := str(source["action_id"])
		if not _names.has(source_id):
			return _fail(&"schedule_name_unavailable")
		var art: Dictionary = _ART.resolve(_registry, source_id, _registry_fingerprint)
		if not art.get("ok", false):
			return art
		var available := true
		if int(view["day"]) < 7:
			var probe: Dictionary = _view_controller.prepare_add(source_id,
				source["source_receipt_id"], view["entries"].size(), _probe_id(view["entries"]))
			if not probe.get("ok", false):
				if str(probe.get("code", "")) not in [
					"too_many_entries", "too_many_dates", "action_not_repeatable",
					"superseded_solo_date",
				]:
					return probe
				available = false
		sources.append({
			"id": source_id, "name": _names[source_id][locale],
			"compact": art["value"]["compact"], "folio": art["value"]["folio"],
			"available": available,
		})

	var entries: Array = []
	for entry: Dictionary in view["entries"]:
		var source_id := str(entry["action_id"])
		if not _names.has(source_id):
			return _fail(&"schedule_name_unavailable")
		var art: Dictionary = _ART.resolve(_registry, source_id, _registry_fingerprint)
		if not art.get("ok", false):
			return art
		entries.append({
			"id": entry["draft_entry_id"], "source_id": source_id,
			"name": _names[source_id][locale], "folio": art["value"]["folio"],
		})
	return _ok({
		"day_seven": int(view["day"]) == 7,
		"fingerprint": view_fingerprint,
		"sources": sources,
		"entries": entries,
	})


func append(source_id: String, expected_fp: String, locale: String) -> Dictionary:
	var current := project(locale)
	if not current.get("ok", false):
		return current
	if current["value"]["fingerprint"] != expected_fp:
		return _fail(&"stale_view_fingerprint")
	var selected: Dictionary = {}
	for source: Dictionary in current["value"]["sources"]:
		if source["id"] == source_id:
			selected = source
			break
	if selected.is_empty():
		return _fail(&"schedule_source_unavailable")
	if not selected["available"]:
		return _fail(&"schedule_source_unavailable")
	var source_receipt: Variant = null
	var source_found := false
	var contacts: Dictionary = (_contacts_owner.get("contacts") as Dictionary).duplicate(true)
	var query: Dictionary = _SOURCE_QUERY.project(contacts,
		int(_contacts_owner.get("day")), _registry, _registry_fingerprint)
	if not query.get("ok", false):
		return query
	for source: Dictionary in query["value"]["sources"]:
		if source["action_id"] == source_id:
			source_receipt = source["source_receipt_id"]
			source_found = true
			break
	if not source_found:
		return _fail(&"schedule_source_unavailable")
	if current["value"]["day_seven"] and current["value"]["entries"].size() == 1:
		var existing: Dictionary = current["value"]["entries"][0]
		var snap: Dictionary = _view_controller.snapshot()
		var raw: Dictionary = snap["value"]["view"]["entries"][0]
		if existing["source_id"] == source_id and raw["source_receipt_id"] == source_receipt:
			return current
	var issued: Dictionary = _identity_issuer.issue(&"transaction_id")
	if not issued.get("ok", false):
		return issued
	var result: Dictionary = _view_controller.apply_docket_edit({
		"kind": "append", "action_id": source_id, "source_receipt_id": source_receipt,
		"draft_entry_id": str(issued["value"]["token"]),
	}, expected_fp)
	return project(locale) if result.get("ok", false) else result


func move(id: String, target: int, expected_fp: String, locale: String) -> Dictionary:
	return _edit({"kind": "move", "draft_entry_id": id, "target_index": target},
		expected_fp, locale)


func remove(id: String, expected_fp: String, locale: String) -> Dictionary:
	return _edit({"kind": "remove", "draft_entry_id": id}, expected_fp, locale)


func _edit(command: Dictionary, expected_fp: String, locale: String) -> Dictionary:
	var current := project(locale)
	if not current.get("ok", false):
		return current
	if current["value"]["fingerprint"] != expected_fp:
		return _fail(&"stale_view_fingerprint")
	var result: Dictionary = _view_controller.apply_docket_edit(command, expected_fp)
	return project(locale) if result.get("ok", false) else result


static func _probe_id(entries: Array) -> String:
	var candidate := _PROBE_ID
	var occupied: Dictionary = {}
	for entry: Dictionary in entries:
		occupied[str(entry["draft_entry_id"])] = true
	while occupied.has(candidate):
		candidate += "-next"
	return candidate


static func _validate_names(names: Dictionary, registry: Object,
		fingerprint: String) -> Dictionary:
	for action_id: Variant in names:
		if typeof(action_id) != TYPE_STRING \
				or not registry.lookup(str(action_id), fingerprint).get("ok", false):
			return _fail(&"invalid_schedule_names")
		var translations: Variant = names[action_id]
		if typeof(translations) != TYPE_DICTIONARY:
			return _fail(&"invalid_schedule_names")
		var table := translations as Dictionary
		var keys: Array = table.keys()
		keys.sort()
		if keys != _NAME_KEYS:
			return _fail(&"invalid_schedule_names")
		for locale: String in _LOCALES:
			if typeof(table[locale]) != TYPE_STRING \
					or str(table[locale]).strip_edges().is_empty():
				return _fail(&"invalid_schedule_names")
	return {}


static func _packed_error(entries: Array) -> Dictionary:
	for index: int in range(entries.size()):
		if typeof(entries[index]) != TYPE_DICTIONARY \
				or (entries[index] as Dictionary).get("slot_index") != index:
			return _fail(&"sparse_schedule_view")
	return {}


func _existing_entries_error(entries: Array, contacts: Dictionary, day: int) -> Dictionary:
	for entry: Dictionary in entries:
		var found: Dictionary = _registry.lookup(str(entry["action_id"]), _registry_fingerprint)
		if not found.get("ok", false):
			return found
		var record: Dictionary = found["value"]["record"]
		if record["action_kind"] == "ordinary":
			if entry["source_receipt_id"] != null:
				return _fail(&"invalid_existing_schedule_source")
			continue
		if typeof(entry["source_receipt_id"]) != TYPE_STRING:
			return _fail(&"invalid_existing_schedule_source")
		var validated: Dictionary = _CONTACTS.validate_schedule_source_receipt(
			contacts, str(entry["source_receipt_id"]), record, day)
		if not validated.get("ok", false):
			return validated
	return {}


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}}
