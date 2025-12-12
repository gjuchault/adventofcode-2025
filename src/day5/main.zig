const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day 5.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 5);
    defer {
        var iter = files.iterator();
        while (iter.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        files.deinit();
        allocator.destroy(files);
    }

    const part1_test1 = part1(allocator, files.get("test1.txt").?);
    std.debug.print("part1:test1: {d}\n", .{part1_test1});

    const part1_input = part1(allocator, files.get("input.txt").?);
    std.debug.print("part1:input: {d}\n", .{part1_input});

    const part2_test1 = part2(allocator, files.get("test1.txt").?);
    std.debug.print("part2:test1: {d}\n", .{part2_test1});

    const part2_input = part2(allocator, files.get("input.txt").?);
    std.debug.print("part2:input: {d}\n", .{part2_input});
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) usize {
    var lines = std.mem.splitSequence(u8, input, "\n");

    var ranges = std.ArrayList(lib.range.Range).initCapacity(allocator, 2000) catch |err| lib.die(@src(), err);
    defer ranges.deinit(allocator);

    var result: usize = 0;

    while (lines.next()) |line| {
        const index_of_dash = std.mem.indexOf(u8, line, "-") orelse 0;
        if (line.len == 0) {
            continue;
        }

        if (index_of_dash == 0) {
            const ingredient = std.fmt.parseInt(usize, line, 10) catch |err| lib.die(@src(), err);
            for (ranges.items) |range| {
                if (range.from <= ingredient and range.to >= ingredient) {
                    result += 1;
                    break;
                }
            }
        } else {
            var parts = std.mem.splitSequence(u8, line, "-");
            const first_part = parts.first();
            const second_part = parts.next();
            if (second_part == null) {
                lib.die(@src(), error.CantSplitLine);
            }
            const first_ingredient = std.fmt.parseInt(usize, first_part, 10) catch |err| lib.die(@src(), err);
            const second_ingredient = std.fmt.parseInt(usize, second_part.?, 10) catch |err| lib.die(@src(), err);

            ranges.appendAssumeCapacity(.{ .from = first_ingredient, .to = second_ingredient });
        }
    }

    return result;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) usize {
    var lines = std.mem.splitSequence(u8, input, "\n");

    var ranges = std.ArrayList(lib.range.Range).initCapacity(allocator, 2000) catch |err| lib.die(@src(), err);
    defer ranges.deinit(allocator);

    var result: usize = 0;

    while (lines.next()) |line| {
        const index_of_dash = std.mem.indexOf(u8, line, "-") orelse 0;
        if (line.len == 0) {
            continue;
        }

        if (index_of_dash == 0) {
            continue;
        } else {
            var parts = std.mem.splitSequence(u8, line, "-");
            const first_part = parts.first();
            const second_part = parts.next();
            if (second_part == null) {
                lib.die(@src(), error.CantSplitLine);
            }
            const first_ingredient = std.fmt.parseInt(usize, first_part, 10) catch |err| lib.die(@src(), err);
            const second_ingredient = std.fmt.parseInt(usize, second_part.?, 10) catch |err| lib.die(@src(), err);

            ranges.appendAssumeCapacity(.{ .from = first_ingredient, .to = second_ingredient });
        }
    }

    // we can't really loop on each number, we got to keep ranges
    // but we need to merge ranges so we _never_ have ranges overlapping each other
    // this MultiRange lib will do exactly this
    var merged_ranges = lib.range.MultiRange.initCapacity(allocator, ranges.items.len) catch |err| lib.die(@src(), err);
    defer merged_ranges.deinit();

    for (ranges.items) |range| {
        merged_ranges.merge(range) catch |err| lib.die(@src(), err);
    }

    for (merged_ranges.ranges.items) |range| {
        const to: usize = @intCast(range.to);
        const from: usize = @intCast(range.from);
        result += to - from + 1;
    }

    return result;
}
