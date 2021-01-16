const std = @import("std");
const Module = @import("module.zig").Module;
const list = @import("list.zig");
const List = list.List;

pub fn astString(allocator: *std.mem.Allocator, module: Module) !List(u8) {
    var output = list.init(u8, allocator);
    const length = module.ast.top_level.length;
    for (list.slice(usize, module.ast.top_level)) |index, i| {
        switch (module.ast.kinds.items[index]) {
            .Int => {
                try list.insertSlice(u8, &output, "(int ");
                try list.insertSlice(u8, &output, module.ast.literals.items[index]);
                _ = try list.insert(u8, &output, ')');
            },
        }
        if (i < length - 1) _ = try list.insert(u8, &output, '\n');
    }
    return output;
}
