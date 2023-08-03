const std = @import("std");
const builtin = @import("builtin");

const js = @import("sysjs");

pub const Value = js.Value;
pub const Function = js.Function;

const BindingError = error{
    WrongPropertyType,
    WrongIndexedType,
    WrongReturnType,
};

fn tagFromType(comptime Type: type) Value.Tag {
    return switch (Type) {
        Object, Array => .object,
        String => .string,
        Function => .func,
        bool => .bool,
        void => .undefined,
        else => switch (@typeInfo(Type)) {
            .Int, .Float, .Enum => .num,
            else => {
                @compileLog("Type: ", @typeInfo(Type));
                @compileError("Invalid type");
            },
        },
    };
}

fn typeFromValue(comptime Type: type, value: *const js.Value) Type {
    return switch (comptime Type) {
        Object => Object{ .obj = value.view(.object) },
        Array => Array{ .obj = value.view(.object) },
        String => value.view(.string),
        Value => value,
        bool => value.view(.bool),
        void => void,
        else => switch (@typeInfo(Type)) {
            .Int => @floatToInt(Type, value.view(.num)), // Should really check this is safe.
            .Float => @floatCast(Type, value.view(.num)),
            .Enum => |e| @intToEnum(Type, @floatToInt(e.tag_type, value.view(.num))),
            else => {
                @compileLog("Type: ", @typeInfo(Type));
                @compileError("Invalid type");
            },
        },
    };
}

pub const Object = struct {
    obj: js.Object,

    const Self = @This();

    pub fn fromRef(ref: u64) Self {
        return Self{ .obj = js.Object{ .ref = ref } };
    }

    /// Return the Object as a generic Value.
    pub fn toValue(self: *const Self) Value {
        return Value{ .tag = .object, .val = .{ .ref = self.obj.ref } };
    }

    /// Retrieve the value of the given property.
    pub fn get(self: *const Self, property: []const u8, comptime Type: type) !Type {
        comptime var param_tag = tagFromType(Type);
        const value: Value = self.obj.get(property);

        // If in debug mode check that the property type is as expected.
        if (comptime builtin.mode == .Debug) {
            if (!value.is(param_tag)) {
                return BindingError.WrongPropertyType;
            }
        }

        return typeFromValue(Type, &value);
    }

    /// Call the given method.
    pub fn call(self: *const Self, comptime method: []const u8, args: anytype, comptime ReturnType: type) !ReturnType {
        comptime var return_tag = tagFromType(ReturnType);

        var arg_vals: [args.len]Value = undefined;
        inline for (args.*) |arg, i| {
            if (@TypeOf(arg) == Value) {
                arg_vals[i] = arg;
            } else {
                arg_vals[i] = arg.toValue();
            }
        }

        const result: Value = self.obj.call(method, &arg_vals);

        if (comptime builtin.mode == .Debug) {
            if (!result.is(return_tag)) {
                return BindingError.WrongReturnType;
            }
        }

        return typeFromValue(ReturnType, &result);
    }
};

pub const String = struct {
    str: js.String,

    const Self = @This();

    pub fn from(str: []const u8) Self {
        return Self{
            .str = js.createString(str),
        };
    }

    /// Return the String as a generic Value.
    pub fn toValue(self: *const Self) Value {
        return Value{ .tag = .str, .val = .{ .ref = self.str.ref } };
    }

    pub fn length(self: *const Self) usize {
        return self.str.getLength();
    }
};

pub const Array = struct {
    obj: js.Object,

    const Self = @This();

    pub fn new() Self {
        return Self{
            .obj = js.createArray(),
        };
    }

    pub fn fromRef(ref: u64) Self {
        return Self{ .obj = js.Object{ .ref = ref } };
    }

    /// Return the Array as a generic Value.
    pub fn toValue(self: *const Self) Value {
        return Value{ .tag = .object, .val = .{ .ref = self.obj.ref } };
    }

    pub fn get(self: *const Self, index: u32, comptime Type: type) !Type {
        comptime var param_tag = tagFromType(Type);
        const value: Value = self.obj.getIndex(index);

        // If in debug mode check that the property type is as expected.
        if (comptime builtin.mode == .Debug) {
            if (!value.is(param_tag)) {
                return BindingError.WrongIndexedType;
            }
        }

        return typeFromValue(Type, &value);
    }

    pub fn set(self: *const Self, index: u32, value: anytype) void {
        if (@TypeOf(value) == Value) {
            self.obj.setIndex(index, value);
        } else {
            self.obj.setIndex(index, value.toValue());
        }
    }

    pub fn del(self: *const Self, index: u32) void {
        self.obj.deleteIndex(index);
    }
};
