---
id: spec.schedule_focused_docket_folio_ui_ux_amendment
kind: design_amendment
schema_version: 1
amends: spec.desktop_minesweeper_shop_schedule_amendment
amends_path: "docs/design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md"
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
scope: ["schedule_available_ledger_and_focused_docket_folio","schedule_uncommitted_view_and_ordered_editing","schedule_day1_to_day6_projection","schedule_day7_unclassified_terminal_projection","schedule_warning_focus_and_done_handoff","schedule_dark_refusal_and_shell_integration","schedule_persistence_localization_accessibility_and_verification"]
---

# Schedule Focused Docket Folio UI/UX Amendment

## 1. Status and objective

This accepted written amendment records the conversationally approved design
for the player-facing Schedule application. It does not authorize
implementation. Requirement packets, authority registries, Beads, hash-bound
plans, schemas, manifests, localization, scenes, tests, art, audio, and runtime
code remain unchanged until separately reconciled and explicitly authorized.

The chosen Schedule is a **Focused Docket Folio** inside the accepted desktop
shell:

- one unclassified `Available` ledger presents legal sources;
- one ordered current-day Docket presents a packed sequence of up to seven
  entries on Days 1–6;
- one large folio presents the inspected entry through its name and restrained
  identifying art, without describing its mechanics;
- `Earlier`, `Later`, and `Remove` edit the inspected occurrence;
- insertion-style drag duplicates the move operation for pointer and touch;
  and
- one bare, pinned `Done` command begins the accepted warning or commit flow.

The interface must be operationally truthful without becoming explanatory. It
shows what is available, what Angela has drafted, and the order the draft will
preserve. It does not label entries as ordinary actions, solo dates, group
dates, romance, destinations, or endings; preview effects or cost; disclose
relationship gates; explain Hospital risk; or tell the audience what choice is
optimal.

### 1.1 Approved derived closures

The conversation fixed the experience. These narrow derived closures make it
deterministic and testable:

- The seven Docket positions describe one ordered sequence for the **current
  logical day**. They are never weekdays and the component is never called a
  Week Strip in player-facing or assistive output.
- The pre-Done Schedule view is durable but uncommitted. Same-day Home and
  every exact run save must preserve it without creating canonical `Scheduled`
  entries, charging Motivation, applying effects, fulfilling invitations, or
  starting a route.
- Days 1–6 use no visible or assistive category headings. `Available` is the
  only ledger heading.
- Day 4 uses the same unclassified projection. It has no Priscilla-first
  placement exception; fixed invitation round order controls availability,
  not Docket position.
- Training, Working, and Rest are repeatable through distinct occurrence
  identities. A solo or group date is not repeatable within that day's draft.
- Filled positions form one packed prefix and empty positions form one suffix.
  Persistent holes are impossible.
- Reordering is insertion, not pairwise exchange. There is no `Swap` command,
  no second selected item, and no two-item swap mode.
- Selecting another filled folio changes inspection only. It never changes
  order.
- At Day 7, activating a different eligible personal folio atomically replaces
  the one uncommitted choice. This single-choice replacement is not a Swap or
  an ordered-list move.
- Mixed Days 1–6 positions are not a literal interleaved timeline. Done applies
  ordinary entries in their relative Docket order, then the single
  condition/Hospital gate, then surviving dates in their relative Docket
  order. Cross-kind position does not insert a date scene between ordinary
  effects.
- Draft editing costs nothing. Successful Done charges the registry-backed
  cost once per committed entry. Under the retained v1 registry every entry,
  including a Day-7 personal destination, costs one Motivation; empty Done
  costs zero.
- A cross-app stat change never silently trims or rearranges a saved draft.
  Validation or Done may reject the now-unaffordable candidate unchanged.
- A committed Minesweeper or Shop action may independently trigger the retained
  immediate Days 1–6 condition/Hospital departure before Done. That causal path
  replaces the uncommitted view through its own durable receipt; it never
  commits the draft, charges its entries, fabricates warning consumption, or
  turns any draft occurrence into Scheduled truth.
- Day-7 empty Done emits only the exact typed `empty_done` terminal cause.
  Schedule never constructs an Alone ending identity or playback plan; the
  ending owner performs that later mapping.
- Minimal explanation never means silent input loss. An ordinary refused edit
  remains visibly and assistively perceivable through restrained generic
  operational status, without disclosing its hidden reason or formula. Warning
  navigation failure remains in its trusted dialog; Dark Done uses its accepted
  Angela self-talk instead of a generic status.

## 2. Authority and precedence

### 2.1 Authority spine

Within the seven frontmatter scope topics, this exact artifact controls
intended behavior over conflicting recovered documents, prompt packets,
proposed or hash-bound plans, tests, and current scaffolds.

Its direct parent is the accepted 2026-08-11 Desktop Minesweeper, Shop, and
Schedule amendment. That amendment retains authority for:

- the Days 1–6 finite warning queue and exact warning actions;
- prepared-board discard and started-board forfeit at Schedule departure;
- atomic Schedule Done admission, durability, failure, and causal routing;
- exact save, Load, logout, and cross-app merge law; and
- the fiction-versus-technical-failure boundary.

The accepted 2026-08-07 Seven-Day Flow design retains authority for:

- invitation generation, reading-as-acceptance, expiry, and fulfilment;
- the two-date cap and audience-chosen date order on Days 1–6;
- group-date occupancy and Priscilla-Lavinia consequence law;
- condition, Hospital, date, pair, and day-resolution order;
- Day-7 invitation eligibility, echo drain, faint precedence, empty Done,
  personal destination, Dark mode, Alone, and no Day 8; and
- every relationship, challenge, ending, Gallery, and narrative consequence.

Sibling accepted amendments retain scope ownership:

- Contacts owns reading, acceptance, addability, unread state, and warning Go
  behavior;
- the shell owns the 800 by 656 logical app body, Home/Back, overlay priority,
  app caching, Angela self-talk, and Dark-refusal lane;
- Settings owns 100/125/150 text, 48/64 target modes, language, contrast,
  colour differentiation, Reduced Motion, and input preferences;
- Backup and SaveManager own save-document I/O and atomic restore;
- Shop owns the retirement of gifts, GiftPicker, and GiftBox; and
- the narrative host owns full-canvas Hospital and dating presentation after a
  durable handoff.

Scope ownership wins; document date alone does not.

### 2.2 Logical review baseline and current execution state

Review is bound to immutable logical authority, not whichever worktree happens
to contain this new document:

- commit `1e6f8d3` is the accepted authority reconciliation and binds the
  approved/hash-bound August requirements and plan suite;
- descendant commit `b09bd05` is the accepted strict ScheduleRules port,
  including no Day-4-Priscilla-first rule and registry-owned repeatability;
- descendant commit `8adfb9f` is the accepted immutable Schedule action
  registry baseline; and
- the read-only Beads baseline on 2026-08-13 reports `dwm-0hi`,
  `dwm-p2r.12`, and `dwm-wks` closed while the later player-facing Schedule
  owner `dwm-oyo.3` remains open and gated.

The documentation worktree containing this amendment does not yet integrate
those descendant implementation commits. Its unwired Schedule scene and legacy
GameState paths are physical drift, not counter-authority and not evidence that
the reconciled runtime is already present here. Self-review therefore compares
this artifact against the immutable Git blobs above plus the live read-only
Beads state without merging, cherry-picking, or mutating either.

