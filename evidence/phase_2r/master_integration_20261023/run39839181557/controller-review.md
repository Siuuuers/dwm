# Restore qualification controller review

Static review accepts template SHA256 `2f664dba852b38d9e3022702fb6451cdb0809b93b88c41b973f392f654eceab0` subject to replacing both source/tree placeholders with the reviewed one-test-change candidate and verifying those exact pins before dispatch. This template is not dispatch-ready while placeholders remain.

YAML parses and both embedded Python blocks compile. Canonical isolated runner supports comma-separated -gtest paths and TimeoutSeconds; selected original suites contain5 restore cases plus3 live-run cases. Source-derived XML census requires exactly their full testcase multiset, positive assertions/pass statuses, no failures/errors/skips, and both exact six-direction control completion markers once each. Thus an early return in a provenance test cannot silently supply the required control marker.

One combined original-suite isolated execution plus four inventory generate/check executions plus one public-surfaces execution gives the expected6 clean exits. Import exit/log checks, core.autocrlf=false, project restore, official Godot checksum, bounded tracked/untracked source guards, generated inventory delta reporting and required-contract source retention remain intact.

The workflow retains original XML/logs, tested source copies, provenance refs, raw owner, generated inventories and hashes even on failure. Artifact upload includes hidden files and uses read-only permissions. There is no product publication or broad-workflow replacement. Stage timeout480seconds remains below its10minute step ceiling; failure must remain failure rather than cause an unchanged automatic retry.

No blocking mismatch found in the template. Qualification must wait for the concrete canonical failure as planned, then use the exact pinned candidate. After success, review generated inventories for only expected source-line movement before integration; the focused result is not broad CI or scene-wide restore acceptance. No engine/PowerShell execution by this review.
