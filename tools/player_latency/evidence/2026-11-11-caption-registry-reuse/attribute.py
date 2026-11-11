import os,pathlib,subprocess,re,json
root=pathlib.Path.cwd();out=root/'.godot/ci/registry-reuse';p=root/'scripts/narrative/NarrativeCaptionLedger.gd';original=p.read_bytes()
try:
 s=original.decode()
 for name,call in [('initialize','session_token, frozen_context, entry_manifest, registry, entry_contexts_required, scene, registration'),('prepare_registration','entry_manifest, registry')]:
  pattern=r'(static )?func '+name+r'\((.*?)\) -> Dictionary:'
  match=re.search(pattern,s,re.S);assert match
  prefix=match.group(1) or '';args=match.group(2)
  wrapper=f'{prefix}func {name}({args}) -> Dictionary:\n\tvar tick := Time.get_ticks_usec()\n\tvar result := {name}_measured({call})\n\tprint("REGISTRY_SPAN {name} ", Time.get_ticks_usec()-tick)\n\treturn result\n\n{prefix}func {name}_measured({args}) -> Dictionary:'
  s=s[:match.start()]+wrapper+s[match.end():]
 p.write_text(s)
 env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',DWM_EARLY_COMPUTER='normal',XDG_DATA_HOME=str(out/'attribute-user'))
 with (out/'attribute.log').open('w') as f:r=subprocess.run(['godot','--headless','--path',str(root),'--script',str(out/'observe.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 text=(out/'attribute.log').read_text();assert r.returncode==0 and 'ERROR:' not in text,text[-3000:]
 print('\n'.join(line for line in text.splitlines() if line.startswith('REGISTRY_SPAN')))
finally:p.write_bytes(original)
