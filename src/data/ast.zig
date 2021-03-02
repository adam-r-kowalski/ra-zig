const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;

pub const Source = struct {
    input: []const u8
};

pub const Kind = enum(u8) {
    Int,
    Float,
    Symbol,
    Keyword,
    Parens,
    Brackets,
};

pub const Ast = struct {
    kinds: List(Kind),
    indices: List(usize),
    children: List(List(usize)),
    top_level: List(usize),
    arena: *Arena,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
