# Lawful-Universe Design Atlas HTML Prototype

**Status:** Approved for disposable prototype construction  
**Date:** 2026-08-13  
**Written specification approved:** 2026-08-14  
**Artifact class:** Disposable visual prototype; non-authoritative  

## 1. Purpose

Build one interactive HTML design museum for the approved player-facing game
surfaces that do not already have dedicated demos. The museum exists to test
whether the whole project feels like one maintained, strange university
workstation before final character faces, hair silhouettes, and accent colours
are refined.

The museum must let the designer compare screens quickly without pretending to
be a playable build. It contains one faithful 1280-by-720 game specimen inside
clearly separate curator controls.

## 2. Authority and prototype boundary

The accepted documents under `docs/design/` remain the sole design authority.
The HTML is visual evidence only and cannot amend mechanics, canon, copy,
geometry, persistence, focus law, accessibility, or component ownership.

The prototype must visibly identify its outer interface as `DESIGN ATLAS —
NON-SHIPPING PROTOTYPE`. That statement belongs outside the game canvas. No
debug, specimen, route, or mechanical label may leak into a purported game
screen.

The prototype:

- changes only in-memory fixture state;
- performs no real save, load, profile, purchase, Gallery, ending, or run
  mutation;
- uses no RNG, network, storage, framework, package, or project autoload;
- invents no story progression to connect unrelated specimens;
- uses sample layout prose that is explicitly noncanonical in curator chrome;
- never replaces a written specification or production test; and
- remains inside the gitignored `.superpowers/brainstorm/` tree.

Implementation authorization for the Godot game remains false.

## 3. Chosen structure

### 3.1 Curated living atlas

Use a non-diegetic atlas around one exact logical game canvas.

The atlas has three regions:

1. a left curator rail for module selection;
2. a centre stage containing the uniformly scaled 1280-by-720 specimen; and
3. a right specimen tray for fixture state, presentation settings,
   annotations, reset, and presentation mode.

At constrained browser widths, the curator rail and specimen tray may collapse
into ordinary outer drawers. The game canvas itself never reflows. A
presentation-mode command hides both outer regions and centres the same canvas.

### 3.2 Rejected structures

A continuous playable journey is rejected because demo-only jumps would look
like approved story flow and the omitted Minesweeper and Schedule surfaces
would create false holes.

A linear guided exhibition is rejected because it makes rare-state comparison
slow and can imply a canonical scene order.

## 4. Technical artifact

Create one dependency-free full HTML document at:

`.superpowers/brainstorm/2376-1786631199/content/lawful-universe-design-atlas-01.html`

Reuse the already-local provisional lineup plate only from:

`.superpowers/brainstorm/2376-1786631199/content/character-lineup-study-01.png`

The document contains its CSS, deterministic fixture data, render functions,
and local interaction handlers inline. It performs no external requests and
must also remain intelligible if opened directly as a local file. The active
visual-companion server provides the review link and injects only its normal
connection helper.

Earlier HTML prototypes are references, not source components. Their stale
launcher, adaptive Contacts, floating caption, responsive-canvas, or
`Save & Return` behavior must not be copied.

## 5. Outer atlas interface

### 5.1 Module rail

Use this exact group and order:

1. `Workstation`
   - Title
   - Desktop & Angela
2. `Apps`
   - Contacts
   - Shop
   - Backup / Log in
   - Settings
3. `Archive`
   - Gallery & Rehearsal
4. `Scenes`
   - Narrative / Dating
   - Hospital
   - Ending
5. `Art production`
   - Quartet study
   - Placement map

Schedule, universal Pause, and Minesweeper receive no atlas module because
they already have dedicated demos. Their truthful references remain where
required by other accepted surfaces.

### 5.2 Specimen tray

The tray contains:

- fixture-state buttons specific to the selected module;
- text size: 100%, 125%, 150%;
- target size: ordinary 48, large 64;
- palette proof: Light, Dark, governed by the selected fixture's host law;
- contrast: Standard, High;
- colour differentiation: Standard, Protan, Deutan, Tritan;
- language projection: Primary, Dual;
- motion: Standard, Reduced;
- `Show layout annotations`;
- `Reset specimen`; and
- `Presentation mode`.

