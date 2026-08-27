---
id: spec.seven_day_dialogic_flow
kind: design_specification
schema_version: 1
conversational_design_status: approved
written_spec_status: approved
self_review_status: passed
implementation_authorized: true
implementation_plan_path: "docs/superpowers/plans/2026-08-07-seven-day-flow-implementation-roadmap.md"
implementation_plan_status: approved
implementation_plan_sha256: "288c73f7eeca6bc80fe8775cd77f25aba8bc68e0945dd244592a1d6128a7c32f"
implementation_plan_created_on: 2026-08-07
implementation_execution_mode: subagent_driven
implementation_approved_by: project_owner
implementation_authorization_state: approved
implementation_authorization_scope: seven_day_flow_phase_01_dwm_oyo_2_only
implementation_base_commit: ed037cb2b1781a02905a232b0747b093abc377c7
implementation_plan_approved_on: 2026-08-27
implementation_authorized_on: 2026-08-27
implementation_commit_authorized: true
implementation_commit_approved_by: project_owner
created_on: 2026-08-07
written_spec_approved_on: 2026-08-07
engine_line: godot_4_6
verification_engine: "4.6.3-stable-mono"
dialogic_version: "2.0-Alpha-19 (Godot 4.4+)"
language: gdscript
scope: seven_day_flow_dialogic_structure
---

# Seven-Day Flow and Dialogic Structure

## 1. Status and objective

This document records the conversationally approved design for the seven-day
calendar, relationship and Minesweeper consequences, Hospital interruptions,
Priscilla-Lavinia encounters, Day 7 endings, save/reload law, and consolidated
Dialogic authoring structure.

The user approved this written specification on 2026-08-07. It is now the
domain design authority for the concerns named above, but it authorizes no
implementation by itself. Runtime code, tests, requirement packets, and Beads
issues must be reconciled through a separately reviewed and approved
implementation plan.

The objective is an absurd, dreamlike, punishing game whose world does not bend
around Angela, while every apparently impossible consequence still follows a
stable physical game law. Players may misunderstand the world. The software
must not.

## 2. Scope boundary

### 2.1 In scope

- Days 1 through 7 and the transition into endings.
- Six ordinary three-reply messages and their later echoes.
- Twelve solo invitation windows and twelve possible solo challenges.
- The original Day 2 and Day 6 Priscilla-Lavinia group-date mechanism.
- Hospital interruption, including Sylvia's special hospital behavior.
- Relationship statistics, durable tiers, tone, attitude, and promotion gates.
- Minesweeper-to-relationship outcome classification.
- Board permanence before and after the first completed ending.
- Rehearsal, Observer mastery evidence, postscript replay, and Gallery identity.
- Exact semantic timeline identities, frozen contexts, safe signals, receipts,
  locale fallback, and recovery behavior.
- Consolidation to seven day timelines plus one ending timeline per locale.
- Plot-neutral documentation and authoring templates.

### 2.2 Out of scope

- Finished dialogue, action prose, date premises, or ending prose.
- Final character voice analysis for content production.
- New plot anchors, mystery answers, locations, or replacement dates.
- Finished backgrounds, portraits, audio, animation, or cinematics.
- Chinese translation prose.
- Final numerical balance beyond the approved laws in this document.
- A line-collection Gallery UI; this design preserves IDs and metadata for it.
- Replacing the existing definition of Perfect, Foresight, or No-flag.
- Changing the original Priscilla-Lavinia group-date protocol; section 7.5
  restates its normative state machine so implementation need not infer it from
  a historical document.
- Explaining hidden mechanics to the player.

## 3. Authority and documentation consequences

After written approval, authority for this bounded domain is:

1. This specification owns the approved mechanics and Dialogic structure.
2. `story/01-core-story-bible.md` and
   `story/02-character-relationship-handbook.md` own character, relationship,
   voice, atmosphere, and narrative canon where they do not contradict an
   explicit later approval recorded here.
3. `story/03-seven-day-production-map.md` becomes a derived, plot-neutral
   production template. It does not define mechanics.
4. `story/05-canon-amendments-2026-07-19.md` remains historical amendment
   evidence. Conflicting mechanical rulings are superseded by this document.
5. Named material removed from `story/03` moves verbatim to a clearly marked,
   noncanonical idea library.
6. `docs/design/recovered/` remains historical reference only.
7. Requirement packets and Beads own implementation requirements and live work
   status after they are reconciled from the approved design. Runtime code owns
   only what physically exists, including any known drift.

Approval does not imply implementation. Implementation does not imply
verification. Verification requires executed evidence against an identified
worktree or commit.

## 4. Chosen architecture and alternatives

### 4.1 Chosen: semantic entries inside eight master timelines

The game calls stable semantic presentation-entry IDs. A closed manifest resolves
each `entry_id` to one exact `{path, label}` locator and contract. Dialogic starts
that label inside one of eight master files. Physical file layout may change
without changing save, Gallery, localization, audio, or visited-line identity.

Ending identity and presentation identity are deliberately separate. One stable
`ending_id` owns discovery, save, and Gallery meaning; one of its allowlisted
`entry_id` values selects Normal/Dark-mode, Full/Residue, or another presentation
form. Each `entry_id` still resolves to exactly one locator. No runtime lookup is
ambiguous or one-ID-to-many-locators.

This design keeps authoring navigable by day, removes the current file explosion,
and prevents a save from depending on a filename or line number.

### 4.2 Rejected: retain one file for every contact/date fragment

The current English skeleton contains 61 `.dtl` files and 61 UID sidecars.
Keeping that layout preserves simple file-level starts, but makes cross-day
causality difficult to inspect and multiplies localization and registry work.

### 4.3 Rejected: one timeline for the whole game

A single monolithic file minimizes file count, but makes day ownership, merge
conflicts, locale completion, and label auditing needlessly difficult. Eight
files are the smallest structure that still communicates ownership.

### 4.4 Rejected: let DTL own gameplay state

Direct DTL mutation makes skipping, replay, reload, localization, and authoring
errors capable of changing canon. Dialogic is therefore a presentation layer.
The game state owner validates and commits all consequences through typed,
idempotent commands.

## 5. Narrative authoring guardrails

These rules govern later content; they do not require prose in this structural
phase.

- Only character dialogue and executable character action presentation may tell
  the story. Do not add an explanatory narrator.
- The surface may be dreamlike, surreal, psychedelic, absurd, ridiculous,
  unrealistic, and chilling. Causality underneath must remain exact.
- Normalize abnormal events. Do not announce their meaning.
- Keep psychological horror under sweetness: every dark option is attractive
  for a character-grounded reason, and every sweet branch retains nearby danger.
- Prefer implication and interaction over exposition. Leave room to infer
  history, personality, motives, and relationships.
- Avoid affectation, feyness, frivolity, melodramatic staging, sentimentality,
  cheesiness, and cliches. Do not construct scenes as deliberate symbols,
  cinematic spectacle, dramatic set-pieces, or dialogue-shaped decoding keys.
- Maintain noir-thriller tension and short memorable shocks without relying on
  graphic brutality. Cruel or immoral fantasy should arrive as normalized
  character behavior rather than an announced transgression.
- Characters act from their own experience and personality, not merely to serve
  Angela's route or reward the audience.
- Dialogue is natural, idiomatic casual English from England. Grammar may break
  in voice-specific ways, but not through accidental non-native phrasing.
- Emotion is carried by diction, rhythm, interruption, silence, and personalized
  syntax; emotional parentheticals are optional, not a default.
- No statistic name, relationship outcome name, Observer rule, save punishment,
  or hidden board law is explained to the player.
- Authoring notes distinguish observed physical facts from character inference.
  An extraordinary event retains at least one plausible mundane explanation
  unless the game has explicitly established a different physical rule; no
  supernatural claim becomes fact merely because a character believes it.
- Every authored entry comments its purpose, causal background, variation
  layers, and allowed effect boundary. Background/portrait staging uses the
  agreed executable events with an adjacent authoring comment such as
  `# [background path="..."]`.

The named craft references remain lenses, not formulas or imitation targets.
McKee, Truby, USC Eight Reels, Syd Field, Rossio, and Martell may test causal
turns and sequence pressure; Robbe-Grillet, Barthes, Mark Fisher, and Masaaki
Yuasa may test perception, estrangement, normalized abnormality, and elastic
rhythm. None may override character autonomy, physical plausibility, dialogue-only
story delivery, or the prohibition on deliberate symbolic decoding.

## 6. Domain terminology and ownership

### 6.1 Friends

The three solo friends are Priscilla, Lavinia, and Sylvia. Priscilla-Lavinia is
a separate pair domain for counted encounters and counter-endings; it does not
reuse Angela's relationship statistics.

### 6.2 Per-friend relationship state

Each solo friend begins with:

| Field | Initial value | Law |
|---|---:|---|
| `affection` | 0 | Signed readiness clamped to -4 through 10; never directly sets tier |
| `tier` | Friend | Friend -> Ambiguous -> Love only; never regresses |
| `dark` | 0 | Integer 0 through 4; permanent within the run |
| `attitude` | Neutral | Overwritten by every attended relationship challenge |

Tone is derived from permanent dark count:

- `dark` 0 or 1: Sweet.
- `dark` 2 through 4: Totally Dark.

Dark never decreases. It rises only through a terminal Dark relationship
outcome or the explicitly approved Sylvia Hospital witness, one point at a time
and subject to the cap.

Affection changes only through the six terminal solo relationship outcomes or
the approved Sylvia Hospital witness. Every mutation clamps immediately; no
message, miss, invitation, pair board, or ending applies a hidden delta.

Tier and tone are independent. A character may be Ambiguous/Totally Dark or
Love/Sweet. Attitude is also independent and controls short current-behavior
inserts rather than route eligibility.

Attitude persists across midnight, ordinary messages, invitations, misses, and
endings until that same friend's next attended solo challenge overwrites it.
Sylvia's approved Hospital witness is the only other overwrite. Presentation may
portray stored attitude but cannot reset it.

