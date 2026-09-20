---
id: spec.main_menu_desktop_shell_global_chrome_ui_ux_amendment
kind: design_amendment
schema_version: 1
amends: spec.desktop_minesweeper_shop_schedule_amendment
amends_path: "docs/design/2026-08-11-desktop-minesweeper-shop-schedule-amendment.md"
conversational_design_status: approved
decision_status: accepted
written_spec_status: approved
self_review_status: passed
self_reviewed_on: "2026-08-12"
written_spec_approved_on: "2026-08-12"
implementation_authorized: false
created_on: "2026-08-12"
engine_line: godot_4_6
verification_engine: "4.6.3-stable-mono"
language: gdscript
scope: ["title_shell_and_new_acc_entry","desktop_shell_canvas_and_global_chrome","desktop_launcher_app_host_and_focus","angela_hud_tableau_keepsakes_and_self_talk","audience_clock_strip_and_anomaly_projection","global_overlay_arbitration","shell_persistence_accessibility_and_visual_trust","opening_and_tutorial_retirement"]
---

# Main Menu, Desktop Shell, and Global Chrome UI/UX Amendment

## 1. Status and objective

This accepted written amendment records the approved main
menu, desktop shell, global chrome, launcher, Angela panel, self-talk, clock,
overlay, focus, and responsive-layout design.

The conversational design and exact self-reviewed written artifact were
approved on 2026-08-12. Acceptance does not authorize implementation.
Requirement packets, design-authority registries, Beads, hash-bound plans,
schemas, scenes, localization catalogs, tests, and runtime code remain
unchanged until separately reconciled and explicitly authorized.

The chosen experience is one **continuous campus workstation**. Logged-out and
in-run states belong to the same old university operating system rather than
two unrelated menus. The system may look rough, aged, ink-like, excessively
still, and subtly dreamlike. It must remain exact and truthful about focus,
input, time, saves, routes, app state, and technical failure.

The design has six objectives:

- preserve one recognizable shell at 100%, 125%, and 150% text size;
- keep Angela and the computer present as one continuous lived space;
- make every app reachable without draggable-window or desktop-cosplay noise;
- allow eerie time and self-talk presentation without falsifying mechanics;
- preserve exact cross-app, save, Load, and recovery behavior; and
- remove the never-shipped standalone Opening and tutorial completely.

### 1.1 Accepted derived closures

The conversation fixed the product direction and nearly every observable
choice. The following exact closures are accepted within scope so the design
is deterministic and testable:

- The shared title and in-run host strip is 64 logical pixels tall. This is the
  smallest fixed strip that can contain a genuine 64-by-64 Home or Return
  target when Large Targets is enabled without overlapping content or changing
  the shell topology.
- The 30/44/26 Angela-panel division is a baseline composition target, not a
  clipping mandate. At 125% and 150%, functional HUD and caption content takes
  height from the noninteractive tableau first.
- The fixed logical canvas is 1280 by 720. Other aspect ratios uniformly center
  that canvas inside inert themed matte bars. The bars never receive or remap
  input.
- A valid saved active-app identity is either `null` or one of the six stable
  content-app IDs. `logout` remains the seventh registered launcher identity
  but is an action/confirmation, never a restorable workspace. Unknown or
  `logout` active-app values are invalid save data; the host does not silently
  guess a substitute app.
- The Home control remains geometrically present on the launcher but is marked
  current and omitted from focus because the launcher already is Home.
- Direct and indirect app routes use the actual destination app ID as the
  transient return-focus anchor. They never pretend an unrelated source icon
  opened the app.
- The self-talk admission queue contains at most one unpublished ordinary cue.
  The latest admitted ordinary cue replaces an older unpublished ordinary cue
  by canonical causal sequence, never by frame arrival order.
- Once ordinary self-talk is published, the accepted caption grammar may show
  the current and prior two available beats in single-language mode. The
  one-slot rule governs unpublished competition, not the accepted caption
  stack.
- A pinned Dark Schedule refusal temporarily projects only that refusal. It
  suppresses ordinary publication. When it clears, the one retained
  `pending_ordinary` occurrence may publish; replaced or otherwise suppressed
  occurrences never resurrect.
- Each eligible desktop-clock anomaly window declares a deterministic nonzero
  wrong-time rule. Materialization therefore cannot accidentally display the
  truthful minute and pass as an anomaly by luck.
- A missing or unreadable audience clock projects a truthful unavailable state
  rather than retaining a stale time or manufacturing one.
- A missing decorative app icon or keepsake asset uses an authored,
  nonsemantic fallback silhouette. Missing decoration cannot change an app,
  purchase, route, focus target, or saved ownership fact.
- A route or app-construction failure retains the last stable shell and enters
  the trusted technical recovery boundary. It never silently falls back to a
  different app or turns the failure into fiction.

## 2. Authority and precedence

### 2.1 Authority spine

This accepted artifact controls intended behavior within its eight frontmatter
scope topics over conflicting recovered
documents, prompt packets, proposed or hash-bound plans, tests, and current
shell scaffolds.

It narrowly amends the accepted 2026-08-11 Desktop Minesweeper, Shop, and
Schedule amendment. That amendment retains authority for the seven-app
registry, one-visible-app invariant, desktop-board lifecycle, exact cross-app
continuity, stable command boundaries, Schedule warning mechanics, causal
departure, and technical truth.

The accepted 2026-08-07 Seven-Day Flow and Dialogic Structure design retains
authority for every unrelated run, story, Contacts, invitation, Schedule,
Hospital, relationship, challenge, ending, Gallery, persistence, and recovery
rule. This amendment narrowly retires its `opening.day1` and
`tutorial.desktop_day1` semantic inventory entries because the product has not
shipped and the approved game now begins directly at the Day-1 desktop.

The accepted 2026-08-12 app amendments retain their own authority:

- Shop owns its catalogue, inspector, purchase, Supportz, and transaction
  behavior;
- Contacts owns correspondence, notification, clock-allocation, and app-cache
  behavior;
- Backup owns record projection, Save/Load/Delete consent, title Log in, and
  route reconstruction; and
- Settings owns language, caption, TTS, text-size, target-size, colour,
  inactive-window, window-mode, and Dark-run configuration.

This amendment supplies the common host and safe regions consumed by those
apps. It does not reinterpret their internal state or commands.

Authority is resolved by declared scope, not document date. Each accepted
sibling amendment controls behavior inside its declared app scope. This
amendment controls only shared shell, global chrome, host composition, and
cross-surface arbitration inside its declared scope. If an observable behavior
cannot be assigned unambiguously to one declared owner, implementation is
blocked until an explicit reconciliation assigns it; neither document wins by
being newer or more general.

The Core Story Bible retains dialogue-led story delivery, sparse source-authored
anchor-bound perception, no narrator identity or unrestricted thought box, and
the audible-self-talk, visual, sound, and epistemic boundaries. The approved
July canon amendment retains the desktop-only Observer exclusion and Dark
Angela's left-panel refusal/self-talk law. This amendment defines their shell
projection; it does not add consciousness, knowledge, motives, or a new Observer
mechanic.

Beads owns mutable work status, dependencies, and implementation evidence. A
written design approval does not authorize runtime, packet, plan, schema,
test, art, audio, localization, or Beads mutation.

### 2.2 Current physical and execution state

At the time of writing:

- runtime implementation is not authorized;
- `dwm-0hi` is closed against the earlier accepted desktop amendment and must
  not be reopened or silently widened for this later shell design;
- `dwm-oyo.1` remains the future authority-reconciliation work-tracking gate;
  it records mutable work status and does not itself define product law;
- `dwm-oyo.3` owns later production desktop composition but is bound to an
  earlier authority and plan surface;
- `dwm-oyo.7` owns final integration and release evidence, not product-law
  invention;
- a separate successor reconciliation issue and reviewed plan amendments are
  required before this design may enter those live owners;
- the checked-out title, desktop, Angela panel, host strip, launcher, app
  windows, HUD, Opening, and tutorial scenes are incomplete or stale physical
  scaffolds; and
- approval of this file alone claims no validator discovery, implementation,
  migration, scene completeness, or release readiness.

Historical documents and commits remain inspectable evidence. They are not
runtime compatibility promises.

## 3. Scope boundary

### 3.1 In scope

This amendment closes:

