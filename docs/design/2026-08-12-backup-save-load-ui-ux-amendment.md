---
id: spec.backup_save_load_ui_ux_amendment
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
verification_engine: 4.6.3-stable-mono
language: gdscript
scope: ["backup_record_projection","backup_save_load_delete_interaction","backup_quick_shortcuts","backup_time_and_recovery_presentation","backup_view_cache_and_accessibility","backup_visual_trust"]
---

# Backup Save/Load UI/UX Amendment

## 1. Status and objective

This accepted written amendment records the conversationally approved Backup,
Save, Load, Delete, quick-shortcut, recovery, and archive-cabinet design
discovered while preparing the game's future UI/UX, visual-art, and music/audio
manuals.

The objective is to make Backup the game's calmest and most trustworthy
software surface. It may look like a rough, old university archive rendered in
ink on tired paper. It may feel overly still, empty, and slightly wrong. It may
never manufacture that unease by lying about a save, hiding a record, changing
slot order, falsifying time, simulating corruption, or disguising a technical
failure as fiction.

The user approved this exact written artifact on 2026-08-12 after self-review.
It is bounded written authority within its declared scope. Approval does not
authorize implementation. Requirements, Beads, hash-bound plans, schemas,
tests, scenes, localization catalogs, and runtime code remain unchanged.

### 1.1 Approved derived closures

The conversation fixed the product direction while leaving a few operational
details implicit. This written pass records the following closures so the
design is deterministic and testable. Approval of this exact artifact accepts
them within scope:

- The nine visible drawers bind commands by semantic record locator, never by
  the order returned from a storage enumeration.
- Moving keyboard or gamepad focus among drawers also changes the selected
  presentation drawer and refreshes the inspector. Hover never does so.
- A normal valid Quick record is replaced directly. Any nonempty Quick record
  that is not an ordinary readable current checkpoint, including
  `fallback-loadable` and `Unavailable`, is treated as occupied: explicit
  replacement requires confirmation, and global F5 refuses rather than
  silently destroying it.
- A loadable earlier compatible checkpoint belongs to the selected record. It
  is never borrowed from another drawer or from the live crash-recovery
  journal.
- The drawer continues to show the selected record's safe latest-document
  metadata rather than calling the whole record `Unavailable`.
  The inspector separately shows the exact earlier Day and frozen time that
  would actually load.
- In-run fallback disclosure and live-continuation replacement consent share
  one confirmation. They never form two stacked dialogs. Title fallback still
  requires `Load` and `Cancel` because the selected latest checkpoint is not
  the checkpoint that will load.
- A confirmation binds the record kind, semantic locator, validated document
  revision or fingerprint, and the Day/time displayed for its prepared target.
  A changed target requires fresh consent.
- Normal title Load prepares and validates the selected whole checkpoint before
  committing, even though it requires no ordinary live-progress confirmation.
- The save timestamp is captured once when a stable save transaction is
  prepared for durable publication. A retry of that same transaction retains
  the same timestamp.
- F5 pressed during one bounded domain command coalesces into one Quick Save of
  the first subsequent admissible stable revision. It never waits through a
  confirmation, restore, fatal recovery, run replacement, or unresolved route
  replacement.
- F9 never queues a future surprise Load. When Quick Load cannot be prepared
  immediately, it reports a terse truthful unavailable or wait state.
- A prepared fallback Quick record counts as usable for F9 and opens the one
  combined fallback-and-replacement confirmation.
- The global Quick status occupies a trusted non-occluding system layer. It
  yields to captions, dialogue choices, confirmations, and technical recovery
  rather than covering them.
- Loading a save whose active app is Backup reconstructs a clean in-run Backup
  view at `Save` plus `Slot 1`; it never restores a modal, transient message,
  pointer state, or view cache.
- The title cabinet uses the current trusted menu/next-run palette until Load
  commits. The restored run palette applies atomically with the successful
  route replacement.
- Each drawer's decorative ink/paper fingerprint is authored from its logical
  drawer identity alone. It is identical across profiles, runs, installations,
  locales, and save states and consumes no runtime random stream.

These closures carry the same bounded authority as the approved conversational
design.

## 2. Authority and precedence

### 2.1 Authority spine

This amendment controls intended behavior within its six frontmatter scope
topics over conflicting recovered documents, prompt packets, proposed or hash-
bound plans, tests, current storage enumeration order, and current Backup UI
scaffolds.

It narrowly supplements and amends the accepted 2026-08-11 Desktop
Minesweeper, Shop, and Schedule amendment. That amendment retains authority for
exact candidate/board saves, stable command boundaries, Load replacement,
numbered-slot deletion safety, Logout autosave, board fate, continuation
generation, and the rule that run replacement is not a forfeit.

The accepted 2026-08-07 Seven-Day Flow and Dialogic Structure design retains
authority for profile/run/branch ownership, relationship-board permanence,
old-save merging, semantic recovery, atomic writes, whole-state compatibility,
and every unrelated narrative, Hospital, ending, Gallery, and Observer rule.

The accepted Contacts and Shop amendments retain authority for their own
canonical state and post-Load presentation-reset laws. This Backup amendment
does not reinterpret their app-local caches or transactions.

Beads owns mutable work status, dependencies, and implementation evidence. A
written design approval does not authorize code, schema, requirement, plan,
test, or Beads mutation.

### 2.2 Retained storage foundation

The retained persistence foundation supplies exactly:

- seven numbered manual records, identified as Slots 1 through 7;
- one Quick record; and
- one Autosave record.

