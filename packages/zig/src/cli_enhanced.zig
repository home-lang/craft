const std = @import("std");
const io_context = @import("io_context.zig");
const builtin = @import("builtin");

/// Enhanced CLI with project scaffolding and templates
/// Provides tools for creating, managing, and building Craft projects

pub const CLIError = error{
    InvalidCommand,
    InvalidTemplate,
    ProjectAlreadyExists,
    InvalidProjectName,
    MissingArgument,
    FileSystemError,
};

/// Project template types
pub const ProjectTemplate = enum {
    vanilla,
    react,
    vue,
    svelte,
    solid,
    preact,
    alpine,
    htmx,

    pub fn toString(self: ProjectTemplate) []const u8 {
        return switch (self) {
            .vanilla => "vanilla",
            .react => "react",
            .vue => "vue",
            .svelte => "svelte",
            .solid => "solid",
            .preact => "preact",
            .alpine => "alpine",
            .htmx => "htmx",
        };
    }

    pub fn fromString(s: []const u8) ?ProjectTemplate {
        if (std.mem.eql(u8, s, "vanilla")) return .vanilla;
        if (std.mem.eql(u8, s, "react")) return .react;
        if (std.mem.eql(u8, s, "vue")) return .vue;
        if (std.mem.eql(u8, s, "svelte")) return .svelte;
        if (std.mem.eql(u8, s, "solid")) return .solid;
        if (std.mem.eql(u8, s, "preact")) return .preact;
        if (std.mem.eql(u8, s, "alpine")) return .alpine;
        if (std.mem.eql(u8, s, "htmx")) return .htmx;
        return null;
    }

    pub fn description(self: ProjectTemplate) []const u8 {
        return switch (self) {
            .vanilla => "Plain HTML, CSS, and JavaScript",
            .react => "React with TypeScript",
            .vue => "Vue 3 with TypeScript",
            .svelte => "Svelte with TypeScript",
            .solid => "Solid.js with TypeScript",
            .preact => "Preact with TypeScript",
            .alpine => "Alpine.js with Tailwind CSS",
            .htmx => "HTMX with hyperscript",
        };
    }
};

/// CLI Command
pub const Command = enum {
    init,
    dev,
    build,
    package,
    @"test",
    clean,
    help,
    version,

    pub fn fromString(s: []const u8) ?Command {
        if (std.mem.eql(u8, s, "init")) return .init;
        if (std.mem.eql(u8, s, "dev")) return .dev;
        if (std.mem.eql(u8, s, "build")) return .build;
        if (std.mem.eql(u8, s, "package")) return .package;
        if (std.mem.eql(u8, s, "test")) return .@"test";
        if (std.mem.eql(u8, s, "clean")) return .clean;
        if (std.mem.eql(u8, s, "help") or std.mem.eql(u8, s, "--help") or std.mem.eql(u8, s, "-h")) return .help;
        if (std.mem.eql(u8, s, "version") or std.mem.eql(u8, s, "--version") or std.mem.eql(u8, s, "-v")) return .version;
        return null;
    }
};

/// CLI configuration
pub const CLIConfig = struct {
    command: Command,
    project_name: ?[]const u8 = null,
    template: ProjectTemplate = .vanilla,
    output_dir: ?[]const u8 = null,
    platform: ?[]const u8 = null,
    verbose: bool = false,
    force: bool = false,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *CLIConfig) void {
        if (self.project_name) |name| self.allocator.free(name);
        if (self.output_dir) |dir| self.allocator.free(dir);
        if (self.platform) |plat| self.allocator.free(plat);
    }
};

