const std = @import("std");
const hashset = @import("set");
const string_lib = @import("./string.zig");

pub const Point = struct {
    x: usize,
    y: usize,

    // Comparator for sorting points top-to-bottom then left-to-right.
    pub fn lessThan(_: void, a: Point, b: Point) bool {
        return if (a.y == b.y) a.x < b.x else a.y < b.y;
    }

    pub fn eql(self: *const Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn lineTo(self: *const Point, allocator: std.mem.Allocator, other: Point) !std.ArrayList(Point) {
        if (other.x != self.x and other.y != self.y) return error.NotAligned;

        if (other.x == self.x) {
            const min_y = @min(self.y, other.y);
            const max_y = @max(self.y, other.y);
            var points = try std.ArrayList(Point).initCapacity(allocator, max_y - min_y + 1);
            for (min_y..max_y + 1) |y| {
                points.appendAssumeCapacity(.{ .x = self.x, .y = y });
            }
            return points;
        }

        const min_x = @min(self.x, other.x);
        const max_x = @max(self.x, other.x);
        var points = try std.ArrayList(Point).initCapacity(allocator, max_x - min_x + 1);
        for (min_x..max_x + 1) |x| {
            points.appendAssumeCapacity(.{ .x = x, .y = self.y });
        }
        return points;
    }

    pub fn rectangleTo(self: *const Point, allocator: std.mem.Allocator, other: Point, only_edges: bool) !std.ArrayList(Point) {
        const min_x = @min(self.x, other.x);
        const max_x = @max(self.x, other.x);
        const min_y = @min(self.y, other.y);
        const max_y = @max(self.y, other.y);

        var points = try std.ArrayList(Point).initCapacity(allocator, (max_x - min_x + 1) * (max_y - min_y + 1));
        for (min_y..max_y + 1) |y| {
            for (min_x..max_x + 1) |x| {
                if (only_edges) {
                    if (x == min_x or x == max_x or y == min_y or y == max_y) {
                        points.appendAssumeCapacity(.{ .x = x, .y = y });
                    }
                } else {
                    points.appendAssumeCapacity(.{ .x = x, .y = y });
                }
            }
        }
        return points;
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
        const Map = std.AutoHashMap(Point, GridItem);
        const Entry = struct { key: Point, value: GridItem };
        const GridItemSet = hashset.Set(GridItem);

        map: Map,
        empty_item: GridItem,
        max_y: usize,
        max_x: usize,

        pub fn init(allocator: std.mem.Allocator, input: []const u8, empty_item: GridItem) !Grid {
            var g = Grid.initEmpty(allocator, empty_item);

            var lines = std.mem.splitSequence(u8, input, "\n");
            var y: usize = 0;
            while (lines.next()) |line| {
                for (line, 0..) |char, x| {
                    try g.set(.{ .x = x, .y = y }, inputToGridItem(char));
                }

                y += 1;
            }

            return g;
        }

        pub fn initEmpty(allocator: std.mem.Allocator, empty_item: GridItem) Grid {
            return Grid{ .max_y = 0, .max_x = 0, .empty_item = empty_item, .map = .init(allocator) };
        }

        pub fn deinit(self: *Grid) void {
            self.map.deinit();
        }

        pub fn at(self: *const Grid, p: Point) GridItem {
            const maybe_map_point = self.map.get(p);

            if (maybe_map_point) |map_point| {
                return map_point;
            }

            return self.empty_item;
        }

        pub fn set(self: *Grid, p: Point, item: GridItem) !void {
            if (p.x > self.max_x) self.max_x = p.x;
            if (p.y > self.max_y) self.max_y = p.y;

            try self.map.put(p, item);
        }

        pub fn iterator(self: *const Grid) Map.Iterator {
            return self.map.iterator();
        }

        pub fn height(self: *const Grid) usize {
            return self.max_y + 1;
        }

        pub fn width(self: *const Grid) usize {
            return self.max_x + 1;
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

        pub fn cross(self: *const Grid, allocator: std.mem.Allocator, p: Point) !std.ArrayList(Entry) {
            var all_candidates = try std.ArrayList(Entry).initCapacity(allocator, self.width() + self.height() - 2);

            for (0..self.height()) |y| {
                const point = Point{ .x = p.x, .y = y };

                if (point.eql(p)) continue;

                all_candidates.appendAssumeCapacity(.{ .key = point, .value = self.at(point) });
            }

            for (0..self.width()) |x| {
                const point = Point{ .x = x, .y = p.y };

                if (point.eql(p)) continue;

                all_candidates.appendAssumeCapacity(.{ .key = point, .value = self.at(point) });
            }

            return all_candidates;
        }

        pub fn isPointInArea(self: *const Grid, p: Point, border_type: *const GridItemSet) !bool {
            if (border_type.contains(self.at(p))) return true;

            const horizontal_origin = Point{ .x = 0, .y = p.y };
            const horizontal_target = Point{ .x = self.width() - 1, .y = p.y };
            const vertical_origin = Point{ .x = p.x, .y = 0 };
            const vertical_target = Point{ .x = p.x, .y = self.height() - 1 };

            var horizontal_intersection_count: usize = 0;
            var last_point_type: GridItem = self.empty_item;
            for (horizontal_origin.x..horizontal_target.x) |x| {
                const horizontal_line_point = Point{ .x = x, .y = p.y };
                const horizontal_line_point_value = self.at(horizontal_line_point);
                if (horizontal_line_point.eql(p)) break;
                // if we're looping on the border, it doesn't count as multiple intersection
                if (border_type.contains(last_point_type) and border_type.contains(horizontal_line_point_value)) continue;

                last_point_type = horizontal_line_point_value;
                if (border_type.contains(last_point_type)) {
                    horizontal_intersection_count += 1;
                }
            }
            if (try std.math.mod(usize, horizontal_intersection_count, 2) == 0) return false;

            var vertical_intersection_count: usize = 0;
            last_point_type = self.empty_item;
            for (vertical_origin.y..vertical_target.y) |y| {
                const vertical_line_point = Point{ .x = p.x, .y = y };
                const vertical_line_point_value = self.at(vertical_line_point);
                if (vertical_line_point.eql(p)) break;
                // if we're looping on the border, it doesn't count as multiple intersection
                if (border_type.contains(last_point_type) and border_type.contains(vertical_line_point_value)) continue;

                last_point_type = vertical_line_point_value;
                if (border_type.contains(last_point_type)) {
                    vertical_intersection_count += 1;
                }
            }
            if (try std.math.mod(usize, vertical_intersection_count, 2) == 0) return false;

            return true;
        }

        pub fn toStr(self: *Grid, allocator: std.mem.Allocator, gridItemToChar: fn (GridItem) u8) ![]const u8 {
            const is_str = comptime string_lib.isTypeStr(GridItem);
            var str = try std.ArrayList(u8).initCapacity(allocator, self.width() * self.height());

            for (0..self.height()) |y| {
                for (0..self.width()) |x| {
                    const p = Point{ .x = x, .y = y };
                    const cell = self.at(p);
                    const cell_str = if (is_str)
                        try std.fmt.allocPrint(allocator, "{s}", .{cell})
                    else
                        try std.fmt.allocPrint(allocator, "{c}", .{gridItemToChar(cell)});
                    try str.appendSlice(allocator, cell_str);
                    allocator.free(cell_str);
                }
                if (y < self.height() - 1) {
                    try str.append(allocator, '\n');
                }
            }

            return str.toOwnedSlice(allocator);
        }

        pub fn toAscii(self: *Grid, allocator: std.mem.Allocator) ![]const u8 {
            // Assumes GridItem is u8, directly appends ASCII characters
            var str = try std.ArrayList(u8).initCapacity(allocator, self.width() * self.height() + self.height());

            for (0..self.height()) |y| {
                for (0..self.width()) |x| {
                    const cell = self.at(.{ .x = x, .y = y });
                    try str.append(allocator, cell);
                }
                if (y < self.height() - 1) {
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
    return try _Grid.init(allocator, input, .dot);
}

test "height, width" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(3, g.height());
    try std.testing.expectEqual(5, g.width());
}

test "adjacents" {
    const allocator = std.testing.allocator;
    var g = try _testGrid();
    defer g.deinit();

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

test "Point.eql" {
    const p1 = Point{ .x = 1, .y = 2 };
    const p2 = Point{ .x = 1, .y = 2 };
    const p3 = Point{ .x = 1, .y = 3 };
    const p4 = Point{ .x = 2, .y = 2 };

    try std.testing.expect(p1.eql(p2));
    try std.testing.expect(!p1.eql(p3));
    try std.testing.expect(!p1.eql(p4));
}

test "Point.lessThan" {
    const p1 = Point{ .x = 1, .y = 0 };
    const p2 = Point{ .x = 2, .y = 0 };
    const p3 = Point{ .x = 1, .y = 1 };
    const p4 = Point{ .x = 0, .y = 1 };

    try std.testing.expect(Point.lessThan({}, p1, p2));
    try std.testing.expect(Point.lessThan({}, p1, p3));
    try std.testing.expect(Point.lessThan({}, p4, p3));
    try std.testing.expect(!Point.lessThan({}, p2, p1));
    try std.testing.expect(!Point.lessThan({}, p3, p1));
}

test "Point.lineTo vertical" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 2, .y = 1 };
    const p2 = Point{ .x = 2, .y = 4 };

    var points = try p1.lineTo(allocator, p2);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), points.items.len);
    try std.testing.expectEqual(Point{ .x = 2, .y = 1 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 2 }, points.items[1]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 3 }, points.items[2]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 4 }, points.items[3]);
}

