# Haunted Instrumentarium Silent Audio Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the unshipped legacy audio model with a verified, truth-safe, accessible, save-coherent Godot 4.6.3 audio and system-TTS platform that contains no production audio assets and makes authored environmental silence a valid result.

**Architecture:** Pure catalogues and immutable value objects turn only audience-visible presentation facts into deterministic scene plans. `AudioManager` alone owns fixed live players beneath a checked-in bus graph, while separate mutation layers own authored playback, profile/output settings, TTS ducking, and fail-closed recovery. A monotonic `RunCommitCoordinator` publishes narrative and audio state together, and six existing restore participants remain the outer save transaction. A system-TTS coordinator uses an injectable platform port and never enters the game buses.

**Tech Stack:** Godot 4.6.3-stable-mono, GDScript, Dialogic 2.0 Alpha 19 with its native live-audio paths disabled, GUT, strict JSON/value-object schemas, the repository's isolated Godot wrapper, and PowerShell static/export verification.

**Authority:** `docs/superpowers/specs/2026-08-14-haunted-instrumentarium-audio-production-manual-design.md` (Accepted, 2026-08-14), as the later authority over its explicitly named Settings clauses.

**Status:** Draft for exact user review. This file authorizes no implementation, asset operation, playback, audition, or Pass 1A resumption. Before Task 1 begins, record the approved canonical-text SHA-256 and this exact path in the repository's approval authority, obtain scope-matched execution permission, and select one bounded Beads issue.

## Global Constraints

- [ ] Required skills during execution: `superpowers:test-driven-development`, `incremental-implementation`, `godot-prompter:audio-system`, `godot-prompter:save-load`, `godot-prompter:godot-testing`, `git-workflow-and-versioning`, and `superpowers:verification-before-completion`. Use `debugging-and-error-recovery` whenever a RED or GREEN result differs from the expected assertion.
- [ ] Work only in `C:\Users\glori\Documents\dwm\.godot\worktrees\audio-audition-pass-1`. Preserve the unrelated original workspace and the ignored audition cache.
- [ ] Re-audit HEAD, worktree status, active Beads issue, and the approved plan hash before every task. Stop if authority, hash, or physical assumptions drift.
- [ ] Do not research, download, copy, buy, decode, play, audition, edit, render, import, register, or ship any audio asset. Do not resume Pass 1A. Test streams are generated in memory or kept under `tests/fixtures/`; the OS audio device remains unused.
- [ ] Do not compose, record, synthesize, clone, or AI-generate audio. Do not add a production `audio/` binary merely to make a test pass.
- [ ] The game has not shipped. Profile v1, run/save v1-v2 audio shapes, Voice preferences, semantic context aliases, route/mood/ending adapters, and deprecated cue IDs receive no compatibility layer. Unsupported development data fails factually; it is not silently reinterpreted.
- [ ] `AudioManager` is the sole live owner of game `AudioStreamPlayer` nodes. Every live player is a descendant of it. System TTS is external platform speech and is owned only through `SystemTtsCoordinator` and its adapter.
- [ ] No player, bus, profile, save, resolver, caption, diagnostic, or asset ID may encode raw route, ending, affection, jealousy, desire, mood, attitude, medical, supernatural, future, or hidden-tier state.
- [ ] Optional failure remains local to audio. It restores a determinate prior layer or enters the silent recovery latch; it never turns a technical problem into fiction or latches the whole application fatal merely because an optional sound is unavailable.
- [ ] Every task follows RED -> smallest GREEN -> focused regression -> `git diff --check` -> exact-path staging -> one bounded commit. A parse error, missing dependency, wrong test subject, or unrelated failure is not an acceptable RED.
- [ ] Run Godot only through `tools/testing/Invoke-IsolatedGodot.ps1`. Never pass caller-owned `--path`, `--headless`, or `--log-file`; the wrapper owns isolation and logs.
- [ ] Do not weaken existing narrative, transaction, storage, localization, input, Gallery-unlock, or accessibility guarantees to make audio tests pass.
- [ ] The final checkpoint is a silent-system review. Music/SFX selection, acquisition, audition, edits, runtime bytes, mix approval, and shipping remain separate later gates.

### Test command contract

Every task below supplies its exact focused `-gtest` list. Final import and whole-suite gates use:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-silent-import' -LogName 'audio-silent-import.log' -GodotArgs @('--editor','--quit-after','1')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-silent-all-tests' -LogName 'audio-silent-all-tests.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests','-ginclude_subdirs','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-silent-dialogic-smoke' -LogName 'audio-silent-dialogic-smoke.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/smoke_dialogic_timelines.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-silent-scene-smoke' -LogName 'audio-silent-scene-smoke.log' -GodotArgs @('-s','res://tests/smoke_load_scenes.gd')
```

## Frozen cross-task decisions

1. **Profile v2:** root keys are exactly `schema_version`, `gallery_unlocks`, `gallery_transaction_receipts`, `visited_line_ids`, `preferences`, and `input_mappings`. `migration_receipts` is removed. Profile v1 is unsupported rather than migrated.
2. **Preference vocabulary:** the complete accepted Settings vocabulary is reconciled, then extended only by `preferences.audio.output_mode`, `preferences.accessibility.sound_detail_text`, and `preferences.reading.lower_background_during_narration`. There is no Voice field or voice selector.
3. **Audio snapshot:** `audio_snapshot` has exactly eleven keys: `schema_version`, `plan_id`, `plan_revision`, `phase_id`, `variant_set_id`, `stable_selections`, `anomaly_ids`, `omission_ids`, `signature_ids`, `resume_anchor_id`, and `harmless_texture_seed`.
4. **Stable selection value:** each `stable_selections[slot_id]` has exactly `asset_id` and `derivative_revision`. A wholly silent plan has an empty map; no path is serialized.
5. **Run/save v3:** `RunSnapshotSchema` and `SaveDocumentSchema` become v3. The run snapshot renames `audio_context` to `audio_snapshot` and adds top-level non-negative `run_commit_revision`.
6. **Load revision:** a saved revision is coherence evidence, never a reusable async identity. Successful Load publishes `max(current_revision, saved_revision) + 1`.
7. **Neutral profile memory:** no second profile ledger is added. `ProfileManager.get_eligible_audio_memory_ids(surface_id)` derives only `memory.completion_present` for one or more visible Gallery unlocks and additionally `memory.completion_plural` for two or more. It returns nothing outside `META_POST_ENDING_TITLE`, `META_BACKUP_LOAD`, and `META_GALLERY_REPLAY`; ending identity never crosses the boundary.
8. **Silent catalogue:** production `asset_catalogue.json` contains zero assets. The commissioning manifest contains the accepted 35 role families and all exact member IDs, but role availability is not a runtime asset record. Missing members produce factual technical silence and preserve their non-audio equivalent.
9. **Fixed players:** Music 2, Ambience 2, protected Evidence/Anomaly 1, Material/SFX 4, UI 3, Settings Preview 1, Voice 0. Protected requests never wait in a timing-changing queue.
10. **TTS constants:** duck `-12 dB / 120 ms`, recovery `180 ms`, start watchdog `3000 ms`, stop watchdog `3000 ms`, not-speaking drain `750 ms` sampled every `100 ms`, and utterance deadline `min(120000, max(10000, 1000 + 600 * grapheme_count))` milliseconds.
11. **Settings TTS specimen:** localized neutral text is `This is a reading test.`, `这是朗读测试。`, and `這是朗讀測試。`; it creates no presentation receipt.
12. **No production detail text yet:** production Sound Detail Text registry is empty until an approved audible command exists. Tests use fixture-only proposition records.

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Accepted Settings vocabulary and current Profile v1 drift | Strict Profile v2 plus one explicit validation/rendering registry |
| 2 | Audio narrator law, role manifest and surface atlas | Pure request/catalogue/template/plan resolver with a silent production catalogue |
| 3 | Immutable plan and canonical narrative capture | Exact audio snapshot schema and monotonic run-commit lease protocol |
| 4 | Profile v2 and checked-in mix law | Bus layout, fixed runtime seam and compositional gain/output layers |
| 5 | Pure plans, runtime seam and mutation layers | Deterministic pools, epoch-safe transitions and local silent recovery |
| 6 | Live manager and lifecycle boundaries | Opaque suspension leases, Universal Pause, focus behavior and preview policy |
| 7 | Snapshot/coordinator plus six restore owners | Coherent New Run, Save, Load, reconciliation and production bootstrap wiring |
| 8 | TTS table and duck layer | Fake-proven total system-TTS coordinator and sole platform adapter |
| 9 | Profile/manager/TTS APIs | Shared Settings content, atomic controls, truthful tests and Sound Detail Text |
| 10 | Registered surfaces/actions and existing narrative UI | Semantic scene integration, Gallery replay, and Dialogic sole-owner compliance |
| 11 | Silent platform and closed manifests | Static/import/export/fixture validators and zero-asset coverage proof |
| 12 | All prior tasks | Failure matrix, full regression evidence and the silent-system review packet |

---

## Task 1: Reconcile Profile v2 and the explicit Settings registry

**Specification:** Manual Sections 1.1, 12.3, 14 and 15; Settings amendment Sections 5.6, 9, 10 and 22.

**Files:**

- Create: `scripts/settings/SettingsPreferenceRegistry.gd`
- Modify: `scripts/profile/ProfileSchema.gd`
- Modify: `schemas/profile.schema.json`
- Delete: `scripts/profile/ProfileMigration.gd`
- Modify: `autoload/ProfileManager.gd`
- Modify: `scripts/application/restore/ProfileRestoreParticipant.gd`
- Modify: `autoload/LocalizationManager.gd`
- Modify: `autoload/AccessibilityManager.gd`
- Modify: `scripts/narrative/DialogicPreferenceAdapter.gd`
- Modify: `autoload/DialogicBridge.gd`
- Modify: `autoload/AudioManager.gd`
- Modify: `scripts/ui/SettingsPanelController.gd`
- Modify: `tests/unit/test_profile_manager.gd`
- Modify: `tests/unit/test_audio_manager.gd`
- Modify: `tests/integration/test_profile_reset_consumers.gd`
- Modify: `tests/scene/test_settings_localization_scene.gd`
- Create: `tests/unit/test_settings_preference_registry.gd`

- [ ] Write RED tests asserting Profile v2's six root keys, the complete accepted semantic vocabulary, the three and only three manual extensions, correct defaults, capability-owned non-writable fields, and rejection of unknown leaves, arbitrary reflection, Profile v1, `migration_receipts`, Voice, old dialogue/audio/accessibility names, and non-finite values.
- [ ] Require the shared registry to be the sole authority for preference type, allowed values, default, player-writable status, visible Settings section, renderer kind and 5-percent audio step. Its public surface is:

```gdscript
class_name SettingsPreferenceRegistry
extends RefCounted

