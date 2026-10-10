from pathlib import Path
import hashlib,json,re,subprocess,zipfile

BASE=Path('/workspace/scratch/e58f796fe7a3')
ROOT=BASE/'hospital-broad2'
OUT=BASE/'hospital-broad2-export-audit'
SOURCE='a24f71766a624b57601814dda487b53c66518c39'
HEAD='c9c013397f2e309b48fc1548490b401e54938c6c'
checks=[]
def check(value,name):
    if not value: raise AssertionError(name)
    checks.append(name)
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def ident(path):
    with path.open('rb') as stream: digest=hashlib.file_digest(stream,'sha256').hexdigest()
    return {'bytes':path.stat().st_size,'sha256':digest}

jobs=read(ROOT/'jobs.json')['jobs'];job=next(j for j in jobs if j['name']=='Windows / exported release startup')
check(job['id']==110976704690 and job['conclusion']=='success','exact successful export job')
log=(ROOT/'logs'/f"{job['id']}.log").read_text(encoding='utf-8-sig')
lines=[re.sub(r'^\d{4}-[^ ]+Z\s*','',re.sub(r'\x1b\[[0-9;]*m','',line)).strip() for line in log.splitlines()]
checkout=[lines[i+1] for i,line in enumerate(lines[:-1]) if 'log -1 --format=%H' in line]
check(checkout==[HEAD],'actual checkout equals expected workflow head')
row=next(r for r in read(ROOT/'artifact-manifest.json') if r['id']==11245855941)
api=next(r for r in read(ROOT/'artifacts-api.json')['artifacts'] if r['id']==row['id'])
check(all(row[k]==api[k] for k in ['id','name','digest','size_in_bytes','workflow_run']),'original artifact metadata identity')
check(ident(Path(row['local_zip']))=={'bytes':row['size_in_bytes'],'sha256':row['digest'].removeprefix('sha256:')},'original ZIP API size and SHA256')
artifact=ROOT/'artifacts'/row['name'];folder=artifact/'windows-export'
with zipfile.ZipFile(row['local_zip']) as z:
    check(z.testzip() is None and len(z.infolist())==11,'outer ZIP all CRCs and member count')
    for member in z.infolist():
        check((artifact/member.filename).read_bytes()==z.read(member),'exact outer extracted bytes '+member.filename)
transport=read(BASE/'hospital-export2-transport-capture/reassembly-receipt.json')
check(transport['original_artifact']['id']==row['id'] and transport['ordered_reassembly_verified'] and transport['all_chunks_verified'] and transport['zip_crc_verified'],'exact original ZIP transport receipt')
helper_path='tools/testing/Invoke-WindowsExportValidation.ps1'
helper=(BASE/'dwm'/helper_path).read_bytes()
check(all(subprocess.check_output(['git','-C',str(BASE/'dwm'),'show',ref+':'+helper_path])==helper for ref in [SOURCE,HEAD]),'export helper exact source and checkout bytes')
validation=read(folder/'validation.json')
check(validation['ok'] is True and validation['commit']==HEAD,'source-bound successful validation')
check(validation['engine']=='4.6.3.stable' and validation['architecture']=='x86_64' and validation['signed'] is False,'standard engine x86_64 unsigned scope')
check(validation['templates_sha256']=='3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8','exact pinned templates hash')
check(validation['smoke']=={'executable':'DWM.exe','headless':True,'isolated_profile_created':True,'iterations':240,'ok':True},'isolated 240-iteration headless startup')
check(validation['pack_audit']=={'ok':True,'runtime_data_files_verified':111} and validation['runtime_data_files_verified']==111,'111 runtime files pack-audited')
check(validation['export_editor_plugin_exclusion']=='res://addons/gut/plugin.cfg','exact editor plugin exclusion')
files=validation['files'];check(len(files)==17 and len({f['path'] for f in files})==17,'17 unique packaged files')
archive=folder/validation['archive']['file'];check(ident(archive)=={k:validation['archive'][k] for k in ['bytes','sha256']},'nested ZIP identity')
check((folder/'SHA256SUMS.txt').read_text().strip()==validation['archive']['sha256']+'  '+archive.name,'SHA256SUMS exact archive line')
with zipfile.ZipFile(archive) as z:
    check(z.testzip() is None and set(z.namelist())=={f['path'] for f in files}|{'validation.json'} and len(z.infolist())==18,'nested ZIP exact membership and CRC')
    for f in files:
        with z.open(f['path']) as stream: h=hashlib.file_digest(stream,'sha256').hexdigest()
        check(z.getinfo(f['path']).file_size==f['bytes'] and h==f['sha256'],'nested payload identity '+f['path'])
    inner_bytes=z.read('validation.json');inner=json.loads(inner_bytes)
    check(inner=={k:v for k,v in validation.items() if k!='archive'},'inner validation equals outer fields before archive identity append')
receipts=[json.loads(line.split('WINDOWS_EXPORT_RECEIPT ',1)[1]) for line in lines if line.startswith('WINDOWS_EXPORT_RECEIPT ')]
expected={k:validation[k] for k in ['ok','commit','engine','runtime_data_files_verified','templates_sha256','archive']}
expected.update(executable_sha256=next(f['sha256'] for f in files if f['path']=='DWM.exe'),pck_sha256=next(f['sha256'] for f in files if f['path']=='DWM.pck'))
check(receipts==[expected],'exact single export console receipt')
check(sum(line.startswith('WINDOWS_EXPORT_VALIDATED: ') for line in lines)==1,'exact single terminal validation marker')
logs={}
for name in ['version.console.log','export.log','export.console.log','smoke.log','smoke.console.log','pack-audit.log','pack-audit.console.log']:
    path=folder/name;text=path.read_text(encoding='utf-8-sig');check(bool(text.strip()),'nonempty log '+name)
    check(re.search(r'SCRIPT ERROR:|^\s*ERROR:|STARTUP_FAILED|Unicode parsing error|Unexpected NUL character|Resource still in use:|ObjectDB instances leaked',text,re.M) is None,'strict diagnostic scan '+name)
    logs[name]=ident(path)
for name in ['pack-audit.log','pack-audit.console.log']:
    check((folder/name).read_text().count('WINDOWS_PACK_DATA_VERIFIED count=111')==1,'exact pack data marker '+name)
check(re.fullmatch(r'4\.6\.3\.stable\.official\.[a-f0-9]+',(folder/'version.console.log').read_text().strip()) is not None,'engine full version')
audit={'status':'pass_bounded_export_only','source':SOURCE,'checkout':HEAD,'run_id':37048318182,'job_id':job['id'],'artifact':row,'original_zip':ident(Path(row['local_zip'])),'transport':transport,'helper':{'path':helper_path,'sha256':hashlib.sha256(helper).hexdigest()},'validation':validation,'nested_archive':ident(archive),'inner_validation_sha256':hashlib.sha256(inner_bytes).hexdigest(),'logs':logs,'checks':checks,'nonfatal_observations':['Controller mapping misc2 warnings, skipped X509 certificates and Node action deprecation warnings remain; this is not a warning-free claim.'],'limits':['Cloud unsigned Windows export, packaged data and isolated headless startup only.','No executable or engine ran locally.','No graphical Windows, UIA, screen-reader, signing, release or whole-game acceptance.','Original binary ZIP is verified locally and retained by Actions; repository evidence packaging excludes its binary bytes explicitly.']}
(OUT/'windows-export-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
print(json.dumps({'status':audit['status'],'checks':len(checks),'report':str(OUT/'windows-export-audit.json')}))
