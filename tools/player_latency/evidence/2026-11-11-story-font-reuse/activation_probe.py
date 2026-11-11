import os,pathlib,subprocess
root=pathlib.Path.cwd(); out=root/'.godot/ci/activation';out.mkdir(exist_ok=True)
p=root/'autoload/DialogicBridge.gd'; original=p.read_bytes();s=original.decode()
for name,ret in [('_scene_restore_current','bool'),('_capture_scene_restore_position','Dictionary'),('_prepare_witnessed_style','Dictionary')]:
 needle=f'func {name}() -> {ret}:'
 assert s.count(needle)==1
 wrapper=f'''func {name}() -> {ret}:
	var tick := Time.get_ticks_usec()
	var result := {name}_measured()
	print("ACTIVATION_SPAN {name} ", Time.get_ticks_usec() - tick)
	return result

func {name}_measured() -> {ret}:'''
 s=s.replace(needle,wrapper)
try:
 p.write_text(s)
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.pop('DWM_EARLY_COMPUTER',None)
 env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='idle',XDG_DATA_HOME=str(out/'user1'))
 with (out/'probe.log').open('w') as f:
  r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(root/'.godot/ci/first-caption/observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 print('exit',r.returncode)
 for l in (out/'probe.log').read_text().splitlines():
  if l.startswith(('ACTIVATION_SPAN','FIRST_CAPTION','ERROR','SCRIPT ERROR')):print(l)
finally:p.write_bytes(original)
