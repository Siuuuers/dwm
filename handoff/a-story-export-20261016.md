# Registered story Windows export — Coordinator A

Status: bounded packaging milestone accepted; draft/unmerged, no release.

## Outcome

The normal registered seven-day TEST story now initializes in the exported Windows x86_64 executable from an empty isolated profile. Cloud run143 verified117 runtime JSON/DTL/DCH files byte-for-byte in the actual PCK, including the two registered story timelines and the story ordering file. The audit rejects every other file under tests/ and excludes test tools, development directories, and the export plugin itself.

This qualification covers unsigned release export and headless native startup. It is not rendered exported gameplay, accessibility, Save/Load execution in the exported binary, performance or full release acceptance. Earlier run141's25tests/623assertions remain separate accepted source-rendered evidence and were not rerun.

## Defect and minimal fix

[Product broad-CI run504](https://github.com/Siuuuers/dwm/actions/runs/38870409788), job116875233427, failed native startup with scene_programme_unavailable. The normal registration still used two established paths under tests/fixtures/dialogic/, and first-target selection used tests/templates/scene_sequence/seven_day_order.json. The release filter excluded tests/*.

Moving the registered locators would change the full registration fingerprint and invalidate previously accepted saved readers, even though programme hashes exclude file paths. A small editor export plugin instead adds exactly those three files at their established logical paths with unchanged bytes. The broad tests/* exclusion stays. The independent package audit hashes the three exceptions and rejects all other tests-path files recursively.

No save schema, registration bundle, programme, dialogue, ordering, recovery or runtime gameplay code changed. The existing test-only runtime flag remains restricted to debug builds; shipping these data files does not activate test registration.

The export receipt now records the actual checked-out product commit separately from the CI event commit. A controller workflow can test a pinned product checkout, so the event SHA must not be presented as the product SHA.

## Exact qualification

- Product source: `be597be59f3f06d7cc9ea6a169fbb433f1120ca3`.
- Tested source tree: `05085de256de4ccb6d39dfd469b979330bd9f704`.
- Parent accepted milestone: `b92951d4e4e06820768aea5d672d50c0c01f798c`.
- Controller: `387d6500d7070ea9518f3f2a47f2965f52529864`; workflow blob `9bf1462e91cf42e7ae2ebe353d5e6947bbb66098`.
- [Final run143](https://github.com/Siuuuers/dwm/actions/runs/38879107441), job116901229033: success.
- Windows2022, Godot4.6.3 standard GDScript; editor archive SHA256 `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90`.
- Official export-template archive SHA256 `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`.
- Native DWM.exe startup: exit0, no timeout or startup/engine/script errors, isolated profile created.
- Pack audit: exit0,117 exact resource hashes and strict exclusions passed.
- Independent verification: original evidence ZIP bytes/hash,19/19 manifest members, actual source/tree pins, all six changed source files, clean tracked source apart from two documented disposable-index gitlink removals. Registration, ending catalogue, both timelines and order file match accepted source bytes.
- Final original evidence:96340bytes; SHA256 `6a56b5c4fc8d33a7814ae1c76d02a7c7047caaabd1734f8dfa5aa4ddc8dd96f6`.

The files under `evidence/phase_2r/windows_story_export_20261016/` retain both original bounded evidence archives, final validation and independent verification. The full unsigned99MB validation build is a GitHub Actions artifact with limited retention; its runner-reported hash is recorded, but the build archive was not independently downloaded/rehashed. No binaries were published as a release.

[Run142](https://github.com/Siuuuers/dwm/actions/runs/38878690737), job116899868894, also passed packaging on `19a8710e2ccc61b1105fec351be7205a4f9289ec`. Its legacy validation.commit field contains controller event commit3970d4b5ead5446a26a983a19284a75eeb34c6b8; export-origin and source-check identify the actual product source. That provenance defect was corrected in run143. Do not count these two exports as separate gameplay acceptance or GUT tests.

## Continuation

PR36 remains the product draft; PR30 remains workflow-only and must not merge into product. Integration `3ae6d9138fb53c388380c78550cf6082eafc0ea3` and master `0c8b2384415d71bd3de4ff7408640bbf60b63740` were not changed.

Broad CI504 remains red in other lanes. Public API inventories, checkpoint diagnostics and audio passed; other failures include stale issuer expectations in new_account, legacy fixture/runtime composition and rendered/performance lanes. This packaging fix does not qualify those failures. Choose one concrete remaining failure, compare its current caller/owner contract and master, then execute only the necessary cloud checks. Avoid repeating completed run141 or143 without a relevant change. All engine and PowerShell execution remains cloud-only.
