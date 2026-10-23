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

## Coordinator A continuation — lower checkpoint phases, 18 October 2026

Director6250380703 and C6250326930 confirmed the next scope. [Run39131596323](https://github.com/Siuuuers/dwm/actions/runs/39131596323), job117687721524, controllerb93ccbb73eed31dc7770298a27dd26642b52cb01, reused instrumented artifact12137690574 without rebuilding. Isolated candidateafbaeb0994bba9070df2c18e17cd8d474b666b09/tree35549a89ffa36d40a951035df0a7cc915947b112 adds only explicit child DWM_CHECKPOINT_PROFILE=1 and its receipt field to the prior profiling driver. Same package hash, original action deadlines and caption gates. Capability/Create and four deadline cases pass; Load **fails at Day5 opening**, forced cleanup-1. Earlier Day7 progress is not deterministic acceptance.

Primary stream is only exported-load/game.stdout.log (87 profile records total). The two completed checkpoint calls inside the Day4→Day5 operation show:

| Scope | Source checkpoint10 | Target checkpoint11 |
| --- | ---: | ---: |
| Lower prepare total | 8.778s | 5.162s |
| Lower commit total | 7.841s | 6.185s |
| Enclosing narrative checkpoint call | 16.758s | 11.651s |
| Prepare document build | 3.924s | 4.205s |
| Prepare storage preimage capture/validation | 3.951s | 0.002s |
| Commit outgoing schema | 3.904s | 0.961s, refused optimization |
| Commit write_atomic | 0.006s | 4.261s, includes4.251s full text validation |
| Commit retained-history proof work | 3.009s | 0.001s |

Source has0/4 retained-document proof hits and no splice; target has4/4 hits and a successful splice. Target outgoing_validation_ok=false forces strict text validation inside storage. Top-level and nested timers are not additive: text_validator_us_since_prepare is cumulative/overlapping. `document_schema_metadata_us` contains scene family/history validation, not merely saved-time formatting; its3.009/3.226s must not be described as trivial metadata overhead. Whole forward operation30.262s. No new ending-admission measurements in this failed run.

Concrete defect independently source-confirmed: SaveManagerCheckpointPort._normalize_outgoing_document empties recovery_journal on the splice path. SaveDocumentSchema._validate_document's Save9 proof path then requires the caller journal and retained proofs to have equal counts and values. Empty history versus four proofs necessarily returns `scene journal proof count mismatch` after validating the current snapshot. The actual spliced bytes still include the retained history, so full parsing accepts them. This explains the measured warm fallback without implying corrupt saved bytes.

Smallest candidate correction: preserve ordinary full normalization for Save9, keeping the empty-history shortcut for legacy families. No proof/validation rule is removed. In-flight isolated candidate75aecb404cba8c2531cb5b944fd8ae75f2990347/treeadffc2682d6ecf5fb1b6d35ee7595672123c3b74 also adds three tests to the existing owner-backed scene-anchor suite: positive warm proof/full-validation byte equivalence and detachment, missing/substituted proof refusal, and unchanged legacy normalization. Controller75b9fd18e8090c805f5050916e59b37d8160378a requires the original code to fail the selected regression for the exact count mismatch, then runs candidate scene-anchor/checkpoint-port suites and same-host baseline/candidate exported journeys. Baseline failure is retained, never converted to candidate success. Fixed-order comparison supports bounded evidence only. **At this handoff checkpoint the correction is not yet qualified or promoted.**

Original1041039-byte ZIP SHA256839fefe9232367290fd3ef4ae12f9720e4ac24223d4843ac20a61f10e6548b7a;154 outer members and22/57/45 per-mode manifest members independently verified, along with both retained checkpoint-port sources. [Lower-phase evidence and replayable verifier](../evidence/phase_2r/checkpoint_profile_20261018/) preserve the original failed run. Save/transition latency, ending/Gallery/normal exit and B's bounded fixtures remain open.

## Coordinator A continuation — Save9 splice correction qualified within scope

[Run39132455733](https://github.com/Siuuuers/dwm/actions/runs/39132455733), job117690225862, completed the focused qualification and same-host exported comparison. Overall workflow remains **failed at the candidate ending deadline**. The earlier in-flight status above is superseded by this section.

Promote only scripts/application/run/SaveManagerCheckpointPort.gd's Save9 normalization predicate/comment correction and the three additive tests in tests/integration/test_scene_saved_event_anchor.gd. Keep the diagnostic driver, deadline experiment and GameState/DialogicBridge timing wrappers isolated. No persisted schema, checkpoint count, caller/proof equality check, serializer, atomic write, reread, rollback or proof-retention gate changed. Genuine caller/proof mismatch still declines the optimization and falls back to strict validation of the actual spliced bytes.

### Focused qualification

The selected new regression ran with the original checkpoint port substituted byte-for-byte, failed with exactly one assertion for `scene journal proof count mismatch`, then the candidate bytes were restored in finally. The failure was not a parse/setup error. Candidate tests ran against the restored correction in isolated Windows cloud processes.

| Suite | Executed tests | XML testcase assertions | Exit |
| --- | ---: | ---: | ---: |
| Expected original-code regression | 1 | 6, one failure | 1, expected |
| Scene saved-event anchor, including3 new tests | 7 | 89 | 0 |
| Checkpoint port, including existing mutation/write/reread/history-proof checks | 42 | 1268 | 0 |
| Candidate total | 49 | 1357 | |

Four separate PowerShell deadline checks also passed. The new scene tests use the existing owner-backed fixture: valid complete Save9 history, exact canonical equivalence with full validation, output detachment, missing/substituted proof refusal and unchanged legacy/cold normalization. They do not independently exercise a deliberately mutated Save9 caller through a complete physical write; legacy full-port tests cover that fallback structure and the exported journey covers actual unmodified Save9 writes. No leak-free or broad-CI completion claim.

### Same-host comparison and limits

Both builds used the same external driver, standard4.6.3 Windows renderer/accessibility/audio settings, profiling flags and original30s caption deadline, with separate user roots. Baseline source193691f9 used artifact12137690574; candidate75aecb404 used a freshly exported package. Baseline ran first: this is one bounded fixed-order comparison, not general performance statistics.

| Measured first Day4→Day5 operation | Baseline | Correction |
| --- | ---: | ---: |
| Whole forward operation | 30.530s | 28.701s |
| Target narrative checkpoint call | 11.872s | 10.410s |
| Target lower commit | 6.266s | 5.075s |
| Target outgoing schema work | 0.979s, optimization refused | 4.102s, accepted |
| Target atomic-write phase, including validator | 4.234s | 0.007s |
| Target fallback text-validator calls | 1 | 0 |

The whole-operation difference is1.830s (~6.0%). Do not advertise the4.227s write-phase difference as net savings:3.123s moves into successful outgoing-schema work. Candidate warm checkpoints11–17 all report outgoing_validation_ok=true with zero fallback text-validator calls. The cold source checkpoint still performs its original validation.

Baseline Load failed at Day5. Candidate Load reached Day5, Day6 and full Day7 opening/closing, then failed waiting for the ending; both required forced cleanup-1. Capability/Create passed with normal exits0 for both packages. Candidate ordinary forward totals after the first transition were25.581s and29.249s. Ending forward work took36.363s, including19.439s in its distinct admission branch. Lower checkpoint17 prepare9.245s/commit9.278s occur in that ending sequence; do not rename the whole admission as the ordinary target-commit scope. Actual Day7 closing and later ending-failure captures were independently viewed. The late visible ending does not qualify in-budget action readiness, durable Gallery award, title return or normal loader exit.

Candidate diagnostic package artifact12138174416 (`forward-profile-package-39132455733-1`), expires25October, source75aecb404cba8c2531cb5b944fd8ae75f2990347/treeadffc2682d6ecf5fb1b6d35ee7595672123c3b74. Inner ZIP99454506bytes/SHA2566b59c85c9b05e4de97c14b14267b4b80354d683727be5f65892ce8736fca017f. Original evidence ZIP3017358bytes/SHA256c252c20ac31060426673326155da93def6a4298cb570d8e1edc7445bb752f004;329 outer members and272 inner mode members independently verified. Source pins: corrected port9306b21bd1e92e1c81c25a709c89470b4e2d8179; scene tests0c104ca0edb62f07baa5092af0f487e335e48fd3. [Original comparison, XML, screenshots and replayable verifier](../evidence/phase_2r/scene_splice_fix_20261018/) retain both failed loaders without rewriting their outcomes.

### Next owned work

Keep this demonstrated correction. Remaining warm preparation/outgoing-schema work is still expensive: checkpoint17 document build6.846s includes4.424s in the combined scene-family/history metadata phase, while outgoing schema is6.913s. Inspect the existing Run9/history-validation owners and proof obligations before selecting another change; these timings do not authorize bypassing historical validation or introducing a cache. The source cold path and observed Backup Save latency also remain limitations. Reuse existing profiles and the retained package for any harness-only follow-up; do not repeat equivalent UIA polling.

A retains runtime/controller/dispatch ownership, C reviews new evidence/proposals, and B's two scoped fixtures remain queued behind this exported boundary. Ending/Gallery/normal loader exit and relevant integration qualification remain open. No merge, release, master/integration update, new feature or architecture decision was made.

## Coordinator A continuation — proof-normalization experiment rejected

Continued from d9e5720fdc421ce1faacef7fdf4b4ba2c3c05d35 after checking PR30/36 decisions and unchanged master0c8b2384415d71bd3de4ff7408640bbf60b63740. Observable target: reduce the existing Save9 proof-comparison work without changing accepted bytes, refusal, history validation, detachment or persistence. No architecture question was needed.

The direct-equality shortcut was discarded during source review because mixed numeric conversion can affect equivalence. Instead, isolated candidate3ef4639194f9aed2e892d792cd76134e209364cc/treeac0135ef11730c66db167d264dc719f86d5afe94 fused the existing text and integral-float normalization walks only in _scene_proof_error, using the existing copy-on-change normalizer. It retained exact finite/floor/int conversion, caller/proof comparison, full _scene_journal_error and document composition. Two tests added only to the isolated candidate compare the original double-walk reference over typed containers, StringName keys/values, numeric boundaries, mismatches and nonmutation; matching malformed history still fails full outgoing validation. Independent source review finished before dispatch.

**Decision: do not promote this runtime change or its experimental test additions.** [Cloud run39135371406](https://github.com/Siuuuers/dwm/actions/runs/39135371406), job117698694622, controller65e2f0adf3197d56e3bb6f9155367a76b2002d3c, demonstrates equivalent tested behavior but no meaningful complete-operation improvement. Keep the previously qualified Save9 splice correction from d9e5720. This update contains evidence and this handoff only.

### Qualification and matched comparison

Godot4.6.3 standard and PowerShell ran only on Windows cloud. The expanded scene suite first ran with the original schema substituted, then with the candidate schema restored byte-for-byte. Baseline9 tests/169 XML testcase assertions passed. Candidate scene9/169, checkpoint-port42/1268 and document-schema21/272 passed: **72 candidate tests/1709 assertions**, three candidate exits0 and baseline exit0. Four deadline harness cases also passed. No broad-CI or leak-free claim.

The same host and external driver ran retained baseline artifact12138174416/source75aecb404 first, then the fresh candidate, with separate user roots, identical flags and original30s caption/480s journey limits. One fixed-order comparison is bounded evidence, not statistical proof of equivalence or general performance.

| Complete measured operation | Baseline | Candidate |
| --- | ---: | ---: |
| Day4 to Day5 forward | 29.375865s | 29.420472s |
| Next ordinary forward | 26.304563s | 26.133161s |
| Final ordinary forward | 29.733051s | 29.440518s |
| Ending forward | 36.802421s | 36.838025s |
| Ending admission, nested within ending forward | 19.643982s | 19.750064s |

Checkpoint17 build metadata remains4.444904s versus4.417169s; outgoing proven-journal composition remains4.618180s versus4.664001s. These inclusive phases still combine proof binding with complete historical Run9 validation. Do not add them to their enclosing totals or claim the removed walk was the dominant cost. Warm checkpoints11–17 retain outgoing validation success and zero fallback text-validator calls in both builds. Cold checkpoint10 still follows its original validation path.

Both Capability/Create modes pass with normal exits0. Both Load modes reach Day7 and then fail `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.`, with forced cleanup/exit-1; elapsed281.790214s baseline and279.790804s candidate are not successful journey durations. Actual candidate Day7-closing and failure PNGs were reviewed independently: full Day7 captions and later full ending caption are visible. Late pixels do not establish ending readiness, durable Gallery award, title return or normal loader exit. The final three-exit/source-cleanliness acceptance step was skipped after Load failed, not passed.

### Retained evidence and next boundary

[Original evidence, verification report and replayable verifier](../evidence/phase_2r/proof_normalization_20261018/) contain the unchanged4072258-byte ZIP, SHA256d697d91450e15124f5bfa3104b2baef99434aa99d4edfd620133d2159410cc08. Independently verified356 outer manifest entries plus the manifest itself, and296 inner mode manifest entries. Primary timing stream is each Load's game.stdout.log only. Candidate schema blob3e34199514319b5bc464836f78007c465f5aebc8; test blobc3fc877d77f874e006107c39f0543c95d602af1a. Candidate package artifact12139163286, expires25October, inner ZIP99454641bytes/SHA2567f8cac35a74a0f2f1be6846c15b4aae226bd8514a81ee514af14a026d64bf212, is **experimental and rejected for promotion**. Baseline artifact12138174416 remains the retained package corresponding to the qualified runtime.

Next useful investigation: distinguish proof binding from full _scene_journal_error/Run9 validation within the existing schema profile dictionaries and timing helper, then identify the expensive validation owner before another mutation. No new profiler framework/cache/manager, history-validation bypass, timeout inflation or equivalent UIA polling campaign. The current combined timings do not identify an individual historical validation subcall. The source cold path and observed Backup Save latency remain limitations.

A retains controller/runtime/dispatch ownership. Independent internal review agreed with rejecting the optimization; external C review has not been claimed. Ending/Gallery/normal exit, B's two bounded fixture corrections, relevant integration triage and the existing inventory/author-guide handoff remain open. No merge, release, master/integration update or new feature.


## Coordinator A continuation — proof versus complete journal attribution

Following Director6251298922, isolated diagnostic source `de5daf8abdd0b4c6c89ab66c9d044dfe8301c72f`, tree `9642c21e8d727015b639c96536fe333e31f3a2eb`, adds ten opt-in timing lines to SaveDocumentSchema and one owner-backed equivalence test. Removing those ten lines reproduces the retained schema byte-for-byte. Existing forward timing/driver/deadline diagnostic files are reused unchanged from75aecb404. No rejected normalization optimization or new cache is included. Source review preceded cloud dispatch.

[Run39138156844](https://github.com/Siuuuers/dwm/actions/runs/39138156844), job117706838606, controller173144984778d3788dbdfab2728b100e19d2a60d, ran Godot4.6.3 standard and PowerShell only on Windows cloud. Import, **8 scene tests /133 XML assertions**, four separate deadline cases, fresh export, Capability and Create passed. Both successful exported modes exited0. Load reached Day7 but **failed** the ending-caption deadline and was forcibly cleaned up(exit-1). No whole-game, speedup, ending/Gallery or normal-loader-exit acceptance.

### Measured attribution

Primary stream: only exported-load/game.stdout.log. Seven warm checkpoints11–17 carry both proof and complete history timings:

| Nested phase | Proof binding | Complete scene-journal validation | Journal share of inclusive parent, summed |
| --- | ---: | ---: | ---: |
| Document build metadata | 8.103–10.572ms | 2.031245–2.772526s | 99.605% |
| Outgoing proven-journal composition | 8.381–11.287ms | 2.009854–2.810937s | 99.578% |

Parent tick semantics remain unchanged. These nested costs must not be added to their inclusive parents or checkpoint/forward totals. Complete ordinary forward operations are18.359026s,16.493696s,19.015039s; ending forward23.456110s includes12.369270s ending admission. This different-run timing is **not** a matched performance improvement: no behavior optimization was made. Warm outgoing validation remains successful with zero fallback text-validator calls.

The result attributes the dominant combined cost to `_scene_journal_error`, which revalidates retained Run9 bundles and checks their family/registration/order. It does not yet isolate receipt authentication, Profile references, frozen-frame derivation, reading validation, copying or hashing within Run9 and its live semantic owner. Repeating proof-normalization experiments is unsupported.

### Ending boundary remains distinct

The ending wait lasts30.0117116s. Late in-budget native probes report the original game window responding;33 root-acquisition attempts are recorded, and final action enumeration finishes29.9932742s with zero matches. The later failure screenshot visibly shows the complete ending caption and six bottom controls, but failure.uia.json contains23 nodes: background Continue/Backup/Settings/Return to Title and audio nodes, no ending caption/rail. This is a concrete provider-tree/presentation discrepancy worth discriminating; do not infer a particular caching or viewport cause, or equate23.456s instrumented forward work with full UI readiness. The original failure is unchanged.

### Retained evidence and next ownership

[Original archive, receipt, verifier and complete parsed timings](../evidence/phase_2r/scene_validation_attribution_20261018/) retain2140195 bytes, SHA256 b1f9c9ce1be27d78b8e7ca6b73947058943e9bfb61e1118858702e336b70edd3. Verified186 outer members,148 inner manifest members, exact source pins and the eight source-derived test names. New diagnostic package artifact12139978428 expires25October; inner package SHA256 b8fbcdaf06f3c71fd48e38b32262431228bda4bb986c37f0bdbf4cc1a6603cba. Reuse only for matching harness-only diagnostics; another source change requires another export.

Next: use existing timing helpers to split complete Run9 validation at concrete owner boundaries before selecting a runtime correction. In parallel, read-only inspection can identify the smallest observation separating the ending's missing UIA subtree from native responsiveness. Keep original deadlines, exact actionable gates, both durable checkpoints, validation/refusal/history/detachment guarantees. A remains sole driver/runtime/controller/dispatch owner; independent review only, no duplicate run. B's scoped fixtures remain queued; ending/Gallery/normal exit and relevant integration work remain open. This product-branch publication retains evidence/handoff only; diagnostic runtime and test stay isolated. Master/integration unchanged; draft/unmerged; no release.

Read-only ending-source review identifies the23 nodes as persistent PauseSurface plus audio nodes. EndingScene and its Dialogic caption layout share the same native root; no separate Window/SubViewport was found. GalleryScene and WitnessedSourceCanvas already document hidden-container sibling omission in Godot4.6, but this does not prove the ending cause. Smallest harness discriminator: after preserving the unchanged failed30-second result, collect a bounded RawViewWalker hierarchy (parent/depth/runtime ID/name/offscreen) on the same verified HWND and compare with existing FindAll descendants. Do not change caption acceptance, timeout, or lifecycle ownership to make the diagnostic pass.


## 18 October continuation — Run9 owner costs and post-failure hierarchy

Observable outcome: attribute full historical Run9 validation to concrete existing owners, and compare RawViewWalker with unfiltered FindAll on the original HWND after preserving the unchanged failed gate. This is diagnostic evidence, not a runtime optimization or exported-journey acceptance.

Source `b1ec16613d3450f48e49a50ef739df517360c3d8`, tree `caf3e2cb5f8c8e570b00d8326fa4703415044645`; controller `deb35674b05af8a091166709940ef417c8851df2`. [Cloud run39142114567](https://github.com/Siuuuers/dwm/actions/runs/39142114567), job117718486123, used Godot4.6.3 standard GDScript and cloud PowerShell only. Diagnostic source remains isolated on codex/a-run9-owner-profile-20261018; this product update retains evidence only.

### Verification and limits

Import/parser checks, four deadline cases, and eight scene tests / 135 XML assertions passed, with zero test failures/skips. Fresh export succeeded. Capability and Create exited0 (28.2104521s and116.0578671s). Load failed at **TEST Day7 opening.**, after239.2106352s overall, forced cleanup/exit-1. It never reached ending. The unchanged caption gate ended at30.0105372s; complete forward durations were29.603874s,26.329651s,30.370814s. Different-run observations do not establish a speedup.

Original archive1318178bytes, SHA256 `cf5848846011e6f80cabbb8702374cf754e38e7cc7efc1c9aa60849b7c7763a9`;180 outer and141 inner manifest entries verified with source pins. Artifact12142351379 expires25 October; retained archive avoids depending on expiry. Inner package SHA256 `dea30f936b07374a6e99a53820dc05a4ee78536ea27ce9206c7097f545d552b5`. Independent review rehashed all141 inner members, parsed XML and primary Load stdout directly, and confirmed the timing census and hierarchy chronology.

### Concrete timing owners

Twelve distinct primary Load checkpoint records (six prepare, six commit) contain42.847325s summed disjoint Run9 phase time across historical entries. These percentages describe that measured validation work, not whole-transition time.

| Disjoint phase | Seconds | Share |
| --- | ---: | ---: |
| Semantic owner | 28.726061 | 67.043% |
| Outer receipt contract | 11.200384 | 26.140% |
| Reading | 1.537864 | 3.589% |
| Remaining phases combined | 1.383016 | 3.228% |

Inside semantic-owner time: frozen context11.584263s (40.327% of parent), receipt authentication11.188358s (38.948%), reading anchors5.556247s (19.342%). **Nested values must not be added to the parent total.** Copying/hashing and physical-reference checks are smaller in this sample. Diagnostic timers preserve existing validation order, refusal behavior, copies and default call paths; failed stages can return before their timer is accumulated, so these are not a complete failed-stage census.

### Failure and hierarchy chronology

The original Day7 failure was persisted at15:57:34.3518166Z after wait-end15:57:34.3436809Z, before diagnostics/cleanup. All261 native wait samples reported nonresponsive. Original HWND1049056/PID4908 was later responsive/not hung at15:57:35.7468Z. Executable, process-start, PID and original HWND identity checks recorded no mismatch.

Raw traversal ran15:57:36.0177–36.8773Z (0.85744s), yielding41 nodes including root without errors/truncation. Day7 caption hierarchy was root → pane → button → text. Subsequent FindAll at15:57:36.8813–36.9396Z returned the same40 descendants, with identical runtime IDs/names/types. The isolated probe completed in3.261055s under its unchanged15s hard bound; timeout cleanup was not exercised. The screenshot also shows Day7 opening.

These sequential post-deadline observations establish later recovery and agreement between enumeration methods. They do not establish caption readiness within the original deadline, an ending provider diagnosis, Gallery completion or clean exit. Previous ending-subtree evidence remains a separate unresolved observation.

### Next bounded work

Audit receipt authentication at RunSnapshotSchema, GameState semantic validation and FrozenRunContext for exact input/authority equivalence, including the scene-creation owner versus actual SaveManager. Only consider sharing authenticated work within a single validation call after proving refusal ordering, detached-input guarantees and all independent caller obligations. Do not remove checks merely because their names repeat. Correlate Day6→Day7 checkpoint work with the original polling deadline. No new cache/manager, timeout expansion or guessed UI correction follows from this run.

Preserve both durable checkpoints and save/recovery/history contracts. Product remains draft/unmerged; master and integration unchanged. Ending/Gallery/normal exit and queued fixture work remain open.


## Receipt-equivalence audit completed — 18 October 2026 UTC

Followed Director6252085070; independent read-only source review agrees. [Detailed authority/refusal audit](a-receipt-equivalence-audit-20261018.md) maps Run, GameState and Frozen input copies, separate owner bindings, committed-creation proof reads and terminal-path obligations.

Decision: retain all three ordinary authentication calls. Production wiring aligns them, but API contracts do not guarantee identical owners or stable owner state; a caller-provided validated ledger/Boolean would not preserve the proof boundary. No runtime candidate or new test run was produced, and no performance gain is claimed.

Next A measurement: split the existing SceneEventContract receipt owner into bundle/shape, committed initial admission, other admissions, event reconstruction/authentication and final chain passes. Time SaveManager creation capture within initial-admission work if needed; do not double-count it. This seeks a smaller internal optimization while preserving the public validation boundaries. Repeated pure bundle reconstruction is a source-level hypothesis, not yet a measured cause.

Keep the existing post-failure hierarchy discriminator for the next run that reaches ending. Latest exported result still fails at Day7. Ending/Gallery/normal exit, B's scoped fixtures and relevant integration qualification remain open. Product is draft/unmerged; no master/integration change.


## New-session checkpoint — 19 October 2026 Hong Kong time

**Start with [a-resume-20261019.md](a-resume-20261019.md).** It records the completed receipt-internal diagnostic39145021649, exact source/controller/evidence hashes,8 tests/173 assertions, failed ending gate and independently reviewed provider hierarchy. Event reconstruction/authentication/group work measured56.2984% of the outer receipt-call phases; no optimization or matched speedup is accepted.

The small internal reconstruction change is a proposal only: user requested handoff before edits were written, local status was clean, and no optimized candidate was published. Next session implements/reviews/tests that bounded candidate while preserving standalone public validators. Original evidence is retained under evidence/phase_2r/receipt_internal_profile_20261018/. Product remains draft/unmerged, master/integration unchanged.
