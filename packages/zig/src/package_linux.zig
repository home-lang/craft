const std = @import("std");
const io_context = @import("io_context.zig");

/// Linux Packaging
/// Supports DEB, RPM, and AppImage formats
pub const LinuxPackager = struct {
    allocator: std.mem.Allocator,
    app_name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    license: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        app_name: []const u8,
        version: []const u8,
        description: []const u8,
        author: []const u8,
        license: []const u8,
    ) LinuxPackager {
        return .{
            .allocator = allocator,
            .app_name = app_name,
            .version = version,
            .description = description,
            .author = author,
            .license = license,
        };
    }

    /// Create DEB package
    pub fn createDEB(self: *LinuxPackager, binary_path: []const u8, output_dir: []const u8) !void {
        std.debug.print("Creating DEB package...\n", .{});

        const package_name = try std.fmt.allocPrint(
            self.allocator,
            "{s}_{s}_amd64.deb",
            .{ self.app_name, self.version },
        );
        defer self.allocator.free(package_name);

        // Create package directory structure
        const pkg_dir = try std.fmt.allocPrint(self.allocator, "{s}/deb_build", .{output_dir});
        defer self.allocator.free(pkg_dir);

        try self.createDEBStructure(pkg_dir, binary_path);
        try self.generateDEBControl(pkg_dir);
        try self.buildDEB(pkg_dir, output_dir, package_name);

        std.debug.print("DEB package created: {s}/{s}\n", .{ output_dir, package_name });
    }

    fn createDEBStructure(self: *LinuxPackager, pkg_dir: []const u8, binary_path: []const u8) !void {
        const io = io_context.get();
        const cwd = io_context.cwd();

        // Create directories
        const dirs = [_][]const u8{
            try std.fmt.allocPrint(self.allocator, "{s}/DEBIAN", .{pkg_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/usr/bin", .{pkg_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/usr/share/applications", .{pkg_dir}),
            try std.fmt.allocPrint(self.allocator, "{s}/usr/share/icons/hicolor/256x256/apps", .{pkg_dir}),
        };

        for (dirs) |dir| {
            defer self.allocator.free(dir);
            cwd.createDir(io, dir, .default_dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }

        // Copy binary
        const dest_binary = try std.fmt.allocPrint(self.allocator, "{s}/usr/bin/{s}", .{ pkg_dir, self.app_name });
        defer self.allocator.free(dest_binary);

        try std.Io.Dir.copyFile(cwd, binary_path, cwd, dest_binary, io, .{});

        // Make binary executable
        const chmod_cmd = try std.fmt.allocPrint(self.allocator, "chmod +x {s}", .{dest_binary});
        defer self.allocator.free(chmod_cmd);

        var chmod_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", chmod_cmd }, self.allocator);
        _ = try chmod_proc.spawnAndWait();

        // Create desktop file
        try self.generateDesktopFile(pkg_dir);
    }

    fn generateDEBControl(self: *LinuxPackager, pkg_dir: []const u8) !void {
        const control_path = try std.fmt.allocPrint(self.allocator, "{s}/DEBIAN/control", .{pkg_dir});
        defer self.allocator.free(control_path);

        const control_content = try std.fmt.allocPrint(
            self.allocator,
            \\Package: {s}
            \\Version: {s}
            \\Section: utils
            \\Priority: optional
            \\Architecture: amd64
            \\Maintainer: {s}
            \\Description: {s}
            \\
        ,
            .{ self.app_name, self.version, self.author, self.description },
        );
        defer self.allocator.free(control_content);

        const io = io_context.get();
        const file = try io_context.cwd().createFile(io, control_path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, control_content);
    }

    fn generateDesktopFile(self: *LinuxPackager, pkg_dir: []const u8) !void {
        const desktop_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/usr/share/applications/{s}.desktop",
            .{ pkg_dir, self.app_name },
        );
        defer self.allocator.free(desktop_path);

        const desktop_content = try std.fmt.allocPrint(
            self.allocator,
            \\[Desktop Entry]
            \\Name={s}
            \\Comment={s}
            \\Exec={s}
            \\Icon={s}
            \\Terminal=false
            \\Type=Application
            \\Categories=Utility;
            \\
        ,
            .{ self.app_name, self.description, self.app_name, self.app_name },
        );
        defer self.allocator.free(desktop_content);

        const io = io_context.get();
        const file = try io_context.cwd().createFile(io, desktop_path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, desktop_content);
    }

    fn buildDEB(self: *LinuxPackager, pkg_dir: []const u8, output_dir: []const u8, package_name: []const u8) !void {
        const cmd = try std.fmt.allocPrint(
            self.allocator,
            "dpkg-deb --build {s} {s}/{s}",
            .{ pkg_dir, output_dir, package_name },
        );
        defer self.allocator.free(cmd);

        var proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", cmd }, self.allocator);
        const result = try proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            return error.DEBBuildFailed;
        }
    }

    /// Create RPM package
    pub fn createRPM(self: *LinuxPackager, binary_path: []const u8, output_dir: []const u8) !void {
        std.debug.print("Creating RPM package...\n", .{});

        const spec_file = try self.generateRPMSpec(binary_path, output_dir);
        defer self.allocator.free(spec_file);

        const cmd = try std.fmt.allocPrint(
            self.allocator,
            "rpmbuild -bb {s}",
            .{spec_file},
        );
        defer self.allocator.free(cmd);

        var proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", cmd }, self.allocator);
        const result = try proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            std.debug.print("RPM build failed. Ensure rpmbuild is installed.\n", .{});
            return error.RPMBuildFailed;
        }

        std.debug.print("RPM package created\n", .{});
    }

    fn generateRPMSpec(self: *LinuxPackager, binary_path: []const u8, output_dir: []const u8) ![]u8 {
        const spec_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.spec",
            .{ output_dir, self.app_name },
        );

        const spec_content = try std.fmt.allocPrint(
            self.allocator,
            \\Name: {s}
            \\Version: {s}
            \\Release: 1
            \\Summary: {s}
            \\License: {s}
            \\
            \\%description
            \\{s}
            \\
            \\%install
            \\mkdir -p %{{buildroot}}/usr/bin
            \\cp {s} %{{buildroot}}/usr/bin/{s}
            \\chmod +x %{{buildroot}}/usr/bin/{s}
            \\
            \\%files
            \\/usr/bin/{s}
            \\
            \\%changelog
            \\* $(date "+%a %b %d %Y") {s}
            \\- Initial release
            \\
        ,
            .{
                self.app_name,
                self.version,
                self.description,
                self.license,
                self.description,
                binary_path,
                self.app_name,
                self.app_name,
                self.app_name,
                self.author,
            },
        );
        defer self.allocator.free(spec_content);

        const io = io_context.get();
        const file = try io_context.cwd().createFile(io, spec_path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, spec_content);

        return spec_path;
    }

    /// Create AppImage
    pub fn createAppImage(self: *LinuxPackager, binary_path: []const u8, output_dir: []const u8) !void {
        std.debug.print("Creating AppImage...\n", .{});

        const appdir = try std.fmt.allocPrint(self.allocator, "{s}/{s}.AppDir", .{ output_dir, self.app_name });
        defer self.allocator.free(appdir);

        try self.createAppImageStructure(appdir, binary_path);
        try self.buildAppImage(appdir, output_dir);

        std.debug.print("AppImage created\n", .{});
    }

    fn createAppImageStructure(self: *LinuxPackager, appdir: []const u8, binary_path: []const u8) !void {
        const io = io_context.get();
        const cwd = io_context.cwd();

        // Create AppDir structure
        const dirs = [_][]const u8{
            appdir,
            try std.fmt.allocPrint(self.allocator, "{s}/usr/bin", .{appdir}),
            try std.fmt.allocPrint(self.allocator, "{s}/usr/share/applications", .{appdir}),
            try std.fmt.allocPrint(self.allocator, "{s}/usr/share/icons/hicolor/256x256/apps", .{appdir}),
        };

        for (dirs) |dir| {
            defer if (dir.ptr != appdir.ptr) self.allocator.free(dir);
            cwd.createDir(io, dir, .default_dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }

        // Copy binary
        const dest_binary = try std.fmt.allocPrint(self.allocator, "{s}/usr/bin/{s}", .{ appdir, self.app_name });
        defer self.allocator.free(dest_binary);

        try std.Io.Dir.copyFile(cwd, binary_path, cwd, dest_binary, io, .{});

        // Create AppRun script
        try self.generateAppRun(appdir);

        // Create desktop file
        const desktop_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/usr/share/applications/{s}.desktop",
            .{ appdir, self.app_name },
        );
        defer self.allocator.free(desktop_path);

        try self.generateDesktopFile(appdir);

        // Copy desktop file to root
        const root_desktop = try std.fmt.allocPrint(self.allocator, "{s}/{s}.desktop", .{ appdir, self.app_name });
        defer self.allocator.free(root_desktop);

        try std.Io.Dir.copyFile(cwd, desktop_path, cwd, root_desktop, io, .{});
    }

    fn generateAppRun(self: *LinuxPackager, appdir: []const u8) !void {
        const apprun_path = try std.fmt.allocPrint(self.allocator, "{s}/AppRun", .{appdir});
        defer self.allocator.free(apprun_path);

        const apprun_content = try std.fmt.allocPrint(
            self.allocator,
            \\#!/bin/sh
            \\SELF=$(readlink -f "$0")
            \\HERE=${{SELF%/*}}
            \\export PATH="${{HERE}}/usr/bin:${{PATH}}"
            \\exec "${{HERE}}/usr/bin/{s}" "$@"
            \\
        ,
            .{self.app_name},
        );
        defer self.allocator.free(apprun_content);

        const io = io_context.get();
        const file = try io_context.cwd().createFile(io, apprun_path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, apprun_content);

        // Make AppRun executable
        const chmod_cmd = try std.fmt.allocPrint(self.allocator, "chmod +x {s}", .{apprun_path});
        defer self.allocator.free(chmod_cmd);

        var chmod_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", chmod_cmd }, self.allocator);
        _ = try chmod_proc.spawnAndWait();
    }

    fn buildAppImage(self: *LinuxPackager, appdir: []const u8, output_dir: []const u8) !void {
        // Download appimagetool if not present
        const appimagetool_path = try self.downloadAppImageTool(output_dir);
        defer self.allocator.free(appimagetool_path);

        const output_name = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}-x86_64.AppImage",
            .{ output_dir, self.app_name, self.version },
        );
        defer self.allocator.free(output_name);

        const cmd = try std.fmt.allocPrint(
            self.allocator,
            "{s} {s} {s}",
            .{ appimagetool_path, appdir, output_name },
        );
        defer self.allocator.free(cmd);

        var proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", cmd }, self.allocator);
        const result = try proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            return error.AppImageBuildFailed;
        }
    }

    fn downloadAppImageTool(self: *LinuxPackager, output_dir: []const u8) ![]u8 {
        const tool_path = try std.fmt.allocPrint(self.allocator, "{s}/appimagetool-x86_64.AppImage", .{output_dir});

        // Check if already exists
        io_context.cwd().access(io_context.get(), tool_path, .{}) catch {
            // Download appimagetool
            std.debug.print("Downloading appimagetool...\n", .{});

            const url = "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage";
            const cmd = try std.fmt.allocPrint(
                self.allocator,
                "curl -L -o {s} {s} && chmod +x {s}",
                .{ tool_path, url, tool_path },
            );
            defer self.allocator.free(cmd);

            var proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", cmd }, self.allocator);
            _ = try proc.spawnAndWait();
        };

        return tool_path;
    }
};

// Tests
test "Linux packager init" {
    const allocator = std.testing.allocator;
    const packager = LinuxPackager.init(
        allocator,
        "TestApp",
        "1.0.0",
        "Test application",
        "Test Author",
        "MIT",
    );

    try std.testing.expectEqualStrings("TestApp", packager.app_name);
    try std.testing.expectEqualStrings("1.0.0", packager.version);
}
