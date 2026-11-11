extends "res://addons/gut/test.gd"
const ART := preload("res://scripts/data/ArtManifest.gd")

func after_each() -> void:
	ART.reload_placements()

func test_cached_picture_retains_size_checks_and_replacement_ownership() -> void:
	assert_true(ART.reload_placements())
	var original := ART.get_texture("picture1")
	assert_not_null(original)
	if original == null: return
	assert_same(ART.get_texture("picture1", Vector2i(original.get_size())), original)
	assert_null(ART.get_texture("picture1", Vector2i(1, 1)))
	assert_same(ART.get_texture("picture1"), original)
	ART.set_overlay_info("", "picture1", "res://icon.svg", Vector2i(128, 128), "fixture")
	assert_false(ART._gallery_textures.has("picture1"))
	var replacement := ART.get_texture("picture1")
	assert_not_null(replacement)
	if replacement == null: return
	assert_eq(replacement.resource_path, "res://icon.svg")
	assert_ne(replacement, original)
	assert_same(ART.get_texture("picture1"), replacement)
	assert_true(ART.reload_placements())
	assert_true(ART._gallery_textures.is_empty())
	assert_same(ART.get_texture("picture1"), original)
