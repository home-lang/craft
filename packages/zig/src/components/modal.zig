const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Modal/Dialog Component
pub const Modal = struct {
    component: Component,
    title: ?[]const u8,
    content: *Component,
    footer: ?*Component,
    visible: bool,
    closable: bool,
    backdrop: bool,
    on_open: ?*const fn () void,
    on_close: ?*const fn () void,

    pub fn init(allocator: std.mem.Allocator, content: *Component, props: ComponentProps) !*Modal {
        const modal = try allocator.create(Modal);
        modal.* = Modal{
            .component = try Component.init(allocator, "modal", props),
            .title = null,
            .content = content,
            .footer = null,
            .visible = false,
            .closable = true,
            .backdrop = true,
            .on_open = null,
            .on_close = null,
        };
        return modal;
    }

    pub fn deinit(self: *Modal) void {
        self.content.deinit();
        self.component.allocator.destroy(self.content);
        if (self.footer) |footer| {
            footer.deinit();
            self.component.allocator.destroy(footer);
        }
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn open(self: *Modal) void {
        self.visible = true;
        if (self.on_open) |callback| {
            callback();
        }
    }

    pub fn close(self: *Modal) void {
        if (self.closable) {
            self.visible = false;
            if (self.on_close) |callback| {
                callback();
            }
        }
    }

    pub fn toggle(self: *Modal) void {
        if (self.visible) {
            self.close();
        } else {
            self.open();
        }
    }

    pub fn setTitle(self: *Modal, title: []const u8) void {
        self.title = title;
    }

    pub fn setFooter(self: *Modal, footer: *Component) void {
        if (self.footer) |old_footer| {
            old_footer.deinit();
            self.component.allocator.destroy(old_footer);
        }
        self.footer = footer;
    }

    pub fn setClosable(self: *Modal, closable: bool) void {
        self.closable = closable;
    }

    pub fn setBackdrop(self: *Modal, backdrop: bool) void {
        self.backdrop = backdrop;
    }

    pub fn onOpen(self: *Modal, callback: *const fn () void) void {
        self.on_open = callback;
    }

    pub fn onClose(self: *Modal, callback: *const fn () void) void {
        self.on_close = callback;
    }
};
