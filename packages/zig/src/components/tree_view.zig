const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// TreeView Component - Hierarchical data display
pub const TreeView = struct {
    component: Component,
    root: ?*TreeNode,
    selected_node: ?*TreeNode,
    on_select: ?*const fn (*TreeNode) void,
    on_expand: ?*const fn (*TreeNode) void,
    on_collapse: ?*const fn (*TreeNode) void,

    pub const TreeNode = struct {
        id: []const u8,
        label: []const u8,
        children: std.ArrayList(*TreeNode),
        parent: ?*TreeNode,
        expanded: bool,
        selectable: bool,
        data: ?*anyopaque,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, id: []const u8, label: []const u8) !*TreeNode {
            const node = try allocator.create(TreeNode);
            node.* = TreeNode{
                .id = id,
                .label = label,
                .children = .{},
                .parent = null,
                .expanded = false,
                .selectable = true,
                .data = null,
                .allocator = allocator,
            };
            return node;
        }

        pub fn deinit(self: *TreeNode) void {
            for (self.children.items) |child| {
                child.deinit();
            }
            self.children.deinit(self.allocator);
            self.allocator.destroy(self);
        }

        pub fn addChild(self: *TreeNode, child: *TreeNode) !void {
            child.parent = self;
            try self.children.append(self.allocator, child);
        }

        pub fn removeChild(self: *TreeNode, child: *TreeNode) void {
            for (self.children.items, 0..) |c, i| {
                if (c == child) {
                    _ = self.children.swapRemove(i);
                    child.parent = null;
                    break;
                }
            }
        }

        pub fn getDepth(self: *const TreeNode) usize {
            var depth: usize = 0;
            var current = self.parent;
            while (current) |node| {
                depth += 1;
                current = node.parent;
            }
            return depth;
        }

        pub fn isLeaf(self: *const TreeNode) bool {
            return self.children.items.len == 0;
        }

        pub fn hasChildren(self: *const TreeNode) bool {
            return self.children.items.len > 0;
        }

        pub fn findById(self: *TreeNode, id: []const u8) ?*TreeNode {
            if (std.mem.eql(u8, self.id, id)) {
                return self;
            }

            for (self.children.items) |child| {
                if (child.findById(id)) |found| {
                    return found;
                }
            }

            return null;
        }
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*TreeView {
        const tree = try allocator.create(TreeView);
        tree.* = TreeView{
            .component = try Component.init(allocator, "tree_view", props),
            .root = null,
            .selected_node = null,
            .on_select = null,
            .on_expand = null,
            .on_collapse = null,
        };
        return tree;
    }

    pub fn deinit(self: *TreeView) void {
        if (self.root) |root| {
            root.deinit();
        }
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn setRoot(self: *TreeView, root: *TreeNode) void {
        if (self.root) |old_root| {
            old_root.deinit();
        }
        self.root = root;
    }

    pub fn getRoot(self: *const TreeView) ?*TreeNode {
        return self.root;
    }

    pub fn selectNode(self: *TreeView, node: *TreeNode) void {
        if (!node.selectable) return;

        self.selected_node = node;
        if (self.on_select) |callback| {
            callback(node);
        }
    }

    pub fn expandNode(self: *TreeView, node: *TreeNode) void {
        if (!node.expanded and node.hasChildren()) {
            node.expanded = true;
            if (self.on_expand) |callback| {
                callback(node);
            }
        }
    }

    pub fn collapseNode(self: *TreeView, node: *TreeNode) void {
        if (node.expanded) {
            node.expanded = false;
            if (self.on_collapse) |callback| {
                callback(node);
            }
        }
    }

    pub fn toggleNode(self: *TreeView, node: *TreeNode) void {
        if (node.expanded) {
            self.collapseNode(node);
        } else {
            self.expandNode(node);
        }
    }

    pub fn expandAll(self: *TreeView) void {
        if (self.root) |root| {
            self.expandNodeRecursive(root);
        }
    }

    pub fn collapseAll(self: *TreeView) void {
        if (self.root) |root| {
            self.collapseNodeRecursive(root);
        }
    }

    fn expandNodeRecursive(self: *TreeView, node: *TreeNode) void {
        if (node.hasChildren()) {
            node.expanded = true;
            for (node.children.items) |child| {
                self.expandNodeRecursive(child);
            }
        }
    }

    fn collapseNodeRecursive(self: *TreeView, node: *TreeNode) void {
        if (node.expanded) {
            node.expanded = false;
            for (node.children.items) |child| {
                self.collapseNodeRecursive(child);
            }
        }
    }

    pub fn findNodeById(self: *TreeView, id: []const u8) ?*TreeNode {
        if (self.root) |root| {
            return root.findById(id);
        }
        return null;
    }

    pub fn clearSelection(self: *TreeView) void {
        self.selected_node = null;
    }

    pub fn onSelect(self: *TreeView, callback: *const fn (*TreeNode) void) void {
        self.on_select = callback;
    }

    pub fn onExpand(self: *TreeView, callback: *const fn (*TreeNode) void) void {
        self.on_expand = callback;
    }

    pub fn onCollapse(self: *TreeView, callback: *const fn (*TreeNode) void) void {
        self.on_collapse = callback;
    }
};
