# Readability and DTL editor guidance handoff

Date: 30 October 2026 (Hong Kong)
Status: agreed implementation direction; documentation only. No new runtime changes or measurements are claimed.

## Purpose and scope

Implement together:
1. Remaining UI readability/clipping fixes at 125% and 150%.
2. DTL pocket-editor guidance grounded in measured Godot gameplay text layout.

Include the requested borderless default as a small separately verifiable display change.
Defer glass/thread/wax redesign and broad interaction redesign. The owner permits future code-only texture, composition and layout exploration; those are outside this handoff.

PR #158 is merged as 3ce9be69a6534ea619f3445cf35a0ea86b0b64a8. It already addresses Reading typography, 125% defaults, Beginner Challenges, Shop balances and measured Shop/Save–Load text. Reproduce remaining issues against current master; do not treat previous fixes as undone. Read AGENTS.md, CLAUDE.md and relevant current contracts before implementation.

## Owner decisions

- Main visual target: 1920 × 1080 full-screen presentation.
- Borderless should be the default. Apply to fresh profiles and explicit reset-to-default behavior; preserve existing saved display choices. Locate the canonical default owner before editing.
- UI must remain attractive and usable at both 125% and 150%.
- DTL authoring guidance prioritizes 125%; a 150% comparison is optional.
- Measure actual Godot text layout, then derive language-specific approximate character capacity and visually comfortable ranges.
- Editor has both an always-visible compact reminder and gentle per-line notices, preferably a marker near the source line.
- Advice must not block export or silently rewrite prose.
- Preserve the simple offline import/edit/quick-controls/export workflow.

## Display distinction to preserve

Current scripts/display/WindowModePort.gd defines three windowed presets: 1280×720, 1600×900, 1920×1080. Available presets are filtered by usable desktop space plus frame allowance. The current borderless mode fills screen_get_usable_rect(), not necessarily the complete monitor dimensions. autoload/WindowModeManager.gd recognizes windowed and borderless; project.godot has a 1280×720 design viewport and canvas_items stretch.

Treat 1920×1080 as the primary rendering acceptance target, not a forced output resolution for every monitor. Record actual client size separately from monitor size and OS scaling.
Do not silently redefine existing borderless behavior or add exclusive fullscreen merely to obtain the reference capture. If actual full-monitor coverage including taskbar area is needed, present that as a distinct display decision. Existing usable-desktop borderless is the selected default for this slice.
Keep windowed selection available. Check default/reset application, existing preference preservation, mode changes and restoration. The native output adapter currently limits verified physical operations to Windows; Linux rendering does not prove Windows display-mode behavior.

## Measure width, not font points

Font size in points does not establish a line's length. Use shaped text width and available content width in the SAME coordinate space. Keep logical layout units separate from physical output pixels and text-scale percentages.

For an unwrapped source string:
  width use = 100 × shaped text width / available content width

This ratio is a useful one-row indicator, not an exact wrapped-row count. Obtain actual wrapping from the renderer: word boundaries, punctuation, shaping, mixed scripts, fallback fonts and authored line breaks affect rows.

Illustrative explanation only: 600 width units in an 800-unit content area uses 75% of one row. These are not measured game values.

Character counts remain approximate editorial guidance:
- Count user-visible characters/grapheme clusters, including spaces and punctuation, rather than bytes or UTF-16 units.
- Exclude IDs, directives and non-visible formatting syntax.
- Equal character counts need not have equal width.
- Define a measured approximate capacity range per language/font/layout profile. Do not invent one universal hard maximum.
- Choose comfortable ranges through screenshot review of representative prose. Geometry can establish fit but cannot prove aesthetic comfort.
- A wrapped line is not automatically invalid or a clipping defect.

## Measurement and readability work

Capture real scene captions and self-talk separately, in single-language and supported bilingual configurations. Record:
- source revision, font and fallback identities, style and actual font-size parameters;
- locale(s), text scale, client area, logical viewport and scaling;
- panel/content width, padding and divider position;
- visible text, shaped width and actual wrapped rows;
- screenshots and whether anything clips or becomes inaccessible.

