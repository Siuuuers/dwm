---
id: spec.contacts_messaging_ui_ux_canon_amendment
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
scope: ["contacts_entry_lifecycle","contacts_ui_ux","contacts_notifications","contacts_time_and_anomaly_presentation","contacts_persistence_and_accessibility","day2_pre_echo_canon","sylvia_special_draft_removal"]
---

# Contacts Messaging, UI/UX, and Canon Amendment

## 1. Status and objective

This accepted written artifact records the conversationally approved Contacts
messaging, UI/UX, timing, expiry, and anomaly design discovered while preparing
the game's future UI/UX, visual-art, and music/audio manuals. It also records two
narrow story changes:

- Day 2 replaces the former unsent-message contradiction with an ordinary
  same-minute semantic pre-echo; and
- Sylvia Special removes its separate unsent draft without replacement.

The objective is an ordinary university correspondence application whose
causal behavior is exact but whose records can feel quietly impossible. The
audience may wonder whether the game, the application, memory, or coincidence
is responsible. The interface never supplies an answer and never corrupts an
accepted command to create that doubt.

The user approved this exact written artifact on 2026-08-12 after self-review
passed. `decision_status: accepted` and `written_spec_status: approved` make it
bounded written authority within its declared scope. Approval does not authorize
implementation. Requirements, Beads, hash-bound plans, schemas, tests, scenes,
timelines, and runtime code remain unchanged.

### 1.1 Proposed derived closures

The conversation fixed the product behavior but left a few small operational
details implicit. This written pass proposes the following closures so the
design is complete and testable. Approval of this exact artifact accepts them
within scope:

- A first ordinary launcher opening focuses the Priscilla row without opening
  it. A Schedule-warning route focuses the neutral Contacts-list container and
  no friend row.
- With no open thread, the conversation pane is intentionally blank. It contains
  no `Select a contact` instruction, tutorial, empty-state illustration, or
  fabricated correspondence.
- A notification's twenty-second timeout uses monotonic foreground UI time. It
  pauses while the game lacks focus or a blocking trusted modal is open, and a
  replacing notification starts its own full interval.
- A notification never steals focus. Tab/Shift+Tab or controller shoulders
  deliberately enter or leave its two-control focus group; its timer pauses
  while either control owns focus, and Back performs X.
- Notification presentation is transient view state. Save, Load, and launcher
  reopen reconstruct unread facts but do not resurrect an expired or replaced
  toast.
- Timestamps use a compact tabular 24-hour `HH:MM` rendering. Stored authored
  time and canonical ordering never depend on localized text or the audience's
  current clock.
- A routine slip owns one time marker beneath it. Only a registered contiguous
  minute group replaces duplicate per-slip markers with one shared marker; the
  Day-2 pair is such a group.
- Day 2 first presents its two slips during the authored Returned Seat beat and
  then projects the same immutable pair into Priscilla's Contacts history.
- Every saved or restored correspondence snapshot is plain text. Trusted
  authored markup, if later needed, is a separate manifest capability and can
  never be parsed from save-derived text.
- The Day-2 pre-echo and Sylvia Special wake sequence resume by semantic stage;
  presentation animation, caret position, and scene-tree state are never save
  facts.
- The run-scoped clock-anomaly family uses one exact 1-in-16 occurrence gate and
  one shared allocation record across Contacts and the audience clock strip.
- The rare solo-invitation erasure independently uses one exact 1-in-16
  per-run occurrence gate before selecting its frozen target.

## 2. Authority and precedence

### 2.1 Authority spine

This amendment controls intended behavior within the
seven frontmatter scope topics over conflicting recovered documents, prompt
packets, proposed plans, tests, and current scaffolds.

It narrowly amends the accepted 2026-08-07 Seven-Day Flow and Dialogic
Structure design. That design retains authority for every unrelated message,
invitation, relationship, Schedule, Hospital, Day 7, ending, Gallery,
Observer, localization, recovery, and presentation rule.

The accepted 2026-08-11 Desktop Minesweeper, Shop, and Schedule amendment
retains authority for cross-app board merging, saved Schedule view, warning
routing, board fate, and technical-trust law. The accepted 2026-08-12 Shop
amendment retains authority only for its Shop scope.

The Core Story Bible and its later approved 2026-07-19 canon amendment remain
narrative authority except for the exact Day-2 and Sylvia clauses superseded in
sections 15, 16, and 23. The Seven-Day Production Map remains the derived
working view of that canon except for its matching listed clauses. This
amendment preserves the historical source files and records the later decisions
rather than silently rewriting their decision trail.

Beads owns mutable work status, dependencies, and implementation evidence. A
runtime scene or old closed issue cannot silently supersede this product law.

### 2.2 Current execution state

At the time of writing:

- runtime implementation is not authorized;
- `dwm-0hi` is already executing a different, exact authority-reconciliation
  scope and must not be silently widened;
- `dwm-p2r.6` is closed against the older Contacts packet and remains valid
  historical implementation evidence, not current target authority;
- `dwm-oyo.3` remains open and owns later player-facing Contacts composition;
- the accepted August plan suite is hash-bound and cannot be edited silently;
- current Contacts scenes and scripts are incomplete scaffolds; and
- `docs/design` amendments are not yet discoverable by the current machine
  authority resolver or prompt-doc validator.

This document claims no validator coverage, implementation completion, or
runtime compatibility.

## 3. Scope boundary

### 3.1 In scope

- The fixed Contacts screen topology, contact rail, transcript, inline reply
  controls, focus, scrolling, and app-cache behavior.
- The exact boundary between focusing, selecting, opening, bulk-reading,
  accepting, and replying.
- Ordinary messages, solo invitation presentation, and the linked
  Priscilla-Lavinia two-thread presentation.
- Contacts notification layout, timing, replacement, navigation, and
  non-mutation law.
- Authored timestamps, day separators, canonical order, the rare audience-clock
  bleed, and their trust boundary.
- Midnight erasure of unanswered ordinary messages and a rare seeded unread
  solo-invitation erasure.
- Contacts-specific persistence, idempotency, history, localization, text-size,
  TTS, assistive, and input behavior.
- The Day-2 same-minute Priscilla/Angela pre-echo.
- Removal of the Sylvia Special unsent draft.

### 3.2 Out of scope

- Final prose for the six ordinary messages, invitations, follow-ups, or
  character replies beyond the two fixed Day-2 lines.
- Changing the number or calendar positions of ordinary messages and solo
  invitation windows.
- Changing Schedule eligibility, date attendance, Hospital, relationship
  outcomes, tiers, attitudes, ending triggers, Gallery identities, or Observer
  evidence gates except for the two named story-presentation changes.
