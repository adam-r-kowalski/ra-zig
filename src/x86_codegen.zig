const std = @import("std");
const assert = std.debug.assert;
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const data = @import("data.zig");
const InternedStrings = data.interned_strings.InternedStrings;
const InternedString = data.interned_strings.InternedString;
const internString = data.interned_strings.internString;
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
const Stack = data.x86.Stack;
const Register = data.x86.Register;
const SseRegister = data.x86.SseRegister;
const Kind = data.x86.Kind;
const List = data.List;
const Map = data.Map;
const Set = data.Set;
const Label = usize;
const Immediate = usize;
const Int = @enumToInt(Builtins.Int);
const I64 = @enumToInt(Builtins.I64);
const Float = @enumToInt(Builtins.Float);
const F64 = @enumToInt(Builtins.F64);

const InternedInt = usize;
const InternedInts = Map(usize, InternedString);

// fn pushFreeRegister(comptime n: Register, register_stack: *RegisterStack(n), register: Register) void {
//     assert(register_stack.head > 0);
//     register_stack.head -= 1;
//     register_stack.data[register_stack.head] = register;
// }

// fn popFreeRegister(comptime n: Register, register_stack: *RegisterStack(n)) ?Register {
//     if (register_stack.head == n) return null;
//     const head = register_stack.head;
//     register_stack.head += 1;
//     return register_stack.data[head];
// }

const Context = struct {
    allocator: *Allocator,
    overload: *const Overload,
    x86: *X86,
    x86_block: *X86Block,
    ir_block: *const IrBlock,
    stack: *Stack,
    interned_strings: *InternedStrings,
    interned_ints: *InternedInts,
};

fn internInt(context: Context, value: usize) !InternedInt {
    if (context.interned_ints.get(value)) |interned| {
        return interned;
    }
    const buffer = try std.fmt.allocPrint(context.allocator, "{}", .{value});
    const interned = try internString(context.interned_strings, buffer);
    try context.interned_ints.putNoClobber(value, interned);
    return interned;
}

// fn opLiteral(context: Context, op: Instruction, lit: InternedString) !void {
//     _ = try context.x86_block.instructions.insert(op);
//     const operand_kinds = try context.allocator.alloc(Kind, 1);
//     operand_kinds[0] = .Literal;
//     _ = try context.x86_block.operand_kinds.insert(operand_kinds);
//     const operands = try context.allocator.alloc(usize, 1);
//     operands[0] = lit;
//     _ = try context.x86_block.operands.insert(operands);
// }

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

fn opStackLiteral(context: Context, op: Instruction, offset: usize, literal: InternedString) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .StackOffset;
    operand_kinds[1] = .Literal;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = offset;
    operands[1] = literal;
    _ = try context.x86_block.operands.insert(operands);
}

fn opRegStack(context: Context, op: Instruction, reg: Register, offset: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .StackOffset;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(reg);
    operands[1] = offset;
    _ = try context.x86_block.operands.insert(operands);
}

fn opSseRegStack(context: Context, op: Instruction, reg: SseRegister, offset: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .SseRegister;
    operand_kinds[1] = .StackOffset;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(reg);
    operands[1] = offset;
    _ = try context.x86_block.operands.insert(operands);
}

fn opStackReg(context: Context, op: Instruction, offset: usize, reg: Register) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .StackOffset;
    operand_kinds[1] = .Register;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = offset;
    operands[1] = @enumToInt(reg);
    _ = try context.x86_block.operands.insert(operands);
}

fn opStackSseReg(context: Context, op: Instruction, offset: usize, reg: SseRegister) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .StackOffset;
    operand_kinds[1] = .SseRegister;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = offset;
    operands[1] = @enumToInt(reg);
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

fn opNoArgs(x86_block: *X86Block, op: Instruction) !void {
    _ = try x86_block.instructions.insert(op);
    _ = try x86_block.operand_kinds.insert(&.{});
    _ = try x86_block.operands.insert(&.{});
}

