"""Prepare and summarize matched cloud exports using the pinned startup observer."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess

DIAGNOSTIC = "d72b67506e05c03f161201df7b9fc5430e2b136e"
HARNESS = ("prepare_startup_attribution.py", "startup_probe.gd", "Invoke-ExportedStartupProbe.ps1")
OWNERS = ("StartupProbe", "ProfileManager", "GameState", "SaveManager", "LocalizationManager",
          "AudioManager", "SystemTtsCoordinator", "WindowModeManager", "EffectResolver", "SceneRouter",
          "InputManager", "AccessibilityManager", "Dialogic", "DialogicBridge", "ApplicationBootstrap")


def extract(folder):
    folder.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for name in HARNESS:
        data = subprocess.check_output(["git", "show", f"{DIAGNOSTIC}:tools/testing/{name}"])
        (folder / name).write_bytes(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
    (folder / "harness.json").write_text(json.dumps({"commit": DIAGNOSTIC, "sha256": hashes}, indent=2))


def prepare(root, harness):
    spec = importlib.util.spec_from_file_location("startup_attribution", harness / HARNESS[0])
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Baseline means observation-only overlay, identically applied to both sources.
    # Its replace_once and coroutine guards reject outdated instrumentation anchors.
    module.prepare(root, "baseline", trace_autoloads=True, trace_newacc=True)


def summarize(folder):
    rows = []
    for pair, order in (("ab", ("baseline", "candidate")), ("ba", ("candidate", "baseline"))):
        for variant in order:
            for case in ("fresh", "retained"):
                run = folder / "measurements" / f"{pair}-{variant}-{case}"
                report = json.loads((run / "results.json").read_text(encoding="utf-8-sig"))
                process = json.loads((run / "process.json").read_text(encoding="utf-8-sig"))
                assert report["complete"] and not report["failures"] and process["clean_exit"]
                assert not process["timed_out"] and process["exit_code"] == 0
                assert process["status"] == "collected_requires_visual_review"
                logs = "\n".join((run / name).read_text(encoding="utf-8-sig", errors="replace")
                                 for name in ("stdout.log", "stderr.log", "render.log"))
                assert not re.search(r"SCRIPT ERROR:|^\s*ERROR:|Unicode parsing error|Unexpected NUL character", logs, re.M)
                assert report["variant"] == variant and report["case"] == case
                trace = report["autoload_trace"]
                assert [(t["owner"], t["event"]) for t in trace] == [(o, e) for o in OWNERS for e in ("begin", "end")]
                assert all(b["ticks_us"] >= a["ticks_us"] for a, b in zip(trace, trace[1:]))
                assert trace[-1]["ticks_us"] <= report["milestones"]["probe_enter_tree"]["ticks_us"]
                profile = report["newacc_validation_profile"]
                assert report["trace_newacc"] and profile["ok"] and profile["inclusive_nested"]
                assert profile["configuration_calls"] >= 1
                # Shared preparation can legitimately eliminate all timed compiler calls.
                assert isinstance(profile["compilation_calls"], int) and profile["compilation_calls"] >= 0
                phases = {}
                for name in ("decision", "plans", "resume", "apply_transaction", "settle_pair", "commit_intent"):
                    samples = [p for p in report["phases"] if p["phase"] == f"newacc.{name}"]
                    assert len(samples) >= (2 if name == "plans" else 1), name
                    for sample in samples:
                        assert sample["ok"] and sample["inclusive_nested"] and isinstance(sample["validation_counter_delta"], dict)
                        assert sample["end"]["ticks_us"] >= sample["start"]["ticks_us"] and sample["elapsed_us"] >= 0
                    phases[name] = [s["elapsed_us"] / 1000 for s in samples]
                for image in process["images"]:
                    assert hashlib.sha256((run / image["name"]).read_bytes()).hexdigest() == image["sha256"]
                metrics = {k: v for k, v in process.items() if k.endswith("_ms") and not k.endswith("unix_ms")}
                metrics["new_acc_excluding_consent_dwell_ms"] = process["new_acc_to_caption_complete_ms"] - process.get("consent_dwell_ms", 0)
                rows.append({"pair": pair, "variant": variant, "case": case, "metrics": metrics,
                             "max_frame_gap_us": report["max_frame_gap_us"], "phases_ms": phases,
                             "configuration_calls": profile["configuration_calls"], "compilation_calls": profile["compilation_calls"]})
    comparisons = []
    for pair in ("ab", "ba"):
        for case in ("fresh", "retained"):
            matched = {r["variant"]: r for r in rows if r["pair"] == pair and r["case"] == case}
            comparisons.append({"pair": pair, "case": case, "candidate_minus_baseline_ms": {
                key: matched["candidate"]["metrics"][key] - value
                for key, value in matched["baseline"]["metrics"].items()
                if key in matched["candidate"]["metrics"]}})
    result = {"scope": "Eight instrumented exported New Acc journeys, two matched orders on one Windows runner. Fresh means empty user data, not cold OS/driver caches. Retained profiles continue their own variant's fresh run. No Load measurement. Inclusive child phases must not be summed into parents. Screenshot visual review remains required; two samples per variant/case do not establish statistical certainty.",
              "samples": rows, "paired_differences": comparisons}
    (folder / "comparison.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "prepare", "summarize"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.action == "extract": extract(args.root)
    elif args.action == "prepare": prepare(args.root, args.harness)
    else: summarize(args.root)
