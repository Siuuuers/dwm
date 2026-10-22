# Qualified short-route bundle reuse — run39759857757

## Result
Independent review PASS:37tests/453assertions (contract27/285,receipt9/99,rendered1/69),zero failures/skips/script errors. Three isolated children exit0. Rendered case25.162976s. Durable COMPLETED/GALLERY_RECORDED, readback and Title return pass.

| Measurement | Baseline39757235992 | Candidate39759857757 |
|---|---:|---:|
| Complete Accept seconds |23.586143|14.955353|
| Receipt validation calls |188|188|
| Bundle validation calls |2064|724|
| Physical proof calls |188|188|
| Receipt validation seconds |15.434748|9.523689|
| Bundle validation seconds |12.649887|4.294682|

Accept was8.630790s/36.59% lower in this one measured pair.1340/64.92% fewer bundle computations; receipt traversal and physical-proof counts unchanged. Inclusive categories overlap, never add. This is an observed short-route improvement, not a statistical guarantee or restored/export acceptance.

## Exact provenance
Product3f3621bd074d47c6e76d5e5b000a12ada08f142b.
Assets61553214b6f202b2f5083963c9aaa4a65778ce01.
Controller94f0cf4b9060331e5f11c4d6431b6d51a7c32622.
Actual event4d678d3fe4e7dd93f04d4c6e60960a6bffea1c5c workflow blob0eb412f0b487b1b98b80a098b24c486f380efa78 fetched and matched by Lead.
Independent review verifies12source pins across4custody phases,4policies,5205retained hashes,5helper files and raw-log/aggregate/XML/isolation agreement.

Original archives retained as25ordered512KiB parts. Concatenate parts in numeric order for each original ZIP. All uploaded Git blob identities verified against parts.json.
-12417767649.zip preparation SHA2563bc25b2d56a6803e9f5e36697d648b9da3a20d471af0bdb4c27244b44bbdd168
-12417991127.zip qualification SHA25652179ee9f78a64642782e8cf4c4cbc46f5144d51ba26244c37b0c64f744e5cac
Both match GitHub API artifact digests.

## Accepted change and limits
Only one runtime file changes pure computation: each public entrypoint freshly validates, then private helpers reuse detached computed bundle tables within that synchronous call. No cross-call cache, saved trust flag, removed issuer/storage callback, ledger traversal or recovery boundary. Two added tests pin mixed-invalid precedence and fresh input validation/detachment.

No PR36/master/integration promotion, merge or release. GeneralCI39759857771 failed separately. Restored Day4 journey, exported gameplay and arbitrary recovery remain unqualified. Existing instrumentation remains on diagnostic product ancestry; clean production promotion requires deliberate composition/qualification later.

Next task is source/packet reconciliation for the longer restored Day4-to-ending journey against the materially changed candidate, preserving prior240s child ceiling and15/20/5s local guards. Do not rerun completed37/453 or preceding diagnostic runs merely to resume. Do not raise timeouts or relabel prior failed runs.
