const std = @import("std");
const components = @import("components");
const DataGrid = components.DataGrid;
const Row = DataGrid.Row;
const SortDirection = DataGrid.SortDirection;
const Alignment = DataGrid.Alignment;
const ComponentProps = components.ComponentProps;

var selected_row_index: usize = 0;
var sort_column_index: usize = 0;
var sort_dir: SortDirection = .none;
var page_number: usize = 0;

fn handleRowSelect(index: usize) void {
    selected_row_index = index;
}

fn handleSort(column: usize, direction: SortDirection) void {
    sort_column_index = column;
    sort_dir = direction;
}

fn handlePageChange(page: usize) void {
    page_number = page;
}

test "data grid creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    try std.testing.expect(grid.columns.items.len == 0);
    try std.testing.expect(grid.rows.items.len == 0);
    try std.testing.expect(grid.page_size == 10);
    try std.testing.expect(grid.current_page == 0);
    try std.testing.expect(grid.selectable);
}

test "data grid add columns" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    try grid.addColumn("id", "ID");
    try grid.addColumn("name", "Name");

    try std.testing.expect(grid.columns.items.len == 2);
    try std.testing.expectEqualStrings("ID", grid.columns.items[0].label);
    try std.testing.expectEqualStrings("Name", grid.columns.items[1].label);
}

test "data grid add and remove rows" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    try grid.addColumn("id", "ID");
    try grid.addColumn("name", "Name");

    var row1 = Row.init(allocator, "row1");
    try row1.addCell("1");
    try row1.addCell("Alice");
    try grid.addRow(row1);

    var row2 = Row.init(allocator, "row2");
    try row2.addCell("2");
    try row2.addCell("Bob");
    try grid.addRow(row2);

    try std.testing.expect(grid.rows.items.len == 2);
    try std.testing.expectEqualStrings("Alice", grid.rows.items[0].cells.items[1]);

    grid.removeRow(0);
    try std.testing.expect(grid.rows.items.len == 1);
}

test "data grid row selection" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    var row = Row.init(allocator, "row1");
    try row.addCell("1");
    try grid.addRow(row);

    selected_row_index = 0;
    grid.onRowSelect(&handleRowSelect);

    grid.selectRow(0);
    try std.testing.expect(grid.isRowSelected(0));
    try std.testing.expect(selected_row_index == 0);

    grid.deselectRow(0);
    try std.testing.expect(!grid.isRowSelected(0));
}

test "data grid multi select" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    var row1 = Row.init(allocator, "row1");
    try row1.addCell("1");
    try grid.addRow(row1);

    var row2 = Row.init(allocator, "row2");
    try row2.addCell("2");
    try grid.addRow(row2);

    // Single select by default
    grid.selectRow(0);
    grid.selectRow(1);
    try std.testing.expect(grid.selected_rows.items.len == 1);

    // Enable multi-select
    grid.setMultiSelect(true);
    grid.selectRow(0);
    grid.selectRow(1);
    try std.testing.expect(grid.selected_rows.items.len == 2);
}

test "data grid sorting" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    try grid.addColumn("name", "Name");

    sort_column_index = 0;
    sort_dir = .none;
    grid.onSort(&handleSort);

    grid.sortByColumn(0, .ascending);
    try std.testing.expect(grid.sort_column == 0);
    try std.testing.expect(grid.sort_direction == .ascending);
    try std.testing.expect(sort_dir == .ascending);
}

test "data grid toggle sort" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    try grid.addColumn("name", "Name");

    grid.toggleSort(0);
    try std.testing.expect(grid.sort_direction == .ascending);

    grid.toggleSort(0);
    try std.testing.expect(grid.sort_direction == .descending);

    grid.toggleSort(0);
    try std.testing.expect(grid.sort_direction == .none);
}

test "data grid pagination" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    // Add 25 rows
    var i: usize = 0;
    while (i < 25) : (i += 1) {
        var row = Row.init(allocator, "row");
        try row.addCell("data");
        try grid.addRow(row);
    }

    grid.setPageSize(10);
    try std.testing.expect(grid.getTotalPages() == 3);

    try std.testing.expect(grid.getPageStart() == 0);
    try std.testing.expect(grid.getPageEnd() == 10);

    grid.setPage(1);
    try std.testing.expect(grid.getPageStart() == 10);
    try std.testing.expect(grid.getPageEnd() == 20);

    grid.setPage(2);
    try std.testing.expect(grid.getPageStart() == 20);
    try std.testing.expect(grid.getPageEnd() == 25);
}

test "data grid next and previous page" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    // Add 25 rows
    var i: usize = 0;
    while (i < 25) : (i += 1) {
        var row = Row.init(allocator, "row");
        try row.addCell("data");
        try grid.addRow(row);
    }

    grid.setPageSize(10);
    page_number = 0;
    grid.onPageChange(&handlePageChange);

    try std.testing.expect(grid.current_page == 0);

    grid.nextPage();
    try std.testing.expect(grid.current_page == 1);
    try std.testing.expect(page_number == 1);

    grid.previousPage();
    try std.testing.expect(grid.current_page == 0);
    try std.testing.expect(page_number == 0);
}

test "data grid clear rows" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    var row1 = Row.init(allocator, "row1");
    try row1.addCell("1");
    try grid.addRow(row1);

    var row2 = Row.init(allocator, "row2");
    try row2.addCell("2");
    try grid.addRow(row2);

    grid.selectRow(0);
    try std.testing.expect(grid.rows.items.len == 2);
    try std.testing.expect(grid.selected_rows.items.len == 1);

    grid.clearRows();
    try std.testing.expect(grid.rows.items.len == 0);
    try std.testing.expect(grid.selected_rows.items.len == 0);
}

test "data grid selectable state" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    var row = Row.init(allocator, "row1");
    try row.addCell("1");
    try grid.addRow(row);

    grid.setSelectable(false);
    try std.testing.expect(!grid.selectable);

    grid.selectRow(0);
    try std.testing.expect(!grid.isRowSelected(0));
}

test "data grid filter" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    grid.setPage(5);
    try std.testing.expect(grid.current_page == 5);

    grid.setFilter("search");
    try std.testing.expect(grid.current_page == 0); // Reset to first page
}

test "data grid column options" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    const grid = try DataGrid.init(allocator, props);
    defer grid.deinit();

    try grid.addColumnWithOptions("id", "ID", false, false, .center);

    try std.testing.expect(!grid.columns.items[0].sortable);
    try std.testing.expect(!grid.columns.items[0].resizable);
    try std.testing.expect(grid.columns.items[0].alignment == .center);

    // Should not sort non-sortable column
    grid.sortByColumn(0, .ascending);
    try std.testing.expect(grid.sort_column == null);
}
