extends "res://addons/gut/test.gd"
# Boundary tooling contract for Plan 02 Task 1 (dwm-p2r.16).
#
# OBLIGATION MAP (dwm-p2r.16 DECISION 9.13 -- each file names what it owns):
#   * Step 1.1 load/parse probes for the generator, MinesweeperShopRegistry, and all five Task-1
#     JSON documents (DECISION 8.4). Retained from the skeleton half.
#   * Unclaused frozen law, plan line 851: the three public-surface preimages and their SHA-256,
#     DERIVED by parsing current source and never hardcoded (DECISION 8.1/8.2, 11.1-11.5). DEEP.
#   * Unclaused frozen law, plan line 851: the exact four-flag CLI contract with --write/--check
#     exclusivity (DECISION 11.6). DEEP.
#   * Clause 46 support: MinesweeperShopRegistry record content and manifest envelope, which
#     DataCatalog parity cannot reach because DataCatalog carries no capability_ids, no
#     cap.per_causal_day, and no envelope (DECISION 11.7, an explicit extension of DECISION 9.6).
#     DEEP.
# The CLI and surface rows are "unclaused frozen law" rather than one of the 46 plan-797 clauses,
# the same row type DECISION 10.3 introduced for the two frozen port laws, so DECISION 9.11
# condition (4) still accounts for every test in this file.
#
# DELIBERATELY ABSENT: validation of the immutable boundary RECORD at
# evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json, and the
# DWM_REQUIRE_CURRENT_P2R16_BOUNDARY=1 branch at plan line 853. Step 1.4 runs this file expecting
# exit 0, but that record does not exist until Step 1.6, so any unconditional record assertion
# would make Step 1.4 GREEN structurally impossible (DECISION 9.6). Shop records carry none of that
# risk: Step 1.3 populates the manifest, which is why 11.7 can extend the scope safely.
#
# RETIRED MODE (dwm-p2r.34, 2026-08-24): the DWM_REQUIRE_CURRENT_P2R16_BOUNDARY=1 current-byte
# branch this file later gained is GONE. Plan line 851 scopes that invariant to "only through the
# close of dwm-p2r.9" (closed 2026-08-17), and the plan's `.9` entry gate rules that after closure
# consumers validate the immutable v1 record against its named commit tree plus ancestry, never
# against current working-tree bytes -- and that re-pinning v1 hashes to evolved files does not
# satisfy the gate. The environment value the plan's gate blocks export is therefore a no-op now:
# those blocks run the same permanent historical validation the default suite runs, and the
# drift-independence test below pins the retirement against reintroduction.
#
# TWO PARSE HAZARDS THIS FILE IS WRITTEN AGAINST:
#   * DECISION 9.18 -- the 20 new Task-1 scripts are absent from the global class cache under a
#     headless run, so they are preloaded by path as file-level consts, never referenced by
#     class_name.
#   * DECISION 10.7/11.11 -- GUT installs its own warning set and treats an inferred-Variant `:=`
#     as a parse error, and a static called through a preloaded const may not resolve its return
#     type. Every local declaration below therefore carries an EXPLICIT type annotation.

const GENERATOR := preload("res://tools/evidence/generate_desktop_identity_issuer_boundary.gd")
const SHOP_REGISTRY := preload("res://scripts/domain/shop/MinesweeperShopRegistry.gd")

const SCRIPT_PATHS := {
	"generate_desktop_identity_issuer_boundary": "res://tools/evidence/generate_desktop_identity_issuer_boundary.gd",
	"MinesweeperShopRegistry": "res://scripts/domain/shop/MinesweeperShopRegistry.gd",
}