static func records() -> Array[Dictionary]
static func validate(path: StringName, value: Variant) -> Dictionary
static func default_value(path: StringName) -> Variant
static func visible_records(section_id: StringName) -> Array[Dictionary]
static func is_player_writable(path: StringName) -> bool
```

- [ ] Freeze nested `preferences` groups as `language`, `reading`, `audio`, `display`, `accessibility`, `exceptional_replay`, and `dark_mode`. Add Master, correct inactive default, Output Mode, Sound Detail Text, Read Aloud/rate, and narration lowering; remove Voice and every retired public toggle.
- [ ] Remove `ProfileMigration.gd`, audio/Voice legacy patching and the Profile v1 success path. `ProfileManager.initialize()` accepts a valid v2 document or creates v2 only when the profile is physically absent. An existing unsupported document returns `unsupported_profile_schema` without deleting or rewriting it.
- [ ] Keep Gallery and visited-history ownership. Derive the two closed neutral memory IDs from visible unlock count and surface allowlist; prove two profiles with different ending identities but equal unlock counts return byte-identical audio-memory IDs.
- [ ] Update consumers to read new paths without adding aliases. `ProfileRestoreParticipant` prepares a complete v2 profile; it never invokes a legacy patch. Adapt the current AudioManager preference reader and its tests to Master/category/inactive/output fields so this commit remains green; its live-player replacement still belongs to Tasks 4–5.
- [ ] Replace Settings schema reflection immediately with registry-record projection, including enum renderers and capability-owned read-only rows. Preserve the current two host wrappers until Task 9 moves the controls into one shared scene; no unregistered profile leaf may render during the interim.
- [ ] Expected RED is an assertion for missing v2 defaults or acceptance of a forbidden path/Voice field (`invalid_profile` / `invalid_preference_path`), never a parser or autoload error.
- [ ] Run the focused test command and require the intended vocabulary/default assertions to fail RED, then pass GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-profile-v2' -LogName 'audio-profile-v2.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_settings_preference_registry.gd,res://tests/unit/test_profile_manager.gd,res://tests/unit/test_audio_manager.gd,res://tests/integration/test_profile_reset_consumers.gd,res://tests/scene/test_settings_localization_scene.gd','-gexit')
```

- [ ] Commit only the named paths: `refactor(profile): install the accepted settings vocabulary`.

## Task 2: Build the pure catalogue, request and plan domain

**Specification:** Manual Sections 3–8, 9.5, 10, 12.1, 12.4–12.6 and 19.

**Files:**

- Inspect without extending; delete in Task 5 with their final consumer: `scripts/data/AudioManifest.gd`
- Inspect without extending; delete in Task 5: `scripts/resources/AudioCueData.gd`
- Inspect without extending; delete in Task 5: `scripts/resources/BgmTrackData.gd`
- Create: `scripts/audio/domain/AudioPresentationRegistry.gd`
- Create: `scripts/audio/domain/AudioAssetCatalogue.gd`
- Create: `scripts/audio/domain/AudioPlanTemplateCatalogue.gd`
- Create: `scripts/audio/domain/AudioPlanRequest.gd`
- Create: `scripts/audio/domain/ResolvedSceneAudioPlan.gd`
- Create: `scripts/audio/domain/AudioPlanResolver.gd`
- Create: `schemas/audio/audio-presentation-registry.schema.json`
- Create: `schemas/audio/audio-commissioning-manifest.schema.json`
- Create: `schemas/audio/audio-asset-catalogue.schema.json`
- Create: `schemas/audio/audio-plan-templates.schema.json`
- Create: `data/audio/presentation_registry.json`
- Create: `data/audio/commissioning_manifest.json`
- Create: `data/audio/asset_catalogue.json`
- Create: `data/audio/plan_templates.json`
- Create: `tests/unit/test_audio_catalogue.gd`
- Create: `tests/unit/test_audio_plan_resolver.gd`

- [ ] Write RED catalogue tests for exact schema keys, unique neutral IDs, all 35 families and every atomic member, zero production assets, exact-path-only lookup, lifecycle gating, duration tolerances, hash/ledger/distribution references, no directory scan and no semantic fallback.
- [ ] Write RED resolver tests for every closed surface; allowed scene/beat/phase/location/source/visible-character/witnessed-action/replay/memory field; forbidden route/ending/mood/affection/medical/supernatural/future fields; non-aliasing registry membership; and defensive immutability of every nested value.
- [ ] Define these public value-object surfaces:

