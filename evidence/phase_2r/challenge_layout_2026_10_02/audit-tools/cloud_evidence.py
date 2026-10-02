#!/usr/bin/env python3
"""Audit/package downloaded GitHub evidence. Never runs engines or PowerShell.

The audit is deliberately bounded: passing jobs, source/log bindings, strict XML,
original ZIP/extracted-byte identity and retained reading receipts. Independent
non-GUT semantics must still be reviewed before making whole-product claims.
"""
from __future__ import annotations

import argparse
from collections import Counter
import fnmatch
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import subprocess
import tarfile
import xml.etree.ElementTree as ET
import zipfile

SECRET_PATTERNS = {
    "github_token": rb"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b",
    "signed_query": rb"https?://[^\s\"<>]*[?&](?:sig|signature|token|access_token|X-Amz-Signature|X-Amz-Credential|AWSAccessKeyId|se)=",
    "authorization_secret": rb"Authorization[\"\s:]+(?:Bearer|Basic)\s+(?!\*{3}|REDACTED)[A-Za-z0-9._~+/=-]{12,}",
    "private_key": rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
}
BINARY_SUFFIXES = {".exe", ".pck", ".dll", ".so", ".dylib", ".bin", ".wasm", ".zip", ".7z", ".gz"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, f"DUPLICATE_JSON_KEY: {key}")
            result[key] = value
        return result
    def constant(value):
        raise ValueError(f"NONFINITE_JSON_NUMBER: {value}")
    return json.loads(raw, object_pairs_hook=pairs, parse_constant=constant)


def read(path):
    return strict_json(path.read_text(encoding="utf-8-sig"))


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def identity(path):
    return {"bytes": path.stat().st_size, "sha256": sha(path)}


def scan(raw, path):
    for label, pattern in SECRET_PATTERNS.items():
        require(re.search(pattern, raw, re.I) is None, f"SECRET_OR_SIGNED_URL_REFUSED: {path}: {label}")


def clean(line):
    line = re.sub(r"\x1b\[[0-9;]*m", "", line)
    return re.sub(r"^\ufeff?\d{4}-\d\d-\d\dT\S+\s", "", line).strip()


def exclusion(path, artifact):
    if path.name in ("game_state_surface.json", "save_manager_surface.json"):
        return "Duplicate public inventory; retain canonical source-bound copies separately."
    if path.suffix.lower() == ".png" and not artifact.startswith(("reading-rail-", "solo-authored-selector-")):
        return "Non-reading PNG omitted; verified original ZIP member, byte length and SHA-256 retained."
    if path.suffix.lower() in BINARY_SUFFIXES:
        return "Binary payload excluded; cloud build/startup receipts remain in logs and API metadata."
    if artifact.startswith("cloud-speech-") and path.name in ("speech-dispatcher.log", "voices.txt"):
        return "Large native speech diagnostic omitted; job/capability receipts retain their bounded scope."
    return None


