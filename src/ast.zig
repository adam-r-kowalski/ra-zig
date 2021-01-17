const std = @import("std");
const list = @import("list.zig");
const List = list.List;

pub const Kind = enum(u8) {
    Int,
    Symbol,
    Keyword,
    Parens,
};

pub const Ast = struct {
    kinds: List(Kind),
    indices: List(usize),
    literals: List([]const u8),
    children: List([]const usize),
    top_level: List(usize),
};

pub fn init(allocator: *std.mem.Allocator) Ast {
    return .{
        .kinds = list.init(Kind, allocator),
        .indices = list.init(usize, allocator),
        .literals = list.init([]const u8, allocator),
        .children = list.init([]const usize, allocator),
        .top_level = list.init(usize, allocator),
    };
}
