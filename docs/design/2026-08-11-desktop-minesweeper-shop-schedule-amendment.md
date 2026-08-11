---
id: spec.desktop_minesweeper_shop_schedule_amendment
kind: design_amendment
schema_version: 1
amends: spec.seven_day_dialogic_flow
amends_path: docs/design/2026-08-07-seven-day-dialogic-flow-design.md
decision_status: proposed
conversational_design_status: approved
written_spec_status: review_pending
self_review_status: passed
self_reviewed_on: 2026-08-11
implementation_authorized: false
created_on: 2026-08-11
engine_line: godot_4_6
verification_engine: 4.6.3-stable-mono
language: gdscript
scope:
  - desktop_app_board_lifecycle
  - desktop_app_board_exact_persistence
  - desktop_app_round_start_boundary
  - challenge_board_materialization_under_safety_capabilities
  - shop_board_modifiers_and_safety_capabilities
  - schedule_done_warning_policy
---

# Desktop Minesweeper Lifecycle, Shop Capabilities, and Schedule-Warning Amendment

## 1. Status and objective

This document records the conversationally approved amendment for desktop-app
Minesweeper lifecycle, exact persistence, Shop capabilities, and the Schedule
Done warning queue. It narrows and corrects rules that were discovered while
designing the UI/UX, visual-art, and music/audio manuals.

The written amendment is proposed until the user reviews this file. It does not
authorize implementation. Acceptance of this amendment will authorize only the
product and domain decisions written here; requirement packets, Beads
acceptance criteria, hash-bound plans, schemas, tests, and runtime code must be
reconciled separately and only with explicit execution authority.

The objective is to preserve three qualities at once:

- the audience may explore an absurd and cruel interface without explanatory
  hand-holding;
- every accepted action has an exact deterministic consequence and truthful
  acceptance, cost, and save feedback; and
- save, reload, suspension, Shop effects, random generation, and crash recovery
  obey deterministic physical software law.

The game may conceal why something matters and may deliberately hide a
downstream capability such as Supportz. It must not falsify whether an input
was accepted, whether currency was spent, which board exists, whether a save
succeeded, or whether the run advanced.

## 2. Authority and precedence

### 2.1 Authority ladder

For this bounded decision:

1. Beads owns mutable work status, dependencies, and implementation evidence.
2. Once accepted, this amendment owns intended behavior for the six
   frontmatter scope topics.
3. The 2026-08-07 Seven-Day Flow and Dialogic Structure specification owns all
   unrelated seven-day, relationship, Hospital, ending, persistence, and
   presentation law.
4. Reconciled requirement and decision packets translate accepted design into
   executable requirements.
5. Reviewed, hash-bound plans describe implementation procedure; they do not
   invent product law or authorize runtime work.
6. Runtime code and tests describe physical reality and drift, not intended
   behavior where they conflict with accepted design.
7. Recovered documents remain historical evidence only.

Within the six scoped topics, an accepted version of this amendment controls
over conflicting wording in the 2026-08-07 design, Phase-2R requirements and
plans, recovered documents, tests, and current skeleton code. Every unrelated
August relationship, Hospital-after-committed-action, receipt, atomicity,
idempotence, save, and presentation-only rule remains unchanged.

### 2.2 Status is not execution authority

At the time of writing:

- Beads epic dwm-oyo and its seven implementation children remain open.
- Beads issue dwm-p2r.9 still requires the old lifetime save lock and active
  board logout rejection.
- The August roadmap and child plans remain proposed and hash-bound.
- Runtime implementation remains unauthorized.

This amendment does not modify any of those artifacts. It identifies the
required reconciliation work without pretending that work has occurred.

## 3. Scope boundary

### 3.1 In scope

- Desktop-app board identity, phases, start boundary, cost boundary,
  suspension, completion, forfeit, and fatal recovery.
- Exact save/load/logout behavior for an unstarted, preparing, prepared,
  active, suspended, settling, or terminal desktop board.
- The interaction between a suspended desktop board and Contacts, Schedule,
  Shop, Backup, Settings, Logout, Days 1–6 Hospital, Day 7 condition
  destinations, day advance, Load, and New Run.
- Supportz, Lucky Charm, and Debug Key ownership, purchase caps, timing,
  stacking, hidden presentation, and board-generation effects.
- First-cell safety, first-cell-zero, hidden extra mines, and deterministic
  no-guess generation.
- The two-stage materialization boundary required to apply those safety
  capabilities to solo and visible pair challenge boards without violating
  August board permanence.
- The Days 1–6 Schedule Done warning queue and its exact state fingerprint.
- Component ownership, atomic command order, isolated random streams, recovery
  journal, and evidence requirements for this scope.

### 3.2 Out of scope

- Final UI layout, styling, wording beyond the few mechanically fixed labels,
  animation, portraits, backgrounds, music, sound design, or final prose.
- Android delivery, portrait layout, export policy, or mobile lifecycle.
- Final numerical balancing outside the values explicitly fixed here.
- Redesigning ordinary Shop items other than Supportz, Lucky Charm, and Debug
  Key.
- Changing relationship challenge results, rewards, contacts, group
  activation, condition predicates, Hospital priority, or ending eligibility.
- Explaining hidden extra mines, pressure formulas, outcome formulas,
  relationship statistics, Observer gates, or ending gates to the audience.
- Implementing, testing, migrating, or reconciling runtime artifacts.
- Compatibility with unshipped pre-amendment skeleton saves.

## 4. Chosen design and alternatives

### 4.1 Chosen: a narrow product-law amendment

The approved approach preserves the August specification and adds one narrow
amendment. The later UI/UX, visual-art, and music/audio manuals will cite this
authority spine rather than restating its mechanics.

This boundary is chosen because the changes are observable product law, not
merely an implementation technique. Saving an active board, switching apps,
when a round is charged, how Debug Key works, and which warning appears all
change audience-visible behavior.

### 4.2 Alternatives rejected

#### Rewrite the August specification in place

Rejected because its plan suite is hash-bound and its accepted historical
record should remain inspectable. Silent editing would make old approvals and
plan digests misleading.

#### Put the changes only in the UI/UX manual

Rejected because generators, saves, transactions, day progression, and Shop
effects are domain law consumed by several systems. A presentation manual
cannot safely own them.

#### Preserve the old active-board lock

Rejected because the approved experience treats apps like ordinary apps:
Home/app switching, Contacts, Schedule editing, Shop, Backup, Settings, and
Logout remain available. Safety comes from exact suspension and atomic
commands, not from locking the audience inside Minesweeper.

## 5. Domain vocabulary and identity

### 5.1 Terms

- Desktop board: a Minesweeper board created from the desktop Minesweeper app.
- Challenge board: a board entered through an August relationship challenge.
- Candidate: frozen board-generation inputs whose playable layout may not yet
  have been adopted as a charged attempt.
- Prepared candidate: a Debug Key candidate whose exact certified layout and
  forced first cell are ready but have not yet consumed the desktop round or
  motivation.
