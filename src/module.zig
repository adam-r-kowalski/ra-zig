const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;

const String = []const u8;

pub fn Map(comptime Key: type, comptime Value: type) type {
    return if (Key == []const u8) std.StringHashMap(Value) else std.AutoHashMap(Key, Value);
}

const Name = usize;

pub const Scope = struct {
    name_to_index: Map(Name, usize),
};

pub const BasicBlock = struct {
    const Kind = enum(u8) {
        Call,
        Return,
    };

    kind: []const Kind,
};

pub const Overload = struct {
    parameter_names: []const Name,
    parameter_type_blocks: []const usize,
    scopes: List(Scope),
    basic_blocks: List(BasicBlock),
};

pub const Function = List(Overload);

pub const Ssa = struct {
    pub const Kind = enum(u8) {
        Function,
    };

    name_to_index: Map(Name, usize),
    kinds: List(Kind),
    names: List(Name),
    indices: List(usize),
    functions: List(Function),

    pub fn init(allocator: *Allocator) Ssa {
        return .{
            .name_to_index = Map(Name, usize).init(allocator),
            .kinds = List(Kind).init(allocator),
            .names = List(Name).init(allocator),
            .indices = List(usize).init(allocator),
            .functions = List(Function).init(allocator),
        };
    }
};

pub const Module = struct {
    parent_allocator: *Allocator,
    arena: *Arena,
    ast: Ast,
    strings: Strings,
    ssa: Ssa,

    pub fn init(allocator: *Allocator) !Module {
        const arena = try allocator.create(Arena);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        return Module{
            .parent_allocator = allocator,
            .arena = arena,
            .ast = Ast.init(&arena.allocator),
            .strings = Strings.init(&arena.allocator),
            .ssa = Ssa.init(&arena.allocator),
        };
    }

    pub fn deinit(module: *Module) void {
        module.arena.deinit();
        module.parent_allocator.destroy(module.arena);
    }
};
