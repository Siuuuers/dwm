import pathlib,subprocess,os,xml.etree.ElementTree as ET
root=pathlib.Path.cwd();out=root/'.godot/ci/settings-open'
suites=['tests/scene/test_settings_host_geometry.gd']
for i,suite in enumerate(suites):
 user=root/'.godot/phase2r_tests/settings-open'/f'delayed-{i}';(user/'root').mkdir(parents=True,exist_ok=True)
 env=dict(os.environ,DWM_TEST_ROOT=str(user/'root'),XDG_DATA_HOME=str(user/'data'),DWM_SCENE_READING_FIXTURE='1')
 log=out/f'delayed-{i}.log';xml=out/f'delayed-{i}.xml'
 cmd=['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://'+suite,'-gunit_test_name=test_departure_blocks_input_and_reopen_until_held_sample_cleanup_finishes','-gexit','-glog=1','-gjunit_xml_file='+str(xml)]
 with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=log.read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-6000:]
 report=ET.parse(xml).getroot();cases=report.findall('.//testcase');assert cases and all(int(c.get('assertions','0'))>0 for c in cases)
 assert not any(report.findall('.//'+tag) for tag in ['failure','error','skipped']),text[-6000:]
 print(suite,len(cases),sum(int(c.get('assertions','0')) for c in cases),flush=True)
