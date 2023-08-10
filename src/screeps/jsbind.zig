const std = @import("std");
const logging = std.log.scoped(.main);
const builtin = @import("builtin");

const sysjs = @import("sysjs");

pub const JSTag = sysjs.Value.Tag;
pub const JSValue = sysjs.Value;
pub const JSFunction = sysjs.Function;

pub const createNumber = sysjs.createNumber;

/// Description
/// -----------
/// Defines and checks conformance to the interface required for types to interoperate with this
/// module.
///
/// Parameters
/// ----------
/// T: Type to check for conformance.
///
/// Returns
/// ------
/// True if the type conforms, false otherwise.
///
pub fn assertIsJSObjectReference(comptime T: type) void {
    comptime var type_name = @typeName(T);

    if (!@hasDecl(T, "jstag")) {
        @compileError(comptime std.fmt.comptimePrint("Type '{s}' doesn't implement jstag declaration", .{type_name}));
    }

    if (!(@TypeOf(T.jstag) == sysjs.Value.Tag)) {
        @compileError(std.fmt.comptimePrint("Type '{s}' implements jstag declaration but declaration is wrong type", .{@typeName(T)}));
    }

    if (!@hasDecl(T, "fromValue")) {
        @compileError(comptime std.fmt.comptimePrint("Type '{s}' doesn't implement fromValue", .{type_name}));
    }

    if (!@hasDecl(T, "asValue")) {
        @compileError(comptime std.fmt.comptimePrint("Type '{s}' doesn't implement asValue", .{type_name}));
    }
}

fn tagFromType(comptime T: type) sysjs.Value.Tag {
    return switch (T) {
        JSFunction => .func,
        bool => .bool,
        void => .undefined,
        else => switch (@typeInfo(T)) {
            .Int, .Float => .num,
            .Struct, .Enum => {
                assertIsJSObjectReference(T);
                return T.jstag;
            },
            else => {
                @compileLog("Type: ", @typeName(T));
                @compileError("Invalid type");
            },
        },
    };
}

fn typeFromValue(comptime T: type, value: *const sysjs.Value) T {
    return switch (comptime T) {
        JSFunction => value.view(.func),
        sysjs.Value => value,
        bool => value.view(.bool),
        void => void{},
        else => switch (@typeInfo(T)) {
            .Int => @floatToInt(T, value.view(.num)), // Should really check this is safe.
            .Float => @floatCast(T, value.view(.num)),
            .Struct, .Enum => {
                assertIsJSObjectReference(T);
                return T.fromValue(value);
            },
            else => {
                @compileLog("Type: ", @typeName(T));
                @compileError("Invalid type");
            },
        },
    };
}

