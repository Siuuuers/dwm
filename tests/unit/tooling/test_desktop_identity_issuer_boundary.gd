extends "res://addons/gut/test.gd"

# Contract tests for the boundary generator's public surface parser and CLI parser.

const GENERATOR_PATH := "res://tools/evidence/generate_desktop_identity_issuer_boundary.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const PORT_PATH := "res://scripts/application/run/CausalDayAdvanceIdentityPort.gd"

const EXPECTED_ISSUER_PREIMAGE := """configure(root_store)
issue(purpose)
verify_issued(receipt,expected_purpose)
derive_child(request)
validate_child(provenance,expected_kind)
prepare_continuation_allocation(request)
commit_continuation_allocation(candidate)
prepare_causal_day_advance(request)
commit_causal_day_advance(candidate)
capture_root()
"""

const EXPECTED_ROOT_PREIMAGE := """configure(storage,namespace_source)
load_or_create()
issue(purpose)
verify_receipt(receipt,expected_purpose)
prepare_allocation(request)
commit_allocation(candidate)
prepare_causal_day_advance(request)
commit_causal_day_advance(candidate)
capture()
"""

const EXPECTED_PORT_PREIMAGE := """configure(identity_issuer)
prepare_advance(request)
commit_advance(candidate)
"""

const PARSE_FIXTURE_SOURCE := """## public-surface fixture
@warning_ignore("unused")
func visible_one(alpha: int = 1, beta: String = "two") -> void
func _private_visible(alpha: int) -> void
static func static_only(alpha: int) -> void
    func indented(alpha: int) -> void
func visible_two() -> Dictionary
"""

const EXPECTED_PARSE_FIXTURE_PREIMAGE := """visible_one(alpha,beta)
visible_two()
"""


func test_generator_script_loads() -> void:
	var probe := DynamicScriptProbe.load_script(GENERATOR_PATH)
	assert_true(probe.get("ok", false), "boundary generator must parse and load")


func test_parse_arguments_enforces_the_exact_contract() -> void:
	var probe := _generator()
	if probe == null:
		return
	var parser := probe["value"]

	var parsed: Dictionary = parser.parse_arguments(PackedStringArray([
		"--boundary-commit=commit.1",
		"--focused-log=logs/p2r16.log",
		"--output=out.json",
		"--write",
	]))
	assert_true(parsed.get("ok", false), "all required flags plus one mode must pass")
	if not parsed.get("ok", false):
		return
	var value: Dictionary = parsed["value"]
	assert_eq(value.get("boundary_commit"), "commit.1")
	assert_eq(value.get("focused_log"), "logs/p2r16.log")
	assert_eq(value.get("output"), "out.json")
	assert_eq(value.get("mode"), "write")


func test_parse_arguments_rejects_duplicate_mode_flags() -> void:
	var parser := _generator()
	if parser == null:
		return
	var rejected: Dictionary = parser["value"].parse_arguments(PackedStringArray([
		"--boundary-commit=commit.1",
		"--focused-log=logs/p2r16.log",
		"--output=out.json",
		"--write",
		"--check",
	]))
	_assert_rejected(rejected, "duplicate --write/--check must be rejected")
	assert_eq(rejected.get("code", &""), &"ambiguous_generator_mode")


func test_parse_arguments_rejects_missing_mode_flag() -> void:
	var parser := _generator()
	if parser == null:
		return
	var rejected: Dictionary = parser["value"].parse_arguments(PackedStringArray([
		"--boundary-commit=commit.1",
		"--focused-log=logs/p2r16.log",
		"--output=out.json",
	]))
	_assert_rejected(rejected, "missing mode flag must be rejected")
	assert_eq(rejected.get("code", &""), &"generator_mode_required")


func test_parse_arguments_rejects_unknown_flag_and_duplicates() -> void:
	var parser := _generator()
	if parser == null:
		return
	var unknown: Dictionary = parser["value"].parse_arguments(PackedStringArray([
		"--boundary-commit=commit.1",
		"--focused-log=logs/p2r16.log",
		"--output=out.json",
		"--write",
		"--bad=not-a-flag",
	]))
	_assert_rejected(unknown, "unknown flag must be rejected")
	assert_eq(unknown.get("code", &""), &"unknown_generator_argument")

	var duplicated_value: Dictionary = parser["value"].parse_arguments(PackedStringArray([
		"--boundary-commit=commit.1",
		"--focused-log=logs/p2r16.log",
		"--output=out.json",
		"--output=again.json",
		"--write",
	]))
	_assert_rejected(duplicated_value, "duplicated valued flag must be rejected")
	assert_eq(duplicated_value.get("code", &""), &"duplicate_generator_argument")


func test_parse_public_surface_uses_frozen_grammar() -> void:
	var parser := _generator()
	if parser == null:
		return
	var parsed: Dictionary = parser["value"].parse_public_surface(PARSE_FIXTURE_SOURCE)
	assert_true(parsed.get("ok", false), "parse_public_surface fixture must not reject")
	if not parsed.get("ok", false):
		return
	assert_eq(str(parsed["value"]["preimage"]), EXPECTED_PARSE_FIXTURE_PREIMAGE,
		"parser must keep only source-order, top-level, non-underscore func declarations")


func test_derive_public_surface_matches_expected_plan_1_3_preimages() -> void:
	var generator := _generator()
	if generator == null:
		return
	var parser := generator["value"]

	_assert_derived_surface(parser, ISSUER_PATH, EXPECTED_ISSUER_PREIMAGE)
	_assert_derived_surface(parser, ROOT_PATH, EXPECTED_ROOT_PREIMAGE)
	_assert_derived_surface(parser, PORT_PATH, EXPECTED_PORT_PREIMAGE)


func test_derive_public_surface_rejects_missing_path() -> void:
	var parser := _generator()
	if parser == null:
		return
	var parsed: Dictionary = parser["value"].derive_public_surface("res://tools/evidence/no-such-script.gd")
	_assert_rejected(parsed, "derive_public_surface on missing path must reject")
	assert_eq(parsed.get("code", &""), &"missing_surface_source")


func _generator() -> Variant:
	var probe := DynamicScriptProbe.load_script(GENERATOR_PATH)
	if not probe.get("ok", false):
		assert_true(false, "boundary generator must load: %s" % str(probe.get("message", "")))
		return null
	return probe["value"]


func _assert_derived_surface(parser: Object, source_path: String, expected_preimage: String) -> void:
	var derived: Dictionary = parser.derive_public_surface(source_path)
	assert_true(derived.get("ok", false),
		"derive_public_surface must parse %s: %s" % [source_path, str(derived.get("message", ""))])
	if not derived.get("ok", false):
		return
	var surface: Dictionary = derived["value"]
	assert_eq(str(surface.get("preimage", "")), expected_preimage,
		"public surface preimage must match the frozen plan contract for %s" % source_path)
	assert_eq(str(surface.get("sha256", "")), _sha256(expected_preimage),
		"public surface sha256 must match the frozen SHA over that preimage for %s" % source_path)


func _assert_rejected(result: Dictionary, label: String) -> void:
	assert_false(result.get("ok", true), "%s must be rejected" % label)
	assert_ne(result.get("code", &"not_implemented"), &"not_implemented",
		"%s must fail with a real code, not a skeleton envelope" % label)


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()
