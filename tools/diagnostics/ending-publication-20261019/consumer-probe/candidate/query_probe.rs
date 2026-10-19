// Diagnostic observations only: never changes navigation decisions or requests.
use accesskit_consumer::{FilterResult, Node};
use std::{fs::{File, OpenOptions}, io::Write, sync::{Arc, Mutex, atomic::{AtomicBool, AtomicU64, Ordering}}, time::{SystemTime, UNIX_EPOCH}};
const MAX_ENTRIES: usize = 256;
const MAX_LABEL: usize = 1024;
const MAX_REQUESTS: u64 = 16384;
static REQUEST_ID: AtomicU64 = AtomicU64::new(0);
const MAX_BYTES: u64 = 64 * 1024 * 1024;
static BYTES: AtomicU64 = AtomicU64::new(0);
fn reserve_bytes(n:u64)->bool {BYTES.fetch_update(Ordering::Relaxed,Ordering::Relaxed,|used| used.checked_add(n).filter(|v| *v<=MAX_BYTES)).is_ok()}
static RESERVED: AtomicU64 = AtomicU64::new(0);
pub(crate) fn now() -> u64 { SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_micros() as u64 }
fn quote(s: &str) -> String {
 let mut o=String::from("\""); for c in s.chars() { match c { '"'=>o.push_str("\\\""),'\\'=>o.push_str("\\\\"),'\n'=>o.push_str("\\n"),'\r'=>o.push_str("\\r"),'\t'=>o.push_str("\\t"),c if c<' '=>o.push_str(&format!("\\u{:04x}",c as u32)),c=>o.push(c) }} o.push('"');o
}
#[derive(Debug)]
pub(crate) struct Identity { local_id:u64, tree_id:String }
impl Identity { pub(crate) fn of(n:Node<'_>)->Self { let (id,tree)=n.locate();Self{local_id:id.0,tree_id:format!("{tree:?}")} } fn json(&self)->String {format!("{{\"local_id\":{},\"tree_id\":{}}}",self.local_id,quote(&self.tree_id))} }
#[derive(Debug)]
struct Sink { file:File, emitted:u64, failed:bool }
#[derive(Debug)]
pub(crate) struct QueryObservation { adapter:u64, hwnd:String, epoch:AtomicU64, epoch_started:AtomicU64, armed:AtomicBool, armed_us:AtomicU64, dropped:AtomicU64, sink:Mutex<Sink> }
#[derive(Debug)]
struct Candidate { identity:Identity,predicate:&'static str,filter:FilterResult,role:String,hidden:bool,focused:bool,label:Option<String>,label_truncated:bool }
#[derive(Debug)]
pub(crate) struct Request { epoch:u64, epoch_started:u64,armed_us:u64,id:u64,thread:String,start:u64,end:u64,direction:i32,source:Identity,root:Identity,placeholder:bool,candidates:Vec<Candidate>,count:u64,pub(crate) selected:Option<Identity> }
impl QueryObservation {
 pub(crate) fn from_env(adapter:u64,hwnd:&str)->Option<Arc<Self>> {
  let path=std::env::var_os("GODOT_ACCESSKIT_QUERY_TRACE_PATH")?;
  let path=format!("{}.adapter-{adapter}.jsonl",path.to_string_lossy().replace("{pid}",&std::process::id().to_string()));
  let file=match OpenOptions::new().create(true).append(true).open(path) {Ok(f)=>f,Err(e)=>{eprintln!("query_probe: open failed: {e}");return None;}};
  Some(Arc::new(Self{adapter,hwnd:hwnd.into(),epoch:AtomicU64::new(0),epoch_started:AtomicU64::new(0),armed:AtomicBool::new(false),armed_us:AtomicU64::new(0),dropped:AtomicU64::new(0),sink:Mutex::new(Sink{file,emitted:0,failed:false})}))
 }
 // Called before Context publication or under the existing replacement write guard.
 pub(crate) fn reset(&self,epoch:u64) {self.armed.store(false,Ordering::Relaxed);self.armed_us.store(0,Ordering::Relaxed);self.epoch_started.store(now(),Ordering::Relaxed);self.epoch.store(epoch,Ordering::Relaxed);}
 pub(crate) fn arm(&self) {if !self.armed.swap(true,Ordering::Relaxed) {self.armed_us.store(now(),Ordering::Relaxed);}}
 // Caller owns the existing tree read guard; lifecycle writes use its write guard.
 pub(crate) fn begin(&self,source:Node<'_>,root:Node<'_>,direction:i32,placeholder:bool)->Option<Request> {
  if !self.armed.load(Ordering::Relaxed) {return None;}
  let id=REQUEST_ID.fetch_add(1,Ordering::Relaxed)+1;
  if RESERVED.fetch_update(Ordering::Relaxed,Ordering::Relaxed,|n| if n<MAX_REQUESTS {Some(n+1)} else {None}).is_err() {self.dropped.fetch_add(1,Ordering::Relaxed);return None;}
  Some(Request{epoch:self.epoch.load(Ordering::Relaxed),epoch_started:self.epoch_started.load(Ordering::Relaxed),armed_us:self.armed_us.load(Ordering::Relaxed),id,thread:format!("{:?}",std::thread::current().id()),start:now(),end:0,direction,source:Identity::of(source),root:Identity::of(root),placeholder,candidates:Vec::new(),count:0,selected:None})
 }
 // Never called while a tree guard is held. Poison/write failure cannot affect native Result.
 pub(crate) fn emit(&self,r:Request,hresult:i32,outcome_ok:bool) {
  // Reserve 16KiB for fixed metadata. Append only complete candidate objects.
  let mut candidates=String::new();let mut recorded=0usize;
  for c in &r.candidates {
   let item=format!("{{\"identity\":{},\"predicate\":{},\"filter\":{},\"role\":{},\"hidden\":{},\"focused\":{},\"raw_label\":{},\"label_truncated\":{}}}",c.identity.json(),quote(c.predicate),quote(&format!("{:?}",c.filter)),quote(&c.role),c.hidden,c.focused,c.label.as_deref().map(quote).unwrap_or_else(||"null".into()),c.label_truncated);
   if candidates.len()+item.len()+1 > 368*1024 {break;}
   if recorded>0 {candidates.push(',');}candidates.push_str(&item);recorded+=1;
  }
  let Ok(mut sink)=self.sink.lock() else {self.dropped.fetch_add(1,Ordering::Relaxed);return;};
  if sink.failed {self.dropped.fetch_add(1,Ordering::Relaxed);return;}
  sink.emitted+=1;
  let row=format!("{{\"schema\":1,\"source\":\"accesskit_windows-0.32.1-query-probe-v1\",\"event\":\"navigate\",\"pid\":{},\"hwnd\":{},\"adapter_id\":{},\"epoch\":{},\"request_id\":{},\"emission_seq\":{},\"thread_id\":{},\"unix_us\":{},\"capture_end_unix_us\":{},\"epoch_started_us\":{},\"armed_us\":{},\"direction\":{},\"source_node\":{},\"root\":{},\"placeholder\":{},\"candidates\":[{}],\"selected\":{},\"outcome_hresult\":{},\"outcome_ok\":{},\"candidate_count\":{},\"omitted_candidates\":{},\"truncated\":{}}}\n",std::process::id(),quote(&self.hwnd),self.adapter,r.epoch,r.id,sink.emitted,quote(&r.thread),r.start,r.end,r.epoch_started,r.armed_us,r.direction,r.source.json(),r.root.json(),r.placeholder,candidates,r.selected.as_ref().map(Identity::json).unwrap_or_else(||"null".into()),hresult,outcome_ok,r.count,r.count-recorded as u64,r.count>recorded as u64);
  if row.len()>384*1024 {sink.emitted-=1;self.dropped.fetch_add(1,Ordering::Relaxed);return;}
  if !reserve_bytes(row.len() as u64) {sink.emitted-=1;self.dropped.fetch_add(1,Ordering::Relaxed);return;}
  if let Err(e)=sink.file.write_all(row.as_bytes()) {sink.failed=true;eprintln!("query_probe: write failed: {e}");}
 }
}
impl Request {
 pub(crate) fn observe(&mut self,node:&Node<'_>,predicate:&'static str,result:FilterResult) {self.count+=1;if self.candidates.len()==MAX_ENTRIES{return;}
  let mut truncated=false;let label=node.data().label().map(|s|{let mut n=s.len().min(MAX_LABEL);while !s.is_char_boundary(n){n-=1;}truncated=n!=s.len();s[..n].to_owned()});
  self.candidates.push(Candidate{identity:Identity::of(*node),predicate,filter:result,role:format!("{:?}",node.role()),hidden:node.is_hidden(),focused:node.is_focused(),label,label_truncated:truncated});
 }
 pub(crate) fn finish(&mut self) {self.end=now();}
}
impl Drop for QueryObservation {fn drop(&mut self) {if let Ok(s)=self.sink.get_mut(){let row=format!("{{\"schema\":1,\"source\":\"accesskit_windows-0.32.1-query-probe-v1\",\"event\":\"query_footer\",\"pid\":{},\"adapter_id\":{},\"records\":{},\"dropped_records\":{},\"write_failed\":{},\"pre_arm_coverage\":false,\"pre_resolution_coverage\":false}}\n",std::process::id(),self.adapter,s.emitted,self.dropped.load(Ordering::Relaxed),s.failed);if reserve_bytes(row.len() as u64) {let _=s.file.write_all(row.as_bytes()).and_then(|_|s.file.flush());}}}}

#[cfg(test)]
mod tests {
 use super::*;
 use accesskit::{Node as Data, NodeId as LocalId, Role, Tree as TreeData, TreeId, TreeUpdate};
 use accesskit_consumer::{Tree, common_filter, common_filter_with_root_exception};
 use std::cell::RefCell;
 static TEST_ID: AtomicU64=AtomicU64::new(0);
 fn observer()->QueryObservation {
  let id=TEST_ID.fetch_add(1,Ordering::Relaxed);
  let file=OpenOptions::new().create(true).append(true).read(true).open(std::env::temp_dir().join(format!("dwm-query-{}-{id}.jsonl",std::process::id()))).unwrap();
  QueryObservation{adapter:id,hwnd:"0x1".into(),epoch:AtomicU64::new(0),epoch_started:AtomicU64::new(0),armed:AtomicBool::new(false),armed_us:AtomicU64::new(0),dropped:AtomicU64::new(0),sink:Mutex::new(Sink{file,emitted:0,failed:false})}
 }
 fn tree()->Tree {let mut root=Data::new(Role::GenericContainer);root.set_children(vec![LocalId(1),LocalId(2)]);let mut hidden=Data::new(Role::Button);hidden.set_hidden();let mut visible=Data::new(Role::Button);visible.set_label("TEST Seven-day ending. ");Tree::new(TreeUpdate{nodes:vec![(LocalId(0),root),(LocalId(1),hidden),(LocalId(2),visible)],tree:Some(TreeData::new(LocalId(0))),tree_id:TreeId::ROOT,focus:LocalId(0)},false)}
 #[test] fn arming_epoch_reset_and_identity_are_explicit() {let t=tree();let q=observer();let root=t.state().root();q.reset(1);assert!(q.begin(root,root,3,false).is_none());q.arm();let first=q.begin(root,root,3,false).unwrap();assert_eq!(first.epoch,1);assert_eq!(first.source.local_id,0);assert!(first.armed_us>=first.epoch_started);q.arm();assert_eq!(q.armed_us.load(Ordering::Relaxed),first.armed_us);q.reset(2);assert!(q.begin(root,root,3,false).is_none());q.arm();assert_eq!(q.begin(root,root,3,false).unwrap().epoch,2);}
 #[test] fn wrapping_preserves_predicate_order_and_selected_identity() {let t=tree();let root=t.state().root();let q=observer();q.reset(1);q.arm();let capture=RefCell::new(q.begin(root,root,3,false).unwrap());let baseline=RefCell::new(Vec::new());let expected=root.filtered_children(|n|{let r=common_filter(n);baseline.borrow_mut().push((n.locate().0.0,r));r}).next().unwrap();let actual=root.filtered_children(|n|{let r=common_filter(n);capture.borrow_mut().observe(n,"filter",r);r}).next().unwrap();assert_eq!(actual.id(),expected.id());let r=capture.into_inner();let baseline=baseline.into_inner();assert!(!baseline.is_empty());assert_eq!(r.count,baseline.len() as u64);assert_eq!(r.candidates.iter().map(|c|(c.identity.local_id,c.filter)).collect::<Vec<_>>(),baseline);}
 #[test] fn parent_root_exception_is_not_ordinary_filter() {let t=tree();let root=t.state().root();assert_eq!(common_filter(&root),FilterResult::ExcludeNode);assert_eq!(common_filter_with_root_exception(&root),FilterResult::Include);let child=root.children().last().unwrap();let q=observer();q.reset(1);q.arm();let capture=RefCell::new(q.begin(child,root,0,false).unwrap());let parent=child.filtered_parent(&|n|{let r=common_filter_with_root_exception(n);capture.borrow_mut().observe(n,"filter_with_root_exception",r);r}).unwrap();assert_eq!(parent.id(),root.id());assert_eq!(capture.borrow().candidates[0].predicate,"filter_with_root_exception");}
 #[test] fn entry_cap_never_stops_predicate_evaluation() {let t=tree();let root=t.state().root();let q=observer();q.reset(1);q.arm();let mut r=q.begin(root,root,3,false).unwrap();let mut evaluated=0;for _ in 0..MAX_ENTRIES+7 {let decision=common_filter(&root);evaluated+=1;r.observe(&root,"filter",decision);}assert_eq!(evaluated,MAX_ENTRIES+7);assert_eq!(r.count,(MAX_ENTRIES+7) as u64);assert_eq!(r.candidates.len(),MAX_ENTRIES);}
 #[test] fn labels_are_utf8_bounded_and_json_escaped() {let mut data=Data::new(Role::Button);data.set_label("é".repeat(MAX_LABEL));let t=Tree::new(TreeUpdate{nodes:vec![(LocalId(0),data)],tree:Some(TreeData::new(LocalId(0))),tree_id:TreeId::ROOT,focus:LocalId(0)},false);let root=t.state().root();let q=observer();q.reset(1);q.arm();let mut r=q.begin(root,root,0,false).unwrap();r.observe(&root,"filter",common_filter(&root));assert!(r.candidates[0].label_truncated);assert_eq!(r.candidates[0].label.as_ref().unwrap().len(),MAX_LABEL);assert_eq!(quote("\n\"\\"),"\"\\n\\\"\\\\\"");}
 #[test] fn concurrent_emission_serializes_and_failed_sink_drops_only_observation() {let t=tree();let root=t.state().root();let q=Arc::new(observer());q.reset(1);q.arm();let requests=(0..4).map(|_|{let mut r=q.begin(root,root,3,false).unwrap();r.finish();r}).collect::<Vec<_>>();std::thread::scope(|scope|{for r in requests {let q=Arc::clone(&q);scope.spawn(move||q.emit(r,0,true));}});assert_eq!(q.sink.lock().unwrap().emitted,4);q.sink.lock().unwrap().failed=true;let mut r=q.begin(root,root,3,false).unwrap();r.finish();q.emit(r,0,true);assert_eq!(q.dropped.load(Ordering::Relaxed),1);}
 #[test] fn actual_com_navigate_body_observed_and_disabled_results_agree() {
  use crate::{context::{Context,ActionHandlerNoMut},node::PlatformNode};
  use windows::Win32::{Foundation::HWND,UI::Accessibility::*};
  struct NoActions;impl ActionHandlerNoMut for NoActions {fn do_action(&self,_:accesskit::ActionRequest){}}
  for enabled in [false,true] {
   let q=Arc::new(observer());q.reset(1);q.arm();
   let context=Context::with_query_observation(HWND::default().into(),tree(),Arc::new(NoActions),false,if enabled {Some(Arc::clone(&q))} else {None});
   let root_id=context.read_tree().state().root_id();
   let root:IRawElementProviderFragment=PlatformNode::new(&context,root_id).into();
   unsafe {
    let child=root.Navigate(NavigateDirection_FirstChild).unwrap();
    assert!(root.Navigate(NavigateDirection_LastChild).is_ok());
    assert!(child.Navigate(NavigateDirection_Parent).is_ok());
    assert!(child.Navigate(NavigateDirection_NextSibling).is_err());
    assert!(child.Navigate(NavigateDirection_PreviousSibling).is_err());
    assert!(root.Navigate(NavigateDirection(999)).is_err());
   }
   assert_eq!(q.sink.lock().unwrap().emitted,if enabled {6} else {0});
  }
 }

 #[test] fn escaped_serialized_request_cap_marks_omitted_candidates() {
  use std::io::{Read,Seek,SeekFrom};
  let mut data=Data::new(Role::Button);data.set_label("\u{1}".repeat(MAX_LABEL));
  let t=Tree::new(TreeUpdate{nodes:vec![(LocalId(0),data)],tree:Some(TreeData::new(LocalId(0))),tree_id:TreeId::ROOT,focus:LocalId(0)},false);
  let root=t.state().root();let q=observer();q.reset(1);q.arm();let mut r=q.begin(root,root,3,false).unwrap();
  for _ in 0..MAX_ENTRIES {r.observe(&root,"filter",FilterResult::Include);}r.finish();q.emit(r,0,true);
  let mut sink=q.sink.lock().unwrap();sink.file.seek(SeekFrom::Start(0)).unwrap();let mut output=String::new();sink.file.read_to_string(&mut output).unwrap();
  assert!(output.len()<=384*1024);assert!(output.contains("\"truncated\":true"));assert!(!output.contains("\"omitted_candidates\":0"));assert_eq!(output.lines().count(),1);
 }

}