def artifact_inventory(root, attachments, omissions):
    """Verify *all* extracted bytes, including omitted payloads, against originals."""
    run = read(root / "run.json")
    api = read(root / "artifacts-api.json")
    records = api["artifacts"]
    require(api.get("total_count", len(records)) <= len(records), "ARTIFACT_API_PAGINATION_INCOMPLETE")
    require(len({a["name"] for a in records}) == len(records), "DUPLICATE_ARTIFACT_NAME")
    zip_by_hash = {}
    for directory in attachments:
        for path in directory.rglob("*.zip"):
            zip_by_hash.setdefault(sha(path), path)
    known = {a["name"] for a in records}
    artifact_root = root / "artifacts"
    require(not records or artifact_root.is_dir(), "ARTIFACT_DIRECTORY_REQUIRED")
    require(not artifact_root.exists() or all(p.is_dir() and not p.is_symlink() and p.name in known for p in artifact_root.iterdir()),
            "UNKNOWN_FILE_OR_ARTIFACT_DIRECTORY")
    artifacts, files, omitted = [], [], []
    for record in sorted(records, key=lambda a: a["name"]):
        name = record["name"]
        require(PurePosixPath(name).name == name and "\\" not in name, "UNSAFE_ARTIFACT_NAME")
        folder = artifact_root / name
        require(record["workflow_run"]["id"] == run["id"], f"ARTIFACT_RUN_MISMATCH: {name}")
        require(record["workflow_run"]["head_sha"] == run["head_sha"], f"ARTIFACT_WORKFLOW_HEAD_MISMATCH: {name}")
        provenance = {key: record.get(key) for key in ("id", "name", "digest", "size_in_bytes", "created_at")}
        provenance["workflow_run_head_sha"] = record["workflow_run"]["head_sha"]
        if not folder.exists():
            reason = omissions.get(name, omissions.get(str(record["id"])))
            require(isinstance(reason, str) and bool(reason.strip()), f"EXPLICIT_OMISSION_REASON_REQUIRED: {name}")
            omitted.append(provenance | {"reason": reason, "downloaded": False})
            continue
        digest = record.get("digest", "")
        require(re.fullmatch(r"sha256:[0-9a-f]{64}", digest), f"API_SHA256_REQUIRED: {name}")
        original = zip_by_hash.get(digest[7:])
        require(original is not None and original.stat().st_size == record["size_in_bytes"], f"ORIGINAL_ZIP_HASH_SIZE_MISMATCH: {name}")
        provenance.update({"zip_sha256": digest[7:], "local_zip_basename": original.name})
        with zipfile.ZipFile(original) as archive:
            members = [i for i in archive.infolist() if not i.is_dir()]
            require(len({i.filename for i in members}) == len(members), f"DUPLICATE_ZIP_MEMBER: {name}")
            for item in members:
                p = PurePosixPath(item.filename)
                require(not p.is_absolute() and ".." not in p.parts and "\\" not in item.filename
                        and not stat.S_ISLNK(item.external_attr >> 16), f"UNSAFE_ZIP_MEMBER: {name}/{item.filename}")
            local = [p for p in folder.rglob("*") if p.is_file()]
            require(not any(p.is_symlink() for p in folder.rglob("*")), f"EXTRACTED_SYMLINK_REFUSED: {name}")
            require({p.relative_to(folder).as_posix() for p in local} == {i.filename for i in members},
                    f"EXTRACTED_MEMBER_SET_MISMATCH: {name}")
            for path in sorted(local):
                member = path.relative_to(folder).as_posix()
                with archive.open(member) as stream:
                    original_digest = hashlib.file_digest(stream, "sha256").hexdigest()
                ident = identity(path)
                require(ident == {"bytes": archive.getinfo(member).file_size, "sha256": original_digest},
                        f"EXTRACTED_MEMBER_BYTES_MISMATCH: {name}/{member}")
                files.append({"path": path.relative_to(root).as_posix(), **ident,
                    "provenance": {"artifact_id": record["id"], "zip_sha256": digest[7:], "zip_member": member,
                                   "extraction_verified_byte_for_byte": True},
                    "exclusion_reason": exclusion(path, name)})
        artifacts.append(provenance | {"extracted_file_count": len(members), "zip_and_extraction_verified": True})
    return {"artifacts": artifacts, "files": files, "not_downloaded_artifacts": omitted}


def source_boundary(args):
    def git(*argv):
        return subprocess.check_output(["git", "-C", str(args.repo), *argv])
    source, checkout = args.source, args.checkout
    for revision in (source, checkout):
        require(re.fullmatch(r"[0-9a-f]{40}", revision), "EXACT_40_CHARACTER_SOURCE_SHA_REQUIRED")
        require(git("rev-parse", revision + "^{commit}").decode().strip() == revision, "GIT_COMMIT_MISMATCH")
    # Read the verified commit object's ordered parent headers directly. Source
    # caches need not materialize unrelated ancestor trees to inspect provenance.
    headers = git("cat-file", "commit", checkout).split(b"\n\n", 1)[0].splitlines()
    parents = [line[len(b"parent "):].decode() for line in headers if line.startswith(b"parent ")]
    require(all(re.fullmatch(r"[0-9a-f]{40}", parent) for parent in parents), "EXACT_PARENT_SHA_REQUIRED")
    if args.master:
        require(parents == [args.master, source], "TESTED_MERGE_PARENTS_MISMATCH")
    differences = []
    pieces = git("diff", "--raw", "--no-abbrev", "--no-renames", "-z", source, checkout).split(b"\0")
    for index in range(0, len(pieces) - 1, 2):
        header = pieces[index].decode().split()
        path = pieces[index + 1].decode()
        allowed = any(fnmatch.fnmatchcase(path, pattern) for pattern in args.allow_source_diff)
        require(allowed, f"UNAPPROVED_SOURCE_CHECKOUT_DIFFERENCE: {path}")
        differences.append({"path": path, "old_mode": header[0][1:], "new_mode": header[1],
                            "source_blob": header[2], "checkout_blob": header[3], "status": header[4]})
    return {"source": source, "tested_checkout": checkout, "master": args.master,
            "checkout_parents": parents, "source_checkout_differences": differences,
            "explicit_allowed_difference_patterns": args.allow_source_diff,
            "all_unlisted_paths_byte_identical": True}


