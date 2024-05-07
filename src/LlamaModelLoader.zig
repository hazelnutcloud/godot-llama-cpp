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

pub fn _load(path: *Godot.String, original_path: Godot.String, use_sub_threads: bool, cache_mode: i32) Godot.Variant {
    _ = original_path;
    _ = use_sub_threads;
    _ = cache_mode;
    const LlamaModel = @import("LlamaModel.zig");
    const model = Godot.create(LlamaModel) catch unreachable;
    if (Godot.Engine.getSingleton().is_editor_hint()) {
        return Godot.Variant.initFrom(.{ .godot_object = model.godot_object });
    }
    model.load_model(path);
    return Godot.Variant.initFrom(.{ .godot_object = model.godot_object });
}

pub fn _handles_type(type_name: *Godot.StringName) bool {
    return Godot.ClassDB.getSingleton().is_parent_class(@ptrCast(&type_name.value), "LlamaModel");
}

pub fn _get_resource_type(p_path: *Godot.String) Godot.String {
    const el = p_path.get_extension().to_lower();

    if (el.casecmp_to("gguf") == 0) {
        return Godot.String.initFromUtf8Chars("LlamaModel");
    }

    return Godot.String.init();
}
