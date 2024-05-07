const std = @import("std");
const Godot = @import("godot");
const Self = @This();

pub usingnamespace Godot.ResourceFormatLoader;
godot_object: *Godot.ResourceFormatLoader,

pub fn _get_recognized_extensions() Godot.PackedStringArray {
    var res = Godot.PackedStringArray.init();
    _ = res.push_back("gguf");
    return res;
}

pub fn _load(_: *Godot.String) Godot.Variant {
    const LlamaModel = @import("LlamaModel.zig");
    const model = Godot.create(LlamaModel) catch unreachable;
    if (Godot.Engine.getSingleton().is_editor_hint()) {
        return Godot.Variant.initFrom(.{ .godot_object = model.godot_object });
    }
    return Godot.Variant.initFrom(.{ .godot_object = model.godot_object });
}

pub fn _handles_type(type_name: *Godot.StringName) bool {
    var buf: [256]u8 = undefined;
    return Godot.ClassDB.getSingleton().is_parent_class(@ptrCast(Godot.stringNameToAscii(type_name.*, &buf)), "LlamaModel");
}

pub fn _get_resource_type(p_path: *Godot.String) Godot.String {
    const el = p_path.get_extension().to_lower();

    if (el.casecmp_to("gguf") == 0) {
        return Godot.String.initFromUtf8Chars("LlamaModel");
    }

    return Godot.String.init();
}
