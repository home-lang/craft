const std = @import("std");

pub fn build(b: *std.Build) void {
    // This is a wrapper build file for the monorepo
    // The actual Zig build is in packages/zig/build.zig

    const optimize = b.standardOptimizeOption(.{});

    // Create a step to delegate to the zig package build
    const optimize_str = b.fmt("-Doptimize={s}", .{@tagName(optimize)});
    const delegate_step = b.addSystemCommand(&.{
        "zig",
        "build",
        optimize_str,
    });
    delegate_step.cwd = b.path("packages/zig");

    // Make the default step delegate to the zig package
    b.getInstallStep().dependOn(&delegate_step.step);

    // Add test step
    const test_step = b.step("test", "Run all tests");
    const delegate_test = b.addSystemCommand(&.{
        "zig",
        "build",
        "test",
    });
    delegate_test.cwd = b.path("packages/zig");
    test_step.dependOn(&delegate_test.step);

    // Add run step (runs the main craft CLI)
    const run_step = b.step("run", "Run the craft CLI");
    const delegate_run = b.addSystemCommand(&.{
        "zig",
        "build",
        "run",
    });
    delegate_run.cwd = b.path("packages/zig");
    run_step.dependOn(&delegate_run.step);

    // Add run-demo step (runs the simple demo)
    const run_demo_step = b.step("run-demo", "Run the demo app");
    const delegate_run_demo = b.addSystemCommand(&.{
        "zig",
        "build",
        "run-demo",
    });
    delegate_run_demo.cwd = b.path("packages/zig");
    run_demo_step.dependOn(&delegate_run_demo.step);
}
