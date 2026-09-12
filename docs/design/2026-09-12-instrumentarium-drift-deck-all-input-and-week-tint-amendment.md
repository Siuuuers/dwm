---
id: spec.instrumentarium_drift_deck_all_input_and_week_tint_amendment
kind: design_amendment
schema_version: 1
amends: spec.haunted_instrumentarium_ui_manual_foundation_decisions
amends_path: "docs/design/2026-08-14-haunted-instrumentarium-ui-manual-foundation-decisions.md"
related_authorities: ["story/01-core-story-bible.md","story/08-narrative-style-manual.md","note.global_functional_semantic_alphabet_disposition","note.functional_state_morphology_and_overlap_disposition","note.shared_title_desktop_shell_standard_palette_and_state_disposition","note.deferred_ui_feature_register","spec.settings_preferences_ui_ux_amendment","spec.contacts_messaging_ui_ux_canon_amendment","spec.backup_save_load_ui_ux_amendment","docs/design/current-ui/working-design.md","docs/design/2026-09-02-narrative-constitution-working-decision-ledger.md"]
decision_status: accepted
conversational_design_status: approved_owner_rulings_2026_09_12
conversationally_approved_on: "2026-09-12"
written_spec_status: pending_owner_review
implementation_requested: true
implementation_authorized: true
implementation_authorized_on: "2026-09-12"
implementation_order: "section_13_with_week_tint_first"
beads: dwm-gb6
created_on: "2026-09-12"
engine_line: godot_4_6
audience: private_spoiler_complete
scope: ["owner_ruling_ledger_2026_09_12","foundation_contradiction_resolutions","smooth_typography_at_1280x720","all_input_landscape_layout_law","week_tint_token_over_sixteen_tuples","authored_drift_deck_and_families","drift_invariants_and_never_list","steady_interface_preference","diegetic_ui_sound_cue_roles","per_surface_drift_eligibility","found_paintings_art_direction_and_sourcing_law","issued_student_id_account_identity","proposals_awaiting_ruling","future_implementation_boundary"]
---

# Instrumentarium Drift Deck, All-Input Layout, and Week Tint Amendment

## 1. Status, purpose, and boundary

This amendment records the project owner's UI and interaction rulings of
2026-09-12 and turns them into law for the Haunted Instrumentarium UI manual.
It was produced design-first: it authorizes **no Godot changes, no generated
art, and no audio assets**. Where it names a colour, a size, or a count, that
value is a written direction for a later implementation pass, not a shipped
byte.

The owner's brief was "thrilling and delicious." The reading adopted here is
that the game already owns its most frightening instrument: a save system and
a shell that are honest to the byte. An interface that is trusted can afford
to be wrong a little, at the right moments, in ways the audience can study.
This amendment spends that trust deliberately and never overdraws it.

The foundation ledger and every accepted disposition remain binding except
where Section 12 names an exact supersession. The Core Story Bible, Character
and Relationship Handbook, and Narrative Style Manual remain narrative law;
this amendment derives from them and never amends them.

## 2. Owner rulings of 2026-09-12

Recorded in the order obtained. Each is binding on every later UI disposition.

| # | Ruling |
|---|---|
| R1 | "Resonance with the bibles" means the story bibles under `story/`. The interface obeys the laws the prose obeys. No scriptural or liturgical layer is added. |
| R2 | The Haunted Instrumentarium constitution stays binding. Its contradictions are resolved here (Section 3); further changes are earned one proposal at a time. |
| R3 | Smooth font rendering (Source Sans 3, Source Han Sans SC, Source Han Sans HC) at a 1280 × 720 logical stage wins. The 640 × 360 pixel-font foundation is retired. |
| R4 | Interaction feel is fully open. Core rules (Minesweeper as the date board, the three-truth mechanism, progression windows, Hospital trigger) change only through a named proposal the owner rules on. |
| R5 | Interface wrongness is **graded across the seven days**. The shell never lies about a player action. |
| R6 | Only day-by-day plot and story auditions are reference material. The Bible, Handbook, and Style Manual stay law. |
| R7 | Inputs served: mouse, keyboard, gamepad, and touch. Screen shape: landscape only. |
| R8 | Output is documents only. No generated art or audio assets; art direction is written, and anything stylistic that UI code can carry (colour, material, motion) is in scope. |
| R9 | All four drift families are permitted: clock and timestamps; wallpaper, palette, and copy; records and archives; structure and layout. |
| R10 | Structure may change **only across a boundary** the player crosses, never under the hand. |
| R11 | Drift is **never confirmed** to the audience by any screen, including Observer postscripts. |
| R12 | A UI sound layer is specified as diegetic cue roles. Silence is a valid decision. |
| R13 | The palette slides **warm to cold** across the week with no visible step. |
| R14 | Midnight stays bound to Dark runs and After-Hours to ordinary runs. The player never selects a base palette. |
| R15 | Drift randomness comes from an **authored deck drawn per run** with a receipt, using the existing deterministic RNG. |
| R16 | Dark runs and ordinary runs share the **identical** drift curve. |
| R17 | Settings gains a **Steady Interface** accessibility preference that disables the structural family only. |
| R18 | Scene and portrait art is sourced from **public-domain, open-access museum paintings**, impressionism preferred. Nothing is generated. (Ruled 2026-09-12, second round.) |
| R19 | UI sound is specified as **placement, function, and feeling** only. No sourcing, licensing, or acquisition work now. (Second round.) |
| R20 | The account identity is an **institution-issued student ID**, never a typed name. (Second round; supersedes the first draft of proposal P2.) |

