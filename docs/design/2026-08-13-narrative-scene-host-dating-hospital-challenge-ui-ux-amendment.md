---
id: spec.narrative_scene_host_dating_hospital_challenge_ui_ux_amendment
kind: design_amendment
schema_version: 1
amends: spec.seven_day_dialogic_flow
amends_path: "docs/design/2026-08-07-seven-day-dialogic-flow-design.md"
decision_status: accepted
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
self_reviewed_on: "2026-08-13"
written_spec_approved_on: "2026-08-13"
implementation_authorized: false
created_on: "2026-08-13"
engine_line: godot_4_6
verification_engine: "4.6.3-stable-mono"
language: gdscript
scope: ["project_wide_spoken_scene_physical_presence","narrative_scene_host_information_architecture","physically_present_portrait_register_and_third_person_tableau","caption_choice_history_and_transport_controls","auto_skip_next_and_normal_accept_semantics","dating_minesweeper_pressure_layer_and_transition","hospital_host_preset_and_completion","narrative_pause_backup_save_load_and_exact_restore","narrative_localization_accessibility_visual_audio_and_failure","narrative_component_ownership_supersession_and_verification"]
---

# Narrative Scene Host, Dating, Hospital, and Challenge UI/UX Amendment

## 1. Status and objective

This accepted written amendment records the approved design for the shared
narrative scene host used by canonical dating scenes, visible
Priscilla-Lavinia encounters, and Hospital presentation.

The user approved this exact self-reviewed artifact on 2026-08-13. That
approval establishes bounded design authority; it does not authorize
implementation. Requirement packets, authority registries, Beads, hash-bound
plans, schemas, manifests, timelines, scenes, localization, tests, art, audio,
and runtime code remain unchanged until separately reconciled and explicitly
authorized.

The chosen experience is a **witnessed third-person scene in three persistent
bands**:

- a top portrait register contains only characters physically present in the
  authored shot;
- a middle tableau shows the complete environment and the characters' visible
  bodies, movement, objects, and actions; and
- a protected lower reading deck contains captions, inline choices, and the
  exact control rail.

Angela is always Angela. The camera never asks the audience to occupy her body,
stand in for her, or infer that she is a player-avatar. When she is present, she
is physically staged and receives the same honest portrait treatment as every
other present participant.

The design has eight objectives:

- preserve character autonomy through an explicitly witnessed camera;
- make multi-person conversation readable without turning portraits into a
  messenger roster or speaker-name banner;
- keep physical action and consent visible while captions remain protected;
- distinguish ordinary line advance, Auto, continuous Skip, and the stronger
  `Next` seek command exactly;
- let a reached Minesweeper challenge emerge as pressure inside the same scene
  without becoming a debug result selector or unrelated route;
- reuse the trusted Backup, Settings, save, load, focus, and recovery laws;
- resume exact semantic narrative and board state without saving live UI
  objects or animation positions; and
- preserve complete operation at 100%, 125%, and 150% text with keyboard,
  controller, pointer, touch, TTS, and assistive parity.

### 1.1 Approved derived closures

The conversation fixed the product direction. The following derived closures
are part of this amendment so that the design is deterministic and testable:

- Project-wide authored spoken narrative has **no offscreen-speaker state**.
  Every spoken line belongs to a character physically present and visibly
  staged in the current authored shot. This amendment enforces that rule for
  its scoped host; every future spoken-scene or ending manual must retain it.
  The host has no offscreen portrait, hidden speaker, remote voice, silhouette,
  fallback avatar, or retained prior portrait branch.
- Written Contacts messages are not spoken narrative and are unaffected by that
  rule. Environmental sound without a speaking character also remains possible
  when it follows the existing visual-equivalent law.
- Physical presence comes from validated shot metadata, not from inference
  based on dialogue text. When a character exits the shot, their body and
  portrait leave at the same registered presentation boundary.
- Persistent three-band design means persistent topology, not immutable pixel
  heights. At 125% and 150%, functional caption height consumes middle-tableau
  space before any text is clipped or reduced.
- The portrait order mirrors authored left-to-right tableau order. Speaker
  changes never reorder, slide, or replace participants.
- A speaking portrait receives a non-colour double-frame or raised-tab cue plus
  restrained brightness. Silent portraits remain legible; colour or luminance
  is never the sole speaker cue.
- The lower canonical control order is exactly
  `History | Skip | Auto | Save | Load | Next`.
- Ordinary click, tap, keyboard Accept, and controller Accept follow normal
  visual-novel behavior: if the current line is revealing, one activation
  completes it; only a later activation advances to the next beat.
- `Next` is not ordinary advance. It seeks through exact already-witnessed
  material toward the next exact unseen presentation variant, a challenge, or
  legal scene completion.
- Exact witnessed status includes every frozen field capable of changing a
  line or action. A familiar base line under a new tier, tone, attitude, echo,
  result, or staging variant is unseen and stops `Next`.
- `MINESWEEPER_ENTRY` is a dedicated semantic boundary kind. It is not encoded
  as a generic marker, effect, or route transition.
- A deliberate `Next` reaching `MINESWEEPER_ENTRY` atomically begins the exact
  untouched challenge without asking for a second Accept. It may not cross a
  colocated choice, effect transaction, acknowledged marker, or unrelated route
  transition.
- If no unseen material and no unentered or active challenge remain in the
  current segment, `NARRATIVE_COMPLETION` is the other closed `Next` exception:
  it may complete that exact already-witnessed scene through its normal
  idempotent completion command. This covers boardless scenes and familiar
  post-challenge segments. It may not stand in for an unresolved choice or
  unacknowledged consequence.
- Auto, Skip, and Next are mutually exclusive transport modes. Next is a
  one-shot command. Any of them stops current Read Aloud before taking control.
- During a challenge, the six narrative controls withdraw. The canonical board
  and its own Back/Pause surface own input until the board reaches a stable
  terminal result.
- Save and Load open the already-approved trusted Backup component in the
  requested mode. There is no narrative-only miniature slot system.
- Activating Save while prose is revealing completes only the current line,
  does not advance, then opens Backup at a stable semantic presentation state.
- Next traversal never flashes skipped captions, portraits, poses, or sounds.
  Previously witnessed traversed lines enter the current scene's History in
  canonical order before the destination is presented.
- The host shows no routine date, location, episode, tier, attitude, route,
  result, affection, or reward banner. Physical staging and dialogue carry the
  scene.
- Post-challenge completion never displays a stat delta, outcome grade, reward
  report, or relationship summary. Domain consequences commit first; the exact
  frozen post-scene then resumes.

## 2. Authority and precedence

### 2.1 Authority spine

This exact accepted artifact controls intended behavior inside its ten
frontmatter scope topics over conflicting recovered documents,
prompt packets, proposed or hash-bound plans, tests, and current scene
scaffolds.

It narrowly amends the accepted 2026-08-07 Seven-Day Flow and Dialogic
Structure design. That design retains authority for:

- the seven-day calendar, invitation, attendance, Hospital, and day-resolution
  mechanics;
- solo relationship state, challenge results, outcomes, effects, promotion,
  and attempt permanence;
- the Priscilla-Lavinia group, missed, private-visible, private-offscreen,
  counted-window, stable-deck, and observation laws;
- the thirteen ending identities and ordered ending plan;
- semantic entry IDs, eight master timelines, frozen presentation context,
  stable line and presentation-atom IDs, token-bound playback, acknowledged
  signals, idempotent receipts, and exact recovery;
- profile witnessed-line and evidence boundaries; and
- production challenge and Rehearsal mechanics.

This amendment closes how the audience sees and controls the scoped narrative
routes. It does not let the scene host choose an outcome, mutate a relationship,
interpret a Dialogic path, advance a day, select a route, or fabricate a
completion receipt.

The accepted 2026-08-11 Desktop, Minesweeper, Shop, and Schedule amendment
retains authority for exact Minesweeper board lifecycle, capability behavior,
active-board persistence, bounded commands, cross-app departure, and truthful
technical recovery. This amendment owns only the narrative challenge host,
entry transition, surrounding staged pressure layer, and narrative-to-board
focus handoff.

The accepted 2026-08-12 Main Menu, Desktop Shell, and Global Chrome amendment
owns the 1280-by-720 logical canvas, aspect-preserving matte, global blocking
layers, safe focus behavior, quick status, and direct Day-1 desktop start. This
amendment consumes its canvas and never resurrects the retired Opening or
tutorial.

The accepted Settings amendment owns Primary and Secondary language, Dual
Language, text reveal speed, Auto delay, Skip mode, Read Aloud, TTS, text-size
presets, target sizes, Reduced Motion, palette, contrast, colour vision,
quiet suspension, controls, and reset behavior. This amendment defines their
narrative projection but does not duplicate their stored values.

The accepted Backup amendment owns the nine records, Save and Load surfaces,
confirmation, transaction, fallback, metadata, exact restore, shortcuts,
failure, and focus-return laws. This amendment requests modes and supplies a
stable narrative save boundary; it never performs storage or restore itself.

The accepted Gallery and Rehearsal amendment owns archive eligibility, exact
witnessed-version replay, Full Date sandbox isolation, visited-line-only merge,
archive exit, and the prohibition on archive-session saves. This amendment
supplies the reusable visual host and control capabilities without granting
Save or Load to consequence-free archive playback.

