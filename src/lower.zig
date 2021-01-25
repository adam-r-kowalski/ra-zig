const std = @import("std");
const assert = std.debug.assert;
const module_ = @import("module.zig");
const Ast = module_.Ast;
const Ssa = module_.Ssa;
const Overload = module_.Overload;
const Function = module_.Function;
const BasicBlock = module_.BasicBlock;
const Scope = module_.Scope;
const Module = module_.Module;
const List = @import("list.zig").List;
const Children = []const usize;

fn astIndex(module: *const Module, kind: Ast.Kind, entity: usize) usize {
    assert(module.ast.kinds.items[entity] == kind);
    return module.ast.indices.items[entity];
}

fn astChildren(module: *const Module, kind: Ast.Kind, entity: usize) Children {
    return module.ast.children.items[astIndex(module, kind, entity)];
}

fn astString(module: *const Module, kind: Ast.Kind, entity: usize) []const u8 {
    return module.strings.data.items[astIndex(module, kind, entity)];
}

fn lowerParameters(module: *Module, overload: *Overload, children: Children) !void {
    assert(children.len > 1);
    assert(std.mem.eql(u8, astString(module, .Keyword, children[0]), ":args"));
    assert(children.len > 2);
    var parameters = astChildren(module, .Parens, children[1]);
    assert(parameters.len % 2 == 0);
    const parameter_count = parameters.len / 2;
    const parameter_names = try module.arena.allocator.alloc(usize, parameter_count);
    const parameter_type_blocks = try module.arena.allocator.alloc(usize, parameter_count);
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

fn lowerOverload(module: *Module, children: Children) !void {
    assert(children.len > 0);
    const name = astIndex(module, .Symbol, children[0]);
    const get_or_put_result = try module.ssa.name_to_index.getOrPut(name);
    const function = blk: {
        if (get_or_put_result.found_existing) {
            const index = get_or_put_result.entry.value;
            assert(module.ssa.kinds.items[index] == .Function);
            const function_index = module.ssa.indices.items[index];
            break :blk &module.ssa.functions.items[function_index];
        } else {
            _ = try module.ssa.kinds.insert(.Function);
            get_or_put_result.entry.value = try module.ssa.names.insert(name);
            const result = try module.ssa.functions.addOne();
            result.ptr.* = List(Overload).init(&module.arena.allocator);
            _ = try module.ssa.indices.insert(result.index);
            break :blk result.ptr;
        }
    };
    const overload = (try function.addOne()).ptr;
    overload.scopes = List(Scope).init(&module.arena.allocator);
    overload.basic_blocks = List(BasicBlock).init(&module.arena.allocator);
    var remaining_children = children[1..];
    while (remaining_children.len > 0) {
        assert(module.ast.kinds.items[remaining_children[0]] == .Keyword);
        remaining_children = remaining_children[2..];
    }
    // try lowerParameters(module, overload, children[1..]);
}

pub fn lower(module: *Module) !void {
    for (module.ast.top_level.slice()) |index| {
        const children = astChildren(module, .Parens, index);
        assert(children.len > 0);
        assert(std.mem.eql(u8, astString(module, .Symbol, children[0]), "fn"));
        try lowerOverload(module, children[1..]);
    }
}
