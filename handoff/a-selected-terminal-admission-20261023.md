# Qualified terminal admission — 23 October 2026

## Completed checkpoint

Continue `Siuuuers/dwm` on `codex/authored-week-followup-20261023`. Read AGENTS.md
and CLAUDE.md. Use Windows cloud execution, Godot 4.6.3 standard, and focused
automatic tests. The user authorized implementation and publication on the
continuation branch. Do not change master/PR51, merge diagnostic controllers into
product, or upload Steam. No design question blocks the next investigation.

Both optimizations are qualified. Runtime and focused-test bytes match
`5360c82e386698d6779f7b4cc63df3a07b9c0fe6` (tree
`801046ea4284d9afb21b76b023d0aad3377d8725`). The adoption commit adds retained
evidence and this handoff. No qualifying job remains active.

1. Selected terminal admission reuses manifest-owned immutable structural tables.
   Mutable receipt, issuer, creation-owner, physical Profile, source/trigger,
   hash/order and reconstructed-record checks remain fresh. Generic arbitrary
   bundle APIs and their error order remain intact.
2. FrozenRunContext full validation authenticates terminal authority once, then
   enters a private synchronous checkpoint body. The standalone public checkpoint
   API still authenticates on every call. No await, callback or mutation occurs
   between the full entry point's authentication and shared body.

There is no cross-call authority cache, saved-schema change, checkpoint-policy
change, or ending-creation change. The runtime change is limited to
SceneEventContract.gd, RunSnapshotSchema.gd and FrozenRunContext.gd. Independent
runtime and test reviews found no blocker.

## Qualification and measured outcome

