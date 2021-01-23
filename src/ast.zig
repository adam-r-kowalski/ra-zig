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
        .kinds = List(Kind).init(allocator),
        .indices = List(usize).init(allocator),
        .children = List([]const usize).init(allocator),
        .top_level = List(usize).init(allocator),
    };
}
