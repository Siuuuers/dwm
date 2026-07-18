# Agent Workflow Navigation Manual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an agent-first, human-readable navigation guide that explains repository authority, Beads status, capability-intention activation, stop conditions, and safe prompting without becoming execution authority or recreating a numbered roadmap.

**Architecture:** `Prompt.md` remains the only initial entry and gains one pointer to `docs/agent/AGENT_WORKFLOW.md`. The guide stores its frozen authority flags and unordered capability intentions in strict YAML-frontmatter scalars; dedicated tooling validates the pointer, guide structure, decision matrix, and typed authority links. Existing packet/index tooling remains the owner of requirement and decision packets.

**Tech Stack:** Godot 4.6.3 stable Mono, typed GDScript, GUT 9.6.1, Markdown, the existing strict `DocFrontmatter` subset, Beads JSON snapshots, PowerShell, and `rg`.

**Design authority:** `docs/superpowers/specs/2026-07-18-agent-workflow-navigation-manual-design.md`

**Plan status:** Awaiting explicit implementation approval. Written-spec approval does not authorize the mutations or commits below.

## Approval Gate

Before Task 1, show this exact plan to the user and obtain one explicit execution-mode choice: `subagent_driven` or `inline`. If execution is approved, compute the current plan's canonical lowercase SHA-256 digest without changing the plan:

```powershell
$planPath='docs/superpowers/plans/2026-07-18-agent-workflow-navigation-manual.md'
$strictUtf8=New-Object Text.UTF8Encoding($false,$true)
$canonicalUtf8=New-Object Text.UTF8Encoding($false)
$planBytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $planPath).Path)
if ($planBytes.Length -ge 3 -and $planBytes[0] -eq 0xef -and $planBytes[1] -eq 0xbb -and $planBytes[2] -eq 0xbf) { throw 'PLAN_UTF8_BOM_FORBIDDEN' }
$planText=$strictUtf8.GetString($planBytes).Replace("`r`n","`n").Replace("`r","`n")
$hasher=[Security.Cryptography.SHA256]::Create()
try { $planSha256=-join ($hasher.ComputeHash($canonicalUtf8.GetBytes($planText)) | ForEach-Object { $_.ToString('x2') }) }
finally { $hasher.Dispose() }
$implementationBase=[string]::Join('',@(& 'C:\Program Files\Git\cmd\git.exe' rev-parse --verify 'HEAD^{commit}')).Trim()
if ($implementationBase -notmatch '^[0-9a-f]{40}$') { throw 'IMPLEMENTATION_BASE_INVALID' }
```

Set the design specification's `implementation_authorized` and `implementation_plan_status` fields to `true` and `approved`; set `implementation_plan_path` to the JSON string `"docs/superpowers/plans/2026-07-18-agent-workflow-navigation-manual.md"`; set `implementation_plan_sha256` to `$planSha256`; set `implementation_execution_mode` to the user's exact choice; set `implementation_approved_by` to `project_owner`; set `implementation_authorization_state` to `approved`; set `implementation_authorization_scope` to `agent_workflow_manual_plan_tasks_1_through_3_only`; set `implementation_base_commit` to `$implementationBase`; and record the actual approval date in both `implementation_plan_approved_on` and `implementation_authorized_on`.

Record the user's exact scope and choice in Beads issue `dwm-2oy`. Ask separately whether the four exact scoped commits in this plan are authorized; execution permission does not imply commit permission. If commits are authorized, also record `implementation_commit_authorized: true`, `implementation_commit_approved_by: project_owner`, `implementation_commit_scope: exact_path_boundaries_in_approved_plan_only`, and the actual `implementation_commit_authorized_on` date in the specification. If commits are declined, record `implementation_commit_authorized: false`, do not invoke the commit helper, keep `dwm-2oy` in progress, and report that checked-in acceptance remains unmet even if working-tree tests pass. If the user does not approve execution, stop after preserving the reviewed plan and specification.

If the user authorizes exact scoped commits, commit the approved plan and its approval record before Task 1:

```powershell
$required=[ordered]@{
  'docs/superpowers/specs/2026-07-18-agent-workflow-navigation-manual-design.md'='M'
  'docs/superpowers/plans/2026-07-18-agent-workflow-navigation-manual.md'='A'
}
$expectedHead=[string]::Join('',@(& 'C:\Program Files\Git\cmd\git.exe' rev-parse --verify 'HEAD^{commit}')).Trim()
$env:DWM_COMMIT_AUTHORIZED='1'
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -ExpectedHead $expectedHead -Message 'docs(agent): approve workflow manual plan'
```

## Global Constraints

- The final guide MUST declare `document_role: navigation_only`, `execution_authority: false`, `status_authority: false`, `behavior_authority: false`, and `verification_authority: false` as direct entries in its only YAML frontmatter block.
- `Prompt.md` remains the only initial repository entry point and work-selection authority.
- Beads owns work status and dependency order; approved requirement packets own required behavior; approved specifications own design; approved plans own implementation procedure; executed evidence owns verification status.
- The guide MUST NOT contain numbered future phase labels. Validate the entire guide with case-insensitive pattern `\bphase(?:\s+|[-_])?[0-9]+[a-z0-9._-]*\b`.
- Capability intentions are unordered, non-executable, and contain only `intention_id`, `purpose`, and `authority_links`.
- Empty `authority_links` means intent only. A nonempty link must pass its typed resolver but never grants execution permission.
- No runtime gameplay, save, localization, audio, narrative, UI, or Minesweeper behavior changes.
- Tests use a GUID-scoped isolated root through `tools/testing/Invoke-IsolatedGodot.ps1`; no test may read or write production `user://`.
- Inspect every GUT log for parser errors and ignored scripts; process exit zero alone is insufficient.
- Preserve every unrelated worktree change. Every proposed commit uses `tools/git/Invoke-ExactPathCommit.ps1` and requires separate explicit commit authority.

---

### Task 1: Implement deterministic authority-link resolution

**Files:**

- Create: `tools/docs/AgentWorkflowAuthorityResolver.gd`
- Create: `tests/unit/tooling/test_agent_workflow_authority_resolver.gd`
- Modify: `tools/docs/DocValidator.gd`
- Modify: `tools/docs/DocIndexGenerator.gd`
- Modify: `tests/unit/tooling/test_doc_validator.gd`
- Modify: `prompt_docs/schemas/document_packet.v1.json`
- Modify: `prompt_docs/INDEX.md`

**Interfaces:**

- Consumes: validated packet/index output, projected specification approval fields, a caller-supplied `Array[Dictionary]` Beads snapshot, and repository-relative paths.
- Produces:

```gdscript
class_name AgentWorkflowAuthorityResolver
extends RefCounted

func _init(repository_root: String = "res://", beads_snapshot: Array[Dictionary] = []) -> void
func resolve(link: Dictionary) -> Dictionary
```

