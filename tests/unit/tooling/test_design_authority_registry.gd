extends "res://addons/gut/test.gd"

const REGISTRY_PATH := "res://tools/docs/DesignAuthorityRegistry.gd"
var _counter := 0

func _write(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(text)
	file.close()

func _root() -> String:
	_counter += 1
	var result: Dictionary = TemporaryStorage.create("design-authority-%d" % _counter)
	assert_true(result.ok, result.get("message", ""))
	if not result.ok:
		return ""
	return result.value

func _design(id: String, kind: String, extra: String = "", plan: String = "") -> String:
	return "---\nid: %s\nkind: %s\nschema_version: 1\nconversational_design_status: approved\nwritten_spec_status: approved\nimplementation_authorized: false\n%s%s---\n\n# Authority\n" % [id, kind, extra, plan]

func _manifest(records: Array[Dictionary]) -> String:
	return JSON.stringify({"schema_version": 1, "records": records}, "  ") + "\n"

func _valid_fixture() -> Dictionary:
	var root := _root()
	if root.is_empty():
		return {}
	var base_path := "docs/design/base.md"
	var amendment_path := "docs/design/amendment.md"
	_write(root.path_join(base_path), _design("spec.base", "design_specification"))
	_write(root.path_join(amendment_path), _design(
		"spec.amendment", "design_amendment",
		"decision_status: accepted\namends: spec.base\namends_path: \"docs/design/base.md\"\n"
	))
	_write(root.path_join("prompt_docs/metadata/design_authority_registry.v1.json"), _manifest([
		{"id":"spec.amendment", "kind":"design_amendment", "path":amendment_path},
		{"id":"spec.base", "kind":"design_specification", "path":base_path},
	]))
	return {"root": root, "manifest": root.path_join("prompt_docs/metadata/design_authority_registry.v1.json")}

func _validate(fixture: Dictionary) -> Dictionary:
	var loaded: Script = load(REGISTRY_PATH)
	assert_not_null(loaded, "DesignAuthorityRegistry.gd must exist")
	if loaded == null:
		return {"ok": false, "errors": ["missing registry"]}
	return loaded.new().validate(fixture.root, fixture.manifest)

func _has_code(result: Dictionary, code: String) -> bool:
	return result.get("errors", []).any(func(error: Variant) -> bool: return str(error).begins_with(code))

func test_closed_registry_accepts_a_registered_base_and_amendment() -> void:
	var result := _validate(_valid_fixture())
	assert_true(result.get("ok", false), JSON.stringify(result.get("errors", [])))
	assert_eq(result.get("records", []).map(func(record: Dictionary) -> Variant: return record.id), ["spec.amendment", "spec.base"])

func test_registry_rejects_duplicate_ids_paths_and_unsorted_records() -> void:
	for mutation: Callable in [
		func(records: Array) -> void: records[1].id = records[0].id,
		func(records: Array) -> void: records[1].path = records[0].path,
		func(records: Array) -> void: records.reverse(),
	]:
		var fixture := _valid_fixture()
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture.manifest))
		mutation.call(parsed.records)
		_write(fixture.manifest, JSON.stringify(parsed, "  ") + "\n")
		assert_false(_validate(fixture).get("ok", true))

func test_registry_enforces_the_manifest_id_and_exact_source_path_grammar() -> void:
	for field_and_value: Array in [
		["id", "Spec.Bad"],
		["path", "docs/design/nested/base.md"],
	]:
		var fixture := _valid_fixture()
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture.manifest))
		parsed.records[0][field_and_value[0]] = field_and_value[1]
		_write(fixture.manifest, JSON.stringify(parsed, "  ") + "\n")
		assert_true(_has_code(_validate(fixture), "DESIGN_AUTHORITY_MANIFEST_INVALID"))

func test_amendment_requires_accepted_status_and_exact_registered_lineage() -> void:
	for replacement: String in [
		"decision_status: decision_required",
		"amends: spec.missing",
		"amends_path: \"docs/design/other.md\"",
	]:
		var fixture := _valid_fixture()
		var path: String = fixture.root.path_join("docs/design/amendment.md")
		var text := FileAccess.get_file_as_string(path)
		if replacement.begins_with("decision_status"):
			text = text.replace("decision_status: accepted", replacement)
		elif replacement.begins_with("amends:"):
			text = text.replace("amends: spec.base", replacement)
		else:
			text = text.replace("amends_path: \"docs/design/base.md\"", replacement)
		_write(path, text)
		assert_true(_has_code(_validate(fixture), "DESIGN_AUTHORITY_LINEAGE_INVALID") or _has_code(_validate(fixture), "DESIGN_AUTHORITY_SOURCE_INVALID"))

