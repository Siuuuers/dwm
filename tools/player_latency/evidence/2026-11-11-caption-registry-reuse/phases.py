import hashlib, json, os, pathlib, subprocess
root = pathlib.Path.cwd()
repo = root
source = repo / 'autoload/SaveManager.gd'
out = root / '.godot/ci/registry-reuse'
original = source.read_bytes()
text = original.decode()

def span(body, needle, name, indent='\t'):
    assert body.count(needle) == 1, (name, needle)
    return body.replace(needle, indent + '_probe_tick = Time.get_ticks_usec()\n' + needle + '\n' + indent + 'print("NEW_RUN_SPAN ", JSON.stringify({"name": "' + name + '", "us": Time.get_ticks_usec() - _probe_tick}))', 1)

a = text.index('func _start_scene_new_run_in_memory(')
b = text.index('\nfunc _prepare_scene_new_run_plans(', a)
body = text[a:b]
body = body.replace('\n\tvar target := {}', '\n\tvar _probe_tick := Time.get_ticks_usec()\n\tvar target := {}', 1)
body = body.replace('\n\tvar allocation: Dictionary = allocated.value', '\n\tprint("NEW_RUN_SPAN ", JSON.stringify({"name": "identity", "us": Time.get_ticks_usec() - _probe_tick}))\n\tvar allocation: Dictionary = allocated.value', 1)
body = span(body, '\tvar input: Dictionary = _restore_participants.run.prepare_scene_new_run_snapshot_input(\n\t\tallocation, target.entry_id, operation_id)', 'snapshot_input')
body = span(body, '\tvar reading: Dictionary = _scene_new_run_bridge._build_current_scene_initial_checkpoint(\n\t\tinput.value.snapshot_input.scene, _scene_new_run_bundle)', 'initial_reading')
body = span(body, '\tvar built := RUN_SNAPSHOT_SCHEMA.build_scene(input.value.snapshot_input, reading.value,\n\t\t"scene", null, {}, initial_context.content_version, 1)', 'snapshot_build')
body = span(body, '\tvar profile := {"candidate": _new_run_profile_owner.get_profile_snapshot()}', 'profile_capture')
body = span(body, '\tvar plans := _prepare_scene_new_run_plans(snapshot, allocation, profile)', 'all_plans_inclusive')
needle = '\treturn _run_scene_restore_transaction(plans.value, reset, "scene", snapshot.checkpoint_id,\n\t\tfalse, {"kind": "memory_new_run", "transaction_id": operation_id}, _new_run_gate_token, false)'
assert body.count(needle)==1
body = body.replace(needle, '\t_probe_tick = Time.get_ticks_usec()\n\tvar _probe_result: Dictionary = _run_scene_restore_transaction(plans.value, reset, "scene", snapshot.checkpoint_id,\n\t\tfalse, {"kind": "memory_new_run", "transaction_id": operation_id}, _new_run_gate_token, false)\n\tprint("NEW_RUN_SPAN ", JSON.stringify({"name": "restore_transaction_until_return", "us": Time.get_ticks_usec() - _probe_tick, "code": _probe_result.get("code", "")}))\n\treturn _probe_result')
text = text[:a] + body + text[b:]
a = text.index('func _prepare_scene_new_run_plans(')
b = text.index('\nfunc _resume_scene_new_run(', a)
body = text[a:b]
body = body.replace('\n\tvar run:', '\n\tvar _probe_tick := 0\n\tvar run:', 1)
body = span(body, '\tvar run: Dictionary = _restore_participants.run.prepare_scene_new_run(snapshot, allocation,\n\t\tprofile_material, _scene_new_run_bundle, _identity_issuer, self)', 'plan_run')
body = span(body, '\tvar profile: Dictionary = _restore_participants.profile.prepare_frozen_profile(profile_material.candidate)', 'plan_profile')
body = span(body, '\tvar narrative: Dictionary = _restore_participants.narrative.prepare_scene_new_run(snapshot, allocation,\n\t\tprofile_material, _scene_new_run_bundle, _identity_issuer, self)', 'plan_narrative')
body = span(body, '\tvar audio_context := RUN_SNAPSHOT_SCHEMA.derive_scene_audio_context(audio_snapshot, _scene_new_run_bundle)', 'derive_audio')
needle = '\t\tvar prepared: Dictionary = _restore_participants[key].prepare(inputs[key])'
assert body.count(needle)==1
body = body.replace(needle, '\t\t_probe_tick = Time.get_ticks_usec()\n' + needle + '\n\t\tprint("NEW_RUN_SPAN ", JSON.stringify({"name": "plan_" + key, "us": Time.get_ticks_usec() - _probe_tick}))')
text = text[:a] + body + text[b:]
assert text != original.decode()
try:
    source.write_text(text)
    (out/'candidate-attribution.patch').write_bytes(subprocess.check_output(['git', 'diff', '--', 'autoload/SaveManager.gd'],cwd=repo))
    env = os.environ.copy()
    env.pop('DWM_TEST_ROOT',None)
    env.pop('DWM_EARLY_COMPUTER',None)
    env.update(DWM_STARTUP_AUDIT='1',DWM_CLICK_MODE='settled',XDG_DATA_HOME=str(out/'candidate-attribution-user'))
    assert not pathlib.Path(env['XDG_DATA_HOME']).exists(), 'Need fresh profile'
    with (out/'candidate-attribution.log').open('w') as log:
        result = subprocess.run(['godot','--headless','--path',str(repo),'--script',str(root/'.godot/ci/registry-reuse/observe.gd')],cwd=repo,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
    log=(out/'candidate-attribution.log').read_text()
    print('exit',result.returncode)
    for line in log.splitlines():
        if line.startswith('NEW_RUN_SPAN'): print(line)
        if line.startswith('FIRST_CAPTION'):
            row=json.loads(line.split('FIRST_CAPTION ',1)[1]); print('FIRST_CAPTION', {k:v for k,v in row.items() if k!='trace'})
    assert result.returncode==0 and 'SCRIPT ERROR' not in log and 'ERROR:' not in log and 'FIRST_CAPTION ' in log, log[-5000:]
finally:
    source.write_bytes(original)
    assert hashlib.sha256(source.read_bytes()).digest()==hashlib.sha256(original).digest()
