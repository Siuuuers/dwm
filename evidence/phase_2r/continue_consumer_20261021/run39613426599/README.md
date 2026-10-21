# Read-only consumer attempt 39613426599 — failed before attachment

## Result
Official Windows Godot4.6.3-standard attempt1/job119268012351 failed. The new reader failed in its receipt replacement before engine identity resolution and before FromHandle/FindAll. This is a concrete harness defect; the attempt does not test whether timely successful UIA discovery enables Continue registration.

Controller1caf3f2c95ac1e7817d22eebd314c0bd725bef94; source1ee15f07b315fa762495a6bb93d07d91201ae600; helpercd5d74f7bc72322dbb48e1592900552f757b3956. C6317665215 clearance and Director6317374204 authorized one attempt, now consumed. Active controller rechecked unchanged. No retry or runtime/product/master/integration mutation.

## Observed evidence
- Cloud checkout/pins, PowerShell syntax parsing, official engine install/version, import, before/import/restored/post-tests policies passed. Syntax success does not qualify the reader's Windows PowerShell5 runtime behavior.
- One GUT case,16/17 assertions,1 failure,child exit1: Continue did not register a native action for reveal1. JUnit root/suite/failure-element counts agree at1.
- All11 boundaries retained; no SCRIPT ERROR in focused Godot log. Same Continue492914608802/layout491824089715. Projection requests/returns3 and retirement requests/returns8; notification/element/admission/capture/action-registration counts0.
- Reader PID1100 launched; supplied launcher binding PID3172. These are supplied/owned identities, NOT a verified engine binding. Reader identity/HWND and all attachment/discovery timestamps remain null.
- Main consumer-reader.json remains status starting with only reader_start. consumer-reader.json.tmp records status failed, error: Exception calling "Replace" with "3" argument(s): "The path is not of a legal form."
- Exact source Save-ReaderEvent writes the temporary file then calls [IO.File]::Replace($temporary, $ReceiptPath, $null) when destination exists. First receipt uses Move and succeeds. Second event identity_start reaches Replace before the identity loop. The catch/finally use the same failing writer; final temporary bytes contain failure and reader_complete, while the published receipt is stale. The invalid-path exception at Replace is established; PowerShell's null-to-string interop is the leading explanation, not independently reproduced here.
- Parent lifecycle: child_exit1,reader_started true,reader_exit1,reader_forced false,error null,cleanup_errors empty. Receipt writer failure prevents a successful reader outcome; neither cleanup nor registration is silently qualified.
- consumer-outcome.json: attachment failed,registration timeout,timing clock_incomparable,qualified false. Do not substitute the temporary receipt into the qualification gate.

## Timing limits
Original deadline remains start ticks10406 +5000 =15406. Start UTC1792591550341ms, projected deadline1792591555341ms; end ticks15417/UTC1792591555353ms. Fixture sampled drift1ms, zero-width sample brackets.
Reader_start is5774ms before window start. Temporary identity_start is2949ms before start; temporary failure2818ms before start; temporary reader_complete2813ms before start. These are raw UTC differences only: main receipt lacks a complete reader clock sequence, so the existing gate correctly refuses comparable attachment timing. There is no attachment/discovery offset to report and no timely-discovery claim. This does not establish backend inactivity or a gameplay cause.

## Preserved originals
Both downloaded ZIPs match GitHub byte counts/SHA256; ZIP CRC checks passed and all member names were checked for absolute/traversal paths.
- focused artifact12350763829:7775 bytes,10 members,SHA256 ac344122e6fe8b436454f597b202da45096b893f89719dfb731aa5852b89b973.
- preparation artifact12352042037:10804771 bytes,5280 members,SHA256 bb347d87153c9d6867499889d3af983bcc04e38d13ea4934f3fda2b3ad516c6f.
Original ZIP bytes are split into166 binary parts under originals/. Concatenate each archive's numerically ordered parts to reproduce its exact ZIP, then verify the above SHA256. parts.json records sizes and verified Git blob hashes for every part. Readable focused receipts (including .tmp), JUnit/log and bounded preparation receipts accompany originals; readable copies decode UTF8 BOM and are convenience views. Original archives are authoritative.
Preparation claims above are based on cloud step results and retained policy receipts; no repeated full independent preparation census or engine run was performed. Previous failed run39604954687 remains preserved in45037563, including the earlier history/discrepancy.

## Proposed next correction and review
Repair only the reader's receipt replacement argument handling in its actual Windows PowerShell5 host, preserving atomic replacement, existing error propagation, process ownership, original5000ms window and read-only UIA behavior. Before another engine attempt, verify repeated publication to an already-existing receipt and terminal failure/completion receipts in the same host; syntax parsing alone missed this defect. Do not weaken the outcome gate or extend/delay the game window to compensate.
C: review actual result and this bounded diagnosis. Director: reconcile that small harness repair and any next cloud validation allowance; no further attempt is assumed. No production workaround, broad/native/export run, merge or release. Registration, known transition latency and exported completion/Title/fresh Load/normal clean exit remain open.

Run: https://github.com/Siuuuers/dwm/actions/runs/39613426599
