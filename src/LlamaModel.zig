const std = @import("std");
const Godot = @import("godot");
const Self = @This();
const c = @cImport({
    @cInclude("llama.h");
});

pub usingnamespace Godot.Resource;
godot_object: *Godot.Resource,

model: ?*c.struct_llama_model = null,

pub fn load_model(self: *Self, path: Godot.String) void {
    var buf: [256:0]u8 = undefined;
    const abs_path = Godot.ProjectSettings.getSingleton().globalize_path(@ptrCast(Godot.stringToAscii(path, &buf)));

    var buf2: [1024:0]u8 = undefined;
    self.model = c.llama_load_model_from_file(Godot.stringToAscii(abs_path, &buf2), c.llama_model_default_params());
}