test "Point.lineTo vertical reverse" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 2, .y = 4 };
    const p2 = Point{ .x = 2, .y = 1 };

    var points = try p1.lineTo(allocator, p2);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), points.items.len);
    try std.testing.expectEqual(Point{ .x = 2, .y = 1 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 2 }, points.items[1]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 3 }, points.items[2]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 4 }, points.items[3]);
}

test "Point.lineTo horizontal" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 1, .y = 3 };
    const p2 = Point{ .x = 4, .y = 3 };

    var points = try p1.lineTo(allocator, p2);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), points.items.len);
    try std.testing.expectEqual(Point{ .x = 1, .y = 3 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 3 }, points.items[1]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 3 }, points.items[2]);
    try std.testing.expectEqual(Point{ .x = 4, .y = 3 }, points.items[3]);
}

test "Point.lineTo horizontal reverse" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 4, .y = 3 };
    const p2 = Point{ .x = 1, .y = 3 };

    var points = try p1.lineTo(allocator, p2);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 4), points.items.len);
    try std.testing.expectEqual(Point{ .x = 1, .y = 3 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 3 }, points.items[1]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 3 }, points.items[2]);
    try std.testing.expectEqual(Point{ .x = 4, .y = 3 }, points.items[3]);
}

test "Point.lineTo same point" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 2, .y = 3 };
    const p2 = Point{ .x = 2, .y = 3 };

    var points = try p1.lineTo(allocator, p2);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), points.items.len);
    try std.testing.expectEqual(Point{ .x = 2, .y = 3 }, points.items[0]);
}

