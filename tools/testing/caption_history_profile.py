import sys
from pathlib import Path
root = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(root / 'tools/testing'))
from history_refresh_comparison import wrap
seams = {
    'scripts/ui/witnessed/WitnessedCaptionLayer.gd': ['_refresh_reading_session', '_project_scene_caption_memory', '_acknowledge_visible_line'],
    'autoload/DialogicBridge.gd': ['get_scene_caption_memory', '_record_line_presentation'],
    'scripts/narrative/SoloReadingSession.gd': ['project_scene_day_history', '_capture_scene'],
    'scripts/narrative/SceneReadingHistory.gd': ['project_encountered'],
    'autoload/ProfileManager.gd': ['mark_caption_variant_witnessed', 'merge_caption_history', '_commit_profile_candidate', '_persist_candidate'],
}
for relative, names in seams.items():
    path = root / relative
    text = wrap(path.read_text(), Path(relative).stem, names)
    text = text.replace('root.get_node("StartupProbe")', 'root.get_node_or_null("DialogicBridge")')
    text = text.replace('\thistory_probe.history_finish(', '\tif history_probe != null: history_probe.history_finish(')
    path.write_text(text)
path = root / 'autoload/DialogicBridge.gd'
with path.open('a') as f:
    f.write('''
var history_active := false
var history_samples := {}

func history_finish(name: String, began: int) -> void:
	if not history_active: return
	var elapsed := Time.get_ticks_usec() - began
	if not history_samples.has(name): history_samples[name] = {"calls": 0, "elapsed_us": 0}
	history_samples[name].calls += 1
	history_samples[name].elapsed_us += elapsed
''')
path = root / 'tests/integration/authored_week_child.gd'
text = path.read_text()
start = '\t\tvar started := Time.get_ticks_msec()\n'
assert text.count(start) == 1
text = text.replace(start, '\t\tbridge.history_samples = {}\n\t\tbridge.history_active = true\n' + start)
end = '\t\t\t"elapsed_ms": Time.get_ticks_msec() - started})\n'
assert text.count(end) == 1
text = text.replace(end, end + '\t\tbridge.history_active = false\n\t\t_timings.back()["costs"] = bridge.history_samples.duplicate(true)\n')
path.write_text(text)
print('Caption profiling overlay installed')