- Started board: a desktop candidate whose first Reveal command has
  successfully committed, consumed its costs, and become the canonical active
  attempt.
- Suspended board: a started board whose scene is hidden while its canonical
  state remains live and resumable.
- Causal-day departure: Schedule Done/day resolution or any condition-driven
  route that ends the board's originating day context, including Days 1–6
  Hospital and the exact Day 7 terminal route.
- Causal-day instance: an opaque identity owned by RunLifecycle for one
  presentation of one logical Day 1–7 inside a branch. It remains stable across
  same-day app switching, Save, and Logout; closes on committed day departure;
  and is remapped from the selected snapshot to a fresh active identity on
  Load. A next day receives a new identity, and New Run cannot reuse one.
- Forfeit: a terminal record that retains already-paid costs and grants no
  board result or reward.
- Fatal abort: trusted technical recovery for an unrecoverable command or
  teardown failure. Ordinary audience navigation never invokes it.
- Desktop timeline generation: a continuation identity issued after a Load so
  commands made after the restored point cannot collide with receipts from the
  discarded future.
- Branch: the rewindable run continuation created by New Run or Load. A Load
  copies the selected snapshot's ordinary inventory, purchase counts, currency,
  board, and warning receipts into a new branch identity. “Per saved branch”
  means that copied state and its continuation; loading an earlier save may
  truthfully rewind it.

### 5.2 Board identity

A desktop attempt is identified by the closed tuple:

    run_id
    branch_id
    desktop_timeline_generation
    causal_day_instance
    app_round_ordinal

Every command, receipt, checkpoint, journal entry, warning-state fingerprint,
result, and forfeit record carries this identity. Difficulty alone, day alone,
seed alone, or app-round ordinal alone is never a sufficient key.

Loading a save restores its exact board contents, then issues a new branch
identity and desktop timeline generation for subsequent commands. The restored
source identity remains provenance; it is never confused with the discarded
future. New Run creates a new run and branch identity and carries no board or
receipt from the replaced run.

Continuation generation namespaces commands and receipts only. It is not board
entropy. Issuing a new continuation after Load must not itself alter the
restored board RNG position, forced cell, prepared candidate, materialized
layout, or any later deterministic draw already represented by the save.

## 6. Desktop-board lifecycle

### 6.1 Normative phases

The coordinator owns this state machine:

    Default or Lucky:
      NONE → ACTIVE_VISIBLE ↔ ACTIVE_SUSPENDED → SETTLING → NONE

    Debug:
      NONE → PREPARING → PREPARED_UNSTARTED
           → ACTIVE_VISIBLE ↔ ACTIVE_SUSPENDED → SETTLING → NONE

PREPARING and PREPARED_UNSTARTED are used only when Debug Key is active.
Default and Lucky Charm candidates materialize at the audience's chosen first
Reveal.

While canonical phase is NONE, the Minesweeper scene may render a
presentation-only difficulty selection or untouched grid shell. That view is
not a board, attempt, or save authority. With Debug active, the semantic
prepare-candidate command after difficulty choice enters PREPARING. Without
Debug, difficulty choice remains cost-free configuration and the first
semantic Reveal moves directly from NONE to ACTIVE_VISIBLE.

SETTLING is a short transactional phase for completion or forfeit. It is not a
screen on which the audience waits for the lifetime of a board. A terminal
result or forfeit is durably recorded before the board returns to NONE.

### 6.2 Configuration and candidate freeze

Opening Minesweeper and selecting or changing difficulty is free while no
candidate exists.

When Debug preparation begins, or when a Default/Lucky first Reveal begins,
the coordinator freezes:

- run, branch, continuation generation, causal day, and app-round ordinal;
- board kind and difficulty;
- dimensions and base mine count;
- pressure and penalty inputs used for hidden extras;
- the complete capability set;
- requested mine count;
- board RNG nonce and stream identity;
- generator version and solver version; and
- every gameplay-affecting configuration value.

Later Shop purchases or Settings changes cannot mutate those frozen inputs.
They affect presentation immediately where safe, or future candidates where
they affect gameplay.

### 6.3 The authoritative desktop start boundary

A desktop app round starts only when its first Reveal command successfully
commits.

For a Default or Lucky board, that command deterministically materializes the
layout around the audience-selected cell. For a Debug board, it adopts the
already prepared certified layout and accepts only the forced cell.

One atomic first-Reveal transaction:

1. validates board identity, expected revision, phase, difficulty, frozen
   capabilities, and cell eligibility;
2. materializes or adopts one exact layout;
3. records the exact first cell, layout, mine count, and generation proof;
4. consumes exactly one desktop app-round opportunity;
5. consumes exactly one motivation;
6. decrements the signed round counter;
7. records the revealed result of the first command;
8. commits a stable canonical checkpoint and idempotency receipt; and
9. publishes presentation only after the canonical commit succeeds.

If validation, generation, solver certification, persistence, or canonical
commit fails, none of those effects occur. No round, motivation, currency,
result, or opportunity is charged.

Flags, chords, alternate cells, and non-Reveal actions cannot start a board.
Duplicate delivery of the same accepted first-Reveal command returns its
existing receipt and cannot charge twice.

### 6.4 Debug preparation is not a paid attempt

Debug preparation may create and persist an exact certified layout before the
first Reveal. That candidate is cost-free and not yet an entered desktop
attempt. The preparation snapshot makes saving, app switching, logout, and
crash recovery exact without charging the audience for computation.

All cells are disabled during PREPARING. In PREPARED_UNSTARTED, only the forced
cell is Reveal-eligible. The forced cell is initially focused for keyboard and
gamepad use; touch, mouse, keyboard, and gamepad activate the same command.

When Home, app switch, Save, or Logout arrives during a preparation slice, the
coordinator finishes or rolls back only that bounded slice, records the stable
frontier, and pauses background search. Reopening or restoring Minesweeper
resumes from that exact frontier. A hidden app does not consume low-end CPU by
continuing an unbounded search.

Leaving the causal day while PREPARING or PREPARED_UNSTARTED discards the
candidate without cost, result, reward, or forfeit. Loading another save or
starting a new run replaces it as ordinary run replacement.

### 6.5 Relationship challenge boundary

Challenge candidates use the same generation capabilities and exact
persistence, but their story attempt is reserved at challenge entry according
to August law. Their first Reveal does not consume a desktop app round or
desktop motivation. This amendment does not change challenge-slot eligibility,
relationship consequences, or pair law. It preserves staged permanence while
amending which immutable artifact exists before the first Reveal.

The August pre-challenge permanence record is a two-stage immutable board:

1. before entry, freeze and append the exact BoardSpec, capability set,
   identity, RNG nonce, versions, hidden H/U/A assignment recipe, special-mine
   recipe where applicable, and story-attempt reservation;
2. for Default/Lucky, layout is explicitly null until the chosen first Reveal,
   which atomically appends one immutable materialization receipt, exact mine
   layout, exact H/U/A assignments, exact special-mine data, first cell, and
   every other board auxiliary value required by August law;
