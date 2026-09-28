# Next-session handoff — updated 29 September 2026 (Hong Kong)

Continue public `Siuuuers/dwm` draft PR #1 on `codex/windows-cloud-ux`.
Read the live PR head and Beads before work. Keep the repository public and PR
draft; do not merge, mark ready, or change master. The actual master ref last
checked was `2e8602d5f098eebbab18241f370b5f4d14adf99b`. The owner has separately added story documentation;
this task did not move master. The connector's normalized PR base may be stale:
check the actual ref and bind every test to its executed merge and source.

## Current accepted source and next action

**Run66 is the latest fully accepted source baseline.**

- Run: <https://github.com/Siuuuers/dwm/actions/runs/36449012704>
- Source: `33ad80cc25c592153292e4e8544564877ac9d99e`
- Tested PR merge: `5c0d393da7808be8b9df1e4a5d4b6e0d1c84b8bb`
- Source tree: `974ab90a4d1f4f2c5320a16f6963424ba68606d3`
- Tested merge tree: `4e7dafd2814cc74c12ddc3292aacff5850adece0`
- All **18/18 jobs** passed; **2,028 GUT executions**, all passing, **zero skips**.
  There are **2,024 unique cases**; the four diagnostic cases intentionally run
  in both Settings and the isolated diagnostic job.
- Settings **288/288** plus storage-refusal checks; isolated diagnostics **10/10**
  (four checkpoint diagnostics and six normalization identity cases).
- All 17 internal caption-ledger cases, 136 standalone capture checks, five
  rendered journeys, rendered UI, and exported Windows headless startup passed.
- The source-to-merge comparison has seven Markdown differences only. Runtime,
  tests, workflow and inventories are identical. The owner's story archives do
  not approve their noncanonical proposals or runtime behavior.

Later evidence-only commits do not create a new tested runtime baseline. Never
reset newer work to an older accepted source. Continue with `dwm-634.3`'s measured
remaining checkpoint costs: use the Run66 phase trace to choose one bounded
experiment and compare identical retained payloads and proof states. The small
normalization improvement does not settle the larger save/first-reveal pauses.
No new architecture decision was required for this completed increment. Ask when
a proposed next change would alter save/recovery custody or another unsettled law.

## Accepted normalization change and its measurement limits

`SaveDocumentSchema._normalize_engine_text` and
`SaveManagerCheckpointPort._normalize_json_string_types` now allocate a result
container only when a child actually changes. They preserve unchanged identity,
StringName conversion, traversal/key order, numeric types and bits, source
immutability, changed **untyped** containers, and existing detachment boundaries.
The unchanged prefix is copied in original order; dictionary prefixes use an
ordinal, and recursive children are visited once. Do not replace this with typed
`duplicate()`/`slice()` results. No cache, validation omission, retention change,
save-format change or storage-operation change is part of this increment.

The benchmark freezes the exact eager helper bodies from Run63 source
`dae70bf9aa05b6b3debb60f95738e5ffc4e97548`. Source and function hashes are recorded
and verified. Four alternating pairs per full/splice mode use sixteen fresh cloud
processes on the same verified Day7 JSON with all 66 bundles. Each metric retains
five samples after two warmups; OS caches are not flushed.

Run66 median paired reductions:

| Measured scope | Full retained payload | Splice envelope |
|---|---:|---:|
| Direct schema helper | 8.399 ms | 0.247 ms |
| Direct port helper | 7.869 ms | 0.185 ms |
| Port helper plus current outgoing validator | 8.298 ms | 1.655 ms |

All sixteen processes preserve exact canonical output bytes, identity and all 66
checkpoints. Both seam variants use the SAME current strict outgoing validator.
Proof creation, envelope construction, canonical emission and equality checks are
outside timing. These are matched helper/seam measurements, **not** a matched
schema-build, complete physical save, gameplay or input-to-paint comparison.
Do not add nested timers or pool independent run medians as if they were one sample.

Run65 independently measured direct full-payload reductions of 8.198 ms and
7.753 ms, with both helpers faster in all four pairs. Its performance lane passed,
but the overall source was not accepted because one fixture test failed.
The older outgoing-normalization benchmark compares full versus splice with the
same helper on both sides; it cannot attribute a lazy-allocation gain.

Run66 synthetic Day7 observed first reveal **1.162124 s**,
complete manual save **3.258836 s**, terminal settlement
**0.739865 s**, and cold Login
**8.310559 s**. All **66 retained
checkpoints** survive (32 line, 32 manual-save, two semantic). These are workload
observations on one shared Windows runner; cross-run differences are not causal
speedup evidence or a latency acceptance threshold.

Version2 profiling separates document construction, normalization, validation,
composition and proof learning. The ordered trace has 204 records (190 checkpoint,
seven consequence, seven day), including 35 profiled autosave prepare/commit pairs.
Timers are nested and inclusive. Prepare stops proof lookup after the first miss:
its miss count is not a census of every missing proof. Never assign unexplained
residuals to a guessed cause. The earlier manual/Quick preparation optimization is
already published; its separate eight-pair comparison preserves ten physical,
candidate, journal and cache invariants. Do not redo it or conflate its gain with
normalization.

