# Schedule semantic scroll restoration

Following 36e4aca43, each mounted sheet captures the item at its top using a
semantic identity, ordinal and row-relative delta. Available uses source IDs;
Docket uses occurrence IDs or numbered empty slots. Reflow resolves the same
identity, otherwise the next row at the old ordinal, otherwise the final previous
row. Delta clamps within the new row span and the result within the new extent.
The first Available row's inset preserves an explicit zero scroll offset.

Cached return, duplicate refresh, locale/text-size/target reflow, refused edits
and warning background reconstruction restore focus before scroll, preserving a
manual offset even when focus is elsewhere. A successful edit restores scroll
before its new focus target, allowing normal reveal. Neither path focuses the
anchor item or adds a nested scroll owner.

Queued focus and anchor restoration bind the projection revision. Two refreshes
in one frame retain the original pending anchors instead of recapturing a new
ScrollContainer's temporary zero. Explicit cache clearing cancels pending work,
zeros both owners, and prevents an old callback restoring abandoned offsets.
All of this is local presentation state; no save field or gameplay ID is added.

## Verification

- `scroll/schedule-semantic-scroll.log`: meaningful initial failure, 37/39 tests;
  rapid same-frame projection lost offset 90 to zero. A separate oversized name
  fixture exceeded the existing folio contract and was shortened.
- `scroll/schedule-semantic-scroll-fixed.log`: both focused suites pass after the
  pending-anchor fix and queued-cache-clear regression.
- `scroll/schedule-scroll-final.log`: ten suites, **130/130 tests, 2,477
  assertions**, native/wrapper exit 0. Includes the real mounted App changing
  Traditional Chinese150/Large to English150/Large, retaining the same top
  occurrence and independently focused row without mutating the view.
- `scroll/schedule-scroll-render-repeat.log`: the nine existing real GPU samples
  rerun successfully with native/wrapper exit 0; compact-art and detached-focus
  pixel assertions pass. The initial `schedule-scroll-render.log` captured all
  nine images but stalled during native shutdown; its specifically verified
  isolated process was stopped (native -1, wrapper 1). The repeat used unchanged
  code and a new isolated root. `scroll/invocations.jsonl` records both outcomes.
  This protects existing composition; the semantic reflow scenarios are proven
  by mounted state/geometry tests, not claimed as a new rendered matrix.
- Independent final review found no remaining defect. Godot 4.6.3 jobs use the
  isolated wrapper/APPDATA; GPU root deliberately retained. Existing certificate,
  Unicode and 24 Dialogic-orphan noise remains; no full startup claim.

Production lifecycle hooks must still call cache clearing after successful Load,
New Run/New Acc, Logout and profile reset. Actual launcher/Done/navigation/save
composition, dock custody seam, nonstandard contrast/RTL and platform assistive
proof remain open. This does not complete Schedule or the overall UI goal.