The Core Story Bible and later accepted canon amendments retain authority for
character truth, sparse source-authored anchor-bound perception, the
prohibitions on narrator identity, unrestricted thought boxes, and
player-authored Angela, consent and epistemic boundaries, exact authored events,
and restrained layered-2D direction. Final dialogue, locations, expressions,
objects, poses, CGs, and sound cues remain authored content rather than UI
invention.

Authority resolves by declared scope, not document date. If an observable rule
cannot be assigned unambiguously to one owner, implementation remains blocked
until the owner is reconciled explicitly.

Beads owns mutable work status, dependencies, and implementation evidence.
Approval of this design does not authorize Beads, plan, schema, manifest,
content, scene, test, or runtime mutation.

### 2.2 Current physical and execution state

At the time of writing:

- runtime implementation is not authorized;
- `DatingScene` contains empty character zones and a run-local transcript
  scaffold rather than the approved three-band host;
- `HospitalScene` is a label-and-button scaffold that directly starts a legacy
  timeline and directly mutates or routes on Continue;
- `DialogueBox` is disconnected, exposes an always-visible speaker label, and
  has no complete consumer for its Advance, Auto, or Log signals;
- `MinesweeperChallengeOverlay` is a debug result picker with retired result
  language rather than a production board;
- the project retains dozens of path-based placeholder timelines instead of the
  accepted eight semantic masters;
- current timeline manifest records contain no production line or event
  inventory sufficient for exact semantic resume;
- current playback adapters mix legacy direct starts with the newer token-bound
  boundary;
- current day resolution does not issue the final physical Dating and Hospital
  route commands;
- no portrait register, third-person scene composition, caption stack, full
  History sheet, six-control rail, trusted narrative Backup host, or challenge
  pressure layer exists physically;
- accessibility scaling is metadata-only and ordinary targets still drift from
  the accepted 48-pixel law;
- current tests primarily prove scene loadability or fake adapter behavior,
  with no integrated phase, focus, transport, challenge, or exact-restore
  matrix;
- `dwm-p2r.14` owns only token-bound Hospital and Dating presentation adapters,
  not this final visual composition;
- `dwm-oyo.4` remains the future canonical relationship, dating, pair-board,
  and visible-presentation integration owner;
- `dwm-oyo.5` consumes the host for Rehearsal isolation; and
- a separate successor authority-reconciliation gate is required before any
  current Bead or hash-bound plan may consume this amendment.

The current scaffold is evidence of drift, not a constraint to preserve.

## 3. Scope boundary

### 3.1 In scope

This amendment decides:

- the project-wide rule that every authored spoken character is physically
  present and visibly staged in the owning shot, including later ending hosts;
- one shared narrative host for canonical solo dates, visible
  Priscilla-Lavinia scenes, and Hospital;
- full-canvas three-band composition and supported text-size behavior;
- physical-presence and portrait-register law;
- third-person environment, character, action, object, and CG staging grammar;
- caption stack, inline choices, History, normal Accept, Auto, Skip, Next, Save,
  and Load presentation;
- exact `Next` traversal and boundary behavior;
- quiet pause, Settings, Backup, Save & Return to Title, and focus precedence;
- narrative-to-Minesweeper entry, pressure-layer composition, challenge input,
  terminal return, and exact restore;
- Hospital's boardless reuse of the same host;
- host/session/component ownership and typed semantic ports;
- localization, TTS, accessibility, motion, audio-equivalence, failure, and
  recovery presentation; and
- supersession, reconciliation, and verification requirements.

### 3.2 Out of scope

This amendment does not decide:

- final dialogue prose or translation;
- final backgrounds, character illustrations, portrait assets, expressions,
  poses, CGs, animation, music, ambience, or sound production;
- new dates, invitations, Hospital causes, relationship effects, outcomes,
  promotion valves, pair windows, endings, or Observer mechanics;
- Minesweeper grid dimensions, mine counts, cell styling, board input details,
  capability mechanics, or balance;
- the Day-7 ending host, credits, or ending-specific composition beyond the
  retained project-wide no-offscreen-speaker rule;
- Contacts, Shop, Schedule, Backup, Settings, Gallery, or Rehearsal internal
  design beyond the semantic ports consumed here;
- free-text dialogue, rewind, rollback of accepted choices, or a player-authored
  Angela;
- recorded character voice acting;
- mobile portrait layout or a second responsive topology;
- implementation plans, Beads mutation, asset production, or runtime work; or
- compatibility promises for unshipped placeholder narrative checkpoints.

## 4. Chosen design and rejected alternatives

### 4.1 Chosen: witnessed three-band proscenium

The scene is a restrained third-person proscenium with a portrait register
above it and a protected reading deck below it. Portraits improve turn-taking
in multi-person scenes, while the middle tableau remains the source of physical
truth: who is present, where each person stands, what Angela does, what another
person permits, and which object moves.

The host remains one coherent place when the challenge begins. Minesweeper
appears as a foreground pressure layer while the exact pre-board environment
and characters remain frozen and dimly perceptible. The board is real and fully
interactive; the surrounding scene is not a result picker or decorative fake.

### 4.2 Rejected: audience-adjacent Angela

A camera that implies the audience occupies Angela's edge or body is rejected.
It weakens Angela's independent identity and encourages the audience to treat
her choices as self-insertion. The chosen camera witnesses Angela instead.

### 4.3 Rejected: first-person Angela framing

First-person hands, Angela-view reflections, player shadows, and other framing
that asks the audience to occupy Angela are rejected in every scoped atom, not
merely as the default camera. Authored close-ins remain third-person views of a
body, hand, object, or reflection situated in the witnessed scene.

### 4.4 Rejected: portrait-only conversation

Portraits alone cannot establish physical movement, distance, interruption,
objects, or consent. The middle environment and a staged body or registered
visible partial-body composition remain mandatory whenever dialogue or
executable action occurs.

### 4.5 Rejected: speaker-driven portrait or body shuffling

Reordering the rail or moving bodies whenever a speaker changes turns scene
grammar into a call list. Authored physical positions remain stable until a
registered staging atom changes them.

### 4.6 Rejected: dedicated challenge scene replacement

Replacing the narrative host with an unrelated full-screen board loses the
pressure of the room and risks breaking exact scene continuity. The board owns
foreground input but remains inside the same semantic session.

### 4.7 Rejected: floating captions and hidden controls

Floating captions can cover hands, objects, faces, and choice evidence. Hidden
or hover-only controls fail input parity and stable muscle memory. The reading
deck and control rail remain protected and labelled.

### 4.8 Rejected: miniature narrative save slots

A bespoke save popover would duplicate transaction, confirmation, fallback,
and recovery law. Narrative Save and Load invoke the trusted Backup component.

### 4.9 Rejected: offscreen spoken dialogue

No scoped scene may use a voice without a physically present, visibly staged
speaker. The host therefore has no offscreen-speaker presentation, fallback,
or migration branch.

## 5. Vocabulary and ownership-facing state

### 5.1 Narrative session

A **narrative session** is one token-bound presentation of a registered semantic
entry sequence under one immutable frozen context. It may contain pre-dialogue,
a challenge, post-dialogue, and completion.

### 5.2 Authored shot

An **authored shot** is a validated presentation record containing background,
physical participants, participant positions, portrait layout, body/pose
variants, optional object/CG atoms, and motion policy. Runtime never infers shot
membership from the current line's speaker ID.

### 5.3 Physically present participant

A **physically present participant** is declared present and visible by the
current shot record and has a staged body or registered visible partial-body
composition in the middle tableau. Scene membership without current visibility
is not enough.

Every scoped spoken line requires its speaker to be a physically present
participant. An unused stage or portrait position stays empty.

### 5.4 Portrait register

The **portrait register** is the top noninteractive projection of current
physically present participants. It is scene presentation, not a dossier,
Contact record, evidence item, or game state.

### 5.5 Tableau

The **tableau** is the middle layered-2D environment containing physical
background, bodies, poses, movement, objects, partial-body close-ins, and rare
CG atoms.

### 5.6 Caption deck

The **caption deck** is the lower protected reading region. It owns caption
cards, inline choices, scroll containment where required, and the control rail.

### 5.7 Presentation beat and exact variant

A **presentation beat** is one stable line or non-dialogue presentation atom.
Its **exact variant** is determined by semantic identity plus every frozen field
declared capable of changing its text, action, staging, or disclosed context.

### 5.8 Normal Accept

**Normal Accept** is the ordinary reveal-or-advance command produced by click,
tap, keyboard Accept, controller Accept, or assistive activation on the current
caption target.

### 5.9 Transport commands

- **Auto** advances fully revealed material after its accepted delay and TTS
  rules.
- **Skip** visibly fast-forwards under the selected Read Only or All Text policy.
- **Next** performs one deterministic seek through safe already-witnessed
  material.

They are distinct commands and never share an ambiguous boolean state.

### 5.10 Registered boundary kinds

Narrative traversal recognizes a closed boundary vocabulary including:

- `ORDINARY_BEAT`;
- `UNRESOLVED_CHOICE`;
- `ACKNOWLEDGED_MARKER`;
- `EFFECT_TRANSACTION`;
- `UNRELATED_ROUTE_TRANSITION`;
- `MINESWEEPER_ENTRY`;
- `NARRATIVE_COMPLETION`; and
- `TECHNICAL_FAILURE`.

