# Phase 2R Dialogic, Effects, and Skip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Make Dialogic the sole validated narrative playhead, replace filename inference and unconditional smoke tests with exact manifests and a physical fixture, commit effects idempotently, persist semantic checkpoints, and implement global read history with read-only/all-text skip.

**Architecture:** Exact JSON manifests register every narrative ID and physical locator. DialogicRuntimeAdapter wraps only APIs proven in the installed Dialogic Alpha-19 source. DialogicBridge translates addon events into validated semantic commands, stable checkpoints, and typed notifications. EffectResolver resolves allowlisted descriptors without mutation; GameState commits an entire transaction atomically. SkipPolicy is a pure boundary decision over pre-reveal visited state.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, Dialogic 2.0-Alpha-19, strict JSON/manifests, ProfileManager visited history, and on-tree asynchronous integration tests.

## Global Constraints

- This plan owns dwm-p2r.8 and starts after .3, .4, .5, and .6 close and the dwm-p2r.7.1 handoff contract (`docs/superpowers/specs/2026-08-08-phase-2r-7-to-8-dialogic-handoff-contract.md`) is committed. It does NOT require all of .7 to close: the corrected order is .8 -> dwm-7e6 -> remaining .7 tails, so .7 stays open for work ordered after .8/dwm-7e6. The frozen .7 interface .8 consumes (11 ending ids, physical-label dispositions, playback stages/context, postscript+audio ownership, ending vs effect ledger ownership) is that contract.
- Dialogic alone owns the timeline/event index. UI nodes never maintain another narrative index or write gameplay variables.
- Saved checkpoints contain stable semantic IDs, never arbitrary paths or Dialogic.get_full_state().
- Unknown timeline, line, label, marker, effect, variable, route, and ending IDs reject before mutation.
- Every effect transaction is all-or-nothing and idempotent.
- skip_mode is exactly read_only or all_text; invalid/missing profile values normalize to read_only.
- Skip always reveals the current line and stops before every approved boundary event.
- Narrative checkpoints carry an exact manifest-validated boundary event and post-event resume locator; restoring a transaction boundary never replays the completed event or skips its registered successor.
- Existing narrative prose is not rewritten. This plan may remove four obsolete contact labels, rename/retire the three ending `.true` labels, and add missing ending labels/TODO-only placeholders; it invents no dialogue prose or translation.
- Preserve plan `.3`'s `bind_profile_preferences`, `apply_profile_preferences`, and `reapply_cached_preferences_after_clear` seams. Every explicit Dialogic clear/start in this plan MUST reapply the cached committed profile plan synchronously before the first restored/new event.
- Proposed commits require separate explicit authority.
- `implementation_authorized: true` as of 2026-07-18 for the exact task-scoped runtime, generated-manifest, test, and ordinary Beads execution changes below after blockers close. Git history remains separately unauthorized.
- Tasks 4, 5, and 6 are three non-squashable exact-path boundaries. Task 5 requires committed Task 4; Task 6 requires committed Task 5 plus closed `dwm-p2r.8`. The Plan-05 reconciliation itself rides in the Task-4 boundary so the frozen Task-3 parent remains exact.
- Every proposed commit invokes Plan 01's checked-in `tools/git/Invoke-ExactPathCommit.ps1`. The helper itself requires `DWM_COMMIT_AUTHORIZED=1`, distinguishes Git quiet exit `0`, `1`, and error, stages every literal non-UID requirement plus only explicitly listed newly generated `.uid` companions that are present, accepts only each declared `A`/`M`/`D` status, and rejects an empty/missing/extra/malformed/duplicate/rename/copy/type/unmerged staged record. Unless a map explicitly supplies another frozen mode, every Plan-05 entry requires regular-file mode `100644` before and after; symlink, gitlink, executable-bit, and all other mode/type drift reject. It runs the cached diff check, commits one direct child of the supplied `ExpectedHead`, and verifies the new commit's exact path/status/mode/cardinality. Existing `.uid` identities are read-only HEAD-blob bindings, never optional staged files. `.beads/issues.jsonl` and `.beads/interactions.jsonl` are the only explicitly allowed unstaged Beads paths; a boundary stages either only when its required-status map names it.

---

## Task 1: Pin the installed Dialogic API and generate exact manifests

**Beads:** dwm-p2r.8

**Files:**

- Create: tools/dialogic/DialogicApiAudit.gd
- Create: tools/dialogic/TimelineManifestBuilder.gd
- Create: tools/dialogic/TimelineManifestValidator.gd
- Create: tools/dialogic/validate_manifests.gd
- Create: schemas/manifests/timelines.schema.json
- Create: schemas/manifests/id-registry.schema.json
- Create: data/manifests/timelines.json
- Create: data/manifests/effects.json
- Modify: data/manifests/narrative_variables.json (created as the initial empty registry by Plan 03)
- Create: data/manifests/routes.json
- Create: data/manifests/endings.json
- Create: tests/unit/test_timeline_manifest.gd
- Generate: evidence/phase_2r/dialogic/addon_api.json
- Generate: evidence/phase_2r/dialogic/timeline_inventory.json
- Modify: scripts/data/DialogicTimelineCatalog.gd
- Modify structurally: dialogic/timelines/en/contacts/priscilla_day2.dtl
- Modify structurally: dialogic/timelines/en/contacts/priscilla_day6.dtl
- Modify structurally: dialogic/timelines/en/contacts/lavinia_day2.dtl
- Modify structurally: dialogic/timelines/en/contacts/lavinia_day6.dtl
- Modify structurally: dialogic/timelines/en/ending/alone.dtl
- Modify structurally: dialogic/timelines/en/ending/priscilla_lavinia.dtl
- Modify structurally: dialogic/timelines/en/ending/priscilla.dtl
- Modify structurally: dialogic/timelines/en/ending/lavinia.dtl
- Modify structurally: dialogic/timelines/en/ending/sylvia.dtl

**Interfaces:**

- Consumes: exact installed Dialogic source; canonical timeline/route/effect/variable/ending ID sets; the initial empty production narrative-variable registry created by `.5`.
- Produces: strict manifests plus `DialogicTimelineCatalog.initialize/has_timeline_id/get_record/get_path_for_id/get_line_record/get_event_record/validate_successor/validate_all`; `endings.json` is the sole ending-ID-to-physical-locator map.

- [ ] **Step 1.1: Claim .8 and write manifest RED tests**

- [ ] Run:

~~~powershell
bd show dwm-p2r.3 --json
bd show dwm-p2r.4 --json
bd show dwm-p2r.5 --json
bd show dwm-p2r.6 --json
bd show dwm-p2r.7.1 --json
bd update dwm-p2r.8 --claim
~~~

.3-.6 must be CLOSED and dwm-p2r.7.1 (the .7->.8 Dialogic handoff contract) must be CLOSED. Do NOT require all of dwm-p2r.7 to close: per the corrected graph .7 stays open for tails ordered after .8/dwm-7e6. Verify the frozen 11-id ending table, physical-label dispositions, playback stages/context, and ledger/ownership decisions from `docs/superpowers/specs/2026-08-08-phase-2r-7-to-8-dialogic-handoff-contract.md`.

- [ ] Tests assert exactly 61 production English timeline records, one physical file per record, one unique timeline_id header per file, no unregistered .dtl file, and no inferred path API.

- [ ] Create the parse-safe first RED assertion before any manifest or builder exists:

~~~gdscript
extends "res://addons/gut/test.gd"

const MANIFEST_PATH := "res://data/manifests/timelines.json"

func test_exact_timeline_manifest_is_required() -> void:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "missing timelines.json")
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed := StrictJson.parse_object(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed.get("ok", false), str(parsed))
~~~

- [ ] A timeline record is exactly:

~~~json
{
  "id": "dating.solo.sylvia.day3.pre_challenge",
  "locale": "en",
  "path": "dialogic/timelines/en/dating/solo/sylvia_day3_pre_challenge.dtl",
  "content_status": "draft",
  "content_fingerprint": "sha256:fbd646179783eed4c46b9cf8746cc6e720026f971f589372e461527c6604a3d2",
  "labels": [],
  "lines": [],
  "markers": [],
  "effect_ids": [],
  "variable_ids": [],
  "route_ids": [],
  "ending_ids": [],
  "events": []
}
~~~

The displayed digest is the current SHA-256 of that physical file. The builder regenerates it from exact UTF-8 file bytes and fails on drift.

Each `events` entry is exact and ordered by `event_index`:

~~~json
{
  "event_id": "dating.solo.sylvia.day3.pre_challenge@0:text",
  "event_index": 0,
  "event_kind": "text",
  "semantic_id": "dating.solo.sylvia.day3.line.1",
  "post_event_id": "dating.solo.sylvia.day3.pre_challenge@1:choice",
  "post_event_index": 1
}
~~~

`event_id` is the registered `<timeline_id>@<event_index>:<event_kind>` locator and is valid only with the record's exact content fingerprint. `post_event_id/index` identifies the statically validated successor for that branch; terminal events use null/null. Choice records store one successor pair per registered choice ID. Builder/validator reject duplicate indices/IDs, gaps, wrong kinds, a successor that is not a legal imported control-flow edge, and a semantic ID absent from the matching line/choice/marker/effect/variable/route registry.

- [ ] Run the test before building manifests:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_manifest_red' -LogName 'phase2r-red-dialogic-manifest.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_timeline_manifest.gd','-gexit')
~~~

Expected RED: timelines.json is absent.

- [ ] **Step 1.2: Record only physically verified addon APIs**

- [ ] DialogicApiAudit reads installed addon source and records file, line, signature, and SHA-256 evidence for:

~~~text
Dialogic.start(timeline, label_or_idx) -> Node
Dialogic.start_timeline(timeline, label_or_idx) -> void
Dialogic.end_timeline(skip_ending)
Dialogic.handle_next_event(_ignore_argument: Variant = "") -> void
Dialogic.handle_event(event_index: int) -> void
Dialogic.current_timeline
Dialogic.current_timeline_events
Dialogic.current_event_idx
Dialogic.timeline_started
Dialogic.timeline_ended
Dialogic.event_handled(resource)
Dialogic.signal_event(argument)
Dialogic.Text.text_started(info)
Dialogic.Text.text_finished(info)
Dialogic.Text.skip_text_reveal() -> void
Dialogic.Choices.question_shown(info)
Dialogic.Choices.choice_selected(info)
Dialogic.Choices.select_choice(choice_index: int) -> void
~~~

The initial evidence must point to `addons/dialogic/Core/DialogicGameHandler.gd`, `Modules/Text/subsystem_text.gd`, `Modules/Choice/subsystem_choices.gd`, and every event serializer used by the fixture (`Text`, `Choice`, `Signal`, `Label`, `Return`). It records exact source hashes and callable/subsystem lookup. If a signature differs when implementation begins, stop and update this plan rather than guessing.

- [ ] **Step 1.3: Build exact status and ID records**

- [ ] Before manifest generation, make only these machine-checkable structural corrections: remove `need_reply_priscilla_first` from the `# parts` header and delete its label/TODO block in the four listed Day-2/Day-6 Priscilla/Lavinia contact files; add `label ending.alone` and `label ending.priscilla_lavinia` to their currently label-less files; in `priscilla.dtl` rename `label ending.priscilla.true` to `label ending.priscilla.observation` and replace `true` with `observation` in `# contains`; in `lavinia.dtl` make the corresponding `.true` to `.observation` label/header rename; in `sylvia.dtl` replace `label ending.sylvia.true` with `label ending.sylvia.special`, replace `true` with `special` in `# contains`, and reuse the existing TODO-only Sylvia placeholder beneath that label. Then TimelineManifestBuilder reads without further rewrite and validates comment timeline_id, locale, type metadata, labels, branches, signal payloads, variables, and return/transition structure. Source/manifest scans for `need_reply_priscilla_first` and the three retired `.true` ending IDs must return no live-record matches; migration/frozen-localization references are outside the production ending manifest and remain allowed.
- [ ] Status derivation is exact:

~~~text
contains a TODO marker -> placeholder
no TODO and no explicit approval evidence -> draft
explicit approved evidence -> approved
explicit final evidence -> final
~~~

