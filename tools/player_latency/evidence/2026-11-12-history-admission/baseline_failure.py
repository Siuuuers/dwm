import pathlib,subprocess,os
root=pathlib.Path.cwd();out=root/'.godot/ci/history-admission';paths=['autoload/DialogicBridge.gd','scripts/ui/witnessed/WitnessedCaptionLayer.gd']; saved={p:(root/p).read_bytes() for p in paths}
try:
 for p in paths:(root/p).write_bytes(subprocess.check_output(['git','show','HEAD:'+p]))
 user=root/'.godot/phase2r_tests/history-admission/check-baseline';(user/'root').mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,DWM_TEST_ROOT=str(user/'root'),XDG_DATA_HOME=str(user/'data'),DWM_SCENE_READING_FIXTURE='1')
 with (out/'check-baseline.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://tests/integration/test_scene_log_readonly.gd','-gexit','-glog=1','-gjunit_xml_file='+str(out/'check-baseline.xml')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 print('baseline existing suite exit',r.returncode)
finally:
 for p,data in saved.items():(root/p).write_bytes(data)
