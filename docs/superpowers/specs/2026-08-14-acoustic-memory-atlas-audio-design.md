# Acoustic Memory Atlas: Audio Implementation and Asset-Curation Design

**Status:** Accepted historical design; pending supersession after written-manual review

**Date:** 2026-08-14

**Written specification approved:** 2026-08-14

**Planned successor:** [Haunted Instrumentarium: Audio Production and Implementation Manual](2026-08-14-haunted-instrumentarium-audio-production-manual-design.md)

This file remains the accepted audio authority until the user approves the
written successor. The successor incorporates approved Design Gates 1–4, the
clean runtime replacement, the thirty-five-role register, revised legal
provenance rules, Godot 4.6.3 import policy, Mono Audio, Sound Detail Text, and
the comfort and verification matrix.

**Target:** Godot 4.6.3, initial Windows release

**Artifact class:** Normative audio design and research specification; no asset or runtime implementation authorization by itself

## 1. Purpose

Define the complete artistic, legal, architectural, persistence, accessibility,
and production model for music, ambience, UI audio, and sound effects in the
adult pixel-art romantic psychological/supernatural horror visual novel.

The design supports an existing-audio-only production process. It does not
authorize composition, generation, synthesis, cloning, or AI generation of
music or sound effects. It permits documented editing of an existing asset only
when that asset's license permits modification.

The intended result is an **Acoustic Memory Atlas**: sound behaves like the
story remembering itself. It can be tender, dry, unreliable, or quietly
contradictory while remaining governed by deterministic rules and physical
evidence.

## 2. Authority and scope

### 2.1 Authority spine

Narrative and system decisions remain subordinate to the newest accepted
project authorities, especially:

1. `story/01-core-story-bible.md`;
2. `story/05-canon-amendments-2026-07-19.md`;
3. the newest applicable accepted documents under `docs/design/`;
4. approved requirement packets under `prompt_docs/requirements/`; and
5. this specification for audio behavior where it does not conflict with a
   higher authority.

The classical-recording note at
`docs/research/2026-08-14-classical-music-recording-rights-and-free-sources.md`
is external research supporting the legal gate. It does not independently
amend canon or runtime law.

### 2.2 In scope

- the artistic function and limits of the audio narrator;
- scene, interface, route, fragment, hospital, ending, and meta-memory audio;
- music, ambience, Foley, UI sound, nonverbal human textures, and authored
  silence;
- deterministic selection, anomaly handling, and spoiler-safe semantic IDs;
- Godot ownership, buses, playback topology, TTS ducking, and failure behavior;
- Pause, inactive-window behavior, Save, Load, crash recovery, and replay;
- free-to-use asset research, legal evidence, rejection, attribution, and
  permitted editing;
- mono, stereo, comfort, TTS, repetition, and accessibility verification; and
- current implementation drift and the required clean replacement boundary.

### 2.3 Out of scope

- downloading, purchasing, editing, importing, or shipping audio assets;
- composing, recording, generating, synthesizing, or AI-generating audio;
- recorded character voice acting;
- new narrative events, diagnoses, supernatural explanations, or ending logic;
- backward compatibility for an unshipped audio manifest or legacy Voice
  preferences; and
- a final mix before actual licensed assets have been selected and auditioned.

## 3. Project identity and hard constraints

The audio belongs to a short adult romantic psychological/supernatural horror
visual novel in pixel art. Romance may be tender, devotional, playful,
obsessive, poisonous, manipulative, ambiguous, tragic, or doomed. Horror is
subtle, elegant, dreamlike, surreal, noir, tense, uncanny, uncomfortable, and
occasionally dryly funny.

The production must preserve all of the following:

- no loud-sound or jump-scare dependency;
- no continuous text blips;
- no lyrical singing;
- no recorded character voice acting;
- rare human nonverbal breath, humming, or choir-like material only when its
  human provenance and license are verifiable;
- no supernatural theme that instructs the audience what to believe;
- no clue, choice, route, ending, or outcome that depends on hearing;
- no clue encoded only by stereo position;
- no offscreen speaking character introduced by environmental sound;
- no fake technical failure, fake corruption, or aggressive broken-game audio;
- dry absurd comedy may use timing and material contrast, but not cartoon
  boings, meme sounds, canned laughter, or borrowed internet shorthand;
