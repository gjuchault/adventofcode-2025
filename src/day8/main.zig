const std = @import("std");
const lib = @import("lib");
const set = @import("set");

pub fn main() !void {
    std.debug.print("Day 8.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 8);
    defer {
        var iter = files.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        files.deinit();
        allocator.destroy(files);
    }

    const part1_test1 = try part1(allocator, files.get("test1.txt").?, 10);
    std.debug.print("part1:test1: {d}\n", .{part1_test1});

    const part1_input = try part1(allocator, files.get("input.txt").?, 1000);
    std.debug.print("part1:input: {d}\n", .{part1_input});

    const part2_test1 = try part2(allocator, files.get("test1.txt").?);
    std.debug.print("part2:test1: {d}\n", .{part2_test1});

    const part2_input = try part2(allocator, files.get("input.txt").?);
    std.debug.print("part2:input: {d}\n", .{part2_input});
}

const Point = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn hash(self: Point) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, self.x);
        std.hash.autoHash(&hasher, self.y);
        std.hash.autoHash(&hasher, self.z);
        return hasher.final();
    }

    pub fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn lt(self: *const Point, other: Point) bool {
        if (self.x < other.x) return true;
        if (self.y < other.y) return true;
        if (self.z < other.z) return true;
        return false;
    }

    pub fn distanceTo(self: *const Point, other: *const Point) u64 {
        const dx = @as(i64, other.x - self.x);
        const dy = @as(i64, other.y - self.y);
        const dz = @as(i64, other.z - self.z);
        return @intCast(dx * dx + dy * dy + dz * dz);
    }
};

const Distances = lib.double_map.DoubleMap(Point, u64);
const DistanceEntry = Distances.Entry;
const Circuit = set.Set(usize);
const CircuitSet = set.Set(*Circuit);
const CircuitMap = std.AutoHashMap(usize, *Circuit);

const Junction = struct {
    distance: u64,
    a_idx: usize,
    b_idx: usize,

    fn lessThan(_: void, a: Junction, b: Junction) bool {
        return a.distance < b.distance;
    }
};

fn cmpDistanceEntry(_: void, a: DistanceEntry, b: DistanceEntry) bool {
    return a.v < b.v;
}

pub fn part1(base_allocator: std.mem.Allocator, input: []const u8, max: usize) !usize {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var lines = std.mem.splitSequence(u8, input, "\n");
    const total = std.mem.count(u8, input, "\n");
    var points = try std.ArrayList(Point).initCapacity(allocator, total * 3);
    var distances = Distances.init(allocator);
    while (lines.next()) |line| {
        var nums_as_str = std.mem.splitSequence(u8, line, ",");

        var i: usize = 0;
        var point = Point{ .x = 0, .y = 0, .z = 0 };
        while (nums_as_str.next()) |num_as_str| {
            if (i == 0) point.x = try std.fmt.parseInt(i32, num_as_str, 10);
            if (i == 1) point.y = try std.fmt.parseInt(i32, num_as_str, 10);
            if (i == 2) point.z = try std.fmt.parseInt(i32, num_as_str, 10);
            i += 1;
        }

        points.appendAssumeCapacity(point);
    }

    for (points.items, 0..) |point, i| {
        var j = i;
        // do not compare B to A if A to B has been done, DoubleMap will handle this
        while (j < points.items.len - 1) {
            j += 1;
            const point_b = points.items[j];
            try distances.put(point, point_b, point.distanceTo(&point_b));
        }
    }

    var junctions = try std.ArrayList(Junction).initCapacity(
        allocator,
        @divFloor(points.items.len * (points.items.len - 1), 2),
    );

    for (points.items, 0..) |point_a, i| {
        for (points.items[i + 1 ..], i + 1..) |point_b, j| {
            try junctions.append(allocator, .{
                .distance = point_a.distanceTo(&point_b),
                .a_idx = i,
                .b_idx = j,
            });
        }
    }

    std.mem.sort(Junction, junctions.items, {}, Junction.lessThan);

    var circuit_map: CircuitMap = .init(allocator);
    var circuit_set: CircuitSet = .init(allocator);

    for (points.items, 0..) |_, i| {
        const circuit = try allocator.create(Circuit);
        circuit.* = Circuit.init(allocator);
        _ = try circuit.*.add(i);
        _ = try circuit_set.add(circuit);
        try circuit_map.put(i, circuit);
    }

    var pairs_index: usize = 0;
    var connections_processed: usize = 0;
    while (connections_processed < max and pairs_index < junctions.items.len) {
        const pair = junctions.items[pairs_index];
        pairs_index += 1;

        const ca = circuit_map.get(pair.a_idx).?;
        const cb = circuit_map.get(pair.b_idx).?;

        if (ca == cb) {
            // points already in same circuit, skip but count as processed
            connections_processed += 1;
            continue;
        }

        // merge circuits: create new circuit with all points from both
        const new_circuit = try allocator.create(Circuit);
        new_circuit.* = Circuit.init(allocator);

        var ca_iter = ca.*.iterator();
        while (ca_iter.next()) |idx| {
            _ = try new_circuit.*.add(idx.*);
        }

        var cb_iter = cb.*.iterator();
        while (cb_iter.next()) |idx| {
            _ = try new_circuit.*.add(idx.*);
        }

        // update circuit_map for all points in the new circuit
        var new_circuit_iter = new_circuit.*.iterator();
        while (new_circuit_iter.next()) |idx| {
            try circuit_map.put(idx.*, new_circuit);
        }

        // remove old circuits from circuit_set
        _ = circuit_set.remove(ca);
        _ = circuit_set.remove(cb);

        // add new circuit to circuit_set
        _ = try circuit_set.add(new_circuit);

        connections_processed += 1;
    }

    var sizes = try std.ArrayList(usize).initCapacity(allocator, circuit_set.cardinality());

    var set_iter = circuit_set.iterator();
    while (set_iter.next()) |circuit_ptr_ptr| {
        try sizes.append(allocator, circuit_ptr_ptr.*.*.cardinality());
    }

    std.mem.sort(usize, sizes.items, {}, struct {
        fn desc(_: void, a: usize, b: usize) bool {
            return a > b;
        }
    }.desc);

    if (sizes.items.len < 3) {
        return error.NotEnoughCircuits;
    }

    return sizes.items[0] * sizes.items[1] * sizes.items[2];
}

