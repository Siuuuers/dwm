# Caption replacement and asynchronous text effects

Skipping a caption during an authored `[pause]` and immediately advancing could let the old pause consume the next caption's effects and increment its reveal count. Pausing the new caption did not prevent this: the old asynchronous continuation ran outside the native node's `_process` method.

The regression uses the installed Dialogic runtime, native `[signal]` and `[pause]` effects, and ordinary input handling. It pauses the replacement synchronously at `text_started`, then lets the original timer expire. Before the fix, the replacement signal fires and its visible count changes from zero to one. No private effect queue is fabricated or changed by the fixture. The RED run, `witnessed-effects-red-20260906a`, failed exactly those three assertions (including the combined state invariant): 13 of 14 tests passed, 859 of 862 assertions passed, exit 1.

Cancellation belongs in the native reveal node and Text subsystem. A node generation distinguishes successive reveals, including identical replacement text, append, direct text assignment and explicit completion. An effect-batch generation distinguishes newly parsed effects from the batch an old continuation began consuming. Both must be checked across an awaited callback: checking only the character count after the whole effect loop is too late to prevent a stale signal.

The implementation increments those process-local generations at their native boundaries and refuses stale work before it touches the next effect or character. Instant text projection and empty replacement retire the old effect batch. Explicit skip first invalidates the suspended character continuation, then executes legitimate remaining effects with the new generation. Existing `Control` callers of `execute_effects` retain the same API.

This is a local correction to the installed addon, not an upstream release update. Future Dialogic updates must retain the runtime regression and review these two source changes:

- `addons/dialogic/Modules/Text/node_dialog_text.gd`
- `addons/dialogic/Modules/Text/subsystem_text.gd`

The fix does not establish canonical saved-caption identity or History restoration. Temporary hiding during an already-awaited effect needs a separate suspension policy; stopping `_process` alone does not pause its timer. Arbitrary custom asynchronous callbacks also need their own cancellation checks for side effects they perform internally. The actual Hospital timeline still contains no authored captions, so these fixtures prove installed-runtime behavior rather than authored Hospital content.

## Verification

The final run, `witnessed-effects-final-20260906a`, passed **158 tests / 2,357 assertions across eleven suites**, exit 0. The new native tests cover stale skip/advance and clear/replacement cancellation, legitimate remaining effects during skip, and the replacement's ordinary pause, exactly-once effects and natural completion. Existing append, presentation, Hospital, bridge, skip, restore and effect-boundary regressions also pass. Broader instant-restoration behavior remains outside the new native test coverage.

Independent review found no blocker in this demonstrated scope. The installed addon's known eager-constructor overhead remains 384 orphan subsystem objects in this run (24 per handler); the environment's certificate-store and Unicode-NUL diagnostics remain. No script error occurred. All runs used isolated application data rather than player saves.

The RED and final GREEN logs and invocation receipts are retained in [`evidence/witnessed_effects`](../../../evidence/witnessed_effects). The earlier stack screenshots remain evidence for the unchanged presentation at `9dc978258`; no new visual change is claimed here. Durable task: `dwm-eei.12`.
