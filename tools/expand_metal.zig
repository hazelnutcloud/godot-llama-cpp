const std = @import("std");

const usage =
    \\Usage: ./embed_metal [options]
    \\
    \\Options:
    \\  --metal-file ggml-metal.metal
    \\  --common-file ggml-common.h
    \\  --output-file ggml-metal-embed.metal
    \\
;

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    var opt_metal_file_path: ?[]const u8 = null;
    var opt_common_file_path: ?[]const u8 = null;
    var opt_output_file_path: ?[]const u8 = null;

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                try std.io.getStdOut().writeAll(usage);
                return std.process.cleanExit();
            } else if (std.mem.eql(u8, "--metal-file", arg)) {
                i += 1;
                if (i > args.len) std.debug.panic("expected arg after '{s}'", .{arg});
                if (opt_metal_file_path != null) std.debug.panic("duplicated {s} argument", .{arg});
                opt_metal_file_path = args[i];
            } else if (std.mem.eql(u8, "--common-file", arg)) {
                i += 1;
                if (i > args.len) std.debug.panic("expected arg after '{s}'", .{arg});
                if (opt_common_file_path != null) std.debug.panic("duplicated {s} argument", .{arg});
                opt_common_file_path = args[i];
            } else if (std.mem.eql(u8, "--output-file", arg)) {
                i += 1;
                if (i > args.len) std.debug.panic("expected arg after '{s}'", .{arg});
                if (opt_output_file_path != null) std.debug.panic("duplicated {s} argument", .{arg});
                opt_output_file_path = args[i];
            } else {
                std.debug.panic("unrecognized arg: '{s}'", .{arg});
            }
        }
    }

    const metal_file_path = opt_metal_file_path orelse std.debug.panic("missing --input-file", .{});
    const common_file_path = opt_common_file_path orelse std.debug.panic("missing --output-file", .{});
    const output_file_path = opt_output_file_path orelse std.debug.panic("missing --lang", .{});

    const cwd = std.fs.cwd();

    var metal_file = try cwd.openFile(metal_file_path, .{});
    defer metal_file.close();

    var common_file = try cwd.openFile(common_file_path, .{});
    defer common_file.close();

    const metal_size = (try metal_file.stat()).size;
    const metal_contents = try arena.alloc(u8, metal_size);
    defer arena.free(metal_contents);
    _ = try metal_file.readAll(metal_contents);

    const common_size = (try common_file.stat()).size;
    const common_contents = try arena.alloc(u8, common_size);
    defer arena.free(common_contents);
    _ = try common_file.readAll(common_contents);

    const output = try std.mem.replaceOwned(u8, arena, metal_contents, "#include \"ggml-common.h\"", common_contents);
    defer arena.free(output);

    const output_file = try cwd.createFile(output_file_path, .{});
    try output_file.writeAll(output);
}
