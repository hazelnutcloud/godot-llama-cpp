const std = @import("std");
const Godot = @import("godot");
const Self = @This();

pub usingnamespace Godot.ResourceFormatLoader;
godot_object: *Godot.ResourceFormatLoader,

pub fn _get_recognized_extensions(_: *Self) Godot.PackedStringArray {
    var res = Godot.PackedStringArray.init();
    _ = res.push_back("gguf");
    return res;
}

pub fn _load(_: *Self, path: Godot.String, _: Godot.String, _: bool, _: i32) Godot.Variant {
    const LlamaModel = @import("LlamaModel.zig");
    const model = Godot.create(LlamaModel) catch unreachable;
    // if (Godot.Engine.getSingleton().is_editor_hint()) {
    //     return Godot.Variant.initFrom(.{ .godot_object = model.godot_object });
    // }
    model.load_model(path);
    return Godot.Variant.initFrom(model.*);
}

pub fn _handles_type(_: *Self, type_name: Godot.StringName) bool {
    return type_name.casecmp_to("LlamaModel") == 0;
}

pub fn _get_resource_type(self: *Self, p_path: Godot.String) Godot.String {
    _ = self;
    const el = p_path.get_extension().to_lower();

    if (el.casecmp_to("gguf") == 0) {
        return Godot.String.initFromLatin1Chars("LlamaModel");
    }

    return Godot.String.init();
}
