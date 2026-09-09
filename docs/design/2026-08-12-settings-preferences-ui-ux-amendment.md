---
id: spec.settings_preferences_ui_ux_amendment
kind: design_amendment
schema_version: 1
amends: spec.seven_day_dialogic_flow
amends_path: "docs/design/2026-08-07-seven-day-dialogic-flow-design.md"
decision_status: accepted
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
self_reviewed_on: "2026-08-12"
written_spec_approved_on: "2026-08-12"
implementation_authorized: false
created_on: "2026-08-12"
engine_line: godot_4_6
verification_engine: 4.6.3-stable-mono
language: gdscript
scope: ["settings_hosts_and_navigation","language_and_dual_language_preferences","reading_caption_and_tts_preferences","audio_preferences_tests_and_inactive_suspension","display_window_and_dark_run_configuration","input_bindings_and_resets","accessibility_text_motion_target_and_colour_preferences","profile_partition_view_cache_and_reset_truth"]
---

# Settings, Preferences, and Accessibility UI/UX Amendment

## 1. Status and objective

This accepted written amendment records the conversationally approved
Settings, preference, accessibility, input, audio, inactive-window, and
Dark-mode configuration design discovered while preparing the game's future
UI/UX, visual-art, and music/audio manuals.

The user approved this exact written amendment on 2026-08-12. It is the
accepted product and design authority for its bounded scope, but it does not
authorize implementation. Requirement packets, Beads, hash-bound plans,
schemas, migrations, tests, scenes, localization catalogs, and runtime code
remain unchanged until separately reconciled and explicitly authorized.

Settings is a trusted old-university operating-system surface. It may be rough
in material, quiet in composition, and liminal in its unused space. It may not
manufacture unease by lying about a committed preference, secretly changing a
run, hiding an unavailable capability, simulating a technical failure, or
making an accessibility control that does not physically work.

The design has four objectives:

- keep the same understandable seven-category surface at 100%, 125%, and 150%
  text size;
- apply ordinary profile presentation choices immediately and truthfully;
- keep profile preferences, one-shot Dark intent, and captured run
  configuration in separate owners; and
- expose only features that have real, tested behavior.

### 1.1 Derived closure ledger

The conversation fixed the product direction and most defaults. This accepted
written pass fixes the following exact closures so later code cannot invent
them:

- Text reveal uses stable IDs and exact rates: Instant publishes one completed
  beat atomically; Fast reveals at 60 grapheme clusters per foreground second;
  Normal at 30; and Slow at 15. Authored semantic pauses remain part of the
  narrative atom and are not erased by the preset.
- Auto delay begins only after the complete presentation atom has become
  available. Short is 1.0 foreground second, Normal is 2.0, and Long is 4.0.
  Auto advances only after both that delay has elapsed and the atom's effective
  Read Aloud utterance has completed or been deliberately stopped.
- Read Aloud rate uses the system speech service at 0.8, 1.0, or 1.2 times its
  normal supported rate for Slow, Normal, or Fast.
- Screen Shake maps to exact normalized amplitudes Off 0.0, Low 0.5, and Normal
  1.0. Low is the fresh-profile default.
- Fresh audio defaults are Master 100%, Music 80%, Ambience 65%, and SFX 80%,
  all unmuted. Effective authored-channel gain is Master multiplied by that
  channel's gain. Master mute or a channel mute silences that channel.
- System TTS is not recorded character voice and is not routed through Master,
  Music, Ambience, or SFX. The operating system owns its final output volume.
- Mute When Inactive defaults On. When On, music and ambience pause at their
  exact playhead positions. When Off, music and ambience alone may continue.
  Narrative, gameplay, input, notifications, Auto, generators, and other
  foreground-time behavior suspend in both cases.
- A Settings preview, TTS utterance or test, and one-shot SFX/UI test stops on
  focus loss and does not restart automatically. Music and ambience are the
  only samples that may resume from an exact playhead.
- A pointer-dragged slider previews live and commits one durable value on
  release. A keyboard, controller, or accessibility step commits immediately.
  Losing focus while a drag is active ends admission and commits the last
  visibly accepted value or restores the prior committed value if publication
  fails.
- Legacy continuous values migrate deterministically. Text-speed multipliers
  select the nearest of Slow 0.5, Normal 1.0, or Fast 2.0, with a tie selecting
  the slower preset, and never infer Instant. A finite positive legacy
  auto-speed value first becomes
  `2.0 / legacy_auto_text_speed` seconds, then selects the nearest delay among
  1.0, 2.0, and 4.0 seconds; a tie selects the longer delay. Invalid values use
  Normal. Font scale selects the nearest supported 1.0, 1.25, or
  1.5 value. A tie selects the larger presentation value. Shake 0 maps to Off,
  values above 0 and below 0.75 map to Low, and values at least 0.75 map to
  Normal.
- A legacy scalar locale becomes Primary Language. Secondary Language becomes
  the first other selectable locale in canonical registry order and Dual
  Language defaults Off. If no second locale exists, the secondary row remains
  visible and truthfully unavailable.
- A legacy fullscreen false value maps to Windowed; true maps to Borderless.
- Every stored valid legacy focus-mute Boolean maps unchanged to Mute When
  Inactive. A fresh profile defaults it On. The old pause-on-focus-loss
  field is retired because safe foreground suspension is now invariant.
- Legacy Voice volume and mute values do not become TTS preferences. They are
  retired because the initial release has no recorded voice acting.
- Legacy subtitle, caption, speaker-name, opacity, visual-audio-cue, flashing,
  focus-ring, hold-to-confirm, controller-cursor, tutorial-replay, and
  pause-on-focus-loss leaves are removed during migration. Their old values do
  not weaken the guarantees in this amendment, unlock exceptional replay, or
  create replacement controls.
- The category rail scrolls vertically if its localized labels cannot fit at
  150%. It never narrows the right sheet, shrinks text, clips a category, or
  creates horizontal scrolling.
- A binding capture ignores the activation event that entered capture.
  Multi-conflict capture lists every overlapping same-device action and allows
  one atomic ordered swap plan or Cancel; it never silently displaces several
  bindings.

## 2. Authority and precedence

### 2.1 Authority spine

This amendment controls intended behavior within its eight frontmatter scope
topics over conflicting recovered documents,
requirement packets, proposed or hash-bound plans, tests, schemas, and current
Settings scaffolds.

It narrowly amends the accepted 2026-08-07 Seven-Day Flow and Dialogic
Structure design. That design retains authority for narrative presentation
receipts, skip/visited behavior, Dark-mode Angela's unlock predicate and
romance/ending mechanics, exceptional-ending Full/Residue law, and all
unrelated Schedule, Hospital, relationship, ending, Gallery, Observer,
persistence, and recovery law.