3. for Debug, the entry transaction commits only after a certified prepared
   candidate exists, and stores that same closed materialized data plus the
   exact layout and forced cell; and
4. after materialization, every save stores the exact layout and never
   regenerates it.

This narrowly amends any August wording that requires an exact layout before a
Default/Lucky first cell exists while retaining its no-reroll and
board-permanence purpose. A technical failure before the challenge entry
transaction commits reserves no story attempt. A failure after commit resumes
or recovers the same frozen candidate rather than generating a replacement.

### 6.6 Same-day suspension

Home or app switching changes ACTIVE_VISIBLE to ACTIVE_SUSPENDED. It stops board
input and presentation but does not:

- finish, refund, reroll, regenerate, relocate mines, or forfeit the board;
- release or restore its already-paid app round or motivation;
- erase revealed or flagged cells;
- prevent other apps from committing their own valid actions; or
- hold a lifetime global save lock.

Reopening Minesweeper restores the exact board and focus law. The launcher need
not reveal a special paused-board badge.

Contacts reads and replies, Schedule editing, Shop purchases, and profile
Settings commit normally while a board is suspended. Board completion later
applies typed deltas to the then-current live state; it must never restore a
whole pre-board snapshot over those valid changes.

### 6.7 Causal-day departure

Schedule Done/day resolution and a condition-driven departure end the old
causal context. They do not carry a desktop board into another day.

- PREPARING or PREPARED_UNSTARTED candidates are silently discarded without
  cost.
- ACTIVE_VISIBLE or ACTIVE_SUSPENDED boards are silently forfeited.
- A forfeit retains the consumed round and motivation.
- A forfeit grants no outcome, money, coin, relationship effect, contact or
  group progression, unlock, notification, or board-history notice.
- A board whose terminal completion transaction committed before a competing
  condition-driven departure transaction is completed, not forfeited.

On Days 1–6 the condition-driven departure remains the existing Hospital path.
On Day 7 this amendment defers to August's exact precedence: qualifying faint
with Sylvia already read begins Sylvia Special then Sylvia Totally Dark;
qualifying faint with Sylvia unread resolves Hospital-cause Normal Alone; and
enabled Dark mode wins as Dark-mode Alone. In every case, a prepared desktop
candidate is discarded and a started desktop board is forfeited before the
terminal route becomes visible.

The audience receives no forfeit confirmation or explanatory aftermath.
Schedule warnings in section 10 may offer a final opportunity to visit
Minesweeper, but they never explain hidden consequences or block Done forever.

### 6.8 Fatal recovery

Ordinary Home, app switch, Save, Logout, Schedule Done, any condition-driven
departure, Load, and New Run never call the legacy trusted
abort-and-rollback path.

A narrow fatal abort MAY remain for unrecoverable technical teardown. Before a
canonical commit, it may discard the pending intent and return to the prior
stable board checkpoint. After any canonical cost, state, result, consequence,
or route commit, recovery is forward-only: finish publication or reconciliation
from the journal and never undo that commit. It must never rewind unrelated
Contacts, Schedule, Shop, Settings, or relationship changes. A technical
failure is reported as technical failure outside the fiction.

## 7. Minesweeper safety capabilities

### 7.1 Capabilities compose

Safety is a capability set, not one scalar level in which Debug Key overrides
Lucky Charm.

| Owned items | First cell | Hidden extra mines | No-guess requirement |
|---|---|---|---|
| Neither | Audience chooses any cell; it is safe | Raw extras | No |
| Lucky Charm | Audience chooses any cell; it opens as zero | floor(raw extras / 2) | No |
| Debug Key | Seed chooses one forced safe cell | Raw extras, then deterministic reduction if certification requires it | Yes |
| Both | Seed chooses one forced cell; it opens as zero | floor(raw extras / 2), then deterministic reduction if required | Yes |

Lucky Charm and Debug Key apply to every subsequently created board candidate
in the current saved branch. They do not mutate any candidate whose inputs were
already frozen. Loading a save from before purchase restores the inventory and
continuation represented by that save.

### 7.2 Hidden extra mines

The frozen raw extra-mine request is:

    raw_extra = floor(pressure / 3) + penalty_points_today

Lucky Charm uses floor division for odd values:

    lucky_extra = floor(raw_extra / 2)

The game never labels an extra mine, exposes this formula, names the pressure
contribution, or explains Debug's fallback reductions. The board's displayed
total mine count is always truthful for the exact adopted layout.

### 7.3 First-cell materialization

For Default and Lucky boards:

1. freeze the candidate inputs and deterministic seed;
2. create the canonical ordered list of grid positions;
3. remove the audience-selected first cell;
4. with Lucky Charm, also remove all valid neighbors of that cell;
5. sample the required mines deterministically from the remaining candidates;
6. calculate numbers; and
7. atomically adopt and reveal the first cell.

First-cell safety has priority over hidden extras. If the requested total does
not fit the remaining candidate positions, the generator deterministically
reduces only extras until it fits. It never reduces the selected difficulty's
base mine count. A configuration whose base mine count itself cannot fit is a
technical failure and charges nothing.

No mine may be moved after adoption. Reload cannot reroll the layout.

### 7.4 Debug forced cell

Debug Key chooses its forced first cell uniformly from every cell in the grid.
The versioned generator defines a canonical row-major coordinate enumeration
and a named fixed-width PRNG. Its bounded sampler draws one unsigned word x,
computes limit = floor(2^word_bits / cell_count) × cell_count, rejects
x greater than or equal to limit, and uses x modulo cell_count. This removes
modulo bias when the PRNG words are uniform. The selected coordinate is frozen
before candidate search and never changes when a candidate fails verification.

The UI frames the forced cell using the ordinary focus grammar. All other cells
are noninteractive until the forced Reveal succeeds. The audience cannot flag
the forced cell, choose a substitute, or trigger first Reveal with a chord.
Debug never automatically opens or flags a cell.

### 7.5 No-guess proof

A Debug board must be provably solvable to completion after the forced first
Reveal using visible Minesweeper deductions only. The versioned verifier may
use:

- the local adjacent zero rule;
- the local adjacent full rule;
- direct subset-difference deductions whose remainder is zero or full; and
- the truthful global remaining-mine constraint.

It may not use probabilities, speculative branches, contradiction search,
arbitrary solution enumeration, oracle hints, hidden-layout inspection as a
player deduction, later mine relocation, or automatic flags.

Certification succeeds when every safe cell can be revealed through the
allowed deductions. It does not require the audience to flag every mine.

The verifier maintains canonical safe, mine, revealed-number, and unresolved
sets. A proven mine may feed later local, subset, and global deductions; a
proven safe cell is revealed in the simulation and its visible number may
create later constraints. Direct subset difference recurses over constraints
derived from visible numbered cells and previously proven cells until a
fixpoint. The global remaining-mine constraint is one ordinary constraint over
all unresolved cells and may participate in the same direct subset-difference
rule. Canonical coordinate and constraint ordering makes the proof trace
deterministic. None of these rules permits a speculative branch.