- `resolve()` returns `{"ok":true,"code":&"ok","value":{"kind":String,"target":String},"receipt":{}}` or `{"ok":false,"code":StringName,"details":Dictionary,"receipt":{}}`.
- Frozen failure codes: `AUTHORITY_LINK_INVALID`, `AUTHORITY_LINK_DUPLICATE_TARGET`, `AUTHORITY_LINK_UNKNOWN`, `AUTHORITY_LINK_UNAPPROVED`, and `AUTHORITY_LINK_SOURCE_INVALID`.

- [ ] **Step 1: Write the resolver and accepted-decision RED tests**

Create `tests/unit/tooling/test_agent_workflow_authority_resolver.gd` with a temporary repository containing one record of each link kind:

```gdscript
extends "res://addons/gut/test.gd"

const RESOLVER_PATH := "res://tools/docs/AgentWorkflowAuthorityResolver.gd"
var _counter := 0

func _write(path: String, text: String) -> void:
	assert_eq(DirAccess.make_dir_recursive_absolute(path.get_base_dir()), OK)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	file.store_string(text)
	file.close()

func _canonical_sha256(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	var text := bytes.get_string_from_utf8()
	assert_eq(text.to_utf8_buffer(), bytes)
	assert_false(bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf)
	return text.replace("\r\n", "\n").replace("\r", "\n").sha256_text()

func _fixture_root() -> String:
	_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("agent-authority-%d" % _counter)
	var plan_path := root.path_join("docs/superpowers/plans/sample.md")
	_write(plan_path, "# Sample plan\n\nOne reviewed procedure.\n")
	_write(root.path_join("prompt_docs/requirements/sample.md"), "---\nid: req_packet.sample\nkind: requirement_packet\nschema_version: 1\nspecification_status: approved\nbeads: []\nrequirements:\n  - {\"id\":\"req.sample\",\"depends_on\":[],\"implementation_evidence\":[],\"verification_evidence\":[]}\n---\n\n# Sample\n\n## Rule req.sample\n\nSample authority.\n")
	_write(root.path_join("prompt_docs/decisions/sample.md"), "---\nid: decision.sample\nkind: decision_packet\nschema_version: 1\nspecification_status: approved\ndecision_status: accepted\nbeads: []\nrequirements: []\ndepends_on: []\nevidence: [\"accepted by user\"]\nscope: [\"sample\"]\naffected_requirement_ids: [\"req.sample\"]\nblocking_requirement_ids: []\nrecommended_investigation: [\"Re-open only if the recorded scope changes.\"]\n---\n\n# Accepted decision\n")
	_write(root.path_join("docs/superpowers/specs/sample.md"), "---\nid: spec.sample\nconversational_design_status: approved\nwritten_spec_status: approved\nimplementation_plan_path: \"docs/superpowers/plans/sample.md\"\nimplementation_plan_status: approved\nimplementation_plan_sha256: %s\ncreated_on: 2026-07-18\n---\n\n# Sample specification\n" % _canonical_sha256(plan_path))
	var validator := preload("res://tools/docs/DocValidator.gd").new()
	var preliminary: Dictionary = validator.validate_tree(root.path_join("prompt_docs"), [])
	var index := preload("res://tools/docs/DocIndexGenerator.gd").new().render(preliminary)
	_write(root.path_join("prompt_docs/INDEX.md"), index)
	return root

func test_resolves_every_frozen_link_kind() -> void:
	var loaded := load(RESOLVER_PATH)
	assert_not_null(loaded, "expected RED: missing AgentWorkflowAuthorityResolver.gd")
	if loaded == null:
		return
	var resolver: RefCounted = loaded.new(_fixture_root(), [{"id":"dwm-sample"}])
	for link in [
		{"kind":"beads_issue", "target":"dwm-sample"},
		{"kind":"requirement_id", "target":"req.sample"},
		{"kind":"specification_id", "target":"spec.sample"},
		{"kind":"decision_id", "target":"decision.sample"},
		{"kind":"plan_path", "target":"docs/superpowers/plans/sample.md"},
	]:
		assert_true(resolver.resolve(link).get("ok", false), str(link))
	assert_eq(resolver.resolve({"kind":"beads_issue", "target":"missing"}).get("code"), &"AUTHORITY_LINK_UNKNOWN")
	assert_eq(resolver.resolve({"kind":"plan_path", "target":"../outside.md"}).get("code"), &"AUTHORITY_LINK_INVALID")

func test_plan_link_is_invalidated_when_approved_canonical_text_changes() -> void:
	var root := _fixture_root()
	_write(root.path_join("docs/superpowers/plans/sample.md"), "# Sample plan\n\nChanged after approval.\n")
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, [{"id":"dwm-sample"}])
	assert_eq(resolver.resolve({"kind":"plan_path", "target":"docs/superpowers/plans/sample.md"}).get("code"), &"AUTHORITY_LINK_UNAPPROVED")

func test_packet_links_require_the_current_generated_index() -> void:
	var root := _fixture_root()
	_write(root.path_join("prompt_docs/INDEX.md"), "stale\n")
	var resolver: RefCounted = load(RESOLVER_PATH).new(root, [{"id":"dwm-sample"}])
	assert_eq(resolver.resolve({"kind":"requirement_id", "target":"req.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
	assert_eq(resolver.resolve({"kind":"decision_id", "target":"decision.sample"}).get("code"), &"AUTHORITY_LINK_SOURCE_INVALID")
```

Extend `test_doc_validator.gd` with a complete accepted-decision fixture whose `evidence`, `scope`, `affected_requirement_ids`, and `recommended_investigation` arrays are nonempty and whose `blocking_requirement_ids` is empty. Assert that `(specification_status=approved, decision_status=accepted)` passes while `draft`, missing, and `rejected` statuses fail. Also assert that an accepted decision with a nonempty blocking list fails and that the generated index contains exactly one decision row for the accepted fixture.

- [ ] **Step 2: Run the focused RED gate**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'agent_authority_red' -LogName 'agent-authority-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_agent_workflow_authority_resolver.gd,res://tests/unit/tooling/test_doc_validator.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
```

Expected: the resolver test reaches the explicit missing-script assertion. No parser error or ignored test is acceptable.

- [ ] **Step 3: Implement the exact resolver**

Create `AgentWorkflowAuthorityResolver.gd` with these rules:

```gdscript
class_name AgentWorkflowAuthorityResolver
extends RefCounted

const DOC_VALIDATOR := preload("res://tools/docs/DocValidator.gd")
const LINK_KINDS := [&"beads_issue", &"requirement_id", &"specification_id", &"decision_id", &"plan_path"]
const SPEC_FIELDS := [&"id", &"conversational_design_status", &"written_spec_status", &"implementation_plan_path", &"implementation_plan_status", &"implementation_plan_sha256"]

