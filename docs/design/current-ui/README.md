# Current UI Canon

This directory is the merge-forward destination for the game's current UI
design. It will contain one canonical dossier per UI family so a reader can
find that family's complete UI truth without choosing among overlapping design
documents. An accepted and repointed dossier becomes design authority only
within its declared scope. A proposed dossier is nonbinding, and no dossier by
itself authorizes implementation or proves that runtime matches the design.

One additional cross-family dossier, `global-ui-grammar.md`, is reserved for
the invariant functional-presentation grammar consumed by every family. It is
not a tenth screen or a behavioral super-authority: applications continue to
own their facts, commands, topology, persistence, failure, and recovery.

## One dossier per family

Each UI family has one stable dossier and one unambiguous owner. Its complete UI
truth includes:

- visual identity, material, layout, component anatomy, and functional states;
- player-facing behavior, copy, presentation canon, input, focus, and routing
  consequences owned by that UI;
- localization, text scaling, assistive output, TTS, motion, contrast, and
  other accessibility behavior;
- presentation-cache boundaries, the UI projection of persisted state, Load
  and reset behavior, failure, recovery, and acceptance evidence; and
- explicit exclusions, supersessions, dependencies, and known implementation
  drift needed to interpret the dossier safely.

The dossier records the player-facing consequence of an externally owned fact
and links its exact owner. It does not duplicate systems outside its declared
family—for example deeper story or relationship canon, game mechanics, Schedule
or ending resolution, save-file I/O, another family's shell arbitration,
global Settings and semantic-token systems, or asset/audio production. It may
specify design acceptance and proof obligations, but implementation plans,
mutable work status, runtime code, and generated/runtime verification evidence
remain separate and retain their declared scopes.

## Draft to accepted lifecycle

1. **Draft.** Inventory every candidate source and every inbound identifier or
   path reference. Merge forward while all existing sources remain authoritative
   in their original locations. Maintain a clause ledger that assigns every
   source clause to the draft, an exact external owner, or an explicitly
   superseded historical decision.
2. **Review.** Resolve contradictions by declared scope and recorded owner
   decisions. Verify that the draft contains no drafting marker, unresolved
   alternative, hidden behavior change, unsupported production claim, or
   unclassified clause.
3. **Accepted.** The owner approves the exact written bytes and the dossier
   records accepted status, a unique stable identifier, its absorbed sources,
   retained external authorities, and its implementation boundary. Only this
   accepted state may replace the family's prior design authorities.
4. **Repoint.** Update every living identifier, path, authority map, index, and
   machine-readable consumer to the accepted dossier. A retained historical
   reference must be labelled as provenance rather than left ambiguous.
5. **Move.** Only after all gates pass, move the wholly absorbed sources—not
   copies—into a family-named subfolder under
   `docs/design/superseded/absorbed-ui/` and index each moved artifact in
   `docs/design/superseded/README.md`.

Partially superseded documents remain at their current paths with narrow
supersession notices. Recovered evidence and deferred-feature authorities stay
in their existing dedicated locations.

## Exact-writing acceptance ledger

This ledger records the external owner-approval binding for an installed canonical-dossier artifact. It is lifecycle evidence only: an accepted entry
does not itself repoint a consumer, establish machine discovery, supersede a
source, authorize implementation, or permit source movement. Canonical-text
SHA-256 means valid UTF-8 without a BOM with CRLF or CR normalized to LF.

