# Retired suspended Observer presentation

Baseline: `a1be5930f07adf3a12801e4ae156d371d0fe5637` (2026-11-04).

The [current suspension decision](../../design/current-ui/observer-interactions-suspended-2026-09-21.md)
already excludes Capture, Compare and timed-restraint controls from the live
DatingScene. Original implementation and design remain on its named archive.
This cleanup removes dormant presentation code; it does not change eligibility,
profile evidence, saved data, domain rules or history interfaces.

## Removed group and proof

From `scripts/ui/DatingScene.gd`, remove `_build_observer`,
`_hide_capture_if_unfocused`, `_send_observer`, `_on_observer_action`,
`_on_comparison_drawn`, `_refresh_observer`, their ten exclusive fields, the
no-op refresh invocation, and four exclusive inline translation entries in each
of four locales. These built a prior-line Capture/Compare panel or a timed
MoveCup control and false cursor, then dispatched Observer commands.

The builder has no caller, signal connection, resource invocation or subclass
entry point. `_ready` does not mount it; all other removed callbacks are wired
only by that builder. The retained refresh invocation returned immediately
because its panel was never instantiated. Searches included scripts, scenes,
resources, autoloads, addons, data, authored timelines, tests and tools.
`DatingPhysicalOwner._observer_source` returns an empty dictionary. Preserve
physical/application/profile/schema owners and all their interfaces.

The existing `test_day2_scene_does_not_mount_retired_observer_interactions`
checks both former participant scopes, no Observer reads, no mounted controls,
and no dispatched commands. Extend its absent-node list to MoveCup and ComparedLines.
The retained Observer startup probe now checks actual node absence instead of
reading the deleted private dictionary; its empty-evidence assertion remains. The surrounding challenge-control suite
checks retained board controls, rules, layout and input boundaries.

## Verification scope

Run that focused scene suite, remaining scene-load smoke and both read-only
public inventory checks. Compare the complete remaining source against baseline
after only the listed deletions. External locale catalogues are unchanged; the
removed inline entries have no remaining consumers.

No gameplay journey, broad localization matrix, shop/audio tests, TLA+, Windows
export or performance benchmark is needed for this dormant presentation removal.
Actual outcomes and automatic CI selection are reported in the PR. No speedup
is claimed. Terminal-choice helpers and their stale selectable probe remain a
separate investigation; live input guards stay intact.