// fn opRegByte(context: Context, op: Instruction, to: Register, byte: usize) !void {
//     _ = try context.x86_block.instructions.insert(op);
//     const operand_kinds = try context.allocator.alloc(Kind, 2);
//     operand_kinds[0] = .Register;
//     operand_kinds[1] = .Byte;
//     _ = try context.x86_block.operand_kinds.insert(operand_kinds);
//     const operands = try context.allocator.alloc(usize, 2);
//     operands[0] = to;
//     operands[1] = byte;
//     _ = try context.x86_block.operands.insert(operands);
// }

// fn opSseRegSseReg(context: Context, op: Instruction, to: Register, from: Register) !void {
//     _ = try context.x86_block.instructions.insert(op);
//     const operand_kinds = try context.allocator.alloc(Kind, 2);
//     operand_kinds[0] = .SseRegister;
//     operand_kinds[1] = .SseRegister;
//     _ = try context.x86_block.operand_kinds.insert(operand_kinds);
//     const operands = try context.allocator.alloc(usize, 2);
//     operands[0] = to;
//     operands[1] = from;
//     _ = try context.x86_block.operands.insert(operands);
// }

// fn opRegQuadWordPtr(context: Context, op: Instruction, register: Register, offset: usize) !void {
//     _ = try context.x86_block.instructions.insert(op);
//     const operand_kinds = try context.allocator.alloc(Kind, 2);
//     operand_kinds[0] = .Register;
//     operand_kinds[1] = .QuadWordPtr;
//     _ = try context.x86_block.operand_kinds.insert(operand_kinds);
//     const operands = try context.allocator.alloc(usize, 2);
//     operands[0] = register;
//     operands[1] = offset;
//     _ = try context.x86_block.operands.insert(operands);
// }

// fn opSseRegQuadWordPtr(context: Context, op: Instruction, register: Register, offset: usize) !void {
//     _ = try context.x86_block.instructions.insert(op);
//     const operand_kinds = try context.allocator.alloc(Kind, 2);
//     operand_kinds[0] = .SseRegister;
//     operand_kinds[1] = .QuadWordPtr;
//     _ = try context.x86_block.operand_kinds.insert(operand_kinds);
//     const operands = try context.allocator.alloc(usize, 2);
//     operands[0] = register;
//     operands[1] = offset;
//     _ = try context.x86_block.operands.insert(operands);
// }
// fn opQuadWordPtrSseReg(context: Context, op: Instruction, offset: usize, register: Register) !void {
//     _ = try context.x86_block.instructions.insert(op);
//     const operand_kinds = try context.allocator.alloc(Kind, 2);
//     operand_kinds[0] = .QuadWordPtr;
//     operand_kinds[1] = .SseRegister;
//     _ = try context.x86_block.operand_kinds.insert(operand_kinds);
//     const operands = try context.allocator.alloc(usize, 2);
//     operands[0] = offset;
//     operands[1] = register;
//     _ = try context.x86_block.operands.insert(operands);
// }

// fn opSseReg(context: Context, op: Instruction, reg: Register) !void {
//     _ = try context.x86_block.instructions.insert(op);
//     const operand_kinds = try context.allocator.alloc(Kind, 1);
//     operand_kinds[0] = .SseRegister;
//     _ = try context.x86_block.operand_kinds.insert(operand_kinds);
//     const operands = try context.allocator.alloc(usize, 1);
//     operands[0] = reg;
//     _ = try context.x86_block.operands.insert(operands);
// }

// fn ensureRegisterPreserved(context: Context, register: Register) !void {
//     if (context.memory.preserved[register]) |_| return;
//     try opReg(context, .Push, register);
//     context.memory.stack += 8;
//     context.memory.preserved[register] = context.memory.stack;
// }

// fn ensureSseRegisterPreserved(context: Context, register: Register) !void {
//     if (context.memory.sse_preserved[register]) |_| return;
//     const eight = try intern(context.interned_strings, "8");
//     context.memory.stack += 8;
//     try opRegLiteral(context, .Sub, SP, eight);
//     try opQuadWordPtrSseReg(context, .Movsd, context.memory.stack, register);
//     context.memory.sse_preserved[register] = context.memory.stack;
// }