pub const JSObject = struct {
    obj: sysjs.Object,

    const Self = @This();
    const jstag = sysjs.Value.Tag.object;

    comptime {
        assertIsJSObjectReference(Self);
    }

    /// Description
    /// -----------
    /// Return a new Object referencing a newly constructed, empty Javascript object.
    ///
    /// Returns
    /// -------
    /// New object.
    ///
    pub fn init() Self {
        const global = Self{ .obj = sysjs.global() };
        return global.call("Object", &.{}, Self);
    }

    /// Description
    /// -----------
    /// Return a new Object from a generic value referencing an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    pub fn fromValue(value: *const sysjs.Value) Self {
        return Self{ .obj = value.view(.object) };
    }

    /// Description
    /// -----------
    /// Return a generic Value referening this Javascript object.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) sysjs.Value {
        return sysjs.Value{ .tag = .object, .val = .{ .ref = self.obj.ref } };
    }

    /// Description
    /// -----------
    /// Return a new Object from a reference to an existing Javascript object.
    ///
    /// Parameters
    /// ----------
    /// - ref: Reference of the javascript object.
    ///
    pub fn fromRef(ref: u64) Self {
        return Self{ .obj = sysjs.Object{ .ref = ref } };
    }

    /// Retrieve the value of the given property.
    pub fn get(self: *const Self, property: []const u8, comptime T: type) T {
        comptime var param_tag = tagFromType(T);
        const value: sysjs.Value = self.obj.get(property);

        // If in debug mode check that the property type is as expected.
        if (comptime builtin.mode == .Debug) {
            if (!value.is(param_tag)) {
                logging.err("Wrong property type when fetching property '{s}'. Expected '{s}'. Found '{s}'", .{ property, @typeName(T), @tagName(value.tag) });
                @panic("Wrong property type");
            }
        }

        return typeFromValue(T, &value);
    }

    pub fn set(self: *const Self, property: []const u8, value: anytype) void {
        if (@TypeOf(value) == sysjs.Value) {
            self.obj.set(property, value);
        } else {
            self.obj.set(property, value.asValue());
        }
    }

    pub fn getValues(self: *const Self, comptime T: type) JSArray(T) {
        const global = Self{ .obj = sysjs.global() };

        // Mach-sysjs picks this up as a function but it's really a type.
        // Need manually convert it to an object.
        const object_func = global.get("Object", JSFunction);
        const object_type = Self{ .obj = sysjs.Object{ .ref = object_func.ref } };

        return object_type.call("values", &.{self}, JSArray(T));
    }

    /// Call the given method.
    pub fn call(self: *const Self, comptime method: []const u8, args: anytype, comptime ReturnType: type) ReturnType {
        comptime var return_tag = tagFromType(ReturnType);

        var arg_vals: [args.len]sysjs.Value = undefined;
        inline for (args.*) |arg, i| {
            if (@TypeOf(arg) == sysjs.Value) {
                arg_vals[i] = arg;
            } else {
                arg_vals[i] = arg.asValue();
            }
        }

        const result: sysjs.Value = self.obj.call(method, &arg_vals);

        if (comptime builtin.mode == .Debug) {
            if (!result.is(return_tag)) {
                logging.err("Wrong return type when calling method '{s}'. Expected '{s}'. Found '{s}'", .{ method, @typeName(ReturnType), @tagName(result.tag) });
                @panic("Wrong return type");
            }
        }

        return typeFromValue(ReturnType, &result);
    }
};

pub fn JSObjectReference(comptime Self: type) type {
    return struct {
        pub const jstag = sysjs.Value.Tag.object;

        /// Description
        /// -----------
        /// Return a new Source from a generic value referencing an existing Javascript object.
        ///
        /// Parameters
        /// ----------
        /// - value: Generic value type.
        ///
        /// Returns
        /// -------
        /// New Source referencing an existing Javascript object.
        ///
        pub fn fromValue(value: *const sysjs.Value) Self {
            return Self{ .obj = JSObject.fromValue(value) };
        }

        /// Description
        /// -----------
        /// Return a generic Value referening this Javascript object.
        ///
        /// Returns
        /// -------
        /// Generic value referencing the Javascript object.
        ///
        pub fn asValue(self: *const Self) sysjs.Value {
            return self.obj.asValue();
        }
    };
}

pub fn jsObjectProperty(comptime Self: type, comptime name: []const u8, comptime T: type) fn (*const Self) T {
    const Object = struct {
        pub fn getter(self: *const Self) T {
            return self.obj.get(name, T);
        }
    };

    return Object.getter;
}

pub const JSString = struct {
    str: sysjs.String,

    const Self = @This();
    const jstag = sysjs.Value.Tag.str;

    comptime {
        assertIsJSObjectReference(Self);
    }

    pub fn from(str: []const u8) Self {
        return Self{
            .str = sysjs.createString(str),
        };
    }

    /// Description
    /// -----------
    /// Return a new String from a generic value referencing an existing Javascript string object.
    ///
    /// Parameters
    /// ----------
    /// - value: Generic value type.
    ///
    pub fn fromValue(value: *const sysjs.Value) Self {
        return Self{ .str = value.view(.str) };
    }

    /// Description
    /// -----------
    /// Return a generic Value referening this Javascript string object.
    ///
    /// Returns
    /// -------
    /// Generic value referencing the Javascript object.
    ///
    pub fn asValue(self: *const Self) sysjs.Value {
        return sysjs.Value{ .tag = .str, .val = .{ .ref = self.str.ref } };
    }

    pub fn length(self: *const Self) usize {
        return self.str.getLength();
    }

    pub fn getOwnedSlice(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        return self.str.getOwnedSlice(allocator);
    }
};

