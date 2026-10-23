#!/usr/bin/env python3
"""Materialize Run128 Settings-F5 records only after exact final acceptance.

Prepared task-locally while the broad run is pending; do not confuse preparing
this program with executing it. Default is a validated dry-run. --apply writes
only the new evidence folder and the lead Bead's notes/updated_at, plus a task-local
PR-body draft. No engines, Git writes, network access, navigation edits or publish.
Requires prepare_settings_navigation.py beside this file as a guard dependency.
"""

import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import sys
import tarfile
import tempfile
from types import SimpleNamespace

import prepare_settings_navigation as guard


SOURCE = "16484fe4eaecf3c49fe2fbb0f46a543a493b57bf"
CHECKOUT = "885daae62be2ecdfd8f601cd1c6028eeb12c5243"
RUN_ID = 36967371973
RUN_NUMBER = 128
BASELINE = "5a581fc89121864aead5202e01d6a82423b1b52d"
LEAD = "dwm-vky.14"
DESTINATION = "evidence/phase_2r/paused_settings_quick_2026_10_02"
BEADS_BASELINE_SHA256 = "b4f4d7f08a7c823321b22e8d650e44868e26ac5fc03c0006efe46961024b2375"
FOCUSED = {
    "focus1": (36964699167, "e6d445343c292342310359faa898aabd2959f4db", "failure"),
    "focus2": (36965784091, "63b59b67a169a34a17f0f5ec4c15b98a55c6ff2b", "failure"),
    "focus3": (36966651051, "8c4218cc880f16e69854115e7b5263a00982d1bb", "success"),
}
SOURCE_REVIEWS = [
    "settings-desktop-type-mismatch-review.json",
    "settings-focus1-public-inventory-review.json",
    "settings-focus2-public-inventory-review.json",
    "settings-focus3-public-inventory-review.json",
    "settings_f5_final_source/final-source-review.json",
    "settings_f5_final_source/preliminary-merge-boundary.json",
]
HELPERS = [
    "cloud_evidence.py", "capture_cloud_evidence.py", "layout_evidence.py",
    "audit_layout_observations.py", "audit_settings_quick_journey.py",
    "audit_settings_reset_focus.py", "join_settings_acceptance.py",
    "settings_focus1_inventory_review.py", "settings_focus2_inventory_review.py",
    "settings_focus3_inventory_review.py", "prepare_settings_window_source_review.py",
    "build_settings_reset_workflow.py", "build_paused_settings_workflow.py",
    "build_layout_workflow.py", "check_settings_quick_validator.py",
    "settings-quick-validator-review.json", "settings_acceptance_adapter_sources.json",
    "paused-settings-cloud/verify_auditor_controls.py",
    "paused-settings-cloud/auditor-control-results.json",
    "paused-settings-cloud/e6d4453.yml", "paused-settings-cloud/e6d4453.yml.manifest.json",
    "paused-settings-cloud/focus2.yml", "paused-settings-cloud/focus2.yml.manifest.json",
    "paused-settings-cloud/focus3-reviewed.yml", "paused-settings-cloud/focus3-reviewed.yml.manifest.json",
]
HELPER_DIRS = ["settings_acceptance_adapters", "settings_f5_review_adapters_v2", "settings-performance-tools"]
LIMITS = [
    "Bounded noncanonical English Solo first-line paused Settings F5 and silent fresh Quick Load only; production catalogue registration remains disabled.",
    "Original eight reading modes and their 14-file seal are retained. The supplemental Settings writer/reader uses two distinct OS processes and a separate three-file writer seal.",
    "Raw Quick bytes are archived and directly audited. Unchanged Profile and Autosave are proved by hash-and-size receipts and writer FileOps observations, not by newly archived raw Profile/Autosave copies.",
    "The physical catalogue-v2 proof retains only its observed sweet/exploded disposition, independent frame checks, actual Next Autosave endpoints and final-Quick fresh Load; other production variants are not accepted.",
    "The retained title guard covers 480 visible geometry observations. Historical original PNGs already showed the complete title; no title-layout runtime repair or glyph-pixel/all-locale acceptance is claimed.",
    "Settings F9 remains unavailable in this F5 increment. Guarded Settings Quick Load is separate pending work under ordered-ending amendment sections 13.4 and 24.5.",
    "Supported save formats, public port signatures, Save/Profile ownership and production catalogue registration are unchanged.",
    "No whole-game, native all-input/accessibility, OS-crash, pixel-identical transient scrollback or final visual-polish acceptance is claimed.",
    "Source reviews retain their original source-only and broad-pending-at-review fields. Final broad acceptance is recorded separately here and in the exact Run128 summary.",
    "Compressed packages preserve their explicit exclusions. Original local_zip manifests and binary downloads are not all embedded; reproducing an auditor may require reobtaining its identity-bound upstream artifact. Preserving helpers is not a claim of fully offline replay.",
    "All 23 unfinished Beads remain; only the lead note/timestamp changes. No live Dolt query, synchronization, task closure, PR publication or merge occurs here.",
    "Documentation/evidence descendants are not separately engine-tested.",
]