def job_audit(root, checkout, expected, no_checkout, *, require_success=True):
    api = read(root / "jobs.json")
    records = api["jobs"]
    require(api.get("total_count", len(records)) <= len(records), "JOBS_API_PAGINATION_INCOMPLETE")
    latest = {}
    for job in records:
        if "${{" in job["name"] and job.get("conclusion") == "skipped":
            continue
        old = latest.get(job["name"])
        if old is None or (job.get("run_attempt", 1), job["id"]) > (old.get("run_attempt", 1), old["id"]):
            latest[job["name"]] = job
    require(len(latest) == expected, f"EXPECTED_{expected}_JOBS_OBSERVED_{len(latest)}")
    require(set(no_checkout) <= set(latest), "UNKNOWN_NO_CHECKOUT_JOB")
    result = []
    for job in sorted(latest.values(), key=lambda j: j["id"]):
        require(job["status"] == "completed", f"JOB_NOT_COMPLETED: {job['name']}")
        if require_success:
            require(job["conclusion"] == "success", f"JOB_NOT_SUCCESS: {job['name']}")
        aliases = [j for j in records if all(j.get(k) == job.get(k) for k in
            ("name", "status", "conclusion", "started_at", "completed_at", "runner_id", "steps"))]
        execution = min(aliases, key=lambda j: (j.get("run_attempt", 1), j["id"]))
        path = root / "logs" / f"{execution['id']}.log"
        require(path.is_file(), f"JOB_LOG_REQUIRED: {execution['id']}")
        lines = [clean(line) for line in path.read_text(encoding="utf-8-sig").splitlines()]
        checkouts = [lines[i + 1] for i, line in enumerate(lines[:-1])
                     if "log -1 --format=%H" in line and re.fullmatch(r"[0-9a-f]{40}", lines[i + 1])]
        if job["name"] in no_checkout:
            require(not checkouts, f"EXPECTED_CHECKOUT_FREE_AGGREGATE: {job['name']}")
        else:
            require(bool(checkouts) and all(value == checkout for value in checkouts), f"JOB_CHECKOUT_MISMATCH: {job['name']}: {checkouts}")
        result.append({key: job.get(key) for key in ("id", "name", "run_attempt", "status", "conclusion", "started_at", "completed_at")} |
            {"execution_job_id": execution["id"], "execution_attempt": execution.get("run_attempt", 1),
             "log": path.relative_to(root).as_posix(), "log_identity": identity(path), "checkout_shas": checkouts,
             "checkout_exemption": "explicit checkout-free aggregate" if job["name"] in no_checkout else None})
    return result


def xml_audit(root, run_id, expected):
    selected, negatives = {}, []
    for path in sorted((root / "artifacts").rglob("*.xml")):
        relative = path.relative_to(root / "artifacts")
        if "storage-refusal" in relative.parts:
            negatives.append({"path": path.relative_to(root).as_posix(), **identity(path),
                              "reason": "Expected negative storage-root refusal probe; excluded from ordinary GUT totals."})
            continue
        match = re.fullmatch(r"(.+)-" + str(run_id) + r"-(\d+)", relative.parts[0])
        family = (match.group(1), *relative.parts[1:]) if match else relative.parts
        attempt = int(match.group(2)) if match else 1
        if family not in selected or attempt > selected[family][0]:
            selected[family] = (attempt, path)
    require(len(selected) == expected, f"EXPECTED_{expected}_XML_OBSERVED_{len(selected)}")
    cases, scripts, results = set(), set(), []
    for attempt, path in sorted(selected.values(), key=lambda x: str(x[1])):
        tree = ET.parse(path).getroot()
        suites = list(tree.iter("testsuite"))
        nodes = list(tree.iter("testcase"))
        require(bool(nodes), f"EMPTY_GUT_XML: {path}")
        for node in tree.iter():
            for label in ("failures", "errors", "skipped", "disabled"):
                require(int(node.get(label, "0")) == 0, f"DECLARED_GUT_{label.upper()}: {path}")
            require(node.tag not in ("failure", "error", "skipped"), f"GUT_FAILURE_ERROR_OR_SKIP: {path}")
        for case in nodes:
            require(case.get("status", "pass") in ("pass", "passed", "run"), f"NONPASS_GUT_CASE: {path}: {case.attrib}")
        for suite in suites:
            scripts.add(suite.get("name"))
            for case in suite.findall("./testcase"):
                cases.add((suite.get("name"), case.get("name")))
        if tree.get("tests") is not None:
            require(int(tree.get("tests")) == len(nodes), f"DECLARED_GUT_CASE_COUNT_MISMATCH: {path}")
        results.append({"path": path.relative_to(root).as_posix(), "run_attempt": attempt,
                        "cases": len(nodes), "scripts": len(suites), **identity(path)})
    return {"xml_count": len(results), "case_executions": sum(x["cases"] for x in results),
            "unique_cases": len(cases), "script_executions": sum(x["scripts"] for x in results),
            "unique_scripts": len(scripts), "failures": 0, "errors": 0, "skipped": 0,
            "unique_identity": "testsuite.name + testcase.name", "suites": results,
            "negative_xml_exclusions": negatives}


