# Current qualification checkpoint — 2026-10-24 (Hong Kong)

Status: final composed acceptance pending. This record does not claim a master merge.

## Final composition

Source `1ca4b17e49dd487fd57aa80b4a8d7fb3b2c17d1e` combines PR52, current Settings fixtures and first-reveal selection, measured scene seed reuse, and master `894a9f2f2df65b5b87b0562ea1a2e7bc5fb5b1ef`. The two concurrent Steam files are preserved byte-for-byte. Steam export/upload is a separate workflow; this task neither dispatches nor claims it.

The player outcome is unchanged durable Save/Load behavior with less repeated validation and no hidden Backup inspection before its first preview. SaveDocumentSchema owns admission; SaveManager consumes call-local detached proof only while the document and selected bundle remain exactly equal. Drift, legacy admission and recovery retain generic validation. There is no global proof cache. Hidden previews, actual opening/reopening, and action execution retain their respective freshness checks.

## Completed verification

- Settings [39989387087](https://github.com/Siuuuers/dwm/actions/runs/39989387087): 366 primary cases, 21,934 assertions, no failures/skips. Each invalid-root mode reports 80 expected refusals plus three storage-free passes and unchanged repository snapshots. Manual storage checks: 61,180 assertions. Three rendered Settings captures passed.
- Current ordinary-board first-reveal in the same run: two separate creator/loader processes, two cases, 143 assertions. Durable paid board, selected Load on a different branch, no extra round charge or history replay. This does not reproduce the retired legacy post-checkpoint/pre-live-adoption crash injection.
- Seed reuse [39988834004](https://github.com/Siuuuers/dwm/actions/runs/39988834004): 66 focused/public cases, 2188 assertions, then the matched native ending Save/Load journey, one case and 112 assertions. The matched complete Load phase fell from 543.462862s to 397.534697s (26.85%); Save fell from 363.537523s to 246.436326s (32.21%). Boot fell from 67.238331s to 60.130351s. These are one matched pair, not a statistical guarantee. Complete-operation provenance is retained separately.
- Earlier full run [39978867976](https://github.com/Siuuuers/dwm/actions/runs/39978867976): 20 primary suites/2366 cases passed. Its Settings cancellation and renderer failure are not represented as success; both were subsequently resolved in scoped checks. Final composed CI remains required.
- Visual recheck [39981619080](https://github.com/Siuuuers/dwm/actions/runs/39981619080): all 133 captures passed after correcting a pixel probe boundary; no runtime change.
- Uninterrupted default authored week [39973922887](https://github.com/Siuuuers/dwm/actions/runs/39973922887): 836 captions, 835 transitions, 7615 assertions, durable completion, one Gallery receipt and return to Title. This precedes seed reuse and is not a final-source uninterrupted rerun. It proves one authored path, not every branch.

## Minimal verification changes

GUT logging changed from all passing assertions to test/failure output. Matched Settings runs retained exactly the same 369 case results, 22,009 assertions and eight identified failures while reducing logs from 23,187,074 to 57,879 bytes. This proves quieter equivalent diagnostics, not the cause of earlier runner stalls.

Those eight failures were stale fixtures: existing scene-validation scopes now isolate retained catalogues, Reset uses a current line ID, and four compatible first-reveal adapter cases are selected without the three retired motivation/schema cases. The original seven-case legacy file remains byte-preserved. Current transactional first-reveal coverage is selected as a separate creator/loader pair. No production legacy fallback was added.

Canonical CI selects 22 primary regression suites plus exported startup, public surfaces and two rendered jobs. Historical benchmark and superseded story jobs remain on their pinned sources. The frozen four method hashes and behavioral alias probes remain; the broad current-owner hash reconstruction and orphan tool were removed. Public inventories must come from cloud Godot regeneration, never hand edits.

## Remaining limits and next work

Multi-minute authored and Save/Load pauses remain. The earlier uninterrupted path took 45m55.8s with a 216.631s worst transition. Single matched cloud timing pairs are not statistical guarantees or smooth-gameplay acceptance. Next optimization should start from one reproducible long transition and compare the whole operation; avoid removing copies or validation without understanding their ownership.

Do not infer production Notes activation, Schedule removal, legacy save migration, every-branch acceptance, Steam installation or release acceptance. No new architecture decision is currently blocked on a user answer.

## Merge disposition

After final composed CI passes, merge PR52 preserving history, then refresh older PR state. Exact ancestors require no repeated code merge. Divergent incorporated proposals can be reconciled as superseded; preserve the pinned historical records from PR38/43 and all protected references. Diagnostic PR30/50 stay separate. Detailed exact heads and retained paths are in `evidence/phase_2r/current_ci_20261023/pr-reconciliation-provenance.json` and its Markdown companion. Status changes must be recorded only after they actually happen.