- no asset copied from or melodically imitating DDLC, Yume Nikki, or Ib;
- no unlicensed Hong Kong transit chime, announcement, broadcast, or branded
  sonic identity; and
- no legal guess: unclear evidence produces `REJECTED` or `LEGAL REVIEW`.

“No painful frequencies” cannot be treated as a physically universal frequency
ban. Discomfort depends on level, duration, playback equipment, hearing
sensitivity, and spectral concentration. The enforceable replacement is modest
level, no surprise peaks, no sustained high-Q resonance used as punishment,
audience volume control, measured output, and listening tests across devices and
listeners.

## 4. Chosen direction and rejected alternatives

### 4.1 Chosen: Acoustic Memory Atlas

Most scenes use credible room tone, material action, or authored silence. Music
appears as an island at a physical source, transition, suspended emotional
threshold, ending, fragment, or approved profile-memory surface.

The production chain is:

`verified source and license evidence -> preserved original -> permitted edit master -> runtime export -> semantic catalogue -> deterministic plan -> AudioManager`

### 4.2 Chosen: acoustic-theatre restraint

The game borrows the discipline of an acoustic-theatre approach: rooms and
objects carry relationships before a score does. This is a restraint within the
Atlas, not a second architecture.

### 4.3 Rejected: track per screen, route, mood, or ending

Continuous contextual scoring would expose hidden importance, reduce silence to
missing content, produce excessive asset count, and convert moral ambiguity into
musical labels. Character-, mood-, `true`-, and ending-named track selection is
therefore retired.

### 4.4 Rejected: pure random unreliability

Reloading cannot reroll evidence or change what an anomaly meant. Randomness is
restricted to harmless environmental texture that cannot affect interpretation,
state, or eligibility.

### 4.5 Rejected: audio as an omniscient truth oracle

Audio can counterread emotion or misremember form. It cannot reveal private
desire, hidden relationship tier, future ending, supernatural mechanism,
unwitnessed culprit, or unavailable health information.

## 5. Audio narrator and knowledge boundary

The audio narrator is an unknown authorial force: not Angela, a love interest,
the supernatural, or the interface. It is the story's memory of itself.

It may:

- support the visible atmosphere;
- emotionally contradict the visible atmosphere;
- return a familiar texture imperfectly;
- omit a previously ordinary sound;
- reproduce an ordinary action in a subtly wrong order when the visible source
  and consequence make the mismatch inspectable;
- foreshadow a kind of feeling without identifying a fact; and
- respond to completed profile memory on explicitly approved meta surfaces.

It may know only what the audience has witnessed or what a canonical owner has
durably committed. It may not:

- read raw hidden affection or relationship tiers;
- choose a cue because of an ending that has not occurred;
- imply an absent character is physically nearby;
- prove who authored a contradictory record;
- confirm a supernatural or medical cause;
- turn an uncommitted hover, preview, or choice focus into evidence; or
- create new Observer evidence through History, replay, Settings tests, Load,
  or repeated playback.

Musical contradiction is an emotional counterreading, never factual testimony.

## 6. Cue taxonomy and scene grammar

### 6.1 Texture

Texture supplies credible environmental continuity: room air, equipment hum,
distant maintained machinery, sheltered rain, or restrained public activity.
It may be continuous, intermittent, omitted, or changed harmlessly after Load.

### 6.2 Signature

A signature is a rare recurring material associated with how a physically
present character handles the world. It is not a melody and never fires from a
hidden affection value.

- Angela: equipment hum, motors, keys, switches, instrument controls.
- Priscilla: paper, ceramic, clasps, measured footsteps, doors.
- Lavinia: breath, fabric, floor contact, rehearsal resonance, held stillness.
- Sylvia: badge clip, kit zipper, packaging, kettle, chair, prepared supplies.

### 6.3 Evidence

Evidence is an audible event with an established source and visible, physical,
or already-natural textual equivalent. Its selected identity is deterministic
and is not replayed as newly witnessed by History or Load.

### 6.4 Anomaly

An anomaly is a deliberate wrong order, omission, altered decay, or incompatible
return. It is rare, deterministic, and bounded by the scene's abnormality
budget. It cannot be the sole proof of anything important.

