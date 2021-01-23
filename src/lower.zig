const std = @import("std");
const assert = std.debug.assert;
const Module = @import("module.zig").Module;
const List = @import("list.zig").List;
const ast = @import("ast.zig");
const ssa = @import("ssa.zig");
const Overload = ssa.Overload;
const Function = ssa.Function;
const Children = []const usize;

fn astIndex(module: *const Module, kind: ast.Kind, entity: usize) usize {
    assert(module.ast.kinds.items[entity] == kind);
    return module.ast.indices.items[entity];
}

fn astChildren(module: *const Module, kind: ast.Kind, entity: usize) Children {
    return module.ast.children.items[astIndex(module, kind, entity)];
}

fn astString(module: *const Module, kind: ast.Kind, entity: usize) []const u8 {
    return module.strings.data.items[astIndex(module, kind, entity)];
}

fn lowerParameters(module: *Module, overload: *Overload, children: Children) !void {
    assert(children.len > 1);
    assert(std.mem.eql(u8, astString(module, .Keyword, children[0]), ":args"));
    assert(children.len > 2);
    var parameters = astChildren(module, .Parens, children[1]);
    assert(parameters.len % 2 == 0);
    const parameter_names = try module.arena.allocator.alloc(usize, parameters.len / 2);
    var i: usize = 0;
    while (parameters.len > 0) : (i += 1) {
        parameter_names[i] = astIndex(module, .Symbol, parameters[0]);
        parameters = parameters[2..];
    }
    overload.parameter_names = parameter_names;
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
    const result = try function.addOne();
    try lowerParameters(module, result.ptr, children[1..]);
}

pub fn lower(module: *Module) !void {
    for (module.ast.top_level.slice()) |index| {
        const children = astChildren(module, .Parens, index);
        assert(children.len > 0);
        assert(std.mem.eql(u8, astString(module, .Symbol, children[0]), "fn"));
        try lowerOverload(module, children[1..]);
    }
}
