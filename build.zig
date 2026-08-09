const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    // Library module (for Zig consumers)
    const mod = b.addModule("dim", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    mod.addImport("dim", mod);

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

    // Compile the public package surface as an external consumer would. This
    // catches lazy generic API and documentation examples that internal tests
    // may never instantiate.
    const consumer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/consumer.zig"),
            .target = target,
            .imports = &.{
                .{ .name = "dim", .module = mod },
            },
        }),
    });
    const run_consumer_tests = b.addRunArtifact(consumer_tests);

    // Built-in Zig fuzz tests. These run their empty-input smoke cases during
    // normal tests and can be driven with `zig build test --fuzz=N`.
    const fuzz_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fuzz.zig"),
            .target = target,
            // ReleaseSafe avoids a Zig 0.16 test-runner error-trace type
            // mismatch in fuzz mode while retaining runtime safety checks.
            .optimize = .ReleaseSafe,
            .imports = &.{
                .{ .name = "dim", .module = mod },
            },
        }),
    });
    const run_fuzz_tests = b.addRunArtifact(fuzz_tests);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
    test_step.dependOn(&run_consumer_tests.step);
    test_step.dependOn(&run_fuzz_tests.step);

    const lib = b.addLibrary(.{
        .name = "dim",
        .root_module = mod,
    });
    b.installArtifact(lib);

    // C-compatible static library (exports C-ABI functions for FFI)
    const c_lib = b.addLibrary(.{
        .name = "dim_c",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "dim", .module = mod },
            },
        }),
    });
    b.installArtifact(c_lib);

    // WebAssembly wrapper (exports JS-callable API).
    // This is a dedicated step so building wasm does not retarget the native CLI/library graph.
    const wasm_mod = b.addModule("dim_wasm_module", .{
        .root_source_file = b.path("src/root.zig"),
        .target = wasm_target,
    });
    wasm_mod.addImport("dim", wasm_mod);

    const wasm_exe = b.addExecutable(.{
        .name = "dim_wasm",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = wasm_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "dim", .module = wasm_mod },
            },
        }),
    });
    wasm_exe.entry = .disabled;
    wasm_exe.rdynamic = true;
    wasm_exe.stack_size = 512 * 1024; // 512 KiB (default 16 MiB is excessive for this library)

    const install_wasm = b.addInstallArtifact(wasm_exe, .{});
    const wasm_step = b.step("wasm", "Build the WebAssembly wrapper");
    wasm_step.dependOn(&install_wasm.step);
}
