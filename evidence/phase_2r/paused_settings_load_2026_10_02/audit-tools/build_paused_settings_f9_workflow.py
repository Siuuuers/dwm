#!/usr/bin/env python3
"""Derive a source-pinned paused Settings F9 candidate from canonical cloud CI.

This helper only reads source and writes workflow/provenance files. It never runs
Godot or PowerShell, changes repository files/refs, or publishes remote objects.
Without --source it emits an explicitly nonpublishable draft. Final generation
requires every inventoried working byte to match the exact local Git source.
"""
from __future__ import annotations

import argparse
import ast
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import subprocess

import yaml

import build_layout_workflow as diagnostic


PLACEHOLDER = "__FROZEN_SOURCE_COMMIT__"
DEFAULT_BRANCH = "codex/paused-settings-f9-cloud-20261002"
DEFAULT_SUITES = ("reading_delivery", "settings", "localization")
DEFAULT_BASELINE = "2254d6956de778cc54aa42fe610bcdf94f5301a5"
DEFAULT_FIXTURES = (
    "tests/unit/test_production_pause_controller.gd",
    "tests/unit/test_reading_pause_save.gd",
    "tests/unit/test_backup_quick_actions.gd",
    "tests/unit/test_quick_status_edge.gd",
    "tests/unit/test_backup_presentation.gd",
    "tests/scene/test_settings_reset_confirmation.gd",
    "tests/scene/test_settings_localization_scene.gd",
    "tests/integration/test_settings_shared_hosts.gd",
)
PRODUCTION_PATHS = (
    "scripts/ui/pause/PauseQuickCommands.gd",
    "scripts/ui/pause/PauseSurface.gd",
    "scripts/ui/SettingsContent.gd",
    "scripts/ui/SettingsPanelController.gd",
    "autoload/SaveManager.gd",
    "scripts/application/backup/BackupPresentationPort.gd",
    "scripts/ui/desktop/QuickStatusEdge.gd",
    "scripts/ui/BackupApp.gd",
)
RUNNER = "tools/testing/run_reading_rail_journey.py"
JOURNEY = "tests/integration/verify_reading_rail_journey.gd"
SUITE_RUNNER = "tools/testing/Invoke-CloudTests.ps1"
WORKFLOW = ".github/workflows/paused-settings-f9-cloud.yml"


def require(value: object, message: str) -> None:
    if not value:
        raise ValueError(message)


def identity(raw: bytes) -> dict:
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


class Source:
    def __init__(self, repo: Path, commit: str | None, baseline: str):
        self.repo = repo.resolve()
        self.commit = commit
        self.baseline = baseline
        self.inventory: dict[str, dict] = {}
        require(re.fullmatch(r"[0-9a-f]{40}", baseline), "Exact lowercase 40-character baseline SHA required")
        subprocess.run(["git", "-C", str(self.repo), "cat-file", "-e", baseline + "^{commit}"], check=True)
        if commit:
            require(re.fullmatch(r"[0-9a-f]{40}", commit), "Exact lowercase 40-character source SHA required")
            actual = subprocess.check_output(
                ["git", "-C", str(self.repo), "rev-parse", commit + "^{commit}"], text=True
            ).strip()
            require(actual == commit, "Source must name an exact locally materialized commit")
            subprocess.run(["git", "-C", str(self.repo), "merge-base", "--is-ancestor", baseline, commit], check=True)

    def read(self, relative: str) -> bytes:
        path = Path(relative)
        require(not path.is_absolute() and ".." not in path.parts, "Repository-relative source path required")
        raw = (self.repo / path).read_bytes()
        if self.commit:
            committed = subprocess.check_output(
                ["git", "-C", str(self.repo), "show", self.commit + ":" + relative]
            )
            require(raw == committed, "Working bytes do not match frozen source: " + relative)
        self.inventory[relative] = identity(raw)
        return raw

    def changed_fixtures(self) -> tuple[str, ...]:
        command = ["git", "-C", str(self.repo), "diff", "--name-only", "-z", self.baseline]
        if self.commit:
            command.append(self.commit)
        command += ["--", "tests"]
        changed = subprocess.check_output(command).decode().split("\0")
        if not self.commit:
            changed += subprocess.check_output([
                "git", "-C", str(self.repo), "ls-files", "--others", "--exclude-standard", "-z", "--", "tests"
            ]).decode().split("\0")
        return tuple(sorted({path for path in changed if Path(path).name.startswith("test_") and path.endswith(".gd")}))


