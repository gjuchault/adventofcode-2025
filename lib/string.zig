const std = @import("std");

pub fn splitEvenly(allocator: std.mem.Allocator, input: []const u8, size: usize) !std.ArrayList([]const u8) {
    var result = std.ArrayList([]const u8).empty;
    result.ensureTotalCapacity(allocator, 10) catch |err| return err;

    var cursor: usize = 0;
    while (cursor < input.len) {
        try result.append(allocator, input[cursor..@min(input.len, cursor + size)]);
        cursor += size;
    }

    return result;
}

pub fn fromNumber(comptime T: type, allocator: std.mem.Allocator, input: T) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{d}", .{input});
}

pub fn isTypeStr(comptime T: type) bool {
    const type_info = @typeInfo(T);
    if (type_info == .pointer) {
        const ptr_info = type_info.pointer;
        if (ptr_info.size == .slice and ptr_info.child == u8) {
            return true;
        }
    }

    return false;
}

test "splitEvenly" {
    const allocator = std.testing.allocator;

    var test1 = try splitEvenly(allocator, "abcde", 2);
    defer test1.deinit(allocator);

    const expected = [_][]const u8{ "ab", "cd", "e" };
    try std.testing.expectEqual(expected.len, test1.items.len);
    for (expected, test1.items) |exp, actual| {
        try std.testing.expectEqualStrings(exp, actual);
    }
}

test "fromNumber" {
    const allocator = std.testing.allocator;

    const test1 = try fromNumber(usize, allocator, 123);
    defer allocator.free(test1);

    try std.testing.expectEqualStrings("123", test1);
}
