# Witnessed caption accessibility palettes

This extends the seven existing caption material roles to all sixteen AfterHours/Midnight, Standard/High Contrast and Standard/Protan/Deutan/Tritan combinations. The accepted witnessed dossier supplies the two Standard masters and calls the other fourteen tuples provisional. This is an authored caption-role extension using existing registered colours; it does not establish acceptance of the complete witnessed family, its unimplemented rail, authored art or assistive technology.

The literal source is `scripts/settings/SettingsPaletteRegistry.gd` at commit `26de279be5f6490ff453db359b1964ec10596962`, blob `5954ae68db2c36794506f242dac5bbad0c2a93b1`. The source worktree matched that blob during this checkpoint. The witnessed registry owns a detached literal table, with no runtime dependency on another worktree or a generated colour transform.

| Caption role | Source semantic role |
|---|---|
| field | face |
| deep | habitat |
| current | inward_preview |
| text, focus_outer | ink |
| rule | structure |
| focus_inner | focus |

`inward_preview` represents the same registered inward plane used by the existing current caption. It is not substituted with a worksheet role. Both existing Standard appearances, licensed fonts and fixed geometry remain exact.

The real profile publishes `preferences.accessibility.high_contrast` and `preferences.accessibility.colorblind_mode`. The explicit legacy-value mapping is `none` to `standard`, `protanopia` to `protan`, `deuteranopia` to `deutan`, and `tritanopia` to `tritan`. No new preference or captured-run palette owner is invented. The caller still supplies AfterHours/Midnight explicitly.

A complete tuple is validated before presentation mutation. Pure colour changes must retain caption scroll, focus, reveal, history and pending input; they should not trigger a layout pass. Locale and text-size changes keep their existing remeasurement path.

Contrast checks use the sRGB relative-luminance formula and unrounded comparisons against 4.5:1 for text and 3:1 for functional marks, following the [W3C text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) references. These checks concern the used caption pairs; they do not claim complete WCAG conformance or perceptual validation for every user.

The initial real-profile RED run passed 26 of 27 tests and 1,165 of 1,204 assertions, exit 1 (`witnessed-palettes-red-20260906a`). Its 39 expected failures showed unchanged caption colours and missing tuple projection after real profile publication. The corrected focused run passed 27 tests / 3,522 assertions (`witnessed-palettes-green-20260906a`), including the 144-combination state matrix, deferred mounting, atomic invalid-preset refusal and a click held through all four High Contrast colour-vision publications and Standard restoration.

An independent literal audit compares the new file directly with the pinned Git source: all 112 role values match. All 144 checked role-pair ratios pass their unrounded thresholds. Minimum text contrast is 9.0716783:1 (13.7537290:1 in High Contrast); minimum registration contrast is 3.2508408:1 (6.3691042:1 in High Contrast). The minimum inner focus-rail contrast is 4.7111130:1. See the source hashes, exact tables and individual ratios in [`literal-contrast-audit.json`](../../../evidence/witnessed_palettes/literal-contrast-audit.json).

Durable palette task: `dwm-eei.16`. The complete witnessed family remains open under the parent UI goal.

The first GPU run produced all 148 primary captures plus three unfocused overflow references and reached its final verification marker. Independent image analysis found all 144 unique combinations, minimum sampled text contrast 8.9809678:1 and minimum sampled structure/focus contrast 3.2508408:1. All eighteen Standard captures are pixel-identical to their prior `evidence/witnessed_stack` counterparts. Representative English High Contrast/Protan, traditional-Chinese Midnight High Contrast/Tritan, and simplified-Chinese High Contrast/Deutan overflow captures were visually inspected. Unassisted shutdown then stalled. The exact isolated renderer was explicitly terminated after identity checks and a graceful-close diagnostic; its invocation receipt records exit -1. These are completed image checks, not an exit-0 GPU run. The cause is unresolved; no change to production cleanup is inferred from a sleeping native thread.

Final headless regression verification passed **170 tests / 4,991 assertions across eleven suites**, exit 0 (`witnessed-palettes-final-20260906a`). The installed addon retains its known constructor overhead of 24 orphan subsystem objects per handler, 672 in this run including the application handler. Existing certificate-store and Unicode-NUL diagnostics remain; there are no script errors. A separate single-tuple diagnostic using the same mount/capture/restore code exited 0 (`witnessed-palettes-probe-20260906a`); it does not replace full-matrix acceptance or establish the stalled-run cause.

The repeated full GPU run `witnessed-palettes-render-20260906b` completed all 144 combinations, three overflow cases and one empty case and **exited 0 without intervention**. All 151 images are pixel-identical to the first run, and all eighteen Standard images remain identical to the earlier stack checkpoint. Final captures, framebuffer measurements, literal audit, image comparisons and all six invocation receipts are retained in [`evidence/witnessed_palettes`](../../../evidence/witnessed_palettes). The first run remains recorded as exit -1, and its unexplained shutdown stall remains open as `dwm-eei.17`; the clean repeat does not establish its cause or a fix.
