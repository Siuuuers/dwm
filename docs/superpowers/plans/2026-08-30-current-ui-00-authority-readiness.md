# Current UI-00 Authority Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the ten accepted current-UI dossiers uniquely and fail-closed machine-discoverable, reconcile the five stale requirement clauses in the four confirmed conflict areas, define the minimum slice-admission contract for later runtime children, and produce an exact reviewed consumer/provenance census without implementing UI or cutting over any family.

**Architecture:** One narrow `CurrentUiDossierProjector` validates the countersigned current-UI acceptance projection and exact dossier bytes at the repository boundary. `AgentWorkflowAuthorityResolver` adds one backwards-compatible `canonical_ui_id` link kind and conditionally validates ordinary design specifications that declare an implementation-target admission. Requirement packets retain their stable IDs while five stale behavior bodies and three authority-context bodies are corrected. A separate read-only census checker validates one reviewed JSON evidence artifact; neither the census nor `prompt_docs/INDEX.md` becomes design authority.

**Tech Stack:** Godot 4.6 GDScript, GUT, strict UTF-8/LF Markdown and JSON, PowerShell 5.1 repository tooling, ripgrep, Beads, and exact-path Git commits only when separately authorized.

**Spec:** [`docs/superpowers/specs/2026-08-30-current-ui-incremental-implementation-roadmap-design.md`](../specs/2026-08-30-current-ui-incremental-implementation-roadmap-design.md)

**Lifecycle status:** Proposed written procedure. These bytes do not approve themselves and are not executable until every gate in “Approval and execution gates” passes.

## Global Constraints

- UI-00 is documentation, authority-tooling, and audit-evidence readiness only. Do not edit application runtime, autoloads, scenes, resources, assets, localization, save schemas, gameplay tests, story content, or player-facing UI.
- Do not change any byte in `docs/design/current-ui/README.md` or the ten accepted dossiers. Any mismatch is a stop condition, never an invitation to repair accepted writing.
- Do not move, copy, archive, delete, or mark superseded any prior design source. Do not edit `docs/design/superseded/`.
- Machine discovery and family cutover are separate. A successful `canonical_ui_id` resolution must preserve `authority_effect: nonbinding_until_accepted_repointed_and_machine_discoverable` and cannot claim that a consumer was repointed.
- Keep requirement, specification, accepted-writing, machine-discovery, cutover, implementation, execution-permission, commit-permission, Beads-status, and verification-evidence states independent.
- Add exactly one resolver link kind, `canonical_ui_id`. Do not add an admission link kind, a second design registry, or current-UI rows to `prompt_docs/INDEX.md`.
- Preserve the resolver’s public result envelopes and existing error taxonomy: `ok`, `AUTHORITY_LINK_INVALID`, `AUTHORITY_LINK_UNKNOWN`, `AUTHORITY_LINK_DUPLICATE_TARGET`, `AUTHORITY_LINK_SOURCE_INVALID`, and `AUTHORITY_LINK_UNAPPROVED`.
- Preserve every existing hash-bound implementation plan byte-for-byte. A changed plan digest stops UI-00.
- Preserve the stable but historically named requirement ID `req.save.minesweeper_lock`. Renaming it would require a separate requirement-ID, Beads, evidence, and frozen-plan migration.
- Reconcile only the five stale behavior-rule bodies and the three authority-context rule bodies named in this plan—eight bodies total. Do not repair currently contradictory runtime behavior or weaken runtime tests to make documentation appear implemented.
- Keep `prompt_docs/INDEX.md` generated. Because UI-00 changes no packet IDs, owners, dependencies, statuses, or Beads bindings, regeneration must leave its current SHA-256 `d4c24033eea0a6ffd2e16be1e5c8000ea4980997f7408ad24e5ee198587995c3` byte-identical.
- Use `apply_patch` for every authored file edit. Generated index output may be written only by `tools/docs/generate_index.gd`.
- Run Godot through `tools/testing/Invoke-IsolatedGodot.ps1` with unique suite IDs and `evidence/current_ui/logs/isolated-godot.jsonl` after execution is authorized.
- Execute Tasks 0–5 serially through the one selected UI-00 issue. Task 4 family classifications may receive parallel read-only reviews only when every reviewer uses the same inventory/artifact subject; one integrator applies the reviewed JSON edits.
- Preserve all unrelated dirty and untracked user work. Never use broad staging, `git reset`, `git checkout`, `git stash`, destructive cleanup, or a recursive move.
- Commit steps are conditional. If exact commit permission is absent, do not stage; retain verified changes uncommitted and report that durable versioned custody and UI-00 completion remain open.
- Never push.

---

## Proposal-Time Evidence and Known Blockers

The plan was authored from this read-only observation:

| Fact | Observed value | Meaning |
|---|---|---|
| Proposal branch | `docs/recover-design-brain` | Informational only; not an implementation branch grant |
| Proposal HEAD | `67228bc164a593e5ccc207fbf87196df1ee26a04` | Proposal base candidate, not an approved implementation base |
| Roadmap specification current SHA-256 | `f70cc70b2b8e20c0db443383544c955f9f793701ea734bd97cfec7aa143f9ae0` | Current clerical approved-state rendering after recording approved pending-state digest `6dd6565cbf1c59277c5ecb673b6e1f4d30b8cd48a8b069bac6a0b88c6a770b35` |
| Current-UI directory | all eleven Markdown files untracked | Durable versioned custody is not yet established |
| Roadmap specification | untracked | Must be included in an independently authorized proposal/custody transaction before execution |
| Current-UI README | 28,664 bytes; SHA-256 `eff07ec5026dfb76f18d106beadab3d8aa1e8dadf76fa3e32acac2adccbc0185`; UTF-8, no BOM, LF, final LF | Observed recovery/custody identity only until separately countersigned |
| Acceptance-binding projection | 1,358 bytes; SHA-256 `38bb3f4a105671967aae65017165c23838e38863c0a4da0049218d5229d0bdb3` | Stable machine-discovery trust root over the ten accepted ID/path/byte/hash bindings; separately countersigned and deliberately independent of mutable lifecycle prose |
| Beads CLI | workspace found, database `dwm` missing | Planning may continue; execution and issue registration are blocked |
| UI-00 Beads issue | none proven | An actual CLI-created/read-back issue is a registration prerequisite; no ID may be invented |
| Existing `.beads/issues.jsonl` | modified user/external state | Never edit directly or absorb into a UI-00 commit |

The current README candidate needs this separate narrow owner decision before it may be compiled into the trust boundary:

> Countersign `docs/design/current-ui/README.md`, SHA-256 `eff07ec5026dfb76f18d106beadab3d8aa1e8dadf76fa3e32acac2adccbc0185`, as the clerical custody and acceptance ledger for the ten already accepted dossiers; and countersign acceptance-binding projection SHA-256 `38bb3f4a105671967aae65017165c23838e38863c0a4da0049218d5229d0bdb3`, the 1,358-byte UTF-8/LF sequence whose sorted lines contain `id`, TAB, `repository path`, TAB, `decimal byte length`, TAB, `accepted SHA-256`, and LF, as the stable machine-discovery trust root. The full-file hash is custody evidence; a separately reviewed lifecycle/provenance edit may change it without changing machine discovery when the acceptance projection remains identical. This does not repoint authority or authorize implementation, cutover, source movement, archival, registry mutation, or commit.

If that countersignature is absent, stop before Task 0. Plan approval alone does not supply it.

### Accepted cohort frozen by owner approval

| Family | Stable ID | Path | Bytes | Accepted SHA-256 |
|---|---|---|---:|---|
| Global UI Grammar | `canon.current_ui.global_ui_grammar` | `docs/design/current-ui/global-ui-grammar.md` | 94,529 | `4c2dba5908c854e6972df608ef45c9bbe31654d3bc81ba18f22259a720cabecf` |
| Contacts | `canon.current_ui.contacts` | `docs/design/current-ui/contacts.md` | 63,778 | `4739b83c1260a9c9c48b90bc2ad92fc6a163a88fe10262914e7ef0e90f9395bb` |
| Shared Shell | `canon.current_ui.shared_shell` | `docs/design/current-ui/shared-shell.md` | 123,247 | `232af85acee85bb69b58cdff1c42cb755ab0d821b90866ca2f6c026126824d71` |
| Gallery | `canon.current_ui.gallery` | `docs/design/current-ui/gallery.md` | 93,975 | `7fbc858566a6d9317f857e94bdf5f6ca889188d8b0132dab86585c25e1f04c11` |
| Witnessed Scene | `canon.current_ui.witnessed_scene` | `docs/design/current-ui/witnessed-scene.md` | 129,386 | `7b3ce28e0732e54c3227bf978bacd3e45a947f0393913784cfd34dfbc07f30b4` |
| Shop | `canon.current_ui.shop` | `docs/design/current-ui/shop.md` | 109,665 | `6c10286dcc90fae48f4a50fbb83860c35ad97c0d02692b2c0af42e83ba69641e` |
| Backup | `canon.current_ui.backup` | `docs/design/current-ui/backup.md` | 121,824 | `1da253e262d996234208e2c95a1096a518ff1a19d02b8a1b85f185f9350da78d` |
| Settings | `canon.current_ui.settings` | `docs/design/current-ui/settings.md` | 108,168 | `f8877f892aee62a3d5f3ba5618def2fe5b751508aa4a7e5da11d1c8459b1fa51` |
| Schedule | `canon.current_ui.schedule` | `docs/design/current-ui/schedule.md` | 98,224 | `7183b9323908e9b10eab5d9192dfc567f5fe1d10b170c1c5eb53e23679539180` |
| Minesweeper | `canon.current_ui.minesweeper` | `docs/design/current-ui/minesweeper.md` | 117,037 | `20c4319ded61b8ce7474c5ad84414c3a7b46f3fc9bf567c6491a041271ec6430` |

All eleven observed files are valid UTF-8 without BOM, use LF only, and end in LF. The resolver must prove these facts again; this table is not executable input.

### Retained deeper authority inputs

These are the exact stable owners the accepted dossiers declare as still-current, mixed, pending, or retained. The scope phrases summarize those accepted declarations for UI-00 routing; the census must bind every concrete disposition back to exact accepted dossier section bytes rather than treating this table as new behavior authority.

| Family | Retained/current stable IDs | Scope retained through UI-00 |
|---|---|---|
| Global UI Grammar | `spec.haunted_instrumentarium_ui_manual_foundation_decisions`; `note.global_functional_semantic_alphabet_disposition`; `note.functional_state_morphology_and_overlap_disposition` | mixed cross-family identity/reliability/theory and M-behavior handoff; pending semantic alphabet writing; accepted morphology within its recorded scope |
| Contacts | `spec.contacts_messaging_ui_ux_canon_amendment`; `note.contacts_maintained_correspondence_register_standard_palette_and_state_disposition` | current Contacts behavior/canon and pending visual Standard until valid Contacts cutover |
| Shared Shell | `spec.main_menu_desktop_shell_global_chrome_ui_ux_amendment`; `note.shared_title_desktop_shell_standard_palette_and_state_disposition`; `spec.title_art_placement_bottom_up_scene_caption_rhythm_amendment`; `spec.ordered_ending_host_universal_pause_ui_ux_amendment` | current shell behavior/geometry, pending shell visual Standard, retained title/caption law and plan provenance, and retained ending/Pause ownership outside the admitted host clauses |
| Gallery | `spec.gallery_rehearsal_archive_ui_ux_amendment`; `note.deferred_ui_feature_register`; `note.gallery_maintained_microfiche_registrar_standard_palette_and_state_disposition` | deeper archive/profile/replay/history and future Rehearsal law; current-v1 Rehearsal exclusion; current visual Standard until valid cutover |
| Witnessed Scene | `spec.narrative_scene_host_dating_hospital_challenge_ui_ux_amendment`; `spec.title_art_placement_bottom_up_scene_caption_rhythm_amendment`; `guide.visual_art_placement_and_asset_production`; `note.canonical_spoken_scene_agency_disposition`; `note.hospital_ordered_ending_current_v1_ui_disposition`; `spec.ordered_ending_host_universal_pause_ui_ux_amendment`; `note.room_owned_aperture_caption_material_disposition`; `note.ordinary_witnessed_scene_reading_apparatus_standard_palette_and_state_disposition` | deeper host/transport/persistence/recovery, title and caption law, asset production, cross-cutting agency, ending/Pause, and accepted material/apparatus scopes retain exactly their dossier-classified portions; the frontmatter-less Room-Owned Aperture source path remains provenance while its separate `spec.room_owned_aperture_v1_design` token is a dangling reference to replace without inventing identity or authority |
| Shop | `spec.shop_catalog_transaction_ui_amendment`; `spec.desktop_minesweeper_shop_schedule_amendment`; `note.shop_maintained_campus_stores_standard_palette_and_state_disposition` | catalog/transaction/persistence and cross-app mechanics stay deeper-owned; visual Standard stays current until valid Shop cutover |
| Backup | `spec.backup_save_load_ui_ux_amendment`; `note.backup_transfer_bloom_disposition`; `note.backup_archive_cabinet_standard_palette_and_state_disposition` | save/load behavior, transaction/compatibility/cache/external boundaries; Bloom direction/deferred field; current whole-family visual Standard |
| Settings | `spec.settings_preferences_ui_ux_amendment`; `note.settings_university_calibration_registry_anatomy_disposition`; `note.settings_university_calibration_registry_standard_palette_and_state_disposition` | preference/profile/localization/audio/input/persistence/component law; accepted anatomy direction with pending exact writing; current two-Standard visual mappings/proof |
| Schedule | `spec.schedule_focused_docket_folio_ui_ux_amendment`; `spec.desktop_minesweeper_shop_schedule_amendment`; `note.schedule_mounted_docket_desk_standard_palette_and_state_disposition` | focused Schedule behavior/persistence/failure/handoff, mixed cross-app mechanics, and current whole-family visual Standard |
| Minesweeper | `spec.minesweeper_board_session_challenge_ui_ux_amendment`; `spec.desktop_minesweeper_shop_schedule_amendment`; `note.minesweeper_maintained_survey_worksheet_standard_palette_and_state_disposition` | deeper board/session/challenge law, generation/cost/checkpoint/cross-app mechanics, and owner-approved visual direction whose exact writing remains pending |

---

## Approval and Execution Gates

Every gate is independent and fail-closed.

### Gate A — Exact plan review

- The owner reviews this file’s exact canonical-text SHA-256.
- Approval authorizes the written procedure only.
- The roadmap specification records the approved plan path and digest only through a separately reviewed lifecycle edit.
- Any semantic plan edit invalidates that approval and requires a new digest.

### Gate B — Versioned custody base

- A separately authorized exact-path custody transaction tracks the ten unchanged dossier files and the countersigned README.
- A separately authorized proposal transaction tracks this plan and its roadmap specification lifecycle binding.
- Every retained authority path needed by UI-00 exists as a regular non-link tracked file.
- The execution grant names the resulting full implementation-base commit. Proposal HEAD `67228bc164a593e5ccc207fbf87196df1ee26a04` must not be silently reused after HEAD advances.
- No file under `docs/design/superseded/` participates.

### Gate C — Beads recovery and registration

- Restore the Beads database through separately authorized recovery work without overwriting the modified `.beads/issues.jsonl`.
- Run `bd prime`, read-only health/status queries, and a fresh strict snapshot export successfully.
- Verify no UI-00 issue already exists.
- With separate Beads-mutation permission, create exactly one issue titled `UI-00 — Current UI authority readiness` whose scope cites this roadmap and exact approved plan digest and whose exclusions match this plan.
- Read the actual issue ID back through `bd show`; bind that real ID in the lifecycle/execution record. Do not rewrite this plan merely to insert the future ID.
- Do not register UI-01 or any runtime child during UI-00.

After database recovery and separate Beads-mutation permission, create the issue with this exact semantic payload; `$planDigest` is the already verified Gate A digest:

```powershell
$description = 'Make the ten accepted current-UI dossiers fail-closed machine-discoverable; reconcile five stale behavior rules and three authority-context rules; validate the smallest later slice-admission schema; and produce one reviewed consumer/provenance census. No runtime, cutover, source movement, archival, push, or unrelated repair.'
$acceptance = 'Exact custody/projection and protected-plan hashes pass; all ten canonical_ui_id links resolve; negative cases fail with the frozen taxonomy; eight rule bodies match; admission fixtures pass without implied runtime/commit permission; census has zero unresolved references; no runtime or cutover path changed.'
$metadataObject = [ordered]@{
  roadmap_specification_id = 'spec.current_ui.incremental_implementation_roadmap'
  roadmap_path = 'docs/superpowers/specs/2026-08-30-current-ui-incremental-implementation-roadmap-design.md'
  plan_path = 'docs/superpowers/plans/2026-08-30-current-ui-00-authority-readiness.md'
  plan_sha256 = $planDigest
  scope = @('accepted current-ui custody projection','canonical_ui_id discovery','slice admission validation','eight exact requirement bodies','consumer provenance census')
  exclusions = @('runtime UI','family cutover','source movement','archival','push','unrelated repair')
  implementation_authorized = $false
  implementation_commit_authorized = $false
}
$metadata = $metadataObject | ConvertTo-Json -Compress -Depth 5
$created = bd create --title 'UI-00 — Current UI authority readiness' --type task --priority 1 --labels 'documentation,tooling,current-ui' --spec-id 'spec.current_ui.incremental_implementation_roadmap' --description $description --acceptance $acceptance --metadata $metadata --json
$created
```

Require one created ID, then `bd show` it read-only and compare every field. The later execution and commit grants update permission metadata only through separately authorized `bd update`; registration itself keeps both booleans false.

### Gate D — Exact execution permission

The execution grant must name the approved plan path/digest, actual UI-00 issue ID, implementation-base commit, relevant-path census, exact docs/tooling/test/evidence mutation boundary, and all exclusions. Plan approval, README countersignature, custody, Beads readiness, and execution permission do not imply one another.

After that owner grant and separate Beads-mutation permission, bind its already-computed exact values without replacing the registered scope:

```powershell
bd update $ui00IssueId --status in_progress --set-metadata implementation_authorized=true --set-metadata implementation_base_commit=$implementationBase --set-metadata execution_plan_sha256=$planDigest --set-metadata execution_scope_id=ui-00.authority_readiness --set-metadata execution_grant_sha256=$executionGrantSha256
bd show $ui00IssueId --json --readonly
```

Task 0 requires every bound value to equal the owner grant. A boolean alone is insufficient.

### Gate E — Conditional commit permission

Commit permission must independently enumerate the exact custody and UI-00 commit boundaries. Without it, every staging/commit checkbox below is skipped. Successful uncommitted tests do not satisfy durable custody or final UI-00 completion.

When the owner grants those exact maps, record the independent receipt and read it back:

```powershell
bd update $ui00IssueId --set-metadata implementation_commit_authorized=true --set-metadata commit_scope_id=ui-00.exact_path_maps --set-metadata commit_grant_sha256=$commitGrantSha256
bd show $ui00IssueId --json --readonly
```

Neither update creates a commit; the exact-path helper still checks permission at every boundary.

---

## Failure, Rollback, and Safe Stop

- Any failed approval, custody, base, Beads, path/link, encoding, digest, baseline, or overlap check stops before the first authored mutation.
- A RED test may fail only for its named unsupported behavior. Parse errors, missing dependencies, zero executed tests, engine errors, or an uncreatable required directory-link fixture stop the task.
- After an uncommitted task failure, preserve the exact diff and evidence for review; do not use reset, checkout, stash, broad cleanup, or an inferred repair. Apply only the smallest in-scope correction after its cause is identified.
- After an authorized task commit, a later failure does not rewrite history. Keep the last green commit as the recovery point and use a separately reviewed exact-path repair commit, or a separately authorized revert, before continuing.
- A generated-index mismatch is not hand-edited or normalized away. Stop, identify the packet/index cause, and rerun the authorized generator only after the cause is in scope.
- A census ambiguity remains in `unresolved_references` and returns to the owner. A missing runtime interface, copy decision, asset, or UI behavior never expands UI-00; it becomes a later child blocker.
- Beads registration/closure failure leaves the issue open or unchanged. Never repair the database by editing `.beads/issues.jsonl` directly.

---

## File and Responsibility Map

### Create

| Path | Responsibility |
|---|---|
| `tools/docs/CurrentUiDossierProjector.gd` | One boundary validator for the countersigned README ledger and direct-child dossier bytes; no authority mutation |
| `tests/unit/tooling/test_current_ui_dossier_projector.gd` | Adversarial UTF-8/LF, ledger, lifecycle, duplicate, digest, and path tests |
| `tests/unit/tooling/test_current_ui_requirement_reconciliation.gd` | Exact stable-ID/dependency/body regression for the five corrected rules and authority-context distinctions |
| `tools/evidence/CurrentUiConsumerCensus.gd` | Pure read-only parser/scanner/checker for the reviewed census artifact |
| `tools/evidence/validate_current_ui_consumer_census.gd` | CLI wrapper for `--check --input=res://evidence/current_ui/authority/ui_00_consumer_census.v1.json` |
| `tests/unit/tooling/test_current_ui_consumer_census.gd` | Exact-key, ordering, coverage, basis-hash, and unresolved-reference rejection tests |
| `evidence/current_ui/authority/ui_00_beads_registration.v1.json` | Immutable strict export of the registered UI-00 issue set used as a census input; live `.beads/issues.jsonl` is never scanned or copied |
| `evidence/current_ui/authority/ui_00_consumer_census.v1.json` | Reviewed audit evidence; never resolver input or behavior/cutover authority |
| `evidence/current_ui/logs/.gitkeep` | Makes the repository-contained evidence parent exist before the isolated runner's first RED call |
| `evidence/current_ui/logs/isolated-godot.jsonl` | Isolated command ledger created only during authorized execution |

Godot may create matching `.uid` files for new GDScript files. Treat each as optional generated output: inspect it, include it only in the same exact-path boundary as its script, and never invent UID bytes manually.

### Modify

| Path | Responsibility |
|---|---|
| `tools/docs/AgentWorkflowAuthorityResolver.gd` | Add `canonical_ui_id`; consume the projector; conditionally validate the slice-admission record while preserving legacy specification behavior |
| `tests/unit/tooling/test_agent_workflow_authority_resolver.gd` | Resolver integration, error taxonomy, real ten-ID cohort, and admission lifecycle tests |
| `tests/unit/tooling/test_agent_workflow_validator.gd` | One fixture proves generic authority-link delegation accepts the added kind; no production kind switch |
| `prompt_docs/requirements/authority_context.md` | Distinguish accepted target discovery, retained ownership, cutover, plan, execution, commit, and evidence |
| `prompt_docs/requirements/contacts_invitations.md` | Replace solo reply acceptance and linked-group double-acceptance wording |
| `prompt_docs/requirements/persistence.md` | Replace lifetime Minesweeper save-lock wording while retaining stable ID |
| `prompt_docs/requirements/desktop_minesweeper_handoff.md` | Replace active-round Logout rejection and lock-owning round contract |
| `docs/agent/AGENT_WORKFLOW.md` | Explain the new link meaning without adding a live authority link or changing the decision table |

### Generate and verify, but expect no byte change

- `prompt_docs/INDEX.md`

### Explicitly unchanged

- `tools/docs/DocValidator.gd`
- `tools/docs/DocIndexGenerator.gd`
- `tools/docs/generate_index.gd`
- `tools/docs/validate_docs.gd`
- `tools/docs/AgentWorkflowValidator.gd`
- `Prompt.md`
- every file under `docs/design/current-ui/`
- every existing implementation plan except this newly authored UI-00 plan
- `.beads/issues.jsonl`
- all runtime, scene, asset, story, localization, and save files

---

## Stable Interface Contracts

### 1. `CurrentUiDossierProjector`

The projector is a validation boundary with two consumers: the authority resolver and the census checker. It is not a registry and owns no mutable status.

```text
class_name CurrentUiDossierProjector
extends RefCounted

const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
const CURRENT_UI_ROOT := "docs/design/current-ui"
const LEDGER_PATH := "docs/design/current-ui/README.md"
const APPROVED_ACCEPTANCE_PROJECTION_SHA256 := "38bb3f4a105671967aae65017165c23838e38863c0a4da0049218d5229d0bdb3"
const ID_PATTERN := "^canon\\.current_ui\\.[a-z0-9_]+$"

func project(repository_root: String = "res://") -> Dictionary

func _project_with_expected_projection_for_test(
	repository_root: String,
	expected_acceptance_projection_sha256: String,
) -> Dictionary

func _project(
	repository_root: String,
	expected_acceptance_projection_sha256: String,
) -> Dictionary
```

Every projector entry point returns exactly:

```text
source_valid: bool
ledger: {path, byte_length, actual_sha256, acceptance_projection_sha256, expected_acceptance_projection_sha256}
records: sorted Array[Dictionary]
errors: sorted Array[String]
```

