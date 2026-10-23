#!/usr/bin/env python3
"""Preview or apply the three navigation updates after final paused-Settings F5 acceptance.

Task-local preparation only. This script is intentionally not run while evidence
is pending. Default is a validated dry-run diff; --apply writes only the three
named navigation documents. It never runs engines, publishes, edits evidence, or
changes Beads. A completed broad acceptance-summary.json from the current final
join is required. Counts and source/run bindings are deliberately not configurable.

Example (replace every placeholder with the final accepted identity):
  python prepare_settings_navigation.py --source SOURCE --checkout MERGE \
    --run-id ID --run-number NUMBER --acceptance-summary PATH
Review that preview, prepare the root-owned receipt, then repeat with --apply.
"""

import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


REPO_DEFAULT = Path(__file__).resolve().parent / "dwm"
RECEIPT = "evidence/phase_2r/paused_settings_quick_2026_10_02/receipt.json"
RECEIPT_LINK = "../../" + RECEIPT
AUTHORITY_LINK = "../design/2026-08-13-ordered-ending-host-universal-pause-ui-ux-amendment.md"
BASELINES = {
    "docs/agent/2026-09-23-next-session-handoff.md": "c54fac18f5d714da371fb95760ebb959cc2794aaa6c96f8fa167fcc64a0dc96d",
    "docs/agent/execution-map.md": "128bbcef78d24085a7dfd46af76c082dc913462ab738597d921c86360831e565",
    "docs/agent/2026-09-29-reading-rail-next-slice.md": "f4702cb4073fc80c0f9e3265d666a632a9ef236252282123d612b8ac5f14ad61",
}
EXPECTED_COUNTS = {
    "case_executions": 2286, "unique_cases": 2282, "unique_scripts": 194,
    "failures": 0, "errors": 0, "skipped": 0,
}
SEMANTIC_ASSERTIONS = {
    "partial_reveal_preserved_until_f5", "only_current_reveal_completed",
    "exact_settings_host_focus_and_suspension_retained", "exact_canonical_source_preserved",
    "single_quick_transaction_verified", "autosave_profile_identity_receipts_unchanged",
    "fresh_restore_exact_and_silent", "original_eight_modes_and_seal_unchanged",
}