Implementation remains unauthorized. The approved plans also predate this
exact Focused Docket Folio presentation, so a successor reconciliation must
amend their UI-facing dispositions without silently rewriting their approved
bytes. This document makes no claim that its new presentation law is already
implemented, tested, or registered as live authority.

## 3. Scope boundary

### 3.1 In scope

- Schedule's physical composition inside the integrated desktop app body.
- Available-ledger and Docket projection on Days 1–6 and Day 7.
- Folio art/name anatomy and the absence of explanatory classification.
- Append, inspect, Earlier, Later, insertion-drag, Remove, and packed-prefix
  behavior.
- The saved uncommitted Schedule view and its boundary from committed Schedule.
- Schedule-local focus, input, cache, restore, accessibility, localization,
  motion, status, and failure projection.
- Physical warning-modal integration and the visible Done handoff.
- Dark-refusal projection and Day-7 one-choice presentation.
- Exact verification and reconciliation requirements for this bounded scope.

### 3.2 Out of scope

- Changing the three ordinary actions' registered effects or cost.
- Changing invitation days, eligibility, expiry, relationship gates, the
  two-date cap, group protocol, warning eligibility, Hospital predicate,
  condition formulas, ending selection, or route order.
- Exposing affection, tier, tone, attitude, hidden condition inputs, future
  consequences, or ending identity.
- Final Schedule illustrations, animation frames, sound effects, music, or
  localized prose.
- Embedding Hospital or dating presentation inside Schedule.
- Gifting or any GiftPicker/GiftBox revival.
- Runtime implementation, Beads mutation, plan execution, save migration, or
  compatibility promises for unshipped scaffold saves.
- A 200% text claim or Android/portrait composition.

## 4. Chosen design and rejected alternatives

### 4.1 Chosen design

The Schedule uses one stable two-column workstation sheet. The Available
ledger is a compact source index. The Docket is the authored-order surface and
contains a seven-position overview on Days 1–6, one focused folio, its legal
edit controls, and pinned Done.

The audience may learn effects only from committed consequences in the
persistent Angela HUD and later scenes. The Schedule does not pre-explain them.

### 4.2 Rejected alternatives

The following are rejected for the initial release:

- a horizontal seven-day calendar or weekday strip;
- separate `Ordinary Actions`, `Accepted Dates`, `Solo Date`, `Group Date`,
  `Ending Destinations`, or equivalent headings/badges;
- a single mixed card feed without a distinct ordered Docket;
- a description/effect/cost inspector;
- seven independently actionable empty placement boxes;
- drag-only editing without keyboard/controller/assistive equivalents;
- pairwise Swap, select-two-to-swap, or a visible Swap button;
- click-to-remove, double-click-to-remove, right-click-to-remove-last, or Back
  as removal;
- gifts, gift slots, gift boxes, or date-gift state;
- a Day-7 Alone card, ending label, capacity label, `Position 1`, instruction,
  or explanation beside Done; and
- a review confirmation, fake progress plate, success banner, or Hospital
  forecast after Done.

## 5. Vocabulary and ownership-facing state

### 5.1 Terms

- **Available source:** a registry-backed action or accepted invitation which
  the domain projection permits Schedule to present.
- **ScheduleView:** the exact saved, day-local, uncommitted draft and warning
  state. It is canonical run data for exact continuation but not a committed
  Schedule.
- **Draft occurrence:** one identity-bearing `draft_entry_id` appearance of a source in the
  uncommitted Docket. Repeatable ordinary sources may create several distinct
  occurrences.
- **Docket position:** a zero-based internal order position. Player-facing
  Days 1–6 may announce one-based order; Day 7 never announces its sole index.
- **Inspected occurrence:** the one presentation-only Docket occurrence whose
  large folio and controls are projected.
- **Committed Schedule:** the validated, charged, immutable day-resolution
  input created only by successful Done.
- **Insertion move:** remove one occurrence from its old position and insert it
  at a target boundary, shifting intervening occurrences without swapping a
  pair.
- **Warning-state fingerprint:** the accepted Aug-11 snapshot key from which
  the finite warning policy and receipts are evaluated.
- **Editable-view fingerprint:** the canonical hash over the accepted
  optimistic ScheduleView projection plus registry fingerprint. The append-only
  condition-departure ledger is deliberately excluded from this edit key.
- **Operational status:** one concise, localized, non-mechanical result such as
  `Unavailable`. It is visible and politely announced, never focus-owning, and
  never substitutes for trusted technical recovery.

### 5.2 State boundary

| Fact | Owner | Saved | Consequential before Done |
|---|---|---:|---:|
| available-source eligibility | domain projection | derived from saved truth | no |
| ordered draft occurrences | ScheduleView | yes | no |
| date-entry-seen latch | warning policy | yes | warning eligibility only |
| warning receipts/pending activation | warning policy | yes | warning flow only |
| condition-departure receipts | ScheduleView recovery ledger | yes; append-only | idempotent view replacement only |
| committed Schedule | Schedule commit owner | only after Done | yes |
| prepared/admitted causal transaction | desktop consequence coordinator/journal | when present | yes after admission |
| inspected occurrence/focus/scroll anchor | Schedule presenter cache | no | no |
| hover/pressed/drag/drop preview | Schedule presenter | no | no |
| Dark refusal predicate | captured `run.dark_mode_enabled` plus domain law | yes through owning facts | yes |
| visible pinned refusal | shell self-talk presenter | no | no |

No presentation object, localized string, art path, Control, NodePath, pixel
offset, animation position, or input gesture becomes gameplay truth.

ScheduleView owns no independent `revision`, `next_occurrence_ordinal`, or
transaction phase field. Optimistic edits bind the editable-view fingerprint;
the shared identity issuer supplies each `draft_entry_id`; and the desktop
consequence state plus recovery journal determine whether a Done/condition
transaction is unadmitted, admitted, or forward-recovering. UI visibility or
the mere presence of a view never overrides those owners.

## 6. Physical composition

### 6.1 App body

The accepted shell supplies an 800 by 656 logical Schedule body below its
global 64-pixel strip. Schedule uses a 16-pixel local inset, yielding a 768 by
624 logical working rect.

At the 100% wide baseline, the stable working composition is:

- Available ledger: 250 logical pixels wide;
- inter-column gap: 12 logical pixels;
- Docket: the remaining 506 logical pixels;
- pinned command/status row: 64 logical pixels high, spanning both columns;
  `Done` is its only idle interactive copy, while a reserved blank region may
  project the temporary operational status required by sections 5.1 and 9.5;
  and
- row gap above Done: 12 logical pixels.

These values define the intended baseline geometry, not permission to clip.
At 125% and 150%, functional text and 48/64 targets keep their chosen size;
local ledger/Docket regions scroll vertically and decorative art yields space.
The two-column macro topology, column order, and pinned Done row do not swap or
collapse.

### 6.2 Available ledger

The only heading is localized `Available`.

Each source folio contains:

- one mandatory localized action or known participant name;
- optional redundant identifying art; and
- non-colour focus and unavailable states.

