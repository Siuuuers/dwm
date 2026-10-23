# Contacts presentation component

The subsequent desktop-shell milestone places this app at `(480,64,800,656)`
under one shared Home/title/clock strip. Its inherited local title bar is hidden.
See `scripts/ui/desktop/README.md` and `evidence/desktop_shell/` for current shell
verification; the earlier `contacts_integration` receipt remains historical.

This implementation follows the accepted visual direction from the typography studies: paper incoming slips, narrower plum outgoing slips, pixel frames and identity marks, a 12 native-equivalent pixel text baseline, and 100/125/150 percent text presets. It is reusable source, not a separate preview app. It has no story, persistence, or network dependency; touch gestures use the input-custody contract described below.

Original component task: `dwm-dro`. The isolated worktree starts at `1790785bcfd37d2a27a0ecef81b9dc80fe501f71`. The game `ContactListApp` now embeds this component, and the desktop mounts it through the existing app registry. Bootstrap injects a presentation adapter using its retained command and desktop owners. UI-00/UI-00R plans are reference material under the owner's September 5 direction.

## Host contract

Create a `Control` using `ContactsPanel.gd`, add it to the scene tree, then call `configure(english_font, simplified_font, traditional_font, text_percent, midnight)`. Supply fonts explicitly; unconfigured projections are rejected. The component is 800 × 656 logical pixels, corresponding to the 400 × 328 native plate at the game's 2× presentation. Place it within a suitable host; parent DPI/window scaling remains external.

Connect `open_requested(friend_id)` to the transaction owner. Clicking or activating a row emits that signal and never changes Selected, Unread, or transcript contents by itself. `back_requested` lets the host close/return when Back is pressed on a row.

Touch rows bind the existing `/root/InputManager` contact/custody owner; an
isolated host can supply the same contract with `row.bind_input_custody(owner)`.
A short tap opens once. Holding for 500 ms shows the existing quiet inspection
mark and public accessibility description through row focus; release does not
open or mark the thread read. Dragging more than 8 logical pixels, another touch,
focus loss, hiding, Pause or custody loss cancels the gesture. A later fresh tap
works after release. Touch is unavailable without this input owner; native mouse,
keyboard, controller and assistive Button activation retain their existing path.
Engine-routed verification is in `evidence/contacts_touch/README.md`.

After an accepted owner transaction, call:

```gdscript
var entries: Array[Dictionary] = [{
    "id": "stable-entry-id",
    "outgoing": false,
    "texts": {"en": "Approved English text", "zh-HK": "已審閱的譯文"},
    "timestamp": "12:00", # Optional authored HH:MM; illustrative, not story data.
}]
var accepted: bool = panel.set_projection(
    "priscilla", entries,
    {"priscilla": false, "lavinia": true, "sylvia": false},
    "en", "zh-HK"
)
```

The example wording and time are placeholders demonstrating the API; do not ship them as correspondence. The owner supplies only entries already admitted for display. Held incoming messages must stay outside this array. A selected row may remain Unread while its visible transcript is unchanged.

Supported friend IDs are `priscilla`, `lavinia`, and `sylvia`; supported locale IDs are `en`, `zh-CN`, and `zh-HK`. Empty secondary locale disables dual text. Empty friend with an empty entries array returns to the blank pane. Message ordering follows the supplied array; timestamps never sort it. Entries have unique nonempty string IDs, a boolean direction, and nonempty plain strings for each requested locale. Optional times require ASCII `HH:MM` within 00:00–23:59. Unread values are binary booleans.

Invalid configuration/projection returns `false` before changing the previous valid view. The component copies supplied data. It uses plain `Label` text, so markup-like strings remain literal. Missing translations are rejected atomically rather than replaced by unreviewed fallback policy. The owner must resolve fallback before projection.

## Focus and reading

Fresh entry focuses Priscilla with a bare right pane. A newly selected friend focuses its transcript. Presentation refreshes preserve meaningful row/transcript focus; relayout retains the visible entry ID plus its pixel offset. Scroll position is transient UI state, not save data or a witness receipt.

