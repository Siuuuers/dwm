# Lawful-Universe Atlas Title, Caption, and Companion Expansion

> **Archive notice — 2026-08-24:** Retired disposable HTML-prototype evidence.
> This document is non-authoritative and must not be executed or treated as a
> current requirement. See `README.md`.

**Status:** Conversational design approved; written specification pending review

**Date:** 2026-08-14

**Parent:** `2026-08-14-lawful-universe-atlas-presence-refinement-design.md`

**Original atlas:** `2026-08-13-lawful-universe-design-atlas-prototype.md`

**Artifact class:** Disposable visual-prototype refinement; non-authoritative

**Self-review:** Passed 2026-08-14

**Implementation authorization for the Godot game:** False

## 1. Purpose and boundary

Extend the portable Curated Living Atlas in three narrowly approved ways:

1. reserve the logged-out title workfield as a future authored title-art well;
2. make witnessed-scene caption history build upward from a bottom-anchored
   current beat; and
3. include the existing Schedule and Minesweeper HTML studies as local
   companion modules without rewriting either prototype.

This document controls only the disposable HTML atlas and its locally copied
companion files. It creates no final title artwork, story copy, mechanic,
progression, save, profile state, or production asset.

Accepted design amendments under `docs/design/` remain the game authority.
The title-art direction deliberately differs from the currently accepted blank
title workfield. The atlas may demonstrate the newly approved direction, but a
later canonical shell amendment must reconcile that difference before any
Godot implementation. Nothing in this document authorizes that production
change by implication.

## 2. Chosen approach

Use one curated atlas with two sandboxed, local companion documents.

The atlas continues to own its outer navigation, annotations, presentation
mode, and faithful 1280-by-720 specimens. Schedule and Minesweeper remain their
existing independent HTML studies, copied into the portable atlas and opened
inside a clearly identified companion viewport. They do not share JavaScript,
CSS, fixture state, or persistence with the main atlas.

This approach is chosen because it:

- preserves the already-reviewed Schedule and Minesweeper interactions;
- avoids a second, subtly different reconstruction of either design;
- keeps the portable atlas usable from one local link; and
- makes the prototype boundary visible instead of suggesting that the three
  documents form a working game build.

Rejected alternatives:

- rebuilding both applications natively inside the atlas would duplicate a
  large interaction surface and invite design drift; and
- opening unrelated external file links would make the atlas less portable and
  lose deterministic navigation and return focus.

## 3. Title-art well

### 3.1 Owned rectangle

In every unhosted logged-out title specimen, the right workfield below its
64-pixel strip is one dedicated artwork well:

`x = 320, y = 64, width = 960, height = 656`

The well fills that rectangle. It never changes the accepted 320/960 title
split, strip height, ledger order, clock, or focus path. Log in, Settings, and
Gallery continue to replace the workfield body with their hosted surfaces.

### 3.2 Prototype projection

The HTML does not invent a game title, logo, slogan, illustration, or temporary
copy. Until authored art exists, the well renders only a quiet nonverbal
paper-and-ink placement surface. It may use restrained registration corners or
tonal planes so its bounds can be judged, but contains no readable text,
symbolic lore, character silhouette, progress signal, or button.

The outer curator layer may identify the rectangle as `Future title artwork`
when annotations are enabled. That annotation must remain outside the game
canvas and outside the specimen accessibility tree.

The well is decorative, noninteractive, nonfocusable, pointer-inert, and hidden
from assistive traversal. Missing future art never produces a broken-image
icon, loading copy, error fiction, or empty focus stop.

### 3.3 Future artwork contract

The future authored asset may contain the real title treatment as part of the
art, but the atlas must not manufacture or bake one now. The asset will later
require a semantic manifest ID, native dimensions, cover or contain rule,
focal anchor, and Light/Dark suitability decision.

For this prototype, pending Dark may change functional title-shell tokens but
must not recolour the artwork pixels or use a different image as an undisclosed
ending, route, or entitlement clue.

This clause supersedes only the disposable atlas requirement that Fresh and
Entitled title workfields be completely blank. It does not alter hosted title
surfaces, ending-to-title focus, or production authority.

## 4. Bottom-up caption rhythm

### 4.1 Visual order

The protected lower caption deck and pinned transport rail retain their exact
accepted geometry. Inside the caption region, the current semantic beat is
always the lowest visible card. Previous retained beats appear above it in
chronological order.

