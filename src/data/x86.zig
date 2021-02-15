const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;

pub const Instruction = enum(u8) {
    Mov,
    Push,
    Pop,
    Add,
    Call,
    Syscall,
};

pub const Register = enum(usize) {
    Rax,
    Rdx,
    Rbp,
    Rsp,
    Rdi,
};

pub const Kind = enum(u8) {
    Immediate,
    Register,
    Label,
};

pub const Labels = enum(usize) {
    EntryPoint,
    Main,
};

pub const Block = struct {
    instructions: List(Instruction),
    operand_kinds: List([]const Kind),
    operands: List([]const usize),
};

pub const X86 = struct {
    blocks: List(Block),
    arena: *Arena,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
