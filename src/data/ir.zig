const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Map = @import("map.zig").Map;
const List = @import("list.zig").List;
const InternedString = @import("interned_strings.zig").InternedString;

pub const Scopes = enum(usize) {
    External,
    Function,
};

pub const SpecialForms = enum(usize) {
    If,
    Const,
};

const String = []const u8;

pub const Scope = struct {
    name_to_entity: Map(InternedString, usize),
    entities: List(usize),
};

pub const ExpressionKind = enum(u8) {
    Return,
    Call,
    Branch,
    Phi,
    Jump,
};

pub const Call = struct {
    result_entity: usize,
    function_entity: usize,
    argument_entities: []const usize,
};

pub const Branch = struct {
    condition_entity: usize,
    then_block_index: usize,
    else_block_index: usize,
};

pub const Phi = struct {
    result_entity: usize,
    then_block_index: usize,
    then_entity: usize,
    else_block_index: usize,
    else_entity: usize,
};

pub const Block = struct {
    active_scopes: []const usize,
    kinds: List(ExpressionKind),
    indices: List(usize),
    returns: List(usize),
    calls: List(Call),
    branches: List(Branch),
    phis: List(Phi),
    jumps: List(usize),
};

pub const Entities = struct {
    names: Map(usize, InternedString),
    values: Map(usize, InternedString),
    next_id: usize,
};

pub const Overload = struct {
    parameter_names: []const InternedString,
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
