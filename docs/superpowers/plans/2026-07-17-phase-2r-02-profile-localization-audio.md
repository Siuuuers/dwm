# Phase 2R Profile, Localization, and Audio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish one global profile owner, a strict extensible custom-JSON localization pipeline, atomic locale presentation, and one live semantic audio owner without TranslationServer or profile state inside run saves.

**Architecture:** `ProfileManager` persists schema-validated global data through an injected root-relative `StorageAdapter`; `JsonFileStorage` uses strict duplicate-rejecting JSON, one canonical writer, and operation-tagged write/delete transactions that reconcile every failpoint to a proven winner. `LocalizationManager` queues presentation roots until its validated bundle is ready, then applies presentation, commits the language preference with deferred profile signals, swaps the bundle, and publishes exactly once. `AudioManager`, InputManager, AccessibilityManager, and DialogicBridge apply committed profile values but never become alternate owners; AudioManager alone owns semantic cue playback, fades, crossfades, players, and tweens.

**Tech Stack:** Godot 4.6.3 stable Mono (GDScript only), GUT 9.6.1, strict JSON plus a checked-in JSON-Schema subset, custom locale JSON, Godot audio buses/players, Beads 1.1.0, PowerShell, and the checked-in isolated-Godot command wrapper.

## Global Constraints

- This plan owns Beads issue `dwm-p2r.3` and starts only after `dwm-p2r.1` closes.
- `implementation_authorized` remains `false`; this document is an execution plan, not authority to edit runtime files, stage paths, or commit.
- Use the signatures and result unions frozen in `2026-07-17-phase-2r-foundation-repair.md` exactly; a signature change requires a cross-plan edit and renewed approval.
- Every Godot invocation MUST use `tools/testing/Invoke-IsolatedGodot.ps1`; direct engine invocations and hand-set `DWM_TEST_ROOT` values are forbidden.
- Canonical profile and localization files are strict primitive-only JSON; `store_var`, `get_var`, object loading, and `TranslationServer` are forbidden.
- Every persisted profile, transaction marker, localization catalog, and generated JSON evidence document uses `StrictJson` for reads and `CanonicalJsonWriter` for deterministic writes; `JSON.parse*` and ad-hoc `JSON.stringify` are forbidden in those owners.
- Every Dictionary/Array crossing a manager, storage, signal, prepared-plan, snapshot, or test-double boundary is recursively duplicated on ingress and egress. Mutating an input, return value, or captured emitted payload MUST NOT mutate manager/test-double internal state. Godot delivers one signal argument instance synchronously to all listeners, so listeners MUST treat collection payloads as read-only; this plan does not claim impossible listener-to-listener isolation.
- Preserve an immutable exact fingerprint of the existing `50 en / 25 zh_CN / 25 zh_HK` legacy subset before adding any UI key; later full-catalog hashes are separate evidence and MUST NOT replace that subset fingerprint.
- Only English narrative timelines physically exist; do not create or claim Chinese narrative files.
- `GameState.reset_game()` and slot restore MUST NOT reset or replace profile data.
- Every project-manager `_ready()` is side-effect-free. `ApplicationBootstrap._ready()` may only defer the staged bootstrap until all autoload ready callbacks finish; disk access, signal wiring, player creation, and live preference application occur in named stages.
- Tests use injected storage below the wrapper-proven test root. No test may construct or open production `user://profile.json`, `user://input_bindings.json`, or a production saves path.
- Every Plan-02-owned guarded manager implements `configure_mutation_gate(gate: Object) -> Dictionary` with one identical contract: reject null, a gate missing `capability_changed` or any of `acquire/release/guard_external/is_active/get_active_owner/is_internal_owner_active/latch_fatal/is_fatal_latched`, and replacement by another instance; accept the first compatible gate or the same instance idempotently; perform no I/O, initialization, signal emission, or domain mutation. Success is exactly `{"ok":true,"code":&"ok","value":{"gate_instance_id":int,"already_configured":bool},"receipt":{}}`; failures use the frozen CommandResult with `code=&"invalid_mutation_gate"` or `&"mutation_gate_already_configured"`. The retained instance is private; the returned instance ID is the bootstrap's identity proof.
- Preserve the user-owned dirty files listed in the master plan. In particular, do not edit `scripts/ui/ShopApp.gd`; its scene may receive declarative child nodes only after its existing diff is rechecked.
- Plan 01 owns and commits `tools/git/Invoke-ExactPathCommit.ps1` plus its behavior fixtures before this plan starts. All six boundaries below invoke that exact helper with literal `A|M|D` maps, present-only optional UID additions, and an `ExpectedHead` captured immediately before mutation. The helper itself enforces `DWM_COMMIT_AUTHORIZED=1`, Git quiet `0|1|error` handling, regular-blob modes, no partial/rename/copy/type/unmerged state, commit exit, sole-child ancestry, and postcommit revalidation.
- Commit blocks are proposed path-specific boundaries only. Do not stage or commit unless the user separately authorizes that exact boundary; never use `git add .`.

---

## Task 1: Add crash-recoverable storage, the exact profile model, and staged bootstrap

**Files:**

- Create: `scripts/infrastructure/storage/StorageAdapter.gd`
- Create: `scripts/infrastructure/storage/FileOps.gd`
- Create: `scripts/infrastructure/storage/JsonFileStorage.gd`
- Create: `scripts/validation/StrictJson.gd`
- Create: `scripts/validation/CanonicalJsonWriter.gd`
- Create: `scripts/profile/ProfileSchema.gd`
- Create: `scripts/profile/ProfileMigration.gd`
- Create: `autoload/ProfileManager.gd`
- Create: `autoload/ApplicationBootstrap.gd`
- Create: `schemas/profile.schema.json`
- Create: `tests/support/DynamicScriptProbe.gd`
- Create: `tests/support/FakeFileOps.gd`
- Create: `tests/support/FakeApplicationMutationGate.gd`
- Create: `tests/support/TemporaryStorage.gd`
- Create: `tests/unit/test_json_file_storage.gd`
- Create: `tests/unit/test_strict_json.gd`
- Create: `tests/unit/test_profile_manager.gd`
- Create: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Modify: `project.godot`

**Interfaces:**

- Consumes: `Invoke-IsolatedGodot.ps1` from `dwm-p2r.1`; the master `CommandResult`, `StorageAdapter`, `JsonFileStorage`, and ProfileManager contracts; the existing `GameState.reset_game()` compatibility seam.
- Produces: `StrictJson.parse_object()` and `CanonicalJsonWriter.stringify()`; validator-backed crash-recoverable write/delete storage; `ProfileSchema` and `ProfileMigration`; all frozen ProfileManager methods/signals; a final fail-closed bootstrap plus an explicit non-shipping development subset.

- [ ] **Step 1.1: Claim the issue and add parse-safe dynamic-load RED tests**

- [ ] Run the bookkeeping checks without changing runtime files:

```powershell
bd show dwm-p2r.3 --json
bd update dwm-p2r.3 --claim
git status --short
git diff -- Prompt.md prompt_docs/CONTRACTS.md prompt_docs/DIALOGIC.md prompt_docs/PHASES.md prompt_docs/TESTING.md scripts/data/ArtManifest.gd scripts/ui/ShopApp.gd
```

- [ ] Implement `DynamicScriptProbe` so a RED test never names a not-yet-registered global class at parse time:

```gdscript
class_name DynamicScriptProbe
extends RefCounted

static func load_script(path: String) -> Dictionary:
	if not ResourceLoader.exists(path, "Script"):
		return {"ok": false, "code": &"missing_script", "message": path}
	var script: Script = load(path)
	if script == null or not script.can_instantiate():
		return {"ok": false, "code": &"invalid_script", "message": path}
	return {"ok": true, "code": &"ok", "value": script}

static func instantiate(path: String) -> Dictionary:
	var loaded := load_script(path)
	if not loaded.get("ok", false):
		return loaded
	return {"ok": true, "code": &"ok", "value": loaded["value"].new()}
```

- [ ] Start `test_profile_manager.gd` without `preload`, `class_name` references, or a `ProfileManager` global reference:

```gdscript
extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PROFILE_SCHEMA_PATH := "res://scripts/profile/ProfileSchema.gd"

func test_defaults_are_schema_valid_and_skip_is_read_only() -> void:
	var loaded := PROBE.load_script(PROFILE_SCHEMA_PATH)
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false):
		return
	var schema: Script = loaded["value"]
	var profile: Dictionary = schema.call(&"make_defaults")
	var result: Dictionary = schema.call(&"validate", profile)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(profile["preferences"]["dialogue"]["skip_mode"], "read_only")
	assert_eq(profile["gallery_transaction_receipts"], {})
```

- [ ] Add these named, runnable dynamic-load RED fixtures. Keep the production class names out of annotations, `preload`, and executable expressions until each probe succeeds:

```gdscript
# tests/unit/test_strict_json.gd
extends "res://addons/gut/test.gd"
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

func _assert_script_contract_missing(path: String) -> void:
	var result: Dictionary = PROBE.load_script(path)
	assert_true(result.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(result))
	if not result.get("ok", false):
		assert_eq(result.get("code"), &"missing_script")

func test_strict_json_contract_exists() -> void:
	_assert_script_contract_missing("res://scripts/validation/StrictJson.gd")

func test_canonical_writer_contract_exists() -> void:
	_assert_script_contract_missing("res://scripts/validation/CanonicalJsonWriter.gd")
```

```gdscript
# tests/unit/test_json_file_storage.gd
extends "res://addons/gut/test.gd"
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")

func test_json_file_storage_contract_exists() -> void:
	var result: Dictionary = PROBE.load_script("res://scripts/infrastructure/storage/JsonFileStorage.gd")
	assert_true(result.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(result))
	if not result.get("ok", false):
		assert_eq(result.get("code"), &"missing_script")
```

```gdscript
# tests/unit/test_application_bootstrap_profile_stage.gd
extends "res://addons/gut/test.gd"
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const EXPECTED_STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
	&"initialize_profile",
	&"initialize_saves",
	&"initialize_localization",
	&"initialize_input",
	&"initialize_accessibility",
	&"initialize_audio",
	&"initialize_dialogic_bridge",
	&"configure_restore_participants",
	&"configure_day_resolution",
	&"configure_minesweeper_rounds",
	&"publish_application_ready",
]

func test_application_bootstrap_contract_exists() -> void:
	var result: Dictionary = PROBE.load_script("res://autoload/ApplicationBootstrap.gd")
	assert_true(result.get("ok", false), "expected implementation; RED=%s" % JSON.stringify(result))
	if not result.get("ok", false):
		assert_eq(result.get("code"), &"missing_script")
```

Each fixture's first run must reach its `assert_true` failure with the captured `code=&"missing_script"`; a parse error, autoload error, crash, production path access, or unrelated failure is not acceptable RED. After each script exists, retain the fixture and replace the existence-only assertion path with the contract cases specified below; never delete the test to obtain GREEN.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'profile_storage_red' -LogName 'phase2r-profile-storage-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_strict_json.gd,res://tests/unit/test_json_file_storage.gd,res://tests/unit/test_profile_manager.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd','-gexit')
```

Expected RED: each file reaches its first intended `missing_script` assertion, and the wrapper reports no production-path access.

- [ ] **Step 1.2: Implement strict/canonical JSON and the exact write/delete transaction**

- [ ] Implement the JSON boundary before either profile or marker persistence:

```gdscript
# scripts/validation/StrictJson.gd
class_name StrictJson
extends RefCounted
static func parse_object(text: String) -> Dictionary

# scripts/validation/CanonicalJsonWriter.gd
class_name CanonicalJsonWriter
extends RefCounted
static func stringify(value: Variant) -> Dictionary
```

`StrictJson.parse_object()` returns `{ok:true, value:Dictionary}` or `{ok:false, code:StringName, message:String, line:int, column:int}` and rejects duplicate object members before materialization, non-object roots, trailing tokens, invalid escapes, lone surrogate halves, NaN, and infinity. `CanonicalJsonWriter.stringify()` accepts only null/bool/int/finite-float/String/Array/Dictionary with String or StringName keys; recursively sorts object keys by UTF-8 bytes, preserves array order, uses JSON escapes and locale-independent numbers, emits no insignificant whitespace, then strict-parses its own bytes before returning `{ok:true, value:String}`. Unsupported types, colliding `String`/`StringName` keys after normalization, or non-finite values fail without bytes. Profile documents, transaction markers, tombstones, locale files, and evidence generators call these two classes directly.

- [ ] Implement this closed recursive-descent algorithm; do not delegate parsing to Godot `JSON` or a regex:

```text
parse_object(text): cursor=(code-point index 0, line 1, column 1)
  skip only U+0020, U+0009, U+000A, U+000D
  value = parse_value(); skip whitespace; require EOF; require Dictionary; return detached value