It contains no type, category, participant-role label, description, cost,
effect, formula, route, eligibility reason, consequence, relationship state,
recommendation, tooltip explanation, or forecast.

The stable Days 1–6 source order is:

1. Training;
2. Working;
3. Rest; and
4. accepted date sources in that day's fixed invitation-generation order.

This ordering creates no category break and no placement priority. A group
source occupies its accepted generation position under its owning contact
window. Locale, affordability, selection, receipt state, and art availability
never sort sources.

### 6.3 Docket overview

Days 1–6 draw exactly seven stable positions in one ordered overview. Filled
positions are interactive folios. Empty suffix positions are quiet ruled paper:
visible as capacity rhythm but inert, nonfocusable, nonclickable, and absent
from the assistive reading tree.

The overview never labels a position as a weekday or time. Its one-based
position text, where shown or announced on Days 1–6, is purely order within the
current day.

### 6.4 Focused folio

The focused folio presents the inspected occurrence through:

- its localized action or participant name;
- optional registered nonmechanical art; and
- its current order on Days 1–6.

It presents no description or classification. Art cannot encode mechanics,
affection, tier, attitude, route, outcome, Dark/Sweet form, condition, danger,
value, or recommendation. Character art must not imply the audience has
selected an ending form.

Missing optional art uses a neutral authored paper/object mark while retaining
the mandatory name and full command. Missing required manifest integrity is a
technical failure, not an empty or unavailable gameplay state.

### 6.5 Commands

When a Days 1–6 occurrence is inspected, the command area exposes the legal
subset of:

- `Earlier`;
- `Later`; and
- `Remove`.

Unavailable boundary actions are omitted or disabled truthfully under the
shared accessibility law. There is no `Swap` command.

Done remains visually pinned and logically outside inspection. Inspection can
never consume the first Done activation.

The reserved status region is blank during ordinary idle use. It contains no
instruction, cost, explanation, forecast, or `Ready`-style filler beside Done.

## 7. Available-source projection

### 7.1 Days 1–6

Training, Working, and Rest remain present in stable order. Each is repeatable
through a separate accepted activation and distinct occurrence identity.

Date sources derive only from exact Contacts acceptance/addability receipts.
Opening an invitation may make a source available; Schedule never reads a
message, accepts an invitation, or fabricates eligibility.

### 7.2 Absent versus unavailable

The projection uses this closed distinction:

- unread, unaccepted, expired, superseded, never-unlocked, or genuinely
  ineligible date sources are absent;
- an accepted source temporarily blocked by full capacity, the date cap,
  insufficient current Motivation, or an already drafted nonrepeatable source
  may remain present but generically unavailable;
- repeatable ordinary sources remain present and may be unavailable when a new
  occurrence cannot be admitted; and
- a Dark-run romantic source remains present and addable when otherwise legal,
  because Dark refusal occurs at Done rather than by hiding the choice.

Unavailable state uses shape/boundary/text in addition to colour. It does not
expose the hidden reason, resource formula, gate, or future consequence.

### 7.3 Resource drift

An append candidate validates against current capacity and registry-backed
cost. If another app later changes Motivation, Schedule reprojects source
availability but preserves the exact existing draft. It never trims,
reorders, marks committed, or applies part of the draft.

Done performs the authoritative full revalidation. An unaffordable draft
returns unchanged so the audience may remove entries or change the live state.

## 8. Append and identity law

### 8.1 Append

One accepted activation of an available source appends one new occurrence to
the packed Docket tail.

An occurrence owns a stable day/draft-local identity independent of its current
position. Reordering preserves it. Removing and later re-adding allocates a new
occurrence identity.

Training, Working, and Rest may share their source ID across several distinct
occurrences. Solo/group sources may not appear twice in one draft. The group
source counts as one date entry and one Docket occurrence.

### 8.2 Input deduplication

One pointer/touch release cycle, keyboard Accept, controller Accept, or
assistive activation can append at most one occurrence.

OS double-click/double-tap synthesis, key repeat, a held controller button,
or duplicate signal delivery cannot append a repeatable action twice. Two
copies require two separately accepted release cycles.

Every edit request freezes one `draft_entry_id` when applicable, the expected
editable-view fingerprint, and its exact payload. The bounded UI command gate
coalesces duplicate delivery of that one in-flight request. After the first
atomic publish, any repeated request carries a stale expected fingerprint and
returns unchanged rather than appending or editing again. Changed payload
under one in-flight identity conflicts and mutates nothing.

Edit-request deduplication is not a new saved receipt ledger. Save waits for an
accepted bounded edit to publish or roll back; hide, Load, route change, and
input-owner replacement discard held/queued physical input, so no old gesture
is replayed against a later ScheduleView.

### 8.3 Date-entry-seen latch

The first successful append of any date occurrence sets the accepted day-local
date-entry-seen latch immediately. Removing that occurrence does not clear the
latch. Failed or duplicate append does not set it.

## 9. Inspect, move, drag, and remove

### 9.1 Inspection

Activating a filled Docket folio makes it the sole inspected occurrence and
updates the focused folio. Activating another filled folio replaces inspection
only. Docket order, editable-view fingerprint, resources, warning state, and canonical
facts remain byte-equivalent.

There is no second selected occurrence and no swap-armed state.

### 9.2 Earlier and Later

`Earlier` moves the inspected occurrence one position toward index zero.
`Later` moves it one position toward the tail.

They are semantic order terms, not visual left/right or language-direction
terms. RTL localization does not reverse canonical order.

Each accepted move:

1. binds the expected editable-view fingerprint, occurrence identity, source
   and target positions, and one bounded request identity;
2. prepares a complete detached candidate;
3. removes the occurrence from its old position;
4. inserts it at the target boundary and compacts all positions; and
5. atomically publishes the validated candidate only if the expected
   fingerprint still matches.

### 9.3 Pointer/touch drag

Drag begins only from the registered grip/drag affordance of a filled
occurrence. Card-body swipe/wheel remains local scrolling. The gesture uses a
minimum movement threshold so a tap remains inspection.

The grip's complete pointer/touch hit region is a semantic reorder action target
and meets the same 48-by-48 or Large-Target 64-by-64 minimum as every other
action. Its decorative mark may be smaller than that hit region. Raw drag is
not a separate sequential-focus stop: the filled folio's assistive action list
exposes `Move Earlier` and `Move Later`, and the visible Earlier/Later controls
remain the keyboard/controller route, so no modality must simulate drag motion.

Drag shows a noncanonical insertion boundary. Releasing on a legal boundary
submits the same move command as Earlier/Later over a possibly longer distance;
intervening entries shift. It never swaps a pair.

Releasing over the origin, outside legal boundaries, on an empty illegal
target, after a stale fingerprint, or during a modal cancels and restores the
unchanged projection. Edge auto-scroll may expose a legal boundary but cannot
commit until release.

Drag has full keyboard/controller/assistive parity through Earlier/Later. It is
never the sole route to any order.

### 9.4 Remove

`Remove` deletes the inspected occurrence from the uncommitted draft and shifts
every later occurrence left. It spends/refunds nothing and never cascades into
another removal.

Delete may invoke the same command only while a filled Docket occurrence owns
stable focus and no modal, drag, capture, or transaction owns input. Back never
removes.

### 9.5 No-change and rejection

