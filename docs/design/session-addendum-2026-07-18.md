# Design Session Addendum — 2026-07-18

> **2026-07-19 update:** the `story/` narrative canon (Core Story Bible et al.) now
> exists and supersedes parts of this addendum. All reconciliation rulings —
> including the revised dark-mode Angela, the True/Observer fusion, and the
> Special's final trigger — are recorded in
> `story/05-canon-amendments-2026-07-19.md`, which wins over this file on any
> conflict.

Status: **exploratory design notes**, not an approved requirement packet. Captures
ideas from a grilling/brainstorming session that are NOT already covered by the
recovered design docs in `docs/design/recovered/`. Everything the session merely
*rediscovered* (board contract, affection deltas, true-path skill gate, pressure/
health/sequela chain, minesweeper-skill→romance coupling, per-character special-mine
flavor) is already authoritative in the recovered docs and is deliberately NOT
repeated here.

Cross-references point at the recovered spec so this file never becomes a second
source of truth.

---

## Context: why the recovered docs exist

The full design spec (`CONTENT`, `CONTRACTS`, `DIALOGIC`, `FLOWS`, `PHASES`,
`TESTING`, `REPORT`, `GLOSSARY`) was deleted from the working tree in commit
`6d304ea` on the theory that the Beads issues, generated from those docs, had fully
absorbed them. Verification (below) shows that is *mostly* true for the foundation
but leaves the signature mechanic thin. The docs are recovered read-only under
`docs/design/recovered/` so the design is visible again without disturbing the
`prompt_docs/` requirement pipeline.

---

## NEW idea 1 — "Dark-mode Angela": the traumatized, romance-refusing Angela

Not found in any recovered doc. Treat as a new design decision. REVISED from an
earlier framing — dark mode is NOT the player wearing Angela's darkness; it is
Angela **hurt by having lived through the dark endings**.

- **Unlock condition:** the player must have seen ALL FOUR dark outcomes — the dark
  ending of each friend (Priscilla, Lavinia, Sylvia) PLUS the Sylvia special (hospital)
  ending. Only then does a **"dark mode" toggle appear on the main menu** (default OFF).
  (The unlock flag is a tier-2 persistence-marker candidate, NEW idea 2 — it should
  survive a new game.)
- **What it does:** dark-mode Angela has **negative feelings about romance itself** —
  she's been broken by it. This surfaces as **refusal**: when any dating action is on
  the schedule, the Schedule Done press is BLOCKED, and Angela's left-panel dialogue
  box pops up (e.g. "I don't want to date."). Effect: dark mode effectively forces the
  **alone ending**, because she rejects every romance path.
- **No new Dialogic `.dtl` keys.** Dark-mode Angela's voice lives ENTIRELY in the
  **left-panel self-talk overlay** (see the shared system below), not in dating
  timelines. This is why it needs no per-timeline `angela_dark` branching.

**Consolidation — one system, two jobs.** Dark-mode Angela and the everyday Day-1..7
horror self-talk are the SAME feature: a **left-panel dialogue overlay on top of
Angela's portrait** that:
  1. delivers ambient inner-monologue dread on every route, every day (NEW idea 4), and
  2. becomes Angela's romance-refusal voice when dark mode is ON.
Build the overlay once; it serves both. Keeps the feature shippable for a solo dev.

Interaction with Schedule Done (recovered `FLOWS.md §2`): dark mode adds a new
pre-Done gate — if a dating entry is scheduled AND `angela_dark_mode` is ON, block
Done and show the refusal line. This is a new branch in the Schedule Done flow, to be
specified against `FLOWS.md §2` when filed as an issue.

---

## NEW idea 2 — Three-tier saves-vs-meta-horror architecture

The recovered save spec (`CONTRACTS.md §6`, `FLOWS.md §7`) is purely **defensive**:
reject corrupt/unsupported saves, never crash, forward-migrate, never resume an
in-progress dating queue. It has **no** meta-horror / save-as-canvas concept. The
session established that meta-horror ("the game knows things") is intended to be
central, which collides with a save system whose whole job is to be boring and safe.

Proposed resolution — keep them apart with **three tiers**, so the existing
save contract (`dwm-p2r.5`) does NOT get more complex:

1. **Canonical save** — exactly what `CONTRACTS.md §6` already governs. Run
   progress, day, per-friend affection + dark-point, route flags, minesweeper
   receipts. Versioned, migrated, atomic, recoverable. Never deliberately corrupted.
   No change from the recovered spec.

2. **Persistence-beyond-erasure markers** — a separate, tiny set of marker files
   OUTSIDE the canonical save (the DDLC "character files" trick). Stores only what
   the horror must remember across new games / deletions: has-seen-true-ending,
   dark-mode unlocked (NEW idea 1), restart-after-dark counts, a per-friend
   "watermark". Append-only breadcrumbs, not game state. Surviving a save deletion
   IS the scare. Note: the recovered requirement `req.contact.history_watermark`
   already uses the word "watermark" — this tier may be the intended home for it.

3. **Presentation-only fakery** — fake crashes, glitched UI, a character "editing"
   a textbox. Touches nothing on disk. Pure runtime theater; zero persistence risk.

Rule: the meta layer **reads** tier 1 but only **writes** tier 2. Tiers 1 and 2
never share a file. This lets `dwm-p2r.5` stay exactly as simple as specified.

