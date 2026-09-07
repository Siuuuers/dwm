extends "res://addons/gut/test.gd"
## Registered line identity on ProfileManager (Seven-Day Flow Plan 01 Task 6, dwm-oyo.2).
##
## WHAT THIS SUITE BINDS. DEVIATION-11 Ruling A gives the visited-line identity law a CONFIGURED
## SEAM on autoload/ProfileManager.gd. configure_line_registry(registry) takes the PARSED ids
## document explicitly, derives a membership index from its reply_lines block once, and makes
## mark_line_visited strict only while a registry is configured. Unconfigured it admits
## everything, which is _guard's own shape one call level below in the same file, and which is
## what keeps the five legacy line literals green - tests/integration/test_profile_reset_consumers
## .gd:81 among them, inside a frozen baseline this task may not move.
##
## WHY THE REGISTRY IS INJECTED AND NEVER READ FROM DISK. A predicate that loads its own registry
## cannot be driven by a fixture without writing a mutated manifest, so its law survives mutation.
## That is the defect dwm-oyo.2.1 records against DialogicEntryManifest._is_retired_label and the
## reason campaign site C40 survives. Taking the document explicitly is the idiom
## validate_ids_document already has, and this seam copies it rather than inventing a second one.
## Ruling A's sibling seam does NOT close C40: different file, different injection style, different
## block of the same registry, no shared call path.
##
## ACCESS IDIOM. Every production call goes through Object.call(&"name", ...) on a Script value
## loaded by tests/support/DynamicScriptProbe.gd. A statically resolved call to a method the
## production source does not declare yet is a PARSE error, which reports as a load failure and
## proves nothing, whereas the dynamic form lets this suite compile and report RED as an ordinary
## named assertion. _guard() refuses to reach any dynamic call until the seam is declared.
##
## TWO DERIVATIONS, NEVER ONE. Every law is proven against a literal fixture registry, and
## test_the_shipped_ids_document_configures_the_seam_with_its_eighteen_reply_lines additionally
## drives the real data/manifests/dialogic_ids.json through the same entry point, so a fixture
## that has drifted from the shipped document shape cannot vouch for itself.
##
## THREE THINGS ARE KNOWINGLY UNCOVERED, declared here rather than discovered during the campaign.
##
## (1) and (2) test_is_line_visited_stays_a_permissive_read_under_a_configured_registry and
## test_reset_visited_history_needs_no_registry_and_clears_a_planted_legacy_id pin NEGATIVE space,
## namely that neither surface is gated. The gating line does not exist, so no mutation can
## invert the law either one NAMES. Both will nonetheless appear as killers in a campaign report,
## because their SETUP exercises the shipped seam - measured, not assumed: campaign pass 1
## recorded both as killers at sites P01, P14 and P20.
##
## (3) configure_line_registry's unfingerprintable_line_registry branch, which fires when
## CanonicalJsonWriter refuses to emit the derived index. Over a {String: bool} index the writer
## has exactly one remaining failure mode, the lone-surrogate refusal at
## CanonicalJsonWriter.gd:69-71, and NO GDScript fixture can reach it: String.chr(0xD800) does
## not produce a lone surrogate, the engine substitutes U+FFFD at construction and logs
## "Unpaired surrogate (d800)". Measured, not assumed - the withdrawn fixture assertion read
## [65533] expected to equal [55296]. The branch keeps a code of its OWN rather than reusing
## invalid_line_registry, so the sibling-code trap is closed by identity even though no test
## drives it. This is how tests/unit/test_dialogic_ids_manifest.gd records the four
## IDS_MANIFEST_ codes that need a file to be absent or corrupt on disk.
##
## All three are recorded the way Task 5 recorded observer.evidence.commit.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const MANAGER_PATH := "res://autoload/ProfileManager.gd"
const MANIFEST_PATH := "res://scripts/narrative/DialogicEntryManifest.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const FAKE_OPS_PATH := "res://tests/support/FakeFileOps.gd"
const ROOT := "identity-registry-tests/root"

