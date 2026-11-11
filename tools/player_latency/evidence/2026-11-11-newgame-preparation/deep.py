import os,pathlib,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/newgame-preparation';originals={}
specs={
'scripts/narrative/SoloReadingSession.gd':[('static ','expand_player_checkpoint','checkpoint: Dictionary','checkpoint','Dictionary'),('','restore_player','saved: Dictionary, entry_id: String','saved, entry_id','Dictionary'),('','configure_scene','','','Dictionary'),('','restore','saved: Dictionary, entry_id: String','saved, entry_id','Dictionary')],
'scripts/narrative/NarrativeCaptionLedger.gd':[('','initialize','session_token: String, frozen_context: Dictionary,\n\t\tentry_manifest: Dictionary, registry: Dictionary, entry_contexts_required: bool = false,\n\t\tscene: bool = false','session_token, frozen_context, entry_manifest, registry, entry_contexts_required, scene','Dictionary')]
}
try:
 for path,funcs in specs.items():
  p=root/path;originals[p]=p.read_bytes();s=originals[p].decode()
  for prefix,name,args,call,ret in funcs:
   needle=f'{prefix}func {name}({args}) -> {ret}:';assert s.count(needle)==1,(path,name)
   wrapper=f'{prefix}func {name}({args}) -> {ret}:\n\tvar tick := Time.get_ticks_usec()\n\tvar result := {name}_measured({call})\n\tprint("PREP_DEEP {name} ",Time.get_ticks_usec()-tick)\n\treturn result\n\n{prefix}func {name}_measured({args}) -> {ret}:'
   s=s.replace(needle,wrapper)
  p.write_text(s)
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.pop('DWM_EARLY_COMPUTER',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='idle',XDG_DATA_HOME=str(out/'deep-user'))
 with (out/'deep.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(root/'.godot/ci/first-caption/observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 print('exit',r.returncode)
 for l in (out/'deep.log').read_text().splitlines():
  if l.startswith(('PREP_DEEP','ERROR','SCRIPT ERROR')):print(l)
  if l.startswith('FIRST_CAPTION '):
   v=json.loads(l.split(' ',1)[1]);print({k:v for k,v in v.items() if k!='trace'})
finally:
 for p,b in originals.items():p.write_bytes(b)