```gdscript
AudioPlanRequest.create(input: Dictionary) -> Dictionary
AudioPlanRequest.to_canonical_dict() -> Dictionary
ResolvedSceneAudioPlan.create(input: Dictionary) -> Dictionary
ResolvedSceneAudioPlan.to_canonical_dict() -> Dictionary
AudioAssetCatalogue.load_document(document: Dictionary) -> Dictionary
AudioAssetCatalogue.resolve_exact(asset_id: String, derivative_revision: String) -> Dictionary
AudioPlanTemplateCatalogue.load_document(document: Dictionary) -> Dictionary
AudioPlanResolver.resolve(request: RefCounted, composite_revision: String) -> Dictionary
```

- [ ] `presentation_registry.json` contains the exact 16 `PresentationSurfaceId` values and the three-surface profile-memory allowlist. Scene, beat, phase, location, source, character and witnessed-action IDs are explicit closed records, never runtime strings or hashes of hidden state.
- [ ] `commissioning_manifest.json` reproduces the accepted family/member expansion and required/optional/authored-silence rules. It is production need, not proof that an asset exists.
- [ ] `asset_catalogue.json` starts with `assets: []`. Its schema nevertheless requires any future record to contain neutral ID/path, derivative revision/hash, stream/import metadata, duration tolerance, loop law, commissioning gain, evidence/attribution/distribution IDs and a runtime-eligible lifecycle state.
- [ ] `plan_templates.json` registers every global surface, accepted event law and ending presentation family without naming endings in runtime plan or asset IDs. With no exact runtime asset, the resolver emits neutral technical silence plus the intact non-audio equivalent; this consumes no anomaly debit and creates no absolute-silence fiction.
- [ ] Prove hidden-state noninterference by generating opposing canonical fixtures whose permitted audience presentation is identical and requiring byte-identical request JSON and plan JSON. Prove duplicate/missing/over-budget anomaly, omission, stripped-silence and absolute-silence debit IDs are rejected.
- [ ] Reject any authored absolute-silence plan whose first returning cue lacks a registered gentle entry envelope. A technical missing-asset fallback cannot allocate, time, caption or shape an absolute-silence event.
- [ ] Prove deterministic stable selections, omission/signature/music decisions and harmless texture across repeated resolution and Save/Load construction. Missing assets never choose another role, and settings/replay previews create no witnessed action.
- [ ] Expected RED is `forbidden_audio_request_field`, `invalid_audio_plan`, or `unknown_audio_asset` from the new assertion under test, never a missing script/class error.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-pure-domain' -LogName 'audio-pure-domain.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_catalogue.gd,res://tests/unit/test_audio_plan_resolver.gd','-gexit')
```

- [ ] Commit: `feat(audio): add the truth-safe silent plan domain`.

## Task 3: Add the exact audio snapshot and run-commit protocol

**Specification:** Manual Sections 12.7, 13.2 and 21 lifecycle/determinism laws.

**Files:**

- Create: `scripts/audio/persistence/AudioSnapshotSchema.gd`
- Create: `scripts/application/run/RunCommitCoordinator.gd`
- Create: `tests/unit/test_audio_snapshot_schema.gd`
- Create: `tests/unit/test_run_commit_coordinator.gd`
- Create: `tests/integration/test_save_run_commit_interleavings.gd`
- Create: `tests/support/DeterministicInterleavingGate.gd`

- [ ] Write RED schema tests for exactly eleven fields, no paths/private fields/one-shots/playback objects, strict sorted unique ID arrays, non-negative seed, registered resume anchor, nonempty composite revision, and exact `{asset_id, derivative_revision}` selection values.
- [ ] Implement:

```gdscript
class_name AudioSnapshotSchema
extends RefCounted

static func make_initial() -> Dictionary
static func from_plan(plan: RefCounted) -> Dictionary
static func validate(snapshot: Dictionary) -> Dictionary
```

The initial snapshot is a registered first-launch authored-silence plan, not `{}`.

- [ ] Write RED coordinator tests for writer exclusivity, concurrent read leases, monotonic opaque tokens, idempotent same-holder acquisition, foreign/double release diagnostics, prepare/commit/rollback order, revision publication only after both narrative and audio commits, and no restoration/reuse of identities.
- [ ] Implement:

```gdscript
class_name RunCommitCoordinator
extends RefCounted

func acquire_write(owner_id: StringName) -> Dictionary
func prepare_joint_commit(write_token: String, narrative_candidate: Dictionary, audio_candidate: Dictionary) -> Dictionary
func publish_joint_commit(write_token: String) -> Dictionary
func rollback_joint_commit(write_token: String) -> Dictionary
func acquire_read(holder_id: StringName) -> Dictionary
func capture_revision(read_token: String) -> Dictionary
func release_read(read_token: String) -> Dictionary
func publish_loaded_revision(write_token: String, saved_revision: int) -> Dictionary
```

- [ ] Force every prepare, narrative commit, audio commit, publication, first revision capture, payload capture and second revision capture interleaving. A stable capture succeeds; a torn capture returns `run_revision_changed` and never produces durable JSON. Load publishes `max(current, saved) + 1`.
- [ ] Keep `ApplicationMutationGate` for restore/New Run fatal application ownership. Do not broaden it into the run coherence protocol or audio's local failure latch.
- [ ] Expected RED is an exact snapshot-shape or lease/revision assertion (`invalid_audio_snapshot`, `run_write_conflict`, or `run_revision_changed`), not a dependency failure.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-run-commit-domain' -LogName 'audio-run-commit-domain.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_snapshot_schema.gd,res://tests/unit/test_run_commit_coordinator.gd,res://tests/integration/test_save_run_commit_interleavings.gd','-gexit')
```

- [ ] Commit: `feat(save): define coherent narrative audio revisions`.

## Task 4: Check in the mix graph and compositional mutation layers

**Specification:** Manual Sections 12.1–12.3, 15.3, 16 and 19.

**Files:**

- Create: `default_bus_layout.tres`
- Modify: `project.godot`
- Create: `scripts/audio/runtime/AudioMutationCoordinator.gd`
- Create: `tests/unit/test_audio_bus_layout.gd`
- Create: `tests/unit/test_audio_mutation_coordinator.gd`

