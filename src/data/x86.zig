const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;
const Set = @import("set.zig").Set;
const entity = @import("entity.zig");
const InternedString = entity.InternedString;
const Entity = entity.Entity;

pub const BlockIndex = usize;

pub const Register = enum(usize) {
    Rax,
    Eax,
    Rbx,
    Ebx,
    Rcx,
    Ecx,
    Rdx,
    Edx,
    Rsp,
    Esp,
    Rbp,
    Ebp,
    Rsi,
    Esi,
    Rdi,
    Edi,
    R8,
    R9,
    R10,
    R11,
    R12,
    R13,
    R14,
    R15,
};

pub const SseRegister = enum(usize) {
    Xmm0,
    Xmm1,
    Xmm2,
    Xmm3,
    Xmm4,
    Xmm5,
    Xmm6,
    Xmm7,
    Xmm8,
    Xmm9,
    Xmm10,
    Xmm11,
    Xmm12,
    Xmm13,
    Xmm14,
    Xmm15,
};

pub const Instruction = enum(u8) {
    Mov,
    Movsd,
    Push,
    Pop,
    Add,
    Addsd,
    Sub,
    Subsd,
    Imul,
    Mulsd,
    Idiv,
    Divsd,
    Xor,
    Or,
    Call,
    Syscall,
    Cqo,
    Ret,
};

pub const Kind = enum(u8) {
    Immediate,
    Register,
    SseRegister,
    Label,
    Literal,
    Byte,
    QuadWord,
    RelativeQword,
    StackOffsetQword,
    StackOffsetDword,
};

pub const Block = struct {
    instructions: List(Instruction),
    operand_kinds: List([]const Kind),
    operands: List([]const usize),
};

pub const X86 = struct {
    blocks: List(Block),
    externs: Set(InternedString),
    bytes: Set(InternedString),
    quad_words: Set(InternedString),
    arena: *Arena,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};

pub const Stack = struct {
    entity: Map(Entity, usize),
    top: usize,
};
