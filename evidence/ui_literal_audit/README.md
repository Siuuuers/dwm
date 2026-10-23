# UI literal audit and Ending recovery

This 2026-09-14 checkpoint starts at `d064c59bb610d7defa24beb5a42956bde55abd07`
and advances `dwm-vky.15`. It does not close that Bead or the broader goal.

The literal audit previously stopped at the first unowned desktop placeholder.
It now records every scanned source, including sources with no matching sinks,
and writes both complete disposition reports before returning failure for
unclassified literals. Authenticated scene bindings check catalog keys and
format parameters; explicit presenter records identify current runtime owners.
Script scanning covers direct and receiver properties, accessibility copy,
multiline expressions, and later text arguments. Comments and quoted examples
cannot authenticate an owner. Trusted helper arguments are separated from
untranslated sibling fallback text. Negative fixtures exercise these boundaries.

This remains a source-pattern audit, not a GDScript compiler or arbitrary dataflow
proof. Path-specific helpers and exact presenter expressions are declared trust
boundaries. The localization bundle validator checks catalog consistency.

The audit exposed an independent Ending UI defect. Normal playback no longer
adds an Ending heading or Return button. A recovery request projects two new
registered strings atomically in English, Simplified Chinese, and Traditional
Chinese. Locale changes preserve the pending command/completion and retire held
input. The centered panel follows current text-size, target-size, contrast and
colour preferences. Its clean material has no fictional week tint. Layer 2 places
it above the current Dialogic layer-1 composition. Initial recovery focuses Retry.
The existing guarded transport button handles physical and native activation;
ordinary `Button.pressed` cannot submit Retry. Ending progression is unchanged.

## Verification

| Evidence | Result and scope |
| --- | --- |
| `ui-literal-index-green` | 17/17 audit tests, 162 assertions, on the final auditor |
| `ending-recovery-focus-green` | 9/9 recovery tests on the final Ending source |
| `ui-literal-final-regression-2` | 102/104 tests, 1,118/1,122 assertions; final Ending source, auditor before the final scanner-only corrections |
| `ending-recovery-main-baseline` | Same two failures on unchanged main at the base commit: 7/9 tests, 155/159 assertions |
| `ui-literal-full-scan-index-complete` | 30 scenes / 51 records / 0 failures; 286 scripts / 268 records / 19 unresolved literals; deliberate exit 1 |
| `ending-recovery-render` | Six 1280x720 captures: recovery and normal-hidden states in three locales at 150% |
| `ending-recovery-native` | One Windows UIA Retry activation and handler entry, zero admitted Button.pressed signals and zero physical contacts |
| `ui-literal-index-tooling` / inventories | Both inventories regenerated; current public contracts unchanged; 14/14 tooling tests, 410 assertions |
| `ui-literal-docs` | 16 packets, 4 design authorities, 1 workflow; archived 23-Bead snapshot |
| `ui-literal-dialogic-contract` | Exit 0; authored Dialogic content contract |

Counts overlap and are not additive. The final scanner corrections affect only
the audit tool and its tests, covered by the final focused tests and complete CLI scan.
The 100 frozen legacy localization records and all pre-existing catalog strings
are unchanged; only two recovery IDs were added in each locale.

The recovery tests use real Profile/Localization owners with memory-backed
storage. One explicit temporary playback-failure fixture proves a physical Enter
press retries the same command and then hides recovery. Other projection fixtures
have no ending ports. Native captures use a synthetic opaque layer-1 underlay;
UIA proves provider activation and handler entry, not a successful save, real
narrative retry, or speech. Root inspected all three localized recovery images
and the normal-state image; no clipping or overlap was visible at 150%.

## Remaining work and diagnostics

All 19 unresolved literals belong to `scripts/ui/DatingScene.gd`: challenge/retry
status, special-mine accessibility copy, and Observer controls. That file overlaps
excluded `dwm-634` ownership and is byte-unchanged. These remain failures rather
than receiving a waiver. `dwm-vky.15` stays in progress with that dependency.

The two broader failures are the exact canonical-label/Gallery runtime test and
the terminal-admission durability fixture. `baseline-regression.txt` contains
their matching signatures, the exact pre-change main control, and older diagnostic
context. They remain unfixed; no whole-suite or whole-game pass is claimed.

Recovery failure classification, universal/modal input custody, and deeper route
recovery are not completed by this presentation fix. The existing host may still
offer Retry for an unrecoverable missing-owner failure. History also awaits an
authoritative session/ordered semantic projection and inspection handle; durable
ownership overlaps excluded work. The ordinary reply-save report still needs a
real diagnostic recurrence. Those dependencies are recorded in their Beads.

The ledger retains every terminal attempt, including RED tests, test-fixture
StringName corrections, script type-inference errors, and the audit decoder error.
The initial layer probe failed to parse and supplied no layer evidence; the later
render does. Logs retain Unicode/NUL warnings and Dialogic orphan observations
(168 in the broad regression). No warning-free or leak-free claim is made.

No excluded Bead, source, branch, worktree, or dirty change is included. Main's
unrelated work is preserved. `source-and-inventory.json` records source hashes
and unchanged overlap files. `runs.jsonl` records exact arguments, isolated roots,
terminal exits, original log hashes, and archived log paths. Text artifacts use LF;
log trailing whitespace is removed without changing raw originals. `SHA256SUMS.txt`
covers the artifacts except this README and itself. Run engines only through
`tools/testing/Invoke-IsolatedGodot.ps1`, serially, with fresh isolated roots.