/// Enhanced CLI
pub const EnhancedCLI = struct {
    allocator: std.mem.Allocator,
    config: CLIConfig,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);

        if (args.len < 2) {
            printUsage();
            return CLIError.InvalidCommand;
        }

        const command_str = args[1];
        const command = Command.fromString(command_str) orelse {
            std.debug.print("Error: Unknown command '{s}'\n\n", .{command_str});
            printUsage();
            return CLIError.InvalidCommand;
        };

        var config = CLIConfig{
            .command = command,
            .allocator = allocator,
        };

        // Parse remaining arguments based on command
        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--template") or std.mem.eql(u8, arg, "-t")) {
                i += 1;
                if (i >= args.len) return CLIError.MissingArgument;
                config.template = ProjectTemplate.fromString(args[i]) orelse {
                    std.debug.print("Error: Invalid template '{s}'\n", .{args[i]});
                    return CLIError.InvalidTemplate;
                };
            } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
                i += 1;
                if (i >= args.len) return CLIError.MissingArgument;
                config.output_dir = try allocator.dupe(u8, args[i]);
            } else if (std.mem.eql(u8, arg, "--platform") or std.mem.eql(u8, arg, "-p")) {
                i += 1;
                if (i >= args.len) return CLIError.MissingArgument;
                config.platform = try allocator.dupe(u8, args[i]);
            } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
                config.verbose = true;
            } else if (std.mem.eql(u8, arg, "--force") or std.mem.eql(u8, arg, "-f")) {
                config.force = true;
            } else if (!std.mem.startsWith(u8, arg, "-")) {
                // Positional argument (project name)
                if (config.project_name == null) {
                    config.project_name = try allocator.dupe(u8, arg);
                }
            }
        }

        return Self{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Self) void {
        self.config.deinit();
    }

    pub fn run(self: *Self) !void {
        switch (self.config.command) {
            .init => try self.runInit(),
            .dev => try self.runDev(),
            .build => try self.runBuild(),
            .package => try self.runPackage(),
            .@"test" => try self.runTest(),
            .clean => try self.runClean(),
            .help => printHelp(),
            .version => printVersion(),
        }
    }

    fn runInit(self: *Self) !void {
        const project_name = self.config.project_name orelse {
            std.debug.print("Error: Project name required\n", .{});
            std.debug.print("Usage: craft init <project-name> [options]\n", .{});
            return CLIError.MissingArgument;
        };

        if (self.config.verbose) {
            std.debug.print("Creating project: {s}\n", .{project_name});
            std.debug.print("Template: {s}\n", .{self.config.template.toString()});
        }

        // Validate project name
        if (!isValidProjectName(project_name)) {
            std.debug.print("Error: Invalid project name '{s}'\n", .{project_name});
            std.debug.print("Project name must contain only letters, numbers, hyphens, and underscores\n", .{});
            return CLIError.InvalidProjectName;
        }

        // Check if directory already exists
        const io = io_context.get();
        const cwd = io_context.cwd();
        const project_dir = cwd.openDir(io, project_name, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // Directory doesn't exist, we can proceed
                try self.createProject(project_name);
                return;
            }
            return err;
        };
        defer project_dir.close(io);

        if (!self.config.force) {
            std.debug.print("Error: Directory '{s}' already exists\n", .{project_name});
            std.debug.print("Use --force to overwrite\n", .{});
            return CLIError.ProjectAlreadyExists;
        }

        try self.createProject(project_name);
    }

    fn createProject(self: *Self, name: []const u8) !void {
        const io = io_context.get();
        const cwd = io_context.cwd();

        // Create project directory
        try cwd.createDir(io, name, .default_dir);
        var project_dir = try cwd.openDir(io, name, .{});
        defer project_dir.close(io);

        std.debug.print("✓ Created directory: {s}\n", .{name});

        // Create project structure based on template
        try self.createProjectStructure(&project_dir, name);

        std.debug.print("\n✨ Project '{s}' created successfully!\n\n", .{name});
        std.debug.print("Next steps:\n", .{});
        std.debug.print("  cd {s}\n", .{name});
        std.debug.print("  bun install\n", .{});
        std.debug.print("  craft dev\n\n", .{});
    }

    fn createProjectStructure(self: *Self, dir: *std.fs.Dir, name: []const u8) !void {
        const io = io_context.get();
        // Create standard directories
        try dir.createDir(io, "src", .default_dir);
        try dir.createDir(io, "public", .default_dir);
        try dir.createDir(io, "dist", .default_dir);

        std.debug.print("✓ Created project structure\n", .{});

        // Create package.json
        try self.createPackageJson(dir, name);

        // Create source files based on template
        try self.createTemplateFiles(dir);

        // Create craft.config.json
        try self.createCraftConfig(dir, name);

        // Create README.md
        try self.createReadme(dir, name);

        // Create .gitignore
        try self.createGitignore(dir);
    }

    fn createPackageJson(self: *Self, dir: *std.fs.Dir, name: []const u8) !void {
        const package_json = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "name": "{s}",
            \\  "version": "0.1.0",
            \\  "type": "module",
            \\  "scripts": {{
            \\    "dev": "craft dev",
            \\    "build": "craft build",
            \\    "package": "craft package"
            \\  }},
            \\  "dependencies": {{
            \\    "@craft-native/{s}": "latest"
            \\  }},
            \\  "devDependencies": {{
            \\    "typescript": "^5.3.0",
            \\    "vite": "^5.0.0"
            \\  }}
            \\}}
            \\
        , .{ name, self.config.template.toString() });
        defer self.allocator.free(package_json);

        const io = io_context.get();
        const file = try dir.createFile(io, "package.json", .{});
        defer file.close(io);
        try file.writeStreamingAll(io, package_json);

        std.debug.print("✓ Created package.json\n", .{});
    }

    fn createTemplateFiles(self: *Self, dir: *std.fs.Dir) !void {
        const io = io_context.get();
        var src_dir = try dir.openDir(io, "src", .{});
        defer src_dir.close(io);

        switch (self.config.template) {
            .vanilla => try self.createVanillaTemplate(&src_dir),
            .react => try self.createReactTemplate(&src_dir),
            .vue => try self.createVueTemplate(&src_dir),
            .svelte => try self.createSvelteTemplate(&src_dir),
            .solid => try self.createSolidTemplate(&src_dir),
            .preact => try self.createPreactTemplate(&src_dir),
            .alpine => try self.createAlpineTemplate(&src_dir),
            .htmx => try self.createHtmxTemplate(&src_dir),
        }

        std.debug.print("✓ Created template files\n", .{});
    }

    fn createVanillaTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const html =
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\  <meta charset="UTF-8">
            \\  <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\  <title>Craft App</title>
            \\  <link rel="stylesheet" href="style.css">
            \\</head>
            \\<body>
            \\  <div id="app">
            \\    <h1>Welcome to Craft</h1>
            \\    <p>Build desktop apps with web languages</p>
            \\  </div>
            \\  <script src="main.js"></script>
            \\</body>
            \\</html>
            \\
        ;

        const css =
            \\* {
            \\  margin: 0;
            \\  padding: 0;
            \\  box-sizing: border-box;
            \\}
            \\
            \\body {
            \\  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            \\  display: flex;
            \\  align-items: center;
            \\  justify-content: center;
            \\  min-height: 100vh;
            \\  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            \\}
            \\
            \\#app {
            \\  text-align: center;
            \\  color: white;
            \\}
            \\
            \\h1 {
            \\  font-size: 3rem;
            \\  margin-bottom: 1rem;
            \\}
            \\
            \\p {
            \\  font-size: 1.5rem;
            \\  opacity: 0.9;
            \\}
            \\
        ;

        const js =
            \\console.log('Craft app loaded!');
            \\
            \\document.addEventListener('DOMContentLoaded', () => {
            \\  console.log('App ready');
            \\});
            \\
        ;

        try writeFile(dir, "index.html", html);
        try writeFile(dir, "style.css", css);
        try writeFile(dir, "main.js", js);
    }

    fn createReactTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const tsx =
            \\import React from 'react';
            \\import { createRoot } from 'react-dom/client';
            \\import './style.css';
            \\
            \\function App() {
            \\  return (
            \\    <div className="app">
            \\      <h1>Welcome to Craft</h1>
            \\      <p>Build desktop apps with React</p>
            \\    </div>
            \\  );
            \\}
            \\
            \\const root = createRoot(document.getElementById('root')!);
            \\root.render(<App />);
            \\
        ;

        try writeFile(dir, "index.tsx", tsx);
    }

    fn createVueTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const vue =
            \\<template>
            \\  <div class="app">
            \\    <h1>Welcome to Craft</h1>
            \\    <p>Build desktop apps with Vue</p>
            \\  </div>
            \\</template>
            \\
            \\<script setup lang="ts">
            \\import { ref } from 'vue';
            \\
            \\const message = ref('Hello from Vue!');
            \\</script>
            \\
            \\<style scoped>
            \\.app {
            \\  text-align: center;
            \\  padding: 2rem;
            \\}
            \\</style>
            \\
        ;

        try writeFile(dir, "App.vue", vue);
    }

    fn createSvelteTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const svelte =
            \\<script lang="ts">
            \\  let message = 'Hello from Svelte!';
            \\</script>
            \\
            \\<div class="app">
            \\  <h1>Welcome to Craft</h1>
            \\  <p>Build desktop apps with Svelte</p>
            \\</div>
            \\
            \\<style>
            \\  .app {
            \\    text-align: center;
            \\    padding: 2rem;
            \\  }
            \\</style>
            \\
        ;

        try writeFile(dir, "App.svelte", svelte);
    }

    fn createSolidTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const solid =
            \\import { render } from 'solid-js/web';
            \\import './style.css';
            \\
            \\function App() {
            \\  return (
            \\    <div class="app">
            \\      <h1>Welcome to Craft</h1>
            \\      <p>Build desktop apps with Solid.js</p>
            \\    </div>
            \\  );
            \\}
            \\
            \\render(() => <App />, document.getElementById('root')!);
            \\
        ;

        try writeFile(dir, "index.tsx", solid);
    }

    fn createPreactTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const preact =
            \\import { render } from 'preact';
            \\import './style.css';
            \\
            \\function App() {
            \\  return (
            \\    <div class="app">
            \\      <h1>Welcome to Craft</h1>
            \\      <p>Build desktop apps with Preact</p>
            \\    </div>
            \\  );
            \\}
            \\
            \\render(<App />, document.getElementById('root')!);
            \\
        ;

        try writeFile(dir, "index.tsx", preact);
    }

    fn createAlpineTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const html =
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\  <meta charset="UTF-8">
            \\  <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\  <title>Craft App</title>
            \\  <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
            \\</head>
            \\<body>
            \\  <div x-data="{ message: 'Hello from Alpine.js!' }" class="app">
            \\    <h1>Welcome to Craft</h1>
            \\    <p x-text="message"></p>
            \\  </div>
            \\</body>
            \\</html>
            \\
        ;

        try writeFile(dir, "index.html", html);
    }

    fn createHtmxTemplate(self: *Self, dir: *std.fs.Dir) !void {
        _ = self;
        const html =
            \\<!DOCTYPE html>
            \\<html lang="en">
            \\<head>
            \\  <meta charset="UTF-8">
            \\  <meta name="viewport" content="width=device-width, initial-scale=1.0">
            \\  <title>Craft App</title>
            \\  <script src="https://unpkg.com/htmx.org@1.9.10"></script>
            \\</head>
            \\<body>
            \\  <div class="app">
            \\    <h1>Welcome to Craft</h1>
            \\    <p>Build desktop apps with HTMX</p>
            \\  </div>
            \\</body>
            \\</html>
            \\
        ;

        try writeFile(dir, "index.html", html);
    }

    fn createCraftConfig(self: *Self, dir: *std.fs.Dir, name: []const u8) !void {
        const config = try std.fmt.allocPrint(self.allocator,
            \\{{
            \\  "name": "{s}",
            \\  "version": "0.1.0",
            \\  "window": {{
            \\    "title": "{s}",
            \\    "width": 1200,
            \\    "height": 800,
            \\    "resizable": true,
            \\    "dev_tools": true
            \\  }},
            \\  "build": {{
            \\    "output": "dist",
            \\    "platforms": ["current"]
            \\  }}
            \\}}
            \\
        , .{ name, name });
        defer self.allocator.free(config);

        const io = io_context.get();
        const file = try dir.createFile(io, "craft.config.json", .{});
        defer file.close(io);
        try file.writeStreamingAll(io, config);

        std.debug.print("✓ Created craft.config.json\n", .{});
    }

    fn createReadme(self: *Self, dir: *std.fs.Dir, name: []const u8) !void {
        const readme = try std.fmt.allocPrint(self.allocator,
            \\# {s}
            \\
            \\A desktop application built with Craft.
            \\
            \\## Development
            \\
            \\```bash
            \\bun install
            \\craft dev
            \\```
            \\
            \\## Build
            \\
            \\```bash
            \\craft build
            \\```
            \\
            \\## Package
            \\
            \\```bash
            \\craft package --platform all
            \\```
            \\
        , .{name});
        defer self.allocator.free(readme);

        const io = io_context.get();
        const file = try dir.createFile(io, "README.md", .{});
        defer file.close(io);
        try file.writeStreamingAll(io, readme);

        std.debug.print("✓ Created README.md\n", .{});
    }

    fn createGitignore(_: *Self, dir: *std.fs.Dir) !void {
        const gitignore =
            \\node_modules/
            \\dist/
            \\*.log
            \\.DS_Store
            \\Thumbs.db
            \\
        ;

        const io = io_context.get();
        const file = try dir.createFile(io, ".gitignore", .{});
        defer file.close(io);
        try file.writeStreamingAll(io, gitignore);

        std.debug.print("✓ Created .gitignore\n", .{});
    }

    fn runDev(_: *Self) !void {
        std.debug.print("Starting development server...\n", .{});
        // Implementation would start dev server with hot reload
    }

    fn runBuild(self: *Self) !void {
        if (self.config.verbose) {
            std.debug.print("Building project...\n", .{});
        }
        // Implementation would run build process
    }

    fn runPackage(self: *Self) !void {
        const platform = self.config.platform orelse "current";
        std.debug.print("Packaging for: {s}\n", .{platform});
        // Implementation would package the app
    }

    fn runTest(_: *Self) !void {
        std.debug.print("Running tests...\n", .{});
        // Implementation would run test suite
    }

    fn runClean(_: *Self) !void {
        std.debug.print("Cleaning build artifacts...\n", .{});
        // Implementation would clean dist/ and other build artifacts
    }
};

