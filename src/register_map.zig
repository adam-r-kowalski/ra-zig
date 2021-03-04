const std = @import("std");
const assert = std.debug.assert;
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const data = @import("data.zig");
const Map = data.Map;
const Register = data.x86.Register;
const Entity = data.ir.Entity;

pub const caller_saved_registers = [9]Register{ .Rax, .Rcx, .Rdx, .Rsi, .Rdi, .R8, .R9, .R10, .R11 };
pub const callee_saved_registers = [5]Register{ .Rbx, .R12, .R13, .R14, .R15 };
pub const total_available_registers = callee_saved_registers.len + caller_saved_registers.len;

const RegisterType = enum { CalleeSaved, CallerSaved };

pub const register_type = blk: {
    var array: [total_available_registers]RegisterType = undefined;
    for (callee_saved_registers) |register|
        array[@enumToInt(register)] = .CalleeSaved;
    for (caller_saved_registers) |register|
        array[@enumToInt(register)] = .CallerSaved;
    break :blk array;
};

fn RegisterStack(comptime n: u8) type {
    return struct {
        length: u8,
    };
}

pub const RegisterMap = struct {
    entity_to_register: Map(Entity, Register),
    register_to_entity: [total_available_registers]?Entity,
    free_callee_saved_registers: [callee_saved_registers.len]Register,
    free_caller_saved_registers: [caller_saved_registers.len]Register,
    free_callee_saved_length: u8,
    free_caller_saved_length: u8,
    arena: *Arena,
};

pub fn pushFreeRegister(register_map: *RegisterMap, register: Register) void {
    switch (register_type[@enumToInt(register)]) {
        .CalleeSaved => {
            const n = register_map.free_callee_saved_registers.len;
            assert(register_map.free_callee_saved_length < n);
            register_map.free_callee_saved_length += 1;
            register_map.free_callee_saved_registers[n - register_map.free_callee_saved_length] = register;
        },
        .CallerSaved => {
            const n = register_map.free_caller_saved_registers.len;
            assert(register_map.free_caller_saved_length < n);
            register_map.free_caller_saved_length += 1;
            register_map.free_caller_saved_registers[n - register_map.free_caller_saved_length] = register;
        },
    }
}

pub fn popFreeRegister(register_map: *RegisterMap) ?Register {
    if (register_map.free_callee_saved_length > 0) {
        const index = register_map.free_callee_saved_registers.len - register_map.free_callee_saved_length;
        const register = register_map.free_callee_saved_registers[index];
        register_map.free_callee_saved_length -= 1;
        return register;
    }
    if (register_map.free_caller_saved_length > 0) {
        const index = register_map.free_caller_saved_registers.len - register_map.free_caller_saved_length;
        const register = register_map.free_caller_saved_registers[index];
        register_map.free_caller_saved_length -= 1;
        return register;
    }
    return null;
}

pub fn initRegisterMap(allocator: *Allocator) !RegisterMap {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    return RegisterMap{
        .entity_to_register = Map(Entity, Register).init(&arena.allocator),
        .register_to_entity = .{null} ** total_available_registers,
        .free_callee_saved_registers = callee_saved_registers,
        .free_callee_saved_length = callee_saved_registers.len,
        .free_caller_saved_registers = caller_saved_registers,
        .free_caller_saved_length = caller_saved_registers.len,
        .arena = arena,
    };
}

pub fn deinitRegisterMap(regiseter_map: *RegisterMap) void {
    regiseter_map.arena.deinit();
    regiseter_map.arena.child_allocator.destroy(regiseter_map.arena);
}