def suite_census(source: Source, selected: tuple[str, ...], affected: tuple[str, ...]) -> dict:
    raw = source.read(SUITE_RUNNER)
    groups = {
        name: re.findall(r"'([^']+\.gd)'", body)
        for name, body in re.findall(r"^    (\w+) = @\((.*?)^    \)", raw.decode("utf-8-sig"), re.M | re.S)
    }
    require(len(set(selected)) == len(selected) and "public_surfaces" not in selected,
            "Select unique ordinary suites; public_surfaces is an independent mandatory job")
    names = ("public_surfaces", *selected)
    require(all(groups.get(name) for name in names), "Selected canonical suite is absent or unparsable")
    owners = {path: [name for name, scripts in groups.items() if path in scripts] for path in affected}
    require(all(owners[path] and set(owners[path]).intersection(names) for path in affected),
            "Affected fixture is unregistered or excluded from candidate: " + json.dumps(owners))
    census = {}
    identities = set()
    unique_scripts = set()
    for name in names:
        paths = groups[name]
        require(len(paths) == len(set(paths)), "Duplicate script registration in suite: " + name)
        scripts = []
        for path in paths:
            data = source.read(path)
            tests = re.findall(r"^func (test_\w+)\(", data.decode("utf-8-sig"), re.M)
            require(tests and len(tests) == len(set(tests)), "Absent or duplicate static test functions: " + path)
            scripts.append({"path": path, **identity(data), "static_test_names": tests,
                            "static_case_count": len(tests)})
            unique_scripts.add(path)
            identities.update((path, test) for test in tests)
        census[name] = {"scripts": scripts, "script_count": len(scripts),
                        "static_case_count": sum(item["static_case_count"] for item in scripts)}
    return {
        "suite_runner": {"path": SUITE_RUNNER, **identity(raw)},
        "affected_fixture_suites": owners,
        "suites": census,
        "predicted_case_executions": sum(item["static_case_count"] for item in census.values()),
        "predicted_script_executions": sum(item["script_count"] for item in census.values()),
        "predicted_unique_cases": len(identities),
        "predicted_unique_scripts": len(unique_scripts),
        "limit": "Static source census is not execution evidence. Audit actual cloud XML against these named scripts/tests; reject failures, errors, skips and undiscovered fixtures. Parameterized runtime cases can require an explicitly reviewed count adjustment.",
    }


def runner_contract(source: Source) -> dict:
    raw = source.read(RUNNER)
    tree = ast.parse(raw.decode("utf-8-sig"), filename=RUNNER)
    literals = {node.value for node in ast.walk(tree) if isinstance(node, ast.Constant) and isinstance(node.value, str)}
    mode_constants = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            name = node.targets[0].id
            if name.endswith("MODES"):
                value = ast.literal_eval(node.value)
                require(isinstance(value, (list, tuple)) and all(isinstance(item, str) for item in value),
                        "Mode constant must be a literal string sequence: " + name)
                mode_constants[name] = list(value)
    fixture = source.read(JOURNEY)
    f9_present = "settings-load" in literals and "settings_load" in literals and '"settings-load"' in fixture.decode("utf-8-sig")
    if source.commit:
        require(f9_present, "Frozen source lacks the agreed settings-load runner/fixture declarations")
    return {
        "command": "python3 " + RUNNER,
        "runner": {"path": RUNNER, **identity(raw)},
        "fixture": {"path": JOURNEY, **identity(fixture)},
        "declared_mode_constants": mode_constants,
        "f9_declarations_present": f9_present,
        "original_reading": {"modes": ["write", "read", "repeat", "variant", "witness-read", "next-unseen", "next", "next-read"],
                             "unchanged_command_and_original_seal_required": True},
        "settings_f5": {"modes": ["settings-write", "settings-read"],
                        "parent_result_key": "settings_quick_save", "artifact_subdirectory": "settings-quick/"},
        "settings_f9": {"modes": ["settings-load"],
                        "parent_result_keys": ["settings_quick_save", "settings_load"],
                        "artifact_subdirectory": "settings-load/",
                        "planned_order": "After original F5 writer/reader validation in the same isolated Settings user profile.",
                        "required_evidence": ["raw input trace", "paused Settings baseline", "final exact file copies", "independent settings-load-transactions.jsonl"],
                        "preserve": ["original eight-mode proof and seal", "F5 writer/reader reports and seal", "original F5 transactions.jsonl"]},
        "limit": "Declaration checks do not prove runtime mode execution or semantic acceptance. Verify actual process records, traces, seals, save bytes, failures and assertions from the completed artifact.",
    }