## 3. Resolutions of the six foundation contradictions

### 3.1 Typography and canvas (R3)

Foundation Sections 6.2, 6.3, 10, and 11 are superseded as follows.

- The authored stage is **1280 × 720 logical**, `canvas_items` stretch, aspect
  `keep`. 1920 × 1080 and 2560 × 1440 scale uniformly; 1366 × 768 and the
  Steam Deck's 1280 × 800 receive an inert matte on the short axis (24 px and
  40 px per side respectively). The matte is noninteractive and carries no
  evidence. This preserves the foundation's "never crop, never rearrange
  macro topology" law on the new stage.
- Functional text uses the font renderer: Source Sans 3 Regular for English,
  Source Han Sans SC Regular for `zh_CN`, Source Han Sans HC Regular for
  `zh_HK`, at 24 / 30 / 36 logical px for the 100 / 125 / 150 % presets, as
  the 2026-09-05 working direction already tested. Fusion Pixel Font and the
  8 / 10 / 12 px bitmap masters are retired. Source Han Serif is retained only
  as an *optional* display face for the title logotype and ending titles, and
  only if a later art pass asks for it.
- "Pixel materials" (Section 11) survive as **materials, not rasters**: seams,
  hatch, filing rules, and wear are drawn as crisp 1 px or 2 px logical strokes
  by code. Nothing in the UI is a scaled bitmap.
- The font directory `assets/ui/contacts/fonts/` is now shared by every
  surface; its path is a historical accident. A later implementation pass may
  move the three files to `assets/ui/fonts/` in one commit; this amendment
  neither requires nor forbids that.

### 3.2 Derivative closure

The shell disposition's "no seventh derivative" sentence is superseded. The
authored value set is the ten primitives plus the six shell derivatives plus
Contacts' two identity-only values (Worn Mauve `#756477`, Weathered Verdigris
`#4F665C`): **eighteen named values**. New values may be added only by a
disposition that names them and their sole consumer, as Contacts did. The
week tint (Section 5) adds *no* new named values; it interpolates between
existing ones.

### 3.3 Authorization status

Every disposition that says `implementation_authorized: false` is telling the
truth about itself: none of them authorized the September playable build. The
build was authorized separately by the owner's simplified-implementation
decision recorded in `docs/agent/2026-09-07-whole-game-implementation-reconciliation.md`.
The two are reconciled by this rule: **the playable build is provisional
implementation; the dispositions are intended appearance.** Where they differ,
the disposition wins at the next visual pass, and the build's shipped tuples in
`scripts/settings/SettingsPaletteRegistry.gd` are treated as the implemented
subset of the sixteen, not as a competing authority.

### 3.4 Contacts row pitch

48 px logical row pitch is adopted, closing the 44-versus-48 question in the
direction the all-input law (Section 4) requires anyway.

### 3.5 Gallery record copy

The Microfiche Registrar design assumed registered ending record copy. Until
the ending titles leave their `Provisional` header, the Gallery shows the
literal `Unavailable record` row with Replay in the Unavailable morphology
(dashed boundary and hatch, never dimming). This is correct current behaviour,
not a defect, and it is *not* a drift card.

### 3.6 Deferred register Section 3 (no-scaffold clause)

The register forbade any "random seed, variant deck, receipt" for deferred
anomaly features. This amendment does not promote entry 4.3: the Drift Deck is
a **new, owner-approved family for the operating-system shell**, distinct from
the scene-aperture anomaly generator that 4.3 preserves. Entries 4.1, 4.2, 4.3
remain `deferred`. A cross-reference line is added to the register so that a
later reader cannot mistake one for the other. The no-scaffold clause continues
to bind the aperture; it does not bind the shell once implementation of this
amendment is separately authorized.

