import pathlib,subprocess,os,json
root=pathlib.Path.cwd();out=root/'.godot/ci/registration-cost'
paths=['scripts/domain/narrative/SceneEventContract.gd','scripts/narrative/DialogicEntryManifest.gd']
original={p:(root/p).read_bytes() for p in paths}
s=original[paths[0]].decode();start=s.index('static func _validate_bundle_structure_observed_body');end=s.index('\nstatic func bundle_fingerprint',start);body=s[start:end]
body=body.replace('\n\tif not _json_data(bundle):','\n\tvar probe_start := Time.get_ticks_usec()\n\tif not _json_data(bundle):',1)
for needle,label in [('\tvar nested_encodings := {}','header'),('\tvar programme: Variant = bundle.scene_programme','nested_encoding'),('\tvar members: Array = bundle.keys()','structure'),('\tfor registered: Dictionary in markers.values():','remaining_encoding'),('\ttables["markers"] = markers','passages')]:
 assert needle in body
 body=body.replace(needle,'\tprint("REG_COST '+label+' ", Time.get_ticks_usec()-probe_start)\n\tprobe_start = Time.get_ticks_usec()\n'+needle,1)
body=body.replace('\treturn {"ok": true, "value": tables.duplicate(true)}','\tvar result := {"ok": true, "value": tables.duplicate(true)}\n\tprint("REG_COST table_copy_hash ", Time.get_ticks_usec()-probe_start)\n\treturn result')
s=s[:start]+body+s[end:]
m=original[paths[1]].decode();m=m.replace('\tvar structural := SCENE_EVENTS.validate_bundle_structure(bundle)','\tvar probe_start := Time.get_ticks_usec()\n\tvar structural := SCENE_EVENTS.validate_bundle_structure(bundle)',1).replace('\t_scene_contract_tables = structural.value','\tprint("REG_COST validate_total ", Time.get_ticks_usec()-probe_start)\n\tprobe_start = Time.get_ticks_usec()\n\t_scene_contract_tables = structural.value',1).replace('\t_scene_bundle_fingerprint = structural.value.fingerprint','\tprint("REG_COST freeze_copy ", Time.get_ticks_usec()-probe_start)\n\t_scene_bundle_fingerprint = structural.value.fingerprint',1)
try:
 (root/paths[0]).write_text(s);(root/paths[1]).write_text(m)
 for i in range(3):
  env=os.environ.copy();env.pop('DWM_TEST_ROOT',None);env.update(DWM_STARTUP_AUDIT='1',XDG_DATA_HOME=str(out/f'profile-user-{i}'))
  r=subprocess.run(['godot','--headless','--path',str(root),'--script','res://tests/manual/benchmark_player_startup.gd'],env=env,capture_output=True,text=True,timeout=120)
  log=r.stdout+r.stderr;(out/f'profile-{i}.log').write_text(log)
  assert r.returncode==0 and 'ERROR:' not in log,log[-6000:]
  print('\n'.join(l for l in log.splitlines() if l.startswith(('REG_COST','PLAYER_STARTUP'))),flush=True)
finally:
 for p,b in original.items():(root/p).write_bytes(b)