- the shared 1280-by-720 title and in-run shell canvas;
- title ledger, workfield, host strip, clock, focus, and hosted surfaces;
- New Acc publication into a clean Day-1 desktop;
- complete retirement of the never-shipped Opening and tutorial;
- the in-run 480/800 Angela/computer split;
- the 64-pixel app strip and fixed seven-app launcher;
- one-visible-app hosting, Home, Back, cache, direct routes, and indirect routes;
- Angela's quiet HUD, non-geographic tableau, and three keepsake sockets;
- ordinary and Dark-refusal self-talk projection and persistence;
- title clock truth and desktop clock-anomaly materialization;
- confirmation, warning, toast, Quick-status, caption, and recovery layering;
- fixed-aspect behavior, text size, target size, localization, focus, input, and
  assistive semantics;
- shell-level technical failure and recovery presentation; and
- component ownership and the later reconciliation/verification boundary.

### 3.2 Out of scope

This amendment does not define:

- Gallery/Rehearsal internal layout, ending titles, replay, signatures, or
  profile mechanics;
- narrative-scene, dating, Hospital, challenge, ending, or credits composition;
- final dialogue or self-talk prose;
- final portrait, background, icon, keepsake, font, animation, music, or sound
  asset production;
- exact final colour-token values beyond the visual constraints in this file;
- Shop, Contacts, Schedule, Minesweeper, Backup, Settings, or Logout internal
  mechanics already owned elsewhere;
- mobile portrait layout, Android delivery, 200% text, exclusive fullscreen,
  or a resolution selector;
- character customization, room decoration controls, draggable windows,
  multitasking windows, desktop files, folders, or a taskbar;
- arbitrary system-clock changes, real-time deadlines, or clock-driven game
  state;
- runtime implementation, destructive deletion, migration execution, Beads
  mutation, or plan execution.

## 4. Chosen design and rejected alternatives

### 4.1 Chosen: continuous campus workstation

The logged-out ledger, title workfield, in-run launcher, apps, Angela alcove,
Backup archive, and trusted recovery surface are states of one maintained old
university workstation.

The surface is spatially stable. Horror comes from sustained familiarity,
blankness, authored record order, rare truthful-context anomalies, and Angela's
audible presence—not from unreliable controls or simulated corruption.

This approach best fits the game because:

- the audience learns one spatial grammar;
- old-school material and liminal empty space can persist across every app;
- app-local designs remain isolated behind one host contract;
- exact focus and save behavior stays understandable; and
- the abnormal feels normalized rather than announced.

### 4.2 Rejected: separate cinematic title world

A centered decorative title screen followed by a visually unrelated desktop is
rejected. It would turn New Acc into a conventional game-start threshold and
weaken the sensation that the audience is continuing to use the same machine.

### 4.3 Rejected: fluid art-first dream desktop

A responsive shell that rearranges icons, expands panels into new topologies,
or treats dreamcore colour as the primary structure is rejected. It would make
focus, muscle memory, localization, and 150% text behavior less predictable,
and cosmetic movement could look mechanically meaningful.

### 4.4 Rejected: simulated window manager

Draggable, overlapping, resizable windows, minimize buttons, title-bar X
buttons, a taskbar, and free desktop placement are rejected. The game needs app
continuity, not a general-purpose window manager.

### 4.5 Rejected: authored Opening and tutorial

A standalone Opening, blocking tutorial overlay, hidden tutorial alias, or
mandatory orientation dialogue is rejected. Day 1 begins at the launcher.
Sparse Angela self-talk may orient through ordinary use, but it remains
ignorable and never stands in for a tutorial receipt.

## 5. Vocabulary and state ownership

### 5.1 Logical canvas

The 1280-by-720 coordinate space in which all shell geometry, focus anchors,
safe regions, and logical target sizes are defined. Operating-system display
scaling is outside this coordinate system.

### 5.2 Title shell

The logged-out workstation state containing the action ledger and workfield.
It owns no live run. It projects profile preferences, Dark next-run intent,
Gallery availability, Backup records, and the truthful title clock through
their proper owners.

### 5.3 In-run shell

The live-run workstation state containing Angela's panel and the computer
workspace. It does not own gameplay state inside apps.

### 5.4 Launcher

The in-run Home projection of the seven registered app identities. It is not a
saved app and owns no gameplay mutation.

### 5.5 Active app identity

`null` for the launcher or exactly one of the six stable content apps:

- `minesweeper`;
- `contacts`;
- `schedule`;
- `shop`;
- `backup`;
- `settings`.

The canonical run save preserves this semantic identity. It never preserves an
app Node, scene instance, focus NodePath, modal, hover, animation, or view
cache.

`logout` remains the seventh registered launcher destination, but activating
it prepares trusted Logout consent over the launcher. It never becomes a
stable active workspace, same-day cache, or saved `active_app_id`.

### 5.6 Presentation cache

Noncanonical same-day state such as app instances, local scroll, selection,
and meaningful focus. Each app owns the contents allowed by its accepted
manual. The shell owns cache lifetime and visibility only.

### 5.7 Self-talk cue

A stable localized semantic ID representing audible Angela speech plus a
minimal frozen trigger context. It is not a Dialogic timeline, narrator line,
private thought, Contacts message, visited line, Gallery record, or Observer
fact.

### 5.8 Trusted blocking surface

A confirmation, Schedule warning, transaction recovery, or technical recovery
surface that temporarily owns input and defines exact focus restoration.

## 6. Canvas, aspect ratio, and scaling

### 6.1 Fixed logical canvas

The shell uses exactly 1280 by 720 logical pixels with a 16:9 aspect ratio.

Windowed mode uses this approved logical baseline. Borderless mode uses the
display's usable bounds and uniformly scales the logical canvas to fit while
preserving aspect ratio.

At any other usable aspect ratio:

- the entire logical canvas is uniformly scaled and centered;
- pillarbox or letterbox margins use the current effective base palette;
- no shell region expands into the margins;
- no content crops or rearranges;
- no pointer coordinate outside the canvas is remapped onto an edge control;
  and
- the margins contain no focus, hover, tooltip, toast, anomaly, status, hidden
  hit area, or gameplay fact.

### 6.2 Text-size invariance

The initial release supports the Settings-owned 100%, 125%, and 150% text
presets. These change type metrics, wrapping, and local scroll needs but not:

- the 320/960 title split;
- the 480/800 in-run split;
- the 64-pixel host strips;
- launcher order or coordinates;
- Angela/computer ownership;
- app or ledger order;
- overlay anchors; or
- canonical input behavior.

Text never silently shrinks, clips, overlaps, becomes an image, or requires
horizontal text scrolling. Supported localization that cannot satisfy this
surface is a release failure, not permission to reduce the selected size.

### 6.3 Target sizes

Ordinary interactive targets are at least 48 by 48 logical pixels. Large
Targets raises the minimum to 64 by 64.

The shell's 64-pixel strips and large launcher cells support both modes without
macro reflow. App-internal local scrolling may increase under Large Targets as
defined by each app manual.

## 7. Logged-out title shell

### 7.1 Exact composition

The title canvas is divided into:

- action ledger: `x=0..320`, `y=0..720`; and
- workfield: `x=320..1280`, `y=0..720`.

The workfield contains:

- host strip: `x=320..1280`, `y=0..64`; and
- hosted content: `x=320..1280`, `y=64..720`.

When no title destination is hosted, the content field is deliberately empty.
It contains no instruction, logo animation, fake terminal, `Select an option`
copy, placeholder illustration, lore, or tutorial hint.

### 7.2 Ledger order and visibility

The exact vertical ledger order is:

1. New Acc;
2. Dark Mode next-run selector, only after its profile entitlement exists;
3. Log in;
4. Gallery;
5. Settings; and
6. Shut down.

Before Dark entitlement, the selector is absent. It leaves no disabled gap,
locked silhouette, tooltip, count, or phantom focus stop.

Fresh title focus begins on New Acc. Up and Down move through the currently
visible rows without wrapping. Pointer hover never changes focus or selection.
One click, tap, keyboard Accept, controller Accept, or assistive activation
invokes the same semantic command.

### 7.3 Title host strip

The empty title strip shows only the truthful audience-local clock at its right
edge. Its Return and title regions remain blank rather than projecting a fake
app.

When Log in, Gallery, or Settings occupies the workfield, the strip contains:

- one 64-by-64 Return target at the left of the workfield;
- a flexible localized host title; and
- the noninteractive clock at the right.

The title clock never participates in the run-scoped clock anomaly, even if
saves exist or the prior session ended during an anomaly.

### 7.4 Hosted title destinations

