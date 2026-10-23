# UI and rendered CI triage — run39837646584

Read-only review on candidate d1d8313cff343a46733c021ad9125d6c0702eeff / tested merge3b171dbb60f6edc9cd267e6244f786893b146e76. No runtime or test edits, engine execution, workflow changes, deadline changes, or new acceptance.

## Observed families

| Job | Actual evidence | Cause / bounded next step |
| --- | --- | --- |
| reading_delivery120033199646 | 659 cases,188 failed across25scripts; exact failures in ui-triage-artifacts/reading-failures.json | Many legacy `dating.solo.priscilla.day1.pre_challenge`, legacy ending and hospital entries are absent from current shipped scene registration. Also stale exact playback context (four required keys) and DTL structure assumptions. Restore explicit test-only historical registration for bounded legacy owner tests if supported; do not change shipped registration or silently label all188 as one cause. Coordinate with ending/persistence review. |
| localization120033199703 | 162 cases,18failed:11ordinary reply,5desktop crash recovery,2Japanese/Korean | OrdinaryReplyEchoState._load_registry reads `loaded.value.reply_ids` directly at329 after loading current scene registration, which has no legacy reply list. Its eleven original tests and Japanese/Korean reply fallback case consequently fail. Desktop recovery first fails profile locale preparation with `zh_CN`; delegated to desktop audit. One Japanese/Korean test hard-codes308 while current source has311messages. |
| rendered Hospital120033199504 | Both write processes fail `canonical desktop day did not arrive: 1`; no write-pass marker | Old New Account immediately-to-ComputerDesktop assumption precedes hospital proof. Current game opens a scene. Need explicit supported scene-opening traversal or a genuine test-only legacy initial context, retaining physical save/fresh-process proof; never restore retired health to get here. |
| rendered timed hold120033199521 | `TIMED_HOLD_JOURNEY_FAIL: real New Account activated Run` before hold proof | Same old opening assumption; no successful hold/Pause/fresh-input coverage this run. |
| rendered desktop120033266371 | Invalid Dictionary key1, missing protein_box, array index12; later UI audit10unclassified sinks | Render fixture still indexes now-keyed desktop LABELS by1 and uses retired Shop rows. Independently, some new UI text lacks localization ownership (details below). |

## Desktop rendering fixture corrections

`tests/ui/render_desktop_scaling.gd:448` uses `desktop.LABELS[desktop._locale][1]`; current labels are keyed by app identity, so select the Contacts key. `_shop_samples` at281hovers retired `protein_box`, at283takes `catalog.rows[12]` as lucky_charm, and later hovers retired healthy_meal. Choose current supported item IDs and locate lucky_charm by identity, preserving page-two/sold-out/readable/contrast/art-retention assertions and capture census. This is a fixture update, not grounds to restore retired Shop items. Coordinate with shop audit's separate real production receipt defect.

## Japanese/Korean catalogue census

`test_both_catalogs_cover_all_308_source_ids_and_exact_placeholders` has stale308count. Current311includes the three new scene controls `scene.controls.check_computer`, `scene.controls.close_computer`, `scene.thought.yes`. Last thought addition is8c51e25a; earlier controls f66db40d. Preserve translated key equality, nonempty values, every-placeholder checks and rendering assertions. Update the finite expected source census/title with explicit inclusion of the new IDs, not removal of the coverage checks. The second failed test is ordinary-reply registry coupling, not a Japanese/Korean translation defect.

## Ten UI literal audit failures: ownership updates versus real untranslated chrome

- `SceneHost.tscn:99-100` Yes/accessible Yes is an initializer replaced by `SceneHost._refresh_copy` using `scene.thought.yes` before presentation. It needs exact demonstrable owner markers, not blanket placeholder exemption.
- `SceneHost.gd:88` uses `_localization.t` with a conditional between two registered scene-control keys. The scanner currently rejects that expression. Add path-specific exact ownership or narrowly support this verified conditional lookup while retaining malformed-key/spoof tests.
- `ComputerDesktop.gd:1045` title expression contains the existing five-locale unavailable copy and keyed LABELS. Its exact-expression owner digest is stale after the expression changed. Review/register the exact expression; do not exempt arbitrary locale-looking dictionaries.
- `ArtworkGallery.gd:78,80,100,101,136` has actual English-only UI chrome: Locked, Locked artwork, View…, empty/unavailable/click guidance and H/Esc hint. It has no localization owner in the inspected source. Correctly route chrome through existing locale presentation/catalog patterns; artwork IDs may remain runtime identity but should not excuse these English literals. Do not mark all as runtime_data merely to pass.
- `PauseSurface.gd:89` hardcodes Back. `_apply_copy` updates title/actions/question/warning but never this button, so it is a real untranslated control, not an overwritten initializer. Add owned back copy through existing presentation contract or existing localized service; preserve focus/return behavior.

No product design question is established by these failures alone. The choice of keeping old legacy fixture coverage separate from shipped scene qualification should follow existing supported test injection contracts, with the parent integrating one coherent approach. Actual current player chrome localization is a bounded product correction, not a test-waiver task.

## Original artifacts

All downloaded archives verified provider SHA256, ZIP CRC and safe member paths; originals retained locally in ui-triage-artifacts. These have not been uploaded into repository evidence by this audit.

| Artifact | ID | bytes | SHA256 |
| --- | ---: | ---: | --- |
| reading |12451438164|213048|24c933867ce8b84eb25b5ea7efb3fd54e0856c317b91c4ac9413ea675863e290|
| localization |12452840514|371718|f031a970e9aa53daae44aa3d9887ec6289cc2722efc37613ab8f4584ae58ed52|
| Hospital |12451583035|71364|ea7c410face846489f0b32f348ba1be802d55ea81b1c0623d64de8866501046b|
| timed hold |12452905314|33312|2f4d1ee86bfdce92da7f1af5faf42c78fe6118ca37ee96eca9b10968ac3daa72|
| literal audit |12453045045|30859|23edb969d59d6d63da3f4f3f0e3d3fb44c776a5823cd75397b5ccebb652cf73d|

Desktop-render job logs were inspected, but its12.5MBimage artifact was not downloaded or visually reviewed. No screenshot acceptance is claimed. Five remaining tests/entire journeys are not treated as passed on similar source alone.
