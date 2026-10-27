# Quick Save completion notice

Date: 2026-10-27, Hong Kong time.
Previous record: [Save reading reuse](av-save-reading-reuse-20261027.md).
Implementation and final acceptance: [PR 137](https://github.com/Siuuuers/dwm/pull/137).
Read current master and both PR results before more work.

## User decision and behavior

"Saved" confirms that the Quick Save action completed. Show it for two visible seconds.
Do not compare that completed action with subsequent gameplay state.

- Desktop, Dating and Pause no longer query Quick capability after successful Save.
- The success notice does not poll full save conditions while it is visible.
- Each successful Save starts a fresh two-second notice.
- Dating binds the notice to its screen and physical command. Board revision and
  caption publication changes do not invalidate the completed action.
- Keep screen ownership, visibility, failure-notice checks and pending Quick Load
  freshness. This is not permission to reuse a pending token after state changes.

Existing desktop, Dating and Pause tests check capture counts, ordinary gameplay
changes, repeated Save and notice expiry. All game execution stays in cloud CI.
The existing rendered direct Save/Load journey also sends native F5, verifies
actual drawing and durable Quick storage, and checks no capture while the notice
is visible. PR 137 records final results. No end-to-end Quick Save latency claim
is made.

## Next performance work

Use the accepted current master as the next baseline. Do not compare absolute times
between different runners. PR 136 reduced repeated reading validations from 12 to 8;
its [retained report](../evidence/phase_2r/save_reading_reuse_20261027/README.md) includes
the matched Save, passage and Load evidence.

First enable existing `DWM_SAVE_LOAD_PROFILE` phase timings in a cloud diagnostic
and measure native F5 to the first drawn Saved notice. The measured reading-validation
and storage spans overlap and account for only part of the full Save path. Use
that evidence to choose the next cut; do not assume remaining reconstruction dominates.

One bounded candidate is semantic reading reuse. Run schema validation already
has the expanded checkpoint, but GameState and FrozenRunContext expand it again.
Use existing owner boundaries. Preserve independent public calls, custom two-argument
semantic delegates, required frame checks and raw reading5 projection behavior.
Completed-passage validation also needs review. Measure one coherent candidate.

Do not add a prepared-save cache, background draft, new interaction gate, injected
failure, edited-file scenario or speculative external protection. Preserve exact
current-state Save, named-checkpoint-only Autosave, Logout without saving and the
accepted content compatibility/error behavior. No blocking product question remains.
