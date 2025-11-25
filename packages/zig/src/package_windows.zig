const std = @import("std");

/// Windows Packaging
/// Supports MSI installer creation using WiX Toolset

pub const WindowsPackager = struct {
    allocator: std.mem.Allocator,
    app_name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    license: []const u8,
    upgrade_code: []const u8, // GUID for upgrade tracking

    pub fn init(
        allocator: std.mem.Allocator,
        app_name: []const u8,
        version: []const u8,
        description: []const u8,
        author: []const u8,
        license: []const u8,
        upgrade_code: []const u8,
    ) WindowsPackager {
        return .{
            .allocator = allocator,
            .app_name = app_name,
            .version = version,
            .description = description,
            .author = author,
            .license = license,
            .upgrade_code = upgrade_code,
        };
    }

    /// Create MSI installer using WiX
    pub fn createMSI(self: *WindowsPackager, binary_path: []const u8, output_dir: []const u8) !void {
        std.debug.print("Creating MSI installer...\n", .{});

        // Generate WiX source file
        const wxs_file = try self.generateWiXSource(binary_path, output_dir);
        defer self.allocator.free(wxs_file);

        // Compile WiX source
        const wixobj_file = try self.compileWiX(wxs_file, output_dir);
        defer self.allocator.free(wixobj_file);

        // Link to create MSI
        try self.linkMSI(wixobj_file, output_dir);

        std.debug.print("MSI installer created\n", .{});
    }

    fn generateWiXSource(self: *WindowsPackager, binary_path: []const u8, output_dir: []const u8) ![]u8 {
        const wxs_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.wxs",
            .{ output_dir, self.app_name },
        );

        const product_id = try self.generateGUID();
        defer self.allocator.free(product_id);

        const component_id = try self.generateGUID();
        defer self.allocator.free(component_id);

        const wxs_content = try std.fmt.allocPrint(
            self.allocator,
            \\<?xml version="1.0" encoding="UTF-8"?>
            \\<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
            \\  <Product Id="{s}"
            \\           Name="{s}"
            \\           Language="1033"
            \\           Version="{s}"
            \\           Manufacturer="{s}"
            \\           UpgradeCode="{s}">
            \\    <Package InstallerVersion="200" Compressed="yes" InstallScope="perMachine" />
            \\
            \\    <MajorUpgrade DowngradeErrorMessage="A newer version of [{s}] is already installed." />
            \\    <MediaTemplate EmbedCab="yes" />
            \\
            \\    <Feature Id="ProductFeature" Title="{s}" Level="1">
            \\      <ComponentGroupRef Id="ProductComponents" />
            \\    </Feature>
            \\
            \\    <Directory Id="TARGETDIR" Name="SourceDir">
            \\      <Directory Id="ProgramFilesFolder">
            \\        <Directory Id="INSTALLFOLDER" Name="{s}" />
            \\      </Directory>
            \\      <Directory Id="ProgramMenuFolder">
            \\        <Directory Id="ApplicationProgramsFolder" Name="{s}"/>
            \\      </Directory>
            \\    </Directory>
            \\
            \\    <DirectoryRef Id="INSTALLFOLDER">
            \\      <Component Id="ProductComponent" Guid="{s}">
            \\        <File Id="MainExecutable" Source="{s}" KeyPath="yes" Checksum="yes" />
            \\      </Component>
            \\    </DirectoryRef>
            \\
            \\    <DirectoryRef Id="ApplicationProgramsFolder">
            \\      <Component Id="ApplicationShortcut" Guid="*">
            \\        <Shortcut Id="ApplicationStartMenuShortcut"
            \\                 Name="{s}"
            \\                 Description="{s}"
            \\                 Target="[#MainExecutable]"
            \\                 WorkingDirectory="INSTALLFOLDER"/>
            \\        <RemoveFolder Id="CleanUpShortCut" Directory="ApplicationProgramsFolder" On="uninstall"/>
            \\        <RegistryValue Root="HKCU" Key="Software\[Manufacturer]\[ProductName]" Name="installed" Type="integer" Value="1" KeyPath="yes"/>
            \\      </Component>
            \\    </DirectoryRef>
            \\
            \\    <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
            \\      <ComponentRef Id="ProductComponent" />
            \\      <ComponentRef Id="ApplicationShortcut" />
            \\    </ComponentGroup>
            \\  </Product>
            \\</Wix>
            \\
        ,
            .{
                product_id,
                self.app_name,
                self.version,
                self.author,
                self.upgrade_code,
                self.app_name,
                self.app_name,
                self.app_name,
                self.app_name,
                component_id,
                binary_path,
                self.app_name,
                self.description,
            },
        );
        defer self.allocator.free(wxs_content);

        const file = try std.fs.cwd().createFile(wxs_path, .{});
        defer file.close();

        try file.writeAll(wxs_content);

        return wxs_path;
    }

    fn compileWiX(self: *WindowsPackager, wxs_file: []const u8, output_dir: []const u8) ![]u8 {
        const wixobj_file = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}.wixobj",
            .{ output_dir, self.app_name },
        );

        const cmd = try std.fmt.allocPrint(
            self.allocator,
            "candle.exe -nologo -out {s} {s}",
            .{ wixobj_file, wxs_file },
        );
        defer self.allocator.free(cmd);

        var proc = std.process.Child.init(&[_][]const u8{ "cmd.exe", "/C", cmd }, self.allocator);
        const result = try proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            std.debug.print("WiX compilation failed. Ensure WiX Toolset is installed.\n", .{});
            return error.WiXCompilationFailed;
        }

        return wixobj_file;
    }

    fn linkMSI(self: *WindowsPackager, wixobj_file: []const u8, output_dir: []const u8) !void {
        const msi_file = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}-{s}.msi",
            .{ output_dir, self.app_name, self.version },
        );
        defer self.allocator.free(msi_file);

        const cmd = try std.fmt.allocPrint(
            self.allocator,
            "light.exe -nologo -ext WixUIExtension -out {s} {s}",
            .{ msi_file, wixobj_file },
        );
        defer self.allocator.free(cmd);

        var proc = std.process.Child.init(&[_][]const u8{ "cmd.exe", "/C", cmd }, self.allocator);
        const result = try proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            return error.WiXLinkingFailed;
        }
    }

    fn generateGUID(self: *WindowsPackager) ![]u8 {
        // Simple GUID generation (for production, use a proper UUID library)
        var rng = std.rand.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));

        const guid = try std.fmt.allocPrint(
            self.allocator,
            "{X:0>8}-{X:0>4}-{X:0>4}-{X:0>4}-{X:0>12}",
            .{
                rng.random().int(u32),
                rng.random().int(u16),
                rng.random().int(u16),
                rng.random().int(u16),
                rng.random().int(u48),
            },
        );

        return guid;
    }

    /// Sign the MSI with code signing certificate
    pub fn signMSI(self: *WindowsPackager, msi_path: []const u8, cert_path: []const u8, password: []const u8) !void {
        std.debug.print("Signing MSI...\n", .{});

        const cmd = try std.fmt.allocPrint(
            self.allocator,
            "signtool.exe sign /f {s} /p {s} /t http://timestamp.digicert.com {s}",
            .{ cert_path, password, msi_path },
        );
        defer self.allocator.free(cmd);

        var proc = std.process.Child.init(&[_][]const u8{ "cmd.exe", "/C", cmd }, self.allocator);
        const result = try proc.spawnAndWait();

        if (result != .Exited or result.Exited != 0) {
            return error.CodeSigningFailed;
        }

        std.debug.print("MSI signed successfully\n", .{});
    }
};

