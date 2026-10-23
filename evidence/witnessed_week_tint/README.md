# Witnessed run-presentation evidence

Witnessed captions and art-only scenes now read the installed run palette and day
at scene boundaries. Room materials use the existing sixteen Witnessed tuples
and shared WeekTint curve. Text and focus roles remain fixed, High Contrast has
zero amplitude, and CVD changes affect lightness only. Future-run Dark Mode
preferences cannot override the installed run. Live accessibility changes use
captured context without querying gameplay or persistence.

The mapping and exact compatibility scope are in
[witnessed-presentation-tuples.md](../../docs/design/current-ui/witnessed-presentation-tuples.md).
Day 1 caption tuples remain exact. The art-only surface previously used a
hardcoded backdrop and engine button material; its new authored backdrop,
footer and Continue material intentionally change those pixels. Paintings are
not tinted. Continue geometry and narrative transport remain unchanged.

The reviewed five-suite run passes **50/50 tests and 8,284 assertions** in
**18.2 s** (`witnessed-presentation-reviewed-20260913.log`). It covers all
16 tuples × 7 days, fresh and reused native Dialogic layouts, installed versus
future-run mode, invalid contexts, live accessibility, retained captions, scroll,
focus and a real pending mouse accept. Existing caption runtime tests cover
locale/text-scale and input behavior. Art-only tests keep the real imported
texture, token and Continue control through live recolouring and actual Bridge
suspend/resume. Continue regains focus on the next admitted processing frame;
direct cover/restore alone has no immediate focus-restoration contract.
After the final test-only isolation guard, the new integration suite also passes
independently: **6/6 tests, 124 assertions**
(`witnessed-run-presentation-guarded-20260913.log`).

Both current public inventories were regenerated after the final source/test
edit. Live byte reproduction and documentation validation pass **14/14 tests,
410 assertions** (`witnessed-inventory-and-docs-20260913.log`). Historical
evidence gates remain for the parent epic's single final reseal.

Six inspected Windows/OpenGL3 captures pass **105 checks** at 1280 × 720
(`witnessed-week-tint-native-typed-20260913.log`, `measurements.json`). Five mount
the installed Dialogic caption controls with synthetic English text at 100%,
including retained captions and a manually scrolled overflow. One mounts the
real art-only surface with a known synthetic pink image. Day 1/High Contrast
flat roles, focus rails, solid glyph interiors and the sampled art colour are
exact RGB8. Only computed room colours allow at most one RGB8 channel level.
The unchanged Day 1 and Day 7 protected-copy interiors occupy 744 identical
pixels. These samples do not certify all authored story content, physical-input
or assistive-technology acceptance. No player storage was used.

The broader seven-suite run is **62/68**, with six failures independently
reproduced on unchanged source base
`f8da0266043996e5d4343ab6d6cfb8420ff4d722` (**43/49** baseline):
five physical-owner Hospital fixtures still expect a caption for empty context,
where the accepted rules now use a fainting notice; one Dating fixture expects
the old worksheet minimum height. Both logs are retained. `dwm-1tg` owns their
repair against current contracts. This increment does not change production
behavior to satisfy those stale fixtures.

The first focused attempt caught fixture typing errors and an empty-locale
compatibility issue in the legacy art-only entry point. Its former English
fallback was restored; the new presentation API remains strict. The second
attempt exposed a trailing-space fixture mismatch and an incorrect immediate
focus expectation for the direct cover/restore helpers. The final tests instead
check live colour retention and the real Bridge Pause focus path. The first
native attempt caught one untyped filename expression; the corrected capture
executes all six samples. Failed logs remain alongside passing evidence.

The final scene run retains 1,008 existing Dialogic/GUT orphan notices. The
native log retains existing Unicode/NUL diagnostics; no script/load errors
remain in successful runs. Log copies trim trailing whitespace and blank EOF
lines. `runs.jsonl` records exact isolated invocations and outcomes.

This increment is `dwm-vky.11`. Minesweeper presentation, Steady Interface,
Drift Deck compatibility and projection, remaining all-input work, and the
final historical evidence reseal remain separate. The parent UI epic and the
expanded goal remain active. Concurrent Minesweeper latency work in `dwm-634.2`
is untouched.