## One real record, quoted from the reply_lines block of data/manifests/dialogic_ids.json.
const REGISTERED_LINE := "line.contact.ordinary.lavinia.day1.reply.a"
const REGISTERED_OWNER := "contact.ordinary.lavinia.day1"
const SECOND_REGISTERED_LINE := "line.contact.ordinary.lavinia.day1.reply.b"

## A legacy literal that no registry registers. tests/unit/test_profile_manager.gd:219 marks it on
## the real manager today, which is exactly why the unconfigured seam must stay permissive.
const LEGACY_LINE := "legacy.unregistered.line.1"

## The shipped reply_lines block holds exactly this many records.
const SHIPPED_REPLY_LINE_COUNT := 18

var _manager_script: Script
var _storage_script: Script
var _fake_ops_script: Script
var _manifest_script: Script

func before_all() -> void:
	_manager_script = _load(MANAGER_PATH)
	_storage_script = _load(STORAGE_PATH)
	_fake_ops_script = _load(FAKE_OPS_PATH)
	_manifest_script = _load(MANIFEST_PATH)

# --------------------------------------------------------------------------------------------
# Loading helpers. Everything fails soft so RED is an assertion, never a script error.
# --------------------------------------------------------------------------------------------

func _load(path: String) -> Script:
	var result: Dictionary = PROBE.load_script(path)
	if not result.get("ok", false):
		return null
	return result.get("value") as Script

## Refuses to reach a dynamic call until the seam exists, so a missing method reports as a named
## RED assertion instead of an engine error.
func _guard() -> bool:
	if _manager_script == null:
		assert_true(false, "expected RED: missing " + MANAGER_PATH)
		return false
	if not _declares("configure_line_registry"):
		assert_true(false, "expected RED: " + MANAGER_PATH + " declares no configure_line_registry")
		return false
	return true

func _declares(method_name: String) -> bool:
	for method: Dictionary in _manager_script.get_script_method_list():
		if str(method.get("name", "")) == method_name:
			return true
	return false

## The tests/unit/test_profile_manager.gd factory restated: the real JsonFileStorage adapter over
## the in-memory FakeFileOps, an initialized manager, never added to the scene tree.
func _new_manager() -> Node:
	var ops: RefCounted = _fake_ops_script.new()
	var storage: RefCounted = _storage_script.new(ROOT, ops)
	var manager: Node = autofree(_manager_script.new())
	var initialized: Dictionary = manager.call(&"initialize", storage)
	assert_true(initialized.get("ok", false), str(initialized))
	return manager

## An uninitialized manager, for the laws that never touch a profile document.
func _bare_manager() -> Node:
	return autofree(_manager_script.new())

## A well-formed registry document carrying exactly the named line ids.
func _registry(line_ids: Array) -> Dictionary:
	var records: Array = []
	for line_id: Variant in line_ids:
		records.append({"line_id": line_id, "owning_entry_id": REGISTERED_OWNER})
	return {"reply_lines": records}

func _fingerprint(result: Dictionary) -> String:
	return str((result.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

## Configures a fresh bare manager, so a refusal test never inherits another test's state.
func _configure_fresh(registry: Dictionary) -> Dictionary:
	return _bare_manager().call(&"configure_line_registry", registry)

func _visited(manager: Node) -> Array:
	return (manager.call(&"get_profile_snapshot") as Dictionary)["visited_line_ids"]

# --------------------------------------------------------------------------------------------
# The unconfigured half of Ruling A.
# --------------------------------------------------------------------------------------------

func test_mark_line_visited_stays_permissive_until_a_registry_is_configured() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	var marked: Dictionary = manager.call(&"mark_line_visited", LEGACY_LINE)
	assert_true(marked.get("ok", false),
		"an unconfigured seam admits every id: " + str(marked))
	assert_true(manager.call(&"is_line_visited", LEGACY_LINE),
		"and the legacy id really lands in visited history")

# --------------------------------------------------------------------------------------------
# configure_line_registry: the command envelope and the closure of the block it reads.
# --------------------------------------------------------------------------------------------

func test_configure_line_registry_binds_a_reply_lines_block() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	var result: Dictionary = manager.call(&"configure_line_registry", _registry([REGISTERED_LINE]))
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("code"), &"ok", "the command success code")
	var value: Dictionary = result.get("value", {})
	assert_eq(value.get("line_count"), 1, "one record indexes one line")
	assert_false(value.get("already_configured", true),
		"a first configure is not a re-configure")
	assert_eq(str(value.get("registry_fingerprint", "")).length(), 64,
		"the reported identity is a sha256 digest, not the serialized index itself: that is what "
		+ "every other fingerprint site in this repository emits, and it keeps the command "
		+ "receipt constant-sized as the registry grows")

func test_configure_line_registry_returns_the_command_failure_shape() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	var result: Dictionary = manager.call(&"configure_line_registry", {})
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.size(), 4, "a command failure carries exactly ok, code, details, receipt")
	assert_eq(result.get("details"), {}, "details is the empty command detail object")
	assert_eq(result.get("receipt"), {}, "receipt is the empty command receipt")
	assert_false(result.has("message"),
		"a command failure is not the message-carrying _failure shape")

