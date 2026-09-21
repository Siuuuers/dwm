# PR1 cloud Beads continuation — 2026-09-21

Work continues on `codex/windows-cloud-ux`, PR #1. Bead closure requires the
relevant implementation and cloud evidence; the expanded workflow is not yet
fully passing at the checkpoint recorded below.

## Implemented and under verification

- Profile v9 retains first-witnessed presentation chronology. Migrated v8
  signatures retain explicit unknown legacy order. Replays cannot rewrite the
  known chronology or manufacture a first witness.
- Failed Load compensation restores the exact prior audio runtime, including
  stream/player identity and playback/fade state. A successful Load still uses
  the accepted curated-anchor behavior; this is a separate contract.
- Minesweeper receives the admitted day tint on Desktop and Dating surfaces.
  All 16 palette tuples across seven days retain semantic ink and accessibility
  constraints; Day 1 and High Contrast are preserved.
- Direct SaveManager boundary tests exercise responsive New Account/Retry,
  session-exit custody, and exact retained `load_context` behavior. Four contract
  labels identify these direct tests. Six unused GameState wrappers are retired.
- Pause and Desktop Quick commands use the existing Backup transaction owner,
  preserving app/modal custody, Cancel-first Load consent, and held-contact
  quarantine. The existing Controls rules reject modifier chords; tests preserve
  that deliberate restriction and the unchanged default binding.
- The first frozen-story-context checkpoint captures immutable Dating facts and
  rejects malformed retained contexts before Profile history reconciliation.
  It does not finish Contacts, Hospital, ordered endings, or the final RunSave
  migration; `dwm-n3h` remains open until those producers are covered.

Dating retains automatic pre-board/post-board handoff with no Continue/Done
interstitial or special-mine action. Observer interactions remain retired from
current play and preserved at `archive/observer-interactions-2026-09-21`.

## Measured cloud checkpoints

| Run | PR head | Result and scope |
| --- | --- | --- |
| 39 / `35604201178` | `69abfaf0065edcbfed5c6efb6a7f7f0a3ff60c55` | 11/14 jobs passed. New ending, persistence, and Minesweeper fixtures exposed stale assumptions. Seven-day retained-history/cold Login correctness passed. |
| 40 / `35627055044` | `34926b45af076559de40d8ee00c3403254428a3b` | All 17 jobs stopped at import: Godot rejected an array-expression constant in ProfileSchema. No test-pass claim. |
| 41 / `35627369190` | `86e511f5c05e902d2ab7e625fcd91581d510a470` | Parser fixed; 12/17 jobs passed. Settings, persistence, reading/delivery, exported startup, and full rendered journeys still failed. |
| 42 / `35629589023` | `0fa182fdf5ca6999f4adcfe0369781d2a308a6db` | 11/17 jobs passed. All five rendered journeys reached their markers/captures; strict native-TTS and shutdown-resource gates still failed. Three focused fixture corrections and one real no-mutation Dating refusal fix remain under verification. |

Run 41's focused failures were two invalid checkpoint-field fixture accesses,
two paused-Quick fixture assumptions, and one expected storage-refusal code.
The storage guard correctly returned `reconcile_required` after an external byte
change. Fixes retain the real guards and add unchanged-state assertions.

Run 41 generated canonical public inventories successfully and found zero
references to the six retired GameState APIs in 888 scanned source files.
The exact inventories were recovered with byte counts and SHA256 verification.
Further source/contract edits require regeneration followed by a final read-only
check of the committed inventories.

The expanded full-journey harness found script/teardown failures and a dating
watchdog timeout even where some expected markers were reached. A marker alone
does not pass the strict engine-error gate. The export reached pack audit but
failed its strict engine-error scan; bounded engine diagnostics are being added
to make the underlying failure visible in the job log.

## Performance evidence and remaining work

Run 41 retained exactly 32 line, 32 manual-save, and two semantic checkpoints
after seven days, then restored the exact Day 7 Autosave in a fresh process.
The fixture adds 98 explicitly synthetic checkpoints alongside real New Account,
App-loss, Schedule Done, and Slot 1 paths. It is not an authored-dialogue
playthrough.

The final document was 1,671,028 bytes with SHA256
`7ebffe8e2e1ecbc2233e8b678e09ae851eace5e336e5b4372ad29a159515f1c9`.
On that shared Windows runner, Day 7 first Reveal took 925.962 ms synchronously,
settlement took 1,988.443 ms, Slot 1 save took 5,163.638 ms, and cold Login took
12,188.362 ms. These are observations for this fixture and runner.

All 34 durable Autosaves took the full-document fallback: no retained-journal
splice was used. This establishes the next concrete optimization target:
remember validated historical bundles only after an exact durable full write,
successful reread, and successful journal commit. Failed or mismatched writes
must never establish that proof.

The separate matched-payload normalization probe used five samples after two
warmups with identical input/output hashes. Day 7's normalization median was
160.144 ms for the pinned baseline and 81.871 ms for the candidate. This measures
one normalization seam with a complete proof set; because production history
used no splices, it does not establish a corresponding end-to-end speedup.

Run 42 proved real use of the retained-history optimization: 14 of 34 durable
Autosaves used the splice. Its Day 7 document was 1,671,259 bytes. First Reveal
took 911.698 ms, settlement 627.815 ms, Slot 1 prepare-plus-commit 4,123.819 ms,
and the automated cold Login flow 9,709.482 ms. Login includes opening the Title
Backup picker, selecting Autosave, consent, restoration, and frame waits. The
fresh payload and runner differ from run 41, so these observations do not prove
a causal end-to-end percentage improvement. Save/Load phase instrumentation is
the next step for the remaining multi-second operations.

Outstanding content/native gates remain explicit: authored per-version Gallery
cues and canonical dialogue History require their accepted content/catalogs;
native Windows UI Automation requires the missing upstream scroll-provider
capability. Headless tests, software-rendered screenshots, and package startup
do not substitute for those gates.
