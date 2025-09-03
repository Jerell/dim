const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module (for Zig consumers)
    const mod = b.addModule("dim", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // CLI executable
    const exe = b.addExecutable(.{
        .name = "dim",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "dim", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    // Run step for CLI
    const run_step = b.step("run", "Run the CLI tool");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    // Tests for library
    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Tests for CLI
    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const lib = b.addLibrary(.{
        .name = "dim",
        .root_module = mod,
    });
    b.installArtifact(lib);
}