test "Point.lineTo adjacent vertical" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 5, .y = 2 };
    const p2 = Point{ .x = 5, .y = 3 };

    var points = try p1.lineTo(allocator, p2);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), points.items.len);
    try std.testing.expectEqual(Point{ .x = 5, .y = 2 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 5, .y = 3 }, points.items[1]);
}

test "Point.lineTo adjacent horizontal" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 3, .y = 5 };
    const p2 = Point{ .x = 4, .y = 5 };

    var points = try p1.lineTo(allocator, p2);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), points.items.len);
    try std.testing.expectEqual(Point{ .x = 3, .y = 5 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 4, .y = 5 }, points.items[1]);
}

test "Point.lineTo not aligned" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 1, .y = 2 };
    const p2 = Point{ .x = 3, .y = 4 };

    // Diagonal line should return error
    try std.testing.expectError(error.NotAligned, p1.lineTo(allocator, p2));
}

test "Point.rectangleTo" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 1, .y = 2 };
    const p2 = Point{ .x = 3, .y = 4 };

    var points = try p1.rectangleTo(allocator, p2, false);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 9), points.items.len);
    try std.testing.expectEqual(Point{ .x = 1, .y = 2 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 2 }, points.items[1]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 2 }, points.items[2]);
    try std.testing.expectEqual(Point{ .x = 1, .y = 3 }, points.items[3]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 3 }, points.items[4]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 3 }, points.items[5]);
    try std.testing.expectEqual(Point{ .x = 1, .y = 4 }, points.items[6]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 4 }, points.items[7]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 4 }, points.items[8]);
}

