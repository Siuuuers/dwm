# Desktop launcher owner audit

Read-only source inspection on 2026-09-05 in `contacts-ui-build`. This records
the current wiring, not a full application-startup or rendering test. Historical
plan permission gates are reference material; the missing runtime dependencies
below are actual implementation gaps.

## Recommendation

Build the shared launcher/strip/Home/cache/focus foundation around Contacts and
Settings. Settings has functioning owner commands; the bounded hosting follow-up
below supplies its scrolling and layout. Keep the other registered destinations visible with
truthful unavailable behavior until their real adapters exist. Unsupported
activation must leave the host, current app, board, save state and route intact;
never mount enabled inert buttons or sample content as if those apps worked.

## Route inventory

All seven exact scene paths are supplied by
`scripts/domain/desktop/DesktopAppRegistry.gd:get_record`. Each app has a real
scene; that fact alone does not establish operational readiness.

| ID and scene under `scenes/apps/` | Existing behavior | Prerequisites and smallest useful binding |
|---|---|---|
| `contacts` — `ContactListApp.tscn` | Operational shell, detached projection, guarded owner open, group reply seam. | Reuse `ApplicationBootstrap.configure_contacts_desktop`, retained `ContactsPresentationPort`, issuer-backed `ContactCommandPort`, canonical GameState and retained desktop host. Production correspondence catalog remains empty; reject missing content before acceptance. |
| `settings` — `SettingsApp.tscn` | `SettingsApp._ready` binds `SettingsPanelController`. Locale, preference and confirmation-gated reset controls call real owners. | After Bootstrap readiness, require `/root/ProfileManager` and `/root/LocalizationManager` (`get_readiness()==ready`). Controller uses these absolute paths. The hosting follow-up now supplies a vertical scroll layout and explicit `get_desktop_ready_result`; the shell supplies its title and Home button. |
| `minesweeper` — `MinesweeperApp.tscn` | Scaffolding: difficulty/status/tools, empty board region, enabled simulation-result buttons; no board commands connected. | Real application `MinesweeperRoundCoordinator.configure` needs state/checkpoint/generation/issuer dependencies; Bootstrap currently never calls its base configure and its per-run identity is still a placeholder. Do not wire simulator outcome buttons or bypass the coordinator. |
| `schedule` — `ScheduleApp.tscn` | Scaffolding: enabled Dating/Training/Working/Rest/Done controls, empty draft bar; no handlers. | Needs UI draft projection plus retained `GameStateScheduleCommitPort` and `ScheduleDoneDispatcher.dispatch_done(command_id)` with the existing day-resolution graph and authentic command issuance. Do not set `GameState.day`, call internal prepare/commit fragments independently, or manufacture Done success. |
| `shop` — `ShopApp.tscn` | No handlers; scene contains `SampleShopItemBox`. | Requires catalog/currency/quantity projection and the retained purchase/consequence transaction path. `GameStateMinesweeperShopPort.prepare_purchase` is a participant, not a complete UI purchase command; Bootstrap's placeholder identity also affects this path. Do not show sample merchandise or call money/inventory mutators directly. |
| `backup` — `BackupApp.tscn` | Only listens to `save_capability_changed`; `SaveSlotRow` toggles its Save button. Save/Load/Delete and Return are otherwise unwired; only two sample rows exist. | `SaveManager.get_all_save_metadata` is a usable read-only query. Complete operations already exist (`save_latest_to_slot`, `quick_save_latest`, prepare/commit restore, delete methods), but require explicit row identity, initial `get_save_capability`, result handling, restore routing and appropriate confirmation. Do not treat metadata presence as permission to write or display sample rows as saves. |
| `logout` — `LogOutApp.tscn` | No hides the panel; Yes does nothing. It is a PanelContainer, not AppWindowBase, and has no `window_hidden` contract. | `LogoutCoordinator.configure` requires SaveManager, route port `goto_menu`, and stable-board port `is_slice_executing`/`capture_stable_board`. That last production port does not exist and Bootstrap constructs no LogoutCoordinator. No confirmation must return focus without mutation. Yes cannot bypass save with `SceneRouter.goto_menu`. |

