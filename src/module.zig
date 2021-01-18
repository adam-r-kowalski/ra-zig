const std = @import("std");
const ast = @import("ast.zig");
const strings = @import("strings.zig");

pub const Module = struct {
    parent_allocator: *std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    ast: ast.Ast,
    strings: strings.Strings,
};

pub fn init(allocator: *std.mem.Allocator) !Module {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    return Module{
        .parent_allocator = allocator,
        .arena = arena,
        .ast = ast.init(&arena.allocator),
        .strings = strings.init(&arena.allocator),
    };
}

pub fn deinit(module: *Module) void {
    module.arena.deinit();
    module.parent_allocator.destroy(module.arena);
}
