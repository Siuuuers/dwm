import pathlib,subprocess,os,json,re
root=pathlib.Path.cwd();out=root/'.godot/ci/load-attribution';project=root/'project.godot';original=project.read_bytes()
bootstrap='res://autoload/ApplicationBootstrap.gd'
paths=[bootstrap]+list(dict.fromkeys(re.findall(r'preload\("(res://[^"\n]+)"\)',(root/'autoload/ApplicationBootstrap.gd').read_text())))
rows=[]
try:
 project.write_text(re.sub(r'(?ms)^\[autoload\]\n.*?(?=^\[)', '',original.decode()))
 for i,path in enumerate(paths):
  env=os.environ.copy();env.update(DWM_LOAD_PATHS=path,XDG_DATA_HOME=str(out/f'isolated-user-{i}'))
  r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'probe.gd')],env=env,capture_output=True,text=True,timeout=90)
  text=r.stdout+r.stderr;(out/f'isolated-{i}.log').write_text(text)
  assert r.returncode==0 and 'ERROR:' not in text,text
  row=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('RESOURCE_LOAD ')));rows.append(row)
  print(row,flush=True)
  (out/'isolated.json').write_text(json.dumps(rows,indent=2))
finally:project.write_bytes(original)
