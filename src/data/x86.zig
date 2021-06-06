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
    Al,
    Ah,
    Rbx,
    Ebx,
    Bl,
    Bh,
    Rcx,
    Ecx,
    Cl,
    Ch,
    Rdx,
    Edx,
    Dl,
    Dh,
    Rsp,
    Esp,
    Spl,
    Rbp,
    Ebp,
    Bpl,
    Rsi,
    Esi,
    Sil,
    Rdi,
    Edi,
    Dil,
    R8,
    R8d,
    R8b,
    R9,
    R9d,
    R9b,
    R10,
    R10d,
    R10b,
    R11,
    R11d,
    R11b,
    R12,
    R12d,
    R12b,
    R13,
    R13d,
    R13b,
    R14,
    R14d,
    R14b,
    R15,
    R15d,
    R15b,
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
    And,
    Cmp,
    Je,
    Jmp,
    Sete,
    Setg,
    Call,
    Syscall,
    Cqo,
    Cdq,
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
    StackOffsetByte,
    BytePointer,
};

pub const Block = struct {
    instructions: List(Instruction),
    operand_kinds: List([]const Kind),
    operands: List([]const usize),
};

pub const UniqueIds = struct {
    string_to_index: Map(InternedString, usize),
    index_to_string: List(InternedString),
    next_index: usize,
};

pub const X86 = struct {
    blocks: List(Block),
    externs: Set(InternedString),
    bytes: UniqueIds,
    quad_words: UniqueIds,
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