A move to the same effective position returns `no_change`, does not increment
or replace the editable-view fingerprint, and causes no warning/focus churn. A rejected append, move,
drag, or remove leaves draft, resources, latch, receipts, and occurrence
identity byte-equivalent.

The presenter must show a terse localized `Unavailable`-class status and emit
one polite assistive announcement for every distinct accepted-but-refused edit.
Duplicate physical delivery of the same bounded request cannot reannounce. The
reserved status line does not shift layout or take focus. A newer edit/Done
result replaces it; the next successful Schedule mutation or safe app departure
clears it. It does not time out while foregrounded, disclose the hidden
validation reason, or repeat on resize/locale/focus restoration. Technical
failures use trusted recovery instead.

## 10. Ordered execution semantics

### 10.1 Docket order

The packed positions are canonical draft order. Done freezes filled positions
ascending by index and commits that exact order.

On Days 1–6 the day resolver consumes the order in two filtered subsequences:

1. apply every ordinary-action entry in its relative Docket order;
2. perform the single post-commit condition/Hospital evaluation;
3. if Hospital is required, it supersedes every committed date before
   attendance; otherwise
4. attend surviving date entries in their relative Docket order; then
5. continue the retained pair/follow-up/day-advance stages.

Cross-kind placement does not interleave date presentation with ordinary
effects. Moving an ordinary occurrence across only a date may therefore leave
both filtered subsequences unchanged. The UI makes no claim that every card
executes visually top-to-bottom; it shows authored order, not a clock.

Within the ordinary subsequence and within the date subsequence, order is
causal and preserved exactly.

### 10.2 Day 4

Day 4 has no Priscilla-first placement rule. An otherwise eligible Priscilla
solo occurrence may appear before or after an ordinary occurrence or another
eligible date, subject only to general capacity, eligibility, distinctness,
and date-cap law.

The fixed Day-4 invitation generation order—Priscilla first, Sylvia second—
controls source availability order only. No append, move, drag, whole-draft
validator, Done commit, restore, assistive action, or migration may force
Priscilla to Docket index zero or silently normalize her there.

## 11. Day-7 projection

### 11.1 Entry boundary

Schedule and every faint-capable desktop action remain unavailable until all
accepted Day-7 follow-ups and the exact oldest-first echo fallback are durably
complete. Schedule does not duplicate or explain that gate.

### 11.2 Available sources

Day 7 has no Training, Working, Rest, group, or other ordinary source.

The Available ledger projects only currently eligible personal invitations
which were actually read/accepted, in stable character order:

1. Priscilla;
2. Lavinia; and
3. Sylvia.

Absent/ineligible/unread sources leave no placeholder or empty-state text.
Sylvia Special, Observer, Priscilla-Lavinia layers, Sweet/Dark form, and Alone
are not selectable sources.

Each visible source and the focused folio expose only the known character name
plus neutral non-spoilery art. There is no category, date, romance,
destination, ending, capacity, `1/1`, `Position 1`, route, or outcome text,
including in the assistive tree.

### 11.3 One unlabelled choice

The model owns one internal semantic position at index zero, but the UI never
labels or announces that index.

- With no current choice, activating an eligible source inserts it.
- With one current choice, activating that same source is `no_change`.
- Activating a different eligible source atomically replaces the uncommitted
  choice while preserving the one-position law.
- `Remove` clears the choice.
- Earlier, Later, drag, and every reorder affordance are absent.

Replacement spends nothing, fulfils nothing, and creates no ending identity.
It is a one-choice picker operation, not the retired pairwise Swap command.

### 11.4 Done and faint

Empty Done commits no Schedule entry, costs zero Motivation, and begins the
exact typed `empty_done` terminal cause. Nonempty Done revalidates and atomically commits
the chosen registry-backed personal destination, charging its registered v1
cost of one Motivation.

`empty_done` contains no ending identity, form, plan, timeline, or Gallery fact.
Only the ending owner may later map that typed cause and captured run context to
the appropriate Alone presentation.

Day 7 has no warning queue, dating challenge, post-Done condition check, or Day
8. A qualifying faint before Done discards the whole uncommitted view and
follows the accepted Sylvia-Special/Hospital-cause/Alone/Dark precedence. It
creates no missed-date record. After Done admission, no faint interrupts the
terminal handoff.

### 11.5 Dark mode

An otherwise eligible personal source remains visible and selectable in a Dark
run. Done rejects the romantic commitment under section 13. The choice stays in
the Docket. Removing it and pressing empty Done emits `empty_done` with the
captured Dark run context; Schedule does not name or construct its ending.

## 12. Warning component

### 12.1 Eligibility and order

Schedule does not reinterpret warning law. On Days 1–6, while no date is in the
draft and the date-entry-seen latch is false, one Done activation may present
at most one next eligible warning for the exact fingerprint:

1. unread date-enabling message;
2. accepted-but-unscheduled date;
3. base Minesweeper opportunity; or
4. no warning, so Done proceeds.

Day 7 never calls this queue.

### 12.2 Shared physical template

All warning kinds use one restrained institutional alert component inside the
accepted shell modal safe rect. Shared appearance never merges their distinct
semantics.

The component:

- has modal dialog semantics with a localized accessible name and the exact
  warning body as its description;
- announces that name and description once when a new or restored pending
  activation opens;
- traps focus and begins on X/Close;
- exposes only the exact accepted actions for that warning;
- maps Back to its accepted Close action;
- makes Home, Schedule, and every lower app target inert;
- makes its dialog subtree the sole assistive traversal context while open;
- pauses covered public timers; and
- restores Done focus after dismissal or successful navigation. A failed Go
  keeps the same modal open and returns focus to Close.

### 12.3 Exact actions

- Unread-warning Go opens only the bare Contacts list, selects nobody, opens no
  thread, and reads nothing.
- Accepted-date X and Go both close only.
- Minesweeper Go opens/resumes the exact desktop Minesweeper state and preserves
  the Docket.
- X/Close dismisses without changing the Docket.

Dismissal or successful Go commits exactly the matching receipt. A failed Go
does not consume it or close the pending activation. It records the accepted
failed-attempt fact, leaves the same dialog visible, returns focus to Close,
and presents truthful operational failure; a later deliberate Go may issue a
new terminal navigation attempt. Pending activation is durable; exact restore
reopens that one warning rather than creating a new stack or replaying the
failed navigation automatically.

## 13. Dark refusal

When immutable `run.dark_mode_enabled` is true and the draft contains a
romantic commitment, Done is rejected without changing any occurrence, order,
latch, receipt, resource, or focus. Relationship tone, attitude, ending form,
palette appearance, or the title's pending next-run selector never substitutes
for that captured Boolean.

The only ordinary player-facing response is the accepted pinned Angela
self-talk refusal:

- its presentation fingerprint is the shell-owned exact run, branch, desktop
  generation, day, captured Dark Boolean, and ScheduleView fingerprint;
- it is admitted once for that exact fingerprint;
- it outranks ordinary self-talk;
- it is not a Schedule modal, toast, status banner, or warning;
- repeated Done on unchanged state returns the same rejection without
  duplicating, restarting, or reannouncing it;
- a committed relevant Docket edit changes the fingerprint and clears the pin;
- leaving Schedule clears the visible pin under shell law;
- obscuring the app or explicitly saving does not mutate the view or make a
  refusal receipt; and
