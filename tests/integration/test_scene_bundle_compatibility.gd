extends "res://addons/gut/test.gd"
## Exact A/G composition check. A owns installed DTL/label authentication; G's
## structural bundle validation deliberately cannot replace that trusted owner.
## Dedicated process with DWM_SCENE_READING_FIXTURE=1; no registry reconfiguration.
const A := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const G := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const STRICT := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const ORIGINAL := "res://tests/fixtures/dialogic/scene_reading_registration.json"
const COMPAT := "res://tests/fixtures/dialogic/scene_reading_registration_compat.json"

func _bundle() -> Dictionary:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(ORIGINAL))
	assert_true(parsed.ok, str(parsed))
	return parsed.value if parsed.ok else {}

func _target(bundle: Dictionary, target_id: String) -> Dictionary:
	for row: Dictionary in bundle.targets:
		if row.target_id == target_id: return row.target
	return {}

func test_unmodified_fixture_bytes_and_ordinary_internal_return_are_compatible() -> void:
	assert_true(FileAccess.file_exists(ORIGINAL))
	assert_true(FileAccess.file_exists(COMPAT))
	if not FileAccess.file_exists(ORIGINAL) or not FileAccess.file_exists(COMPAT): return
	assert_eq(FileAccess.get_file_as_bytes(COMPAT), FileAccess.get_file_as_bytes(ORIGINAL),
		"G compatibility fixture must retain A's exact original bytes")
	var bundle := _bundle()
	if bundle.is_empty(): return
	var target := _target(bundle, "return_a")
	assert_eq(target.label, "scene.test.a.loop")
	assert_eq(target.kind, "return")
	var owner_found := false
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == target.entry_id:
			owner_found = true
			assert_eq(programme.markers, [], "the internal return label is not an effect marker")
	assert_true(owner_found)
	var actual_dtl := A.validate_scene_registration(bundle)
	assert_true(actual_dtl.ok, str(actual_dtl))
	var structural := G.validate_bundle_structure(bundle)
	assert_true(structural.ok, str(structural))
	if not structural.ok: return
	assert_eq(structural.value.targets.return_a.target, target)

func test_both_owners_share_the_selected_complete_bundle_fingerprint() -> void:
	var bundle := _bundle()
	if bundle.is_empty(): return
	var a_checked := A.validate_scene_registration(bundle)
	var g_checked := G.validate_bundle_structure(bundle)
	assert_true(a_checked.ok, str(a_checked))
	assert_true(g_checked.ok, str(g_checked))
	if not a_checked.ok or not g_checked.ok: return
	var canonical := WRITER.stringify(bundle)
	assert_true(canonical.ok, str(canonical))
	if not canonical.ok: return
	var expected := str(canonical.value).sha256_text()
	var fingerprint := G.bundle_fingerprint(bundle)
	assert_true(fingerprint.ok, str(fingerprint))
	if not fingerprint.ok: return
	assert_eq(g_checked.value.fingerprint, expected)
	assert_eq(fingerprint.value, expected)
	var selected := A.scene_registration()
	assert_true(selected.ok, "fixture must be selected at process startup")
	if not selected.ok: return
	assert_eq(selected.value, bundle)
	assert_eq(A.scene_registration_fingerprint(), expected)
	# A structural-only change still changes B; hashing only entry identities
	# would miss this sibling-table mutation.
	var changed := bundle.duplicate(true)
	_target(changed, "return_a").label = "scene.test.a.nonexistent"
	var changed_fingerprint := G.bundle_fingerprint(changed)
	assert_true(changed_fingerprint.ok, str(changed_fingerprint))
	if changed_fingerprint.ok: assert_ne(changed_fingerprint.value, expected)
	assert_eq(A.scene_registration_fingerprint(), expected, "pure validation cannot alter selection")

func test_structural_internal_label_acceptance_requires_actual_dtl_owner() -> void:
	var bad := _bundle()
	if bad.is_empty(): return
	_target(bad, "return_a").label = "scene.test.a.nonexistent"
	var structural := G.validate_bundle_structure(bad)
	assert_true(structural.ok, "G accepts internal label shape; it does not claim DTL existence")
	var installed := A.validate_scene_registration(bad)
	assert_false(installed.ok, "A must refuse the nonexistent label in the installed DTL")
	_target(bad, "return_a").label = "scene.test.a.loop"
	assert_true(A.validate_scene_registration(bad).ok)
	assert_true(G.validate_bundle_structure(bad).ok)

func test_g_exact_members_and_callable_label_law_remain_closed() -> void:
	for mutation: String in ["bundle_member", "target_member", "programme_member", "callable_label", "target_version", "target_programme"]:
		var bad := _bundle()
		if bad.is_empty(): return
		match mutation:
			"bundle_member": bad["caller_override"] = true
			"target_member": _target(bad, "return_a")["caller_override"] = true
			"programme_member": bad.scene_programme.entries[0]["caller_override"] = true
			"callable_label": _target(bad, "target_a").label = "scene.test.a.loop"
			"target_version": _target(bad, "return_a").content_version = 2
			"target_programme": _target(bad, "return_a").program_sha256 = "0".repeat(64)
		assert_false(G.validate_bundle_structure(bad).ok, mutation)
		assert_false(A.validate_scene_registration(bad).ok, mutation)