var _repository_root: String
var _beads_by_id := {}
var _beads_source_valid := true
var _packet_result: Dictionary
var _spec_records: Array[Dictionary] = []

func _init(repository_root: String = "res://", beads_snapshot: Array[Dictionary] = []) -> void:
	_repository_root = repository_root.replace("\\", "/")
	while _repository_root.ends_with("/") and not _repository_root.ends_with("://"):
		_repository_root = _repository_root.trim_suffix("/")
	for issue: Dictionary in beads_snapshot:
		var issue_id := str(issue.get("id", ""))
		if issue_id.is_empty() or _beads_by_id.has(issue_id):
			_beads_source_valid = false
		else:
			_beads_by_id[issue_id] = issue.duplicate(true)
	_packet_result = DOC_VALIDATOR.new().validate_tree(_path("prompt_docs"), beads_snapshot)
	_spec_records = _project_specifications(_path("docs/superpowers/specs"))

func resolve(link: Dictionary) -> Dictionary:
	if link.keys().size() != 2 or not link.has("kind") or not link.has("target"):
		return _failure(&"AUTHORITY_LINK_INVALID", {})
	if typeof(link.kind) != TYPE_STRING or typeof(link.target) != TYPE_STRING:
		return _failure(&"AUTHORITY_LINK_INVALID", {})
	var kind := StringName(link.kind)
	var target := str(link.target)
	if kind not in LINK_KINDS or target.is_empty():
		return _failure(&"AUTHORITY_LINK_INVALID", {"kind":str(kind), "target":target})
	match kind:
		&"beads_issue":
			if not _beads_source_valid:
				return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":str(kind), "target":target})
			return _success(kind, target) if _beads_by_id.has(target) else _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind":str(kind), "target":target})
		&"requirement_id":
			return _resolve_requirement(target)
		&"specification_id":
			return _resolve_specification(target)
		&"decision_id":
			return _resolve_decision(target)
		&"plan_path":
			return _resolve_plan(target)
	return _failure(&"AUTHORITY_LINK_INVALID", {})

func _resolve_requirement(target: String) -> Dictionary:
	if not _packet_result.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"requirement_id", "target":target, "errors":_packet_result.get("errors", [])})
	var matches: Array = _packet_result.get("requirements", []).filter(func(requirement: Dictionary) -> bool: return requirement.get("id") == target)
	return _unique_approved(matches, target, &"requirement_id", func(requirement: Dictionary) -> bool: return requirement.get("specification_status") == "approved")

func _resolve_specification(target: String) -> Dictionary:
	var matches := _spec_records.filter(func(record: Dictionary) -> bool: return record.get("fields", {}).get("id") == target)
	return _unique_approved(matches, target, &"specification_id", func(record: Dictionary) -> bool:
		return record.get("ok", false) and record.fields.get("conversational_design_status") == "approved" and record.fields.get("written_spec_status") == "approved"
	)

func _resolve_decision(target: String) -> Dictionary:
	if not _packet_result.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"decision_id", "target":target, "errors":_packet_result.get("errors", [])})
	var matches: Array = _packet_result.get("packets", []).filter(func(front: Dictionary) -> bool: return front.get("id") == target and front.get("kind") == "decision_packet")
	return _unique_approved(matches, target, &"decision_id", func(front: Dictionary) -> bool:
		return front.get("specification_status") == "approved" and front.get("decision_status") == "accepted"
	)

func _resolve_plan(target: String) -> Dictionary:
	if not _is_safe_relative_path(target) or not target.begins_with("docs/superpowers/plans/") or not target.ends_with(".md"):
		return _failure(&"AUTHORITY_LINK_INVALID", {"kind":"plan_path", "target":target})
	var path := _path(target)
	if not _is_regular_non_link_file(path):
		return _failure(&"AUTHORITY_LINK_UNKNOWN", {"kind":"plan_path", "target":target})
	var matches := _spec_records.filter(func(record: Dictionary) -> bool: return record.get("fields", {}).get("implementation_plan_path") == target)
	if matches.size() != 1:
		return _failure(&"AUTHORITY_LINK_UNKNOWN" if matches.is_empty() else &"AUTHORITY_LINK_DUPLICATE_TARGET", {"kind":"plan_path", "target":target})
	var record: Dictionary = matches[0]
	if not record.get("ok", false):
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"plan_path", "target":target})
	var approved := record.fields.get("conversational_design_status") == "approved" and record.fields.get("written_spec_status") == "approved" and record.fields.get("implementation_plan_status") == "approved"
	var digest_result := _canonical_text_sha256(path)
	if not digest_result.ok:
		return _failure(&"AUTHORITY_LINK_SOURCE_INVALID", {"kind":"plan_path", "target":target})
	var digest_matches := record.fields.get("implementation_plan_sha256") == digest_result.value
	return _success(&"plan_path", target) if approved and digest_matches else _failure(&"AUTHORITY_LINK_UNAPPROVED", {"kind":"plan_path", "target":target})
```

Implement `_project_specifications`, `_project_frontmatter`, `_collect_markdown`, `_unique_approved`, `_is_safe_relative_path`, `_is_regular_non_link_file`, `_canonical_text_sha256`, `_path`, `_success`, and `_failure` as typed helpers. Recursive scans sort paths and reject symlinks. `_project_frontmatter` reads only the first exact `---` block, validates UTF-8, and projects only `SPEC_FIELDS`; projected values are strict JSON strings or bare scalars matching `^[A-Za-z0-9_.-]+$`, and slash-containing paths must therefore be quoted. Reject a projected key that is duplicated, indented, empty, or outside that grammar while ignoring unrelated keys. Add fixtures for a quoted path passing, an unquoted slash path failing, duplicate keys failing, and an indented projected key failing. Preserve partial projected fields on an invalid record so a matching malformed source returns `AUTHORITY_LINK_SOURCE_INVALID`, not `UNKNOWN`. `_unique_approved` returns `UNKNOWN` for zero matches, `DUPLICATE_TARGET` for multiple matches, `SOURCE_INVALID` for one malformed match, and `UNAPPROVED` when the sole valid match fails its predicate. Safe paths are repository-relative, use `/`, and contain no empty, `.`, or `..` segment. `_is_regular_non_link_file` opens each ancestor directory from the repository root and calls that directory handle's `is_link(next_segment)` before descending, then applies the same check to the final regular file; do not call a nonexistent static symlink helper. `_canonical_text_sha256` rejects invalid UTF-8 and a UTF-8 BOM, normalizes CRLF and CR to LF, and returns the normalized `String.sha256_text()` value.

`DocValidator.validate_tree()` is the mandatory index reader/checker for requirement and decision links: when called on the repository's `prompt_docs` root, it compares `prompt_docs/INDEX.md` byte-for-byte with `DocIndexGenerator.render()`. The resolver MUST refuse packet links whenever that validation reports `DOC_INDEX_DRIFT`; it MUST NOT fall back to raw packet scans.

Update the decision-packet contract:

```gdscript
# DocValidator._validate_status_pair
if kind == "decision_packet":
	var valid_deferred := front.get("specification_status") == "deferred" and front.get("decision_status") == "decision_required"
	var valid_accepted := front.get("specification_status") == "approved" and front.get("decision_status") == "accepted"
	if not valid_deferred and not valid_accepted:
		errors.append("DOC_FRONTMATTER_INVALID: decision status pair in " + path)
