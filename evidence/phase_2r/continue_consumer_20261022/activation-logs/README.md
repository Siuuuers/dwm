# Existing activation-log diagnostic — inert review candidate

Outcome: observe whether official Godot4.6.3 emits its existing adapter activation and initial-update-completed witnesses during the same rendered initial-registration case. Owner: official engine accessibility lifecycle; harness only enables existing verbosity. This is not native gameplay acceptance.

Basis: run39632926009 atadcede5ffb030d6258661b6eade37a578efd9e49 establishes matching sampled HWND262422 and PID4828, timely empty discovery, zero notifications/registration, clean reader0 and failing game1. Generic Win32 metadata does not determine adapter activation.

## Exact delta
Source d57fc90af73141f1a19e871e48205adc9788208e, parent39a9d23616229aa709ff4c7de7d726d48bee8890, tree1c59f126df7b26dce2066bf8eadcc7c60b45dc2f: one path tools/testing/Invoke-ContinuePublicationChecks.ps1. Add only '--verbose' to the focused engine argument list before '--accessibility'. No fixture, reader, production, UIA query, deadline, clock-classifier or pass-gate change.
Helper ff32e3488257ef3e2ab67ebdb24be7391f0047a9, parent86e2fbdd1458c02e5a85a52ce317f15d99398932: only PRODUCT pin. SHA256 7498a6055c0ea3821701c76ac1391fab0ed113fd4f86718eb477a1f8a141258d.
Inert activation-controller.yml SHA256 f364dc33f5fce86d4abe8d12f64f0dd59ca4952b60b6cc09a1f02f795e4eefe8: only source pin(two occurrences), helper pin/hash differ from cleared window-provider workflow. Actual writer/selector preflights and all preparation/source/failure gates retained.
Source/helper published readbacks byte-equal; helper Python AST checked. Cloud-only runtime validation; no local Godot/PowerShell.

## Source-supported distinction
Read official tagged source https://github.com/godotengine/godot/blob/4.6.3-stable/drivers/accesskit/accessibility_driver_accesskit.cpp
- window_create logs adapter created before its null-adapter check: not proof of success.
- _accessibility_initial_tree_update_callback logs adapter activated after constructing a busy initial root, before deferring the normal activation callable. This is a concrete executed callback boundary.
- accessibility_window_activation_completed logs adapter initial update completed and sets initial_update_completed.
Use these existing messages. Do not add an engine rebuild, forced refresh/notification or repeated UIA discovery.

## Failure interpretation and acceptance
Preserve complete raw log and process/source receipts. Confirm --verbose in actual bound argv. Do not use absent messages alone as proof of inactivity if logging/capture failed. Creation message alone is insufficient. Activation message establishes callback execution, not native Continue publication. Initial-update-completed message is its own boundary, not proof of UIA descendants or action behavior.
Logs are not timestamped by these engine statements: use available ordering only; no fabricated exact activation-vs-UTC timing. Additional logging may alter timing; changed registration is not by itself a causal explanation. Existing registration/timing/clean-exit qualification remains mandatory. Unexpected script/runtime errors remain failures, even if logging is noisier.
If neither witness nor new useful distinction emerges, preserve evidence and escalate the concrete evidence gap; do not repeat unchanged.

## Run plan and mission
External C must consume actual39632926009 result (PR30 comment6321331571) and clear exact candidate/controller/run plan.
Then A rechecks controllerff27c641e7bb521b9544ea03f08a9ff75c2ef6aa, active runs, product/integration/master; expected-head installs reviewed workflow only; one targeted run: writer7/selector11 actual PS5 preflights -> unchanged preparation -> one initial-registration case. Publish link/pause, preserve originals and request C actual-result review.
Standing continuous mission6319405974 permits progress without a new Director/user assignment; historical per-attempt/no-export gates remain superseded in scope. No held product/master/integration movement, merge or release. Caption qualification still precedes isolated composition/export journey.
