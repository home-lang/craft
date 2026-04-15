const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Chart Component - Data Visualization
pub const Chart = struct {
    component: Component,
    chart_type: ChartType,
    data: std.ArrayList(DataPoint),
    title: ?[]const u8,
    x_label: ?[]const u8,
    y_label: ?[]const u8,
    legend_enabled: bool,

    pub const ChartType = enum {
        line,
        bar,
        pie,
        scatter,
        area,
        doughnut,
    };

    pub const DataPoint = struct {
        label: []const u8,
        value: f64,
        color: ?[4]u8 = null,
    };

    pub fn init(allocator: std.mem.Allocator, chart_type: ChartType, props: ComponentProps) !*Chart {
        const chart = try allocator.create(Chart);
        errdefer allocator.destroy(chart);
        const component = try Component.init(allocator, "chart", props);
        chart.* = Chart{
            .component = component,
            .chart_type = chart_type,
            .data = .{},
            .title = null,
            .x_label = null,
            .y_label = null,
            .legend_enabled = true,
        };
        return chart;
    }

    pub fn deinit(self: *Chart) void {
        // Free owned label storage (see `addDataPoint` and `setLabels`).
        const allocator = self.component.allocator;
        for (self.data.items) |point| {
            allocator.free(point.label);
        }
        if (self.title) |t| allocator.free(t);
        if (self.x_label) |l| allocator.free(l);
        if (self.y_label) |l| allocator.free(l);
        self.data.deinit(allocator);
        self.component.deinit();
        allocator.destroy(self);
    }

    pub fn addDataPoint(self: *Chart, label: []const u8, value: f64, color: ?[4]u8) !void {
        // Dupe the label so the chart owns its storage — the old borrowing
        // semantics forced every caller to keep label buffers alive for the
        // chart's entire lifetime.
        const allocator = self.component.allocator;
        const label_dup = try allocator.dupe(u8, label);
        errdefer allocator.free(label_dup);
        try self.data.append(allocator, .{
            .label = label_dup,
            .value = value,
            .color = color,
        });
    }

    pub fn removeDataPoint(self: *Chart, index: usize) void {
        // `orderedRemove` preserves the rest of the series' order. For
        // line / area / bar charts where order is the x-axis, the previous
        // `swapRemove` silently scrambled the chart.
        if (index < self.data.items.len) {
            const removed = self.data.orderedRemove(index);
            self.component.allocator.free(removed.label);
        }
    }

    pub fn clearData(self: *Chart) void {
        const allocator = self.component.allocator;
        for (self.data.items) |point| allocator.free(point.label);
        self.data.clearRetainingCapacity();
    }

    /// Set the chart's textual labels. Each label is duped so the chart
    /// owns its storage and the caller doesn't have to keep its source
    /// buffers alive. Previous versions stored borrowed slices.
    pub fn setLabels(self: *Chart, title: ?[]const u8, x_label: ?[]const u8, y_label: ?[]const u8) !void {
        const allocator = self.component.allocator;

        const new_title = if (title) |t| try allocator.dupe(u8, t) else null;
        errdefer if (new_title) |t| allocator.free(t);
        const new_x = if (x_label) |l| try allocator.dupe(u8, l) else null;
        errdefer if (new_x) |l| allocator.free(l);
        const new_y = if (y_label) |l| try allocator.dupe(u8, l) else null;
        errdefer if (new_y) |l| allocator.free(l);

        if (self.title) |t| allocator.free(t);
        if (self.x_label) |l| allocator.free(l);
        if (self.y_label) |l| allocator.free(l);

        self.title = new_title;
        self.x_label = new_x;
        self.y_label = new_y;
    }

    pub fn setLegendEnabled(self: *Chart, enabled: bool) void {
        self.legend_enabled = enabled;
    }

    pub fn getDataPoint(self: *const Chart, index: usize) ?DataPoint {
        if (index < self.data.items.len) {
            return self.data.items[index];
        }
        return null;
    }

    pub fn getTotal(self: *const Chart) f64 {
        var total: f64 = 0.0;
        for (self.data.items) |point| {
            total += point.value;
        }
        return total;
    }

    pub fn getAverage(self: *const Chart) f64 {
        if (self.data.items.len == 0) return 0.0;
        return self.getTotal() / @as(f64, @floatFromInt(self.data.items.len));
    }
};