```

Change `document_packet.v1.json` so `decision_status` is `{"enum":["decision_required","accepted"]}`. Do not change any existing decision packet.

Adjust `_validate_decisions()` without weakening deferred-decision checks: both statuses require all five decision fields with array types; `evidence`, `scope`, `affected_requirement_ids`, and `recommended_investigation` remain nonempty; `blocking_requirement_ids` remains nonempty for `decision_required` but MUST be empty for `accepted`, because an accepted decision no longer blocks its affected requirements. Keep dependency validation for every affected or blocking ID.

Extend `DocIndexGenerator.render()` with a deterministic decision lookup after the requirement table:

```gdscript
lines.append_array(["", "# Decision Index", "", "| decision_id | path | specification_status | decision_status |", "|---|---|---|---|"])
var decisions: Array = validation_result.get("packets", []).filter(func(packet: Dictionary) -> bool: return packet.get("kind") == "decision_packet")
decisions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
for decision: Dictionary in decisions:
	lines.append("| `%s` | `%s` | `%s` | `%s` |" % [decision.id, decision.path, decision.specification_status, decision.decision_status])
```

Place this table before the final `blocked_requirement_ids` line. Regenerate `prompt_docs/INDEX.md` through `tools/docs/generate_index.gd`; never hand-edit generated rows.

- [ ] **Step 4: Run the authority GREEN gate**

Run the same isolated suite as Step 2 with `SuiteId 'agent_authority_green'` and `LogName 'agent-authority-green.log'`.

Expected: every test passes; the log contains no `SCRIPT ERROR`, `Ignoring script`, or unexpected `ERROR:`.

- [ ] **Step 5: Proposed exact commit boundary**

Do not run without separate explicit commit authority. Commit only Task 1 paths and present-only generated UIDs:

```powershell
$required=[ordered]@{
  'tools/docs/AgentWorkflowAuthorityResolver.gd'='A'
  'tests/unit/tooling/test_agent_workflow_authority_resolver.gd'='A'
  'tools/docs/DocValidator.gd'='M'
  'tools/docs/DocIndexGenerator.gd'='M'
  'tests/unit/tooling/test_doc_validator.gd'='M'
  'prompt_docs/schemas/document_packet.v1.json'='M'
  'prompt_docs/INDEX.md'='M'
}
$optional=[ordered]@{
  'tools/docs/AgentWorkflowAuthorityResolver.gd.uid'='A'
  'tests/unit/tooling/test_agent_workflow_authority_resolver.gd.uid'='A'
}
$expectedHead=[string]::Join('',@(& 'C:\Program Files\Git\cmd\git.exe' rev-parse --verify 'HEAD^{commit}')).Trim()
$env:DWM_COMMIT_AUTHORIZED='1'
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optional -ExpectedHead $expectedHead -Message 'feat(docs): resolve typed agent authority links'
```

---

### Task 2: Implement the navigation-manual validator

**Files:**

- Create: `tools/docs/AgentWorkflowValidator.gd`
- Create: `tools/docs/validate_agent_workflow.gd`
- Create: `tests/unit/tooling/test_agent_workflow_validator.gd`

**Interfaces:**

- Consumes: `DocFrontmatter`, `AgentWorkflowAuthorityResolver`, `Prompt.md`, a Beads snapshot, and the exact guide path.
- Produces:

```gdscript
class_name AgentWorkflowValidator
extends RefCounted

func validate_files(prompt_path: String = "res://Prompt.md", beads_snapshot: Array[Dictionary] = []) -> Dictionary
func validate_pair(prompt_text: String, guide_text: String, resolver: RefCounted = null) -> Dictionary
```

- Both methods return `{"ok":bool,"errors":Array[String]}`. Errors use stable prefixes: `AGENT_WORKFLOW_PROMPT_INVALID`, `AGENT_WORKFLOW_POINTER_INVALID`, `AGENT_WORKFLOW_GUIDE_INVALID`, `AGENT_WORKFLOW_AUTHORITY_INVALID`, `AGENT_WORKFLOW_INTENTION_INVALID`, `AGENT_WORKFLOW_INTENTION_DUPLICATE`, `AGENT_WORKFLOW_LINK_UNRESOLVED`, `AGENT_WORKFLOW_NUMBERED_PHASE`, `AGENT_WORKFLOW_PLACEHOLDER`, and `AGENT_WORKFLOW_DECISION_MATRIX_INVALID`.

- [ ] **Step 1: Write the complete validator RED matrix**

Create an in-memory valid prompt/guide pair, then mutate one property per assertion:

```gdscript
extends "res://addons/gut/test.gd"

const VALIDATOR_PATH := "res://tools/docs/AgentWorkflowValidator.gd"
const VALID_PROMPT := "---\nschema_version: 1\nkind: agent_entry\nagent_workflow_guide: \"docs/agent/AGENT_WORKFLOW.md\"\n---\n\n# Entry\n"
const VALID_GUIDE := "---\nschema_version: 1\ndocument_id: agent_workflow\ndocument_role: navigation_only\nexecution_authority: false\nstatus_authority: false\nbehavior_authority: false\nverification_authority: false\ncapability_intentions: [{\"intention_id\":\"desktop_experience\",\"purpose\":\"Provide a usable desktop experience.\",\"authority_links\":[]}]\n---\n\n# Agent Workflow Navigation\n\n## Decision table\n\n| decision_id | exact action |\n|---|---|\n| commit_parent_open | Report the bounded commit; report the parent as open. |\n| one_ready_issue | Inspect the issue and its dependencies; mutate only with scope-matched permission. |\n| multiple_active_ambiguous | Stop, list the issue IDs, and request one selection. |\n| intention_links_empty | Treat it as intent only and request design authority. |\n| authority_link_broken | Stop and identify the broken link. |\n| design_without_plan | Do not implement; prepare a plan only when requested. |\n| plan_without_permission | Stop and request exact execution permission. |\n| ignored_script | Treat verification as failed, fix discovery, and rerun. |\n| child_closed_parent_open | Report the child closed and the parent open. |\n"