parse_value(): dispatch only on {, [, ", -, 0..9, true, false, null
parse_object_value(): consume {; for each member parse_string key; reject key already in seen
  before parsing/inserting its value; require :; parse_value; require comma or closing }
parse_array(): consume [; parse values in source order; require comma or closing ]
parse_string(): reject raw U+0000..U+001F and raw/escaped lone U+D800..U+DFFF;
  accept only \" \\ \/ \b \f \n \r \t and exactly four-hex \u escapes;
  combine one high-surrogate escape only with the immediately following low-surrogate escape
parse_number(): scan exactly -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?;
  reject a leading zero or unconsumed numeric character; without fraction/exponent, accumulate
  a checked signed 64-bit integer digit-by-digit and reject overflow; otherwise convert only the
  already-validated ASCII token to float and reject non-finite output
literal(): consume the exact lowercase bytes true, false, or null
error(): report the first offending code point using the cursor's 1-based line/column
```

The parser stores no object member until its normalized key has passed the per-object `seen` check. Array/object returns and error payloads are newly allocated. A non-exported value-document entry point may be shared with the writer's self-check, but `parse_object()` remains the only public parser API and still rejects every non-object root.

- [ ] Implement canonical emission recursively with these exact rules:

```text
null/bool: null, true, false
int: minimal base-10 ASCII, including the full signed 64-bit range
float: reject non-finite; normalize either signed zero to 0.0; otherwise generate exactly
  17 significant decimal digits with the engine's locale-independent scientific formatter,
  lowercase e, remove exponent + and leading exponent zeroes, and retain at least one fractional
  digit; strict-reparse and require the identical IEEE-754 value and TYPE_FLOAT
String: emit UTF-8 scalar values; use \" and \\; use \b/\f/\n/\r/\t for those controls and
  lowercase \u00xx for every other U+0000..U+001F; reject lone surrogate code points
Array: preserve index order and recursively emit each element
Dictionary: normalize every StringName key to String in a fresh map, reject a normalization
  collision, sort keys byte-by-byte by unsigned UTF-8 bytes (shorter prefix first), then emit
  each normalized key/value once
other Variant type: fail before returning any text
```

After emission, run the same private strict value parser over the complete output, require EOF and deep type/value equality, and only then return the String. This private self-check does not widen `StrictJson.parse_object()` or any frozen public interface.

- [ ] Implement the frozen storage signatures without removing delete support:

```gdscript
# scripts/infrastructure/storage/StorageAdapter.gd
class_name StorageAdapter
extends RefCounted

func read_text(relative_path: String) -> Dictionary
func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary
func reconcile(relative_path: String, validator: Callable) -> Dictionary
func exists(relative_path: String) -> bool
func remove(relative_path: String) -> Dictionary
func describe_root() -> String

# scripts/infrastructure/storage/JsonFileStorage.gd
func _init(root_dir: String, file_ops: RefCounted = null) -> void
```

`validator` receives the exact re-read UTF-8 String and returns `{ok:true, value:Dictionary}` or `{ok:false, code:StringName, message:String}`. `write_atomic()` rejects an invalid/unbound callable before I/O and invokes it before the first write and after every candidate re-read. Owners independently validate a detached Dictionary before `CanonicalJsonWriter.stringify()`. Because `read_text()` has no validator parameter, every owner calls `reconcile(relative_path, validator)` and then `read_text(relative_path)`; the lease is final-path plus SHA-256 and `read_text()` returns `reconcile_required` if it is absent or stale.

- [ ] `FileOps` and `FakeFileOps` expose the same seam:

```gdscript
func exists(path: String) -> bool
func read_bytes(path: String) -> Dictionary
func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary
func flush_path(path: String) -> Dictionary
func rename_path(from_path: String, to_path: String) -> Dictionary
func remove_path(path: String) -> Dictionary
func sha256(bytes: PackedByteArray) -> String
```

`write_bytes()` retains its handle only until `flush_path()`, which flushes and closes even when reporting failure. `FakeFileOps.fail_after(operation_ordinal)` fails exactly one operation and records an immutable operation trace. After each injected failure, tests discard the adapter and FileOps, construct fresh instances over only the simulated persisted artifact map, and reconcile; no lease, open handle, cached parse, or object identity may aid recovery.

- [ ] For `profile.json`, the transaction family is exactly `profile.json`, `.next`, `.txn.json`, and `.bak`. All markers use `CanonicalJsonWriter`; all marker reads use `StrictJson`. A write marker has this closed shape:

```json
{
  "backup_hash": null,
  "keep_backup": true,
  "next_hash": null,
  "operation": "write",
  "outgoing_hash": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "previous_hash": null,
  "relative_path": "profile.json",
  "schema_version": 1,
  "stage": "prepared"
}
```

`operation` is exactly `write` or `delete`. Write `stage` is exactly `prepared`, `next_validated`, `backup_preserved`, or `final_promoted`; `outgoing_hash` is present from `prepared` onward, `next_hash` equals it after next validation, `previous_hash` is the validated old-final hash or null for a first write, and `backup_hash` equals `previous_hash` after backup preservation. Hashes are null or 64 lowercase hexadecimal SHA-256 characters.

- [ ] Execute a write in this exact order:

```text
reconcile the existing transaction family
validate outgoing text; compute outgoing_hash; capture validated previous_hash or proven absence
write/flush/re-read/strict-validate canonical marker(operation=write, stage=prepared)
write and flush .next
re-read .next; require exact outgoing bytes, validator success, and outgoing_hash
write/flush/re-read marker(stage=next_validated, next_hash=outgoing_hash)
if previous exists, replace .bak with that exact previous final and verify its hash
write/flush/re-read marker(stage=backup_preserved, backup_hash=previous_hash)
promote .next to final
re-read final; require exact outgoing bytes, validator success, and outgoing_hash
write/flush/re-read marker(stage=final_promoted)
remove residual .next; remove marker last; retain .bak iff keep_backup=true
```

The durable `prepared` marker is written before `.next`, including on the first write. Therefore a future first-write crash never creates an unowned candidate. A markerless orphan `.next` plus a validator-valid final is stale and may be removed after final wins; a markerless `.next` with no valid final is `indeterminate_transaction`, is preserved, and is never promoted merely because it parses. A genuinely absent final with no transaction artifacts reconciles to `{exists:false}`.

- [ ] Reconciliation first classifies each final/`.next`/`.bak` artifact as `absent`, `valid(hash, exact_bytes)`, or `invalid`; `invalid` is never treated as `absent`. It strict-parses and schema-validates the marker, verifies the exact operation/path/version/stage keys and stage-dependent hashes, then applies this closed decision table:

| Durable evidence | Deterministic action/result |
|---|---|
| Valid `delete/delete_marked` marker | Delete final, `.next`, and `.bak`; remove marker last; retry any failed removal on the next reconciliation; deletion is the winner. |
| Valid write marker and valid final hash = `outgoing_hash` | New bytes win; remove residual `.next`, then marker; retain `.bak` only when requested. |
| Write stage `prepared`, `next_validated`, or `backup_preserved`, and valid `.next` hash = `outgoing_hash` | Promote that exact `.next`, re-read/validate/hash final, then take the new-winner row. |
| Write stage `prepared`, no outgoing candidate, `previous_hash=null`, and final is absent | Prove first-write absence, remove owned residue/marker, return `write_not_committed`. |
| Write stage `prepared`, no outgoing candidate, and final or `.bak` validly matches non-null `previous_hash` | Keep or restore those exact previous bytes, verify final, remove owned residue/marker, return `write_not_committed`. |
| Write stage `next_validated` or `backup_preserved` without either an outgoing final or outgoing `.next` | `indeterminate_commit`; a previously validated candidate cannot disappear in the declared sequence. |
| Write stage `final_promoted` without an outgoing final | `indeterminate_commit`, regardless of a previous-looking final/backup. |
| No marker, valid final, any `.next` | Final wins; remove the orphan `.next`; do not promote it. A retained valid `.bak` remains only backup evidence. |
| No marker, absent/invalid final, but `.next`, `.bak`, or a corrupt marker exists | `indeterminate_transaction`; preserve every artifact. |
| Any hash/stage/path inconsistency, invalid artifact needed by a row, or two different plausible winners | Fatal `indeterminate_commit`; preserve every artifact. |

For `backup_preserved`, a non-null `previous_hash` additionally requires `backup_hash=previous_hash` and a validator-valid matching `.bak`; a null `previous_hash` requires both hashes null and no transaction-owned backup. Marker cleanup is never evidence of commit: re-read final decides the result. A fresh adapter never guesses from a corrupt marker. Only the still-running operation that already holds a deep-copied known intent `{operation, relative_path, outgoing_hash, previous_hash, previous_absent}` may repair its own failed marker write; it must classify against those hashes, remove/replace the corrupt marker, and run ordinary reconciliation again before returning. If that clean second pass cannot prove new bytes or the exact previous/absent state, it returns fatal indeterminate.

- [ ] After **every** injected write failure, invalidate the lease and reconcile fresh against the known `outgoing_hash` and the marker's `previous_hash`/proven absence. Return success when the validator-valid final hash equals `outgoing_hash`, even if the original operation reported a failure. Return ordinary `write_not_committed` only when the exact previous document is the deterministic winner or first-write absence is proven and outgoing bytes did not win. Return fatal `indeterminate_commit` and preserve all evidence when neither winner can be proven. It is forbidden to report ordinary failure after new bytes durably won. Tests assert this tri-state result at every marker write/flush/re-read, next write/flush/re-read, backup removal/rename/re-read, promotion, final re-read, cleanup, and marker-removal failpoint for both first write and replacement.

- [ ] Give `FakeFileOps` a deep-copying `snapshot_persisted() -> Dictionary` and constructor seed, then use these exact runnable fixtures in `test_json_file_storage.gd`:

```gdscript
const OLD_TEXT := "{\"generation\":1}"
const NEW_TEXT := "{\"generation\":2}"

func _generation_validator(text: String) -> Dictionary:
	var parsed: Dictionary = _strict_script.call(&"parse_object", text)
	if not parsed.get("ok", false):
		return parsed
	var value: Dictionary = parsed["value"]
	if value.keys() != ["generation"] or typeof(value["generation"]) != TYPE_INT:
		return {"ok": false, "code": &"invalid_fixture", "message": "generation:int required"}
	return {"ok": true, "value": value.duplicate(true)}

func _restart_and_reconcile(persisted: Dictionary) -> Dictionary:
	var restarted_ops = _fake_ops_script.new(persisted.duplicate(true))
	var restarted = _storage_script.new(_root, restarted_ops)
	return restarted.reconcile("profile.json", _generation_validator)
```

Run the complete operation trace once without failure to obtain ordinals. For every ordinal, seed either no final (first write) or `OLD_TEXT` (replacement), inject exactly that one failure, discard both objects, restart only from `snapshot_persisted()`, and assert one of: final bytes/hash exactly `NEW_TEXT` plus success; final bytes/hash exactly `OLD_TEXT` or proven absence plus `write_not_committed`; or preserved artifacts plus `indeterminate_commit`. Add named artifact fixtures for markerless `{final=OLD_TEXT,next=NEW_TEXT}` → old wins, markerless `{next=NEW_TEXT}` → indeterminate, valid prepared marker plus outgoing `.next` → new wins, valid prepared marker plus only previous final → old wins, `next_validated` with missing outgoing bytes → indeterminate, `final_promoted` with non-outgoing final → indeterminate, and corrupt marker → indeterminate. Repeat every removal ordinal with old final and require: no durable delete marker → old wins; durable `delete_marked` marker → fresh reconciliation finishes absence and returns success. Tests compare exact bytes, hashes, result code, and residual artifact names, not only `ok`.

- [ ] Because the frozen `remove(relative_path)` signature has no validator, it requires a fresh lease from the owner's immediately preceding `reconcile(relative_path, validator)`; an absent/stale lease or changed final hash returns `reconcile_required` without mutation. `remove()` then uses the same family and this canonical tombstone:

```json
{
  "operation": "delete",
  "previous_hash": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "relative_path": "profile.json",
  "schema_version": 1,
  "stage": "delete_marked"
}
```

It first reconciles, captures a validated final hash or proven absence, then writes/flushes/re-reads the `delete_marked` marker before removing final, `.next`, and `.bak`; the marker is removed last. `reconcile()` always completes a valid delete marker before considering backup recovery, so `.bak` can never resurrect deleted state. If marker creation did not become durable, the exact old/absent state wins and `remove()` reports uncommitted; if the marker became durable, fresh reconciliation completes deletion and reports success. A corrupt delete marker fails closed. Delete tests inject every marker, final, next, backup, and marker-removal failure, restart from persisted artifacts, and assert final/next/backup are absent after success.

- [ ] Reconciliation never combines bytes, trusts a hash without validator success, treats corrupt artifacts as absence, or improvises rollback. Reject empty/rooted/schemed/drive-prefixed/ADS/NUL paths, `.`/`..` segments, normalized escapes, and targets outside the constructor root. `TemporaryStorage.create(suite_id)` resolves exactly `DWM_TEST_ROOT.path_join(str(OS.get_process_id())).path_join(str(_counter)).path_join(suite_id)`, proves it is a strict descendant of wrapper-owned `.godot/phase2r_tests`, and proves it differs from production `user://`.

- [ ] Run the JSON/storage tests:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'json_file_storage_green' -LogName 'phase2r-json-file-storage-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_strict_json.gd,res://tests/unit/test_json_file_storage.gd','-gexit')
```

Expected GREEN: duplicate JSON keys and noncanonical values reject; canonical output is byte-identical across insertion orders; every write failpoint returns new-won success, old/absent-won failure, or fatal indeterminate; every delete failpoint completes without resurrection; path escapes reject; production-path access is zero.

- [ ] **Step 1.3: Implement the exact profile schema and migration policy**

- [ ] `ProfileSchema` and `ProfileMigration` expose:

```gdscript
# ProfileSchema.gd
static func make_defaults() -> Dictionary
static func validate(profile: Dictionary) -> Dictionary
static func validate_preference(path: StringName, value: Variant) -> Dictionary

# ProfileMigration.gd
static func prepare_document(raw: Dictionary) -> Dictionary
static func prepare_legacy_patch(legacy_run_state: Dictionary, legacy_input_mappings: Dictionary = {}) -> Dictionary
```

- [ ] `make_defaults()` returns exactly this schema-version-1 document:

```json
{
  "schema_version": 1,
  "gallery_unlocks": [],
  "gallery_transaction_receipts": {},
  "visited_line_ids": [],
  "preferences": {
    "language": "en",
    "audio": {
      "music_volume": 0.8,
      "music_muted": false,
      "ambience_volume": 0.65,
      "ambience_muted": false,
      "sfx_volume": 0.8,
      "sfx_muted": false,
      "voice_volume": 0.8,
      "voice_muted": false,
      "mute_audio_on_focus_loss": false
    },
    "dialogue": {
      "text_speed": 1.0,
      "auto_text_speed": 1.0,
      "skip_mode": "read_only",
      "auto_advance_dialogue": false
    },
    "display": {"fullscreen": false},
    "accessibility": {
      "font_scale": 1.0,
      "high_contrast": false,
      "reduced_motion": false,
      "screen_shake_strength": 0.5,
      "large_click_targets": false,
      "hold_to_confirm": false,
      "colorblind_mode": "none",
      "show_focus_ring": true,
      "controller_cursor_enabled": false,
      "subtitles_enabled": true,
      "captions_enabled": true,
      "subtitle_speaker_names": true,
      "subtitle_background_opacity": 0.85,
      "text_box_opacity": 0.9,
      "visual_audio_cues": true,
      "flashing_effects_enabled": false,
      "tutorial_replay_available": true,
      "pause_on_focus_loss": true
    }
  },
  "input_mappings": {},
  "migration_receipts": {
    "legacy_game_state_profile_v1": false,
    "legacy_input_bindings_v1": false,
    "invalid_persisted_skip_mode_v1": false
  }
}
```

`gallery_transaction_receipts` is a strict map whose nonempty keys are stable transaction IDs and whose values are exactly `{"ending_id": String, "unlocked": bool}`. `reset_gallery()` and `reset_entire_profile()` clear user-visible `gallery_unlocks` but retain this ledger; replaying a retained transaction does not re-unlock an ending. Both operations also retain every `migration_receipts` flag so removed legacy state cannot import again. Schema validation recursively copies accepted input before returning it; neither a validated candidate nor any nested receipt aliases caller memory.

- [ ] Validate exactly `ending.alone`, `ending.priscilla.sweet`, `ending.priscilla.dark`, `ending.priscilla.true`, `ending.lavinia.sweet`, `ending.lavinia.dark`, `ending.lavinia.true`, `ending.sylvia.sweet`, `ending.sylvia.dark`, `ending.sylvia.true`, `ending.sylvia.special`, and `ending.priscilla_lavinia`; unique nonempty visited line IDs; and allowlisted input event records. A key event is `{"kind":"key","physical_keycode":int,"keycode":int,"shift":bool,"alt":bool,"ctrl":bool,"meta":bool}`; a joypad event is `{"kind":"joypad_button","button_index":int,"device":int}`. Unknown keys and malformed nested values fail. Volumes, opacity, and shake values are finite floats in `0.0..1.0`; text/auto speed and font scale are finite floats greater than `0.0`; `skip_mode` is exactly `read_only` or `all_text`.

- [ ] Public preference paths are always fully qualified from the profile root: `preferences.language`, `preferences.audio.*`, `preferences.dialogue.*`, `preferences.display.*`, and `preferences.accessibility.*`. Bare paths such as `language`, `audio.music_volume`, or `dialogue.skip_mode` reject with `invalid_preference_path`; no public method accepts both forms. `preferences.language` is schema-valid when it is a trimmed nonempty String and is not locale-enumerated. Direct `set_preference(&"preferences.language", ...)` and any batch containing it fail atomically with `managed_preference`; only `prepare_locale_preference(locale_id)` may build that candidate after manifest validation.

- [ ] `ProfileMigration.prepare_document()` handles one narrow invalid persisted value: an otherwise schema-version-1 document whose only invalid field is `preferences.dialogue.skip_mode` is normalized to `read_only` and sets `invalid_persisted_skip_mode_v1=true`. The known legacy boolean maps `skip_unseen_text_allowed=true` to `preferences.dialogue.skip_mode=all_text` and false to `preferences.dialogue.skip_mode=read_only`. Other malformed types, unknown fields, or future versions fail; migration never silently drops them.

- [ ] **Step 1.4: Implement all frozen ProfileManager APIs and deferred publication**

- [ ] Implement every master signature and signal exactly:

```gdscript
signal profile_restored(profile: Dictionary)
signal preference_changed(path: StringName, value: Variant)
signal gallery_changed(ending_id: String, unlocked: bool)
signal visited_history_changed(line_id: String, visited: bool)
signal input_mappings_changed(action_id: StringName)
signal profile_reset(section: StringName)
signal profile_write_failed(result: Dictionary)

func initialize(storage: StorageAdapter = null) -> Dictionary
func prepare_profile_document(raw: Dictionary) -> Dictionary
func prepare_preferences(changes: Dictionary) -> Dictionary
func prepare_locale_preference(locale_id: String) -> Dictionary
func commit_prepared_profile(candidate: Dictionary, defer_signals: bool = false) -> Dictionary
func publish_deferred_profile_signals(publication_id: String) -> Dictionary
func get_profile_snapshot() -> Dictionary
func get_preference(path: StringName, default_value: Variant = null) -> Variant
func set_preference(path: StringName, value: Variant) -> Dictionary
func set_preferences(changes: Dictionary) -> Dictionary
func is_line_visited(line_id: String) -> bool
func mark_line_visited(line_id: String) -> Dictionary
func has_gallery_unlock(ending_id: String) -> bool
func prepare_ending_unlock(ending_id: String, transaction_id: String) -> Dictionary
func unlock_ending(ending_id: String, transaction_id: String) -> Dictionary
func get_input_mappings() -> Dictionary
func set_input_mapping(action_id: StringName, events: Array[Dictionary]) -> Dictionary
func prepare_legacy_profile_patch(legacy_run_state: Dictionary, legacy_input_mappings: Dictionary = {}) -> Dictionary
func reset_preferences() -> Dictionary
func reset_visited_history() -> Dictionary
func reset_gallery() -> Dictionary
func reset_entire_profile() -> Dictionary
func configure_mutation_gate(gate: Object) -> Dictionary
func capture_restore_state() -> Dictionary
func apply_restore_silent(plan: Dictionary) -> Dictionary
func rollback_restore_silent(backup: Dictionary) -> Dictionary
func finalize_restore() -> Dictionary
```

- [ ] Implement ProfileManager's common mutation-gate configuration contract now, before any bootstrap test. `test_profile_manager.gd` configures a valid fake, repeats the same instance, then attempts null, each missing gate method/signal, and a different valid instance; it asserts the exact result codes/instance ID, no storage operation, no profile byte change, and no profile signal.

- [ ] `prepare_preferences(changes)` and `set_preferences(changes)` accept exactly one flat batch shape whose keys are unique fully qualified `StringName` preference paths and whose values are leaf values:

```gdscript
{
	&"preferences.audio.music_volume": 0.5,
	&"preferences.dialogue.skip_mode": "all_text",
	&"preferences.accessibility.font_scale": 1.2,
}
```

Nested batches, bare/relative paths, non-leaf paths, String keys, unknown leaves, and a batch containing `&"preferences.language"` reject atomically. Empty batches return an unchanged detached candidate and emit/write nothing. Validation and publication order is lexicographic by fully qualified UTF-8 path; `get_preference()`, `set_preference()`, `validate_preference()`, `preference_changed`, Settings controllers, migration assertions, and consumer filters use the identical path vocabulary.

- [ ] Every mutation recursively duplicates input, prepares and validates a detached candidate, serializes it through `CanonicalJsonWriter.stringify()`, calls `write_atomic("profile.json", text, validator)`, swaps live state only after storage proves success, then emits deterministic post-commit signals whose payloads are detached from manager state. `write_not_committed` leaves memory on the old profile and emits only a copied `profile_write_failed(result)`; `indeterminate_commit` blocks further profile mutation and bootstrap. If storage reports success because the outgoing bytes won during reconciliation, ProfileManager commits that exact candidate in memory and publishes the normal success signals rather than emitting a false failure.

- [ ] A deferred commit returns one opaque nonempty `publication_id`. It swaps the committed profile but emits no profile signal until `publish_deferred_profile_signals(publication_id)`. The manager stores a deep-copied immutable diff plus any gallery transaction IDs behind that ID. Publication is accepted exactly once; an unknown or repeated ID fails without a signal. Returned IDs do not expose the candidate. This seam is shared by Task 4 locale switching and plan 04 ending playback.

- [ ] `mark_line_visited()` is idempotent. `prepare_ending_unlock()` returns this detached value and performs no write, live mutation, or signal:

```gdscript
{
	"candidate": Dictionary,
	"transaction_id": String,
	"gallery_receipt": {"ending_id": String, "unlocked": bool},
	"requires_commit": bool,
	"pending_publication_id": String,
}
```

For a new run-scoped transaction it adds the receipt and, when not already unlocked, the canonical ending ID to one candidate and sets `requires_commit=true`. Repeating the same transaction/ending returns the exact prior receipt, `requires_commit=false`, and the still-pending publication ID when one exists in this process; repeating the transaction with another ending rejects. `unlock_ending()` is the immediate convenience path: prepare, commit with `defer_signals=false`, return the receipt. Plan 04 MUST use the prepared path: prepare → `commit_prepared_profile(candidate, true)` when required → commit lifecycle/checkpoint → publish the returned or pending publication ID. If the checkpoint fails after profile commit, retry reuses the durable receipt and pending ID without a second unlock; after process restart the already-restored profile needs no historical signal replay. Gallery reset retains the receipt, so replay remains a no-op and a later run must use a new transaction ID.
- [ ] Reset commits publish changed records in this closed order: `preference_changed` by lexicographic fully qualified `preferences.*` path, `input_mappings_changed` by action ID, `gallery_changed(..., false)` by ending ID, `visited_history_changed(..., false)` by line ID, then exactly one `profile_reset(section)`. A category with no change emits nothing. `reset_preferences()` uses schema defaults; `reset_visited_history()` and `reset_gallery()` do not touch preferences; entire reset retains only the two internal receipt ledgers described above.

- [ ] Add adversarial alias tests for every ProfileManager boundary: mutate raw documents after `prepare_profile_document()`, batches after `prepare_preferences()`, candidates after `commit_prepared_profile()`, nested snapshots returned by `get_profile_snapshot()`/`get_input_mappings()`, restore backups/plans after apply, and a captured signal Dictionary after synchronous emission. Internal bytes, later getters, and deferred publication records remain byte-identical. Tests also document that signal listeners receive a shared read-only payload instance.

- [ ] **Step 1.5: Freeze literal autoload order and the staged startup contract**

- [ ] Replace the entire `[autoload]` entry order with these literal lines while preserving the existing Dialogic UID:

```ini
ProfileManager="*res://autoload/ProfileManager.gd"
GameState="*res://autoload/GameState.gd"
SaveManager="*res://autoload/SaveManager.gd"
LocalizationManager="*res://autoload/LocalizationManager.gd"
AudioManager="*res://autoload/AudioManager.gd"
EffectResolver="*res://autoload/EffectResolver.gd"
SceneRouter="*res://autoload/SceneRouter.gd"
InputManager="*res://autoload/InputManager.gd"
AccessibilityManager="*res://autoload/AccessibilityManager.gd"
Dialogic="*uid://ds2q0uclmolvu"
DialogicBridge="*res://autoload/DialogicBridge.gd"
ApplicationBootstrap="*res://autoload/ApplicationBootstrap.gd"
```

- [ ] All project-manager `_ready()` methods return without reading disk, connecting profile signals, creating audio players/buses, applying input/accessibility/localization state, or touching another manager. `ApplicationBootstrap._ready()` performs only a deferred call to `start(_requested_mode_from_debug_args())`; `start(mode)` owns all fallible work and rejects a second call.

- [ ] Freeze the final named stage order now:

```gdscript
const STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
	&"initialize_profile",
	&"initialize_saves",
	&"initialize_localization",
	&"initialize_input",
	&"initialize_accessibility",
	&"initialize_audio",
	&"initialize_dialogic_bridge",
	&"configure_restore_participants",
	&"configure_day_resolution",
	&"configure_minesweeper_rounds",
	&"publish_application_ready",
]
```

Task `.3` implements and tests the stage runner plus the profile/localization/input/accessibility/audio/Dialogic preference stages it owns. The `construct_and_inject_mutation_gate` slot is present now, between proven-root selection and every manager initialization; plan 03 supplies its production `ApplicationMutationGate` class and concrete adapter without changing the slot. Plans 03, 05, and 06 add their other concrete stage adapters without reordering this list. In final mode, a missing/failing stage records one fatal result, stops before later stages, leaves menu/run input disabled, and emits no `application_ready`; no partial state is represented as application-ready.

- [ ] Freeze the gate-stage adapter contract before profile initialization. It constructs exactly one compatible object, resolves the ordered target list for the requested mode, calls `configure_mutation_gate(gate)` once per target, and requires every success `gate_instance_id` to equal that one object's instance ID. Null, a missing gate method/signal, a missing/incompatible target, a different retained instance, or failure at any target is fatal, invokes no initialization stage, emits no readiness, and leaves input disabled. Injection performs no disk I/O or domain mutation. A partial injection is not rolled back by replacement; bootstrap remains fatal for that process. Plan 03 replaces only the final-mode production factory/target implementations, not the stage ID, order, or result contract.

`FakeApplicationMutationGate` implements all eight methods and `capability_changed` with the frozen CommandResult union. Before a fatal latch it accepts only `restore`/`new_run`, issues deterministic `fake-gate-<counter>` tokens, rejects nested acquisition and wrong owner/token release, and deep-copies its ordered call log. Its `latch_fatal()`/`is_fatal_latched()` behavior is byte-shape-compatible with Plan 03's production contract: invalid failure input does not latch; the first valid failure is detached and retained irreversibly; an identical repeat is idempotent; a different valid repeat returns `APPLICATION_FATAL_CONFLICT`; and every later acquire, release, external guard, or internal-owner check remains blocked exactly as specified by Plan 03. The fake never represents fatal as an acquire owner. It is injected only when a debug process proves the wrapper-owned root; production/final startup never falls back to a test fake. Missing-method cases use deliberately incomplete local doubles rather than flags that make `has_method()` lie.

- [ ] Distinguish the shipping contract from the temporary development subset explicitly:

```gdscript
const MODE_FINAL := &"final"
const MODE_TEST_MANUAL := &"test_manual"
const MODE_PROFILE_LOCALIZATION_DEVELOPMENT := &"profile_localization_development"
const MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT := &"profile_locale_audio_development"

