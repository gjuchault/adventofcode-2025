const std = @import("std");
const lib = @import("lib");
const set = @import("set");

pub fn main() !void {
    std.debug.print("Day 9.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 9);
    defer {
        var iter = files.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        files.deinit();
        allocator.destroy(files);
    }

    const part1_test1 = try part1(allocator, files.get("test1.txt").?);
    std.debug.print("part1:test1: {d}\n", .{part1_test1});

    const part1_input = try part1(allocator, files.get("input.txt").?);
    std.debug.print("part1:input: {d}\n", .{part1_input});

    const part2_test1 = try part2(allocator, files.get("test1.txt").?);
    std.debug.print("part2:test1: {d}\n", .{part2_test1});

    const part2_input = try part2(allocator, files.get("input.txt").?);
    std.debug.print("part2:input: {d}\n", .{part2_input});
}

const GridItem = enum { space, red, green };
fn charToGridItem(input: u8) GridItem {
    if (input == '.') return .space;
    if (input == '#') return .red;
    std.debug.print("invalid grid item: {c}\n", .{input});
    @panic("invalid grid item");
}
fn gridItemToChar(input: GridItem) u8 {
    switch (input) {
        .red => return '#',
        .green => return 'O',
        .space => return '.',
    }
}
const Grid = lib.grid.grid(GridItem, charToGridItem);
const Pair = struct { x1: usize, x2: usize, y1: usize, y2: usize };

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var map = Grid.initEmpty(allocator, .space);
    defer map.deinit();

    var lines = std.mem.splitSequence(u8, input, "\n");
    var points_count: usize = 0;
    while (lines.next()) |line| {
        var parts = std.mem.splitSequence(u8, line, ",");
        const x = try std.fmt.parseInt(usize, parts.next().?, 10);
        const y = try std.fmt.parseInt(usize, parts.next().?, 10);
        points_count += 1;

        try map.set(.{ .x = x, .y = y }, .red);
    }

    var visited_pairs = try set.Set(Pair).initCapacity(allocator, @intCast(points_count));
    defer visited_pairs.deinit();

    var maximum_area: usize = 0;

    var it = map.iterator();
    while (it.next()) |point_and_value| {
        const point = point_and_value.key_ptr.*;
        const t = point_and_value.value_ptr.*;
        if (t == .space) continue;

        var other_it = map.iterator();
        while (other_it.next()) |other_point_and_value| {
            const other_point = other_point_and_value.key_ptr.*;
            const other_t = other_point_and_value.value_ptr.*;
            if (other_t != .red) continue;
            if (other_point.eql(point)) continue;

            const p1 = if (lib.grid.Point.lessThan({}, point, other_point)) point else other_point;
            const p2 = if (lib.grid.Point.lessThan({}, point, other_point)) other_point else point;

            const pair = Pair{ .x1 = p1.x, .y1 = p1.y, .x2 = p2.x, .y2 = p2.y };

            if (visited_pairs.contains(pair)) continue;

            _ = try visited_pairs.add(pair);
            const dx = std.math.sub(usize, p2.x, p1.x) catch 0;
            const dy = std.math.sub(usize, p2.y, p1.y) catch 0;
            const area = try std.math.mul(usize, dx + 1, dy + 1);
            if (area > maximum_area) maximum_area = area;
        }
    }

    return maximum_area;
}

const PointPair = struct {
    p1: lib.grid.Point,
    p2: lib.grid.Point,
    area: usize,
};

const MinMax = struct {
    min: usize,
    max: usize,
};

const VerticalLines = std.AutoHashMap(usize, std.ArrayList(MinMax));
const HorizontalLines = std.AutoHashMap(usize, std.ArrayList(MinMax));
const CoordSet = set.Set(usize);

fn isPointOnBoundary(x: usize, y: usize, x_coords_at_y: *const std.AutoHashMap(usize, CoordSet), y_coords_at_x: *const std.AutoHashMap(usize, CoordSet)) bool {
    if (x_coords_at_y.get(y)) |x_set| {
        if (x_set.contains(x)) return true;
    }
    if (y_coords_at_x.get(x)) |y_set| {
        if (y_set.contains(y)) return true;
    }
    return false;
}

