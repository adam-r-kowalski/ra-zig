const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const data = @import("data.zig");
const Ast = data.ast.Ast;
const AstKind = data.ast.Kind;
const List = data.List;
const Map = data.Map;
const Children = []const usize;
const Ir = data.ir.Ir;
const DeclarationKind = data.ir.DeclarationKind;
const ExpressionKind = data.ir.ExpressionKind;
const LiteralKind = data.ir.LiteralKind;
const Function = data.ir.Function;
const Overload = data.ir.Overload;
const Scope = data.ir.Scope;
const Scopes = data.ir.Scopes;
const Block = data.ir.Block;
const Entities = data.ir.Entities;
const Entity = data.ir.Entity;
const Call = data.ir.Call;
const Branch = data.ir.Branch;
const Phi = data.ir.Phi;
const Builtins = data.ir.Builtins;
const Strings = data.interned_strings.Strings;
const InternedStrings = data.interned_strings.InternedStrings;
const InternedString = data.interned_strings.InternedString;

fn astIndex(ast: Ast, kind: AstKind, ast_entity: usize) usize {
    assert(ast.kinds.items[ast_entity] == kind);
    return ast.indices.items[ast_entity];
}

fn astChildren(ast: Ast, kind: AstKind, ast_entity: usize) Children {
    return ast.children.items[astIndex(ast, kind, ast_entity)].slice();
}

fn lowerSymbol(overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) !Entity {
    const name = ast.indices.items[ast_entity];
    switch (name) {
        @enumToInt(Strings.If) => return @enumToInt(Builtins.If),
        @enumToInt(Strings.Const) => return @enumToInt(Builtins.Const),
        @enumToInt(Strings.I64) => return @enumToInt(Builtins.I64),
        @enumToInt(Strings.F64) => return @enumToInt(Builtins.F64),
        else => {
            const active_scopes = overload.blocks.items[active_block.*].active_scopes;
            var i: usize = active_scopes.len;
            while (i != 0) : (i -= 1) {
                if (overload.scopes.items[active_scopes[i - 1]].name_to_entity.get(name)) |entity|
                    return entity;
            }
            const entity = overload.entities.next_entity;
            overload.entities.next_entity += 1;
            try overload.entities.names.putNoClobber(entity, name);
            try overload.scopes.items[@enumToInt(Scopes.External)].name_to_entity.putNoClobber(name, entity);
            _ = try overload.scopes.items[@enumToInt(Scopes.External)].entities.insert(entity);
            return entity;
        },
    }
}

fn lowerNumber(overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize, kind: LiteralKind) !Entity {
    const number = ast.indices.items[ast_entity];
    const active_scopes = overload.blocks.items[active_block.*].active_scopes;
    const entity = overload.entities.next_entity;
    overload.entities.next_entity += 1;
    try overload.entities.values.putNoClobber(entity, number);
    try overload.entities.kinds.putNoClobber(entity, kind);
    _ = try overload.scopes.items[active_scopes[active_scopes.len - 1]].entities.insert(entity);
    return entity;
}

fn lowerIf(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, children: Children) !Entity {
    const condition_block = &overload.blocks.items[active_block.*];
    const condition_entity = try lowerExpression(allocator, overload, ast, active_block, children[0]);
    const then_block_index = try newBlockAndScope(allocator, overload, condition_block.active_scopes);
    active_block.* = then_block_index;
    const then_entity = try lowerExpression(allocator, overload, ast, active_block, children[1]);
    const else_block_index = try newBlockAndScope(allocator, overload, condition_block.active_scopes);
    active_block.* = else_block_index;
    const else_entity = try lowerExpression(allocator, overload, ast, active_block, children[2]);
    assert(children.len == 3);
    _ = try condition_block.kinds.insert(.Branch);
    const branch_index = try condition_block.branches.insert(.{
        .condition_entity = condition_entity,
        .then_block_index = then_block_index,
        .else_block_index = else_block_index,
    });
    _ = try condition_block.indices.insert(branch_index);
    const phi_block_id = try newBlockAndScope(allocator, overload, condition_block.active_scopes);
    const phi_block = &overload.blocks.items[phi_block_id];
    _ = try phi_block.kinds.insert(.Phi);
    const result_entity = overload.entities.next_entity;
    overload.entities.next_entity += 1;
    _ = try overload.scopes.items[phi_block.active_scopes[phi_block.active_scopes.len - 1]].entities.insert(result_entity);
    const phi_index = try phi_block.phis.insert(.{
        .result_entity = result_entity,
        .then_block_index = then_block_index,
        .then_entity = then_entity,
        .else_block_index = else_block_index,
        .else_entity = else_entity,
    });
    _ = try phi_block.indices.insert(phi_index);
    active_block.* = phi_block_id;
    const then_block = &overload.blocks.items[then_block_index];
    _ = try then_block.kinds.insert(.Jump);
    const then_jump_index = try then_block.jumps.insert(phi_block_id);
    _ = try then_block.indices.insert(then_jump_index);
    const else_block = &overload.blocks.items[else_block_index];
    _ = try else_block.kinds.insert(.Jump);
    const else_jump_index = try else_block.jumps.insert(phi_block_id);
    _ = try else_block.indices.insert(else_jump_index);
    return result_entity;
}