## 4. All-input landscape layout law (R7)

Foundation Section 16's first bullet is widened: every core operation supports
mouse, keyboard, gamepad, **and touch**. The following laws apply to every
surface.

1. **No hover-only information.** Hover remains a quiet local inspection
   response (alphabet: Hover), but any fact it reveals is also reachable by
   focus and by a tap. A touch device has no hover; the surface must be
   complete without it.
2. **Targets.** Ordinary minimum target 48 × 48 logical; Large Targets 64 × 64.
   Adjacent targets are separated by at least 8 px or a drawn seam.
3. **Focus is authored, never emulated.** Gamepad input drives the existing
   focus grid; a virtual mouse cursor is forbidden. The detached double-outline
   Focus mark appears after any non-pointer input and stays until the next
   pointer or touch event. Pointer use hides Focus; it never destroys it.
4. **Touch verbs.** Tap = Accept. Long-press (500 ms, with a static inward
   contact seam as the only feedback) = the secondary verb (Minesweeper Flag,
   Backup inspect). Drag = the existing Drag mode only. Two-finger gestures are
   never required. Because Minesweeper already exposes Reveal / Flag / Drag as
   an explicit mode row, touch never depends on long-press alone.
5. **Right-click parity.** Everything a right-click does is also a mode or a
   long-press. Right-click is a shortcut, not an owner.
6. **Gamepad glyphs** are drawn as the same literal-label buttons as keyboard
   hints, in the shell's own material, never platform-branded icons.
7. **Scroll** is by focus movement, wheel, drag on a scrollbar with a 48 px
   thumb, or touch swipe within the scrolling region. Horizontal text
   scrolling remains forbidden.
8. **Safe regions.** Nothing interactive sits within 16 px of a stage edge, so
   a Steam Deck bezel or a tablet gesture zone never swallows a control.
9. **Steam Deck at 800p text.** The 100 % preset must remain readable at 7 in.
   diagonal; if a later physical check fails, the fix is a larger preset
   default on that device, never a smaller macro layout.

## 5. Week tint token (R13, R14)

### 5.1 Definition

A single day-indexed scalar `week_tint` in [0, 1] is derived at every boundary
(login, day advance, return from a scene) as an eased curve over the run's
calendar day:

| Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| `week_tint` | 0.00 | 0.08 | 0.20 | 0.38 | 0.58 | 0.80 | 1.00 |

The token never changes between boundaries and never animates.

### 5.2 Application

The token modulates only the **room roles** of the active tuple: `habitat`,
`face`, `paper`, `structure`, `secondary_ink`, `inward_preview`. It never
touches `ink`, `paper_ink`, `focus`, `paper_focus`, `danger`, `destructive`,
or `filed`, so every contrast guarantee and every semantic colour remains as
authored.

For each modulated role the **shipped tuple value is the Day 1 (warm)
endpoint** and the tuple carries an authored **cold endpoint** reached at Day 7.
(Corrected 2026-09-12 at implementation time: the first draft placed the shipped
value at the Day 4 midpoint, which would have changed every Day 1 render; keeping
Day 1 byte-identical to the shipped tuple is worth more than symmetry, and the
whole authored range now lies on the cold side.) Provisional cold-endpoint
deltas for the two Standard masters, expressed in OK HSL so that hue never
rotates:

| Role | Day 7 (cold) delta at tint 1.0 |
|---|---|
| `habitat` | L −0.035, S −0.015 |
| `face` | L −0.05, S −0.012 |
| `paper` | L −0.05, S −0.025 (greyer bone) |
| `structure` | S −0.016 (toward Fog Blue) |
| `secondary_ink`, `inward_preview` | L −0.01 |

The amplitudes are deliberately below the threshold at which a single-day
step is perceptible; the effect is only visible when Day 1 and Day 7 are
placed side by side. High-contrast tuples receive **zero amplitude**. CVD
tuples receive lightness deltas only, no chroma deltas.

### 5.3 Binding to run mode

Midnight and After-Hours remain selected by run mode (`dark_mode` in the run
configuration), as the code already does. The week tint rides on top of
whichever base was chosen. No Settings row selects a base palette; the
existing read-only `Dark mode available` and `Enable dark mode next run`
rows are the only player-facing surface of this fact.

### 5.4 What the tint is not

It is not a drift card, not an anomaly, and not evidence. It is the room
ageing. It is therefore exempt from the Steady Interface preference and from
Reduced Motion (it never moves).

## 6. The Drift Deck (R5, R9, R10, R11, R15, R16, R17)

