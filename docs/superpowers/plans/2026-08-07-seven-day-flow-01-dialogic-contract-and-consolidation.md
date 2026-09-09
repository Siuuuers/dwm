# Seven-Day Flow Phase 01: Dialogic Contract and Consolidation Implementation Plan

> **Owner decision, 2026-09-08:** Eight-master consolidation is cancelled. Retain
> the original scene-oriented DTL arrangement and implement all promised scene
> mechanics with dialogue deferred. References below to 61-to-8 migration,
> eight-only path/count gates, and deleting the original DTL/UID files are
> superseded and must not be executed. Semantic IDs, exact entry resolution,
> safe scene completion, save/load, and promised branches remain required.
> Existing consolidated files are temporary implementation state, not layout
> authority. See the updated base design sections 4.1, 12.1, and 16.4.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace permissive path-based narrative lookup with a closed semantic entry contract, create eight executable plot-neutral English master timelines, and make label-aware validated playback possible without yet inventing prose.

**Architecture:** Strict JSON manifests describe every callable entry, exact locator, frozen context, source-scoped signal, stable line/atom namespace, and visual capability. `DialogicEntryManifest` validates and indexes those records; `DialogicTimelineCatalog` becomes a compatibility facade; `DialogicBridge` starts only validated `{path,label}` entries and owns the playback token. A static validator proves DTL labels and returns before legacy files are retired.

**Tech Stack:** Godot 4.6.3, GDScript, Dialogic 2.0 Alpha 19, StrictJson, JsonSchemaValidator, GUT, eight `.dtl` masters.

## Global Constraints

- [ ] Required skills: `api-and-interface-design`, `security-and-hardening`, `deprecation-and-migration`, `godot-master` with `dialogue-system`, `ui-rich-text`, `save-load-systems`, and `testing-patterns`, plus `test-driven-development` and `superpowers:verification-before-completion`.
- [ ] Phase 00 must be complete and its requirement packets/index green.
- [ ] Expand all 139 public entry records explicitly: 121 day entries plus 18 callable ending presentation entries. Runtime wildcard or suffix parsing is forbidden.
- [ ] Preserve stable semantic IDs. Physical paths and labels are locators, not save/Gallery/history identities.
- [ ] Every master starts with a bare `return`; every callable label owns its own trailing `return`.
- [ ] Do not add final dialogue, actions, plot premises, art, audio, or animation. Skeleton comments may describe role, causal input, variation order, and allowed signals only.
- [ ] Keep the 61 old DTL and UID files until Plan 06 proves the physical cutover. Coexistence during migration is intentional.
- [ ] Do not fabricate Chinese DTL files. Missing locale locators fall back to the same semantic entry and exact label in English.
- [ ] `start_timeline_path()` becomes test-only/deprecated and must have no production caller before physical cutover.
- [ ] A DTL signal cannot carry deltas, arbitrary strings, method names, paths, Resources, Nodes, save data, or next-entry IDs.

---

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Approved inventory commit and legacy DTL tree | Immutable 61-to-8 migration records |
| 2 | Spec sections 12–13 | Closed entry/ID/context/signal/visual contracts |
| 3 | Exact manifest | Eight structural masters and static validator |
| 4 | Validated manifest/labels | Exact semantic locator catalog |
| 5 | Locator catalog and Dialogic API | One label-aware signal/completion playback boundary |
| 6 | ID/atom/visual registries | Closed visited-line, atom, and visual validation |
| 7 | Semantic checkpoint contract | Restore prepare/apply/finalize with fresh process token |

## Task 1: Characterize and freeze the current timeline inventory

**Specification:** Sections 4, 12.1–12.2, 13, 16.4.

**Files:**

- Create: `data/migrations/dialogic_61_to_8.json`
- Create: `schemas/manifests/dialogic-migration.schema.json`
- Create: `tests/unit/test_dialogic_migration_inventory.gd`
- Inspect only: `dialogic/timelines/en/**`
- Inspect only: `project.godot`

- [ ] Write a failing inventory test that requires exactly 61 tracked legacy `.dtl` paths, 61 tracked adjacent UID paths, their approved-source commit/blob IDs and SHA-256 values, all existing labels, and one disposition per source. The immutable source inventory commit is `9e15c38f9f2eee7edc5a399bdde07823b90cfeb4`:

