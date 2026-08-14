# Haunted Instrumentarium: Audio Production and Implementation Manual

**Status:** Written from user-approved Design Gates 1–4; awaiting written-specification review

**Date:** 2026-08-14

**Target:** Godot 4.6.3, initial Windows release

**Artifact class:** Normative private production manual and implementation design

**Authorization boundary:** This document does not authorize audio acquisition, audition, editing, import, runtime implementation, or release by itself

**Supersedes:** Acoustic Memory Atlas: Audio Implementation and Asset-Curation Design for all audio decisions after this manual is accepted

## 1. Purpose and authority

This manual defines how music, ambience, Foley, evidence sounds, interface
feedback, restrained human nonverbal material, silence, system text-to-speech,
Save/Load memory, and post-ending audio must work in the adult pixel-art
romantic psychological and supernatural horror visual novel.

It converts the approved creative direction into one production contract:

> The audio is the story's memory of itself. It may misremember acoustic
> presentation. It may never contradict a committed physical fact, contribute
> evidence for an unproved fact, or disclose hidden truth.

The manual is intentionally self-contained for audio production decisions. A
future researcher, editor, mixer, programmer, tester, or agent should be able to
use it without reconstructing the preceding interview. It remains subordinate
to canon; “standalone” does not mean that audio may redefine story truth.

The authority spine locked for this revision is:

1. story/01-core-story-bible.md;
2. story/03-seven-day-production-map.md;
3. story/05-canon-amendments-2026-07-19.md;
4. docs/design/2026-08-07-seven-day-dialogic-flow-design.md;
5. docs/design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md;
6. docs/design/2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md;
7. docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md;
8. docs/design/2026-08-12-settings-preferences-ui-ux-amendment.md; and
9. this manual for audio-specific production behavior.

Within the same tier, a document with an explicit supersession statement wins;
otherwise the later accepted date wins. This manual becomes accepted authority
only after written-specification review. On that acceptance it is the later,
targeted audio/accessibility amendment for the exact conflicts in Section 1.1;
the Settings amendment continues to govern every clause not named there. An
unresolved same-tier conflict stops audio planning and returns to the user. A
later canon or design amendment does not silently rewrite this manual: the
manual must be revised, reviewed, and given a new plan revision.

Where authorities conflict, use this order:

1. the locked story and canon authorities above;
2. the locked accepted design authorities above, except for the exact Settings
   clauses explicitly superseded in Section 1.1 after this manual is accepted;
3. this manual for audio-specific behavior and those exact targeted amendments;
4. the research ledgers for evidence, never for canon; and
5. current code only as an implementation fact, not as authority over an
   accepted design.

The words MUST, MUST NOT, SHOULD, SHOULD NOT, and MAY are normative. A
creative or technical production exception requires a written reason, evidence,
and user approval. No ordinary exception may waive law, controlling licence
terms, third-party rights, attribution, distribution restrictions, the no-AI
provenance rule, or the separate authorization boundary between research,
acquisition, playback, editing, runtime integration and shipping.

### 1.1 Targeted Settings supersession ledger

Upon acceptance, this manual explicitly amends only the following clauses of
`docs/design/2026-08-12-settings-preferences-ui-ux-amendment.md`:

1. **Section 5.6, Closed persisted vocabulary** is extended by exactly three
   fields: `audio.output_mode` with `stereo | mono`, default `stereo`;
   `accessibility.sound_detail_text` with `story_relevant | off`, default
   `story_relevant`; and `reading.lower_background_during_narration` Boolean,
   default `true`. Its explicit validation and rendering allowlist must include
   these fields and no implicit schema reflection.
2. **Section 9.3, Caption guarantees**, and **Section 15.6, Invariants, not
   toggles**, are superseded only where they categorically ban a non-speech
   caption stream or visual-audio-evidence control. Section 15.2 of this manual
   permits the narrower, non-canonical Sound Detail Text presentation and
   governs its limits. Dialogue visibility, no audio-only evidence, and every
   other guarantee remain unchanged.

The Settings amendment's Read Aloud rates remain Slow 0.8, Normal 1.0 and Fast
1.2. Its no-in-game-voice-picker law also remains unchanged: compatible voice
selection is system capability resolution, not a persisted choice. No other
Settings clause is superseded.

## 2. Scope and non-goals

### 2.1 In scope

- artistic purpose, style, restraint, and knowledge boundary;
- music, ambience, material Foley, evidence, anomaly, UI, gameplay, human
  nonverbal texture, and authored silence;
- the thirty-five commissioning roles;
- scene, day, event, fragment, ending, menu, replay, Save, Load, Pause, focus,
  and post-ending placement;
- exact legal, provenance, anti-AI, attribution, acquisition, edit, import,
  catalogue, and release gates;
- Godot bus, player, pool, resolver, transaction, persistence, and TTS design;
- mono output, sound-detail text, muted-play equivalence, comfort, loudness,
  repetition, and device testing;
- current implementation drift and the clean replacement boundary; and
- the future approval sequence for research, acquisition, audition,
  implementation, and shipping.

### 2.2 Out of scope

- composing, recording, generating, synthesizing, cloning, or AI-generating
  music or sound effects;
- lyrical singing or recorded character voice acting;
- downloading, purchasing, editing, importing, or integrating an asset without
  a separately approved acquisition step;
- adding narrative facts, diagnoses, supernatural explanations, relationship
  facts, routes, or endings;
- backward compatibility for the unshipped legacy audio model;
- promising a final mix before real assets have survived audition; and
- claiming medical safety from digital audio measurements.

Existing audio may be edited or arranged only when the exact license permits
the exact change. A weak substitute is worse than authored silence.

## 3. Project identity and creative north star

The game is tender and poisonous, playful and doomed, ordinary and
supernaturally uncertain. Horror is subtle, elegant, dreamlike, surreal, noir,
tense, intimate, uncomfortable, and occasionally dryly ridiculous. It does not
depend on volume, pain, gore, or a broken-game performance.

The governing equation is:

- **Tenderness:** ordinary detail heard closely.
- **Horror:** ordinary detail arriving too early, too late, without its
  companion, or after it should have become impossible.
- **Absurdity:** a system handling emotional catastrophe with impeccable
  procedural politeness.

The result is called the **Haunted Instrumentarium**, built on the approved
**Acoustic Memory Atlas**. Rooms and objects perform first. Music is a rare
instrument within that theatre, not wallpaper placed over it.

### 3.1 Reference lenses, not imitation targets

- Robert McKee, John Truby, Syd Field, USC Eight Reels, and five-minute
  sequence thinking inform where acoustic states turn. They do not require a
  cue at every beat.
- Alain Robbe-Grillet informs exact objects, surfaces, repetitions, and
  inspectable incompatibilities.
- Roland Barthes informs unstable authorship and multiple readings, not a
  hidden symbol dictionary.
- Mark Fisher informs institutional uncanniness and the ordinary world
  continuing past emotional rupture, not sonic pastiche.
- Masaaki Yuasa informs elastic tonal collision and pleasurable absurdity,
  not copied style or frantic loudness.
- DDLC, Yume Nikki, and Ib are mood references only. No melody, asset,
  arrangement, signature sound, or recognizable imitation may be copied.

Sound must remain concrete enough to resist affectation. A clasp is a clasp
before it is a metaphor. An omitted kettle click is first a missing physical
event, not a puzzle key.

The four recurring route symbols remain practical materials rather than
leitmotifs: astronomy is motors, switches and night equipment; literature is
books, paper and annotation; music is visible rehearsal and playback;
calculation is keys, accepted commands and restrained interface feedback. None
receives a melody that labels a character or route.

The recurring material palette is institutional air; paper and control; body
and rehearsal; care and preparation; threshold and travel; fragile music
islands; and negative space.

### 3.2 Hard aesthetic constraints

- The game is rarely acoustically empty. It is often musically silent.
- Silence must feel inhabited.
- Ten percent music coverage is the commissioning aim. Twenty percent is the
  hard ceiling across every reachable authored terminal trace and repeatable
  cycle at the fastest valid presentation clock. Coverage counts scheduled
  music-island occupancy, not audibility after gain, mute, ducking or device
  loss. Numerator time includes every diegetic, authorial, post-ending, and menu
  music command while it is scheduled active. Denominator time includes all
  story and meta-surface time at the locked clock; only Universal Pause,
  operating-system suspension, and user-idle dwell are excluded from both
  numerator and denominator. No menu can hide music in an excluded interval.
  The implementation plan must freeze a versioned reachability manifest, prove
  that every reachable transition is covered, enumerate repeatable cycles
  separately, and lock the presentation clock before any production asset is
  integrated. A reachable path omitted from that proof blocks acceptance.
- Absolute silence appears at most twice and only briefly.
- Every beat has exactly one authored AudioSalienceClass: ORDINARY,
  RELATIONSHIP_SPOTLIGHT, or HEIGHTENED. Narrative labels may overlap, but the
  audio class may not. If a beat is both a relationship spotlight and dream,
  pivotal, fragmentary, or ending material, the strictest numerical cap wins
  and the class is RELATIONSHIP_SPOTLIGHT.
- ORDINARY permits at most one peripheral anomaly.
- RELATIONSHIP_SPOTLIGHT permits at most one anomaly total; if relational, it
  replaces rather than adds to the peripheral allowance.
- HEIGHTENED is reserved for dream, pivotal, fragment, or ending beats and
  permits at most two anomalies total, at most one of which may be relational,
  only when both are explicitly authored in its plan. No beat has a larger
  budget.
- Only one cue should request conscious attention at a time.
- Human breath, humming, or choir-like material begins at zero and may survive
  in at most two moments across the complete game. A third requires a named
  scene, written justification, and explicit user exception.
- Most classical material is visibly diegetic.
- Post-ending memory begins by altering ambience. Music is the rarer second
  choice.
- No continuous text blips.
- No jump-scare-shaped volume ambush.
- No chiptune nostalgia, trailer braam, lush romance wash, stock ominous drone,
  stereotypical evil violin, wedding shorthand, or automatic music-box horror.
- No cartoon boing, meme sound, canned laughter, or borrowed internet
  shorthand.
- No Hong Kong identity through copied transit chimes, branded announcements,
  broadcasts, or stereotypes.
- No intelligible environmental speech, offscreen speaking character, or
  recorded announcement may introduce a person or story fact.

Preferred musical colors are fragile piano, small human chamber performance,
unsteady breath between notes, restrained nonverbal vocal texture, and faint
electroacoustic residue whose origin remains uncertain. Human imperfection is
welcome; coercive pathos is not.

## 4. The audio narrator and its knowledge boundary

The audio narrator is not Angela, Lavinia, Priscilla, Sylvia, the
supernatural, the interface, or an omniscient composer. It is the story's
memory of itself.

It MAY:

- support the visible atmosphere;
- emotionally counterread a visible moment;
- return a familiar physical texture imperfectly;
- omit a previously ordinary companion sound;
- present the remembered sound of an ordinary action in a subtly wrong order
  when the real visible action and consequence remain unambiguous;
- foreshadow a kind of feeling without naming a fact;
- preserve or alter a neutral approved memory variant only after its source
  ending has been visibly completed and durably committed, and only on one of
  the closed post-completion meta surfaces defined in Section 8.1; and
- use harmless deterministic texture variation that cannot change meaning.

It MUST NOT:

- read raw affection, desire, jealousy, relationship tier, or private intent;
- choose a cue because of an uncommitted route or future ending;
- identify or corroborate a true path, culprit, medical condition, diagnosis,
  prognosis, treatment truth, physiological cause, supernatural presence,
  agency, existence, mechanism, or authorship;