Log in uses the accepted Backup load-only composition. Settings uses the
accepted title Settings composition. Gallery receives the same bounded
workfield and Return contract, while its internal archive design remains owned
by a later Gallery/Rehearsal amendment.

The ledger remains visible and operable while an ordinary nonmodal title
destination is open. Selecting another destination performs the current
surface's accepted local retreat first:

- stop or cancel noncanonical previews, tests, and captures;
- allow an admitted bounded commit to reach its stable result;
- never abandon a prepared storage mutation or profile commit;
- close the old host cleanly; and
- open the new destination at its semantic first focus.

The ledger becomes inert while a trusted modal, indeterminate commit, or
technical recovery surface owns input.

Return closes the current title destination and restores focus to its exact
ledger source row.

### 7.5 Shut down

Shut down opens an ordinary trusted confirmation. Cancel owns initial focus;
Back means Cancel; cancellation returns focus to Shut down. Confirming quits
only after any already-admitted bounded title operation has reached its stable
result. It does not fabricate a Save or delete any record.

## 8. New Acc and removal of Opening/tutorial

### 8.1 New Acc transaction

New Acc follows the accepted Backup replacement consent and Settings Dark
capture laws. After any required confirmation succeeds, the existing
SaveManager-owned New Run transaction:

1. freezes the selected Dark next-run intent and relevant record revisions;
2. creates a new run and branch identity;
3. sets logical Day 1;
4. captures the frozen Dark value into immutable run configuration;
5. sets canonical route to the main shell;
6. sets active app identity to `null`;
7. seeds only valid Day-1 run and self-talk facts;
8. prepares the required initial Autosave from that complete detached run;
9. atomically commits the new run, initial Autosave, and title Dark selector
   consumption to Off through the existing recoverable New Run transaction;
   and
10. publishes the Day-1 launcher only after the transaction is durable.

The first visible in-run focus is Minesweeper on the launcher. A Dark run uses
its captured Dark palette immediately, so consuming the menu selector cannot
create a light-palette flash.

Cancel or failure preserves the prior title state, pending Dark intent,
records, and live continuation exactly.

### 8.2 Complete target removal

The target product contains no standalone Opening or desktop tutorial.
Specifically, it contains no:

- `opening.day1` semantic entry or timeline;
- `tutorial.desktop_day1` semantic entry or timeline;
- Opening route, scene, script, manifest row, project registration, or audio
  context;
- Tutorial overlay, host, scene, script, manifest row, project registration,
  audio context, or replay setting;
- `opening_seen` or `tutorial_seen` run field, command, receipt, or save leaf;
- Opening/tutorial visited-line ID, smoke inventory, localization contract,
  fixture, or target test expectation; or
- alias, tombstone, compatibility converter, fallback route, hidden cue, or
  replacement tutorial receipt.

Sparse Day-1 self-talk remains ordinary ignorable self-talk. It does not carry
an Opening or tutorial identity and does not gate any app.

### 8.3 No unshipped compatibility burden

The game has not shipped. Development snapshots, profiles, or checkpoints that
depend on retired Opening/tutorial routes, fields, or IDs are outside the
supported target schema. They are not migrated, normalized, read-and-dropped,
or reinterpreted.

Historical source documents and Git commits remain historical evidence. They
do not become runtime entries.

## 9. In-run shell and computer workspace

### 9.1 Exact outer split

The in-run canvas is divided into:

- Angela panel: `x=0..480`, `y=0..720`; and
- computer workspace: `x=480..1280`, `y=0..720`.

The computer workspace contains:

- app strip: `x=480..1280`, `y=0..64`; and
- app content: `x=480..1280`, `y=64..720`.

Only one stable content app may be visible in the app content area. The shell does
not show overlapping windows, a taskbar, minimized windows, or a parallel app
title bar.

### 9.2 App strip

The app strip contains:

- a 64-by-64 Home target at left;
- one flexible localized current-title region; and
- one fixed-width, tabular, noninteractive `HH:MM` clock at right.

When an app is open, Home is enabled. On the launcher, Home remains visibly
current but is disabled and omitted from focus order. The title region reads
the localized equivalent of Home on the launcher and the registered localized
app title while an app is open.

The title and clock use complete text, not ellipsis. A localization that cannot
fit within the strip's verified wrapping allowance fails release validation.
Minute changes never trigger a live-region announcement.

### 9.3 Integrated app surface

The shell supplies app content bounds, visibility, focus entry, focus return,
cache lifetime, global preference inputs, overlay safe regions, and technical
recovery entry.

It does not supply app gameplay, rewrite app selections, or infer app-specific
state from Controls. App scenes do not render a second draggable title bar or
X button. App-internal headings are allowed where their own information
architecture requires them.

## 10. Launcher

### 10.1 Fixed registry projection

The exact row-major launcher order is:

| Row | Column 1 | Column 2 | Column 3 | Column 4 |
|---|---|---|---|---|
| 1 | Minesweeper | Contacts | Schedule | Shop |
| 2 | Backup | Settings | Log out | empty |

The empty eighth position is genuinely empty and nonfocusable. It contains no
future-app silhouette, lock, tooltip, mystery marker, Supportz analogue, or
hidden activation.

This visible order supersedes recovered arrangements that place Setting,
Logout, and Backup in another tail order. It does not change the closed seven
semantic app IDs.

### 10.2 Exact baseline geometry

Within the 800-by-656 computer content area, the launcher grid uses:

- outer inset: 24 logical pixels;
- grid bounds: `x=504..1256`, beginning at `y=88` in full-canvas coordinates;
- four columns, each 176 logical pixels wide;
- three horizontal gutters, each 16 logical pixels;
- two row cells, each 176 logical pixels tall;
- one vertical gutter of 16 logical pixels;
- first row: `y=88..264`;
- second row: `y=280..456`; and
- deliberate unused field below the second row.

The cells and labels remain at those coordinates for all supported text sizes.
Labels wrap within their cells. Icons do not reorder, move to a list, or shrink
into a dense taskbar.

### 10.3 Launcher focus graph

Fresh or rebuilt launcher focus begins on Minesweeper.

Horizontal arrows or D-pad move only among actual neighbors in the same row.
Vertical mappings are:

- Minesweeper and Backup;
- Contacts and Settings; and
- Schedule and Log out.

Down from Shop does nothing. Movement toward the empty eighth position does
nothing. Focus never wraps. Tab and Shift+Tab traverse the seven items in
row-major order.

Focus, hover, and selection never open an app. One explicit activation does.
Double-click and double-tap have no special shell meaning.

## 11. App lifecycle, cache, and routing

### 11.1 Direct opening

Activating a stable content-app icon asks the Desktop Host to open that app.
The host prepares the app projection before replacing the launcher. Success:

- hides the launcher;
- shows exactly one app;
- enters the app at its accepted semantic first focus or valid same-day cached
  focus; and
- records that app ID as the transient return-focus anchor.

Failure retains the launcher and icon focus, changes no canonical app identity,
and uses the trusted technical boundary.

Activating Log out leaves the launcher as the stable underlying projection and
opens the accepted trusted Logout consent. Cancel restores Log out focus.
Success writes the exact Logout Autosave and routes to title. No Logout consent
or `logout` active-app value can enter a save.

### 11.2 Same-day Home and reopen

Home or root-level Back hides rather than frees an ordinary app during the same
logical day. It preserves only the app-local presentation cache allowed by that
app's accepted manual and restores focus to the app's launcher icon.

Reopening the app reprojects current canonical state and then restores only
still-valid cached presentation. It cannot replay a purchase, read, reply,
board command, Schedule action, Save, or TTS announcement merely because the
scene was hidden.

### 11.3 Indirect routing

Schedule-warning Go, Contacts-toast Go, Quick Load restoration, and any other
registered indirect route use the actual destination app ID as the return
anchor. For example, a warning that opens Contacts returns Home focus to the
Contacts icon, not Schedule.

An indirect route prepares the destination and app-specific command separately.
If preparation fails, neither the route nor its command partially commits.

### 11.4 Cache reset boundaries

Every app presentation cache is cleared on:

- logical-day change;
- successful Load;
- successful New Acc/New Run;
- Logout; and
- Entire Profile Reset where the Settings law requires a fresh host.

The next clean day entry returns to the launcher with Minesweeper focused.

### 11.5 Load reconstruction

A valid selected save preserves canonical route and active app identity.
After the detached whole-state restore commits:

- `active_app_id=null` reconstructs the launcher with Minesweeper focused;
- a valid registered ID reconstructs that app at its accepted clean restore
  projection;
- Contacts, Shop, Backup, and Settings apply their accepted reset projections;
- Schedule restores only its explicitly canonical saved view facts;
- Minesweeper restores its exact candidate or board; and
- no app modal, preview, hover, pointer press, local scroll, stale toast, or
  focus NodePath is restored.

For the main shell route, the active-app value must be `null` or one of the six
stable content-app IDs. For a route that does not project the desktop shell, the
active-app value must be `null`. An unknown ID, `logout`, or an incompatible
route/app combination is invalid data and causes Load preparation to reject
without mutating the current run. A valid app whose presentation cannot be
constructed enters trusted recovery rather than silently showing another app.

## 12. Home, Back, and focus precedence

### 12.1 In-run focus entry and exit

Opening an app focuses its semantic first or cached control, never Home. Home
remains reachable through the host focus path, including Shift+Tab from the
app's first host-level focus boundary and the accepted controller navigation
route.

At a safe app root, Back performs Home. At the launcher, Back has no implicit
Logout, title route, or Quit meaning.

### 12.2 Exact Back/Home precedence

One Back input resolves against the highest active applicable layer:

1. technical recovery exposes only its registered recovery commands;
2. a binding capture, confirmation, Schedule warning, or blocking consent
   cancels or closes through its own exact law;
3. an active preview, sample, test, or transient local mode stops;
4. an app-local subview retreats toward its app root; and
5. the safe app root returns Home.

One input performs one semantic action. It never closes two layers or both
cancels a modal and leaves the app.

Home is inert while technical recovery, a binding capture, a confirmation,
Schedule warning, blocking consent, or an already-admitted canonical
transaction owns input. It neither cancels nor queues behind that owner and
requires a fresh activation after the owner releases input. In an otherwise
safe app state, Home performs the app's required noncanonical preview/test
cleanup, hides the app, preserves only its allowed same-day cache, shows the
launcher, and restores the app's launcher icon. It does not walk an app-local
subview one level at a time. It never pretends a still-running command was
cancelled.

### 12.3 Focus restoration

Closing a modal restores the exact initiating semantic control if it remains
valid. Returning Home restores the actual destination app icon. Returning from
a title host restores its ledger source row.

If an app-local cached focus target no longer exists, the app's accepted manual
selects its deterministic fallback. The shell never chooses a nearby control
by screen geometry.

Pointer hover never steals keyboard/controller focus. Pointer, touch,
keyboard, controller, and assistive activation reach the same semantic action.

## 13. Angela panel composition

### 13.1 Baseline regions

The persistent Angela panel uses the following baseline targets:

- quiet HUD: approximately 30%, `y=0..216`;
- Angela/room/keepsake tableau: approximately 44%, `y=216..533`; and
- self-talk dock: approximately 26%, `y=533..720`.

These coordinates describe the 100% baseline composition. They are not hard
clipping boundaries. At 125% or 150%, functional HUD and caption content may
grow into the tableau. The tableau is cropped or reframed around authored focal
anchors before any functional text is reduced, clipped, or overlapped.

The Angela panel remains present while any desktop app is open. It never
overlays the computer workspace.

### 13.1A Glass HUD overlay refinement (2026-09-20)

The current desktop composition extends the existing artwork across Angela's
full panel and places the stats above it in an inset, translucent dark card.
The artwork retains its aspect ratio and layer registration; changing stats
or text size does not reserve or remove a separate strip of artwork. A subtle
rim and highlight give the card a glass appearance, while a stronger Day
heading and tabular figures keep the public facts easy to scan.

The card ends above the divider's complete pointer/touch target. Enlarged
text and longer condition or penalty copy scroll within this bounded area;
facts are never shortened or silently hidden. High Contrast uses an opaque
surface. All public-value, localization, accessibility and read-only rules
in section 14 continue to apply.

### 13.2 Non-geographic alcove

The tableau is an intentionally non-geographic old-campus work alcove. It may
contain a shallow desk, sparse shelf, exhausted institutional wall plane, and
restrained Angela sprite. It is not declared to be a dormitory, home, office,
specific campus room, or fixed story location.

Angela remains the visual anchor. Pose or hand changes are restrained authored
presentation, not a continuous emotional meter. No pose, costume, tint, or
facial variant exposes hidden relationship, Observer, ending, or Dark-unlock
facts.

Reduced Motion turns any nonessential transition into a static swap. No
continuous idle animation is required.

## 14. Quiet HUD

### 14.1 Visible facts

The HUD projects only:

- logical Day;
- Pressure displayed in the audience range 0 through 9;
- Health displayed in the audience range 0 through 9;
- Motivation displayed in the audience range 0 through 7;
- exact money;
- exact Minesweeper coins; and
- a localized current condition and current penalty only when canonically
  present.

Each fact has visible text or numeral plus any optional icon, glyph, outline,
shape, or notch. Colour is never its only evidence. Figures use stable tabular
alignment so changing values do not move surrounding layout.

Day, Pressure, Health, and Motivation each expose a localized name and displayed
numeric value. Pressure, Health, and Motivation also expose their audience
display maxima of 9, 9, and 7 respectively. Currency uses localized labels and
signed tabular figures rather than an unexplained icon.

Pressure values held internally above 9 continue to display 9. The HUD does
not reveal that clamping, the internal 10-through-12 range, a danger forecast,
or the next condition threshold.

Health values held internally below 0 continue to display 0. They are visually
and assistively indistinguishable from canonical displayed Health 0. No tint,
overflow mark, tooltip, animation, description, or hidden accessibility
metadata reveals either concealed Pressure or Health range.

When no condition or penalty exists, that region is ordinary negative space.
It does not display `Normal`, `Safe`, an empty warning frame, or a future-state
placeholder.

When a registered audience-facing condition exists, the HUD projects only its
localized presentation, never a raw condition ID or predicate. A nonzero
current daily penalty may be shown as its exact audience integer without
explaining its cause, lifetime accumulation, or downstream mine formula. Zero
uses ordinary negative space. A terminal Day 8 state never projects through
this desktop HUD.

### 14.2 Forbidden facts

The global HUD never shows:

- affection, relationship tier, attitude, tone, or Dark points;
- Observer Pressure, Capture/Compare gates, evidence totals, or ending gates;
- hidden extra mines, board formulas, safety-capability formulas, or Shop
  stock;
- invitation eligibility, invisible branch state, or causal receipts; or
- a global Minesweeper round counter.

The signed round counter belongs inside Minesweeper under the accepted desktop
amendment.

## 15. Keepsake projection

### 15.1 Exact objects

The tableau contains three fixed generic object sockets:

- Bookend;
- Metronome; and
- Pocket Calculator.

Owned keepsake semantic IDs determine whether their corresponding object is
projected. All three may coexist.

### 15.2 Presentation-only boundary

Keepsakes are static, inert, nonfocusable, and nonclickable. They have no:

- friend or provenance label;
- tooltip, dialogue, reaction, sound, or animation;
- collision, inventory action, consume action, or placement control;
- evidence, fragment, Observer, relationship, ending, or schedule consumer; or
- randomized position, transform, depth, or degradation state.

The save stores ownership IDs only. Authored sockets, transforms, z-order, and
assets are projection facts.

Assistive description may name only the same generic visible object. It never
reveals a friend association or hidden meaning.

If final art is unavailable, a stable authored generic silhouette preserves
the visible owned-object projection. It never becomes a broken-image icon,
placeholder filename, or state-changing error.

## 16. Self-talk

### 16.1 Narrative and interaction boundary

Self-talk is audible, diegetic Angela muttering represented through the
accepted caption system. It is not narration, an invisible thought, an
interface assistant, or a personalized tutorial.

Ordinary self-talk:

- is ignorable;
- never blocks input;
- never creates a choice;
- never carries the only copy of a mandatory instruction;
- never mutates gameplay merely because it becomes visible;
- never auto-opens an app; and
- never enters Contacts, global dialogue History, Gallery, profile visited or
  skip-seen state, Observer evidence, echo state, or relationship logic.

### 16.2 Run/day-local state

Exact continuation uses primitive semantic state, never saved prose or Nodes.
One registered ordinary occurrence contains:

```text
SelfTalkOccurrence {
  occurrence_id,
  cue_id,
  source_event_token,
  parameters
}
```