Each scene plan carries an anomaly-salience weight. Ordinary texture costs
nothing; a noticeable omission, wrong order, or incompatible return spends part
of the scene's finite budget. An ordinary scene normally permits zero or one
peripheral abnormality, and a relationship spotlight permits at most one
relational intrusion. Unspent budget is not filled merely to make the scene
stranger.

### 6.5 Music island

A music island is optional, bounded, and authored. It may be diegetic or
authorial, but the plan must say which. It never becomes default wallpaper.

### 6.6 Authored silence

- **Room-held silence:** speech or action stops while credible space remains.
- **Stripped silence:** one expected layer is deliberately absent while another
  physical layer remains.
- **Absolute silence:** all game audio is removed. This is rare and cannot hide
  an essential event.

An ordinary scene begins with a room texture or an explicit silence state and
contains zero to two foreground actions. Only one cue should request conscious
attention at a time.

## 7. Runtime ownership and architecture

### 7.1 Sole owner

`AudioManager` remains the sole owner of live music, ambience, UI, SFX, any
future recorded voice infrastructure, audio buses, gains, playheads,
crossfades, player pools, and registered channel tests.

Scenes, Dialogic timelines, Minesweeper, Settings, Gallery, ending hosts, and
other systems submit registered semantic intentions. They never construct or
control scene-local audio players.

### 7.2 Internal authorities

| Authority | Owns | Does not own |
|---|---|---|
| Audio asset catalogue | Neutral asset IDs, runtime paths, roles, license-ledger IDs, loop/edit/mix metadata | Story truth or live players |
| Audio-plan resolver | Deterministic mapping from permitted facts to a complete scene plan | Narrative mutation or playback |
| AudioManager | Live players, buses, fades, pools, ducking, capture, restoration | Narrative truth or asset licensing |
| ProfileManager | Validated global audio/TTS preferences and completed profile-memory facts | Run audio state |
| SaveManager/run owner | Durable semantic audio snapshot as part of the canonical save transaction | Live playback |
| System TTS coordinator | Compatible system voice, utterance arbitration, rate, completion and stop status | Game buses or final hardware speech volume |

### 7.3 Resolver inputs

Permitted inputs are:

- semantic scene and beat ID;
- physical location, established source state, and visibly present characters;
- already-committed witnessed actions and authored presentation surface;
- eligible profile memory only on approved title, Backup/Load,
  Gallery/Rehearsal, ending, or rare desktop-residue surfaces;
- stable replay mode; and
- validated user preferences.

Forbidden inputs are raw private desire, raw hidden affection tier, future
outcomes, preview-only choices, secret authorship, unconfirmed causes, or RNG
that can change evidence.

### 7.4 Scene audio plan

Each resolved plan is immutable for its semantic beat and contains:

- neutral plan ID and schema version;
- room texture or explicit silence state;
- permitted material, signature, evidence, and anomaly cues;
- optional music island and horizontal variant;
- for every diegetic cue: established source, distance, material, acoustic
  space, interruption behavior, and physical/visual equivalent;
- explicit `authorial` declaration for the only cues allowed to lack a
  physical source;
- anomaly-salience weight and remaining scene budget;
- entry and exit transition policy;
- concurrency and interruption priority;
- harmless texture seed, if any;
- curated Load resume anchor;
- physical or textual equivalent for every essential event; and
- asset-ledger IDs for every referenced file.

IDs must be neutral and spoiler-resistant, for example a location, day slot, or
sequence identity rather than `sylvia_special`, `lavinia_love`, or
`ending_true`. This is spoiler hygiene, not a security boundary.

Supported horizontal families are `base`, `quiet_altered`, `post_ending`, and
`witnessed_echo`. The last replaces a raw affection-flag micro-SFX: it may occur
only after the audience has witnessed and the game has committed the relevant
action. Real-time stems are not required. They may be considered only when the
source supplies separately identifiable, mutually aligned stems and every stem
passes the same legal and provenance gate.

### 7.5 Concurrency

- one logical music context; a second player exists only for transition;
- one logical room ambience; a second player exists only for transition;
- one protected evidence/anomaly cue;
- bounded material/SFX voices;
- bounded UI voices governed by SFX settings; and
- no repeated cue for every cell in a multi-cell Minesweeper reveal.