Settings owner details: `SettingsPanelController._on_language_selected` delegates
to `LocalizationManager.set_locale`; `_commit_preference` delegates to
`ProfileManager.set_preference` and restores the displayed value on failure.
The generated reset controls already use ConfirmationDialogs. Preserve those
confirmations. Its existing generic font-scale slider spans 0.05–3.0, whereas
Contacts renders the 100/125/150 presets; these are not currently identical UI
contracts. The initial scene ignored the result of `bind`; the hosting follow-up
now exposes it. The launcher must inspect readiness instead of assuming scene
instantiation proves it.

### Bounded Settings hosting follow-up

After the read-only audit, the orchestrator assigned a focused Settings host fix.
Only `scripts/ui/SettingsApp.gd` and `scenes/apps/SettingsApp.tscn` changed for it.
The app now occupies 800x656 with its inherited strip hidden, one vertical
ScrollContainer and a VBox of existing controls. Buttons/labels wrap and sliders
retain usable width; preference semantics and the shared controller remain intact.
`configure_desktop_home(home)` links initial language focus with shell Home in
both directions. Cached reopen restores valid focus. Back returns to language
first, then returns Home on a separate activation; visible confirmations or
internal option popups block Home and retain input priority. Readiness-capable
owners must report `ready` before binding; LocalizationManager exposes this API,
while ProfileManager currently exposes no public readiness query.

`python tests/desktop_shell/verify_settings.py` passed against the real Settings
scene, controller, ProfileManager and LocalizationManager with fake storage. It
checks readiness, existing preference mutation, scroll reachability, 24/30/36
font layout, focus and confirmation priority. Evidence:
`.godot/desktop-settings-ypvbt8ix/result.json`. Inherited certificate/NUL
diagnostics are retained; this is headless geometry/input evidence, not a full
Settings design or production-startup completion claim.

## Host and Bootstrap constraints

`DesktopAppHostState.open_app(app_id, day, board_phase)` both mutates the
transient host and returns ordered commands. When leaving an active visible
Minesweeper board those commands include `suspend_board`; returning can require
`resume_board`. `go_home` similarly returns suspension and hide commands.
`close_app` by itself has no board-suspension input. Never pass a fabricated
`NONE` phase to make a real board transition appear safe.

For the supported Contacts/Settings subset, create/configure the destination
successfully before publishing its host transition. Preserve one visible app,
cache hidden apps for the same day, restore each launcher's focus, and handle
same-app activation without rebuilding its state. Unknown or unsupported IDs
must reject before `open_app` changes host state.

Bootstrap retains a RefCounted eviction adapter with a weak view reference, so
day change works while Dating/Hospital has destroyed the desktop view. Preserve
that ownership and rebind each replacement desktop. Restore can name any
registered active app; an unsupported restored destination is a genuine
capability gap, not permission to overwrite canonical saved intent. Display a
safe unavailable surface or preserve the owner identity until explicit supported
navigation, rather than silently resetting it to Contacts.

`ApplicationBootstrap._configure_desktop_production_graph` explicitly documents
the absent Minesweeper generation/base configuration, placeholder per-run board
and shop identities, and absent Logout stable-board port. Its
`desktop_graph_constructed` probe deliberately means construction, not usability.

## Clock

No desktop/system-clock presentation provider or clock Control was found in the
current `autoload`, `scripts`, or `scenes/desktop` sources. The GameState
`started_at_unix` read is a round record, not a UI clock provider.

The root current-UI `docs/design/current-ui/shared-shell.md` section 10 specifies
audience-device local civil time as noninteractive 24-hour `HH:MM`, no seconds,
minute-boundary refresh while eligible and immediate refresh on foreground
return. Use a small injected system-clock adapter; tests can supply fixed values.
Time must never advance the game day, sort messages, grant knowledge or change
save ordering. Unavailable time renders `--:--` with a truthful semantic label.
Contacts wrong-time allocation has no implemented provider here; do not create
an anomaly or random offset in the shell.

## Focused checks for the foundation

- Supported Contacts/Settings open, same-app reopen, Home, keyboard/controller
  focus restoration and day eviction use the real host.
- Unsupported, unknown and failed scene/configuration routes leave the previous
  app and host state unchanged.
- Restored supported apps mount without inventing a new selected contact or read.
- Settings preserves real owner failures and supports all content at larger text.
- Clock refresh is presentation-only, supports unavailable input and cannot take focus.
- Returning from routed scenes binds the replacement desktop without retaining a
  freed view or constructing a second canonical owner.