### 6.3 Invitation terms

- **Offered:** the invitation exists but has not been opened.
- **Accepted:** Angela opened/read the invitation; her scripted acceptance is
  committed and the date becomes addable to the schedule UI.
- **Scheduled:** the player pressed Done with that date in the schedule.
- There is no canonical `planned` or `added-but-not-scheduled` state. Schedule-bar
  contents before Done are ephemeral UI state.
- **Attended:** the scheduled date reached and resolved its challenge.
- **Missed:** an accepted date was not attended.
- **Hospital-missed:** a read/accepted, unfulfilled date was superseded by a
  Hospital interruption.

### 6.4 Board result and relationship outcome

`board_result` records what happened in Minesweeper. `relationship_outcome`
records how the friend responds. They are separate so a Perfect board followed
by the deliberate special mine can remain Perfect for mastery while producing
the Dark relationship consequence.

The persisted enums are disjoint:

- `board_result`: `exploded | solved | perfect`;
- `perfect_reasons`: a nonempty subset of
  `efficiency_gt_100 | no_flag` only when `board_result = perfect`;
- `relationship_outcome`:
  `hatred | upset | amused | loved | foresight | dark`.

The relationship outcome named Foresight is never used as a Perfect-reason
value. This prevents the prose name from collapsing board qualification and
character response into one field.

### 6.5 Run, profile, and rehearsal

- **Run state** is the canonical current seven-day week.
- **Profile state** survives run saves and old-save loading. It owns permanent
  milestones, discovered endings, cross-run Observer evidence, append-only board
  attempt history, and the recoverable cross-store transaction journal.
- **Run irreversibility ledger** is a profile-owned, append-only overlay keyed by
  `run_id` and challenge slot. Before the first ending milestone it owns any
  challenge already entered, its board instance, terminal result, and effect
  receipt; an older slot save cannot overwrite it.
- **Branch state** identifies one restored canonical timeline after the first
  ending milestone. It owns which replacement attempt is current for each slot.
  Different old saves may create different branches without racing for one
  global “current result.”
- **Rehearsal state** is a consequence-free sandbox. It may update witnessed-line
  history but never canonical run or profile consequences except that separate
  visited-line collection.

## 7. Seven-day calendar law

### 7.1 Ordinary messages

There are exactly six ordinary replyable messages:

| Day | Friend | Choices |
|---:|---|---:|
| 1 | Lavinia | 3 |
| 2 | Sylvia | 3 |
| 3 | Priscilla | 3 |
| 4 | Lavinia | 3 |
| 5 | Priscilla | 3 |
| 6 | Sylvia | 3 |
| 7 | None | 0 |

Each choice is stat-neutral. Choosing one records one stable semantic reply ID,
the exact witnessed line ID and a safe plain-text snapshot, the scripted
immediate response, and a pending echo obligation. The line ID is authoritative;
the snapshot is content-versioned, length-bounded, markup-escaped, and never
parsed as DTL, BBCode, a resource path, or a command.

Ignoring an ordinary message until midnight erases it as if it never existed:
no player-facing history record, unanswered flag, late reply, or echo. The state
owner may retain only a non-narrative expiry receipt/sequence tombstone required
for deterministic generation and idempotency. That tombstone is invisible to
Contacts, history, Gallery, echoes, and route logic.

Invitations, nevermind messages, missed-date questions, Hospital explanations,
caring follow-ups, and institutional notices never gain reply menus. Angela's
response is scripted where one is required.

### 7.2 Solo invitation windows

Each friend has exactly four Days 1-6 solo invitation windows:

| Friend | Invitation days | Fixed third gate | Fixed fourth gate |
|---|---|---:|---:|
| Priscilla | 1, 2, 4, 6 | 4 | 6 |
| Lavinia | 2, 3, 5, 6 | 5 | 6 |
| Sylvia | 1, 3, 4, 5 | 4 | 5 |

Daily solo invitation order is fixed:

| Day | Round 1 | Round 2 | Additional round |
|---:|---|---|---|
| 1 | Priscilla | Sylvia | None |
| 2 | Priscilla | Lavinia | Original P-L group protocol at round 3 |
| 3 | Lavinia | Sylvia | None |
| 4 | Priscilla | Sylvia | None |
| 5 | Lavinia | Sylvia | None |
| 6 | Priscilla | Lavinia | Original P-L group protocol at round 3 |

Opening an invitation is the acceptance action. It commits Angela's scripted
acceptance and makes the date available to add. It does not schedule the date.

On Days 1-6, Done may commit zero, one, or two distinct solo dates in the
audience-chosen order. Each attended date owns its own challenge and consequence.
The world does not compensate for a missed opportunity.

### 7.3 Contact stacking and expiry

When a contact has several items on one day, presentation order is:

1. Previous-day causal follow-up.
2. That day's fixed ordinary message, if any.
3. A newly unlocked invitation.

Items append; they do not replace one another.

- Unread offer at expiry -> one next-day `nevermind` message.
- Read/accepted but unfulfilled offer -> one next-day missed-date question.
- Hospital-superseded accepted offer -> one Hospital-specific missed record and
  follow-up, except Sylvia's witness rule below.
- Every offer closes exactly once.
- Day 7 creates no Day 8 follow-up.

### 7.4 Hospital on Days 1-6

Hospitalization is reachable only from this audience-caused condition contract;
it is never a random cancellation inserted to redirect a route:

- `danger := pressure >= 10 OR health <= 0` using internal, not display-clamped,
  values;
- `sequela` exists only when carried from the previous day's uncleared danger;
- immediately after a desktop Minesweeper app round or Shop purchase commits its
  effects, `sequela AND danger` triggers Hospital before another desktop action;
- on Days 1-6, Schedule Done commits the selected schedule, then runs the single
  end-of-day condition resolver before any date. A new danger condition combined
  with carried `sequela` triggers Hospital and supersedes the committed dates;
- Day 7 Done bypasses end-of-day condition resolution. Its only faint path is the
  real-time app/Shop check before Done described in section 11.1.

The same idempotent condition receipt owns the danger inputs, trigger result, and
`pending_hospital` transition. Reload cannot reroll or reapply it. These
thresholds and condition names remain hidden from the audience.

If Hospital interrupts a day:

- Every read/accepted, unfulfilled invitation produces its own
  `missed_reason = hospital` record.
- Multiple accepted invitations produce multiple independent records.
- No generic missed duplicate is also created.
- Unread invitations still expire to ordinary `nevermind`; Angela cannot stand
  up a date she never accepted.
- No challenge, relationship outcome, attitude overwrite, or Perfect credit is
  fabricated for an interrupted date.

For Priscilla and Lavinia, the next-day missed question internally selects the
Hospital reason. Angela gives the scripted Hospital explanation and the friend
responds differently from an ordinary miss.

If Sylvia has a read/accepted invitation among the unfulfilled dates closed by
that Hospital resolution, Sylvia comes to the Hospital and witnesses Angela.
The Hospital resolver—not the DTL presentation—derives and persists one
idempotent `sylvia_hospital_witness` receipt for that invitation. The receipt is
unapplied handoff truth that freezes the next-day caring entry and its fixed
future consequence. Therefore:

- Sylvia sends no missed-date question for that event.
- The next day contains a scripted caring message with no choices.
- The frozen consequence is 2 affection, 1 dark point, Fixated attitude, and
  exactly one durable tier advance regardless of affection: Friend ->
  Ambiguous, Ambiguous -> Love, or Love remains Love.
- It grants no challenge result, board history, or Perfect mastery.

Neither the Hospital resolver nor Hospital/caring presentation applies those
relationship fields or commits caring history. `dwm-oyo.4` alone validates and
consumes the exact witness once, applies the frozen fields subject to the tier
maximum, affection clamp, and dark cap, and commits the caring
presentation/history transaction. Multiple qualifying Hospital encounters on
different invitation windows may each produce one independently consumable
witness; replaying or resuming the same encounter cannot apply it twice.

These earlier encounters enrich Sylvia's route but are not the Day 7 Special
trigger.

### 7.5 Priscilla-Lavinia group protocol and counted windows

The original Day 2 and Day 6 protocol is normative here:

1. The third desktop Minesweeper round attempts group activation exactly once.
2. Activation succeeds only while both same-day Priscilla and Lavinia solo
   offers remain available and unread. Success atomically hides/supersedes both
   solo offers and creates one group action in `AVAILABLE_UNOPENED`. Superseded
   solo offers cannot be accepted, scheduled, or produce solo follow-ups.
3. The first participating contact opened fixes `inviter_id` for wording and
   date-image position only, creates the paired contact presentation, and moves
   the group action to `REPLY_REQUIRED`. Opening the other contact changes no
   inviter and creates no duplicate action.
4. The group protocol is the sole invitation exception that retains a scripted
   reply action: replying through either participant moves the single group
   action to `ACCEPTED` and makes it schedulable. A reply through the other
   participant creates no second acceptance and changes only the existing
   judgment/response variation; repeating the same reply receipt is idempotent.
5. The group action occupies one schedule date slot. It cannot coexist with its
   two superseded solo actions.
6. At day resolution, an untouched generated group offer queues `busy` to both;
   an opened but unanswered offer queues `nevermind` to both; an attended group
   accepted through only one participant queues `judge` to the unreplied
   participant; an accepted but unfulfilled group queues one missed question per
   participant. Hospital selects the Hospital-reason versions and creates no
   generic missed duplicates.

After group contact state closes, each window obeys one prior question: did
Angela actually attend a solo date with Priscilla or Lavinia in that window?

- If Angela solo-dated either woman, their meeting is Prevented. It does not
  occur and counts nothing.
- If Angela solo-dated neither, they meet exactly once and the window counts
  once, regardless of whether Angela sees it.

When they meet, group-offer state selects presentation:

| State | Cause | Counts | Visible | Pair board |
|---|---|---:|---:|---:|
| Group | Offer generated, accepted, and attended | Yes | Yes | Yes |
| Missed | Offer generated and accepted; Angela absent | Yes | Yes | Yes |
| Private-visible | Offer generated but not accepted; unread and opened-unanswered are presentation subvariants | Yes | Yes | Yes |
| Private-offscreen | Group offer never generated | Yes | No | No |

The pair board has exactly three terminal results: Perfect, Solved, or Exploded.
It has no colored/special mine and no relationship-outcome layer. It controls
only legibility and mastery evidence and never changes Angela's affection, dark,
tier, attitude, invitation consent, or the pair's desire/state/tone.

Hospital uses actual attendance, not a discarded schedule intention:

- a Hospital-superseded solo date was not attended and therefore does not
  Prevent the pair;
- an accepted group date superseded by Hospital resolves as the visible Missed
  form with Hospital-flavored follow-ups;
- an unaccepted generated group offer resolves as its Private-visible form;
- a never-generated group offer remains Private-offscreen;
- Hospital presentation completes before any resulting visible Missed or
  Private two-friends scene and its pure-observation board.

Thus Hospital does not fabricate a solo result, but it also does not stop
Priscilla and Lavinia from acting without Angela. A Prevented or offscreen
meeting cannot fabricate a visible board. The pair counter, deck draw, deferred
scene identity, and follow-up records commit together in the day-resolution
receipt.

For avoidance of doubt, opened-but-unanswered is not a fifth pair outcome. The
preserved executable group protocol classifies it as Private-visible with the
`nevermind` contact flavor; both-unread is the neutral/`busy` subvariant of that
same outcome.

## 8. Challenge, attitude, and promotion law

### 8.1 Outcome classification

The date never presents a six-option relationship menu. Actual Minesweeper play
produces the result.

| Board event | Board result | Relationship outcome | Affection | Dark | New attitude |
|---|---|---|---:|---:|---|
| Exploded mine with hidden H assignment | Exploded | Hatred | -1 | 0 | Hostile |
| Exploded mine with hidden U assignment | Exploded | Upset | 0 | 0 | Upset |
| Exploded mine with hidden A assignment | Exploded | Amused | +1 | 0 | Amused |
| Cleared, not Perfect | Solved | Loved | +2 | 0 | Affectionate |
| Perfect clear | Perfect | Foresight | +2 | 0 | Seen |
| Deliberate special mine after clear | Solved if the clear was non-Perfect; Perfect if the clear was Perfect | Dark | +2 | +1 | Fixated |

Explosion assignments are generated and fixed with the board before reveal,
drawn only from Hatred, Upset, and Amused. Each eligible ordinary mine receives
one independent uniform `1/3` assignment from the board RNG; “equal thirds” is a
probability law, not an exact per-board quota. Reloading an active board cannot
reroll that assignment.

Assignment never consults friend, day, tier, affection, dark, attitude, route,
or prior outcome. Character-specific dialogue/action interpretation supplies
difference without weighting the hidden probabilities.

Perfect uses the game's existing definition: Foresight efficiency greater than
100 percent, No-flag, or both. Store the qualifying reason. Approved
accessibility assistance does not invalidate Perfect.

The special mine has no numerical label and is non-interactable until the board
has cleared. A clear first commits only board truth and enters
`CLEARED_AWAITING_TERMINAL_CHOICE`; it does not yet apply Loved or Foresight
relationship effects. Continuing without the special mine closes the board as
Loved/Foresight. Deliberately activating the special mine closes it as Dark
without erasing the already-earned Solved/Perfect board truth. Exactly one
terminal relationship-outcome receipt then applies affection, dark, and
attitude. Saving in the post-clear phase restores that phase, so Loved/Foresight
and Dark can never both pay out.

Every attended challenge overwrites the friend's current attitude. Outcomes and
statistics remain hidden from the audience.

### 8.2 Fixed promotion valves

Affection is fuel; fixed challenge windows are the valves.

- Immediately after the challenge in the friend's fixed third invitation slot
  (Priscilla Day 4, Lavinia Day 5, Sylvia Day 4), Friend may advance to
  Ambiguous if affection is at least 4.
- Immediately after the challenge in the fixed fourth invitation slot
  (Priscilla Day 6, Lavinia Day 6, Sylvia Day 5), Ambiguous may advance to Love
  if affection is at least 8.
- Each valve advances at most one tier.
- Promotion is evaluated after committing the challenge result and before
  presenting its post-challenge dialogue.
- A missed, unread, prevented, or Hospital-superseded fixed window does not move
  elsewhere.
- The fourth valve cannot repair a missed or failed third valve.
- Raw affection never bypasses a durable tier or directly unlocks Day 7.
- Sylvia's witnessed Hospital promotion is the only approved exception to these
  fixed solo challenge valves.

## 9. Message variation and echo law

### 9.1 Stable meaning, variable surface

Each ordinary message has stable A/B/C semantic choices. Surface wording may
vary by durable tier, tone, and attitude without changing which semantic choice
is selected. The committed record retains the authoritative line ID and safe
plain-text snapshot. Echo authoring resolves the versioned trusted line catalog
first and uses only the escaped snapshot when historical wording must survive a
compatible prose revision; saved text is never executable input.

### 9.2 Layer order

Authored variation is layered rather than multiplied into a Cartesian product:

1. Causal spine.
2. Durable tier: Friend, Ambiguous, or Love.
3. Tone: Sweet or Totally Dark.
4. Short current-attitude insert.
5. Short message-echo insert.
6. Exact witnessed-detail insert when required.

Tier by tone permits at most six core authored versions. Attitude and echo are
small composable inserts, not separate full scenes or ending identities.

### 9.3 Echo obligation

Choosing an ordinary reply creates `pending -> satisfied` echo state.

- The earliest natural authored slot may consume the obligation.
- If no contextual scene is reached, Day 7 contains an unavoidable fallback.
- Pending echoes are consumed oldest first.
- An echo may be a quote, syntax echo, action, physical consequence, changed
  silence, or another concrete witnessed detail.
- It may change presentation only. It cannot alter stats, tier, tone, attitude,
  invitation availability, schedule eligibility, mastery, or ending destination.
- Every authored echo binds its `echo_id` to one stable
  `presentation_atom_id`. A dialogue atom also owns a `line_id`; action, visual,
  and deliberate-silence atoms do not invent one.
- Consumption becomes durable only on a semantic `presentation_atom_presented`
  receipt. A dialogue atom is presented when the renderer accepts it into the
  visible dialogue/history stream; another atom is presented when its registered
  staging state is applied and entered in presentation history. Skip, Auto, TTS,
  instant-text, and accessibility input still count; dwell time does not. A
  crash before the durable receipt leaves the echo pending and replayable.
- Later optional callbacks may recur after satisfaction without becoming gates.

An ignored ordinary message creates no echo and must never grant unwitnessed
knowledge.

## 10. Board permanence, saves, and rehearsal

### 10.1 Active-board snapshot

An active-board save preserves the exact board instance, including at minimum:

- challenge slot ID and board nonce;
- run ID, branch ID, attempt ID, and attempt generation;
- seed/layout and hidden explosion assignments;
- revealed cells and flags;
- click history and current interaction phase;
- efficiency, Foresight, and No-flag metrics;
- special-mine state;
- clear/terminal phase and resolved receipt, if resolution already occurred.

Loading an active board never regenerates it.

### 10.2 Before the first completed ending

Every new playthrough receives a unique `run_id`. At the
pre-challenge-to-board boundary, the profile-owned run irreversibility ledger
atomically appends a slot-entry receipt and exact board instance under
`run_id + challenge_slot_id`. It later appends clear phase, terminal outcome, and
effect receipts. The ledger is monotonic and is not copied backward from a save
slot.

Challenge slots include all twelve solo windows and each Day 2/Day 6 visible
P-L board when its encounter form creates one. Offscreen or Prevented pair
windows create no board slot.

The same profile-owned per-run overlay also owns exactly one optional
`run_id + priscilla_lavinia_deck` draw receipt. Once the first counted pair
window requests a combination, an older same-run save can neither erase nor
replace that draw, even if profile-wide witnessed combinations change later.

The first entered canonical attempt for a challenge slot is therefore
irrevocable within that run:

- loading an older same-run save merges the newer ledger over the slot snapshot;
- a mid-board save resumes the ledger's exact board;
- a pre-board save whose challenge-entry receipt already exists resumes that
  board or its terminal post-challenge continuation and reconciles its exact
  relationship-effect receipt;
- a still-earlier branch that has not yet reached the causative challenge entry
  gains no anachronistic stats, but if it later enters that same slot it receives
  the ledger's existing board/result rather than a reroll;
- every consequential receipt is applied against the branch at its registered
  causal boundary, once, so an old snapshot cannot duplicate or delete the
  outcome, attitude change, or promotion it actually reaches.

Starting a genuinely new playthrough creates a new `run_id` and an empty run
ledger. The profile milestone remains, but the prior week's slots do not leak
into the new week. The audience chose; that week remembers.

### 10.3 After the first completed ending

Completing the first semantic ending step sets a monotonic profile milestone.
Afterward, loading any pre-challenge save and crossing its challenge-entry
boundary forks a new `branch_id`, appends a fresh `attempt_id` and board nonce to
profile attempt history, and generates a fresh unknown board. Once that board
begins, its active-board saves restore it exactly.

The completed replacement attempt becomes the canonical slot head only for that
branch. A saved branch persists its `branch_id` and per-slot canonical attempt
pointers. Loading two old saves may therefore create two independent branches;
neither overwrites the other's results or mastery. The active loaded branch is
the only source for current-run statistics, promotion, and Perfect mastery.

