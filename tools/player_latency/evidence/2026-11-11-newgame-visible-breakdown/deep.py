import os,pathlib,subprocess,json,re
root=pathlib.Path.cwd();out=root/'.godot/ci/visible-breakdown';original={}
specs={
'autoload/SaveManager.gd':['_start_scene_new_run_in_memory','_drive_scene_restore_activation_owned'],
'autoload/SceneRouter.gd':['begin_scene_activation','_on_scene_activation_mounted','publish_scene_activation'],
'scripts/ui/SceneHost.gd':['_ready'],
'addons/dialogic/Core/DialogicGameHandler.gd':['start_timeline'],
'addons/dialogic/Resources/timeline.gd':['process'],
'addons/dialogic/Modules/Style/subsystem_styles.gd':['create_layout','_attach_layout'],
'autoload/DialogicBridge.gd':['_prepare_witnessed_style','_confirm_scene_activation','publish_scene_activation'],
'scripts/narrative/DialogicRuntimeAdapter.gd':['start_timeline','_start_held_scene_target','_finish_reading_restore','_on_caption_text_started'],
'scripts/ui/witnessed/WitnessedArtLayer.gd':['_ready','refresh_art'],
'scripts/data/ArtManifest.gd':['get_texture'],
'scripts/ui/witnessed/WitnessedCaptionLayer.gd':['_ready','_refresh_reading_session','_refresh_dating_overlay','_apply_story_fonts','_layout_stack','_acknowledge_visible_line','_apply_preferences','configure_presentation','configure_run_presentation','_sync_transport','_refresh_bilingual_caption','_refresh_self_talk','_project_scene_caption_memory'],
}
try:
 for path,names in specs.items():
  p=root/path;original[p]=p.read_bytes();s=original[p].decode()
  for name in names:
   m=re.search(r'(?m)^(static )?func '+name+r'\((.*?)\) -> (\w+):',s,re.S);assert m,(path,name)
   prefix,args,ret=m.groups();prefix=prefix or '';call=', '.join(re.findall(r'(?:^|,)\s*(\w+)\s*:',args))
   tail=s[m.end():];body=re.split(r'\n(?:static )?func ',tail,maxsplit=1)[0]
   asynchronous=any('await ' in line and not line.lstrip().startswith('#') for line in body.splitlines())
   invoke=('await ' if asynchronous else '')+name+'_profiled('+call+')'
   label=path+':'+name
   wrapper=m.group()+'\n\tvar _probe_start := Time.get_ticks_usec()\n\t'+(('var _probe_result = '+invoke) if ret!='void' else invoke)+'\n\tprint("VISIBLE_SPAN ", JSON.stringify({"name":"'+label+'","start_us":_probe_start,"end_us":Time.get_ticks_usec()}))\n'+ ('\treturn _probe_result\n' if ret!='void' else '')+'\n'+prefix+'func '+name+'_profiled('+args+') -> '+ret+':'
   s=s[:m.start()]+wrapper+s[m.end():]
  p.write_text(s)
 for i in range(2):
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/f'deep-user{i}'))
  log=out/f'deep-{i}.log'
  with log.open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'milestones.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
  text=log.read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-4000:]
  caption=json.loads(next(l.split(' ',1)[1] for l in text.splitlines() if l.startswith('FIRST_CAPTION ')))
  spans=[json.loads(l.split(' ',1)[1]) for l in text.splitlines() if l.startswith('VISIBLE_SPAN ')]
  spans=[s for s in spans if s['end_us']>=caption['click_us'] and s['start_us']<=caption['caption_us']]
  result={'caption':caption,'warning':'WARNING:' in text,'spans':spans};(out/f'deep-{i}.json').write_text(json.dumps(result,indent=2))
  print('PROFILE',i,'caption_ms',(caption['caption_us']-caption['click_us'])/1000,flush=True)
  for s in sorted(spans,key=lambda x:x['start_us']):
   if s['end_us']-s['start_us']>=1000:print(s['name'],round((s['start_us']-caption['click_us'])/1000,3),round((s['end_us']-s['start_us'])/1000,3),flush=True)
finally:
 for p,data in original.items():p.write_bytes(data)
