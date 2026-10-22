extends RefCounted

## Historical test dependency. Never leaves production registration deselected.
const ORDINARY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
var _previous_definitions: Dictionary
var _installed := false

func install() -> Dictionary:
	if _installed: return {"ok": false, "message": "retained ordinary fixture already installed"}
	# Authenticate inputs before temporarily selecting the legacy loader path.
	for source: Array in [
		["res://data/manifests/dialogic_ids.json", "2ca187e4ca3fa33b1701c78aeb45e59b0d726f80650232fb6e25b15ca8d67375"],
		["res://data/manifests/dialogic_entries.json", "410934868a736082daa4ff55bc7e25f550359b2f8b91ff956a7997788c334a3a"],
	]:
		var text := FileAccess.get_file_as_string(source[0]).replace("\r\n", "\n")
		if text.sha256_text() != source[1]:
			return {"ok": false, "message": "retained ordinary source changed: " + str(source[0])}
	_previous_definitions = ORDINARY._definitions
	var bundle: Dictionary = MANIFEST._scene_bundle
	var checked: bool = MANIFEST._startup_selection_checked
	var selection_error: Dictionary = MANIFEST._startup_selection_error
	var used: bool = MANIFEST._registration_used
	var signature_entries: Dictionary = SIGNATURE._entries
	ORDINARY._definitions = {}
	SIGNATURE._entries = {}
	MANIFEST._scene_bundle = {}
	MANIFEST._startup_selection_checked = true
	MANIFEST._startup_selection_error = {}
	# Synchronous existing parser/validator/builder only; no await or consumer callback.
	var loaded: Dictionary = ORDINARY._load_registry()
	MANIFEST._scene_bundle = bundle
	MANIFEST._startup_selection_checked = checked
	MANIFEST._startup_selection_error = selection_error
	MANIFEST._registration_used = used
	SIGNATURE._entries = signature_entries
	_installed = true
	if not loaded.get("ok", false): restore()
	return loaded

func restore() -> void:
	if not _installed: return
	ORDINARY._definitions = _previous_definitions
	_installed = false
