# Attribute startup script loading before further removal

Base: 30e66ab4e8d382c9a3f245ba2cc11ab5bd445b2d (PR #280).
Outcome: identify the larger pre-title costs and an exclusive removable dependency,
without moving mandatory work onto the first caption. No runtime change justified
by this pass. All diagnostic edits were restored.

## Current startup observations

Two fresh-user Linux headless Godot 4.6.3 source-project traces with existing imported
assets. These spans include dependencies; they are not pure parser CPU time.

| Span | Run 1 | Run 2 |
| --- | --- | --- |
| Bootstrap script load and construction | 1338.103 ms | 1298.332 ms |
| DialogicBridge script load | 579.989 ms | 600.099 ms |
| initialize_saves stage | 444.907 ms | 433.647 ms |
| Enabled title observation | 3602.732 ms | 3671.986 ms |

The save stage includes shipped scene-registration setup and recovery; its label
does not imply that all its time is spent reading player saves. Title observations
are instrumented ready-control measurements, not rendered first paint or Windows
release performance. The second full trace emitted an ObjectDB shutdown warning.

## Shared dependency attribution

A temporary probe disables autoload installation, then loads a resource in a fresh
engine. It retains resources so subsequent requests can prove cache reuse. It
does not instantiate owners, initialize saves or run gameplay. These isolated
times cannot be summed: the resources share dependencies.

| Isolated resource including its dependency closure | One observation |
| --- | --- |
| ApplicationBootstrap | 1677.885 ms |
| SaveManagerCheckpointPort | 1324.269 ms |
| SaveDocumentSchema | 1188.508 ms |
| RunSnapshotSchema | 1155.100 ms |
| DialogicEntryManifest | 364.693 ms |

A second set traces RunSnapshotSchema's branches. Examples: RunLifecycle 611.692 ms,
ContactInvitationState 558.297 ms, SoloReadingSession 505.105 ms, SceneEventContract
452.612 ms, and the function-local FrozenRunContext preload 964.545 ms. These too
overlap. A local preload is still an eager dependency; source location does not
make it lazy. The raw set includes all literal preloads, not only top-level ones.

Four fresh-process sequential-load probes confirm the overlap:

- Checkpoint port first: 1416.559 / 1149.663 ms. The two schemas are then cached
  and load in 3–9 microseconds. Loading Bootstrap afterward takes 147.658 / 150.167 ms.
- Bootstrap first: 1571.235 / 1544.790 ms. The checkpoint port and both schemas are
  then cached and load in 3–44 microseconds. A repeated Bootstrap load takes 2 microseconds.

This is not repeated loading that can be fixed by deleting duplicate declarations.
Independent caller review found no safe exclusive dependency to remove:

- Bootstrap's schema constants named FOR_PROBE have production schema/configuration
  users. The schemas are also reached by SaveManager and its checkpoint port.
- DialogicRuntimeAdapter is reached through actual global-class calls in the
  manifest, SoloReadingSession and ScenePassageCatalog before its runtime queue
  entry. Queue membership does not establish the first load point.
- RunSnapshotSchema validation helpers that appear locally unused have GameState
  callers. SaveMigrations remains part of existing autosave admission.
- A few small unused helpers do not own exclusive dependencies. No unrelated
  cleanup was represented as a solution to the multi-second loading span.

## Separate registration cost

Two further fresh-startup probes split the shipped story-registration operation:

| Operation | Run 1 | Run 2 |
| --- | --- | --- |
| File read | 6.291 ms | 1.530 ms |
| StrictJson.parse_object | 230.489 ms | 248.897 ms |
| Configure registration, including structure validation/freeze | 230.782 ms | 210.072 ms |

The committed JSON is 534707 bytes; decoded text is 530538 characters. The probe's
raw field named bytes records text.length(), so it is a character count. These
subspans were measured in separate runs and must not be subtracted from the earlier
save-stage observations as if they were the same execution.

This suggests a bounded next experiment in shipped-registration decoding. Preserve
integer types, canonical fingerprints, generated-data validation, fixture behavior
and unavailable-registration handling. Do not substitute a generic native JSON
parse without checking numeric types: the scene contract explicitly requires
TYPE_INT for version/count fields. This pass does not select or implement a new
serialization format. StrictJson for player saves and recovery remains unchanged.

## Evidence and limits

Evidence: tools/player_latency/evidence/2026-11-11-startup-load-attribution.
35 successful diagnostic processes: 12 initial isolated loads, 15 snapshot-branch
loads, four shared-cache sequences, two full startup traces and two registration
traces. No engine errors. No source-graph size estimate is treated as timing proof.

To reproduce, copy scripts to .godot/ci/load-attribution and rename probe.gd.txt to
probe.gd. Run isolate.py, snapshot.py, shared.py, profile.py and registration.py
sequentially from the repository root with Godot on PATH. Use fresh output/user
folders. The first three temporarily remove the autoload configuration; the last
two temporarily instrument source. Each restores original bytes in finally. Do
not run another engine or editor against the checkout during these probes.

No performance candidate was shipped, so no before/after speedup is claimed.
Skipped new Windows export, gameplay acceptance suites, broad tests, lint changes,
cache-flushing claims and speculative dependency/validation removal. Existing
script_export_mode=2 means source-project timing must not be promised as packaged
Windows timing. The previous title-refresh improvement remains intact.