Each record has exactly:

```text
family
id
path
byte_length
accepted_sha256
actual_sha256
structure_valid
lifecycle_approved
ledger_match
```

Validation rules:

1. Normalize the repository root once; reject ambiguous roots and every symlink or junction in the README/dossier path chain. `project()` always supplies the compiled accepted digest. `_project()` treats every expected digest unequal to that compiled value as a test override and, before reading source, rejects an empty `DWM_TEST_ROOT`, any expected digest outside lowercase 64-hex, a normalized root that is not a strict descendant of normalized `DWM_TEST_ROOT`, or a normalized root identical to `ProjectSettings.globalize_path("res://")`. The underscored fixture seam performs the same checks and calls `_project(repository_root, expected_acceptance_projection_sha256)`. There is no caller-controlled guard boolean, so direct or subclass access cannot substitute an alternate digest for the live repository even when `DWM_TEST_ROOT` is misbound above it.
2. The README must be one regular direct file at `LEDGER_PATH`, valid UTF-8 without BOM, LF-only, and final-LF. Record its current raw byte count/hash for evidence, but do not freeze its whole-file hash in production code: later separately reviewed lifecycle and provenance wording is allowed to evolve.
3. Parse rows only between exact headings `## Exact-writing acceptance ledger` and `## Non-negotiable gates`.
4. Require one exact five-cell header, one separator, and exactly five cells per data row. Each row requires a nonempty family, a safe direct-child `.md` link whose label equals target, one `canon.current_ui.*` ID, owner-approval text beginning with an ISO date and containing `owner explicitly`, a positive decimal byte count, the exact `UTF-8 without BOM; LF; raw and canonical-text SHA-256` wording with one lowercase 64-hex digest, and a nonempty authority-effect cell beginning `accepted exact writing;`.
5. Sort rows by ID using ordinal byte order and build exactly one UTF-8/no-BOM projection line per row: `id + TAB + "docs/design/current-ui/" + target + TAB + ungrouped decimal byte length + TAB + lowercase digest + LF`. Require the projection SHA-256 to equal `APPROVED_ACCEPTANCE_PROJECTION_SHA256`, or the expected digest admitted only through the guarded test seam. The current projection is 1,358 bytes and hashes to `38bb3f4a105671967aae65017165c23838e38863c0a4da0049218d5229d0bdb3`.
6. Enumerate only direct regular non-link `.md` files beside README. Ignore README as a dossier; any extra Markdown child or linked file/directory is a global source error.
7. Parse dossier frontmatter through `DocFrontmatter`. Required structural fields are `id`, `kind`, `schema_version`, `decision_status`, `conversational_design_status`, `written_spec_status`, `self_review_status`, `authority_effect`, `implementation_requested`, `implementation_authorized`, and `implementation_authorized_by_this_dossier`.
8. `lifecycle_approved` is true only for the exact typed tuple `kind == "canonical_ui_dossier"`, integer `schema_version == 1`, `decision_status == "accepted"`, `conversational_design_status == "approved"`, `written_spec_status == "approved"`, `self_review_status == "passed"`, `authority_effect == "nonbinding_until_accepted_repointed_and_machine_discoverable"`, and all three implementation booleans false. Missing/wrongly typed structural fields make `structure_valid: false`; a validly typed tuple with another lifecycle value remains structurally valid and makes `lifecycle_approved: false`.
9. Dossier bytes must be valid UTF-8 without BOM, LF-only, and final-LF. `actual_sha256` hashes exact bytes; do not normalize CRLF. A missing, linked, unreadable, invalidly encoded, or malformed dossier remains represented by its trusted ledger ID with `structure_valid: false` when that ID can be recovered.
10. Require matching filename/frontmatter ID and no duplicate path or ID. A trusted row with no dossier is a per-record structural failure; an extra dossier with no trusted row is a global topology failure. Complete success is therefore a ledger/dossier bijection. Do not hardcode a second ten-row list in production code; the accepted projection pins the bindings and the integration test pins the expected cohort.
11. A structurally valid dossier whose actual byte count/hash differs from its trusted ledger row remains identifiable with `ledger_match: false`; this is an unapproved byte drift, not malformed source. A changed ledger byte/hash/path/ID changes the acceptance projection and is a global source error.

`source_valid` reports only ledger/root/topology trust: normalized safe root, readable strict README, valid table grammar, accepted projection match, unique rows, and no extra dossier/link. Per-record missing/malformed dossier state is carried by `structure_valid`; lifecycle state by `lifecycle_approved`; byte agreement by `ledger_match`. The projector retains every lexically recoverable row and all duplicates long enough for resolver precedence. Resolver classification is frozen in this order: duplicate matching IDs → `AUTHORITY_LINK_DUPLICATE_TARGET`; global projector failure → `AUTHORITY_LINK_SOURCE_INVALID`; no matching trusted row → `AUTHORITY_LINK_UNKNOWN`; matching record structurally invalid → `AUTHORITY_LINK_SOURCE_INVALID`; lifecycle or dossier-byte mismatch → `AUTHORITY_LINK_UNAPPROVED`; otherwise success. Thus an unchanged ledger plus altered dossier bytes is `UNAPPROVED`, while an altered ledger binding is `SOURCE_INVALID`.

### 2. Resolver addition

The public addition is one enum value and one match branch:

```gdscript
const CURRENT_UI_PROJECTOR := preload("res://tools/docs/CurrentUiDossierProjector.gd")
const LINK_KINDS := [&"beads_issue", &"requirement_id", &"specification_id", &"decision_id", &"plan_path", &"canonical_ui_id"]

var _canonical_ui_result: Dictionary

func _resolve_canonical_ui(target: String) -> Dictionary:
	var records: Array = _canonical_ui_result.get("records", [])
	var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == target)
	if matches.size() > 1:
		return _failure(&"AUTHORITY_LINK_DUPLICATE_TARGET", {"kind":"canonical_ui_id", "target":target})
	if not _canonical_ui_result.get("source_valid", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"canonical_ui_id", "target":target, "errors":_canonical_ui_result.get("errors", [])})
	if matches.is_empty():
		return _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind":"canonical_ui_id", "target":target})
	var record: Dictionary = matches[0]
	if not record.get("structure_valid", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"canonical_ui_id", "target":target})
	if not record.get("lifecycle_approved", false) or not record.get("ledger_match", false):
		return _failure(&"AUTHORITY_LINK_UNAPPROVED", {"kind":"canonical_ui_id", "target":target})
	return _success(&"canonical_ui_id", target)
```

Duplicate ledger IDs must also map to `AUTHORITY_LINK_DUPLICATE_TARGET` before unrelated source-invalid diagnostics. The success envelope remains exactly `{kind,target}`; it does not expose a path, digest, permission, or cutover receipt.

### 3. Slice-scoped implementation-target admission

An admission remains an ordinary `design_specification` resolved through existing `specification_id` and `plan_path`. No new link kind exists.

The existing six projected specification fields remain globally required:

```text
id
conversational_design_status
written_spec_status
implementation_plan_path
implementation_plan_status
implementation_plan_sha256
```

Before a child plan exists, an approved admission uses exactly:

```text
implementation_plan_path: "docs/superpowers/plans/ui-01-settings-probe.md"
implementation_plan_status: not_authored
implementation_plan_sha256: not_authored
```

`not_authored` is the only permitted non-hash sentinel and is valid only when `implementation_plan_status == "not_authored"` and the prospective path is safe, under `docs/superpowers/plans/`, ends in `.md`, and does not exist. In this state `specification_id` may resolve but `plan_path` returns `AUTHORITY_LINK_UNKNOWN`. When the plan is approved, status changes to `approved`, the same path must exist as a regular non-link file, and the SHA field must be replaced by its lowercase 64-hex canonical-text digest. Every other status/hash/path combination is source-invalid.

Only a specification with exact top-level `implementation_target_admission: true` receives strict conditional validation of these additive fields:

| Field | Exact type and rule |
|---|---|
| `kind` | string `design_specification` |
| `schema_version` | integer `1` |
| `implementation_slice_id` | string matching `^ui-[0-9]{2}\.[a-z0-9][a-z0-9_.-]*$` |
| `implementation_target_dossiers` | nonempty inline-JSON array of `TargetRecord`; sorted by `id` |
| `implementation_current_authorities` | nonempty inline-JSON array of `AuthorityRecord`; sorted by `(authority_kind,target)` |
| `implementation_retained_authorities` | inline-JSON array of `AuthorityRecord`; sorted by `(authority_kind,target)` |
| `implementation_conflict_audit` | string `complete_no_unresolved_conflicts` |
| `implementation_conflict_resolutions` | inline-JSON array of `ConflictRecord`; sorted by `conflict_id` |
| `production_exposure_paths` | nonempty inline-JSON array of unique sorted safe repository-relative existing regular non-link file paths |
| `pre_cutover_exposure_must_remain_unchanged` | boolean `true` |
| `plan_authoring_scope` | nonempty inline-JSON array of unique sorted strings matching `^[a-z0-9][a-z0-9_.-]*$` |
| `plan_authoring_authorized` | boolean `true` after exact written-admission approval |
| `implementation_requested` | boolean, initially `false` |
| `implementation_authorized` | boolean, initially `false` |
| `implementation_commit_authorized` | boolean, independently `false` unless explicitly granted |

Every structured admission field is one physical frontmatter line containing strict JSON; do not add YAML block-array support to `DocFrontmatter`. Because conditional admissions receive a full `DocFrontmatter.parse_file()` pass, every date-like scalar in that specification—including `created_on` and later approval dates—must be a JSON-quoted string. The closed nested schemas are:

```text
ClauseRecord = {
  clause_key: string matching ^[a-z0-9][a-z0-9_.-]*$,
  heading: exact nonempty Markdown heading line,
  start_line: integer >= 1,
  end_line: integer >= start_line,
  section_sha256: lowercase 64-hex SHA-256
}

TargetRecord = {
  id: canon.current_ui.* string,
  path: safe repository-relative dossier path,
  sha256: lowercase 64-hex exact-byte SHA-256,
  clauses: nonempty Array[ClauseRecord] sorted by clause_key
}

AuthorityRecord = {
  authority_kind: one of requirement_id, specification_id, decision_id, design_document,
  target: nonempty stable target string,
  path: safe repository-relative regular non-link Markdown path,
  canonical_sha256: lowercase 64-hex canonical-text SHA-256,
  scope_ids: nonempty sorted unique Array[String] matching ^[a-z0-9][a-z0-9_.-]*$
}

ConflictRecord = {
  conflict_id: string matching ^conflict\.[a-z0-9][a-z0-9_.-]*$,
  target_id: one declared TargetRecord.id,
  target_clause_key: one ClauseRecord.clause_key under target_id,
  current_authority_kind: one declared current AuthorityRecord.authority_kind,
  current_authority_target: the paired declared current AuthorityRecord.target,
  resolution: nonempty single-line string without CR or LF
}
```

`design_document` is admission-local source validation, not a new public authority-link kind. Its `target` MUST match `^(spec|note|guide)\.[a-z0-9][a-z0-9_.-]*$`; its path MUST begin `docs/design/`, MUST NOT begin `docs/design/current-ui/`, and must end `.md`. Any `canon.current_ui.*` target or current-UI path is source-invalid and must be represented only by `TargetRecord` plus `canonical_ui_id`. The type exists only for a retained/current design authority whose exact frontmatter ID is absent from every public requirement, specification, and decision source projection. Any matching public-source record—approved, unapproved, malformed but lexically recoverable, duplicate, or otherwise invalid—makes `design_document` source-invalid; direct projection lookup decides this collision, not whether public `resolve()` succeeds. The path identifies one regular non-link file whose strict UTF-8 frontmatter contains exactly one scalar `id` equal to `target`. The file MUST be valid UTF-8 without BOM; canonical-text hashing normalizes CRLF and CR to LF before SHA-256. A duplicate matching ID anywhere under `docs/design/`, an absent/mismatched ID, unsafe path, linked path segment, invalid frontmatter, or digest drift makes the admission source-invalid. This local validation neither adds `design_document` to `LINK_KINDS` nor makes the target generally machine-discoverable, current, cut over, or executable.

For a `ClauseRecord`, `heading` must equal the line at `start_line`; the inclusive line slice is joined with LF and one final LF before `section_sha256` is computed. Clause keys, `(authority_kind,target)` pairs, conflict IDs, target paths, authority paths, exposure paths, and all sorted arrays must be unique. Authority canonical-text hashing rejects invalid UTF-8/BOM and normalizes CRLF/CR to LF, matching existing resolver plan hashing. A requirement authority path must contain the target requirement exactly once; specification and decision paths must expose the target as their unique parsed ID.

The conditional parser uses `DocFrontmatter.parse_file()` for these inline JSON values while the legacy six-field projection stays unchanged. It rejects extra or missing nested keys, unsorted arrays, unsafe paths, wrong types, nonexistent or linked files, hashes or section ranges that drift, and references outside the declared records. Every target ID/path/hash must match `CurrentUiDossierProjector`. Every `requirement_id`, `specification_id`, and `decision_id` authority target MUST resolve through its existing public link kind and match its declared path/hash. Every `design_document` authority target MUST pass the admission-local exact-ID/path/hash validation above. No validation path may call public `resolve()` recursively while `_spec_records` is being initialized. An empty conflict array is valid only with `implementation_conflict_audit: complete_no_unresolved_conflicts`; any discovered unresolved conflict makes the admission source-invalid.

Malformed admission structure, unsafe/missing paths, target drift, or undeclared conflict references make the matching specification and plan source-invalid. Nonapproved conversational/written status remains unapproved. `implementation_authorized: false` and `implementation_commit_authorized: false` must not make an accepted specification or exact approved plan unresolved; execution tooling checks those permissions separately.

### 4. Census evidence contract

`evidence/current_ui/authority/ui_00_consumer_census.v1.json` has an exact, closed top-level key set:

```text
schema_version
artifact_id
artifact_role
behavior_authority
cutover_authority
subject
scan_contract
accepted_subjects
dangling_source_identity_exceptions
reference_occurrences
requirement_reconciliations
protected_plan_bindings
cutover_gates
unresolved_references
```

Required fixed values are `schema_version: 1`, `artifact_id: evidence.current_ui.ui_00_consumer_census`, `artifact_role: audit_evidence`, `behavior_authority: false`, and `cutover_authority: false`.

`subject` has exactly these keys and binds the artifact to one reviewable state:

```text
implementation_base_commit
approved_plan_path
approved_plan_sha256
beads_snapshot_path
beads_snapshot_sha256
prompt_index_path
prompt_index_sha256
acceptance_projection_sha256
```

The two paths are fixed to `evidence/current_ui/authority/ui_00_beads_registration.v1.json` and `prompt_docs/INDEX.md`; hashes are lowercase 64-hex, the Git object ID is the exact full implementation-base ID, and the plan path/hash must equal the approved lifecycle binding. The Beads file is an immutable strict `bd list --status all --json --readonly` export captured after UI-00 registration. Closing the live issue later does not rewrite this evidence subject; the exit gate separately proves that the issue's title, description, metadata, and authority references still equal the captured record while allowing only its live status/closure fields to change.

`scan_contract` has exactly `roots`, `excluded_paths`, and `text_extensions` with these exact sorted values:

```json
{
  "roots": ["Prompt.md", "autoload", "docs", "evidence/current_ui/authority/ui_00_beads_registration.v1.json", "prompt_docs", "scenes", "scripts", "tests", "tools"],
  "excluded_paths": ["evidence/current_ui/authority/ui_00_consumer_census.v1.json", "evidence/current_ui/logs/isolated-godot.jsonl"],
  "text_extensions": [".gd", ".json", ".jsonl", ".md", ".tscn"]
}
```

Every root is required at the approved base: a root must be a regular non-link file or a recursively traversed regular non-link directory. Absence, a wrong type, or a symlink/junction anywhere in its chain is a validation failure; there are no optional roots. The checker never reads live `.beads/issues.jsonl`.

Each accepted-subject row has exact keys `canonical_ui_id`, `path`, `accepted_sha256`, `actual_sha256`, `byte_length`, `lifecycle_approved`, and `ledger_match`; rows equal the projector's frozen cohort and sort by `canonical_ui_id`, with both booleans true.

The checker derives the required per-family token set rather than trusting the artifact to enumerate it. For each accepted dossier, it begins with the dossier's own ID as `source_id` and repository path as `source_path`. It then reads the following source-ID/source-path field pairs when present:

```text
prospective_absorbs_if_all_gates_pass <-> prospective_absorbs_paths_if_all_gates_pass
prospective_retires_pending_if_all_gates_pass <-> prospective_retires_pending_paths_if_all_gates_pass
partial_imports_if_all_gates_pass <-> partial_imports_paths_if_all_gates_pass
partial_imports_after_valid_cutover <-> partial_imports_paths_after_valid_cutover
```

Every declared source path MUST be a safe repository-relative regular non-link Markdown file. For each paired source-ID/source-path field, both arrays MUST have equal length and agree positionally after strict path/ID validation. A path entry without a paired ID is normally invalid. There is exactly one frozen exception in `dangling_source_identity_exceptions`; it records a source path and a dangling reference token separately and MUST NOT treat the token as that source's ID, resolve it as authority, or add it to any authority-link namespace.

The artifact's `dangling_source_identity_exceptions` array and the checker's compiled expected tuple must both equal exactly this one row:

```json
{
  "canonical_ui_id": "canon.current_ui.witnessed_scene",
  "source_path": "docs/superpowers/specs/2026-08-21-room-owned-aperture-v1-design.md",
  "source_sha256": "fb87532e67150bc8867c78cdc5bae5587107a0caf9b23b85aefe2f49290f7082",
  "dangling_reference_token": "spec.room_owned_aperture_v1_design",
  "accepted_basis": {
    "dossier_path": "docs/design/current-ui/witnessed-scene.md",
    "dossier_sha256": "7b3ce28e0732e54c3227bf978bacd3e45a947f0393913784cfd34dfbc07f30b4",
    "heading": "### 1.1 Lifecycle reconciliation",
    "start_line": 108,
    "end_line": 117,
    "section_sha256": "681daa93c7143656eeacff2a235ba95a81aedafb7c2bb96ae146868639c52d19"
  },
  "effect": "replace_dangling_reference_without_inventing_source_identity"
}
```

This array is audit evidence mirroring an accepted clause, not a registry. The checker requires the Room-Owned Aperture source to be a 42,254-byte regular non-link strict UTF-8/no-BOM/LF/final-LF file with that exact raw digest and no YAML frontmatter block or parsed ID. It validates the exact accepted basis and requires line 115 to contain `R defines no YAML ID`, line 116 to contain the exact token plus `This successor must replace that`, and line 117 to contain `dangling identity rather than silently invent authority for R.` Any source drift, frontmatter/ID appearance, basis drift, missing token, changed exception field, omitted row, or additional exception is fail-closed.

Token inventory emits `{token_kind:"source_path", token:source_path}` and `{token_kind:"dangling_reference", token:dangling_reference_token}` for this exception; it emits no `source_id` token for Room-Owned Aperture. The dangling token is scanned so every occurrence receives a reviewed disposition, but it never becomes a source identity. Every other path without a paired ID is invalid.

`retained_external_implementation_authorization_provenance_id`, when present, is an additional exact `source_id` token. The checker resolves it to exactly one strict Markdown frontmatter ID under the required scan roots and adds that unique repository path as the paired `source_path` token; zero or multiple matches is invalid. Stable IDs are matched as exact tokens. Markdown links are resolved against their containing file and anchors are removed before repository-path comparison; bare full repository paths in all allowed text files are matched exactly. Overlapping matches use longest-token-first, then ordinal order. Derived tokens are lexical inventory inputs only and carry no semantic disposition or authority effect.

Each `reference_occurrences` row represents one exact token occurrence for one family and has exactly:

```text
canonical_ui_id
token_kind
source_token
consumer_path
line_number
match_ordinal
line_sha256
dispositions
scope
basis
```

`token_kind` is exactly one of `source_id`, `source_path`, or `dangling_reference`. `line_number` and `match_ordinal` are one-based integers; `line_sha256` hashes the exact UTF-8 line bytes without its delimiter. `dispositions` is a nonempty sorted unique subset of:

```text
repoint_after_valid_family_cutover
retain_living_owner
relabel_archive_provenance_after_valid_move
routing_or_census_reference
```

Multiple dispositions on one ordinary occurrence express a genuinely mixed scope without changing the row shape. A `dangling_reference` row MUST NOT use `retain_living_owner`, because the token identifies no authority. Its dispositions are a nonempty sorted subset of `repoint_after_valid_family_cutover`, `relabel_archive_provenance_after_valid_move`, and `routing_or_census_reference`, with each disposition supported by that occurrence's consumer-specific accepted basis. The compiled exception supplies and validates the Section 1.1 non-identity invariant for every dangling row. Each row's single `basis` supplies only its consumer-specific treatment: Section 1.4/20 for repoint or archive provenance, while Section 1.1 may itself be the row basis for explanatory routing/census mentions. A current target-architecture consumer uses repoint; a future archived-source consumer may use archive provenance; tooling, plan, census, or accepted explanatory mentions use routing/census. Its scope MUST contain the exact sentence `This token is a dangling reference, not Room-Owned Aperture's identity or authority.` Unsupported cases remain unresolved. `scope` is otherwise a nonempty single-line explanation. `basis` is one exact `BasisRecord`:

```text
BasisRecord = {
  dossier_path: accepted current-UI dossier path,
  dossier_sha256: that dossier's accepted exact-byte SHA-256,
  heading: exact nonempty Markdown heading line,
  start_line: integer >= 1 whose line equals heading,
  end_line: integer >= start_line,
  section_sha256: SHA-256 of the inclusive UTF-8 lines joined with LF and one final LF
}
```

Rows sort by `(canonical_ui_id, token_kind, source_token, consumer_path, line_number, match_ordinal)`. The checker discovers occurrences but never invents dispositions or scope. It requires a one-to-one set match between discovered occurrence keys and the union of classified plus unresolved rows, rejects a phantom/duplicate row, and verifies every semantic basis against exact accepted bytes.

Each `unresolved_references` row has exact keys `canonical_ui_id`, `token_kind`, `source_token`, `consumer_path`, `line_number`, `match_ordinal`, `line_sha256`, and `reason`, sorted by the same occurrence key. An unentailed or ambiguous classification stays here for owner resolution. UI-00 exit requires the array to be empty; the checker never clears it.

Each of the five `requirement_reconciliations` rows has exact keys `requirement_id`, `packet_path`, `body_sha256`, `accepted_basis`, and `status`; `accepted_basis` is a `BasisRecord`, `status` is `reconciled_in_ui_00`, and rows sort by requirement ID. `body_sha256` hashes the exact replacement paragraph's UTF-8 bytes plus one final LF.

Each `protected_plan_bindings` row has exact keys `specification_id`, `specification_path`, `plan_path`, `approved_canonical_sha256`, and `actual_canonical_sha256`, sorted by specification ID. The array equals every specification whose existing `implementation_plan_status` is `approved`; the checker rejects a missing, duplicate, malformed, linked, or drifted binding.

Each `cutover_gates` row has exact keys `id`, `path`, `observed_sha256`, `status`, and `effect`. The sole row is:

```json
{
  "id": "note.minesweeper_maintained_survey_worksheet_standard_palette_and_state_disposition",
  "path": "docs/design/2026-08-23-minesweeper-maintained-survey-worksheet-standard-palette-and-state-disposition.md",
  "observed_sha256": "b8a7f62f0202c82ac2114a9fedf171d7c5fc5fc5e33ce4cc9d8d49721a95027c",
  "status": "owner_approved_direction_exact_writing_pending_owner_review",
  "effect": "blocks_minesweeper_documentation_cutover_and_source_movement_without_promoting_general_authority"
}
```

The evidence file itself must be valid UTF-8 without BOM, LF-only, and final-LF. The checker strict-parses duplicate-free JSON with `EvidenceValidator`, rejects unknown/missing keys and noncanonical array ordering, recomputes every subject/hash/occurrence/basis, requires zero phantom or uncovered references, and never rewrites the artifact. PASS output is exactly one deterministic line containing accepted-subject, classified-occurrence, reconciliation, protected-plan, cutover-gate, unresolved counts, and the raw artifact SHA-256.

`CurrentUiConsumerCensus` exposes only:

```text
inventory(repository_root: String, scan_contract: Dictionary) -> {
  ok: bool,
  occurrences: sorted Array[Dictionary],
  errors: sorted Array[String]
}

validate(repository_root: String, artifact_path: String) -> {
  ok: bool,
  counts: {
    accepted_subjects: int,
    dangling_source_identity_exceptions: int,
    reference_occurrences: int,
    requirement_reconciliations: int,
    protected_plan_bindings: int,
    cutover_gates: int,
    unresolved_references: int
  },
  artifact_sha256: String,
  errors: sorted Array[String]
}
```

