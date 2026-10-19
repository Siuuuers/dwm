# Later partner-fork TEST content

Status: connected TEST fixture, boundedly qualified; outside normal seven-day
startup. Production wording, action, day, placement and opportunity length remain
unselected. The initial Sweet/Dark form and title-opening template are unchanged.

## Source and scope

The [single author guide and template inventory](../scene_sequence/AUTHOR_GUIDE.md)
covers replaceable registered targets and optional content holders.
The three original DTL segments are composed by
[ScenePartnerForkFixture.gd](../../support/ScenePartnerForkFixture.gd).
See [A's implementation and evidence handoff](../../../handoff/a-partner-fork-20261017.md)
for exact source/run identities and failed-attempt exclusions.

- [Approved narrative amendment, sections 1–4](https://github.com/Siuuuers/dwm/blob/0c8b2384415d71bd3de4ff7408640bbf60b63740/story/09-priscilla-foundation-amendment.md).
- [Intended behavior, sections 1–2 and 5–7](https://github.com/Siuuuers/dwm/blob/0c8b2384415d71bd3de4ff7408640bbf60b63740/docs/design/2026-10-09-priscilla-flow-behavior-amendment.md).
- [Normal Auto decision](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6215552725)
  supersedes the historical Auto-hold proposal.

One optional private Priscilla thought offers only Yes. Yes selects Sylvia;
passing its authored boundary manually or through normal Auto selects Lavinia.
Both paths work without a Challenge. No partner is selected at run creation,
and the audience seeing Priscilla's thought grants other characters no knowledge.

## Implemented opportunity and owners

- No offer-specific Auto hold, separate expiry timer, No button or confirmation.
  Existing Computer and History holds remain.
- The authenticated `thought.pass` marker binds the opportunity, preceding offer
  caption, expiry label and registered destinations. `thought.accept` is live
  Yes intent, not an automatic authored marker.
- The existing command gate and checkpoint owner serialize resolution.
  A durable `thought_resolved` receipt precedes target admission; retry resumes
  its recorded target. No independent partner flag or new manager is introduced.
- Yes input is consumed rather than also advancing the caption. Resolution
  removes the control; stale/history/replay activation must not resolve again.
- The qualified example offers Yes at the complete caption immediately before
  the expiry marker. It does not qualify arbitrary multi-caption opportunities.

## Replaceable pieces

DTL: [scene_partner_fork_template.dtl](../../fixtures/dialogic/scene_partner_fork_template.dtl).

| Fixture identity | Purpose |
| --- | --- |
| `scene.test.partner.shared` | Shared pre-fork and offer captions |
| `scene.test.partner.offer` | Label at the thought caption |
| `scene.test.partner.expiry` | Registered TEST opportunity-end boundary |
| `scene.test.partner.sylvia` | Continuation for accepted Yes |
| `scene.test.partner.lavinia` | Continuation for passing the opportunity |

The builder binds `TEST.partner` to `partner.sylvia` and `partner.lavinia`
using the existing target table. These TEST identities are not approved
production IDs. Label spelling alone does not create a choice or a durable
resolution. The DTL segments retain Return delimiters; the registration/runtime
composition connects them. Launching the shared segment without that composition
does not supply the playable fork.

Replace prose while preserving entry labels and `#id:` identities for the same
beats. Recompile and validate owner-derived hashes/revisions; structural changes
require corresponding registration updates. Preserve existing saves and their
compatibility/refusal policy. Stable targets do not promise arbitrary migration.
Do not emulate this control with generic Dialogic Choices, arbitrary variables,
Contacts or Challenge rewards.

## Accepted evidence and remaining limits

A reports **nine distinct tests / 251 XML assertions**, combining the accepted
run155 subset (7/181) and run156's remaining Auto/uncertainty cases (2/70).
[Run156](https://github.com/Siuuuers/dwm/actions/runs/39034271188) also repeated
the prerequisite save creator; it is counted only once in the distinct total.
The original failed attempts remain failures, with accepted subsets and exact
pins recorded in the linked handoff.

Coverage includes keyboard Yes, History/Computer holds, manual and Auto passage,
earlier unresolved Save/Load, resolved receipt retention, physical checkpoint
refusal/retry, pending-target fresh recovery and uncertain-ack blocking.
Offer, recovered-Sylvia and Auto-Lavinia captures were reviewed at 992×558,
English 100% pixel font. The compiler-only test remains a separate narrower check;
compiler success alone does not prove persistence or rendered behavior.

The uncertain acknowledgement is explicit diagnostic fault injection, not an
OS-kill test. This is bounded TEST composition, not exhaustive crash recovery,
approved production placement, broad-CI or whole-game acceptance. Current
official exported ending/Gallery/Title/normal Load-exit qualification and ordinary
latency work remain separate and pending. A owns integration and cloud-only
Godot 4.6.3 standard GDScript / Windows PowerShell execution.

This documentation reconciliation runs no engine tests, changes no DTL/runtime
behavior and adds no new acceptance. Keep PR36 and controller PR30 draft/unmerged.