// fn restorePreservedRegisters(context: Context) !void {
//     for ([_]Register{ B, 12, 13, 14, 15 }) |register| {
//         if (context.memory.preserved[register]) |offset| {
//             try opRegQuadWordPtr(context, .Mov, register, offset);
//             context.memory.preserved[register] = null;
//         }
//     }
//     var register: u8 = 8;
//     while (register < 16) : (register += 1) {
//         if (context.memory.sse_preserved[register]) |offset| {
//             try opSseRegQuadWordPtr(context, .Movsd, register, offset);
//             context.memory.sse_preserved[register] = null;
//         }
//     }
// }

// fn freeUpRegister(context: Context) !Register {
//     const registers = &context.memory.registers;
//     if (popFreeRegister(registers.volatle.data.len, &registers.volatle)) |r| return r;
//     if (popFreeRegister(registers.stable.data.len, &registers.stable)) |r| {
//         try ensureRegisterPreserved(context, r);
//         return r;
//     }
//     unreachable;
// }

// fn freeUpSseRegister(context: Context) !Register {
//     const registers = &context.memory.sse_registers;
//     if (popFreeRegister(registers.volatle.data.len, &registers.volatle)) |r| return r;
//     unreachable;
// }

// fn freeUpSpecificRegister(context: Context, register: Register) !void {
//     const registers = &context.memory.registers;
//     if (registers.stored_entity[register]) |stored_entity| {
//         const free_register = try freeUpRegister(context);
//         try context.memory.storage_for_entity.put(stored_entity, Storage{ .kind = .Register, .value = free_register });
//         registers.stored_entity[free_register] = stored_entity;
//         try opRegReg(context, .Mov, free_register, register);
//     }
// }

// fn returnRegisterForUse(context: Context, register: Register) void {
//     const registers = &context.memory.registers;
//     switch (register_kind[register]) {
//         .Volatle => pushFreeRegister(registers.volatle.data.len, &registers.volatle, register),
//         .Stable => pushFreeRegister(registers.stable.data.len, &registers.stable, register),
//     }
//     const entity = registers.stored_entity[register].?;
//     registers.stored_entity[register] = null;
//     context.memory.storage_for_entity.removeAssertDiscard(entity);
// }

// fn moveEntityToRegister(context: Context, entity: Entity) !Register {
//     if (context.memory.storage_for_entity.get(entity)) |storage| {
//         switch (storage.kind) {
//             .Register => return @intCast(Register, storage.value),
//             .Stack => {
//                 const register = try freeUpRegister(context);
//                 try opRegQuadWordPtr(context, .Mov, register, storage.value);
//                 try context.memory.storage_for_entity.put(entity, Storage{ .kind = .Register, .value = register });
//                 context.memory.registers.stored_entity[register] = entity;
//                 return register;
//             },
//             else => unreachable,
//         }
//     }
//     const value = context.overload.entities.values.get(entity).?;
//     const register = try freeUpRegister(context);
//     try opRegLiteral(context, .Mov, register, value);
//     try context.memory.storage_for_entity.put(entity, Storage{ .kind = .Register, .value = register });
//     context.memory.registers.stored_entity[register] = entity;
//     return register;
// }

// fn moveEntityToSseRegister(context: Context, entity: Entity) !Register {
//     if (context.memory.storage_for_entity.get(entity)) |storage| {
//         assert(storage.kind == .SseRegister);
//         return @intCast(Register, storage.value);
//     }
//     const value = blk: {
//         if (context.overload.entities.kinds.get(entity).? == .Int) {
//             const index = context.overload.entities.values.get(entity).?;
//             const buffer = try std.fmt.allocPrint(context.allocator, "{s}.0", .{context.interned_strings.data.items[index]});
//             break :blk try intern(context.interned_strings, buffer);
//         } else {
//             break :blk context.overload.entities.values.get(entity).?;
//         }
//     };
//     const register = try freeUpSseRegister(context);
//     try context.x86.quad_words.insert(value);
//     try opSseRegRelQuadWord(context, .Movsd, register, value);
//     try context.memory.storage_for_entity.put(entity, Storage{ .kind = .SseRegister, .value = register });
//     context.memory.sse_registers.stored_entity[register] = entity;
//     return register;
// }

