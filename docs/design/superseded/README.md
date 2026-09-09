# Superseded Design Evidence

This folder preserves whole design artifacts whose authority or intended use
has ended. An artifact here has either been completely replaced by later
accepted authority or belongs to an explicitly disposable, non-authoritative
prototype that has been retired as one intact cohort. The files remain
available as decision history, but they are not current requirements,
implementation instructions, plans, or fallback authority.

## Admission rule

A file belongs here only when one of these classifications is true:

- a later accepted document supersedes the whole artifact, not merely one
  clause or visual detail; or
- the file belongs to an explicitly disposable, non-authoritative prototype
  whose host has been retired and whose full cohort is preserved together.

All of the following must also be true:

- every current behavioral, canonical, accessibility, persistence, and failure
  obligation has another explicit living owner;
- the superseding or living authority is recorded in this folder's index;
- every inbound path or identifier reference is updated or deliberately
  preserved as historical provenance; and
- moving the file does not touch an unresolved merge conflict or another
  owner's uncommitted work.

Partially superseded documents stay in their original location with a narrow
supersession notice. Deferred future features stay in the Deferred UI Feature
Register. Recovered evidence stays in `docs/design/recovered/`.

## Authority law

Current accepted documents outside this folder always win. A file here cannot
authorize implementation, restore a rejected alternative, fill an intentional
absence, or weaken a later decision. Historical evidence must never be copied
back into current design without a new explicit owner decision.

## Index

| Historical artifact | Classification | Superseding or living authority | Archived | Why the whole file is safe here |
|---|---|---|---|---|
| `2026-08-13-lawful-universe-design-atlas-prototype.md` | Retired disposable prototype specification | Current accepted surface authorities listed below | 2026-08-24 | It declares itself disposable and non-authoritative; its HTML museum no longer owns game decisions. |
| `2026-08-14-lawful-universe-design-atlas-prototype.md` | Retired disposable prototype plan | Its archived source specification and the current accepted surface authorities listed below | 2026-08-24 | It can authorize work only on the retired non-shipping HTML Atlas. |
| `2026-08-14-lawful-universe-atlas-presence-refinement-design.md` | Retired disposable prototype refinement | Room-Owned Aperture v1 and the current accepted surface authorities listed below | 2026-08-24 | It controls only Atlas presentation; its centred portrait-register direction is expressly superseded by Room-Owned Aperture v1. |
| `2026-08-14-lawful-universe-atlas-presence-refinement.md` | Retired disposable prototype plan | Its archived refinement specification, Room-Owned Aperture v1, and the current accepted surface authorities listed below | 2026-08-24 | It targets only the retired portable HTML Atlas and grants no Godot implementation authority. |
| `2026-08-14-lawful-universe-atlas-title-caption-companion-expansion-design.md` | Retired disposable companion specification | Title/caption amendment plus current Schedule and Minesweeper Standards | 2026-08-24 | Its title, caption, Schedule, and Minesweeper projections are owned by later accepted game documents; its companion host is retired. |

### Living authority map for the retired Atlas cohort

- Title, Desktop, Angela HUD, clock, toast, and Pause: `../2026-08-22-shared-title-desktop-shell-standard-palette-and-state-disposition.md`.
- Title-art placement and bottom-up captions: `../2026-08-14-title-art-placement-and-bottom-up-scene-caption-rhythm-amendment.md`.
- Contacts: `../2026-08-22-contacts-maintained-correspondence-register-standard-palette-and-state-disposition.md`.
- Shop: `../2026-08-23-shop-maintained-campus-stores-standard-palette-and-state-disposition.md`.
- Backup: `../2026-08-23-backup-archive-cabinet-standard-palette-and-state-disposition.md`.
- Settings: `../2026-08-22-settings-university-calibration-registry-standard-palette-and-state-disposition.md`.
- Gallery: `../2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md`.
- Ordinary witnessed scenes and History: `../2026-08-22-ordinary-witnessed-scene-reading-apparatus-standard-palette-and-state-disposition.md`.
- Hospital and ordered endings: `../2026-08-22-hospital-ordered-ending-current-v1-ui-disposition.md`.
- Schedule: `../2026-08-23-schedule-mounted-docket-desk-standard-palette-and-state-disposition.md`.
- Minesweeper: `../2026-08-23-minesweeper-maintained-survey-worksheet-standard-palette-and-state-disposition.md`.
- Current participant staging and aperture ownership: `../../superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md` and `../2026-08-21-room-owned-aperture-caption-material-disposition.md`.

Each later admission must add one row containing the historical file, its
classification, its superseding or living authority, the archive date, and the
reason the whole file is safe to archive.
