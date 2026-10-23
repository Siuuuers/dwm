# Audio Asset Research

**Status:** Active research workspace; no acquisition or integration authority

This folder records the role-first search for existing human-created audio for
the accepted Acoustic Memory Atlas. Research may nominate assets for acquisition
review. It may not download, edit, import, register, or ship them.

## Authority

1. `docs/superpowers/specs/2026-08-14-acoustic-memory-atlas-audio-design.md`
2. `docs/research/2026-08-14-classical-music-recording-rights-and-free-sources.md`
3. `docs/superpowers/plans/2026-08-14-audio-asset-research-and-approval.md`
4. `docs/research/audio/2026-08-14-audio-role-register.md`

If a candidate conflicts with an authority, the candidate loses. A later
source-page or license-page change cannot silently replace the captured
evidence; it requires a dated review entry.

## Status vocabulary

- `CANDIDATE`: found but not fully audited.
- `CONDITIONAL`: promising, with one or more named evidence or fit gaps.
- `REJECTED`: fails a hard legal, provenance, comfort, or artistic rule.
- `LEGAL REVIEW`: depends on territorial status or rights-holder
  interpretation outside this project's research authority.
- `APPROVED FOR ACQUISITION REVIEW`: complete research evidence and suitable
  enough to compare as a preferred or fallback prospect. This is not download
  or integration approval.

The final approval packet alone may nominate preferred and fallback finalists.
Silence is always a valid decision.

## Candidate schema

Every candidate uses this exact heading and field order:

```markdown
### `<role_id>` — Candidate: <exact title>

- **Status:** `CANDIDATE` | `CONDITIONAL` | `REJECTED` | `LEGAL REVIEW` | `APPROVED FOR ACQUISITION REVIEW`
- **Creator / recorder / performers:** <exact credited identity>
- **Source page:** <direct asset or track URL>
- **Exact file identity:** <filename, movement, track number, or source-page file identity; “not exposed before download” when factual>
- **License:** <exact license name and version>
- **License page:** <direct deed, legal code, or creator terms URL>
- **Commercial game use:** Yes | No | Unclear
- **Modification:** Yes | No | Unclear
- **Attribution:** <exact requirement or “not legally required under CC0”>
- **Restrictions:** <redistribution, trademark, collection, account, territory, or other conditions>
- **Composition / arrangement / performance / master:** <classical only; otherwise “not applicable”>
- **Human / AI provenance:** <affirmative evidence, contrary evidence, or unresolved>
- **Proposed placement:** <approved surface, event, or cue family>
- **Permitted edit concept:** <trim/fade/loop/gain/EQ/narrowing, or “none”>
- **Loop and mono notes:** <page evidence and/or later-audition requirement>
- **Comfort and repetition risk:** <specific concern>
- **Why it fits or fails:** <concise artistic/legal judgment>
- **Retrieved:** 2026-08-14
```

Use `Unclear`, `not supplied`, or a named evidence gap when the source does not
provide a fact. Never infer a filename, performer, recording owner, AI status,
or permission from a search snippet.

## Fail-closed rules

- Accept only exact CC0, CC BY, OGA-BY, or another verified creator-owned,
  commercial-game-compatible, modification-compatible license.
- Reject NC, ND, ShareAlike/copyleft under project policy, personal use,
  unclear royalty-free, “no copyright,” reuploads, conflicting metadata,
  Mixkit music, and AI/GenAI.
- Freesound items described or tagged as AI, GenAI, synthetic generation, or
  generated are rejected.
- Human nonverbal material requires affirmative human performer/recordist
  provenance.
- Classical candidates clear composition, edition/arrangement, performance,
  and exact recording/master separately.
- A library-level license does not identify an exact asset; an asset page does
  not replace the license terms. Both are required.
- Research records links and evidence only. No audio is downloaded during this
  phase.

## Ledgers

- `2026-08-14-audio-role-register.md`
- `2026-08-14-music-candidate-ledger.md`
- `2026-08-14-ambience-candidate-ledger.md`
- `2026-08-14-material-foley-candidate-ledger.md`
- `2026-08-14-ui-gameplay-candidate-ledger.md`
- `2026-08-14-human-nonverbal-candidate-ledger.md`
- `2026-08-14-cross-ledger-rejection-log.md`
- `2026-08-14-audio-approval-packet.md`
- `2026-08-14-attribution-draft.md`
