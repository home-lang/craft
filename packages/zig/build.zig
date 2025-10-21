const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the zyte module
    const zyte_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
    });

    // Example executable
    const exe = b.addExecutable(.{
        .name = "zyte-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyte", .module = zyte_module },
            },
        }),
    });

    // Add system libraries based on platform
    const target_os = target.result.os.tag;
    switch (target_os) {
        .macos => {
            exe.linkFramework("Cocoa");
            exe.linkFramework("WebKit");
        },
        .linux => {
            exe.linkSystemLibrary("gtk+-3.0");
            exe.linkSystemLibrary("webkit2gtk-4.0");
        },
        .windows => {
            exe.linkSystemLibrary("ole32");
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
        },
        else => {},
    }

    exe.linkLibC();
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example app");
    run_step.dependOn(&run_cmd.step);

    // Minimal app executable
    const minimal_exe = b.addExecutable(.{
        .name = "zyte-minimal",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/minimal.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyte", .module = zyte_module },
            },
        }),
    });

    switch (target_os) {
        .macos => {
            minimal_exe.linkFramework("Cocoa");
            minimal_exe.linkFramework("WebKit");
        },
        .linux => {
            minimal_exe.linkSystemLibrary("gtk+-3.0");
            minimal_exe.linkSystemLibrary("webkit2gtk-4.0");
        },
        .windows => {
            minimal_exe.linkSystemLibrary("ole32");
            minimal_exe.linkSystemLibrary("user32");
            minimal_exe.linkSystemLibrary("gdi32");
        },
        else => {},
    }

    minimal_exe.linkLibC();
    b.installArtifact(minimal_exe);

    const run_minimal_cmd = b.addRunArtifact(minimal_exe);
    run_minimal_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_minimal_cmd.addArgs(args);
    }

    const run_minimal_step = b.step("run-minimal", "Run the minimal app");
    run_minimal_step.dependOn(&run_minimal_cmd.step);

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Individual test files with proper imports
    // Create module for each source file
    const api_module = b.createModule(.{
        .root_source_file = b.path("src/api.zig"),
    });

    const mobile_module = b.createModule(.{
        .root_source_file = b.path("src/mobile.zig"),
    });

    const menubar_module = b.createModule(.{
        .root_source_file = b.path("src/menubar.zig"),
    });

    const components_module = b.createModule(.{
        .root_source_file = b.path("src/components.zig"),
    });

    const gpu_module = b.createModule(.{
        .root_source_file = b.path("src/gpu.zig"),
    });

    const system_module = b.createModule(.{
        .root_source_file = b.path("src/system.zig"),
    });

    const profiler_module = b.createModule(.{
        .root_source_file = b.path("src/profiler.zig"),
    });

    const memory_module = b.createModule(.{
        .root_source_file = b.path("src/memory.zig"),
    });

    const lifecycle_module = b.createModule(.{
        .root_source_file = b.path("src/lifecycle.zig"),
    });

    const shortcuts_module = b.createModule(.{
        .root_source_file = b.path("src/shortcuts.zig"),
    });

    const hotreload_module = b.createModule(.{
        .root_source_file = b.path("src/hotreload.zig"),
    });

    const async_module = b.createModule(.{
        .root_source_file = b.path("src/async.zig"),
    });

    const events_module = b.createModule(.{
        .root_source_file = b.path("src/events.zig"),
    });

    const bridge_module = b.createModule(.{
        .root_source_file = b.path("src/bridge.zig"),
    });

    const devmode_module = b.createModule(.{
        .root_source_file = b.path("src/devmode.zig"),
    });

    const renderer_module = b.createModule(.{
        .root_source_file = b.path("src/renderer.zig"),
    });

    const log_module = b.createModule(.{
        .root_source_file = b.path("src/log.zig"),
    });

    const theme_module = b.createModule(.{
        .root_source_file = b.path("src/theme.zig"),
    });

    const animation_module = b.createModule(.{
        .root_source_file = b.path("src/animation.zig"),
    });

    const cli_module = b.createModule(.{
        .root_source_file = b.path("src/cli.zig"),
    });

    const config_module = b.createModule(.{
        .root_source_file = b.path("src/config.zig"),
    });

    const ipc_module = b.createModule(.{
        .root_source_file = b.path("src/ipc.zig"),
    });

    const performance_module = b.createModule(.{
        .root_source_file = b.path("src/performance.zig"),
    });

    const benchmark_module = b.createModule(.{
        .root_source_file = b.path("src/benchmark.zig"),
    });

    const api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/api_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/api.zig", .module = api_module },
            },
        }),
    });

    const mobile_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/mobile_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/mobile.zig", .module = mobile_module },
            },
        }),
    });

    const menubar_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/menubar_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/menubar.zig", .module = menubar_module },
            },
        }),
    });

    const components_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/components.zig", .module = components_module },
            },
        }),
    });

    const gpu_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/gpu_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/gpu.zig", .module = gpu_module },
            },
        }),
    });

    const system_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/system_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/system.zig", .module = system_module },
            },
        }),
    });

    const profiler_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/profiler_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/profiler.zig", .module = profiler_module },
            },
        }),
    });

    const memory_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/memory_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/memory.zig", .module = memory_module },
            },
        }),
    });

    const lifecycle_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/lifecycle_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/lifecycle.zig", .module = lifecycle_module },
            },
        }),
    });

    const shortcuts_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/shortcuts_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/shortcuts.zig", .module = shortcuts_module },
            },
        }),
    });

    const hotreload_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/hotreload_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/hotreload.zig", .module = hotreload_module },
            },
        }),
    });

    const async_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/async_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/async.zig", .module = async_module },
            },
        }),
    });

    const events_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/events_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/events.zig", .module = events_module },
            },
        }),
    });

    const bridge_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/bridge_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/bridge.zig", .module = bridge_module },
            },
        }),
    });

    const devmode_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/devmode_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/devmode.zig", .module = devmode_module },
            },
        }),
    });

    const renderer_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/renderer_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/renderer.zig", .module = renderer_module },
            },
        }),
    });

    const log_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/log_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/log.zig", .module = log_module },
            },
        }),
    });

    const theme_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/theme_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/theme.zig", .module = theme_module },
            },
        }),
    });

    const animation_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/animation_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/animation.zig", .module = animation_module },
            },
        }),
    });

    const cli_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/cli_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/cli.zig", .module = cli_module },
            },
        }),
    });

    const config_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/config_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/config.zig", .module = config_module },
            },
        }),
    });

    const ipc_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/ipc_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/ipc.zig", .module = ipc_module },
            },
        }),
    });

    const performance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/performance_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/performance.zig", .module = performance_module },
            },
        }),
    });

    const button_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/button_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const text_input_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/text_input_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const chart_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/chart_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const media_player_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/media_player_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const code_editor_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/code_editor_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const tabs_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/tabs_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const modal_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/modal_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const progress_bar_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/progress_bar_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const dropdown_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/dropdown_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const toast_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/toast_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const tree_view_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/tree_view_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const date_picker_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/date_picker_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const data_grid_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/data_grid_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const tooltip_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/tooltip_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const slider_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/slider_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const autocomplete_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/autocomplete_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const color_picker_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/components/color_picker_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "components", .module = zyte_module },
            },
        }),
    });

    const error_context_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/error_context_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "../src/error_context.zig", .module = b.createModule(.{
                    .root_source_file = b.path("src/error_context.zig"),
                }) },
            },
        }),
    });

    const benchmark_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/benchmark_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "benchmark", .module = benchmark_module },
            },
        }),
    });

    const run_api_tests = b.addRunArtifact(api_tests);
    const run_mobile_tests = b.addRunArtifact(mobile_tests);
    const run_menubar_tests = b.addRunArtifact(menubar_tests);
    const run_components_tests = b.addRunArtifact(components_tests);
    const run_gpu_tests = b.addRunArtifact(gpu_tests);
    const run_system_tests = b.addRunArtifact(system_tests);
    const run_profiler_tests = b.addRunArtifact(profiler_tests);
    const run_memory_tests = b.addRunArtifact(memory_tests);
    const run_lifecycle_tests = b.addRunArtifact(lifecycle_tests);
    const run_shortcuts_tests = b.addRunArtifact(shortcuts_tests);
    const run_hotreload_tests = b.addRunArtifact(hotreload_tests);
    const run_async_tests = b.addRunArtifact(async_tests);
    const run_events_tests = b.addRunArtifact(events_tests);
    const run_bridge_tests = b.addRunArtifact(bridge_tests);
    const run_devmode_tests = b.addRunArtifact(devmode_tests);
    const run_renderer_tests = b.addRunArtifact(renderer_tests);
    const run_log_tests = b.addRunArtifact(log_tests);
    const run_theme_tests = b.addRunArtifact(theme_tests);
    const run_animation_tests = b.addRunArtifact(animation_tests);
    const run_cli_tests = b.addRunArtifact(cli_tests);
    const run_config_tests = b.addRunArtifact(config_tests);
    const run_ipc_tests = b.addRunArtifact(ipc_tests);
    const run_performance_tests = b.addRunArtifact(performance_tests);
    const run_button_tests = b.addRunArtifact(button_tests);
    const run_text_input_tests = b.addRunArtifact(text_input_tests);
    const run_chart_tests = b.addRunArtifact(chart_tests);
    const run_media_player_tests = b.addRunArtifact(media_player_tests);
    const run_code_editor_tests = b.addRunArtifact(code_editor_tests);
    const run_tabs_tests = b.addRunArtifact(tabs_tests);
    const run_modal_tests = b.addRunArtifact(modal_tests);
    const run_progress_bar_tests = b.addRunArtifact(progress_bar_tests);
    const run_dropdown_tests = b.addRunArtifact(dropdown_tests);
    const run_toast_tests = b.addRunArtifact(toast_tests);
    const run_tree_view_tests = b.addRunArtifact(tree_view_tests);
    const run_date_picker_tests = b.addRunArtifact(date_picker_tests);
    const run_data_grid_tests = b.addRunArtifact(data_grid_tests);
    const run_tooltip_tests = b.addRunArtifact(tooltip_tests);
    const run_slider_tests = b.addRunArtifact(slider_tests);
    const run_autocomplete_tests = b.addRunArtifact(autocomplete_tests);
    const run_color_picker_tests = b.addRunArtifact(color_picker_tests);
    const run_error_context_tests = b.addRunArtifact(error_context_tests);
    const run_benchmark_tests = b.addRunArtifact(benchmark_tests);

    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_api_tests.step);
    test_step.dependOn(&run_mobile_tests.step);
    test_step.dependOn(&run_menubar_tests.step);
    test_step.dependOn(&run_components_tests.step);
    test_step.dependOn(&run_gpu_tests.step);
    test_step.dependOn(&run_system_tests.step);
    test_step.dependOn(&run_profiler_tests.step);
    test_step.dependOn(&run_memory_tests.step);
    test_step.dependOn(&run_lifecycle_tests.step);
    test_step.dependOn(&run_shortcuts_tests.step);
    test_step.dependOn(&run_hotreload_tests.step);
    test_step.dependOn(&run_async_tests.step);
    test_step.dependOn(&run_events_tests.step);
    test_step.dependOn(&run_bridge_tests.step);
    test_step.dependOn(&run_devmode_tests.step);
    test_step.dependOn(&run_renderer_tests.step);
    test_step.dependOn(&run_log_tests.step);
    test_step.dependOn(&run_theme_tests.step);
    test_step.dependOn(&run_animation_tests.step);
    test_step.dependOn(&run_cli_tests.step);
    test_step.dependOn(&run_config_tests.step);
    test_step.dependOn(&run_ipc_tests.step);
    test_step.dependOn(&run_performance_tests.step);
    test_step.dependOn(&run_button_tests.step);
    test_step.dependOn(&run_text_input_tests.step);
    test_step.dependOn(&run_chart_tests.step);
    test_step.dependOn(&run_media_player_tests.step);
    test_step.dependOn(&run_code_editor_tests.step);
    test_step.dependOn(&run_tabs_tests.step);
    test_step.dependOn(&run_modal_tests.step);
    test_step.dependOn(&run_progress_bar_tests.step);
    test_step.dependOn(&run_dropdown_tests.step);
    test_step.dependOn(&run_toast_tests.step);
    test_step.dependOn(&run_tree_view_tests.step);
    test_step.dependOn(&run_date_picker_tests.step);
    test_step.dependOn(&run_data_grid_tests.step);
    test_step.dependOn(&run_tooltip_tests.step);
    test_step.dependOn(&run_slider_tests.step);
    test_step.dependOn(&run_autocomplete_tests.step);
    test_step.dependOn(&run_color_picker_tests.step);
    test_step.dependOn(&run_error_context_tests.step);
    test_step.dependOn(&run_benchmark_tests.step);

    // Individual test steps
    const test_api_step = b.step("test:api", "Run API tests");
    test_api_step.dependOn(&run_api_tests.step);

    const test_mobile_step = b.step("test:mobile", "Run Mobile tests");
    test_mobile_step.dependOn(&run_mobile_tests.step);

    const test_menubar_step = b.step("test:menubar", "Run Menubar tests");
    test_menubar_step.dependOn(&run_menubar_tests.step);

    const test_components_step = b.step("test:components", "Run Components tests");
    test_components_step.dependOn(&run_components_tests.step);

    const test_gpu_step = b.step("test:gpu", "Run GPU tests");
    test_gpu_step.dependOn(&run_gpu_tests.step);

    const test_system_step = b.step("test:system", "Run System tests");
    test_system_step.dependOn(&run_system_tests.step);

    const test_profiler_step = b.step("test:profiler", "Run Profiler tests");
    test_profiler_step.dependOn(&run_profiler_tests.step);

    const test_memory_step = b.step("test:memory", "Run Memory tests");
    test_memory_step.dependOn(&run_memory_tests.step);

    const test_lifecycle_step = b.step("test:lifecycle", "Run Lifecycle tests");
    test_lifecycle_step.dependOn(&run_lifecycle_tests.step);

    const test_shortcuts_step = b.step("test:shortcuts", "Run Shortcuts tests");
    test_shortcuts_step.dependOn(&run_shortcuts_tests.step);

    const test_hotreload_step = b.step("test:hotreload", "Run Hot Reload tests");
    test_hotreload_step.dependOn(&run_hotreload_tests.step);

    const test_async_step = b.step("test:async", "Run Async tests");
    test_async_step.dependOn(&run_async_tests.step);

    const test_events_step = b.step("test:events", "Run Events tests");
    test_events_step.dependOn(&run_events_tests.step);

    const test_bridge_step = b.step("test:bridge", "Run Bridge tests");
    test_bridge_step.dependOn(&run_bridge_tests.step);

    const test_devmode_step = b.step("test:devmode", "Run Dev Mode tests");
    test_devmode_step.dependOn(&run_devmode_tests.step);

    const test_renderer_step = b.step("test:renderer", "Run Renderer tests");
    test_renderer_step.dependOn(&run_renderer_tests.step);

    const test_log_step = b.step("test:log", "Run Log tests");
    test_log_step.dependOn(&run_log_tests.step);

    const test_theme_step = b.step("test:theme", "Run Theme tests");
    test_theme_step.dependOn(&run_theme_tests.step);

    const test_animation_step = b.step("test:animation", "Run Animation tests");
    test_animation_step.dependOn(&run_animation_tests.step);

    const test_cli_step = b.step("test:cli", "Run CLI tests");
    test_cli_step.dependOn(&run_cli_tests.step);

    const test_config_step = b.step("test:config", "Run Config tests");
    test_config_step.dependOn(&run_config_tests.step);

    const test_ipc_step = b.step("test:ipc", "Run IPC tests");
    test_ipc_step.dependOn(&run_ipc_tests.step);

    const test_performance_step = b.step("test:performance", "Run Performance tests");
    test_performance_step.dependOn(&run_performance_tests.step);

    const test_button_step = b.step("test:button", "Run Button component tests");
    test_button_step.dependOn(&run_button_tests.step);

    const test_text_input_step = b.step("test:text_input", "Run TextInput component tests");
    test_text_input_step.dependOn(&run_text_input_tests.step);

    const test_chart_step = b.step("test:chart", "Run Chart component tests");
    test_chart_step.dependOn(&run_chart_tests.step);

    const test_media_player_step = b.step("test:media_player", "Run MediaPlayer component tests");
    test_media_player_step.dependOn(&run_media_player_tests.step);

    const test_code_editor_step = b.step("test:code_editor", "Run CodeEditor component tests");
    test_code_editor_step.dependOn(&run_code_editor_tests.step);

    const test_tabs_step = b.step("test:tabs", "Run Tabs component tests");
    test_tabs_step.dependOn(&run_tabs_tests.step);

    const test_modal_step = b.step("test:modal", "Run Modal component tests");
    test_modal_step.dependOn(&run_modal_tests.step);

    const test_progress_bar_step = b.step("test:progress_bar", "Run ProgressBar component tests");
    test_progress_bar_step.dependOn(&run_progress_bar_tests.step);

    const test_dropdown_step = b.step("test:dropdown", "Run Dropdown component tests");
    test_dropdown_step.dependOn(&run_dropdown_tests.step);

    const test_toast_step = b.step("test:toast", "Run Toast component tests");
    test_toast_step.dependOn(&run_toast_tests.step);

    const test_tree_view_step = b.step("test:tree_view", "Run TreeView component tests");
    test_tree_view_step.dependOn(&run_tree_view_tests.step);

    const test_date_picker_step = b.step("test:date_picker", "Run DatePicker component tests");
    test_date_picker_step.dependOn(&run_date_picker_tests.step);

    const test_data_grid_step = b.step("test:data_grid", "Run DataGrid component tests");
    test_data_grid_step.dependOn(&run_data_grid_tests.step);

    const test_tooltip_step = b.step("test:tooltip", "Run Tooltip component tests");
    test_tooltip_step.dependOn(&run_tooltip_tests.step);

    const test_slider_step = b.step("test:slider", "Run Slider component tests");
    test_slider_step.dependOn(&run_slider_tests.step);

    const test_autocomplete_step = b.step("test:autocomplete", "Run Autocomplete component tests");
    test_autocomplete_step.dependOn(&run_autocomplete_tests.step);

    const test_color_picker_step = b.step("test:color_picker", "Run ColorPicker component tests");
    test_color_picker_step.dependOn(&run_color_picker_tests.step);

    const test_error_context_step = b.step("test:error_context", "Run ErrorContext tests");
    test_error_context_step.dependOn(&run_error_context_tests.step);

    const test_benchmark_step = b.step("test:benchmark", "Run Benchmark tests");
    test_benchmark_step.dependOn(&run_benchmark_tests.step);

    // Cross-compilation helpers
    const build_linux = b.step("build-linux", "Build for Linux");
    const build_windows = b.step("build-windows", "Build for Windows");
    const build_macos = b.step("build-macos", "Build for macOS");
    const build_all = b.step("build-all", "Build for all platforms");

    // Linux target
    const linux_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
    });

    const linux_exe = b.addExecutable(.{
        .name = "zyte-linux",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/minimal.zig"),
            .target = linux_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyte", .module = zyte_module },
            },
        }),
    });
    linux_exe.linkSystemLibrary("gtk+-3.0");
    linux_exe.linkSystemLibrary("webkit2gtk-4.0");
    linux_exe.linkLibC();

    const linux_install = b.addInstallArtifact(linux_exe, .{});
    build_linux.dependOn(&linux_install.step);
    build_all.dependOn(&linux_install.step);

    // Windows target
    const windows_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .windows,
        .abi = .gnu,
    });

    const windows_exe = b.addExecutable(.{
        .name = "zyte-windows",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/minimal.zig"),
            .target = windows_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyte", .module = zyte_module },
            },
        }),
    });
    windows_exe.linkSystemLibrary("ole32");
    windows_exe.linkSystemLibrary("user32");
    windows_exe.linkSystemLibrary("gdi32");
    windows_exe.linkLibC();

    const windows_install = b.addInstallArtifact(windows_exe, .{});
    build_windows.dependOn(&windows_install.step);
    build_all.dependOn(&windows_install.step);

    // macOS target
    const macos_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    });

    const macos_exe = b.addExecutable(.{
        .name = "zyte-macos",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/minimal.zig"),
            .target = macos_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyte", .module = zyte_module },
            },
        }),
    });
    macos_exe.linkFramework("Cocoa");
    macos_exe.linkFramework("WebKit");
    macos_exe.linkLibC();

    const macos_install = b.addInstallArtifact(macos_exe, .{});
    build_macos.dependOn(&macos_install.step);
    build_all.dependOn(&macos_install.step);
}
