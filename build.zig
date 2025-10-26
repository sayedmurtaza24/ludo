const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.addModule("ludo", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const root_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ludo", .module = lib_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "ludo",
        .root_module = root_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    const exe_check = b.addExecutable(.{
        .name = "ludo",
        .root_module = root_mod,
    });

    const check = b.step("check", "Check if ludo compiles");
    check.dependOn(&exe_check.step);

    const mod_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