- Adding arbitrary text entry, a general message composer, voice messages,
  attachments, reactions, blocking, typing indicators, online status, or
  social-network mechanics.
- Final portrait production, animation frames, sound assets, font files, or
  palette values. Later art and audio manuals may style this fixed grammar but
  cannot change its semantics.
- Public claims of full accessibility conformance. Initial release support is
  the honestly tested 100%, 125%, and 150% text-size range.
- Runtime implementation, migrations, plan execution, or Beads mutation.

## 4. Chosen character of the application

Contacts is an ordinary correspondence tool inside an old university operating
system. It is not a modern social messenger and not a supernatural terminal.

Its horror comes from three disciplines:

1. **Exact operation.** Focus, open, read, accept, reply, expire, save, and load
   are deterministic and truthfully represented.
2. **Sparse explanation.** The audience sees messages, order, time, and current
   availability, but no hidden rule, relationship formula, invitation category,
   or causal interpretation.
3. **Normalized abnormality.** A wrong-looking record uses the same visual and
   input grammar as every ordinary record. No glitch, sting, warning icon, or
   character explanation identifies it as important.

The app uses a rough, old-school, ink-like, liminal, and slightly awkward
surface. It must not look broken, drop inputs, falsify saved state, or imitate a
technical failure.

### 4.1 Controls and input convention

In this document, `Accept` means the platform's ordinary primary UI activation
for the currently focused semantic control: keyboard Enter/Space as mapped by
the shared UI layer, controller south/A-equivalent, touch tap, pointer primary
click, or assistive activation. `Back` means the shared cancel/back semantic
action. No Contacts component binds gameplay-only board actions directly.

Focus navigation follows one semantic order across keyboard, controller, and
assistive traversal. Pointer hover can update inspection styling but never owns
canonical focus, read state, or command admission.

## 5. Domain vocabulary and ownership

The following terms are exact:

- **Delivered entry:** a canonical message, follow-up, invitation, or linked
  group entry currently available to a contact.
- **Focused row:** the contact row currently holding keyboard/gamepad/assistive
  focus. Focus is presentation only.
- **Open thread:** the one friend conversation currently projected on the right.
- **Bulk-read boundary:** one accepted activation that opens a friend and marks
  every entry delivered to that friend at command admission as read.
- **Reply boundary:** one explicit authored reply choice accepted beneath its
  source entry.
- **Presentation watermark:** the highest exact delivered sequence included in
  a successful bulk-read command. It is not a friend/day-only identifier.
- **Unanswered ordinary entry:** an ordinary message whose A/B/C reply boundary
  has not committed, whether unread or already opened.
- **Player-facing Contacts history:** the visible chronological correspondence
  in one friend thread. It is distinct from profile visited-line state, global
  narrative History, transaction receipts, and Observer evidence.
- **View cache:** same-day, noncanonical selected-thread, scroll, and focus
  presentation state.

The Contacts domain owner owns entries, canonical sequence, unread/read state,
acceptance, replies, closure, invisible tombstones, and idempotent receipts.
The UI owns only projection, selection, scrolling, focus, and transient
notification presentation.

## 6. Screen composition

### 6.1 Fixed split

Inside the approximately 800-logical-pixel computer pane, Contacts keeps one
stable master-detail composition:

- left rail: 31 percent;
- right conversation: 69 percent; and
- ordinary app shell above them, including the shared Home/app-title grammar.

The topology remains in place at 100%, 125%, and 150% text size. Text wraps and
the rail/transcript scroll locally when required. The application does not
change into a separate phone-like page flow in the initial Windows release.

### 6.2 Contact rail

The rail always contains exactly three fixed rows in this order:

1. Priscilla;
2. Lavinia; and
3. Sylvia.

Rows never reorder by recent activity. Each row exposes only:

- portrait;
- first name; and
- one binary unread mark.

There is no unread count, preview, timestamp, invitation icon, message-type
icon, typing state, online state, last-seen state, or relationship decoration.
One unread entry and several unread entries look identical. A linked
Priscilla-Lavinia delivery gives both rows the same ordinary unread mark.

Focus, selected thread, and unread are three visually and semantically distinct
states. None relies on color alone. A sold or hidden gameplay fact can never be
encoded in a portrait treatment.

### 6.3 Empty conversation state

With no open thread, the right pane remains a clean, quiet paper-grey field.
It contains no prompt, tutorial, placeholder conversation, preview, or
auto-selected friend. A Schedule warning always arrives at this exact list-only
state.

The empty conversation pane is not an unnamed focus target. On first launcher
entry the Priscilla row owns focus. On Schedule-warning entry, the app root owns
a stable assistive focus stop named `Contacts list`; its accessible description
is `Three contacts` plus the same binary unread state already exposed on each
row, never a total unread count. The next forward navigation enters Priscilla;
Back invokes the shared app-shell return action without reading anything.

## 7. Focus, activation, and bulk reading

### 7.1 Focus never reads

Pointer hover, keyboard/gamepad focus, assistive inspection, and moving the
selection highlight onto a friend do not open a thread and do not mutate any
entry.

Only explicit activation opens a conversation. Mouse click, short touch tap,
keyboard Accept, gamepad Accept, and assistive activation invoke the same
semantic command.

### 7.2 One activation reads the current stack

Activating a friend:

1. snapshots the exact highest delivered sequence for that friend;
2. opens the conversation;
3. marks every currently delivered entry through that sequence read in one
   idempotent transaction;
4. commits every entry-specific consequence of reading; and
5. projects the resulting transcript beginning at the oldest newly read entry.

Consequences are not delayed until a line scrolls onscreen. Therefore a solo
invitation lower in the opened stack is accepted immediately even if it lies
below the fold. Visibility and causal reading remain distinct from the separate
`witnessed` presentation receipt used by dialogue, echoes, and evidence.

The command identity includes the friend and admitted delivery boundary. A
per-friend/per-day command ID is forbidden because a later same-day arrival
must remain openable through a new idempotent command.

### 7.3 Entries delivered after opening

An entry delivered while its friend thread is visible remains withheld from the
rendered transcript and unread until a new accepted open/reopen boundary occurs.
Its rail unread mark appears, and an eligible notification appears under the
closed table in section 11.1, but its slip, choices, accessibility node, TTS,
live announcement, and witnessed receipt do not. The audience therefore cannot
reply to an unread source.

Reactivating the already selected friend row, following that friend's
notification Go, or hiding and reopening Contacts through the launcher invokes
the new open boundary. Merely scrolling, changing text size or locale,
refocusing the window, or restoring focus does not.

