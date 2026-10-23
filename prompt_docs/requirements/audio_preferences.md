---
id: req_packet.audio_preferences
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.3"]
requirements:
  - {"id":"req.audio.sole_owner","depends_on":["req.runtime.sole_owners"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.audio.semantic_context","depends_on":["req.audio.sole_owner"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.preferences.profile","depends_on":["req.profile.partition"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.preferences.reset","depends_on":["req.preferences.profile"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.audio_preferences

## Rule req.audio.sole_owner

AudioManager MUST be the sole owner of live music, ambience, voice, and sound-effect playback and bus application.

## Rule req.audio.semantic_context

Audio requests MUST use registered semantic context IDs and deterministic transitions rather than scene-local direct player control.

## Rule req.preferences.profile

Global language, audio, skip, display, accessibility, and input preferences MUST be validated and persisted through ProfileManager.

## Rule req.preferences.reset

Preference, visited-history, gallery, and entire-profile resets MUST use separate explicit commands and MUST publish only durable results.