Initial expected status counts remain 24 placeholder and 37 draft. The three renamed friend-ending files retain their existing TODO markers, while the newly labelled Alone and Priscilla-Lavinia files retain no TODO marker; therefore these structural edits do not change file-level status. No current record is approved/final.

- [ ] Existing broad filename construction in DialogicTimelineCatalog is replaced by strict manifest lookup:

~~~gdscript
static func initialize(
	manifest_path: String = "res://data/manifests/timelines.json"
) -> Dictionary
static func has_timeline_id(timeline_id: String) -> bool
static func get_record(timeline_id: String) -> Dictionary
static func get_path_for_id(timeline_id: String) -> Dictionary
static func get_line_record(
	timeline_id: String,
	line_id: String
) -> Dictionary
static func get_event_record(timeline_id: String, event_id: String) -> Dictionary
static func validate_successor(
	timeline_id: String,
	event_id: String,
	post_event_id: Variant,
	choice_id: Variant = null
) -> Dictionary
static func validate_all() -> Dictionary
~~~

Only en narrative records exist. LocalizationManager language selection does not manufacture zh_CN/zh_HK paths.

- [ ] Generate effects.json from the current EffectResolver allowlist, routes.json from the registered SceneRouter IDs, and extend the initial narrative_variables.json only with explicitly audited production variables. Validators prove runtime constants and manifests match exactly.

- [ ] The endings registry schema and `TimelineManifestValidator` accept role exactly `primary|postscript|epilogue`; any other value fails closed. They prove the manifest primary set equals `DatingEndingRules.VALID_PRIMARY_IDS`, the postscript set equals `DatingEndingRules.POSTSCRIPT_IDS`, the only epilogue is `ending.priscilla_lavinia`, and the union of all three role sets equals `DatingEndingRules.CANONICAL_ENDING_IDS` exactly.

- [ ] `endings.json` contains exactly eleven records with keys `ending_id`, `role`, `timeline_id`, and `label`:

~~~text
ending.alone                  primary     ending.alone               ending.alone
ending.priscilla.sweet        primary     ending.priscilla           ending.priscilla.sweet
ending.priscilla.dark         primary     ending.priscilla           ending.priscilla.dark
ending.lavinia.sweet          primary     ending.lavinia             ending.lavinia.sweet
ending.lavinia.dark           primary     ending.lavinia             ending.lavinia.dark
ending.sylvia.sweet           primary     ending.sylvia              ending.sylvia.sweet
ending.sylvia.dark            primary     ending.sylvia              ending.sylvia.dark
ending.sylvia.special         primary     ending.sylvia              ending.sylvia.special
ending.priscilla.observation  postscript  ending.priscilla           ending.priscilla.observation
ending.lavinia.observation    postscript  ending.lavinia             ending.lavinia.observation
ending.priscilla_lavinia      epilogue    ending.priscilla_lavinia   ending.priscilla_lavinia
~~~

Every locator must resolve to the exact physical timeline and label before an EndingPlan can validate or playback can start. Unknown/missing/mis-role records fail manifest validation. `ending.priscilla.true`, `ending.lavinia.true`, and `ending.sylvia.true` are retired, never aliased by `endings.json`, and must be rejected by validation before playback or mutation.

- [ ] **Step 1.4: Validate manifests**

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_manifests_validate' -LogName 'phase2r-dialogic-manifests.log' -GodotArgs @('-s','res://tools/dialogic/validate_manifests.gd')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_manifests_tests' -LogName 'phase2r-timeline-manifest-tests.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_timeline_manifest.gd','-gexit')
~~~

Expected GREEN: 61 exact records, 24 placeholder, 37 draft, zero unregistered IDs/paths, and no broad pattern lookup.

- [ ] **Step 1.5: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 1 Step 1.5 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$') {
	throw 'Task 1 Step 1.5 could not bind the prerequisite HEAD.'
}
$required = [ordered]@{
	'tools/dialogic/DialogicApiAudit.gd' = 'A'
	'tools/dialogic/TimelineManifestBuilder.gd' = 'A'
	'tools/dialogic/TimelineManifestValidator.gd' = 'A'
	'tools/dialogic/validate_manifests.gd' = 'A'
	'schemas/manifests/timelines.schema.json' = 'A'
	'schemas/manifests/id-registry.schema.json' = 'A'
	'data/manifests/timelines.json' = 'A'
	'data/manifests/effects.json' = 'A'
	'data/manifests/narrative_variables.json' = 'M'
	'data/manifests/routes.json' = 'A'
	'data/manifests/endings.json' = 'A'
	'tests/unit/test_timeline_manifest.gd' = 'A'
	'evidence/phase_2r/dialogic/addon_api.json' = 'A'
	'evidence/phase_2r/dialogic/timeline_inventory.json' = 'A'
	'scripts/data/DialogicTimelineCatalog.gd' = 'M'
	'dialogic/timelines/en/contacts/priscilla_day2.dtl' = 'M'
	'dialogic/timelines/en/contacts/priscilla_day6.dtl' = 'M'
	'dialogic/timelines/en/contacts/lavinia_day2.dtl' = 'M'
	'dialogic/timelines/en/contacts/lavinia_day6.dtl' = 'M'
	'dialogic/timelines/en/ending/alone.dtl' = 'M'
	'dialogic/timelines/en/ending/priscilla_lavinia.dtl' = 'M'
	'dialogic/timelines/en/ending/priscilla.dtl' = 'M'
	'dialogic/timelines/en/ending/lavinia.dtl' = 'M'
	'dialogic/timelines/en/ending/sylvia.dtl' = 'M'
}
$optionalUids = [ordered]@{
	'tools/dialogic/DialogicApiAudit.gd.uid' = 'A'
	'tools/dialogic/TimelineManifestBuilder.gd.uid' = 'A'
	'tools/dialogic/TimelineManifestValidator.gd.uid' = 'A'
	'tools/dialogic/validate_manifests.gd.uid' = 'A'
	'tests/unit/test_timeline_manifest.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'feat(dialogic): register exact timeline and narrative manifests'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 1 commit boundary failed.' }
~~~

## Task 2: Wrap Dialogic with semantic checkpoints and restore

**Beads:** dwm-p2r.8

**Files:**

- Create: scripts/narrative/DialogicRuntimeAdapter.gd
- Create: scripts/narrative/NarrativeCheckpointSchema.gd
- Create: scripts/application/ending/DialogicEndingPlaybackPort.gd
- Create: scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd
- Create: tests/support/FakeDialogicRuntime.gd
- Create: tests/support/FakeNarrativeCheckpointContext.gd
- Create: tests/unit/test_dialogic_runtime_adapter.gd
- Create: tests/unit/test_narrative_checkpoint_schema.gd
- Create: tests/unit/test_dialogic_ending_playback_port.gd
- Create: tests/unit/test_save_manager_narrative_checkpoint_port.gd
- Create: tests/integration/test_dialogic_restore.gd
- Create: tests/integration/test_ending_dialogic_wiring.gd
- Create: tests/integration/test_narrative_checkpoint_wiring.gd
- Modify: autoload/DialogicBridge.gd
- Modify: autoload/ApplicationBootstrap.gd
- Modify: autoload/GameState.gd
- Modify: autoload/SceneRouter.gd
- Modify: scripts/data/AudioManifest.gd
- Bind read-only: scripts/data/AudioManifest.gd.uid (must equal its regular-file HEAD blob and is never staged)
- Modify: tests/unit/test_audio_manager.gd
- Bind read-only: tests/unit/test_audio_manager.gd.uid (must equal its regular-file HEAD blob and is never staged)
- Consume without modification: autoload/SaveManager.gd and its Plan-03 newest-to-oldest all-six participant preparation algorithm; it never becomes the narrative adapter
- Modify: scripts/application/restore/NarrativeRestoreParticipant.gd (created by Plan 03)
- Optional generated UID: scripts/application/restore/NarrativeRestoreParticipant.gd.uid (absent from the frozen Task-1 HEAD; stage as `A` only if Godot generates it)
- Modify: tests/integration/test_restore_production_adapters.gd
- Modify: tests/integration/test_restore_transaction.gd
- Modify: scripts/ui/OpeningScene.gd
- Modify: scripts/ui/TutorialOverlay.gd
- Modify: scripts/ui/HospitalScene.gd
- Modify: scripts/ui/DatingScene.gd
- Modify: scripts/ui/EndingScene.gd

**Interfaces:**

- Consumes: Task 1 manifests; master `DialogicRuntimeAdapter`/`DialogicBridge` signatures; Plan 03's one real `SaveManagerCheckpointPort`, exact checkpoint input contract, six-participant common `prepare(input)` contract, and private newest-to-oldest `_prepare_bundle_with_all_participants(bundle,migrated_document)` algorithm; and `.7`'s injected `EndingPlaybackPort` seam. The `.7` GameState `play_ending` CommandResult value has exactly `kind`, `ending_id`, and `playback_context`; `playback_context` has exactly `playback_id`, `transaction_id`, `expected_stage`, and `role` and is passed unchanged through EndingScene and the production port.
- Produces: `NarrativeCheckpointSchema.build/validate`; `SaveManagerNarrativeCheckpointPort` as the single configured narrative-checkpoint adapter shared by DialogicBridge and GameState; the read-only `GameState.capture_run_snapshot_input()` provider; `DialogicBridge.start_timeline_id()`, `start_ending_id()`, and bridge-only `start_postscript_id()` CommandResults plus semantic checkpoint capture; an exact 11-ending-id audio map; `DialogicEndingPlaybackPort` as the production `.7` primary/epilogue adapter with immediate-start and physical-completion receipts; and the real Plan-03-created `NarrativeRestoreParticipant` implementation. Low-level restore is `prepare_runtime_restore(checkpoint, manifest)` while that registered participant still exposes exactly `prepare(input)/capture/apply_silent/rollback_silent/finalize`. ApplicationBootstrap configures the shared checkpoint adapter and ending port through existing stages, and SceneRouter injects the one production ending port. No production caller schedules a postscript in this task.

- [ ] **Step 2.1: Write adapter RED tests against a fake runtime**

- [ ] Start each new test through a dynamic script load so missing production files fail by assertion rather than parse error:

~~~gdscript
extends "res://addons/gut/test.gd"

func test_runtime_adapter_and_checkpoint_schema_are_required() -> void:
	for path in [
		"res://scripts/narrative/DialogicRuntimeAdapter.gd",
		"res://scripts/narrative/NarrativeCheckpointSchema.gd",
		"res://scripts/application/ending/DialogicEndingPlaybackPort.gd",
		"res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd",
	]:
		assert_true(ResourceLoader.exists(path, "Script"), "missing %s" % path)
~~~

- [ ] Use the shared master interface exactly; the low-level adapter adds:

~~~gdscript
func capture_restore_state() -> Dictionary
func restore_captured_state(backup: Dictionary) -> Dictionary
func halt_with_error(result: Dictionary) -> Dictionary
~~~

- [ ] Tests prove only the physically audited signals/methods are connected/called, signal connections are made once, a missing subsystem returns a safe error, and no complete addon state is serialized.
- [ ] Ending-port RED cases pass the exact Plan04 `playback_context` unchanged, assert the bridge's six-field receipt and the port's seven-field receipt are in the outer CommandResult `receipt` with `value={}`, then emit a matching asynchronous failure and assert the next identical request starts again with a different opaque token. They also prove a mismatched token cannot clear the active binding.

- [ ] Run RED before creating any production adapter/schema/port:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_adapter_red' -LogName 'phase2r-red-dialogic-adapter.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dialogic_runtime_adapter.gd,res://tests/unit/test_narrative_checkpoint_schema.gd,res://tests/unit/test_dialogic_ending_playback_port.gd','-gexit')
~~~

Expected RED: the first missing production script is reported; no parse error, real timeline start, profile write, or production save access is acceptable.

- [ ] **Step 2.2: Define the semantic checkpoint shape**

- [ ] Narrative checkpoint JSON is exactly:

