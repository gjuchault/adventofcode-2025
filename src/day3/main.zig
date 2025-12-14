const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day 3.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 3);
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

const Bank = struct {
    batteries_joltage_rating: std.ArrayList(u8),

    fn deinit(self: *Bank, allocator: std.mem.Allocator) void {
        self.batteries_joltage_rating.deinit(allocator);
    }
};

fn parseBanks(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Bank) {
    var result = try std.ArrayList(Bank).initCapacity(allocator, 200);

    var lines = std.mem.splitSequence(u8, input, "\n");
    while (lines.next()) |line| {
        var joltages = try std.ArrayList(u8).initCapacity(allocator, line.len);
        for (line) |char| {
            joltages.appendAssumeCapacity(lib.number.asciiToDigit(char));
        }

        result.appendAssumeCapacity(.{ .batteries_joltage_rating = joltages });
    }

    return result;
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var banks = try parseBanks(allocator, input);
    defer {
        for (banks.items) |*bank| bank.deinit(allocator);
        banks.deinit(allocator);
    }

    var result: usize = 0;

    for (banks.items) |bank| {
        var max1: u8 = 0;
        var max1_index: usize = 0;
        var max2: u8 = 0;
        var max2_index: usize = 0;
        var intermediate_result: u8 = 0;

        const len = bank.batteries_joltage_rating.items.len;

        for (bank.batteries_joltage_rating.items, 0..) |joltage, index| {
            if (joltage > max1) {
                max1 = joltage;
                max1_index = index;
            }
        }

        if (max1_index == len - 1) {
            // max is last, we need to find max2 before max1 (aka 89)
            for (0..max1_index) |index| {
                const joltage = bank.batteries_joltage_rating.items[index];

                if (joltage > max2) {
                    max2 = joltage;
                    max2_index = index;
                }
            }
        } else {
            // max isn't last, we need to find second max after (aka 98)
            for (max1_index + 1..len) |index| {
                const joltage = bank.batteries_joltage_rating.items[index];

                if (joltage > max2) {
                    max2 = joltage;
                    max2_index = index;
                }
            }
        }

        if (max1_index > max2_index) {
            intermediate_result = max2 * 10 + max1;
        } else {
            intermediate_result = max1 * 10 + max2;
        }

        result += intermediate_result;
    }

    return result;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var banks = try parseBanks(allocator, input);
    defer {
        for (banks.items) |*bank| bank.deinit(allocator);
        banks.deinit(allocator);
    }

    var result: usize = 0;

    for (banks.items) |bank| {
        var top12 = [12]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        const len = bank.batteries_joltage_rating.items.len;
        var current_start: usize = 0;

        for (0..12) |iteration| {
            const current_end = len - (12 - iteration);
            // std.debug.print("starting iteration {d}, loop from {d} to {d}\n", .{iteration, current_start, current_end});

            var max: u8 = 0;
            var next_start: usize = 0;
            for (current_start..current_end + 1) |index| {
                if (bank.batteries_joltage_rating.items[index] > max) {
                    max = bank.batteries_joltage_rating.items[index];
                    next_start = index + 1;
                    // std.debug.print("  found new max: {d} at {d}\n", .{max, index});
                }
            }

            top12[iteration] = max;
            current_start = next_start;
        }

        result += lib.number.mergeDigits(u8, &top12);
    }

    return result;
}
