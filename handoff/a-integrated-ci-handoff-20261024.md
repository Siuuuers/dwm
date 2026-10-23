# Integrated game and CI handoff — 2026-10-24 (Hong Kong)

## Publication and acceptance

PR #52 merged as `5e3f1e0bb3ac251e88ea8a7b87c5a0616e3f7d5a`, tree `edbb28ef90f0e111e325e898be98e0464a8c153f`. Composed acceptance passed: **22 primary suites, 2,739 executed cases and 154,403 assertions, zero failures/errors/skips**. Exported startup and rendered desktop/Gallery checks also passed. Settings adds its separately recorded storage-refusal and 61,180-assertion manual checks. This handoff and its evidence are documentation-only descendants of that merge.

The game/tool source was qualified at `3e016116ecac40ea5ce8186332261927a4959d16`. CI checked GitHub merge preview `0646d42ef054318c18863fee087c19b3efdad476`; both have tree `2321e4bc8ab0157101275e0a491aaac20bc1ee0e`. That run passed 25 jobs; Settings failed because two Quick Backup test doubles retained a three-argument override after the parent gained an optional fourth argument. Source `69cca3f965e065c708eac87b5723d744e2be7787` fixes only those two signature lines, preserving every test body and all game/tool bytes. Full Settings plus a no-regeneration inventory check passed separately in [run39993602893](https://github.com/Siuuuers/dwm/actions/runs/39993602893). This is scoped acceptance across two runs, not a claim that all 26 jobs passed in one run. The [main run](https://github.com/Siuuuers/dwm/actions/runs/39992202440) retains the original failure as well as its 25 passing jobs. Native inventories were generated on the combined source in run39991657937 and checked without regeneration by canonical CI and the fixture-only replacement run. Diagnostic workflow controllers are excluded from product source. Master advanced again to `7d64dd644a466292d42d3446e16558d963dc2b89` during qualification. Its only changes were Steam workflow/documentation updates. Both files were preserved exactly; the reviewed merge preview differs from the qualified fixture source only in those two files. This task does not claim to validate those separate Steam packaging changes.

## What changed

The authored scene game, current Title/desktop apps, ordinary board first-reveal, scene checkpoints, Backup, localization and ending journeys are integrated. Hidden Backup inspection is deferred until preview, while actual activation/reopening and actions still refresh. SaveManager now reuses detached scene admission results only while document and selected bundle remain exactly equal; legacy, recovery and drift retain generic validation.

Current test fixtures own their synthetic catalogue registration. Legacy historical cases remain preserved; current automatic coverage selects current contracts. GUT emits test/failure output instead of every passing assertion, reducing the matched Settings log by 99.75% with identical case outcomes. Broad current-owner hash reconstruction and its orphan updater were removed; frozen controls and mutation probes remain. No runtime legacy fallback or global proof cache was introduced.

## Evidence and limits

- Matched native Load 543.463→397.535s; Save 363.538→246.436s. Same 40-file authentic input and 4 helper hashes, 112 assertions. One matched pair supports this workload improvement, not a universal speed guarantee. Original archives and detailed summaries live in `evidence/phase_2r/current_ci_20261023/`.
- Current Settings: 366 primary cases/21,934 assertions; 61,180 additional manual storage assertions; both expected invalid-root refusal censuses; 3 rendered captures. Current ordinary first-reveal creator/loader: 2 cases/143 assertions. This does not recreate the retired legacy post-checkpoint/pre-live-adoption crash matrix.
- Earlier uninterrupted default authored week: 836 captions, 835 transitions, 7615 assertions, durable completion, exactly 1 Gallery receipt, return to Title. Runtime source 0493 predates seed reuse; do not call it a final-source uninterrupted rerun. Worst recorded transition 216.631s entering Day7.A.001.
- No claim of every possible player branch, Steam installation, public release, production Notes activation, Schedule deletion, legacy migration or smooth performance. Steam export/upload is a separate workflow and was not executed by this task.

## Resume with one observable outcome

Reduce the player-visible pause for the authentic ending-state Load while preserving the selected board/story state and transaction ownership. Start with the retained native source slot and helper. Map repeated 36–42s slot inspections to actual callers, input revision and custody boundaries, then inspect the 127.368s restore-commit scope. Repetition is proven; safe redundancy is not. If source inspection cannot resolve it, add narrowly scoped attribution for one matched run before changing behavior.

Keep exactly one owner for each important fact. Do not remove freshness checks, copies or validation simply because they are expensive. Compare complete Load/Save and visible readiness; nested timings overlap and must not be added. Use the smallest tests that exercise changed ownership/failure cases, then the connected native journey. All Godot execution stays on cloud runners.

## PR and branch preservation

Thirty older proposals were reconciled: 29 status-only closures and #42 already closed automatically by ancestry. #1 also closed automatically when #52 merged; its protected branch remains intact and was not explicitly closed. #14, #30 and #50 remain open. Every branch was preserved, including historical #38/#43 records. Exact actions and observed final states are in `evidence/phase_2r/current_ci_20261023/run39992202440/final-pr-reconciliation.json`. These are incorporated/superseded proposals, not 29 new source merges.

Exact historical proposal heads, missing historical record paths and protected branches are recorded in `evidence/phase_2r/current_ci_20261023/pr-reconciliation-provenance.json`. Preserve all branches, especially coordination/archive #1/#14, diagnostic #30/#50 and historical #38/#43/build references. Do not reapply old source implementations over current owners.

## Session boundary

This is a useful fresh-session boundary: the large integration and CI repair work is closed, evidence is durable, and the next task is one measured performance investigation. No unresolved design question currently requires a user answer. Check current master and open PR state before starting; another session may independently change Steam packaging.

## Durable final reports

- [Primary summary](../evidence/phase_2r/current_ci_20261023/run39992202440/final-primary-summary.json) and [exact JUnit bundle](../evidence/phase_2r/current_ci_20261023/run39992202440/final-primary-junit.zip).
- [Export/render/public-surface summary](../evidence/phase_2r/current_ci_20261023/run39992202440/final-four-job-qualification.json) and [exact report bundle](../evidence/phase_2r/current_ci_20261023/run39992202440/final-auxiliary-reports.zip).
- [Residual performance analysis](../evidence/phase_2r/current_ci_20261023/run39992202440/residual-performance-note.md).

The primary bundle deliberately includes the excluded failed Settings XML with its classification, alongside accepted results. Do not sum that failed attempt into the passing census. Original artifact SHA-256, extracted-member hashes and source/controller provenance are retained in the bundles.