def reading_audit(root, checkout, modes):
    results = []
    for path in sorted((root / "artifacts").glob("reading-rail-*/result.json")):
        report = read(path)
        require(report.get("ok") is True and report.get("failures") == [], "READING_JOURNEY_NOT_PASSING")
        require(report["checkout_sha"] == checkout, "READING_CHECKOUT_MISMATCH")
        folder = path.parent / PurePosixPath(report["artifact_root"]).name
        require(read(folder / "result.json") == report, "READING_TOP_AND_RAW_REPORT_MISMATCH")
        observed = report["reports"]
        require(set(modes) == set(observed), f"READING_MODE_SET_MISMATCH: {list(observed)}")
        pids = [r["process_id"] for r in observed.values()]
        require(all(type(pid) is int and pid > 0 for pid in pids) and len(set(pids)) == len(pids), "FRESH_READING_PROCESS_IDS_REQUIRED")
        for mode, value in observed.items():
            require(value["mode"] == mode and PurePosixPath(value["user_dir"]) == PurePosixPath(report["user_dir"])
                    and read(folder / f"{mode}.json") == value, f"RAW_READING_REPORT_MISMATCH: {mode}")
        for mode, process in report["processes"].items():
            require(process["exit_code"] == 0 and process["timed_out"] is False, f"READING_PROCESS_FAILED: {mode}")
            require(read(folder / f"{mode}.process.json") == process, f"RAW_PROCESS_REPORT_MISMATCH: {mode}")
            for name in (f"{mode}.log", PurePosixPath(process["stdout"]).name, PurePosixPath(process["stderr"]).name):
                text = (folder / name).read_text(encoding="utf-8-sig")
                require(re.search(r"SCRIPT ERROR:|(?:^|\s)ERROR:|Unicode parsing error|Unexpected NUL character|Parse Error:|READING_RAIL_FAIL:|Resource still in use:|Leaked instance:|Orphan StringName:", text, re.M) is None,
                        f"READING_ENGINE_OR_LIFETIME_ERROR: {name}")
            if mode != "user-dir-proof":
                stdout = (folder / PurePosixPath(process["stdout"]).name).read_text(encoding="utf-8-sig")
                marker = "READING_RAIL_" + mode.upper().replace("-", "_") + "_PASS:"
                require(len(re.findall(r"^" + re.escape(marker), stdout, re.M)) == 1, f"READING_PASS_MARKER_COUNT: {mode}")
        require(set(report["processes"]) == set(modes) | {"user-dir-proof"}, "READING_PROCESS_SET_MISMATCH")
        written, restored = observed["write"], observed["read"]
        for field in ("canonical_transcript", "current_line_id", "physical_record", "quick_sha256", "quick_bytes"):
            require(written[field] == restored[field], f"READING_FRESH_RESTORE_MISMATCH: {field}")
        require(restored["speech_admissions"] == 0 and written["speech_admissions"] > 0, "READING_RESTORE_SPEECH_DUPLICATION")
        quick = identity(folder / "saved-quick.json")
        require(quick == report["retained_quick"] == {"bytes": written["quick_bytes"], "sha256": written["quick_sha256"]}, "RETAINED_QUICK_MISMATCH")
        pause = written["ordinary_pause_save"]
        pause_identity = identity(folder / "saved-pause-slot.json")
        require(pause_identity == {k: report["retained_pause_slot"][k] for k in ("bytes", "sha256")}
                == {"bytes": pause["slot_bytes"], "sha256": pause["slot_sha256"]}, "RETAINED_PAUSE_SLOT_MISMATCH")
        trace = [strict_json(line) for line in (folder / "transactions.jsonl").read_text().splitlines()]
        require(set(e["mode"] for e in trace) == set(modes), "READING_TRACE_MODE_SET_MISMATCH")
        for mode in modes:
            entries = [e for e in trace if e["mode"] == mode]
            require([e["sequence"] for e in entries] == list(range(1, len(entries) + 1))
                    and all(e["process_id"] == observed[mode]["process_id"] for e in entries), f"READING_TRACE_IDENTITY_MISMATCH: {mode}")
        captures = []
        for capture in report["captures"]:
            image = folder / "captures" / PurePosixPath(capture["file"]).name
            raw = image.read_bytes()
            require(raw.startswith(b"\x89PNG\r\n\x1a\n") and raw[12:16] == b"IHDR", "READING_PNG_REQUIRED")
            width, height = struct.unpack(">II", raw[16:24])
            require(identity(image) == {key: capture[key] for key in ("bytes", "sha256")}
                    and (width, height) == (capture["width"], capture["height"]), "READING_CAPTURE_IDENTITY_MISMATCH")
            captures.append({"path": image.relative_to(root).as_posix(), **identity(image), "width": width, "height": height})
        seal_path = folder / "write-read-seal.json"
        seal_summary = None
        if seal_path.exists():
            seal = read(seal_path)
            sealed = folder / PurePosixPath(seal["root"]).name
            for name, ident in seal["files"].items():
                require(PurePosixPath(name).name == name, "UNSAFE_SEAL_FILENAME")
                require(identity(sealed / name) == ident, f"READING_SEAL_BYTES_MISMATCH: {name}")
                retained = folder / ("captures/" + name if name.endswith(".png") else name)
                if name == "transactions.jsonl":
                    require(retained.read_bytes().startswith((sealed / name).read_bytes()), "READING_SEAL_TRACE_PREFIX_MISMATCH")
                else:
                    require(identity(retained) == ident, f"READING_SEAL_RETAINED_BYTES_MISMATCH: {name}")
            seal_summary = {"file_count": len(seal["files"]), "identity": identity(seal_path),
                            "sealed_after_mode": seal["sealed_after_mode"], "before_mode": seal["before_mode"]}
        witness_summary = None
        if set(modes) - {"write", "read"}:
            require(seal_summary is not None and report.get("write_read_seal_verified") is True, "WRITE_READ_SEAL_REQUIRED")
            witness_summary = witness_audit(report, folder)
        results.append({"report": path.relative_to(root).as_posix(), "report_identity": identity(path),
            "modes": list(observed), "process_ids": dict(zip(observed, pids)), "all_process_exits_zero": True,
            "trace_entries": len(trace), "trace_identity": identity(folder / "transactions.jsonl"),
            "quick": quick, "pause_slot": pause_identity, "captures": captures, "write_read_seal": seal_summary,
            "original_capture_file_count": len(captures),
            "original_capture_distinct_sha256_count": len({capture["sha256"] for capture in captures}),
            "exact_witnesses": witness_summary,
            "limits": ["Generic audit binds retained bytes, fresh processes and baseline restore receipts; independently review witness semantics and exact trace kinds.",
                       "Pause slot is retained and hashed; generic audit does not claim it was independently fresh-loaded."]})
    require(bool(results), "READING_JOURNEY_ARTIFACT_REQUIRED")
    return results