const FINAL_GATE_TARGETS: Array[StringName] = [
	&"SaveManager", &"GameState", &"ProfileManager", &"LocalizationManager",
	&"AudioManager", &"SceneRouter", &"DialogicBridge", &"InputManager",
]

const DEVELOPMENT_GATE_TARGETS := {
	MODE_PROFILE_LOCALIZATION_DEVELOPMENT: [
		&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager",
	],
	MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT: [
		&"ProfileManager", &"LocalizationManager", &"InputManager", &"AccessibilityManager",
		&"AudioManager", &"DialogicBridge",
	],
}

const DEVELOPMENT_STAGE_SETS := {
	MODE_PROFILE_LOCALIZATION_DEVELOPMENT: [
		&"select_and_prove_roots", &"construct_and_inject_mutation_gate",
		&"initialize_profile", &"initialize_localization",
		&"initialize_input", &"initialize_accessibility",
	],
	MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT: [
		&"select_and_prove_roots", &"construct_and_inject_mutation_gate",
		&"initialize_profile", &"initialize_localization",
		&"initialize_input", &"initialize_accessibility",
		&"initialize_audio", &"initialize_dialogic_bridge",
	],
}

signal application_ready()
signal development_subset_ready(subset_id: StringName)

func configure_debug_mutation_gate_factory(factory: Callable) -> Dictionary
func start(mode: StringName = MODE_FINAL) -> Dictionary
func get_startup_state() -> Dictionary
```

`configure_debug_mutation_gate_factory()` is the only pre-start test seam. It succeeds only when all of these are already true: `OS.is_debug_build()`, the exact requested command-line mode is one of the two development modes, `DWM_TEST_ROOT` is nonempty and canonicalizes to a strict descendant of the repository's `.godot/phase2r_tests`, the deferred start has not begun, no factory was previously stored, and `factory.is_valid()`. It stores a copied Callable without invoking it and returns `value={"configured":true}`. Otherwise it stores nothing and fails with exactly `debug_gate_factory_forbidden`, `debug_gate_factory_too_late`, `debug_gate_factory_already_configured`, or `invalid_debug_gate_factory`. `_ready()` still only schedules deferred start, leaving the main test scene's `_enter_tree()` a deterministic configuration window. The development gate stage calls the stored factory exactly once, requires one compatible gate object, and injects only `DEVELOPMENT_GATE_TARGETS[mode]`. `MODE_FINAL` never reads or accepts this seam, uses only `FINAL_GATE_TARGETS`, and remains a `missing_production_gate_factory` fatal blocker until plan 03 installs the production factory.

After the gate stage, `get_startup_state()` includes this recursively copied identity record in addition to its existing mode/stage/fatal records:

```gdscript
"gate_injection": {
	"factory_invocation_count": int,
	"gate_instance_id": int,
	"targets": Array[StringName],
	"target_instance_ids": Array[int],
}
```

On a successful development stage, `factory_invocation_count` is exactly `1`, `targets` equals the selected `DEVELOPMENT_GATE_TARGETS[mode]` byte-for-byte and in order, and every parallel entry in `target_instance_ids` equals `gate_instance_id`. The record never contains an Object, Callable, node reference, or mutable target result. Before construction the count is `0` and all other fields are empty/zero; on failure it records only the completed attempts, while the fatal result identifies the failing construction or target. This evidence does not relax the final-mode production-factory blocker.

`MODE_FINAL` always executes every `STAGE_ORDER` entry and remains fail-closed: an absent/failing stage records exactly one fatal startup result, disables menu/run input, emits neither ready signal, and stops. `_requested_mode_from_debug_args()` selects an explicit `--phase2r-bootstrap-mode=<id>` first; with no explicit ID it selects `test_manual` only when a debug build can prove the wrapper-owned `DWM_TEST_ROOT`, otherwise `final`. `test_manual` executes no stage, emits no ready/fatal/project diagnostic, keeps input disabled, and exists only so focused tests can construct isolated managers/bootstrap instances explicitly; it is not readiness or a pass. Other development modes require an exact explicit argument: `profile_localization_development` executes roots, gate construction/injection into its four ordered development targets, profile, localization, input, and accessibility; `profile_locale_audio_development` executes those stages with its six ordered development targets followed by audio and DialogicBridge. Omitted stages and final-only gate targets are informational `planned_blocker` entries, produce no `push_error`, warning, fatal diagnostic, or fake pass, emit only `development_subset_ready(mode)`, and never emit `application_ready`. An unknown mode, any non-final mode in a non-debug/unproven-root process, a missing debug factory, or failure inside an included stage fails closed. Plan 06 removes development-mode use from the final startup gate; debug modes cannot satisfy shipping readiness.

- [ ] The root stage chooses the already wrapper-proven `DWM_TEST_ROOT` in tests and production `user://` otherwise. It constructs the profile adapter at the selected root and later SaveManager at `selected_root.path_join("saves")`; no other autoload constructs production storage.

- [ ] **Step 1.6: Complete profile/storage/bootstrap tests and turn GREEN**

- [ ] Add tests for unknown and malformed nested fields; canonical profile bytes across insertion orders; invalid-skip migration; nonempty extensible language validation; fully qualified flat preference batches; rejection of bare/nested/String-key/language batches; deferred publication exactly once; prepared ending unlock plus checkpoint-retry publication; write/delete reconcile tri-state results; duplicate gallery transaction conflict; gallery/reset ledger retention; migration receipt retention; independent reset signals; all no-alias cases; isolated root enforcement; input event validation; reinitialization rejection; and `GameState.reset_game()` leaving profile bytes unchanged.

