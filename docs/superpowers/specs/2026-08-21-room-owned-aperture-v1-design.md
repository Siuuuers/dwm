# Room-Owned Aperture v1 Design

**Status:** Conversational design approved; written specification pending owner review

**Date:** 2026-08-21

**Artifact class:** Player-facing witnessed-scene architecture

**Self-review:** Passed 2026-08-21; no known P0/P1 findings

**Implementation requested:** False

**Implementation authorized:** False

## 1. Purpose

Replace the witnessed-scene portrait-register composition with one deliberately
simple first-stage architecture: a continuous, room-owned scene aperture above
the existing caption deck and transport rail.

The aperture presents the room and every required, visibly staged non-Angela
body. Angela may be physically present and speaking, but she is never pictured
inside any canonical witnessed scene owned by this host. Her unpictured
presence is an invariant presentation law, not a route state, anomaly, missing
asset, or claim that the audience literally occupies her eyes.

Version 1 begins as a deliberately narrow, development-only proof. It must
already express the complete artistic premise through absence, fixed
observation, visible surfaces, and restrained factual changes, but it cannot
own canonical routing, filter progression, or ship while any canonical scene
consumer still depends on the current host. Production adoption is one atomic
cutover after the complete registry equality gate in Section 14. Features that
merely intensify the premise remain outside this version.

This document records a design decision only. It does not authorize changes to
Godot scenes, scripts, tests, assets, manifests, imports, or project settings.

## 2. Authority boundary

Approval of this written specification selects Room-Owned Aperture as the
target architecture; it does not by itself retire or partly replace the current
canonical runtime host. At the atomic production cutover defined in Section 14,
this design narrowly supersedes the following older player-facing laws:

- the 640-by-52 physical-presence or portrait register in
  `docs/design/2026-08-14-haunted-instrumentarium-ui-manual-foundation-decisions.md`;
- the three-band portrait-register host, universal Angela body/portrait
  projection, active portrait frame, and routine third-person Angela staging in
  `docs/design/2026-08-13-narrative-scene-host-dating-hospital-challenge-ui-ux-amendment.md`;
- the equivalent portrait and visibly staged Angela requirements in
  `docs/design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md`;
- the close-portrait and Angela tableau placements for these hosts in
  `docs/design/2026-08-13-visual-art-placement-and-asset-production-guide.md`;
  and
- the centred portrait-register direction in the disposable
  `docs/superpowers/specs/2026-08-14-lawful-universe-atlas-presence-refinement-design.md`.

It retains the existing story, progression, challenge, caption, History,
transport, save/load, focus, input, localization, recovery, and
assistive-truth laws except where this document explicitly changes visual
projection. In particular:

- Angela remains Angela rather than becoming a player avatar;
- every physically present non-Angela participant remains visibly staged,
  whether speaking or silent;
- remote, hidden, or routine offscreen non-Angela speech remains invalid;
- the released game still contains no narrator, thought box, invisible
  explanatory prose, or stage direction;
- bottom-up caption memory and the pinned control rail retain their accepted
  behavior;
- the canonical no-inline-scene-choice law and challenge routing retain their
  accepted owners;
- the audience receives no relationship statistics or explanatory horror
  symbols; and
- Angela's existing desktop-workstation art remains outside this supersession.

The contrast between Angela pictured at her maintained workstation and
structurally unpictured in the scenes presented by that workstation is
intentional.

The latest owner direction authorizes removal of Angela's scene art and visual
restaging needed to preserve that invariant. It does not authorize changing a
story fact, line, relationship consequence, causal action, medical fact, or
consent boundary. Any such substantive change requires its own explicit owner
approval.

## 3. Chosen approach

Use one rectangular **Room-Owned Aperture**.

The aperture is a noninteractive composition of:

1. one authored static room surface selected from the current room's closed
   surface registry;
2. zero to three required non-Angela body layers;
3. only the object or action overlays consumed by the current authored shot;
   and
4. room-owned integer placements and z-order.

It is not a roster, portrait rail, security camera, evidence viewer, photo
frame, or speaker indicator. It has no cards, slots, names, counts, empty
holders, Angela-shaped gaps, camera chrome, reticle, timestamp, recording mark,
or hover behavior.

