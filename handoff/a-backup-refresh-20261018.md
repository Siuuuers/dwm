# A — Backup refresh notification correction, 18 October 2026

## Change and owner

BackupApp now skips a deferred projection notification only when this view already adopted a valid projection covering that notification's revision. BackupPresentationPort increments a presentation-only revision for every metadata/capability invalidation, including those coalesced into an already-queued publication. It still publishes to every subscriber.

The view captures the revision before reading and records it only after validation. Changes during/after a read require another refresh. Failed projections do not suppress retry; separate views track their own adoption; older injected ports without the optional getter retain unconditional refresh. Explicit refresh, action preparation and commit still inspect through existing owners. No SaveManager, persisted schema, file revision, restore admission, receipt or history rule changed.

This addresses the duplicate path established in [the phase diagnosis](a-post-save-phase-profile-20261018.md): successful _commit_pending refresh followed by deferred projection_changed refresh. It does not cache restore validation.

## Focused cloud qualification

[Run39124136055](https://github.com/Siuuuers/dwm/actions/runs/39124136055), job117665605713, succeeded with Godot4.6.3 standard GDScript and PowerShell on Windows cloud only.
Source8a431447b3fffa180b4cdd22fdc8f74a40e95d77; tree8aa17066accfc5ae8877780b50007acc16df0aea.
Controller1817a808e390030850d42eba086189ad8676f45f.

| Suite | Tests | XML assertions | Process exit |
| --- | ---: | ---: | ---: |
| Backup presentation | 11 | 3458 | 0 |
| Scene Backup inspection | 2 | 46 | 0 |
| Pause Backup host/custody | 13 | 320 | 0 |
| Total | 26 | 3824 | |

The five new tests cover successful Save/read counts and status with two views, changes during/after reading, failed-read retry and equal-number port replacement, getter-less ports, and every invalidation advancing the real port's revision despite coalesced delivery. Existing suites cover scene admission/cancelled consent, real record revisions, stale source refusal, recovery, parent custody and prepared-token cancellation.

A deliberate baseline used the original BackupApp from318e77ff454e6035d2ac1dbb7ef68885681a9ff4 with the candidate's additive port counter and new tests. The selected regression exited1 with exactly one failing testcase/two read-count assertion failures. It was not a parse failure or an unchanged whole-tree baseline. Candidate then passed all26 cases. Original failure retained.

Original ZIP84945bytes, SHA2564bf76fc2fb43204813056ee0d1dae44194d835a23bad9881bb292f24399cbfe9. All22 retained entries, six source blob pins, exact source/XML census and three exit receipts independently verified. Unit logs report orphans; this is clean process-exit evidence, not a leak-free claim. Scene stdout reports49 assertions while XML records46;3824 is specifically the XML count.

Tracked source is unchanged after testing except the two documented disposable-index gitlink removals. Import also generates untracked UID/image-import sidecars; these are recorded in final-status and not promoted. Scene-view revision adoption was source-reviewed; new mounted-view race tests use configure_backup.

## Publication limits and next work

Keep draft/unmerged; no integration/master change or release. Broad automatically triggered Windows CI is not accepted by this bounded result. B's completed fixture proposal remains queued after the active exported journey. The next export uses the tested runtime and a separate opt-in continuation harness; its outcome is recorded below.

## Exported continuation: previous boundary crossed, later observation failure retained

[Run39124502119](https://github.com/Siuuuers/dwm/actions/runs/39124502119), job117666685695, built a fresh export from63f1e4dbfe649039881d138541abd377a8639778, tree d8da757693c190bb6cde7eafdbeacaf02c7330cd. Its runtime matches the qualified source; the only additional source change is the isolated external PowerShell harness. Controller249f9598c91f5c8f8b32b7d2b1a5a6823226669d; driver blobd2003611a97c99626b72a727a56d0c9d55a72f55.

The harness adds opt-in ContinueAfterQuiet. Default diagnostic behavior still fails intentionally. Opt-in resumes all ordinary Saved/Back/state/ending/normal-exit gates without marking success early. Generic failure capture resumes after continuation. Native CDB/WER dump setup is not enabled in this controller. No timeout increased.

Package artifact12135278742, backup-refresh-package-39124502119-1:
- ZIP99457763bytes, SHA256ef5f3f19980064080a84a28bcae9f97db4feb41934a9f007bc828172394f3431.
- EXE SHA25691724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6.
- PCK SHA256cdf5c0063473c008faceea725f889abf58283c46dec107400f577b2f5b67419b.
- Packaging/headless startup and117 packaged runtime-data hashes passed.
- ProjectDefault renderer (D3D12 Forward+ Microsoft Basic Render Driver), Always accessibility, Dummy audio. Existing phase profiling enabled only in Load.

Observed correction: raw phase records contain one complete nine-locator inspection pass after successful witness Save, rather than the prior two. Save commit4.857508s; subsequent top-level inspection sum19.957882s (nested phases excluded). First responsive quiet native sample21.845184s; final11/40 samples respond. Fresh UIA returns75 descendants/one Saved; immediate native check responds on the original HWND. This demonstrates removed duplicated work and observed recovery in this run, not universal latency or hardware-performance acceptance.

The loader then:
- Captures Saved, invokes actual Back, and displays the full restored Day4 closing caption.
- Completes six restored-field comparisons, same-run/new-branch checks and whole Profile equality after Load/witness Save.
- Invokes the Day4 closing caption once to advance.
- Fails UIA_UNAVAILABLE_OR_TIMEOUT: TEST Day5 opening.

Crucially, the later failure screenshot visibly renders Day5 opening. The later failure tree contains the exact trimmed caption as a visible, enabled Button with InvokePattern, and the separate native probe finds the original HWND responsive. These observations occur after the timeout; they do not establish whether the transition/provider update was late or earlier UIA observations were stale. Preserve the original failure; do not weaken selector requirements or increase timeout as a fix.

Source slot1 remains byte-identical in retained failure evidence. Quiet-before/quiet-after Profile equality holds; after the actual Day5 advance, failure Profile differs only in visited_line_ids and witnessed_caption_variants for the newly observed Day5 line. That later difference must not be described as failed Load preservation or whole-run unchanged Profile.

Capability/Create pass with normal exit0. Load remains ok=false, forced cleanup-1. Ending, Gallery completion and normal loader shutdown are not reached. This is bounded post-Save/Back evidence, not complete exported-journey acceptance.

Original evidence ZIP894954bytes, SHA256c3d9e119c986c1ca54b47705cfced62232d6b3b0c96c928a21d511706ecc03e7; all149 retained entries, inner mode manifests, source pins and phase sequence independently verified. Actual restored/failure images reviewed independently.

## Concrete next action

Keep this runtime correction. Reuse artifact12135278742 if still available; no rebuild is needed for harness-only work. At the Day4→Day5 boundary, retain bounded polling diagnostics for candidate caption name, enabled state, bounds and InvokePattern together with native responsiveness. Separate observed caption from actionable caption diagnostically while preserving the existing acceptance gate. This will distinguish delayed transition/readiness from stale observation before another correction.

Do not repeat completed unit/custody campaigns or prior snapshot audits merely to restate them. Once the observation boundary is resolved, finish ending/Gallery/normal-exit checks, then B's existing scoped fixture corrections and the established framework/author-guide handoff.


## Coordinator A continuation — Day5 readiness observed, 18 October 2026

### Driver ancestry reconciliation

The ordinary product head7b7a689 and tested continuation63f1e4d are siblings, both parented by8a431447. The former did not remove the latter's diagnostics. The intentionally stopping quiet experiment remains separate from the normal driver, as required by [the quiet diagnostic handoff](a-post-save-quiet-uia-20261018.md). Earlier conversational wording implying a dropped-driver regression is corrected here. No ordinary driver replacement is justified by that comparison.

The new isolated diagnostic candidate2195d5dfc399ef3d40db905d8ec89e48f6ea7c90, tree1cdd5dafa2a004ec52c1cc264559516404bccf80, composes the retained continuation harness with one-shot Day5 telemetry. It records actual short-circuit acceptance decisions plus diagnostic candidate fields. Diagnostic-only stale-node reads are caught; exact-name, visible, enabled, InvokePattern and uniqueness requirements remain. No game runtime or persisted data definition changed. This candidate is not the ordinary PR36 driver.

### New cloud evidence

[Run39127084942](https://github.com/Siuuuers/dwm/actions/runs/39127084942), job117674367387, controllerb00319a5bcfb85c996648f479c9310c4b5fa5623, completed **failure** at `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Day7 opening.` The original failure remains a failure.

The run reused artifact12135278742 without rebuilding: package source63f1e4dbfe649039881d138541abd377a8639778, inner ZIP SHA256ef5f3f19980064080a84a28bcae9f97db4feb41934a9f007bc828172394f3431. Candidate commit/tree, driver parse, package receipt/hash and per-mode package identity were checked. Standard Godot4.6.3 Windows export, ProjectDefault renderer, Always accessibility and Dummy audio remain the scope; existing Save/Load timing hooks were enabled for Load. All PowerShell/game execution was cloud-only.

Capability and Create passed with normal exits0. Create made the Day4 save through ordinary UI. Load reached witness Save, Back, restored Day4, Day5 opening/closing and Day6 opening/closing; it then timed out waiting for Day7. Its forced cleanup exit-1 is not a native crash or clean shutdown. Ending/Gallery/normal loader exit remain unqualified. No new GUT census or broad-CI completion claim.

At the first Day5 wait, with the original30-second deadline:

| Elapsed from wait start | Observation |
| --- | --- |
|0.001s native sample begins|Original Engine HWND524740/PID6016 does not answer the50ms native probe; hung=false.|
|15.056s|Actions begins only after the preceding Window call; enumeration returns0 descendants in about0.0005s.|
|15.158s native sample begins|Same game window hung/unresponsive; foreground is a distinct Ghost window.|
|29.164s|Next Actions call again returns0 descendants in about0.0005s.|
|29.273s native sample begins|Original game window responds and is foreground; hung=false.|
|29.409s wait ends|One visible/enabled exact-name Button with InvokePattern passes; the separate Text node is correctly rejected for lacking InvokePattern.|

Thus this run observed Day5 actionable within the deadline. It does not prove a deterministic fix or establish that telemetry caused recovery. The long intervals precede Actions, within the Window/check-live/native/UIA root-acquisition path; they are **not**15-second FindAll durations. We did not time its individual FromHandle/Current.ProcessId subcalls. Additional diagnostic reads/native probes/log writes affect timing and do not qualify ordinary-play performance.

The later Day7 failure probe still reports the original HWND hung/unresponsive despite exposing40 descendants including Day7. The failure screenshot visibly shows the complete Day7 opening. Provider text/pixels alone therefore do not establish timely native readiness or successful interaction. Independent review confirmed Day5 opening, Day6 closing and Day7 failure captures without redoing the earlier snapshot audit.

Original999043-byte evidence archive SHA25671e6adb85945fc705cfb7e7b6b7f0834e2e7ffa43c4c507c663e34d125fb6b30 and all164 outer manifest members plus per-mode manifests were verified, including retained driver blob9e78a5ab72c137e73749c10b77e9f7777326dd6c. A separate read-only review independently verified the archive/manifest and interpretation. [Archive, verifier and recorded telemetry](../evidence/phase_2r/day5_readiness_20261018/) preserve the actual failed run. This adds bounded readiness evidence, not new saved-state or recovery qualification.

### Next owned action

A retains driver/controller/dispatch ownership. Use the same retained corrected package for a matched boundary experiment: while the original window is unresponsive, take bounded native-only samples instead of repeatedly calling Window/UIA. Once responsive, apply the same fresh actionable-caption gate within the same30-second deadline. Record process CPU delta and bracket Window acquisition separately if needed. This is a discriminator for observation-related contention versus long application work, not permission to bypass readiness, lengthen the timeout or call provider presence a pass. If the stall remains, profile the existing scene-event/target-admission owners before selecting a runtime change; the existing Save/Load phase hooks do not cover these forward day-transition phases.

Retain the observed Save latency limitation and accepted Backup correction. After this boundary is resolved, finish ending/Gallery/normal exit, apply B's two existing bounded fixture corrections with negative/cache-teardown checks, and consolidate the existing author guide. No extra inventory, retired-feature restoration, merge, master/integration change or release.

## Coordinator A continuation — native-only discriminator, 18 October 2026

[Run39128530440](https://github.com/Siuuuers/dwm/actions/runs/39128530440), job117678690818, controllerbf53dcf82ba290d220756767563961ca5d4b17fc, again failed at `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Day7 opening.` Isolated candidateb59b9d548f352895ac89b6aa55b80822358f8b69/tree82cafaf91f939be1545d7cd61c8770e687273e97 reused corrected artifact12135278742 and the same package hash. No runtime rebuild, product driver replacement or timeout increase occurred.

The driver withholds Window/UIA queries while bounded native probes cannot obtain a response from the original game window. Once responsive it retains the fresh exact-name, visible, enabled, InvokePattern and unique-match gate. It also rechecks the original deadline after blocking Window and Find operations and before returning a match. Four focused tests of the actual Wait-One definition passed in Windows cloud: late root refused before enumeration, late match refused, timely unique match accepted, and ambiguous match refused. These mocked boundaries qualify the deadline logic, not the game.

| Initial caption wait | Elapsed | Process CPU delta | UIA acquisition |
| --- | ---: | ---: | --- |
| Day5 opening | 29.301s | 29.672s | Window took45.94ms, after29.149s of the wait |
| Day6 opening | 27.630s | 27.891s | Window took17.43ms, after27.502s of the wait |
| Day7 opening | 30.011s, failed | 30.000s | None;261 native samples, zero responsive |

Repeated UIA queries during the wait are not necessary for this stall. CPU is aggregate process time; this does not identify a thread, function, or exclusively CPU-bound cause. Native probes and diagnostics still affect timing. The failure screenshot visibly contains the Day7 opening caption, but pixels do not qualify readiness. Capability and Create passed with normal exit0; Load required forced cleanup-1. Ending/Gallery/normal loader exit remain unqualified, and the existing Save latency limitation remains.

Original1017512-byte ZIP SHA2566a88d9bd84a0cc6cab2c79b6696964d1f42057260bb20df34e0c3e9d1076a0f0, all166 outer manifest members, inner mode manifests, exact source pins and deadline results verified. Separate read-only review independently checked archive hashes and the native-only/CPU interpretation. [Original evidence, verifier and full telemetry](../evidence/phase_2r/native_readiness_20261018/) preserve this failed run. No prior snapshot or custody audit was repeated.

### Next owned action after the matched failure

Per Director issuecomment-6250026410, stop equivalent polling experiments and profile forward scene-event/target-admission owners. A owns an isolated opt-in timing candidate, fresh cloud export and dispatch; this runtime instrumentation cannot use the prior binary. Measure source checkpoint, admission preparation, target checkpoint, runtime installation and reading adoption separately, with nested totals identified. Preserve both durable checkpoint calls, return values and persisted data. No optimization is selected until measured evidence identifies the cost. B's scoped fixture work remains queued after the exported boundary; C reviews evidence. Product runtime and ordinary driver remain unchanged by this evidence update.

## Coordinator A continuation — forward owner profile, 18 October 2026

Observable outcome: identify which existing forward-transition owner consumes the native-unresponsive interval, without changing checkpoint, history or recovery behavior. The matched discriminator above warranted profiling; no further equivalent polling run was made.

Isolated diagnostic193691f9dfa06aed698274cd1ce7346cee77857a/treef613f1299a5e1e9fa274007f1df4d8acaab5fb61 adds opt-in wrappers/phases around GameState event acceptance, marker advance, target admission/commit and DialogicBridge reading adoption. It reuses SaveManager's existing timing helpers, preserves both checkpoint calls and return values, and does not change persisted data. Disabled/detached execution uses no profiling clock or SaveManager lookup. This instrumentation and the continuation driver remain outside the ordinary product tree.

[Run39129421744](https://github.com/Siuuuers/dwm/actions/runs/39129421744), job117681340781, controller59fa07283ef6c1f90aff39031e0540194c79a29a, passed cloud parsing/import, fresh standard Godot4.6.3 export, four deadline tests, Capability and Create. Load reached Day7 opening/closing and then **failed** at `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.` It required forced cleanup-1. This is not a complete exported-journey pass or a performance improvement claim across different cloud runs.

| Forward transition | Source checkpoint commit | Target checkpoint commit | Whole forward operation | Native caption wait |
| --- | ---: | ---: | ---: | ---: |
| Day4 to Day5 | 12.486s | 8.503s | 22.374s | 22.409s |
| Day5 to Day6 | 9.205s | 10.077s | 20.929s | 20.952s |
| Day6 to Day7 | 10.723s | 11.191s | 23.906s | 24.042s |

The two checkpoint calls account for about92–94% of these ordinary transition totals. Target bridge-install calls took67–83ms; later bridge-adoption scopes took1.7–2.3ms. This locates the dominant owner boundary, not the internal validation/hash/serialization/storage cause. The synchronous install return may precede pending native adoption. Profile scopes are nested/inclusive and must not be summed across levels; signal duration covers synchronous subscribers only. Use `game.stdout.log` as the primary stream: `game.log` contains a buffered partial duplicate, not extra operations.

The ending branch differs: source checkpoint11.961s sits inside event total12.841s; ending admission16.109s is entirely unphased because it returns through the existing early ending path. Whole forward total29.791s. Of260 native samples one became responsive; Window completed29.873s, then enumeration completed29.938s with zero matching actions. The deadline expired30.005s. The failure capture visibly renders the ending later, but does not establish in-budget acceptance. Gallery and normal loader exit remain unqualified. Retain the Save latency limitation.

Fresh diagnostic package artifact12137690574 (`forward-profile-package-39129421744-1`) is retained from this run, expires25October. Inner ZIP99454371bytes/SHA2564291ba8bcc07a1077a4cea4f5b99f20c5352c5dbe15885a1523dd2b77922f237; source193691f9dfa06aed698274cd1ce7346cee77857a. EXE SHA25691724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6; PCK SHA25651bdc630252d2bffb3994f3f92b1598b12feae3b695451824eb25dfe68c5ae9c. This is instrumented diagnostic data, not the earlier corrected product binary.

Original evidence ZIP2003387bytes/SHA256d9707b161c0a69921eda4a9f1f36d4c8b1d5828dde15d11855bcce30155177f1,177 outer manifest members, inner mode manifests and both instrumented source blob pins verified. Independent read-only review confirmed hashes, transition mapping, ending native timing and failure screenshot. [Archive, replayable verifier and full telemetry](../evidence/phase_2r/forward_profile_20261018/) retain the actual failed result. The verifier accepts either the original job log or retained ZIP.

### Next measurement, before runtime surgery

Use the existing `DWM_CHECKPOINT_PROFILE=1` hooks in SaveManagerCheckpointPort.prepare/commit to separate measured checkpoint costs. A can reuse artifact12137690574 for this harness-only change. The exported driver deliberately removes inherited DWM_* environment variables, so enable the flag explicitly in the isolated child's environment; setting only workflow env will not work. Keep original deadlines, action gates and forced-cleanup failure semantics. Retain source SaveManagerCheckpointPort, SaveManagerNarrativeCheckpointPort and their existing profile definitions with the evidence. No additional profiler layer is needed for those lower checkpoint phases.

Owner chain: scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd commit_scene_event → _commit_scene_event_autosave → scripts/application/run/SaveManagerCheckpointPort.gd capture/prepare/commit → retained journal/storage. Existing lower hook emits save_checkpoint_prepare/save_checkpoint with diagnostics_version2, including snapshot build, document validation/serialization, atomic write/reread and journal phases. The current run did not enable that separate flag. The ending's16.109s admission remains a distinct unresolved branch and must not be labeled target_checkpoint_commit by inference.

Choose a minimal runtime correction only after this decomposition, then compare the complete matched operation and run relevant negative/retry/recovery checks. Keep B's already-scoped fixtures and ending/Gallery/normal-exit acceptance outstanding. No new architecture choice requires user input at this point; no merge, release or master/integration change.
