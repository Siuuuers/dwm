# Japanese and Korean UI draft

Japanese (`ja`, 日本語) and Korean (`ko`, 한국어) are selectable draft languages
in Settings → Language, including the secondary-language option. The locale
selection uses the existing profile transaction and survives restart. Pixel is
the default font style for all five languages: English, Simplified Chinese,
Traditional Chinese, Japanese, and Korean. Settings → Accessibility → Font style
also offers Readable; this game-wide choice persists independently of locale.
Profiles without the preference default to Pixel. Switching locale resolves the
chosen style for the new language; it does not restore the former project-default
font. Secondary-language display follows each screen's existing behavior; the
Contacts app currently does not connect its secondary-language preference to the view.

Each new catalog translates all 300 current source UI message IDs. Additional
app-owned controls and accessibility descriptions have draft copy for both
languages. Story dialogue, correspondence bodies, and authored Gallery record
prose retain the existing English fallback; this change does not add story
translations or change narrative identities, gameplay rules, or saved progress.
These translations need native-speaker editorial review before release.

## Font choice and commercial use

The default Pixel style uses the locale-specific proportional flavors of
[Fusion Pixel Font 2026.08.11](https://github.com/TakWolf/fusion-pixel-font/releases/tag/2026.08.11).
This is the same family and pinned release as the Gallery's pixel fonts, now
used for game text in all five languages. Readable uses Source Sans 3 for English
and Source Han Sans for Chinese, Japanese, and Korean. The Japanese and Korean
faces are the official regional JP/KR Regular subsets from Source Han Sans
2.005R; their pinned sources and hashes are recorded in
`assets/ui/contacts/fonts/sources.json`.

The six Japanese/Korean 8px, 10px, and 12px pixel faces are bundled unmodified
with their existing SIL Open Font License 1.1 and upstream copyright notices. The OFL permits
commercial game bundling without requiring the game itself to use that license.
The bundled Source Sans and Source Han faces also retain their OFL 1.1 licenses
and copyright notices. Keep the font licenses and notices in redistributed
packages. See the [official OFL FAQ](https://openfontlicense.org/ofl-faq/) and
`assets/ui/gallery/fonts/sources.json` for source URLs, pinned archive hashes,
individual file hashes, and font metrics.

At 100/125/150% text size, Pixel uses matching 8/10/12px masters for all five
languages. Normal app text renders at 24/30/36 logical pixels; Gallery text
retains its 16/20/24 sizing. Readable follows each surface's existing scalable
text sizes. System font substitution is disabled for the pixel faces.
The existing game-wide panel scaling can still produce fractional physical
pixels at some window sizes. The fonts' complete Unicode coverage is not
assumed: the actual draft strings are checked for supported glyphs, and text
is normalized to NFC.

## Preview and verification

Select 日本語 or 한국어 in Settings → Language to try the draft in the game.
The shared native preview harness is:

```text
godot --path . --script res://tests/ui/render_japanese_korean_ui.gd
```

The cloud workflow renders real UI scenes with controlled fixture data and
checks Japanese and Korean layouts, fonts, missing glyphs, and overflow.
Enlarged-text samples cover Minesweeper, Settings, Backup, Gallery, and captions.
Any Japanese/Korean caption specimen in that harness is test copy rather than
authored story. Headless layout checks do not count as rendered previews.

`tools/localization/validate_japanese_korean_catalogs.py` checks catalog
completeness, placeholders, line breaks, and NFC. The focused localization
suite covers language selection, profile persistence, transactions, font
coverage, and retained English story fallback. System read-aloud selects a
matching installed Japanese/Korean voice; a missing voice remains unavailable
instead of silently substituting a different language.
