import os,pathlib,subprocess,json
root=pathlib.Path.cwd();out=root/'.godot/ci/activation'; originals={}
specs={
'scripts/ui/UiTypography.gd':[],
'scripts/ui/SceneHost.gd':[('_ready','','','void'),('_refresh_presentation','_locale_id: String = ""','_locale_id','void')],
'scripts/ui/witnessed/WitnessedCaptionLayer.gd':[('_ready','','','void')],
'autoload/SceneRouter.gd':[('begin_scene_activation','operation_id: String','operation_id','Dictionary'),('_on_scene_activation_mounted','','','void')],
'scripts/narrative/DialogicRuntimeAdapter.gd':[('_install_scene_frontier','session: RefCounted, checkpoint: Dictionary, source_token: RefCounted = null','session, checkpoint, source_token','Dictionary'),('start_timeline','path: String, label_or_index: Variant = 0','path, label_or_index','Dictionary'),('_finish_reading_restore','request_id: String, event: DialogicTextEvent','request_id, event','void')],
'scripts/application/restore/RunRestoreParticipant.gd':[('activate_live_session','ticket: Dictionary','ticket','Dictionary')],
'autoload/SaveManager.gd':[('_drive_scene_restore_activation_owned','','','Dictionary')]
}
try:
 for path,funcs in specs.items():
  p=root/path; originals[p]=p.read_bytes();s=originals[p].decode()
  for name,args,call,ret in funcs:
   needle=f'func {name}({args}) -> {ret}:'; assert s.count(needle)==1,(path,name)
   invocation=f'{name}_measured({call})'
   wrapper=f'func {name}({args}) -> {ret}:\n\tvar tick := Time.get_ticks_usec()\n\t'+(('var result := '+invocation) if ret!='void' else invocation)+f'\n\tprint("DEEP_SPAN {name} ", Time.get_ticks_usec() - tick)\n'+('\treturn result\n' if ret!='void' else '')+f'\nfunc {name}_measured({args}) -> {ret}:'
   s=s.replace(needle,wrapper)
  if path=='scripts/ui/SceneHost.gd':
   needle='\thome.theme = preload("res://scripts/ui/desktop/DesktopTheme.gd").build(locale, percent, &"midnight", 0.0, false, "standard", font_style)'
   assert needle in s
   s=s.replace(needle,'\tvar theme_tick := Time.get_ticks_usec()\n'+needle+'\n\tprint("DEEP_SPAN hidden_home_theme ", Time.get_ticks_usec()-theme_tick)')
  if path=='scripts/ui/UiTypography.gd':
   for tag,needle in [('duplicate','\t\tvar face := primary.duplicate() as FontFile'),('clear','\t\tface.clear_cache()'),('fallback','\t\tvar fallbacks: Array[Font] = [load("res://assets/ui/contacts/fonts/dejavu-sans-fallback.ttf") as FontFile]')]:
    s=s.replace(needle,'\t\tvar tick_'+tag+' := Time.get_ticks_usec()\n'+needle+'\n\t\tprint("DEEP_SPAN font_'+tag+' ",Time.get_ticks_usec()-tick_'+tag+')')
  p.write_text(s)
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.pop('DWM_EARLY_COMPUTER',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='idle',XDG_DATA_HOME=str(out/'deep-user4'))
 with (out/'deep4.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(root/'.godot/ci/first-caption/observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 print('exit',r.returncode)
 for l in (out/'deep4.log').read_text().splitlines():
  if l.startswith(('DEEP_SPAN','ERROR','SCRIPT ERROR')):print(l)
  if l.startswith('FIRST_CAPTION '):
   v=json.loads(l.split(' ',1)[1]);print({k:v for k,v in v.items() if k!='trace'})
finally:
 for p,b in originals.items():p.write_bytes(b)