require = guard.require
read_json = lambda path: guard.strict_json(path.read_bytes())


def identity(raw):
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def file_identity(path):
    require(path.is_file() and not path.is_symlink(), "Missing or symlinked input: " + str(path))
    hasher = hashlib.sha256()
    length = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            length += len(chunk)
            hasher.update(chunk)
    return {"bytes": length, "sha256": hasher.hexdigest()}


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def safe_relative(name):
    path = PurePosixPath(name)
    require(name and not path.is_absolute() and ".." not in path.parts and "\\" not in name
            and ":" not in name, "Unsafe relative path: " + str(name))
    return path


def verify_package(folder, label, summary_raw):
    """Verify every listed payload in-place, without extraction or log duplication."""
    manifest_raw = (folder / "manifest.json").read_bytes()
    manifest = guard.strict_json(manifest_raw)
    receipt = read_json(folder / "bundle-receipt.json")
    archive_name = receipt["archive"]
    require(str(safe_relative(archive_name)) == Path(archive_name).name, "Archive must be local to its package")
    archive = folder / archive_name
    require(file_identity(archive) == {key: receipt[key] for key in ("bytes", "sha256")}, "Archive bytes differ: " + label)
    require(identity(manifest_raw)["sha256"] == receipt["manifest_sha256"], "Package manifest changed")
    require(receipt["round_trip_verified"] is True, "Package round-trip verification missing")
    require(manifest["bundle"] == archive_name, "Manifest/archive names differ")
    require(manifest["run"]["status"] == "completed", "Package run still pending")
    run = manifest["run"]
    boundary = manifest["source_boundary"]
    if label in FOCUSED:
        run_id, source, conclusion = FOCUSED[label]
        require(run["id"] == run_id and run["conclusion"] == conclusion, "Focused run binding differs")
        require(boundary["source"] == boundary["tested_checkout"] == source, "Focused source binding differs")
        expected_kind = "failed-run-diagnostic-only" if conclusion == "failure" else "bounded-successful-run-audit"
        require(manifest["evidence_kind"] == receipt["evidence_kind"] == expected_kind, "Focused scope was broadened")
    else:
        require(run["id"] == RUN_ID and run["run_number"] == RUN_NUMBER and run["conclusion"] == "success",
                "Broad package run binding differs")
        require(boundary["source"] == SOURCE and boundary["tested_checkout"] == CHECKOUT, "Broad package source binding differs")
        require(manifest["generic_audit_pass"] is True, "Broad package generic audit is incomplete")
    listed = {row["path"]: row for row in manifest["payload_files"]}
    require(len(listed) == len(manifest["payload_files"]) == manifest["payload_file_count"] == receipt["payload_file_count"],
            "Package payload count/identity mismatch")
    digest_members = {}
    summary_members = []
    with tarfile.open(archive, "r:gz") as bundle:
        members = bundle.getmembers()
        require(len({member.name for member in members}) == len(members) == receipt["archive_member_count"],
                "Package member count or duplicates differ")
        require({member.name for member in members} == set(listed) | {"README.txt", "manifest.json"},
                "Unexpected or missing package member")
        for member in members:
            safe_relative(member.name)
            require(member.isfile(), "Only ordinary archive files are allowed")
            require("__pycache__" not in PurePosixPath(member.name).parts and not member.name.endswith(".pyc"),
                    "Generated Python cache must not be packaged")
            stream = bundle.extractfile(member)
            require(stream is not None, "Unreadable package member")
            if member.name == "manifest.json":
                require(stream.read() == manifest_raw, "Inner/outer manifests differ")
                continue
            if member.name == "README.txt":
                continue
            hasher = hashlib.sha256()
            size = 0
            keep_summary = member.name.endswith("/acceptance-summary.json") or member.name == "acceptance-summary.json"
            retained = []
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                hasher.update(chunk)
                size += len(chunk)
                if keep_summary:
                    retained.append(chunk)
            actual = {"bytes": size, "sha256": hasher.hexdigest()}
            require(actual == {key: listed[member.name][key] for key in actual}, "Package payload differs: " + member.name)
            digest_members.setdefault((actual["bytes"], actual["sha256"]), []).append(member.name)
            if keep_summary:
                summary_members.append(b"".join(retained))
    if label == "run128":
        require(summary_raw in summary_members, "Exact final acceptance summary must be inside the immutable broad package")
    expected_sums = {archive_name: receipt["sha256"], "manifest.json": receipt["manifest_sha256"]}
    observed_sums = {}
    for line in (folder / "SHA256SUMS.txt").read_text().splitlines():
        if line:
            sha, name = line.split("  ", 1)
            require(name not in observed_sums, "Duplicate checksum entry")
            observed_sums[name] = sha
    require(observed_sums == expected_sums, "Package checksum index differs")
    return manifest, receipt, digest_members


