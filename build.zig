const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const extension = b.addSharedLibrary(.{ .name = "godot-llama-cpp", .target = target, .optimize = optimize });
    extension.addIncludePath(.{ .path = "src" });
    // extension.addIncludePath(.{ .path = "llama.cpp" });
    // extension.addIncludePath(.{ .path = "llama.cpp/common" });
    extension.addIncludePath(.{ .path = "godot-cpp/include/" });
    extension.addIncludePath(.{ .path = "godot-cpp/gdextension/" });
    extension.addIncludePath(.{ .path = "godot-cpp/gen/include/" });
    extension.addObjectFile(.{ .path = "godot-cpp/zig-out/lib/libgodot.lib" });

    extension.linkLibC();
    extension.linkLibCpp();

    const sources = try findFilesRecursive(b, "src", &.{ ".c", ".cpp", ".cxx", ".c++", ".cc" });
    extension.addCSourceFiles(.{ .files = sources, .flags = &.{ "-std=c++17", "-fno-exceptions" } });

    // const llama_libs = try findFilesRecursive(b, "llama.cpp/zig-out/lib", &.{".lib"});
    // for (llama_libs) |lib| {
    //     extension.addObjectFile(.{ .path = lib });
    // }

    b.installArtifact(extension);
}

fn findFilesRecursive(b: *std.Build, dir_name: []const u8, exts: []const []const u8) ![][]const u8 {
    var sources = std.ArrayList([]const u8).init(b.allocator);

    var dir = try std.fs.cwd().openDir(dir_name, .{ .iterate = true });
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include_file = for (exts) |e| {
            if (std.mem.eql(u8, ext, e)) {
                break true;
            }
        } else false;
        if (include_file) {
            try sources.append(b.fmt("{s}/{s}", .{ dir_name, entry.path }));
        }
    }

    return sources.items;
}
