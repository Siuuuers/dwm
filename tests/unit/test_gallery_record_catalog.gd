extends GutTest

const CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")

func _alone(dark: bool = false) -> Dictionary:
	return {"entry_id": "ending.alone.dark_mode" if dark else "ending.alone.normal",
		"schema_version": 1, "fields": {"ending_role": "core",
		"ending_form": "alone_dark_mode" if dark else "alone_normal"}}

func _id(signature: Dictionary) -> String:
	return str(SIGNATURE.validate(signature).value.signature_id)

func _base() -> Dictionary:
	return {"ending.alone": {"sentence": ["Base", "基础", "基礎"],
		"media_asset_id": "archive.ending.alone.media"}}

func test_shipped_metadata_is_valid() -> void:
	assert_true(CATALOG.new().valid)

func test_reached_date_accepts_defaults_and_exact_details() -> void:
	var signature := {"entry_id": "dating.solo.priscilla.day1.pre_challenge",
		"schema_version": 1, "fields": {"tier": "friend", "tone": "sweet",
			"attitude": "ordinary", "echo_ids": []}}
	var catalog = CATALOG.new({signature.entry_id: {"sentence": ["Base", "Base", "Base"],
		"media_asset_id": "archive.date"}}, [{"signature": signature,
		"sentence": ["Exact", "Exact", "Exact"],
		"version_cue": ["TEST date cue", "TEST 日期提示", "TEST 日期提示"]}])
	assert_true(catalog.valid)
	assert_eq(catalog.projection(signature.entry_id, "", "en"),
		{"sentence": "Base", "media_asset_id": "archive.date"})
	assert_eq(catalog.projection(signature.entry_id, _id(signature), "en"),
		{"sentence": "Exact", "media_asset_id": "archive.date"})
	assert_eq(catalog.version_cue(signature.entry_id, _id(signature), "en"), "TEST date cue")
	assert_eq(catalog.version_cue("ending.alone", _id(signature), "en"), "")

func test_non_gallery_entries_reject_defaults_and_exact_details() -> void:
	var signature := {"entry_id": "hospital.faint.day7", "schema_version": 1,
		"fields": {"miss_reason": "condition"}}
	assert_true(SIGNATURE.validate(signature).get("ok", false))
	var defaults = CATALOG.new({signature.entry_id: {"media_asset_id": "archive.hospital"}}, [])
	var exact = CATALOG.new({}, [{"signature": signature, "media_asset_id": "archive.hospital"}])
	for catalog in [defaults, exact]:
		assert_false(catalog.valid)
		assert_eq(catalog.projection(signature.entry_id, _id(signature), "en"),
			{"sentence": "", "media_asset_id": ""})

func test_default_and_exact_override_precedence_use_locale_aliases() -> void:
	var normal := _alone()
	var dark := _alone(true)
	var catalog = CATALOG.new(_base(), [
		{"signature": normal, "sentence": ["Exact", "精确", "精確"]},
		{"signature": dark, "media_asset_id": "archive.ending.alone.dark"}])
	assert_true(catalog.valid)
	assert_eq(catalog.projection("ending.alone", "unknown", "en"),
		{"sentence": "Base", "media_asset_id": "archive.ending.alone.media"})
	assert_eq(catalog.projection("ending.alone", _id(normal), "zh_CN"),
		{"sentence": "精确", "media_asset_id": "archive.ending.alone.media"})
	assert_eq(catalog.projection("ending.alone", _id(dark), "zh-HK"),
		{"sentence": "基礎", "media_asset_id": "archive.ending.alone.dark"})

func test_explicit_empty_override_suppresses_inherited_copy_and_media() -> void:
	var signature := _alone()
	var catalog = CATALOG.new(_base(), [{"signature": signature,
		"sentence": ["", "", ""], "media_asset_id": ""}])
	assert_true(catalog.valid)
	assert_eq(catalog.projection("ending.alone", _id(signature), "en"),
		{"sentence": "", "media_asset_id": ""})

func test_exact_signature_details_cannot_leak_to_another_record() -> void:
	var signature := _alone()
	var defaults := _base()
	defaults["ending.priscilla.sweet"] = {"sentence": ["Other", "其他", "其他"]}
	var catalog = CATALOG.new(defaults, [{"signature": signature,
		"sentence": ["Alone exact", "独处精确", "獨處精確"]}])
	assert_eq(catalog.projection("ending.priscilla.sweet", _id(signature), "en"),
		{"sentence": "Other", "media_asset_id": ""})

func test_constructor_detaches_source_definitions_and_projection_results() -> void:
	var details := _base()
	var signature := _alone()
	var overrides := [{"signature": signature, "sentence": ["Exact", "精确", "精確"]}]
	var catalog = CATALOG.new(details, overrides)
	details["ending.alone"].sentence[0] = "mutated"
	signature.fields.ending_form = "alone_dark_mode"
	overrides[0].sentence[0] = "mutated"
	var result: Dictionary = catalog.projection("ending.alone", _id(_alone()), "en")
	assert_eq(result, {"sentence": "Exact", "media_asset_id": "archive.ending.alone.media"})
	result.sentence = "changed"
	assert_eq(catalog.projection("ending.alone", _id(_alone()), "en").sentence, "Exact")

