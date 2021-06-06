const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Map = @import("map.zig").Map;
const List = @import("list.zig").List;
const entity = @import("entity.zig");
const InternedString = entity.InternedString;
const Entity = entity.Entity;

pub const Scopes = enum(usize) {
    External,
    Function,
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
    TypedLet,
    CopyingLet,
    CopyingTypedLet,
};

pub const Call = struct {
    result_entity: Entity,
    function_entity: Entity,
    argument_entities: []const Entity,
};

pub const Branch = struct {
    condition_entity: Entity,
    then_block_index: usize,
    then_entity: Entity,
    else_block_index: usize,
    else_entity: Entity,
    phi_block_index: usize,
    phi_entity: Entity,
};

pub const Phi = struct {
    phi_entity: Entity,
    then_block_index: usize,
    then_entity: Entity,
    else_block_index: usize,
    else_entity: Entity,
};

pub const TypedLet = struct {
    entity: Entity,
    type_entity: Entity,
};

pub const CopyingLet = struct {
    destination_entity: Entity,
    source_entity: Entity,
};

pub const CopyingTypedLet = struct {
    destination_entity: Entity,
    source_entity: Entity,
    type_entity: Entity,
};

pub const Block = struct {
    active_scopes: []const usize,
    kinds: List(ExpressionKind),
    indices: List(usize),
    returns: List(Entity),
    typed_lets: List(TypedLet),
    copying_lets: List(CopyingLet),
    copying_typed_lets: List(CopyingTypedLet),
    calls: List(Call),
    branches: List(Branch),
    phis: List(Phi),
    jumps: List(usize),
};

pub const Overload = struct {
    parameter_entities: []const InternedString,
    parameter_type_block_indices: []const usize,
    return_type_block_index: usize,
    body_block_index: usize,
    scopes: List(Scope),
    blocks: List(Block),
};

pub const Function = struct {
    overloads: List(Overload),
    entities: List(usize),
};

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
