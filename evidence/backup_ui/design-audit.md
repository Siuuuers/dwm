# Backup UI design and blind-spot audit

Scope: read-only review of the root Backup dossier for the current in-run UI
milestone. Historical recovery gates are reference material. This audit changes
no production source and creates no new preview or specification workflow.

Source: `C:/Users/glori/Documents/dwm/docs/design/current-ui/backup.md`,
121,824 bytes, SHA-256
`1da253e262d996234208e2c95a1096a518ff1a19d02b8a1b85f185f9350da78d`.
Line references below refer to that exact source.

## Smallest useful implementation

Build one Backup body below the existing desktop strip, using a fixed cabinet,
one selected record, one Save/Load mode group, a readable inspector, and pinned
status/actions. Keep persistence, compatibility, consent binding and restoration
with real owners. Do not reconstruct SaveManager behavior in buttons. Reuse the
existing 24/30/36 logical font direction and validate the compact text allocations
before claiming the old pixel masters fit it.

The current 800×656 logical desktop content is exactly the dossier's 400×328
native body at 2:1. No shell resizing or second title bar is needed.

## Geometry and record truth

All following rectangles are Backup-local logical pixels, converted exactly from
section 5, lines 410–491:

| Region | Logical rectangle or size |
|---|---|
| Body | `(0,0,800,656)` |
| Mode region | `(16,16,448,64)` |
| Main region | `(16,96,768,544)` |
| Cabinet | `(16,96,448,544)` |
| Inspector | `(480,96,304,544)` |
| Information | `(480,96,304,336)` |
| Pinned status | `(480,432,304,96)` |
| Pinned action dock | `(480,528,304,112)` |
| Each drawer | `144×176`, with 8-pixel gaps |
| Ordinary mode keys | Save `(16,24,96,48)`; Load `(128,24,96,48)` |
| Large mode keys | Save `(16,16,96,64)`; Load `(128,16,96,64)` |

Dock-local one-action geometry is `(0,32,304,48)` for Ordinary, or
`(0,24,304,64)` for Large. Two actions use widths 144, an intervening 16-pixel
gap, and x positions 0 and 160 at the same y/height. Save mode instantiates only
Save. There is no blank capacity for absent keys.

The nine fixed row-major records are Autosave, Quick, Slot 1; Slot 2, Slot 3,
Slot 4; Slot 5, Slot 6, Slot 7 (lines 346–363). No sorting, filtering, slot
renaming, or hiding Empty records. The paper shows fixed identity and one primary
semantic state: `Day N · HH:MM`, `Empty`, or `Unavailable`. Text may wrap; this
does not authorize extra metadata.

Lines 374–404 distinguish current readable, safely disclosed compatible fallback,
future-schema, and unreadable states. Only typed content incompatibility may
select a validated earlier whole checkpoint from the same record. Corruption,
future schema, unsafe metadata, and another drawer never supply fallback.
Inspector copy is limited to record identity/state, automatic Autosave explanation,
the prescribed compatibility sentence and prepared fallback Day/time, and truthful
public action reasons. No route, character, playtime, file path, checksum, internal
version, branch, journal, or hidden story preview is shown.

## Actions and consent

Section 8.3, lines 842–865:

| Record class | Save mode | Load mode |
|---|---|---|
| Autosave, any state | Visible Disabled Save | Load if usable; confirmed Delete if occupied |
| Quick, Empty | Direct Save | Disabled Load and Delete |
| Quick, readable | Direct replacement Save | Confirmed in-run Load; confirmed Delete |
| Quick, fallback or Unavailable | Confirmed overwrite | Disclosed fallback Load if usable; confirmed Delete |
| Numbered, Empty | Direct Save | Disabled Load and Delete |
| Numbered, any occupied state | Confirmed overwrite | Load if usable; confirmed Delete |

Every in-run Load confirms replacement of unsaved current progress. A fallback
combines that warning and the exact earlier target disclosure in one sheet.
Every occupied Delete, including corrupt/unavailable Autosave or Quick, confirms.
Disabled actions remain readable with their state/reason but are skipped in
action traversal; their drawer remains selectable for inspection.

Confirmation starts on Cancel, traps foreground input, blocks Home/background
commands, and binds semantic locator, exact document revision/integrity identity,
prepared target and visible target facts (lines 869–920). Changed facts invalidate
consent; no automatic substitution or reused consent. Use explicit Load, Delete,
Overwrite and Cancel verbs. Load has Danger evidence; Delete/overwrite have
Destructive evidence. These are independent of the sheet's Warning.

Publish new Day/time and Saved only after the owner proves the durable winner.
Use the owner's frozen save-time fact, never filesystem modification time, click
time or the live desktop clock (lines 924–990, 1419–1436). Load failure preserves
the current run; Delete failure preserves the record. Do not assert these guarantees
when the owner instead reports indeterminate persistence: that requires its
stronger recovery path. A failed consent/admission cannot be retried as though
the old prepared target were still valid.

