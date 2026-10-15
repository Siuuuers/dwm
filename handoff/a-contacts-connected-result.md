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

Reviewed the actual message and parent-return captures: message text and controls are visible. The fresh-load screenshot includes the GUT overlay before the first Viewport click; it is retained unchanged and is not a clean visual acceptance image. B completed the persistence/caller review in PR34 comment6184554361 with no concrete source blocker. C completed bounded visual disposition in comment6184601053, accepting message/entry/parent-return views while retaining the overlay limitation; neither claims clean post-Load layout or rendered board restoration. This run is bounded connected evidence, not broad adversarial coverage or whole-game acceptance. No local Godot/PowerShell runs, master merge, release, or repeat audio/localization campaign.

Earlier diagnostic runs remain linked: run81 (38680331314) caught the test's wrong active/in_progress enum; run82 (38680619822) exposed the missing causal receipt in Contacts context and led to the runtime fix; run83 (38680946442) passed creator and all return/persistence checks but failed an overly broad Profile equality assertion. Run84 checks the exact expected resume-caption witness addition instead.

## Focused checkpoint-refusal follow-up

B identified missing injection coverage at the new message/read checkpoint seam. A added only tests/integration/test_scene_contacts_checkpoint_refusal.gd and its generated UID; no runtime code changed and the accepted connected journey was not rerun.

[Cloud run85 / 38683172134](https://github.com/Siuuuers/dwm/actions/runs/38683172134) passed all steps: **1 test / 60 assertions**, one child exit0, no skips or script errors, exact census/source/evidence gate green. Windows2022 / Godot4.6.3 standard as run84. Controller dead8f2a709dfe0645863c65f60f252476cf03cb; input candidate205da20b30cf78b52ea41c202083fb5bf8c53cec; cloud frozen source d062e119e4bb130915924d36a362ee316c896b5d / tree2f2a2976fed4ec3e9f2d76215264801e773f7b77. Commit1721cd0dd5aef0014d1d695ced37a0a753d245a1 retains that exact tested tree. Later changes are evidence/documentation only.

Using FINAL Bootstrap, real GameState, narrative checkpoint port and SaveManager, the existing negative-only FileOps wrapper refuses the actual autosave.json.next write once for the message and once for the read. Both return write_not_committed with rolled_back=true and committed=false; exact live run snapshot, Contacts, reading checkpoint, Profile and physical autosave bytes remain unchanged. The same issued command then retries successfully once; repeating it changes neither Contacts nor saved bytes and performs no write. Executed counters: 2 refusals, 6 writes (refusal + physical rollback + successful retry for each command), 2 final Contacts receipts. This closes the specific ordinary write-refusal/retry coverage gap; it does not establish crash/uncertain-compensation or broad adversarial coverage.

[run85-refusal.zip](../evidence/scene_contacts_connected/run85-refusal.zip) retains original XML/logs, fault proof, tested source/patch and identities. ZIP SHA256 5ae27c358c17ea66a4b180d5dc4b38e9f52e6bc3c24bd65754a2daedc4dee735; all34 manifest members checked after retrieval. Keep its 1/60 census separate from run84's 2/129.