- successful Load clears the visible pin as presentation state, while a later
  deliberate rejected Done may derive and pin the restored view's fingerprint
  once.

The domain rejection never depends on whether the self-talk string or art can
render. Missing presentation cannot permit the commitment.

This amendment creates no persistent Dark-refusal receipt in ScheduleView.
Domain rejection is recomputed from captured run truth plus the exact current
view; visible pin idempotency remains exclusively the accepted shell's
presentation law.

## 14. Done transaction and handoff

### 14.1 One activation

One Done activation binds:

- run, branch, causal-day, and the exact editable-view fingerprint;
- ordered occurrence/provenance bytes and condition-departure-ledger context;
- warning-state fingerprint and receipts;
- current resource/capability inputs required by the registry-backed commit;
- captured Dark mode;
- board-fate input; and
- one command identity.

It then:

1. asks the finite warning policy on Days 1–6 and returns if a warning is
   admitted;
2. validates the complete frozen draft and every source receipt;
3. rejects Dark romantic commitment before any mutation;
4. prepares detached replacement, committed-Schedule, board-fate,
   day-resolution/terminal, and recovery bytes under the shared mutation gate;
5. wins the one final causal-sequence/revision compare-and-swap by durably
   promoting the shared admission checkpoint;
6. only after that admission makes canonical Schedule input forward-only and
   inert;
7. atomically commits the Schedule, charges every entry's registered cost once,
   records prepared-board discard or started-board forfeit, and adopts the
   exact day-resolution/terminal intent;
8. proves the complete state durable; and
9. publishes the accepted route.

Inspection, focus, status, or a selected folio never turns this into a two-press
command. Duplicate delivery returns the stored receipt and cannot double-charge,
double-forfeit, schedule twice, or route twice.

The promoted admission checkpoint is the sole linearization point. Before it,
the canonical ScheduleView remains unchanged and a loss or failed compare-and-
swap restores editable projection byte-for-byte. After it, rollback is
forbidden and the frozen transaction recovers forward. UI may be temporarily
input-inert while detached preparation is in flight, but that visual state is
not canonical admission and cannot outlive prepare rollback.

A racing Day-7 faint, edit, Load, or other causal action is resolved by which
valid transaction wins the shared admission checkpoint first. The loser never
partially mutates ScheduleView, resources, board, lifecycle, or outboxes and is
never queued for surprise replay.

### 14.2 Quiet admitted state

After admission, the exact Docket remains visible and inert until the durable
route replaces it. There is no progress label, spinner, percentage, success
banner, review confirmation, Hospital forecast, threshold explanation, or
board-forfeit explanation.

The interface may remain visually still while an already-admitted bounded
transaction reaches its stable frontier. Home, Back, edit commands, and repeat
Done cannot cancel it or queue surprise work.

### 14.3 Failure

Expected validation rejection leaves the prior view editable and byte-equal
with concise localized operational status. It does not expose hidden rules.

A transaction, storage, schema, or recovery failure uses the trusted technical
surface. No failure masquerades as Angela, horror, a false success, a missing
folio, an ending clue, or intentional corruption. A failure before admission
retains the prior draft/resources/board. Every failure after admission recovers
forward from the frozen transaction; an indeterminate admission/commit blocks
further input until reconciliation proves the result.

### 14.4 Route boundary

Days 1–6 continue through the retained action/condition/Hospital/date/pair/day
resolver. Hospital and dating are full-canvas narrative-host sessions after
durable handoff, never Schedule subviews.

Day 7 hands off only exact terminal provenance/intent. Schedule never selects,
displays, or persists an ending identity, form, timeline, or Gallery fact.

### 14.5 Disjoint pre-Done condition departure

On Days 1–6, an admitted Minesweeper-round or Shop-purchase causal action may
meet the retained condition predicate before Done. This is a separate
condition/Hospital transaction, not a Done attempt:

1. the source action remains committed under its owning law;
2. its frozen before/after ScheduleView bytes and source condition receipt bind
   one condition-departure candidate;
3. the shared causal admission checkpoint decides the race before any live
   ScheduleView replacement;
4. forward recovery appends/reuses the exact condition-departure receipt and
   replaces the uncommitted day view as specified by the accepted condition
   flow; and
5. the full-canvas Hospital/day-resolution owner continues from its own durable
   source truth.

This path commits no Schedule, charges no draft entry, applies no draft effect,
fulfils no invitation through the draft, and neither creates nor consumes a
Schedule warning receipt. Its append-only condition-departure ledger survives
day replacement and closes retry windows, but proves only idempotent view
replacement; it is never Hospital-source proof. A failed or losing transaction
leaves the draft byte-equivalent. Schedule shows no causal forecast before the
handoff and never embeds Hospital presentation.

## 15. Focus, navigation, and cache

### 15.1 Fresh focus

Fresh Schedule entry and clean successful Load choose:

1. first legal Available source;
2. otherwise first filled Docket occurrence; or
3. otherwise Done.

This covers zero Motivation, a full/temporarily invalid source set, Day 7 with
no eligible invitation, and an empty Docket.

### 15.2 Focus graph

The semantic traversal order is:

1. visible Available sources;
2. filled Docket occurrences in order;
3. the legal controls for the inspected occurrence; and
4. Done.

Empty positions and decorative art never enter it. Tab/Shift-Tab cross regions;
arrows/D-pad move within the focused region through explicit neighbors; focus
never falls into an empty slot or the shell background. The focused item is
fully scrolled into view.

Every locally scrollable ledger, Docket/folio, and modal-body region exposes
the same semantic scrolling routes: wheel/trackpad and touch pan; keyboard
Page Up/Page Down; registered controller page-scroll actions; and assistive
scroll-forward/scroll-back actions. A scroll command applies only to the region
that owns focus or the active modal body, clamps at its boundary, and never
reorders, activates, or changes inspection. While a warning/recovery owner is
active, background regions cannot scroll through any modality. Focus movement
auto-scrolls the complete target into view, including its focus outline.

### 15.3 Post-command focus

- Append leaves focus on the source, allowing deliberate repeats.
- Inspection focuses the activated occurrence and follows it into the folio.
- Move/drag follows the same occurrence identity to its new position.
- Remove focuses the occurrence shifted into the removed position, otherwise
  the prior occurrence, otherwise the first legal source, otherwise Done.
- Warning close restores Done. Failed Go keeps its modal open and returns focus
  to Close. Dark refusal retains Done.
- A rejected edit retains its source focus and inspection.
- Day-7 replacement follows the newly chosen personal occurrence.

Hover never steals focus or inspection. Pointer, touch, keyboard, controller,
and assistive activation submit the same semantic command once.

### 15.4 Back and Home

Back follows the accepted shell precedence:

1. trusted recovery/modal owns input;
2. active drag/capture cancels without moving the draft;
3. an accepted bounded mutation is inert to Back until its stable boundary; and
4. otherwise root Back returns Home. Operational status is not its own Back
   layer; safe Home departure clears it under section 9.5.

Back never removes an entry. Home is inert during a warning, trusted modal,
recovery, active drag, or any accepted in-flight edit/Done/condition transaction
until its stable boundary. Safe Home hides Schedule, preserves the valid
same-day cache, and returns focus to the Schedule launcher icon.

