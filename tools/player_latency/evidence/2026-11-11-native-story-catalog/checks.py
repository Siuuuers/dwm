import os,pathlib,subprocess
root=pathlib.Path.cwd();out=root/'.godot/ci/native-catalog'
env=os.environ.copy();env['DWM_TEST_ROOT']=str(root/'.godot/phase2r_tests/native-catalog');env['XDG_DATA_HOME']=str(out/'checks-user')
for name,tests in [('focused','tests/unit/test_story_bilingual_projection.gd,tests/integration/test_bilingual_reading.gd'),('load','tests/integration/test_bilingual_reading_load.gd')]:
 with (out/(name+'.log')).open('w') as f:
  r=subprocess.run(['godot','--headless','--path',str(root),'-s','res://addons/gut/gut_cmdln.gd','-gconfig=','-gtest='+','.join('res://'+p for p in tests.split(',')),'-gexit','-gjunit_xml_file=res://.godot/ci/native-catalog/'+name+'.xml'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=(out/(name+'.log')).read_text();print(name,r.returncode,text[-1800:],flush=True)
 assert r.returncode==0 and 'ERROR:' not in text