const JSON_PATHS := {
	"desktop-issuer-root.schema.json": "res://data/schemas/desktop-issuer-root.schema.json",
	"desktop-continuation-operation-journal.schema.json": "res://data/schemas/desktop-continuation-operation-journal.schema.json",
	"desktop-identity-issuer-boundary.schema.json": "res://data/schemas/desktop-identity-issuer-boundary.schema.json",
	"minesweeper-shop.schema.json": "res://data/schemas/minesweeper-shop.schema.json",
	"minesweeper_shop.v1.json": "res://data/manifests/minesweeper_shop.v1.json",
}

# ---- the three frozen public surfaces (plan line 851) ----
# The preimage strings are copied verbatim from plan line 851. The digests are their independently
# computed lowercase SHA-256 (DECISION 11.4): pinning BOTH is double-entry, because the preimage
# catches a wrong surface while the digest catches a wrong hashing convention -- uppercase output,
# a stray newline, or the wrong encoding.

const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const PORT_PATH := "res://scripts/application/run/CausalDayAdvanceIdentityPort.gd"

const ISSUER_PREIMAGE := "configure(root_store)\nissue(purpose)\nverify_issued(receipt,expected_purpose)\nderive_child(request)\nvalidate_child(provenance,expected_kind)\nprepare_continuation_allocation(request)\ncommit_continuation_allocation(candidate)\nprepare_causal_day_advance(request)\ncommit_causal_day_advance(candidate)\ncapture_root()\n"
const ROOT_STORE_PREIMAGE := "configure(storage,namespace_source)\nload_or_create()\nissue(purpose)\nverify_receipt(receipt,expected_purpose)\nprepare_allocation(request)\ncommit_allocation(candidate)\nprepare_causal_day_advance(request)\ncommit_causal_day_advance(candidate)\ncapture()\n"
const PORT_PREIMAGE := "configure(identity_issuer)\nprepare_advance(request)\ncommit_advance(candidate)\n"

const ISSUER_SURFACE_SHA256 := "bea08bbff6a60719a37619d20b625f298dce27f8bba402afd5dd385018964d49"
const ROOT_STORE_SURFACE_SHA256 := "2134c00e0c9a7c752c83d2dc3dc3633b97da37824b68ffbe465d5c0799b38c2d"
const PORT_SURFACE_SHA256 := "c1208b4304842ef05998656f8d62de20307b5ae66cd79a9eef9fbef293ffc214"

const SURFACE_EXPECTATIONS := [
	{
		"field": "public_surface_sha256",
		"path": ISSUER_PATH,
		"preimage": ISSUER_PREIMAGE,
		"sha256": ISSUER_SURFACE_SHA256,
	},
	{
		"field": "root_store_public_surface_sha256",
		"path": ROOT_STORE_PATH,
		"preimage": ROOT_STORE_PREIMAGE,
		"sha256": ROOT_STORE_SURFACE_SHA256,
	},
	{
		"field": "day_advance_identity_port_public_surface_sha256",
		"path": PORT_PATH,
		"preimage": PORT_PREIMAGE,
		"sha256": PORT_SURFACE_SHA256,
	},
]

# ---- parser rule sample (DECISION 11.3) ----
# Built from a line array rather than a triple-quoted literal so the trailing newline and the tab
# indentation are unambiguous. Every skip rule appears exactly once, and the "## capture_root()"
# line is not decorative: DesktopIdentityNonceIssuer.gd's own header genuinely contains the frozen
# preimage lines as doc comments, so a parser matching on "name(args)" anywhere would read them.

const PARSER_SAMPLE_LINES := [
	"## capture_root()",
	"@warning_ignore(\"unused_parameter\")",
	"func configure(root_store: Object) -> Dictionary:",
	"\treturn {}",
	"",
	"func _not_implemented(method: String) -> Dictionary:",
	"\treturn {}",
	"",
	"static func initialize(path: String = \"x\") -> Dictionary:",
	"\treturn {}",
	"",
	"class Inner:",
	"\tfunc helper(first: int) -> void:",
	"\t\tpass",
	"",
	"func verify_issued(receipt: Dictionary, expected_purpose: StringName) -> Dictionary:",
	"\treturn {}",
	"",
]

