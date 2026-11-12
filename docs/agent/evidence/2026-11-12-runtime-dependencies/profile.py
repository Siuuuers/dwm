from pathlib import Path
import subprocess
p=Path('autoload/StartupLoader.gd');old=p.read_text()
try:
 s=old.replace('var _phase := &"idle"','var _phase := &"idle"\nvar _profile_request_us := 0')
 s=s.replace('var instance: Node = script.new()','var start := Time.get_ticks_usec()\n\tvar instance: Node = script.new()\n\tprint("STARTUP_SPAN new ", owner, " ", Time.get_ticks_usec() - start)\n\tstart = Time.get_ticks_usec()').replace('get_tree().root.add_child(instance)','get_tree().root.add_child(instance)\n\tprint("STARTUP_SPAN attach ", owner, " ", Time.get_ticks_usec() - start)')
 s=s.replace('_loaded[_active] = ResourceLoader.load_threaded_get(_active)','print("STARTUP_SPAN request ", _active, " ", Time.get_ticks_usec() - _profile_request_us)\n\t\t\t_loaded[_active] = ResourceLoader.load_threaded_get(_active)')
 s=s.replace('if ResourceLoader.load_threaded_request(_active) != OK:','_profile_request_us = Time.get_ticks_usec()\n\t\tif ResourceLoader.load_threaded_request(_active) != OK:')
 s=s.replace('var prepared: Dictionary = _bootstrap.prepare_runtime()','var start := Time.get_ticks_usec()\n\t\t\t\t\tvar prepared: Dictionary = _bootstrap.prepare_runtime()\n\t\t\t\t\tprint("STARTUP_SPAN prepare ", Time.get_ticks_usec() - start)')
 s=s.replace('var result: Dictionary = _bootstrap.advance_runtime()','var start := Time.get_ticks_usec()\n\t\t\tvar result: Dictionary = _bootstrap.advance_runtime()\n\t\t\tprint("STARTUP_SPAN advance ", Time.get_ticks_usec() - start)')
 p.write_text(s)
 subprocess.run(['python','.godot/ci/dependency-audit/run.py','early','profile'],check=True)
finally:p.write_text(old)