When a pool is full, the oldest lowest-priority decorative cue is dropped
first. Evidence is never stolen by decorative texture or ordinary UI feedback.

## 8. Bus, settings, and TTS design

### 8.1 Player-facing controls

Retain the approved visible controls and fresh defaults:

| Control | Default |
|---|---:|
| Master | 100% |
| Music | 80% |
| Ambience | 65% |
| SFX, including UI | 80% |
| Mute When Inactive | On |

There is no recorded Voice row. System TTS is external and does not inherit the
game's Master or channel setting. Legacy Voice fields do not become TTS
preferences.

### 8.2 Internal routing

Conceptual routing is:

```text
Master -- audience gain and final safety limiter
└── Game Mix -- internal uniform TTS duck, no visible preference
    ├── Music
    ├── Ambience
    ├── SFX
    └── UI -- governed by SFX preference
```

The final limiter is a safety guard, not a loudness strategy. Ordinary content
must retain headroom and must not rely on routine limiting. Offline validation
targets a final true-peak ceiling no higher than -1 dBTP; the commissioning mix
should normally retain at least 6 dB of pre-limiter peak headroom. Asset-class
loudness targets are finalized only after real candidates are selected, because
sparse ambience, short Foley, and music cannot be normalized meaningfully by
one shared integrated-loudness number.

### 8.3 Uniform TTS duck

Every live Read Aloud or TTS Test applies the same duck to the whole Game Mix.
The duck does not inspect speaker, line, character, route, affection, scene, or
importance.

Commissioning defaults are:

- gain reduction: -12 dB;
- fade down: 120 milliseconds before speech begins;
- fade up: 180 milliseconds after confirmed completion or stop;
- no full mute;
- no adaptive importance mode; and
- no persistent preference mutation.

Exact stop order is:

1. request TTS stop;
2. confirm completion/cancellation through the TTS coordinator;
3. release and complete the uniform duck recovery; and
4. play the restrained confirmation cue at normal game gain.

TTS failure, unavailable voices, or focus loss must always release the duck and
show factual status. Failure never becomes story audio.

## 9. Pause, inactive window, Save, Load, and replay

| Boundary | Required audio behavior |
|---|---|
| Universal Pause | Freeze exact music/ambience playheads and any crossfade legs, gains, and remaining transition time |
| Focus loss with inactive mute On | Use the same exact background-playback capture after admitted work reaches its stable frontier; stop TTS, tests, and one-shots |
| Focus loss with inactive mute Off | Music/ambience may advance; TTS, tests, and one-shots still stop |
| Ordinary Save | Persist semantic plan, deterministic variant/anomaly selection, and curated resume anchor; do not persist decorative one-shot tails as story facts |
| Load | Reconstruct the saved plan at its safe authored anchor; never reroll evidence |
| Crash recovery | Reconstruct the last durable semantic plan and discard incomplete decorative one-shots |
| Gallery exact replay | Use the registered replay plan; do not read current hidden relationship state or fabricate fresh witnessing |
| Post-ending title | Select the deterministic eligible profile-memory variant |
| New Run | Clear run audio facts while preserving eligible profile-memory facts |

Pause resumes the literal playhead because continuity is expected. Load resumes
at a plan-defined loop boundary, held room bed, variant entrance, or authored
silence because an arbitrary millisecond might begin inside a footstep, piano
attack, door impact, or breath.

Harmless environmental intervals may vary after Load. Evidence, anomaly,
omission, signature eligibility, and music-island identity may not.

## 10. Core material palette

Use five to eight recurring families; this design defines seven:

1. institutional air;
2. paper and control;
3. body and rehearsal;
4. care and preparation;
5. threshold and travel;
6. fragile music islands; and
7. negative space.

Hong Kong physical identity comes from credible room scale, sheltered exterior
texture, maintained university material, and restrained urban density. It does
not come from copied transit announcements, chimes, branded broadcasts, or a
generic musical stereotype.

## 11. Global surface placement

