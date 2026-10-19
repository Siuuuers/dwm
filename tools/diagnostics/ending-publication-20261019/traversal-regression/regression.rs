
#[cfg(test)]
mod dwm_traversal_regression {
    use accesskit::{Node, NodeId, Role, Tree, TreeId, TreeUpdate};
    use alloc::vec;
    use crate::{filters::{common_filter, FilterResult}, tests::nid};

    // A -> transparent leaf B -> excluded C(D) -> reachable E.
    // Reverse order exercises the same contract for preceding siblings.
    fn fixture(reverse: bool, excluded_has_child: bool) -> crate::Tree {
        let mut root = Node::new(Role::Window);
        root.set_children(if reverse {
            vec![NodeId(5), NodeId(3), NodeId(2), NodeId(1)]
        } else {
            vec![NodeId(1), NodeId(2), NodeId(3), NodeId(5)]
        });
        let mut excluded = Node::new(Role::GenericContainer);
        excluded.set_hidden();
        if excluded_has_child { excluded.set_children(vec![NodeId(4)]); }
        let mut nodes = vec![
            (NodeId(0), root),
            (NodeId(1), Node::new(Role::Button)),
            (NodeId(2), Node::new(Role::GenericContainer)),
            (NodeId(3), excluded),
            (NodeId(5), Node::new(Role::Button)),
        ];
        if excluded_has_child {
            let mut child = Node::new(Role::GenericContainer);
            child.set_hidden();
            nodes.push((NodeId(4), child));
        }
        crate::Tree::new(TreeUpdate {
            nodes, tree: Some(Tree::new(NodeId(0))),
            tree_id: TreeId::ROOT, focus: NodeId(0),
        }, false)
    }

    fn explicit_filter(node: &crate::Node) -> FilterResult {
        if node.id() == nid(NodeId(2)) { FilterResult::ExcludeNode }
        else if node.id() == nid(NodeId(3)) || node.id() == nid(NodeId(4)) {
            FilterResult::ExcludeSubtree
        } else { FilterResult::Include }
    }

    fn check(reverse: bool, has_child: bool, common: bool) {
        let tree = fixture(reverse, has_child);
        let source = tree.state().node_by_id(nid(NodeId(1))).unwrap();
        let filter: fn(&crate::Node) -> FilterResult = if common { common_filter } else { explicit_filter };
        let actual = if reverse {
            source.preceding_filtered_siblings(filter).next().map(|n| n.id())
        } else {
            source.following_filtered_siblings(filter).next().map(|n| n.id())
        };
        assert_eq!(Some(nid(NodeId(5))), actual, "excluded subtree must not hide the following reachable sibling");
    }

    #[test] fn forward_excluded_child_explicit() { check(false, true, false); }
    #[test] fn reverse_excluded_child_explicit() { check(true, true, false); }
    #[test] fn forward_excluded_child_common() { check(false, true, true); }
    #[test] fn reverse_excluded_child_common() { check(true, true, true); }
    #[test] fn forward_excluded_leaf_control() { check(false, false, true); }
    #[test] fn reverse_excluded_leaf_control() { check(true, false, true); }
}
