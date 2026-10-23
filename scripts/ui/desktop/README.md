# Desktop shell foundation

`ComputerDesktop` owns presentation, launcher focus and same-day visual caches.
The retained desktop owner supplies canonical app identity and day eviction.
The existing Bootstrap adapter keeps a weak view reference across scene changes,
including when a restored destination cannot currently be presented.

The 800×720 workspace contains one 64px Home/title/clock strip and an 800×656
content area. The seven 176px launcher targets keep the design's order, 24px
inset and 16px gutters. The eighth position has no node or drawn placeholder.
Arrows and Tab do not wrap. Focus and hover do not activate apps. Each 48px icon
aperture uses an original 24×24 pixel silhouette drawn in code when no optional
authored icon is installed. The seven shapes use the desktop's existing palette;
literal labels and accessible names retain app identity. Contacts draws its
saved unread fact as a separate inert mark, so it cannot wrap onto its own text
line. Enlarged English uses a measured Mine/sweeper break, and the caption band
accommodates Japanese Readable text. Home's Current and Disabled facts remain
independent.

DesktopTheme maps the Standard After-Hours roles to the existing licensed fonts
and 24/30/36 logical-pixel presets. English and both Chinese locales share fixed
geometry; labels wrap inside their cells. This milestone does not calibrate other
palette families or claim full accessibility certification.

Contacts and Settings reuse their existing production owners. They prepare their
view before the host publishes a transition, use the shared strip, and retain
valid local focus on same-day reopen. Contacts remembers semantic focus because
its transcript controls are rebuilt. Settings uses the existing preference/reset
controller inside a scrollable pane; visible popups prevent Home from bypassing
their input custody. This is hosting support, not completion of Settings design.

Minesweeper, Schedule, Shop, Backup and Log out currently return a factual
unavailable result before any host mutation. Their missing adapters are listed in
`evidence/desktop_shell/owner-route-audit.md`. No sample merchandise, simulator
outcomes, fake save rows or unwired Yes controls are presented. Failed restoration
preserves the requested identity and displays a technical unavailable surface;
the next owner eviction can rebuild the launcher.

The clock reads audience-device local civil time through an injectable read-only
Callable. It displays HH:MM, schedules the next minute boundary, stops while the
window is unfocused, and refreshes on foreground return. Invalid readings show
`--:--`; routine time never changes game state. No anomaly mechanism is added.

## Verification

Run the focused suites from this worktree:

```text
python tools/desktop_shell/verify.py
python tests/desktop_shell/verify_settings.py
python tools/contacts_shell/verify.py
python tests/contacts_presentation/verify_real_owner.py
```

The first two cover the new shell and real existing Settings owners; the latter
two preserve Contacts behavior and actual GameState/Bootstrap wiring. Each uses
isolated storage and a disposable Godot project. Consolidated evidence and the
independent review live in `evidence/desktop_shell/`. Headless layout/input results
do not prove GPU rendering, full startup, hardware controller or Windows DPI
coverage. Known certificate-store and inherited NUL diagnostics remain in logs.

UI-00/UI-00R documents remain historical references under the user's UI-first
direction. This work does not register dossiers, archive sources, commit or
install changes into the dirty destination. Missing final Contacts prose and
general history-read commands remain separate content/gameplay work.
