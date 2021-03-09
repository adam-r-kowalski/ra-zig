const std = @import("std");
const assert = std.debug.assert;
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const data = @import("data.zig");
const InternedStrings = data.interned_strings.InternedStrings;
const InternedString = data.interned_strings.InternedString;
const intern = data.interned_strings.intern;
const Strings = data.interned_strings.Strings;
const DeclarationKind = data.ir.DeclarationKind;
const IrBlock = data.ir.Block;
const Ir = data.ir.Ir;
const Builtins = data.ir.Builtins;
const Overload = data.ir.Overload;
const Entity = data.ir.Entity;
const Call = data.ir.Call;
const X86 = data.x86.X86;
const X86Block = data.x86.Block;
const Instruction = data.x86.Instruction;
const Kind = data.x86.Kind;
const Register = data.x86.Register;
const SseRegister = data.x86.SseRegister;
const List = data.List;
const Map = data.Map;
const Set = data.Set;
const Label = usize;
const Immediate = usize;
const RegisterMap = data.x86.RegisterMap;
const SseRegisterMap = data.x86.SseRegisterMap;
const Int = @enumToInt(Builtins.Int);
const I64 = @enumToInt(Builtins.I64);
const Float = @enumToInt(Builtins.Float);
const F64 = @enumToInt(Builtins.F64);

pub fn pushFreeRegister(register_map: *RegisterMap, register: Register) void {
    switch (data.x86.register_type[@enumToInt(register)]) {
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

pub fn pushFreeSseRegister(sse_register_map: *SseRegisterMap, register: SseRegister) void {
    const n = sse_register_map.free_registers.len;
    assert(sse_register_map.length < n);
    sse_register_map.length += 1;
    sse_register_map.free_registers[n - sse_register_map.length] = register;
}

pub fn popFreeSseRegister(sse_register_map: *SseRegisterMap) ?SseRegister {
    assert(sse_register_map.length > 0);
    const index = sse_register_map.free_registers.len - sse_register_map.length;
    const register = sse_register_map.free_registers[index];
    sse_register_map.length -= 1;
    return register;
}

const Context = struct {
    allocator: *Allocator,
    overload: *const Overload,
    x86: *X86,
    x86_block: *X86Block,
    ir_block: *const IrBlock,
    register_map: *RegisterMap,
    sse_register_map: *SseRegisterMap,
    interned_strings: *InternedStrings,
};

fn opLiteral(context: Context, op: Instruction, lit: InternedString) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 1);
    operand_kinds[0] = .Literal;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 1);
    operands[0] = lit;
    _ = try context.x86_block.operands.insert(operands);
}

fn opRegReg(context: Context, op: Instruction, to: Register, from: Register) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Register;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = @enumToInt(from);
    _ = try context.x86_block.operands.insert(operands);
}

fn opSseRegSseReg(context: Context, op: Instruction, to: SseRegister, from: SseRegister) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .SseRegister;
    operand_kinds[1] = .SseRegister;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = @enumToInt(from);
    _ = try context.x86_block.operands.insert(operands);
}

fn opRegLiteral(context: Context, op: Instruction, to: Register, lit: InternedString) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Literal;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = lit;
    _ = try context.x86_block.operands.insert(operands);
}

fn opRegByte(context: Context, op: Instruction, to: Register, byte: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Byte;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = byte;
    _ = try context.x86_block.operands.insert(operands);
}

fn opSseRegRelQuadWord(context: Context, op: Instruction, to: SseRegister, quad_word: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .SseRegister;
    operand_kinds[1] = .RelativeQuadWord;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = quad_word;
    _ = try context.x86_block.operands.insert(operands);
}

fn opReg(context: Context, op: Instruction, reg: Register) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 1);
    operand_kinds[0] = .Register;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 1);
    operands[0] = @enumToInt(reg);
    _ = try context.x86_block.operands.insert(operands);
}

fn opNoArgs(x86_block: *X86Block, op: Instruction) !void {
    _ = try x86_block.instructions.insert(op);
    _ = try x86_block.operand_kinds.insert(&.{});
    _ = try x86_block.operands.insert(&.{});
}

