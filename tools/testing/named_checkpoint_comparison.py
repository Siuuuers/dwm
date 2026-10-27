"""Matched ordinary passage, Load and manual Save after checkpoint-only Autosave.

Reuse the existing native-input observer without requiring the removed automatic
write path to execute. Named checkpoint arrival requires its separate authored
integration journey and is deliberately not claimed by this comparison.
"""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import median

import passage_compilation_comparison as passage

BASELINE = "249b66bc0158353e0e576daf89768096665e95b7"
METHODS = {
    "scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd": (
        "commit_scene_event", "_commit_scene_event_autosave", "_scene_candidate_reference"),
    "scripts/application/run/SaveManagerCheckpointPort.gd": ("capture", "prepare", "commit"),
    "scripts/infrastructure/storage/JsonFileStorage.gd": (
        "write_atomic", "write_atomic_reconciled", "write_atomic_if_revision"),
}
STORAGE_METHODS = tuple(
    f"{'GameSaveStorage' if Path(path).stem == 'JsonFileStorage' else Path(path).stem}.{name}"
    for path, names in METHODS.items() if Path(path).stem != "SaveManagerNarrativeCheckpointPort"
    for name in names
)
WRITE_METHODS = tuple(name for name in STORAGE_METHODS if name.startswith("GameSaveStorage."))


def prepare(root, harness):
    passage.prepare(root, harness)
    receipt_path = root / "startup-variant.json"
    receipt = json.loads(receipt_path.read_text())

    def edit(relative, transform):
        path = root / relative
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        path.write_text(transform(path.read_text()), encoding="utf-8")
        receipt["changes"].setdefault(relative, {"before": before})["after"] = hashlib.sha256(path.read_bytes()).hexdigest()

    def instrument(text, owner, names):
        text = passage.history.wrap(text, owner, names)
        if owner == "JsonFileStorage":
            for name in names:
                line = f'\thistory_probe.history_finish("{owner}.{name}", history_began)\n'
                text = passage.history.trusted.replace_once(text, line, line +
                    f'\thistory_probe.history_finish("{owner}.{name}.file." + relative_path, history_began)\n'
                    '\tif relative_path.get_file() != "profile.json":\n'
                    f'\t\thistory_probe.history_finish("GameSaveStorage.{name}", history_began)\n')
        return text

    for relative, names in METHODS.items():
        edit(relative, lambda text, owner=Path(relative).stem, names=names:
             instrument(text, owner, names))

    def probe(text):
        replace = passage.history.trusted.replace_once
        # Inspect bytes before and after the operation, never inside the timing.
        text = replace(text, '\t# All cache inspection and translation lookup end before the timed action.\n',
            '\tvar passage_autosave_before := FileAccess.get_sha256("user://saves/autosave.json") if FileAccess.file_exists("user://saves/autosave.json") else ""\n'
            '\t# All cache inspection and translation lookup end before the timed action.\n')
        text = replace(text, '\tobservation["passage"] = {"entry_id": PASSAGE_ENTRY, "line_id": PASSAGE_LINE,\n',
            '\tvar passage_autosave_after := FileAccess.get_sha256("user://saves/autosave.json") if FileAccess.file_exists("user://saves/autosave.json") else ""\n'
            '\tif variant == "candidate" and not _check(passage_autosave_before == passage_autosave_after, "ordinary passage changed Autosave bytes"): return false\n'
            '\tobservation["passage"] = {"entry_id": PASSAGE_ENTRY, "line_id": PASSAGE_LINE,\n'
            '\t\t"autosave_before": passage_autosave_before, "autosave_after": passage_autosave_after,\n')
        text = replace(text, '\tvar opened: Dictionary = await pause.open_scene_backup("save")\n',
            '\tvar prior_scope := history_scope\n'
            '\thistory_scope = "manual_save"\n'
            '\tvar manual_save_began := Time.get_ticks_usec()\n'
            '\tvar opened: Dictionary = await pause.open_scene_backup("save")\n')
        text = replace(text, '\tvar saved: Dictionary = pause._backup_port.commit_action(prepared.value.token)\n',
            '\tvar saved: Dictionary = pause._backup_port.commit_action(prepared.value.token)\n'
            '\tvar manual_save_elapsed := Time.get_ticks_usec() - manual_save_began\n'
            '\thistory_scope = prior_scope\n'
            '\tobservation["manual_save"] = {"action_elapsed_us": manual_save_elapsed, "locator": locator,\n'
            '\t\t"expected_line": expected_line, "profile": history_samples.get("manual_save", {}).duplicate(true)}\n')
        return text

    edit("startup_probe.gd", probe)
    receipt["probe_sha256"] = receipt["changes"]["startup_probe.gd"]["after"]
    receipt["named_checkpoint_observer"] = {
        "scope": "Ordinary passage storage calls and unchanged bytes; complete explicit manual Save action from Backup opening/live capture through command commit.",
        "storage_methods": STORAGE_METHODS,
        "independent_storage": "Profile writes remain recorded by method and exact relative path, but are excluded from the game-progress zero-write requirement. All other storage paths remain included.",
        "named_arrival": "Not measured: the baseline has no named-checkpoint authoring feature.",
    }
    receipt_path.write_text(json.dumps(receipt, indent=2), encoding="utf-8")


