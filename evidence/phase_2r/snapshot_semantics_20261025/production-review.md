# Synchronous Run9 snapshot validation review

## Observable outcome

Save and Load preserve the same complete dialogue beat, board, receipts and gameplay consequences while removing redundant whole-snapshot copying and hashing. SaveManager remains the Save/Load owner. RunSnapshotSchema owns snapshot admission; GameState and the installed narrative owners retain semantic validation.

Baseline: `a7a9707dae17b648c09e70a139e1c37d4a7a4d37` (master after PR82). Runtime/test candidate: `13b6853a6f66b92022a589489bf5f0187c18d1e3`. Inventory-only successor: `0ccaaed82bb0f896e998118ee8b5db5d2a25a7e3`.

## Ownership and synchronous boundary

`RunSnapshotSchema._normalize_integral_floats` recursively allocates each Dictionary and Array. Unsupported reference-bearing leaves cannot pass primitive-tree validation. Its candidate is already detached from the caller.

`DialogicEntryManifest.scene_registration` returns a detached canonical registration. RunSnapshotSchema still checks the supplied bundle against that registration before using the selected copy.

The subsequent production path through `GameState._prepare_scene_snapshot_semantics`, Frozen validators, Profile readers and `DialogicBridge.validate_scene_event_anchors` is synchronous. It reads the candidate and registration. Anchor validation restores a separate reading session; it does not install the candidate as live gameplay state, advance playback or publish gameplay signals. Frozen terminal validation copies its source before adjusting source lifecycle fields. No asynchronous yield or retained mutable candidate was found in this reviewed interval.

The removed hashes only detected injected callbacks mutating validation inputs. The removed second candidate/bundle copies supported those checks. They did not authenticate additional saved receipts, Profile bytes, frames or native anchors. The explicit unshipped-save policy excludes injected mid-call mutation as a gameplay obligation.

The change retains the reentrancy guard, semantic result checks, installed-owner matching and custom-owner fallback. `_scene_hash` remains because `_scene_equal` still authenticates registration equality; it is not an orphan.

## Failures and retained checks

- Invalid registration, shape, receipts, current physical Profile proof, historical frames and native anchors present before a call still refuse admission.
- Altering a returned candidate cannot change the caller snapshot or actual gameplay owners.
- Altering the caller afterward cannot change an already-returned candidate.
- A later public validation sees later corrupted inputs; there is no persistent proof cache.
- Failed validation applies no gameplay consequences.

The injected mutation-precedence test and its two orphan proxy helpers were retired. Its replacement checks nested Run9 receipt/caption detachment in both directions, later corruption refusal, exact admitted data and unchanged owner state. Other pre-call corruption and owner-boundary tests remain.

## Measurement decision

The Windows diagnostic at run `40118441660` completed its native Save and separate-process Load cases. Its instrumented scopes show that full-root capture was not the leading cost: retained Load captured the root 3,963 times in about 0.480 seconds, whereas its snapshot guard preparation and verification intervals were about 1.844 and 1.715 seconds. The preparation interval includes copying and hashing; the verification interval includes hashing. These observations selected the candidate, but are not complete-operation speedup claims.

Nested diagnostic times must not be added to UI operation totals. Final performance acceptance uses the uninstrumented candidate and baseline, identical retained inputs/helpers, separate-process fresh Load, and both execution orders. See `results.json` for final evidence and limits.

An earlier Linux diagnostic completed the gameplay assertions but failed on the unavailable native speech service (`Parameter synth is null`). It is not accepted qualification evidence. Windows qualification uses the established repository runner and pinned Godot 4.6.3.

## Future changes that reopen this boundary

Revisit the local reuse if production semantic validation starts mutating its inputs, retaining them for later work, yielding, invoking mutable external callbacks, or publishing gameplay state. Do not restore whole-tree mutation policing solely to satisfy an injected-owner test.

## Export boundary

The existing Windows export preset excludes `evidence/*`, `handoff/*`, `tools/*`, `tests/*` and `docs/*`. Retained test evidence and controller patches therefore do not enter the game export. No export preset or installed Steam build was changed in this work.
