from pathlib import Path
import ast, json, hashlib, re, difflib

p = Path(__file__).parent
base = p.parent / 'ledger-packet'
candidate = p.parent / 'pure-candidate'
tests = p.parent / 'pure-tests'
sources = json.loads((base / 'source-manifest.json').read_text())
changed = json.loads((candidate / 'manifest.json').read_text())
for name in ['tests/unit/test_scene_event_contract.gd', 'tests/unit/test_scene_receipt_validation.gd']:
    b = (tests / name).read_bytes()
    changed.append({'path': name, 'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest(), 'blob': hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest()})
for row in changed:
    previous = next((item for item in sources if item['path'] == row['path']), None)
    if previous is None: sources.append(row)
    else: previous.update(row)
(p / 'source-manifest.json').write_text(json.dumps(sources, indent=2) + '\n')

prep = (base / 'prepare_caption.py').read_text()
prep = re.sub(r'PRODUCT = "[0-9a-f]{40}"', 'PRODUCT = "REVIEWED_PRODUCT_COMMIT_REQUIRED"', prep)
helper = next(row for row in sources if row['path'] == 'scripts/narrative/SceneValidationTiming.gd')
prep = re.sub(r'("scripts/narrative/SceneValidationTiming.gd.uid": ")[0-9a-f]{40}(")', lambda m: m[1] + helper['blob'] + m[2], prep)
tree = ast.parse(prep)
node = next(n for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'OBSERVATION_SOURCES' for t in n.targets))
lines = prep.splitlines(True)
lines[node.lineno-1:node.end_lineno] = ['OBSERVATION_SOURCES = ' + json.dumps({row['path']: {'blob': row['blob'], 'sha256': row['sha256']} for row in sources}, indent=4) + '\n']
(p / 'prepare_caption.py').write_text(''.join(lines))

manifest = json.loads((base / 'manifest.json').read_text())
manifest.append({'path': 'tools/testing/Invoke-SceneContractRegression.ps1'})
for row in manifest:
    b = (p / Path(row['path']).name).read_bytes()
    row.update(bytes=len(b), sha256=hashlib.sha256(b).hexdigest(), blob=hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest())
(p / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

workflow = (base / 'controller.yml').read_text()
product = re.search(r'PRODUCT_SHA: ([a-f0-9]{40})', workflow)[1]
assets = re.search(r'SOURCE_SHA: ([a-f0-9]{40})', workflow)[1]
workflow = workflow.replace(product, 'REVIEWED_PRODUCT_COMMIT_REQUIRED').replace(assets, 'REVIEWED_ASSET_COMMIT_REQUIRED')
workflow = workflow.replace('ending_receipt_bundle_20261022', 'ending_pure_contract_20261022')
workflow = workflow.replace('name: Short ending receipt and bundle validation observation', 'name: Scene contract regression and ending comparison')
marker = '      - name: Always retain and check source after focused tests\n'
assert workflow.count(marker) == 1
regression = '''      - name: Focused scene contract unit regression
        id: contract_regression
        timeout-minutes: 8
        run: |
          $ErrorActionPreference = 'Stop'
          $PSNativeCommandUseErrorActionPreference = $false
          & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $env:FOCUSED_HARNESS 'Invoke-SceneContractRegression.ps1') -RepositoryRoot $env:GITHUB_WORKSPACE -ExpectedSource $env:PRODUCT_SHA
          if ($LASTEXITCODE -ne 0) { throw "CONTRACT_REGRESSION_EXIT: $LASTEXITCODE" }
'''
workflow = workflow.replace(marker, regression + marker)
old = "if: always() && (steps.focused.outcome == 'success' || steps.focused.outcome == 'failure' || steps.focused.outcome == 'cancelled')"
new = "if: always() && (steps.contract_regression.outcome == 'success' || steps.contract_regression.outcome == 'failure' || steps.contract_regression.outcome == 'cancelled' || steps.focused.outcome == 'success' || steps.focused.outcome == 'failure' || steps.focused.outcome == 'cancelled')"
assert old in workflow
workflow = workflow.replace(old, new)
workflow = re.sub(r'PREPARATION_SHA256: [a-f0-9]+', 'PREPARATION_SHA256: ' + hashlib.sha256((p / 'prepare_caption.py').read_bytes()).hexdigest(), workflow)
workflow = re.sub(r'HARNESS_MANIFEST_SHA256: [a-f0-9]+', 'HARNESS_MANIFEST_SHA256: ' + hashlib.sha256((p / 'manifest.json').read_bytes()).hexdigest(), workflow)
(p / 'controller.yml').write_text(workflow)
patch = ''
for name in ['prepare_caption.py', 'Invoke-SceneContractRegression.ps1', 'manifest.json', 'controller.yml', 'source-manifest.json']:
    before = (base / name).read_text().splitlines(True) if (base / name).exists() else []
    patch += ''.join(difflib.unified_diff(before, (p / name).read_text().splitlines(True), fromfile='ledger/' + name, tofile='pure/' + name))
(p / 'packet.patch').write_text(patch)
ast.parse((p / 'prepare_caption.py').read_text())
for name in ['Invoke-EndingLayoutBoundary.ps1', 'Invoke-IsolatedGodot.ps1', 'Get-ContinueFileSha256.ps1']:
    assert (p / name).read_bytes() == (base / name).read_bytes()
assert len(sources) == 12
assert workflow.index('id: focused') < workflow.index('id: contract_regression')
assert "${{ github.workspace }}/.godot/ci" in workflow and "${{ github.workspace }}/.godot/phase2r_logs" in workflow
print('Pure candidate packet prepared with both exact test-source pins and product/assets placeholders.')
