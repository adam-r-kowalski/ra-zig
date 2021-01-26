const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const parser = @import("parser.zig");
const Ast = parser.Ast;
const AstKind = parser.Kind;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;
const Children = []const usize;

const String = []const u8;

const Name = usize;

pub const Scope = struct {
    name_to_index: Map(Name, usize),
};

const ExpressionKind = enum(u8) {
    Call,
    Return,
};

pub const BasicBlock = struct {
    kind: []const ExpressionKind,
};

pub const Overload = struct {
    parameter_names: []const Name,
    parameter_type_blocks: []const usize,
    scopes: List(Scope),
    basic_blocks: List(BasicBlock),
};

pub const Function = List(Overload);

pub const DeclarationKind = enum(u8) {
    Function,
};

pub const Ssa = struct {
    name_to_index: Map(Name, usize),
    kinds: List(DeclarationKind),
    names: List(Name),
    indices: List(usize),
    functions: List(Function),
    arena: Arena,
};

fn astIndex(ast: Ast, kind: AstKind, entity: usize) usize {
    assert(ast.kinds.items[entity] == kind);
    return ast.indices.items[entity];
}

fn astChildren(ast: Ast, kind: AstKind, entity: usize) Children {
    return ast.children.items[astIndex(ast, kind, entity)].slice();
}

fn astString(ast: Ast, kind: AstKind, entity: usize) []const u8 {
    return ast.strings.data.items[astIndex(ast, kind, entity)];
}

fn lowerParameters(ast: Ast, ssa: *Ssa, overload: *Overload, children: Children) !void {
    assert(children.len > 1);
    assert(std.mem.eql(u8, astString(ast, .Keyword, children[0]), ":args"));
    assert(children.len > 2);
    var parameters = astChildren(ast, .Parens, children[1]);
    assert(parameters.len % 2 == 0);
    const parameter_count = parameters.len / 2;
    const parameter_names = try ssa.arena.allocator.alloc(usize, parameter_count);
    const parameter_type_blocks = try ssa.arena.allocator.alloc(usize, parameter_count);
    var i: usize = 0;
    while (parameters.len > 0) : (i += 1) {
        parameter_names[i] = astIndex(module, .Symbol, parameters[0]);
        const result = try overload.basic_blocks.addOne();
        parameter_type_blocks[i] = result.index;
        parameters = parameters[2..];
    }
    overload.parameter_names = parameter_names;
    overload.parameter_type_blocks = parameter_type_blocks;
}

fn lowerOverload(ssa: *Ssa, ast: Ast, children: Children) !void {
    assert(children.len > 0);
    const name = astIndex(ast, .Symbol, children[0]);
    const get_or_put_result = try ssa.name_to_index.getOrPut(name);
    const function = blk: {
        if (get_or_put_result.found_existing) {
            const index = get_or_put_result.entry.value;
            assert(ssa.kinds.items[index] == .Function);
            const function_index = ssa.indices.items[index];
            break :blk &ssa.functions.items[function_index];
        } else {
            _ = try ssa.kinds.insert(.Function);
            get_or_put_result.entry.value = try ssa.names.insert(name);
            const result = try ssa.functions.addOne();
            result.ptr.* = List(Overload).init(&ssa.arena.allocator);
            _ = try ssa.indices.insert(result.index);
            break :blk result.ptr;
        }
    };
    const overload = (try function.addOne()).ptr;
    overload.scopes = List(Scope).init(&ssa.arena.allocator);
    overload.basic_blocks = List(BasicBlock).init(&ssa.arena.allocator);
    var remaining_children = children[1..];
    while (remaining_children.len > 0) {
        assert(ast.kinds.items[remaining_children[0]] == .Keyword);
        remaining_children = remaining_children[2..];
    }
    // try lowerParameters(module, overload, children[1..]);
}

pub fn lower(allocator: *Allocator, ast: Ast) !Ssa {
    var ssa: Ssa = undefined;
    ssa.arena = Arena.init(allocator);
    ssa.name_to_index = Map(Name, usize).init(&ssa.arena.allocator);
    ssa.kinds = List(DeclarationKind).init(&ssa.arena.allocator);
    ssa.names = List(Name).init(&ssa.arena.allocator);
    ssa.indices = List(usize).init(&ssa.arena.allocator);
    ssa.functions = List(Function).init(&ssa.arena.allocator);
    for (ast.top_level.slice()) |index| {
        const children = astChildren(ast, .Parens, index);
        assert(children.len > 0);
        assert(std.mem.eql(u8, astString(ast, .Symbol, children[0]), "fn"));
        try lowerOverload(&ssa, ast, children[1..]);
    }
    return ssa;
}
