const std = @import("std");
const string_lib = @import("./string.zig");

pub const Point = struct {
    x: usize,
    y: usize,

    // Comparator for sorting points top-to-bottom then left-to-right.
    pub fn lessThan(_: void, a: Point, b: Point) bool {
        return if (a.y == b.y) a.x < b.x else a.y < b.y;
    }
};

pub fn noop(comptime Out: type, value: Out) fn (u8) Out {
    return struct {
        pub fn f(_: u8) Out {
            return value;
        }
    }.f;
}

pub fn grid(
    comptime GridItem: type,
    inputToGridItem: fn (u8) GridItem,
) type {
    return struct {
        const Grid = @This();
        const Row = std.ArrayList(GridItem);
        const Rows = std.ArrayList(Row);

        const IteartorPoint = struct { Point, GridItem };

        pub const Iterator = struct {
            g: *const Grid,
            coords: Point = .{ .x = 0, .y = 0 },

            pub fn next(it: *Iterator) ?IteartorPoint {
                if (it.coords.y > it.g.height() - 1) {
                    return null;
                }

                const p = Point{ .x = it.coords.x, .y = it.coords.y };

                const grid_item = it.g.at(it.coords.x, it.coords.y);
                if (it.coords.x == it.g.width() - 1) {
                    it.coords.x = 0;
                    it.coords.y += 1;
                } else {
                    it.coords.x += 1;
                }

                return .{ p, grid_item };
            }
        };

        rows: Rows,

        pub fn init(allocator: std.mem.Allocator, input: []const u8, size_optional: ?usize) !Grid {
            const size = if (size_optional) |s| s else 10;

            var rows = try Rows.initCapacity(allocator, size);

            var lines = std.mem.splitSequence(u8, input, "\n");
            while (lines.next()) |line| {
                var row = try Row.initCapacity(allocator, size);
                for (line) |char| {
                    try row.append(allocator, inputToGridItem(char));
                }

                try rows.append(allocator, row);
            }

            return Grid{ .rows = rows };
        }

        pub fn deinit(self: *Grid, allocator: std.mem.Allocator) void {
            for (self.rows.items) |*row| {
                row.deinit(allocator);
            }
            self.rows.deinit(allocator);
        }

        pub fn initEmpty(allocator: std.mem.Allocator, w: usize, h: usize, base_value: GridItem) !Grid {
            var rows = try Rows.initCapacity(allocator, h);
            errdefer {
                for (rows.items) |*row| {
                    row.deinit(allocator);
                }
                rows.deinit(allocator);
            }

            var y: usize = 0;
            while (y < h) : (y += 1) {
                var row = try Row.initCapacity(allocator, w);
                errdefer row.deinit(allocator);

                var x: usize = 0;
                while (x < w) : (x += 1) {
                    try row.append(allocator, base_value);
                }

                try rows.append(allocator, row);
            }

            return Grid{ .rows = rows };
        }

        pub fn at(self: *const Grid, x: usize, y: usize) GridItem {
            return self.rows.items[y].items[x];
        }

        pub fn set(self: *Grid, x: usize, y: usize, item: GridItem) void {
            self.rows.items[y].items[x] = item;
        }

        pub fn iterator(self: *const Grid) Iterator {
            return .{ .g = self, .coords = .{ .x = 0, .y = 0 } };
        }

        pub fn height(self: *const Grid) usize {
            return self.rows.items.len;
        }

        pub fn width(self: *const Grid) usize {
            if (self.rows.items.len == 0) {
                return 0;
            }

            return self.rows.items[0].items.len;
        }

        pub fn pointTop(_: *const Grid, point: Point) ?Point {
            return if (point.y == 0) null else .{ .x = point.x, .y = point.y - 1 };
        }
        pub fn pointDown(self: *const Grid, point: Point) ?Point {
            return if (point.y == self.height() - 1) null else .{ .x = point.x, .y = point.y + 1 };
        }
        pub fn pointLeft(_: *const Grid, point: Point) ?Point {
            return if (point.x == 0) null else .{ .x = point.x - 1, .y = point.y };
        }
        pub fn pointRight(self: *const Grid, point: Point) ?Point {
            return if (point.x == self.width() - 1) null else .{ .x = point.x + 1, .y = point.y };
        }
        pub fn pointTopLeft(_: *const Grid, point: Point) ?Point {
            return if (point.y == 0 or point.x == 0) null else .{ .x = point.x - 1, .y = point.y - 1 };
        }
        pub fn pointTopRight(self: *const Grid, point: Point) ?Point {
            return if (point.y == 0 or point.x == self.width() - 1) null else .{ .x = point.x + 1, .y = point.y - 1 };
        }
        pub fn pointBottomLeft(self: *const Grid, point: Point) ?Point {
            return if (point.x == 0 or point.y == self.height() - 1) null else .{ .x = point.x - 1, .y = point.y + 1 };
        }
        pub fn pointBottomRight(self: *const Grid, point: Point) ?Point {
            return if (point.y == self.height() - 1 or point.x == self.width() - 1) null else .{ .x = point.x + 1, .y = point.y + 1 };
        }

        pub fn adjacents(self: *const Grid, allocator: std.mem.Allocator, p: Point, diagonals: bool) !std.ArrayList(Point) {
            const all_candidates = [_]?Point{
                self.pointTop(p),
                self.pointDown(p),
                self.pointLeft(p),
                self.pointRight(p),
                if (diagonals) self.pointTopLeft(p) else null,
                if (diagonals) self.pointTopRight(p) else null,
                if (diagonals) self.pointBottomLeft(p) else null,
                if (diagonals) self.pointBottomRight(p) else null,
            };

            var result = try std.ArrayList(Point).initCapacity(allocator, if (diagonals) 8 else 4);

            for (all_candidates) |optional_candidate| {
                if (optional_candidate) |candidate| {
                    result.appendAssumeCapacity(candidate);
                }
            }

            return result;
        }

        pub fn to_str(self: *Grid, allocator: std.mem.Allocator, gridItemToChar: fn (GridItem) u8) ![]const u8 {
            const is_str = comptime string_lib.isTypeStr(GridItem);
            var str = try std.ArrayList(u8).initCapacity(allocator, self.width() * self.height() * 2);

            for (self.rows.items, 0..) |row, row_idx| {
                for (row.items) |cell| {
                    const cell_str = if (is_str)
                        try std.fmt.allocPrint(allocator, "{s}", .{cell})
                    else
                        try std.fmt.allocPrint(allocator, "{c}", .{gridItemToChar(cell)});
                    try str.appendSlice(allocator, cell_str);
                    allocator.free(cell_str);
                }
                if (row_idx < self.rows.items.len - 1) {
                    try str.append(allocator, '\n');
                }
            }

            return str.toOwnedSlice(allocator);
        }

        pub fn to_ascii(self: *Grid, allocator: std.mem.Allocator) ![]const u8 {
            // Assumes GridItem is u8, directly appends ASCII characters
            var str = try std.ArrayList(u8).initCapacity(allocator, self.width() * self.height() + self.height());

            for (self.rows.items, 0..) |row, row_idx| {
                for (row.items) |cell| {
                    try str.append(allocator, cell);
                }
                if (row_idx < self.rows.items.len - 1) {
                    try str.append(allocator, '\n');
                }
            }

            return str.toOwnedSlice(allocator);
        }
    };
}