```gdscript
const ALLOWED_DISPOSITIONS := ["retained", "split", "retired"]

func test_every_legacy_timeline_has_one_checked_disposition() -> void:
	var manifest := _load_migration_manifest()
	assert_eq(manifest.legacy_files.size(), 61)
	for record in manifest.legacy_files:
		assert_has(ALLOWED_DISPOSITIONS, record.disposition)
		assert_false(record.source_blob_id.is_empty())
		if manifest.cutover_status == "legacy_present":
			assert_true(FileAccess.file_exists(record.path))
			assert_eq(FileAccess.get_sha256(record.path), record.sha256)
		else:
			assert_false(FileAccess.file_exists(record.path))
```

- [ ] Include explicit transformations for:

  - generic contact files split into exact ordinary/offer/follow-up entries;
  - `hospital.faint` split into `hospital.faint.day1` through `.day7` entries;
  - five old ending files split into the 18 approved presentation entries;
  - retired `ending.*.true` labels rejected rather than aliased to Observer;
  - group/twofriends Day 2/6 files retained as semantic entries under their owning day master.

- [ ] Run RED. Expected failure: migration manifest/schema does not exist.
- [ ] Create the exact inventory from the named Git tree, not by blessing arbitrary live bytes. Before recording it, require every one of the 122 targets to be tracked, unstaged, unmodified, and byte-equal to its source blob; stop for separate archive/authorization if any target differs. Do not edit source DTLs in this task.
- [ ] Validate that all 91 legacy labels and placeholder-comment blocks are accounted for. Ambiguous saved checkpoints without a semantic discriminator must map to `incompatible`, never to a guessed label.
- [ ] Run GREEN and commit:

```text
test(dialogic): freeze 61-to-8 timeline migration inventory
```

## Task 2: Implement the closed manifest and exact ID registries

**Specification:** Sections 6.4, 9, 11.2, 12.2–12.3, 12.6, 12.8, 14.1–14.2.

**Files:**

- Create: `schemas/manifests/dialogic-entries.schema.json`
- Create: `schemas/manifests/dialogic-ids.schema.json`
- Create: `schemas/manifests/dialogic-visuals.schema.json`
- Create: `data/manifests/dialogic_entries.json`
- Create: `data/manifests/dialogic_ids.json`
- Create: `data/manifests/dialogic_visuals.json`
- Modify: `data/manifests/narrative_variables.json`
- Create: `scripts/narrative/DialogicEntryManifest.gd`
- Create: `scripts/narrative/FrozenPresentationContext.gd`
- Create: `tests/unit/test_timeline_manifest.gd`
- Create: `tests/unit/test_frozen_presentation_context.gd`

- [ ] Write RED tests for exact top-level keys, duplicate entry/label rejection, closed IDs, missing/extra context fields, illegal friend/day/role combinations, wrong ending forms, wrong locale fallback, and unknown visual IDs.
- [ ] Define one exact manifest record shape:

```gdscript
{
	"entry_id": "contact.ordinary.lavinia.day1",
	"role": "ordinary_message",
	"day": 1,
	"ending_id": null,
	"allowed_ending_forms": [],
	"locators": {
		"en": {"path": "res://dialogic/timelines/en/day_1.dtl", "label": "contact.ordinary.lavinia.day1"}
	},
	"context_schema_id": "context.ordinary.lavinia.day1.v1",
	"allowed_signals": ["message.reply.commit", "history.line.witness", "message.echo.satisfy"],
	"line_namespace": "line.contact.ordinary.lavinia.day1",
	"atom_namespace": "atom.contact.ordinary.lavinia.day1",
	"content_version": 1,
	"visual_ids": {"required": [], "optional": []}
}
```

- [ ] The schema must reject unknown keys, unknown enum values, empty identifiers, duplicate locator pairs, absolute OS paths, non-`res://` paths, and labels not equal to their registered semantic entry unless an explicitly versioned migration record says otherwise.
- [ ] Populate all 139 entry records exactly from specification section 13. Do not use `*`, regular-expression families, abbreviated `.a|b|c` notation, or generated-at-runtime suffixes.
- [ ] Register the exact 13 ending IDs, 18 ordinary reply IDs, the five section-12.8 signal IDs/payload schemas, presentation atom namespaces, retired IDs, and allowed `ending_form` union from section 12.3.
- [ ] Expand the structural presentation registry explicitly, never by runtime suffix parsing. These six rows own exactly three line IDs and three Day-7 fallback atom IDs apiece:

