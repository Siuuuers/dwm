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