- imply an absent character is physically nearby;
- make a hover, preview, focus state, or rejected command into story evidence;
- create new witnessed or Observer evidence through replay, Settings, History,
  Save, Load, or repeated playback;
- contradict a committed physical fact; or
- turn technical failure into fiction.

Musical contradiction is an emotional counterreading, never factual testimony.
Audio may misremember acoustic presentation. It may not invent, corroborate, or
weight evidence for truth. A completed-profile memory may affect only an
approved post-completion presentation surface; it is never a resolver input
before completion, never names an ending in an asset ID, and never asserts that
one completed ending was truer or more important than another.

## 5. Cue taxonomy

### 5.1 Texture

Texture provides credible environmental continuity: room air, maintained
equipment, distant machinery, sheltered rain, public-room density, or a finite
nonlooping bed. Texture may be continuous, intermittent, deliberately omitted,
or harmlessly varied.

Environmental texture is the default background score, but it remains on the
Ambience bus. Calling it score does not grant it musical privilege.

### 5.2 Signature

A signature is a rare material habit of a physically present character. It is
not a leitmotif and never fires from a hidden relationship value.

- Angela: equipment hum, motors, keys, switches, instrument controls.
- Priscilla: paper, ceramic, clasps, measured footsteps, handled doors.
- Lavinia: fabric, floor contact, rehearsal resonance, held stillness, and
  bounded breath only if approved.
- Sylvia: badge clip, kit zipper, packaging, kettle, chair, prepared supplies.

A signature must remain credible when the player has forgotten its earlier
appearance. It cannot function as a secret character detector.

### 5.3 Evidence

Evidence is an audible event with an established source and a simultaneous
physical, visual, or natural textual equivalent. Its identity is deterministic.
History and Load do not replay it as newly witnessed.

### 5.4 Anomaly

An anomaly is a wrong remembered order, omission, altered decay, physically
inspectable incompatible companion, or incompatible return. It is rare,
deterministic, bounded by the scene budget, and may not serve as evidence,
corroboration, probability weight, or confirmation for any hidden, medical, or
supernatural fact.

The plan records every anomaly and omission explicitly. Reloading never rerolls
one. Every perceptibly wrong omission, authored stripped-silence event, or
authored absolute-silence event is an anomaly debit and consumes the same beat
budget as an audible anomaly. Base negative space and a factual technical
fallback are not anomaly debits because they are not presented as fiction;
neither may be shaped to imply meaning. Any sound designed principally to make
the player flinch is rejected even when its physical source is visible.
Inspectability is required for an anomaly; it never licenses a jump scare.

### 5.5 Music island

A music island is bounded and authored. Its plan states whether it is diegetic
or authorial, what visible or semantic boundary admits it, when it yields, and
what silence or room layer follows it.

Music must not explain whom to love, whom to fear, which choice is correct, or
which ending is privileged.

### 5.6 Authored silence

- **Room-held silence:** conversation or action stops while credible space
  remains.
- **Stripped silence:** one expected layer disappears while another physical
  layer remains.
- **Absolute silence:** the game mix is removed. It is brief, rare, and cannot
  conceal an essential event.

The first sound returning from absolute silence requires a separately authored
gentle entry envelope. A modest peak can still feel violent after nothing.

## 6. Scene grammar

Every scene or semantic beat resolves to one complete audio plan:

1. one room texture, finite bed, or explicit silence state;
2. established physical sources;
3. zero to two foreground material actions;
4. one exclusive AudioSalienceClass, its exact anomaly budget, and explicit
   omission debits;
5. an optional music island;
6. deterministic memory and horizontal variants;
7. entry, interruption, concurrency, and exit laws;
8. a curated Save/Load resume anchor; and
9. a natural non-audio equivalent for every essential event.

Supported horizontal families are:

- base;
- quiet altered;
- post-ending; and
- witnessed echo.

Witnessed echo replaces raw affection-flag micro-SFX. It may exist only after
the audience has visibly witnessed and the canonical owner has committed the
relevant action.

The scene may use harmless environmental variation, but no variation may
change evidence, anomaly, omission, signature eligibility, music identity,
choice eligibility, interpretation, or state.

## 7. Commissioning and research role register

A role is a family of production needs, not a promise to ship one file. One
source may yield several separately registered derivatives only when the
license allows it and every derivative has an explicit purpose. One file may
not masquerade as several unrelated physical objects.

Family-level completion is never inferred from one convenient file. Every
enumerated member receives its own exact cue ID and acceptance result. In
particular, foley.chair_ceramic_kettle expands to separately reviewed chair,
ceramic, and kettle cues, and foley.badge_zipper_packaging expands to separately
reviewed badge, zipper, and packaging cues. A family is incomplete until each
required member is satisfied or the user explicitly waives that member because
the corresponding authored action was removed.

### 7.1 Music roles

| Role ID | Commissioning purpose |
|---|---|
| music.fragile_authorial | Rare suspended threshold; fragile rather than explanatory |
| music.social_diegetic_classical | Visible public or social playback that continues indifferently |
| music.rehearsal_playback_classical | Visible practical rehearsal source with credible stop and residue |
| music.post_ending_memory | Short completed-profile memory; ambience remains preferred |
| music.dream_noir_suspension | Rare dream or noir suspension without stock ominous language |

### 7.2 Ambience roles

| Role ID | Commissioning purpose |
|---|---|
| ambience.bedroom_night | Maintained interior, device or window detail, no cosy wallpaper |
| ambience.university_day | Ordinary inhabited campus work without identifying announcements |
| ambience.university_late_empty | Maintained but thinned institutional space |
| ambience.conservatory_rehearsal | Credible room and equipment residue around visible practice |
| ambience.campus_social | Restrained density without intelligible offscreen characters |
| ambience.hospital_ordinary | Air, distant workflow, fabric and equipment without monitor melodrama |
| ambience.sheltered_transit_rain | Covered exterior threshold, rain and material travel detail |

### 7.3 Material and Foley roles

| Role ID | Commissioning purpose |
|---|---|
| foley.paper_folder | Programme tables, forms, folders, controlled alignment |
| foley.book_page_annotation | Cover, page, receipt and annotation handling |
| foley.clasp_small_mechanical | Exact small clasp or closure, not a generic impact |
| foley.keys_visible | Only keys visibly handled in the scene |
| foley.keyboard_instrument_control | Computer or instrument controls with exact material identity |
| foley.chair_ceramic_kettle | Quiet table and care actions; split into exact cue IDs at runtime |
| foley.fabric_floor_weight | Bounded body, rehearsal and load-shift actions |
| foley.badge_zipper_packaging | Prepared supplies; split into exact cue IDs at runtime |
| foley.equipment_motor | Maintained equipment, astronomy and institutional mechanisms |
| foley.umbrella_luggage | Return and sheltered-transit thresholds |
| foley.door_handled | Visible, physically handled door only |
| foley.device_notification_physical | Legitimate device event with visible record or consequence |

### 7.4 UI and gameplay roles

| Role ID | Commissioning purpose |
|---|---|
| ui.accept | Restrained confirmation |
| ui.cancel_back | Dry reversible retreat |
| ui.notification | Ordinary, non-supernatural notice |
| ui.save_load_success | Trustworthy operation feedback |
| ui.rejection_error | Factual refusal without punishment or horror |
| gameplay.minesweeper_reveal | One cue per accepted reveal command, not every cell |
| gameplay.minesweeper_mark | Distinct but quiet mark feedback |
| gameplay.minesweeper_result | Bounded result without victory or failure fanfare |

### 7.5 Human nonverbal roles

| Role ID | Commissioning purpose |
|---|---|
| human_nonverbal.breath | Rare, bounded, human-provenanced breath; zero is preferred |
| human_nonverbal.hum | Rare, nonlyrical human hum; never a character voice substitute |
| human_nonverbal.choir_like | Sparse human texture; authored silence is the default candidate |

### 7.6 Atomic commissioning manifest

The following is the normative family-to-member manifest. Each listed member
is an exact cue ID with its own evidence, audition and acceptance state. A role
family is mechanically complete only when every listed member is satisfied.
Optional music and human-nonverbal families may instead carry one explicit
AUTHORED_SILENCE decision for the whole family; that decision does not satisfy
any physical-core family.

| Role family | Required exact member cue IDs |
|---|---|
| music.fragile_authorial | music.fragile_authorial.threshold |
| music.social_diegetic_classical | music.social_diegetic_classical.public_playback |
| music.rehearsal_playback_classical | music.rehearsal_playback_classical.rehearsal_source |
| music.post_ending_memory | music.post_ending_memory.memory_island |
| music.dream_noir_suspension | music.dream_noir_suspension.suspension |
| ambience.bedroom_night | ambience.bedroom_night.base_loop; ambience.bedroom_night.quiet_variant |
| ambience.university_day | ambience.university_day.base_loop |
| ambience.university_late_empty | ambience.university_late_empty.base_loop; ambience.university_late_empty.quiet_variant |
| ambience.conservatory_rehearsal | ambience.conservatory_rehearsal.base_loop; ambience.conservatory_rehearsal.equipment_residue |
| ambience.campus_social | ambience.campus_social.base_loop |
| ambience.hospital_ordinary | ambience.hospital_ordinary.base_loop; ambience.hospital_ordinary.quiet_variant |
| ambience.sheltered_transit_rain | ambience.sheltered_transit_rain.base_loop; ambience.sheltered_transit_rain.thinned_variant |
| foley.paper_folder | foley.paper_folder.paper_sheet; foley.paper_folder.folder; foley.paper_folder.alignment |
| foley.book_page_annotation | foley.book_page_annotation.book_cover; foley.book_page_annotation.page_turn; foley.book_page_annotation.receipt; foley.book_page_annotation.annotation_tool |
| foley.clasp_small_mechanical | foley.clasp_small_mechanical.clasp |
| foley.keys_visible | foley.keys_visible.handling |
| foley.keyboard_instrument_control | foley.keyboard_instrument_control.computer_key; foley.keyboard_instrument_control.instrument_control |
| foley.chair_ceramic_kettle | foley.chair_ceramic_kettle.chair; foley.chair_ceramic_kettle.ceramic; foley.chair_ceramic_kettle.kettle |
| foley.fabric_floor_weight | foley.fabric_floor_weight.fabric; foley.fabric_floor_weight.floor_contact; foley.fabric_floor_weight.weight_shift |
| foley.badge_zipper_packaging | foley.badge_zipper_packaging.badge; foley.badge_zipper_packaging.zipper; foley.badge_zipper_packaging.packaging |
| foley.equipment_motor | foley.equipment_motor.start; foley.equipment_motor.sustain; foley.equipment_motor.stop |
| foley.umbrella_luggage | foley.umbrella_luggage.umbrella_hardware; foley.umbrella_luggage.luggage_handling |
| foley.door_handled | foley.door_handled.handle; foley.door_handled.movement; foley.door_handled.latch |
| foley.device_notification_physical | foley.device_notification_physical.primary |
| ui.accept | ui.accept.primary |
| ui.cancel_back | ui.cancel_back.cancel; ui.cancel_back.back |
| ui.notification | ui.notification.primary |
| ui.save_load_success | ui.save_load_success.save; ui.save_load_success.load |
| ui.rejection_error | ui.rejection_error.rejection; ui.rejection_error.error |
| gameplay.minesweeper_reveal | gameplay.minesweeper_reveal.primary |
| gameplay.minesweeper_mark | gameplay.minesweeper_mark.primary |
| gameplay.minesweeper_result | gameplay.minesweeper_result.primary |
| human_nonverbal.breath | human_nonverbal.breath.primary |
| human_nonverbal.hum | human_nonverbal.hum.primary |
| human_nonverbal.choir_like | human_nonverbal.choir_like.primary |