~~~json
{
  "schema_version": 1,
  "timeline_id": "fixture.phase2r.contract",
  "content_fingerprint": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "last_committed_line_id": "fixture.line.after_choice",
  "boundary": {
    "kind": "effect_transaction",
    "semantic_id": "fixture.effect.tx",
    "transaction_id": "fixture-run:effect:1"
  },
  "event": {
    "event_id": "fixture.phase2r.contract@4:effect_transaction",
    "event_index": 4,
    "event_kind": "effect_transaction",
    "semantic_id": "fixture.effect.tx"
  },
  "post_event": {
    "position": "before_event",
    "event_id": "fixture.phase2r.contract@5:variable_transaction",
    "event_index": 5,
    "event_kind": "variable_transaction",
    "semantic_id": "fixture.variable.tx"
  },
  "timeline_completed": false
}
~~~

`boundary.kind` is exactly `timeline_start|line|choice|effect_transaction|variable_transaction|safe_marker|scene_transition|timeline_complete`. `semantic_id` is null only for timeline start/completion; `transaction_id` is nonempty only for choice/effect/variable/marker/transition receipts. `event` is the exact completed/revealed manifest event. `post_event.position` is exactly `revealed_event`, `before_event`, `external_route`, or `timeline_complete`: line checkpoints use the same text event with `revealed_event`; choice/effect/variable/marker checkpoints use the branch-validated successor with `before_event`; scene transitions use null event fields plus `external_route`; completion uses null event fields plus `timeline_complete`. `last_committed_line_id` is null only before the first line. Raw paths, arbitrary event objects, unregistered indices, mismatched kinds/semantic IDs, wrong fingerprints, illegal control-flow successors, and inconsistent nullable fields reject.

- [ ] Implement the schema as a pure boundary:

~~~gdscript
class_name NarrativeCheckpointSchema
extends RefCounted

static func build(
	timeline_record: Dictionary,
	boundary: Dictionary,
	event: Dictionary,
	post_event: Dictionary,
	last_committed_line_id: Variant,
	timeline_completed: bool
) -> Dictionary

static func validate(checkpoint: Dictionary, timeline_record: Dictionary) -> Dictionary
~~~

Both functions recursively copy collections. `validate()` resolves `event` and `post_event` from the manifest rather than trusting saved indices, then requires saved and registered records to match exactly.

- [ ] Stable checkpoints occur after:

~~~text
timeline start
every fully committed text_finished line
choice selection
validated effect transaction
validated variable transaction
validated safe marker
scene transition
timeline completion
~~~

A partially revealing line is not stable. Restore behavior is exact: `revealed_event` starts the registered text event and calls `reveal_current_line()`; `before_event` stages the exact successor without executing it during the restore transaction, and successful participant `finalize()` schedules one deferred resume after SaveManager releases the mutation gate; rollback cancels that resume; terminal/external positions start nothing. Tests use a synthetic choice → effect_transaction → variable_transaction → text event list and restore every boundary: choice is never replayed, effect resumes at variable without replaying effect, variable resumes at text without replaying either transaction, and no successor is skipped. Literal reveal count, tween state, and animation progress are intentionally not restored.

- [ ] Implement one concrete checkpoint adapter; neither DialogicBridge nor GameState may call SaveManager, the journal, a `/root` singleton, or a second checkpoint port directly:

~~~gdscript
class_name SaveManagerNarrativeCheckpointPort
extends RefCounted

func configure(checkpoint_port: Object, providers: Dictionary) -> Dictionary
func commit_current_boundary(request: Dictionary) -> Dictionary
func preview_checkpoint_id(run_id: String) -> Dictionary
func capture() -> Dictionary
func prepare_candidate(
	owner_id: StringName,
	snapshot_input: Dictionary,
	transaction_id: String,
	source_id: String,
	checkpoint_kind: StringName,
	expected_checkpoint_id: String
) -> Dictionary
func commit(owner_id: StringName, candidate: Dictionary) -> Dictionary
func rollback(owner_id: StringName, backup: Dictionary) -> Dictionary
~~~

`configure()` accepts exactly one Plan-03 `SaveManagerCheckpointPort` exposing `preview_checkpoint_id/capture/prepare/commit/rollback` and a provider Dictionary with exactly `snapshot_input`, `narrative_checkpoint`, `route_id`, `active_app_id`, `audio_context`, and `content_version`. All six values are non-null Callables. `snapshot_input`, `route_id`, `active_app_id`, `audio_context`, and `content_version` take zero arguments and return, respectively, a detached Dictionary, registered nonempty String/StringName, JSON null or registered app-ID String, detached semantic-audio Dictionary, and positive integer; the adapter validates and normalizes each raw result. `narrative_checkpoint(transaction_id:String,source_id:String,checkpoint_kind:StringName)` is bound to DialogicBridge and returns exactly the frozen CommandResult `value={"narrative_checkpoint":Dictionary}` only for its currently validated effect/variable event with matching identity/kind. ApplicationBootstrap binds `snapshot_input` specifically to the Task-2-created pure `GameState.capture_run_snapshot_input()` read seam; that method returns the complete detached current RunSnapshot input and performs no mutation, checkpoint, signal, or disk access. Task 3 later extends that same capture with its new live transaction fields. The remaining named Callables bind to DialogicBridge, SceneRouter, Bootstrap's stable private active-app context method, AudioManager, and DialogicTimelineCatalog; the adapter performs no SceneTree/global lookup. The stable active-app Callable returns JSON null until Plan 06 injects the Bootstrap-owned desktop host, then reads that same host without replacing the Callable or adapter.

The first compatible configuration returns exactly `{"ok":true,"code":&"ok","value":{"port_instance_id":int,"checkpoint_port_instance_id":int,"already_configured":false},"receipt":{}}`. Provider identity is the ordered pair `(Callable.get_object_id(),String(Callable.get_method()))` under its exact key; anonymous/unbound callables with no stable nonzero object identity or wrong arity are rejected. Configuration validates identity/arity only and never invokes a provider against a not-yet-started run. Repeating with the same checkpoint-port identity and all six identical provider pairs returns the same shape with `already_configured=true`. Null, missing methods, missing/extra provider keys, a non-Callable, or any different dependency returns a frozen failure before retaining anything; replacement after success returns `narrative_checkpoint_port_already_configured`. A provider's invalid runtime result fails that boundary before capture/prepare and does not erase configuration. The configured adapter is one object: ApplicationBootstrap injects that exact instance into both `DialogicBridge.configure_narrative_checkpoint_port(port)` and `GameState.configure_narrative_checkpoint_port(port)`. Each consumer accepts the same instance idempotently, rejects a different instance, and returns its retained `port_instance_id` for Bootstrap identity verification.

`commit_current_boundary()` is the declared atomic transaction owner for stable boundaries that do not change gameplay state. Its request has exactly `boundary_id:String`, `checkpoint_kind:StringName`, and `narrative_checkpoint:Dictionary`; the kind is exactly `timeline_start|line|choice|safe_marker|scene_transition|timeline_complete`. `boundary_id` is not caller-chosen: it is exactly `timeline:<timeline_id>:start`, the registered completed/revealed `event.event_id` for line/choice/safe-marker, the nonempty `boundary.transaction_id` for scene transition, or `timeline:<timeline_id>:complete`, respectively. The adapter derives that value again from the validated checkpoint and requires equality, making it recoverable from persisted bytes. It first compares the request with the current bundle and retained journal bundles in descending sequence: an identical committed boundary returns its deterministic stored/reconstructed receipt without provider calls or sequence consumption; the same retained boundary ID with different normalized bytes returns `duplicate_transaction_conflict`. A pruned historical line is not a legal runtime retry because the current playhead cannot move backward to it. Otherwise it enters the adapter-local owner `&"narrative_boundary"`, invokes the snapshot/route/active-app/audio/content providers once in that order (not the transaction-only narrative provider), constructs the exact six-key Plan-03 checkpoint input, captures the real port, prepares with disk write exactly `{"kind":&"none","reason":&"stage"}`, commits, and releases the local owner. A failed or partially mutating commit calls the real port's rollback before release; rollback failure propagates its fatal result. No profile/domain signal is published before commit.

Its success is exactly:

~~~gdscript
{
	"ok": true,
	"code": &"ok",
	"value": {"checkpoint_id": String, "duplicate": bool},
	"receipt": {
		"boundary_id": String,
		"checkpoint_id": String,
		"checkpoint_kind": StringName,
		"narrative_fingerprint": String,
	},
}
~~~

The fingerprint is lowercase SHA-256 over canonical UTF-8 bytes of the exact normalized primitive request; `checkpoint_kind` is normalized to its closed String value before hashing and no StringName/Object enters the writer. The deterministic receipt is derivable from the persisted current bundle, so an identical high-level duplicate after restore consumes no sequence. Every returned collection is detached.

The remaining methods are the low-level seams used only while GameState owns an effect/variable transaction. `preview_checkpoint_id(run_id)` is a pure exact proxy and returns only `value={"checkpoint_id":String}` with empty receipt. `prepare_candidate()` accepts only local owner `&"game_state_narrative_transaction"`, a detached already-updated gameplay `snapshot_input`, exact `transaction_id/source_id`, the matching effect/variable `checkpoint_kind`, and the exact previewed ID. It calls the transaction-only narrative provider with those three identity fields, validates the returned checkpoint against them, then invokes route/active-app/audio/content once in that order. It calls the real port with exact disk write `{"kind":&"none","reason":&"stage"}` and rejects unless the prepared `checkpoint_id` equals `expected_checkpoint_id`. Success is exactly `{"ok":true,"code":&"ok","value":{"candidate":Dictionary,"checkpoint_id":String},"receipt":{}}`. The adapter privately hashes the complete normalized prepare request and issued candidate to detect alteration; that adapter-local hash is not a second gameplay transaction identity and is not persisted. `commit()` succeeds only for a candidate issued to that same owner and returns exactly `value={"checkpoint_id":String}`; `rollback()` accepts only the matching captured backup and returns exactly empty `value`/`receipt`. Stale, reused, foreign-owner, or byte-modified candidates reject before touching the real port. Only one local owner/candidate may exist at a time.

- [ ] `test_save_manager_narrative_checkpoint_port.gd` and `FakeNarrativeCheckpointContext.gd` cover initial/same/different configuration, every missing real-port method, every provider key/result/type, exact provider order/count, strict disk-write keys/types, high-level duplicate/conflict after a seeded restore, pure preview, preview/prepare ID mismatch, foreign/stale/modified candidates, commit failure with rollback, rollback failure, and recursive no-alias results. `test_narrative_checkpoint_wiring.gd` proves one real checkpoint-port identity is retained by the adapter, the later DayResolution stage, DialogicBridge, and GameState; no global lookup or second `SaveManagerCheckpointPort.new()` exists.

- [ ] **Step 2.3: Rewrite DialogicBridge as the only narrative seam**

- [ ] Keep `start_timeline_id()` but make it return manifest-backed results. Add `start_ending_id()` as the only live EndingPlan resolver through `endings.json`; it accepts the exact four-key `playback_context`, requires a `primary|epilogue` record whose role equals `playback_context.role`, and delegates to the exact timeline ID/label without rewriting that context. Add bridge-only `start_postscript_id(postscript_id:String) -> Dictionary`; it accepts only a manifest record whose role is `postscript`, takes no EndingPlan context, and reuses the same opaque token and physical completion/failure machinery. It has no production caller in this task. Remove public arbitrary `start_timeline_path()` after zero callers remain.
- [ ] Implement every shared DialogicBridge method plus:

~~~gdscript
signal narrative_checkpoint_committed(checkpoint: Dictionary)
signal narrative_validation_failed(result: Dictionary)
signal ending_playback_finished(playback_token: String, ending_id: String, receipt: Dictionary)
signal ending_playback_failed(playback_token: String, ending_id: String, result: Dictionary)

func initialize(
	catalog: Script = DialogicTimelineCatalog,
	runtime_adapter: RefCounted = null
) -> Dictionary
func configure_narrative_checkpoint_port(port: Object) -> Dictionary
func provide_transaction_narrative_checkpoint(
	transaction_id: String,
	source_id: String,
	checkpoint_kind: StringName
) -> Dictionary
func capture_restore_state() -> Dictionary
func restore_captured_state(backup: Dictionary) -> Dictionary
~~~

