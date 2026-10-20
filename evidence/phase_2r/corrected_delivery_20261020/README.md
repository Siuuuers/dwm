# Corrected official delivery preparation — awaiting C review

Observable outcome: the frozen product reaches export only with exact accounted-for source bytes and generated inputs; the unchanged package audit then gates Capability → Create → Load → TerminalLoad. The workflow owns preparation/evidence. No product, runtime, save, recovery, history, selector or deadline behavior changes.

Director PR30 comment 6295116783 authorizes preparation of this concrete controller. After C reports no blocker to this exact integrated delta, A may install it by expected-head-protected replacement and run **one** corrected official Windows attempt. Preparation and export must pass in that same run before the four existing native phases. No additional Director confirmation is required within that sequence. Stop at the first causal failure, preserve evidence, and do not retry automatically. C must review actual package/results before acceptance. Prior failed attempts 39441551063 and 39450025637 retain their original dispositions.

## Pins and scope

- Product `c8358870d3ece92d5f8cc7ba65aefe34a746be5c`, standard GDScript; no .NET engine.
- External preparation source `55e5675eb683ae26c1bb16d511c435c0a1ec1272`; helper SHA-256 `9235be503d2a7bd5d5216e203681a010a40409ab9cea37a06d2245c4cec501d9`.
- Unchanged capture helper at `evidence/phase_2r/import_integrity_20261020/capture_import.py`, SHA-256 `a04a8560ea2ac7e8ff77d6bb3e3ffe8d1404193f5e1de2a71676332403fe7379`, fetched from that same immutable source.
- Existing driver source `8adc8c78fcbf25fa0df030391bac6f1d64073a01`, SHA-256 `7a4bcd31aa4f340e76e0aee34c5857565d672ed38b3c66275fab525ea40ac21c`.
- Official Godot 4.6.3 standard Windows editor/archive and export-template pins unchanged. Native steps retain 30-second steps, 480-second journeys, separate processes, same selectors and terminal-save semantics.
- Active PR30 controller remains `d47703368ad96c5ea0338b74b351f9d1c9cc1487` while this candidate is inert. Product PR36 remains draft/unmerged.

## Preparation and failure ordering

1. Fetch and hash-verify both Python helpers outside the source checkout. Capture baseline before the existing two malformed gitlink removals. Every tracked file must match its pinned raw Git blob; HEAD/index paths, modes and blobs must agree. Capture settings and config. A dirty baseline fails.
2. Import once with the pinned official editor and isolated configuration. Retain command, executable/version, platform, configuration, console/log, actual exit and filter receipts.
3. Always capture after import, before any restoration. Preserve exact pre/post changed tracked bytes through the previously reviewed helper. Independently enforce the raw-byte census: only the exact previously captured project-settings rewrite is permitted. Git's content-aware predicate is supplementary, never a substitute for this policy.
4. Retain generated-file paths, raw bytes, hashes, source-owner blobs, provenance and export classification. Reject any unreviewed input. Failure blocks restoration and export, with original bytes retained.
5. Restore only `project.godot`, from the immutable pinned Git object, after all import policies pass. Verify exact restored bytes and repeat the raw census in a separate `restored` directory. No sidecar restoration or blanket ignore occurs. Run the reviewed content comparison `git -c diff.autoRefreshIndex=false diff --exit-code` and preserve the existing HEAD and allowed-index guards.
6. Run the unchanged exporter. It already temporarily removes only the GUT editor plugin and restores project bytes in its finally block; no exporter edit is introduced. It validates official templates, source data, package contents, package identity and startup.
7. After exporter success/failure/cancellation, always collect a separate `final` raw census and generated-file inventory before any native journey. Require exact tracked equality and exactly the same generated path/hash set as before export. A failure prevents native phases. If export never ran, this final check is skipped so it does not obscure an earlier preparation failure.
8. Existing cumulative success gating stops later native phases after failure. Always summarize and upload original delivery evidence plus a separate external preparation artifact, each with hashes and actual phase outcomes. Missing import receipts are explicit. Runner loss can prevent capture; missing/incomplete evidence cannot establish acceptance.

The exact settings exception is hash-pinned: original SHA-256 `5e8009d890f9e4359b24bb68a59fdec1bf56ef0a3ea94be06c3e43a6d2353053`, observed import SHA-256 `6880d26a04484587a54c63e0a98072984b6adac7ac3e9d07e8d138e934428fdd`. C previously verified that clearing only Dialogic's `directories/dtl_directory` reproduces the entire observed file. Any other settings bytes fail. Unchanged settings are also valid.

## Bounded generated-input policy

The clean baseline must have no untracked source inputs, including ignored inputs. The scan uses `git ls-files --others` without `--exclude-standard`; only `.godot/` is outside this authored-input inventory because it contains the disposable engine import cache and CI outputs. Evidence and helper code live outside the imported tree.

After import, accept only `.import` or `.uid` files whose corresponding source is tracked and whose paths are under `tests/` or `evidence/`. Capture all their bytes. Unknown files, runtime metadata outside those directories, missing owners, and nonregular/symlink inputs fail after evidence retention. This deliberately does not assume that the 34 prior names have reviewed contents or that exactly 34 files will recur. The current run must supply its own complete bytes and provenance. Nothing is added to the index or promoted to source.

The exact `export_presets.cfg` SHA-256 `76d904435496d2057572225b796f8b3c74f121a21254d211a6246caaf96efcaa` pins `all_resources`, runtime include patterns and development exclusions. `tests/*` and `evidence/*` exclude the accepted generated metadata. The unchanged actual-PCK audit recursively rejects every test resource except these three exact saved-identity compatibility data files:

- `tests/fixtures/dialogic/scene_seven_day_linear.dtl`
- `tests/fixtures/dialogic/scene_seven_day_ending.dtl`
- `tests/templates/scene_sequence/seven_day_order.json`

It also rejects the entire `evidence` directory and the other development directories. None of these three compatibility files is generated `.uid`/`.import` metadata. The audit hashes runtime JSON/DTL/DCH and compatibility data against source, while existing exporter checks retain package hashes, template sidecars and process outcomes. Excluded metadata must remain unchanged through export; new or changed generated inputs fail the final check. Generated runtime inputs would require focused review instead of silent acceptance.

## Verification and review request

Seven synthetic Python/Git integration tests passed: known settings restoration with exact generated bytes (including ignored UID files), real sidecar mutation, unexpected settings mutation, generated runtime metadata, unexpected untracked files, generated input appearing after export, and staged mutation concealed by restoring worktree bytes. Independent internal review ran the same suite and found no blocker. The inherited capture helper emitted Python ResourceWarnings for its object-reader stdout handles during in-process tests; tests passed and the helper remains byte-identical to C's reviewed version. No local Godot or PowerShell was executed.

Offline YAML checks confirm ordering and exact equality of the existing driver preparation, template steps, exporter call and all four native steps. Settings exception hashes match the retained original cloud bytes. Prior original-artifact, predicate, driver and terminal reviews are reused; no repeat import-only campaign is proposed.

C: review only this integrated preparation/helper/generated-input delta, including raw enforcement, capture-before-restoration, exact settings restore and accounted export inputs. A will install and execute the one corrected official attempt only after your no-blocker disposition. No delivery/performance acceptance, merge, release or master/integration movement is claimed.