The profile milestone overrides a pre-milestone slot lock only at a fresh
pre-challenge entry boundary; it never deletes that history and never regenerates
a saved mid-board instance. Discarded attempts remain append-only profile
history. An entry may portray them only through a finite manifest-owned
`attempt_residue_id` deterministically derived from that slot's prior attempts
and frozen in the presentation signature; absent an exact mapping, the value is
`none`. Residue is nonpenalizing and presentation-only. Discarded attempts never
add canonical stats, tiers, dark, attitudes, Observer evidence, or mastery.
Rehearsal attempts
never enter this history. Only a full profile reset removes the milestone and
profile attempt ledger.

### 10.4 Current-run mastery

For mastery, “current canonical run” means the active loaded branch's canonical
slot heads within its `run_id`, never a union of sibling branches or prior weeks.

- Priscilla Observer board mastery requires all four Priscilla solo boards in
  the current canonical run to be attended and Perfect.
- Lavinia Observer board mastery requires all four Lavinia solo boards likewise.
- Priscilla-Lavinia Observer board mastery requires both counted visible pair
  boards in the current canonical run to be Perfect.
- Perfect-then-Dark retains Perfect mastery evidence.
- Missed, Hospital-superseded, offscreen, rehearsal, discarded, Solved, or
  Exploded boards do not substitute for required current-run Perfect evidence.
- Sylvia has no Observer route.

Pairing-specific Observer behavior evidence persists profile-wide. It is
separate from current-run board mastery; neither half substitutes for the other.

### 10.5 Rehearsal

After the first ending milestone, every callable entry declares a
`presentation_signature_schema`: the complete set of frozen fields that can
change its presented lines or actions. It includes entry identity plus only the
applicable tier, tone, attitude, echo, miss reason, board truth, relationship
outcome, Perfect reason, special-mine phase, promotion result, pair mode/deck,
ending role/form, and residue fields declared by that entry's exact role schema.
P-L and Alone signatures never acquire dummy solo fields.
Direct entry replay is allowed only for an exact signature already reached.

A full-date Rehearsal is the deliberate exception used for dialogue collection:
it begins from a canonically reached pre-challenge signature, then runs the real
production board rules in a sandbox. Any legal sandbox outcome may show its
hypothetical post-challenge lines and add their line IDs to visited-line history,
but it does not add that outcome signature to canonical reached-state history.
It cannot unlock a Gallery identity or Observer evidence.

Rehearsal owns isolated copies of GameState, Dialogic variables, board RNG,
nonce generation, receipts, and command capabilities. It may update only the
separate visited-line/skip-seen collection. It may not change canonical
affection, dark, tier, attitude, echo state, invitation state, schedule, run
ledger, profile attempt history, mastery, Observer evidence, ending plan, ending
discovery, Gallery completion, or global RNG. Observer-evidence and
pair-combination-witness commands are rejected from every Rehearsal source.
On exit, run and profile state must be deep-equivalent to entry except for the
allowlisted visited-line collection.

Debug outcome buttons remain test-only. Player Rehearsal uses the actual
production board rules, not those buttons and not a canonical board nonce.

## 11. Day 7 and ending law

### 11.1 Day 7 interaction flow

Day 7 first presents any due Day 6 Priscilla, Lavinia, and Priscilla-Lavinia
follow-ups. It has no ordinary three-choice message and no dating challenge.

Those follow-ups may naturally satisfy echoes. Immediately afterward,
`echo.fallback.day7` receives the immutable remaining pending-echo list and drains
every item oldest first. Desktop app/Shop controls, Done, and every faint-capable
action remain unavailable until all matching presentation-atom receipts are
durable. On interruption, the fallback resumes at the first unsatisfied echo.
Therefore no legal ending or Hospital transition can strand a chosen ordinary
reply without one visibly experienced echo.

Eligible boardless ending invitations unlock through the desktop Minesweeper app:

1. Round 1: Priscilla, if her durable tier is Ambiguous or Love.
2. Round 2: Lavinia, if her durable tier is Ambiguous or Love.
3. Round 3: Sylvia, if her durable tier is Ambiguous or Love.

Ineligible invitations are absent. Raw affection and current hostility cannot add
or remove them.

Reading an eligible invitation is its scripted acceptance and makes the ending
destination available to the Day 7 schedule UI. Before Done, bar contents remain
ephemeral and are not canonical planned/scheduled state. Done commits at most one
personal ending destination. Done with no destination selected enters ordinary
Alone.

Day 7 checks the existing qualifying faint condition in real time after a
desktop Minesweeper app round and after a Shop purchase, while Done remains
unpressed. A date/ending is never interrupted after Done.

For each qualifying action, operation order is fixed: commit its effects and
round/unlock state; evaluate the exact section-7.4 faint predicate against
invitations that were already read before that action; then, only on the no-faint
path, publish newly unlocked invitation notifications. Round 3 may logically
unlock Sylvia but cannot retroactively count her as read; Sylvia Special requires
the audience to survive that check, read her invitation, and then perform a later
qualifying action. The route is intentionally unavailable when the player leaves
no later legal trigger.

- If Sylvia's eligible Day 7 invitation has been read and Angela faints before
  Done, the uncommitted bar is discarded. The ending plan begins with Sylvia
  Special and then plays Sylvia Totally Dark.
- If Sylvia's invitation has not been read, the same qualifying faint enters the
  Hospital and resolves to normal Alone with a Hospital-cause insert.
- Merely adding another item to the uncommitted UI cannot block Sylvia Special.
- Day 7 fainting creates no missed-date record. This is an explicit terminal-day
  exception to the Days 1-6 accepted-but-unfulfilled law: no Day 7 destination
  becomes Scheduled until Done, and there is no Day 8 causal follow-up.

### 11.2 Thirteen semantic ending identities

There are exactly thirteen Gallery and save identities:

| Pairing | Identity 1 | Identity 2 | Identity 3 |
|---|---|---|---|
| Angela-Priscilla | Sweet | Dark | Observer |
| Angela-Lavinia | Sweet | Dark | Observer |
| Angela-Sylvia | Sweet | Dark | Special |
| Priscilla-Lavinia | Sweet | Dark | Observer |
| Angela alone | Alone | - | - |

Sweet/Dark/Observer/Special are internal semantic classifications. Discovered
Gallery entries use authored audience-facing titles.

### 11.3 Solo visible endings

For a normally selected personal destination:

- `dark` 0 or 1 selects that friend's Sweet identity.
- `dark` 2 through 4 selects that friend's Dark identity.
- Ambiguous/Love, current attitude, exact echoes, and missed/Hospital history may
  vary inserts but do not create new ending IDs.
- Day 7 never asks the player to produce another board result.

### 11.4 Priscilla and Lavinia Observer

Observer is a postscript identity, not a selectable destination and not a
replacement for the visible ending. It requires all of the following:

- The selected friend's Sweet ending completes first.
- All four of that friend's current canonical solo boards in the run are
  attended and Perfect.
- The profile has the pairing-specific Observer behavior evidence defined by the
  Core Story Bible: Verification for Priscilla or Restraint for Lavinia.

Verification requires its fresh-playthrough Capture/Compare evidence; reloading
the same scene cannot manufacture the fresh-run counterpart. Restraint remains a
deliberate withholding opportunity rather than a reflex test, and Lavinia never
perceives the false cursor.

Both grammars use registered canonical dating-scene evidence only. Verification
stores a captured source-line ID plus comparison key and requires a registered
counterpart from a different `run_id` before committing completion. Restraint
opens one registered, time-bounded but accessibility-neutral withholding window
and commits only when it closes without the intervention; it is never inferred
from generic inactivity. Evidence IDs and valid source entries are finite
manifest capabilities. History/skip-seen and Rehearsal lines cannot satisfy
either grammar.

Dark solo endings do not append Observer. Sylvia has no Observer identity.

### 11.5 Sylvia Special

Sylvia Special is not an Observer and has no Perfect or raw-dark requirement.
Its sole route trigger is the qualifying Day 7 faint after Sylvia's eligible
invitation was read and before Done.

Playback order is deliberately abnormal but exact:

1. Sylvia Special.
2. Sylvia Dark.

The sequence selects the Dark ending presentation even when Sylvia's stored dark
count is below 2. The frozen ending context records both her derived
`stored_tone` and `ending_form = special_forced_dark`; the latter is a validated
presentation override, not a stat mutation. Special itself does not add or
rewrite raw dark points. Earlier Hospital encounters are optional enrichments,
not prerequisites.

### 11.6 Priscilla-Lavinia counter-ending

If both Day 2 and Day 6 pair windows counted, a visible Priscilla-Lavinia ending
may follow any Angela solo ending, Sylvia sequence, or Alone. It never replaces
Angela's result and always occupies the latest applicable layer.

At the first counted window, a run-stable, unseen-first deck draws one of four
pair combinations:

- Ambiguous + Sweet.
- Ambiguous + Dark.
- Love + Sweet.
- Love + Dark.

The draw is uniform among profile-unwitnessed combinations while any remain;
after all four are witnessed, it is uniform among all four. Before day resolution
can commit the first counted window, it obtains or idempotently reuses the
profile-owned per-run draw receipt, which stores the chosen combination, the
witnessed-set fingerprint used for selection, and RNG nonce. Day resolution
references that receipt rather than drawing locally, so old saves, visibility,
board performance, and later profile discoveries cannot reroll it.

The deck remains stable across reload. It is independent of Angela's affection,
dark, tier, attitude, and pair-board performance. A visible Perfect or Solved
pair board permits the full observation and marks that drawn combination
witnessed after its registered line is presented; Exploded truncates it and does
not mark it witnessed. Private-offscreen counts the meeting but provides neither
a board nor witnessed-combination credit. Physical completion of the P-L visible
ending also marks its portrayed combination witnessed.

The deck's tone selects the P-L Sweet or Dark identity. The pair's state controls
internal Ambiguous/Love inserts without multiplying identities.

### 11.7 Priscilla-Lavinia Observer

The pair Observer postscript requires:

- both counted windows;
- the P-L Sweet ending to complete first;
- Perfect results on both current-run counted visible pair boards; and
- profile-wide Persistence evidence: all four stable pair state/tone
  combinations actually witnessed.

