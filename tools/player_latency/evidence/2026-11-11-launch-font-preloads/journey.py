import os, pathlib, subprocess, json
root=pathlib.Path.cwd(); out=root/'.godot/ci/launch-breakdown'
paths=['scripts/ui/UiTypography.gd','scripts/ui/desktop/DesktopTheme.gd','scripts/ui/SettingsTheme.gd']
candidate={p:(root/p).read_bytes() for p in paths}
baseline={p:subprocess.check_output(['git','show','c13d92ae4b7af8c23c72f56b0bbafdd7bb161bf2:'+p]) for p in paths}
rows=[]
try:
 for i,label in enumerate(['baseline','candidate','candidate','baseline']):
  for p in paths: (root/p).write_bytes((baseline if label=='baseline' else candidate)[p])
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None)
  env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/f'journey-user{i}'))
  log=out/f'journey-{i}-{label}.log'
  with log.open('w') as f: result=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  text=log.read_text();assert result.returncode==0 and 'ERROR:' not in text,text[-3000:]
  row=json.loads(next(line.split(' ',1)[1] for line in text.splitlines() if line.startswith('FIRST_CAPTION ')))
  assert row['text']=='Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself.'
  row.update(label=label,warning='WARNING:' in text,computer=json.loads(next(line.split(' ',1)[1] for line in text.splitlines() if line.startswith('EARLY_COMPUTER '))))
  row['caption_ms']=(row['caption_us']-row['click_us'])/1000;rows.append(row)
  (out/'journey.json').write_text(json.dumps(rows,indent=2))
  print(label,{k:row[k] for k in ['title_us','runtime_us','caption_ms','computer','warning']},flush=True)
finally:
 for p,data in candidate.items(): (root/p).write_bytes(data)
