const std = @import("std");

pub fn removeFirstElements(comptime T: type, list: *std.ArrayList(T), count: usize) void {
    if (count >= list.items.len) {
        list.clearRetainingCapacity();
        return;
    }
    const remaining_count = list.items.len - count;
    @memmove(list.items[0..remaining_count], list.items[count..]);
    list.shrinkRetainingCapacity(remaining_count);
}

test "removeFirstElements" {
    const allocator = std.testing.allocator;

    var list = try std.ArrayList(u8).initCapacity(allocator, 10);
    defer list.deinit(allocator);

    list.appendSliceAssumeCapacity(&[_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });

    removeFirstElements(u8, &list, 3);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 4, 5, 6, 7, 8, 9, 10 }, list.items);
}