Controls that do not apply to a fixture remain absent rather than implying a
game option. The tray may name internal specimen states because it is outside
the game canvas.

Palette proof is host-aware. Title-hosted specimens derive their palette only
from the fixture's pending next-run selector: Fresh and Entitled — Off remain
Light, and Entitled — On is Dark. In-run specimens derive it only from the
fixture's immutable captured run configuration. Quartet Study and Placement Map
do not expose this control, and their artwork is never recoloured.

### 5.3 Atlas state

Atlas navigation state may be encoded in the URL hash for review convenience:

`#module=<id>&fixture=<id>&text=<100|125|150>`

No canonical game state or sample dialogue is serialized. Reloading without a
valid hash returns to `Title / Fresh` at 100% text, ordinary targets, Light,
Standard contrast, Standard colour differentiation, Primary language, and
Standard motion.

## 6. Game-stage invariants

The specimen owns exactly 1280 by 720 logical pixels. JavaScript computes one
uniform scale from the available centre-stage rectangle and centres the canvas.
It never expands, crops, or rearranges internal topology. Outer browser space
is curator space, not the game's accepted matte.

Inside the game canvas:

- title uses the exact 320/960 split and 64-pixel workfield strip;
- in-run desktop uses the exact 480/800 split and 64-pixel computer strip;
- narrative, Hospital, and Ending use the exact 104/344/272 three-band host;
- accepted app-local fixed splits remain fixed at every supported text size;
- ordinary interactive targets are at least 48 by 48 logical pixels;
- Large Targets raises them to at least 64 by 64;
- text wraps or locally scrolls and never silently shrinks or ellipsizes; and
- focus, selection, unread, unavailable, warning, and speaking state never rely
  on colour alone.

The stage uses real HTML buttons and controls where interaction is demonstrated.
Curator controls never enter the game's focus order.

## 7. Module coverage

### 7.1 Title

Required fixtures:

- `Fresh`: New Acc focused, Dark selector absent, truthful clock, completely
  empty workfield;
- `Entitled — Off` and `Entitled — On`: one-shot next-run selector directly
  below New Acc;
- `Log in hosted`: title Backup in load-only mode;
- `Settings hosted`;
- `Gallery hosted`;
- `New Acc confirmation`; and
- `Shut down confirmation`.

The workfield contains no key art, logo animation, prompt, lore, Opening,
tutorial, completion badge, or credits. New Acc may transition the specimen to
the Desktop module and consume the displayed pending Dark selector, but this is
explicitly fixture behavior rather than a transaction simulation.

### 7.2 Desktop and Angela

Required fixtures:

- light launcher with no keepsakes;
- launcher with all three keepsakes;
- captured Dark run;
- current condition and penalty HUD projection;
- ordinary three-beat self-talk;
- pinned Dark refusal self-talk;
- Contacts toast with Go and X;
- quiet Quick Save edge status; and
- Logout confirmation.

The launcher keeps the accepted fixed row-major 4+3 order:

`Minesweeper | Contacts | Schedule | Shop`

`Backup | Settings | Log out | [empty]`

The Minesweeper and Schedule tiles remain normal-looking because the real game
contains them. Activating either in this atlas produces a message only in outer
curator chrome that its dedicated demo is intentionally separate; it does not
draw a disabled or explanatory state inside the game.

Opening Contacts, Shop, Backup, or Settings from the launcher uses the actual
desktop host specimen and leaves Angela's HUD, alcove, keepsakes, and self-talk
present.

### 7.3 Contacts

Use the fixed 31/69 rail/thread split and exactly Priscilla, Lavinia, Sylvia in
that order.

Required fixtures and safe interactions:

- bare list with nobody selected;
- binary unread row;
- activation bulk-reads and opens at the oldest-new divider;
- ordinary correspondence with one A/B/C inline reply;
- linked Priscilla/Lavinia exchange with literal sender labels only where
  needed;