def witness_audit(result, folder):
    """Independently join finite exact-witness claims to the physical Profile."""
    reports = result["reports"]
    repeated, variant, restart = (reports[k] for k in ("repeat", "variant", "witness-read"))
    ledger = reports["write"]["saved_checkpoint"]["reading_session"]["ledger"]
    original = ledger["captions"][0]["beat"]
    original_session = ledger["frozen_context"]["completion_transaction_id"]
    require(len({original_session, repeated["current_session_id"], variant["current_session_id"]}) == 3,
            "WITNESS_CAUSAL_SESSIONS_NOT_DISTINCT")
    for item in (repeated, variant):
        require(item["prior_session_id"] == original_session and item["current_session_id"]
                and item["first_line_id"] == original["line_id"] == item["beat"]["line_id"]
                and item["seen_after"] is True and item["skip_result"]["ok"] is True, "WITNESS_PUBLICATION_IDENTITY_MISMATCH")
        require(all(item["witnesses_after"].get(k) == v for k, v in item["witnesses_before"].items()), "WITNESS_PRIOR_CREDIT_LOST")
    require(repeated["beat"] == original and repeated["seen_before"] is True
            and repeated["acknowledgement_receipt"]["was_visited_before_presentation"] is True
            and repeated["skip_result"]["value"]["advance"] is True
            and repeated["resulting_line_id"] != repeated["first_line_id"]
            and repeated["witnesses_before"] == repeated["witnesses_after"]
            and original in repeated["witnesses_before"].values(), "EXACT_REPEAT_DID_NOT_KEEP_PRIOR_CREDIT")
    changed = variant["beat"]
    expected = strict_json(json.dumps(original))
    expected["presentation_signature"]["content_revision"] = changed["presentation_signature"]["content_revision"]
    require(changed == expected and changed != original, "VARIANT_MUST_CHANGE_ONLY_CONTENT_REVISION")
    added = {k: v for k, v in variant["witnesses_after"].items() if k not in variant["witnesses_before"]}
    require(variant["witnesses_before"] == repeated["witnesses_after"] and list(added.values()) == [changed]
            and changed not in variant["witnesses_before"].values() and variant["seen_before"] is False
            and variant["acknowledgement_receipt"]["was_visited_before_presentation"] is False
            and variant["skip_result"]["value"]["advance"] is False
            and variant["resulting_line_id"] == variant["first_line_id"], "NEW_REVISION_SKIP_BASELINE_NOT_UNSEEN")
    failure = variant["write_failure"]
    require(variant["write_faults"] == 1 and failure["ok"] is False and failure["code"]
            and failure.get("fatal", False) is False
            and variant["failed_profile_sha256"] == variant["profile_before_sha256"] != variant["profile_after_sha256"]
            and variant["neutrality_before_retry"] is True and variant["history_after_retry_neutral"] is True,
            "RECOVERABLE_WRITE_FAILURE_OR_RETRY_NEUTRALITY_MISSING")
    physical = folder / "witness-profile.json"
    ident = identity(physical)
    require(ident == {"bytes": variant["profile_bytes"], "sha256": variant["profile_sha256"]}
            == {k: result["retained_witness_profile"][k] for k in ("bytes", "sha256")}
            and ident["sha256"] == variant["profile_after_sha256"]
            and read(physical)["witnessed_caption_variants"] == variant["witnesses_after"], "PHYSICAL_WITNESS_PROFILE_MISMATCH")
    require(restart["beat"] == changed and restart["witnessed"] is True and restart["profile_unchanged"] is True
            and restart["witnesses"] == variant["witnesses_after"]
            and ident == {"bytes": restart["profile_bytes"], "sha256": restart["profile_sha256"]}, "FRESH_PROCESS_WITNESS_MISMATCH")
    return {"profile": ident, "durable_witness_count": len(variant["witnesses_after"]),
            "same_stable_line_new_revision_unseen": True, "exact_repeat_seen": True,
            "recoverable_write_failures": 1, "fresh_process_physical_profile_match": True}