- [ ] Write RED tests loading the checked-in layout and requiring exactly `Master -> Game Mix -> Music/Ambience/SFX/UI`, one disabled-by-default `AudioEffectStereoEnhance` on Game Mix with `pan_pullout = 0.0`, `surround = 0.0`, `time_pullout_ms = 0.0`, and a final protective limiter on Master. Reject Voice and runtime bus construction.
- [ ] Write RED layer-interleaving tests for independently owned `plan`, `profile_output`, `tts_duck`, and `recovery_mute` state. Each transaction captures and restores only its owner layer; every effective state is derived, not destructively overwritten.
- [ ] Implement `AudioMutationCoordinator.prepare_layer(owner_id, candidate)`, `commit_layer(token)`, `rollback_layer(token)`, `capture_state()`, and `derive_effective_state()`. Tokens are monotonic and never restored.
- [ ] Apply profile gain once on buses: Master then category. UI follows SFX. Commissioning gain remains a player/derivative property and never repeats audience gain. Zero or mute is exact silence.
- [ ] Model Output Mode as an atomic `profile_output` transaction. Stereo derives a bypassed Game Mix mono effect; Mono derives an enabled effect. Task 5 binds this pure result to the real port. Rollback restores the prior layer values exactly, with no positive compensation.
- [ ] The recovery layer can only mute Game Mix and quarantine mutations; it cannot rewrite profile preferences, release another layer's duck, or change story state. The limiter is not used as routine gain staging.
- [ ] Expected RED is `invalid_audio_bus_layout`, `audio_layer_conflict`, or an incorrect derived-gain assertion from the new tests.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-mix-layers' -LogName 'audio-mix-layers.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_bus_layout.gd,res://tests/unit/test_audio_mutation_coordinator.gd','-gexit')
```

- [ ] Commit: `feat(audio): check in the layered game mix`.

## Task 5: Replace AudioManager with fixed pools and epoch-safe plans

**Specification:** Manual Sections 12.5–12.7, 13, 19 and 21.

**Files:**

- Rewrite: `autoload/AudioManager.gd`
- Delete: `scripts/data/AudioManifest.gd`
- Delete: `scripts/resources/AudioCueData.gd`
- Delete: `scripts/resources/BgmTrackData.gd`
- Create: `scripts/audio/runtime/AudioPoolPolicy.gd`
- Create: `scripts/audio/runtime/AudioTransitionState.gd`
- Create: `scripts/audio/runtime/AudioRuntimeSnapshot.gd`
- Modify: `scripts/audio/AudioPlaybackPort.gd`
- Modify: `tests/support/FakeAudioPlaybackPort.gd`
- Rewrite: `tests/unit/test_audio_manager.gd`
- Modify: `tests/integration/test_profile_reset_consumers.gd`
- Create: `tests/unit/test_audio_pool_policy.gd`
- Create: `tests/unit/test_audio_transition_state.gd`

- [ ] Write RED initialization tests for exactly 13 descendant players: `MusicA/B`, `AmbienceA/B`, `Protected`, `Material0..3`, `UI0..2`, and `Preview`; correct buses; explicit process/pause modes; zero Voice players; and retry-safe injection of catalogue, resolver, mutation coordinator, run coordinator and profile.
- [ ] Delete the legacy manifest/resources in the same commit that removes their last runtime consumer. Refactor `AudioPlaybackPort` to bind beneath its injected AudioManager owner, remove `ensure_bus()` and the SceneTree-root `AudioPlaybackRuntime`, and expose only typed fixed-player, capture, seek, pause and epoch-aware transition primitives.
- [ ] Expose only the new semantic transaction surface:

```gdscript
func prepare_plan(request: RefCounted) -> Dictionary
func capture_playback_state() -> Dictionary
func commit_prepared_plan(prepared: Dictionary) -> Dictionary
func rollback_prepared_plan(backup: Dictionary) -> Dictionary
func request_registered_command(command: Dictionary) -> Dictionary
func get_audio_snapshot() -> Dictionary
func prepare_snapshot_restore(snapshot: Dictionary, prepared_preferences: Dictionary) -> Dictionary
func capture_restore_state() -> Dictionary
func apply_restore_silent(plan: Dictionary) -> Dictionary
func rollback_restore_silent(backup: Dictionary) -> Dictionary
func validate_restore_ready() -> Dictionary
func finalize_restore() -> Dictionary
func reset_silent_recovery() -> Dictionary
```

Remove `set_music_context`, `set_ambience_context`, `play_sfx`, semantic context getters and all legacy snapshot validation; do not leave aliases.

- [ ] Implement stable command-ID deduplication and one Minesweeper cue per accepted reveal command. Preview never enters snapshots, evidence or witnessing state.
- [ ] Implement fixed priority `Evidence > Anomaly > Material > UI > decorative Texture`, then monotonically increasing sequence as tie-breaker. A started Evidence cue is never stolen. Evidence may replace Anomaly only with its authored interruption fade; otherwise a protected collision rejects immediately with the non-audio equivalent intact.
- [ ] Implement independent Music/Ambience fades, remaining-time capture, fresh transition epoch on every apply and rollback, and stale-callback no-ops. Never restore transition, suspension, TTS or platform identities.
- [ ] `AudioRuntimeSnapshot` captures stream identity, registered tolerance, engine playhead observation, playing/paused state, logical pause reasons, transition direction/legs/remaining time, commissioning gains and pool commands. It does not capture another mutation layer.
- [ ] Rollback restores semantic identity and playhead within the registered WAV/Ogg/MP3 tolerance. Failure to prove the boundary enters the local silent recovery latch, cancels transitions, stops players, asks TTS to quarantine through its port, and rejects conflicting audio mutation without latching the application fatal.
- [ ] Expected RED is the pool/epoch/reconstruction assertion being introduced (`protected_collision`, `stale_audio_epoch`, or `audio_runtime_indeterminate`), not absent fixture media.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-manager-runtime' -LogName 'audio-manager-runtime.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_manager.gd,res://tests/unit/test_audio_pool_policy.gd,res://tests/unit/test_audio_transition_state.gd,res://tests/integration/test_profile_reset_consumers.gd','-gexit')
```

- [ ] Commit: `refactor(audio): install fixed plan playback`.

## Task 6: Implement suspension leases, Universal Pause, focus and preview law

**Specification:** Manual Sections 12.7, 13.1 and 21; Settings amendment Section 11.

**Files:**

- Create: `scripts/audio/runtime/AudioSuspensionRegistry.gd`
- Create: `scripts/application/lifecycle/ApplicationLifecycleCoordinator.gd`
- Create: `scripts/application/lifecycle/LifecycleSuspendablePort.gd`
- Create: `scripts/ui/PauseOverlay.gd`
- Create: `scenes/overlay/PauseOverlay.tscn`
- Modify: `project.godot`
- Modify: `scenes/main/MainGameScene.tscn`
- Modify: `autoload/AudioManager.gd`
- Modify: `autoload/InputManager.gd`
- Modify: `autoload/DialogicBridge.gd`
- Modify: `scripts/audio/AudioPlaybackPort.gd`
- Create: `tests/unit/test_audio_pause_focus.gd`
- Create: `tests/integration/test_application_lifecycle_audio.gd`
- Create: `tests/scene/test_pause_overlay.gd`