def validate_components(summary):
    args = SimpleNamespace(source=SOURCE, checkout=CHECKOUT, run_id=RUN_ID, run_number=RUN_NUMBER)
    guard.validate_acceptance(args, summary)
    for key in ("physical_selector", "public_surfaces"):
        value = summary[key]
        require(value["audit_complete"] is True and value["run_id"] == RUN_ID and value["source"] == SOURCE,
                "Component audit/binding is incomplete: " + key)
        require(value.get("checkout", value.get("tested_checkout")) == CHECKOUT, "Component checkout differs: " + key)
        if "runtime_proof_failures" in value:
            require(value["runtime_proof_failures"] == [], "Component runtime failures: " + key)
    next_proof = summary["next"]
    require(next_proof["next_component_audit_pass"] is True and next_proof["source"] == SOURCE
            and next_proof["checkout"] == CHECKOUT and next_proof["run_id"] == RUN_ID, "Next proof is incomplete")
    reading = summary["reading"]
    require(reading["all_process_exits_zero"] is True and reading["modes"] ==
            ["write", "read", "repeat", "variant", "witness-read", "next-unseen", "next", "next-read"],
            "Original eight reading modes are not retained")
    require(reading["write_read_seal"]["file_count"] == 14, "Original 14-file seal missing")
    settings = summary["settings_quick_save"]
    require(set(settings["process_ids"]) == {"settings-write", "settings-read"}
            and len(set(settings["process_ids"].values())) == 2, "Distinct supplemental writer/reader required")
    require(settings["settings_write_seal"]["file_count"] == 3
            and settings["settings_write_seal"]["all_sealed_and_retained_bytes_verified"] is True,
            "Supplemental three-file seal missing")
    require(settings["original_write_read_seal"]["file_count"] == 14
            and settings["original_write_read_seal"]["all_sealed_and_retained_bytes_verified"] is True,
            "Original seal was not independently verified")
    layout = summary["title_layout"]
    require(layout["audit_pass"] is True and layout["source_boundary"] == summary["source_boundary"],
            "Retained title-layout audit incomplete")
    modes = layout["layout_modes"]
    require(len(modes) == 2 and {mode["mode"] for mode in modes} == {"next", "next-read"}, "Title layout modes differ")
    samples = 0
    for mode in modes:
        require(set(mode["streams"]) == {"process", "post_draw"}, "Title observation streams differ")
        for stream in mode["streams"].values():
            require(stream["visible_samples"] == 120 and stream["all_visible_titles_enclosed"] is True,
                    "Retained title geometry proof incomplete")
            samples += stream["visible_samples"]
    require(samples == 480, "Exactly 480 visible geometry observations required")
    physical = summary["physical_selector"]
    require(physical["caption_count"] == physical["canonical_witness_hashes"] == 4
            and physical["restored_speech_admissions"] == 0
            and physical["independent_run_frame_forgery_refused"] is True,
            "Retained physical-v2 semantic proof incomplete")


