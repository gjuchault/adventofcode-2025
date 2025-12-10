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

    const part1_test1 = part1(allocator, files.get("test1.txt").?);
    std.debug.print("part1:test1: {d}\n", .{part1_test1});

    // 17155 too low
    const part1_input = part1(allocator, files.get("input.txt").?);
    std.debug.print("part1:input: {d}\n", .{part1_input});

    // const part2_test1 = part2(allocator, files.get("test1.txt").?);
    // std.debug.print("part2:test1: {d}\n", .{part2_test1});

    // const part2_input = part2(allocator, files.get("input.txt").?);
    // std.debug.print("part2:input: {d}\n", .{part2_input});
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
            // 48 is 0 in ascii table
            if (char < 48 or char > 57) @panic("can't parse character in line");
            joltages.appendAssumeCapacity(char - 48);
        }

        result.appendAssumeCapacity(.{
            .batteries_joltage_rating = joltages
        });
    }

    return result;
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) usize {
    var banks = parseBanks(allocator, input) catch |err| lib.die(@src(), err);
    defer {
        for (banks.items) |*bank| bank.deinit(allocator);
        banks.deinit(allocator);
    }

    var result: usize = 0;

    for (banks.items, 0..) |bank, line_n| {
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
            for (0 .. max1_index) |index| {
                const joltage = bank.batteries_joltage_rating.items[index];

                if (joltage > max2) {
                    max2 = joltage;
                    max2_index = index;
                }
            }
        } else {
            // max isn't last, we need to find second max after (aka 98)
            for (max1_index + 1 .. len) |index| {
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

        std.debug.print("line{d}: {d} ({d}) {d} ({d}) = {d}\n", .{line_n + 1, max1, max1_index, max2, max2_index, intermediate_result});
        result += intermediate_result;
    }

    return result;
}

pub fn part2(_: std.mem.Allocator, _: []const u8) usize {
    const result: usize = 0;

    return result;
}
