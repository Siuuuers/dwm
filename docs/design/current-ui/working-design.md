# Current UI working direction — 2026-09-05

The objective is a legible, coherent game UI. On 2026-09-05 the owner explicitly
made old recovery plans and implementation restrictions reference material,
allowing a simpler route whenever that serves the design. This document records
the resulting working direction. It does not claim that the isolated component
has been installed in the game or that historical acceptance hashes cover these
new bytes.

## What the player sees

Keep the quiet registrar appearance: pixel frames, restrained flat materials,
literal names, and small functional marks. Incoming correspondence sits on paper;
outgoing correspondence uses a narrower plum slip. The interface shows actual
state without interpreting the story. Focus, Selected, and Unread remain separate
facts; one never impersonates another. No portraits or explanatory hints are
introduced.

The [consolidated Contacts design](contacts.md) corrects contradictory instructions
about the retired Day-2 return-message pair. That pair produces no message, time,
Unread event, history entry, assistive announcement, or dedicated persistence
stage. Real linked offers and ordinary Day-2 scenes remain intact. Operational
reply controls are distinct from selectable spoken-scene story choices.

## Typography

Use font rendering for functional English and Chinese text. Pixel artwork and
frames retain their crisp grid; text uses the font renderer at the presentation
resolution. Do not rasterize an 8px master and enlarge that bitmap to obtain the
larger text presets. Nominal font size is not a guarantee of equal visible glyph
height across families or languages.

| Text | Font used by the isolated component |
|---|---|
| English | Source Sans 3 Regular |
| Simplified Chinese (`zh-CN`) | Source Han Sans SC Regular |
| Traditional Chinese for Hong Kong (`zh-HK`) | Source Han Sans HC Regular |

The current recommendation retains the tested 12 native-equivalent pixel
baseline. At the 2× logical presentation reference, text sizes are:

| Text setting | Logical font size | Native-equivalent size |
|---|---:|---:|
| 100% | 24 px | 12 px |
| 125% | 30 px | 15 px |
| 150% | 36 px | 18 px |

The earlier 10px baseline remains comparison evidence, not an additional Settings
control. In the absence of a new preference, this pass preserves the existing
12px component default for readability. This is a design recommendation, not a
claim that 10px was explicitly rejected by the owner.

Use the regional font appropriate to each displayed language. These three font
choices do not establish coverage of every language. Missing translations must
not silently become invented text. Keep both languages in one slip when dual
text is enabled, and allow the slip to grow vertically.

Keep the original font files and their complete OFL license notices together in
[the font directory](../../../assets/ui/contacts/fonts). The existing source
manifest records the downloaded bytes. Font subsetting, modifications, and extra
families are unnecessary for this design pass.

## Geometry and reading

The Contacts plate stays 400 × 328 native geometry, presented as 800 × 656 logical
pixels. Its rail remains 124 native pixels wide and the conversation pane 276.
Text scaling preserves that split. Row pitch is 48 native pixels with a 40px
semantic body and a clear gap around the detached focus marks. This adopts the
focus study's best of three tested allocations; it does not claim that every
possible 44px design is impossible.

The rail and open-thread header stay fixed. Messages wrap in one vertically
scrolling region. Never hide message lines to make a slip fit, shrink text to fit,
or introduce horizontal paragraph scrolling. Continuation cuts appear only when
content really continues outside the viewport. Resizing text keeps the reader's
position using the visible entry and its offset. Fresh entry has a blank right
pane; sample text never becomes canon by appearing in a test.

These smooth-font and 48px-row choices replace the old bitmap-master and 44px-row
directions for this isolated working design. The old dossiers and proof receipts
remain historical references, not a requirement to repeat obsolete experiments.

## Evidence and its limits

The existing [Godot component result](../../../evidence/contacts_component/result.json)
records passing layout and input checks for the isolated presentation component.
Its text-visibility ablation hid 72 of 80 fixture lines with a two-line cap and
none with normal or restored reflow. The cap did not reduce layout height, so
this supports reflow rather than a performance claim.

Keep that evidence; do not rerun unrelated experiments for a documentation edit.
When component behavior changes, run its focused verifier. Headless layout tests
do not prove final GPU rendering, all Windows DPI settings, complete assistive
behavior, or font coverage beyond the tested locales.

The first integration slice is to mount Contacts in the shared shell and wire
existing open/read actions to the presentation component. Use the actual game
state owner and approved correspondence; do not invent state changes or story
text to complete the screen. Inspect that boundary before estimating the work;
the UI-00R grant system does not need to be reconstructed first.