An offscreen counted encounter can qualify the visible pair ending but cannot
supply its missing board or witnessed-combination evidence. Pair Dark does not
append Observer. If the planned P-L Sweet ending itself will portray the sole
missing combination, the resolver includes Observer with an explicit precondition
on that ending's completion/witness receipt; Observer cannot start unless the
fourth combination became durable.

### 11.8 Alone and Dark-mode Angela

Alone is one semantic identity with two major presentations:

- **Normal Alone:** empty Done, including a Hospital-cause insert when Day 7
  fainting occurred without Sylvia's invitation read.
- **Dark-mode Alone:** unlocked after the profile has discovered all three
  friends' Dark endings and Sylvia Special.

Once unlocked, a hidden profile setting allows Dark-mode Angela to be enabled.
When enabled, every Days 1-7 romantic schedule commitment is blocked: offers may
still appear and be read for presentation, but Done cannot commit a solo or
group date. Non-romantic actions still permit day progression, and Day 7 resolves
through the Dark-mode presentation of the same Alone identity. A qualifying
faint in this mode also resolves Dark-mode Alone; Dark mode wins over the
otherwise eligible Sylvia Special trigger. Empty-Done and Hospital are causes
inside normal Alone, not additional ending identities. A qualified P-L layer may
still follow either Alone presentation; the pair may act privately even when
Angela cannot commit a date.

### 11.9 Ordered ending plan

The resolver freezes one ordered list of semantic steps before playback. It may
contain one through four steps. Examples:

- Priscilla Sweet -> Priscilla Observer.
- Priscilla Sweet -> P-L Sweet -> P-L Observer.
- Sylvia Special -> Sylvia Dark -> P-L visible ending -> P-L Observer when its
  independent Sweet/Observer gates qualify.
- Alone -> P-L visible ending -> P-L Observer when qualified.

A Priscilla or Lavinia solo Observer and a counted P-L ending cannot coexist in
one run: solo Perfect mastery requires attending that friend's Day 2 and Day 6
solo dates, while each attendance Prevents the corresponding P-L counted window.
The four-layer ordering remains general, but the resolver must reject a plan
that combines causally incompatible evidence.

Each step owns a stable `step_id`, semantic ending ID, callable entry ID, role,
frozen presentation context, playback mode, prerequisite receipt IDs, and
transaction token. State is:

`pending -> playing -> completed`

Only a physical completion carrying the matching token commits completion and
advances the cursor. Starting a label never advances. Duplicate matching
completion is an idempotent no-op; mismatched completion cannot advance.

Gallery discovery is committed only for semantic identities that physically
completed. The run reaches Completed/Menu only after every planned step and its
Gallery receipt are durable.

The first semantic ending step is “an ending achieved,” even when later ordered
steps remain. Its completion, Gallery discovery, and permanent post-first-ending
board-regeneration milestone form one recoverable cross-store transaction before
the cursor advances. Abandoning later steps does not revoke the earned
privilege. A crash cannot display and complete the first identity while losing
that privilege.

### 11.10 Full-once exceptional identities and residue

Observer and Special are exceptional identities that share one full-once replay
policy. Observer is a postscript; Sylvia Special is a prelude and deliberately
the first step of its Special -> Dark chain:

- First profile discovery always plays the full entry.
- After any exceptional identity has first been discovered, the hidden setting
  `Replay discovered exceptional scenes in full` becomes available, default Off.
- With the setting Off, a previously discovered qualifying exceptional identity
  uses a short residue under the same semantic identity.
- With the setting On, it plays in full.
- A newly discovered exceptional identity always plays in full regardless of
  the setting.
- The setting value and selected residue variant are frozen into the ending plan
  so reload cannot change or reroll them.
- Gallery replay always plays the full discovered exceptional identity.

Unseen Gallery identities are absent: no silhouette, lock, question mark,
percentage, or spoiler count.

## 12. Dialogic runtime contract

### 12.1 Eight physical masters

English authoring consolidates to exactly:

- `dialogic/timelines/en/day_1.dtl`
- `dialogic/timelines/en/day_2.dtl`
- `dialogic/timelines/en/day_3.dtl`
- `dialogic/timelines/en/day_4.dtl`
- `dialogic/timelines/en/day_5.dtl`
- `dialogic/timelines/en/day_6.dtl`
- `dialogic/timelines/en/day_7.dtl`
- `dialogic/timelines/en/endings.dtl`

Future locale mirrors use the same label contract. Chinese DTL prose is not
required in this structural phase; missing locale entries use exact-label
English fallback.

### 12.2 Closed semantic manifest

Every externally callable entry has one exact record containing:

- semantic `entry_id`;
- optional stable `ending_id` plus exact allowed playback form when the entry
  presents an ending identity;
- role and owning day/ending layer;
- locale-specific `{path, label}` locators;
- frozen-context schema and schema version;
- allowed signal IDs, exact payload schemas, and allowed source stage;
- content-contract version;
- compatible line-ID and presentation-atom namespaces;
- complete presentation-signature schema;
- required and optional visual-resource IDs with expected types and declared
  neutral fallbacks.

The manifest is closed. Unknown suffixes do not resolve through permissive
pattern parsing. Timeline IDs, marker IDs, effect IDs, variable IDs, line IDs,
and ending IDs all fail closed when absent.

### 12.3 Frozen presentation context

Before playback, the game resolves and validates an immutable context snapshot.
Applicable fields include:

- day and semantic entry ID;
- friend or pair ID;
- durable tier, tone, and current attitude;
- exact selected reply and witnessed line IDs;
- due echo IDs and their registered presentation-atom IDs;
- invitation/miss reason and presentation phase;
- board result, Perfect reason, and relationship outcome;
- promotion receipt/result;
- pair encounter presentation and stable deck state;
- run, branch, attempt, and transaction identity when relevant;
- exact group action state, inviter, target participant, canonical opened/replied
  participant IDs, and contact variation when relevant;
- finite `attempt_residue_id` when a registered prior-attempt presentation is
  selected;
- ending step, role, playback mode, residue variant, derived `stored_tone`, and
  validated `ending_form`;
- `alone_cause = empty_done | hospital_faint` for the Alone identity.

Each entry declares which fields are required. Undeclared extra fields, invalid
enums, wrong friend/day/source combinations, and mutable object references are
rejected. Optional fields may use declared defaults only; the bridge never
guesses them from live state.

Role-family required fields are:

| Entry role | Required frozen fields |
|---|---|
| Ordinary message | entry, day, friend, tier, tone, attitude, phase, due echoes; committed reply/line when resuming after selection |
| Solo invitation offer | entry, source day, friend, tier, tone, attitude |
| Group contact/offer | entry, source day, pair, group action state, inviter, target participant, canonical opened/replied participant IDs, contact variation |
| Consequence/follow-up | entry, display day, source invitation, friend/pair, closure state, miss reason, witnessed-Hospital flag |
| Solo pre-challenge | entry, day, friend, challenge slot, tier, tone, attitude, due echoes, attempt residue ID |
| Solo post-challenge | all pre fields plus board result, Perfect reason set, relationship outcome, effect receipt, promotion result |
| Hospital | entry, day, qualifying cause, exact accepted/unfulfilled records, Sylvia witness result when applicable |
| Pair pre-challenge scene | entry, day/window, encounter presentation, group action/inviter/participant variation when generated, pair count receipt, stable deck state, attempt residue ID |
| Pair post-challenge scene | all pair pre fields plus board result, Perfect reason set when Perfect, full/truncated observation form, combination-witness capability |
| Solo ending/exceptional step | entry, semantic ending ID, role, friend, tier, stored tone, ending form, attitude, relevant evidence/echo inserts, playback mode, residue variant, prerequisite receipts, step token |
| P-L ending/Observer step | entry, semantic ending ID, role, pair state, deck tone, stable combination, ending form, playback mode, residue variant, prerequisite receipts, step token |
| Alone step | entry, `ending.alone`, role, ending form, Alone cause, playback mode, prerequisite receipts, step token |

Each row lists fields shared by that role family. Every concrete manifest entry
expands the applicable row into one exact discriminated schema; it may add only
fields explicitly enumerated for that entry and rejects every undeclared field.
Canonical participant-ID arrays have fixed Priscilla-then-Lavinia ordering, so
open/reply variation cannot depend on arbitrary collection order.

`ending_form` is a closed union:
`derived_sweet | derived_dark | special_forced_dark | deck_sweet | deck_dark |
alone_normal | alone_dark_mode | observer_full | observer_residue | special_full |
special_residue`. The ending identity/entry map determines which values are
legal; Alone additionally requires its cause discriminator.

No sentinel friend, fake Neutral attitude, or dummy tier is legal for P-L or
Alone. Their concrete schemas omit inapplicable solo fields entirely.

DTL may branch on the frozen presentation context. It may not query or mutate
live GameState, profile state, save objects, resources, arbitrary singletons, or
filesystem data.

### 12.4 Playback boundary

Runtime flow is:

`semantic ID + frozen context -> exact manifest locator -> validated bridge -> Dialogic.start(path, label) -> presentation -> allowlisted semantic signal -> validated idempotent command`

The bridge retains semantic identity and a unique playback token until the
entry ends. Scenes never inspect or persist physical paths/labels.

Every state-capable DTL signal is an acknowledged boundary. Dialogic may not
advance to any consequence-dependent line until the bridge returns either an
accepted result or an identical prior receipt. A rejected signal aborts the
entry at its registered continuation stage; it cannot continue presenting a
consequence the state owner refused.

A merged timeline is never legally started without a validated label. Every
master begins with a bare `return`, and every callable label block ends with its
own `return`; no label may fall through into its neighbor.

### 12.5 Mutation and commit points

State commits at the causative action, not at arbitrary prose completion:

- ordinary reply when selected;
- invitation acceptance when read;
- group activation/open/reply at their exact contact actions;
- solo board instance at challenge entry; board truth at clear/explosion; one
  relationship outcome only when the post-clear opportunity closes or an
  explosion terminates the board;