def prepare_beads(repo, timestamp):
    before = guard.git(repo, "show", SOURCE + ":.beads/issues.jsonl")
    require(identity(before)["sha256"] == BEADS_BASELINE_SHA256, "Unexpected source Beads baseline")
    require((repo / ".beads/issues.jsonl").read_bytes() == before, "Working Beads changed from the accepted source")
    lines = before.splitlines(keepends=True)
    records = [guard.strict_json(line) for line in lines]
    require(len(records) == len({row["id"] for row in records}) == 191, "Expected exactly 191 unique Beads")
    note = (
        f"2026-10-02 accepted bounded paused Settings F5 at source {SOURCE}; tested PR merge {CHECKOUT}; "
        f"broad Run128 ({RUN_ID}) passes 23/23 jobs, 2286 GUT executions / 2282 unique cases / 194 scripts, "
        "zero failures/errors/skips. Fresh admitted F5 completes only the current reveal, retains exact canonical "
        "source/Settings/focus/suspension and commits one Quick transaction; a separate fresh process restores "
        "that point without repeated speech. Original eight reading modes and 14-file seal retained; supplemental "
        "Settings writer/reader is two processes with its own three-file seal. Raw Quick bytes are archived. "
        "Autosave/Profile neutrality uses hash-and-size receipts and writer FileOps observations, not newly "
        "archived raw Autosave/Profile copies. Physical catalogue-v2 observed sweet/exploded proof and 480 "
        "title-geometry observations remain within their prior scope; the historical clipping correction remains "
        "unchanged. Public port signatures, supported formats and production catalogue registration are unchanged. "
        f"Shared receipt: {DESTINATION}/receipt.json. Settings F9 remains unavailable and is the next separately "
        "pending guarded-Load clause under ordered-ending amendment sections13.4/24.5; no architecture question "
        "is needed. Production exact replay, Hospital/ending continuity, native all-input/accessibility and "
        "whole-game/final-polish acceptance remain open. All23unfinished statuses/dependencies remain unchanged; "
        "no closure or live Dolt synchronization. PR stays draft/unmerged; later records commits are not separately engine-tested."
    )
    note = note.replace("sections13.4/24.5", "sections 13.4/24.5").replace("All23unfinished", "All 23 unfinished")
    indices = [index for index, row in enumerate(records) if row["id"] == LEAD]
    require(len(indices) == 1, "Lead Bead missing or duplicate")
    index = indices[0]
    changed = dict(records[index])
    changed["notes"] = changed.get("notes", "") + "\n\n" + note
    changed["updated_at"] = timestamp
    lines[index] = (json.dumps(changed, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
    after = b"".join(lines)
    before_lines = before.splitlines(keepends=True)
    after_lines = after.splitlines(keepends=True)
    for number, (old_raw, new_raw) in enumerate(zip(before_lines, after_lines, strict=True)):
        old, new = guard.strict_json(old_raw), guard.strict_json(new_raw)
        require(old["id"] == new["id"], "Beads ordering changed")
        if number != index:
            require(old_raw == new_raw, "Another Bead changed")
        else:
            require({k: v for k, v in old.items() if k not in {"notes", "updated_at"}} ==
                    {k: v for k, v in new.items() if k not in {"notes", "updated_at"}}, "Lead fields changed beyond note/timestamp")
        require(old.get("status") == new.get("status") and old.get("dependencies") == new.get("dependencies"),
                "A status or dependency changed")
    counts = Counter(row["status"] for row in records)
    require(sum(value for key, value in counts.items() if key != "closed") == 23, "Unfinished count changed")
    audit = {"schema_version": 1, "baseline_source": SOURCE, "before": identity(before), "after": identity(after),
             "records": 191, "changed_records": [LEAD], "changed_fields": ["notes", "updated_at"],
             "other_190_records_byte_identical": True, "all_statuses_and_dependencies_unchanged": True,
             "unfinished": 23, "status_counts": dict(counts), "live_dolt_queried": False, "live_dolt_synchronized": False}
    return before, after, audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument("--repo", type=Path)
    parser.add_argument("--acceptance-summary", type=Path, required=True,
                        help="Completed final summary at the raw run root; packager embeds it but does not copy it loose")
    parser.add_argument("--apply", action="store_true", help="Materialize the guarded records; default validates only")
    args = parser.parse_args()
    root = args.workspace.resolve(strict=True)
    repo = (args.repo or root / "dwm").resolve(strict=True)
    summary_path = args.acceptance_summary.resolve(strict=True)
    summary_raw = summary_path.read_bytes()
    summary = guard.strict_json(summary_raw)
    validate_components(summary)
    guard.validate_source(repo, SOURCE)
    destination = repo / DESTINATION
    require(not destination.exists(), "Destination already exists; never overwrite prior evidence")
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
    before, after, beads_audit = prepare_beads(repo, timestamp)
    plan = {}
    input_identities = {}

    def add(name, source):
        safe_relative(name)
        require(name not in plan, "Duplicate output path: " + name)
        if isinstance(source, Path):
            input_identities[str(source)] = file_identity(source)
        plan[name] = source

    packages = {}
    broad_members = {}
    for label in (*FOCUSED, "run128"):
        folder = root / "settings-evidence" / label
        manifest, receipt, member_index = verify_package(folder, label, summary_raw)
        for name in (receipt["archive"], "manifest.json", "bundle-receipt.json", "SHA256SUMS.txt"):
            add(label + "/" + name, folder / name)
        packages[label] = {"run": manifest["run"], "source_boundary": manifest["source_boundary"],
                           "evidence_kind": manifest["evidence_kind"], "archive": label + "/" + receipt["archive"],
                           "archive_identity": {k: receipt[k] for k in ("bytes", "sha256")},
                           "manifest": label + "/manifest.json", "receipt": label + "/bundle-receipt.json"}
        if label == "run128":
            broad_members = member_index
    add("run128/acceptance-summary.json", summary_raw)
    raw_quick = summary["settings_quick_save"]["raw_quick_identity"]
    quick_members = broad_members.get((raw_quick["bytes"], raw_quick["sha256"]), [])
    require(any(name.endswith("/saved-settings-quick.json") for name in quick_members),
            "The identity-bound raw Settings Quick must be retained in the broad archive")
    for key, filename in (("original_write_read_seal", "write-read-seal.json"),
                          ("settings_write_seal", "settings-write-seal.json")):
        ident = summary["settings_quick_save"][key]["identity"]
        members = broad_members.get((ident["bytes"], ident["sha256"]), [])
        require(any(name.endswith("/" + filename) for name in members),
                "The identity-bound seal must be retained: " + filename)

    for name in SOURCE_REVIEWS:
        add("source-review/" + name, root / name)
    window = read_json(root / "settings-window-source-review/source-review.json")
    expected_window = {"source-review.json", "production.diff"}
    for row in window["godot"]["sources"]:
        name = row["exact_copy"]
        safe_relative(name)
        path = root / "settings-window-source-review" / name
        raw = path.read_bytes()
        blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
        require(row["api_blob_identity_verified"] is True
                and file_identity(path) == {k: row["exact_identity"][k] for k in ("bytes", "sha256")}
                and blob == row["exact_identity"]["git_blob"] == row["upstream_git_blob"], "Upstream source copy is unverified")
        expected_window.add(name)
    actual_window = {path.relative_to(root / "settings-window-source-review").as_posix()
                     for path in (root / "settings-window-source-review").rglob("*") if path.is_file()}
    require(actual_window == expected_window and len(window["godot"]["sources"]) == 6,
            "Unexpected source-review folder files")
    require(file_identity(root / "settings-window-source-review/production.diff") ==
            {k: window["production_diff"][k] for k in ("bytes", "sha256")}, "Source-review diff changed")
    for name in sorted(expected_window):
        add("source-review/settings-window-source-review/" + name, root / "settings-window-source-review" / name)
    final_review = read_json(root / "settings_f5_final_source/final-source-review.json")
    require(final_review["source"] == SOURCE and final_review["source_only_review"] is True,
            "Final source-only review binding differs")
    for key in ("supported_formats_changed", "save_or_profile_owner_changed", "production_catalogue_changed"):
        require(final_review[key] is False, "Review reports broader changes: " + key)
    require(final_review["test_identities_added"] == 6 and final_review["old_test_identities_removed"] == 0,
            "Source case identity review differs")
    for row in final_review["changed_files"]:
        raw = guard.git(repo, "show", SOURCE + ":" + row["path"])
        require(identity(raw) == {k: row[k] for k in ("bytes", "sha256")}, "Final reviewed source bytes differ")
    for number in (1, 2, 3):
        review = read_json(root / f"settings-focus{number}-public-inventory-review.json")
        require(review["audit_pass"] is True and review["run_id"] == FOCUSED[f"focus{number}"][0], "Inventory review binding differs")
    latest = read_json(root / "settings-focus3-public-inventory-review.json")
    for owner in ("game_state", "save_manager"):
        raw = guard.git(repo, "show", SOURCE + f":evidence/phase_2r/runtime/{owner}_surface.json")
        require(identity(raw) == latest["inventories"][owner]["focus3_generated"], "Final source inventories are not the reviewed generated bytes")
    # Small immutable freeze metadata only; explicitly omit source trees/indexes,
    # massive merge-tree JSON and the redundant full-tree import receipt.
    for folder in ("settings_f5_candidate_1", "settings_f5_candidate_2", "settings_f5_final_source"):
        for name in ("manifest.json", "commit.json", "published-blobs.json"):
            path = root / folder / name
            if path.is_file():
                require(path.stat().st_size < 100000, "Unexpectedly large freeze metadata")
                add("source-review/" + folder + "/" + name, path)

    helper_names = list(HELPERS)
    for directory in HELPER_DIRS:
        require((root / directory).is_dir(), "Missing reproduction helper directory")
        for path in sorted((root / directory).rglob("*")):
            if path.is_file() and "__pycache__" not in path.parts and path.suffix != ".pyc":
                require(path.suffix in {".py", ".json", ".md"}, "Unexpected helper payload: " + str(path))
                helper_names.append(path.relative_to(root).as_posix())
    helper_names.extend(["prepare_settings_navigation.py", "finalize_settings_evidence.py"])
    reproduction = []
    for name in helper_names:
        path = root / name
        ident = file_identity(path)
        members = broad_members.get((ident["bytes"], ident["sha256"]), [])
        if members:
            retained = {"archive": packages["run128"]["archive"], "member": sorted(members)[0]}
        else:
            retained = {"file": "audit-tools/" + name}
            add(retained["file"], path)
        reproduction.append({"workspace_relative_path": name, **ident, **retained})
    physical_auditor = "evidence/phase_2r/physical_authored_selector_2026_10_02/audit-tools/audit_physical_selector_journey.py"
    reproduction.append({"workspace_relative_path": "audit_physical_selector_journey.py",
                         "repository_file": physical_auditor, "file": "../physical_authored_selector_2026_10_02/audit-tools/audit_physical_selector_journey.py",
                         **file_identity(repo / physical_auditor)})
    add("reproduction-files.json", json_bytes({"schema_version": 1, "files": reproduction,
        "materialization": "Extract bundles and place helper bytes at workspace_relative_path; exact matching helpers already inside Run128 are indexed instead of duplicated.",
        "limits": [LIMITS[9], "Historical validator controls require source-bound Run127 inputs and use original absolute paths; their preservation is provenance, not standalone replay."]}))
    add("beads-record-audit.json", json_bytes(beads_audit))
    readme = f"""# Paused Settings F5 — bounded acceptance

Source `{SOURCE}`; tested PR merge `{CHECKOUT}`; [Run128](https://github.com/Siuuuers/dwm/actions/runs/{RUN_ID}).
The exact [acceptance summary](run128/acceptance-summary.json) records 23 successful jobs,
2,286 GUT executions, 2,282 unique cases and 194 scripts, with zero failures/errors/skips.

Fresh admitted F5 in nonmodal paused Settings completes only the current reveal,
saves the underlying canonical point once, and preserves Settings, focus and
suspension. Fresh-process Quick Load restores that point without repeated speech.

The [receipt](receipt.json) owns final acceptance and links immutable packages.
Focus1 and Focus2 remain failed diagnostics; Focus3 is bounded two-job evidence.
Their results are not combined to fabricate a passing candidate. The [final source
review](source-review/settings_f5_final_source/final-source-review.json) remains
source-only and preserves its historical broad-pending field. It is not edited to
pretend that runtime acceptance existed when that review occurred.

## Retained proof and limits

""" + "\n".join("- " + value for value in LIMITS) + """

## Reproduction and provenance

Each package's manifest binds its archive members and explicit exclusions. Logs
are kept in those archives rather than copied again. The [reproduction index](reproduction-files.json)
locates each helper either as a relative file or an exact member of the broad
archive. Source reviews remain byte-preserved: their original scratch references
are historical provenance; use the retained relative copies and archive manifests.
The six `settings-window-source-review/upstream` copies are verified against their
recorded Git blob, byte length and SHA-256 identities. No unverified extra source,
generated Python cache, full obsolete source tree or huge merge-tree export is copied.

[Beads audit](beads-record-audit.json): only `dwm-vky.14` notes/updated_at change;
the other 190 records are byte-identical, with 191 total and 23 unfinished.
All statuses/dependencies are unchanged. No live Dolt synchronization is claimed.
Navigation updates remain the separate `prepare_settings_navigation.py` step.
PR #1 remains draft and unmerged; review/publication belong to the integrator.
"""
    add("README.md", readme.encode())
    retained = []
    for name, source in plan.items():
        retained.append({"file": name, **(file_identity(source) if isinstance(source, Path) else identity(source))})
    receipt = {"schema_version": 1, "accepted_at": timestamp, "lead_bead": LEAD,
               "accepted_scope": "Bounded paused nonmodal Settings F5 Quick Save and fresh-process semantic restore",
               "source": SOURCE, "tested_checkout": CHECKOUT, "baseline": BASELINE,
               "broad_run": {"number": RUN_NUMBER, "id": RUN_ID, "url": summary["run_url"], "jobs": 23,
                             **guard.EXPECTED_COUNTS, "acceptance_summary": "run128/acceptance-summary.json"},
               "overall_accepted": True, "acceptance_summary_identity": identity(summary_raw),
               "source_review_scope": "Historical source-only review retains broad-pending-at-review; this receipt records actual later acceptance.",
               "final_source_review": "source-review/settings_f5_final_source/final-source-review.json",
               "packages": packages, "supported_format_changes": False, "public_port_signature_changes": False,
               "save_or_profile_owner_changes": False, "production_catalogue_registered": False,
               "original_reading": {"processes": 8, "seal_files": 14},
               "supplemental_settings": {"processes": 2, "seal_files": 3,
                   "raw_quick_archived": True, "raw_profile_autosave_archived": False,
                   "neutrality_evidence": "Hash-and-size receipts and writer FileOps observations"},
               "physical_selector_proof_retained": True, "visible_title_geometry_observations": 480,
               "settings_f9": "unavailable; separate pending guarded-Load acceptance",
               "beads_audit": "beads-record-audit.json", "reproduction_index": "reproduction-files.json",
               "limits": LIMITS, "retained_files_excluding_this_receipt": retained}
    add("receipt.json", json_bytes(receipt))
    print(json.dumps({"mode": "apply" if args.apply else "dry-run", "source": SOURCE, "checkout": CHECKOUT,
                      "run_id": RUN_ID, "files": len(plan), "total_bytes": sum(row["bytes"] for row in retained),
                      "output": DESTINATION, "beads": beads_audit}, indent=2))
    if not args.apply:
        print("Validated dry-run only; no files written.")
        return
    require(summary_path.read_bytes() == summary_raw, "Summary changed during preparation")
    guard.validate_source(repo, SOURCE)
    require((repo / ".beads/issues.jsonl").read_bytes() == before, "Beads changed during preparation")
    for name, ident in input_identities.items():
        require(file_identity(Path(name)) == ident, "Input changed during preparation: " + name)
    stage = Path(tempfile.mkdtemp(prefix="settings-records-stage-", dir=root))
    beads_temp = None
    installed = False
    try:
        for name, source in plan.items():
            path = stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(source, Path):
                shutil.copyfile(source, path)
            else:
                path.write_bytes(source)
        for row in retained:
            require(file_identity(stage / row["file"]) == {k: row[k] for k in ("bytes", "sha256")}, "Staged copy mismatch")
        require(not destination.exists(), "Destination appeared during staging")
        require((repo / ".beads/issues.jsonl").read_bytes() == before, "Beads changed during staging")
        fd, name = tempfile.mkstemp(prefix="settings-beads-", dir=repo / ".beads")
        beads_temp = Path(name)
        with os.fdopen(fd, "wb") as stream:
            stream.write(after)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(beads_temp, (repo / ".beads/issues.jsonl").stat().st_mode & 0o777)
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.replace(stage, destination)
        installed = True
        os.replace(beads_temp, repo / ".beads/issues.jsonl")
        beads_temp = None
    except Exception:
        if installed and (repo / ".beads/issues.jsonl").read_bytes() == before:
            shutil.rmtree(destination)
        raise
    finally:
        if stage.exists():
            shutil.rmtree(stage)
        if beads_temp is not None and beads_temp.exists():
            beads_temp.unlink()
    # Task-local draft only: publication remains an explicit integrator action.
    pr_body = f"""Paused Settings F5 now saves the current canonical reading point through the existing Quick owner. It completes only the current reveal, preserves Settings/focus/suspension, and requires fresh input after modal or preference custody.

Run128 ({summary['run_url']}) accepts source `{SOURCE}` at tested merge `{CHECKOUT}`: 23/23 jobs, 2,286 GUT executions / 2,282 unique cases / 194 scripts, zero failures/errors/skips. The supplemental writer/reader preserves exact semantic state and silent restore; existing v1/v2 and title-geometry proofs retain their prior bounds.

Evidence: `{DESTINATION}/receipt.json`. Raw Quick is archived; Profile/Autosave neutrality uses hash-and-size receipts and FileOps observations. Formats/public port signatures and production catalogue admission are unchanged. Settings F9, native/accessibility and whole-game acceptance remain separate. All 23 unfinished Beads remain; only the lead evidence note/timestamp changed. This PR remains draft and unmerged.
"""
    (root / "settings-f5-pr-body-draft.md").write_text(pr_body, encoding="utf-8")
    print("Evidence and lead note materialized; navigation, publication and merge remain untouched.")


if __name__ == "__main__":
    try:
        main()
    except (guard.Refusal, KeyError, TypeError, ValueError, OSError, tarfile.TarError) as error:
        print("REFUSED: " + str(error), file=sys.stderr)
        raise SystemExit(2)