The accepted 2026-08-11 Desktop Minesweeper, Shop, and Schedule amendment
retains authority for exact candidate and board persistence, cross-app
continuity, and the right to apply global presentation preferences while a
board exists. Settings changes never mutate a frozen candidate or active
board's gameplay facts.

The accepted 2026-08-12 Shop, Contacts, and Backup amendments retain authority
for their app-local layouts, transactions, caches, trust boundaries, and
restore behavior. This amendment supplies their shared preference inputs. It
does not reinterpret a Shop purchase, Contacts read, Backup record, or saved
Schedule view.

The Core Story Bible remains narrative authority except for one narrow TTS
supersession in section 9.5: live and History Read Aloud now speak only the
primary display language. The native-language original remains available
visually under its accepted caption and History rules but is not automatically
spoken before the primary translation.

Beads owns mutable work status, dependencies, and implementation evidence.
Approved product law does not itself authorize runtime, plan, packet, schema,
test, or Beads mutation.

### 2.2 Current physical and execution state

At the time of writing:

- implementation is not authorized;
- dwm-p2r.3 is closed historical evidence for the older Profile,
  Localization, and Audio scaffold and must not be reopened;
- dwm-0hi is executing a different exact reconciliation scope and must not be
  silently widened;
- no dedicated Settings authority or implementation Bead exists;
- the proposed August roadmap and child plans are hash-bound and cannot be
  edited silently;
- current machine authority discovery does not yet register design amendments
  in this folder;
- the current Settings scenes expose a small generic schema-driven scaffold,
  not this design; and
- current accessibility, focus-loss, TTS, window-mode, Dark capture, and
  dual-language behavior do not physically satisfy this amendment.

No support, compatibility, validation, or implementation claim follows from
this document.

## 3. Scope boundary

### 3.1 In scope

This amendment closes:

- the shared title and in-run Settings composition;
- the seven-category rail, sheet, focus, scrolling, Back, and cache grammar;
- primary, secondary, and Dual Language preferences;
- reading, Auto, Skip, caption, History, speaker-announcement, TTS, and
  exceptional-replay controls;
- Master, Music, Ambience, SFX, manual tests, defaults, and mute behavior;
- safe inactive-window suspension;
- Windowed and Borderless application;
- Dark entitlement, pending next-run selection, captured run configuration,
  save/load isolation, and reset boundaries;
- keyboard/controller binding slots, context conflicts, Swap, Cancel, and
  Restore Controls;
- text size, target size, contrast, motion, shake, colour differentiation, and
  semantic specimen behavior;
- profile, view-cache, save, and reset ownership; and
- truthful application, rollback, failure, migration, and verification rules.

### 3.2 Out of scope

This amendment does not:

- implement the design or authorize implementation;
- create recorded character voice acting;
- choose final system-voice assets, because the operating system supplies
  them;
- add arbitrary user-defined colours, a whole-screen colour filter, 200% text,
  exclusive fullscreen, resolution selection, mouse-button rebinding, or
  mobile lifecycle;
- change Dark-mode Angela's story mechanics, ending precedence, or unlock
  predicate;
- change the prose or branches of a narrative timeline;
- change saved gameplay except for the explicit captured Dark run fact;
- delete Backup records;
- claim WCAG, XAG, screen-reader, colour-vision, battery-saving, or general
  accessibility conformance before the exact supported surface is physically
  tested; or
- finalize art, fonts, sound files, localized copy, or platform export policy.

## 4. Chosen design and rejected alternatives

### 4.1 Shared logical Settings composition

One shared logical Settings content scene is hosted by both the main-menu shell
and the in-run desktop application. Host chrome may differ, but categories,
control semantics, defaults, order, assistive names, commit behavior, and
failure law do not.

The screen uses a fixed directory rail on the left and one independently
scrollable category sheet on the right. It resembles an old maintained
university workstation: square geometry, disciplined ink, paper-like surfaces,
restrained registration texture, and generous dead space. Roughness belongs to
noninteractive material. Text, focus, controls, and state remain exact.

Preferences commit immediately. There is no page-wide Apply or Cancel. A
control whose platform operation can fail prepares the new value, applies it,
persists it, and publishes it as one recoverable command. Failure restores the
last committed preference and presentation.

### 4.2 Rejected alternatives

#### One long undivided settings page

Rejected because it makes seven different conceptual owners difficult to
navigate, localize, cache, and test.

#### Modal Apply and Cancel for the whole window

Rejected because most choices are reversible global presentation preferences
whose effect should be inspectable immediately. One giant draft would also
mix unrelated failures and make system TTS, window mode, and colour preview
less truthful.

#### Major layout reflow at 150%

Rejected for the initial release. The audience asked to preserve the same
positions and learnable composition. The rail and sheet use local scrolling
and wrapping instead.

#### Whole-screen colour-blindness shader

Rejected because it distorts character art and narrative colour without
guaranteeing that functional states become distinguishable. The chosen design
authors semantic interface palettes and redundant non-colour cues.

#### Hard-freezing the process immediately on focus loss

Rejected because it could strand a save, restore, generator, or other bounded
atomic operation. The chosen state reaches a safe frontier before parking
background work.

#### Saving all Settings inside each run

Rejected because Load would unexpectedly rewind language, audio, input, text
size, TTS, and accessibility. Only Dark-mode gameplay configuration belongs to
the run.

## 5. Domain vocabulary and ownership

### 5.1 Profile preference

A profile preference is global player-facing presentation or input state.
Language, reading, audio, window mode, controls, TTS, text size, contrast,
motion, target size, colour differentiation, and exceptional-replay selection
are profile-owned. They apply to the current presentation and survive ordinary
run replacement. Load never rewinds them.

### 5.2 Entitlement and pending next-run choice

Dark availability is a durable profile entitlement earned by the accepted
four-ending predicate. It is independent of the current Gallery projection
after acquisition.

The main-menu Dark switch is a separate durable Boolean pending choice for the
next successful New Run. It is not current-run authority and is not an ordinary
resettable preference.

### 5.3 Captured run configuration

Dark-mode enabled for a run is an immutable run-configuration Boolean captured
at successful New Run creation. It is serialized by every run save and branch.
It controls that run's palette and Dark-Angela mechanics. It is the only
Settings-related fact restored from a run save.

### 5.4 Effective accessibility state

Effective presentation is resolved from:

