const std = @import("std");
// const Module = @import("module.zig").Module;
// const ast = @import("ast.zig");
// const ssa = @import("ssa.zig");
const List = @import("list.zig").List;

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
                    try output.insertSlice(")\n  :parameter-type-blocks (");
                    for (overload.parameter_type_blocks) |block, j| {
                        try output.insertFormatted("%b{}", .{block});
                        if (j < overload.parameter_type_blocks.len - 1)
                            _ = try output.insert(' ');
                    }
                    try output.insertSlice(")\n  :return-type-blocks (");
                }
            },
        }
    }
    return output;
}
