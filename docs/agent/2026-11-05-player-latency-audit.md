# Player latency audit — 2026-11-05

Save was the strongest repeated in-play optimization candidate in the baseline run. Its median action duration was 889 ms and its largest observed engine-frame interval was 1,048 ms. The Contacts registration follow-up below records the resulting implementation and matched comparison. These are Linux headless diagnostics, not measurements of the Windows release's display or audio latency.

## Revision and proof

- Production revision: `69949519880c1ed4449ef0361377ef287809b9e9`.
- Godot 4.6.3 stable standard build; imported source project; isolated user files.
- One complete authored Day 1–7 route: 830 caption positions across 28 entries, followed by Gallery navigation and Load of a saved Day 7 challenge boundary.
- Final journey: **4,285 assertions passed**, GUT exit 0, 121.329 seconds inside the test. Three startup processes also exited 0.
- Raw action samples, SaveManager profiles, probe hashes and limits: [headless evidence](../../tools/player_latency/evidence/2026-11-05-headless.json).
- Only the final successful journey is included. Earlier probe-development attempts are excluded.

## Measurements

All durations below are milliseconds. These are state-observation timings with headless frame pacing; they include input dispatch and the probe's frame waits. They do not establish on-screen response time. Percentiles describe this route, not a population estimate.

| Operation | Samples | Median | Observed range |
|---|---:|---:|---:|
| Process launch → title ready, fresh profile | 3 | 10,563 | 9,124–11,823 |
| Title mount → New Game flow, automated confirmation | 1 | 1,628 | 1,628 |
| Save/overwrite flow | 6 | 889 | 810–1,910 |
| History open | 6 | 153 | 61–844 |
| Settings open | 6 | 139 | 129–709 |
| Passage/entry transition → input ready | 27 | 180 | 106–451 |
| Ordinary caption → input ready | 802 | 112 | 92–158 |
| Ordinary caption presentation acknowledgment | 802 | 18.6 | p95: 36.3 |
| Save menu open | 6 | 77.6 | 62–226 |
| Computer reopen | 6 | 46.2 | 26–137 |
| Gallery open | 3 | 12.5 | 12–37 |
| Dialogue Library tab | 3 | 13.5 | 13–14 |
| Load menu open | 1 | 22.0 | 22 |
| Load action → restored live session and caption content | 1 | 401 | 401 |

The startup observer loads the normal main scene through a SceneTree script and waits for bootstrap readiness and an enabled New Game button. It excludes rendering and does not flush the OS file cache. Its source-project startup number needs exported Windows confirmation before it becomes a release-performance claim.

Save samples were 810/1,910/912 ms on Day 1 and 1,134/865/850 ms on Day 7. This run does **not** establish growth with story age. First-use History was 844 ms; subsequent opens were 61–178 ms. First-use Settings was 709 ms; subsequent opens were 129–272 ms. Cold and warm actions should remain separate in follow-up comparisons.

The slowest entry transitions were the ending entry (451 ms), Day 1 result A (351 ms), and Day 4 entry (308 ms). Entry p95 was 351 ms. This does not cover every route or outcome.

## Investigation

`node_dialog_text` applies `dialogic/text/advance_delay`, default 0.1 seconds, after organic reveal completion. The probe therefore records presentation acknowledgment separately from eligibility for another input. Removing the guard to improve the input-ready number would change skip protection rather than remove rendering work.

For six successful saves, the existing SaveManager profiler reported these median phase durations:

| Phase | Median ms |
|---|---:|
| Snapshot capture | 292 |
| Document construction | 157 |
| Atomic write, including its validation callback | 178 |
| Journal commit | 163 |
| Serialization | 0.925 |
| Physical reread | 0.109 |

The saved slot was approximately 6.2 KiB by Day 7. Serialization and raw bytes are not the leading observed costs. The atomic-write scope includes validation, so its duration must not be described as disk I/O alone. Scope totals are inclusive, and medians of phases must not be added to reconstruct a median action duration.

