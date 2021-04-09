const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Map = @import("map.zig").Map;
const List = @import("list.zig").List;

pub const InternedString = usize;

pub const InternedStrings = struct {
    data: List([]const u8),
    mapping: Map([]const u8, InternedString),
};

pub const Entity = usize;

pub const Builtins = enum(Entity) {
    If,
    Const,
    Int,
    I64,
    Float,
    F64,
};

pub const LiteralKind = enum(u8) {
    Int,
    Float,
};

pub fn internString(entities: *Entities, string: []const u8) !InternedString {
    const result = try entities.interned_strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const string_copy = try entities.arena.allocator.dupe(u8, string);
    result.entry.key = string_copy;
    const index = try entities.interned_strings.data.insert(string_copy);
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
    Int,
    I64,
    Float,
    F64,
    Add,
    Subtract,
    Multiply,
    Divide,
    Print,
};

pub const Entities = struct {
    names: Map(Entity, InternedString),
    literals: Map(Entity, InternedString),
    kinds: Map(Entity, LiteralKind),
    next_entity: Entity,
    interned_strings: InternedStrings,
    arena: *Arena,

    pub fn init(allocator: *Allocator) !Entities {
        const arena = try allocator.create(Arena);
        arena.* = Arena.init(allocator);
        const next_id = @typeInfo(Builtins).Enum.fields.len;
        var entities = Entities{
            .names = Map(Entity, InternedString).init(&arena.allocator),
            .literals = Map(Entity, InternedString).init(&arena.allocator),
            .kinds = Map(Entity, LiteralKind).init(&arena.allocator),
            .next_entity = next_id,
            .interned_strings = InternedStrings{
                .data = List([]const u8).init(&arena.allocator),
                .mapping = Map([]const u8, InternedString).init(&arena.allocator),
            },
            .arena = arena,
        };
        _ = try internString(&entities, "fn");
        _ = try internString(&entities, ":args");
        _ = try internString(&entities, ":ret");
        _ = try internString(&entities, ":body");
        _ = try internString(&entities, "if");
        _ = try internString(&entities, "const");
        _ = try internString(&entities, "int");
        _ = try internString(&entities, "i64");
        _ = try internString(&entities, "float");
        _ = try internString(&entities, "f64");
        _ = try internString(&entities, "+");
        _ = try internString(&entities, "-");
        _ = try internString(&entities, "*");
        _ = try internString(&entities, "/");
        _ = try internString(&entities, "print");
        return entities;
    }

    pub fn deinit(self: *Entities) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