It is evidence tooling, not a registry or generator. The resolver never reads this evidence file.

---

## Requirement Reconciliation — Exact Replacement Text

All IDs, frontmatter arrays, dependencies, packet owners, and Beads bindings remain byte-identical. Replace only the named rule bodies.

### `req.invitation.solo`

> A solo invitation MUST remain unread until one explicit friend activation admits the exact delivered-sequence boundary containing it. That activation atomically opens the thread, marks entries through that boundary read, and accepts each admitted solo invitation exactly once, including one below the fold or not yet witnessed. Acceptance makes the date schedulable but does not schedule it. The invitation lifecycle MUST distinguish unread, accepted, and superseded state; it MUST NOT require a player reply, Accept/Decline control, confirmation, or witnessed presentation. At day resolution the single nevermind message MUST fire for every unaccepted, nonsuperseded solo offer and MUST NOT fire for an accepted or superseded offer.

### `req.invitation.group_resolution`

> The first participating contact explicitly opened for the exact group generation MUST fix `inviter_id` for presentation variation only. The linked invitation MUST expose one exact shared response action; its first valid commit accepts the group invitation and makes the group date schedulable exactly once while updating both participant projections atomically. Opening the second participant alone MUST NOT accept, reply, or mutate Schedule. A later response in the other projection MAY add only registered authored variation and MUST NOT accept or schedule again. The fixed inviter, shared acceptance receipt, and both projections MUST remain idempotent and race-safe across save/load, reopen, rapid activation, and concurrent attempts.

Do not change `req.invitation.group_activation`; its third-round and two-unread-offer eligibility remains deeper authority.

### `req.save.minesweeper_lock`

> A Minesweeper candidate, session, or board MUST NOT impose a lifetime active-board save lock or require board completion before saving. A Save, Home, app-switch, Logout, or focus-loss request MAY wait only for the currently admitted bounded command, replacement, generator, or journal slice to reach its stable frontier; it MUST then expose the latest exact stable canonical revision to the persistence owner. Manual and Quick Save at that frontier MUST preserve the exact candidate or board state and MUST NOT cause a result, forfeit, completion, replacement, cost, refund, or restoration of a whole pre-board snapshot. SaveManager and lifecycle owners retain storage, Autosave, journal, durability, failure, and recovery authority.

### `req.minesweeper.round_contract`

> The Minesweeper coordinator MUST expose exact validated stable candidate, session, and board revisions and apply exactly one validated domain result through injected ports. Save-capable owners MAY synchronize only with the current bounded stable frontier and snapshot its latest canonical revision; the coordinator MUST NOT impose a lifetime active-board save lock, require board completion, restore a whole pre-board snapshot when a later result applies, or take ownership of storage, journaling, durability, or recovery. Result application and any separately required post-result checkpoint MUST remain idempotent and receipt-bound.

### `req.desktop.logout`

> A confirmed Logout MUST NOT reject merely because a Minesweeper candidate, session, or board is active. It MAY wait only for the current admitted bounded slice to reach its stable frontier, MUST write the exact live continuation—including any active Minesweeper state—to Autosave, and MUST route through the validated return-to-menu lifecycle only after durability is proven. Persistence failure MUST remain in-run with truthful Retry and Cancel recovery. Cancel or No MUST neither save nor route, and Logout MUST NOT modify Quick or numbered records.

### Authority-context rule bodies

Replace the three existing bodies with:

**`req.docs.authority`**

> The approved Phase 2R specification, active requirement packets, frozen interface registry, and any uniquely resolved accepted canonical-UI dossier admitted by the selected approved specification MUST be the only sources of intended behavior for that selected work. Resolving `canonical_ui_id` proves only the exact accepted target bytes and digest; it does not repoint a consumer, cut over a family, transfer retained deeper ownership, authorize implementation, or make evidence authoritative. Until a valid family cutover, current predecessor design authorities and retained requirement/domain owners keep their declared scopes. Generated indexes, censuses, plans, evidence, and Beads MUST NOT redefine behavior.

**`req.docs.context_order`**

> An agent MUST load `Prompt.md`, Beads execution context, the selected active issue, its phase packet, referenced requirement packets, transitive requirement dependencies, and the generated index lookup in that order. When the selected issue cites UI implementation work, the agent MUST then load only its exact approved admission/specification, approved hash-bound plan, resolved `canonical_ui_id` targets, and named current/retained authorities. Unrelated UI dossiers MUST NOT become ambient authority.

**`req.docs.status_separation`**

> Requirement status, specification status, accepted-writing status, machine discoverability, consumer repoint/cutover status, implementation status, issue status, execution permission, commit permission, and verification evidence MUST remain separate fields and MUST NOT imply one another.

In `docs/agent/AGENT_WORKFLOW.md`, insert the following three lines immediately after the existing `Accepted decision` glossary line:

```markdown
- **Canonical UI dossier:** an owner-accepted exact-writing UI successor whose stable `canon.current_ui.*` ID and exact bytes may be discovered without making it current authority.
- **Machine discovery:** fail-closed resolution of one stable authority ID to its approved exact source; discovery proves identity and approval state only.
- **Cutover:** a separate authorized transaction that repoints named consumers to a successor authority after every required gate passes.
```

Insert this exact row immediately after the existing `What design was approved?` authority-map row:

```markdown
| Which accepted current-UI target bytes resolve uniquely? | A successfully resolved `canonical_ui_id` and its accepted current-UI dossier binding |
```

Insert this exact paragraph immediately after the complete approved-plan paragraph and before `## Decision table`:

```markdown
A successful `canonical_ui_id` resolution proves only that one accepted current-UI target has the expected stable ID and exact approved bytes. It does not repoint a consumer, cut over a family, transfer retained deeper ownership, authorize implementation or commit, make evidence authoritative, or permit source movement or archival.
```

Anchor each insertion by its exact neighboring text rather than an absolute line number. Do not add any live `authority_links`, change `Prompt.md`, or change the decision table.

---

## Shared Conditional Exact-Path Commit Procedure

Every task ends with a conditional boundary. Before staging:

1. Read `implementation_commit_authorized` and its exact scope from the owner-approved lifecycle/execution record.
2. Require an empty pre-existing index and the expected full parent commit.
3. Require only the task’s literal paths at their declared `A` or `M` status; generated `.uid` files are optional only beside their named script.
4. Run the task’s focused GREEN gate and `git diff --check --` against exactly those paths.
5. If commit permission is false, do not stage and record `verified_uncommitted`.
6. If true, call `tools/git/Invoke-ExactPathCommit.ps1` with the exact ordered path map, full expected parent, and task message. Never use broad `git add`.
7. Verify the created commit is the sole direct child and contains exactly the allowed paths. Never push.

The separately authorized custody commit contains only these eleven literal paths:

```text
docs/design/current-ui/README.md
docs/design/current-ui/backup.md
docs/design/current-ui/contacts.md
docs/design/current-ui/gallery.md
docs/design/current-ui/global-ui-grammar.md
docs/design/current-ui/minesweeper.md
docs/design/current-ui/schedule.md
docs/design/current-ui/settings.md
docs/design/current-ui/shared-shell.md
docs/design/current-ui/shop.md
docs/design/current-ui/witnessed-scene.md
```

It must prove the exact hashes above, and its message is `docs: install accepted current ui custody cohort`. It performs no discovery, cutover, implementation, source movement, or archival.

For every authorized commit, `$boundaryAllowedDirtyPaths` is the exact set of non-task paths that the execution grant or the immediately preceding verified boundary receipt authorizes to remain dirty after that commit. A later boundary may remove paths after they are committed, but it never adds a path merely because current status reports it. The isolated JSONL is prospectively authorized as generated retained-dirty evidence only when the execution grant says so; add it only after it exists and only when the current commit map does not itself contain it. Set the helper's required environment guard only for the duration of one invocation:

```powershell
$expectedHead = (git rev-parse HEAD).Trim()
$generatedLogPath = 'evidence/current_ui/logs/isolated-godot.jsonl'
$allowedDirtyPaths = @($boundaryAllowedDirtyPaths | Sort-Object -Unique)
if ($required.Contains($generatedLogPath)) {
  $allowedDirtyPaths = @($allowedDirtyPaths | Where-Object { $_ -cne $generatedLogPath })
} elseif (Test-Path -LiteralPath $generatedLogPath -PathType Leaf) {
  $allowedDirtyPaths = @(@($allowedDirtyPaths) + @($generatedLogPath) | Sort-Object -Unique)
}
$env:DWM_COMMIT_AUTHORIZED = '1'
try {
  & .\tools\git\Invoke-ExactPathCommit.ps1 `
    -RequiredStatus $required `
    -OptionalPresentStatus $optional `
    -AllowedDirtyPaths $allowedDirtyPaths `
    -ExpectedHead $expectedHead `
    -RequireRemainingDirtyExact `
    -Message $message
} finally {
  Remove-Item Env:DWM_COMMIT_AUTHORIZED -ErrorAction SilentlyContinue
}
```

Before invoking the helper, compare the actual remaining non-task dirty set with `$allowedDirtyPaths` and stop on any difference. Task 5 removes the JSONL from the retained-dirty set only when its separately authorized exact-path evidence commit is being made.

Use exactly one of these ordered task maps with that invocation; an optional UID is admitted only when Godot generated that exact adjacent file:

```powershell
# Task 1
$required = [ordered]@{
  'tools/docs/CurrentUiDossierProjector.gd' = 'A'
  'tests/unit/tooling/test_current_ui_dossier_projector.gd' = 'A'
  'evidence/current_ui/logs/.gitkeep' = 'A'
}
$optional = [ordered]@{
  'tools/docs/CurrentUiDossierProjector.gd.uid' = 'A'
  'tests/unit/tooling/test_current_ui_dossier_projector.gd.uid' = 'A'
}
$message = 'feat(docs): validate accepted current ui dossier custody'

# Task 2
$required = [ordered]@{
  'tools/docs/AgentWorkflowAuthorityResolver.gd' = 'M'
  'tests/unit/tooling/test_agent_workflow_authority_resolver.gd' = 'M'
  'tests/unit/tooling/test_agent_workflow_validator.gd' = 'M'
}
$optional = [ordered]@{}
$message = 'feat(docs): resolve current ui and slice admission links'

# Task 3
$required = [ordered]@{
  'tests/unit/tooling/test_current_ui_requirement_reconciliation.gd' = 'A'
  'prompt_docs/requirements/authority_context.md' = 'M'
  'prompt_docs/requirements/contacts_invitations.md' = 'M'
  'prompt_docs/requirements/persistence.md' = 'M'
  'prompt_docs/requirements/desktop_minesweeper_handoff.md' = 'M'
  'docs/agent/AGENT_WORKFLOW.md' = 'M'
}
$optional = [ordered]@{
  'tests/unit/tooling/test_current_ui_requirement_reconciliation.gd.uid' = 'A'
}
$message = 'docs: reconcile current ui authority requirements'

# Task 4
$required = [ordered]@{
  'tools/evidence/CurrentUiConsumerCensus.gd' = 'A'
  'tools/evidence/validate_current_ui_consumer_census.gd' = 'A'
  'tests/unit/tooling/test_current_ui_consumer_census.gd' = 'A'
  'evidence/current_ui/authority/ui_00_beads_registration.v1.json' = 'A'
  'evidence/current_ui/authority/ui_00_consumer_census.v1.json' = 'A'
}
$optional = [ordered]@{
  'tools/evidence/CurrentUiConsumerCensus.gd.uid' = 'A'
  'tools/evidence/validate_current_ui_consumer_census.gd.uid' = 'A'
  'tests/unit/tooling/test_current_ui_consumer_census.gd.uid' = 'A'
}
$message = 'test(docs): validate current ui consumer custody'

# Task 5 optional log evidence
$required = [ordered]@{
  'evidence/current_ui/logs/isolated-godot.jsonl' = 'A'
}
$optional = [ordered]@{}
$message = 'docs: record ui00 authority readiness evidence'
```

The separately authorized proposal-base transaction uses required `A` paths `docs/superpowers/specs/2026-08-30-current-ui-incremental-implementation-roadmap-design.md` and `docs/superpowers/plans/2026-08-30-current-ui-00-authority-readiness.md`, after exact plan approval is lifecycle-bound, with message `docs: bind current ui incremental roadmap`. The custody transaction uses the eleven `A` paths printed above. Both use the same helper and independent permission; neither is smuggled into a UI-00 task commit.

---

### Task 0: Revalidate Every Entry Gate

**Files:**

- Read-only; create no repository file.

**Interfaces:**

- Consumes: owner-countersigned README/canonical acceptance projection, owner-approved exact plan lifecycle binding, actual registered UI-00 Beads issue, tracked implementation-base commit, and existing documentation tools.
- Produces: one fail-closed preflight result plus `.godot/beads/ui00-all.json`; no repository interface or authored file.