`SaveManager._commit_backup_action_profiled` validates outgoing document text through `_document_text_validator`; `CheckpointJournal.commit_prepared` also calls `_validate_candidate`, which validates the current snapshot. These are concrete targets for deeper profiling and checking whether already admitted validation results can be reused. The audit does not prove every repeated check is redundant.

The follow-up isolated repeated Contacts registration work inside snapshot validation. Further reuse of prepared snapshot validation remains a separate investigation. First-use History/Settings also needs separate attribution; this audit does not identify its exact internal cost owner.

## Contacts registration follow-up

`ContactInvitationState.capture_scene_definitions` previously requested a deep copy of the entire installed story registration and canonicalized/hashed that copy every time it validated Contacts. Source tracing and temporary instrumentation found five such copies/hashes per Save: one live-input validation and four complete snapshot validations. A three-Save early-game probe produced 15 calls of each kind despite having zero Contacts messages or transaction receipts. The instrumented median was 9.65 ms per registration copy and 98.85 ms per canonicalization/hash. These nested samples are attribution evidence, not an uninstrumented speed comparison.

The production change replaces three lines: use `scene_contract_tables().bundle`, which is already recursively immutable, and compare `scene_registration_fingerprint()`, which the registration owner already computed. The installed-registration reader still selects the active registration on each call, and the requested fingerprint must still match it. Contact definition validation, detached returned definition rows, message/read/reply state validation, source freshness checks, atomic writes and journal validation remain in place. No new cache or caller-provided trust flag was added.

Matched, uninstrumented, sequential runs used the same probe, fresh processes and isolated profiles on this Linux host:

| Metric | Before | After |
|---|---:|---:|
| Save samples, ms | 893.837 / 931.370 / 850.018 | 306.504 / 357.859 / 327.995 |
| Median Save, ms | 893.837 | 327.995 |
| Largest observed Save frame interval, ms | 887.139 | 300.030 |
| Focused assertions | 102 passed | 102 passed |

The observed median reduction is 63.3%; three samples per variant do not establish a Windows release guarantee. [Comparison evidence](../../tools/player_latency/evidence/2026-11-05-contacts-registration-reuse.json) includes the exact probe source, raw action samples, production-file hashes and limits. The probe intentionally uses the early portion of the original authored journey; it does not add a permanent duplicate test suite.

Candidate verification also passed the complete authored journey through same-process checkpoint Load (4,285 assertions) and the existing message/read/reply positive test (12 assertions). The complete journey is correctness evidence here; its timings were not used in the matched comparison. Comment lint and whitespace checks passed.

Reproduce by writing `probe_source` from that JSON to `.godot/ci/contacts-save-probe.gd`, then use the journey command above with `-gtest=res://.godot/ci/contacts-save-probe.gd`, a new isolated root, and `DWM_SAVE_LOAD_PROFILE` unset. Run before and after sequentially on the same host. The original 4,285-assertion journey count consists largely of five checks repeated over 830 captions (4,150 checks); it is not 4,285 runtime Save assertions.

## Limits

Xvfb could not provide a usable display in this environment. Artwork-viewer attempts could not validate unlocked image presentation headlessly and were excluded. GPU texture upload, actual Windows input-to-photon latency, audio start/crossfade gaps, physical Minesweeper interactions, other branches, other languages and text-size combinations remain unmeasured. Gallery numbers cover navigation, not fullscreen image decoding/rendering. Load is a same-process restored-session measurement at a control boundary, not a fresh-process load or an ordinary-dialogue input-ready measurement.

## Reproduce

Import with the pinned Godot build first, then restore any import-only changes to `project.godot`. Use a new directory for every journey:

```bash
audit_root="$PWD/.godot/phase2r_tests/player-latency-run"
mkdir -p "$audit_root/data" "$audit_root/test-root"
XDG_DATA_HOME="$audit_root/data" \
DWM_TEST_ROOT="$audit_root/test-root" \
DWM_BENCHMARK_REVISION="$(git rev-parse HEAD)" \
DWM_SAVE_LOAD_PROFILE=1 \
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gconfig= -gtest=res://tests/manual/benchmark_player_latency.gd -gexit
```