## Retained evidence and resolved test defects

- `evidence/beads_cloud_review/resumed-public-cloud-run66.json`
- `evidence/beads_cloud_review/performance/run66-lazy-normalization.json`
- `evidence/beads_cloud_review/performance/run66-checkpoint-trace.json`
- Equivalent Run65 receipt, raw pairs and ordered trace remain alongside them.
- `evidence/beads_cloud_review/run65-normalization-identity-red.log`
- Run63 and earlier accepted/partial receipts remain in git.

Run64 failed import because the port array return was indented inside its loop;
Godot rejected the empty-array path. Commit `1e7d266d5b8cc9d743150e78f7d82c7e459d840c`
dedented that return. Run65 passed 17 jobs but the isolated job passed only 9/10
cases (506/508 assertions): the literal-based signed-zero distinction failed for
both helpers while source-preservation checks passed. Run66 constructs negative
zero from explicit IEEE 754 bytes and verifies its sign before normalization and
its exact output bits. All prior predicates remain; the six identity cases pass.

Run62's separate diagnostics had exposed an absent `money` key inserted as
StringName. Explicit String indexing fixed the fixture; runtime validation still
rejects StringName gameplay keys. Run63 then passed 18 jobs, 2,022 executions,
Settings 288/288 and isolated diagnostics 4/4. Earlier Settings cancellation logs
were unavailable, so the internal mechanism of those historical 25-minute stalls
is not established. Do not claim the fixture evidence proves that mechanism.
The old storage-refusal driver has unbounded cleanup/output waits, but it is not a
proven cause. Neither timeouts nor test omissions were used to obtain acceptance.

The public inventories reproduce canonical bytes **without regeneration**:

- GameState SHA-256: `8c5e0a110fe05bc418894ba273ce7e3a72cfe60963535f227e17bd416ee0e08c`
- SaveManager SHA-256: `35921b0d7023421e2e81bcfc4642f026d31b318bc6287967f9119dc4ed81038e`

## Caption ledger and unsettled narrative integration

The opt-in internal ordered caption ledger has stable authored beat/line identity,
frozen detached fixture context, session binding, actual publication order,
idempotent duplicates and conflict/foreign-session refusal. A clearly noncanonical
Dialogic fixture exercises two registered beats. Nine unit and eight runtime cases
pass, including pause/replacement/end custody and split/missing-ID refusal.
Production use remains disabled. This does not establish durable canonical History,
witnessed Save, exact-variant Next, Profile witnessing or production story coverage.

Legacy Gallery may offer a clearly identified limited replay only from recorded
facts; otherwise preserve the achievement and mark exact replay unavailable. Never
invent missing selectors/history or count limited playback as witnessing a missing
exact variant. Selector/successor contracts and runtime integration remain open.
Future dual-language rendering starts with captions and History; menus remain
single-language. Both languages share one semantic leaf and History entry, and
Read Aloud uses Primary only. Implementation remains deferred.

Noncanonical test dialogue is authorized. Production prose and representative
translated narrative files remain owner inputs for later work. Dating already
advances into and out of its challenge; do not restore Continue/Done or special
mines. Other settled choices are in
`docs/design/current-ui/owner-ui-updates-2026-09-21.md`.

## Tracker, authority and workflow constraints

Beads: **191 records; 168 closed; 23 unfinished** (11 in progress, five open,
six deferred, one blocked). No task closes from this increment. `dwm-634`,
`dwm-634.3` and `dwm-vky.14` remain in progress. Root alone updates `.beads/issues.jsonl`;
if `bd` is unavailable, preserve unrelated records byte for byte and append accurate
evidence notes to only selected records.

Read `Prompt.md`, `CLAUDE.md`, `docs/agent/AGENT_WORKFLOW.md` and the selected issue's
linked requirements. **Godot 4.6.3 standard, GDScript** is authoritative; old
.NET/C# memory is stale. Run Godot and PowerShell only in GitHub cloud. Local source
inspection and static Python analysis are allowed. Temporary workspaces can revert
or expire; the freshly fetched published head and retained evidence are authoritative.

Preserve strict Run/document v7 and Profile v9 chronology, physical byte/revision
checks, consent, complete-action recovery and all retained history. Old Run-save
permission never authorizes deleting Profile history or unrelated slots. Keep both
public inventories committed and verify without regeneration; source-reference line
shifts must match the candidate. Preserve full Git ancestry for Desktop/New Account
seal tests. Verify exact blobs/tree and freshly checked parent before non-force
publication. Do not overlap pushes with a useful acceptance run. Distinguish source,
tested merge and subsequent records-only commits.

Original intermittent save failure and native renderer stall still need evidence of
the real fault; injected tests or a clean rerun alone cannot close them. Linux
software-rendered checks plus exported Windows headless startup do not establish
native Windows graphics/accessibility or physical input-to-paint acceptance. Recheck
the upstream ScrollPattern blocker when that task resumes. Reference Windows
hardware and a responsiveness target remain needed for broad latency acceptance.
