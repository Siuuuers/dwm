# Day7 closing → ending readiness: offline cost reconciliation

Director [6273381902](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6273381902), 19 October 2026 UTC. Observable goal: reduce the complete transition's synchronous work while preserving its source receipt, ending admission, refusal/retry/recovery and history contracts. This slice maps existing evidence; it does not implement or qualify a performance correction.

**Disposition: no additional safe runtime optimization is established by the retained evidence.** The large history-validation scopes are live authority checks, not proven redundant pure reconstruction. The previously focused-tested reconstruction experiment is already in the measured frozen game. Do not repeat or re-propose it as a new improvement. No new native run, runtime patch, checkpoint removal, timeout widening or engine promotion follows from this report.

## Evidence and source reconciliation

Use the [original run39279335309 packet](../title_timing_20261019/run39279335309/README.md) and its primary `exported-load/game.stdout.log` only. `selected-profiles.json` preserves the final seven records, lines109–115, verbatim as parsed JSON. Archive SHA256477cef168d3c7e76f76d19198050866dfe132cc4003e5e486c2d9e8bfbf405c3 was checked on retrieval; consume the completed A/C193-payload verification, without a repeat archive campaign. External C's result review [6272967093](https://github.com/Siuuuers/dwm/pull/36#issuecomment-6272967093) is complete; the old restart's review-next wording is superseded.

Frozen game `81847d8b1560340a3a7769223cee0b46c6bdc0f9`; current product/report head `19b5efd0c3a51852079c11d0fe7789743ff30495`. Checkpoint port, narrative checkpoint port, CheckpointJournal and ApplicationBootstrap are byte-identical between these refs. SaveDocumentSchema differs only in diagnostic timings. GameState and DialogicBridge add opt-in timing in the frozen source; SceneEventContract also contains the already completed isolated reconstruction improvement. Frozen EndingScene/caption files additionally contain the unpromoted publication experiment. These are not identical whole product trees, and the measured engine is diagnostic.

Master rechecked at `0c8b2384415d71bd3de4ff7408640bbf60b63740`; integration at `3ae6d9138fb53c388380c78550cf6082eafc0ea3`; controller at `929423d0de7984e6fbfd90de292414bdafd62eb0`. Master has neither `_admit_scene_ending_owned` nor `_scene_journal_error`; there is no already-landed equivalent fix in those owners. No protected/controller ref is changed here.

## Complete operation, with nested costs kept inside their parents

Source links below use frozen game line numbers. All durations are seconds. `scene_forward_total` is an internal operation, **not** caption readiness or complete player-journey time.