The journey writes `.godot/ci/player-latency.json` and emits `PLAYER_LATENCY` and `DWM_SAVE_LOAD_PROFILE` records. A successful GUT exit is required before accepting a dataset. The probe supports a display, but its rendered path has not been verified here.

For startup, use three new XDG directories, unset `DWM_TEST_ROOT`, and run:

```bash
XDG_DATA_HOME="$PWD/.godot/phase2r_tests/startup-run" \
DWM_STARTUP_AUDIT=1 DWM_BENCHMARK_REVISION="$(git rev-parse HEAD)" \
"$GODOT" --headless --path . -s res://tests/manual/benchmark_player_startup.gd
```

`PLAYER_STARTUP.engine_ticks_us` reports engine-relative readiness. The recorded process-to-marker measurements additionally use the parent process's monotonic clock. No performance threshold or automatic CI matrix was added.

## Owned Save candidate reuse follow-up

The new checkpoint is validated during construction. SaveDocumentSchema now accepts the exact owner-proven snapshot identity, detaches it, and builds the document without revalidating that snapshot. SaveManager seeds its per-write validation memo with the exact canonical text it just produced. Different existing/recovery text still receives independent validation. After physical readback and the existing journal freshness check, the prepared journal candidate is installed without a fourth snapshot validation. Live source freshness, selected slot revision, atomic writing, and byte-exact readback remain intact. Independently loaded documents still receive full schema validation.

Compared with the Contacts-fixed revision `657c393e0158291ff2eafdaa0b3dc6490bd33dd0`, the same focused probe measured Save at 424.378, 533.200, 358.470 ms before and 134.950, 143.909, 236.820 ms after. Median: **424.378 → 143.909 ms (66.1% lower)**. These are three sequential samples per variant in fresh processes/profiles on shared Linux headless infrastructure, not Windows display evidence. Do not compound this percentage with the earlier Contacts comparison.

Validation: focused probe 102 assertions per variant; document schema 74; full authored week 4,285; saved checkpoint creator 3,792; fresh-process Load 101. The initial Load process was interrupted by workspace loss; the recovered workspace rerun passed all 101 assertions. Global discoveries and local checkpoint restoration are covered by that existing positive create/load pair. The exact probe, samples, source hashes, and log hashes are in [candidate reuse evidence](../../tools/player_latency/evidence/2026-11-05-save-candidate-reuse.json).

The existing fast source-lint job now guards the Save commit against reintroducing full document/snapshot validation or public journal revalidation, and guards Contacts definition capture against rebuilding/hashing the immutable registration. Its function selector also recognizes static owners. All 22 lint unit checks passed. These are narrow structural checks, not a general ban on validation and not proof of a runtime timing budget.

## First History, Settings, transitions, and Load follow-up

The recovered Save candidate was published as `07727f340bcf7f3040c712826db06251214ba06e`. The following investigation starts from that revision.

An instrumented native first History command took 913.864 ms. Inside that operation, the unrelated pause Settings instance spent 703.452 ms in `_ready`; History projection itself took 4.595 ms. The Settings instance used by the Scene computer was then built separately on the actual Settings command. The expensive first History opening was therefore primarily unrelated UI construction, not its caption projection.

`ProductionPauseController.request_pause` now asks for Settings only when opening the full Pause surface or recovery. A direct Settings sheet still constructs its host explicitly, and the existing host is reused. History and direct Save still retain their original pause/backup custody. `SettingsContent` populates labels before binding its controller, eliminating an initial refresh that was immediately repeated after labeling. `SettingsControlsSheet.set_presentation` no longer styles all binding buttons immediately before `refresh` styles those same buttons. Dynamic bindings, labels, accessibility, confirmation themes, and control refresh remain intact.

| First-open observation | Before | Final candidate |
| --- | ---: | ---: |
| First History | 949.891 ms | 41.113 ms |
| First Settings after History/Save | 606.321 ms | 828.576 ms |
| Combined first History + Settings | 1556.212 ms | 869.689 ms |