def build(source_sha: str | None, repo: Path, baseline: str, branch: str, suites: tuple[str, ...], affected: tuple[str, ...]) -> tuple[dict, dict]:
    source = Source(repo, source_sha, baseline)
    canonical_path = source.repo / ".github/workflows/windows-tests.yml"
    canonical_raw = source.read(".github/workflows/windows-tests.yml")
    canonical = yaml.safe_load(canonical_raw)
    pin = source_sha or PLACEHOLDER
    workflow, base_manifest = diagnostic.build(source_sha or "0" * 40, branch, canonical_path)
    public = deepcopy(canonical["jobs"]["public-surfaces"])
    focused = deepcopy(canonical["jobs"]["focused-tests"])
    for job in (public, focused):
        require(job["runs-on"] == "windows-2022" and job["defaults"]["run"]["shell"] == "pwsh",
                "Canonical Windows runner or shell changed; inspect derivation")
    matrix = focused["strategy"]["matrix"]
    require(set(matrix) == {"suite"} and set(suites).issubset(matrix["suite"]), "Selected canonical suites are missing")
    matrix["suite"] = list(suites)
    require(focused.get("needs") == "public-surfaces", "Canonical public gate dependency changed")
    regeneration = [step for step in public["steps"] if step.get("run", "").strip() == "./tools/testing/Invoke-PublicSurfaceValidation.ps1 -EmitPayloads"]
    require(len(regeneration) == 1, "Expected one canonical public inventory validation command")
    regeneration[0]["name"] = "Generate affected public inventories for review"
    regeneration[0]["run"] = "./tools/testing/Invoke-PublicSurfaceValidation.ps1 -Regenerate -EmitPayloads"
    rendered = workflow["jobs"].pop("cold-layout-journey")
    rendered["name"] = "Rendered paused Settings F9 / original and F5 reading journeys and UI literal audit"
    rendered["timeout-minutes"] = canonical["jobs"]["rendered-journeys"]["timeout-minutes"]
    rendered["needs"] = canonical["jobs"]["rendered-journeys"]["needs"]
    require(rendered["needs"] == "public-surfaces", "Canonical rendered public gate dependency changed")
    workflow["name"] = "Paused Settings F9 focused candidate"
    workflow["concurrency"]["group"] = "paused-settings-f9-${{ github.ref }}"
    workflow["jobs"] = {"public-surfaces": public, "focused-tests": focused, "paused-settings-reading": rendered}
    for job in workflow["jobs"].values():
        checkouts = [step for step in job["steps"] if step.get("uses") == "actions/checkout@v7"]
        require(len(checkouts) == 1, "Exactly one checkout per engine job required")
        checkouts[0].setdefault("with", {}).update({"ref": pin, "fetch-depth": 0})
        for step in job["steps"]:
            if step.get("uses", "").startswith("actions/upload-artifact@"):
                require(step.get("if") == "always()" and step["with"].get("include-hidden-files"),
                        "Evidence uploads must always run and retain hidden files")
    changed_fixtures = source.changed_fixtures()
    census = suite_census(source, suites, tuple(dict.fromkeys((*affected, *changed_fixtures))))
    contract = runner_contract(source)
    for path in PRODUCTION_PATHS:
        source.read(path)
    manifest = {
        "schema_version": 1,
        "source_checkout": pin,
        "accepted_baseline": baseline,
        "source_pending": source_sha is None,
        "publish_ready": source_sha is not None,
        "trigger_branch": branch,
        "workflow_repository_path": WORKFLOW,
        "canonical_workflow": {"path": ".github/workflows/windows-tests.yml", **identity(canonical_raw)},
        "job_count": len(suites) + 2,
        "job_definition_count": 3,
        "expected_ordinary_xml_count": len(suites) + 1,
        "focused_suites": list(suites),
        "public_inventory_mode": "Regenerate EmitPayloads",
        "public_inventory_command": regeneration[0]["run"],
        "retained_journey_artifact_root": base_manifest["retained_journey_artifact_root"],
        "suite_census": census,
        "automatically_discovered_changed_fixtures": list(changed_fixtures),
        "reading_contract": contract,
        "source_file_identities": source.inventory,
        "derivation_helpers": [{"path": str(path.resolve()), **identity(path.read_bytes())}
                               for path in (Path(__file__), Path(diagnostic.__file__))],
        "derived_steps": {name: [step.get("name", step.get("uses")) for step in job["steps"]]
                          for name, job in workflow["jobs"].items()},
        "scope": [
            "Paused Settings F9 admission, consent, Cancel/failure return and successful restore through existing owners.",
            "Settings preview/controller interactions and original F5 source/host preservation regression coverage.",
            "Quick feedback additions: empty Quick reports No Quick Save; known inspected compatibility/technical reason retained; nonloadable Backup no longer implies fallback consent.",
            "Existing save/recovery/history guarantees, public signatures and formats are required invariants; verify generated inventory changes rather than assuming invariance.",
        ],
        "limits": [
            "Focused candidate gate only; final stable production source still requires the canonical broad gate.",
            "Generated public inventories require source-bound review and exact-byte adoption before committed-inventory verification.",
            "Auxiliary workflow head differs from tested source; bind all execution claims to actual checkout logs.",
            "Auxiliary branch updates must fast-forward; keep candidate workflow off the PR source branch.",
            "A draft with the explicit source placeholder is not publish-ready.",
            "The runner command retains original eight reading modes and F5 writer/reader proof; independently audit F9 execution and semantics in its own evidence.",
            "The separate physical catalogue-v2 journey and unrelated canonical suites remain responsibilities of the final broad gate.",
            "Linux software rendering does not establish native Windows graphics, native accessibility or physical input-to-paint acceptance.",
            "Unit fault injection and process-level restore proof do not establish OS-crash resilience.",
            "No claim of exhaustive feedback branches, unexercised Settings preview states, localization execution or whole-product acceptance follows from a passing workflow alone.",
        ],
    }
    return workflow, manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", help="Exact frozen source commit; omit only for an explicit nonpublishable draft")
    parser.add_argument("--repo", type=Path, default=Path(__file__).parent / "dwm")
    parser.add_argument("--baseline", default=DEFAULT_BASELINE, help="Accepted ancestor for discovery of every changed GUT fixture")
    parser.add_argument("--branch", default=DEFAULT_BRANCH)
    parser.add_argument("--suites", nargs="+", default=list(DEFAULT_SUITES), help="Canonical ordinary suite names; each creates one Windows job")
    parser.add_argument("--affected-fixture", action="append", default=[], help="Additional changed fixture that must be registered in a selected canonical suite")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    affected = tuple(dict.fromkeys((*DEFAULT_FIXTURES, *args.affected_fixture)))
    workflow, manifest = build(args.source, args.repo, args.baseline, args.branch, tuple(args.suites), affected)
    raw = yaml.safe_dump(workflow, sort_keys=False, width=120).encode("utf-8")
    require(yaml.safe_load(raw) == workflow, "Workflow serialization did not round-trip")
    manifest["workflow_sha256"] = hashlib.sha256(raw).hexdigest()
    manifest_path = args.output.with_name(args.output.name + ".manifest.json")
    serialized = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    for path, content in ((args.output, raw), (manifest_path, serialized)):
        require(not path.exists() or path.read_bytes() == content,
                "Refusing to overwrite differing retained workflow/provenance: " + str(path))
    for path, content in ((args.output, raw), (manifest_path, serialized)):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    print(json.dumps({"workflow": str(args.output.resolve()), "manifest": str(manifest_path.resolve()),
                      "source": manifest["source_checkout"], "branch": args.branch,
                      "jobs": manifest["job_count"], "expected_xml": manifest["expected_ordinary_xml_count"],
                      "publish_ready": manifest["publish_ready"],
                      "predicted_cases": manifest["suite_census"]["predicted_case_executions"],
                      "predicted_scripts": manifest["suite_census"]["predicted_script_executions"],
                      "workflow_sha256": manifest["workflow_sha256"]}))


if __name__ == "__main__":
    main()
