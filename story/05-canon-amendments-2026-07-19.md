# Approved Canon Amendments — 2026-07-19

HISTORICAL AMENDMENT EVIDENCE — NOT CURRENT MECHANICAL AUTHORITY

The July `Status: **approved canon**` statement below is retained as historical
status and decision provenance. The August 7 design supersedes conflicting
mechanics; this document remains useful as evidence of the decisions that led
to them.

Status: **approved canon**, per the Core Story Bible's authority rule that later
explicit approvals supersede earlier proposals. These rulings resolve every known
conflict between the Core Story Bible (`01-core-story-bible.md`), the recovered
mechanical spec (`docs/design/recovered/`), the existing code, and the
2026-07-18 session addendum. Where a ruling amends the Bible, the amendment is
recorded here and the Bible text is left pristine; this file wins on the amended
points. Implementation details named here remain code-owned; this file records
approved intent.

**Mechanical supersession notice (2026-08-07).** Where a mechanical ruling in
this file conflicts with the approved bounded specification
`docs/design/2026-08-07-seven-day-dialogic-flow-design.md`, the specification
supersedes that ruling for the seven-day flow domain. The historical reasoning
below is preserved unchanged as amendment evidence.

---

## 1. True and Observer fuse — the "true (observation) end"
> **Current status: SUPERSEDED MECHANICS.**
>
> Current Observer, board, and gate law is in the August 7 design sections 10.4
> and 11.2–11.7.

The standalone true-path ending identities, the consecutive-perfect chain rule
(`previous_entered_true_path` and its exemption tables), and true-path audio as a
distinct ending tier are **retired**. Tone is binary: Sweet or Totally Dark, as the
Bible states.

The third slot per pairing is the **true (observation) end** — the Bible's Observer
postscript, now gated **conjunctively**:

- **true minesweeper** (board mastery, defined in §3), AND
- **observer behaviour** (the pairing's Observer language: Verification for
  Angela–Priscilla, Restraint for Angela–Lavinia, Persistence for
  Priscilla–Lavinia).

Neither half alone qualifies. Sylvia remains Special-only, no Observer end.

## 2. Scope of the fused gate
> **Current status: SUPERSEDED MECHANICS.**
>
> Current Observer, board, and gate law is in the August 7 design sections 10.4
> and 11.2–11.7.

The gate applies to **all pairings, including the Priscilla–Lavinia encounters**
(group, missed, and private versions). In Angela-absent pair scenes the audience
plays the challenge board; this is canonically **Observer Pressure made playable**
— the audience's hand is the pressure in the room. It may affect legibility and
collisions; it may never author the pair's desire, state, tone, or consent (§10).

## 3. Board half of the gate — definition
> **Current status: SUPERSEDED MECHANICS.**
>
> Current Observer, board, and gate law is in the August 7 design sections 10.4
> and 11.2–11.7.

Per pairing, per playthrough: **every attended dating challenge with that pairing
is a perfect (no-flag / foresight) clear, and none exploded.** One predicate per
pairing; any non-perfect challenge makes it false for the playthrough. No
cross-day chain bookkeeping. For Priscilla–Lavinia: perfect on both counted
encounters' boards.

## 4. Leveling — two tier-gated events per friend; fuel + valve
> **Current status: SUPERSEDED MECHANICS.**
>
> All three friends begin at Friend and use only the fixed third/fourth invitation
> valves in the August 7 design sections 8.2 and 7.2.

Each of Priscilla, Lavinia, Sylvia has **two** leveling incidents (the
Priscilla–Lavinia pair excluded; they use the deck):

- one that **appears only when** the relationship can advance friend → ambiguous;
- one that **appears only when** it can advance ambiguous → love.

Appearance is tier-gated; ineligible events are absent, never locked (Bible rule).
The Seven-Day Production Map currently designates one leveling card per friend
(Events 4, 8, 11); designating the second card per friend is reconciliation work.

**Fuel + valve:** hidden affection accumulates from every dating challenge
(the code's per-challenge deltas). A leveling event that appears **lands** (advances
one tier) only if the accumulated pool has crossed the code-owned threshold AND the
scene's Bible condition holds. The audience never sees a number.

