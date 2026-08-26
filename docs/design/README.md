# Design authority and reference

This directory contains both registered design authority and historical or
exploratory reference. A Markdown file does not become authority merely by
being placed here.

The closed machine registry is
`prompt_docs/metadata/design_authority_registry.v1.json`. The registered
game-design authorities are:

1. `2026-08-07-seven-day-dialogic-flow-design.md` — the approved bounded base
   specification for the seven-day flow and Dialogic structure.
2. `2026-08-11-phase-2r-foundation-repair-current-authority.md` — the approved
   current reconciliation for the Phase-2R logical specification ID; it is
   explicitly not a reconstruction of missing July source bytes.
3. `2026-08-11-desktop-minesweeper-shop-schedule-amendment.md` — the accepted
   bounded amendment for desktop-board lifecycle, Shop capabilities, Schedule
   warnings, and the explicitly recorded Schedule decisions.

Within the amendment's scope it takes precedence over conflicting base-plan,
requirement, recovered-document, test, or skeleton-code wording. Outside that
scope the August base specification remains authoritative.

Within this bounded domain, interpretive authority follows this ladder,
highest first:

1. The approved seven-day specification, with the accepted amendment's
   precedence inside its own scope as above.
2. The nonconflicting story canon in `story/01-core-story-bible.md` and
   `story/02-character-relationship-handbook.md`.
3. The derived plot-neutral production map
   `story/03-seven-day-production-map.md`.
4. The noncanonical idea library
   `story/library/03-seven-day-plot-material-library.md`.
5. The recovered historical reference under `docs/design/recovered/` and the
   other preserved historical documents.

Approved requirement and decision packets under `prompt_docs/` translate this
design into atomic executable contracts. Beads owns mutable work status and
dependencies. Reviewed hash-bound plans own procedure. Runtime and evidence
describe physical implementation and verification. None of those statuses
implies another, and all registered game-design documents retain
`implementation_authorized: false` until a separate explicit authorization.

Other contents are not registered design authority:

- `session-addendum-2026-07-18.md` is exploratory session material.
- `recovered/` preserves the deleted design brain as historical reference.
- Noncanonical idea libraries and derived production templates remain subject
  to the authority notices in their owning files.