func test_invalid_fields_types_and_signatures_fail_closed() -> void:
	var invalid := [
		CATALOG.new({"ending.alone": {"description": ["x", "x", "x"]}}, []),
		CATALOG.new({"ending.alone": {"sentence": ["two", "only"]}}, []),
		CATALOG.new({"ending.alone": {"media_asset_id": 7}}, []),
		CATALOG.new({"ending.alone.normal": {"sentence": ["x", "x", "x"]}}, []),
		CATALOG.new({"ending.alone": {"sentence": ["x", "x", "x"]},
			7: {"sentence": ["x", "x", "x"]}}, []),
		CATALOG.new({}, [{"signature": {}, "sentence": ["x", "x", "x"]}]),
		CATALOG.new({}, [{"signature": _alone(), "unknown": "x"}])]
	for catalog in invalid:
		assert_false(catalog.valid)
		assert_eq(catalog.projection("ending.alone", _id(_alone()), "en"),
			{"sentence": "", "media_asset_id": ""})

func test_duplicate_canonical_signature_records_invalidate_the_catalog() -> void:
	var signature := _alone()
	var catalog = CATALOG.new({}, [{"signature": signature, "media_asset_id": "one"},
		{"signature": signature.duplicate(true), "media_asset_id": "two"}])
	assert_false(catalog.valid)
	assert_eq(catalog.projection("ending.alone", _id(signature), "en"),
		{"sentence": "", "media_asset_id": ""})

func test_exact_version_cues_resolve_locale_aliases_without_changing_record_projection() -> void:
	# Explicitly noncanonical TEST copy; this does not register production version cues.
	var signature := _alone()
	var catalog = CATALOG.new(_base(), [{"signature": signature,
		"version_cue": ["TEST cue", "TEST 简体提示", "TEST 繁體提示"]}])
	assert_true(catalog.valid)
	for locale: String in ["en", "ja", "ko"]:
		assert_eq(catalog.version_cue("ending.alone", _id(signature), locale), "TEST cue")
	for locale: String in ["zh_CN", "zh-CN"]:
		assert_eq(catalog.version_cue("ending.alone", _id(signature), locale), "TEST 简体提示")
	for locale: String in ["zh_HK", "zh-HK"]:
		assert_eq(catalog.version_cue("ending.alone", _id(signature), locale), "TEST 繁體提示")
	assert_eq(catalog.projection("ending.alone", _id(signature), "en"),
		{"sentence": "Base", "media_asset_id": "archive.ending.alone.media"})

func test_version_cues_never_inherit_sentences_or_cross_exact_identity() -> void:
	var signature := _alone()
	var catalog = CATALOG.new(_base(), [
		{"signature": signature, "version_cue": ["TEST cue", "TEST cue", "TEST cue"]},
		{"signature": _alone(true), "sentence": ["TEST sentence", "TEST sentence", "TEST sentence"]}])
	assert_true(catalog.valid)
	assert_eq(catalog.version_cue("ending.alone", _id(_alone(true)), "en"), "")
	assert_eq(catalog.version_cue("ending.alone", "unknown", "en"), "")
	assert_eq(catalog.version_cue("ending.priscilla.sweet", _id(signature), "en"), "")
	assert_eq(catalog.version_cue("unknown", _id(signature), "en"), "")
	assert_eq(CATALOG.new().version_cue("ending.alone", _id(signature), "en"), "",
		"Production metadata still contains no authored exact-version cue")

func test_version_cue_definitions_are_detached_from_the_caller() -> void:
	var signature := _alone()
	var cue := ["TEST cue", "TEST 简体提示", "TEST 繁體提示"]
	var overrides := [{"signature": signature, "version_cue": cue}]
	var catalog = CATALOG.new({}, overrides)
	cue[0] = "changed"
	overrides[0].version_cue[1] = "changed"
	signature.fields.ending_form = "alone_dark_mode"
	assert_true(catalog.valid)
	assert_eq(catalog.version_cue("ending.alone", _id(_alone()), "en"), "TEST cue")
	assert_eq(catalog.version_cue("ending.alone", _id(_alone()), "zh_CN"), "TEST 简体提示")

func test_version_cues_reject_base_defaults_and_malformed_or_blank_translations() -> void:
	var cue := ["TEST cue", "TEST cue", "TEST cue"]
	var base = CATALOG.new({"ending.alone": {"version_cue": cue}}, [])
	assert_false(base.valid, "An ending-level default cannot label exact versions")
	assert_eq(base.version_cue("ending.alone", _id(_alone()), "en"), "")
	var malformed: Array = [null, "TEST cue", {}, [], ["TEST cue", "TEST cue"],
		["TEST cue", "TEST cue", "TEST cue", "TEST cue"],
		[7, "TEST cue", "TEST cue"], ["TEST cue", null, "TEST cue"],
		["TEST cue", "TEST cue", {}], ["", "TEST cue", "TEST cue"],
		["TEST cue", " \t", "TEST cue"], ["TEST cue", "TEST cue", "\n"]]
	for value: Variant in malformed:
		var catalog = CATALOG.new(_base(), [{"signature": _alone(), "version_cue": value}])
		assert_false(catalog.valid, str(value))
		assert_eq(catalog.version_cue("ending.alone", _id(_alone()), "en"), "")
		assert_eq(catalog.projection("ending.alone", _id(_alone()), "en"),
			{"sentence": "", "media_asset_id": ""})

func test_version_cues_require_valid_unique_gallery_signatures() -> void:
	var cue := ["TEST cue", "TEST cue", "TEST cue"]
	var hospital := {"entry_id": "hospital.faint.day7", "schema_version": 1,
		"fields": {"miss_reason": "condition"}}
	var invalid := [
		CATALOG.new({}, [{"signature": {}, "version_cue": cue}]),
		CATALOG.new({}, [{"signature": hospital, "version_cue": cue}]),
		CATALOG.new({}, [{"signature": _alone(), "version_cue": cue},
			{"signature": _alone(), "version_cue": cue}])]
	for catalog in invalid:
		assert_false(catalog.valid)
		assert_eq(catalog.version_cue("ending.alone", _id(_alone()), "en"), "")
