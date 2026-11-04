"""Install synchronous transition observations in an isolated checkout."""
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(root / "tools/testing"))
from history_refresh_comparison import wrap

seams = {
    "autoload/GameState.gd": ["advance_scene_registered_marker", "_accept_scene_end",
        "_admit_scene_target_owned", "_commit_scene_target_owned"],
    "autoload/DialogicBridge.gd": ["_prepare_scene_entry", "_commit_scene_entry",
        "_adopt_scene_target", "_record_line_presentation", "_clear_scene_transition"],
    "scripts/narrative/DialogicRuntimeAdapter.gd": ["install_scene_target",
        "_start_held_scene_target", "_finish_reading_restore"],
    "autoload/ProfileManager.gd": ["_persist_candidate"],
    "scripts/narrative/SoloReadingSession.gd": ["_capture_scene"],
    "scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd": [
        "commit_scene_event", "retain_scene_entry", "consume_scene_entry_ack",
        "_commit_scene_event_autosave"],
}
edits = {}
for relative, names in seams.items():
    text = wrap((root / relative).read_text(), Path(relative).stem, names)
    text = text.replace('root.get_node("StartupProbe")', 'root.get_node_or_null("DialogicBridge")')
    text = text.replace('\thistory_probe.history_finish(', '\tif history_probe != null: history_probe.history_finish(')
    edits[relative] = text

edits["autoload/DialogicBridge.gd"] += '''
var history_active := false
var history_samples := {}
var history_spans: Array[Dictionary] = []
var history_origin_us := 0

func history_finish(name: String, began: int) -> void:
	if not history_active: return
	var ended := Time.get_ticks_usec()
	var elapsed := ended - began
	if not history_samples.has(name): history_samples[name] = {"calls": 0, "elapsed_us": 0}
	history_samples[name].calls += 1
	history_samples[name].elapsed_us += elapsed
	history_spans.append({"name": name, "start_us": began - history_origin_us,
		"end_us": ended - history_origin_us, "elapsed_us": elapsed})
'''
relative = "tests/integration/authored_week_child.gd"
text = (root / relative).read_text()
start = '\t\tvar started := Time.get_ticks_msec()\n'
assert text.count(start) == 1
text = text.replace(start, '\t\tbridge.history_samples = {}\n\t\tbridge.history_spans.clear()\n'
    '\t\tbridge.history_origin_us = Time.get_ticks_usec()\n\t\tbridge.history_active = true\n' + start)
end = '\t\t\t"elapsed_ms": Time.get_ticks_msec() - started})\n'
assert text.count(end) == 1
text = text.replace(end, end + '\t\tbridge.history_active = false\n'
    '\t\t_timings.back()["costs"] = bridge.history_samples.duplicate(true)\n'
    '\t\t_timings.back()["spans"] = bridge.history_spans.duplicate(true)\n')
edits[relative] = text
if "--check" not in sys.argv[2:]:
    for relative, text in edits.items():
        (root / relative).write_text(text)
print("Transition overlay checked" if "--check" in sys.argv[2:] else "Transition overlay installed")
print("Synchronous spans use relative microseconds; nested durations are inclusive, not additive.")
