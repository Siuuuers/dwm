# Focus3 narrow repair evidence

Run `37093670324` completed all three intended cloud jobs successfully. Runtime source and every actual checkout are `abb7a3cac46ef3499fd797edd164ab8c1ac078f7`; the distinct workflow head is `d5652c4c8b9391cc57d5f5a7b1c1fc950a4db465`.

This archive retains four original artifact ZIPs exactly once and inventories all 63 extracted members. Complete API/jobs/log/capture records, exact source/workflow provenance and hash-bound independent audit/visual reports are included. The package creates no additional runtime acceptance. It is the narrow repair proof; the separate full Broad1 run remains outside this package.

The archive is `timed-hold-focus3-evidence.tar.gz`, 7,161,415 bytes, SHA256 `15d4d4117d108fb98060ba5f7deaea79fb4daac8a05393db555d2d56fc13e4c8`. It is below 8 MiB, so no raw split is needed. `package-manifest.json` records all delivery and inventory identities. `adoption-inventory.json` lists only intended delivery files; expanded staging payloads are excluded.

`verify_package.py` uses only these delivered files. It verifies the archive hash, every payload, each retained original ZIP's CRC and every extracted-member hash. `independent-delivery-verification.json` confirms all four ZIPs and 63 members; no original workspace attachment is required.

```bash
python -B verify_package.py --manifest package-manifest.json --output local-verification.json
```

To reconstruct captured artifacts, extract the tar, then unpack each original ZIP into `capture/artifacts/<artifact name>` according to `extraction-inventory.json`. Historical absolute `local_zip` values in unchanged capture metadata are replaced operationally by the inventory's portable `archive_path` mapping.

Scope remains an authorized noncanonical captionless timed-hold fixture. No production duration, canonical no-Sylvia Hospital completion, durable mid-hold save/restore, OS accessibility-tree/screen-reader, hardware-input or audible speech-quality acceptance is established. Prior failed runs stay failed and are retained separately. No Godot or PowerShell ran locally during packaging or verification.
