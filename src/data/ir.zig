const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Map = @import("map.zig").Map;
const List = @import("list.zig").List;
const InternedString = @import("interned_strings.zig").InternedString;

pub const Entity = usize;

pub const Scopes = enum(usize) {
    External,
    Function,
};

pub const Builtins = enum(usize) {
    If,
    Const,
    Int,
    I64,
    Float,
    F64,
};

const String = []const u8;

pub const Scope = struct {
    name_to_entity: Map(InternedString, Entity),
    entities: List(Entity),
};

pub const ExpressionKind = enum(u8) {
    Return,
    Call,
    Branch,
    Phi,
    Jump,
};

pub const LiteralKind = enum(u8) {
    Int,
    Float,
};

pub const Call = struct {
    result_entity: Entity,
    function_entity: Entity,
    argument_entities: []const Entity,
};

pub const Branch = struct {
    condition_entity: Entity,
    then_block_index: usize,
    else_block_index: usize,
};

pub const Phi = struct {
    result_entity: Entity,
    then_block_index: usize,
    then_entity: Entity,
    else_block_index: usize,
    else_entity: Entity,
};

pub const Block = struct {
    active_scopes: []const usize,
    kinds: List(ExpressionKind),
    indices: List(usize),
    returns: List(Entity),
    calls: List(Call),
    branches: List(Branch),
    phis: List(Phi),
    jumps: List(usize),
};

pub const Entities = struct {
    names: Map(Entity, InternedString),
    values: Map(Entity, InternedString),
    kinds: Map(Entity, LiteralKind),
    next_entity: Entity,
};

pub const Overload = struct {
    parameter_entities: []const InternedString,
    parameter_type_block_indices: []const usize,
    return_type_block_index: usize,
    body_block_index: usize,
    scopes: List(Scope),
    blocks: List(Block),
    entities: Entities,
};

pub const Function = List(Overload);

pub const DeclarationKind = enum(u8) {
    Function,
};

pub const Ir = struct {
    name_to_index: Map(InternedString, usize),
    kinds: List(DeclarationKind),
    names: List(InternedString),
    indices: List(usize),
    functions: List(Function),
    arena: *Arena,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
