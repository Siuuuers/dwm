import pathlib,subprocess,os,xml.etree.ElementTree as ET
root=pathlib.Path.cwd();out=root/'.godot/ci/history-admission'
suites=['tests/integration/test_scene_native_activation_runtime.gd','tests/unit/test_witnessed_reading_rail.gd']
for i,suite in enumerate(suites):
 user=root/'.godot/phase2r_tests/history-admission'/f'final-check-{i}';(user/'root').mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,DWM_TEST_ROOT=str(user/'root'),XDG_DATA_HOME=str(user/'data'),DWM_SCENE_READING_FIXTURE='1')
 log=out/f'final-check-{i}.log';xml=out/f'final-check-{i}.xml'
 cmd=['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://'+suite,'-gexit','-glog=1','-gjunit_xml_file='+str(xml)]
 with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=log.read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-6000:]
 report=ET.parse(xml).getroot();cases=report.findall('.//testcase');assert cases and all(int(c.get('assertions','0'))>0 for c in cases)
 assert not any(report.findall('.//'+tag) for tag in ['failure','error','skipped']),text[-6000:]
 print(suite,len(cases),sum(int(c.get('assertions','0')) for c in cases),flush=True)
