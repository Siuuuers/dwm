# One official delivery attempt stopped before export

Run39441551063 / job118692418355 / attempt1, 20 October2026: **FAILURE**. C6293482944 cleared the exact candidate; A installed reviewed workflow blob1210abacb7fcb67a1006ec2d3aebff92b3ffcdb8 on controllerc49990cea18bf16fcb4ed03a432e8ecb662f4b83 with expected-head protection from9f7fe38a. No separate dispatch or retry.

Product c8358870d3ece92d5f8cc7ba65aefe34a746be5c / treeaacc9bfb8a1d076016a477e396acf781d4786062; driver8adc8c78fcbf25fa0df030391bac6f1d64073a01, SHA2567a4bcd31aa4f340e76e0aee34c5857565d672ed38b3c66275fab525ea40ac21c; workflow/event5a0a749d0350d5f912451065a9e234145c7874ec. Windows2022 / PowerShell7.6.6 / official Godot4.6.3 standard.

## First causal boundary

`Verify frozen product before export` failed at `git diff-files --exit-code`, throwing `TRACKED_PRODUCT_FILES_CHANGED`. The complete log lists990 unique tracked changes, all `.import` sidecars: addons193, art13, assets22, evidence749, root icon1, tests12. No non-sidecar path is in this observed diff output. The controller restored project.godot after import but demanded all remaining tracked files be unchanged.

This is a harness/build-preparation source-integrity failure before native export, not a provider/gameplay failure. The guard correctly refused a changed checkout; its preparation did not account for these import-time changes. The rewritten sidecar bytes/diffs were not retained, so this evidence does not establish that every change is harmless, solely line endings, or safely ignorable. Do not broadly exempt `.import` files or delete the guard on this evidence.

## Outcomes

| Phase | Actual result |
| --- | --- |
| Exact source/driver custody and PowerShell parser | Passed; parser errors empty |
| Official editor installation and import | Steps passed; import ObjectDB leak warning disclosed |
| Official templates cache/download verification | Passed; cached official archive verified |
| Frozen product check | Failed, exit1, before export |
| Export/package/startup | Unexecuted; no EXE/PCK/package created by this run |
| Capability, Create, Load, TerminalLoad | All unexecuted; no native journey child exits or gameplay evidence |
| Evidence summary/upload | Passed |

Import log contains `WARNING: ObjectDB instances leaked at exit`; the existing import gate passed and must not be described as leak/warning-free. Upload/cache actions emitted Node deprecation warnings. No wait limit was changed and no further native attempt was launched.

## Retained evidence

Original artifact12274186759, `official-delivery-39441551063-1`,33132bytes, ZIP SHA256 `c3b5a61eeabb5701bc82980a27036cf6dfa7449b16df6d06ad9fae4300ff77e1`. Original `original.zip` retained unchanged;7 ZIP members and all6 manifest payloads independently verified. It includes import.log, exact driver/native probe, origin, parser, phase summary and manifest. Driver hash matches reviewed source. `verification.json` and `changed-import-paths.json` record checks and census. `job.log.gz` is the complete fetched GitHub job log, UTF-8 with normalized LF; it includes the failed guard output absent from the artifact's compact phase summary. This gzip is a log preservation copy, not the original GitHub artifact.

## Next decision, not automatic work

Per Director6293127731, stop at this first boundary. Recommend Director/C select a narrow build-preparation correction that retains the complete import-sidecar diffs, preserves exact source custody, and reconciles only demonstrated generated changes with committed inputs before the strict check. No correction or retry is implemented or authorized by this report. Existing runtime/save/recovery/History owners and30s/480s limits remain untouched. Any renewed execution needs explicit scope selection.

Product/PR36 remainsc8358870 draft/unmerged. Active controllerc49990ce holds the completed one-attempt runner; avoid incidental pushes. Master/integration/release untouched. Natural broad CI39441551075 is separate, not a result of the focused journey and not audited here. No delivery or speedup acceptance.
