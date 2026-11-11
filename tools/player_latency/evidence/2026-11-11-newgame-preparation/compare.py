import os,pathlib,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/newgame-preparation';p=root/'scripts/application/restore/NarrativeRestoreParticipant.gd';candidate=p.read_bytes();base=(out/'NarrativeRestoreParticipant.baseline.txt').read_bytes();rows=[]
try:
 for i,label in enumerate(['baseline','candidate','candidate','baseline']):
  p.write_bytes(base if label=='baseline' else candidate)
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/f'matched-user{i}'))
  log=out/f'matched-{i}-{label}.log'
  with log.open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(root/'.godot/ci/title-art/observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  s=log.read_text();assert r.returncode==0 and 'ERROR:' not in s,s[-3000:]
  row=json.loads(next(l.split(' ',1)[1] for l in s.splitlines() if l.startswith('FIRST_CAPTION ')));row.update(label=label,warning='WARNING:' in s,computer=json.loads(next(l.split(' ',1)[1] for l in s.splitlines() if l.startswith('EARLY_COMPUTER '))))
  assert row['text']=='Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself.'
  row['caption_ms']=(row['caption_us']-row['click_us'])/1000;rows.append(row);(out/'matched.json').write_text(json.dumps(rows,indent=2));print(label,row['caption_ms'],row['computer'],row['warning'],flush=True)
finally:p.write_bytes(candidate)
