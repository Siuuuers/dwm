# Accepted owner UI updates — 2026-09-21

This note reconciles the owner's subsequent implementation requests with older
UI documents. It records accepted conversation decisions, not a new gameplay
or save-recovery design. The implemented baseline is draft PR #1 at
`681251dc832262c08826ce74d6a4480291eac4a8`; later verification belongs to the
commit actually tested.

## Desktop size and navigation

The computer panel scales all of its content together after the divider is
released. The shared desktop canvas keeps its 800-pixel logical width and scales
to the available panel width. Shop and Schedule use this same canvas; their
fixed logical geometry is not evidence of unfinished per-app horizontal reflow.
Taller content remains reachable through the host's scrolling. Resizing retains
the current app, pending action, selection and focus.

Angela's image stays centered at constant height and crops equally on both
sides. At the 1280×720 reference, her width is 320–480 logical pixels in
two-pixel steps. The larger visible `<` grip retains its 64×64 interaction area.
Pointer movement previews the boundary; release commits it. Cancellation and
no-op gestures do not change the preference. Keyboard resizing remains usable.

The desktop width is a saved profile preference, initially 480. It survives
scene changes and restarts. The clock stays at the rightmost end of the bottom
bar. Previous/Next/Confirm are not part of the ordinary layout; the existing
large-target accessibility option can expose them. Minesweeper Fit and the
compact cell-size picklist occupy the bottom controls in both hosts. Drag stays
available. Rules and Assignments overlay the retained board; permitted Home,
New Board and difficulty actions dismiss the information overlay.

These decisions supersede the per-mount width reset, unchanged-text, no-extra-
scrolling, always-visible navigation and per-app reflow requirements in the
[September 15 divider amendment](../2026-09-15-desktop-divider-and-touch-focus-amendment.md).
They do not assert that older external worktrees were handed over or changed.

## Dating presentation and divider preferences

Dating keeps character portraits on the left and the scene on the right. Both
panes currently use the same background image. Portrait height stays constant
while width changes crop symmetrically. Multiple portraits have equal centers
and stable order; transparent portraits may overlap, while opaque paintings use
clipped slots. The Minesweeper challenge fills the right pane and retains the
left portraits. Full CGs and intentionally portrait-free entries keep their
existing full-width fallback.

Solo and group dates have separate profile preferences. Each initially inherits
the saved desktop width. Only an actual committed resize creates that category's
override; later desktop changes continue to affect an untouched category.
Overrides survive dialogue/challenge transitions, later dates and restarts.
Entry kind chooses the category, even if an optional group portrait is missing.
Dating permits 320–640 logical pixels; solo uses two-pixel steps and group uses
four-pixel steps to keep portrait centers on whole pixels. An inherited width is
rounded for presentation without creating an override. Failed saves restore the
previous width. Existing Reset Preferences restores desktop 480 and inheritance
for both dating categories.

Three captions are centered across both panels near the bottom, above controls.
They are outlined text over the image, with no speaker names or opaque caption
panel. Wheel review moves one already-seen caption at a time: down goes older,
up returns toward live text. Admitted background clicks reveal/advance; controls,
choices and input custody retain priority. These presentation features do not
by themselves establish persistent canonical History or exact-variant navigation.

## Fonts and languages

Pixel is the default font style. Readable is an optional saved accessibility
preference for all game text. English, Simplified Chinese, Traditional Chinese,
Japanese and Korean UI use their corresponding installed font resources.
Japanese Motivation remains `意欲`. JA/KO UI copy is a draft requiring editorial
review; adding UI translations does not translate authored narrative files or
complete deferred dual-language rendering.

These choices supersede older directions prescribing one fixed font style or
only three supported UI languages. Controls should fit complete labels where
possible; readability and access take precedence over forcing every locale and
enlarged-text combination onto one row.

## Beads disposition and limits

`dwm-01b` should be assessed against the accepted shared scaling behavior above,
not reopened as a demand for separate wider Shop/Schedule layouts. Existing
desktop, Shop and Schedule tests and native render evidence must establish the
actual implementation before closure.

Logout remains consent over the launcher, not a seventh saved content workspace.
The registry can expose seven launcher actions while only the six content apps
are restorable. That requirement was not superseded by these visual changes.
The owner explicitly permits discarding the previous save. A legacy Autosave
whose current workspace is `logout` may therefore be rejected; no compatibility
migration is required. This does not authorize automatic deletion of unrelated
slots or removal of the normal validation and recovery rules.

Save durability, complete-action recovery, transaction markers, journal retention,
and narrative receipt rules remain in force. Performance experiments must measure
current code and preserve those rules. Historical timings and test counts are
evidence for their original commits, not proof of present latency or full release
acceptance.
