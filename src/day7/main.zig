const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day 7.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 7);
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

const GridItem = enum { space, manifold, beam, splitter };
fn charToGridItem(char: u8) GridItem {
    if (char == '.') return GridItem.space;
    if (char == 'S') return GridItem.manifold;
    if (char == '|') return GridItem.beam;
    if (char == '^') return GridItem.splitter;
    @panic("can't parse character");
}
fn gridItemToChar(item: GridItem) u8 {
    if (item == GridItem.space) return '.';
    if (item == GridItem.manifold) return 'S';
    if (item == GridItem.beam) return '|';
    if (item == GridItem.splitter) return '^';
    @panic("can't parse character");
}
const Grid = lib.grid.grid(GridItem, charToGridItem);

pub fn part1(allocator: std.mem.Allocator, input: []const u8) !usize {
    var result: usize = 0;

    var grid = try Grid.init(allocator, input, null);
    defer grid.deinit(allocator);

    const manifold_point = lib.grid.Point{ .x = @divFloor(grid.width(), 2), .y = 0 };

    var current_beam_coords = try std.ArrayList(lib.grid.Point).initCapacity(allocator, grid.width() * 2);
    defer current_beam_coords.deinit(allocator);

    var round: usize = 0;
    while (true) {
        round += 1;

        if (round == 1) {
            current_beam_coords.appendAssumeCapacity(.{
                .x = manifold_point.x,
                .y = manifold_point.y + 1,
            });

            grid.set(manifold_point.x, manifold_point.y + 1, .beam);
        }

        if (round == grid.height() - 1) {
            break;
        }

        const beams_count_before_round = current_beam_coords.items.len;

        for (0..beams_count_before_round) |beam_index| {
            const beam = current_beam_coords.items[beam_index];

            const point_below = lib.grid.Point{ .x = beam.x, .y = beam.y + 1 };
            const item_below = grid.at(point_below.x, point_below.y);

            switch (item_below) {
                .beam => continue,
                .manifold => @panic("manifold below"),
                .space => {
                    current_beam_coords.appendAssumeCapacity(point_below);
                    grid.set(point_below.x, point_below.y, .beam);
                },
                .splitter => {
                    result += 1;

                    if (beam.x > 0) {
                        current_beam_coords.appendAssumeCapacity(.{ .x = beam.x - 1, .y = beam.y + 1 });
                        grid.set(beam.x - 1, beam.y + 1, .beam);
                    }
                    if (beam.x < grid.width()) {
                        current_beam_coords.appendAssumeCapacity(.{ .x = beam.x + 1, .y = beam.y + 1 });
                        grid.set(beam.x + 1, beam.y + 1, .beam);
                    }
                },
            }
        }

        lib.array_list.removeFirstElements(lib.grid.Point, &current_beam_coords, beams_count_before_round);
    }

    return result;
}

pub fn get_next_results(
    result_by_point: *std.AutoHashMap(lib.grid.Point, usize),
    starting_point: lib.grid.Point,
) usize {
    var result: usize = 0;
    var point_left = lib.grid.Point{ .x = starting_point.x - 1, .y = starting_point.y + 1 };
    var point_right = lib.grid.Point{ .x = starting_point.x + 1, .y = starting_point.y + 1 };

    var left_done = false;
    var right_done = false;

    while (!(left_done and right_done)) {
        if (!left_done) {
            if (result_by_point.contains(point_left)) {
                result += result_by_point.get(point_left).?;
                left_done = true;
            } else {
                point_left.y += 1;
            }
        }

        if (!right_done) {
            if (result_by_point.contains(point_right)) {
                result += result_by_point.get(point_right).?;
                right_done = true;
            } else {
                point_right.y += 1;
            }
        }
    }

    return result;
}

// the idea for part 2 is to tag bottom line: a last splitter = 2, a last space = 1
// then loop on line above and for each splitter, sum scores from below
pub fn part2(allocator: std.mem.Allocator, input: []const u8) !usize {
    var grid = try Grid.init(allocator, input, null);
    defer grid.deinit(allocator);

    const manifold_point = lib.grid.Point{ .x = @divFloor(grid.width(), 2), .y = 0 };
    const first_splitter_point = lib.grid.Point{ .x = manifold_point.x, .y = manifold_point.y + 2 };

    var result_by_point = std.AutoHashMap(lib.grid.Point, usize).init(allocator);
    defer result_by_point.deinit();

    try result_by_point.put(manifold_point, 0);

    var line = grid.height() - 2;
    while (true) {
        for (0..grid.width()) |x| {
            const point = lib.grid.Point{ .x = x, .y = line };
            const item = grid.at(point.x, point.y);

            if (item == .space) {
                if (point.y == grid.height() - 2) {
                    try result_by_point.put(point, 1);
                }
            }

            if (item == .splitter) {
                if (point.y == grid.height() - 2) {
                    try result_by_point.put(point, 2);
                } else {
                    const result_from_below = get_next_results(&result_by_point, point);
                    try result_by_point.put(point, result_from_below);
                }
            }
        }

        if (line == 2) {
            break;
        }

        line -= 2;
    }

    return result_by_point.get(first_splitter_point).?;
}