It also supplies primitive validated save documents, atomic replacement,
last-known-good protection, exact whole-checkpoint restoration, and one
recoverable transaction journal. This amendment designs their player-facing
projection and consent grammar. It does not create a second storage owner or a
second restore path.

`SaveManager` remains the sole save-document I/O and restore coordinator. UI
drawers never receive raw paths, file handles, backup filenames, journals,
checksums, or mutable state objects.

### 2.3 Status is not execution authority

Current code and plans contain known drift, including an incomplete two-record
Backup grid, per-record action buttons, absent metadata binding, and an obsolete
active-board save lock. Those facts remain physical evidence only. The accepted
2026-08-11 stable-board save law already controls over the obsolete lifetime
board lock.

Nothing in this document authorizes implementation or silently expands an
existing Bead or hash-bound plan.

## 3. Scope

### 3.1 In scope

This amendment closes:

- the nine-record player-facing inventory and fixed visual order;
- the 3-by-3 archive-cabinet plus shared-inspector composition;
- in-run `Save` and `Load` modes and title-menu `Log in` mode;
- Save, Load, Delete, overwrite, fallback, and New Acc confirmation grammar;
- visible Day/time, `Empty`, and `Unavailable` metadata states;
- frozen audience-local save-time capture and projection;
- F5/F9 scope, coalescing, confirmation, and feedback;
- operation-busy, success, failure, and recovery presentation;
- exact focus, selection, Back, cache, and route-restoration behavior;
- 100%, 125%, and 150% text-size behavior;
- assistive parity and the nonfiction technical-trust boundary; and
- old-university, ink, paper, liminal, and Dark-palette visual constraints.

### 3.2 Out of scope

This amendment does not redesign:

- the canonical contents of a run snapshot;
- challenge anti-reroll, profile ledger, branch, or Rehearsal mechanics;
- automatic-save trigger timing already owned by lifecycle authority;
- Logout transaction ordering;
- cloud saves, platform accounts, Steam Cloud, file browsing, import, export, or
  save sharing;
- a tenth record, named records, folders, record sorting, or record search;
- the exact physical save schema or migration implementation;
- raw diagnostic tools or developer log format;
- mobile portrait composition;
- 200% text support, which remains a separately tracked future enhancement;
- final texture assets, icon assets, font files, or palette token values; or
- runtime, requirements, tests, plans, localization catalogs, or Beads work.

The exploratory three-tier meta-save and save-corruption-as-horror ideas in the
July session addendum are explicitly not adopted.

## 4. Chosen design and rejected alternatives

### 4.1 Chosen design: fixed archive cabinet plus inspector

Backup uses one stable master-detail surface:

- roughly three-fifths of the app content width belongs to a fixed 3-by-3
  archive cabinet;
- roughly two-fifths belongs to one shared record inspector and action dock;
- mode controls sit above the composition; and
- Home/Return remains part of the ordinary app shell.

This design preserves nine learnable physical positions while avoiding twenty-
seven small Save/Load/Delete controls. It also keeps long translations,
confirmation context, compatibility disclosure, and operation feedback in one
readable inspector.

### 4.2 Rejected: direct controls inside every drawer

Three actions inside every drawer are rejected. They create visual noise,
repeat destructive controls, produce a long keyboard focus sequence, encourage
accidental action, and fail earliest under 125% or 150% text.

### 4.3 Rejected: single vertical ledger

One ordered list would localize and scale easily, but it loses the fixed
physical-memory grammar the user approved. The stable 3-by-3 cabinet is a
deliberate product decision, not an inherited limitation of the scaffold.

### 4.4 Rejected: responsive topology replacement at 150%

The cabinet does not become a list or stacked page at 150%. Initial release
intentionally preserves positions at 100%, 125%, and 150%. Local wrapping and
inspector scrolling absorb text growth without changing topology.

### 4.5 Rejected: Backup horror anomalies

Backup does not fake corruption, alter timestamps, move drawers, resurrect a
deleted record, retain ghost metadata, show invented diagnostics, or attribute
system copy to a character. Horror comes from truthful rewind and from the
contrast between this calm archive and the rest of the game.

## 5. Record registry and cabinet order

### 5.1 Closed player-facing records

The player-facing registry contains exactly nine logical drawers:

| Visual index | Semantic record | Audience label |
|---:|---|---|
| 1 | `autosave` | `Autosave` |
| 2 | `quick` | `Quick` |
| 3 | `slot:1` | `Slot 1` |
| 4 | `slot:2` | `Slot 2` |
| 5 | `slot:3` | `Slot 3` |
| 6 | `slot:4` | `Slot 4` |
| 7 | `slot:5` | `Slot 5` |
| 8 | `slot:6` | `Slot 6` |
| 9 | `slot:7` | `Slot 7` |

The visual order is row-major:

| Row | Left | Center | Right |
|---|---|---|---|
| 1 | Autosave | Quick | Slot 1 |
| 2 | Slot 2 | Slot 3 | Slot 4 |
| 3 | Slot 5 | Slot 6 | Slot 7 |

No record disappears, moves, or changes label because of locale, save state,
corruption, affordability of an action, route, run, branch, profile, or time.
Storage enumeration order cannot alter this projection.

### 5.2 Drawer-visible state

Each drawer shows its identity plus exactly one primary state line:

- `Day N · HH:MM` for a readable occupied current record;
- `Empty` for a genuinely absent record; or
- `Unavailable` for an existing record whose current document cannot safely be
  used as an ordinary current checkpoint.

