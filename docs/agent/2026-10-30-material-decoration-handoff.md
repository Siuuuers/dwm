> Current clarification: material rendering remains retired, but the three items
> are restored as inventory-only purchases. See [runtime disposition](../retired-features/material-decorations/README.md).

> **Retirement update:** All three material decorations and their purchases are retired. See [the preserved implementation and compatibility policy](../retired-features/material-decorations/README.md). Earlier decoration requirements below are historical.

# Material decoration guiding handoff

Date: 30 October 2026 (Hong Kong)
Status: static hybrid prototype implemented in PR #162; final rendered acceptance is tracked in that PR.
The owner reports interaction consistency complete and now requests decoration planning. This document does not independently certify that implementation's acceptance.

## Goal

Make the three purchased materials recognizable, intentional and cohesive through code-only art:
- crystal stutters
- inked silk string
- letter with wax seal

The owner permits texture, decorative composition and layout exploration. Do not assume functional controls or caption placement should move. Preserve the completed readability and interaction work.

Read AGENTS.md, CLAUDE.md and current presentation/input contracts before implementation. Start from current master; do not overwrite parallel work. Current source inspection used search revision e295f5ccb8b81b56ec89fb6ba80b1bf372fb1a27 and ComputerDesktop.gd on master.

## Existing implementation

scripts/ui/ComputerDesktop.gd::_draw_cosmetics:
- Crystal: short straight highlights at top corners and short vertical edge strokes.
- Silk: a vertical line, a horizontal bottom line and a small outlined circle.
- Letter: 36×26 rectangular paper with fold lines and a circular seal, visible only when no desktop app is active.
- App decorations currently occupy the outer eight pixels. Desktop bottom excludes the 64-pixel region and current quick-status band.
- Colors come from Desktop structure, ink, focus and face roles.
- Ownership comes from the current inventory owner.

This is a source description, not a fresh visual audit. Capture current screenshots first. Do not mistake scripts/ui/shop/ShopItemArt.gd catalogue icons for the purchased desktop effect; update icons only if needed for visual coherence, as a separately stated small scope.

Relevant existing checks:
- tests/ui/render_shop_cosmetics_base.gd
- tests/integration/test_scene_shop_checkpoint_transaction.gd
Inspect additional callers and existing cosmetics fixtures before changes. Existing pixel regions encode old placement; update deliberately when geometry changes without weakening ownership/input assertions.

## Confirmed constraints

- Code-only final visuals: custom drawing, procedural textures and small shaders where justified. No requirement for painted/downloaded/generated raster art.
- Preserve per-run ownership, purchase caps, prices, restoration and new-run behavior.
- Keep computer-only scope and desktop-only letter visibility as the baseline until the owner selects a change.
- Main review target 1920×1080; ensure readability at 125% and 150%, both supported fonts, relevant palettes and smaller/narrower layouts.
- Do not cover captions, text, controls, focus rings, scrollbars, divider targets or status feedback.
- Decorations must not receive focus or intercept input.
- No revival of retired save-slot ink, Notes unlocks or new story mechanics.

## Proposed art direction — not yet selected by owner

A small collection of tangible, carefully placed objects, with restrained coverage and a shared lighting direction. Improve silhouette and composition before adding surface noise. Preserve quiet empty space.

### Crystal stutters

Use two or three asymmetrical clusters of faceted translucent shapes. A few bright edges and subdued faces should establish glass/crystal; avoid a continuous bright rectangle that resembles focus.
Suggested code construction:
- Small authored polygon groups with controlled variation.
- Consistent directional face shading and sparse offset edge highlights.
- Subtle procedural frost only where it strengthens the silhouette.
Avoid framebuffer refraction or full-screen blur for the first pass; convincing stylization does not require optical simulation.

### Inked silk string

Use a continuous curved thread with clear attachment points, a restrained bend or small knot, and an offset contact shadow. It should read as a physical strand rather than an ordinary UI border.
Suggested construction:
- Sampled Bezier curves with bounded subdivisions.
- A darker base stroke, narrower light-facing stroke and selective ink-darkened segments.
- A few controlled strand overlaps near the knot, not random scribbles.
Keep thread separate from draggable dividers and focus indicators.

### Letter with wax seal

Make paper folds, a slightly irregular seal and contact shadows readable at normal gameplay size. Place it intentionally on the desktop.
Suggested construction:
- Paper quadrilateral, fold triangles and small edge shadows.
- Smooth irregular radial seal contour with restrained harmonics; offset rim lighting and an inset stamped motif.
- Sparse, stable paper grain only after form and contrast work.
The emblem is undecided; do not silently choose a character, route symbol, initials or narrative meaning.
Do not make it openable, clickable or a Notes feature.

