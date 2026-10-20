# Gallery caption-admission diagnosis — 20 October 2026

Disposition proposed to external C/Director: **stale test setup**, not an established supported-player defect. No follow-on repair or diagnostic run is implemented here.

Observable outcome for this increment: identify the request/owner contract mismatch at the first failing caption-admission call, preserve the distinction between observed and inferred results, and map the remaining coverage before choosing a correction. DialogicBridge owns admission; SoloReadingSession owns catalogue compilation; FrozenPresentationContext consumes the selected registration. Evidence is the retained failure plus pinned source comparison, not a new engine execution.

## Observation and exact scope

Product PR36: 2c188cd55eccad94f9a6bbf139384548be0289ea. Controller PR30: a3c37fb2417092f3aa783154cc2b0fec88da4ce6. PR1 comparison: a6decec3693ee4d57df9f879b90ace3e118c9d1d. All three remain draft/unmerged. Master rechecked at 0c8b2384415d71bd3de4ff7408640bbf60b63740; no newer master work was available.

Natural run39387121967/job118512156600 passed the completed register step, then failed caption collection with five checks, zero samples/publications and exit1. render_gallery_caption_collection.gd line66 reduces the configure result to ok=false. The actual owner refusal code was NOT retained. The original ZIP, log and metadata remain in ../gallery-post-integration39387121967 (artifact12248237640, SHA2568e74207f8cc86b3c52e206eb5b3e04dfa4b1f111ece8dba9dcdcfe846a4a173a). No duplicate archive review/run was performed.

## Request and established state

The cloud workflow starts a fresh Godot4.6.3 process with isolated test-root/data paths and --phase2r-bootstrap-mode=final. It does not select --scene-reading-fixture or DWM_SCENE_READING_FIXTURE. The test waits for Bootstrap ready, obtains the real Bridge/Profile, and successfully calls initialize(EndingReadingTimelineCatalog).

That initialize call changes the locator and reloads ending records. It does not replace the selected scene registration or clear its frozen-context cache; it does not pre-admit a caption collection. Bootstrap configures the ordinary reading catalogue through configure_reading_catalogue, a separate operation. Bootstrap contains no configure_reached_caption_collection call. Bridge's reached-caption owner starts null and its assignment occurs only after successful explicit admission.

The request uses EndingReadingFixture.catalogue(): schema1 ending_reading_catalogue with historical ending.sylvia.special.full and ending.sylvia.dark. Admissions contains one Sylvia signature and collectable_line_ids=[fixture.ending.first]. The test does not reach unlock_ending, record_reached_presentation, Menu mounting or replay.

## Validation order and deterministic mismatch

1. Bridge checks an existing reached-caption catalogue, active playback/replay, then schema1 and nonempty admissions.
2. It creates a fresh SoloReadingSession and calls configure(document), returning a compilation refusal before signature/admission validation.
3. configure accepts the document's outer shape, then requires each ending entry to satisfy _ending_entry.
4. _ending_entry requires the ending prefix AND FrozenPresentationContext.schema_for_entry(entry_id).ok.
5. FrozenPresentationContext._load_registry prefers DialogicEntryManifest.scene_registration().value.context_registry. Normal startup chooses data/manifests/scene_story_registration.json, containing Day1..Day7 and ending.alone.normal, with no Sylvia entry.
6. Thus the first historical Sylvia row violates the current catalogue contract. schema_for_entry gives frozen_context_unknown_entry internally; configure maps this to reading_catalogue_invalid. Bridge would return that compilation result before validating the admission signature.

**reading_catalogue_invalid is source-inferred, not an observed log return.** Earlier owner guards precede this branch; the log does not expose their state. Regardless of which refusal was returned in that process, this request cannot pass the unchanged current catalogue contract. The stale-setup classification therefore does not require another diagnostic just to recover the lost code. If C needs exact first-branch attribution, the only justified extra work is a separately reviewed diagnostic capturing individual setup results and the full configure result, retaining the original failure; no such run is launched here.

There is a second source-visible incompatibility downstream: EndingReadingTimelineCatalog only overrides a path after PRODUCTION.get_entry succeeds. It cannot resolve the removed Sylvia entry in the current selected manifest. A catalogue-only bypass would not establish actual native playback. The register's private availability seam does not repair either owner contract and is not proposed.

## PR1 comparison

At PR1, SoloReadingSession already enforces _ending_entry through FrozenPresentationContext. Its frozen registry loader reads the historical raw registry directly; current source adds selected-scene registration precedence. PR1's rendered fixture uses the same historical Sylvia setup, so copying it back does not repair current startup.

Current rendered test extends PR1's transient standalone Gallery exercise to actual Menu/Gallery exit, physical Profile bytes, durable History publication, refusal/uncertainty custody, focus/scroll restoration and localized status geometry. PR1's older exit expectation is discard/no merge; it is not the current behavior to restore.

## Coverage mapping (source definitions, not new passing results)

| Obligation | Existing source | Remaining boundary |
| --- | --- | --- |
| Explicit admission, exact signature, detached collection, publication vs acknowledgement, stale proofs and noncollectable lines | tests/integration/test_gallery_caption_collection.gd uses supported ending.alone.normal and real Bridge/Profile/ledger | NativeFrontier replaces the native playhead; no mounted visibility proof |
| Durable merge, duplicate silence, refusal/uncertainty retention, synchronous replacement and retry | Same integration file, 20 test definitions total | Fake file operations and simulated frontier do not prove real native captions plus physical Profile I/O |
| Actual Menu/Gallery entry, reuse, focus and exclusive Settings/Backup transitions | tests/integration/test_menu_gallery_host.gd | Does not replace native caption collection plus durable exit composition |
| Replay status, retry identity and denied-close retention | tests/integration/test_gallery_replay_status.gd | Fake Bridge; cannot qualify native playback or collection |
| Gallery register projection/availability | Accepted register run39385501032 and natural39387121967 register step | Availability is not executed captions; completed scope stays closed |
| Native mounted acknowledgement -> real Menu exit -> physical History bytes, actual refusal/uncertainty, return context and locale/status layout | Failing render_gallery_caption_collection.gd describes this connected obligation | Unexecuted after setup; reviewed coverage does not justify deleting it as redundant |

## Smallest next action and limits

Ask C to review/select stale setup and the coverage map, then authorize a bounded test-only fixture redesign around a currently registered ending and an explicitly noncanonical, physically playable caption programme. Reuse current owner-level tests for their existing obligations; preserve only the connected native/Menu/physical-History and presentation obligations unique to this rendered test. Do not blindly rename Sylvia: locator/programme validation, signature fields, multiple-version expectations and scroll setup need a coherent design reviewed before implementation.

No production admission, cache clearing, forced success, runtime change, guard relaxation, deadline expansion or broad run is proposed. No diagnostic controller is needed for the classification at this point. This packet updates the existing inventory/restart on an isolated report branch; product/controller/master/integration stay unchanged.

Known33.179067s transition latency and official Windows exported persisted completion -> Title -> fresh Load -> normal clean exit remain open and priority. Later skipped journeys remain unexecuted. No release, whole-workflow pass, production replay qualification or game completion is claimed.

Internal independent coverage review concurred with preserving the native/Menu/physical-History composition and 90 status combinations (2 styles x5 locales x3 sizes x3 statuses). This is source review, not external C approval or test execution.
