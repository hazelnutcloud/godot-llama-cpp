const std = @import("std");
const Godot = @import("godot");
const Self = @This();
const c = @cImport({
    @cInclude("llama.h");
});

pub usingnamespace Godot.Resource;
godot_object: *Godot.Resource,

model: ?*c.struct_llama_model = null,

pub fn load_model(self: *Self, path: *Godot.String) void {
    const abs_path = Godot.ProjectSettings.getSingleton().globalize_path(@ptrCast(&path.value));

    var buf: [256]u8 = undefined;
    self.model = c.llama_load_model_from_file(@ptrCast((Godot.stringToAscii(abs_path, &buf))), c.llama_model_default_params());
}