The camera is an authored, impersonal room coordinate. It does not bob, breathe,
pan toward a speaker, follow a cursor, cast a player shadow, show Angela in a
reflection, or imply an embodied first-person controller. A room may have only
one camera coordinate in v1. A room may nevertheless own more than one static
surface when an in-scope shot truthfully requires a global plate condition such
as weather, time or practical lighting, or an irreversible room-wide finish
that preserves the same architecture and placement geometry. Every surface in
one registry is pixel-registered to the same 640-by-224 origin, camera, scale,
architectural geometry, and compatible placement registry. A changed camera or
architecture requires a distinct room coordinate and is not a surface variant
in v1. Each surface also declares a closed `lighting_context_id`; every body,
object, and grounding asset composited with it must declare compatibility with
that context. Movable chairs, papers, clues, consent-bearing objects, and other
action-scale facts remain independently declared overlays; they do not create a
new full room surface. V1 selects a complete authored surface by ID; it does not
generate or transition between surfaces procedurally.

The room camera and Angela's unpictured spatial position are separate authored
anchors. A present Angela occupies an off-camera `angela_spatial_anchor_id` used
for truthful eyelines, distance, sound, and object blocking. That anchor resolves
to an integer source-projection point strictly outside the largest source view
`(0,0,640,224)`: `x < 0 || x >= 640 || y < 0 || y >= 224`. It is therefore
outside every active aperture crop. Its ID and room position must both differ
from the room's `camera_anchor_id` and camera position. Visible bodies orient
toward an authored person, object, or room anchor rather than automatically
addressing the lens.

### 3.1 Rejected alternatives

- A retained friend portrait register still converts presence into explanatory
  metadata and makes Angela's omission a visible UI event.
- A simultaneous room/detail split reads too readily as surveillance or
  forensic analysis and becomes cramped at 150% text.
- A global sequence of discontinuous object plates weakens ordinary body
  language and physical-action legibility. Rare object plates may be designed
  later, but they are not the scene host.
- A shippable legacy compatibility mode or mixed-host route would preserve two
  contradictory scene philosophies and is prohibited. The current host remains
  the sole canonical runtime until the one production cutover; the proof does
  not run beside it in player-facing progression.

## 4. Native geometry

The fixed native canvas remains 640 by 360. The 32-pixel transport rail remains
at `y = 328` in every text preset.

| Text preset | Room-Owned Aperture | Caption region | Rail |
| --- | --- | --- | --- |
| 100% | `(0,0,640,224)` | `(0,224,640,104)` | `(0,328,640,32)` |
| 125% | `(0,0,640,196)` | `(0,196,640,132)` | `(0,328,640,32)` |
| 150% | `(0,0,640,164)` | `(0,164,640,164)` | `(0,328,640,32)` |

V1 authors room and body composition in one 640-by-224 source space. The
smaller apertures use deterministic centred crops:

- 100%: source `(0,0,640,224)`;
- 125%: source `(0,14,640,196)`; and
- 150%: source `(0,30,640,164)`.

Background surface, grounding, shadows, bodies, and object/action overlays all
compose in that same source coordinate system before one view rectangle clips
the complete composite. For a view rectangle at `(vx,vy)`, a displayed source
point is `(source_x - vx, source_y - vy)`. V1 never crops only the background
while leaving bodies or overlays in a different coordinate system.

Every essential face, gesture, action-bearing silhouette, body relation, hand
or foot belonging to a visible non-Angela character, contact shadow or
equivalent ground contact, object, exit, and consent-bearing fact must fit
inside the shared source-safe rectangle `(0,30,640,164)`. Each room defines a
stable grounding baseline or grounding band inside that rectangle. The
additional upper and lower material visible at smaller text sizes may contain
atmosphere and room continuation, but never unique story evidence. A shot that
fails the shared safe rectangle is rejected before publication; v1 does not
create a bespoke camera or scale characters to repair it.

Each consumed visual asset's manifest is the sole owner of its integer local
bounds, registered pivot, and `local_essential_bounds[]` rectangles keyed by
public fact ID. Body families share one registered ground pivot across their
variants. Shot data references the required fact IDs rather than reauthoring
rectangles. The validator transforms every local rectangle through its integer
room placement into source space and checks the shared safe core. Human content
review proves that the declared fact set is complete rather than attempting to
infer story meaning from pixels.

The selected 640-by-224 room surface is pinned to source origin with identity
transform and pivot `(0,0)`. Its local bounds therefore equal source bounds.
Bodies, participant-grounding layers, and object/action overlays alone resolve
through room placements. Transformed-bound verification covers both the surface
identity case and at least one nonzero placed asset.