func _has_code(result: Dictionary, code: String) -> bool:
	return result.errors.any(func(error: String) -> bool: return error.begins_with(code))

func test_validator_rejects_every_frozen_drift() -> void:
	var loaded := load(VALIDATOR_PATH)
	assert_not_null(loaded, "expected RED: missing AgentWorkflowValidator.gd")
	if loaded == null:
		return
	var validator: RefCounted = loaded.new()
	assert_true(validator.validate_pair(VALID_PROMPT, VALID_GUIDE).ok)
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT.replace("docs/agent/AGENT_WORKFLOW.md", "missing.md"), VALID_GUIDE), "AGENT_WORKFLOW_POINTER_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("execution_authority: false", "execution_authority: true")), "AGENT_WORKFLOW_AUTHORITY_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("Provide a usable desktop experience.", "Phase 3 desktop")), "AGENT_WORKFLOW_NUMBERED_PHASE"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("# Agent Workflow Navigation", "# Agent Workflow Navigation\n\nTBD")), "AGENT_WORKFLOW_PLACEHOLDER"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE + "\n---\nsecond: block\n---\n"), "AGENT_WORKFLOW_GUIDE_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE + "\ncapability_intentions: []\n"), "AGENT_WORKFLOW_GUIDE_INVALID"))
	var duplicate := VALID_GUIDE.replace("}]\n---", "},{\"intention_id\":\"desktop_experience\",\"purpose\":\"duplicate\",\"authority_links\":[]}]\n---")
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, duplicate), "AGENT_WORKFLOW_INTENTION_DUPLICATE"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("| ignored_script |", "| removed_script |")), "AGENT_WORKFLOW_DECISION_MATRIX_INVALID"))
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, VALID_GUIDE.replace("Report the bounded commit; report the parent as open.", "Report everything complete.")), "AGENT_WORKFLOW_DECISION_MATRIX_INVALID"))
	var competing_table := VALID_GUIDE.replace("## Decision table", "## Unrelated table\n\n| arbitrary | value |\n|---|---|\n| unknown_id | unrelated |\n\n## Decision table")
	assert_true(validator.validate_pair(VALID_PROMPT, competing_table).ok)
	var unknown_decision := VALID_GUIDE.replace("| child_closed_parent_open |", "| unknown_decision | unrelated action |\n| child_closed_parent_open |")
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, unknown_decision), "AGENT_WORKFLOW_DECISION_MATRIX_INVALID"))
```

Add these boundary fixtures in the same test file:

```gdscript
class StubResolver:
	extends RefCounted
	var succeeds := true
	func _init(value: bool) -> void: succeeds = value
	func resolve(_link: Dictionary) -> Dictionary:
		return {"ok":true, "code":&"ok"} if succeeds else {"ok":false, "code":&"AUTHORITY_LINK_UNKNOWN"}

func test_nonempty_links_must_resolve() -> void:
	var validator: RefCounted = load(VALIDATOR_PATH).new()
	var linked := VALID_GUIDE.replace("\"authority_links\":[]", "\"authority_links\":[{\"kind\":\"beads_issue\",\"target\":\"dwm-sample\"}]")
	assert_true(validator.validate_pair(VALID_PROMPT, linked, StubResolver.new(true)).ok)
	assert_true(_has_code(validator.validate_pair(VALID_PROMPT, linked, StubResolver.new(false)), "AGENT_WORKFLOW_LINK_UNRESOLVED"))

func test_validate_files_rejects_physically_missing_guide() -> void:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("agent-workflow-missing")
	_write(root.path_join("Prompt.md"), VALID_PROMPT)
	var result: Dictionary = load(VALIDATOR_PATH).new().validate_files(root.path_join("Prompt.md"), [])
	assert_true(_has_code(result, "AGENT_WORKFLOW_POINTER_INVALID"), JSON.stringify(result.errors))
```

Add the same bounded `_write()` helper shown in Task 1 to this test file. `validate_files()` derives the repository root from the supplied `Prompt.md` path, so this fixture proves a syntactically correct pointer cannot pass when the target is physically absent.

- [ ] **Step 2: Run the validator RED gate**

Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'agent_workflow_validator_red' -LogName 'agent-workflow-validator-red.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_agent_workflow_validator.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
```

Expected: the test reaches the explicit missing-script assertion and is not ignored.

- [ ] **Step 3: Implement the exact validator**

Use these frozen constants and checks:

```gdscript
class_name AgentWorkflowValidator
extends RefCounted

const FRONTMATTER := preload("res://tools/docs/DocFrontmatter.gd")
const RESOLVER := preload("res://tools/docs/AgentWorkflowAuthorityResolver.gd")
const GUIDE_PATH := "docs/agent/AGENT_WORKFLOW.md"
const GUIDE_FIELDS := [&"schema_version", &"document_id", &"document_role", &"execution_authority", &"status_authority", &"behavior_authority", &"verification_authority", &"capability_intentions"]
const AUTHORITY_VALUES := {&"document_role":"navigation_only", &"execution_authority":false, &"status_authority":false, &"behavior_authority":false, &"verification_authority":false}
const DECISION_ROWS := {
	"commit_parent_open":"Report the bounded commit; report the parent as open.",
	"one_ready_issue":"Inspect the issue and its dependencies; mutate only with scope-matched permission.",
	"multiple_active_ambiguous":"Stop, list the issue IDs, and request one selection.",
	"intention_links_empty":"Treat it as intent only and request design authority.",
	"authority_link_broken":"Stop and identify the broken link.",
	"design_without_plan":"Do not implement; prepare a plan only when requested.",
	"plan_without_permission":"Stop and request exact execution permission.",
	"ignored_script":"Treat verification as failed, fix discovery, and rerun.",
	"child_closed_parent_open":"Report the child closed and the parent open.",
}
const NUMBERED_PHASE_PATTERN := "(?i)\\bphase(?:\\s+|[-_])?[0-9]+[a-z0-9._-]*\\b"
const PLACEHOLDER_PATTERN := "(?i)\\b(?:TBD|TODO|FIXME|XXX|My first issue)\\b"
const INTENTION_ID_PATTERN := "^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$"

func validate_pair(prompt_text: String, guide_text: String, resolver: RefCounted = null) -> Dictionary:
	var errors: Array[String] = []
	var prompt := FRONTMATTER.parse_text(prompt_text, "Prompt.md")
	if not prompt.ok:
		errors.append("AGENT_WORKFLOW_PROMPT_INVALID: " + JSON.stringify(prompt.errors))
		return {"ok":false, "errors":errors}
	if prompt.frontmatter.get("agent_workflow_guide") != GUIDE_PATH:
		errors.append("AGENT_WORKFLOW_POINTER_INVALID: " + str(prompt.frontmatter.get("agent_workflow_guide", "")))
	var guide := FRONTMATTER.parse_text(guide_text, GUIDE_PATH)
	if not guide.ok:
		errors.append("AGENT_WORKFLOW_GUIDE_INVALID: " + JSON.stringify(guide.errors))
		return {"ok":false, "errors":errors}
	_validate_frontmatter(guide.frontmatter, resolver, errors)
	_validate_text(guide_text, guide.body, errors)
	return {"ok":errors.is_empty(), "errors":errors}
```

