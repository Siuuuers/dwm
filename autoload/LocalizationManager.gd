extends Node

signal locale_changed(locale_id: String)

const CATALOG := preload("res://scripts/localization/LocalizationCatalog.gd")
const SCHEMA := preload("res://scripts/localization/LocalizationSchema.gd")
const ROOT_METHODS: Array[StringName] = [
	&"prepare_presentation",
	&"capture_presentation_state",
	&"apply_presentation_silent",
	&"rollback_presentation_silent",
	&"finalize_presentation",
]

var _profile: Node
var _mutation_gate: Object
var _readiness := &"uninitialized"
var _catalog_store: Dictionary = {}
var _bundle: Dictionary = {}
var _locale_id := ""
var _presentation_profile: Dictionary = {}
var _warned_missing: Dictionary = {}
var _roots: Dictionary = {}
var _restore_backup: Dictionary = {}
var _restore_applied: Array = []
var _publishing_own_locale := false


func _ready() -> void:
	pass


func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _fail(&"invalid_mutation_gate")
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method):
			return _fail(&"invalid_mutation_gate")
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id():
		return _fail(&"mutation_gate_already_configured")
	var already_configured := _mutation_gate != null
	_mutation_gate = gate
	return _success({"gate_instance_id": gate.get_instance_id(), "already_configured": already_configured})


func initialize(profile: Node, manifest_path: String = "res://localization/manifest.json") -> Dictionary:
	if _readiness != &"uninitialized":
		return _fail(&"already_initialized")
	if profile == null or not profile.has_method("prepare_locale_preference"):
		_readiness = &"failed"
		return _fail(&"invalid_profile_manager")

	_readiness = &"initializing"
	_profile = profile
	var loaded: Dictionary = CATALOG.load_bundle(manifest_path)
	if not loaded.get("ok", false):
		_readiness = &"failed"
		return loaded
	var catalog_store: Dictionary = (loaded["value"] as Dictionary).duplicate(true)
	var source_locale: String = catalog_store["manifest"]["source_locale"]
	var stored_locale := str(profile.get_preference(&"preferences.language", source_locale))
	var canonical_locale := _resolve_locale_in_bundle(catalog_store, stored_locale)
	if canonical_locale.is_empty():
		canonical_locale = source_locale
	var next_bundle := _bundle_for_locale(catalog_store, canonical_locale)
	var next_presentation := _make_presentation_in_bundle(catalog_store, canonical_locale)
	var prepared_roots := _prepare_root_plans(next_presentation)
	if not prepared_roots.get("ok", false):
		_readiness = &"failed"
		return prepared_roots
	var applied := _apply_root_plans(prepared_roots["value"])
	if not applied.get("ok", false):
		_readiness = &"failed"
		return applied

	var publication_id := ""
	if stored_locale != canonical_locale:
		var profile_candidate: Dictionary = profile.prepare_locale_preference(canonical_locale)
		if not profile_candidate.get("ok", false):
			_rollback_applied_roots(applied.get("applied", []))
			_readiness = &"failed"
			return profile_candidate
		var committed: Dictionary = profile.commit_prepared_profile(profile_candidate["value"], true)
		if not committed.get("ok", false):
			_rollback_applied_roots(applied.get("applied", []))
			_readiness = &"failed"
			return committed
		publication_id = committed["value"]["publication_id"]

	_catalog_store = catalog_store
	_bundle = next_bundle
	_locale_id = canonical_locale
	_presentation_profile = next_presentation
	_readiness = &"ready"
	if not profile.preference_changed.is_connected(_on_profile_preference_changed):
		profile.preference_changed.connect(_on_profile_preference_changed)
	if not publication_id.is_empty():
		_publishing_own_locale = true
		profile.publish_deferred_profile_signals(publication_id)
		_publishing_own_locale = false
	_finalize_roots(applied.get("applied", []))
	return _success({"locale_id": canonical_locale})


func get_readiness() -> StringName:
	return _readiness


func get_locale() -> String:
	return _locale_id


func get_presentation_profile() -> Dictionary:
	return _presentation_profile.duplicate(true)


func get_selectable_locales() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if _catalog_store.is_empty():
		return output
	for record in _catalog_store["manifest"]["locales"]:
		if record["selectable"]:
			output.append((record as Dictionary).duplicate(true))
	return output