`configure_narrative_checkpoint_port()` requires the high-level and low-level methods frozen in Step 2.2, accepts the first compatible object, accepts the identical object idempotently, rejects replacement, and returns the same retained positive `port_instance_id` that GameState and Bootstrap verify. DialogicBridge never resolves SaveManager or calls `SaveManagerCheckpointPort` itself. `provide_transaction_narrative_checkpoint()` is the exact Callable target configured on the shared adapter: it returns only `value={"narrative_checkpoint":Dictionary}` when all three arguments match the one transient, manifest-validated effect/variable event, otherwise a frozen failure with no checkpoint. It never executes, commits, advances, or looks up global state. Timeline start, fully revealed line, choice, safe marker, scene transition, and timeline completion build the exact validated semantic checkpoint and call `commit_current_boundary()` synchronously; only its committed success may update the bridge's cached checkpoint and emit `narrative_checkpoint_committed`. Effect and variable events are delegated to the GameState transaction in Task 3 and never call the high-level method.

`DialogicBridge.start_ending_id()` and `start_postscript_id()` resolve `endings.json`, create one opaque playback token, start the registered timeline/label, and then return this exact outer CommandResult:

~~~gdscript
{
	"ok": true,
	"code": &"started",
	"value": {},
	"receipt": {
		"playback_token": String,
		"ending_id": String,
		"role": StringName,
		"timeline_id": String,
		"label": String,
		"started": true,
	},
}
~~~

`value` is exactly empty; the six start fields exist only in `receipt`. For `start_postscript_id`, `role` is necessarily `postscript`. A synchronous validation/start failure is exactly `{"ok":false,"code":StringName,"message":String,"details":Dictionary}` with no `value`, no `receipt`, no token binding, and no completion/failure signal. After a successful return, the bridge emits `ending_playback_finished` only when that same token's timeline ends normally and `ending_playback_failed` on a later validation/halt; another timeline's signals cannot satisfy the token. Direct postscript capability MUST NOT call `GameState.request_next_ending_command()`, `complete_ending_playback_stage()`, mutate an EndingPlan stage, schedule/unlock/record a postscript, or publish Gallery state.

- [ ] Starting validates timeline ID and every supplied context key before calling the adapter. Signal payloads are Dictionaries with kind exactly `safe_marker`, `effect_transaction`, `variable_transaction`, `scene_transition`, or `minesweeper_entry`. The current timeline manifest must allow the referenced ID and exact event locator.
- [ ] Any invalid runtime event halts the current timeline through the adapter, emits narrative_validation_failed, creates no checkpoint, and mutates no domain state.
- [ ] `DialogicRuntimeAdapter.start_timeline()` and restore clear/start preserve the installed-version ordering `Dialogic clear -> DialogicBridge.reapply_cached_preferences_after_clear() -> first event`. They do not reconnect the profile adapter or read disk. Extend plan `.3`'s New Game/restore first-event tests through the real runtime adapter; a direct Dialogic clear/start outside the bridge/adapter fails the ownership scan.

- [ ] Opening, tutorial, Hospital, dating, and ending scenes request only stable timeline IDs. They render/forward receipts and never inspect an event index.
- [ ] `DialogicEndingPlaybackPort` implements `.7`'s interface without widening it:

~~~gdscript
signal playback_completed(completion: Dictionary)
signal playback_failed(failure: Dictionary)

func initialize(dialogic_bridge: Object) -> Dictionary
func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary
func is_ready() -> bool
~~~

`initialize()` accepts exactly one DialogicBridge-like dependency exposing `start_ending_id` and the matching completion/failure signals; replacement rejects. This production-only dependency method is distinct from EndingScene's owner wiring. Its `context` argument is the `.7` command's `playback_context` passed unchanged: it has exactly `playback_id`, `transaction_id`, `expected_stage`, and `role`. The only legal triples are `role=primary`, `expected_stage=PRIMARY_PENDING`, and `ending_id in DatingEndingRules.VALID_PRIMARY_IDS`; or `role=epilogue`, `expected_stage=PRIMARY_PLAYED`, and `ending_id=ending.priscilla_lavinia`. `postscript`, any other stage, and any mismatched manifest role reject before the port calls the bridge. The bridge treats a validated `expected_stage` as opaque correlation data and does not own lifecycle-stage meaning.

`DialogicEndingPlaybackPort.start_ending_id()` passes that same Dictionary unchanged to `DialogicBridge.start_ending_id()`. After the bridge returns `code=started`, the port binds its opaque token to a detached copy of that context and returns immediately with this exact CommandResult:

~~~gdscript
{
	"ok": true,
	"code": &"started",
	"value": {},
	"receipt": {
		"playback_id": String,
		"transaction_id": String,
		"expected_stage": StringName,
		"role": StringName,
		"ending_id": String,
		"playback_token": String,
		"started": true,
	},
}
~~~

`value` is exactly empty; the seven start fields exist only in `receipt`. A synchronous bridge failure returns the bridge's copied failure CommandResult, creates no binding, and emits no port signal. Start success MUST NOT wait for or imply physical completion. Only the matching `ending_playback_finished` signal may emit `playback_completed` with exactly `{"playback_id":String,"ending_id":String,"expected_stage":StringName,"transaction_id":String,"timeline_completion_receipt_id":String,"outcome":&"completed"}`. A matching bridge failure first deletes the token binding, active transaction, and cached start result, then emits `playback_failed` with exactly `{"playback_id":String,"ending_id":String,"expected_stage":StringName,"transaction_id":String,"code":StringName,"result":Dictionary}`. The Plan04 command and EndingPlan stage remain pending; the next identical request therefore calls the bridge again, allocates a new token, and starts a new playback. Another token cannot satisfy either signal. While a transaction is active, a concurrent identical start returns its copied immediate-start CommandResult without replay, a different in-flight command returns `playback_in_progress`, and reuse of one active ID with different ending/stage/role rejects. Only physically completed receipts remain cached, solely to make duplicate bridge completion idempotent. Thus Plan04's primary/epilogue stage advances only from the physical-completion signal.

- [ ] Use only the existing Bootstrap stages—do not add or reorder a global stage. `initialize_saves` constructs and retains the one real `SaveManagerCheckpointPort`. Inside `initialize_dialogic_bridge`, after the catalog/runtime bridge initializes and before any timeline can start, Bootstrap constructs one `SaveManagerNarrativeCheckpointPort`, configures it with that retained real port plus the six exact provider Callables, injects the same adapter into DialogicBridge and GameState, and verifies all three positive instance IDs are identical. It then constructs one `DialogicEndingPlaybackPort`, calls `initialize(DialogicBridge)`, calls `SceneRouter.configure_ending_ports(GameState, ending_port)`, and verifies `ending_port.is_ready()` plus `SceneRouter.is_ending_ports_configured()` before the stage succeeds. The later existing `configure_day_resolution` stage injects the same retained real checkpoint port, not a new instance. SceneRouter stores the exact ending instances and calls `EndingScene.configure_ending_ports(state_port,playback_port)` on an off-tree ending scene before adding it to the tree. A null/replacement/missing method, provider failure, identity mismatch, an ending scene that reaches `_ready()` unconfigured, or any second checkpoint-port construction is a fatal stage result; `application_ready` is not emitted. `test_narrative_checkpoint_wiring.gd` proves the stage order and identities. `test_ending_dialogic_wiring.gd` exercises primary-only and primary-plus-epilogue completion, asynchronous failure, unknown IDs, mismatched completion tokens, in-flight duplicates, and completed retry. It also starts both `.observation` IDs directly through `DialogicBridge.start_postscript_id()`, proves normal tokenized finish/failure, and proves primary, epilogue, unknown, and retired `.true` IDs reject without a GameState, stage, or Gallery call. The production port separately proves it rejects both postscript IDs before calling the bridge.

- [ ] Replace ending-context audio suffix inference with one exact map whose keys equal `DatingEndingRules.CANONICAL_ENDING_IDS`. Rename only the three ending-track IDs frozen by the handoff: `ending_priscilla_true` → `ending_priscilla_observation`, `ending_lavinia_true` → `ending_lavinia_observation`, and `ending_sylvia_true` → `ending_sylvia_special`; retire generic ending-tier `ending_true` and the `true` suffix fallback. `resolve_music_context("ending", {"ending_id": id})` resolves every one of the 11 canonical IDs to its exact track. Empty, unknown, and retired `.true` semantic IDs fail before AudioManager mutation; no fallback to `ending_alone` is permitted. This is registry/playback capability only and does not schedule a postscript. Non-ending dating/challenge track IDs are outside this handoff.

~~~text
ending.alone                  -> ending_alone
ending.priscilla.sweet        -> ending_priscilla_sweet
ending.priscilla.dark         -> ending_priscilla_dark
ending.priscilla.observation  -> ending_priscilla_observation
ending.lavinia.sweet          -> ending_lavinia_sweet
ending.lavinia.dark           -> ending_lavinia_dark
ending.lavinia.observation    -> ending_lavinia_observation
ending.sylvia.sweet           -> ending_sylvia_sweet
ending.sylvia.dark            -> ending_sylvia_dark
ending.sylvia.special         -> ending_sylvia_special
ending.priscilla_lavinia      -> ending_priscilla_lavinia
~~~

~~~gdscript
# autoload/SceneRouter.gd
func configure_ending_ports(state_port: Object, playback_port: Object) -> Dictionary
func is_ending_ports_configured() -> bool

# scripts/ui/EndingScene.gd
func configure_ending_ports(state_port: Object, playback_port: Object) -> Dictionary
~~~

- [ ] **Step 2.4: Restore through the real SaveManager participant seam**

- [ ] Modify the Plan-03-created `scripts/application/restore/NarrativeRestoreParticipant.gd`; do not replace it inside SaveManager, create a seventh participant, or make SaveManager impersonate it. Bootstrap constructs that one participant around the already initialized DialogicBridge and exact Task-1 catalog, then registers it under the existing `narrative` key of the exact six-participant Dictionary. Its optional existing `.uid` remains the same resource identity. `tests/integration/test_restore_production_adapters.gd` must exercise this physical class, not a SaveManager-only fake.
- [ ] The real participant retains the exact common `prepare(input)/capture/apply_silent/rollback_silent/finalize` interface. Its `prepare()` input remains exactly `{"narrative_checkpoint":Dictionary,"content_version":int}` and validates the complete semantic checkpoint against the current catalog record, current manifest version, exact current content fingerprint, event, post-event successor, and nullable rules without mutation. It returns typed `content_incompatible` only when a structurally valid bundle references removed/unavailable content or an earlier valid fingerprint; malformed primitive/schema data, unsupported future schema/content versions, and corruption keep their Plan-03 fail-closed codes. `apply_silent()` runs only after the route adapter reports its target Dialogic layout ready, resolves the prepared locator without re-selection, starts the event, and reveals the restored line without emitting narrative/domain signals.
- [ ] Preserve Plan 03's one private selection algorithm: every public `prepare_restore_*` strict-parses and migrates all whole bundles, orders current first and journal bundles by descending sequence, and calls `SaveManager._prepare_bundle_with_all_participants(bundle,migrated_document)` for each candidate. That helper invokes the pure `prepare()` of run, profile, localization, audio, route, and the real narrative participant for the **same** bundle before returning a candidate. SaveManager selects only the first all-six success. Typed `content_incompatible` advances to the next earlier whole bundle; corruption/schema/future-version outcomes follow Plan 03's frozen rejection policy instead of being relabeled as incompatibility. There is no preliminary selection followed by narrative failure, no field mixing, no second compatibility provider/configuration method, and no global lookup.
- [ ] Add restore fixtures where the current bundle references a removed timeline, removed label/event, wrong prior fingerprint, or illegal successor while one or more earlier bundles remain. For each public slot/quick/autosave prepare API, assert candidate attempts are newest-to-oldest, all six participant preparations use one sequence at a time, and the selected result is the greatest earlier fully compatible bundle under the **current** manifest/fingerprint. Add a case where an earlier bundle passes narrative but another participant returns the frozen typed `content_incompatible`: selection must continue; the same participant returning corruption, malformed input, configuration failure, or fatal must stop under Plan 03's policy. Add no-compatible, corrupt-current, and unsupported-future cases and assert the frozen rejection policy. Every attempt is pure; live participants, journal, checkpoint sequence, provider counts, and files stay byte-equal until `commit_prepared_restore()`.
- [ ] Implement the exact post-event restore state machine:

~~~text
prepare:
  strict-validate checkpoint and current manifest fingerprint
  resolve event and legal post_event edge; copy both into a detached plan
apply_silent(revealed_event):
  clear/start exact text event -> reapply cached preferences -> reveal line
apply_silent(before_event):
  set Dialogic paused -> clear/start at post_event.index -> verify execution is suspended
  record pending_resume token; emit no boundary/domain signal
apply_silent(timeline_complete|external_route):
  restore semantic terminal/external state; start no event
rollback_silent:
  cancel pending_resume; restore captured runtime/checkpoint
finalize:
  for before_event only, call_deferred(resume_pending_token)
deferred resume:
  verify successful restore token and released mutation gate, then unpause once
~~~

The staged successor cannot execute during participant apply/finalize. A rollback or stale token makes the deferred callback a no-op. Tests fail each preparation/apply/finalize/deferred-resume point and assert no completed boundary replays, no successor skips, and no callback survives rollback.
- [ ] Inject failure after every real participant apply position and prove SaveManager rolls route/layout, narrative, localization, audio, profile, run, and its own journal back with zero mutation or run_restored signals. An earlier-bundle fallback is prepared once and then committed through this same transaction; SaveManager never reruns selection during apply.

- [ ] **Step 2.5: Run adapter/restore tests**

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_restore' -LogName 'phase2r-dialogic-restore.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_dialogic_runtime_adapter.gd,res://tests/unit/test_narrative_checkpoint_schema.gd,res://tests/unit/test_save_manager_narrative_checkpoint_port.gd,res://tests/unit/test_dialogic_ending_playback_port.gd,res://tests/unit/test_audio_manager.gd,res://tests/integration/test_dialogic_restore.gd,res://tests/integration/test_narrative_checkpoint_wiring.gd,res://tests/integration/test_ending_dialogic_wiring.gd,res://tests/integration/test_restore_production_adapters.gd,res://tests/integration/test_restore_transaction.gd','-gexit')
~~~

Expected GREEN: semantic capture/restore, full reveal, registered locators, one shared checkpoint-port identity, newest-to-oldest all-six compatibility fallback, and transaction rollback.

- [ ] **Step 2.6: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 2 Step 2.6 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'feat(dialogic): register exact timeline and narrative manifests')) {
	throw 'Task 2 requires the exact Task 1 commit boundary as HEAD.'
}
$readOnlyUidBindings = @(
	@{ Path = 'scripts/data/AudioManifest.gd.uid'; Required = $true },
	@{ Path = 'tests/unit/test_audio_manager.gd.uid'; Required = $true }
)
foreach ($binding in $readOnlyUidBindings) {
	$existingUid = [string]$binding.Path
	if (-not (Test-Path -LiteralPath $existingUid -PathType Leaf)) {
		if ([bool]$binding.Required) {
			throw "Required read-only UID is missing: $existingUid"
		}
		continue
	}
	$headUidRecord = @(
		git ls-tree $expectedHead -- $existingUid
	)
	if ($LASTEXITCODE -ne 0 -or $headUidRecord.Count -ne 1 -or
		$headUidRecord[0] -notmatch '^100644 blob ([0-9a-f]{40,64})\t') {
		throw "Read-only UID must be one tracked regular HEAD blob: $existingUid"
	}
	$headUidObject = $Matches[1]
	$workingUidObject = [string](git hash-object -- $existingUid)
	if ($LASTEXITCODE -ne 0 -or -not ($workingUidObject -ceq $headUidObject)) {
		throw "Read-only UID identity changed: $existingUid"
	}
}
$required = [ordered]@{
	'scripts/narrative/DialogicRuntimeAdapter.gd' = 'A'
	'scripts/narrative/NarrativeCheckpointSchema.gd' = 'A'
	'scripts/application/ending/DialogicEndingPlaybackPort.gd' = 'A'
	'scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd' = 'A'
	'tests/support/FakeDialogicRuntime.gd' = 'A'
	'tests/support/FakeNarrativeCheckpointContext.gd' = 'A'
	'tests/unit/test_dialogic_runtime_adapter.gd' = 'A'
	'tests/unit/test_narrative_checkpoint_schema.gd' = 'A'
	'tests/unit/test_dialogic_ending_playback_port.gd' = 'A'
	'tests/unit/test_save_manager_narrative_checkpoint_port.gd' = 'A'
	'tests/integration/test_dialogic_restore.gd' = 'A'
	'tests/integration/test_ending_dialogic_wiring.gd' = 'A'
	'tests/integration/test_narrative_checkpoint_wiring.gd' = 'A'
	'autoload/DialogicBridge.gd' = 'M'
	'autoload/ApplicationBootstrap.gd' = 'M'
	'autoload/GameState.gd' = 'M'
	'autoload/SceneRouter.gd' = 'M'
	'scripts/data/AudioManifest.gd' = 'M'
	'tests/unit/test_audio_manager.gd' = 'M'
	'scripts/application/restore/NarrativeRestoreParticipant.gd' = 'M'
	'tests/integration/test_restore_production_adapters.gd' = 'M'
	'tests/integration/test_restore_transaction.gd' = 'M'
	'scripts/ui/OpeningScene.gd' = 'M'
	'scripts/ui/TutorialOverlay.gd' = 'M'
	'scripts/ui/HospitalScene.gd' = 'M'
	'scripts/ui/DatingScene.gd' = 'M'
	'scripts/ui/EndingScene.gd' = 'M'
}
$optionalUids = [ordered]@{
	'scripts/application/restore/NarrativeRestoreParticipant.gd.uid' = 'A'
	'scripts/narrative/DialogicRuntimeAdapter.gd.uid' = 'A'
	'scripts/narrative/NarrativeCheckpointSchema.gd.uid' = 'A'
	'scripts/application/ending/DialogicEndingPlaybackPort.gd.uid' = 'A'
	'scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd.uid' = 'A'
	'tests/support/FakeDialogicRuntime.gd.uid' = 'A'
	'tests/support/FakeNarrativeCheckpointContext.gd.uid' = 'A'
	'tests/unit/test_dialogic_runtime_adapter.gd.uid' = 'A'
	'tests/unit/test_narrative_checkpoint_schema.gd.uid' = 'A'
	'tests/unit/test_dialogic_ending_playback_port.gd.uid' = 'A'
	'tests/unit/test_save_manager_narrative_checkpoint_port.gd.uid' = 'A'
	'tests/integration/test_dialogic_restore.gd.uid' = 'A'
	'tests/integration/test_ending_dialogic_wiring.gd.uid' = 'A'
	'tests/integration/test_narrative_checkpoint_wiring.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'refactor(dialogic): persist semantic playhead checkpoints'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 2 commit boundary failed.' }
~~~

## Task 3: Make effect and variable transactions validated, atomic, and idempotent

**Beads:** dwm-p2r.8

**Files:**

- Modify: autoload/EffectResolver.gd
- Modify: autoload/GameState.gd
- Modify: autoload/DialogicBridge.gd
- Extend: scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd
- Extend: tests/support/FakeNarrativeCheckpointContext.gd
- Extend: tests/unit/test_save_manager_narrative_checkpoint_port.gd
- Create: tests/unit/test_effect_transactions.gd
- Modify: tests/unit/test_effect_resolver.gd
- Create: tests/integration/test_dialogic_effect_boundary.gd
- Extend: scripts/domain/run/RunSnapshotSchema.gd
- Extend: scripts/infrastructure/save/SaveDocumentSchema.gd
- Extend: scripts/infrastructure/save/SaveMigrations.gd
- Extend: tests/unit/test_run_snapshot_schema.gd
- Extend: tests/unit/test_save_document_schema.gd
- Extend: tests/unit/test_save_migrations.gd
- Extend: tests/unit/test_game_state_facade_contract.gd
- Extend: tests/unit/test_restore_participants.gd
- Extend: tests/unit/test_save_manager.gd
- Extend: tests/integration/test_restore_transaction.gd
- Extend: tests/integration/test_restore_production_adapters.gd
- Extend: tests/integration/test_save_capability.gd
- Extend: tests/integration/test_save_manager_journal.gd
- Regenerate: evidence/phase_2r/runtime/game_state_surface.json
- Modify: tests/fixtures/snapshots/invalid_day8.json
- Modify: tests/fixtures/snapshots/invalid_object_shapes.json
- Modify: tests/fixtures/snapshots/valid_day3.json
- Modify: tests/fixtures/saves/day8_ending_non_group.json
- Modify: tests/fixtures/saves/day8_group_invalid_with_day7_journal.json
- Modify: tests/fixtures/saves/day8_group_synchronized.json
- Modify: tests/fixtures/saves/day8_no_fallback.json
- Modify: tests/fixtures/saves/day8_playing_with_day7_journal.json
- Modify: tests/fixtures/saves/v2_future_schema.json
- Consume without modification: scripts/application/transaction/FatalDiagnosticProjector.gd
- Re-run without modification: tests/unit/test_fatal_diagnostic_projector.gd

**Interfaces:**

- Consumes: exact effect/variable registries; Task 2's pure `GameState.capture_run_snapshot_input()` and one shared `SaveManagerNarrativeCheckpointPort`; the existing applied effect/variable ID arrays; the one injected `ApplicationMutationGate`; and Plan-03 Task-3's unchanged `FatalDiagnosticProjector`. No GameState detached-candidate API, run command-receipt ledger, live narrative-variable store, or `_latch_facade_recovery_fatal` helper exists at Task-3 entry.
- Produces: `EffectResolver.resolve_effects`; `GameState.commit_effect_transaction` and `GameState.commit_variable_transaction`; `GameState.prepare_run_candidate/capture_live_run_state/commit_run_candidate/restore_live_run_state`; live recursively detached narrative-variable, applied-ID, and command-receipt state; the private `_latch_facade_recovery_fatal(...)` helper; and one mandatory top-level schema-v2 `command_receipts: Dictionary`. In this task the map accepts only effect/variable variants. It is disjoint from `ProfileManager.gallery_transaction_receipts`: Task 3 never reads, writes, copies, or recreates the ending-gallery ledger, and permits no ending receipt variant.

- [ ] **Step 3.1: Write RED atomicity and duplicate tests**

- [ ] Add a runnable first assertion without naming a missing class at parse time:

~~~gdscript
func test_variable_transaction_api_is_required() -> void:
	var state := get_tree().root.get_node_or_null("GameState")
	assert_not_null(state)
	if state == null:
		return
	assert_true(state.has_method("commit_variable_transaction"))
~~~

- [ ] Tests submit two valid effects plus one invalid effect and assert the entire GameState snapshot and signal counts remain unchanged.
- [ ] Tests submit one valid batch twice with the same transaction ID and assert state changes once, the second result equals the first receipt, and checkpoint sequence does not increment twice.
- [ ] Tests inject a failure while committing the second descriptor and assert full rollback.
- [ ] Tests submit one registered variable value and one unknown or wrong-typed variable. The registered value commits once with a variable_transaction checkpoint; invalid input leaves state, receipts, signals, and sequence unchanged.
- [ ] Schema/new-run/migration tests require mandatory top-level `command_receipts={}` and empty live narrative variables/applied-ID sets by default. They reject missing/extra wrapper keys, mismatched map keys, malformed fingerprints, unknown registered IDs, aliases, and any ending/gallery receipt variant. A legacy/provisional snapshot missing `command_receipts` may migrate to `{}` only when both applied-ID arrays are empty; migration never invents a receipt for a nonempty array.
- [ ] Facade/restore tests require the reserved `capture_run_snapshot_input`, `prepare_run_candidate`, `capture_live_run_state`, `commit_run_candidate`, and `restore_live_run_state` methods; prove narrative variables, both applied-ID sets, and `command_receipts` recursively detach through capture/commit/restore/rollback; and regenerate `game_state_surface.json` from the checked-in required surface. Source scans prove GameState never reads/writes `ProfileManager.gallery_transaction_receipts` and creates no second gate, projector, or fatal flag.

- [ ] Run RED before modifying EffectResolver, GameState, or DialogicBridge:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_transactions_red' -LogName 'phase2r-red-dialogic-transactions.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_effect_resolver.gd,res://tests/unit/test_effect_transactions.gd,res://tests/integration/test_dialogic_effect_boundary.gd','-gexit')
~~~

