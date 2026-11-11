import os,pathlib,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/art-alpha';originals={}
specs={
'scripts/ui/art/SceneArtView.gd':[],
'scripts/data/ArtManifest.gd':[('static ','get_texture','asset_id: String, expected_size: Vector2i = Vector2i.ZERO','asset_id, expected_size','Texture2D')],
'scripts/ui/witnessed/WitnessedArtLayer.gd':[('','refresh_art','','','void')],
'autoload/GameState.gd':[('','get_scene_presentation','','','Dictionary')],
'autoload/DialogicBridge.gd':[('','get_current_scene_art','','','Dictionary')],
'scripts/ui/witnessed/WitnessedCaptionLayer.gd':[('','_refresh_dating_overlay','','','void')]
}
try:
 for path,funcs in specs.items():
  p=root/path;originals[p]=p.read_bytes();s=originals[p].decode()
  for prefix,name,args,call,ret in funcs:
   needle=f'{prefix}func {name}({args}) -> {ret}:';assert s.count(needle)==1,(path,name)
   invocation=f'{name}_measured({call})'
   wrapper=f'{prefix}func {name}({args}) -> {ret}:\n\tvar tick := Time.get_ticks_usec()\n\t'+(('var result := '+invocation) if ret!='void' else invocation)+f'\n\tprint("ART_DEEP {name} ",Time.get_ticks_usec()-tick)\n'+('\treturn result\n' if ret!='void' else '')+f'\n{prefix}func {name}_measured({args}) -> {ret}:'
   s=s.replace(needle,wrapper)
  if path=='scripts/ui/art/SceneArtView.gd':
   for name,needle,indent in [('image','var source: Image = texture.get_image()',4),('alpha','_opaque_portraits[index] = source != null and source.detect_alpha() == Image.ALPHA_NONE',4),('signal','split_changed.emit(get_right_rect())',1)]:
    line='\t'*indent+needle
    s=s.replace(line,'\t'*indent+'var tick_'+name+' := Time.get_ticks_usec()\n'+line+'\n'+'\t'*indent+'print("ART_DEEP '+name+' ",Time.get_ticks_usec()-tick_'+name+')')
  p.write_text(s)
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.pop('DWM_EARLY_COMPUTER',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='idle',XDG_DATA_HOME=str(out/'combined-user'))
 with (out/'combined.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(root/'.godot/ci/first-caption/observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 print('exit',r.returncode)
 for l in (out/'combined.log').read_text().splitlines():
  if l.startswith(('ART_DEEP','ERROR','SCRIPT ERROR')):print(l)
  if l.startswith('FIRST_CAPTION '):
   v=json.loads(l.split(' ',1)[1]);print({k:v for k,v in v.items() if k!='trace'})
finally:
 for p,b in originals.items():p.write_bytes(b)