Each first opening has **one cold sample per run**, not three independent cold repetitions. The preliminary candidate measured History 110.194 ms and Settings 1203.655 ms before removing the duplicate binding styling pass; host variability means that difference cannot be attributed entirely to the deletion. First Settings is now cold rather than accidentally warmed by History. Do not claim Settings itself got faster. Later early-session Settings opens in the final run were 137.060 and 124.601 ms. The final full journey's early UI sequence is identical to the focused baseline sequence.

The instrumented full-route investigation recorded 27 passage-entry transitions at median 199.905 ms, with the largest 657.454 ms at `line.Day6.A.001`, an authored Challenge-result handoff. Checkpoint Load took 584.620 ms: preparation 19.544 ms (including participant preparation 12.640 ms), synchronous commit 110.768 ms, followed by pending scene activation/presentation. Those nested phases are not additive. The successful route completes the pending activation; its intermediate `scene_activation_pending` result is not a failed final Load.

Final uninstrumented candidate: 27 passage entries, median 180.348 ms, range 115.088–500.877 ms; one Day7 checkpoint Load 479.817 ms. These are diagnostic observations, **not established transition/Load speedups**. No transition, Challenge, restore validation, authored effect, or input guard was removed. Next attribution should split Challenge-result preparation and deferred scene activation/presentation; another broad assertion deletion is not supported by these results.

Validation: full native-input authored journey and Load 4,285 assertions; positive lazy pause-host check 92; existing font-change/binding preservation check 16; existing localized Boolean-caption/commit check 114. The new manual check proves History and Save leave Settings unconstructed, Settings still opens, its instance is reused, and the caption remains unchanged. Existing lint now also rejects unconditional default host construction in `request_pause` and duplicate binding styling in `set_presentation`; all 22 lint tests passed. Comment and whitespace checks passed.

Raw action observations, phase records, reproduction probes, source hashes, check log hashes, and interpretation limits: [first-open evidence](../../tools/player_latency/evidence/2026-11-05-first-open-followup.json). All timings are Linux headless state-observation timings, not exported Windows input-to-photon measurements.

## Cold Settings theme ownership and Load check cost

From `bdc942e75e4d9450303aea751ceb2e1ae5f80a9d`, the Controls sheet still created a temporary 100% theme in its child `_ready`, styled/refreshed it, then refreshed again. Its sole constructor is SettingsContent, which later applies the actual player presentation. Removed that temporary theme/refresh sequence. Initial label population now leaves binding refresh to the subsequent bound controller, so no binding styling runs before its actual theme exists. Later label changes still refresh bindings normally. A scoped lint guard prevents fallback theme initialization returning to Controls `_ready`.

A new probe opens Settings before any History or Save to measure a genuinely cold Settings path. Sequential fresh profiles/processes measured **1723.125 → 616.015 ms** on first opening. The two later openings were 414.845/312.398 ms before and 189.762/205.120 ms after. These are one cold sample per variant on a variable shared host, not reliable population estimates or Windows display latency. They cannot be directly compared with the earlier History-first workload. Both probes passed 84 assertions.

Candidate checks: the existing 18 locale/text-size/target-size geometry and font combinations passed 4,287 assertions; existing live font/binding preservation passed 16; actual lazy pause Settings ownership/open/reuse passed 92. All 22 lint checks plus comment/whitespace checks passed.

For Load, a timing overlay counted 14 `_scene_restore_current` calls totaling **8.833 ms**, maximum 1.247 ms, on the early compact-history checkpoint. This does not justify treating those repeated checks as the main remaining stall. No Load checks were removed. This diagnostic is not a fresh-Load correctness pass: its PID-inequality fixture assertion failed because the recovered environment reused PID 6; the other 100 assertions passed. The overlay was removed. The earlier accepted fresh-process Load and full journey evidence remain separate. Next Load attribution should time route mounting, native frontier installation, style preparation, and deferred presentation individually.