### 6.1 Governing statement

> The shell keeps every promise it makes to the hand. It keeps fewer of the
> promises it makes about the past.

A **drift card** is one authored, bounded, deterministic departure of the
operating-system shell from its own record. Cards are drawn from a closed
authored deck once per run, applied only at boundaries, never confirmed, and
never permitted to touch the never-list in Section 6.6.

Foundation Section 4.1 (wrongness budget) is superseded for the shell by the
allowance table in Section 6.4. It remains in force for witnessed scenes,
Hospital, and endings, which this amendment does not touch.

### 6.2 Families

| Family | ID | What may drift | What may not |
|---|---|---|---|
| Clock | `clock` | Message timestamps, save timestamps, Gallery and Backup dates, the routine clock's displayed minute. | The order of any list; the day number; any duration the player is asked to act within. |
| Surface | `surface` | Wallpaper colour field, one room-role tint beyond the week curve, one label word replaced by a near-synonym, a launcher caption's letter-spacing, one keepsake socket's material. | Any label that names an action (Save, Load, Buy, Delete, Skip); any price, count, or balance; any Focus, Danger, Destructive, or Unavailable mark. |
| Record | `record` | Gallery row count, a Backup slot's display name, a Contacts history entry the player never made, a read receipt on an unopened message, a greeting that addresses the account by a different name once. | The stored bytes of any save, slot, profile, or journal; the truth of which ending was reached; the content of any message Angela sent; any receipt the Shop issued. |
| Structure | `structure` | Launcher order, the eighth launcher position becoming occupied, a panel's inner padding, a second static pointer resting on the desktop, the app strip's seam count. | Any control's size or hit region; the Home position; the Pause action pane; anything while focused, pressed, or under a pointer or finger. |

### 6.3 Boundaries

A card may take effect only at one of these boundaries, and only if no control
is focused-and-pressed, no pointer button is down, and no touch is in
progress:

- account login and account creation;
- day advance (the Schedule commit that resolves the day);
- return to the desktop from a witnessed scene, Hospital, or ending;
- reopening an app whose window was hidden (the app strip's hide-not-free
  semantics make this a real boundary);
- Load from Backup or Pause.

Between boundaries the shell is exactly as stable as it is today. A card that
would have fired but found the hand busy waits for the next boundary. Idle time
is **not** a boundary.

### 6.4 Allowance by day

| Day | Families open | Maximum active cards | Notes |
|---|---|---|---|
| 1 | none | 0 | Spotless. The room earns trust. |
| 2 | clock | 1 | One misdated thing, late in the day. |
| 3 | clock, surface | 2 | |
| 4 | clock, surface, record | 3 | The first record card fires after the Day 4 boundary, never before. |
| 5 | clock, surface, record | 4 | |
| 6 | all four | 5 | Structure opens. Both structure cards on Day 6 must be from the "quiet" subset (order, padding, seam count). |
| 7 | all four | 7 | The eighth launcher and the second pointer are Day 7 only. |

"Active" means visible somewhere in the shell after the boundary. A card may
retire (revert) at a later boundary; reversion is itself never announced.
Cards never accumulate past the day's maximum; the draw is trimmed, not the
law.

### 6.5 Determinism, draw, and receipt

- The deck is a closed authored list of cards (Section 6.8 gives the seed
  set). Each card declares `id`, `family`, `earliest_day`, `surface`,
  `quiet` (bool), `reduced_motion_safe` (always true; cards never animate),
  `structure_moves_target` (bool; must be false), and its localized copy keys.
- At run creation, an `ui.drift.deck` stream is seeded with the existing
  `DeterministicRng32` (`stream_id = &"ui.drift.deck"`, `nonce = run_id`).
  A **draw plan** is produced in one pass: for each day, an ordered subset of
  eligible cards up to that day's maximum, rejection-sampled exactly as
  `PairDeckDraw` rejects an incomplete modulo bucket.
- The draw plan and a receipt (`ruleset_id`, `rng_nonce`, card ids in order,
  deck fingerprint) are stored **in the run snapshot** as a canonical JSON
  member. This is the only persisted drift fact. No drifted *value* is ever
  written to a save.
- Replaying, loading, or crash-recovering a run reproduces the identical plan.
  Two accounts draw differently. A community can compare and find overlap.
- Dark runs use the same deck, curve, and maxima (R16). Their only difference
  is the Midnight base.

### 6.6 The never-list

No card, in any family, on any day, may:

1. change what a player action did, or misreport that a save, load, purchase,
   setting change, reply, or Schedule commit happened when it did not (this
   restates Foundation Section 19 and it wins over every card);