Expected RED: `commit_variable_transaction` or the new detached resolver contract is absent; a parse error or mutation before the intended assertion is not acceptable.

- [ ] **Step 3.2: Split resolution from mutation**

- [ ] Complete the reserved GameState detached-run seam before either transaction method uses it:

~~~gdscript
func prepare_run_candidate(snapshot: Dictionary) -> Dictionary
func capture_live_run_state() -> Dictionary
func commit_run_candidate(candidate: Dictionary) -> Dictionary
func restore_live_run_state(backup: Dictionary) -> Dictionary
~~~

`capture_run_snapshot_input()` remains the pure Task-2 read seam. Task 3 extends it and `prepare_new_run_snapshot_input()` with private live `narrative_variables`, the two applied transaction-ID sets, and mandatory top-level `command_receipts`. `prepare_run_candidate()` recursively detaches and validates the complete GameState-owned RunSnapshot **input** before returning exactly `{"ok":true,"code":&"ok","value":{"candidate":Dictionary},"receipt":{}}`; `value.candidate` is that normalized snapshot input itself, not a full SaveManager snapshot or another wrapper. It does not construct the narrative checkpoint, route/app/audio/content fields, or journal sequence. `commit_run_candidate()` accepts only the exact issued detached `value.candidate` and publishes no transaction-specific signal; `capture_live_run_state()` and `restore_live_run_state()` cover every field the commit may alter and reject stale/modified/foreign backups. These are the one GameState candidate/restore seams later facade work reuses; `SaveManagerNarrativeCheckpointPort` remains the sole full-snapshot/bundle constructor.

- [ ] Replace apply_effect_ids() with:

~~~gdscript
func resolve_effects(effect_ids: Array[String]) -> Dictionary
~~~

It normalizes and validates every ID against effects.json and returns typed descriptors without finding GameState or mutating anything.

- [ ] GameState implements the shared commit method:

~~~gdscript
func commit_effect_transaction(
	transaction_id: String,
	effect_ids: Array[String],
	source_id: String
) -> Dictionary

func commit_variable_transaction(
	transaction_id: String,
	variable_id: String,
	value: Variant,
	source_id: String
) -> Dictionary
~~~

The DialogicBridge signal callback first calls its injected shared gate's `guard_external(&"dialogic_narrative_transaction")`; a failure returns or halts with that frozen gate result before manifest lookup, transient-boundary creation, provider exposure, or GameState invocation. Only after that guard succeeds does DialogicBridge validate the manifest event/successor and expose one detached checkpoint through the configured `narrative_checkpoint(transaction_id,source_id,checkpoint_kind)` provider. It then invokes the unchanged master GameState signatures. On entry, GameState independently applies the same shared gate before any argument normalization, receipt-ledger read, validation, snapshot capture, or port/provider call. GameState performs this exact algorithm for both kinds:

~~~text
guard external mutation with &"commit_effect_transaction" or &"commit_variable_transaction"
  as the method's first operation
  on failure return that frozen gate result without normalization, ledger/provider/port access, or mutation
normalize the request and compute its canonical request_fingerprint
look up transaction_id in the persisted top-level command_receipts map before any port call
  identical kind/source/payload/fingerprint -> return the stored copied receipt
  same ID with any different normalized byte -> duplicate_transaction_conflict
capture detached live-state backup
resolve/validate every effect descriptor or variable registry/value without mutation
call narrative_checkpoint_port.preview_checkpoint_id(run_id) exactly once
  require pure value={checkpoint_id}; sequence/journal/providers/storage remain unchanged
build detached gameplay candidate and exact public transaction receipt using that checkpoint_id
insert command_receipts record {transaction_id,request_fingerprint,receipt} into the candidate
apply the effect/variable transaction ID and value to that same snapshot_input
call prepare_run_candidate(snapshot_input) exactly once and retain run_candidate.value.candidate
call narrative_checkpoint_port.capture()
call prepare_candidate(&"game_state_narrative_transaction", run_candidate.value.candidate,
  transaction_id, source_id, matching checkpoint_kind, previewed_checkpoint_id)
require prepared checkpoint_id equals the previewed/receipt checkpoint_id
commit prepared checkpoint first; commit_run_candidate(run_candidate.value.candidate) second
if checkpoint commit fails: rollback checkpoint backup; live GameState remains unchanged
if GameState commit fails/partially mutates: restore GameState backup, then rollback checkpoint
  backup (strict reverse order); any rollback failure invokes Task 3's
  _latch_facade_recovery_fatal helper, which projects through the one unchanged
  FatalDiagnosticProjector, latches the injected gate once, and returns the final retained APPLICATION_FATAL
only after both commits publish the typed gameplay notification and boundary completion
clear the bridge's transient boundary only after success or terminal failure
~~~

Task 3 creates `_latch_facade_recovery_fatal(original_phase:StringName, command_id:String, raw_rollback_diagnostics:Array[Dictionary]) -> Dictionary` with the Plan-04-compatible signature. It runs only after every required reverse-recovery attempt has completed; projects and validates through the existing `FatalDiagnosticProjector` or its invariant fallback; calls the injected gate's `latch_fatal()` exactly once on the first fatal; and returns the final `guard_external()` `APPLICATION_FATAL`. An already-latched gate returns its retained fatal without another latch. The helper retains no failure, creates no gate/projector/fatal Boolean, and never puts unvalidated raw diagnostics into the fatal payload.

The frozen public/stored receipt shapes remain exactly `{"transaction_id":String,"kind":"effect_transaction","source_id":String,"effect_ids":Array[String],"checkpoint_id":String}` and `{"transaction_id":String,"kind":"variable_transaction","source_id":String,"variable_id":String,"value":Variant,"checkpoint_id":String}`. The persisted `command_receipts` record wrapping either is exactly `{"transaction_id":String,"request_fingerprint":String,"receipt":Dictionary}`; the map key equals `transaction_id`, and its detached `receipt` must validate as the matching exact public shape. RunSnapshotSchema requires `applied_effect_transaction_ids` to equal the sorted map keys whose `receipt.kind` is `effect_transaction`, requires the same equality for `applied_variable_transaction_ids` and `variable_transaction`, and requires the union of those two partitions to equal every `command_receipts` key. No ending/gallery kind is legal. The checkpoint's `event` is the completed signal and `post_event` is its manifest-validated successor. This ledger record is part of the same detached/persisted GameState candidate committed after the checkpoint, not an adapter-only cache. After both shared fatal/transaction guards succeed, an identical duplicate after SaveManager restore returns only the copied public receipt before preview/provider/prepare and consumes no checkpoint sequence; a conflicting duplicate after restore also makes zero port/provider calls. A failed guard always wins over either duplicate outcome. Variable transactions use the identical ordering with `checkpoint_kind=&"variable_transaction"`; effects use `&"effect_transaction"`. Every checkpoint prepare receives only `{"kind":&"none","reason":&"stage"}`.

Create the previously planned but absent run-level `command_receipts` validator—do not add another run ledger or snapshot authority—and accept only these two wrapper/receipt variants with exact keys, map-key identity, fingerprint grammar, registered IDs, and partition equality. The map is mandatory top-level schema-v2 data, never nested in legacy gameplay or `_SAVE_WHITELIST`. RunSnapshotSchema requires every receipt checkpoint ID to use the lifecycle run ID and a positive parsed sequence. SaveDocumentSchema's whole-document validation requires that sequence to be no greater than the containing journal bundle's `checkpoint_sequence` and resolves the ID to the retained/current semantic-anchor bundle whose `checkpoint_kind` and narrative boundary transaction match the receipt; effect/variable anchors are permanent, so a missing or cross-transaction reference is corruption. Update the still-unshipped schema-v2 defaults, all nine checked-in v2 fixtures, and migration as specified above. RunSnapshotSchema/SaveDocumentSchema reject corruption before SaveManager enters the six-participant prepare loop; RunRestoreParticipant then captures/applies/rolls back the ledger, both ID sets, and narrative variables recursively detached. The other five participants remain unchanged.

Before the first durable commit, any failure leaves live state, receipt ledger, signals, journal, sequence, transient boundary, and storage byte-equal after rollback. Publication here is the synchronous non-mutating emission of the already committed detached receipt; it has no fallible observer acknowledgement and is never part of rollback. The implementation emits it only after both commits return success. After both shared guards succeed, an identical retry returns the stored receipt and emits nothing again; a different request under that transaction remains a conflict. A fatal or active-transaction guard failure precedes both results.

narrative_variables.json registers variable ID, primitive value type, default, and allowed timeline IDs. Production starts with the exact physically used set (currently empty if the timeline audit finds no Set events). The separate fixture manifest registers fixture.counter as an integer. commit_variable_transaction() validates the manifest/value, applies it to the detached run candidate, and records a variable_transaction anchor using the same atomic receipt rules. An unregistered direct Dialogic Set event fails manifest validation.

- [ ] Add failpoint tests before/after the first gate call, descriptor resolution, variable validation, duplicate lookup, preview, every snapshot/provider call, narrative-boundary lookup, candidate validation, checkpoint prepare, preview/prepare ID comparison, checkpoint commit before/after mutation, GameState commit before/after mutation, and each reverse rollback. Named cases `test_effect_fatal_guard_precedes_restored_duplicate_lookup`, `test_variable_fatal_guard_precedes_argument_and_registry_validation`, and `test_dialogic_effect_boundary_fatal_guard_precedes_manifest_validation` first latch the shared gate, then submit an identical restored duplicate, a conflicting duplicate, malformed arguments, and an invalid manifest event; every call must return/halt with `APPLICATION_FATAL` before normalization, ledger lookup, manifest/catalog lookup, provider/preview/prepare/commit, or state mutation. At every other pre-durable failure assert exact live/journal/sequence/provider/file equality and zero signals; at checkpoint-ID mismatch assert neither commit runs. At GameState commit failure assert rollback call order `game_state -> checkpoint`. Feed nonprimitive/StringName/collision rollback diagnostics through this Task-3-created helper and require it to use the one shared projector, never copy rejected data or return `INVALID_FATAL_FAILURE`, and return only the final retained `APPLICATION_FATAL`; cover first latch, already-latched, and invariant-fallback paths. Assert the one typed signal occurs only after both commit call-log entries and that an identical nonfatal retry emits nothing. Serialize/restore the committed bundle, call the exact duplicate and a conflict while the gate is nonfatal, and assert both make zero provider/preview/prepare/commit calls and leave sequence unchanged. The first-gate tests additionally prove the guard does not call `preview_checkpoint_id`, so the unchanged successful path still previews exactly once and requires the prepared, receipt, and preview IDs to be byte-equal.

- [ ] **Step 3.3: Enforce synchronous bridge ordering**

- [ ] On an approved Dialogic effect signal, execution is exactly:

~~~text
Dialogic signal_event callback
DialogicBridge shared guard_external (before manifest/catalog/transient-boundary work)
DialogicBridge manifest validation
GameState shared guard_external (the first GameState operation)
GameState persisted duplicate lookup
if new: EffectResolver descriptor resolution
pure checkpoint-ID preview
detached gameplay/receipt/checkpoint preparation with identical ID
checkpoint commit, then GameState candidate commit
typed notification publication
return from callback
Dialogic signal event finishes and narrative resumes
~~~

Because signal_event is synchronous in the installed addon, both commits must finish before the addon event returns. Validation/preparation/commit failure calls `halt_with_error()` before narrative continuation; a successful duplicate returns its stored receipt without another signal or sequence.

- [ ] **Step 3.4: Verify effect boundaries**

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_effects' -LogName 'phase2r-dialogic-effects.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_effect_resolver.gd,res://tests/unit/test_effect_transactions.gd,res://tests/unit/test_save_manager_narrative_checkpoint_port.gd,res://tests/unit/test_game_state_facade_contract.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_restore_participants.gd,res://tests/unit/test_save_manager.gd,res://tests/integration/test_dialogic_effect_boundary.gd,res://tests/integration/test_restore_transaction.gd,res://tests/integration/test_restore_production_adapters.gd,res://tests/integration/test_save_capability.gd,res://tests/integration/test_save_manager_journal.gd','-gexit')
~~~

Expected GREEN: invalid batches have zero effects; valid gameplay/checkpoint candidates commit once; failpoints reverse-roll back; and duplicates before/after restore consume no checkpoint sequence.