func test_optional_plan_binding_is_all_or_none_and_hash_checked() -> void:
	var fixture := _valid_fixture()
	var path: String = fixture.root.path_join("docs/design/base.md")
	var text := FileAccess.get_file_as_string(path)
	_write(path, text.replace("implementation_authorized: false\n", "implementation_authorized: false\nimplementation_plan_path: \"docs/superpowers/plans/base.md\"\n"))
	assert_true(_has_code(_validate(fixture), "DESIGN_AUTHORITY_PLAN_INVALID"))
	var plan_path: String = str(fixture.root).path_join("docs/superpowers/plans/base.md")
	_write(plan_path, "# Plan\n")
	var digest: String = FileAccess.get_file_as_string(plan_path).sha256_text()
	_write(path, text.replace("implementation_authorized: false\n", "implementation_authorized: false\nimplementation_plan_path: \"docs/superpowers/plans/base.md\"\nimplementation_plan_status: proposed\nimplementation_plan_sha256: %s\n" % digest))
	assert_true(_validate(fixture).get("ok", false), JSON.stringify(_validate(fixture).get("errors", [])))
	_write(plan_path, "# Changed\n")
	assert_true(_validate(fixture).get("ok", false), "plan approval/digest drift must not invalidate design authority")

func test_optional_plan_suite_binding_is_closed_and_projects_every_exact_plan() -> void:
	var fixture := _valid_fixture()
	var source_path: String = fixture.root.path_join("docs/design/base.md")
	var source := FileAccess.get_file_as_string(source_path)
	_write(source_path, source.replace("implementation_authorized: false\n", "implementation_authorized: false\nimplementation_plan_suite_path: \"prompt_docs/metadata/sample_plan_suite.v1.json\"\n"))
	assert_true(_has_code(_validate(fixture), "DESIGN_AUTHORITY_PLAN_SUITE_INVALID"))
	var roadmap_path := "docs/superpowers/plans/roadmap.md"
	var child_path := "docs/superpowers/plans/child.md"
	_write(fixture.root.path_join(roadmap_path), "# Roadmap\n")
	_write(fixture.root.path_join(child_path), "# Child\n")
	_write(fixture.root.path_join("prompt_docs/metadata/sample_plan_suite.v1.json"), JSON.stringify({
		"schema_version":1,
		"specification_id":"spec.base",
		"status":"proposed",
		"roadmap":{"path":roadmap_path, "status":"proposed", "sha256":"__REPLACE_WITH_CANONICAL_SHA256_ROADMAP__"},
		"plans":[{"path":child_path, "status":"proposed", "sha256":"__REPLACE_WITH_CANONICAL_SHA256_PLAN_01__"}],
	}, "  ") + "\n")
	_write(source_path, source.replace("implementation_authorized: false\n", "implementation_authorized: false\nimplementation_plan_suite_path: \"prompt_docs/metadata/sample_plan_suite.v1.json\"\nimplementation_plan_suite_status: proposed\nimplementation_plan_suite_sha256: \"__REPLACE_WITH_CANONICAL_SHA256_PLAN_SUITE__\"\n"))
	var result := _validate(fixture)
	assert_true(result.get("ok", false), JSON.stringify(result.get("errors", [])))
	var base_records: Array = result.get("records", []).filter(func(record: Dictionary) -> bool: return record.id == "spec.base")
	assert_eq(base_records.size(), 1)
	assert_eq(base_records[0].get("plan_suite", {}).get("records", []).map(func(record: Dictionary) -> Variant: return record.path), [roadmap_path, child_path])
	var suite_path: String = str(fixture.root).path_join("prompt_docs/metadata/sample_plan_suite.v1.json")
	var suite: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(suite_path))
	suite.plans.append(suite.plans[0].duplicate(true))
	_write(suite_path, JSON.stringify(suite, "  ") + "\n")
	assert_true(_has_code(_validate(fixture), "IMPLEMENTATION_PLAN_SUITE_INVALID"))