- the current host or captured run base palette;
- High Contrast Off or On;
- Standard, Protan, Deutan, or Tritan colour differentiation;
- 100%, 125%, or 150% text size;
- ordinary or Large Targets; and
- Reduced Motion plus the remembered shake selection.

Effective state is derived. It is not a second mutable preference bag.

### 5.5 Presentation cache

Selected category, sheet scroll, rail scroll, and focused semantic control are
view state. They are never profile or run save facts. A preview or sample has
no cached position and is discarded whenever its category or Settings hides.

### 5.6 Closed persisted vocabulary

The target profile vocabulary is exact. Physical schema versions and storage
layout belong to later reconciliation, but semantic IDs, types, values, and
fresh-profile defaults are fixed here:

| Semantic field | Type / allowed values | Default |
|---|---|---|
| language.primary_locale_id | registered locale ID | en |
| language.secondary_locale_id | registered locale ID distinct from Primary when possible | first other canonical locale |
| language.dual_enabled | Boolean | false |
| reading.reveal_speed | instant, fast, normal, slow | normal |
| reading.auto_enabled | Boolean | false |
| reading.auto_delay | short, normal, long | normal |
| reading.skip_mode | read_only, all_text | read_only |
| reading.read_aloud_enabled | Boolean | false |
| reading.read_aloud_rate | slow, normal, fast | normal |
| audio.master_volume | finite 0.0 through 1.0 | 1.0 |
| audio.master_muted | Boolean | false |
| audio.music_volume | finite 0.0 through 1.0 | 0.8 |
| audio.music_muted | Boolean | false |
| audio.ambience_volume | finite 0.0 through 1.0 | 0.65 |
| audio.ambience_muted | Boolean | false |
| audio.sfx_volume | finite 0.0 through 1.0 | 0.8 |
| audio.sfx_muted | Boolean | false |
| audio.mute_when_inactive | Boolean | true |
| display.window_mode | windowed, borderless | windowed |
| accessibility.text_size | 100, 125, 150 | 100 |
| accessibility.large_targets | Boolean | false |
| accessibility.high_contrast | Boolean | false |
| accessibility.reduced_motion | Boolean | false |
| accessibility.screen_shake | off, low, normal | low |
| accessibility.colour_differentiation | standard, protan, deutan, tritan | standard |
| exceptional_replay.available | Boolean, capability-owned | false |
| exceptional_replay.replay_full | Boolean | false |
| dark_mode.available | Boolean, entitlement-owned | false |
| dark_mode.next_run_enabled | Boolean | false |
| input_mappings | closed per-action keyboard/controller records | registered defaults |

The run vocabulary adds exactly one Settings-originating gameplay field:
run_configuration.dark_mode_enabled, a Boolean captured at New Run and defaulted
false only by the explicit legacy migration.

No persisted voice selector exists. The operating-system default compatible
voice is resolved at use time.

## 6. Hosts, composition, and navigation

### 6.1 Title and in-run hosts

Both hosts instantiate the same logical content. The title host uses the
current title palette. The in-run host uses the run's captured base palette
with the current global accessibility modifiers.

Dark Mode is not shown inside Settings. Its one-shot switch remains in the
main-menu New Run area.

### 6.2 Category rail and sheet

The exact rail order is:

1. Language
2. Reading
3. Audio
4. Display
5. Controls
6. Accessibility
7. Records

The rail and sheet scroll vertically and independently. Neither scrolls
horizontally. Long labels wrap. Text is never clipped, ellipsized, overlapped,
or silently shrunk.

At 100%, 125%, and 150%, the macro positions stay recognizable. A rail overflow
scrolls while preserving the selected category. The sheet ensures the focused
control remains visible with a stable inset.

### 6.3 Focus and Back

On a fresh host, focus begins on Language in the rail. Arrows or D-pad move
through the rail. Right or Tab enters the active sheet. Left or Shift+Tab from
the sheet returns to its category. Page Up/Page Down or approved semantic
actions scroll the sheet without changing preference state.

Back follows this order:

1. cancel binding capture or close the active confirmation;
2. stop an active preview or test;
3. return from sheet focus to the selected rail category; and
4. close Settings through its host.

Pointer hover never changes selection or focus. Touch selection and assistive
activation use the same semantic commands.

## 7. Commit, rollback, and live-application grammar

Every reversible preference command follows:

1. validate the semantic value against a closed registry;
2. capture the prior durable preference and effective presentation;
3. prepare any platform or consumer application;
4. apply the new presentation silently;
5. durably commit the profile value;
6. publish one preference-changed event and assistive value change; and
7. discard the rollback capture.

If platform application or persistence fails, restore the prior presentation
and preference. If durable outcome is indeterminate, block conflicting
mutations and reconcile storage before claiming success or rollback.

Locale, palette, window, audio, TTS, input, and reset commands may require
specialized coordinators, but none may publish half a change. A cached hidden
window and every future-created window receive the committed effective state.

Sliders preview during pointer drag but create only one durable command on
release. Keyboard/controller steps are discrete commands. A visible value can
never claim commitment while only a transient preview exists.

## 8. Language and dual-language behavior

### 8.1 Closed controls

Language contains:

- Primary Language;
- Dual Language Off or On, default Off; and
- Secondary Language.

Primary controls ordinary UI localization and the first narrative display
language. Secondary is used only for the approved dual narrative/caption
projection and its corresponding History row.

Secondary remains visible while Dual is Off but is disabled with a truthful
reason. If fewer than two selectable locales exist, Dual and Secondary remain
visible and unavailable.

### 8.2 Atomic selection and same-language swap

Primary, Secondary, and Dual form one validated profile record. A command
changes the record atomically.

Choosing the current Primary as Secondary, or current Secondary as Primary,
swaps them. It never creates two equal active language positions.

Changing Primary updates ordinary UI and active narrative projection
immediately without changing canonical line identity, read state, branch,
History identity, or gameplay.

### 8.3 Independent fallback

Every UI key and every narrative row resolves independently through its
registered locale fallback chain. A missing row never drops, merges, delays,
or reorders its partner.

In dual mode, requested and resolved locale/status remain inspectable in
development evidence. Public released locales must meet their registered
coverage gate. Development and QA builds always show a compact truthful
fallback indicator on a fallback row without changing semantic identity.

If both dual rows resolve to identical text, both remain present for
translation comparison. History freezes displayed requested/resolved/status
facts as immutable per-entry content/presentation receipts. Those receipts
preserve the text and locale resolution actually presented; they are not saved
language preferences, never restore or override Primary/Secondary/Dual, and do
not prevent later entries and ordinary UI from using the currently committed
language tuple. Gallery replay uses current catalogs under its separate law.

### 8.4 Caption presentation

