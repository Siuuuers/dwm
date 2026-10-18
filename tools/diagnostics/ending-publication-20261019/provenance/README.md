# Official engine provenance and stock-reader feasibility

This read-only audit strengthens custody of the official Godot 4.6.3 standard editor and export-template downloads. It **does not resolve the tested banner's source revision, establish a supported stock AccessKit parent-chain reader, or turn the failed ending journey into acceptance**. No gameplay, Godot, PowerShell, binary download, debugger attachment, or engine substitution ran during this audit.

## What the existing evidence establishes

Both the [Godot-builds release](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) and the [Godot mirror release](https://github.com/godotengine/godot/releases/tag/4.6.3-stable) publish identical sizes and SHA256 digests for the controller's exact inputs:

| Input | Bytes | SHA256 |
| --- | ---: | --- |
| Standard Windows x64 editor ZIP | 79,844,616 | `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90` |
| Standard export templates TPZ | 1,255,918,323 | `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8` |
| Exported `DWM.exe`, as bound by the original run receipts | 104,659,456 | `91724f15024a3a545e28ccd83134403d31ce2323a38e51c95e4dfa282f732ab6` |

The existing controller verifies the editor digest before expansion and the template digest before export. The original export validation and all three original mode results bind the same exported EXE hash. The exported game's hash is a local build/package receipt; it is not a separate upstream release asset digest.

The original fetched release inventories are retained under [metadata](metadata). Their relevant Godot-builds asset IDs are editor `425485542` and templates `425482597`; mirror IDs are `425559552` and `425557321`. Both release records report `immutable: false`. These snapshots preserve the metadata observed during this audit; they are not a cryptographic build attestation.

## Exact engine source remains qualified

The archived primary Load stdout identifies `4.6.3.stable.official.7d41c59c4`. The [official release announcement](https://godotengine.org/article/maintenance-release-godot-4-6-3/) names source commit `35e80b3a8822a9df9be390814b62f44c0a9c69e8`.

The Godot-builds hosting tag points to `4aa5b4950f650adc0aac8cb465479570b60c8122`, tree `ebdda167b6aa7d3d62db25299e6691ddd1633631`. Its pinned release-index blob `d8fed792a2d884b1fe4a291c4ac80fa135821fc8` records `git_reference: "4.6.3-stable"`. This is release-hosting metadata; it supplies no exact `7d41c59c4` to `35e80b3a` mapping.

At the public source commit, `main/main.cpp` lines 318–323 forms the banner suffix from the first nine characters of compile-time `GODOT_VERSION_HASH`. `methods.py` reads Git HEAD; `core/core_builders.py` emits the hash constant. The pinned tarball builder appends a synthetic `.git/HEAD` containing its resolved source revision. The released source tarball was not downloaded or inspected, so this build path does not resolve the discrepancy.

[The prior source-identity qualification](prior-engine-source-identity-note.md) retains the completed lookup results and file-level observations. Those failed diagnostics were not repeated. All new engine source readings in this folder use the public `35e80b3a` reference. Matching selected source blobs is narrower than establishing the complete tested binary's source tree or build.

## Native symbols: published inventory and historical configuration

**No Windows PDB or Windows native-symbol asset was found in either complete release inventory.** The only published assets whose names identify native debug symbols are Android editor and Android release-template ZIPs. This is an inventory finding, not proof that the original Windows EXE contains no symbol/debug data.

The public build configuration supports a narrower, concrete inference:

| Pinned source | Evidence |
| --- | --- |
| [Windows build script](source/build-scripts/windows-build-03934586.sh), commit `039345862ec0a5476044076ca7414cb92f3b99c1`, blob `afcf18947f4d96b3db77737f87273d9f97293542` | Lines 8 and 24–30 use `production=yes use_mingw=yes` for the editor, `template_debug`, and `template_release`, without `debug_symbols=yes` or a separate-symbol override. |
| [SConstruct](source/godot-35e80b3a/SConstruct), blob `58c895bfe51b6fc53b04d5a9b11677aa3e615f0d` | Production defaults native symbols off at line 665. The non-MSVC path adds linker `-s` when symbols are off at lines 854–859. |
| Same SConstruct | `template_debug` enables `DEBUG_ENABLED` game-development features at lines 527 and 543–546. Native `debug_symbols` is an independent setting. |
| [Historical release packaging](source/build-scripts/release-packaging-b3289deb.sh), commit `b3289deb5d8750c06f792dc197d068829445e10b`, blob `8d7c408436b2a7e599582cc940d7131d98067c45` | Windows packaging copies editor/wrapper and release/debug template EXEs at lines 211–253. Native-symbol packaging at lines 355–357 is for Android. |
| [Windows SCsub](source/godot-35e80b3a/platform/windows/SCsub) and [symbol builder](source/godot-35e80b3a/platform/windows/platform_windows_builders.py) | The separate MinGW symbol post-action is conditional on `debug_symbols`; the builder extracts a `.debugsymbols` file and adds a GNU debug link only when its separate-symbol/size condition applies. |

The two build-script revisions are the last public changes to those paths before the release's 20 May 2026 publication, as preserved by the commit-query snapshots. They are **not a receipt of the exact build-script revisions or overrides used by the release builder**. Current default-branch scripts were not substituted for historical release configuration.

Accordingly, the expected public configuration strips Windows targets, including the standard debug template. The audit did not inspect the original PE debug directory, embedded DWARF, CodeView record, symbol table, or a matching external symbol package. It therefore does **not prove the tested EXE symbol-free**. A `template_debug` filename alone provides no native-symbol guarantee, and symbols for a different editor/debug-template executable would not establish exact symbols for the tested release EXE.

## Stock output and the proposed after-failure snapshot

The pinned [AccessKit driver](source/godot-35e80b3a/drivers/accesskit/accessibility_driver_accesskit.cpp), blob `f0dfc5e056c4cf6341cda93763e294b7e5fe3df6`, has verbose adapter lifecycle messages: creation/destruction, activation/deactivation, initial-update completion, and dynamic-library loading. It does not call a tree/edge dump helper. The pinned [main.cpp](source/godot-35e80b3a/main/main.cpp) exposes accessibility mode selection and general verbose/script-debug options; no accessibility parent-chain dump switch was identified in that file. These are qualified reference-source observations, not a fresh executable capability test.

The already-retained external driver contains a dormant `Capture-FailureStacks` hook. It only runs when `DWM_CDB_PATH` is configured and a player is still live. Its command is noninvasive `cdb -pv -p <PID>`, uses the Microsoft symbol server, and requests `!runaway; ~* kv 24; lm; q` under 55 seconds. This captures stacks and modules; it is not a heap/tree snapshot or an AccessKit decoder. The hook was not invoked by this audit.

A useful private-state snapshot would first need:

- Exact original module identity and matching native debug information. PDB GUID/age is relevant to a CodeView/PDB path; a MinGW route would need the corresponding matching DWARF/debug-link information if present.
- Private AccessKit types/layout, or an independently validated decoder, for the Rust implementation in the loaded module or modules. Godot C++ symbols alone may leave the opaque adapter undecodable. This audit does not assume that the implementation resides in a separate DLL.
- A coherent bounded capture protocol. Live noninvasive reads are not guaranteed atomic; inconsistent pointer/edge reads must remain inconclusive.

No matching Windows symbol set or supported stock graph-decoding route was established here. A correctly decoded after-failure snapshot could show connectivity **at capture time**. It could not prove that the parent chain was emitted in the earlier natural update within the original 30-second ending gate. UIA client results also cannot substitute for the private graph or provide an established Godot RID mapping.

## Decision and custody limits

Retain the stronger official-asset provenance and the unresolved exact-source qualification. Do not treat another stock verbose/debug-template run as a known parent-chain discriminator. The exact-symbol/schema prerequisites for a useful original-binary private-memory diagnostic remain missing. Nothing in this audit justifies promoting the root-order experiment.

The retained run `39155624496` still has Capability and Create passing, followed by Load failing with `UIA_UNAVAILABLE_OR_TIMEOUT: TEST Seven-day ending.`, player exit `-1`, and forced cleanup. No end-to-end acceptance, durable final Gallery award, return-to-Title, or normal final exit was established by this provenance audit.

[findings.json](findings.json) provides the compact machine-readable conclusions. [sources.json](sources.json) records exact URLs, returned Git blobs, byte counts and SHA256 hashes for 32 original snapshot/input files. Thirteen source-file snapshots were independently rehashed as Git blobs and matched their returned pins. API snapshots preserve the connector-returned UTF-8 bodies without JSON reserialization; they are not HTTP wire captures or externally signed evidence.

The eight [existing-run](existing-run) members were copied byte-for-byte from original evidence ZIP SHA256 `d3fe288fe60167a2dda044c7a2d8962b0c88c789a5044f4347cb9b78993544cc`. Its original receipt is retained. This subset is not a replacement for the full archive or its independent verifier and does not rerun or relax any acceptance gate. The original EXE, TPZ, source tarball, and AccessKit binary archive are absent from this folder. Only source/metadata and existing evidence were read.

