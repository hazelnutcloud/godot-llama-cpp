const std = @import("std");
const Godot = @import("godot");
const Self = @This();
const c = @cImport({
    @cInclude("llama.h");
});
const LlamaModel = @import("LlamaModel.zig");

pub usingnamespace Godot.Node;
godot_object: *Godot.Node,

model: ?LlamaModel = null,

pub fn _get_property_list(_: *Self) []const Godot.PropertyInfo {
    const C = struct {
        var properties: [32]Godot.PropertyInfo = undefined;
    };

    C.properties[0] = Godot.PropertyInfo.initFull(
        Godot.GDE.GDEXTENSION_VARIANT_TYPE_OBJECT,
        Godot.StringName.initFromLatin1Chars("model"),
        Godot.StringName.initFromLatin1Chars("LlamaModel"),
        Godot.GlobalEnums.PROPERTY_HINT_RESOURCE_TYPE,
        Godot.String.initFromLatin1Chars("LlamaModel"),
        Godot.GlobalEnums.PROPERTY_USAGE_DEFAULT,
    );

    return C.properties[0..1];
}

pub fn _property_can_revert(_: *Self, name: Godot.StringName) bool {
    return name.nocasecmp_to("model") == 0;
}

pub fn _property_get_revert(_: *Self, name: Godot.StringName, value: *Godot.Variant) bool {
    if (name.nocasecmp_to("model") == 0) {
        value.* = Godot.Variant.init();
        return true;
    }
    return false;
}

pub fn _set(self: *Self, name: Godot.StringName, value: Godot.Variant) bool {
    if (name.nocasecmp_to("model") == 0) {
        std.debug.print("set model: {any}\n", .{value});
        if (std.mem.eql(u8, &value.value, &[_]u8{0} ** 24)) {
            self.model = null;
            return true;
        }
        const model = value.as(*LlamaModel);
        self.model = model.*;
        return true;
    }

    return false;
}

pub fn _get(self: *Self, name: Godot.StringName, value: *Godot.Variant) bool {
    if (name.nocasecmp_to("model") == 0) {
        if (self.model) |model| {
            std.debug.print("get model: {any}\n", .{model});
            const new_value = Godot.Variant.initFrom(model);
            value.* = new_value;
            return true;
        } else {
            value.* = Godot.Variant.init();
            return true;
        }
    }

    return false;
}