const PARSER_SAMPLE_SURFACE := "configure(root_store)\nverify_issued(receipt,expected_purpose)\n"

# ---- the exact four-flag CLI contract (plan line 851) ----

const SAMPLE_COMMIT := "0123456789abcdef0123456789abcdef01234567"
const COMMIT_FLAG := "--boundary-commit=0123456789abcdef0123456789abcdef01234567"
const FOCUSED_LOG := "res://evidence/phase_2r/logs/p2r16-identity-catalog-green.log"
const LOG_FLAG := "--focused-log=res://evidence/phase_2r/logs/p2r16-identity-catalog-green.log"
const OUTPUT := "res://evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json"
const OUTPUT_FLAG := "--output=res://evidence/phase_2r/contracts/desktop_identity_issuer_boundary.json"

# The seven named-commit source bindings of the v1 record, as field prefixes: each contributes
# <prefix>_path and <prefix>_sha256 members (plan line 851's exact member set).
const BOUND_SOURCE_FIELD_PREFIXES := [
	"issuer",
	"root_store",
	"day_advance_identity_port",
	"operation_journal",
	"data_catalog",
	"schedule_registry",
	"shop_registry",
]

const ARGUMENT_REJECTIONS := [
	{"name": "both modes", "args": [COMMIT_FLAG, LOG_FLAG, OUTPUT_FLAG, "--write", "--check"]},
	{"name": "neither mode", "args": [COMMIT_FLAG, LOG_FLAG, OUTPUT_FLAG]},
	{"name": "unknown flag", "args": [COMMIT_FLAG, LOG_FLAG, OUTPUT_FLAG, "--write", "--force"]},
	{"name": "missing boundary commit", "args": [LOG_FLAG, OUTPUT_FLAG, "--write"]},
	{"name": "missing focused log", "args": [COMMIT_FLAG, OUTPUT_FLAG, "--write"]},
	{"name": "missing output", "args": [COMMIT_FLAG, LOG_FLAG, "--write"]},
	{"name": "duplicate output", "args": [COMMIT_FLAG, LOG_FLAG, OUTPUT_FLAG, OUTPUT_FLAG, "--write"]},
]

# ---- the three frozen Shop records (plan lines 627-631, DECISION 4 / 9.16 / 11.7) ----
# Caps come straight from the frozen table's Cap column: "once per saved branch" for Lucky and
# Debug, "once per causal day; three per saved branch" for Supportz. A flat max int would drop the
# per-causal-day limit that Task 2's supportz_eligible() needs, which is why cap is structured.
# capability_ids uses the board vocabulary frozen at plan lines 946/1194; first_cell_safe is
# baseline and granted by no item, so Supportz -- a round-floor economy effect -- carries none.

const SHOP_ITEM_IDS := ["lucky_charm", "debug_key", "supportz"]

const SHOP_RECORDS := [
	{
		"item_id": "lucky_charm",
		"currency": "minesweeper_coin",
		"price": 1,
		"effect_ids": ["inventory:add:lucky_charm"],
		"capability_ids": ["first_cell_zero"],
		"cap": {"per_causal_day": null, "per_branch": 1},
	},
	{
		"item_id": "debug_key",
		"currency": "minesweeper_coin",
		"price": 3,
		"effect_ids": ["inventory:add:debug_key"],
		"capability_ids": ["forced_no_guess"],
		"cap": {"per_causal_day": null, "per_branch": 1},
	},
	{
		"item_id": "supportz",
		"currency": "money",
		"price": 45,
		"effect_ids": ["minesweeper:round_floor:-1"],
		"capability_ids": [],
		"cap": {"per_causal_day": 1, "per_branch": 3},
	},
]

const SHOP_MANIFEST_PATH := "res://data/manifests/minesweeper_shop.v1.json"
const SHOP_REGISTRY_VERSION := "minesweeper_shop_v1"