`MINESWEEPER_ENTRY` and `NARRATIVE_COMPLETION` are explicit boundary kinds, not
labels inferred from nearby content.

### 5.11 Canonical phases

The canonical session phase vocabulary is:

`PREPARING -> PRE_DIALOGUE -> AT_MINESWEEPER_ENTRY -> ENTERING_CHALLENGE -> CHALLENGE_ACTIVE -> COMMITTING_RESULT -> POST_DIALOGUE -> COMMITTING_COMPLETION -> COMPLETE`

Boardless Hospital omits the three challenge phases. A visible pair scene uses
the challenge phases only when its accepted semantic form owns a board.

History-open, pause-open, Backup-open, Settings-open, and quiet suspension are
orthogonal presentation modes. They never replace canonical phase truth.

## 6. Full-canvas composition

### 6.1 Logical canvas

The narrative host uses the accepted 1280-by-720 logical canvas. The shell's
aspect-preserving physical scale and inert themed matte apply unchanged.
Nothing may render, focus, announce, scroll, or accept input in the matte.

### 6.2 Baseline bands at 100%

At 100% text, the baseline band boundaries are:

| Band | Logical rect | Height |
|---|---|---:|
| Portrait register | `(0, 0, 1280, 104)` | 104 |
| Tableau | `(0, 104, 1280, 344)` | 344 |
| Caption deck and controls | `(0, 448, 1280, 272)` | 272 |

The three regions cover the canvas exactly without overlap or gap.

The control rail occupies the bottom 64 logical pixels of the reading deck.
The remaining deck height belongs to captions and inline choices.

### 6.3 Text-size expansion

The portrait register remains 104 logical pixels at all three supported text
presets because it contains no routine visible text.

At 125% and 150%, the caption deck computes its required intrinsic height after
localization and layout settlement. It expands upward from 272 logical pixels
to at most 392 logical pixels. The tableau yields the same amount and uses its
authored focal crop or reframe. The tableau therefore retains at least 224
logical pixels.

If complete functional text still exceeds the 392-pixel deck, the caption area
uses local vertical scrolling with the current card kept visible. The control
rail remains pinned. Text never shrinks below the selected preset, clips,
ellipsizes, overlaps, or requires horizontal scrolling.

### 6.4 Layout templates, not runtime wrapping

Each shot references a validated portrait-layout ID and tableau-blocking ID.
Those closed layouts place the exact current participant set without generic
runtime wrapping, horizontal portrait scrolling, speaker-driven reorder, or
empty placeholder cards.

A shot whose declared participants do not fit its registered layout fails
manifest validation. Runtime never invents a fifth position, compresses faces,
or silently drops a participant.

### 6.5 Layer order inside the host

The ordinary layer order is:

1. background and environmental depth;
2. character bodies and registered objects;
3. presentation atoms and restrained effects;
4. portrait register;
5. caption deck and inline choices;
6. challenge pressure layer when active;
7. History, pause, confirmation, Backup, or Settings modal owner; and
8. trusted technical recovery.

No visual effect may cover essential caption text, choices, focus rings, or
trusted recovery.

## 7. Portrait register

### 7.1 Membership and order

The register contains exactly the participants physically present in the
current shot, in the same authored left-to-right order as their tableau
positions.

Angela receives a portrait whenever she is physically present. A private
Priscilla-Lavinia scene without Angela contains no Angela portrait or reserved
Angela gap.

A participant exit removes body and portrait at one registered presentation
atom. Entry adds both at one registered presentation atom. Load reconstructs
the exact shot rather than replaying the transition.

### 7.2 No offscreen branch

Scoped spoken entries cannot declare an absent speaker. The manifest rejects:

- a line speaker absent from current shot participants;
- a remote, phone, doorway, corridor, recorded, hidden, or voice-only speaker;
- a retained portrait after physical exit;
- a portrait, thumbnail, silhouette, nameplate icon, or caption likeness for an
  absent speaker; and
- a staging record that relies on an offscreen voice to explain an action.

Contacts correspondence and nonverbal environmental sound remain outside this
spoken-scene constraint.

### 7.3 Active speaker cue

For a spoken line, the matching present portrait receives:

- a double-frame, raised-tab, or equivalent shape change;
- restrained brightness or contrast emphasis; and
- the exact registered expression variant when one exists.

Every other portrait remains readable. They are never blacked out, blurred,
desaturated beyond recognition, or removed merely because they are silent.

For a nonverbal action, silence, or environmental beat, no portrait is active
unless the atom explicitly owns one present character's visible action.

### 7.4 Names and semantic identity

The visual frame has no routine printed name, role, date, serial number,
relationship label, or institutional dossier field. Identity comes from the
portrait, body, authored staging, and dialogue.

Assistive semantics expose the same disclosed character identity and speaking
state, for example `Priscilla, speaking`, without adding hidden relationship or
mechanical information.

### 7.5 Expression and motion

Portrait expressions change only at registered semantic presentation atoms.
There is no automatic lip sync, perpetual blink loop, random idle motion, or
amplitude-driven bounce.

Reduced Motion converts every portrait and frame transition to an immediate
static swap. Expression selection never uses gameplay RNG.

### 7.6 Asset failure

A missing optional expression may use its manifest-declared base portrait
fallback. A missing required base portrait, participant mapping, or layout is a
trusted technical failure; the host cannot replace it with an anonymous
silhouette that changes character truth.

## 8. Third-person tableau and staging

### 8.1 Camera grammar

The default composition is a stable third-person wide tableau. Angela and every
other physically present participant are visible as independent characters.
The audience watches; it does not occupy Angela's eyes, body, choices, or
position.

The camera never uses a first-person cursor, player shadow, camera-breathing,
or addressed-to-camera blocking to imply that Angela is the audience.

### 8.2 Stable authored positions

Character positions are authored facts. Speaker changes do not move bodies.
Movement occurs only through registered atoms with stable start and resulting
shot identities.

Depth, overlap, and pose must preserve the legibility of hands, objects, and
consent-bearing movement. Decorative framing cannot hide a required action.

### 8.3 Close-ins, objects, and CGs

An authored object, hand, partial-body close-in, or sparse CG may temporarily
replace or overlay the middle tableau when its registered atom requires more
detail. Every such view remains third-person and never places the audience in
Angela's body. It never replaces the portrait register or caption deck.

A replacement atom may contain speech only when the speaking participant's
staged body or registered visible partial body remains in the middle
composition. An object-only or bodyless replacement is non-spoken.

Each such atom owns stable semantic identity, exact start and end shot, motion
policy, accessible factual description where required, and restore behavior.
It is not a narrator card, collectible notification, or hidden evidence grant.

### 8.4 Environment and interaction

The tableau is not a point-and-click scene. Backgrounds, bodies, and objects do
not take focus, reveal tooltips, or accept exploratory clicks unless a later
scoped interaction design explicitly authorizes one.

Pointer click or tap on the current caption target performs Normal Accept.
Clicking stage art does nothing and cannot accidentally advance text.

### 8.5 Transitions

Ordinary shot and pose transitions are restrained static swaps or short
crossfades. The challenge pressure layer uses a short matte-plane transition of
approximately 200 milliseconds. Reduced Motion makes every transition
immediate while preserving the same semantic order.

No glitch, false crash, camera seizure, or technical-error styling is used to
signal an ordinary narrative or challenge transition.

## 9. Caption deck and dialogue presentation

### 9.1 Mandatory captions

Captions are always present for spoken dialogue and every essential sound or
action that requires a textual equivalent. They cannot be hidden through a
preference.

There is no routine visible speaker-name label. The active portrait, physical
body, and authored staging disclose the speaker. Assistive output includes the
disclosed speaker identity.

### 9.2 Single-language presentation

In single-language mode, the deck shows the current semantic beat plus the
previous two available beats as full-text receding cards. Text size is the same
selected preset across all three; receding means material hierarchy, spacing,
and depth, not smaller or lower-contrast text.

### 9.3 Dual-language presentation

In Dual Language mode, the deck shows only the current semantic card. Primary
appears first and Secondary second inside that one card. The two language rows
share one semantic beat, receipt, history entry, and advance boundary.

### 9.4 Reveal

Text reveal follows the selected Instant, Fast, Normal, or Slow preset. A line
is semantically presented when the accepted Dialogic contract says its stable
line/presentation atom enters the visible presentation stream; glyph animation
does not create another gameplay receipt.

Normal Accept while reveal is incomplete completes the current line and
consumes that one input. It does not also advance. Held or repeated input must
be release-gated before another semantic command is admitted.

### 9.5 Inline choices

Choices appear in the caption deck directly beneath their source beat. They do
not float over bodies or the environment.

When choices are active:

- Normal Accept does not select a default choice;
- Skip, Auto, and Next stop and become inert;
- History, Save, and Load remain available when the canonical run is at a
  stable save boundary;
- each choice is at least 48 by 48 logical pixels, or 64 by 64 with Large
  Targets;
- wrapped choices scroll locally and focused choice remains visible;
- the first choice is not automatically focused by pointer arrival; and
- one deliberate choice command binds semantic choice ID, session ID,
  playback token, expected revision, and command ID.

