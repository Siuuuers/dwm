# Design Session Addendum — 2026-07-18

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

## NEW idea 1 — "Dark-mode Angela" main-menu toggle

Not found in any recovered doc (`grep` for dark_mode/meta/corrupt across
`docs/design/recovered/` returns nothing relevant). Treat as a new design decision.

- Angela is sweet by default in every route.
- Achieving **any** friend's **dark** ending unlocks a **"dark mode" toggle on the
  main-menu screen** (default OFF).
- When ON, Angela plays the whole run with her dark personality surfaced.
- Reach is **dialogue/tone only** — it does NOT change Minesweeper logic, meters,
  routing, or endings. It only adds dialogue variations. (Deliberate: keeps the
  verified mechanic stable.)
- Angela's dark mode is expected to matter most on the **alone ending** (per the
  designer: dark-mode Angela "sits on the alone ending," ignoring friend affection/
  dark-point, adding only dialogue variation).

Authoring implication (see `docs/design/recovered/DIALOGIC.md`): implement as a
**variable-gated branch inside the existing timelines** (e.g. `angela_dark == true`),
NOT as duplicated `.dtl` files. One timeline serves both personalities; only the
divergent lines branch.

Persistence implication: the unlock flag ("player has reached a dark ending") is a
candidate for the tier-2 marker layer described in NEW idea 2 — it should survive a
new game, because "the game remembers you went dark" is the intended feel.

Open question: does unlocking require a dark ending for a **specific** friend, or
**any** friend? (Session assumed *any*.)

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

## Suggested follow-ups (not yet filed as issues)

- Decide dark-mode unlock scope (any vs specific friend's dark ending).
- Decide whether to adopt the three-tier meta/save architecture; if yes, file a
  Phase 3+ issue distinct from `dwm-p2r.5`.
- Consider promoting the real Minesweeper engine from a single contract issue
  (`dwm-p2r.9`) to a set of Phase 6 implementation issues, since it is the game's
  defining mechanic.
