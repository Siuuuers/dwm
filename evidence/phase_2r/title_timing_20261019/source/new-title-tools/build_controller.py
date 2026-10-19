"""Render the review-only controller; installing it on PR30 is a separate gated action."""
import argparse, pathlib, yaml
P='evidence/phase_2r/title_timing_20261019/source'
GAME='81847d8b1560340a3a7769223cee0b46c6bdc0f9'
def render(source_sha, old):
    prior=yaml.safe_load(pathlib.Path(old).read_text())['jobs']['authority-audit']['steps']
    steps=[{'name':'Preserve source bytes','run':'git config --global core.autocrlf false'},
      {'uses':'actions/checkout@v7','with':{'ref':GAME,'fetch-depth':2}},
      {'uses':'actions/checkout@v7','with':{'ref':source_sha,'path':'.godot/title-packet','sparse-checkout':P,'persist-credentials':True}},
      {'uses':'actions/setup-python@v6','with':{'python-version':'3.12.10','architecture':'x64'}},
      {'name':'Bind exact sources and retained corrected evidence','run':'''$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force .godot/ci | Out-Null
foreach ($repo in @($env:GITHUB_WORKSPACE,(Join-Path $env:GITHUB_WORKSPACE '.godot/title-packet'))) {
 git -C $repo update-index --force-remove -- .claude/skills/godot-prompter/1.10.0 .claude/skills/superpowers/6.1.1
 if ($LASTEXITCODE -ne 0) { throw 'Legacy gitlink cleanup failed' }
 git -C $repo submodule foreach --recursive 'true'
 if ($LASTEXITCODE -ne 0) { throw 'Gitlink cleanup verification failed' }
}
git fetch --no-tags --depth=1 origin d37ad1f6d3c0148205c1b4d21444d05d01e7cca6 400d279ff884328b3665e8b97533115aa148a47a
if ($LASTEXITCODE -ne 0) { throw 'Pinned source fetch failed' }
$toolRoot = Join-Path $env:GITHUB_WORKSPACE '.godot/title-packet/'''+P+'''/new-title-tools'
"TITLE_TOOLS=$toolRoot" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
@'
import hashlib,pathlib,subprocess,zipfile,json
out=pathlib.Path('.godot/ci')
raw=subprocess.check_output(['git','show','400d279ff884328b3665e8b97533115aa148a47a:evidence/phase_2r/ending_iterator_comparison_20261019/corrected-evidence.zip'])
assert len(raw)==3642930 and hashlib.sha256(raw).hexdigest()=='434e94bb800e99d702d3322cf067d4deb76a50cd04b4b7b425956c96b923fd72'
archive=out/'original-corrected-evidence.zip';archive.write_bytes(raw)
with zipfile.ZipFile(archive) as z:
    assert not z.testzip()
    for x in z.infolist():
        p=pathlib.PurePosixPath(x.filename)
        assert not p.is_absolute() and '..' not in p.parts and ':' not in x.filename and '\\\\' not in x.filename
    z.extractall(out/'retained-corrected')
(out/'origin.json').write_text(json.dumps({'game_commit':'81847d8b1560340a3a7769223cee0b46c6bdc0f9','tool_commit':'SOURCE_SHA','controller_event':'${{ github.event.pull_request.head.sha }}','retained_run':39243496974,'retained_package_artifact':12184205891,'engine_rebuilt':False,'diagnostic_only':True,'official_acceptance_established':False},indent=2))
'@ | python -
if ($LASTEXITCODE -ne 0) { throw 'Retained evidence pin failed' }
'''.replace('SOURCE_SHA',source_sha)},
      {'name':'Download retained Corrected executable package','uses':'actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093','with':{'artifact-ids':'12184205891','run-id':'39243496974','github-token':'${{ github.token }}','repository':'Siuuuers/dwm','path':'.godot/corrected-package'}},
      {'name':'Focused transformation and package tests','run':'''python -m unittest discover -s "$env:TITLE_TOOLS" -p 'test_*.py' -v 2>&1 | Tee-Object .godot/ci/python-tests.log
if ($LASTEXITCODE -ne 0) { throw 'Focused tests failed' }
'''}]
    # Reuse exact official editor installation from the product workflow.
    windows=yaml.safe_load(pathlib.Path(__file__).resolve().parents[1].joinpath('.github/workflows/windows-tests.yml').read_text())
    install=next(s for j in windows['jobs'].values() for s in j.get('steps',[]) if s.get('name')=='Install Godot 4.6.3 standard')
    steps.append(install)
    steps += [{'name':'Apply isolated timing overlay and parse PowerShell','run':'''$overlay=Join-Path $env:RUNNER_TEMP 'title-timing-overlay'
python "$env:TITLE_TOOLS/prepare_source.py" --root $env:GITHUB_WORKSPACE --output $overlay
if ($LASTEXITCODE -ne 0) { throw 'Source overlay failed' }
Copy-Item $overlay .godot/ci/source-overlay -Recurse
$records=@()
foreach ($p in @('tools/testing/Invoke-ExportedGameplay.ps1',"$env:TITLE_TOOLS/Smoke-TimingPackage.ps1")) {
  $tokens=$null; $errors=$null
  $null=[Management.Automation.Language.Parser]::ParseFile([IO.Path]::GetFullPath($p),[ref]$tokens,[ref]$errors)
  $records+=@{path=$p;errors=@($errors | ForEach-Object {$_.Message})}
}
$records | ConvertTo-Json -Depth 5 | Set-Content .godot/ci/powershell-parse.json
if (@($records | Where-Object {$_.errors.Count -gt 0}).Count) { throw 'PowerShell parse failed' }
& pwsh -NoProfile -File tests/tooling/Test-ExportedGameplayDeadline.ps1 -DriverPath tools/testing/Invoke-ExportedGameplay.ps1 -OutputPath .godot/ci/deadline-tests.json
if ($LASTEXITCODE -ne 0) { throw 'Deadline checks failed' }
'''},
      {'name':'Import and export diagnostic PCK with official standard editor','timeout-minutes':12,'run':'''$ErrorActionPreference='Stop'
$env:APPDATA=Join-Path $env:RUNNER_TEMP 'title-export-user/appdata'
$env:LOCALAPPDATA=Join-Path $env:RUNNER_TEMP 'title-export-user/localappdata'
New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
& $env:GODOT_CONSOLE_PATH --headless --path $env:GITHUB_WORKSPACE --import --log-file "$env:GITHUB_WORKSPACE/.godot/ci/import.log"
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
Copy-Item .godot/ci/source-overlay/project.export.godot project.godot -Force
& $env:GODOT_CONSOLE_PATH --headless --path $env:GITHUB_WORKSPACE --export-pack 'Windows Desktop' "$env:GITHUB_WORKSPACE/.godot/ci/DWM.pck" --log-file "$env:GITHUB_WORKSPACE/.godot/ci/export.log"
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic pack export failed' }
foreach ($log in @('.godot/ci/import.log','.godot/ci/export.log')) {
  if (Select-String $log -Pattern 'SCRIPT ERROR:|^\\s*ERROR:|STARTUP_FAILED|Unicode parsing error|Unexpected NUL character' -Quiet) { throw 'Strict editor error gate failed' }
}
Copy-Item .godot/ci/source-overlay/project.original.godot project.godot -Force
@'
import hashlib,json,pathlib
import subprocess
out=pathlib.Path('.godot/ci');p=out/'DWM.pck';m=json.loads((out/'source-overlay/timing-inventory.json').read_text())
for entry in m['files']:
    assert hashlib.sha256(pathlib.Path(entry['path']).read_bytes()).hexdigest()==entry['after_sha256'], 'Instrumented source changed during import/export'
allowed={e['path'] for e in m['files']}|{'tools/testing/Invoke-ExportedGameplay.ps1','.claude/skills/godot-prompter/1.10.0','.claude/skills/superpowers/6.1.1'}
assert set(subprocess.check_output(['git','diff','HEAD','--name-only'],text=True).splitlines())<=allowed, 'Unexpected tracked source mutation'
assert pathlib.Path('project.godot').read_bytes()==(out/'source-overlay/project.original.godot').read_bytes()
m['fresh_pck']={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()};(out/'source-manifest.json').write_text(json.dumps(m,indent=2))
'@ | python -
if ($LASTEXITCODE -ne 0) { throw 'Fresh pack source receipt failed' }
'''},
      {'name':'Prepare and smoke reused engine with new diagnostic pack','id':'package','timeout-minutes':5,'run':'''$packages=@(Get-ChildItem .godot/corrected-package -Recurse -Filter DWM-windows-x86_64-diagnostic.zip -File)
if ($packages.Count -ne 1) { throw 'Expected one retained corrected package' }
python "$env:TITLE_TOOLS/package_timing.py" prepare --original $packages[0].FullName --evidence .godot/ci/retained-corrected --pck .godot/ci/DWM.pck --source-manifest .godot/ci/source-manifest.json --output .godot/ci/title-package
if ($LASTEXITCODE -ne 0) { throw 'Retained engine/package verification failed' }
& pwsh -NoProfile -File "$env:TITLE_TOOLS/Smoke-TimingPackage.ps1" -OutputPath .godot/ci/title-package
if ($LASTEXITCODE -ne 0) { throw 'Fresh diagnostic startup failed' }
python "$env:TITLE_TOOLS/package_timing.py" finish --output .godot/ci/title-package --smoke-result .godot/ci/title-package/smoke-result.json
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic sealing failed' }
$receipt=Get-Content .godot/ci/title-package/validation.json -Raw | ConvertFrom-Json
"DWM_EXPORT_SHA=$($receipt.archive.sha256)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
'''},
      {'name':'Retain diagnostic package before journey','uses':'actions/upload-artifact@v4','with':{'name':'title-timing-package-${{ github.run_id }}-${{ github.run_attempt }}','path':'.godot/ci/title-package/DWM-windows-x86_64-diagnostic.zip','include-hidden-files':True,'if-no-files-found':'error','retention-days':7}}]
    for step_id in ['capability','create','load']:
        step=next(s.copy() for s in prior if s.get('id')==step_id)
        step['run']=step['run'].replace('.godot/ci/native-diagnostic/', '.godot/ci/title-package/')
        if step_id=='load':
            step['run']=step['run'].replace('$watch = [Diagnostics.Stopwatch]::StartNew()',"$env:DWM_TITLE_TIMING_PATH=Join-Path $env:GITHUB_WORKSPACE '.godot/ci/title-timing.jsonl'\n$watch = [Diagnostics.Stopwatch]::StartNew()")
            step['run']=step['run'].replace('Remove-Item Env:GODOT_ACCESSKIT_CONSUMER_TRACE_PATH','Remove-Item Env:DWM_TITLE_TIMING_PATH\n  Remove-Item Env:GODOT_ACCESSKIT_CONSUMER_TRACE_PATH')
        steps.append(step)
    steps += [{'name':'Preserve original outcome and timing limitations','if':'always()','run':'''$failures=[Collections.Generic.List[string]]::new()
foreach ($mode in @('capability','create','load')) {
 $p=".godot/ci/exported-$mode/result.json"
 if (-not (Test-Path $p)) { $failures.Add("Missing $mode result"); continue }
 $r=Get-Content $p -Raw | ConvertFrom-Json
 if (-not $r.ok -or -not $r.clean_player_exit -or $r.forced_cleanup -or $r.exit_code -ne 0) {$failures.Add("$mode original gate failed")}
}
@{ok=($failures.Count -eq 0);diagnostic_only=$true;official_acceptance_established=$false;failures=$failures.ToArray();interpretation='Separate game readiness, native acquisition, durable snapshot and clean exit. Missing timing anchors remain inconclusive.'} | ConvertTo-Json -Depth 5 | Set-Content .godot/ci/diagnostic-outcome.json
if ($failures.Count) { throw ($failures -join '; ') }
'''},
      {'name':'Seal diagnostic evidence','if':'always()','run':'''@'
import hashlib,json,pathlib
root=pathlib.Path('.godot/ci'); files=[]
for p in sorted(root.rglob('*')):
    if p.is_file() and p.name!='timing-evidence-manifest.json' and not any(part in ('package','smoke-user','retained-corrected') for part in p.relative_to(root).parts) and p.suffix not in ('.zip','.pck'):
        files.append({'path':p.relative_to(root).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(root/'timing-evidence-manifest.json').write_text(json.dumps({'files':files},indent=2))
'@ | python -
if ($LASTEXITCODE -ne 0) { throw 'Evidence seal failed' }
'''},
      {'name':'Retain original timing evidence','if':'always()','uses':'actions/upload-artifact@v4','with':{'name':'title-timing-evidence-${{ github.run_id }}-${{ github.run_attempt }}','path':'.godot/ci/\n!.godot/ci/**/package/**\n!.godot/ci/**/smoke-user/**\n!.godot/ci/retained-corrected/**\n!.godot/ci/**/*.zip\n!.godot/ci/**/*.pck','include-hidden-files':True,'if-no-files-found':'error','retention-days':7}}]
    return yaml.safe_dump({'name':'Bounded ending Title timing diagnostic','on':{'pull_request':{'paths':['.github/workflows/scene-first-reveal-profile-diagnostic.yml']}},'permissions':{'contents':'read','actions':'read'},'concurrency':{'group':'scene-first-reveal-profile-${{ github.event.pull_request.number }}','cancel-in-progress':True},'jobs':{'authority-audit':{'if':"github.event.pull_request.number == 30 && github.event.pull_request.head.repo.full_name == 'Siuuuers/dwm'",'runs-on':'windows-2022','timeout-minutes':55,'defaults':{'run':{'shell':'pwsh'}},'steps':steps}}},sort_keys=False,width=120)
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',required=True);p.add_argument('--original-controller',required=True);p.add_argument('--output',required=True);a=p.parse_args();pathlib.Path(a.output).write_text(render(a.source,a.original_controller))