If Contacts is hidden and later reopened from the launcher on the same day, the
cached thread is restored. Any entries delivered to that already-open friend
while hidden are bulk-read by the reopen activation. Entries for the other two
friends remain unread.

### 7.4 Witnessed presentation

Bulk read alone never creates a witnessed receipt for an offscreen entry.

A registered Contacts line or presentation atom becomes witnessed exactly once
when either:

- its leading content edge enters the visible transcript viewport after layout
  and the renderer has accepted the complete semantic entry into the scroll
  stream; or
- semantic assistive traversal or TTS explicitly reaches and presents that
  entry.

Dwell time is never required. Instant text, reduced motion, and accessibility
presentation remain valid. An entry longer than the viewport is witnessed when
its beginning becomes visible and its full text is available through ordinary
scrolling; clipping or truncation is forbidden.

This receipt can satisfy only a separately registered witnessed-line, echo, or
presentation-atom contract. It never infers Observer evidence, acceptance,
reply, relationship state, or an outcome from generic Contacts inspection.

## 8. Transcript ordering and inspection

### 8.1 Canonical entry order

The accepted August daily stack remains:

1. previous-day causal follow-up;
2. today's fixed ordinary message, when present; and
3. newly unlocked invitation.

Every entry also owns a stable semantic ID and monotonic canonical presentation
sequence. The UI sorts by that sequence, never by localized text, sender,
timestamp string, dictionary order, node order, or current device time.

### 8.2 Oldest-new anchor

After a successful bulk read, the transcript top-aligns the oldest newly read
entry with a small breathing margin. It never jumps directly to the newest
entry or invitation merely because that entry created a consequence.

A temporary `NEW` divider appears immediately before that oldest-new entry.
It is session presentation only, disappears after leaving/reopening, and is
never saved or treated as narrative evidence.

Quiet continuation notches at the top or bottom indicate offscreen transcript
content. They convey overflow only: no unread count, entry type, pulse, or
instruction. They never cover correspondence.

When nothing is newly read, reopen priority is:

1. valid same-day cached position and meaningful focus;
2. earliest unresolved inline action on a cache miss; or
3. the latest entry only when neither exists.

### 8.3 Scrolling and focus

The transcript is one focusable scrolling region rather than one Tab stop per
message. Wheel, trackpad, touch drag, keyboard, and gamepad scroll it without
changing read state.

Initial focus after bulk read stays on the transcript/oldest-new anchor, not on
Choice A or an invitation action. Tab/Right enters the earliest unresolved
inline response. Back/Left returns to the selected contact row. Focus never
wraps into a different friend without an explicit rail navigation command.

## 9. Ordinary messages and inline replies

There remain exactly six ordinary replyable messages under the accepted August
calendar. Opening the containing thread marks an ordinary entry read but never
chooses an answer.

Every unresolved ordinary entry renders three compact authored response rows
directly beneath its source slip. There is no persistent composer, text box,
keyboard, free typing, Send button, attachment button, or fake editable field.

Accepting A, B, or C atomically:

1. records the stable semantic reply and witnessed line IDs;
2. removes the three response controls;
3. inserts Angela's selected response as an ordinary outgoing slip;
4. inserts the scripted immediate incoming response; and
5. creates the accepted pending echo obligation.

Each command is stat-neutral and idempotent. The visible saved text snapshot is
length-bounded, markup-escaped, and never executable.

Response rows wrap within the transcript and remain at least 48 by 48 logical
pixels. Focus is restored to the newly committed Angela response or the
transcript anchor, never to a removed choice control.

## 10. Solo and linked invitations

### 10.1 Solo invitation

Opening a thread whose current stack includes a solo invitation is the
acceptance action. It commits Angela's scripted acceptance and Schedule
addability immediately. It does not schedule the date.

There is no solo reply/decline menu, confirmation dialog, invitation-type badge,
or acceptance toast. The transcript projects the scripted acceptance as an
ordinary outgoing correspondence slip, but it cannot imply audience-authored
free text.

### 10.2 Priscilla-Lavinia linked presentation

The Day-2/Day-6 group protocol never creates a fourth contact. Successful
activation gives Priscilla and Lavinia the same ordinary binary unread mark and
publishes no notification toast.

Opening either participant first:

- bulk-reads that participant's current stack;
- fixes the one shared inviter wording and paired portrait order;
- displays the linked exchange within that participant's thread; and
- leaves the other participant's presentation unread until explicitly opened.

The linked exchange uses the ordinary correspondence-slip grammar. Every linked
Priscilla-Lavinia incoming slip carries its small literal sender name so the two
participants cannot be confused; ordinary one-to-one messages carry no such
decorative speaker label.

The group action is the sole invitation exception with a reply action. Replying
through either thread accepts one shared invitation exactly once and updates
both thread projections. Opening the other thread later only reads and presents
its existing linked entry and exposes that participant's still-uncommitted reply
action. Committing that second participant reply adds only its registered
authored judgment/response variation; it cannot create a second invitation,
acceptance, schedule entry, or consequence.

The first-open inviter and every shared receipt survive save/load. Reopening or
rapidly activating both sides cannot race into different inviter identities.

## 11. Notification grammar and Schedule routing

### 11.1 Ordinary notification surface

The closed notification-eligibility table is:

| Delivery | Toast |
|---|---|
| One of the six ordinary messages | Yes |
| A Days-1–6 or eligible Day-7 solo invitation, after its owning no-faint publication boundary | Yes |
| A next-day causal follow-up or institutional Contacts notice first delivered into a safe desktop state | Yes |
| A scripted immediate response inside an already open exchange | No |
| Angela's outgoing or scripted acceptance slip | No |
| Priscilla-Lavinia group activation or linked-thread update | No |
| Day-2 pre-echo pair | No |
| Hospital-scene, ending, History-only, echo-only, technical, or recovery record | No |

Here, a `safe desktop state` means the desktop host owns input after the owning
delivery transaction and its no-faint/condition evaluation have both committed,
with no Hospital, ending, technical-recovery, or other blocking route pending.
An eligible entry created earlier is queued until that boundary; entering the
boundary does not change its canonical delivery sequence.

If one atomic delivery batch contains several eligible entries, the outbox
publishes them in ascending canonical sequence. Each newer publication replaces
the visible prior toast, so the highest-sequence entry remains visible while all
underlying unread entries remain intact. Only the final visible toast produces
the polite assistive announcement; intermediate replacements in that same
bounded publication batch do not produce a burst of announcements.

Each eligible presentation is one lower-right in-game toast containing only:

- `New message`;
- the friend's first name;
- `Go`; and
- a visually quiet `X` close action.