- fixed promotion immediately after result commit;
- Sylvia Hospital witness derivation in the Hospital-resolution receipt, with
  its fixed relationship and caring-history effects committed only when
  `dwm-oyo.4` consumes that receipt;
- invitation closures, miss reasons, pair mode/count, and first stable-deck draw
  in one day-resolution receipt;
- pair-board result at that visible board's terminal resolution;
- pair combination witnessed only after its registered full-observation line is
  presented; Exploded and offscreen paths have no such capability;
- Observer behavior evidence only at its registered canonical dating-scene
  action; visited-line history alone is never evidence;
- witnessed echo after its registered presentation atom is presented;
- Day 7 destination at Done, or Special/Alone faint resolution at its trigger;
- ending step only after its matching timeline completion; P-L visible ending
  completion also witnesses the stable combination it physically portrayed.

Commands use idempotent receipts. Skipping, replaying, localization fallback,
or restarting prose cannot duplicate or erase a consequence.

### 12.6 Stable line and presentation identity

Every authored line that may enter history, skip-seen, echo, Observer Capture,
Gallery collection, or save restoration owns a stable semantic line ID. IDs are
not derived from file path, line number, translated text, or label position.
Physical consolidation and prose edits therefore do not invalidate witnessed
history.

Every non-dialogue action, visual beat, or deliberate silence that may satisfy
an echo, Observer action, pair witness, resume boundary, or collection record
also owns a stable semantic `presentation_atom_id`. Atom records declare kind,
owning entry/stage, and optional associated line ID. They are never derived from
resource path, animation position, elapsed time, or translated text.

### 12.7 DTL authoring envelope

Every master begins safely, and every callable block follows this conceptual
shape:

```text
# Master timeline: presentation only.
return

label fully.namespaced.semantic.entry
# PURPOSE: why this entry exists
# CAUSAL INPUT: already-committed state represented by frozen context
# VARIATION: tier -> tone -> attitude -> echo -> exact witnessed detail
# ALLOWED SIGNALS: finite semantic IDs only
# [background path="res://..."]
# executable background / character / portrait staging
# authored dialogue or action slots
return
```

Reply A/B/C, board outcomes, tier/tone/attitude inserts, and echo variants remain
internal branches. They retain stable reply/line/effect IDs but do not multiply
public timeline labels.

### 12.8 DTL-to-domain signal allowlist

DTL may request only these command kinds:

| Signal ID | Exact payload | Valid source |
|---|---|---|
| `message.reply.commit` | `entry_id`, `reply_id`, `witnessed_line_id`, `playback_token`, `receipt_id` | The six ordinary-message entries while awaiting reply |
| `history.line.witness` | `entry_id`, `line_id`, `playback_token`, `receipt_id` | A manifest-owned line in the current entry |
| `message.echo.satisfy` | `entry_id`, `echo_id`, `presentation_atom_id`, `playback_token`, `receipt_id` | A registered echo atom actually presented in the current entry |
| `observer.evidence.commit` | `entry_id`, `evidence_id`, `presentation_atom_id`, `playback_token`, `receipt_id` | A source entry/atom explicitly registered for that Observer grammar |
| `pair.combination.witness` | `entry_id`, `combination_id`, `presentation_atom_id`, `playback_token`, `receipt_id` | A canonical visible P-L post-board entry after its full Perfect/Solved observation atom |

Payloads reject missing and extra fields. None may carry arbitrary deltas,
method names, file paths, next-entry IDs, or save data. The state owner derives
all permitted consequences from the registered semantic IDs.

Capability also depends on execution mode. Rehearsal routes ordinary-reply and
echo commands only into its disposable sandbox state and may persist only
`history.line.witness` into the separate visited-line collection. It is denied
Observer-evidence and pair-combination-witness capabilities even when replaying
a label that owns them canonically.

Invitation acceptance, board resolution, promotion, day resolution, Hospital,
pair counting, Day 7 selection, and ending completion are engine-owned commands,
not DTL signals. Dialogic's physical end notification is accepted only through
the bridge's matching playback token.

Background, character, and portrait events are presentation-only. Every static
`res://` path must belong to the entry's closed visual manifest with its expected
resource type. Missing/wrong-type required assets reject the entry before start;
optional assets use only their declared neutral fallback ID. DTL cannot
dynamically compose or load an arbitrary path or mutate domain state.

The 18 stable ordinary reply IDs are:

- `reply.ordinary.lavinia.day1.a`, `.b`, `.c`;
- `reply.ordinary.sylvia.day2.a`, `.b`, `.c`;
- `reply.ordinary.priscilla.day3.a`, `.b`, `.c`;
- `reply.ordinary.lavinia.day4.a`, `.b`, `.c`;
- `reply.ordinary.priscilla.day5.a`, `.b`, `.c`;
- `reply.ordinary.sylvia.day6.a`, `.b`, `.c`.

The shorthand suffixes above are documentation only; the runtime reply manifest
contains all 18 complete strings. Final content line IDs are added alongside the
lines they identify and must pass the same closed-manifest validation before
that content can ship.

## 13. Exact master-file ownership

Notation such as `{priscilla,lavinia}` below abbreviates a finite list for
readability. The implemented manifest must expand every member explicitly; it
must not accept patterns at runtime.

### 13.1 `day_1.dtl`

- `opening.day1`
- `tutorial.desktop_day1`
- `contact.ordinary.lavinia.day1`
- `contact.invitation.solo.priscilla.day1.offer`
- `contact.invitation.solo.sylvia.day1.offer`
- `dating.solo.priscilla.day1.pre_challenge`
- `dating.solo.priscilla.day1.post_challenge`
- `dating.solo.sylvia.day1.pre_challenge`
- `dating.solo.sylvia.day1.post_challenge`
- `hospital.faint.day1`

### 13.2 `day_2.dtl`

Day 1 solo carryovers:

- `contact.invitation.solo.priscilla.day1.nevermind`
- `contact.invitation.solo.priscilla.day1.missed_question`
- `contact.invitation.solo.sylvia.day1.nevermind`
- `contact.invitation.solo.sylvia.day1.missed_question` for ordinary miss only
- `contact.hospital_care.sylvia.day2`

Current-day entries:

- `contact.ordinary.sylvia.day2`
- `contact.invitation.solo.priscilla.day2.offer`
- `contact.invitation.solo.lavinia.day2.offer`
- `contact.invitation.group.priscilla_lavinia.day2.first_open_priscilla`
- `contact.invitation.group.priscilla_lavinia.day2.first_open_lavinia`
- `contact.invitation.group.priscilla_lavinia.day2.second_open_priscilla`
- `contact.invitation.group.priscilla_lavinia.day2.second_open_lavinia`
- `contact.invitation.group.priscilla_lavinia.day2.need_reply_priscilla_first`
- `contact.invitation.group.priscilla_lavinia.day2.need_reply_lavinia_first`
- `contact.invitation.group.priscilla_lavinia.day2.offer`
- `dating.solo.priscilla.day2.pre_challenge`
- `dating.solo.priscilla.day2.post_challenge`
- `dating.solo.lavinia.day2.pre_challenge`
- `dating.solo.lavinia.day2.post_challenge`
- `dating.group.priscilla_lavinia.day2.pre_challenge`
- `dating.group.priscilla_lavinia.day2.post_challenge`
- `dating.twofriends.priscilla_lavinia.day2.pre_challenge`
- `dating.twofriends.priscilla_lavinia.day2.post_challenge`
- `hospital.faint.day2`

Private-offscreen has no DTL entry.

### 13.3 `day_3.dtl`

- `contact.invitation.solo.priscilla.day2.nevermind`
- `contact.invitation.solo.priscilla.day2.missed_question`
- `contact.invitation.solo.lavinia.day2.nevermind`
- `contact.invitation.solo.lavinia.day2.missed_question`
- `contact.invitation.group.priscilla_lavinia.day2.busy_priscilla`
- `contact.invitation.group.priscilla_lavinia.day2.busy_lavinia`
- `contact.invitation.group.priscilla_lavinia.day2.nevermind_priscilla`
- `contact.invitation.group.priscilla_lavinia.day2.nevermind_lavinia`
- `contact.invitation.group.priscilla_lavinia.day2.judge_priscilla`
- `contact.invitation.group.priscilla_lavinia.day2.judge_lavinia`
- `contact.invitation.group.priscilla_lavinia.day2.missed_question_priscilla`
- `contact.invitation.group.priscilla_lavinia.day2.missed_question_lavinia`
- `contact.ordinary.priscilla.day3`
- `contact.invitation.solo.lavinia.day3.offer`
- `contact.invitation.solo.sylvia.day3.offer`
- `dating.solo.lavinia.day3.pre_challenge`
- `dating.solo.lavinia.day3.post_challenge`
- `dating.solo.sylvia.day3.pre_challenge`
- `dating.solo.sylvia.day3.post_challenge`
- `hospital.faint.day3`

### 13.4 `day_4.dtl`

- `contact.invitation.solo.lavinia.day3.nevermind`
- `contact.invitation.solo.lavinia.day3.missed_question`
- `contact.invitation.solo.sylvia.day3.nevermind`
- `contact.invitation.solo.sylvia.day3.missed_question` for ordinary miss only
- `contact.hospital_care.sylvia.day4`
- `contact.ordinary.lavinia.day4`
- `contact.invitation.solo.priscilla.day4.offer`
- `contact.invitation.solo.sylvia.day4.offer`
- `dating.solo.priscilla.day4.pre_challenge`
- `dating.solo.priscilla.day4.post_challenge`
- `dating.solo.sylvia.day4.pre_challenge`
- `dating.solo.sylvia.day4.post_challenge`
- `hospital.faint.day4`

Priscilla and Sylvia's post entries receive already-evaluated third-valve
promotion context.

### 13.5 `day_5.dtl`

