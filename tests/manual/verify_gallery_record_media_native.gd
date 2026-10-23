extends "res://tests/manual/verify_gallery_record_paper_native.gd"
## Exact registered fixture pixels through the real Gallery and art loader.
const CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const MEDIA_ID := "archive.test.exact_record"

func _create_gallery() -> Control:
	var gallery := super._create_gallery()
	gallery._record_catalog = CATALOG.new({}, [])
	return gallery

func _sample(locale: String, percent: int, palette: String) -> bool:
	if not await super._sample(locale, percent, palette): return false
	var before: Dictionary = _profile.get_profile_snapshot()
	var starts := _bridge.starts.duplicate()
	var signature_id: String = _gallery._selected_signature_id()
	var signature: Dictionary = _gallery._versions[_gallery._selected_version].signature
	var sentences := ["A registered archive sentence.", "\u4e00\u53e5\u5df2\u767b\u8bb0\u7684\u6863\u6848\u6587\u5b57\u3002", "\u4e00\u53e5\u5df2\u767b\u8a18\u7684\u6a94\u6848\u6587\u5b57\u3002"]
	_gallery._record_catalog = CATALOG.new({}, [{"signature": signature,
		"sentence": sentences, "media_asset_id": MEDIA_ID}])
	_check(_gallery._record_catalog.valid, "fixture metadata registration failed")
	ART.set_overlay_info("", MEDIA_ID, "res://tests/fixtures/art/gallery-258x78.svg", Vector2i(258, 78), "fixture")
	_gallery._refresh_record_copy()
	await _frames()
	var paper: Control = _gallery._record_paper
	var title: Label = paper.title_label
	var sentence: Label = paper.sentence_label
	var host: Control = _gallery.get_node("%GalleryHost")
	_check(title.global_position - host.global_position == Vector2(392, 208), "registered media title offset changed")
	_check(sentence.position.y == 192 + title.size.y and not sentence.text.is_empty(), "sentence is missing or has wrong rhythm")
	var filename := "%s-%d-%s-media.png" % [locale.replace("_", "-"), percent, palette]
	var picture := await _capture(filename)
	if picture == null: return false
	var ink := _gallery.theme.get_color("paper_ink", "Gallery")
	_check(_near_rgb8(picture.get_pixel(196, 16), ink), "compact perimeter missing")
	for point: Vector2i in [Vector2i(197, 17), Vector2i(454, 94)]:
		_check(_near_rgb8(picture.get_pixelv(point), Color("edc769")), "authored one-pixel edge changed")
	_check(_near_rgb8(picture.get_pixel(325, 20), Color("b2395b")), "left media pixel was filtered or recolored")
	_check(_near_rgb8(picture.get_pixel(326, 20), Color("21848e")), "right media pixel was resampled or recolored")
	var sentence_rect := Rect2i(Vector2i(sentence.global_position / 2), Vector2i(sentence.size / 2))
	_check(_find_ink(picture, sentence_rect, ink, _gallery.theme.get_color("paper", "Gallery")) != Vector2i(-1, -1),
		"registered localized sentence has no native ink")
	if _samples.size() == 1:
		for bad_path: String in ["res://tests/fixtures/art/placement-cg.svg", "res://art/archive/not-installed.png"]:
			ART.set_overlay_info("", MEDIA_ID, bad_path, Vector2i(258, 78), "fixture")
			_gallery._refresh_record_copy()
			await _frames()
			_check(paper._media.texture == null and title.position == Vector2.ZERO,
				"missing/wrong export left a frame or gap")
	_check(_profile.get_profile_snapshot() == before and _bridge.starts == starts, "metadata projection changed player state or playback")
	_check(_gallery._selected_signature_id() == signature_id, "metadata changed exact replay selection")
	var sample: Dictionary = _samples[-1]
	sample["record_media_file"] = filename
	sample["record_media_checks"] = {"exact_pixels": true, "sentence": true, "profile_and_replay_unchanged": true}
	_samples[-1] = sample
	_gallery._record_catalog = CATALOG.new({}, [])
	_gallery._refresh_record_copy()
	await _frames()
	return _failures.is_empty()
