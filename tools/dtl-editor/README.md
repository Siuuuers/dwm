# DTL pocket editor

Open `index.html` in a browser. It is one self-contained offline file: no server,
installation, accounts or uploads. Import a UTF-8 `.dtl`, click a caption, choose a
quick control, fill its fields, then insert. The text area is the exact DTL preview.
Edit or delete text directly; Undo edit restores up to 50 changes. Export downloads
the file with its original name. Export before closing; there is no autosave.

Quick controls insert plain labels, scene/background/show/hide artwork cues,
music/change/stop, one-shot SFX and checkpoints. Existing source comments, unknown
syntax, stable IDs and untouched line endings remain unchanged. UTF-8 BOM is
retained. New lines use the file's first newline style. Insertions require a caption
with a stable `#id:` marker. A caption and its adjacent `# self-talk`/thought are
kept together; a new label goes before any preceding cue block. Existing broad
Dialogic label syntax is preserved; newly created labels use project semantic IDs.

Use catalogue IDs, not filenames: scene preset, background asset, overlay preset,
slot, music or SFX as appropriate. A label alone does not register a story entry,
Gallery item or checkpoint. Story metadata remains editable as ordinary text.

Feedback checks the supported cue fields and duplicate labels in this file. It
does not compile DTL, validate project assets, cross-file jumps or story metadata.
It does not block export of a work in progress. Run the existing cloud exporter
and validation before shipping. The preview does not simulate Godot rendering.
See [story authoring](../../docs/agent/dtl-story-authoring.md) and
[audio authoring](../../docs/agent/dtl-audio-authoring.md).

`node tools/dtl-editor/test.cjs` runs focused source/placement checks without
dependencies. `node tools/dtl-editor/test.cjs --browser` additionally requires
Playwright and its Chromium browser. The cloud workflow retains desktop/mobile
screenshots and an exported real Day1 fixture, then checks that fixture using the
existing Godot project exporter. It never changes committed game content.

Writing guidance aims for one source caption per visual row. Choose the source's
writing language; this never translates or changes it. Captions and thoughts use
separate reference widths. A diamond beside a source line is a gentle editorial
notice: focus it with the keyboard or point to it for the explanation, and activate
it to return to that line. The current source line also shows its visible-character
count. Notices update after import, edits and undo, and never prevent export.

The self-contained page embeds `readability-profile.json`; their equality is
checked by the tests. A profile marked `pending` deliberately applies no length
targets. Measured profiles use 125% text at the 1920 × 1080 reference presentation,
with one conservative range per language across Pixel and Readable fonts. The
lower end is an editorial target, not a guaranteed maximum; font shaping, words,
punctuation, mixed scripts and panel resizing can change the result. The profile's
revision and evidence fields identify the renderer measurement provenance.

Counts use browser `Intl.Segmenter` grapheme clusters, including spaces and
punctuation. The supported source form is a plain escaped DTL text line, with
optional stable `#id:`. IDs, the initial escape and escaped colons are excluded. An adjacent
`# self-talk` selects thought guidance. Source continuations, draft markup and
dynamic text receive a review notice without a character target. Authored BBCode
is not interpreted or stripped: the current scene compiler admits plain prose,
not that formatting syntax. Draft export remains available for correction and
project validation. This page does not recreate Godot shaping or claim exact rows,
clipping, or pixel-width percentages. Use a modern browser with `Intl.Segmenter`.

Refresh after a font or layout change by running the Readability measurements
workflow, inspecting its captures, then running
`node tools/dtl-editor/update-profile.cjs path/to/results.json`. This regenerates
both the versioned profile and offline copy from the renderer's boundary strings.
Add `--check` to compare the current measurements with committed ranges without
rewriting either file.