- [ ] Write RED registry tests proving opaque `{holder, reason, generation, handle_id}` identities, distinct independent holders, idempotent same-holder reacquisition in one live generation, single-consumption release, and diagnostic no-ops for stale/foreign/double release.
- [ ] `ApplicationLifecycleCoordinator` exposes `register_suspendable(owner_id, port)`, `request_pause(holder_id)`, `request_resume(handle)`, `notify_focus_out()`, `notify_focus_in()`, and `get_state()`. Each registered port must reach a stable commit-or-rollback frontier before the coordinator publishes Suspended.
- [ ] Universal Pause accepts the visible Pause feedback, acquires a lease, freezes Music, Ambience, protected and Material/source SFX at literal playheads, freezes both transition legs/gains/remaining time, stops non-Pause UI, Preview and TTS, and admits only commands carrying the registered `pause_menu_ui` class.
- [ ] Resume stops Pause-menu one-shots first, then resumes every still-live source player in place. Stopped UI, Preview and TTS do not resume or replay. `SceneTree.paused` never advances AudioManager transitions because player and timer pause policies are explicit.
- [ ] Focus loss reaches the lifecycle coordinator's stable frontier. With `mute_when_inactive = true`, Music/Ambience and transitions suspend exactly; with it false they may advance. Both modes stop TTS, Preview and one-shots and suspend foreground input/narrative work. Rapid focus changes cannot stale-resume.
- [ ] InputManager clears held input and rejects new foreground commands; DialogicBridge parks Auto, advancement and presentation timers through injected suspendable ports. A focus change never accepts or cancels a modal and never fabricates a narrative completion.
- [ ] A Settings preview acquires a channel-scoped lease, captures the exact prior channel/transition state, plays only through `Preview`, and consumes that handle once when stopped or complete. Focus/Pause stops it without restoration; ordinary deliberate Stop restores the prior channel state within tolerance.
- [ ] The lifecycle coordinator owns focus/Pause admission; AudioManager no longer interprets raw focus notifications into bus mute. It injects/consumes audio and TTS ports and never changes stored preferences.
- [ ] The Pause overlay is keyboard/controller accessible, processes while paused, exposes Resume and Settings only, and emits registered Pause UI commands rather than owning players.
- [ ] Expected RED is `invalid_suspension_handle`, `audio_suspended`, or a playhead/transition mismatch in the focused test; no real stream or device is required.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-pause-focus' -LogName 'audio-pause-focus.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_pause_focus.gd,res://tests/integration/test_application_lifecycle_audio.gd,res://tests/scene/test_pause_overlay.gd','-gexit')
```

- [ ] Commit: `feat(audio): preserve sound across pause and focus`.

## Task 7: Make New Run, Save, Load and bootstrap coherent

**Specification:** Manual Sections 13.1–13.2, 19–21.

**Files:**

- Modify: `scripts/domain/run/RunSnapshotSchema.gd`
- Modify: `scripts/infrastructure/save/SaveDocumentSchema.gd`
- Modify: `scripts/infrastructure/save/SaveMigrations.gd`
- Modify: `scripts/infrastructure/save/CheckpointJournal.gd`
- Modify: `autoload/SaveManager.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd`
- Modify: `scripts/application/run/SaveManagerCheckpointPort.gd`
- Modify: `scripts/application/run/GameStateDayResolutionPort.gd`
- Modify: `scripts/application/restore/RunRestoreParticipant.gd`
- Modify: `scripts/application/restore/AudioRestoreParticipant.gd`
- Modify: `scripts/application/restore/ProfileRestoreParticipant.gd`
- Modify: `scripts/application/restore/LocalizationRestoreParticipant.gd`
- Modify: `scripts/application/restore/RouteRestoreParticipant.gd`
- Modify: `scripts/application/restore/NarrativeRestoreParticipant.gd`
- Modify: `autoload/GameState.gd`
- Modify: `scripts/ui/MenuScene.gd`
- Modify: `tests/fixtures/snapshots/valid_day3.json`
- Modify: `tests/fixtures/snapshots/invalid_day8.json`
- Modify: `tests/fixtures/snapshots/invalid_object_shapes.json`
- Modify: `tests/fixtures/saves/v2_future_schema.json`
- Modify: `tests/fixtures/saves/v1_unreceipted_applied_ids.json`
- Modify: `tests/fixtures/saves/v1_minimal_slot.json`
- Modify: `tests/fixtures/saves/unknown_ending_id.json`
- Modify: `tests/fixtures/saves/reversed_pair_tokens.json`
- Modify: `tests/fixtures/saves/day8_playing_with_day7_journal.json`
- Modify: `tests/fixtures/saves/day8_no_fallback.json`
- Modify: `tests/fixtures/saves/day8_group_synchronized.json`
- Modify: `tests/fixtures/saves/day8_group_invalid_with_day7_journal.json`
- Modify: `tests/fixtures/saves/day8_ending_non_group.json`
- Modify: `tests/unit/test_run_snapshot_schema.gd`
- Modify: `tests/unit/test_save_document_schema.gd`
- Modify: `tests/unit/test_save_migrations.gd`
- Modify: `tests/unit/test_save_manager.gd`
- Modify: `tests/unit/test_restore_participants.gd`
- Modify: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Modify: `tests/unit/test_day_resolution_snapshot_production.gd`
- Modify: `tests/integration/test_restore_transaction.gd`
- Modify: `tests/integration/test_restore_production_adapters.gd`
- Modify: `tests/integration/test_save_manager_journal.gd`
- Modify: `tests/integration/test_new_run_transaction.gd`
- Modify: `tests/integration/test_day_resolution_disk_durability.gd`
- Create: `tests/integration/test_audio_save_restore_recovery.gd`
- Create: `tests/integration/test_save_fresh_process_reconciliation.gd`
- Create: `tests/integration/test_application_bootstrap_restore_wiring.gd`
- Modify intentionally after interface verification: `evidence/phase_2r/runtime/save_manager_required_surface.json`
- Modify intentionally after interface verification: `evidence/phase_2r/runtime/save_manager_surface.json`
- Modify intentionally after interface verification: `evidence/phase_2r/runtime/game_state_required_surface.json`
- Modify intentionally after interface verification: `evidence/phase_2r/runtime/game_state_surface.json`
- Modify: `tests/unit/tooling/test_public_surface_inventory.gd`

- [ ] Write RED schema tests for RunSnapshot v3's exact `audio_snapshot` and `run_commit_revision`, SaveDocument v3 transitively validating both, and factual rejection of v1/v2 audio shapes, `audio_context`, empty audio objects, paths, engine objects and compatibility aliases.
- [ ] Change every checkpoint provider to obtain a `RunCommitCoordinator` read lease, capture revision -> narrative/GameState/audio -> revision, release the lease, and retry only `run_revision_changed` up to `MAX_STABLE_CAPTURE_ATTEMPTS = 3`. Exhaustion returns `stable_capture_unavailable` and writes nothing.
- [ ] Every narrative transition that changes its resolved audio plan uses one write lease. Prepare both owners, apply both, publish one new revision only after both succeed, and self-restore an already-applied side before releasing a failed transaction. Add deterministic yield hooks only through the test seam.
- [ ] Bump the journal/document producers to v3. `SaveMigrations` returns `unsupported_development_save` for v1/v2 rather than manufacturing an audio plan or Voice alias.
- [ ] `SaveManager.initialize()` reconciles the nine closed locator families—slots 1–7, quicksave and autosave—using the document validator before ready. Metadata, exact read and delete reconcile that locator again immediately before access. An indeterminate family fails factually.
- [ ] New Run prepares real run, Profile v2, localization and initial audio plans; uses `AudioSnapshotSchema.make_initial()`; publishes a fresh run revision; and commits the first durable checkpoint. No real participant receives `{}`.
- [ ] Preserve the six outer restore participants and order. Change the protocol to prepare all -> capture all -> apply-silent all -> validate-ready all -> publish loaded revision/journal -> infallible public signal publication. A participant that fails during apply must first restore its own partial internal state; AudioManager latches silent if it cannot.
- [ ] Register restore participants in Bootstrap's already-declared `configure_restore_participants` stage. Bootstrap constructs and retains one `RunCommitCoordinator`, injects it into checkpoint/narrative/audio owners, constructs all six adapters, calls `SaveManager.configure_restore_participants()`, and fails before `application_ready` if identities or methods differ.
- [ ] Load reconstructs at `resume_anchor_id`, preserves selections/anomaly/omission/signature/music decisions, discards decorative tails, and publishes `max(current, saved) + 1`. It never restarts at zero or restores transition/TTS/suspension identities.
- [ ] Force music, ambience, anchor, Output Mode, profile, route and narrative failures at every ordinal. Require prior determinate logical layers within registered tolerance or the local silent latch; require no partial public signal and no stale callback revival.
- [ ] Expected RED is `invalid_snapshot_shape`, `unsupported_development_save`, `storage_reconciliation_required`, `restore_participant_failed`, or `run_revision_changed` at the injected boundary.
- [ ] Run the three focused clusters RED then GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-snapshot-persistence' -LogName 'audio-snapshot-persistence.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_snapshot_schema.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_run_commit_coordinator.gd,res://tests/integration/test_save_run_commit_interleavings.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-restore-bootstrap' -LogName 'audio-restore-bootstrap.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_restore_participants.gd,res://tests/integration/test_restore_transaction.gd,res://tests/integration/test_restore_production_adapters.gd,res://tests/integration/test_new_run_transaction.gd,res://tests/integration/test_audio_save_restore_recovery.gd,res://tests/integration/test_save_fresh_process_reconciliation.gd,res://tests/integration/test_application_bootstrap_restore_wiring.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-checkpoint-regression' -LogName 'audio-checkpoint-regression.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_save_manager.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_day_resolution_snapshot_production.gd,res://tests/integration/test_save_manager_journal.gd,res://tests/integration/test_day_resolution_disk_durability.gd','-gexit')
```