- [ ] **Step 1: Verify exact plan approval.** Run this PowerShell 5.1-compatible check; then compare the separate execution grant to the same digest rather than treating the approved spec as execution permission.

  ```powershell
  $planPath = 'docs/superpowers/plans/2026-08-30-current-ui-00-authority-readiness.md'
  $specPath = 'docs/superpowers/specs/2026-08-30-current-ui-incremental-implementation-roadmap-design.md'
  $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
  $planBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $planPath))
  if ($planBytes.Length -ge 3 -and $planBytes[0] -eq 0xEF -and $planBytes[1] -eq 0xBB -and $planBytes[2] -eq 0xBF) { throw 'UI00_PLAN_BOM' }
  $canonicalPlan = $strictUtf8.GetString($planBytes).Replace("`r`n", "`n").Replace("`r", "`n")
  $sha = [Security.Cryptography.SHA256]::Create()
  $planDigest = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonicalPlan)))).Replace('-', '').ToLowerInvariant()
  $specText = $strictUtf8.GetString([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $specPath)))
  $pathMatch = [regex]::Match($specText, '(?m)^implementation_plan_path: "([^"]+)"$')
  $statusMatch = [regex]::Match($specText, '(?m)^implementation_plan_status: approved$')
  $digestMatch = [regex]::Match($specText, '(?m)^implementation_plan_sha256: "?([0-9a-f]{64})"?$')
  if (-not $pathMatch.Success -or $pathMatch.Groups[1].Value -cne $planPath) { throw 'UI00_PLAN_PATH_NOT_APPROVED' }
  if (-not $statusMatch.Success) { throw 'UI00_PLAN_STATUS_NOT_APPROVED' }
  if (-not $digestMatch.Success -or $digestMatch.Groups[1].Value -cne $planDigest) { throw 'UI00_PLAN_DIGEST_NOT_APPROVED' }
  $planDigest
  ```

  Expected: one lowercase digest equal to the owner-approved lifecycle binding; any thrown marker stops.
- [ ] **Step 2: Verify implementation base and worktree scope.** Run the exact read-only capture below, compute the status fingerprint, and compare `$implementationBase` plus every named path with the execution grant. Stop on any overlapping mutation.

  ```powershell
  $implementationBase = (git rev-parse HEAD).Trim()
  $branch = (git branch --show-current).Trim()
  $statusText = (@(git status --short) -join "`n") + "`n"
  $staged = @(git diff --cached --name-status)
  $sha = [Security.Cryptography.SHA256]::Create()
  $statusSha256 = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($statusText)))).Replace('-', '').ToLowerInvariant()
  [pscustomobject]@{ Head = $implementationBase; Branch = $branch; StatusSha256 = $statusSha256; Staged = $staged }
  ```

  Expected: full HEAD and fingerprint equal the grant, an empty staged set, and no mutation overlapping any Create/Modify path in this plan.
- [ ] **Step 3: Verify the eleven custody inputs.** Use the following exact expected map and reject a missing tracked blob, invalid UTF-8, BOM, CR byte, missing final LF, byte-count mismatch, or raw digest mismatch.

  ```powershell
  $expected = [ordered]@{
    'docs/design/current-ui/README.md' = @(28664, 'eff07ec5026dfb76f18d106beadab3d8aa1e8dadf76fa3e32acac2adccbc0185')
    'docs/design/current-ui/backup.md' = @(121824, '1da253e262d996234208e2c95a1096a518ff1a19d02b8a1b85f185f9350da78d')
    'docs/design/current-ui/contacts.md' = @(63778, '4739b83c1260a9c9c48b90bc2ad92fc6a163a88fe10262914e7ef0e90f9395bb')
    'docs/design/current-ui/gallery.md' = @(93975, '7fbc858566a6d9317f857e94bdf5f6ca889188d8b0132dab86585c25e1f04c11')
    'docs/design/current-ui/global-ui-grammar.md' = @(94529, '4c2dba5908c854e6972df608ef45c9bbe31654d3bc81ba18f22259a720cabecf')
    'docs/design/current-ui/minesweeper.md' = @(117037, '20c4319ded61b8ce7474c5ad84414c3a7b46f3fc9bf567c6491a041271ec6430')
    'docs/design/current-ui/schedule.md' = @(98224, '7183b9323908e9b10eab5d9192dfc567f5fe1d10b170c1c5eb53e23679539180')
    'docs/design/current-ui/settings.md' = @(108168, 'f8877f892aee62a3d5f3ba5618def2fe5b751508aa4a7e5da11d1c8459b1fa51')
    'docs/design/current-ui/shared-shell.md' = @(123247, '232af85acee85bb69b58cdff1c42cb755ab0d821b90866ca2f6c026126824d71')
    'docs/design/current-ui/shop.md' = @(109665, '6c10286dcc90fae48f4a50fbb83860c35ad97c0d02692b2c0af42e83ba69641e')
    'docs/design/current-ui/witnessed-scene.md' = @(129386, '7b3ce28e0732e54c3227bf978bacd3e45a947f0393913784cfd34dfbc07f30b4')
  }
  $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
  foreach ($entry in $expected.GetEnumerator()) {
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $entry.Key))
    $null = $strictUtf8.GetString($bytes)
    $actualHash = (Get-FileHash -LiteralPath $entry.Key -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($bytes.Length -ne $entry.Value[0] -or $actualHash -cne $entry.Value[1]) { throw "UI00_CUSTODY_DRIFT: $($entry.Key)" }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw "UI00_CUSTODY_BOM: $($entry.Key)" }
    if (@($bytes | Where-Object { $_ -eq 13 }).Count -ne 0 -or $bytes[-1] -ne 10) { throw "UI00_CUSTODY_LINE_ENDING: $($entry.Key)" }
    $workingBlob = @(git hash-object --no-filters -- $entry.Key)
    if ($LASTEXITCODE -ne 0 -or $workingBlob.Count -ne 1) { throw "UI00_WORKTREE_BLOB_HASH_FAILED: $($entry.Key)" }
    $workingBlobId = ([string]$workingBlob[0]).Trim()
    $baseSpec = "$implementationBase`:$($entry.Key)"
    $baseBlob = @(git rev-parse --verify $baseSpec)
    if ($LASTEXITCODE -ne 0 -or $baseBlob.Count -ne 1) { throw "UI00_CUSTODY_NOT_TRACKED_AT_BASE: $($entry.Key)" }
    $baseBlobId = ([string]$baseBlob[0]).Trim()
    if ($baseBlobId -cne $workingBlobId) { throw "UI00_CUSTODY_BASE_BYTES_DIFFER: $($entry.Key)" }
    $baseType = @(git cat-file -t $baseBlobId)
    if ($LASTEXITCODE -ne 0 -or $baseType.Count -ne 1 -or ([string]$baseType[0]).Trim() -cne 'blob') { throw "UI00_CUSTODY_BASE_NOT_BLOB: $($entry.Key)" }
  }
  ```

  Expected: no output except Git diagnostics on failure.
- [ ] **Step 4: Capture protected plan bindings.** Run this exact PowerShell 5.1-compatible discovery and projection. It strict-reads every specification with exact approved plan status, validates unique frontmatter fields, rejects links and path escapes, recomputes canonical-text digests, and retains the sorted rows in `$protectedPlanRows` for Task 4:

  ```powershell
  function Assert-Ui00RegularRepositoryFile {
    param(
      [Parameter(Mandatory = $true)][string]$RepositoryRoot,
      [Parameter(Mandatory = $true)][string]$RelativePath
    )
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -cne $RelativePath.Replace('\', '/') -or $RelativePath -match '(^|/)\.\.?(/|$)' -or $RelativePath.Contains(':')) { throw "UI00_UNSAFE_REPOSITORY_PATH: $RelativePath" }
    $absoluteRoot = [IO.Path]::GetFullPath($RepositoryRoot)
    if (([IO.File]::GetAttributes($absoluteRoot) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'UI00_REPOSITORY_ROOT_LINK' }
    $current = $absoluteRoot
    foreach ($segment in $RelativePath.Split('/')) {
      if ([string]::IsNullOrWhiteSpace($segment)) { throw "UI00_EMPTY_PATH_SEGMENT: $RelativePath" }
      $current = Join-Path $current $segment
      if (-not (Test-Path -LiteralPath $current)) { throw "UI00_PATH_MISSING: $RelativePath" }
      if (([IO.File]::GetAttributes($current) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "UI00_PATH_LINK: $RelativePath" }
    }
    if (-not (Test-Path -LiteralPath $current -PathType Leaf)) { throw "UI00_PATH_NOT_FILE: $RelativePath" }
    $absolute = [IO.Path]::GetFullPath($current)
    $prefix = $absoluteRoot.TrimEnd([char[]]@('\', '/')) + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "UI00_PATH_ESCAPE: $RelativePath" }
    return $absolute
  }

  function Read-Ui00StrictUtf8 {
    param([Parameter(Mandatory = $true)][string]$AbsolutePath)
    $bytes = [IO.File]::ReadAllBytes($AbsolutePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { throw "UI00_TEXT_BOM: $AbsolutePath" }
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    try { return $strictUtf8.GetString($bytes) } catch { throw "UI00_TEXT_UTF8: $AbsolutePath" }
  }

  $repositoryRoot = (Resolve-Path -LiteralPath '.').Path
  $specPaths = @(rg -l '^implementation_plan_status: approved$' docs/superpowers/specs | ForEach-Object { $_.Replace('\', '/') } | Sort-Object)
  if ($LASTEXITCODE -ne 0 -or $specPaths.Count -eq 0) { throw 'UI00_APPROVED_PLAN_DISCOVERY_EMPTY' }
  $protectedPlanRows = @()
  foreach ($specPath in $specPaths) {
    $specAbsolute = Assert-Ui00RegularRepositoryFile -RepositoryRoot $repositoryRoot -RelativePath $specPath
    $specText = (Read-Ui00StrictUtf8 -AbsolutePath $specAbsolute).Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = $specText.Split("`n")
    if ($lines.Count -lt 3 -or $lines[0] -cne '---') { throw "UI00_SPEC_FRONTMATTER_OPEN: $specPath" }
    $closing = -1
    for ($index = 1; $index -lt $lines.Count; $index++) { if ($lines[$index] -ceq '---') { $closing = $index; break } }
    if ($closing -lt 2) { throw "UI00_SPEC_FRONTMATTER_CLOSE: $specPath" }
    $front = @($lines[1..($closing - 1)])
    $idLines = @($front | Where-Object { $_ -cmatch '^id:[ \t]*' })
    $statusLines = @($front | Where-Object { $_ -cmatch '^implementation_plan_status:[ \t]*' })
    $pathLines = @($front | Where-Object { $_ -cmatch '^implementation_plan_path:[ \t]*' })
    $hashLines = @($front | Where-Object { $_ -cmatch '^implementation_plan_sha256:[ \t]*' })
    if ($idLines.Count -ne 1 -or $statusLines.Count -ne 1 -or $pathLines.Count -ne 1 -or $hashLines.Count -ne 1) { throw "UI00_SPEC_PLAN_FIELDS: $specPath" }
    $idMatch = [regex]::Match($idLines[0], '^id:[ \t]*([A-Za-z0-9_.-]+)$')
    $pathMatch = [regex]::Match($pathLines[0], '^implementation_plan_path:[ \t]*"([^"]+)"$')
    $hashMatch = [regex]::Match($hashLines[0], '^implementation_plan_sha256:[ \t]*"?([0-9a-f]{64})"?$')
    if (-not $idMatch.Success -or $statusLines[0] -cne 'implementation_plan_status: approved' -or -not $pathMatch.Success -or -not $hashMatch.Success) { throw "UI00_SPEC_PLAN_FIELD_VALUE: $specPath" }
    $planPath = $pathMatch.Groups[1].Value
    if (-not $planPath.StartsWith('docs/superpowers/plans/', [StringComparison]::Ordinal) -or -not $planPath.EndsWith('.md', [StringComparison]::Ordinal)) { throw "UI00_PLAN_PATH_SCOPE: $planPath" }
    $planAbsolute = Assert-Ui00RegularRepositoryFile -RepositoryRoot $repositoryRoot -RelativePath $planPath
    $canonicalPlan = (Read-Ui00StrictUtf8 -AbsolutePath $planAbsolute).Replace("`r`n", "`n").Replace("`r", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    $actualDigest = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonicalPlan)))).Replace('-', '').ToLowerInvariant()
    if ($actualDigest -cne $hashMatch.Groups[1].Value) { throw "UI00_APPROVED_PLAN_DRIFT: $planPath" }
    $protectedPlanRows += [pscustomobject]@{ specification_id = $idMatch.Groups[1].Value; specification_path = $specPath; plan_path = $planPath; approved_canonical_sha256 = $hashMatch.Groups[1].Value; actual_canonical_sha256 = $actualDigest }
  }
  $protectedPlanRows = @($protectedPlanRows | Sort-Object specification_id)
  if (@($protectedPlanRows.specification_id | Sort-Object -Unique).Count -ne $protectedPlanRows.Count -or @($protectedPlanRows.plan_path | Sort-Object -Unique).Count -ne $protectedPlanRows.Count) { throw 'UI00_APPROVED_PLAN_BINDING_DUPLICATE' }
  $protectedPlanRows | ConvertTo-Json -Depth 4 -Compress
  ```

  Expected: one deterministic sorted JSON projection; zero matches or any malformed, linked, escaped, duplicated, or drifted binding stops.
- [ ] **Step 5: Capture the collision and inbound-reference preflight.** Strict-parse the ten acceptance rows using the grammar in this plan, require ten unique IDs and paths, rebuild the 1,358-byte sorted projection, and require SHA-256 `38bb3f4a105671967aae65017165c23838e38863c0a4da0049218d5229d0bdb3`. Then run this read-only broad inventory and preserve its exact output with the entry evidence:

  ```powershell
  rg -n --no-heading -e 'canon\.current_ui\.' -e 'docs/design/current-ui/' -e 'current-ui/' Prompt.md autoload docs prompt_docs scenes scripts tests tools .beads/issues.jsonl
  ```

  Expected: a reviewable preliminary path/ID occurrence set and no duplicate accepted binding. This is entry evidence, not the final semantic census; ambiguity stops rather than being classified by inference.
- [ ] **Step 6: Verify Beads and export one fresh snapshot.** Run these commands; derive the real ID from the strict export instead of substituting a roadmap label.

  ```powershell
  bd prime
  bd list --status all --json --readonly
  bd ready --json --readonly
  & .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/ui00-all.json'
  $issues = @(Get-Content -Raw -LiteralPath '.godot/beads/ui00-all.json' | ConvertFrom-Json)
  $matches = @($issues | Where-Object { $_.title -ceq 'UI-00 — Current UI authority readiness' })
  if ($matches.Count -ne 1) { throw "UI00_BEADS_ISSUE_COUNT: $($matches.Count)" }
  $ui00IssueId = [string]$matches[0].id
  bd show $ui00IssueId --json --readonly
  ```

  Expected: database/queries/export succeed; one actual issue's scope, exclusions, roadmap path, approved plan digest, and permission state equal the registration grant. A missing database, missing/duplicate issue, or stale binding stops.
- [ ] **Step 7: Verify baseline documentation.** Use the fresh snapshot and the existing runner; Task 0 writes its command record beneath allowed `.godot`, not the not-yet-created current-UI evidence directory.

  ```powershell
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-baseline-resolver' -LogName 'ui00-baseline-resolver.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_agent_workflow_authority_resolver.gd,res://tests/unit/tooling/test_agent_workflow_validator.gd','-gexit') -EvidenceLogPath '.godot/ui00-preflight.jsonl'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-baseline-docs' -LogName 'ui00-baseline-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/ui00-all.json') -EvidenceLogPath '.godot/ui00-preflight.jsonl'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-baseline-workflow' -LogName 'ui00-baseline-workflow.log' -GodotArgs @('-s','res://tools/docs/validate_agent_workflow.gd','--','--beads-snapshot=res://.godot/beads/ui00-all.json') -EvidenceLogPath '.godot/ui00-preflight.jsonl'
  ```

  Expected: all three exit zero. Fingerprint unrelated failures without repairing them; any failure touching UI-00 paths or authority resolution stops.
- [ ] **Step 8: Confirm no commit.** Task 0 is read-only and has no commit boundary.

Expected outcome: all entry gates pass against one identified tracked base. The proposal-time worktree described above does not currently satisfy Steps 3 or 6.

---

### Task 1: Build the Exact Current-UI Dossier Projector

**Files:**

- Create: `tools/docs/CurrentUiDossierProjector.gd`
- Create: `tests/unit/tooling/test_current_ui_dossier_projector.gd`
- Create: `evidence/current_ui/logs/.gitkeep`

**Interfaces:**

- Consumes: `DocFrontmatter.parse_file(path: String) -> Dictionary`, the countersigned acceptance-projection digest, and strict repository-path/link checks patterned after `AgentWorkflowAuthorityResolver`.
- Produces: `CurrentUiDossierProjector.project(repository_root: String = "res://") -> Dictionary` with the exact envelope and records frozen in “Stable Interface Contracts”; its only production path binds the compiled accepted projection digest.

- [ ] **Step 1: Create the evidence parent and a loadable projector seam.** Add `evidence/current_ui/logs/.gitkeep` with `apply_patch` containing exactly one LF byte (raw SHA-256 `01ba4719c80b6fe911b091a7c05124b64eeece964e09c058ef8f9805daca546b`), then create this compiling seam so RED is behavioral rather than a missing-script failure:

  ```gdscript
  class_name CurrentUiDossierProjector
  extends RefCounted

  const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
  const CURRENT_UI_ROOT := "docs/design/current-ui"
  const LEDGER_PATH := "docs/design/current-ui/README.md"
  const APPROVED_ACCEPTANCE_PROJECTION_SHA256 := "38bb3f4a105671967aae65017165c23838e38863c0a4da0049218d5229d0bdb3"
  const ID_PATTERN := "^canon\\.current_ui\\.[a-z0-9_]+$"

  func project(repository_root: String = "res://") -> Dictionary:
      return _project(repository_root, APPROVED_ACCEPTANCE_PROJECTION_SHA256)

  func _project_with_expected_projection_for_test(
      repository_root: String,
      expected_acceptance_projection_sha256: String,
  ) -> Dictionary:
      return _project(repository_root, expected_acceptance_projection_sha256)

  func _project(
      repository_root: String,
      expected_acceptance_projection_sha256: String,
  ) -> Dictionary:
      return {
          "source_valid": false,
          "ledger": {},
          "records": [],
          "errors": ["CURRENT_UI_PROJECTOR_NOT_IMPLEMENTED"],
      }
  ```
- [ ] **Step 2: Write the first fixture contract.** Create one temporary repository with one exact five-cell ledger row and one accepted dossier. Compute the fixture acceptance projection with the production line grammar, inject its digest, and add these exact assertions:

  ```gdscript
  class TestProjector extends CurrentUiDossierProjector:
      func project_fixture(repository_root: String, expected_sha256: String) -> Dictionary:
          return _project_with_expected_projection_for_test(repository_root, expected_sha256)

  func test_projects_one_exact_accepted_binding() -> void:
      var fixture := _fixture_with_one_accepted_dossier()
      var result: Dictionary = TestProjector.new().project_fixture(fixture.root, fixture.projection_sha256)
      assert_true(result.source_valid, JSON.stringify(result.errors))
      var result_keys: Array = result.keys()
      result_keys.sort()
      assert_eq(result_keys, ["errors", "ledger", "records", "source_valid"])
      assert_eq(result.records.size(), 1)
      assert_eq(result.records[0].id, "canon.current_ui.sample")
      assert_eq(result.records[0].path, "docs/design/current-ui/sample.md")
      assert_true(result.records[0].structure_valid)
      assert_true(result.records[0].lifecycle_approved)
      assert_true(result.records[0].ledger_match)
      assert_eq(result.ledger.acceptance_projection_sha256, fixture.projection_sha256)
  ```

  `_fixture_with_one_accepted_dossier()` must create its repository root as a strict descendant of nonempty `DWM_TEST_ROOT`, write strict UTF-8/LF bytes through the existing `_write` pattern, and return exact keys `root` and `projection_sha256`. Envelope key order is noncontractual; sort the returned key array before comparison as shown.

  - [ ] Create the fixture root as a strict descendant of nonempty `DWM_TEST_ROOT`.
  - [ ] Write the minimal strict README boundaries, header, separator, and one five-cell row.
  - [ ] Write the matching strict accepted `sample.md` dossier bytes.
  - [ ] Implement the fixture-only production-line projection helper.
  - [ ] Hash the fixture projection and return exactly `root` plus `projection_sha256`.
  - [ ] Add `TestProjector` with only the guarded fixture-seam delegation shown above.
  - [ ] Add the result-envelope and one-record-count assertions.
  - [ ] Add the exact ID/path and three independent record-state assertions.
  - [ ] Add the projected-ledger-digest equality assertion.
  - [ ] Run the Step 10 command at this point and require only the named contract to reach the behavioral `CURRENT_UI_PROJECTOR_NOT_IMPLEMENTED` failure.
- [ ] **Step 3: Add one reusable mutation assertion.** Add this fixture helper; every table case creates a fresh root, applies one mutation, and proves the expected stable prefix rather than merely checking any failure:

  ```gdscript
  func _assert_projector_mutation_fails(mutate: Callable, expected_prefix: String) -> void:
      var fixture := _fixture_with_one_accepted_dossier()
      mutate.call(fixture)
      var result: Dictionary = TestProjector.new().project_fixture(fixture.root, fixture.projection_sha256)
      assert_false(result.source_valid)
      assert_true(result.errors.any(
          func(error: Variant) -> bool: return str(error).begins_with(expected_prefix)
      ), JSON.stringify(result.errors))
  ```
- [ ] **Step 4: Add strict README encoding and grammar cases.** Implement `test_missing_or_invalid_ledger_is_global_source_invalid()` with one case row per missing file, invalid UTF-8, BOM, CRLF, no final LF, wrong boundary heading, wrong header, wrong separator, and wrong cell count. Each row supplies `name`, `mutate: Callable`, and exact `expected_prefix`; loop through `_assert_projector_mutation_fails` and include the case name in assertion messages.

  - [ ] Add the missing-ledger-file row with its exact error prefix.
  - [ ] Add the invalid-UTF-8 row with its exact error prefix.
  - [ ] Add the BOM row with its exact error prefix.
  - [ ] Add the CRLF row with its exact error prefix.
  - [ ] Add the missing-final-LF row with its exact error prefix.
  - [ ] Add the missing-boundary-heading row with its exact error prefix.
  - [ ] Add the duplicated-boundary-heading row with its exact error prefix.
  - [ ] Add the misspelled-boundary-heading row with its exact error prefix.
  - [ ] Add the wrong-header row with its exact error prefix.
  - [ ] Add the wrong-separator row with its exact error prefix.
  - [ ] Add the wrong-cell-count row with its exact error prefix.
  - [ ] Run this case table and require every named row to reach `_assert_projector_mutation_fails`.
- [ ] **Step 5: Add projection and duplicate cases.** Implement `test_projection_drift_is_global_source_invalid()` for changed ID, path, byte count, and digest. Implement `test_duplicate_rows_are_retained_for_precedence()` separately for duplicate ID and duplicate path; assert global invalidity plus the retained lexically recoverable rows needed by resolver precedence.

  - [ ] Add the changed-ledger-ID projection row.
  - [ ] Add the changed-ledger-path projection row.
  - [ ] Add the changed-byte-count projection row.
  - [ ] Add the changed-digest projection row.
  - [ ] Add the duplicate-ID retention row.
  - [ ] Add the duplicate-path retention row.
  - [ ] Run the projection/duplicate tests and require every lexically recoverable duplicate row to remain observable.
- [ ] **Step 6: Add byte and lifecycle cases.** Implement `test_dossier_byte_drift_is_record_unapproved()` and `test_lifecycle_drift_is_record_unapproved()`. The first requires global validity plus `structure_valid == true` and `ledger_match == false`; the second mutates each accepted tuple field independently and requires `lifecycle_approved == false` without changing structural validity.

  - [ ] Add and run the dossier-byte-drift control case.
  - [ ] Add and run the `kind` lifecycle mutation row.
  - [ ] Add and run the `schema_version` lifecycle mutation row.
  - [ ] Add and run the `decision_status` lifecycle mutation row.
  - [ ] Add and run the `conversational_design_status` lifecycle mutation row.
  - [ ] Add and run the `written_spec_status` lifecycle mutation row.
  - [ ] Add and run the `self_review_status` lifecycle mutation row.
  - [ ] Add and run the `authority_effect` lifecycle mutation row.
  - [ ] Add and run the `implementation_requested` lifecycle mutation row.
  - [ ] Add and run the `implementation_authorized` lifecycle mutation row.
  - [ ] Add and run the `implementation_authorized_by_this_dossier` lifecycle mutation row.
- [ ] **Step 7: Add malformed-dossier cases.** Implement `test_malformed_dossier_is_record_source_invalid()` with one independent row for invalid UTF-8, BOM, CRLF, no final LF, unterminated frontmatter, wrong required type, filename/ID mismatch, and missing file; every trusted matching record remains present with `structure_valid == false`.

  - [ ] Add and run the invalid-UTF-8 dossier row.
  - [ ] Add and run the BOM dossier row.
  - [ ] Add and run the CRLF dossier row.
  - [ ] Add and run the missing-final-LF dossier row.
  - [ ] Add and run the unterminated-frontmatter row.
  - [ ] Add and run the wrong-required-type row.
  - [ ] Add and run the filename/ID-mismatch row.
  - [ ] Add and run the missing-dossier-file row.
  - [ ] Require every malformed row to retain its trusted record with `structure_valid == false`.
- [ ] **Step 8: Add topology and path cases.** Implement `test_extra_or_unsafe_dossier_is_global_source_invalid()` and `test_ambiguous_repository_root_is_source_invalid()` for an extra `.md`, unsafe ledger path, `root + "/."`, non-descendant root, and linked root/child. On Windows create the required directory junction with `New-Item -ItemType Junction`; on Unix use `/bin/ln -s`. Failure to create the directory link is a test failure, not `pending`; only the separate file-symlink case may pend when the OS denies it.

  - [ ] Add and run the extra-direct-child-Markdown row.
  - [ ] Add and run the unsafe-ledger-path row.
  - [ ] Add and run the ambiguous `root + "/."` row.
  - [ ] Add and run the non-descendant-root row.
  - [ ] Add the Windows junction fixture branch and make creation failure fail the test.
  - [ ] Add the Unix directory-symlink fixture branch and make creation failure fail the test.
  - [ ] Add and run the linked-root row through the platform fixture branch.
  - [ ] Add and run the linked-child row through the platform fixture branch.
  - [ ] Add and run the separately permitted file-symlink row, with pending allowed only for an OS denial.
  - [ ] Run the topology table and assert directory-link cases never pend.
- [ ] **Step 9: Add override-guard cases.** Implement `test_fixture_digest_override_is_guarded()` for empty/malformed digest, fixture root equal to/outside `DWM_TEST_ROOT`, direct/subclass `_project("res://", alternate_digest)`, and `DWM_TEST_ROOT` deliberately rebound above the live repository. Require exact `CURRENT_UI_TEST_OVERRIDE_*` errors, restore the original environment value after every case, and prove the ordinary public `project("res://")` path still uses the compiled digest.

  - [ ] Add empty and malformed alternate-digest cases.
  - [ ] Add fixture-root-equal and fixture-root-outside guard cases.
  - [ ] Add direct and subclass live-`res://` override cases.
  - [ ] Add the rebound-parent `DWM_TEST_ROOT` case and the ordinary public-path control.
  - [ ] Capture `OS.has_environment("DWM_TEST_ROOT")` and its original value in `before_each()`; in `after_each()`, restore the value with `OS.set_environment()` when it originally existed or call `OS.unset_environment()` when it did not. Assert the cleanup state so a failing case cannot leak authority into the next case.
- [ ] **Step 10: Run RED.** Use:

  ```powershell
  & .\tools\testing\Invoke-IsolatedGodot.ps1 `
    -SuiteId 'ui00-projector-red' `
    -LogName 'ui00-projector-red.log' `
    -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_current_ui_dossier_projector.gd','-gexit') `
    -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  ```

  Expected RED: `test_projects_one_exact_accepted_binding` executes and fails because `source_valid` is false with `CURRENT_UI_PROJECTOR_NOT_IMPLEMENTED`. A missing dependency, parse error, engine error, or zero executed tests is not acceptable RED.
- [ ] **Step 11: Add the private projector boundaries.** Replace the seam's class body with the public signature above and declare these exact helpers:

  ```text
  func _normalize_repository_root(repository_root: String) -> Dictionary
  func _read_strict_lf_file(absolute_path: String, label: String) -> Dictionary
  func _parse_ledger(readme_text: String) -> Dictionary
  func _acceptance_projection(rows: Array[Dictionary]) -> PackedByteArray
  func _validate_test_override(repository_root: String, expected_acceptance_projection_sha256: String) -> Array[String]
  func _project(repository_root: String, expected_acceptance_projection_sha256: String) -> Dictionary
  func _project_validated(repository_root: String, expected_acceptance_projection_sha256: String) -> Dictionary
  func _project_with_expected_projection_for_test(repository_root: String, expected_acceptance_projection_sha256: String) -> Dictionary
  func _enumerate_dossier_children(absolute_root: String) -> Dictionary
  func _project_dossier(repository_root: String, row: Dictionary) -> Dictionary
  func _is_safe_relative_path(path: String) -> bool
  func _is_regular_non_link_file(repository_root: String, relative_path: String) -> bool
  func _result(source_valid: bool, ledger: Dictionary, records: Array[Dictionary], errors: Array[String]) -> Dictionary
  ```

  Each helper returns only its declared value plus sorted deterministic errors and performs no writes.
- [ ] **Step 12: Implement strict root, path, and file reading.** Implement `_normalize_repository_root`, `_is_safe_relative_path`, and `_is_regular_non_link_file` by normalizing once, requiring a strict repository descendant for every relative path, and walking every segment with `DirAccess.is_link()`. Implement the strict reader with this representative body and the repository's existing error-prefix convention:

  ```gdscript
  func _read_strict_lf_file(path: String, label: String) -> Dictionary:
      var bytes := FileAccess.get_file_as_bytes(path)
      if bytes.is_empty() and not FileAccess.file_exists(path):
          return {"ok":false,"bytes":PackedByteArray(),"text":"","errors":[label + "_MISSING"]}
      if bytes.size() >= 3 and bytes.slice(0, 3) == PackedByteArray([0xef, 0xbb, 0xbf]):
          return {"ok":false,"bytes":bytes,"text":"","errors":[label + "_BOM"]}
      var text := bytes.get_string_from_utf8()
      if bytes.is_empty() or 13 in bytes or bytes[-1] != 10 or text.to_utf8_buffer() != bytes:
          return {"ok":false,"bytes":bytes,"text":"","errors":[label + "_ENCODING"]}
      return {"ok":true,"bytes":bytes,"text":text,"errors":[]}
  ```

  - [ ] Implement `_normalize_repository_root()` without changing another helper.
  - [ ] Run only the equal, descendant, non-descendant, and ambiguous-root tests.
  - [ ] Implement `_is_safe_relative_path()` without changing another helper.
  - [ ] Run only the safe, absolute, backslash, colon, dot-segment, and escape path tests.
  - [ ] Implement `_is_regular_non_link_file()` without changing another helper.
  - [ ] Run only the regular, missing, linked, directory, and nonregular file tests.
  - [ ] Implement `_read_strict_lf_file()` exactly as represented above.
  - [ ] Run only the missing, UTF-8, BOM, CRLF, and final-LF reader tests.
- [ ] **Step 13: Implement guarded digest selection.** Make `_project()` the deepest guard so direct callers cannot bypass it:

  ```gdscript
  func _project(repository_root: String, expected_sha256: String) -> Dictionary:
      if expected_sha256 != APPROVED_ACCEPTANCE_PROJECTION_SHA256:
          var guard_errors := _validate_test_override(repository_root, expected_sha256)
          if not guard_errors.is_empty():
              return _result(false, {}, [], guard_errors)
      return _project_validated(repository_root, expected_sha256)
  ```

  `_validate_test_override()` requires lowercase 64-hex, a nonempty normalized `DWM_TEST_ROOT`, the requested normalized root as its strict descendant, and requested root unequal to normalized `ProjectSettings.globalize_path("res://")`. `project()` supplies only the constant; the fixture seam calls `_project()` and cannot weaken it.
- [ ] **Step 14: Implement ledger boundary and row parsing.** Implement `_parse_ledger()` in this exact stage order: find each boundary heading exactly once; slice only the intervening lines; require the exact header and separator; split every data line into exactly five trimmed cells; retain every row with lexically recoverable ID/path before reporting cell errors; validate label/path/approval/byte-count/digest/effect grammar; then report duplicate ID/path errors without discarding rows.

  - [ ] Implement exact-once discovery of the opening and closing boundary headings.
  - [ ] Implement slicing that excludes both boundary headings and every outside line.
  - [ ] Implement exact header and separator validation.
  - [ ] Implement exact five-cell splitting with trimmed cell values.
  - [ ] Retain lexically recoverable ID/path values before recording later cell errors.
  - [ ] Implement family-label and accepted-dossier link/path grammar.
  - [ ] Implement owner-approval date and `owner explicitly` grammar.
  - [ ] Implement positive decimal byte-count grammar.
  - [ ] Implement exact digest wording and lowercase 64-hex grammar.
  - [ ] Implement nonempty `accepted exact writing;` effect grammar.
  - [ ] Implement duplicate ID/path reporting without row deletion.
  - [ ] Run only the ledger boundary, grammar, projection-drift, and duplicate-retention tests.
- [ ] **Step 15: Implement deterministic acceptance projection.** Implement `_acceptance_projection()` as an ordinal copy-sort by `(id,path)`, append `id + "\t" + path + "\t" + str(byte_length) + "\t" + accepted_sha256 + "\n"` for every valid row, and return `projection_text.to_utf8_buffer()`. Hash those exact bytes once in `_project_validated()` and compare with `expected_acceptance_projection_sha256` before dossier enumeration.
- [ ] **Step 16: Implement direct-child topology enumeration.** Implement `_enumerate_dossier_children()` as a nonrecursive ordinal listing of `CURRENT_UI_ROOT`: ignore README, accept only regular non-link direct `.md` files, and report every extra Markdown child, linked entry, directory, or nonregular target as a global topology error. Never follow a link or recurse.
- [ ] **Step 17: Implement one dossier projection.** Implement `_project_dossier()` in this order: create the record from the trusted row; strict-read the expected path; parse required frontmatter; validate filename/ID and exact typed lifecycle tuple; compute raw byte length/hash; set `structure_valid`, `lifecycle_approved`, and `ledger_match` independently; return the record even when source or approval validation fails.

  - [ ] Construct the initial record solely from the trusted ledger row.
  - [ ] Strict-read the expected dossier path while retaining the initial record on failure.
  - [ ] Parse and type-check the required frontmatter fields.
  - [ ] Validate direct-child filename against frontmatter ID.
  - [ ] Validate the exact typed lifecycle tuple independently of byte agreement.
  - [ ] Compute the raw byte length and SHA-256 without normalization.
  - [ ] Set `structure_valid`, `lifecycle_approved`, and `ledger_match` independently.
  - [ ] Run only the malformed, lifecycle, byte-drift, and missing-dossier projection tests.
- [ ] **Step 18: Implement orchestration and exact result shape.** Implement `_project_validated()` as root normalization → strict README read → ledger parse → projection digest → child topology → one record per retained trusted row → extra-child comparison → ordinal record/error sorting. `_result()` constructs only `{source_valid,ledger,records,errors}`; `source_valid` excludes per-record lifecycle/hash state exactly as frozen above. `project()` and the fixture seam delegate without additional behavior.

  - [ ] Implement `_result()` with exactly its four frozen keys and copied sorted errors.
  - [ ] Run only the result-shape and `source_valid` boundary assertions.
  - [ ] Implement `_project_validated()` through root normalization and strict README reading.
  - [ ] Extend `_project_validated()` through ledger parsing and projection-digest comparison.
  - [ ] Extend `_project_validated()` through direct-child topology enumeration.
  - [ ] Extend `_project_validated()` through one record per retained trusted row and extra-child comparison.
  - [ ] Complete `_project_validated()` with ordinal record/error sorting and `_result()` construction.
  - [ ] Implement public `project()` as constant-bound delegation only.
  - [ ] Implement the guarded fixture entry point as delegation only.
  - [ ] Run the focused projector suite before the repository-cohort test.
- [ ] **Step 19: Run fixture GREEN.** Repeat the RED command with SuiteId `ui00-projector-green` and log `ui00-projector-green.log`. Require every named test to execute, zero failures, zero unexpected engine errors, the non-skippable directory-link test to execute rather than pend, and no leaked fixture links/directories.
- [ ] **Step 20: Pin the repository cohort.** Add `test_repository_cohort_matches_countersigned_projection()`; instantiate at `res://`, assert the production projection digest, and compare the ten sorted `(id,path,byte_length,accepted_sha256,actual_sha256)` tuples exactly to the frozen table above. Rerun with SuiteId `ui00-projector-cohort` and require ten records and zero errors.
- [ ] **Step 21: Conditional commit.** Invoke the Task 1 ordered map and exact helper command in “Shared Conditional Exact-Path Commit Procedure.” Skip it when permission is absent.

---

### Task 2: Add `canonical_ui_id` and the Admission Schema

**Files:**

- Modify: `tools/docs/AgentWorkflowAuthorityResolver.gd`
- Modify: `tests/unit/tooling/test_agent_workflow_authority_resolver.gd`
- Modify: `tests/unit/tooling/test_agent_workflow_validator.gd`

**Interfaces:**

- Consumes: Task 1's `CurrentUiDossierProjector.project(repository_root: String = "res://") -> Dictionary` result, existing resolver projections for requirements, decisions, specifications, plans, and Beads, and admission-local strict `docs/design/` frontmatter-ID projection.
- Produces: backwards-compatible `AgentWorkflowAuthorityResolver.resolve({"kind":"canonical_ui_id","target":String}) -> Dictionary` and conditional admission validation for ordinary `design_specification` records. Public authority-link kinds resolve normally; `design_document` records validate locally without expanding `AgentWorkflowAuthorityResolver.LINK_KINDS`; there is no new public envelope or link kind beyond `canonical_ui_id`.

- [ ] **Step 1: Extend the resolver fixture.** Copy the eleven exact current-UI cohort files byte-for-byte from `res://docs/design/current-ui/` into `_fixture_root()`; do not add a resolver digest override. Add this link to `test_resolves_every_frozen_link_kind()`:

  ```gdscript
  {"kind":"canonical_ui_id", "target":"canon.current_ui.settings"}
  ```

  Require the unchanged success envelope `{"ok":true,"code":&"ok","value":{"kind":"canonical_ui_id","target":"canon.current_ui.settings"},"receipt":{}}`. All resolver construction remains backwards-compatible with the existing two arguments.

  - [ ] Copy README, Global UI Grammar, and Contacts into the fixture byte-for-byte.
  - [ ] Copy Shared Shell, Gallery, and Witnessed Scene into the fixture byte-for-byte.
  - [ ] Copy Shop, Backup, and Settings into the fixture byte-for-byte.
  - [ ] Copy Schedule and Minesweeper into the fixture byte-for-byte.
  - [ ] Compare all eleven fixture byte arrays to their `res://docs/design/current-ui/` sources and add no digest override.
  - [ ] Add the `canonical_ui_id` Settings link row shown above.
  - [ ] Add the exact unchanged success-envelope assertion.
  - [ ] Retain one construction call with each existing two-argument constructor form.
  - [ ] Run only `test_resolves_every_frozen_link_kind()` and the constructor-compatibility controls.
- [ ] **Step 2: Add invalid and unknown resolver tests.** Prove malformed link shape, unknown kind, and empty target return `AUTHORITY_LINK_INVALID`; with a valid projector, prove an absent well-formed ID returns `AUTHORITY_LINK_UNKNOWN`.

  - [ ] Add and run the malformed link-shape row.
  - [ ] Add and run the unknown link-kind row.
  - [ ] Add and run the empty-target row.
  - [ ] Add and run the absent well-formed canonical ID row with a valid projector.
  - [ ] Run the invalid/unknown table and require exact codes and unchanged envelopes.
- [ ] **Step 3: Add duplicate and global-source tests.** Prove two lexically recoverable matching ledger IDs return `AUTHORITY_LINK_DUPLICATE_TARGET`, even when that fixture is also globally invalid. Prove README/table/projection/path/topology failure returns `AUTHORITY_LINK_SOURCE_INVALID` for a nonduplicate target.

  - [ ] Add and run the two-recoverable-matching-ID duplicate-precedence row.
  - [ ] Add and run the strict README source-failure row for a nonduplicate target.
  - [ ] Add and run the ledger-table grammar failure row for a nonduplicate target.
  - [ ] Add and run the acceptance-projection failure row for a nonduplicate target.
  - [ ] Add and run the repository-path failure row for a nonduplicate target.
  - [ ] Add and run the dossier-topology failure row for a nonduplicate target.
  - [ ] Run the duplicate/global-source table and require duplicate precedence over global invalidity.
- [ ] **Step 4: Add record-source and approval tests.** Prove matching missing/linked/invalid-UTF-8/malformed dossier returns `AUTHORITY_LINK_SOURCE_INVALID`; typed unaccepted lifecycle and unchanged-ledger dossier byte drift return `AUTHORITY_LINK_UNAPPROVED`. Require the unchanged success envelope and error keys.

  - [ ] Add and run the matching missing-dossier row.
  - [ ] Add and run the matching linked-dossier row.
  - [ ] Add and run the matching invalid-UTF-8 dossier row.
  - [ ] Add and run the matching malformed-frontmatter dossier row.
  - [ ] Add and run the matching typed-but-unaccepted lifecycle row.
  - [ ] Add and run the unchanged-ledger dossier byte-drift row.
  - [ ] Run the record-source/approval table and require exact error keys plus an unchanged success control.

  The complete frozen classification remains:

  | Condition | Expected code |
  |---|---|
  | malformed link shape/kind/empty target | `AUTHORITY_LINK_INVALID` |
  | valid projector and absent ID | `AUTHORITY_LINK_UNKNOWN` |
  | two lexically recoverable matching ledger IDs | `AUTHORITY_LINK_DUPLICATE_TARGET` |
  | README/table/projection/path/topology failure | `AUTHORITY_LINK_SOURCE_INVALID` |
  | matching missing, linked, invalid-UTF-8, or malformed dossier | `AUTHORITY_LINK_SOURCE_INVALID` |
  | matching typed but unaccepted lifecycle | `AUTHORITY_LINK_UNAPPROVED` |
  | unchanged ledger plus changed dossier byte count/hash | `AUTHORITY_LINK_UNAPPROVED` |

- [ ] **Step 5: Write the valid admission lifecycle test.** Build `spec.ui_01.settings_probe` with strict quoted dates and one-line JSON values. Its semantic data must equal this shape, with hashes/ranges calculated from fixture bytes before serialization:

  ```gdscript
  var targets := [{
      "id": "canon.current_ui.settings",
      "path": "docs/design/current-ui/settings.md",
      "sha256": _raw_sha256(dossier_path),
      "clauses": [{
          "clause_key": "settings_authority_boundary",
          "heading": "## 1. Status, authority, precedence, and migration effect",
          "start_line": 60,
          "end_line": 67,
          "section_sha256": _inclusive_line_sha256(dossier_path, 60, 67),
      }],
  }]
  var current := [{
      "authority_kind": "requirement_id",
      "target": "req.sample",
      "path": "prompt_docs/requirements/sample.md",
      "canonical_sha256": _canonical_sha256(requirement_path),
      "scope_ids": ["settings_existing_projection"],
  }]
  var retained := [{
      "authority_kind": "decision_id",
      "target": "decision.sample",
      "path": "prompt_docs/decisions/sample.md",
      "canonical_sha256": _canonical_sha256(decision_path),
      "scope_ids": ["settings_deeper_ownership"],
  }]
  var conflicts := [{
      "conflict_id": "conflict.settings_probe.existing_projection",
      "target_id": "canon.current_ui.settings",
      "target_clause_key": "settings_authority_boundary",
      "current_authority_kind": "requirement_id",
      "current_authority_target": "req.sample",
      "resolution": "The admitted clause succeeds the old Settings-facing projection only; retained deeper ownership remains unchanged.",
  }]
  ```

  The frontmatter also sets `implementation_target_admission: true`, `implementation_slice_id: ui-01.settings_probe`, exact kind/schema/status fields, `implementation_conflict_audit: complete_no_unresolved_conflicts`, `production_exposure_paths: ["scripts/ui/existing.gd"]`, `pre_cutover_exposure_must_remain_unchanged: true`, `plan_authoring_scope: ["settings_probe_contract_tests"]`, `plan_authoring_authorized: true`, and all runtime/commit booleans false. Before plan creation it uses the exact prospective path and two `not_authored` values frozen above. Assert `specification_id` success while `plan_path` is `UNKNOWN`; after creating exact plan bytes and setting approved status/hash, assert plan success without changing runtime/commit booleans.

  - [ ] Add the strict `req.sample` requirement source and compute its canonical digest.
  - [ ] Add the strict `decision.sample` decision source and compute its canonical digest.
  - [ ] Add the existing exposure file at `scripts/ui/existing.gd` in the fixture.
  - [ ] Calculate the Settings dossier raw digest and the exact clause line range/heading.
  - [ ] Calculate the inclusive-LF clause digest from fixture bytes.
  - [ ] Assemble and serialize the one-row `targets` array shown above.
  - [ ] Assemble and serialize the one-row `current` authority array.
  - [ ] Assemble and serialize the one-row `retained` authority array.
  - [ ] Assemble and serialize the one-row `conflicts` array.
  - [ ] Add admission identity, kind, schema, slice, and audit fields.
  - [ ] Add exposure, pre-cutover, authoring-scope, and authoring-permission fields.
  - [ ] Add false requested, runtime-authorization, and commit-authorization fields.
  - [ ] Add the safe prospective plan path with status/hash both `not_authored` while that path is absent.
  - [ ] Strict-write `spec.ui_01.settings_probe` with quoted date scalars and one-line JSON fields.
  - [ ] Resolve `specification_id` and assert the exact success envelope.
  - [ ] Resolve the prospective `plan_path` and assert `AUTHORITY_LINK_UNKNOWN`.
  - [ ] Create the exact strict plan bytes at the unchanged prospective path.
  - [ ] Replace status/hash with `approved` and the calculated lowercase canonical digest.
  - [ ] Resolve the approved plan and assert the exact success envelope.
  - [ ] Reassert that requested, runtime-authorized, and commit-authorized values remain false.
  - [ ] Run only the valid admission lifecycle test before adding mutation cases.
- [ ] **Step 6: Add one reusable admission mutation assertion.** Add this helper and create a fresh valid fixture per case:

  ```gdscript
  func _assert_admission_mutation_fails(mutate: Callable, label: String) -> void:
      var fixture := _valid_admission_fixture()
      mutate.call(fixture.admission)
      _write_admission_spec(fixture)
      var result := _resolver_for(fixture).resolve({"kind":"specification_id","target":"spec.ui_01.settings_probe"})
      assert_false(result.ok, label)
      assert_eq(result.code, &"AUTHORITY_LINK_SOURCE_INVALID", label)
  ```
- [ ] **Step 7: Add admission top-level schema cases.** Use the helper for each missing/extra conditional field, malformed/non-inline JSON, invalid `implementation_slice_id`, empty exposure/authoring scope, and false pre-cutover guard. Each case changes one field only and identifies that field in `label`.

  - [ ] Add missing-field rows for `kind`, `schema_version`, and `implementation_slice_id`.
  - [ ] Add missing-field rows for target, current-authority, and retained-authority arrays.
  - [ ] Add missing-field rows for conflict audit, conflict resolutions, and exposure paths.
  - [ ] Add missing-field rows for the pre-cutover guard, authoring scope, and authoring permission.
  - [ ] Add missing-field rows for requested, runtime-authorized, and commit-authorized booleans.
  - [ ] Add one-extra-field rows beside `kind`, `schema_version`, and `implementation_slice_id`.
  - [ ] Add one-extra-field rows beside target, current-authority, and retained-authority arrays.
  - [ ] Add one-extra-field rows beside conflict audit, conflict resolutions, and exposure paths.
  - [ ] Add one-extra-field rows beside the pre-cutover guard, authoring scope, and authoring permission.
  - [ ] Add one-extra-field rows beside requested, runtime-authorized, and commit-authorized booleans.
  - [ ] Add and run the malformed inline-JSON row.
  - [ ] Add and run the YAML/block-array instead of inline-JSON row.
  - [ ] Add and run the invalid `implementation_slice_id` row.
  - [ ] Add and run the empty `production_exposure_paths` row.
  - [ ] Add and run the empty `plan_authoring_scope` row.
  - [ ] Add and run the false pre-cutover guard row.
  - [ ] Run the complete admission top-level table and require each label to identify its one changed field.
- [ ] **Step 8: Add nested order and duplicate cases.** Mutate one `TargetRecord`, `ClauseRecord`, `AuthorityRecord`, or `ConflictRecord` key set/type/order at a time. Separately test unsorted arrays and duplicate target, `(authority_kind,target)`, scope, clause, conflict, and exposure entries. Include `design_document` in the accepted admission enum and prove `{"kind":"design_document","target":"spec.sample"}` remains an invalid public authority link.

  - [ ] Add exact-key, type, and key-order rows for `TargetRecord`.
  - [ ] Add exact-key, type, and key-order rows for `ClauseRecord`.
  - [ ] Add exact-key, type, and key-order rows for `AuthorityRecord`.
  - [ ] Add exact-key, type, and key-order rows for `ConflictRecord`.
  - [ ] Add and run the unsorted target-array row.
  - [ ] Add and run the unsorted current-authority-array row.
  - [ ] Add and run the unsorted retained-authority-array row.
  - [ ] Add and run the unsorted conflict-array row.
  - [ ] Add and run the unsorted exposure-array row.
  - [ ] Add and run the unsorted authoring-scope row.
  - [ ] Add and run the duplicate target row.
  - [ ] Add and run the duplicate `(authority_kind,target)` row.
  - [ ] Add and run the duplicate scope row.
  - [ ] Add and run the duplicate clause row.
  - [ ] Add and run the duplicate conflict row.
  - [ ] Add and run the duplicate exposure-path row.
  - [ ] Add and run the admission-local `design_document` enum-positive row.
  - [ ] Add and run the public-link `design_document` invalid-kind control.
- [ ] **Step 9: Add clause locator and hash cases.** Independently invert/exceed a clause range, mismatch its heading, drift its inclusive-LF section hash, use an undeclared clause key, and point a conflict at the wrong target clause. Require source-invalid while an unrelated legacy record remains byte-identical and resolvable.

  - [ ] Add and run the inverted clause-range row.
  - [ ] Add and run the end-line-exceeds-file row.
  - [ ] Add and run the heading-mismatch row.
  - [ ] Add and run the inclusive-LF section-hash drift row.
  - [ ] Add and run the undeclared clause-key row.
  - [ ] Add and run the conflict-to-wrong-target-clause row.
  - [ ] Run the unrelated legacy-record control and require byte-identical resolution after every clause mutation.
- [ ] **Step 10: Add repository path, link, and encoding cases.** Independently use unsafe, nonexistent, wrong-root, linked, and nonregular target/authority/exposure paths; add invalid UTF-8 or BOM; and drift target/authority digests. Each mutation must fail before permission evaluation.

  - [ ] Add unsafe-path rows for target, authority, and exposure records.
  - [ ] Add nonexistent-path rows for target, authority, and exposure records.
  - [ ] Add wrong-root rows for target, authority, and exposure records.
  - [ ] Add linked-path rows for target, authority, and exposure records.
  - [ ] Add nonregular-path rows for target, authority, and exposure records.
  - [ ] Add and run the invalid-UTF-8 admission row.
  - [ ] Add and run the BOM admission row.
  - [ ] Add and run the target-digest drift row.
  - [ ] Add and run the authority-digest drift row.
  - [ ] Assert every path, encoding, and digest row fails before permission evaluation.
- [ ] **Step 11: Add `design_document` projection and collision cases.** Prove valid admission-local `spec.*`, `note.*`, and `guide.*` IDs from strict `docs/design/` files. Reject paths outside `docs/design/`, missing/duplicate/mismatched ID, malformed or duplicate frontmatter key, invalid encoding, duplicate local ID, and every matching public-source identity state: approved, unapproved, malformed-but-lexically-recoverable, or duplicate. Also reject a valid copied `canon.current_ui.*` dossier under `docs/design/current-ui/`, a `canon.current_ui.*` ID under another `docs/design/` path, and a `spec.*` ID whose path is under `docs/design/current-ui/`. Only a matching target pattern, non-current-UI path, and zero public-source records may pass locally; none becomes a public link kind.

  - [ ] Add and run the valid local `spec.*` projection row.
  - [ ] Add and run the valid local `note.*` projection row.
  - [ ] Add and run the valid local `guide.*` projection row.
  - [ ] Add and run the path-outside-`docs/design/` row.
  - [ ] Add and run the unsafe-path row.
  - [ ] Add and run the linked-path row.
  - [ ] Add and run the nonregular-file row.
  - [ ] Add and run the missing-frontmatter-ID row.
  - [ ] Add and run the duplicated-frontmatter-ID row.
  - [ ] Add and run the path/ID-mismatch row.
  - [ ] Add and run the malformed-frontmatter row.
  - [ ] Add and run the duplicate-frontmatter-key row.
  - [ ] Add and run the invalid-UTF-8 row.
  - [ ] Add and run the BOM row.
  - [ ] Add and run the duplicate admission-local ID row.
  - [ ] Add and run the approved public-source collision row.
  - [ ] Add and run the unapproved public-source collision row.
  - [ ] Add and run the malformed-but-lexically-recoverable public-source collision row.
  - [ ] Add and run the duplicate public-source collision row.
  - [ ] Add and run the copied canonical dossier under `docs/design/current-ui/` exclusion row.
  - [ ] Add and run the `canon.current_ui.*` ID under another `docs/design/` path exclusion row.
  - [ ] Add and run the local `spec.*` ID under `docs/design/current-ui/` exclusion row.
  - [ ] Prove again that `design_document` is admission-local only and is rejected as a public authority-link kind.
- [ ] **Step 12: Add referential and conflict cases.** Cover unresolved public authority, authority path/hash mismatch, conflict outside declared target/current records, duplicate conflict reference, and an empty conflict array paired with any audit status other than `complete_no_unresolved_conflicts`.

  - [ ] Add and run the unresolved-public-authority row.
  - [ ] Add and run the authority-path mismatch row.
  - [ ] Add and run the authority-hash mismatch row.
  - [ ] Add and run the conflict-outside-declared-target row.
  - [ ] Add and run the conflict-outside-declared-current-authority row.
  - [ ] Add and run the duplicate conflict-reference row.
  - [ ] Add and run the empty-conflicts/noncomplete-audit-status row.
- [ ] **Step 13: Add lifecycle, permission, and legacy cases.** Prove the exact prospective-path/`not_authored` tuple resolves the specification but not the plan; reject every other status/hash/path combination; prove approved exact plan resolution; preserve false runtime/commit permission as valid; reject an approved admission with false plan-authoring grant; and resolve one byte-for-byte legacy specification with no admission fields.

  - [ ] Add and run the exact prospective-path plus two-`not_authored` positive specification case.
  - [ ] Require `plan_path` to remain `AUTHORITY_LINK_UNKNOWN` for that positive prospective state.
  - [ ] Add and run `not_authored` paired with a hash instead of the sentinel.
  - [ ] Add and run `not_authored` paired with an already existing plan path.
  - [ ] Add and run `approved` paired with a missing plan path.
  - [ ] Add and run `approved` paired with the `not_authored` hash sentinel.
  - [ ] Add and run `approved` paired with a drifted plan digest.
  - [ ] Add and run an unknown implementation-plan status.
  - [ ] Add and run the approved exact-plan positive resolution case.
  - [ ] Add and run the false runtime-authorization positive control.
  - [ ] Add and run the false commit-authorization positive control.
  - [ ] Add and run the approved admission with false plan-authoring grant rejection.
  - [ ] Resolve one byte-for-byte legacy specification with no admission fields.
- [ ] **Step 14: Run RED.** Use:

  ```powershell
  & .\tools\testing\Invoke-IsolatedGodot.ps1 `
    -SuiteId 'ui00-resolver-red' `
    -LogName 'ui00-resolver-red.log' `
    -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_current_ui_dossier_projector.gd,res://tests/unit/tooling/test_agent_workflow_authority_resolver.gd,res://tests/unit/tooling/test_agent_workflow_validator.gd','-gexit') `
    -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  ```

  Expected RED: `canonical_ui_id` is rejected as an invalid kind and the valid-admission fixture does not receive strict validation; all legacy assertions still execute. A missing dependency, parse error, engine error, or zero tests is not acceptable RED.
- [ ] **Step 15: Wire the projector and resolver branch.** Add the preload, enum entry, cached result, and branch exactly as follows; initialize `_canonical_ui_result` after packet projection and before the two-pass specification admission validation:

  ```gdscript
  const CURRENT_UI_PROJECTOR := preload("res://tools/docs/CurrentUiDossierProjector.gd")
  const LINK_KINDS := [&"beads_issue", &"requirement_id", &"specification_id", &"decision_id", &"plan_path", &"canonical_ui_id"]
  var _canonical_ui_result: Dictionary

  # In _init(), before admission validation:
  _canonical_ui_result = CURRENT_UI_PROJECTOR.new().project(_repository_root)

  # In resolve():
  &"canonical_ui_id":
      return _resolve_canonical_ui(target)

  func _resolve_canonical_ui(target: String) -> Dictionary:
      var records: Array = _canonical_ui_result.get("records", [])
      var matches: Array = records.filter(func(record: Dictionary) -> bool: return record.get("id") == target)
      if matches.size() > 1:
          return _failure(&"AUTHORITY_LINK_DUPLICATE_TARGET", {"kind":"canonical_ui_id", "target":target})
      if not _canonical_ui_result.get("source_valid", false):
          return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"canonical_ui_id", "target":target, "errors":_canonical_ui_result.get("errors", [])})
      if matches.is_empty():
          return _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind":"canonical_ui_id", "target":target})
      var record: Dictionary = matches[0]
      if not record.get("structure_valid", false):
          return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"canonical_ui_id", "target":target})
      if not record.get("lifecycle_approved", false) or not record.get("ledger_match", false):
          return _failure(&"AUTHORITY_LINK_UNAPPROVED", {"kind":"canonical_ui_id", "target":target})
      return _success(&"canonical_ui_id", target)
  ```
- [ ] **Step 16: Add the two-pass admission seam.** Keep `SPEC_FIELDS` unchanged. During `_project_frontmatter`, detect exactly one unindented `implementation_target_admission: true`; only then call `DocFrontmatter.parse_file(path)` and attach its parsed frontmatter to the internal record. After every legacy/public identity projection exists, execute this order and never call public `resolve()` inside the pass:

  ```gdscript
  var _design_documents: Dictionary = {}

  _spec_records = _project_specifications(_path("docs/superpowers/specs"))
  _design_documents = _project_design_document_ids(_repository_root)
  _validate_admissions()
  ```

  Declare these exact private boundaries:

  ```text
  func _validate_admissions() -> void
  func _validate_admission(record: Dictionary) -> Array[String]
  func _validate_target_record(value: Variant, seen_ids: Dictionary, seen_paths: Dictionary) -> Array[String]
  func _validate_clause_record(value: Variant, dossier_path: String, seen_keys: Dictionary) -> Array[String]
  func _validate_authority_record(value: Variant, seen_keys: Dictionary) -> Array[String]
  func _project_design_document_ids(repository_root: String) -> Dictionary
  func _public_authority_identity_count(target: String) -> int
  func _validate_existing_public_authority(value: Dictionary) -> Array[String]
  func _validate_design_document_authority(value: Dictionary, design_documents: Dictionary) -> Array[String]
  func _validate_conflict_record(value: Variant, targets: Dictionary, current_authorities: Dictionary, seen_ids: Dictionary) -> Array[String]
  func _validate_sorted_unique_strings(value: Variant, pattern: String, label: String) -> Array[String]
  func _inclusive_line_sha256(path: String, start_line: int, end_line: int) -> Dictionary
  ```

  The seam sets only the matching internal record's `ok` false and appends sorted source errors; it does not change approval or permission booleans.
- [ ] **Step 17: Implement target and clause validation.** For each record: exact keys/types → local uniqueness → projector ID/path/raw-hash binding → exact heading at `start_line` → inclusive `start_line..end_line` joined by LF plus final LF → section digest comparison. `_inclusive_line_sha256()` returns `{ok,value,errors}` and never normalizes accepted dossier bytes.

  - [ ] Implement `_inclusive_line_sha256()` strict reading and one-based range validation.
  - [ ] Complete `_inclusive_line_sha256()` with inclusive LF-plus-final-LF hashing and its exact result envelope.
  - [ ] Run only the inclusive-range and section-hash helper tests.
  - [ ] Implement `TargetRecord` exact keys, types, and local ID/path uniqueness.
  - [ ] Complete `_validate_target_record()` with projector ID/path/raw-hash binding.
  - [ ] Run only the target-record schema, duplicate, and projector-binding tests.
  - [ ] Implement `ClauseRecord` exact keys, types, and local clause-key uniqueness.
  - [ ] Add exact heading and in-file start/end validation to `_validate_clause_record()`.
  - [ ] Add inclusive section-digest comparison to `_validate_clause_record()`.
  - [ ] Run only the clause locator, heading, range, and digest tests.
- [ ] **Step 18: Project admission-local design identities.** Walk `docs/design/` Markdown files in ordinal repository-path order, reject links, strict-read UTF-8/no-BOM frontmatter, and retain `{id,path,ok,canonical_sha256}` even when the record is malformed but its ID is lexically recoverable. Group by ID without deduplication so missing, malformed, or duplicate targets remain distinguishable.
- [ ] **Step 19: Validate authority records without namespace laundering.** Implement the branch exactly at the local/public boundary:

  ```gdscript
  if authority_kind == "design_document":
      if _public_authority_identity_count(target) != 0:
          return ["ADMISSION_AUTHORITY_PUBLIC_ID_COLLISION"]
      return _validate_design_document_authority(value, _design_documents)
  return _validate_existing_public_authority(value)
  ```

  `_public_authority_identity_count()` counts every lexically recoverable matching requirement/specification/decision record regardless of approval or validity. Before local lookup, `design_document` rejects a target outside the `spec|note|guide` pattern, any `canon.current_ui.*` target, and any path under `docs/design/current-ui/`. Existing kinds require their existing projected path/hash; a remaining `design_document` requires exactly one valid local record and never expands `LINK_KINDS`.
- [ ] **Step 20: Validate conflicts and sorted strings.** Implement `_validate_conflict_record()` against declared targets, clause keys, and current-authority pairs only. Implement `_validate_sorted_unique_strings()` as exact type/pattern validation followed by ordinal copy-sort equality and duplicate rejection; do not silently sort input.

  - [ ] Implement `ConflictRecord` exact keys, types, and unique `conflict_id` validation.
  - [ ] Add declared-target and declared-target-clause validation.
  - [ ] Add declared current-authority pair validation.
  - [ ] Run only the conflict referential-closure and duplicate-reference tests.
  - [ ] Implement `_validate_sorted_unique_strings()` type and element-pattern validation.
  - [ ] Add ordinal copy-sort equality without mutating the input.
  - [ ] Add duplicate-string rejection without input normalization.
  - [ ] Run only the scope and exposure ordering/duplicate tests.
- [ ] **Step 21: Complete admission lifecycle orchestration.** `_validate_admission()` validates the exact top-level key/type set, all nested records, referential closure, and conflicts before state. State then accepts exactly the prospective path + `not_authored` + `not_authored` tuple before a plan exists, or approved status + same existing regular path + lowercase canonical digest after approval. `_validate_admissions()` applies sorted errors only to the matching record. False runtime/commit booleans remain valid independent denials; malformed structure or a false plan-authoring grant invalidates the admission.

  - [ ] Implement the conditional admission's exact top-level key and type validation.
  - [ ] Invoke target and clause validators and retain their deterministic errors.
  - [ ] Invoke current/retained public and admission-local authority validators.
  - [ ] Invoke conflict and sorted-string validators only after their prerequisites are valid.
  - [ ] Enforce target, authority, clause, conflict, and exposure referential closure.
  - [ ] Implement the exact prospective path plus two-`not_authored` lifecycle state.
  - [ ] Implement the approved existing-plan path plus lowercase canonical-digest lifecycle state.
  - [ ] Reject every other plan status/path/hash combination.
  - [ ] Preserve false runtime and commit permission as valid independent denials.
  - [ ] Reject false plan-authoring permission and malformed admission structure.
  - [ ] Complete `_validate_admission()` with copied sorted errors only.
  - [ ] Implement `_validate_admissions()` as an ordinal pass over matching records.
  - [ ] Apply each error set only to its matching record without changing approval or permission booleans.
  - [ ] Run the focused admission lifecycle, permission, referential, and legacy tests.
- [ ] **Step 22: Run GREEN.** Repeat with SuiteId `ui00-resolver-green` and log `ui00-resolver-green.log`. Require all three suites green, the entire error matrix exact, the legacy fixture unchanged, and every one of the ten repository IDs resolvable.
- [ ] **Step 23: Conditional commit.** Invoke the Task 2 ordered map and exact helper command in “Shared Conditional Exact-Path Commit Procedure.” Skip it when permission is absent.

---

### Task 3: Reconcile Authority Context and the Five Stale Rules

**Files:**

- Create: `tests/unit/tooling/test_current_ui_requirement_reconciliation.gd`
- Modify: `prompt_docs/requirements/authority_context.md`
- Modify: `prompt_docs/requirements/contacts_invitations.md`
- Modify: `prompt_docs/requirements/persistence.md`
- Modify: `prompt_docs/requirements/desktop_minesweeper_handoff.md`
- Modify: `docs/agent/AGENT_WORKFLOW.md`
- Generate/check only: `prompt_docs/INDEX.md`

**Interfaces:**

- Consumes: the eight exact replacement paragraphs in “Requirement Reconciliation — Exact Replacement Text,” current packet IDs/dependencies/frontmatter, and the existing generated-index/document validators.
- Produces: five reconciled behavior-rule bodies, three reconciled authority-context bodies, one exact-body regression suite, and guide terminology for `canonical_ui_id`; no runtime conformance claim.

- [ ] **Step 1: Build the exact rule extractor and preservation fixture.** Strict-read the four packets, preserve their current frontmatter text/IDs/dependency arrays, and implement `extract_rule_body(path: String, requirement_id: String) -> String`; it requires exactly one heading formed as `## Rule ` plus the ID and returns its paragraph through the next heading with surrounding blank lines removed but internal bytes unchanged.

  - [ ] Implement `extract_rule_body()` exact heading construction and exact-once lookup.
  - [ ] Complete the extractor's next-heading boundary and surrounding-blank-line removal without internal normalization.
  - [ ] Add missing-rule and duplicate-rule rejection controls.
  - [ ] Implement one preservation projection helper for frontmatter text, ID, and dependency arrays.
  - [ ] Capture preservation fixtures for `authority_context.md` and `contacts_invitations.md`.
  - [ ] Capture preservation fixtures for `persistence.md` and `desktop_minesweeper_handoff.md`.
  - [ ] Run only the extractor boundary and four-packet preservation controls.
- [ ] **Step 2: Add the five behavior-body expectations.** Add five string constants copied verbatim from `req.invitation.solo`, `req.invitation.group_resolution`, `req.save.minesweeper_lock`, `req.minesweeper.round_contract`, and `req.desktop.logout` above; compare each extracted body exactly.

  - [ ] Add and compare the exact `req.invitation.solo` body constant.
  - [ ] Add and compare the exact `req.invitation.group_resolution` body constant.
  - [ ] Add and compare the exact `req.save.minesweeper_lock` body constant.
  - [ ] Add and compare the exact `req.minesweeper.round_contract` body constant.
  - [ ] Add and compare the exact `req.desktop.logout` body constant.
  - [ ] Run only the five positive behavior-body comparisons.
- [ ] **Step 3: Add the three authority-context expectations.** Add constants copied verbatim from `req.docs.authority`, `req.docs.context_order`, and `req.docs.status_separation` above; compare each extracted body exactly—eight total with Step 2.

  - [ ] Add and compare the exact `req.docs.authority` body constant.
  - [ ] Add and compare the exact `req.docs.context_order` body constant.
  - [ ] Add and compare the exact `req.docs.status_separation` body constant.
  - [ ] Run only the three authority-context comparisons, then all eight positive comparisons together.
- [ ] **Step 4: Add stale-clause negative assertions.** Reject reply-required solo acceptance; `replying to either participant MUST make the group date schedulable`; `disable manual saving until result application`; coordinator-owned `pre-board autosave, save lock`; and `Logout MUST reject while a Minesweeper round is active` in their owning rule bodies.

  - [ ] Add the reply-required solo-acceptance absence assertion.
  - [ ] Add the group-date either-participant reply sentence absence assertion.
  - [ ] Add the disable-manual-saving sentence absence assertion.
  - [ ] Add the coordinator-owned pre-board autosave/save-lock absence assertion.
  - [ ] Add the active-round Logout rejection sentence absence assertion.
  - [ ] Run only the five stale-clause negative assertions.
- [ ] **Step 5: Add guide assertions.** Compare the three glossary lines, the `canonical_ui_id` authority-map row, and the discovery-is-not-cutover paragraph in “Requirement Reconciliation — Exact Replacement Text” byte-for-byte at their exact neighboring anchors. Require all four `capability_intentions.authority_links` arrays to remain empty and the decision table unchanged.

  - [ ] Add the first glossary-line exact-anchor assertion.
  - [ ] Add the second glossary-line exact-anchor assertion.
  - [ ] Add the third glossary-line exact-anchor assertion.
  - [ ] Add the `canonical_ui_id` authority-map row exact-anchor assertion.
  - [ ] Add the discovery-is-not-cutover paragraph exact-anchor assertion.
  - [ ] Add empty authority-link-array assertions for the first two requirement packets.
  - [ ] Add empty authority-link-array assertions for the remaining two requirement packets.
  - [ ] Add the unchanged decision-table byte assertion.
  - [ ] Run only the guide-anchor, empty-link-array, and decision-table controls.
- [ ] **Step 6: Run RED.** Use:

  ```powershell
  & .\tools\testing\Invoke-IsolatedGodot.ps1 `
    -SuiteId 'ui00-requirements-red' `
    -LogName 'ui00-requirements-red.log' `
    -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_current_ui_requirement_reconciliation.gd','-gexit') `
    -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  ```

  Expected RED: exact new body/guide assertions fail against old prose; the test script itself parses and runs.
- [ ] **Step 7: Apply the two Contacts replacements.** With `apply_patch`, replace only `req.invitation.solo` and `req.invitation.group_resolution`; preserve `req.invitation.group_activation` and every frontmatter byte.
- [ ] **Step 8: Apply the three persistence/desktop replacements.** With `apply_patch`, replace only `req.save.minesweeper_lock`, `req.minesweeper.round_contract`, and `req.desktop.logout`; preserve stable IDs/dependencies/frontmatter.
- [ ] **Step 9: Apply the three authority-context replacements.** With `apply_patch`, replace only `req.docs.authority`, `req.docs.context_order`, and `req.docs.status_separation`; do not alter capability intentions.
- [ ] **Step 10: Apply the guide additions.** Insert exactly the three glossary lines, one authority-map row, and one discovery-is-not-cutover paragraph printed in “Requirement Reconciliation — Exact Replacement Text,” using their exact neighboring anchors rather than line numbers. Do not alter `Prompt.md` or the decision table.
- [ ] **Step 11: Run the focused GREEN test.** Repeat with SuiteId `ui00-requirements-green` and log `ui00-requirements-green.log`; require all eight exact comparisons, preservation assertions, guide assertions, and stale-clause negatives green.
- [ ] **Step 12: Regenerate and prove index stability.** Export once, then run all three CLIs against that snapshot:

  ```powershell
  & .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/ui00-all.json'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-generate-index' -LogName 'ui00-generate-index.log' -GodotArgs @('-s','res://tools/docs/generate_index.gd','--','--beads-snapshot=res://.godot/beads/ui00-all.json') -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-validate-docs' -LogName 'ui00-validate-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/ui00-all.json') -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-validate-workflow' -LogName 'ui00-validate-workflow.log' -GodotArgs @('-s','res://tools/docs/validate_agent_workflow.gd','--','--beads-snapshot=res://.godot/beads/ui00-all.json') -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  if ((Get-FileHash -LiteralPath 'prompt_docs/INDEX.md' -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'd4c24033eea0a6ffd2e16be1e5c8000ea4980997f7408ad24e5ee198587995c3') { throw 'UI00_INDEX_DRIFT' }
  ```

  Expected markers: `DOC_INDEX: PASS`, `DOC_VALIDATION: PASS`, and `AGENT_WORKFLOW_VALIDATION: PASS`; the index hash remains exact.
- [ ] **Step 13: Characterize runtime drift without mutation.** Run this exact read-only search and preserve its output in the execution report, not a source edit:

  ```powershell
  rg -n --no-heading -e 'reply' -e 'Accept' -e 'Decline' -e 'save lock' -e 'active.*round' -e 'pre-board' -e 'Logout.*reject' autoload scripts tests
  ```

  Expected: remaining stale runtime/tests may be reported as drift; do not edit them, claim conformance, or weaken a test.
- [ ] **Step 14: Conditional commit.** Require `prompt_docs/INDEX.md` byte-identical and unstaged, then invoke the Task 3 ordered map and exact helper command in “Shared Conditional Exact-Path Commit Procedure.” Skip it when permission is absent.

---

### Task 4: Produce and Validate the Reviewed Consumer/Provenance Census

**Files:**

- Create: `tools/evidence/CurrentUiConsumerCensus.gd`
- Create: `tools/evidence/validate_current_ui_consumer_census.gd`
- Create: `tests/unit/tooling/test_current_ui_consumer_census.gd`
- Create: `evidence/current_ui/authority/ui_00_beads_registration.v1.json`
- Create: `evidence/current_ui/authority/ui_00_consumer_census.v1.json`

**Interfaces:**

- Consumes: Task 1 projector records, `EvidenceValidator.parse_strict_text(text: String) -> Dictionary`, the registered Beads snapshot, exact accepted-dossier inbound/retained sections, the five Task 3 rule bodies, and existing approved specification/plan bindings.
- Produces: `CurrentUiConsumerCensus.inventory(repository_root: String, scan_contract: Dictionary) -> Dictionary`, `CurrentUiConsumerCensus.validate(repository_root: String, artifact_path: String) -> Dictionary`, one read-only CLI, and one reviewed audit artifact with zero unresolved references; none is resolver or behavior authority.

- [ ] **Step 1: Create a loadable census seam.** Add this exact compiling core before the test so RED proves behavior rather than dependency failure:

  ```gdscript
  class_name CurrentUiConsumerCensus
  extends RefCounted

  func inventory(repository_root: String, scan_contract: Dictionary) -> Dictionary:
      return {"ok":false, "occurrences":[], "errors":["CURRENT_UI_CENSUS_NOT_IMPLEMENTED"]}

  func validate(repository_root: String, artifact_path: String) -> Dictionary:
      return {"ok":false, "counts":{}, "artifact_sha256":"", "errors":["CURRENT_UI_CENSUS_NOT_IMPLEMENTED"]}
  ```
- [ ] **Step 2: Write the first failing fixture test.** Build a strict fixture under nonempty `DWM_TEST_ROOT` containing one projected dossier, one predecessor authority link, one accepted basis section, one reconciled rule, one approved spec/plan pair, one Beads snapshot, and one exact Minesweeper gate file. Keep production construction override-free. In the test file only, subclass the projector to expose its guarded fixture seam and subclass the census to override the two underscored dependency seams:

  ```gdscript
  class TestProjector extends CurrentUiDossierProjector:
      func project_fixture(repository_root: String, expected_sha256: String) -> Dictionary:
          return _project_with_expected_projection_for_test(repository_root, expected_sha256)

  class TestCensus extends CurrentUiConsumerCensus:
      var fixture_projection_sha256 := ""
      var fixture_dangling_exceptions: Array[Dictionary] = []

      func _project_current_ui(repository_root: String) -> Dictionary:
          return TestProjector.new().project_fixture(repository_root, fixture_projection_sha256)

      func _expected_dangling_source_identity_exceptions() -> Array[Dictionary]:
          return fixture_dangling_exceptions.duplicate(true)
  ```

  The base implementations call `CurrentUiDossierProjector.project(repository_root)` and return the frozen one-row exception respectively; the production CLI instantiates only the base census. The test adapter is valid only for a root strictly beneath `DWM_TEST_ROOT`, and a repository-cohort test uses the base class at `res://`. Add:

  ```gdscript
  func test_valid_reviewed_fixture_census_passes() -> void:
      var fixture := _valid_census_fixture()
      var census := TestCensus.new()
      census.fixture_projection_sha256 = fixture.projection_sha256
      census.fixture_dangling_exceptions = fixture.dangling_exceptions
      var result: Dictionary = census.validate(fixture.root, fixture.artifact_path)
      assert_true(result.ok, JSON.stringify(result.errors))
      var result_keys: Array = result.keys()
      result_keys.sort()
      assert_eq(result_keys, ["artifact_sha256", "counts", "errors", "ok"])
      assert_eq(result.counts.accepted_subjects, 1)
      assert_eq(result.counts.dangling_source_identity_exceptions, 0)
      assert_eq(result.counts.unresolved_references, 0)
  ```

  - [ ] Create the strict fixture root beneath nonempty `DWM_TEST_ROOT`.
  - [ ] Add the one-row strict current-UI ledger and matching accepted dossier.
  - [ ] Compute the fixture projection bytes/digest with production grammar.
  - [ ] Add the predecessor public authority source and exact link projection.
  - [ ] Add the accepted dossier basis section and inclusive-LF section digest.
  - [ ] Add the one exact reconciled requirement body and body digest.
  - [ ] Add the approved specification source and its exact lifecycle fields.
  - [ ] Add the matching approved plan bytes and canonical digest.
  - [ ] Add the strict Beads snapshot containing the one fixture issue.
  - [ ] Add the exact one-row Minesweeper gate source.
  - [ ] Add `TestProjector` with only guarded fixture-seam delegation.
  - [ ] Add `TestCensus` with only the two underscored dependency overrides shown above.
  - [ ] Assert the production base census still calls the public projector and frozen exception source.
  - [ ] Assemble fixture `subject` and `scan_contract` sections.
  - [ ] Assemble the one accepted subject and empty dangling-exception array.
  - [ ] Assemble the one classified occurrence with its exact accepted basis.
  - [ ] Assemble the one reconciliation, one protected plan, and one gate.
  - [ ] Close the fixture artifact with an empty unresolved array and strict JSON bytes.
  - [ ] Add the exact four-key result-envelope assertion.
  - [ ] Add accepted-subject, dangling-exception, and unresolved-count assertions.
  - [ ] Run only `test_valid_reviewed_fixture_census_passes()` and require the behavioral not-implemented failure at RED.
- [ ] **Step 3: Add one reusable census mutation assertion.** Add the shared test helper below; each case deep-copies a fresh valid artifact, applies one mutation, writes strict fixture JSON, and proves one stable error family:

  ```gdscript
  func _assert_census_mutation_fails(fixture: Dictionary, mutate: Callable, prefix: String) -> void:
      var artifact: Dictionary = fixture.artifact.duplicate(true)
      mutate.call(artifact)
      _write_strict_json(fixture.artifact_path, artifact)
      var result := _fixture_census(fixture).validate(fixture.root, fixture.artifact_path)
      assert_false(result.ok)
      assert_true(result.errors.any(
          func(error: Variant) -> bool: return str(error).begins_with(prefix)
      ), JSON.stringify(result.errors))
  ```
- [ ] **Step 4: Add strict encoding and JSON tests.** Create separate named cases for invalid UTF-8, BOM, CRLF, no final LF, and duplicate JSON key. Each calls the checker directly and requires `CURRENT_UI_CENSUS_ENCODING_*`; a permissive parse or exception crash fails the test.
- [ ] **Step 5: Add closed top-level schema tests.** Remove and add each of the fourteen exact top-level keys one at a time, mutate each fixed value/type, and require `CURRENT_UI_CENSUS_SCHEMA_*`. Assert that `dangling_source_identity_exceptions` cannot be omitted even though fixture expectation may be empty.

  - [ ] Add omission rows for `schema_version`, `artifact_id`, `artifact_role`, and `behavior_authority`.
  - [ ] Add omission rows for `cutover_authority`, `subject`, `scan_contract`, and `accepted_subjects`.
  - [ ] Add omission rows for `dangling_source_identity_exceptions`, `reference_occurrences`, and `requirement_reconciliations`.
  - [ ] Add omission rows for `protected_plan_bindings`, `cutover_gates`, and `unresolved_references`.
  - [ ] Add one-extra-key rows beside `schema_version`, `artifact_id`, `artifact_role`, and `behavior_authority`.
  - [ ] Add one-extra-key rows beside `cutover_authority`, `subject`, `scan_contract`, and `accepted_subjects`.
  - [ ] Add one-extra-key rows beside `dangling_source_identity_exceptions`, `reference_occurrences`, and `requirement_reconciliations`.
  - [ ] Add one-extra-key rows beside `protected_plan_bindings`, `cutover_gates`, and `unresolved_references`.
  - [ ] Add wrong-value and wrong-type rows for `schema_version`.
  - [ ] Add wrong-value and wrong-type rows for `artifact_id`.
  - [ ] Add wrong-value and wrong-type rows for `artifact_role`.
  - [ ] Add wrong-value and wrong-type rows for `behavior_authority`.
  - [ ] Add wrong-value and wrong-type rows for `cutover_authority`.
  - [ ] Add wrong-container-type rows for `subject` and `scan_contract`.
  - [ ] Add wrong-container-type rows for `accepted_subjects` and `dangling_source_identity_exceptions`.
  - [ ] Add wrong-container-type rows for `reference_occurrences` and `requirement_reconciliations`.
  - [ ] Add wrong-container-type rows for `protected_plan_bindings`, `cutover_gates`, and `unresolved_references`.
  - [ ] Add the explicit empty-fixture omission row for `dangling_source_identity_exceptions`.
  - [ ] Run the complete top-level case table and require every row to report `CURRENT_UI_CENSUS_SCHEMA_*`.
- [ ] **Step 6: Add nested schema and order tests.** For `subject`, `scan_contract`, accepted subjects, dangling exceptions, classified/unresolved occurrences, reconciliations, protected plans, gates, and every `BasisRecord`, mutate one missing/extra key or wrong type at a time. Separately reject unsorted and duplicate arrays; never silently sort artifact input.

  - [ ] Add the exact-key and wrong-type table for `subject`.
  - [ ] Add the exact-key and wrong-type table for `scan_contract`.
  - [ ] Add the exact-key and wrong-type table for one accepted-subject row.
  - [ ] Add the exact-key and wrong-type table for one dangling-exception row.
  - [ ] Add the exact-key and wrong-type table for one classified-occurrence row.
  - [ ] Add the exact-key and wrong-type table for one unresolved-occurrence row.
  - [ ] Add the exact-key and wrong-type table for one requirement-reconciliation row.
  - [ ] Add the exact-key and wrong-type table for every `BasisRecord` location.
  - [ ] Add the exact-key and wrong-type table for one protected-plan row.
  - [ ] Add the exact-key and wrong-type table for one cutover-gate row.
  - [ ] Add unsorted and duplicate rows for the ordered `scan_contract` collections.
  - [ ] Add unsorted and duplicate rows for `accepted_subjects`.
  - [ ] Add unsorted and duplicate rows for `dangling_source_identity_exceptions`.
  - [ ] Add unsorted and duplicate rows for classified occurrences.
  - [ ] Add unsorted and duplicate rows for unresolved occurrences.
  - [ ] Add unsorted and duplicate rows for `requirement_reconciliations`.
  - [ ] Add unsorted and duplicate rows for `protected_plan_bindings`.
  - [ ] Add unsorted and duplicate rows for `cutover_gates`.
  - [ ] Run the nested-schema table and require every row to fail without mutating artifact order.
- [ ] **Step 7: Add required-root walker tests.** Cover missing, wrong-type, linked root, linked descendant, excluded-path leak, unexpected extension, and an omitted required root. Require `CURRENT_UI_CENSUS_ROOT_*` before occurrence comparison; the Windows directory-junction case is required rather than pending.

  - [ ] Add and run the missing-required-root row.
  - [ ] Add and run the wrong-type-root row.
  - [ ] Add and run the linked-root row.
  - [ ] Add and run the linked-descendant row.
  - [ ] Add and run the excluded-path-leak row.
  - [ ] Add and run the unexpected-extension row.
  - [ ] Add and run the omitted-required-root declaration row.
  - [ ] Require the Windows directory-junction row to execute rather than pend.
  - [ ] Assert every root error is emitted before occurrence comparison.
- [ ] **Step 8: Add projector-equality tests.** Mutate one accepted-subject ID, path, hash, byte count, lifecycle flag, or ledger flag at a time; add/remove/duplicate a row; require `CURRENT_UI_CENSUS_SUBJECT_*` and prove the artifact cannot redefine the projector cohort.

  - [ ] Add and run the accepted-subject ID drift row.
  - [ ] Add and run the accepted-subject path drift row.
  - [ ] Add and run the accepted-subject hash drift row.
  - [ ] Add and run the accepted-subject byte-count drift row.
  - [ ] Add and run the accepted-subject lifecycle-flag drift row.
  - [ ] Add and run the accepted-subject ledger-flag drift row.
  - [ ] Add and run the added accepted-subject row.
  - [ ] Add and run the removed accepted-subject row.
  - [ ] Add and run the duplicated accepted-subject row.
  - [ ] Assert no artifact mutation can redefine the projector cohort.
- [ ] **Step 9: Add ordinary source-pair tests.** For each frozen ID/path field pair, reject unequal lengths, positional mismatch, ID without path, path without ID, unsafe/nonexistent/linked path, invalid source identity/encoding, and duplicate retained provenance ID matches. Require typed `source_id` and `source_path` tokens only after exact validation.

  - [ ] Add and run the unequal-length source-array row.
  - [ ] Add and run the positional ID/path mismatch row.
  - [ ] Add and run the ID-without-path row.
  - [ ] Add and run the path-without-ID row.
  - [ ] Add and run the unsafe source-path row.
  - [ ] Add and run the nonexistent source-path row.
  - [ ] Add and run the linked source-path row.
  - [ ] Add and run the nonregular source-path row.
  - [ ] Add and run the malformed source-identity row.
  - [ ] Add and run the invalid-UTF-8 source row.
  - [ ] Add and run the BOM source row.
  - [ ] Add and run the non-LF source row.
  - [ ] Add and run the duplicate retained-provenance identity row.
  - [ ] Assert that every invalid row emits neither `source_id` nor `source_path` tokens.
- [ ] **Step 10: Prove the dangling exception positive path.** Build one fixture matching the frozen tuple; require Room-Owned Aperture as `source_path`, `spec.room_owned_aperture_v1_design` as `dangling_reference`, and no Room-Owned Aperture `source_id`. Assert the source stays frontmatter-less and the exception does not change resolver results.
- [ ] **Step 11: Add dangling exception drift tests.** Independently mutate source bytes/hash/length/encoding, add YAML frontmatter or an ID, alter the token/effect, alter accepted basis path/range/hash, omit the row, or add a second row. Require `CURRENT_UI_CENSUS_DANGLING_IDENTITY_*`; prove any unrelated path without paired ID remains invalid.

  - [ ] Add and run the source-byte drift row.
  - [ ] Add and run the recorded source-hash drift row.
  - [ ] Add and run the recorded source-length drift row.
  - [ ] Add and run the source-encoding drift row.
  - [ ] Add and run the YAML-frontmatter appearance row.
  - [ ] Add and run the source-ID appearance row.
  - [ ] Add and run the dangling-token drift row.
  - [ ] Add and run the authority-effect drift row.
  - [ ] Add and run the accepted-basis path drift row.
  - [ ] Add and run the accepted-basis line-range drift row.
  - [ ] Add and run the accepted-basis section-hash drift row.
  - [ ] Add and run the missing-exception-row case.
  - [ ] Add and run the second-exception-row case.
  - [ ] Add and run the unrelated-unpaired-path case.
- [ ] **Step 12: Add nonpromotion and retained-provenance tests.** Against `res://`, require exactly the frozen Room-Owned Aperture/Witnessed Scene tuple and at least the accepted dossier's own dangling occurrence; prove `specification_id` resolution for the dangling token is still nonsuccess. Separately require Shared Shell's retained provenance ID to resolve to exactly one strict `source_path` without changing its authority status.

  - [ ] Assert the production cohort has exactly the frozen Room-Owned Aperture/Witnessed Scene exception tuple.
  - [ ] Assert the production scan finds at least the accepted dossier's own dangling-token occurrence.
  - [ ] Resolve the dangling token as `specification_id` and require a nonsuccess result.
  - [ ] Assert Shared Shell's retained provenance ID maps to exactly one strict `source_path`.
  - [ ] Re-resolve that provenance ID and require its preexisting authority status to remain unchanged.
- [ ] **Step 13: Add occurrence-set equality tests.** Independently remove, add, and duplicate a classified or unresolved occurrence and change `canonical_ui_id`, `token_kind`, or `source_token`; require `CURRENT_UI_CENSUS_OCCURRENCE_*`. The union of classified and unresolved keys must equal discovered keys exactly.

  - [ ] Add and run the removed-classified-occurrence row.
  - [ ] Add and run the added-classified-occurrence row.
  - [ ] Add and run the duplicated-classified-occurrence row.
  - [ ] Add and run the removed-unresolved-occurrence row.
  - [ ] Add and run the added-unresolved-occurrence row.
  - [ ] Add and run the duplicated-unresolved-occurrence row.
  - [ ] Add and run the changed-`canonical_ui_id` row.
  - [ ] Add and run the changed-`token_kind` row.
  - [ ] Add and run the changed-`source_token` row.
  - [ ] Assert the successful control has `discovered == classified union unresolved` exactly.
- [ ] **Step 14: Add occurrence coordinate tests.** Mutate one-based line number, same-line ordinal, exact line hash, consumer path, Markdown target/anchor resolution, and longest-token selection. Require the expected stable occurrence/line error without changing semantic disposition.

  - [ ] Add and run the one-based-line-number drift row.
  - [ ] Add and run the same-line-ordinal drift row.
  - [ ] Add and run the exact-line-hash drift row.
  - [ ] Add and run the consumer-path drift row.
  - [ ] Add and run the Markdown target/anchor resolution drift row.
  - [ ] Add and run the longest-token-selection drift row.
  - [ ] Assert coordinate failures do not mutate semantic disposition fields.
- [ ] **Step 15: Add disposition, scope, and basis tests.** Reject unknown/unsorted/duplicate dispositions, empty/multiline scope, and bad basis heading/range/dossier/section hash. For dangling rows, prove consumer-supported repoint, archive-provenance, and routing/census; reject `retain_living_owner`, missing exact non-identity sentence, and a disposition unsupported by the cited consumer basis.

  - [ ] Add and run the unknown ordinary-disposition row.
  - [ ] Add and run the unsorted ordinary-disposition row.
  - [ ] Add and run the duplicate ordinary-disposition row.
  - [ ] Add and run the empty-scope row.
  - [ ] Add and run the multiline-scope row.
  - [ ] Add and run the missing exact-scope row.
  - [ ] Add and run the bad basis-heading row.
  - [ ] Add and run the bad basis-range row.
  - [ ] Add and run the bad basis-dossier-digest row.
  - [ ] Add and run the bad basis-section-digest row.
  - [ ] Add and run one positive dangling repoint row whose consumer basis supports repointing.
  - [ ] Add and run one positive dangling archive-provenance row whose consumer basis supports archival provenance.
  - [ ] Add and run one positive dangling routing/census row whose consumer basis supports routing/census treatment.
  - [ ] Add and run the forbidden dangling `retain_living_owner` row.
  - [ ] Add and run the missing exact non-identity sentence row.
  - [ ] Add and run the consumer-basis/disposition mismatch row.
- [ ] **Step 16: Add requirement reconciliation tests.** Remove, duplicate, or drift each of the five exact body rows and its accepted basis; require `CURRENT_UI_CENSUS_REQUIREMENT_*` and exact body hash from the final packet bytes.

  - [ ] Add removal, duplicate, and body-drift rows for `req.invitation.solo`.
  - [ ] Add the accepted-basis drift row for `req.invitation.solo`.
  - [ ] Add removal, duplicate, and body-drift rows for `req.invitation.group_resolution`.
  - [ ] Add the accepted-basis drift row for `req.invitation.group_resolution`.
  - [ ] Add removal, duplicate, and body-drift rows for `req.save.minesweeper_lock`.
  - [ ] Add the accepted-basis drift row for `req.save.minesweeper_lock`.
  - [ ] Add removal, duplicate, and body-drift rows for `req.minesweeper.round_contract`.
  - [ ] Add the accepted-basis drift row for `req.minesweeper.round_contract`.
  - [ ] Add removal, duplicate, and body-drift rows for `req.desktop.logout`.
  - [ ] Add the accepted-basis drift row for `req.desktop.logout`.
  - [ ] Run the reconciliation table and require every row to compare against the final packet's exact body hash.
- [ ] **Step 17: Add protected-plan tests.** Remove, duplicate, link, path-drift, or digest-drift an approved spec/plan binding and add an unrepresented approved binding; require `CURRENT_UI_CENSUS_PLAN_*` against the Task 0 projection.

  - [ ] Add and run the removed protected-plan binding row.
  - [ ] Add and run the duplicate protected-plan binding row.
  - [ ] Add and run the linked protected-plan path row.
  - [ ] Add and run the protected-plan path-drift row.
  - [ ] Add and run the protected-plan digest-drift row.
  - [ ] Add and run the unrepresented approved binding row.
  - [ ] Assert the successful control equals the Task 0 projection exactly.
- [ ] **Step 18: Add gate and unresolved tests.** Mutate or duplicate the exact Minesweeper gate and require `CURRENT_UI_CENSUS_GATE_*`. Add one well-formed unresolved row and require validation failure with nonzero unresolved count rather than silently classifying or clearing it.

  - [ ] Add and run the Minesweeper gate-field mutation row.
  - [ ] Add and run the duplicate Minesweeper gate row.
  - [ ] Add and run one well-formed unresolved-reference row.
  - [ ] Assert the unresolved-reference case fails with a nonzero unresolved count.
  - [ ] Assert no gate or unresolved row is silently reclassified or cleared.
- [ ] **Step 19: Run RED.** Use:

  ```powershell
  & .\tools\testing\Invoke-IsolatedGodot.ps1 `
    -SuiteId 'ui00-census-red' `
    -LogName 'ui00-census-red.log' `
    -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_current_ui_consumer_census.gd','-gexit') `
    -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  ```

  Expected RED: `test_valid_reviewed_fixture_census_passes` executes and fails with `CURRENT_UI_CENSUS_NOT_IMPLEMENTED`. A missing script, parse/dependency/engine error, or zero tests is not acceptable RED.
- [ ] **Step 20: Declare the pure checker boundaries.** Replace the seam with the same two public signatures and declare these private methods:

  ```text
  const PROJECTOR := preload("res://tools/docs/CurrentUiDossierProjector.gd")
  const STRICT_JSON := preload("res://tools/evidence/EvidenceValidator.gd")

  func _read_strict_json(path: String) -> Dictionary
  func _validate_exact_keys(value: Variant, expected: Array[String], label: String) -> Array[String]
  func _project_current_ui(repository_root: String) -> Dictionary
  func _expected_dangling_source_identity_exceptions() -> Array[Dictionary]
  func _derive_family_tokens(dossier_record: Dictionary) -> Dictionary
  func _derive_source_tokens(repository_root: String, dossier_record: Dictionary) -> Dictionary
  func _validate_dangling_source_identity_exceptions(repository_root: String, value: Variant, projector_records: Array[Dictionary]) -> Dictionary
  func _project_unique_markdown_ids(repository_root: String, scan_contract: Dictionary) -> Dictionary
  func _walk_required_roots(repository_root: String, scan_contract: Dictionary) -> Dictionary
  func _scan_file(repository_root: String, path: String, family_tokens: Dictionary) -> Array[Dictionary]
  func _resolved_markdown_targets(repository_root: String, consumer_path: String, line: String) -> Array[Dictionary]
  func _validate_basis(repository_root: String, value: Variant, projector_records: Array[Dictionary]) -> Array[String]
  func _project_requirement_bodies(repository_root: String) -> Dictionary
  func _project_protected_plans(repository_root: String) -> Dictionary
  func _inventory_result(ok: bool, occurrences: Array[Dictionary], errors: Array[String]) -> Dictionary
  func _validation_result(ok: bool, counts: Dictionary, artifact_sha256: String, errors: Array[String]) -> Dictionary
  ```

  Do not expose a write/generate method and do not read live `.beads/issues.jsonl`.
- [ ] **Step 21: Implement strict artifact reading, exact keys, and result constructors.** `_read_strict_json()` strict-reads UTF-8/no-BOM/LF/final-LF bytes, calls `EvidenceValidator.parse_strict_text()`, and returns raw bytes/hash plus parsed value/errors. `_validate_exact_keys()` compares ordinal-sorted actual/expected key arrays without mutation. `_inventory_result()` and `_validation_result()` construct only their frozen envelopes and sort copied errors before return.

  - [ ] Implement `_read_strict_json()` without changing another helper.
  - [ ] Run only the encoding and duplicate-JSON-key tests against `_read_strict_json()`.
  - [ ] Implement `_validate_exact_keys()` without changing another helper.
  - [ ] Run only the closed-schema tests against `_validate_exact_keys()`.
  - [ ] Implement `_inventory_result()` with only its frozen envelope.
  - [ ] Run only the inventory result-shape and error-order assertions.
  - [ ] Implement `_validation_result()` with only its frozen envelope.
  - [ ] Run only the validation result-shape and error-order assertions.
- [ ] **Step 22: Implement production projector and exception seams.** `_project_current_ui(repository_root)` returns only `PROJECTOR.new().project(repository_root)`. `_expected_dangling_source_identity_exceptions()` returns a deep copy of the frozen one-row constant. There is no setter; test overrides work only with the guarded projector under `DWM_TEST_ROOT`, while the production CLI instantiates the base class.
- [ ] **Step 23: Implement required-root traversal.** Validate every root and exclusion before walking; reject every reparse point in its chain; enumerate eligible regular files recursively in ordinal repository-path order; require only frozen extensions; and remove exact exclusions before scanning. Return `{ok,paths,errors}` and never treat a missing root as empty.

  - [ ] Implement required-root existence, type, safety, and repository-boundary validation.
  - [ ] Implement exclusion-path safety and required-root containment validation.
  - [ ] Implement reparse-point rejection for every root and exclusion path segment.
  - [ ] Run only the root/exclusion/link preflight tests.
  - [ ] Implement recursive enumeration without following a link or reparse point.
  - [ ] Filter enumerated entries to regular files with the frozen extensions.
  - [ ] Remove exact exclusions and reject an excluded-path leak.
  - [ ] Ordinal-sort copied repository-relative paths and construct `{ok,paths,errors}`.
  - [ ] Run only the traversal, extension, exclusion, and deterministic-order tests.
- [ ] **Step 24: Implement deterministic typed scanning.** Sort family tokens longest-byte-length first then ordinal; read each file once; split exact LF lines; on every nonoverlapping exact token match emit `(canonical_ui_id,token_kind,source_token,consumer_path,line_number,match_ordinal,line_sha256)`. Resolve Markdown targets against the containing path with anchors removed; do not attach disposition, scope, or basis during discovery.

  - [ ] Implement copied token ordering by descending byte length and then ordinal value.
  - [ ] Run only the overlapping-token precedence test.
  - [ ] Implement one strict read and exact LF-line split per consumer file.
  - [ ] Implement nonoverlapping plain-token matching within one line.
  - [ ] Implement same-line ordinal assignment for repeated token matches.
  - [ ] Implement one-based line number and exact line-SHA emission.
  - [ ] Implement `_resolved_markdown_targets()` with containing-path resolution and anchor removal.
  - [ ] Emit the frozen typed occurrence tuple without semantic fields.
  - [ ] Run only the scanner coordinate, Markdown-resolution, and no-semantic-field tests.
- [ ] **Step 25: Implement ordinary pairs, provenance, and the frozen exception.** `_derive_source_tokens()` positionally zips each ordinary ID/path array and validates both before emitting `source_id`/`source_path`. `_project_unique_markdown_ids()` supplies the unique retained-provenance ID-to-path lookup. `_validate_dangling_source_identity_exceptions()` requires exact artifact/compiled tuple equality, R bytes/no-frontmatter state, W accepted basis, and emits only the frozen path/dangling token pair.

  - [ ] Implement `_derive_source_tokens()` without changing another helper.
  - [ ] Run only the ordinary-pair tests against `_derive_source_tokens()`.
  - [ ] Implement `_project_unique_markdown_ids()` without changing another helper.
  - [ ] Run only the retained-provenance tests against `_project_unique_markdown_ids()`.
  - [ ] Implement `_validate_dangling_source_identity_exceptions()` without changing another helper.
  - [ ] Run only the dangling-exception positive and drift tests against that helper.
- [ ] **Step 26: Implement coverage and semantic-basis validation.** Build exact occurrence-key sets for discovered, classified, and unresolved rows; reject any duplicate before union; then enforce `discovered_keys == classified_keys union unresolved_keys`. `_validate_basis()` binds heading/range/hash to exact accepted projector bytes. Validate each disposition/scope against that basis, including dangling non-identity and consumer-specific treatment.

  - [ ] Implement discovered/classified/unresolved occurrence-key construction.
  - [ ] Implement duplicate-key rejection before any set union.
  - [ ] Implement exact occurrence-set equality.
  - [ ] Run only the occurrence add/remove/duplicate tests.
  - [ ] Implement `_validate_basis()` without adding disposition logic.
  - [ ] Run only the basis heading/range/digest drift tests.
  - [ ] Implement ordinary disposition and scope semantics.
  - [ ] Run only the ordinary disposition/scope tests.
  - [ ] Implement dangling non-identity and consumer-specific semantics.
  - [ ] Run only the dangling semantic tests.
- [ ] **Step 27: Implement requirements, protected plans, and the gate.** `_project_requirement_bodies()` hashes the five exact Task 3 bodies after packet edits. `_project_protected_plans()` reproduces Task 0's strict approved binding set. Compare both arrays exactly, then require the sole Minesweeper gate tuple and zero unresolved rows for success.

  - [ ] Implement `_project_requirement_bodies()` without changing another helper.
  - [ ] Run only the requirement-reconciliation tests.
  - [ ] Implement `_project_protected_plans()` without changing another helper.
  - [ ] Run only the protected-plan tests.
  - [ ] Implement the one-row Minesweeper gate comparison.
  - [ ] Run only the gate mutation and duplication tests.
  - [ ] Implement the zero-unresolved success guard.
  - [ ] Run only the unresolved-reference failure/count test.
- [ ] **Step 28: Complete `inventory()` and `validate()` orchestration.** `inventory()` executes projector → token/exception derivation → root walk → scan → sorted occurrence envelope. `validate()` executes strict artifact/schema → subject → projector/accepted subjects → exception → fresh inventory → occurrence coverage/bases → requirements/plans/gate → counts/raw hash. Collect deterministic errors within a stage, stop dependent stages after invalid prerequisites, sort once at return, and never write.

  - [ ] Implement `inventory()` through projector and token/exception derivation.
  - [ ] Complete `inventory()` with root walk, scan, sort, and its frozen result envelope.
  - [ ] Run only the inventory positive, walker, and scanner tests.
  - [ ] Implement `validate()` through strict artifact/schema and subject validation.
  - [ ] Extend `validate()` through projector, accepted-subject, exception, and fresh-inventory validation.
  - [ ] Extend `validate()` through occurrence coverage and basis validation.
  - [ ] Complete `validate()` with requirement, plan, gate, unresolved, count, and raw-hash validation.
  - [ ] Run only the reviewed-fixture positive test and stage-dependency failure tests.
  - [ ] Assert both public methods are read-only and return deterministically sorted errors.
- [ ] **Step 29: Implement the read-only CLI.** `validate_current_ui_consumer_census.gd` extends `SceneTree`, reads `OS.get_cmdline_user_args()`, and accepts only these exact shapes:

  ```gdscript
  match Array(OS.get_cmdline_user_args()):
      ["--inventory"]:
          _run_inventory()
      ["--check", "--input=res://evidence/current_ui/authority/ui_00_consumer_census.v1.json"]:
          _run_check("res://evidence/current_ui/authority/ui_00_consumer_census.v1.json")
      _:
          printerr("CURRENT_UI_CENSUS_ARGS")
          quit(2)
  ```

  Inventory prints `CURRENT_UI_CENSUS_INVENTORY: ` plus one-line JSON. Check prints `CURRENT_UI_CENSUS: PASS accepted=%d dangling=%d references=%d reconciliations=%d plans=%d gates=%d unresolved=0 sha256=%s`. Bad arguments exit 2, invalid evidence exits 1 after sorted stderr errors, and success exits 0. No branch writes a file.
- [ ] **Step 30: Run fixture GREEN.** Repeat Step 19 with SuiteId `ui00-census-fixture-green` and log `ui00-census-fixture-green.log`. Require every rejection test to execute and zero failures, engine errors, or pending required link cases. Require the derived token report to contain the Room-Owned Aperture `source_path` plus distinct dangling-reference token under `canon.current_ui.witnessed_scene`, no invented Room-Owned Aperture `source_id`, and the Title/Caption provenance `source_id`/`source_path` pair under `canon.current_ui.shared_shell`; any mismatch is a failed census, not an unresolved semantic row.
- [ ] **Step 31: Freeze the registered Beads input.** After re-verifying the one actual UI-00 issue, run:

  ```powershell
  & .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath 'evidence/current_ui/authority/ui_00_beads_registration.v1.json'
  ```

  Expected: `BEADS_SNAPSHOT: PASS records=` followed by a positive decimal count. Strict-read it, require the actual UI-00 issue exactly once, and record its raw SHA-256 for `subject.beads_snapshot_sha256`.
- [ ] **Step 32: Inventory mechanically.** Define the exact marker extractor in the active PowerShell session and run the inventory through it:

  ```powershell
  function Invoke-Ui00GodotMarker {
    param(
      [Parameter(Mandatory = $true)][string]$SuiteId,
      [Parameter(Mandatory = $true)][string]$LogName,
      [Parameter(Mandatory = $true)][string[]]$GodotArgs,
      [Parameter(Mandatory = $true)][string]$MarkerPrefix
    )
    $runnerOutput = @(& .\tools\testing\Invoke-IsolatedGodot.ps1 `
      -SuiteId $SuiteId `
      -LogName $LogName `
      -GodotArgs $GodotArgs `
      -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl')
    if ($LASTEXITCODE -ne 0) { throw "UI00_GODOT_EXIT: $SuiteId exit=$LASTEXITCODE" }
    if ($runnerOutput.Count -ne 1) { throw "UI00_RUNNER_RECORD_COUNT: $SuiteId count=$($runnerOutput.Count)" }
    try { $record = $runnerOutput[0] | ConvertFrom-Json } catch { throw "UI00_RUNNER_RECORD_JSON: $SuiteId" }
    if ([string]$record.suite_id -cne $SuiteId -or [int]$record.exit_code -ne 0) { throw "UI00_RUNNER_RECORD_MISMATCH: $SuiteId" }
    if ($null -eq $record.log_path -or [string]::IsNullOrWhiteSpace([string]$record.log_path)) { throw "UI00_RUNNER_LOG_PATH: $SuiteId" }
    $logPath = [string]$record.log_path
    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { throw "UI00_RUNNER_LOG_MISSING: $SuiteId" }
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $logBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $logPath))
    if ($logBytes.Length -ge 3 -and $logBytes[0] -eq 0xEF -and $logBytes[1] -eq 0xBB -and $logBytes[2] -eq 0xBF) { throw "UI00_RUNNER_LOG_BOM: $SuiteId" }
    try { $logText = $strictUtf8.GetString($logBytes) } catch { throw "UI00_RUNNER_LOG_UTF8: $SuiteId" }
    if ($logText.Contains("`r")) { throw "UI00_RUNNER_LOG_CR: $SuiteId" }
    $markers = @($logText.Split("`n") | Where-Object { $_.StartsWith($MarkerPrefix, [StringComparison]::Ordinal) })
    if ($markers.Count -ne 1) { throw "UI00_MARKER_COUNT: $SuiteId count=$($markers.Count)" }
    return [string]$markers[0]
  }

  $inventoryLine = Invoke-Ui00GodotMarker `
    -SuiteId 'ui00-census-inventory' `
    -LogName 'ui00-census-inventory.log' `
    -GodotArgs @('-s','res://tools/evidence/validate_current_ui_consumer_census.gd','--','--inventory') `
    -MarkerPrefix 'CURRENT_UI_CENSUS_INVENTORY: '
  $inventoryJson = $inventoryLine.Substring('CURRENT_UI_CENSUS_INVENTORY: '.Length)
  . .\tools\testing\Read-StrictJson.ps1
  $null = ConvertFrom-Phase2RStrictJson -Json $inventoryJson -Label 'UI-00 census inventory marker'
  $inventoryLine
  ```

  Expected: exactly one deterministic `CURRENT_UI_CENSUS_INVENTORY:` record read from the Godot log named by the isolated runner's JSON record, containing sorted occurrence keys and no semantic disposition. Zero or multiple markers stop. Capture it in the review transcript; do not redirect it into an authority file.

  Before classification, split each family's sorted occurrence list into review chunks of at most three rows; any chunk whose rows need different basis logic contains exactly one row. Materialize one unchecked executable checkbox in the review transcript for every concrete chunk, naming the family and first/last occurrence key. One action classifies only one such chunk and records its exact bases or unresolved rows before checking that transcript box. Steps 33–42 are rollups only and close only after every materialized chunk beneath that family is checked. Never classify an unrecorded batch or more than one chunk in one action; this preserves the literal two-to-five-minute bound without inventing the still-unknown occurrence count in this plan.
- [ ] **Step 33: Classify Global UI Grammar occurrences.** For every discovered row assigned to `canon.current_ui.global_ui_grammar`, transcribe only dispositions entailed by its Sections 1.3, 1.4, 18.3, 19.4, or 19.5; bind each row to one exact `BasisRecord`. Put ambiguity into `unresolved_references`.
- [ ] **Step 34: Classify Contacts occurrences.** Use only Contacts Sections 1.2, 1.3, 17.1, 17.2, or 17.5 as bases; do not infer reply-era runtime conformance.
- [ ] **Step 35: Classify Shared Shell occurrences.** Use only Shared Shell Sections 1.1, 1.2, 15.4, 17.1, 17.3, 17.4, or 17.7; preserve living mixed owners.
- [ ] **Step 36: Classify Gallery occurrences.** Use only Gallery Sections 1.1, 1.2, 1.3, 16, or 17.1; keep Rehearsal references retained/deferred.
- [ ] **Step 37: Classify Witnessed Scene occurrences.** Use only Witnessed Scene Sections 1.2, 1.3, 1.4, 19, or 20 for ordinary tokens. For `dangling_reference`, rely on the compiled Section 1.1 exception for the non-identity invariant, then put exactly one consumer-treatment `BasisRecord` in the row: Section 1.4/20 for repoint or archive provenance, or Section 1.1 itself for an explanatory routing/census mention. Preserve retained scene/ending/plan ownership and never identify Room-Owned Aperture by the dangling token.
- [ ] **Step 38: Classify Shop occurrences.** Use only Shop Sections 1.1, 1.2, 16.5, 17.1, 17.2, 17.3, 17.4, or 17.6; preserve transaction/mechanics owners.
- [ ] **Step 39: Classify Backup occurrences.** Use only Backup Sections 1.1, 1.2, 17.1, 17.2, 17.3, or 17.4; preserve persistence and external-owner law.
- [ ] **Step 40: Classify Settings occurrences.** Use only Settings Sections 1.1, 1.2, 1.3, 17, 18.1, or 18.3; preserve profile/localization/input ownership.
- [ ] **Step 41: Classify Schedule occurrences.** Use only Schedule Sections 1.1, 1.2, 1.3, 16, 17.1, 17.2, or 17.3; preserve deeper date/board-fate ownership.
- [ ] **Step 42: Classify Minesweeper occurrences.** Use only Minesweeper Sections 1.2, 1.3, 1.4, 19, 20.1, 20.2, 20.3, 20.4, or 20.5; preserve generator/session/persistence owners and the pending visual Standard gate.
- [ ] **Step 43: Add non-reference evidence rows.** Populate the ten projector-derived accepted subjects, the exact one-row dangling-source exception, five Task 3 requirement reconciliations, every approved spec/plan binding discovered at the same base, the exact Minesweeper cutover gate, and the exact `subject`/`scan_contract`. All semantic rows must have accepted bases; a missing proof remains unresolved.

  - [ ] Populate `subject` from the frozen base, approved plan, Beads snapshot, and INDEX evidence.
  - [ ] Populate `scan_contract` with the exact roots, exclusions, extensions, and matching rules.
  - [ ] Add accepted subjects for Backup, Contacts, and Gallery from the projector result.
  - [ ] Add accepted subjects for Global UI Grammar, Minesweeper, and Schedule.
  - [ ] Add accepted subjects for Settings, Shared Shell, and Shop.
  - [ ] Add the Witnessed Scene accepted subject and re-sort the ten-row array ordinally.
  - [ ] Add the exact one-row dangling-source-identity exception.
  - [ ] Add the `req.invitation.solo` reconciliation and accepted basis.
  - [ ] Add the `req.invitation.group_resolution` reconciliation and accepted basis.
  - [ ] Add the `req.save.minesweeper_lock` reconciliation and accepted basis.
  - [ ] Add the `req.minesweeper.round_contract` reconciliation and accepted basis.
  - [ ] Add the `req.desktop.logout` reconciliation and accepted basis.
  - [ ] Split the sorted protected-plan projection into chunks of at most three rows and materialize one executable review-transcript checkbox per chunk.
  - [ ] Copy exactly one protected-plan chunk into the review buffer and check only that chunk's transcript box; repeat this action until none remain.
  - [ ] Add the exact one-row Minesweeper cutover gate.
  - [ ] Run the focused mechanical-projection assertions for subject, scan contract, accepted subjects, exception, reconciliations, protected plans, and gate before transferring any classified occurrence row into the authority artifact.
  - [ ] Transfer reviewed occurrence chunks only after every mechanical-projection assertion passes; any missing accepted basis remains in `unresolved_references`.
- [ ] **Step 44: Resolve or stop on ambiguity.** Present every `unresolved_references` row to the owner as a genuine conflict question. Apply only owner-resolved classifications with `apply_patch`; never guess. Do not proceed while this array is nonempty.
- [ ] **Step 45: Author the reviewed artifact.** Use `apply_patch` to create strict UTF-8/LF/final-LF JSON with exactly the closed schema, sorted arrays, all reviewed rows, and `unresolved_references: []`. Do not use the inventory tool or Python to write it.

  - [ ] Use `apply_patch` to create the closed-key JSON skeleton with fixed values, `subject`, and `scan_contract` only; keep every not-yet-populated array present and empty.
  - [ ] Patch accepted subjects for Backup, Contacts, and Gallery into ordinal position.
  - [ ] Patch accepted subjects for Global UI Grammar, Minesweeper, and Schedule into ordinal position.
  - [ ] Patch accepted subjects for Settings, Shared Shell, and Shop into ordinal position.
  - [ ] Patch the Witnessed Scene accepted subject and exact dangling-source exception.
  - [ ] Materialize one unchecked authoring-transcript checkbox per reviewed occurrence chunk, preserving the Step 32 limit of at most three rows and exactly one mixed-basis row.
  - [ ] Patch exactly one reviewed occurrence chunk into ordinal position and check only its authoring-transcript box; repeat this action until none remain.
  - [ ] Patch reconciliations for solo invitation, group resolution, and save lock.
  - [ ] Patch reconciliations for round contract and desktop Logout.
  - [ ] Materialize one unchecked authoring-transcript checkbox per sorted protected-plan chunk of at most three rows.
  - [ ] Patch exactly one protected-plan chunk into ordinal position and check only its authoring-transcript box; repeat this action until none remain.
  - [ ] Patch the exact one-row Minesweeper cutover gate.
  - [ ] Reconcile the artifact's occurrence-key union against the reviewed transcript.
  - [ ] Set `unresolved_references` to the reviewed empty array only after every materialized chunk is checked.
  - [ ] Strict-read the completed bytes and require UTF-8 without BOM, LF-only, final LF, exact keys, and ordinal arrays.
  - [ ] Run Step 46 immediately; any failure returns to only the owning materialized chunk or mechanical section.
- [ ] **Step 46: Run the repository checker.** Define the exact `Invoke-Ui00GodotMarker` helper from Step 32 in the active PowerShell session if it is not already present, then use:

  ```powershell
  $passLine = Invoke-Ui00GodotMarker `
    -SuiteId 'ui00-consumer-census' `
    -LogName 'ui00-consumer-census.log' `
    -GodotArgs @('-s','res://tools/evidence/validate_current_ui_consumer_census.gd','--','--check','--input=res://evidence/current_ui/authority/ui_00_consumer_census.v1.json') `
    -MarkerPrefix 'CURRENT_UI_CENSUS: PASS '
  $passLine
  ```

  Expected GREEN: one deterministic PASS line with ten accepted subjects, one dangling-source exception, five reconciliations, one cutover gate, zero unresolved rows, exact discovered reference/protected-plan counts, and raw artifact digest; no write occurs.
- [ ] **Step 47: Rerun the unit suite.** Repeat Step 19 with SuiteId `ui00-census-green` and log `ui00-census-green.log`. Require zero uncovered, phantom, or unresolved references.
- [ ] **Step 48: Obtain independent semantic review.** A fresh reviewer checks every disposition/scope against its exact accepted basis, with special attention to multi-disposition occurrences, frozen cross-dossier references, and still-living mixed authorities. Mechanical checker success alone is insufficient; any P0/P1 returns to the owning family step.

  - [ ] Materialize one unchecked semantic-review transcript checkbox for every Step 32 occurrence chunk; preserve the at-most-three-row limit and exactly one row for mixed basis logic.
  - [ ] Have a fresh reviewer check exactly one materialized chunk's dispositions, scope sentences, basis coordinates, and section hashes, then check only that review box; repeat this action until none remain.
  - [ ] Materialize separate at-most-three-row review chunks for frozen cross-dossier occurrences.
  - [ ] Review exactly one frozen cross-dossier chunk and check only its box; repeat until none remain.
  - [ ] Materialize separate at-most-three-row review chunks for still-living mixed-authority occurrences.
  - [ ] Review exactly one mixed-authority chunk and check only its box; repeat until none remain.
  - [ ] Return every P0/P1 to its owning family and authoring chunk, then rerun only the affected checker gates.
  - [ ] Check the Step 48 rollup only when every materialized review box is checked and no P0/P1 remains.
- [ ] **Step 49: Conditional commit.** Invoke the Task 4 ordered map and exact helper command in “Shared Conditional Exact-Path Commit Procedure.” Skip it when permission is absent.

---

### Task 5: Run the UI-00 Exit Gate

**Files:**

- Verification only, except execution logs already named above.

**Interfaces:**

- Consumes: Tasks 1–4 committed or explicitly verified-uncommitted outputs, immutable custody inputs, one fresh Beads read, and every approval/permission gate.
- Produces: a final UI-00 evidence result and, only after all durable/versioned gates pass, closure of the actual UI-00 Beads issue; no runtime or cutover interface.

- [ ] **Step 1: Recheck immutable inputs.** Repeat Task 0 Steps 1, 3, and 4 verbatim against the same implementation base; require identical plan binding, all eleven raw hashes/encoding facts, acceptance-projection digest, and protected-plan rows.

  - [ ] Repeat Task 0 Step 1 and require the same approved plan binding and implementation base.
  - [ ] Repeat Task 0 Step 3 and require all eleven raw hashes, byte counts, and encoding facts plus the acceptance projection to match.
  - [ ] Repeat Task 0 Step 4 and require the protected-plan projection to match.
  - [ ] Compare the three rerun records to their entry evidence and check this rollup only when all are identical.
- [ ] **Step 2: Run focused authority tooling.** Use:

  ```powershell
  & .\tools\testing\Invoke-IsolatedGodot.ps1 `
    -SuiteId 'ui00-authority-focused' `
    -LogName 'ui00-authority-focused.log' `
    -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_current_ui_dossier_projector.gd,res://tests/unit/tooling/test_agent_workflow_authority_resolver.gd,res://tests/unit/tooling/test_agent_workflow_validator.gd,res://tests/unit/tooling/test_current_ui_requirement_reconciliation.gd,res://tests/unit/tooling/test_current_ui_consumer_census.gd,res://tests/unit/tooling/test_doc_frontmatter.gd,res://tests/unit/tooling/test_doc_validator.gd','-gexit') `
    -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  ```
- [ ] **Step 3: Run the complete tooling regression.** Use:

  ```powershell
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-tooling-regression' -LogName 'ui00-tooling-regression.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests/unit/tooling','-ginclude_subdirs','-gexit') -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  ```

  Expected: every discovered script executes with zero failures/errors; only pending tests fingerprinted before UI-00 may remain, and the required directory-link tests are not pending.
- [ ] **Step 4: Run document CLIs with one fresh snapshot.** Use one export for all commands:

  ```powershell
  & .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/ui00-final-read.json'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-final-index' -LogName 'ui00-final-index.log' -GodotArgs @('-s','res://tools/docs/generate_index.gd','--','--beads-snapshot=res://.godot/beads/ui00-final-read.json') -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-final-docs' -LogName 'ui00-final-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/ui00-final-read.json') -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  & .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'ui00-final-workflow' -LogName 'ui00-final-workflow.log' -GodotArgs @('-s','res://tools/docs/validate_agent_workflow.gd','--','--beads-snapshot=res://.godot/beads/ui00-final-read.json') -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl'
  if ((Get-FileHash -LiteralPath 'prompt_docs/INDEX.md' -Algorithm SHA256).Hash.ToLowerInvariant() -cne 'd4c24033eea0a6ffd2e16be1e5c8000ea4980997f7408ad24e5ee198587995c3') { throw 'UI00_FINAL_INDEX_DRIFT' }
  ```

  Expected markers: `BEADS_SNAPSHOT: PASS`, `DOC_INDEX: PASS`, `DOC_VALIDATION: PASS`, and `AGENT_WORKFLOW_VALIDATION: PASS`.

  - [ ] Export `.godot/beads/ui00-final-read.json` and require its single `BEADS_SNAPSHOT: PASS` marker.
  - [ ] Run index generation against that exact snapshot and require `DOC_INDEX: PASS`.
  - [ ] Run document validation against that exact snapshot and require `DOC_VALIDATION: PASS`.
  - [ ] Run workflow validation against that exact snapshot and require `AGENT_WORKFLOW_VALIDATION: PASS`.
  - [ ] Hash `prompt_docs/INDEX.md` and require `d4c24033eea0a6ffd2e16be1e5c8000ea4980997f7408ad24e5ee198587995c3`.
  - [ ] Check the Step 4 rollup only when all four commands consumed the same snapshot bytes and every marker/hash matched.
- [ ] **Step 5: Run the census checker twice.** Prove stable output and no artifact rewrite:

  ```powershell
  function Invoke-Ui00GodotMarker {
    param(
      [Parameter(Mandatory = $true)][string]$SuiteId,
      [Parameter(Mandatory = $true)][string]$LogName,
      [Parameter(Mandatory = $true)][string[]]$GodotArgs,
      [Parameter(Mandatory = $true)][string]$MarkerPrefix
    )
    $runnerOutput = @(& .\tools\testing\Invoke-IsolatedGodot.ps1 `
      -SuiteId $SuiteId `
      -LogName $LogName `
      -GodotArgs $GodotArgs `
      -EvidenceLogPath 'evidence/current_ui/logs/isolated-godot.jsonl')
    if ($LASTEXITCODE -ne 0) { throw "UI00_GODOT_EXIT: $SuiteId exit=$LASTEXITCODE" }
    if ($runnerOutput.Count -ne 1) { throw "UI00_RUNNER_RECORD_COUNT: $SuiteId count=$($runnerOutput.Count)" }
    try { $record = $runnerOutput[0] | ConvertFrom-Json } catch { throw "UI00_RUNNER_RECORD_JSON: $SuiteId" }
    if ([string]$record.suite_id -cne $SuiteId -or [int]$record.exit_code -ne 0) { throw "UI00_RUNNER_RECORD_MISMATCH: $SuiteId" }
    if ($null -eq $record.log_path -or [string]::IsNullOrWhiteSpace([string]$record.log_path)) { throw "UI00_RUNNER_LOG_PATH: $SuiteId" }
    $logPath = [string]$record.log_path
    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) { throw "UI00_RUNNER_LOG_MISSING: $SuiteId" }
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $logBytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $logPath))
    if ($logBytes.Length -ge 3 -and $logBytes[0] -eq 0xEF -and $logBytes[1] -eq 0xBB -and $logBytes[2] -eq 0xBF) { throw "UI00_RUNNER_LOG_BOM: $SuiteId" }
    try { $logText = $strictUtf8.GetString($logBytes) } catch { throw "UI00_RUNNER_LOG_UTF8: $SuiteId" }
    if ($logText.Contains("`r")) { throw "UI00_RUNNER_LOG_CR: $SuiteId" }
    $markers = @($logText.Split("`n") | Where-Object { $_.StartsWith($MarkerPrefix, [StringComparison]::Ordinal) })
    if ($markers.Count -ne 1) { throw "UI00_MARKER_COUNT: $SuiteId count=$($markers.Count)" }
    return [string]$markers[0]
  }

  $artifactPath = 'evidence/current_ui/authority/ui_00_consumer_census.v1.json'
  $before = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $first = Invoke-Ui00GodotMarker -SuiteId 'ui00-census-repeat-a' -LogName 'ui00-census-repeat-a.log' -GodotArgs @('-s','res://tools/evidence/validate_current_ui_consumer_census.gd','--','--check','--input=res://evidence/current_ui/authority/ui_00_consumer_census.v1.json') -MarkerPrefix 'CURRENT_UI_CENSUS: PASS '
  $middle = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $second = Invoke-Ui00GodotMarker -SuiteId 'ui00-census-repeat-b' -LogName 'ui00-census-repeat-b.log' -GodotArgs @('-s','res://tools/evidence/validate_current_ui_consumer_census.gd','--','--check','--input=res://evidence/current_ui/authority/ui_00_consumer_census.v1.json') -MarkerPrefix 'CURRENT_UI_CENSUS: PASS '
  $after = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($before -cne $middle -or $middle -cne $after) { throw 'UI00_CENSUS_REWRITE' }
  if ($first -cne $second) { throw 'UI00_CENSUS_NONDETERMINISTIC' }
  $first
  ```

  Expected: exactly one PASS marker in each named Godot log, identical marker lines, and one unchanged raw digest; zero/multiple markers or empty wrapper output cannot pass vacuously.
- [ ] **Step 6: Verify discovery without cutover.** Resolve all ten `canonical_ui_id` values; require every success envelope exact. Then assert every dossier still declares the nonbinding authority effect and no live capability intention, runtime route, or family authority map was repointed by UI-00.

  - [ ] Resolve Backup, Contacts, and Gallery IDs and compare their exact success envelopes.
  - [ ] Resolve Global UI Grammar, Minesweeper, and Schedule IDs and compare their exact success envelopes.
  - [ ] Resolve Settings, Shared Shell, and Shop IDs and compare their exact success envelopes.
  - [ ] Resolve Witnessed Scene and compare its exact success envelope.
  - [ ] Verify all ten dossiers still declare the frozen nonbinding authority effect.
  - [ ] Verify every live `capability_intentions.authority_links` surface remains unrepointed by UI-00.
  - [ ] Verify every runtime route remains unrepointed by UI-00.
  - [ ] Verify every family authority map remains unrepointed by UI-00.
  - [ ] Check the Step 6 rollup only after discovery succeeds and all four no-cutover surfaces remain unchanged.
- [ ] **Step 7: Verify evidence applicability.** Record authority and focused tooling evidence as required. Record runtime behavior, scene, visual/accessibility, persistence, and cross-family integration evidence as `not applicable: UI-00 performs no runtime mutation or cutover`, not as passed conformance.
- [ ] **Step 8: Inspect the exact diff.** Run `git diff --check`, `git diff --cached --name-status`, and `git status --short`; compare the result to the exact per-task path maps and separately authorized commits. Run `git diff --exit-code --` for the eleven custody paths, every pre-existing approved plan, `Prompt.md`, `tools/docs/DocValidator.gd`, `tools/docs/DocIndexGenerator.gd`, `autoload`, `scenes`, and `scripts`. Require no current-UI dossier/README edit, existing-plan edit, runtime/scene mutation, source movement/archive edit, broad staged path, or direct `.beads/issues.jsonl` edit by the executor.

  - [ ] Run `git diff --check` and resolve only UI-00-owned whitespace errors.
  - [ ] Run `git diff --cached --name-status` and compare staged paths to separately authorized exact-path commits.
  - [ ] Run `git status --short` and retain unrelated pre-existing owner changes in the allowed dirty-set comparison.
  - [ ] Compare every UI-00-owned path to the exact per-task path map.
  - [ ] Run the custody diff check for README plus the ten accepted dossiers.
  - [ ] Run the diff check for every pre-existing approved implementation plan.
  - [ ] Run the diff check for `Prompt.md`, `DocValidator.gd`, and `DocIndexGenerator.gd`.
  - [ ] Run separate diff checks for `autoload`, `scenes`, and `scripts`.
  - [ ] Verify no source path moved and no superseded/archive record changed.
  - [ ] Verify the executor did not edit `.beads/issues.jsonl` directly.
  - [ ] Check the Step 8 rollup only when status, staging, task maps, custody, runtime trees, source/archive state, and Beads ownership all match their allowed sets.
- [ ] **Step 9: Obtain a fresh independent audit.** Reviewer checks spec coverage, public resolver/constructor compatibility, error precedence, acceptance-projection stability, admission/permission separation, five behavior-rule plus three authority-context bodies, census semantic bases, immutable bytes, and absence of cutover/runtime claims. Resolve every P0/P1 within scope and rerun affected gates.

  - [ ] Review roadmap/plan specification coverage and every explicit exclusion.
  - [ ] Review public resolver envelopes and constructor compatibility.
  - [ ] Review error precedence and acceptance-projection stability.
  - [ ] Review admission validation and permission-state separation.
  - [ ] Review the five exact behavior-rule bodies.
  - [ ] Review the three exact authority-context bodies.
  - [ ] Review census dispositions/scopes against accepted semantic bases.
  - [ ] Review immutable custody bytes and protected-plan bindings.
  - [ ] Review every statement for accidental cutover or runtime-conformance claims.
  - [ ] Resolve each P0/P1 in its owning task and rerun only affected gates.
  - [ ] Check the Step 9 rollup only after all review boxes pass with zero P0/P1.
- [ ] **Step 10: Conditional final log-evidence commit.** If the isolated JSONL log is explicitly commit-authorized, invoke the Task 5 ordered map and exact helper command in “Shared Conditional Exact-Path Commit Procedure.” Otherwise leave that optional diagnostic log uncommitted and report it; the reviewed Task 4 census remains the required committed evidence artifact.
- [ ] **Step 11: Close only with full authority.** With separately granted Beads closure permission, derive the actual ID from the registered snapshot, verify its immutable descriptive fields still match, close it, and read it back:

  ```powershell
  $issues = @(Get-Content -Raw -LiteralPath 'evidence/current_ui/authority/ui_00_beads_registration.v1.json' | ConvertFrom-Json)
  $matches = @($issues | Where-Object { $_.title -ceq 'UI-00 — Current UI authority readiness' })
  if ($matches.Count -ne 1) { throw "UI00_BEADS_ISSUE_COUNT: $($matches.Count)" }
  $ui00IssueId = [string]$matches[0].id
  bd show $ui00IssueId --json --readonly
  bd close $ui00IssueId --reason 'UI-00 authority readiness evidence complete; no runtime or cutover performed.'
  bd show $ui00IssueId --json --readonly
  ```

  Expected: the final read reports closed status while title, description, metadata, roadmap/plan binding, scope, exclusions, and authority references equal the captured record. Do not close if commit permission was withheld, required commits are absent, descriptive fields drifted, or Beads remains unavailable.

---

## Exit Criteria

UI-00 is complete only when all of the following are true:

- the countersigned README, stable acceptance-binding projection, and ten accepted dossiers are durably tracked at their exact hashes;
- every accepted ID resolves uniquely through `canonical_ui_id` and every negative case fails with the intended stable error;
- legacy authority-link behavior remains compatible;
- an ordinary design specification can express and validate the smallest slice admission without granting runtime or commit permission by implication;
- the three authority-context bodies equal their exact replacements, and the guide explains accepted target, retained owner, discovery, cutover, plan, execution, commit, and evidence as separate states;
- the two Contacts bodies and three Backup/Minesweeper/Logout bodies equal the exact reconciled text while their stable IDs/dependencies remain unchanged;
- `prompt_docs/INDEX.md` is regenerated, validated, and byte-identical;
- the consumer/provenance census covers every discovered reference with accepted semantic basis, has zero unresolved rows, and remains audit evidence only;
- the Room-Owned Aperture path and `spec.room_owned_aperture_v1_design` dangling reference are inventoried as different token kinds under the one frozen Witnessed Scene exception, without assigning an ID or authority to the frontmatter-less source;
- the Minesweeper visual Standard remains a pending exact-writing cutover gate at SHA-256 `b8a7f62f0202c82ac2114a9fedf171d7c5fc5fc5e33ce4cc9d8d49721a95027c` rather than being silently promoted;
- every pre-existing approved plan still matches its recorded canonical digest;
- no accepted dossier, runtime file, source location, archive state, family authority route, or unrelated user change moved; and
- one real Beads issue and evidence record describe the exact tested subject honestly.

Passing UI-00 authorizes no runtime UI work. The next action is a separately owner-approved Settings-scoped implementation-target admission and its own hash-bound child plan, as defined by the roadmap specification.
