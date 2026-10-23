# Backup retention and current CI — qualified handoff, 23 October 2026

Continue on `codex/authored-week-followup-20261023`. No product design question blocks the next task. Keep Windows Godot 4.6.3 standard execution in cloud; local work is static inspection only.

## Accepted scope

Public `SaveManager.inspect_backup` now releases only the fresh private scene preparation that its synchronous metadata inspection created. Its token is never returned to callers. Selected Load and retry plans remain owned and unchanged. This fixes retained-plan growth; it does not claim a load-time improvement or fix other plan lifetimes.

Runtime commit `6dc50fb01d6dfb99bba2a5456a7c5fa5b559cdff`, tree `10f02b9e02aeec0633b24d58eb5630b667a8399a`, passed [run39958419154](https://github.com/Siuuuers/dwm/actions/runs/39958419154). Two inspection cases, eight Backup-host cases, eleven surface cases and the genuine ending native Load/Save case passed with clean exits. The same new regression test on the old source failed exactly its retention assertions, as intended. That negative control is not a passing product test.

Native Load phase: 551.636 seconds; Save phase: 443.431 seconds. These are whole helper phases, not isolated I/O timings. Existing saves and Gallery receipts were preserved. The genuine checkpoint-71, 61-receipt input root is retained in the preceding authored-followup evidence. This is stitched ending coverage, not uninterrupted full-week acceptance. The newly written output root was not archived as a new recovery fixture.

Test/CI commit `149c5cde96f021385fa3e9a1789362e3989b75b9`, tree `f8febce4a16552cf1a3ce239b02d9b7f0fd25c6e`, passed [run39960111488](https://github.com/Siuuuers/dwm/actions/runs/39960111488): 96 cases comprising 74 unchanged current mixed-file methods, 11 current scene journey cases and 11 public-surface contracts. Six suites now run current checkpoints, localization, Apps and Title. Paired create/load scripts run in separate processes sharing an isolated root; Apps took 49 seconds and Title 122 seconds, within existing CI limits. No runtime changed after the first qualification.

Twenty-seven retired method bodies remain traceable to pinned PR5 source with hashes in `tools/testing/canonical-test-disposition.json`; historical coverage is separated rather than counted as current acceptance. The new historical workflow is manual-only and was not rerun. See [CI reconciliation](a-canonical-ci-reconciliation-20261023.md).

## Evidence and visual inspection

Original archives, SHA-256/CRC inspections and authenticated source records are under `evidence/phase_2r/backup_ci_20261023`. The larger archive is split into four ordered byte ranges solely for transport; reconstruct before opening. Cloud-regenerated inventory bytes from the final CI candidate are adopted without manual coordinate edits. The records commit changes evidence/docs/inventories only.

Reviewed ending, Title, fresh-load story, fresh-load Shop and Japanese story screenshots. Japanese labels wrap heavily in the narrow sidebar; passing localization assertions are not a claim of polished typography. Other images remain available in the original archive. Empty runtime-diff files are omitted by artifact upload; final status lists inventory regeneration, checkout gitlink deletions and a generated UID, with no runtime edits.

## PR disposition and next observable outcome

PR42 and PR51 are ancestors of this continuation. PR43 is not an ancestor, but its authored-week DTL subtree matches the continuation; localized story assets are also present here. Earlier simplifications are already consolidated. Do not merge diagnostic controller PRs or merge old PR heads merely because they are mechanically mergeable.

Next outcome: the canonical Windows workflow selects supported current behavior, with every remaining legacy benchmark/rendered job explicitly assigned to its historical source or a reviewed current replacement. Start with `.github/workflows/windows-tests.yml` and the benchmark/rendered disposition in the CI reconciliation document. Review all related selections before one coherent cloud integration campaign and current Windows export. Preserve original historical assertions and current owner checks; do not enlarge timeouts or restore retired mechanics to force green.

Still open: broad benchmark/rendered reconciliation, complete current integration/export qualification, uninterrupted full-week coverage, and multi-minute authored Load/Save pauses. The draft candidate is not master acceptance or Steam release. Do not repeat the unchanged native ending test for records-only updates. Profile one complete operation before further performance surgery; retain receipt/Profile/issuer validation and avoid cross-call authority caches.

A fresh session is useful after this checkpoint because the next task is canonical workflow reconciliation, with runtime qualification and evidence custody already complete. It can start from this handoff without repeating these runs.
