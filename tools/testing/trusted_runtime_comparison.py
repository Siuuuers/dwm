"""Compare matched baseline and candidate exports across fresh, retained and Load processes."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
from statistics import median

DIAGNOSTIC = "d72b67506e05c03f161201df7b9fc5430e2b136e"
HARNESS = ("prepare_startup_attribution.py", "startup_probe.gd", "Invoke-ExportedStartupProbe.ps1")
OWNERS = ("StartupProbe", "ProfileManager", "GameState", "SaveManager", "LocalizationManager",
          "AudioManager", "SystemTtsCoordinator", "WindowModeManager", "EffectResolver", "SceneRouter",
          "InputManager", "AccessibilityManager", "Dialogic", "DialogicBridge", "ApplicationBootstrap")


LOAD_PROBE = r'''
func _load_saved(menu: Node) -> void:
	var saves := get_node("/root/SaveManager")
	var bridge := get_node("/root/DialogicBridge")
	var game := get_node("/root/GameState")
	var parser := load("res://scripts/validation/StrictJson.gd")
	var document: Dictionary = parser.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _check(document.get("ok", false), "seed autosave is unreadable"): return
	var saved: Dictionary = document.value.current_snapshot.snapshot
	var source_hash := FileAccess.get_sha256("user://saves/autosave.json")
	if not _check(saved.narrative_checkpoint.reading_session.position_id == FIRST_LINE, "unexpected seed position"): return
	var ready := {"count": 0}
	saves.live_session_ready.connect(func() -> void:
		ready.count += 1
		mark("load_ready"))
	var login: Button = menu.get_node("%LogInButton")
	if not await _prepare_pointer(login, "login"): return
	if not _begin_newacc_scope("exported_load"): return
	if not await _click(login, "login"): return
	var deadline := Time.get_ticks_msec() + 300000
	var app: Control
	while Time.get_ticks_msec() < deadline:
		app = menu._backup_app_instance
		if is_instance_valid(app) and app.is_visible_in_tree() and not menu._title_transition \
				and app.action_buttons.has("load") and not app.action_buttons["load"].disabled:
			break
		await get_tree().process_frame
	if not _check(is_instance_valid(app) and app.is_visible_in_tree() and app.selected_locator == "autosave" \
			and app.action_buttons.has("load") and not app.action_buttons["load"].disabled, "autosave Load unavailable"): return
	await RenderingServer.frame_post_draw
	mark("backup_drawn_usable")
	gap_scope = ""
	if not _capture("backup"): return
	if not await _prepare_pointer(app.action_buttons["load"], "load"): return
	if not await _click(app.action_buttons["load"], "load"): return
	deadline = Time.get_ticks_msec() + 300000
	while Time.get_ticks_msec() < deadline:
		if is_instance_valid(app) and is_instance_valid(app.confirmation):
			_check(false, "Title Load unexpectedly requested confirmation")
			return
		var caption: Node = get_node("/root/SceneRouter")._production_pause._find_caption(get_tree().root)
		if is_instance_valid(caption) and caption.caption_text.is_visible_in_tree():
			var native: Node = caption.caption_text
			var event: Resource = bridge._runtime_adapter._current_skip_text(true)
			if ready.count == 1 and bridge._runtime_adapter.current_line_id() == FIRST_LINE \
					and event != null and int(event.get("state")) == 2 and not native.revealing \
					and native.visible_ratio == 1.0 and bridge.is_current_line_presentation_acknowledged() \
					and game.capture_live_session().value.active:
				await RenderingServer.frame_post_draw
				mark("load_caption_complete_drawn_idle")
				gap_scope = ""
				observation = {"line_id": FIRST_LINE, "text": native.get_parsed_text(), "visible_ratio": native.visible_ratio,
					"event_done": true, "active": true, "ready_count": ready.count, "source_autosave_sha256": source_hash}
				break
		await get_tree().process_frame
	if not _check(not observation.is_empty(), "Load did not reach the complete saved caption"): return
	_end_newacc_scope(true)
	var current: Dictionary = game.capture_run_snapshot_input()
	if not _check(current.lifecycle.run_id == saved.lifecycle.run_id and current.lifecycle.branch_id != saved.lifecycle.branch_id,
		"Load must preserve run identity and allocate a new branch"): return
	if not _check(current.gameplay == saved.gameplay and current.scene == saved.scene, "Load changed saved gameplay or scene"): return
	var expanded: Dictionary = load("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(saved.narrative_checkpoint)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _check(expanded.get("ok", false) and reading.get("ok", false) and reading.value == expanded.value,
		"Load did not restore the complete saved reading checkpoint"): return
	var locale: String = get_node("/root/LocalizationManager").get_locale()
	var texts: Dictionary = load("res://scripts/localization/StoryLocalization.gd").catalog(locale)
	if not _check(observation.text == texts.get(FIRST_LINE, FIRST_EN), "loaded caption differs from authored text"): return
	if not _check(FileAccess.get_sha256("user://saves/autosave.json") == source_hash, "Load changed source autosave bytes"): return
	var incomplete: Dictionary = saves._continuation_journal.list_incomplete()
	if not _check(incomplete.get("ok", false) and incomplete.value.is_empty(), "Load journal not settled"): return
	observation["gameplay_preserved"] = true
	observation["scene_preserved"] = true
	observation["reading_preserved"] = true
	observation["autosave_preserved"] = true
	observation["run_id"] = current.lifecycle.run_id
	observation["branch_id"] = current.lifecycle.branch_id
	if not _capture("loaded-caption"): return
	_finish(true)
'''


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected one Load diagnostic anchor: {old!r}")
    return text.replace(old, new, 1)


def extract(folder):
    folder.mkdir(parents=True, exist_ok=True)
    hashes = {}
    for name in HARNESS:
        data = subprocess.check_output(["git", "show", f"{DIAGNOSTIC}:tools/testing/{name}"])
        (folder / name).write_bytes(data)
        hashes[name] = hashlib.sha256(data).hexdigest()
    runner = folder / "Invoke-ExportedStartupProbe.ps1"
    text = runner.read_text()
    text = replace_once(text, "[ValidateSet('new_acc', 'screens', 'apps')]", "[ValidateSet('new_acc', 'screens', 'apps', 'load')]")
    text = replace_once(text, "        if ($Journey -in @('new_acc', 'apps')) {", """        if ($Journey -eq 'load') {
            $record.login_to_backup_ms = ($m.backup_drawn_usable.ticks_us - $m.login_input.ticks_us) / 1000.0
            $record.load_action_to_ready_ms = ($m.load_ready.ticks_us - $m.load_input.ticks_us) / 1000.0
            $record.load_action_to_caption_ms = ($m.load_caption_complete_drawn_idle.ticks_us - $m.load_input.ticks_us) / 1000.0
            $record.login_to_caption_ms = ($m.load_caption_complete_drawn_idle.ticks_us - $m.login_input.ticks_us) / 1000.0
            $record.backup_dwell_ms = ($m.load_input.ticks_us - $m.backup_drawn_usable.ticks_us) / 1000.0
        } elseif ($Journey -in @('new_acc', 'apps')) {""")
    text = replace_once(text, "elseif ($Journey -eq 'screens') { @('title.png'", "elseif ($Journey -eq 'load') { @('title.png', 'backup.png', 'loaded-caption.png') } elseif ($Journey -eq 'screens') { @('title.png'")
    runner.write_text(text)
    hashes["load_runner_sha256"] = hashlib.sha256(runner.read_bytes()).hexdigest()
    (folder / "harness.json").write_text(json.dumps({"commit": DIAGNOSTIC, "sha256": hashes}, indent=2))


def prepare(root, harness):
    spec = importlib.util.spec_from_file_location("startup_attribution", harness / HARNESS[0])
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Baseline means an observation-only overlay on the both pinned sources.
    # Its replace_once and coroutine guards reject outdated instrumentation anchors.
    module.prepare(root, "baseline", trace_autoloads=True, trace_newacc=True)
    probe = root / "startup_probe.gd"
    text = probe.read_text()
    text = replace_once(text, '["baseline", "desktop"]', '["baseline", "candidate", "desktop"]')
    text = text.replace('(variant == "baseline")', '(variant in ["baseline", "candidate"])')
    text = replace_once(text, "func _begin_newacc_scope() -> bool:", 'func _begin_newacc_scope(scope: String = "exported_new_acc") -> bool:')
    text = replace_once(text, 'begin_scope("exported_new_acc", case_name, "button_to_caption", 0)', 'begin_scope(scope, case_name, "button_to_caption", 0)')
    text = replace_once(text, 'if journey == "screens":\n\t\tawait _screens(menu)', 'if journey == "load":\n\t\tawait _load_saved(menu)\n\telif journey == "screens":\n\t\tawait _screens(menu)')
    probe.write_text(text + LOAD_PROBE)
    receipt_path = root / "startup-variant.json"
    receipt = json.loads(receipt_path.read_text())
    receipt["newacc_probe_sha256"] = receipt["probe_sha256"]
    receipt["probe_sha256"] = hashlib.sha256(probe.read_bytes()).hexdigest()
    receipt["changes"]["startup_probe.gd"]["after"] = receipt["probe_sha256"]
    receipt_path.write_text(json.dumps(receipt, indent=2))


def numeric_leaves(value, prefix=""):
    """Keep individual inclusive counters/intervals; never add overlapping costs."""
    if isinstance(value, dict):
        for key, child in value.items():
            yield from numeric_leaves(child, f"{prefix}.{key}" if prefix else key)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from numeric_leaves(child, f"{prefix}[{index}]")
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        yield prefix, value


def summarize(folder):
    source = json.loads((folder / "source.json").read_text(encoding="utf-8-sig"))
    assert source["repetitions"] == 4 and source["observer"] == DIAGNOSTIC
    rows = []
    package_hashes = {}
    seed_hashes = None
    for repetition in range(1, 5):
        order = ("baseline", "candidate") if repetition % 2 else ("candidate", "baseline")
        for variant in order:
            fresh_hashes = None
            for case in ("fresh", "retained", "load"):
                name = f"r{repetition}-{variant}-{case}"
                run = folder / "measurements" / name
                report = json.loads((run / "results.json").read_text(encoding="utf-8-sig"))
                process = json.loads((run / "process.json").read_text(encoding="utf-8-sig"))
                assert report["complete"] and not report["failures"] and process["clean_exit"], name
                assert not process["timed_out"] and process["exit_code"] == 0, name
                assert process["status"] == "collected_requires_visual_review", name
                expected_case = "fresh" if case == "fresh" else "retained"
                journey = "load" if case == "load" else "new_acc"
                for record in (report, process):
                    assert record["variant"] == variant and record["case"] == expected_case and record["journey"] == journey, name
                assert not process["minimal"] and report["display_server"] != "headless", name
                assert process["package_hashes"], name
                if variant not in package_hashes: package_hashes[variant] = process["package_hashes"]
                assert process["package_hashes"] == package_hashes[variant], "Samples of each variant must use the same exported build"
                if case == "fresh":
                    assert not process["input_profile_hashes"] and process["preexisting_profile_files"] == 0, name
                    fresh_hashes = process["output_profile_hashes"]
                    assert fresh_hashes and any(k.replace("\\", "/").endswith("saves/autosave.json") for k in fresh_hashes), name
                    if repetition == 1 and variant == "baseline": seed_hashes = fresh_hashes
                else:
                    expected = fresh_hashes if case == "retained" else seed_hashes
                    assert process["input_profile_hashes"] == expected, f"{name}: complete input profile differs from its seed"
                logs = "\n".join((run / item).read_text(encoding="utf-8-sig", errors="replace")
                                 for item in ("stdout.log", "stderr.log", "render.log"))
                assert not re.search(r"SCRIPT ERROR:|^\s*ERROR:|Unicode parsing error|Unexpected NUL character", logs, re.M), name
                trace = report["autoload_trace"]
                assert [(t["owner"], t["event"]) for t in trace] == [(o, e) for o in OWNERS for e in ("begin", "end")], name
                assert all(b["ticks_us"] >= a["ticks_us"] for a, b in zip(trace, trace[1:])), name
                assert trace[-1]["ticks_us"] <= report["milestones"]["probe_enter_tree"]["ticks_us"], name
                profile = report["newacc_validation_profile"]
                assert report["trace_newacc"] and profile["ok"] and profile["inclusive_nested"], name
                assert profile["configuration_calls"] >= 1 and profile["compilation_calls"] >= 0, name
                observed = report["observation"]
                assert observed["line_id"] == "line.Day1.one" and observed["event_done"] and observed["active"] and observed["visible_ratio"] == 1.0, name
                labels = [item["label"] for item in report["inputs"]]
                expected_labels = ["login", "load"] if case == "load" else (["new_acc", "confirm"] if case == "retained" else ["new_acc"])
                assert labels == expected_labels, (name, labels)
                assert all(item[key] == 1 for item in report["inputs"] for key in ("pressed_count", "down_count", "up_count")), name
                if case == "load":
                    assert observed["ready_count"] == 1, name
                    assert all(observed[k] for k in ("gameplay_preserved", "scene_preserved", "reading_preserved", "autosave_preserved")), name
                    seed_autosaves = [v for k, v in seed_hashes.items() if k.replace("\\", "/").endswith("saves/autosave.json")]
                    assert seed_autosaves == [observed["source_autosave_sha256"]], name
                expected_images = {"title.png", "backup.png", "loaded-caption.png"} if case == "load" else {"title.png", "caption.png"}
                if case == "retained": expected_images.add("consent.png")
                assert {image["name"] for image in process["images"]} == expected_images, name
                for image in process["images"]:
                    data = (run / image["name"]).read_bytes()
                    assert len(data) == image["size"] and data and hashlib.sha256(data).hexdigest() == image["sha256"], name
                phases = report["phases"]
                assert sum(item["phase"] == "bootstrap.total" for item in phases) == 1 and all(item["ok"] for item in phases), name
                metrics = {"process." + k: v for k, v in process.items() if k.endswith("_ms") and not k.endswith("unix_ms")}
                if case == "load":
                    metrics["process.login_to_caption_excluding_dwell_ms"] = process["login_to_caption_ms"] - process["backup_dwell_ms"]
                else:
                    metrics["process.new_acc_excluding_consent_dwell_ms"] = process["new_acc_to_caption_complete_ms"] - process.get("consent_dwell_ms", 0)
                metrics.update({"frame_gap_us." + k: v for k, v in numeric_leaves(report["max_frame_gap_us"])})
                metrics.update({"validation." + k: v for k, v in numeric_leaves(profile)
                                if not k.endswith(("ordinal", "next_step_index"))})
                for index, owner in enumerate(OWNERS):
                    metrics[f"autoload.{owner}.elapsed_us"] = trace[index * 2 + 1]["ticks_us"] - trace[index * 2]["ticks_us"]
                occurrences = {}
                for phase in phases:
                    key = phase["phase"]
                    occurrence = occurrences.get(key, 0)
                    occurrences[key] = occurrence + 1
                    metrics[f"phase.{key}[{occurrence}].elapsed_us"] = phase["elapsed_us"]
                rows.append({"sample": name, "repetition": repetition, "variant": variant, "case": case, "metrics": metrics,
                             "input_profile_hashes": process["input_profile_hashes"], "output_profile_hashes": process["output_profile_hashes"],
                             "validation_profile": profile, "inclusive_phases": phases})
    aggregates = {}
    comparisons = []
    for variant in ("baseline", "candidate"):
        aggregates[variant] = {}
        for case in ("fresh", "retained", "load"):
            samples = [row for row in rows if row["case"] == case and row["variant"] == variant]
            aggregates[variant][case] = {}
            for key in sorted(set().union(*(row["metrics"] for row in samples))):
                raw = [{"sample": row["sample"], "value": row["metrics"][key]} for row in samples if key in row["metrics"]]
                values = [item["value"] for item in raw]
                aggregates[variant][case][key] = {"raw_samples": raw, "count": len(values), "median": median(values), "min": min(values), "max": max(values)}
    for repetition in range(1, 5):
        for case in ("fresh", "retained", "load"):
            matched = {row["variant"]: row for row in rows if row["case"] == case and row["repetition"] == repetition}
            comparisons.append({"repetition": repetition, "case": case, "candidate_minus_baseline": {
                key: matched["candidate"]["metrics"][key] - value
                for key, value in matched["baseline"]["metrics"].items()
                if key in matched["candidate"]["metrics"]}})
    result = {"scope": "Twenty-four instrumented exported journeys on one Windows runner, four repetitions in AB/BA/AB/BA order. Fresh means empty user data, not cold OS caches; retained New Acc uses its own fresh output; every Load uses the same r1-baseline-fresh profile. Inclusive costs overlap and must not be summed. Screenshot hashes establish integrity; visual review remains required. Four samples per variant/case are descriptive, not statistical certainty.",
              "source": source, "package_hashes": package_hashes, "load_seed_profile_hashes": seed_hashes,
              "samples": rows, "aggregates": aggregates, "paired_differences": comparisons}
    (folder / "summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"samples": len(rows), "summary": "summary.json"}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "prepare", "summarize"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.action == "extract": extract(args.root)
    elif args.action == "prepare": prepare(args.root, args.harness)
    else: summarize(args.root)
