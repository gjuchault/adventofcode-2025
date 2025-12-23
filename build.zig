const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addModule("lib", .{
        .root_source_file = b.path("lib/root.zig"),
        .target = target,
    });

    const ziglangSet = b.dependency("ziglangSet", .{});
    lib.addImport("set", ziglangSet.module("ziglangSet"));

    var src_dir = std.fs.cwd().openDir("src", .{ .iterate = true }) catch |err| @panic(@errorName(err));
    defer src_dir.close();

    var src_dir_iterator = src_dir.iterate();
    while (src_dir_iterator.next() catch |err| @panic(@errorName(err))) |dir_content| {
        if (dir_content.kind == .directory) {
            const main_path = std.fmt.allocPrint(b.allocator, "src/{s}/main.zig", .{dir_content.name}) catch |err| @panic(@errorName(err));
            defer b.allocator.free(main_path);

            const exe_name = std.fmt.allocPrint(b.allocator, "adventofcode_2025_{s}", .{dir_content.name}) catch |err| @panic(@errorName(err));
            defer b.allocator.free(exe_name);

            const exe = b.addExecutable(.{
                .name = exe_name,
                .root_module = b.createModule(.{
                    .root_source_file = b.path(main_path),
                    .target = target,
                    .optimize = optimize,
                    .imports = &.{ .{ .name = "lib", .module = lib }, .{ .name = "set", .module = ziglangSet.module("ziglangSet") } },
                }),
            });

            b.installArtifact(exe);

            const run_step = b.step(dir_content.name, "day");
            const run_cmd = b.addRunArtifact(exe);
            run_step.dependOn(&run_cmd.step);

            run_cmd.step.dependOn(b.getInstallStep());
        }
    }

    const tests = b.addModule("tests", .{
        .root_source_file = b.path("lib/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const test_exe = b.addTest(.{
        .name = "tests",
        .root_module = tests,
    });
    test_exe.root_module.addImport("set", ziglangSet.module("ziglangSet"));
    const run_tests = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