2. write, alter, reorder, or withhold a word Angela owns: self-talk, sent
   replies, choices, silence (Style Manual: Angela owns every line);
3. touch Minesweeper board truth, mine count, Foresight, rounds, resources,
   money, care, conditions, or any Shop receipt;
4. touch a save's bytes, a slot's contents, the profile, the journal, or the
   Gallery's record of which endings were reached;
5. move, resize, or re-target any control while it is focused, pressed, or
   under a pointer or finger;
6. animate, flicker, glitch, or use motion in any way (Reduced Motion is
   therefore satisfied by construction);
7. depend on colour, sound, or hover alone to exist (a screen reader user and
   a touch user meet the same card);
8. be confirmed, explained, annotated, badged, rewarded, or resolved by any
   screen, including Observer postscripts (R11);
9. simulate a crash, corrupt install, diagnostic, or error;
10. fire on Day 1, or fire a structure card that is not `quiet` before Day 7;
11. make Day 7's never-generated invitations anything other than literal
    silence; or
12. exist in fewer than three locales.

### 6.7 Steady Interface preference (R17)

A new accessibility row is added to the existing `accessibility` section of
`SettingsPreferenceRegistry`:

| Path | Type | Default | Renderer | Label (en / zh_CN / zh_HK) |
|---|---|---|---|---|
| `preferences.accessibility.steady_interface` | bool | false | toggle | Steady interface / 稳定界面 / 穩定介面 |

When true, the `structure` family is suppressed entirely and any card in
another family whose `structure_moves_target` would be true is likewise
suppressed (there should be none). Clock, surface, and record cards continue.
The draw plan is unchanged; suppression is a presentation filter, so turning
the preference off later restores the same plan. The row carries the literal
description "Keeps launchers, panels and pointers where they were." and no
mention of story, drift, or horror.

### 6.8 Seed deck (authored cards, first cut)

These are the cards recommended for the first authored deck. Each is a
direction; final copy is written at implementation, in three locales, under
`drift.<family>.<card_id>` keys with placeholder parity.

**Clock**

- `clock.reply_stamped_before_sent` — an incoming reply's timestamp precedes
  Angela's outgoing message by one to four minutes. Order unchanged.
- `clock.routine_minute_repeats` — the routine clock shows the same minute
  twice across one boundary; it is real time again at the next.
- `clock.save_dated_tomorrow` — one Backup slot's date reads the next calendar
  day. The slot's contents and label are true.
- `clock.gallery_date_blank` — one Gallery row's date is blank, in the
  Unavailable morphology, though the record itself is available.

**Surface**

- `surface.wallpaper_one_step_deeper` — the desktop colour field takes the
  Day 7 cold endpoint early, for one day, then returns to the curve.
- `surface.launcher_synonym` — one launcher caption reads a near-synonym
  (`shop` → `stores`; `backup` → `archive`). Never the action verbs.
- `surface.keepsake_socket_material` — one of the three keepsake sockets on
  the Angela panel is drawn in paper instead of habitat for a day.
- `surface.contacts_slip_narrower` — outgoing slips in Contacts lose 8 px of
  width for a day. Text reflows; nothing clips.

**Record**

- `record.read_receipt_unopened` — a message Angela has not opened shows a
  read mark. Opening it behaves normally.
- `record.history_entry_unmade` — Contacts history shows one short entry
  Angela did not send, in her voice's *absence*: the entry is the friend's
  reply to nothing. (This never puts words in Angela's mouth; it puts a reply
  where her words were never given.)
- `record.slot_named_by_no_one` — a Backup slot the player never named carries
  a name. Its contents are true and loadable.
- `record.gallery_count_off_by_one` — the Gallery index count is one higher
  than its rows. Scrolling finds no extra row.
- `record.greeting_wrong_account` — once, on Day 6 or 7, the login greeting
  addresses a student ID that differs from this account's by exactly one
  digit. The ID in the title ledger is unchanged. (A wrong name is a mistake;
  an ID one digit off is another person who exists.)

**Structure (quiet subset, Day 6+)**

- `structure.launcher_order_rotated` — the seven launchers rotate by one
  position. Sizes and hit regions unchanged.
- `structure.app_strip_extra_seam` — the app strip shows one more filing seam
  than it has apps.
- `structure.panel_padding_tightens` — the Angela panel's inner padding
  shrinks by 4 px. Content reflows.

**Structure (Day 7 only)**

- `structure.eighth_launcher_occupied` — the genuinely absent eighth position
  holds a launcher captioned with a literal, boring app name (`notes`). It
  opens an app-shaped room containing nothing: no placeholder, no scar. Home
  returns normally. It is not a reward and has no content, ever.