# ---- Step 1.1 skeleton probes (retained) ----

# The generator extends SceneTree and does its work in _init(), so it is probed with load_script
# and never instantiate() -- instantiating would construct a SceneTree and execute the tool. The
# preloaded const above is likewise only a Script resource; calling a static on it constructs
# nothing.
func test_boundary_tooling_skeletons_load() -> void:
	for label: String in SCRIPT_PATHS:
		var probe: Dictionary = DynamicScriptProbe.load_script(str(SCRIPT_PATHS[label]))
		assert_true(probe.get("ok", false),
			"%s must parse and load: %s" % [label, str(probe.get("message", ""))])


# DynamicScriptProbe resolves Script resources only, so JSON is proven with a strict parse instead.
func test_task_one_json_documents_strict_parse() -> void:
	for label: String in JSON_PATHS:
		var path: String = str(JSON_PATHS[label])
		assert_true(FileAccess.file_exists(path), "%s must exist at %s" % [label, path])
		if not FileAccess.file_exists(path):
			continue
		var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(path))
		assert_true(parsed.get("ok", false),
			"%s must strict-parse as an object: %s" % [label, str(parsed.get("message", ""))])


# ---- the frozen public surfaces ----

# CHARACTERIZATION, GREEN AT RED BY DESIGN (DECISION 11.5). This is the independent tripwire: it
# parses today's production sources with this file's own extractor and compares to the plan-851
# literals, so the three frozen signatures are guarded from now through GREEN. That timing is the
# whole point -- Step 1.3 rewrites all three files, filling bodies while the signatures must not
# move, and a tripwire that depended on the generator being implemented would be blind during
# exactly the step most likely to break it.
func test_current_sources_still_match_the_frozen_public_surfaces() -> void:
	for row: Dictionary in SURFACE_EXPECTATIONS:
		var path: String = str(row["path"])
		var expected_preimage: String = str(row["preimage"])
		var actual_preimage: String = _independent_public_surface(path)
		assert_eq(actual_preimage, expected_preimage,
			"%s public surface drifted from the frozen plan-851 preimage" % path)
		assert_eq(_sha256_of(actual_preimage), str(row["sha256"]),
			"%s public surface digest drifted" % path)


func test_generator_derives_each_frozen_public_surface() -> void:
	for row: Dictionary in SURFACE_EXPECTATIONS:
		var field: String = str(row["field"])
		var derived: Dictionary = GENERATOR.derive_public_surface(str(row["path"]))
		assert_true(derived.get("ok", false),
			"derive_public_surface must succeed for %s: %s" % [field, str(derived.get("code", &""))])
		var value: Dictionary = derived.get("value", {}) as Dictionary
		assert_eq(str(value.get("preimage", "")), str(row["preimage"]),
			"%s preimage must be derived from current source" % field)
		assert_eq(str(value.get("sha256", "")), str(row["sha256"]),
			"%s must be the lowercase SHA-256 of that preimage" % field)


# THE DECISION 8.2 TRAP, MADE ENFORCEABLE. Unused parameters on the three surface-hashed classes
# keep their exact frozen names and are silenced with @warning_ignore, never with the repo's usual
# leading underscore. A parser that helpfully stripped a leading underscore would produce the right
# answer for today's source and the wrong one after a genuine rename, so the two must not collapse.
func test_generator_parser_treats_an_underscored_parameter_as_a_different_surface() -> void:
	var frozen: Dictionary = GENERATOR.parse_public_surface("func configure(root_store: Object) -> Dictionary:\n")
	var renamed: Dictionary = GENERATOR.parse_public_surface("func configure(_root_store: Object) -> Dictionary:\n")
	assert_true(frozen.get("ok", false), "the frozen parameter name must parse")
	assert_true(renamed.get("ok", false), "the underscored parameter name must parse")
	var frozen_preimage: String = str((frozen.get("value", {}) as Dictionary).get("preimage", ""))
	var renamed_preimage: String = str((renamed.get("value", {}) as Dictionary).get("preimage", ""))
	assert_eq(frozen_preimage, "configure(root_store)\n",
		"parameter names are frozen strings and types are stripped")
	assert_ne(renamed_preimage, frozen_preimage,
		"configure(_root_store) must NOT reduce to configure(root_store)")


