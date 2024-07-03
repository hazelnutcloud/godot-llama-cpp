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
    plugin.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src/" } });
    plugin.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "godot_cpp/gdextension/" } });
    plugin.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "godot_cpp/include/" } });
    plugin.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "godot_cpp/gen/include" } });
    plugin.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "llama.cpp" } });
    plugin.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "llama.cpp/common" } });
    plugin.linkLibrary(lib_llama_cpp);
    plugin.linkLibrary(lib_godot_cpp);

    b.installArtifact(plugin);

    const check = b.step("check", "Check if plugin compiles");
    check.dependOn(&plugin.step);
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
                _ = try std.process.Child.run(.{
                    .allocator = b.allocator,
                    .argv = &.{ "python", "binding_generator.py", "godot_cpp/gdextension/extension_api.json", "godot_cpp" },
                    .cwd_dir = b.build_root.handle,
                });
            },
            else => {},
        }
    };
    lib_godot.linkLibCpp();
    lib_godot.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "godot_cpp/gdextension/" } });
    lib_godot.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "godot_cpp/include/" } });
    lib_godot.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "godot_cpp/gen/include" } });
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

    const lib_llama_cpp = b.addStaticLibrary(.{
        .name = "llama.cpp",
        .target = target,
        .optimize = optimize,
    });

    const build_info_run = b.addSystemCommand(&.{
        "echo",
        "-e",
        b.fmt(
            "int LLAMA_BUILD_NUMBER = {d};\\nchar const *LLAMA_COMMIT = \"$(git rev-parse HEAD)\";\\nchar const *LLAMA_COMPILER = \"Zig {s}\";\\nchar const *LLAMA_BUILD_TARGET = \"{s}\";\\n",
            .{ 0, builtin.zig_version_string, zig_triple },
        ),
    });
    const build_info_wf = b.addWriteFiles();
    _ = build_info_wf.addCopyFile(build_info_run.captureStdOut(), "build-info.cpp");

    var objBuilder = ObjBuilder.init(.{
        .b = b,
        .target = target,
        .optimize = optimize,
        .include_paths = &.{ "llama.cpp", "llama.cpp/common" },
    });
    try objBuilder.c_flags.append("-std=c11");
    try objBuilder.cpp_flags.append("-std=c++11");

    var objs = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);

    switch (target.result.os.tag) {
        .macos => {
            try objBuilder.base_flags.append("-DGGML_USE_METAL");
            try objs.append(try objBuilder.build(.{ .name = "ggml_metal", .source = "llama.cpp/ggml-metal.m" }));

            lib_llama_cpp.linkFramework("Foundation");
            lib_llama_cpp.linkFramework("Metal");
            lib_llama_cpp.linkFramework("MetalKit");

            const expand_metal = b.addExecutable(.{
                .name = "expand_metal",
                .target = target,
                .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "tools/expand_metal.zig" } },
            });
            var run_expand_metal = b.addRunArtifact(expand_metal);
            run_expand_metal.addArg("--metal-file");
            run_expand_metal.addFileArg(.{ .src_path = .{ .owner = b, .sub_path = "llama.cpp/ggml-metal.metal" } });
            run_expand_metal.addArg("--common-file");
            run_expand_metal.addFileArg(.{ .src_path = .{ .owner = b, .sub_path = "llama.cpp/ggml-common.h" } });
            run_expand_metal.addArg("--output-file");
            const metal_expanded = run_expand_metal.addOutputFileArg("ggml-metal.metal");
            const install_metal = b.addInstallFileWithDir(metal_expanded, .lib, "ggml-metal.metal");
            lib_llama_cpp.step.dependOn(&install_metal.step);
        },
        .linux => {
            try objBuilder.base_flags.append("-D_GNU_SOURCE");
        },
        else => {},
    }

    const build_info_compile = try objBuilder.build(.{
        .name = "build_info",
        .source = "build-info.cpp",
        .root = build_info_wf.getDirectory(),
    });
    build_info_compile.step.dependOn(&build_info_wf.step);

    try objs.appendSlice(&.{
        try objBuilder.build(.{ .name = "ggml", .source = "llama.cpp/ggml.c" }),
        try objBuilder.build(.{ .name = "sgemm", .source = "llama.cpp/sgemm.cpp" }),
        try objBuilder.build(.{ .name = "ggml_alloc", .source = "llama.cpp/ggml-alloc.c" }),
        try objBuilder.build(.{ .name = "ggml_backend", .source = "llama.cpp/ggml-backend.c" }),
        try objBuilder.build(.{ .name = "ggml_quants", .source = "llama.cpp/ggml-quants.c" }),
        try objBuilder.build(.{ .name = "llama", .source = "llama.cpp/llama.cpp" }),
        try objBuilder.build(.{ .name = "unicode", .source = "llama.cpp/unicode.cpp" }),
        try objBuilder.build(.{ .name = "unicode_data", .source = "llama.cpp/unicode-data.cpp" }),
        try objBuilder.build(.{ .name = "common", .source = "llama.cpp/common/common.cpp" }),
        try objBuilder.build(.{ .name = "console", .source = "llama.cpp/common/console.cpp" }),
        try objBuilder.build(.{ .name = "sampling", .source = "llama.cpp/common/sampling.cpp" }),
        try objBuilder.build(.{ .name = "grammar_parser", .source = "llama.cpp/common/grammar-parser.cpp" }),
        try objBuilder.build(.{ .name = "json_schema_to_grammar", .source = "llama.cpp/common/json-schema-to-grammar.cpp" }),
        build_info_compile,
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
    c_flags: std.ArrayList([]const u8),
    cpp_flags: std.ArrayList([]const u8),
    base_flags: std.ArrayList([]const u8),

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
            .c_flags = std.ArrayList([]const u8).init(params.b.allocator),
            .cpp_flags = std.ArrayList([]const u8).init(params.b.allocator),
            .base_flags = std.ArrayList([]const u8).init(params.b.allocator),
        };
    }

    fn build(
        self: *ObjBuilder,
        params: struct {
            name: []const u8,
            source: []const u8,
            root: ?std.Build.LazyPath = null,
        },
    ) !*std.Build.Step.Compile {
        const obj = self.b.addObject(.{
            .name = params.name,
            .target = self.target,
            .optimize = self.optimize,
            .pic = true,
        });

        const Extension = enum {
            c,
            cpp,
            m,
        };
        const extension = std.meta.stringToEnum(
            Extension,
            std.mem.trimLeft(u8, std.fs.path.extension(params.source), "."),
        ) orelse return error.UnknownExtension;

        const flags = switch (extension) {
            .c, .m => self.c_flags,
            .cpp => self.cpp_flags,
        };
        try self.base_flags.appendSlice(flags.items);

        obj.addCSourceFiles(.{
            .files = &.{params.source},
            .flags = self.base_flags.items,
            .root = params.root,
        });
        for (self.include_paths) |path| {
            obj.addIncludePath(.{ .src_path = .{ .owner = self.b, .sub_path = path } });
        }

        switch (extension) {
            .c, .m => obj.linkLibC(),
            .cpp => obj.linkLibCpp(),
        }

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
