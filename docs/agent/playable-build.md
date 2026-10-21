# Playable-build readiness — Coordinator D, 21 October 2026

Integration preparation, not gameplay acceptance or a release. The held product is [PR36](https://github.com/Siuuuers/dwm/pull/36), `c8358870d3ece92d5f8cc7ba65aefe34a746be5c`, draft/unmerged. Godot **4.6.3 standard GDScript** and PowerShell execution remains cloud-only. The previous local Mono/desktop/calendar instructions describe a historical build; their exact text remains in [the parent version](https://github.com/Siuuuers/dwm/blob/c8358870d3ece92d5f8cc7ba65aefe34a746be5c/docs/agent/playable-build.md).

Assignment: [Director6318547755](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6318547755). A owns implementation, product assembly, controller and cloud attempts; C reviews concrete changes/results; Director selects further scope; D updates this existing handoff. No runtime/workflow/inventory changes, regeneration, dispatch, merge or product-ref movement belongs to this D task.

## Source identity before interpreting results

| Role | Observed immutable source | Meaning |
|---|---|---|
| Product | `c8358870d3ece92d5f8cc7ba65aefe34a746be5c` | Held PR36 candidate; ordinary CI below. |
| Integration | `3ae6d9138fb53c388380c78550cf6082eafc0ea3` | PR36 target; later product changes are not integrated here. |
| Controller | `1caf3f2c95ac1e7817d22eebd314c0bd725bef94` | PR30 workflow lane; ordinary checkout differs from product. Never merge it into product. |
| Product reference | PR1 `a6decec3693ee4d57df9f879b90ace3e118c9d1d` | Major historical reference; Git ancestry confirms it is already an ancestor of held PR36. |
| Master | `41592fcc792aa615e47ee2ce2f05008ca195b311` | PR41 story consolidation. Diff from `0c8b2384` has no changes under autoload/scripts/addons/tools/project.godot/export_presets.cfg; no runtime fix in that delta to import. |

Recheck refs before later integration. Diagnostic candidates and receipts do not implicitly change held product. Story consolidation is not runtime story placement.

## Public inventories: distinguish classification from output drift

**Product passes.** [Run39437998817/job118680048651](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118680048651), source c8358870, tested merge `29a5ee013e920a8465dea42e172ae350a9a2af62`, passed public-surface checks. No product regeneration is justified by the controller failure.

**Earlier output drift is repaired.** Reuse the [canonical refresh](../../evidence/phase_2r/inventory_refresh_20261020/README.md) and [Gallery-caption refresh](../../evidence/phase_2r/inventory_refresh_20261020/gallery-caption-inventory39394031743/README.md). The latter changes lexical `capture_run_snapshot_input` coordinates361→380 and `initialize`66→68, qualified11/352 with five validation exits0. It is already integrated at83da. The c835 delta changes evidence/handoffs and two tools/testing PowerShell files, not scanner roots, required manifests or inventories.

**Controller classification gaps are real on its checkout.** [Run39613426725/job119268011958](https://github.com/Siuuuers/dwm/actions/runs/39613426725/job/119268011958) fails GameState on25 `SURFACE_UNCLASSIFIED` declarations before canonical-output comparison. These are declarations, not25 proven new gameplay calls. `tools/runtime/PublicSurfaceInventory.gd` validates current-manifest dispositions before `check_canonical_json`; output regeneration cannot supply missing classifications.

Independent read-only declaration/manifest comparison (not a fresh engine test):

| Source | GameState declarations / current classifications / stored records | SaveManager declarations / current classifications / stored records |
|---|---:|---:|
| Product c835 |271 /271 /271|82 /82 /82|
| Controller1caf |269 /244 /243|82 /74 /74|
| Master41592 |239 /239 /239|74 /74 /74|

Product and master have zero missing current dispositions. Product embedded required manifests equal their live required files. Controller GameState stored metadata also predates its `capture_scene_entry_audio` classification.

The controller log's25 names are: `SCENE_GAMEPLAY_KEYS`, `admit_scene_target`, `advance_scene_registered_marker`, `apply_scene_new_run_silent`, `capture_scene_challenge_closure`, `capture_scene_challenge_command`, `capture_scene_contact_context`, `commit_scene_challenge_checkpoint`, `commit_scene_challenge_closure`, `configure_scene_challenge_runtime`, `configure_scene_checkpoint_source`, `configure_scene_runtime_validation`, `continue_completed_scene_challenge`, `emit_scene_contact_message`, `make_scene_new_run_gameplay`, `prepare_scene_new_run`, `prepare_scene_new_run_snapshot_input`, `prepare_selected_scene_absence`, `resolve_scene_contact_facts`, `scene_entry_staging_context`, `validate_scene_challenge_command`, `validate_scene_challenge_end`, `validate_scene_entry_staging_source`, `validate_scene_snapshot_semantics`, `validate_selected_scene_absence`.

Eight additional controller SaveManager gaps are **static findings, not executed failures in that run**: `configure_scene_new_run`, `configure_scene_title_new_run`, `start_scene_new_run`, `retry_scene_activation`, `load_restore_context`, `capture_committed_scene_restore`, `configure_scene_restore_participants`, `capture_committed_scene_creation`. Its downstream skips/failed prerequisite aggregate do not establish new game defects. A owns any future reconciliation; D does not repair or dispatch it.

## Actual held-product CI obligations

[Run39437998817](https://github.com/Siuuuers/dwm/actions/runs/39437998817), attempt1: **5 successful jobs,16 failed,1 cancelled,1 skipped**. This is a job-status census, not an assertion total. These are committed workflow gates; GitHub branch-protection enforcement was not established. Public surfaces, exported startup, minesweeper, audio and checkpoint_diagnostics succeeded. Settings was cancelled; the comparison matrix was skipped. Neither is a pass. Gallery register/caption steps passed before the journey step failed.

Observed log boundaries below are not exhaustive root-cause diagnoses. A owns selected implementation; C reviews; Director chooses scope. No blanket legacy-test rewrite is authorized.

| Failed job | Observed boundary / disposition |
|---|---|
| [Rendered journeys](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358149) | Six desktop-startup expectation failures; Practice logs show active SceneHost/scene route. Reuse the reviewed [six-case obligation map](../../evidence/phase_2r/inventory_refresh_20261020/legacy-journey-coverage/README.md). Later Solo/selector steps skipped. Do not merely rename the startup assertion. |
| [Hospital reading](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358156) | Both recorded attempts: write exit1, missing HOSPITAL_READING_WRITE_PASS, assertion failures, two orphan names. Historical restore/refusal obligations survive retired orchestration; wrapper log does not fully locate cause. |
| [Ordered ending](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358460) | PROCESS_FAILED:write. Full physical-boundary/fresh-Load proof unqualified; wrapper summary does not locate assertion. |
| [Timed hold](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358390) | Real New Account activated Run assertion fails; exit1/lifetime diagnostics. Preserve Pause/fresh-input obligation when reviewing startup assumptions. |
| [Checkpoint performance](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358224) | `benchmark desktop ready` fails before valid matched comparison. Not performance evidence. |
| [Seven-day producer](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358529) | `derive_save_admission_baseline.py`: Expected3 current-source admission anchors. Baseline construction failure. |
| [Seven-day aggregate](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118686537092) | Producer/comparison prerequisites unsuccessful; consequential gate failure, not another observed gameplay defect. |
| [Shop](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358602) | Null/empty shop state, checkpoint-action failures and unexpected errors. Case-level retired route/item disposition needed; purchase/recovery obligations remain. |
| [Desktop](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358670) | `scene_validation_already_configured`, issuer conflicts, setup failures and geometry mismatch. Review fixture ownership before production authority changes. |
| [Localization](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358633) |311 versus hardcoded308 (`test_japanese_korean_ui.gd:48`), plus reply_ids/ok access errors. Census correction alone cannot pass suite; preserve per-ID/placeholder checks. |
| [Endings](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358645) | Unknown historical ending.priscilla.sweet/ending.sylvia.dark entries, empty labels/media assertions. TEST ending evidence is not whole historical catalogue qualification. |
| [Reading delivery](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358726) | Unknown Solo entry, unregistered ending.alone.dark_mode, unavailable Gallery record. Return/History obligations remain; no registry opening authorized. |
| [Persistence](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358807) | Historical entry refusal, snapshot/access errors, exact Notes reverse-fragment count failure. Preserve [provenance obligations](../../handoff/a-public-inventory-20261017.md); never rewrite immutable seals to match current owners. |
| [New account](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683359239) | Historical vector rejects `health:+1`/unknown_effect_id. Reconcile historical fixture authority; do not revive retired health gameplay. |
| [Dating](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358870) | Regression step failed. Log retrieval returned Transport closed twice; cause unclassified here, not inferred from neighboring suites. |
| [Linux desktop/dialogue](https://github.com/Siuuuers/dwm/actions/runs/39437998817/job/118683358861) | Scaling dictionary/index errors (`1`, protein_box, index12), blank-card/sample failures; separate five-sink UI literal audit failure below. Geometry/accessibility obligations remain. |

UI audit sinks: `SceneHost.tscn:99 text` and`:100 accessibility_name` (Yes defaults), `ComputerDesktop.gd:1045 text` (fallback label), `SceneHost.gd:88 text` (localized conditional label), `PauseSurface.gd:89 text` (Back). These are missing audit classifications at this source, not public-inventory output drift. Some source values already use localization; failure does not prove every displayed string is untranslated. Back localization remains explicitly deferred by the existing Director disposition.

## Accepted work and four remaining areas

| Area | Existing evidence / owner | Remaining qualification |
|---|---|---|
| Caption / Continue | A implementation, C review; [actual result](https://github.com/Siuuuers/dwm/pull/36#issuecomment-6318388769), [C review](https://github.com/Siuuuers/dwm/pull/36#issuecomment-6318487912). | Reader File.Replace second publication fails before verified identity/UIA attachment. Null/string interop is hypothesis. Game1case,16/17 assertions,exit1,zero notifications. Exact writer repair + actual Windows PowerShell5 preflight is selected; after C clearance, A has one authorized run, no automatic retry. |
| Exported completion / Gallery / Title / terminal Load | [TEST week25/623](../../handoff/a-seven-day-connected-20261016.md), [no-Save return1/52](../../handoff/a-ending-return-20261016.md), [export history](../../handoff/a-exported-gameplay-20261018.md). A delivery, C review. | Exported startup is not native completion→Title→fresh completed-save Load→clean exit. Replay of the exact Gallery version earned by that completion is not proven by combining unrelated fixtures. |
| Responsiveness / clean completion | [Cost/source reconciliation and qualified deadline guard](../../evidence/phase_2r/native_delivery_proposal_20261020/README.md); guard integrated at c835. | Diagnostic33.179067s transition remains open. Late-result rejection is not preemption/speedup. Require matched complete-operation evidence before optimization; preserve validation/receipts/History. |
| Integration / CI / handoff | This page and [A resume record](../../handoff/a-resume-20261019.md); Director promotion, A assembly, C review. | Failures/cancellation/skips, supported replacement coverage and final candidate acceptance remain. Four overlapping areas do not imply a completion percentage. |

These are primarily qualification/integration boundaries, not four missing features. Reuse bounded [optional Challenge](../../handoff/a-optional-challenge-result.md), [first Reveal](../../handoff/a-scene-desktop-first-reveal-result.md), [partner fork](../../handoff/a-partner-fork-20261017.md) and [private rehearsal](../../handoff/a-gallery-rehearsal-20261018.md) evidence within its limits. Production prose/partner placement remain separate content inputs. Retiring orchestration does not retire historical-save compatibility. Valid durable caption History is not forbidden by old blanket Profile-invariance wording.

## Minimal eventual integration order

1. **Start with held c835.** PR1 is already ancestry. Archived-source discovery, Gallery register/caption corrections with generated inventories, and deadline guards are integrated through a01497d1→2c188cd5→83da885c→c8358870. Do not reimport them.
2. **Finish A/C's selected isolated writer gate.** Preserve original failures and source/helper/controller/runtime pins. Diagnostic authorization does not permit wholesale instrumentation import, forced updates, rejected anchor optimization or changed observation windows.
3. **Compose only evidenced product deltas.** Review callers, saves/History/authority and actual runtime need; the minimal product delta may be none. A installs reviewed bytes with expected-head protection. If scanned source changes, classify declarations first, then obtain canonical cloud-generated inventories; ordinary CI remains check-only.
4. **Qualify one coherent candidate.** Use the completed six-case map rather than repeating its audit. Complete independent reviews before final acceptance; exported E2E, valid performance/history comparisons and historical compatibility retain separate appropriate evidence. Cancelled/skipped jobs never count as passes.
5. **Director-controlled promotion after review.** A rechecks integration/master/story changes, resolves conflicts in isolation and records exact final source/test tree. PR30 never enters product. No merge/release or product/master/integration movement follows from this handoff.

Documentation validation: read-only Git/source comparison, GitHub job/step/log inspection, independent inventory review, links/whitespace. No Godot/PowerShell execution, regeneration or dispatch. Job logs are not a fresh original-archive audit; accepted archive reviews are reused. This replaces a stale entry point, not the existing task system or Beads.
