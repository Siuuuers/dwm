# Contacts shell integration checks

Run `python tools/contacts_shell/verify.py` from this worktree. The runner copies
the real desktop, Contacts, shared shell, scripts, and fonts into a fresh mini
project. It follows resource and global script class dependencies. It does not
replace production scripts, register game autoloads, or read player data.
APPDATA and LOCALAPPDATA point inside the disposable project.

The test uses small external presentation, preferences, locale, and desktop-owner
fakes to force both successful and rejected actions. It verifies the real scene
mount, initial blank state, no transaction on focus, committed unread/selection,
failed open preservation, long-text scrolling, Home/End, 150% English/Chinese
reflow, regional caption glyph coverage, operational reply failure/success,
Back routing and focus return, cached reopen, and day-reset eviction.
It also verifies focused-reply preservation across font/locale refresh, focus
return after a successful reply, Down navigation to the reply, and visible
technical failure status with retry/Back controls left available.

The actual `MainGameScene.tscn` is instantiated in a 1280x720 logical viewport.
Its production desktop receives an already-active Contacts host state and must
automatically mount a fresh blank app without opening or reading a contact.
At 150% text the measured app is 800x720, its Contacts plate is 800x656, and the
toolbar is 64 pixels high. The app must fit inside the main scene. The suite sets
the root window size explicitly because headless Windows otherwise starts at
64x64 despite the project's display hints.

Every run saves its log and `result.json` under `.godot/contacts-shell-*`.
Hashes describe the copied bytes actually tested, so concurrent authoring cannot
silently change the evidence. The Windows root-certificate diagnostic is retained
and is the sole allowed engine error in this offline sandbox.

Initial red failed because the desktop had no configure/open methods. Subsequent
regressions reproduced a visible window after the host rejected opening, Chinese
launcher captions replaced by question marks, and a reply font missing Chinese
glyphs. Those regressions are now covered by the suite.

This is headless scene integration evidence with synthetic neutral text. It does
not prove production story content, real GameState transactions, Bootstrap startup,
GPU raster quality, or installation in another checkout.