| Ordinary entry | Semantic reply IDs | Authoritative reply line IDs | Guaranteed fallback atom IDs |
|---|---|---|---|
| `contact.ordinary.lavinia.day1` | `reply.contact.ordinary.lavinia.day1.a`, `reply.contact.ordinary.lavinia.day1.b`, `reply.contact.ordinary.lavinia.day1.c` | `line.contact.ordinary.lavinia.day1.reply.a`, `line.contact.ordinary.lavinia.day1.reply.b`, `line.contact.ordinary.lavinia.day1.reply.c` | `atom.echo.lavinia.day1.reply.a.fallback.day7`, `atom.echo.lavinia.day1.reply.b.fallback.day7`, `atom.echo.lavinia.day1.reply.c.fallback.day7` |
| `contact.ordinary.sylvia.day2` | `reply.contact.ordinary.sylvia.day2.a`, `reply.contact.ordinary.sylvia.day2.b`, `reply.contact.ordinary.sylvia.day2.c` | `line.contact.ordinary.sylvia.day2.reply.a`, `line.contact.ordinary.sylvia.day2.reply.b`, `line.contact.ordinary.sylvia.day2.reply.c` | `atom.echo.sylvia.day2.reply.a.fallback.day7`, `atom.echo.sylvia.day2.reply.b.fallback.day7`, `atom.echo.sylvia.day2.reply.c.fallback.day7` |
| `contact.ordinary.priscilla.day3` | `reply.contact.ordinary.priscilla.day3.a`, `reply.contact.ordinary.priscilla.day3.b`, `reply.contact.ordinary.priscilla.day3.c` | `line.contact.ordinary.priscilla.day3.reply.a`, `line.contact.ordinary.priscilla.day3.reply.b`, `line.contact.ordinary.priscilla.day3.reply.c` | `atom.echo.priscilla.day3.reply.a.fallback.day7`, `atom.echo.priscilla.day3.reply.b.fallback.day7`, `atom.echo.priscilla.day3.reply.c.fallback.day7` |
| `contact.ordinary.lavinia.day4` | `reply.contact.ordinary.lavinia.day4.a`, `reply.contact.ordinary.lavinia.day4.b`, `reply.contact.ordinary.lavinia.day4.c` | `line.contact.ordinary.lavinia.day4.reply.a`, `line.contact.ordinary.lavinia.day4.reply.b`, `line.contact.ordinary.lavinia.day4.reply.c` | `atom.echo.lavinia.day4.reply.a.fallback.day7`, `atom.echo.lavinia.day4.reply.b.fallback.day7`, `atom.echo.lavinia.day4.reply.c.fallback.day7` |
| `contact.ordinary.priscilla.day5` | `reply.contact.ordinary.priscilla.day5.a`, `reply.contact.ordinary.priscilla.day5.b`, `reply.contact.ordinary.priscilla.day5.c` | `line.contact.ordinary.priscilla.day5.reply.a`, `line.contact.ordinary.priscilla.day5.reply.b`, `line.contact.ordinary.priscilla.day5.reply.c` | `atom.echo.priscilla.day5.reply.a.fallback.day7`, `atom.echo.priscilla.day5.reply.b.fallback.day7`, `atom.echo.priscilla.day5.reply.c.fallback.day7` |
| `contact.ordinary.sylvia.day6` | `reply.contact.ordinary.sylvia.day6.a`, `reply.contact.ordinary.sylvia.day6.b`, `reply.contact.ordinary.sylvia.day6.c` | `line.contact.ordinary.sylvia.day6.reply.a`, `line.contact.ordinary.sylvia.day6.reply.b`, `line.contact.ordinary.sylvia.day6.reply.c` | `atom.echo.sylvia.day6.reply.a.fallback.day7`, `atom.echo.sylvia.day6.reply.b.fallback.day7`, `atom.echo.sylvia.day6.reply.c.fallback.day7` |

Also register exactly four full P–L observation atoms: `atom.pair.day2.group.full`, `atom.pair.day2.twofriends.full`, `atom.pair.day6.group.full`, and `atom.pair.day6.twofriends.full`. Records contain IDs/ownership only, no invented wording. Production Observer evidence capabilities remain absent/disabled until an approved content card supplies an exact source entry/atom; fixture-only capabilities are marked test-only and can never mutate a production profile.
- [ ] Implement:

```gdscript
class_name DialogicEntryManifest
extends RefCounted

static func load_default() -> Dictionary
static func validate_document(document: Dictionary) -> Dictionary
static func resolve_entry(document: Dictionary, entry_id: String, locale: String) -> Dictionary
static func validate_signal(document: Dictionary, entry_id: String, stage: StringName, signal_id: String, payload: Dictionary) -> Dictionary
static func validate_line_id(document: Dictionary, entry_id: String, line_id: String) -> Dictionary
static func validate_atom_id(document: Dictionary, entry_id: String, atom_id: String) -> Dictionary
static func fingerprint(document: Dictionary) -> String
```

- [ ] `resolve_entry()` returns the selected-locale locator only when both path and exact label validate; otherwise it returns the same entry's English locator and `used_fallback = true`. Missing/duplicate English label is a failure.
- [ ] `FrozenPresentationContext.validate(entry_record, context)` deep-copies only primitives and rejects undeclared extras. It must implement each role-family table in section 12.3, including group open/reply fields, `attempt_residue_id`, and `alone_cause`.
- [ ] Run GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_manifests' -LogName 'dialogic-manifests.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_timeline_manifest.gd,res://tests/unit/test_frozen_presentation_context.gd','-gexit')
```

- [ ] Commit:

```text
feat(dialogic): add closed semantic entry contracts
```

## Task 3: Generate and validate the eight plot-neutral masters

**Specification:** Sections 12.1, 12.7, 13, 16.4.

**Files:**

- Create: `tools/dialogic/DtlStructureValidator.gd`
- Create: `tools/dialogic/generate_master_skeletons.gd`
- Create: `tools/dialogic/validate_manifests.gd`
- Create: `dialogic/timelines/en/day_1.dtl`
- Create: `dialogic/timelines/en/day_2.dtl`
- Create: `dialogic/timelines/en/day_3.dtl`
- Create: `dialogic/timelines/en/day_4.dtl`
- Create: `dialogic/timelines/en/day_5.dtl`
- Create: `dialogic/timelines/en/day_6.dtl`
- Create: `dialogic/timelines/en/day_7.dtl`
- Create: `dialogic/timelines/en/endings.dtl`
- Add import-generated sidecars only when Godot creates them: the eight adjacent `.dtl.uid` files
- Modify as an expected Dialogic import result: `project.godot`
- Replace: `tests/smoke_dialogic_timelines.gd`

- [ ] First replace the unconditional smoke with failing structural assertions:

  - exactly eight target master paths exist;
  - manifest count is 139 and every locator label occurs exactly once;
  - day label counts are `10, 24, 20, 13, 13, 24, 17`; ending callable-label count is `18`;
  - the first executable event in each master is `return`;
  - each public label's next terminal boundary is its own `return`;
  - no label falls into its neighbor;
  - no unregistered label, signal, variable, effect, line, atom, or visual path exists;
  - no final dialogue line or arbitrary visual path appears in structural mode.

- [ ] Run RED. Expected failure: eight masters/validator do not exist and current smoke has no assertions.
- [ ] Implement the generator from the explicit manifest. It emits only:

```text
# Master timeline: presentation only.
return

label contact.ordinary.lavinia.day1
# PURPOSE: ordinary_message
# CAUSAL INPUT: validated frozen context
# VARIATION: registered layer order
# ALLOWED SIGNALS: message.reply.commit, history.line.witness, message.echo.satisfy
return
```

The shown Lavinia label is the concrete format example; generation substitutes each of the other 138 exact manifest IDs and that entry's exact registered role and signal list.

- [ ] Generated comments may contain IDs and schema roles, never plot material or dialogue.
- [ ] The static validator parses DTL text without executing arbitrary events. It detects duplicate labels, missing leading/per-entry returns, unregistered signal JSON, direct domain method calls, dynamic resource paths, and neighboring-label fallthrough.
- [ ] `tools/dialogic/validate_manifests.gd` extends `SceneTree`, awaits validation to completion, prints bounded diagnostics, and exits nonzero on any failure.
- [ ] Editor import may register the eight new resources alongside the 61 legacy resources, producing 69 coexistence registrations in `project.godot`. Treat that exact import change as expected task output; runtime resolution still accepts only the eight manifest-owned master paths.
- [ ] Import and validate:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_import' -LogName 'dialogic-import.log' -GodotArgs @('--editor','--quit-after','1')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_manifest_cli' -LogName 'dialogic-manifest-cli.log' -GodotArgs @('-s','res://tools/dialogic/validate_manifests.gd')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_structure' -LogName 'dialogic-structure.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/smoke_dialogic_timelines.gd','-gexit')
```

