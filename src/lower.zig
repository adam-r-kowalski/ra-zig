const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const parser = @import("parser.zig");
const Strings = parser.Strings;
const Ast = parser.Ast;
const AstKind = parser.Kind;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;
const Children = []const usize;

const EXTERNAL_SCOPE = 0;
const FUNCTION_SCOPE = 1;

const String = []const u8;

const InternedString = usize;

pub const Scope = Map(InternedString, usize);

const ExpressionKind = enum(u8) {
    Return,
};

pub const BasicBlock = struct {
    active_scopes: []const usize,
    kinds: List(ExpressionKind),
    indices: List(usize),
    returns: List(usize),
};

pub const Entities = struct {
    names: Map(usize, InternedString),
    values: Map(usize, InternedString),
    next_id: usize,
};

pub const Overload = struct {
    parameter_names: []const InternedString,
    parameter_type_blocks: []const usize,
    return_type_block: usize,
    body_block: usize,
    scopes: List(Scope),
    basic_blocks: List(BasicBlock),
    entities: Entities,
};

pub const Function = List(Overload);

pub const DeclarationKind = enum(u8) {
    Function,
};

pub const Ssa = struct {
    name_to_index: Map(InternedString, usize),
    kinds: List(DeclarationKind),
    names: List(InternedString),
    indices: List(usize),
    functions: List(Function),
    arena: Arena,
};

fn astIndex(ast: Ast, kind: AstKind, ast_entity: usize) usize {
    assert(ast.kinds.items[ast_entity] == kind);
    return ast.indices.items[ast_entity];
}

fn astChildren(ast: Ast, kind: AstKind, ast_entity: usize) Children {
    return ast.children.items[astIndex(ast, kind, ast_entity)].slice();
}

fn astString(ast: Ast, kind: AstKind, ast_entity: usize) []const u8 {
    return ast.strings.data.items[astIndex(ast, kind, ast_entity)];
}

fn lowerExpression(overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) !usize {
    switch (ast.kinds.items[ast_entity]) {
        .Symbol => {
            const name = ast.indices.items[ast_entity];
            const active_scopes = overload.basic_blocks.items[active_block.*].active_scopes;
            var i: usize = active_scopes.len;
            while (i != 0) : (i -= 1) {
                if (overload.scopes.items[i - 1].get(name)) |entity|
                    return entity;
            }
            const entity = overload.entities.next_id;
            overload.entities.next_id += 1;
            try overload.entities.names.putNoClobber(entity, name);
            try overload.scopes.items[EXTERNAL_SCOPE].putNoClobber(name, entity);
            return 0;
        },
        else => std.debug.panic("entity kind {} not yet supported!", .{ast.kinds.items[ast_entity]}),
    }
}

fn lowerBasicBlock(overload: *Overload, ast: Ast, block: usize, children: Children) !void {
    var active_block = block;
    const scope_entity = try lowerExpression(overload, ast, &active_block, children[0]);
    const basic_block = &overload.basic_blocks.items[active_block];
    _ = try basic_block.kinds.insert(.Return);
    const return_index = try basic_block.returns.insert(scope_entity);
    _ = try basic_block.indices.insert(return_index);
}

fn newBasicBlockAndScope(allocator: *Allocator, overload: *Overload, currently_active_scopes: []const usize) !usize {
    const new_scope = try overload.scopes.insert(Scope.init(allocator));
    const result = try overload.basic_blocks.addOne();
    const basic_block = result.ptr;
    const active_scopes = try allocator.alloc(usize, currently_active_scopes.len + 1);
    for (currently_active_scopes) |scope, i| active_scopes[i] = scope;
    active_scopes[currently_active_scopes.len] = new_scope;
    basic_block.active_scopes = active_scopes;
    basic_block.kinds = List(ExpressionKind).init(allocator);
    basic_block.indices = List(usize).init(allocator);
    basic_block.returns = List(usize).init(allocator);
    return result.index;
}