fn hasIntersection(
    x: usize,
    y: usize,
    u: usize,
    v: usize,
    horizontal_lines: *const HorizontalLines,
    vertical_lines: *const VerticalLines,
) bool {
    const x_min = @min(x, u);
    const x_max = @max(x, u);
    const y_min = @min(y, v);
    const y_max = @max(y, v);

    // Check horizontal lines that intersect the rectangle
    var h_iter = horizontal_lines.iterator();
    while (h_iter.next()) |entry| {
        const iy = entry.key_ptr.*;
        if (iy > y_min and iy < y_max) {
            for (entry.value_ptr.*.items) |segment| {
                const ix1 = segment.min;
                const ix2 = segment.max;
                // Check if any x in the segment (excluding endpoints) is in xr
                var ix = ix1 + 1;
                while (ix < ix2) : (ix += 1) {
                    if (ix > x_min and ix < x_max) {
                        return false;
                    }
                }
            }
        }
    }

    // Check vertical lines that intersect the rectangle
    var v_iter = vertical_lines.iterator();
    while (v_iter.next()) |entry| {
        const ix = entry.key_ptr.*;
        if (ix > x_min and ix < x_max) {
            for (entry.value_ptr.*.items) |segment| {
                const iy1 = segment.min;
                const iy2 = segment.max;
                // Check if any y in the segment (excluding endpoints) is in yr
                var iy = iy1 + 1;
                while (iy < iy2) : (iy += 1) {
                    if (iy > y_min and iy < y_max) {
                        return false;
                    }
                }
            }
        }
    }

    return true;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var lines = std.mem.splitSequence(u8, input, "\n");
    var points = try std.ArrayList(lib.grid.Point).initCapacity(
        allocator,
        std.mem.count(u8, input, "\n") + 1,
    );
    defer points.deinit(allocator);

    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parts = std.mem.splitSequence(u8, line, ",");
        const x = try std.fmt.parseInt(usize, parts.next().?, 10);
        const y = try std.fmt.parseInt(usize, parts.next().?, 10);
        points.appendAssumeCapacity(.{ .x = x, .y = y });
    }

    // Build vertical and horizontal line segments from consecutive points
    var vertical_lines = VerticalLines.init(allocator);
    defer {
        var v_iter = vertical_lines.iterator();
        while (v_iter.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
        }
        vertical_lines.deinit();
    }

    var horizontal_lines = HorizontalLines.init(allocator);
    defer {
        var h_iter = horizontal_lines.iterator();
        while (h_iter.next()) |entry| {
            entry.value_ptr.*.deinit(allocator);
        }
        horizontal_lines.deinit();
    }

    for (points.items, 0..) |point, i| {
        const next_point = if (i == points.items.len - 1) points.items[0] else points.items[i + 1];

        if (point.x == next_point.x) {
            const y_min = @min(point.y, next_point.y);
            const y_max = @max(point.y, next_point.y);
            const gop = try vertical_lines.getOrPut(point.x);
            if (!gop.found_existing) {
                gop.value_ptr.* = try std.ArrayList(MinMax).initCapacity(allocator, 4);
            }
            try gop.value_ptr.*.append(allocator, .{ .min = y_min, .max = y_max });
        } else {
            const x_min = @min(point.x, next_point.x);
            const x_max = @max(point.x, next_point.x);
            const gop = try horizontal_lines.getOrPut(point.y);
            if (!gop.found_existing) {
                gop.value_ptr.* = try std.ArrayList(MinMax).initCapacity(allocator, 4);
            }
            try gop.value_ptr.*.append(allocator, .{ .min = x_min, .max = x_max });
        }
    }

    var x_coords_at_y = std.AutoHashMap(usize, CoordSet).init(allocator);
    defer {
        var iter = x_coords_at_y.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        x_coords_at_y.deinit();
    }

    var h_iter = horizontal_lines.iterator();
    while (h_iter.next()) |entry| {
        const y = entry.key_ptr.*;
        var x_set = CoordSet.init(allocator);
        for (entry.value_ptr.*.items) |segment| {
            var x = segment.min;
            while (x <= segment.max) : (x += 1) {
                _ = try x_set.add(x);
            }
        }
        try x_coords_at_y.put(y, x_set);
    }

    var y_coords_at_x = std.AutoHashMap(usize, CoordSet).init(allocator);
    defer {
        var iter = y_coords_at_x.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        y_coords_at_x.deinit();
    }

    var v_iter = vertical_lines.iterator();
    while (v_iter.next()) |entry| {
        const x = entry.key_ptr.*;
        var y_set = CoordSet.init(allocator);
        for (entry.value_ptr.*.items) |segment| {
            var y = segment.min;
            while (y <= segment.max) : (y += 1) {
                _ = try y_set.add(y);
            }
        }
        try y_coords_at_x.put(x, y_set);
    }

    var pairs = try std.ArrayList(PointPair).initCapacity(allocator, points.items.len * (points.items.len - 1) / 2);
    defer pairs.deinit(allocator);

    for (points.items, 0..) |point, i| {
        for (points.items[i + 1 ..]) |other_point| {
            const dx = if (point.x > other_point.x) point.x - other_point.x else other_point.x - point.x;
            const dy = if (point.y > other_point.y) point.y - other_point.y else other_point.y - point.y;
            const area = (dx + 1) * (dy + 1);
            pairs.appendAssumeCapacity(.{
                .p1 = point,
                .p2 = other_point,
                .area = area,
            });
        }
    }

    std.mem.sort(PointPair, pairs.items, {}, struct {
        fn lessThan(_: void, a: PointPair, b: PointPair) bool {
            return a.area > b.area;
        }
    }.lessThan);

    for (pairs.items) |pair| {
        const x = pair.p1.x;
        const y = pair.p1.y;
        const u = pair.p2.x;
        const v = pair.p2.y;

        const corner1_on_boundary = isPointOnBoundary(x, v, &x_coords_at_y, &y_coords_at_x);
        const corner2_on_boundary = isPointOnBoundary(u, y, &x_coords_at_y, &y_coords_at_x);

        if (corner1_on_boundary or corner2_on_boundary) {
            if (hasIntersection(x, y, u, v, &horizontal_lines, &vertical_lines)) {
                return pair.area;
            }
        }
    }

    return 0;
}
