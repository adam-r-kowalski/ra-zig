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

const IF = std.math.maxInt(usize);

const String = []const u8;

const InternedString = usize;

pub const Scope = struct {
    name_to_entity: Map(InternedString, usize),
    entities: List(usize),
};

const ExpressionKind = enum(u8) {
    Return,
    Call,
    Branch,
    Phi,
    Jump,
};

const Call = struct {
    entity: usize,
    function: usize,
    arguments: []const usize,
};

const Branch = struct {
    condition_entity: usize,
    then_block: usize,
    else_block: usize,
};

const Phi = struct {
    entity: usize,
    then_block: usize,
    then_entity: usize,
    else_block: usize,
    else_entity: usize,
};

pub const BasicBlock = struct {
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

fn lowerSymbol(overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) !usize {
    const name = ast.indices.items[ast_entity];
    if (name == parser.IF) return IF;
    const active_scopes = overload.basic_blocks.items[active_block.*].active_scopes;
    var i: usize = active_scopes.len;
    while (i != 0) : (i -= 1) {
        if (overload.scopes.items[active_scopes[i - 1]].name_to_entity.get(name)) |entity|
            return entity;
    }
    const entity = overload.entities.next_id;
    overload.entities.next_id += 1;
    try overload.entities.names.putNoClobber(entity, name);
    try overload.scopes.items[EXTERNAL_SCOPE].name_to_entity.putNoClobber(name, entity);
    _ = try overload.scopes.items[EXTERNAL_SCOPE].entities.insert(entity);
    return entity;
}

fn lowerInt(overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) !usize {
    const integer = ast.indices.items[ast_entity];
    const active_scopes = overload.basic_blocks.items[active_block.*].active_scopes;
    const entity = overload.entities.next_id;
    overload.entities.next_id += 1;
    try overload.entities.values.putNoClobber(entity, integer);
    _ = try overload.scopes.items[active_scopes[active_scopes.len - 1]].entities.insert(entity);
    return entity;
}

fn lowerIf(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, children: Children) !usize {
    const condition_block = &overload.basic_blocks.items[active_block.*];
    const condition_entity = try lowerExpression(allocator, overload, ast, active_block, children[0]);
    const then_block_id = try newBasicBlockAndScope(allocator, overload, condition_block.active_scopes);
    active_block.* = then_block_id;
    const then_entity = try lowerExpression(allocator, overload, ast, active_block, children[1]);
    const else_block_id = try newBasicBlockAndScope(allocator, overload, condition_block.active_scopes);
    active_block.* = else_block_id;
    const else_entity = try lowerExpression(allocator, overload, ast, active_block, children[2]);
    assert(children.len == 3);
    _ = try condition_block.kinds.insert(.Branch);
    const branch_index = try condition_block.branches.insert(.{
        .condition_entity = condition_entity,
        .then_block = then_block_id,
        .else_block = else_block_id,
    });
    _ = try condition_block.indices.insert(branch_index);
    const phi_block_id = try newBasicBlockAndScope(allocator, overload, condition_block.active_scopes);
    const phi_block = &overload.basic_blocks.items[phi_block_id];
    _ = try phi_block.kinds.insert(.Phi);
    const entity = overload.entities.next_id;
    overload.entities.next_id += 1;
    _ = try overload.scopes.items[phi_block.active_scopes[phi_block.active_scopes.len - 1]].entities.insert(entity);
    const phi_index = try phi_block.phis.insert(.{
        .entity = entity,
        .then_block = then_block_id,
        .then_entity = then_entity,
        .else_block = else_block_id,
        .else_entity = else_entity,
    });
    _ = try phi_block.indices.insert(phi_index);
    active_block.* = phi_block_id;
    const then_block = &overload.basic_blocks.items[then_block_id];
    _ = try then_block.kinds.insert(.Jump);
    const then_jump_index = try then_block.jumps.insert(phi_block_id);
    _ = try then_block.indices.insert(then_jump_index);
    const else_block = &overload.basic_blocks.items[else_block_id];
    _ = try else_block.kinds.insert(.Jump);
    const else_jump_index = try else_block.jumps.insert(phi_block_id);
    _ = try else_block.indices.insert(else_jump_index);
    return entity;
}

fn lowerParens(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) !usize {
    const children = ast.children.items[ast.indices.items[ast_entity]].slice();
    const function = try lowerExpression(allocator, overload, ast, active_block, children[0]);
    if (function == IF) return lowerIf(allocator, overload, ast, active_block, children[1..]);
    const arguments = try allocator.alloc(usize, children.len - 1);
    for (children[1..]) |child, i|
        arguments[i] = try lowerExpression(allocator, overload, ast, active_block, child);
    const basic_block = &overload.basic_blocks.items[active_block.*];
    _ = try basic_block.kinds.insert(.Call);
    const entity = overload.entities.next_id;
    overload.entities.next_id += 1;
    const active_scopes = overload.basic_blocks.items[active_block.*].active_scopes;
    _ = try overload.scopes.items[active_scopes[active_scopes.len - 1]].entities.insert(entity);
    const call_index = try basic_block.calls.insert(.{
        .entity = entity,
        .function = function,
        .arguments = arguments,
    });
    _ = try basic_block.indices.insert(call_index);
    return entity;
}

fn lowerExpression(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) error{OutOfMemory}!usize {
    return switch (ast.kinds.items[ast_entity]) {
        .Symbol => try lowerSymbol(overload, ast, active_block, ast_entity),
        .Int => try lowerInt(overload, ast, active_block, ast_entity),
        .Parens => try lowerParens(allocator, overload, ast, active_block, ast_entity),
        else => std.debug.panic("entity kind {} not yet supported!", .{ast.kinds.items[ast_entity]}),
    };
}

fn lowerBasicBlock(allocator: *Allocator, overload: *Overload, ast: Ast, block: usize, children: Children) !void {
    var active_block = block;
    const scope_entity = try lowerExpression(allocator, overload, ast, &active_block, children[0]);
    const basic_block = &overload.basic_blocks.items[active_block];
    _ = try basic_block.kinds.insert(.Return);
    const return_index = try basic_block.returns.insert(scope_entity);
    _ = try basic_block.indices.insert(return_index);
}

fn newBasicBlockAndScope(allocator: *Allocator, overload: *Overload, currently_active_scopes: []const usize) !usize {
    const new_scope = try overload.scopes.insert(.{
        .name_to_entity = Map(InternedString, usize).init(allocator),
        .entities = List(usize).init(allocator),
    });
    const result = try overload.basic_blocks.addOne();
    const basic_block = result.ptr;
    const active_scopes = try allocator.alloc(usize, currently_active_scopes.len + 1);
    for (currently_active_scopes) |scope, i| active_scopes[i] = scope;
    active_scopes[currently_active_scopes.len] = new_scope;
    basic_block.active_scopes = active_scopes;
    basic_block.kinds = List(ExpressionKind).init(allocator);
    basic_block.indices = List(usize).init(allocator);
    basic_block.returns = List(usize).init(allocator);
    basic_block.calls = List(Call).init(allocator);
    basic_block.branches = List(Branch).init(allocator);
    basic_block.phis = List(Phi).init(allocator);
    basic_block.jumps = List(usize).init(allocator);
    return result.index;
}

fn lowerParameters(allocator: *Allocator, overload: *Overload, ast: Ast, children: Children) !void {
    assert(children.len == 1);
    const ast_entity = children[0];
    var parameters = astChildren(ast, .Parens, ast_entity);
    const parameter_names = try allocator.alloc(usize, parameters.len);
    const parameter_type_blocks = try allocator.alloc(usize, parameters.len);
    var i: usize = 0;
    while (i < parameters.len) : (i += 1) {
        const parameter = astChildren(ast, .Parens, parameters[i]);
        const parameter_name = astIndex(ast, .Symbol, parameter[0]);
        parameter_names[i] = parameter_name;
        const entity = overload.entities.next_id;
        overload.entities.next_id += 1;
        try overload.entities.names.putNoClobber(entity, parameter_name);
        try overload.scopes.items[FUNCTION_SCOPE].name_to_entity.putNoClobber(parameter_name, entity);
        _ = try overload.scopes.items[FUNCTION_SCOPE].entities.insert(entity);
        const block = try newBasicBlockAndScope(allocator, overload, &.{ EXTERNAL_SCOPE, FUNCTION_SCOPE });
        parameter_type_blocks[i] = block;
        try lowerBasicBlock(allocator, overload, ast, block, parameter[1..2]);
    }
    overload.parameter_names = parameter_names;
    overload.parameter_type_blocks = parameter_type_blocks;
}

fn lowerReturnType(allocator: *Allocator, overload: *Overload, ast: Ast, children: Children) !void {
    assert(children.len == 1);
    const block = try newBasicBlockAndScope(allocator, overload, &.{ EXTERNAL_SCOPE, FUNCTION_SCOPE });
    overload.return_type_block = block;
    try lowerBasicBlock(allocator, overload, ast, block, children);
}

fn lowerBody(allocator: *Allocator, overload: *Overload, ast: Ast, children: Children) !void {
    const block = try newBasicBlockAndScope(allocator, overload, &.{ EXTERNAL_SCOPE, FUNCTION_SCOPE });
    overload.body_block = block;
    try lowerBasicBlock(allocator, overload, ast, block, children);
}

fn childrenTillNextKeyword(ast: Ast, children: Children) usize {
    const len = children.len - 1;
    var i: usize = 1;
    while (true) {
        if (i == len) return i + 1;
        if (ast.kinds.items[children[i]] == .Keyword) return i;
        i += 1;
    }
}

fn lowerOverload(allocator: *Allocator, function: *Function, ast: Ast, children: Children) !void {
    const overload = (try function.addOne()).ptr;
    overload.scopes = List(Scope).init(allocator);
    _ = try overload.scopes.insert(.{
        .name_to_entity = Map(InternedString, usize).init(allocator),
        .entities = List(usize).init(allocator),
    });
    _ = try overload.scopes.insert(.{
        .name_to_entity = Map(InternedString, usize).init(allocator),
        .entities = List(usize).init(allocator),
    });
    overload.basic_blocks = List(BasicBlock).init(allocator);
    overload.entities = Entities{
        .names = Map(usize, InternedString).init(allocator),
        .values = Map(usize, InternedString).init(allocator),
        .next_id = 0,
    };
    var remaining_children = children;
    var keyword_to_children = Map(usize, Children).init(allocator);
    while (remaining_children.len > 0) {
        const keyword = astIndex(ast, .Keyword, remaining_children[0]);
        const length = childrenTillNextKeyword(ast, remaining_children);
        try keyword_to_children.putNoClobber(keyword, remaining_children[1..length]);
        remaining_children = remaining_children[length..];
    }
    try lowerParameters(allocator, overload, ast, keyword_to_children.get(parser.ARGS).?);
    try lowerReturnType(allocator, overload, ast, keyword_to_children.get(parser.RET).?);
    try lowerBody(allocator, overload, ast, keyword_to_children.get(parser.BODY).?);
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

fn writeParameterName(output: *List(u8), overload: Overload, strings: Strings) !void {
    try output.insertSlice("\n  :parameter-names (");
    for (overload.parameter_names) |parameter_name, i| {
        try output.insertSlice(strings.data.items[parameter_name]);
        if (i < overload.parameter_names.len - 1)
            _ = try output.insert(' ');
    }
}

fn writeParameterTypeBlock(output: *List(u8), overload: Overload) !void {
    try output.insertSlice(")\n  :parameter-type-blocks (");
    for (overload.parameter_type_blocks) |block, i| {
        try output.insertFormatted("%b{}", .{block});
        if (i < overload.parameter_type_blocks.len - 1)
            _ = try output.insert(' ');
    }
}

const Writer = struct {
    output: *List(u8),
    anonymous_entity_to_name: *Map(usize, usize),
    overload: *const Overload,
    strings: *const Strings,
};

fn writeScopes(writer: Writer) !void {
    const output = writer.output;
    const anonymous_entity_to_name = writer.anonymous_entity_to_name;
    const overload = writer.overload;
    const strings = writer.strings;
    try output.insertSlice("\n  :scopes");
    for (overload.scopes.slice()) |scope, i| {
        try output.insertSlice("\n  (scope ");
        switch (i) {
            EXTERNAL_SCOPE => try output.insertSlice("%external"),
            FUNCTION_SCOPE => try output.insertSlice("%function"),
            else => try output.insertFormatted("%s{}", .{i - 2}),
        }
        for (scope.entities.slice()) |entity| {
            try output.insertSlice("\n    (entity :name ");
            if (overload.entities.names.get(entity)) |string_index| {
                try output.insertSlice(strings.data.items[string_index]);
            } else if (anonymous_entity_to_name.get(entity)) |name| {
                try output.insertFormatted("%t{}", .{name});
            } else {
                const name = anonymous_entity_to_name.count();
                try anonymous_entity_to_name.putNoClobber(entity, name);
                try output.insertFormatted("%t{}", .{name});
            }
            if (overload.entities.values.get(entity)) |string_index| {
                try output.insertSlice(" :value ");
                try output.insertSlice(strings.data.items[string_index]);
            }
            _ = try output.insert(')');
        }
        _ = try output.insert(')');
    }
}

fn writeActiveScopes(output: *List(u8), basic_block: BasicBlock) !void {
    try output.insertSlice(" :scopes (");
    for (basic_block.active_scopes) |scope, i| {
        switch (scope) {
            EXTERNAL_SCOPE => try output.insertSlice("%external"),
            FUNCTION_SCOPE => try output.insertSlice("%function"),
            else => try output.insertFormatted("%s{}", .{scope - 2}),
        }
        if (i < basic_block.active_scopes.len - 1)
            _ = try output.insert(' ');
    }
}

fn writeEntity(writer: Writer, block_entity: usize) !void {
    const output = writer.output;
    const overload = writer.overload;
    const strings = writer.strings;
    if (overload.entities.names.get(block_entity)) |string_index| {
        try output.insertSlice(strings.data.items[string_index]);
    } else if (writer.anonymous_entity_to_name.get(block_entity)) |name| {
        try output.insertFormatted("%t{}", .{name});
    }
}

fn writeReturn(writer: Writer, basic_block: BasicBlock, block_entity: usize) !void {
    const output = writer.output;
    try output.insertSlice("\n    (return ");
    const entity = basic_block.returns.items[basic_block.indices.items[block_entity]];
    try writeEntity(writer, entity);
    _ = try output.insert(')');
}

fn writeCall(writer: Writer, basic_block: BasicBlock, block_entity: usize) !void {
    const output = writer.output;
    const call = basic_block.calls.items[basic_block.indices.items[block_entity]];
    try output.insertSlice("\n    (let ");
    try writeEntity(writer, call.entity);
    try output.insertSlice(" (");
    try writeEntity(writer, call.function);
    for (call.arguments) |argument| {
        _ = try output.insert(' ');
        try writeEntity(writer, argument);
    }
    try output.insertSlice("))");
}

fn writeBranch(writer: Writer, basic_block: BasicBlock, block_entity: usize) !void {
    const output = writer.output;
    const branch = basic_block.branches.items[basic_block.indices.items[block_entity]];
    try output.insertSlice("\n    (branch ");
    try writeEntity(writer, branch.condition_entity);
    try output.insertFormatted(" %b{} %b{})", .{ branch.then_block, branch.else_block });
}

fn writePhi(writer: Writer, basic_block: BasicBlock, block_entity: usize) !void {
    const output = writer.output;
    const phi = basic_block.phis.items[basic_block.indices.items[block_entity]];
    try output.insertSlice("\n    (let ");
    try writeEntity(writer, phi.entity);
    try output.insertSlice(" (phi ");
    try output.insertFormatted("(%b{} ", .{phi.then_block});
    try writeEntity(writer, phi.then_entity);
    try output.insertFormatted(") (%b{} ", .{phi.else_block});
    try writeEntity(writer, phi.else_entity);
    try output.insertSlice(")))");
}

fn writeJump(writer: Writer, basic_block: BasicBlock, block_entity: usize) !void {
    const output = writer.output;
    const jump = basic_block.jumps.items[basic_block.indices.items[block_entity]];
    try output.insertFormatted("\n    (jump %b{})", .{jump});
}

fn writeExpressions(writer: Writer, basic_block: BasicBlock) !void {
    try writer.output.insertSlice(")\n    :expressions");
    for (basic_block.kinds.slice()) |expression_kind, entity| {
        switch (expression_kind) {
            .Return => try writeReturn(writer, basic_block, entity),
            .Call => try writeCall(writer, basic_block, entity),
            .Branch => try writeBranch(writer, basic_block, entity),
            .Phi => try writePhi(writer, basic_block, entity),
            .Jump => try writeJump(writer, basic_block, entity),
        }
    }
}

fn writeBlocks(writer: Writer) !void {
    const output = writer.output;
    try output.insertSlice("\n  :blocks");
    for (writer.overload.basic_blocks.slice()) |basic_block, i| {
        try output.insertSlice("\n  (block ");
        try output.insertFormatted("%b{}", .{i});
        try writeActiveScopes(output, basic_block);
        try writeExpressions(writer, basic_block);
        _ = try output.insert(')');
    }
}

fn functionString(allocator: *Allocator, output: *List(u8), strings: Strings, ssa: Ssa, ssa_entity: usize) !void {
    var anonymous_entity_to_name = Map(usize, usize).init(allocator);
    defer anonymous_entity_to_name.deinit();
    const name = strings.data.items[ssa.names.items[ssa_entity]];
    const function = ssa.functions.items[ssa.indices.items[ssa_entity]];
    for (function.slice()) |overload| {
        try output.insertSlice("(fn ");
        try output.insertSlice(name);
        try writeParameterName(output, overload, strings);
        try writeParameterTypeBlock(output, overload);
        try output.insertSlice(")\n  :return-type-blocks ");
        try output.insertFormatted("%b{}", .{overload.return_type_block});
        try output.insertSlice("\n  :body-block ");
        try output.insertFormatted("%b{}", .{overload.body_block});
        const writer = Writer{
            .output = output,
            .anonymous_entity_to_name = &anonymous_entity_to_name,
            .overload = &overload,
            .strings = &strings,
        };
        try writeScopes(writer);
        try writeBlocks(writer);
        _ = try output.insert(')');
    }
}
pub fn ssaString(allocator: *std.mem.Allocator, strings: Strings, ssa: Ssa) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    for (ssa.kinds.slice()) |kind, entity| {
        switch (kind) {
            .Function => try functionString(allocator, &output, strings, ssa, entity),
        }
    }
    return output;
}
