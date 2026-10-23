# Compact Gallery media and descriptions

This increment adds the registration and rendering path for the user's chosen
compact archive, following section 6 of the active
[Gallery disposition](../../docs/design/2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md).
The baseline is `e743b2ecc`. Exact final sources are listed in `source-sha256.json`.

## Behavior

- `GalleryRecordCatalog` accepts authored record defaults and exact presentation
  overrides. Full canonical signatures are validated once and bound to their
  actual Gallery record. Invalid types, fields, identities and duplicate exact
  signatures invalidate the metadata catalog. Returned copy is detached.
- The selected reached version projects its localized sentence and optional
  asset ID. Omitted override fields inherit; explicit empty fields suppress.
  Unreached, empty and unavailable records cannot expose those details.
- The existing art loader accepts only an actual 258 by 78 export. A paint-only
  Node2D draws it at exact 2x with nearest filtering inside the 520 by 160 logical
  aperture. The title begins at logical y=176 when media exists and y=0 when it
  does not. Missing, unregistered and wrongly sized exports reserve no space.
- The image has no Control, focus, hit area or assistive target. Title, sentence
  and existing actions retain one bounded scroll body. Version changes and
  refreshes do not alter Profile bytes, discovery, exact selection or playback.

Shipping registrations remain empty. The coloured SVG and short descriptions
are test fixtures only. The [artist guide](../../art/README.md) explains where
to install authored exports and register their localized copy. This increment
does not supply story content or alter persistence, chronology or Minesweeper.

## Verification

- Final Windows/OpenGL probe: **18 tuples, 95 images, 1,108 checks, exit 0**.
- The 15-suite GUT regression covered **112 tests**. All 101 tests outside the
  inventory suite passed; the sole failure was its stale generated SaveManager
  reference inventory. After regeneration, the complete inventory suite passed
  **11/11 tests, 344 assertions, exit 0**. No behavioral changes followed the
  regression. The 24 existing Dialogic orphan nodes remain.
- Fresh independent source review found no further concrete blocker.

`runs.jsonl` and `logs/` retain all ten terminal attempts, including the initial
image-drawing argument-order error, its failed dependent tests and the stale
inventory failure. Editor import returned zero despite the parse error; its log
is retained, and that import is not treated as proof of a successful build.

The native probe exercises English, Simplified Chinese and Traditional Chinese,
100/125/150 percent text, and AfterHours/Midnight. It verifies exact aperture
edges, the authored one-pixel border, the unchanged red/teal pixel boundary,
localized sentence ink, missing-image collapse and unchanged player state.
It also retains the prior retry, action focus and bounded-paper checks.

The focused integration uses real Profile/localization with in-memory file
operations. Switching versions alternates between inherited artwork and an
explicitly absent image, detecting stale media as well as stale descriptions.
Windows screen-reader output and physical touch hardware are not certified.

`inventory-review.json` verifies that generated public inventories change only
lexical references. Protected implementation, tests, schemas, Beads and
worktrees are untouched. `sha256.json` and `source-sha256.json` are checked
against staged Git blobs before publication.

## Remaining scope

`dwm-7wj` stays in progress. Authored descriptions, exact archive exports,
meaningful version cues, the chronological witnessed register and full assistive
and release acceptance remain. Durable completion chronology belongs to the
excluded persistence work; no ordering was invented from signature hashes.
Existing Practice and reached-date replay remain available.