Mouse wheel scrolling is supplied by `ScrollContainer`; keyboard/controller directional input scrolls the focused transcript. Home, End, Page Up and Page Down are supported. Left/Back returns to the selected row without clearing selection. One noninteractive foreground layer draws truthful continuation cuts. Rows keep Focus, Selected, Unread, identity, Hover, and Press separate.

The row allocation uses the 48 native pixel proposal from the prior focus study. Theme changes refresh existing text and incoming border colours. The font baseline is 24 logical pixels (30 and 36 at larger presets); it is not a claim that all nominal font sizes have identical visible ink dimensions.

## Verification and ablation

Run from this worktree:

```text
python tools/contacts_component/verify.py
```

The runner creates a fresh miniature Godot project containing only the component, its fonts, and tests. It uses isolated APPDATA/LOCALAPPDATA and no game autoloads. Set `GODOT_CONSOLE_PATH` to override the installed Godot 4.6.3 executable. Results and source hashes are written to `evidence/contacts_component/result.json`; that record points to the full log in `.godot/`.

Tests cover fresh state, request-versus-commit semantics, invalid/duplicate inputs, caller data ownership, literal markup, selected+unread preservation, long multilingual layout, scroll reachability, entry anchoring, controller input, and focus races during immediate configuration/projection updates. Review-discovered bugs were reproduced with failing tests before correction.

The bounded ablation compares normal reflow with a two-line visibility cap, then restores reflow. At 150%, the cap hides 72 of 80 fixture lines; normal/restored reflow hides none. The cap does not reduce the measured layout height, so this is a text-visibility ablation, not a performance benchmark or an implementation of a fixed-height container. Keep reflow; do not add production ablation flags.

The sandbox cannot read the Windows root certificate store. The runner retains that exact engine diagnostic and excludes it from failure classification because these tests do not use network/TLS. Every other engine error and any failed completion marker fails verification.

## Integration boundary

`ContactsPresentationPort` projects detached canonical records and binary Unread, including an unopened linked offer. Available invitation opens use the existing issuer-backed command port. An authenticated pure preview verifies required text for every affected thread before the real open commits. Empty/history navigation creates no acceptance or read receipt. Group replies use the existing reply command; the app supplies a keyboard-accessible operational button.

There is no final production correspondence catalog in this checkout. Bootstrap deliberately supplies an empty catalog; live empty threads render normally, and unresolved correspondence shows a neutral technical notice before any invitation is consumed. Test catalogs contain explicitly synthetic text. The four documentary audition lines were not promoted into game content. General durable reading of historical follow-ups also has no existing owner command: merely viewing them preserves Unread. Do not fake an invitation acceptance to clear it. Witness tracking, authored group timestamps, session boundaries, outgoing acceptance prose, and complete correspondence authoring remain outside this UI wiring.

The persistent desktop owner retains a weak reference to the scene through an eviction adapter. Leaving the desktop destroys its visual cache without leaving an invalid callback; returning or restoring active Contacts mounts a fresh pane. Back restores launcher focus, and ordinary hide/reopen preserves the local view. Other desktop app transitions, including live Minesweeper board transitions, are not implemented by this Contacts slice.

Focused checks:

```text
python tools/contacts_shell/verify.py
python tests/contacts_presentation/verify.py
python tests/contacts_presentation/verify_real_owner.py
```

The shell suite loads the real UI scenes with external port fixtures. Presentation tests use the real domain and identity issuer; real-owner tests additionally load actual GameState and Bootstrap methods with isolated, manually configured services. See [the independent review](INTEGRATION-REVIEW.md). These checks do not claim full application startup, GPU rendering, screen-reader conformance, full Windows DPI coverage, controller hardware parity, or installation into another checkout. No source archives, recovery registry entries, commits, or destination refs are changed by this integration.

Original Source Sans 3 and Source Han Sans SC/HC font files and complete OFL licenses are under `assets/ui/contacts/fonts`. They permit commercial bundling subject to their retained license conditions. `Source` is a Reserved Font Name; the files are unmodified. The source manifest records the exact downloaded bytes; shipping package/version selection remains an integration decision.