// fn removeRegisterFromRegisterStack(comptime n: Register, register_stack: *RegisterStack(n), register: Register) void {
//     assert(register_stack.head < register_stack.data.len);
//     for (register_stack.data[register_stack.head..]) |r, i| {
//         if (r == register) {
//             register_stack.data[i] = register_stack.data[register_stack.data.len - 1];
//             register_stack.data[register_stack.data.len - 1] = register;
//             break;
//         }
//     }
// }

// fn moveEntityToSpecificRegister(context: Context, entity: Entity, register: Register) !void {
//     const registers = &context.memory.registers;
//     // ensure there is no entity currently in the desired register
//     if (registers.stored_entity[register]) |stored_entity| {
//         if (stored_entity == entity) return;
//         const free_register = try freeUpRegister(context);
//         try context.memory.storage_for_entity.put(stored_entity, Storage{ .kind = .Register, .value = free_register });
//         registers.stored_entity[free_register] = stored_entity;
//         try opRegReg(context, .Mov, free_register, register);
//     } else {
//         switch (register_kind[register]) {
//             .Volatle => removeRegisterFromRegisterStack(registers.volatle.data.len, &registers.volatle, register),
//             .Stable => removeRegisterFromRegisterStack(registers.stable.data.len, &registers.stable, register),
//         }
//     }
//     // move the entity from it's current storage into the desired register
//     if (context.memory.storage_for_entity.get(entity)) |storage| {
//         assert(storage.kind == .Register);
//         try context.memory.storage_for_entity.put(entity, Storage{ .kind = .Register, .value = register });
//         returnRegisterForUse(context, @intCast(Register, storage.value));
//         registers.stored_entity[register] = entity;
//         try opRegReg(context, .Mov, register, @intCast(Register, storage.value));
//         return;
//     }
//     // entity has no current storage, it better have a value
//     const value = context.overload.entities.values.get(entity).?;
//     try context.memory.storage_for_entity.put(entity, Storage{ .kind = .Register, .value = register });
//     registers.stored_entity[register] = entity;
//     try opRegLiteral(context, .Mov, register, value);
// }

// fn preserveVolatleRegisters(context: Context) !void {
//     const registers = &context.memory.registers;
//     for (registers.volatle.data[0..registers.volatle.head]) |volatle_register| {
//         const volatle_entity = registers.stored_entity[volatle_register].?;
//         const stable_register = blk: {
//             if (popFreeRegister(registers.stable.data.len, &registers.stable)) |stable_register| {
//                 try ensureRegisterPreserved(context, stable_register);
//                 break :blk stable_register;
//             } else {
//                 const stable_register = registers.stable.data[0];
//                 try opReg(context, .Push, stable_register);
//                 context.memory.stack += 8;
//                 const stable_entity = registers.stored_entity[stable_register].?;
//                 try context.memory.storage_for_entity.put(stable_entity, Storage{ .kind = .Stack, .value = context.memory.stack });
//                 break :blk stable_register;
//             }
//         };
//         try context.memory.storage_for_entity.put(volatle_entity, Storage{ .kind = .Register, .value = stable_register });
//         registers.stored_entity[stable_register] = volatle_entity;
//         try opRegReg(context, .Mov, stable_register, volatle_register);
//         registers.stored_entity[volatle_register] = null;
//     }
//     registers.volatle.head = 0;

