# Deadline fixture correction — exact packet for external C review

Authorization: [Director6269458094](https://github.com/Siuuuers/dwm/pull/30#issuecomment-6269458094). Prior result review: [C6269405875](https://github.com/Siuuuers/dwm/pull/36#issuecomment-6269405875).

## Exact pins and change
Source commit `5e07d7075385844edbc77e01276950f186cf1dac`, tree `a5a895c921508cd140e7d17a80de2b58ac5ff3b8`, parent e603b308441481480bdf80e6a9af491f60d54cea.
Rendered controller blob `27271c688466e5c75844b0a411c2d39cbe65effc` in ../controller.yml; NOT installed. Live PR30 remains95b75d6ecce073c1fa11e0da64480b9dbd551477.

Two source files: a diagnostic-local copy of Test-ExportedGameplayDeadline.ps1 plus the existing build_controller.py invocation change. No original game checkout fixture, Wait-One implementation, timing overlay or product runtime is edited.

The copied fixture comes from game81847d8b, original blob436c73a380baec1a3bc6ba64d273ff052e316d78. It explicitly initializes TraceEndingActions=false and script:endingTitleWaitTrace=false. Each negative case retains its caught ErrorRecord and rethrows unexpected errors before the original exact-outcome assertion. No-exception cases still fail the existing assertion. Four case bodies, delays, expected messages and behavioral assertions remain unchanged. [Exact fixture diff](fixture.patch).

Controller invokes the pinned isolated fixture from TITLE_TOOLS and copies it into .godot/ci/deadline-fixture.ps1 before execution so the cloud evidence retains the actual fixture. DriverPath, OutputPath and failure gate remain unchanged. YAML comparison confirms only two tool-source pins and this fixture-copy/invocation differ from e406ba7c; all other values match.

## Dependency audit and validation
Independent internal source review found no blocker. With false TraceDay5/NativeReadyCaptions/TraceEndingActions flags, remaining native/trace dependencies (child, native observation state, Record-EndingTiming) are unreachable. Window/Record/Require and ordinary shared state are supplied by the fixture; local variables are assigned before use. Both new flag defaults are explicit.

No local PowerShell/Godot execution. This is source/preparation validation, not a reproduced hidden exception or a passing Windows fixture. The prior28 Windows Python tests are unchanged and not repeated locally. Cloud still runs them and the corrected fixture before import/export/smoke/player. Four existing fixture cases must pass; unexpected failures now preserve their cause.

The first local controller-render command used the wrong staging directory and stopped on missing reference windows-tests.yml; rendering from the existing complete packet layout succeeded. No source edit was needed and no cloud event occurred from this preparation.

## Review/continuation contract
External C must review this exact delta and refreshed pins, reusing prior reviews for unchanged source. No additional Director confirmation is needed after no blocker. Reconcile current heads/live and queued runs/artifact12184205891 availability before controller installation. Never duplicate or cancel an active diagnostic.

Director6269458094 supersedes the former one-attempt cap only for directly evidenced preparation/fixture setup defects within this same isolated task, with exact delta review and original failures retained. Do not weaken assertions, alter driver/gameplay semantics or30s/480s, add instrumentation lanes, rebuild engine, repeat Baseline or completed campaigns. Materially different problems must be reported. Stop after the first actual bounded timing journey and retained phase/deadline analysis, or a substantive import/export/smoke/runtime blocker.

Original run39266748914 and39262225003 failures and paired Load failures remain unchanged. Official exported completion/clean exit remains open. No merge/release/master/integration movement.