In single-language mode, the current caption beat and the previous two
available beats form the visible three-beat stack. At the beginning of a
sequence, only the beats that already exist are shown.

A native-original-plus-translation pair is one semantic beat and occupies one
card in that three-beat stack; its two rows never consume two beat positions.

In dual-language mode, only the current semantic beat appears: Primary first,
then its corresponding Secondary row. No prior beat remains on screen.

Native-language originals follow the accepted story rule: single-language
presentation shows the native original before its translation; dual
presentation omits the extra native row from the live caption and retains it
in History.

## 9. Reading, dialogue, captions, and TTS

### 9.1 Reading controls

Reading contains:

- Text Reveal: Instant, Fast, Normal, Slow; default Normal;
- Auto Dialogue: Off or On; default Off;
- Auto Delay: Short, Normal, Long; default Normal;
- Skip: Read Only or All Text; default Read Only;
- Read Aloud: Off or On; default Off;
- Read Aloud Rate: Slow, Normal, Fast; default Normal; and
- one TTS Test/Stop action.

Auto Delay is visible while Auto is Off but disabled. Read Aloud Rate and Test
remain visible when Read Aloud is Off; Test may be used deliberately without
enabling live Read Aloud.

### 9.2 Presentation receipts

Instant reveal, Auto, Skip, TTS, and accessibility activation preserve the
accepted presentation-receipt law. A line counts as presented only at its
registered boundary. A test specimen never creates a presentation receipt.

Skip cannot cross an unresolved choice, effect, marker, route, or other
accepted semantic boundary. Auto does not advance behind a modal or while the
window is inactive.

Auto's delay begins at visual completion, but advancing requires both the
remaining foreground delay to reach zero and the current effective Read Aloud
utterance to complete or be deliberately stopped. Focus loss pauses the delay
and stops the utterance without replay; after refocus, only the remaining delay
continues. A missing or disabled compatible voice creates no speech gate.

### 9.3 Caption guarantees

Dialogue text cannot be disabled. There is no subtitle/caption enable switch,
visible speaker-name switch, background-opacity control, non-speech-caption
stream, or visual-audio-evidence toggle.

No important evidence is audio-only. Nonessential sound creates atmosphere
and may be missed. Essential visible events may have accompanying sound, but
their visible state is complete without it.

### 9.4 Speaker disclosure

Visible caption cards do not show a routine speaker label. Each authored line
still carries a stable public speaker/disclosure token for History and
assistive presentation.

Read Aloud announces an already disclosed speaker only when the disclosed
speaker changes. It never reads a hidden internal actor ID or turns ambiguity
into a name.

### 9.5 Read Aloud and system voices

Read Aloud uses the system speech service, one audience TTS voice policy, and
the Primary display language only. This narrowly supersedes the older Core
Story Bible sentence that automatically spoke a native original before the
first translation during History replay.

There is no in-game voice picker. The service resolves a compatible installed
system voice for Primary. It never downloads a voice or substitutes a known
wrong-language voice.

If no compatible voice exists, the controls remain visible with the factual
status No compatible system voice found. The toggle and rate/test controls are
disabled without changing the stored desired value, and effective speech is
unavailable. If a compatible voice later returns, no old or current line is
replayed automatically; when the stored desired value is On, live speech
resumes only on the next newly presented line.

Only one utterance may own speech. A new live line, deliberate Test, Skip, app
departure, Settings departure, or focus loss stops the current utterance.
Stopped utterances do not resume automatically.

Read Aloud never changes read state, choice, branch, History identity, or
Observer evidence. Its Test uses the neutral specimen only.

### 9.6 Exceptional replay

Records shows Replay discovered exceptional scenes in full only after its
accepted profile unlock. It defaults Off.

Changing it affects future canonical ending-plan preparation only. It cannot
mutate an already frozen ending plan or fabricate an undiscovered Full entry.
Gallery replay remains Full for every discovered exceptional identity
regardless of this choice. Restore Preferences returns the choice Off without
removing its availability.

## 10. Audio settings and tests

### 10.1 Visible channels and defaults

Audio contains:

| Row | Default volume | Default mute | Test |
|---|---:|---|---|
| Master | 100% | Off | none |
| Music | 80% | Off | registered Music sample |
| Ambience | 65% | Off | registered Ambience sample |
| SFX | 80% | Off | registered SFX/UI sample |

Mute When Inactive appears below the channels and defaults On.

Keyboard, controller, and assistive volume increments change a row by exactly
5 percentage points and clamp at 0% and 100%. Pointer drag retains the section
7 preview-and-commit grammar.

There is no recorded Voice row. An internal Voice bus or player pool may remain
as dormant infrastructure, but it has no player-facing preference until
recorded voice content is separately approved and authored. System TTS is
separate.

### 10.2 Gain and mute

For Music, Ambience, and SFX, effective linear gain is Master gain multiplied
by channel gain. Master mute, channel mute, or either gain at zero produces
silence.

SFX owns ordinary UI sounds consistently. No visible setting can mute only the
semantic confirmation cue while leaving an otherwise identical gameplay cue
audible.

TTS does not obey Master or channel mute. Its availability and final hardware
volume belong to the operating-system speech path.

### 10.3 Manual tests

Tests never autoplay. A Test becomes Stop while active. Starting another test
stops and replaces the current test.

A channel Test respects Master, its channel mute, and zero volume. When it
would be silent, Test is disabled with the visible reason Muted or Volume is
0. It never bypasses or changes the audience's mute choice.

Music and Ambience tests temporarily suspend that channel's current semantic
context, play one registered noncanonical sample, and restore the exact prior
context and playhead when stopped or complete. SFX Test uses one registered
neutral cue. No sample enters a save, receipt ledger, History, or gameplay
state.

Missing registered audio retains the previous context and shows a factual
unavailable status. It never falls back to story audio whose meaning differs.

## 11. Inactive-window quiet suspension

### 11.1 State machine

Window deactivation and minimization use one lifecycle:

Active -> Draining -> Suspended -> Active.

On focus loss:

1. input admission becomes inert immediately and held inputs are cleared;
2. no new narrative step, timer, generator job, notification action, or
   gameplay command may begin;
3. every already admitted bounded transaction, including profile, New Run,
   save/restore, Shop, Schedule, board, narrative, and generator work, reaches
   its recorded stable commit-or-rollback frontier;
4. music and ambience follow Mute When Inactive;
5. TTS, Settings tests, and one-shot SFX/UI stop without automatic restart;
6. Auto, notification foreground lifetime, confirmations, and user-facing
   timers preserve their remaining foreground time;