fn writeFile(dir: *std.fs.Dir, name: []const u8, content: []const u8) !void {
    const io = io_context.get();
    const file = try dir.createFile(io, name, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, content);
}

fn isValidProjectName(name: []const u8) bool {
    if (name.len == 0) return false;

    for (name) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_') {
            return false;
        }
    }

    return true;
}

fn printUsage() void {
    std.debug.print(
        \\Usage: craft <command> [options]
        \\
        \\Commands:
        \\  init <name>      Create a new Craft project
        \\  dev              Start development server
        \\  build            Build the project
        \\  package          Package the application
        \\  test             Run tests
        \\  clean            Clean build artifacts
        \\  help             Show this help message
        \\  version          Show version information
        \\
        \\Run 'craft <command> --help' for more information on a command.
        \\
    , .{});
}

fn printHelp() void {
    std.debug.print(
        \\
        \\⚡ Craft - Build desktop apps with web languages
        \\
        \\Commands:
        \\
        \\  init <name> [options]
        \\    Create a new Craft project
        \\
        \\    Options:
        \\      -t, --template <template>    Template to use (default: vanilla)
        \\      -o, --output <dir>           Output directory
        \\      -f, --force                  Overwrite existing directory
        \\
        \\    Templates:
        \\      vanilla    Plain HTML, CSS, and JavaScript
        \\      react      React with TypeScript
        \\      vue        Vue 3 with TypeScript
        \\      svelte     Svelte with TypeScript
        \\      solid      Solid.js with TypeScript
        \\      preact     Preact with TypeScript
        \\      alpine     Alpine.js with Tailwind CSS
        \\      htmx       HTMX with hyperscript
        \\
        \\  dev
        \\    Start development server with hot reload
        \\
        \\  build [options]
        \\    Build the project for production
        \\
        \\    Options:
        \\      -o, --output <dir>           Output directory (default: dist)
        \\      -v, --verbose                Verbose output
        \\
        \\  package [options]
        \\    Package the application for distribution
        \\
        \\    Options:
        \\      -p, --platform <platform>    Target platform (macos|windows|linux|all)
        \\      -o, --output <dir>           Output directory
        \\
        \\  test
        \\    Run test suite
        \\
        \\  clean
        \\    Clean build artifacts
        \\
        \\Examples:
        \\  craft init my-app
        \\  craft init my-app --template react
        \\  craft dev
        \\  craft build --verbose
        \\  craft package --platform all
        \\
        \\For more information, visit: https://github.com/stacksjs/craft
        \\
        \\
    , .{});
}

fn printVersion() void {
    const target = builtin.target;
    const platform_name = switch (target.os.tag) {
        .macos => "macOS",
        .linux => "Linux",
        .windows => "Windows",
        else => "Unknown",
    };

    std.debug.print(
        \\craft version 1.3.0
        \\Built with Zig 0.15.1
        \\Platform: {s}
        \\
        \\
    , .{platform_name});
}

// Tests
test "project name validation" {
    try std.testing.expect(isValidProjectName("my-app"));
    try std.testing.expect(isValidProjectName("my_app"));
    try std.testing.expect(isValidProjectName("myapp123"));
    try std.testing.expect(!isValidProjectName("my app"));
    try std.testing.expect(!isValidProjectName("my@app"));
    try std.testing.expect(!isValidProjectName(""));
}

test "template from string" {
    try std.testing.expectEqual(ProjectTemplate.react, ProjectTemplate.fromString("react").?);
    try std.testing.expectEqual(ProjectTemplate.vue, ProjectTemplate.fromString("vue").?);
    try std.testing.expectEqual(@as(?ProjectTemplate, null), ProjectTemplate.fromString("invalid"));
}
