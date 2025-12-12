const std = @import("std");

pub const Range = struct {
    from: usize,
    to: usize,

    pub fn compare(_: void, a: Range, b: Range) std.math.Order {
        if (a.from == b.from and a.to == b.to) {
            return .eq;
        }

        if (a.from < b.from) {
            return .lt;
        } else if (a.from > b.from) {
            return .gt;
        }

        if (a.to < b.to) {
            return .lt;
        }

        return .gt;
    }

    pub fn xorRange(self: *const Range, allocator: std.mem.Allocator, cmp: Range) !std.ArrayList(Range) {
        var result = try std.ArrayList(Range).initCapacity(allocator, 2);

        // No overlap - ranges are identical
        if (self.from == cmp.from and self.to == cmp.to) {
            return result;
        }

        // No overlap - self is completely after cmp
        if (self.from > cmp.to) {
            result.appendAssumeCapacity(self.*);
            return result;
        }

        // No overlap - self is completely before cmp
        if (self.to < cmp.from) {
            result.appendAssumeCapacity(self.*);
            return result;
        }

        // cmp is completely inside self - split into two ranges
        if (self.from < cmp.from and self.to > cmp.to) {
            result.appendAssumeCapacity(Range{ .from = self.from, .to = cmp.from - 1 });
            result.appendAssumeCapacity(Range{ .from = cmp.to + 1, .to = self.to });
            return result;
        }

        // self is completely inside cmp - return nothing
        if (self.from >= cmp.from and self.to <= cmp.to) {
            return result;
        }

        // Partial overlap - self starts after cmp starts
        if (self.from >= cmp.from and self.to > cmp.to) {
            result.appendAssumeCapacity(Range{ .from = cmp.to + 1, .to = self.to });
            return result;
        }

        // Partial overlap - self ends before cmp ends
        result.appendAssumeCapacity(Range{ .from = self.from, .to = cmp.from - 1 });
        return result;
    }
};

test "compare" {
    const a = Range{ .from = 1, .to = 10 };
    const b = Range{ .from = 5, .to = 15 };
    const c = Range{ .from = 10, .to = 20 };
    const full = Range{ .from = 1, .to = 20 };

    try std.testing.expectEqual(.eq, Range.compare({}, a, a));

    try std.testing.expectEqual(.lt, Range.compare({}, a, b));
    try std.testing.expectEqual(.gt, Range.compare({}, b, a));

    try std.testing.expectEqual(.lt, Range.compare({}, a, c));
    try std.testing.expectEqual(.gt, Range.compare({}, c, a));

    try std.testing.expectEqual(.lt, Range.compare({}, a, full));
    try std.testing.expectEqual(.gt, Range.compare({}, full, a));

    try std.testing.expectEqual(.gt, Range.compare({}, b, full));
    try std.testing.expectEqual(.lt, Range.compare({}, full, b));
}

test "xorRange" {
    const allocator = std.testing.allocator;

    const a = Range{ .from = 1, .to = 10 };
    const b = Range{ .from = 5, .to = 15 };
    const c = Range{ .from = 10, .to = 20 };
    const d = Range{ .from = 15, .to = 25 };
    const full = Range{ .from = 1, .to = 20 };

    var axa = try a.xorRange(allocator, a);
    defer axa.deinit(allocator);
    try std.testing.expectEqual(0, axa.items.len);

    var axb = try a.xorRange(allocator, b);
    defer axb.deinit(allocator);
    try std.testing.expectEqual(1, axb.items.len);
    try std.testing.expectEqual(1, axb.items[0].from);
    try std.testing.expectEqual(4, axb.items[0].to);

    var axc = try a.xorRange(allocator, c);
    defer axc.deinit(allocator);
    try std.testing.expectEqual(1, axc.items.len);
    try std.testing.expectEqual(1, axc.items[0].from);
    try std.testing.expectEqual(9, axc.items[0].to);

    var axd = try a.xorRange(allocator, d);
    defer axd.deinit(allocator);
    try std.testing.expectEqual(1, axd.items.len);
    try std.testing.expectEqual(1, axd.items[0].from);
    try std.testing.expectEqual(10, axd.items[0].to);

    var bxa = try b.xorRange(allocator, a);
    defer bxa.deinit(allocator);
    try std.testing.expectEqual(1, bxa.items.len);
    try std.testing.expectEqual(11, bxa.items[0].from);
    try std.testing.expectEqual(15, bxa.items[0].to);

    var bxb = try b.xorRange(allocator, b);
    defer bxb.deinit(allocator);
    try std.testing.expectEqual(0, bxb.items.len);

    var bxc = try b.xorRange(allocator, c);
    defer bxc.deinit(allocator);
    try std.testing.expectEqual(1, bxc.items.len);
    try std.testing.expectEqual(5, bxc.items[0].from);
    try std.testing.expectEqual(9, bxc.items[0].to);

    var bxd = try b.xorRange(allocator, d);
    defer bxd.deinit(allocator);
    try std.testing.expectEqual(1, bxd.items.len);
    try std.testing.expectEqual(5, bxd.items[0].from);
    try std.testing.expectEqual(14, bxd.items[0].to);

    var fullxb = try full.xorRange(allocator, b);
    defer fullxb.deinit(allocator);
    try std.testing.expectEqual(2, fullxb.items.len);
    try std.testing.expectEqual(1, fullxb.items[0].from);
    try std.testing.expectEqual(4, fullxb.items[0].to);
    try std.testing.expectEqual(16, fullxb.items[1].from);
    try std.testing.expectEqual(20, fullxb.items[1].to);

    var bxfull = try b.xorRange(allocator, full);
    defer bxfull.deinit(allocator);
    try std.testing.expectEqual(0, bxfull.items.len);
}