### 15.5 Presentation cache

Same-day Home/reopen may cache:

- one semantic focus target;
- one inspected occurrence identity;
- semantic scroll anchors for ledger and Docket; and
- no other interaction state.

If a cached target no longer projects, use the fallback in 15.1. Day change,
successful Load, New Run/New Acc, Logout, and Entire Profile Reset clear the
cache. Save does not serialize it.

## 16. Persistence and recovery

### 16.1 Saved ScheduleView

Every exact live-run save boundary—numbered manual, Quick, Autosave including
day/logout/ending reasons, and any stable checkpoint containing the live run—
must include the same validated ScheduleView when one exists.

The saved primitive ScheduleView retains the accepted exact top-level shape:

```text
{day, causal_day_instance, entries, date_entry_seen, pending_warning,
 consumed_warning_receipts, condition_departure_receipts}
```

Each `entries` member retains the accepted exact shape:

```text
{draft_entry_id, day, slot_index, action_id, action_kind, participants,
 source_receipt_id}
```

`entries` is the packed ordered occurrence list. Its `draft_entry_id` is the
stable occurrence identity; source/participants/kind are revalidated against
the immutable registry and source-receipt owner. `condition_departure_receipts`
is an append-only map keyed by exact source condition receipt ID. Each value is
exactly:

```text
{source_condition_receipt_id, source_condition_receipt_provenance,
 schedule_view_before_sha256, schedule_view_after_sha256,
 disposition:"condition_departure_view_committed"}
```

The editable-view fingerprint hashes exactly `{day, causal_day_instance,
entries, date_entry_seen, pending_warning, consumed_warning_receipts}` plus the
accepted registry fingerprint. Full snapshot/schema validation still includes
the condition-departure ledger byte-for-byte, but ledger growth alone cannot
stale an already-issued ordinary edit expectation.

It does not include:

- committed-Schedule state for an uncommitted occurrence;
- localized names, type/category display labels, descriptions, or art paths;
- selected/inspected state, focus, hover, press, drag, insertion preview, or
  pointer capture;
- pixel scroll, Control/Node/NodePath, theme, tween, or animation state;
- a `Swap` or two-selection state; or
- a cached validation explanation;
- an independent ScheduleView revision, next-occurrence counter, edit-command
  receipt ledger, or transaction phase; or
- any ending identity/Alone plan derived from `empty_done`.

### 16.2 Save semantics

Saving ScheduleView:

- spends no Motivation;
- applies no action effect;
- fulfils no invitation;
- starts no warning or route;
- creates no committed Schedule/ending/missed-date receipt; and
- never changes the visible draft.

If a save meets an accepted in-flight draft edit, it waits only for that bounded edit
to publish or roll back. It never writes a half-drag or half-move.

### 16.3 Load

Load atomically replaces the live branch with the selected snapshot. It
restores that snapshot's ScheduleView and warning facts semantically exactly
after the accepted continuation remapper, discards old presentation cache, and
reprojects current localized text/art from semantic IDs.

This amendment introduces no remap grammar. Every identity field follows the
closed owning class registered by the accepted restore architecture: causal-day
and rewindable warning/navigation/transaction roots remap where prescribed;
source acceptance receipts must byte-match the remapped Contacts owner; and
other identities remain byte-preserved unless their registered owner declares
that class remappable. Any field with no unique owning class or any mismatch
between a remapped source receipt and its Schedule occurrence rejects. “Exact
restore” therefore means byte equality after that prescribed allowlisted remap,
never ad hoc regeneration or raw whole-view equality across branches.

An invalid source receipt, unknown registry record/version, duplicate identity,
hole, wrong day, impossible repeat, stale warning binding, or malformed Day-7
view rejects before any restore participant mutates live state. Restore never
silently trims, sorts, reclassifies, or converts an invalid view into Empty.

If a pending warning activation is valid, the modal becomes the sole restored
focus owner. Otherwise use fresh focus law.

### 16.4 Day and route transitions

Successful Done freezes the committed Schedule separately from ScheduleView.
The old editable view becomes inert resolution provenance and is not reopened
as a draft. A new logical day creates a fresh empty ScheduleView and false
date-entry-seen latch while preserving the append-only
`condition_departure_receipts` ledger exactly.

Day-7 faint discards the current uncommitted view as part of its accepted
terminal transaction. The disjoint Days 1–6 pre-Done condition/Hospital path in
14.5 replaces the editable day view through its exact retained ledger law; it
is not a Schedule commit or a Day-7 exception.

## 17. Localization, accessibility, motion, and visual direction

### 17.1 Text and language

All visible strings use localization IDs and current Primary/Secondary rules.
The UI supports `en`, `zh_CN`, and `zh_HK` release catalogs without hard-coded
English layout assumptions.

Long names wrap completely. The interface never clips, ellipsizes, silently
shrinks, overlaps, or requires horizontal text scrolling. Local vertical
scrolling is permitted in the ledger, Docket overview/folio region, and modal
body while Done and modal actions remain reachable.

### 17.2 Targets and modes

Every semantic control is at least 48 by 48 logical pixels, or 64 by 64 with
Large Targets. The 100/125/150 text presets change type metrics without
changing macro topology or Docket order.

Focus, inspection, filled/empty, available/unavailable, drag boundary, warning,
and failure states use non-colour evidence. High Contrast and every authored
colour-differentiation preset preserve the distinctions.

### 17.3 Assistive projection

The reading order matches Available sources, filled Docket occurrences,
focused folio controls, then Done.

Days 1–6 occurrences may announce localized name and `position n of 7` plus
available/selected state. They do not announce action/date/group/type, effect,
cost, relationship, eligibility reason, route, or forecast.

Day 7 announces only the visible person's name and selected/available state.
It never announces position, capacity, date, destination, ending, or form.

Art is decorative and accessibility-hidden. Mandatory textual names remain.
Move, Remove, append, warning, and Done expose semantic actions that call the
same commands as pointer input.

### 17.4 Motion and sound

Reduced Motion makes append, move, removal, folio replacement, modal, and
scroll correction static or immediate. No functionality depends on animation,
drag ghost motion, brightness, sound, or haptics.

Schedule uses restrained UI sound only when the accepted Audio/SFX channel
permits it. Essential state always has a visual and assistive equivalent.

### 17.5 Material direction

The component uses maintained old-university ledger/folio language:

- square paper wells and ruled docket marks;
- faded cream, old ink, oxidized blue, washed mint, bruised mauve, or faded
  peach within the active palette;
- restrained stamps, index tabs, and contact-sheet/object illustrations;
- stable negative space; and
- no rounded messenger bubbles, fake filesystem chrome, horror glitch, fake
  corruption, or changing record order.

Art is authored decoration, not generated from run state or RNG. It must not
flicker, reroll, age, darken, or become sinister because an entry is important,
unavailable, or dangerous.

## 18. Component and semantic-port ownership

### 18.1 Schedule presenter

Owns only:

- Control-node composition and local scrolling;
- semantic focus and inspection cache;
- folio projection from validated view models;
- pointer/touch drag recognition and noncanonical insertion preview; and
- typed UI intent emission.