7. generators and workers park; and
8. nonessential redraw and processing park.

Focus loss never accepts or cancels a modal. A technical outcome completed
while inactive waits for refocus before presenting its public result.

### 11.2 Mute When Inactive

When On, music and ambience pause at exact playheads. An active crossfade
captures both legs' playheads and gains plus its remaining transition state;
focus loss never advances the fade merely to reach another boundary. Refocus
resumes that exact semantic context without overwriting volume or mute
preferences.

When Off, music and ambience may continue and advance. All narrative,
gameplay, input, notification, Auto, generator, and foreground-timer suspension
still applies. The option is not a general Pause Game switch.

The UI labels this behavior Mute when inactive. It may say that the game lowers
background activity, but it cannot promise energy or battery savings until
measured on supported hardware.

### 11.3 Resume

Rapid focus changes are idempotent. Resume happens once from the last stable
frontier. A fresh press is required; held focus-loss input cannot fire.

Auto and notification timers continue from their remaining foreground time.
Music/ambience follow section 11.2. TTS, previews, and one-shot tests remain
stopped.

## 12. Display and window mode

Display contains Window Mode with Windowed and Borderless. Windowed is the
fresh-profile default and uses the approved 1280 by 720 logical baseline.
Borderless uses the current display's usable bounds.

Selection applies immediately. The window coordinator prepares the new mode,
applies it, verifies the resulting window state, persists it, and publishes
once. Rejection or platform failure restores the exact prior mode and shows a
factual localized status.

There is no exclusive fullscreen, resolution picker, fake restart requirement,
or silent fallback in the initial release.

Dark Mode is absent from this page because it is a main-menu next-run choice
and a captured run mechanic, not a live display preference.

## 13. Dark Mode entitlement and run capture

### 13.1 Profile entitlement

The accepted discovery predicate unlocks one durable profile entitlement:
Dark Mode available. It defaults false, is monotonic for the lifetime of that
profile, cannot be asserted by UI/save payload, and never auto-enables a run.

Clear Gallery, Restore Preferences, New Run, Load, logout, and ending
completion do not revoke it. A separately confirmed Entire Profile Reset
clears it because that command replaces the player-facing profile.

### 13.2 Pending next-run selector

When entitlement is available, the main-menu Dark Mode switch is visible and
enabled. It defaults Off.

Toggling it durably changes only the pending-next-run Boolean and the current
title-owned palette. It never changes a live or saved run. Restore Preferences
preserves it.

### 13.3 Atomic New Run capture

A successful New Run or New Acc command:

1. completes any replacement confirmation;
2. freezes the old run/autosave revisions and current pending Dark value;
3. prepares a new run with immutable run_configuration.dark_mode_enabled equal
   to that frozen value;
4. prepares the required initial run save and pending selector Off;
5. commits new run, initial save, and profile selector consumption in one
   recoverable idempotent transaction; and
6. publishes the new route only after all durable owners agree.

Cancel or failure changes neither the old run nor pending selector. Retry uses
the frozen intent and cannot reread a changed or already-cleared selector.

Recovery exposes only two legal outcomes:

- old run plus pending selector unchanged; or
- new run plus pending selector Off.

The entitlement remains available. The switch is not locked; it is merely Off
and may be selected again for a later New Run.

### 13.4 Save, Load, and palette

Every Autosave, Quick, numbered save, branch, and checkpoint stores the run's
captured Dark Boolean. No save stores or restores the pending menu choice.

Load never reads, clears, consumes, or writes the pending choice. It prepares
under the current title or live-run palette. On successful commit it switches
atomically to the selected save's captured run palette. Failure preserves the
current state and palette.

A dark save remains dark after entitlement or profile reset. Loading it does
not restore the entitlement or arm the next run. A light save remains light
even while the pending menu choice is On.

Returning to title uses the current pending choice, normally Off after a
successful New Run, never the departed run's palette.

### 13.5 Migration

An old run save with no Dark configuration migrates to false. A compatible
legacy explicit run Dark Boolean migrates unchanged. A malformed present Dark
field rejects the save as unavailable; run state is never inferred from the
current profile or Gallery.

For an existing profile, Dark availability becomes true when either a valid
legacy availability latch is true or all four accepted qualifying Gallery
discoveries are durably present. The legacy `dark_mode.enabled` Boolean becomes
the pending-next-run selection only when resulting availability is true;
otherwise pending selection is repaired to false. This migration never changes
an already captured run.

Exceptional-replay availability becomes true when either its valid legacy
availability latch is true or at least one accepted exceptional identity is
durably discovered. Its valid legacy replay-full Boolean is preserved only
when resulting availability is true; otherwise it becomes false.

The planned ambiguous profile field dark_mode.enabled is superseded before
implementation. Profile stores available and pending-next-run selection; the
run stores captured enabled.

## 14. Controls and rebinding

### 14.1 Binding inventory

Each rebindable semantic action has exactly:

- one keyboard binding; and
- one controller binding.

Initial release does not expose mouse-button rebinding. Pointer and touch
controls remain accessible through their visible semantic controls.

Fundamental UI navigation, Accept, Cancel/Back, and the recovery path cannot be
erased. At least one complete keyboard and one complete controller navigation
set always remain.

Controller bindings describe semantic button positions, not one transient
physical device ID.

### 14.2 Context conflicts

The input registry declares the contexts in which each action can be live.
Two actions conflict only when they use the same device binding and their live
contexts overlap.

The same binding may be reused in mutually exclusive contexts and is labelled
as shared. The UI never reports a false conflict merely because two actions
exist in the registry.

### 14.3 Capture, Swap, and Cancel

Capture ignores the input that opened capture and rejects unsupported events
truthfully. It has no automatic timeout. Back, category/Settings departure,
focus loss, or disconnection of the active capture device cancels capture with
zero binding mutation and returns focus to the initiating row on the next
foreground presentation.

For one conflict, the dialog names both actions and offers Swap or Cancel.
Swap atomically exchanges their same-device bindings only after validating the
complete resulting same-device binding map against every registered context
intersection. If the exchange would create any new conflict with an action not
shown in the initial pair, Swap is unavailable.

For several overlapping conflicts, the dialog lists all affected actions. The
captured action receives the requested binding; every listed action receives
the captured action's prior same-device binding. Such a fan-out is legal only
when those listed actions are mutually exclusive with one another. Otherwise
Swap is unavailable and the audience must Cancel and choose another binding.
Before offering Swap, the complete resulting same-device binding map is also
validated against every registered action and context intersection; any new
conflict makes Swap unavailable. The exact before/after table is shown before
Swap. Cancel changes nothing.
Failure restores the complete prior binding set.

