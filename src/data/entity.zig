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
    Let,
    Int,
    I64,
    I32,
    U8,
    Float,
    F64,
    Array,
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
    Let,
    Int,
    I64,
    Float,
    F64,
    Add,
    Sub,
    Mul,
    Div,
    BitOr,
    Print,
    Open,
    Lseek,
};

pub const Status = enum { Unanalyzed, Analyzed };

pub const Overloads = struct {
    status: List(Status),
    parameter_types: List([]const Entity),
    return_type: List(Entity),
    block: List(usize),
};

pub const Arrays = struct {
    types: List(Entity),
    lengths: List(usize),
};

pub const Entities = struct {
    names: Map(Entity, InternedString),
    literals: Map(Entity, InternedString),
    types: Map(Entity, Entity),
    overload_index: Map(Entity, usize),
    array_index: Map(Entity, usize),
    next_entity: Entity,
    interned_strings: InternedStrings,
    overloads: Overloads,
    arrays: Arrays,
    arena: *Arena,

    pub fn init(allocator: *Allocator) !Entities {
        const arena = try allocator.create(Arena);
        arena.* = Arena.init(allocator);
        const next_id = @typeInfo(Builtins).Enum.fields.len;
        var entities = Entities{
            .names = Map(Entity, InternedString).init(&arena.allocator),
            .literals = Map(Entity, InternedString).init(&arena.allocator),
            .types = Map(Entity, Entity).init(&arena.allocator),
            .overload_index = Map(Entity, usize).init(&arena.allocator),
            .array_index = Map(Entity, usize).init(&arena.allocator),
            .next_entity = next_id,
            .interned_strings = InternedStrings{
                .data = List([]const u8).init(&arena.allocator),
                .mapping = Map([]const u8, InternedString).init(&arena.allocator),
            },
            .overloads = Overloads{
                .status = List(Status).init(&arena.allocator),
                .parameter_types = List([]const Entity).init(&arena.allocator),
                .return_type = List(Entity).init(&arena.allocator),
                .block = List(usize).init(&arena.allocator),
            },
            .arrays = Arrays{
                .types = List(Entity).init(&arena.allocator),
                .lengths = List(usize).init(&arena.allocator),
            },
            .arena = arena,
        };
        _ = try internString(&entities, "fn");
        _ = try internString(&entities, ":args");
        _ = try internString(&entities, ":ret");
        _ = try internString(&entities, ":body");
        _ = try internString(&entities, "if");
        _ = try internString(&entities, "let");
        _ = try internString(&entities, "int");
        _ = try internString(&entities, "i64");
        _ = try internString(&entities, "float");
        _ = try internString(&entities, "f64");
        _ = try internString(&entities, "add");
        _ = try internString(&entities, "sub");
        _ = try internString(&entities, "mul");
        _ = try internString(&entities, "div");
        _ = try internString(&entities, "bit-or");
        _ = try internString(&entities, "print");
        _ = try internString(&entities, "open");
        _ = try internString(&entities, "lseek");
        return entities;
    }

    pub fn deinit(self: *Entities) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
