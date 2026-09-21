# Beads and cloud verification — 2026-09-21

Working branch: `codex/windows-cloud-ux`, draft PR #1. The source baseline was
`681251dc832262c08826ce74d6a4480291eac4a8`. Verified code head:
`e1d3428fbfc9de27a0f350f3a858478cd06c0978`.
[Cloud run 35577704852](https://github.com/Siuuuers/dwm/actions/runs/35577704852)
passed all nine jobs. The PR checkout commit
`e585dc45f4305add2c7c37b316cea74d7153efae` has the same tree
`47e601d2b235fca8eacf2a4389e26543330f1558` as that code head.
The subsequent evidence/task commit does not change game code, tests or workflows.

## Scope and design decisions

The GitHub repository is authoritative for this work. Historical references to
other machines and worktrees are retained as history, not treated as changes to
those inaccessible checkouts. The accepted current UI decisions are recorded in
[owner-ui-updates-2026-09-21.md](../../docs/design/current-ui/owner-ui-updates-2026-09-21.md).

The owner permits discarding the previous save. Logout therefore remains a
launcher consent action and is rejected as a saved workspace, without introducing
a legacy migration. No personal save files were accessed or deleted in this work.

The repository contained 181 Beads records, of which 28 were unfinished. An
isolated Beads 1.3.0 tracker imported that snapshot and claimed `dwm-8gr` for this
batch. Only selected records are merged back into the exported JSONL; untouched
records retain their original bytes. This updates the GitHub task snapshot and
does not claim synchronization of another machine's Dolt database.

## Verified changes

- Logout consent retains launcher, host and cache state, starts on No, restores
  focus on cancellation, and uses the existing save/exit coordinator with truthful
  retry custody. New workspace admission and restored snapshots reject Logout.
- Storage path checking rejects numeric NUL and U+FFFD without embedding a NUL
  source literal. The separate evidence inventory sentinel preserves Godot's
  historical U+FFFD value and unique failure counter without an import warning.
- The last two unsafe test fixtures use the existing checked TemporaryStorage
  allocation and immediately stop setup/callers on refusal.
- Dating, delivery, welcome, notification and divider accessibility copy gains
  missing translations. Current literal ownership records match the demonstrated
  presenters; negative audit cases remain strict.
- Outgoing save validation avoids recursively normalizing a caller journal that
  is immediately replaced by already-proven bundles. The paired benchmark uses
  identical saved bytes for the comparison and retains both recovery bundles.

Four repaired records are closed: `dwm-1w9` (Logout), `dwm-6zh` (NUL diagnostics),
`dwm-ryl` (remaining unsafe test fixtures), and `dwm-vky.15` (full UI literal audit).
The two earlier acceptance records below are also closed. This resolves six of
the original 28 unfinished records; 22 remain unfinished. The batch tracker
`dwm-8gr` is closed separately, giving 182 total records and 160 closed records.
Closure records implementation and evidence on the draft branch, not a master merge.

The obsolete `dwm-6zh` ownership block on `dwm-634.3` is removed: this coordinated
GitHub batch owned the necessary source edits, while the latency task remains
unfinished. Its historical `discovered-from` link is retained. No inaccessible
external worktree was modified or claimed handed over.

## Earlier acceptance reconciled

`dwm-bap` is backed by the existing Day 7 calendar/echo acceptance report in
[evidence/day7_accessibility](../day7_accessibility/README.md).

`dwm-01b` is assessed against the owner's accepted whole-computer scaling design.
Existing Shop/Schedule resize tests and cloud run 35570702793 at the baseline
verify retained state and reachable content. The old separate wider-app reflow
requirement is superseded, not silently implemented or claimed.

## Verification history

The first candidate, `f475f9ff6a83d8aa49599f82033c812e8f0416cb`, failed run
35574830481 before gameplay tests: import found one remaining NUL source in the
evidence inventory, and the full literal audit exposed 32 stale or missing
ownership/translation entries. These failures were kept visible and addressed;
that run supplies no performance result.

Run 35575715188 at `63032abe334bddbc79bb70fc5d6e6bf21a908912` passed
all native rendering, full UI audit, paired performance and storage-refusal
checks. It exposed a StringName-vs-String key in a new refusal-order fixture,
an outdated English-fallback assertion after adding the real Chinese copy, and
an audit helper that logged an engine error for deliberately malformed input.
Those were corrected without changing production schema refusal order.

Run 35576255581 at `d5ee7e7403719b2a0d8fc879810a5c6c94414e02` passed every
GUT assertion, native check and performance probe. Its new-account job still
failed the overbroad Unicode log guard: the existing corrupt-save test deliberately
loads byte `0xff`. The runner now admits exactly one matching invalid-UTF-8
message only in that exact script/test context, while rejecting every NUL and
other unexpected Unicode diagnostic. Import, native and profiling gates remain
strict. No corrupt-save assertion was removed.

Run 35576966243 at `5492aae6a5f525d8a36528fed41f369ad9c2b457` passed the
corrected diagnostic guard and all 136 New Account GUT cases. Its later latency
probe still accessed the removed cached Logout app, produced a script error,
and reached its deadline. The probe now activates launcher consent and validates
retained launcher/cache state before confirming; measurement boundaries are
unchanged. This probe defect was not a measured 120-second game startup.

Final run 35577704852 at `e1d3428fbfc9de27a0f350f3a858478cd06c0978` passes all
nine jobs. Original failed runs remain in GitHub; none is counted as a passing run.

## Final verification

Seven Windows suites pass **1,218 tests across 109 unique scripts**, with requested
and executed scripts matching exactly, seven zero process exits, and zero ordinary
failures, errors or skips. JUnit reports, execution records, compressed logs and
independent verification are retained in [windows](windows/manifest.json).

| Suite | Tests | Scripts |
| --- | ---: | ---: |
| Desktop | 157 | 15 |
| Localization | 152 | 18 |
| Minesweeper | 197 | 20 |
| New Account | 136 | 13 |
| Reading/delivery | 178 | 14 |
| Settings | 254 | 21 |
| Shop | 144 | 8 |

Storage refusal is verified separately for empty and whitespace `DWM_TEST_ROOT`.
Each run has 78 cases: 75 expected `test_root_missing` refusals and three
storage-free passes, with exit 1 as intended. Before/after snapshots of 11,187
repository entries match exactly. These 156 intentional cases are excluded from
the 1,218 passing-test total. No personal save directories were tested or deleted.

The six native render processes report the expected X11 software-driver VSync
warning; it is not a script or Unicode failure.

No script, load, NUL or unexpected Unicode diagnostic remains in the checked
logs. Exactly one invalid-UTF-8 diagnostic is expected from the existing corrupt
`0xff` save fixture in `test_prepared_new_run.gd`, specifically
`test_prepare_counts_nonempty_unreadable_autosave_but_not_zero_bytes`.
The runner accepts only that exact message in that exact context, once.

Six native Linux render passes produce 137 PNGs: desktop 38, delivery/dialogue 25,
Angela overlay 10, Japanese/Korean 30, font choices 30, and startup/Logout four.
Native reports and artifact provenance are retained under [native](native/).
Full literal audit reports under [audit](audit/) cover 31 scene files / 53 records
and 301 script files / 324 records, with zero failures. The 20 audit regression
tests include negative ownership cases; they are part of the Windows total.
The legacy 50 English / 25 Simplified Chinese / 25 Traditional Chinese fingerprint
file remains the same Git blob; all 100 frozen texts pass their extraction checks.

## Performance and remaining lag

The controlled ablation changes only `SaveDocumentSchema.gd` between baseline and
candidate. Each locale uses the identical fixed autosave bytes for five samples
per version, with equal input/output hashes and both recovery bundles preserved.
The result below is the outgoing-validation phase, not the whole save or game.

| Fixed payload | Bytes | Baseline median | Candidate median | Reduction |
| --- | ---: | ---: | ---: | ---: |
| zh-CN | 376,091 | 41.547 ms | 29.029 ms | 30.13% |
| zh-HK | 362,808 | 39.366 ms | 26.876 ms | 31.73% |

Exact payloads, SHA256 hashes, results and eight isolated execution records are
retained in [performance/provenance.json](performance/provenance.json).
The reproducible driver is `tools/testing/Invoke-CheckpointPerformance.ps1`;
baseline schema is pinned to `681251dc832262c08826ce74d6a4480291eac4a8`.
No checkpoint, recovery proof, journal retention or durable write stage is removed.

Final candidate cloud observations still show routine App clicks around 40 ms,
New Board first reveals 206–228 ms, Dating first reveals 284–290 ms,
App round settlement 695–836 ms, and Dating settlement 531–590 ms.
Fresh journey boards differ, so these ranges are observations rather than
controlled before/after speedups. `dwm-634` and `dwm-634.3` remain unfinished;
seven-day long-history behavior was not measured by this short journey.

The final Windows New Account probe observes 746.556 ms fresh and 693.111 ms
replacement from button activation to desktop, with maximum frame gaps of
186.850 ms and 89.378 ms. This turn adds no further production New Account
optimization, so these single-run figures are not a causal speed comparison.

## Limits

A clean focused suite is not whole-game release acceptance. The originally
reported intermittent ordinary-reply failure and renderer shutdown stall require
matching recurrence evidence before their causes can be called fixed. Larger
persistent History, exact audio restoration, frozen narrative context, Controls,
dual-language and seven-day release tasks retain their unfinished acceptance.
Headless Windows timings are processing observations, not physical input-to-paint
measurements on a player's computer. The native rendering job uses Linux software
OpenGL; it is not Windows assistive-technology certification.

## Unfinished original records

These are seven deferred, six open, eight in progress and one blocked record.
Dependencies, broader acceptance and genuine deferred scope remain visible.

| Bead | Status | Work |
| --- | --- | --- |
| `dwm-5ht` | deferred | Implement dual-language rendering before restoring secondary-language controls |
| `dwm-634` | open | Reduce cumulative Autosave latency as recovery history grows |
| `dwm-634.3` | in progress | Minesweeper terminal settlement frame and remaining checkpoint cost: consequence pipeline, single strict validation, port read amplification |
| `dwm-eei` | deferred | Finish remaining Settings preview, Controls and witnessed History behavior |
| `dwm-eei.10` | deferred | Build witnessed-scene live captions on existing Dialogic playback |
| `dwm-eei.11` | deferred | Complete witnessed caption stack and public-history projection |
| `dwm-eei.17` | open | Investigate intermittent native renderer shutdown stall after caption matrix |
| `dwm-eei.2` | deferred | Finish Settings shared-host and recovery presentation |
| `dwm-eei.5` | deferred | Reconcile canonical input registry and implement two-device Controls rebinding |
| `dwm-eob` | deferred | Choose narrative localization adapter after representative files exist |
| `dwm-hsi` | in progress | Fix ordinary reply save failure in real play |
| `dwm-n3h` | open | Specification 12.3 frozen-context field law is unenforced: frozen_context is a bare four-key Dictionary |
| `dwm-nqn` | open | Compose silent audio with the frozen seven-day runtime before persistence advances |
| `dwm-oyo` | open | Implement approved seven-day flow and Dialogic structure |
| `dwm-oyo.5` | in progress | Phase 04 — Persistence profile ledgers and Rehearsal |
| `dwm-oyo.6` | in progress | Phase 05 — Day 7 endings Gallery and production wiring |
| `dwm-oyo.7` | open | Phase 06 — Integration and release evidence |
| `dwm-sx8` | in progress | Replace legacy public API contract labels with demonstrated test coverage |
| `dwm-vky` | in progress | Implement the 2026-09-12 UI amendment (week tint, Steady Interface, drift deck, all-input) |
| `dwm-vky.14` | in progress | Complete Witnessed reading rail and transport owners |
| `dwm-7wj` | in progress | Replace Gallery dropdown with witnessed-version register and readable record desk |
| `dwm-wuk` | blocked | Windows Gallery scroll semantics need upstream ScrollPattern support |