For a single-language stack:

```text
oldest retained beat
previous beat
current beat          <- bottom anchor
```

When a new beat becomes current, it enters at the bottom. The former current
beat moves upward and the oldest excess beat leaves the retained visual stack.
The animation, when motion is enabled, must communicate this upward accretion
without changing card width, text size, participant geometry, or control-rail
position. Reduced Motion performs the same state change as a static swap.

### 4.2 Dual language and reading order

Dual-language Primary and Secondary text form one current semantic card at the
bottom; they never become two independently stacked beats. Dual mode retains
only that current bilingual card under the existing caption law.

The visible chronological order remains oldest to current from top to bottom.
Only the newly published current beat receives its normal polite announcement;
moving a witnessed beat upward does not announce it again. The current beat is
kept fully in view after reveal, text-size change, language change, or local
overflow.

### 4.3 Transparency and alignment

The approved centred, transparent caption treatment remains. The stack is
horizontally centred; each card uses the approved centred prose and line-level
contrast backing. Bottom anchoring must not turn the caption into a floating
tableau overlay or allow stage input beneath the protected deck.

At 125 or 150 percent text, the deck follows its accepted growth and local
vertical-overflow law. Overflow starts from the bottom so the current card
remains visible. No caption shrinks, clips, ellipsizes, or uses horizontal
scrolling.

## 5. Portable companion documents

### 5.1 Copied artifacts

Copy the two approved source studies into the portable atlas without rewriting
their internal markup, styles, fixture logic, or wording:

- Schedule source: `C:/Users/glori/Documents/dwm/.superpowers/brainstorm/schedule-ui-20260813-165111/content/schedule-ledger-docket-prototype.html`
- Minesweeper source: `C:/Users/glori/Documents/dwm/.superpowers/brainstorm/minesweeper-ui-20260813-144731/content/minesweeper-layout-v3.html`

Portable destinations:

- `content/companions/schedule-focused-docket-folio.html`
- `content/companions/minesweeper-layout-v3.html`

The copied bytes must initially match these source SHA-256 fingerprints:

- Schedule: `22ECDA21C794B467E2C5D64DD9B0CE438BBE15D8136D8B6DC20F71691023E4C6`
- Minesweeper: `8A2ABC3459C2B7C357F1260BEFA8F4BA45BEB9959CC7C666C0C0F5A0099D71B3`

The copies are disposable visual evidence. They are not runtime source, design
authority, or a substitute for later Godot implementation.

### 5.2 Atlas navigation

Add one exact module-rail group after `Apps` and before `Archive`:

```text
Companion demos
  Minesweeper
  Schedule
```

This order matches the Desktop launcher's application order. The group name
keeps the independent prototypes distinct from the atlas's native fixture
renderers. Universal Pause remains excluded.

The lawful Desktop launcher keeps its existing tile order. Activating its
Minesweeper or Schedule tile navigates to the corresponding companion module
instead of showing the former outer note. Returning to Desktop restores focus
to the exact launcher tile that initiated the handoff.

Direct curator navigation selects the companion and focuses an outer `Enter
demo` action. Activating that action moves focus to the iframe browsing context;
its natural internal Tab order then begins at the source document's first
meaningful control. A Desktop launcher activation is already a deliberate entry
and may focus that same browsing context directly. The atlas retains a visible
outer `Return to atlas` or `Return to Desktop` action that is never drawn as
shipped game chrome.

### 5.3 Embedded boundary

Each companion loads in a local iframe with a meaningful title and the exact
sandbox token `allow-scripts`. It receives no top-navigation, download, pop-up,
or same-origin DOM access. The atlas and companions expose no cross-document
messaging or state protocol. Both copied sources contain no external dependency;
any unexpected network request is a verification failure rather than a
fictional in-game event.

The iframe is contained within the atlas centre stage and never overlaps the
curator rail or specimen tray. Its source document remains visually intact and
owns its own internal scrolling. The atlas does not inject CSS, reach into the
companion DOM, synthesize game commands, or represent the iframe as a native
1280-by-720 game screen.

The default source queries are:

- Schedule: `?variant=C`
- Minesweeper: `?variant=C`

Variant C is therefore selected on first entry and after companion Reset.

### 5.4 State, controls, and failure

