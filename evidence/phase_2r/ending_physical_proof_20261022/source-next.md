# Snapshot phase decision — run39752940588

## Decision
Proceed with one leaf observation: wrap `ProfileManager.prove_scene_assignment()` and add aggregate `physical_proof_calls`, `physical_proof_us`, `physical_proof_failures` to the existing SceneValidationTiming operation record. Do not split another broad call tree or change validation. The next run will answer whether repeated current physical assignment proof explains a material share of the expensive validation paths, or rules it out. This is the smallest unresolved decision needed before considering any simplification.

## Measured evidence
All24 returned snapshot validations passed. Means in milliseconds:

| Input category | Calls | Total | Pre-semantic | Semantic callback | Prepare + verify guards |
|---|---:|---:|---:|---:|---:|
| PLAYING | 2 | 333.243 | 126.075 | 199.269 | 7.694 |
| PRIMARY_PENDING | 4 | 566.793 | 244.532 | 313.956 | 8.071 |
| EPILOGUE_PLAYED | 8 | 981.340 | 449.512 | 522.440 | 9.133 |
| GALLERY_RECORDED, including COMPLETED | 10 | 982.603 | 450.372 | 523.036 | 8.947 |

The24 returned snapshot totals sum20.610404s; their phases sum pre-semantic9.330086s, semantic11.064243s, guards0.210203s. Final Accept is21.586132s. These are nested accounting observations, not independent durations to add to Accept; completion ordinals alone do not prove nonoverlap. The schema's synchronous call sites and successful reentry-guarded observations support focusing on the validation boundaries. Copy/hash guard work is small; it is not a sensible surgery target.

Both expensive halves increase with terminal lifecycle complexity. The broad split has adequately excluded guard copying/hashing as the principal cost and has shown that optimizing only the installed semantic callback would leave substantial pre-semantic cost. It does not identify the expensive shared leaf or establish that any validator can be omitted.

## Shared leaf and authority
The current exact source call graph, retained in the preceding source audit, includes repeated `SceneEventContract.validate_scene_receipts()` invocations from RunSnapshotSchema and from the installed GameState/Frozen terminal validation paths. For committed initial admission these invoke `SaveManager.capture_committed_scene_creation()`, which calls `ProfileManager.prove_scene_assignment()`.

That leaf performs current storage revision inspection of profile.json, strict decode/validation, canonical emission and retained assignment-row validation. The whole leaf is synchronous. Its inclusive duration is therefore informative without separately instrumenting every read/parse/hash. In contrast, `get_pair_deck_draw()` reads the initialized in-memory assignment and is not itself a disk read. Existing configuration/compilation timings do not measure the whole physical proof.

Exact ProfileManager source is autoload/ProfileManager.gd, Git blobdf09421ed6d7573c0e43da640dcc8ba610b4a10d, SHA25666383d7ca934a4fd9ad16575d29e5706d4e35c40155b71d39eeda4311c794e7d,94261bytes; verify against this run's original preparation receipt. Current product9f404db25737fca51b1ab3f2fe495d55a0b4dbda retains this unchanged owner. Existing helper source is the reviewed snapshot observer composition.

Repeated terminal checks are a concrete simplification candidate only after a proof that their authority inputs remain stable over an internal delegation. They include fresh physical creation/assignment authentication, frozen historical frame checks and reading-anchor validation. A repeated function name is not sufficient evidence to skip those checks. No persistent cache, saved Boolean, checkpoint coalescing, weakened mutation guard or omission of a physical proof is recommended.

## Minimal observation contract
Two files only: ProfileManager and existing SceneValidationTiming. Preserve public signature; record start via the helper; delegate once to the unchanged renamed original body; record the returned ok/failure and elapsed microseconds; return the same Dictionary. Inactive helper sampling returns-1 and records nothing. No new clock/label/copy/owner call is introduced beyond timing, and no proof or save candidate receives diagnostic fields. The helper remains dependency-free, so the new preload introduces no schema/Profile dependency cycle.

Initialize the three aggregate fields in each existing writer scope. Capture may have zero calls; prepare/commit counts are observed dynamically rather than prescribed. On a successful focused run require nonnegative integer fields and zero failures; missing records or an interrupted call must not be fabricated as completed time. Preserve all existing snapshot/journal/whole-operation assertions, engine, renderer, child deadline and the three distinct ending persistence boundaries.

The inclusive proof total belongs within snapshot/operation totals and must not be added to them. A high share justifies inspecting this leaf for pure-work redundancy with its current-byte proof intact; a low share falsifies this hypothesis and shifts attention to the already identified receipt/Frozen work. Neither result by itself authorizes caching or bypassing authority. Independent exact-body source review precedes packet preparation/dispatch; compare future optimization candidates under matched flags and complete operation timing.

This audit makes no performance-improvement, restored-journey or exported-game claim.