The generator may inspect a candidate's hidden layout to simulate those
strictly defined visible deductions. That internal proof does not add an
audience-visible hint or action.

### 7.6 Deterministic search priority

The priority order is:

1. preserve a certified no-guess board;
2. preserve the selected difficulty's base mine count;
3. preserve as many requested extra mines as certification permits; and
4. preserve cosmetic randomness.

For a fixed frozen request, the generator:

1. searches candidates with the full effective extra-mine request;
2. follows a versioned, deterministic candidate sequence within a bounded
   end-to-end preparation-operation budget;
3. if no candidate certifies, reduces only extra mines using a deterministic
   sequence down to zero; and
4. if necessary, uses a versioned certified fallback that preserves the base
   mine count and works for every forced cell and supported difficulty.

It never lowers the selected difficulty's base mine count and never silently
accepts a guessing board. If even the certified fallback fails because of a
technical defect or unsupported configuration, preparation fails truthfully
and charges nothing.

The end-to-end budget counts generator and verifier operations across every
candidate, every extra-mine tier, and fallback construction for one preparation
request. A second smaller constant bounds one resumable work slice. When search
exhausts its allocation, the remaining reserved allocation invokes the
certified fallback; the whole request still stays within the one hard bound.
The exact two constants are implementation-plan values chosen from benchmarks
on the largest supported board and lowest target Windows device. This design
does not invent an unevidenced millisecond or iteration number.

### 7.7 Board scopes and isolation

Default, Lucky Charm, Debug Key, and their combination apply uniformly to:

- desktop app boards;
- solo relationship challenge boards; and
- visible Priscilla–Lavinia pair boards.

They do not change offscreen/prevented encounter counting, relationship
formulas, or ending gates. Rehearsal uses isolated copies of generation state
and RNG and cannot mutate canonical inventory, receipts, counters, or global
random streams.

## 8. Shop capabilities

### 8.1 Closed item law

| Item | Price | Purchase cap | Durable effect |
|---|---:|---|---|
| Lucky Charm | 1 Minesweeper coin | Once per saved branch | Future candidates gain first-cell-zero and floor-halved hidden extras |
| Debug Key | 3 Minesweeper coins | Once per saved branch | Future candidates require a deterministic forced-cell no-guess board |
| Supportz | $45 | Once per logical day and at most three times per saved branch | Permanently adds one future desktop app-round capacity to that branch, including the current day |

Lucky Charm and Debug Key are ordinary item cards. Activating Buy performs one
atomic purchase without a quantity selector, sell action, consume action, or
confirmation dialog. Their descriptions are absent or deliberately bare and
never explain safety capabilities, hidden extras, formulas, forced-cell logic,
or no-guess certification.

Every purchase path revalidates transaction identity, quote, currency,
ownership, caps, frozen run/branch/day context, and effect IDs at commit time.
Rapid duplicate input returns one receipt and cannot double-spend.

### 8.2 Prospective application

A purchase never mutates an already frozen PREPARING, PREPARED_UNSTARTED,
ACTIVE_VISIBLE, or ACTIVE_SUSPENDED candidate. Lucky Charm, Debug Key, and
Supportz apply prospectively to later candidate creation or later capacity
checks.

The purchase remains durable if it is followed by any condition-driven
departure. It is never refunded because Days 1–6 Hospital or a Day 7 terminal
destination routed. The exact ordering is defined in section 12.

### 8.3 Supportz discovery and purchase

Supportz occupies one fixed, non-overlapping blank card area in the Shop grid.
It is inert until exactly this eligibility is true:

- two desktop app rounds have completed in the current logical day;
- the branch has fewer than three successful Supportz purchases;
- no Supportz purchase has succeeded in the current logical day; and
- the ordinary transaction can still revalidate its fixed $45 quote.

When eligible, the blank card area is activatable by pointer/touch click,
keyboard Enter/Space, and the standard gamepad confirm action. Focus uses the
ordinary visible focus outline. Assistive technology receives a neutral
blank-card button identity; it does not receive an explanation of the secret
effect.

Activation opens an in-game modal containing only the price $45 and Yes/No
choices. It must have a dialog role/name, set initial focus consistently, make
the Shop background inert, keep focus inside while open, support Close/Back as
No, and return focus to the card after dismissal.

No, Close, or Back makes no durable mutation. Yes atomically revalidates the
quote, funds, run, branch, day, eligibility, daily cap, and branch cap.

- Failure spends nothing and uses only ordinary unavailable or affordability
  feedback.
- Success spends $45, expands capacity by one, marks the card inert for the
  day, and records one idempotent internal receipt.
- After the third branch purchase, the card remains permanently inert in that
  saved branch continuation. Loading an earlier save may truthfully restore an
  earlier rewindable purchase count.
- Success has no effect description, discovery receipt, celebration, history
  entry, or explanation.
- Accessibility may announce the truthful currency change, but not the hidden
  capability.

### 8.4 Signed round counter

The ordinary daily capacity is two desktop app rounds. The Supportz floor is
zero to negative three and persists across logical-day resets. The daily
display numerator resets to two; the denominator always remains two.

A new desktop candidate is capacity-eligible only while the current numerator
is greater than the saved Supportz floor, in addition to all other ordinary
entry requirements. Thus floor zero permits two starts, floor negative one
permits three, and floor negative three permits five.

Every successful desktop first Reveal decrements the numerator:

    2/2 → 1/2 → 0/2 → -1/2 → -2/2 → -3/2

The counter appears only inside the Minesweeper app, not the global HUD. A
forfeited started board keeps its decrement. Buying Supportz grants permission
to enter the newly available negative ordinal; it does not increase the
currently displayed numerator.

Supportz rounds are extra ordinals three through five. They never count as the
first or second base round for the Schedule warning.

Supportz's two-completion eligibility counts only terminal desktop completion
receipts stamped with the current causal-day instance. A forfeit, prepared
candidate, challenge board, restored receipt from another causal day, or
Supportz extra capacity without completion does not count.

## 9. Cross-app action and board-fate law

### 9.1 Normative action matrix

| Action | PREPARING or PREPARED_UNSTARTED | ACTIVE_VISIBLE or ACTIVE_SUSPENDED |
|---|---|---|
| Home or switch app | Preserve exact candidate; hide or suspend presentation | Preserve exact board; change to ACTIVE_SUSPENDED |
| Contacts action | Preserve candidate; commit Contacts action normally | Preserve board; commit Contacts action normally |
| Schedule editing before Done | Preserve candidate and ephemeral Schedule view state | Preserve board and ephemeral Schedule view state |
| Settings | Preserve candidate; presentation/profile preferences may apply immediately | Preserve board; presentation/profile preferences may apply immediately |
| Shop purchase without a condition-driven departure | Preserve candidate; purchased gameplay capability is prospective | Preserve board; purchased gameplay capability is prospective |
| Manual or quick Save | Serialize the latest stable candidate slice exactly | Serialize the latest stable board command exactly |
| Logout | Write exact logout save, then route to title | Write exact logout save, then route to title |
| Load | Replace live run with the selected save's exact state | Replace live run with the selected save's exact state |
| Delete another user slot | Leave live candidate unchanged | Leave live board unchanged |
| Schedule Done or other ordinary day advance | Discard silently without cost | Forfeit silently with paid costs retained |
| Shop purchase whose committed effects cause a condition-driven departure | Keep purchase; discard candidate; follow the exact August destination | Keep purchase; forfeit board; follow the exact August destination |
| Durably committed board completion whose condition check causes a departure | Not applicable | Complete board and its effects, then follow the exact August destination |
| New Run | Replace old run; candidate never migrates | Replace old run; board never migrates |

