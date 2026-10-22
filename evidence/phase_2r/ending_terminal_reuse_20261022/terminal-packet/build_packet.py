"""Prepare inert terminal-reuse packet; no engine execution or remote mutation."""
from pathlib import Path
import argparse, ast, difflib, hashlib, json, re, shutil

p = Path(__file__).parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--product', default='REVIEWED_PRODUCT_COMMIT_REQUIRED')
parser.add_argument('--assets', default='REVIEWED_ASSET_COMMIT_REQUIRED')
args = parser.parse_args()
for value, placeholder in [(args.product,'REVIEWED_PRODUCT_COMMIT_REQUIRED'),(args.assets,'REVIEWED_ASSET_COMMIT_REQUIRED')]:
    assert value == placeholder or re.fullmatch('[a-f0-9]{40}', value)
base = Path('/workspace/scratch/4c77836a140f/ending-equality-packet')
workflow_base = p.parent/'session/controller.yml'
candidate = p.parent/'terminal-candidate'
tests = p.parent/'terminal-tests'
root = 'evidence/phase_2r/ending_terminal_reuse_20261022'

def receipt(path, data):
    return {'path':path,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
            'blob':hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()}

sources = json.loads((base/'source-manifest.json').read_text())
changed = json.loads((candidate/'manifest.json').read_text())
assert len(changed)==1 and changed[0]['path']=='scripts/domain/narrative/SceneEventContract.gd'
for row in changed:
    assert receipt(row['path'],(candidate/row['path']).read_bytes())==row
    next(old for old in sources if old['path']==row['path']).update(row)
test_path = 'tests/unit/test_scene_terminal_lifecycle.gd'
sources.append(receipt(test_path,(tests/test_path).read_bytes()))
assert len(sources)==15 and len({r['path'] for r in sources})==15
(p/'source-manifest.json').write_text(json.dumps(sources,indent=2)+'\n')

manifest=[]
for old in json.loads((base/'manifest.json').read_text()):
    name=Path(old['path']).name
    data=(base/name).read_bytes()
    assert receipt(old['path'],data)==old
    if name=='Invoke-SceneContractRegression.ps1':
        text=data.decode()
        before="$scripts = @('tests/unit/test_scene_event_contract.gd', 'tests/unit/test_scene_receipt_validation.gd')"
        after=before[:-1]+", 'tests/unit/test_scene_terminal_lifecycle.gd')"
        assert text.count(before)==1
        text=text.replace(before,after)
        data=text.encode()
    (p/name).write_bytes(data)
    manifest.append(receipt(old['path'],data))
(p/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

prep=(base/'prepare_caption.py').read_text()
prep=re.sub(r'PRODUCT = "[a-f0-9]{40}"','PRODUCT = "'+args.product+'"',prep)
tree=ast.parse(prep)
node=next(n for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='OBSERVATION_SOURCES' for t in n.targets))
lines=prep.splitlines(True)
lines[node.lineno-1:node.end_lineno]=['OBSERVATION_SOURCES = '+json.dumps({r['path']:{'blob':r['blob'],'sha256':r['sha256']} for r in sources},indent=4)+'\n']
(p/'prepare_caption.py').write_text(''.join(lines))

def strip_pins(text):
    tree=ast.parse(text)
    tree.body=[n for n in tree.body if not (isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('PRODUCT','OBSERVATION_SOURCES') for t in n.targets))]
    return ast.dump(tree)
assert strip_pins(prep)==strip_pins((p/'prepare_caption.py').read_text())

w=workflow_base.read_text()
w=w.replace('name: Restored ending validation profile diagnostic','name: Terminal bundle reuse and restored ending qualification')
w=w.replace('4278756add50ea27da8237106260a0efee606cda',args.product)
w=w.replace('b36f5b6773a754bc33a7e9b5c591316b622b426b',args.assets)
w=w.replace('evidence/phase_2r/ending_equality_reuse_20261022',root)
w=re.sub(r'PREPARATION_SHA256: [a-f0-9]{64}','PREPARATION_SHA256: '+hashlib.sha256((p/'prepare_caption.py').read_bytes()).hexdigest(),w)
w=re.sub(r'HARNESS_MANIFEST_SHA256: [a-f0-9]{64}','HARNESS_MANIFEST_SHA256: '+hashlib.sha256((p/'manifest.json').read_bytes()).hexdigest(),w)
old_workflow=(base/'controller.yml').read_text()
unit=old_workflow[old_workflow.index('      - name: Focused scene contract unit regression\n'):old_workflow.index('      - name: Rendered Day4 restore through durable ending and Title\n')]
focused='      - name: Rendered Day4 restore through durable ending and Title\n'
assert w.count(focused)==1
w=w.replace(focused,unit+focused)
old_condition="if: always() && (steps.focused.outcome == 'success' || steps.focused.outcome == 'failure' || steps.focused.outcome == 'cancelled')"
new_condition="if: always() && (steps.contract_regression.outcome == 'success' || steps.contract_regression.outcome == 'failure' || steps.contract_regression.outcome == 'cancelled' || steps.focused.outcome == 'success' || steps.focused.outcome == 'failure' || steps.focused.outcome == 'cancelled')"
assert w.count(old_condition)==1
w=w.replace(old_condition,new_condition)
(p/'controller.yml').write_text(w)
assert w.count('DWM_SCENE_VALIDATION_PROFILE')==1 and "DWM_SCENE_VALIDATION_PROFILE: '1'" in w
assert 'DWM_CHECKPOINT_PROFILE' not in w
assert w.index('id: contract_regression')<w.index('id: focused')
assert w.count(args.product)==2 and w.count(args.assets)==1
assert "timeout-minutes: 8" in unit
patch=''
for name in ['Invoke-SceneContractRegression.ps1','manifest.json','prepare_caption.py','source-manifest.json','controller.yml']:
    old=workflow_base if name=='controller.yml' else base/name
    patch+=''.join(difflib.unified_diff(old.read_text().splitlines(True),(p/name).read_text().splitlines(True),fromfile='baseline/'+name,tofile='terminal/'+name))
(p/'packet.patch').write_text(patch)
summary={'product':args.product,'assets':args.assets,'source_pins':len(sources),'harnesses':len(manifest),
         'workflow':receipt('.github/workflows/scene-first-reveal-profile-diagnostic.yml',w.encode()),
         'preparation':receipt(root+'/prepare_caption.py',(p/'prepare_caption.py').read_bytes()),
         'unit_scripts':['tests/unit/test_scene_event_contract.gd','tests/unit/test_scene_receipt_validation.gd',test_path],
         'new_terminal_cases':re.findall(r'^func (test_\w+)\(', (tests/test_path).read_text(), re.M)}
(p/'packet-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