fn moveEntityToRegister(context: Context, entity: Entity) !Register {
    if (context.register_map.entity_to_register.get(entity)) |register| return register;
    const value = context.overload.entities.values.get(entity).?;
    const register = popFreeRegister(context.register_map).?;
    try opRegLiteral(context, .Mov, register, value);
    try context.register_map.entity_to_register.put(entity, register);
    context.register_map.register_to_entity[@enumToInt(register)] = entity;
    return register;
}

fn moveEntityToSseRegister(context: Context, entity: Entity) !SseRegister {
    if (context.sse_register_map.entity_to_register.get(entity)) |register| return register;
    const value = context.overload.entities.values.get(entity).?;
    try context.x86.quad_words.insert(value);
    const register = popFreeSseRegister(context.sse_register_map).?;
    try opSseRegRelQuadWord(context, .Movsd, register, value);
    try context.sse_register_map.entity_to_register.put(entity, register);
    context.sse_register_map.register_to_entity[@enumToInt(register)] = entity;
    return register;
}

fn moveEntityToSpecificRegister(context: Context, entity: Entity, register: Register) !void {
    if (context.register_map.register_to_entity[@enumToInt(register)]) |entity_in_register| {
        if (entity_in_register == entity) return;
        const free_register = popFreeRegister(context.register_map).?;
        try opRegReg(context, .Mov, free_register, register);
        try context.register_map.entity_to_register.put(entity_in_register, free_register);
        context.register_map.register_to_entity[@enumToInt(free_register)] = entity_in_register;
    } else {
        switch (data.x86.register_type[@enumToInt(register)]) {
            .CalleeSaved => {
                const length = context.register_map.free_callee_saved_length - 1;
                for (context.register_map.free_callee_saved_registers[0..length]) |current_register, i| {
                    if (current_register == register) {
                        context.register_map.free_callee_saved_registers[i] = context.register_map.free_callee_saved_registers[length];
                        context.register_map.free_callee_saved_registers[length] = register;
                    }
                }
                context.register_map.free_callee_saved_length = length;
            },
            .CallerSaved => {
                const length = context.register_map.free_caller_saved_length - 1;
                for (context.register_map.free_caller_saved_registers[0..length]) |current_register, i| {
                    if (current_register == register) {
                        context.register_map.free_caller_saved_registers[i] = context.register_map.free_caller_saved_registers[length];
                        context.register_map.free_caller_saved_registers[length] = register;
                    }
                }
                context.register_map.free_caller_saved_length = length;
            },
        }
    }
    if (context.register_map.entity_to_register.get(entity)) |current_register| {
        if (current_register == register) return;
        try opRegReg(context, .Mov, register, current_register);
        pushFreeRegister(context.register_map, current_register);
    } else {
        const value = context.overload.entities.values.get(entity).?;
        try opRegLiteral(context, .Mov, register, value);
    }
    try context.register_map.entity_to_register.put(entity, register);
    context.register_map.register_to_entity[@enumToInt(register)] = entity;
}

fn moveEntityToSpecificSseRegister(context: Context, entity: Entity, register: SseRegister) !void {
    if (context.sse_register_map.register_to_entity[@enumToInt(register)]) |entity_in_register| {
        if (entity_in_register == entity) return;
        const free_register = popFreeSseRegister(context.sse_register_map).?;
        try opSseRegSseReg(context, .Movsd, free_register, register);
        try context.sse_register_map.entity_to_register.put(entity_in_register, free_register);
        context.register_map.register_to_entity[@enumToInt(free_register)] = entity_in_register;
    } else {
        const length = context.sse_register_map.length - 1;
        for (context.sse_register_map.free_registers[0..length]) |current_register, i| {
            if (current_register == register) {
                context.sse_register_map.free_registers[i] = context.sse_register_map.free_registers[length];
                context.sse_register_map.free_registers[length] = register;
            }
        }
        context.sse_register_map.length = length;
    }
    if (context.sse_register_map.entity_to_register.get(entity)) |current_register| {
        if (current_register == register) return;
        try opSseRegSseReg(context, .Movsd, register, current_register);
        pushFreeSseRegister(context.sse_register_map, current_register);
    } else {
        const value = context.overload.entities.values.get(entity).?;
        try context.x86.quad_words.insert(value);
        try opSseRegRelQuadWord(context, .Movsd, register, value);
    }
    try context.sse_register_map.entity_to_register.put(entity, register);
    context.sse_register_map.register_to_entity[@enumToInt(register)] = entity;
}

