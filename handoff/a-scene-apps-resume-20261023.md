# Scene apps and Shop — resume 2026-10-23

## Stop point and authority

The user requested a clean handoff for a new session. Stop feature work here. Shop and the other supported desktop apps are approved to be available throughout play. All Minesweeper remains optional; do not require completion before story progress. The two daily-renewal/unfinished-board questions below remain unanswered. No release or master acceptance is claimed.

Read AGENTS.md and CLAUDE.md, then this record and the current branch heads. Run Godot and PowerShell only in cloud GitHub Actions, using the repository's official Godot 4.6.3 standard workflow. Local git, Python, source review and archive verification are allowed. Preserve historical test bodies, hashes, deadlines and saved-data obligations. Do not revive health, Hospital or calendar mechanics to satisfy old fixtures.

## Exact sources and concurrent work

| Role | Last observed commit |
| --- | --- |
| master | `41592fcc792aa615e47ee2ce2f05008ca195b311` |
| PR42 integration before this documentation commit | `cc40aee5722afaa24e8a8daa556e8c27bc956810` |
| PR47 tested production candidate | `f20e559a7af26808eff3f0582eae60564ed3c352` |
| PR47 candidate tree | `76bef7a0c3c673badca5aba2e47fb34eaac02d19` |
| PR47 diagnostic controller | `937953772c3d9879b21cd7f76d967943dd2f8c1f` |
| PR43 story branch | `e2d1cd5c3500d2178fcbc483495010a1922d3f0f` |
| temporary Windows delivery branch | `1b98886628c3e042c5a7c5738ddb2912f27d7ae8` |

PR42 is `codex/playable-master-integration-20261023`, targeting master. PR47 is `codex/scene-shop-qualification-20261023`, targeting PR42. Its two diagnostic workflows check out the separate production candidate above; do not merge the controller as production. Incorporate qualified source deliberately and close the diagnostic PR afterward. PR43 currently targets `codex/art-media-20261023`; re-read its live metadata before composing it.

Important concurrency: PR42 advanced after this candidate was composed. Commits fd96dee/3b23d8f imported and documented licensed Bach music and regenerated story registration; 6e7fb1a added localization/Steam handoffs; f828036 completed Chinese UI strings; 1d04743 configured Steam AppID5199120 and DepotID5199121 preview. Preserve these changes. The candidate already preserves export exclusions from50bb121 and accepted Shop evidence from65914c0, but does not include all later PR42 changes. Reconcile scene_story_registration.json and Chinese UI files deliberately. Do not reset PR42 to the candidate or overwrite another session's media, localization, Steam, or PR30 work.

During handoff publication PR42 advanced again to cc40aee: authored-week localization in four languages, PR43's seven-day English DTL and choice/Challenge support, font fallback, display-only caption/History/choice translation, and compiler-cache changes. Its commit reports24 focused tests/481 assertions plus graphical language switching/save-load; this session has not independently qualified that result. Read handoff/localization-20261023.md and its retained evidence. Overlapping Bootstrap, GameState, Bridge, SceneHost and SceneEventContract changes require a real merge/review. Reproduce the failures below on the combined candidate; they describe f20e559, not an assertion that cc40aee has identical behavior.

## Implemented candidate scope

- Durable scene Shop transaction through GameState, SceneEventContract, RunSnapshotSchema and SaveManagerNarrativeCheckpointPort: detached preparation, real issuer/source identity, checkpoint before adoption, exact retry/conflict handling, lease revalidation and uncertain-commit refusal. Existing catalog and consequence state remain canonical owners. No fabricated health.
- Bootstrap binds the existing catalog/consequence owners. ShopPresentationPort captures transaction/source context once and retains it through retries.
- Computer hold freezes the current native presentation while desktop apps remain usable. Boundary reads verify the held physical source, including under a transaction lease. Genuine authored Challenge admission remains separate from ordinary Apps opening.
- Scene desktop supports existing Contacts, Shop, ordinary Minesweeper, Settings, Backup and logout. Returning from Shop preserves the admitted Challenge board. Restored Settings/Backup states use canonical Home navigation. No invented Music/Files app or retired Schedule.
- Gallery/pause/Apps localization and literal-audit coverage; explicit retained historical fixtures; Shop blank slot, partial-page keyboard navigation and metadata-width corrections. All original assertions retained. Twelve missing UID sidecars came from actual cloud imports.

## Latest evidence: accepted scope and failures

Both final qualification runs used source f20e559a/tree76bef7a and controller9379537.