- [ ] Commit:

```text
feat(dialogic): add eight plot-neutral master timelines
```

Do not manually prune `project.godot` or delete old files in this task; preserve the coexistence registration produced by import until the authorized cutover.

## Task 4: Replace permissive catalog lookup with exact locators

**Specification:** Sections 4.1, 12.2, 14.1.

**Files:**

- Modify: `scripts/data/DialogicTimelineCatalog.gd`
- Create: `tests/unit/test_dialogic_timeline_catalog.gd`
- Modify: `tests/integration/test_profile_reset_consumers.gd`

- [ ] Write RED tests proving arbitrary suffixes, retired `.true` IDs, missing labels, duplicate labels, and unsupported locale fabrication fail.
- [ ] Replace `_relative_path()`, `_contact_path()`, `_dating_path()`, and pattern-based `has_timeline_id()` with manifest delegation.
- [ ] Provide the compatibility surface:

```gdscript
static func get_entry(entry_id: String, locale: String = "") -> Dictionary
static func has_entry_id(entry_id: String) -> bool
static func get_required_entry_ids() -> Array[String]
static func get_required_master_paths(locale: String = "en") -> Array[String]
static func build_validation_report(locale: String = "en") -> Dictionary
```

- [ ] Keep `get_timeline_path()` only as a deprecated read-only compatibility query during migration. It must call `get_entry()` and return empty on failure; no production caller may use it by the Plan 06 gate.
- [ ] Replace the integration test's external `start_timeline_path()` call with a registered semantic fixture entry.
- [ ] Run GREEN and commit:

```text
refactor(dialogic): resolve timelines through exact entry locators
```

## Task 5: Make DialogicBridge label-aware and token-bound

**Specification:** Sections 12.3–12.5, 12.8, 14.1–14.3.

**Files:**

- Modify: `autoload/DialogicBridge.gd`
- Create: `scripts/narrative/DialogicSignalCommandPort.gd`
- Create: `scripts/narrative/DialogicPlaybackCompletionPort.gd`
- Create: `tests/support/FakeDialogicSignalCommandPort.gd`
- Create: `tests/support/FakeDialogicPlaybackCompletionPort.gd`
- Create: `tests/integration/test_dialogic_bridge_contract.gd`
- Create: `tests/integration/test_dialogic_signal_boundary.gd`

- [ ] Write RED tests for label-aware start, immutable context, exact locale fallback, one active token, stale/mismatched completion, unknown signal, wrong payload, forbidden source/stage, duplicate identical receipt, conflicting receipt, and Rehearsal capability denial.
- [ ] Replace `Dialogic.start(path)` with `Dialogic.start(path, label)` after manifest/context validation.
- [ ] Add the production-safe API:

```gdscript
func start_entry(entry_id: String, context: Dictionary, execution_mode: StringName = &"canonical") -> Dictionary
func resume_entry(checkpoint: Dictionary, execution_mode: StringName = &"canonical") -> Dictionary
func acknowledge_signal(signal_id: String, payload: Dictionary) -> Dictionary
func abort_current_entry(code: StringName) -> Dictionary
func capture_restore_state() -> Dictionary
```

The success result contains `entry_id`, `playback_token`, `content_version`, `context_fingerprint`, `path`, `label`, and `used_locale_fallback`; callers persist only the semantic fields/fingerprints.

- [ ] Connect Dialogic's real `timeline_ended` and `signal_event` once. Physical completion advances nothing directly; it calls one configured `DialogicPlaybackCompletionPort.complete_entry(intent)` with exact primitive keys `entry_id`, `transaction_id`, `stage`, `playback_token`, `context_fingerprint`, `execution_mode`, and `completion_kind = natural_end`.
- [ ] Enforce one active entry. A playback token is unique and process-local; restore revalidates the durable semantic checkpoint and issues a fresh token. An old-process token is always stale. `abort_current_entry()` reports a failure/aborted result and can never masquerade as natural completion.
- [ ] `DialogicSignalCommandPort` is an interface/adapter with one method:

```gdscript
func commit_signal(entry_id: String, stage: StringName, signal_id: String, payload: Dictionary, execution_mode: StringName) -> Dictionary:
	return {"ok": false, "code": &"not_configured"}
```

- [ ] Every state-capable signal is an acknowledged boundary. On rejection, pause/abort at the registered continuation stage and never show consequence-dependent prose.
- [ ] Retire every legacy bypass: production `start_timeline_path()` fails; old `start_timeline_id()` may only be a strict compatibility delegate to `start_entry()`; manual `finish_current_timeline()` and arbitrary `timeline_marker()` are removed or fail closed. Only Dialogic's real `timeline_ended` and `signal_event` may drive completion/signals. Add static scans and direct rejection tests for all four surfaces.
- [ ] Run GREEN and commit:

```text
feat(dialogic): bind semantic playback to labels and receipts
```

## Task 6: Validate stable lines, atoms, and visuals without inventing content

**Specification:** Sections 9, 12.6–12.8, 14.2.

**Files:**

- Modify: `autoload/ProfileManager.gd`
- Modify: `scripts/data/ArtManifest.gd`
- Modify: `tools/dialogic/DtlStructureValidator.gd`
- Create: `tests/unit/test_dialogic_identity_registries.gd`
- Create: `tests/unit/test_art_manifest.gd`

- [ ] Write RED tests proving `ProfileManager.mark_line_visited()` rejects unknown line IDs, DTL cannot compose a resource path, required missing/wrong-type visuals reject before playback, and optional visuals use only a declared neutral fallback ID.
- [ ] Make `ProfileManager` validate line identity through the manifest before preparing a visited-line mutation. Do not permit saved wording or BBCode to become an identity.
- [ ] Replace the empty `ArtManifest` stub with strict semantic visual records:

```gdscript
{
	"visual_id": "visual.neutral.background",
	"resource_path": String,
	"resource_type": "Texture2D",
	"required": false,
	"fallback_visual_id": null
}
```

Do not populate invented art paths. In structural mode, entry visual lists remain empty; the neutral fallback record is added only when an existing verified neutral asset exists.
- [ ] Extend static validation to reject raw unregistered Background/Character/Portrait paths and unsafe JSON signal payloads.
- [ ] Run GREEN and commit:

```text
feat(dialogic): close line atom and visual identities
```

## Task 7: Prepare semantic narrative restore without production cutover

**Specification:** Sections 10.1, 12.4, 14.3–14.4.

**Files:**

- Modify: `scripts/application/restore/NarrativeRestoreParticipant.gd`
- Modify: `autoload/DialogicBridge.gd`
- Create: `tests/integration/test_dialogic_restore.gd`
- Modify: `tests/integration/test_restore_production_adapters.gd`

- [ ] Write RED tests for empty narrative state, pending semantic entry restore, post-commit continuation restore, incompatible content fingerprint, missing entry, and physical path/label injection.
- [ ] Upgrade the existing participant; do not create a second narrative restore owner. Its prepared plan contains only:

```gdscript
{
	"entry_id": String,
	"stage": String,
	"transaction_id": String,
	"frozen_context": Dictionary,
	"content_version": int,
	"manifest_fingerprint": String,
}
```

- [ ] `prepare()` validates semantics and compatibility without starting Dialogic. `apply_silent()` stores the plan. `finalize()` calls `resume_entry()` for the exact registered entry/stage only after the entire restore transaction succeeds; the bridge issues a new process-local playback token while retaining the durable transaction ID.
- [ ] Future/unmappable content rejects non-destructively. It never substitutes Alone, day start, the top of a master, or a neighboring label.
- [ ] Run restore integration GREEN and commit:

```text
feat(dialogic): restore semantic entries by validated stage
```

## Phase 01 Verification Gate

- [ ] 139 explicit entries and 13 ending IDs validate; retired/unknown IDs fail.
- [ ] Eight master files exist with counts `10/24/20/13/13/24/17/18`, safe leading returns, and isolated label returns.
- [ ] All selected-locale failures fall back to the exact English entry/label only.
- [ ] `DialogicBridge` calls the real label-aware API and rejects direct production path starts.
- [ ] Context, signals, lines, atoms, and visuals are closed and source-scoped.
- [ ] Narrative restore persists semantic identity and stage only.
- [ ] The 61 old DTL/UID files and current `project.godot` registry remain intact pending final cutover.
- [ ] No final prose or invented asset path was added.