Settings changes to text scale, audio, input, and other presentation preferences
may take effect while a board exists. Gameplay-affecting board configuration is
frozen in the candidate and changes only for a later candidate.

### 9.2 Save, Load, Delete, and Logout

Manual Save and quick Save remain ordinary game save actions. They do not
forfeit or finish a board and do not capture live Nodes. They serialize the
latest completed stable domain state described in section 11.

Load replaces the live branch with exactly the selected save. The ordinary
Backup load confirmation may warn that live unsaved progress will be replaced,
but it must not invent a board-specific forfeit explanation. A save containing
a candidate or board restores it exactly; one without a board clears it.

Deleting a numbered save slot uses the ordinary destructive-action
confirmation and leaves the live board untouched. It cannot delete the
internal transaction or crash-recovery journal that protects the live run.

Logout never asks for a numbered slot and never rejects solely because a board
exists. Yes atomically writes the exact live run to the normal logout/autosave
document, then routes to title. It leaves numbered manual slots untouched.
If the write fails, the game remains in the run and reports a truthful
retry/cancel technical error. It may not claim success or route with unproven
persistence. Continue restores the saved host route and exact candidate or
board; no paused-board badge is required.

### 9.3 Run replacement is not forfeit

Load and New Run replace the current run or continuation. They do not emit a
forfeit into the newly selected run, carry a board across identities, or grant
a refund in the discarded future. The standard replacement confirmation is
sufficient.

An older save may truthfully rewind ordinary desktop inventory, purchases,
currency, board progress, and Schedule warning receipts to that save's state.
The restored continuation receives a new branch identity, causal-day-instance
mapping, and desktop timeline generation so its future command and idempotency
keys cannot collide with the abandoned future.
During restore, rewindable board-local identities and warning receipts present
in the selected snapshot are atomically remapped from the saved source
generation to the new continuation generation. Their consumed/processed
meaning is preserved; receipts from the abandoned future are not imported.
The generation-remap allowlist is closed: board command scopes, board-local
idempotency receipts, causal-day-local Supportz completion receipts, and
Schedule warning-state fingerprints from the selected rewindable snapshot. It
may
not rewrite, delete, or import abandoned-future values from August's permanent
milestones, discovered ending/Gallery receipts, Observer evidence, append-only
attempt history, cross-store journal, run irreversibility overlay,
Priscilla–Lavinia deck/witness records, or global visited-line collection.
Those categories retain their exact August ownership and merge law.

### 9.4 Cross-app merge law

A board never owns a whole pre-board GameState snapshot that can later replace
the run. It owns only its typed board state, paid start receipt, and pending
typed consequences.

Completion applies validated, idempotent deltas to current live state. Contact
reads, invitations, Schedule view state, purchases, currency, preferences, and
other valid changes made after board start remain authoritative. If a rule,
such as later contact-group activation, intentionally evaluates current state
at completion, it observes the then-current canonical state exactly once.
Board topology, result classification, and any consequence input explicitly
frozen by August law remain frozen; “current live state” does not permit those
inputs to drift after the candidate was created.

## 10. Schedule Done warning queue

### 10.1 Global eligibility

The warning queue exists only on Days 1 through 6 and only while the Schedule
bar contains no date entry.

The Schedule view owns a day-local date-entry-seen latch. It becomes true the
first time any date entry is added, remains true even if that date is later
removed, survives app caching and explicit save/restore, and resets only with a
new logical-day Schedule view or an ordinary Load to a snapshot where it was
false. While the latch is true, no warning in this section may appear. Done
proceeds through the normal August Schedule commit and day-resolution path.
Day 7 never uses this warning queue.

Warnings are invitations to explore, not tutorials, locks, or explanations.
They do not expose hidden mechanics, future consequences, relationship gates,
extra rounds, forfeit, or refunds.

### 10.2 Ordered queue

For one exact unchanged warning-state fingerprint, each Done press may present
at most one eligible warning. The closed order is:

1. unread date-enabling message;
2. accepted-but-unscheduled date;
3. base Minesweeper opportunity; and
4. Done proceeds.

Closing or successfully following a warning stores one receipt keyed by
{warning_state_fingerprint, warning_kind}. The next Done press evaluates the
next eligible kind without such a receipt. Once the finite queue is exhausted,
Done must remain reachable.

Any relevant state change creates a new warning-state fingerprint and
recomputes the queue.
Loading an earlier save may restore its earlier receipts as part of ordinary
rewind.

### 10.3 Unread date-enabling message warning

This warning is eligible when at least one unread message in canonical Contacts
state could enable a date entry.

- Go/Yes opens the Contacts list only.
- It does not select a contact, open a conversation, read a message, accept an
  invitation, focus a date action, or mutate Schedule.
- X/Close dismisses the warning.
- A successful close or Contacts-list route consumes the warning receipt for
  the exact warning-state fingerprint.
- A failed route consumes nothing.

The warning does not identify which person, line, or outcome matters unless
ordinary visible Contacts state already reveals it.

### 10.4 Accepted-but-unscheduled date warning

This warning is eligible only when all are true:

- motivation is zero;
- the Schedule bar contains at least one non-date entry;
- the bar contains no date entry; and
- at least one accepted/read date is currently addable but unscheduled.

X/Close and Go/Yes only close the warning. They do not route, focus a date
button, add a date, clear the bar, refund an action, or mutate canonical state.
The apparently redundant choices are intentional and use the ordinary alert
grammar without teaching the audience what to do.

### 10.5 Base Minesweeper warning

This warning considers only the first and second base desktop app-round
ordinals. Supportz opportunities three through five never qualify.

It is eligible when a base board is unfinished or a base opportunity remains
unspent, plus one of these motivation conditions:

- motivation is greater than zero; or
- motivation is zero and the Schedule bar contains at least one non-date
  entry.

Go/Yes opens Minesweeper and preserves the ephemeral Schedule bar. It resumes
the exact unfinished board when one exists. X/Close dismisses the warning.
Successful navigation or dismissal stores the exact keyed warning receipt;
failed navigation does not.

The warning may appear even when zero motivation means the audience cannot
start a fresh board immediately. It is an eerie opportunity signal, not a
promise or explanation.

### 10.6 Queue examples

With zero motivation, a non-date Schedule entry, an accepted unscheduled date,
and an unspent second base-round opportunity:

1. the first Done press shows the accepted-date warning;
2. after dismissal or its no-op Go/Yes, the second Done press shows the
   Minesweeper warning; and