There is no message preview, timestamp, entry type, invitation hint, unread
count, sender portrait, sound requirement, or route consequence explanation.

The toast binds the exact `run_id`, logical day, friend, entry ID, and delivery
sequence that caused it. Before Go, the coordinator revalidates that binding and
that the entry still exists and remains unread. If Load, New Run, day transition,
expiry, supersession, or another accepted open command removes or reads the
target, the toast closes quietly without navigation or canonical mutation.

The toast never steals focus. It remains for twenty seconds of eligible
foreground time unless dismissed or replaced.

- `Go` opens that friend's conversation and invokes the normal bulk-read
  boundary, including any solo acceptance in the current stack.
- `X` or timeout dismisses only the toast and reads nothing.
- A newer notification replaces the previous toast visually; the older entry
  remains canonically unread.
- Failed navigation consumes no read command and leaves the canonical entry
  unchanged.
- Priscilla-Lavinia group activation never publishes this toast.

Arrival sends one polite assistive announcement containing only `New message`
and the friend's name. The toast enters ordinary keyboard/gamepad traversal only
when the audience deliberately Tabs/Shift-Tabs or uses controller shoulders into
its focus group; arrival itself never moves focus. While Go or X is focused, the
timeout pauses. Back performs X. X returns focus to the previously meaningful
control. Successful Go transfers focus to the target Contacts transcript under
the normal oldest-new law. Replacement or removal can never strand focus or
implicitly activate a control.

If a new toast replaces one whose Go or X currently owns focus, focus moves to
the same semantic control on the replacement, its full twenty-second interval
starts paused, and one concise live announcement identifies the new friend. If
the replacement has no valid control projection, focus returns to the saved
meaningful pre-toast control. Toast geometry reserves a nonoverlapping corner
region and never covers an active modal, focused control, Contacts transcript,
caption stack, or essential status; an incompatible host state queues the toast
until that safe presentation region exists. A toast entering or leaving the
viewport never contributes to Contacts `witnessed` receipts.

### 11.2 Schedule-warning route is deliberately different

The accepted Schedule unread-message warning routes only to the bare Contacts
list. It:

- opens no conversation;
- selects no friend;
- focuses no friend row;
- reads no entry;
- accepts no invitation; and
- restores no cached thread.

Its successful route consumes only the Schedule warning receipt already owned
by the Schedule amendment and overwrites Contacts' transient same-day view cache
with the list-only state. It does not change canonical correspondence. A later
ordinary launcher reopen therefore returns to the list rather than resurrecting
the pre-warning thread.

## 12. Time and order

### 12.1 Authored ordinary time

Routine correspondence uses authored, stable 24-hour timestamps and localized
story-day separators. A timestamp is a presentation fact attached to a semantic
entry, not a causal scheduler.

Each routine slip renders its own time marker beneath the slip. A registered
`minute_group_id` instead renders one shared marker before or between its
contiguous members when all members own the same authored minute. Grouping never
changes semantic order or creates a causal relation. Day 2 requires this shared
form; assistive traversal announces the minute once at the group boundary.

Time never controls:

- entry ordering;
- unread/read state;
- invitation acceptance or expiry;
- Schedule availability;
- day transition;
- route, relationship, echo, ending, or Gallery logic; or
- deterministic command identity.

Save/load, timezone changes, daylight-saving changes, manual system-clock edits,
sleep/resume, and locale changes cannot rewrite an authored message time.

### 12.2 Rare audience-clock bleed

At run creation, one shared clock-anomaly arbiter applies an exact 1-in-16
occurrence gate. Failure freezes `none`. On success, it uniformly selects one
identity from the sorted, versioned finite manifest containing eligible quiet
audience-clock-strip windows and eligible noncritical ordinary-message
identities. It stores one allocation record:

`none | desktop_clock_strip(window_id) | contacts(message_id)`

The allocation, manifest version, and seed receipt are saved as one run-scoped
presentation record. Materialization adds one monotonic presentation receipt;
a Contacts allocation also adds its frozen displayed value. They never reroll
on reload and never choose a replacement when the allocated target is not
experienced.

When that exact message is created, its displayed `HH:MM` is sampled once from
the audience device's current local civil time and frozen permanently as that
entry's presentation token. No other field reads it.

The materialized receipt and frozen Contacts time live in a same-`run_id`
monotonic presentation ledger. Loading an older save from that run reattaches an
already materialized value instead of sampling the device clock again. A
genuinely new run owns a new allocation and no inherited value.

The target must not be:

- a solo or group invitation;
- a Hospital, ending, technical, save, purchase, or Schedule record;
- required evidence;
- the Day-2 pre-echo pair; or
- any entry whose time could imply an actionable deadline.

This is the same zero-or-one-per-run clock-anomaly allowance as the audience
clock strip; the common allocation makes overlap impossible. No character,
sound, tooltip,
History label, Gallery entry, or later line confirms the bleed. Assistive output
announces only the same displayed time, never its source.

Presentation RNG for this decision is isolated from message generation,
Minesweeper, relationships, endings, and every other mechanical stream.

## 13. Midnight erasure

### 13.1 Unanswered ordinary correspondence

At logical-day resolution, every unanswered ordinary entry disappears as if it
never existed, whether it was unread or opened and seen.

Erasure removes from player-facing Contacts and History:

- the source entry;
- its unresolved A/B/C controls;
- any temporary `NEW` divider or notification trace; and
- every visual gap, deletion marker, empty timestamp, unanswered status, late
  reply affordance, and echo.

One invisible deterministic tombstone/receipt remains for generation,
idempotency, and technical visited-line behavior. It cannot reconstruct text or
be read by Contacts, route logic, Gallery, Observer evidence, or accessibility.

A replied ordinary exchange remains as ordinary correspondence and owns its
pending echo under August law.

### 13.2 Rare unread solo-invitation erasure

At run creation, a separate deterministic 1-in-16 occurrence gate first freezes
`none` or `selected`. On selection, it uniformly chooses one identity from the
sorted, versioned closed Days-1–6 solo-invitation-window set. The gate receipt,
set version, and target identity are stored and never rerolled or replaced.

If the selected invitation reaches midnight both unread and unsuperseded:

- the offer disappears absolutely from player-facing Contacts and History;
- its normal next-day `nevermind` is suppressed;
- no missed, echo, relationship, Schedule, route, or Gallery effect is created;
  and
- one invisible deterministic tombstone remains.

If the target is opened, accepted, or superseded by successful
Priscilla-Lavinia group activation, the rare erasure does not occur and no
replacement target is selected.

This exception never applies to:

- a Priscilla-Lavinia group action;
- an opened or answered group action;
- a Day-7 invitation;
- a Hospital-specific closure; or
- an institutional/follow-up entry.

All nonselected solo offers retain the accepted August expiry and follow-up
law. Priscilla-Lavinia-superseded solo offers continue to vanish under the
existing group protocol without producing solo follow-ups.

## 14. Cache, save, load, and recovery

### 14.1 Same-day view cache

Ordinary Home/app switching hides Contacts without freeing it. For the current
logical day, the view cache retains:

- open friend, if any;
- transcript scroll anchor/offset;
- meaningful focus target;
- temporary selected reply control, when still valid; and
- layout direction and text-size presentation derived from live profile
  settings.

The cache owns no unread, acceptance, reply, expiry, or invitation fact.

Day change, selected Load, and New Run reset Contacts presentation to the bare
list. An explicit run save preserves every canonical Contacts fact required for
exact continuation and never persists the presentation cache.

### 14.2 Canonical persistence

Run state persists only primitive, validated semantic data required for exact
continuation, including:

- entry IDs, type, friend/participant ownership, canonical sequence, story day,
  and authored time token;
- per-participant read/presentation watermarks;
- reply, invitation, group, closure, and invisible tombstone state;
- stable command, transaction, and receipt identities;
- fixed Priscilla-Lavinia inviter/presentation order;
- seeded rare invitation-erasure gate, set version, and identity;
- the shared clock-anomaly allocation, manifest version, seed receipt, and its
  same-run monotonic materialization receipt; a Contacts allocation also stores
  its one frozen displayed `HH:MM`; and
- in-flight semantic presentation stages for the Day-2 pair.

It does not persist Controls, Nodes, RichTextLabel state, BBCode, pixel offsets,
hover, pressed state, scrollbar objects, focus rings, toast lifetime, temporary
`NEW` dividers, or animation progress.

The selected save owns ordinary correspondence and story state. The run snapshot
references the shared clock allocation, while the same-run monotonic
presentation ledger owns only its materialization receipt and frozen Contacts
time. That narrow overlay cannot read, accept, erase, reorder, or otherwise
merge unrelated Contacts state from an abandoned future branch.

### 14.3 Atomicity and recovery

Bulk read, reply, invitation acceptance, group first-open, group reply, expiry,
and story anomaly presentation each commit through bounded idempotent commands.

A technical failure leaves the last stable state unchanged or resumes the one
pending transaction forward. It never partially reads a stack, accepts a solo
without its receipt, duplicates a response, changes the group inviter, reorders
Day 2, resurrects erased text, or fabricates a fictional glitch.

## 15. Day-2 semantic pre-echo

### 15.1 New fixed fact

The former unsent-message contradiction is retired. During Returned Seat, the
application presents one ordinary authored minute group in this exact order:

1. Priscilla sends `I know`.
2. Angela sends `Lavinia is back`.

Both display the same authored `HH:MM` minute through one ordinary shared time
marker. They use the standard incoming/outgoing correspondence slips and no
special frame, draft state, label, glitch, animation, sound cue, narrator, or
explanation.

Canonical presentation order, not the minute-resolution timestamp, proves only
which record appears first. The game does not label Priscilla's line a reply to
Angela's later line, and it does not establish that the two messages are
causally connected. The audience may interpret the order as coincidence,
anticipation, application error, game error, or something else.

Hidden cohabitation may make Priscilla's knowledge credible; it does not settle
why these two statements occupy that order. No later dialogue confirms the
mechanism.

For the Core Story Bible's mystery-fairness rule, this supersedes only the claim
that the apartment fails to explain an `impossible timing` event. The retained
meaning is: the apartment can explain Priscilla's knowledge, but it does not
settle why `I know` precedes `Lavinia is back` within their shared displayed
minute. The surrounding three-source braid and plausible-mundane-explanation
law remain unchanged.

### 15.2 Presentation and persistence

The first presentation belongs to the Returned Seat beat. Angela and the
audience see the correspondence while Lavinia shares the surrounding return
scene. Lavinia's authored reaction is to Angela's observable pause or behavior,
not knowledge of Priscilla's private thread. She sees the message text only if a
later authored shot explicitly establishes that the screen is physically within
her view; this amendment establishes no such shot. The pair then remains
inspectable in Priscilla's Contacts history as the same immutable semantic
entries.

The sequence owns distinct line IDs, one authored minute token, canonical
sequence numbers, and resumable stages:

- before pair;
- Priscilla visible;
- Angela visible; and
- complete.

A save between stages resumes by appending only the missing line. It never
duplicates, swaps, or reannounces an already committed line. With reduced motion,
both publications use hard state changes while preserving order. Accessibility
tree order and live announcements match visual order exactly.

When the audience experiences Returned Seat, the pair is recorded as already
read and witnessed when it is projected into Priscilla's thread. It produces no
unread mark or notification and does not advance a bulk-read watermark across
any unrelated Priscilla entry. The pair owns its own presentation receipts. If
Returned Seat is not experienced, neither private line is projected into
Contacts; only the separately authored indirect residue for the unexperienced
path may appear.

The sequence is a fixed authored mystery anchor, not randomized Observer
evidence, a technical error, a clock-bleed target, or one of the six ordinary
A/B/C message slots.

## 16. Sylvia Special without an unsent draft

The separate Sylvia Special draft `I'm with Sylvia. Don't come.` and the
unknown-typist question are retired completely.

The full Special retains the reordered factual images:

- Sylvia's badge turned down;
- Angela withdrawing from unnecessary touch;
- the prefilled welfare incident slip;
- an interrupted objection; and
- the treatment-room ceiling.

The sequence ends on the ceiling and settles directly into Angela waking and
the next authored visible action or spoken line. It does not emphasize a phone,
open Contacts, show an empty composer, display a missing-message cue, insert a
replacement text, or invite the audience to search for deletion.

Contacts remains byte-identical across this beat: no draft, message, unread
state, timestamp, notification, watermark movement, or tombstone is created.
Player-facing History contains no removed line and no `[no message]` substitute.
Accessibility describes only visible wake facts and never announces that a
draft is absent.

The following remain unchanged:

- Sylvia intends that Angela lose consciousness and prepares to control the
  immediate aftermath;
- the means, immediate physical cause, and degree of Observer Pressure remain
  unproved and unauthored;
- the qualifying Day-7 trigger and precedence;
- the Special then forced-form Sylvia Dark playback order;
- `ending.sylvia.special`, Gallery identity, full-once/residue eligibility,
  replay isolation/routing, migrations, and save/ending planning; and
- every non-actionable medical and consent boundary.