The coordinator commits or replays the exact idempotent result before any
consequence-dependent prose is presented.

## 10. Canonical control rail

### 10.1 Exact controls and order

Canonical Dating and Hospital presentation uses one labelled control rail in
this exact order:

`History | Skip | Auto | Save | Load | Next`

The rail is 64 logical pixels high at all supported settings, so both ordinary
and Large Targets fit without moving the scene topology.

There is no `Advance` control. Normal caption activation owns ordinary advance;
`Next` owns the stronger seek command.

### 10.2 Initial and sequential focus

On ordinary dialogue entry, meaningful focus begins on the current caption
target. Tab enters the control rail in its visual order. Shift-Tab reverses it.
Explicit spatial neighbors prevent Godot from jumping into portrait or stage
art.

Hover never steals canonical focus. Selection, speaking, current caption,
focused control, active transport, unavailable control, and disabled control
remain distinct with non-colour cues.

### 10.3 Contextual capability

Canonical run scenes expose all six controls. A control whose command is
temporarily inadmissible remains visibly disabled only when its presence is
operationally useful; it is never allowed to fail silently after activation.

Gallery replay and Rehearsal reuse the visual host under their own accepted
capability law. Because archive playback owns no run save, Save and Load are
absent there rather than becoming fake records. The remaining controls retain
their order and the archive supplies its own Return action.

### 10.4 `Next` help text

The visible label remains the short localized equivalent of `Next`.
Focus, hover, and assistive description expose its exact meaning:

`Skip witnessed content to the next unseen beat or challenge.`

This is operational help, not a tutorial scene, narrator line, or persistent
instruction card.

## 11. Normal Accept, Auto, and Skip

### 11.1 Normal Accept

Keyboard Enter or Space, controller Accept, short tap, pointer activation on the
current caption target, and assistive activation normalize to one
`NORMAL_ACCEPT` command.

If reveal is incomplete, the command completes reveal only. If reveal is
complete and no choice or acknowledged boundary owns input, it advances one
semantic beat. One event can never perform both operations.

### 11.2 Auto preference and active timer

The rail's Auto control projects and immediately mutates the profile-owned
Settings `Auto Dialogue` preference. It is not a run-save fact and explicit
Load never rewinds it.

When that preference is On and the current beat is eligible, the host owns one
revision-bound active Auto timer. It waits for complete reveal, the accepted
Auto delay, and active Read Aloud completion when applicable. The timer pauses
or invalidates before:

- every choice;
- every acknowledged marker or effect transaction;
- `MINESWEEPER_ENTRY`;
- technical recovery;
- a modal or pause owner; and
- quiet suspension.

Auto never enters Minesweeper, selects a choice, or completes a route by itself.
An ineligible boundary suspends active Auto without inventing another stored
preference; the next eligible authoritative beat may arm a fresh full delay
only after that boundary is deliberately resolved.

### 11.3 Skip

Skip is a visible On/Off fast-forward mode, not a hold-only command. A second
Skip activation or Normal Accept stops it.

In Read Only mode, Skip stops automatically at the first exact unseen variant.
In All Text mode, it may visibly fast-forward unseen ordinary prose under the
accepted presentation-receipt law. Both modes stop at choices, acknowledged
effects, challenge entry, completion ownership, modal ownership, and technical
failure.

Skip never silently selects or auto-enters a Minesweeper challenge.

### 11.4 Arbitration

Only one transport may be active:

- enabling Auto stops Skip;
- enabling Skip first commits the profile Auto preference Off, then starts
  Skip;
- activating Next first commits the profile Auto preference Off and stops
  Skip, then admits the one-shot seek;
- Normal Accept stops Skip before applying its own one-step meaning; and
- every transport stops current TTS before taking control.

If the required Auto-preference change cannot commit, Skip or Next does not
start and the prior transport state remains truthful. No cross-owner partial
state is published.

Normal Accept atomically invalidates the pending Auto timer generation before
revealing or advancing. If the profile Auto preference remains On, the
resulting eligible authoritative beat arms a new full delay. The old timer can
never fire after the manual command.

The Auto preference remains profile state; its pending timer, Skip-active flag,
and Next operation are presentation/session state. None can change the frozen
narrative context, relationship outcome, board, or route plan.

## 12. `Next` deterministic seek

### 12.1 Purpose

Next lets an audience who has already witnessed material move directly toward
something exact and new, or toward the scene's challenge, without turning the
game into a result selector.

It is a deliberate one-shot command, never an always-running mode.

### 12.2 Exact witnessed predicate

A beat is safe for Next traversal only when the profile's validated witnessed
ledger contains the exact stable presentation identity and signature required
by the frozen current route.

Base line ID alone is insufficient. A change in any declared text, action,
speaker, shot, expression, tier, tone, attitude, echo, result, pair variation,
attempt residue, or other signature field makes the beat unseen.

An erased, absent, never-presented, unsupported, or merely generated beat is not
witnessed.

### 12.3 Current partial beat

If the current line is still revealing and its exact variant was not witnessed
before this presentation, Next completes that line and stops. It does not seek
past the newly encountered material.

If the current partial line's exact variant was already witnessed, Next may
complete it internally and continue the same seek.

### 12.4 Traversal table

| Encountered item | Next behavior |
|---|---|
| Exact witnessed ordinary beat | Traverse without flashing; append it to current scene History in order |
| Exact unseen beat | Materialize it normally, focus its caption, reveal it, and stop |
| Unresolved choice | Stop before it and present the normal choice surface |
| Acknowledged marker | Stop before its command boundary |
| Effect transaction | Stop before its command boundary |
| Unrelated route transition | Stop before its command boundary |
| `MINESWEEPER_ENTRY` | Admit the atomic challenge entry immediately; no extra Accept |
| `NARRATIVE_COMPLETION` with all remaining material witnessed and no unresolved boundary | Admit exact completion immediately |
| Technical failure | Stop and enter trusted recovery with no guessed continuation |

### 12.5 Exclusive traversal transaction

An admitted Next command owns one exclusive bounded traversal transaction.
Normal Accept, Auto, Skip, choices, Save, Load, Back, and modal opening cannot
observe or act on an intermediate traversal frontier. They become legal only
after the exact destination, completion, or rollback state is durable and
published.

Repeated Next activations coalesce only when their complete command bytes are
identical; changed or stale activations reject. No UI input is queued behind
the transaction for surprise execution.

### 12.6 No rapid visual playback

During traversal, the host holds the last safe composition under a restrained
matte. It does not cycle through captions, active portraits, poses, expressions,
CGs, sounds, or TTS.

The coordinator processes required safe idempotent presentation and route
receipts in canonical order. Only after the destination or completion result is
durable does the host publish the new stable composition.

### 12.7 History and witnessed state

Traversed beats were already exactly witnessed at least once. They are appended
to the current scene's History in canonical order so the audience can inspect
what Next crossed.

Next never marks an exact unseen beat witnessed without actually presenting it.
It never grants Observer evidence, Gallery discovery, pair-combination witness,
or another capability merely because the traversal considered an item.

### 12.8 Scene completion

If the current segment has no remaining challenge, exact unseen beat,
unresolved choice, acknowledged marker, or uncommitted effect before its
registered terminal boundary, Next may submit the same `NARRATIVE_COMPLETE`
command ordinary playback would eventually submit. This applies both to a
boardless scene and to a post-challenge segment after its board and consequences
are already durably complete.

That command remains token-bound and idempotent. It may route only after the
coordinator proves physical completion and commits or replays the exact receipt.
Next cannot synthesize a different destination or skip a required downstream
visible scene.

## 13. Minesweeper challenge pressure layer

### 13.1 Dedicated entry boundary

Every challenge-bearing route owns one stable `MINESWEEPER_ENTRY` boundary ID.
The boundary is distinct from adjacent dialogue, effect, promotion, route, and
completion records.

It may not bundle an unresolved choice, effect mutation, evidence action,
promotion, unrelated route transition, or post-challenge consequence. Manifest
validation rejects such a bundle.

Ordinary playback reaches the boundary through its accepted causal path. A
Normal Accept at a fully presented threshold or a Next seek that reaches the
threshold may submit the same challenge-entry command. Auto and Skip stop there.

### 13.2 Atomic entry from Normal Accept or Next

At a fully presented registered `MINESWEEPER_ENTRY`, boundary dispatch takes
priority over ordinary beat advance. Normal Accept and Next submit the same
entry protocol with their source command kind recorded; neither can treat the
boundary as an `ORDINARY_BEAT`.

When either command admits entry:

1. Normal Accept, Next, Auto, Skip, and narrative input become inert.
2. The triggering event is consumed and held input is release-gated.
3. The host submits one challenge-entry command containing session ID,
   playback token, boundary ID, expected revision, command ID, and frozen
   challenge locator.
4. The coordinator validates the exact boundary and builds or restores the
   challenge through the authoritative board owner.
5. The board view proves the active target-size mode and pointer, touch,
   keyboard, controller, and assistive-input conformance required by this host.
6. The entry receipt and exact board snapshot become durable atomically under
   the governing transaction.
7. Only then does the session publish `CHALLENGE_ACTIVE` and transfer focus to
   the board's canonical first playable cell.

When Next is the source, no separate Accept prompt, Start button, confirmation,
or tutorial appears.
Repeated, stale, held, queued, or conflicting inputs cannot create another
board or activate the first cell.