test "Point.rectangleTo only_edges" {
    const allocator = std.testing.allocator;
    const p1 = Point{ .x = 1, .y = 2 };
    const p2 = Point{ .x = 3, .y = 4 };

    var points = try p1.rectangleTo(allocator, p2, true);
    defer points.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 8), points.items.len);

    // Sort points for easier checking
    std.mem.sort(Point, points.items, {}, Point.lessThan);

    try std.testing.expectEqual(Point{ .x = 1, .y = 2 }, points.items[0]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 2 }, points.items[1]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 2 }, points.items[2]);
    try std.testing.expectEqual(Point{ .x = 1, .y = 3 }, points.items[3]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 3 }, points.items[4]);
    try std.testing.expectEqual(Point{ .x = 1, .y = 4 }, points.items[5]);
    try std.testing.expectEqual(Point{ .x = 2, .y = 4 }, points.items[6]);
    try std.testing.expectEqual(Point{ .x = 3, .y = 4 }, points.items[7]);
}

test "Grid.init" {
    const allocator = std.testing.allocator;
    const input = ".*\n*.";
    var g = try _Grid.init(allocator, input, .dot);
    defer g.deinit();

    try std.testing.expectEqual(2, g.height());
    try std.testing.expectEqual(2, g.width());
    try std.testing.expectEqual(_GridItem.dot, g.at(.{ .x = 0, .y = 0 }));
    try std.testing.expectEqual(_GridItem.star, g.at(.{ .x = 1, .y = 0 }));
    try std.testing.expectEqual(_GridItem.star, g.at(.{ .x = 0, .y = 1 }));
    try std.testing.expectEqual(_GridItem.dot, g.at(.{ .x = 1, .y = 1 }));
}

test "Grid.initEmpty" {
    const allocator = std.testing.allocator;
    var g = _Grid.initEmpty(allocator, .dot);
    defer g.deinit();

    // initEmpty sets max_y=0 and max_x=0, so height/width return 1
    try std.testing.expectEqual(1, g.height());
    try std.testing.expectEqual(1, g.width());
    // But the grid is empty (no entries in map)
    try std.testing.expectEqual(_GridItem.dot, g.at(.{ .x = 0, .y = 0 }));
}

test "Grid.at" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(_GridItem.dot, g.at(.{ .x = 0, .y = 0 }));
    try std.testing.expectEqual(_GridItem.dot, g.at(.{ .x = 1, .y = 0 }));
    try std.testing.expectEqual(_GridItem.star, g.at(.{ .x = 2, .y = 1 }));
    try std.testing.expectEqual(_GridItem.dot, g.at(.{ .x = 0, .y = 2 }));
    // Test empty item for out of bounds
    try std.testing.expectEqual(_GridItem.dot, g.at(.{ .x = 10, .y = 10 }));
}

