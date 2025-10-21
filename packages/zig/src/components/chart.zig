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
        chart.* = Chart{
            .component = try Component.init(allocator, "chart", props),
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
        self.data.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addDataPoint(self: *Chart, label: []const u8, value: f64, color: ?[4]u8) !void {
        try self.data.append(self.component.allocator, .{
            .label = label,
            .value = value,
            .color = color,
        });
    }

    pub fn removeDataPoint(self: *Chart, index: usize) void {
        if (index < self.data.items.len) {
            _ = self.data.swapRemove(index);
        }
    }

    pub fn clearData(self: *Chart) void {
        self.data.clearRetainingCapacity();
    }

    pub fn setLabels(self: *Chart, title: ?[]const u8, x_label: ?[]const u8, y_label: ?[]const u8) void {
        self.title = title;
        self.x_label = x_label;
        self.y_label = y_label;
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