If the board view cannot prove its 48/64 target mode and complete input/access
contract, challenge entry fails closed at `AT_MINESWEEPER_ENTRY`. A later board
UI authority may define its geometry but cannot waive this host-admission gate.

### 13.3 Visual takeover

Challenge entry uses the approved short matte-plane transition. The exact
pre-challenge shot freezes. Portraits return to neutral frames, the tableau
dims, and its bodies and environment remain perceptible around or behind the
foreground board plane.

The caption stack, inline choices, and six-control rail withdraw. The board
receives the maximum safe foreground area while preserving enough surrounding
scene to retain continuity. Exact board geometry, cell dimensions, and board
controls belong to the Minesweeper UI authority, not this amendment.

The dim scene accepts no input, focus, hover, tooltip, TTS, live announcement,
or presentation mutation while the board is active.

### 13.4 Challenge input

Only canonical board commands act during `CHALLENGE_ACTIVE`. Narrative Normal
Accept, Auto, Skip, Next, and caption pointer areas are absent from the focus
and input trees.

Back opens the board's quiet pause surface; it never cancels or forfeits the
board implicitly. The pause surface provides the previously approved Continue,
Backup, Settings, and Save & Return to Title actions under their existing laws.

F5 and F9 retain the accepted Backup shortcut behavior when the board owner
reports a stable save/replace boundary. No shortcut bypasses a blocking modal,
transaction, restore, or recovery owner.

### 13.5 Board truth and consequences

The pressure layer presents a real production board. It never offers buttons
for Perfect, Solved, Exploded, relationship outcomes, affection changes,
promotion, special-mine selection, or debug completion.

The authoritative engine and coordinator own board result, exact reasons,
relationship outcome, effect application, promotion, pair observation, and
receipts. The host receives only a board view and later the validated frozen
post-scene context.

For Priscilla-Lavinia boards, the accepted observation-only result vocabulary
and no-solo-payout law remain intact. The host cannot display or infer a solo
relationship effect.

### 13.6 Terminal return

When the board reaches a stable terminal condition:

1. board input locks;
2. the board owner commits or replays the exact result receipt;
3. relationship effect, promotion, pair observation, or other authorized
   consequences complete in their accepted order;
4. the coordinator freezes and validates the exact post-challenge presentation
   context;
5. the board pressure layer withdraws through the restrained transition; and
6. the host reconstructs the registered post-challenge shot and caption deck.

There is no result card, stat delta, reward toast, grade, or relationship
summary between board and post-dialogue.

### 13.7 Entry failure and recovery

The challenge entry states are
`AT_MINESWEEPER_ENTRY -> ENTERING_CHALLENGE -> CHALLENGE_ACTIVE`.

If preparation fails before durable entry, recovery returns to the intact
`AT_MINESWEEPER_ENTRY` state and no board exists. If entry is durable, recovery
reconstructs the exact board and enters `CHALLENGE_ACTIVE`. No saved or visible
intermediate state exists.

A stale or duplicate entry command replays its identical receipt or rejects
without mutation. A changed command under the same ID is a conflict and enters
trusted recovery.

## 14. Hospital preset

### 14.1 Same host, distinct semantic route

Hospital uses the same three-band host, portrait rules, tableau, captions,
controls, History, pause, Backup, Settings, accessibility, and recovery grammar
as Dating. It retains its own semantic route and frozen context.

It does not instantiate a smaller dialogue system or a Hospital-specific
Continue button.

### 14.2 Treatment-room staging

Hospital selects an authored treatment-room shot family. Angela and every
speaking participant are physically present and visibly staged. Qualified
clinicians remain responsible for assessment and treatment; the UI never turns
their role into a relationship stat or Sylvia mechanic.

There are no offscreen clinical voices. A clinician who speaks must be present
in the shot and included in the portrait register.

### 14.3 Boardless flow

Hospital is boardless. Its phase sequence is:

`PREPARING -> PRE_DIALOGUE -> COMMITTING_COMPLETION -> COMPLETE`

It cannot show an empty board frame, locked challenge slot, challenge countdown,
or disabled Minesweeper control.

If all exact Hospital material is already witnessed and no acknowledged
boundary remains, Next may reach `NARRATIVE_COMPLETION` and submit the ordinary
token-bound Hospital completion command.

### 14.4 Mechanical boundary

The Hospital resolver, not the host, owns causes, invitation closures,
Hospital-specific missed reasons, Sylvia witness results, deferred visible pair
work, day advancement, and persistence.

The host presents the exact frozen context and returns one physical completion
receipt. It cannot advance the day or route to Dating directly.

Hospital completes before any resulting visible Missed or Private-visible
Priscilla-Lavinia scene. A later required scene starts as a fresh semantic
session under the same visual host.

## 15. History

### 15.1 Full-canvas sheet

History opens as a trusted full-canvas reading sheet above the paused narrative
host. It does not compress the three bands into a side ledger or move the live
caption deck.

It contains only stable lines and presentation atoms admitted to the current
scene's history stream, in canonical order. It may include lines safely
traversed by Next because those exact variants were already witnessed.

### 15.2 No rewind or mutation

History is inspect-only. It cannot:

- rewind Dialogic;
- undo or change a choice;
- change a shot, expression, board, result, relationship, or route;
- grant Observer evidence merely by inspection;
- replay an audio cue as if it were newly witnessed; or
- alter profile visited state.

Closing History restores the exact originating focus and presentation state.

### 15.3 Language and TTS

History reprojects stable semantic line IDs and the frozen exact variant under
current language settings. Dual Language follows the accepted Primary then
Secondary order. Read Aloud speaks Primary only through the compatible system
voice.

Opening, scrolling, or closing History never duplicates a live announcement or
current-line TTS utterance.

### 15.4 Accessibility and focus

History traps focus while open. Initial focus is its heading or current-history
anchor, not Close. Its scroll container exposes semantic line order; Back closes
the sheet and restores exact source focus.

No history line is presented as an editable field or activation target unless
an explicitly supported TTS action owns that control.

## 16. Save, Load, pause, and Settings

### 16.1 Save and Load controls

The persistent Save and Load controls invoke the accepted Backup component in
the corresponding mode over the paused narrative scene.

The component keeps its authoritative nine records, actions, confirmations,
fallbacks, technical states, frozen local save time, focus behavior, and
transactions. The narrative host supplies no slot list, no direct filesystem
access, and no custom save confirmation.

Cancel closes Backup and restores the exact originating Save or Load control.
A successful manual Save remains inside Backup on the selected record with
refreshed metadata and truthful `Saved`, exactly as the accepted Backup law
requires. The audience closes it deliberately to return to the originating
Save control. Successful Load atomically replaces the live branch and routes
to the selected save's canonical scene; it does not return focus to the
departed session.

### 16.2 Explicit Save during reveal

If the visible Save control or F5 Quick Save is deliberately activated while
the current line is revealing, the host completes that line's visual reveal
only. It does not advance, choose, acknowledge a marker, enter a board, or
create another presentation receipt.

For the visible control, Backup opens only after that stable visible line state
exists. F5 does **not** open Backup: it directly admits or coalesces the accepted
Quick Save transaction and uses the accepted edge `Saving…` / `Saved` feedback
without changing focus. Both snapshots store semantic current-line and
presentation state rather than glyph index. Restore shows the line fully
visible without replaying its TTS or live announcement.

### 16.3 Choices and stable boundaries

Save and Load may be opened while an unresolved choice is visible when the
coordinator reports a stable save boundary. The choice remains unselected.
Restore reconstructs the same exact choices from frozen context and committed
receipts.

An admitted choice, effect, challenge-entry, completion, save, load, or route
command finishes its bounded transaction or reaches its governing stable
frontier before another conflicting operation acts.

### 16.4 Quiet pause sheet

Back at narrative root opens a quiet pause sheet with:

1. Continue;
2. Backup;
3. Settings; and
4. Save & Return to Title.

Continue receives initial focus. Back closes the pause sheet and resumes the
exact scene. The sheet does not provide rewind, restart scene, skip result,
abandon date, or change-choice actions.

Save & Return to Title uses the accepted exact Autosave/logout transaction. A
failure remains in the paused scene with truthful Retry/Cancel recovery.

### 16.5 Settings

Settings opens the shared trusted Settings component. Immediate preference
changes reproject the same semantic beat, shot, control, and focus context.
They never count as a new line presentation or alter the frozen route context.

Leaving Settings follows its accepted capture, preview, sample, and focus-loss
cleanup. It returns to the exact Settings source in the pause sheet.

### 16.6 Shortcut parity

F5 targets Quick Save and F9 targets Quick Load under the accepted Backup law.
They do not click the visible Save or Load controls, change control focus, or
open a second Backup instance.

During an already-admitted bounded narrative or challenge command slice, F5
may admit exactly one coalesced Quick Save intent and wait for the next stable
frontier. Repeated F5 inputs coalesce. It never waits through confirmation,
restore, fatal recovery, route replacement, or an exclusive Next traversal.

F9 never queues a future Load. While a blocking modal, incompatible
transaction, or route replacement owns input, F9 is inert or returns the
accepted concise truthful wait status. No shortcut executes later by surprise.

## 17. Exact persistence and restore

### 17.1 Saved semantic facts

