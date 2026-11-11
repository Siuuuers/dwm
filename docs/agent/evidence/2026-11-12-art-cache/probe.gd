extends "res://addons/gut/test.gd"
const ART := preload("res://scripts/data/ArtManifest.gd")
const VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
func test_refresh_cost() -> void:
	assert_true(ART.reload_placements())
	var textures: Array[Texture2D] = []
	for id: String in ART.GALLERY_IDS:
		var texture := ART.get_texture(id)
		assert_not_null(texture)
		textures.append(texture)
	var started := Time.get_ticks_usec()
	for repeat: int in 1000:
		for id: String in ART.GALLERY_IDS: ART.get_texture(id)
	print("ART_CACHE_LOOKUP_US ", Time.get_ticks_usec() - started)
	var view := VIEW.new()
	add_child_autofree(view)
	var entry: String = "draft.reading.early"
	view.configure_entry(entry, 125, false, true, true)
	started = Time.get_ticks_usec()
	for repeat: int in 100: view.configure_entry(entry, 125, false, true, true)
	print("ART_REFRESH_US ", Time.get_ticks_usec() - started)
	for index: int in ART.GALLERY_IDS.size():
		assert_same(ART.get_texture(ART.GALLERY_IDS[index]), textures[index])
		assert_null(ART.get_texture(ART.GALLERY_IDS[index], Vector2i(1, 1)))
