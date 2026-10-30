# Shop item scale and computer-panel alignment handoff

## Mission and authorization

The owner requests implementation in another session: restore the item presentation
size/visual presence associated with the game before PR #1, keep all nine Shop slots
on one page, enlarge the computer panel toward the right if needed, and make the
computer bar and panel share the same width and aligned edges. This session supplies
this handoff only; it makes no additional runtime changes. Final visuals remain code-based.

Do not interpret “old size” as permission to restore old clipping or shrink accessible
text. Measure card bounds, artwork bounds and their rendered screen size separately.

## Start from the correct revision

Repository: https://github.com/Siuuuers/dwm

At handoff preparation, PR #167 is **open, ready for review, and unmerged**:
https://github.com/Siuuuers/dwm/pull/167

- Branch: `codex/shop-inventory-only`
- Tested head: `7a06b0eabd05ecca8debc52fcd461f2bdb2473ab`
- Master/base at that check: `f8cc83308aa5d74631aca1e8f5de0bc46aeacf5f`
- Historical pre–PR #1 master reference: `9e43b52c9884ccd59e82245d2168c3113ee4d037`

Recheck PR status and current branch heads before editing. If #167 is still open,
base the implementation on its current head, using an isolated branch/worktree.
If merged, use current master containing it. Do not start from the older master and
accidentally discard the inventory-only or single-page changes. Do not modify PR #1.
Read `AGENTS.md`, `CLAUDE.md`, and the applicable UI/desktop contracts first.

## Preserve the accepted behavior

1. Fixed 3×3 grid: Crystal Stutters, Inked Silk String, Letter with Wax Seal,
   Metronome, Pocket Calculator, Bookend, Lucky Charm, Debug Key, then the existing
   secret Supportz slot. Eight public cards plus the ninth structural/conditional
   slot; do not invent a ninth ordinary product or expose Supportz prematurely.
2. Money and coins share one tinted row spanning only the item grid, not the inspector.
3. No visible Previous, Next or page number. Pagination is retired, with an exact
   source snapshot in `docs/retired-features/shop-pagination/`.
4. The first three items cost $45 each, once per run, and only add inventory.
   Decoration rendering stays retired. Preserve existing ownership, save/load,
   purchase caps, prices, capability effects and new-run behavior.
5. Lucky Charm stays seventh and Debug Key eighth. Their artwork uses the historical
   Weighted Plush and Bandage Pack fallback tiles explicitly chosen by the owner.
6. The redundant inspector price beside availability remains removed; card prices
   and the purchase total remain visible and localized.

## Verified findings, not a guessed visual target

Historical `scripts/ui/ShopApp.gd` at `9e43b52c` uses an 800×656 logical Shop plate,
448×544 catalogue and fixed 144×176 cards. The historical
`scripts/ui/ShopItemBox.gd::refresh_layout()` computes an artwork aperture between
12×12 and 56×56, depending on text metrics; 56×56 was a maximum, not a guaranteed size.
It reserves two name lines and one line per price/availability field. Restoring those
fixed text bands could reintroduce clipping. Compare the historical and current
versions at the same font, locale, text percentage and viewport before selecting sizes.

Current cards retain 144 logical pixels of width and grow vertically to fit complete
text. The single-page panel measures three rows and can grow vertically. This fixes
pagination but does not establish that the artwork has the owner's desired prominence.

The current production scene has two sizing layers worth examining together:

- `autoload/ApplicationBootstrap.gd::_layout_scene_desktop()` fixes the desktop at
  800×720, then uniformly scales it by `min(available.x / 800, available.y / 720)`.
  More horizontal mount space alone may therefore have no visible effect when
  height is the limiting factor.
- `scripts/ui/ComputerDesktop.gd::_layout_desktop()` also derives canvas scale from
  `size.x / 800`. Its `AppStrip` is bottom-wide on `DesktopCanvas`.

`scenes/narrative/SceneHost.tscn` currently anchors `ComputerMount` to the scene with
left offset 352, top 8, right −8 and bottom −8. Inspect the actual runtime transforms;
logical dimensions and rendered pixels are not interchangeable.

## Implementation direction

- First capture the real mounted computer with Shop open at 1920×1080, using the
  default 125% text size. Record the global rectangles and transforms of the mount,
  desktop, Shop plate, catalogue, artwork, inspector and computer bar.
