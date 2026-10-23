#!/usr/bin/env python3
"""Package immutable cloud-only timed-hold failures; never execute a game engine."""
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import xml.etree.ElementTree as ET
import zipfile


RUNS = {
    "red1": {
        "run": 37091802987, "job": 111113526600,
        "source": "cdd08426e5d7f43aa2ad43caa508ab0d353018f6",
        "workflow": "ab49046d36679b1cca6f4c40766a7ff501ed9b21",
        "snapshot": "hold-red1-final", "generator": "build_timed_hold_workflow.red1.py",
        "assertions": 133, "failed_assertions": 14,
        "qualification": "Includes an invalid same-resource assumption alongside observed native defects; Red2 corrects only that assertion boundary.",
    },
    "red2": {
        "run": 37092157492, "job": 111114589404,
        "source": "95a514919ddd4abf44dbb26362e9d91e1ec0cdc0",
        "workflow": "b7fcb3eb8007bce202426390770e2f7381d2d489",
        "snapshot": "hold-red2-source", "generator": "build_timed_hold_workflow.py",
        "assertions": 134, "failed_assertions": 13,
        "qualification": "Corrected test-only baseline reproduces the three intended native failure cases without the Red1 resource-identity assumption.",
    },
}
WORKFLOW_PATH = ".github/workflows/timed-hold-cloud.yml"
TEST_PATH = "tests/integration/test_dialogic_timed_hold_runtime.gd"
DTL_PATH = "tests/fixtures/dialogic/timed_hold_runtime.dtl"
WAIT_PATH = "addons/dialogic/Modules/Wait/event_wait.gd"
EXPECTED_WAIT_SHA256 = "36615fe758680ee4efcacef4f9d244d1900b4b68e6806e1ac0ea6b8956b85fc8"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def write_exact(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        assert path.read_bytes() == data, f"Refusing to replace different sealed bytes: {path}"
    else:
        path.write_bytes(data)


def package_run(workspace: Path, output: Path, name: str, config: dict) -> dict:
    repo = workspace / "dwm"
    capture = workspace / ("hold-" + name)
    source_dir = workspace / config["snapshot"]
    payload: dict[str, bytes] = {}
    origins: dict[str, str] = {}

    def git(*args: str) -> bytes:
        return subprocess.check_output(["git", *args], cwd=repo)

    def add(path: Path) -> None:
        assert path.is_file() and not path.is_symlink(), path
        relative = path.relative_to(workspace).as_posix()
        assert relative not in payload, relative
        payload[relative] = path.read_bytes()
        origins[relative] = relative

    def generated(relative: str, data: bytes, origin: str) -> None:
        assert relative not in payload, relative
        payload[relative] = data
        origins[relative] = origin

    run = json.loads((capture / "run.json").read_text())
    jobs = json.loads((capture / "jobs.json").read_text())
    api = json.loads((capture / "artifacts-api.json").read_text())
    artifacts = json.loads((capture / "artifact-manifest.json").read_text())
    assert run["id"] == config["run"] and run["run_attempt"] == 1
    assert run["conclusion"] == "failure" and run["head_sha"] == config["workflow"]
    assert jobs["total_count"] == len(jobs["jobs"]) == 1
    assert jobs["jobs"][0]["id"] == config["job"] and jobs["jobs"][0]["conclusion"] == "failure"
    assert json.loads((capture / "omissions.json").read_text()) == {}
    assert api["total_count"] == len(api["artifacts"]) == len(artifacts) == 1
    artifact = artifacts[0]
    zip_path = Path(artifact["local_zip"])
    if not zip_path.is_file():
        # The record is immutable; relocate only the lookup when rebuilding in
        # another workspace while retaining its original artifact identity.
        parts = zip_path.parts
        zip_path = workspace.joinpath(*parts[parts.index("attachments"):])
    raw_zip = zip_path.read_bytes()
    assert len(raw_zip) == artifact["size_in_bytes"] == api["artifacts"][0]["size_in_bytes"]
    assert artifact["id"] == api["artifacts"][0]["id"]
    assert "sha256:" + digest(raw_zip) == artifact["digest"] == api["artifacts"][0]["digest"]
    extracted_root = capture / "artifacts" / artifact["name"]
    with zipfile.ZipFile(io.BytesIO(raw_zip)) as archive:
        assert archive.testzip() is None
        members = [member for member in archive.infolist() if not member.is_dir()]
        assert len(members) == 5
        extracted_files = {path.relative_to(extracted_root).as_posix() for path in extracted_root.rglob("*") if path.is_file()}
        assert extracted_files == {member.filename for member in members}
        for member in members:
            assert not member.filename.startswith("/") and ".." not in Path(member.filename).parts
            assert (extracted_root / member.filename).read_bytes() == archive.read(member)

    xml = ET.parse(extracted_root / "ci/timed-hold-fixture.xml").getroot()
    cases = xml.findall(".//testcase")
    assert len(cases) == 4 and len(xml.findall(".//failure")) == 3
    assert not xml.findall(".//error") and not xml.findall(".//skipped")
    assert sum(int(case.attrib["assertions"]) for case in cases) == config["assertions"]
    assert int(xml.find("testsuite").attrib["failures"]) == config["failed_assertions"]

    capture_paths = sorted(path for path in capture.rglob("*") if path.is_file())
    snapshot_paths = sorted(path for path in source_dir.rglob("*") if path.is_file())
    for path in capture_paths + snapshot_paths:
        add(path)
    add(zip_path)

    source_manifest = json.loads((source_dir / "manifest.json").read_text())
    source_publication = json.loads((source_dir / "publication.json").read_text())
    assert source_publication["commit"]["sha"] == config["source"]
    assert git("rev-parse", config["source"] + "^{tree}").decode().strip() == source_manifest["tree"]
    changed = git("diff", "--name-only", source_manifest["parent"], config["source"]).decode().splitlines()
    assert changed == sorted(record["path"] for record in source_manifest["files"])
    for record in source_manifest["files"]:
        data = (source_dir / record["path"]).read_bytes()
        assert len(data) == record["bytes"] and digest(data) == record["sha256"]
        assert data == git("show", config["source"] + ":" + record["path"])

    workflow_file = workspace / "hold-cloud-plan" / ("timed-hold-" + name + ".yml")
    workflow_manifest_file = Path(str(workflow_file) + ".manifest.json")
    workflow_manifest = json.loads(workflow_manifest_file.read_text())
    assert digest(workflow_file.read_bytes()) == workflow_manifest["workflow_sha256"]
    assert workflow_file.read_bytes() == git("show", config["workflow"] + ":" + WORKFLOW_PATH)
    assert git("diff", "--name-status", config["source"], config["workflow"]).decode().strip() == "A\t" + WORKFLOW_PATH
    for path in [workflow_file, workflow_manifest_file,
                 workspace / "hold-cloud-plan" / (name + "-publication.json"),
                 workspace / "hold-cloud-plan" / (name + "-tree-review.json"),
                 workspace / "hold-cloud-plan" / (name + "-api-commit.json"),
                 workspace / "hold-cloud-plan/import_auxiliary_tree.py"]:
        add(path)

    review_path = workspace / "hold-contract-review" / (name + "-evidence-review.json")
    review = json.loads(review_path.read_text())
    assert review["run"]["actual_checkout"] == config["source"]
    assert review["run"]["workflow_head"] == config["workflow"]
    assert review["census"]["failed_cases"] == 3 and review["census"]["passed_cases"] == 1
    for record in review["inputs"]:
        data = (workspace / record["path"]).read_bytes()
        assert len(data) == record["bytes"] and digest(data) == record["sha256"], record["path"]
    add(review_path)
    add(workspace / "hold-contract-review" / ("audit_" + name + ".py"))

    # Preserve exactly the generator bytes identified by the historical manifest.
    generator_sources = [workspace / "hold-cloud-plan" / config["generator"]]
    generator_sources += [workspace / "hospital-tools" / Path(record["path"]).name for record in workflow_manifest["helpers"][1:]]
    for recorded, actual in zip(workflow_manifest["helpers"], generator_sources, strict=True):
        data = actual.read_bytes()
        assert len(data) == recorded["bytes"] and digest(data) == recorded["sha256"], actual
        add(actual)

    for suffix in ["workflow-api-commit.json", "source-workflow-api-compare.json"]:
        add(workspace / "hold-evidence-stage/inputs" / (name + "-" + suffix))

    source_context = {}
    # Materialize both executed fixture files even when Red2's delta only holds
    # the changed test. The unchanged native Wait is comparison context only.
    for source_path in [TEST_PATH, DTL_PATH, WAIT_PATH]:
        data = git("show", config["source"] + ":" + source_path)
        if source_path == WAIT_PATH:
            assert digest(data) == EXPECTED_WAIT_SHA256
        destination = "source-context/" + name + "/" + source_path
        generated(destination, data, "git:" + config["source"] + ":" + source_path)
        source_context[source_path] = {"bytes": len(data), "sha256": digest(data), "payload_path": destination}
    provenance = {
        "schema_version": 1, "source_commit": config["source"], "workflow_commit": config["workflow"],
        "source_parents": git("show", "-s", "--format=%P", config["source"]).decode().strip().split(),
        "workflow_parents": git("show", "-s", "--format=%P", config["workflow"]).decode().strip().split(),
        "source_tree": git("rev-parse", config["source"] + "^{tree}").decode().strip(),
        "workflow_tree": git("rev-parse", config["workflow"] + "^{tree}").decode().strip(),
        "sole_auxiliary_tree_change": "A\t" + WORKFLOW_PATH,
        "executed_fixture_and_unchanged_baseline_runtime_context": source_context,
        "native_wait_is_historical_baseline_not_candidate": True,
    }
    generated("source-context/" + name + "/provenance.json", json_bytes(provenance), "derived from immutable Git objects")

    readme = f"""# Timed-hold {name} diagnostic evidence

Run {config['run']}, attempt 1, is intentionally retained as **failure**: one
positive control and three failing test cases, with no XML errors or skips.
GUT reports {config['failed_assertions']} failed assertions, not that many failed cases.

{config['qualification']}

The executed checkout is `{config['source']}`. The auxiliary workflow head is
`{config['workflow']}`; its sole tree addition is `{WORKFLOW_PATH}`.
The native Wait implementation is the unchanged baseline. No fixed-runtime or
rendered/UI acceptance is claimed by this archive.

The package includes every captured API record, job log, the exact original
artifact ZIP, all five extracted artifact files, every published source-snapshot
file, workflow and publication records, historical generator dependencies and
independent audit scripts/reports. No in-scope captured file is excluded.
Source-context copies are bound to the executed commit, never current worktree
content. Candidate/green sources and unpublished preliminary snapshots are
explicitly outside this failed-run evidence scope.

One ObjectDB shutdown warning occurs in the import process job console, while
the import.log and fixture log artifacts do not contain it. This is not warning-
free or leak-free import acceptance. Native fixture Profile snapshots began as
empty dictionaries; they are not initialized durable Profile-byte evidence.

inventory.json lists every payload byte identity except itself. Its identity
and the complete archive identity are bound by the external package manifest.
The original auditors are preserved without rewriting their workspace paths;
rerunning them requires these captured paths and the cited repository commits.
Package construction/round-trip verification uses only Python and read-only Git.
"""
    generated("README.md", readme.encode(), "bounded package explanation")
    inventory = {
        "schema_version": 1, "run": config["run"], "stage": name,
        "scope": "complete failed-run capture plus explicit published source/workflow/audit context",
        "capture_file_count": len(capture_paths), "source_snapshot_file_count": len(snapshot_paths),
        "extracted_artifact_file_count": 5, "original_zip_count": 1,
        "excluded_in_scope_files": [],
        "outside_scope": ["green/fixed-runtime candidates and later executions", "unpublished preliminary snapshots", "unrelated workspace files"],
        "self_identity_bound_by": "external package manifest and complete archive SHA256",
        "files": [{"path": path, "bytes": len(data), "sha256": digest(data), "origin": origins[path]}
                  for path, data in sorted(payload.items())],
    }
    inventory_data = json_bytes(inventory)
    payload["inventory.json"] = inventory_data
    stage_payload = output / (name + "-payload")
    for relative, data in sorted(payload.items()):
        write_exact(stage_payload / relative, data)

    tar_bytes = io.BytesIO()
    with tarfile.open(fileobj=tar_bytes, mode="w", format=tarfile.USTAR_FORMAT) as archive:
        for relative, data in sorted(payload.items()):
            member = tarfile.TarInfo(relative)
            member.size, member.mode, member.uid, member.gid, member.mtime = len(data), 0o644, 0, 0, 0
            member.uname = member.gname = ""
            archive.addfile(member, io.BytesIO(data))
    compressed = io.BytesIO()
    with gzip.GzipFile(fileobj=compressed, mode="wb", filename="", mtime=0, compresslevel=9) as gz:
        gz.write(tar_bytes.getvalue())
    archive_data = compressed.getvalue()
    archive_name = "timed-hold-" + name + "-diagnostic-evidence.tar.gz"
    write_exact(output / archive_name, archive_data)
    with tarfile.open(fileobj=io.BytesIO(archive_data), mode="r:gz") as archive:
        members = archive.getmembers()
        assert {member.name for member in members} == set(payload)
        assert len(members) == len(payload)
        for member in members:
            assert member.isfile() and archive.extractfile(member).read() == payload[member.name]
    manifest = {
        "schema_version": 1, "status": "complete_diagnostic_failure_archive_not_acceptance",
        "run": config["run"], "source_commit": config["source"], "workflow_commit": config["workflow"],
        "archive": {"path": archive_name, "bytes": len(archive_data), "sha256": digest(archive_data)},
        "inventory": {"path": name + "-inventory.json", "bytes": len(inventory_data), "sha256": digest(inventory_data)},
        "payload_file_count_excluding_inventory": len(payload) - 1,
        "archive_member_count": len(payload), "payload_bytes_including_inventory": sum(map(len, payload.values())),
        "capture_files": len(capture_paths), "source_snapshot_files": len(snapshot_paths),
        "original_zip": {"bytes": len(raw_zip), "sha256": digest(raw_zip)},
        "round_trip": "all members byte-equal; complete set; deterministic tar metadata and gzip mtime",
        "excluded_in_scope_files": [], "engine_or_powershell_executed": False,
    }
    write_exact(output / (name + "-inventory.json"), inventory_data)
    write_exact(output / (name + "-package-manifest.json"), json_bytes(manifest))
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    manifests = [package_run(args.workspace.resolve(), args.output.resolve(), name, config) for name, config in RUNS.items()]
    summary = {"status": "staged_only_not_repository_adopted", "runs": manifests,
               "total_archive_bytes": sum(row["archive"]["bytes"] for row in manifests),
               "total_archive_members": sum(row["archive_member_count"] for row in manifests),
               "no_fixed_runtime_acceptance_claim": True}
    write_exact(args.output / "red-evidence-summary.json", json_bytes(summary))
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
