---
id: spec.title_art_placement_bottom_up_scene_caption_rhythm_amendment
kind: design_amendment
schema_version: 1
amends: spec.main_menu_desktop_shell_global_chrome_ui_ux_amendment
amends_path: "docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md"
related_authorities: ["spec.narrative_scene_host_dating_hospital_challenge_ui_ux_amendment","spec.ordered_ending_host_universal_pause_ui_ux_amendment","guide.visual_art_placement_and_asset_production"]
decision_status: proposed
conversational_design_status: approved
written_spec_status: proposed
self_review_status: passed
self_reviewed_on: "2026-08-14"
implementation_requested: true
implementation_requested_on: "2026-08-14"
implementation_requested_scope: title_art_presenter_and_bottom_up_scene_caption_rhythm_only
implementation_authorized: false
implementation_gate: exact_written_spec_and_reviewed_plan_required
created_on: "2026-08-14"
engine_line: godot_4_6
verification_engine: "4.6.3-stable-mono"
dialogic_version: "2.0-Alpha-19"
language: gdscript
scope: ["logged_out_unhosted_title_art_placement","title_art_host_replacement_and_focus","shared_narrative_caption_visual_order","caption_motion_accessibility_and_semantic_parity","narrow_runtime_component_and_verification_boundary"]
---

# Title Art Placement and Bottom-Up Scene Caption Rhythm Amendment

## 1. Status and objective

This proposed written amendment records two conversation-approved refinements
for the actual Godot game:

1. the unhosted logged-out title owns a dedicated placement for future authored
   title artwork; and
2. the shared Narrative Scene Host presents its visible caption cards from
   older at the top to current at the bottom.

The user explicitly requested both the game-design specification and the
bounded implementation on 2026-08-14. The request covers the two
frontmatter-scoped refinements only. Repository implementation remains gated on
review of these exact written bytes and a reviewed implementation plan. This
proposed artifact does not authorize unrelated shell reconstruction, narrative
content, art production, authority-registry mutation, Beads mutation, or HTML
prototype changes.

The title decision is a **placement decision, not an artwork commission**. The
game must provide the exact presenter and its ownership rules now, while the
texture remains unset until separately approved title art exists.

The caption decision is a **visual rhythm clarification, not a new dialogue
history model**. Existing semantic beats, receipts, reveal behavior, language
modes, History, TTS, choices, and transport laws remain authoritative.

## 2. Authority and precedence

### 2.1 Direct title authority

This amendment narrowly supersedes the accepted Main Menu, Desktop Shell, and
Global Chrome amendment only where that artifact requires the unhosted title
content field to be empty and forbids placeholder illustration.

The parent amendment retains authority for:

- the fixed 1280-by-720 logical canvas and inert physical matte;
- the title ledger at `x=0..320`, `y=0..720`;
- the title workfield at `x=320..1280`, `y=0..720`;
- the host strip at `x=320..1280`, `y=0..64`;
- hosted content at `x=320..1280`, `y=64..720`;
- the title ledger order, Dark entitlement, clock, focus, confirmation, and
  route laws; and
- the exact Log in, Gallery, and Settings host ownership.

This amendment changes only the unhosted content projection at
`x=320`, `y=64`, `w=960`, `h=656` from deliberately empty to an inert title-art
presenter.

### 2.2 Shared narrative authority

The accepted Narrative Scene Host amendment retains sole authority for:

- the 104-pixel portrait register, adaptive tableau, caption deck, and pinned
  64-pixel control rail;
- the current beat plus two previous available beats in single-language mode;
- the one current bilingual semantic card in Dual Language mode;
- reveal, ordinary Accept, Auto, Skip, Next, choices, History, TTS, save, load,
  pause, challenge, and completion behavior;
- semantic presentation receipts and physical completion tokens; and
- accessibility, localization, target sizes, focus, and failure truth.

This amendment adds only the missing visual-order and bottom-anchor law for
those already-defined caption cards.