| Family | Accepted dossier | Owner approval | Exact accepted artifact | Present authority effect |
|---|---|---|---|---|
| Global UI Grammar | [`global-ui-grammar.md`](global-ui-grammar.md), `canon.current_ui.global_ui_grammar` | 2026-08-25; the owner explicitly named the stable ID and digest | 94,529 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `4c2dba5908c854e6972df608ef45c9bbe31654d3bc81ba18f22259a720cabecf` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation or source movement authorized |
| Contacts | [`contacts.md`](contacts.md), `canon.current_ui.contacts` | 2026-08-25; the owner explicitly named the stable ID and digest | 63,778 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `4739b83c1260a9c9c48b90bc2ad92fc6a163a88fe10262914e7ef0e90f9395bb` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, or commit authorized |
| Shared Shell | [`shared-shell.md`](shared-shell.md), `canon.current_ui.shared_shell` | 2026-08-25; the owner explicitly named the stable ID and digest | 123,247 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `232af85acee85bb69b58cdff1c42cb755ab0d821b90866ca2f6c026126824d71` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, or commit authorized |
| Gallery | [`gallery.md`](gallery.md), `canon.current_ui.gallery` | 2026-08-25; the owner explicitly named the stable ID and digest | 93,975 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `7fbc858566a6d9317f857e94bdf5f6ca889188d8b0132dab86585c25e1f04c11` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, or commit authorized |
| Witnessed Scene | [`witnessed-scene.md`](witnessed-scene.md), `canon.current_ui.witnessed_scene` | 2026-08-25; the owner explicitly named the stable ID and digest | 129,386 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `7b3ce28e0732e54c3227bf978bacd3e45a947f0393913784cfd34dfbc07f30b4` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation or source movement authorized |
| Shop | [`shop.md`](shop.md), `canon.current_ui.shop` | 2026-08-25; the owner explicitly countersigned the stable ID and installed accepted-state digest, derived clerically from approved design digest `034a5b36aa52792014a089f669d2e64a69ee5fbcedf71a9d24664d8cf1d56068` | 109,665 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `6c10286dcc90fae48f4a50fbb83860c35ad97c0d02692b2c0af42e83ba69641e` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, or commit authorized |
| Backup | [`backup.md`](backup.md), `canon.current_ui.backup` | 2026-08-25; the owner explicitly named the stable ID and digest | 121,824 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `1da253e262d996234208e2c95a1096a518ff1a19d02b8a1b85f185f9350da78d` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, or commit authorized |
| Settings | [`settings.md`](settings.md), `canon.current_ui.settings` | 2026-08-26; the owner explicitly countersigned the stable ID and installed accepted-state digest, derived clerically from approved design digest `a944cf96f2051ddd1a52b614edc0dff1cd91e150aa6f4ee6a126556625fe03d6` | 108,168 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `f8877f892aee62a3d5f3ba5618def2fe5b751508aa4a7e5da11d1c8459b1fa51` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, registry mutation, or commit authorized |
| Schedule | [`schedule.md`](schedule.md), `canon.current_ui.schedule` | 2026-08-26; the owner explicitly countersigned the stable ID and installed accepted-state digest, derived clerically from approved design digest `628e00919236d2021f7a5f20ad050b7156245ea098278a0d5afcfbbff265be2c` | 98,224 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `7183b9323908e9b10eab5d9192dfc567f5fe1d10b170c1c5eb53e23679539180` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, registry mutation, or commit authorized |
| Minesweeper | [`minesweeper.md`](minesweeper.md), `canon.current_ui.minesweeper` | 2026-08-26; the owner explicitly countersigned the stable ID and installed accepted-state digest, derived clerically from approved design digest `9717825150f275fde6bbc79764ed086b7a49a44af0f57815901ebb4fc06eb864` | 117,037 bytes; UTF-8 without BOM; LF; raw and canonical-text SHA-256 `20c4319ded61b8ce7474c5ad84414c3a7b46f3fc9bf567c6491a041271ec6430` | accepted exact writing; nonbinding until repointed and machine-discoverable; no implementation, cutover, source movement, archival, registry mutation, or commit authorized |

## Non-negotiable gates

No prior source may move until all of the following are true:

- the accepted successor covers every current visual, behavioral, canonical,
  accessibility, persistence, failure, and recovery obligation;
- the clause ledger has zero unmapped clauses and every historical exclusion is
  explicit;
- every retained external authority exists, is linked precisely, and still
  owns the cited scope;
- every inbound identifier and path reference is repointed or deliberately
  preserved as historical provenance;