The existing hard scene-to-caption boundary is sufficient. V1 adds no aperture
mask, frame asset, registration crown, or room-specific chrome.

Legacy 1280-by-720 reference coordinates are exactly 2x the native layout, not
a second topology:

| Text preset | 2x aperture | 2x caption region | 2x rail |
| --- | --- | --- | --- |
| 100% | `(0,0,1280,448)` | `(0,448,1280,208)` | `(0,656,1280,64)` |
| 125% | `(0,0,1280,392)` | `(0,392,1280,264)` | `(0,656,1280,64)` |
| 150% | `(0,0,1280,328)` | `(0,328,1280,328)` | `(0,656,1280,64)` |

2x, 3x, and 4x presentation use integer nearest-neighbour scaling with integer
pivots and no gap, overlap, resampling, or layout reflow.

## 5. Presence and projection

Physical presence and pictorial projection are separate facts.

- `shot_participants` remains the semantic list of everyone physically present.
- `visible_bodies` contains every physically present non-Angela participant
  visibly staged in the aperture, whether speaking or silent.
- Angela may be `present + speaking + unpictured`.
- Angela is invalid in `visible_bodies` and receives no hidden slot, placeholder,
  missing-art icon, shadow, reflection, or assistive art node.
- Every physically present non-Angela participant appears exactly once in
  `visible_bodies`. V1 does not support a present but pictorially hidden or
  publicly undisclosed non-Angela identity; such a shot is rejected before
  publication.
- An absent character receives no body, placeholder, reserved geometry, or
  assistive node.

For explicitly participating characters,
`visible_bodies.character_ids == shot_participants - {Angela}`. Incidental
crowd texture is decorative environment art, never a participant or speaker.
The validated visible-body count is 0 through 3, character IDs and placements
are unique, and each authored entry or exit atom changes semantic presence and
body projection together.

Angela's nonprojection is identical across relationship phases, routes, health,
Observer state, language, theme, text size, replay, save/load, and failure
conditions. No character or interface copy remarks upon it.

An Angela-only shot therefore contains its authored location plate and any
already-public object states, but no character body. That visual condition is
not sufficient to prove whether Angela is present; dialogue, sound, scene
continuity, and other ordinary facts retain that work.

Priscilla-Lavinia scenes in which Angela is genuinely absent use the same host
and camera grammar. The host never changes skin or displays an attendance mark.

## 6. Minimal art and staging contract

V1 creates only assets consumed by authored shipped shots:

- one or more 640-by-224 static, shipping-approved room surfaces per required
  room, limited to variants consumed by in-scope shots and registered against
  the same origin, camera, scale, architecture, and placement geometry;
- one transparent base body variant for each visibly staged non-Angela
  character;
- only those complete body variants referenced by a shipped shot, including
  any consumed pose, expression, wardrobe, weather, or lighting-context facts;
- participant-dependent contact shadow or equivalent grounding baked into that
  body variant, or carried by a separately declared overlay whose presence,
  placement, and lifecycle are parity-bound to that body; and
- only those object overlays required to show an authored public fact.

A reusable room surface may bake only architectural and ambient shadows that
remain true at every occupancy using that surface. It never contains a shadow,
depression, reflection, or other trace belonging to a participant who may leave.

A location plate may remain deliberately abstract and materially restrained.
It can ship only after a separate art review explicitly accepts it as the
canonical final environment asset and validation proves every essential body,
object, route, action, and clue is owned by visible, validated layers. A
development or pre-release placeholder cannot become canonical merely by being
renamed or marked `non-evidentiary` in metadata. Approved canonical art is never
labelled `placeholder` in the player surface.

The first proof needs only one recurring university room, two friends, their
base poses plus at most one required action pose each, and one literal movable
object. Four shot states reuse the pixel-identical room and camera:

1. one canonical, pilot-proof exact state with Angela present and zero visible
   bodies, containing either an Angela line or public action that passes
   Sections 7 and 8;
2. Angela present with one visible friend;
3. Angela present with two visible friends; and
4. Priscilla and Lavinia present without Angela.

One of those states is also shown at 150% text. If the zero-body state and the
Angela-attended friend states feel intentionally addressed while the private
friend state feels private without an Angela token, the visual grammar
succeeds.

Scene changes are direct publications. V1 has no tween, lip flap, idle loop,
parallax, pose interpolation, camera motion, fade, or count-dependent body
scaling. A body variant, room surface, or object state changes only at an
authored `staging_atom_id`, and save/load reconstructs that exact settled atom
without replaying a transition.

