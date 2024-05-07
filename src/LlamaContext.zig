const std = @import("std");
const Godot = @import("godot");
const Self = @This();
const c = @cImport({
    @cInclude("llama.h");
});
const LlamaModel = @import("LlamaModel.zig");

pub usingnamespace Godot.Node;
godot_object: *Godot.Node,

model: ?*LlamaModel = null,

pub fn _get_property_list(_: *Self) []const Godot.PropertyInfo {
    const C = struct {
        var properties: [32]Godot.PropertyInfo = undefined;
    };

    C.properties[0] = Godot.PropertyInfo.initFull(
        Godot.GDE.GDEXTENSION_VARIANT_TYPE_OBJECT,
        Godot.StringName.initFromLatin1Chars("model"),
        Godot.StringName.initFromLatin1Chars(""),
        Godot.GlobalEnums.PROPERTY_HINT_RESOURCE_TYPE,
        Godot.String.initFromLatin1Chars("LlamaModel"),
        Godot.GlobalEnums.PROPERTY_USAGE_DEFAULT,
    );

    return C.properties[0..1];
}

pub fn _set(self: *Self, name: Godot.StringName, value: Godot.Variant) bool {
    if (name.casecmp_to("Model") == 0) {
        var model = value.as(LlamaModel);
        self.model = &model;
        return true;
    }

    return false;
}

pub fn _get(self: *Self, name: Godot.StringName, value: *Godot.Variant) bool {
    if (name.casecmp_to("Model") == 0) {
        value.* = Godot.Variant.initFrom(self.model.?.*);
        return true;
    }

    return false;
}
