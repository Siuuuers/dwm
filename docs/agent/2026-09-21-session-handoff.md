# Session handoff — 21 September 2026

The user is pausing for sleep and has requested that the repository become private again. Preserve this checkpoint before further development. Do not merge PR #1 or start another broad change during this pause.

## Resume location and authority

- Repository: `Siuuuers/dwm`; draft PR: https://github.com/Siuuuers/dwm/pull/1
- Working branch: `codex/windows-cloud-ux`. Read its **current remote head**, this handoff, `Prompt.md`, `CLAUDE.md`, `bd prime`, and relevant Beads records before editing. This handoff supplements, not replaces, specification authority.
- Last executed head: `17c31be1014f70592b06a76c23a48a965e310384`; run47 tested PR merge `dba429ba7432642e253e218e2095eaec799e43fa`, whose other parent is master `9e43b52c9884ccd59e82245d2168c3113ee4d037`.
- The commit containing this handoff adds **reviewed but runtime-unverified** repairs on top of that head. Its commit message uses `[skip ci]` to save the sleep checkpoint without starting another automatic run. This is not test acceptance. Resume with a cloud workflow dispatch on the branch, or a subsequent normal commit, then verify the exact tested head/merge SHA.
- Godot **4.6.3 standard GDScript** and all Godot/PowerShell execution belong in GitHub Actions only. Local source review, Python/static checks are allowed. Do not run the game or PowerShell locally.
- The former local checkout was partial and based on an old commit. It was published through deliberate GitHub tree/commit/ref snapshots, never `git push`. Use a fresh complete checkout or the same exact-base API workflow. Never push that partial checkout.

## User decisions that remain in force

- Old Run saves may be refused/discarded; preserve Profile history. Current Run/document schema remains **v6**, Profile remains **v9**. Strict v7 cutover is pending.
- Dating goes from pre-DTL to its board to the matching post-DTL automatically. No starting/ending Continue or Done popup, and no special mine.
- Observer interactions are retired from the current game and preserved on `archive/observer-interactions-2026-09-21`. Observer endings do not require interaction receipts.
- Continue the Beads and lag work with scoped changes, explicit assumptions, actual automated evidence, and the supplied Karpathy Guidelines. Do not fabricate missing historical presentation contexts or weaken checks to make them pass.
- Keep the repository private once restored; do not change visibility or spending to obtain tests without user authorization. PR #1 remains draft; no merge requested.

## Run47: what actually executed

Run: https://github.com/Siuuuers/dwm/actions/runs/35642962190

**14 of 17 jobs passed; 3 failed.** All jobs completed. Machine-readable job IDs and results are in `evidence/beads_cloud_review/resumed-public-cloud-run47.json`.

- Ten focused scopes passed **1,536 tests across 140 scripts**: desktop, persistence, endings, settings, dating, new_account, audio, minesweeper, shop, localization.
- Public surface generation/validation passed: 240 GameState and 74 SaveManager records, zero inventory errors; six retired symbols had zero references across 902 scanned files.
- Rendered desktop/dialogue passed, including 133 previews, startup/Logout captures, and UI literal audit.
- Seven-day retained history and paired checkpoint performance passed. All 66 retained checkpoints survived (32 line, 32 manual, 2 semantic). Complete inspectable performance receipts are in `evidence/beads_cloud_review/performance/retained-history-run47.json`.
- `reading_delivery` passed 207/210 tests in 16 scripts; three fixture tests failed.
- Rendered full journeys passed 3/5: Dating reload and both Practice journeys. The two full-week ending routes failed when a legitimate null pair window reached ending-seed capture.
- Native Windows export reached the actual exported executable, which refused `--path`. No accepted release ZIP exists.

## Three repairs saved in this checkpoint — cloud verification required

1. `tools/testing/Invoke-WindowsExportValidation.ps1`: remove only `--path` from the native release executable invocation. Its package working directory and adjacent PCK discovery remain; keep isolation, timeout, diagnostic scans, Profile creation proof, and independent PCK audit.
2. `autoload/GameState.gd`: read `pl_window` as a Variant and check that it is a Dictionary before accessing `counts`. Null is legal on non-group days. `tests/unit/test_ending_frozen_context.gd` now creates seven real domain closures, checks only counted Day 2/6 receipts enter the seed, preserves source receipts, and exercises admission/checkpoint/presentation. Independently reviewed; not executed yet.
3. `tests/integration/test_dating_caption_style.gd`: both replacement sites now retain original DTL bytes. The older two-line fixture previously let teardown write an empty byte array, contaminating the later Dating natural-end test. Ending/Gallery fixtures now wait boundedly for one fresh `text_started` plus exact parsed text before sending input. Source inspection shows the default Visual Novel textbox has a 0.7-second fade before publication; the next run must confirm this explanation using `DWM_DTL_TEXT_PUBLICATION` diagnostics. Keep all original text, completion, and cleanup assertions. No production Dialogic behavior changed.