- [ ] Bootstrap tests inject one fake callable per stage, assert final-mode exact order, fail every ordinal in turn, and prove no later call, no ready signal, one fatal result, and disabled input. Add named cases `test_debug_gate_factory_rejects_release_or_final_process`, `test_debug_gate_factory_rejects_unproven_root`, `test_debug_gate_factory_rejects_invalid_duplicate_or_late_configuration`, `test_gate_construction_failure_stops_before_profile`, `test_gate_rejects_each_missing_method_or_signal`, `test_development_gate_targets_are_exact_and_ordered`, `test_gate_injection_failure_at_each_development_target_stops_before_profile`, `test_gate_rejects_different_retained_instance`, and `test_gate_is_one_identity_for_every_selected_target`. The four-target mode must record exactly ProfileManager → LocalizationManager → InputManager → AccessibilityManager; the six-target mode appends AudioManager → DialogicBridge; SaveManager, GameState, SceneRouter, and every other autoload record zero configuration calls in development. Test-owned target doubles verify final mode still resolves the exact eight `FINAL_GATE_TARGETS` and fails when its production factory is absent; Task 1 does not require those later-plan production targets to implement the seam. Each failure case records that no target initializer or disk adapter was called. Separate cases prove automatic wrapper-root `test_manual` executes nothing and is not ready, then assert the exact six-stage `[roots, gate, profile, localization, input, accessibility]` and eight-stage `[roots, gate, profile, localization, input, accessibility, audio, dialogic]` development subsets, informational skipped-stage/final-target records, zero fatal/project diagnostics, no `application_ready`, one `development_subset_ready(mode)`, and disabled gameplay input. At this boundary, a source scan asserts the newly created ProfileManager `_ready()` contains no side effect and ApplicationBootstrap `_ready()` contains only the deferred `start` call. Tasks 2, 4, and 6 extend the same test with each real Plan-02-owned manager as its owning file changes; plan 05 performs the ready-callback migration for EffectResolver.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'profile_storage_green' -LogName 'phase2r-profile-storage-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_strict_json.gd,res://tests/unit/test_json_file_storage.gd,res://tests/unit/test_profile_manager.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd','-gexit')
```

Expected GREEN: zero failures and diagnostics, every failpoint recovers, all profile contracts pass, and production persistence access count is zero.
- [ ] **Step 1.7: Proposed path-specific commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'scripts/infrastructure/storage/StorageAdapter.gd'='A'
  'scripts/infrastructure/storage/FileOps.gd'='A'
  'scripts/infrastructure/storage/JsonFileStorage.gd'='A'
  'scripts/validation/StrictJson.gd'='A'
  'scripts/validation/CanonicalJsonWriter.gd'='A'
  'scripts/profile/ProfileSchema.gd'='A'
  'scripts/profile/ProfileMigration.gd'='A'
  'autoload/ProfileManager.gd'='A'
  'autoload/ApplicationBootstrap.gd'='A'
  'schemas/profile.schema.json'='A'
  'tests/support/DynamicScriptProbe.gd'='A'
  'tests/support/FakeFileOps.gd'='A'
  'tests/support/FakeApplicationMutationGate.gd'='A'
  'tests/support/TemporaryStorage.gd'='A'
  'tests/unit/test_json_file_storage.gd'='A'
  'tests/unit/test_strict_json.gd'='A'
  'tests/unit/test_profile_manager.gd'='A'
  'tests/unit/test_application_bootstrap_profile_stage.gd'='A'
  'project.godot'='M'
}
$optionalUids = [ordered]@{
  'scripts/infrastructure/storage/StorageAdapter.gd.uid'='A'
  'scripts/infrastructure/storage/FileOps.gd.uid'='A'
  'scripts/infrastructure/storage/JsonFileStorage.gd.uid'='A'
  'scripts/validation/StrictJson.gd.uid'='A'
  'scripts/validation/CanonicalJsonWriter.gd.uid'='A'
  'scripts/profile/ProfileSchema.gd.uid'='A'
  'scripts/profile/ProfileMigration.gd.uid'='A'
  'autoload/ProfileManager.gd.uid'='A'
  'autoload/ApplicationBootstrap.gd.uid'='A'
  'tests/support/DynamicScriptProbe.gd.uid'='A'
  'tests/support/FakeFileOps.gd.uid'='A'
  'tests/support/FakeApplicationMutationGate.gd.uid'='A'
  'tests/support/TemporaryStorage.gd.uid'='A'
  'tests/unit/test_json_file_storage.gd.uid'='A'
  'tests/unit/test_strict_json.gd.uid'='A'
  'tests/unit/test_profile_manager.gd.uid'='A'
  'tests/unit/test_application_bootstrap_profile_stage.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Plan 02 Task 1 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'feat(profile): add crash-safe global profile persistence'
if ($LASTEXITCODE -ne 0) { throw 'Exact Plan 02 Task 1 commit boundary failed.' }
~~~

## Task 2: Move permanent ownership out of GameState and legacy input files

**Files:**

- Modify: `scripts/profile/ProfileMigration.gd`
- Modify: `autoload/GameState.gd`
- Modify: `autoload/InputManager.gd`
- Modify: `autoload/AccessibilityManager.gd`
- Modify: `autoload/LocalizationManager.gd`
- Modify: `autoload/AudioManager.gd`
- Modify: `scripts/ui/StatHud.gd`
- Modify: `scripts/ui/GalleryScene.gd`
- Modify: `scripts/ui/EndingScene.gd`
- Modify: `tests/unit/test_game_state.gd`
- Modify: `tests/unit/test_input_accessibility.gd`
- Modify: `tests/unit/test_audio_manager.gd`
- Modify: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Extend: `tests/unit/test_profile_manager.gd`

**Interfaces:**

- Consumes: Task 1 ProfileManager/ProfileMigration, the existing flat `GameState.settings`, `GameState.audio_state`, `GameState.seen_endings`, and the legacy `user://input_bindings.json` shape only as migration inputs.
- Produces: `InputManager.initialize(profile: Node) -> Dictionary`, `InputManager.apply_profile_mappings(action_id: StringName = &"") -> Dictionary`, `AccessibilityManager.initialize(profile: Node) -> Dictionary`; the common `configure_mutation_gate(gate: Object) -> Dictionary` seam on InputManager, AccessibilityManager, LocalizationManager, and AudioManager; and a GameState run serializer with no permanent profile field.

- [ ] **Step 2.1: Write migration and ownership RED tests**

- [ ] Add dynamic-load-safe tests that obtain autoloads with `get_tree().root.get_node_or_null("ProfileManager")` and fail by assertion if absent. Tests MUST assert:

```text
GameState._SAVE_WHITELIST excludes settings, audio_state, and seen_endings.
GameState.reset_game leaves the complete profile byte-for-byte unchanged.
skip_unseen_text_allowed=true migrates to preferences.dialogue.skip_mode=all_text.
legacy seen_endings canonicalize and union idempotently.
legacy lavinia_priscilla maps to ending.priscilla_lavinia once.
legacy audio_state imports only preferences.audio.music_muted; live track/context IDs are discarded.
user://input_bindings.json imports once into allowlisted profile input records.
an existing committed profile preference wins over a repeated legacy import.
an otherwise-valid persisted invalid skip_mode becomes read_only once and records invalid_persisted_skip_mode_v1.
reset_gallery and reset_entire_profile retain gallery_transaction_receipts and all migration receipts.
```

- [ ] Put these named fixtures and runnable RED bodies in the existing tests before changing production ownership:

```gdscript
# tests/unit/test_game_state.gd
const PERMANENT_PROFILE_KEYS := ["settings", "audio_state", "seen_endings"]

func test_run_serializer_excludes_permanent_profile_keys() -> void:
	var run_save: Dictionary = GameState.to_save_dict()
	for key: String in PERMANENT_PROFILE_KEYS:
		assert_false(run_save.has(key), "run serializer still owns %s" % key)

func test_reset_game_does_not_change_profile() -> void:
	var profile := get_tree().root.get_node_or_null("ProfileManager")
	assert_not_null(profile)
	if profile == null:
		return
	var before: Dictionary = profile.get_profile_snapshot()
	GameState.reset_game()
	assert_eq(profile.get_profile_snapshot(), before)
```

```gdscript
# tests/unit/test_profile_manager.gd
const LEGACY_RUN_STATE := {
	"settings": {
		"language": "zh_HK", "music_volume": 0.25,
		"skip_unseen_text_allowed": true, "font_scale": 1.25,
	},
	"audio_state": {
		"music_muted": true, "current_bgm_id": "menu_theme",
		"current_ambience_id": "rain", "current_context_id": "menu",
		"current_context": {"day": 7},
	},
	"seen_endings": {
		"alone": true, "ending.priscilla.sweet": true, "lavinia_priscilla": true,
	},
}
const LEGACY_INPUT_MAPPINGS := {
	"game_quick_save": [KEY_F6],
	"not_registered": [KEY_F7],
}

func test_legacy_patch_is_exact_detached_and_discards_runtime_audio() -> void:
	var run_input: Dictionary = LEGACY_RUN_STATE.duplicate(true)
	var input_input: Dictionary = LEGACY_INPUT_MAPPINGS.duplicate(true)
	var result: Dictionary = _migration_script.call(&"prepare_legacy_patch", run_input, input_input)
	assert_true(result.get("ok", false), JSON.stringify(result))
	if not result.get("ok", false):
		return
	var patch: Dictionary = result["value"]
	assert_eq(patch["preferences"]["dialogue"]["skip_mode"], "all_text")
	assert_eq(patch["preferences"]["audio"]["music_muted"], true)
	assert_false(JSON.stringify(patch).contains("current_bgm_id"))
	assert_eq(patch["gallery_unlocks"], [
		"ending.alone", "ending.priscilla.sweet", "ending.priscilla_lavinia"])
	assert_true(patch["input_mappings"].has("game_quick_save"))
	assert_false(patch["input_mappings"].has("not_registered"))
	run_input["settings"]["font_scale"] = 99.0
	input_input["game_quick_save"].append(KEY_F8)
	assert_eq(patch["preferences"]["accessibility"]["font_scale"], 1.25)
	assert_eq((patch["input_mappings"]["game_quick_save"] as Array).size(), 1)
```

The fixture may add omitted valid legacy fields in separate table-driven cases, but it may not change these values or expected canonical IDs. Task 1 has already made `_migration_script` available through `DynamicScriptProbe`; a missing script is not acceptable Task 2 RED.

- [ ] Extend `test_application_bootstrap_profile_stage.gd` with `test_task2_owned_managers_expose_common_gate_contract`. Dynamically load and instantiate InputManager, AccessibilityManager, LocalizationManager, and AudioManager; for each, require `configure_mutation_gate`, then run the valid/same/null/missing-method/missing-signal/replacement matrix from the Global Constraints and assert no `_ready`, initialization, disk, InputMap, localization, audio-player, or signal side effect. Expected RED is the first named manager missing the method, not a parse or autoload error.

- [ ] Run the profile and GameState files:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'profile_ownership_red' -LogName 'phase2r-profile-ownership-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_game_state.gd,res://tests/unit/test_profile_manager.gd,res://tests/unit/test_input_accessibility.gd,res://tests/unit/test_audio_manager.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd','-gexit')
```

Expected RED: the current run save still contains `settings`, `audio_state`, or `seen_endings`. A missing isolated root or production legacy-input access is not acceptable RED.

- [ ] **Step 2.2: Migrate each caller before removing the old fields**

- [ ] Use this exhaustive source-to-owner map; no matched runtime caller is left for a worker to interpret:

| Current source/call | Exact replacement in this boundary | Later owner |
|---|---|---|
| `GameState._DEFAULT_SETTINGS`, `settings`, settings signals/methods, and save-whitelist entry | Remove after the rows below compile and pass; ProfileManager is the only persisted owner. | None |
| `GameState._DEFAULT_AUDIO_STATE`, `audio_state`, audio signals/methods, and save-whitelist entry | Remove; AudioManager keeps semantic live IDs in its existing private runtime fields and reads/writes only fully qualified profile audio preferences. | Task 6 replaces AudioManager internals, not ownership. |
| `GameState.seen_endings`, `record_ending_seen`, and save-whitelist entry | Remove; GalleryScene calls `ProfileManager.has_gallery_unlock("ending." + tile_id)` using canonical IDs. | Plan 04 wires EndingScene's run-scoped prepared gallery transaction. |
| `LocalizationManager.get_locale/set_locale` GameState access | Read `preferences.language`; locale writes use prepare/commit/deferred-publication, never `set_preference`. | Task 4 replaces embedded tables while preserving that profile seam. |
| `AudioManager._setting/_set_audio_state` GameState access | Map `_setting` callers to exact `preferences.audio.*` paths; delete runtime-ID persistence calls; mute preference writes go to ProfileManager. | Task 6 semantic rewrite. |
| `InputManager.INPUT_SETTINGS_PATH`, `save_input_settings`, `load_input_settings` | One root-relative import through ProfileMigration/ProfileManager, then delete the constant and both file methods; rebind/reset use `set_input_mapping`. | InputManager applies committed records only. |
| `AccessibilityManager._settings` and `StatHud` flat reads | `ProfileManager.get_preference(&"preferences.accessibility.<leaf>", default)`. | AccessibilityManager presentation only. |
| `EndingScene.gd` call to `record_ending_seen` | Remove it now and add a negative source-contract assertion. Do **not** invent an immediate transaction ID; Plan 04 owns `ending:<run_id>:gallery:<ending_id>`. | Explicit planned blocker until Plan 04. |
| Existing audio/input/accessibility tests | Replace assertions against GameState/file JSON with ProfileManager snapshot plus committed-notification assertions. | Same test files. |

Plan 02's development readiness never claims ending playback readiness, so the explicit EndingScene blocker is permitted; an ad-hoc `unlock_ending()` call here is not. The Task 2 commit may proceed only after the runtime scan below is empty. Tests may contain legacy fixture strings and negative assertions.

- [ ] Add the exact common mutation-gate configuration method and private retained gate field to InputManager, AccessibilityManager, LocalizationManager, and AudioManager in this task. Use the frozen result shapes/codes from Global Constraints byte-for-byte; configuration remains valid before initialization, same-instance repetition is idempotent, and a different instance can never replace it. No manager calls another manager, connects the gate signal, or applies live state during configuration. The Task 4 LocalizationManager rewrite and Task 6 AudioManager rewrite must retain the already configured instance and method unchanged.

```gdscript
# autoload/InputManager.gd
func configure_mutation_gate(gate: Object) -> Dictionary

# autoload/AccessibilityManager.gd
func configure_mutation_gate(gate: Object) -> Dictionary

# autoload/LocalizationManager.gd
func configure_mutation_gate(gate: Object) -> Dictionary

