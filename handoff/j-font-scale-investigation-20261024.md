# Font scale investigation — 24 October 2026

The player reports unreadable numbers and widespread corrupt text, especially non-English text at 125% and 150%, in a Steam installation. Readable font mode has not been tested by the player. **The reported defect remains unresolved: none of the cloud captures reproduced it.** Issue #73 was closed administratively because the player did not request a separate issue; that closure was not a fix.

## Observed outcome and ownership

The intended outcome is readable multilingual text and Minesweeper numbers at every supported text size. `scripts/ui/UiTypography.gd` owns font selection and logical pixel sizes; the Settings presentation applies that selection, while the Window and board controls also scale the rendered result. A passing glyph-presence check alone does not establish visual readability.

Pixel mode selects distinct Fusion Pixel 8/10/12 px font masters for 100/125/150%, presented at 24/30/36 logical pixels for a base 24-pixel control. These are WOFF2-compressed OpenType assets. Readable mode uses the regional Source Sans/Han faces. A font file format does not guarantee its glyph coverage or its appearance after rendering and scaling. Renaming percentage choices to pixel sizes would not itself repair corrupted glyphs. No font, default, accessibility option, renderer, or shipping workflow was changed by this investigation.

## Cloud evidence

All execution was on Windows cloud runners with Godot 4.6.3. Native runs used D3D12 Forward Plus on Microsoft Basic Render Driver; the comparison lane used OpenGL ANGLE compatibility. These are not the player's GPU or installed Steam session.

| Check | Exact source and run | Evidence |
|---|---|---|
| Source resource panels, native and GL | `ad82c5f3857bb564a1d670ba7075a5fecc611f3c`; [40090259974](https://github.com/Siuuuers/dwm/actions/runs/40090259974) | Six panels per renderer, Pixel/Readable × 100/125/150%, five locales, production number-cell renderer at 24/36 px. Two clean exits; 60 sample records; no reported missing glyphs. |
| Mounted Settings and Minesweeper | `29711853b93a9c042e042d818fedb613ae3df7bf`; [40091217010](https://github.com/Siuuuers/dwm/actions/runs/40091217010) | 32 captures/samples, one clean exit. Traditional Chinese: both styles × 125/150% × 1280×720, 1600×900, 1920×1080 × two surfaces. English, Simplified Chinese, Japanese and Korean: Pixel 150%, 1920×1080, two surfaces. |
| Retained exported font resources | Diagnostic `8bdf183a89d795743f4e7ab6f10f5586eabc7940`; [40091687370](https://github.com/Siuuuers/dwm/actions/runs/40091687370) | Six panels/30 samples, one clean exit. Untouched `game.pck` from the retained Steam package under the pinned editor executable, with no source project fallback or editor import. All six pixel arrays exactly match the initial native panels. |

The font reviewer inspected every capture. Pixel faces have coarse strokes, but the reported widespread corruption, missing-glyph boxes, and unreadable 1–8 pattern were not reproduced. Readable faces appear smoother. Mounted screenshots also show wrapping, ellipsis and scroll clipping; those are distinct observations, not proof of glyph corruption. The mounted fixture uses production UI and real font preferences with controlled services and synthetic public board facts. Its Settings selectors are invoked programmatically. It does not establish a complete player journey or all offscreen content.

The mounted records confirm actual 1/1.25/1.5 window stretching, production font fallbacks, image dimensions and hashes. The simple panels use 1280×720 SubViewports and do not exercise that window stretching. The resource-panel native/GL comparison differed by at most one RGB intensity unit, without changed glyph shapes. Source/raw font paths are absent in the export as expected; the retained package hashes bind the loaded exported resources instead.

The package came from [export/upload run 40078754096](https://github.com/Siuuuers/dwm/actions/runs/40078754096), runtime `14648617b55a4c67bef7b7cc0d23461f0502f23c`, Steam BuildID 26179529. All 19 packaged files were checked against the retained receipt before and after the probe. The probe ran the editor, **not `game.exe`**, and this BuildID has not been established as the player's installed build. The earlier upload did not set a Steam branch live. The existing master Steam workflow still pins an older runtime; do not dispatch it expecting the latest master.

## Retention and next discriminating evidence

Exact captures, logs, receipts, source snapshots, full original-member manifests and concise audit summaries are retained in [the evidence directory](../evidence/phase_2r/font_scale_20261024). Disposable generated user files are omitted with reasons in the manifests. `mounted-evidence.zip.part01` followed by `.part02`, concatenated as binary bytes, reconstructs `mounted-evidence.zip` (14,567,513 bytes; SHA256 `6b249fd377ea695ee2f701887ff371c2cd3c8ebf79ce068f284638f98103ac0b`). Per-part hashes are recorded in the mounted manifest. The split is only for transport; no original retained member bytes were altered.

Further blind changes to font selection are not justified by these results. The smallest useful player evidence is an original corruption screenshot with the affected screen, locale, font style, text size and window resolution; the installed Steam BuildID (or exact executable/package hashes); and whether switching that same screen to Readable changes the corruption. GPU, Windows display scaling and driver details may then distinguish a device-specific rendering failure. Keep the report open in development records until reproduced or a specifically matched correction is verified.

The separately qualified Save/Load improvement is already merged in [PR #74](https://github.com/Siuuuers/dwm/pull/74); see [its handoff](i-bundle-encoding-handoff-20261024.md). Launch/New Acc attribution continues independently and must not be inferred from these font captures.
