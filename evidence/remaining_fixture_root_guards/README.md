# Remaining fixture root guards

`dwm-ryl`, 2026-09-14. Source base: `f59f288bf820afe0ff73f65f8210aa5c3a0c13fc`.

Forty-two test suites now allocate native scratch storage through the existing `TemporaryStorage.create` helper and stop when allocation fails. This covers the 41 eligible fixtures from the Bead audit plus the Witnessed art fixture, whose old empty-string check accepted whitespace and wrote through `user://`. The art fixture now writes and reloads its catalog from the allocated absolute path.

Returning from a GUT setup method does not skip a test. The conversions therefore propagate typed failure values through helpers, guard test entry before accessing retained fixtures, clear setup readiness before allocation, and preserve cleanup after partial setup. Cases needing multiple roots derive their children from one checked allocation. All 559 test names and their order remain unchanged. Independent reviews checked all 42 conversions for caller propagation and preservation of behavioral assertions.

No production implementation changed. The GameState and SaveManager generated inventories were refreshed for moved test call sites; their contracts, signatures, classifications, and required manifests are unchanged. All `dwm-634*` work remains excluded. In particular, the still-unsafe `test_minesweeper_shop_purchase_participant.gd` and `test_save_manager_checkpoint_port.gd` belong to that scope, so `dwm-ryl` remains in progress rather than claiming every repository fixture is repaired.

The two shared live handoff manifests bind four of the changed fixtures. Exactly six test-source SHA values were refreshed; every other byte, including all runtime source bindings, remains unchanged. `contract-binding-refresh.json` records each replacement. This maintains references to our changed tests without replacing another owner's code or evidence.

## Verification

| Run | Scope | Result |
| --- | --- | --- |
| Unchanged main baseline | 42 suites, 559 tests | 444 passing, 115 failing; 11,231/11,427 assertions |
| Repaired combined run | Same 42 suites and 559 tests | 444 passing, the same 115 failing tests; 11,077/11,275 assertions |
| Final evaluation-order check | Desktop simulator suite, 8 tests | Same 6 existing failures and messages; 64/83 assertions |
| Unit/scenario plus allocator | 10 suites, 161 tests | 159 passing; same 2 existing debug-capability failures; 2,602/2,609 assertions |
| Empty root | 42 suites, 559 registered tests | 91 passing source/memory tests, 367 expected failures, 101 risky/pending after refused suite setup |
| Whitespace root | Same scope | Same expected refusal results |
| Valid first test, then missing root | 26 suites with `before_each`, 342 tests | All 26 post-first-test storage snapshots unchanged; no runtime errors after refusal |
| Current inventories and documentation | 14 tests | All pass, 410 assertions |
| Desktop and Minesweeper handoff evidence | 22 tests on baseline and current | Both 19 passing, same 3 existing Desktop failures; 932/935 assertions |

The combined normal run precedes one final correction that restores the original order of reading the first boot's context before attempting a second boot. The focused run verifies that correction. Combined with that final focused result, every one of the 115 baseline failure records and messages matches exactly, excluding source line numbers. The older failures concern debug admission, obsolete graph expectations, and incomplete fixture wiring such as missing `schedule_view`; this change neither repairs nor hides them. The comparison is in `remaining-root-normal-comparison.json`.

The lower assertion totals reflect replacement of repeated root and directory checks with the allocator's checked result. Existing behavioral assertions remain. The normal combined run retains 816 Dialogic orphan observations and Unicode/NUL warnings. This is not whole-game, warning-free, or leak-free acceptance.

The three handoff failures all come from the already-stale `DialogicBridge.gd` binding in the Desktop manifest, independently reproduced on unchanged main. The current Minesweeper manifest passes its complete suite. The unrelated Bridge binding remains unchanged and needs a separate review of the prior Witnessed changes; this checkpoint does not claim a fully current Desktop handoff.

## Failure-path evidence

A disposable `git archive` of the source base received the changed tests and the existing import/class caches. Its own isolated wrapper ran the probes. `probe-hook.gd.txt` clears the environment only after wrapper admission, records root and isolated user-directory snapshots, and restores the environment afterward. Empty/whitespace probes load every requested suite; the large handoff suite refuses its `before_all` setup, so its 101 guarded bodies have no assertions and GUT reports them as risky/pending. This is deliberate refusal, not successful functional coverage.

The original facade test supplied the concrete RED: with an empty root it reported an assertion failure but still wrote `facade-contract-identity/desktop-issuer-root.json` and its backup into the disposable source checkout. Those two actual files are preserved in `red-control`. An earlier bootstrap negative control passed all 12 tests despite missing its root; passing alone did not establish safe fixture admission.

After the repairs, the empty, whitespace, and stale probes leave all **9,213 source-tree file hashes and 565 descendant directories outside `.godot` unchanged**, with no new relative fixture files. The complete initial inventory is retained as `source-tree-before.json.gz`; `remaining-root-filesystem-verification.json` records the final comparison. The isolated user directory is also unchanged, including Dialogic's pre-existing empty global-info file. Each empty/whitespace run leaves its allocated test root empty and has no script/engine errors.

The stale probe applies only to suites with `before_each`: it permits their first test, snapshots storage, then removes the environment before later setups. Fixtures deliberately owned by `before_all` have a different lifetime and are covered by the missing-root setup probes. All 26 per-suite comparisons pass. Seven script errors occur in the initial valid tests and match existing fixture problems; none occur after the root is removed.

No selected test directly launches an external process. The probes establish unchanged observed files/directories and checked refusal paths; they do not claim a system-wide operating-system I/O trace.

## Diagnostics and reproduction

Sixteen terminal engine runs are recorded in `runs.jsonl`, with raw log hashes and archived log paths. An initial combined run failed to load the first-reveal suite because the new allocator local reused an existing variable name; that log is retained and the subsequent combined run executes all 559 tests. The first negative-wrapper invocation rejected an evidence path outside the disposable repository before launching an engine; subsequent invocations use its local evidence ledger. An abandoned read-only inventory traversal was replaced with one that prunes `.godot` before recursion; it is not used as proof.

Normal runs use `tools/testing/Invoke-IsolatedGodot.ps1` and the exact GUT selections in the ledger. For negative reproduction, use a disposable checkout, install the archived hook under its ignored `.godot` directory, and supply `ROOT_GUARD_MODE=empty`, `whitespace`, or `stale` plus `-gpre_run_script=res://.godot/root_guard_probe.gd`. Keep the wrapper's application-data isolation. Use `stale-suites.json` for the stale selection. Never perform the negative control in the user's working checkout.

`source-sha256.json` binds the final 42 test sources, two inventories, and two shared handoff manifests after CRLF-to-LF normalization. `SHA256SUMS` binds the evidence artifacts. Archived text logs strip trailing whitespace; raw hashes retain the exact original-log identity.