- [ ] **Step 3.5: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 3 Step 3.5 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'refactor(dialogic): persist semantic playhead checkpoints')) {
	throw 'Task 3 requires the exact Task 2 commit boundary as HEAD.'
}
$required = [ordered]@{
	'autoload/EffectResolver.gd' = 'M'
	'autoload/GameState.gd' = 'M'
	'autoload/DialogicBridge.gd' = 'M'
	'scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd' = 'M'
	'tests/support/FakeNarrativeCheckpointContext.gd' = 'M'
	'tests/unit/test_save_manager_narrative_checkpoint_port.gd' = 'M'
	'tests/unit/test_effect_transactions.gd' = 'A'
	'tests/unit/test_effect_resolver.gd' = 'M'
	'tests/integration/test_dialogic_effect_boundary.gd' = 'A'
	'scripts/domain/run/RunSnapshotSchema.gd' = 'M'
	'scripts/infrastructure/save/SaveDocumentSchema.gd' = 'M'
	'scripts/infrastructure/save/SaveMigrations.gd' = 'M'
	'tests/unit/test_run_snapshot_schema.gd' = 'M'
	'tests/unit/test_save_document_schema.gd' = 'M'
	'tests/unit/test_save_migrations.gd' = 'M'
	'tests/unit/test_game_state_facade_contract.gd' = 'M'
	'tests/unit/test_restore_participants.gd' = 'M'
	'tests/unit/test_save_manager.gd' = 'M'
	'tests/integration/test_restore_transaction.gd' = 'M'
	'tests/integration/test_restore_production_adapters.gd' = 'M'
	'tests/integration/test_save_capability.gd' = 'M'
	'tests/integration/test_save_manager_journal.gd' = 'M'
	'evidence/phase_2r/runtime/game_state_surface.json' = 'M'
	'tests/fixtures/snapshots/invalid_day8.json' = 'M'
	'tests/fixtures/snapshots/invalid_object_shapes.json' = 'M'
	'tests/fixtures/snapshots/valid_day3.json' = 'M'
	'tests/fixtures/saves/day8_ending_non_group.json' = 'M'
	'tests/fixtures/saves/day8_group_invalid_with_day7_journal.json' = 'M'
	'tests/fixtures/saves/day8_group_synchronized.json' = 'M'
	'tests/fixtures/saves/day8_no_fallback.json' = 'M'
	'tests/fixtures/saves/day8_playing_with_day7_journal.json' = 'M'
	'tests/fixtures/saves/v2_future_schema.json' = 'M'
}
$optionalUids = [ordered]@{
	'tests/unit/test_effect_transactions.gd.uid' = 'A'
	'tests/integration/test_dialogic_effect_boundary.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'refactor(effects): commit narrative effects as idempotent transactions'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 3 commit boundary failed.' }
~~~

## Task 4: Implement global visited history and both skip modes

**Beads:** dwm-p2r.8

**Files:**

- Modify: docs/superpowers/plans/2026-07-17-phase-2r-05-dialogic-skip.md
- Create: scripts/narrative/SkipPolicy.gd
- Create: tests/unit/test_skip_policy.gd
- Create: tests/integration/test_dialogic_skip.gd
- Modify: autoload/DialogicBridge.gd
- Modify: scripts/ui/DialogueBox.gd
- Modify: scripts/ui/DatingScene.gd
- Extend: tests/unit/test_profile_manager.gd

**Interfaces:**

- Consumes: ProfileManager visited-history/skip preference and the Task-1-audited reveal, advance, and choice APIs.
- Produces: pure `SkipPolicy.evaluate` and one DialogicBridge skip command; normal text completion also persists visited history before recording the line checkpoint.

- [ ] **Step 4.1: Write SkipPolicy exactly and test it RED-first**

- [ ] Create the test first and dynamically load the absent policy:

~~~gdscript
extends "res://addons/gut/test.gd"

const POLICY_PATH := "res://scripts/narrative/SkipPolicy.gd"

func test_skip_stops_before_variable_transaction() -> void:
	assert_true(ResourceLoader.exists(POLICY_PATH, "Script"), "missing SkipPolicy.gd")
	if not ResourceLoader.exists(POLICY_PATH, "Script"):
		return
	var policy: Script = load(POLICY_PATH)
	var decision: Dictionary = policy.call(&"evaluate", &"all_text", false, &"variable_transaction")
	assert_true(decision["reveal_current"])
	assert_false(decision["advance"])
	assert_true(decision["stop_before_boundary"])
~~~

- [ ] Run RED before creating `SkipPolicy.gd`:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_skip_red' -LogName 'phase2r-red-dialogic-skip.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_skip_policy.gd,res://tests/integration/test_dialogic_skip.gd','-gexit')
~~~

Expected RED: `missing SkipPolicy.gd`; no Dialogic event is consumed.

- [ ] Implement this complete pure policy after tests fail on the missing file:

~~~gdscript
class_name SkipPolicy
extends RefCounted

const READ_ONLY := &"read_only"
const ALL_TEXT := &"all_text"

const STOP_BOUNDARIES: Array[StringName] = [
	&"choice",
	&"effect_transaction",
	&"variable_transaction",
	&"safe_marker",
	&"scene_transition",
	&"minesweeper_entry",
	&"validation_error",
]

static func evaluate(
	mode: StringName,
	was_visited_before_reveal: bool,
	next_boundary: StringName
) -> Dictionary:
	var normalized := mode
	if normalized not in [READ_ONLY, ALL_TEXT]:
		normalized = READ_ONLY
	var stop_before := next_boundary in STOP_BOUNDARIES
	var may_advance := not stop_before
	if normalized == READ_ONLY and not was_visited_before_reveal:
		may_advance = false
	return {
		"mode": normalized,
		"reveal_current": true,
		"mark_current_visited": true,
		"advance": may_advance,
		"stop_before_boundary": stop_before,
	}
~~~

- [ ] Unit tests cover the Cartesian product of two modes, visited/unvisited, and text plus all seven boundaries. Invalid mode behaves exactly as read_only.

- [ ] **Step 4.2: Integrate the pre-reveal visited decision**

- [ ] DialogicBridge.request_skip_step() performs:

~~~text
validate current registered line
read was_visited_before_reveal from ProfileManager
reveal current line immediately
mark current line visited globally
classify next event without consuming it
evaluate SkipPolicy
advance one text event only when allowed
return the decision/result
~~~

Every text line passed by repeated skip becomes visited. For read_only, an unread current line becomes visible/visited and automatic advance stops. all_text may continue through unread text. Both stop before a choice/effect transaction/variable transaction/safe marker/scene transition/Minesweeper entry/validation error.

- [ ] DialogueBox emits commands to DialogicBridge and renders current Dialogic presentation. It owns no text array, event index, variable store, or advancement state. Its visible log remains run-specific and is not the ProfileManager visited set.
- [ ] New Game leaves visited IDs and skip mode unchanged. Explicit visited-history reset clears only visited IDs.
- [ ] Normal (non-skip) `text_finished` handling validates the stable line ID, calls `ProfileManager.mark_line_visited()`, then prepares/commits the line checkpoint before allowing the next event. A profile-write failure halts advancement with no line checkpoint. Add an integration case that reads normally, starts a new run, restores a different slot, and proves read_only skip recognizes the globally visited line in both cases.

- [ ] **Step 4.3: Test held fast-forward and every stop boundary**

- [ ] Integration tests call request_skip_step() repeatedly to simulate held skip in both modes. They assert the boundary event has not been consumed, its transaction/route/choice signal count is zero, and current text is fully revealed.

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_skip' -LogName 'phase2r-dialogic-skip.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_skip_policy.gd,res://tests/integration/test_dialogic_skip.gd','-gexit')
~~~

Expected GREEN: both modes and seven boundaries pass; visited checks occur before marking.

- [ ] **Step 4.4: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 4 Step 4.4 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$task3Head = '4f5071b10f573f3575995915f354643f993b23c1'
if ($LASTEXITCODE -ne 0 -or -not ($expectedHead -ceq $task3Head)) {
	throw 'Task 4 requires the exact Task 3 commit boundary as HEAD.'
}
$required = [ordered]@{
	'docs/superpowers/plans/2026-07-17-phase-2r-05-dialogic-skip.md' = 'M'
	'scripts/narrative/SkipPolicy.gd' = 'A'
	'tests/unit/test_skip_policy.gd' = 'A'
	'tests/integration/test_dialogic_skip.gd' = 'A'
	'autoload/DialogicBridge.gd' = 'M'
	'scripts/ui/DialogueBox.gd' = 'M'
	'scripts/ui/DatingScene.gd' = 'M'
	'tests/unit/test_profile_manager.gd' = 'M'
}
$optionalUids = [ordered]@{
	'scripts/narrative/SkipPolicy.gd.uid' = 'A'
	'tests/unit/test_skip_policy.gd.uid' = 'A'
	'tests/integration/test_dialogic_skip.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'feat(dialogic): add global read history and boundary-safe skip'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 4 commit boundary failed.' }
~~~

## Task 5: Replace the unconditional smoke stub with a physical Dialogic fixture

**Beads:** dwm-p2r.8

**Files:**

- Create: tests/fixtures/dialogic/phase2r_contract_fixture.dtl
- Create: tests/fixtures/dialogic/manifest.json
- Create: tests/integration/test_dialogic_bridge_contract.gd
- Replace: tests/smoke_dialogic_timelines.gd
- Create: tools/testing/UnconditionalPassAudit.gd
- Create: tests/unit/tooling/test_no_unconditional_pass.gd
- Modify: tests/unit/test_input_accessibility.gd
- Bind read-only: tests/unit/test_input_accessibility.gd.uid

**Interfaces:**

- Consumes: installed serializer syntax and Task 1's separate fixture registries.
- Produces: one physical on-tree fixture contract and a smoke runner that exits nonzero on any unmet assertion.

- [ ] **Step 5.1: Build the fixture from installed serializers, not guessed syntax**

- [ ] Create `test_dialogic_bridge_contract.gd` first with a physical-file RED guard:

~~~gdscript
extends "res://addons/gut/test.gd"

const FIXTURE_PATH := "res://tests/fixtures/dialogic/phase2r_contract_fixture.dtl"
const FIXTURE_MANIFEST := "res://tests/fixtures/dialogic/manifest.json"

func test_physical_fixture_and_manifest_are_required() -> void:
	assert_true(FileAccess.file_exists(FIXTURE_PATH), "missing physical Dialogic fixture")
	assert_true(FileAccess.file_exists(FIXTURE_MANIFEST), "missing fixture manifest")
~~~

- [ ] Run RED before creating the fixture, fixture manifest, smoke replacement, or audit:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_fixture_red' -LogName 'phase2r-red-dialogic-fixture.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/unit/tooling/test_no_unconditional_pass.gd','-gexit')
~~~

Expected RED: the fixture path is missing; an unconditional pass, parser crash, or gameplay-autoload mutation is not acceptable.

- [ ] The physical `.dtl` is exactly this serializer-validated fixture (signal IDs resolve through the separate fixture manifest and never call a gameplay autoload):

~~~dtl
# timeline_id: fixture.phase2r.contract
# locale: en
# type: phase2r_test_fixture
# line_ids: fixture.line.start, fixture.line.after_choice, fixture.line.after_effect
# choice_ids: fixture.choice.continue
# signal_ids: fixture.marker.safe, fixture.effect.tx, fixture.variable.tx

label fixture.start
Narrator: Phase 2R fixture line.

- Continue
	Narrator: Choice committed.

[signal arg="fixture.marker.safe"]
[signal arg="fixture.effect.tx"]
[signal arg="fixture.variable.tx"]

Narrator: Fixture complete.
return
~~~

The fixture manifest maps the three text events in order to `fixture.line.start`, `fixture.line.after_choice`, and `fixture.line.after_effect`; the only choice to `fixture.choice.continue`; and each signal ID to its exact safe-marker/effect/variable descriptor. The worker round-trips this text through the audited event serializers and validates imported event kinds/indices before using it.

- [ ] The test fixture manifest is separate from the 61-record production manifest and records exact event indices/fingerprints after import.

- [ ] **Step 5.2: Traverse the actual addon runtime on-tree**

