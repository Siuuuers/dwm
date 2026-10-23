extends "res://addons/gut/test.gd"

const ART := preload("res://scripts/ui/schedule/ScheduleArtRegistry.gd")
const ACTIONS := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")

func test_registered_neutral_pair_has_declared_dimensions_and_only_opaque_hard_pixels() -> void:
	var loaded: Dictionary = ACTIONS.load_current()
	assert_true(loaded.ok)
	var registry: Object = loaded.value.registry
	var result := ART.resolve(registry, "training", registry.fingerprint())
	assert_true(result.ok)
	if not result.ok: return
	assert_eq(result.value.art_id, "schedule.neutral_ticket.v1")
	assert_eq(result.value.compact.get_size(), Vector2(24, 24))
	assert_eq(result.value.folio.get_size(), Vector2(64, 64))
	for texture: Texture2D in [result.value.compact, result.value.folio]:
		var pixels := texture.get_image()
		var palette: Dictionary = {}
		for y in pixels.get_height():
			for x in pixels.get_width(): palette[pixels.get_pixel(x, y).to_html()] = true
		assert_eq(palette.size(), 3, "Transparent plus two literal object colors; no antialias shades.")
		assert_true(palette.has("00000000"))
		assert_true(palette.has("151b25ff"))
		assert_true(palette.has("c3baa3ff"))

func test_art_resolution_cannot_publish_metadata_or_admit_unknown_actions() -> void:
	var registry: Object = ACTIONS.load_current().value.registry
	assert_false(ART.resolve(registry, "unregistered", registry.fingerprint()).ok)
	assert_false(ART.resolve(registry, "training", "stale").ok)
	assert_false(ART.resolve(null, "training", "stale").ok)
	var result := ART.resolve(registry, "rest", registry.fingerprint())
	var keys: Array = result.value.keys()
	keys.sort()
	assert_eq(keys, ["art_id", "compact", "folio"])
