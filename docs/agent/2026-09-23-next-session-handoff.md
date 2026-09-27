# Next-session handoff — updated 27 September 2026 (Hong Kong)

Continue public `Siuuuers/dwm` draft PR #1 on `codex/windows-cloud-ux`.
Fetch the live PR head and Beads before work. Keep master unchanged; do not merge,
change visibility, or mark the PR ready. Live master is now
`538b61ba96457eb5448053c8b0897b4fcbaa464a` after the owner's separate story PR #2;
this task did not move it. The normalized PR base field still reports the older
`9e43b52c9884ccd59e82245d2168c3113ee4d037`; check the actual master ref.

## Immediate state and next action

The current cut adds a separate **checkpoint_diagnostics** cloud job containing
the four new diagnostic tests. The same tests remain in Settings, with all
timeouts and runtime code unchanged. Resume its cloud result before another
source batch: an isolated failure implicates the fixture, while an isolated pass
with a Settings failure points toward the surrounding suite or its runner path.
This diagnostic duplication adds four executions, not four unique tests.

Run61 <https://github.com/Siuuuers/dwm/actions/runs/36260578366> tested source
`8ceca91cd5b084c04b5a1c34db82d3cdccd53396` as merge
`efbeec18006c5397ed2427a09849b65bb349c430`: **16 successful jobs and one cancelled
Settings job**, again without an available Settings log. The assertion-formatting
experiment did not resolve the stall. It retained the same predicates: six
assertions now use the same native equality predicate without GUT's unconditional
full dictionary/array diff and byte formatting. Five success messages print stage
and code instead of complete result trees. All four tests, 55 assertion sites and
198 lines remain. This removes demonstrated unnecessary work, but the Settings
stall's cause is **not established**. Do not call it fixed without executed proof.
The Run61 merge differs from its source only in five Markdown files introduced
by story PR #2; runtime, tests, workflow and inventory bytes are identical.
That story work does not authorize its noncanonical scene/intimacy proposals.

The previous source is `d3647767fc058185fcc893d469b54e707f660102`, tested as merge
`843036fcf10e6490e44f933ac8ecbb3f83b3744e`. Run60
<https://github.com/Siuuuers/dwm/actions/runs/35822448296> finished with **16 successful
jobs and one cancelled Settings job**. Its Settings log remains unavailable
(BlobNotFound/404), including after terminal cancellation. It stayed in progress
beyond the configured isolated 480 seconds, step 10 minutes and job 20 minutes;
elapsed status alone does not diagnose a runner fault or test deadlock. Run59
had the same unresolved Settings symptom. Run58 failed import on inferred `proven`
type; the published explicit bool annotation repaired that import error.

Run60 passed committed **read-only** inventory verification, 11 drift/no-write
regressions, all 17 new caption-ledger tests, the other reported GUT tests, 136
standalone capture checks, five rendered journeys, rendered UI checks, exported
Windows headless startup and both performance lanes. **1,730 GUT executions were
reported, all passing with zero skips; Settings contributes no accepted count.**
Do not substitute the expected full count of 2,018 for observed results.

Retained current evidence:

- `evidence/beads_cloud_review/resumed-public-cloud-run60.json`
- `evidence/beads_cloud_review/performance/run60-checkpoint-trace.json`
- `evidence/phase_2r/runtime/game_state_surface.json`
- `evidence/phase_2r/runtime/save_manager_surface.json`

**Run57 remains the last fully accepted source baseline**, with 17/17 jobs,
1,997 GUT executions and zero skips. Its source is
`cc42b9e4c4f0c5c736fef625c0be6b1fa0855f00`, tested merge
`efcc6d210896389641a270c0c2ee9e0e5074404c`; receipt and ordered trace remain in git.
Newer work must not be reset to that older baseline.

## Completed implementation slices, pending full acceptance

Opt-in checkpoint diagnostics version 2 separate document construction,
outgoing normalization/validation and journal proof work. They count proof hits,
misses, attempted and successful learning without changing validation, storage
operations, transaction order, save formats or checkpoint retention. Four focused
regressions compare profiling on/off, cold/warm proofs, edited-history learning
refusal and journal-commit refusal; Settings acceptance remains outstanding.

