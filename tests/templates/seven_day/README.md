# Seven-day TEST authoring preparation

`SevenDayTemplates.prepare()` compiles the replaceable captions in
`tests/fixtures/dialogic/seven_day_templates.dtl`, builds the closed registration
through the existing manifest/compiler owners, and calls `SceneSequenceAuthoring`
with the explicit `Day1, Day2, Day3, Day4, Day5, Day6, Day7` order.

The result contains `registration`, `first_target_id` (`target.Day1`), and an
explicit pending `terminal_dependency`. It is offline preparation only: nothing
is installed, no Run is created, and no production narrative is supplied.
There is no intermediate Day1.1 feature and no required Minesweeper challenge.

Replace each TEST caption in the DTL, keeping its stable line ID and labels;
prepare again to derive captions and hashes through the compiler. Each template
currently has one caption. Adding beats requires updating its registered IDs and
marker anchor together. The explicit order controls ordinary-next links;
canonical registry sorting does not control story order.

**Day7's DTL return is not an ending or completed game.** It intentionally has no
terminal marker. The next implementation must resolve an actually registered
ending and supply authenticated, durable scene-to-ending admission through the
existing owners. Do not fabricate an ending target, legacy Day7 eligibility, or
terminal payload to make this preparation appear connected.

Cloud GUT target: `tests/unit/test_seven_day_templates.gd`. Its scope is native
compiler/manifest/contract admission, six ordinary links, seven TEST captions,
explicit pending terminal dependency, and deterministic detached preparation.
Passing it does not prove Title → week → ending → Title playback, save/recovery,
or a clean rendered E2E journey. Those remain separate integration acceptance.
