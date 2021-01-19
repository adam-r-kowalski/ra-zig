const std = @import("std");
const Module = @import("module.zig").Module;
const list = @import("list.zig");
const List = list.List;

pub fn codegen(allocator: *std.mem.Allocator, module: Module) !List(u8) {
    var x86 = list.init(u8, allocator);
    try list.insertSlice(u8, &x86,
        \\          global _main
        \\
        \\          section .text
        \\_main:    mov rax, 0x2000001
        \\          mov rdi, 52
        \\          syscall
    );
    return x86;
}
