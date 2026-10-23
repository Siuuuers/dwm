# Coordinator A — bounded TEST Contacts work packet

15 October 2026. Implements the coordination request in Director comment
6183819347; reservations published in PR30 comment6184004188.
Historical planning packet. Implementation and connected cloud results are now
recorded in [a-contacts-connected-result.md](a-contacts-connected-result.md).
The requirements and original allocations below describe the preparation stage;
A subsequently reclaimed the dedicated connected tests in PR30 comment6184198257.

Observed product: fa965f7cb7b0c32cb7682758804cc9fc8eee3bc0.
Observed controller: 2a73df9d642847cddc71040eedbec08f59343ede.
Observed master: 0c8b2384415d71bd3de4ff7408640bbf60b63740.
Recheck refs before implementation or dispatch; these are not reset targets.
Retain the audio and pointer evidence in handoff/report.md without rerunning it.

## Observable outcome

Using FINAL application owners and an isolated labelled TEST registration:
seed the registered incoming message through a checkpointed application command;
open it through the actual Contacts presentation; close the computer; reach its
registered Contact entry boundary; finish the Contact scene; return to the
registered parent resume label using the original parent occurrence/admission.
Preserve the parent Challenge, all reading history and committed Contact facts.
Ordinary Save and a fresh-process Load must preserve those same relationships.
No production story, device ownership, reply choice or new calendar behavior.

## Source findings that change implementation

1. GameState lacks capture_scene_contact_context and resolve_scene_contact_facts.
   Its preview_open_contact/open_contact currently enter calendar paths. The
   scene branches of ContactCommandPort and ContactsPresentationPort already
   exist and should be reused; ContactInvitationState owns scene fact validation.
2. ApplicationBootstrap.open_scene_computer currently requires a Challenge and
   mounts only SceneChallengePanel. configure_contacts_desktop is legacy desktop
   wiring. A must expose the existing ContactListApp scene presentation through
   the actual scene host; C must not fake a desktop or mount a substitute host.
3. GameState._accept_scene_runtime_event rejects Contact kinds. There is no
   contact.enter result variant in SceneEventContract.validate_scene_result.
   validate_scene_receipts explicitly refuses admissions with return_to, while
   its contact_returned check only establishes that the admission exists.
   Both producer and validator must change together, with fact/parent proof.
4. GameState._admit_scene_target_owned accepts only transition/Challenge triggers
   and supplies null return_to. Its acknowledged staging machinery already owns
   durable-before-audio-before-native activation. Extend that owner.
5. Current registration has contact.return at contact.test.a.end, but no
   contact.enter marker. ScenePlayableFixture changes facts to TEST.fact.read;
   it does not add entry wiring. A's new dedicated fixture must compile its own
   explicit TEST entry marker and matching programme/registration hashes.
6. The existing return target is return_a -> scene.test.a.loop. This is an
   authored resume label, not an instruction to rewind to an old publication.
   SoloReadingSession.admit_scene can reuse a retained occurrence/frame;
   DialogicBridge._prepare_scene_entry stages a caption and appends publication.
   Return should retain the original parent admission/occurrence and full current
   ledger, then publish the authored resume caption once. It must not create a
   new parent admission. Exact prior-publication restoration is NOT this contract.
   The current line-frontier validator expects the ledger tail; discarding child
   history would invalidate historical event anchors. No new parent store is
   justified for the registered-label return.

An independent internal read-only source review supports the registered-label
approach. It does not replace external B's assigned persistence/caller review or
claim any runtime testing. The earlier informal phrase "restore the same caption"
must not be implemented as an old-frontier reset.

## Callable contract and worker dependencies

Reuse existing signatures (Dictionary results, normal ok/code failure protocol):

```gdscript
ContactsPresentationPort.get_projection(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary
ContactsPresentationPort.open_friend(friend_id: String, primary: String = "en", secondary: String = "") -> Dictionary
ContactCommandPort.request_open_contact(friend_id: String, before_commit: Callable = Callable()) -> Dictionary
GameState.preview_open_contact(friend_id: String, command_id: String, command_issuer_receipt: Dictionary) -> Dictionary
GameState.open_contact(friend_id: String, command_id: String, command_issuer_receipt: Dictionary) -> Dictionary
```

