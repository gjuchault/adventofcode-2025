const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day 6.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 6);
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

    // const part2_test1 = part2(allocator, files.get("test1.txt").?);
    // std.debug.print("part2:test1: {d}\n", .{part2_test1});

    // const part2_input = part2(allocator, files.get("input.txt").?);
    // std.debug.print("part2:input: {d}\n", .{part2_input});
}

fn noopInputToGridItem(_: u8) usize { return 0; }

const Operation = enum { add, mul };

pub fn part1(allocator: std.mem.Allocator, input: []const u8) usize {
    var lines = std.mem.splitSequence(u8, input, "\n");
    const total = std.mem.count(u8, input, "\n");

    var ranges = std.ArrayList(lib.range.Range).initCapacity(allocator, 2000) catch |err| lib.die(@src(), err);
    defer ranges.deinit(allocator);

    var result: usize = 0;

    var grid = lib.grid.grid(usize, noopInputToGridItem).initEmpty(allocator, 1000, 5, 0) catch |err| lib.die(@src(), err);
    defer grid.deinit(allocator);

    var operations = std.ArrayList(Operation).initCapacity(allocator, 1000) catch |err| lib.die(@src(), err);
    defer operations.deinit(allocator);

    var line_index: usize = 0;
    while (lines.next()) |line| {
        result += 0;

        if (line_index == total) {
            var operations_str = lib.string.splitBySpaces(allocator, line) catch |err| lib.die(@src(), err);
            defer operations_str.deinit(allocator);

            for (operations_str.items) |operation_str| {
                if (std.mem.eql(u8, operation_str, "*")) {
                    operations.appendAssumeCapacity(.mul);
                } else {
                    operations.appendAssumeCapacity(.add);
                }
            }
        } else {
            var nums = lib.string.splitBySpaces(allocator, line) catch |err| lib.die(@src(), err);
            defer nums.deinit(allocator);

            for (nums.items, 0..) |num_str, x| {
                const num = std.fmt.parseInt(usize, num_str, 10) catch |err| lib.die(@src(), err);

                grid.set(x, line_index, num);
            }
        }

        line_index += 1;
    }

    for (0..grid.width()) |x| {
        var column_result: usize = 0;
        for (0..grid.height()) |y| {
            const point = grid.at(x, y);
            if (point == 0) {
                continue;
            }

            const operation = operations.items[x];

            if (column_result == 0) {
                column_result = point;
            } else {
                if (operation == .add) {
                    column_result += point;
                } else {
                    column_result *= point;
                }
            }
        }

        result += column_result;
    }

    return result;
}

pub fn part2(_: std.mem.Allocator, _: []const u8) usize {
    var result: usize = 0;
    result += 0;

    return result;
}