`_validate_frontmatter()` requires the exact `GUIDE_FIELDS` set, `schema_version == 1`, `document_id == "agent_workflow"`, exact authority values, an array of exact-key intention dictionaries, unique IDs matching `INTENTION_ID_PATTERN`, nonempty plain-string purposes, and arrays of exact-key typed links. It calls `resolver.resolve()` for every nonempty link and prefixes failures with `AGENT_WORKFLOW_LINK_UNRESOLVED`.

`_validate_text()` applies both forbidden regexes to the entire guide, not only the body. It rejects any second exact `---` line in the body and any body line beginning `capability_intentions:`. For the matrix, locate exactly one `## Decision table` heading, take only the lines until the next level-two heading or end of body, require the exact header `| decision_id | exact action |` and separator `|---|---|` once, and parse only two-cell rows within that section. Require exactly one row for every frozen pair and reject duplicate, unknown, or wrong-action rows. Ignore tables outside that section.

`validate_files()` parses `Prompt.md`, validates that its pointer is the exact safe relative path, checks that the resolved guide is one non-symlink regular file beneath the repository root, instantiates `AgentWorkflowAuthorityResolver` with the repository root and snapshot, and delegates to `validate_pair()`. It never accepts an absolute path, empty segment, `.`, `..`, alternate separator, or link traversal.

Create `validate_agent_workflow.gd` by reusing the exact strict snapshot loader from `tools/docs/validate_docs.gd`, then:

```gdscript
func _init() -> void:
	var result := preload("res://tools/docs/AgentWorkflowValidator.gd").new().validate_files("res://Prompt.md", _load_snapshot_or_quit())
	if not result.ok:
		printerr(JSON.stringify(result.errors))
		quit(1)
		return
	print("AGENT_WORKFLOW_VALIDATION: PASS")
	quit(0)
```

- [ ] **Step 4: Run the validator GREEN gate**

Run the same suite as Step 2 with `SuiteId 'agent_workflow_validator_green'` and `LogName 'agent-workflow-validator-green.log'`.

Expected: all mutation cases pass with their exact failure prefixes and no ignored script.

- [ ] **Step 5: Proposed exact commit boundary**

Do not run without separate explicit commit authority:

```powershell
$required=[ordered]@{
  'tools/docs/AgentWorkflowValidator.gd'='A'
  'tools/docs/validate_agent_workflow.gd'='A'
  'tests/unit/tooling/test_agent_workflow_validator.gd'='A'
}
$optional=[ordered]@{
  'tools/docs/AgentWorkflowValidator.gd.uid'='A'
  'tools/docs/validate_agent_workflow.gd.uid'='A'
  'tests/unit/tooling/test_agent_workflow_validator.gd.uid'='A'
}
$expectedHead=[string]::Join('',@(& 'C:\Program Files\Git\cmd\git.exe' rev-parse --verify 'HEAD^{commit}')).Trim()
$env:DWM_COMMIT_AUTHORIZED='1'
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optional -ExpectedHead $expectedHead -Message 'feat(docs): validate agent workflow navigation'
```

---

### Task 3: Add the guide, entry pointer, and documentation gate

**Files:**

- Create: `docs/agent/AGENT_WORKFLOW.md`
- Modify: `Prompt.md`
- Modify: `tools/docs/validate_docs.gd`
- Modify: `tests/unit/tooling/test_agent_workflow_validator.gd`

**Interfaces:**

- Consumes: the Task 2 validator and existing strict Beads snapshot loader.
- Produces: one valid `agent_workflow_guide` pointer, one navigation-only guide, and a documentation command that validates requirement packets and the guide in the same isolated process.

- [ ] **Step 1: Add the real-file RED integration test**

Append:

```gdscript
func test_repository_agent_workflow_files_validate() -> void:
	var validator: RefCounted = load(VALIDATOR_PATH).new()
	var result: Dictionary = validator.validate_files("res://Prompt.md", [])
	assert_true(result.ok, JSON.stringify(result.errors))
```

Run the Task 2 focused suite. Expected RED: `AGENT_WORKFLOW_PROMPT_INVALID` because the existing slash-containing Prompt path scalars predate the strict quoted-scalar contract; after those are corrected, the still-missing guide pointer remains a tested unit failure. A missing test or ignored script is not acceptable.

- [ ] **Step 2: Create the complete guide**

Create `docs/agent/AGENT_WORKFLOW.md` with this frontmatter and body structure. Do not add numbered future labels or mutable project status:

```markdown
---
schema_version: 1
document_id: agent_workflow
document_role: navigation_only
execution_authority: false
status_authority: false
behavior_authority: false
verification_authority: false
capability_intentions: [{"intention_id":"desktop_experience","purpose":"Provide a usable desktop experience in which registered applications open, retain appropriate same-day presentation state, and remain accessible.","authority_links":[]},{"intention_id":"narrative_experience","purpose":"Present the intended story, relationships, hospital sequence, dates, and endings coherently through approved narrative content.","authority_links":[]},{"intention_id":"whole_project_hardening","purpose":"Make the complete game stable, accessible, secure against unsafe data execution, and honestly verified for release decisions.","authority_links":[]},{"intention_id":"playable_minesweeper","purpose":"Provide a deterministic, accessible, genuinely playable Minesweeper experience that feeds the existing game outcomes through approved contracts.","authority_links":[]}]
---

# Agent Workflow Navigation

This guide explains how to find valid work. It does not authorize work or define game behavior. If it conflicts with a source that owns the disputed fact, stop and report the conflict.

## Plain-language glossary

- **Authority:** the one designated source that owns a particular kind of project truth.
- **Frontmatter:** the machine-readable block between the two `---` lines at the top of a Markdown file.
- **Authority link:** a typed reference from an intention to one existing approved source; it is not execution permission.
- **Prompt:** the repository entry contract that tells an agent how to select context.
- **Beads:** the task tracker that owns live issue status and dependency order.
- **Bounded issue:** one Beads task with a specific scope and acceptance criteria.
- **Dependency:** an authority record or work item that must be satisfied before the dependent work can proceed.
- **Epic:** a parent Beads issue that remains open until its required child work and gates are closed.
- **Intention:** an outcome worth considering; not scheduled work.
- **Requirement packet:** an approved document that owns required behavior or constraints.
- **Specification:** an approved design explaining boundaries and decisions.
- **Accepted decision:** a reviewed choice packet whose exact status pair is approved and accepted.
- **Plan:** an approved, hash-bound procedure for implementing a specification.
- **Worktree:** the physical files currently present, including uncommitted changes.
- **Instruction hierarchy:** the active system, developer, and user instructions that determine what actions are permitted.
- **Execution permission:** exact authority to perform the requested mutation.
- **Evidence:** recorded output proving what ran against one identified worktree or commit.

## Sixty-second startup

1. Read `Prompt.md` and follow its current selection rule.
2. Use the Beads executable preflight in `Prompt.md`, run `& $bdExecutable prime`, inspect in-progress work, and run `& $bdExecutable ready --json --readonly` only when no valid work is already in progress.
3. Select exactly one bounded issue and inspect it with `& $bdExecutable show <issue-id> --json --readonly`.
4. Load only that issue's approved requirement packets and transitive dependencies; load an approved specification or implementation plan only when the requested action requires it.
5. Inspect the named physical files and current worktree before proposing mutations.
6. Confirm that the requested mutation has exact scope-matched execution permission.
7. Run the required evidence and inspect logs before reporting completion.

In plain language: start with the entry contract, ask Beads what is actually active, read only the authority for that one job, compare it with the real files, and never confuse a plan or commit with verified completion.

| Startup step | Why it exists |
|---|---|
| Read the prompt | It supplies the current context-selection contract. |
| Inspect Beads | It prevents stale prose from being mistaken for live status. |
| Select one issue | It keeps authority and mutations inside one reviewable boundary. |
| Load linked authority | It supplies required behavior, design, dependencies, and procedure without loading unrelated history. |
| Inspect physical files | It detects drift between the approved plan and the worktree. |
| Confirm permission | It separates a ready task from authority to mutate files or external state. |
| Inspect evidence | It prevents a process exit code, stale log, or wrong tested subject from becoming a false completion claim. |

## Authority map

| Question | Source to inspect |
|---|---|
| How does an agent enter and select context? | `Prompt.md` |
| What work is active, ready, blocked, or closed? | Beads |
| What behavior is required? | Approved requirement packets |
| What design was approved? | Approved specifications and accepted decisions |
| What exact implementation procedure was approved? | Approved implementation plans |
| What physically exists? | The inspected worktree or tested commit |
| What is verified? | Executed evidence tied to that subject |
| May this mutation be performed? | The active instruction hierarchy and exact scope-matched user authorization |

No entry in this table implies another. Beads readiness does not approve a design. An approved design does not approve implementation. A passing test does not close a Beads issue. This guide never grants permission.

## Reading status correctly

- A commit records one bounded repository change.
- A closed child issue reports only that child's accepted scope.
- A parent epic remains incomplete until Beads closes the parent after its required children and gates.
- An approved specification may have no implementation.
- Implemented code may have missing or stale verification.
- Query Beads for mutable status; do not copy status into this guide.

## Capability intentions

The frontmatter contains an unordered catalog of desired outcomes. These entries explain purpose only. They do not prescribe order, implementation, or completion.

An empty `authority_links` array means the intention is not executable. Ask to design and link one bounded capability. A nonempty array still requires every target to resolve, one valid Beads issue, approved requirements and plan, and exact execution permission.

## Activating one intention

Use this lifecycle: intention → bounded Beads issue → clarified and approved design or decision → approved requirements → approved implementation plan → exact execution permission → implementation and tests → evidence tied to the tested subject → Beads closure.

Each arrow is a separate gate. Never infer the next gate from the previous one.

An approved plan is the exact plan file whose path and canonical-text SHA-256 digest are recorded by one approved specification. If its valid UTF-8 text changes after newline normalization, treat approval as stale and stop for review; newline-only checkout conversion does not change approval.

## Decision table

| decision_id | exact action |
|---|---|
| commit_parent_open | Report the bounded commit; report the parent as open. |
| one_ready_issue | Inspect the issue and its dependencies; mutate only with scope-matched permission. |
| multiple_active_ambiguous | Stop, list the issue IDs, and request one selection. |
| intention_links_empty | Treat it as intent only and request design authority. |
| authority_link_broken | Stop and identify the broken link. |
| design_without_plan | Do not implement; prepare a plan only when requested. |
| plan_without_permission | Stop and request exact execution permission. |
| ignored_script | Treat verification as failed, fix discovery, and rerun. |
| child_closed_parent_open | Report the child closed and the parent open. |

## Stop report

When blocked, report four things: the physical observation, the owning authority, the action that cannot continue, and the smallest decision or correction needed. Do not disguise missing permission as a technical error.

Stop the affected work when no valid in-progress or ready bounded issue exists; multiple active issues cannot be reduced to one by the entry rule; an authority link is missing, broken, unapproved, or contradictory; requested behavior is absent from approved requirements; the approved plan does not cover the mutation; exact execution permission is missing; a prerequisite is unavailable; the worktree differs from the plan's bound assumptions; verification did not run, failed, ignored a script, or tested another subject; or completion would require inventing content or behavior. Report unaffected observations separately, but do not continue the blocked mutation.

## Adding a new idea

Describe the player-facing outcome and the problem it solves, then ask the agent to compare it with current authority and identify architecture-changing questions. Keep it as an unlinked intention while exploring. When the idea is clear, create one bounded issue, record approved behavior and design in their owning documents, write and approve an exact implementation plan, and grant execution permission separately. Never turn the intention text itself into implementation instructions.

## Safe prompts

- “Inspect current project status from Beads and explain it without changing files.”
- “Select and explain the next valid bounded issue; do not implement it.”
- “Turn this capability intention into a design proposal and stop for my review.”
- “Write an implementation plan from this approved specification; do not execute it.”
- “Inspect current authority first; then execute this exact bounded issue using only its approved requirements and plan, run its evidence gate, and preserve unrelated changes.”
- “Audit authority links and contradictions without changing runtime files.”
- “Explain this blocker in plain language and identify the smallest decision needed.”

These prompts grant only what they say. They never imply commit, push, deletion, evidence sealing, external messages, or history changes.

```

- [ ] **Step 3: Add the exact Prompt pointer**

Quote the three existing slash-containing path scalars so `Prompt.md` is valid under `DocFrontmatter`, then add the quoted guide pointer after `generated_lookup`:

```yaml
specification_authority: "docs/superpowers/specs/2026-07-17-phase-2r-foundation-repair-design.md"
plan_authority: "docs/superpowers/plans/2026-07-17-phase-2r-foundation-repair.md"
generated_lookup: "prompt_docs/INDEX.md"
agent_workflow_guide: "docs/agent/AGENT_WORKFLOW.md"
```