First change: runtime `22415748662b377725cc2c617b8cd26b8d561832`, with tests
`97c28899f0913d14dc80644f3ab56b1354ec87c7`.
[Run 39940374828](https://github.com/Siuuuers/dwm/actions/runs/39940374828) passed:
seven generic terminal lifecycle tests, genuine selected-authority checks
(76 assertions), baseline Load/Save (112), candidate Load/Save/ending/NewGame
(342), and exact-source Windows export/startup.

Its matched broad Load went from 659.310 to 592.007 seconds; Save from 574.619 to
504.624 seconds. Structural calls fell from 1186 to 848 for Load and 1175 to 835
for Save. Receipt and physical-proof counts stayed 470 and 447 respectively.

Second change: final tested source `5360c82e386698d6779f7b4cc63df3a07b9c0fe6`.
[Run 39946595362](https://github.com/Siuuuers/dwm/actions/runs/39946595362) passed:
focused genuine-authority checks (98 assertions), matched baseline and candidate
Load/Save (112 each), fresh-process slot3 replay/completion/NewGame (312), and
exact-source Windows export/startup. All child exits were zero. Discovery finds
exactly one test per journey helper. Native ending restore and fresh Day1 images
were inspected. Replay observed 23 lines including fresh Day1, preserved slots
1/2/3, reached COMPLETED/GALLERY_RECORDED without duplicate Gallery effects, then
started a distinct PLAYING run with no ending plan or retained challenge.

Second matched comparison (baseline already includes the first optimization):

| Measurement | Baseline | Final candidate |
| --- | ---: | ---: |
| Broad Load helper | 599.204 s | 539.594 s |
| Broad Save helper | 500.876 s | 448.499 s |
| Title Backup press-return | 86.632 s | 78.051 s |
| Load action to owner Ready signal | 422.850 s | 382.081 s |
| Ending Backup press-return | 198.508 s | 180.326 s |
| Save action press-return | 300.223 s | 266.074 s |
| Load receipt / physical-proof calls | 470 / 470 | 402 / 402 |
| Save receipt / physical-proof calls | 447 / 447 | 377 / 377 |
| Load structural calls | 848 | 712 |
| Save structural calls | 835 | 695 |

These are single matched pairs, not a statistical benchmark. Do not combine the
two runs into a claimed matched total speedup. Broad helpers include captures,
assertions and screenshots. Press-return retains the original five frame waits;
Load Ready is the existing owner signal, not an exact frame-present measurement.
Save had finished successfully at press-return in both variants. Do not sum nested
profiling durations. The remaining multi-minute pauses are not smooth play.

The final focused checks cover equal selected/generic acceptance, fewer structural
checks, fresh changed receipts/issuer/owner/Profile, retained source history,
full versus standalone checkpoint authority counts, empty checkpoint policy, and
terminal-first error ordering. Physical Profile bytes restore immediately and in
cleanup. The trigger-hash mutation check is record-tamper coverage because the
fingerprint gate rejects it first; it is not independent hash-join coverage.

Export scope: unsigned Windows x64 release export, 136 packaged runtime resources
verified, isolated headless executable startup and Profile creation. This is not
graphical exported-game or full release acceptance. Final validation build archive
SHA256: `4e92da9522cec682457b28417a336368d05146bf5e5bb5911000b9d938a65a8c`.

The earlier uninterrupted full-week run39920770730 remains timed out. Neither
ending replay qualifies an uninterrupted full week. Prior late recovery/export
run39929612232 remains valid within its stated scope.

## Durable evidence and genuine saves

Evidence directories:
- `evidence/phase_2r/terminal_admission_20261023/run39940374828/`
- `evidence/phase_2r/terminal_admission_20261023/run39946595362/`

Each contains the original journey artifact ZIP, a compact inspection JSON, and
compact original export evidence (logs, origin, validation and build hashes).
The export evidence omits the approximately 111 MB build archive. The original
build artifact remains on the linked Actions run with its configured retention.

First journey artifact 12498915989 SHA256:
`c0c21ea365cd0bf123ef8602077823a10e2f9ef25a24ec42a7910e0315499c8d`.
Final journey artifact 12501877704 SHA256:
`ae87682f685fbd175f84e71d4165863cba2221536f00132136148a91a11e3078`.
Final original export artifact 12501359577 SHA256:
`3e01ffffc8fada77147aba845a90419def65c8e38afea213de78d3d51c7efb7b`.
Final compact export evidence SHA256:
`e543b93f56261c5e2e4943e0c4b7d03b00f896d22a30cf77e7a5494e8709579c`.

The final journey artifact contains two complete 42-file user roots:
- `terminal-baseline-root.zip`: SHA256
  `739327937312a4b3831d6bcdaf5ce5fe06e5f9707eb27685b54bbd38c984b911`.
- `terminal-candidate-root.zip`: SHA256
  `cd1bb2e531e63ceefe70afe35feaf5fb8ee7a91fd2b683e8072e432e509bbc7a`.

Both retain genuine slot2 ending (checkpoint71, 61 receipts) and newly saved slot3
ending (checkpoint72, 61 receipts). Autosave is fresh Day1 (checkpoint1, one receipt),
not the ending. Slot1 and slot2 hashes remain unchanged. The candidate root is
post replay/completion/NewGame. Keep the whole root, including issuer journals,
Profile and backups; do not rebuild authority from a diagnostic snapshot JSON.

For another matched comparison, the original 40-file pre-save root remains at
`evidence/phase_2r/authored_followup_20261023/run39929612232_late_success/genuine-post-replay-root.zip`,
SHA256 `82251bc333baaccdc4c1de38fb175f72b411466b8c4583d41e8fc7fc09edc029`.
It has occupied slots1/2 and empty slot3. Relocate only diagnostic proof.user_dir
in memory when seeding a new isolated root; preserve saved authority bytes.

## Controllers and resolved harness error

First controller `1ea1607eab1dbcb9c625b9752bd77af310e26c12` is preserved on
`codex/terminal-admission-controller-20261023`; its automatic push trigger was
retired at `2fbe7eae1b2d4639175f4f035a436beb9caab73a`.

Final controller `4b6a1450698d04ab39836b620a327e0bd91594fb` is preserved on
`codex/terminal-once-controller-20261023`; its automatic push trigger was retired
at `7e0a75175804ef398e37d2f12affc1d07fe95475`. Both retain manual dispatch only.
Controller helpers live under tools/testing/terminal-admission on those branches;
they are not product changes. Each native child kept its 1800-second deadline.

Run39940270641 was intentionally superseded during import after review found
that the Save helper did not confirm occupied-slot overwrite. Corrected journeys
save to empty slot3. Run39943584240 failed because pair-next.gd overrode an
inherited test name and GUT collected both descriptors: the first actual journey
passed, then duplicate startup failed with mutation_gate_already_configured.
The fix removed the wrapper and preflighted method discovery without instantiation.
The passing final run uses log level1 for both variants. Do not accept the failed
run's four-phase result as a qualified comparison.

## Next mission and why a new session helps

This batch is complete. A fresh session is useful for a separate bottleneck
investigation with a stable baseline and reproducible physical saves. Do not
repeat the full completed qualification merely to regain context.

Observable next outcome: opening or refreshing Backup should avoid demonstrably
redundant work while reporting the same slot validity and preserving fresh
selected-action authority. First measure, then choose the smallest change.

Inspect this owner path:
`BackupApp.get_projection()` -> `BackupPresentationPort.get_projection()` -> all
nine locators -> `SaveManager._inspect_backup_profiled()` -> document admission
and restore preparation -> snapshot/Frozen validation. Distinguish work for
listing slots from work for the selected Load/Save action. Existing
DWM_SAVE_LOAD_PROFILE scopes can separate backup_inspection, admission and restore
preparation by locator. Those scopes were not enabled in this batch's logs;
DWM_SCENE_VALIDATION_PROFILE counts alone do not attribute the cost to callers.

One narrow lead: get_projection() calls get_backup_save_capability() even at Title,
then discards it for title_load_only. Inspect its capture path and side effects,
and measure its actual contribution before removing work. Do not introduce an
unbounded cache or weaken authority just because counts are large.

Keep later-call freshness, physical Profile/issuer proof and error-order behavior.
Use focused invalid-authority tests for the changed owner, integration for storage,
and one affected native Load/Save journey. Add replay only if its boundary changes.
Finish independent caller/test reviews before final acceptance; avoid overlapping
broad runs. Do not inflate timeouts to hide a regression.

Master was checked at `d2062f8d9807f7f06935f86065640ff14a5400d6`; it did not contain
this selected-terminal API. Master/PR51 and Steam were not changed. This checkpoint
does not estimate overall game completion or approve unrelated story/UI work.
