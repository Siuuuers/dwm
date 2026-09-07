# Schedule in the shared desktop

The shared desktop can mount the existing Schedule docket through an explicitly
configured presentation owner. The host retains the same scene across Home and
reopening, and reconciles an already active Schedule route during setup. A failed
restored projection leaves the route unresolved instead of pretending the desktop
is on its launcher.

The injected bundle contains the existing draft presentation port, shared locale
and preference owners, desktop state owner and day, plus an optional Done callable
and optional complete warning presentation/command pair. Setup validates the bundle
before publishing it and refuses replacement owners. Pending warnings receive
their presentation and command pair before the first projection. Missing Schedule
presentation remains unavailable; missing Done ownership leaves Done disabled.

Locale, text size and large-target preferences reflow the existing docket. Cached
hidden views retain their presentation until foreground entry, and shared dialogs
retain control ownership while lower-view reconstruction is deferred. Selection,
semantic focus and scroll anchors belong to the presentation; drafting remains with
the supplied real controller. Done and warning commands notify the shared shell
while they own interaction, so Home cannot acquire focus during that interval.

## Production dependencies

This change does not construct a new production ScheduleViewController. The current
Bootstrap retains an action-only ScheduleDepartureViewPort, and its method named
_construct_schedule_presentation composes Hospital/Dating, not the docket UI. The
external durable Schedule owner work remains in progress on dwm-oyo.3.

Complete localized action names, authored warning copy and the warning command
adapter are still missing in this lineage. The current ScheduleApp expects a
2-argument warning command while the underlying controller exposes a different
3-argument transaction API. Exposing the private Done dispatcher or creating an
independent runtime draft store would not resolve those dependencies.

The injected integration tests use real draft, presentation, registry, issuer,
profile and desktop owners with isolated fixtures. Native captures use ordinary
action fixture names and prove presentation only. They do not establish production
save/restore continuity, canonical Done execution, Day7 gameplay, or platform screen
reader acceptance. Neutral ticket art and existing licensed fonts are reused.

Final verification passes 169 tests and 3,004 assertions across 14 suites. Native
rendering passes 207 checks across 18 locale, text-size and target-size combinations.
The ordinary English and largest Traditional Chinese captures were visually inspected.
Initial failed tests and the rejected fixture-encoding attempt remain recorded.

See [the evidence summary](../../../evidence/schedule_desktop/summary.json) for
exact source hashes, terminal test counts and native captures. Bead dwm-eei.8 and
the full current-UI goal remain in progress. This is a local checkpoint; no merge
or push is included.