The **physical core** means all material/Foley members and the location
ambiences required to make bedroom, university, hospital, rehearsal, campus
social, and sheltered-rain scenes physically credible. Its repair order is:

1. exact clasp, umbrella, luggage, badge, zipper and packaging;
2. hospital and sheltered-rain ambience;
3. the remaining material/Foley families;
4. the remaining foundational ambience;
5. UI and gameplay;
6. music; and
7. human nonverbal material last.

The first acquisition batch may contain physical-core candidates only. The
PHYSICAL_CORE_CLOSED gate is reached only when every required physical-core
member in the manifest has an exact AUDITION_PASSED candidate or a written
member-level user waiver that removes its corresponding authored action or
location need. Review without closure, a rejected candidate, a family-level
waiver, or a merely available source does not pass the gate. No music or human
batch may be proposed before PHYSICAL_CORE_CLOSED. Pivotal roles may receive
one daring wildcard candidate, never automatic approval.

## 8. Placement atlas

### 8.1 Global surfaces

PresentationSurfaceId is a closed enum, not an arbitrary string. Its complete
initial set is META_FIRST_LAUNCH_TITLE, META_POST_ENDING_TITLE, STORY_BEDROOM,
STORY_CONTACTS, STORY_SCHEDULE, STORY_SHOP, META_BACKUP_LOAD, META_SETTINGS,
STORY_MINESWEEPER, OVERLAY_PAUSE, META_GALLERY_REPLAY, STORY_REHEARSAL,
STORY_UNIVERSITY, STORY_CAMPUS_SOCIAL, STORY_HOSPITAL, and
STORY_SHELTERED_TRANSIT. Only META_POST_ENDING_TITLE, META_BACKUP_LOAD, and
META_GALLERY_REPLAY may receive eligible completed-profile memory IDs. Adding a
surface or changing that allowlist is a reviewed schema change, never runtime
data.

STORY_BEDROOM is always an in-run story surface. Starting or loading a new run
clears completed-profile memory from its request even when the profile already
contains completed endings. There is no combined “bedroom and desktop” surface
and no generic “menu” surface through which memory can leak.

| Surface | Base treatment | Music and memory law |
|---|---|---|
| META_FIRST_LAUNCH_TITLE | Faint maintained room or equipment presence, or authored silence | No mandatory title theme and no memory anomaly |
| META_POST_ENDING_TITLE | Recognizable base with one deterministic alteration | Rare short music island only from durably completed neutral profile memory |
| STORY_BEDROOM | Computer, window, room and device detail | Usually no music; no completed-profile memory |
| STORY_CONTACTS | Desktop bed and restrained notification | No continuous music, profile memory, or altered message order |
| STORY_SCHEDULE | Quiet controls and accepted-command feedback | Eligibility and profile memory never become audible |
| STORY_SHOP | Dry confirmation and rejection | No jingle, fictional failure, or profile memory |
| META_BACKUP_LOAD | Trustworthy mechanical feedback | A neutral completed-profile memory tail may alter; command meaning may not |
| META_SETTINGS | Underlying context remains | Only deliberate registered samples; no story facts or profile memory |
| STORY_MINESWEEPER | Dry reveal, mark, rejection and result cues | One primary cue per accepted command; normally no music |
| OVERLAY_PAUSE | Exact frozen source scene | No pause theme or profile memory |
| META_GALLERY_REPLAY | Registered replay plan chosen from visibly unlocked content | Neutral completed-profile memory may frame replay; no fresh witnessing |
| STORY_REHEARSAL | Credible room and equipment residue around visible practice | No hidden-state lookup, profile memory, or evidence reroll |
| STORY_UNIVERSITY | Maintained institutional work | No identifying announcements or profile memory |
| STORY_CAMPUS_SOCIAL | Restrained social density | No intelligible offscreen facts or profile memory |
| STORY_HOSPITAL | Air, fabric, chair and restrained workflow | Normally no music; no monitor melodrama or profile memory |
| STORY_SHELTERED_TRANSIT | Covered rain and material travel detail | No copied transit identifiers or profile memory |

### 8.2 Seven-day progression

- **Day 1 — administrative uncertainty:** paper, copying, keyboards and
  equipment establish the institution. Lavinia's premature roster entry gets
  no abnormal sting.
- **Day 2 — return and transit:** luggage, umbrella hardware, sheltered rain,
  returned seats and ordinary device cues support return. Priscilla's
  premature reply receives no supernatural notification.
- **Day 3 — repetition:** familiar rooms carry the change. No compulsory new
  anomaly or score is added merely because relationships are clearer.
- **Day 4 — preparation becoming uncomfortable:** packaging, welfare supplies,
  forms, rehearsal adjustment and ordinary hospital air carry the day. The
  prefilled slip remains an object, not a horror cue.
- **Day 5 — utility running out:** activity gradually stops. Packed objects,
  final clasps, chairs and doors lead into room-held silence. One visibly
  sourced social or rehearsal music island may survive.
- **Day 6 — implication:** equipment and final checks dominate. The location
  prompt uses the normal notification family; its visible record carries
  importance.
- **Day 7 — public performance:** the university becomes more inhabited, not
  louder or more cinematic. Reception or rehearsal source music may exist.
  The decisive action receives no route fanfare.

### 8.3 Event laws

| Event | Foreground material | Music and silence law |
|---|---|---|
| The Programme Table | Paper alignment, folder, restrained room activity | No cue for the premature name |
| The Borrowed Book | Cover, page, receipt and annotation | Quiet physical bed; no sentimental score |
| The Public Question | Public-room air, prompt card and equipment | No success or failure music |
| No Task Left | Final clasp, packed material and chair | Activity ends into room-held silence |
| The Returned Seat | Chair, equipment settings and ordinary message | No return theme |
| Borrowed Gravity | Floor, shoes, fabric and bounded breath | No erotic exaggeration or pain cue |
| After the Music | Social room and visible playback | Source music ends plausibly into room sound |
| Before It Hurts | Pace, fabric, load adjustment and threshold | No diagnosis or crisis sting |
| Exactly on Time | Equipment handoff, badge and packaging | Hospital variant remains ordinary |
| A Quiet Table | Ceramic, kettle, chair and public room | No cosy score validating a prediction |
| The Caretaker's Break | Packaging, cup, chair and handoff | Reciprocal care remains unscored |
| Contingency | Kit zipper, paper slip and supplies | No ominous emphasis on prefilled information |
| Three Versions of the Sky | Paper, controls and visible playback | Classical source starts and stops visibly |
| After the Run-Through | Floor, fabric, transport and key | Rehearsal residue yields before negotiation |
| Day 2 Umbrella Pickup | Luggage, latch and threshold | No romantic theme or pair-counter signal |

### 8.4 Fragments and endings

Past fragments have no shared memory theme. They use their physical material:
folder and overwritten page; room murmur, glass and name tag; key, ceramic and
kettle; correction paper, fabric and floor marking; or device residue without
recorded acting.

Thirteen catalogue identities do not produce thirteen themes. Canon labels
appear here only to make placement review complete; runtime plans and asset IDs
remain neutral.

| Catalogue identity | Audio law |
|---|---|
| Angela-Priscilla Sweet — Attend the Closing Reception | Inhabited room, paper and ceramic recede after Priscilla stops herself; no romantic validation |
| Angela-Priscilla Totally Dark — Attend the Closing Reception | The same physical family continues with less reciprocal space; no dominance or reward cue |
| Angela-Priscilla Observer — Verification | Interface and text prove two incompatible lines; audio may repeat ordinary capture material but never confirms cause |
| Angela-Lavinia Sweet — Wait by the Stage Door | Sourced rehearsal residue yields to exterior air and a directly asked boundary |
| Angela-Lavinia Totally Dark — Wait by the Stage Door | Floor, fabric and crisis aftermath remain bounded; no pain, jealousy, erotic, or reward cue |
| Angela-Lavinia Observer — Restraint | Withheld environmental excuse receives no sting; ordinary connection returns only when Lavinia visibly calls |
| Angela-Sylvia Sweet — Collect What Was Found | Returned objects, kit, packaging and deliberate placement retain physical separation |
| Angela-Sylvia Totally Dark — Collect What Was Found | The same material family becomes procedurally over-complete; no care-validation or surrender cue |
| Angela-Sylvia Special | Only visible badge, withdrawal, paper, interrupted objection and treatment-room material may reorder; no condition, means, cause, typist, intent extension, or supernatural inference |
| Priscilla-Lavinia Sweet — Counter-ending | Keys, transport, fabric and controlled distance support direct admission; no secret-couple theme |
| Priscilla-Lavinia Totally Dark — Counter-ending | The same credible objects remain; manipulation receives no proof-of-love sound |
| Priscilla-Lavinia Observer — Persistence | Duplicate key sounds require both visible keys and never decide origin, authenticity, agency, or cause |
| Alone — Complete the Final Observation | Astronomy controls, motors and intentional night room tone are complete rather than abandoned or punished |

The no-credits title return receives no credits cue. Only an eligible,
deterministic profile-memory variant may follow.

## 9. Legal and provenance gate

This manual is conservative production policy, not legal advice. A platform or
license family never approves an individual asset.

The supporting primary-source decision record is
[Audio Legal Source and Provenance Policy Audit](../../research/audio/2026-08-14-audio-legal-source-policy-audit.md).

### 9.1 Unambiguous lifecycle

The word APPROVED may not appear alone. Use exactly:

1. DISCOVERED;
2. CANDIDATE;
3. CONDITIONAL — ineligible for acquisition until every condition is resolved;
4. RESEARCH_VERIFIED;
5. ACQUISITION_APPROVED;
6. ACQUIRED_IDENTITY_VERIFIED;
7. AUDITION_PASSED;
8. EDIT_OR_PASS_THROUGH_APPROVED;
9. RUNTIME_APPROVED;
10. SHIP_APPROVED;
11. QUARANTINED;
12. REVOKED; or
13. REJECTED.

LEGAL REVIEW is a hold, not permission. Under the project's fail-closed rule,
an unresolved candidate is treated as rejected for acquisition and runtime
use. SHIP_APPROVED is a release decision, not permanent immunity: a credible
rights, provenance, attribution, security-of-distribution or licence-compliance
problem moves the asset immediately to QUARANTINED. REVOKED means it may not
return without a completely new evidence and approval chain.

### 9.2 License and source-family decisions

