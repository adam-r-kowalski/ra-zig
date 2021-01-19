const std = @import("std");
const Module = @import("module.zig").Module;
const ssa = @import("ssa.zig");
const list = @import("list.zig");
const List = list.List;

fn expressionString(output: *List(u8), module: Module, index: usize, depth: usize) error{OutOfMemory}!void {
    var i: usize = 0;
    while (i < depth) : (i += 1) _ = try list.insert(u8, output, ' ');
    const data_index = module.ast.indices.items[index];
    switch (module.ast.kinds.items[index]) {
        .Int => {
            try list.insertSlice(u8, output, "(int ");
            try list.insertSlice(u8, output, module.strings.data.items[data_index]);
            _ = try list.insert(u8, output, ')');
        },
        .Symbol => {
            try list.insertSlice(u8, output, "(symbol ");
            try list.insertSlice(u8, output, module.strings.data.items[data_index]);
            _ = try list.insert(u8, output, ')');
        },
        .Keyword => {
            try list.insertSlice(u8, output, "(keyword ");
            try list.insertSlice(u8, output, module.strings.data.items[data_index]);
            _ = try list.insert(u8, output, ')');
        },
        .Parens => {
            try list.insertSlice(u8, output, "(parens");
            for (module.ast.children.items[data_index]) |child| {
                _ = try list.insert(u8, output, '\n');
                try expressionString(output, module, child, depth + 2);
            }
            _ = try list.insert(u8, output, ')');
        },
        .Brackets => {
            try list.insertSlice(u8, output, "(brackets");
            for (module.ast.children.items[data_index]) |child| {
                _ = try list.insert(u8, output, '\n');
                try expressionString(output, module, child, depth + 2);
            }
            _ = try list.insert(u8, output, ')');
        },
    }
}

pub fn astString(allocator: *std.mem.Allocator, module: Module) !List(u8) {
    var output = list.init(u8, allocator);
    errdefer list.deinit(u8, &output);
    const length = module.ast.top_level.length;
    for (list.slice(usize, module.ast.top_level)) |index, i| {
        try expressionString(&output, module, index, 0);
        if (i < length - 1) _ = try list.insert(u8, &output, '\n');
    }
    return output;
}

pub fn ssaString(allocator: *std.mem.Allocator, module: Module) !List(u8) {
    var output = list.init(u8, allocator);
    errdefer list.deinit(u8, &output);
    for (list.slice(ssa.Kind, module.ssa.kinds)) |kind, i| {
        switch (kind) {
            .OverloadSet => {
                const name = module.strings.data.items[module.ssa.names.items[i]];
                const overloads = module.ssa.overload_sets.items[module.ssa.indices.items[i]];
                for (list.slice(ssa.Function, overloads)) |overload| {
                    try list.insertSlice(u8, &output, "(fn ");
                    try list.insertSlice(u8, &output, name);
                }
            },
        }
    }
    return output;
}
