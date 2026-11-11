import pathlib,os,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/launch-breakdown';paths=['scripts/ui/UiTypography.gd','scripts/ui/desktop/DesktopTheme.gd','scripts/ui/SettingsTheme.gd'];candidate={p:(root/p).read_bytes() for p in paths};base={p:subprocess.check_output(['git','show','c13d92ae4b7af8c23c72f56b0bbafdd7bb161bf2:'+p]) for p in paths};rows=[]
try:
 for i,label in enumerate(['baseline','candidate']):
  for p in paths:(root/p).write_bytes((base if label=='baseline' else candidate)[p])
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'font-user-{i}'))
  with (out/f'font-{i}-{label}.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'font-probe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  text=(out/f'font-{i}-{label}.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-3000:]
  row=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('PLAYER_STARTUP ')));row.update(label=label,warning='WARNING:' in text,title=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('PLAYER_TITLE '))));rows.append(row);(out/'font-probe.json').write_text(json.dumps(rows,indent=2));print(row,flush=True)
finally:
 for p,b in candidate.items():(root/p).write_bytes(b)