Exact probes, raw samples, source/log hashes, and limitations: [initial-theme evidence](../../tools/player_latency/evidence/2026-11-05-settings-initial-theme.json).

## Caption initial-theme follow-up

From `3170eef69033624f3a24e6f0c6f64121606f39ae`, fresh Load attribution found route begin 5.246 ms, SceneHost `_ready` 153.721 ms, style creation 14.643 ms, and native frontier installation 7.705 ms. The latter are nested/deferred stages, not additive portions of a single synchronous stack. A subsequent caption overlay measured its deferred `_ready` at 469.639 ms, including a default 100% presentation build at 98.392 ms followed by the actual 125% preferences at 67.908 ms. These are separate diagnostic runs and cannot be summed into one Load.

The caption now applies real preferences before constructing a fallback presentation. If no valid theme results, the existing default construction remains. Installed-run palette/day application, native caption setup, restore validation, and publication/input readiness are unchanged. The source lint now guards against moving default presentation construction back ahead of preference application.

Matched uninstrumented cold-process comparison, identical isolated user-data seed and checkpoint: **1397.195 → 1038.425 ms**, one successful sample per variant, both 100 state assertions passed. The timer starts at the actual Load button command and ends after the expected full caption is input-ready. This early compact-history checkpoint is not the earlier warm Day7 Load workload. Shared-host noise and one sample do not support a robust percentage or Windows-display claim.

The runner starts a separate Godot process for every sample and restores the same user-data seed. Its temporary comparison wrapper omits the unreliable numeric PID-inequality assertion: this recovered environment reused PID 7 for separately launched processes. All checkpoint bytes, global-discovery, local-history, caption, and input-readiness assertions remain. The existing source tests were not weakened. A creator and loader launched sequentially by one supervisor also passed the original 3,792/101 assertions.

Three older `test_witnessed_run_presentation.gd` cases encountered missing `t`/`get_readiness` methods on their MemoryLocale fake; the fresh-layout case reproduced the same failure on the unchanged baseline. These are excluded from passing evidence and left outside the production optimization.

Exact comparison source/runner, diagnostic phase values, candidate source hash, and limits: [caption initial-theme evidence](../../tools/player_latency/evidence/2026-11-05-caption-initial-theme.json).

Final candidate: the complete 830-caption authored journey, early/late UI, and checkpoint Load passed all 4,285 assertions. All 22 lint unit tests, structural lint, comment lint, and whitespace checks passed.

## Global preferences and unchanged run presentation

Load already marks Profile and Localization plans `reuse_current`; current global preferences are not rolled back from a checkpoint. Fresh UI must still apply those current preferences, and restored audio context must use current global audio preferences. The redundant operation was instead `configure_run_presentation`: it built a new caption theme even when the admitted run palette and day already matched the applied theme.

The method now retains the existing theme when present and matching palette/day. It still reads and validates the run context, updates the owner reference, and rebuilds when the palette/day changes or no theme exists. Actual preference changes continue through `_apply_preferences`, independently of this run-context fast path.

Matched cold Load observations from `11051f3ee60d8141cfe2f04327f63bffc2c16aa7`: **1701.049 → 1204.069 ms**, one sample per variant, 100 state assertions each. Shared-host variability means the full difference cannot be attributed to this small change or expressed as a reliable speedup percentage. Both use the same saved user-data seed in independently launched processes.

The new positive manual check saves a checkpoint, changes global text size/high contrast, loads the older checkpoint through the actual in-game Load owner, and verifies the newer global settings survive and appear on the caption. It also verifies unchanged run context keeps the same theme object and a subsequent text-size change still replaces/applies the theme. All 119 assertions passed. The full-week probe additionally checks the applied day at every passage-entry boundary.

Exact probes, runner, source/log hashes, raw timings, and limitations: [run presentation reuse evidence](../../tools/player_latency/evidence/2026-11-05-run-presentation-reuse.json).

Final candidate week: all 4,312 assertions passed, including 27 applied-day checks, 830 captions, early/late UI, and checkpoint Load. All 22 lint tests, structural checks, comment lint, and whitespace checks passed.
