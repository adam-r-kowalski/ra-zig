const std = @import("std");
const list = @import("list.zig");
const List = list.List;

pub const Kind = enum(u8) {
    Int,
    Symbol,
    Keyword,
    Parens,
    Brackets,
};

pub const Ast = struct {
    kinds: List(Kind),
    indices: List(usize),
    children: List([]const usize),
    top_level: List(usize),
};

pub fn init(allocator: *std.mem.Allocator) Ast {
    return .{
        .kinds = list.init(Kind, allocator),
        .indices = list.init(usize, allocator),
        .children = list.init([]const usize, allocator),
        .top_level = list.init(usize, allocator),
    };
}
