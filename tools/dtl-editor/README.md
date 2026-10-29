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
