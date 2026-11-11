import pathlib,subprocess,os
root=pathlib.Path.cwd();out=root/'.godot/ci/dialogue-parse';p=root/'addons/dialogic/Resources/timeline.gd';original=p.read_bytes()
try:
 s=original.decode()
 s=s.replace('\tvar event_cache := DialogicResourceUtil.get_event_cache()', '\tvar _start := Time.get_ticks_usec()\n\tvar _select_us := 0\n\tvar _load_us := 0\n\tvar _kinds := {}\n\tvar event_cache := DialogicResourceUtil.get_event_cache()\n\tvar _cache_us := Time.get_ticks_usec()-_start',1)
 s=s.replace('\t\tvar event: DialogicEvent = event_from_string(event_content, event_cache)','\t\tvar _tick := Time.get_ticks_usec()\n\t\tvar event: DialogicEvent = event_from_string(event_content, event_cache)\n\t\t_select_us += Time.get_ticks_usec()-_tick',1)
 s=s.replace('\t\tevent._load_from_string(event_content)','\t\t_tick = Time.get_ticks_usec()\n\t\tevent._load_from_string(event_content)\n\t\tvar _cost := Time.get_ticks_usec()-_tick\n\t\t_load_us += _cost\n\t\tvar _kind: String = event.get_script().resource_path\n\t\tif not _kinds.has(_kind): _kinds[_kind] = {"count":0,"us":0}\n\t\t_kinds[_kind].count += 1\n\t\t_kinds[_kind].us += _cost',1)
 s=s.replace('\tevents = processed_events','\tprint("PARSE_SPAN ", JSON.stringify({"us":Time.get_ticks_usec()-_start,"cache_us":_cache_us,"select_us":_select_us,"load_us":_load_us,"lines":lines.size(),"kinds":_kinds}))\n\tevents = processed_events',1)
 p.write_text(s)
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/'attribute-user'))
 with (out/'attribute.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=(out/'attribute.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-4000:]
 print('\n'.join(l for l in text.splitlines() if l.startswith('PARSE_SPAN')))
finally:p.write_bytes(original)
