# Reading and New Acc simplification handoff — 26 October 2026

> Current status: [accepted Load and remaining work](al-trusted-load-accepted-history-next-20261027.md#brief-review-of-aa-through-ak).
> Read that review before using the implementation instructions below. Older status and policy statements are historical where later decisions replace them.

> Latest continuation: [Trusted story runtime and startup performance](ac-trusted-story-runtime-20261026.md).
> Read it first for the current validation policy, measured baseline and next work.
> Older implementation directions below are historical where that continuation supersedes them.

## Status and first outcome

This record contains the user's design decisions and a separately identified
implementation continuation. Requirements below are not all implemented; use the
continuation status and linked PR for actual accepted changes.

First observable outcome: an existing run loads current story content at its
stable saved line, or at the defined fallback if that line was deleted. Its
gameplay state remains intact. Opening History does not mark revised text as read.

This record supersedes conflicting next-step recommendations in
[z-newacc-attribution-20261025.md](z-newacc-attribution-20261025.md).
That record remains the source for measured costs and diagnostic evidence.
Do not automatically resume its narrow second-copy experiment as the main task.
The user now wants the larger simplification described here.

## Implementation continuation — 26 October 2026

Merged first batch: [PR #104](https://github.com/Siuuuers/dwm/pull/104),
commit `8b8e73929801a9527872b1485a289a1ffca6e5a8`.
The candidate shares immutable prepared scene configuration, keeps explicit DTL
IDs during authoring, preserves unchanged caption revisions, and marks displayed
Gallery Replay captions through Profile. Matched exported New Acc measurements passed: 5.14–5.92 seconds faster in
four matched fresh/retained comparisons; pauses remain 7.19–7.51 seconds. See
[the retained evidence](../evidence/phase_2r/reading_configuration_20261026/README.md).
Matched exported Load measurements also passed: 1.16–1.86 seconds faster, with
5.31–5.69-second frame gaps remaining. See [Load evidence](../evidence/phase_2r/reading_load_20261026/README.md).
Correctness run [40223513652](https://github.com/Siuuuers/dwm/actions/runs/40223513652)
passed: 50 successful jobs and one intentionally skipped separate measurement job.
One slow runner timed out before tests in user-directory proof; that job alone
passed on retry with unchanged code and limits. [Replay acceptance evidence](../evidence/phase_2r/reading_acceptance_20261026/README.md)
is retained. This is not completed save migration. Continue with
[the concrete migration owner map and failure cases](ab-current-content-save-migration-20261026.md).

The owner clarified these decisions during implementation:

- Use explicit major checkpoints, not every scene-entry label. The initial set
  is each day start and the first caption reached after a resolved choice or
  Challenge. Update the recovery anchor when that caption is reached.
- History shows current wording without adding global read marks. Content ahead
  of an intact saved line appears during normal continuation. Do not force a
  rewind for inserted content before that line. Keep encountered-only History;
  old saves can initially retain only their provable current caption.
- Read status is shared across languages. Canonical story revision owns it.
- Re-encountering an unresolved Challenge resumes the exact board. A Challenge
  with a saved result stays unavailable and follows that result.
- If an update deletes Challenge A while its board is unresolved, carry its
  exact placement and unfinished progress to the next eligible Challenge B.
  The eventual story result belongs to B. This replaces the earlier suggestion
  to refuse the removed-Challenge case or require a separate recovery screen.

### Save migration audit to use next

Normalize external saves once at `SaveMigrations.migrate_document`, before
current-content validation. Keep strict internal live checks after migration.
Do not merely remove the reading registration-hash comparison.

Physical Challenge context also contains the whole-story registration hash.
Its context and spec are frozen into the Profile attempt, semantic slot,
command hash and physical envelope. Rewriting A's physical context to B would
break those identities. Preserve the physical record and attempt reference;
let the Run own the current story binding to that record. A wording edit must
not replace a saved board or its rules.

Only an unresolved board may transfer. An `in_progress` physical record can
already have a saved `unfinished` story result because the player left the
Challenge cue. Check saved outcomes before deciding whether to resume or transfer.
Transfer must not change money, inventory, pressure, penalties or round limits.
Commit the new story binding and checkpoint together; failed persistence must
leave the old binding and board intact.

Fallback must follow saved choices and resolved Challenge outcomes without
repeating effects. Prior Challenge outcomes retain a hash plus Challenge ID
and result, not recoverable old occurrence IDs. Do not invent those old IDs.
Do not repeat day-renewal effects. Preserve retired historical choices/results
instead of requiring every old fact to remain in current registration.

Keep the active physical board separate from a temporarily rewound reading
cursor. An absent later eligible Challenge must not discard the suspended board.
The owner confirmed that transfer carries the exact state even for a terminal
board. There is no player-facing Finish button: terminal boards automatically
continue, while leaving an unfinished cue records its result. Do not confuse
internal test wording with the visible UI. Entire-day deletion will not occur
and is outside supported authoring changes; do not add a recovery mechanism for it.

## Confirmed player behavior

### Content and saved progress

- Give each dialogue line a unique stable ID.
- Keep an ID when wording changes. Do not derive identity from wording or line
  number. Do not reuse a deleted ID for another story moment.
- Keep the exact current line ID and only one recovery checkpoint: the latest
  major checkpoint reached on the actual route.
- The start of each day's DTL is also a checkpoint.
- If the saved line exists, resume there using current DTL.
- If the line was deleted, use the saved latest checkpoint.
- If that checkpoint was also deleted, use the start checkpoint of that DTL.
- Never automatically reset a run after a content update.
- Preserve existing saved gameplay values, choices, Challenge results and route.
  Do not substitute changed defaults for existing saved values.
- Unread content uses the updated DTL. Insertions before an intact saved line do
  not force replay of earlier dialogue.
- Do not add retroactive gameplay adjustments or alternate paths just to make
  old progress satisfy newly added content prerequisites. A new run provides
  the complete revised experience.
- Do not retain old full DTL versions merely to restore a reading position.

A stable anchor does not guarantee compatibility with arbitrary branch rewrites.
Inspect route ownership and choose the defined fallback for an invalid anchor.
If an entire day/start checkpoint is removed, do not invent a reset policy.
That is an exceptional unresolved content-authoring case, not a reason to block
ordinary wording edits or insertions.

### History

History contains the previous two checkpoint sections plus the current section,
only up to the current reading position, on the player's actual route.

Example after checkpoint 2:
1. Start checkpoint to checkpoint 1.
2. Checkpoint 1 to checkpoint 2.
3. Checkpoint 2 to the current line.

At checkpoint 3, drop the oldest section. Do not display boundary captions twice.
Use current wording for previously encountered IDs. Do not insert never-encountered
new lines merely because they lie before the cursor. Omit deleted lines.
Opening or scrolling History does not create new global read marks.

The single recovery checkpoint is separate from the bounded History window.
Derive History section boundaries from recorded choices/results where reliable.
If this is insufficient, retain minimal bounded display data; do not quietly
reintroduce a full recovery-checkpoint list. Verify what existing history already owns.

### Global read status and Replay

Distinguish an encountered line ID from having read its current text revision.
Normal playback and Replay display current DTL and mark the displayed line/revision
as globally read. Do not mark an entire section on entry.
Viewing updated wording in History does not mark that revision as read.
Previously read unchanged text should keep its read status across unrelated edits.
A global whole-story hash must not erase that distinction.

Replay and New Acc are different actions. The accepted recommendation is that
Replay leaves the active run's gameplay state unchanged while global read status
can grow. Inspect the existing Replay owner and UI before implementing; do not
create a new feature based only on the ambiguous earlier use of the word replay.

### New Acc form selection

Choose sweet or dark once with 50/50 probability for the initial run.
Then alternate: odd-numbered successful runs use the initial form; even-numbered
successful runs use the opposite form. Do not make a new coin flip on every run.
A failed attempt does not consume a turn. Loading or replaying does not advance it.
The current implementation already alternates; simplify its bookkeeping only
after checking its callers and persistence responsibilities.

## Proposed architecture, subject to code audit

These are implementation directions, not claims that all details are settled.

- Validate dialogue, labels, stable IDs, jumps, choices and event references in
  cloud build checks. Package runtime content with matching generated metadata.
- Prefer one shared immutable prepared configuration over repeatedly configuring
  each reading session. Each session owns only mutable cursor/history/choice state.
- Load required day data as needed. Title prewarming may prepare opening content
  after Title is responsive. Reuse it when New Acc is clicked.
- Prewarming must not allocate a persistent run, advance alternation, overwrite
  a save, or publish gameplay effects. Handle clicks before prewarming finishes.
- Keep responsive scheduling explicit. Moving work to Title does not eliminate
  work or make synchronous engine calls run in parallel.
- Replace global registration-hash equality as a save compatibility gate with
  stable anchors, route state and the stated fallback.
- Retain runtime checks for external saved-data shape and references required
  for safe operation. Do not simply delete checks and accept invalid state.
- Keep fingerprints where useful for build integrity, cache identity or diagnosis.
  Removing a string comparison alone will not remove compilation/copying cost.
- Check Dialogic native playback integration before designing a prepared format.
  Avoid two independent story representations with different semantics.
- Keep shared content frozen once. Remove repeated copying/freezing only when
  ownership proves safe. Mutable run state must remain independent.
- Prefer a small new-run candidate built from defaults and run identity over
  routing a fresh start through the full restore transaction.
- Preserve the old autosave until the new opening is ready and replacement
  succeeds. Enable player input only after a successful commit.
- Do not delete the intent journal before replacing the multi-file consistency
  role it currently serves for identity, profile, alternation and autosave.
  Choose the smallest persistence owner that can commit these coherently.
- Saving only changed-from-default fields is not automatically simpler. Store
  actual gameplay values where that avoids versioned-default migration machinery.

## Important correctness boundary

Dialogue position and gameplay state are stored separately. That separation does
not itself prevent replayed dialogue from executing an effect again.

Use existing saved completion/results where they reliably identify an already
resolved event. On fallback or Replay, do not duplicate rewards, purchases,
penalties or Challenge settlement. Do not reintroduce a general receipt ledger
unless a concrete remaining operation requires it. One owner must decide whether
an event is already resolved.

Inspect old save schemas before changing them. Preserve player data; do not fix
a schema mismatch by silently deleting saves or resetting a profile.

## Existing evidence and source map

Product baseline for the measurements: 47234a3395a4566e840140f1849da55a65d15521.
PRs 101, 102 and 103 preserved records only. Latest verified master before this
handoff was 6a94cbcd39b8ac9a32fbc09a7f17176ea32377cb. Fetch current master next session.

Measured New Acc:
- 90 fresh / 96 retained reading configurations.
- 8,300 fresh / 8,853 retained compiler calls, including cache hits.
- Inclusive configuration time about 3.82–4.47 seconds.
- Inclusive compilation time about 2.11–2.33 seconds, nested in configuration.
- Settlement includes extensive validation/configuration; it is not pure disk I/O.
- No accepted runtime speedup from these measurements.

Read the evidence handoff for exact samples and limitations. Do not add inclusive
child timings to parents or compare unmatched runners as an optimization result.

Relevant owners:
- scripts/narrative/DialogicEntryManifest.gd: registration, fingerprint, copies.
- scripts/narrative/SoloReadingSession.gd: configuration, frozen nodes, save/restore.
- scripts/narrative/DialogicRuntimeAdapter.gd: compilation cache and playback.
- autoload/DialogicBridge.gd: initial checkpoint, reading admission and restoration.
- autoload/SaveManager.gd: decision, intent, settlement, participant plans, activation.
- autoload/GameState.gd: gameplay defaults and new-run snapshot input.
- autoload/ProfileManager.gd and scripts/domain/relationship/PairDeckDraw.gd:
  run assignment, alternation and profile persistence.
- RunSnapshotSchema and FrozenRunContext: downstream save and registration checks.

## Next-session work order

1. Read AGENTS.md, CLAUDE.md and applicable design records. Fetch current master
   and check related work already merged. Use a clean product worktree.
2. Audit existing stable line/checkpoint IDs, read marks, History and Replay.
   Confirm which requirements are already implemented and who owns each fact.
3. Trace callers of registration equality and prepared session data. Identify
   the smallest coherent replacement, including the current native playback path.
4. Write concrete failure cases before changing persistence or restore behavior.
5. Implement in bounded reviewable changes. Complete independent audits before
   final acceptance testing. Parallel agents may investigate disjoint owners;
   one coordinator owns integration and publication.
6. Run cloud-only Godot/Windows tests. Local static checks are allowed.
7. Compare complete fresh/retained New Acc and Load journeys in matched orders.
   Measure Title responsiveness, click-to-caption latency and maximum frame gap.
   Do not claim speed from shorter code or fewer function names.
8. Merge only verified changes. Direct PR merges are authorized. Report actual
   changes, validation and limitations.

Required regression cases:
- Wording update and insertion before/after a stable saved line.
- Deleted current line, deleted latest checkpoint, and DTL-start fallback.
- Correct branch after saved choices and Challenge results.
- No automatic run reset, no changed saved gameplay values, no repeated effects.
- History rolling through checkpoints without duplicate boundaries or new-line
  backfill; updated History wording does not change global read status.
- Normal playback/Replay mark revised text only when displayed.
- Replay leaves active gameplay intact.
- Alternation across successful creation, failed creation, Load and restart.
- Failed save replacement preserves the previous autosave.
- Shared content remains immutable; separate sessions cannot mutate each other.
- Early New Acc click during prewarming and cross-day transitions.
- Rendered New Acc, Load, History, Contacts return and existing Gallery/Replay paths.

Keep strict shutdown-error checks. The desktop-deferral experiment has an
unresolved intermittent shutdown error; do not merge that diagnostic branch.
See y-desktop-dependency-investigation-20261025.md.

## Original documentation-session boundary

The following describes the original documentation session, before the
implementation continuation above. The user explicitly requested this handoff
and implementation in the next session.
No runtime changes or cloud test runs are part of this documentation task.
The local diagnostic checkout contains existing modified/untracked harness and
evidence files. Do not discard them or merge the diagnostic branch wholesale.
Start the next session from this record, then the measurement handoff.
