---
id: spec.haunted_instrumentarium_ui_manual_foundation_decisions
kind: design_amendment
schema_version: 1
amends: spec.main_menu_desktop_shell_global_chrome_ui_ux_amendment
amends_path: "docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md"
related_authorities: ["spec.narrative_scene_host_dating_hospital_challenge_ui_ux_amendment","spec.minesweeper_board_session_challenge_ui_ux_amendment","spec.backup_save_load_ui_ux_amendment","spec.title_art_placement_bottom_up_scene_caption_rhythm_amendment","guide.visual_art_placement_and_asset_production"]
decision_status: accepted
conversational_design_status: approved_through_section_4_with_owner_corrections_plus_section_5_1_covenant
written_spec_status: pending_owner_review
theory_to_form_covenant_status: approved
theory_to_form_covenant_approved_on: "2026-08-23"
theory_to_form_covenant_self_review_status: passed
theory_to_form_covenant_self_reviewed_on: "2026-08-23"
self_review_status: passed
self_reviewed_on: "2026-08-14"
implementation_requested: false
implementation_authorized: false
created_on: "2026-08-14"
engine_line: godot_4_6
verification_engine: "4.6.3-stable-mono"
language: gdscript
audience: private_spoiler_complete
scope: ["manual_authority_and_identity","reliability_and_usability_law","native_canvas_and_spatial_architecture","witness_register_and_bottom_up_captions","haunted_instrumentarium_visual_system","four_lens_theory_to_form_covenant","relationship_phase_grammar","interaction_choreography","no_inline_scene_choices","backup_load_delete_confirmation_ownership","accessibility_localization_and_input_foundations","prototype_and_art_policy"]
---

# Haunted Instrumentarium UI Manual: Foundation Decisions

## 1. Status, purpose, and boundary

This is the private, spoiler-complete decision ledger for the UI manual approved
through Sections 1–4 on 2026-08-14. It records the project owner's latest
corrections together with the accepted governing philosophy, spatial
architecture, visual system, and interaction choreography.

This is a **living foundation document**, not the completed screen-by-screen
manual. It intentionally stops before final screen concepts, final art briefs,
component construction specifications, and an implementation plan.

This document authorizes no Godot changes. The game is unshipped, so later
implementation may replace obsolete scaffolds without preserving their visual
or scene-tree compatibility. Canonical persistence, transaction, and recovery
guarantees remain intact unless separately amended.

## 2. Authority and precedence

For matters inside this document's scope, use this order:

1. the project owner's latest explicit correction;
2. this decision ledger;
3. the accepted August 2026 design amendments retained below;
4. earlier exploratory notes and disposable prototypes; and
5. current runtime scaffolds as implementation evidence only.

Story canon remains authoritative for character facts, relationships, physical
events, and epistemic limits. This UI document may decide how accepted facts are
presented; it may not invent a diagnosis, motive, history, route, ending, or
supernatural explanation.

The newest HTML atlas exported outside the workspace is a strong structural
reference, not the final aesthetic authority. The living companion screens in
`.superpowers/brainstorm/ui-manual-20260814-142341/content/` are design
evidence. Neither artifact authorizes production code by itself.

### 2.1 Exact narrow supersessions

This document supersedes only the following conflicting laws:

- any rule that makes institutional cream or pale paper the dominant global
  game habitat;
- any rule that places inline dialogue-option lists in canonical Dating,
  visible Priscilla–Lavinia, Hospital, or ordered-ending scene playback;
- any scene specimen that places save-record deletion over a narrative host;
- any visual caption implementation that creates the first/current line away
  from the lowest caption position; and
- any witness-register design that uses visible character names or wide empty
  photo frames as the visible portrait boundary.

All unrelated mechanics in the amended documents remain retained.

## 3. Project identity

- **Genre:** romantic psychological and supernatural horror visual novel.
- **Audience:** adult.
- **Era and world:** contemporary.
- **Art direction:** authored pixel art on a fixed native raster canvas.
- **Horror:** psychological, supernatural, and deliberately ambiguous.
- **Romance:** tender, obsessive, devotional, playful, poisonous, tragic,
  manipulative, ambiguous, and doomed, organized as phases rather than
  simultaneous noise.