- [ ] Regenerate the four public-surface inventories only from the verified new interfaces; review the diff and run `tests/unit/tooling/test_public_surface_inventory.gd` before staging.
- [ ] Commit: `feat(save): restore audio at one coherent run revision`.

## Task 8: Implement the total system-TTS state machine

**Specification:** Manual Sections 12.3, 12.7, 13.1, 14, 16–17 and 19.

**Files:**

- Create: `scripts/tts/TtsPlatformPort.gd`
- Create: `scripts/tts/SystemTtsPlatformAdapter.gd`
- Create: `autoload/SystemTtsCoordinator.gd`
- Create: `tests/support/FakeTtsPlatformPort.gd`
- Create: `tests/unit/test_tts_duck.gd`
- Create: `tests/integration/test_tts_pause_focus.gd`
- Modify: `project.godot`
- Modify: `scripts/audio/runtime/AudioMutationCoordinator.gd`
- Modify: `scripts/application/lifecycle/ApplicationLifecycleCoordinator.gd`
- Modify: `autoload/AudioManager.gd`

- [ ] Write the fake and RED table tests first. The fake schedules voice-list, started, finished, cancelled, error, late, duplicate and missing callbacks plus independent `is_speaking` changes without calling the OS.
- [ ] Freeze the coordinator's public surface:

```gdscript
func initialize(platform: RefCounted, audio_mutations: RefCounted, profile: Object) -> Dictionary
func refresh_capability(primary_locale_id: String) -> Dictionary
func request_speech(text: String, locale_id: String, rate_id: StringName, source_id: String) -> Dictionary
func stop(reason: StringName) -> Dictionary
func reset_quarantine() -> Dictionary
func handle_platform_event(event: Dictionary) -> Dictionary
func poll(now_ms: int) -> Dictionary
func get_state() -> Dictionary
```
- [ ] `TtsPlatformPort` exposes only `list_voices()`, `speak(text, voice_id, rate, volume, interrupt, utterance_id)`, `stop_and_clear()`, `is_speaking()`, and normalized callback events. `SystemTtsPlatformAdapter.gd` is the sole project-owned file containing `DisplayServer.tts_*`.
- [ ] Implement states `IDLE`, `DUCKING`, `STARTING`, `SPEAKING`, `STOPPING`, `RECOVERING`, and `QUARANTINED` exactly. At most one identity occupies active or stopping, never both; one pending successor has no token until predecessor clearance.
- [ ] Use monotonic game token and platform utterance IDs. Every callback/watchdog acts only for matching identity, slot and legal state. Late, duplicate, mismatched and illegal events are diagnostic no-ops.
- [ ] Apply the frozen constants and exact utterance-deadline formula. Lower Background During Narration acquires the token-owned duck only when enabled. TTS never goes through Master/Game Mix and never claims control of OS volume.
- [ ] Start during active speech means Replace and retains only the newest successor. Stop clears the successor and is idempotent in STOPPING. Successful finish may emit one restrained semantic confirmation after recovery; cancel/error/degraded completion suppresses it.
- [ ] STOPPING transfers an already-lowered duck atomically to a fresh successor only after matching cancellation or the stable not-speaking drain. The stop watchdog releases only the orphaned token's duck, clears pending speech and enters QUARANTINED.
- [ ] Pause, focus loss, teardown and silent recovery stop speech and prevent a successor. Recovery quarantine blocks speech until explicit adapter reset and a new compatible-voice capability check.
- [ ] Empty compatible voice lists are valid. The effective capability is unavailable while the stored desired Read Aloud preference remains unchanged; no old/current line auto-replays when a voice later appears.
- [ ] Expected RED is a state/identity assertion such as `tts_event_illegal`, `tts_start_watchdog`, or `tts_quarantined`; the fake never calls `DisplayServer`.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-tts-state' -LogName 'audio-tts-state.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_tts_duck.gd,res://tests/integration/test_tts_pause_focus.gd','-gexit')
```

- [ ] Static-scan the project for `DisplayServer.tts_`; require exactly the declared calls in `SystemTtsPlatformAdapter.gd` and none in scenes, addons or tests other than a quoted scanner fixture.
- [ ] Commit: `feat(tts): serialize system narration and duck ownership`.

## Task 9: Replace reflected Settings UI and add non-canonical detail text

**Specification:** Manual Sections 1.1, 12.3, 13.1, 14–15, 16.3 and 19; Settings amendment Sections 6–10.

**Files:**

- Create: `scripts/ui/SettingsContent.gd`
- Create: `scenes/shared/SettingsContent.tscn`
- Rewrite: `scripts/ui/SettingsPanelController.gd`
- Modify: `scripts/ui/Setting.gd`
- Modify: `scripts/ui/SettingsApp.gd`
- Modify: `scenes/menu/Setting.tscn`
- Modify: `scenes/apps/SettingsApp.tscn`
- Create: `scripts/audio/accessibility/SoundDetailTextRegistry.gd`
- Create: `scripts/audio/accessibility/SoundDetailTextPresenter.gd`
- Create: `scripts/audio/accessibility/ListeningComfortNoticeCoordinator.gd`
- Create: `schemas/audio/sound-detail-text.schema.json`
- Create: `data/audio/sound_detail_text.json`
- Create: `scripts/ui/SoundDetailTextLayer.gd`
- Create: `scenes/shared/SoundDetailTextLayer.tscn`
- Create: `scripts/ui/ListeningComfortNotice.gd`
- Create: `scenes/overlay/ListeningComfortNotice.tscn`
- Modify: `scenes/main/MainGameScene.tscn`
- Modify: `localization/ui/en.json`
- Modify: `localization/ui/zh_CN.json`
- Modify: `localization/ui/zh_HK.json`
- Modify: `tests/scene/test_settings_localization_scene.gd`
- Create: `tests/unit/test_sound_detail_text.gd`
- Create: `tests/unit/test_audio_comfort_notices.gd`
- Create: `tests/scene/test_sound_detail_text_layer.gd`

- [ ] Write RED scene tests proving title and in-run hosts instance the same `SettingsContent`, with explicit category/control records rather than iterating schema leaves. Every visible control maps to one registered field; capability-owned fields are read-only; Voice never appears.
- [ ] Implement explicit controls for Master/Music/Ambience/SFX volume and mute, Mute When Inactive, Stereo/Mono, Sound Detail Text, Read Aloud, 0.8/1.0/1.2 rate, Lower Background During Narration and the accepted non-audio Settings fields. No arbitrary Boolean/number added to Profile can appear.
- [ ] Pointer slider movement previews in memory and performs one durable commit on release. Keyboard/controller/assistive 5-percent steps commit immediately. A failed publication restores the last committed visible value.
- [ ] Music/Ambience/SFX Tests never autoplay. With the production catalogue empty they show factual Unavailable and leave the prior context untouched. Muted/zero rows show Muted or Volume is 0. Future registered tests use only the dedicated Preview player/lease and never enter Save, History, evidence or witnessing state.
- [ ] TTS Test/Stop uses the frozen localized specimen and no presentation receipt. It remains visible when Read Aloud is Off, but truthful compatible-voice absence disables it without changing desired preference.
- [ ] Production `sound_detail_text.json` is an empty records array. The registry schema requires each future record to contain exact audible-event proposition IDs, already committed visible-fact IDs and rendered proposition IDs; rendered must be a subset, while cause/agency/absence/diagnosis/supernatural classes are structurally forbidden.
- [ ] The presenter accepts only a resolved registered command and renders at the same semantic moment even when its category is muted. It writes nothing to History, Save, evidence, presentation receipts or route state and ignores decorative atmosphere.
- [ ] Fixture tests use the accepted kettle example and opposing hidden states to prove byte-identical allowed text, subset parity and rejection of stronger explanations. Muted and unmuted runs produce identical durable state.
- [ ] Add a non-medical first-run note—English `Set a comfortable device volume. Stop and rest if sound feels uncomfortable.`, Simplified Chinese `请将设备音量调至舒适水平。如果声音令你不适，请停止并休息。`, Traditional Chinese `請將裝置音量調至舒適水平。如果聲音令你不適，請停止並休息。`—to the accessibility setup. Track foreground session time in memory only; after each 60-minute interval, make English `You have been playing for a while. This is a quiet moment to rest your ears.`, Simplified Chinese `你已经游玩一段时间了。现在正好安静地让耳朵休息一下。`, and Traditional Chinese `你已經遊玩一段時間了。現在正好安靜地讓耳朵休息一下。` eligible only at the next Pause or day boundary. Inactive/Pause time does not advance the interval, and the notice never interrupts a scene.
- [ ] Expected RED is `unregistered_settings_control`, `invalid_sound_detail_record`, or a visible-state/parity assertion—not unavailable production audio.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-settings-detail' -LogName 'audio-settings-detail.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/scene/test_settings_localization_scene.gd,res://tests/unit/test_sound_detail_text.gd,res://tests/unit/test_audio_comfort_notices.gd,res://tests/scene/test_sound_detail_text_layer.gd','-gexit')
```

