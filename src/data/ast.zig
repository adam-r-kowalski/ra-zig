const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;

pub const Strings = enum(usize) {
    Fn,
    Args,
    Ret,
    Body,
    If,
    Const,
};

pub const Source = struct {
    input: []const u8
};

pub const Kind = enum(u8) {
    Int,
    Symbol,
    Keyword,
    Parens,
    Brackets,
};

pub const InternedStrings = struct {
    data: List([]const u8),
    mapping: Map([]const u8, usize),
};

pub const Ast = struct {
    kinds: List(Kind),
    indices: List(usize),
    children: List(List(usize)),
    top_level: List(usize),
    interned_strings: InternedStrings,
    arena: *Arena,
};