| Disjoint outer portion | Duration | Owner/calls |
|---|---:|---|
| Request preparation | 0.307665 | [GameState4914–4953](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/autoload/GameState.gd#L4914): guard, capture marker/frontier, retry lookup, issue identity, construct event and live session |
| Dispatch, inclusive | 15.597958 | Bridge dispatch → [GameState4550–4645](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/autoload/GameState.gd#L4550): validate event/result/ledger, commit checkpoint16, then adopt receipt only after source/lease recheck |
| Ending admission, inclusive | 17.271897 | [GameState5186–5216](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/autoload/GameState.gd#L5186), [5467–5509](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/autoload/GameState.gd#L5467): authenticate saved trigger/source, create/reuse terminal plan, validate admission, capture rollback, enter ENDING, checkpoint17 |
| Outer remainder | 0.001547 | Arithmetic residual; includes wrapper/unallocated work, not a separately timed function |
| Complete forward total | **33.179067** | Sum of the preceding disjoint rows |

Inside dispatch, event scope14.924676 comprises event validation0.641685 + source-checkpoint wrapper13.890249 + receipt adoption0.392066 + residual0.000676. Dispatch minus event is0.673282; it is not attributed to a single Bridge subcall. Checkpoint16 port prepare+commit is13.591644, nested in that13.890249 wrapper. Narrative port [205 onward and383–480](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd#L383) captures providers/backups, checks scene/candidate custody, then prepares/commits/compensates. The0.298605 wrapper difference is unisolated.

Inside ending admission, the timestamped ApplicationBootstrap checkpoint wrapper is16.421435, leaving0.850462 outside it. The source enters lifecycle ENDING before this write, and rolls live state back on definite refusal; uncertainty remains fatal. The wrapper [2264–2287](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/autoload/ApplicationBootstrap.gd#L2264) captures ending reading/audio/input and journal backup, prepares, commits, and compensates on definite failure. Marker prepare8.497141/commit7.918463 includes wrapper instrumentation; port timings below are slightly narrower. Never add both versions.

After successful admission, [GameState5122–5184](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/autoload/GameState.gd#L5122) releases the transaction, retires scene playback, and routes through a deferred retirement callback with live-session/lifecycle checks. EndingScene then requests playback through its existing state/playback ports. These later publication/acquisition costs are **not isolated** by the seven profiles. A completed forward scope does not establish a responsive caption.

## Checkpoint construction and commit

| Port scope / nested portion | Checkpoint16 | Checkpoint17 | Work and obligation |
|---|---:|---:|---|
| Prepare total | 6.734977 | 8.496695 | Complete prepare boundary |
| ↳ Run snapshot build | 1.258315 | 2.282618 | Normalize producer StringNames; build/validate fresh current snapshot; exact validated object feeds journal preparation |
| ↳ Document construction | 5.470921 | 6.208034 | New document with detached current bundle and four retained history bundles |
| ↳ Physical backup | 0.004405 | 0.004668 | Capture existing Autosave preimage; not all persistence cost |
| Commit total | 6.856667 | 7.917419 | Complete commit boundary |
| ↳ Outgoing schema block | 5.498655 | 6.007347 | Normalize actual outgoing document; validate current and spliced history against bytes to be written |
| ↳ Journal commit | 1.327996 | 1.880664 | Validate prepared current again, sequence/run checks, then install private retained state |
| ↳ Atomic write | 0.014793 | 0.014057 | Storage transaction, including its existing hooks/witness calls |
| ↳ Reread / reread validation | 0.002303 / 0.000394 | 0.002199 / 0.000396 | Read actual written bytes; require exact text and validated witness |

Children are not exhaustive and must not be added to their parent. The four port totals sum30.005758 of33.179067;3.173309 remains in other/wrapper work. This does not isolate observer overhead or predict uninstrumented performance.

[Port216–278](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/scripts/application/run/SaveManagerCheckpointPort.gd#L216) builds Run, prepares journal, fetches all four retained document proofs, constructs Save9, then captures backup. A complete proof set avoids prior normalization/primitive reconstruction; it does **not** authorize skipping current scene authority checks.

Checkpoint17's6.208034 document construction includes current validation2.180073 and scene-journal validation3.992369. Metadata4.024494 contains the scene-journal scope and proof binding0.032113; it is not additional metadata-only cost. Composition itself0.001620 and current text normalization0.001759 are small. Checkpoint16's corresponding current/history validation is1.604091/3.828532.

[SaveDocumentSchema328–344,405–417](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/scripts/infrastructure/save/SaveDocumentSchema.gd#L328) revalidates each historical Run9 through its canonical owner, then checks family/run/content, registration, duplicate IDs and predecessor sequence in order. Four historical bundles need not have the same receipt ledger or source-reading state as current. `_validate_journal` is only primitive-shape validation; it is not equivalent to this authority pass.

Checkpoint17 commit's outgoing scene-journal4.012322 is nested in proven-journal composition4.032476, itself inside outgoing schema6.007347. Current validation1.962816 is separate within that schema block. Retained `history_run9_*` counters cover historical validation, **not all current validations**. Within prepare history, semantic-owner2.764041 contains frozen-context0.972228, receipt1.005516 and reading-anchor0.740737 work. Outer receipt0.917484 is a separate owner call. These cannot be added as independent optimization savings.

[Port344–431](https://github.com/Siuuuers/dwm/blob/81847d8b1560340a3a7769223cee0b46c6bdc0f9/scripts/application/run/SaveManagerCheckpointPort.gd#L344) must accept/reject the actual possibly edited outgoing value. Its emitted historical bytes come from journal-owned texts, not caller-edited journal dictionaries. After physical write/reread, CheckpointJournal validates and installs its own candidate; exact comparison prevents edited output from poisoning future retained proofs. Successful old validation therefore cannot simply replace commit validation.

## Smallest correction disposition and precise missing fact

**Reject the proposed shortcut of reusing prepare/retained-history validation across commit or public validators. No replacement runtime patch is proposed in this slice.** The existing [receipt-equivalence audit](../../../handoff/a-receipt-equivalence-audit-20261018.md) establishes separate Run, GameState and Frozen authority, live SaveManager/Profile proof reads, detached-input mutation checks and terminal/source-reading obligations. Equal bytes do not prove unchanged authority. The [reconstruction comparison](../receipt_reconstruction_comparison_20261018/README.md) already extracted safe same-invocation pure construction; frozen81847 includes it. The rejected proof-normalization comparison remains rejected; small proof-binding time is not a reason to rerun it.

The missing fact is a **specific additional expensive repeated pure operation, with exact same-input/authority/refusal-order equivalence within one invocation**. Existing profiles identify broad Run9 owner boundaries but do not establish such an eligible repetition inside current ending validation or historical semantic/reading validation. A cross-owner cached-success capability would be an architectural change, not the evidenced minimal correction. No further profiling campaign is launched or automatically requested to fill this gap.

Any later concrete candidate must name that pure call and its inputs before coding. Its focused qualification must compare complete outputs, first refusals for multi-fault inputs, both-direction detachment, changed/unavailable issuer/Profile/creation authority, candidate edits between prepare/commit, terminal source-reading and storage refusal/uncertain retry. Only then use the existing cloud Godot/PowerShell integration and matched complete-transition comparison with unchanged deadlines; qualify native readiness, durable lifecycle and clean exit separately. No tests were rerun for this documentation-only result.

The measured checkpoint17 returned about3.004s after the earlier caption deadline. All257 observations were unresponsive; no finish-ending or New Acc anchors exist. Failure autosave16/PLAYING predates return; absent post17 bytes remain absent. Synchronous overlap is established, sole cause and Title-stall explanation are not. Original failures and diagnostic/official separation remain intact.

Internal independent ownership review agrees with this blocked-shortcut disposition; it is not external Coordinator C approval of this new map. External C can review this bounded equivalence reasoning using existing audits, with no repeated artifact census. A stops here under Director6273381902. Runtime, saves, controller, master and integration unchanged; no release or completion claim.
