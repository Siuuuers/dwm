extends RefCounted
## Read-only public projection of the retained warning owner; never issues commands.
const INTENTS := {"unread_invitation":&"open_contacts_list", "accepted_date":&"dismiss", "base_minesweeper":&"open_minesweeper"}
const LOCALES := ["en","zh-CN","zh-HK","ja","ko"]
const AUTHORED_LOCALES := ["en","zh-CN","zh-HK"]
var _view: Object
var _copy: Dictionary = {}

func configure(view_controller: Object, copy_catalog: Dictionary) -> Dictionary:
	if _view != null: return _fail(&"warning_presentation_already_configured")
	if view_controller == null or not view_controller.has_method("snapshot"): return _fail(&"invalid_warning_owner")
	for kind: String in INTENTS:
		if typeof(copy_catalog.get(kind)) != TYPE_DICTIONARY: return _fail(&"warning_copy_unavailable")
		for locale: String in LOCALES:
			if locale not in AUTHORED_LOCALES and not copy_catalog[kind].has(locale): continue
			var row: Variant = copy_catalog[kind].get(locale)
			if typeof(row) != TYPE_DICTIONARY: return _fail(&"warning_copy_unavailable")
			for field: String in ["title","body","close","go","failed_go"]:
				if typeof(row.get(field)) != TYPE_STRING or row[field].strip_edges().is_empty(): return _fail(&"warning_copy_unavailable")
	_view = view_controller
	_copy = copy_catalog.duplicate(true)
	return {"ok":true,"code":&"ok"}

func project(locale: String) -> Dictionary:
	if _view == null: return _fail(&"warning_presentation_unconfigured")
	if locale not in LOCALES: return _fail(&"unsupported_locale")
	var snapshot: Dictionary = _view.snapshot()
	if not snapshot.get("ok",false): return snapshot
	var warning: Variant = snapshot.value.view.pending_warning
	if warning == null: return {"ok":true,"value":{"warning":null}}
	if typeof(warning) != TYPE_DICTIONARY or warning.get("warning_kind","") not in INTENTS: return _fail(&"invalid_warning_projection")
	var row: Dictionary = _copy[warning.warning_kind].get(locale, _copy[warning.warning_kind]["en"])
	return {"ok":true,"value":{"warning":{
		"activation_id":warning.activation_id,
		"copy":{"title":row.title,"body":row.body,"close":row.close,"go":row.go},
		"error":row.failed_go if not warning.attempt_receipts.is_empty() else "",
		"go_intent":INTENTS[warning.warning_kind],
	}}}

static func _fail(code: StringName) -> Dictionary:
	return {"ok":false,"code":code}
