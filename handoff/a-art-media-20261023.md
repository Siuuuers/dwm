# Five-picture Gallery and separate music handoff

Product source: `82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc` on
`codex/art-media-20261023`. Builds on the completed seven-DTL template milestone.
Master remains `41592fcc792aa615e47ee2ce2f05008ca195b311`; no merge or release.

## Player behavior and replacement paths

- Five replaceable JPGs: `art/pictures/picture 1.jpg` through `picture 5.jpg`.
- Picture1 left Days 1–7; picture 2 right Days 1–3 (Day 2 temporary default);
  picture 3 right Days 4–7; picture 4 and picture 5 Gallery-only.
- Gallery artwork unlocks at the first witnessed caption: Day 1 pictures 1/2,
  Day 2 picture 4, Day 3 picture 5, Day 4 picture 3. Existing durable visited-line
  history owns this projection; clearing that history relocks artwork.
- Existing Gallery Records remains default. Artwork tab offers thumbnails,
  right preview, full-window proportional artwork, H hint toggle, Esc return.
- Title uses `audio/bgm/menu_theme.ogg`; story uses `audio/bgm/story_theme.ogg`.
  Both are independent, loop-enabled copies of the same original eight-second
  quiet synthesized placeholder. Original bytes SHA256:
  `97390a627b08151cc5c566e16dd1b3a34428f368e5b4651b9b282c58db179cd4`.
- Replacement instructions: `art/pictures/README.md`, linked from `art/README.md`
  and `tests/templates/seven_day/README.md`. Rebuild registration after changing
  story music; its digest and duration are authored content identity.

## Ownership and compatibility

ArtManifest owns placement; existing SceneArtView split rendering is reused by
the seven-day caption layer. Gallery reads ProfileManager and writes no unlock
or save schema. Audio catalogue v2 admits one music OR ambience bed, routed
through the existing AudioManager players. Catalogue v1 remains unchanged;
saved scene-audio snapshot shape remains v1. Save/recovery/history owners are
unchanged. This new content fingerprint does not migrate old presentation saves.

The exporter explicitly retains original story OGG bytes for digest verification,
alongside the native imported looping stream. Runtime package audit hashes them.

## Verified cloud evidence

All engine/PowerShell execution used Windows cloud runners and official Godot 4.6.3.
No local Godot run. Existing120/240-second child deadlines were preserved.

1. Run 39823628664, source 96999b674dea4cdaabeb8f44e57caa7aad3cfdc9:
   three template tests/83 assertions; thirty music tests/315 assertions passed.
   Gallery focus assertion failed (114/115); other audio/template qualification
   was retained, not repeated after the isolated Gallery fix.
2. Run 39824610874, source 82d42d3524ac0cdcc90e7c7ae7f69298d5046bcc:
   Gallery 3 tests/116 assertions passed, including five real imported pictures,
   all seven day mappings, persisted unlock projection, preview focus and real
   H/Esc input dispatch. Connected 2 tests/336 assertions passed: New Game to
   Day 4 save, fresh-process load, witness/save/Back, Days 5–7, durable ending,
   Title and New Game. Before/after source custody passed. Native registration
   and all runtime imports equal the committed product. Screenshots visually
   reviewed: readable Gallery preview and artwork-only fullscreen with hints.

Together these cover 38 distinct targeted cases/850 assertions. No claim of a
full-game or performance audit. Broad controller Windows CI uses its existing
different source and is not acceptance evidence for this isolated product branch.

First run 39823188668 caught corrupted audio transfer before gameplay tests.
Corrected transfer was verified against the local Git blob and SHA256. Import
stderr checking was tightened. Gallery fix explicitly enables preview keyboard
focus; its fixture also settles deferred entry focus and hides the GUT diagnostic
overlay for unobscured captures. Final assertion was retained.

3. Windows export run 39825608353 passed on the same product source 82d42d3.
   PCK audit verifies 123 runtime data files including the original story OGG.
   Isolated exported executable startup passed (headless 240 iterations); this is
   not a second full graphical journey inside the exported executable.
   Artifact 12445803960 expires 2026-10-29:
   https://github.com/Siuuuers/dwm/actions/runs/39825608353/artifacts/12445803960
   Inner `DWM-windows-x86_64-validation.zip` is 105649772 bytes, SHA256
   `8420129c411b82051432ba01aebbb4ab62a0d2c2519ce0fd8934885945796f28`.
   Outer artifact ZIP SHA256
   `a6bf581cefe0da259918bd8fd6065796daabeed29d46811fcbe79618b9167fd9`.
   Final package source custody passed.

Compact JUnit, selection/unchanged-owner receipts, aggregate results and export
receipt persist under `evidence/phase_2r/art_media_20261023/results/`.
Full logs/screenshots remain in the expiring Actions artifacts.

Qualification artifact 12445508987 (run 39824610874) expires 2026-10-29.
Music/template evidence artifact 12444864417 (run 39823628664) expires 2026-10-29.
Source, test bodies, hashed PowerShell packet and this handoff persist in Git.

## Next work

Replace placeholder art, music and DTL text using the guide; rebuild and export.
Keep current scope small. No additional generic verification, redesign or
performance surgery is required by this handoff. Do not repeat completed cases
unless a concrete changed behavior invalidates their evidence.