Focus returns to the initiating binding control after Swap or Cancel.

### 14.4 Restore Controls

Restore Controls is a separate confirmed profile command. It resets every
rebindable keyboard/controller slot to the registered defaults atomically and
preserves every non-input preference, unlock, History, Gallery fact, run, and
save.

Cancel is initially focused. Failure leaves all bindings unchanged.

## 15. Accessibility contract

### 15.1 Text size

The initial Windows release exposes exactly 100%, 125%, and 150%, default 100%.
The chosen preset applies immediately to all visible, cached, and future UI.

The seven-category macro topology remains at all three sizes. Rail and sheet
may wrap and scroll locally. Text never shrinks below the selected size,
clips, overlaps, becomes an image, or requires horizontal text scrolling.

This is an in-game text-size contract, not a claim of Windows Make text bigger,
200% reflow, WCAG conformance, or every assistive technology.

### 15.2 Targets

Ordinary interactive hit areas are at least 48 by 48 logical pixels. Large
Targets defaults Off and raises the minimum to 64 by 64 without changing text
size or gameplay geometry.

Large Targets may increase local scrolling. It cannot shrink a Minesweeper
cell, hide an action, or change canonical board coordinates.

### 15.3 Motion and shake

Reduced Motion defaults Off. Screen Shake offers Off, Low, and Normal with Low
default.

While Reduced Motion is On, nonessential motion, fades, shake, cascade, and
decorative auto-scroll animation become static swaps or jumps. Screen Shake
is visibly disabled but its independent selection is remembered and restored
when Reduced Motion turns Off.

Reduced Motion never changes text speed, Auto delay, input acceptance, command
order, or outcome.

Flicker, strobe, rapidly alternating contrast, and essential motion-only facts
are prohibited regardless of preference.

### 15.4 High Contrast and Colour Differentiation

High Contrast defaults Off.

Colour Differentiation offers:

- Standard;
- Protan;
- Deutan; and
- Tritan.

These are stable semantic IDs with localized audience labels. They are
authored differentiation presets, not a medical simulation or promise of
correction.

Effective themes are complete authored tuples:

2 base palettes x 2 contrast states x 4 colour presets = 16 tuples.

The resolver never stacks unverified shaders or silently falls back to another
tuple. A failure preserves the complete previous tuple.

Functional tokens include at least surfaces, text, muted text, focus outer and
inner outlines, selection, unread, information, success, warning, danger,
destructive action, unavailable/disabled, friend identity, Schedule
action/date states, and every Minesweeper numeral/flag/forced/exploded state.

Artwork pixels, portraits, narrative tints, item art, backgrounds, and
decorative ink texture are not recoloured. Functional controls and overlays
on top of artwork use the selected semantic tuple.

Every meaningful state also uses text, icon, glyph, outline, shape, position,
or pattern. Colour is never its sole evidence.

### 15.5 Live specimen

Accessibility permanently shows one noninteractive specimen strip labelled:

- Selected;
- Focus;
- Warning; and
- Unavailable.

The specimen uses the same production tokens and effective tuple as the game.
It updates immediately without moving focus, creating a second draft state, or
flooding assistive announcements.

### 15.6 Invariants, not toggles

These are guarantees and are not exposed as optional Settings:

- dialogue text remains visible;
- essential focus remains visible;
- important state does not rely on colour, sound, animation, hover, or
  pointer-only input;
- no strobe or deliberate accessibility-hostile flashing;
- no routine visible speaker labels;
- no non-speech caption stream;
- no audio-only evidence; and
- no fabricated visual equivalent for a sound that has no gameplay evidence.

## 16. Neutral previews and sample arbitration

Reading and TTS share one neutral localized preview card. It is institutional
and ordinary, not a character line, clue, anomaly, route hint, or tutorial.

Single-language preview follows the single-language caption grammar. Dual
preview shows Primary then Secondary for one semantic beat. Read Aloud speaks
Primary only.

Only one Settings sample can run. Starting another stops the first. The active
button becomes Stop. Leaving the category, closing Settings, entering a
blocking modal, or losing focus stops it without automatic restart.

Previews create no canonical line ID, visited receipt, read state, History,
Gallery, Observer evidence, audio context save fact, or gameplay transaction.

## 17. View cache, profile persistence, save, and Load

Within the same logical host session, app switching preserves:

- selected category;
- rail and sheet scroll;
- one meaningful focused semantic control per category; and
- no active sample or modal.

Fresh title, day change, successful Load, successful New Run, Logout, and
Entire Profile Reset clear the cache. The next open starts at Language/top
with focus on Language.

The cache is never serialized.

All ordinary Settings values are profile-owned and apply immediately while a
candidate or board exists without changing gameplay facts. Save and Load do
not rewind them.

If a save captures Settings as the active desktop app, restore reconstructs a
clean Settings host at Language/top. It does not restore a category cache,
scroll, focus, slider drag, binding capture, preview, confirmation, or status.

Dark captured run configuration is the sole exception described in section
13.

## 18. Records and reset commands

### 18.1 Reset matrix

| State | Restore Preferences | Restore Controls | Clear Visited History | Clear Gallery | Entire Profile |
|---|---|---|---|---|---|
| Primary/Secondary/Dual | preserve | preserve | preserve | preserve | defaults |
| Reading/Auto/Skip | defaults | preserve | preserve | preserve | defaults |
| Read Aloud/rate | defaults | preserve | preserve | preserve | defaults |
| Master/channels/inactive mute | audible defaults | preserve | preserve | preserve | defaults |
| Window mode | Windowed | preserve | preserve | preserve | defaults |
| Text/targets/contrast/motion/shake/colour | defaults | preserve | preserve | preserve | defaults |
| Input bindings | preserve | defaults | preserve | preserve | defaults |
| Exceptional replay choice | Off | preserve | preserve | Off | Off |
| Exceptional replay availability | preserve | preserve | preserve | cleared | cleared |
| Dark entitlement | preserve | preserve | preserve | preserve | cleared |
| Dark pending next-run choice | preserve | preserve | preserve | preserve | Off |
| Gallery entries | preserve | preserve | preserve | cleared | cleared |
| Visited History | preserve | preserve | cleared | preserve | cleared |
| Live/captured run Dark state | unchanged | unchanged | unchanged | unchanged | unchanged |
| Autosave, Quick, Slots 1-7 | untouched | untouched | untouched | untouched | untouched |

An already frozen canonical ending plan is never mutated by any profile reset.
Gallery replay remains Full for a discovered exceptional identity while that
identity exists in Gallery; Clear Gallery removes the discovery and therefore
clears exceptional-replay availability and returns its choice Off.