fn lowerConst(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, children: Children) !Entity {
    const name = astIndex(ast, .Symbol, children[0]);
    const entity = try lowerExpression(allocator, overload, ast, active_block, children[1]);
    assert(children.len == 2);
    const result = try overload.entities.names.getOrPut(entity);
    assert(!result.found_existing);
    result.entry.value = name;
    const active_scopes = overload.blocks.items[active_block.*].active_scopes;
    try overload.scopes.items[active_scopes[active_scopes.len - 1]].name_to_entity.putNoClobber(name, entity);
    return entity;
}

fn lowerCall(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, function_entity: Entity, children: Children) !Entity {
    const argument_entities = try allocator.alloc(Entity, children.len);
    for (children) |child, i|
        argument_entities[i] = try lowerExpression(allocator, overload, ast, active_block, child);
    const block = &overload.blocks.items[active_block.*];
    _ = try block.kinds.insert(.Call);
    const result_entity = overload.entities.next_entity;
    overload.entities.next_entity += 1;
    const active_scopes = overload.blocks.items[active_block.*].active_scopes;
    _ = try overload.scopes.items[active_scopes[active_scopes.len - 1]].entities.insert(result_entity);
    const call_index = try block.calls.insert(.{
        .result_entity = result_entity,
        .function_entity = function_entity,
        .argument_entities = argument_entities,
    });
    _ = try block.indices.insert(call_index);
    return result_entity;
}

fn lowerParens(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) !usize {
    const children = ast.children.items[ast.indices.items[ast_entity]].slice();
    const function = try lowerExpression(allocator, overload, ast, active_block, children[0]);
    return switch (function) {
        @enumToInt(Builtins.If) => lowerIf(allocator, overload, ast, active_block, children[1..]),
        @enumToInt(Builtins.Const) => lowerConst(allocator, overload, ast, active_block, children[1..]),
        else => lowerCall(allocator, overload, ast, active_block, function, children[1..]),
    };
}

fn lowerExpression(allocator: *Allocator, overload: *Overload, ast: Ast, active_block: *usize, ast_entity: usize) error{OutOfMemory}!Entity {
    return switch (ast.kinds.items[ast_entity]) {
        .Symbol => try lowerSymbol(overload, ast, active_block, ast_entity),
        .Int => try lowerNumber(overload, ast, active_block, ast_entity, .Int),
        .Float => try lowerNumber(overload, ast, active_block, ast_entity, .Float),
        .Parens => try lowerParens(allocator, overload, ast, active_block, ast_entity),
        else => std.debug.panic("entity kind {} not yet supported!", .{ast.kinds.items[ast_entity]}),
    };
}

fn newBlockAndScope(allocator: *Allocator, overload: *Overload, currently_active_scopes: []const usize) !usize {
    const new_scope = try overload.scopes.insert(.{
        .name_to_entity = Map(InternedString, usize).init(allocator),
        .entities = List(usize).init(allocator),
    });
    const result = try overload.blocks.addOne();
    const block = result.ptr;
    const active_scopes = try allocator.alloc(usize, currently_active_scopes.len + 1);
    for (currently_active_scopes) |scope, i| active_scopes[i] = scope;
    active_scopes[currently_active_scopes.len] = new_scope;
    block.active_scopes = active_scopes;
    block.kinds = List(ExpressionKind).init(allocator);
    block.indices = List(usize).init(allocator);
    block.returns = List(usize).init(allocator);
    block.calls = List(Call).init(allocator);
    block.branches = List(Branch).init(allocator);
    block.phis = List(Phi).init(allocator);
    block.jumps = List(usize).init(allocator);
    return result.index;
}