It does not validate gameplay, spend resources, mutate Contacts, own save I/O,
choose warnings, evaluate Dark, forfeit boards, resolve Hospital, or route.

### 18.2 ScheduleView owner

Owns detached primitive candidate operations:

- append;
- inspect-independent ordered move;
- remove;
- Day-7 single-choice replace;
- packed-prefix validation;
- optimistic editable-view fingerprint validation and atomic candidate commit;
- append-only condition-departure receipt lookup/commit; and
- saved uncommitted view serialization.

Inspection is presentation-only and is never an argument required by a domain
edit command.

### 18.3 Registry and domain owners

The immutable Schedule action registry owns source identity, allowed day/window,
kind, participants, repeatability, cost, route/effects, and required provenance.
The UI never supplies those facts as authority.

Contacts owns accepted invitation and addability receipts. Warning policy owns
eligibility/order/fingerprint/receipts. The causal coordinator owns Done,
board fate, condition/Hospital, date/pair order, and recovery. The ending owner
consumes Day-7 terminal intent later; Schedule never constructs an ending plan.

### 18.4 Save and shell owners

SaveManager remains the sole save-document I/O and restore coordinator. The
shell owns app visibility, Home/Back, modal/layer arbitration, launcher focus,
Angela self-talk, and same-day presentation-cache lifetime.

No second coordinator or alternate save path is authorized.

## 19. Exact supersession and retained law

### 19.1 Directly superseded

Within this bounded scope, this amendment supersedes:

- recovered Schedule composition with separate action/dating/invitation rows,
  GiftPicker/GiftBox, click removal, right-click remove-last, or old warning
  copy;
- the 2026-08-03 and legacy checked-out-runtime Day-4 Priscilla-first placement exception,
  including `priscilla_first_slot_required` and matching tests;
- blanket duplicate-action rejection for registry-marked repeatable Training,
  Working, and Rest;
- immediate Motivation spend/refund during draft add/remove;
- cascade removal/sanitization of later draft entries after one edit;
- any reading of Aug-07 `ephemeral` as unsaved or discarded on Home/close—the
  view is uncommitted but explicitly save-backed under Aug-11 and this artifact;
- plans/scaffolds in which closing Schedule discards the current-day draft;
- a horizontal Week Strip as final UI;
- separate type/category headings on any day, including Day 4;
- descriptions/effects/costs in the focused folio;
- Swap, select-two swap mode, pairwise drag exchange, and persistent holes;
- Day-7 ordinary sources, category/ending labels, Position 1, capacity copy,
  or near-Done explanation; and
- any player-facing Day-7 route through a dating challenge or Day 8.

### 19.2 Retained

This amendment retains:

- seven Docket positions on Days 1–6 and the general one-cost-per-entry registry
  law;
- zero, one, or two distinct audience-ordered dates on Days 1–6;
- one group date occupying one date slot;
- read-as-acceptance and accepted-but-unscheduled invitation semantics;
- no gameplay consequence from draft editing itself, while retaining the
  separate admitted Minesweeper/Shop condition-Hospital path;
- the exact warning queue and receipts;
- atomic Done and board-fate law;
- condition/Hospital before any date attendance;
- accepted date and P-L order/consequence law;
- Day-7 echo drain, eligible read invitations, one personal choice or empty
  Done, faint precedence, no challenge, and no Day 8;
- Dark romantic-commitment refusal and the ending owner's mapping of captured
  Dark `empty_done`;
- exact save/Load/branch/recovery boundaries; and
- all global shell, Settings, Contacts, Backup, Shop, narrative-host,
  localization, accessibility, and fiction-truth laws not explicitly amended.

### 19.3 Historical evidence

Recovered documents and old plans remain historical evidence. They are not
deleted or silently rewritten. Runtime scaffolds/tests remain evidence of
physical drift until a separately approved reconciliation updates them.

## 20. Reconciliation path before implementation

Acceptance of this design must not trigger runtime work automatically. Before
implementation:

1. register this exact artifact in the machine-readable design authority
   context and document index;
2. create a successor authority/reconciliation issue rather than widening or
   reopening the closed Aug-11 reconciliation issue;
3. make that reconciliation a prerequisite of every affected Schedule/runtime
   execution owner, including the future OYO Schedule integration;
4. issue successor requirement/decision packets for ScheduleView, UI,
   warnings, Done, focus, localization, and verification with explicit
   retained/replaced/superseded dispositions;
5. reconcile the hash-bound August plan suite without silently editing its
   historical approved bytes;
6. bind the already-separated registry, committed-Schedule, ScheduleView,
   desktop consequence, SaveManager, Contacts, shell, narrative, and ending
   owners with no duplicate coordinator;
7. replace or retire the stale scene/script/localization/test expectations
   enumerated below; and
8. obtain explicit runtime implementation authority for the exact successor
   plan and Beads scope.

Current physical drift to disposition includes:

- `scenes/apps/ScheduleApp.tscn` and `scripts/ui/ScheduleApp.gd`;
- `scenes/shared/ScheduleEntryBox.tscn` and its script;
- obsolete GiftPicker/GiftBox nodes and localization;
- `scripts/domain/schedule/ScheduleRules.gd` legacy duplicate/Day-4 rules;
- `autoload/GameState.gd` immediate cost/refund/cascade/old warning paths;
- duplicate Schedule facts in `scripts/data/DataCatalog.gd`;
- stale Day-7 dating-route and warning-copy tests; and
- absent focused Schedule UI/integration/accessibility tests.

The HTML prototype remains disposable design evidence. It is neither an
authority source nor a runtime dependency and need not be updated to mirror
every final wording refinement.

## 21. Verification matrix

### 21.1 Authority and structure

- Frontmatter parent/path/scope/status are valid and implementation remains
  false.
- Authority registration resolves this amendment above conflicting recovered,
  proposed-plan, runtime, and test clauses only within scope.
- No runtime/test/localization/parser treats the HTML prototype as authority.
- Static scans find no player-facing GiftPicker/GiftBox, Swap, Day-4
  Priscilla-first, type/category heading, Day-7 Position 1, or Week Strip residue.

### 21.2 Layout and folio

- Schedule receives exactly the shell-owned 800 by 656 body and uses the fixed
  two-column Focused Docket Folio topology plus pinned 64-pixel Done row.
- Days 1–6 show one Available heading, seven quiet Docket positions, one focused
  folio, legal edit controls, and Done.
- Day 4 shows no ordinary/date/solo/group/type wording visually or
  assistively.
- Focused folio shows only mandatory name plus permitted art/order, never
  description, cost, effect, type, gate, or forecast.
- Missing optional art preserves name, target, focus, and command.
- Empty positions are visible but inert and absent from focus/accessibility.

### 21.3 Projection and append

- Days 1–6 source order is Training, Working, Rest, then accepted date sources
  in fixed invitation-generation order, with no visual groups.
- Unread/unaccepted/expired/superseded/ineligible dates are absent; temporarily
  blocked accepted sources are generically unavailable.
- Dark romantic sources remain addable when otherwise legal.
- Separate activations append repeated ordinary occurrences with distinct IDs.
- Date/group duplicates reject; group consumes one date and Docket position.
- One input release/Accept creates at most one occurrence under double-click,
  key-repeat, held-controller, duplicate-signal, and duplicate-command tests.
