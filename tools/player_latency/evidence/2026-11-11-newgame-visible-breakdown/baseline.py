import os,pathlib,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/visible-breakdown';rows=[]
for i in range(3):
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/f'baseline-user{i}'))
 log=out/f'baseline-{i}.log'
 with log.open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=log.read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-3000:]
 row=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('FIRST_CAPTION ')))
 assert row['text']=='Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself.'
 row.update(caption_ms=(row['caption_us']-row['click_us'])/1000,warning='WARNING:' in text,computer=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('EARLY_COMPUTER '))))
 rows.append(row);(out/'baseline.json').write_text(json.dumps(rows,indent=2));print({k:row[k] for k in ['caption_ms','largest_frame_gap_us','computer','warning']},flush=True)
