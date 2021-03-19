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
const Memory = data.x86.Memory;
const Storage = data.x86.Storage;
const initMemory = data.x86.initMemory;
const Register = data.x86.Register;
const Registers = data.x86.Registers;
const RegisterStack = data.x86.RegisterStack;
const register_kind = data.x86.register_kind;
const Kind = data.x86.Kind;
const A = data.x86.A;
const C = data.x86.C;
const D = data.x86.D;
const B = data.x86.B;
const SP = data.x86.SP;
const BP = data.x86.BP;
const SI = data.x86.SI;
const DI = data.x86.DI;
const List = data.List;
const Map = data.Map;
const Set = data.Set;
const Label = usize;
const Immediate = usize;
const Int = @enumToInt(Builtins.Int);
const I64 = @enumToInt(Builtins.I64);
const Float = @enumToInt(Builtins.Float);
const F64 = @enumToInt(Builtins.F64);

fn pushFreeRegister(comptime n: Register, register_stack: *RegisterStack(n), register: Register) void {
    assert(register_stack.head > 0);
    register_stack.head -= 1;
    register_stack.data[register_stack.head] = register;
}

fn popFreeRegister(comptime n: Register, register_stack: *RegisterStack(n)) ?Register {
    if (register_stack.head == n) return null;
    const head = register_stack.head;
    register_stack.head += 1;
    return register_stack.data[head];
}

const Context = struct {
    allocator: *Allocator,
    overload: *const Overload,
    x86: *X86,
    x86_block: *X86Block,
    ir_block: *const IrBlock,
    memory: *Memory,
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
    operands[0] = to;
    operands[1] = from;
    _ = try context.x86_block.operands.insert(operands);
}

fn opSseRegSseReg(context: Context, op: Instruction, to: SseRegisterBackup, from: SseRegisterBackup) !void {
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
    operands[0] = to;
    operands[1] = lit;
    _ = try context.x86_block.operands.insert(operands);
}