fn lowerParameters(allocator: *Allocator, overload: *Overload, ast: Ast, ast_entity: usize) !void {
    var parameters = astChildren(ast, .Parens, ast_entity);
    const parameter_names = try allocator.alloc(usize, parameters.len);
    const parameter_type_blocks = try allocator.alloc(usize, parameters.len);
    var i: usize = 0;
    while (i < parameters.len) : (i += 1) {
        const parameter = astChildren(ast, .Parens, parameters[i]);
        const parameter_name = astIndex(ast, .Symbol, parameter[0]);
        parameter_names[i] = parameter_name;
        const id = overload.entities.next_id;
        overload.entities.next_id += 1;
        try overload.entities.names.putNoClobber(id, parameter_name);
        try overload.scopes.items[FUNCTION_SCOPE].putNoClobber(parameter_name, id);
        const block = try newBasicBlockAndScope(allocator, overload, &.{ EXTERNAL_SCOPE, FUNCTION_SCOPE });
        parameter_type_blocks[i] = block;
        try lowerBasicBlock(overload, ast, block, parameter[1..2]);
    }
    overload.parameter_names = parameter_names;
    overload.parameter_type_blocks = parameter_type_blocks;
}

fn lowerReturnType(allocator: *Allocator, overload: *Overload, ast: Ast, ast_entity: usize) !void {
    const block = try newBasicBlockAndScope(allocator, overload, &.{ EXTERNAL_SCOPE, FUNCTION_SCOPE });
    overload.return_type_block = block;
    try lowerBasicBlock(overload, ast, block, &.{ast_entity});
}

fn lowerBody(allocator: *Allocator, overload: *Overload, ast: Ast, ast_entity: usize) !void {
    const block = try newBasicBlockAndScope(allocator, overload, &.{ EXTERNAL_SCOPE, FUNCTION_SCOPE });
    overload.body_block = block;
    // try lowerBasicBlock(overload, ast, block, parameter[1..2]);
}

fn lowerOverload(allocator: *Allocator, function: *Function, ast: Ast, children: Children) !void {
    const overload = (try function.addOne()).ptr;
    overload.scopes = List(Scope).init(allocator);
    _ = try overload.scopes.insert(Scope.init(allocator));
    _ = try overload.scopes.insert(Scope.init(allocator));
    overload.basic_blocks = List(BasicBlock).init(allocator);
    overload.entities = Entities{
        .names = Map(usize, InternedString).init(allocator),
        .values = Map(usize, InternedString).init(allocator),
        .next_id = 0,
    };
    var remaining_children = children;
    var keyword_to_index = Map(usize, usize).init(allocator);
    while (remaining_children.len > 0) {
        const keyword = astIndex(ast, .Keyword, remaining_children[0]);
        try keyword_to_index.putNoClobber(keyword, remaining_children[1]);
        remaining_children = remaining_children[2..];
    }
    try lowerParameters(allocator, overload, ast, keyword_to_index.get(parser.ARGS).?);
    try lowerReturnType(allocator, overload, ast, keyword_to_index.get(parser.RET).?);
    try lowerBody(allocator, overload, ast, keyword_to_index.get(parser.BODY).?);
}

fn createOrOverloadFunction(ssa: *Ssa, ast: Ast, ast_entity: usize) !*Function {
    const allocator = &ssa.arena.allocator;
    const name = astIndex(ast, .Symbol, ast_entity);
    const get_or_put_result = try ssa.name_to_index.getOrPut(name);
    if (get_or_put_result.found_existing) {
        const index = get_or_put_result.entry.value;
        assert(ssa.kinds.items[index] == .Function);
        const function_index = ssa.indices.items[index];
        return &ssa.functions.items[function_index];
    }
    _ = try ssa.kinds.insert(.Function);
    get_or_put_result.entry.value = try ssa.names.insert(name);
    const result = try ssa.functions.addOne();
    result.ptr.* = List(Overload).init(&ssa.arena.allocator);
    _ = try ssa.indices.insert(result.index);
    return result.ptr;
}