func test_configure_line_registry_refuses_a_missing_reply_lines_block() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	var result: Dictionary = manager.call(&"configure_line_registry", {"atoms": []})
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"invalid_line_registry",
		"a document declaring no reply_lines would silently index nothing")

func test_configure_line_registry_refuses_a_reply_lines_block_that_is_not_an_array() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	var result: Dictionary = manager.call(&"configure_line_registry",
		{"reply_lines": REGISTERED_LINE})
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"invalid_line_registry",
		"a registry block is an array of records or it is not a registry block")

func test_configure_line_registry_refuses_a_record_that_is_not_an_object() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	var result: Dictionary = manager.call(&"configure_line_registry",
		{"reply_lines": [REGISTERED_LINE]})
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"invalid_line_record",
		"a bare string is not a reply-line record")

func test_configure_line_registry_refuses_a_record_whose_line_id_is_absent_or_not_a_string() -> void:
	if not _guard():
		return
	var absent: Dictionary = _configure_fresh({"reply_lines": [{"owning_entry_id": REGISTERED_OWNER}]})
	assert_false(absent.get("ok", true), str(absent))
	assert_eq(absent.get("code"), &"invalid_line_record_id",
		"a record without a line_id would silently drop one real line")
	var mistyped: Dictionary = _configure_fresh(
		{"reply_lines": [{"line_id": 7, "owning_entry_id": REGISTERED_OWNER}]})
	assert_false(mistyped.get("ok", true), str(mistyped))
	assert_eq(mistyped.get("code"), &"invalid_line_record_id",
		"and a line_id that is not a string is the same defect")

func test_configure_line_registry_refuses_a_record_whose_line_id_is_empty() -> void:
	if not _guard():
		return
	var result: Dictionary = _configure_fresh(
		{"reply_lines": [{"line_id": "", "owning_entry_id": REGISTERED_OWNER}]})
	assert_false(result.get("ok", true), str(result))
	assert_eq(result.get("code"), &"invalid_line_record_id",
		"the empty string is not an identity")

# --------------------------------------------------------------------------------------------
# One-shot identity, measured on the DERIVED INDEX rather than on the document.
# --------------------------------------------------------------------------------------------

func test_the_same_registry_configures_twice_and_reports_already_configured() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	var first: Dictionary = manager.call(&"configure_line_registry", _registry([REGISTERED_LINE]))
	assert_true(first.get("ok", false), str(first))
	var second: Dictionary = manager.call(&"configure_line_registry", _registry([REGISTERED_LINE]))
	assert_true(second.get("ok", false),
		"re-configuring with the same registry is idempotent: " + str(second))
	assert_true((second.get("value", {}) as Dictionary).get("already_configured", false),
		"and it says so rather than pretending to be the first")
	assert_eq(_fingerprint(second), _fingerprint(first),
		"the reported fingerprint is the value identity is actually measured against")

