---
id: note.deferred_ui_feature_register
kind: deferred_design_register
schema_version: 1
decision_status: accepted
owner_choice: one_deferred_ui_register_with_per_feature_promotion
owner_choice_on: "2026-08-22"
current_direction: preserve_future_ui_intent_without_v1_scaffolding
conversational_design_status: approved_owner_direction
conversationally_approved_on: "2026-08-22"
written_spec_status: approved
written_spec_approved_on: "2026-08-22"
implementation_requested: false
implementation_authorized: false
created_on: "2026-08-22"
audience: private_spoiler_complete
scope: ["deferred_ui_registry","observer_ui_deferral","future_visual_anomaly_generator","future_non_narrative_avatar_frame","post_v1_scene_aperture_refinements","special_ending_visual_reconciliation","promotion_and_retirement_law"]
related_authorities: ["story/01-core-story-bible.md","spec.haunted_instrumentarium_ui_manual_foundation_decisions","note.canonical_spoken_scene_agency_disposition","docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md","spec.ordered_ending_host_universal_pause_ui_ux_amendment"]
---

# Deferred UI Feature Register

## 1. Accepted purpose

The project owner approved one central register for UI directions that are
deliberately excluded from the current simple implementation stage but must not
be forgotten. A deferred feature receives its own focused design specification
only when the owner later reopens it.

This register records **preserved intent and boundaries**, not complete feature
designs. It is not:

- an implementation plan, roadmap, sprint backlog, or release promise;
- authorization to create code, scenes, assets, settings, save fields, tests,
  localization, compatibility paths, or Beads work;
- a substitute for the active UI specifications that govern current behavior;
- permission to infer unrecorded future mechanics from an evocative name; or
- a container for audio design.

The accepted architectural choice is a hybrid: one small discoverable register
now, followed by one separately approved specification per promoted feature.
Writing one speculative pseudo-specification for every future possibility now
would freeze premature details. Scattering deferred notes through active v1
specifications would make the v1 boundary unreliable.

## 2. Authority and lifecycle

### 2.1 Current authority remains current

Active accepted design continues to govern every current player-facing surface.
An entry in this register cannot weaken, replace, or reinterpret story canon,
route law, Minesweeper agency, the no-dialogue-choice disposition, the current
Room-Owned Aperture boundary, or any current accessibility and truth constraint.

If a deferred direction conflicts with an accepted current authority, the
feature remains deferred until a successor owner-approved design resolves the
conflict explicitly. Implementation may not choose a convenient interpretation.

### 2.2 Entry statuses

Each entry has exactly one lifecycle status:

- `deferred`: its bounded intent is preserved, but it owns no implementation;
- `promoted`: a separately approved successor design now owns the feature; or
- `retired`: a later owner decision rejects or supersedes the future direction.

Historical entries remain in the register when promoted or retired. They are
not deleted or silently rewritten.

### 2.3 Promotion law

Promotion requires all of the following:

1. an explicit owner request to reopen one named entry;
2. a bounded design exploration for that feature;
3. a separately reviewed design specification naming current authorities and
   exact supersessions;
4. an update of this entry to `promoted` with the successor document ID; and
5. separate implementation authorization after the successor design is
   approved.

The successor specification owns detailed interaction, state, persistence,
failure, accessibility, content, asset, and verification law. This register
keeps only the short historical boundary and link; it never duplicates the
successor specification.

## 3. Global current-stage boundary

While an entry is `deferred`, the current implementation creates no anticipatory
scaffold for it. In particular, it adds no:

- dormant runtime enum, branch, feature flag, or compatibility mode;
- hidden control, inactive slot, mystery symbol, placeholder, or missing-art
  treatment on the player surface;
- save/profile field, random seed, variant deck, receipt, or migration rule;
- speculative asset family, animation track, camera, overlay, or input action;
- localization key, assistive announcement, tooltip, tutorial, or explanatory
  prose; or
- test that accidentally converts a possible future direction into current
  production law.

The current interface remains complete without these features. Their absence is
not presented as locked content or a technical failure.

## 4. Deferred feature entries

### 4.1 `future_ui.observer_verification`

- **Status:** `deferred`.
- **Preserved future intent:** A future Angela-Priscilla Observer presentation
  may use `CAPTURE` only while an exact designated History line is actively
  indicated. `COMPARE` may then place the stored and current text together. The
  operation proves contradiction, never cause, intention, or supernatural
  explanation.
