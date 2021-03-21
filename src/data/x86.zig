const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;
const Set = @import("set.zig").Set;
const InternedString = @import("interned_strings.zig").InternedString;
const Entity = @import("ir.zig").Entity;

pub const StorageKind = enum(u8) {
    Register,
    SseRegister,
    Stack,
};

pub const Storage = struct {
    kind: StorageKind,
    value: usize,
};

pub const A = 0;
pub const C = 1;
pub const D = 2;
pub const B = 3;
pub const SP = 4;
pub const BP = 5;
pub const SI = 6;
pub const DI = 7;

pub const Register = u8;

pub const RegisterKind = enum { Volatle, Stable };

pub const register_kind = blk: {
    var array: [16]RegisterKind = undefined;
    for ([_]Register{ A, C, D, SP, BP, SI, DI, 8, 9, 10, 11 }) |register|
        array[register] = .Volatle;
    for ([_]Register{ B, 12, 13, 14, 15 }) |register|
        array[register] = .Stable;
    break :blk array;
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
    QuadWordPtr,
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

pub fn RegisterStack(comptime n: Register) type {
    return struct {
        data: [n]Register,
        head: Register,
    };
}

pub const Registers = struct {
    stored_entity: [16]?Entity,
    volatle: RegisterStack(9),
    stable: RegisterStack(5),
};

pub const SseRegisters = struct {
    stored_entity: [16]?Entity,
    volatle: RegisterStack(8),
    stable: RegisterStack(8),
};

pub const Memory = struct {
    registers: Registers,
    sse_registers: SseRegisters,
    storage_for_entity: Map(Entity, Storage),
    preserved: [16]?usize,
    stack: usize,
};

pub fn initMemory(allocator: *Allocator) Memory {
    return Memory{
        .registers = Registers{
            .stored_entity = [_]?Entity{null} ** 16,
            .volatle = RegisterStack(9){
                .data = [_]Register{ A, C, D, SI, DI, 8, 9, 10, 11 },
                .head = 0,
            },
            .stable = RegisterStack(5){
                .data = [_]Register{ B, 12, 13, 14, 15 },
                .head = 0,
            },
        },
        .sse_registers = SseRegisters{
            .stored_entity = [_]?Entity{null} ** 16,
            .volatle = RegisterStack(8){
                .data = [_]Register{ 0, 1, 2, 3, 4, 5, 6, 7 },
                .head = 0,
            },
            .stable = RegisterStack(8){
                .data = [_]Register{ 8, 9, 10, 11, 12, 13, 14, 15 },
                .head = 0,
            },
        },
        .storage_for_entity = Map(Entity, Storage).init(allocator),
        .preserved = [_]?usize{null} ** 16,
        .stack = 0,
    };
}