Removing the draft reduces explicit proof of communication control. It does not
retire or weaken Sylvia Special's fixed intent or ending identity.

## 17. Visual grammar

### 17.1 Correspondence slips

Messages resemble squared correspondence slips inside a maintained old campus
system:

- incoming slips align left on off-paper rectangles with a one-pixel ink rule;
- Angela's outgoing slips are slightly narrower, align right, and use a darker
  diluted-ink plane plus a small structural edge notch;
- neither side uses speech tails, pills, rounded modern bubbles, gradients,
  glow, or soft drop shadows;
- the thread header owns the friend portrait/name, so ordinary slips do not
  repeat portraits or visible sender labels;
- linked Priscilla-Lavinia entries use small literal sender labels only where
  two incoming participants must remain distinguishable;
- routine time sits quietly beneath its slip, while only registered contiguous
  minute groups use one shared marker in tabular digits; and
- inline choices appear as compact stamped response rows beneath their source.

Direction is conveyed through alignment, geometry, and accessible sender data,
not color alone.

### 17.2 Ink, old-school, and liminal treatment

Use exhausted paper-grey fields, soot/diluted-ink rules, hard raster edges,
restrained indexed color, and deliberate negative space. Static texture is
permitted only on broad noninteractive planes and must never cross text, focus,
portraits, unread marks, or controls.

The roughness must feel like an old university OS rendered through ink and
photocopy processes, not cheaply manufactured hardware or a broken game.

Forbidden treatments include:

- modern blue/green messenger colors;
- rounded bubble clouds, avatars repeated beside every line, reactions, or
  online dots;
- terminal-log sterility that removes interpersonal direction;
- ornamental calligraphy, talismans, seals, or generic East-Asian mysticism;
- flicker, scanlines, RGB split, fake compression, layout jitter, missing
  glyphs, corrupted timestamps, or changing hitboxes; and
- horror-red alerts, glitch wipes, fake crashes, or decorative error codes.

## 18. Language, text size, TTS, and accessibility

### 18.1 Language projection

Every entry is addressed by stable semantic ID, never file line number or
localized string matching.

In single-language mode, correspondence follows the accepted story language
rules. In dual-language mode, the primary display language appears first and
the secondary appears beneath it inside the same semantic slip using a quieter
but contrast-compliant tone. The secondary line is not a second message and
does not change chronology, read state, or command identity.

Per-entry localization fallback never drops, merges, or reorders another entry.
Saved safe snapshots are plain text. Missing source text, unstable identity, or
branch mismatch remains a release-blocking content fault even if a development
build can degrade deterministically.

### 18.2 Initial release text sizes

Contacts supports exactly 100%, 125%, and 150% text presets for the initial
Windows release. The fixed 31/69 topology remains recognizable at all three.
Long translations, dual-language slips, choices, and linked entries wrap and
scroll vertically without clipping, truncation, overlap, or text shrinkage.

Interactive targets remain at least 48 by 48 logical pixels independent of text
size. The separately deferred 200% milestone cannot be advertised as present.

These three values are in-game text presets, not Windows display scaling and not
the Windows `Make text bigger` preference. Initial verification crosses each
preset with every supported Windows display-scaling baseline, supported locale,
single/dual-language mode, and window mode/resolution in the release matrix.
The game claims Windows text-preference integration only after it is physically
implemented and tested. No WCAG/XAG conformance or 200% large-text claim follows
from this narrower release contract.

### 18.3 Assistive semantics

Assistive output exposes the same audience-visible facts and no hidden metadata:

- friend name and binary unread state;
- sender identity when disclosed;
- displayed authored time;
- message text in visual order;
- available inline choices; and
- the same visible control role, name, state, and action label.

It never exposes stacked unread count, invitation category, hidden erasure
target, clock-bleed provenance, P-L internal action identity, relationship
state, route result, or Observer metadata.

TTS reads the main display language only. A disclosed speaker is announced when
the speaker changes, not redundantly before every slip. Prior retained messages
do not reannounce merely because the transcript scrolls. An intentionally
ambiguous authored speaker, if one later exists, cannot be revealed through an
internal actor ID or distinct synthetic voice.

No essential fact relies on sound, animation, hover, color, or pointer-only
interaction. Contacts contains no non-speech caption stream.

## 19. History, evidence, and epistemic boundary

Contacts thread history, global narrative History, profile visited-line state,
and Observer evidence are separate owners.

- Replied correspondence, accepted invitations, fixed follow-ups, linked group
  records, and the Day-2 pair remain in the appropriate friend transcript.
- Erased ordinary/invitation entries leave no player-facing transcript or
  global-History reconstruction.
- A technical visited-line receipt may survive only for skip/idempotency and
  cannot expose removed prose.
- Merely opening, reading, saving, loading, or inspecting Contacts never grants
  Observer evidence.
- A finite manifest may designate a witnessed line for another accepted grammar,
  but the UI cannot infer evidence from message type, timestamp, anomaly, or
  repetition.

Characters know only diegetic correspondence and their own experience. They do
not perceive the audience clock, hidden erasure seed, notification replacement,
save state, or internal command order.

## 20. Technical trust and error behavior

Presentation anomaly and story mystery never impersonate a technical failure.

Known ordinary refusal or ineligible action uses restrained, truthful state and
does not generate horror copy. A real user-impacting failure uses the game's
trusted technical recovery surface with accurate Retry/Return behavior and
whether progress is safe or pending.

Technical failure must never:

- create, delete, reorder, read, accept, or reply to correspondence;
- be attributed to a character;
- consume the rare anomaly allowance;
- play a fictional glitch or horror sting;
- reveal hidden state in diagnostics shown to the audience; or
- turn a save/load fault into story evidence.

Internal diagnostics may use semantic IDs, transaction stages, and error codes
outside the fiction. Released UI displays only the safe factual recovery copy.

## 21. Component and interface ownership

A recommended future Godot composition contains:

- a Contacts app orchestrator with no message-domain mutation logic;
- a fixed contact-rail projection;
- a transcript projection over detached semantic entries;
- a correspondence-slip component;
- an inline-response component;
- a linked-group projection adapter;
- a transient notification presenter;
- a same-day view-cache owner; and
- a trusted technical-recovery handoff.

The domain port exposes explicit semantic commands such as:

- open friend through expected delivery watermark;
- reply to exact entry/reply ID;
- open linked participant through exact group generation;
- reply to exact shared group action;
- resolve day expiry; and
- restore validated Contacts state.

UI components emit intent upward. They do not mutate GameState sideways, infer
read state from visibility, derive canonical order from node layout, parse
message text as markup, or create command IDs from friend/day alone.