`occurrence_id` is a stable idempotency identity. `source_event_token` names one
committed causal source, not a frame, localized string, Node path, wall-clock
value, or presentation-random result. `parameters` is a closed plain-scalar map
whose allowed keys and types belong to the cue manifest.

The run snapshot stores one day-local ordinary ledger:

```text
SelfTalkDayState {
  schema_version,
  cue_manifest_version,
  logical_day,
  handled_occurrence_ids,
  published_beats,
  pending_ordinary
}
```

- `handled_occurrence_ids` is a sorted unique list of admitted, replaced,
  suppressed, or published ordinary occurrence identities;
- `published_beats` contains at most three occurrences, oldest first; and
- `pending_ordinary` contains one unpublished occurrence or `null`.

The ledger stores stable semantic IDs and validated parameters. It stores no
localized prose, reveal progress, TTS progress, Node, Resource, focus, scroll,
animation, or Dark-refusal pin.

This ordinary ledger rewinds with the selected run save and clears on day
change or New Run. It is not profile-global memory. The canonical source event
and its admitted self-talk disposition must share one stable command boundary;
a snapshot cannot contain the event while omitting whether its occurrence was
handled, published, or retained pending.

A post-publication save restores the same visible semantic cue state without
rerunning the trigger, reveal, TTS, or live announcement. A pre-trigger save
does not inherit a later abandoned cue.

Locale, text-size, contrast, colour, and window changes reproject the same cue
IDs. They create no new self-talk receipt.

A compatible pre-shell save with no ordinary self-talk field migrates to an
empty ledger for its saved logical day and synthesizes no missed cue. A present
but malformed ledger, wrong-day value, duplicate occurrence ID, oversized
published list, undeclared parameter, or incompatible schema rejects before
live-state replacement. This narrow empty-ledger migration does not preserve or
reinterpret the separately retired Opening/tutorial fields.

### 16.3 Ordinary cue arbitration

Content registries admit cues through deterministic causal sequence, not
frame timing or presentation RNG.

Duplicate admission of a handled occurrence is an idempotent no-op. Publishing
atomically moves the pending occurrence into `published_beats`, trims an oldest
fourth beat, clears the matching pending slot, and records it as handled. A new
cue completes the prior visual beat before retaining it as a previous beat, so
partially revealed copy is never lost.

While self-talk publication is unavailable because a higher layer owns the
surface, a newly admitted ordinary cue replaces the prior unpublished ordinary
cue. There is never an unbounded queue.

When publication becomes safe, the latest retained cue publishes once. In
single-language mode, the current beat and prior two available beats use the
accepted caption stack. In Dual Language mode, only the current semantic beat
appears as Primary then Secondary.

Ordinary cues remain until superseded or the day/shell state clears them. They
do not use a lossy timed disappearance.

### 16.4 Dark Schedule refusal

When captured run Dark mode rejects a Schedule Done attempt, the refusal:

- appears in Angela's self-talk dock rather than a modal or toast;
- binds to the rejected command's run, branch, logical day, and relevant
  Schedule-view fingerprint;
- becomes the sole pinned current cue;
- keeps input focus on the Schedule Done control;
- has no independent X or Back dismissal; Back still follows the accepted
  Schedule/root-navigation law, and leaving Schedule through that law clears
  the pin;
- outranks and suppresses ordinary self-talk;
- survives app focus loss, text/language changes, Quick or manual Save, a
  cancelled confirmation, and temporary higher-layer obscuration; and
- clears only after a committed relevant Schedule-view change or actual
  departure from Schedule.

Its presentation fingerprint is a canonical hash over a version, run ID,
branch ID, current desktop-generation identity, logical day, captured Dark
Boolean, Schedule revision, and canonical Schedule-view signature. It contains
no localized prose, Control state, focus, animation, clock value, or
presentation randomness.

Repeated Done activation against the unchanged fingerprint returns the same
domain rejection without duplicating, restarting, or reannouncing the refusal.

When the pin clears, the one retained `pending_ordinary` occurrence may publish
through section 16.3. Replaced or otherwise suppressed ordinary occurrences do
not resurrect. A later new rejected Done attempt after returning to Schedule
may create one new pin and announcement for its new presentation boundary.

The visible pin is not the source of the domain rejection. Missing presentation
cannot permit the blocked Schedule action.

The pin is shell presentation state and is never serialized. A committed Load
is both run replacement and departure from the current Schedule projection, so
it clears the pin even when the selected save restores Schedule with an
equivalent view. Cancelling or failing Load leaves the current pin intact. The
next deliberate rejected Done after a successful Load may create a fresh pin.

### 16.5 Caption, TTS, and assistive behavior

Self-talk follows the accepted Settings language and reading law:

- no routine visible speaker label;
- an assistive speaker disclosure identifies Angela;
- Primary and Secondary order follows current language settings;
- system TTS speaks Primary only when Read Aloud is enabled;
- there is no recorded Angela voice;
- ordinary publication uses one polite announcement;
- a newly pinned action-blocking refusal uses one immediate status
  announcement; and
- Load, unocclusion, resize, locale change, or repeated unchanged Done does not
  reannounce it.

Skip may complete the current visual reveal but cannot add visited state or
suppress gameplay. Auto does not advance self-talk or leave an app.

At 150%, caption cards wrap and the dock consumes tableau height first. If the
accepted three-beat stack still exceeds the available safe height, the
self-talk region scrolls vertically without horizontal scrolling and keeps the
current beat in view. The region remains readable in the accessibility tree
without becoming a gameplay choice or blocking app focus. Any exposed semantic
scroll control obeys the active 48- or 64-logical-pixel target minimum.

An unknown or unresolved optional atmospheric cue is marked handled, projects
no cue, preserves every gameplay fact, and records an internal diagnostic. It
is a release-blocking content defect, not an anomaly. A missing authored
Dark-refusal localization uses the required truthful localized generic
refusal while the independent domain rejection remains authoritative. If that
generic refusal is also unavailable, Done remains blocked and the trusted
technical-recovery surface reports a presentation failure without exposing a
raw key.

## 17. Audience clock strip

### 17.1 Routine title and in-run clock

Both title and in-run strips use a compact tabular 24-hour `HH:MM` display with
no seconds.

Routine time is the audience device's current local civil time. It updates on
minute boundaries while foreground-eligible and refreshes immediately after
focus resume. It is presentation only and never:

- sorts or expires Contacts;
- controls Schedule, Day progression, Save order, board state, or deadlines;
- becomes character knowledge or Observer evidence;
- enters narrative History; or
- changes a frozen Backup save timestamp.

The clock is noninteractive and omitted from focus order. Assistive technology
may read it on deliberate semantic inspection, but routine minute updates are
not live-announced.

If the system clock cannot be read, the visible strip shows a stable localized
unavailable token such as `--:--`, and its semantic label states that time is
unavailable. It never displays stale prior time as current.

### 17.2 Title exclusion

The title clock is always truthful. It cannot allocate, materialize, resume, or
preview a run clock anomaly.

### 17.3 In-run rare clock anomaly

The in-run strip consumes the Contacts-owned shared run allocation:

`none | desktop_clock_strip(window_id) | contacts(message_id)`

This amendment does not rerun the 1-in-16 gate or create a second arbiter. When
the allocation targets one exact experienced desktop window:

1. the registered window supplies stable start and end boundaries;
2. its versioned manifest row supplies a deterministic nonzero wrong-time rule;
3. materialization freezes the resulting displayed `HH:MM` once;
4. one same-run monotonic presentation receipt records materialization;
5. the frozen wrong value persists through app hiding, focus loss, and refocus
   during that registered interval;
6. the clock resumes truthful routine time permanently after the interval; and
7. older saves from the same run reattach the receipt/value and cannot replay,
   reroll, or relocate it.

The wrong-time rule may be a nonzero minute offset or an explicit frozen value,
but it must guarantee a different displayed minute modulo 24 hours. Exact
manifest calibration is content data; zero, live-random, frame-derived, or
mechanics-derived values are invalid.

An allocated interval that is never experienced creates no replacement
anomaly. A genuinely new run owns a new shared allocation.

The anomaly never changes canonical sequence, timers, app state, input,
mechanical RNG, save time, or character knowledge. No sound, tooltip, glitch,
later line, Gallery entry, or system warning confirms it.

## 18. Global layers and safe regions

### 18.1 Priority and ownership

The shell composes these layers from highest to lowest:

1. technical or transaction recovery;
2. trusted blocking confirmation, consent, or Schedule warning;
3. protected narrative text, the pinned Dark refusal, dialogue choices, and
   required app transaction controls;