- **Input boundary:** Pointer hover and keyboard/controller focus may indicate
  the same exact line and expose the same evidence. This is operational access
  to one mechanism, not an equivalent explanatory substitute or extra clue.
- **Agency boundary:** `CAPTURE` and `COMPARE` are evidence operations, not
  dialogue choices, Angela-authored replies, or selectable ending results.
- **Current behavior:** Existing runtime routing and playback remain unchanged
  and presently reachable through the current progression. Deferral of this
  special History grammar does not disable, hide, or relabel an Observer ending,
  and the current game invents no temporary replacement mechanic. This register
  neither defines nor certifies canonical Observer qualification.
- **Reopen only when:** Ordinary History identity, cross-run witnessed-state
  ownership, input parity, and Observer migration requirements can receive one
  dedicated design pass.
- **No current scaffold:** No hidden hover target, capture flag, compare overlay,
  stored-line UI record, or Observer-specific History branch is added now.

### 4.2 `future_ui.observer_restraint`

- **Status:** `deferred`.
- **Preserved future intent:** A future Angela-Lavinia Observer presentation may
  introduce one silent false cursor drifting toward a physically plausible
  intervention. The audience has meaningful time to resist; it is not a reflex
  test. Successful restraint leaves the decision to Lavinia, who never knows
  about the cursor or Observer Pressure.
- **Host boundary:** The future mechanism requires a separately owned exception
  surface. It does not make ordinary scenery clickable, turn the Room-Owned
  Aperture into an inspection field, or introduce dialogue choices.
- **Current behavior:** Existing runtime routing and playback remain unchanged
  and presently reachable through the current progression without this special
  cursor grammar. No substitute prompt or result selector appears. This
  register neither defines nor certifies canonical Observer qualification.
- **Reopen only when:** The real-pointer relationship, non-pointer input,
  timing, restraint success, pause/focus behavior, save/load, failure, and
  already-discovered-ending migration can be designed together.
- **No current scaffold:** No fake-cursor node, hidden timer, restraint state,
  input interceptor, accessibility narration, or Observer-only aperture branch
  is added now.

### 4.3 `future_ui.visual_anomaly_variant_generator`

- **Status:** `deferred`.
- **Preserved future intent:** Randomness is a lawful part of the universe. A
  future visual anomaly system may use a profile-aware unseen-first deck of
  eligible authored variants. Once selected, the exact variant is frozen for
  the scene and exact restoration. A witnessed variant may re-enter only after
  every other eligible variant in its closed deck has been witnessed.
- **Epistemic boundary:** Variants present observable evidence without naming an
  anomaly, explaining a cause, displaying a rarity, or assigning meaning. Local
  events remain physically possible and globally unresolved.
- **Current behavior:** Scene surfaces, friend art, placements, captions, and
  objects use their current authored deterministic projection. No anomaly or
  random generator participates in v1 scene publication.
- **Reopen only when:** The base scene host is stable and a dedicated pass can
  decide eligible evidence classes, exact deck identity, selection, persistence,
  replay, failure, accessibility boundaries, and abnormality budgets.
- **No current scaffold:** No RNG call, seed, weight, variant-deck field,
  anomaly tag, save branch, icon, status copy, or fallback is added now.
- **Cross-reference (2026-09-12):** The operating-system shell now has a
  separately owner-approved drift family, the Drift Deck in
  `spec.instrumentarium_drift_deck_all_input_and_week_tint_amendment`. That
  amendment neither promotes nor retires this entry: it governs the desktop
  shell and its apps only, and this entry continues to preserve the
  scene-aperture anomaly generator as `deferred`. Section 3's no-scaffold
  clause continues to bind the aperture; for the shell drift family it is
  superseded only once that amendment's implementation is separately
  authorized.

### 4.4 `future_ui.non_narrative_avatar_photo_frame`

- **Status:** `deferred`.
- **Preserved future intent:** An avatar or photo-frame treatment may be
  reconsidered for a future, explicitly named non-narrative consumer. Only the
  possibility is preserved; no shape, content, identity law, or destination has
  been accepted.
- **Current behavior:** Canonical witnessed scenes show only the current scene
  background and the finished art of friends physically present in that scene.
  Angela receives no scene art, frame, slot, gap, vacancy token, or missing icon.
- **Reopen only when:** The owner identifies the exact non-narrative consumer and
  the factual purpose of the frame.
