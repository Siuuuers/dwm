import pathlib,os,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/title-refresh';p=root/'scripts/ui/MenuScene.gd';original=p.read_bytes()
s=original.decode();sig='func _refresh_login_shell(_value: String = "") -> void:'
s=s.replace(sig,sig+'\n\tvar start := Time.get_ticks_usec()\n\t_refresh_login_shell_profiled(_value)\n\tprint("TITLE_REFRESH ", JSON.stringify({"start_us":start,"duration_us":Time.get_ticks_usec()-start}))\n\nfunc _refresh_login_shell_profiled(_value: String = "") -> void:')
try:
 p.write_text(s)
 for i in range(2):
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'profile-candidate-user-{i}'))
  r=subprocess.run(['godot','--headless','--path',str(root),'--script','res://tests/manual/benchmark_player_startup.gd'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
  (out/f'profile-candidate-{i}.log').write_text(r.stdout)
  assert r.returncode==0 and 'ERROR:' not in r.stdout,r.stdout
  print(r.stdout,flush=True)
finally:p.write_bytes(original)