func prepare_locale(locale_input: String) -> Dictionary:
	if _readiness not in [&"initializing", &"ready"]:
		return _fail(&"localization_not_ready")
	var canonical := _resolve_locale_in_bundle(_catalog_store, locale_input)
	if canonical.is_empty():
		return _fail(&"unknown_locale")
	var presentation := _make_presentation_in_bundle(_catalog_store, canonical)
	var root_plans := _prepare_root_plans(presentation)
	if not root_plans.get("ok", false):
		return root_plans
	var profile_candidate: Dictionary = _profile.prepare_locale_preference(canonical)
	if not profile_candidate.get("ok", false):
		return profile_candidate
	return _success({
		"canonical_locale_id": canonical,
		"bundle": _bundle_for_locale(_catalog_store, canonical),
		"presentation_profile": presentation.duplicate(true),
		"root_plans": root_plans["value"],
		"profile_candidate": (profile_candidate["value"] as Dictionary).duplicate(true),
	})


func set_locale(locale_input: String) -> Dictionary:
	if _mutation_gate != null:
		var guarded: Dictionary = _mutation_gate.guard_external(&"localization_set_locale")
		if not guarded.get("ok", false):
			return guarded
	var prepared := prepare_locale(locale_input)
	if not prepared.get("ok", false):
		return prepared
	var plan: Dictionary = prepared["value"]
	var applied := _apply_root_plans(plan["root_plans"])
	if not applied.get("ok", false):
		return applied
	var committed: Dictionary = _profile.commit_prepared_profile(plan["profile_candidate"], true)
	if not committed.get("ok", false):
		_rollback_applied_roots(applied.get("applied", []))
		return committed

	_bundle = (plan["bundle"] as Dictionary).duplicate(true)
	_locale_id = plan["canonical_locale_id"]
	_presentation_profile = (plan["presentation_profile"] as Dictionary).duplicate(true)
	_publishing_own_locale = true
	_profile.publish_deferred_profile_signals(committed["value"]["publication_id"])
	_publishing_own_locale = false
	locale_changed.emit(_locale_id)
	_finalize_roots(applied.get("applied", []))
	return _success({"locale_id": _locale_id})


func has_key(key: String) -> bool:
	return _lookup(key) != null


func t(key: String, params: Dictionary = {}) -> String:
	var text: Variant = _lookup(key)
	if text == null:
		_warn_once(&"missing", key)
		return "[missing:%s]" % key
	var expected := SCHEMA.extract_named_placeholders(text)
	var actual := PackedStringArray(params.keys())
	actual.sort()
	if expected != actual:
		_warn_once(&"format", key)
		return "[format_error:%s]" % key
	var output: String = text
	for param in params:
		output = output.replace("{%s}" % param, str(params[param]))
	return output


func register_presentation_root(root: Node) -> Dictionary:
	var validated := _validate_root(root)
	if not validated.get("ok", false):
		return validated
	if _readiness == &"failed":
		return _fail(&"localization_failed")
	var root_id := root.get_instance_id()
	var existing: WeakRef = _roots.get(root_id)
	if existing != null and existing.get_ref() == root:
		return _success({"root_instance_id": root_id}, &"already_registered")
	if _readiness != &"ready":
		_roots[root_id] = weakref(root)
		return _success({"root_instance_id": root_id}, &"pending_registration")

	_roots[root_id] = weakref(root)
	var prepared := _prepare_one_root(root, _presentation_profile)
	if not prepared.get("ok", false):
		_roots.erase(root_id)
		return prepared
	var applied := _apply_root_plans([prepared["value"]])
	if not applied.get("ok", false):
		_roots.erase(root_id)
		return applied
	_finalize_roots(applied.get("applied", []))
	return _success({"root_instance_id": root_id})


func unregister_presentation_root(root: Node) -> Dictionary:
	if root != null:
		_roots.erase(root.get_instance_id())
	return _success()


func capture_restore_state() -> Dictionary:
	var root_states := _capture_root_states()
	if not root_states.get("ok", false):
		return root_states
	return _success({
		"locale_id": _locale_id,
		"bundle": _bundle.duplicate(true),
		"presentation_profile": _presentation_profile.duplicate(true),
		"root_states": root_states["value"],
	})


