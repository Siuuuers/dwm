import pathlib,os,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/bridge-loading';paths=['autoload/DialogicBridge.gd','autoload/ApplicationBootstrap.gd'];candidate={p:(root/p).read_bytes() for p in paths};base={p:subprocess.check_output(['git','show','24131a2596861e19820d02300d63fbb7aac78cf5:'+p]) for p in paths};rows=[]
try:
 for i,label in enumerate(['baseline','candidate']):
  for p in paths:(root/p).write_bytes((base if label=='baseline' else candidate)[p])
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'cache-user-{i}'))
  with (out/f'cache-{i}-{label}.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'cache-probe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  text=(out/f'cache-{i}-{label}.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-3000:]
  row=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('PLAYER_STARTUP ')));row.update(label=label,warning='WARNING:' in text);rows.append(row);(out/'cache.json').write_text(json.dumps(rows,indent=2));print(row,flush=True)
finally:
 for p,b in candidate.items():(root/p).write_bytes(b)
