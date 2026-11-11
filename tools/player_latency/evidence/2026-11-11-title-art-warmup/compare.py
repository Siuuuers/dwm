import os,pathlib,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/title-art';p=root/'autoload/StartupLoader.gd';base=p.read_bytes();candidate=base.decode().replace('queue_resources(_bootstrap.BACKGROUND_RESOURCES)','queue_resources(_bootstrap.BACKGROUND_RESOURCES + ["res://art/pictures/picture1.png", "res://art/pictures/picture2.png"])').encode();rows=[]
try:
 for mode in ['early','settled']:
  for i,label in enumerate(['baseline','candidate','candidate','baseline']):
   p.write_bytes(base if label=='baseline' else candidate)
   env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE=mode,DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/f'{mode}-user{i}'))
   log=out/f'{mode}-{i}-{label}.log'
   with log.open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
   s=log.read_text();assert r.returncode==0 and 'ERROR:' not in s,s[-3000:]
   row=json.loads(next(l.split(' ',1)[1] for l in s.splitlines() if l.startswith('FIRST_CAPTION ')));row.update(mode=mode,label=label,warning='WARNING:' in s,computer=json.loads(next(l.split(' ',1)[1] for l in s.splitlines() if l.startswith('EARLY_COMPUTER '))))
   assert row['text']=='Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself.'
   row['caption_ms']=(row['caption_us']-row['click_us'])/1000;rows.append(row);(out/'matched.json').write_text(json.dumps(rows,indent=2));print(mode,label,row['caption_ms'],row['computer'],flush=True)
finally:p.write_bytes(base)
