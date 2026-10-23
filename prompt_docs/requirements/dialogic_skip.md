---
id: req_packet.dialogic_skip
kind: requirement_packet
schema_version: 1
specification_status: approved
depends_on: ["spec.seven_day_dialogic_flow"]
beads: ["dwm-p2r.8"]
requirements:
  - {"id":"req.dialogic.authority","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.manifest","depends_on":["req.dialogic.authority"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.masters","depends_on":["req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.context","depends_on":["req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.signals","depends_on":["req.dialogic.manifest","req.dialogic.context"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.line_identity","depends_on":["req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.effects","depends_on":["req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.visited","depends_on":["req.profile.partition","req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.skip","depends_on":["req.dialogic.visited"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.dialogic.content_status","depends_on":["req.dialogic.manifest"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.dialogic_skip

Amended 2026-07-19 per `story/05-canon-amendments-2026-07-19.md`; that file wins on amended points.

Reconciled 2026-08-26 with the approved `docs/design/2026-08-07-seven-day-dialogic-flow-design.md` (`spec.seven_day_dialogic_flow`, the typed packet dependency); the approved specification supersedes conflicting mechanical wording.

## Rule req.dialogic.authority

Dialogic MUST be the sole narrative playhead; runtime code MUST communicate through the validated Dialogic adapter and bridge.

## Rule req.dialogic.manifest

Every externally callable narrative entry MUST have exactly one closed semantic-manifest record: semantic `entry_id`; optional stable ending ID plus exact allowed playback form; role and owning day or ending layer; locale-specific path/label locators; frozen-context schema and version; allowed signal IDs with exact payload schemas and source stages; content-contract version; compatible line-ID and presentation-atom namespaces; complete presentation-signature schema; and required/optional visual-resource IDs with expected types and declared neutral fallbacks. The manifest is closed: timeline, marker, effect, variable, line, and ending IDs all fail closed when absent, unknown suffixes MUST NOT resolve through permissive pattern parsing, and filesystem path MUST NOT serve as timeline or save identity. Retired true-path timeline IDs remain excluded, and Priscilla-Lavinia group, missed, and private scene variations register as distinct semantic entries inside the master timelines rather than as separate physical files.

## Rule req.dialogic.masters

English narrative authoring MUST consolidate to exactly eight physical master timelines - `day_1` through `day_7` plus `endings` under `dialogic/timelines/en/` - with future locale mirrors reusing the same label contract and missing locale entries falling back to the exact-label English master. One physical DTL file per semantic event is retired as an architectural requirement, and the old English skeleton files may be retired only after exact locator coverage and headless label tests pass. Every master begins with a bare `return`, every callable label block ends with its own `return`, and no label may fall through into its neighbor.

## Rule req.dialogic.context

Before playback the game MUST resolve and validate one immutable frozen presentation context per entry, expanded from that entry's role family into one exact discriminated schema: undeclared extra fields, invalid enums, wrong friend/day/source combinations, and mutable object references MUST be rejected, optional fields use declared defaults only, and canonical participant-ID arrays keep the fixed Priscilla-then-Lavinia order. No sentinel friend, fake Neutral attitude, or dummy tier is legal for Priscilla-Lavinia or Alone entries. DTL MAY branch on the frozen context and MUST NOT query or mutate live GameState, profile state, save objects, resources, arbitrary singletons, or filesystem data.

## Rule req.dialogic.signals

DTL MAY request only the five allowlisted signal kinds - `message.reply.commit`, `history.line.witness`, `message.echo.satisfy`, `observer.evidence.commit`, and `pair.combination.witness` - each with its exact closed payload and valid source stage; payloads MUST reject missing and extra fields and MUST NOT carry arbitrary deltas, method names, file paths, next-entry IDs, or save data. Invitation acceptance, board resolution, promotion, day resolution, Hospital, pair counting, Day 7 selection, and ending completion remain engine-owned commands, never DTL signals. Every state-capable signal is an acknowledged boundary: Dialogic MUST NOT advance to a consequence-dependent line before an accepted result or identical prior receipt, and a rejected signal aborts the entry at its registered continuation stage. Rehearsal sources route reply and echo commands only into sandbox state, persist only `history.line.witness` into the separate visited-line collection, and are denied Observer-evidence and pair-combination-witness capabilities even on entries that own them canonically.

## Rule req.dialogic.line_identity

Every authored line that may enter history, skip-seen, echo, Observer capture, Gallery collection, or save restoration MUST own a stable semantic line ID, and every non-dialogue action, visual beat, or deliberate silence that may satisfy an echo, Observer action, pair witness, resume boundary, or collection record MUST own a stable semantic `presentation_atom_id` declaring kind, owning entry/stage, and optional associated line ID. Neither identity may derive from file path, line number, label or animation position, elapsed time, or translated text, so physical consolidation and prose edits never invalidate witnessed history.

## Rule req.dialogic.effects

Narrative effects and variables MUST resolve through typed allowlisted transactions and MUST NOT invoke arbitrary methods by name.

## Rule req.dialogic.visited

Visited line history MUST be permanent profile state keyed by registered stable line IDs and MUST publish only after durable commit.

## Rule req.dialogic.skip

Skip MUST always fast-forward text; the setting MUST choose whether unread lines are eligible or only previously visited lines are eligible.

## Rule req.dialogic.content_status

Phase 2R MUST validate English timeline structure and MUST NOT invent dialogue prose or claim unavailable translated narrative coverage.
