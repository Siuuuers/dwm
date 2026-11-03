# Retired terminal-choice probe and unused presentation helpers

Baseline: `09ba45330bb5a508bab934a3ae542ee9bc79285b` (2026-11-04).

The [approved automatic flow](../../design/current-ui/automatic-dating-flow-2026-09-21.md)
settles completed boards automatically and excludes the special mine and routine
confirmation cards. This cleanup preserves that behavior.

## Removed group

- `tests/integration/PlayableDatingCapabilityProbe.gd` and its UID sidecar
  (`uid://48iu1chaisnh`). The baseline revision retains their exact source.
- Its only launcher in `verify_playable_startup.gd`: `--probe-dating-debug`,
  `--probe-dating-marked`, their conditional invocation and debug-only inventory fixture.
- DatingScene's uncalled `_refresh_terminal_choice`, its exclusive
  `_poll_terminal_release`, and `_terminal_choice_key` / `_terminal_contacts`.

The probe waited on the old pre-challenge draw acknowledgement, pressed the
former Continue control, and expected marked-mine choice/focus and Dark-result
behavior. Those expectations contradict current automatic flow. No current
workflow or tool launches its two flags. Ordinary `--probe-dating` and
`--probe-dating-reload` remain. Supported Debug capability is not retired.

Before removal, searches of scripts, scenes, resources, autoloads, tests, tools
and workflows found only the named launcher, UID, declarations and closed helper
references. No signal, dynamic caller or inherited entry point reaches the helper
group. Preserve `_choice_released`, `_input`, `_on_cell_action`, quick commands,
advance-contact release handling, physical-owner rules and legacy phase admission.
Their remaining source bytes are unchanged. Historical evidence stays intact.

## Focused verification

Existing capability tests cover automatic Perfect/nonperfect results, absence of
marked-cell actions, held-contact separation and Debug preparation/restore.
Physical-owner tests cover legacy clear continuation, mounted board input and
paint-before-settlement. Run those suites, the remaining scene smoke, startup
probe parsing, and read-only API inventory checks. Removed probe-only API caller
memberships may require actual generator output; never hand-edit inventories.

No new lint, test framework, gameplay rule, save schema or dependency is added.
Skip broad localization/rendering matrices, shop/audio tests, TLA+, export and
performance benchmarking. Report actual outcomes in the PR; no speedup claim.