- [ ] Commit: `feat(settings): expose truthful audio access controls`.

## Task 10: Convert scene, Gallery and Dialogic surfaces to semantic requests

**Specification:** Manual Sections 4–8, 12.1, 12.4, 12.7, 13.1, 15 and 21.

**Files:**

- Create: `scripts/audio/application/AudioPresentationCoordinator.gd`
- Create: `scripts/audio/application/AudioPresentationPort.gd`
- Create: `scripts/application/gallery/GalleryReplayCoordinator.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `autoload/SceneRouter.gd`
- Modify: `autoload/DialogicBridge.gd`
- Modify: `scripts/ui/EndingScene.gd`
- Modify: `scripts/ui/GalleryScene.gd`
- Modify: `scenes/menu/GalleryScene.tscn`
- Modify: `scripts/ui/MenuScene.gd`
- Modify: `scripts/ui/ComputerDesktop.gd`
- Modify: `scripts/ui/MinesweeperApp.gd`
- Modify: `scripts/ui/HospitalScene.gd`
- Modify: `scripts/ui/DatingScene.gd`
- Modify: `scripts/ui/OpeningScene.gd`
- Modify: `addons/dialogic/Core/DialogicGameHandler.gd`
- Modify: `addons/dialogic/Modules/Audio/index.gd`
- Modify: `addons/dialogic/Modules/Audio/subsystem_audio.gd`
- Modify: `addons/dialogic/Modules/Voice/index.gd`
- Modify: `addons/dialogic/Modules/Voice/subsystem_voice.gd`
- Modify: `addons/dialogic/Modules/Text/node_type_sound.gd`
- Modify: `addons/dialogic/Modules/Choice/node_button_sound.gd`
- Modify: `addons/dialogic/Modules/DefaultLayoutParts/Layer_Textbubble/text_bubble.tscn`
- Modify: `addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Textbox/vn_textbox_layer.tscn`
- Modify: `addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Choices/vn_choice_layer.tscn`
- Modify: `addons/dialogic/Modules/DefaultLayoutParts/Layer_SpeakerPortraitTextbox/textbox_with_speaker_portrait.tscn`
- Create: `export_presets.cfg` with a credential-free Windows Desktop preset and explicit exclusion filters
- Create: `tools/audio/validate_audio_runtime_ownership.gd`
- Create: `tests/unit/tooling/test_audio_runtime_ownership.gd`
- Create: `tests/integration/test_audio_semantic_wiring.gd`
- Create: `tests/integration/test_gallery_replay_audio.gd`
- Modify: `tests/integration/test_ending_dialogic_wiring.gd`
- Modify: `tests/integration/test_dialogic_bridge_contract.gd`
- Modify: `tests/integration/test_dialogic_restore.gd`
- Modify: `tests/smoke_dialogic_timelines.gd`

- [ ] Write the ownership/forbidden-input scan RED first. It scans project-owned runtime code, exported scenes and enabled/exported addon modules; rejects live players outside AudioManager's fixed port, raw paths, legacy audio calls, Audio/Voice/type-sound directives, filesystem discovery, and forbidden story fields; and allows only proven editor-only previews excluded from export.
- [ ] Freeze `AudioPresentationCoordinator.prepare_transition(presentation_snapshot, narrative_candidate)`, `commit_transition(prepared)`, `rollback_transition(prepared)`, and `submit_visible_command(command_snapshot)`. Freeze `GalleryReplayCoordinator.prepare_replay(unlock_id)`, `start_replay(prepared)`, and `finish_replay(replay_token)`; the unlock ID remains inside the Gallery/narrative owner and is absent from the returned audio request.
- [ ] `AudioPresentationCoordinator` constructs requests only from versioned surface registry plus a canonical audience-visible presentation snapshot. It obtains a run write lease, prepares narrative and audio candidates, commits both, and publishes one run revision. Technical audio failure may commit narrative only when the plan's registered neutral fallback is determinate and the same joint revision records that fallback.
- [ ] SceneRouter maps physical routes to the 16 closed surfaces. Scenes may add only registered visible source/action/character facts. UI and Minesweeper send stable accepted-command IDs; one multi-cell reveal produces one audio command. Hover, rejected focus and preview never become witnessed actions.
- [ ] Remove EndingScene's raw `ending_id` audio call. Ending playback may still use its canonical narrative owner, but audio receives only the public surface/phase/visible tableau. Tests require opposing ending IDs with identical visible presentation to resolve byte-identically and never appear in catalogue selection or diagnostics.
- [ ] Gallery buttons become keyboard/controller-activatable. `GalleryReplayCoordinator` verifies the visible Profile unlock, starts the existing registered narrative replay path, and gives audio only `META_GALLERY_REPLAY`, stable replay mode and ProfileManager's neutral memory IDs. Reopening/replaying creates no new Gallery unlock, witness, evidence or run state.
- [ ] Remove Dialogic Audio and Voice subsystem registration and static construction. Make their retained APIs inert and player-free so an accidental call fails factually. Make type sounds inert permanently, change runtime layout nodes from `AudioStreamPlayer` to player-free nodes, and convert choice-button sound behavior to a semantic registered UI request with no player. Reject any `.dtl` `audio`/`voice` directive at validation.
- [ ] The export preset excludes Dialogic Editor, Audio/Voice event modules, Example Assets and examples, plus every source-vault/audition/edit path. No signing, store, network or credential field is added.
- [ ] Instantiate the actual runtime Dialogic layouts in tests and prove no live player exists. Keep editor preview code only on a documented export-excluded allowlist; Dialogic example typing WAVs and module examples are never packaged.
- [ ] Expected RED names the exact forbidden path/field/player/directive or reports `invalid_audio_presentation`; it must not be a generic source scan failure.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-semantic-integration' -LogName 'audio-semantic-integration.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_audio_runtime_ownership.gd,res://tests/integration/test_audio_semantic_wiring.gd,res://tests/integration/test_gallery_replay_audio.gd,res://tests/integration/test_ending_dialogic_wiring.gd,res://tests/integration/test_dialogic_bridge_contract.gd,res://tests/integration/test_dialogic_restore.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-ownership-validator' -LogName 'audio-ownership-validator.log' -GodotArgs @('-s','res://tools/audio/validate_audio_runtime_ownership.gd')
```

- [ ] Commit: `refactor(audio): route every surface through semantic plans`.

## Task 11: Add zero-asset import, export and coverage verification

**Specification:** Manual Sections 9–11, 16–17, 21 and 23.

**Files:**

