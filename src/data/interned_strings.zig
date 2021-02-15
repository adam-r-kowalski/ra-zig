const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;

pub const InternedStrings = struct {
    data: List([]const u8),
    mapping: Map([]const u8, usize),
    arena: *Arena,

    pub fn deinit(self: *InternedStrings) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};

pub fn intern(interned_strings: *InternedStrings, string: []const u8) !usize {
    const result = try interned_strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const string_copy = try interned_strings.arena.allocator.dupe(u8, string);
    result.entry.key = string_copy;
    const index = try interned_strings.data.insert(string_copy);
    result.entry.value = index;
    return index;
}

pub const Strings = enum(usize) {
    Fn,
    Args,
    Ret,
    Body,
    If,
    Const,
};

pub fn prime(allocator: *Allocator) !InternedStrings {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    var interned_strings = InternedStrings{
        .arena = arena,
        .data = List([]const u8).init(&arena.allocator),
        .mapping = Map([]const u8, usize).init(&arena.allocator),
    };
    const fn_symbol = try intern(&interned_strings, "fn");
    const args_keyword = try intern(&interned_strings, ":args");
    const ret_keyword = try intern(&interned_strings, ":ret");
    const body_keyword = try intern(&interned_strings, ":body");
    const if_symbol = try intern(&interned_strings, "if");
    const const_symbol = try intern(&interned_strings, "const");
    assert(fn_symbol == @enumToInt(Strings.Fn));
    assert(args_keyword == @enumToInt(Strings.Args));
    assert(ret_keyword == @enumToInt(Strings.Ret));
    assert(body_keyword == @enumToInt(Strings.Body));
    assert(if_symbol == @enumToInt(Strings.If));
    assert(const_symbol == @enumToInt(Strings.Const));
    return interned_strings;
}