- **Absurdity:** uncomfortable, grotesque, bureaucratically serious, and
  occasionally funny.
- **Primary materials:** astronomy, literature, music, calculation, physical
  evidence, and careful institutional procedure.

The compact identity sentence is:

> The UI is a pixel-art love letter operating inside a haunted
> instrumentarium: tender enough to trust, exact enough to use, and wrong in
> ways that invite interpretation rather than prevent action.

“Haunted observatory” describes after-hours observation, distance, patient
measurement, imperfect instruments, and the feeling of being watched by a
record. It is a mood, not a requirement for domes, telescopes, constellations,
brass decoration, or star wallpaper.

## 4. Core governing law

The governing thesis is:

> **Trust the hand. Question the trace.**

The story may lie. Narration, characters, memory, timestamps in a registered
anomaly, and interpretive evidence may disagree. Core software operations may
not lie.

The following functions remain literal, stable, and usable:

- reading and advancing dialogue;
- transport controls and their active state;
- opening and closing applications;
- selecting, saving, loading, and deleting records;
- changing settings, volume, text size, reveal speed, and input bindings;
- prices, quantities, balances, and transaction results;
- focus, selection, disabled, busy, failure, and recovery states; and
- quitting, returning, and navigating by mouse, keyboard, or controller.

Emotional and symbolic corruption may alter evidence, annotation, alignment,
timing, visual residue, or an authored interpretation. It may not make the
player guess whether a core command worked.

### 4.1 Wrongness budget

- Ordinary use: zero registered anomalies.
- Charged scene or surface: one authored anomaly.
- Climax: one additional anomaly only when required.
- Constant glitch, animated corruption, and random visual noise are prohibited.

An anomaly uses ordinary visual grammar. It receives no horror sting, blood-red
warning frame, fake diagnostic, or tutorial explanation that tells the audience
how to interpret it.

## 5. Internal conceptual lenses

The named theorists guide internal design reasoning rather than appearing as
UI decoration or quotations:

- Robert McKee informs pressure, reversal, and the placement of meaningful
  interaction boundaries.
- Alain Robbe-Grillet informs attention to objects, surfaces, position, and
  evidence without explanatory narration.
- Roland Barthes informs plural interpretation, annotation, authorship, and the
  suspicious relationship between a record and its reader.
- Mark Fisher informs institutional eeriness, normalized abnormality, and the
  disturbance of something that should be present or absent.

The interface must not become affected, academically named, or overloaded with
symbols in order to prove these influences.

### 5.1 Approved four-lens theory-to-form covenant

The project owner approved the following private styling covenant on
2026-08-23. It is the shared theory-to-form test inherited by every application,
host, and Standard-master disposition:

> **Change composition only when represented reality changes. Let object,
> position, repetition, replacement, and absence carry the evidence. Maintain
> ordinary and impossible facts with the same competent materials. Supply no
> privileged decoding key.**

The four named lenses therefore have exact internal formal duties:

- **Robert McKee — pressure at the boundary.** Visual pressure or reversal
  follows a genuine causal boundary. The frame does not manufacture drama around
  an unchanged fact.
- **Alain Robbe-Grillet — exact objects.** Surfaces, positions, distances,
  repetitions, replacements, and absences perform the observation without an
  explanatory ornament or interpretive caption.
- **Roland Barthes — open traces.** Recurring marks may rhyme, but they never
  become a private symbol dictionary, conclusive annotation system, or decoding
  key that tells the audience what a narrative sign means.
- **Mark Fisher — administered impossibility.** When their complete functional
  facts are otherwise identical, routine and impossible events receive the same
  maintained institutional material, typography, geometry, input treatment, and
  assistive parity.

Every UI disposition applies those duties through the following six shared
styling laws:

1. **Repetition earns deviation.** Exact recurring geometry is established
   before one charged surface may alter one measurable property. A whole
   interface never becomes a separate horror skin.
2. **Structure precedes colour.** Distance, alignment, enclosure, density,
   shared axes, seam count, or one lawful boundary trespass carries pressure
   before hue supports it.