def audit(args):
    root = args.run_root.resolve()
    run = read(root / "run.json")
    require(run["status"] == "completed" and run["conclusion"] == "success", "COMPLETED_SUCCESSFUL_RUN_REQUIRED")
    inventory = artifact_inventory(root, args.attachments, read(args.omissions) if args.omissions else {})
    result = {"schema_version": 1, "audit_scope": __doc__.strip(), "generic_audit_pass": True,
        "raw_metadata_identities": {name: identity(root / name) for name in ("run.json", "jobs.json", "artifacts-api.json")},
        "run": {k: run.get(k) for k in ("id", "run_number", "run_attempt", "head_sha", "head_branch", "event", "html_url", "status", "conclusion")},
        "source_boundary": source_boundary(args),
        "jobs": job_audit(root, args.checkout, args.expected_jobs, args.no_checkout_job),
        "gut": xml_audit(root, run["id"], args.expected_xml),
        "reading": reading_audit(root, args.checkout, args.reading_modes.split(",")),
        "artifact_inventory": inventory,
        "limits": ["Workflow head is recorded separately from the immutable subject checkout; focused helper workflows can differ.",
                   "This bounded audit does not replace independent render, storage-fault, performance, export or witness-semantic review.",
                   "No Godot, PowerShell, physical-crash injection or local native-window acceptance occurs here."]}
    raw = encoded(result)
    scan(raw, "generic-evidence-audit.json")
    output = args.output or root / "audit/generic-evidence-audit.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(raw)
    print(json.dumps({"output": str(output), "generic_audit_pass": True, "jobs": len(result["jobs"]), "gut": {k: result["gut"][k] for k in ("xml_count", "case_executions", "unique_cases", "unique_scripts")}, "artifact_files": len(inventory["files"])}))


def diagnostic_package(args):
    """Preserve a completed failed run, explicitly without test acceptance."""
    root = args.run_root.resolve()
    run = read(root / "run.json")
    require(run["status"] == "completed" and run["conclusion"] != "success", "COMPLETED_NONSUCCESSFUL_RUN_REQUIRED")
    require(run["head_sha"] == args.workflow_head, "DIAGNOSTIC_WORKFLOW_HEAD_MISMATCH")
    inventory = artifact_inventory(root, args.attachments, read(args.omissions) if args.omissions else {})
    jobs = job_audit(root, args.checkout, args.expected_jobs, args.no_checkout_job, require_success=False)
    reviewed = {"schema_version": 1, "diagnostic_only": True, "acceptance": False, "generic_audit_pass": False,
        "audit_scope": "Preserve completed failed-run metadata, job/source bindings and verified artifact bytes. Individual component outcomes may be retained in separately scoped audits; no full-gate acceptance is inferred.",
        "reported_diagnosis": args.diagnosis,
        "reported_diagnosis_scope": "Investigator explanation, retained separately from automated provenance verification.",
        "raw_metadata_identities": {name: identity(root / name) for name in ("run.json", "jobs.json", "artifacts-api.json")},
        "run": {k: run.get(k) for k in ("id", "run_number", "run_attempt", "head_sha", "head_branch", "event", "html_url", "status", "conclusion")},
        "source_boundary": source_boundary(args), "jobs": jobs,
        "job_conclusions": dict(Counter(job["conclusion"] for job in jobs)), "artifact_inventory": inventory,
        "limits": ["DIAGNOSTIC/PARTIAL ONLY: this failed run does not establish full-gate acceptance. Independently audited passing components retain only their stated scope.",
                   "No XML results are required or manufactured by this packaging mode; all existing raw results retain their actual outcomes.",
                   "Workflow head and pinned attempted source/checkout are recorded separately; checkout success does not imply the engine loaded the project.",
                   "Artifact bytes and raw logs are preserved without executing Godot or PowerShell locally."]}
    report_path = root / "audit/diagnostic-evidence.json"
    raw = encoded(reviewed)
    scan(raw, report_path.name)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_bytes(raw)
    package(args, reviewed=reviewed, audit_path=report_path)


