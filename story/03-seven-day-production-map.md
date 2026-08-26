# Seven-Day Production Map

> Status: derived, plot-neutral production template. Mechanics authority is the
> approved specification
> `docs/design/2026-08-07-seven-day-dialogic-flow-design.md`; this file defines
> no mechanics and owns no plot. Events, premises, locations, mystery anchors,
> and final prose live elsewhere. Named plot material removed from this file is
> preserved verbatim in the noncanonical
> `story/library/03-seven-day-plot-material-library.md`.

## How to Use This Template

- Author events as cards against the schemas below; a card becomes canonical
  only through a later explicit approval recorded outside this file.
- Character IDs appear in this file only inside the fixed calendar table that
  the approved mechanics require; card content stays character-neutral here.
- Every stable ID (semantic entry, reply, line, echo, presentation atom,
  visual) must resolve through the closed semantic manifest owned by the
  approved specification; this template never invents runtime behavior.
- Exact thresholds, counters, and hidden condition names are code-owned and
  are never restated as audience-facing text.

## Fixed Days 1-7 Structural Slot Table

The approved mechanics fix this calendar (specification sections 7.1, 7.2,
7.5, and 8.2). This table is the only place in this file where character IDs
may appear.

| Day | Ordinary message (3 stable choices) | Solo invitation round 1 | Round 2 | Additional round | Fixed challenge valves |
|---:|---|---|---|---|---|
| 1 | Lavinia | Priscilla | Sylvia | None | None |
| 2 | Sylvia | Priscilla | Lavinia | P-L group protocol at round 3 | None |
| 3 | Priscilla | Lavinia | Sylvia | None | None |
| 4 | Lavinia | Priscilla | Sylvia | None | Third valve: Priscilla, Sylvia |
| 5 | Priscilla | Lavinia | Sylvia | None | Third valve: Lavinia. Fourth valve: Sylvia |
| 6 | Sylvia | Priscilla | Lavinia | P-L group protocol at round 3 | Fourth valve: Priscilla, Lavinia |
| 7 | None | None | None | None | None; Day 7 follows the approved selection and ending law |

## Shared Card Fields

Every card of every schema declares:

- **Stable semantic IDs** — `entry_id`, per-choice reply IDs, `line_id`s for
  witnessed lines, `echo_id` to `presentation_atom_id` bindings, and visual IDs
  from the entry's closed visual manifest with declared neutral fallbacks.
- **Causal inputs** — the receipts and witnessed facts a card may assume;
  nothing unwitnessed may be referenced.
- **Variation layers** — causal spine, durable tier, tone, short
  current-attitude insert, short message-echo insert, and exact
  witnessed-detail insert, in that order; tier by tone permits at most six
  core authored versions.
- **Echo atoms** — each authored echo binds one `echo_id` to one stable
  `presentation_atom_id`; a dialogue atom also owns a `line_id`; action,
  visual, and deliberate-silence atoms do not invent one.
- **Allowed signals** — only signal kinds from the approved DTL-to-domain
  allowlist (specification section 12.8), each restricted to its valid source.
- **Visual IDs** — presentation-only background and portrait identifiers
  resolved through the closed visual manifest; no dynamic path composition.
- **Verification checklist** — the per-card checks in the checklist section.

## Ordinary-Message Card Schema

- Slot: the fixed per-day ordinary message owner from the calendar table.
- Exactly three stat-neutral semantic choices with stable reply IDs.
- Committed record: semantic reply ID, witnessed line ID, safe plain-text
  snapshot, scripted immediate response, and one pending echo obligation.
- Expiry: ignoring until midnight erases the message with only the invisible
  generation tombstone surviving; no follow-up gains a reply menu.
- Allowed signals: `message.reply.commit`, `history.line.witness`,
  `message.echo.satisfy`.

## Solo Invitation/Date Card Schema

- Slot: a fixed solo invitation window from the calendar table; opening is the
  acceptance action; scheduling commits only through Done.
- Owns its own challenge and consequence; the fixed third and fourth valve
  windows are calendar-owned and never move elsewhere.
- Closure paths: unread expiry to a next-day nevermind; read or accepted but
  unfulfilled to one missed-date question; Hospital supersession to the
  Hospital-specific record and follow-up, subject to the witness rule of
  specification section 7.4. Every offer closes exactly once.
- Allowed signals: `history.line.witness`, `message.echo.satisfy` within the
  entry; invitation acceptance, board resolution, promotion, and day
  resolution remain engine-owned commands, never DTL signals.

## P-L Encounter Card Schema

- Slot: the two counted windows on the calendar table's group-protocol days.
- Group action lifecycle: `AVAILABLE_UNOPENED` to `REPLY_REQUIRED` to
  `ACCEPTED`, as the sole scripted-reply exception; one schedule slot.
- Presentation states: Group, Missed, Private-visible, Private-offscreen; the
  window counts by the attendance law, not by visibility.
- Pair board: exactly three terminal results (Perfect, Solved, Exploded); no
  colored or special mine; legibility and mastery evidence only.
- Allowed signals: `history.line.witness`, `message.echo.satisfy`, and
  `pair.combination.witness` from the canonical visible post-board entry.

## Hospital/Follow-up Card Schema

- Trigger: the code-owned audience-caused condition contract; never a random
  cancellation inserted to redirect a route. Thresholds and condition names
  stay hidden from the audience.
- Records: one Hospital-specific missed record per read or accepted unfulfilled
  invitation; unread invitations still expire ordinarily.
- Witness rule: the idempotent witness receipt of specification section 7.4 is
  unapplied handoff truth; cards never apply its frozen consequences.
- Follow-ups: next-day scripted messages with no choices; no reply menus.
- Allowed signals: `history.line.witness`, `message.echo.satisfy`.

## Ending-Layer Card Schema

- Slot: one semantic step inside the resolver's frozen ordered ending plan of
  one through four steps.
- Fields: stable `step_id`, semantic ending ID, callable entry ID, role,
  frozen presentation context, playback mode, prerequisite receipt IDs, and
  transaction token.
- State: `pending` to `playing` to `completed`; only a physical completion
  carrying the matching token commits completion; Gallery discovery commits
  only for physically completed semantic identities.
- Allowed signals: `history.line.witness`, `message.echo.satisfy`, and, only
  where the entry is registered for them, `observer.evidence.commit` and
  `pair.combination.witness`.

## Verification Checklist

- [ ] The card names no mystery object, location, date premise, or
      character-specific beat inside this file.
- [ ] Every stable ID resolves through the closed semantic manifest and the
      entry's closed visual manifest.
- [ ] Variation stays within the approved six-layer order with no Cartesian
      multiplication.
- [ ] Every authored echo binds one `echo_id` to one `presentation_atom_id`.
- [ ] Signals stay inside the approved allowlist for the card's entry and
      execution mode.
- [ ] No stat, threshold, tier, attitude, or hidden condition is restated as
      audience-facing text.
- [ ] Follow-up and expiry paths close every offer exactly once.

## What Lives Elsewhere

- Events, premises, locations, mystery anchors, and final prose are authored
  later under the approved specification's narrative guardrails and approved
  outside this file.
- Retired named plot material is preserved verbatim in the noncanonical
  `story/library/03-seven-day-plot-material-library.md`.
- Mechanics, calendars, thresholds, and signal law belong to the approved
  specification and to code.
