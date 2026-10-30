# Shop artwork and mounted computer sizing

## Accepted outcome

The owner chose artwork prominence over restoring every historical card dimension,
balances above the selected-item details, and artwork beside the name to keep the
nine structural slots visible with enlarged text. Eight public products and the
conditional blank Supportz slot remain one page. Purchase and save owners are unchanged.

## Geometry and ownership

- Production scene Shop uses 200px cards, a 616px catalogue, and a 968px plate.
  The 304px inspector keeps its existing artwork, copy and purchase controls.
- Every card reserves 56×56 artwork beside complete measured text. The historical
  56px maximum is now a stable aperture, not a claim that all historical cards
  displayed 56px art at every text size. Card height still grows with measured copy.
- The balance strip uses the inspector's width with 8px text margins. Earned
  balances wrap when needed instead of overflowing the column; the inspector
  yields height while the grid stays fixed.
- Bootstrap sizes the production computer to the available mount; the scene canvas
  uses the same 968px logical width. The panel and AppStrip share that canvas.
  Available mount height is retained when width limits the scale.
- Legacy desktops retain their 800px canvas and 144px card width. Scene configuration
  works both before and after mounting. There is no new layout manager or save field.

At the reference 1280×720 logical viewport (1920×1080 capture), the mount is
920×704. The scene scale is 920/968 rather than the former 704/720. Selected font
sizes are unchanged; physical text is about 2.8% smaller due to fitting the wider
computer. A 56px aperture renders at about 79.8 screen pixels. The measured baseline
rendered Crystal Stutters at 29.3px with 125% text and 35.2px with 150% text.

## Verification

`tests/ui/render_shop_mounted_sizing.gd` uses production SceneHost and FINAL services
with authored TEST dialogue. The cloud comparison runs the same probe against
PR #167's `7a06b0e` and the candidate. Candidate acceptance checks all 30 combinations
of five locales, two font styles, and 100/125/150% text: full grid visibility,
56px artwork, complete measured card copy, hidden/inactive pagination, balances
above the inspector, and both panel/bar and Shop/bar edges within one physical pixel.
It retains whole-view, panel and item captures at English Pixel 100/125/150%.

The existing Shop, desktop, native input, localized layout and real purchase → save
→ fresh-process load → new-run suites remain selected. Cloud results and the final
tested revision are recorded on PR #168; this document is not itself a passing receipt.

Coverage selection now admits Shop-only geometry work without requiring a catalogue
data edit. Bootstrap changes qualify only when everything outside its scene-desktop
layout method is unchanged. Unrelated source changes retain broad coverage. Existing
sparse checkout remains in place; no unmeasured download-speed claim is made.

## Limits

Small windows retain the existing shared scale and scrolling behavior. Linux captures
do not certify physical Windows monitors or native display scaling. Older non-Shop
apps keep their own content widths inside the wider scene shell. No new decoration,
save migration, external-input hardening, latency rewrite, or PR #1 change is included.
All retired source snapshots remain intact.
