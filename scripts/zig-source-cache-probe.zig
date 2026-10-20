const std = @import("std");
const Io = std.Io;
const Cache = std.Build.Cache;

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    const cwd = try std.process.currentPathAlloc(io, arena);
    std.debug.print("NATIVE_CWD={s}\n", .{cwd});
    const source = try Io.Dir.cwd().openDir(io, args[1], .{});
    defer source.close(io);
    const file = source.openFile(io, "build.zig", .{}) catch |err| {
        std.debug.print("SOURCE_OPEN={t}\n", .{err});
        return err;
    };
    defer file.close(io);
    const stat = file.stat(io) catch |err| {
        std.debug.print("SOURCE_STAT={t}\n", .{err});
        return err;
    };
    const contents = source.readFileAlloc(io, "build.zig", arena, .limited(1024 * 1024)) catch |err| {
        std.debug.print("SOURCE_READ={t}\n", .{err});
        return err;
    };
    std.debug.print("SOURCE_SIZE={d} READ_BYTES={d}\n", .{ stat.size, contents.len });
    var cache: Cache = .{
        .io = io,
        .gpa = arena,
        .manifest_dir = try Io.Dir.cwd().createDirPathOpen(io, args[2], .{}),
        .cwd = cwd,
    };
    defer cache.manifest_dir.close(io);
    cache.addPrefix(.{ .path = null, .handle = Io.Dir.cwd() });
    for (0..4) |_| cache.addPrefix(.{ .path = args[1], .handle = source });
    var manifest = cache.obtain();
    defer manifest.deinit();
    var check_diagnostic: Cache.Manifest.CheckDiagnostic = undefined;
    _ = try manifest.check(&check_diagnostic, .none);
    var diagnostic: Cache.Manifest.AddDiscoveredPathDiagnostic = .none;
    manifest.addDiscoveredPath(.{
        .discovered_path = .{ .prefixed = .{ .prefix = 4, .sub_path = "build.zig" } },
        .diagnostic = &diagnostic,
    }) catch |err| {
        std.debug.print("SOURCE_CACHE={t} DETAILS={f}\n", .{ err, diagnostic });
        return err;
    };
    std.debug.print("SOURCE_CACHE=passed\n", .{});
}