A record with a rejected current checkpoint but a validated earlier compatible
whole checkpoint is a separate `fallback-loadable` state and remains visibly
occupied. Its drawer keeps the current document's Day/time because its outer
metadata are trustworthy; the selected inspector separately discloses the
earlier load target. If safe outer structure or metadata cannot be read, the
record is `Unavailable` and compatibility fallback is forbidden.

The drawer never shows route, character, ending, board, challenge, playtime,
run ID, branch ID, checkpoint ID, version, save reason, filename, or recovery
journal information.

### 5.3 Inspector

The inspector repeats the selected drawer identity and its visible state at a
comfortable text measure. It may additionally show only operational facts
required for a safe action:

- `Autosave is created automatically.`
- `Can't read this save.`
- `Newer game version required.`
- `Only an earlier compatible checkpoint can be loaded.`
- the exact earlier target's `Day N · HH:MM` when fallback is possible;
- current operation state; and
- the applicable action dock.

It never exposes hidden game content or internal diagnostic identifiers.

## 6. Mode and title composition

### 6.1 In-run Backup

In-run Backup has two top-level modes:

- `Save`; and
- `Load`.

They are modes over the same nine drawers, not separate record pages. Changing
mode preserves the selected drawer and never moves or filters records.

The `Save` mode still shows Autosave in its normal top-left position. Selecting
Autosave shows a visible `Save` action in the shared dock, but that action is
disabled and paired with the truthful system-owned reason. Autosave is never
hidden merely because the audience cannot manually write it.

### 6.2 Title-menu Log in

The title-menu `Log in` button opens the same cabinet and inspector in a load-
only context:

- there is no disabled or decorative `Save` tab;
- Load and applicable Delete actions remain available;
- there is no live continuation to warn about for an ordinary current
  checkpoint; and
- closing restores focus to the title menu's `Log in` button.

Log in is not a one-click Continue shortcut and does not privilege Autosave
beyond its initial-selection rule.

### 6.3 App-shell relationship

Backup uses the normal trusted Home/Return and app-title grammar. It does not
create a nested desktop, file browser, operating-system title bar, or character-
voiced status surface.

## 7. Action matrix

### 7.1 Exact actions by record state

| Record and state | Save mode | Load mode / title Log in |
|---|---|---|
| Autosave, Empty | visible disabled `Save` | `Load` disabled; `Delete` disabled |
| Autosave, readable | visible disabled `Save` | `Load`; confirmed `Delete` |
| Autosave, fallback-loadable | visible disabled `Save` | disclosed fallback `Load`; confirmed `Delete` |
| Autosave, Unavailable | visible disabled `Save` | `Load` disabled; confirmed `Delete` |
| Quick, Empty | direct `Save` | `Load` disabled; `Delete` disabled |
| Quick, readable | direct replacement `Save` | `Load`; confirmed `Delete` |
| Quick, fallback-loadable | confirmed replacement `Save` | disclosed fallback `Load`; confirmed `Delete` |
| Quick, Unavailable | confirmed replacement `Save` | `Load` disabled; confirmed `Delete` |
| Numbered, Empty | direct `Save` | `Load` disabled; `Delete` disabled |
| Numbered, readable | confirmed overwrite `Save` | `Load`; confirmed `Delete` |
| Numbered, fallback-loadable | confirmed overwrite `Save` | disclosed fallback `Load`; confirmed `Delete` |
| Numbered, Unavailable | confirmed overwrite `Save` | `Load` disabled; confirmed `Delete` |

`Direct` means no confirmation. It never means no validation, no feedback, or
permission to bypass the stable-state and atomic-publication laws.

### 7.2 Save mode does not expose Delete

The Save-mode action dock contains Save only. Load mode contains Load and
Delete. Delete is not duplicated into Save mode.

### 7.3 Disabled actions remain truthful

A disabled action remains visually recognizable, exposes its disabled state to
assistive technology, and has a short operational reason when needed. It is
skipped as an action in sequential focus order and never accepts input.

The interface never uses a clickable-looking no-op as mystery or punishment.

### 7.4 Confirmation grammar

Localized wording may adapt grammar, but it preserves these exact facts and
verbs:

| Command | Title and essential body | Actions |
|---|---|---|
| Occupied overwrite | `Overwrite <record>?` and the selected record's visible Day/time or `Unavailable` state | `Overwrite`, `Cancel` |
| In-run current Load | `Load <record>? Unsaved progress in the current game will be replaced.` | `Load`, `Cancel` |
| In-run fallback Load | `Load earlier checkpoint? Only an earlier compatible checkpoint can be loaded — Day N · HH:MM. Unsaved progress in the current game will be replaced.` | `Load`, `Cancel` |
| Title fallback Load | `Load earlier checkpoint? Only an earlier compatible checkpoint can be loaded — Day N · HH:MM.` | `Load`, `Cancel` |
| Delete | `Delete <record>? This save will be deleted.` | `Delete`, `Cancel` |
| New Acc replacement | `Start a new account? Autosave will be replaced. Other saves will remain.` | `Start`, `Cancel` |

No modal uses a generic `OK`, names hidden game content, or promises an outcome
before the bound transaction commits.

## 8. Save transaction and feedback

### 8.1 Manual numbered Save

Saving into an Empty numbered slot proceeds directly. Saving into a readable or
Unavailable occupied numbered slot first opens an overwrite confirmation bound
to that exact target revision.

Confirmation does not yet claim that a new save exists. On approval, the save
coordinator captures or awaits the next admissible stable canonical revision,
prepares one detached document candidate, captures one save-time fact, writes
atomically, validates the durable winner, and only then publishes new drawer
metadata and `Saved`.

If the target record changed after confirmation preparation, the command does
not overwrite the replacement under stale consent. It refreshes and requires a
new confirmation.

