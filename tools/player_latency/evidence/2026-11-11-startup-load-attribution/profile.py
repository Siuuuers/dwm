import pathlib,os,subprocess,re,json
root=pathlib.Path.cwd();out=root/'.godot/ci/load-attribution';original={}
specs={'autoload/StartupLoader.gd':['_install','_attach'],'autoload/ApplicationBootstrap.gd':['start_title','_run_stage'],'scripts/ui/MenuScene.gd':['_ready','_mount_title_art','_build_login_shell']}
try:
 for path,names in specs.items():
  p=root/path;original[p]=p.read_bytes();s=original[p].decode()
  if path.endswith('StartupLoader.gd'):
   s=s.replace('_bootstrap = load("res://autoload/ApplicationBootstrap.gd").new()','var boot_start := Time.get_ticks_usec()\n\t_bootstrap = load("res://autoload/ApplicationBootstrap.gd").new()\n\tprint("LAUNCH_BOOT ", boot_start, " ", Time.get_ticks_usec())')
   s=s.replace('\t\t_attach(owner, load(_owner_path(owner)))','\t\tvar load_start := Time.get_ticks_usec()\n\t\tvar owner_script: Script = load(_owner_path(owner))\n\t\tprint("LAUNCH_LOAD ", owner, " ", load_start, " ", Time.get_ticks_usec())\n\t\t_attach(owner, owner_script)',1)
  for name in names:
   m=re.search(r'(?m)^func '+name+r'\((.*?)\) -> (\w+):',s,re.S);assert m,(path,name)
   args,ret=m.groups();call=', '.join(re.findall(r'(?:^|,)\s*(\w+)\s*:',args));invoke=name+'_profiled('+call+')'
   extra=',"detail":str('+call.split(',')[0]+')' if name in ['_attach','_run_stage'] else ''
   w=m.group()+'\n\tvar probe_start := Time.get_ticks_usec()\n\t'+('var result = '+invoke if ret!='void' else invoke)+'\n\tprint("LAUNCH_SPAN ",JSON.stringify({"name":"'+path+':'+name+'","start":probe_start,"end":Time.get_ticks_usec()'+extra+'}))\n'+('\treturn result\n' if ret!='void' else '')+'\nfunc '+name+'_profiled('+args+') -> '+ret+':'
   s=s[:m.start()]+w+s[m.end():]
  p.write_text(s)
 for i in range(2):
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'user-{i}'))
  with (out/f'profile-{i}.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script','res://tests/manual/benchmark_player_startup.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  text=(out/f'profile-{i}.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-3000:]
  print(text,flush=True)
finally:
 for p,b in original.items():p.write_bytes(b)