# The remaining parser rules of DECISION 11.3, each exercised exactly once by PARSER_SAMPLE_LINES:
# doc comments and annotations are skipped, underscore-prefixed methods are excluded, `static func`
# is not recognized so a static conversion breaks the hash loudly, inner-class methods are excluded
# by their indentation, and default values are stripped along with types.
func test_generator_parser_skips_comments_annotations_privates_statics_and_inner_classes() -> void:
	var sample: String = "\n".join(PackedStringArray(PARSER_SAMPLE_LINES))
	var parsed: Dictionary = GENERATOR.parse_public_surface(sample)
	assert_true(parsed.get("ok", false),
		"the sample must parse: %s" % str(parsed.get("code", &"")))
	assert_eq(str((parsed.get("value", {}) as Dictionary).get("preimage", "")), PARSER_SAMPLE_SURFACE,
		"only column-zero non-underscore plain func declarations enter the preimage")


# ---- the exact four-flag CLI contract ----

func test_parse_arguments_accepts_each_exclusive_mode() -> void:
	for mode: String in ["write", "check"]:
		var args: PackedStringArray = PackedStringArray([COMMIT_FLAG, LOG_FLAG, OUTPUT_FLAG, "--%s" % mode])
		var parsed: Dictionary = GENERATOR.parse_arguments(args)
		assert_true(parsed.get("ok", false),
			"--%s must be accepted: %s" % [mode, str(parsed.get("code", &""))])
		var value: Dictionary = parsed.get("value", {}) as Dictionary
		assert_eq(str(value.get("boundary_commit", "")), SAMPLE_COMMIT, "--boundary-commit value")
		assert_eq(str(value.get("focused_log", "")), FOCUSED_LOG, "--focused-log value")
		assert_eq(str(value.get("output", "")), OUTPUT, "--output value")
		assert_eq(str(value.get("mode", "")), mode, "the exclusive mode")


# Per DECISION 9.9 every rejection asserts ok == false AND code != not_implemented, so none of
# these can be satisfied by the skeleton envelope. No exact code literal is asserted: plan line 851
# freezes none for this tool, and DECISION 5 refuses to hardcode what the plan never froze.
func test_parse_arguments_rejects_every_malformed_invocation() -> void:
	for row: Dictionary in ARGUMENT_REJECTIONS:
		var name: String = str(row["name"])
		var args: PackedStringArray = PackedStringArray(row["args"] as Array)
		var parsed: Dictionary = GENERATOR.parse_arguments(args)
		assert_false(parsed.get("ok", true), "%s must be rejected" % name)
		assert_ne(parsed.get("code", &""), &"not_implemented",
			"%s must be rejected with a real code, not the skeleton envelope" % name)


# The record is necessarily absent at the preceding code commit and is added by the following
# evidence commit. Once present, every run validates its subject/ancestry, named-commit tree
# bytes, public surfaces, and focused-log bytes -- the permanent law. The temporary current-file
# comparison the DWM_REQUIRE_CURRENT_P2R16_BOUNDARY=1 environment value used to enable here was
# retired by dwm-p2r.34 (see the header note), so this validation no longer branches on anything.
func test_immutable_boundary_record_binds_the_named_commit_tree() -> void:
	if not FileAccess.file_exists(OUTPUT):
		pass_test("the immutable record is generated only after the named code commit exists")
		return
	var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(OUTPUT))
	assert_true(parsed.get("ok", false),
		"the immutable boundary record must strict-parse: %s" % str(parsed.get("message", "")))
	if not parsed.get("ok", false):
		return
	var validated: Dictionary = GENERATOR.validate_boundary_record(
		parsed.get("value", {}) as Dictionary
	)
	assert_true(validated.get("ok", false),
		"the immutable boundary must validate: %s %s" % [
			str(validated.get("code", &"")),
			str(validated.get("message", "")),
		])


