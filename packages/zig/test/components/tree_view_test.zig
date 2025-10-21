const std = @import("std");
const components = @import("components");
const TreeView = components.TreeView;
const TreeNode = TreeView.TreeNode;
const ComponentProps = components.ComponentProps;

var selected_node_id: []const u8 = "";
var expanded_node_id: []const u8 = "";
var collapsed_node_id: []const u8 = "";

fn handleSelect(node: *TreeNode) void {
    selected_node_id = node.id;
}

fn handleExpand(node: *TreeNode) void {
    expanded_node_id = node.id;
}

fn handleCollapse(node: *TreeNode) void {
    collapsed_node_id = node.id;
}

test "tree view creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    try std.testing.expect(tree.root == null);
    try std.testing.expect(tree.selected_node == null);
}

test "tree node creation and hierarchy" {
    const allocator = std.testing.allocator;

    const root = try TreeNode.init(allocator, "root", "Root Node");
    defer root.deinit();

    const child1 = try TreeNode.init(allocator, "child1", "Child 1");
    const child2 = try TreeNode.init(allocator, "child2", "Child 2");

    try root.addChild(child1);
    try root.addChild(child2);

    try std.testing.expect(root.children.items.len == 2);
    try std.testing.expect(child1.parent == root);
    try std.testing.expect(child2.parent == root);
}

test "tree node depth" {
    const allocator = std.testing.allocator;

    const root = try TreeNode.init(allocator, "root", "Root");
    defer root.deinit();

    const child = try TreeNode.init(allocator, "child", "Child");
    const grandchild = try TreeNode.init(allocator, "grandchild", "Grandchild");

    try root.addChild(child);
    try child.addChild(grandchild);

    try std.testing.expect(root.getDepth() == 0);
    try std.testing.expect(child.getDepth() == 1);
    try std.testing.expect(grandchild.getDepth() == 2);
}

test "tree node is leaf" {
    const allocator = std.testing.allocator;

    const parent = try TreeNode.init(allocator, "parent", "Parent");
    defer parent.deinit();

    const child = try TreeNode.init(allocator, "child", "Child");

    try std.testing.expect(parent.isLeaf());
    try std.testing.expect(!parent.hasChildren());

    try parent.addChild(child);

    try std.testing.expect(!parent.isLeaf());
    try std.testing.expect(parent.hasChildren());
    try std.testing.expect(child.isLeaf());
}

test "tree view set root" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    const root = try TreeNode.init(allocator, "root", "Root");
    tree.setRoot(root);

    try std.testing.expect(tree.root != null);
    try std.testing.expectEqualStrings("root", tree.root.?.id);
}

test "tree view select node" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    const root = try TreeNode.init(allocator, "root", "Root");
    tree.setRoot(root);

    selected_node_id = "";
    tree.onSelect(&handleSelect);

    tree.selectNode(root);
    try std.testing.expect(tree.selected_node == root);
    try std.testing.expectEqualStrings("root", selected_node_id);
}

test "tree view expand and collapse" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    const root = try TreeNode.init(allocator, "root", "Root");
    const child = try TreeNode.init(allocator, "child", "Child");
    try root.addChild(child);
    tree.setRoot(root);

    expanded_node_id = "";
    collapsed_node_id = "";
    tree.onExpand(&handleExpand);
    tree.onCollapse(&handleCollapse);

    try std.testing.expect(!root.expanded);

    tree.expandNode(root);
    try std.testing.expect(root.expanded);
    try std.testing.expectEqualStrings("root", expanded_node_id);

    tree.collapseNode(root);
    try std.testing.expect(!root.expanded);
    try std.testing.expectEqualStrings("root", collapsed_node_id);
}

test "tree view toggle node" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    const root = try TreeNode.init(allocator, "root", "Root");
    const child = try TreeNode.init(allocator, "child", "Child");
    try root.addChild(child);
    tree.setRoot(root);

    try std.testing.expect(!root.expanded);

    tree.toggleNode(root);
    try std.testing.expect(root.expanded);

    tree.toggleNode(root);
    try std.testing.expect(!root.expanded);
}

test "tree view expand and collapse all" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    const root = try TreeNode.init(allocator, "root", "Root");
    const child1 = try TreeNode.init(allocator, "child1", "Child 1");
    const child2 = try TreeNode.init(allocator, "child2", "Child 2");
    const grandchild = try TreeNode.init(allocator, "grandchild", "Grandchild");

    try root.addChild(child1);
    try root.addChild(child2);
    try child1.addChild(grandchild);
    tree.setRoot(root);

    tree.expandAll();
    try std.testing.expect(root.expanded);
    try std.testing.expect(child1.expanded);

    tree.collapseAll();
    try std.testing.expect(!root.expanded);
    try std.testing.expect(!child1.expanded);
}

test "tree view find node by id" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    const root = try TreeNode.init(allocator, "root", "Root");
    const child = try TreeNode.init(allocator, "child", "Child");
    const grandchild = try TreeNode.init(allocator, "grandchild", "Grandchild");

    try root.addChild(child);
    try child.addChild(grandchild);
    tree.setRoot(root);

    const found = tree.findNodeById("grandchild");
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("Grandchild", found.?.label);

    const not_found = tree.findNodeById("nonexistent");
    try std.testing.expect(not_found == null);
}

test "tree node remove child" {
    const allocator = std.testing.allocator;

    const parent = try TreeNode.init(allocator, "parent", "Parent");
    defer parent.deinit();

    const child = try TreeNode.init(allocator, "child", "Child");
    defer child.deinit();

    try parent.addChild(child);
    try std.testing.expect(parent.children.items.len == 1);

    parent.removeChild(child);
    try std.testing.expect(parent.children.items.len == 0);
    try std.testing.expect(child.parent == null);
}

test "tree view non-selectable node" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const tree = try TreeView.init(allocator, props);
    defer tree.deinit();

    const root = try TreeNode.init(allocator, "root", "Root");
    root.selectable = false;
    tree.setRoot(root);

    tree.selectNode(root);
    try std.testing.expect(tree.selected_node == null);
}