3. **One institution contains different instruments.** Every application feels
   maintained by the same university while retaining its own material dialect,
   composition, domain marks, and silence.
4. **Blankness is lawful.** Structural capacity may remain as inert negative
   space. Genuine absence leaves no placeholder, scar, silhouette, mystery
   symbol, reassurance, hidden target, or assistive residue.
5. **The project-wide mass remains restrained.** The existing blend of roughly
   70–75% Quiet Instrumentality, 15–20% Tender Archive, and 5–10% Impossible
   Procedure is a governing weight rather than a per-screen quota. Nocturnal
   habitat remains dominant; pale or warm material is a bounded visitor, not
   mandatory paper or global daylight.
6. **Wear is geology; motion is punctuation.** UI fibres, soot, registration
   drift, and age remain sparse, deterministic, stationary, and clear of text,
   Focus, controls, and required evidence. Motion remains brief, local, and
   governed by the existing Section 13 choreography and its exact surface owner;
   this covenant neither removes nor creates a motion token or authorized use.
   Neither wear nor motion reacts to importance or becomes ambient processing,
   emotional instruction, or a substitute for state truth.

This covenant generalizes verbs rather than nouns. It does not spread Backup's
cabinet, Settings' folio, Contacts' correspondence, Shop's cards, Schedule's
docket, Minesweeper's worksheet, or another application's material into a
universal skin. The theorist names and this calibration vocabulary remain
private documentation and never appear player-facing.

## 6. Native canvas and scaling

### 6.1 Platform

The initial release targets Windows landscape only. It supports Windowed and
Borderless display modes. Mobile, portrait, web-responsive topology, and
exclusive fullscreen are outside the current manual.

### 6.2 Raster law

- Native authored canvas: **640 × 360**.
- Default physical window: **1280 × 720** at 2× integer scale.
- Additional exact integer presentations: 1920 × 1080 at 3× and 2560 × 1440
  at 4×.
- At 1366 × 768, retain a 2× 1280 × 720 game image centred inside an inert
  physical matte of 43 pixels horizontally and 24 pixels vertically per side.
- Texture filtering is nearest-neighbour for authored pixel assets.
- The game canvas never crops, stretches non-uniformly, or rearranges its macro
  topology in response to a different landscape aspect ratio.
- The matte is noninteractive and contains no story evidence.

Existing documents expressed coordinates on a 1280 × 720 stage. The forward
manual expresses the same composition on the 640 × 360 native raster. Exact
legacy coordinates convert by division by two unless a later approved screen
concept explicitly replaces them.

### 6.3 Target and text sizes

- Ordinary minimum target: 24 × 24 native, presented as 48 × 48 at 2×.
- Large Targets: 32 × 32 native, presented as 64 × 64 at 2×.
- Text presets remain 100%, 125%, and 150%.
- Text growth uses wrapping, taller protected text regions, and local vertical
  scrolling. It does not shrink text, create horizontal text scrolling, or
  replace the macro layout.

## 7. Approved spatial architecture

### 7.1 Global compositions

| Surface | Native composition |
|---|---|
| Logged-out title | 160-pixel action ledger + 480-pixel workfield |
| In-run desktop | 240-pixel persistent Angela panel + 400-pixel computer workspace |
| Witnessed scene at 100% text | 52-pixel presence register + 172-pixel tableau + 136-pixel caption/rail deck |
| Witnessed scene at 125% text | 52 + 144 + 164 |
| Witnessed scene at 150% text | 52 + 112 + 196 |

The title, desktop, app, narrative, pause, and ending hosts each own their
rectangles. A child application does not resize or reposition a sibling host.
Only one desktop application is visible at a time; there are no draggable,
overlapping faux windows.

### 7.2 Persistent Angela panel

Angela remains physically present beside every in-run desktop application. The
panel is an authored character/environment surface, not a first-person camera,
mascot sidebar, status dashboard, or narrator portrait.

### 7.3 Witness register

The upper 640 × 52 band is a physical-presence register:

- every physically present character receives one individual avatar portrait;
- portraits contain no visible name;
- accessibility exposes already-disclosed identities such as `Angela,
  speaking` or `Priscilla, present`;
- left-to-right order matches the tableau and never changes when the speaker
  changes;