class Refusal(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise Refusal(message)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def strict_json(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result

    def nonfinite(value):
        raise Refusal("Non-finite JSON number: " + value)

    return json.loads(raw, object_pairs_hook=pairs, parse_constant=nonfinite)


def git(repo, *arguments):
    return subprocess.check_output(["git", "-C", str(repo), *arguments])


def integer_equal(value, expected):
    return type(value) is int and value == expected


def validate_acceptance(args, summary):
    require(type(summary) is dict, "Acceptance summary must be an object")
    require(summary.get("source_commit") == args.source, "Acceptance source differs")
    require(summary.get("actual_checkout_merge") == args.checkout, "Acceptance checkout differs")
    require(integer_equal(summary.get("run_id"), args.run_id), "Acceptance run ID differs")
    require(integer_equal(summary.get("run_number"), args.run_number), "Acceptance run number differs")
    require(summary.get("run_url") == f"https://github.com/Siuuuers/dwm/actions/runs/{args.run_id}",
            "Acceptance run URL differs")
    workflow = summary.get("workflow_run", {})
    require(workflow.get("status") == "completed" and workflow.get("conclusion") == "success",
            "Final workflow has not completed successfully")
    require(type(workflow.get("run_attempt")) is int and workflow["run_attempt"] > 0,
            "Explicit workflow attempt required")
    for key in ("overall_acceptance_pass", "overall_accepted", "all_jobs_completed",
                "all_checkout_provenance_verified", "independent_non_gut_audit_complete"):
        require(summary.get(key) is True, "Incomplete final acceptance: " + key)
    for key in ("expected_job_count", "observed_job_count"):
        require(integer_equal(summary.get(key), 23), "Exactly 23 broad jobs required: " + key)
    jobs = summary.get("jobs")
    require(type(jobs) is list and len(jobs) == 23, "Exactly 23 job records required")
    require(len({job["id"] for job in jobs}) == 23, "Duplicate job identities")
    checkout_count = 0
    for job in jobs:
        require(job.get("status") == "completed" and job.get("conclusion") == "success",
                "A broad job is incomplete or unsuccessful")
        checkouts = job.get("checkout_shas")
        require(type(checkouts) is list, "Missing job checkout provenance")
        if checkouts:
            require(set(checkouts) == {args.checkout}, "Job tested a different checkout")
            require(job.get("checkout_exemption") is None, "Checked-out job has an exemption")
            checkout_count += 1
        else:
            require(job.get("name") == "Windows / seven-day retained history"
                    and job.get("checkout_exemption") == "explicit checkout-free aggregate",
                    "Unexpected checkout-free job")
    require(checkout_count == 22 and integer_equal(summary.get("unique_verified_checkout_execution_count"), 22),
            "Exactly 22 bound execution jobs plus the aggregate required")
    counts = summary.get("gut", {})
    for key, expected in EXPECTED_COUNTS.items():
        require(integer_equal(counts.get(key), expected), "Unexpected GUT count: " + key)
    boundary = summary.get("source_boundary", {})
    require(boundary.get("source") == args.source and boundary.get("tested_checkout") == args.checkout,
            "Source boundary differs from final subject")
    require(boundary.get("all_unlisted_paths_byte_identical") is True,
            "Source boundary byte audit is incomplete")
    settings = summary.get("settings_quick_save", {})
    require(settings.get("audit_complete") is True
            and settings.get("runtime_proof_failures") == [] and settings.get("pending_areas") == [],
            "Paused Settings F5 component proof is incomplete")
    require(settings.get("source") == args.source and settings.get("checkout") == args.checkout
            and integer_equal(settings.get("run_id"), args.run_id)
            and integer_equal(settings.get("run_attempt"), workflow["run_attempt"]),
            "Settings component source/run binding differs")
    assertions = settings.get("semantic_assertions", {})
    require(set(assertions) == SEMANTIC_ASSERTIONS and all(value is True for value in assertions.values()),
            "Settings semantic proof is incomplete")
    selectors = summary.get("selectors", {})
    require(selectors.get("production_catalogue_registered") is False,
            "Production catalogue boundary changed")
    non_gut = summary.get("non_gut_proofs", {})
    require(non_gut.get("audit_complete") is True and non_gut.get("runtime_proof_failures") == []
            and non_gut.get("pending_areas") == [], "Non-GUT proof is incomplete")


def validate_source(repo, source):
    require(git(repo, "rev-parse", "HEAD").decode().strip() == source,
            "Repository HEAD changed; expected the exact final accepted source")
    # Root may already be preparing evidence and Beads, but runtime changes would
    # make the current tree a different candidate. Neither is edited here.
    changed = git(repo, "diff", "--name-only", "-z", source).decode().split("\0")
    allowed = set(BASELINES)
    unexpected = [path for path in changed if path and path not in allowed
                  and not path.startswith("evidence/") and not path.startswith(".beads/")]
    require(not unexpected, "Unexpected working-source changes: " + ", ".join(unexpected))


def baseline_bytes(repo, source):
    result = {}
    for name, expected in BASELINES.items():
        path = repo / name
        require(not path.is_symlink() and path.resolve().is_relative_to(repo), "Unexpected document path: " + name)
        raw = path.read_bytes()
        require(digest(raw) == expected, "Navigation baseline changed: " + name)
        require(git(repo, "show", source + ":" + name) == raw,
                "Final source does not contain the pinned navigation baseline: " + name)
        result[name] = raw
    return result


def replace_once(text, old, new, label):
    count = text.count(old)
    require(count == 1, f"Expected exactly one anchor for {label}; found {count}")
    return text.replace(old, new, 1)


def proposed_documents(original, args):
    source, checkout, number, run_id = args.source, args.checkout, args.run_number, args.run_id
    run_link = f"[Run{number}](https://github.com/Siuuuers/dwm/actions/runs/{run_id})"
    f9 = (
        "Next bounded work is guarded F9 Quick Load from admissible nonmodal Settings\n"
        "under `dwm-vky.14`, using the existing confirmation and restore owners.\n"
        "Settings F9 remains unavailable in this accepted F5 increment; its admission,\n"
        "Cancel/source preservation, confirmed canonical Load with Pause closed, and\n"
        "blocked-input/no-queue proof remain separate pending acceptance. The\n"
        f"[ordered-ending amendment]({AUTHORITY_LINK}) §§13.4 and 24.5 already require\n"
        "this parity; no new architecture decision is needed.\n"
    )
    outcome = (
        f"**Accepted bounded paused Settings F5.** Source: `{source}`.\n"
        f"Tested PR merge: `{checkout}`.\n"
        f"{run_link} passes 23/23 jobs, 2,286 GUT executions / 2,282 unique\n"
        "cases / 194 scripts, zero failures/errors/skips. The connected noncanonical\n"
        "Solo proof preserves partial reveal through Pause and Settings, then a fresh\n"
        "F5 completes only the current reveal and commits one Quick transaction while\n"
        "retaining the exact canonical source, Settings host, focus and suspension.\n"
        "A fresh process loads that exact semantic point without repeated speech.\n"
        "The retained Quick bytes are directly audited; Autosave/Profile neutrality\n"
        "uses source-bound identity receipts and write observations. The original\n"
        "eight-mode v1 and bounded physical v2 proofs retain their prior scopes.\n"
        "Public port signatures and supported save formats are unchanged. Exact\n"
        f"evidence and limitations belong in the [paused Settings F5 receipt]({RECEIPT_LINK}).\n"
        "Production catalogue registration remains disabled. This does not accept\n"
        "Settings F9, Hospital/ending continuity, production replay, native all-input\n"
        "or accessibility behavior, pixel-identical scrollback, or final visual polish.\n"
        "All 23 unfinished Beads remain; no status/dependency change, closure or live\n"
        "Dolt synchronization is implied. Later records-only commits are not\n"
        "separately engine-tested.\n"
    )
    result = {}
    handoff_name, map_name, reading_name = BASELINES
    text = original[handoff_name].decode("utf-8")
    edits = [
        ("## Current acceptance\n\n", "## Current acceptance\n\n" + outcome + "\n", "handoff acceptance"),
        ("Next bounded work is paused Settings F5 under `dwm-vky.14`: complete only the\ncurrent reveal, preserve the exact semantic point, and retain existing Save\nadmission and command custody.\n", f9, "handoff next clause"),
        ("   catalogue-v1 journey. Next, cover paused Settings F5 using the current\n   Pause/Settings and reading owners: finish only the current reveal, preserve\n   exact semantic position, and prove Save admission and command custody.\n",
         "   catalogue-v1 journey and the accepted paused Settings F5 proof. Next, cover\n   guarded F9 Quick Load from admissible nonmodal Settings through existing\n   confirmation/restore custody, with Cancel preserving the source and confirmed\n   Load reconstructing the canonical destination with Pause closed. Blocking\n   owners admit no shortcut and queue nothing. This remains separate pending\n   acceptance under ordered-ending amendment §§13.4 and 24.5.\n", "handoff resume"),
        ("Run127 is the current bounded broad cloud acceptance. Run122 physical proof,\nRun120 selector admission and Run114 Next remain historical foundations; subsequent\nhandoff/evidence edits are records-only. Historical receipts remain unchanged.\n",
         f"Run{number} is the current bounded broad cloud acceptance for paused Settings F5.\nRun127 title geometry/correction, Run122 physical proof, Run120 selector admission\nand Run114 Next remain historical foundations; subsequent handoff/evidence edits\nare records-only. Historical receipts remain unchanged.\n", "handoff current broad"),
    ]
    for old, new, label in edits:
        text = replace_once(text, old, new, label)
    result[handoff_name] = text.encode("utf-8")

    text = original[map_name].decode("utf-8")
    edits = [
        ('inspected_source: "79b36d90e3ea41d36a81a4c5ba0f87b0ae4a7bfa"',
         f'inspected_source: "{source}"', "map inspected source"),
        ("Next bounded work: paused Settings F5, completing only the current reveal while preserving exact semantic position and Save custody.",
         f"Paused Settings F5 is accepted at source `{source}` / tested merge `{checkout}` / Run{number}; the [shared receipt]({RECEIPT_LINK}) binds current-reveal-only Quick Save, retained Settings/focus/canonical source and silent fresh Load. Next bounded work: guarded Settings F9 Quick Load through existing confirmation and restore custody; it remains unavailable and separately unaccepted in this increment.", "map queue outcome"),
        ("Continue the next bounded `dwm-vky.14` clause: paused Settings F5 must complete\nonly the current reveal, preserve the exact semantic point, and use existing\nSave admission and command custody. Reuse the current Pause/Settings and reading\nowners; production catalogue work and Hospital/ending continuity remain separate.\nTransient scrollback remains separate from the exact semantic current caption\nand History; no final visual-polish acceptance is claimed.\n",
         outcome + "\n" + f9 + "Reuse the current Pause/Settings and reading owners; production catalogue work\nand Hospital/ending continuity remain separate. Transient scrollback remains\nseparate from the exact semantic current caption and History; no final\nvisual-polish acceptance is claimed.\n", "map accepted clause"),
    ]
    for old, new, label in edits:
        text = replace_once(text, old, new, label)
    result[map_name] = text.encode("utf-8")

    text = original[reading_name].decode("utf-8")
    edits = [
        ("Updated after the cold-Load layout diagnostic corrected the earlier clipping claim, retaining Run122 acceptance of the bounded physical catalogue-v2 Save/Load proof, Run120 selector admission and the Run114 one-shot Next foundation. Check the live handoff and its source-bound receipts for exact acceptance boundaries. This navigation record does not change specification authority, close Beads, or authorize production narrative content.",
         f"Updated after Run{number} accepted bounded paused Settings F5, preserving the cold-Load layout correction, Run127 title-geometry guard, Run122 bounded physical catalogue-v2 Save/Load proof, Run120 selector admission and Run114 one-shot Next foundation. Check the live handoff and source-bound receipts for exact acceptance boundaries. This navigation record does not change specification authority, close Beads, or authorize production narrative content.", "reading introduction"),
        ("## Current boundary\n\n", "## Current boundary\n\n" + outcome + "\n", "reading current acceptance"),
        ("**Accepted bounded source:** `cfb7616bfd498979bef520e1522cbbb712298aea`. **Tested PR merge:** `f527957009017993a4987174aeb76a26e8793075`.\nFinal [Run122]",
         "**Historical physical-v2 accepted source:** `cfb7616bfd498979bef520e1522cbbb712298aea`. **Tested PR merge:** `f527957009017993a4987174aeb76a26e8793075`.\nHistorical [Run122]", "reading historical physical proof"),
        ("- Production catalogue/selector admission and exact Next/replay, Hospital/ending continuity, paused Settings F5, arbitrary production partial-reveal abort lifetime and full native all-input/accessibility acceptance remain separate unfinished work.",
         "- Production catalogue/selector admission and exact Next/replay, Hospital/ending continuity, guarded Settings F9, arbitrary production partial-reveal abort lifetime and full native all-input/accessibility acceptance remain separate unfinished work.", "reading unfinished clauses"),
        ("The next bounded `dwm-vky.14` clause is paused Settings F5: complete only the\ncurrent reveal, preserve the exact semantic point, and retain existing Save\nadmission and command custody. The [layout diagnostic](../../evidence/phase_2r/challenge_layout_2026_10_02/receipt.json)\ncorrects the earlier clipping claim without a production layout change.\n",
         f9 + "The [layout diagnostic](../../evidence/phase_2r/challenge_layout_2026_10_02/receipt.json)\ncorrects the earlier clipping claim without a production layout change.\n", "reading next clause"),
        ("Next, cover paused Settings F5 under `dwm-vky.14`: finish only the current reveal,\npreserve the semantic point, and use the existing Save and custody owners.\nProduction catalogue admission, Hospital/ending continuity and native acceptance\nremain separate work.\n",
         f"The later [paused Settings F5 receipt]({RECEIPT_LINK})\naccepts the current-reveal-only Quick Save clause at its identified source.\nNext is guarded Settings F9 under `dwm-vky.14`; it remains separate pending\nacceptance under ordered-ending amendment §§13.4 and 24.5. Production catalogue\nadmission, Hospital/ending continuity and native acceptance remain separate work.\n", "reading post-correction navigation"),
        ("Plain Pause/preview/Return cancellation remains literal; paused Settings F5 is outside this accepted increment.",
         "Plain Pause/preview/Return cancellation remains literal; bounded paused Settings F5 is accepted in its own source-bound receipt, while Settings F9 remains separate pending acceptance.", "reading settled save scope"),
        ("Paused Settings F5 needs no new architecture decision. Before production catalogue\n",
         "Guarded Settings F9 needs no new architecture decision; its admission and\nrecovery follow ordered-ending amendment §§13.4 and 24.5. Before production catalogue\n", "reading later input boundary"),
    ]
    for old, new, label in edits:
        text = replace_once(text, old, new, label)
    result[reading_name] = text.encode("utf-8")
    require(set(result) == set(BASELINES), "Unexpected write set")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--checkout", required=True)
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--run-number", type=int, required=True)
    parser.add_argument("--acceptance-summary", type=Path, required=True)
    parser.add_argument("--repo", type=Path, default=REPO_DEFAULT)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="Write exactly the three documents after validation")
    mode.add_argument("--dry-run", action="store_true", help="Explicit default: validate and print diffs only")
    args = parser.parse_args()
    require(all(re.fullmatch(r"[0-9a-f]{40}", value) for value in (args.source, args.checkout)),
            "Full lowercase 40-character source and checkout SHAs required")
    require(args.run_id > 0 and args.run_number > 127, "A later identified final broad run is required")
    repo = args.repo.resolve(strict=True)
    summary_path = args.acceptance_summary.resolve(strict=True)
    require(summary_path.name in {"acceptance-summary.json", "final-acceptance-summary.json"},
            "The final acceptance-summary.json is required")
    summary_raw = summary_path.read_bytes()
    summary = strict_json(summary_raw)
    validate_acceptance(args, summary)
    validate_source(repo, args.source)
    original = baseline_bytes(repo, args.source)
    proposed = proposed_documents(original, args)
    manifest = {
        "mode": "apply" if args.apply else "dry-run",
        "source": args.source, "checkout": args.checkout,
        "run_id": args.run_id, "run_number": args.run_number,
        "acceptance_summary": {"path": str(summary_path), "bytes": len(summary_raw), "sha256": digest(summary_raw)},
        "documents": {name: {"baseline_sha256": BASELINES[name], "proposed_sha256": digest(raw)}
                      for name, raw in proposed.items()},
    }
    print(json.dumps(manifest, indent=2))
    for name, raw in proposed.items():
        sys.stdout.writelines(difflib.unified_diff(original[name].decode("utf-8").splitlines(True),
                                                raw.decode("utf-8").splitlines(True),
                                                fromfile="a/" + name, tofile="b/" + name))
    if not args.apply:
        print("Validated dry-run only; no files changed.")
        return
    receipt_path = repo / RECEIPT
    require(receipt_path.is_file() and not receipt_path.is_symlink(),
            "Prepare the root-owned paused Settings receipt before applying navigation")
    require(type(strict_json(receipt_path.read_bytes())) is dict, "Root-owned receipt must be a JSON object")
    # Check the final subject, acceptance file and all three baselines again at the
    # write boundary. A changed candidate or concurrently edited document refuses.
    require(summary_path.read_bytes() == summary_raw, "Acceptance summary changed during preparation")
    validate_source(repo, args.source)
    require(baseline_bytes(repo, args.source) == original, "Navigation changed during preparation")
    written = []
    try:
        for name, raw in proposed.items():
            require((repo / name).read_bytes() == original[name], "Concurrent navigation change: " + name)
            (repo / name).write_bytes(raw)
            written.append(name)
    except Exception:
        for name in reversed(written):
            if (repo / name).read_bytes() == proposed[name]:
                (repo / name).write_bytes(original[name])
        raise
    print("Applied exactly three navigation documents; evidence and Beads were not edited.")


if __name__ == "__main__":
    try:
        main()
    except (Refusal, KeyError, TypeError, OSError, json.JSONDecodeError, subprocess.CalledProcessError) as error:
        print("REFUSED: " + str(error), file=sys.stderr)
        raise SystemExit(2)