//     const sse_registers = &context.memory.sse_registers;
//     for (sse_registers.volatle.data[0..sse_registers.volatle.head]) |volatle_register| {
//         const volatle_entity = sse_registers.stored_entity[volatle_register].?;
//         const stable_register = blk: {
//             if (popFreeRegister(sse_registers.stable.data.len, &sse_registers.stable)) |stable_register| {
//                 try ensureSseRegisterPreserved(context, stable_register);
//                 break :blk stable_register;
//             } else {
//                 const stable_register = sse_registers.stable.data[0];
//                 const eight = try intern(context.interned_strings, "8");
//                 context.memory.stack += 8;
//                 try opRegLiteral(context, .Sub, SP, eight);
//                 try opQuadWordPtrSseReg(context, .Movsd, context.memory.stack, stable_register);
//                 const stable_entity = sse_registers.stored_entity[stable_register].?;
//                 try context.memory.storage_for_entity.put(stable_entity, Storage{ .kind = .Stack, .value = context.memory.stack });
//                 break :blk stable_register;
//             }
//         };
//         try context.memory.storage_for_entity.put(volatle_entity, Storage{ .kind = .SseRegister, .value = stable_register });
//         sse_registers.stored_entity[stable_register] = volatle_entity;
//         try opSseRegSseReg(context, .Movsd, stable_register, volatle_register);
//         sse_registers.stored_entity[volatle_register] = null;
//     }
//     sse_registers.volatle.head = 0;
// }

// const Offset = struct {
//     value: usize,
//     interned: InternedString,
// };

// fn alignStackTo16Bytes(context: Context) !Offset {
//     const value = (context.memory.stack + 8) % 16;
//     const buffer = try std.fmt.allocPrint(context.allocator, "{}", .{value});
//     const interned = try intern(context.interned_strings, buffer);
//     if (value > 0) {
//         try opRegLiteral(context, .Sub, SP, interned);
//         context.memory.stack += 8;
//     }
//     return Offset{ .value = value, .interned = interned };
// }

// fn codegenPrintI64(context: Context, call: Call) !void {
//     try preserveVolatleRegisters(context);
//     const entity = call.argument_entities[0];
//     if (context.memory.storage_for_entity.get(entity)) |storage| {
//         switch (storage.kind) {
//             .Register => try opRegReg(context, .Mov, SI, @intCast(Register, storage.value)),
//             .Stack => try opRegQuadWordPtr(context, .Mov, SI, storage.value),
//             else => unreachable,
//         }
//     } else {
//         const value = context.overload.entities.values.get(entity).?;
//         try opRegLiteral(context, .Mov, SI, value);
//     }
//     const format_string = try intern(context.interned_strings, "\"%ld\", 10, 0");
//     try context.x86.bytes.insert(format_string);
//     try opRegByte(context, .Mov, DI, format_string);
//     try opRegReg(context, .Xor, A, A);
//     const offset = try alignStackTo16Bytes(context);
//     const printf = try intern(context.interned_strings, "_printf");
//     try context.x86.externs.insert(printf);
//     try opLiteral(context, .Call, printf);
//     try context.memory.storage_for_entity.put(call.result_entity, Storage{ .kind = .Register, .value = A });
//     context.memory.registers.stored_entity[A] = call.result_entity;
//     var i: usize = 0;
//     while (i < context.memory.registers.volatle.data.len) : (i += 1) {
//         if (context.memory.registers.volatle.data[i] == A) {
//             context.memory.registers.volatle.data[i] = context.memory.registers.volatle.data[0];
//             context.memory.registers.volatle.data[0] = @intCast(Register, A);
//             break;
//         }
//     }
//     context.memory.registers.volatle.head = 1;
//     if (offset.value > 0) {
//         try opRegLiteral(context, .Add, SP, offset.interned);
//         context.memory.stack -= offset.value;
//     }
// }