- one to four portraits form one count-aware centred ensemble;
- the alignment tracks may be wide and invisible, but the visible photo frame
  hugs the portrait rather than stretching across the track;
- an active speaker uses a thicker outer seam plus an inset line;
- quiet portraits keep one solid seam; and
- colour supports, but never replaces, structural speaker evidence.

A small functional avatar is permitted. Cinematic face-filling close-ups,
dramatic eye or hand inserts, and enlarged portrait replacements for the
environmental tableau are prohibited.

## 8. Canonical spoken-scene flow

### 8.1 No inline scene choices

The canonical Narrative Scene Host is a witnessed playback surface, not a
dialogue-choice surface. Canonical Dating, visible Priscilla–Lavinia, Hospital,
and ordered-ending playback MUST NOT publish response lists, moral prompts,
route selectors, default answers, or player-authored Angela lines.

Scenes consume already committed Contacts, Schedule, challenge, route, and
ending-plan facts. They may vary dialogue and staging from those facts but do
not ask the audience to choose the same fact again.

Minesweeper is the sole **in-scene agency and relationship-consequence
mechanism**:

- board play derives Exploded, Solved, or Perfect;
- the accepted non-Perfect solo terminal may expose Continue versus the marked
  special mine; and
- Perfect, explosion, Hospital, pair-board results, and ending-step transitions
  resolve under their accepted automatic laws.

This scope does not remove Contacts reply operations, invitation availability,
Schedule drafting or Day-7 destination selection, Shop purchases, Settings,
Backup confirmations, or other application operations outside authored scene
playback.

### 8.2 Bottom-up caption memory

The first published semantic beat occupies the bottom caption slot immediately
above the control rail. Unused capacity remains above it.

For every later publication:

1. the former current card rises by one retained position;
2. the new current card appears in the bottom slot; and
3. a fourth-oldest card leaves the visible stack but remains in History.

The visual order is always `oldest retained → previous → current`. The first
line therefore starts at the bottom and rises only after a newer line makes it
previous.

Single-language mode shows current plus at most two previous available beats.
Dual Language shows one current bottom card with Primary first and Secondary
second. The language rows share one semantic beat, receipt, History entry, and
advance boundary.

Visual top-to-bottom chronology does not force assistive traversal to begin
with the oldest retained prose. Assistive reading begins with the actionable
current beat, then exposes retained previous beats without announcing them as
new dialogue.

Publication and input readiness never wait for card motion. Reduced Motion,
restore, locale change, text-size change, focus return, and uncover rebuild the
correct stack immediately without replaying the rise.

### 8.3 Control rail

The fixed rail remains:

`History | Skip | Auto | Save | Load | Next`

Ordinary caption activation owns reveal and one-beat advance. There is no
separate Advance button. Save and Load are absent, not disabled, when archive
playback has no canonical run record to operate on.

## 9. Governing aesthetic: Haunted Instrumentarium

The chosen blend is:

- 70–75% Quiet Instrumentality for shell, geometry, navigation, and ordinary
  operation;
- 15–20% Tender Archive for records, Contacts, History, Gallery, and relational
  residue; and
- 5–10% Impossible Procedure for Schedule, Minesweeper, selected anomalies,
  and escalating dark pressure.

The palette hierarchy is more important than any isolated swatch:

- approximately 72% nocturnal habitat;
- 18% muted instrument surfaces;
- 7% readable bone and fog; and
- 3% warm focus, document light, or authored intrusion.

The governing colour law is:

> **Night is the room. Paper is the visitor.**

Cream appears as an exposed document, illuminated caption leaf, selected
memory, or impossible procedural result. It does not become a full-screen
daylight background.

### 9.1 Approved primitives

| Token | Value | Use |
|---|---:|---|
| Void | `#0B0D13` | deepest habitat and inert matte relationship |
| Deep Navy | `#151B25` | ordinary night canvas |
| Bruised Plum | `#2F2936` | records, captions, interpretive residue |
| Oxidized Mint | `#6F8178` | ordinary instrument activity |
| Fog Blue | `#657D89` | secondary active and liminal surfaces |
| Fog Text | `#9EA8A2` | secondary readable text |
| Worn Cream | `#C3BAA3` | rare paper/object illumination |
| Bone Text | `#D8CFB7` | primary nocturnal text |
| Rust Thread | `#8F5A49` | focus support, warning boundary, annotation |
| Tarnished Gold | `#A9935F` | high-priority focus and rare procedural light |

