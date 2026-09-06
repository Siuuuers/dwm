# Schedule edit owner and neutral art checkpoint

This checkpoint adds synchronous append, insertion-move and remove commands to
the existing ScheduleViewController on base dbca83bd4. It does not install a
Schedule screen or connect the production launcher or Done dispatcher.

Mutating edits pack entries in existing slot order and preserve occurrence IDs.
Day 7 replaces its one destination atomically; an identical source or a
same-position move leaves the original view unchanged. Stale fingerprints,
malformed commands, rule violations and pending warnings refuse without partial
mutation. A future screen must reject sparse restored input before mounting;
the unchanged operation deliberately does not act as an implicit save migration.

The command reuses the existing registry, draft rules and final owner commit.
It validates receipt classes; it does not prove an invitation was read, accepted
or remains eligible. Available-source admission must come from the real Contacts
owner before the presentation layer can offer these commands.

Two independently authored blank clipped-corner ticket masters provide the
accepted optional-art fallback at native 24x24 and 64x64. Their registry exposes
only an art ID and the two textures. No story, public name, route or eligibility
is inferred from them. This is imported-pixel proof, not rendered screen proof.

## Validation

Godot 4.6.3 Mono, isolated test roots through Invoke-IsolatedGodot.ps1:

- schedule-docket-regression.log: 4 suites, 64 tests, 1,093 assertions, all pass;
  native exit 0 and no script-load failure or ignored suite.
- Covers packed insertion/removal, repeated ordinary actions, stale/malformed
  refusal, capacity, Day 7 replacement/refused replacement/removal, warning
  custody, retained departure receipts and unchanged committed Schedule and
  motivation. Existing controller and warning receipt suites run alongside
  the new tests.
- Both imported textures have exactly transparent black plus the two authored
  opaque colors, with declared dimensions and no antialias shades.
- Initial failures were test-script type inference and alpha-border importer
  recoloring. Explicit Dictionary types and disabling that import option fixed
  those failures; the resulting complete suites were executed above.
- Environment log noise remains: Windows certificate-store read error, Unicode
  NUL warnings, and 24 Dialogic subsystem orphans. These checks do not establish
  a clean full-game startup, save compatibility or end-to-end Schedule flow.

Independent read-only review checked atomicity, command shapes and warning/
ledger custody. Its suggested no-op normalization was declined because the
accepted Schedule dossier section 7.3 explicitly requires same-position moves
to be silent no-change operations. Its missing custody and failed replacement
test recommendations are included.

Task dwm-eei.8 and the full ten-family UI goal remain in progress.