## 5. Tone selection
> **Current status: SUPERSEDED MECHANICS.**
>
> The August 7 design sections 6.1 and 11.3 use stored dark `0–1` for Sweet and
> `2–4` for Totally Dark; Day 7 never asks for another board.

**The decisive board decides.** On the Day-7 date's challenge: deliberately
clicking the pairing's colored dark mine → **Totally Dark**; finishing any other
way → **Sweet**. Accumulated week dark points do not gate the ending; they feed
atmosphere only (pressure, self-talk drift, ambient wrongness).

## 6. Observer scoping and the desktop hub

Observer behaviour (Capture/Compare, false cursor, gate accrual) lives **only
inside dating scenes**. The desktop shell — Angela panel, apps (Minesweeper,
Contacts, Schedule, Shop, Settings, Backup, Log Out), money/motivation economy —
**survives as the game's hub** between dates. The Day-2 unsent-message and Day-6
check-in anchors are diegetic desktop events, not Observer mechanics.

## 7. Priscilla–Lavinia counted-window model
> **Current status: PARTIALLY SUPERSEDED MECHANICS.**
>
> The August 7 design section 7.5 is normative: opened-but-unanswered is a
> Private-visible presentation subvariant, not a sixth outcome.

REFINED 2026-07-21 (dwm-p2r.6 grilling). A counted window (Events 13, 14) turns on
one rule: **did Angela solo-date either woman that window?**

- **Angela solo-dated one of the pair** → **Prevented**: that friend's solo offer
  was read to schedule it, so the group offer never forms and the pair does not
  meet. **Counts nothing.**
- **Angela solo-dated neither** → the pair meets and the window **always counts**;
  only the flavor and visibility differ, driven by the group-offer state:
  1. **Group** — the group offer generated, Angela accepted and attends. Counts, visible.
  2. **Missed** — the group offer generated and was accepted, but Angela stood them
     up; the pair meets without her, guilt flavor (next-day guilt messages). Counts, visible.
  3. **Private (visible)** — the group offer generated and **both** participants'
     group messages were left **unread**; the pair meets, neutral flavor. Counts,
     visible scene.
  4. **Private (offscreen)** — the group offer **never generated** (e.g. fewer than
     three Minesweeper rounds, so no group message exists); the pair still meets on
     their own, but **the player sees no scene**. **Counts**, invisibly.