def _counts(profile):
    return {method: profile.get(method, {}).get("calls", 0) for method in STORAGE_METHODS}


def summarize(root):
    passage.BASELINE = BASELINE
    passage.summarize(root)  # Retain all 24 exported outcomes, hashes and drawing checks.
    result = json.loads((root / "passage-summary.json").read_text(encoding="utf-8"))
    samples = []
    for repetition in range(1, 5):
        for variant in ("baseline", "candidate"):
            for case in ("fresh", "retained", "load"):
                name = f"r{repetition}-{variant}-{case}"
                report = json.loads((root / "measurements" / name / "results.json").read_text(encoding="utf-8-sig"))
                observed = report["observation"]
                manual = observed["manual_save"]
                assert manual["action_elapsed_us"] > 0
                assert manual["locator"] == ("slot:2" if case == "load" else "slot:1")
                counts = _counts(manual["profile"])
                assert sum(counts[name] for name in WRITE_METHODS) > 0, (name, "manual Save never reached storage")
                metrics = {"manual_save.action_elapsed_us": manual["action_elapsed_us"]}
                metrics.update({"manual_save." + method + ".calls": count for method, count in counts.items()})
                if case == "load":
                    profiles = observed["history_profile"]
                    ordinary_scopes = ["first_accept", *(f"accept_{number:03}" for number in range(3, 31)), "passage_transition"]
                    for scope in ordinary_scopes:
                        counts = _counts(profiles.get(scope, {}))
                        metrics.update({scope + "." + method + ".calls": count for method, count in counts.items()})
                        if variant == "candidate":
                            assert not any(counts.values()), (name, scope, counts)
                    if variant == "baseline":
                        counts = _counts(profiles["passage_transition"])
                        assert counts["SaveManagerCheckpointPort.prepare"] > 0, (name, "baseline preparation observer absent")
                        assert sum(counts[method] for method in WRITE_METHODS) > 0, (name, "baseline storage observer absent")
                    else:
                        assert observed["passage"]["autosave_before"] == observed["passage"]["autosave_after"]
                samples.append({"sample": name, "variant": variant, "case": case, "repetition": repetition, "metrics": metrics})
    aggregates = {}
    for variant in ("baseline", "candidate"):
        aggregates[variant] = {}
        for case in ("fresh", "retained", "load"):
            rows = [sample["metrics"] for sample in samples if sample["variant"] == variant and sample["case"] == case]
            keys = sorted(set().union(*(row.keys() for row in rows)))
            aggregates[variant][case] = {key: {"samples": values, "median": median(values), "min": min(values), "max": max(values)}
                for key in keys if (values := [row.get(key, 0) for row in rows])}
    paired = []
    for repetition in range(1, 5):
        for case in ("fresh", "retained", "load"):
            rows = {sample["variant"]: sample["metrics"] for sample in samples
                    if sample["repetition"] == repetition and sample["case"] == case}
            paired.append({"repetition": repetition, "case": case, "candidate_minus_baseline": {
                key: rows["candidate"].get(key, 0) - rows["baseline"].get(key, 0)
                for key in sorted(set(rows["candidate"]) | set(rows["baseline"]))}})
    result.update({
        "experiment": "Remove automatic intermediate storage while preserving live reading and later explicit saves.",
        "storage_and_manual_save_samples": samples,
        "storage_and_manual_save_aggregates": aggregates,
        "storage_and_manual_save_paired_differences": paired,
        "limitations": [
            "Named checkpoint arrival is not measured; baseline has no equivalent authored feature. Separate candidate integration/rendered evidence is required.",
            "Manual Save timing covers open_scene_backup (including live capture), prepare_action and commit_action; it is API-action latency, not physical-button-to-painted-confirmation latency.",
            "Independent profile.json persistence is retained and reported separately; every other storage path is subject to the zero-write rule. Storage counters count method invocations, including nested calls; do not add nested counts or durations as independent writes or speed gains.",
            "Four same-run counterbalanced samples are descriptive. Fresh user data does not imply cold OS caches.",
        ],
    })
    (root / "named-checkpoint-summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"ordinary_storage_and_manual_save": aggregates}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "prepare", "summarize"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.action == "extract": passage.history.trusted.extract(args.root)
    elif args.action == "prepare": prepare(args.root, args.harness)
    else: summarize(args.root)