| Source or license | Project decision |
|---|---|
| Exact CC0 | Eligible after rights and provenance checks; voluntary credit retained |
| Exact CC BY 4.0 | Eligible with credit, source, license, changes and packaging or DRM review |
| Exact OGA CC0, CC BY 4.0 or OGA-BY 4.0 download | Eligible; the preview never substitutes for the licensed member. Legacy 3.0 variants remain held for exact legal review and are not acquisition-eligible by default |
| Kenney CC0 | Preferred legal baseline, not automatic aesthetic approval |
| Sonniss GDC member | Eligible under the exact bundle license with member and recordist identity |
| PeriTune through February 2026 | Conditional CC BY 4.0; exact date and human process required |
| PeriTune from March 2026 | Conditional under the current custom terms; permitted free format, embedding and human process required |
| Freesound exact CC0 or CC BY | Conditional on exact uploader or recorder chain and affirmative physical or human provenance |
| ZapSplat Standard or Basic | Conditional on named downloader, account tier, subscription state, download time, MP3 or entitled format, credit, embedded use and exact provenance |
| Mixkit SFX | Held until exact modification permission, named creator, affirmative human-process evidence, exact member identity and non-AI clearance are all unambiguous |
| Pixabay audio | Held for affirmative human provenance and whole-product legal review covering the game, store page, marketing, packaging and distribution context |
| FMA or ccMixter | Held and not search-eligible until a separate primary-source audit establishes exact commercial adaptation, attribution, provenance and distribution rules |
| CC BY-NC, NonCommercial or personal use | Rejected |
| CC BY-ND | Rejected because the production requires editing freedom |
| CC BY-SA, GPL or comparable copyleft | Rejected by project policy, not because commercial use is universally forbidden |
| Mixkit music | Rejected because its music terms prohibit video-game use |
| YouTube no-copyright upload, mirror, reupload or unclear royalty-free page | Rejected |

Every exact page and terms snapshot must be checked again at acquisition and
before release. Platform terms can change.

### 9.3 License fact is not provenance

The record separately clears:

1. the exact recording or master;
2. composition, edition, arrangement, transcription, completion or
   orchestration;
3. every performance and identifiable voice;
4. samples, impulse responses and derivative sources;
5. privacy, publicity, property, trademark and location restrictions; and
6. the project's no-AI rule.

For classical music, public-domain composition status clears only the
composition. A modern edition, arrangement, human performance and exact master
remain separate rights layers. Wikimedia Commons and IMSLP are file-level
catalogues, not blanket clearance. Musopen is discovery-only unless exact
creator-side evidence corroborates the file. Territorial uncertainty rejects
the file until resolved.

### 9.4 Human and anti-AI provenance

An absent AI tag is never proof of human creation. AI-training restrictions do
not prove how a file was made. Do not attempt to identify AI by listening.

- Physical field recording and Foley require a named recorder or creator, a
  credible real object, action, location or session account, and no contrary
  AI indicator.
- Designed UI and SFX require affirmative human process evidence, a named
  creator, exact member identity and no AI indicator. First-party hosting or a
  named pack alone is insufficient. Anonymous or process-unknown stock rows
  fail.
- Music, humming, choir, breath and human nonverbal material require
  affirmative human composer, performer and recordist provenance.
- An AI or GenAI label, model name, generation description, cloned or synthetic
  voice statement, or unresolved contradiction rejects the asset.
- AI artwork on an asset page is not itself proof about the audio, but it
  increases the need for exact process evidence.

Field recordings containing intelligible speech, patients, students, private
conversation, branded announcements, clinical identifiers, transit identity,
alarms or narrative-significant words are rejected even when the file claims a
permissive license.

### 9.5 Evidence record

Before acquisition review, every candidate row contains:

- exact title, creator, recorder, performers and uploader when different;
- direct asset page, exact downloadable member, original filename, archive and
  member path;
- controlling legal code or complete custom terms plus any human-readable deed
  or summary, license type and version, terms revision and retrieval date;
- exact publication date when it determines the license era, including every
  PeriTune candidate;
- commercial-game, modification, adaptation, format-conversion, embedding,
  redistribution, encryption, DRM and Content ID findings;
- exact attribution and change-notice requirements;
- exact composition, edition, editor, arranger, transcriber, completer,
  orchestrator, publication, performance, master, target-territory and
  third-party-rights findings when applicable;
- exact human-process or physical-recording evidence and AI check;
- proposed role, scene use, physical source and non-audio equivalent;
- permitted edit recipe;
- preliminary loop, mono, repetition, comfort and TTS risks; and
- current lifecycle status with a factual rejection reason when applicable.

After authorized acquisition, add the original SHA-256, byte length, embedded
metadata, archive license file, archive-member identity and exact match back to
the captured page. Account-conditioned sources also record the downloader
identity, account tier, subscription state, entitlement state and timestamp of
download.

### 9.6 Post-release incident response

A credible ownership claim, takedown, licence breach, newly discovered AI or
source contradiction, missing required credit, prohibited extraction, or other
rights defect immediately moves the exact asset and its derivatives to
QUARANTINED. The release owner then:

1. preserves the report, shipped hashes, evidence packet and affected build IDs;
2. suspends new distribution, promotion and build publication containing the
   asset while the claim is assessed;
3. activates the registered semantically neutral fallback or authored silence,
   never a meaning-changing substitute;
4. determines whether a factual attribution or packaging correction fully cures
   the issue under the controlling terms;
5. if not cured, marks the chain REVOKED, removes every runtime derivative,
   rebuilds, revalidates notices and distribution profiles, and publishes the
   corrected build through the platform's available update process; and
6. records the decision, dates, contacts, affected versions and residual limits
   on recall or correction.

Every patch, re-release, new storefront package and distribution-profile change
rechecks the controlling terms and incident ledger. A prior SHIP_APPROVED state
does not waive a later conflict.

## 10. Source, edit, runtime and attribution chain

The chain has four immutable logical layers. They need not be four different
byte files:

1. **Evidence and preserved original:** exact downloaded bytes, checksum,
   metadata, source and license evidence.
2. **Edit or pass-through decision:** permitted deterministic edits produce a
   lossless master with a human-readable recipe. When an already suitable Ogg
   or MP3 is approved unchanged, the record explicitly selects pass-through,
   reuses the preserved original hash, and records that no edit master exists.
3. **Runtime derivative:** one final game-ready encode with measured channel,
   sample-rate, duration, peak, loop and import settings.
4. **Semantic registration:** neutral asset ID, role, technical metadata,
   evidence-ledger ID and attribution-ledger ID.

Preserved originals and edit masters live in a controlled private vault outside
Godot's active resource tree and outside any public repository. Runtime bytes
may enter res://audio only after an exact redistribution and repository-
visibility decision. A trimmed, re-encoded, or pass-through derivative remains
licensed audio and is not made safe for public Git merely by being modified.
If the exact terms do not permit repository distribution, the binary stays in
a private artifact store and enters protected builds through an approved
injection step; the diffable catalogue, recipe, hash and import policy remain
in Git.

Each acquired asset receives a distribution_profile_id that fixes repository
visibility, build embedding, extraction protection, encryption or DRM,
attribution surface and raw-file access. If one build layout cannot satisfy all
selected licenses—for example an extraction-protection term and a prohibition
on effective technological restrictions—the incompatible candidate is
rejected or placed in a legally distinct package verified before shipping.

### 10.1 Permitted edits

Only when the exact license permits them:

- trim and selection;
- clean entry and exit fades;
- loop-seam construction;
- gain staging;
- gentle corrective EQ;
- removal of unusable leading or trailing noise;
- stereo narrowing or approved mono downmix;
- resampling and format conversion;
- one quieter horizontal derivative; and
- a composite whose every component and processing resource has independent
  clearance.

Every recipe records source hash, derivative hash, tool and version, channel
layout, sample rate, bit depth or bitrate, exact parameters and operator.

### 10.2 Forbidden edits

- generative extension or reconstruction;
- AI denoise or enhancement whose operation invents material;
- voice cloning, isolation used to evade rights, or synthetic performance;
- pitch randomization, time stretch, reversal, granular mutation or procedural
  regeneration at runtime;
- heavy rescue processing that disguises a poor source;
- an unlicensed convolution impulse response or hidden sample; and
- any change whose permission is argued from ambiguity.

Variation comes from separately approved alternates or deterministic plan
structure, not from mutating a source into false evidence.

### 10.3 Attribution

Attribution appears in title-hosted Settings and in THIRD_PARTY_NOTICES. Endings
do not become credits sequences.

The baseline display is Title / Creator or Performer / Direct Source / License
and Version / Changes. It is not an exhaustive legal template. The rendered
notice also preserves every supplied copyright notice, designated attribution
party, disclaimer notice, previous modification notice, current change notice,
and license link required by the controlling terms.

CC BY credit must not suggest endorsement. CC0 files receive voluntary creator
and source credit whenever known. Ship validation renders the exact notice from
the evidence record and compares it with the asset's controlling requirements.

## 11. Godot 4.6.3 import contract

Godot 4.6 imports WAV, Ogg Vorbis and MP3. Runtime files use lowercase neutral
snake_case names and exact catalogue paths. Embedded title or artist tags never
drive runtime selection.

### 11.1 Runtime formats

| Material | Runtime policy |
|---|---|
| Short UI, Foley, gameplay, evidence and human micro-cues | 16-bit PCM WAV; mono only when the approved derivative is genuinely mono |
| Long ambience and music from lossless masters | Ogg Vorbis through one final encode; quality selected by blind comparison |
| Existing suitable Ogg requiring no destructive edit | Import directly; do not recompress for uniformity |
| Existing MP3 with no better source | Import directly only for noncritical, nonlooping use after audition |
| Timing-critical MP3 or seamless MP3 loop | Prefer another source or authored silence |
| FLAC, M4A and other acquisition formats | Preserve in the private vault; do not place under res:// |

Do not upsample. Preserve native 44.1 or 48 kHz. Material above 48 kHz may be
reduced to 48 kHz as a recorded approved edit; it is never retained merely for
prestige. Leave the project mix rate at the Godot or operating-system default
unless measured implementation evidence justifies a project-wide change.

### 11.2 WAV import settings

- Compress Mode: PCM Uncompressed.
- Force 8 Bit: Off.
- Force Mono: Off; the derivative already has its approved channel layout.
- Force Max Rate: Off unless an explicit reviewed exception is recorded.
- Normalize: Off.
- Trim: Off.
- Nonlooping cue: Loop Mode Disabled, not Detect From WAV.
- Looping cue: Forward with reviewed sample-accurate Loop Begin and Loop End.
- Ping-Pong and Backward: prohibited unless a separately approved design
  explicitly requires them.

Godot 4.6 defaults WAV compression to lossy QOA, so PCM must be explicit.
Automatic normalization to a zero-decibel peak and automatic trimming would
destroy commissioning headroom or exact boundaries.

### 11.3 Ogg and MP3 import settings

- Nonlooping: Loop false and Loop Offset zero.
- Full-file seamless loop: Loop true and Loop Offset zero.
- Intro plus loop: Loop Offset equals the approved start in seconds.
- BPM and Beat Count remain zero unless beat-aware runtime behavior is
  deliberately adopted.
- Ogg and MP3 loop from one begin offset to the physical file end; they do not
  provide a separate loop end.
- Looping streams never emit a finished event.

A loop that cannot remain invisible becomes a long finite bed, a registered
transition to another bed, or inhabited silence.

### 11.4 Repository and export rules

- Commit a runtime binary only when its distribution profile permits the
  repository's actual visibility. Otherwise inject it from the private artifact
  store during the protected build.
- Commit generated .import policy evidence only in the form supported by the
  chosen binary-delivery path; never publish a sidecar that falsely implies
  the licensed binary is available.
- Never hand-edit generated sidecars.
- Never commit .godot/imported; it is reproducible cache.
- If Git LFS is later adopted, only binary audio belongs there. Import sidecars
  and legal ledgers remain ordinary diffable text.
- Production export validation proves that source-vault material, edit masters,
  audition previews and Dialogic example typing sounds are absent.
- Export validation checks each asset-specific distribution profile, packaging,
  extraction, DRM and attribution assertion; simple file presence is
  insufficient.
- All registered paths load through ResourceLoader in a clean Godot import.

## 12. Runtime architecture

### 12.1 Ownership