/// Description
/// -----------
/// An interface to a Javascript array like object containing values of type T.
///
pub fn JSArray(comptime T: type) type {
    return struct {
        obj: sysjs.Object,

        const Self = @This();
        const jstag = sysjs.Value.Tag.object;

        comptime {
            assertIsJSObjectReference(Self);
        }

        /// Description
        /// -----------
        /// Return a new Array by contstructing a new Javascript array like object.
        ///
        pub fn new() Self {
            return Self{
                .obj = sysjs.createArray(),
            };
        }

        /// Description
        /// -----------
        /// Return a new Array from a generic value referencing an existing Javascript array like
        /// object.
        ///
        /// Parameters
        /// ----------
        /// - value: Generic value type.
        ///
        pub fn fromValue(value: *const sysjs.Value) Self {
            return Self{ .obj = value.view(.object) };
        }

        /// Description
        /// -----------
        /// Return a generic Value referening this Javascript adrray like object.
        ///
        /// Returns
        /// -------
        /// Generic value referencing the Javascript object.
        ///
        pub fn asValue(self: *const Self) sysjs.Value {
            return sysjs.Value{ .tag = .object, .val = .{ .ref = self.obj.ref } };
        }

        /// Description
        /// -----------
        /// Return the item at the given index.
        ///
        /// Parameters
        /// ----------
        /// - index: Index of the item.
        ///
        /// Returns
        /// -------
        /// The item or BindingError.WrongIndexedType.
        ///
        pub fn get(self: *const Self, index: u32) T {
            const value: sysjs.Value = self.obj.getIndex(index);

            // If in debug mode check that the property type is as expected.
            if (comptime builtin.mode == .Debug) {
                if (!value.is(comptime tagFromType(T))) {
                    logging.err("Wrong return type when fetching array element '{d}'. Expected '{s}'. Found '{s}'", .{ index, @typeName(T), @tagName(value.tag) });
                    @panic("Wrong indexed type");
                }
            }

            return typeFromValue(T, &value);
        }

        /// Description
        /// -----------
        /// Add an item at the given index.
        ///
        /// Parameters
        /// ----------
        /// - index: Index to add the item at.
        /// - value: Value of the item.
        ///
        pub fn set(self: *const Self, index: u32, value: T) void {
            if (T == sysjs.Value) {
                self.obj.setIndex(index, value);
            } else {
                self.obj.setIndex(index, value.asValue());
            }
        }

        /// Description
        /// -----------
        /// Delete the item at the given index.
        ///
        /// Parameters
        /// ----------
        /// - index: Index of the item to delete.
        ///
        pub fn del(self: *const Self, index: u32) void {
            self.obj.deleteIndex(index);
        }

        /// Description
        /// -----------
        /// Return the length of the array.
        ///
        /// Returns
        /// -------
        /// Number of items in the array.
        ///
        pub fn len(self: *const Self) usize {
            return self.obj.attributeCount();
        }

        /// Description
        /// -----------
        /// Return a new iterator.
        ///
        /// Returns
        /// -------
        /// New ArrayIterator.
        ///
        pub fn iterate(self: *const Self) JSArrayIterator(T) {
            return JSArrayIterator(T){
                .array = self,
                .len = self.len(),
            };
        }

        pub fn getOwnedSlice(self: *const Self, allocator: std.mem.Allocator) ![]T {
            var memory = try allocator.alloc(T, self.len());
            errdefer allocator.free(memory);

            for (memory) |*element, i| {
                element.* = self.get(i);
            }

            return memory;
        }
    };
}

/// Description
/// -----------
/// Iterator over a Javascript arrays elements.
///
pub fn JSArrayIterator(comptime T: type) type {
    return struct {
        array: *const JSArray(T),
        len: usize,
        i: usize = 0,

        const Self = @This();

        /// Description
        /// -----------
        /// Return the next item in the array.
        ///
        /// Returns
        /// -------
        /// One of the following:
        /// - The next item.
        /// - Null if there are no more items in the array.
        /// - BindingError.WrongIndexedType
        ///
        pub fn next(self: *Self) !?T {
            if (self.i == self.len) {
                return null;
            }

            const value = try self.array.get(self.i);
            self.i += 1;

            return value;
        }
    };
}