The accepted Ordered Ending Host amendment continues to consume the same
caption rules. Archive Scene replay, Full-Date narrative presentation,
canonical Dating, visible pair scenes, Hospital, and ordered ending playback
must therefore share this refinement rather than implement local variants.

### 2.3 Visual-art authority

This amendment reserves an empty consumer surface only. It does not supersede
the Visual Art Placement guide's current prohibition on a title-screen cast
lineup, logo hero, or Angela splash, nor its separate rule that Angela does not
become title key art. A later approved art decision must reconcile those exact
rules before any texture is assigned.

The following retained art laws remain unchanged:

- model sheets and turnarounds are production reference only;
- character art never changes form to disclose route, affection, tier, tone,
  Dark, Observer, Special, condition, or ending truth;
- functional palette and accessibility changes do not recolour authored art;
  and
- missing optional decoration never changes focus, route, save state, or
  gameplay behavior.

### 2.4 Scope-owner rule

The scope owner wins; newest date does not create general precedence. This
amendment must not be read as authority over unrelated title, shell, Dialogic,
narrative, ending, Gallery, Settings, Backup, Contacts, art, or accessibility
decisions.

## 3. Scope and explicit exclusions

### 3.1 In scope

- one semantic unhosted-title art presenter and its exact logical rectangle;
- its visibility during title destination hosting and return;
- its input, focus, accessibility, scaling, and missing-art behavior;
- the visual top-to-bottom order of existing caption cards;
- the current caption's bottom anchor and retained-caption upward movement;
- parity across every consumer of the shared Narrative Scene Host; and
- narrow Godot components and tests needed to prove those behaviors.

### 3.2 Out of scope

This amendment does not:

- create, generate, select, or approve the actual title artwork;
- add title copy, a temporary game logo, a title animation, or a loading state;
- redesign the ledger, host strip, clock, title palette, confirmations, or
  title routes;
- authorize a title-screen cast lineup or model-sheet placement;
- redesign caption typography, alignment, transparency, width, colours, or
  prose;
- change Contacts, self-talk, or ordinary application language projection;
- change the number of retained beats, Dual Language semantics, History, TTS,
  reveal, choices, Auto, Skip, Next, save, load, or pause;
- complete the still-missing full Title Shell or Narrative Scene Host;
- alter Schedule, Minesweeper, Pause, or their separate prototypes; or
- modify any HTML design atlas or companion demonstration.

## 4. Unhosted title-art presenter

### 4.1 Exact owned rectangle

When the logged-out title has no hosted destination, the title-art presenter
owns exactly:

`x=320`, `y=64`, `w=960`, `h=656`

in the accepted 1280-by-720 logical canvas.

The presenter never overlaps the left ledger or the 64-pixel title host strip.
It does not resize, reflow, or move at 100%, 125%, or 150% text size or when
Large Targets is enabled. Physical window sizes uniformly scale and center the
whole logical canvas under the retained shell law.

### 4.2 Placement-only initial state

The initial implementation leaves the presenter's texture unset. That empty
asset state is intentional and complete for this slice. It must show:

- no substitute title words;
- no invented logo;
- no registration marks, checkerboard, frame label, or drop target;
- no broken-image icon or technical placeholder;
- no stock, model-sheet, atlas, or temporary character image; and
- no loading, missing-art, or `coming soon` copy.

The presenter is a semantic future-art slot, not a visible UI panel. Its empty
state may reveal the ordinary workfield material beneath it.

### 4.3 Deferred asset handoff

This amendment creates no title-art asset binding. A later approved title-art
decision may define one semantic binding, aspect-preserving crop, and authored
focal rule for this placement. Until then, the presenter remains empty.

That future decision may approve an authored title treatment as image content,
but it must not bake interactive ledger states, focus, clock, Dark entitlement,
language, save availability, or other functional UI into the pixels.