# autoload/AudioManager.gd
func configure_mutation_gate(gate: Object) -> Dictionary
```

- [ ] Apply this complete legacy flat-setting map; any current legacy setting key not in the table fails with `unknown_legacy_profile_key` rather than being silently dropped:

| Legacy key(s) | Profile leaf |
|---|---|
| `language` | `preferences.language` |
| `music_volume`, `voice_volume`, `sfx_volume`, `ambience_volume`, `mute_audio_on_focus_loss` | same leaf under `preferences.audio` |
| `text_speed`, `auto_text_speed`, `auto_advance_dialogue` | same leaf under `preferences.dialogue` |
| `skip_unseen_text_allowed` | `preferences.dialogue.skip_mode` (`true→all_text`, `false→read_only`) |
| `fullscreen` | `preferences.display.fullscreen` |
| `font_scale`, `high_contrast`, `reduced_motion`, `screen_shake_strength`, `large_click_targets`, `hold_to_confirm`, `colorblind_mode`, `show_focus_ring`, `controller_cursor_enabled`, `subtitles_enabled`, `captions_enabled`, `subtitle_speaker_names`, `subtitle_background_opacity`, `text_box_opacity`, `visual_audio_cues`, `flashing_effects_enabled`, `tutorial_replay_available`, `pause_on_focus_loss` | same leaf under `preferences.accessibility` |
| `audio_state.music_muted` | `preferences.audio.music_muted` |
| `audio_state.current_bgm_id/current_ambience_id/current_context_id/current_context` | validate their legacy types, then deliberately discard as non-profile runtime state |

- [ ] `ProfileMigration.prepare_legacy_patch()` maps current flat settings field-for-field into nested profile preferences; missing values come from a detached `ProfileSchema.make_defaults()`, never current live state. `skip_unseen_text_allowed` maps exactly to `preferences.dialogue.skip_mode`, legacy `audio_state` imports only `preferences.audio.music_muted`, and track/context IDs are discarded. Mutating either legacy input after preparation cannot alter the patch.
- [ ] If no profile file exists, the initial import may seed legacy preferences and input mappings. If a valid profile already exists, its committed preferences/mappings win; the matching migration receipt is committed without overwriting them. Physically recorded legacy gallery IDs are canonicalized and unioned once. `lavinia_priscilla` maps to `ending.priscilla_lavinia`; every unregistered ending ID rejects the patch.
- [ ] Import ordering is exact: initialize/reconcile the current profile; if the selected root contains legacy `input_bindings.json` and `legacy_input_bindings_v1=false`, strict-parse the legacy shape `{registered_action_id:Array[int physical_keycode]}`, ignore unregistered action IDs, reject a malformed registered action atomically, convert each code to `{"kind":"key","physical_keycode":code,"keycode":0,"shift":false,"alt":false,"ctrl":false,"meta":false}`, and commit the mappings plus receipt in one profile write. A valid existing profile mapping wins per action. Leave the legacy source inert and untouched; the durable receipt prevents a second import, so no uncontracted rename/delete API is invented. On slot migration, plan 03 passes detached `legacy_run_state` into `prepare_legacy_profile_patch`; existing preferences/mappings win, canonical gallery IDs union, and `legacy_game_state_profile_v1` is committed in the same write. A receipt that is already true makes the corresponding import a detached no-op. No code opens literal production `user://` in tests.
- [ ] `InputManager` converts only the Task 1 key/joypad records to `InputEvent` instances, writes changes through `ProfileManager.set_input_mapping()`, and applies only committed `input_mappings_changed` notifications. Delete direct read/write ownership of `user://input_bindings.json` only after the one-time import test passes.
- [ ] `AccessibilityManager` and `StatHud` read committed nested accessibility paths. Notification handlers update presentation only; they never call a ProfileManager mutation.
- [ ] `GalleryScene` uses `has_gallery_unlock()` with canonical ending IDs and does not retain a second unlock cache.
- [ ] Move GameState reset/startup work and InputManager signal/default-map setup out of `_ready()` into their explicit bootstrap initializers; their `_ready()` bodies become no-ops. Plan 03 supplies GameState's final run initializer, while Task 6 supplies InputManager's bootstrap call.
- [ ] Remove GameState permanent-state variables, default constants, signals, getters/setters, save-whitelist entries, and serialization only after the exact runtime-only scan below returns exit code 1/no matches. Then run the fixture scan separately and inspect every allowed test match; do not weaken the production regex.

- [ ] Run:

```powershell
$directCalls = @(rg -n '(GameState|gs)\.(settings|audio_state|seen_endings)|get\("settings"\)|get_audio_state|set_audio_state|record_ending_seen' autoload scripts scenes --glob '*.gd')
$directExit = $LASTEXITCODE
$gameStateOwners = @(rg -n '_DEFAULT_SETTINGS|_DEFAULT_AUDIO_STATE|signal (settings_changed|language_changed|accessibility_settings_changed|input_settings_changed|audio_state_changed)|var (settings|audio_state|seen_endings):|"settings", "audio_state", "seen_endings"|func (set_setting|set_language|record_ending_seen|set_audio_state_value|get_audio_state_value|get_audio_state_save_dict|apply_audio_state_save_dict)' autoload/GameState.gd)
$ownerExit = $LASTEXITCODE
$legacyInputOwner = @(rg -n 'user://input_bindings\.json|INPUT_SETTINGS_PATH|func (save_input_settings|load_input_settings)' autoload/InputManager.gd)
$inputExit = $LASTEXITCODE
if ($directExit -notin 0,1 -or $ownerExit -notin 0,1 -or $inputExit -notin 0,1) { throw 'Caller scan failed.' }
$runtimeMatches = @($directCalls) + @($gameStateOwners) + @($legacyInputOwner)
if ($runtimeMatches.Count -ne 0) { $runtimeMatches; throw 'Permanent profile caller remains.' }
rg -n 'settings|audio_state|seen_endings|input_bindings\.json' tests --glob '*.gd'
```

Expected runtime matches after migration: exactly zero. Test matches are limited to the named `LEGACY_*` fixtures and negative ownership assertions and must be inspected, not globally allowlisted.

- [ ] **Step 2.3: Verify the broader ownership seam**

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'profile_ownership_green' -LogName 'phase2r-profile-ownership-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_profile_manager.gd,res://tests/unit/test_game_state.gd,res://tests/unit/test_input_accessibility.gd,res://tests/unit/test_audio_manager.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd','-gexit')
```

Expected GREEN: no permanent state returns to GameState after New Game or run serialization; legacy imports are one-shot and isolated; InputManager and AccessibilityManager apply committed notifications without mutating from callbacks.

- [ ] **Step 2.4: Proposed path-specific commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'scripts/profile/ProfileMigration.gd'='M'
  'autoload/GameState.gd'='M'
  'autoload/InputManager.gd'='M'
  'autoload/AccessibilityManager.gd'='M'
  'autoload/LocalizationManager.gd'='M'
  'autoload/AudioManager.gd'='M'
  'scripts/ui/StatHud.gd'='M'
  'scripts/ui/GalleryScene.gd'='M'
  'scripts/ui/EndingScene.gd'='M'
  'tests/unit/test_game_state.gd'='M'
  'tests/unit/test_input_accessibility.gd'='M'
  'tests/unit/test_audio_manager.gd'='M'
  'tests/unit/test_application_bootstrap_profile_stage.gd'='M'
  'tests/unit/test_profile_manager.gd'='M'
}
$optionalUids = [ordered]@{}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Plan 02 Task 2 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'refactor(profile): remove permanent state from GameState'
if ($LASTEXITCODE -ne 0) { throw 'Exact Plan 02 Task 2 commit boundary failed.' }
~~~

## Task 3: Add localization schema validation and prove exact extraction

**Files:**

- Create: `scripts/validation/JsonSchemaValidator.gd`
- Create: `scripts/localization/LocalizationSchema.gd`
- Create: `schemas/localization/manifest.schema.json`
- Create: `schemas/localization/ui-locale.schema.json`
- Create: `localization/manifest.json`
- Create: `localization/ui/en.json`
- Create: `localization/ui/zh_CN.json`
- Create: `localization/ui/zh_HK.json`
- Create: `tools/localization/ExtractLegacyLocalization.gd`
- Create: `tools/localization/ValidateLocalizationCatalogs.gd`
- Modify: `tests/unit/test_strict_json.gd`
- Create: `tests/unit/test_localization_extraction.gd`
- Generate once: `evidence/phase_2r/localization/legacy_subset_fingerprint.json`
- Generate/update: `evidence/phase_2r/localization/full_catalog_validation.json`

**Interfaces:**

- Consumes: Task 1 `StrictJson`, `CanonicalJsonWriter`, and `DynamicScriptProbe`; the current dynamically loaded `autoload/LocalizationManager.gd` embedded tables as a temporary extraction oracle; strict primitive-only JSON rules.
- Produces: JSON-Schema and localization semantic validators, canonical manifest/catalog files, an immutable `50/25/25` legacy-subset fingerprint, and independently replaceable full-catalog validation evidence.

- [ ] **Step 3.1: Write strict-parser and semantic-validation RED tests**

- [ ] Use `DynamicScriptProbe` for every not-yet-created script so RED reaches assertions instead of parse failure. Test these exact interfaces:

```gdscript
# JsonSchemaValidator.gd
static func validate(value: Variant, schema: Dictionary) -> Dictionary

# LocalizationSchema.gd
static func validate_manifest(manifest: Dictionary, base_path: String) -> Dictionary
static func validate_locale_file(catalog: Dictionary, expected_locale: String) -> Dictionary
static func extract_named_placeholders(text: String) -> PackedStringArray
static func validate_bundle(manifest: Dictionary, catalogs: Dictionary) -> Dictionary
static func build_legacy_subset_records(tables: Dictionary) -> Dictionary
static func fingerprint_records(records: Array[Dictionary]) -> String
```

Task 1 already proves strict duplicate rejection and canonical output. Extend `test_strict_json.gd` only with JSON-Schema integration cases proving schema files are themselves strict-parsed and generated evidence is written through `CanonicalJsonWriter`.

- [ ] Required RED cases are duplicate object key, duplicate message/locale/alias/font ID, absolute path, URI scheme, drive prefix, parent traversal, normalized escape, locale fallback cycle, font fallback cycle, wrong locale file ID, missing/duplicate source locale, wrong source fallback, fallback not terminating at source, and placeholder-set mismatch.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localization_schema_red' -LogName 'phase2r-localization-schema-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_strict_json.gd,res://tests/unit/test_localization_extraction.gd','-gexit')
```

Expected RED: `missing_script` for `JsonSchemaValidator.gd`; no catalog is written and the current embedded manager remains unchanged.

- [ ] **Step 3.2: Create the exact initial manifest**

- [ ] Write:

```json
{
  "schema_version": 1,
  "source_locale": "en",
  "aliases": [{"input": "zh_hk", "locale": "zh_HK"}],
  "font_profiles": [
    {"id": "project_default", "font_files": [], "fallback_profile": null}
  ],
  "locales": [
    {"id": "en", "native_name": "English", "fallback_locale": null, "release_status": "source", "selectable": true, "ui_file": "ui/en.json", "font_profile": "project_default", "layout_direction": "ltr"},
    {"id": "zh_CN", "native_name": "简体中文", "fallback_locale": "en", "release_status": "draft", "selectable": true, "ui_file": "ui/zh_CN.json", "font_profile": "project_default", "layout_direction": "ltr"},
    {"id": "zh_HK", "native_name": "繁體中文", "fallback_locale": "en", "release_status": "draft", "selectable": true, "ui_file": "ui/zh_HK.json", "font_profile": "project_default", "layout_direction": "ltr"}
  ]
}
```

Paths resolve only as registered descendants of `res://localization/`; font files resolve only under `res://localization/fonts/`. Empty `font_files` means the project default font.

- [ ] **Step 3.3: Extract and freeze the immutable legacy subset before deleting tables**

- [ ] `ExtractLegacyLocalization.gd` dynamically loads the current manager script by path, instantiates it off-tree, calls `_build_tables()`, reads `_tables`, and rejects unless its locale/key counts are exactly `en=50`, `zh_CN=25`, and `zh_HK=25`. It never reads the replacement catalogs as its oracle.

- [ ] Materialize generated ending titles and all other records into catalogs with shape:

```json
{
  "schema_version": 1,
  "locale": "en",
  "messages": [{"id": "button.close", "text": "Close"}]
}
```

Every catalog and evidence file is serialized only with Task 1's `CanonicalJsonWriter`; validation re-reads it with `StrictJson` and compares the detached parsed value. Extraction and validation helpers deep-copy embedded-table inputs and returned record arrays so sorting/fingerprinting cannot reorder the oracle or catalog in memory.

- [ ] `test_localization_extraction.gd` compares every ID and exact string against the live embedded tables, not just counts. The twelve generated ending-title strings become twelve literal `en.json` records with the exact generated legacy values.

- [ ] Freeze `legacy_subset_fingerprint.json` using this unambiguous byte algorithm: sort records by locale UTF-8 bytes, then message ID UTF-8 bytes; for each record append `locale UTF-8`, one zero byte, `id UTF-8`, one zero byte, `text UTF-8`, and one zero byte; SHA-256 the concatenation. The evidence stores the three ordered `[{"id":String,"text":String}]` lists, counts `50/25/25`, the combined lowercase SHA-256, and the oracle file's SHA-256. `--ensure-fingerprint` creates it only when absent; when present it verifies exact equivalence and leaves its bytes and modification time unchanged.

- [ ] Generate `full_catalog_validation.json` separately. It records current complete counts, per-file byte hashes, fallback coverage, and placeholder validation. Task 5 may update this file when it adds ordinary UI keys, but it must continue validating every frozen subset record and must never modify `legacy_subset_fingerprint.json`.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localization_extract' -LogName 'phase2r-localization-extraction.log' -GodotArgs @('-s','res://tools/localization/ExtractLegacyLocalization.gd','--','--ensure-fingerprint') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localization_extract_tests' -LogName 'phase2r-localization-extraction-tests.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_strict_json.gd,res://tests/unit/test_localization_extraction.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localization_catalog_validate' -LogName 'phase2r-localization-catalog-validation.log' -GodotArgs @('-s','res://tools/localization/ValidateLocalizationCatalogs.gd') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
```

Expected GREEN: exact `50/25/25` key/value equivalence, one immutable subset fingerprint, separate complete-catalog evidence, and every invalid fixture rejected.

- [ ] **Step 3.4: Convert the temporary oracle to a permanent regression check**

- [ ] Before Task 4 removes `_tables`, run the extraction comparison one final time. Then change `test_localization_extraction.gd` to validate catalog records against the checked-in immutable subset evidence. The permanent test rejects any changed/missing legacy record but permits additional full-catalog keys.

- [ ] Do not retain a second GDScript translation table or copy the old manager into a fixture. The fingerprint evidence plus literal catalogs are the only retained extraction oracle.

- [ ] **Step 3.5: Proposed path-specific commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'scripts/validation/JsonSchemaValidator.gd'='A'
  'scripts/localization/LocalizationSchema.gd'='A'
  'schemas/localization/manifest.schema.json'='A'
  'schemas/localization/ui-locale.schema.json'='A'
  'localization/manifest.json'='A'
  'localization/ui/en.json'='A'
  'localization/ui/zh_CN.json'='A'
  'localization/ui/zh_HK.json'='A'
  'tools/localization/ExtractLegacyLocalization.gd'='A'
  'tools/localization/ValidateLocalizationCatalogs.gd'='A'
  'tests/unit/test_localization_extraction.gd'='A'
  'evidence/phase_2r/localization/legacy_subset_fingerprint.json'='A'
  'evidence/phase_2r/localization/full_catalog_validation.json'='A'
  'tests/unit/test_strict_json.gd'='M'
}
$optionalUids = [ordered]@{
  'scripts/validation/JsonSchemaValidator.gd.uid'='A'
  'scripts/localization/LocalizationSchema.gd.uid'='A'
  'tools/localization/ExtractLegacyLocalization.gd.uid'='A'
  'tools/localization/ValidateLocalizationCatalogs.gd.uid'='A'
  'tests/unit/test_localization_extraction.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Plan 02 Task 3 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'feat(localization): extract strict custom JSON catalogs'
if ($LASTEXITCODE -ne 0) { throw 'Exact Plan 02 Task 3 commit boundary failed.' }
~~~

## Task 4: Rewrite LocalizationManager as an atomic custom-JSON coordinator

**Files:**

- Create: `scripts/localization/LocalizationCatalog.gd`
- Modify: `autoload/LocalizationManager.gd`
- Modify: `tests/unit/test_localization.gd`
- Modify: `tests/unit/test_localization_extraction.gd`

**Interfaces:**

- Consumes: Task 1 ProfileManager deferred-publication APIs; Task 3 strict manifest/catalog validation and immutable subset evidence; registered `LocalePresentationRoot` instances through the interface below.
- Produces: an immutable validated locale bundle, explicit readiness/pending registration, atomic `set_locale()`, presentation-root registration and rollback, silent restore APIs for plan 03, alias/fallback lookup, one post-commit `locale_changed` signal, and the unchanged common mutation-gate configuration seam introduced in Task 2.

- [ ] **Step 4.1: Convert extraction evidence into permanent regression tests**

- [ ] Before removing `_build_tables()`, run Task 3's oracle comparison. Then make the permanent test verify every checked-in subset record and the exact combined SHA-256 from `legacy_subset_fingerprint.json`; additions are permitted only in the separately validated full catalog.

- [ ] Add RED tests for `zh_hk -> zh_HK`, unknown alias rejection, registered English fallback, `[missing:key]`, `[format_error:key]`, exact runtime parameter sets, one warning per key, visible selectable-draft status, duplicate registration, root registration before initialization, pending-root removal, pending-root failure during initialization, ready-time registration, failed-manager registration rejection, root prepare/apply failure rollback, profile-write failure rollback, deferred profile-signal publication, silent restore/rollback, no-alias bundle/root plans, a removed stored locale, and preservation of the Task 2 mutation-gate object/instance ID through the rewrite.

- [ ] Run before implementation:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localization_coordinator_red' -LogName 'phase2r-localization-coordinator-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_localization.gd,res://tests/unit/test_localization_extraction.gd','-gexit')
```