AudioManager is the sole live owner of game audio. Scenes, Dialogic, menus,
Minesweeper, endings, Gallery, Settings, Save and Load submit semantic requests.
They never create or command live AudioStreamPlayer nodes.

Dialogic native audio is disabled or bridged into the same semantic request
boundary. A static test must fail if a production live player exists outside
AudioManager.

The architecture separates:

| Authority | Owns | Must not own |
|---|---|---|
| AudioAssetCatalogue | Neutral IDs, exact paths, technical metadata, per-asset duration tolerance, legal, attribution and distribution-profile IDs, ship state | Story truth, hidden route fields or live players |
| AudioPlanTemplateCatalogue | Authored scene grammar, cue eligibility, transitions and resume anchors | Runtime mutation |
| AudioPlanResolver | Pure deterministic mapping from permitted committed facts to an immutable plan | Narrative mutation, filesystem discovery or playback |
| AudioManager | Players, buses, fades, pools, suspension, tolerance-bound playback capture and restoration | Narrative truth, licensing judgment or cross-owner rollback |
| AudioMutationCoordinator | Shared mutation gate, compositional gain/effect layers, owner-scoped transactions and combined snapshots | Story truth, asset selection or reuse of async identities |
| ProfileManager | Strict player-facing preferences and completed profile memory | Run audio state |
| Save and run owner | Validated semantic audio snapshot inside the canonical save transaction | Live players |
| SystemTtsCoordinator | Voice discovery, utterance token, start, stop, completion and watchdog | Game volume, route meaning or final ear-level output |

### 12.2 Checked-in bus layout

The bus layout is a checked-in project resource, never constructed ad hoc:

~~~text
Master — audience Master gain and final protective limiter
└── Game Mix — narration duck and checked-in mono downmix
    ├── Music
    ├── Ambience
    ├── SFX
    └── UI — governed by the SFX preference
~~~

No Voice bus or recorded-voice pool exists.

Profile gain is applied once, on buses. Player-level or derivative-level
commissioning gain may shape a cue, but the player's Music, Ambience or SFX
preference must never be multiplied into the player again.

AudioMutationCoordinator serializes every bus- or player-affecting commit and
snapshots one compositional state vector. Its independently owned layers are:
authored plan/playback and commissioning gain; profile Master/category gain,
mute and Output Mode; the token-scoped TTS duck; and the fail-closed recovery
mute. Effective gain is derived from those layers rather than destructively
rewritten by whichever subsystem ran last. Each transaction backs up and rolls
back only its owned layer under the shared mutation gate. Plan rollback cannot
change profile or Output Mode, profile rollback cannot change playheads, and
neither can release, duplicate or overwrite a TTS duck or recovery latch.

### 12.3 Player-facing preferences

| Preference | Fresh default |
|---|---:|
| Master | 100 percent |
| Music | 80 percent |
| Ambience | 65 percent |
| SFX, including UI | 80 percent |
| Mute When Inactive | On |
| Output Mode | Stereo |
| Sound Detail Text | Story-Relevant, preselected at first-run setup |
| Lower Background During Narration | On |
| Read Aloud | Off |
| Reading Rate | Normal, 1.0 |

Mono Audio combines the complete game mix after category gain and sends the
same approved result to both channels before the Master limiter. Godot 4.6 uses
one checked-in AudioEffectStereoEnhance on Game Mix with pan_pullout 0.0,
surround 0.0 and time_pullout_ms 0.0. Stereo bypasses the effect; Mono enables
it. No positive compensation is applied by default.
Changing Output Mode is one atomic profile-and-bus operation whose rollback
state includes effect enablement and compensation. An operating-system mono
option is not a substitute for the in-game control.

An asset is rejected when matched-gain mono loses the recognizable principal
event, causes material cancellation, or loses more than 6 dB in that principal
event relative to stereo without an approved replacement derivative. The
downmix must also pass the final peak gate. Any later compensation change is a
checked-in mix revision and must pass the complete stereo, mono and peak matrix.

Reading rate and enablement are accessibility preferences, not legacy Voice
volume fields. Compatible voice resolution is non-persisted system capability
state; there is no in-game voice picker.

Profile validation and Settings rendering use the same explicit field
allowlist. Settings must not auto-render arbitrary booleans or numbers added to
the profile schema.

### 12.4 Request boundary

An AudioPlanRequest contains only:

- request schema version;
- semantic scene ID, beat ID and phase ID;
- neutral presentation surface ID;
- physical location ID;
- established visible source IDs;
- visibly present character IDs;
- already committed witnessed action IDs;
- eligible completed profile-memory IDs only on the closed post-completion
  meta-surface allowlist in Section 8.1;
- stable replay mode; and
- the authored harmless texture seed when one already exists.

It must not contain raw route, ending, mood, attitude, affection, jealousy,
desire, hidden tier, future outcome, uncommitted focus, secret cause or
filesystem-derived identity.

Permitted fields are not an aliasing loophole. Scene, beat and phase IDs must
come from the versioned authored presentation registry and name a unit the
audience can presently distinguish; they may not be hashes, aliases or
one-to-one encodings of forbidden state. Visible source, character and action
IDs must come from the canonical committed presentation snapshot, not from a
relationship or route service. The texture seed is fixed in the authored plan
template from public presentation coordinates and cannot be supplied or
derived from runtime narrative state. Every request field records its source
registry and constructor in the schema review.

The security property is hidden-state noninterference: if two canonical game
states have the same permitted, audience-visible presentation snapshot but
differ in any forbidden route, relationship, medical, supernatural, future, or
ending field, request construction and plan resolution must be byte-identical.
Testing only “same request, same plan” is insufficient.

### 12.5 Immutable resolved plan

A ResolvedSceneAudioPlan contains:

- plan ID, revision and phase ID;
- base room layer or explicit silence;
- variant-set ID;
- stable selected neutral asset IDs;
- material, evidence, anomaly, omission and signature commands;
- optional music-island command;
- source, distance, material and equivalent for each diegetic cue;
- an explicit authorial declaration for a source-less cue;
- entry, exit, interruption and concurrency policy;
- anomaly budget and salience use;
- resume-anchor ID;
- harmless texture seed; and
- accessibility equivalence references.

Every anomaly command and every perceptibly wrong omission command carries one
unique debit ID. Authored stripped silence and authored absolute silence also
carry a debit ID when used as wrongness. The validator derives consumed budget
from the union of audible anomaly and omission debit IDs and rejects duplicate,
missing or over-budget debits. Ordinary base silence and non-fictional failure
fallbacks carry no debit and may not acquire anomalous presentation.

The resolver is pure: the same request and plan revision produce the same plan.
Plan revision is a composite compatibility revision that pins resolver,
template and catalogue semantics. It does not inspect directories and never
substitutes a vaguely similar track when an exact registered asset is missing.

The resolved plan is implemented as validated value objects. Construction deep-
copies and recursively freezes every nested array and dictionary; getters expose
scalars, read-only value objects or defensive copies. Freezing only an outer
Dictionary is insufficient.

### 12.6 Initial voice budget

The initial fixed pool is:

- two Music players for one context and a crossfade leg;
- two Ambience players for one room and a crossfade leg;
- one protected Evidence or Anomaly player;
- four Material or SFX players;
- three UI players;
- one deliberate Settings preview player; and
- zero Voice players.

The pool changes only after stress-test evidence. Plan validation forbids
overlapping protected commands. Runtime priority is Evidence, then Anomaly,
then Material, then UI, then decorative Texture; sequence number is the stable
tie-breaker. A started Evidence cue cannot be stolen. If an impossible
protected collision still occurs, Evidence replaces Anomaly with its authored
interruption fade; otherwise the later protected request is rejected with a
diagnostic and its non-audio equivalent remains. Protected requests never wait
in a timing-altering queue.

AudioStreamPlayer is the default because the visual novel does not possess a
continuous physical listener map. AudioStreamPlayer2D or 3D requires a
separately justified scene with truthful spatial semantics. Decorative panning
is not world simulation.

### 12.7 Playback and transition law

- Music and ambience have independent fade-in and fade-out durations.
- Every asynchronous transition carries a generation token. A stale completion
  cannot mutate the current plan.
- Cue requests deduplicate by stable event or command ID.
- A multi-cell Minesweeper reveal produces one command cue, not one cue per
  cell.
- A preview never enters evidence or save state.
- Registered replay uses a replay plan; it never reads current hidden state.

Applying a plan is one atomic logical audio operation. AudioManager captures
complete reconstructible playback state, allocates a fresh transaction epoch,
invalidates every earlier transition epoch, applies the plan, and either commits
or reconstructs the prior determinate logical state under another fresh epoch.
The backup includes streams, engine playhead observations and their tolerances,
logical pause reasons, transition direction and legs, authored commissioning
gains, remaining fades, and pool commands. Profile gains, Output Mode, TTS duck
and recovery mute remain in their separately owned layers. A semantic-only
playback backup is insufficient.

Epoch numbers, utterance tokens, platform utterance IDs and suspension-handle
identities are monotonic and are never rolled back, restored or reused. Pending
callbacks are cancelled or made stale; they are not reinstated. Plan
transactions do not mutate or roll back the suspension registry or TTS
coordinator. They run through the shared audio mutation gate, respect the
registry's current logical constraints, and reconstruct playback with fresh
identities. This prevents an ABA rollback from making old work current again.

Godot playback-position queries are chunk-based and cannot promise sample-exact
reconstruction. “Exact” applies only to pausing a still-live player in place.
Transaction rollback is required to restore semantic identity, transition
direction and playhead within the asset's registered tolerance. If rollback
cannot establish that determinate boundary, AudioManager latches Game Mix
silent, cancels all in-flight transition epochs, marks the active TTS token
non-startable and retains it only in the stopping slot, blocks new speech, calls
the platform adapter's stop-and-clear operation, and quarantines platform TTS
until matching cancellation or a confirmed not-speaking state. The stopping
identity may release only its own orphaned duck; an unresolved cancellation
remains quarantined and can never admit successor speech. The latch reports
factual technical recovery and accepts no conflicting audio mutation until an
explicit reset.

An optional audio failure degrades locally to a registered room layer or
authored silence. It must not freeze the entire application through a global
fatal mutation gate.

## 13. Pause, focus, Save, Load and memory

### 13.1 Suspension leases

Pause, focus loss and Settings preview use opaque suspension-lease handles
containing holder, reason and generation. Independent holders always receive
distinct handles. Reacquisition by the same holder and live generation returns
the same handle; release consumes exactly that handle once. Stale, foreign and
double release are no-ops with diagnostics. One subsystem cannot resume audio
while any valid handle still suspends it.

| Boundary | Required behavior |
|---|---|
| Universal Pause | After the accepted Pause feedback, freeze live Music, Ambience, Evidence, Anomaly, Material and every other source-scene SFX player in place; freeze both transition legs, gains and remaining transition time; stop active non-Pause UI, Settings preview and TTS; admit only registered Pause-menu UI |
| Focus loss with inactive mute On | Reach a stable frontier, capture and suspend background exactly; stop TTS, preview and one-shots |
| Focus loss with inactive mute Off | Music and ambience may advance; TTS, preview and one-shots still stop |
| Ordinary Save | Persist semantic plan and stable decisions, not decorative tails |
| Load | Reconstruct at the authored resume anchor; never reroll evidence |
| Crash recovery | Restore the last durable semantic plan and discard incomplete decorative one-shots |
| Gallery replay | Activate the registered replay plan without fresh witnessing |
| Post-ending title | Select the deterministic eligible completed-profile variant |
| New Run | Install a valid empty initial audio snapshot; retain eligible completed memory only in ProfileManager, never in the new run request until a closed meta surface asks for it |

