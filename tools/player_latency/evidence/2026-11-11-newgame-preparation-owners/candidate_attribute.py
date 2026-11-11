import pathlib,subprocess,os,re
root=pathlib.Path.cwd();out=root/'.godot/ci/newgame-owners';original={}
specs={
'autoload/GameState.gd':('func prepare_scene_new_run_snapshot_input(', '\nfunc prepare_scene_new_run(', ['presentation','registration','art_arrival','arrival']),
'autoload/DialogicBridge.gd':('static func _build_current_scene_initial_checkpoint(', '\nfunc _prepare_scene_entry(', ['compiled','presentation','configured','begun','entered','allocation','published','captured','frames'])}
try:
 for path,(start,end,names) in specs.items():
  p=root/path;original[p]=p.read_bytes();s=original[p].decode();a=s.index(start);b=s.index(end,a);body=s[a:b]
  for name in names:
   pattern=r'(?m)^(\t+)var '+name+r'(?:\s*:\s*\w+)?\s*:?= [^\n]*(?:\n\t{2,}[^\n]*)*'
   # Bound multiline matches to balanced parentheses, not following nested statements.
   m=re.search(r'(?m)^(\t+)var '+name+r'(?:\s*:\s*\w+)?\s*:?= [^\n]*',body);assert m,(path,name)
   j=m.end();statement=m.group()
   while statement.count('(')>statement.count(')') or statement.count('{')>statement.count('}'):
    j=body.index('\n',j+1);statement=body[m.start():j]
   indent=m.group(1)
   wrapped=indent+'var _tick_'+name+' := Time.get_ticks_usec()\n'+statement+'\n'+indent+'print("OWNER_SPAN '+path.split('/')[-1]+' '+name+' ", Time.get_ticks_usec()-_tick_'+name+')'
   body=body[:m.start()]+wrapped+body[j:]
  p.write_text(s[:a]+body+s[b:])
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/'candidate-attribute-user'))
 with (out/'candidate-attribute.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=(out/'candidate-attribute.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-4000:]
 print('\n'.join(l for l in text.splitlines() if l.startswith('OWNER_SPAN')))
finally:
 for p,data in original.items():p.write_bytes(data)
