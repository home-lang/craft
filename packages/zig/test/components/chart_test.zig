const std = @import("std");
const components = @import("components");
const Chart = components.Chart;
const ComponentProps = components.ComponentProps;

test "chart creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const chart = try Chart.init(allocator, .bar, props);
    defer chart.deinit();

    try std.testing.expect(chart.chart_type == .bar);
    try std.testing.expect(chart.data.items.len == 0);
    try std.testing.expect(chart.legend_enabled);
}

test "chart add data points" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const chart = try Chart.init(allocator, .line, props);
    defer chart.deinit();

    try chart.addDataPoint("Q1", 100.0, null);
    try chart.addDataPoint("Q2", 150.0, .{ 255, 0, 0, 255 });
    try chart.addDataPoint("Q3", 200.0, null);

    try std.testing.expect(chart.data.items.len == 3);
    try std.testing.expectEqualStrings("Q1", chart.data.items[0].label);
    try std.testing.expect(chart.data.items[0].value == 100.0);
}

test "chart remove data point" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const chart = try Chart.init(allocator, .bar, props);
    defer chart.deinit();

    try chart.addDataPoint("A", 10.0, null);
    try chart.addDataPoint("B", 20.0, null);
    try chart.addDataPoint("C", 30.0, null);

    chart.removeDataPoint(1);
    try std.testing.expect(chart.data.items.len == 2);
}

test "chart clear data" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const chart = try Chart.init(allocator, .pie, props);
    defer chart.deinit();

    try chart.addDataPoint("A", 10.0, null);
    try chart.addDataPoint("B", 20.0, null);
    chart.clearData();

    try std.testing.expect(chart.data.items.len == 0);
}

test "chart set labels" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const chart = try Chart.init(allocator, .bar, props);
    defer chart.deinit();

    chart.setLabels("Sales Data", "Quarter", "Revenue");
    try std.testing.expectEqualStrings("Sales Data", chart.title.?);
    try std.testing.expectEqualStrings("Quarter", chart.x_label.?);
    try std.testing.expectEqualStrings("Revenue", chart.y_label.?);
}

test "chart calculations" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const chart = try Chart.init(allocator, .bar, props);
    defer chart.deinit();

    try chart.addDataPoint("A", 10.0, null);
    try chart.addDataPoint("B", 20.0, null);
    try chart.addDataPoint("C", 30.0, null);

    const total = chart.getTotal();
    const average = chart.getAverage();

    try std.testing.expect(total == 60.0);
    try std.testing.expect(average == 20.0);
}

test "chart get data point" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const chart = try Chart.init(allocator, .line, props);
    defer chart.deinit();

    try chart.addDataPoint("Point1", 42.0, null);

    const point = chart.getDataPoint(0);
    try std.testing.expect(point != null);
    try std.testing.expectEqualStrings("Point1", point.?.label);
    try std.testing.expect(point.?.value == 42.0);

    const invalid = chart.getDataPoint(999);
    try std.testing.expect(invalid == null);
}
