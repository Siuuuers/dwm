# Next-session handoff — 29 September 2026 (Hong Kong)

Continue public `Siuuuers/dwm` draft PR #1 on `codex/windows-cloud-ux`.
Verify the live branch, actual master ref and Beads first. Keep the PR draft:
do not merge, mark ready or change master. The last checked master was
`2e8602d5f098eebbab18241f370b5f4d14adf99b`; normalized PR-base fields may be stale.

## Current checkpoint

**Run71 is accepted for this bounded source increment.** [All 18 jobs passed](https://github.com/Siuuuers/dwm/actions/runs/36486629798).
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

This handoff follows D4 in a records-only commit: Beads, docs and evidence only.
It does not claim that a different records SHA was engine-tested. Inspect the live
diff before continuing, and retain source/run/merge distinctions.

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
**Remaining:** 238 current GameState rows include 131 mappings using 28 absent
test names; one identified `commit_variable_transaction` label is existence-only.
SaveManager's 74 current rows have no absent names, which is not exhaustive
behavior proof. Legacy API disposition still needs caller/current-authority review.
Do not mechanically substitute unrelated passing tests.
See the [exact mapping follow-up](2026-09-29-facade-contract-follow-up.md).

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

The prior editor workspace went offline. GitHub source reads, Git object creation
and cloud verification continued. If that workspace returns, inspect and reconcile
our exact staged changes; never reset or overwrite unrelated work.
The unavailable local aggregate verifier was not run; explicit cloud logs and
independent JSON/source checks support the retained receipts.

Linux rendered captures and Windows exported headless startup do not establish
native Windows graphics/accessibility or physical input-to-paint acceptance.
Reference hardware and a responsiveness target remain outstanding. Original
intermittent save/renderer faults need matching recurrence evidence.
Settings recovery still needs an explicit Profile reconciliation owner.