Faded blue-lavender dream colour is reserved for memories, sweetness, and
false-safe intervals. Near-black green Midnight Apparatus treatment is reserved
for late dark pressure and too-perfect enclosure. “Totally Dark” is never a
simple evil-colour swap.

### 9.2 Three-layer token system

Every screen uses:

1. primitive tokens for raw colour, spacing, line, type, and timing values;
2. semantic tokens for canvas, paper, seam, text, focus, warning, evidence, and
   active presence; and
3. component tokens for caption cards, portrait frames, rails, drawers,
   inspector sheets, controls, warnings, and application-specific surfaces.

Components do not introduce unregistered raw values. Theme and
colour-differentiation variants remap semantic roles while retaining shape,
line, pattern, text, and focus evidence.

## 10. Typography

The system uses two type voices only:

- **Fusion Pixel Font** proportional builds for prose and controls, with its
  monospaced builds limited to calculations, timestamps, tables, and numeric
  registers; and
- **Source Han Serif** for rare title, record-heading, and literary display
  raster, authored at exact supported native sizes.

Functional native masters are 8, 10, and 12 pixels. One master is never scaled
to imitate another. Simplified Chinese and Traditional Chinese use their
correct regional glyph forms. Dual Language is a composed layout rather than
two strings squeezed into one row.

No essential information depends on italics, handwriting, tiny capitals,
decorative corruption, or a display serif. No localized text is baked into art.
Font packages, regional subsets, and their license notices must be verified and
shipped with the final asset ledger.

## 11. Pixel materials and component marks

- Square corners and one-pixel seams are the default.
- Selection may use a two-pixel seam and one corner notch.
- Paper receives at most one offset registration shadow.
- Surface fibres are deterministic, static, sparse, and absent beneath glyphs.
- Instrument glass uses two or three flat value bands and a restrained double
  inset.
- Icons use 12 × 12 or 16 × 16 native grids with one-pixel strokes.
- Core operations retain text labels; icons do not become a private pictogram
  language.
- Hover changes value or fill only; it does not move geometry.
- Focus uses a separated outer instrument ring.
- Press uses an inset or reversed seam without scale, bounce, or layout shift.
- Disabled remains readable and structurally distinct; opacity alone is
  insufficient.

Rounded cards, blur, glow, continuous gradients, neon cyberpunk, CRT filters,
scanlines, animated grain, large dot fields, star wallpaper, decorative hearts,
skulls, occult shorthand, and emoji icons are prohibited.

## 12. Relationship phase grammar

Relationship state changes composition before colour:

| Phase | Visual behavior |
|---|---|
| Hate | Exact distance, hard seams, defended territory |
| Friend | Parallel measure, shared baseline, bounded cooperation |
| Ambiguous | One cross-boundary annotation or ownership trespass |
| Love | Shared axis, fewer chrome lines, greater restful silence |
| Sweet | Warm irregularity, one repaired seam, boundaries preserved |
| Totally Dark | Human irregularity removed; enclosure and synchrony become too perfect |

No character, route, or phase receives a complete independent skin. Day may
alter the global atmosphere; relationship state alters local intimacy; dark
pressure affects peripheral precision; and Observer corruption stays inside
its registered scene scope.

## 13. Interaction choreography

The governing law is:

> **The hand answers now. The world answers after.**

The control acknowledges input immediately. Fictional material may settle one
restrained beat later. Atmosphere never requires disobedience or latency.

### 13.1 Tempo blend

- 75% Quiet Clockwork: ordinary interaction.
- 15% Dream Drift: wordless seams, memories, and false-safe intervals.
- 10% Mechanical Snap: technical refusal, impossible correction, and late dark
  pressure.

### 13.2 Motion tokens