Godot implementation must use Container-driven layout, one transcript
ScrollContainer, root Theme inheritance, explicit nonlinear focus neighbors,
and semantic accessibility descriptions. Per-message `_process`, presentation-
derived state, duplicate hidden transcript trees, and arbitrary rich-text
execution are forbidden.

## 22. Rejected alternatives

The following approaches are intentionally rejected:

- selecting/focusing a friend reads the thread;
- opening a thread reads only one arbitrary item or only the newest item;
- opening a contact silently marks a later delivery read without a new command;
- a generic Dating button or generic invitation inbox replaces specific friend
  correspondence;
- solo invitations require a separate reply/decline action;
- a fourth Priscilla-Lavinia group contact exists;
- one toast per queued message stacks, scrolls, or reveals message type;
- device time stamps every message or controls message order;
- expiring entries leave `deleted`, gaps, timestamps, tombstones, or late-reply
  affordances visible;
- the rare invitation erasure applies to P-L group or Day 7;
- Day 2 uses an unsent draft, fake composer, anomaly frame, or claimed causal
  reply;
- Sylvia Special replaces its removed draft with a missing-message clue, phone
  inspection, or another text; and
- a modern messenger, terminal log, or decorative glitch system substitutes for
  the correspondence-slip grammar.

## 23. Exact supersession and retained law

### 23.1 Controlling decisions

Within scope, this amendment supersedes or retires:

- the Day-2 unsent `Lavinia is back` contradiction and every claim that
  Priscilla replied before Send;
- the phrase `unsent-message anomaly` for Returned Seat;
- the Sylvia Special draft `I'm with Sylvia. Don't come.` and its unknown-typist
  question;
- the August ordinary-message rule only where it limits no-trace expiry to
  messages never opened; the new boundary is unanswered at midnight;
- the August solo unread-expiry table only for the one seeded rare no-trace
  target;
- Phase-2R packet/closed-issue language that treats Contacts history as always
  append-only or says reads never accept solo invitations;
- current friend/day-only open-command identity and bulk watermark behavior;
- current separate solo reply-as-acceptance behavior;
- recovered notification routes that open a predetermined conversation or show
  Go/Yes beyond the fixed toast grammar;
- recovered GiftPicker/contact assumptions; and
- current scaffold geometry, visible speaker labels, BBCode treatment, and
  empty content hosts where they conflict with this document.

Direct narrative references superseded are:

- `story/01-core-story-bible.md` Day-2 anchor, Returned Seat label, and only the
  `impossible timing` phrase in its mystery-fairness paragraph, plus only the
  Sylvia Special unsent-draft sentence and unknown-typist clause;
- `story/03-seven-day-production-map.md` only assertions that Angela does not
  send or retains an unsent draft, Priscilla replies before Send, or the Day-2
  order proves impossible timing/private-message access, plus only the
  unsent-draft and unknown-typist parts of its Sylvia Special ending summary;
- `story/05-canon-amendments-2026-07-19.md` historical Day-2 unsent label, plus
  only the Sylvia Special unsent-draft and unknown-typist wording.

Every surrounding Sylvia fixed-intent, unresolved-means/cause, and
reordered-image clause remains intact. Trigger, precedence, identity, and ending
order continue to follow the accepted 2026-08-07 design and later scoped
amendments; this document does not alter them.

Returned Seat's return fact, setting, relationship pressure, state/tone actions,
Lavinia reaction, concealed-knowledge/cohabitation law, and every nonconflicting
residue/facet remain intact.

The historical files must be preserved and linked from this later amendment,
not edited as though the former decisions never existed.

### 23.2 Retained law

This amendment does not change:

- exactly six ordinary A/B/C messages and their calendar positions;
- exactly twelve Days-1–6 solo invitation windows and their round gates;
- ordinary reply stat neutrality and one pending echo after reply;
- solo open/read as acceptance and Schedule addability;
- the original P-L activation requirements, one shared action, first-open
  inviter, reply exception, expiry branches, counted-window law, or pair autonomy;
- Schedule warning eligibility/order or list-only route semantics;
- Hospital closure, relationship, challenge, ending, Gallery, replay, or
  Observer rules;
- the Day-7 Sylvia Special trigger, precedence, Special-to-Dark order, identity,
  or fixed harmful intent;
- the no-narrator, no-thought-box, no-hidden-stat, and technical-trust laws; or
- the requirement that causality underneath surreal presentation remain exact.

## 24. Reconciliation path before implementation

After this exact written artifact's approval, authority reconciliation must:

1. preserve the currently executing `dwm-0hi` scope and decide through a
   separately reviewed successor whether this amendment follows or supersedes
   any of its outputs; never widen it silently;
2. register and validate `design_amendment` plus `docs/design` before claiming
   machine discoverability;
3. update the design authority index/README and translate this law into exact
   Contacts, invitation, notification, time, persistence, accessibility, and
   story decision/requirement packets;
4. regenerate the prompt-doc index and verify requirement/Beads metadata parity;
5. preserve closed `dwm-p2r.6` as historical evidence and create/reconcile a
   successor task for the changed lifecycle rather than falsely claiming its
   old acceptance still matches target law;
6. reconcile `dwm-oyo.2` for semantic lines/timeline consolidation,
   `dwm-oyo.3` for production Contacts and notification composition, the
   relationship-scene owner for Returned Seat, the ending owner for Sylvia
   Special, and `dwm-oyo.7` for release evidence;
7. amend every affected hash-bound August plan only through a separately
   reviewed plan amendment with new recorded hashes;
8. update schemas, ports, manifests, migrations, fixtures, and verification from
   reconciled requirements; and
9. obtain explicit runtime implementation authorization.

No existing Beads issue is modified, reopened, closed, or claimed by this
accepted document.

## 25. Verification matrix

### 25.1 Contact opening and ordinary replies

- Hover/focus/inspection never reads; every activation path invokes one exact
  open command.
- Bulk open reads precisely the admitted stack and no later delivery.
- A later same-day delivery remains openable through a distinct idempotent
  command.
- A late delivery to the visible thread stays absent from transcript, choices,
  TTS, and accessibility until reactivation; it cannot be replied to while
  unread.
- Row reactivation, notification Go, and launcher reopen create the boundary;
  scroll, refocus, text-size, and locale changes do not.
- Oldest-new anchoring, temporary divider, continuation marks, and focus order
  match the approved projection.
- Only viewport entry or explicit semantic assistive/TTS presentation commits a
  witnessed receipt; bulk-read/offscreen layout alone does not.
- A/B/C each commit one response and one scripted reply/echo obligation; rapid
  duplicate input never creates two.