**Shop:** [run39848251407](https://github.com/Siuuuers/dwm/actions/runs/39848251407) passed64 cases/883 assertions:62 unit cases/757 assertions, real Contacts refusal1/60 and real Shop transaction1/66. Three successful isolated processes. Original ZIP1,557,569bytes SHA256 `06161c39237a31a30e6014935b51c008197f753c2e0525039fb059954be59aa2`; all540 retained hashes and CRC rechecked at handoff. Artifact12455773278. This is bounded Shop checkpoint acceptance, not whole-game acceptance.

**Apps:** [run39848251404](https://github.com/Siuuuers/dwm/actions/runs/39848251404), job120067211389, failed the final gate. 259 of260 planned cases executed:257 passed,2 failed; fresh-process loader did not run after creator failure. Shell39, Computer custody8, localization57, historical dating81 and rendered blank1 all passed. Shop fixtures71/72; connected creator failed at Save. Nine Apps PNGs plus blank PNG were retained. Purchase, visible Home/Contacts navigation, same-caption return, real Challenge first reveal, switching to Shop and unchanged Challenge return passed. The reviewer found the before/after Challenge images pixel-identical.

Apps artifact12456297180 transport ZIP:2,203,870bytes SHA256 `5f895213fb48523f7c05f5e499273524c7f5b97f9da561e7e565b457e9679319`. Distinguish this from its **original inner evidence ZIP**:2,307,099bytes SHA256 `ff807dd35b914ec0b25af0e810bb43511df0f3081c9858afae4d7f67ef34d633`. All669 retained hashes and CRC rechecked at handoff. Original inner ZIPs and reports are committed under `evidence/phase_2r/master_integration_20261023/run39848251404/` and `run39848251407/`.

Broad [Windows run39848251396](https://github.com/Siuuuers/dwm/actions/runs/39848251396) also failed. Focused results do not override that gate. Earlier accepted fixture run39843560271 (106 cases/2102 assertions plus public surfaces11/352), restore proof and preserved historical evidence remain in PR42; see a-master-integration-20261023.md. Do not repeat or weaken those proofs without a changed dependency.

## First two fixes in the next session

1. Japanese pixel-font Shop at150%, page index1, still returns `shop_dock_does_not_fit` in test_every_locale_and_size_keeps_full_catalog_inside_the_plate. The measured availability-width correction fixed Chinese cases but did not establish Japanese fit. Inspect the original logs and actual font/layout measurements; preserve full catalog/order/fit assertions and the strict refusal. Do not reduce font size, hide items or relax the oracle merely to pass.
2. Save after returning from Challenge fails `before_write_refused` / `event_presentation_held`. Observed chain: JsonFileStorage._run_before_write → Bootstrap._flush_before_run_save → DatingPhysicalOwner.flush_pending_attempt → _flush_scene_pending authorizes before checking whether anything is pending → GameState.validate_scene_challenge_command → Bridge.capture_scene_event_boundary rejects the active Save-sheet pause. The Save sheet intentionally owns that pause. Review no-pending handling and real pending-write custody; do not unpause in the fixture or bypass source validation. Prove Save and the separate fresh-process Load journey, including unchanged board/purchase/reading state.

Complete compatible reviews before the next coherent acceptance run. Pin both focused workflows to one new source. Retain original artifacts even on failure. If opening a diagnostic rerun, keep collection UTF-8-safe and write ZIP before printing log tails. Green execution steps alone are insufficient; inspect process exit records, exact source-derived census, JUnit and images.

## Remaining gameplay and design decisions

Ordinary Minesweeper first Reveal has a scene checkpoint path, but completion still reaches legacy health/condition/schedule code. See the companion ordinary-Minesweeper audit in this handoff publication. Its real completion ledger is also needed to demonstrate Supportz eligibility after actual rounds1 and2. Keep existing reward tables, daily money caps, task claims and the one-owner ledger; introduce an explicit pressure-only scene completion transaction with durable settlement/retry proof. Do not inject ledger rows to claim a player journey passed.

Two product choices require the user's answer:

1. Should each new authored story day renew the two base rounds, daily earning allowance, finished-today count and daily Supportz eligibility? Recommendation: yes, via explicit registered day boundaries and one atomic transition owner. Never infer resets from entry-ID spelling or reset on every intra-day scene transition.
2. What happens to an unfinished ordinary board at a story-day boundary? Recommendation: ask before abandonment, with no refund of the already spent round, while allowing return to finish the board. Alternative: carry it forward and explicitly define which day's rewards/eligibility it counts toward. Neither rule is approved yet. Minesweeper must remain optional; requiring completion to advance is inconsistent with that established constraint.

Apps being available throughout play does not itself define either choice. Keep these questions pending; proceed independently with the two reproducible fixes above. Timed-wait/art-card frontiers also lack a proven semantic checkpoint for app mutations. Native timer preservation, successful Supportz purchase after real completions, daily renewal, and fresh-process Load are not certified by the focused Shop run.

## Integration and release order

After product decisions and bounded fixes: compose current PR42 media/localization/Steam changes, latest PR43 story source and the qualified apps source; regenerate current owner inventories and finite current-owner provenance with existing tools; preserve every historical seal/control; run required canonical cloud checks and rendered journeys; produce and verify the exact Windows artifact. Only then assess PR/master/delivery integration. Do not treat a draft PR, preview Steam configuration, or successful export as proof of a playable release.

The old local integration-work directory is a sparse detached merge worktree with staged and unstaged changes, not a clean branch. Do not blindly commit its index. A new session should fetch current refs and use an isolated clean worktree. All necessary source is reachable through PR47's pinned candidate; this handoff and original evidence are Git-backed. No background coding or new qualification run was started for this handoff.