- Create: `scripts/audio/verification/AudioVerificationFixture.gd`
- Create: `scripts/audio/verification/AudioCoverageVerifier.gd`
- Create: `scripts/audio/verification/AudioCodecProbeRecord.gd`
- Create: `schemas/audio/audio-verification-fixtures.schema.json`
- Create: `data/audio/verification_fixtures.json`
- Create: `tools/audio/validate_audio_project.gd`
- Create: `tools/audio/Invoke-AudioExportBoundary.ps1`
- Create: `tests/tooling/Test-AudioExportBoundary.ps1`
- Create: `tests/unit/test_audio_verification_fixtures.gd`
- Create: `tests/unit/tooling/test_audio_export_boundary.gd`
- Modify: `.gitignore`

- [ ] Write RED fixture tests requiring reachability revision, surface/route ID, plan revision, seed, command schedule, concurrency, fades, gain profile, Output Mode, locale, TTS inclusion, capture point, meter algorithm/version, warm-up and numeric tolerances. Reject an uncovered reachable transition, terminal trace or repeatable cycle.
- [ ] Freeze default/stress gain × Stereo/Mono × pre-limiter/post-Master matrix cells even though the production catalogue is empty. Coverage proves scheduled music occupancy is exactly 0 percent and therefore below 20 percent at the fastest valid clock; it does not claim a future asset mix passes.
- [ ] `AudioCodecProbeRecord` validates the future hash-bound external probe fields: codec, decoded duration, channel count, sample rate, bit depth or bitrate, true peak and duration tolerance. It runs against zero production records now and has fixture coverage for WAV/Ogg/MP3 tolerance laws.
- [ ] Enforce duration tolerance at most `1 ms` for PCM WAV and `50 ms` for Ogg/MP3 unless an exact approved encoder record supplies a tighter value. No looser exception exists in the silent platform.
- [ ] Freeze import-policy validation: short cues are 16-bit PCM WAV with QOA/normalize/trim/forced-mono/forced-rate disabled and authored loop mode/bounds; Ogg/MP3 declare loop and offset explicitly with BPM/beat count zero; no runtime FLAC/M4A/source master is accepted. Generated `.import` files are inspected, never hand-edited.
- [ ] `validate_audio_project.gd` validates all JSON schemas/catalogues, exact ResourceLoader paths, lifecycle eligibility, import-policy records, bus graph/effects, no source/edit/audition material under `res://`, and no runtime asset lacking evidence/attribution/distribution IDs. Zero registered assets is a valid silent result.
- [ ] The export boundary builds or inspects a credential-free test pack and proves every registered runtime asset is present (vacuously zero) while source vaults, audition cache/previews, edit masters, addon examples, Dialogic Editor and example typing sounds are absent. It never reads or copies the ignored audition cache.
- [ ] Extend `.gitignore` only for generated export/verification scratch beneath a narrow `.godot/audio_verification/` root. Never ignore the diffable catalogues, schemas, recipes or ledgers.
- [ ] Expected RED is one exact missing coverage edge, invalid probe/import record, forbidden exported path, or absent registered asset; zero catalogue entries are not themselves a failure.
- [ ] Run RED and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-verification-domain' -LogName 'audio-verification-domain.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_audio_verification_fixtures.gd,res://tests/unit/tooling/test_audio_export_boundary.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-project-validator' -LogName 'audio-project-validator.log' -GodotArgs @('-s','res://tools/audio/validate_audio_project.gd')
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-InvokeIsolatedGodot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/tooling/Test-AudioExportBoundary.ps1
```

- [ ] Commit: `test(audio): prove the silent export boundary`.

## Task 12: Close the silent-platform failure matrix and present the checkpoint

**Specification:** Manual Sections 15–17, 19, 21–23.

**Files:**

- Create: `tests/integration/test_audio_failure_matrix.gd`
- Create: `tests/integration/test_audio_muted_equivalence.gd`
- Create: `tests/integration/test_audio_aba_interleavings.gd`
- Create: `docs/research/audio/2026-08-14-silent-audio-platform-verification.md`

- [ ] Build the final RED failure table before fixes: every port ordinal, missing/late callback, missing asset, bad catalogue row, transition callback, profile/output transaction, Pause/focus lease, TTS replacement/stop, restore owner, storage reconciliation and run-commit yield point.
- [ ] Require every case to end in the prior determinate state, the registered neutral fallback, or the local silent recovery/quarantine state. No case invents a sting, anomaly, absolute-silence slot, save damage, hidden fact or global fatal state.
- [ ] Force ABA schedules across plan epochs, suspension handles, TTS tokens/platform IDs, run-write/read tokens and loaded revisions. Old callbacks remain stale after rollback, Load and reset; no identity is restored or reused.
- [ ] Run identical input scripts with all game audio muted/TTS Off and with preferences enabled against the empty catalogue. Choices, consequences, eligibility, presentation receipts and every durable canonical JSON byte must match.
- [ ] Run the eight manual-mandated suites by exact name: `test_audio_catalogue.gd`, `test_audio_plan_resolver.gd`, `test_audio_pool_policy.gd`, `test_audio_transition_state.gd`, `test_audio_pause_focus.gd`, `test_audio_save_restore_recovery.gd`, `test_tts_duck.gd`, and `test_audio_failure_matrix.gd`.
- [ ] Run focused final failures:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'audio-final-failures' -LogName 'audio-final-failures.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_audio_failure_matrix.gd,res://tests/integration/test_audio_muted_equivalence.gd,res://tests/integration/test_audio_aba_interleavings.gd,res://tests/integration/test_audio_save_restore_recovery.gd,res://tests/unit/test_tts_duck.gd','-gexit')
```

- [ ] Run import, full GUT, Dialogic smoke, scene smoke, audio project validator, ownership validator, PowerShell tooling tests, `git diff --check`, static forbidden-field/direct-TTS/live-player scans, secret scan and Beads preflight against one identified clean implementation commit.
- [ ] Write the verification record with exact commit, commands, exit codes, test/assertion counts, log hashes, platform limits and zero-asset statement. Say only that the platform is verified silent; do not claim asset, comfort, loudness, TTS intelligibility, human audition, licensing or ship approval.
- [ ] Confirm no production audio binary, acquired preview, edit master, generated media, `.godot/imported` content or ignored audition artifact is tracked or staged.
- [ ] Expected RED is one deliberately injected failure-matrix or ABA assertion. Remove every injection and rerun GREEN before the evidence record is written.
- [ ] Commit the bounded evidence record: `docs(audio): record the verified silent platform`.
- [ ] Stop and present the silent system for user review. Do not begin research, acquisition, playback, audition, editing or asset integration without the next exact authorization gate.

## Final acceptance checklist

- [ ] Profile v2 contains the accepted vocabulary plus only the three manual additions and no Voice surface.
- [ ] Requests and plans are immutable, deterministic and hidden-state noninterfering.
- [ ] The production catalogue has zero audio assets and no filesystem discovery or semantic fallback.
- [ ] `AudioManager` alone owns the 13 fixed game players under the checked-in bus graph.
- [ ] Profile/output, plan, TTS duck and recovery layers cannot overwrite one another.
- [ ] Pause/focus preserve eligible playheads and transitions while stopped work never resumes.
- [ ] Save/New Run/Load publish one coherent run revision and bootstrap wires all six participants.
- [ ] System TTS has a total fake-proven state machine, no stale duck and one direct-call adapter.
- [ ] Sound Detail Text is non-canonical, proposition-bounded and empty in production until a real approved command exists.
- [ ] Ending, Gallery, Dialogic, UI and gameplay use semantic requests with no truth-bearing audio input.
- [ ] Import/export/static gates exclude every source, preview, example and unauthorized live player.
- [ ] All manual-mandated tests and the full repository regression pass against one clean commit.
- [ ] The user receives a silent-system checkpoint; every asset operation remains separately gated.
