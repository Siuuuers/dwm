# Bounded post-export UID allowance — review candidate

21 October 2026 Hong Kong. Implements the bounded preparation task in [Director 6297698097](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6297698097).

## Observable outcome and owner

The existing preparation helper should accept only the four observed post-export UID sidecars, with retained bytes and consistent actual package mappings, while rejecting every existing-file change/deletion and every other addition. It must still gate all four native phases. No gameplay or saved-data owner changes.

Frozen product: `c8358870d3ece92d5f8cc7ba65aefe34a746be5c`. Previous failed attempt: [39456588183](https://github.com/Siuuuers/dwm/actions/runs/39456588183), evidence at `e79b12d4fb4a935bbcb46fc704318e3b7518e835`. Current active controller at preparation: `c0bb500fbbfdcc190c0a5a5a045f684d761cee88`. Master `41592fcc792aa615e47ee2ce2f05008ca195b311` contains narrative/documentation consolidation, not this preparation correction.

## Narrow policy

Only these optional additions are allowed after export:

- `tests/fixtures/dialogic/gallery_collection.dtl.uid`
- `tests/fixtures/dialogic/scene_author_option_slots.dtl.uid`
- `tests/fixtures/dialogic/scene_challenge_recall.dtl.uid`
- `tests/fixtures/dialogic/scene_partner_fork_template.dtl.uid`

Every prior generated path must still exist with identical bytes. Restoration retains its original exact-set check. Raw tracked/index/settings checks, pinned engine/templates, exporter and closed native driver/deadline/terminal semantics remain in place. No sidecar is fabricated, promoted, restored or copied from the previous run. No engine cache is rewritten or pruned.

Each actual addition retains its bytes/hash, parsed UID and pinned tracked source-owner provenance. The final check reads the actual exported ZIP/PCK, accounts for the corresponding packaged UID-cache records, and rejects conflicting mappings or source/sidecar inclusion. This is a reviewed build-generated metadata allowance; exclusion does not establish zero runtime influence.

## Review and execution boundary

This branch is an inert candidate. Internal tests/reviews do not replace external Coordinator C. C must clear both the retained failed-result classification and this exact candidate before A installs a controller. The Director has already conditionally authorized one new official Windows attempt after those two clearances, using same-run preparation → export/package/final gate → Capability → Create → Load → TerminalLoad. Preserve the first failure; no automatic retry. C reviews actual resulting package/native evidence before acceptance or harness integration.

No cloud attempt, active controller update, product/master/integration movement, merge or release is performed by this preparation. The prior failed run remains failed and its four native phases remain unexecuted.

## Verification and immutable pins

18 focused offline Python/Git integration tests passed. Coverage includes all four allowed additions, an optional single addition and absent mapping, changed/deleted prior files, other additions, malformed UID bytes, UID/path conflicts, duplicate addition UIDs, source/sidecar package inclusion, missing package/malformed cache, and unchanged restoration/raw/index guards. Inherited capture-helper ResourceWarnings remain disclosed. No Godot or PowerShell was executed locally.

Read-only replay against the original retained package passed: 2,091 PCK payloads checked, 2,836 UID-cache records decoded, four exact consistent mappings. Independent internal evidence verification checked original archive/part identities, all 204+15 manifest payloads and all 17 package members; independent source audit found no blocker. These checks do not replace external C review and do not change the original failed run classification.

The bounded parser follows pinned Godot source: [PCK reader](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/core/io/file_access_pack.cpp) and [ResourceUID codec/cache](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/core/io/resource_uid.cpp). Missing mappings are recorded as absent, not manufactured; conflicting actual mappings fail.

Helper source commit: `13c34ff20eec2430daad46a23e8a82fd6c691b7a`. Helper SHA256: `c62253edd0d15de024629f50cfce94e415e2dc41cc9a8fc84c19f2e8380e20e2`. Controller SHA256: `c28e57ae77bd65afd601102683f7663f52afc6956d233a675b50f07a7265fef3`. `bounded-uid-validation.json` records controller comparison: only helper source/hash pins and the final package argument changed; all other step blocks remain identical.
