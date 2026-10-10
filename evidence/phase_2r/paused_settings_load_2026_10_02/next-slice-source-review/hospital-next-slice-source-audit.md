# Hospital next-slice source audit

Read-only snapshot: `78cb263f8e0d82ad1f1274c0e84915397cd071b0`. No repository edits, Godot/PowerShell execution or runtime acceptance. This review does not enlarge the pending Settings F9 acceptance.

**Finding:** Hospital continuation and frozen gameplay facts already have owners, but the new semantic reading/History/Save path remains explicitly Solo-only. The next Hospital increment needs bounded integration work before a connected Save/Load proof can pass; it is not just another fixture of the existing Solo path.

## Approved contract and current seams

| Boundary | Source evidence | Consequence for next work |
| --- | --- | --- |
| Fresh semantic session | `docs/design/current-ui/witnessed-scene.md:1007–1021`; `docs/design/2026-08-22-hospital-ordered-ending-current-v1-ui-disposition.md:136–149` | Hospital imports no prior captions/History; only actual Hospital publications appear. A later Dating/Priscilla–Lavinia scene starts fresh again. One ordered ending has a separate uninterrupted History law. |
| Completion/UI | `witnessed-scene.md:1058–1070`; Hospital disposition `:123–132,163–170` | Existing physical completion owns settlement; no Hospital Continue/completion message. This is already decided, not a new design interview. |
| Canonical Hospital entry | `scripts/application/run/HospitalPresentationPort.gd:114–161`; `scripts/application/run/DayResolutionCoordinator.gd:461–515`; `scripts/application/run/GameStateConditionHospitalPort.gd:276–305` | Reuse the issued command, completion ancestry, coordinator and route publication. Neither caption presenter nor fixture should choose recovery/day/route consequences. Both Schedule-Done and condition-Hospital paths exist; select one explicitly for the first bounded proof. |
| Physical playback | `scripts/application/narrative/DialogicPresentationOwnerAdapter.gd:110–164`; `autoload/DialogicBridge.gd:227–254,425–479` | Sylvia-present Hospital currently starts `start_timeline_id`, whose frozen lookup resolves a semantic entry locator but still runs ordinary playback. It does not acquire the new semantic reading session or bind its ledger. Preserve exact physical completion receipt ownership while integrating the reading seam. |
| Session admission is Solo-only | `autoload/DialogicBridge.gd:1752–1797`; `scripts/narrative/SoloReadingSession.gd:26–43,48–52,91–106` | `context.kind != solo` is disabled; the session/catalogue requires Solo pre/post entry structure. Merely registering Hospital text cannot enable History. Use one shared ledger/bridge with explicit family admission, not a parallel Hospital transcript or fake Dating IDs. |
| Existing exit behavior | `scripts/application/run/DatingNarrativePlayback.gd:138–143`; `DialogicBridge.gd:1809–1814` | Post-Dating completion retires its reading session. Hospital currently has no corresponding semantic session begin/retire integration. Prove both entry reset and Hospital-to-next-scene reset, including restore/abandonment, rather than assuming absence of a current scene clears all data. |
| Save admission | `autoload/ApplicationBootstrap.gd:881–916`; `scripts/application/lifecycle/ProductionPauseController.gd:501–519,598–623` | Capture allows only main/Dating; reading Save requires Dating presentation/physical authority. Hospital must remain honestly unavailable until its canonical command and independently frozen context are captured. Do not widen route strings alone or permit empty narrative fallback. |
| Restore validation | `scripts/application/restore/NarrativeRestoreParticipant.gd:73–85,112–141,213–239`; `scripts/narrative/FrozenRunContext.gd:49–140` | The reading participant already demands the complete matching saved Run and silent staged/finalized install. Its independent authority validator is Dating-only: route `dating`, `active_dating_challenge`, canonical_solo and pre/post frames. Add independently validated Hospital-command authority before accepting any Hospital reading envelope; retain the transaction and compensation owner. |
| Frozen Hospital facts already exist | `scripts/narrative/HospitalFrozenContext.gd:13–27,30–104,106–131`; `FrozenRunContext.gd:228–279,439–464` | Reuse day, cause, accepted/unfulfilled records and Sylvia eligibility/witness from saved canonical Hospital requests. Do not sample live gameplay on restore or treat causal receipt IDs as new wording variants. |
| Routing | `autoload/SceneRouter.gd:452–511` | The existing router validates the Hospital port and injects the canonical command off-tree. Route/restore publication custody must continue to own mounting. |