| Surface | Base treatment | Music and memory law |
|---|---|---|
| First-launch title | Faint maintained room/equipment presence or authored silence | No mandatory title theme and no memory anomaly |
| Post-ending title | Recognizable base with one deterministic alteration | Rare short post-ending island permitted from completed profile facts only |
| Bedroom/desktop | Computer/equipment hum, window and room detail | Usually no music; rare harmless post-ending residue |
| Contacts | Desktop bed and restrained notification | No continuous music; message order remains visible |
| Schedule | Quiet controls and accepted-command feedback | Eligibility never becomes audible |
| Shop | Dry confirmation/rejection | No jingle and no fictional failure |
| Backup/Load | Trustworthy mechanical feedback | Meta-memory may alter a tail but never command meaning |
| Settings | Underlying context remains | Only deliberate registered samples; samples create no story facts |
| Minesweeper | Dry reveal, mark, rejection, and result cues | One primary cue per accepted command; normally no music |
| Universal Pause | Exact frozen source scene | No pause theme |
| Gallery/Rehearsal | Registered replay plan | No gallery wallpaper and no evidence reroll |
| Hospital | Air, fabric, chair, restrained workflow | Normally no music; no monitor melodrama |

## 12. Seven-day acoustic progression

### Day 1: administrative uncertainty

Paper, copying, keyboards, and equipment checks establish the institutional
world. Lavinia's premature roster entry is visually inspectable and receives no
abnormal sting.

### Day 2: return and transit

Luggage, umbrella hardware, passing sheltered rain, returned seats, equipment
settings, and normal device cues support return. Priscilla's premature reply
uses no supernatural notification.

### Day 3: repetition

Earlier rooms become familiar. No compulsory new anomaly or added score is
needed merely because relational patterns are clearer.

### Day 4: preparation becoming uncomfortable

Packaging, welfare supplies, form handling, rehearsal adjustment, and hospital
air where applicable carry the day. The prefilled slip remains an object, not a
horror sound.

### Day 5: utility running out

Practical activity gradually stops. Packed objects, final clasps, chairs, and
closing doors lead into room-held silence. A visible rehearsal or social source
may support one music island.

### Day 6: implication

Equipment and final checks dominate. The location prompt uses the same
restrained notification family as other legitimate notifications. Its visible
record or expiry notice carries the importance.

### Day 7: public performance

The university becomes more inhabited without becoming louder or more
cinematic. Reception and rehearsal source music may exist. The decisive action
receives no route fanfare. Ending differences emerge through material action,
environmental withdrawal, and silence.

## 13. Event placement matrix

| Event | Foreground material | Music and silence law |
|---|---|---|
| The Programme Table | Paper alignment, folder, restrained room activity | No music; no cue for the premature name |
| The Borrowed Book | Cover, page, receipt, annotation handling | Quiet bookshop/campus bed; no sentimental cue |
| The Public Question | Public-room air, prompt card, restrained equipment | No success/failure music when Priscilla stops or speaks |
| No Task Left | Final clasp, packed material, chair settling | Activity ends into room-held silence |
| The Returned Seat | Chair/equipment setting, controls, normal message cues | No return theme; contradiction remains textual |
| Borrowed Gravity | Floor contact, shoes, fabric, bounded breath | No erotic exaggeration or pain cue |
| After the Music | Social room and visibly sourced recording | Optional classical/chamber source continues indifferently, then ends plausibly into room sound |
| Before It Hurts | Pace change, fabric, load adjustment, exterior threshold | No diagnosis or crisis sting |
| Exactly on Time | Equipment handoff, badge, sealed packaging | Hospital variant uses ordinary air/workflow, not monitor melodrama |
| A Quiet Table | Ceramic, kettle, chair, public-room texture | No cosy score validating Sylvia's predictions |
| The Caretaker's Break | Packaging, cup, chair, practical handoff | Reciprocal care remains unscored |
| Contingency | Kit zipper, paper slip, organized supplies | No ominous emphasis on prefilled information |
| Three Versions of the Sky | Paper, controls, visible rehearsal playback | Optional classical recording starts/stops through visible practical actions |
| After the Run-Through | Floor, fabric, transport preparation, visible key | Rehearsal residue may decay before negotiation; no pair theme |
| Day 2 Umbrella Pickup | Luggage, umbrella latch, transit threshold | No romantic theme or pair-counter signal |

## 14. Fragments and endings

### 14.1 Past fragments

Fragments have no shared memory theme:

- The Project Folder: paper, folder mechanism, overwritten-page handling.
- Before the Introduction: room murmur, glass, name-tag handling.
- Someone Else's Kitchen: key, ceramic, kettle, practiced domestic action.
- The Revised Form: correction paper, fabric, floor/rehearsal marking.
- Four Months Away: device and message residue without intelligible recorded
  acting.

A fragment may use wrong order only when the source objects and consequences
are visible enough to inspect. It never assigns relationship state, tone, or
ending eligibility.

### 14.2 Ending grammar

Thirteen catalogue identities do not produce thirteen musical themes.

- Closing Reception: inhabited room recedes; paper and ceramic remain.
- Stage Door: distant sourced rehearsal residue gives way to exterior air and
  body/floor material.
- Collect What Was Found: returned objects, kit, packaging, and deliberate
  placement dominate.
- Alone: astronomy controls, motors, equipment, and night room tone feel
  intentional and complete rather than abandoned or punished.
- Verification: interface and text prove incompatible lines; no supernatural
  confirmation sting.
- Restraint: withholding intervention receives no reward sound; the world
  continues or omits an expected ordinary event.
- Sylvia Special: reordered audio corresponds only to visible present-tense
  images such as badge, withdrawal, paper, interrupted objection, and
  treatment-room air. It never supplies method or medical cause.
- Priscilla-Lavinia: keys, transport, fabric, floor, and controlled distance;
  no secret-couple theme.
- Persistence: duplicate key sounds require both visible keys and cannot decide
  which is real.

The no-credits title return receives no credits cue. Only the eligible title
memory variant may follow.

## 15. Classical-music policy

“Classical music” is a repertoire description, not a license. Every candidate
must clear four separate layers:

1. composition;
2. modern edition, arrangement, transcription, completion, or orchestration;
3. human performance and neighbouring rights; and
4. exact sound recording/master.

The preferred path is a human-performed exact recording released by the
apparent rights holder under CC0 or CC BY, with identifiable performers,
arranger/editor status, stable source page, and direct license evidence.

Wikimedia Commons and IMSLP are file-level catalogues, not blanket clearance.
Musopen is discovery-only unless creator-side evidence corroborates the exact
recording. Public Domain Mark and expiry-only recordings are conditional for an
international release and require territorial review. Contradictory metadata is
rejected rather than reconciled by assumption.

Classical material is optional. Its principal likely homes are After the Music
and Three Versions of the Sky. It is not Lavinia's theme, a prestige marker, or
a shortcut for madness. Prefer fragile solo or small-ensemble performance;
avoid grand symphonic triumph, stereotypical evil violin, wedding shorthand,
and famous melody used merely as cultural decoration.

## 16. General legal gate

### 16.1 Shortlist-ready

- CC0 with exact asset-level provenance;
- CC BY with exact creator/licensor, versioned license, attribution, and change
  notice;
- OGA-BY or another clearly game-compatible attribution license whose exact
  terms permit commercial use and editing;
- clear creator-owned terms such as verified PeriTune-compatible terms;
- Sonniss GDC SFX terms for included files;
- Kenney CC0; and
- Mixkit SFX under its applicable SFX license.

### 16.2 Rejected

- CC BY-NC, NonCommercial, personal-use-only, or ambiguous commercial use;
- CC BY-ND or any term preventing required editing and format conversion;
- CC BY-SA and other ShareAlike/copyleft terms under this project's hard filter;
- unclear royalty-free, “no copyright,” or YouTube/social reuploads;
- Mixkit music;
- missing or conflicting exact-file evidence;
- AI-generated music or SFX;
- Freesound items tagged or described as AI, GenAI, or generated;
- human vocal material without credible human-recording provenance; and
- any candidate whose composition, arrangement, performance, or recording
  evidence cannot be separated where necessary.

If evidence is unclear, the status is `REJECTED` rather than “probably safe.”

## 17. Asset research package

The initial search defines approximately thirty roles:

- seven ambience roles;
- twelve Foley/material roles;
- five UI/gameplay roles;
- four to five music-island roles, including classical; and
- two restrained human nonverbal texture roles.

Each role seeks one preferred candidate and one legal/artistic fallback. Silence
is a valid result when neither candidate deserves production use.

Every candidate record contains:

- exact title and creator, recorder, or performers;
- direct source page and exact downloadable file identity;
- direct license page, license type, and version;
- commercial-game permission;
- modification permission;
- required attribution and change notice;
- restrictions and territorial caveats;
- AI/GenAI evidence check;
- source-material and recording description;
- proposed scene and cue-taxonomy placement;
- permitted edit recipe, if any;
- loop, mono, comfort, and repetition observations;
- retrieval date and evidence capture; and
- `APPROVED`, `CONDITIONAL`, `REJECTED`, or `LEGAL REVIEW` status.

Search order for music is PeriTune and similar creator-owned libraries,
OpenGameArt CC0/CC BY, purpose-built CC0 classical projects, individual
Wikimedia/IMSLP files, then FMA/ccMixter only with unmistakable commercial
adaptation permission. Pixabay receives heightened caution. Mixkit music is not
searched.

Search order for SFX/ambience is Sonniss GDC, Kenney CC0, individual Freesound
CC0/CC BY files with AI checks, Mixkit SFX, OpenGameArt, then ZapSplat or Pixabay
only when exact conditions are acceptable.

## 18. Source, edit, runtime, and attribution pipeline

The future production layout should preserve four distinct states:

1. **Evidence and preserved original:** original download, checksum, source and
   license capture, creator metadata, retrieval date, and status.
2. **Edit master:** lossless permitted edits with a human-readable recipe and
   no overwritten original.
3. **Runtime export:** game-ready long-stream or short-one-shot form with
   measured gain, loop, and import settings.
4. **Semantic registration:** neutral asset ID, role, plan eligibility, and
   attribution-ledger link.

Source originals should live in a Godot-ignored source tree so the editor does
not import them accidentally. Runtime exports alone live in the active audio
tree. The implementation plan must choose exact paths and add structural checks
before files are acquired.

Permitted edits, when licensed, include trimming, clean fades, loop-seam
construction, gain normalization, gentle corrective EQ, removal of unusable
leading/trailing noise, stereo narrowing for mono safety, format conversion,
resampling, and a quieter horizontal variant derived from the preserved source.

No edit may synthesize missing material, clone a voice, generate an extension,
invent a performance, hide provenance, or exceed the license. Added impulse
responses or other third-party processing material require their own evidence
records.

Attribution is available from title-hosted Settings and is also recorded in
`THIRD_PARTY_NOTICES`; endings do not become credits sequences. Required format
is `Title / Author or Performer / Source / License`, plus a change notice where
required.

## 19. Mixing, comfort, and accessibility

- headphone-first detail with complete mono compatibility;
- restrained stereo anchored to the visible tableau;
- no essential clue solely in panning, width, reverberation, or hearing;
- no continuous text blips;
- no loud horror spikes;
- no sustained resonant tone used to punish the audience;
- no route or ending distinguished only by loudness;
- no TTS line assigned a different duck because of importance;
- one foreground cue at a time where practical;
- music and ambience evaluated for fatigue over extended replay;
- UI confirmation quiet enough to tolerate frequent use; and
- every essential sound supplied with a simultaneous physical, visual, or
  already-natural textual equivalent rather than a global optional sound-caption
  stream.

This is a narrow audio-equivalence clarification. Spoken dialogue remains
captioned. There is no separate optional stream that mechanically emits labels
such as `[door sound]`. If an essential nonverbal event is not completely
communicated by its visible physical action or existing prose, the authored
scene must include a natural textual or physical representation as part of the
event itself.

## 20. Failure and truthful fallback

- Missing optional music falls back to the registered room texture or authored
  silence, never a different semantic track.
- Missing ambience falls back to authored silence and a factual diagnostic.
- Missing essential sound leaves its visual/textual equivalent intact and logs
  the missing registered asset; it does not substitute an unrelated cue.
- A failed context transition restores the last determinate live state.
- An indeterminate audio transaction blocks conflicting audio mutation and uses
  the trusted technical recovery surface.
- TTS failure always releases ducking.
- Technical failure never creates a story anomaly, horror sting, fake save
  corruption, or supernatural clue.

## 21. Current implementation drift and supersession

The current `AudioManager` already provides useful sole ownership, double-player
music/ambience transitions, SFX/UI pools, semantic requests, settings
application, and rollback concepts. Retain those principles.

The current physical implementation does not yet satisfy this design:

- `AudioManifest` lists continuous screen, friend, mood, route, and
  ending-specific music IDs;
- retired `*_true` concepts remain in its inventory;
- jealousy/desire mine stingers remain registered;
- dating music resolution reads friend and mood/attitude fields directly;
- semantic Save/Load restoration restarts contexts rather than applying the
  approved curated-anchor model;
- exact inactive playhead/crossfade capture is not yet implemented by the
  visible focus-loss behavior; and
- Voice preferences remain in runtime settings/snapshot validation despite the
  accepted no-recorded-Voice player-facing design.

This specification also narrows older general essential-sound caption wording:
essential meaning remains fully equivalent, but the game does not add a second
optional sound-label stream. Spoken captions and natural authored textual or
physical evidence remain intact.

Because the game has never shipped and compatibility is waived, the
implementation plan must replace these expectations directly. It must not add
aliases or fallback mappings that preserve the rejected model.

## 22. Verification matrix

### 22.1 Structural and ownership

- only AudioManager owns live players and bus mutation;
- every runtime asset has one catalogue record and evidence-ledger link;
- scenes contain no direct audio-player ownership;
- semantic IDs contain no avoidable route/ending spoilers;
- retired `true`, friend-theme, ending-theme, and mine-stinger IDs are absent;
- no visible Voice setting or legacy-to-TTS mapping remains.

### 22.2 Determinism and truth

- save/reload cannot reroll evidence, anomaly, omission, signature eligibility,
  or music-island identity;
- harmless texture variation cannot affect interpretation;
- hidden tiers and future endings are not resolver inputs;
- wrong-order sound always has a visible/physical inspectable basis;
- missing assets never substitute semantic meaning;
- replay and Settings tests create no witnessed or Observer evidence.

### 22.3 Playback lifecycle

- Pause resumes exact playheads and transition state;
- inactive mute captures and resumes exact background state;
- inactive-audio continuation does not resume stopped TTS/tests/one-shots;
- Load enters at the registered anchor and selected variant;
- rapid focus changes are idempotent;
- failure rollback preserves the last determinate state.

### 22.4 TTS and settings

- fresh values are Master 100, Music 80, Ambience 65, SFX 80, inactive mute On;
- effective game gain obeys Master multiplied by channel gain;
- UI obeys SFX;
- TTS remains outside game volume ownership;
- every utterance receives the same -12 dB duck with 120 ms down and 180 ms up;
- Stop confirms TTS end, releases duck, then plays confirmation;
- unavailable or failed TTS cannot leave the game ducked.

### 22.5 Legal and provenance

- every shortlist entry has exact source and license pages;
- commercial use and modification are explicit;
- attribution and changes are recorded;
- classical layers are cleared separately;
- NC, ND, SA, unclear, conflicting, reuploaded, Mixkit-music, and AI candidates
  are rejected under project policy;
- preserved originals and checksums remain available;
- every runtime export has a reproducible permitted edit recipe.

### 22.6 Listening and accessibility

- mono-first blind tests do not tell listeners which cues matter;
- separate stereo tests detect cancellation, width, and headphone discomfort;
- panning cannot change story comprehension;
- routine content retains headroom and the limiter does not become the mix;
- representative headphones and ordinary speakers pass comfort checks;
- long-loop and repeated-UI fatigue tests pass;
- multiple installed system voices remain intelligible under the uniform duck;
- every essential auditory event has a complete non-audio equivalent.

## 23. Deliverables after written approval

The next phase produces, in order:

1. a role-based search ledger with primary and fallback candidates;
2. a rejection log with explicit legal or artistic reasons;
3. a source/license evidence packet for every surviving candidate;
4. an attribution draft;
5. a scene-to-candidate placement matrix;
6. proposed permitted edit recipes and import settings;
7. a listening-test sheet; and
8. an implementation plan for the catalogue, resolver, AudioManager
   reconciliation, persistence, buses, tests, and eventual asset intake.

Research does not itself authorize downloading or integrating an asset. The
shortlist is reviewed before acquisition and runtime work.

## 24. Acceptance

The user approved the complete written specification on 2026-08-14 after
approving its three design sections and classical-music correction separately.
This acceptance authorizes the research and planning phase. It does not
authorize unreviewed asset acquisition, audio integration, or runtime-code
implementation.