### 8.2 Quick Save

A normal Empty or readable Quick record is replaced directly through the same
atomic save path. A fallback-loadable or Unavailable Quick record requires an
explicit inspector overwrite confirmation. Global F5 does not provide that
destructive consent and therefore refuses to overwrite either state.

Quick Save never creates a numbered record and never changes the selected
drawer or current app focus.

### 8.3 Autosave

Autosave is written only by the lifecycle's registered automatic triggers,
including retained Logout and day/ending boundaries. This amendment does not
add or remove trigger points.

Successful Autosave is silent. Failure cannot be silently treated as success:
the governing lifecycle/recovery surface reports any user-impacting unproven
persistence truthfully.

An Unavailable Autosave cannot be manually replaced through an invented UI
exception. A later registered lifecycle Autosave trigger follows the retained
storage owner's non-destructive write/recovery policy; this UI amendment neither
blocks that trigger nor authorizes overwriting an unproven current document.

### 8.4 Busy state

If one accepted save spans visible frames, Backup stays visible and shows static
`Saving…` in the inspector. It uses no spinner, fake percentage, animated disk,
or staged progress claim.

Only controls that could conflict with the prepared transaction become inert.
Inspection may continue. A route change that would make outcome ownership
ambiguous waits for the bounded transaction or follows the governing safe-
cancellation law; the UI never guesses.

### 8.5 Save success and failure

Manual and Quick Save stay in Backup after success. The same drawer remains
selected, metadata refreshes only after durable validation, and the inspector
shows restrained `Saved`. That local acknowledgment remains until selection,
mode, operation, or app visibility changes; it is not a timed toast.

A failed save keeps the previous record and prior metadata byte-equivalent and
shows:

`Couldn't save. Your previous save is unchanged.`

If no previous save existed, localized copy may use the truthful equivalent
`Couldn't save. No save was created.` The command offers only recovery actions
that actually exist, such as Retry and Cancel.

## 9. Load preparation, consent, and commit

### 9.1 Whole-checkpoint preparation

Load first reads, migrates, validates, and prepares one complete checkpoint with
all restore participants without mutating live state. It never mixes gameplay,
route, narrative, contacts, or other fields from different checkpoints.

The current checkpoint is preferred. Only typed content incompatibility may
select the newest earlier validated whole compatible checkpoint retained inside
that same record. Structural corruption, future schema, or unsafe outer data do
not silently fall back.

### 9.2 In-run Load

Every in-run Load asks for confirmation because it replaces the live
continuation. The copy may say that unsaved live progress will be replaced. It
does not mention a board forfeit, refund, punishment, character choice, or route
consequence.

The prepared candidate and exact selected record revision are bound to the
modal. The initial focus is `Cancel`; Back performs Cancel; focus is trapped;
and dismissal returns focus to the selected drawer or invoking Load action.

On `Load`, the coordinator revalidates the prepared target and commits the
atomic restore. A changed or invalidated target cannot be substituted.

### 9.3 Normal title Load

In title Log in, a readable current checkpoint loads without an ordinary live-
replacement confirmation. It still passes full non-mutating preparation and
validation before commit.

### 9.4 Earlier-compatible fallback

When the selected record's newest checkpoint is content-incompatible but one
earlier whole checkpoint is compatible, the inspector immediately discloses:

`Only an earlier compatible checkpoint can be loaded.`

It also shows that prepared target's exact `Day N · HH:MM`.

In-run activation opens one modal combining fallback disclosure with the live-
replacement warning. Title activation opens a fallback-only modal. Both use
`Load` and `Cancel`, with Cancel initially focused. There is no silent fallback
and no pair of sequential confirmations.

### 9.5 Load success and failure

Successful Load closes the pre-restore Backup instance and routes to the saved
semantic route and active desktop app after every canonical participant commits.

A failed Load leaves the current game and selected record unchanged and shows:

`Couldn't load. Your current game is unchanged.`

In title context, localized copy instead states truthfully that the save could
not be loaded. Failure does not route, substitute another record, create a new
run, or turn into fiction.

## 10. Delete

### 10.1 Scope

Autosave, Quick, and every occupied numbered record can be selected for Delete
in Load mode or title Log in. Every Delete requires confirmation, including an
Unavailable record.

Delete operates only on the selected semantic record. It may remove recovery
history embedded inside that save document as part of deleting the document.
It can never delete or mutate the separate live-run transaction/crash-recovery
journal.

### 10.2 Consent and result

The confirmation binds the exact occupied revision and starts on `Cancel`/`No`.
If the target changes while open, fresh consent is required.

Successful Delete stays on the same drawer, which becomes `Empty`. It leaves
the current live run, board, candidate, currency, Contacts, Schedule, and every
other record unchanged.

A failed Delete leaves the record unchanged and shows:

`Couldn't delete. The save is unchanged.`

## 11. New Acc and Logout boundary

### 11.1 New Acc

`New Acc` behaves like starting a new game. It creates a new run and branch
identity and never migrates a board or candidate from an older run.

It asks for confirmation only when starting would replace a live continuation
or a nonempty Autosave, including an Unavailable-but-existing Autosave. The
confirmation states that Autosave will be replaced. Quick and numbered records
remain untouched and loadable under their ordinary compatibility law.

An Empty Autosave with no live continuation requires no destructive warning.

### 11.2 Logout

This amendment retains the accepted Logout law: Yes writes the exact live run
to Autosave and routes to title only after persistence is proven. No/Cancel
does neither. Failure remains in-run with truthful Retry/Cancel recovery.

