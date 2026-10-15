# TEST title-to-scene content template

This is engineering placeholder content, not selected production story.

- `tests/fixtures/dialogic/scene_title_template.dtl`: replace the visible English caption prose here.
- `Registration.gd`: selects the opening target and recompiles the DTL through the existing registration owner. It inherits the established TEST scene/Challenge registration, then derives caption text/revision from compiled DTL and recomputes content/program hashes and target hashes for this file.
- `tests/integration/test_scene_title_template.gd`: installs this registration before FINAL Bootstrap, configures the title opening through SaveManager, and clicks the actual title/confirmation controls. Registration selection and returning to the title are explicit test setup, not player-input claims.

Preserve `#id:` identifiers, entry labels and control-marker labels for prose-only changes. If entries, transitions, Challenge boundaries, Contacts or line identities change, update their registration together. Do not hand-edit hashes or suppress registration validation. The current template inherits a Challenge and destination/Contact placeholders, but this new lane accepts the title opening only; it does not claim a newly tested full story.

The test currently checks the literal opening caption; update that expectation when deliberately replacing its prose. It is deliberately clear that a different visible opening was loaded.

The initial target is `OPENING_TARGET`. It must name an installed scene target. The trusted application configuration calls `SaveManager.configure_scene_title_new_run` once. The normal Menu retains its existing prepare, confirmation, cancel, commit and retry flow. Nothing changes the normal production content selection or introduces a second save or history owner.

Content replacements change registration identity. Existing saves must remain intact and follow existing compatibility/refusal policy; this template does not make old saves compatible with arbitrary rewritten story structure. Do not promise automatic migration.

Run this lane through the pinned Windows cloud controller, Godot 4.6.3 standard and the existing isolated PowerShell runner. No local Godot/PowerShell execution is required.
