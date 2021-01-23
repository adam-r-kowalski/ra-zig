const std = @import("std");
const Module = @import("module.zig").Module;
const ast = @import("ast.zig");
const ssa = @import("ssa.zig");
const List = @import("list.zig").List;

fn writeString(output: *List(u8), module: Module, kind: []const u8, index: usize) !void {
    _ = try output.insert('(');
    try output.insertSlice(kind);
    _ = try output.insert(' ');
    try output.insertSlice(module.strings.data.items[index]);
    _ = try output.insert(')');
}

fn writeList(output: *List(u8), module: Module, kind: []const u8, index: usize, depth: usize) !void {
    _ = try output.insert('(');
    try output.insertSlice(kind);
    for (module.ast.children.items[index]) |child| {
        _ = try output.insert('\n');
        try expressionString(output, module, child, depth + 2);
    }
    _ = try output.insert(')');
}

fn expressionString(output: *List(u8), module: Module, index: usize, depth: usize) error{OutOfMemory}!void {
    var i: usize = 0;
    while (i < depth) : (i += 1) _ = try output.insert(' ');
    const data_index = module.ast.indices.items[index];
    switch (module.ast.kinds.items[index]) {
        .Int => try writeString(output, module, "int", data_index),
        .Symbol => try writeString(output, module, "symbol", data_index),
        .Keyword => try writeString(output, module, "keyword", data_index),
        .Parens => try writeList(output, module, "parens", data_index, depth),
        .Brackets => try writeList(output, module, "brackets", data_index, depth),
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
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    for (module.ssa.kinds.slice()) |kind, i| {
        switch (kind) {
            .Function => {
                const name = module.strings.data.items[module.ssa.names.items[i]];
                const function = module.ssa.functions.items[module.ssa.indices.items[i]];
                for (function.slice()) |overload| {
                    try output.insertSlice("(fn ");
                    try output.insertSlice(name);
                    try output.insertSlice("\n  :parameter-names (");
                    for (overload.parameter_names) |parameter_name, j| {
                        try output.insertSlice(module.strings.data.items[parameter_name]);
                        if (j < overload.parameter_names.len - 1)
                            _ = try output.insert(' ');
                    }
                    try output.insertSlice(")\n  :parameter-type-blocks ()\n");
                }
            },
        }
    }
    return output;
}