Logout never asks the audience to select a Backup drawer and never modifies a
numbered or Quick record.

## 12. Quick shortcuts

### 12.1 Scope

F5 and F9 are global convenience shortcuts only while a live run exists. They
are not active on the title menu. Their functionality remains fully available
through Backup controls, so keyboard shortcuts are not the sole input path.

They may be invoked at any admissible stable point in a live run, including:

- the desktop and any ordinary desktop app;
- dates and relationship challenges;
- Hospital scenes;
- endings; and
- visible or suspended Minesweeper candidates and boards under the accepted
  stable-command law.

They are blocked during a trusted confirmation, restore, fatal recovery,
unresolved route replacement, or another incompatible record mutation.

### 12.2 F5

F5 always targets Quick and never the currently selected drawer.

If the canonical state is stable, one Quick Save begins. If one bounded command
slice is still resolving, exactly one request waits for its first subsequent
admissible stable revision. Further F5 inputs coalesce into that same request.

The request cannot outlive a confirmation, restore, fatal recovery, run
replacement, or unresolved route replacement. It never wakes later and saves a
different run unexpectedly.

A fallback-loadable or Unavailable Quick record is not overwritten. The command
reports that Quick Save is unavailable and directs the audience to Backup
without exposing a raw cause.

### 12.3 F9

F9 always targets Quick Load. With a usable prepared Quick record, it opens the
ordinary in-run replacement confirmation. It never bypasses that modal.

With an Empty Quick record, it reports `No Quick Save`. A fallback-loadable
Quick record opens the combined fallback-and-live-replacement confirmation.
With an Unavailable record, F9 reports the same truthful compatibility or
technical state the Backup inspector would expose. If the context is
temporarily unsafe for preparation, it reports a restrained `Please wait` and
queues nothing.

### 12.4 Edge feedback

Outside Backup, an accepted F5 request uses one quiet noninteractive status at
the trusted screen edge:

- `Saving…` remains while a prepared request is pending; and
- `Saved` remains for two seconds of foreground UI time after durable success.

There is no sound, icon, notification card, animation, focus movement, or
twenty-second Contacts-toast reuse. A newer Quick status replaces the older
visible status. The system-status anchor never covers captions, dialogue
choices, confirmations, or technical recovery; it defers or relocates within
the trusted safe frame. Assistive technology receives one polite status
announcement.

F5 inside Backup uses the same edge status and refreshes Quick metadata without
changing selected drawer or focus. Successful Autosave never uses this status.

## 13. Save time and metadata truth

### 13.1 Captured fact

Every successfully published record owns one validated save-time fact captured
from the audience's local civil clock when the stable save transaction is
prepared. Persistence retains enough semantic data to preserve:

- the captured instant;
- the original local offset; and
- the exact frozen local 24-hour hour/minute projection.

The display is compact tabular `HH:MM`. A locale may substitute supported digit
glyphs, but it cannot reinterpret the saved fact as a current time, change the
value, or convert it into a story clock.

### 13.2 Publication

Button-down time, filesystem modified time, reread time, load time, and retry
time are not the saved-time authority. A retry of the same prepared transaction
retains the original captured fact. A genuinely new save transaction captures a
new fact.

The new Day/time does not become visible until the complete document is
durably written, reread, validated, and selected as winner. Failure retains the
prior visible metadata.

### 13.3 Isolation

Save time:

- never sorts or reorders drawers;
- may appear nonmonotonic after audience clock changes without implying an
  anomaly;
- is excluded from the Contacts clock-bleed family and every narrative,
  Observer, board, branch, and presentation-anomaly random stream;
- cannot expire content, advance a day, or unlock anything; and
- is ordinary nonfictional system metadata, not authored evidence.

## 14. Selection, focus, and navigation

### 14.1 Selection boundary

A drawer selection is presentation-only. It never Saves, Loads, Deletes,
accepts a confirmation, or mutates canonical state.

- Pointer click or touch tap selects.
- Keyboard or gamepad focus movement within the cabinet selects.
- Assistive activation selects.
- Hover is inspectable presentation only and never selects or focuses.
- Double-click and double-tap perform only the same selection. They never invoke
  the current mode's primary action.

### 14.2 Cabinet navigation

The cabinet is one spatial focus group:

- arrows and D-pad move through the visible 3-by-3 positions without wrapping;
- focus movement updates the inspector through selection;
- Up from the top row reaches the active mode control in-run;
- Right from the third column reaches the first enabled inspector action;
- Left from the inspector returns to the selected drawer;
- Down from any bottom-row drawer reaches ordinary Home/Return; and
- Tab order is mode, drawers row-major, enabled inspector actions, then
  Home/Return.

Title load-only mode omits the absent Save control from focus order rather than
leaving a meaningless disabled tab stop.

### 14.3 Modal focus

Every confirmation:

- makes background tabs, drawers, shortcuts, and actions inert;
- traps sequential and spatial focus;
- begins on `Cancel` or `No`;
- maps Back/Escape/B to Cancel;
- uses explicit action verbs rather than a generic `OK`; and
- returns focus to the exact source drawer or action on dismissal/failure.

Successful Load transfers focus only after the restored semantic route reports
ready.

## 15. View cache and restore

### 15.1 First opening

The first in-run Backup opening or a reset opening uses:

- `Save` mode;
- `Slot 1` selected; and
- focus on `Slot 1`.

The first title Log in opening re-evaluates current records and selects:

1. Autosave if it has a loadable current or approved compatible fallback;
2. otherwise the first loadable drawer in visible row-major order; or
3. Autosave with Load disabled if no record can load.

