# Reading rail geometry source review — 2026-10-04

This is a diagnostic and focused-review record, not the final acceptance receipt. The coordinating agent owns final PR validation and publication.

## Observable defect and rejected hypotheses

The baseline diagnostic ran source `93e934b88a5ac1caaa111cdddd280b8122647090` in cloud run **37183839755**. The actual Simplified and Traditional Chinese buttons resolved their selected Fusion Pixel 12px SC/TC faces at font size 36. Skip and Auto label widths were **180px within 194px** of horizontal content space. Both languages nevertheless had native minimum height **68px** and actual height **68px**, extending below the fixed **64px** rail.

Blanking and restoring text to force reshaping produced RGB-byte-identical images in all three retained CN150 samples. Earlier speculation about stale fonts, incomplete settling or a Simplified-Chinese-only horizontal failure is unsupported. The two prior Chinese screenshots are RGB-byte-identical to their diagnostic counterparts. The confirmed defect is vertical geometry shared by both languages.

## Bounded change and ownership

`WitnessedTransportRail` remains the owner of its fixed six-control geometry. The change reduces top and bottom content margins from 10px to 8px while preserving 10px horizontal margins. A 48px line plus 16px vertical padding fits the 64px rail. Restoring each button to its canonical minimum allocation after material updates prevents retained enlargement during presentation transitions. Font selection remains owned by `WitnessedCaptionTheme` / `UiTypography`; there is no speculative font override or new manager.

No save, recovery, History, narrative admission or consequence ownership changes belong to this fix. Caption artwork, panel-free text, caption placement and the separate rail remain unchanged in the inspected evidence.

## Regression and artifact inspection

The mounted unit regression reuses the rail through EN100 → CN150 → HK150 → CN150 → EN100 and all five supported locales at 100%, 125% and 150%, in Pixel and Readable styles. It models the production order of rail theme assignment followed by Canvas theme assignment. Assertions cover resolved font identity and size, fixed bays, native minimum height, full line height within actual margins, visible label widths, complete accessible labels and distinct mode states. Earlier fresh-instance label expectations were preserved.

The enhanced rendered fixture records actual control fonts, sizes, widths and bounds. Independent inspection of focused `results.json` verifies **90 controls across 15 caption samples** have exact fixed 212px/214px × 64px allocations at their canonical x positions. Every measured visible label fits its actual horizontal aperture. The full render result reports **25 captures and no failures**.

Comparing all 15 caption screenshots between baseline and focused runs yields a union RGB difference rectangle **[4, 673, 1276, 720)**, wholly inside the lower control strip. Every upper region **[0, 0, 1280, 656)** is byte-identical. These are pixel comparisons of the same synthetic fixtures, not acceptance of every authored scene or background.

`diagnostic-summary.json` records exact SHA-256 values for original/focused PNG files, reshaped PNGs, input manifests/logs and identical upper-region RGB bytes. Its per-control entries preserve the measurements establishing the 90-control claim.

## Cloud provenance and limitations

- Diagnostic source `93e934b88a5ac1caaa111cdddd280b8122647090`, run **37183839755**.
- Candidate `9df331`, run **37184063851**, failed on a GDScript test-variable parse error. It is not accepted evidence; the variable was corrected before rerunning.
- Focused source `84ba09ddc8c7009f6618111e4e56dd3545428c16`, run **37184176470**: 25 rendered samples and 633 reading cases passed.
- Localization source `c54401807db2dedd7dbd754e940401c50b166e95`, run **37184396640**: 154 cases passed, including 12 rail tests.
- Initial PR source `69138a20a6923b808f60da393fdaae4647221aa3`, run **37184566351**, passed the native caption action but stopped on a stale public-surface caller line number. Dependent broad jobs did not run.
- Cloud inventory regeneration run **37184831148** checked out exact source `69138a20a6923b808f60da393fdaae4647221aa3`. Only the GameState dynamic `day` reference moved from `render_delivery_dialogue.gd:366` to `:384`; SaveManager inventory was unchanged. Published blob `0a27c210b2ffd452358e4607473fecbd7431a5e5` matches the generated artifact.
- Inventory-corrected PR source `027e90b664b6a75f0740defb20eae9735498b2c1`, run **37185050289**, is tracked by the final acceptance receipt. Runtime and test files are unchanged.

The focused, localization and final PR versions of the three affected runtime/test files have identical SHA-256 values (verified with `git show`). Auxiliary workflow/diagnostic runner differences do not change those files. Cloud case totals above were supplied by the coordinator; this reviewer independently checked the local rendered results and image geometry. No Godot or PowerShell was executed locally.

| Source file | SHA-256, identical across the three candidate sources |
|---|---|
| `scripts/ui/witnessed/WitnessedTransportRail.gd` | `f750a33fb4afdbc842414f5f98d7aea0bd54ff066aacc47a4d2e32c2ef80ff7e` |
| `tests/unit/test_witnessed_transport_rail.gd` | `be31475abcecf6363a133467d7865f79b7573db3d06d357639500faad3fd77e3` |
| `tests/ui/render_delivery_dialogue.gd` | `1da6db3d3b403dbb6916e2513d3f5d2c8982d2893e4ee1f3ba94c83da88e1f50` |
