# Failed Focus1 and Focus2 diagnostic archive stage

These are failed-run records, prepared in scratch for later repository adoption. They provide no current or whole-game acceptance.

| Capture | Run | Original ZIPs | Extracted files reproducible | Compressed archive bytes | Delivery |
|---|---:|---:|---:|---:|---|
| Focus1 | 37092368181 | 13 | 490 | 39,763,629 | Five ordered raw parts, each at most 8 MiB |
| Focus2 | 37093072813 | 1 | 8 | 1,371,000 | One compressed tar |

Focus1 archive SHA256: `84979244569ad99856d606ec1f784951a8da07c927c20b35b75262e8e807b51c`.

Focus2 archive SHA256: `64a504a99d1594db56e42d084eeeaf9d4db9912d2a8b99dd32b6c9a65bbc676f`.

Focus1 retains the raw invalid-Tween error despite 35 targeted XML passes, the obsolete refusal test, and the signed-ObjectID checker failure. Its diagnostic Python re-audit does not change either failed job or the failed run. Focus2 retains the stale-inventory failure and four explicit skipped job records; no runner log or execution is manufactured for skipped work.

Each original artifact ZIP is archived exactly once. Extracted members are not duplicated beside their ZIP; complete extraction inventories retain every path, byte count, SHA256, CRC and original member mapping. Every capture API/jobs/log/omission record is included. Frozen source/workflow snapshots, exact Git commits and complete Git tree identity inventories, original publication receipts, independent audit versions and correction receipts are included. Mutable later-run auditors and duplicate partial download/extraction directories are outside these archives; their relevant historical review records and complete original artifacts are retained.

`adoption-inventory.json` lists only the intended delivery files and their exact identities. **Do not adopt the unsplit Focus1 tar alongside its five raw parts.** It remains a staging/checking convenience. Do not adopt the expanded `focus1-payload/` or `focus2-payload/` directories alongside their archive delivery.

`verify_staged_archive.py` independently reassembles the listed delivery files, checks the compressed archive identity and every archived payload, then opens the archived original ZIPs and reconstructs all extraction identities. It needs only the package manifest and delivered files; it does not need this workspace's original attachments or extracted captures. Both `*-independent-roundtrip.json` receipts passed. No engine, PowerShell or network ran.

Example verification after adoption:

```bash
python -B verify_staged_archive.py --manifest focus1-package-manifest.json --output focus1-local-verification.json
python -B verify_staged_archive.py --manifest focus2-package-manifest.json --output focus2-local-verification.json
```

For full extraction, concatenate Focus1 raw parts in manifest order and verify its declared size/SHA256 before opening the tar. Within each tar, restore each `original-artifacts/` ZIP into `capture/artifacts/<artifact name>` using `extraction-inventory.json`; verify every member identity. Original capture manifests retain historical absolute `local_zip` paths unchanged, so use the inventory's portable archived path mapping.

Generated metadata correction: workflow heads e91e0b50…/f22f187d… are distinct from actual source-pinned checkouts 75d129b1…/058f817e…. Every executed job checkout log was verified against the source commit. The 1,266 cases span five ordinary suites; reading_delivery has 515 (514 pass, one failure). The prior scratch package is superseded, and original captures were unchanged.