- First successful date append sets the seen latch; remove does not clear it.

### 21.4 Editing

- Activating another filled occurrence changes inspection only and cannot move
  either item.
- Earlier/Later perform one adjacent insertion and preserve occurrence identity.
- Long-distance drag emits the same insertion move and shifts intervening
  entries; it never swaps.
- Remove compacts left, refunds nothing, and removes nothing else.
- Same-position moves are no-change without revision churn.
- Invalid/stale edits leave draft/resources/latch/receipts byte-equivalent and
  restore exact semantic focus.
- Drag threshold distinguishes tap from drag; card-body scroll remains usable;
  invalid/cancelled drop has no canonical half-state.
- No Swap button, two-item selection, pairwise exchange command, or saved Swap
  state exists.

### 21.5 Order and Day 4

- Exhaust mixed drafts and prove ordinary relative order, one
  condition/Hospital gate, then surviving date relative order.
- Moving within either filtered subsequence changes its order; moving one item
  only across the other kind does not invent interleaving.
- Hospital prevents all committed date attendance while preserving exact miss
  consequences under owning law.
- Day-4 Priscilla may occupy every otherwise legal position before/after an
  ordinary action or Sylvia date; no validator normalizes her to index zero.

### 21.6 Warning and Dark

- Exhaust warning eligibility, order, changed fingerprints, receipts,
  one-warning-per-Done, finite reachability, and D7 suppression.
- Unread Go opens bare Contacts and reads/selects nobody.
- Accepted-date X/Go close only; Minesweeper Go preserves exact Docket/board.
- Modal traps focus, starts on Close, and makes Home/background inert. Dismissal
  or successful navigation restores Done; failed Go keeps the modal open and
  focuses Close.
- Modal exposes named dialog semantics, announces a new/restored activation
  once, and is the sole assistive traversal tree while open.
- Failed Go keeps the same pending modal/receipt unconsumed, records the failed
  attempt, and never auto-retries navigation.
- Pending warning survives every exact save kind and restore.
- Dark romantic Done rejects atomically, retains Docket/focus, and pins exactly
  one refusal; unchanged repeat is idempotent.
- Relevant edit clears the pin; missing presentation cannot bypass domain
  rejection.

### 21.7 Done and recovery

- Empty, ordinary-only, date-containing, full, restored, and externally
  invalidated drafts each revalidate at Done.
- Draft editing costs zero; successful Done charges one per v1 entry exactly
  once; empty Done charges zero.
- Prepared board discards and started board forfeits exactly once on admitted
  departure; terminal-completed board remains completed.
- Inspection never creates a two-press Done.
- After admission the exact Docket remains inert with no progress/success/
  forecast copy until durable route publication.
- Duplicate/stale/racing Done cannot double-charge, double-forfeit, route, or
  advance.
- Admission-checkpoint races prove one winner, pre-admission byte-exact
  rollback, and post-admission forward-only recovery; transient UI disablement
  is never mistaken for canonical admission.
- Failure injection at every transaction stage proves full rollback or trusted
  forward recovery without false success.
- D1–6 pre-Done Minesweeper/Shop condition departure commits no Schedule or
  draft charge/warning receipt, replaces the view idempotently through the
  append-only condition ledger, and enters the full-canvas Hospital flow.

### 21.8 Day 7

- Before echo completion Schedule/faint-capable actions remain unavailable.
- Day 7 shows only eligible read/accepted Priscilla/Lavinia/Sylvia sources in
  stable order; all other identities leave no trace.
- No ordinary/type/date/romance/destination/ending/capacity/position copy exists
  visually or assistively.
- Inserting, no-change, atomic replacement, and Remove preserve the one-choice
  law without Swap/reorder state.
- Empty Done emits exact `empty_done` at zero cost; occupied Done charges one
  and produces one terminal intent without challenge/Day8. Schedule bytes
  contain no Alone/ending identity or plan.
- Pre-Done faint discards the view and follows exact Sylvia/Dark precedence;
  no post-Done faint interrupts.
- Dark occupied Done rejects; Remove then empty Done emits `empty_done` with
  captured Dark context for the ending owner.

### 21.9 Save, Load, focus, and cache

- Every numbered/Quick/Autosave/logout/stable-checkpoint path round-trips the
  semantically exact ScheduleView after only the registered continuation
  remap, including its condition-departure ledger.
- Save creates no committed Schedule, cost, effect, fulfilment, warning start,
  route, or ending fact.
- Inspect serialized data and reject localized copy/art/path/Control/focus/
  scroll/drag/Swap state.
- Save/Load around every append/move/remove/warning boundary equals uninterrupted
  execution and contains no half-edit.
- Duplicate in-flight edit delivery is coalesced or rejected by the stale
  expected fingerprint; no saved edit-command ledger or replayed held input is
  invented.
- Invalid restored holes, duplicate IDs, wrong day, bad provenance, unknown
  version, or impossible repeat reject before mutation.
- Same-day Home/reopen restores valid semantic cache; successful Load/day/New
  Run/Logout/profile reset clears it and uses deterministic focus fallback.
- Fresh focus is first legal Available, else first filled Docket, else Done.
- Every local overflow region is reachable through wheel/trackpad/touch,
  Page Up/Down, registered controller page-scroll, and assistive scroll actions;
  modal ownership prevents background scrolling.
- Every refused edit produces visible status plus exactly one polite assistive
  announcement without focus theft, reason leakage, timeout loss, or duplicate
  announcement on reflow.

### 21.10 Release cross-product

Exercise every relevant row across:

- logical days 1–7, including Day 4 and Day 7;
- normal and captured Dark run palettes;
- empty, partial, full, restored, and externally invalidated drafts;
- no board, prepared candidate, active/suspended board, and terminal board;
- text 100%, 125%, and 150%;
- ordinary 48 and Large 64 target modes;
- `en`, `zh_CN`, and `zh_HK`;
- single and dual language where shared UI law applies;
- keyboard, controller, pointer, touch, and assistive activation;
- standard/High Contrast and every colour-differentiation preset;
- Reduced Motion on/off; and
- windowed/borderless plus the accepted shell viewport/letterbox matrix.

For every projection assert unchanged macro topology/order, complete wrapping,
no clipping/ellipsis/silent shrink/overlap/horizontal text scrolling, visible
focus, target minimums, non-colour state, and semantic/input parity. Screenshot
comparison may support visual review but cannot be the sole oracle.

## 22. Acceptance and next work

The user explicitly approved the reviewed content bytes on 2026-08-13 after
three fresh-context adversarial passes. The approved pre-lifecycle-update
content SHA-256 was
`0A48899CEBE74CEE818974FD2BD9E20F7346DFC99C54670ED9BAA6BFD448CA8D`.
An optional independent second-model opinion was offered and explicitly
skipped by the user. The lifecycle metadata therefore records
`decision_status: accepted`, `written_spec_status: approved`, and
`self_review_status: passed`.

Approval does not authorize implementation. Next work remains:

- perform the separate authority/requirements/plan/Beads reconciliation; and
- only then consider a bounded implementation plan under explicit runtime
  authority.

The next creative design mission may proceed independently, but no visual-art,
audio, localization, or runtime manual may reinterpret the Schedule state,
ordering, warning, Day-7, Dark, persistence, or focus laws established here.
