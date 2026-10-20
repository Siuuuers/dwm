# Import integrity diagnostic — awaiting C review

Observable outcome: one fresh Windows cloud import explains every tracked-byte change at frozen product `c8358870d3ece92d5f8cc7ba65aefe34a746be5c` through exact before/after bytes, hashes, attributes, index state, and import provenance. The controller owns preparation and evidence retention; product owners and saved-data formats are unchanged.

Director scope: PR30 comment 6293667852. This is one import-only diagnostic after C reviews the exact candidate. No export, native journey, template download, retry, or full delivery attempt is authorized by this candidate. The earlier official attempt 39441551063 remains failed before export; its 990 changed sidecars cannot be classified retrospectively because rewritten bytes were not retained.

## Existing behavior inspected

- `.gitattributes` sets `* text=auto eol=lf`, with explicit binary treatment for selected historical evidence directories. `.editorconfig` specifies UTF-8. These rules are clues, not proof of the cause.
- Representative root icon, Dialogic addon, and evidence image sidecars contain Godot import settings, UIDs and cache references. We cannot assume their changes are harmless or normalization-only.
- `Invoke-WindowsExportValidation.ps1` expects an imported checkout and preserves temporary project plugin edits; it provides no general sidecar cleanup contract.
- The failed controller restored `project.godot` after import and then applied strict tracked-file integrity. This diagnostic restores nothing and captures project settings independently.
- Master was checked at `41592fcc792aa615e47ee2ce2f05008ca195b311`; no related runtime correction was imported.

## Exact candidate

- Helper immutable source: `4d4f232da7e234dbbc55d69d34f98930cbc06594`.
- Helper SHA-256: `a04a8560ea2ac7e8ff77d6bb3e3ffe8d1404193f5e1de2a71676332403fe7379`.
- Product: `c8358870d3ece92d5f8cc7ba65aefe34a746be5c` (tree `aacc9bfb8a1d076016a477e396acf781d4786062`).
- Official standard Windows Godot 4.6.3 editor archive SHA-256: `e39986a178d585ce7ac198fb8de6ea436366dc0cc00e594810c2e3e104c04b90`.
- Inert proposed controller: `controller.proposed.yml`; install only after external C review, with protected expected-head update of PR30's single workflow path.

## Evidence and failure behavior

The Python helper hashes every tracked raw worktree file before import. A preimage is referenced by immutable Git blob only when its raw blob hash agrees exactly; checkout-normalized bytes are saved directly otherwise. After import, every changed path retains binary-safe raw pre/post bytes and available HEAD/index blob bytes. Deletions, additions, index-only changes, and missing files are explicit. `project.godot` is retained independently even when unchanged. Files live outside the imported checkout, keyed by SHA-256; `changes.json` maps paths to bytes. CRLF-normalized equality is only a byte comparison, never a semantic exemption.

Original index is captured before the existing two malformed gitlink removals used for checkout credential cleanup. Their index-only changes are disclosed; all other tracked changes still fail the strict gate. Nothing is restored, deleted to conceal mutation, added to an ignore list, or promoted as product evidence.

Nonzero import exit, existing script-error filter failure, or timeout reaches an `always()` post-capture before integrity evaluation. Missing process receipts are explicit. A capture error fails the run; collected path mappings are retained with `complete=false` and the active path. An unexpected HEAD move is reported after capture. Artifact upload and evidence hashes run on failure. Abrupt runner loss can still prevent capture/upload and cannot support a diagnosis.

Import command, executable/archive/version, Windows runner image, PowerShell/Python/Git versions, isolated configuration paths, timestamps, original and post status/index/attributes/EOL settings, raw logs and phase outcomes are retained. No cleanup precedes post-capture. Strict integrity may intentionally fail on the reproduced mutation; this run can never claim delivery acceptance.

## Verification and next gate

Local Python/Git synthetic test passed: exact binary mutations, preexisting CRLF checkout bytes, metadata edits, deletion, newly indexed files, independent settings capture, index-only mutation, gitlink cleanup, hashes, duplicate-baseline refusal, and fail-closed HEAD movement with retained bytes. No local Godot or PowerShell was run. Independent internal source review found and resolved partial-manifest/HEAD-failure custody loss; YAML ordering and prohibited-operation checks passed.

C should review only this import/evidence delta and pinned workflow. Prior terminal/driver clearance remains applicable and is not re-requested. After C has no blocker, perform the one authorized diagnostic, retain the original artifact and logs, classify actual bytes by cause, then propose the smallest deterministic preparation correction with verification. A second full export/native attempt requires a new scope decision. Blind restoration of sidecars is not an accepted correction because cache coherence remains unproved.
