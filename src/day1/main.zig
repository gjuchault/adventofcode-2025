const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day {d}.\n", .{lib.add(1, 2)});
}
