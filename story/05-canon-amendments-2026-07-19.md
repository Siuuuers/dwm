# Approved Canon Amendments — 2026-07-19

Status: **approved canon**, per the Core Story Bible's authority rule that later
explicit approvals supersede earlier proposals. These rulings resolve every known
conflict between the Core Story Bible (`01-core-story-bible.md`), the recovered
mechanical spec (`docs/design/recovered/`), the existing code, and the
2026-07-18 session addendum. Where a ruling amends the Bible, the amendment is
recorded here and the Bible text is left pristine; this file wins on the amended
points. Implementation details named here remain code-owned; this file records
approved intent.

---

## 1. True and Observer fuse — the "true (observation) end"

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

The gate applies to **all pairings, including the Priscilla–Lavinia encounters**
(group, missed, and private versions). In Angela-absent pair scenes the audience
plays the challenge board; this is canonically **Observer Pressure made playable**
— the audience's hand is the pressure in the room. It may affect legibility and
collisions; it may never author the pair's desire, state, tone, or consent (§10).

## 3. Board half of the gate — definition

Per pairing, per playthrough: **every attended dating challenge with that pairing
is a perfect (no-flag / foresight) clear, and none exploded.** One predicate per
pairing; any non-perfect challenge makes it false for the playthrough. No
cross-day chain bookkeeping. For Priscilla–Lavinia: perfect on both counted
encounters' boards.

## 4. Leveling — two tier-gated events per friend; fuel + valve

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

A counted window (Events 13, 14) resolves one of four ways:

1. **Group** — Angela scheduled and attends. Counts.
2. **Missed** — the group date was on the table but Angela stood them up; the pair
   meets without her, guilt flavor (next-day guilt messages). Counts.
3. **Private** — Angela scheduled neither woman; the pair meets, neutral flavor
   (a variation similar in shape to Missed, without the broken promise). Counts.
4. **Prevented** — Angela solo-dates one of the pair in the window; no meeting.
   Counts nothing.

All three occurring versions are **audience-visible scenes**, and each marks the
playthrough's drawn state/tone combination **seen** — subject to §10's witnessing
rule. The umbrella pickup never counts and never marks seen.

## 8. Sylvia Special — trigger and content

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

A P0 reconciliation issue updates `prompt_docs/requirements/dating_endings.md`,
`contacts_invitations.md`, and `dialogic_skip.md` (plus the generated index) to
these rulings, and **blocks dwm-p2r.6, dwm-p2r.7, dwm-p2r.8** until complete.
dwm-p2r.4, .5, and .10 are unaffected and proceed. Retired spec to strip during
reconciliation: true-path ending identities and chain rule, missed-only pair
counting, "Special Sylvia first" as previously worded, `ending_*_true` /
`date_challenge_true` as ending-tier audio.
