const std = @import("std");
const ast = @import("ast.zig");

pub const Module = struct {
    allocator: *std.mem.Allocator,
    arena: *std.heap.ArenaAllocator,
    ast: ast.Ast,
};

pub fn init(allocator: *std.mem.Allocator) !Module {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    return Module{
        .allocator = allocator,
        .arena = arena,
        .ast = ast.init(&arena.allocator),
    };
}

pub fn deinit(module: *Module) void {
    module.arena.deinit();
    module.allocator.destroy(module.arena);
}