AudioManager and its live players use an explicit process mode, and transition
timers or Tweens use an explicit pause policy, so SceneTree pause cannot advance
fades or override a surviving focus lease. On resume, Pause-menu one-shots stop
before the source scene resumes. Frozen source-scene pools resume from their
literal paused positions. Non-Pause UI, preview and TTS that were stopped at the
boundary do not resume or replay. While paused, every UI request lacking the
registered Pause-menu class is rejected rather than queued.

Pause resumes still-live engine playheads in place because continuity is
expected. Load uses a
curated anchor because an arbitrary millisecond may begin inside a footstep,
door impact, breath or piano attack.

### 13.2 Semantic save schema

The audio sub-snapshot inside the canonical run snapshot stores exactly:

- schema_version;
- plan_id;
- plan_revision;
- phase_id;
- variant_set_id;
- stable_selections;
- anomaly_ids;
- omission_ids;
- signature_ids;
- resume_anchor_id; and
- harmless_texture_seed.

It does not store raw resource paths, private fields, arbitrary dictionaries,
decorative one-shots or unvalidated playback objects. New Run uses a schema-
valid initial object, never an empty dictionary that the real AudioManager
rejects.

plan_revision pins resolver, template and catalogue compatibility.
stable_selections is a strict map from every stable semantic cue slot to its
neutral asset ID and derivative revision. It includes the room layer, protected
Evidence, Anomaly, eligible Signature and any Music island; no stable category
is implicit.

Save capture is admitted only at a shared stable-plan frontier. The canonical
save envelope, outside the exact audio snapshot above, carries one monotonic
run_commit_revision. A RunCommitCoordinator owns the mutation barrier: every
narrative transition and its resolved audio-plan commit prepare under one
exclusive mutation lease and publish the new run_commit_revision only after
both sides commit. If either side fails, neither revision publishes and every
already-applied side restores its prepared prior state before the lease is
released. Save obtains a read lease, captures the envelope revision,
narrative state and audio snapshot, then captures the revision again before
release. Different beginning and ending revisions abort and retry the Save; a
revision is never inferred from plan_revision or phase_id. Thus a Save cannot
combine state from opposite sides of either a narrative or audio-plan commit.

Verification must force adversarial interleavings at every prepare, commit,
publish and capture yield point, including failure and rollback. Every accepted
snapshot must contain one published run_commit_revision whose narrative and
audio members were committed together; every torn attempt must abort without a
durable file.

Audio restoration is internally atomic. If any music, ambience, profile/output
or anchor operation fails, the restore coordinator returns every applied owner
to its prior determinate logical layer. Playback identity, transition direction
and playhead restore within the registered asset tolerance; profile scalars and
effect enablement restore exactly. If the combined state cannot be
re-established within those contracts, AudioManager enters the silent recovery
latch before reporting failure. Save orchestration must register its audio
restore participant during bootstrap and complete storage reconciliation before
a fresh-process read.

## 14. System text-to-speech

System TTS is asynchronous, platform-dependent and external to the game buses.
A compatible voice list may be empty. The game cannot limit or promise the
physical level of the operating-system voice.

SystemTtsCoordinator depends on an injectable TtsPlatformPort with voice-list,
speak, stop-and-clear, is-speaking and callback-event operations. The production
SystemTtsPlatformAdapter is the sole project-owned location permitted to call
DisplayServer.tts_* directly. Automated lifecycle tests use a deterministic
FakeTtsPlatformPort that can schedule start, finish, cancel, error, delayed and
missing callbacks and is-speaking transitions. Fake-port success proves state-
machine behavior only; it never proves voice availability or intelligibility.

The coordinator serializes game-owned TTS through IDLE, DUCKING, STARTING,
SPEAKING, STOPPING, RECOVERING and QUARANTINED. At most one utterance identity
occupies either the active slot or the stopping slot; never both. One pending-
successor request may exist, but receives no token until the prior identity is
cleared. Tokens and platform utterance IDs are monotonically increasing. A
callback or watchdog may act only when both identities match the appropriate
slot and its event is legal in the current state. A stopping callback may
confirm termination and release its own duck, but can never start or mutate
successor speech.

The initial Windows commissioning constants are:

- narration duck: minus 12 dB over 120 milliseconds;
- recovery: 180 milliseconds;
- start watchdog: 3000 milliseconds;
- stop or missing-finish drain: continuously not speaking for 750 milliseconds,
  sampled every 100 milliseconds; and
- stop watchdog: 3000 milliseconds.

The utterance deadline after confirmed start is
`min(120000, max(10000, 1000 + 600 * grapheme_count))` milliseconds. Constants
are versioned and may change only after recorded platform tests. They are
failure bounds and commissioning choices, not intelligibility or safety claims.

The transition law is total:

| State or event | Required action and next state |
|---|---|
| IDLE + Start | Allocate a fresh active token, acquire its duck lease, enter DUCKING |
| DUCKING complete | Recheck Pause, focus and every suspension lease; if clear, call speak once and enter STARTING; otherwise Stop before platform speech begins |
| STARTING + matching started callback or is-speaking true | Cancel the start watchdog, start the utterance deadline, enter SPEAKING |
| STARTING + matching finished callback | Cancel the start watchdog, mark successful short completion and enter RECOVERING |
| STARTING + matching cancelled callback | Cancel the start watchdog, mark deliberately stopped, suppress confirmation and enter RECOVERING |
| STARTING + watchdog, error or suspension | Call stop-and-clear once, move the active identity to the stopping slot, enter STOPPING |
| SPEAKING + matching finished callback | Mark successful completion and enter RECOVERING |
| SPEAKING + matching cancelled callback | Mark deliberately stopped, suppress confirmation and enter RECOVERING |
| SPEAKING + is-speaking false without a finish callback | Begin the 750-millisecond drain; if it remains false, mark degraded completion, suppress confirmation and enter RECOVERING; any speaking observation restarts the drain |
| SPEAKING + error, utterance deadline, Pause, focus loss or teardown | Call stop-and-clear once, move the identity to the stopping slot, enter STOPPING |
| STOPPING + matching finished or cancelled callback, or completed not-speaking drain | If a pending successor exists, clear the stopping identity, allocate the fresh successor and atomically transfer the already-lowered duck lease before entering DUCKING; otherwise move the same non-speaking identity back to the active slot solely to own RECOVERING |
| STOPPING + stop watchdog | Release only that token's orphaned duck, clear pending speech, enter QUARANTINED and report factual unavailability |
| RECOVERING complete | Release or finish the owning duck lease, clear the active identity, play a restrained confirmation only for a matching successful completion with no pending successor, then enter IDLE or start the pending request with a fresh token |
| QUARANTINED + any speech request | Reject factually; no speech begins until an explicit adapter reset and voice-capability recheck succeeds |

Any Start while an identity is active is Replace. Replace stores only the newest
pending successor. In DUCKING, before speak was called, Replace makes the old
token stale, transfers its duck lease to a fresh token and remains DUCKING; Stop
enters RECOVERING without calling the platform. In STARTING or SPEAKING,
Replace invokes the STOPPING transition. In STOPPING it only updates the
pending slot and never issues a second platform stop. In RECOVERING it waits for
recovery to complete. Stop always clears the pending successor; Stop in
STOPPING is idempotent, Stop in RECOVERING suppresses confirmation and lets
recovery finish, and Stop in IDLE is a factual no-op. Passing interrupt=true to
speak may clear a platform queue but is never proof that earlier speech stopped.

An identity-mismatched, late, duplicate or state-illegal callback is an
idempotent no-op with a diagnostic. The only non-table polling transition is the
declared is-speaking drain. This default rule closes the state/event matrix
without allowing an unexpected callback to mutate ownership.

Normal finish, missing callbacks, errors and explicit stops all reach either
IDLE or QUARANTINED within a declared bound. Once its duck is released, a failed
or quarantined utterance reports `DELIBERATELY_STOPPED_TECHNICAL`; Auto may then
honour its remaining visual delay rather than wait forever. Older callbacks and
watchdogs are no-ops. No path may leave a stale duck, start speech after
suspension, replay stopped text, or admit overlapping speech.

Godot's platform rate range is 0.1 through 10.0, but the accepted Settings
presets are deliberately narrower: Slow 0.8, Normal 1.0, and Fast 1.2. Every
platform and installed-voice report records whether a chosen voice truncates or
otherwise alters the requested rate. These values are project choices, not
claims of universal speech comfort.

Lower Background During Narration applies to game-owned narration. The game
must not claim detection of an external screen reader unless that detection is
technically verified on each supported platform.

## 15. Accessibility and non-audio equivalence

Audio may enrich interpretation but may never control comprehension, choice,
state, eligibility, route or ending.

### 15.1 Muted-play law

For identical player inputs, an all-muted and TTS-disabled run must produce
byte-identical choices, consequences, eligibility and durable state. Every
essential event is understandable before its related decision, not explained
afterward.

Spoken dialogue remains text. Essential nonverbal facts receive a simultaneous
visible action, physical consequence or natural prose line.

### 15.2 Sound Detail Text

Sound Detail Text is a non-canonical accessibility presentation annotation. It
conveys a meaningful non-speech anomaly or material event without becoming
dialogue, narration, witnessed evidence, a presentation receipt, or a durable
story fact. It does not enter History, Save state, the evidence ledger or route
logic. When enabled, it renders from the already resolved command at the same
semantic moment even if the audio category is muted.

- objective, brief and authored from a registered detail-text ID;
- shown at the same semantic moment as the sound;
- limited to the exact acoustic event plus already committed simultaneous
  visible facts;
- forbidden from inferring cause, agency, authorship, intent, hidden presence,
  absence, diagnosis, or supernatural meaning;
- never a mechanical bracket stream such as [door sound];
- never a diagnosis, symbol interpretation or emotion label;
- never generated from filenames or metadata; and
- omitted for purely decorative atmosphere.

An acceptable line is: “The kettle clicks twice.”
An unacceptable line is: “A supernatural kettle proves Sylvia was right.”

Every registered line carries an immutable proposition-parity record containing
its audible-event proposition IDs, already committed visible-fact IDs, and
rendered proposition IDs. The rendered set must be a subset of the first two;
cause, agency, absence and hidden-state proposition classes are structurally
forbidden. A test presents the same allowed inputs under opposing hidden states
and requires byte-identical text. Human review rejects any wording that gains a
stronger evidentiary reading than the sound and visible tableau together.

Story-Relevant is preselected in the first-run setup. The player may disable it
without changing state. This narrow surface replaces only the exact blanket
ban named in the targeted supersession ledger; every other Settings caption and
evidence guarantee remains in force.

### 15.3 Stereo and mono

- No essential clue exists only in pan, width, phase, reverberation or distance.
- Stereo remains restrained and anchored to the visible tableau.
- Mono combines the full game mix into both channels without clipping or
  cancellation.
- Left-only and right-only playback preserve every essential event.
- No asset gains prestige merely because headphones reveal hidden detail.

## 16. Comfort and measurement

### 16.1 Physical honesty

LUFS and dBTP describe digital signals. They do not determine sound pressure at
the ear. Hardware gain, operating-system volume, amplifier, transducer
sensitivity, fit, duration and individual hearing all matter.

Therefore this project may say **measured, restrained and auditioned**. It may
not claim **universally safe**, **non-painful**, or medically protective.

The project uses ITU-T H.872 and ITU-R BS.1770-5 as an informed measurement
basis without claiming formal H.872 compliance.

