"""Measure the first new authored passage after genuine sequential reading.

This adds observation only. Both variants retain the same native input journey.
Set BASELINE and the matching workflow SHA to the accepted capture candidate.
"""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import median

import history_refresh_comparison as history

BASELINE = "211192562d7be919d0dfd65714153e5199762f29"

PASSAGE_PROBE = r'''
const PASSAGE_ENTRY := "Day1.photo.default"
const PASSAGE_LINE := "line.Day1.photo.default.001"
const PASSAGE_PATH := "res://dialogic/timelines/authored_week/Day1.dtl"
var _passage_drawing_watch := false
var _passage_expected_text := ""

func _passage_caption() -> Node:
	return get_node("/root/SceneRouter")._production_pause._find_caption(get_tree().root)

func _observe_passage_drawing() -> void:
	if not _passage_drawing_watch or milestones.has("passage_first_correct_drawn"): return
	var caption: Node = _passage_caption()
	var bridge: Node = get_node("/root/DialogicBridge")
	if not is_instance_valid(caption) or not caption.caption_text.is_visible_in_tree(): return
	if bridge._runtime_adapter.current_line_id() == PASSAGE_LINE and caption.caption_text.visible_ratio > 0.0 \
			and caption.caption_text.get_parsed_text() == _passage_expected_text:
		mark("passage_first_correct_drawn")

func _passage_wait_ready(line_id: String) -> bool:
	var bridge: Node = get_node("/root/DialogicBridge")
	var inputs: Node = bridge._runtime_adapter._dialogic.get_subsystem("Inputs")
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var caption: Node = _passage_caption()
		var event: Resource = bridge._runtime_adapter._current_skip_text(true)
		if is_instance_valid(caption) and bridge._runtime_adapter.current_line_id() == line_id \
				and event != null and int(event.get("state")) == 2 and not caption.caption_text.revealing \
				and caption.caption_text.visible_ratio == 1.0 and caption.caption_text.is_visible_in_tree() \
				and not inputs.is_input_blocked() and bridge.is_current_line_presentation_acknowledged():
			await RenderingServer.frame_post_draw
			return true
		await get_tree().process_frame
	return _check(false, "passage caption never became usable: " + line_id)

func _passage_accept() -> bool:
	var caption: Node = _passage_caption()
	caption.caption_text.grab_focus()
	if not _check(caption.caption_text.has_focus(), "passage Accept requires caption focus"): return false
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		get_viewport().push_input(key, true)
		await get_tree().process_frame
	return true

func _passage_transition(run_id: String) -> bool:
	var bridge: Node = get_node("/root/DialogicBridge")
	if not await _passage_wait_ready("line.Day1.030"): return false
	if not await _passage_accept(): return false
	if not await _passage_wait_ready("line.Day1.031"): return false
	var adapter := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
	if not _check(not adapter._scene_runtime_programmes.has(PASSAGE_ENTRY), "destination runtime programme was already warm"): return false
	var strict_cached := false
	for path: String in adapter._scene_compile_cache:
		for result: Dictionary in adapter._scene_compile_cache[path].results.values():
			if result.value.label_nodes.has(PASSAGE_ENTRY): strict_cached = true
	if not _check(not strict_cached, "destination strict programme was already warm"): return false
	var day_parse_ready: bool = adapter._scene_runtime_parsed_sources.has(PASSAGE_PATH)
	if not _check(day_parse_ready, "current day parse was not available before transition"): return false
	var locale: String = get_node("/root/LocalizationManager").get_locale()
	var texts := preload("res://scripts/localization/StoryLocalization.gd")
	_passage_expected_text = texts.catalog(locale).get(PASSAGE_LINE, texts.catalog("en").get(PASSAGE_LINE, ""))
	if not _check(not _passage_expected_text.is_empty(), "destination text missing from authored catalog"): return false
	# All cache inspection and translation lookup end before the timed action.
	_passage_drawing_watch = true
	RenderingServer.frame_post_draw.connect(_observe_passage_drawing)
	history_scope = "passage_transition"
	gap_scope = "passage_transition"
	previous_frame_us = Time.get_ticks_usec()
	mark("passage_input")
	if not await _passage_accept(): return false
	if not await _passage_wait_ready(PASSAGE_LINE): return false
	mark("passage_usable")
	if not _check(milestones.has("passage_first_correct_drawn"), "destination was usable without first correct drawing"): return false
	var observe_until: int = Time.get_ticks_usec() + 1000000
	while Time.get_ticks_usec() < observe_until:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	mark("passage_observation_complete")
	history_scope = ""
	gap_scope = ""
	_passage_drawing_watch = false
	RenderingServer.frame_post_draw.disconnect(_observe_passage_drawing)
	# State inspection, PNG readback, hashing and Save are outside timing.
	var game: Node = get_node("/root/GameState")
	var snapshot: Dictionary = game.capture_run_snapshot_input()
	if not _check(game.capture_live_session().value.active and snapshot.lifecycle.run_id == run_id, "passage transition changed Run"): return false
	if not _check(snapshot.gameplay.scene_choices.get("Day1.photo") == "pass", "ordinary caption Accept selected a different photograph route"): return false
	var encountered: Dictionary = bridge.get_reading_history()
	if not _check(encountered.get("ok", false), "passage History unavailable"): return false
	for row: Dictionary in encountered.value.captions:
		if not _check(not str(row.line_id).begins_with("line.Day1.photo.yes."), "unselected yes route entered History"): return false
	if not _check(encountered.value.captions.back().line_id == PASSAGE_LINE, "passage History lacks destination"): return false
	if not _check(bridge._reading_session.latest_entry == PASSAGE_ENTRY and adapter._scene_runtime_programmes.has(PASSAGE_ENTRY), "destination programme was not installed"): return false
	if not _check(DirAccess.make_dir_recursive_absolute(folder.path_join("passage")) == OK, "passage image directory unavailable"): return false
	if not _capture("passage/destination"): return false
	observation["passage"] = {"entry_id": PASSAGE_ENTRY, "line_id": PASSAGE_LINE,
		"runtime_cache_was_absent": true, "strict_cache_was_absent": true, "day_parse_was_ready": day_parse_ready,
		"same_run": true, "choice": "pass", "no_yes_encounters": true, "press_count": 1, "release_count": 1,
		"image": "passage/destination.png", "image_sha256": FileAccess.get_sha256(folder.path_join("passage/destination.png"))}
	return true
'''