Missing or unreadable optional title art resolves to the intentional empty
presenter. It cannot enter technical recovery, block the title, fabricate a
fallback image, or change the ledger's behavior.

### 4.4 Interaction and accessibility

The presenter:

- is noninteractive and never receives pointer, touch, keyboard, controller,
  or assistive activation;
- has no focus mode, tooltip, drag behavior, context action, or cursor change;
- does not intercept hit tests intended for the title shell;
- is absent from sequential and spatial focus traversal;
- contributes no accessibility node, label, description, live region, or
  announcement in its empty state; and
- never changes initial focus from `New Acc`.

If future approved artwork contains information that becomes essential, that
information must be represented separately through a later accessibility
decision. This placement alone is decorative.

### 4.5 Hosted replacement

Opening Log in, Gallery, or Settings replaces the unhosted title-art presenter
before the hosted component becomes visible and interactive. The presenter is
hidden, pointer-inert, process-inert, and absent from the accessibility tree
while a title destination owns the workfield.

After a hosted destination's local layers retreat, closing that hosted
destination restores the empty or authored presenter and returns focus to the
exact initiating ledger row under the retained host law. Restoring the
presenter never creates a focus event, live announcement, or art animation
receipt.

Trusted title-workfield confirmations and recovery layers retain their accepted
owners and overlay laws. They may leave the presenter visible beneath them, but
make it inert and do not destroy or reload its optional texture. This amendment
adds no new visibility rule for those layers. Technical recovery retains its
existing higher global priority.

### 4.6 Lifecycle projection

The presenter appears in both Fresh and Dark-entitled logged-out title states.
Entitlement controls only whether the Dark next-run selector row exists. The
pending next-run choice retains its accepted ownership of title palette and
next-run intent. This amendment defines no Dark artwork variant and never
recolours title-art pixels.

The normal completed-ending matte returns to this ordinary title projection,
with the current pending next-run palette, truthful clock, `New Acc` focus, and
the unhosted title-art presenter. It still shows no completion badge, ending
title, summary, percentage, or automatic Gallery route.

## 5. Bottom-up caption rhythm

### 5.1 Visual stack invariant

The caption viewport is bottom-anchored above the pinned control rail. Caption
cards are ordered visually from oldest retained at the top to current at the
bottom.

For single-language presentation:

| Available semantic beats | Visual order from top to bottom |
|---:|---|
| 1 | current |
| 2 | previous, current |
| 3 | oldest retained, previous, current |

The current semantic caption is always the lowest **caption card**. Blank
capacity, when present, stays above the stack rather than beneath the current
card.

Inline choices remain immediately below their source beat. When the current
beat owns choices, the current card is still the lowest caption card and the
choice block follows it before the control rail.

### 5.2 Publication movement

When a new semantic beat is published:

1. it becomes the new current card at the bottom;
2. the former current card rises into the nearest retained position;
3. the older retained card rises to the top position when one exists; and
4. a fourth-oldest beat leaves the visible stack without changing History.

The ordinary motion treatment is one restrained upward material shift. It may
not delay semantic publication, input readiness, caption reveal, TTS, or
completion. It may not flash skipped captions or turn semantic history into a
carousel.

Reduced Motion replaces the shift with an immediate static swap. Restore,
locale change, text-size change, focus return, and uncover also rebuild the
correct stack without replaying the shift.

### 5.3 Semantic identity is unchanged

Visual movement creates no new semantic beat, line ID, presentation atom,
receipt, visited state, History entry, TTS utterance, live announcement, Auto
delay, Skip frontier, Next frontier, or save boundary.

Dialogic append fragments that belong to one canonical semantic beat update
the same current card. They do not push the current card upward or create a
false previous beat.

The stack changes only when the accepted narrative presentation contract
publishes a new semantic beat or replaces the current presentation boundary.

### 5.4 Language modes

Single-language mode retains the current beat plus the previous two available
beats exactly as already accepted.