3. after dismissal or a successful Minesweeper route, the third unchanged Done
   press proceeds.

If an unread date-enabling message is also eligible, it precedes those two:
unread message, accepted date, base Minesweeper, then Done.

### 10.7 Fingerprint and receipt

The stable warning-state fingerprint includes:

- run, branch, desktop timeline generation, and causal-day identity;
- stable set of eligible unread date-enabling message IDs;
- stable set of accepted-but-unscheduled date IDs;
- the canonical Schedule view-state signature, including date/non-date entry
  classes and the date-entry-seen latch but no finished prose;
- board identity and phase, when present;
- base-round opportunity state and ordinal;
- current motivation; and
- every other canonical value used by the pure policy.

Consumed-warning receipts are not inputs to the warning-state fingerprint.
They are a separate set queried by the policy after it computes that
fingerprint. This prevents a receipt from changing its own suppression key.

The receipt records the warning-state fingerprint, warning kind, activation
transaction ID, and terminal UI result: dismissed, navigation committed, or
navigation failed. Dismissal and successful navigation are canonical receipt
events. Route commit and receipt consumption are one atomic command; a failed
route leaves the warning unconsumed.

An open warning is a pending canonical warning activation, not a consumed
receipt. If a save boundary can occur while it is open, the snapshot records
that activation and restore presents the same warning. It is consumed only by
the approved dismissal or successful-navigation terminal event.

While one warning activation is pending, another Done command with the same
activation identity idempotently returns that pending activation. A distinct
Done command is rejected as modal input and cannot create, skip, consume, or
stack another warning.

The policy never reads UI node visibility, button text, animation state, or
presentation-only randomness.

### 10.8 Relationship to board fate

Warnings resolve before Schedule Done commits. After no warning remains for the
current warning-state fingerprint, Done commits through the ordinary Schedule
transaction.
That transaction silently discards a prepared candidate or forfeits a started
board according to section 6.7.

There is no separate forfeit confirmation, unfinished-board explanation,
remaining-round tutorial, or post-forfeit notice.

## 11. Exact persistence and random ownership

### 11.1 Canonical ownership

The desktop board coordinator is the sole writer of canonical board state.
Godot Control nodes render snapshots and emit commands; they are never save
authority.

A save contains primitive, schema-validated data only. It never serializes
Nodes, Resources, Callables, signal connections, tweens, animations, hover
state, pointer state, half-applied input, or a live random-number object.

### 11.2 Required snapshot data

The exact desktop-board snapshot includes, as applicable:

- schema version;
- run, branch, source timeline generation, continuation generation,
  causal-day instance, and app-round ordinal;
- board kind, phase, difficulty, dimensions, and revision;
- frozen capability IDs and resolved capability values;
- cost reservation and paid-cost receipts;
- transaction and idempotency IDs;
- RNG stream ID, seed/nonce, and canonical draw position or equivalent
  deterministic proof;
- generator and verifier versions;
- base, raw-extra, requested, effective, and actual mine counts;
- Debug forced cell, candidate subseed, deterministic candidate ordinal,
  search frontier, operation count, and last stable preparation slice;
- first-Reveal cell;
- exact mine layout after materialization or preparation;
- revealed and flagged cell bitsets;
- result, terminal, forfeit, and settlement status;
- pending consequence stage and outbox receipts;
- Schedule warning-state fingerprints, date-entry-seen latch, pending
  activation, and consumed receipts; and
- the ephemeral Schedule view state, which this amendment newly requires to
  survive same-day app caching and an explicit save without becoming canonical
  Scheduled state.

Fields absent in a phase must be absent or use one schema-defined null form.
An implementation may not infer missing identity, layout, capability, or
transaction fields from current inventory or current GameState.

### 11.3 Stable command checkpoints

Every accepted board command is serialized per board identity and expected
revision:

- enter or resume Debug PREPARING;
- commit a completed Debug preparation slice;
- adopt PREPARED_UNSTARTED;
- first Reveal;
- reveal;
- flag or unflag;
- chord;
- terminal result;
- explicit internal settlement;
- causal-day forfeit; and
- board-related Shop or warning transaction stages.

The in-memory canonical state changes only at a completed command boundary.
Presentation animation, focus, hover, sound, and partial input never become a
checkpoint.

Routine cell commands do not require a disk write on every click. Manual Save,
quick Save, logout save, and the existing bounded autosave policy serialize the
latest completed stable command or Debug preparation slice. If a command slice
is currently executing, the save/switch/logout request waits only for that
bounded slice, never for the lifetime or completion of the board.

Rejected, stale-revision, cancelled-before-commit, or technically failed
commands leave the prior stable checkpoint byte-equivalent and charge nothing.

### 11.4 Save and restore

Restore validates the full snapshot before mutating live state. It reconstructs
canonical domain state first, then rebuilds presentation. It never reruns
inventory queries to change frozen capabilities, regenerates a materialized
layout, repeats a paid start, duplicates a result, or invents a new forced
cell.

A restored PREPARING candidate resumes from its last stable deterministic
search slice. A restored PREPARED_UNSTARTED candidate presents the same forced
cell and layout. A restored active board presents the same revealed/flagged
state. A restored SETTLING transaction finishes or rolls back only according to
its recorded journal stage.

The restore transaction records one explicit source-generation to
continuation-generation remap. It rewrites only the selected snapshot's
rewindable desktop-local command scopes and warning-state fingerprints. It
never
imports abandoned-future receipts or rewrites August's monotonic ledgers.

Pre-amendment skeleton saves that lack the required schema are unsupported
because the game has never shipped. They fail validation truthfully instead of
being guessed into a partially compatible board.

### 11.5 Isolated RNG streams

The following streams are distinct and must not perturb one another:

- desktop/challenge board generation;
- Debug forced-cell and deterministic candidate sequence;
- Priscilla–Lavinia pair-deck selection;
- presentation-only anomaly variants;
- run and transaction identity generation; and
- Rehearsal copies.

UI, Dialogic, animation, audio, _ready callbacks, and presentation anomalies
must not call a shared global RNG that can alter board layouts or identities.

Board generation records enough versioned deterministic state to reproduce and
validate its exact output. Once a layout is adopted, the layout itself is
canonical and takes precedence over regeneration from a seed.

### 11.6 Persistence is integrity, not secrecy

Local saves cannot make a hidden mine layout cryptographically secret from a
person who controls the device. The design requires schema validation,
checksums or integrity validation as appropriate, corruption detection, and
truthful errors. It does not pretend that local obfuscation is encryption or
make anti-tamper a narrative anomaly.

## 12. Component boundaries and transaction ordering

### 12.1 Logical components

#### Desktop Board Coordinator

Owns board identity, phase, revision, frozen candidate, paid start, suspension,
commands, result, forfeit, and typed consequence requests. It is the sole
canonical board writer.

#### Board Generator

A pure, versioned service. Given frozen BoardSpec, first cell or forced cell,
and deterministic candidate index, it returns one candidate layout or a typed
failure. It reads no mutable inventory or UI state.