# THE dwm-p2r.34 RETIREMENT PIN. Bound sources have lawfully evolved since the boundary sealed at
# 86b125484 (DesktopIdentityNonceIssuer.gd first at b9206a685, DataCatalog.gd at 69cf694e0), so
# the working tree genuinely diverges from the recorded v1 hashes -- exactly the state the retired
# current-byte mode rejected with boundary_current_source_hash_mismatch. This test proves the v1
# record remains valid historical evidence UNDER that real drift, so any reintroduction of a
# current-working-tree pin inside validate_boundary_record() turns it red. The premise assertion
# keeps it honest: were every bound source ever byte-identical to v1 again, the drift claim would
# be vacuous and this test says so loudly instead of passing silently.
func test_the_record_validates_while_bound_sources_drift_from_the_named_commit_tree() -> void:
	if not FileAccess.file_exists(OUTPUT):
		pass_test("the immutable record is generated only after the named code commit exists")
		return
	var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(OUTPUT))
	assert_true(parsed.get("ok", false),
		"the immutable boundary record must strict-parse: %s" % str(parsed.get("message", "")))
	if not parsed.get("ok", false):
		return
	var record: Dictionary = parsed.get("value", {}) as Dictionary
	var drifted: PackedStringArray = PackedStringArray()
	for prefix: String in BOUND_SOURCE_FIELD_PREFIXES:
		var path: String = str(record.get("%s_path" % prefix, ""))
		var recorded: String = str(record.get("%s_sha256" % prefix, ""))
		var current_path: String = "res://" + path
		assert_true(FileAccess.file_exists(current_path),
			"%s must exist in the working tree" % path)
		if not FileAccess.file_exists(current_path):
			continue
		if _sha256_of_bytes(FileAccess.get_file_as_bytes(current_path)) != recorded:
			drifted.append(path)
	assert_gt(drifted.size(), 0,
		"at least one bound source must have lawfully evolved past the sealed v1 bytes; " +
		"if none has, this retirement pin is vacuous and needs a new premise")
	var validated: Dictionary = GENERATOR.validate_boundary_record(record)
	assert_true(validated.get("ok", false),
		"the v1 record must remain valid historical evidence under working-tree drift: %s %s" % [
			str(validated.get("code", &"")),
			str(validated.get("message", "")),
		])


# ---- MinesweeperShopRegistry records and envelope (DECISION 11.7) ----

func test_shop_registry_initializes_and_validates() -> void:
	var initialized: Dictionary = SHOP_REGISTRY.initialize()
	assert_true(initialized.get("ok", false),
		"initialize() must load the v1 manifest: %s" % str(initialized.get("code", &"")))
	var validated: Dictionary = SHOP_REGISTRY.validate_all()
	assert_true(validated.get("ok", false),
		"validate_all() must accept the frozen manifest: %s" % str(validated.get("code", &"")))


