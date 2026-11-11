import os,pathlib,subprocess,json,shutil
root=pathlib.Path.cwd();out=root/'.godot/ci/activation';p=root/'scripts/ui/UiTypography.gd';candidate=p.read_bytes();baseline=(out/'UiTypography.baseline.txt').read_bytes();rows=[]
try:
 for i,label in enumerate(['baseline','candidate','candidate','baseline']):
  p.write_bytes(baseline if label=='baseline' else candidate)
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.pop('DWM_EARLY_COMPUTER',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='idle',XDG_DATA_HOME=str(out/f'matched-user{i}'))
  with (out/f'match-{i}-{label}.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(root/'.godot/ci/first-caption/observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  s=(out/f'match-{i}-{label}.log').read_text();assert r.returncode==0 and 'ERROR:' not in s,s[-3000:]
  row=json.loads(next(l.split(' ',1)[1] for l in s.splitlines() if l.startswith('FIRST_CAPTION ')))
  row['label']=label;row['elapsed_ms']=(row['caption_us']-row['click_us'])/1000;rows.append(row)
  (out/'matched.json').write_text(json.dumps(rows,indent=2));print(label,row['elapsed_ms'],flush=True)
finally:p.write_bytes(candidate)
