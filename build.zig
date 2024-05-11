const std = @import("std");
const builtin = @import("builtin");

const cfiles_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };
const extension_name = "godot-llama-cpp";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const triple = try target.result.linuxTriple(b.allocator);

    const lib_godot_cpp = try build_lib_godot_cpp(.{ .b = b, .target = target, .optimize = optimize });
    const lib_llama_cpp = try build_lib_llama_cpp(.{ .b = b, .target = target, .optimize = optimize });

    const plugin = b.addSharedLibrary(.{
        .name = b.fmt("{s}-{s}-{s}", .{ extension_name, triple, @tagName(optimize) }),
        .target = target,
        .optimize = optimize,
    });
    plugin.addCSourceFiles(.{ .files = try findFilesRecursive(b, "src/", &cfiles_exts) });
    plugin.addIncludePath(.{ .path = "src/" });
    plugin.addIncludePath(.{ .path = "godot_cpp/gdextension/" });
    plugin.addIncludePath(.{ .path = "godot_cpp/include/" });
    plugin.addIncludePath(.{ .path = "godot_cpp/gen/include" });
    plugin.addIncludePath(.{ .path = "llama.cpp" });
    plugin.addIncludePath(.{ .path = "llama.cpp/common" });
    plugin.linkLibrary(lib_llama_cpp);
    plugin.linkLibrary(lib_godot_cpp);

    b.lib_dir = "./godot/addons/godot-llama-cpp/lib";
    b.installArtifact(plugin);
}

const BuildParams = struct {
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

fn build_lib_godot_cpp(params: BuildParams) !*std.Build.Step.Compile {
    const b = params.b;
    const target = params.target;
    const optimize = params.optimize;

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
            else => {},
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

    return lib_godot;
}

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
    , .{ 0, commit_hash.stdout[0 .. commit_hash.stdout.len - 1], zig_version, zig_triple }) });

    const lib_llama_cpp = b.addStaticLibrary(.{ .name = "llama.cpp", .target = target, .optimize = optimize });

    var objs = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);
    var objBuilder = ObjBuilder.init(.{
        .b = b,
        .target = target,
        .optimize = optimize,
        .include_paths = &.{ "llama.cpp", "llama.cpp/common" },
    });

    switch (target.result.os.tag) {
        .macos => {
            try objBuilder.flags.append("-DGGML_USE_METAL");
            try objs.append(objBuilder.build(.{ .name = "ggml_metal", .sources = &.{"llama.cpp/ggml-metal.m"} }));

            lib_llama_cpp.linkFramework("Foundation");
            lib_llama_cpp.linkFramework("Metal");
            lib_llama_cpp.linkFramework("MetalKit");

            const expand_metal = b.addExecutable(.{
                .name = "expand_metal",
                .target = target,
                .root_source_file = .{ .path = "tools/expand_metal.zig" },
            });
            var run_expand_metal = b.addRunArtifact(expand_metal);
            run_expand_metal.addArg("--metal-file");
            run_expand_metal.addFileArg(.{ .path = "llama.cpp/ggml-metal.metal" });
            run_expand_metal.addArg("--common-file");
            run_expand_metal.addFileArg(.{ .path = "llama.cpp/ggml-common.h" });
            run_expand_metal.addArg("--output-file");
            const metal_expanded = run_expand_metal.addOutputFileArg("ggml-metal.metal");
            const install_metal = b.addInstallFileWithDir(metal_expanded, .lib, "ggml-metal.metal");
            lib_llama_cpp.step.dependOn(&install_metal.step);
        },
        else => {},
    }

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
    flags: std.ArrayList([]const u8),

    fn init(params: struct {
        b: *std.Build,
        target: std.Build.ResolvedTarget,
        optimize: std.builtin.OptimizeMode,
        include_paths: []const []const u8,
    }) ObjBuilder {
        return ObjBuilder{
            .b = params.b,
            .target = params.target,
            .optimize = params.optimize,
            .include_paths = params.include_paths,
            .flags = std.ArrayList([]const u8).init(params.b.allocator),
        };
    }

    fn build(self: *ObjBuilder, params: struct { name: []const u8, sources: []const []const u8 }) *std.Build.Step.Compile {
        const obj = self.b.addObject(.{ .name = params.name, .target = self.target, .optimize = self.optimize });
        obj.addCSourceFiles(.{ .files = params.sources, .flags = self.flags.items });
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
