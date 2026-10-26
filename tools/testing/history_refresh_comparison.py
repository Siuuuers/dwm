"""Attribute caption refresh costs on identical exported observation overlays.

The inherited matched harness retains its complete Load/first-Accept checks.
Additional sequential reading stops before the first authored choice.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
from statistics import median

import trusted_runtime_comparison as trusted

BASELINE = "1592d62f9f68b02e1c0778ca083bfb8115272319"

HISTORY_PROBE = r'''
var history_scope := ""
var history_samples := {}

func history_finish(name: String, began: int) -> void:
	if history_scope.is_empty(): return
	if not history_samples.has(history_scope): history_samples[history_scope] = {}
	var scope: Dictionary = history_samples[history_scope]
	if not scope.has(name): scope[name] = {"calls": 0, "elapsed_us": 0, "max_us": 0}
	var row: Dictionary = scope[name]
	var elapsed := Time.get_ticks_usec() - began
	row.calls += 1
	row.elapsed_us += elapsed
	row.max_us = maxi(row.max_us, elapsed)

func _history_reading_sequence(caption: Node, bridge: Node, run_id: String) -> bool:
	var sequence: Array[Dictionary] = []
	var native: Node = caption.caption_text
	var inputs: Node = bridge._runtime_adapter._dialogic.get_subsystem("Inputs")
	var locale: String = get_node("/root/LocalizationManager").get_locale()
	var catalog: Dictionary = load("res://scripts/localization/StoryLocalization.gd").catalog(locale)
	var english: Dictionary = load("res://scripts/localization/StoryLocalization.gd").catalog("en")
	for number: int in range(3, 31):
		# Natural reveal completion is outside the input-to-drawing interval.
		# No synthetic publication, reveal shortcut, or checkpoint fabrication.
		var deadline := Time.get_ticks_msec() + 30000
		while Time.get_ticks_msec() < deadline:
			var event: Resource = bridge._runtime_adapter._current_skip_text(true)
			if event != null and int(event.get("state")) == 2 and not native.revealing \
					and native.visible_ratio == 1.0 and not inputs.is_input_blocked() \
					and bridge.is_current_line_presentation_acknowledged(): break
			await get_tree().process_frame
		if not _check(Time.get_ticks_msec() < deadline, "sequential caption never became ready"): return false
		var expected := "line.Day1.%03d" % number
		caption.caption_text.grab_focus()
		if not _check(caption.caption_text.has_focus(), "sequential caption lost Accept focus"): return false
		history_scope = "accept_%03d" % number
		gap_scope = history_scope
		previous_frame_us = Time.get_ticks_usec()
		var began := Time.get_ticks_usec()
		for pressed: bool in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
			key.pressed = pressed
			get_viewport().push_input(key, true)
			await get_tree().process_frame
		while Time.get_ticks_msec() < deadline:
			if bridge._runtime_adapter.current_line_id() == expected and native.visible_ratio > 0.0:
				break
			await get_tree().process_frame
		if not _check(Time.get_ticks_msec() < deadline, "sequential Accept did not advance to " + expected): return false
		await RenderingServer.frame_post_draw
		var drawn := Time.get_ticks_usec()
		if not _check(native.get_parsed_text() == catalog.get(expected, english.get(expected, "")), "sequential caption differs from authored text"): return false
		# Include deferred refreshes after drawing; no snapshots or hashing here.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		sequence.append({"line_id": expected, "input_to_observed_drawing_us": drawn - began,
			"press_count": 1, "release_count": 1})
		history_scope = ""
		gap_scope = ""
	# Validate the genuinely encountered history after all timed actions.
	var history: Dictionary = bridge.get_reading_history()
	if not _check(history.get("ok", false) and history.value.captions.size() == 30, "sequential History did not retain exactly 30 encounters"): return false
	for index: int in range(30):
		var expected := FIRST_LINE if index == 0 else "line.Day1.%03d" % (index + 1)
		if not _check(history.value.captions[index].line_id == expected, "sequential History order changed"): return false
	if not _check(get_node("/root/GameState").capture_live_session().value.run_id == run_id, "sequential reading changed Run"): return false
	observation["history_sequence"] = sequence
	observation["history_encounters"] = 30
	return true
'''


def wrap(text, owner, names):
    """Synchronous, typed wrappers; boolean refusals are observations, not errors."""
    for name in names:
        match = re.search(r"^(?:static )?func " + re.escape(name) + r"\(([^)]*)\) -> (Dictionary|bool|void):\n", text, re.M)
        if not match:
            raise ValueError(f"Missing synchronous seam {owner}.{name}")
        header, arguments, returns = match.group(0), match.group(1), match.group(2)
        body = re.split(r"\n(?:static )?func ", text[match.end():], maxsplit=1)[0]
        if re.search(r"\bawait\b", body):
            raise ValueError(f"Cannot wrap async seam {owner}.{name}")
        params = ", ".join(part.strip().split(":", 1)[0] for part in arguments.split(",") if part.strip())
        internal = "_history_body_" + name.lstrip("_")
        call = f"{internal}({params})"
        wrapper = header + '\tvar history_began := Time.get_ticks_usec()\n'
        wrapper += f"\t{call}\n" if returns == "void" else f"\tvar history_result: {returns} = {call}\n"
        wrapper += ('\tvar history_probe: Node = (Engine.get_main_loop() as SceneTree).root.get_node("StartupProbe")\n'
                    f'\thistory_probe.history_finish("{owner}.{name}", history_began)\n')
        if returns != "void":
            wrapper += "\treturn history_result\n"
        wrapper += "\n" + header.replace("func " + name + "(", "func " + internal + "(", 1)
        text = trusted.replace_once(text, header, wrapper)
    return text


def span(text, start, end, name):
    """Measure an existing straight-line sub-block without extracting production helpers."""
    tag = re.sub(r"\W", "_", name)
    text = trusted.replace_once(text, start, f"\tvar history_{tag}_began := Time.get_ticks_usec()\n" + start)
    return trusted.replace_once(text, end, end +
        f'\t(Engine.get_main_loop() as SceneTree).root.get_node("StartupProbe").history_finish("{name}", history_{tag}_began)\n')


def prepare(root, harness):
    trusted.prepare(root, harness)
    receipt_path = root / "startup-variant.json"
    receipt = json.loads(receipt_path.read_text())

    def edit(relative, transform):
        path = root / relative
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        path.write_text(transform(path.read_text()), encoding="utf-8")
        receipt["changes"].setdefault(relative, {"before": before})["after"] = hashlib.sha256(path.read_bytes()).hexdigest()

    for relative, names in {
        "scripts/ui/witnessed/WitnessedCaptionLayer.gd": (
            "_on_reading_session_changed", "_on_reading_input_custody_changed", "_refresh_reading_session",
            "_project_scene_caption_memory", "reproject_retained_captions"),
        "autoload/DialogicBridge.gd": ("get_scene_caption_memory",),
        "scripts/narrative/SoloReadingSession.gd": (
            "project_scene_day_history", "_capture_scene", "_validate_scene_saved", "_ensure_scene_programme"),
        "scripts/narrative/SceneReadingHistory.gd": ("project_encountered",),
        "scripts/localization/StoryLocalization.gd": ("project",),
    }.items():
        edit(relative, lambda text, owner=Path(relative).stem, names=names: wrap(text, owner, names))
    edit("scripts/narrative/SoloReadingSession.gd", lambda text: span(text,
        '\tvar retained: Dictionary = ledger.snapshot()\n', '\tvar retained: Dictionary = ledger.snapshot()\n', "Capture.ledger_snapshot_copy"))
    edit("scripts/narrative/SoloReadingSession.gd", lambda text: span(text,
        '\tvar saved := {"schema_version": 5, "registration_sha256": fingerprint, "entry_id": latest_entry,\n',
        '\t\t"ledger": retained, "frontier": frontier.duplicate(true), "player_progress": player_progress.duplicate(true),\n'
        '\t\t"next_operation": null if next_operation.is_empty() else next_operation.duplicate(true)}\n', "Capture.saved_fields_copy"))
    edit("scripts/narrative/SceneReadingHistory.gd", lambda text: span(text,
        '\tvar lines := {}\n', '\t\t\tlines[line.line_id] = {"entry_id": entry.entry_id, "line": line}\n',
        "History.registry_lookup"))
    edit("scripts/localization/StoryLocalization.gd", lambda text: span(text,
        '\tvar copy := result.duplicate(true)\n', '\tvar copy := result.duplicate(true)\n', "Localization.copy"))
    edit("scripts/ui/witnessed/WitnessedCaptionLayer.gd", lambda text: span(text,
        '\t_scene_caption_memory = memory.duplicate(true)\n', '\t_scene_caption_memory = memory.duplicate(true)\n', "Caption.memory_copy"))

    def probe(text):
        text = trusted.replace_once(text, '\t\t_load_first_draw_session = get_node("/root/GameState").capture_live_session().value\n',
            '\t\tvar first_draw_observer_began := Time.get_ticks_usec()\n'
            '\t\t_load_first_draw_session = get_node("/root/GameState").capture_live_session().value\n'
            '\t\thistory_finish("Observer.first_draw_session", first_draw_observer_began)\n')
        text = trusted.replace_once(text, '\t_load_draw_watch = true\n', '\thistory_scope = "load"\n\t_load_draw_watch = true\n')
        text = trusted.replace_once(text, '\tvar current: Dictionary = game.capture_run_snapshot_input()\n',
            '\thistory_scope = "observer_capture"\n\tgap_scope = "observer_capture"\n\tprevious_frame_us = Time.get_ticks_usec()\n'
            '\tvar observer_began := Time.get_ticks_usec()\n\tvar current: Dictionary = game.capture_run_snapshot_input()\n')
        text = trusted.replace_once(text, '\tvar input_caption: Node = get_node("/root/SceneRouter")._production_pause._find_caption(get_tree().root)\n',
            '\thistory_finish("Observer.capture_and_hash", observer_began)\n\thistory_scope = "input_readiness"\n'
            '\tgap_scope = "input_readiness"\n\tprevious_frame_us = Time.get_ticks_usec()\n'
            '\tvar input_caption: Node = get_node("/root/SceneRouter")._production_pause._find_caption(get_tree().root)\n')
        text = trusted.replace_once(text, '\tmark("load_next_input")\n',
            '\thistory_scope = "first_accept"\n\tgap_scope = "first_accept"\n\tprevious_frame_us = Time.get_ticks_usec()\n\tmark("load_next_input")\n')
        text = trusted.replace_once(text, '\tmark("load_post_input_observation_complete")\n',
            '\tmark("load_post_input_observation_complete")\n\thistory_scope = ""\n')
        post_draw_check = ('\tif not _check(game.capture_live_session().value.active and game.capture_run_snapshot_input().lifecycle.run_id == saved.lifecycle.run_id,\n'
            '\t\t"first Accept acted on a different Run"): return\n')
        text = trusted.replace_once(text, post_draw_check, "")
        text = trusted.replace_once(text, '\tif not _check(current.lifecycle.run_id == saved.lifecycle.run_id, "Load changed run identity"): return\n',
            post_draw_check + '\tif not _check(current.lifecycle.run_id == saved.lifecycle.run_id, "Load changed run identity"): return\n')
        text = trusted.replace_once(text, '\tif not await _save_after_measurement("slot:2", "line.Day1.002"): return\n',
            '\tif not await _history_reading_sequence(input_caption, bridge, saved.lifecycle.run_id): return\n'
            '\tobservation["history_profile"] = history_samples.duplicate(true)\n'
            '\tif not await _save_after_measurement("slot:2", "line.Day1.030"): return\n')
        return text + HISTORY_PROBE

    edit("startup_probe.gd", probe)
    receipt["probe_sha256"] = receipt["changes"]["startup_probe.gd"]["after"]
    receipt["history_observer"] = "Scoped synchronous inclusive spans; no runtime optimization in overlay."
    receipt_path.write_text(json.dumps(receipt, indent=2), encoding="utf-8")


def summarize(root):
    trusted.summarize(root)
    source = json.loads((root / "source.json").read_text(encoding="utf-8-sig"))
    assert source["baseline"] == BASELINE
    samples = []
    for repetition in range(1, 5):
        for variant in ("baseline", "candidate"):
            name = f"r{repetition}-{variant}-load"
            report = json.loads((root / "measurements" / name / "results.json").read_text(encoding="utf-8-sig"))
            observation = report["observation"]
            assert observation["history_encounters"] == 30
            sequence = observation["history_sequence"]
            assert [row["line_id"] for row in sequence] == [f"line.Day1.{number:03}" for number in range(3, 31)]
            assert all(row["press_count"] == row["release_count"] == 1 for row in sequence)
            profile = observation["history_profile"]
            assert profile["load"]["WitnessedCaptionLayer._refresh_reading_session"]["calls"] > 0
            assert profile["observer_capture"]["Observer.capture_and_hash"]["calls"] == 1
            # The synchronous wrappers only record methods that execute. Ordinary
            # text publication appends local scrollback and can legitimately make
            # no refresh request or History projection. Keep those zeros visible.
            assert profile["first_accept"]["SoloReadingSession._capture_scene"]["calls"] > 0
            metrics = dict(trusted.numeric_leaves(profile))
            for scope in ("load", "first_accept", *(f"accept_{number:03}" for number in range(3, 31))):
                for method in ("_on_reading_session_changed", "_on_reading_input_custody_changed",
                               "_refresh_reading_session", "_project_scene_caption_memory"):
                    for field in ("calls", "elapsed_us", "max_us"):
                        metrics.setdefault(f"{scope}.WitnessedCaptionLayer.{method}.{field}", 0)
            for row in sequence:
                metrics[row["line_id"] + ".input_to_observed_drawing_us"] = row["input_to_observed_drawing_us"]
            metrics.update({"frame_gap_us." + key: value for key, value in trusted.numeric_leaves(report["max_frame_gap_us"])})
            samples.append({"sample": name, "variant": variant, "repetition": repetition, "metrics": metrics})
    aggregates = {}
    for variant in ("baseline", "candidate"):
        rows = [sample["metrics"] for sample in samples if sample["variant"] == variant]
        aggregates[variant] = {key: {"samples": values, "median": median(values), "min": min(values), "max": max(values)}
            for key in sorted(set().union(*rows))
            if (values := [row.get(key, 0) for row in rows])}
    result = {"scope": "Four matched Load samples per variant, AB/BA/AB/BA on one Windows runner. Request callbacks, refresh executions and History projections are counted separately. Observer capture/hash is outside first-Accept frame scope and separately timed; inherited complete Load-to-response latencies remain observer-inclusive. Lightweight first-draw session capture is separately timed inside Load. Polling, text checks and matched counter bookkeeping still contribute observer overhead to frame intervals. Next 28 natural reading actions grow genuine History to 30 captions; each waits native completion before one real press/release. Observed drawing intervals can include one observation frame. Spans are inclusive and overlap; do not sum nested costs. No uncompiled passage, choice, board, locale change or long-history saved Load is timed. Screenshots retain the inherited first-Accept view before subsequent reading. Natural reveal waits are outside each subsequent input interval. Four samples are descriptive, not a device guarantee.",
        "source": source, "samples": samples, "aggregates": aggregates}
    (root / "history-summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"history_samples": len(samples), "summary": "history-summary.json"}))
    review = {}
    for variant, metrics in aggregates.items():
        review[variant] = {key: value for key, value in metrics.items()
            if (key.startswith(("load.WitnessedCaptionLayer.", "first_accept.WitnessedCaptionLayer.",
                                "accept_030.WitnessedCaptionLayer.")) and key.endswith((".calls", ".elapsed_us")))
            or key in ("observer_capture.Observer.capture_and_hash.elapsed_us",
                       "line.Day1.003.input_to_observed_drawing_us", "line.Day1.030.input_to_observed_drawing_us",
                       "frame_gap_us.first_accept", "frame_gap_us.accept_030")}
    print(json.dumps({"history_review": review}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("extract", "prepare", "summarize"))
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--harness", type=Path)
    args = parser.parse_args()
    if args.action == "extract": trusted.extract(args.root)
    elif args.action == "prepare": prepare(args.root, args.harness)
    else: summarize(args.root)