const PointSet = set.Set(Point);
pub fn part2(base_allocator: std.mem.Allocator, input: []const u8) !usize {
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lines = std.mem.splitSequence(u8, input, "\n");
    const total = std.mem.count(u8, input, "\n");
    var points = try std.ArrayList(Point).initCapacity(allocator, total * 3);
    var distances = Distances.init(allocator);
    while (lines.next()) |line| {
        var nums_as_str = std.mem.splitSequence(u8, line, ",");

        var i: usize = 0;
        var point = Point{ .x = 0, .y = 0, .z = 0 };
        while (nums_as_str.next()) |num_as_str| {
            if (i == 0) point.x = try std.fmt.parseInt(i32, num_as_str, 10);
            if (i == 1) point.y = try std.fmt.parseInt(i32, num_as_str, 10);
            if (i == 2) point.z = try std.fmt.parseInt(i32, num_as_str, 10);
            i += 1;
        }

        points.appendAssumeCapacity(point);
    }

    for (points.items, 0..) |point, i| {
        var j = i;
        // do not compare B to A if A to B has been done, DoubleMap will handle this
        while (j < points.items.len - 1) {
            j += 1;
            const point_b = points.items[j];
            try distances.put(point, point_b, point.distanceTo(&point_b));
        }
    }

    // prim's algorithm
    var cheapest_cost = std.AutoHashMap(Point, u64).init(allocator);
    try cheapest_cost.ensureTotalCapacity(@intCast(points.items.len));
    var cheapest_edge = std.AutoHashMap(Point, Point).init(allocator);
    try cheapest_edge.ensureTotalCapacity(@intCast(points.items.len));

    for (points.items) |point| {
        cheapest_cost.putAssumeCapacity(point, std.math.maxInt(u64));
    }

    var explored = PointSet.init(allocator);
    var unexplored = PointSet.init(allocator);
    for (points.items) |point| {
        _ = try unexplored.add(point);
    }

    const start_vertex = points.items[0];
    cheapest_cost.putAssumeCapacity(start_vertex, 0);

    while (unexplored.cardinality() > 0) {
        var min_vertex: ?Point = null;
        var min_cost: u64 = std.math.maxInt(u64);

        var unexplored_iter = unexplored.iterator();
        while (unexplored_iter.next()) |point_ptr| {
            const point = point_ptr.*;
            const cost = cheapest_cost.get(point).?;
            if (cost < min_cost) {
                min_cost = cost;
                min_vertex = point;
            }
        }

        const current_vertex = min_vertex.?;
        _ = unexplored.remove(current_vertex);
        _ = try explored.add(current_vertex);

        const all_distances = try distances.all_entries();
        for (all_distances.items) |entry| {
            if (!entry.k1.eql(current_vertex) and !entry.k2.eql(current_vertex)) continue;

            const neighbor = if (entry.k1.eql(current_vertex)) entry.k2 else entry.k1;

            if (explored.contains(neighbor)) continue;

            const current_cost = cheapest_cost.get(neighbor).?;
            if (entry.v < current_cost) {
                cheapest_cost.putAssumeCapacity(neighbor, entry.v);
                cheapest_edge.putAssumeCapacity(neighbor, current_vertex);
            }
        }
    }

    var max_edge_weight: u64 = 0;
    var max_edge_points: ?struct { Point, Point } = null;

    for (points.items) |point| {
        if (cheapest_edge.get(point)) |parent| {
            const weight = if (distances.contains(point, parent))
                distances.get(point, parent).?
            else if (distances.contains(parent, point))
                distances.get(parent, point).?
            else
                point.distanceTo(&parent);

            if (weight > max_edge_weight) {
                max_edge_weight = weight;
                max_edge_points = .{ point, parent };
            }
        }
    }

    return @intCast(max_edge_points.?.@"0".x * max_edge_points.?.@"1".x);
}