// fn codegenPrintF64(context: Context, call: Call) !void {
//     try preserveVolatleRegisters(context);
//     const entity = call.argument_entities[0];
//     if (context.memory.storage_for_entity.get(entity)) |storage| {
//         assert(storage.kind == .SseRegister);
//         try opSseRegSseReg(context, .Movsd, 0, @intCast(Register, storage.value));
//     } else {
//         const value = blk: {
//             if (context.overload.entities.kinds.get(entity).? == .Int) {
//                 const index = context.overload.entities.values.get(entity).?;
//                 const buffer = try std.fmt.allocPrint(context.allocator, "{s}.0", .{context.interned_strings.data.items[index]});
//                 break :blk try intern(context.interned_strings, buffer);
//             } else {
//                 break :blk context.overload.entities.values.get(entity).?;
//             }
//         };
//         try context.x86.quad_words.insert(value);
//         try opSseRegRelQuadWord(context, .Movsd, 0, value);
//     }
//     const format_string = try intern(context.interned_strings, "\"%f\", 10, 0");
//     try context.x86.bytes.insert(format_string);
//     try opRegByte(context, .Mov, DI, format_string);
//     const one = try intern(context.interned_strings, "1");
//     try opRegLiteral(context, .Mov, A, one);
//     const offset = try alignStackTo16Bytes(context);
//     const printf = try intern(context.interned_strings, "_printf");
//     try context.x86.externs.insert(printf);
//     try opLiteral(context, .Call, printf);
//     try context.memory.storage_for_entity.put(call.result_entity, Storage{ .kind = .Register, .value = A });
//     context.memory.registers.stored_entity[A] = call.result_entity;
//     var i: usize = 0;
//     while (i < context.memory.registers.volatle.data.len) : (i += 1) {
//         if (context.memory.registers.volatle.data[i] == A) {
//             context.memory.registers.volatle.data[i] = context.memory.registers.volatle.data[0];
//             context.memory.registers.volatle.data[0] = @intCast(Register, A);
//             break;
//         }
//     }
//     if (offset.value > 0) {
//         try opRegLiteral(context, .Add, SP, offset.interned);
//         context.memory.stack -= offset.value;
//     }
// }

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

// fn codegenPrint(context: Context, call: Call) !void {
//     assert(call.argument_entities.len == 1);
//     const argument = call.argument_entities[0];
//     switch (try typeOf(context, argument)) {
//         Int, I64 => try codegenPrintI64(context, call),
//         Float, F64 => try codegenPrintF64(context, call),
//         else => unreachable,
//     }
// }

const BinaryOps = struct {
    int: Instruction,
    float: Instruction,
};

const AddOps = BinaryOps{ .int = .Add, .float = .Addsd };
const SubOps = BinaryOps{ .int = .Sub, .float = .Subsd };
const MulOps = BinaryOps{ .int = .Imul, .float = .Mulsd };

fn entityStackOffset(context: Context, entity: Entity) !usize {
    if (context.stack.entity.get(entity)) |offset| {
        return offset;
    }
    if (context.overload.entities.values.get(entity)) |value| {
        context.stack.top += 8;
        const offset = context.stack.top;
        try context.stack.entity.putNoClobber(entity, offset);
        const eight = try internInt(context, 8);
        try opRegLiteral(context, .Sub, .Rsp, eight);
        try opStackLiteral(context, .Mov, offset, value);
        return offset;
    }
    unreachable;
}

fn sseEntityStackOffset(context: Context, entity: Entity) !usize {
    if (context.stack.entity.get(entity)) |offset| {
        return offset;
    }
    if (context.overload.entities.values.get(entity)) |value| {
        context.stack.top += 8;
        const offset = context.stack.top;
        try context.stack.entity.putNoClobber(entity, offset);
        const eight = try internInt(context, 8);
        try opRegLiteral(context, .Sub, .Rsp, eight);
        switch (context.overload.entities.kinds.get(entity).?) {
            .Int => {
                const interned = context.interned_strings.data.items[value];
                const buffer = try std.fmt.allocPrint(context.allocator, "{s}.0", .{interned});
                const quad_word = try internString(context.interned_strings, buffer);
                try context.x86.quad_words.insert(quad_word);
                try opSseRegRelQuadWord(context, .Movsd, .Xmm0, quad_word);
                try opStackSseReg(context, .Movsd, offset, .Xmm0);
            },
            .Float => {
                try context.x86.quad_words.insert(value);
                try opSseRegRelQuadWord(context, .Movsd, .Xmm0, value);
                try opStackSseReg(context, .Movsd, offset, .Xmm0);
            },
        }
        return offset;
    }
    unreachable;
}

