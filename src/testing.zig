const std = @import("std");
const Module = @import("module.zig").Module;
const ast = @import("ast.zig");
const ssa = @import("ssa.zig");
const List = @import("list.zig").List;

fn expressionString(output: *List(u8), module: Module, id: ast.EntityId, depth: usize) error{OutOfMemory}!void {
    var i: usize = 0;
    while (i < depth) : (i += 1) _ = try output.insert(' ');
    const entity = module.ast.entities.lookup(id);
    switch (entity.kind) {
        .Int => {
            try output.insertSlice("(int ");
            try output.insertSlice(module.strings.data.items[entity.foreign_id]);
            _ = try output.insert(')');
        },
        .Symbol => {
            try output.insertSlice("(symbol ");
            try output.insertSlice(module.strings.data.items[entity.foreign_id]);
            _ = try output.insert(')');
        },
        .Keyword => {
            try output.insertSlice("(keyword ");
            try output.insertSlice(module.strings.data.items[entity.foreign_id]);
            _ = try output.insert(')');
        },
        .Parens => {
            try output.insertSlice("(parens");
            for (module.ast.children.items[entity.foreign_id]) |child| {
                _ = try output.insert('\n');
                try expressionString(output, module, child, depth + 2);
            }
            _ = try output.insert(')');
        },
        .Brackets => {
            try output.insertSlice("(brackets");
            for (module.ast.children.items[entity.foreign_id]) |child| {
                _ = try output.insert('\n');
                try expressionString(output, module, child, depth + 2);
            }
            _ = try output.insert(')');
        },
    }
}

pub fn astString(allocator: *std.mem.Allocator, module: Module) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    const length = module.ast.top_level.length;
    for (module.ast.top_level.slice()) |index, i| {
        try expressionString(&output, module, index, 0);
        if (i < length - 1) _ = try output.insert('\n');
    }
    return output;
}

pub fn ssaString(allocator: *std.mem.Allocator, module: Module) !List(u8) {
    var output = list.init(u8, allocator);
    errdefer list.deinit(u8, &output);
    for (list.slice(ssa.Kind, module.ssa.kinds)) |kind, i| {
        switch (kind) {
            .Function => {
                const name = module.strings.data.items[module.ssa.names.items[i]];
                const function = module.ssa.functions.items[module.ssa.indices.items[i]];
                for (list.slice(ssa.Overload, function)) |overload| {
                    try list.insertSlice(u8, &output, "(fn ");
                    try list.insertSlice(u8, &output, name);
                }
            },
        }
    }
    return output;
}
