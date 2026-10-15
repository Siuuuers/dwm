# Contacts connected cloud result — 15 October 2026

Implemented in draft PR #34, based on integration fa965f7cb7b0c32cb7682758804cc9fc8eee3bc0. Master and integration were not advanced.

The existing Contacts presentation and command ports now connect to the scene host, full causal identity, checkpointed message/read commands, registered Contact entry, and return to the original parent occurrence/admission. Save validation receives the full canonical Contacts bag. Return preserves the Challenge, Contacts facts and reading ledger, then publishes the registered resume caption once. This is an isolated labelled TEST registration; production story and reply choices remain outside this increment.

## Accepted connected run

- Run: https://github.com/Siuuuers/dwm/actions/runs/38681480224 (all steps successful).
- Controller: bda6b7d6e1313d342101c66aa55fd2eea720db71, PR #30.
- Input candidate: 8bd2f7cd2ebab685e76f625a0199ed2052a256ca.
- Cloud frozen commit: d63427654090b0ab3bbdb1fb032036216b9e9b95.
- Exact tested tree: a56df01f27b2125ff7fc173a8700ad0c1fabe23b.
- Repository commit 0de440e81cb411af8b60cce6d86bf364a5e87baa retains that exact tree, including the four cloud-generated UIDs. Subsequent changes contain this report, historical packet status and evidence only.
- Windows 2022; Godot 4.6.3 standard, 4.6.3.stable.official.7d41c59c4. Engine/archive hashes are in the retained engine.json.
- Creator: 1 test, 72 assertions, pass. Fresh loader: 1 test, 57 assertions, pass. Total: 2 tests / 129 assertions, no skips or script errors; both child processes exit 0.
- Separate process IDs 5672 and 7528; shared isolated real save files. Strict exact test census, source cleanliness and evidence gate passed.

The creator uses application-port message setup and ordinary Backup ports for Save/Load. Contact row selection, computer open/close, Challenge reveals and caption continuation use Viewport input. It proves unread-to-read, idempotent retries, no entry while the computer is held, registered entry with real read facts, forged/missing fact rejection, retained terminal Challenge and Save inside Contact. The fresh loader proves unchanged selected save, same child occurrence, preserved facts/board/ledger, exactly one return to the original parent, one new resume publication, exactly its Profile history addition, every other Profile field unchanged, and a successful second Save.

## Retained evidence and limits

[run84.zip](../evidence/scene_contacts_connected/run84.zip) contains original logs, JUnit XML, engine/source identities, SHA-256 manifest, exact changed source, patch, proof JSON and screenshots. ZIP SHA-256: eea8e5ae285571ba3fcb92bea7cabf493c38bad42bf3c63f8bbc8fbeb0b14f5d. All 40 manifest entries were checked after retrieval. GitHub artifact: scene-contacts-connected-38681480224-1 (ID11948397468), also uploaded successfully.

Reviewed the actual message and parent-return captures: message text and controls are visible. The fresh-load screenshot includes the GUT overlay before the first Viewport click; it is retained unchanged and is not a clean visual acceptance image. External C visual disposition and B persistence/caller review are not claimed. This run is bounded connected evidence, not broad adversarial coverage or whole-game acceptance. No local Godot/PowerShell runs, master merge, release, or repeat audio/localization campaign.

Earlier diagnostic runs remain linked: run81 (38680331314) caught the test's wrong active/in_progress enum; run82 (38680619822) exposed the missing causal receipt in Contacts context and led to the runtime fix; run83 (38680946442) passed creator and all return/persistence checks but failed an overly broad Profile equality assertion. Run84 checks the exact expected resume-caption witness addition instead.