Visibility rule: the three group-offer-generated outcomes (Group, Missed, visible
Private) are **audience-visible scenes** and mark the drawn state/tone combination
**seen** (subject to §10's witnessing rule). Offscreen Private counts toward the
pair counter but shows no scene and marks nothing seen. The umbrella pickup never
counts and never marks seen.

Epilogue threshold is unchanged: `ending.priscilla_lavinia` requires the pair
counter to reach **2** — Angela solo-dated neither woman on **both** Day 2 and
Day 6, so the pair met (in some flavor) both windows.

## 8. Sylvia Special — trigger and content
> **Current status: SUPERSEDED MECHANICS.**
>
> Sylvia's current pre-Done trigger and ordered consequence follow the August 7
> design sections 11.5 and 11.8; Event 9 is audition history.

**Trigger (old mechanics, precise sequencing):** On Day 7, the Sylvia date is
**schedulable** (invitation unlocked, destination eligible at ambiguous/love) but
**Done has not been pressed**, and Angela — in neglect-danger (sequela chain) —
**faints via the real-time check after a Minesweeper app round or Shop purchase**.
Faints fire only from that desktop check; dates are never interrupted mid-scene.
Hospital receives her; the Special plays. She was one button from the date and
opened Minesweeper instead.

**Content (Bible imagery, unchanged):** reordered present-tense flashes — badge
turned down, withdrawal from unnecessary touch, the prefilled slip, an interrupted
objection, the treatment-room ceiling — waking beside the unsent draft
`I'm with Sylvia. Don't come.` FIXED FACT and UNRESOLVED CAUSE stand exactly as
the Bible states; means remain non-actionable.

Mid-week neglect-faints route to hospital as Event 9's hospital-arrival variant
(retroactively, rehearsal). A Day-7 faint without Sylvia eligibility resolves to
an **Alone hospital variant**, never Special.

## 9. Dark-mode Angela — approved amendment
> **Current status: SUPERSEDED MECHANICS.**
>
> Dark-mode scope and faint precedence follow the August 7 design section 11.8.

Canon. Unlock: witnessing **all three Totally Dark endings plus the Special**
(global-profile marker; survives new games). A **dark mode toggle** appears on the
main menu, default off. When on: Angela refuses romance — any scheduled dating
action blocks the Done press with her left-panel refusal line; her Day 1–7
self-talk carries the hurt, romance-negative voice; runs resolve toward Alone.
No new timeline keys; the voice lives entirely in the left-panel self-talk
overlay. This is the global profile remembering harm, not the audience authoring
her personality.

## 10. Priscilla–Lavinia boards — pure observation

P×L challenge boards are mechanically distinct from Angela's:

- **No colored dark mines, no finish/done button.** Outcomes are exactly:
  perfect | solved | exploded. Nothing on their board chooses; tone and state are
  deck-drawn and untouchable. (Observer Pressure cannot define desire — enforced
  in the tile set itself.)
- **Perfect** on both counted encounters = the board half of the P×L true
  (observation) end (§3).
- **Solved** — the scene runs its full insert and the drawn combination is
  **marked seen**.
- **Exploded** — the scene truncates; the window on their privacy closes early;
  the combination is **not marked seen** (unseen-first offers it again).
- Board-fed inter-friend deltas remain **flavor only**, read by their dialogue for
  warmth/friction within the drawn combination; never state, tone, or endings.

The audience's play decides how much is shown — never what they feel.

## 11. Four-state deck — endorsed as written

The per-playthrough draw (ambiguous/love × sweet/dark), unseen-first, stable, no
reload reroll, stands exactly as the Bible wrote it. The draw is stored in the
canonical save; **seen** combinations are global-profile markers. The draw is
invisible — no UI trace until witnessed. The Day-2 umbrella cutaway must be
written state/tone-neutral.

## 12. Phase 2R protection
> **Current status: SUPERSEDED MECHANICS.**
>
> This Phase 2R wording is a historical tracking snapshot, not current authority;
> the August 7 design governs current mechanics.

A P0 reconciliation issue updates `prompt_docs/requirements/dating_endings.md`,
`contacts_invitations.md`, and `dialogic_skip.md` (plus the generated index) to
these rulings, and **blocks dwm-p2r.6, dwm-p2r.7, dwm-p2r.8** until complete.
dwm-p2r.4, .5, and .10 are unaffected and proceed. Retired spec to strip during
reconciliation: true-path ending identities and chain rule, missed-only pair
counting, "Special Sylvia first" as previously worded, `ending_*_true` /
`date_challenge_true` as ending-tier audio.

## 13. Contacts & invitations — dwm-p2r.6 refinements (2026-07-21 grilling)
> **Current status: SUPERSEDED MECHANICS.**
>
> Under the August 7 design section 7.2, opening a solo invitation is acceptance;
> the old reply-required model is superseded.

Two refinements from the dwm-p2r.6 grilling, to be reconciled into
`prompt_docs/requirements/contacts_invitations.md`:

**Nevermind scope (amends req.invitation.solo).** At day resolution the single
`nevermind` message fires for **any un-replied solo offer** — whether it was
**unread** (never opened) or **opened but unanswered**. The earlier wording
("only for an opened unanswered offer") is superseded. The only silent solo case
is **superseded** (a group invitation generated that day suppresses the pair's
solo offers). A **replied** offer is never a nevermind (it is schedulable, or a
missed invitation if accepted-but-unscheduled).

**Contact history model.** Contact history is an append-only per-friend log with
monotonic sequence watermarks (the highest sequence per friend). Generating a
message appends at the next sequence; re-generating at an existing sequence is a
no-op, which is what makes generation idempotent and the history cleanly
restorable through the save system. Solo offers move unread → reply_required →
replied, or become superseded. See §7 for the Priscilla–Lavinia four-way window
this history drives.