| Token | Duration | Use |
|---|---:|---|
| Now | 0 ms | state publication, focus, Reduced Motion, technical truth |
| Touch | 60 ms | pressed inset and release acknowledgement |
| Settle | 120 ms | local line, notch, and value settlement |
| Shift | 180 ms | bottom-up caption rise or panel-content arrival |
| Veil | 240 ms | rare artwork transition or wordless seam |
| Authored hold | 0.4–1.6 s | explicit story rhythm only; never disguised loading |

Motion never delays semantic publication, input readiness, focus, assistive
announcement, saving, or state commitment. Reduced Motion replaces shifts,
veils, shake, and decorative scrolling with the correct static state.

### 13.3 Input laws

- One admitted event performs at most one semantic command.
- If a line is still revealing, Accept completes it and stops. A later released
  Accept advances one beat.
- Held or repeated input is release-gated across reveal, challenge, modal,
  restore, pause, and route boundaries.
- Hover inspects only; it never selects, focuses, confirms, advances, purchases,
  or rewrites a state.
- Opening a surface places focus deliberately. Closing or cancelling returns
  focus to the exact semantic source.
- A rejected command explains the operational reason and preserves the prior
  state. It does not punish, substitute silently, or simulate corruption.

### 13.4 Transport arbitration

Auto, Skip, and Next remain mutually exclusive under their accepted mechanics.
They never choose a Minesweeper result, cross a challenge or effect boundary,
act behind a modal, or complete a route without its owner.

### 13.5 Interaction sound

- Hover is silent.
- Focus is ordinarily silent; entering a new focus group may use one dry tick.
- Accept uses a short, soft mechanical contact rather than a reward sparkle.
- Operational refusal uses two close dull tones plus literal text, never a
  supernatural or horror sting.

## 14. Backup Load and delete confirmation

Delete exists only in Backup's `Load` mode and the title's load-only `Log in`
surface. Save mode does not expose Delete.

Activating Delete changes the shared Backup inspector into an **app-contained
modal consent sheet**. It never opens over a narrative scene, the whole game
canvas, or an operating-system-styled window.

The owner has locked the within-Load ownership. This written proposal chooses
inspector replacement as the exact contained geometry; approval of this file
locks that refinement.

The cabinet, selected drawer, mode, and surrounding Backup page remain visible
and geometrically unchanged. Every control outside the consent sheet becomes
inert, including drawers, mode controls, shortcuts, host navigation, and other
inspector actions.

The sheet:

- repeats the bound drawer identity and its visible Day/time or Unavailable
  state;
- states `Delete <record>? This save will be deleted.`;
- offers only `Delete` and `Cancel`;
- gives initial focus to Cancel;
- traps sequential and spatial focus;
- maps Back, Escape, and controller B to Cancel; and
- invalidates consent if the selected record revision changes.

Cancel or failure restores focus to the invoking Delete control. Successful
Delete remains in Load mode, retains the drawer as selected, projects it as
Empty, announces the truthful result, and moves focus to that now-Empty drawer
because Delete is no longer available. Confirmation state is never saved or
restored.

The same inspector consent-sheet component may host lawful overwrite and Load
confirmations in their accepted modes.

## 15. Application material dialects

One visual family contains several functional dialects:

- Contacts: correspondence slips, withheld lines, and marginal ownership marks.
- Shop: specimen catalogue, provenance, quantity, and brutally literal price.
- Backup: fixed archive cabinet, record inspector, and consent sheet.
- Settings: calm maintenance panel whose operational state never corrupts.
- Schedule: ruled procedural folio and docket.
- Minesweeper: calculation worksheet and instrument of consequential agency.
- History and Gallery: suspicious archive and registrar record.

These are material behaviors, not independent skins. All inherit the same
token roles, focus grammar, type system, native grid, and reliability law.

## 16. Accessibility, input, and localization

- Every core operation supports mouse, keyboard, and controller.
- Optional shortcuts never own exclusive functionality.
- Nonlinear focus neighbours are authored explicitly; focus never enters
  portraits, backgrounds, or decorative evidence.
- Focus, selection, active transport, speaker, disabled, busy, warning, and
  unavailable states do not depend on colour, motion, texture, or sound alone.
