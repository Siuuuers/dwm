import pathlib,subprocess,os,xml.etree.ElementTree as ET
root=pathlib.Path.cwd();out=root/'.godot/ci/native-registration';p=root/'scripts/narrative/DialogicEntryManifest.gd';candidate=p.read_bytes();base=subprocess.check_output(['git','show','29d8ff273e560e668bc7e6ca5d08e0ce4619bba7:scripts/narrative/DialogicEntryManifest.gd'])
user=root/'.godot/phase2r_tests/native-registration/cross-load';user.mkdir(parents=True,exist_ok=True)
env=os.environ.copy();env.update(DWM_TEST_ROOT=str(user),XDG_DATA_HOME=str(out/'cross-user'))
try:
 for name,path,data in [('old-create','tests/integration/test_bilingual_reading.gd',base),('native-load','tests/integration/test_bilingual_reading_load.gd',candidate)]:
  p.write_bytes(data)
  r=subprocess.run(['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest=res://'+path,'-gexit','-glog=1','-gjunit_xml_file='+str(out/(name+'.xml'))],env=env,capture_output=True,text=True,timeout=180)
  text=r.stdout+r.stderr;(out/(name+'.log')).write_text(text);assert r.returncode==0 and 'ERROR:' not in text,text[-5000:]
  report=ET.parse(out/(name+'.xml')).getroot();tests=report.findall('.//testcase');assert len(tests)==1
  assert not any(report.findall('.//'+tag) for tag in ['failure','error','skipped']);assert all(int(t.get('assertions','0'))>0 for t in tests)
  print(name,[(t.get('name'),t.get('assertions')) for t in tests],flush=True)
finally:p.write_bytes(candidate)
