# TEST title-to-scene milestone — 15 October 2026

User selected TEST startup and replaceable content, not production story selection.
PR #35 is the product change; PR #30 remains the separate cloud controller.
Master remains 0c8b2384415d71bd3de4ff7408640bbf60b63740.

## Accepted source and cloud evidence

- Candidate: d922f51e0330f56c9018c2544b90b2594c65aa80.
- Complete tested tree: 04169661acc6f03a00212de3a5f99aea357f2732.
- Cloud freeze: 5b7bc7f844e04100e3d36c02592b7ea9bd286b1b; its tree exactly equals candidate and local staged tree.
- Controller: 3723be6056831b91e767e4558f0711259a827272.
- [Run 38687431565](https://github.com/Siuuuers/dwm/actions/runs/38687431565), job 116265388168, all steps passed.
- Godot 4.6.3 standard, Windows Actions and isolated PowerShell runner only. No local Godot/PowerShell execution.
- Rendered title journey: 1 test / 106 XML assertions. Existing legacy preparation suite: 10 tests / 261 assertions. No failures, errors or skips.
- Gate checks exact source-derived case names, nonzero assertions, child exit codes, physical proof, source cleanliness and logs.
- Legacy corrupt-autosave case deliberately supplies byte 0xff. Gate requires its exact decode diagnostic once within that named case, rejects all other decode/script/error diagnostics. ANGLE fallback warning is retained.
- [Retained evidence ZIP](../evidence/title_template/accepted-cloud-run94.zip): 158843 bytes, SHA256 54ff1a9e4be8fd91edf7fdeecb6c8b3bfca859212365dd58007fb9811dbcf10a. All 26 manifest members rehashed.
- Actions artifact 11949983640 (scene-title-template-38687431565-1), 159755 bytes; separate artifact package digest 76d19cef65d4bbf867e0a908b3783f309718f7dcf40d90697c6930a29564cf18.

Evidence/report additions after acceptance change no executable or template bytes.

## Behavior and owners

SaveManager selects one installed scene opening through configure_scene_title_new_run.
Existing Menu preparation, Cancel, confirmation, stale-baseline checks and responsive
commit/retry remain authoritative. The existing scene decision builder allocates identity
only after consent and baseline checks. Existing durable intent retains the complete
decision for retry. No second save, history, assignment or recovery owner was introduced.

Title configuration requires registration schema 3: AudioManifest derives canonical
entry audio. The template explicitly registers silence for every entry. Story prose
belongs to tests/fixtures/dialogic/scene_title_template.dtl; Registration.gd derives
caption revisions and programme hashes through the existing compiler. Preserve semantic
IDs/labels for prose edits. Structural edits require corresponding registration changes;
arbitrary rewritten stories do not automatically migrate older saves.

FINAL Bootstrap uses real owners/files with explicitly installed TEST content.
Nine Viewport pointer actions cover fresh New Acc, replacement prompt, Cancel,
stale Start/dismiss, failure Start and Retry. A transparent observer forwards exact
SaveManager calls/results. Initial title navigation and production Pause/Return ports
are test setup, not pointer claims. Return retires the live source without saving;
the replacement case concerns the retained autosave, not an active live session.

Verified: visible template opening; real slot creation; Cancel and stale refusal
preserve Profile, retired live baseline and autosave; one actual autosave write refusal
produces retry-only UI; Retry retains complete original new_run_materials, acknowledges
activation, creates the recorded alternating assignment, reaches Ready exactly twice
overall, and preserves manual slot bytes. Invalid/stale configuration/token paths refuse.

Independent static review found no blocker in the adapter, catalogue, forwarding
observer or retirement setup. Coordinator inspected consent, Retry and final opening
screenshots from the accepted run: controls and caption readable, no GUT overlay.
No whole-game, native OS input, production story, crash restart, arbitrary save migration
or polished-art acceptance. This lane does not separately assert Profile/autosave/live
unchanged at the instant of the injected refusal.

## Earlier attempts remain distinct

- Runs 86/87 were superseded controller setup attempts.
- Run 88 (38685554743): refused non-admitted DTL locator. Moved template into existing TEST locator boundary; validator unchanged.
- Run 89 (38685853555): refused mismatched DTL captions. Derived caption registry from compiler output.
- Run 90 (38686126066): fresh creation timeout; insufficient diagnostics.
- Run 91 (38686440732): observer confirmed invalid_audio_snapshot. Added canonical schema 3 silent catalogue and explicit title schema guard.
- Run 92 (38686809910): fresh opening and slot passed; direct scene-change setup left native overlay intercepting replacement click. Replaced setup with production Pause/Return ports.
- Run 93 (38687104901): both suites passed (106 + 261), but workflow gate failed on deliberate legacy corrupt-byte diagnostic. Narrowly corrected controller rule; candidate unchanged.
- Run 94 above is the fully passing acceptance. Failed attempts are not counted as passes.

## Continuation

This bounded TEST startup milestone is complete. Production content selection remains
an explicit future decision. Do not redo accepted Contacts/audio work or infer combined
whole-runtime acceptance. Future story work starts with the template README and the
specific authored transition/identity changes, preserving existing compatibility rules.
