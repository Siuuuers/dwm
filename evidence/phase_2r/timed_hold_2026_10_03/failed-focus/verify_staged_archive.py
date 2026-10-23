#!/usr/bin/env python3
"""Verify raw-part delivery, every archived payload and original-ZIP extraction identities offline."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
import zipfile

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--manifest',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
base=args.manifest.resolve().parent
manifest=json.loads(args.manifest.read_text())

def require(value,label):
 if not value:raise ValueError(label)
def identity(raw):return {'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
def read_member(tar,name):
 stream=tar.extractfile(name);require(stream is not None,'regular archive member '+name);return stream.read()

pieces=manifest['parts'] or [{'file':manifest['archive']['file'],**{k:manifest['archive'][k] for k in ('bytes','sha256')},'offset':0,'index':1}]
with tempfile.TemporaryFile() as stream:
 h=hashlib.sha256();total=0
 for index,piece in enumerate(pieces,1):
  require(piece['index']==index and piece['offset']==total,'contiguous raw-part order')
  raw=(base/piece['file']).read_bytes()
  require(identity(raw)=={k:piece[k] for k in ('bytes','sha256')},'exact raw-part identity')
  if manifest['parts']:require(len(raw)<=8*1024*1024,'bounded raw part')
  stream.write(raw);h.update(raw);total+=len(raw)
 require({'bytes':total,'sha256':h.hexdigest()}=={k:manifest['archive'][k] for k in ('bytes','sha256')},'ordered archive byte identity')
 stream.seek(0)
 with tarfile.open(fileobj=stream,mode='r:gz') as tar:
  members=tar.getmembers();names=[m.name for m in members]
  require(len(names)==len(set(names))==manifest['archive_members'],'unique complete tar member census')
  require(all(m.isfile() for m in members),'only regular archived files')
  raw_inventory=read_member(tar,'archive-inventory.json');require(identity(raw_inventory)==manifest['archive_inventory'],'archive-inventory identity')
  inventory=json.loads(raw_inventory)
  require(set(names)=={row['archive_path'] for row in inventory['files']}|{'archive-inventory.json'},'no extra or missing tar payload')
  for row in inventory['files']:
   require(identity(read_member(tar,row['archive_path']))=={k:row[k] for k in ('bytes','sha256')},'archived payload identity '+row['archive_path'])
  extraction_raw=read_member(tar,'extraction-inventory.json');require(identity(extraction_raw)==manifest['extraction_inventory'],'extraction-inventory identity')
  extraction=json.loads(extraction_raw);zip_count=0;reproduced=[]
  zip_paths=[m for m in names if m.startswith('original-artifacts/')]
  require(len(zip_paths)==manifest['original_zip_count'],'one archived ZIP per original artifact')
  require(not any(m.startswith('capture/artifacts/') for m in names),'no duplicate extracted bytes')
  for artifact in extraction['artifacts']:
   raw=read_member(tar,artifact['archive_path']);require(identity(raw)=={k:artifact[k] for k in ('bytes','sha256')},'archived original ZIP identity')
   with zipfile.ZipFile(io.BytesIO(raw)) as z:
    require(z.testzip() is None,'archived original ZIP every member CRC')
    expected={row['member']:row for row in artifact['member_records']}
    require(set(z.namelist())==set(expected) and len(z.namelist())==len(expected),'exact original ZIP members')
    for info in z.infolist():
     row=expected[info.filename]
     if info.is_dir():require(row.get('directory') is True,'directory inventory');continue
     require(identity(z.read(info))=={k:row[k] for k in ('bytes','sha256')},'every extracted file reproducible from archived ZIP')
     require(f'{info.CRC:08x}'==row['zip_crc32'],'member CRC identity')
     reproduced.append(row)
   zip_count+=1
  require(sorted(reproduced,key=lambda x:x['capture_path'])==sorted(extraction['extracted_files'],key=lambda x:x['capture_path']),'whole extraction inventory agrees exactly')
  require(len(reproduced)==manifest['reproducible_extracted_files'],'complete extracted-file census')
report={'status':'ARCHIVE_DELIVERY_AND_LOSSLESS_EXTRACTION_VERIFIED','run_id':manifest['run_id'],
 'original_zip_count':zip_count,'reproducible_extracted_files':len(reproduced),
 'archive_members_verified':len(names),'archive':manifest['archive'],
 'raw_part_count':len(manifest['parts']),'archive_reassembled_from_delivery_files':True,
 'verified_without_original_capture_or_attachment_paths':True,
 'engine_or_powershell_executed':False,'failed_run_status_unchanged':True,'current_acceptance':False}
args.output.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
