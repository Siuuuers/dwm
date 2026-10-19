from pathlib import Path
p=Path(__file__).parent
s=(p/'baseline/adapter.rs').read_text()
def replace(a,b,count=1):
 global s
 assert s.count(a)==count,(a,s.count(a),count)
 s=s.replace(a,b)
replace('fn focus_event(', '#[path = "consumer_probe.rs"]\nmod consumer_probe;\nuse consumer_probe::Probe;\n\nfn focus_event(')
replace("    context: &'a Arc<Context>,\n", "    context: &'a Arc<Context>,\n    probe: Option<&'a mut Probe>,\n")
replace("    fn new(context: &'a Arc<Context>) -> Self {", "    fn new(context: &'a Arc<Context>, probe: Option<&'a mut Probe>) -> Self {")
replace('            context,\n            queue:', '            context,\n            probe,\n            queue:')
for sig,node in [('node_added(&mut self, node: &Node)', 'node'),('node_removed(&mut self, node: &Node)','node')]:
 replace('    fn '+sig+' {','    fn '+sig+' {\n        if let Some(probe) = self.probe.as_deref_mut() { probe.discover('+node+'); }')
replace('    fn node_updated(&mut self, old_node: &Node, new_node: &Node) {','    fn node_updated(&mut self, old_node: &Node, new_node: &Node) {\n        if let Some(probe) = self.probe.as_deref_mut() { probe.discover(old_node); probe.discover(new_node); }')
replace('    state: State,\n','    state: State,\n    probe: Option<Probe>,\n')
replace('        Self { state }','        Self { state, probe: Probe::from_env(hwnd.0 as isize) }')
replace('AdapterChangeHandler::new(context)', 'AdapterChangeHandler::new(context, self.probe.as_mut())',3)
replace('                handler.enqueue_selection_changes(&tree);\n                Some(QueuedEvents(handler.queue))', '''                handler.enqueue_selection_changes(&tree);
                let snapshot = handler.probe.as_deref_mut().and_then(|p| p.capture(&tree, "update", false));
                drop(tree);
                if let Some(probe) = handler.probe.as_deref_mut() { probe.emit(snapshot); }
                Some(QueuedEvents(handler.queue))''')
# Both focus branches use committed state under their existing guard.
a='                tree.update_host_focus_state_and_process_changes(is_focused, &mut handler);\n                Some(QueuedEvents(handler.queue))'
assert s.count(a)==2
for placeholder,cause in [('true','placeholder_focus'),('false','focus')]:
 s=s.replace(a,f'''                tree.update_host_focus_state_and_process_changes(is_focused, &mut handler);
                let snapshot = handler.probe.as_deref_mut().and_then(|p| p.capture(&tree, "{cause}", {placeholder}));
                drop(tree);
                if let Some(probe) = handler.probe.as_deref_mut() {{ probe.emit(snapshot); }}
                Some(QueuedEvents(handler.queue))''',1)
replace('                *context.tree.write().unwrap() = tree;', '''                let mut guard = context.tree.write().unwrap();
                *guard = tree;
                let snapshot = self.probe.as_mut().and_then(|p| {
                    p.begin_epoch(&guard);
                    p.capture(&guard, "placeholder_replacement", false)
                });
                drop(guard);''')