test "Grid.set" {
    const allocator = std.testing.allocator;
    var g = _Grid.initEmpty(allocator, .dot);
    defer g.deinit();

    try g.set(.{ .x = 5, .y = 3 }, .star);
    try std.testing.expectEqual(_GridItem.star, g.at(.{ .x = 5, .y = 3 }));
    try std.testing.expectEqual(6, g.width());
    try std.testing.expectEqual(4, g.height());

    try g.set(.{ .x = 0, .y = 0 }, .star);
    try std.testing.expectEqual(_GridItem.star, g.at(.{ .x = 0, .y = 0 }));
}

test "Grid.pointTop" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointTop(.{ .x = 0, .y = 0 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 1, .y = 0 }), g.pointTop(.{ .x = 1, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 2, .y = 1 }), g.pointTop(.{ .x = 2, .y = 2 }));
}

test "Grid.pointDown" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointDown(.{ .x = 0, .y = 2 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 1, .y = 2 }), g.pointDown(.{ .x = 1, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 2, .y = 1 }), g.pointDown(.{ .x = 2, .y = 0 }));
}

test "Grid.pointLeft" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointLeft(.{ .x = 0, .y = 0 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 0, .y = 1 }), g.pointLeft(.{ .x = 1, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 3, .y = 2 }), g.pointLeft(.{ .x = 4, .y = 2 }));
}

test "Grid.pointRight" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointRight(.{ .x = 4, .y = 0 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 2, .y = 1 }), g.pointRight(.{ .x = 1, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 1, .y = 2 }), g.pointRight(.{ .x = 0, .y = 2 }));
}

