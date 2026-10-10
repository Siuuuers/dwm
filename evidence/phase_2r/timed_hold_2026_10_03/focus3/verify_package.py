#!/usr/bin/env python3
"""Verify delivered archive parts and every retained artifact; report explicit binary exclusions."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
import zipfile

def require(value,label):
 if not value:raise ValueError(label)
def identity(raw):return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
def read_member(tar,name):
 stream=tar.extractfile(name);require(stream is not None,'regular tar member '+name);return stream.read()

def verify(manifest_path,output):
 base=manifest_path.resolve().parent;manifest=json.loads(manifest_path.read_text())
 pieces=manifest['parts'] or [{'file':manifest['archive']['file'],**{k:manifest['archive'][k] for k in ('bytes','sha256')},'offset':0,'index':1}]
 with tempfile.TemporaryFile() as stream:
  h=hashlib.sha256();total=0
  for index,piece in enumerate(pieces,1):
   require(piece['index']==index and piece['offset']==total,'contiguous raw-part order')
   raw=(base/piece['file']).read_bytes();require(identity(raw)=={k:piece[k] for k in ('bytes','sha256')},'exact part identity')
   if manifest['parts']:require(len(raw)<=8*1024*1024,'bounded raw part')
   stream.write(raw);h.update(raw);total+=len(raw)
  require({'bytes':total,'sha256':h.hexdigest()}=={k:manifest['archive'][k] for k in ('bytes','sha256')},'ordered compressed archive identity')
  stream.seek(0)
  with tarfile.open(fileobj=stream,mode='r:gz') as tar:
   members=tar.getmembers();names=[m.name for m in members];require(len(names)==len(set(names))==manifest['archive_members'],'exact unique tar census')
   require(all(m.isfile() for m in members),'regular tar files')
   raw=read_member(tar,'archive-inventory.json');require(identity(raw)==manifest['archive_inventory'],'archive inventory hash')
   inventory=json.loads(raw);require(set(names)=={r['archive_path'] for r in inventory['files']}|{'archive-inventory.json'},'all payloads inventoried')
   for row in inventory['files']:require(identity(read_member(tar,row['archive_path']))=={k:row[k] for k in ('bytes','sha256')},'every archived payload hash')
   raw=read_member(tar,'extraction-inventory.json');require(identity(raw)==manifest['extraction_inventory'],'extraction inventory hash')
   extraction=json.loads(raw);reproduced=[];excluded=[];retained=0
   for artifact in extraction['artifacts']:
    if artifact['original_zip_included']:
     raw=read_member(tar,artifact['archive_path']);require(identity(raw)=={k:artifact[k] for k in ('bytes','sha256')},'archived original ZIP identity')
     with zipfile.ZipFile(io.BytesIO(raw)) as z:
      require(z.testzip() is None,'every retained ZIP member CRC')
      expected={r['member']:r for r in artifact['members']};require(set(z.namelist())==set(expected) and len(z.namelist())==len(expected),'complete retained ZIP members')
      for member in z.infolist():
       row=expected[member.filename]
       if member.is_dir():require(row.get('directory') is True,'directory identity');continue
       require(row['storage']=='original_zip' and row['reproducible_from_repository'] is True,'included ZIP storage policy')
       require(identity(z.read(member))=={k:row[k] for k in ('bytes','sha256')},'every original member reproducible')
       require(f'{member.CRC:08x}'==row['zip_crc32'],'exact member CRC');reproduced.append(row)
     retained+=1
    else:
     require(artifact['archive_path'] is None and artifact['name'].startswith('windows-export-'),'only explicit export artifact omitted')
     for row in artifact['members']:
      if row.get('directory'):continue
      if row['storage']=='direct_export_record':
       require(identity(read_member(tar,row['archive_path']))=={k:row[k] for k in ('bytes','sha256')},'retained raw export record');reproduced.append(row)
      else:
       require(row['storage']=='explicit_binary_exclusion' and row['reproducible_from_repository'] is False and row['reason'],'documented exact binary exclusion');excluded.append(row)
   represented=reproduced+excluded
   require(sorted(represented,key=lambda x:x['capture_path'])==sorted(extraction['extracted_files'],key=lambda x:x['capture_path']),'every extracted member either reproduced or explicitly excluded')
   require(len([n for n in names if n.startswith('original-artifacts/')])==retained,'original ZIPs retained exactly once')
   require(not any(n.startswith('capture/artifacts/') for n in names),'no duplicate raw extraction copy')
 report={'status':'DELIVERY_VERIFIED_WITH_EXPLICIT_STORAGE_LIMITS','run_id':manifest['run_id'],'source':manifest['source'],'workflow_head':manifest['workflow_head'],'actual_checkout':manifest['actual_checkout'],'archive':manifest['archive'],'archive_members_verified':len(names),'included_original_zips_verified':retained,'extracted_files_reproduced':len(reproduced),'binary_members_explicitly_excluded':len(excluded),'excluded_member_identities':excluded,'delivery_only_verification':True,'original_workspace_attachments_not_required':True,'runtime_acceptance_inferred':False,'limits':manifest['limits']}
 output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ('status','included_original_zips_verified','extracted_files_reproduced','binary_members_explicitly_excluded','runtime_acceptance_inferred')}))

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--manifest',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args();verify(args.manifest,args.output)
