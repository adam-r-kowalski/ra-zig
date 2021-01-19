const std = @import("std");
const Module = @import("module.zig").Module;
const ssa = @import("ssa.zig");
const Function = ssa.Function;
const list = @import("list.zig");
const List = list.List;

fn function(module: *Module, children: []const usize) !void {
    std.debug.assert(children.len > 0);
    const name_index = children[0];
    std.debug.assert(module.ast.kinds.items[name_index] == .Symbol);
    const name = module.ast.indices.items[name_index];
    const get_or_put_result = try module.ssa.contents.getOrPut(name);
    const overloads = blk: {
        if (get_or_put_result.found_existing) {
            const index = get_or_put_result.entry.value;
            std.debug.assert(module.ssa.kinds.items[index] == .OverloadSet);
            const overload_index = module.ssa.indices.items[index];
            break :blk &module.ssa.overload_sets.items[overload_index];
        } else {
            _ = try list.insert(ssa.Kind, &module.ssa.kinds, .OverloadSet);
            get_or_put_result.entry.value = try list.insert(usize, &module.ssa.names, name);
            const result = try list.addOne(List(Function), &module.ssa.overload_sets);
            result.ptr.* = list.init(Function, &module.arena.allocator);
            _ = try list.insert(usize, &module.ssa.indices, result.index);
            break :blk result.ptr;
        }
    };
    const result = try list.addOne(Function, overloads);
}

pub fn lower(module: *Module) !void {
    for (list.slice(usize, module.ast.top_level)) |index| {
        switch (module.ast.kinds.items[index]) {
            .Parens => {
                const children = module.ast.children.items[module.ast.indices.items[index]];
                std.debug.assert(children.len > 0);
                const kind = module.strings.data.items[module.ast.indices.items[children[0]]];
                std.debug.assert(std.mem.eql(u8, kind, "fn"));
                try function(module, children[1..]);
            },
            else => unreachable,
        }
    }
}