## Original visual choices (resolved below)

1. Overall finish:
   - Clearly pixel-stepped, matching the game's pixel character.
   - Smooth stylized materials.
   - Hybrid: crisp silhouettes with subtle smooth shading (recommended proposal).
2. Presence/composition:
   - Quiet edge accents.
   - More recognizable objects at corners/desktop, with compact app-open treatment (recommended proposal).
   Larger composition may require more decorative area; review exclusion zones before expanding beyond the current eight-pixel app border.
3. Motion:
   - Static first (recommended proposal).
   - Brief restrained reveal on purchase.
   - Occasional ambient movement.
No animation is agreed yet. If selected, respect Reduced Motion, avoid flashing and continuous motion near text, and never replay purchase reveals on Load/reopen.
Optional motif preference: abstract seal geometry, botanical motif, or user-provided design. Default prototype may use an explicitly temporary neutral inset ring.

These questions are visual choices, not a reason to delay baseline captures, source review or reusable prototype preparation. Do not call proposals approved requirements.

## Prototype workflow

1. Capture current no-item, each-item and all-three states on the same desktop/palette.
2. Produce actual Godot code-rendered previews of the proposed composition, with the current UI present. Do not use AI concept images as proof of implementation.
3. Show full desktop and a material close-up; also show an open app and the all-three combination.
4. Refine based on owner visual feedback before treating the finish as accepted.
5. Integrate the chosen treatment through existing ownership and drawing lifecycle.

Do not build three large independent systems. Use a small helper only if it clearly simplifies current code. Preserve approved functional geometry; flag any necessary layout change explicitly.

## Rendering and performance

- Deterministic geometry/texture; no reroll on repaint, resize, app switch or Load.
- Use fixed local decorative seeds if needed; never consume gameplay RNG or add save fields just for visual variation.
- Cache geometry/textures where useful; redraw on relevant ownership/theme/size/app-visibility changes.
- Bound polygon/curve/texture work. Do not create nodes per droplet, facet or thread segment.
- Avoid continuous processing for static decoration.
- Adapt to theme roles without borrowing the focus color so heavily that decoration looks interactive.
- Measure if a more expensive effect is introduced; do not claim performance improvement from visual simplicity alone.

## Acceptance

- Materials are identifiable at normal viewing size, not only in enlarged crops.
- Each item works alone; all three together remain balanced.
- No-item state stays unchanged; no decoration appears without ownership.
- Save/Load restores ownership appearance; genuinely new runs reset it; repaint/reopen does not alter the pattern.
- Desktop-only letter hides while an app is open unless the owner explicitly revises that rule.
- No text/focus/control obstruction or unintended hit targets.
- Check 125/150%, font/palette changes, desktop resizing and relevant app/Challenge navigation.
- No effect on purchases, story progress, read records, audio, save latency owners or transitions.
- Visual review plus relevant existing cloud tests establishes acceptance; a few changed-pixel assertions alone do not establish aesthetics.

Follow repository cloud test conventions and retain relevant layout, input, transition and accessibility coverage. Keep implementation scoped; unrelated CI and F5 latency work belongs to its own task.

## Completion record

Record chosen visual direction and any changed placement rules, PR/revision, before/after screenshots at normal size, test evidence and limitations. Distinguish a working prototype from owner-accepted visual finish.

## Follow-up: broader UI aesthetic review

The owner also requests investigation of broader UI aesthetics. Add a baseline UI review before finalizing the purchased objects. This authorizes review and proposals, not an indiscriminate redesign.

Source evidence: scripts/settings/SettingsPaletteRegistry.gd already provides dark blue/green surfaces, warm paper/ink, structural borders, selection/focus roles and authored high-contrast/color-vision variants. Preserve that visual foundation. No fresh screenshots were inspected for this follow-up, so the candidates below are not confirmed visual defects.

Review candidates:
- Hierarchy: distinguish screen titles, section headings, body text and secondary metadata through existing typography, spacing and restrained color roles. Do not shrink readable body text to create hierarchy.
- Borders: identify redundant nested outlines; retain clear panel separation, actionable affordances and focus rings.
- Surfaces/depth: compare subtle contact shadows or edge highlights on floating panels with flatter reading surfaces. Avoid uniform gloss or heavy blur.
- Composition: align headings, lists, item artwork and action rows to clear shared anchors; use spacing to group related content, not identical gaps everywhere.
- Color emphasis: keep strong accents meaningful for selection/focus/actions; decorations should not compete with them.
- Material coherence: paper-like Save/Load and Gallery surfaces, quieter computer framing, and the three purchased objects should share lighting and edge treatment.
- Small details: consistent icon stroke weight/optical alignment and corner/border treatment where applicable; preserve established functional symbols.