replace('                self.state = State::Active(Arc::clone(context));\n                result', '                self.state = State::Active(Arc::clone(context));\n                if let Some(probe) = self.probe.as_mut() { probe.emit(snapshot); }\n                result')
# Tree::new has already committed state; no guard exists before Context::new.
replace('                    let context = Context::new(hwnd, tree, Arc::clone(action_handler), false);', '''                    let snapshot = self.probe.as_mut().and_then(|p| {
                        p.begin_epoch(&tree); p.capture(&tree, "initial", false)
                    });
                    let context = Context::new(hwnd, tree, Arc::clone(action_handler), false);
''')
replace('                    let context =\n                        Context::new(hwnd, placeholder_tree, Arc::clone(action_handler), true);', '''                    let snapshot = self.probe.as_mut().and_then(|p| {
                        p.begin_epoch(&placeholder_tree); p.capture(&placeholder_tree, "placeholder_initial", true)
                    });
                    let context =
                        Context::new(hwnd, placeholder_tree, Arc::clone(action_handler), true);
''')
# Emit initial snapshots only after all original lifecycle transition operations.
replace('                    self.state = State::Active(context);', '                    self.state = State::Active(context);\n                    if let Some(probe) = self.probe.as_mut() { probe.emit(snapshot); }')
replace('                    self.state = State::Placeholder(context);', '                    self.state = State::Placeholder(context);\n                    if let Some(probe) = self.probe.as_mut() { probe.emit(snapshot); }')
(p/'candidate/adapter.rs').write_text(s)
# Query observation extends the same diagnostic adapter identity, not tree ownership.
s=s.replace('mod consumer_probe;', 'mod consumer_probe;\n#[path = "query_probe.rs"]\npub(crate) mod query_probe;')
s=s.replace('Context::new(hwnd, tree, Arc::clone(action_handler), false)', 'Context::with_query_observation(hwnd, tree, Arc::clone(action_handler), false, self.probe.as_ref().and_then(|p| p.query_handle()))')
s=s.replace('Context::new(hwnd, placeholder_tree, Arc::clone(action_handler), true)', 'Context::with_query_observation(hwnd, placeholder_tree, Arc::clone(action_handler), true, self.probe.as_ref().and_then(|p| p.query_handle()))')
(p/'candidate/adapter.rs').write_text(s)
c=(p/'baseline/context.rs').read_text()
c=c.replace('    pub(crate) hwnd: WindowHandle,','    pub(crate) query_observation: Option<Arc<crate::adapter::query_probe::QueryObservation>>,\n    pub(crate) hwnd: WindowHandle,',1)
c=c.replace('        Arc::new(Self {','''        Self::with_query_observation(hwnd, tree, action_handler, is_placeholder, None)
    }

    pub(crate) fn with_query_observation(
        hwnd: WindowHandle, tree: Tree,
        action_handler: Arc<dyn ActionHandlerNoMut + Send + Sync>, is_placeholder: bool,
        query_observation: Option<Arc<crate::adapter::query_probe::QueryObservation>>,
    ) -> Arc<Self> {
        Arc::new(Self {
            query_observation,''',1)
(p/'candidate/context.rs').write_text(c)
n=(p/'baseline/node.rs').read_text()
a=n.index('    fn Navigate(&self, direction: NavigateDirection)')
b=n.index('\n    fn GetRuntimeId',a)
n=n[:a]+'''    fn Navigate(&self, direction: NavigateDirection) -> Result<IRawElementProviderFragment> {
        use crate::adapter::query_probe::Identity;
        use std::cell::RefCell;
        let pending = RefCell::new(None);
        let result = self.resolve_with_tree_state_and_context(|node, state, context| {
            let observer = context.query_observation.as_ref();
            let capture = RefCell::new(observer.and_then(|q| q.begin(node, state.root(), direction.0,
                context.is_placeholder.load(std::sync::atomic::Ordering::Relaxed))));
            let ordinary = |candidate: &Node| {
                let decision = filter(candidate);
                if let Some(r) = capture.borrow_mut().as_mut() { r.observe(candidate, "filter", decision); }
                decision
            };
            let parent = |candidate: &Node| {
                let decision = filter_with_root_exception(candidate);
                if let Some(r) = capture.borrow_mut().as_mut() { r.observe(candidate, "filter_with_root_exception", decision); }
                decision
            };
            let selected = match direction {
                NavigateDirection_Parent => node.filtered_parent(&parent),
                NavigateDirection_NextSibling => node.following_filtered_siblings(&ordinary).next(),
                NavigateDirection_PreviousSibling => node.preceding_filtered_siblings(&ordinary).next(),
                NavigateDirection_FirstChild => node.filtered_children(&ordinary).next(),
                NavigateDirection_LastChild => node.filtered_children(&ordinary).next_back(),
                _ => None,
            };
            if let Some(r) = capture.borrow_mut().as_mut() { r.selected = selected.map(Identity::of); }
            let outcome = match selected {
                Some(result) => Ok(self.relative(result.id()).into()),
                None => Err(Error::empty()),
            };
            if let (Some(q), Some(mut r)) = (observer, capture.into_inner()) {
                r.finish();
                *pending.borrow_mut() = Some((Arc::clone(q), r));
            }
            outcome
        });
        // The resolver has released its tree read guard before any sink acquisition or I/O.
        if let Some((observer, request)) = pending.into_inner() {
            let hresult = result.as_ref().err().map_or(0, |e| e.code().0);
            observer.emit(request, hresult, result.is_ok());
        }
        result
    }
''' + n[b:]
(p/'candidate/node.rs').write_text(n)
