extends "res://tests/integration/verify_playable_startup.gd"
## Runs the default real player journey with every optional narrative art slot populated by fixtures.

const ART := preload("res://scripts/data/ArtManifest.gd")
const FIXTURE_ROOT := "res://tests/fixtures/art/"

var _continued_tokens: Dictionary = {}
var _continued_art_cards := 0
var _art_failure := ""

func _run() -> void:
	_install_art_overrides()
	await super._run()
	if not _check(_art_failure.is_empty(), _art_failure): return
	if not _check(_continued_art_cards > 0, "optional art produced no real startup hold"): return
	print("ART_STARTUP_PASS: continued_art_cards=%d" % _continued_art_cards)

func _process(_delta: float) -> bool:
	if not _art_failure.is_empty(): return false
	var bridge := root.get_node_or_null("DialogicBridge")
	if bridge == null or not bridge.has_method("get_art_hold_view"): return false
	var view: Node = bridge.get_art_hold_view()
	if view == null or not view.has_drawn_art() or view.next_button.disabled: return false
	var token := str(view.get("_token"))
	if token.is_empty() or _continued_tokens.has(token): return false
	var validation := _validate_art_hold(view)
	if not validation.is_empty():
		_art_failure = validation
		printerr("PLAYABLE_STARTUP_FAIL: " + validation)
		quit(1)
		return false
	_continued_tokens[token] = true
	_continued_art_cards += 1
	view.next_button.pressed.emit()
	return false

func _install_art_overrides() -> void:
	ART.reload_placements()
	ART.set_overlay_info("", "ui.title", FIXTURE_ROOT + "ui-960x656.svg",
		Vector2i(960, 656), "startup")
	ART.set_overlay_info("", "ui.desktop", FIXTURE_ROOT + "ui-800x656.svg",
		Vector2i(800, 656), "startup")
	for asset_id: String in ART.get_expected_art_paths():
		if asset_id.begins_with("background."):
			ART.set_overlay_info("", asset_id, FIXTURE_ROOT + "placement-background.svg",
				Vector2i(1280, 448), "startup")
		elif asset_id.begins_with("character."):
			var portrait := "placement-portrait-right.svg" if asset_id.ends_with("lavinia") \
				else "placement-portrait-left.svg"
			ART.set_overlay_info("", asset_id, FIXTURE_ROOT + portrait,
				Vector2i(320, 448), "startup")
		elif asset_id.begins_with("cg."):
			ART.set_overlay_info("", asset_id, FIXTURE_ROOT + "placement-cg.svg",
				Vector2i(1280, 448), "startup")

func _validate_art_hold(view: Node) -> String:
	if view.next_button.focus_mode != Control.FOCUS_ALL:
		return "art hold Continue is not a native focus target"
	var art: Control = view.get("art")
	if art == null or not art.visible or not Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(art.get_rect()):
		return "drawn art is absent or outside the player viewport"
	var textured_layers := 0
	for child: Node in art.get_children():
		if child is TextureRect and child.visible and child.texture != null:
			if not art.get_rect().encloses(child.get_rect()):
				return "visible art layer escapes the scene aperture"
			textured_layers += 1
	if textured_layers == 0:
		return "drawn art hold has no visible texture layer"
	return ""