An exact canonical narrative snapshot contains only primitive validated facts
required to resume, including when applicable:

- narrative session ID and playback token lineage;
- semantic entry ID and immutable frozen context/signature;
- canonical phase and phase-specific boundary ID;
- current stable line or presentation-atom ID;
- admitted/presented atom and line receipts needed for idempotency;
- committed choice IDs and acknowledged marker/effect receipts;
- current shot ID and registered participant/body/portrait variants;
- scene-local History identity sequence;
- challenge entry receipt and exact authoritative board snapshot;
- committed result/effect/promotion/pair receipts;
- completion intent and receipt stage; and
- route/session operation revision and idempotency records.

It does not save Nodes, Controls, focus objects, resource instances, raw DTL
indices, file paths, label positions, glyph reveal position, tweens, audio
playhead objects, shader state, or live input events.

### 17.2 Presentation-only state

Hover, focus ring animation, scroll momentum, modal tween, transition opacity,
and held input are rebuilt. The current meaningful focus target, open canonical
choice state, and exact semantic host mode are reconstructed from validated
state under the governing focus law.

The profile-owned Auto preference is not part of a run save and retains its
current committed value across explicit Load. Any old pending Auto timer is
discarded; after reconstruction, an eligible beat may arm one new full delay
from the loaded authoritative revision. Skip resumes Off and Next has no
persistent active mode. A save made while History, pause, Backup, or Settings is
open restores the canonical scene boundary, not the transient modal.

### 17.3 Load reconstruction

Load validates and prepares the whole selected checkpoint before mutation. On
commit it reconstructs exactly one canonical phase:

- pre-dialogue at the exact stable beat;
- `AT_MINESWEEPER_ENTRY` before board creation;
- exact active board from its durable entry receipt and snapshot;
- `COMMITTING_RESULT` with the terminal locked board snapshot, result receipt
  stage, ordered consequence plan, and exact next uncommitted consequence;
- post-dialogue after committed result and consequences; or
- `COMMITTING_COMPLETION` with its frozen completion intent, receipt stage, and
  exact next uncommitted completion step.

Both committing phases restore with all audience input locked and resume from
the first uncommitted step. Already committed result, effect, promotion, pair,
completion, or route receipts replay identically and never execute twice.

It never regenerates a board, rerolls a pair deck, reselects an outcome,
replays an effect, or restarts the whole scene because a physical node was
missing.

### 17.4 Quick Save during challenge entry

The visible narrative Save control is already withdrawn and cannot be activated
during `ENTERING_CHALLENGE`. One F5 intent accepted by the Backup capability
gate may coalesce and wait only for that bounded entry transaction. The durable
Quick Save result is either:

- intact `AT_MINESWEEPER_ENTRY` with no board; or
- exact `CHALLENGE_ACTIVE` with entry receipt and board snapshot.

No snapshot or visible frame may encode a half-created board.

### 17.5 Crash and replay

Every narrative, choice, Next traversal, challenge-entry, result, effect,
promotion, and completion command is idempotent under semantic command identity
and expected revision.

Identical replay returns the prior receipt. Changed bytes under the same command
identity conflict. Recovery never guesses whether an operation committed from
what happens to be visible.

## 18. Gallery and Rehearsal consumption

### 18.1 Exact Scene replay

Gallery/Rehearsal Scene replay may use the same three-band host only for a
canonically reached exact presentation signature. It presents the exact
witnessed scene without choices or canonical consequences.

Save and Load are absent. Replay exit follows the archive's exact return-focus
law. Next may seek only inside that reached exact scene and cannot reveal an
unreached variant.

### 18.2 Full Date

Full Date uses the same pre-dialogue, challenge pressure layer, and hypothetical
post-dialogue presentation in its isolated sandbox. The board remains a fresh
production board, not an outcome selector.

The archive owner supplies the reached start seed and consumes only
manifest-validated visited-line identities on clean exit. No run, save, Gallery,
relationship, evidence, ending, attempt, or global RNG mutation may escape.

### 18.3 Host capability mode

The session view carries an explicit closed host capability mode such as
`canonical_run | gallery_replay | rehearsal_full_date`. The view, not scene
path or caller convention, determines which controls and commands are legal.

An unknown mode fails closed. The host never infers that title playback may
save because the same visual scene is used in a live run.

## 19. Input, focus, Back, and modal precedence

### 19.1 One input, one command

Every pointer, touch, keyboard, controller, and assistive activation normalizes
to one semantic command. The host consumes the triggering event before a newly
opened modal or board can receive input.

Held input must be released before another semantic activation. Double-click,
key repeat, controller repeat, or simultaneous devices cannot reveal and
advance, choose twice, enter two boards, or close a newly opened surface.

### 19.2 Back precedence

Back performs exactly one highest-priority legal action:

1. trusted technical recovery owns only its explicit controls;
2. active confirmation, Backup, Settings, or History closes or cancels under
   that surface's law;
3. an active preview or sample stops;
4. an already-open quiet pause sheet closes to Continue;
5. `CHALLENGE_ACTIVE` opens the board's quiet pause sheet; or
6. narrative root, including a visible unresolved choice, opens the quiet pause
   sheet while leaving that choice unchanged.

Back never rewinds prose, changes a choice, cancels an admitted board command,
or exits a canonical scene directly.

### 19.3 Focus restoration

Every modal records its semantic source control and expected session revision.
Safe dismissal restores that source if it still exists and is legal. Otherwise
the host chooses the nearest governing semantic target, preferring current
caption, current choice, or pause Continue in that order.

Node paths are not persistence or restoration identities.

### 19.4 Choice focus

Opening choices keeps current caption context visible. Keyboard/controller Tab
or directional navigation enters the first choice only after deliberate
movement. Choice focus never wraps silently into the portrait register, stage,
control rail, or another scene.

### 19.5 Challenge focus

`CHALLENGE_ACTIVE` transfers focus only after the exact board is durable and
visible. The board owner supplies the canonical first playable focus target.
The host does not guess a node path or activate a cell during transfer.

On terminal return, focus moves to the reconstructed post-dialogue caption or
its first exact choice. The old board focus tree is destroyed or disabled
before narrative input returns.

## 20. Localization, TTS, accessibility, motion, and audio

### 20.1 Localization

Every control, help description, caption, choice, technical status, History
heading, pause action, and accessible label uses registered localization keys.

The control order and semantics are stable across locales. A longer localized
label wraps inside its target; it never shrinks, clips, ellipsizes, or reorders
the rail.

### 20.2 Text presets

The host supports exactly 100%, 125%, and 150% in-game text presets for the
initial Windows release. A change applies immediately to current presentation
without advancing or duplicating a beat.

The band-growth law in section 6 preserves complete essential text. The design
makes no 200% or Windows system-text-scale acceptance claim.

### 20.3 Target sizes

Every interactive target is at least 48 by 48 logical pixels. Large Targets
makes it at least 64 by 64. The 64-pixel control rail supports both without
changing macro topology.

Portraits, character bodies, backgrounds, and ordinary caption text are not
fake interactive targets.

### 20.4 Assistive reading order

The semantic reading order is:

1. current physically present participants in authored left-to-right order;
2. current tableau description when one is required;
3. current caption card and any previous cards exposed by the active language
   mode;
4. current inline choices; and
5. control rail in visual order.

The speaking participant receives `speaking` state. Silent participants remain
named but are not announced again on every line. No absent character enters the
accessibility tree.

### 20.5 TTS

Read Aloud uses the compatible system voice and reads Primary only. It
announces the public disclosed speaker token only when the speaker changes,
then reads the Primary caption. It never repeats the same speaker on every line
or exposes an internal actor identity.

TTS stops when Normal Accept skips reveal, Auto/Skip/Next takes control, a
choice or modal opens, the challenge begins, focus is lost, or another trusted
speech owner takes priority. Restore and uncover never replay an utterance
automatically.

### 20.6 Motion and shake

Reduced Motion replaces portrait, pose, camera, matte, caption, and board
transitions with static swaps. Screen Shake never applies to caption cards,
portrait frames, choices, focus rings, or technical surfaces.

Flicker and strobe remain prohibited at every setting. Motion is never required
to identify the speaker, choice, challenge state, or result.

### 20.7 Colour and art

High Contrast and colour-vision presets remap functional tokens: focus,
speaking frame, selected choice, active transport, warning, unavailable, and
technical status. Character portraits, bodies, backgrounds, object art, and CGs
are not globally recoloured.

Every functional state also has a shape, line, text, pattern, or position cue.

### 20.8 Audio equivalence and focus loss

Essential sound has a visible textual or physical equivalent. Environmental
audio cannot introduce an offscreen speaking character.

On focus loss, quiet suspension stops TTS and samples, pauses Auto/Skip/Next
presentation, pauses user-facing timers, blocks input, and lets only an admitted
bounded transaction reach its stable frontier. Refocus resumes the exact stable
state without advancing prose or activating the board.

## 21. Visual and material direction

### 21.1 Maintained institutional theatre

The host combines maintained university paper, restrained photo-frame edges,
quiet ink, shallow stage depth, and faded but cared-for surfaces. It is neither
a modern mobile messenger nor a lavish theatre UI.

Portrait frames are presentation structure, not literal evidence photographs.
They contain no timestamps, case numbers, file tabs, relationship labels, or
false institutional metadata.