const _GridItem = enum { dot, star };
fn _inputToGridItem(c: u8) _GridItem {
    return if (c == '.') _GridItem.dot else _GridItem.star;
}
const _Grid = grid(_GridItem, _inputToGridItem);
fn _testGrid() !_Grid {
    const allocator = std.testing.allocator;
    const input = ".....\n..*..\n.....";
    return try _Grid.init(allocator, input, 5);
}

test "height, width" {
    const allocator = std.testing.allocator;
    var g = try _testGrid();
    defer g.deinit(allocator);

    try std.testing.expectEqual(3, g.height());
    try std.testing.expectEqual(5, g.width());
}

test "adjacents" {
    const allocator = std.testing.allocator;
    var g = try _testGrid();
    defer g.deinit(allocator);

    var point00 = try g.adjacents(allocator, .{ .x = 0, .y = 0 }, true);
    defer point00.deinit(allocator);
    std.mem.sort(Point, point00.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 1, .y = 0 },
            .{ .x = 0, .y = 1 },
            .{ .x = 1, .y = 1 },
        },
        point00.items,
    );

    var point00_no_diag = try g.adjacents(allocator, .{ .x = 0, .y = 0 }, false);
    defer point00_no_diag.deinit(allocator);
    std.mem.sort(Point, point00_no_diag.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 1, .y = 0 },
            .{ .x = 0, .y = 1 },
        },
        point00_no_diag.items,
    );

    var point01 = try g.adjacents(allocator, .{ .x = 0, .y = 1 }, true);
    defer point01.deinit(allocator);
    std.mem.sort(Point, point01.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 0, .y = 0 },
            .{ .x = 1, .y = 0 },
            .{ .x = 1, .y = 1 },
            .{ .x = 0, .y = 2 },
            .{ .x = 1, .y = 2 },
        },
        point01.items,
    );

    var point01_nodiag = try g.adjacents(allocator, .{ .x = 0, .y = 1 }, false);
    defer point01_nodiag.deinit(allocator);
    std.mem.sort(Point, point01_nodiag.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 0, .y = 0 },
            .{ .x = 1, .y = 1 },
            .{ .x = 0, .y = 2 },
        },
        point01_nodiag.items,
    );

    var point11 = try g.adjacents(allocator, .{ .x = 1, .y = 1 }, true);
    defer point11.deinit(allocator);
    std.mem.sort(Point, point11.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 2, .y = 0 }, .{ .x = 0, .y = 1 }, .{ .x = 2, .y = 1 }, .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } },
        point11.items,
    );

    var point11_nodiag = try g.adjacents(allocator, .{ .x = 1, .y = 1 }, false);
    defer point11_nodiag.deinit(allocator);
    std.mem.sort(Point, point11_nodiag.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 1, .y = 0 },
            .{ .x = 0, .y = 1 },
            .{ .x = 2, .y = 1 },
            .{ .x = 1, .y = 2 },
        },
        point11_nodiag.items,
    );

    var point53 = try g.adjacents(allocator, .{ .x = 4, .y = 3 }, true);
    defer point53.deinit(allocator);
    std.mem.sort(Point, point53.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 3, .y = 2 },
            .{ .x = 4, .y = 2 },
            .{ .x = 3, .y = 3 },
            .{ .x = 3, .y = 4 },
            .{ .x = 4, .y = 4 },
        },
        point53.items,
    );

    var point53_nodiag = try g.adjacents(allocator, .{ .x = 4, .y = 3 }, false);
    defer point53_nodiag.deinit(allocator);
    std.mem.sort(Point, point53_nodiag.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 4, .y = 2 },
            .{ .x = 3, .y = 3 },
            .{ .x = 4, .y = 4 },
        },
        point53_nodiag.items,
    );

    var point52 = try g.adjacents(allocator, .{ .x = 4, .y = 2 }, true);
    defer point52.deinit(allocator);
    std.mem.sort(Point, point52.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 3, .y = 1 },
            .{ .x = 4, .y = 1 },
            .{ .x = 3, .y = 2 },
        },
        point52.items,
    );

    var point52_nodiag = try g.adjacents(allocator, .{ .x = 4, .y = 2 }, false);
    defer point52_nodiag.deinit(allocator);
    std.mem.sort(Point, point52_nodiag.items, {}, Point.lessThan);
    try std.testing.expectEqualSlices(
        Point,
        &[_]Point{
            .{ .x = 4, .y = 1 },
            .{ .x = 3, .y = 2 },
        },
        point52_nodiag.items,
    );
}