Companion state is document-local and temporary. Leaving a companion may
discard its state; Reset must reload its exact local URL and Variant C. No
companion writes browser storage, modifies the atlas URL beyond the atlas's own
module state, or mutates another fixture.

Atlas-wide text size, target size, palette, language, contrast, colour, and
motion controls are absent or clearly not applicable while a companion owns
the stage. They must not pretend to configure an isolated document they do not
actually control.

If a companion file cannot load, preserve the atlas shell and show one factual
error in outer curator chrome. Do not display fictional computer corruption,
an in-game warning, or a false successful blank application.

## 6. Accessibility and focus

The artwork well creates no focus stop or accessible content.

Caption publication preserves the existing scene focus owner. Visual movement
of prior beats never changes focus, reading cursor, or transport state.

Each iframe has a concise accessible title that includes the application and
the phrase `non-shipping companion demo`. Entering a companion is deliberate;
focus must not jump into it merely because the module becomes visible. The
outer handoff control moves focus to the iframe browsing context, and the outer
return control restores the initiating curator control or launcher tile.

Keyboard users can always leave the companion without relying on a shortcut
owned by the embedded document: a persistent outer Return control immediately
precedes the iframe in the atlas traversal order, and reverse traversal from the
companion boundary reaches it. Presentation mode retains the same outer escape
route. No hidden iframe remains focusable after another module replaces it.

## 7. Atlas-only supersession

Within the disposable atlas only, this amendment supersedes these requirements
from the original atlas specification:

- Title/Fresh and Entitled workfields are no longer completely blank; they own
  the nonverbal artwork well defined in Section 3.
- The module rail is no longer limited to the original groups; it includes the
  exact `Companion demos` group defined in Section 5.2.
- Schedule and Minesweeper now have companion modules, while universal Pause
  remains excluded.
- Their Desktop launcher tiles open those companion modules instead of
  publishing an outer note that a separate demo exists.

Every other original atlas and presence-refinement requirement remains in
force, including the non-shipping boundary and the prohibition on treating
prototype state as canonical game state.

## 8. Implementation boundary

Implementation may change only:

- the portable atlas HTML;
- the two new local companion copies;
- the atlas structural guard and browser verifier;
- local evidence screenshots and reports; and
- a later implementation plan for this disposable prototype.

It must not change Godot scenes, scripts, accepted `docs/design/` amendments,
Beads state, save schemas, production localization, final title art, or the
source companion prototypes.

## 9. Verification

The disposable prototype must prove all of the following in a real isolated
Chromium or Edge browser:

1. Fresh and both Entitled title specimens own the exact 960-by-656 artwork
   well beneath the strip.
2. The well contains no readable game-canvas placeholder, focus target,
   assistive node, broken image, or pointer action.
3. Hosted Log in, Settings, and Gallery replace the well normally, and closing
   them restores the correct title-ledger focus.
4. Single-language scene captions keep the current beat at the bottom and at
   most two retained prior beats above it.
5. Publishing a new beat moves prior beats upward without changing scene
   participants, card width, text size, or control-rail geometry.
6. Dual language renders one bilingual current card at the bottom, with no
   separate prior-card stack.
7. At 100, 125, and 150 percent text, the current beat stays fully visible;
   no caption clips, shrinks, ellipsizes, or scrolls horizontally.
8. Reduced Motion produces a static bottom-up state swap with the same final
   visual order.
9. Both companion files return HTTP 200 from the atlas's local server and make
   no unexpected external request.
10. Direct module navigation and both Desktop launcher tiles reach the correct
    companion.
11. Schedule and Minesweeper first open and Reset to Variant C.
12. Companion focus entry is deliberate; outer Return restores the exact
    launcher or curator source; a hidden companion is absent from traversal.
13. Atlas presentation controls do not falsely mutate isolated companion
    content.
14. A simulated missing companion produces one factual outer error while the
    atlas remains usable.
15. Existing atlas modules, modal focus traps, presentation mode, URL-hash
    recovery, and console-clean verification remain green.
16. Chrome reports zero console errors, zero console warnings, and zero
    unexpected external requests across the expanded evidence matrix.

## 10. Completion boundary

This refinement is complete when the designer can see the title-art region,
judge the bottom-up caption rhythm, and open both prior application studies
from the same portable atlas without mistaking any of them for a production
game build.

Completion does not approve title artwork, canonize prototype copy, merge the
three HTML state models, or authorize Godot implementation.
