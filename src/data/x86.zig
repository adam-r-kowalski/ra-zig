const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;
const InternedString = @import("interned_strings.zig").InternedString;
const Entity = @import("ir.zig").Entity;

pub const Instruction = enum(u8) {
    Mov,
    Push,
    Pop,
    Add,
    Sub,
    Imul,
    Idiv,
    Call,
    Syscall,
    Cqo,
    Ret,
};

pub const Register = enum(usize) {
    Rax,
    Rbx,
    Rcx,
    Rdx,
    Rsi,
    Rdi,
    R8,
    R9,
    R10,
    R11,
    R12,
    R13,
    R14,
    R15,
    Rbp,
    Rsp,
};

pub const Kind = enum(u8) {
    Immediate,
    Register,
    Label,
    Literal,
};

pub const Block = struct {
    instructions: List(Instruction),
    operand_kinds: List([]const Kind),
    operands: List([]const usize),
};

pub const X86 = struct {
    blocks: List(Block),
    types: Map(Entity, Entity),
    arena: *Arena,
    uses_print: bool,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