- machine discovery, generated indexes, documentation validation, and authority
  resolution recognize the successor without duplicate IDs or broken links;
- reviewed implementation-plan bytes and their canonical hashes remain
  unchanged, or a separate reviewed plan amendment records and rebinds every
  affected hash;
- the superseded index records the successor, archive date, classification, and
  reason that the whole source is safe to archive; and
- no unresolved merge conflict or overlapping uncommitted owner work affects
  the source, successor, or references being changed.

## Machine-discoverability blocker

The current authority tooling does not discover design dossiers here. The
workflow resolver currently projects specifications from
`docs/superpowers/specs/`, while the packet validator and generated index cover
`prompt_docs/`. Therefore, placing or approving a dossier in `current-ui/` does
not by itself make its ID machine-resolvable. No dossier may claim machine
discoverability, become an executable authority link, or trigger archival until
the resolver/registry boundary is deliberately reconciled and verified.

Document consolidation must not edit a reviewed hash-bound implementation plan
silently. Preserve existing plan bytes and digests during this migration; any
necessary plan change is separate reviewed work with newly recorded hashes.

## Preserved inputs and provenance

This is a non-authoritative routing and provenance index, not a source ledger.
An entry is preserved so a family audit or later implementation review does
not lose it; inclusion does not make the artifact accepted design authority or
a source for an unrelated dossier.

| Artifact | Dossier or provenance use | Current classification |
|---|---|---|
| [`docs/superpowers/plans/2026-08-14-title-art-and-bottom-up-caption-components.md`](../../superpowers/plans/2026-08-14-title-art-and-bottom-up-caption-components.md) | Shared Shell and Witnessed Scene | path-bounded implementation evidence derived from the accepted title/caption amendment; never design authority by itself |
| [`docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md`](../../superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md) | accepted Witnessed Scene dossier provenance input | conversationally approved target architecture whose exact written specification remains pending owner review; its direction is restated in accepted successor bytes without retroactively approving this source |

Neither artifact is a Schedule authority, Schedule inbound consumer, or
Schedule absorption candidate. The Room-Owned Aperture cannot intercept,
filter, or reroute canonical progression before its separately gated atomic
all-consumer cutover.

## Family status