- `contact.invitation.solo.priscilla.day4.nevermind`
- `contact.invitation.solo.priscilla.day4.missed_question`
- `contact.invitation.solo.sylvia.day4.nevermind`
- `contact.invitation.solo.sylvia.day4.missed_question` for ordinary miss only
- `contact.hospital_care.sylvia.day5`
- `contact.ordinary.priscilla.day5`
- `contact.invitation.solo.lavinia.day5.offer`
- `contact.invitation.solo.sylvia.day5.offer`
- `dating.solo.lavinia.day5.pre_challenge`
- `dating.solo.lavinia.day5.post_challenge`
- `dating.solo.sylvia.day5.pre_challenge`
- `dating.solo.sylvia.day5.post_challenge`
- `hospital.faint.day5`

Lavinia receives third-valve context; Sylvia receives fourth-valve context.

### 13.6 `day_6.dtl`

- `contact.invitation.solo.lavinia.day5.nevermind`
- `contact.invitation.solo.lavinia.day5.missed_question`
- `contact.invitation.solo.sylvia.day5.nevermind`
- `contact.invitation.solo.sylvia.day5.missed_question` for ordinary miss only
- `contact.hospital_care.sylvia.day6`
- `contact.ordinary.sylvia.day6`
- `contact.invitation.solo.priscilla.day6.offer`
- `contact.invitation.solo.lavinia.day6.offer`
- `contact.invitation.group.priscilla_lavinia.day6.first_open_priscilla`
- `contact.invitation.group.priscilla_lavinia.day6.first_open_lavinia`
- `contact.invitation.group.priscilla_lavinia.day6.second_open_priscilla`
- `contact.invitation.group.priscilla_lavinia.day6.second_open_lavinia`
- `contact.invitation.group.priscilla_lavinia.day6.need_reply_priscilla_first`
- `contact.invitation.group.priscilla_lavinia.day6.need_reply_lavinia_first`
- `contact.invitation.group.priscilla_lavinia.day6.offer`
- `dating.solo.priscilla.day6.pre_challenge`
- `dating.solo.priscilla.day6.post_challenge`
- `dating.solo.lavinia.day6.pre_challenge`
- `dating.solo.lavinia.day6.post_challenge`
- `dating.group.priscilla_lavinia.day6.pre_challenge`
- `dating.group.priscilla_lavinia.day6.post_challenge`
- `dating.twofriends.priscilla_lavinia.day6.pre_challenge`
- `dating.twofriends.priscilla_lavinia.day6.post_challenge`
- `hospital.faint.day6`

Priscilla and Lavinia's solo post entries receive fourth-valve context.

### 13.7 `day_7.dtl`

- `contact.invitation.solo.priscilla.day6.nevermind`
- `contact.invitation.solo.priscilla.day6.missed_question`
- `contact.invitation.solo.lavinia.day6.nevermind`
- `contact.invitation.solo.lavinia.day6.missed_question`
- `contact.invitation.group.priscilla_lavinia.day6.busy_priscilla`
- `contact.invitation.group.priscilla_lavinia.day6.busy_lavinia`
- `contact.invitation.group.priscilla_lavinia.day6.nevermind_priscilla`
- `contact.invitation.group.priscilla_lavinia.day6.nevermind_lavinia`
- `contact.invitation.group.priscilla_lavinia.day6.judge_priscilla`
- `contact.invitation.group.priscilla_lavinia.day6.judge_lavinia`
- `contact.invitation.group.priscilla_lavinia.day6.missed_question_priscilla`
- `contact.invitation.group.priscilla_lavinia.day6.missed_question_lavinia`
- `contact.invitation.ending.priscilla.day7.offer`
- `contact.invitation.ending.lavinia.day7.offer`
- `contact.invitation.ending.sylvia.day7.offer`
- `echo.fallback.day7`
- `hospital.faint.day7`

Day 7 has no ordinary message, solo/group date pre/post entry, challenge result,
or Day 8 carryover. After Done or faint resolution, the engine starts the first
step directly from `endings.dtl`.

### 13.8 `endings.dtl`

The exact ending-identity-to-entry capability map is:

| Stable `ending_id` | Allowed callable `entry_id` values | Form selection |
|---|---|---|
| `ending.priscilla.sweet` | `ending.priscilla.sweet` | derived Sweet |
| `ending.priscilla.dark` | `ending.priscilla.dark` | derived Dark |
| `ending.priscilla.observer` | `ending.priscilla.observer.full`, `ending.priscilla.observer.residue` | first/full setting vs residue |
| `ending.lavinia.sweet` | `ending.lavinia.sweet` | derived Sweet |
| `ending.lavinia.dark` | `ending.lavinia.dark` | derived Dark |
| `ending.lavinia.observer` | `ending.lavinia.observer.full`, `ending.lavinia.observer.residue` | first/full setting vs residue |
| `ending.sylvia.sweet` | `ending.sylvia.sweet` | derived Sweet |
| `ending.sylvia.dark` | `ending.sylvia.dark` | derived Dark or `special_forced_dark` |
| `ending.sylvia.special` | `ending.sylvia.special.full`, `ending.sylvia.special.residue` | first/full setting vs residue |
| `ending.priscilla_lavinia.sweet` | `ending.priscilla_lavinia.sweet` | stable deck Sweet |
| `ending.priscilla_lavinia.dark` | `ending.priscilla_lavinia.dark` | stable deck Dark |
| `ending.priscilla_lavinia.observer` | `ending.priscilla_lavinia.observer.full`, `ending.priscilla_lavinia.observer.residue` | first/full setting vs residue |
| `ending.alone` | `ending.alone.normal`, `ending.alone.dark_mode` | resolved Alone presentation |

Each table cell expands to a distinct closed manifest record for its `entry_id`.
Full/residue and Normal/Dark-mode entries share their named semantic Gallery
identity; micro-variation remains internal and cannot create a save or Gallery
ID. A plan is invalid if its `ending_id`, `entry_id`, role, playback mode, and
ending form do not match this table.

## 14. Failure and recovery law

Playback is a transaction:

`validate entry -> freeze context -> issue token -> start exact label -> accept receipts -> complete`

### 14.1 Locator and locale failures

- Missing selected-locale path or label falls back only to the exact same
  semantic label in English.
- Missing/wrong-type English master path, or a missing/duplicated English label,
  starts nothing and preserves the pending event.
- Fallback may change language only. It may not change day, route, friend,
  entry, ending, or consequence.
- The bridge never starts a merged file at its beginning as fallback.

### 14.2 Context and signal failures

- Missing or invalid frozen context is rejected before playback.
- Unknown signal, wrong/missing/extra payload field, forbidden source entry,
  wrong mode/phase, or stale token applies zero mutation and rejects the
  acknowledged boundary. The bridge aborts to the entry's registered
  continuation stage before Dialogic can present consequence-dependent prose.
- A valid receipt repeated with the identical command returns/reuses the existing
  result without another effect.
- The same receipt reused for different command data is a conflict; neither the
  new command nor a merge is applied.

### 14.3 Interrupted playback

- Every entry declares resumable stages around each causal/acknowledged boundary.
  Before a boundary receipt, restart that stage with the same transaction; after
  a receipt, resume its registered continuation and never offer the causative
  action again. This generic law covers invitation reads, Hospital/caring
  follow-ups, group open/reply, echoes, pair scenes, and ending layers.
- Before causal commit: restart the same semantic entry with the same
  transaction.
- After an ordinary reply commits: resume its post-reply branch using the stored
  reply ID; never offer A/B/C again.
- Mid-board: restore the exact board.
- After board resolution: restart only the post-challenge entry with its frozen
  result and committed receipt.
- Mid-ending: restart the current unfinished ending label. Completed steps never
  replay automatically.
- Missing or mismatched completion cannot advance the date queue, day, ending
  cursor, Gallery, or menu transition.
- Already committed consequences remain committed; presentation failure never
  rolls Angela backward.

### 14.4 Save durability and compatibility

Saves persist semantic entry ID, phase, frozen context, transaction ID, receipts,
contract/manifest fingerprint, `run_id`, `branch_id`, per-slot canonical attempt
pointers, ordered ending plan, and cursor. They never persist a physical path,
untrusted label, DTL line position, or mutable Node. The profile-owned run ledger
including its P-L draw receipt, and attempt history are stored separately and
merged by ID; a slot snapshot is never allowed to replace them wholesale.

Writes are atomic: write a temporary candidate, validate it, replace the target,
and retain a last-known-good backup. Compatible prose, translation, and physical
file moves preserve saves because semantic contracts remain stable. Breaking
semantic changes require an explicit migration map and contract-version bump.

Operations spanning a run slot and profile use a recoverable transaction journal:

1. Build and validate detached next run/profile values and one idempotency key.
2. Durably append an intent containing target slot, precondition hashes, and the
   exact profile/run receipts before either target advances.
3. Apply the profile side and run-slot side by independent atomic replacement.
4. On startup or load, replay any incomplete intent into whichever side is
   missing; identical receipts are no-ops and conflicts stop recovery.
5. Mark the intent complete only after both validated targets contain it.

This protocol owns ending completion plus Gallery/milestone/cursor updates and
any other cross-store operation. A crash may leave a pending intent, never an
ambiguous canon. The run cannot advance past an ending step until reconciliation
proves its profile discovery and milestone side durable.

Future, malformed, corrupt, or unmappable saves are rejected without overwriting
the slot or partially mutating run/profile state. The game never substitutes
Alone, a day start, or another route for incompatible data.

### 14.5 Player-facing recovery

Technical failure remains outside the fiction. Release builds show a quiet
Retry/Return-to-Title recovery surface and accurately say whether progress is
pending or already safe. They do not expose internal IDs. Developer diagnostics
record the entry, label, context validation, signal, token, and receipt reason.

## 15. Verification design

The existing GUT framework remains the single test framework. Pure domain tests
use injected fakes and a compact reference model. Headless integration tests use
the real project bridge and Dialogic addon. Tests validate project integration,
not Dialogic internals or pixel-perfect prose presentation.