pub fn lower(allocator: *Allocator, ast: Ast) !Ssa {
    var ssa: Ssa = undefined;
    ssa.arena = Arena.init(allocator);
    ssa.name_to_index = Map(InternedString, usize).init(&ssa.arena.allocator);
    ssa.kinds = List(DeclarationKind).init(&ssa.arena.allocator);
    ssa.names = List(InternedString).init(&ssa.arena.allocator);
    ssa.indices = List(usize).init(&ssa.arena.allocator);
    ssa.functions = List(Function).init(&ssa.arena.allocator);
    for (ast.top_level.slice()) |index| {
        const children = astChildren(ast, .Parens, index);
        assert(astIndex(ast, .Symbol, children[0]) == parser.FN);
        const function = try createOrOverloadFunction(&ssa, ast, children[1]);
        try lowerOverload(&ssa.arena.allocator, function, ast, children[2..]);
    }
    return ssa;
}

pub fn ssaString(allocator: *std.mem.Allocator, strings: Strings, ssa: Ssa) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    for (ssa.kinds.slice()) |kind, i| {
        switch (kind) {
            .Function => {
                const name = strings.data.items[ssa.names.items[i]];
                const function = ssa.functions.items[ssa.indices.items[i]];
                for (function.slice()) |overload| {
                    try output.insertSlice("(fn ");
                    try output.insertSlice(name);
                    try output.insertSlice("\n  :parameter-names (");
                    for (overload.parameter_names) |parameter_name, j| {
                        try output.insertSlice(strings.data.items[parameter_name]);
                        if (j < overload.parameter_names.len - 1)
                            _ = try output.insert(' ');
                    }
                    try output.insertSlice(")\n  :parameter-type-blocks (");
                    for (overload.parameter_type_blocks) |block, j| {
                        try output.insertFormatted("%b{}", .{block});
                        if (j < overload.parameter_type_blocks.len - 1)
                            _ = try output.insert(' ');
                    }
                    try output.insertSlice(")\n  :return-type-blocks ");
                    try output.insertFormatted("%b{}", .{overload.return_type_block});
                    try output.insertSlice("\n  :body-block ");
                    try output.insertFormatted("%b{}", .{overload.body_block});
                    try output.insertSlice("\n  :scopes");
                    for (overload.scopes.slice()) |scope, j| {
                        try output.insertSlice("\n  (scope ");
                        switch (j) {
                            EXTERNAL_SCOPE => try output.insertSlice("%external"),
                            FUNCTION_SCOPE => try output.insertSlice("%function"),
                            else => try output.insertFormatted("%s{}", .{j - 2}),
                        }
                        var iterator = scope.iterator();
                        while (iterator.next()) |entry| {
                            try output.insertSlice("\n    (entity ");
                            if (overload.entities.names.get(entry.value)) |string_index| {
                                try output.insertSlice(strings.data.items[string_index]);
                            }
                            _ = try output.insert(')');
                        }
                        _ = try output.insert(')');
                    }
                    try output.insertSlice("\n  :blocks");
                    for (overload.basic_blocks.slice()) |basic_block, j| {
                        try output.insertSlice("\n  (block ");
                        try output.insertFormatted("%b{} :scopes (", .{j});
                        for (basic_block.active_scopes) |scope, k| {
                            switch (scope) {
                                EXTERNAL_SCOPE => try output.insertSlice("%external"),
                                FUNCTION_SCOPE => try output.insertSlice("%function"),
                                else => try output.insertFormatted("%s{}", .{scope - 2}),
                            }
                            if (k < basic_block.active_scopes.len - 1)
                                _ = try output.insert(' ');
                        }
                        try output.insertSlice(")\n    :expressions");
                        for (basic_block.kinds.slice()) |expression_kind, k| {
                            switch (expression_kind) {
                                .Return => {
                                    try output.insertSlice("\n    (return ");
                                    const entity = basic_block.returns.items[basic_block.indices.items[k]];
                                    const string_index = overload.entities.names.get(entity).?;
                                    try output.insertSlice(strings.data.items[string_index]);
                                },
                            }
                        }
                        _ = try output.insert(')');
                    }
                    _ = try output.insert(')');
                }
            },
        }
    }
    return output;
}
