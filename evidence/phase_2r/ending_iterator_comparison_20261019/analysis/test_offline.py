import copy,json,sys,tempfile,unittest
from pathlib import Path
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE/'source/tools/diagnostics/ending-publication-20261019/query_analysis'))
import bind_query
from wait_validation import validate_waits,utc_us,source_exception,SOURCE,TREE,HASHES
FOLDER=BASE.parent/'corrected-evidence'
EVENTS=json.loads((FOLDER/'exported-load/events.json').read_text(encoding='utf-8-sig'))
LOAD=json.loads((FOLDER/'exported-load/result.json').read_text(encoding='utf-8-sig'))
PID=LOAD['process']['pid']; START=utc_us(LOAD['process']['started_utc'])
WAITS=validate_waits(EVENTS,PID,START)
class OrderedWaitTests(unittest.TestCase):
 def check_bad(self,edit):
  events=copy.deepcopy(EVENTS);edit(events)
  with self.assertRaises(ValueError):validate_waits(events,PID,START)
 def test_arbitrary_count_first_selected(self):
  self.assertEqual(len(WAITS),3)
  self.assertEqual(validate_waits(EVENTS[:WAITS[1]['end_event_index']+1],PID,START)[0]['start_event_index'],WAITS[0]['start_event_index'])
 def test_missing_all(self):
  with self.assertRaises(ValueError):validate_waits([],PID,START)
 def test_missing_start(self):self.check_bad(lambda e:e.pop(WAITS[1]['start_event_index']))
 def test_missing_end(self):self.check_bad(lambda e:e.pop(WAITS[2]['end_event_index']))
 def test_reordered(self):
  def edit(e):
   a,b=WAITS[1]['start_event_index'],WAITS[1]['end_event_index'];e[a],e[b]=e[b],e[a]
  self.check_bad(edit)
 def test_deadline_later_wait(self):self.check_bad(lambda e:e[WAITS[2]['start_event_index']]['data'].update(deadline_seconds=31))
 def test_pid_later_wait(self):self.check_bad(lambda e:e[WAITS[2]['start_event_index']+1]['data'].update(pid=PID+1))
 def test_hwnd_later_wait(self):self.check_bad(lambda e:e[WAITS[2]['start_event_index']+1]['data'].update(handle=999))
 def test_source_exception_is_exact(self):
  name=next(iter(HASHES));origin=dict(tool_source=SOURCE,tool_tree=TREE)
  self.assertTrue(source_exception(origin,name,HASHES[name]))
  for bad in [dict(tool_source='wrong',tool_tree=TREE),dict(tool_source=SOURCE,tool_tree='wrong')]:self.assertFalse(source_exception(bad,name,HASHES[name]))
  self.assertFalse(source_exception(origin,name,'wrong'))
  self.assertFalse(source_exception(origin,'consumer_analysis/read_trace.py',HASHES[name]))
 def test_later_ordinal_rejected_in_complete_binding(self):
  with tempfile.TemporaryDirectory() as tmp:
   target=Path(tmp)
   for p in FOLDER.iterdir():
    if p.name!='exported-load':(target/p.name).symlink_to(p.resolve(),target_is_directory=p.is_dir())
   d=target/'exported-load';d.mkdir()
   for p in (FOLDER/'exported-load').iterdir():
    if p.name!='events.json':(d/p.name).symlink_to(p.resolve())
   events=copy.deepcopy(EVENTS)
   for e in events[WAITS[1]['start_event_index']:WAITS[1]['end_event_index']]:
    if e['kind']=='caption-action-enumeration':e['data']['ending_actions']['query_ordinal']=1
   (d/'events.json').write_text(json.dumps(events))
   report=bind_query.bind(target)
   self.assertFalse(report['binding_ok']);self.assertIn('Harness query ordinal gap',str(report['errors']))
 def test_retained_both_first_interval_only(self):
  for label,count in [('baseline',1),('corrected',3)]:
   r=bind_query.bind(BASE.parent/(label+'-evidence'))
   self.assertTrue(r['binding_ok'],r['errors'])
   self.assertEqual(len(r['consumer_binding']['validated_waits']),count)
   self.assertEqual(len(r['harness_observations']),r['validated_harness_query_counts']['0'])
   wait=r['consumer_binding']['original_wait'];a,b=utc_us(wait['start']['utc']),utc_us(wait['end']['utc'])
   for row in r['selected_observations']:self.assertTrue(a<=row['unix_us']<=row['capture_end_unix_us']<=b)
if __name__=='__main__':unittest.main(verbosity=2)
