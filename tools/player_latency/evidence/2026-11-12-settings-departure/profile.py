from pathlib import Path
import subprocess
paths=['scripts/ui/SceneHost.gd','scripts/ui/SettingsPanelController.gd'];saved={p:Path(p).read_text() for p in paths}
try:
 p=Path(paths[0]);s=saved[str(p)];s=s.replace('func set_computer_open(open: bool) -> void:', '''func set_computer_open(open: bool) -> void:
	var started := Time.get_ticks_usec()
	var repeated := _computer_open == open
	_profiled_set_computer_open(open)
	print("SPAN computer " + str(repeated) + " " + str(Time.get_ticks_usec() - started))

func _profiled_set_computer_open(open: bool) -> void:''');p.write_text(s)
 p=Path(paths[1]);s=saved[str(p)];s=s.replace('func refresh() -> void:', '''func refresh() -> void:
	var started := Time.get_ticks_usec()
	_profiled_refresh()
	print("SPAN settings " + str(_content.is_visible_in_tree()) + " " + str(Time.get_ticks_usec() - started))

func _profiled_refresh() -> void:''');p.write_text(s)
 subprocess.run(['python','.godot/ci/settings-open/run.py','profile'],check=True)
finally:
 for p,s in saved.items():Path(p).write_text(s)
