# Witnessed run presentation

The existing [Witnessed palette registry](../../../scripts/ui/witnessed/WitnessedPaletteRegistry.gd)
retains its sixteen exact seven-role literal tuples. Its `resolve()` lookup is
unchanged. `resolve_tinted(palette, high_contrast, colour_preset, day=1)`
returns a separate colour-only projection for days 1–7. Unknown tuple keys or
out-of-range days fail rather than falling back.

| Witnessed role | WeekTint room role | Treatment |
| --- | --- | --- |
| field | face | ages |
| deep | habitat | ages |
| current | inward_preview | ages |
| rule | structure | saturation ages in Standard |
| text, focus_outer | authored ink | protected |
| focus_inner | authored focus | protected |

Day 1 returns the shipped tuple exactly. High Contrast has zero tint amplitude;
CVD presets receive lightness-only deltas, so their structure rule stays exact.
The caption theme's `build()` accepts `day` after `large_targets`, preserving
the former six-argument Day 1 call. This projection changes no fonts, leaf
geometry, caption text, Dialogic event, History, reveal, scroll, focus owner,
or pending Accept. [WitnessedArtLayer](../../../scripts/ui/witnessed/WitnessedArtLayer.gd)
and its paintings remain unfiltered.

The caption layer reads the installed run's mode and day when it mounts and when
a new timeline starts. The art-only hold reads them when it mounts. Both use
the same read-only boundary helper; a future-run Dark Mode preference cannot
replace the installed palette. Live accessibility changes use the captured
context without querying gameplay or persistence. An absent or invalid run
leaves the current presentation intact, including standalone Day 1 previews.

The art-only hold uses the same seven roles: field backdrop, deep footer,
current Continue face, rule border, protected text and outer focus ring.
Its Continue stays 384 × 48 at (448, 656); an 80-pixel footer contains the
expanded focus ring. This replaces the former hardcoded backdrop and engine
button material, so full historical art-hold pixel identity is not claimed.
Colour changes retain artwork textures, token, button, neutral-input guard
and Pause state. Only the existing text-size change resizes the art aperture.
Production Pause restores Continue focus on the next admitted processing frame;
the direct view cover/restore helpers only restore visibility and identity.

The unit check covers all sixteen tuples across seven days using the actual
current, retained-leaf, seam, focus, and shared-scrollbar colour pairs. Real
Dialogic tests and native samples are recorded in
[the evidence report](../../../evidence/witnessed_week_tint/README.md).
Physical-input and assistive-technology acceptance remain separate verification.
