const std = @import("std");
const builtin = @import("builtin");

const cfiles_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };
const extension_name = "godot-llama-cpp";

const ComputeBackend = enum {
    metal,
    vulkan,
    cuda,
    cpu,
};

const Extension = enum {
    @".c",
    @".cpp",
    @".m",
};

const Source = struct {
    name: []const u8,
    source_file: []const u8,
    root: ?std.Build.LazyPath = null,
    dependencies: ?[]const *std.Build.Step = null,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const triple = try target.result.linuxTriple(b.allocator);
    const compute_backend = b.option(
        ComputeBackend,
        "compute-backend",
        "The compute backend to use.",
    ) orelse ComputeBackend.cpu;

    const gen_run = b.addSystemCommand(&.{ "python", "binding_generator.py" });
    gen_run.addFileArg(b.path("godot_cpp/gdextension/extension_api.json"));
    const gen_out = gen_run.addOutputDirectoryArg("godot-cpp-gen");

    // godot-llama-cpp
    const plugin = b.addSharedLibrary(.{
        .name = b.fmt("{s}-{s}-{s}", .{ extension_name, triple, @tagName(optimize) }),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(plugin);

    plugin.addCSourceFiles(.{ .files = try findFilesRecursive(b, "src", &cfiles_exts) });
    plugin.addIncludePath(b.path("src"));
    plugin.addIncludePath(b.path("godot_cpp/gdextension"));
    plugin.addIncludePath(b.path("godot_cpp/include"));
    plugin.addIncludePath(gen_out.path(b, "gen/include"));
    plugin.addIncludePath(b.path("llama.cpp/src"));
    plugin.addIncludePath(b.path("llama.cpp/include"));
    plugin.addIncludePath(b.path("llama.cpp/common"));
    plugin.addIncludePath(b.path("llama.cpp/ggml/include"));
    plugin.addIncludePath(b.path("llama.cpp/ggml/src"));

    // godot-cpp
    const lib_godot = b.addStaticLibrary(.{
        .name = "godot-cpp",
        .target = target,
        .optimize = optimize,
    });
    plugin.linkLibrary(lib_godot);
    lib_godot.linkLibCpp();
    lib_godot.step.dependOn(&gen_run.step);

    lib_godot.addIncludePath(b.path("godot_cpp/gdextension"));
    lib_godot.addIncludePath(b.path("godot_cpp/include"));
    lib_godot.addIncludePath(gen_out.path(b, "gen/include"));

    const concat_gen_exe = b.addExecutable(.{
        .name = "concat_gen",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("tools/concat_files.zig"),
    });
    var concat_gen_run = b.addRunArtifact(concat_gen_exe);
    concat_gen_run.addDirectoryArg(gen_out.path(b, "gen/src"));
    const concat_gen_out = concat_gen_run.addOutputFileArg("gen_concat.cpp");
    const lib_godot_sources = try findFilesRecursive(b, "godot_cpp/src", &cfiles_exts);

    lib_godot.addCSourceFile(.{ .file = concat_gen_out, .flags = &.{ "-std=c++17", "-fno-exceptions" } });
    lib_godot.addCSourceFiles(.{ .files = lib_godot_sources, .flags = &.{ "-std=c++17", "-fno-exceptions" } });

    // llama.cpp
    const lib_llama_cpp = b.addStaticLibrary(.{
        .name = "llama.cpp",
        .target = target,
        .optimize = optimize,
    });
    plugin.linkLibrary(lib_llama_cpp);

    var base_flags = std.ArrayList([]const u8).init(b.allocator);
    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    var cpp_flags = std.ArrayList([]const u8).init(b.allocator);
    var include_paths = std.ArrayList(std.Build.LazyPath).init(b.allocator);
    var system_libs = std.ArrayList([]const u8).init(b.allocator);
    var library_paths = std.ArrayList(std.Build.LazyPath).init(b.allocator);

    var sources = std.ArrayList(Source).init(b.allocator);

    try c_flags.append("-std=c11");
    try cpp_flags.append("-std=c++17");
    try include_paths.appendSlice(&.{
        b.path("llama.cpp/src"),
        b.path("llama.cpp/include"),
        b.path("llama.cpp/common"),
        b.path("llama.cpp/ggml/include"),
        b.path("llama.cpp/ggml/src"),
    });

    switch (target.result.os.tag) {
        .linux => {
            try base_flags.append("-D_GNU_SOURCE");
        },
        .macos => {
            try base_flags.append("-D_DARWIN_C_SOURCE");
        },
        else => {},
    }

    switch (compute_backend) {
        .metal => {
            try base_flags.append("-DGGML_USE_METAL");
            try sources.append(.{ .name = "ggml_metal", .source_file = "llama.cpp/ggml/src/ggml-metal.m" });

            lib_llama_cpp.linkFramework("Foundation");
            lib_llama_cpp.linkFramework("Metal");
            lib_llama_cpp.linkFramework("MetalKit");

            const expand_metal = b.addExecutable(.{
                .name = "expand_metal",
                .target = target,
                .root_source_file = b.path("tools/expand_metal.zig"),
            });
            var run_expand_metal = b.addRunArtifact(expand_metal);
            run_expand_metal.addArg("--metal-file");
            run_expand_metal.addFileArg(b.path("llama.cpp/ggml/src/ggml-metal.metal"));
            run_expand_metal.addArg("--common-file");
            run_expand_metal.addFileArg(b.path("llama.cpp/ggml/src/ggml-common.h"));
            run_expand_metal.addArg("--output-file");
            const metal_expanded = run_expand_metal.addOutputFileArg("ggml-metal.metal");
            const install_metal = b.addInstallFileWithDir(metal_expanded, .lib, "ggml-metal.metal");
            lib_llama_cpp.step.dependOn(&install_metal.step);
        },
        .vulkan => {
            try base_flags.append("-DGGML_USE_VULKAN");
            try sources.append(.{ .name = "ggml_vulkan", .source_file = "llama.cpp/ggml/src/ggml-vulkan.cpp" });

            const env_map = try std.process.getEnvMap(b.allocator);
            const vulkan_sdk = env_map.get("VULKAN_SDK") orelse return error.MissingVulkanSDK;

            const vk_library_path = b.pathJoin(&.{ vulkan_sdk, "lib" });
            const vk_include_path = b.pathJoin(&.{ vulkan_sdk, "include" });
            try include_paths.append(std.Build.LazyPath{ .cwd_relative = vk_include_path });
            try library_paths.append(.{ .cwd_relative = vk_library_path });
            try system_libs.append("vulkan");

            lib_llama_cpp.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ vulkan_sdk, "lib" }) });
            plugin.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ vulkan_sdk, "lib" }) });
        },
        else => {},
    }

    const zig_triple = try target.result.zigTriple(b.allocator);
    const build_info_run = b.addSystemCommand(&.{
        "echo",
        "-e",
        b.fmt(
            "int LLAMA_BUILD_NUMBER = {d};\\nchar const *LLAMA_COMMIT = \"$(git rev-parse HEAD)\";\\nchar const *LLAMA_COMPILER = \"Zig {s}\";\\nchar const *LLAMA_BUILD_TARGET = \"{s}\";\\n",
            .{ 0, builtin.zig_version_string, zig_triple },
        ),
    });
    var build_info_wf = b.addWriteFiles();
    _ = build_info_wf.addCopyFile(build_info_run.captureStdOut(), "build-info.cpp");

    try sources.appendSlice(&.{
        .{ .name = "build_info", .source_file = "build-info.cpp", .root = build_info_wf.getDirectory(), .dependencies = &.{&build_info_wf.step} },
        .{ .name = "ggml", .source_file = "llama.cpp/ggml/src/ggml.c" },
        .{ .name = "sgemm", .source_file = "llama.cpp/ggml/src/sgemm.cpp" },
        .{ .name = "ggml_alloc", .source_file = "llama.cpp/ggml/src/ggml-alloc.c" },
        .{ .name = "ggml_backend", .source_file = "llama.cpp/ggml/src/ggml-backend.c" },
        .{ .name = "ggml_quants", .source_file = "llama.cpp/ggml/src/ggml-quants.c" },
        .{ .name = "llama", .source_file = "llama.cpp/src/llama.cpp" },
        .{ .name = "unicode", .source_file = "llama.cpp/src/unicode.cpp" },
        .{ .name = "unicode_data", .source_file = "llama.cpp/src/unicode-data.cpp" },
        .{ .name = "common", .source_file = "llama.cpp/common/common.cpp" },
        .{ .name = "console", .source_file = "llama.cpp/common/console.cpp" },
        .{ .name = "sampling", .source_file = "llama.cpp/common/sampling.cpp" },
        .{ .name = "grammar_parser", .source_file = "llama.cpp/common/grammar-parser.cpp" },
        .{ .name = "json_schema_to_grammar", .source_file = "llama.cpp/common/json-schema-to-grammar.cpp" },
    });

    try c_flags.appendSlice(base_flags.items);
    try cpp_flags.appendSlice(base_flags.items);

    for (sources.items) |source| {
        const obj = b.addObject(.{
            .name = source.name,
            .target = target,
            .optimize = optimize,
        });
        lib_llama_cpp.addObject(obj);
        if (source.dependencies) |deps| {
            for (deps) |dep| {
                obj.step.dependOn(dep);
            }
        }
        const file = if (source.root) |root|
            root.path(b, source.source_file)
        else
            b.path(source.source_file);
        const extension = std.meta.stringToEnum(
            Extension,
            std.fs.path.extension(source.source_file),
        ) orelse return error.UnknownExtension;
        const flags = switch (extension) {
            .@".c", .@".m" => c_flags.items,
            .@".cpp" => cpp_flags.items,
        };
        obj.addCSourceFile(.{
            .file = file,
            .flags = flags,
        });
        for (include_paths.items) |path| {
            obj.addIncludePath(path);
        }
        for (system_libs.items) |lib| {
            obj.linkSystemLibrary(lib);
        }
        for (library_paths.items) |path| {
            obj.addLibraryPath(path);
        }
        switch (extension) {
            .@".c", .@".m" => obj.linkLibC(),
            .@".cpp" => obj.linkLibCpp(),
        }
    }

    // check step
    const check = b.step("check", "Check if plugin compiles");
    check.dependOn(&plugin.step);
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
