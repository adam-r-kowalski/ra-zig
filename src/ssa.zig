const std = @import("std");
const list = @import("list.zig");
const List = list.List;

pub const Kind = enum(u8) {
    Function,
};

pub const Overload = struct {
    parameter_names: []const usize,
};

pub const Function = List(Overload);

pub const Ssa = struct {
    name_to_index: std.AutoHashMap(usize, usize),
    kinds: List(Kind),
    names: List(usize),
    indices: List(usize),
    functions: List(Function),
};

pub fn init(allocator: *std.mem.Allocator) Ssa {
    return .{
        .name_to_index = std.AutoHashMap(usize, usize).init(allocator),
        .kinds = List(Kind).init(allocator),
        .names = List(usize).init(allocator),
        .indices = List(usize).init(allocator),
        .functions = List(Function).init(allocator),
    };
}