fn lowerParameters(allocator: *Allocator, overload: *Overload, ast: Ast, children: Children) !void {
    assert(children.len == 1);
    const ast_entity = children[0];
    var parameters = astChildren(ast, .Parens, ast_entity);
    const parameter_entities = try allocator.alloc(Entity, parameters.len);
    const parameter_type_block_indices = try allocator.alloc(usize, parameters.len);
    var i: usize = 0;
    while (i < parameters.len) : (i += 1) {
        const parameter = astChildren(ast, .Parens, parameters[i]);
        const parameter_name = astIndex(ast, .Symbol, parameter[0]);
        const entity = overload.entities.next_entity;
        parameter_entities[i] = entity;
        overload.entities.next_entity += 1;
        try overload.entities.names.putNoClobber(entity, parameter_name);
        try overload.scopes.items[@enumToInt(Scopes.Function)].name_to_entity.putNoClobber(parameter_name, entity);
        _ = try overload.scopes.items[@enumToInt(Scopes.Function)].entities.insert(entity);
        var block_index = try newBlockAndScope(allocator, overload, &.{
            @enumToInt(Scopes.External),
            @enumToInt(Scopes.Function),
        });
        parameter_type_block_indices[i] = block_index;
        const type_entity = try lowerExpression(allocator, overload, ast, &block_index, parameter[1]);
        const block = &overload.blocks.items[block_index];
        _ = try block.kinds.insert(.Return);
        const return_index = try block.returns.insert(type_entity);
        _ = try block.indices.insert(return_index);
    }
    overload.parameter_entities = parameter_entities;
    overload.parameter_type_block_indices = parameter_type_block_indices;
}

fn lowerReturnType(allocator: *Allocator, overload: *Overload, ast: Ast, children: Children) !void {
    assert(children.len == 1);
    var block_index = try newBlockAndScope(allocator, overload, &.{
        @enumToInt(Scopes.External),
        @enumToInt(Scopes.Function),
    });
    overload.return_type_block_index = block_index;
    const entity = try lowerExpression(allocator, overload, ast, &block_index, children[0]);
    const block = &overload.blocks.items[block_index];
    _ = try block.kinds.insert(.Return);
    const return_index = try block.returns.insert(entity);
    _ = try block.indices.insert(return_index);
}

fn lowerBody(allocator: *Allocator, overload: *Overload, ast: Ast, children: Children) !void {
    assert(children.len != 0);
    var block_index = try newBlockAndScope(allocator, overload, &.{
        @enumToInt(Scopes.External),
        @enumToInt(Scopes.Function),
    });
    overload.body_block_index = block_index;
    var entity: usize = try lowerExpression(allocator, overload, ast, &block_index, children[0]);
    for (children[1..]) |child|
        entity = try lowerExpression(allocator, overload, ast, &block_index, child);
    const block = &overload.blocks.items[block_index];
    _ = try block.kinds.insert(.Return);
    const return_index = try block.returns.insert(entity);
    _ = try block.indices.insert(return_index);
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
    overload.blocks = List(Block).init(allocator);
    const next_id = @typeInfo(Builtins).Enum.fields.len;
    overload.entities = Entities{
        .names = Map(Entity, InternedString).init(allocator),
        .values = Map(Entity, InternedString).init(allocator),
        .kinds = Map(Entity, LiteralKind).init(allocator),
        .next_entity = next_id,
    };
    var remaining_children = children;
    var keyword_to_children = Map(usize, Children).init(allocator);
    while (remaining_children.len > 0) {
        const keyword = astIndex(ast, .Keyword, remaining_children[0]);
        const length = childrenTillNextKeyword(ast, remaining_children);
        try keyword_to_children.putNoClobber(keyword, remaining_children[1..length]);
        remaining_children = remaining_children[length..];
    }
    try lowerParameters(allocator, overload, ast, keyword_to_children.get(@enumToInt(Strings.Args)).?);
    try lowerReturnType(allocator, overload, ast, keyword_to_children.get(@enumToInt(Strings.Ret)).?);
    try lowerBody(allocator, overload, ast, keyword_to_children.get(@enumToInt(Strings.Body)).?);
}

fn createOrOverloadFunction(ir: *Ir, ast: Ast, ast_entity: usize) !*Function {
    const allocator = &ir.arena.allocator;
    const name = astIndex(ast, .Symbol, ast_entity);
    const get_or_put_result = try ir.name_to_index.getOrPut(name);
    if (get_or_put_result.found_existing) {
        const index = get_or_put_result.entry.value;
        assert(ir.kinds.items[index] == .Function);
        const function_index = ir.indices.items[index];
        return &ir.functions.items[function_index];
    }
    _ = try ir.kinds.insert(.Function);
    get_or_put_result.entry.value = try ir.names.insert(name);
    const result = try ir.functions.addOne();
    result.ptr.* = List(Overload).init(&ir.arena.allocator);
    _ = try ir.indices.insert(result.index);
    return result.ptr;
}