def package(args, *, reviewed=None, audit_path=None):
    root, output = args.run_root.resolve(), args.output.resolve()
    diagnostic = args.command == "diagnostic-package"
    if reviewed is None:
        audit_path = args.audit or root / "audit/generic-evidence-audit.json"
        reviewed = read(audit_path)
    if diagnostic:
        require(reviewed.get("diagnostic_only") is True and reviewed.get("acceptance") is False
                and reviewed.get("generic_audit_pass") is False, "EXPLICIT_FAILED_RUN_DIAGNOSTIC_REQUIRED")
    else:
        require(reviewed.get("generic_audit_pass") is True, "PASSING_GENERIC_AUDIT_REQUIRED")
    require(read(root / "run.json")["id"] == reviewed["run"]["id"], "AUDIT_RUN_MISMATCH")
    require(all(identity(root / name) == ident for name, ident in reviewed["raw_metadata_identities"].items()), "RAW_METADATA_CHANGED_AFTER_AUDIT")
    require(all(identity(root / job["log"]) == job["log_identity"] for job in reviewed["jobs"]), "RAW_JOB_LOG_CHANGED_AFTER_AUDIT")
    inventory = artifact_inventory(root, args.attachments, read(args.omissions) if args.omissions else {})
    require(inventory == reviewed["artifact_inventory"], "ARTIFACT_BYTES_CHANGED_AFTER_AUDIT")
    selected, receipts, exclusions = {}, [], []
    prefix = root.name
    for item in inventory["files"]:
        path = root / item["path"]
        receipt = {k: v for k, v in item.items() if k != "exclusion_reason"}
        receipt["path"] = f"{prefix}/{item['path']}"
        if item["exclusion_reason"]:
            exclusions.append(receipt | {"reason": item["exclusion_reason"]})
        else:
            selected[receipt["path"]] = path
            receipts.append(receipt)
    standalone = [root / name for name in ("run.json", "jobs.json", "artifacts-api.json")]
    standalone.extend(sorted((root / "logs").glob("*.log")))
    standalone.extend(p for p in sorted((root / "audit").rglob("*")) if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc")
    standalone.extend(root / name for name in ("summary.json", "acceptance-summary.json", "artifact-exclusions.json", "infrastructure-attempts.json") if (root / name).exists())
    if audit_path not in standalone:
        require(audit_path.is_relative_to(root), "AUDIT_FILE_MUST_BE_UNDER_RUN_ROOT_FOR_PACKAGING")
        standalone.append(audit_path)
    for path in standalone:
        require(path.is_file() and not path.is_symlink(), f"RAW_RECEIPT_REQUIRED: {path}")
        name = f"{prefix}/{path.relative_to(root).as_posix()}"
        require(name not in selected, f"DUPLICATE_ARCHIVE_PATH: {name}")
        selected[name] = path
        receipts.append({"path": name, **identity(path), "provenance": {"source": "downloaded raw API/job log or independent local audit; see path"}})
    for name, path in selected.items():
        if path.suffix.lower() != ".png":
            raw = path.read_bytes()
            scan(raw, name)
            try:
                raw.decode("utf-8-sig")
            except UnicodeDecodeError as error:
                raise ValueError(f"UNCLASSIFIED_BINARY_PAYLOAD_REFUSED: {name}") from error
    manifest = {"schema_version": 1, "run": reviewed["run"], "source_boundary": reviewed["source_boundary"],
        "evidence_kind": "failed-run-diagnostic-only" if diagnostic else "bounded-successful-run-audit",
        "generic_audit_pass": reviewed["generic_audit_pass"],
        "bundle": args.name + ".tar.gz", "payload_files": sorted(receipts, key=lambda x: x["path"]),
        "payload_file_count": len(receipts), "payload_bytes": sum(x["bytes"] for x in receipts),
        "counts": dict(Counter(Path(x["path"]).suffix for x in receipts)),
        "artifacts": inventory["artifacts"], "not_downloaded_artifacts": inventory["not_downloaded_artifacts"],
        "excluded_extracted_files": exclusions,
        "excluded_metadata": "Transient download responses and artifact-manifest.json are omitted because they can contain signed URLs.",
        "secret_scan_patterns": list(SECRET_PATTERNS),
        "normalization": "lexicographic POSIX PAX members; mode0644 uid/gid0 empty owner names, mtime0; gzip mtime0, empty filename, level9",
        "limits": reviewed["limits"] + ["Only selected PNGs are embedded; each omitted image or binary has an explicit reason and identity. Semantic reports and save bytes are retained.", "This archive preserves evidence; packaging creates no additional engine or visual acceptance."]}
    manifest_raw = encoded(manifest)
    scan(manifest_raw, "manifest.json")
    selected["manifest.json"] = manifest_raw
    selected["README.txt"] = (b"DIAGNOSTIC/PARTIAL ONLY: completed failed run. No full-gate acceptance. Retained independent component audits establish only their explicit scope.\n\n" if diagnostic else b"") + b"Source-bound downloaded cloud evidence. Verify every retained payload against manifest.json. Original artifact ZIP digest and size matched GitHub metadata; every extracted member was compared byte-for-byte, including excluded files. Source, checkout and workflow head are distinct records. Archive hash is external to avoid self-reference. No engines or PowerShell ran during audit or packaging.\n"
    output.mkdir(parents=True, exist_ok=True)
    archive_path = output / manifest["bundle"]
    with archive_path.open("wb") as stream, gzip.GzipFile(fileobj=stream, filename="", mode="wb", mtime=0, compresslevel=9) as compressed:
        with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
            for name, value in sorted(selected.items()):
                raw = value.read_bytes() if isinstance(value, Path) else value
                info = tarfile.TarInfo(name)
                info.size, info.mode, info.mtime, info.uid, info.gid = len(raw), 0o644, 0, 0, 0
                info.uname = info.gname = ""
                archive.addfile(info, io.BytesIO(raw))
    with tarfile.open(archive_path, "r:gz") as archive:
        require(archive.getnames() == sorted(selected), "ARCHIVE_MEMBER_SET_MISMATCH")
        for name, value in selected.items():
            expected = sha(value) if isinstance(value, Path) else hashlib.sha256(value).hexdigest()
            require(hashlib.file_digest(archive.extractfile(name), "sha256").hexdigest() == expected, f"ARCHIVE_ROUND_TRIP_MISMATCH: {name}")
    (output / "manifest.json").write_bytes(manifest_raw)
    receipt = {"archive": archive_path.name, "evidence_kind": manifest["evidence_kind"], **identity(archive_path), "manifest_sha256": hashlib.sha256(manifest_raw).hexdigest(),
        "payload_file_count": len(receipts), "archive_member_count": len(selected), "excluded_file_count": len(exclusions), "round_trip_verified": True}
    (output / "bundle-receipt.json").write_bytes(encoded(receipt))
    (output / "SHA256SUMS.txt").write_text(f"{receipt['sha256']}  {archive_path.name}\n{receipt['manifest_sha256']}  manifest.json\n")
    print(json.dumps(receipt))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("audit", "package", "diagnostic-package"):
        item = sub.add_parser(name)
        item.add_argument("--run-root", type=Path, required=True)
        item.add_argument("--attachments", type=Path, action="append", required=True)
        item.add_argument("--omissions", type=Path, help="JSON object: artifact name or ID -> explicit reason")
        item.add_argument("--output", type=Path, required=name != "audit")
        if name in ("audit", "diagnostic-package"):
            item.add_argument("--repo", type=Path, required=True)
            item.add_argument("--source", required=True)
            item.add_argument("--checkout", required=True)
            item.add_argument("--master", help="For PR merge: exact expected first parent; source must be second")
            item.add_argument("--allow-source-diff", action="append", default=[], help="Explicit allowed checkout/source changed path glob; repeat")
            item.add_argument("--expected-jobs", type=int, required=True)
            item.add_argument("--no-checkout-job", action="append", default=[], help="Exact checkout-free aggregate job name; repeat")
        if name == "audit":
            item.add_argument("--expected-xml", type=int, required=True)
            item.add_argument("--reading-modes", default="write,read,repeat,variant,witness-read")
        if name == "package":
            item.add_argument("--audit", type=Path)
        if name != "audit":
            item.add_argument("--name", required=True, help="Archive basename, without .tar.gz")
        if name == "diagnostic-package":
            item.add_argument("--workflow-head", required=True, help="Exact workflow helper SHA from failed run API metadata")
            item.add_argument("--diagnosis", required=True, help="Investigator diagnosis; explicitly recorded as such, not inferred as test acceptance")
    args = parser.parse_args()
    {"audit": audit, "package": package, "diagnostic-package": diagnostic_package}[args.command](args)


if __name__ == "__main__":
    main()
