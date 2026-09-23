# Next-session handoff — 23 September 2026

Read this first when continuing public `Siuuuers/dwm` draft PR #1. The owner
requested this checkpoint so implementation can continue in a fresh session.
This is navigation and a record of the session, not a replacement for the
selected task's requirements. Older detailed history is in
`docs/agent/2026-09-21-session-handoff.md`.

## Verified starting point

- PR: <https://github.com/Siuuuers/dwm/pull/1>; branch `codex/windows-cloud-ux`.
- Repository stays **public**; PR stays **draft**. Do not merge or change master.
- Last verified master: `9e43b52c9884ccd59e82245d2168c3113ee4d037`.
- Tested game source: `cc42b9e4c4f0c5c736fef625c0be6b1fa0855f00`.
- Tested PR merge: `efcc6d210896389641a270c0c2ee9e0e5074404c`.
- Completed cloud Run57: <https://github.com/Siuuuers/dwm/actions/runs/35814988598>.
- Evidence publication: `ef76304eb981aef1686812f0d921b57a0511198c`, a records-only
  `[skip ci]` commit. This subsequent handoff checkpoint is documentation-only.
  Neither changes the tested production, tests, workflow or inventories.
- **Godot 4.6.3 standard, GDScript.** Older memory describing .NET/C# is stale.
- Owner is phone-only: execute Godot and PowerShell validation in GitHub cloud.
  Local source inspection and static Python analysis are permitted.

Fetch and inspect the **live PR head** before work; do not reset newer work to
one of the reference commits above. Verify draft/base/branch and the worktree.
At this checkpoint there is no pending source batch or CI run to resume.
Older warnings about an obsolete partial checkout describe an earlier workspace;
establish the current checkout's provenance rather than applying them blindly.

Run57 passed all **17 jobs**, **1,997 GUT executions with zero skips**, 136
standalone capture checks, all five rendered journeys, rendered UI checks and
Windows exported startup. Both committed public inventories reproduce **without
regeneration**. These counts are executions, not a deduplicated test census;
Linux rendered evidence and Windows export startup do not establish full native
Windows graphical or accessibility acceptance.

Authoritative retained evidence:

- `evidence/beads_cloud_review/resumed-public-cloud-run57.json`
- `evidence/beads_cloud_review/performance/run57-checkpoint-trace.json`
- `evidence/phase_2r/runtime/game_state_surface.json`
- `evidence/phase_2r/runtime/save_manager_surface.json`

The ordered trace is in git, so the next investigation does not depend on
temporary Actions artifacts or this session's scratch files.

## Tracker and startup

Verified `.beads/issues.jsonl`: **191 records; 168 closed; 23 unfinished**
(11 in progress, five open, six deferred, one blocked). Parent tasks are included;
this is not a count of independent features or a percentage of release readiness.
Only `dwm-n3h.1` and `dwm-sx8.1` closed after Run55. The subsequent performance
batch closed no task; its parents and broader feature/acceptance work remain open.

Read `Prompt.md`, `CLAUDE.md`, `docs/agent/AGENT_WORKFLOW.md`, and the selected
issue's current metadata and linked requirements before edits. Use the ongoing
owner-authorized PR continuation and recorded task scope; do not invent new
behavior from a handoff or treat historical blockers as current observations.
`bd` was unavailable in this environment: recheck availability, and if still
unavailable use the previously recorded root-only JSONL snapshot procedure.
Exactly one coordinator writes Beads; preserve unrelated records byte-for-byte
and close work only against its specific demonstrated acceptance criteria.

## Next priority: measured checkpoint lag

Continue `dwm-634` / `dwm-634.3` with one bounded investigation before selecting
the next optimization. Run57 Day7 observed first reveal **1.368389 s**, full
manual save **3.802030 s**, terminal settlement **0.842601 s**, and cold Login
**9.018146 s**. These are synthetic retained-history observations on one shared
Windows runner, not cross-run speedups or physical input-to-paint guarantees.

Exact Day7 source/trace correlation is already complete: write-log lines
2050/2051/2052 bind `pre_board` preparation, checkpoint commit and
`first_reveal_durable`, between Day6 line1795 and Day7 line2105. The coordinator's
333.060 ms prepare plus 980.392 ms commit comprise **98.3317%** of its
1.335736 s elapsed time. Nested port timers overlap these parents; never add them
again. Document build costs 287.697 ms; outgoing normalization/schema 303.212 ms;
combined journal proof work 262.795 ms; fallback whole-document serialization
255.100 ms. On this event `journal_spliced=false`: `splice_us` names the fallback
serialization interval. Journal proof timing is not exclusively history proof
learning, and unassigned residuals must stay unassigned.