### 15.2 Same-day presentation cache

Home/app switching and same-logical-day reopening retain only:

- selected mode;
- one selected drawer per mode or the equivalent deterministic selection;
- cabinet and inspector scroll offsets; and
- meaningful focus destination.

The cache contains no save document, prepared transaction, modal consent,
diagnostic fact, canonical state, or drawer metadata authority.

Logical-day change, successful Load, New Acc, and Logout clear the Backup view
cache. Title Log in re-evaluates records on every opening rather than retaining
an in-run cache.

### 15.3 Save contents and Load reconstruction

The canonical save may preserve the semantic route and active desktop app. It
never preserves Backup Nodes, open modal, tab Control, focus NodePath, hover,
pressed state, scroll pixels, operation text, or view cache.

After a successful Load:

- the exact saved canonical route and active app are reconstructed;
- exact candidates, boards, Schedule facts, Contacts facts, Shop facts, and
  narrative stages follow their own accepted persistence law;
- every app rebuilds its presentation cache under its governing manual; and
- a saved active Backup app opens cleanly at `Save` plus `Slot 1`.

This is compatible with Contacts restoring to its bare list, Shop restoring to
its approved reset projection, Schedule restoring only its explicitly saved
view facts, and Minesweeper restoring its exact canonical candidate or board.

### 15.4 Palette transition

Title Log in remains in the current menu/next-run palette while a record is
selected or prepared. It does not preview a saved run's palette.

After successful Load commits, the routed game and in-run Backup use the
restored run's captured Dark-mode configuration. Changing the title toggle
cannot recolor or mechanically convert an existing save.

## 16. Busy, failure, and recovery presentation

### 16.1 Ordinary operation states

Backup keeps the cabinet and selected drawer visible during a multi-frame
operation. The inspector may show exactly:

- `Saving…`;
- `Loading…`; or
- `Deleting…`.

It does not show invented percentages, file counts, disk sectors, progress
bars, spinners, flashing activity lights, or random wait copy.

While a record operation is pending, mode changes, drawer-selection changes,
record actions, shortcuts, and route-changing controls are inert. The current
inspector may still scroll and the cabinet remains readable. A selected target
therefore cannot change underneath the operation.

### 16.2 Unavailable records

An existing structurally unreadable, future-schema, or otherwise unsupported
record remains in its fixed drawer as `Unavailable`; it never masquerades as
Empty. Load is disabled. Content incompatibility with an earlier validated
whole checkpoint instead projects the separate fallback-loadable state and its
mandatory disclosure.

Release copy may distinguish only actionable public categories, including:

- `Can't read this save.`
- `Newer game version required.`
- `Only an earlier compatible checkpoint can be loaded.`

Raw parse errors, schema paths, stack traces, checksums, filenames, checkpoint
IDs, and participant failures remain developer diagnostics.

### 16.3 Fatal or transaction recovery

Ambiguous persistence never becomes a drawer claim. A pending cross-store or
restore transaction uses the retained quiet trusted recovery surface until the
system can prove whether progress is safe, pending, or unchanged.

The surface offers only actions the recovery coordinator can perform, such as
Retry, Cancel, or Return to Title. It is visually plainer and cleaner than the
ink archive if needed to mark a nonfiction trust boundary. It never uses horror
red, glitch effects, fake codes, or character attribution.

### 16.4 Migration and retired content

A compatible forward migration that preserves meaning may remain silent and
retains the original saved time. A migration or fallback can never resurrect
retired canon as recovered evidence or inject a deleted message into a current
timeline.

Loading an honestly earlier checkpoint may restore canonical content that
existed at that earlier point. That is ordinary rewind, not a Backup anomaly.

## 17. Visual direction

### 17.1 Role in the university OS

Backup is an archive cabinet inside the established old university operating
system. It should feel institutional, maintained, and physically rough rather
than cheaply manufactured or broken.

Use:

- tired paper-grey and diluted-ink surfaces;
- soot-black and cold grey-green structure;
- restrained washed mint, bruised mauve, faded peach, or oxidized blue accents;
- square corners, hard one-pixel seams, and stable old-workstation bevel logic;
- deliberate empty space in the inspector; and
- integer-aligned, static texture outside text and control boundaries.

### 17.2 Drawer fingerprints

Each logical drawer has one tiny authored registration/paper-density
fingerprint. The mapping is fixed by drawer identity and remains identical:

- before and after Save, Load, Delete, migration, or failure;
- across profiles, runs, branches, accounts, and installations;
- across text-size presets and locale changes; and
- across light and Dark palettes, which recolor the same motif.

The fingerprint never communicates age, safety, recency, occupancy,
compatibility, route, friend, ending, or importance. It is absent from
assistive output.

### 17.3 Interaction states

- Selection uses a persistent charcoal double inset.
- Keyboard/gamepad focus adds a separate pale-and-charcoal outer ring.
- Hover uses one quiet paper-tone change and never changes geometry.
- Press uses a brief reversed workstation bevel without scale or layout shift.
- Disabled remains readable and structurally distinct; opacity alone is
  insufficient.
- Empty, Unavailable, selected, focused, pressed, and busy remain separable
  without relying on color, motion, texture, or audio alone.

### 17.4 Forbidden visual fiction

Backup forbids:

- fake crashes, fake corruption, ghost records, deleted-record residue, and
  fabricated recovery logs;
- changing drawer count, position, size, or decorative fingerprint because of
  hidden state;
- flicker, jitter, RGB split, scanlines, glitch wipes, broken glyphs, simulated
  lag, and animated paper noise;
