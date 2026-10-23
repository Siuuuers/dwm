# Gallery record paper verification

This increment follows the user's compact written archive choice and the active
[Gallery disposition](../../docs/design/2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md), sections 6, 8 and 9.
Production checkpoint: `01932be70`, based on externally merged main `a3dcb775f`.
The final regression also updates an older test's fixed selector geometry to the
new paper-relative layout. Exact final files are in `source-sha256.json`.

## Result

- One clipped 520 x 512 logical record paper at (392, 32). Full natural title and
  optional sentence share its content; absent content reserves no geometry.
- Existing version selection and Practice remain in the same scroll body, 32
  logical pixels after text, with detached focus clearance. Replay stays in its
  pinned dock. These capabilities remain available pending the register.
- Overflow alone supplies the Record details focus target, native scroll role,
  value/range/actions, and paint-only position witness. Fitting paper has no
  pointer scroll target, focus target, named scroll region, or witness.
- Wheel (including fractional factors), pan, touch drag, keyboard, D-pad and
  repeating left stick clamp immediately. Held keys and Accept stay owned at
  boundaries. Native buttons forward touch/pan to the paper; scrolling changes
  neither focus, the exact reached signature, Profile nor playback.
- Same-record refresh and replay retain the paper offset. Locale/size changes
  clamp and minimally reveal a focused retained action. Different records start
  at the top. Removed or no-longer-overflowing targets repair focus to the record.
  Pointer focus stays hidden across refresh/replay; keyboard input reveals it.

Godot 4.6 native APIs provide focus visibility and accessibility; there is no
new global input modality service or persistence format. API references:
[Control](https://docs.godotengine.org/en/4.6/classes/class_control.html),
[DisplayServer](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html).

## Verification

- Final Windows/OpenGL native probe: **18 tuples, 77 images, 890 checks, exit 0**.
  English, Simplified Chinese and Traditional Chinese; 100/125/150 percent text;
  AfterHours/Midnight. Six 150-percent samples also prove overflow focus, top/end
  witness, clipping, retained action visibility and fit-state absence. The prior
  retry/action pixel, pointer-cancellation and exact-signature checks remain.
- Final GUT regression: **99/99 tests, 7,128 assertions, 13 suites, exit 0**.
  Includes nine paper input/layout tests and eleven real Gallery navigation tests.
  The 24 pre-existing Dialogic orphan nodes remain; this is not a full-game test.
- Independent read-only review found no remaining blocker after observed focus
  and input routing defects were fixed. Windows screen-reader output and physical
  touchscreen hardware are not certified by these routed-event tests.
- Both generated public-surface inventories retain exactly the same symbols and
  contracts. Only lexical references changed, including references from the
  other owner's already-merged performance work; see `inventory-review.json`.
  No excluded implementation, tests, schemas, Beads or worktrees were edited.

`runs.jsonl` and `logs/` retain all twelve terminal runs, including intermediate
failures. These exposed focus-retirement ordering, hidden-focus publication and
Accept release handling, touch drag stopped by a native button, a GDScript type
inference error, and outdated test geometry. One fixture's Unicode expectation
and one captured scalar test counter were corrected. Final native images and
report are under `native/`; the earlier native run is retained as a log only.
All engine runs used the isolated wrapper, serialized against other Godot jobs.

`sha256.json` hashes this evidence set; `source-sha256.json` hashes final source
and inventory inputs. Both manifests are checked against staged Git blobs.

## Remaining Gallery scope

Long copy is confined to `tests/support/GalleryLongRecord.gd` and test projections.
Shipping content still has only the existing provisional titles. Authored short
descriptions, exact compact Gallery exports, meaningful version cues and durable
completion chronology are not supplied by this increment. The current version
selector and reached-date replay/Practice remain. The chronological witnessed
register, complete assistive audit and full Gallery release acceptance stay open
on `dwm-7wj`. No record ordering was invented from signature hashes.