- arrival while an already-open thread remains withheld until reopen;
- an ordinary Day-2 Contacts state without a dedicated return-message pair or
  anomaly treatment;
- before/after midnight erasure; and
- Dual-language slip.

Do not add modern bubbles, per-message avatars, unread counts, composer, Send,
invitation badge, typing indicator, or decorative glitch.

### 7.4 Shop

Use the accepted 3/5 catalog and 2/5 inspector with two fixed 3-by-3 pages.

Required fixtures and safe interactions:

- page one and page two;
- batchable selection with `MIN − quantity + MAX`, exact total, and Buy;
- single product;
- sold-out but inspectable product;
- insufficient-funds and unavailable inline refusals;
- ordinary optional double-click confirmation with No focused;
- blank ineligible Supportz slot;
- blank eligible Supportz slot; and
- `$45 / No / Yes` Supportz modal.

Purchasing changes only local fixture balances, stock projection, and an
optional keepsake in the simultaneous Angela shell. It does not simulate
atomic persistence or condition routing. Exactly seventeen products have
visible literal object art; Supportz never gains art, name, price, inspector,
or explanation outside its price-only modal.

### 7.5 Backup and Log in

Use the stable 3/5 cabinet and 2/5 inspector. The nine drawers are:

`Autosave | Quick | Slot 1`

`Slot 2 | Slot 3 | Slot 4`

`Slot 5 | Slot 6 | Slot 7`

Required fixtures and safe interactions:

- in-run Save defaulting to Slot 1;
- in-run Load;
- title Log in load-only;
- Empty, readable, fallback-loadable, and Unavailable drawers;
- Autosave visible with Save truthfully unavailable;
- overwrite, live-load, fallback-load, and Delete confirmations;
- static `Saving…` followed by `Saved`; and
- successful Delete retaining the selected now-Empty drawer.

All confirmation fixtures begin on Cancel/No. Never use corruption fiction,
spinners, percentages, direct action buttons in every drawer, or raw error
diagnostics.

### 7.6 Settings

Render the exact category rail:

`Language | Reading | Audio | Display | Controls | Accessibility | Records`

Required representative interactions:

- Dual Language toggles the visible disabled/enabled Secondary selector and
  same-locale selection swaps Primary/Secondary;
- Reading controls and neutral localized preview;
- Read Aloud and truthful unavailable system-voice state;
- Master/Music/Ambience/SFX volume, mute, and one-sample-at-a-time Test/Stop;
- Windowed/Borderless;
- binding capture and Swap/Cancel conflict surface;
- 100/125/150 text, Large Targets, Reduced Motion and remembered shake;
- High Contrast and four colour-differentiation modes with permanent state
  specimen;
- Records reset confirmation; and
- Entire Profile Reset shown only in a title/no-mounted-run fixture.

Dark Mode never appears in Settings.

### 7.7 Gallery and Rehearsal

Use the title workfield and the accepted 928-by-624 archive inner rectangle.
When Rehearsal exists, use a 64-pixel mode bar, 16-pixel gap, and fixed
344/16/568 registrar split.

Required fixtures and safe interactions:

- honest empty Endings with Rehearsal absolutely absent;
- unlocked Endings/Rehearsal bar;
- discovered-only ending chronology and record detail;
- optional media collapsed versus present;
- `Other witnessed versions` only for multiple reached forms;
- explicit Replay;
- Rehearsal Scenes and Full Dates only when nonempty;
- meaningful Day/participant facets without empty values or counts;
- Begin Rehearsal; and
- quiet `New dialogue added to History` return status.

Full Date stops at its archive start/leave/return specimen. Its production
board belongs to the separate Minesweeper demo. No unseen ending trace, lock,
silhouette, denominator, search, completion percentage, or mechanical identity
may appear.

### 7.8 Narrative and Dating

Use the exact three-band proscenium and control order:

`History | Skip | Auto | Save | Load | Next`

Required fixtures and safe interactions:

- physically present two-person layout;
- physically present three- or four-person layout;
- active-speaker frame cue while every silent portrait remains legible;
- nonverbal beat with no active speaker;
- single-language current plus two prior semantic beats;
- Dual-language current Primary/Secondary beat only;
- partly revealed current line: first normal Accept completes it, second
  advances;
- inline choices stopping transport;
- History full-canvas sheet and exact return focus;
- Next seeking witnessed content to the first unseen or challenge boundary; and
- archive Scene replay capability with Save and Load absent.

Use third-person CSS silhouette studies based on the approved lineup direction.
Do not create first-person Angela framing, audience-adjacent camera, routine
speaker names, offscreen speakers, floating captions, hidden controls, or
clickable stage exploration.

The excluded challenge is represented only by the accepted dimmed-stage entry
boundary and an outer-curator handoff note. No substitute board is drawn.

### 7.9 Hospital

Reuse the complete Narrative host and controls with a treatment-room tableau.
Show physically present participants, boardless captions, and direct completion
rhythm. There is no smaller Hospital UI, empty challenge frame, locked board,
countdown, clinical diagnosis, condition formula, or nurse coding for Sylvia.

### 7.10 Ending

Reuse the three-band host and approved transport grammar.

Required specimens:

- ordinary ending beat;
- ordered later step with continuous History;
- final-shot hold with every control inert;
- automatic wordless inter-step seam;
- closing image;
- neutral textless matte; and
- ordinary title landing with empty workfield and New Acc focus.

There are no credits, public ending title, achievement banner, Gallery notice,
summary, percentage, trophy, Continue, spinner, success sound, or automatic
Gallery opening.

### 7.11 Quartet study and art placement

This module lives outside the game canvas or replaces it with an explicitly
curated production plate. It may show the approved provisional quartet lineup
and the accepted source-to-export-to-manifest-to-presenter map.

It labels outfits, relative silhouette direction, and art-placement regions as
approved. It labels exact faces, hair silhouettes, complexion/heritage details,
and accent swatches as the next refinement—not as canon already solved. The
model sheet is production reference, never a title reward, Gallery record, or
collectible.

## 8. Fixture and interaction architecture

Use a single immutable fixture catalogue:

```js
const FIXTURES = {
  title: { fresh: { /* visible projection only */ } },
  desktop: { launcher_light: { /* visible projection only */ } },
  contacts: { bare_list: { /* visible projection only */ } }
};
```

Each module renderer receives:

```js
renderModule({ fixture, presentation, localState, dispatch })
```

`dispatch` accepts only demo-local semantic intents such as `select-contact`,
`toggle-dual-language`, `select-shop-item`, `change-quantity`, `open-modal`,
and `close-modal`. It never accepts domain commands such as `commit-save`,
`resolve-ending`, or `charge-currency`.

Changing module or fixture rebuilds local state from a cloned deterministic
fixture. Reset does the same. No hidden state carries across unrelated
specimens except the outer presentation settings.

## 9. Visual system

Use provisional CSS tokens rather than treating old prototype hex values as
canon. The target balance is approximately:

- 70% maintained late-1980s/early-1990s university workstation;
- 20% exhausted paper and rough ink; and
- 10% restrained liminal colour.

Use square geometry, one-pixel seams, tabular figures, institutional cream,
soot ink, green-grey, faded blue, bruised lavender, and restrained rust. Apply
static low-contrast dither only to broad inactive planes. Preserve large quiet
negative space.

Do not use modern rounded cards, neon, CRT scanlines, glitch, fake diagnostics,
glass blur, animated grain, excessive gradients, shadow stacks, or motion-only
state. Character and environmental art pixels are not recoloured by Dark,
contrast, or colour-differentiation controls; functional UI tokens are.

## 10. Provisional art policy

Use CSS silhouette and paper-object studies inside game specimens. Do not cut
runtime sprites from the lineup study. The actual lineup image appears only in
the `Quartet study` module.

Every game-surface art placeholder preserves its accepted owned rectangle and
focal relationship. Optional art collapses where the written design requires
collapse. Required-art failure is not simulated as an empty successful state.

No art may encode hidden affection, tier, tone, route, ending form, Foresight,
Observer, condition threshold, recommendation, or Supportz identity. No
localized text is baked into art.