func test_approved_plan_suite_binding_drift_preserves_specification_authority() -> void:
	var fixture := _valid_fixture()
	var roadmap_path := "docs/superpowers/plans/roadmap.md"
	var child_path := "docs/superpowers/plans/child.md"
	var suite_path := "prompt_docs/metadata/sample_plan_suite.v1.json"
	_write(fixture.root.path_join(roadmap_path), "# Roadmap\n")
	_write(fixture.root.path_join(child_path), "# Child\n")
	var suite := {
		"schema_version":1,
		"specification_id":"spec.base",
		"status":"approved",
		"roadmap":{"path":roadmap_path, "status":"approved", "sha256":FileAccess.get_file_as_string(fixture.root.path_join(roadmap_path)).sha256_text()},
		"plans":[{"path":child_path, "status":"approved", "sha256":FileAccess.get_file_as_string(fixture.root.path_join(child_path)).sha256_text()}],
	}
	_write(fixture.root.path_join(suite_path), JSON.stringify(suite, "  ") + "\n")
	var source_path: String = fixture.root.path_join("docs/design/base.md")
	var source := FileAccess.get_file_as_string(source_path)
	var suite_digest := FileAccess.get_file_as_string(fixture.root.path_join(suite_path)).sha256_text()
	_write(source_path, source.replace("implementation_authorized: false\n", "implementation_authorized: false\nimplementation_plan_suite_path: \"%s\"\nimplementation_plan_suite_status: approved\nimplementation_plan_suite_sha256: %s\n" % [suite_path, suite_digest]))
	assert_true(_validate(fixture).get("ok", false), JSON.stringify(_validate(fixture).get("errors", [])))
	_write(fixture.root.path_join(child_path), "# Changed Child\n")
	assert_true(_validate(fixture).get("ok", false), "plan drift changes execution approval, not specification authority")
	_write(fixture.root.path_join(child_path), "# Child\n")
	_write(fixture.root.path_join(suite_path), FileAccess.get_file_as_string(fixture.root.path_join(suite_path)) + "\n")
	assert_true(_validate(fixture).get("ok", false), "suite digest drift changes execution approval, not specification authority")

func test_runtime_authorization_requires_an_approved_verified_binding() -> void:
	var fixture := _valid_fixture()
	var source_path: String = fixture.root.path_join("docs/design/base.md")
	var source := FileAccess.get_file_as_string(source_path)
	_write(source_path, source.replace("implementation_authorized: false", "implementation_authorized: true"))
	assert_true(_has_code(_validate(fixture), "DESIGN_AUTHORITY_AUTHORIZATION_INVALID"))

func test_repository_registry_resolves_the_accepted_amendment() -> void:
	var loaded: Script = load(REGISTRY_PATH)
	assert_not_null(loaded)
	if loaded == null:
		return
	var result: Dictionary = loaded.new().validate("res://", "res://prompt_docs/metadata/design_authority_registry.v1.json")
	assert_true(result.get("ok", false), JSON.stringify(result.get("errors", [])))
	var ids: Array = result.get("records", []).map(func(record: Dictionary) -> Variant: return record.id)
	assert_has(ids, "spec.seven_day_dialogic_flow")
	assert_has(ids, "spec.desktop_minesweeper_shop_schedule_amendment")
	var amendment_records: Array = result.get("records", []).filter(func(record: Dictionary) -> bool: return record.id == "spec.desktop_minesweeper_shop_schedule_amendment")
	assert_eq(amendment_records.size(), 1)
	assert_eq(amendment_records[0].get("plan_suite", {}).get("records", []).size(), 5)
	assert_eq(amendment_records[0].get("plan_suite", {}).get("status"), "approved")
	# Runtime authorization was granted for this amendment in 321a7ef, so the registry must resolve
	# it as true. The Phase-2R foundation-repair record below stays false: it is a pointer document
	# carrying neither an approved plan nor an approved plan-suite binding, and
	# DesignAuthorityRegistry permits the flag only on a document that carries one.
	assert_true(amendment_records[0].get("fields", {}).get("implementation_authorized", false))
	var phase2r_records: Array = result.get("records", []).filter(func(record: Dictionary) -> bool: return record.id == "spec.phase_2r.foundation_repair")
	assert_eq(phase2r_records.size(), 1)
	assert_eq(phase2r_records[0].get("kind"), "design_specification")
	assert_false(phase2r_records[0].get("fields", {}).get("implementation_authorized", true))
	assert_false(phase2r_records[0].get("fields", {}).has("implementation_plan_path"))
	assert_false(phase2r_records[0].get("fields", {}).has("implementation_plan_suite_path"))