test "Grid.pointTopLeft" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointTopLeft(.{ .x = 0, .y = 0 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointTopLeft(.{ .x = 0, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointTopLeft(.{ .x = 1, .y = 0 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 1, .y = 0 }), g.pointTopLeft(.{ .x = 2, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 3, .y = 1 }), g.pointTopLeft(.{ .x = 4, .y = 2 }));
}

test "Grid.pointTopRight" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointTopRight(.{ .x = 4, .y = 0 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointTopRight(.{ .x = 4, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointTopRight(.{ .x = 1, .y = 0 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 3, .y = 0 }), g.pointTopRight(.{ .x = 2, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 1, .y = 1 }), g.pointTopRight(.{ .x = 0, .y = 2 }));
}

test "Grid.pointBottomLeft" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointBottomLeft(.{ .x = 0, .y = 2 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointBottomLeft(.{ .x = 0, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointBottomLeft(.{ .x = 1, .y = 2 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 1, .y = 2 }), g.pointBottomLeft(.{ .x = 2, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 3, .y = 2 }), g.pointBottomLeft(.{ .x = 4, .y = 1 }));
}

test "Grid.pointBottomRight" {
    var g = try _testGrid();
    defer g.deinit();

    try std.testing.expectEqual(@as(?Point, null), g.pointBottomRight(.{ .x = 4, .y = 2 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointBottomRight(.{ .x = 4, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, null), g.pointBottomRight(.{ .x = 1, .y = 2 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 3, .y = 2 }), g.pointBottomRight(.{ .x = 2, .y = 1 }));
    try std.testing.expectEqual(@as(?Point, Point{ .x = 1, .y = 2 }), g.pointBottomRight(.{ .x = 0, .y = 1 }));
}

test "Grid.cross" {
    const allocator = std.testing.allocator;
    var g = try _testGrid();
    defer g.deinit();

    var cross = try g.cross(allocator, .{ .x = 2, .y = 1 });
    defer cross.deinit(allocator);

    // Should have all points in column 2 and row 1, excluding the center point (2,1)
    // Column 2: (2,0), (2,2)
    // Row 1: (0,1), (1,1), (3,1), (4,1)
    try std.testing.expectEqual(@as(usize, 6), cross.items.len);

    // Sort by point for easier checking (sorts by y first, then x)
    std.mem.sort(_Grid.Entry, cross.items, {}, struct {
        fn lessThan(_: void, a: _Grid.Entry, b: _Grid.Entry) bool {
            return Point.lessThan({}, a.key, b.key);
        }
    }.lessThan);

    // After sorting: (2,0), (0,1), (1,1), (3,1), (4,1), (2,2)
    try std.testing.expectEqual(Point{ .x = 2, .y = 0 }, cross.items[0].key);
    try std.testing.expectEqual(Point{ .x = 0, .y = 1 }, cross.items[1].key);
    try std.testing.expectEqual(Point{ .x = 1, .y = 1 }, cross.items[2].key);
    try std.testing.expectEqual(Point{ .x = 3, .y = 1 }, cross.items[3].key);
    try std.testing.expectEqual(Point{ .x = 4, .y = 1 }, cross.items[4].key);
    try std.testing.expectEqual(Point{ .x = 2, .y = 2 }, cross.items[5].key);
}

test "Grid.to_str" {
    const allocator = std.testing.allocator;
    var g = try _testGrid();
    defer g.deinit();

    const str = try g.toStr(allocator, struct {
        fn toChar(item: _GridItem) u8 {
            return if (item == .dot) '.' else '*';
        }
    }.toChar);
    defer allocator.free(str);

    const expected = ".....\n..*..\n.....";
    try std.testing.expectEqualStrings(expected, str);
}

test "Grid.toAscii" {
    const allocator = std.testing.allocator;
    const CharGrid = grid(u8, struct {
        fn toItem(c: u8) u8 {
            return c;
        }
    }.toItem);
    const input = "ABC\nDEF";
    var g = try CharGrid.init(allocator, input, ' ');
    defer g.deinit();

    const str = try g.toAscii(allocator);
    defer allocator.free(str);

    try std.testing.expectEqualStrings(input, str);
}

test "Grid.iterator" {
    var g = try _testGrid();
    defer g.deinit();

    var count: usize = 0;
    var iterator = g.iterator();
    while (iterator.next()) |entry| {
        count += 1;
        // Verify that the entry exists in the grid
        try std.testing.expectEqual(entry.value_ptr.*, g.at(entry.key_ptr.*));
    }

    // The test grid has one star at (2,1), so we should have at least that entry
    // (though the grid might store more entries if set was called)
    try std.testing.expect(count >= 1);
}

test "Grid.isPointInArea" {
    const allocator = std.testing.allocator;
    const CharGrid = grid(u8, struct {
        fn toItem(c: u8) u8 {
            return c;
        }
    }.toItem);

    const input =
        \\............
        \\.......#####
        \\.......#...#
        \\..######...#
        \\..#........#
        \\..########.#
        \\.........#.#
        \\.........###
    ;

    var g = try CharGrid.init(allocator, input, '.');
    defer g.deinit();

    // Create border set with '#' as border
    var borders = hashset.Set(u8).init(allocator);
    defer borders.deinit();
    _ = try borders.add('#');

    try std.testing.expectEqual(false, try g.isPointInArea(
        .{ .x = 0, .y = 0 },
        &borders,
    ));
    try std.testing.expectEqual(false, try g.isPointInArea(
        .{ .x = 1, .y = 0 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 7, .y = 1 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 7, .y = 2 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 8, .y = 2 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 9, .y = 2 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 10, .y = 2 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 3, .y = 4 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 4, .y = 4 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 5, .y = 4 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 2, .y = 4 },
        &borders,
    ));
    try std.testing.expectEqual(false, try g.isPointInArea(
        .{ .x = 0, .y = 4 },
        &borders,
    ));
    try std.testing.expectEqual(false, try g.isPointInArea(
        .{ .x = 1, .y = 4 },
        &borders,
    ));
    try std.testing.expectEqual(false, try g.isPointInArea(
        .{ .x = 8, .y = 6 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 9, .y = 6 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 9, .y = 1 },
        &borders,
    ));
    try std.testing.expectEqual(true, try g.isPointInArea(
        .{ .x = 5, .y = 3 },
        &borders,
    ));
}
