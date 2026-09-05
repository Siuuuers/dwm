# Runtime UI integration readiness — 2026-09-05

The completed UI is ready for source packaging and integration review on its
existing base. It is not yet verified against the destination's unfinished v5
save/runtime changes. Checkpointing the UI now is useful; merging the combined
runtime requires a stable gameplay checkpoint and compatibility verification.

This assessment is tracked by **dwm-opf**. The next bounded task is **dwm-9fk**,
packaging the verified runtime UI into a reviewable Git checkpoint. No code,
player storage, Git refs, commits, or destination files were changed by this
assessment. Its evidence files and these two Beads records are the only intended
writes; the normal Beads CLI may update its local export.

## Observed state

[inventory.json](inventory.json) records exact paths, sizes and SHA-256 hashes.
Both worktrees have HEAD and merge base
`1790785bcfd37d2a27a0ecef81b9dc80fe501f71`:

- UI: `temp-artifacts/worktrees/contacts-ui-build`, detached, 194 changed files
  (25 tracked modifications and 169 untracked files), approximately 40.9 MB.
- Destination: `C:/Users/glori/Documents/dwm-p2r13-resealed`, branch
  `codex/dwm-p2r13-resealed`, 36 changed files.
- Three changed paths overlap and all differ: `autoload/ApplicationBootstrap.gd`,
  `autoload/GameState.gd`, and `scripts/infrastructure/save/SaveDocumentSchema.gd`.

The census includes historical evidence and runner receipts and excludes this
assessment directory. It is not a commit allowlist or a merge simulation. Shared
runtime contracts can conflict across different paths as well as overlapping
files. Root's separate `docs/recover-design-brain` lineage is not a substitute
integration base; the historical UI-00 chain must not be accidentally absorbed.

A final [stability check](stability.json) found the UI inventory unchanged but
destination `scripts/domain/desktop/DesktopContinuationRemapper.gd` changed
during this assessment. The destination hashes are a time-bound census, not an
atomic frozen snapshot. This is direct evidence of ongoing destination work;
refresh from its owner's stable checkpoint before composition.

## Current verification

[verification.json](verification.json) independently rechecks all latest title
milestone source bindings and retained receipt/log hashes:

| Receipt | Recorded checks | Current source bindings |
|---|---:|---:|
| Title shell | 326 | 34/34 |
| Production two-process restart | 103 | 2403/2403 |
| Backup UI | 3870 | 55/55 |
| Routine clock | PASS, no numeric count | 3/3 |

Every inspected receipt reports pass, every listed source binding matches, and
all receipt/log hashes match the consolidated milestone record. Tests were not
rerun for this read-only source assessment. These are evidence for the existing
UI tree, not combined v5 runtime acceptance. Earlier milestone receipts remain
historical where their source bindings have changed.

## Actual integration prerequisites

Independent source review found these concrete seams:

1. Destination v5 snapshot requirements include `schedule_view` and additional
   lifecycle fields. Its `ApplicationBootstrap._configure_schedule_view_participant`
   currently returns `not_implemented`, and `GameState.capture_run_snapshot_input`
   omits `schedule_view`. Wait for a coherent, tested checkpoint of that owner
   work before attempting production composition.
2. UI `SaveManager._inspect_backup` validates the original document
   against the current schema before migration. If the schema simply becomes
   v5, legitimate v4 UI saves can be refused before reaching migration. Reconcile
   version-aware original-envelope validation with migration, retaining wrong
   locator, false timestamp, malformed record and future-version protections.
3. Preserve UI `saved_time` metadata and `manual_save` checkpoint vocabulary.
   Destination `SaveMigrations.migrate_document` reconstructs the outer document
   without `saved_time`. Eligible migration must preserve a truthful frozen time;
   missing legacy time must remain unknown. Do not invent metadata to pass a gate.
4. Verify the exact combined candidate: focused schema/migration/restore tests,
   a genuine prior-v4 save, malformed/future/wrong-locator refusals, and real
   New Acc → Save → cold Log in → restored scene behavior. Retain UI navigation,
   confirmation and recovery regressions. A clean textual merge is insufficient.

The existing full-loop evidence does not establish journal rollback after every
late-finalizer failure. This assessment does not expand that claim. Headless
tests also do not certify GPU appearance or physical assistive technology.

## Beads relationship and merge timing

| Bead | Live status at inspection | Relevance |
|---|---|---|
| dwm-dro | closed | Isolated Contacts component only; no later runtime integration implied. |
| dwm-4yv / dwm-4yv.1 | in_progress | Historical authority readiness/recovery; different deliverables from runtime UI. |
| dwm-oyo.3 | in_progress | Destination gameplay and save/runtime owner work; obtain the relevant stable checkpoint. |
| dwm-pxy | in_progress | Combined save-contract and compatibility characterization; relevant coordination record, not proof that this UI lineage is already covered. |
| dwm-9zg | closed | Audio/gameplay readiness audit; explicitly leaves runtime integration prerequisites open. |
| dwm-opf | assessment task | This report and source/evidence census. |
| dwm-9fk | open | Next: reviewed UI source checkpoint and exact commit manifest. |

Bead closure records satisfaction of that task's acceptance criteria. It does not
automatically authorize or validate a merge. A local checkpoint can precede
integration; tasks whose scope includes integration should close only after the
integration checks pass. The previous UI milestones were not durably represented
as separate closed Beads beyond dwm-dro; this report does not retroactively mark
them or UI-00/UI-00R complete.

The user's later direction permits a simpler runtime UI path without recreating
the historical UI-00R grant machinery. Keep historical records truthful; do not
pretend their projector/census/cutover requirements were satisfied by UI code.
Neither all remaining apps nor every OYO3 subtask must finish first: the actual
requirement is a stable relevant save/runtime unit and a green combined candidate.

## Minimum sequence

1. Package the existing verified UI on its current base using an exact reviewed
   source/evidence manifest. Keep fonts and license notices together. Preserve
   reproducible tests and useful evidence; exclude caches and disposable copies.
   Do not manufacture independent commits that cannot build merely to make a
   large accumulated change appear smaller. Establish self-contained boundaries
   from actual dependencies and validate them.
2. Obtain immutable gameplay and save-contract checkpoints from their owners.
   Refresh this census; these dirty snapshots are not integration inputs.
3. Compose in a separate clean candidate, reconcile the save/restore seams above,
   review the combined diff and run relevant combined-runtime tests.
4. Merge the reviewed green candidate into the agreed destination while
   preserving unrelated work. Record commits and evidence in corresponding Beads.

After that integration milestone, app hosting and visual completion can continue
in smaller slices. Dark entitlement, New Acc replacement policy, missing artwork,
unfinished app adapters and the larger Settings redesign remain separate scope.

## Independent review

The `integration_review` agent independently inspected the two source trees and
milestone evidence without editing them or rerunning suites. It identified the
v5 producer/wiring, pre-migration validation and timestamp preservation issues
above, and recommended checkpointing UI before composing with a coherent v5
runtime. The parent inspected the cited source seams and independently verified
the path inventory and latest evidence hashes. No combined-runtime pass or
actual merge is claimed.

The reviewer also read this final report, including the destination movement
qualification, and found no material correction necessary.