- blood, occult marks, warning-red horror framing, and character handwriting;
- decorative serial numbers or error codes that appear operational; and
- any effect that could make a tester reasonably report that Save, Load, input,
  localization, or rendering failed.

## 18. Text size, localization, and accessibility

### 18.1 Supported text presets

Initial Windows release supports Backup at exactly the established in-game
100%, 125%, and 150% text presets. At all three:

- the cabinet remains 3 by 3 on the left;
- the inspector remains on the right;
- drawer labels and metadata wrap without ellipsis or clipping;
- the inspector information region may scroll vertically;
- its action dock remains reachable and anchored;
- no essential text uses horizontal scrolling; and
- every interactive target remains at least 48 by 48 logical pixels.

The UI never silently shrinks the selected text size. This document makes no
200% or Windows `Make text bigger` conformance claim.

### 18.2 Reading and focus order

Visual, keyboard, gamepad, and assistive order agree on:

1. mode control when present;
2. drawers in fixed row-major order;
3. selected-record inspector content;
4. enabled inspector actions; and
5. Home/Return.

Mode, selected, focused, disabled, Empty, Unavailable, busy, and confirmation
states have semantic roles and text. None relies on alignment, tint, or paper
texture alone.

### 18.3 Assistive parity

Assistive output may expose only the same operational facts visible on screen:

- drawer identity and selected state;
- `Empty`, `Unavailable`, or Day/time;
- action name and enabled/disabled state;
- the Autosave system-owned reason;
- confirmation and fallback disclosure;
- `Saving…`, `Saved`, `Loading…`, and `Deleting…`; and
- truthful public failure/recovery copy.

It never exposes hidden content, save reason, internal version, revision,
fingerprint, filename, journal, branch, route, board, anomaly allocation, or
decorative drawer variance.

Quick status uses a polite live announcement and never steals focus. Autosave
success produces no live announcement.

### 18.4 Input parity

Mouse, touch, keyboard, gamepad, and assistive activation can all complete
select, Save, confirmed overwrite, Load, confirmed Delete, Cancel, Retry, and
Back through visible semantic controls. F5/F9 remain optional keyboard
conveniences, not required functionality.

## 19. Component and ownership boundaries

### 19.1 Persistence owner

`SaveManager` alone owns reading, migration, validation, preparation, atomic
publication, restore coordination, deletion, and record existence. The Backup
view sends semantic record locators and typed commands only.

### 19.2 Projection owner

A read-only record projection maps each closed semantic locator to detached
player-safe facts:

- state: Empty, readable, Unavailable, or fallback-loadable;
- Day and frozen time when safe;
- allowed actions and public disabled reason; and
- prepared fallback metadata when applicable.

It never returns a mutable save document, arbitrary path, Node, or raw error.

### 19.3 View owner

The Backup view owns:

- fixed drawer instances and authored fingerprints;
- current mode, selection, scroll, focus, and transient status;
- rendering and semantic accessibility labels; and
- emitting typed user intents.

It does not decide whether a save is valid, which checkpoint wins, whether a
Load is safe, or whether a transaction committed.

### 19.4 Consent owner

The trusted operation/confirmation coordinator owns prepared-target identity,
revision binding, focus trap, revalidation, and one-shot commit. The modal is
not a storage or gameplay owner.

### 19.5 Host owner

The desktop/title host owns app opening, close focus restoration, same-day view
cache lifetime, route transitions, and edge Quick-status placement. Backup does
not reach into other app scenes.

## 20. Exact supersession and retained law

### 20.1 Superseded or rejected physical drift

Once approved, this amendment supersedes or rejects as product authority:

- the current `BackupApp.tscn` two-record incomplete grid;
- the current `SaveSlotRow.tscn` pattern of Save, Load, and Delete inside every
  record;
- the current inert tabs, unwired Return, absent record binding, and absent
  focus restoration;
- any visual order derived from `SaveManager.get_all_save_metadata()` rather
  than the closed semantic cabinet registry;
- the current UI comment that an active Minesweeper board silently disables
  Save for its lifetime;
- recovered per-row or right-click save interactions;
- rich player-facing metadata such as route, board, friend, ending, playtime,
  run ID, or checkpoint ID;
- filesystem modified time as save-time authority;
- a continuous or 200% initial-release text-scale promise; and
- exploratory meta-horror save tiers or fake corruption behavior.

These are superseded only within the six declared scope topics. Their physical
files remain unchanged until separately authorized implementation.

### 20.2 Retained law

This amendment retains:

- exactly seven numbered records plus Quick and Autosave;
- primitive validated save documents and one storage owner;
- atomic replacement, last-known-good protection, and whole-checkpoint restore;
- exact stable candidate and board save/restore;
- no live Node or presentation cache in canonical save data;
- numbered-slot deletion isolation from the live recovery journal;
- Logout autosave and truthful failure behavior;
- Load/New Run as branch replacement rather than forfeit or refund;
- profile/run/branch/attempt and anti-reroll ownership;
- non-destructive future/corrupt/unmappable rejection;
- Contacts, Shop, Schedule, Minesweeper, dialogue, and narrative-scene app-local
  restore laws;
- Dark-mode new-run capture and existing-save stability; and
- technical failure as nonfiction.

## 21. Reconciliation path

Written acceptance alone performs no reconciliation. A later explicitly
authorized authority pass must:

1. register this amendment in the accepted authority discovery path;
2. reconcile the currently active amendment/requirements effort rather than
   silently widening an executing or hash-bound plan;
3. translate the closed Backup projection, consent, timestamp, shortcut,
   recovery, and accessibility laws into requirement packets;