- [ ] test_dialogic_bridge_contract.gd must:

1. Add the Dialogic layout/fixture to the active SceneTree.
2. Start by stable timeline ID through DialogicBridge.
3. Observe text_started and text_finished for fixture.line.start.
4. Reveal it and commit its stable checkpoint.
5. Observe the choice and select fixture.choice.continue.
6. Observe/reveal `fixture.line.after_choice`, then verify skip stops before the marker without consuming it.
7. Consume the marker and verify its checkpoint.
8. Consume the effect and verify money changes once plus an effect checkpoint.
9. Consume the registered variable transaction and verify fixture.counter changes once plus a variable checkpoint.
10. Finish the final line and timeline.
11. Restore the saved first-line checkpoint and verify a fully revealed line with no duplicated effect or variable mutation.
12. Free every project-created node and await one process frame.

After steps 5, 8, and 9, also capture/restore their checkpoints and assert the exact locator chain: choice `post_event` resolves the selected branch text; effect `post_event` resolves the variable event; variable `post_event` resolves the final text. The restored `event_id/index/kind/semantic_id` and `post_event` record must equal the fixture manifest. Signal counts prove no completed choice/effect/variable event replays and no registered successor is skipped.

No assertion may be unconditional.

- [ ] **Step 5.3: Replace the smoke runner and detect future stubs**

- [ ] Replace tests/smoke_dialogic_timelines.gd with a SceneTree runner that loads the exact production/fixture manifests, validates all physical resources, runs the fixture contract, prints a structured summary, and exits nonzero on failure.
- [ ] The runner accumulates named assertion results, prints one canonical-JSON object with counts `{line,choice,marker,effect,variable,completion,restore,failures}`, calls `quit(1)` when `failures` is nonempty, and calls `quit(0)` only after the on-tree fixture frees all project-created nodes. It never catches an error and converts it to success.
- [ ] UnconditionalPassAudit rejects test functions whose only effective assertion is assert_true(true), pass_test(), or an equivalent constant success.

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_fixture_contract' -LogName 'phase2r-dialogic-contract.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/unit/tooling/test_no_unconditional_pass.gd,res://tests/unit/test_input_accessibility.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_fixture_smoke' -LogName 'phase2r-dialogic-smoke.log' -GodotArgs @('-s','res://tests/smoke_dialogic_timelines.gd')
~~~

Expected GREEN: line=3, choice=1, marker=1, effect=1, variable=1, completion=1, restore=1; zero failed fixture checks and zero unconditional stubs.

- [ ] **Step 5.4: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 5 Step 5.4 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
$task4Parent = [string](git rev-parse "$expectedHead^")
$task3Head = '4f5071b10f573f3575995915f354643f993b23c1'
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'feat(dialogic): add global read history and boundary-safe skip') -or
	-not ($task4Parent -ceq $task3Head)) {
	throw 'Task 5 requires the exact Task 4 commit boundary as HEAD.'
}
$inputAccessibilityUid = 'tests/unit/test_input_accessibility.gd.uid'
$headInputAccessibilityUid = @(git ls-tree $expectedHead -- $inputAccessibilityUid)
if ($LASTEXITCODE -ne 0 -or $headInputAccessibilityUid.Count -ne 1 -or
	$headInputAccessibilityUid[0] -notmatch '^100644 blob ([0-9a-f]{40,64})\t') {
	throw 'Task 5 requires the tracked accessibility-test UID as one regular HEAD blob.'
}
$headInputAccessibilityUidObject = $Matches[1]
$workingInputAccessibilityUidObject = [string](git hash-object -- $inputAccessibilityUid)
if ($LASTEXITCODE -ne 0 -or -not ($workingInputAccessibilityUidObject -ceq $headInputAccessibilityUidObject)) {
	throw 'Task 5 must not change the accessibility-test UID identity.'
}
$required = [ordered]@{
	'tests/fixtures/dialogic/phase2r_contract_fixture.dtl' = 'A'
	'tests/fixtures/dialogic/manifest.json' = 'A'
	'tests/integration/test_dialogic_bridge_contract.gd' = 'A'
	'tests/smoke_dialogic_timelines.gd' = 'M'
	'tools/testing/UnconditionalPassAudit.gd' = 'A'
	'tests/unit/tooling/test_no_unconditional_pass.gd' = 'A'
	'tests/unit/test_input_accessibility.gd' = 'M'
}
$optionalUids = [ordered]@{
	'tests/integration/test_dialogic_bridge_contract.gd.uid' = 'A'
	'tools/testing/UnconditionalPassAudit.gd.uid' = 'A'
	'tests/unit/tooling/test_no_unconditional_pass.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'test(dialogic): replace smoke stub with real fixture traversal'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 5 commit boundary failed.' }
~~~

## Task 6: Run the narrative subsystem gate

**Files:**

- Create: tools/dialogic/WriteDialogicGateSummary.gd
- Create: tests/unit/tooling/test_dialogic_gate_summary.gd
- Generate: evidence/phase_2r/dialogic/gate_summary.json
- Modify through `bd`: .beads/issues.jsonl

**Interfaces:**

- Consumes: Tasks 1–5 and the real SaveManager restore-adapter gate.
- Produces: `WriteDialogicGateSummary.build(inputs: Dictionary) -> Dictionary` and requirement-linked canonical evidence for `dwm-p2r.8`; no new runtime API.

- [ ] **Step 6.1: Write the summary RED test**

- [ ] Create the summary test first:

~~~gdscript
extends "res://addons/gut/test.gd"

const WRITER_PATH := "res://tools/dialogic/WriteDialogicGateSummary.gd"

func test_gate_summary_writer_is_required() -> void:
	assert_true(ResourceLoader.exists(WRITER_PATH, "Script"), "missing gate summary writer")
~~~

- [ ] Run RED before creating the writer/evidence:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_gate_summary_red' -LogName 'phase2r-red-dialogic-gate-summary.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_dialogic_gate_summary.gd','-gexit')
~~~

Expected RED: `missing gate summary writer`.

- [ ] **Step 6.2: Implement the fail-closed summary writer**

- [ ] Implement `class_name WriteDialogicGateSummary extends RefCounted` with `static func build(inputs: Dictionary) -> Dictionary` using this complete pseudocode:

~~~text
require inputs keys exactly manifests, logs, fixture_counts, requirement_ids
require manifests/logs are nonempty arrays of root-relative registered paths
for each sorted path: reject escape/missing; read bytes; compute lowercase SHA-256
strict-parse each JSON input; require its declared result is GREEN
require production counts 61 total, 24 placeholder, 37 draft
require fixture_counts exactly line=3, choice=1, marker=1, effect=1,
  variable=1, completion=1, restore=1, failures=0
require sorted unique nonempty requirement_ids and dwm-p2r.8 linkage
return CommandResult success containing only sorted primitive records/hashes/counts
on any failure return CommandResult failure with code gate_evidence_invalid and no candidate
~~~

The script entry point strict-parses every Task 1–5 evidence/log, calls `build`, writes canonical JSON to `evidence/phase_2r/dialogic/gate_summary.json`, strict-re-reads it, and exits 1 on any missing file, non-GREEN result, count mismatch, duplicate requirement ID, or byte mismatch. The summary contains exact manifest hashes, `61/24/37`, fixture counts, focused command lines/log hashes, ownership-scan results, and the requirement IDs attached to `dwm-p2r.8`; it contains no claimed implementation authorization.

- [ ] **Step 6.3: Run the narrative subsystem gate**

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_gate' -LogName 'phase2r-dialogic-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_timeline_manifest.gd,res://tests/unit/test_dialogic_runtime_adapter.gd,res://tests/unit/test_narrative_checkpoint_schema.gd,res://tests/unit/test_save_manager_narrative_checkpoint_port.gd,res://tests/unit/test_dialogic_ending_playback_port.gd,res://tests/unit/test_effect_resolver.gd,res://tests/unit/test_effect_transactions.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_skip_policy.gd,res://tests/unit/test_input_accessibility.gd,res://tests/unit/tooling/test_no_unconditional_pass.gd,res://tests/unit/tooling/test_dialogic_gate_summary.gd,res://tests/integration/test_dialogic_restore.gd,res://tests/integration/test_narrative_checkpoint_wiring.gd,res://tests/integration/test_ending_dialogic_wiring.gd,res://tests/integration/test_restore_production_adapters.gd,res://tests/integration/test_dialogic_effect_boundary.gd,res://tests/integration/test_dialogic_skip.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_restore_transaction.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_gate_summary' -LogName 'phase2r-dialogic-gate-summary.log' -GodotArgs @('-s','res://tools/dialogic/WriteDialogicGateSummary.gd','--','--output=res://evidence/phase_2r/dialogic/gate_summary.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

- [ ] Validate 61 production statuses and the separate fixture; confirm no Chinese narrative record or narrative adapter was fabricated.
- [ ] Run `rg` ownership scans proving no arbitrary timeline path start, direct Dialogic start/clear outside the bridge/adapter, alternate narrative index, missing `variable_transaction` signal/skip classification, or `assert_true(true)` remains. Expected production matches: zero.
- [ ] Append exact manifests, commands, counts, logs, and `gate_summary.json` to dwm-p2r.8 with `bd update`; run `bd dep cycles`, `bd lint`, and `bd show dwm-p2r.8 --json`; close only with every acceptance criterion GREEN.
- [ ] Confirm dwm-p2r.9 becomes ready.

- [ ] **Step 6.4: Proposed evidence commit boundary (requires explicit commit authority)**

~~~powershell
if (-not ($env:DWM_COMMIT_AUTHORIZED -ceq '1')) {
	throw 'Task 6 Step 6.4 requires DWM_COMMIT_AUTHORIZED to be exactly 1.'
}
$expectedHead = [string](git rev-parse HEAD)
$expectedSubject = [string](git show -s --format=%s $expectedHead)
$task4Head = [string](git rev-parse "$expectedHead^")
$task4Subject = [string](git show -s --format=%s $task4Head)
$task3HeadFromChain = [string](git rev-parse "$expectedHead^^")
$task3Head = '4f5071b10f573f3575995915f354643f993b23c1'
if ($LASTEXITCODE -ne 0 -or $expectedHead -notmatch '^[0-9a-f]{40,64}$' -or
	-not ($expectedSubject -ceq 'test(dialogic): replace smoke stub with real fixture traversal') -or
	-not ($task4Subject -ceq 'feat(dialogic): add global read history and boundary-safe skip') -or
	-not ($task3HeadFromChain -ceq $task3Head)) {
	throw 'Task 6 requires the exact Task 5 commit boundary as HEAD.'
}
. ([IO.Path]::GetFullPath('.\tools\testing\Read-StrictJson.ps1'))
$issueLines = @(bd show dwm-p2r.8 --json --readonly)
if ($LASTEXITCODE -ne 0) { throw 'Could not read dwm-p2r.8 before its evidence commit.' }
$issueText = [string]::Join([Environment]::NewLine, $issueLines).Trim()
$issues = @(ConvertFrom-Phase2RStrictJson -Json $issueText -Label 'bd show dwm-p2r.8')
if ($issues.Count -ne 1 -or -not ([string]$issues[0].id -ceq 'dwm-p2r.8') -or
	-not ([string]$issues[0].status -ceq 'closed')) {
	throw 'Task 6 evidence commit requires exactly closed dwm-p2r.8.'
}
$required = [ordered]@{
	'tools/dialogic/WriteDialogicGateSummary.gd' = 'A'
	'tests/unit/tooling/test_dialogic_gate_summary.gd' = 'A'
	'evidence/phase_2r/dialogic/gate_summary.json' = 'A'
	'.beads/issues.jsonl' = 'M'
}
$optionalUids = [ordered]@{
	'tools/dialogic/WriteDialogicGateSummary.gd.uid' = 'A'
	'tests/unit/tooling/test_dialogic_gate_summary.gd.uid' = 'A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
	-RequiredStatus $required `
	-OptionalPresentStatus $optionalUids `
	-AllowedDirtyPaths @('.beads/interactions.jsonl') `
	-ExpectedHead $expectedHead `
	-Message 'test(dialogic): record narrative subsystem gate evidence'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 6 evidence commit boundary failed.' }
~~~