pub fn lower(allocator: *Allocator, ast: Ast) !Ir {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    var ir = Ir{
        .arena = arena,
        .name_to_index = Map(InternedString, usize).init(&arena.allocator),
        .kinds = List(DeclarationKind).init(&arena.allocator),
        .names = List(InternedString).init(&arena.allocator),
        .indices = List(usize).init(&arena.allocator),
        .functions = List(Function).init(&arena.allocator),
    };
    for (ast.top_level.slice()) |index| {
        const children = astChildren(ast, .Parens, index);
        assert(astIndex(ast, .Symbol, children[0]) == @enumToInt(Strings.Fn));
        const function = try createOrOverloadFunction(&ir, ast, children[1]);
        try lowerOverload(&ir.arena.allocator, function, ast, children[2..]);
    }
    return ir;
}

fn writeParameterName(output: *List(u8), overload: Overload, interned_strings: InternedStrings) !void {
    try output.insertSlice("\n  :parameter-names (");
    if (overload.parameter_entities.len == 0) return;
    const last = overload.parameter_entities.len - 1;
    for (overload.parameter_entities) |parameter_entity, i| {
        try output.insertSlice(interned_strings.data.items[overload.entities.names.get(parameter_entity).?]);
        if (i < last)
            _ = try output.insert(' ');
    }
}

fn writeParameterTypeBlock(output: *List(u8), overload: Overload) !void {
    try output.insertSlice(")\n  :parameter-type-blocks (");
    if (overload.parameter_type_block_indices.len == 0) return;
    const last = overload.parameter_type_block_indices.len - 1;
    for (overload.parameter_type_block_indices) |block_index, i| {
        try output.insertFormatted("%b{}", .{block_index});
        if (i < last)
            _ = try output.insert(' ');
    }
}

const Writer = struct {
    output: *List(u8),
    anonymous_entity_to_name: *Map(usize, usize),
    overload: *const Overload,
    interned_strings: *const InternedStrings,
};

fn writeScopes(writer: Writer) !void {
    const output = writer.output;
    const anonymous_entity_to_name = writer.anonymous_entity_to_name;
    const overload = writer.overload;
    const interned_strings = writer.interned_strings;
    try output.insertSlice("\n  :scopes");
    for (overload.scopes.slice()) |scope, i| {
        try output.insertSlice("\n  (scope ");
        switch (i) {
            @enumToInt(Scopes.External) => try output.insertSlice("%external"),
            @enumToInt(Scopes.Function) => try output.insertSlice("%function"),
            else => try output.insertFormatted("%s{}", .{i - 2}),
        }
        for (scope.entities.slice()) |entity| {
            try output.insertSlice("\n    (entity :name ");
            if (overload.entities.names.get(entity)) |string_index| {
                try output.insertSlice(interned_strings.data.items[string_index]);
            } else if (anonymous_entity_to_name.get(entity)) |name| {
                try output.insertFormatted("%t{}", .{name});
            } else {
                const name = anonymous_entity_to_name.count();
                try anonymous_entity_to_name.putNoClobber(entity, name);
                try output.insertFormatted("%t{}", .{name});
            }
            if (overload.entities.values.get(entity)) |string_index| {
                try output.insertSlice(" :value ");
                try output.insertSlice(interned_strings.data.items[string_index]);
            }
            _ = try output.insert(')');
        }
        _ = try output.insert(')');
    }
}

fn writeActiveScopes(output: *List(u8), block: Block) !void {
    try output.insertSlice(" :scopes (");
    for (block.active_scopes) |scope, i| {
        switch (scope) {
            @enumToInt(Scopes.External) => try output.insertSlice("%external"),
            @enumToInt(Scopes.Function) => try output.insertSlice("%function"),
            else => try output.insertFormatted("%s{}", .{scope - 2}),
        }
        if (i < block.active_scopes.len - 1)
            _ = try output.insert(' ');
    }
}

fn writeEntity(writer: Writer, block_entity: usize) !void {
    const output = writer.output;
    const overload = writer.overload;
    const interned_strings = writer.interned_strings;
    switch (block_entity) {
        @enumToInt(Builtins.I64) => try output.insertSlice("i64"),
        @enumToInt(Builtins.F64) => try output.insertSlice("f64"),
        else => {
            if (overload.entities.names.get(block_entity)) |string_index| {
                try output.insertSlice(interned_strings.data.items[string_index]);
            } else if (writer.anonymous_entity_to_name.get(block_entity)) |name| {
                try output.insertFormatted("%t{}", .{name});
            }
        },
    }
}