fn preserveCallerSaveRegisters(context: Context) !void {
    for (data.x86.caller_saved_registers) |register| {
        if (context.register_map.register_to_entity[@enumToInt(register)]) |entity| {
            assert(context.register_map.free_callee_saved_length > 0);
            const index = context.register_map.free_callee_saved_registers.len - context.register_map.free_callee_saved_length;
            const free_register = context.register_map.free_callee_saved_registers[index];
            context.register_map.free_callee_saved_length -= 1;
            try opRegReg(context, .Mov, free_register, register);
            try context.register_map.entity_to_register.put(entity, free_register);
            context.register_map.register_to_entity[@enumToInt(free_register)] = entity;
            context.register_map.register_to_entity[@enumToInt(register)] = null;
        }
    }
}

fn ensureRegisterAvailable(context: Context, register: Register) !void {
    if (context.register_map.register_to_entity[@enumToInt(register)]) |entity| {
        const free_register = popFreeRegister(context.register_map).?;
        try opRegReg(context, .Mov, free_register, register);
        pushFreeRegister(context.register_map, register);
        try context.register_map.entity_to_register.put(entity, free_register);
        context.register_map.register_to_entity[@enumToInt(free_register)] = entity;
        context.register_map.register_to_entity[@enumToInt(register)] = null;
    }
}

