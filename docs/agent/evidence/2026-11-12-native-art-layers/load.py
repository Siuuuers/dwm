from pathlib import Path
import sys,os,subprocess,shutil,json,xml.etree.ElementTree as ET
root=Path.cwd();out=root/'.godot/ci/art-layer-trim';seed=root/'.godot/ci/checkpoint-load/results/seed-root';user=root/'.godot/phase2r_tests/checkpoint-load'
shutil.rmtree(user);shutil.copytree(seed,user)
env=dict(os.environ,DWM_TEST_ROOT=str(user/'test-root'),XDG_DATA_HOME=str(user/'data'))
log=out/(sys.argv[1]+'.log');xml=out/(sys.argv[1]+'.xml')
cmd=['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://tests/manual/benchmark_checkpoint_load.gd','-gunit_test_name=test_checkpoint_load_cost','-gexit','-glog=1','-gjunit_xml_file='+str(xml)]
with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
s=log.read_text();assert r.returncode==0 and 'ERROR:' not in s,s[-5000:]
cases=ET.parse(xml).getroot().findall('.//testcase');assert len(cases)==1 and cases[0].get('status')=='pass'
print('PROFILE assertions',cases[0].get('assertions'))
for l in s.splitlines():
 if l.startswith(('DWM_SAVE_LOAD_PROFILE','DWM_CHECKPOINT_PROFILE','DWM_SCENE_VALIDATION_PROFILE','CHECKPOINT_LOAD_SAMPLE')):print(l)