## 11. Accessibility and input

The atlas and specimen must both be fully operable with keyboard and pointer.
Use semantic HTML controls, visible focus, meaningful labels, and `aria-pressed`
or `aria-selected` where appropriate.

The outer atlas owns its own landmarks. The game specimen is named
`Game design specimen`. Entering the stage moves to its first meaningful
fixture control; a dedicated `Return to atlas controls` command restores the
last curator focus. Presentation mode retains an accessible way to restore the
outer interface.

Modal specimens use `dialog` semantics, move initial focus to Cancel/No, trap
Tab within the modal, make the specimen background inert, and restore the exact
source control on close.

Text-size, target-size, contrast, colour-differentiation, Dual-language, and
Reduced Motion controls must visibly affect every applicable module. Reduced
Motion disables crossfades and animated reveal while preserving exact states.

## 12. Browser behavior and error handling

Target current Chromium and Edge on Windows. The page must:

- load from the visual companion with no external network requests;
- produce no console error or warning;
- retain a stable logical canvas after resize;
- ignore malformed URL hash fields and use the exact default state;
- show an outer curator error plate if a requested fixture renderer is absent;
- never turn an atlas renderer error into fictional game corruption; and
- keep the last valid specimen visible if a fixture switch fails.

No browser storage or service worker is permitted.

## 13. Verification

### 13.1 Structural checks

- Every required module and fixture in Section 7 is reachable from the atlas.
- Schedule, universal Pause, and Minesweeper have no dedicated atlas module.
- Minesweeper and Schedule remain present in the launcher.
- Title workfield, unseen archive content, Supportz, credits, Opening, tutorial,
  and excluded challenge surfaces remain absent exactly where required.
- Demo-only labels occur only outside the game canvas.

### 13.2 Geometry checks

- At 1280-by-720, title, desktop, app, archive, and three-band host rectangles
  match their accepted coordinates.
- Browser resizing uniformly scales the canvas without internal reflow.
- 100%, 125%, and 150% retain each module's macro topology.
- 48/64 targets meet their selected minimum.
- Long sample content wraps or locally scrolls with no ellipsis, overlap, or
  horizontal text scrolling.

### 13.3 Interaction checks

- Module, fixture, reset, presentation, and URL-hash state are deterministic.
- Safe local interactions change only fixture-local state.
- Every modal begins on Cancel/No, traps focus, and restores source focus.
- Keyboard, pointer, and visible focus reach every demonstrated action.
- One activation produces at most one demo-local command.

### 13.4 Visual and accessibility checks

- Host-lawful palette proof, contrast, four colour-differentiation modes, text
  sizes, target sizes, Primary/Dual, and Reduced Motion are inspectable.
- Fresh and Entitled — Off title specimens remain Light; Entitled — On derives
  Dark from the pending selector; in-run Dark derives only from captured run
  configuration; Quartet Study and Placement Map artwork is unaffected.
- Functional states retain line, shape, text, or pattern evidence without
  colour alone.
- The accessibility tree names outer atlas controls separately from game
  controls.
- The provisional lineup is used only in the production-reference module.

### 13.5 Browser evidence

Verify in a real isolated Chromium/Edge profile at minimum:

- 1920 by 1080;
- 1440 by 900;
- 1280 by 720; and
- one non-16:9 browser window.

Capture screenshots for Title, Desktop, Contacts, Shop, Backup, Settings,
Gallery/Rehearsal, two- and multi-person Narrative, Hospital, final Ending,
and Quartet study. Inspect console, focus order, representative modal focus,
and the accessibility tree before handoff.

## 14. Completion boundary

The prototype is complete when the designer can use one browser link to inspect
every Section 7 module, compare the cross-cutting presentation states, and
identify design inconsistencies without mistaking curator controls for shipped
game UI.

Completion changes no accepted design, game code, art manifest, save schema,
localization, Beads issue, or implementation authorization. Validated visual
findings are recorded later in the appropriate accepted design or art guide;
the disposable HTML remains evidence only.
