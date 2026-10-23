class_name DynamicScriptProbe
extends RefCounted

static func load_script(path: String) -> Dictionary:
	if not ResourceLoader.exists(path, "Script"):
		return {"ok": false, "code": &"missing_script", "message": path}
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		return {"ok": false, "code": &"invalid_script", "message": path}
	return {"ok": true, "code": &"ok", "value": script}

static func instantiate(path: String) -> Dictionary:
	var loaded := load_script(path)
	if not loaded.get("ok", false):
		return loaded
	return {"ok": true, "code": &"ok", "value": loaded["value"].new()}