4. nonblocking Contacts toast and truthful Quick-status surfaces in compatible
   safe regions; and
5. ordinary app presentation, HUD, tableau, and self-talk.

This order does not permit a higher visual z-index to cover essential text.
Protected content reserves geometry; a toast or status queues when no safe
region exists.

### 18.2 Technical recovery

Technical recovery may occupy the full logical canvas. All lower input is
inert. Public presentation timers pause after any already-admitted bounded
operation reaches its recorded safe frontier.

The surface is visually cleaner and more neutral than atmospheric chrome. It
uses factual localized copy and only registered recovery actions. It contains
no horror treatment, fake code, character attribution, or raw internal data.

### 18.3 Blocking modal or warning

An in-run confirmation or Schedule warning remains within the computer-content
safe rect `x=496..1264`, `y=80..704`, up to 560 logical pixels wide. Its body
may scroll vertically; its 48/64-pixel actions remain pinned.

It traps focus, starts on Cancel/No where destructive or replacing action is at
stake, and makes Home, the app, and launcher inert. Back means its accepted
cancel/close action.

Title confirmations remain within the title-workfield safe rect
`x=336..1264`, `y=80..704`, up to 560 logical pixels wide, and make the ledger
inert under the same rule.

### 18.4 Contacts toast

The Contacts toast's preferred candidate is the lower-right computer content
area, at most 320 logical pixels wide with 16-pixel right and bottom insets. It
never covers:

- the app strip;
- a modal or recovery plate;
- focused controls or focus outlines;
- dialogue choices or captions;
- Contacts transcript content needed for the active action;
- a Shop/Backup/Schedule transaction dock or essential status; or
- Angela's self-talk.

If no compatible safe candidate exists, the toast remains queued under its
accepted Contacts law. Its eligible-foreground timer pauses while suppressed
or deliberately focused. It never steals focus.

### 18.5 Quick status and other truthful edge status

The accepted noninteractive Quick `Saving...`/`Saved` status uses the same
safe-region arbiter and yields to the Contacts toast, protected text, modal,
and recovery surfaces. It does not become a message toast, play sound, take
focus, or cover Angela.

### 18.6 Self-talk under higher layers

A higher layer never deletes or mutates self-talk canonical presentation state.
New low-priority publication and live announcement waits while incompatible.
If existing self-talk is visually obscured, reveal/hold timing pauses.

Self-talk TTS stops when a higher-priority textual surface takes speech
ownership and never automatically replays on uncover. The stored visual state
returns silently; then at most the one retained unpublished ordinary cue may
publish.

## 19. Language, accessibility, motion, and colour

### 19.1 Localization

Every player-facing label, title, status, accessible name, refusal fallback,
clock-unavailable token, and confirmation uses registered localization keys.
Layout direction follows the active locale without changing semantic launcher
order or app identity.

Long text wraps vertically. The shell never uses a narrower font, smaller text,
ellipsis, or image text to preserve geometry.

### 19.2 Focus and semantic parity

Visual and assistive representations expose the same operational facts.
Assistive output does not reveal hidden stats, Dark causes, keepsake friend
associations, clock-anomaly source, app cache, route IDs, or internal error
codes.

Focus, selection, unread, current, unavailable, disabled, warning, and danger
use independent semantic states and non-colour evidence. Focus remains visible
for keyboard/controller operation regardless of decorative focus preferences.

### 19.3 Motion

Reduced Motion turns shell transitions, app swaps, tableau pose changes, and
auto-scroll into static swaps or jumps. It does not change input admission,
route order, app cache, self-talk order, clock boundaries, or command results.

Flicker, strobe, scanline shimmer, layout jitter, fake lag, drifting marks, and
animated corruption are prohibited in every mode.

### 19.4 Colour and contrast

The Settings-owned effective palette tuple applies to functional shell
surfaces, text, focus, selection, warning, disabled, and status tokens.

Character art, background art, keepsake pixels, and narrative image tints are
not recoloured by High Contrast or Colour Differentiation. Functional overlays
on top of art use the selected tuple and non-colour evidence.

Captured run Dark mode selects that run's functional base palette and Dark
self-talk source. It does not recolour Angela or props, create an evil portrait,
or expose unlock history.

## 20. Visual direction

### 20.1 Material hierarchy

The shell uses this hierarchy:

- approximately 70% late-1980s/early-1990s university workstation grammar;
- approximately 20% disciplined ink and exhausted-paper material logic; and
- approximately 10% restrained retro/liminal dreamcore colour tension.

The percentages describe emphasis, not compositing math.

### 20.2 Allowed treatment

Allowed visual behavior includes:

- square geometry and one-pixel light/dark seams;
- limited desaturated paper, soot, green-grey, faded blue, bruised lavender, or
  warm institutional-cream relationships;
- static, low-contrast ordered dither on broad noninteractive planes;
- hard-edged pixel-hinted icons and typography with complete CJK fallback;
- restrained authored registration marks outside interactive regions;
- large stable negative space;
- fixed, truthful tabular values; and
- subtle board- or panel-wide tonal tension that never encodes state.

The machine should feel old, maintained, and institutionally ordinary. It
must not read as cheaply manufactured, broken, or nostalgically imitated.

### 20.3 Forbidden treatment

The shell forbids:

- Windows-95 cosplay, arcade fonts, smiley-face branding, or neon retro kitsch;
- CRT curvature, scanlines, VHS noise, RGB split, glitch wipes, fake crashes,
  fake diagnostics, or compression damage;
- random per-control offsets, moving icon positions, fractional blur, clipped
  glyphs, placeholder files, or broken sprites;
- blood, rust, occult symbols, talismans, ornamental Daoist shorthand, or
  generic East-Asian mysticism;
- changing texture based on save age, relationship state, anomaly, danger, or
  hidden mechanics; and
- decorative error codes, false timestamps, phantom apps, disappearing
  controls, or cursor possession.

Daoist-informed emptiness may guide spacing and non-forcing interaction.
Phenomenology may guide the familiar tool becoming strange through attention.
Neither becomes a lore label or horror explanation.

## 21. Persistence and recovery

### 21.1 Canonical saved shell facts

The run save preserves only validated primitive semantic facts required for
exact continuation, including:

- canonical route and active app identity;
- captured run Dark configuration through its Settings-owned field;
- the ordinary day-local self-talk ledger defined in section 16;
- keepsake ownership through the Shop/economy owner;
- the shared clock-anomaly allocation and same-run materialization receipt
  through their accepted owners; and
- every app's own canonical state under its accepted law.

### 21.2 Never-saved presentation facts

The save never stores:

- shell or app Nodes;
- launcher or ledger focus;
- Return/Home hover or pressed state;
- local app instances or cache objects;
- pixel scroll offsets except any explicitly canonical Schedule view fact;
- open modal, toast lifetime, Quick status, Dark-refusal pin, self-talk reveal
  progress, or TTS playback position;
- matte-bar size, window pixel position, or OS scaling; or
- clock timer handles or routine current time.

### 21.3 Day change

After the exact day-resolution transaction finishes and the next clean desktop
becomes available:

- all app presentation caches clear;
- active app becomes `null`;
- launcher focus becomes Minesweeper;
- prior-day ordinary self-talk and Dark-refusal pins clear;
- keepsake ownership and other run-canonical state persist; and
- no Opening/tutorial state is consulted.

### 21.4 Logout and return to title

Logout retains its accepted Yes/No and exact Autosave law. Success routes to
the title shell only after the save commits. Failure stays in-run with truthful
recovery and preserves the current app/board state.

Returning to title projects the current pending next-run Dark selector,
normally Off after a successful New Acc, rather than the departed run palette.
The title clock is routine truthful time.

### 21.5 Failure and retry

Shell failure never becomes diegetic horror. The host:

- retains or reconstructs the last committed state;
- does not publish a destination app before it is prepared;
- prevents duplicate route, cue, or anomaly materialization;
- exposes concise localized recovery actions;
- keeps raw errors, paths, hashes, stack traces, and Node names internal; and
- never claims success before durable or validated publication.

Retry reuses the same prepared semantic operation where required. Cancel or
Return-to-Title follows the governing recovery contract and cannot silently
drop a committed run mutation.

## 22. Component and interface ownership

### 22.1 Desktop Host

The retained Desktop Host owns:

- the closed app registry projection;
- launcher/app visibility;
- active app identity handoff;
- app prepare/show/hide lifecycle;
- same-day cache lifetime;
- Home and return-focus anchors;
- host focus boundaries; and
- safe integration with route and overlay coordinators.

It does not own app gameplay, saves, clocks, self-talk content, Shop ownership,
or Schedule rejection.

### 22.2 Title shell owner

The title shell owns ledger composition, workfield hosting, title focus, Return,
and title clock placement. It consumes but does not own Backup records, profile
preferences, Gallery state, Dark entitlement/intent, or New Run transaction
law.

### 22.3 Run lifecycle and SaveManager

Run lifecycle and SaveManager retain sole ownership of New Acc/New Run,
Autosave, Load, Logout, validated route/app snapshot facts, atomic publication,
and recovery. The shell emits typed intents and projects results.

### 22.4 Angela panel projector

The Angela panel projector consumes a detached audience-safe view containing
only approved HUD fields, effective presentation settings, generic keepsake
ownership, Angela art state, and self-talk projection. It cannot query broad
GameState or derive hidden relationship/ending facts.

### 22.5 Self-talk coordinator

One self-talk coordinator owns cue admission, causal sequence, unpublished
replacement, recent published cue IDs, Dark pin identity, projection receipts,
and TTS/live-announcement arbitration. Content registries supply stable cue IDs
and trigger facts. Schedule owns the actual Dark rejection.

### 22.6 Clock owners

The system-clock adapter supplies routine local time only. The Contacts-owned
shared clock-anomaly arbiter owns run allocation and manifest identity. A
desktop clock projector materializes only its allocated strip target and cannot
allocate, reroll, or write gameplay state.

### 22.7 Overlay arbiter

One shell overlay arbiter owns global safe-region compatibility, input
priority, timer eligibility, focus traps, and restoration anchors. It does not
invent notification content or command outcomes.

## 23. Technical truth and error behavior

### 23.1 Ordinary disabled states

Disabled, unavailable, current, and empty are visible and semantically distinct.
They do not rely on opacity or colour alone.

Examples include:

- Home current on the launcher;
- absent Dark selector before entitlement;
- an app action disabled by its own canonical state; and
- unavailable system time.

### 23.2 Missing presentation assets

Missing nonsemantic art uses a registered generic fallback or omits decoration
without changing semantic state. It never exposes an asset path, broken-image
badge, or fake corruption.

An owned keepsake with missing art uses its established safe inert silhouette
in the authored socket and retains the same generic accessible object name.
Missing Angela or tableau art uses a safe noninteractive fallback while HUD and
self-talk remain functional. None of these fallbacks changes ownership, Dark
state, focus, save restoration, or mechanics.

A missing required app scene, localization bundle, or semantic projection is a
technical failure. It does not masquerade as empty space or an anomaly.

A required HUD label resolves through the accepted locale fallback chain. If
it still cannot resolve, the projector retains the prior complete functional
HUD and enters trusted recovery rather than showing an unlabeled number or raw
ID.

### 23.3 Failure copy

Player-facing failure copy is concise, localized, and factual. It distinguishes
safe unchanged state from pending recovery. It never attributes failure to
Angela, a friend, Observer Pressure, or the university OS as a character.

## 24. Exact supersession and retained law

### 24.1 Controlling shell decisions

This accepted amendment supersedes only the following conflicting target
behavior:

- Aug-07 semantic inventory entries `opening.day1` and
  `tutorial.desktop_day1`;
- runtime/profile/save expectations for `opening_seen` and `tutorial_seen`;
- the current Opening route and Day-1 tutorial-overlay sequence;
- recovered title composition that uses a small upper-left panel;
- recovered launcher tail order that differs from Backup, Settings, Log out;
- current app-window X/title-bar/draggable-window assumptions;
- current global HUD exposure of Minesweeper rounds;
- current 44-pixel ordinary shell-target assumptions;
- any shell topology that rearranges at 125% or 150%; and
- any title or desktop clock behavior that conflicts with sections 17 and 21.

The target retirement surface includes, at minimum:

- `autoload/SceneRouter.gd` Opening route/start decision;
- `autoload/SaveManager.gd` initial-context requirement and
  `scripts/ui/MenuScene.gd` New Acc route preparation;
- `autoload/GameState.gd` Opening/tutorial fields and commands;
- `scripts/domain/run/RunSnapshotSchema.gd` matching save leaves;
- `scenes/opening/OpeningScene.tscn` and `scripts/ui/OpeningScene.gd`;
- `scenes/overlay/TutorialOverlay.tscn` and
  `scripts/ui/TutorialOverlay.gd`;
- `scenes/main/MainGameScene.tscn` tutorial host and
  `scripts/ui/MainGameScene.gd` tutorial launch path;
- `dialogic/timelines/en/core/opening_day1.dtl` and
  `dialogic/timelines/en/core/tutorial_desktop_day1.dtl`;
- `project.godot` Dialogic registrations;
- `data/manifests/timelines.json` and `data/manifests/routes.json` matching
  records;
- Opening/tutorial-only rows in `scripts/data/AudioManifest.gd`, including
  `opening_forget_me_not`, `tutorial_soft_screen`, and their exclusive contexts
  when no retained consumer exists;
- the already-retired tutorial-replay preference leaf and localization row
  under the accepted Settings migration law;
- manifest, localization, audio-context, scene-inventory, smoke, fixture, and
  test references that exist only for those artifacts; and
- proposed/hash-bound plan steps that still require their target existence.

This list is a future reconciliation/deletion inventory, not implementation
authorization.

The accepted semantic presentation inventory consequently changes from 139 to
137 entries, and the Day-1 count changes from 10 to 8 while retaining the same
eight day-master identities. Adapter, restore, visited-line, and persistence
tests that currently use an Opening line merely as arbitrary fixture data must
be replaced with retained semantic fixtures rather than losing their coverage.
Generic controls such as Continue or Finish remain when another retained
surface uses them; target retirement is by semantic ownership, not filename
guessing.

### 24.2 Retained law

This amendment retains without reinterpretation:

- the exact seven semantic desktop app IDs;
- one visible app and same-day app continuity;
- Minesweeper lifecycle, board identity, costs, persistence, and cross-app law;
- Contacts opening, message, toast, timestamp, and clock-allocation law;
- Schedule drafting, Done, warning, condition, and departure law;
- Shop catalogue, purchases, keepsakes, and condition-check law;
- Backup records, consent, Save/Load/Delete, timestamps, Quick shortcuts, and
  recovery law;
- Settings language, caption, TTS, audio, inactive suspension, Dark capture,
  controls, text size, target size, colour, and reset law;
- Logout Autosave and failure law;
- dialogue-led story delivery, sparse source-authored anchor-bound perception,
  no narrator identity or unrestricted thought box, and the audible-self-talk,
  visual, sound, epistemic, and Observer boundaries; and
- every unrelated run, relationship, Hospital, ending, Gallery, and persistence
  rule.

## 25. Reconciliation path before implementation

Acceptance of this artifact does not authorize reconciliation or runtime work.
A separately authorized reconciliation must:

1. create a successor authority-reconciliation issue rather than reopening or
   widening closed `dwm-0hi`;
2. register this design amendment in the machine-resolvable design-authority
   pipeline and update the `docs/design` authority explanation;
3. update `prompt_docs/requirements/authority_context.md` so the new scoped
   authority is discoverable;
4. add or replace exact requirement rules for shell canvas, title, launcher,
   host, self-talk, clock projection, overlays, accessibility, and
   Opening/tutorial retirement rather than creating conflicting duplicates;
5. regenerate `prompt_docs/INDEX.md` byte-for-byte through the repository tool;
6. record explicit retained/replaced/superseded dispositions for overlapping
   desktop, lifecycle, persistence, localization, audio, and verification
   packets;
7. update `dwm-oyo.1`'s authority handoff and prevent it from starting against
   obsolete shell law;
8. amend or replace the affected hash-bound OYO plan artifacts rather than
   editing approved hashes silently;
9. rebind `dwm-oyo.3` to the reviewed successor plan and this authority before
   it implements production shell composition;
10. add shell-specific implementation and verification ownership, or an exact
    bounded child of `dwm-oyo.3`, without duplicating its desktop owner;
11. add the complete shell matrix to `dwm-oyo.7`'s release evidence only after
    upstream implementation closes;
12. reconcile New Run, run snapshot, route, active app, self-talk, clock, and
    profile schemas under their sole owners;
