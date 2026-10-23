---
id: decision.narrative_localization_adapter
kind: decision_packet
schema_version: 1
specification_status: deferred
decision_status: decision_required
beads: ["dwm-eob"]
requirements: []
depends_on: ["req.locale.narrative_deferred"]
evidence: ["Only English narrative timelines are physically present.","No representative external localized narrative file format has been supplied."]
scope: ["Translated narrative import adapter selection."]
affected_requirement_ids: ["req.locale.narrative_deferred"]
blocking_requirement_ids: ["req.locale.narrative_deferred"]
recommended_investigation: ["Provide representative already-localized narrative files.","Compare their stable IDs, branching, markers, and translator-editable structure.","Select and contract-test the narrowest lossless adapter."]
---

# Narrative Localization Adapter

This decision blocks translated narrative import only. It does not block Phase 2R, English narrative playback, custom JSON UI localization, or the Phase 2R evidence gate.