- Establish which visible bar the owner's mismatch refers to in that mounted scene.
  Distinguish the computer-owned AppStrip from separate History/Save/Settings or
  reading controls that may visually join the bottom row. Do not claim that an
  isolated Shop screenshot proves bar alignment.
- Restore the intended item-art presence and comfortable card proportions. Use
  horizontal room to reduce excessive name wrapping before making cards taller.
  Keep the existing left placement where feasible and use available space toward
  the right, as requested. Do not achieve the effect by reducing the selected font size.
- Give the computer panel and its bar one shared outer width/placement calculation.
  Match both left and right edges, not merely their numerical widths. Avoid
  independent offsets or scales that happen to align at one resolution.
- Recalculate the three-column catalogue, column/row gaps, balance strip, inspector,
  dock and focus geometry from the chosen dimensions. Search for fixed 800, 448,
  144, 480 and related coordinates rather than editing one width in isolation.
- Keep the 3×3 grid on a single page. Target full visibility at 1920×1080 with 125%
  and 150% UI text. On smaller windows, preserve usable host scrolling rather than
  clipping or silently restoring pagination. Keep any deliberate constraint/tradeoff
  explicit in the final report.
- If historical rendering does not uniquely identify the owner's intended art size,
  present a measured old/current comparison and ask one focused size question before
  finalizing the visual target. Do not assume the owner wants every old dimension restored.

## Primary files to inspect

- `scripts/ui/ShopApp.gd`: plate, balance strip, grid, inspector/dock and focus wiring.
- `scripts/ui/ShopItemBox.gd` and `scenes/shared/ShopItemBox.tscn`: artwork and text bands.
- `scripts/ui/ComputerDesktop.gd` and `scenes/desktop/ComputerDesktop.tscn`: canvas,
  AppWindowHost/AppScroll, AppStrip and shared chrome.
- `autoload/ApplicationBootstrap.gd`: production scene desktop mounting and scaling.
- `scripts/ui/SceneHost.gd` and `scenes/narrative/SceneHost.tscn`: mount and scene controls.

The production scene route above is important. Do not fix only the older
`MainGameScene.gd` route or only a standalone Shop fixture.

## Verification and acceptance

Godot and PowerShell verification run in GitHub Actions, per repository policy.

- Capture the actual mounted game at 1920×1080, 100%, 125% and 150%, with before/after
  images under matching conditions. Supply both a whole-panel/bar view and a close
  item view. Clearly label isolated layout fixtures separately from gameplay captures.
- Assert all nine slots occupy one 3×3 grid; no paging controls are visible, focusable
  or pointer-active. Preserve Supportz eligibility, its blank presentation and keyboard access.
- Assert the intended computer panel and bar have matching global left/right bounds
  within rounding tolerance (prefer at most one physical pixel), at every tested size.
- Check English, Simplified Chinese, Traditional Chinese, Japanese and Korean with
  pixel and readable fonts. All names, balances, prices, availability and purchase
  controls remain complete at 125% and 150%; artwork stays recognizable.
- Verify native pointer hit locations, hover inspection, keyboard navigation, focus
  rings, Home, app switching, scrolling, reopen and preference changes. Check other
  computer apps because the host/bar is shared. Preserve modal input custody and captions.
- Retain the real purchase → save → fresh-process load → new-run regression and
  confirm the three inventory-only purchases still have no decoration effect.
- Update geometry expectations deliberately, keep assertions meaningful, and refresh
  public API inventories or exact localization-audit dispositions if the changed
  source requires them. Extend CI path selection for new files instead of silently
  losing relevant coverage.

Relevant existing tests include `tests/scene/test_shop_plate.gd`,
`tests/scene/test_shop_blank_rendered.gd`,
`tests/unit/test_shop_app_purchase_bridge.gd`,
`tests/integration/test_shop_desktop_host.gd`,
`tests/ui/render_desktop_scaling.gd`, and `tests/ui/render_shop_cosmetics_*.gd`.

The current `shop-single-page-100/125/150.png` images are **isolated layout fixtures**.
They establish grid fit, not production computer-bar alignment or a live purchase session.
Current baseline validation: Windows selected suites
https://github.com/Siuuuers/dwm/actions/runs/41020755421 ; readability
https://github.com/Siuuuers/dwm/actions/runs/41020755365 .

## Next-session delivery

Return an implementation PR based on the verified current branch, matching mounted
before/after screenshots, the measured old/new card and artwork sizes, the shared
panel/bar bounds, test results, and any remaining small-window limitation. Preserve
all archived implementations. This handoff does not request merging a PR.