Suggested review sequence:
1. Capture current reading scene, desktop, Shop, Save/Load, Settings and Gallery at the reference configuration.
2. Identify the strongest two or three visible opportunities with marked before/after comparisons.
3. Prototype one coherent baseline treatment, then add each purchased item and all three.
4. Evaluate both the unpurchased and decorated experience; do not make baseline usability depend on buying decoration.

Scope clarification: the earlier "no-item state stays unchanged" acceptance applies to the purchase-effect implementation alone. If the owner chooses a separate baseline UI refinement, document it independently and compare old baseline → refined baseline → refined baseline with purchases. Do not grant purchased material motifs globally.

Respect completed interaction, 125/150% readability, palettes and approved caption/control geometry. If proposed font, content width or padding changes affect reading layout, rerun the Godot measurements and refresh DTL guidance; never leave authoring profiles stale. Prefer refinements that preserve reading metrics.

The implementation handoff must report screenshot-backed observations separately from aesthetic preferences. The previous material-style/motion questions remain open.


## Selected implementation direction, 30 October 2026

The owner selected hybrid crisp silhouettes with restrained shading and static artwork,
and delegated composition. [PR #162](https://github.com/Siuuuers/dwm/pull/162) keeps
all drawing in ComputerDesktop, adds no runtime nodes or save fields, and uses a
neutral ring seal without narrative meaning. App accents avoid the right scrollbar.
The letter fits between launcher controls and Home quick feedback, scales modestly
when space is limited, and yields entirely to failure feedback or very short layouts.

The first cloud comparison exposed an overstrict fixed-size letter guard in a wide
direct-canvas fixture and crystal silhouettes resembling pennants; the revised candidate
fixes both. Final primary previews match the game: a 1280×720 logical canvas stretched
to 1920×1080. The earlier wide-canvas result is not a normal shipped-layout defect. Rendered checks now require each item to produce visible pixels, verify the
letter is absent over apps and failure feedback, and cover both fonts, 125/150%,
two palettes, high contrast, narrow and short layouts. Purchase/Load/new-run checks
remain the existing real-owner journey. Exact revisions, final screenshots, cloud
results and remaining visual-review limitations belong to the PR acceptance record.
This work makes no measured gameplay speedup claim and does not redesign the base UI.


## Expanded material direction, 30 October 2026

The owner superseded the small-object prototype: letter ownership now gives the
computer and seven dialogue controls a subtle paper material with a neutral wax
seal; crystal ownership gives computer and live story-art surfaces restrained
edge sheen and hairline cracks; silk wraps the outer computer edge. Effects remain
static, code-drawn, noninteractive and per-run. Existing inventory is canonical.
The paper tile is generated once and reused; no imported concept art is used.

The concept board was AI-generated visual direction, not gameplay evidence.
The earlier 1920×1080 desktop previews assembled a UI shell without an active
story session and must not be described as normal playable scenes. Final review
requires active story artwork and the real seven-control rail, plus open computer
views. Test-scene captures must be labelled as such.

PR #162's prior cosmetic journey failed because screen-space crop conversion
included the root window transform when sampling its viewport texture. This is
being corrected with viewport-image scaling. Prior purchasing/save assertions
are not evidence that fresh-process Load or new-run checks completed. Current
acceptance, cloud results and screenshots remain tracked in the PR.

## Visibility revision, 30 October 2026

After reviewing the actual scene, the owner found PR #162's materials too faint.
Wax is now deferred: keep the existing letter inventory ID but remove its seal.
Paper uses a warm light computer background and seven light control plates with
contrasting dark ink; the computer footer retains dark textured chrome. Crystal
uses broader static corner reflections and branching cracks, behind computer
controls and above artwork. Silk uses a continuous thicker edge wrap. No animation,
new ownership state, imported assets or geometry changes are required.

Acceptance must include recognizable materials at normal playing size, actual
Day1 screenshots, control-state readability, and the existing purchase/Load/new-run
journey. Changed pixels alone do not establish that the materials look convincing.

## Texture-only paper and per-run crystal, 30 October 2026

The owner superseded the light paper recoloring: retain the original computer,
footer and seven-control colors; add only transparent fibres/grain. Original
lettering, active-mode, hover, press and focus colors remain authoritative.
Wax remains deferred and silk is unchanged.

Crystal selects one to three distinct corners per panel (two most often), with
irregular fracture starts and branches. Derive a private RNG seed from the
existing activated run ID and fixed panel role, never gameplay RNG or a session
instance/generation. Cache normalized geometry; resizing transforms the same
pattern. Loading the same run regenerates the same pattern without new saved
fields; a new run receives a different arrangement. Real purchase/fresh-process
Load/new-run checks compare run identity and pattern alongside rendered pixels.
