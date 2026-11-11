import pathlib,subprocess,os,json
root=pathlib.Path.cwd();out=root/'.godot/ci/load-attribution';p=root/'scripts/narrative/DialogicEntryManifest.gd';original=p.read_bytes();s=original.decode()
old='\tvar parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))'
assert old in s
s=s.replace(old,'\tvar read_start := Time.get_ticks_usec()\n\tvar text := FileAccess.get_file_as_string(path)\n\tvar parse_start := Time.get_ticks_usec()\n\tvar parsed := STRICT_JSON.parse_object(text)\n\tprint("REGISTRATION_READ_PARSE ",JSON.stringify({"read_us":parse_start-read_start,"parse_us":Time.get_ticks_usec()-parse_start,"bytes":text.length()}))',1)
old='\tvar selected := configure_test_scene_registration(parsed.value) if fixture else _configure_scene_registration(parsed.value)'
s=s.replace(old,'\tvar config_start := Time.get_ticks_usec()\n'+old+'\n\tprint("REGISTRATION_CONFIG ",Time.get_ticks_usec()-config_start)')
try:
 p.write_text(s)
 for i in range(2):
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'registration-user-{i}'))
  r=subprocess.run(['godot','--headless','--path',str(root),'--script','res://tests/manual/benchmark_player_startup.gd'],env=env,capture_output=True,text=True,timeout=90)
  text=r.stdout+r.stderr;(out/f'registration-{i}.log').write_text(text)
  assert r.returncode==0 and 'ERROR:' not in text,text
  print(text,flush=True)
finally:p.write_bytes(original)
