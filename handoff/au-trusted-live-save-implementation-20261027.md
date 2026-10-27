# Trusted live Save: first measured simplification

Date: 2026-10-27, Hong Kong time.
Previous record: [approved plan](at-trusted-live-save-plan-20261027.md).
Implementation and final acceptance: [PR 135](https://github.com/Siuuuers/dwm/pull/135).
Read the PR and current master before more work. This record does not replace the final CI result.

## Observable outcome

Save the exact current reading and gameplay state. Load must not repeat consequences.
Reduce Save work without moving that work onto ordinary reading.

## Implemented change

- Bind paused-scene Save availability to the existing Pause owner. Other providers keep their existing fallback.
- Use the ledger's admitted frame query for availability. Do not copy History to read one frame.
- Remove duplicate Run9 construction and reading validation from live input capture.
- Reuse the schema-built candidate through the journal's existing exact-object API.
- Remove temporary session restoration from live compact-reading projection.
- Keep actual restoration and scene installation validation. Keep the source recapture and equality check before writing.
- Add the existing direct Save/Load journey to an isolated rendered cloud suite.
- Use the real desktop board restore participant in that journey. Its old diagnostic participant retained player-format data as live state.

No prepared-save cache, background draft, new interaction gate or injected failure test was added.
Manual Save, named-checkpoint-only Autosave, Logout without saving, and accepted content compatibility rules remain.

## Measured evidence

See [report and retained samples](../evidence/phase_2r/trusted_live_save_20261027/README.md).
The first comparison passed all 24 exported journeys. Four matched pairs measured longer-reading Save
at 2092.73 ms before and 931.97 ms after. All four pairs improved. Scene validation calls fell from 40 to 12.
Passage drawing changed little. Load median was 1.0% slower. Do not claim a Load speedup.
The initial regression found stale API inventories and an old direct-controls fixture. Both were corrected;
final acceptance and any repeat measurements are linked from PR 135.

## Remaining work

1. Keep the accepted candidate as the next matched baseline. Do not compare absolute times across runners.
2. Normal Run validation still reconstructs reading three times. The schema expands compact reading,
   then restores a second session. Semantic validation expands it again.
3. Preserve the session needed by `validate_scene_new_run_candidate`. It passes that session to
   `_build_current_scene_initial_checkpoint`. Challenge position checks also need its programme nodes.
   Reuse constructed state through its owner before introducing a separate cache or public trust flag.
4. Quick Save still captures repeatedly for `_quick_condition`. Consider one operation-local capture
   where there is no intervening callback. Keep the freshness boundary across real UI callbacks.
5. Document build and journal commit have other consumers. Do not delete their checks globally.

No blocking product question was found. The next decisions need source and matched runtime evidence.
All game execution must remain in the cloud. Do not add injected failures, new edited-file scenarios,
content scans, mandatory Options/Challenge gates, or speculative external protection.
