import pathlib,subprocess,os,hashlib
root=pathlib.Path.cwd();out=root/'.godot/ci/registration-cost'
paths=['data/manifests/scene_story_registration.json','data/manifests/scene_passages.json','data/manifests/dialogue_library_registration.json','data/manifests/story_start.json'];original={p:(root/p).read_bytes() for p in paths}
env=os.environ.copy();env.update(DWM_TEST_ROOT=str(root/'.godot/phase2r_tests/registration-cost/export'),XDG_DATA_HOME=str(out/'generator-user'))
def run(name,path,args=[]):
 r=subprocess.run(['godot','--headless','--path',str(root),'-s',path]+args,env=env,capture_output=True,text=True,timeout=180)
 log=r.stdout+r.stderr;(out/(name+'.log')).write_text(log);assert r.returncode==0 and 'ERROR:' not in log,log[-5000:];print(name,'exit',r.returncode,flush=True)
try:
 run('export','res://tools/authoring/ExportSevenDayRegistration.gd')
 assert all((root/p).read_bytes()==b for p,b in original.items()),'Generated output changed unexpectedly'
 run('export-validate','res://tools/authoring/ExportSevenDayRegistration.gd',['--','--validate-seven-day-export'])
 run('terminal-export','res://tests/templates/seven_day/ExportTerminalFixture.gd')
 expected=(root/paths[1]).read_bytes()
 run('terminal-parity','res://.godot/ci/registration-cost/generate.gd')
 assert (root/paths[1]).read_bytes()==expected,'Terminal passage output differs'
 print('Normal generation byte-identical; terminal passage output matches independent derivation',flush=True)
finally:
 for p,b in original.items():(root/p).write_bytes(b)