| Family | Successor | Lifecycle | Current authority |
|---|---|---|---|
| Global UI Grammar | `global-ui-grammar.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The mixed [Haunted Instrumentarium Foundation](../2026-08-14-haunted-instrumentarium-ui-manual-foundation-decisions.md) remains living; the [Global Functional Semantic Alphabet](../2026-08-21-global-functional-semantic-alphabet-disposition.md) remains the accepted direction with pending exact writing; the exact approved [Functional-State Morphology](../2026-08-22-functional-state-morphology-and-overlap-disposition.md) remains current within its scope |
| Contacts | `contacts.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The accepted [Contacts Messaging, UI/UX, and Canon Amendment](../2026-08-12-contacts-messaging-ui-ux-and-canon-amendment.md) and accepted-direction, exact-writing-pending [Contacts Maintained Correspondence Register Standard](../2026-08-22-contacts-maintained-correspondence-register-standard-palette-and-state-disposition.md) remain current within their recorded lifecycle strength and scope until a valid Contacts cutover; successor acceptance does not retroactively approve the Standard's pending predecessor bytes |
| Shared Title/Desktop/Pause Shell | `shared-shell.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The accepted [Main Menu, Desktop Shell, and Global Chrome UI/UX Amendment](../2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md) remains current for whole-family behavioral and geometric shell authority; the owner-approved-direction, exact-writing-pending [Shared Title and Desktop Shell Standard Palette and State Disposition](../2026-08-22-shared-title-desktop-shell-standard-palette-and-state-disposition.md) remains current within its recorded lifecycle strength and scope until a valid Shared Shell cutover, and successor acceptance does not retroactively approve its pending predecessor bytes; the [Title Art Placement and Bottom-Up Scene Caption Rhythm Amendment](../2026-08-14-title-art-placement-and-bottom-up-scene-caption-rhythm-amendment.md) and [Ordered Ending Host, Universal Pause, and No-Credits UI/UX Amendment](../2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md) remain living mixed authorities, with only their title-presenter and Universal Pause host contracts eligible to route to the successor after cutover |
| Settings | `settings.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The accepted [Settings, Preferences, and Accessibility UI/UX Amendment](../2026-08-12-settings-preferences-ui-ux-amendment.md) remains current for Settings behavior and retained cross-system law; the accepted-direction, exact-writing-pending [Settings University Calibration Registry Anatomy Disposition](../2026-08-20-settings-university-calibration-registry-anatomy-disposition.md) remains current within its recorded lifecycle strength and scope, and successor acceptance does not retroactively approve its pending exact bytes; the accepted [Settings University Calibration Registry Standard Palette and State Disposition](../2026-08-22-settings-university-calibration-registry-standard-palette-and-state-disposition.md) remains current for its two Standard visual mappings and provisional proof until a valid Settings cutover |
| Schedule | `schedule.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The accepted [Schedule Focused Docket Folio UI/UX Amendment](../2026-08-13-schedule-focused-docket-folio-ui-ux-amendment.md) remains current for focused Schedule behavior, persistence projection, failure, accessibility, and handoff; the mixed [Desktop Minesweeper, Shop, and Schedule Amendment](../2026-08-11-desktop-minesweeper-shop-schedule-amendment.md) remains current for deeper warning, board-fate, transaction, save/Load, and cross-app law; the accepted [Schedule Mounted Docket Desk Standard Palette and State Disposition](../2026-08-23-schedule-mounted-docket-desk-standard-palette-and-state-disposition.md) remains the current whole-family visual authority until a valid Schedule cutover |
| Minesweeper | `minesweeper.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The accepted [Minesweeper Board, Session, and Challenge Amendment](../2026-08-13-minesweeper-board-session-and-challenge-ui-ux-amendment.md) remains the current player-facing UI/behavior authority; the mixed [Desktop Minesweeper, Shop, and Schedule Amendment](../2026-08-11-desktop-minesweeper-shop-schedule-amendment.md) remains current for deeper mechanics and visible consequences; [Minesweeper Maintained Survey Worksheet Standard Palette and State Disposition](../2026-08-23-minesweeper-maintained-survey-worksheet-standard-palette-and-state-disposition.md) records owner-approved visual direction but its exact written bytes remain pending owner review and are not current written authority |
| Witnessed Scene | `witnessed-scene.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The accepted [Narrative Scene Host amendment](../2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md) remains current for behavior, transport, persistence, recovery, and ownership outside later narrow corrections; the accepted [Caption Material disposition](../2026-08-21-room-owned-aperture-caption-material-disposition.md), [Spoken-Scene Agency disposition](../2026-08-21-canonical-spoken-scene-agency-disposition.md), [Ordinary Witnessed-Scene Standard](../2026-08-22-ordinary-witnessed-scene-reading-apparatus-standard-palette-and-state-disposition.md), and [Hospital/Ending disposition](../2026-08-22-hospital-ordered-ending-current-v1-ui-disposition.md) govern their exact accepted scopes; the Room-Owned Aperture draft remains nonbinding as exact writing |
| Shop | `shop.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The [Shop Catalog, Purchase Transaction, and UI/UX Amendment](../2026-08-12-shop-catalog-transaction-and-ui-ux-amendment.md) and mixed [Desktop Minesweeper, Shop, and Schedule Amendment](../2026-08-11-desktop-minesweeper-shop-schedule-amendment.md) remain current within their retained deeper scopes; the [Shop Maintained Campus Stores Standard Palette and State Disposition](../2026-08-23-shop-maintained-campus-stores-standard-palette-and-state-disposition.md) remains the current whole-family visual authority until a valid Shop cutover |
| Backup | `backup.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The [Backup Save/Load UI/UX Amendment](../2026-08-12-backup-save-load-ui-ux-amendment.md) remains current for accepted Backup behavior, player-facing transaction consequences, compatibility, saved-time, shortcut, cache, technical-trust, and external-owner boundaries; the [Backup Transfer Bloom Disposition](../2026-08-20-backup-transfer-bloom-disposition.md) remains current for the shared material direction and deferred Distributed Transfer Field reopening rule; the [Backup Archive Cabinet Standard Palette and State Disposition](../2026-08-23-backup-archive-cabinet-standard-palette-and-state-disposition.md) remains the current whole-family visual authority until a valid Backup cutover |
| Gallery | `gallery.md` | Accepted exact writing; pending consumer repoint and machine discovery; no successor cutover yet | The accepted [Gallery and Rehearsal Archive UI/UX Amendment](../2026-08-12-gallery-rehearsal-archive-ui-ux-amendment.md) and accepted [Deferred UI Feature Register](../2026-08-22-deferred-ui-feature-register.md) remain current within their retained deeper and future scopes; the accepted [Gallery Maintained Microfiche Registrar Standard Palette and State Disposition](../2026-08-24-gallery-maintained-microfiche-registrar-standard-palette-and-state-disposition.md) remains the current whole-family visual authority until a valid Gallery cutover |

The accepted, not-yet-cut-over Global UI Grammar dossier imports only surviving cross-family
identity, reliability, theory-to-form, native-grid, token, type, material,
functional-state, overlap, and accessibility law. It does not wholly absorb the
mixed Haunted Instrumentarium Foundation. Only after a later valid cutover
passes every gate may the Global Functional Semantic Alphabet be retired as a
pending predecessor and the Functional-State Morphology source be wholly
absorbed. Neither source is eligible to move merely because the accepted dossier
exists.

The accepted, not-yet-cut-over Contacts dossier imports the complete current
family UI truth while preserving external ownership. B is a prospective whole
absorption candidate; V is a prospective retirement candidate whose exact
predecessor writing remains pending rather than retroactively approved. Both
sources remain authoritative within their recorded lifecycle strength and
scope until consumer repoint, machine discovery, and every cutover and archive
gate pass. Neither may move merely because the accepted dossier exists.

The accepted, not-yet-cut-over Shared Shell dossier imports the complete current
family UI truth while preserving external ownership. S is a prospective whole
absorption candidate; V is a prospective retirement candidate whose exact
predecessor writing remains pending rather than retroactively approved. Both
whole-family sources remain authoritative within their recorded lifecycle
strength and scope until consumer repoint, machine discovery, and every cutover
and archive gate pass. T and P remain living mixed authorities: only their
title-presenter and Universal Pause host contracts may route to the successor
after valid cutover, while T's narrative-caption authority and narrow section-10.5
implementation-authorization provenance and P's ending-selection, playback,
completion, and Gallery law remain external. No source is eligible to move
merely because the accepted dossier exists.

The Settings Preferences amendment remains living for accepted preference,
profile, language, reading, TTS, audio, lifecycle, display, Dark capture,
input, reset, migration, failure, and external-component law. The accepted
Settings anatomy direction also remains living because its exact written
artifact is still pending owner review and its production microtype, alternate
theme tuples, final bloom, and non-baseline allocation gates remain open. The
accepted, not-yet-cut-over Settings dossier imports their player-facing
consequences without retroactively approving D's pending exact writing. Only the
Settings University Calibration Registry Standard may become wholly absorbed after a valid
cutover. No Settings source is eligible to move merely because the accepted
dossier exists.

The focused Schedule amendment remains living for accepted Schedule behavior,
editing, warning interaction, persistence projection, failure, handoff UX, and
external-owner boundaries. The mixed Desktop Minesweeper, Shop, and Schedule
amendment remains living for the warning policy, board fate, Done transaction,
save/Load, cross-app, and deeper mixed mechanics it still owns. Only the
Schedule Mounted Docket Desk Standard may become wholly absorbed after a valid
cutover. The accepted, not-yet-cut-over Schedule dossier imports current player-facing
consequences without transferring registry, invitation, relationship, route,
day-resolution, Minesweeper, narrative-host, ending, save-I/O, or recovery
ownership. No Schedule source is eligible to move merely because the accepted
dossier exists.

The accepted Minesweeper Board, Session, and Challenge amendment remains living
as the current player-facing board/session/challenge UI authority and as owner
of behavior, input, metrics, persistence, recovery, handoff, transactions,
component boundaries, and verification. The mixed Desktop Minesweeper, Shop,
and Schedule amendment likewise remains living for deterministic generation,
safety capabilities, costs, signed rounds, checkpoints, cross-app board fate,
transaction ordering, and other mixed mechanics. The Maintained Survey
Worksheet disposition records owner-approved visual direction, but its exact
written artifact remains pending owner review and is not current written
authority. Only after that source is separately accepted and an accepted
Minesweeper dossier passes every cutover gate may the visual disposition become
wholly absorbed and move; both living amendments remain living and unmoved. The
Deferred UI Feature Register remains the sole current-v1 Rehearsal exclusion
and reopening owner. No Minesweeper source is eligible to move merely because
the accepted dossier exists.

The Narrative Scene Host amendment remains living for accepted semantic
playback, transport, challenge, persistence, failure, recovery, accessibility,
component, and external-owner law not transferred by a later valid Witnessed Scene
cutover. The mixed Title/Caption amendment, Visual-Art Placement guide,
Spoken-Scene Agency disposition, Hospital/Ending disposition, and Ordered
Ending/Universal Pause amendment likewise remain living for their Title,
production, cross-cutting agency, consumer-completion, ending, and Pause
scopes. The accepted, not-yet-cut-over Witnessed Scene dossier imports only their player-facing
apparatus consequences. The Room-Owned Aperture draft, Caption Material
disposition, and Ordinary Witnessed-Scene Standard are the only prospective
whole-source retirement or absorption candidates, and none may move merely
because the accepted dossier exists.

The Shop Standard remains the current whole-family visual authority and is the
only Shop source that may become wholly absorbed after a valid cutover. The
Shop Catalog amendment remains living because it also owns deeper catalog,
transaction, receipt, persistence, and condition-handoff law. The mixed
Desktop Minesweeper, Shop, and Schedule amendment likewise remains living for
capability, board-fate, route, Minesweeper, and Schedule mechanics. The accepted,
not-yet-cut-over Shop dossier imports their player-facing consequences without transferring
those deeper scopes. No Shop source is eligible to move merely because the
accepted dossier exists.

The Backup Save/Load amendment remains living for its accepted Backup behavior,
player-facing transaction consequences, compatibility, saved-time, shortcut,
cache, technical-trust, and external-owner boundary clauses. SaveManager,
lifecycle, run, host/route, and recovery custody remain with their separately
linked deeper authorities. The accepted, not-yet-cut-over Backup dossier records
the consolidated player-facing projection without transferring current
authority before cutover. The Transfer Bloom disposition remains living for the
current shared direction and the deferred Distributed Transfer Field's
reopening rule. Only the Backup Archive Cabinet Standard may become wholly
absorbed after a valid cutover. No Backup source is eligible to move merely
because the accepted dossier exists.

The accepted, not-yet-cut-over Gallery dossier imports the complete current-v1
player-facing Endings-only Gallery truth while preserving external ownership.
The Gallery/Rehearsal Archive amendment remains living for deeper archive,
domain, History, and future Rehearsal law, and the Deferred UI Feature Register
remains living and unmoved as the sole current-v1 Rehearsal exclusion and
reopening owner. Deeper ending, profile, host, Settings, state, narrative,
Minesweeper, and art custody remains with the separately linked authorities.
Only the Gallery Maintained Microfiche Registrar Standard is a prospective
whole-source absorption candidate after a valid Gallery cutover and every
archive gate. Gallery must cut over before or atomically with Global UI Grammar
so Gallery-specific functional-state behavior never becomes ownerless. No
Gallery source is eligible to move merely because the accepted dossier exists.