Dual Language mode contains one current semantic card at the bottom. Primary
appears first and Secondary second inside that card. The two language rows do
not become two cards and do not create a retained-beat stack.

Changing language or Dual Language mode reprojects the same semantic state in
place. It does not admit, replay, visit, announce, or shift a beat.

### 5.5 Reveal, transport, and choices

Partial text reveal occurs only inside the current lowest card. Completing a
reveal through ordinary Accept does not move the card. Only publication of the
next semantic beat changes the stack.

Auto, Skip, and Next retain their exact accepted boundaries. Traversal that is
defined to avoid flashing captions does not animate intermediate cards through
the stack. The presenter commits directly to the accepted destination visual
state.

Choices remain inside the protected caption deck, below their source beat.
Opening, changing, or resolving a choice cannot reorder unrelated retained
beats or create a duplicate current card.

### 5.6 Visual and semantic reading order

The visual caption order is chronological from top to bottom. The assistive
reading order remains action-oriented and begins with the current caption,
followed by any previous cards exposed by the active language mode, then
choices, then the control rail. Visual placement must therefore be independent
of semantic and assistive child order; a chronological visual container cannot
silently force oldest-first assistive traversal.

Focus never lands on ordinary caption text. Repositioning cards cannot move
focus, steal focus, alter the focused choice or rail control, or announce
retained prose again. When the current caption exposes an activation target,
that current target retains its semantic focus position while visual cards
move around it.

Read Aloud continues to read Primary current content only and follows the
accepted disclosed-speaker-change cadence. It does not read retained cards
because they moved.

### 5.7 Text size and overflow

The current card remains visible at 100%, 125%, and 150% text size. The caption
deck grows upward and the tableau yields space under the accepted host law.
When local vertical scrolling is still required, publication scrolls only
enough to keep the current card and active choice visible.

There is no horizontal caption scroll, silent font reduction, clipping,
ellipsis, overlap, or reordering. Receding cards retain the selected font size
and the same text contrast; their hierarchy comes from material, spacing, and
depth rather than smaller or lower-contrast text.

### 5.8 Shared-host parity

One reusable caption presenter owns this visual invariant for:

- canonical Dating and other authored narrative scenes;
- visible Priscilla-Lavinia scenes;
- boardless Hospital;
- archive Scene replay;
- the narrative portions of Full-Date Rehearsal; and
- every ordered ending step.

No consumer may clone the presenter, reverse its order, add a local transcript
above it, or preserve the retired disconnected `DialogueBox` as a second live
caption owner.

## 6. Runtime ownership boundary

### 6.1 Title component

The narrow title slice may introduce one named presenter component or owned
node at the exact unhosted-title rectangle. The title host owns only its
visibility and optional semantic texture binding. It does not load narrative
state, mutate profile/run state, or become an application route.

### 6.2 Caption component

One project-owned Narrative Caption presenter receives immutable semantic
caption projections from the narrative presentation boundary. It owns visual
card pooling, bottom anchoring, trimming to the active language-mode depth,
reveal projection, and optional upward transition.

It does not:

- parse raw Dialogic labels or infer semantic line identity from prose;
- choose dialogue, advance a timeline, or acknowledge effects;
- own visited/history state, TTS, save/load, route, relationship, or ending
  state; or
- serialize Controls, Nodes, card positions, tween progress, or scroll pixels.

A project-owned Dialogic presentation seam may feed this component. The
bundled fallback Visual Novel textbox and the retired `DialogueBox` cannot
remain simultaneously visible as alternate caption owners.

### 6.3 Narrow implementation truth

Once authorized, the initial implementation is deliberately a partial
production slice:

- it integrates the empty title-art presenter into the current Menu scene at
  the accepted logical coordinates and proves that geometry in a deterministic
  1280-by-720 scene fixture; and
- it builds a project-owned selectable Dialogic caption style and proves that
  style against a physical test timeline.