#### No-Guess Verifier

A pure, versioned service implementing only section 7.5 deductions. It returns
a proof result and evidence suitable for tests, not an audience hint.

#### Shop Purchase Coordinator

Owns quote revalidation, currency spend, item caps, inventory/capacity effects,
idempotent purchase receipt, and the handoff to the post-commit condition
check.

#### Schedule Warning Policy

A pure policy over one canonical input snapshot. It returns the next warning
kind or none, plus the exact fingerprint. It cannot mutate Contacts, Schedule,
Minesweeper, or routing.

#### Desktop Consequence Coordinator

Owns cross-app ordering for committed actions, condition checks, Days 1–6
Hospital, Day 7 condition destinations, notifications, board completion, board
forfeit, and Schedule day departure.

#### Save Manager

Owns validated primitive snapshots, transaction journal, atomic replace,
logout/autosave documents, manual slots, restore transactions, and truthful
failure. It does not derive game rules from scene nodes.

#### Desktop Host

Owns the seven-app registry, one visible app, focus, Home/app switching, and
scene caching. It requests suspend/resume; it does not decide board costs,
layout, result, forfeit, save law, or Hospital.

#### GameState facade

Owns the live run and applies only validated, typed, idempotent domain commands.
No component may restore a broad pre-board snapshot over current state.

### 12.2 Serialization and stale input

Only one canonical board command may commit at a time for one board identity.
Every mutating input carries the expected revision and a stable transaction ID.
A duplicate returns its prior receipt; a stale but different command is
rejected without mutation.

This is a short command boundary, not a lifetime mutex. A persisted operation
marker always contains owner, phase, input fingerprint, last stable state, and
recovery action. Startup and restore reconcile any incomplete marker before
accepting new input. No orphaned lock may leave the game permanently blocked.

The Desktop Consequence Coordinator also owns one durable run-local causal
commit sequence shared by board settlement, Shop condition checks, Schedule
Done, and every condition-driven route. Whichever complete transaction obtains
the next sequence position commits first:

- terminal board completion first means the board is completed and a later
  Shop/condition action sees no active board to forfeit;
- Shop/condition departure first means it atomically forfeits the started board
  and a later completion command is stale and rejected; and
- validation time, presentation time, animation time, or signal arrival order
  can never decide this priority.

The sequence position is assigned by compare-and-swap at the final canonical
commit boundary after validation is repeated against the current run revision.
A transaction that loses that race must replan or reject; it cannot publish a
decision calculated from the stale pre-race state.

### 12.3 First-Reveal order

The exact first-Reveal order is:

1. receive one semantic Reveal command with expected identity and revision;
2. validate phase, cell eligibility, opportunity, motivation, and frozen spec;
3. materialize a Default/Lucky layout or adopt the certified Debug candidate;
4. write transaction intent;
5. atomically commit exact layout, first reveal, paid costs, signed counter,
   revision, and receipt;
6. publish the stable snapshot;
7. present the reveal; and
8. mark any disk journal stage complete when a disk-producing boundary exists.

Presentation failure never reverses the committed board or charges again.
Recovery presents the already committed state.

### 12.4 Ordinary board-command order

Reveal, flag/unflag, and chord validate identity and expected revision, compute
one deterministic next state, commit one new revision and receipt, then
present. They have no start cost after first Reveal.

### 12.5 Completion order

One validated terminal board result executes as one recoverable causal
transaction:

1. validate board identity, revision, exact terminal state, and result;
2. record one terminal result receipt;
3. compute typed board consequences under existing August caps and laws;
4. apply those deltas exactly once to current live state;
5. evaluate the fixed post-commit condition predicate and exact August
   day-specific destination;
6. if a condition-driven departure is required, durably record Days 1–6
   Hospital or the exact Day 7 destination and suppress the no-departure
   notification;
7. otherwise, enqueue the ordinary eligible notification exactly once;
8. checkpoint the complete causal state; and
9. clear the active board only after the terminal state is durable.

Result, deltas, day-specific condition destination, notification outbox, and
cleanup share a recoverable transaction/journal. A crash cannot duplicate
rewards, group activation, contact effects, or notifications, or leave a
terminal board playable.

### 12.6 Shop order

An ordinary Shop command:

1. revalidates quote, item, caps, currency, effects, and idempotency;
2. atomically commits currency and item/capacity effects with an internal
   receipt;
3. evaluates the existing condition predicate and exact August day-specific
   destination; and
4. follows Days 1–6 Hospital or the exact Day 7 destination, or emits ordinary
   no-departure feedback.

If a condition-driven departure is required while a desktop board is started,
purchase commit, board-forfeit receipt, and the exact August route intent are
stages of one recoverable causal transaction. A crash may not leave the
purchase committed while the same board remains resumable. A prepared unstarted
candidate is discarded instead.

The purchase is never undone. The exact Days 1–6 Hospital or Day 7 terminal
destination wins the route and suppresses later ordinary invitation
notification according to August law.

### 12.7 Schedule Done order

One Done input:

1. asks the pure warning policy for the next unconsumed warning;
2. if a warning exists, commits one short pending-activation record, presents
   that warning, and returns without committing Schedule;
3. a later X/Close or Go/Yes input commits the dismissal or route together with
   its consumed receipt in a separate short transaction;
4. otherwise validates the ephemeral Schedule bar under August law;
5. atomically commits Schedule, the prepared-candidate discard or started-board
   forfeit, and day-resolution intent; and
6. follows the existing August Hospital, dating, pair, day-advance, or ending
   order.

No alert, route, or animation may mutate the bar before the Schedule commit.

### 12.8 Technical failure and fiction boundary

Save corruption, unsupported schema, generator failure, verifier failure,
transaction conflict, storage failure, and recovery failure are technical
facts. They use trustworthy recovery UI and never masquerade as a horror
anomaly, fake crash, supernatural event, character action, or intentional
glitch.

## 13. Exact supersession and retained law

### 13.1 Directly superseded behavior

When accepted, this amendment replaces:

- req.save.minesweeper_lock in
  prompt_docs/requirements/persistence.md, insofar as it disables manual save
  for the lifetime of a desktop board;
- req.desktop.logout in
  prompt_docs/requirements/desktop_minesweeper_handoff.md, insofar as it rejects
  logout during an active desktop board;
- the same packet's lifetime desktop save-lock/release sequence;
- the Phase-2R foundation specification's rule that all save controls and
  shortcuts remain disabled until desktop result or rollback;
- the Phase-2R foundation and Phase-3 plan rules that the audience cannot hide,
  close, switch, or route away from an active desktop board;
- ordinary navigation through trusted abort/whole-pre-board rollback;
- desktop round and motivation consumption before the first successful Reveal;
- recovered rules declaring unfinished desktop board state transient;
- current scalar safety logic in which Debug Key overrides Lucky Charm;
- legacy Debug Key behavior that removes all extras and auto-flags a confirmed
  mine;
- the old single Minesweeper-before-Schedule predicate and its coercive
  finish-first behavior;
