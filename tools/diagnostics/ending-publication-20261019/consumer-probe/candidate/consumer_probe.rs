// Diagnostic only. No changes to AccessKit state, events, actions or filters.
use accesskit_consumer::{common_filter, Node, NodeId, Tree};
use std::{fs::{File, OpenOptions}, io::Write, sync::atomic::{AtomicU64, Ordering}, time::{SystemTime, UNIX_EPOCH}};
const CAPTION: &str = "TEST Seven-day ending.";
const MAX_CANDIDATES: usize = 16;
const MAX_SCAN: usize = 4096;
const MAX_PATH: usize = 32;
const MAX_LABEL: usize = 1024;
const MAX_RECORDS: u64 = 16384;
static NEXT_ADAPTER: AtomicU64 = AtomicU64::new(1);
#[derive(Clone, Debug)]
struct Identity { local_id: u64, tree_id: String }
fn identity(node: Node<'_>) -> Identity {
    let (local, tree) = node.locate();
    Identity { local_id: local.0, tree_id: format!("{tree:?}") }
}
#[derive(Debug)]
pub(super) struct Probe {
    file: File, adapter: u64, hwnd: String, epoch: u64, seq: u64,
    candidates: Vec<(NodeId, Identity)>, overflow: bool,
    records: u64, dropped: u64, write_failed: bool,
}
#[derive(Debug)]
struct Fact { id: Identity, parent: Option<Identity>, raw_label: Option<String>, role: String,
    hidden: bool, focused: bool, filter: String, geometry: String }