4. add a validated save-time fact and player-safe metadata projection without
   giving UI raw documents or paths;
5. reconcile the reusable persistence/desktop handoff owner before the
   player-facing Backup composition owner consumes it;
6. update or replace stale active-board save-lock requirements and tests already
   superseded by the accepted 2026-08-11 law;
7. bind player-facing Backup work to a bounded Bead or child issue with exact
   acceptance and evidence rather than mutating unrelated closed work;
8. reconcile localization keys, focus/input actions, theme tokens, and supported
   100/125/150 verification; and
9. preserve the user's dirty worktree and never treat current scaffold edits as
   disposable.

No step in this list is authorized by this document.

## 22. Verification matrix

### 22.1 Registry and projection

- Exactly nine semantic locators project to the exact fixed 3-by-3 order.
- Storage enumeration order, locale, run, profile, load, and record state cannot
  reorder them.
- Empty, readable, Unavailable, and fallback-loadable states project only their
  approved visible and assistive facts.
- No raw document, path, ID, journal, checksum, or hidden content reaches UI.

### 22.2 Save

- Empty numbered direct Save, occupied numbered confirmed Save, readable Quick
  direct Save, fallback-loadable/Unavailable Quick confirmed inspector Save,
  and disabled Autosave Save all follow the exact matrix.
- F5 refuses fallback-loadable and Unavailable Quick without mutation.
- Stable-board, candidate, dialogue, Hospital, ending, and ordinary desktop
  checkpoints save exact canonical state.
- Repeated F5 during one bounded command creates one Quick transaction at the
  first subsequent admissible stable revision.
- Save crash injection before prepare, after timestamp capture, before write,
  after candidate write, after replace, and before readback never publishes a
  false winner or a second timestamp.
- Failure preserves prior record and visible metadata exactly.

### 22.3 Load and fallback

- Title current Load prepares and commits without an ordinary replacement
  modal; every in-run current Load confirms.
- F9 always confirms in-run and never queues a future surprise Load.
- Current-incompatible/earlier-compatible selects the newest earlier whole
  compatible checkpoint inside the same record and discloses its Day/time.
- Fallback never combines fields, reads another drawer, or uses the live
  recovery journal.
- Structural corruption and future schema never trigger silent compatibility
  fallback.
- Changed prepared target cannot be loaded under stale consent.
- Any prepare or commit failure leaves every live participant and record
  unchanged or rolls the participant transaction back exactly.

### 22.4 Delete and New Acc

- Autosave, Quick, readable numbered, and Unavailable record Delete all confirm
  and affect only the bound semantic record.
- Successful Delete leaves the same drawer selected as Empty.
- Delete cannot touch the live transaction/crash-recovery journal.
- New Acc confirms exactly when a live continuation or existing Autosave would
  be replaced, including Unavailable Autosave.
- New Acc leaves Quick and numbered records unchanged.

### 22.5 Time

- Saved time is captured once per prepared transaction and survives retry.
- Durable publication and readback precede visible metadata change.
- Filesystem mtime, load time, current clock, and Contacts anomaly never alter a
  record's displayed saved time.
- Clock rollback cannot reorder drawers or mutate state.
- Locale digit rendering preserves the exact frozen 24-hour value.

### 22.6 Focus, cache, and input

- First-open, same-day reopen, day-change reset, title selection, Load, New Acc,
  Logout, and Backup-active-save restore follow section 15 exactly.
- Drawer focus selects; hover and double-click do not act.
- Pointer, touch, keyboard, gamepad, and assistive controls complete every
  ordinary path without F5/F9.
- Every modal traps focus, begins safe, blocks shortcuts, binds one revision,
  maps Back to Cancel, and restores exact source focus.
- A changed drawer while a modal is open cannot receive the old command.

### 22.7 Layout, language, and visual states

- 100%, 125%, and 150% preserve the fixed cabinet/inspector topology and all
  nine positions.
- Supported long translations wrap without ellipsis, clipping, overlap,
  horizontal text scroll, or unreachable actions.
- Every target is at least 48 by 48 logical pixels.
- Selection, focus, hover, pressed, disabled, Empty, Unavailable, and busy are
  distinguishable without color, motion, texture, or audio alone.
- Drawer fingerprints remain byte-stable in semantic mapping across every
  state and consume no RNG.
- Light/title and loaded-run Dark palettes retain equal text, focus, boundary,
  and disabled-state contrast.

### 22.8 Trust and recovery

- `Saving…`, `Saved`, `Loading…`, `Deleting…`, failure, and fallback copy never
  claim an unproven fact.
- Autosave success is silent while user-impacting Autosave failure remains
  truthful.
- Raw diagnostics never appear in release UI or assistive output.
- No failure, migration, restore, or visual effect becomes character action,
  Observer evidence, route evidence, or horror fiction.
- Compatible migration cannot resurrect retired content; an honest earlier
  checkpoint may restore only what canonically existed at that checkpoint.

## 23. Acceptance and next manuals

The user approved this exact written artifact on 2026-08-12. Its accepted,
approved, and passed lifecycle fields record that bounded authority, while
`implementation_authorized: false` remains in force.

Later UI/UX manual sections must cite this Backup law rather than duplicate or
reinterpret it. The visual-art manual may finalize archive textures, drawer
assets, palette tokens, and font assets without encoding save state in
decoration. The music/audio manual may add optional ordinary ambience but cannot
make Save, Load, success, failure, recovery, or compatibility audio-only.

Settings, Gallery, title-menu composition, and narrative-scene manuals remain
separate design passes. Runtime reconciliation and implementation planning
require separate explicit authority.
