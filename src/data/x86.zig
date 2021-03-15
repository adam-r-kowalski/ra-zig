const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;
const Set = @import("set.zig").Set;
const InternedString = @import("interned_strings.zig").InternedString;
const Entity = @import("ir.zig").Entity;

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

pub const caller_saved_registers = [9]Register{ .Rax, .Rcx, .Rdx, .Rsi, .Rdi, .R8, .R9, .R10, .R11 };
pub const callee_saved_registers = [5]Register{ .Rbx, .R12, .R13, .R14, .R15 };
pub const total_available_registers = callee_saved_registers.len + caller_saved_registers.len;

pub const caller_saved_sse_registers = [8]SseRegister{ .Xmm0, .Xmm1, .Xmm2, .Xmm3, .Xmm4, .Xmm5, .Xmm6, .Xmm7 };
pub const callee_saved_sse_registers = [8]SseRegister{ .Xmm8, .Xmm9, .Xmm10, .Xmm11, .Xmm12, .Xmm13, .Xmm14, .Xmm15 };
pub const total_available_sse_registers = callee_saved_sse_registers.len + caller_saved_sse_registers.len;

pub const RegisterType = enum { CalleeSaved, CallerSaved };

pub const register_type = blk: {
    var array: [total_available_registers]RegisterType = undefined;
    for (callee_saved_registers) |register|
        array[@enumToInt(register)] = .CalleeSaved;
    for (caller_saved_registers) |register|
        array[@enumToInt(register)] = .CallerSaved;
    break :blk array;
};

pub const sse_register_type = blk: {
    var array: [total_available_sse_registers]RegisterType = undefined;
    for (callee_saved_sse_registers) |register|
        array[@enumToInt(register)] = .CalleeSaved;
    for (caller_saved_sse_registers) |register|
        array[@enumToInt(register)] = .CallerSaved;
    break :blk array;
};

pub const RegisterMap = struct {
    entity_to_register: Map(Entity, Register),
    register_to_entity: [total_available_registers]?Entity,
    free_callee_saved_registers: [callee_saved_registers.len]Register,
    free_caller_saved_registers: [caller_saved_registers.len]Register,
    free_callee_saved_length: u8,
    free_caller_saved_length: u8,
};

pub const SseRegisterMap = struct {
    entity_to_register: Map(Entity, SseRegister),
    register_to_entity: [total_available_sse_registers]?Entity,
    free_callee_saved_registers: [callee_saved_sse_registers.len]SseRegister,
    free_caller_saved_registers: [caller_saved_sse_registers.len]SseRegister,
    free_callee_saved_length: u8,
    free_caller_saved_length: u8,
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
    RelativeQuadWord,
};

pub const Block = struct {
    instructions: List(Instruction),
    operand_kinds: List([]const Kind),
    operands: List([]const usize),
};

pub const X86 = struct {
    blocks: List(Block),
    types: Map(Entity, Entity),
    externs: Set(InternedString),
    bytes: Set(InternedString),
    quad_words: Set(InternedString),
    arena: *Arena,

    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.arena.child_allocator.destroy(self.arena);
    }
};