Entire Profile Reset clears player-facing profile state but does not delete
save records. A later Load may restore a dark run from its captured run fact
without restoring the cleared entitlement.

Entire Profile Reset is exposed only in title Settings when no live run is
mounted. It cannot execute against an active continuation, ending transaction,
or recovery candidate. This prevents removal of the profile-owned
irreversibility ledger beneath a live run. Existing save records remain under
SaveManager. A later Load never restores the cleared profile ledger or
milestone: an exact saved mid-board still restores that board, while future
challenge-entry boundaries operate against the new profile's empty ledger.
That reset of profile history is the expressly confirmed consequence of Entire
Profile Reset, not an ordinary Load loophole.

### 18.2 Confirmation and publication

Restore Preferences, Restore Controls, Clear Visited History, Clear Gallery,
and Entire Profile Reset are separate explicit commands. Each confirmation
names its exact scope, places initial focus on Cancel, traps input, and binds
the current profile revision.

Reset is all-or-nothing. Success publishes only after durable commit and
consumer application agree. Failure preserves the prior profile and live
presentation. Hidden migration and transaction receipts may survive only as
technical idempotency facts; they cannot preserve a player-facing setting or
unlock that the command cleared.

SaveManager remains the sole save-document I/O and run-replacement
coordinator. Settings never creates a second storage or replacement path.

## 19. Visual direction

Settings uses the same old-campus operating-system family as the other apps:

- square windows and controls;
- soot ink, exhausted paper, muted institutional colour, and hard raster
  edges;
- static low-contrast ink variation only on inactive planes;
- disciplined empty space instead of decorative clutter;
- complete CJK glyph coverage and tabular figures where values align; and
- no glossy modern mobile cards, neon arcade styling, fake CRT, glitch, blood,
  occult shorthand, or simulated failure.

The application should feel maintained for a long time, not cheaply made or
broken. A technical recovery plate may be cleaner and plainer than the themed
surface so the audience can trust it.

## 20. Technical truth, failure, and recovery

Settings never uses fiction to represent a real failure.

Known ineligibility uses concise inline facts such as:

- No compatible system voice found;
- Muted;
- Volume is 0;
- This language has no second selectable locale; or
- This binding conflicts with the listed actions.

A failed immediate command retains or reconstructs the last committed value,
keeps meaningful focus, and announces one concise localized status. Raw paths,
schema fields, stack traces, device IDs, and internal transaction IDs remain in
diagnostics only.

An indeterminate commit blocks conflicting Settings commands and uses the
trusted recovery surface until storage reconciliation proves the winner. It
never guesses.

Technical failure cannot:

- alter a run, ending plan, board, message, purchase, or Schedule;
- consume or grant Dark entitlement;
- consume the pending Dark selector without a committed New Run;
- create a story anomaly;
- play a horror sting or fake corruption;
- silently select another locale, voice, palette, binding, or window mode; or
- claim accessibility support that was not physically verified.

## 21. Component and interface ownership

Future reconciliation must preserve these ownership boundaries:

- ProfileManager owns validated global preferences, language tuple, Dark
  entitlement, pending Dark choice, reset candidates, and durable publication.
- The run/snapshot owner owns immutable run_configuration.dark_mode_enabled.
- SaveManager's existing New Run transaction owns atomic run creation, initial
  save, Dark capture, and selector-Off consumption. This amendment creates no
  second New Run or cross-store coordinator.
- LocalizationManager owns UI lookup, primary/secondary resolution, atomic
  language publication, and per-row fallback facts.
- The narrative presentation adapter owns caption layout and presentation
  receipts; Settings supplies preferences only.
- A system TTS coordinator owns voice capability, utterance arbitration,
  language compatibility, rate, Test, and failure status.
- AudioManager remains sole owner of game audio contexts, channel gain/mute,
  playheads, and registered channel tests.
- The application lifecycle coordinator owns safe-boundary inactive suspension
  across input, narrative, audio, generators, workers, timers, and redraw.
- The window coordinator owns truthful Windowed/Borderless application and
  rollback.
- Accessibility/theme coordination owns text size, targets, motion, shake, and
  complete semantic palette tuples.
- InputManager owns the context registry, device slots, capture, conflict
  plans, durable swaps, and defaults.
- One shared Settings content scene projects these owners and contains no
  business rule.

No scene writes profile JSON, edits InputMap directly, changes buses directly,
interprets Dark mechanics, or fabricates capability availability.

## 22. Exact supersession and retained law

### 22.1 Superseded wording and physical drift

Within scope, this amendment supersedes:

- the singular profile language shape, replacing it with Primary, Secondary,
  and Dual;
- the Core Story Bible's automatic native-original-plus-translation History
  TTS sequence, replacing it with Primary-only Read Aloud;
- arbitrary continuous text speed, Auto speed, font scale, and shake controls;
- the public Voice row and Voice preference fields for an unvoiced game;
- bus-only focus mute and optional/no-op pause-on-focus-loss behavior;
- fullscreen Boolean presentation;
- the planned ambiguous profile dark_mode.enabled field as live-run authority;
- the current `reset_preferences()` / Restore Preferences behavior that resets
  language; Entire Profile Reset still returns language to fresh defaults;
- generic arbitrary input-event arrays as the player-facing binding grammar;
- 44-pixel normal targets;
- whole-screen colour-filter interpretation; and
- public switches for captions, speaker names, visual audio cues, flashing,
  focus visibility, opacity, hold-to-confirm, controller cursor, and other
  unapproved schema leaves.

Current ProfileSchema, ProfileManager, AccessibilityManager, AudioManager,
InputManager, RunSnapshotSchema, SettingsPanelController, Setting scene,
SettingsApp scene, and their characterization tests are physical evidence and
known drift. They do not acquire product authority by existing.

### 22.2 Retained law

This amendment retains:

- profile ownership of true global presentation preferences;
- AudioManager as sole game-audio owner and semantic audio-context registry;
- atomic locale switching and deterministic per-key fallback;
- Skip/Auto/TTS presentation receipts and global visited-line ownership;
- all Dark unlock, refusal, Schedule, and ending mechanics;
- exact active-board preservation while Settings changes;
- each accepted app amendment's local 100/125/150 topology and cache law;
- Backup's exact save trust and palette-switch boundary;
- no audio-only evidence and no colour-only state;
- technical failure as nonfiction; and
- all unrelated story, relationship, Hospital, ending, Gallery, Observer,
  persistence, and recovery rules.

## 23. Reconciliation path before implementation

After this exact written approval and separate authority to reconcile:

1. update `req.docs.authority`, the authority-context packet, the
   design-authority registry/discovery path, and docs/design guidance so an
   approved scoped design amendment is machine-resolvable without rewriting
   historical accepted artifacts;
2. create a bounded successor Settings authority/reconciliation Bead rather
   than reopening dwm-p2r.3 or widening dwm-0hi;
3. inventory every overlapping rule in authority-context, audio-preferences,
   localization, persistence, runtime-ownership, verification, and any later
   packet; give each an explicit retained, amended/replaced, or superseded
   disposition, then create only the missing exact Settings,
   language/reading, audio/inactive, display/Dark, controls, accessibility,
   reset, and technical-trust rules—never parallel duplicate authority;
4. update the generated requirement index and Beads metadata only through
   their authorized owners;
5. version ProfileSchema and migrate every legacy preference, retired field,
   locale, and binding deterministically;
6. version RunSnapshot and SaveDocument schemas with immutable captured Dark
   run configuration and old-save migration;
7. extend SaveManager's existing recoverable New Run transaction with Dark
   capture and pending-selector consumption without creating a second path;
8. reconcile Profile, Localization, Audio, Accessibility/theme, Input,
   narrative, TTS, window, and lifecycle coordinator interfaces;
9. replace the generic Settings scaffolds with one shared logical content
   scene;
10. add registered control, context, sample, token, locale, and error catalogs;
11. make the successor reconciliation issue a blocking dependency of
   `dwm-oyo.1`, rebind affected `dwm-oyo.5`, `dwm-oyo.6`, and `dwm-oyo.7`
   acceptance/metadata to successor plan hashes without editing historical
   plan bytes, and create separate Settings implementation and verification
   issues gated by completed reconciliation plus explicit runtime authority;
12. write every new successor plan with an exact hash rather than editing a
   hash-bound plan in place; and
13. preserve every unrelated dirty worktree file and accepted sibling
   amendment.

Approval of this document alone performs none of those steps.

## 24. Verification matrix

### 24.1 Profile, migration, and reset

Verify:

- every fresh default and exact allowed value;
- migration of every valid legacy scalar/Boolean/float and discarded field,
  including Auto's exact conversion, stored focus-mute Booleans, Dark's
  four-discovery predicate, and exceptional-discovery availability;
- language tuple and same-language swap atomicity;
- reset table isolation and all-or-nothing publication;
- Controls reset durability and protected navigation;
- Clear Gallery preserving Dark entitlement while clearing exceptional-replay
  choice/availability;
- Entire Profile being title-only with no mounted run, clearing entitlement and
  profile ledgers without deleting saves, and old-save behavior afterward; and
- consumer-application failure and indeterminate commit recovery.

### 24.2 Reading, captions, TTS, and previews

Verify:

- exact reveal and Auto timings in foreground time, including Auto waiting for
  effective Read Aloud completion or deliberate Stop;
- all single/dual caption stacks, native pairs occupying one beat, and per-row
  fallbacks;
- no prior caption beat in dual mode;
- Primary-only live and History TTS;
- immutable per-entry History language receipts never restoring or overriding
  current language preferences;
- disclosed-speaker-on-change behavior;
- voice available, unavailable, disappearing, and returning;
- no wrong-language substitution or download;
- Auto, Skip, utterance replacement, focus loss, and app departure;
- one-sample arbitration and exact context restoration; and
- zero preview effects on read, History, visited, Gallery, evidence, or saves.

### 24.3 Audio and inactive suspension

Verify:

- exact audible fresh defaults, Master multiplication, and 5-point non-pointer
  volume steps;
- every mute/zero/Test combination;
- absence of a public Voice row;
- TTS independence from game audio;
- Active/Draining/Suspended transitions at every bounded transaction phase;
- On and Off behavior for music/ambience;
- stopped TTS/tests/one-shots versus paused Auto/notification timers;
- held-input clearing and rapid focus changes;
- exact crossfade-state capture, generator/worker parking, and exact resume;
- no energy-saving claim without measured evidence.

### 24.4 Window and Dark transactions

Verify:

- Windowed/Borderless success, rejection, rollback, persistence, and focus;
- Dark unlock publication;
- pending toggle durability and title palette;
- crash injection at every New Run capture/commit/publication boundary;
- Cancel/failure preserving pending choice;
- success capturing run Dark and resetting pending Off exactly once;
- alternating normal/dark saves and branches;
- Load never consulting or mutating pending choice;
- title and in-run palette atomicity;
- old-save migration and malformed-save rejection; and
- dark-save Load after profile reset.

### 24.5 Input

Verify:

- one keyboard and one controller slot for every rebindable action;
- fixed indispensable navigation;
- every context-overlap and mutually-exclusive reuse case;
- one-conflict and multi-conflict Swap;
- unsupported capture, activation-event suppression, focus-loss cancellation,
  controller disconnect, Cancel, rollback, and persistence; and
- device-independent controller records.

### 24.6 Text, targets, motion, and colour

Verify the release matrix across:

- every shipped locale;
- Primary/Secondary pair and single/dual mode;
- 100%, 125%, and 150% text;
- 48- and 64-pixel target modes;
- Windowed and Borderless;
- supported Windows display-scaling baselines;
- mouse, touch, keyboard, controller, and supported assistive routes;
- Reduced Motion Off/On and every shake selection; and
- all 16 base/contrast/colour tuples.

Every meaningful token, including Minesweeper and app-specific states, must
retain non-colour evidence and required contrast. Layout must have no clipping,
overlap, hidden control, silent shrinkage, horizontal text scroll, or
unreachable focus.

### 24.7 Cache, continuity, and technical truth

Verify:

- same-host cache preservation;
- reset on fresh title, day, Load, New Run, Logout, and Entire Profile;
- saved active Settings app reconstructing at Language/top;
- changes while a Minesweeper candidate or board exists;
- failure preserving canonical gameplay and prior preference;
- one assistive error announcement;
- no raw diagnostic leakage; and
- no technical failure transformed into story presentation.

Release evidence must identify the exact build, Windows target, locale
catalogs, semantic theme registry, input devices, system TTS availability, and
test matrix. Unverified rows remain unsupported rather than advertised.

## 25. Acceptance and next manuals

The user approved this exact artifact on 2026-08-12 after self-review passed.
It is accepted written design and grants no implementation authority.

Later UI/UX, visual-art, and music/audio manuals
may consume this Settings grammar. They may choose final localized copy,
fonts, token values, sample assets, and art details only within this law.

The next implementation step, if separately authorized after authority
reconciliation, is a reviewed plan. No runtime work follows automatically from
approval.
