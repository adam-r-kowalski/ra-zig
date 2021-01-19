const std = @import("std");
const list = @import("list.zig");
const List = list.List;

pub const Kind = enum(u8) {
    OverloadSet,
};

pub const Function = struct {
    parameter_names: []const usize,
};

pub const Ssa = struct {
    contents: std.AutoHashMap(usize, usize),
    kinds: List(Kind),
    names: List(usize),
    indices: List(usize),
    overload_sets: List(List(Function)),
};

pub fn init(allocator: *std.mem.Allocator) Ssa {
    return .{
        .contents = std.AutoHashMap(usize, usize).init(allocator),
        .kinds = list.init(Kind, allocator),
        .names = list.init(usize, allocator),
        .indices = list.init(usize, allocator),
        .overload_sets = list.init(List(Function), allocator),
    };
}