fn opRegByte(context: Context, op: Instruction, to: RegisterBackup, byte: usize) !void {
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

fn opRegQuadWordPtr(context: Context, register: Register, offset: usize) !void {
    _ = try context.x86_block.instructions.insert(.Mov);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .QuadWordPtr;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = register;
    operands[1] = offset;
    _ = try context.x86_block.operands.insert(operands);
}

fn opSseRegRelQuadWord(context: Context, op: Instruction, to: SseRegisterBackup, quad_word: usize) !void {
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
    operands[0] = reg;
    _ = try context.x86_block.operands.insert(operands);
}

fn opNoArgs(x86_block: *X86Block, op: Instruction) !void {
    _ = try x86_block.instructions.insert(op);
    _ = try x86_block.operand_kinds.insert(&.{});
    _ = try x86_block.operands.insert(&.{});
}

fn ensureRegisterPreserved(context: Context, register: Register) !void {
    if (context.memory.preserved[register]) |_| return;
    try opReg(context, .Push, register);
    context.memory.stack += 8;
    context.memory.preserved[register] = context.memory.stack;
}

fn restorePreservedRegisters(context: Context) !void {
    for ([_]Register{ B, 12, 13, 14, 15 }) |register| {
        if (context.memory.preserved[register]) |offset| {
            try opRegQuadWordPtr(context, register, offset);
            context.memory.preserved[register] = null;
        }
    }
}

fn freeUpRegister(context: Context, registers: *Registers) !Register {
    if (popFreeRegister(registers.volatle.data.len, &registers.volatle)) |r| return r;
    if (popFreeRegister(registers.stable.data.len, &registers.stable)) |r| {
        try ensureRegisterPreserved(context, r);
        return r;
    }
    unreachable;
}

fn freeUpSpecificRegister(context: Context, registers: *Registers, register: Register) !void {
    if (registers.stored_entity[register]) |stored_entity| {
        const free_register = try freeUpRegister(context, registers);
        try context.memory.storage_for_entity.put(stored_entity, Storage{ .kind = .Register, .value = free_register });
        registers.stored_entity[free_register] = stored_entity;
        try opRegReg(context, .Mov, free_register, register);
    }
}

fn returnRegisterForUse(context: Context, registers: *Registers, register: Register) void {
    switch (register_kind[register]) {
        .Volatle => pushFreeRegister(registers.volatle.data.len, &registers.volatle, register),
        .Stable => pushFreeRegister(registers.stable.data.len, &registers.stable, register),
    }
    const entity = registers.stored_entity[register].?;
    registers.stored_entity[register] = null;
    context.memory.storage_for_entity.removeAssertDiscard(entity);
}

fn moveEntityToRegister(context: Context, registers: *Registers, entity: Entity) !Register {
    if (context.memory.storage_for_entity.get(entity)) |storage| {
        assert(storage.kind == .Register);
        return @intCast(Register, storage.value);
    }
    const value = context.overload.entities.values.get(entity).?;
    const register = try freeUpRegister(context, registers);
    try opRegLiteral(context, .Mov, register, value);
    try context.memory.storage_for_entity.put(entity, Storage{ .kind = .Register, .value = register });
    registers.stored_entity[register] = entity;
    return register;
}

fn removeRegisterFromRegisterStack(comptime n: Register, register_stack: *RegisterStack(n), register: Register) void {
    assert(register_stack.head < register_stack.data.len);
    for (register_stack.data[register_stack.head..]) |r, i| {
        if (r == register) {
            register_stack.data[i] = register_stack.data[register_stack.data.len - 1];
            register_stack.data[register_stack.data.len - 1] = register;
            break;
        }
    }
}

fn removeRegisterFromFreeList(registers: *Registers, register: Register) void {
    switch (register_kind[register]) {
        .Volatle => removeRegisterFromRegisterStack(registers.volatle.data.len, &registers.volatle, register),
        .Stable => removeRegisterFromRegisterStack(registers.stable.data.len, &registers.stable, register),
    }
}

fn moveEntityToSpecificRegister(context: Context, registers: *Registers, entity: Entity, register: Register) !void {
    // ensure there is no entity currently in the desired register
    if (registers.stored_entity[register]) |stored_entity| {
        if (stored_entity == entity) return;
        const free_register = try freeUpRegister(context, registers);
        try context.memory.storage_for_entity.put(stored_entity, Storage{ .kind = .Register, .value = free_register });
        registers.stored_entity[free_register] = stored_entity;
        try opRegReg(context, .Mov, free_register, register);
    } else {
        removeRegisterFromFreeList(registers, register);
    }
    // move the entity from it's current storage into the desired register
    if (context.memory.storage_for_entity.get(entity)) |storage| {
        assert(storage.kind == .Register);
        try context.memory.storage_for_entity.put(entity, Storage{ .kind = .Register, .value = register });
        returnRegisterForUse(context, registers, @intCast(Register, storage.value));
        registers.stored_entity[register] = entity;
        try opRegReg(context, .Mov, register, @intCast(Register, storage.value));
        return;
    }
    // entity has no current storage, it better have a value
    const value = context.overload.entities.values.get(entity).?;
    try context.memory.storage_for_entity.put(entity, Storage{ .kind = .Register, .value = register });
    registers.stored_entity[register] = entity;
    try opRegLiteral(context, .Mov, register, value);
}

fn preserveCallerSaveRegisters(context: Context) !void {
    for (data.x86.caller_saved_registers) |register| {
        if (context.register_map.register_to_entity[@enumToInt(register)]) |entity| {
            if (context.register_map.free_callee_saved_length > 0) {
                const index = context.register_map.free_callee_saved_registers.len - context.register_map.free_callee_saved_length;
                const free_register = context.register_map.free_callee_saved_registers[index];
                context.register_map.free_callee_saved_length -= 1;
                try opRegReg(context, .Mov, free_register, register);
                try context.register_map.entity_to_register.put(entity, free_register);
                context.register_map.register_to_entity[@enumToInt(free_register)] = entity;
                context.register_map.register_to_entity[@enumToInt(register)] = null;
            } else {
                try opReg(context, .Push, register);
                context.register_map.register_to_entity[@enumToInt(register)] = null;
                context.register_map.entity_to_register.removeAssertDiscard(entity);
            }
        }
    }
}

fn codegenPrintI64(context: Context, call: Call) !void {
    const eight = try intern(context.interned_strings, "8");
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try preserveCallerSaveRegisters(context);
    try moveEntityToSpecificRegister(context, call.argument_entities[0], .Rsi);
    const format_string = try intern(context.interned_strings, "\"%ld\", 10, 0");
    try context.x86.bytes.insert(format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    const printf = try intern(context.interned_strings, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try opRegLiteral(context, .Add, .Rsp, eight);
    try context.register_map.entity_to_register.put(call.result_entity, .Rax);
    context.register_map.register_to_entity[@enumToInt(RegisterBackup.Rax)] = call.result_entity;
}

fn codegenPrintF64(context: Context, call: Call) !void {
    const eight = try intern(context.interned_strings, "8");
    try opRegLiteral(context, .Sub, .Rsp, eight);
    const argument = call.argument_entities[0];
    try preserveCallerSaveRegisters(context);
    try preserveCallerSaveSseRegisters(context);
    try moveEntityToSpecificSseRegister(context, call.argument_entities[0], .Xmm0);
    const format_string = try intern(context.interned_strings, "\"%f\", 10, 0");
    try context.x86.bytes.insert(format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    const printf = try intern(context.interned_strings, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try opRegLiteral(context, .Add, .Rsp, eight);
    try context.register_map.entity_to_register.put(call.result_entity, .Rax);
    context.register_map.register_to_entity[@enumToInt(RegisterBackup.Rax)] = call.result_entity;
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
    const result_register = try moveEntityToRegister(context, &context.memory.registers, lhs);
    const rhs_register = try moveEntityToRegister(context, &context.memory.registers, rhs);
    const lhs_register = try freeUpRegister(context, &context.memory.registers);
    try opRegReg(context, .Mov, lhs_register, result_register);
    try opRegReg(context, op, result_register, rhs_register);
    try context.memory.storage_for_entity.put(lhs, Storage{
        .kind = .Register,
        .value = lhs_register,
    });
    try context.memory.storage_for_entity.put(call.result_entity, Storage{
        .kind = .Register,
        .value = result_register,
    });
    context.memory.registers.stored_entity[lhs_register] = lhs;
    context.memory.registers.stored_entity[result_register] = call.result_entity;
    try context.x86.types.putNoClobber(call.result_entity, I64);
}

fn codegenBinaryOpFloatFloat(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    unreachable;
    // const lhs_register = try moveEntityToSseRegister(context, lhs);
    // const rhs_register = try moveEntityToSseRegister(context, rhs);
    // try opSseRegSseReg(context, op, lhs_register, rhs_register);
    // try context.sse_register_map.entity_to_register.put(call.result_entity, lhs_register);
    // context.sse_register_map.register_to_entity[@enumToInt(lhs_register)] = call.result_entity;
    // context.sse_register_map.entity_to_register.removeAssertDiscard(rhs);
    // try context.x86.types.putNoClobber(call.result_entity, F64);
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
    const result_register = A;
    try moveEntityToSpecificRegister(context, &context.memory.registers, lhs, result_register);
    var rhs_register = try moveEntityToRegister(context, &context.memory.registers, rhs);
    try freeUpSpecificRegister(context, &context.memory.registers, D);
    const lhs_register = try freeUpRegister(context, &context.memory.registers);
    try opRegReg(context, .Mov, lhs_register, result_register);
    try opNoArgs(context.x86_block, .Cqo);
    try opReg(context, .Idiv, rhs_register);
    try context.memory.storage_for_entity.put(lhs, Storage{
        .kind = .Register,
        .value = lhs_register,
    });
    try context.memory.storage_for_entity.put(call.result_entity, Storage{
        .kind = .Register,
        .value = result_register,
    });
    context.memory.registers.stored_entity[lhs_register] = lhs;
    context.memory.registers.stored_entity[result_register] = call.result_entity;
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
        // @enumToInt(Strings.Print) => try codegenPrint(context, call),
        else => unreachable,
    }
}

fn resetStack(context: Context) !void {
    const buffer = try std.fmt.allocPrint(context.allocator, "{}", .{context.memory.stack});
    const interned = try intern(context.interned_strings, buffer);
    try opRegLiteral(context, .Add, SP, interned);
}

fn main(x86: *X86, ir: Ir, interned_strings: *InternedStrings) !void {
    var arena = Arena.init(x86.arena.child_allocator);
    defer arena.deinit();
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
    var memory = initMemory(allocator);
    const context = Context{
        .allocator = allocator,
        .overload = overload,
        .x86 = x86,
        .x86_block = x86_block,
        .ir_block = &overload.blocks.items[overload.body_block_index],
        .memory = &memory,
        .interned_strings = interned_strings,
    };
    for (context.ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Return => {
                const ret = context.ir_block.returns.items[context.ir_block.indices.items[i]];
                if (memory.storage_for_entity.get(ret)) |storage| {
                    assert(storage.kind == .Register);
                    if (storage.value != DI)
                        try opRegReg(context, .Mov, DI, @intCast(Register, storage.value));
                } else if (overload.entities.values.get(ret)) |value| {
                    try opRegLiteral(context, .Mov, DI, value);
                }
                try restorePreservedRegisters(context);
                try resetStack(context);
                const sys_exit = try intern(interned_strings, "0x02000001");
                try opRegLiteral(context, .Mov, A, sys_exit);
                try opNoArgs(x86_block, .Syscall);
            },
            .Call => try codegenCall(context, i),
            else => unreachable,
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

fn writeRegister(output: *List(u8), register: usize) !void {
    switch (register) {
        A => try output.insertSlice("rax"),
        C => try output.insertSlice("rcx"),
        D => try output.insertSlice("rdx"),
        B => try output.insertSlice("rbx"),
        BP => try output.insertSlice("rbp"),
        SP => try output.insertSlice("rsp"),
        SI => try output.insertSlice("rsi"),
        DI => try output.insertSlice("rdi"),
        8 => try output.insertSlice("r8"),
        9 => try output.insertSlice("r9"),
        10 => try output.insertSlice("r10"),
        11 => try output.insertSlice("r11"),
        12 => try output.insertSlice("r12"),
        13 => try output.insertSlice("r13"),
        14 => try output.insertSlice("r14"),
        15 => try output.insertSlice("r15"),
        else => unreachable,
    }
}

fn writeSseRegister(output: *List(u8), register: SseRegisterBackup) !void {
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
                    .Register => try writeRegister(&output, operands[k]),
                    .SseRegister => unreachable,
                    .Label => try writeLabel(&output, operands[k]),
                    .Literal => try output.insertSlice(interned_strings.data.items[operands[k]]),
                    .Byte => try output.insertFormatted("byte{}", .{operands[k]}),
                    .QuadWord => try output.insertFormatted("quad_word{}", .{operands[k]}),
                    .RelativeQuadWord => try output.insertFormatted("[rel quad_word{}]", .{operands[k]}),
                    .QuadWordPtr => try output.insertFormatted("qword [rbp-{}]", .{operands[k]}),
                }
            }
        }
    }
    return output;
}