## 7. Speech and prose

The aperture adds no visible speaker label, portrait emphasis, personal colour
edge, caption notch, or active-frame symbol.

The existing line record continues to own the internal semantic `speaker_id`.
Its player-facing projection also owns a separate
`public_speaker_disclosure`, either a named public identity token or
`intentionally_ambiguous`. Visible dialogue, voice performance when present,
wording, sequencing, eyelines, and body staging provide ordinary audience
evidence. Ambiguity that is authored in the scene is not repaired by new UI
metadata.

Angela may speak dialogue or audible self-talk while unpictured. Her visual
absence does not permit narration, thought transcription, prose interpretation,
or action brackets. A nonverbal beat owns no speaker.

Assistive presentation consumes only `public_speaker_disclosure`, never the
internal `speaker_id`. It may announce a named public identity when the same
source is already disclosed through ordinary visual, audible, or textual
staging. For an intentionally ambiguous line it exposes no solved identity. It
never says `offscreen`, `invisible`, `observer`, `missing portrait`, or any
inferred intention. This is modality-appropriate access to the public line
source, not an audience-facing interpretation or hidden-story disclosure.

## 8. Angela physical-action boundary

V1 supports unpictured Angela speaking and observing. It supports an
Angela-authored physical action only when that public action is unambiguous
through a visible consequence inside the shared safe core, another visible
body or object state, and a matching public assistive action atom. Exact sound
or dialogue may reinforce that evidence but never carries an essential causal,
medical, consent, action, or speaker fact alone. The same public fact must
remain available with voice, SFX, and motion disabled.

Every essential causal, medical, or consent-bearing action is an authored action
atom declaring its private causal `internal_actor_id`, separately governed
public actor disclosure, action kind, visible overlays, exact required visible
character IDs, accessible description, and visual-body requirement. Internal
ownership drives validation only and never leaks through player or assistive
projection. An action that requires Angela's hand, body, location, or contact to
be seen declares `angela_body_required` and is rejected by v1. The shot must be
restaged truthfully or rejected before publication. V1 does not add a POV-hand,
partial-body, cut-in, or invisible-object-motion system to patch such a scene.

This is a content-validation boundary, not permission to omit physical facts.

## 9. Minimal scene data boundary

The eventual runtime may express the design through equivalent structures, but
the minimum semantic boundary is:

```text
PublicDescriptionAtom
  atom_id
  covered_public_fact_ids[]
  localized_factual_copy_key

VisualAssetRecord
  asset_variant_id
  integer_local_bounds
  registered_pivot
  compatible_lighting_context_ids[]
  local_essential_bounds[] { public_fact_id, integer_local_rect }

RoomApertureSpec
  room_id
  camera_anchor { camera_anchor_id, room_position }
  spatial_anchors {
    anchor_id -> room_position + integer_source_projection_point
  }
  placements { placement_id -> integer position + total_z + ground_baseline }
  surfaces {
    room_surface_id -> background_asset_id + lighting_context_id
                       + shipping_approved
                       + reviewed_surface_facts[] {
                           public_fact_id,
                           description_atom_id?,
                           accessibility_required
                         }
  }

WitnessShot
  shot_id
  staging_atom_id
  projection_variant_id
  room_id
  room_surface_id
  public_room_disclosure = named(public_location_token) | intentionally_ambiguous
  shot_participants[]
  angela_spatial_anchor_id?
  visible_bodies[] {
    character_id,
    public_identity_token,
    body_variant_id,
    placement_id,
    grounding_overlay_id?,
    orientation_target = spatial_anchor(anchor_id) | body(character_id) | object(layer_id)?,
    required_public_fact_ids[]
  }
  visible_grounding_overlays[] {
    layer_id,
    asset_variant_id,
    bound_character_id,
    required_public_fact_ids[]
  }
  visible_object_overlays[] {
    layer_id,
    asset_variant_id,
    placement_id,
    required_public_fact_ids[],
    public_object_description_atom_id?
  }
  visible_action_atoms[] {
    atom_id,
    internal_actor_id = character_id | environment,
    public_actor_disclosure,
    action_kind,
    overlay_ids[],
    required_visible_character_ids[],
    public_visual_fact_ids[],
    public_action_description_atom_id,
    visual_body_requirement = none | visible_non_angela | angela_body_required
  }
  public_scene_description_atom_id?
```