#[derive(Debug)]
pub(super) struct Snapshot {
    seq: u64, unix_us: u128, capture_end_unix_us: u128, cause: &'static str, placeholder: bool,
    state: &'static str, candidates: Vec<Identity>, bound: Option<Identity>,
    overflow: bool, path_truncated: bool, label_truncated: bool,
    host_focused: bool, root: Identity, nodes: Vec<Fact>,
}
impl Probe {
    pub(super) fn from_env(hwnd: isize) -> Option<Self> {
        let path = std::env::var_os("GODOT_ACCESSKIT_CONSUMER_TRACE_PATH")?;
        let path = path.to_string_lossy().replace("{pid}", &std::process::id().to_string());
        // Appending supports multiple adapters without truncating their records.
        let file = match OpenOptions::new().create(true).append(true).open(path) {
            Ok(file) => file,
            Err(err) => { eprintln!("consumer_probe: trace open failed: {err}"); return None; }
        };
        Some(Self { file, adapter: NEXT_ADAPTER.fetch_add(1, Ordering::Relaxed),
            hwnd: format!("0x{:x}", hwnd as usize), epoch: 0, seq: 0,
            candidates: Vec::new(), overflow: false, records: 0, dropped: 0, write_failed: false })
    }
    pub(super) fn discover(&mut self, node: &Node<'_>) {
        if node.data().label().is_some_and(|s| s.trim_end() == CAPTION)
            && !self.candidates.iter().any(|(id, _)| *id == node.id()) {
            if self.candidates.len() == MAX_CANDIDATES { self.overflow = true; }
            else { self.candidates.push((node.id(), identity(*node))); }
        }
    }
    pub(super) fn begin_epoch(&mut self, tree: &Tree) {
        self.epoch += 1;
        self.candidates.clear(); self.overflow = false;
        // Unfiltered bounded DFS; iterator frames avoid collecting unbounded children.
        let root = tree.state().root();
        self.discover(&root);
        let mut stack = vec![root.children()];
        let mut visited = 1;
        while let Some(children) = stack.last_mut() {
            match children.next() {
                Some(node) => {
                    if visited == MAX_SCAN { self.overflow = true; break; }
                    visited += 1; self.discover(&node); stack.push(node.children());
                }
                None => { stack.pop(); }
            }
        }
    }
    pub(super) fn capture(&mut self, tree: &Tree, cause: &'static str, placeholder: bool) -> Option<Snapshot> {
        self.seq += 1;
        if self.records >= MAX_RECORDS || self.write_failed { self.dropped += 1; return None; }
        let unix_us = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_micros();
        let state = tree.state();
        let unique = !self.overflow && self.candidates.len() == 1;
        let bound = unique.then(|| self.candidates[0].1.clone());
        let mut node = if unique { state.node_by_id(self.candidates[0].0) } else { None };
        let status = if self.overflow || self.candidates.len() > 1 { "ambiguous" }
            else if !unique { "unbound" } else if node.is_some() { "present" } else { "absent" };
        let mut nodes = Vec::new(); let mut label_truncated = false;
        while let Some(current) = node {
            if nodes.len() == MAX_PATH { break; }
            let raw_label = current.data().label().map(|s| {
                let (value, truncated) = bounded(s, MAX_LABEL); label_truncated |= truncated; value
            });
            nodes.push(Fact { id: identity(current), parent: current.parent().map(identity), raw_label,
                role: format!("{:?}", current.role()), hidden: current.is_hidden(), focused: current.is_focused(),
                filter: format!("{:?}", common_filter(&current)),
                geometry: format!("raw_bounds={:?};transformed_bounds={:?};transform={:?};clips_children={};sibling_predicate_inputs=not_captured", current.data().bounds(), current.bounding_box(), current.transform(), current.clips_children()) });
            node = current.parent();
        }
        let host_focused = state.is_host_focused();
        let root = identity(state.root());
        Some(Snapshot { seq: self.seq, unix_us, capture_end_unix_us: SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_micros(), cause, placeholder, state: status,
            candidates: self.candidates.iter().map(|(_, id)| id.clone()).collect(), bound,
            overflow: self.overflow, path_truncated: node.is_some(), label_truncated,
            host_focused, root, nodes })
    }
    // Called only after the existing tree guard has been dropped.
    pub(super) fn emit(&mut self, snapshot: Option<Snapshot>) {
        if let Some(s) = snapshot {
            let nodes = s.nodes.iter().map(|n| format!("{{\"identity\":{},\"parent\":{},\"raw_label\":{},\"role\":{},\"hidden\":{},\"focused\":{},\"filter\":{},\"geometry\":{}}}", ident(&n.id), optional_identity(n.parent.as_ref()), n.raw_label.as_deref().map(quote).unwrap_or_else(|| "null".into()), quote(&n.role), n.hidden, n.focused, quote(&n.filter), quote(&n.geometry))).collect::<Vec<_>>().join(",");
            let candidates = s.candidates.iter().map(ident).collect::<Vec<_>>().join(",");
            let row = format!("{{\"schema\":1,\"source\":\"accesskit_windows-0.32.1-consumer-probe-v1\",\"event\":\"consumer_commit\",\"pid\":{},\"hwnd\":{},\"adapter_id\":{},\"epoch\":{},\"seq\":{},\"unix_us\":{},\"capture_end_unix_us\":{},\"cause\":{},\"placeholder\":{},\"binding_state\":{},\"candidates\":[{}],\"bound\":{},\"discovery_overflow\":{},\"path_truncated\":{},\"label_truncated\":{},\"host_focused\":{},\"root\":{},\"nodes\":[{}]}}\n", std::process::id(), quote(&self.hwnd), self.adapter, self.epoch, s.seq, s.unix_us, s.capture_end_unix_us, quote(s.cause), s.placeholder, quote(s.state), candidates, optional_identity(s.bound.as_ref()), s.overflow, s.path_truncated, s.label_truncated, s.host_focused, ident(&s.root), nodes);
            self.records += 1;
            if let Err(err) = self.file.write_all(row.as_bytes()) {
                self.write_failed = true; eprintln!("consumer_probe: trace write failed: {err}");
            }
        }
    }
}
impl Drop for Probe {
    fn drop(&mut self) {
        let row = format!("{{\"schema\":1,\"event\":\"consumer_footer\",\"pid\":{},\"adapter_id\":{},\"seq\":{},\"records\":{},\"dropped_records\":{},\"write_failed\":{}}}\n", std::process::id(), self.adapter, self.seq, self.records, self.dropped, self.write_failed);
        if let Err(err) = self.file.write_all(row.as_bytes()).and_then(|_| self.file.flush()) { eprintln!("consumer_probe: footer write failed: {err}"); }
    }
}
fn bounded(s: &str, limit: usize) -> (String, bool) {
    let mut end = s.len().min(limit); while !s.is_char_boundary(end) { end -= 1; }
    (s[..end].to_owned(), end != s.len())
}
fn quote(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() { match c {
        '"' => out.push_str("\\\""), '\\' => out.push_str("\\\\"),
        '\n' => out.push_str("\\n"), '\r' => out.push_str("\\r"), '\t' => out.push_str("\\t"),
        c if c < ' ' => out.push_str(&format!("\\u{:04x}", c as u32)), c => out.push(c),
    }} out.push('"'); out
}
fn ident(id: &Identity) -> String { format!("{{\"local_id\":{},\"tree_id\":{}}}", id.local_id, quote(&id.tree_id)) }
fn optional_identity(id: Option<&Identity>) -> String { id.map(ident).unwrap_or_else(|| "null".into()) }