### 15.1 P0 invariants

| Area | Required proof |
|---|---|
| Manifest | Every presentation `entry_id` has exactly one valid locator/role; every ending ID/form maps only to its finite allowed entries; labels exist, return, and never fall through; retired/unknown IDs fail |
| Seven-day model | Seeded generated action sequences preserve day bounds, invitation closure, schedule legality, stat ownership, monotonic tiers, and one valid terminal plan |
| Save equivalence | Save/restore/continue equals uninterrupted canonical execution except the explicit post-first-ending pre-challenge regeneration boundary; older saves merge the monotonic run ledger and every causally reached effect |
| Exactly once | Repeating generation, reply, result, Hospital, pair count, promotion, ending, or Gallery receipts never duplicates effects; conflicting reuse fails |
| Promotion | Every friend/window/attendance/Hospital combination at affection 3/4 and 7/8 proves fixed valves, one-step maximum, and no relocation |
| P-L truth table | Exhaust both windows across solo P/L and group-offer states; each window counts zero or exactly one according to law |
| Ending order | Exhaust legal one-to-four-step plans and every resume cursor; only matching completion advances, P-L remains last, and mutually impossible solo-Observer/P-L evidence never coexists |
| Faint/echo terminal order | Exhaust sequela/danger/action/Done states; Day 7 drains every pending echo atom before any faint-capable action or ending transition |

### 15.2 Domain matrix

Tests cover:

- exact ordinary message and invitation calendars;
- all 18 replies, stat neutrality, disappearance on ignore, and guaranteed echoes;
- solo read-as-acceptance alongside the preserved group-only `REPLY_REQUIRED`
  transition and opened-unanswered Private-visible/`nevermind` subvariant;
- unread, read, scheduled, missed, Hospital-missed, and Sylvia-care lifecycles;
- exact real-time/end-of-day faint predicates and notification/Done ordering;
- all six solo relationship outcomes and their independent board evidence;
- equal preassigned explosion classes without friend/state bias;
- Perfect criteria, Perfect-then-Dark, and accessibility neutrality;
- all fixed promotion gates and Sylvia's Hospital exception;
- both P-L windows, visible/offscreen modes, board legibility, stable deck, and
  counted-meeting law, including the visible ending supplying a fourth witnessed
  combination before a preconditioned Observer step;
- loading an older same-run pre-draw save after profile witness changes while
  preserving the exact run-owned P-L combination;
- board irreversibility, old-save profile privilege, exact mid-board resume, and
  branch-scoped canonical replacement attempts;
- two competing post-milestone branches from one run without cross-over;
- clear -> post-clear save -> ordinary finish/Dark terminal choice with exactly
  one relationship payout;
- Rehearsal deep-state/RNG isolation and rejection of every Observer/pair-witness
  command;
- crash injection after every cross-store transaction write and deterministic
  run/profile reconciliation;
- Day 7 boardlessness, invitation rounds, Alone, faint precedence, and tone;
- a legally reachable Sylvia Special trigger after Round 3, plus Dark mode x
  read Sylvia x qualifying faint precedence;
- text/action/visual/silence echo atoms, Day 7 oldest-first drain, and
  interruption after every atom receipt;
- all thirteen semantic ending identities, ordered combinations, full/residue
  selection, Gallery replay, hidden unseen entries, and Dark-mode Alone;
- exact solo/P-L/Alone context validation with inapplicable fields rejected;
- save migrations and non-destructive rejection.

### 15.3 Structural and end-to-end smoke tests

Every public entry starts through the real bridge, reaches its own return, emits
only allowed signals, and leaves no unexpected errors, unfinished transaction,
or neighboring-label fallthrough.

Required full-run smokes are:

1. ordinary Sweet solo route;
2. Sweet route whose four Perfect mastery results include exactly one
   Perfect-then-Dark result, followed by applicable Observer proof;
3. multiple Hospital misses plus Sylvia care;
4. both P-L windows and the final counter-ending;
5. first ending, old save, regenerated board, Rehearsal, and ordered postscripts.

One accessibility smoke completes a Perfect board and an ending with supported
non-mouse input/assistance without invalidating classification.

### 15.4 Release gates

- Domain, save, manifest, and receipt suites run on every relevant change.
- The complete GUT suite runs on every pull request.
- DTL label/manifest smokes run whenever timeline, locale, manifest, calendar, or
  ending entries change.
- All full-run smokes run before release.

The highest-risk permanent regression tests cover duplicate post-load effects,
label fallthrough, older-save ledger reconciliation, Hospital during every P-L
mode, Hospital dates counting as attended, promotion gates moving, post-clear
double payout, cross-store crash recovery, Rehearsal evidence leakage, and
completed ending steps replaying.

## 16. Documentation and migration deliverables

After written-spec approval, the implementation plan must divide work into
reversible checkpoints rather than one mixed change.

### 16.1 Documentation checkpoint

- Update `docs/design/README.md` with the bounded authority ladder.
- Rewrite `story/03-seven-day-production-map.md` as a general seven-day slot and
  event-card template with no named mystery anchor, location, event premise, or
  character-specific plot beat.
- Copy the current named material verbatim to
  `story/library/03-seven-day-plot-material-library.md` and mark it noncanonical.
- Add a bounded supersession notice to the affected ending/mechanics sections of
  `story/01` while leaving its character and narrative prose intact.
- Add supersession notices to conflicting mechanical sections of `story/05`
  without deleting its historical reasoning.
- Reconcile requirement packets and Beads work before runtime implementation.

### 16.2 Runtime-contract checkpoint

- Replace permissive path-only catalog lookup with the exact semantic-entry
  manifest.
- Add label-aware bridge startup, context validation, source-scoped signals, and
  idempotent receipts.
- Remove or disable legacy direct Dialogic starts so one bridge owns playback.

### 16.3 Domain and persistence checkpoint

- Reconcile calendar, relationship, promotion, Hospital, pair, board-journal,
  replay privilege, rehearsal, ending-plan, Gallery, and migration schemas.
- Migrate old primary/optional-epilogue ending plans into ordered steps.
- Retire standalone True identities and any conflicting computed/regressing tier,
  Day 7 board, dark-max-5, or separate solo invitation-reply/decline state. Keep
  the group-only `REPLY_REQUIRED` protocol in section 7.5.

### 16.4 Timeline checkpoint

- Create the eight executable, plot-neutral English master skeletons.
- Update Dialogic's physical timeline directory and UID ownership.
- Preserve every retained or explicitly migrated semantic entry and line
  identity while relocating it; retired IDs follow the migration/rejection
  table rather than surviving accidentally.
- Retire the 61 old English skeleton files only after exact locator coverage and
  headless label tests pass.

### 16.5 Verification checkpoint

- Add the P0, domain, structural, migration, and full-run evidence described
  above.
- Prove that production scenes use the bridge and that no legacy ending path can
  double-start playback.
- Record engine/addon versions, worktree identity, commands, counts, diagnostics,
  and bounded third-party exceptions in release evidence.

## 17. Superseded mechanical rules

The following older rules are explicitly retired for this domain:

- a selectable True path or `true_count` ending gate;
- a fifth or decisive Day 7 dating board;
- Day 7 board performance choosing Sweet/Dark;
- affection-computed or regressing relationship tiers;
- Hate as a durable tier rather than current attitude;
- a solo reply/decline choice separate from invitation reading/acceptance; the
  preserved P-L group protocol remains the sole scripted-reply exception;
- Hospital cancellation that creates no missed evidence;
- dark maximum 5;
- a two-slot `primary + optional epilogue` ending plan;
- filesystem path as timeline/save identity;
- permissive timeline suffix resolution;
- one physical DTL file per semantic event as an architectural requirement;
- missing challenge windows being silently treated as complete Perfect mastery.
- Observer appending after a Dark solo or P-L visible ending; the approved gate
  now requires its corresponding Sweet identity first.
- Sylvia's visible ending preceding Special; the approved Special chain is
  Special first, then forced-form Sylvia Dark.
- exceptional Full-once playback having no audience-controlled replay policy;
  the hidden post-discovery profile toggle now selects automatic Full/Residue.
- Dark-mode Angela blocking only Day 7; it blocks romantic schedule commitment
  throughout Days 1-7.
- ignored ordinary messages remaining in player-facing append-only history;
  only an invisible generation tombstone survives expiry.
- appearance/incident-card or attended-ordinal promotion gates; the only normal
  valves are the fixed calendar challenge slots in section 8.2.
- Day 7 accepted invitations producing Day 8-style missed evidence; terminal
  faint resolution is the explicit exception in section 11.1.

Historical documents may retain these clauses for provenance, but active
implementation and derived production templates must not.

## 18. Acceptance criteria for this design

Design approval is complete because:

- the user approves this written specification;
- frontmatter records written approval and self-review success;
- no placeholder, unresolved alternative, or contradictory rule remains.

Runtime implementation may begin only when:

- one implementation plan suite maps every task to a bounded
  specification section and relevant Godot skill;
- that plan suite explicitly preserves unrelated dirty work and migrates rather
  than silently overwrites current implementation;
- the user separately approves that plan suite and grants implementation
  authorization.

Planning is now authorized. Runtime implementation remains unauthorized until
all remaining conditions are explicitly satisfied.

Authorization update, 2026-08-27: the three conditions above are satisfied. The
plan suite exists as the roadmap plus seven child plans, the maintainer reviewed
that suite and separately granted runtime implementation authorization, and the
grant is recorded on Beads issue dwm-oyo.2. The paragraph above states the
position at written-spec review time and is retained unchanged as history.
Authorization is scoped to Phase 01, tracked as dwm-oyo.2, and every later phase
requires its own separate grant. The frontmatter of this document is the live
approval state; neither this section nor the roadmap prose is, because the
roadmap is SHA-256 bound and its review-time wording is deliberately frozen.