/// Create portable ZIP package for Windows
pub fn createPortableZIP(
    allocator: std.mem.Allocator,
    app_name: []const u8,
    version: []const u8,
    binary_path: []const u8,
    output_dir: []const u8,
) !void {
    std.debug.print("Creating portable ZIP package...\n", .{});

    const zip_name = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}-{s}-portable.zip",
        .{ output_dir, app_name, version },
    );
    defer allocator.free(zip_name);

    // Create temporary directory
    const temp_dir = try std.fmt.allocPrint(allocator, "{s}/portable_temp", .{output_dir});
    defer allocator.free(temp_dir);

    std.fs.cwd().makeDir(temp_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
    defer std.fs.cwd().deleteTree(temp_dir) catch {};

    // Copy binary to temp directory
    const dest_binary = try std.fmt.allocPrint(allocator, "{s}/{s}.exe", .{ temp_dir, app_name });
    defer allocator.free(dest_binary);

    try std.fs.cwd().copyFile(binary_path, std.fs.cwd(), dest_binary, .{});

    // Create README
    const readme_path = try std.fmt.allocPrint(allocator, "{s}/README.txt", .{temp_dir});
    defer allocator.free(readme_path);

    const readme_content = try std.fmt.allocPrint(
        allocator,
        \\{s} - Portable Version
        \\
        \\To run the application, simply double-click {s}.exe
        \\
        \\Version: {s}
        \\
    ,
        .{ app_name, app_name, version },
    );
    defer allocator.free(readme_content);

    const readme_file = try std.fs.cwd().createFile(readme_path, .{});
    defer readme_file.close();
    try readme_file.writeAll(readme_content);

    // Create ZIP using PowerShell
    const cmd = try std.fmt.allocPrint(
        allocator,
        "powershell Compress-Archive -Path {s}\\* -DestinationPath {s} -Force",
        .{ temp_dir, zip_name },
    );
    defer allocator.free(cmd);

    var proc = std.process.Child.init(&[_][]const u8{ "cmd.exe", "/C", cmd }, allocator);
    const result = try proc.spawnAndWait();

    if (result != .Exited or result.Exited != 0) {
        return error.ZIPCreationFailed;
    }

    std.debug.print("Portable ZIP created: {s}\n", .{zip_name});
}

// Tests
test "Windows packager init" {
    const allocator = std.testing.allocator;
    const packager = WindowsPackager.init(
        allocator,
        "TestApp",
        "1.0.0",
        "Test application",
        "Test Author",
        "MIT",
        "12345678-1234-1234-1234-123456789012",
    );

    try std.testing.expectEqualStrings("TestApp", packager.app_name);
    try std.testing.expectEqualStrings("1.0.0", packager.version);
}

test "GUID generation" {
    const allocator = std.testing.allocator;
    var packager = WindowsPackager.init(
        allocator,
        "TestApp",
        "1.0.0",
        "Test application",
        "Test Author",
        "MIT",
        "12345678-1234-1234-1234-123456789012",
    );

    const guid = try packager.generateGUID();
    defer allocator.free(guid);

    // GUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (36 chars with dashes)
    try std.testing.expect(guid.len == 36);
    try std.testing.expect(guid[8] == '-');
    try std.testing.expect(guid[13] == '-');
    try std.testing.expect(guid[18] == '-');
    try std.testing.expect(guid[23] == '-');
}