#[cfg(test)]
mod tests {
    use super::*;
    use accesskit::{Node as Data, NodeId as LocalId, Role, Tree as TreeData, TreeId, TreeUpdate};
    fn tree(labels: &[&str], hidden: bool) -> Tree {
        let mut root = Data::new(Role::Window);
        root.set_children((1..=labels.len()).map(|n| LocalId(n as u64)).collect::<Vec<_>>());
        let mut nodes = vec![(LocalId(0), root)];
        for (i, label) in labels.iter().enumerate() {
            let mut data = Data::new(Role::Label); data.set_label(*label); if hidden { data.set_hidden(); }
            nodes.push((LocalId(i as u64 + 1), data));
        }
        Tree::new(TreeUpdate { nodes, tree: Some(TreeData::new(LocalId(0))), tree_id: TreeId::ROOT, focus: LocalId(0) }, false)
    }
    fn probe() -> Probe {
        let id = NEXT_ADAPTER.fetch_add(1, Ordering::Relaxed);
        let file = OpenOptions::new().create(true).append(true).open(std::env::temp_dir().join(format!("consumer-probe-test-{}-{id}.jsonl", std::process::id()))).unwrap();
        Probe { file, adapter:id, hwnd:"0x0".into(), epoch:0, seq:0, candidates:vec![], overflow:false,records:0,dropped:0,write_failed:false }
    }
    #[test] fn filtered_discovery_and_initial_binding() {
        let t = tree(&[CAPTION], true); let mut p = probe(); p.begin_epoch(&t);
        let s = p.capture(&t,"initial",false).unwrap(); assert_eq!(s.state,"present"); assert_eq!(s.nodes[0].filter,"ExcludeSubtree");
        let mut p = probe(); p.discover(&t.state().root().children().next().unwrap());
        assert_eq!(p.capture(&t,"update",false).unwrap().state,"present");
    }
    #[test] fn removal_is_not_unbound_and_label_change_retains_binding() {
        let t = tree(&[CAPTION], false); let mut p = probe(); p.begin_epoch(&t);
        let renamed = tree(&["changed"], false);
        assert_eq!(p.capture(&renamed,"update",false).unwrap().state,"present");
        let empty = tree(&[], false); assert_eq!(p.capture(&empty,"update",false).unwrap().state,"absent");
        let mut fresh = probe(); fresh.begin_epoch(&empty); assert_eq!(fresh.capture(&empty,"initial",false).unwrap().state,"unbound");
    }
    #[test] fn duplicate_and_capacity_never_look_unique() {
        let t = tree(&[CAPTION,CAPTION],false); let mut p = probe(); p.begin_epoch(&t);
        assert_eq!(p.capture(&t,"initial",false).unwrap().state,"ambiguous");
        let t = tree(&[CAPTION;17],false); p.begin_epoch(&t); assert!(p.overflow); assert_eq!(p.candidates.len(),16);
    }
    #[test] fn placeholder_epoch_reuse_resets_binding_and_focus_is_observed() {
        let t = tree(&[CAPTION],false); let empty = tree(&[],false); let mut p=probe(); p.begin_epoch(&t);
        p.begin_epoch(&empty); assert_eq!(p.epoch,2); assert_eq!(p.capture(&empty,"placeholder_initial",true).unwrap().state,"unbound");
        p.begin_epoch(&t); let s=p.capture(&t,"placeholder_replacement",false).unwrap(); assert_eq!(s.state,"present");
        let focus=p.capture(&t,"focus",false).unwrap(); assert_eq!(focus.seq,s.seq+1); assert_eq!(focus.cause,"focus");
    }
    struct Discover<'a>(&'a mut Probe);
    impl accesskit_consumer::TreeChangeHandler for Discover<'_> {
        fn node_added(&mut self, n: &Node) { self.0.discover(n); }
        fn node_updated(&mut self, old: &Node, new: &Node) { self.0.discover(old); self.0.discover(new); }
        fn node_removed(&mut self, n: &Node) { self.0.discover(n); }
        fn focus_moved(&mut self, _: Option<&Node>, _: Option<&Node>) {}
    }
    #[test] fn actual_commits_focus_removal_and_old_node_discovery() {
        let mut t=tree(&[CAPTION],true); let mut p=probe(); p.begin_epoch(&t);
        let target=t.state().root().children().next().unwrap().id();
        let update=TreeUpdate { nodes:vec![],tree:None,tree_id:TreeId::ROOT,focus:LocalId(1) };
        t.update_and_process_changes(update,&mut Discover(&mut p));
        t.update_host_focus_state_and_process_changes(true,&mut Discover(&mut p));
        let focused=p.capture(&t,"focus",false).unwrap(); assert_eq!(focused.nodes[0].filter,"Include");
        assert!(focused.host_focused); assert!(focused.nodes[0].focused);
        let mut root=Data::new(Role::Window); root.set_children(Vec::<LocalId>::new());
        let update=TreeUpdate { nodes:vec![(LocalId(0),root)],tree:None,tree_id:TreeId::ROOT,focus:LocalId(0) };
        t.update_and_process_changes(update,&mut Discover(&mut p));
        assert!(t.state().node_by_id(target).is_none()); assert_eq!(p.capture(&t,"update",false).unwrap().state,"absent");
        let old=tree(&[CAPTION],true); let renamed=tree(&["renamed"],true); let mut fresh=probe();
        let old_node=old.state().root().children().next().unwrap();
        let new_node=renamed.state().root().children().next().unwrap();
        accesskit_consumer::TreeChangeHandler::node_updated(&mut Discover(&mut fresh),&old_node,&new_node);
        assert_eq!(fresh.capture(&renamed,"update",false).unwrap().state,"present");
    }
    #[test] fn label_and_path_truncation_are_explicit() {
        let mut p=probe(); let t=tree(&[CAPTION],false); p.begin_epoch(&t);
        let long="x".repeat(MAX_LABEL+1); let t=tree(&[&long],false);
        assert!(p.capture(&t,"update",false).unwrap().label_truncated);
        let mut nodes=Vec::new();
        for i in 0..=MAX_PATH {
            let mut node=Data::new(if i==MAX_PATH {Role::Label} else {Role::GenericContainer});
            if i<MAX_PATH { node.set_children(vec![LocalId(i as u64+1)]); } else {node.set_label(CAPTION);}
            nodes.push((LocalId(i as u64),node));
        }
        let deep=Tree::new(TreeUpdate {nodes,tree:Some(TreeData::new(LocalId(0))),tree_id:TreeId::ROOT,focus:LocalId(0)},false);
        p.begin_epoch(&deep); let s=p.capture(&deep,"initial",false).unwrap(); assert!(s.path_truncated); assert_eq!(s.nodes.len(),MAX_PATH);
    }
    #[test] fn limits_and_json_escape_are_explicit() {
        assert_eq!(bounded("éé",3),("é".into(),true)); assert_eq!(quote("\n\"\\"),"\"\\n\\\"\\\\\"");
        let t=tree(&[],false); let mut p=probe(); p.records=MAX_RECORDS; assert!(p.capture(&t,"update",false).is_none()); assert_eq!(p.dropped,1);
        let labels=vec!["irrelevant";MAX_SCAN]; let t=tree(&labels,false); p.begin_epoch(&t); assert!(p.overflow);
    }
}
