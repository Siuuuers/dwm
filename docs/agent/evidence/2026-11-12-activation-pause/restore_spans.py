from pathlib import Path
import subprocess
paths=['autoload/DialogicBridge.gd','scripts/narrative/DialogicRuntimeAdapter.gd'];saved={p:Path(p).read_text() for p in paths}
runner=Path('.godot/ci/activation-pause/load_profile.py');old=runner.read_text()
try:
 p=Path(paths[0]);s=saved[str(p)]
 for name,kind in [('_scene_restore_current','bool'),('_prepare_witnessed_style','Dictionary')]:
  signature='func '+name+'() -> '+kind+':'
  s=s.replace(signature,signature+'\n\tvar started := Time.get_ticks_usec()\n\tvar result: '+kind+' = _profiled'+name+'()\n\tprint("SPAN '+name+' " + str(Time.get_ticks_usec() - started))\n\treturn result\n\nfunc _profiled'+name+'() -> '+kind+':',1)
 p.write_text(s)
 p=Path(paths[1]);s=saved[str(p)];sig='func restore_scene_frontier(session: RefCounted, checkpoint: Dictionary) -> Dictionary:'
 s=s.replace(sig,sig+'\n\tvar started := Time.get_ticks_usec()\n\tvar result: Dictionary = _profiled_restore_scene_frontier(session, checkpoint)\n\tprint("SPAN restore_scene_frontier " + str(Time.get_ticks_usec() - started))\n\treturn result\n\nfunc _profiled_restore_scene_frontier(session: RefCounted, checkpoint: Dictionary) -> Dictionary:',1);p.write_text(s)
 runner.write_text(old.replace("'load-profile.log'","'restore-spans.log'").replace("'load-profile.xml'","'restore-spans.xml'").replace("('DWM_SAVE_LOAD_PROFILE'","('SPAN','DWM_SAVE_LOAD_PROFILE'"))
 subprocess.run(['python',str(runner)],check=True)
finally:
 for p,s in saved.items():Path(p).write_text(s)
 runner.write_text(old)