def prepare(root, harness):
    history.prepare(root, harness)
    receipt_path = root / "startup-variant.json"
    receipt = json.loads(receipt_path.read_text())

    def edit(relative, transform):
        path = root / relative
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        path.write_text(transform(path.read_text()), encoding="utf-8")
        receipt["changes"].setdefault(relative, {"before": before})["after"] = hashlib.sha256(path.read_bytes()).hexdigest()

    def adapter(text):
        text = history.wrap(text, "DialogicRuntimeAdapter", (
            "compile_scene_programme", "compile_runtime_scene_programme",
            "_compile_scene_programme_observed_body", "_compile_scene_programme_timeline"))
        text = history.span(text, '\tvar source := FileAccess.open(path, FileAccess.READ)\n',
                            '\tsource.close()\n', "Compiler.file_read")
        text = history.span(text, '\tvar timeline := DialogicTimeline.new()\n\ttimeline.from_text(text)\n',
                            '\ttimeline.process()\n', "Compiler.parse_source")
        for anchor, metric in (
            ('\tif cacheable and _scene_runtime_programmes.has(entry_label):\n', "Compiler.runtime_cache_hit"),
            ('\tif cacheable and cached.results.has(key):\n', "Compiler.strict_cache_hit"),
            ('\tif cacheable and not parsed_sources.has(path) and _scene_runtime_parsed_sources.has(path):\n', "Compiler.shared_parse_hit"),
        ):
            text = history.trusted.replace_once(text, anchor, anchor +
                '\t\t(Engine.get_main_loop() as SceneTree).root.get_node("StartupProbe").history_finish('
                f'"{metric}", Time.get_ticks_usec())\n')
        return text

    edit("scripts/narrative/DialogicRuntimeAdapter.gd", adapter)
    edit("autoload/DialogicBridge.gd", lambda text: history.wrap(text, "DialogicBridge", ("_prepare_scene_entry",)))

    def probe(text):
        text = history.trusted.replace_once(text, '\tobservation["history_profile"] = history_samples.duplicate(true)\n',
            '\tif not await _passage_transition(saved.lifecycle.run_id): return\n'
            '\tobservation["history_profile"] = history_samples.duplicate(true)\n')
        text = history.trusted.replace_once(text, '\tif not await _save_after_measurement("slot:2", "line.Day1.030"): return\n',
            '\tif not await _save_after_measurement("slot:2", "line.Day1.photo.default.001"): return\n')
        return text + PASSAGE_PROBE

    edit("startup_probe.gd", probe)
    receipt["probe_sha256"] = receipt["changes"]["startup_probe.gd"]["after"]
    receipt["passage_observer"] = "First uncached authored passage after natural real-input sequential reading; inclusive synchronous compiler spans."
    receipt_path.write_text(json.dumps(receipt, indent=2), encoding="utf-8")


