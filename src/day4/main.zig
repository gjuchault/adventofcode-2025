const std = @import("std");
const lib = @import("lib");

pub fn main() !void {
    std.debug.print("Day 4.\n", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer {
        const leaked = gpa.deinit() == .leak;
        if (leaked) @panic("leak detected");
    }
    const allocator = gpa.allocator();

    var files = lib.readAllTexts(allocator, 4);
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

pub const GridItem = enum { empty, roll_of_paper };

fn charToGridItem(input: u8) GridItem {
    if (input == '.') {
        return GridItem.empty;
    } else if (input == '@') {
        return GridItem.roll_of_paper;
    }

    @panic("Unexpected character");
}

const Grid = lib.grid.grid(GridItem, charToGridItem);

fn removeRolls(allocator: std.mem.Allocator, grid: *Grid) usize {
    var rolls_to_remove = std.ArrayList(lib.grid.Point).initCapacity(allocator, 2000) catch |err| lib.die(@src(), err);
    defer rolls_to_remove.deinit(allocator);

    var iterator = grid.iterator();
    while (iterator.next()) |point_and_value| {
        const point, const value = point_and_value;

        if (value == .empty) {
            continue;
        }

        var adjacents = grid.adjacents(allocator, point, true) catch |err| lib.die(@src(), err);
        defer adjacents.deinit(allocator);

        var count_of_adjacent_papers: usize = 0;
        for (adjacents.items) |adjacent| {
            const adjacent_value = grid.at(adjacent.x, adjacent.y);
            if (adjacent_value == .roll_of_paper) {
                count_of_adjacent_papers += 1;
            }
        }

        if (count_of_adjacent_papers < 4) {
            rolls_to_remove.append(allocator, point) catch |err| lib.die(@src(), err);
        }
    }

    const removed = rolls_to_remove.items.len;

    for (rolls_to_remove.items) |roll_to_remove| {
        grid.set(roll_to_remove.x, roll_to_remove.y, .empty);
    }

    return removed;
}

pub fn part1(allocator: std.mem.Allocator, input: []const u8) usize {
    var grid = Grid.init(allocator, input, 20) catch |err| lib.die(@src(), err);
    defer grid.deinit(allocator);

    return removeRolls(allocator, &grid);
}

pub fn part2(allocator: std.mem.Allocator, input: []const u8) usize {
    var grid = Grid.init(allocator, input, 20) catch |err| lib.die(@src(), err);
    defer grid.deinit(allocator);

    var total_removed: usize = 0;

    var turn: usize = 0;
    while (true) {
        turn += 1;

        const removed = removeRolls(allocator, &grid);

        total_removed += removed;

        if (removed == 0) {
            break;
        }
    }

    return total_removed;
}
