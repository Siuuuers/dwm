# Gallery action feedback

Base: `c51140e6c47466f5376b86e1d1da4c8213cce095`. Independent `dwm-7wj`
correction under the active August 24 Gallery state disposition.

Enabled Gallery actions previously inherited empty focus, hover and press
styles. Replay, the current version selector, Practice, and standalone Return
now opt into contextual state paint: a leading hover rule, upper press rule,
and detached double focus outline. Paper and footer use their respective ink
and focus roles. Zero content margins preserve the action and text geometry.
Generic buttons, custom record rows and the retained Practice host keep their
existing paint. Hosted Return remains shell-owned.

## Verification

- Native behavioral RED proved missing outer/inner focus rings on Replay and
  the plural selector. One intermediate extension used native screenshot
  coordinates for logical viewport input; its two pointer failures are retained.
  The corrected probe verifies actual hover/held state before checking pixels.
- Final Windows OpenGL capture: **18 locale/size/palette tuples, 59 images,
  704 checks, exit 0**. All tuples prove Replay and selector focus pixels and
  unchanged geometry. The first tuple additionally proves real Replay hover,
  held press, canceled outside release, and visible Practice focus. Cancellation
  leaves the selected signature, bridge starts and Profile snapshot unchanged.
  The inherited probe also exercises exact Replay/Error/Retry behavior.
- Regression: **83/83 tests, 6,861 assertions, 12 suites, exit 0**. The same
  24 existing Dialogic orphans remain. Native logs retain three existing font
  NUL-decoding diagnostics; the rendered checks pass.
- Both public inventories regenerated. Only GameState's lexical call-site
  record 51 gains the native probe's minimal Practice stub; no semantic coverage
  claim or protected implementation changed. SaveManager inventory is unchanged.
- Independent source review found no blocking issue. Owned source and evidence
  pass whitespace checking; staged artifact/source hashes are verified.

All seven terminal attempts have logs in `runs.jsonl` and `logs/`, including
failures. RED and final native images/receipts are retained; the earlier green
capture was superseded by explicit Gallery-only theme opt-in. Final source hashes
bind the final native and regression runs, not the historical intermediate
sources. Archived text uses UTF-8 LF and log trailing whitespace is normalized.

The custom style uses Godot's [StyleBox drawing and margin API](https://docs.godotengine.org/en/4.6/classes/class_stylebox.html).

## Limits

This is state feedback, not the compact record-desk cutover. Existing artwork,
version selector and Practice placement are unchanged at this checkpoint.
Physical touchscreen/controller, assistive technology, modality-specific focus
visibility and complete Gallery/release conformance are not claimed. No
`dwm-634*` or `dwm-6fl` implementation, tests, branches or worktrees were changed.
