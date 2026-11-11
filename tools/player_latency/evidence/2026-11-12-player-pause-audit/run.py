import pathlib,subprocess,os,json,xml.etree.ElementTree as ET
root=pathlib.Path.cwd();out=root/'.godot/ci/player-pause-audit';revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
for i in range(2):
 user=root/'.godot/phase2r_tests/player-pause-audit'/str(i);(user/'root').mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update(DWM_TEST_ROOT=str(user/'root'),XDG_DATA_HOME=str(user/'data'),DWM_BENCHMARK_REVISION=revision)
 xml=out/f'journey-{i}.xml';log=out/f'journey-{i}.log'
 cmd=['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://.godot/ci/player-pause-audit/journey.gd','-gunit_test_name=test_player_latency','-gexit','-glog=1','-gjunit_xml_file='+str(xml)]
 with log.open('w') as f:r=subprocess.run(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=300)
 text=log.read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-5000:]
 report=ET.parse(xml).getroot();cases=report.findall('.//testcase');assert len(cases)==1 and int(cases[0].get('assertions','0'))>0
 assert not any(report.findall('.//'+tag) for tag in ['failure','error','skipped'])
 rows=[json.loads(l.split(' ',1)[1]) for l in text.splitlines() if l.startswith('PLAYER_LATENCY ')]
 (out/f'journey-{i}.json').write_text(json.dumps({'revision':revision,'samples':rows,'assertions':cases[0].get('assertions'),'warning':'WARNING:' in text},indent=2))
 print('JOURNEY',i,'samples',len(rows),'assertions',cases[0].get('assertions'),flush=True)
 for action in ['new_game_flow','computer_first','history','computer','load_checkpoint']:
  print(action,[r for r in rows if r['action']==action],flush=True)