The opt-in internal ordered caption ledger has explicit authored beat/line
identities, frozen detached fixture context, session binding, actual publication
order, idempotent duplicates and conflict/foreign-session refusal. One real,
clearly non-canon Dialogic fixture exercises two registered beats. Its 9 unit and
8 runtime tests passed in Runs59,60 and61. Publication capture follows actual text
publication; pause/replacement/end custody and split/missing-ID refusal are tested.
This is **not** durable canonical History, witnessed Save, exact-variant Next,
Profile witnessing or production narrative coverage. Production use is not enabled.

## Measured lag and next bounded experiment

Run60 synthetic Day7 observed first reveal **1.380864 s**, manual save
**3.863498 s**, terminal settlement **0.883418 s** and cold Login **9.258772 s**.
All **66 retained checkpoints** survive. These are shared-runner workload
observations, not matched cross-run speedups or input-to-paint guarantees.

The version2 trace now exposes the cost of journal primitive validation,
engine-text normalization, composition and exact proof learning. Run59's audited
Day7 first reveal had 51 proof hits and 15 missing proofs, all 15 successfully
learned. Prepare stops lookup after its first miss, so its one recorded miss is
not a census of all missing proofs. Nested inclusive timers overlap: never add a
parent and its children or assign unexplained residuals to a guessed cause.

A source review found temporary Array/Dictionary containers built and discarded
on unchanged branches in `SaveDocumentSchema._normalize_engine_text` and
`SaveManagerCheckpointPort._normalize_json_string_types`. The measured scopes
justify a **bounded lazy-allocation experiment**, after Settings is resolved.
Preserve traversal/key order, StringName conversion, numeric types, unchanged
identity, changed untyped arrays, final detachment and refusal ordering. Compare
against the current eager implementation on identical retained payloads and proof
states with alternating cloud samples; verify bytes, physical operations, proof
counts and all retention guarantees. No cache, validation omission or history
compaction belongs in this candidate. No new runtime optimization is implemented.

The earlier manual/Quick preparation optimization is already published; do not
redo it. Run60's eight alternating pairs preserve all ten candidate/file/journal/
cache invariants and 66 checkpoints; median paired prepare reduction is 26.974 ms.
That comparison concerns the older preparation change, not the new diagnostics.

## Tracker, authority and constraints

Beads: **191 records; 168 closed; 23 unfinished** (11 in progress, five open,
six deferred, one blocked). No task closes from these bounded slices.
`dwm-634`, `dwm-634.3` and `dwm-vky.14` remain in progress. Root alone updates
`.beads/issues.jsonl`; if `bd` is unavailable, preserve unrelated records byte for
byte and append accurate evidence notes to only the selected records.

Read `Prompt.md`, `CLAUDE.md`, `docs/agent/AGENT_WORKFLOW.md` and the selected
issue's linked requirements. **Godot4.6.3 standard, GDScript** is authoritative;
older .NET/C# memory is stale. Execute Godot and PowerShell only in GitHub cloud.
Local source inspection and static Python analysis are allowed. Temporary local
checkouts can expire; published source and retained evidence are authoritative.

Preserve strict Run/document v7 and Profile v9 chronology, physical byte/revision
checks, consent, complete-action recovery and history. Old Run-save permission
never authorizes erasing Profile history or unrelated slots. Keep both public
inventories committed and check without regeneration; this test-only edit keeps
all six inventory reference locations unchanged, but its own cloud gate must
confirm exact bytes. Keep full Git ancestry for Desktop/New Account seal tests.
Verify exact blobs/tree and freshly checked parent before non-force publication.
Do not overlap pushes with a useful acceptance run. Distinguish source, tested
merge and later records-only commits.

## Settled design and remaining inputs

Neither current slice needs a new owner answer. Legacy Gallery may offer clearly
identified limited replay only from recorded facts; never invent missing exact
selectors/history or count it as witnessing the missing variant. Exact Gallery
selector/successor contracts remain open. Future dual-language rendering begins
with captions and History; menus stay single-language, semantic identity is shared
and Read Aloud uses Primary only. Implementation remains deferred.

Non-canon test dialogue is authorized; production prose and representative
translated narrative files remain owner inputs for later work. Dating already
advances into/out of its challenge; do not restore Continue/Done or special mines.
Other settled UI choices are in `docs/design/current-ui/owner-ui-updates-2026-09-21.md`.
Original intermittent save failure and renderer stall require evidence of the real
fault; injected tests or a clean rerun alone do not close them. Linux rendered
checks and Windows exported headless startup do not establish full native Windows
graphics/accessibility acceptance. Recheck the recorded upstream ScrollPattern
blocker when that task resumes. Reference Windows hardware and a responsiveness
target are still needed for broad latency acceptance.