Line data continues to own internal speaker, public speaker disclosure,
caption, timing, and transport facts. Aperture data does not duplicate
them. The ordinary assistive scene group is generated from
`public_room_disclosure`, the selected shot's closed public-visual-fact ledger,
and validated public participant identity tokens. Internal character IDs,
`room_id`, `room_surface_id`, asset paths, and an unpublished time, weather, or
location fact are never announced.

For each candidate shot, the validator derives
`selected_public_visual_fact_ids` from the selected surface's reviewed required
facts, each visible body's required facts, every participant-grounding and
object overlay's required facts, and every action atom's public visual facts.
Each surface, body, grounding, or object fact must exist in its selected asset
manifest. Human review certifies that this closed set contains every essential
nontextual gesture, gaze, body relation, ground contact, object state, action,
and clue visible in the composition.

The selected surface contributes exactly its reviewed facts marked
`accessibility_required`. Each such fact must reference a description atom on
that same selected surface; a decorative fact may omit one. Shot data owns no
parallel surface-disclosure list and therefore cannot announce a fact from a
different surface or suppress a required selected-surface fact.

Every accessibility-required fact in that set is covered by exactly one
`PublicDescriptionAtom`; an atom may cover only facts in that same selected set.
Surface descriptions cover selected surface facts, persistent-object
descriptions cover object facts, and action descriptions are owned solely by
their action atoms. A `public_scene_description_atom_id` is optional only when
no residual arrangement or body fact remains; otherwise it is required to cover
those remaining facts. Omitted, extra, duplicate, or cross-surface fact coverage
rejects the candidate before publication. All descriptions state visible facts
only, never interpretation.

Placement and spatial-anchor IDs are unique, room-owned, and deterministic. The
presence of Angela is derived only from `shot_participants`: her spatial anchor
is required if and only if she is present and forbidden otherwise. Its ID and
room position differ from the camera, and its source-projection point lies
outside every active source view. Every orientation target resolves to an
existing typed spatial anchor, visible body, or visible object in the shot.
Each visible body's public identity token must match its registered character
and be disclosed by the same ordinary player-facing scene; internal IDs never
substitute for that token.
Every consumed body, object, and participant-grounding asset must list the
selected surface's `lighting_context_id` as compatible. Art review verifies
matched light direction, value hierarchy, palette, and shadow logic; metadata
alone cannot certify the composite.

When a body references `grounding_overlay_id`, exactly one grounding overlay
with that ID must bind to the same character. Its placement, baseline, entry,
exit, variant fallback, staging publication, and restore lifecycle derive from
the body; its total z is the registered layer immediately beneath that body, and
it has no independent save or persistence state. A body may instead carry baked
grounding, but an orphan or mismatched grounding overlay is invalid.

Every essential causal, medical, or consent-bearing fact requires one declared
action atom. Its internal actor must be a present character or `environment`.
`visual_body_requirement = none` requires an empty visible-character list;
`visible_non_angela` requires a nonempty exact list whose members all exist in
`visible_bodies`. When a non-Angela actor's own body carries action evidence,
that actor must appear in the required list. An Angela-owned action may rely on
reviewed visible consequences or other exact visible-character bindings, but v1
rejects `angela_body_required`. Public actor disclosure is validated separately
and can never expose more than the authored audience-visible fact.

Every body, object, and grounding layer uses a unique ID and one deterministic
total z-order; only bodies and ordinary objects own independent placements.
Within one `shot_id + staging_atom_id` pair, every distinct settled composition
has a unique semantic `projection_variant_id`.

Save/load persists the semantic `shot_id`, `staging_atom_id`,
`projection_variant_id`, and `projection_variant_fingerprint` alongside the
existing canonical route/consumer owner, line, and focus state. Load resolves
the variant from those semantic owners, recomputes its fingerprint, and accepts
the candidate only when it matches the persisted and canonical value. It never
persists raw transforms or asset paths. Reprojection therefore resolves the
same validated room surface, body variant, grounding, placement, action, public
fact binding, and object set.

The aperture must receive a complete validated shot candidate before it
publishes any visible layer. It never exposes a half-populated composition.

## 10. Input, challenge, and accessibility

The entire aperture is pointer-inert, nonfocusable, and absent from sequential
or directional focus. It has no click, hover, tooltip, inspection, drag, or
hidden hotspot. Initial and restored focus remain owned by the current caption
or the existing control rail under their accepted precedence.