fn writeReturn(writer: Writer, block: Block, block_entity: usize) !void {
    const output = writer.output;
    try output.insertSlice("\n    (return ");
    const entity = block.returns.items[block.indices.items[block_entity]];
    try writeEntity(writer, entity);
    _ = try output.insert(')');
}

fn writeCall(writer: Writer, block: Block, block_entity: usize) !void {
    const output = writer.output;
    const call = block.calls.items[block.indices.items[block_entity]];
    try output.insertSlice("\n    (const ");
    try writeEntity(writer, call.result_entity);
    try output.insertSlice(" (");
    try writeEntity(writer, call.function_entity);
    for (call.argument_entities) |argument_entity| {
        _ = try output.insert(' ');
        try writeEntity(writer, argument_entity);
    }
    try output.insertSlice("))");
}

fn writeBranch(writer: Writer, block: Block, block_entity: usize) !void {
    const output = writer.output;
    const branch = block.branches.items[block.indices.items[block_entity]];
    try output.insertSlice("\n    (branch ");
    try writeEntity(writer, branch.condition_entity);
    try output.insertFormatted(" %b{} %b{})", .{ branch.then_block_index, branch.else_block_index });
}

fn writePhi(writer: Writer, block: Block, block_entity: usize) !void {
    const output = writer.output;
    const phi = block.phis.items[block.indices.items[block_entity]];
    try output.insertSlice("\n    (const ");
    try writeEntity(writer, phi.result_entity);
    try output.insertSlice(" (phi ");
    try output.insertFormatted("(%b{} ", .{phi.then_block_index});
    try writeEntity(writer, phi.then_entity);
    try output.insertFormatted(") (%b{} ", .{phi.else_block_index});
    try writeEntity(writer, phi.else_entity);
    try output.insertSlice(")))");
}

fn writeJump(writer: Writer, block: Block, block_entity: usize) !void {
    const output = writer.output;
    const jump = block.jumps.items[block.indices.items[block_entity]];
    try output.insertFormatted("\n    (jump %b{})", .{jump});
}

fn writeExpressions(writer: Writer, block: Block) !void {
    try writer.output.insertSlice(")\n    :expressions");
    for (block.kinds.slice()) |expression_kind, entity| {
        switch (expression_kind) {
            .Return => try writeReturn(writer, block, entity),
            .Call => try writeCall(writer, block, entity),
            .Branch => try writeBranch(writer, block, entity),
            .Phi => try writePhi(writer, block, entity),
            .Jump => try writeJump(writer, block, entity),
        }
    }
}

fn writeBlocks(writer: Writer) !void {
    const output = writer.output;
    try output.insertSlice("\n  :blocks");
    for (writer.overload.blocks.slice()) |block, i| {
        try output.insertSlice("\n  (block ");
        try output.insertFormatted("%b{}", .{i});
        try writeActiveScopes(output, block);
        try writeExpressions(writer, block);
        _ = try output.insert(')');
    }
}

fn functionString(allocator: *Allocator, output: *List(u8), interned_strings: InternedStrings, ir: Ir, ir_entity: usize) !void {
    const string_index = ir.names.items[ir_entity];
    const name = interned_strings.data.items[string_index];
    const overloads = ir.functions.items[ir.indices.items[ir_entity]].slice();
    for (overloads) |overload, i| {
        var anonymous_entity_to_name = Map(usize, usize).init(allocator);
        defer anonymous_entity_to_name.deinit();
        try output.insertSlice("(fn ");
        try output.insertSlice(name);
        try writeParameterName(output, overload, interned_strings);
        try writeParameterTypeBlock(output, overload);
        try output.insertSlice(")\n  :return-type-blocks ");
        try output.insertFormatted("%b{}", .{overload.return_type_block_index});
        try output.insertSlice("\n  :body-block ");
        try output.insertFormatted("%b{}", .{overload.body_block_index});
        const writer = Writer{
            .output = output,
            .anonymous_entity_to_name = &anonymous_entity_to_name,
            .overload = &overload,
            .interned_strings = &interned_strings,
        };
        try writeScopes(writer);
        try writeBlocks(writer);
        _ = try output.insert(')');
        if (i < overloads.len - 1) try output.insertSlice("\n\n");
    }
}

pub fn irString(allocator: *std.mem.Allocator, interned_strings: InternedStrings, ir: Ir) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    const kinds = ir.kinds.slice();
    for (kinds) |kind, i| {
        switch (kind) {
            .Function => try functionString(allocator, &output, interned_strings, ir, i),
        }
        if (i < kinds.len - 1) try output.insertSlice("\n\n");
    }
    return output;
}
