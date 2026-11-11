import pathlib,subprocess,os,xml.etree.ElementTree as ET
root=pathlib.Path.cwd();out=root/'.godot/ci/registration-cost'
cases=[('ownership','tests/unit/test_scene_event_contract.gd','test_shipped_structure_keeps_passage_compilation_in_authoring',1),('detach','tests/unit/test_scene_event_contract.gd','test_bundle_validation_detaches_entries_targets_and_markers',1),('fingerprint','tests/unit/test_scene_event_contract.gd','test_bundle_encoding_matches_whole_writer_across_versions_and_member_order',1),('direct-load','tests/integration/test_scene_direct_load.gd','',1),('passage-display','tests/unit/test_scene_passage_gallery.gd','test_passage_catalogue_selects_only_between_the_two_markers_and_detaches',1)]
for name,path,method,count in cases:
 user=root/'.godot/phase2r_tests/registration-cost'/('check-'+name);(user/'test-root').mkdir(parents=True,exist_ok=True)
 env=os.environ.copy();env.update(XDG_DATA_HOME=str(user/'data'),DWM_TEST_ROOT=str(user/'test-root'))
 cmd=['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://'+path,'-gexit','-glog=1','-gjunit_xml_file='+str(out/(name+'.xml'))]
 if method:cmd.append('-gunit_test_name='+method)
 r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=180);text=r.stdout+r.stderr;(out/(name+'.log')).write_text(text)
 assert r.returncode==0 and 'ERROR:' not in text,text[-5000:]
 report=ET.parse(out/(name+'.xml')).getroot();tests=report.findall('.//testcase');assert len(tests)==count,(name,len(tests));assert not any(report.findall('.//'+tag) for tag in ['failure','error','skipped'])
 assert all(int(t.get('assertions','0'))>0 for t in tests)
 print(name,[(t.get('name'),t.get('assertions')) for t in tests],flush=True)
