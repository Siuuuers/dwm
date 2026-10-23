---
id: req_packet.localization
kind: requirement_packet
schema_version: 1
specification_status: approved
beads: ["dwm-p2r.3","dwm-p2r.8"]
requirements:
  - {"id":"req.locale.custom_json","depends_on":["req.profile.partition"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.locale.manifest","depends_on":["req.locale.custom_json"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.locale.extraction","depends_on":["req.locale.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.locale.lookup","depends_on":["req.locale.manifest"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.locale.switch_atomic","depends_on":["req.locale.lookup","req.preferences.profile"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.locale.binding","depends_on":["req.locale.switch_atomic"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.locale.presentation","depends_on":["req.locale.binding"],"implementation_evidence":[],"verification_evidence":[]}
  - {"id":"req.locale.narrative_deferred","depends_on":["req.dialogic.authority"],"implementation_evidence":[],"verification_evidence":[]}
---

# req_packet.localization

## Rule req.locale.custom_json

UI localization MUST use duplicate-rejecting custom primitive-only JSON catalogs and MUST NOT use TranslationServer.

## Rule req.locale.manifest

Locale IDs, aliases, fallback chains, font profiles, release status, and catalog paths MUST be declared in one strict manifest with exactly one source locale.

## Rule req.locale.extraction

Embedded en, zh_CN, and zh_HK UI strings MUST be extracted into validated external locale files without inventing missing translations.

## Rule req.locale.lookup

Lookup MUST normalize aliases, follow an acyclic fallback chain ending at the source locale, and return a deterministic missing-key result.

## Rule req.locale.switch_atomic

Locale switching MUST validate and prepare the entire candidate, durably persist the preference, atomically publish the catalog, and roll back presentation on failure.

## Rule req.locale.binding

Localized UI bindings MUST use registered message IDs and refresh from the locale-changed signal without owning locale state.

## Rule req.locale.presentation

Locale presentation MUST select the manifest font profile and deterministic locale display metadata for every supported locale.

## Rule req.locale.narrative_deferred

Translated narrative import MUST remain deferred until representative already-localized narrative files establish the physical adapter format.
