# Week Tint Evidence Renders

Both PNGs in `renders/` were produced by a patched copy of
`tests/ui/render_art_placements.gd`; the patch itself is not checked in.

## `03-shell-layers.png` (Day 1)

Captured on Day 1. Compared against the tracked
`evidence/art_placements/renders/03-shell-layers.png`, the desktop region
matches except for the clock box: inside bbox (709,24)-(751,40) the mean
absolute difference is 0.068.

## `03b-desktop-day7.png` (Day 7, desktop region only)

Captured after calling
`ComputerDesktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 7})`.
Only the desktop region (x >= 480) reflects Day 7; against the Day 1 capture
the mean absolute difference there is 6.38.

The Angela panel region (x < 480) still reads as Day 1 in both renders. This
is a harness artifact, not a product bug: the render harness advances the
desktop's own `_day` but does not advance the `_day` on the `GameState`
autoload that `StatHud` reads from. In real play both values change together,
inside the same synchronous `day_changed` emission, so this split never
happens outside the test harness. The HUD's own tint behavior is proven
separately by `tests/unit/test_stat_hud_week_tint.gd`.

The Angela region in both renders shows only the HUD because the painting
assets were not present in the worktree that captured these renders.
