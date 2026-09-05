# Desktop shell verification

Run `python tools/desktop_shell/verify.py` from this worktree. The runner creates a
disposable project containing real MainGameScene, ComputerDesktop, Contacts,
their scene/script dependencies, and the bundled fonts. No game autoloads or
player persistence run. The Contacts suite is imported only for its external
owner fixture classes; its old standalone scene assertions are not executed.
One cross-app test explicitly initializes real ProfileManager and
LocalizationManager scripts with their real mutation gate and in-memory
FakeFileOps. It opens the actual Settings scene/controller and verifies that
Home navigation reconnects to cached Contacts after visiting Settings.

The suite checks:

- Seven 176x176 launchers in registry order, four columns, 24px inset and 16px
  gutters; no eighth target; directional and Tab navigation never wrap or activate.
- Complete caption glyphs and layout in English, Simplified Chinese, and
  Traditional Chinese at 100%, 125%, and 150% text.
- Shared strip geometry inside the actual 1280x720 main scene, with a fixed
  noninteractive HH:MM clock, equal digit advances, honest unavailable state,
  suspension while the app lacks focus, and no gameplay writes.
- Contacts content at 800x656 below the shared 64px strip, without a second bar.
- Home/Back/focus routing, cached transcript/reply focus, failed friend/app actions, unavailable
  Settings without its dependencies, day eviction, and restored active Contacts.
- Unsupported restored app state remains visible as an unavailable app, with its
  actual title and owner ID preserved; disabled Home does not claim Current.

The initial red run caught the six missing desktop APIs/properties. The completed
suite also caught a 150% English Minesweeper caption extending three pixels beyond
its launcher cell. Production changes corrected that layout.

Each run preserves its log and hashes of the exact copied files under
`.godot/desktop-shell-*`. Only the known Windows root-certificate diagnostic is
allowed, with its original text retained. Other engine errors fail verification.
The latest portable receipt and full log are copied to
`tools/desktop_shell/evidence/`. Observed Unicode parsing diagnostics from the
real-manager setup are also recorded explicitly in the receipt, without being
filtered out or described as a clean log.
Headless Windows begins with a 64x64 window, so the suite explicitly establishes
the game's 1280x720 logical viewport before measuring layout.

This verifies headless layout and interaction, plus actual Settings/Contacts
cross-app routing with the dependencies described above. It does not prove GPU
rendering, real Bootstrap/GameState transactions, or all other app content.
Existing Contacts tests and production files are not modified by this verifier.
