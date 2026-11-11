import pathlib,subprocess,os,shutil,sys,json,xml.etree.ElementTree as ET
root=pathlib.Path.cwd(); out=root/'.godot/ci/history-admission'; label=sys.argv[1]
for i in range(2):
 user=root/'.godot/phase2r_tests/history-admission'/f'{label}-{i}'
 shutil.copytree(root/'.godot/phase2r_tests/player-pause-audit/0',user)
 env=os.environ.copy();env.update(DWM_TEST_ROOT=str(user/'root'),XDG_DATA_HOME=str(user/'data'))
 xml=out/f'{label}-{i}.xml'; log=out/f'{label}-{i}.log'
 cmd=['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://.godot/ci/history-admission/probe.gd','-gunit_test_name=test_history_probe','-gexit','-glog=1','-gjunit_xml_file='+str(xml)]
 with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=log.read_text(); assert r.returncode==0 and 'ERROR:' not in text,text[-6000:]
 report=ET.parse(xml).getroot(); cases=report.findall('.//testcase'); assert len(cases)==1 and int(cases[0].get('assertions','0'))>0
 assert not any(report.findall('.//'+tag) for tag in ['failure','error','skipped']),text[-6000:]
 print(label,i,cases[0].attrib,flush=True)
 print('\n'.join(l for l in text.splitlines() if l.startswith(('PLAYER_LATENCY','ADMISSION_US','HISTORY_CONTENT'))),flush=True)
