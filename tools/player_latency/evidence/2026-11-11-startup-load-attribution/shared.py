import pathlib,subprocess,os,re,json
root=pathlib.Path.cwd();out=root/'.godot/ci/load-attribution';project=root/'project.godot';original=project.read_bytes()
boot='res://autoload/ApplicationBootstrap.gd';port='res://scripts/application/run/SaveManagerCheckpointPort.gd';snapshot='res://scripts/domain/run/RunSnapshotSchema.gd';document='res://scripts/infrastructure/save/SaveDocumentSchema.gd'
orders=[[port,snapshot,document,boot,boot],[boot,port,snapshot,document,boot]];rows=[]
try:
 project.write_text(re.sub(r'(?ms)^\[autoload\]\n.*?(?=^\[)', '',original.decode()))
 for i,paths in enumerate(orders+orders):
  env=os.environ.copy();env.update(DWM_LOAD_PATHS=';'.join(paths),XDG_DATA_HOME=str(out/f'shared-user-{i}'))
  r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'probe.gd')],env=env,capture_output=True,text=True,timeout=90)
  text=r.stdout+r.stderr;(out/f'shared-{i}.log').write_text(text)
  assert r.returncode==0 and 'ERROR:' not in text,text
  row=[json.loads(l.split(' ',1)[1]) for l in text.splitlines() if l.startswith('RESOURCE_LOAD ')]
  rows.append(row);print(row,flush=True)
  (out/'shared.json').write_text(json.dumps(rows,indent=2))
finally:project.write_bytes(original)
