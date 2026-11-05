extends GutTest

const ART := preload("res://scripts/data/ArtManifest.gd")
const PORTRAIT := "res://tests/fixtures/art/placement-portrait-left.svg"

func before_each() -> void:
	assert_true(ART.reload_placements())

func after_each() -> void:
	ART.reload_placements()

func test_gallery_texture_survives_view_release_and_manifest_reload_releases_it() -> void:
	var texture: Texture2D = ART.get_texture("picture1")
	assert_not_null(texture)
	var retained: WeakRef = weakref(texture)
	var identity := texture.get_instance_id()
	texture = null
	assert_not_null(retained.get_ref())
	assert_eq(ART.get_texture("picture1").get_instance_id(), identity)
	assert_true(ART.reload_placements())
	assert_null(retained.get_ref())

func test_retention_is_bounded_to_the_five_gallery_assets() -> void:
	for asset_id: String in ART.GALLERY_IDS:
		assert_not_null(ART.get_texture(asset_id))
	ART.set_overlay_info("", "preview", PORTRAIT, Vector2i(320, 448), "preview")
	assert_not_null(ART.get_texture("preview"))
	assert_eq(ART._gallery_textures.size(), 5)
	assert_false(ART._gallery_textures.has("preview"))

func test_preview_override_replaces_retained_picture_and_reload_restores_catalog() -> void:
	var original_path := ART.get_asset_path("picture1")
	var original: Texture2D = ART.get_texture("picture1")
	ART.set_overlay_info("", "picture1", PORTRAIT, Vector2i(320, 448), "preview")
	var preview: Texture2D = ART.get_texture("picture1", Vector2i(320, 448))
	assert_not_null(preview)
	assert_ne(preview, original)
	assert_eq(preview.resource_path, PORTRAIT)
	assert_true(ART.reload_placements())
	assert_eq(ART.get_texture("picture1").resource_path, original_path)