Do not label these repairs tested or close their Beads based on review alone. Inspect all required cloud jobs, including both full-week routes and native export. Preserve strict error/leak scanning and existing lifetime regression tests.

## Inventory and performance limits

The public-surface workflow is temporarily in `-Regenerate -EmitPayloads` mode. Its six downstream job definitions require the public-surface job. Run47 payload inventories were recovered and hash-verified, but the GameState/fixture edits in this checkpoint make them stale. After all source edits, regenerate at the final head, recover the exact canonical inventories, commit them, restore the read-only gate, and prove that gate on the final source. A skipped dependent job is not validation.

The exact same 1,910,526-byte Day7 Autosave produced cold Login 13.878894 seconds with cache disabled and 10.233698 seconds enabled. This was **one fixed-order pair**, diagnostic only. Strict parses went from 7 to 3 with 4 hits; all eight source hashes and restored gameplay/board hashes matched. Do not infer a reliable percentage or general hardware improvement from one pair.

Material lag remains: Day7 first reveal 1.306134 seconds, settlement 0.854962 seconds, Slot1 save 4.041201 seconds. The cache does not close `dwm-634`. Six same-byte outgoing-normalization comparisons retained exact equality. For checkpoint splice coverage, 14/35 eligible records carried the flag; do not use all 95 events as the denominator. Inclusive timing phases overlap and must not be summed.

## Beads and next order

There are 191 records: 165 closed and 26 unfinished. This pause closes none. Root alone mutated Beads; unrelated JSONL lines were preserved exactly. Publish intentional issue rows only; do not publish the local Dolt database.

1. Confirm actual repository privacy and Actions availability. The latest verified API state before this checkpoint was **public**. The GitHub connector had no repository-administration operation; the cloud browser was signed out and `/settings` showed 404. User sign-in or a manual visibility change is required. Do not claim privacy from intent alone. Earlier private runs were denied runner allocation by GitHub billing; switching public permitted run46 retries and run47. Do not repeatedly retry a billing admission failure.
2. Run the saved repairs in cloud CI at the current branch head. Resolve remaining failures without weakening gates; record head and actual PR merge SHA separately.
3. Finish canonical producer and adapter proof before strict v7 work. Active `dwm-n3h.1` is still open. Read `docs/agent/2026-09-21-successor-cutover-readiness.md` and `docs/agent/2026-09-21-v7-frozen-predicate-scope.md`; these are readiness audits, not implementation evidence. Coordinate snapshot/document v7, historical refusal fixtures, nested Condition/semantic predicates, and compatible performance harnesses in one bounded cutover. Preserve Profile v9.
4. Regenerate final API inventories and restore/prove the read-only contract gate (`dwm-sx8.1`). Complete release/full-journey gates (`dwm-oyo.8`). Continue measured lag work (`dwm-634`) with matched payloads and an appropriate repetition/order design before causal claims.
5. Consult Beads for the remaining work. `dwm-n3h.2` retains missing legacy replay selectors; do not synthesize them. Authored Gallery/version cues and History DTL content, undefined dual-language behavior, native Windows renderer/accessibility acceptance, and other existing blockers remain. None is silently resolved by the current green subscopes.

Earlier bounded children `dwm-7wj.1`, `dwm-vky.16`, and `dwm-nqn.1` were already closed with their recorded evidence. Do not reopen or reclose them just to recount this session.

## Copyable new-session request

Continue `Siuuuers/dwm` draft PR #1 on `codex/windows-cloud-ux`. Read `docs/agent/2026-09-21-session-handoff.md` at the current remote head, then the repository instructions and relevant Beads. Keep the repository private; use cloud-only Godot 4.6.3 automated tests. First verify the three saved run47 repairs; the last executed run passed 14/17 jobs and the later checkpoint is unverified. Preserve Profile history, automatic Dating transitions with no Continue/Done popup or special mine, and retired Observer interactions. Finish the remaining Beads using actual evidence; do not merge the PR.
