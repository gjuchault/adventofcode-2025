const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  const lib = b.addModule("lib", .{
    .root_source_file = b.path("lib/root.zig"),
    .target = target,
  });

  var src_folder = std.fs.cwd().openDir("src", .{ .iterate = true }) catch |err| {
    std.log.err("error: {any}", .{ err });
    std.process.exit(1);
  };
  defer src_folder.close();

  var src_folder_iterator = src_folder.iterate();
  while (src_folder_iterator.next() catch unreachable) |dirContent| {
    if (dirContent.kind == .directory) {
      const main_path = std.fmt.allocPrint(b.allocator, "src/{s}/main.zig", .{dirContent.name}) catch unreachable;
      defer b.allocator.free(main_path);

      const exe = b.addExecutable(.{
        .name = "adventofcode_2025",
        .root_module = b.createModule(.{
          .root_source_file = b.path(main_path),
          .target = target,
          .optimize = optimize,
          .imports = &.{
            .{ .name = "lib", .module = lib },
          },
        }),
      });

      b.installArtifact(exe);

      const run_step = b.step(dirContent.name, "Run the app");
      const run_cmd = b.addRunArtifact(exe);
      run_step.dependOn(&run_cmd.step);

      run_cmd.step.dependOn(b.getInstallStep());
    }
  }
}