The slice does not establish the still-missing project-wide 1280-by-720 window
scaler and does not make the caption style the project-wide default. Global
style activation waits until the narrative coordinator owns semantic
host/style selection; activating it sooner would also replace presentation for
unscoped Dialogic consumers. This slice therefore must not claim complete live
conformance of the broader title shell or Narrative Scene Host while their
accepted hosts, manifests, coordinators, focus graphs, art, localization,
window scaler, and route adapters remain unfinished.

The implementation must preserve unrelated user work already present in the
working tree. It may not rewrite existing authority documents, HTML demos,
Beads state, or unrelated project configuration.

## 7. Persistence, restore, and failure

The title-art presenter owns no saved state. A title texture path, crop, load
status, or visibility flag does not enter profile or run documents.

The caption presenter owns no canonical history. Save and restore use the
accepted semantic narrative checkpoint. After restore, the presenter rebuilds
the current visual stack from authoritative semantic projection without
replaying reveal, movement, TTS, announcements, choices, or receipts.

An unknown caption projection, conflicting semantic beat sequence, or missing
required current localization fails through the retained trusted narrative
recovery boundary. The presenter never guesses chronological order from node
order or localized text.

Missing optional title art remains the intentional empty title-art placement
and is not a technical failure.

## 8. Exact supersession and retained law

Once this exact artifact is approved, it supersedes only:

- the rule that the unhosted title content field is deliberately empty;
- the verification expectation that the title workfield contains no artwork
  placement;
- every Ordered Ending Host requirement that returns to the ordinary logged-out
  empty title workfield, replacing only that empty projection with the ordinary
  unhosted title-art presenter while retaining route, durability, palette,
  clock, and `New Acc` focus law; and
- any caption implementation that places current above retained captions,
  top-anchors a short stack, or creates a fourth visible beat.

It retains:

- no instructional title copy, fake terminal, tutorial hint, placeholder art,
  or temporary logo;
- no model sheets, cast lineup, or unapproved Angela splash on title;
- no routine visible speaker label;
- current plus two previous single-language depth;
- one bilingual current card in Dual Language mode;
- the protected lower caption deck and pinned control rail;
- captions separate from the physical tableau;
- choices beneath their source beat;
- current-first assistive reading and Primary-only TTS;
- no visual movement as canonical history or evidence; and
- every accepted route, save, focus, accessibility, failure, and narrative
  domain boundary outside this amendment's exact scope.

## 9. Current implementation drift

The current physical project is not design precedent:

- `MenuScene` has a small legacy ledger and no exact title workfield or title-art
  presenter;
- Backup and Settings currently reuse the legacy left rectangle rather than
  the accepted title workfield;
- `DatingScene` contains placeholder character zones and an unbounded previous-
  dialogue list;
- the disconnected `DialogueBox` contains a routine visible speaker label and
  one current text label;
- Dialogic currently falls back to its bundled Visual Novel style rather than
  one project-owned Narrative Caption presenter; and
- Hospital and Ending remain separate label/button scaffolds.

The narrow implementation may establish the requested components without
pretending those broader drifts have been reconciled.

## 10. Verification contract

Sections 10.1 through 10.4 define eventual conformance for the scoped design
law. Section 10.5 bounds the initially requested implementation evidence and
prevents component tests from being reported as completion of the missing host
architecture.

### 10.1 Title placement

Verify at the 1280-by-720 logical canvas:

- exact presenter rectangle `(320,64,960,656)`;
- texture unset and no child copy or placeholder;
- mouse filtering, focus, tooltip, drag, and accessibility exclusion;
- `New Acc` remains initial focus;
- visibility in Fresh and entitled unhosted title states;
- complete hiding while Log in, Gallery, or Settings is hosted;
- exact source-focus return and presenter restoration after host close;
- title confirmations and technical recovery retain their accepted priority;
- no layout movement at 100%, 125%, 150%, ordinary targets, or Large Targets;
  and