fn codegenPrintI64(context: Context, call: Call) !void {
    try ensureRegisterAvailable(context, .Rdi);
    try ensureRegisterAvailable(context, .Rax);
    const eight = try intern(context.interned_strings, "8");
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try moveEntityToSpecificRegister(context, call.argument_entities[0], .Rsi);
    try preserveCallerSaveRegisters(context);
    const format_string = try intern(context.interned_strings, "\"%ld\", 10, 0");
    try context.x86.bytes.insert(format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    const printf = try intern(context.interned_strings, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try opRegLiteral(context, .Add, .Rsp, eight);
    try context.register_map.entity_to_register.put(call.result_entity, .Rax);
    context.register_map.register_to_entity[@enumToInt(Register.Rax)] = call.result_entity;
}

fn codegenPrintF64(context: Context, call: Call) !void {
    try ensureRegisterAvailable(context, .Rdi);
    try ensureRegisterAvailable(context, .Rax);
    const eight = try intern(context.interned_strings, "8");
    try opRegLiteral(context, .Sub, .Rsp, eight);
    const argument = call.argument_entities[0];
    try moveEntityToSpecificSseRegister(context, call.argument_entities[0], .Xmm0);
    try preserveCallerSaveRegisters(context);
    const format_string = try intern(context.interned_strings, "\"%f\", 10, 0");
    try context.x86.bytes.insert(format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    const printf = try intern(context.interned_strings, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try opRegLiteral(context, .Add, .Rsp, eight);
    try context.register_map.entity_to_register.put(call.result_entity, .Rax);
    context.register_map.register_to_entity[@enumToInt(Register.Rax)] = call.result_entity;
}

fn typeOf(context: Context, entity: Entity) !Entity {
    if (context.x86.types.get(entity)) |type_entity|
        return type_entity;
    if (context.overload.entities.kinds.get(entity)) |kind| {
        const type_entity = @enumToInt(switch (kind) {
            .Int => Builtins.Int,
            .Float => Builtins.Float,
        });
        try context.x86.types.putNoClobber(entity, type_entity);
        return type_entity;
    }
    unreachable;
}

fn codegenPrint(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 1);
    const argument = call.argument_entities[0];
    switch (try typeOf(context, argument)) {
        Int, I64 => try codegenPrintI64(context, call),
        Float, F64 => try codegenPrintF64(context, call),
        else => unreachable,
    }
}

const BinaryOps = struct {
    int: Instruction,
    float: Instruction,
};

const AddOps = BinaryOps{ .int = .Add, .float = .Addsd };
const SubOps = BinaryOps{ .int = .Sub, .float = .Subsd };
const MulOps = BinaryOps{ .int = .Imul, .float = .Mulsd };

fn codegenBinaryOpIntInt(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    const lhs_register = try moveEntityToRegister(context, lhs);
    const rhs_register = try moveEntityToRegister(context, rhs);
    try opRegReg(context, op, lhs_register, rhs_register);
    try context.register_map.entity_to_register.put(call.result_entity, lhs_register);
    context.register_map.register_to_entity[@enumToInt(lhs_register)] = call.result_entity;
    context.register_map.entity_to_register.removeAssertDiscard(rhs);
    try context.x86.types.putNoClobber(call.result_entity, I64);
}

fn codegenBinaryOpFloatFloat(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    const lhs_register = try moveEntityToSseRegister(context, lhs);
    const rhs_register = try moveEntityToSseRegister(context, rhs);
    try opSseRegSseReg(context, op, lhs_register, rhs_register);
    try context.sse_register_map.entity_to_register.put(call.result_entity, lhs_register);
    context.sse_register_map.register_to_entity[@enumToInt(lhs_register)] = call.result_entity;
    context.sse_register_map.entity_to_register.removeAssertDiscard(rhs);
    try context.x86.types.putNoClobber(call.result_entity, F64);
}

fn codegenBinaryOp(context: Context, call: Call, ops: BinaryOps) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (try typeOf(context, lhs)) {
        Int => switch (try typeOf(context, rhs)) {
            Int, I64 => try codegenBinaryOpIntInt(context, call, ops.int, lhs, rhs),
            Float, F64 => try codegenBinaryOpFloatFloat(context, call, ops.float, lhs, rhs),
            else => unreachable,
        },
        I64 => switch (try typeOf(context, rhs)) {
            Int, I64 => try codegenBinaryOpIntInt(context, call, ops.int, lhs, rhs),
            else => unreachable,
        },
        Float, F64 => switch (try typeOf(context, rhs)) {
            Int, Float, F64 => try codegenBinaryOpFloatFloat(context, call, ops.float, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenDivideIntInt(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    const lhs_register = Register.Rax;
    try moveEntityToSpecificRegister(context, lhs, lhs_register);
    var rhs_register = try moveEntityToRegister(context, rhs);
    if (context.register_map.register_to_entity[@enumToInt(Register.Rdx)]) |entity| {
        const register = popFreeRegister(context.register_map).?;
        try opRegReg(context, .Mov, register, .Rdx);
        context.register_map.register_to_entity[@enumToInt(register)] = entity;
        try context.register_map.entity_to_register.put(entity, register);
        if (entity == rhs) rhs_register = register;
    }
    try opNoArgs(context.x86_block, .Cqo);
    try opReg(context, .Idiv, rhs_register);
    try context.register_map.entity_to_register.put(call.result_entity, lhs_register);
    context.register_map.register_to_entity[@enumToInt(lhs_register)] = call.result_entity;
    context.register_map.entity_to_register.removeAssertDiscard(rhs);
    try context.x86.types.putNoClobber(call.result_entity, I64);
}

fn codegenDivide(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (try typeOf(context, lhs)) {
        Int => switch (try typeOf(context, rhs)) {
            Int, I64 => try codegenDivideIntInt(context, call, lhs, rhs),
            Float, F64 => try codegenBinaryOpFloatFloat(context, call, .Divsd, lhs, rhs),
            else => unreachable,
        },
        I64 => switch (try typeOf(context, rhs)) {
            Int, I64 => try codegenDivideIntInt(context, call, lhs, rhs),
            else => unreachable,
        },
        Float, F64 => switch (try typeOf(context, rhs)) {
            Int, Float, F64 => try codegenBinaryOpFloatFloat(context, call, .Divsd, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenCall(context: Context, i: usize) !void {
    const call = context.ir_block.calls.items[context.ir_block.indices.items[i]];
    switch (context.overload.entities.names.get(call.function_entity).?) {
        @enumToInt(Strings.Add) => try codegenBinaryOp(context, call, AddOps),
        @enumToInt(Strings.Subtract) => try codegenBinaryOp(context, call, SubOps),
        @enumToInt(Strings.Multiply) => try codegenBinaryOp(context, call, MulOps),
        @enumToInt(Strings.Divide) => try codegenDivide(context, call),
        @enumToInt(Strings.Print) => try codegenPrint(context, call),
        else => unreachable,
    }
}

fn main(x86: *X86, ir: Ir, interned_strings: *InternedStrings) !void {
    var arena = Arena.init(x86.arena.child_allocator);
    defer arena.deinit();
    var register_map = RegisterMap{
        .entity_to_register = Map(Entity, Register).init(&arena.allocator),
        .register_to_entity = .{null} ** data.x86.total_available_registers,
        .free_callee_saved_registers = data.x86.callee_saved_registers,
        .free_callee_saved_length = data.x86.callee_saved_registers.len,
        .free_caller_saved_registers = data.x86.caller_saved_registers,
        .free_caller_saved_length = data.x86.caller_saved_registers.len,
    };
    var sse_register_map = SseRegisterMap{
        .entity_to_register = Map(Entity, SseRegister).init(&arena.allocator),
        .register_to_entity = .{null} ** data.x86.sse_registers.len,
        .free_registers = data.x86.sse_registers,
        .length = data.x86.sse_registers.len,
    };
    const name = interned_strings.mapping.get("main").?;
    const index = ir.name_to_index.get(name).?;
    const declaration_kind = ir.kinds.items[index];
    assert(declaration_kind == DeclarationKind.Function);
    assert(name == ir.names.items[index]);
    const overloads = ir.functions.items[ir.indices.items[index]];
    assert(overloads.length == 1);
    const allocator = &x86.arena.allocator;
    const x86_block = (try x86.blocks.addOne()).ptr;
    x86_block.instructions = List(Instruction).init(allocator);
    x86_block.operand_kinds = List([]const Kind).init(allocator);
    x86_block.operands = List([]const usize).init(allocator);
    const overload = &overloads.items[0];
    const context = Context{
        .allocator = allocator,
        .overload = overload,
        .x86 = x86,
        .x86_block = x86_block,
        .ir_block = &overload.blocks.items[overload.body_block_index],
        .register_map = &register_map,
        .sse_register_map = &sse_register_map,
        .interned_strings = interned_strings,
    };
    for (context.ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Return => {
                const ret = context.ir_block.returns.items[context.ir_block.indices.items[i]];
                if (register_map.entity_to_register.get(ret)) |reg| {
                    if (reg != .Rdi) try opRegReg(context, .Mov, .Rdi, reg);
                } else if (overload.entities.values.get(ret)) |value| {
                    try opRegLiteral(context, .Mov, .Rdi, value);
                }
                const sys_exit = try intern(interned_strings, "0x02000001");
                try opRegLiteral(context, .Mov, .Rax, sys_exit);
                try opNoArgs(x86_block, .Syscall);
            },
            .Call => try codegenCall(context, i),
            .Branch => unreachable,
            .Phi => unreachable,
            .Jump => unreachable,
        }
    }
}

pub fn codegen(allocator: *Allocator, ir: Ir, interned_strings: *InternedStrings) !X86 {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    var x86 = X86{
        .arena = arena,
        .types = Map(Entity, Entity).init(&arena.allocator),
        .externs = Set(InternedString).init(&arena.allocator),
        .bytes = Set(InternedString).init(&arena.allocator),
        .quad_words = Set(InternedString).init(&arena.allocator),
        .blocks = List(X86Block).init(&arena.allocator),
    };
    try main(&x86, ir, interned_strings);
    return x86;
}

fn writeLabel(output: *List(u8), label: Label) !void {
    if (label == 0) {
        try output.insertSlice("_main");
    } else {
        try output.insertFormatted("label{}", .{label});
    }
}

fn writeInstruction(output: *List(u8), instruction: Instruction) !void {
    switch (instruction) {
        .Mov => try output.insertSlice("mov"),
        .Movsd => try output.insertSlice("movsd"),
        .Push => try output.insertSlice("push"),
        .Pop => try output.insertSlice("pop"),
        .Add => try output.insertSlice("add"),
        .Addsd => try output.insertSlice("addsd"),
        .Sub => try output.insertSlice("sub"),
        .Subsd => try output.insertSlice("subsd"),
        .Imul => try output.insertSlice("imul"),
        .Mulsd => try output.insertSlice("mulsd"),
        .Idiv => try output.insertSlice("idiv"),
        .Divsd => try output.insertSlice("divsd"),
        .Call => try output.insertSlice("call"),
        .Syscall => try output.insertSlice("syscall"),
        .Cqo => try output.insertSlice("cqo"),
        .Ret => try output.insertSlice("ret"),
    }
}

fn writeRegister(output: *List(u8), register: Register) !void {
    switch (register) {
        .Rax => try output.insertSlice("rax"),
        .Rbx => try output.insertSlice("rbx"),
        .Rcx => try output.insertSlice("rcx"),
        .Rdx => try output.insertSlice("rdx"),
        .Rbp => try output.insertSlice("rbp"),
        .Rsp => try output.insertSlice("rsp"),
        .Rsi => try output.insertSlice("rsi"),
        .Rdi => try output.insertSlice("rdi"),
        .R8 => try output.insertSlice("r8"),
        .R9 => try output.insertSlice("r9"),
        .R10 => try output.insertSlice("r10"),
        .R11 => try output.insertSlice("r11"),
        .R12 => try output.insertSlice("r12"),
        .R13 => try output.insertSlice("r13"),
        .R14 => try output.insertSlice("r14"),
        .R15 => try output.insertSlice("r15"),
    }
}

fn writeSseRegister(output: *List(u8), register: SseRegister) !void {
    switch (register) {
        .Xmm0 => try output.insertSlice("xmm0"),
        .Xmm1 => try output.insertSlice("xmm1"),
        .Xmm2 => try output.insertSlice("xmm2"),
        .Xmm3 => try output.insertSlice("xmm3"),
        .Xmm4 => try output.insertSlice("xmm4"),
        .Xmm5 => try output.insertSlice("xmm5"),
        .Xmm6 => try output.insertSlice("xmm6"),
        .Xmm7 => try output.insertSlice("xmm7"),
        .Xmm8 => try output.insertSlice("xmm8"),
        .Xmm9 => try output.insertSlice("xmm9"),
        .Xmm10 => try output.insertSlice("xmm10"),
        .Xmm11 => try output.insertSlice("xmm11"),
        .Xmm12 => try output.insertSlice("xmm12"),
        .Xmm13 => try output.insertSlice("xmm13"),
        .Xmm14 => try output.insertSlice("xmm14"),
        .Xmm15 => try output.insertSlice("xmm15"),
    }
}

pub fn x86String(allocator: *Allocator, x86: X86, interned_strings: InternedStrings) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    try output.insertSlice("    global _main\n");
    var extern_iterator = x86.externs.iterator();
    while (extern_iterator.next()) |entry| {
        try output.insertSlice("    extern ");
        try output.insertSlice(interned_strings.data.items[entry.key]);
        _ = try output.insert('\n');
    }
    if ((x86.bytes.count() + x86.quad_words.count()) > 0) {
        try output.insertSlice("\n    section .data\n\n");
    }
    var byte_iterator = x86.bytes.iterator();
    while (byte_iterator.next()) |entry| {
        try output.insertFormatted("byte{}: db ", .{entry.key});
        try output.insertSlice(interned_strings.data.items[entry.key]);
        _ = try output.insert('\n');
    }
    var quad_word_iterator = x86.quad_words.iterator();
    while (quad_word_iterator.next()) |entry| {
        try output.insertFormatted("quad_word{}: dq ", .{entry.key});
        try output.insertSlice(interned_strings.data.items[entry.key]);
        _ = try output.insert('\n');
    }
    try output.insertSlice(
        \\
        \\    section .text
    );
    for (x86.blocks.slice()) |block, label| {
        _ = try output.insertSlice("\n\n");
        try writeLabel(&output, label);
        try output.insertSlice(":");
        for (block.instructions.slice()) |instruction, j| {
            try output.insertSlice("\n    ");
            try writeInstruction(&output, instruction);
            for (block.operand_kinds.items[j]) |operand_kind, k| {
                const operands = block.operands.items[j];
                if (k > 0) {
                    _ = try output.insertSlice(", ");
                } else {
                    _ = try output.insert(' ');
                }
                switch (operand_kind) {
                    .Immediate => try output.insertFormatted("{}", .{operands[k]}),
                    .Register => try writeRegister(&output, @intToEnum(Register, operands[k])),
                    .SseRegister => try writeSseRegister(&output, @intToEnum(SseRegister, operands[k])),
                    .Label => try writeLabel(&output, operands[k]),
                    .Literal => try output.insertSlice(interned_strings.data.items[operands[k]]),
                    .Byte => try output.insertFormatted("byte{}", .{operands[k]}),
                    .QuadWord => try output.insertFormatted("quad_word{}", .{operands[k]}),
                    .RelativeQuadWord => try output.insertFormatted("[rel quad_word{}]", .{operands[k]}),
                }
            }
        }
    }
    return output;
}
