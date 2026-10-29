# Presentation fixtures

For current production authoring, use the
[DTL-first story guide](../../../docs/agent/dtl-story-authoring.md).
Entries, artwork placement, checkpoint arrival and Gallery membership are authored
in DTL; export generates registrations. Reusable image/layout records stay in
`data/manifests/art_placements.json`.

`named_checkpoints.json` remains a legacy owner-test fixture. Its
`presentation_entries` bindings and `{checkpoint_id, overlays}` saved shape test
existing adapters; do not copy those duplicate entry lists into a new story.
The fixture is not installed in the production catalogue and selects no final
story location.

Reusable `overlay_labels` use an existing `asset_id` and `rect` of
`[x, y, width, height]`, relative to the full scene art aperture. Values 0 and 1
name its edges; width and height must be positive. The image keeps its aspect
ratio inside the rectangle. Current DTL `show` commands select these presets by
named slot, preserving slot order when replacing an image.
