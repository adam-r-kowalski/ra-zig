const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;

pub const InternedString = usize;

pub const InternedStrings = struct {
    data: List([]const u8),
    mapping: Map([]const u8, InternedString),
    arena: *Arena,

    pub fn deinit(self: *InternedStrings) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};

pub fn internString(interned_strings: *InternedStrings, string: []const u8) !InternedString {
    const result = try interned_strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const string_copy = try interned_strings.arena.allocator.dupe(u8, string);
    result.entry.key = string_copy;
    const index = try interned_strings.data.insert(string_copy);
    result.entry.value = index;
    return index;
}

pub const Strings = enum(InternedString) {
    Fn,
    Args,
    Ret,
    Body,
    If,
    Const,
    I64,
    F64,
    Add,
    Subtract,
    Multiply,
    Divide,
    Print,
};

pub fn prime(allocator: *Allocator) !InternedStrings {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    var interned_strings = InternedStrings{
        .arena = arena,
        .data = List([]const u8).init(&arena.allocator),
        .mapping = Map([]const u8, InternedString).init(&arena.allocator),
    };
    _ = try internString(&interned_strings, "fn");
    _ = try internString(&interned_strings, ":args");
    _ = try internString(&interned_strings, ":ret");
    _ = try internString(&interned_strings, ":body");
    _ = try internString(&interned_strings, "if");
    _ = try internString(&interned_strings, "const");
    _ = try internString(&interned_strings, "i64");
    _ = try internString(&interned_strings, "f64");
    _ = try internString(&interned_strings, "+");
    _ = try internString(&interned_strings, "-");
    _ = try internString(&interned_strings, "*");
    _ = try internString(&interned_strings, "/");
    _ = try internString(&interned_strings, "print");
    return interned_strings;
}
