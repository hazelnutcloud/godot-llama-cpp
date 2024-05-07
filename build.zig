const std = @import("std");
const builtin = @import("builtin");

const extension_name = "godot-llama-cpp";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zig_triple = try target.result.linuxTriple(b.allocator);

    const godot_zig = b.dependency("godot_zig", .{});
    const lib_llama_cpp = try build_lib_llama_cpp(.{ .b = b, .target = target, .optimize = optimize });

    const plugin = b.addSharedLibrary(.{
        .name = b.fmt("{s}-{s}-{s}", .{ extension_name, zig_triple, @tagName(optimize) }),
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "src/Plugin.zig" },
    });
    plugin.root_module.addImport("godot", godot_zig.module("godot"));
    b.lib_dir = "./godot/addons/godot-llama-cpp/lib";
    plugin.addIncludePath(.{ .path = "llama.cpp" });
    plugin.linkLibrary(lib_llama_cpp);

    b.installArtifact(plugin);
}

const BuildParams = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

fn build_lib_llama_cpp(params: BuildParams) !*std.Build.Step.Compile {
    const b = params.b;
    const target = params.target;
    const optimize = params.optimize;
    const zig_triple = try target.result.zigTriple(b.allocator);

    const commit_hash = try std.ChildProcess.run(.{ .allocator = b.allocator, .argv = &.{ "git", "rev-parse", "HEAD" }, .cwd = b.pathFromRoot("llama.cpp") });
    const zig_version = builtin.zig_version_string;
    try b.build_root.handle.writeFile2(.{ .sub_path = "llama.cpp/common/build-info.cpp", .data = b.fmt(
        \\int LLAMA_BUILD_NUMBER = {};
        \\char const *LLAMA_COMMIT = "{s}";
        \\char const *LLAMA_COMPILER = "Zig {s}";
        \\char const *LLAMA_BUILD_TARGET = "{s}";
        \\
    , .{ 0, commit_hash.stdout[0 .. commit_hash.stdout.len - 1], zig_version, zig_triple }) });

    var objs = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);
    var objBuilder = ObjBuilder.init(.{ .b = b, .target = target, .optimize = optimize, .include_paths = &.{
        "llama.cpp",
        "llama.cpp/common",
    } });

    try objs.appendSlice(&.{
        objBuilder.build(.{ .name = "ggml", .sources = &.{"llama.cpp/ggml.c"} }),
        objBuilder.build(.{ .name = "sgemm", .sources = &.{"llama.cpp/sgemm.cpp"} }),
        objBuilder.build(.{ .name = "ggml_alloc", .sources = &.{"llama.cpp/ggml-alloc.c"} }),
        objBuilder.build(.{ .name = "ggml_backend", .sources = &.{"llama.cpp/ggml-backend.c"} }),
        objBuilder.build(.{ .name = "ggml_quants", .sources = &.{"llama.cpp/ggml-quants.c"} }),
        objBuilder.build(.{ .name = "llama", .sources = &.{"llama.cpp/llama.cpp"} }),
        objBuilder.build(.{ .name = "unicode", .sources = &.{"llama.cpp/unicode.cpp"} }),
        objBuilder.build(.{ .name = "unicode_data", .sources = &.{"llama.cpp/unicode-data.cpp"} }),
        objBuilder.build(.{ .name = "common", .sources = &.{"llama.cpp/common/common.cpp"} }),
        objBuilder.build(.{ .name = "console", .sources = &.{"llama.cpp/common/console.cpp"} }),
        objBuilder.build(.{ .name = "sampling", .sources = &.{"llama.cpp/common/sampling.cpp"} }),
        objBuilder.build(.{ .name = "grammar_parser", .sources = &.{"llama.cpp/common/grammar-parser.cpp"} }),
        objBuilder.build(.{ .name = "json_schema_to_grammar", .sources = &.{"llama.cpp/common/json-schema-to-grammar.cpp"} }),
        objBuilder.build(.{ .name = "build_info", .sources = &.{"llama.cpp/common/build-info.cpp"} }),
    });

    const lib_llama_cpp = b.addStaticLibrary(.{ .name = "llama.cpp", .target = target, .optimize = optimize });

    for (objs.items) |obj| {
        lib_llama_cpp.addObject(obj);
    }

    return lib_llama_cpp;
}

const ObjBuilder = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    include_paths: []const []const u8,

    fn init(params: struct { b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, include_paths: []const []const u8 }) ObjBuilder {
        return ObjBuilder{
            .b = params.b,
            .target = params.target,
            .optimize = params.optimize,
            .include_paths = params.include_paths,
        };
    }

    fn build(self: *ObjBuilder, params: struct { name: []const u8, sources: []const []const u8 }) *std.Build.Step.Compile {
        const obj = self.b.addObject(.{ .name = params.name, .target = self.target, .optimize = self.optimize });
        obj.addCSourceFiles(.{ .files = params.sources });
        for (self.include_paths) |path| {
            obj.addIncludePath(.{ .path = path });
        }
        obj.linkLibC();
        obj.linkLibCpp();
        return obj;
    }
};

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
