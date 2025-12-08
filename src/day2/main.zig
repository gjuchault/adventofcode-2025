const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day 2.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 2);
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

const ProductIdRange = struct { first_id: usize, last_id: usize };

pub fn part1AllPatterns(allocator: std.mem.Allocator, input: []const u8, size: usize) std.ArrayList([]const u8) {
    var result = std.ArrayList([]const u8).empty;

    for (0..input.len - size) |start_idx| {
        const part = input[start_idx .. start_idx + size];
        result.append(allocator, part) catch |err| lib.die(@src(), err);
    }

    return result;
}

pub fn part1IsInvalidId(input: usize) bool {
    const digits_in_input = lib.number.digitsInNumber(input);

    // since we're checking AB or AABB or AAABBB, we have necessarily an even-digits number
    if (@mod(digits_in_input, 2) != 0) {
        return false;
    }

    const left_half = lib.number.stripRightDigits(input, digits_in_input / 2);
    const right_half = lib.number.stripLeftDigits(input, digits_in_input / 2);

    return left_half == right_half;
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) usize {
    var parsed_ranges = std.ArrayList(ProductIdRange).empty;
    defer parsed_ranges.deinit(allocator);

    const input_one_line = std.mem.replaceOwned(u8, allocator, input, "\n", "") catch |err| lib.die(@src(), err);
    defer allocator.free(input_one_line);

    var ranges = std.mem.splitSequence(u8, input_one_line, ",");

    while (ranges.next()) |raw_product_id_range| {
        var ids = std.mem.splitSequence(u8, raw_product_id_range, "-");
        const first_id_str = ids.first();
        const last_id_str = ids.next();

        if (last_id_str == null) {
            lib.die(@src(), error.CantSplitProductIdRange);
        }

        parsed_ranges.append(allocator, .{
            .first_id = std.fmt.parseInt(usize, first_id_str, 10) catch |err| lib.die(@src(), err),
            .last_id = std.fmt.parseInt(usize, last_id_str.?, 10) catch |err| lib.die(@src(), err),
        }) catch |err| lib.die(@src(), err);
    }

    var result: usize = 0;

    for (parsed_ranges.items) |range| {
        for (range.first_id..range.last_id + 1) |id| {
            if (part1IsInvalidId(id)) {
                result += id;
            }
        }
    }

    return result;
}

pub fn part2IsInvalidId(input: usize) bool {
    const digits_in_input = lib.number.digitsInNumber(input);

    for (1..digits_in_input) |pattern_size| {
        // no need to continue if we can't divide equally the pattern (aka AABBC has no point checking size=2)
        if (@mod(digits_in_input, pattern_size) != 0) {
            continue;
        }

        const num_parts = digits_in_input / pattern_size;
        // no need to continue if we don't have at least 2 parts
        if (num_parts < 2) continue;

        const first_pattern = lib.number.stripRightDigits(input, digits_in_input - pattern_size);

        var all_match = true;
        var remaining = input;

        for (0..num_parts) |_| {
            const current_digits = lib.number.digitsInNumber(remaining);
            if (current_digits < pattern_size) {
                all_match = false;
                break;
            }

            const pattern = lib.number.stripRightDigits(remaining, current_digits - pattern_size);
            if (pattern != first_pattern) {
                all_match = false;
                break;
            }

            remaining = lib.number.stripLeftDigits(remaining, pattern_size);
        }

        if (all_match) {
            return true;
        }
    }

    return false;
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) usize {
    var parsed_ranges = std.ArrayList(ProductIdRange).empty;
    defer parsed_ranges.deinit(allocator);

    const input_one_line = std.mem.replaceOwned(u8, allocator, input, "\n", "") catch |err| lib.die(@src(), err);
    defer allocator.free(input_one_line);

    var ranges = std.mem.splitSequence(u8, input_one_line, ",");

    while (ranges.next()) |raw_product_id_range| {
        var ids = std.mem.splitSequence(u8, raw_product_id_range, "-");
        const first_id_str = ids.first();
        const last_id_str = ids.next();

        if (last_id_str == null) {
            lib.die(@src(), error.CantSplitProductIdRange);
        }

        parsed_ranges.append(allocator, .{
            .first_id = std.fmt.parseInt(usize, first_id_str, 10) catch |err| lib.die(@src(), err),
            .last_id = std.fmt.parseInt(usize, last_id_str.?, 10) catch |err| lib.die(@src(), err),
        }) catch |err| lib.die(@src(), err);
    }

    var result: usize = 0;
    for (parsed_ranges.items) |range| {
        for (range.first_id..range.last_id + 1) |id| {
            if (part2IsInvalidId(id)) {
                result += id;
            }
        }
    }

    return result;
}
