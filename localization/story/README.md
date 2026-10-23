# Authored-week localization

The seven English timelines under `dialogic/timelines/authored_week` are the
unchanged PR #43 story. The author approved bringing that story and its required
choice/Challenge support into `codex/playable-master-integration-20261023` on
2026-10-23. Existing artwork and Bach recordings are retained.

Each JSON file is an object mapping stable `line.*` caption IDs and
`choice.<opportunity_id>.<choice_id>` option IDs to display text. There are 1,666
captions and 16 option labels per language. `en.json` must match the DTL and
registered choice text exactly. Supported translations are `zh_HK` (Hong Kong
standard written Traditional Chinese), `zh_CN`, `ja`, and `ko`. Character names
retain Latin spelling. Preserve viewpoint, ambiguity, clues and character voice.

`StoryLocalization.gd` applies translations at the display boundary. Dialogic's
text parser receives a translation for the current stable line; native event
text, registration hashes, line IDs, receipts and saved ledgers remain English.
History and retained captions receive translated copies of the same admitted
rows. An absent translation or mismatched English source falls back to English.
Changing language repaints the current caption without advancing the story.
Bundled fallback fonts cover the story’s CJK and Romanian glyphs. Crossed-out
clues receive presentation-only strike markup while retaining their plain text.
Read-aloud identifies the displayed language; it still requires an installed voice.

This replaces the previously deferred narrative-adapter decision for these
authored-week captions only. It does not localize unused placeholder timelines,
rewrite earlier story variants, or change Steam packaging. Bringing the authored
week into the template branch changes content fingerprints; use a fresh run for
this story. The translation catalogs themselves do not change those fingerprints.

The scene compiler reuses detached results only for identical current source
bytes and semantic arguments; it still reads the source on each proof. The
recursively frozen registration fingerprint is computed once. These bounded
caches avoid repeatedly parsing all seven timelines during save validation.

Validation:

```sh
python tools/localization/validate_story_catalogs.py
# Use an isolated DWM_TEST_ROOT under .godot/phase2r_tests.
# In cloud tests, put XDG_DATA_HOME under /tmp, outside workspace synchronization.
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig= -gtest=res://tests/integration/test_story_localization.gd -gexit
```

The native test covers actual captions, live switching, History, all bundled
font sizes/styles, unchanged checkpoints/receipts and save/load. With a graphical
display it also captures one enlarged-caption screenshot per translated locale.
Translations are authored drafts, not a claim of independent native-editor review.
