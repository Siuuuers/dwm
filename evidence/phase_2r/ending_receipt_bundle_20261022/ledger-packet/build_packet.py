from pathlib import Path
import ast, json, hashlib, re, difflib

p = Path(__file__).parent
base = Path('/workspace/scratch/ba996ff67192/physical-proof-packet')
candidate = p.parent / 'ledger-candidate'
new = json.loads((candidate / 'manifest.json').read_text())
sources = json.loads((base / 'source-manifest.json').read_text())
for item in new:
    previous = next((row for row in sources if row['path'] == item['path']), None)
    if previous is None:
        sources.append(item)
    else:
        previous.update(item)
(p / 'source-manifest.json').write_text(json.dumps(sources, indent=2) + '\n')

helper = next(row for row in sources if row['path'] == 'scripts/narrative/SceneValidationTiming.gd')
prep = (base / 'prepare_caption.py').read_text().replace('5a506a9768287762b2a0e86f94d5eb0006562cc5', 'REVIEWED_PRODUCT_COMMIT_REQUIRED')
prep = prep.replace('b422d142ced6c6f65910758501d87fd79e8ad7f7', helper['blob'])
tree = ast.parse(prep)
node = next(n for n in tree.body if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'OBSERVATION_SOURCES' for t in n.targets))
lines = prep.splitlines(True)
lines[node.lineno-1:node.end_lineno] = ['OBSERVATION_SOURCES = ' + json.dumps({row['path']: {'blob': row['blob'], 'sha256': row['sha256']} for row in sources}, indent=4) + '\n']
(p / 'prepare_caption.py').write_text(''.join(lines))

runner = (base / 'Invoke-EndingLayoutBoundary.ps1').read_text()
runner = runner.replace("'autoload/ProfileManager.gd'))", "'autoload/ProfileManager.gd', 'scripts/domain/narrative/SceneEventContract.gd'))")
runner = runner.replace('short-route physical assignment proof observation', 'short-route receipt and bundle validation observation')
runner = runner.replace("'physical_proof_failures')\n    $stages", "'physical_proof_failures','receipt_validation_calls','receipt_validation_us','receipt_validation_failures','bundle_validation_calls','bundle_validation_us','bundle_validation_failures')\n    $stages")
needle = '            $snapshotRecords = $record.snapshot_validations\n'
assert runner.count(needle) == 1
added = '''            foreach ($kind in @('receipt_validation','bundle_validation')) {
                foreach ($suffix in @('calls','us','failures')) {
                    $field = $kind + '_' + $suffix
                    $value = $record.$field
                    if (($value -isnot [int] -and $value -isnot [long] -and $value -isnot [bigint]) -or $value -lt 0) { throw "ENDING_VALIDATION_INTEGER_INVALID: $field" }
                }
                $calls = $record.($kind + '_calls')
                $duration = $record.($kind + '_us')
                $failures = $record.($kind + '_failures')
                if ($failures -ne 0 -or ($calls -eq 0 -and $duration -ne 0)) { throw "ENDING_VALIDATION_RESULT_INVALID: $kind" }
                if (($operation -cne 'capture' -and $calls -eq 0) -or $duration -gt $record.elapsed_us) { throw "ENDING_VALIDATION_WITNESS_OR_NESTING_INVALID: $kind" }
            }
            # Counts remain observations. Parent/leaf totals overlap; never add them.
            # Neither observed function recursively invokes itself on this path.
'''
runner = runner.replace(needle, added + needle)
(p / 'Invoke-EndingLayoutBoundary.ps1').write_text(runner)

manifest = json.loads((base / 'manifest.json').read_text())
for row in manifest:
    b = (p / Path(row['path']).name).read_bytes()
    row.update(bytes=len(b), sha256=hashlib.sha256(b).hexdigest(), blob=hashlib.sha1(b'blob ' + str(len(b)).encode() + b'\0' + b).hexdigest())
(p / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
workflow = (base / 'controller.yml').read_text().replace('5a506a9768287762b2a0e86f94d5eb0006562cc5', 'REVIEWED_PRODUCT_COMMIT_REQUIRED').replace('517a647f97a075769bf94f8b6469f76ec024ae86', 'REVIEWED_ASSET_COMMIT_REQUIRED')
workflow = workflow.replace('physical assignment proof observation', 'receipt and bundle validation observation').replace('ending_physical_proof_20261022', 'ending_receipt_bundle_20261022')
workflow = re.sub(r'PREPARATION_SHA256: [a-f0-9]+', 'PREPARATION_SHA256: ' + hashlib.sha256((p / 'prepare_caption.py').read_bytes()).hexdigest(), workflow)
workflow = re.sub(r'HARNESS_MANIFEST_SHA256: [a-f0-9]+', 'HARNESS_MANIFEST_SHA256: ' + hashlib.sha256((p / 'manifest.json').read_bytes()).hexdigest(), workflow)
(p / 'controller.yml').write_text(workflow)
patch = ''
for name in ['prepare_caption.py', 'Invoke-EndingLayoutBoundary.ps1', 'manifest.json', 'controller.yml', 'source-manifest.json']:
    patch += ''.join(difflib.unified_diff((base / name).read_text().splitlines(True), (p / name).read_text().splitlines(True), fromfile='physical-proof/' + name, tofile='ledger/' + name))
(p / 'packet.patch').write_text(patch)
ast.parse((p / 'prepare_caption.py').read_text())
assert len(sources) == 10
assert helper['blob'] in (p / 'prepare_caption.py').read_text().split('OBSERVATION_SOURCES')[0]
assert "'scripts/domain/narrative/SceneEventContract.gd'))" in runner
assert "'bundle_validation_failures')\n    $stages" in runner
for name in ['Invoke-IsolatedGodot.ps1', 'Get-ContinueFileSha256.ps1']:
    assert (p / name).read_bytes() == (base / name).read_bytes()
print('Paired observation packet prepared; product/assets placeholders remain.')