- legacy Go/Yes behavior that clears or refunds the Schedule bar; and
- any Supportz interpretation permitting more than one purchase in one logical
  day.

### 13.2 Retained and extended behavior

This amendment retains:

- exactly seven registered desktop apps and one visible app at a time;
- deterministic focus and day-cache reset;
- pre-consequence validation, typed receipts, idempotence, canonical
  checkpoints, and recovery;
- exact result validation and existing August board outcomes;
- Schedule bar ephemerality until Done;
- August relationship, contact, group, reward-cap, condition, Hospital,
  notification, day, ending, Gallery, and Rehearsal law;
- the signed round denominator of two;
- Supportz's negative floor capped at negative three and three-purchase branch
  maximum;
- Lucky Charm's first-cell-zero and floor-halved hidden extras; and
- exact active challenge-board persistence, extended here to desktop boards.

No retained implementation detail gains product authority merely because it is
not named. Unrelated conflicts continue to follow the authority ladder.

## 14. Reconciliation path

After explicit user acceptance, the following ordered handoff is required
before runtime work:

1. Record written acceptance and its approval date in frontmatter.
2. Register and validate the design_amendment kind and docs/design path so
   machine authority resolution can discover this amendment.
3. Reconcile authority-context and requirement/decision packets with new or
   replaced requirement IDs.
4. Amend Beads acceptance and metadata, especially dwm-p2r.9 and affected
   dwm-oyo children, without falsely closing unimplemented work.
5. Create and review a plan amendment for every affected hash-bound August
   plan; record new hashes rather than silently editing the accepted trail.
6. Update schemas, interfaces, fixtures, validators, and tests from the
   reconciled requirements.
7. Obtain explicit runtime implementation authorization.
8. Implement and execute the evidence gate.

Likely affected plan areas are August Plans 00, 02, 03, 04, 05, and 06, plus
the older Phase-3 desktop/Minesweeper contract plan. The exact plan amendment
owns file/task decomposition; this design does not.

## 15. Verification contract

Implementation is not complete until evidence covers at least:

### 15.1 Lifecycle and actions

- Every phase crossed with every applicable action in the section 9 matrix.
- Home/switch exact suspension and resume with no paused badge dependency.
- Contacts, Schedule editing, Shop, and Settings changes surviving later board
  completion.
- Prepared discard and started forfeit on Schedule day departure and on both
  Days 1–6 and Day 7 Shop-triggered condition destinations.
- A terminal completion committed before a competing condition route remaining
  completed rather than forfeited.
- Load/New Run isolation and logout exact resume.

### 15.2 Costs and idempotence

- Opening/difficulty/preparation costs nothing.
- First successful Reveal charges once.
- Every failure before canonical first-Reveal commit charges nothing.
- Duplicate Reveal, completion, purchase, warning, forfeit, and route commands
  return or reconcile one receipt.
- Stale revision and rapid multi-input tests.
- Crash injection at every journal stage with no duplicate cost, reward,
  notification, purchase, Days 1–6 Hospital, or Day 7 destination.

### 15.3 Persistence and timeline generation

- Save/restore from NONE, PREPARING at multiple stable slices,
  PREPARED_UNSTARTED, ACTIVE_VISIBLE, ACTIVE_SUSPENDED, SETTLING, terminal, and
  forfeited states.
- Exact seed, layout, forced cell, search position, reveals, flags, costs,
  counters, and receipts.
- Loading an older save produces a new continuation generation and cannot
  collide with abandoned-future command IDs.
- A new run cannot inherit any old board.
- Old unsupported schema and corrupt snapshots fail truthfully.

### 15.4 Shop and signed rounds

- Lucky and Debug each purchase once per saved branch and stack in both orders.
- Their purchase during an existing candidate affects only the next candidate.
- Supportz is inert before two completed desktop rounds.
- Pointer/touch, keyboard, gamepad, and assistive activation use the same
  purchase transaction.
- Modal focus, Close/Back, revalidation, affordability, daily cap, branch cap,
  and third-purchase permanence.
- Each day resets the visible numerator to 2/2. After three successful
  Supportz purchases on separate days, a fully upgraded later day permits five
  successful first Reveals whose exact visible sequence is
  2/2 → 1/2 → 0/2 → -1/2 → -2/2 → -3/2.
- Forfeit retains the decrement.
- A Shop-triggered Days 1–6 Hospital or Day 7 terminal destination retains the
  purchase and cannot leave a started board resumable.

### 15.5 Generator and verifier

- Default first-click safe for every cell and supported difficulty.
- Lucky first-click zero at edges, corners, and interior cells.
- Odd extra-mine values use floor division.
- Debug uses the versioned fixed-width PRNG and rejection-sampling reference
  vectors exactly; a complete reduced-domain sampler test proves equal mapping
  counts rather than relying on a statistical tolerance. A separate seed
  corpus verifies determinism and that retries never change the chosen cell.
- Same frozen request, versions, and seed produce the same candidate sequence.
- The verifier accepts all and only the versioned deduction rules.
- Full-extra search, deterministic reduction, and certified fallback preserve
  base mine count and no-guess truth.
- Both items together preserve forced-cell no-guess, zero opening, and halved
  extras.
- The displayed total mine count always equals the adopted layout.
- The bounded generator is benchmarked on the largest supported board and
  lowest target Windows class before an operation budget is frozen.

### 15.6 Schedule warning queue

- Day 7 suppression, immediate latching after any date entry, and continued
  suppression after that date is removed.
- Unread, accepted-date, and base-Minesweeper order.
- One warning per Done input and finite reachability of Done.
- Unread Go opens only Contacts list and does not read or select.
- Accepted-date buttons only close and never focus/add/clear/refund.
- Minesweeper Go preserves Schedule view state and resumes exact board.
- Positive- and zero-motivation branches.
- Base ordinal one/two inclusion and Supportz ordinal three-to-five exclusion.
- Fingerprint change recomputation, unchanged-state receipt consumption,
  save/load behavior, successful route atomicity, and failed-route retry.

### 15.7 Isolation and trust

- Board RNG, Debug search, pair deck, presentation anomaly, identity, and
  Rehearsal streams do not perturb one another.
- UI, audio, animation, Dialogic, and audience clock anomalies cannot alter
  board generation.
- Technical failures never appear as fiction.
- Save/load, currency, mine total, accepted input, and route truth remain
  accurate under every tested failure.

## 16. Written-review gate and next artifacts

This draft has conversational design approval and has passed written
self-review, but it remains proposed until the user reviews the written file.
After the user accepts the text, frontmatter may change to:

- decision_status: accepted
- written_spec_status: approved
- written_spec_approved_on: the explicit user-approval date

implementation_authorized must remain false.

After written acceptance, the design sequence returns to the original goal:

1. UI/UX authority and implementation manual;
2. visual-art direction and Godot asset-implementation manual; and
3. music/audio direction and Godot implementation manual.

Those manuals cite this amendment and the August authority spine. They do not
copy or silently change the mechanics. Runtime reconciliation and implementation
planning remain separate work requiring explicit authority.
