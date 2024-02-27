const std = @import("std");
const builtin = @import("builtin");

const cfiles_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };
const extension_name = "godot-llama-cpp";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zig_triple = try target.result.zigTriple(b.allocator);

    var objs = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);

    // godot-cpp
    const lib_godot = b.addStaticLibrary(.{
        .name = "godot-cpp",
        .target = target,
        .optimize = optimize,
    });
    b.build_root.handle.access("godot_cpp/gen", .{}) catch |e| {
        switch (e) {
            error.FileNotFound => {
                _ = try std.ChildProcess.run(.{
                    .allocator = b.allocator,
                    .argv = &.{ "python", "binding_generator.py", "godot_cpp/gdextension/extension_api.json", "godot_cpp" },
                    .cwd_dir = b.build_root.handle,
                });
            },
            else => {
                return;
            },
        }
    };
    lib_godot.linkLibCpp();
    lib_godot.addIncludePath(.{ .path = "godot_cpp/gdextension/" });
    lib_godot.addIncludePath(.{ .path = "godot_cpp/include/" });
    lib_godot.addIncludePath(.{ .path = "godot_cpp/gen/include" });
    const lib_godot_sources = try findFilesRecursive(b, "godot_cpp/src", &cfiles_exts);
    const lib_godot_gen_sources = try findFilesRecursive(b, "godot_cpp/gen/src", &cfiles_exts);
    lib_godot.addCSourceFiles(.{ .files = lib_godot_gen_sources, .flags = &.{ "-std=c++17", "-fno-exceptions" } });
    lib_godot.addCSourceFiles(.{ .files = lib_godot_sources, .flags = &.{ "-std=c++17", "-fno-exceptions" } });
    // try objs.append(lib_godot);

    // llama.cpp
    const commit_hash = try std.ChildProcess.run(.{ .allocator = b.allocator, .argv = &.{ "git", "rev-parse", "HEAD" }, .cwd = b.pathFromRoot("llama.cpp") });
    const zig_version = builtin.zig_version_string;
    try b.build_root.handle.writeFile2(.{ .sub_path = "llama.cpp/common/build-info.cpp", .data = b.fmt(
        \\int LLAMA_BUILD_NUMBER = {};
        \\char const *LLAMA_COMMIT = "{s}";
        \\char const *LLAMA_COMPILER = "Zig {s}";
        \\char const *LLAMA_BUILD_TARGET = "{s}";
        \\
    , .{ 0, commit_hash.stdout[0 .. commit_hash.stdout.len - 1], zig_version, zig_triple }) });

    var flags = std.ArrayList([]const u8).init(b.allocator);
    if (target.result.abi != .msvc) try flags.append("-D_GNU_SOURCE");
    if (target.result.os.tag == .macos) try flags.appendSlice(&.{ "-D_DARWIN_C_SOURCE", "-DGGML_USE_METAL", "-DGGML_USE_ACCELERATE", "-DACCELERATE_USE_LAPACK", "-DACCELERATE_LAPACK_ILP64" }) else try flags.append("-DGGML_USE_VULKAN");
    try flags.append("-D_XOPEN_SOURCE=600");

    var cflags = std.ArrayList([]const u8).init(b.allocator);
    try cflags.append("-std=c11");
    try cflags.appendSlice(flags.items);
    var cxxflags = std.ArrayList([]const u8).init(b.allocator);
    try cxxflags.append("-std=c++11");
    try cxxflags.appendSlice(flags.items);

    const include_paths = [_][]const u8{ "llama.cpp", "llama.cpp/common" };
    const llama = buildObj(.{
        .b = b,
        .name = "llama",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/llama.cpp"},
        .include_paths = &include_paths,
        .link_lib_cpp = true,
        .link_lib_c = false,
        .flags = cxxflags.items,
    });
    const ggml = buildObj(.{
        .b = b,
        .name = "ggml",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/ggml.c"},
        .include_paths = &include_paths,
        .link_lib_c = true,
        .link_lib_cpp = false,
        .flags = cflags.items,
    });
    const common = buildObj(.{
        .b = b,
        .name = "common",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/common/common.cpp"},
        .include_paths = &include_paths,
        .link_lib_cpp = true,
        .link_lib_c = false,
        .flags = cxxflags.items,
    });
    const console = buildObj(.{
        .b = b,
        .name = "console",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/common/console.cpp"},
        .include_paths = &include_paths,
        .link_lib_cpp = true,
        .link_lib_c = false,
        .flags = cxxflags.items,
    });
    const sampling = buildObj(.{
        .b = b,
        .name = "sampling",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/common/sampling.cpp"},
        .include_paths = &include_paths,
        .link_lib_cpp = true,
        .link_lib_c = false,
        .flags = cxxflags.items,
    });
    const grammar_parser = buildObj(.{
        .b = b,
        .name = "grammar_parser",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/common/grammar-parser.cpp"},
        .include_paths = &include_paths,
        .link_lib_cpp = true,
        .link_lib_c = false,
        .flags = cxxflags.items,
    });
    const build_info = buildObj(.{
        .b = b,
        .name = "build_info",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/common/build-info.cpp"},
        .include_paths = &include_paths,
        .link_lib_cpp = true,
        .link_lib_c = false,
        .flags = cxxflags.items,
    });
    const ggml_alloc = buildObj(.{
        .b = b,
        .name = "ggml_alloc",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/ggml-alloc.c"},
        .include_paths = &include_paths,
        .link_lib_c = true,
        .link_lib_cpp = false,
        .flags = cflags.items,
    });
    const ggml_backend = buildObj(.{
        .b = b,
        .name = "ggml_backend",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/ggml-backend.c"},
        .include_paths = &include_paths,
        .link_lib_c = true,
        .link_lib_cpp = false,
        .flags = cflags.items,
    });
    const ggml_quants = buildObj(.{
        .b = b,
        .name = "ggml_quants",
        .target = target,
        .optimize = optimize,
        .sources = &.{"llama.cpp/ggml-quants.c"},
        .include_paths = &include_paths,
        .link_lib_c = true,
        .link_lib_cpp = false,
        .flags = cflags.items,
    });
    try objs.appendSlice(&.{ llama, ggml, common, console, sampling, grammar_parser, build_info, ggml_alloc, ggml_backend, ggml_quants });

    if (target.result.os.tag == .macos) {
        const ggml_metal = buildObj(.{
            .b = b,
            .name = "ggml_metal",
            .target = target,
            .optimize = optimize,
            .sources = &.{"llama.cpp/ggml-metal.m"},
            .include_paths = &include_paths,
            .link_lib_c = true,
            .link_lib_cpp = false,
            .flags = cflags.items,
        });
        try objs.append(ggml_metal);
    } else {
        const ggml_vulkan = buildObj(.{
            .b = b,
            .name = "ggml_vulkan",
            .target = target,
            .optimize = optimize,
            .sources = &.{"llama.cpp/ggml-vulkan.cpp"},
            .include_paths = &include_paths,
            .link_lib_cpp = true,
            .link_lib_c = false,
            .flags = cxxflags.items,
        });
        try objs.append(ggml_vulkan);
    }

    const extension = b.addSharedLibrary(.{ .name = b.fmt("{s}-{s}", .{ extension_name, zig_triple }), .target = target, .optimize = optimize });
    const sources = try findFilesRecursive(b, "src", &cfiles_exts);
    extension.addCSourceFiles(.{ .files = sources, .flags = &.{ "-std=c++17", "-fno-exceptions" } });
    extension.addIncludePath(.{ .path = "src" });
    extension.addIncludePath(.{ .path = "godot_cpp/include/" });
    extension.addIncludePath(.{ .path = "godot_cpp/gdextension/" });
    extension.addIncludePath(.{ .path = "godot_cpp/gen/include/" });
    extension.addIncludePath(.{ .path = "llama.cpp" });
    extension.addIncludePath(.{ .path = "llama.cpp/common" });
    for (objs.items) |obj| {
        extension.addObject(obj);
    }
    extension.linkLibC();
    extension.linkLibCpp();
    if (target.result.os.tag == .macos) {
        extension.linkFramework("Metal");
        extension.linkFramework("MetalKit");
        extension.linkFramework("Foundation");
        extension.linkFramework("Accelerate");
    } else {
        extension.linkSystemLibrary("vulkan");
    }
    extension.linkLibrary(lib_godot);

    b.installArtifact(extension);
}

const BuildObjectParams = struct {
    b: *std.Build,
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    sources: []const []const u8,
    include_paths: []const []const u8,
    link_lib_c: bool,
    link_lib_cpp: bool,
    flags: []const []const u8,
};

fn buildObj(params: BuildObjectParams) *std.Build.Step.Compile {
    const obj = params.b.addObject(.{
        .name = params.name,
        .target = params.target,
        .optimize = params.optimize,
    });
    for (params.include_paths) |path| {
        obj.addIncludePath(.{ .path = path });
    }
    if (params.link_lib_c) {
        obj.linkLibC();
    }
    if (params.link_lib_cpp) {
        obj.linkLibCpp();
    }
    obj.addCSourceFiles(.{ .files = params.sources, .flags = params.flags });
    return obj;
}

fn findFilesRecursive(b: *std.Build, dir_name: []const u8, exts: []const []const u8) ![][]const u8 {
    var sources = std.ArrayList([]const u8).init(b.allocator);

    var dir = try b.build_root.handle.openDir(dir_name, .{ .iterate = true });
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
