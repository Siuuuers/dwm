# Ordinary expiry and per-contact order — dwm-bap

2026-09-13, branch `test/ordinary-midnight-restore`, base `7cc1689cd`, Godot
4.6.3 mono. This increment adds acceptance evidence and corrects an authority
interpretation; it changes no production gameplay or persistence code.

The native Windows/OpenGL journey uses the full production bootstrap and actual
New Account. It opens Lavinia's Day 1 ordinary message, renders all A/B/C choices,
leaves without selecting a reply, and advances through public Schedule Done and
its real optional-work warning dismissal. Day 2 has no late Lavinia reply menu,
message history, ordinary reply/echo receipt or pending echo. Sylvia retains her
three Day 2 choices.

The real SaveManager then prepares the physical Day 2 Autosave and **commits the
full restore**, including all configured participants. The live session changes;
the restored Contacts state is exactly equal to the saved state. Opening Lavinia
again shows no expired choice. This is an installed restore in the running game,
not merely validation of a candidate snapshot. No game state, message, reply,
clock or save owner is seeded or mocked in this journey. UI signals and public
command ports drive it; it does not claim physical input-device coverage.

Final `ordinary-expiry-reviewed-20260913.log` exits **0** after independent review
and the capture-reporting repair below. The two PNGs are unmodified actual
viewport captures from that run: unanswered Day 1 and the empty Day 2 thread
after Load. The earlier successful run's temporary root was cleaned by the
wrapper; subsequent runs used `-KeepRoot` to retain exportable images.

`test_contact_calendar_stacking.gd` passes **2/2 tests, 25 assertions**. It uses
real Contacts domain transitions and the production presentation port to prove:

- Day 1 Sylvia offer → Day 2 nevermind → Day 2 Sylvia ordinary.
- Day 1 Priscilla offer → Day 2 nevermind → new Day 2 Priscilla offer.

Both preserve append-only canonical sequences and exact state through repeated
read-only projections, with zero command calls. Their small owner/command
fixtures do not substitute for the native expiry/restore journey above.

Independent review caught a harness error: a failed final screenshot could call
`quit(1)` and then fall through to the probe's `quit(0)`. The capture helper now
returns success/failure and this probe checks both capture results. The final
source review found no remaining blocker. All recorded successful images
actually exist; the repaired path also prevents a later failure being hidden.

Both final public inventories retain all 239 GameState and 74 SaveManager
contract signatures/dispositions; their call-site census is refreshed. The
final inventory/documentation tooling suites pass **14/14 tests, 410 assertions**.
The actual documentation CLI also passes all **16 packets, four design
authorities and agent workflow** with the base revision's Beads snapshot (exit 0).

The fixed-calendar requirement now records implementation and verification
paths. Combined with `evidence/contact_calendar/README.md`, these checks cover
the fixed calendar, three neutral choices, group protocol and per-contact
stacking. `req.contact.echo` and `req.run.day7_echo_drain` remain open: the accepted
August 12 Contacts amendment §13.1 explicitly retains an invisible expiry
tombstone, and §14.2 lists it in persistence. The virtual ordinary implementation
does not currently implement that literal requirement. Passing visible expiry
does not withdraw it. Day 7 Skip/Auto/instant/TTS/assistive completion parity also
remains unproven for the prelude surface.

Two unsuccessful setup attempts are retained honestly:

- An appended test in the old `test_day_resolution_disk_durability.gd` fixture
  stopped at `day_advance_source_unavailable` (29/30 assertions, exit 1). That
  pre-existing harness lacks current resolution-start identity, consequence
  source and shared day-advance owner wiring, and uses a placeholder causal-day
  identity. The same failure appears in the earlier `vky5-baseline-full` log.
  The attempted addition was removed; that file is byte-equivalent to the base.
  Its older suite is not repaired or claimed passing by this increment.
- The first native command omitted `--phase2r-bootstrap-mode=final`, so the
  isolated root correctly selected test-manual mode and the startup assertion
  failed (exit 1). Both final native runs use the actual final bootstrap mode.

All runs use isolated filesystem roots. No player save, sealed plan or design
digest is modified. Existing Unicode/NUL diagnostics remain in the native logs;
the GUT run also reports its existing 24 Dialogic orphan nodes.