fn codegenBinaryOpIntInt(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    const lhs_offset = try entityStackOffset(context, lhs);
    const rhs_offset = try entityStackOffset(context, rhs);
    try opRegStack(context, .Mov, .Rax, lhs_offset);
    try opRegStack(context, .Mov, .Rcx, rhs_offset);
    try opRegReg(context, op, .Rax, .Rcx);
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.x86.types.putNoClobber(call.result_entity, I64);
}

fn codegenBinaryOpFloatFloat(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    const lhs_offset = try sseEntityStackOffset(context, lhs);
    const rhs_offset = try sseEntityStackOffset(context, rhs);
    try opSseRegStack(context, .Movsd, .Xmm0, lhs_offset);
    try opSseRegStack(context, .Movsd, .Xmm1, rhs_offset);
    try opSseRegSseReg(context, op, .Xmm0, .Xmm1);
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackSseReg(context, .Movsd, offset, .Xmm0);
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
    const lhs_offset = try entityStackOffset(context, lhs);
    const rhs_offset = try entityStackOffset(context, rhs);
    try opRegStack(context, .Mov, .Rax, lhs_offset);
    try opRegStack(context, .Mov, .Rcx, rhs_offset);
    try opNoArgs(context.x86_block, .Cqo);
    try opReg(context, .Idiv, .Rcx);
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, offset, .Rax);
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
    const name = context.overload.entities.names.get(call.function_entity).?;
    switch (name) {
        @enumToInt(Strings.Add) => try codegenBinaryOp(context, call, AddOps),
        @enumToInt(Strings.Subtract) => try codegenBinaryOp(context, call, SubOps),
        @enumToInt(Strings.Multiply) => try codegenBinaryOp(context, call, MulOps),
        @enumToInt(Strings.Divide) => try codegenDivide(context, call),
        // @enumToInt(Strings.Print) => try codegenPrint(context, call),
        else => unreachable,
    }
}

// fn resetStack(context: Context) !void {
//     if (context.memory.stack == 0) return;
//     const buffer = try std.fmt.allocPrint(context.allocator, "{}", .{context.memory.stack});
//     const interned = try intern(context.interned_strings, buffer);
//     try opRegLiteral(context, .Add, SP, interned);
// }

fn codegenMain(x86: *X86, ir: Ir, interned_strings: *InternedStrings) !void {
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
    var stack = Stack{
        .entity = Map(Entity, usize).init(allocator),
        .top = 0,
    };
    var interned_ints = InternedInts.init(allocator);
    const context = Context{
        .allocator = allocator,
        .overload = overload,
        .x86 = x86,
        .x86_block = x86_block,
        .ir_block = &overload.blocks.items[overload.body_block_index],
        .stack = &stack,
        .interned_strings = interned_strings,
        .interned_ints = &interned_ints,
    };
    try opRegReg(context, .Mov, .Rbp, .Rsp);
    for (context.ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Return => {
                const ret = context.ir_block.returns.items[context.ir_block.indices.items[i]];
                if (stack.entity.get(ret)) |offset| {
                    try opRegStack(context, .Mov, .Rdi, offset);
                } else if (overload.entities.values.get(ret)) |value| {
                    try opRegLiteral(context, .Mov, .Rdi, value);
                }
                // try restorePreservedRegisters(context);
                // try resetStack(context);
                const sys_exit = try internString(interned_strings, "0x02000001");
                try opRegLiteral(context, .Mov, .Rax, sys_exit);
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
    try codegenMain(&x86, ir, interned_strings);
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
        .Xor => try output.insertSlice("xor"),
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
                    .StackOffset => try output.insertFormatted("qword [rbp-{}]", .{operands[k]}),
                }
            }
        }
    }
    return output;
}