- `structure.second_pointer_resting` — a second pointer arrow, drawn in the
  shell's own material, rests motionless on the desktop. It is not the real
  pointer, never moves, has no hit region, and is drawn beneath every control.

**Sound** (see Section 7)

- `sound.contact_arrives_late` — one Accept contact sound plays 180 ms after
  the state change, once.
- `sound.paper_without_paper` — one paper cue plays at a boundary where no
  sheet changed.

## 7. Diegetic UI sound cue roles (R12)

Foundation Section 13.5 is retained and extended. The UI sound layer is
specified as **roles**, never files. Every role has a text equivalent already
provided for by the `Sound detail text` preference. Silence is a valid
decision for any role on any surface.

Per R19, this section is complete as placement, function, and feeling. It
names no source, file, licence, or acquisition step; those belong to a later
research ledger in the pattern of `docs/research/audio/`.

| Role | Placement | Function | Feeling | Never |
|---|---|---|---|---|
| `contact` | Accept, commit, on every surface | Confirms the hand was answered now | A switch under a fingertip; short, soft, mechanical | Reward sparkle, chord |
| `seam` | Entering a new focus group | Orients a non-pointer user | One dry tick, like a drawer stop | Per-item ticks |
| `paper` | A Worn Cream sheet appears or turns (Contacts, Schedule, Gallery, Backup inspector) | Marks that a record was handled | Dry paper, low, a little too close to the ear | Page-flip flourish |
| `hum` | Desktop and app bed | Tells the ear the building is on | Equipment hum at the edge of hearing; you notice it only when it stops | Musical drone, tonal centre |
| `room` | Witnessed scenes (owned by the aperture, listed for completeness) | Places the body in a real room | Room tone: a fridge, a corridor, weather through glass | Score |
| `refusal` | Operational refusal | Says no without judgement | Two close dull tones plus literal text | Horror sting |
| `custody` | Busy states (`Saving…`) | Proves the shell is still holding the record | Static, almost inaudible, patient | Progress loop |

Sound cards (Section 6.8) may displace a role's timing by at most one
`Shift` token (180 ms) or add one `paper` cue, once per day, Day 3 onward.
They never remove a cue whose absence would hide a state change from a
non-visual user.

## 8. Per-surface drift eligibility and all-input notes

| Surface | Eligible families | All-input notes |
|---|---|---|
| Title | clock, record | Rows are already 48 px; gamepad wraps vertically. The optional art presenter has no hit region. |
| Desktop shell and Angela panel | all four | Launchers are the structure family's main stage. Self-talk dock is on the never-list. Keepsake sockets are surface-only. |
| Contacts | clock, surface, record | Long-press on a row = inspect. Reply controls are never drift material. |
| Schedule | clock | The docket sheet and commit are never drift material; only displayed times may drift. |
| Shop | surface (wallpaper and caption only) | Prices, counts, balances, receipts are on the never-list. |
| Minesweeper | none | The worksheet is the sole in-scene agency mechanism and stays spotless. Mode row satisfies touch. |
| Backup | clock, record | Delete remains an app-contained consent sheet. Slot bytes never drift. |
| Settings | none | The calibration laboratory never corrupts (existing law). Hosts the Steady Interface row. |
| Gallery | clock, record | Replay stays in Unavailable morphology until records exist. |
| Witnessed scenes, Hospital, endings | none (aperture-owned; Foundation 4.1 still governs) | Caption rail buttons are 48 px; touch swipe on the caption field pages. |
| Pause | none | The frozen art veil and action pane are never drift material. |

## 9. Art direction: found paintings (R18)

The Bible fixes portrait *structure* (one fixed portrait per solo scene, two
per group or twofriends scene, no expression variants) and never commits to a
rendering style. The owner ruled on 2026-09-12 that the art is **public-domain,
open-access museum painting**, with impressionism preferred. Nothing is
generated, and this amendment produces, downloads, or imports no image.

### 9.1 The direction

The four women are shown as **found paintings**. Each is represented by one
painting chosen once and kept for the whole game, so that the audience learns
a face the way one learns a face in a gallery: by return, not by expression.
Group and twofriends scenes place two paintings in the aperture; solo scenes
place one. Angela still receives no scene art (existing law).

A painting is a record of a person, not a likeness of a character. The
interface never says why a nineteenth-century canvas stands for a
twentieth-year student; no caption, glossary, or ending explains it. This is
the Barthes lens doing exactly its duty: an open trace that rhymes without a
decoding key.