### 21.2 Character-first restraint

The strongest contrast belongs to current captions, choices, focus, and the
active speaker frame. Background texture and dreamlike residue remain below
text and body-language legibility.

The scene does not use constant parallax, idle bobbing, animated film grain,
typing indicators, emoji reactions, speech bubbles, or visual-novel nameplates.

### 21.3 Challenge pressure

Challenge pressure comes from the real board occupying the scene while the
room and participants remain frozen behind it. It does not come from fake
glitches, distorted portraits, false controls, sudden error copy, or fabricated
relationship warnings.

### 21.4 No mechanical leakage

The live host never displays:

- affection, tier, attitude, tone, dark points, Observer Pressure, evidence
  flags, promotion requirements, pair-deck state, hidden mine formulas, or
  ending gates;
- internal semantic IDs, route IDs, signature hashes, receipts, revisions, or
  debug result names; or
- unseen-content counts, progress bars, or a promise that Next will find a
  particular route.

## 22. Failure, rollback, and trusted recovery

### 22.1 Required content validation

Before publishing a session, the coordinator validates semantic entry,
frozen context, shot and participant records, portrait layout, required base
assets, stable line/atom IDs, allowed signals, challenge boundary, and
completion owner.

Failure before publication leaves the prior route intact and uses trusted
technical recovery. The host does not show a half-populated scene.

### 22.2 Ordinary optional fallback

Only manifest-declared optional presentation variants may fall back, such as an
optional expression resolving to the required base portrait. Fallback cannot
change speaker identity, physical presence, line meaning, action, choice,
challenge, or evidence.

### 22.3 Command failure

A rejected Normal Accept, choice, Auto, Skip, Next, challenge, Save, Load, or
completion command causes no partial canonical mutation. The UI refreshes from
the returned authoritative view and retains or restores meaningful focus.

Known unavailable actions use concise truthful status. Technical failures use
the trusted recovery plate with Retry or safe return behavior under the
accepted transaction law.

### 22.4 Next failure

Next operates against one frozen traversal plan and expected revision. If any
candidate beat, signature, boundary, receipt, or revision fails validation,
traversal stops before the failing boundary. It never skips ahead using a live
rescan or silently drops a beat.

If the traversal outcome is indeterminate after a crash, recovery consults the
durable operation record. It either reconstructs the exact committed
destination or the last safe pre-command state.

### 22.5 Challenge failure

A preparation failure returns to the intact challenge boundary. An active-board
failure preserves the exact board snapshot and follows Minesweeper recovery.
A post-result failure cannot replay the result or effect; it resumes the exact
committed stage.

### 22.6 Truth boundary

Narrative horror never impersonates a real content, asset, localization,
storage, transaction, or engine failure. Public recovery copy has no character
voice and exposes no raw stack, path, hash, or internal identifier.

## 23. Component and semantic-port ownership

### 23.1 Narrative session coordinator

One narrative session coordinator owns:

- entry and frozen-context validation;
- phase and revision;
- token-bound Dialogic playback;
- accepted command admission and idempotency;
- acknowledged markers and effect handoffs;
- challenge-entry coordination;
- result-to-post-context sequencing;
- canonical completion; and
- save/recovery participation.

It does not draw UI, calculate Minesweeper results, write save files, or invent
story content.

### 23.2 Narrative scene host

The host is a projection and input adapter. It receives an immutable
`NarrativeSessionView` and emits typed `NarrativeCommand` envelopes. It never
reads or mutates GameState, profile data, Schedule, relationship state,
filesystem storage, or raw Dialogic internals directly.

Conceptually, every command includes:

```text
session_id
playback_token
expected_revision
command_id
kind
payload
```

Every view includes only validated player-facing projection data plus semantic
focus and capability IDs. It contains no live mutable domain object.

### 23.3 Shot and presentation manifest owner

One closed narrative presentation manifest maps semantic shot, portrait layout,
participant, body/pose, expression, object/CG, caption, boundary, and accessible
description IDs to validated resources and schemas.

The manifest—not UI script conditionals—declares physical presence and exact
variant dependencies.

### 23.4 Dialogic adapter

The Dialogic adapter starts only a validated semantic entry/label under one
playback token and frozen context. It emits allowlisted semantic events and
accepts acknowledged results. It never calls GameState, SaveManager, or
SceneRouter directly.

### 23.5 Challenge owner

The authoritative Minesweeper coordinator owns board creation, spec, entropy,
capabilities, cells, commands, result, receipts, exact snapshot, and terminal
state. The narrative coordinator supplies an issuer-validated challenge request
and consumes the result through a typed handoff.

The challenge view receives a board snapshot and emits revisioned board
commands. It never receives affection deltas or an outcome selector.

### 23.6 Relationship and pair owner

The relationship/pair coordinator owns solo outcome, effects, promotions,
Sylvia Hospital witness application, pair result, observation, count, and
combination witness. The host receives only the resulting frozen presentation
context.

### 23.7 Backup and Settings owners

Backup remains the sole save-I/O, load, record, confirmation, fallback, and
restore owner. Settings remains the sole profile-preference and input-binding
owner. The host requests their trusted surfaces through semantic ports.

### 23.8 History owner

The narrative coordinator supplies one ordered scene-history projection from
stable semantic IDs and frozen variant context. Profile visited-line/evidence
owners remain distinct. Inspecting UI History cannot mutate either ledger.

### 23.9 Route and day owner

The route/day coordinator validates physical scene completion receipts and owns
Hospital-before-date, slot order, deferred pair presentation, day advancement,
Day 7 handoff, and route publication. Scene scripts never call SceneRouter to
declare themselves complete.

## 24. Exact supersession and retained law

### 24.1 Superseded or retired target behavior

Once accepted and reconciled, this amendment supersedes or retires the
following as intended target behavior:

- empty `DatingScene` character zones and transcript-only projection;
- Hospital's label/button scaffold, direct Dialogic start, direct day mutation,
  and direct route call;
- the disconnected `DialogueBox` and its routine visible speaker label;
- debug result and outcome buttons in `MinesweeperChallengeOverlay`;
- a separate board scene that discards narrative staging;
- direct scene inspection of GameState, relationship state, Schedule, route, or
  raw Dialogic path/label;
- one path-based timeline per fragment as the final runtime contract;
- event-index or node-path narrative checkpointing;
- presentation-owned completion without token-bound physical receipt;
- offscreen spoken characters or portrait fallbacks;
- audience-adjacent or first-person Angela framing;
- floating captions, hidden transport controls, and speaker-driven portrait
  shuffling;
- `Advance` as the visible name for the strong seek control;
- a narrative-specific save-slot popover;
- active-board lifetime save lock inherited from older scaffolds; and
- 44-pixel ordinary target behavior.

### 24.2 Explicitly retained

This amendment retains without redesign:

- all accepted date, Hospital, relationship, promotion, pair, Day-7, ending,
  and attempt mechanics;
- Hospital-before-date and required visible-pair ordering;
- exact semantic entry, frozen-context, signal, receipt, and recovery law;
- exact active-board persistence and anti-reroll behavior;
- P-L observation-only boards and private-offscreen no-presentation law;
- profile witnessed-line versus Observer-evidence separation;
- Gallery/Rehearsal isolation and archive save prohibition;
- Settings language, reading, audio, display, controls, accessibility, reset,
  and suspension law;
- Backup storage, confirmation, transaction, failure, and restore law;
- direct Day-1 desktop start and complete Opening/tutorial retirement;
- sparse source-authored anchor-bound perception, no narrator identity or
  unrestricted thought box, and no player-authored Angela; and
- final story canon and content-authoring ownership.

## 25. Reconciliation path before implementation

Written approval of this amendment requires a later, separately authorized
reconciliation before runtime work:

1. Register `design_amendment` and `docs/design` in the live authority resolver,
   index, validator, and `docs/design/README.md`; the current README still
   describes this directory as recovered-only and is stale.
2. Create a successor authority/reconciliation issue for this amendment and
   make it block the applicable OYO execution chain beginning with
   `dwm-oyo.1`. Registration alone grants no runtime authority.
3. Reconcile existing requirement packets with retained, replaced, or
   superseded dispositions. Add exact rules for narrative host boundaries,
   physical presence, controls, Next, challenge entry, persistence, and access;
   do not create parallel overlapping requirements.
4. Reconcile the proposed/hash-bound August roadmap and Plans 01 through 06
   through successor artifacts. Do not silently edit accepted hashes or claim
   that proposed plans were already accepted.
5. Keep `dwm-p2r.14` bounded to token-bound Hospital/Dating adapters and exact
   physical completion. Reconcile its public handoff to this host; do not widen
   it into final art, prose, or player-facing composition.
6. Rebind `dwm-oyo.4` to the approved relationship/date/pair coordinator and
   challenge handoff. If its current file map cannot own the player-facing host,
   create one dedicated narrative-host implementation issue gated by OYO2,
   OYO3/OYO4 as applicable, and explicit runtime authorization.
7. Make `dwm-oyo.5` consume the same host in explicit archive capability modes
   without save/load or canonical mutation. Keep `dwm-oyo.6` ending ownership
   separate; this amendment does not silently design endings.
8. Replace the path-fragment runtime with the accepted eight-master semantic
   manifest and stable presentation identities before relying on Next or exact
   resume.