- successful ending return restores the ordinary presenter without completion
  copy or automatic Gallery activation.

### 10.2 Caption stack unit behavior

Using stable semantic fixture IDs, verify:

- one beat occupies the lowest caption position;
- a second publishes below the first and moves the first upward;
- a third yields oldest, previous, current from top to bottom;
- a fourth evicts only the oldest visible card;
- Dialogic append fragments update one current card;
- partial reveal never changes card order;
- single and Dual Language depth/order;
- choices stay below their source current card;
- visual transitions create no semantic callback or focus movement;
- assistive traversal remains current then retained while the visual stack is
  oldest then current;
- retained cards stay nonfocusable and are not announced again when moved;
- Reduced Motion and restore use static reconstruction;
- locale/text-size reprojection does not shift semantic state;
- current remains visible during local overflow; and
- reset at an authoritative timeline/session boundary clears prior cards.

### 10.3 Real narrative presentation

Explicitly load the project-owned selectable style against a real test timeline
and assert:

- the Narrative Caption presenter receives stable semantic beats;
- the selected style contains exactly one live Dialogic text owner, so the
  bundled fallback textbox and retired `DialogueBox` are not also visible;
- current plus two previous beats render in the required visual order;
- Dual Language renders one current bilingual card;
- timeline append does not fabricate a previous beat;
- timeline/session replacement cannot retain captions from another session;
- ordinary Accept, Auto, Skip, Next, choice, and completion boundaries remain
  owned by their accepted systems; and
- archive and ordered-ending consumers can reuse the same component rather
  than copy its rules.

### 10.4 Structural and regression checks

Static and scene checks must prove:

- no HTML file changed;
- no title artwork or placeholder asset was added;
- no second caption history or save schema was created;
- no narrative presenter directly mutates GameState, relationships, Schedule,
  Gallery, route, or storage;
- no routine speaker label becomes part of the new component;
- the new title-placement and caption-layer suites pass, and applicable
  existing Dialogic bridge, skip/effect boundary, restore, localization,
  project-config, and scene-smoke regressions remain green; and
- all Godot tests run through the repository's isolated test wrapper.

### 10.5 Initial partial implementation evidence

The first implementation plan may prove only:

- the Menu scene owns one empty, inert presenter at
  `Rect2(320,64,960,656)` when instantiated under a deterministic 1280-by-720
  fixture;
- the current Log in and Settings host paths hide and restore that presenter
  without changing their initiating ledger focus;
- the current ledger does not overlap the presenter's owned rectangle;
- no title image, title copy, HTML, Beads state, or unrelated project setting
  changes;
- one reusable caption layer implements the one/two/three/four-beat and append
  fixtures in both language-depth modes;
- one complete project-owned Dialogic style contains exactly one live Dialogic
  text owner and drives that layer against a physical fixture timeline; and
- applicable focused and regression suites pass through isolated Godot.

This evidence does not prove physical window matte/scaling, hosted Gallery,
ending return, archive reuse, production narrative routing, global Dialogic
activation, final localization, or completion of either parent host.

## 11. Written acceptance gate

Before implementation begins, self-review must establish that this document:

- contains no unresolved title-art or narrative-content decision required for
  this placement-and-caption slice, while final artwork remains explicitly
  deferred;
- distinguishes a placement from artwork;
- distinguishes visual caption order from semantic history;
- explicitly preserves every accepted caption and title law outside scope;
- contains no HTML companion or prototype authority;
- contains no false claim that the full shell or Narrative Host is complete;
  and
- binds implementation and verification only to the two requested slices.

After self-review, the project owner reviews these exact bytes. Approval changes
`decision_status` and `written_spec_status` to accepted/approved, records the
approval date, and may change `implementation_authorized` to true for the
initial partial implementation evidence in section 10.5. Execution then
proceeds only through a separately reviewed, path-bounded implementation plan.