## State, navigation and cache

- First open/reset is Save mode, Slot 1 selected and focused (lines 1381–1385).
  Modes share one drawer selection. Their group is one sequential focus stop;
  Left/Right moves mode focus without changing mode, activation changes it, and
  Down returns to the selected drawer (lines 812–830).
- Cabinet arrow movement selects, while Hover only inspects. Double activation
  selects only; it never performs Save/Load. Three-by-three movement never wraps.
  Up reaches the active mode; bottom-row Down reaches Home. Third-column Right
  reaches genuine inspector overflow or the first enabled action; a missing
  destination is a consumed no-op (lines 1248–1315).
- Only the information region scrolls, and only when measured content overflows.
  Then it becomes one focus/assistive scroll owner with the prescribed truthful
  track and thumb. Otherwise no scroll semantics, focus stop or offset remains.
  Selection resets its offset; mode changes retain it; remeasurement clamps it.
  Status and actions never scroll (lines 1320–1355).
- Same-day cache retains mode, one selected drawer, legal information offset and
  semantic focus only. Reopen rereads current records. No metadata authority,
  prepared document, consent, status or Node reference belongs in the cache.
  Day change/Load/New Run/Logout clear it; restored active Backup starts cleanly
  in Save plus Slot 1 (lines 1397–1417).
- Do not fabricate Busy for synchronous calls. Genuine visible Busy displays the
  exact pending verb, focuses the readable status, and admits only fresh lawful
  overflow inspection. Local Saved is not a two-second toast: it lasts until
  selection, mode, operation or visibility changes (lines 1153–1194).
- Recoverable Error keeps trustworthy record facts, puts Cancel first, and offers
  only real fresh re-entry actions. Home and other routes cannot bypass a live
  modal or operation custody. No broad Disabled wash falsifies drawer state.

## Font and compact-layout blind spots

The macro geometry fits the current shell. The compact text allocations may not
fit the newer font direction; they must be measured rather than inferred from
the old 100/125/150 labels:

1. Ordinary keys are 48 logical pixels tall, while inset Focus consumes protected
   edge space. A 36-pixel regional font can require more vertical room than the
   remaining text band. The dossier explicitly forbids silent target-master
   substitution; choosing Large keys throughout would be a documented working
   design choice, not proof that Ordinary fits.
2. A 144-pixel drawer has only a 136-pixel paper face before text insets. Identity
   plus `Day N · HH:MM` may require multiple lines at 36 pixels. Preserve literal
   facts and ink clearance; do not truncate, shrink or reserve decorative capacity
   that forces essential copy out.
3. The 304×96 status region is especially vulnerable: the prescribed complete
   failure sentence can need more than two lines at 36 pixels. No actual font
   measurement was performed in this read-only audit, so this is a concrete
   required check, not a claimed measured failure. If it fails, the simplest
   working adjustment is a short pinned failure label with its full guarantee
   in the existing information region and Cancel's accessible description.
   Record that narrow departure; do not hide overflow or add a second scroller.
4. Confirmation copy must be tested at real locale/size using the host's safe
   region, genuine body overflow and pinned verbs. Native text-threshold rules
   from older bitmap masters do not apply to smooth font edges; hard pixel
   geometry and color-pair contrast remain independently testable.

## Fingerprints, Blooms and deferred work

The authored direction requires one tiny drawer fingerprint stable by semantic
drawer identity, with identical source pixels across profiles, themes, locales,
occupancy and selection. It is decorative, has no RNG and no assistive narration
(lines 760–770). Do not substitute a document checksum, generated noise, or a
record-state indicator. If authored material is not supplied, disclose that the
final decorative layer remains incomplete rather than create a new generation
pipeline. Static authored drawer marks are sufficient when supplied.

The current Unclassified Transfer Bloom is optional supplied art bound to a
durable record revision. Empty has none; a proven replacement may publish its
already-supplied new binding; Delete removes it. Missing art is omitted without
a gap, placeholder, warning or explanatory copy. Unavailable records can display
it only from independently safe public material. Selection/theme/failure never
recolor or regenerate it (lines 772–796).

The Distributed Transfer Field and Bloom authorship/allocation/generation rules
remain future work (lines 798–805). No procedural system, seeds, variants,
duplicate avoidance or animated anomaly elaboration benefits this implementation.
Title Log in, Pause mounting, New Acc/Logout transactions and global F5/F9 edge
status are separate host capabilities. Do not imply this in-run panel alone
implements them or duplicate Quick status locally. Final decorative production,
full accessibility tuples and broad display-scale proof remain separate from
getting the real save-record panel usable.