func test_a_different_registry_is_refused_as_already_configured() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the first registry binds")
	var second: Dictionary = manager.call(&"configure_line_registry",
		_registry([SECOND_REGISTERED_LINE]))
	assert_false(second.get("ok", true), str(second))
	assert_eq(second.get("code"), &"line_registry_already_configured",
		"a second, different registry may not silently replace the first")
	assert_true((manager.call(&"mark_line_visited", REGISTERED_LINE) as Dictionary).get("ok", false),
		"and the refusal clobbered nothing: the FIRST registry is still the bound one")
	assert_false((manager.call(&"mark_line_visited", SECOND_REGISTERED_LINE) as Dictionary)
		.get("ok", true), "the refused registry never partially bound")

func test_a_registry_differing_only_outside_reply_lines_is_the_same_registry() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	var first: Dictionary = manager.call(&"configure_line_registry", _registry([REGISTERED_LINE]))
	assert_true(first.get("ok", false), "the first registry binds")
	var widened: Dictionary = _registry([REGISTERED_LINE])
	widened["atoms"] = [{"atom_id": "atom.example", "owning_entry_id": REGISTERED_OWNER}]
	widened["retired_ids"] = []
	var second: Dictionary = manager.call(&"configure_line_registry", widened)
	assert_true(second.get("ok", false),
		"identity is the derived index, so a block this seam never reads is not a conflict: "
		+ str(second))
	assert_true((second.get("value", {}) as Dictionary).get("already_configured", false),
		"and the second call is recognised as the same registry")
	assert_eq(_fingerprint(second), _fingerprint(first),
		"the widened document reports the identical fingerprint, not merely an accepted one")

func test_a_registry_whose_records_are_reordered_is_the_same_registry() -> void:
	if not _guard():
		return
	var manager := _bare_manager()
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE, SECOND_REGISTERED_LINE])) as Dictionary).get("ok", false),
		"the first registry binds")
	var second: Dictionary = manager.call(&"configure_line_registry",
		_registry([SECOND_REGISTERED_LINE, REGISTERED_LINE]))
	assert_true(second.get("ok", false),
		"record order is not identity: " + str(second))
	assert_true((second.get("value", {}) as Dictionary).get("already_configured", false),
		"the reordered document is recognised as the same registry")

# --------------------------------------------------------------------------------------------
# The strict half of Ruling A, and the ORDER of the two boundaries around it.
# --------------------------------------------------------------------------------------------

func test_mark_line_visited_refuses_an_unregistered_line_once_a_registry_is_configured() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the registry binds")
	var marked: Dictionary = manager.call(&"mark_line_visited", LEGACY_LINE)
	assert_false(marked.get("ok", true), str(marked))
	assert_eq(marked.get("code"), &"unregistered_line_id",
		"saved wording may not become an identity")

func test_mark_line_visited_accepts_a_registered_line_once_a_registry_is_configured() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the registry binds")
	var marked: Dictionary = manager.call(&"mark_line_visited", REGISTERED_LINE)
	assert_true(marked.get("ok", false), "strictness admits a registered id: " + str(marked))
	assert_eq(_visited(manager), [REGISTERED_LINE],
		"and the id really lands in the committed profile")

func test_a_refused_line_mutates_nothing_and_emits_no_write_failure() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the registry binds")
	watch_signals(manager)
	var refused: Dictionary = manager.call(&"mark_line_visited", LEGACY_LINE)
	assert_false(refused.get("ok", true), str(refused))
	assert_false(refused.get("fatal", true),
		"an identity refusal attempted no write, so nothing is indeterminate")
	assert_eq(_visited(manager), [], "the refusal mutated no profile state")
	assert_false(manager.call(&"is_line_visited", LEGACY_LINE), "and marked nothing visited")
	assert_signal_emit_count(manager, "profile_write_failed", 0,
		"no write was attempted, so no restore participant is told one failed")
	var later: Dictionary = manager.call(&"mark_line_visited", REGISTERED_LINE)
	assert_true(later.get("ok", false),
		"and a later legitimate commit still succeeds, so no fatal latch was set: " + str(later))

func test_the_registry_check_precedes_the_already_visited_short_circuit() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"mark_line_visited", LEGACY_LINE) as Dictionary).get("ok", false),
		"the legacy id is planted while the seam is still permissive")
	assert_true(manager.call(&"is_line_visited", LEGACY_LINE), "it is genuinely in the profile")
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the registry binds")
	var again: Dictionary = manager.call(&"mark_line_visited", LEGACY_LINE)
	assert_false(again.get("ok", true),
		"a planted legacy id may not bypass the law by answering yes, you have seen this: "
		+ str(again))
	assert_eq(again.get("code"), &"unregistered_line_id",
		"the registry check runs before the already-visited short circuit")

