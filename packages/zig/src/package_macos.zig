const std = @import("std");
const io_context = @import("io_context.zig");

/// macOS Packaging
/// Supports .app bundle creation, DMG, and PKG installer
pub const MacOSPackager = struct {
    allocator: std.mem.Allocator,
    app_name: []const u8,
    version: []const u8,
    bundle_id: []const u8,
    description: []const u8,
    author: []const u8,
    copyright: []const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        app_name: []const u8,
        version: []const u8,
        bundle_id: []const u8,
        description: []const u8,
        author: []const u8,
        copyright: []const u8,
    ) MacOSPackager {
        return .{
            .allocator = allocator,
            .app_name = app_name,
            .version = version,
            .bundle_id = bundle_id,
            .description = description,
            .author = author,
            .copyright = copyright,
        };
    }

    /// Create .app bundle
    pub fn createAppBundle(self: *MacOSPackager, binary_path: []const u8, output_dir: []const u8) ![]u8 {
        std.debug.print("Creating .app bundle...\n", .{});

        const app_bundle = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.app",
            .{ output_dir, self.app_name },
        );

        try self.createAppBundleStructure(app_bundle, binary_path);
        try self.generateInfoPlist(app_bundle);

        std.debug.print("App bundle created: {s}\n", .{app_bundle});
        return app_bundle;
    }

    fn createAppBundleStructure(self: *MacOSPackager, app_bundle: []const u8, binary_path: []const u8) !void {
        const io = io_context.get();
        const cwd = io_context.cwd();

        // Create directory structure
        const dirs = [_][]const u8{
            app_bundle,
            try std.fmt.allocPrint(self.allocator, "{s}/Contents", .{app_bundle}),
            try std.fmt.allocPrint(self.allocator, "{s}/Contents/MacOS", .{app_bundle}),
            try std.fmt.allocPrint(self.allocator, "{s}/Contents/Resources", .{app_bundle}),
        };

        for (dirs) |dir| {
            defer if (dir.ptr != app_bundle.ptr) self.allocator.free(dir);
            cwd.createDir(io, dir, .default_dir) catch |err| {
                if (err != error.PathAlreadyExists) return err;
            };
        }

        // Copy binary
        const dest_binary = try std.fmt.allocPrint(
            self.allocator,
            "{s}/Contents/MacOS/{s}",
            .{ app_bundle, self.app_name },
        );
        defer self.allocator.free(dest_binary);

        try std.Io.Dir.copyFile(cwd, binary_path, cwd, dest_binary, io, .{});

        // Make binary executable
        const chmod_cmd = try std.fmt.allocPrint(self.allocator, "chmod +x {s}", .{dest_binary});
        defer self.allocator.free(chmod_cmd);

        var chmod_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", chmod_cmd }, self.allocator);
        _ = try chmod_proc.spawnAndWait();
    }

    fn generateInfoPlist(self: *MacOSPackager, app_bundle: []const u8) !void {
        const plist_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/Contents/Info.plist",
            .{app_bundle},
        );
        defer self.allocator.free(plist_path);

        const plist_content = try std.fmt.allocPrint(
            self.allocator,
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            \\<plist version="1.0">
            \\<dict>
            \\    <key>CFBundleDevelopmentRegion</key>
            \\    <string>en</string>
            \\    <key>CFBundleDisplayName</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleExecutable</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleIdentifier</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleInfoDictionaryVersion</key>
            \\    <string>6.0</string>
            \\    <key>CFBundleName</key>
            \\    <string>{s}</string>
            \\    <key>CFBundlePackageType</key>
            \\    <string>APPL</string>
            \\    <key>CFBundleShortVersionString</key>
            \\    <string>{s}</string>
            \\    <key>CFBundleVersion</key>
            \\    <string>{s}</string>
            \\    <key>LSMinimumSystemVersion</key>
            \\    <string>11.0</string>
            \\    <key>NSHumanReadableCopyright</key>
            \\    <string>{s}</string>
            \\    <key>NSHighResolutionCapable</key>
            \\    <true/>
            \\    <key>NSSupportsAutomaticGraphicsSwitching</key>
            \\    <true/>
            \\</dict>
            \\</plist>
            \\
        ,
            .{
                self.app_name,
                self.app_name,
                self.bundle_id,
                self.app_name,
                self.version,
                self.version,
                self.copyright,
            },
        );
        defer self.allocator.free(plist_content);

        const io = io_context.get();
        const file = try io_context.cwd().createFile(io, plist_path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, plist_content);
    }

    /// Create DMG disk image
    pub fn createDMG(self: *MacOSPackager, app_bundle: []const u8, output_dir: []const u8) !void {
        std.debug.print("Creating DMG...\n", .{});

        const dmg_name = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.dmg",
            .{ output_dir, self.app_name, self.version },
        );
        defer self.allocator.free(dmg_name);

        // Create temporary DMG directory
        const temp_dmg_dir = try std.fmt.allocPrint(self.allocator, "{s}/dmg_temp", .{output_dir});
        defer self.allocator.free(temp_dmg_dir);

        const io = io_context.get();
        const d = io_context.cwd();
        d.createDir(io, temp_dmg_dir, .default_dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
        defer d.deleteTree(io, temp_dmg_dir) catch {};

        // Copy app bundle to temp directory
        const dest_app = try std.fmt.allocPrint(self.allocator, "{s}/{s}.app", .{ temp_dmg_dir, self.app_name });
        defer self.allocator.free(dest_app);

        const cp_cmd = try std.fmt.allocPrint(self.allocator, "cp -R {s} {s}", .{ app_bundle, dest_app });
        defer self.allocator.free(cp_cmd);

        var cp_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", cp_cmd }, self.allocator);
        _ = try cp_proc.spawnAndWait();

        // Create Applications symlink
        const apps_link = try std.fmt.allocPrint(self.allocator, "{s}/Applications", .{temp_dmg_dir});
        defer self.allocator.free(apps_link);

        const ln_cmd = try std.fmt.allocPrint(self.allocator, "ln -s /Applications {s}", .{apps_link});
        defer self.allocator.free(ln_cmd);

        var ln_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", ln_cmd }, self.allocator);
        _ = try ln_proc.spawnAndWait();

        // Create DMG
        const dmg_cmd = try std.fmt.allocPrint(
            self.allocator,
            "hdiutil create -volname {s} -srcfolder {s} -ov -format UDZO {s}",
            .{ self.app_name, temp_dmg_dir, dmg_name },
        );
        defer self.allocator.free(dmg_cmd);

        var dmg_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", dmg_cmd }, self.allocator);
        const result = try dmg_proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            return error.DMGCreationFailed;
        }

        std.debug.print("DMG created: {s}\n", .{dmg_name});
    }

    /// Create PKG installer
    pub fn createPKG(self: *MacOSPackager, app_bundle: []const u8, output_dir: []const u8) !void {
        std.debug.print("Creating PKG installer...\n", .{});

        const pkg_name = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.pkg",
            .{ output_dir, self.app_name, self.version },
        );
        defer self.allocator.free(pkg_name);

        const pkg_cmd = try std.fmt.allocPrint(
            self.allocator,
            "pkgbuild --root {s} --identifier {s} --version {s} --install-location /Applications/{s}.app {s}",
            .{ app_bundle, self.bundle_id, self.version, self.app_name, pkg_name },
        );
        defer self.allocator.free(pkg_cmd);

        var pkg_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", pkg_cmd }, self.allocator);
        const result = try pkg_proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            return error.PKGCreationFailed;
        }

        std.debug.print("PKG created: {s}\n", .{pkg_name});
    }

    /// Code sign the app bundle
    pub fn codeSign(self: *MacOSPackager, app_bundle: []const u8, identity: []const u8) !void {
        std.debug.print("Code signing app bundle...\n", .{});

        const sign_cmd = try std.fmt.allocPrint(
            self.allocator,
            "codesign --force --deep --sign \"{s}\" {s}",
            .{ identity, app_bundle },
        );
        defer self.allocator.free(sign_cmd);

        var sign_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", sign_cmd }, self.allocator);
        const result = try sign_proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            return error.CodeSigningFailed;
        }

        std.debug.print("Code signing successful\n", .{});
    }

    /// Notarize the app bundle with Apple
    pub fn notarize(
        self: *MacOSPackager,
        app_bundle_or_dmg: []const u8,
        apple_id: []const u8,
        password: []const u8,
        team_id: []const u8,
    ) !void {
        std.debug.print("Notarizing with Apple...\n", .{});

        // Create ZIP for notarization
        const zip_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}.zip",
            .{app_bundle_or_dmg},
        );
        defer self.allocator.free(zip_path);

        const zip_cmd = try std.fmt.allocPrint(
            self.allocator,
            "ditto -c -k --keepParent {s} {s}",
            .{ app_bundle_or_dmg, zip_path },
        );
        defer self.allocator.free(zip_cmd);

        var zip_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", zip_cmd }, self.allocator);
        _ = try zip_proc.spawnAndWait();
        defer io_context.cwd().deleteFile(io_context.get(), zip_path) catch {};

        // Submit for notarization
        const notarize_cmd = try std.fmt.allocPrint(
            self.allocator,
            "xcrun notarytool submit {s} --apple-id {s} --password {s} --team-id {s} --wait",
            .{ zip_path, apple_id, password, team_id },
        );
        defer self.allocator.free(notarize_cmd);

        var notarize_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", notarize_cmd }, self.allocator);
        const result = try notarize_proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            std.debug.print("Notarization failed. Check your credentials and try again.\n", .{});
            return error.NotarizationFailed;
        }

        // Staple the notarization ticket
        const staple_cmd = try std.fmt.allocPrint(
            self.allocator,
            "xcrun stapler staple {s}",
            .{app_bundle_or_dmg},
        );
        defer self.allocator.free(staple_cmd);

        var staple_proc = std.process.Child.init(&[_][]const u8{ "sh", "-c", staple_cmd }, self.allocator);
        _ = try staple_proc.spawnAndWait();

        std.debug.print("Notarization successful\n", .{});
    }

    /// Full packaging workflow: bundle -> sign -> dmg -> notarize
    pub fn packageComplete(
        self: *MacOSPackager,
        binary_path: []const u8,
        output_dir: []const u8,
        signing_identity: ?[]const u8,
        apple_id: ?[]const u8,
        app_password: ?[]const u8,
        team_id: ?[]const u8,
    ) !void {
        // Create app bundle
        const app_bundle = try self.createAppBundle(binary_path, output_dir);
        defer self.allocator.free(app_bundle);

        // Code sign if identity provided
        if (signing_identity) |identity| {
            try self.codeSign(app_bundle, identity);
        }

        // Create DMG
        try self.createDMG(app_bundle, output_dir);

        // Notarize if credentials provided
        if (apple_id != null and app_password != null and team_id != null) {
            const dmg_path = try std.fmt.allocPrint(
                self.allocator,
                "{s}/{s}-{s}.dmg",
                .{ output_dir, self.app_name, self.version },
            );
            defer self.allocator.free(dmg_path);

            try self.notarize(dmg_path, apple_id.?, app_password.?, team_id.?);
        }

        std.debug.print("\nPackaging complete!\n", .{});
    }
};

// Tests
test "macOS packager init" {
    const allocator = std.testing.allocator;
    const packager = MacOSPackager.init(
        allocator,
        "TestApp",
        "1.0.0",
        "com.test.app",
        "Test application",
        "Test Author",
        "Copyright 2025 Test Author",
    );

    try std.testing.expectEqualStrings("TestApp", packager.app_name);
    try std.testing.expectEqualStrings("1.0.0", packager.version);
    try std.testing.expectEqualStrings("com.test.app", packager.bundle_id);
}
