import pathlib,os,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/title-refresh';paths=['scripts/ui/MenuScene.gd'];candidate={p:(root/p).read_bytes() for p in paths};base={p:subprocess.check_output(['git','show','49aa8a23219d671b32f589d8d7709bef250a8e9f:'+p]) for p in paths};rows=[]
try:
 for i,label in enumerate(['baseline','candidate','candidate','baseline','candidate','baseline']):
  for p in paths:(root/p).write_bytes((base if label=='baseline' else candidate)[p])
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'matched-user-{i}'))
  with (out/f'matched-{i}-{label}.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script','res://tests/manual/benchmark_player_startup.gd'],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  text=(out/f'matched-{i}-{label}.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-3000:]
  row=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('PLAYER_STARTUP ')));row.update(label=label,warning='WARNING:' in text);rows.append(row);(out/'matched.json').write_text(json.dumps(rows,indent=2));print(row,flush=True)
finally:
 for p,b in candidate.items():(root/p).write_bytes(b)