- Destructive confirmations begin safely and trap focus.
- Reduced Motion preserves every semantic result.
- Screen shake is never required for horror and may be disabled.
- High Contrast and Standard, Protan, Deutan, and Tritan differentiation use
  authored functional theme tuples rather than recolouring character art.
- Primary Language, Secondary Language, and Dual Language remain independent
  layout concerns.
- English, Simplified Chinese, and Traditional Chinese must be tested with real
  longest strings, line breaking, and correct regional glyphs before parity is
  claimed.
- Assistive descriptions expose only already-disclosed character identity and
  visible evidence; they do not reveal internal IDs, hidden motives, or solved
  interpretations.
- No screen-reader compatibility claim is public until physically verified in
  the exact Windows and Godot build.

## 17. Art and placeholder policy

Existing art may be reused only after it is matched to an approved semantic
asset slot. If required production art is missing, the manual will provide:

1. an exact asset brief;
2. native dimensions and crop/focal rules;
3. a clearly labelled sample placeholder;
4. the final replacement path; and
5. manifest, filtering, accessibility-description, and localization rules.

Samples are never presented as canon. The existing quartet lineup is mood
evidence only; no exact face, body, height, garment, hairstyle, or silhouette is
preserved automatically.

Required art failure uses trusted recovery. Optional art either collapses under
an approved rule or uses an explicit neutral fallback. Art never encodes hidden
affection, relationship tier, route, ending, recommendation, or invisible
mechanic.

## 18. Retained prototype assessment

The newest exported atlas is retained as a structural base because it already
demonstrates strong host ownership, focus/state coverage, Angela persistence,
presence framing, and many app layouts.

It is not the final surface treatment. The forward plan is to preserve roughly:

- 85% of its interaction architecture;
- 70% of its macro topology;
- 30% of its current surface styling; and
- none of its placeholder art as production art.

The exported build and later written specifications must be merged
intentionally. File modification time alone does not make either one complete.

## 19. Forbidden interaction and horror patterns

The UI must never:

- move a target away from the player;
- exchange affirmative and negative actions;
- steal focus;
- fabricate a successful save, load, purchase, or setting change;
- misreport a price, quantity, balance, setting, selected slot, or technical
  failure;
- erase an offered operational action without a truthful state change;
- require interpretation of a glitch to continue;
- hide essential horror from non-pointer or non-audio users;
- simulate an operating-system crash or corrupt installation;
- present fake diagnostics as fiction;
- use unreadability, clipped CJK glyphs, or tiny text as atmosphere; or
- treat an accessibility setting as a difficulty penalty.

## 20. Foundation acceptance checks

The eventual implementation evidence for these sections must prove:

- exact 640 × 360 composition at 2×, 3×, and 4× integer scales;
- centred inert matte at 1366 × 768;
- correct 100%, 125%, and 150% caption allocation;
- 24-pixel and 32-pixel native target modes;
- one to four witness portraits with immutable order and no visible names;
- first caption at the bottom, then deterministic upward retention;
- no inline scene response list in canonical scene playback;
- Minesweeper result ownership at the in-scene consequence boundary;
- Delete available only in Load/title Log in and confirmed in the Backup
  inspector consent sheet;
- Cancel initial focus, focus trap, Back-to-Cancel, and exact focus restoration;
- keyboard-, pointer-, and controller-only completion of every core flow;
- non-colour differentiation for every functional state;
- Reduced Motion static parity;
- zero clipping, ellipsis, or horizontal text scrolling for tested EN, zh-CN,
  and zh-HK fixtures; and
- literal technical failure with unchanged prior canonical state.

## 21. Deliberately unresolved next sections

The following are not decided by this foundation ledger and require later
manual sections:

- final screen-by-screen concepts and art direction for Title, Angela Desktop,
  every application, History, Pause, Hospital, Endings, and Gallery/Rehearsal;
- final component anatomy and every state variant;
- character and environment asset briefs, sample locations, and replacement
  manifest;
- detailed sound and ambience grammar beyond the quiet interaction principles;
- anomaly registration per authored scene;
- public spoiler-safe manual extraction;
- exact Godot scene/resource changes; and
- the implementation, testing, migration, and evidence plan.

These topics must not be inferred from a disposable specimen or current
placeholder scene before their manual sections are approved.
