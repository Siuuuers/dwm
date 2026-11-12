import sys,pathlib,subprocess,os,json
root=pathlib.Path.cwd();out=root/'.godot/ci/dependency-audit';mode=sys.argv[1];label=sys.argv[2];rows=[]
for i in range(1):
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE=mode,DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/f'{label}-user-{i}'))
 r=subprocess.run(['godot','--headless','--path',str(root),'-s',str(out/'startup.gd')],env=env,capture_output=True,text=True,timeout=120)
 log=r.stdout+r.stderr;(out/f'{label}-{i}.log').write_text(log);assert r.returncode==0 and 'ERROR:' not in log,log[-5000:]
 row=json.loads(next(l.split(' ',1)[1] for l in log.splitlines() if l.startswith('FIRST_CAPTION ')))
 assert row['text']=='Sylvia slides the fuller teacup onto my mat and keeps the one with the small chip on the rim for herself.'
 row['computer']=json.loads(next(l.split(' ',1)[1] for l in log.splitlines() if l.startswith('EARLY_COMPUTER ')))
 rows.append(row);print({k:v for k,v in row.items() if k not in ['trace','text']},flush=True)
(out/(label+'.json')).write_text(json.dumps(rows,indent=2))