A supplies these missing semantic seams, already specified by the integration design:

```gdscript
GameState.capture_scene_contact_context() -> Dictionary
GameState.resolve_scene_contact_facts(source_fact_ids: Array) -> Dictionary
```

Context is exactly `{identity,scene_occurrence,registration_sha256,contacts_sha256}`,
derived from current live owners. Resolver scans the complete canonical Contacts
bag through ContactInvitationState.validate_scene_facts, returning its receipts;
caller-supplied receipt subsets and mutable fact caches are not authority.

Proposed A-owned setup command, pending implementation and focused tests:

```gdscript
GameState.emit_scene_contact_message(definition_id: String, command_id: String,
    command_issuer_receipt: Dictionary) -> Dictionary
```

It delegates preparation to ContactInvitationState.prepare_scene_message and
commits under real current-session/mutation custody. No direct assignment to
game.contacts, domain-only success or synthetic issuer. C must label this as
application-port setup, distinct from subsequent real Viewport message input.
The TEST entry path uses read eligibility; replies are outside this increment.

The existing scene computer open/close APIs remain Bootstrap-owned. C must wait
for A's actual mounted Contacts controls and report missing hooks rather than
guess a new product navigation design. Return is driven by the registered native
Contact marker through normal dialogue continuation, not a fabricated return call.

## Ownership and exact dedicated paths

A reserves shared implementation:

- autoload/GameState.gd
- autoload/DialogicBridge.gd
- autoload/ApplicationBootstrap.gd
- scripts/domain/narrative/SceneEventContract.gd
- scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd
- scripts/narrative/SoloReadingSession.gd
- scripts/narrative/FrozenRunContext.gd
- scripts/ui/SceneHost.gd
- scenes/narrative/SceneHost.tscn
- tests/support/SceneContactsRegistrationFixture.gd (new)
- tests/fixtures/dialogic/scene_contacts_connected.dtl (new)

A owns shared helpers, API inventory integration and all cloud/controller writes;
announce exact additional shared paths before editing them.

External C owns only these new dedicated fixture/test paths and generated UIDs:

- tests/support/SceneContactsConnectedFixture.gd
- tests/integration/scene_contacts_connected_child.gd
- tests/integration/test_scene_contacts_connected_create.gd
- tests/integration/test_scene_contacts_connected_load.gd

Reuse accepted fixture services without editing ScenePlayableFixture or the
accepted audio/pointer fixtures. External B is read-only: review concrete facts,
parent/entry/return identity and ordinary persistence. No duplicate implementer,
new coordinator or speculative interruption/source-overwrite test campaign.
These allocations do not assert that either external session has started.

## Acceptance requirements for the forthcoming candidate

Focused owner checks must establish: checkpoint refusal leaves read/message facts
unchanged; stale context/foreign issuer/forged facts refuse; duplicate command
does not duplicate effects; Contact entry binds the real registered read fact and
parent; nested calls and allocating exits while a call is outstanding refuse;
return belongs to that Contact admission and can complete only once.

The connected creator/fresh-loader journey must use real services and files:

- Show the TEST incoming text, unread-to-read change and actual message input.
- Prove reading establishes eligibility without entering while computer is held.
- Close and reach the explicit registered entry marker; save inside Contact.
- Fresh process loads that same saved state, retaining parent identity, facts,
  Challenge state and historical reading ledger; original selected save stays
  unchanged by Load.
- Continue through contact.return to the registered parent label. Assert same
  parent occurrence/admission, unchanged parent Challenge and one new resume
  publication; no replayed Contact read/effects and no lost child history.
- Save returned state and verify ordinary saved structure/owner validation.
- Retain labelled screenshots, exact source/engine identity, original logs and
  nonzero exact test census. Distinguish application-port setup from UI input.

Before dispatch, finish compatible source/caller reviews and recheck the released
controller. Run Godot4.6.3 standard and PowerShell in Windows Actions only. Do not
claim these acceptance requirements passed until their actual evidence exists.
No broad cleanup, cosmetic Back-label fix, Beads closure, master merge or release.