Why impressionism serves the constitution rather than fighting it:

- **Warm visitor in a cold room.** The primitives are night; an impressionist
  canvas is daylight. The foundation's law "Night is the room. Paper is the
  visitor." extends verbatim to canvas: the painting is the one warm thing,
  bounded by the aperture, never allowed to become global daylight.
- **Observed, not posed.** Morisot's and Cassatt's interiors and Degas's
  rehearsal rooms show women watched from a slight distance, mid-task. That is
  the Robbe-Grillet lens: object, position, absence, no explanatory ornament.
- **Fixed portraits are already the rule.** A painting cannot change
  expression, so the Bible's "no expression variants" is not a limitation but
  the material's nature.
- **Lavinia is a conservatory dancer.** Degas is the obvious well, and also
  the obvious trap; a rehearsal room, a stretch, a foot, rather than the
  famous stage tutus, keeps the choice from reading as a joke.

### 9.2 Sourcing law (no acquisition now)

- Eligible sources are museum open-access programs that publish works as
  **CC0 or explicit public domain** with a per-work rights statement on the
  work's own page. Examples of programs that publish such statements include
  the Metropolitan Museum of Art, the Art Institute of Chicago, the National
  Gallery of Art (Washington), the Rijksmuseum, the Cleveland Museum of Art,
  and Paris Musées. Naming a program here is not verification of any
  individual work.
- Only the *photograph* the museum itself publishes under that statement is
  eligible. A photograph of a public-domain painting taken by someone else may
  carry its own rights and is out.
- Every candidate enters a research ledger in the pattern of
  `docs/research/audio/`: museum, accession number, artist, date, the exact
  rights statement quoted from the work page, the work-page URL, and a
  candidate status whose highest value is `APPROVED FOR ACQUISITION REVIEW`.
  Research may not download, edit, import, or ship, exactly as the audio rule
  says.
- Attribution is not required by CC0 but is given anyway, in the Settings
  folio's records section, as the museum's own credit line. This is the only
  place a museum is named, and it is factual, not story.

### 9.3 Treatment law

- Paintings are shown **unfiltered**: no tint, no desaturation, no vignette,
  no grain, no colour-grading toward the primitives. High Contrast and CVD
  tuples do not recolour art (existing law).
- The aperture crops; it never distorts. A crop may isolate a hand, a back, a
  chair, a window, as the scene's registered camera coordinate demands.
- The week tint (Section 5) does not touch the painting. The room ages around
  it.
- Drift never touches a painting (Section 8). A painting is the one thing in
  the game the audience may trust to look the same on Day 7 as on Day 1,
  which is why its warmth reads as cruelty by the end.
- Impressionist brushwork is a *texture*, and the covenant's "wear is geology"
  law applies: no UI element imitates it. The shell stays flat around a canvas
  that is not.

### 9.4 Wallpaper

Wallpaper is **code-drawn**: a flat colour field per base palette, modulated
by the week tint and by at most one surface card. No wallpaper bitmap is
produced or required. A painting never becomes wallpaper.

## 10. Proposals awaiting ruling

These are additions the orchestrator recommends. None is law until the owner
rules. Each is written so it can be struck without affecting the rest.

- **P1 Dwell ledger as deck input.** The Bible says the interface "remembers
  observation, hesitation, revisiting, and persistence." Record which contact
  rows, Gallery rows, and Backup slots the player lingered on (focus or hover
  ≥ 2 s, or repeated opening) and let record cards prefer those targets when
  choosing where to fire. The draw plan stays deterministic; only the
  *placement* of an already-drawn card consults the ledger, resolved at the
  boundary. Nothing is ever shown about the ledger itself.
- **P2 Login as the first boundary, with an issued ID (R20).** Account
  creation asks for nothing. New Acc shows a single Worn Cream sheet on which
  the institution has already written a student ID; the player reads it and
  accepts. The ID is minted deterministically from the run's identity (the
  existing desktop identity contract is the natural owner) so it is stable
  across saves and different across accounts. The player therefore never
  authors a single character into the shell, which is the Bible's "registered
  possibilities only" made literal, and it is what makes
  `record.greeting_wrong_account` land: an ID one digit off is another person
  who exists. The Log in row lists accounts by ID. The ID's format is
  provisional: a two-digit intake year, a two-letter faculty code, and five
  digits, so that "one digit off" is always possible and never changes the
  faculty.
- **P3 Real clock stays real.** The routine clock shows the player's wall
  clock, as it does now. On Day 7 it also shows seconds. This is not a card;
  it is the room paying closer attention.
