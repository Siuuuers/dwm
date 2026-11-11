import pathlib,re,subprocess,os
root=pathlib.Path.cwd();out=root/'.godot/ci/native-registration';p=root/'project.godot';original=p.read_bytes()
try:
 p.write_text(re.sub(r'(?ms)^\[autoload\]\n.*?(?=^\[)', '',original.decode()))
 env=os.environ.copy();env['XDG_DATA_HOME']=str(out/'decode-user')
 r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'probe.gd')],env=env,capture_output=True,text=True,timeout=90)
 text=r.stdout+r.stderr;(out/'decode.log').write_text(text);print(text)
 assert r.returncode==0 and 'ERROR:' not in text
finally:p.write_bytes(original)
