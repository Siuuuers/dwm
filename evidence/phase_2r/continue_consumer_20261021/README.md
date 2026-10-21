# Read-only UIA consumer prerequisite — exact candidate for C

Prepared under Director PR30 comment6317374204, consuming C6317336957. Prior run39604954687 remains FAILED; its recorder repair/result/archive review is closed and reused. This packet is inert, not cloud qualification.

## One observable outcome and ownership

The single initial-registration fixture has a real read-only Windows UIA consumer attached to its own launched engine, while the real Continue handler independently publishes its action. The existing isolation helper owns both child processes; the reader owns only discovery references/receipts. Existing production Continue/WitnessedAcceptInput remain registration/custody owners.

No action invocation, focus/input/wheel operation, forced notification/update, substituted capture, delayed mount, registration-dependent attachment or deadline reset. No organic/manual completion, remaining seven cases, native journey or export.

## Exact source and pins

Source1ee15f07b315fa762495a6bb93d07d91201ae600; tree32cc2fc6018c2cf1f6f2bf778765567fe43a5839; parent2def8cd137ee72b78a41414a34d40bd4b7384576.
Four files:
- tools/testing/Read-ContinueAccessibility.ps1 (new): identity-bound read-only consumer.
- tools/testing/Invoke-IsolatedGodot.ps1: narrowly opt-in reader ownership, receipts and cleanup; proof child remains unchanged.
- tools/testing/Invoke-ContinuePublicationChecks.ps1: opt in, separate outcomes and deadline comparison before existing failure propagation.
- tests/manual/test_continue_reveal_publication.gd: comparable clock receipts only. Existing recorder and original5000ms expression/poll/order retained.

Helpercd5d74f7bc72322dbb48e1592900552f757b3956, parent9febfa24f6eae5c4250ca8f5dad484181a0ce945, SHA256c52a62f68ea3ea61d1fe8be90d431f5640182424b8e62c3b3c1f783880841eb7. Only PRODUCT pin changes.
Runtime blob4f0f81b8f8f0c02a4bc7ed06909d9be840fc1ab0 was fetched and verified unchanged.
Capture helper remainsa04a8560ea2ac7e8ff77d6bb3e3ffe8d1404193f5e1de2a71676332403fe7379; preparation/custody/generated-input policies unchanged.
Inert consumer-controller.yml SHA256895568de017d7faf3f2274f07654a6bae774a0597888f20b6054acbe27696e3f: only four source/helper pin substitutions plus addition of the new reader to existing PowerShell syntax parsing. Active controller8e6cb51cd521b6fbbf093b660fd6ba945116c388 is NOT replaced.
hashes.json records all candidate file bytes/SHA256. Published source/helper bytes re-read equal.

## Construction, identity and reader lifetime

After the existing owner starts the console child and begins draining stdout/stderr, it writes a binding for that launched PID/start ticks/executable/exact arguments, then starts a separate Windows PowerShell reader concurrently. It does not wait for reader readiness and the engine receives no attachment command or readiness barrier. This preserves natural mounting and exposes late reader startup.

Reader verifies the live launcher PID plus native Process.StartTime ticks and executable. It considers only immediate children of this launcher, refusing ambiguity and wrong executable/argv. The engine native start ticks must not predate the launcher; exact CIM creation/native-start/executable/commandline/parent identity is bound and rechecked. CommandLineToArgvW argument comparison reuses existing native helper logic. CIM timestamp precision is not used for native start ordering.

MainWindowHandle is accepted only from that bound engine and checked with GetWindowThreadProcessId, UIA Current.ProcessId and a repeat process/window identity check before descendant discovery. No arbitrary desktop scan; no wait for Continue/registration. UIA calls are ONLY FromHandle and FindAll(Descendants,TrueCondition); no pattern invocation or geometry/focus mutation. The objects remain referenced until engine exit or owning helper stop.

Reader emits atomic receipts before potentially blocking FromHandle/FindAll. Parent owns the120s child watchdog and records child exit independently; after child completion it signals reader stop, waits5s, then terminates a stuck reader with explicit forced-cleanup failure. Exceptional cleanup attempts both owned processes and records errors. A stuck UIA call cannot silently qualify. Reader has its own120s polling lifetime. No reader is started for the user-directory proof or other suites; opt-in is restricted to this rendered, single-case suite/evidence path with no sequential children.

## Timing and separate outcomes

The original fixture deadline remains Time.get_ticks_msec()+5000, created at the same point before the unchanged loop. Immediately afterward, UTC Unix milliseconds are bracketed by monotonic before/after ticks; final snapshot captures the same bracket. No file wait, sleep, reader handshake or mount delay is introduced.

Reader records UTC Unix milliseconds plus Stopwatch elapsed for reader start, identity, attachment start/return, discovery start/success, stop/failure/completion. These use the same machine system UTC as Godot. Consumer outcome computes discovery start/completion relative to the fixture start and an earliest/latest UTC deadline derived from the bracket. This is comparable-clock evidence, not a claim that wall clocks cannot change.

Reject timing if fixture start/end UTC-minus-monotonic offsets drift by >10ms, either sample bracket exceeds10ms, or reader UTC deltas differ from its Stopwatch deltas by >10ms across any event from reader_start through reader_complete. Reader coverage includes discovery that completes before fixture start. A conservative12ms margin around the bracketed deadline classifies boundary ambiguity separately; it does not extend the test. Missing/incomplete clock evidence remains unqualified.

Receipts distinguish:
- exact identity errors/stale/ambiguous processes or HWND;
- discovery failed/unobserved versus discovered;
- timely, late, boundary-ambiguous, clock-incomparable or unavailable timing;
- actual registration timeout/success from the game snapshot;
- original child exit, reader exit, forced termination and cleanup errors.

Discovery remains recorded even if later reader cleanup fails. Qualification requires child exit0, real initial_registration_observed, discovered/timely reader, normal reader exit0 and no forced cleanup/error. Original nonzero child exit is propagated before any success gate. FromHandle/discovery do not themselves prove callback delivery or adapter-inactivity causality.

## Review and limits

Internal independent static audit found no remaining blocker after separate discovery/cleanup status and whole-reader clock-consistency corrections. Static exact-delta check confirms fixture adds clock receipts only; reader has exactly one FromHandle and one FindAll and no action/input imports. Python helper AST and controller YAML parse; all four published files and helper re-read equal. No local PowerShell/Godot or Windows parser execution. Windows runtime, provider activation, scheduling and cleanup remain unqualified until cloud evidence; parser execution is included in the reviewed controller.

C must review exact source/helper/controller, identity/lifetime/timing/nonmanufacture semantics. Reuse closed recorder/source/preparation/archive reviews; this internal audit does not substitute external C clearance.

After C clears this exact packet, Director6317374204 authorizes ONE official Windows Godot4.6.3-standard first-case attempt. A immediately rechecks controller8e6cb51c and active runs, uses expected-head protection, posts launch and may pause. No further user/Director confirmation, automatic retry or broader lane. If timely discovery still yields failure, report that outcome instead of assuming inactive adapter. Product/master/integration unchanged; no export/merge/release.
