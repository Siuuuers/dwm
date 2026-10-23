"""Offline separator emulation only; no native/Windows/game execution."""
import json, os, sys, tempfile, zipfile
from pathlib import Path
from unittest.mock import patch
# Run with the published source/new-title-tools directory as first argument.
sys.path.insert(0, sys.argv[1])
import package_timing as p
rows=[]
for sep in ['/', '\\']:
    with patch.object(os, 'sep', sep):
        z=zipfile.ZipInfo('x\\y')
    rows.append({'separator':sep,'requested':'x\\y','constructor_filename':z.filename,'constructor_orig_filename':z.orig_filename})
with tempfile.TemporaryDirectory() as d:
    root=Path(d); archive=root/'raw.zip'
    z=zipfile.ZipInfo('x/y');z.filename='x\\y';z.orig_filename='x\\y'
    with zipfile.ZipFile(archive,'w') as out: out.writestr(z,'bad')
    results=[]
    for index,sep in enumerate(['/','\\']):
        with patch.object(os,'sep',sep):
            with zipfile.ZipFile(archive) as inp:
                names=[{'filename':e.filename,'orig_filename':e.orig_filename} for e in inp.infolist()]
            try: p.extract(archive,root/str(index));rejected=False
            except ValueError: rejected=True
        raw_rejected=False
        try: p.safe_name(names[0]['orig_filename'])
        except ValueError: raw_rejected=True
        results.append({'separator':sep,'read_names':names,'existing_extractor_rejects':rejected,'existing_safe_name_rejects_raw_orig_filename':raw_rejected})
    result={'constructor':rows,'raw_archive_reader':results,'scope':'Offline Python separator emulation, not a Windows execution','proposal':'Construct actual raw malformed fixture; validate ZipInfo.orig_filename before extraction and reject normalization differences. Keep safe_name strict.'}
    assert not results[1]['existing_extractor_rejects'] and results[1]['existing_safe_name_rejects_raw_orig_filename']
    print(json.dumps(result,indent=2))