func test_an_empty_line_id_keeps_its_own_code_under_a_configured_registry() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the registry binds")
	var marked: Dictionary = manager.call(&"mark_line_visited", "")
	assert_false(marked.get("ok", true), str(marked))
	assert_eq(marked.get("code"), &"invalid_line_id",
		"emptiness keeps its own identity; the registry check runs after it")

func test_an_empty_configured_registry_refuses_every_line() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	var configured: Dictionary = manager.call(&"configure_line_registry", {"reply_lines": []})
	assert_true(configured.get("ok", false),
		"an empty registry is a legitimate registry: " + str(configured))
	assert_eq((configured.get("value", {}) as Dictionary).get("line_count"), 0, "it indexes nothing")
	var marked: Dictionary = manager.call(&"mark_line_visited", REGISTERED_LINE)
	assert_false(marked.get("ok", true),
		"configured-and-empty is strict, not unconfigured: " + str(marked))
	assert_eq(marked.get("code"), &"unregistered_line_id",
		"which is why the sentinel is the fingerprint and not the index emptiness")

# --------------------------------------------------------------------------------------------
# KNOWINGLY UNCOVERED. Both pin negative space: no shipped line gates these surfaces, so no
# mutation can kill either assertion. Declared here, and in the campaign, before the run.
# --------------------------------------------------------------------------------------------

func test_is_line_visited_stays_a_permissive_read_under_a_configured_registry() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"mark_line_visited", LEGACY_LINE) as Dictionary).get("ok", false),
		"the legacy id is planted while the seam is still permissive")
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the registry binds")
	assert_true(manager.call(&"is_line_visited", LEGACY_LINE),
		"the read is ungated: the skip route pre-reads before marking, and gating the read would "
		+ "silently reclassify every already-seen legacy line as unseen")

func test_reset_visited_history_needs_no_registry_and_clears_a_planted_legacy_id() -> void:
	if not _guard():
		return
	var manager := _new_manager()
	assert_true((manager.call(&"mark_line_visited", LEGACY_LINE) as Dictionary).get("ok", false),
		"the legacy id is planted while the seam is still permissive")
	assert_true((manager.call(&"configure_line_registry",
		_registry([REGISTERED_LINE])) as Dictionary).get("ok", false), "the registry binds")
	var reset: Dictionary = manager.call(&"reset_visited_history")
	assert_true(reset.get("ok", false),
		"the reset path names no identity, so it is ungated: " + str(reset))
	assert_eq(_visited(manager), [], "and it clears the planted legacy id")

# --------------------------------------------------------------------------------------------
# The second derivation: the shipped document, through the same entry point.
# --------------------------------------------------------------------------------------------

func test_the_shipped_ids_document_configures_the_seam_with_its_eighteen_reply_lines() -> void:
	if not _guard():
		return
	if _manifest_script == null:
		assert_true(false, "expected RED: missing " + MANIFEST_PATH)
		return
	var loaded: Dictionary = _manifest_script.call(&"load_ids_default")
	assert_true(loaded.get("ok", false), "the shipped registry loads: " + str(loaded))
	if not loaded.get("ok", false):
		return
	var manager := _new_manager()
	var configured: Dictionary = manager.call(&"configure_line_registry", loaded["value"])
	assert_true(configured.get("ok", false),
		"the seam accepts the real document, not only fixtures: " + str(configured))
	assert_eq((configured.get("value", {}) as Dictionary).get("line_count"),
		SHIPPED_REPLY_LINE_COUNT, "and indexes every shipped reply line")
	assert_true((manager.call(&"mark_line_visited", REGISTERED_LINE) as Dictionary).get("ok", false),
		"a genuinely registered id is admitted under the shipped registry")
	assert_false((manager.call(&"mark_line_visited", LEGACY_LINE) as Dictionary).get("ok", true),
		"and a legacy literal is refused under it")
