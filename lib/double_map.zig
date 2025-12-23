const std = @import("std");

pub fn DoubleMap(comptime K: type, comptime V: type) type {
    const HashMap = std.AutoHashMap(K, std.AutoHashMap(K, V));

    return struct {
        const Self = @This();
        pub const Entry = struct { k1: K, k2: K, v: V };

        s: HashMap,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .s = .init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            var it = self.s.valueIterator();
            while (it.next()) |v| {
                v.deinit();
            }

            self.s.deinit();
        }

        pub fn all_entries(self: *const Self) !std.ArrayList(Entry) {
            var entries = try std.ArrayList(Entry).initCapacity(self.allocator, self.s.capacity());

            var first_level_iterator = self.s.iterator();
            while (first_level_iterator.next()) |s1| {
                var second_level_iterator = s1.value_ptr.iterator();
                while (second_level_iterator.next()) |s2| {
                    try entries.append(self.allocator, .{
                        .k1 = s1.key_ptr.*,
                        .k2 = s2.key_ptr.*,
                        .v = s2.value_ptr.*,
                    });
                }
            }

            return entries;
        }

        pub fn put(self: *Self, k1: K, k2: K, v: V) !void {
            const gop = try self.s.getOrPut(k1);
            if (!gop.found_existing) {
                gop.value_ptr.* = std.AutoHashMap(K, V).init(self.allocator);
            }
            try gop.value_ptr.put(k2, v);
        }

        pub fn contains(self: *Self, k1: K, k2: K) bool {
            if (!self.s.contains(k1)) {
                if (!self.s.contains(k2)) {
                    return false;
                }

                const submap = self.s.get(k2).?;
                return submap.contains(k1);
            }

            const submap = self.s.get(k1).?;
            return submap.contains(k2);
        }

        pub fn get(self: *Self, k1: K, k2: K) ?V {
            if (!self.s.contains(k1)) {
                if (!self.s.contains(k2)) {
                    return null;
                }

                const submap = self.s.get(k2).?;
                return submap.get(k1);
            }

            const submap = self.s.get(k1).?;
            return submap.get(k2);
        }

        pub fn mustGet(self: *Self, k1: K, k2: K) !V {
            if (!self.s.contains(k1)) {
                if (!self.s.contains(k2)) {
                    return error.NotFound;
                }

                const submap = self.s.get(k2).?;
                if (!submap.contains(k1)) {
                    return error.NotFound;
                }

                return submap.get(k1).?;
            }

            const submap = self.s.get(k1).?;
            if (!submap.contains(k2)) {
                return error.NotFound;
            }

            return submap.get(k2).?;
        }
    };
}

test "DoubleMap: basic put and get" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = DoubleMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.put(1, 10, 100);
    try map.put(1, 20, 200);
    try map.put(2, 30, 300);

    try std.testing.expectEqual(@as(?u32, 100), map.get(1, 10));
    try std.testing.expectEqual(@as(?u32, 200), map.get(1, 20));
    try std.testing.expectEqual(@as(?u32, 300), map.get(2, 30));
    try std.testing.expectEqual(@as(?u32, null), map.get(1, 30));
    try std.testing.expectEqual(@as(?u32, null), map.get(3, 10));

    try std.testing.expectEqual(@as(?u32, 100), map.get(10, 1));
    try std.testing.expectEqual(@as(?u32, 200), map.get(20, 1));
    try std.testing.expectEqual(@as(?u32, 300), map.get(30, 2));
    try std.testing.expectEqual(@as(?u32, null), map.get(30, 1));
    try std.testing.expectEqual(@as(?u32, null), map.get(10, 3));
}

test "DoubleMap: contains" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = DoubleMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.put(1, 10, 100);
    try map.put(1, 20, 200);
    try map.put(2, 30, 300);

    try std.testing.expect(map.contains(1, 10));
    try std.testing.expect(map.contains(1, 20));
    try std.testing.expect(map.contains(2, 30));
    try std.testing.expect(map.contains(10, 1));
    try std.testing.expect(map.contains(20, 1));
    try std.testing.expect(map.contains(30, 2));

    try std.testing.expect(!map.contains(1, 30));
    try std.testing.expect(!map.contains(3, 10));
    try std.testing.expect(!map.contains(2, 10));
    try std.testing.expect(!map.contains(30, 1));
    try std.testing.expect(!map.contains(10, 3));
    try std.testing.expect(!map.contains(10, 2));
}

test "DoubleMap: mustGet success" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = DoubleMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.put(1, 10, 100);
    try map.put(2, 20, 200);

    try std.testing.expectEqual(@as(u32, 100), try map.mustGet(1, 10));
    try std.testing.expectEqual(@as(u32, 100), try map.mustGet(10, 1));
    try std.testing.expectEqual(@as(u32, 200), try map.mustGet(2, 20));
    try std.testing.expectEqual(@as(u32, 200), try map.mustGet(20, 2));
}

test "DoubleMap: mustGet NotFound for missing k1" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = DoubleMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.put(1, 10, 100);

    try std.testing.expectError(error.NotFound, map.mustGet(2, 10));
    try std.testing.expectError(error.NotFound, map.mustGet(10, 2));
}

test "DoubleMap: mustGet NotFound for missing k2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = DoubleMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.put(1, 10, 100);

    try std.testing.expectError(error.NotFound, map.mustGet(1, 20));
    try std.testing.expectError(error.NotFound, map.mustGet(20, 1));
}

test "DoubleMap: overwrite value" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = DoubleMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.put(1, 10, 100);
    try std.testing.expectEqual(@as(?u32, 100), map.get(1, 10));
    try std.testing.expectEqual(@as(?u32, 100), map.get(10, 1));

    try map.put(1, 10, 999);
    try std.testing.expectEqual(@as(?u32, 999), map.get(1, 10));
    try std.testing.expectEqual(@as(?u32, 999), map.get(10, 1));
}

test "DoubleMap: multiple k1 with same k2" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = DoubleMap(u32, u32).init(allocator);
    defer map.deinit();

    try map.put(1, 10, 100);
    try map.put(2, 10, 200);
    try map.put(3, 10, 300);

    try std.testing.expectEqual(@as(?u32, 100), map.get(1, 10));
    try std.testing.expectEqual(@as(?u32, 200), map.get(2, 10));
    try std.testing.expectEqual(@as(?u32, 300), map.get(3, 10));
    try std.testing.expectEqual(@as(?u32, 100), map.get(10, 1));
    try std.testing.expectEqual(@as(?u32, 200), map.get(10, 2));
    try std.testing.expectEqual(@as(?u32, 300), map.get(10, 3));
}
