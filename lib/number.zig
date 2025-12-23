const std = @import("std");

pub fn digitsInNumber(input: usize) usize {
    return if (input == 0) 1 else std.math.log10_int(input) + 1;
}

pub fn asciiToDigit(char: u8) u8 {
    // 48 is 0 in ascii table
    if (char < 48 or char > 57) @panic("can't parse character in line");
    return char - 48;
}

pub fn stripRightDigits(input: usize, digits: usize) usize {
    var input_copy = input;
    for (0..digits) |_| {
        input_copy = @divTrunc(input_copy, 10);
    }

    return input_copy;
}

pub fn stripLeftDigits(input: usize, digits: usize) usize {
    const total_digits = digitsInNumber(input);
    if (digits >= total_digits) {
        return 0;
    }
    const digits_to_keep = total_digits - digits;
    const modulus = std.math.pow(usize, 10, digits_to_keep);
    return @mod(input, modulus);
}

pub fn splitEvenlyIn(allocator: std.mem.Allocator, input: usize, size: usize) !std.ArrayList(usize) {
    var result = std.ArrayList(usize).empty;
    result.ensureTotalCapacity(allocator, digitsInNumber(input)) catch |err| return err;

    var input_copy = input;

    while (input_copy > 0) {
        const total_digits = digitsInNumber(input_copy);
        const chunk_size = if (size > total_digits) total_digits else size;

        const digits_to_strip_from_right = total_digits - chunk_size;
        const leftmost_chunk = stripRightDigits(input_copy, digits_to_strip_from_right);

        input_copy = stripLeftDigits(input_copy, chunk_size);

        result.appendAssumeCapacity(leftmost_chunk);
    }

    return result;
}

pub fn mergeDigits(comptime T: type, input: []const T) usize {
    var result: usize = 0;

    const len: T = @intCast(input.len);
    for (input, 0..) |digit, index| {
        result += std.math.pow(usize, 10, len - index - 1) * digit;
    }

    return result;
}

test "digitsInNumber" {
    try std.testing.expectEqual(5, digitsInNumber(12345));
    try std.testing.expectEqual(10, digitsInNumber(1234567890));
    try std.testing.expectEqual(1, digitsInNumber(1));
}

test "stripRightDigits" {
    try std.testing.expectEqual(123, stripRightDigits(12345, 2));
    try std.testing.expectEqual(12, stripRightDigits(12345, 3));
    try std.testing.expectEqual(1, stripRightDigits(12345, 4));
    try std.testing.expectEqual(0, stripRightDigits(12345, 5));

    try std.testing.expectEqual(10, stripRightDigits(100, 1));
    try std.testing.expectEqual(1, stripRightDigits(100, 2));
    try std.testing.expectEqual(0, stripRightDigits(100, 3));
}

test "stripLeftDigits" {
    try std.testing.expectEqual(345, stripLeftDigits(12345, 2));
    try std.testing.expectEqual(45, stripLeftDigits(12345, 3));
    try std.testing.expectEqual(5, stripLeftDigits(12345, 4));
    try std.testing.expectEqual(0, stripLeftDigits(12345, 5));

    try std.testing.expectEqual(0, stripLeftDigits(100, 1));
    try std.testing.expectEqual(0, stripLeftDigits(100, 2));
    try std.testing.expectEqual(0, stripLeftDigits(100, 3));
}

test "splitEvenlyIn" {
    const allocator = std.testing.allocator;
    var test1 = try splitEvenlyIn(allocator, 123456, 2);
    var test2 = try splitEvenlyIn(allocator, 123456, 3);
    var test3 = try splitEvenlyIn(allocator, 123456, 4);
    var test4 = try splitEvenlyIn(allocator, 123456, 5);
    var test5 = try splitEvenlyIn(allocator, 123456, 6);

    defer {
        test1.deinit(allocator);
        test2.deinit(allocator);
        test3.deinit(allocator);
        test4.deinit(allocator);
        test5.deinit(allocator);
    }

    try std.testing.expectEqualSlices(usize, &[_]usize{ 12, 34, 56 }, test1.items);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 123, 456 }, test2.items);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 1234, 56 }, test3.items);
    try std.testing.expectEqualSlices(usize, &[_]usize{ 12345, 6 }, test4.items);
    try std.testing.expectEqualSlices(usize, &[_]usize{123456}, test5.items);
}

test "mergeDigits" {
    try std.testing.expectEqual(51423, mergeDigits(usize, &[_]usize{ 5, 1, 4, 2, 3 }));
    try std.testing.expectEqual(51423, mergeDigits(u16, &[_]u16{ 5, 1, 4, 2, 3 }));
}
