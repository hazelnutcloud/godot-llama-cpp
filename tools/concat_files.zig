const std = @import("std");

const usage = "Usage: ./concat_files <input-dir-1> <input-dir-2> ... <output-file>";

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len < 3) {
        std.debug.panic("expected at least 2 arguments", .{});
    }

    var input_dirs = std.ArrayList([]const u8).init(arena);
    var output_file_path: []const u8 = undefined;

    {
        var i: usize = 1;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (std.mem.eql(u8, "-h", arg) or std.mem.eql(u8, "--help", arg)) {
                try std.io.getStdOut().writeAll(usage);
                return std.process.cleanExit();
            } else if (i == args.len - 1) {
                output_file_path = arg;
            } else {
                try input_dirs.append(arg);
            }
        }
    }

    const cwd = std.fs.cwd();
    const output = try cwd.createFile(output_file_path, .{});
    var pos: u64 = 0;

    for (input_dirs.items) |dir_path| {
        var dir = try cwd.openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(arena);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            const file = try entry.dir.openFile(entry.basename, .{});
            defer file.close();

            const len = (try file.stat()).size;
            const bytes_copied = try file.copyRangeAll(0, output, pos, len);
            pos += bytes_copied;

            try output.pwriteAll("\n", pos);
            pos += 1;
        }
    }
}
