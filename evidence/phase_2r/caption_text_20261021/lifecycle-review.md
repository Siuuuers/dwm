# Continue reveal-completion lifecycle correction

Candidate: 958ab5e072ef76b9c6467937a4b6ca3c7849382c on codex/a-caption-text-20261021, parent 099f3de88a97d1ec0e506b4e683841d08784a4d8.
Addresses C PR36 comment6308201477 (relay PR30 comment6308203029). Initial design/report remains historical below its original pin.

Observable outcome: after organic or manual caption reveal finishes, the existing Continue surface publishes an action for the new reveal lifetime. The previously published action refuses; the replacement advances once through the existing ordinary input owner.

Production delta: WitnessedAcceptInput.bind connects finished_revealing_text to existing _retire_accessibility_accept. The signal fires after Dialogic increments reveal generation. Retirement refreshes Continue through the existing owner. No new identity state, polling refresh, command path, save/history change or visible control. Manual finish can also retire through its existing path; duplicate refresh scheduling is harmless.

Regression specification: tests/manual/test_continue_reveal_publication.gd extends the existing real Dialogic integration fixture. Run only the two test_continue_registered_* methods in official rendered Windows Godot4.6.3 standard with --accessibility always. A subclass on the same BackgroundInput records the callable returned during the production accessibility notification. Tests never inject that notification or call a fresh capture helper. Organic completion resumes the actual typewriter and waits for its finished signal; manual completion calls the originally registered action. Both retain surface, label, focus, target and geometry, require a replacement registration, await the original input block naturally, reject the old callback and call the replacement twice to require one advancement with the successor still revealing.

Limits: stored registered callables are invoked by the test, not by Windows UIA. This checks the registration boundary, not UIA traversal/Invoke, spoken announcements or exported gameplay. The manual-directory test inherits other integration methods; the eventual runner must select the two named cases explicitly. No revised controller is installed or dispatch-ready.

Verification: independent exact-file static review found no blocking syntax/fixture issue. Incorporated the review suggestion to wait on _finished rather than a transient revealing flag. No Godot/PowerShell execution and no runtime pass claimed. Full native qualification still needs the separately reviewed actual Text + same-story Continue two-object contract; global name-only Continue matching is forbidden. Earlier failure run39476916285 remains failed and consumed.

Next: C reviews this exact correction and registration test. A then completes the separately reviewed native driver/controller contract before authorized cloud qualification. Product PR36 c8358870 and PR30 controller4a902667 are unchanged; no merge/release/master/integration movement.

