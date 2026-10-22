"""Extract existing checkpoint tail; does not execute game code."""
from pathlib import Path
import json,hashlib
base=Path(__file__).resolve().parent
folder=base.parent/'corrected-evidence/exported-load'
files=['game.stdout.log','failure-saves-autosave.json']
lines=(folder/files[0]).read_text(encoding='utf-8-sig').splitlines()
rows=[]
for i,line in enumerate(lines):
 if line.startswith('DWM_CHECKPOINT_PROFILE '):
  row=json.loads(line.split(' ',1)[1]);rows.append(dict(line=i+1,scope=row['scope'],elapsed_us=row['elapsed_us'],checkpoint_id=row.get('checkpoint_id'),ok=row['ok']))
tail=rows[-6:]
assert [r['scope'] for r in tail]==['save_checkpoint_prepare','save_checkpoint']*3
assert [r['checkpoint_id'].split(':')[-1] for r in tail[1::2]]==['18','19','20']
s=json.loads((folder/files[1]).read_text())['current_snapshot']['snapshot']
out=dict(input_sha256={f:hashlib.sha256((folder/f).read_bytes()).hexdigest() for f in files},tail=tail,total_outer_elapsed_us=sum(r['elapsed_us'] for r in tail),failure_snapshot=dict(checkpoint_id=s['checkpoint_id'],state=s['lifecycle']['state'],playback_stage=s['lifecycle']['ending_plan']['playback_stage']),qualification='Untimestamped profile records: no exact overlap with the Title wait established; nested submetrics must not be summed.')
(base/'title-observations.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
