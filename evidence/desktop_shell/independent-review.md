# Desktop shell foundation — independent review

**Source review: no remaining material finding in this milestone.** Reviewed the
current isolated implementation against the milestone plan and root Shared Shell
sections 4, 7, 8, 10, and 14. Historical recovery procedures were not treated as
implementation gates. This review writes no production changes.

## Findings resolved

- Contacts caches semantic focus roles rather than references to transcript or
  reply nodes that projection rebuilds. Visible focus changes are remembered
  before clicking Home moves focus outside the app. Reopening reprojects current
  state and restores valid row, transcript, or reply focus without replaying an
  open/read command.
- Every successful app publication rebinds Home navigation to the active app.
  Settings links Home in both directions, returns to its root on one Back and
  Home on a later Back, and rejects Home while a popup or confirmation is open.
- Launcher geometry and order remain fixed, with seven real targets and no eighth
  target. Arrow navigation uses real neighbors; Tab endpoints do not wrap.
  Contacts and Settings occupy the content below the shared strip with their
  inherited bars hidden.
- Unsupported direct launches reject before host mutation. An unsupported restored
  destination retains its actual title and owner identity, hides the launcher,
  and shows factual unavailability. Its view still receives owner-driven eviction.
  Home's Current appearance is now independent of its Disabled state, so a failed
  restored app does not falsely paint Home as current.
- Routine clock readings validate hours, minutes, and seconds. Invalid data renders
  `--:--` with localized capability text. Foreground eligibility is initialized
  from the window and maintained on focus transitions; an unfocused view neither
  reads the adapter nor schedules another tick. Home uses a drawn pixel pictogram
  rather than relying on a locale font containing a house glyph.
- The retired tutorial entry is no longer instantiated by MainGameScene. Existing
  owners continue to supply Contacts transactions and Settings preferences.

## Evidence readback

`.godot/desktop-settings-ypvbt8ix/result.json` reports a passing real Settings
scene/controller/ProfileManager/LocalizationManager fixture with fake storage;
all 31 recorded source bindings matched during review. Receipt SHA-256:
`d384cbcdb60bfab6e48f2245b960e4552cebdf6dd304f77ee84970fba45de7c2`.

`.godot/desktop-shell-2t4vlp1d/result.json` reports passing headless shell checks:
nine locale/text-size layouts, actual Settings hosting with memory storage,
Contacts focus/cache, Home rebinding, failure/day/restore behavior, clock validation
and foreground handling, tabular clock digits, and no-wrap navigation. Receipt
SHA-256: `b978d9bca55411e221f261a9d3fafb278cbde4a1bf53c628bc985865b9fa242d`.
All 71 recorded source bindings match, including the final Home Current/Disabled
separation. Contacts projection and desktop host are fakes in this suite;
Settings uses the real controller, ProfileManager and LocalizationManager with
explicit fixture initialization, a shared mutation gate, and memory storage.

Two additional passing receipts were independently read back against current
files: `.godot/contacts-shell-vg2i8rzc/result.json` matches all 51 source bindings
(SHA-256 `3c0f74ee5c7ecc7f6ee7906256b239ef4824094cf1cfc7f345d532c0fc09fca8`),
and `.godot/contacts-real-owner-cglifgva/result.json` matches all 139 bindings
(SHA-256 `a29143285a3d527263d3b96c885de0a5d8ce544242467591e449f83f3c24903a`).
The former covers real Contacts/shared-shell scenes with fake application ports;
the latter covers real GameState preview/commit and Bootstrap configuration under
manual fixture startup, including failed restored-view eviction. No final tested
source delta remains in these receipts. Inherited certificate/NUL diagnostics
remain disclosed, not filtered or relabeled as a clean engine log. This reviewer
read evidence rather than rerunning Godot.

## Scope limits

This is the desktop foundation, not the entire Shared Shell or UI-00R. Only
Contacts and existing Settings controls are supported destinations. The five
other launcher operations retain truthful unavailable behavior until their real
adapters exist. Their app internals and full startup were not implemented or
certified here.

Production Contacts correspondence remains absent; test prose is not promoted
to game content. General history/follow-up read and witnessed-presentation
ownership remain incomplete. The existing Settings continuous font preference
and the shell's three rendered presets are not a completed Settings design.
GPU rendering, full Windows display scaling, hardware accessibility, Pause and
other global overlays, and the anomalous clock allocation remain outside this
milestone's proof. Standard palette mappings remain provisional.
