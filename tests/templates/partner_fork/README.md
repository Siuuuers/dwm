# Later partner-fork TEST content

Status: prepared, uninstalled content; **not a playable fork**. Production wording,
chapter placement and action remain unselected. This packet does not modify the
accepted title-opening template or install another registration/state owner.

## Source and scope

Initial content inspection: integration `3ae6d9138fb53c388380c78550cf6082eafc0ea3`.
Runtime dependency review: `154aede473ac8f91e56e0c48af7d0d2f10153d73`.
At initial inspection, master was `0c8b2384415d71bd3de4ff7408640bbf60b63740`; the newer narrative
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

## Approved Auto and expiry behavior — 16 October 2026

The user answered: “No, the auto would just advance.”
[Director's decision record](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6215552725)
settles the earlier question and supersedes the Auto-hold recommendation in
[B's concrete interface packet](https://github.com/Siuuuers/dwm/pull/37#issuecomment-6215021061).

- Auto continues its normal caption progression while the optional thought is
  available. Do not introduce an offer-specific Auto hold.
- Selecting the sole Yes control selects Sylvia. Passing the authored opportunity
  boundary, manually or through Auto, selects Lavinia exactly once.
- No separate expiry timer, No button or confirmation control is introduced.
- Existing Computer-open caption/Auto freeze still applies.
- Production action, prose, day, placement and opportunity length remain
  unselected. The TEST label below does not approve any of those details.

A owns runtime/UI/save integration after the currently reserved clock task.
Reuse the linked concrete interface/path proposal with this settled advancement
rule; its former question and hold recommendation are superseded. Keep the
existing scene registration, command receipts and target-admission owners.

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
The expiry label is the proposed boundary for this explicitly labelled TEST
installation, immediately after the offer caption. The approved advancement rule
above applies when the hook is installed; the label is not a production placement
or duration decision. Input ordering must still be verified through the existing
command owner.

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

At the inspected runtime pin, the scene compiler in
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
4. Let normal Auto progression cross the authored boundary and resolve the default
   once. Consume Yes activation so it cannot also advance dialogue. Serialize Yes
   and boundary departure through the existing command gate; never commit both.

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
opportunity rather than inherit a later save's partner. Verify Auto remains enabled
and progresses across the TEST boundary to Lavinia without an offer-specific hold;
verify Yes selects Sylvia without also advancing, and Computer-open freeze still
prevents caption/Auto progression. Cover stale input after Load and competing
Yes/boundary requests without duplicate resolution. Until then, compiler success
alone cannot establish playable, rendered, persistence, recovery or release acceptance.