- Unanswered opened and unread ordinary entries both erase without trace at
  midnight; replied exchanges remain.

### 25.2 Invitations and P-L

- Every solo opening accepts once without a reply/decline menu.
- Offscreen-in-stack acceptance commits while witnessed presentation remains
  separate.
- P-L activation creates no fourth contact or toast and marks both rows only
  with ordinary unread.
- First participant open freezes inviter/order once; the other participant
  remains presentation-unread until opened.
- Reply through either side creates one shared acceptance and updates both;
  concurrent/replayed commands never duplicate it.
- Opening the second participant without replying creates no replied identity,
  judgment variation, acceptance, or Schedule mutation.
- A committed second-participant reply adds only its registered authored
  judgment/response variation and cannot accept or schedule again.
- Normal solo/P-L expiry tables remain intact except the exact rare target.

### 25.3 Notification and routing

- Toast content is exactly title, friend, Go, and X with no preview/type/count.
- Every delivery class matches the closed eligibility table; a multi-delivery
  batch publishes in canonical order and leaves only its highest sequence
  visible without reading the replaced entries or announcing intermediate
  replacements.
- Twenty-second monotonic foreground timing, pause, timeout, close, replacement,
  and focus neutrality pass.
- Arrival gives one polite non-preview announcement and never moves focus;
  deliberate Tab/shoulder traversal reaches Go/X, focus pauses timeout, Back
  closes, and every removal restores focus safely.
- Replacement while a toast control owns focus transfers to the same semantic
  replacement control and restarts its paused interval; invalid projection
  returns to the pre-toast control.
- Toasts never occlude essential/focused content or create witnessed receipts;
  an incompatible host state queues presentation until a safe region exists.
- Replacement removes only the old toast; its canonical entry stays unread.
- Reading, expiring, superseding, or replacing the bound run/day removes a stale
  toast; its former Go can never open or read a different stack.
- Go uses ordinary friend-open/bulk-read; X/timeout do not mutate.
- Schedule warning enters the bare list and cannot restore cache or read.
- The warning's successful list-only route replaces the transient thread cache,
  so a later launcher reopen remains list-only without mutating correspondence.

### 25.4 Time and anomalies

- Authored timestamp and canonical sequence remain stable across save/load,
  locale, timezone, manual clock change, sleep/resume, and low frame rate.
- Sorting never reads time strings.
- The shared clock family uses exactly one 1-in-16 gate and one persisted
  `none | desktop_clock_strip | contacts` allocation; success selects uniformly
  from the sorted versioned manifest.
- Contacts clock bleed samples once, freezes, and never affects mechanics or
  assistive metadata.
- Loading an older same-run save reattaches an already materialized clock value
  from the monotonic presentation ledger and never samples the device twice.
- Ineligible, unexperienced, reload, branch, and New Run cases do not reroll or
  leak the selected identity.

### 25.5 Erasure

- Unanswered ordinary erasure leaves no visible/assistive trace, gap, follow-up,
  echo, or reconstructible text.
- The seeded solo target erases only if unread and unsuperseded at midnight and
  suppresses exactly its nevermind.
- Its independent 1-in-16 gate, sorted-set uniform selection, version, receipt,
  target-or-none result, and no-replacement behavior are deterministic.
- Read, accepted, superseded, P-L, Day-7, Hospital, and nonselected invitation
  paths retain their own law.
- Reloading a snapshot captured after erasure cannot resurrect the entry. Loading
  an earlier pre-expiry snapshot truthfully restores its earlier entry state and
  the same frozen rare target; it never rerolls or selects a replacement.

### 25.6 Day 2 and Sylvia Special

- Returned Seat publishes `I know` then sent `Lavinia is back` under one authored
  minute marker and ordinary slip styling.
- Routine slips own individual time markers; only registered contiguous minute
  groups share one, and grouping never changes order or causality.
- Visual order, accessibility order, safe text snapshots, save stages, and
  Priscilla-history projection agree exactly.
- No label calls the first line a reply or claims causality.
- The experienced pair enters Priscilla history already read/witnessed without a
  toast, unread mark, or unrelated bulk watermark; the unexperienced path
  exposes neither private line.
- Lavinia's reaction is grounded only in Angela's visible pause and never grants
  her private-message knowledge; this amendment establishes no screen-sharing
  shot.
- Save at every stage resumes only the missing stage without duplicate live
  announcement.
- Sylvia Special creates no draft/message/contact mutation and ends through the
  ceiling-to-wake sequence.
- Special trigger, semantic identity, Special-to-Dark order, discovery receipt,
  Gallery availability, and replay routing remain unchanged at the domain
  boundary; replayed authored content follows the revised draft-free scene.

### 25.7 Layout, input, language, and accessibility

- The 31/69 topology, fixed P-L-S rail, binary unread grammar, blank state, and
  transcript remain usable at 100%, 125%, and 150%.
- Schedule-warning list entry focuses the named `Contacts list` app-root stop;
  it reads nothing and forward navigation reaches Priscilla deterministically.
- Long supported translations and dual-language entries wrap without clipping,
  overlap, hidden controls, or horizontal text scrolling.
- Mouse, touch, keyboard, gamepad, and assistive activation have semantic parity.
- Every target is at least 48 by 48 logical pixels; focus/unread/selection do not
  rely on color or motion.
- Every in-game preset is tested against the supported Windows display-scale,
  locale, language-mode, and window-mode matrix without claiming Windows
  text-preference integration or 200% conformance.
- Screen readers expose no count, category, erasure seed, clock source, hidden
  relationship, or Observer fact.
- Plain-text escaping and hostile saved snapshots cannot execute BBCode, DTL,
  resource paths, or commands.

### 25.8 Recovery and technical trust

- Crash injection after every read/reply/group/expiry/story stage recovers
  exactly once.
- Technical failure never mutates correspondence or appears as fiction.
- Same-day cache, explicit save, Load, day transition, and New Run each restore
  only their approved presentation/canonical owners.
- No per-frame process, hidden duplicate transcript, or UI-derived business fact
  is required.

## 26. Acceptance and next manuals

The user approved this exact artifact on 2026-08-12. The accepted lifecycle is
recorded in frontmatter, while `implementation_authorized: false` remains in
force. Runtime work still requires authority reconciliation and separate
explicit implementation authorization.

Later UI/UX manual sections must cite this Contacts law rather than duplicate
or reinterpret it. The visual-art manual may finalize portraits, texture,
palette, and slip assets. The music/audio manual may add optional ordinary
interface ambience but cannot make any Contacts fact audio-only or announce an
anomaly. Backup, Settings, Gallery, and narrative-scene manuals remain separate
design passes.
