import json,sys,collections
p=json.load(open(sys.argv[1]))
records=[r for r in p['profiles']['exported'] if 'history_receipt_calls' in r]
sums=collections.Counter()
for r in records:
 for k,v in r.items():
  if k.startswith('history_receipt_'): sums[k]+=v
phases=['prelude','identity_dispatch','effect_variable','initial_admission','other_admission','event_auth_group','final_chain_joins']
total=sum(sums['history_receipt_'+k+'_us'] for k in phases)
report={'records':len(records),'counters':dict(sums),'disjoint_us':total,'parent_us':sum(r['history_run9_receipt_contract_us'] for r in records),'phase_share':{k:round(100*sums['history_receipt_'+k+'_us']/total,4) if total else 0 for k in phases},'whole_transitions':[r for r in p['profiles']['exported'] if r.get('scope') in ['scene_forward','scene_ending','scene_forward_total','scene_ending_total']]}
print(json.dumps(report,indent=2))