func apply_restore_silent(plan: Dictionary) -> Dictionary:
	if not _is_restore_plan_valid(plan):
		return _fail(&"invalid_localization_restore_plan")
	if str(_profile.get_preference(&"preferences.language", "")) != str(plan["canonical_locale_id"]):
		return _fail(&"localization_restore_profile_mismatch")
	var backup := capture_restore_state()
	if not backup.get("ok", false):
		return backup
	var applied := _apply_root_plans(plan["root_plans"])
	if not applied.get("ok", false):
		return applied
	_restore_backup = (backup["value"] as Dictionary).duplicate(true)
	_restore_applied = applied.get("applied", []).duplicate()
	_locale_id = plan["canonical_locale_id"]
	_bundle = (plan["bundle"] as Dictionary).duplicate(true)
	_presentation_profile = (plan["presentation_profile"] as Dictionary).duplicate(true)
	return _success()


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var value: Dictionary = backup.get("value", backup)
	if not value.has_all(["locale_id", "bundle", "presentation_profile"]):
		return _fail(&"invalid_localization_restore_backup")
	_rollback_root_states(value.get("root_states", []))
	_locale_id = value["locale_id"]
	_bundle = (value["bundle"] as Dictionary).duplicate(true)
	_presentation_profile = (value["presentation_profile"] as Dictionary).duplicate(true)
	_finalize_roots(_restore_applied)
	_restore_applied = []
	return _success()


func finalize_restore() -> Dictionary:
	_finalize_roots(_restore_applied)
	_restore_applied = []
	_restore_backup = {}
	return _success()


func _prepare_root_plans(presentation: Dictionary) -> Dictionary:
	var plans: Array = []
	for root_id in _live_root_ids():
		var root: Node = (_roots[root_id] as WeakRef).get_ref()
		var prepared := _prepare_one_root(root, presentation)
		if not prepared.get("ok", false):
			return prepared
		plans.append(prepared["value"])
	return _success(plans)


func _prepare_one_root(root: Node, presentation: Dictionary) -> Dictionary:
	var prepared: Variant = root.prepare_presentation(presentation.duplicate(true))
	if not prepared is Dictionary or not prepared.get("ok", false):
		return prepared if prepared is Dictionary else _fail(&"invalid_root_prepare_result")
	return _success({
		"root_instance_id": root.get_instance_id(),
		"plan": (prepared.get("value", {}) as Dictionary).duplicate(true),
	})


func _apply_root_plans(root_plans: Array) -> Dictionary:
	var applied: Array = []
	for root_plan_value in root_plans:
		var root_plan: Dictionary = root_plan_value
		var root: Node = _root_for_id(root_plan.get("root_instance_id", -1))
		if not is_instance_valid(root):
			_rollback_applied_roots(applied)
			return _fail(&"presentation_root_freed")
		var captured: Variant = root.capture_presentation_state()
		if not captured is Dictionary or not captured.get("ok", false):
			_rollback_applied_roots(applied)
			return captured if captured is Dictionary else _fail(&"invalid_root_capture_result")
		var applied_record := {
			"root": root,
			"backup": (captured.get("value", {}) as Dictionary).duplicate(true),
		}
		var result: Variant = root.apply_presentation_silent((root_plan["plan"] as Dictionary).duplicate(true))
		if not result is Dictionary or not result.get("ok", false):
			root.rollback_presentation_silent(applied_record["backup"].duplicate(true))
			_rollback_applied_roots(applied)
			return result if result is Dictionary else _fail(&"invalid_root_apply_result")
		applied.append(applied_record)
	return {"ok": true, "code": &"ok", "value": {}, "applied": applied}


func _rollback_applied_roots(applied: Array) -> void:
	for index in range(applied.size() - 1, -1, -1):
		var record: Dictionary = applied[index]
		var root: Node = record.get("root")
		if is_instance_valid(root):
			root.rollback_presentation_silent((record["backup"] as Dictionary).duplicate(true))


func _finalize_roots(applied: Array) -> void:
	for record_value in applied:
		var root: Node = (record_value as Dictionary).get("root")
		if is_instance_valid(root):
			root.finalize_presentation()


func _capture_root_states() -> Dictionary:
	var states: Array = []
	for root_id in _live_root_ids():
		var root: Node = (_roots[root_id] as WeakRef).get_ref()
		var captured: Variant = root.capture_presentation_state()
		if not captured is Dictionary or not captured.get("ok", false):
			return captured if captured is Dictionary else _fail(&"invalid_root_capture_result")
		states.append({"root_instance_id": root_id, "backup": (captured.get("value", {}) as Dictionary).duplicate(true)})
	return _success(states)


func _rollback_root_states(states: Array) -> void:
	for index in range(states.size() - 1, -1, -1):
		var record: Dictionary = states[index]
		var root: Node = _root_for_id(record.get("root_instance_id", -1))
		if is_instance_valid(root):
			root.rollback_presentation_silent((record["backup"] as Dictionary).duplicate(true))