The existing Minesweeper challenge host freezes and dims the exact settled
aperture before presenting its board. Room-Owned Aperture adds no board state,
clue, input, animation, or hidden-special projection.

Assistive output exposes one nonfocusable scene group assembled from semantic
facts, not asset filenames. It may report only:

- the publicly disclosed room or location;
- the visibly staged non-Angela people in stable scene order;
- visible objects and actions that have authored description atoms; and
- only the public speaker disclosure through the caption/TTS owner.

The scene group is derived from visible bodies rather than from every internal
`shot_participants` entry. An unpictured Angela enters assistive output only
through an already-public named speaker disclosure or public action atom, never
merely because the private presence flag is true. The group is announced only
when its public semantic contents change; load, uncover, focus restoration, or
reprojection does not automatically repeat it.

It never describes Angela's unseen appearance, pose, gaze, body, or intention.
It never announces an empty aperture, absent friend, missing slot, camera
position, relationship state, anomaly interpretation, or decorative difference.
Individual visual layers are hidden from assistive traversal to prevent
duplicate announcements.

Public action-description and scene-description atoms are localized,
modality-equivalent factual accessibility metadata. They are not rendered as
captions, History entries, narrator prose, stage directions, or interpretation.
Their actor disclosure and factual content may never exceed what the ordinary
sighted presentation already makes public.
Persistent-object descriptions follow scene-group change cadence; an action
description publishes only with its action atom. The same fact never has both
owners and is never announced twice merely because its resulting object remains.

High Contrast and colour-differentiation tuples remap functional captions,
focus, and rail controls only. They never recolour scene art. Reduced
Motion publishes the same static shot and pose state immediately.

## 11. Asset failure and recovery

Development builds may use explicit, visibly noncanonical bounds proxies for a
room surface, body variant, overlay, or placement. They preserve source size,
safe-core bounds, position, and z-order and remain outside assistive output and
canonical screenshots.

Canonical player-facing scenes do not use a missing-picture icon. The earlier
icon idea is retained only for development tooling or a future non-narrative art
placement where it cannot replace a physical fact.

Before scene publication, release validation requires:

- a valid room and a separately art-approved `shipping_approved` asset for
  every consumed room surface, regardless of whether that surface owns an
  essential fact;
- every required non-Angela base body variant;
- every referenced required body variant or a declared optional-variant
  fallback to the same character's base body, where the base body preserves
  every public gesture, gaze, body relation, action, medical, clue, wardrobe,
  weather, and consent fact;
- every placement and z-order;
- lighting-context compatibility and art-reviewed light/shadow coherence for
  every composited body, object, and participant-grounding layer;
- shared-safe-core compliance;
- every required object/action overlay; and
- every required surface, object, action, or scene `PublicDescriptionAtom` and
  exact closed-set fact coverage.

Missing any required room surface, body variant, placement, action, consent
evidence, or consumed description atom enters trusted recovery before the scene
becomes visible. The system never shows a silhouette, initials, wrong
character, old room, technical checkerboard, invented generic room, dark
fictional field, or half-populated aperture.

## 12. Deliberately deferred within Room-Owned Aperture

The following are future refinements and receive no v1 scaffold, runtime enum,
asset family, save field, setting, or compatibility branch:

- additional static registered room-owned camera positions or hard cuts, after
  a separate design pass and never selected by speaker or relationship state;
- large expression and pose libraries;
- cross-day object-state catalogues beyond required shot overlays;
- foreground lattices, blinds, masks, or architectural occluders;
- simultaneous detail panes or compound instrument fields;
- close material plates and cinematic fragments;
- unconsumed room-surface expansion, dynamic weather transitions, and
  procedural time-of-day or lighting systems;
- parallax, ambient motion, lip flap, shaders, particles, bloom, or animated
  texture;
- more than three visible bodies or automatic layout;
- physically plausible local sound irregularity that remains within the
  established anomaly budget; and
- room-specific aperture frames and irregular host shapes.

## 13. Prohibited without a new explicit owner-approved architecture

The following do not become available merely because v1 is complete. Each
requires a new owner decision that explicitly supersedes this specification:

- any Angela hand, partial body, full body, reflection, shadow, portrait,
  silhouette, vacancy marker, absence token, or missing-art substitute;
- an embodied or Angela-owned camera, POV cue, player shadow, camera breathing,
  reticle, timestamp, recording chrome, or surveillance explanation;
