# Desktop dependency experiment

This experiment does not qualify a product performance change. Keep the original
failure and the later successful diagnosis as separate results.

| Run | Scope | Result |
|---|---|---|
| [40203205178](https://github.com/Siuuuers/dwm/actions/runs/40203205178) | Matched baseline/desktop exported comparison, plus uninstrumented Apps regression | Exported comparison stopped after four of twelve planned processes. Three passed strict checks. The retained candidate completed gameplay and exited zero, but reported two resources still in use at shutdown. |
| [40204864050](https://github.com/Siuuuers/dwm/actions/runs/40204864050) | Exact original package bytes with verbose logging; no rebuild | Six diagnostic processes passed. The shutdown failure did not reproduce. First Apps opening and cached reopening passed. This single-order verbose run is not performance acceptance. |

The independent uninstrumented Apps creator/loader passed two tests with 130
assertions. It covers purchase/navigation/challenge preservation, saving, and
restoration in a fresh process. It does not explain the exported shutdown error.

The candidate only replaces ApplicationBootstrap's eager ComputerDesktop scene
load with a guarded load after live-session admission and before port creation.
Cache observations confirm that the scene and script are absent before Title
in the candidate. The original startup/preparation result is in
[the preceding evidence](../exported_startup_20261025/README.md).

## Retained files

- `run40203205178-evidence.zip`: original compact exported evidence artifact 12602104512.
- `run40203205178-regression.zip`: original regression artifact 12603176132.
- `run40204864050-verbose-evidence.zip`: original verbose artifact 12603098105.
- Matching member manifests record archive size/hash, member hashes and CRC verification.
- Matching summaries distinguish complete gameplay, strict acceptance and performance limits.

The original package artifact is 12602274130 from run 40203205178. Package hashes
and source identities are retained in the compact archives. Large executable/PCK
files and shader caches are not duplicated here. Current-format profile/save
payloads are retained in the exported evidence archives.

The coordinator reviewed contact sheets covering all 21 images from the first
run and regression (17 unique images), and all 20 verbose images (10 unique).
Seven first-run image entries and all 20 verbose image entries match their
process manifests. The failed first-run process has no image manifest; its three
PNGs are retained and hashed without claiming comparison to that missing manifest.

No runtime source or save format change is approved by these records. All engine
execution occurred on Windows cloud runners. See the
[handoff](../../../handoff/y-desktop-dependency-investigation-20261025.md).