Status: unspecified in recovered docs and NOT yet a Beads issue. If adopted, it
belongs in Phase 3+ (meta-horror is not foundation), filed as its own issue rather
than folded into `dwm-p2r.5`.

---

## Verification finding — do the Beads issues capture the original design?

Question the designer raised: the md docs were deleted because the Beads issues were
generated from them; does Beads actually hold the design?

Finding: **Yes for the foundation, thin for the signature mechanic.**

- Every recovered *flow* maps to a Phase 2R issue: run lifecycle → `dwm-p2r.4`;
  saves/migrations → `dwm-p2r.5`; contacts/invitations → `dwm-p2r.6`; schedule/
  hospital/dating/endings → `dwm-p2r.7`; Dialogic → `dwm-p2r.8`; integration/
  evidence → `dwm-p2r.10`. Nothing foundational is orphaned.
- BUT the game's signature horror engine — the **real** Minesweeper board (3BV /
  foresight scoring per `CONTENT.md §12`, mine-density scaling by `pressure`,
  jealous/desire special-mine stingers per `CONTENT.md §13`, board-performance →
  romance coupling per `FLOWS.md §6` "Phase 6") — is deferred to **Phase 6** and
  currently lives in a single P1 contract-definition issue, `dwm-p2r.9` ("Define
  Phase 3 desktop and Minesweeper contracts"). No Phase 6 implementation issues
  exist yet.

Implication: completing Phase 2R yields a working dating-sim skeleton with a
**placeholder** board (simulated results via buttons), not the horror engine. The
process rigor currently guards the plumbing far more thoroughly than the soul. This
is a legitimate foundation-first choice — but it should be a *known* choice, and the
Minesweeper engine deserves its own dedicated issues before it is called "designed."

---

## NEW idea 3 — The God of Love (invisible systemic pressure) + the true-path thesis

Not in any recovered doc. The single most load-bearing new concept from the session:
it supplies the *fictional source* of the "dread you can't explain."

**Thesis (the game in one line):**
> Attraction may pull two people into the same room. Choice decides whether staying
> there means love.

**The God of Love** is an unseen force. It is NEVER a cute mascot and NEVER canon on
the player's side — it does not appear, is never confirmed, and characters are wholly
unaware of it. It acts only as *subtle systemic pressure*:

- It can increase **collisions** (make two people end up in the same place).
- It can amplify **attraction**.
- It can make **meetings more likely**.
- It **cannot** define consent or force a choice.

Every intervention must be **physically possible and individually deniable**:
coincidence, accident, a system/computer error, weather, a mistimed message, a
crossed path. No single event is provably supernatural; the *accumulation* is what
unsettles. Characters treat the strange as normal ("as usual") — the player is the
only one whose neck prickles.

**Design consequences:**

- This is the answer to the open "how does the player half-notice the board matters /
  why does anything feel wrong" question. Dread is sourced in *statistics that feel
  slightly off*, not gore or jump-scares.
- It cleanly splits authorship: the God controls **proximity** (collisions, pull,
  likelihood); the player controls **what happens in the room** (the board, choices).
- It reframes routes: a **dark ending** is where someone let the *pull* decide instead
  of *choosing* — they mistook arrival-in-the-same-room for love. The **true path**
  (the hard, earned streak) is where choice, not proximity, does the work — hence the
  thesis is literally the true path's thesis.
- Delivery candidates (physically-possible-only): desktop clock/timestamp drift as
  dark-points rise; a message that arrives just before you'd have needed it; weather
  or a "system error" that cancels one plan and creates another; an app that opens
  itself. All ambient, none confirmed.

Open questions: how strongly should God-of-Love nudges correlate with dark-point
level (louder as you darken)? Should any nudge ever be *readable* in hindsight on a
true-path replay (tie-in to NEW idea 1's "faint trail")?

## NEW idea 4 — No authored opening/tutorial; explore-first with Angela's self-talk

Designer preference: do NOT build a scripted OpeningScene or tutorial sequence.
Player learns by exploring the desktop. In place of a tutorial, **Angela emits short
self-directed dialogue on the left panel** (over her portrait image) — ambient inner
monologue that orients the player without a formal teaching flow.

- Replaces the existing `OpeningScene` / `TutorialOverlay` scripted beats with
  ambient, diegetic guidance.
- Fits the God-of-Love tone: Angela's self-talk can register small wrongnesses as
  "normal" ("weird, the clock's off again"), seeding dread while pretending to teach.
- Implementation note: this is left-panel monologue on `MainGameScene`, not a Dialogic
  timeline necessarily; keep it lightweight and skippable-by-ignoring.

## Confirmed-for-game — Sylvia hospital "how did she know" scene

Designer accepted the session's surveillance reading: Angela neglects her body →
faints before the Sylvia date → Sylvia is *already at the hospital that day*. The
scare is the unanswered **"how did she know?"** — being cared for is the trap. This
is the intended fiction for the `sylvia.special` ending (recovered `FLOWS.md §6`,
`CONTENT.md §13` `ending_sylvia_special`). Expand per session brainstorm.

## Suggested follow-ups (not yet filed as issues)

- Decide dark-mode unlock scope (any vs specific friend's dark ending).
- Decide whether to adopt the three-tier meta/save architecture; if yes, file a
  Phase 3+ issue distinct from `dwm-p2r.5`.
- Consider promoting the real Minesweeper engine from a single contract issue
  (`dwm-p2r.9`) to a set of Phase 6 implementation issues, since it is the game's
  defining mechanic.
