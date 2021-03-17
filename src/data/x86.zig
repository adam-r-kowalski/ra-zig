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

pub const RegisterKind = enum { CalleeSaved, CallerSaved };

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

pub const Memory = struct {
    registers: Registers,
    storage_for_entity: Map(Entity, Storage),
};

pub fn initMemory(allocator: *Allocator) Memory {
    return Memory{
        .registers = Registers{
            .stored_entity = [_]?Entity{null} ** 16,
            .volatle = RegisterStack(9){
                .data = [9]Register{ A, C, D, SI, DI, 8, 9, 10, 11 },
                .head = A,
            },
            .stable = RegisterStack(5){
                .data = [5]Register{ B, 12, 13, 14, 15 },
                .head = B,
            },
        },
        .storage_for_entity = Map(Entity, Storage).init(allocator),
    };
}

// pub const register_kind = blk: {
//     var array: [16]RegisterType = undefined;
//     for (callee_saved_registers) |register|
//         array[@enumToInt(register)] = .CalleeSaved;
//     for (caller_saved_registers) |register|
//         array[@enumToInt(register)] = .CallerSaved;
//     break :blk array;
// };

// pub const sse_register_type = blk: {
//     var array: [total_available_sse_registers]RegisterType = undefined;
//     for (callee_saved_sse_registers) |register|
//         array[@enumToInt(register)] = .CalleeSaved;
//     for (caller_saved_sse_registers) |register|
//         array[@enumToInt(register)] = .CallerSaved;
//     break :blk array;
// };
//
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
