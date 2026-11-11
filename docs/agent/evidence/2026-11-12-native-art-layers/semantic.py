import pathlib,os,subprocess,sys,xml.etree.ElementTree as ET
root=pathlib.Path.cwd();out=root/'.godot/ci/art-layer-trim';label=sys.argv[1]
for i in range(1):
 user=root/'.godot/phase2r_tests/settings-open'/f'{label}-{i}';(user/'root').mkdir(parents=True,exist_ok=False)
 env=dict(os.environ,DWM_TEST_ROOT=str(user/'root'),XDG_DATA_HOME=str(user/'data'))
 log=out/f'{label}-{i}.log';xml=out/f'{label}-{i}.xml'
 cmd=['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://.godot/ci/art-layer-trim/semantic.gd','-gunit_test_name='+sys.argv[3],'-gexit','-glog=1','-gjunit_xml_file='+str(xml)]
 with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=log.read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-6000:]
 report=ET.parse(xml).getroot();cases=report.findall('.//testcase');assert len(cases)==1 and int(cases[0].get('assertions','0'))>0
 assert not any(report.findall('.//'+t) for t in ['failure','error','skipped']),text[-6000:]
 print(label,i,cases[0].attrib,flush=True)
 print('\n'.join(l for l in text.splitlines() if l.startswith(('PLAYER_LATENCY','OPEN_BEGIN','SPAN'))),flush=True)