- per-shot zoom, pan, continuous camera motion, or speaker-, relationship-, or
  pressure-responsive reframing;
- a portrait register, legacy scene host, compatibility mode, or participant
  roster;
- clickable scenery, inspection mode, tooltips, hover evidence, or any focus
  path entering the aperture;
- a permanent compound/multiple-aperture host;
- impossible physical repetition, geometry drift, delayed or impossible
  reflection, or other effect that establishes impossible physics;
- an Observer-specific discontinuity that visibly exposes hidden Observer
  state; and
- narrator prose, thoughts, invisible stage directions, or explanatory labels.

Literal Venetian blinds, permanent empty chairs, measuring grids, and other
recognizable literary shorthand are not required future milestones. If ever
used, they must first be ordinary authored facts of a location rather than
proof that the design understood a reference.

## 14. Canonical-shot feasibility gate

Before any v1 implementation plan, a read-only canonical shot ledger must derive
`canonical_aperture_state_keys` from the authoritative route, host-consumer,
shot, and staging registries rather than from a handwritten genre list. Each key
is `(consumer_id, shot_id, staging_atom_id, projection_variant_id,
projection_variant_fingerprint)`.
The key set includes every consumer and every exact canonical settled state it
can project: Narrative and Dating scenes, visible Priscilla-Lavinia private
scenes, Hospital, ordered-ending steps, and Gallery or Rehearsal replay
consumers wherever they project the same canonical states.

The deterministic `projection_variant_fingerprint` covers every aperture and
public scene-projection field that can vary beneath one `shot_id` and
`staging_atom_id` pair: room coordinate, surface and lighting context;
participants and Angela anchor; body variants, placements, orientations, and
grounding; object and action overlays; and the closed public
visual-fact/description bindings. It is derived from validated semantic IDs and
records, not raw pixel sampling or runtime transforms. Projecting the first two
fields of every state key also proves the complete consumer-to-shot edge set.
Line-owned caption and `public_speaker_disclosure` data remain outside this
fingerprint because the retained caption owner consumes them; their per-line
parity is tested separately in Section 15.

The ledger may also name a smaller `pilot_proof_state_keys` subset. That
subset is development-harness-only, cannot own canonical route or progression,
and cannot ship. Noncanonical fixtures can test renderer mechanics but never
count as content coverage. The ledger must prove for every distinct pilot or
production state named by those keys:

- no shot requires more than three visible non-Angela bodies;
- one room coordinate and the shared 164-pixel safe core preserve every
  essential body, ground contact, object, exit, and action;
- every required weather, lighting, time, or irreversible room-wide condition
  resolves to one consumed, static, shipping-approved, pixel-registered room
  surface, while changed architecture uses a distinct room coordinate and
  movable or evidentiary facts remain declared overlays;
- every Angela-owned causal, medical, or consent-bearing action has truthful
  unpictured staging, declares its exact internal actor and required visible
  character bindings, and does not require `angela_body_required`;
- every silent as well as speaking non-Angela participant remains visible;
- every essential action remains publicly available with voice, SFX, and motion
  disabled; and
- the pilot includes at least one canonical Angela-present shot with zero
  visible bodies that passes the speech/action truth rules.

Any failure blocks that exact state, and therefore its shot, from the pilot
proof or production support set. It requires an explicit owner-approved
restaging or a revision of this specification; the project may not silently
remove, weaken, or reinterpret the story beat. Before production cutover, the
current host remains the sole canonical player-facing owner and the
Room-Owned Aperture proof cannot intercept, filter, or reroute canonical
progression.

Production readiness requires the build-failing equality
`v1_supported_state_keys == canonical_aperture_state_keys`. The check fails for
any missing or extra consumer, shot, staging atom, or frozen projection variant,
so neither an unmigrated presenter nor a later unsupported composition can hide
inside a passing shot. Only after exact-state equality and all per-state proofs
pass may one atomic change switch every consumer to Room-Owned Aperture and
remove the retired host. No shippable build may mix the two hosts, keep a
compatibility branch, or route an unsupported state through either an
approximation or a fallback.

## 15. Verification gate for later implementation

Any later implementation plan must prove at minimum:

- exact native geometry and its 2x reference mapping, plus gap-free,
  overlap-free nearest-neighbour presentation at 2x, 3x, and 4x;
- one whole-composite crop transform shared by room surface, grounding, bodies,
  shadows, and overlays;
- the room surface using an origin-pinned identity transform while a nonzero
  body/object placement proves local-to-source bound transformation;