Expected RED: the existing manager has no manifest-backed `initialize(profile, manifest_path)`, no prepared bundle, and no rollback API. The immutable subset test must already remain GREEN.

- [ ] **Step 4.2: Implement the coordinator interface**

- [ ] Implement these exact methods and retain no alternate public locale setter:

```gdscript
signal locale_changed(locale_id: String)

func configure_mutation_gate(gate: Object) -> Dictionary
func initialize(profile: Node, manifest_path: String = "res://localization/manifest.json") -> Dictionary
func get_readiness() -> StringName
func get_locale() -> String
func get_selectable_locales() -> Array[Dictionary]
func set_locale(locale_input: String) -> Dictionary
func has_key(key: String) -> bool
func t(key: String, params: Dictionary = {}) -> String
func get_presentation_profile() -> Dictionary
func register_presentation_root(root: Node) -> Dictionary
func unregister_presentation_root(root: Node) -> Dictionary
func prepare_locale(locale_input: String) -> Dictionary
func capture_restore_state() -> Dictionary
func apply_restore_silent(plan: Dictionary) -> Dictionary
func rollback_restore_silent(backup: Dictionary) -> Dictionary
func finalize_restore() -> Dictionary
```

The rewrite retains Task 2's private gate field and exact configure result/failure behavior. It neither clears nor replaces the gate during initialization, locale changes, restore finalize, or profile reset; `test_localization.gd` configures before `initialize()` and proves the same gate instance ID afterward.

`get_readiness()` returns exactly `uninitialized`, `initializing`, `ready`, or `failed`. `prepare_locale()` is callable only in `initializing` or `ready`; it resolves exact canonical ID then explicit alias, strict-loads every catalog in its fallback chain, validates schemas/placeholders/font/layout, asks every live registered presentation root to prepare a detached plan, and returns a recursively duplicated Dictionary. It does not mutate the live bundle, presentation, profile, root, input parameters, or signal count. Unregistered input fails.

The prepared shape is exact:

```gdscript
{
	"canonical_locale_id": String,
	"bundle": Dictionary,
	"presentation_profile": Dictionary,
	"root_plans": Array[Dictionary],
	"profile_candidate": Dictionary,
}
```

`bundle` contains only manifest-registered locale records and message dictionaries for the candidate fallback chain. Lookup follows that validated chain to source without cycles. Runtime parameter keys must exactly equal the source message's named placeholder set.

- [ ] `set_locale()` performs this atomic sequence:

```text
prepare_locale(locale_input), including ProfileManager.prepare_locale_preference(canonical_id)
capture LocalizationManager state and every registered root state
apply every already-prepared root plan silently; roll back prior roots on failure
ProfileManager.commit_prepared_profile(profile_candidate, true)
if persistence fails, roll every root back and preserve the old live bundle/profile
swap the already-validated bundle and presentation profile by non-failing assignment
ProfileManager.publish_deferred_profile_signals(publication_id) exactly once
emit locale_changed(canonical_id) exactly once
```

There is no fallible work after the profile commit: bundle swap is reference assignment and the manager owns the valid publication ID. Tests connect observers to both signals and assert no observer can see a profile language that disagrees with the active bundle. Any precommit failure preserves old locale, roots, profile bytes, warning state, and signal counts.

- [ ] On initialization, strict-load and validate the manifest plus source bundle before consulting the profile. If the stored language resolves, switch to its canonical ID. If it is an alias, canonicalize and persist it. If its manifest record was removed or is unknown, atomically switch and persist `source_locale`; a profile write failure fails bootstrap and does not keep an in-memory-only fallback.

- [ ] Connect once to committed `preference_changed` notifications during initialization. During a locale transaction, ignore the manager's own matching deferred `&"preferences.language"` notification only after asserting it equals the active bundle; external observers still receive it. A reset's changed-leaf `preferences.language` notification applies the already validated source bundle/presentation without parsing disk or performing a second profile write, then emits one `locale_changed` only when locale/presentation changed. `profile_reset` is a summary notification and does not trigger a duplicate apply.

- [ ] For SaveManager participation, `capture_restore_state()` captures runtime bundle/presentation/root backups. `apply_restore_silent(plan)` accepts only a plan produced by `prepare_locale()` for the already prepared profile language, applies roots, and swaps the bundle without persistence or locale/profile signals. `rollback_restore_silent()` restores roots and bundle in reverse order. `finalize_restore()` only discards the backup; it emits no domain signal because SaveManager owns the sole aggregate `run_restored` notification.

- [ ] Remove `_SUPPORTED`, `_tables`, `_build_tables()`, recursive `refresh_tree()`, and GameState language access only after all tests pass.

- [ ] **Step 4.3: Freeze the presentation registration contract**

- [ ] Task 5's `LocalePresentationRoot` must satisfy this duck-typed interface; Task 4 tests use a fake with the same signatures:

```gdscript
func prepare_presentation(profile: Dictionary) -> Dictionary
func capture_presentation_state() -> Dictionary
func apply_presentation_silent(plan: Dictionary) -> Dictionary
func rollback_presentation_silent(backup: Dictionary) -> Dictionary
func finalize_presentation() -> Dictionary
```

Registration rejects a freed/nonconforming node, is idempotent for the same instance, stores only runtime `WeakRef`s, and never aliases a root-owned plan. In `uninitialized` or `initializing`, it queues the WeakRef and returns success with code `pending_registration` without applying presentation; unregister removes it from both pending and active sets. `initialize()` changes to `initializing`, validates the manifest/source/profile candidate, snapshots all still-live pending roots in instance-ID order, prepares and applies every root inside the same startup transaction, and changes to `ready` only after the bundle/profile/presentation commit succeeds. A pending-root failure rolls back prior roots, changes readiness to `failed`, and fails bootstrap. In `ready`, registration prepares/applies the current presentation before returning, so a newly entered scene never flashes a stale font/layout. In `failed`, registration rejects with `localization_failed`. Roots unregister on tree exit, and every operation prunes invalid WeakRefs.

- [ ] Alias tests mutate a returned selectable-locale record, bundle, presentation profile, root plan, restore backup, and `locale_changed` observer-owned data immediately after receipt. Later lookups, rollback, other roots, and profile candidates remain unchanged.

- [ ] **Step 4.4: Prove no TranslationServer or embedded-table dependency**

- [ ] Run:

```powershell
rg -n 'TranslationServer|_SUPPORTED|_build_tables|var _tables|refresh_tree' autoload/LocalizationManager.gd scripts/localization
```

Expected exit code: 1/no matches.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localization_coordinator_green' -LogName 'phase2r-localization-coordinator-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_localization.gd,res://tests/unit/test_localization_extraction.gd','-gexit')
```

Expected GREEN: manifest lookup, aliases/fallback/formatting, atomic profile/root/bundle publication, removed-locale source fallback, silent restore/rollback, immutable subset verification, and no mutation on invalid input.

- [ ] **Step 4.5: Proposed path-specific commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'scripts/localization/LocalizationCatalog.gd'='A'
  'autoload/LocalizationManager.gd'='M'
  'tests/unit/test_localization.gd'='M'
  'tests/unit/test_localization_extraction.gd'='M'
}
$optionalUids = [ordered]@{
  'scripts/localization/LocalizationCatalog.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Plan 02 Task 4 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'refactor(localization): load locales atomically from manifest JSON'
if ($LASTEXITCODE -ne 0) { throw 'Exact Plan 02 Task 4 commit boundary failed.' }
~~~

## Task 5: Bind UI text, font/layout presentation, and settings

**Files:**

- Create: `scripts/ui/LocalizedBinding.gd`
- Create: `scripts/ui/LocalePresentationRoot.gd`
- Create: `scripts/ui/SettingsPanelController.gd`
- Create: `tools/localization/UiLiteralAudit.gd`
- Create: `tests/unit/test_localized_binding.gd`
- Create: `tests/scene/test_settings_localization_scene.gd`
- Create: `tests/integration/ProjectStartupLocalizationHarness.gd`
- Create: `tests/integration/ProjectStartupLocalizationHarness.tscn`
- Generate: `evidence/phase_2r/localization/ui_literal_disposition.json`
- Generate: `evidence/phase_2r/localization/script_ui_disposition.json`
- Modify: `evidence/phase_2r/localization/full_catalog_validation.json`
- Modify: `localization/ui/en.json`
- Modify: `localization/ui/zh_CN.json`
- Modify: `localization/ui/zh_HK.json`
- Modify: `scripts/ui/Setting.gd`
- Modify: `scripts/ui/SettingsApp.gd`
- Modify: `scenes/menu/Setting.tscn`
- Modify: `scenes/apps/SettingsApp.tscn`
- Modify localized scene roots listed below
- Delete after zero consumers: `scripts/ui/LocalizedText.gd`
- Delete after zero consumers: `scripts/ui/LocalizedText.gd.uid`

**Interfaces:**

- Consumes: Task 4 `LocalizationManager` lookup, registration, and atomic-switch APIs; Task 1 ProfileManager preference/reset methods; the immutable legacy-subset fingerprint from Task 3.
- Produces: one `LocalizedBinding` automatic text component; one transactional `LocalePresentationRoot` per localized top-level scene; one shared Settings controller; complete scene/script UI-string disposition reports; and an on-tree startup test proving pending roots become ready without a stale frame.

- [ ] **Step 5.1: Write RED component tests**

- [ ] Dynamically load absent component scripts and use these exact interfaces:

```gdscript
# LocalizedBinding.gd
@export var target_path: NodePath = NodePath("..")
@export_enum("text", "placeholder_text", "tooltip_text", "accessibility_name")
var target_property: String = "text"
@export var key: String = ""
@export var parameters: Dictionary = {}
func set_parameters(value: Dictionary) -> Dictionary
func refresh() -> Dictionary

# LocalePresentationRoot.gd
@export var target_path: NodePath = NodePath("..")
func prepare_presentation(profile: Dictionary) -> Dictionary
func capture_presentation_state() -> Dictionary
func apply_presentation_silent(plan: Dictionary) -> Dictionary
func rollback_presentation_silent(backup: Dictionary) -> Dictionary
func finalize_presentation() -> Dictionary

# SettingsPanelController.gd
func bind(host: Node, language_option: OptionButton, language_status: Label, accessibility_container: VBoxContainer, audio_container: VBoxContainer) -> Dictionary
func unbind() -> Dictionary
```

Tests prove ready refresh, committed parameter-change refresh, one locale-change refresh, all four target properties including `accessibility_name`, invalid target/property/key rejection, no recursive tree walk, and recursive copies of exported parameters/setter inputs. Presentation tests prove pending/ready registration, prepare without mutation, capture, silent apply, reverse rollback, finalize, duplicate registration idempotence, invalid/freed target rejection, no child traversal, and no alias between root plans/backups/live Theme state.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localized_ui_red' -LogName 'phase2r-localized-ui-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_localized_binding.gd,res://tests/scene/test_settings_localization_scene.gd','-gexit')
```

Expected RED: `LocalizedBinding.gd` or `LocalePresentationRoot.gd` reports `missing_script`; no scene parse error is acceptable.

- [ ] **Step 5.2: Implement binding and transactional presentation**

- [ ] `LocalizedBinding._ready()` validates the target/property/key, connects exactly once to `locale_changed`, then calls `refresh()`. `set_parameters()` recursively duplicates input, validates exact source placeholders, stores another detached copy, and refreshes. `refresh()` performs one `LocalizationManager.t()` call and `target.set(target_property, value)`; it never walks children or calls a guessed method.

- [ ] `LocalePresentationRoot._ready()` resolves its target `Control` and registers itself. `_exit_tree()` unregisters. `prepare_presentation()` resolves only manifest-registered font files, builds a detached inherited Theme override and exact `Control.LayoutDirection` value, and changes no live property. `capture_presentation_state()` captures the target's current theme/layout in runtime memory. Silent apply assigns only that target's inherited theme/layout; rollback restores the captured values; finalize discards the backup. None of these Dictionaries is serialized.

- [ ] **Step 5.3: Add one presentation root to each localized top-level scene**

- [ ] Modify these scene files, not their user-dirty unrelated scripts:

```text
scenes/menu/MenuScene.tscn
scenes/menu/GalleryScene.tscn
scenes/menu/Setting.tscn
scenes/opening/OpeningScene.tscn
scenes/main/MainGameScene.tscn
scenes/desktop/ComputerDesktop.tscn
scenes/apps/BackupApp.tscn
scenes/apps/ContactListApp.tscn
scenes/apps/LogOutApp.tscn
scenes/apps/MinesweeperApp.tscn
scenes/apps/ScheduleApp.tscn
scenes/apps/SettingsApp.tscn
scenes/apps/ShopApp.tscn
scenes/dating/DatingScene.tscn
scenes/dating/MinesweeperChallengeOverlay.tscn
scenes/hospital/HospitalScene.tscn
scenes/ending/EndingScene.tscn
scenes/overlay/TutorialOverlay.tscn
```

Each root applies only the resolved font chain and `layout_direction` through inherited Control properties. It never searches descendants or guesses method names.

- [ ] **Step 5.4: Audit and migrate literal UI strings**

- [ ] `UiLiteralAudit` scans `.tscn` `text`, `placeholder_text`, `tooltip_text`, and `accessibility_name` properties into `ui_literal_disposition.json`. It also scans project `.gd` files (excluding addons/tests/generated evidence) for literal or formatted strings flowing to `.text`, `.placeholder_text`, `.tooltip_text`, `.accessibility_name`, `.dialog_text`, `set_text`, `add_item`, `set_item_text`, and notification/dialog helpers, and writes `script_ui_disposition.json` with exact `source_path`, `line`, `sink`, `source_expression`, disposition, key/reason. Every record has exactly one `localized_binding`, `localized_call`, `runtime_data`, `decorative`, or `narrative_owned_by_dialogic` disposition; duplicate locations, missing sources, stale line hashes, or unclassified UI sinks fail.
- [ ] Add ordinary locale messages only after the immutable `50/25/25` evidence exists. Preserve each existing literal exactly as the new English source value; do not invent narrative prose or Chinese translations. Missing Chinese additions fall back to English and increase the reported incomplete count.
- [ ] Add `LocalizedBinding` children for every `localized_binding` record. Dynamic presenters may call `LocalizationManager.t()` directly with validated parameters.
- [ ] Regenerate only `full_catalog_validation.json`; run the immutable subset validator before and after and assert its bytes and hash are unchanged. The audit fails if a new unclassified literal appears.

- [ ] Run the literal and catalog validators:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui_literal_audit' -LogName 'phase2r-ui-literal-audit.log' -GodotArgs @('-s','res://tools/localization/UiLiteralAudit.gd') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui_catalog_validate' -LogName 'phase2r-ui-catalog-validation.log' -GodotArgs @('-s','res://tools/localization/ValidateLocalizationCatalogs.gd') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
```

Expected GREEN: every literal has one disposition, the full-catalog evidence reflects added English keys/fallback gaps, and the legacy subset fingerprint is byte-identical.

- [ ] **Step 5.5: Wire settings and safe resets**

- [ ] Add English source key `locale.release_status.draft` with exact text `{native_name} [draft]`. Preserve Chinese files without invented translations so they fall back to English and count as incomplete. Populate languages from `get_selectable_locales()` and render a draft record only through `LocalizationManager.t("locale.release_status.draft", {"native_name": native_name})`; the literal `"%s [draft]"` and hardcoded `[draft]` suffix are forbidden by the script audit.
- [ ] Expose exactly `read_only` and `all_text` for skip mode and commit immediately through `&"preferences.dialogue.skip_mode"`.
- [ ] Add independent preference, visited-history, gallery, and entire-profile reset controls. Each opens a confirmation dialog and invokes only its matching method after confirmation.
- [ ] Wire audio, dialogue, display, and accessibility controls through the shared controller so Menu Settings and desktop Settings use identical fully qualified `preferences.*` paths. Language controls call only `LocalizationManager.set_locale()`; direct ProfileManager `preferences.language` writes remain impossible.
- [ ] Reset callbacks render results only. The post-commit profile signals update LocalizationManager, AudioManager, InputManager, AccessibilityManager, and DialogicBridge; a UI notification handler never performs a second domain mutation.

- [ ] **Step 5.6: Remove the inert stub and verify on-tree behavior**

- [ ] `ProjectStartupLocalizationHarness.tscn` instances the real `scenes/menu/MenuScene.tscn`; its script records the frame in `_ready()`, observes the real project autoloads, and exits nonzero on assertion failure. Its `_enter_tree()` is exactly the pre-deferred-start factory installation window:

```gdscript
const FAKE_APPLICATION_MUTATION_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")