9. Define and validate closed schemas for shot, physical participant, portrait
   layout, tableau blocking, expression, object/CG, boundary, accessibility,
   and host capability records.
10. Implement one narrative session coordinator and typed view/command ports
    before connecting UI. Scene scripts must not retain direct mutation or route
    calls.
11. Replace the debug challenge overlay with the production board view and
    revisioned command port only after the authoritative board coordinator is
    available.
12. Reconcile save snapshots and recovery participants to the semantic phase
    model, exact challenge entry, and scene completion without storing Nodes or
    raw Dialogic indices.
13. Reconcile the shared Backup and Settings components for full-canvas modal
    hosting without duplicating transactions or profile state.
14. Add localization extraction and catalog entries for all controls, help,
    pause, History, statuses, and accessibility descriptions. Narrative prose
    remains a separate authored-content pass.
15. Produce source-bound unit, integration, scene, accessibility, localization,
    restore, and release evidence under an explicitly authorized implementation
    plan.

No reconciliation step above authorizes implementation by itself.

## 26. Verification matrix

### 26.1 Manifest and physical presence

Verify that:

- every scoped spoken line's speaker is a physically present current-shot
  participant;
- absent participants have no body, portrait, silhouette, thumbnail,
  nameplate icon, caption likeness, focus node, or accessibility node;
- body and portrait enter/exit atomically at one registered atom;
- portrait order equals tableau left-to-right order and never follows speaker
  changes;
- every shot resolves a closed portrait layout and blocking record; and
- missing required assets fail before scene publication.

### 26.2 Geometry and text

At 1280-by-720, verify exact 100% rects: 104-pixel register, 344-pixel tableau,
272-pixel deck, and 64-pixel pinned control rail.

Exercise every scoped host family across:

- text 100%, 125%, and 150%;
- ordinary and Large Targets;
- Primary locales `en`, `zh_CN`, and `zh_HK`;
- single and Dual Language;
- windowed and borderless;
- both base palettes, High Contrast Off/On, and every accepted colour-vision
  preset; and
- Reduced Motion Off/On.

Assert no text clipping, ellipsis, silent shrink, overlap, horizontal text
scroll, hidden focus, or control reorder. At larger text, assert deck growth is
at most 392 pixels, tableau remains at least 224 pixels, and local caption
scroll keeps current content visible.

### 26.3 Portrait and tableau

Verify one-, two-, three-, and every manifest-declared participant layout.
Assert speaking state has both frame-shape and contrast cues, silent portraits
remain legible, action-only atoms activate only their declared present actor,
and no portrait or body reorders on line changes.

Verify registered entries, exits, pose changes, object atoms, close-ins, CGs,
Reduced Motion static swaps, save/restore reconstruction, and optional
expression fallback.

### 26.4 Normal Accept and choices

For pointer, touch, keyboard, controller, and assistive activation, assert:

- one activation during reveal completes only that reveal;
- another released activation advances exactly one beat;
- held/repeated input cannot perform both;
- stage art is inert;
- an unresolved choice is never selected by Normal Accept;
- every choice command binds exact identity and revision; and
- identical, stale, duplicate, and conflicting choice cases are deterministic.

### 26.5 Auto and Skip

Verify Auto's profile-owned preference, revision-bound timer generation, delay,
TTS ownership, stop/suspension boundaries, manual-advance invalidation, Load
preservation, pause, focus loss, and rail/Settings parity. Verify Skip Read Only
stops at the first exact unseen variant and Skip All Text presents unseen
ordinary prose under the accepted receipt law.

Assert Auto and Skip exclude each other, Normal Accept stops Skip, both stop at
choices and challenge entry, and neither enters a board or completes a route.

### 26.6 Next

Use a table crossing exact witnessed/unseen state with line, action, expression,
tier, tone, attitude, echo, result, pair variation, and attempt-residue changes.
Assert only byte-equivalent exact variants count as witnessed.

Verify:

- partial unseen current line completes and stops;
- partial previously witnessed current line may be traversed;
- witnessed beats do not flash or produce TTS/live announcements;
- traversed lines enter current History in canonical order;
- the first unseen exact beat is normally presented and focused;
- choices, markers, effects, unrelated routes, and failure stop traversal;
- `MINESWEEPER_ENTRY` admits exactly one challenge with no extra Accept;
- legal all-witnessed boardless or post-challenge completion admits exactly one
  ordinary completion command;
- Next never crosses an active board or grants evidence/collection capability;
  and
- stale, duplicate, conflicting, interrupted, save, restore, and crash cases
  return the exact committed destination or prior safe state.

### 26.7 Challenge entry and return

Verify the exact phase transitions and command order. Assert board snapshot and
entry receipt are durable before `CHALLENGE_ACTIVE`, focus transfers only after
publication, the triggering event cannot reveal a cell, and repeated inputs
cannot create another board.

Verify foreground board ownership, frozen/dim stage, neutral portraits, removed
narrative controls, board pause, exact save/load, F5/F9, result commit,
consequence order, post-context freeze, transition return, and no result
summary.

Before active publication, verify the board view proves the active 48/64 target
mode and pointer, touch, keyboard, controller, and assistive-input conformance;
missing or false capability must leave the session at the intact entry boundary.

Cross solo and P-L challenge families, all accepted board results, pre-entry
failure, active-board failure, post-result failure, and exact restoration.

### 26.8 Hospital and route ordering

Verify Hospital uses the same host without any board placeholder, offscreen
voice, direct GameState mutation, or direct route call. Cross ordinary and
Sylvia-witness variants, exact present participants, all closure reasons,
interrupted playback, save/restore, Next completion, and completion receipt
replay.

Assert Hospital physically completes before any required visible deferred pair
scene and the host never advances the day itself.

### 26.9 History, Backup, Settings, and pause

Verify History content/order, no rewind/mutation/evidence, language reprojection,
TTS, scrolling, Back, and exact focus return.

Verify Save and Load open the authoritative Backup modes, Save during reveal
completes but does not advance, successful manual Save stays inside Backup with
refreshed metadata, deliberate Backup close returns focus, choices restore
unchanged, and successful Load routes away. Verify F5 performs or coalesces a
direct Quick Save with edge feedback and never opens Backup. Archive playback
exposes no Save/Load, and no second slot implementation exists.

Verify pause order, Continue initial focus, Settings round trip, Save & Return
transaction, failure recovery, and one-level Back behavior.

### 26.10 Persistence and recovery

Test save and restore at every canonical phase and every acknowledged
transaction frontier. Inspect serialized data to prove absence of Nodes,
Controls, resource objects, raw DTL indices, paths, label positions, glyph
indices, tweens, and input events.

Cross exact identical replay, stale revision, changed-command conflict, process
loss before/after durable challenge entry, result, effect, promotion, and
completion. Restore `COMMITTING_RESULT` and `COMMITTING_COMPLETION` from every
ordered receipt stage and prove execution resumes at the first uncommitted
step. Assert no reroll, duplicate board, duplicate consequence, or synthetic
completion.

### 26.11 Input and accessibility

Verify focus graphs, target minima, non-colour state cues, semantic reading
order, present-speaker labels, absence from assistive tree, TTS Primary-only,
quiet suspension, resize, locale switch, input-device switch, and held-input
release gates.

Every command must produce the same semantic result across pointer, touch,
keyboard, controller, and assistive activation.

### 26.12 Visual and failure truth

Verify no routine speaker nameplate, narrator identity, unrestricted thought
box, offscreen speaker treatment, player-authored Angela,
relationship/stat/result summary, hidden mechanic, debug identifier, fake
glitch, or horror-styled technical failure appears. No prose receives a speaker
nameplate or makes Angela a visible avatar; her independently staged
third-person physical presence remains unchanged.

Verify optional expression fallback versus required-asset recovery, missing
localization, unknown host mode, invalid participant layout, stale Next plan,
and indeterminate transaction paths all fail truthfully without partial
canonical mutation.

### 26.13 Structural and ownership guards

Static checks must prove:

- narrative host scripts do not reference GameState, SaveManager filesystem
  APIs, SceneRouter, raw Dialogic paths, or relationship mutation directly;
- Hospital and Dating scripts cannot start timelines or mark completion outside
  the session coordinator;
- debug challenge result controls are absent from production scenes;
- one coordinator owns narrative phase and command idempotency;
- one board owner owns board state and result;
- one Backup owner owns storage/restore;
- one Settings owner owns profile preferences;
- current plans and Beads metadata cite the reconciled authority before runtime
  work; and
- release evidence uses semantic state and geometry assertions rather than
  screenshots as the sole oracle.

## 27. Acceptance and next work

This document was accepted after exact-artifact review established that:

- self-review found no placeholder, internal contradiction, unresolved
  architecture, or accidental implementation authorization;
- authority, scope, physical-presence, control, Next, challenge, Hospital,
  persistence, accessibility, and failure laws are executable and mutually
  consistent;
- no final prose, art, audio, Minesweeper balance, or ending-host design is
  invented; and
- implementation remains gated by authority registration, requirement/plan
  reconciliation, Beads ownership, and separate explicit authorization.

After this written approval, the next design section should close the remaining
production Minesweeper board UI or Day-7/ending presentation only through its
own bounded interview. This amendment does not pre-approve either design.