// This is a holder to a merge function that stores every range in a PriorityQueue
// and, when asked to merge a range, will make sure to split it so it never overlaps one already in
pub const MultiRange = struct {
    ranges: std.ArrayList(Range),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MultiRange {
        return .{ .ranges = std.ArrayList(Range).init(allocator), .allocator = allocator };
    }

    pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) !MultiRange {
        const ranges = try std.ArrayList(Range).initCapacity(allocator, capacity);
        return .{ .ranges = ranges, .allocator = allocator };
    }

    pub fn deinit(self: *MultiRange) void {
        self.ranges.deinit(self.allocator);
    }

    fn lessThan(_: void, a: Range, b: Range) bool {
        return Range.compare({}, a, b) == .lt;
    }

    pub fn merge(self: *MultiRange, new_range: Range) !void {
        // 1. identify first range that we'll be crossing (aka new_range.to >= range.from)
        var merge_with: ?Range = null;
        var merge_with_index: ?usize = null;
        for (self.ranges.items, 0..) |cmp, i| {
            if (new_range.to >= cmp.from and new_range.from <= cmp.to) {
                merge_with = cmp;
                merge_with_index = i;
                break;
            }
        }

        // 2. no overlap -> just append
        if (merge_with == null) {
            try self.ranges.append(self.allocator, new_range);
            std.mem.sort(Range, self.ranges.items, {}, lessThan);
            return;
        }

        // 3. overlap -> keep merge_with, only merge the exclusive parts of new_range
        var exclusive_ranges = try new_range.xorRange(self.allocator, merge_with.?);
        defer exclusive_ranges.deinit(self.allocator);

        // Merge the exclusive parts (parts of new_range that don't overlap with merge_with)
        // if they still overlap, recursion will take care of it
        // if they end up empty, recursion will ignore it
        for (exclusive_ranges.items) |exclusive_range| {
            try self.merge(exclusive_range);
        }

        std.mem.sort(Range, self.ranges.items, {}, lessThan);
    }
};

test "merge" {
    const allocator = std.testing.allocator;
    var mr = try MultiRange.initCapacity(allocator, 10);
    defer mr.deinit();

    const a = Range{ .from = 1, .to = 10 };
    const b = Range{ .from = 5, .to = 15 };
    const c = Range{ .from = 10, .to = 20 };

    try mr.merge(c);
    try std.testing.expectEqualSlices(Range, &[_]Range{c}, mr.ranges.items);

    try mr.merge(a);
    try std.testing.expectEqualSlices(Range, &[_]Range{ .{ .from = 1, .to = 9 }, c }, mr.ranges.items);

    try mr.merge(b);
    try std.testing.expectEqualSlices(Range, &[_]Range{ .{ .from = 1, .to = 9 }, c }, mr.ranges.items);

    var mr2 = try MultiRange.initCapacity(allocator, 10);
    defer mr2.deinit();

    try mr2.merge(.{ .from = 3, .to = 5 });
    try mr2.merge(.{ .from = 10, .to = 14 });
}
