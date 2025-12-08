const std = @import("std");

pub const number = @import("./number.zig");
pub const string = @import("./string.zig");

pub fn die(loc: std.builtin.SourceLocation, err: anyerror) noreturn {
    std.debug.panic("panic at {s}:{d}@{s}: {s}", .{ loc.file, loc.line, loc.fn_name, @errorName(err) });
}

pub fn readAllTexts(allocator: std.mem.Allocator, day: usize) *std.StringHashMap([]const u8) {
    const day_path = std.fmt.allocPrint(allocator, "src/day{d}", .{day}) catch |err| die(@src(), err);
    defer allocator.free(day_path);

    var day_dir = std.fs.cwd().openDir(day_path, .{ .iterate = true }) catch |err| die(@src(), err);
    var day_dir_iterator = day_dir.iterate();

    var map = allocator.create(std.StringHashMap([]const u8)) catch |err| die(@src(), err);
    map.* = std.StringHashMap([]const u8).init(allocator);
    map.ensureTotalCapacity(10) catch |err| die(@src(), err);

    while (day_dir_iterator.next() catch |err| die(@src(), err)) |dir_content| {
        if (dir_content.kind != .file) {
            continue;
        }

        if (!std.mem.endsWith(u8, dir_content.name, ".txt")) {
            continue;
        }

        const file_contents = day_dir.readFileAlloc(allocator, dir_content.name, 4096 * 1024) catch |err| die(@src(), err);

        map.put(allocator.dupe(u8, dir_content.name) catch |err| die(@src(), err), file_contents) catch |err| die(@src(), err);
    }

    return map;
}

test "lib" {
    std.testing.refAllDecls(@import("./number.zig"));
    std.testing.refAllDecls(@import("./string.zig"));
}