- zero, one, two, and three visible non-Angela bodies at all three text sizes;
- `visible_bodies.character_ids == shot_participants - {Angela}`, unique body
  and placement IDs, deterministic total z-order, and entry/exit parity;
- silent present non-Angela participants remaining visibly projected;
- every separate grounding overlay bound to exactly one body and entering,
  changing, restoring, and leaving with it, including a no-ghost-after-exit
  fixture;
- manifest-owned local bounds and pivots transforming through one integer room
  placement into source space, including a transformed-bound fixture, then
  passing machine containment and human fact-completeness review;
- shared-safe-core compliance without scaling or essential cropping;
- exact static room-surface selection for every consumed global physical state,
  with every variant sharing origin, camera, scale, architectural geometry, and
  placement compatibility;
- lighting-context compatibility plus reviewed direction, value, palette, and
  shadow coherence for every surface/body/object/grounding composition;
- Angela-spoken, friend-spoken, and nonverbal beats with no visible speaker UI;
- each named or intentionally ambiguous public-speaker disclosure exposing
  exactly its declared public fact in every applicable modality: named lines
  remain named only where already public, ambiguous lines remain unsolved, and
  a named Angela case retains ordinary non-audio evidence with voice disabled;
- `angela_spatial_anchor_id` existing if and only if Angela belongs to
  `shot_participants`, with its ID and room position distinct from the camera
  and its projection point outside all active source views;
- every body orientation target resolving through its declared spatial-anchor,
  body, or object namespace;
- named and intentionally ambiguous public-room disclosures exposing no internal
  room or surface fact to assistive output;
- a closed `selected_public_visual_fact_ids` set with omission, extra,
  duplicate-owner, cross-surface, and residual-scene-description negative
  fixtures;
- every essential action atom validating its private internal actor, public
  actor disclosure, exact required visible-character bindings, and body-evidence
  requirement, with v1 rejecting `angela_body_required`;
- negative action fixtures rejecting an absent character actor, an empty list
  for `visible_non_angela`, a nonempty list for
  `visual_body_requirement = none`, an actor body omitted when it carries the
  evidence, and any public disclosure stronger than the visible fact;
- every essential action remaining available with voice, SFX, and motion off;
- Angela-attended and genuinely Angela-absent scenes using one unchanged host;
- one canonical pilot shot proving Angela present with zero visible bodies;
- entry, exit, body-variant, room-surface, and object-state publication as
  static cuts;
- exact save/load restoration from semantic `shot_id`, `staging_atom_id`, and
  `projection_variant_id`, with the recomputed fingerprint matching the
  persisted canonical fingerprint;
- two variants sharing one shot and staging atom saving and restoring to their
  respective distinct projection fingerprints;
- focus never entering the aperture;
- mouse, keyboard, and controller behavior remaining unchanged;
- truthful assistive scene and speaker projections without invented Angela art;
- challenge freeze/dim preserving the exact settled aperture;
- persistent-object and action descriptions retaining one distinct announcement
  owner and their respective scene-change/action-publication cadence;
- optional body-variant fallback using only the same character's base body and
  preserving every public visual fact;
- a missing required room surface, body variant, placement, safe-core fact,
  action, or consumed description atom entering trusted recovery before
  publication;
- no portrait node, Angela art slot, missing-picture icon, legacy mode, or
  transition state surviving in the v1 host;
- production equality over every canonical
  consumer/shot/staging/variant-ID/fingerprint state key, including complete
  projected consumer-to-shot edges, followed by one atomic all-consumer cutover
  with no mixed-host build; and
- a negative coverage fixture adding a later staging atom or frozen variant
  beneath an already-supported shot and proving the equality gate fails.

## 16. Completion boundary

The development proof is complete when one fixed rectangular scene renderer and
one shot validator can simulate and validate every exact state in
`pilot_proof_state_keys` outside canonical progression while reusing the
existing caption, challenge, focus, transport, save/load, and
accessibility owners.

Production v1 is complete only when that renderer and validator cover the full
registry-derived state-key set, the build proves
`v1_supported_state_keys == canonical_aperture_state_keys`, and the
atomic all-consumer cutover retires the former host without a compatibility
path.

It is not incomplete merely because it lacks camera variety, animation,
close-ups, rich expression libraries, or Observer spectacle. Those elements may
deepen a future art pass; none is necessary to make the absent centre, fixed
observation, and factual room surfaces legible in the first stage.
