"""Apply only the reviewed timing overlay to a disposable frozen cloud checkout."""
import argparse, hashlib, json, pathlib, subprocess, shutil
from game_patch import generate
from harness_patch import patch
GAME='81847d8b1560340a3a7769223cee0b46c6bdc0f9'
TOOLS='d37ad1f6d3c0148205c1b4d21444d05d01e7cca6'
H='tools/testing/Invoke-ExportedGameplay.ps1'
def sha(b): return hashlib.sha256(b).hexdigest()
def prepare(root,out):
    root,out=pathlib.Path(root).resolve(),pathlib.Path(out).resolve()
    def git(*args): return subprocess.check_output(['git','-C',str(root),*args])
    if git('rev-parse','HEAD').decode().strip()!=GAME: raise ValueError('frozen game HEAD mismatch')
    expected_removals={'D\t.claude/skills/godot-prompter/1.10.0','D\t.claude/skills/superpowers/6.1.1'}
    if not set(git('diff','HEAD','--name-status').decode().splitlines())<=expected_removals: raise ValueError('dirty frozen checkout')
    generate(root,out)
    for entry in json.loads((out/'timing-inventory.json').read_text())['files']:
        p=entry['path']; (root/p).parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(out/p,root/p)
    before=git('show',TOOLS+':'+H)
    after=patch(before.decode()).encode()
    (root/H).write_bytes(after)
    (out/'harness-before.ps1').write_bytes(before); (out/'harness-after.ps1').write_bytes(after)
    (out/'harness-source.json').write_text(json.dumps({'source_commit':TOOLS,'path':H,'before_sha256':sha(before),'after_sha256':sha(after)},indent=2))
    # The established export-only GUT plugin exclusion avoids its network update check.
    # Keep all runtime plugins; record exact export settings and restore after export.
    project=(root/'project.godot').read_bytes()
    (out/'project.original.godot').write_bytes(project)
    text=project.decode(); needle='"res://addons/gut/plugin.cfg", '
    if text.count(needle)!=1:
        needle=', "res://addons/gut/plugin.cfg"'
    if text.count(needle)!=1: raise ValueError('GUT export-only exclusion anchor mismatch')
    exported=text.replace(needle,'',1).encode()
    (out/'project.export.godot').write_bytes(exported)
    (root/'project.godot').write_bytes(exported)
    (out/'export-source.json').write_text(json.dumps({'game_commit':GAME,'game_tree':git('rev-parse',GAME+'^{tree}').decode().strip(),'project_before_sha256':sha(project),'project_export_sha256':sha(exported),'instrumentation_only':True,'official_acceptance_established':False},indent=2))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--root',required=True);p.add_argument('--output',required=True);a=p.parse_args();prepare(a.root,a.output)
