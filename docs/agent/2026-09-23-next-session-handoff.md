# Next-session handoff — 29 September 2026 (Hong Kong)

Continue public `Siuuuers/dwm` draft PR #1 on `codex/windows-cloud-ux`.
Verify the live branch, actual master ref and Beads first. Keep the PR draft:
do not merge, mark ready or change master. The last checked master was
`2e8602d5f098eebbab18241f370b5f4d14adf99b`; normalized PR-base fields may be stale.

## Working guidance for the next session

These lessons guide the already-authorized work; they do not amend game behavior,
save compatibility, acceptance gates or the project's authority map. Aim for a
feature that is easy to explain, verify and resume. Keep one bounded outcome
moving through review and proof before starting another implementation.

1. **Define the outcome and failure before editing.** State the player-visible
   result (or protected guarantee), its current owner, the observed problem and
   how success will be checked. List the relevant failure modes: for a saved
   action, that may include a refused write, retry, interruption and restore.
   Use this small statement inside the existing task; do not create another
   planning system or try to enumerate hypothetical failures without limit.
2. **Simplify decisions and state ownership.** Prefer the existing canonical
   owner and a direct implementation over another manager, parallel state bag or
   speculative abstraction. Reuse an abstraction when actual repeated needs
   justify it. Before retirement, inspect real callers, current authority and
   persistence obligations; an unused saved field can still be a compatibility
   contract. Isolation copies and recovery checks have purposes that a shorter
   implementation must still satisfy.
3. **Complete inexpensive review before final cloud acceptance.** Audit callers,
   test bodies, ownership and provenance in parallel where independent. Combine
   compatible findings within the chosen scope, stabilize the candidate, then
   regenerate affected inventories once and run read-only acceptance against the
   exact source. Early diagnostic runs are useful when they answer a concrete
   uncertainty; avoid overlapping acceptance runs for a still-expanding batch.
   This session's three-label run was superseded by the larger coherent slice.
4. **Choose tests by the failure they expose.** Reuse meaningful existing checks.
   Use focused unit tests for isolated rules, integration tests for real owner,
   storage, retry and recovery boundaries, and rendered E2E journeys for connected
   player flows. A test name, helper invocation, green exit code or coverage count
   is insufficient proof. Start with affected suites; broaden only for a concrete
   interaction risk or required gate. Keep Godot and PowerShell cloud-only.
5. **Measure complete operations before optimizing.** Shorter code is not proof
   of less lag. Reproduce the pause, record the baseline and exact input, change
   one suspected cost, then compare matched complete-operation samples across
   relevant cold, mixed and warm states. Retain unfavorable results and independent
   correctness checks. Do not sum nested timers or equate a journal benchmark with
   player-perceived responsiveness. Preserve all fixture files needed for replay.
6. **Parallelize independent work with explicit ownership.** Assign disjoint edits
   or read-only questions to agents. Keep one integrator for shared owner files,
   publication and Beads records; use an independent reviewer for material risks.
   More agents are useful only while their work reduces uncertainty or elapsed
   time. Future CI parallelization must preserve identical source/input admission
   and isolated paired benchmarks; its speedup is not yet measured.
7. **Make continuity small and factual.** Verify the live head and selected issue,
   then read their relevant authority rather than reload all project history.
   Keep the accepted source, exact run, outcome, evidence limits, next bounded
   action and unresolved decisions in the existing handoff; link detailed proof.
   Do not reopen accepted work without new evidence. Consolidate navigation
   duplication without deleting historical evidence or changing its authority.
8. **Ask consequential questions and use a stopping rule.** Routine engineering
   remains delegated. Batch independent questions whose answers change player
   behavior, architecture, saved-data compatibility or authored narrative policy.
   Once the selected acceptance is satisfied, publish the verified increment and
   stop optional polishing. A broad parent remains open until all its acceptance
   is met. Start a fresh session at a durable checkpoint when the next slice needs
   different context; preserve the reading-rail questions below.

## Current checkpoint

