---
id: spec.desktop_divider_and_touch_focus_amendment
kind: design_amendment
schema_version: 1
amends: spec.main_menu_desktop_shell_global_chrome_ui_ux_amendment
amends_path: "docs/design/2026-08-12-main-menu-desktop-shell-global-chrome-ui-ux-amendment.md"
decision_status: accepted
written_spec_status: reviewed
written_spec_review_basis: owner_feature_request_and_delegated_layout_judgment
implementation_requested: true
implementation_authorized: true
implementation_status: partial
beads: dwm-01b
created_on: "2026-09-15"
scope: ["in_run_desktop_divider", "touch_sequential_focus", "desktop_strip_placement"]
---

# Desktop divider and touch focus

The owner requested a draggable boundary between Angela and the app panel,
keeping Angela's current width as the maximum, and touch controls that move
focus before a separate confirmation. The owner then questioned the extra
Up/Down controls. This increment uses Previous, Next, and Confirm. Previous
and Next follow logical focus order, including vertically arranged controls;
they do not replace spatial board input.

At the 1280×720 logical stage, Angela ranges from 320 to 480 pixels and starts
at 480 on each main-scene mount. The computer receives the remaining width,
800–960 pixels. The separator consumes no layout width. Its 64-pixel central
touch handle stays wholly on Angela's side, so it cannot cover app controls.
Mouse/touch dragging and focused Left/Right/Home/End adjust the width without
remounting an app or changing gameplay. No save or preference field is added.

The host-selected layout moves the existing 64-pixel Home/title/clock strip
to the bottom, adding the three compact controls there. This is delegated
layout judgment, not a separately answered owner placement preference; the
optional placement question was still unanswered at implementation time.
It preserves the authored 656-pixel app height without shrinking text or
adding a second page scroll layer. Launcher positions, notifications, and
quick-status regions move with their workfield. This narrowly supersedes the
fixed 480/800 division and top-strip coordinates in the earlier shell design;
its other behavior remains in force. Existing Home Down-to-first links remain
wrap navigation, with Home Up also entering the current app.

The touch controls have localized accessible names/tooltips and stay outside
keyboard focus traversal. A first tap restores missing focus without acting.
Confirm requires the same admitted scope and focused control through release
and dispatch; canceled, moved, stale, or interrupted contacts do not activate.
Confirmation uses paired Enter input through the ordinary viewport pipeline,
including real modal custody and the existing board's keyboard handler.

Contacts, Settings, and Backup now use the full 800–960-pixel app width.
Their left contact/category/save-slot areas keep their existing dimensions;
the extra width expands the reading or information pane. Text sizes, app
height, active controls, and pending actions stay unchanged. Resizing does
not remount apps, refresh gameplay projections, or save preferences. Backup's
title-login layout retains its fixed 800-pixel canvas and existing inset.

**Implementation boundary:** Shop and Schedule still need app-body reflow,
with concurrent edits recorded in Beads. The Minesweeper layout remains
separately owned and is outside this goal's required completion.
This amendment does not authorize changes to `dwm-634*` or `dwm-6fl` owned
source, tests, gameplay, schemas, persistence, branches, or worktrees.

Verification lives in `tests/desktop_shell/test_desktop_split_touch.gd`,
`tests/unit/test_desktop_panel_split.gd`, and
`tests/unit/test_desktop_touch_navigation.gd`. Geometry checks include English,
Simplified Chinese, and Traditional Chinese at 100%, 125%, and 150% text,
along with existing desktop-shell coverage. Native render evidence is a
layout observation, not proof of physical touchscreen hardware behavior.