func test_shop_registry_exposes_exactly_the_three_frozen_records() -> void:
	SHOP_REGISTRY.initialize()
	var ids: Array[String] = SHOP_REGISTRY.get_ids()
	assert_eq(ids.size(), 3, "exactly three Shop capability records")
	for item_id: String in SHOP_ITEM_IDS:
		assert_true(item_id in ids, "%s must be registered" % item_id)
	for expected: Dictionary in SHOP_RECORDS:
		var item_id: String = str(expected["item_id"])
		var fetched: Dictionary = SHOP_REGISTRY.get_record(item_id)
		assert_true(fetched.get("ok", false),
			"get_record(%s) must succeed: %s" % [item_id, str(fetched.get("code", &""))])
		var record: Dictionary = (fetched.get("value", {}) as Dictionary).get("record", {}) as Dictionary
		assert_eq(str(record.get("item_id", "")), item_id, "%s item_id" % item_id)
		assert_eq(str(record.get("currency", "")), str(expected["currency"]), "%s currency" % item_id)
		assert_eq(int(record.get("price", -1)), int(expected["price"]), "%s price" % item_id)
		assert_eq(record.get("effect_ids", []), expected["effect_ids"], "%s effect_ids" % item_id)
		assert_eq(record.get("capability_ids", []), expected["capability_ids"],
			"%s capability_ids" % item_id)
		assert_true(record.has("cap"), "%s must carry a structured cap" % item_id)
		var cap: Dictionary = record.get("cap", {}) as Dictionary
		var expected_cap: Dictionary = expected["cap"] as Dictionary
		assert_true(cap.has("per_causal_day"), "%s cap must carry per_causal_day" % item_id)
		assert_true(cap.has("per_branch"), "%s cap must carry per_branch" % item_id)
		assert_eq(cap.get("per_causal_day"), expected_cap.get("per_causal_day"),
			"%s cap.per_causal_day" % item_id)
		assert_eq(cap.get("per_branch"), expected_cap.get("per_branch"), "%s cap.per_branch" % item_id)


# The skeleton manifest ships registry_version as the INTEGER 1, while plan line 991 freezes the
# STRING "minesweeper_shop_v1" -- unlike ScheduleActionRegistry, whose registry_version is an
# integer. Without this assertion nothing would force Step 1.3 to correct it (DECISION 11 C5).
func test_shop_manifest_envelope_names_the_frozen_registry_version() -> void:
	var parsed: Dictionary = StrictJson.parse_object(FileAccess.get_file_as_string(SHOP_MANIFEST_PATH))
	assert_true(parsed.get("ok", false), "the Shop manifest must strict-parse")
	var manifest: Dictionary = parsed.get("value", {}) as Dictionary
	assert_eq(manifest.get("schema_version"), 1, "schema_version is exactly 1")
	assert_eq(str(manifest.get("registry_version", "")), SHOP_REGISTRY_VERSION,
		"registry_version is the frozen string, not an integer")
	var records: Array = manifest.get("records", []) as Array
	assert_eq(records.size(), 3, "the manifest carries exactly the three frozen records")


# ---- helpers ----

# This file's OWN extractor, implementing the DECISION 11.3 rules independently of the generator.
# Double-entry on a frozen formula, the same choice DECISION 9.12 made for the plan-535 preimages.
func _independent_public_surface(source_path: String) -> String:
	var text: String = FileAccess.get_file_as_string(source_path)
	var preimage: String = ""
	for raw_line: String in text.split("\n"):
		if not raw_line.begins_with("func "):
			continue
		var signature: String = raw_line.substr(5)
		var open_at: int = signature.find("(")
		var close_at: int = signature.rfind(")")
		if open_at < 0 or close_at < open_at:
			continue
		var method_name: String = signature.substr(0, open_at).strip_edges()
		if method_name.begins_with("_"):
			continue
		var parameter_names: PackedStringArray = PackedStringArray()
		var parameter_text: String = signature.substr(open_at + 1, close_at - open_at - 1)
		for parameter: String in parameter_text.split(",", false):
			var trimmed: String = parameter.strip_edges()
			if trimmed.is_empty():
				continue
			var cut: int = trimmed.length()
			var colon_at: int = trimmed.find(":")
			if colon_at >= 0:
				cut = colon_at
			var equals_at: int = trimmed.find("=")
			if equals_at >= 0 and equals_at < cut:
				cut = equals_at
			parameter_names.append(trimmed.substr(0, cut).strip_edges())
		preimage += "%s(%s)\n" % [method_name, ",".join(parameter_names)]
	return preimage


func _sha256_of(text: String) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _sha256_of_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