### 16.2 Internal mix gates

Every locked route/surface fixture is rendered through a mandatory matrix:

- the shipped-default gain profile and a stress profile with Master, Music,
  Ambience and SFX all at 100 percent;
- Stereo and Mono Output Modes; and
- a pre-limiter Game Mix capture plus a post-Master final capture.

The same versioned command schedule and warm-up apply to all matrix cells. The
post-Master capture for every worst-credible thirty-minute window is no louder
than minus 23 LUFS integrated and does not exceed minus 1 dBTP. Quieter is
allowed and is never raised merely to hit a target. The corresponding
pre-limiter Game Mix capture remains at or below minus 6 dBTP. Final decoded
runtime assets also do not exceed minus 1 dBTP. System TTS is excluded from the
game-bus ceiling and captured in a separately labelled operating-system
loopback report; it never silently contaminates a Game Mix pass.

- The limiter performs zero routine gain reduction. Any activation triggers
  review rather than becoming a mixing method.
- A non-user-initiated rise greater than 6 LU is a mandatory human-review flag,
  not a medical threshold. Momentary loudness uses an ungated 400-millisecond
  sliding window with a 100-millisecond hop. For each authored event interval,
  compare the maximum intersecting momentary sample against the median of the
  momentary samples in the preceding three-second stable bed. If no complete
  three-second stable bed exists, or the reference contains undefined or
  negative-infinity silence readings, review the event manually and mark the
  numeric comparison not applicable.
- No fixed per-class LUFS target is invented before real assets exist.
- No frequency blacklist pretends that frequency alone establishes pain.

Automated analysis flags clipping, DC steps, import pops, codec overs,
unexplained persistent narrow peaks, rumble, mono cancellation and accumulated
tails. Human review decides whether the result is piercing, pressurized,
startling, coercive or fatiguing.

Before these tests can claim a pass, a versioned AudioVerificationFixture
manifest must freeze reachability-manifest revision, route or surface ID, plan
revision, seed, command timing, voice concurrency, fade overlap, gain-profile
ID, Output Mode, locale, TTS inclusion, capture point, meter algorithm and
version, warm-up period, and every numeric tolerance. Its coverage checker
proves that every authored transition, terminal trace and repeatable cycle is
represented; an unrepresented reachable edge fails the suite. “Worst credible”
means the enumerated fixture with the largest legal simultaneous bus sum under
authored concurrency, not an operator's intuition. “Fastest valid” means one
accepted command per locked input-debounce interval and the minimum legal text
dwell; the clock may not be slowed to improve music coverage. Memory tests
require stable player and node counts after warm-up and no monotonic retained-
memory rise beyond the manifest's measured platform tolerance.

### 16.3 Listening conduct

Auditioners:

- establish one comfortable hardware setting and do not turn it up to chase
  hidden detail;
- stop immediately for pain, pressure, ringing, headache, nausea or unusual
  fatigue;
- take a quiet break after one hour;
- record a stopped test as evidence against the candidate, never as reviewer
  failure; and
- compare against silence at the same hardware setting.

The first-run accessibility setup includes a brief non-horror listening-
comfort note. A long-session reminder appears only at a Pause or day boundary,
never during a scene and never as fiction. It does not claim dosimetry.

## 17. Acceptance tests for sound and mix

| Area | Measured gate | Human gate |
|---|---|---|
| Thirty-minute mix | Every shipped/stress-gain × Stereo/Mono × pre-limiter/post-Master matrix cell passes; stems and sum are reported | Quiet remains legible without inflation |
| Suddenness | Every greater-than-6-LU rise is listed | No unresolved volume ambush |
| Spectrum | No clipping, DC step, import pop, codec over or unexplained persistent narrow peak | No piercing, pressure-like or tinnitus-like residue |
| Mono | No clipping or phase cancellation; both channels receive the combined mix | Meaning, timing and material identity survive mono, left-only and right-only |
| Loop | At least twenty in-engine wraps without gap, click, drift or tail accumulation | Thirty-minute blind test does not reveal a stable seam or moderate fatigue |
| Repeated UI | One hundred fastest-valid activations without clipping, pool leak or evidence theft | No urge to mute SFX |
| Long session | Longest route twice or a two-hour soak without stale duck, gain drift, memory growth or phase accumulation | Beds remain inhabitable rather than coercive |
| TTS | Fake-port lifecycle suite plus every locale at 0.8, 1.0 and 1.2 with up to two installed compatible voices; no clipped first phoneme, overlap, stale duck or confirmation collision | A blinded listener recognizes every critical unit and at least 95 percent of all marked content units under the versioned protocol |
| Muted equivalence | Identical choices, consequences, eligibility and state | Every essential event is understood before its decision |
| Audiovisual startle | No cue is paired with abrupt full-screen contrast change or audio-reactive flashing | No combined audiovisual ambush |
| Device matrix | Closed and open headphones, sensitive earbuds, laptop speakers, small desktop speakers, mono, left-only and right-only | No device class hides essential material or creates unresolved discomfort |

Loop fatigue uses a zero-to-four rating for seam awareness, repetition
awareness, spectral irritation and urge to mute. Any three or four blocks the
candidate. Two ratings of two require revision and retest.

The versioned TTS corpus includes longest lines, short interjections, negations,
dates, calculations, astronomy and literature terms, character names,
punctuation, English inside Chinese and Chinese inside English. Its transcript
marks indivisible content units before listening and identifies negations,
names, dates, numbers and choice-changing words as critical. A listener hears
without viewing the transcript, writes what was understood, then a fixed scorer
compares the response with the marked answer key. One blinded listener who did
not author the line is the minimum for a provisional result. A second
independent blinded listener is required for every miss or ambiguity and for a
final ship pass; if unavailable, the result remains provisional rather than
being promoted by judgment.

The production voice matrix tests up to two installed compatible voices per
supported locale. If only one or none exists, the report records that exact
availability and tests all available voices; it does not invent a second voice
or convert absence into a pass. Voice discovery, truncation, selected voice ID,
operating-system build, device, output settings and rate are recorded. A
versioned Windows human/device protocol owns loopback and intelligibility
testing because system TTS does not pass through the game limiter. The
deterministic fake-port protocol separately owns automated start, end, cancel,
delay, watchdog, replacement and quarantine assertions.

## 18. Blind audition and artistic decision

Legal and provenance review occurs before listening to prevent attachment bias.
The evidence operator publishes a hash-bound blind docket; the artistic docket
contains only neutral IDs and normalized technical warnings. The artistic
listener must not have the identity ledger open during judgment. When one
person performs both duties, the blind order is shuffled and the listening
session occurs separately from evidence review; the limitation is recorded.

The audition sequence is:

1. verify the research packet;
2. authorize and identity-check acquisition;
3. present a neutral blind ID with no title, creator, source tag, route,
   preference or importance;
4. listen in mono;
5. listen in stereo;
6. test the proposed scene under dialogue and TTS;
7. test repeated actions, long duration and loop seams;
8. compare preferred, fallback and authored silence;
9. expose identity only after the blind artistic judgment is immutable;
10. evaluate source reliability and recheck license, provenance and edit
    permission outside the artistic score; and
11. approve or reject the exact derivative, never the vague source family.

Artistic scoring records:

- physical credibility and material specificity;
- restraint and emotional ambiguity;
- fit with the visible space;
- restrained authorial wrongness;
- scene contribution compared with authored silence;
- dialogue and TTS coexistence;
- mono and device behavior;
- repetition comfort;
- edit and loop feasibility.

Legal, AI, privacy, semantic leakage, truth-boundary, essential-equivalence and
comfort failures are hard gates, not weighted scores. For a preferred
candidate, physical credibility and restraint must each reach at least four out
of five and no scored dimension may be below three.

Scene contribution uses one fixed five-point rubric: 1 weakens or distracts; 2
adds no useful value over silence; 3 provides modest but replaceable support; 4
materially enriches space or tension without explaining it; 5 creates unusually
specific, repeatable enrichment while muted-play equivalence remains complete.
The listener records the same dimension for authored silence in the identical
fixture.

Authored silence is evaluated as a real comparison condition for restraint,
scene contribution and comfort. A candidate advances only when scene
contribution exceeds silence by at least one point, physical credibility and
restraint meet the preferred-candidate thresholds, and comfort is no worse than
silence. Comfort is a better/equal/worse hard comparison, not a disguised
weighted score. An exact tie, split decision, or unresolved trade-off selects
silence.

Music and human texture are never searched desperately. If a scene works
without them, their burden of proof rises.

## 19. Failure and truthful fallback

- Missing optional music falls to the registered room texture or authored
  silence, never another semantic track.
- Missing ambience falls to the plan's registered room-held or stripped-silence
  fallback with a factual diagnostic. It never creates a new absolute-silence
  moment or spends one of the two authored absolute-silence slots. This
  technical stripped silence is neutral failure containment, never timed,
  captioned or shaped as an anomaly; an authored stripped-silence anomaly must
  instead carry and consume its normal anomaly debit.
- Missing essential sound leaves its complete visible or textual equivalent
  intact and logs the exact missing ID.
- A failed plan transaction restores the prior determinate logical state within
  registered playback tolerances, or enters the fail-closed silent recovery
  latch.
- An indeterminate audio state blocks conflicting audio mutation only; it does
  not convert the whole game into supernatural or fatal failure.
- TTS failure releases ducking.
- Mono failure falls back to the last known valid output mode and reports a
  factual settings error.
- Technical failure never creates a sting, anomaly, fake corruption, false
  save damage or hidden story fact.

Diagnostics name technical IDs and states in developer logs but use neutral,
non-spoiling player text.

## 20. Current implementation drift and replacement boundary

The implementation audit below describes branch codex/audio-audition-pass-1 at
commit d12f5426a88b1b1a34de28d62e83c3315439e28b on 2026-08-14. Later code must
be re-audited rather than assumed identical. The audited implementation has
useful crossfade, pool and rollback ideas, but it does not satisfy this manual.

Known drift includes:

- AudioManager combines too many responsibilities, creates buses dynamically
  and still owns a Voice path;
- no checked-in default bus layout or production audio directory exists;
- AudioManifest hardcodes continuous screen, mood, friend, route and ending
  themes, mine stingers and filesystem inference;
- current user gain is applied at both bus and player, so an 80-percent setting
  can become approximately 64 percent;
- SFX gain and loop behavior are incomplete;
- Dialogic can own audio players outside the sole-owner boundary;
- only an ending scene currently makes a production audio call;
- Profile schema version 1 exposes Voice, defaults inactive mute Off and lacks
  Master, Mono, Sound Detail Text and narration-lowering preferences;
- Settings renders every numeric and boolean field automatically instead of
  using an audio allowlist;
- focus loss merely bus-mutes and does not capture, pause or stop one-shots;
- RunSnapshot accepts arbitrary audio dictionaries while AudioManager expects
  a different four-key legacy object; New Run supplies an invalid empty object;
- Load force-restarts contexts at zero rather than using a curated anchor;
- audio restore is not internally atomic and does not preserve playheads or
  crossfade state on rollback;
- bootstrap names a restore-registration stage without executing or targeting
  it;
- fresh-process storage reads lack the required reconciliation lease; and
- Gallery has no activation path for registered replay.

The game has never shipped. Compatibility aliases, legacy Voice migration,
route-theme fallbacks, mood-field adapters and deprecated cue IDs are therefore
forbidden. Replace the model cleanly.