func _live_root_ids() -> Array:
	var ids: Array = _roots.keys()
	ids.sort()
	var live: Array = []
	for root_id in ids:
		var reference: WeakRef = _roots[root_id]
		if reference.get_ref() == null:
			_roots.erase(root_id)
		else:
			live.append(root_id)
	return live


func _root_for_id(root_id: int) -> Node:
	var reference: WeakRef = _roots.get(root_id)
	if reference == null:
		return null
	return reference.get_ref()


func _validate_root(root: Node) -> Dictionary:
	if root == null or not is_instance_valid(root):
		return _fail(&"invalid_presentation_root")
	for method in ROOT_METHODS:
		if not root.has_method(method):
			return _fail(&"invalid_presentation_root")
	return _success()


func _is_restore_plan_valid(plan: Dictionary) -> bool:
	return plan.has_all(["canonical_locale_id", "bundle", "presentation_profile", "root_plans"])


func _on_profile_preference_changed(path: StringName, value: Variant) -> void:
	if path != &"preferences.language":
		return
	var requested := str(value)
	if _publishing_own_locale:
		if requested != _locale_id:
			_readiness = &"failed"
			push_error("Localization publication disagreed with the active bundle")
		return
	var canonical := _resolve_locale_in_bundle(_catalog_store, requested)
	if canonical.is_empty():
		_readiness = &"failed"
		push_error("Committed profile contains an unregistered locale")
		return
	var presentation := _make_presentation_in_bundle(_catalog_store, canonical)
	if canonical == _locale_id and presentation == _presentation_profile:
		return
	var root_plans := _prepare_root_plans(presentation)
	if not root_plans.get("ok", false):
		_readiness = &"failed"
		push_error("Could not prepare committed locale presentation")
		return
	var applied := _apply_root_plans(root_plans["value"])
	if not applied.get("ok", false):
		_readiness = &"failed"
		push_error("Could not apply committed locale presentation")
		return
	_bundle = _bundle_for_locale(_catalog_store, canonical)
	_locale_id = canonical
	_presentation_profile = presentation
	locale_changed.emit(canonical)
	_finalize_roots(applied.get("applied", []))


func _warn_once(kind: StringName, key: String) -> void:
	var warning_id := "%s:%s" % [kind, key]
	if _warned_missing.has(warning_id):
		return
	_warned_missing[warning_id] = true
	push_warning("Localization %s for key '%s'" % [kind, key])


func _lookup(key: String) -> Variant:
	if _bundle.is_empty():
		return null
	var catalogs: Dictionary = _bundle["catalogs"]
	var cursor: Variant = _locale_id
	while cursor != null:
		for message in catalogs[cursor]["messages"]:
			if message["id"] == key:
				return message["text"]
		cursor = _locale_record_in_bundle(_bundle, cursor)["fallback_locale"]
	return null


func _resolve_locale_in_bundle(bundle: Dictionary, input: String) -> String:
	for record in bundle.get("manifest", {}).get("locales", []):
		if record["id"] == input:
			return input
	for alias in bundle.get("manifest", {}).get("aliases", []):
		if alias["input"] == input:
			return alias["locale"]
	return ""


func _bundle_for_locale(catalog_store: Dictionary, locale_id: String) -> Dictionary:
	var catalogs: Dictionary = {}
	var cursor: Variant = locale_id
	while cursor != null:
		catalogs[cursor] = (catalog_store["catalogs"][cursor] as Dictionary).duplicate(true)
		cursor = _locale_record_in_bundle(catalog_store, cursor)["fallback_locale"]
	return {
		"manifest": (catalog_store["manifest"] as Dictionary).duplicate(true),
		"catalogs": catalogs,
	}


func _locale_record_in_bundle(bundle: Dictionary, locale_id: String) -> Dictionary:
	for record in bundle["manifest"]["locales"]:
		if record["id"] == locale_id:
			return record
	return {}


func _make_presentation_in_bundle(bundle: Dictionary, locale_id: String) -> Dictionary:
	var record := _locale_record_in_bundle(bundle, locale_id)
	return {
		"locale_id": locale_id,
		"font_profile": record["font_profile"],
		"layout_direction": record["layout_direction"],
	}


func _success(value: Variant = {}, code: StringName = &"ok") -> Dictionary:
	return {"ok": true, "code": code, "value": value, "receipt": {}}


func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}