Next measure the subphases of document construction, outgoing validation and
journal proof work, including proof hits/misses and successful proof learning.
No safe proof omission or discarded work has yet been established in these
boundaries. Prefer a surgical removal of demonstrated redundant work over a new
cache or architectural change. Preserve strict validation, physical byte/revision
checks, consent, transaction order, complete-action recovery and all checkpoints.
Any speed claim needs a matched cloud comparison on identical retained saves,
with relevant correctness/refusal cases and unchanged output/retention proofs.

Start with:

- `scripts/application/run/SaveManagerCheckpointPort.gd`
- `scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd`
- `scripts/application/minesweeper/MinesweeperRoundCoordinator.gd`
- `tests/manual/benchmark_seven_day_history.gd`
- `tools/testing/Invoke-SevenDayHistoryPerformance.ps1`

The previous manual/Quick preparation change is already published: the eager
retained-history copy now runs only in the unconfigured fallback. Do not redo it.
Run57's eight alternating pairs retained all ten checked invariants and all 66
checkpoints: candidate faster 7/8, median paired reduction **13.122 ms**. Run56's
separate 8/8 and 25.388 ms result must not be substituted for Run57. This modest
improvement does not fix first reveal or establish overall latency acceptance.

## Parallel feature slice: ordered caption ledger

Inspect the Witnessed work under `dwm-vky.14` and its related caption/History
requirements. The first bounded slice is an **internal token-bound ordered
caption ledger**, exercised through one real, clearly non-canon Dialogic fixture
with two explicitly registered beats. Prove immutable identity/context, actual
publication order, idempotent duplicate publication, conflict and foreign-session
refusal, and detached snapshots. Do not derive identity from visible prose,
scrollback, DTL position or event indices.

Read `docs/design/current-ui/witnessed-scene.md` sections 3, 7–9 and 13.1–13.3,
plus `scripts/narrative/DialogicRuntimeAdapter.gd` and
`scripts/narrative/DialogicEntryManifest.gd`. Existing reply/Observer line
registration is not a complete narrative beat registry. This initial slice
leaves Profile visited state, canonical completion, save schemas and
History/Save/Next controls unchanged. Their later durable integration remains
required. Assign separate files to parallel agents; coordinate any shared save,
narrative, inventory or workflow edits through one integrator.

## Settled decisions and remaining inputs

- Legacy Gallery may provide clearly identified limited replay only where saved
  facts support it; otherwise preserve the achievement and mark exact replay
  unavailable. Never invent missing selectors/history or count limited playback
  as witnessing the missing exact original variant. Full selector/successor
  contracts and implementation remain open.
- Future dual-language rendering starts with captions and History. Menus remain
  single-language; implementation stays deferred. Both languages share one
  semantic leaf, receipt, History entry and advance boundary; Read Aloud uses
  Primary only.
- Clearly labelled non-canon dialogue fixtures are authorized. Production prose,
  narrative translations and final authored selectors/version cues remain
  unsettled; seek representative translated files when that adapter work begins.
- Keep strict Run/document v7 admission and Profile v9 chronology/history.
  Permission concerning old Run saves does not authorize erasing Profile history
  or unrelated slots.
- Dating already advances automatically into and out of its challenge. Do not
  reintroduce Continue/Done or special mines. Other settled UI choices are in
  `docs/design/current-ui/owner-ui-updates-2026-09-21.md`.

The two next engineering slices need no new owner design answer. Original
intermittent save failure and renderer-stall tasks still need diagnostic evidence
of the real fault; injected recovery tests or a clean rerun alone do not close
them. Native Windows Gallery ScrollPattern support remains recorded as an
upstream blocker; recheck actual support when resuming that task.

## Cloud validation and publication

Keep `.github/workflows/windows-tests.yml` on the committed/read-only inventory
gate and the intended matched performance mode. If source/test changes invalidate
inventory references, obtain new inventories in cloud, verify exact payload
bytes/hashes, commit them, restore read-only checking, and inspect that final
cut's own CI. A regeneration pass alone is not committed-inventory acceptance.
Retain full Git ancestry in Desktop and New Account CI: historical seal tests
require it. Use explicit commit-to-commit comparisons when auditing a shallow
local checkout; a shallow commit's apparent root diff can misrepresent scope.

Publish through the available GitHub connection to the existing PR branch;
verify exact blobs/tree and freshly checked parent before a non-force ref update.
Avoid overlapping source pushes that cancel the run being used for acceptance.
Distinguish source head, tested merge and later records-only commits in receipts.
Do not include account metadata, credentials or signed download URLs in evidence.
No merge, visibility change, new implementation or new test run belongs to this
handoff-only checkpoint.
