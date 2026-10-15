# Later partner-fork TEST content

Status: prepared, uninstalled content; **not a playable fork**. Production wording,
chapter placement and action remain unselected. This packet does not modify the
accepted title-opening template or install another registration/state owner.

## Source and scope

Inspected integration `3ae6d9138fb53c388380c78550cf6082eafc0ea3`.
Master remains `0c8b2384415d71bd3de4ff7408640bbf60b63740`; the newer narrative
amendments exist there, not in this integration tree.

- [Director B assignment](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6189235647).
- [Approved narrative amendment, sections 1–4](https://github.com/Siuuuers/dwm/blob/0c8b2384415d71bd3de4ff7408640bbf60b63740/story/09-priscilla-foundation-amendment.md).
- [Intended behavior, sections 1–2 and 5–7](https://github.com/Siuuuers/dwm/blob/0c8b2384415d71bd3de4ff7408640bbf60b63740/docs/design/2026-10-09-priscilla-flow-behavior-amendment.md).
- [Existing title-opening template](../scene_startup/README.md) is a separate,
  already accepted bounded milestone.

Observable eventual outcome: later in a run, one optional private Priscilla thought
offers only Yes. Yes selects P-S; passing its opportunity selects P-L. Both work
without any Challenge. The initial Sweet/Dark form remains unchanged; no partner
is selected at run creation. Other characters acquire no viewpoint or knowledge
from the audience seeing Priscilla's thought.

## Replaceable pieces

The DTL is [scene_partner_fork_template.dtl](../../fixtures/dialogic/scene_partner_fork_template.dtl).

| Fixture identity | Purpose |
|---|---|
| `scene.test.partner.shared` | Shared pre-fork and offer captions |
| `scene.test.partner.offer` | Label at the proposed thought caption |
| `scene.test.partner.expiry` | Candidate authored opportunity-end boundary |
| `scene.test.partner.sylvia` | Continuation for accepted Yes |
| `scene.test.partner.lavinia` | Continuation for passing the opportunity |

These are test-only names, not new runtime APIs or approved production IDs.
The expiry label illustrates the existing **recommendation** of script-progress
expiry; it does not settle production expiry or Auto/input ordering.

The three entries are deliberately disconnected. Their Return events terminate
compiler segments; they do not resolve a partner, expire a live offer, return to
a parent scene or advance a production chapter. There is no actual Yes widget,
choice event, variable assignment, Challenge, Perfect or observer-awareness award.
Launching the shared entry alone will not reach either partner continuation.

Replace caption prose while preserving entry labels and `#id:` line identities.
Once installed, prose changes still require owner-derived content/program hashes
and caption revisions. Structural changes require corresponding registration
updates. Existing saved content follows the existing compatibility/refusal policy;
do not overwrite saves or promise arbitrary story migration.

## Concrete interface request to Coordinator A

The current scene compiler in
`scripts/narrative/DialogicRuntimeAdapter.gd::compile_scene_programme` accepts
registered controls plus caption/label/jump/return events; native choice events
fall through to `scene_executable_event_refused`.
`scripts/domain/narrative/SceneEventContract.gd::SCENE_PAYLOAD_KEYS` admits
scene transitions, Challenge, Contacts and notifications, but no optional thought
or partner resolution. Its older `self_talk.trigger` envelope shape is not that
missing live scene operation. Generic Dialogic Choices availability is not
registered scene/save authority.

A owns shared runtime, schema, UI, registration and cloud integration. Please supply
the smallest existing-owner extension which can:

1. Bind one offered thought to its authenticated live caption/opportunity identity,
   with one Yes control and a registered default boundary.
2. Resolve exactly once to the registered Sylvia or Lavinia continuation, retaining
   the selected storyline through existing save/recovery/history owners, without
   changing the initial ending form.
3. Remove the control on resolution/expiry and refuse stale, duplicate or
   history/replay activation. Retain normal checkpoint refusal/retry behavior.

This is a behavioral interface request, not an invented method signature or a
second manager. A should choose the concrete representation after inspecting the
existing owners. B has not smuggled route selection through Contacts, Challenge
results, arbitrary DTL variables or direct state mutation.

## Failure boundaries and verification

Before connecting the fixture, cover the relevant ordinary failures: Yes input
after expiry or Load, duplicate input, failed resolution checkpoint and retry,
and reopening History after selection. A refused write must not display a committed
partner continuation or lose the valid retry; replay must not resolve again.

[Compiler test](../../unit/test_scene_partner_fork_template.gd) checks that all
three segments compile through the actual existing adapter with isolated caption
IDs and no effect nodes. It does not assert production placeholder prose.

Cloud execution: **NOT RUN by B**. A should include this focused test in the existing
Windows Godot 4.6.3 standard / isolated PowerShell controller when assembling the
coherent candidate. No local Godot/PowerShell or competing controller was launched.

After A supplies the hook, the bounded connected evidence needs both Yes and
pass/default paths through the real host, unchanged initial form, zero-Challenge
reachability, Save/fresh-process Load of the selected continuation, and ordinary
duplicate/stale/refusal behavior above. A pre-fork save must retain its unresolved
opportunity rather than inherit a later save's partner. Auto/input ordering should
be explicitly checked against A's selected boundary. Until then, compiler success
alone cannot establish playable, rendered, persistence, recovery or release acceptance.
