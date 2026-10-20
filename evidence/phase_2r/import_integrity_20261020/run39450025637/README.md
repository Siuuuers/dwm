# Import-only reproduction: complete tracked-byte custody, strict gate failed

Run [39450025637](https://github.com/Siuuuers/dwm/actions/runs/39450025637), attempt 1, job 118722059242. Installed controller `d47703368ad96c5ea0338b74b351f9d1c9cc1487`; frozen product `c8358870d3ece92d5f8cc7ba65aefe34a746be5c`. C clearance: PR36 comment 6294611362 under Director PR30 comment 6293667852. The one authorized import-only reproduction is consumed. No export or native gameplay was attempted, and no retry is authorized by this report.

## Preserved original evidence

Artifact 12277264918: 3,777,448 bytes, SHA-256 `4c802bcd75a55f6293b57c08d79b3d354dbd464bee4f9b64dfb910a9bf355e14`. The original ZIP is preserved without repacking as eight binary chunks `original.zip.part01` through `original.zip.part08`; concatenate in numeric order and verify that archive hash. Parts 01–07 contain 524,288 bytes each, final part 107,432 bytes. This split only accommodates publication transport limits.

All 52 ZIP members are accounted for: 51 payloads verified against the artifact's manifest, plus the manifest itself. Five byte locators were independently checked for exact size, SHA-256 and Git blob identity. `verification.json` records the census and limitations. `job.log.gz` contains the connector-returned job log encoded as UTF-8, separate from the original archive. `project-settings.diff` is a derived readable view; the exact settings bytes remain in the original archive.

## Actual observations

- Editor: `4.6.3.stable.official.7d41c59c4`, official standard Windows archive pin verified. Import exit 0; existing error-pattern filter passed. Import console log also contains an ObjectDB leak warning; a successful import is not a delivery pass.
- Baseline and post-capture succeeded over 13,419 tracked paths. Census `complete=true`, unchanged HEAD, no active capture failure.
- **None of the 997 tracked `.import` sidecars changed raw bytes.** There is no demonstrated sidecar checkout normalization, generated metadata edit, or import-setting change in this reproduction.
- Exactly one tracked worktree file changed: `project.godot`. Its Dialogic `directories/dtl_directory` dictionary became empty; the retained unified diff shows the exact change. This is the existing settings rewrite for which the original delivery controller already restores committed settings. The diagnostic intentionally did not restore it, so strict integrity correctly failed.
- Exactly two index entries were removed: the previously disclosed malformed tooling gitlinks. No other index blob/mode change was reported.
- Status also lists 34 newly generated untracked paths (10 image sidecars, 24 GDScript UID files). Their names are preserved, not their bytes; they are outside this tracked-file census and are not promoted to source or historical evidence.

The post-capture helper runs `git status` before its raw `diff-files` report. Git status can refresh index stat metadata; this does not change tracked raw bytes or staged blob identities, but it means that post-capture `diff-files` is not a measurement of the original unrefreshed stat condition. This limitation is explicit. The raw-byte census, not the refreshed status, establishes unchanged sidecar bytes.

## Narrow diagnosis and proposed correction

A synthetic Git fixture demonstrates that rewriting identical bytes with a changed mtime can make `git diff-files --exit-code` return 1. It is a stat-cache false positive relative to source-content integrity. This mechanism is consistent with the earlier 990 reports, **but does not prove their cause**: run 39441551063 did not preserve rewritten bytes, and this reproduction did not retain the pre-status stat-only diff. The original report remains unclassified retrospectively.

The smallest concrete predicate correction is in `../integrity-correction.proposed.patch`, targeting the original delivery controller at `c49990cea18bf16fcb4ed03a432e8ecb662f4b83`:

```diff
- git diff-files --exit-code
+ git -c diff.autoRefreshIndex=false diff --exit-code
```

The porcelain comparison checks content; disabling automatic refresh keeps the exact index bytes unchanged in regression. No source restoration, index refresh command, ignore flag, whitespace exemption, or `.import` exception is introduced. The existing HEAD pin and second HEAD-to-worktree allowed-path guard remain in place, so staged changes cannot hide behind an index comparison. Git's existing attributes/clean-filter semantics still apply; the retained raw-byte census is needed to distinguish checkout normalization from content changes.

An earlier exploratory `--patch` addition was rejected because its exit status still produced false positives. It was not published as the candidate or executed in cloud. The final predicate fixture passed identical-byte rewrites, real same-length edits, binary edits, deletion, and staged-change detection. Independent review additionally passed ordinary/future mtime cases for both text and binary data and verified exact `.git/index` bytes unchanged in all eight cases. These are Python/Git checks, not local Godot/PowerShell or a Windows runtime pass.

## Next review gate

C should review this evidence classification and exact one-line predicate correction. Before any separately authorized delivery run, its integrated controller must retain the reviewed baseline/post-import capture and always-upload evidence **before** the already-approved project-settings restore, retain strict raw-byte checks, and verify restored settings. No sidecars need restoration based on this reproduction; no cache coherence assumption is made. The patch is an inert proposal, not a complete newly authorized delivery workflow. Product/runtime/save/history remain untouched. Director must scope any further cloud verification or full export/native attempt after correction review.