func _enter_tree() -> void:
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	if bootstrap == null or not bootstrap.has_method("configure_debug_mutation_gate_factory"):
		push_error("ProjectStartupLocalizationHarness: missing debug gate factory seam")
		get_tree().quit(1)
		return
	var result: Dictionary = bootstrap.configure_debug_mutation_gate_factory(
		Callable(self, "_create_debug_mutation_gate")
	)
	if not result.get("ok", false):
		push_error("ProjectStartupLocalizationHarness: gate factory rejected: %s" % JSON.stringify(result))
		get_tree().quit(1)
		return

func _create_debug_mutation_gate() -> Object:
	return FAKE_APPLICATION_MUTATION_GATE.new()
```

The harness never invokes the factory itself. Under `profile_localization_development`, the deferred gate stage invokes it exactly once and the harness asserts the copied startup-state `gate_injection` record is exactly the ordered `ProfileManager`, `LocalizationManager`, `InputManager`, `AccessibilityManager` target list, has four identical target instance IDs equal to the one nonzero gate ID, and contains no `SaveManager`, `GameState`, `SceneRouter`, `AudioManager`, or `DialogicBridge` call. It also proves the menu root registered while LocalizationManager was `uninitialized`, ApplicationBootstrap emitted only `development_subset_ready`, LocalizationManager reached `ready`, the pending root drained and had source font/layout in the same process frame before rendering, alias switch `zh_hk` committed `zh_HK` once, no fatal/project diagnostic or production-path access occurred, and freeing the menu pruned the WeakRef. The script defines the six-target expected list as the same four names followed by `AudioManager`, `DialogicBridge` so Task 6 can rerun this real startup scene under `profile_locale_audio_development` without changing the factory seam. This launches a real scene with real autoload startup, not a fake-root unit substitute.

- [ ] Run:

```powershell
rg -n 'LocalizedText|refresh_localized_text' autoload scripts scenes tests
```

After migrating tests/callers, delete `LocalizedText.gd` and its UID. Expected remaining matches: none.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'localized_ui_green' -LogName 'phase2r-localized-ui-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_localized_binding.gd,res://tests/scene/test_settings_localization_scene.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'project_startup_localization' -LogName 'phase2r-project-startup-localization.log' -GodotArgs @('res://tests/integration/ProjectStartupLocalizationHarness.tscn','--','--phase2r-bootstrap-mode=profile_localization_development')
```

Expected GREEN: both Settings scenes and the real Menu enter the tree; pending presentation registers before readiness and applies before the first rendered frame; selectors populate; a locale transaction refreshes once; rollback restores presentation; every reset requires confirmation; all roots are pruned; the development subset emits no false fatal/project diagnostic.

