import pathlib,subprocess,os,re
root=pathlib.Path.cwd();out=root/'.godot/ci/newgame-owners';original={}
try:
 p=root/'scripts/narrative/DialogicRuntimeAdapter.gd';original[p]=p.read_bytes();s=original[p].decode()
 for name,call in [('_parse_scene_programme_source','text'),('_compile_scene_programme_timeline','timeline, text, entry_label, callable_labels, markers')]:
  m=re.search(r'static func '+name+r'\((.*?)\) -> (\w+):',s,re.S);assert m
  args,ret=m.groups();header=m.group();s=s[:m.start()]+header+'\n\tvar tick := Time.get_ticks_usec()\n\tvar result := '+name+'_measured('+call+')\n\tprint("DEEP '+name+' ", Time.get_ticks_usec()-tick)\n\treturn result\n\nstatic func '+name+'_measured('+args+') -> '+ret+':'+s[m.end():]
 p.write_text(s)
 p=root/'scripts/narrative/SoloReadingSession.gd';original[p]=p.read_bytes();s=original[p].decode()
 s=s.replace('\t\tvar compiled_catalogue := {}','\t\tvar tick := Time.get_ticks_usec()\n\t\tvar compiled_catalogue := {}',1)
 s=s.replace('\t\tvar registration := LEDGER.prepare_registration','\t\tprint("DEEP catalogue ", Time.get_ticks_usec()-tick)\n\t\ttick = Time.get_ticks_usec()\n\t\tvar registration := LEDGER.prepare_registration',1)
 s=s.replace('\t\tFROZEN._freeze(prepared)','\t\tprint("DEEP registration ", Time.get_ticks_usec()-tick)\n\t\ttick = Time.get_ticks_usec()\n\t\tFROZEN._freeze(prepared)\n\t\tprint("DEEP freeze ", Time.get_ticks_usec()-tick)',1);p.write_text(s)
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/'deep-user'))
 with (out/'deep.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=(out/'deep.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-4000:]
 print('\n'.join(l for l in text.splitlines() if l.startswith('DEEP')))
finally:
 for p,data in original.items():p.write_bytes(data)