Start with the actual currently supported story locales, not assumed language support. Include mixed punctuation/Latin/CJK where relevant, short/long words and explicit line breaks. Use representative text rather than repeated identical characters alone.

Audit Settings, Save/Load, Shop, Gallery/library, History, choices, Challenge toolbar and bottom controls at 125% and 150%. Keep existing caption placement, Save-tag relationship and bilingual spacing unless a reproduced defect needs a scoped correction.
Prefer content-aware sizing/wrapping/appropriate scrolling over shrinking the player's selected text size, truncating required labels or moving accepted controls gratuitously.
Use the 1920×1080 target for primary review; retain relevant 1280×720 and 1600×900 regression checks and narrow panel configurations. Preserve reading position when reflowing.

## Pocket editor implementation

Entry points: tools/dtl-editor/index.html, README.md and test.cjs.
Current editor is an offline self-contained file. Its source preview does not simulate Godot rendering. Existing feedback does not validate all assets, cross-file jumps or metadata; preserve that distinction.

First create a small versioned measurement profile from gameplay. Include enough provenance to refresh it after font/layout changes. Keep caption and thought guidance separate. Avoid a large new layout engine.

Reminder:
- selected language/profile and 125% reference;
- comfortable approximate character range and approximate one-row capacity;
- clear reference to default measured panel width and the primary display target;
- optional 150% comparison if implemented and measured.

Line notice:
- small non-color-only marker associated with the correct DTL source line;
- explanation accessible by keyboard/focus as well as pointer;
- distinguishes exceeding an editorial target from probable layout overflow;
- updates after edits/undo/import, never changes IDs, text, line endings or caption/thought pairing;
- normal valid wrapping does not produce an alarming error.

Width meter:
- Prefer "estimated width used / reference row width" alongside character count when a sufficiently faithful offline measurement is practical.
- Browser rendering is not automatically identical to Godot. Calibrate against the gameplay samples; label estimates honestly.
- Do not claim exact rows or fit from character count or by merely dividing total width by row width.
- If matching fonts/shaping cannot be supplied within the simple offline editor, ship calibrated character guidance first and document the limitation. Do not block the useful first slice on pixel-perfect simulation.
- Changing language selection does not translate the source or fabricate missing translations.

## Suggested delivery sequence

1. Reproduce current remaining clipping; capture reference layout and measurements.
2. Fix confirmed readability defects and the fresh/reset borderless default in small scoped changes.
3. Re-measure final layout; choose comfortable ranges from visual review.
4. Add compact reminder and gentle line notices using those profiles.
5. Validate and publish a concise evidence-backed completion record.

One handoff is appropriate because both tasks share the layout measurements; separate commits keep UI corrections and editor advice independently reviewable.

## Acceptance and test discipline

- No unreadable clipping, overlapping essential labels or unreachable actions in audited surfaces at 125% and 150%.
- Measurements tied to actual renderer/settings, with no invented per-language limits.
- Reference display dimensions and usable-desktop borderless behavior correctly distinguished.
- Fresh/reset default applies; previously saved choices survive. Verify physical output on the supported native backend.
- Editor preserves import/export, IDs, pairing, source formatting and undo; advice never blocks draft export.
- Marker tracks the correct line after edits and is keyboard accessible.
- Representative bilingual and mixed-script samples reveal neither false exactness nor a universal character cutoff.
- No changes to story progression, read/unlock identities, audio or save semantics from layout/editor advice.

Run required Godot/PowerShell work through the repository's cloud workflow conventions. Use relevant existing rendered layout, input, transition and accessibility checks; do not remove coverage just because changes appear visual.
PR #158 records that coverage selection is already sparse/blob-filtered. Measure current overhead before proposing more checkout work. Group short related suites only when setup can be shared while keeping processes/test data isolated; compare wall time and runner-minutes. Avoid unrelated CI redesign in this slice.

## Completion report

Record changed files, implementation PR/commit, tested configuration matrix, before/after captures, actual per-language guidance values with provenance, and remaining limitations.
This handoff contains no completed measurement results and does not authorize claiming the runtime work complete.
