#!/usr/bin/env python3
"""Execute verified migration locally; no network or ref writes."""
from pathlib import Path
import argparse,json,shutil
import build_consolidation as b
import finalize_consolidation as f
from verify_consolidation import verify

def run(root,source_dir,upload,report):
    original,m,*_=b.build(root,upload.read_bytes(),f.ARCHIVE)
    # Avoid unrelated spelling-only normalization of existing ./ links.
    for untouched in ['docs/superpowers/plans/2026-08-07-seven-day-flow-implementation-roadmap.md',
                      'docs/superpowers/plans/2026-08-11-desktop-minesweeper-shop-schedule-implementation-roadmap.md',
                      'story/06-seven-day-scene-beatbook.md']:
        (root/untouched).write_bytes(original[untouched])
    f.finalize(root,original,m,f.ARCHIVE)
    (root/b.MAINT/'source-migration.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
    shutil.copy(Path(__file__).with_name('verify_consolidation.py'),root/b.MAINT/'verify_consolidation.py')
    first=verify(root,source_dir,upload,True)
    if first['failed_count']:
        report.write_text(json.dumps(first,indent=2));raise RuntimeError('Preservation gate failed; sources not removed')
    for item in m['source_files']:(root/item['path']).unlink()
    assert not any((root/b.OLD).iterdir());(root/b.OLD).rmdir()
    final=verify(root,source_dir,upload,False)
    report.write_text(json.dumps(final,ensure_ascii=False,indent=2)+'\n')
    assert not final['failed_count'],final['failures']
    print(json.dumps({k:v for k,v in final.items() if k not in ['checks','warnings']},indent=2))

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--root',type=Path,required=True);a.add_argument('--source-dir',type=Path,required=True);a.add_argument('--upload',type=Path,required=True);a.add_argument('--report',type=Path,required=True);args=a.parse_args();run(args.root,args.source_dir,args.upload,args.report)