The existing audition worktree and ignored cache are not production authority.
Pass 1A is governed by
.superpowers/sdd/2026-08-14-audio-audition-intake-pass-1a/SESSION-HANDOFF.md.
Its ignored cache contains seven official Freesound HQ previews and the exact
Kenney UI Audio archive, but no production-approved source master or asset.

Acquisition, analysis publication, blind audition, audio playback and Task 5
changes all remain paused. Resumption requires a separate immutable user-
approved decision record for both the safe explicit-directory-marker rule and
the first-party 50-asset claim versus the physical archive's Preview.ogg plus
51 Audio members. Acceptance of this manual does not resume that work.
Freesound IDs 670070 and 802495 remain rejected and must not be requested again.

## 21. Verification architecture

The implementation plan must provide at least:

- test_audio_catalogue.gd;
- test_audio_plan_resolver.gd;
- test_audio_pool_policy.gd;
- test_audio_transition_state.gd;
- test_audio_pause_focus.gd;
- test_audio_save_restore_recovery.gd;
- test_tts_duck.gd; and
- test_audio_failure_matrix.gd.

Required structural checks:

- no live production audio player outside AudioManager across project-owned
  runtime code, exported scenes, and every enabled or exported addon module;
- Dialogic Audio and Voice modules are disabled and excluded, removed, or
  vendor-patched to emit the semantic bridge before the structural check may
  pass;
- only editor demos and test fixtures proven absent from export may appear on a
  documented static-scan allowlist;
- direct DisplayServer.tts_* calls exist only in
  SystemTtsPlatformAdapter; project scenes, gameplay code and every enabled or
  exported addon must use TtsPlatformPort through SystemTtsCoordinator;
- no Voice bus, preference, player or legacy mapping;
- the accepted Settings vocabulary is extended by only the three fields in
  Section 1.1, uses the same explicit validation/rendering allowlist, and exposes
  no voice picker;
- no raw route, friend, mood, affection, jealousy, desire, medical,
  supernatural, ending or hidden-tier asset ID or resolver input; only the
  neutral, post-completion profile-memory IDs explicitly permitted by this
  manual may enter the closed meta-surface allowlist;
- no filesystem discovery or semantic fallback;
- every runtime asset has one catalogue, evidence and attribution record;
- every .import sidecar matches the locked import policy;
- source vault, audition cache, previews, edit masters and addon examples are
  absent from exports.

Required deterministic checks:

- identical request plus composite plan revision produces identical plan;
- canonical states with identical permitted audience-visible presentation but
  different forbidden route, relationship, medical, supernatural, future or
  ending state construct byte-identical requests and plans;
- Save and Load never reroll stable selections, anomaly, omission, signature or
  music island;
- harmless texture cannot change interpretation;
- replay and Settings create no witnessed evidence;
- Sound Detail Text rendered propositions are a subset of the exact audible
  event plus already committed visible facts and remain identical across
  opposing hidden states;
- missing assets never substitute meaning;
- wrong-order sound always has an inspectable visible basis;
- every authored omission, stripped-silence anomaly and absolute-silence
  anomaly consumes one unique debit from the beat's exclusive salience-class
  budget; and
- omission, stripped silence and absolute silence obey the same truth boundary
  as audible cues and cannot corroborate hidden, medical or supernatural facts;
- every reachable terminal trace and repeatable cycle passes the scheduled
  music-occupancy ceiling at the fastest valid clock, with no uncovered
  transition.

Required lifecycle checks:

- Pause freezes and restores literal playheads and transition time for Music,
  Ambience, Evidence, Anomaly, Material and other source-scene SFX; stopped UI,
  preview and TTS never resume, and only Pause-menu UI is admitted while paused;
- suspension uses holder-scoped opaque handles with idempotent reacquisition
  and single-consumption release;
- inactive-audio continuation never resumes stopped TTS, preview or one-shots;
- Load enters the registered anchor;
- rapid focus and Pause changes cannot stale-resume;
- a failing audio participant restores its determinate logical state before
  reporting failure or enters the explicit silent recovery latch;
- rollback allocates fresh epochs and never restores or reuses transition,
  suspension or TTS identities; stale callbacks remain stale under forced ABA
  interleavings;
- forced interleavings among plan playback, profile/output, TTS duck and
  recovery-mute commits preserve every independently owned layer and apply the
  registered playback tolerance or silent latch consistently;
- the silent recovery latch stops and quarantines platform TTS, blocks successor
  speech and releases only the matching orphaned duck;
- New Run and fresh-process Load use valid schema and storage reconciliation;
- Save rejects every forced narrative/audio interleaving whose enclosing
  run_commit_revision is not stable and jointly published;
- the fake TTS port covers every legal state/event pair, missing and late start
  or finish callbacks, errors, start/utterance/stop watchdogs, repeated Replace
  and Stop, recovery-time requests, quarantine and Auto unblocking; no path
  overlaps speech, admits a successor before confirmed stop, or leaves a stale
  duck; and
- Gallery replay activates only the registered replay plan.

A checked external codec probe records codec, decoded duration, channel count,
sample rate, bit depth or bitrate and true peak for every runtime byte. Godot
clean-import validation then loads every catalogue path through ResourceLoader
and asserts only properties the concrete stream class exposes, including
stream class and loop metadata. Ogg and MP3 channel count or sample rate are
verified from the hash-bound external probe because Godot 4.6 does not expose
them uniformly.

Each catalogue record fixes duration_tolerance_ms: at most 1 millisecond for
PCM WAV and at most 50 milliseconds for Ogg or MP3 unless the approved encoder
report establishes a tighter bound. A looser exception requires written
evidence and user approval. A built export proves that every registered asset
is present and every forbidden source artifact is absent.

## 22. Research and implementation sequence

Acceptance of this written manual authorizes only drafting an implementation
plan. It does not authorize executing that plan, changing runtime code,
resuming Pass 1A, researching new candidates, acquiring, analyzing, playing,
auditioning, editing, importing, registering or shipping audio.

The potential sequence is:

1. draft an implementation plan for the clean architecture and schema repair;
2. obtain explicit user approval of that exact implementation plan;
3. execute only its authorized test-driven increments;
4. obtain user review of the verified silent system with no production assets;
5. obtain explicit user authorization for a bounded research refresh;
6. refresh only the authorized role group under this legal policy; the initial
   refresh is physical core only, and music or human material remains
   ineligible until PHYSICAL_CORE_CLOSED proves every required member
   AUDITION_PASSED or individually waived with its authored need removed;
7. present an immutable acquisition packet for a small physical-core batch;
8. obtain explicit user approval of that exact packet;
9. acquire and identity-check only the approved files;
10. present the resulting neutral blind docket and obtain audition
    authorization;
11. obtain separate artistic and comfort decisions;
12. present exact edit recipes and obtain edit authorization;
13. create only the authorized edit masters or pass-through records;
14. present the runtime-registration packet and obtain integration
    authorization;
15. import, register and test only approved runtime bytes; and
16. present the final license, provenance, placement and distribution packet
    for separate ship approval.

Steps 5–15 repeat in separately authorized, bounded physical-core batches until
PHYSICAL_CORE_CLOSED. A partial batch does not unlock music or human material,
and no batch approval carries forward to the next one.

The user is the acquisition and production approver unless they explicitly
delegate that authority in writing. Every approval record fixes operation,
batch ID, exact candidate or derivative IDs, evidence revision and hashes,
direct source URLs, allowed scope, timestamp and expiry or one-use status. A
general expression of enthusiasm and acceptance of this manual are not batch
approval.

Research never authorizes acquisition. Acquisition never authorizes playback or
audition. Audition never authorizes editing. Editing never authorizes runtime
integration. Runtime approval never authorizes shipping.

## 23. Completion criteria

This audio system is complete only when:

- every audible event, omission and silence state obeys the narrator's
  knowledge boundary;
- silence remains authored and environmental beds remain credible;
- exhaustive reachability and cycle verification proves scheduled music
  occupancy remains at or below twenty percent at the fastest valid clock;
- no music, anomaly, omission, silence, UI cue or failure reveals or
  corroborates hidden, medical or supernatural truth;
- every required physical-core member in the atomic manifest and every UI or
  gameplay member used by the authored game is satisfied by a SHIP_APPROVED
  derivative or removed through an explicit member-level user-approved scene
  revision;
- optional music and human roles may resolve to authored silence; other
  optional decorative roles require an explicit role-level user waiver rather
  than a blanket all-silence completion;
- every shipped byte has exact license, provenance, checksum, edit and
  attribution records;
- the Godot import, catalogue, resolver, ownership, pool, transaction,
  persistence, Pause, focus, replay and TTS contracts pass;
- Mono Audio and Sound Detail Text preserve access without explaining the
  mystery;
- all measured and human comfort gates pass;
- the complete game remains comprehensible and state-identical with audio
  muted; and
- the user approves the final scene-to-audio placement and ship ledger.

## 24. Primary reference spine

- Godot 4.6 audio importing:
  https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_audio_samples.html
- Godot 4.6 AudioStreamPlayer:
  https://docs.godotengine.org/en/4.6/classes/class_audiostreamplayer.html
- Godot 4.6 audio buses:
  https://docs.godotengine.org/en/4.6/tutorials/audio/audio_buses.html
- Godot 4.6 stereo enhance and mono downmix:
  https://docs.godotengine.org/en/4.6/classes/class_audioeffectstereoenhance.html
- Godot 4.6 text to speech:
  https://docs.godotengine.org/en/4.6/tutorials/audio/text_to_speech.html
- Godot 4.6 DisplayServer TTS API:
  https://docs.godotengine.org/en/4.6/classes/class_displayserver.html
- ITU-T H.872 safe listening for gameplay:
  https://www.itu.int/rec/T-REC-H.872
- ITU-R BS.1770-5 loudness and true-peak measurement:
  https://www.itu.int/rec/R-REC-BS.1770-5-202311-I/en
- EBU Tech 3341 momentary and short-term loudness metering:
  https://tech.ebu.ch/publications/tech3341
- Xbox Audio Accessibility Guideline 105:
  https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/105
- Creative Commons CC0:
  https://creativecommons.org/publicdomain/zero/1.0/
  https://creativecommons.org/publicdomain/zero/1.0/legalcode
- Creative Commons CC BY 4.0:
  https://creativecommons.org/licenses/by/4.0/
  https://creativecommons.org/licenses/by/4.0/legalcode.en
- OpenGameArt licensing FAQ:
  https://opengameart.org/content/faq
- OpenGameArt OGA-BY 4.0 controlling text:
  https://opengameart.org/sites/default/files/archive/oga-by-40.txt
- PeriTune terms and March 2026 transition:
  https://peritune.com/about/
  https://peritune.com/blog/2026/03/01/terms-update/
- Sonniss GDC license:
  https://sonniss.com/gdc-bundle-license/
- Freesound license and GenAI policy:
  https://freesound.org/help/faq/
- Mixkit music and SFX terms:
  https://mixkit.co/free-stock-music/
  https://mixkit.co/free-sound-effects/
- Pixabay audio and AI guidance:
  https://pixabay.com/blog/posts/audio-quality-guidelines-182/
- Pixabay binding terms:
  https://pixabay.com/service/terms/
- ZapSplat Standard License:
  https://www.zapsplat.com/license-type/standard-license/

## 25. Private creative vow

This epigraph is non-normative. Sections 1–24 govern every production
decision.

> Let the room remember gently<br>
> without pretending it knows why.<br>
> Let one chosen ordinary sound<br>
> arrive a heartbeat out of place.

The private production secret is simple: the strangest sound should rarely be
the unfamiliar one. It should be the ordinary sound that has obeyed the wrong
day.