- **P4 Card retirement is silent and partial.** A retired record card leaves
  no trace; a retired structure card may leave one seam behind (the extra
  app-strip seam persists after the launcher order reverts). One residue per
  run, Day 7 only.
- **P5 Title after the first ending.** The `Log in` row shows the last
  account's timestamp. After the first reached ending, once, that timestamp
  is the Day 7 date rather than the real date. Clock family, Title only.
- **P6 Sound detail text carries cards.** When `Sound detail text` is on, a
  sound card's late contact is described literally ("contact, late"). This
  keeps the never-list's parity promise for deaf and hard-of-hearing players
  without explaining anything.

## 11. Localization and verification obligations

- Every drift card's copy exists in `en`, `zh_CN`, and `zh_HK` under
  `drift.<family>.<card_id>` with named-placeholder parity, so the existing
  catalog validator can reject an incomplete card at build time.
- Near-synonym cards ship the synonym in all three locales; a locale without
  a natural synonym ships the original word (the card is then invisible in
  that locale, which is lawful).
- Design acceptance for this amendment, checkable from documents alone:
  every card in Section 6.8 declares a family, an earliest day, a surface,
  `quiet`, and `structure_moves_target = false`; every allowance row is
  monotone; the never-list is quoted verbatim in any later per-card
  disposition; the Steady Interface row is present in the preference table;
  Section 8 lists every shipped surface.
- Implementation acceptance is deferred to the implementation plan (Section
  13) and will at minimum require: a deterministic draw-plan test with a
  frozen receipt, a never-list static scan (no card may reference a
  never-list path), a three-locale parity test per card, a boundary test that
  proves no card fires while a control is pressed, and the sixteen-tuple
  contrast check re-run at Day 1 and Day 7 endpoints.

## 12. Exact supersessions

| Superseded | By |
|---|---|
| Foundation 4.1 wrongness budget, for the shell only | Section 6.4 |
| Foundation 6.1 platform (Windows only; controller optional) | Section 4 |
| Foundation 6.2 raster law (640 × 360, integer scale, nearest filtering) | Section 3.1 |
| Foundation 6.3 target sizes expressed in native px | Section 4.2 |
| Foundation 10 typography (Fusion Pixel, bitmap masters) | Section 3.1 |
| Foundation 11 pixel materials as rasters | Section 3.1 (materials drawn by code) |
| Foundation 13.5 interaction sound (retained, extended) | Section 7 |
| Foundation 16 first bullet (mouse, keyboard, controller) | Section 4.1 (adds touch) |
| Shell disposition "no seventh derivative" | Section 3.2 |
| Deferred register Section 3 as applied to the shell drift family | Section 3.6 |
| current-ui/working-design.md typography table (confirmed, now law) | Section 3.1 |

Nothing in the Core Story Bible, Handbook, Style Manual, narrative ledger,
Room-Owned Aperture disposition, or any app disposition's geometry, commands,
routing, or persistence law is superseded.

## 13. Future implementation boundary

When the owner authorizes implementation, the plan must, in this order:

1. add the Steady Interface preference row and its three-locale labels;
2. add the `ui.drift.deck` draw plan and receipt to the run snapshot schema
   (a schema bump; the blast radius rule in project memory applies: run the
   full tree, not the grep-selected set);
3. add the week tint derivation and the endpoint tables to the palette
   registry without changing any shipped tuple value;
4. implement the boundary gate and the presentation filter;
5. author the seed deck copy in three locales;
6. re-seal the affected frozen-gate evidence once, after all edits, per the
   documented re-seal recipe.

Until then, the current build's behaviour is correct as shipped and no drift
exists.

## 14. Deliberately unresolved

- Final numeric endpoints for the week tint per tuple (Section 5.2 values are
  provisional until measured against the sixteen-tuple contrast check).
- The full authored deck beyond the seed set, and which cards are Dark-only
  if the owner ever reverses R16.
- Whether `Sound detail text` is the right carrier for P6 or a new row is.
- The rulings on proposals P1, P3, P4, P5, and P6 in Section 10. Section 9 is
  ruled (R18); P2 is ruled (R20).
- The four candidate paintings themselves. The first candidate ledger exists
  at `docs/research/art/2026-09-12-found-paintings-candidate-ledger.md`
  (nineteen rows, all `CANDIDATE`, two still unverified because the Art
  Institute of Chicago and the Met block automated page reads); none is named
  as more than a candidate until the owner reviews it row by row. Two rows
  carry rights statements narrower than Section 9.2's CC0-or-explicit-public-
  domain rule (Yale's US-scoped statement; a jointly owned Getty work) and
  need an owner ruling on whether they qualify.