def summarize(root):
    history.BASELINE = BASELINE
    history.summarize(root)
    samples = []
    for repetition in range(1, 5):
        for variant in ("baseline", "candidate"):
            name = f"r{repetition}-{variant}-load"
            folder = root / "measurements" / name
            report = json.loads((folder / "results.json").read_text(encoding="utf-8-sig"))
            observed = report["observation"]["passage"]
            assert observed["entry_id"] == "Day1.photo.default" and observed["line_id"] == "line.Day1.photo.default.001"
            assert all(observed[key] for key in ("runtime_cache_was_absent", "strict_cache_was_absent", "day_parse_was_ready", "same_run", "no_yes_encounters"))
            assert observed["choice"] == "pass" and observed["press_count"] == observed["release_count"] == 1
            image = folder / observed["image"]
            assert image.is_file() and image.stat().st_size > 0
            assert hashlib.sha256(image.read_bytes()).hexdigest() == observed["image_sha256"]
            marks = report["milestones"]
            ticks = {key: marks[key]["ticks_us"] for key in ("passage_input", "passage_first_correct_drawn", "passage_usable", "passage_observation_complete")}
            assert ticks["passage_input"] <= ticks["passage_first_correct_drawn"] <= ticks["passage_usable"]
            assert ticks["passage_observation_complete"] - ticks["passage_usable"] >= 1000000
            metrics = dict(history.trusted.numeric_leaves(report["observation"]["history_profile"].get("passage_transition", {})))
            metrics["input_to_first_correct_drawn_us"] = ticks["passage_first_correct_drawn"] - ticks["passage_input"]
            metrics["input_to_usable_us"] = ticks["passage_usable"] - ticks["passage_input"]
            metrics["max_frame_gap_us"] = report["max_frame_gap_us"].get("passage_transition", 0)
            samples.append({"sample": name, "variant": variant, "repetition": repetition, "metrics": metrics,
                            "observation": observed})
    keys = sorted(set().union(*(sample["metrics"] for sample in samples)))
    aggregates = {}
    for variant in ("baseline", "candidate"):
        rows = [sample["metrics"] for sample in samples if sample["variant"] == variant]
        aggregates[variant] = {key: {"samples": values, "median": median(values), "min": min(values), "max": max(values)}
            for key in keys if (values := [row.get(key, 0) for row in rows])}
    result = {"scope": "Four matched first-new-passage transitions per variant after 31 real encountered source captions. Destination absent from both runtime and strict semantic caches; same day parse already available. Native caption Enter selects the existing pass route. First correct drawing uses frame_post_draw; usable requires natural complete reveal and input readiness. One additional elapsed second is observed after usability. Cache inspection, full state checks, PNG encoding and hashes are outside timed intervals. Polling and lightweight observer wrappers remain inside; costs are inclusive and overlap. Missing synchronous counter means zero calls. Same runner and identical overlay, AB/BA/AB/BA; no cold OS-cache claim or device-wide guarantee. Nested destination PNGs require visual review in addition to integrity checks.",
        "baseline": BASELINE, "samples": samples, "aggregates": aggregates}
    (root / "passage-summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"passage_review": aggregates}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "prepare", "summarize"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.action == "extract": history.trusted.extract(args.root)
    elif args.action == "prepare": prepare(args.root, args.harness)
    else: summarize(args.root)
