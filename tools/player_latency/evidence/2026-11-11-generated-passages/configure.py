import pathlib,subprocess,os,json
root=pathlib.Path.cwd();out=root/'.godot/ci/registration-cost'
paths=['scripts/domain/narrative/SceneEventContract.gd','scripts/narrative/DialogicEntryManifest.gd','scripts/narrative/ScenePassageCatalog.gd']
candidate={p:(root/p).read_bytes() for p in paths};base={p:subprocess.check_output(['git','show','d8b70b84c3c51932af4ae67887f207cf6077f7b8:'+p]) for p in paths};rows=[]
try:
 for i,label in enumerate(['baseline','candidate','candidate','baseline']):
  for p,b in (base if label=='baseline' else candidate).items():
   text=b.decode()
   if p.endswith('DialogicEntryManifest.gd'):
    text=text.replace('static func _select_startup_fixture() -> Dictionary:\n','static func _select_startup_fixture() -> Dictionary:\n\tvar probe_start := Time.get_ticks_usec()\n',1)
    text=text.replace('\treturn selected\n','\tprint("REGISTRATION_SELECT_US ",Time.get_ticks_usec()-probe_start)\n\treturn selected\n',1)
   (root/p).write_text(text)
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'config-user-{i}'))
  r=subprocess.run(['godot','--headless','--path',str(root),'--script','res://tests/manual/benchmark_player_startup.gd'],env=env,capture_output=True,text=True,timeout=120)
  log=r.stdout+r.stderr;(out/f'config-{i}-{label}.log').write_text(log)
  assert r.returncode==0 and 'ERROR:' not in log,log[-4000:]
  row={'label':label,'select_us':int(next(l.split(' ',1)[1] for l in log.splitlines() if l.startswith('REGISTRATION_SELECT_US '))),'warning':'WARNING:' in log};rows.append(row);print(row,flush=True)
  (out/'configure.json').write_text(json.dumps(rows,indent=2))
finally:
 for p,b in candidate.items():(root/p).write_bytes(b)
