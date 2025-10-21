const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// DataGrid Component - Advanced table with sorting, filtering, and pagination
pub const DataGrid = struct {
    component: Component,
    columns: std.ArrayList(Column),
    rows: std.ArrayList(Row),
    selected_rows: std.ArrayList(usize),
    sort_column: ?usize,
    sort_direction: SortDirection,
    page_size: usize,
    current_page: usize,
    filter_text: ?[]const u8,
    selectable: bool,
    multi_select: bool,
    on_row_select: ?*const fn (usize) void,
    on_sort: ?*const fn (usize, SortDirection) void,
    on_page_change: ?*const fn (usize) void,

    pub const Column = struct {
        id: []const u8,
        label: []const u8,
        width: ?usize,
        sortable: bool,
        resizable: bool,
        alignment: Alignment,
    };

    pub const Row = struct {
        id: []const u8,
        cells: std.ArrayList([]const u8),
        data: ?*anyopaque,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, id: []const u8) Row {
            return Row{
                .id = id,
                .cells = .{},
                .data = null,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Row) void {
            self.cells.deinit(self.allocator);
        }

        pub fn addCell(self: *Row, value: []const u8) !void {
            try self.cells.append(self.allocator, value);
        }
    };

    pub const SortDirection = enum {
        none,
        ascending,
        descending,
    };

    pub const Alignment = enum {
        left,
        center,
        right,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps) !*DataGrid {
        const grid = try allocator.create(DataGrid);
        grid.* = DataGrid{
            .component = try Component.init(allocator, "data_grid", props),
            .columns = .{},
            .rows = .{},
            .selected_rows = .{},
            .sort_column = null,
            .sort_direction = .none,
            .page_size = 10,
            .current_page = 0,
            .filter_text = null,
            .selectable = true,
            .multi_select = false,
            .on_row_select = null,
            .on_sort = null,
            .on_page_change = null,
        };
        return grid;
    }

    pub fn deinit(self: *DataGrid) void {
        self.columns.deinit(self.component.allocator);
        for (self.rows.items) |*row| {
            row.deinit();
        }
        self.rows.deinit(self.component.allocator);
        self.selected_rows.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    pub fn addColumn(self: *DataGrid, id: []const u8, label: []const u8) !void {
        try self.columns.append(self.component.allocator, .{
            .id = id,
            .label = label,
            .width = null,
            .sortable = true,
            .resizable = true,
            .alignment = .left,
        });
    }

    pub fn addColumnWithOptions(
        self: *DataGrid,
        id: []const u8,
        label: []const u8,
        sortable: bool,
        resizable: bool,
        alignment: Alignment,
    ) !void {
        try self.columns.append(self.component.allocator, .{
            .id = id,
            .label = label,
            .width = null,
            .sortable = sortable,
            .resizable = resizable,
            .alignment = alignment,
        });
    }

    pub fn addRow(self: *DataGrid, row: Row) !void {
        try self.rows.append(self.component.allocator, row);
    }

    pub fn removeRow(self: *DataGrid, index: usize) void {
        if (index < self.rows.items.len) {
            var row = self.rows.swapRemove(index);
            row.deinit();

            // Clear selection if removed row was selected
            self.deselectRow(index);
        }
    }

    pub fn clearRows(self: *DataGrid) void {
        for (self.rows.items) |*row| {
            row.deinit();
        }
        self.rows.clearRetainingCapacity();
        self.selected_rows.clearRetainingCapacity();
    }

    pub fn selectRow(self: *DataGrid, index: usize) void {
        if (!self.selectable or index >= self.rows.items.len) return;

        if (!self.multi_select) {
            self.selected_rows.clearRetainingCapacity();
        }

        // Check if already selected
        for (self.selected_rows.items) |selected| {
            if (selected == index) return;
        }

        self.selected_rows.append(self.component.allocator, index) catch return;

        if (self.on_row_select) |callback| {
            callback(index);
        }
    }

    pub fn deselectRow(self: *DataGrid, index: usize) void {
        var i: usize = 0;
        while (i < self.selected_rows.items.len) {
            if (self.selected_rows.items[i] == index) {
                _ = self.selected_rows.swapRemove(i);
                return;
            }
            i += 1;
        }
    }

    pub fn clearSelection(self: *DataGrid) void {
        self.selected_rows.clearRetainingCapacity();
    }

    pub fn isRowSelected(self: *const DataGrid, index: usize) bool {
        for (self.selected_rows.items) |selected| {
            if (selected == index) return true;
        }
        return false;
    }

    pub fn sortByColumn(self: *DataGrid, column_index: usize, direction: SortDirection) void {
        if (column_index >= self.columns.items.len) return;
        if (!self.columns.items[column_index].sortable) return;

        self.sort_column = column_index;
        self.sort_direction = direction;

        if (self.on_sort) |callback| {
            callback(column_index, direction);
        }
    }

    pub fn toggleSort(self: *DataGrid, column_index: usize) void {
        if (self.sort_column == column_index) {
            // Cycle through: none -> ascending -> descending -> none
            self.sort_direction = switch (self.sort_direction) {
                .none => .ascending,
                .ascending => .descending,
                .descending => .none,
            };
        } else {
            self.sort_column = column_index;
            self.sort_direction = .ascending;
        }

        if (self.on_sort) |callback| {
            callback(column_index, self.sort_direction);
        }
    }

    pub fn setPageSize(self: *DataGrid, size: usize) void {
        if (size > 0) {
            self.page_size = size;
            // Ensure current page is still valid
            const max_page = self.getTotalPages();
            if (self.current_page >= max_page and max_page > 0) {
                self.current_page = max_page - 1;
            }
        }
    }

    pub fn setPage(self: *DataGrid, page: usize) void {
        const max_page = self.getTotalPages();
        if (page < max_page) {
            self.current_page = page;

            if (self.on_page_change) |callback| {
                callback(page);
            }
        }
    }

    pub fn nextPage(self: *DataGrid) void {
        const max_page = self.getTotalPages();
        if (self.current_page + 1 < max_page) {
            self.setPage(self.current_page + 1);
        }
    }

    pub fn previousPage(self: *DataGrid) void {
        if (self.current_page > 0) {
            self.setPage(self.current_page - 1);
        }
    }

    pub fn getTotalPages(self: *const DataGrid) usize {
        if (self.page_size == 0) return 0;
        const total_rows = self.rows.items.len;
        return (total_rows + self.page_size - 1) / self.page_size;
    }

    pub fn getPageStart(self: *const DataGrid) usize {
        return self.current_page * self.page_size;
    }

    pub fn getPageEnd(self: *const DataGrid) usize {
        const start = self.getPageStart();
        const end = start + self.page_size;
        return @min(end, self.rows.items.len);
    }

    pub fn setFilter(self: *DataGrid, filter_text: ?[]const u8) void {
        self.filter_text = filter_text;
        self.current_page = 0; // Reset to first page when filtering
    }

    pub fn setSelectable(self: *DataGrid, selectable: bool) void {
        self.selectable = selectable;
        if (!selectable) {
            self.clearSelection();
        }
    }

    pub fn setMultiSelect(self: *DataGrid, multi_select: bool) void {
        self.multi_select = multi_select;
        if (!multi_select and self.selected_rows.items.len > 1) {
            // Keep only the first selected row
            const first = self.selected_rows.items[0];
            self.selected_rows.clearRetainingCapacity();
            self.selected_rows.append(self.component.allocator, first) catch {};
        }
    }

    pub fn onRowSelect(self: *DataGrid, callback: *const fn (usize) void) void {
        self.on_row_select = callback;
    }

    pub fn onSort(self: *DataGrid, callback: *const fn (usize, SortDirection) void) void {
        self.on_sort = callback;
    }

    pub fn onPageChange(self: *DataGrid, callback: *const fn (usize) void) void {
        self.on_page_change = callback;
    }
};
