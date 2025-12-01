const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day 1.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var x = lib.readAllTexts(allocator, 1);
    defer {
      var iter = x.iterator();
      while (iter.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
      }
      x.deinit();
      allocator.destroy(x);
    }

    const part1_test1 = part1(allocator, x.get("test1.txt").?);
    std.debug.print("part1:test1: {d}\n", .{part1_test1});

    const part1_input = part1(allocator, x.get("input.txt").?);
    std.debug.print("part1:input: {d}\n", .{part1_input});

    const part2_test1 = part2(allocator, x.get("test1.txt").?);
    std.debug.print("part2:test1: {d}\n", .{part2_test1});

    const part2_test2 = part2(allocator, x.get("test2.txt").?);
    std.debug.print("part2:test2: {d}\n", .{part2_test2});

    const part2_input = part2(allocator, x.get("input.txt").?);
    std.debug.print("part2:input: {d}\n", .{part2_input});
}

pub fn part1(_: std.mem.Allocator, input: []const u8) u32 {
  var dial: i32 = 50;
  var count_of_0: u32 = 0;

  var split_lines_iterator = std.mem.splitScalar(u8, input, '\n');
  while (split_lines_iterator.next()) |line| {
    const first_char = line[0];

    const steps = std.fmt.parseInt(i32, line[1..], 10) catch |err| lib.die(@src(), err);

    if (first_char == 'L') {
      dial -= steps;
    } else if (first_char == 'R') {
      dial += steps;
    }

    if (dial < 0) {
      // if we have 50, L200, that's -250. But -100 is already a plain rotation, so it's equal to 0
      // --> we need to remove every hundreds. aka turn -118 into -18, -250 into -50, etc.
      dial = @mod(dial, -100);
    } else {
      dial = @mod(dial, 100);
    }

    if (dial == 0) {
      count_of_0 += 1;
    }
  }

  if (dial < 0) {
    // at the end, if we're below 0 (eg. -18), we're actually at 100 + -18=82
    dial = 100 + dial;
  }

  return count_of_0;
}


pub fn part2(_: std.mem.Allocator, input: []const u8) u32 {
  var dial: i32 = 50;
  var count_of_0: u32 = 0;

  var split_lines_iterator = std.mem.splitScalar(u8, input, '\n');
  while (split_lines_iterator.next()) |line| {
    const first_char = line[0];

    var steps = std.fmt.parseInt(i32, line[1..], 10) catch |err| lib.die(@src(), err);

    while (steps > 0) {
      if (first_char == 'L') {
        dial -= 1;
      }
      if (first_char == 'R') {
        dial += 1;
      }


      if (dial == 100) {
        dial = 0;
      }

      if (dial == 0) {
        count_of_0 += 1;
      }

      if (dial == -1) {
        dial = 99;
      }

      steps -= 1;
    }
  }

  return count_of_0;
}