Do not change the scalar values or the current selection logic; this is syntax hardening only.

Immediately after the existing `Read-StrictJson.ps1` import in the PowerShell block, add this executable preflight:

```powershell
$bdCommand=Get-Command bd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -ne $bdCommand) {
    $bdExecutable=[IO.Path]::GetFullPath($bdCommand.Source)
} else {
    if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'Beads executable not found.' }
    $bdExecutable=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\bd\bd.exe'))
}
if (-not (Test-Path -LiteralPath $bdExecutable -PathType Leaf)) { throw 'Beads executable not found.' }
$bdItem=Get-Item -Force -LiteralPath $bdExecutable
if (($bdItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Beads executable must not be a reparse point.' }
```

Mechanically replace the four native invocations while preserving every argument and `$LASTEXITCODE` check: `bd prime` becomes `& $bdExecutable prime`; `@(bd list ...)` becomes `@(& $bdExecutable list ...)`; `@(bd ready ...)` becomes `@(& $bdExecutable ready ...)`; and `bd show ...` becomes `& $bdExecutable show ...`. Keep human-facing command labels unchanged.

Add this paragraph immediately after `# Phase 2R Agent Entry`:

```markdown
For a plain-language explanation of authority, status, capability intentions, and stop conditions, read `docs/agent/AGENT_WORKFLOW.md`. That guide is navigation-only; it does not change the active selection rule below.
```

- [ ] **Step 4: Integrate the guide into the existing docs command**

Modify `_init()` in `validate_docs.gd` so the snapshot is loaded once and shared by both validators:

```gdscript
var snapshot := _load_snapshot_or_quit()
var result := VALIDATOR.new().validate_tree("res://prompt_docs", snapshot)
if not result.ok:
	printerr(JSON.stringify(result.errors))
	quit(1)
	return
var workflow := preload("res://tools/docs/AgentWorkflowValidator.gd").new().validate_files("res://Prompt.md", snapshot)
if not workflow.ok:
	printerr(JSON.stringify(workflow.errors))
	quit(1)
	return
print("DOC_VALIDATION: PASS packets=%d agent_workflow=1" % result.packets.size())
quit(0)
```

Remove the earlier packet-only success print/quit so the process has one terminal path.

- [ ] **Step 5: Run focused and documentation GREEN gates**

```powershell
$bdCommand=Get-Command bd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$bdExecutable=$(if ($null -ne $bdCommand) { [IO.Path]::GetFullPath($bdCommand.Source) } elseif (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Programs\bd\bd.exe')) } else { '' })
if ([string]::IsNullOrWhiteSpace($bdExecutable) -or -not (Test-Path -LiteralPath $bdExecutable -PathType Leaf)) { throw 'Beads executable not found.' }
$bdItem=Get-Item -Force -LiteralPath $bdExecutable
if (($bdItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Beads executable must not be a reparse point.' }
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json' -BdCommand $bdExecutable
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'agent_workflow_green' -LogName 'agent-workflow-green.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_agent_workflow_authority_resolver.gd,res://tests/unit/tooling/test_agent_workflow_validator.gd,res://tests/unit/tooling/test_doc_frontmatter.gd,res://tests/unit/tooling/test_doc_validator.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'agent_workflow_cli' -LogName 'agent-workflow-cli.log' -GodotArgs @('-s','res://tools/docs/validate_agent_workflow.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'agent_workflow_docs_gate' -LogName 'agent-workflow-docs-gate.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
```

Expected: all focused tests pass; standalone output is `AGENT_WORKFLOW_VALIDATION: PASS`; docs output is `DOC_VALIDATION: PASS packets=14 agent_workflow=1`; none of the three logs contains parse errors, ignored scripts, or unexpected errors.

- [ ] **Step 6: Run final semantic scans and diff checks**

```powershell
rg -n -i '\bphase(?:\s+|[-_])?[0-9]+[a-z0-9._-]*\b' docs/agent/AGENT_WORKFLOW.md
rg -n -i '\b(TBD|TODO|FIXME|XXX|My first issue)\b' docs/agent/AGENT_WORKFLOW.md
rg -n 'execution_authority:\s*true|status_authority:\s*true|behavior_authority:\s*true|verification_authority:\s*true' docs/agent/AGENT_WORKFLOW.md
$baseLines=@(Get-Content -LiteralPath 'docs/superpowers/specs/2026-07-18-agent-workflow-navigation-manual-design.md' | Where-Object { $_ -cmatch '^implementation_base_commit: [0-9a-f]{40}$' })
if ($baseLines.Count -ne 1) { throw 'IMPLEMENTATION_BASE_INVALID' }
$implementationBase=$baseLines[0].Substring('implementation_base_commit: '.Length)
& 'C:\Program Files\Git\cmd\git.exe' diff --check "$implementationBase..HEAD"
if ($LASTEXITCODE -ne 0) { throw 'COMMITTED_DIFF_CHECK_FAILED' }
& 'C:\Program Files\Git\cmd\git.exe' diff --check
if ($LASTEXITCODE -ne 0) { throw 'WORKTREE_DIFF_CHECK_FAILED' }
```

Expected: all three `rg` commands exit 1 with no matches; the committed range from the recorded implementation base and the remaining worktree both pass `git diff --check`.

- [ ] **Step 7: Proposed exact commit boundary**

Do not run without separate explicit commit authority:

```powershell
$required=[ordered]@{
  'docs/agent/AGENT_WORKFLOW.md'='A'
  'Prompt.md'='M'
  'tools/docs/validate_docs.gd'='M'
  'tests/unit/tooling/test_agent_workflow_validator.gd'='M'
}
$expectedHead=[string]::Join('',@(& 'C:\Program Files\Git\cmd\git.exe' rev-parse --verify 'HEAD^{commit}')).Trim()
$env:DWM_COMMIT_AUTHORIZED='1'
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -ExpectedHead $expectedHead -Message 'docs(agent): add navigation-only workflow guide'
```

- [ ] **Step 8: User review and Beads handoff**

When commits are authorized, after the final scoped commit rerun `git diff --check "$implementationBase..HEAD"` so the check covers all four committed boundaries. Show the user `docs/agent/AGENT_WORKFLOW.md`, the exact test totals, docs-gate result, scans, committed-range check, and commit identities. Keep `dwm-2oy` in progress until the user confirms plain-language clarity. After that confirmation, append the evidence to the issue and close it with the reason `Agent workflow navigation manual, entry pointer, typed authority-link validation, and decision fixtures are implemented, reviewed, and verified.`

When commits are not authorized, show the same working-tree evidence but state that the checked-in decision-table criterion is unmet; do not close `dwm-2oy`, do not report the manual complete, and ask for exact commit authority as the smallest remaining gate. Do not commit or push Beads journals without separate exact authority.