- **No current scaffold:** No avatar component, picture slot, profile field,
  missing-picture icon, default silhouette, or reserved layout space is added.

### 4.5 `future_ui.post_v1_aperture_refinements`

- **Status:** `deferred`.
- **Preserved future intent:** Later scene-art passes may separately consider
  additional registered camera coordinates, close material plates, richer
  authored pose or expression sets, foreground architectural occluders,
  restrained ambient motion, expanded room-surface states, or irregular room
  frames. This grouped entry is an index of possibilities, not approval of any
  individual technique.
- **Current behavior:** The initial Room-Owned Aperture remains deliberately
  simple, static, and authored. It does not generate composition, move toward a
  speaker, react to relationship or Observer state, or reserve geometry for a
  future effect.
- **Reopen only when:** One named refinement solves a demonstrated canonical-shot
  need that the simple host cannot truthfully present. Each materially distinct
  refinement receives its own design rather than one bundled expansion.
- **No current scaffold:** No extra camera, detail pane, mask, animation system,
  shader, pose library, automatic layout, or irregular-host compatibility path
  is added now.

### 4.6 `future_ui.special_ending_visual_reconciliation`

- **Status:** `deferred`.
- **Preserved future intent:** Hospital and ordered-ending content that depends
  on reordered present-tense flashes, treatment-room material, or other unusual
  shot structure requires a later canonical-shot audit. Angela's no-art law
  remains absolute: a beat requiring visible Angela body, hand, reflection, or
  shadow must be truthfully restaged through the room, an object, or another
  visible body, or that exact shot remains blocked pending owner-approved design.
- **Current behavior:** Existing runtime routing and playback remain unchanged.
  The simple host does not fabricate a flash, substitute incorrect art, omit a
  required public fact, or treat an unavailable composition as proof of an
  ending's meaning. A future Room-Owned Aperture composition that cannot obey
  Angela's no-art law blocks that exact shot's production support, not the
  ending route itself.
- **Reopen only when:** Hospital and ending shot inventories are available for a
  read-only feasibility ledger and one bounded visual exception pass.
- **No current scaffold:** No Angela fragment, generic CG, flash player, extra
  camera, legacy-host route, or silent content omission is added now.

## 5. Explicit exclusions

### 5.1 Audio

Audio is outside this UI register. The Acoustic Memory Atlas and every music,
ambience, Foley, voice, TTS-ducking, audio-anomaly, or audio-persistence question
are ignored by this artifact. No audio item is copied, summarized, promoted,
retired, or reconciled here.

### 5.2 Story and game mechanics

This register does not create or change dialogue, endings, route qualification,
relationship state, Hospital causes, Minesweeper results, evidence canon, or
Observer meaning. It records only the current UI deferral boundary around named
future presentation mechanisms.

The mismatch between presently reachable runtime playback and the canonical
Observer-language qualification gate is a separate route/canon reconciliation.
This UI register records neither side as having silently superseded the other.

### 5.3 Work tracking and implementation plans

Beads, roadmaps, implementation plans, release phases, task status, and code
ownership remain outside this register. A deferred entry is not work-ready and
must not be copied into a task tracker as if its design were complete.

## 6. Historical-document boundary

The disposable August 13-14 visual atlas documents remain historical evidence.
They are not rewritten to absorb this register, and their prototype markup does
not become current or future implementation law.

Later authority reconciliation may create one separate crosswalk recording
`retained`, `superseded`, or `deferred` relationships among historical and
current design documents. That crosswalk must link to this register rather than
copying its entries.

## 7. Register verification

Any later edit to this register must verify that:

- every added entry records a direction explicitly approved for future
  consideration;
- current behavior and preserved future intent remain distinguishable;
- each entry names a reopening condition and its prohibited current scaffold;
- no entry claims implementation authorization or a release commitment;
- promoted entries link one separately approved successor specification;
- retired and promoted history remains visible;
- audio remains excluded;
- Observer mechanics remain distinct from dialogue choices and Minesweeper
  agency; and
- deferral of special presentation never silently disables a currently
  reachable ending.

## 8. Current completion boundary

This register is complete as a design artifact when the owner approves its
written wording. That approval preserves the deferred directions and the
promotion law only. It does not request an implementation plan.

After written review, design exploration may return to the ordinary Hospital
and ordered-ending UI exceptions. Future-register work need not interrupt that
exploration again unless the owner explicitly reopens one named entry.