13. retire the complete Opening/tutorial target inventory without adding a
    migration path;
14. reconcile the semantic manifest total to 137 and Day-1 total to 8 while
    retaining eight day masters and replacing, rather than dropping, unrelated
    adapter/restore test coverage;
15. reconcile scene trees, app host interfaces, localization, art/audio
    manifests, accessibility semantics, and focused tests; and
16. retain `implementation_authorized: false` until the user separately grants
    runtime authority.

Current unrelated dirty work, especially Shop and Beads files, must not be
absorbed into this documentation change.

## 26. Verification matrix

### 26.1 Canvas and title

Verify:

- exact 1280-by-720 logical bounds;
- Windowed and Borderless uniform aspect preservation;
- inert pillarbox/letterbox margins at wide, tall, and exact-16:9 displays;
- no input remap from margins;
- exact 320/960 title split and 64-pixel workfield strip;
- empty title workfield with no placeholder content;
- exact ledger order with Dark absent before entitlement and present directly
  below New Acc afterward;
- fresh focus New Acc and no phantom Dark focus stop;
- Log in, Gallery, and Settings host/Return behavior;
- nonmodal ledger switching and modal/busy/recovery inhibition;
- title clock truth, unavailable state, focus exclusion, and no anomaly; and
- Shut down confirmation, Cancel-first focus, and no save deletion.

### 26.2 New Acc and retirement

Verify:

- New Acc replacement consent under every Autosave/live-continuation case;
- Dark Off and On capture, cancel, retry, rollback, and atomic publication;
- initial route main, active app null, Day 1, initial Autosave, and launcher
  Minesweeper focus;
- no light-palette flash during a captured Dark start;
- zero runtime/manifest/schema/scene/test inventory for Opening and tutorial;
- no `opening_seen`, `tutorial_seen`, semantic IDs, visited IDs, aliases,
  migration, tombstones, or replacement receipts; and
- target rejection of unsupported development artifacts that require retired
  fields/routes without mutating current valid state.

### 26.3 In-run geometry and launcher

Verify:

- exact 480/800 split and 64-pixel computer strip;
- exact 800-by-656 app content area;
- Home current/disabled/nonfocusable on launcher and enabled in apps;
- complete localized Home/app titles and tabular clock;
- fixed launcher order, cell coordinates, gutters, empty eighth slot, and lower
  negative space;
- spatial focus graph, row-major Tab, no wrap, and no move into empty slot;
- focus/hover/selection do not activate;
- click, tap, keyboard, controller, and assistive activation parity; and
- no draggable windows, X buttons, taskbar, parallel title bars, or overlap.

### 26.4 App host, routing, and cache

Verify:

- one visible app under every direct, indirect, rapid, and failure case;
- prepare-before-publish and last-stable-shell retention on failure;
- semantic app-first focus, Home access, root Back, and launcher Back no-op;
- exact Back layer-by-layer retreat, blocking-state Home inertia, safe direct
  Home return, and one input producing one action;
- no Home cancellation of admitted bounded work;
- same-day hide/reopen preserving only each app's allowed cache;
- direct return to source/destination icon and indirect return to actual
  destination icon;
- day change clearing caches and returning launcher/Minesweeper;
- valid Load active-app reconstruction for all six stable content-app IDs and
  null;
- rejection of `logout`, unknown, and incompatible route/app snapshot values;
- app-specific clean Load projections;
- invalid app ID rejection without current-state mutation;
- scene-construction recovery without silent app fallback; and
- no saved modal, toast, focus NodePath, hover, or cache.

### 26.5 Angela HUD and tableau

Verify:

- baseline 30/44/26 regions and tableau-yields-first growth at 125%/150%;
- no functional text clipping, shrinking, overlap, or horizontal scroll;
- audience-safe HUD fields and exact numeric projection;
- internal Pressure 10 through 12 displaying 9 without hidden-range leakage;
- internal Health minus 1 and minus 2 displaying 0 without hidden-range
  leakage;
- visible maxima, signed currency, registered condition, and nonzero daily
  penalty projection without raw predicates or formulas;
- absent condition/penalty using ordinary blankness;
- prohibited hidden facts and global Minesweeper counter absent;
- non-geographic tableau copy and no accidental residence claim;
- restrained/static Reduced Motion behavior;
- all eight combinations of the three keepsake ownership facts, including none
  and all three together;
- save-before/save-after/load/new-run keepsake projection;
- fixed sockets and no saved transforms;
- inert/nonfocusable/no-mechanics keepsakes;
- assistive parity without friend association; and
- missing-art fallbacks preserving ownership without broken placeholders.

### 26.6 Self-talk

Verify:

- deterministic cue admission and causal ordering;
- exact ordinary-ledger shape, uniqueness, three-beat bound, and closed
  parameters;
- one unpublished latest-ordinary replacement under blocked publication;
- single-language three-beat and dual-language current-beat projection;
- no Contacts, History, Gallery, visited, Observer, echo, or relationship
  mutation;
- save before trigger, during reveal, after publication, and after replacement;
- no duplicate reveal, TTS, or live announcement after Load;
- absent-field empty-ledger migration and malformed-present-ledger rejection;
- day/New Run clearing and branch rewind;
- language/text/contrast/colour changes reprojecting without new receipt;
- Dark refusal fingerprint, pin, focus retention, priority, Save remaining
  nonmutating, committed Load clearing the unsaved pin, and exact invalidation;
- repeated unchanged Done producing no duplicate text/TTS/announcement;
- leaving Schedule clearing the pin and suppressed cues not resurrecting;
- missing optional cue versus missing refusal localization behavior;
- higher-layer speech ownership and silent unocclusion; and
- 150% overflow keeping current text reachable without app blockage.

### 26.7 Clock and anomalies

Verify:

- routine local 24-hour `HH:MM`, minute update, focus-resume update, and no
  seconds;
- clock adapter failure showing truthful unavailable state, never stale time;
- noninteractive/focusless behavior and no routine live announcements;
- title exclusion from anomaly under fresh, logged-out, and save-present cases;
- shared allocation identity and no second 1-in-16 gate;
- every eligible window's deterministic nonzero wrong-time guarantee;
- frozen materialization, interval lifetime, hide/refocus persistence, and
  permanent truthful resume;
- old same-run saves cannot replay, reroll, relocate, or resample;
- unexperienced allocation gets no replacement;
- new run isolation; and
- no effect on mechanics, sequence, deadlines, save timestamps, character
  knowledge, evidence, or unrelated RNG.

### 26.8 Layers and technical trust

Verify:

- recovery, modal/warning, protected text, toast/status, and ordinary-layer
  ordering;
- focus trap and exact focus restoration;
- modal body scrolling with pinned actions at 48 and 64 targets;
- Contacts toast safe candidate, queue, timer pause, and no focus theft;
- Quick status yielding without collision;
- captions, choices, focused controls, transaction docks, essential status,
  and self-talk never covered;
- focus loss and quiet-suspension interaction;
- public timers pausing while ineligible or obscured;
- canonical work and admitted bounded commands remaining exact;
- concise localized nonfiction recovery;
- no raw diagnostic leakage, fake crash, fake corruption, or horror error; and
- Retry/Cancel/Return-to-Title idempotency at every route and projection stage.

### 26.9 Text, targets, colour, and input matrix

Verify the cross-product selected for release across:

- 100%, 125%, and 150% text;
- ordinary 48-pixel and Large 64-pixel targets;
- both base palettes;
- High Contrast Off/On;
- Standard, Protan, Deutan, and Tritan differentiation;
- every supported UI locale and direction;
- single and Dual Language self-talk;
- Reduced Motion Off/On;
- keyboard, controller, pointer, touch, and assistive activation;
- Windowed and Borderless modes; and
- focus loss/resume at every shell and overlay layer.

The concrete release matrix must enumerate tested Windows display scales and
supported locales. This document does not claim 200% text or universal
accessibility conformance.

## 27. Acceptance and next design sections

The user approved the conversational design and the exact self-reviewed written
artifact on 2026-08-12. Placeholder, contradiction, authority, ambiguity,
accessibility, and adversarial self-review passed, and every actionable finding
was corrected before approval. This document now records
`decision_status: accepted`, `written_spec_status: approved`, and
`self_review_status: passed`.

Implementation remains unauthorized.

The next recommended bounded UI/UX section is the shared Gallery/Rehearsal
archive shell, followed by the shared narrative-scene/dating host. Neither may
silently reinterpret this shell amendment.