## Concrete design/source conflict

`scripts/ui/HospitalScene.gd:76–96,107–108,125–132` still exposes the no-Sylvia “You fainted” notice and Continue acknowledgment. `DialogicPresentationOwnerAdapter.gd:150–164,167–185` skips playback for that branch and completes a notice; `capture_pause_source` refuses this notice branch at `:202–211`. `tests/scene/test_hospital_scene.gd:173` and `tests/unit/test_hospital_frozen_context.gd:170` encode that older behavior.

That conflicts with the approved no-Hospital-chrome/Continue and genuine-authored-silent-hold laws above. It is a real existing conformance gap, not a demonstrated regression caused by F9. Keep it explicit in the Hospital backlog. Do not invent an authored silent duration to disguise the missing prose or silently replace the notice while claiming only test changes.

To keep the first reading/Save slice bounded, use a receipt-proven **Sylvia-present noncanonical fixture**. State that no-Sylvia chrome/hold conformance remains outside that proof. If the implementation changes the shared no-Sylvia path, include its conformance and completion tests deliberately instead of inheriting the old expectations unnoticed.

## Smallest useful next proof

1. Select one existing canonical Hospital ingress (Schedule-Done or condition-Hospital) and retain its real issued command/frozen context/physical completion owner. Register a clearly noncanonical two-caption Hospital programme through the same explicit test injection used by reading fixtures; keep production registration disabled.
2. Enter from a distinguishable prior semantic session. Prove Hospital starts with empty History and caption retention, then contains only its actually published fixture captions. Reused identical text must still be a distinct publication when authority says it is; inspection creates no witness or gameplay mutation.
3. At a later partial Hospital caption, plain Pause and Cancel preserve literal reveal. An explicit admitted Save finishes only that caption and stores its canonical point, exact ordered ledger and Hospital command/source authority. Retain original save bytes and source observations.
4. A fresh cloud process loads that exact save through the existing restore transaction. Compare full frozen Hospital context, command/cursor authority, exact current stable caption and History; show the current line fully without new witness, repeated speech or duplicate completion. Forge an earlier frame/source reference coherently and prove independent saved-Run authority rejects it before publication.
5. Complete through actual narrative input/natural completion. The retained physical owner emits its exact completion once and the existing coordinator advances. The subsequent legitimate scene starts fresh captions/History. Include a recoverable restore failure/compensation boundary only if the new integration changes that hook.

This is one family/ingress fixture, not all Hospital causes, no-Sylvia holds, every stable beat or ending continuity. Ordered-ending step boundaries and stale-save receipt/History merge remain separate. Start with a static contract/owner plan for these exact seams, then implement and run affected cloud coverage.

## Authored inputs and questions

No new architecture-changing owner question was found for the bounded fixture: fresh Hospital/next-session identity, publication-only History, existing completion ownership, Save/Load semantics and shared-ledger reuse are already specified. The session-family admission and independently validated saved Hospital authority need engineering design, with the constraints above; these are not reasons to ask the user to restate settled behavior.

Production authoring is not ready: `dialogic/timelines/en/core/hospital_faint.dtl:1–56` contains only comments, returns and seven day labels. There are no production captions or timed holds to integrate. The existing frozen context supplies known facts but cannot prove which facts independently alter authored wording/staging. Ask for an actual per-entry authored selector/timing contract only when production registration is next, or if a concrete authored requirement proves another independent field is needed. Do not invent production dialogue, dwell durations or variant identity from receipt IDs.

## Cloud coverage trap

The canonical suite currently includes `test_hospital_frozen_context.gd` and `test_hospital_scene.gd` in `reading_delivery`. `test_hospital_presentation_port.gd`, `test_condition_hospital_coordinator.gd`, `test_game_state_condition_hospital_port.gd` and `test_hospital_dating_adapter_negative_contract.gd` are **not registered in `Invoke-CloudTests.ps1`**. Existing files are not evidence that the future cloud gate executes those owners. If touched, register the affected fixtures intentionally or select an explicit cloud invocation and audit actual discovered cases.