The latest accepted bounded `dwm-sx8` increment is source
`d6896d7d6c00390b05b4c0cf59e17a37b2fc2419`
(tree `fac82dbe728dff43a3b3d570ab60cee9e95346df`). It repairs fifteen more
contract mappings and retires two unused, explicitly superseded queries.
See the [facade contract proof](2026-09-29-facade-contract-proof.md) for exact
mapping scope, authority and remaining work. [Run74](https://github.com/Siuuuers/dwm/actions/runs/36519455086)
passed all six selected jobs: **1,107 cases / 85 unique scripts, zero skips**.
Every actual checkout is the source above. The auxiliary workflow head is
`f7070d5998dadf8f6c1f5c531fc1f728f031fad4`; it differs only in the workflow,
which copies the original jobs with explicit source refs and a five-suite matrix.
This is exact-source focused acceptance, not a new PR-merge or full 18-job run.

The public gate verifies ten retired names over 925 source files with zero
references and reproduces both committed inventories without regeneration:
GameState `23d43604951254a65baa9c5fdcd2cf34b1399cce6dce6c1e16eda00cf91003b8`;
SaveManager `b3d04e0b66b29ee45b84151418db21cf280247759fdf3279ed1f476519f5ddef`.
Persistence passes all five restore and three active rollback cases. No test
case or predicate was dropped. The [Run74 receipt](../../evidence/beads_cloud_review/facade-contract-run74.json)
retains all per-script counts, checkout excerpts, log hashes, source bindings,
mapping deltas and replay instructions. Generation Run73 and the narrower
three-label Run72 are separate evidence, not substitutes for final acceptance.

This handoff follows that source in a records-only descendant. Only `dwm-sx8`
notes/timestamp change this session; its status remains in progress and the other
190 Beads records retain exact bytes. No fresh benchmark or rendered journey is
claimed. The next useful facade slice is a body/authority audit of the existing
relationship-policy, day-resolution and Schedule-preservation tests; they have
not been selected for new mappings here. Ask only if that review exposes a real
authority or ownership choice. Reading remains the separate owner-favorite slice
with the two unresolved questions below.

### Earlier broad runtime baseline

**Run71 is accepted for its earlier bounded source increment.** [All 18 jobs passed](https://github.com/Siuuuers/dwm/actions/runs/36486629798).
Accepted source: `d4b0fa924af2f83f0a77e9ab3f177c7f86b3e632`
(tree `e57e2c8148aba79643e09f00028ef03811c47bf7`).
Actual tested merge: `386adf3911a76e734baf951c758dc445c4d6e588`
(tree `941a208eeeb45d6c48e0187295187d9b12895411`), against the master above.
Source-to-merge differs in exactly seven owner Markdown files, with no runtime,
test, workflow or inventory difference. All 18 executed checkout logs bind that merge.

The 13 GUT groups passed 2,049 executions / 2,045 unique cases in 175 unique scripts,
zero skips. Four diagnostics cases deliberately execute twice. Standalone capture
checks passed 136 assertions; all five rendered journeys, exported Windows startup,
eight restore/rollback cases and eighteen ledger cases passed. All 66 retained
checkpoints survive fresh-process recovery.

The earlier `955e0bfb449eac0829388ee4ba0ff7e20938bcae` records commit follows D4
with Beads, docs and evidence only. The latest source increment above has separate
focused verification. Do not claim Run71 tested that later source or its records
descendant; retain source/run/merge distinctions.

The owner delegated testing and routine engineering choices and especially values
the reading rail. Continue unblocked work without routine permission questions.
Use focused behavior/integration checks for changed guarantees and rendered
end-to-end journeys for connected player flows; preserve existing useful tests.
Do not adopt a blanket E2E-only policy or add tests merely to improve a count.

The selected parents `dwm-634.3`, `dwm-sx8` and `dwm-vky.14` remain in progress.
Their bounded increments below do not fulfill all broader acceptance.
Beads has 191 records: 168 closed, 23 unfinished (11 in progress, five open,
six deferred, one blocked). Root alone updates selected records and preserves
unrelated JSONL bytes; this does not synchronize an inaccessible Dolt database.

Read `Prompt.md`, `CLAUDE.md`, `docs/agent/AGENT_WORKFLOW.md` and selected issue
authority before the next implementation. The wider backlog is mapped by the
[navigation-only continuation audit](2026-09-29-continuation-audit.md).

A measured workflow opportunity remains: Run70's retained-history lane spent about
49 minutes serially generating the payload and running independent comparisons.
After that producer, comparisons could run in parallel with the same source/payload
hash admission. This is a proposal, not an implemented or measured CI speedup;
preserve all gates and isolated matched pairs if taking that next increment.

## Checkpoint investigation

The original warm-proof change in `9ddc144` improved fully warm commits but
regressed cold/mixed commits. Run69 failed two fixture gates (16/18 jobs);
its completed benchmark remains valid bounded measurement, not source acceptance.
Run70 at `9958c66` passed all 18 jobs and independently repeated the tradeoff:
paired complete-commit medians were +73.8395 ms cold, +78.4525 ms mixed,
and −48.848 ms warm. These separate runs must not be pooled as matched samples.

The single correction reuses the detached snapshot already created by
`CheckpointJournal.remember_written_retained_bundle`, after ALL unchanged
retained-value, shape, kind, validation and strict numeric equality checks.
The port returns to its original detached history capture, removing the extra
whole-history comparison. Production input is StringName-normalized by the port;
do not invent a universal guarantee for arbitrary direct journal callers.
There is no new cache, lifetime, format, retention or storage-operation policy.

Run71 keeps the correction with an explicit small mixed-state tradeoff:

| Journal proof state | Median paired complete-commit delta |
|---|---:|
| Cold, 0/66 | −28.8505 ms (4/4 pairs faster) |
| Mixed, 51/66 | +2.5720 ms (3/4 pairs slower) |
| Warm, 66/66 | −48.7915 ms (4/4 pairs faster) |

The mixed deltas range from −1.221 to +4.476 ms on roughly 900 ms baseline commits.
This is a measured small regression, not a claim of zero regression or statistical
significance. Root and an independent reviewer recomputed every child median,
paired delta and all six summaries from 240 raw timings. Ten actual source hashes,
runtime reference bindings and all exactness invariants match. The roughly 49 ms
warm benefit supports keeping this bounded correction; no workload-weighted,
full-save or gameplay speedup is established.

The comparison uses four alternating pairs per proof state: 0/66, first 51/66,
and 66/66. Twenty-four isolated processes retain five samples per metric after
two warmups: 120 schema-composition timings and 120 complete-commit timings.
“Cold” describes journal proofs, not OS caches. Real journal/storage protocol
runs over FakeFileOps; public preparation, live capture, physical disk and
input-to-paint are excluded. Nested timers must not be summed.

The baseline freezes accepted port commit/splice AND journal learning methods
from `226d3da868784baacc6fc33f58823f95b5815a51`; it is not a wholly historical build.
Provenance verifies actual Git blobs, frozen methods and whole-source reconstruction
for port, schema and journal. Never weaken these guards after an adjacent edit.
Exact values/types/bytes, proof text/documents, journal state, file manifests and
ordered operations are required across variants.

Run68's region-search and Run66's lazy-normalization increments remain accepted;
do not redo them. The next manual-save storage-only success-witness idea is
**unmeasured**: first inspect its consumers and measure the existing boundary.
Do not implement it from guessed profiler attribution or claim broad lag closure.

Read-only follow-up found six full-result deep-copy sites across memoization and
storage validation/promotion, but their cost is unmeasured. The production
`_write_document_text_validator` caller ignores its success value and separately
verifies exact bytes/journal state; that alone does not authorize relaxing admission.
Any future ablation must keep matched physical inputs, cache/preparation state,
full-commit timing and refusal checks. Run71's retained replay input is the Day7
autosave only: its manual-save benchmark also needs the original `slot_1.json` and
exact saves-directory contents. Retain a fresh producer directory plus manifest
before claiming repeatable manual-save comparison; autosave alone is insufficient.

## Restore and public facade

Source `9958c66` adds five scoped deep-copy changes at restore capture,
dictionary/array silent installation, active capture and active rollback.
Five restore-participant and three active rollback cases cover both alias
directions with independent nested oracles, meaningful mutation, raw/wrapped
backups and existing publication behavior. Frozen controls reproduce the aliases
and reconstruct the exact historical whole GameState source.

Run69's restore script did not load because signal inspection was called on the
script class; using the actual owner's signal list fixes the fixture without
dropping predicates. Run70 executes all eight cases (persistence 183/183, no skips).

Two unused APIs are retired: `prepare_run_candidate` only copied a dictionary;
`commit_run_candidate` reported success without installation. Caller review
found no production consumer. Exact historical fragments remain in the hashed,
non-executable `tests/fixtures/source/game_state_retired_candidate_seams.json`.
No executable-test exemption weakens the eight-name retirement scan.

Reviewed mappings cover 15 existing behaviors, two active rollback helpers,
narrow `apply_save_dict` installation, and four earlier restore seams.
The latest bounded source repairs fifteen more mappings and removes two unused
queries: `get_minesweeper_safety_level` and
`should_warn_minesweeper_before_schedule_done`. The approved August11 amendment
explicitly supersedes both behaviors; executable caller review found no consumers.
Their exact historical source and old comment remain in a second hashed,
non-executable fragment artifact. Historical whole-file and four method hashes
remain unchanged, with unique-anchor reconstruction checks intact.

**Remaining:** 236 current GameState rows include 114 mappings using 28 absent
test names; one identified `commit_variable_transaction` label is existence-only.
SaveManager's 74 current rows have no absent names, which is not exhaustive
behavior proof. Legacy API disposition still needs caller/current-authority review.
Do not mechanically substitute unrelated passing tests.
See the [latest exact mappings and limits](2026-09-29-facade-contract-proof.md)
and [earlier mapping follow-up](2026-09-29-facade-contract-follow-up.md).

## Reading rail

The opt-in internal ledger transactionally reconstructs an ordered sequence
against independently admitted context, entry manifest and catalogue.
Ledger-owned publication IDs avoid restored collisions; retired callbacks cannot
append, and rejected suffixes/duplicates leave existing state intact.

The noncanonical mounted Dialogic fixture spans two entries and three beats.
Run69 exposed natural completion freeing its Witnessed host; `9958c66` explicitly
remounts and verifies the style/SubViewport and old-host release, preserving
the six-frame waits and publication assertions. Run70 passes nine unit and nine
mounted runtime cases (reading group 229/229, zero skips).

Production remains unconfigured. This does not complete canonical History,
Witnessed Save, exact-variant Next, Profile witnessing or story coverage.
The [next-slice proposal](2026-09-29-reading-rail-next-slice.md) scopes one English
Solo Dating session through automatic board handoff, History, Save and fresh Load.
It needs authored stable caption/signature identities, immutable per-entry frames
as post-board facts become available, and coordinated semantic-frontier restoration.

**Preserve existing Run7 loadability and all Profile history.** Earlier Run6→7
permission does not authorize rejecting Run7 now. Never invent missing captions.
Only ask architecture/content questions that remain unresolved:

1. Should older records show an explicit History gap followed by new captions
   (proposed default), or keep History unavailable until a new semantic session?
   Run7 loading stays supported either way.
2. Are there Solo Dating wording/staging selectors beyond the inspected
   friend/day/phase/tier/tone/attitude/due echoes and committed post-board
   result/perfect reason/relationship outcome?

Settled: one History per date; fresh Hospital; uninterrupted ordered-ending
History. Ordinary Next may include witnessed traversed beats; Hospital/ending
History uses actual publications only. Board handoffs remain automatic without
Continue/Done or special mines. Save finishes reveal without advancing; Load
restores a fully visible semantic beat without repeating TTS. History is inspect-only.
Legacy Gallery uses recorded facts or marks exact replay unavailable.
Future dual-language captions/History share one semantic leaf; speech uses Primary
and menus remain single-language. Test fixtures are authorized; production prose is unsettled.

## Evidence and environment

Current [Run71 receipt](../../evidence/beads_cloud_review/resumed-public-cloud-run71.json),
[raw matched samples](../../evidence/beads_cloud_review/performance/run71-warm-outgoing-proof.json),
[ordered phase trace](../../evidence/beads_cloud_review/performance/run71-checkpoint-trace.json),
and [replay instructions](../../evidence/beads_cloud_review/performance/README-warm-proof-replay.md)
are committed alongside this handoff. Exact synthetic Day7 inputs for Runs69–71
are retained byte-for-byte with extraction/source/hash receipts; replay does not
depend on the original seven-day Actions archive lifetime. Run71 input:
1,911,169 bytes, SHA256
`078cbf4095498420a8c117b5fa5bd55c8a6386c708fb980cb4158fec1e59bb00`.
The original rejected Run69/70 measurements and Run69 failure excerpts remain.

Run71's public gate verifies eight retired names across 925 source files with
zero references and both exact committed inventories, without regeneration:
GameState `36aa507ea3488f8de7cd7ef608571ac67d59b662695c28e0fe4672a52d870628`;
SaveManager `7ce9ab0c9080eaa7e88a681abdbf18714f6ab9d65c3e0a3dd85aa309d7d21525`.

Day7 observations still include about 3.699 s public manual save and 1.254 s first
reveal on this shared runner. They are not matched performance comparisons and
do not close the lag task. Preserve their inclusive phase boundaries.

Prior baseline: Run68 `36460570529`, source
`274bcff60e7bdba32c2fc4d6961ef51909f0d7a1`, merge
`c89aae5a022dee3262391e68126954f2e01085e7`: 18/18 jobs,
2,035 executions, 2,031 unique, no skips, all 66 checkpoints.
Source/merge differed only in seven owner Markdown files; story archives are not
approval of runtime narrative proposals.

Godot **4.6.3 standard GDScript** is authoritative. Execute Godot and PowerShell
only in GitHub cloud. Preserve full Git ancestry, coordinated Run/document v7 and
Profile v9 chronology, strict revisions/bytes/hashes, consent, complete-action
recovery and retained history. No unrelated slot or Profile-history deletion.

The prior editor workspace went offline. A fresh clone was restored for this
facade increment; static Python/source review works locally. Authenticated Git
object publication uses the connector; Godot and PowerShell remain cloud-only.
The earlier unavailable local aggregate verifier was not retrospectively run;
explicit cloud logs and independent JSON/source checks support the receipts.
Inspect any older restored checkout before reconciling it; preserve unrelated work.

Linux rendered captures and Windows exported headless startup do not establish
native Windows graphics/accessibility or physical input-to-paint acceptance.
Reference hardware and a responsiveness target remain outstanding. Original
intermittent save/renderer faults need matching recurrence evidence.
Settings recovery still needs an explicit Profile reconciliation owner.
