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

pub const Builtins = enum(Entity) {
    Special_Form,
    Fn,
    If,
    Let,
    Var,
    Set_bang_,
    Type,
    Int,
    I64,
    I32,
    I8,
    U8,
    Float,
    F64,
    F32,
    Array,
    Ptr,
    Void,
    Null,
    Add,
    Sub,
    Mul,
    Div,
    Equal,
    Bit_Or,
    Print,
    Open,
    Close,
    Lseek,
    Mmap,
    Munmap,
    Read,
    Deref,
    Greater_query_,
};

pub const names = blk: {
    const fields = @typeInfo(Builtins).Enum.fields;
    var data: [fields.len][]const u8 = undefined;
    for (fields) |field, field_index| {
        var name: [field.name.len]u8 = undefined;
        var name_index: usize = 0;
        var length: usize = 0;
        while (name_index < field.name.len) {
            const c = field.name[name_index];
            switch (c) {
                'A'...'Z' => name[name_index] = std.ascii.toLower(c),
                '_' => {
                    if ((field.name.len - 5 > name_index) and std.mem.eql(u8, field.name[name_index .. name_index + 6], "_bang_")) {
                        name[name_index] = '!';
                        name_index += 6;
                        length += 1;
                        continue;
                    } else if ((field.name.len - 6 > name_index) and std.mem.eql(u8, field.name[name_index .. name_index + 7], "_query_")) {
                        name[name_index] = '?';
                        name_index += 7;
                        length += 1;
                        continue;
                    } else {
                        name[name_index] = '-';
                    }
                },
                else => name[name_index] = c,
            }
            name_index += 1;
            length += 1;
        }
        data[field_index] = name[0..length];
    }
    break :blk data;
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

fn loadBuiltinEntities(entities: *Entities) !void {
    for (names) |name, i| {
        const interned_string = try internString(entities, name);
        try entities.names.putNoClobber(i, interned_string);
    }
    for ([_]Builtins{ .Fn, .If, .Let, .Set_bang_ }) |entity| {
        try entities.types.putNoClobber(@enumToInt(entity), @enumToInt(Builtins.Special_Form));
    }
    for ([_]Builtins{ .Type, .Int, .I64, .I32, .U8, .Float, .F64, .Array, .Ptr, .Void }) |entity| {
        try entities.types.putNoClobber(@enumToInt(entity), @enumToInt(Builtins.Type));
    }
    for ([_]Builtins{ .I64, .F64, .Array, .Ptr }) |entity| {
        try entities.sizes.putNoClobber(@enumToInt(entity), 8);
    }
    for ([_]Builtins{ .I32, .F32 }) |entity| {
        try entities.sizes.putNoClobber(@enumToInt(entity), 4);
    }
    for ([_]Builtins{ .I8, .U8 }) |entity| {
        try entities.sizes.putNoClobber(@enumToInt(entity), 1);
    }
    const Null = @enumToInt(Builtins.Null);
    const null_type = entities.next_entity;
    entities.next_entity += 1;
    try entities.types.putNoClobber(Null, null_type);
    try entities.types.putNoClobber(null_type, @enumToInt(Builtins.Type));
    try entities.values.putNoClobber(null_type, @enumToInt(Builtins.Ptr));
    const index = try entities.pointers.insert(@enumToInt(Builtins.Void));
    try entities.pointer_index.putNoClobber(null_type, index);
    const zero = try internString(entities, "0");
    try entities.literals.putNoClobber(Null, zero);
}

pub const Entities = struct {
    names: Map(Entity, InternedString),
    literals: Map(Entity, InternedString),
    types: Map(Entity, Entity),
    values: Map(Entity, Entity),
    sizes: Map(Entity, usize),
    overload_index: Map(Entity, usize),
    array_index: Map(Entity, usize),
    pointer_index: Map(Entity, usize),
    mutable: Map(Entity, bool),
    rootMutableEntity: Map(Entity, Entity),
    next_entity: Entity,
    interned_strings: InternedStrings,
    overloads: Overloads,
    arrays: Arrays,
    pointers: List(Entity),
    arena: *Arena,

    pub fn init(allocator: *Allocator) !Entities {
        const arena = try allocator.create(Arena);
        arena.* = Arena.init(allocator);
        const next_id = @typeInfo(Builtins).Enum.fields.len;
        var entities = Entities{
            .names = Map(Entity, InternedString).init(&arena.allocator),
            .literals = Map(Entity, InternedString).init(&arena.allocator),
            .types = Map(Entity, Entity).init(&arena.allocator),
            .values = Map(Entity, Entity).init(&arena.allocator),
            .sizes = Map(Entity, usize).init(&arena.allocator),
            .overload_index = Map(Entity, usize).init(&arena.allocator),
            .array_index = Map(Entity, usize).init(&arena.allocator),
            .pointer_index = Map(Entity, usize).init(&arena.allocator),
            .mutable = Map(Entity, bool).init(&arena.allocator),
            .rootMutableEntity = Map(Entity, Entity).init(&arena.allocator),
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
            .pointers = List(Entity).init(&arena.allocator),
            .arena = arena,
        };
        try loadBuiltinEntities(&entities);
        return entities;
    }

    pub fn deinit(self: *Entities) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
