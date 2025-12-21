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

    const part1_test1 = try part1(allocator, files.get("test1.txt").?);
    std.debug.print("part1:test1: {d}\n", .{part1_test1});

    const part1_input = try part1(allocator, files.get("input.txt").?);
    std.debug.print("part1:input: {d}\n", .{part1_input});

    const part2_test1 = try part2(allocator, files.get("test1.txt").?);
    std.debug.print("part2:test1: {d}\n", .{part2_test1});

    const part2_input = try part2(allocator, files.get("input.txt").?);
    std.debug.print("part2:input: {d}\n", .{part2_input});
}

const Operation = enum { add, mul };

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var lines = std.mem.splitSequence(u8, input, "\n");
    const total = std.mem.count(u8, input, "\n");

    var ranges = try std.ArrayList(lib.range.Range).initCapacity(allocator, 2000);
    defer ranges.deinit(allocator);

    var result: usize = 0;

    var grid = try lib.grid.grid(usize, lib.grid.noop(usize, 0)).initEmpty(allocator, 1000, 5, 0);
    defer grid.deinit(allocator);

    var operations = try std.ArrayList(Operation).initCapacity(allocator, 1000);
    defer operations.deinit(allocator);

    var line_index: usize = 0;
    while (lines.next()) |line| {
        result += 0;

        if (line_index == total) {
            var operations_str = try lib.string.splitBySpaces(allocator, line);
            defer operations_str.deinit(allocator);

            for (operations_str.items) |operation_str| {
                if (std.mem.eql(u8, operation_str, "*")) {
                    operations.appendAssumeCapacity(.mul);
                } else {
                    operations.appendAssumeCapacity(.add);
                }
            }
        } else {
            var nums = try lib.string.splitBySpaces(allocator, line);
            defer nums.deinit(allocator);

            for (nums.items, 0..) |num_str, x| {
                if (x >= grid.width() or line_index >= grid.height()) continue;
                const num = try std.fmt.parseInt(usize, num_str, 10);

                grid.set(x, line_index, num);
            }
        }

        line_index += 1;
    }

    for (0..grid.width()) |x| {
        if (x >= operations.items.len) continue;
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

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var ranges = try std.ArrayList(lib.range.Range).initCapacity(allocator, 2000);
    defer ranges.deinit(allocator);

    var result: usize = 0;
    result += 0;

    var lines = std.mem.splitSequence(u8, input, "\n");
    var lines_backwards = std.mem.splitBackwardsSequence(u8, input, "\n");

    // step 1: identify column with based on last line characters
    var columns_width = try std.ArrayList(u8).initCapacity(allocator, 1000);
    defer columns_width.deinit(allocator);

    var operations = try std.ArrayList(Operation).initCapacity(allocator, 1000);
    defer operations.deinit(allocator);

    const last_line = lines_backwards.first();
    var current_column_width: u8 = 0;
    for (last_line, 0..) |char, index| {
        if (char == '*' or char == '+') {
            operations.appendAssumeCapacity(if (char == '*') .mul else .add);

            // column width = op width + spaces width - 1 = spaces
            if (index > 0) {
                columns_width.appendAssumeCapacity(current_column_width);
                current_column_width = 0;
            }
        }
        if (char == ' ') {
            current_column_width += 1;
        }
    }
    columns_width.appendAssumeCapacity(current_column_width + 1);

    // 2. fill a grid
    var grid = try lib.grid.grid([]const u8, lib.grid.noop([]const u8, "")).initEmpty(allocator, 1000, 5, "");
    defer grid.deinit(allocator);

    var line_y: usize = 0;
    while (lines.next()) |line| {
        if (std.mem.eql(u8, line, last_line)) continue;

        var column_start: usize = 0;
        for (columns_width.items, 0..) |column_width, x| {
            if (x >= grid.width() or line_y >= grid.height()) break;
            if (column_start + column_width > line.len) break;
            grid.set(x, line_y, line[column_start .. column_start + column_width]);

            column_start += column_width + 1;
        }

        line_y += 1;
    }

    // 3. start the process
    // 123 328  51 64
    //  45 64  387 23
    //   6 98  215 314
    // *   +   *   +
    //
    // let's take first column only (aka x=0)
    // 123
    //  45
    //   6
    //
    // Goal is to output
    // 356
    // 24
    // 1
    //
    // curr   || v || target
    // (0, 0) || 1 || (0, 2)
    // (1, 0) || 2 || (0, 1)
    // (2, 0) || 3 || (0, 0)
    // (0, 1) ||   || (1, 2)
    // (1, 1) || 4 || (1, 1)
    // (2, 1) || 5 || (1, 0)
    // (0, 2) ||   || (2, 2)
    // (1, 2) ||   || (2, 1)
    // (2, 2) || 6 || (2, 0)
    //
    // f: (x, y) -> (y, max_x - x)
    for (0..operations.items.len) |column_index| {
        const column_width = columns_width.items[column_index];

        var rotated_column_grid = try lib.grid.grid(u8, lib.grid.noop(u8, '0')).initEmpty(
            allocator,
            grid.height(),
            column_width,
            ' ',
        );
        defer rotated_column_grid.deinit(allocator);

        for (0..column_width) |x| {
            for (0..grid.height()) |y| {
                if (column_index >= grid.width()) continue;
                const line = grid.at(column_index, y);
                if (x >= line.len) continue;
                const digit = line[x];
                rotated_column_grid.set(y, column_width - x - 1, digit);
            }
        }

        const rotated_str_rep = try rotated_column_grid.to_ascii(allocator);
        defer allocator.free(rotated_str_rep);

        const operation = operations.items[column_index];

        var rotated_grid_result: usize = 0;

        for (0..rotated_column_grid.height()) |y| {
            var full_number_str = try std.ArrayList(u8).initCapacity(allocator, rotated_column_grid.width());
            defer full_number_str.deinit(allocator);
            for (0..rotated_column_grid.width()) |x| {
                const digit = rotated_column_grid.at(x, y);
                if (digit == ' ') {
                    continue;
                }
                full_number_str.appendAssumeCapacity(digit);
            }

            if (full_number_str.items.len == 0) continue;
            const full_number = try std.fmt.parseInt(usize, full_number_str.items, 10);

            if (rotated_grid_result == 0) {
                rotated_grid_result = full_number;
            } else {
                if (operation == .add) {
                    rotated_grid_result += full_number;
                } else {
                    rotated_grid_result *= full_number;
                }
            }
        }

        result += rotated_grid_result;
    }

    return result;
}