- [ ] **Step 5.7: Proposed path-specific commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'scripts/ui/LocalizedBinding.gd'='A'
  'scripts/ui/LocalePresentationRoot.gd'='A'
  'scripts/ui/SettingsPanelController.gd'='A'
  'tools/localization/UiLiteralAudit.gd'='A'
  'tests/unit/test_localized_binding.gd'='A'
  'tests/scene/test_settings_localization_scene.gd'='A'
  'tests/integration/ProjectStartupLocalizationHarness.gd'='A'
  'tests/integration/ProjectStartupLocalizationHarness.tscn'='A'
  'evidence/phase_2r/localization/ui_literal_disposition.json'='A'
  'evidence/phase_2r/localization/script_ui_disposition.json'='A'
  'evidence/phase_2r/localization/full_catalog_validation.json'='M'
  'localization/ui/en.json'='M'
  'localization/ui/zh_CN.json'='M'
  'localization/ui/zh_HK.json'='M'
  'scripts/ui/Setting.gd'='M'
  'scripts/ui/SettingsApp.gd'='M'
  'scenes/menu/Setting.tscn'='M'
  'scenes/apps/SettingsApp.tscn'='M'
  'scenes/menu/MenuScene.tscn'='M'
  'scenes/menu/GalleryScene.tscn'='M'
  'scenes/opening/OpeningScene.tscn'='M'
  'scenes/main/MainGameScene.tscn'='M'
  'scenes/desktop/ComputerDesktop.tscn'='M'
  'scenes/apps/BackupApp.tscn'='M'
  'scenes/apps/ContactListApp.tscn'='M'
  'scenes/apps/LogOutApp.tscn'='M'
  'scenes/apps/MinesweeperApp.tscn'='M'
  'scenes/apps/ScheduleApp.tscn'='M'
  'scenes/apps/ShopApp.tscn'='M'
  'scenes/dating/DatingScene.tscn'='M'
  'scenes/dating/MinesweeperChallengeOverlay.tscn'='M'
  'scenes/hospital/HospitalScene.tscn'='M'
  'scenes/ending/EndingScene.tscn'='M'
  'scenes/overlay/TutorialOverlay.tscn'='M'
  'scripts/ui/LocalizedText.gd'='D'
  'scripts/ui/LocalizedText.gd.uid'='D'
}
$optionalUids = [ordered]@{
  'scripts/ui/LocalizedBinding.gd.uid'='A'
  'scripts/ui/LocalePresentationRoot.gd.uid'='A'
  'scripts/ui/SettingsPanelController.gd.uid'='A'
  'tools/localization/UiLiteralAudit.gd.uid'='A'
  'tests/unit/test_localized_binding.gd.uid'='A'
  'tests/scene/test_settings_localization_scene.gd.uid'='A'
  'tests/integration/ProjectStartupLocalizationHarness.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Plan 02 Task 5 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'feat(localization): bind UI and manifest-driven locale presentation'
if ($LASTEXITCODE -ne 0) { throw 'Exact Plan 02 Task 5 commit boundary failed.' }
~~~

## Task 6: Make AudioManager the sole live audio owner

**Files:**

- Modify: `autoload/AudioManager.gd`
- Modify: `autoload/DialogicBridge.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `autoload/InputManager.gd`
- Modify: `scripts/data/AudioManifest.gd`
- Create: `scripts/audio/AudioPlaybackPort.gd`
- Modify: `scripts/ui/SettingsPanelController.gd`
- Create: `scripts/narrative/DialogicPreferenceAdapter.gd`
- Create: `tests/support/FakeAudioPlaybackPort.gd`
- Modify: `tests/unit/test_audio_manager.gd`
- Create: `tests/unit/test_dialogic_preferences.gd`
- Modify: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Create: `tests/integration/test_profile_reset_consumers.gd`
- Modify: `tests/integration/ProjectStartupLocalizationHarness.gd`
- Extend: `tests/unit/test_profile_manager.gd`

**Interfaces:**

- Consumes: Task 1 committed/deferred profile notifications and reset semantics; Task 4 LocalizationManager profile application; Task 5 shared Settings controller; registered semantic records in `AudioManifest`; the installed Dialogic 2.0-Alpha-19 live subsystems.
- Produces: every frozen AudioManager initialization/silent-restore method while preserving its Task 2 mutation-gate seam; the common `configure_mutation_gate(gate: Object) -> Dictionary` seam on DialogicBridge; registered semantic music/ambience/SFX, deterministic fade/crossfade ownership, failpoint recovery, and semantic snapshots; a nonpersisting Dialogic preference adapter reapplied after every runtime clear; exact six-target development-gate identity/startup evidence; cross-manager reset evidence with no stale live consumer.

- [ ] **Step 6.1: Write ownership and boundary RED tests**

- [ ] Extend the current test by dynamically checking for the new APIs. Tests cover delayed initialization, preservation of AudioManager's Task 2 gate object/instance ID through the rewrite, bus assignment, clamps below/above `0..1`, the exact silence threshold, explicit mute dominance, temporary focus-loss mute, profile signal application, unknown context/cue rejection, semantic SFX dispatch, same-context idempotence, music and ambience crossfades, zero/duration fades, superseded-tween cancellation, every playback-port failpoint, semantic snapshot JSON safety, silent semantic restart/rollback/finalize, no restore signal, no-alias contexts, and no GameState audio ownership.

- [ ] The semantic run snapshot is exactly:

```json
{
  "music_context_id": "ending",
  "music_context": {"ending_id": "ending.priscilla.true"},
  "ambience_context_id": "hospital",
  "ambience_context": {}
}
```

It contains no streams, resource paths, player nodes, buses, tweens, timestamps, sample positions, or live mute objects.

- [ ] `test_dialogic_preferences.gd` uses the installed-version seam and records exact ordering for bootstrap, New Game, and restore: Dialogic clear → cached committed preference reapply → first `event_handled`. It proves all three settings are correct at the first event and no call writes Dialogic global save info, ProjectSettings, or profile state. `test_profile_reset_consumers.gd` places fresh manager instances on-tree with isolated storage, changes every preference domain, performs each reset, and proves LocalizationManager, AudioManager, InputManager, AccessibilityManager, and DialogicBridge expose the committed values in the same frame.

- [ ] Extend `test_application_bootstrap_profile_stage.gd` with `test_dialogic_bridge_exposes_common_gate_contract`, `test_real_plan02_targets_share_one_gate_identity`, and `test_real_six_target_gate_failure_stops_before_profile`. Configure a fresh DialogicBridge before binding and run the exact valid/same/null/missing-method/missing-signal/replacement matrix with no Dialogic/profile/signal side effect. Then use all six real Plan-02 manager scripts to prove the ordered development list is exactly ProfileManager → LocalizationManager → InputManager → AccessibilityManager → AudioManager → DialogicBridge, every returned ID is the one factory-created gate ID, and failure at each of the six ordinals prevents every initializer/bind/disk call. SaveManager, GameState, and SceneRouter must record zero gate calls. Expected RED is `DialogicBridge` missing `configure_mutation_gate`, not a parse, autoload, or later-plan production-target error.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio_dialogic_reset_red' -LogName 'phase2r-audio-dialogic-reset-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_manager.gd,res://tests/unit/test_dialogic_preferences.gd,res://tests/integration/test_profile_reset_consumers.gd','-gexit')
```

Expected RED: AudioManager lacks `prepare_semantic_restore` or DialogicPreferenceAdapter reports `missing_script`. Existing unrelated audio behavior must not regress.

- [ ] **Step 6.2: Implement the live owner interface**

- [ ] Freeze the disposition of the current `autoload/AudioManager.gd` surface before editing:

```text
KEEP/RESHAPE PUBLIC: initialize, set_music_context, get_current_bgm_id (rename get_music_context_id),
                     get_current_ambience_id (rename get_ambience_context_id), play_sfx,
                     get_missing_audio_report, restore-participant methods
ADD PUBLIC:          set_ambience_context, get_semantic_audio_context,
                     set_channel_volume, set_channel_muted, apply_profile_preferences
MAKE PRIVATE:        ensure_audio_players, ensure_audio_buses, is_track_available,
                     play_bgm, stop_bgm, play_ambience, stop_ambience,
                     resolve_bgm_for_context, refresh_current_context, pause_music, resume_music
REMOVE AFTER CALLER MIGRATION: get_track_path, play_ui_sfx, play_voice, set_music_muted
DELETE:              _gs, _setting, _set_audio_state and every GameState audio read/write
REPLACE SIGNALS:     bgm_changed/bgm_stopped/ambience_changed/audio_context_changed with
                     music_context_changed, ambience_context_changed, sfx_requested;
                     retain audio_warning and audio_settings_applied with copied payloads
```

No compatibility wrapper may continue accepting a track/resource path. `EndingScene.gd` remains a semantic `set_music_context("ending", {"ending_id": ...})` caller; tests and any other raw-track callers migrate before removal.

- [ ] Implement the frozen restore API plus the final semantic/preference surface:

```gdscript
const VOLUME_SILENCE_THRESHOLD := 0.0001

signal music_context_changed(context_id: String, context: Dictionary)
signal ambience_context_changed(context_id: String, context: Dictionary)
signal sfx_requested(cue_id: String, receipt: Dictionary)
signal audio_settings_applied(settings: Dictionary)
signal audio_warning(result: Dictionary)

func _init(playback_port: RefCounted = null) -> void
func configure_mutation_gate(gate: Object) -> Dictionary
func initialize(profile: Node) -> Dictionary
func set_music_context(context_id: String, context: Dictionary = {}) -> Dictionary
func set_ambience_context(context_id: String, context: Dictionary = {}) -> Dictionary
func play_sfx(cue_id: String, context: Dictionary = {}) -> Dictionary
func get_music_context_id() -> String
func get_ambience_context_id() -> String
func get_semantic_audio_context() -> Dictionary
func set_channel_volume(channel_id: StringName, linear: float) -> Dictionary
func set_channel_muted(channel_id: StringName, muted: bool) -> Dictionary
func apply_profile_preferences(changed_path: StringName = &"") -> Dictionary
func prepare_semantic_restore(snapshot: Dictionary, prepared_profile: Dictionary) -> Dictionary
func capture_restore_state() -> Dictionary
func apply_restore_silent(plan: Dictionary) -> Dictionary
func rollback_restore_silent(backup: Dictionary) -> Dictionary
func finalize_restore() -> Dictionary
```

The rewrite retains Task 2's private gate field and exact configure result/failure behavior. It neither clears nor replaces the gate during initialization, preference application, semantic restore/rollback/finalize, focus changes, or profile reset; `test_audio_manager.gd` configures the gate before `initialize()` and proves the same gate instance ID afterward. `initialize(profile)` validates the dependency, connects once to committed preference/reset signals, creates the production `AudioPlaybackPort` when none was injected at construction, ensures buses/players through that port, and applies current committed values. `_ready()` remains a no-op. A second initialize call fails. The injected port is accepted only before initialization and is not exposed afterward.

- [ ] `AudioPlaybackPort` is the only class besides AudioManager that touches AudioStreamPlayer/Tween primitives and exposes failpoint-sized operations:

```gdscript
func ensure_bus(bus_name: StringName) -> Dictionary
func ensure_player(player_id: StringName, bus_name: StringName) -> Dictionary
func load_stream(registered_path: String) -> Dictionary
func assign_stream(player_id: StringName, stream: AudioStream) -> Dictionary
func set_player_db(player_id: StringName, value_db: float) -> Dictionary
func set_bus_state(bus_name: StringName, value_db: float, muted: bool) -> Dictionary
func play(player_id: StringName) -> Dictionary
func stop(player_id: StringName) -> Dictionary
func stop_and_clear(player_id: StringName) -> Dictionary
func kill_tween(channel_id: StringName) -> Dictionary
func create_parallel_tween(channel_id: StringName, tracks: Array[Dictionary], duration: float) -> Dictionary
func capture_runtime() -> Dictionary
func restore_runtime(backup: Dictionary) -> Dictionary
```

Production owns exactly `MusicA`, `MusicB`, `AmbienceA`, `AmbienceB`, eight round-robin `SFX` one-shot players, four `UI` players, and two `Voice` players. When a pool is full, the oldest playing voice on that bus is stopped and reused deterministically. `FakeAudioPlaybackPort.fail_after(ordinal)` fails one recorded operation and deep-copies every argument/result. No runtime node, stream, tween, or path crosses the AudioManager public boundary.

- [ ] Map channels exactly:

```text
music -> Music
ambience -> Ambience
sfx -> SFX and UI
voice -> Voice
```

For each bus:

```gdscript
var effective_mute := explicit_mute or linear <= VOLUME_SILENCE_THRESHOLD or focus_loss_mute
```

For values above the threshold apply `linear_to_db(clampf(linear, 0.0, 1.0))`. AudioManager delegates preference writes to ProfileManager and applies only committed `preference_changed` notifications.

- [ ] `AudioManifest` becomes the closed semantic registry and exposes `resolve_music_context(context_id, context)`, `resolve_ambience_context(context_id, context)`, and `get_cue(cue_id)`. Each returns a detached primitive record with registered internal path, target bus, loop, `fade_in_seconds`, and `fade_out_seconds`; callers cannot supply or override those fields. Context/cue input is recursively copied and validated against the record's exact primitive field allowlist. `play_sfx()` resolves only a registered cue ID, selects its manifest bus/pool, and returns a copied receipt; SFX is one-shot and never enters a run snapshot. Missing/unloadable audio returns `missing_audio`, leaves existing playback untouched, and emits one copied warning.

- [ ] Music and ambience each use an exact two-player crossfade transaction. Prepare resolves/loads the new registered stream and captures semantic plus port runtime state before mutation. Applying kills only the prior tween for that channel, starts the inactive player at silence, then creates one parallel tween from current dB values to candidate target/old silence using `max(old.fade_out_seconds, new.fade_in_seconds)`; duration `0.0` performs the same role swap synchronously. Completion stops/clears the old player and leaves the new at target dB. A request resolving to the same context, deep-equal context parameters, and same track is idempotent and creates no player/tween/signal. A superseding request kills the old tween, captures current dB, and crossfades from those exact values—never jumps back to endpoints.

- [ ] Inject failure after load, capture, tween kill, stream assignment, each dB write, play, tween creation, and old-player stop. Before semantic commit, any failure restores the captured port state and old copied semantic context and emits no context signal. If rollback itself fails, return fatal `audio_runtime_indeterminate`, mute/stop the affected channel through a final best-effort port call, emit one warning, and block later commands until reinitialization. Commit copied semantic context only after the fade is successfully scheduled (or zero-duration swap completes), then emit one copied context signal. Tests assert active tween ownership is at most one per music/ambience channel and no failed request changes the semantic snapshot.

- [ ] `prepare_semantic_restore()` validates the exact semantic snapshot plus prepared `preferences.audio.*` values without touching players. Silent apply cancels active fades and restarts registered semantic contexts from their beginning with restore fade duration `0.0`, then applies prepared volume/mute values without audio/profile/domain signals. Rollback restarts the captured pre-restore semantic contexts/preferences in reverse with duration `0.0`; sample positions, prior tween progress, and partial fades are intentionally not restored. Finalize clears runtime backup only. All snapshot, context, warning, receipt, prepared-plan, backup, and signal Dictionaries are deep copies.

- [ ] Remove GameState discovery helpers and every write to legacy audio state after callers and snapshot seams migrate. Focus-loss mute remains an AudioManager runtime overlay, never a persisted preference replacement; explicit mute dominates at every volume. Setting controllers use only fully qualified `preferences.audio.*` paths.

- [ ] **Step 6.3: Apply dialogue preferences without creating a Dialogic settings owner**

- [ ] Add this installed-version adapter seam:

```gdscript
# scripts/narrative/DialogicPreferenceAdapter.gd
class_name DialogicPreferenceAdapter
extends RefCounted

func bind(dialogic: Node) -> Dictionary
func prepare(profile: Dictionary) -> Dictionary
func capture_state() -> Dictionary
func apply_silent(plan: Dictionary) -> Dictionary
func rollback_silent(backup: Dictionary) -> Dictionary
func finalize() -> Dictionary

# additions preserved on autoload/DialogicBridge.gd by plan 05
func configure_mutation_gate(gate: Object) -> Dictionary
func bind_profile_preferences(profile: Node, preference_adapter: RefCounted = null) -> Dictionary
func apply_profile_preferences(changed_path: StringName = &"") -> Dictionary
func reapply_cached_preferences_after_clear() -> Dictionary
```

DialogicBridge retains the configured gate in a private field using the Global Constraints contract. Configuration occurs before profile binding; the first compatible object succeeds, the same object is idempotent, and null/incomplete/replacement objects fail with the frozen codes. Binding, preference reapplication, Dialogic clear/start, restore rollback/finalize, and runtime-adapter replacement never clear or replace it. Gate configuration performs no Dialogic lookup, binding, signal emission, persistence, or domain mutation, and the tests prove its returned instance ID remains unchanged across every clear/reapply path.

- [ ] `prepare()` reads exactly `preferences.dialogue.text_speed`, `preferences.dialogue.auto_text_speed`, and `preferences.dialogue.auto_advance_dialogue` and returns a detached plan:

```gdscript
{
	"text_delay_multiplier": 1.0 / text_speed,
	"auto_delay_multiplier": 1.0 / auto_text_speed,
	"auto_advance_enabled": auto_advance_dialogue,
}
```

The profile schema guarantees both speeds are finite and greater than zero. The production adapter writes only the already-instantiated live subsystem cache/fields required by Dialogic 2.0-Alpha-19: assign `Dialogic.Settings.settings[&"text_speed"] = text_delay_multiplier` without invoking its persistence setter; call `Dialogic.Text.update_text_speed(-1.0, false, 1.0, text_delay_multiplier)`; assign `Dialogic.Settings.settings[&"autoadvance_delay_modifier"] = auto_delay_multiplier`; assign `Dialogic.Inputs.auto_advance.delay_modifier = auto_delay_multiplier`; and assign the player-auto flag to `Dialogic.Inputs.auto_advance.enabled_until_user_input`. It MUST NOT call `Dialogic.Settings._set`, `Dialogic.Save.set_global_info`, `ProjectSettings.set_setting`, or any profile mutation. A user input may interrupt `enabled_until_user_input`; this does not create a second persisted settings owner. Inputs, cached plan, capture, and rollback values are recursively copied.

- [ ] DialogicBridge binds the adapter during its bootstrap stage, applies current values once, and reapplies only for `preferences.dialogue.text_speed`, `preferences.dialogue.auto_text_speed`, or `preferences.dialogue.auto_advance_dialogue`, including reset leaf notifications. The summary `profile_reset` signal does not cause a duplicate apply.

- [ ] Dialogic 2.0-Alpha-19 `clear()` reloads addon Settings from its global store, and `start_timeline()` emits `timeline_started` synchronously before `handle_next_event()`. On bind, DialogicBridge connects exactly one synchronous handler to the installed `Dialogic.timeline_started`; that handler calls assignment-only `reapply_cached_preferences_after_clear()` before the first event executes. Every New Game and restore path must clear/start only through DialogicBridge/plan-05's runtime adapter, so the exact observed order is `clear`, `profile_preferences_reapplied`, `first_event`. The cached plan was validated at the prior profile commit, making this hook non-failing and disk-free. Initial bootstrap also applies once after Dialogic's `_ready()` clear. Plan 05 MUST preserve this binding and invoke the same hook between its explicit restore clear and first restored event; direct production calls to `Dialogic.start*`, `Dialogic.clear`, or `handle_event` outside DialogicBridge/runtime adapter are forbidden.

- [ ] Add real-addon integration cases for: New Game after nondefault profile values, a stable-checkpoint restore after nondefault values, a preference reset, and a different-slot restore. At each first `event_handled`, assert the Dialogic Settings/Text/Inputs fields already equal the committed profile. Assert exactly one reapply per clear/start boundary and zero Dialogic/Profile persistence calls.

- [ ] **Step 6.4: Prove resets update every consumer without stale live state**

- [ ] ProfileManager uses Task 1's exact preference → input → gallery → visited → summary notification order after a successful reset write. `reset_preferences()` restores schema defaults; `reset_visited_history()` and `reset_gallery()` do not touch preferences; `reset_entire_profile()` resets all user-visible fields while retaining gallery transaction and migration receipt ledgers.

- [ ] LocalizationManager keeps its already validated source bundle prepared at initialization, so a committed preference/entire-profile reset can apply source locale presentation without disk parsing or a second profile write. AudioManager, InputManager, AccessibilityManager, and DialogicBridge similarly apply only validated in-memory defaults from fully qualified committed notifications. Final-mode application failure handling records any impossible consumer error as fatal rather than silently leaving stale state; the explicit development subset reports only failures from its included stages.

- [ ] The integration test asserts after each reset: profile snapshot, active locale/presentation, every audio bus effective state, InputMap records, accessibility getters, Dialogic delay/auto values, gallery/history, signal counts/order, and retained internal receipts. It also asserts notification handlers issue zero calls to `set_preference`, `set_preferences`, `set_input_mapping`, or `set_locale`.

- [ ] **Step 6.5: Complete the owned bootstrap stages and run the subsystem gate**

- [ ] `ApplicationBootstrap` supplies actual Task `.3` stage adapters in the frozen relative order: select/prove roots; construct/inject the one mutation gate; initialize ProfileManager; initialize LocalizationManager from committed `preferences.language`; initialize InputManager; initialize AccessibilityManager; initialize AudioManager; bind DialogicBridge preferences to the already-ready Dialogic autoload. In `profile_locale_audio_development`, only a wrapper-root-proven harness may install the Task 1 fake factory before deferred start; the stage invokes it once and configures exactly `DEVELOPMENT_GATE_TARGETS[MODE_PROFILE_LOCALE_AUDIO_DEVELOPMENT]` in the frozen six-target order before the first initializer. The successful startup-state record must contain that exact target array, one nonzero gate ID, six parallel copies of that ID, and `factory_invocation_count == 1`; SaveManager, GameState, and SceneRouter receive no call. Until plans 03/05/06 implement the omitted final stages and production targets, only the explicitly requested debug development subset may succeed, and it emits `development_subset_ready` rather than `application_ready`. Final mode still resolves the full frozen `FINAL_GATE_TARGETS`, rejects the debug factory seam, and remains fail-closed on `missing_production_gate_factory`.
- [ ] Extend the bootstrap source-contract test across ProfileManager, GameState, LocalizationManager, InputManager, AccessibilityManager, AudioManager, DialogicBridge, and ApplicationBootstrap. Every owned manager `_ready()` is empty; ApplicationBootstrap's contains only the deferred `start` call. Disk I/O, cross-manager lookup, signal connection, live player/bus creation, and preference application appear only in named stage methods. The shared real startup harness must pass in both development modes: under the audio mode it asserts the six-target identity record and completed `[roots, gate, profile, localization, input, accessibility, audio, dialogic]` order before it accepts `development_subset_ready`; any factory/identity/target failure exits nonzero before profile initialization. This evidence is sufficient to close `dwm-p2r.3` without pretending plan 03's production gate exists.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'profile_locale_audio_gate' -LogName 'phase2r-profile-locale-audio-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_json_file_storage.gd,res://tests/unit/test_profile_manager.gd,res://tests/unit/test_game_state.gd,res://tests/unit/test_input_accessibility.gd,res://tests/unit/test_strict_json.gd,res://tests/unit/test_localization_extraction.gd,res://tests/unit/test_localization.gd,res://tests/unit/test_localized_binding.gd,res://tests/unit/test_audio_manager.gd,res://tests/unit/test_dialogic_preferences.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd,res://tests/integration/test_profile_reset_consumers.gd,res://tests/scene/test_settings_localization_scene.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'profile_locale_audio_startup_gate' -LogName 'phase2r-profile-locale-audio-startup-gate.log' -GodotArgs @('res://tests/integration/ProjectStartupLocalizationHarness.tscn','--','--phase2r-bootstrap-mode=profile_locale_audio_development') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
```

Expected GREEN: zero failed tests and project diagnostics; one wrapper-proven fake factory invocation; one gate identity across the exact six ordered development targets; one explicit development-subset readiness with no false final readiness/fatal; no SaveManager/GameState/SceneRouter gate call, production persistence access, recursive localization refresh, TranslationServer, Dialogic global preference persistence, or GameState profile/audio ownership; every reset consumer and every first Dialogic event is current.

- [ ] Run final ownership/semantic-boundary scans:

```powershell
rg -n 'AudioStreamPlayer|create_tween\(|Tween\.' autoload scripts scenes --glob '!autoload/AudioManager.gd' --glob '!scripts/audio/AudioPlaybackPort.gd'
rg -n 'play_bgm|stop_bgm|play_ambience|stop_ambience|play_ui_sfx|play_voice|get_track_path|resolve_bgm_for_context|refresh_current_context|set_music_muted' autoload scripts scenes tests --glob '!autoload/AudioManager.gd' --glob '!tests/unit/test_audio_manager.gd'
rg -n 'Dialogic\.(start|start_timeline|clear|handle_event|handle_next_event)' autoload scripts scenes --glob '!autoload/DialogicBridge.gd' --glob '!scripts/narrative/DialogicRuntimeAdapter.gd'
rg -n 'TranslationServer|GameState\.(settings|audio_state|seen_endings)|get_audio_state|set_audio_state|record_ending_seen|Dialogic\.Save\.set_global_info|Dialogic\.Settings\._set|ProjectSettings\.set_setting|\[draft\]' autoload scripts scenes --glob '!tools/localization/UiLiteralAudit.gd'
```

Expected: all four scans exit 1/no matches. Manifest-internal registered resource paths and negative test assertions are excluded from production scans, not accepted as caller exceptions.

- [ ] **Step 6.6: Proposed path-specific commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'autoload/AudioManager.gd'='M'
  'autoload/DialogicBridge.gd'='M'
  'autoload/ApplicationBootstrap.gd'='M'
  'autoload/InputManager.gd'='M'
  'scripts/data/AudioManifest.gd'='M'
  'scripts/ui/SettingsPanelController.gd'='M'
  'tests/unit/test_audio_manager.gd'='M'
  'tests/unit/test_application_bootstrap_profile_stage.gd'='M'
  'tests/unit/test_profile_manager.gd'='M'
  'scripts/audio/AudioPlaybackPort.gd'='A'
  'scripts/narrative/DialogicPreferenceAdapter.gd'='A'
  'tests/support/FakeAudioPlaybackPort.gd'='A'
  'tests/unit/test_dialogic_preferences.gd'='A'
  'tests/integration/test_profile_reset_consumers.gd'='A'
  'tests/integration/ProjectStartupLocalizationHarness.gd'='M'
}
$optionalUids = [ordered]@{
  'scripts/audio/AudioPlaybackPort.gd.uid'='A'
  'scripts/narrative/DialogicPreferenceAdapter.gd.uid'='A'
  'tests/support/FakeAudioPlaybackPort.gd.uid'='A'
  'tests/unit/test_dialogic_preferences.gd.uid'='A'
  'tests/integration/test_profile_reset_consumers.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Plan 02 Task 6 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'refactor(audio): centralize semantic audio and profile preferences'
if ($LASTEXITCODE -ne 0) { throw 'Exact Plan 02 Task 6 commit boundary failed.' }
~~~

## Issue completion checks

- [ ] Append extraction evidence, scene/script UI dispositions, storage write/delete failpoint matrix, audio failpoint matrix, focused logs, and the subsystem test command to `dwm-p2r.3`.
- [ ] Run the ownership scans and checked-in documentation validator:

```powershell
rg -n 'TranslationServer|GameState\.(settings|audio_state|seen_endings)|get_audio_state|set_audio_state|record_ending_seen|Dialogic\.Save\.set_global_info|user://input_bindings\.json' autoload scripts scenes tests
rg -n 'get_preference\(&"(language|audio\.|dialogue\.|display\.|accessibility\.)|set_preference\(&"(language|audio\.|dialogue\.|display\.|accessibility\.)|preference_changed.*&"(language|audio\.|dialogue\.|display\.|accessibility\.)' autoload scripts tests
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'profile_locale_audio_docs' -LogName 'phase2r-profile-locale-audio-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
bd dep cycles
```

Expected matches are only migration fixtures and negative source assertions; documentation errors and Beads dependency cycles equal zero.
- [ ] Close `dwm-p2r.3` only when every acceptance criterion is linked to GREEN evidence.
- [ ] Confirm `dwm-p2r.5` remains blocked on both `.3` and `.4`; do not bypass dependencies.
