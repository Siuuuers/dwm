from pathlib import Path
import sys,json,hashlib
base=Path(__file__).resolve().parent
sys.path.insert(0,str(base/'source/tools/diagnostics/ending-publication-20261019/query_analysis'))
import bind_query

def manifest(folder):
 return {str(p.relative_to(folder)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.rglob('*')) if p.is_file()}
for label in ['baseline','corrected']:
 folder=base.parent/(label+'-evidence');before=manifest(folder)
 report=bind_query.bind(folder)
 (base/(label+'-query-binding-offline.json')).write_text(json.dumps(report,indent=2)+'\n')
 (base/(label+'-consumer-binding-offline.json')).write_text(json.dumps(report['consumer_binding'],indent=2)+'\n')
 after=manifest(folder)
 assert before==after
 (base/(label+'-evidence-unchanged.json')).write_text(json.dumps(dict(unchanged=True,files=before),indent=2)+'\n')
 print(label,report['binding_ok'],report['errors'])
