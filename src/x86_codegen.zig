const std = @import("std");
const assert = std.debug.assert;
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const data = @import("data.zig");
const InternedStrings = data.entity.InternedStrings;
const InternedString = data.entity.InternedString;
const internString = data.entity.internString;
const Entity = data.entity.Entity;
const Entities = data.entity.Entities;
const Builtins = data.entity.Builtins;
const DeclarationKind = data.ir.DeclarationKind;
const IrBlock = data.ir.Block;
const Ir = data.ir.Ir;
const Overload = data.ir.Overload;
const Call = data.ir.Call;
const X86 = data.x86.X86;
const X86Block = data.x86.Block;
const Instruction = data.x86.Instruction;
const Stack = data.x86.Stack;
const Register = data.x86.Register;
const SseRegister = data.x86.SseRegister;
const Kind = data.x86.Kind;
const BlockIndex = data.x86.BlockIndex;
const UniqueIds = data.x86.UniqueIds;
const List = data.List;
const Map = data.Map;
const Set = data.Set;
const Label = usize;
const Immediate = usize;
const Int = @enumToInt(Builtins.Int);
const I64 = @enumToInt(Builtins.I64);
const I32 = @enumToInt(Builtins.I32);
const U8 = @enumToInt(Builtins.U8);
const Float = @enumToInt(Builtins.Float);
const F64 = @enumToInt(Builtins.F64);
const Array = @enumToInt(Builtins.Array);
const Ptr = @enumToInt(Builtins.Ptr);
const Void = @enumToInt(Builtins.Void);
const Type = @enumToInt(Builtins.Type);

const InternedInts = Map(usize, InternedString);

const Context = struct {
    allocator: *Allocator,
    overload: *const Overload,
    x86: *X86,
    x86_block: *X86Block,
    ir: *const Ir,
    ir_block: *const IrBlock,
    stack: *Stack,
    entities: *Entities,
    interned_ints: *InternedInts,
};

fn internInt(context: Context, value: usize) !InternedString {
    if (context.interned_ints.get(value)) |interned| {
        return interned;
    }
    const buffer = try std.fmt.allocPrint(context.allocator, "{}", .{value});
    const interned = try internString(context.entities, buffer);
    try context.interned_ints.putNoClobber(value, interned);
    return interned;
}

fn initUniqueIds(allocator: *Allocator) UniqueIds {
    return UniqueIds{
        .string_to_index = Map(InternedString, usize).init(allocator),
        .index_to_string = List(InternedString).init(allocator),
        .next_index = 0,
    };
}

fn insertUniqueId(ids: *UniqueIds, interned_string: InternedString) !void {
    const result = try ids.string_to_index.getOrPut(interned_string);
    if (result.found_existing) return;
    result.entry.value = ids.next_index;
    _ = try ids.index_to_string.insert(interned_string);
    ids.next_index += 1;
}

const RegisterSize = enum(u8) { Qword, Dword, Byte };

fn registerSize(reg: Register) RegisterSize {
    return switch (reg) {
        .Rax, .Rbx, .Rcx, .Rdx, .Rsp, .Rbp, .Rsi, .Rdi, .R8, .R9, .R10, .R11, .R12, .R13, .R14, .R15 => .Qword,
        .Eax, .Ebx, .Ecx, .Edx, .Esp, .Ebp, .Esi, .Edi, .R8d, .R9d, .R10d, .R11d, .R12d, .R13d, .R14d, .R15d => .Dword,
        .Al, .Ah, .Bl, .Bh, .Cl, .Ch, .Dl, .Dh, .Spl, .Bpl, .Sil, .Dil, .R8b, .R9b, .R10b, .R11b, .R12b, .R13b, .R14b, .R15b => .Byte,
    };
}

fn opLiteral(context: Context, op: Instruction, lit: InternedString) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 1);
    operand_kinds[0] = .Literal;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 1);
    operands[0] = lit;
    _ = try context.x86_block.operands.insert(operands);
}

fn opLabel(context: Context, op: Instruction, label: Label) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 1);
    operand_kinds[0] = .Label;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 1);
    operands[0] = label;
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

fn opStackLiteral(context: Context, op: Instruction, offset: usize, literal: InternedString) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .StackOffsetQword;
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
    switch (registerSize(reg)) {
        .Qword => operand_kinds[1] = .StackOffsetQword,
        .Dword => operand_kinds[1] = .StackOffsetDword,
        .Byte => operand_kinds[1] = .StackOffsetByte,
    }
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
    operand_kinds[1] = .StackOffsetQword;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(reg);
    operands[1] = offset;
    _ = try context.x86_block.operands.insert(operands);
}

fn opStackReg(context: Context, op: Instruction, offset: usize, reg: Register) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    switch (registerSize(reg)) {
        .Qword => operand_kinds[0] = .StackOffsetQword,
        .Dword => operand_kinds[0] = .StackOffsetDword,
        .Byte => operand_kinds[0] = .StackOffsetByte,
    }
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
    operand_kinds[0] = .StackOffsetQword;
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

fn opStack(context: Context, op: Instruction, offset: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 1);
    operand_kinds[0] = .StackOffsetQword;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 1);
    operands[0] = offset;
    _ = try context.x86_block.operands.insert(operands);
}

fn opSseRegRelQuadWord(context: Context, op: Instruction, to: SseRegister, quad_word: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .SseRegister;
    operand_kinds[1] = .RelativeQword;
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

fn opRegBytePointer(context: Context, op: Instruction, to: Register, from: Register) !void {
    assert(registerSize(to) == .Byte);
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .BytePointer;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = @enumToInt(from);
    _ = try context.x86_block.operands.insert(operands);
}

fn alignStackTo16Bytes(context: Context) !usize {
    const value = context.stack.top % 16;
    if (value == 0) return value;
    const desired = 16 - value;
    const interned = try internInt(context, desired);
    try opRegLiteral(context, .Sub, .Rsp, interned);
    context.stack.top += desired;
    return desired;
}

fn restoreStack(context: Context, offset: usize) !void {
    if (offset == 0) return;
    const interned = try internInt(context, offset);
    try opRegLiteral(context, .Add, .Rsp, interned);
    context.stack.top -= offset;
}

fn codegenPrintI64(context: Context, call: Call) !void {
    try moveToRegister(context, .Rsi, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%ld\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 8;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, result_offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenPrintI32(context: Context, call: Call) !void {
    try moveToRegister(context, .Esi, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%d\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 8;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, result_offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenPrintU8(context: Context, call: Call) !void {
    try moveToRegister(context, .Sil, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%c\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 8;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, result_offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenPrintF64(context: Context, call: Call) !void {
    try moveToSseRegister(context, .Xmm0, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%f\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    const one = try internInt(context, 1);
    try opRegLiteral(context, .Mov, .Rax, one);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 8;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, result_offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenPrintArray(context: Context, call: Call, type_of: Entity) !void {
    const argument = call.argument_entities[0];
    const array_index = context.entities.array_index.get(type_of).?;
    assert(context.entities.arrays.types.items[array_index] == U8);
    const string_literal = context.entities.interned_strings.data.items[context.entities.literals.get(argument).?];
    const buffer = try std.fmt.allocPrint(context.allocator, "{s}, 0", .{string_literal});
    defer context.allocator.free(buffer);
    const null_terminated_string = try internString(context.entities, buffer);
    try insertUniqueId(&context.x86.bytes, null_terminated_string);
    const format_string = try internString(context.entities, "\"%s\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Mov, .Rsi, null_terminated_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 8;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, result_offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenPrintPtr(context: Context, call: Call, type_of: Entity) !void {
    const argument = call.argument_entities[0];
    const pointer_index = context.entities.pointer_index.get(type_of).?;
    assert(context.entities.pointers.items[pointer_index] == U8);
    const format_string = try internString(context.entities, "\"%s\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Mov, .Rdi, format_string);
    try moveToRegister(context, .Rsi, argument);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opLiteral(context, .Call, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 8;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, result_offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenPrint(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 1);
    const argument = call.argument_entities[0];
    const type_of = context.entities.types.get(argument).?;
    switch (type_of) {
        Int, I64 => try codegenPrintI64(context, call),
        I32 => try codegenPrintI32(context, call),
        U8 => try codegenPrintU8(context, call),
        Float, F64 => try codegenPrintF64(context, call),
        else => {
            switch (context.entities.values.get(type_of).?) {
                Array => try codegenPrintArray(context, call, type_of),
                Ptr => try codegenPrintPtr(context, call, type_of),
                else => unreachable,
            }
        },
    }
}

const BinaryOps = struct {
    int: Instruction,
    float: Instruction,
};

const AddOps = BinaryOps{ .int = .Add, .float = .Addsd };
const SubOps = BinaryOps{ .int = .Sub, .float = .Subsd };
const MulOps = BinaryOps{ .int = .Imul, .float = .Mulsd };

fn moveToRegister(context: Context, register: Register, entity: Entity) !void {
    if (context.entities.literals.get(entity)) |value| {
        try opRegLiteral(context, .Mov, register, value);
        return;
    }
    const offset = context.stack.entity.get(entity).?;
    try opRegStack(context, .Mov, register, offset);
}

fn moveToSseRegister(context: Context, register: SseRegister, entity: Entity) !void {
    if (context.entities.literals.get(entity)) |value| {
        switch (context.entities.types.get(entity).?) {
            @enumToInt(Builtins.Int) => {
                const interned = context.entities.interned_strings.data.items[value];
                const buffer = try std.fmt.allocPrint(context.allocator, "{s}.0", .{interned});
                const quad_word = try internString(context.entities, buffer);
                try insertUniqueId(&context.x86.quad_words, quad_word);
                try opSseRegRelQuadWord(context, .Movsd, register, quad_word);
            },
            @enumToInt(Builtins.Float) => {
                try insertUniqueId(&context.x86.quad_words, value);
                try opSseRegRelQuadWord(context, .Movsd, register, value);
            },
            else => unreachable,
        }
    } else if (context.stack.entity.get(entity)) |offset| {
        try opSseRegStack(context, .Movsd, register, offset);
    } else {
        unreachable;
    }
}

fn codegenBinaryOpIntInt(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Rax, lhs);
    if (context.entities.literals.get(rhs)) |value| {
        assert(context.entities.types.get(rhs).? == @enumToInt(Builtins.Int));
        try opRegLiteral(context, .Mov, .Rcx, value);
        try opRegReg(context, op, .Rax, .Rcx);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opRegStack(context, op, .Rax, offset);
    } else {
        unreachable;
    }
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenBinaryOpFloatFloat(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    try moveToSseRegister(context, .Xmm0, lhs);
    if (context.entities.literals.get(rhs)) |value| {
        switch (context.entities.types.get(rhs).?) {
            @enumToInt(Builtins.Int) => {
                const interned = context.entities.interned_strings.data.items[value];
                const buffer = try std.fmt.allocPrint(context.allocator, "{s}.0", .{interned});
                const quad_word = try internString(context.entities, buffer);
                try insertUniqueId(&context.x86.quad_words, quad_word);
                try opSseRegRelQuadWord(context, .Movsd, .Xmm1, quad_word);
            },
            @enumToInt(Builtins.Float) => {
                try insertUniqueId(&context.x86.quad_words, value);
                try opSseRegRelQuadWord(context, .Movsd, .Xmm1, value);
            },
            else => unreachable,
        }
        try opSseRegSseReg(context, op, .Xmm0, .Xmm1);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opSseRegStack(context, .Movsd, .Xmm1, offset);
        try opSseRegSseReg(context, op, .Xmm0, .Xmm1);
    } else {
        unreachable;
    }
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackSseReg(context, .Movsd, offset, .Xmm0);
    try context.entities.types.putNoClobber(call.result_entity, F64);
}

fn codegenBinaryOp(context: Context, call: Call, ops: BinaryOps) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (context.entities.types.get(lhs).?) {
        Int => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenBinaryOpIntInt(context, call, ops.int, lhs, rhs),
            Float, F64 => try codegenBinaryOpFloatFloat(context, call, ops.float, lhs, rhs),
            else => unreachable,
        },
        I64 => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenBinaryOpIntInt(context, call, ops.int, lhs, rhs),
            else => unreachable,
        },
        Float, F64 => switch (context.entities.types.get(rhs).?) {
            Int, Float, F64 => try codegenBinaryOpFloatFloat(context, call, ops.float, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenDivideIntInt(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Rax, lhs);
    try opNoArgs(context.x86_block, .Cqo);
    if (context.entities.literals.get(rhs)) |value| {
        assert(context.entities.types.get(rhs).? == @enumToInt(Builtins.Int));
        try opRegLiteral(context, .Mov, .Rcx, value);
        try opReg(context, .Idiv, .Rcx);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opStack(context, .Idiv, offset);
    } else {
        unreachable;
    }
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenDivide(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (context.entities.types.get(lhs).?) {
        Int => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenDivideIntInt(context, call, lhs, rhs),
            Float, F64 => try codegenBinaryOpFloatFloat(context, call, .Divsd, lhs, rhs),
            else => unreachable,
        },
        I64 => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenDivideIntInt(context, call, lhs, rhs),
            else => unreachable,
        },
        Float, F64 => switch (context.entities.types.get(rhs).?) {
            Int, Float, F64 => try codegenBinaryOpFloatFloat(context, call, .Divsd, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenBitOrI64(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Rax, lhs);
    if (context.entities.literals.get(rhs)) |value| {
        const rhs_type = context.entities.types.get(rhs).?;
        try opRegLiteral(context, .Mov, .Rcx, value);
        try opRegReg(context, .Or, .Rax, .Rcx);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opRegStack(context, .Or, .Rax, offset);
    } else {
        unreachable;
    }
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenBitOrI32(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Eax, lhs);
    if (context.entities.literals.get(rhs)) |value| {
        const rhs_type = context.entities.types.get(rhs).?;
        try opRegLiteral(context, .Mov, .Ecx, value);
        try opRegReg(context, .Or, .Eax, .Ecx);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opRegStack(context, .Or, .Eax, offset);
    } else {
        unreachable;
    }
    context.stack.top += 4;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const four = try internInt(context, 4);
    try opRegLiteral(context, .Sub, .Rsp, four);
    try opStackReg(context, .Mov, offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenBitOr(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (context.entities.types.get(lhs).?) {
        Int => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenBitOrI64(context, call, lhs, rhs),
            I32 => try codegenBitOrI32(context, call, lhs, rhs),
            else => unreachable,
        },
        I64 => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenBitOrI32(context, call, lhs, rhs),
            else => unreachable,
        },
        I32 => switch (context.entities.types.get(rhs).?) {
            Int, I32 => try codegenBitOrI32(context, call, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenOpen(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const open_syscall = try internString(context.entities, "0x2000005");
    try opRegLiteral(context, .Mov, .Rax, open_syscall);
    const path = call.argument_entities[0];
    const type_of = context.entities.types.get(path).?;
    assert(context.entities.values.get(type_of).? == Array);
    const array_index = context.entities.array_index.get(type_of).?;
    assert(context.entities.arrays.types.items[array_index] == U8);
    const string_literal = context.entities.interned_strings.data.items[context.entities.literals.get(path).?];
    const buffer = try std.fmt.allocPrint(context.allocator, "{s}, 0", .{string_literal});
    defer context.allocator.free(buffer);
    const null_terminated_string = try internString(context.entities, buffer);
    try insertUniqueId(&context.x86.bytes, null_terminated_string);
    try opRegByte(context, .Mov, .Rdi, null_terminated_string);
    const oflag = call.argument_entities[1];
    assert(context.entities.types.get(oflag).? == I32 or context.entities.types.get(oflag).? == Int);
    try moveToRegister(context, .Esi, oflag);
    try opRegReg(context, .Xor, .Rdx, .Rdx);
    try opNoArgs(context.x86_block, .Syscall);
    context.stack.top += 4;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const four = try internInt(context, 4);
    try opRegLiteral(context, .Sub, .Rsp, four);
    try opStackReg(context, .Mov, offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenLseek(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 3);
    const lseek_syscall = try internString(context.entities, "0x20000C7");
    try opRegLiteral(context, .Mov, .Rax, lseek_syscall);
    const fd = call.argument_entities[0];
    assert(context.entities.types.get(fd).? == I32 or context.entities.types.get(fd).? == Int);
    try moveToRegister(context, .Edi, fd);
    const offset = call.argument_entities[1];
    assert(context.entities.types.get(offset).? == I64 or context.entities.types.get(offset).? == Int);
    try moveToRegister(context, .Rsi, offset);
    const whence = call.argument_entities[2];
    assert(context.entities.types.get(whence).? == I64 or context.entities.types.get(whence).? == Int);
    try moveToRegister(context, .Edx, whence);
    try opNoArgs(context.x86_block, .Syscall);
    context.stack.top += 8;
    const stack_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, stack_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, stack_offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenMmap(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 6);
    const mmap_syscall = try internString(context.entities, "0x20000C5");
    try opRegLiteral(context, .Mov, .Rax, mmap_syscall);
    const addr = call.argument_entities[0];
    const addr_type = context.entities.types.get(addr).?;
    assert(context.entities.values.get(addr_type).? == Ptr);
    assert(context.entities.pointers.items[context.entities.pointer_index.get(addr_type).?] == Void);
    try moveToRegister(context, .Rdi, addr);
    const len = call.argument_entities[1];
    assert(context.entities.types.get(len).? == I64 or context.entities.types.get(len).? == Int);
    try moveToRegister(context, .Rsi, len);
    const prot = call.argument_entities[2];
    assert(context.entities.types.get(prot).? == I32 or context.entities.types.get(prot).? == Int);
    try moveToRegister(context, .Edx, prot);
    const flags = call.argument_entities[3];
    assert(context.entities.types.get(flags).? == I32 or context.entities.types.get(flags).? == Int);
    try moveToRegister(context, .Ecx, flags);
    const fd = call.argument_entities[4];
    assert(context.entities.types.get(fd).? == I32 or context.entities.types.get(fd).? == Int);
    try moveToRegister(context, .R8d, fd);
    const pos = call.argument_entities[5];
    assert(context.entities.types.get(pos).? == I64 or context.entities.types.get(pos).? == Int);
    try moveToRegister(context, .R9, pos);
    try opRegLiteral(context, .Mov, .R10, try internString(context.entities, "0x1002"));
    try opNoArgs(context.x86_block, .Syscall);
    context.stack.top += 8;
    const stack_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, stack_offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, stack_offset, .Rax);
    const type_of = context.entities.next_entity;
    context.entities.next_entity += 1;
    try context.entities.types.putNoClobber(call.result_entity, type_of);
    try context.entities.values.putNoClobber(type_of, Ptr);
    const index = try context.entities.pointers.insert(Void);
    try context.entities.pointer_index.putNoClobber(type_of, index);
    try context.entities.types.putNoClobber(type_of, Type);
}

fn codegenMunmap(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const munmap_syscall = try internString(context.entities, "0x2000049");
    try opRegLiteral(context, .Mov, .Rax, munmap_syscall);
    const addr = call.argument_entities[0];
    const type_of = context.entities.types.get(addr).?;
    assert(context.entities.values.get(type_of).? == Ptr);
    try moveToRegister(context, .Rdi, addr);
    const len = call.argument_entities[1];
    assert(context.entities.types.get(len).? == I64 or context.entities.types.get(len).? == Int);
    try moveToRegister(context, .Rsi, len);
    try opNoArgs(context.x86_block, .Syscall);
    context.stack.top += 4;
    const stack_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, stack_offset);
    const four = try internInt(context, 4);
    try opRegLiteral(context, .Sub, .Rsp, four);
    try opStackReg(context, .Mov, stack_offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, Int);
}

fn codegenRead(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 3);
    const read_syscall = try internString(context.entities, "0x2000003");
    try opRegLiteral(context, .Mov, .Rax, read_syscall);
    const fd = call.argument_entities[0];
    assert(context.entities.types.get(fd).? == I32 or context.entities.types.get(fd).? == Int);
    try moveToRegister(context, .Edi, fd);
    const buf = call.argument_entities[1];
    const buf_type = context.entities.types.get(buf).?;
    assert(context.entities.values.get(buf_type).? == Ptr);
    try moveToRegister(context, .Rsi, buf);
    const bytes = call.argument_entities[2];
    assert(context.entities.types.get(bytes).? == I64 or context.entities.types.get(bytes).? == Int);
    try moveToRegister(context, .Rdx, bytes);
    try opNoArgs(context.x86_block, .Syscall);
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const eight = try internInt(context, 8);
    try opRegLiteral(context, .Sub, .Rsp, eight);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenClose(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 1);
    const close_syscall = try internString(context.entities, "0x2000006");
    try opRegLiteral(context, .Mov, .Rax, close_syscall);
    const fd = call.argument_entities[0];
    assert(context.entities.types.get(fd).? == I32 or context.entities.types.get(fd).? == Int);
    try moveToRegister(context, .Edi, fd);
    try opNoArgs(context.x86_block, .Syscall);
    context.stack.top += 4;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    const four = try internInt(context, 4);
    try opRegLiteral(context, .Sub, .Rsp, four);
    try opStackReg(context, .Mov, offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenPtr(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 1);
    const element_type = call.argument_entities[0];
    assert(context.entities.types.get(element_type).? == Type);
    try context.entities.types.putNoClobber(call.result_entity, Type);
    try context.entities.values.putNoClobber(call.result_entity, Ptr);
    const pointer_index = try context.entities.pointers.insert(element_type);
    try context.entities.pointer_index.putNoClobber(call.result_entity, pointer_index);
}

fn codegenDeref(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 1);
    const argument = call.argument_entities[0];
    const type_of = context.entities.types.get(argument).?;
    assert(context.entities.values.get(type_of).? == Ptr);
    const pointer_index = context.entities.pointer_index.get(type_of).?;
    const element_type = context.entities.pointers.items[pointer_index];
    assert(element_type == U8);
    context.stack.top += 1;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try context.entities.types.putNoClobber(call.result_entity, element_type);
    const one = try internInt(context, 1);
    try opRegLiteral(context, .Sub, .Rsp, one);
    const argument_offset = context.stack.entity.get(argument).?;
    try opRegStack(context, .Mov, .Rdi, argument_offset);
    try opRegBytePointer(context, .Mov, .Sil, .Rdi);
    try opStackReg(context, .Mov, result_offset, .Sil);
}

fn codegenTypedLet(context: Context, typed_let_index: usize) !void {
    const typed_let = context.ir_block.typed_lets.items[context.ir_block.indices.items[typed_let_index]];
    assert(context.entities.types.get(typed_let.type_entity).? == Type);
    const type_of = context.entities.types.get(typed_let.entity).?;
    switch (type_of) {
        Int => {
            switch (typed_let.type_entity) {
                Int, I64, I32 => try context.entities.types.put(typed_let.entity, typed_let.type_entity),
                else => unreachable,
            }
        },
        Float => {
            switch (typed_let.type_entity) {
                Float, F64 => try context.entities.types.put(typed_let.entity, typed_let.type_entity),
                else => unreachable,
            }
        },
        else => {
            if (context.entities.values.get(type_of)) |value| {
                switch (value) {
                    Ptr => {
                        const type_entity_pointer_index = context.entities.pointer_index.get(typed_let.type_entity).?;
                        const type_entity_element_type = context.entities.pointers.items[type_entity_pointer_index];
                        assert(context.entities.types.get(type_entity_element_type).? == Type);
                        const pointer_index = context.entities.pointer_index.get(type_of).?;
                        const element_type = context.entities.pointers.items[pointer_index];
                        assert(type_entity_element_type == element_type or element_type == Void);
                        context.entities.pointers.items[pointer_index] = type_entity_element_type;
                    },
                    else => unreachable,
                }
            } else {
                assert(type_of == typed_let.type_entity);
            }
        },
    }
}

fn codegenCopyingLet(context: Context, copying_let_index: usize) !void {
    const copying_let = context.ir_block.copying_lets.items[context.ir_block.indices.items[copying_let_index]];
    const type_of = context.entities.types.get(copying_let.source_entity).?;
    try context.entities.types.putNoClobber(copying_let.destination_entity, type_of);
    const literal = context.entities.literals.get(copying_let.source_entity).?;
    try context.entities.literals.putNoClobber(copying_let.destination_entity, literal);
}

fn codegenCopyingTypedLet(context: Context, copying_typed_let_index: usize) !void {
    const copying_typed_let = context.ir_block.copying_typed_lets.items[context.ir_block.indices.items[copying_typed_let_index]];
    const type_of = context.entities.types.get(copying_typed_let.source_entity).?;
    switch (type_of) {
        Int => {
            switch (copying_typed_let.type_entity) {
                Int, I64, I32 => try context.entities.types.put(copying_typed_let.destination_entity, copying_typed_let.type_entity),
                else => unreachable,
            }
        },
        Float => {
            switch (copying_typed_let.type_entity) {
                Float, F64 => try context.entities.types.put(copying_typed_let.destination_entity, copying_typed_let.type_entity),
                else => unreachable,
            }
        },
        else => {
            if (context.entities.values.get(type_of)) |value| {
                switch (value) {
                    Ptr => {
                        assert(context.entities.values.get(copying_typed_let.type_entity).? == Ptr);
                        const type_entity_pointer_index = context.entities.pointer_index.get(copying_typed_let.type_entity).?;
                        const type_entity_element_type = context.entities.pointers.items[type_entity_pointer_index];
                        assert(context.entities.types.get(type_entity_element_type).? == Type);
                        const pointer_index = context.entities.pointer_index.get(copying_typed_let.destination_entity).?;
                        const element_type = context.entities.pointers.items[pointer_index];
                        assert(type_entity_element_type == element_type or element_type == Void);
                        context.entities.pointers.items[pointer_index] = type_entity_element_type;
                    },
                    Array => {
                        assert(context.entities.values.get(copying_typed_let.type_entity).? == Ptr);
                        const type_entity_pointer_index = context.entities.pointer_index.get(copying_typed_let.type_entity).?;
                        const type_entity_element_type = context.entities.pointers.items[type_entity_pointer_index];
                        assert(context.entities.types.get(type_entity_element_type).? == Type);
                        const source_entity_type = context.entities.types.get(copying_typed_let.source_entity).?;
                        const array_index = context.entities.array_index.get(source_entity_type).?;
                        const element_type = context.entities.arrays.types.items[array_index];
                        assert(type_entity_element_type == element_type);
                        assert(element_type == U8);
                        const string_literal = context.entities.interned_strings.data.items[context.entities.literals.get(copying_typed_let.source_entity).?];
                        const buffer = try std.fmt.allocPrint(context.allocator, "{s}, 0", .{string_literal});
                        defer context.allocator.free(buffer);
                        const null_terminated_string = try internString(context.entities, buffer);
                        try insertUniqueId(&context.x86.bytes, null_terminated_string);
                        context.stack.top += 8;
                        const result_offset = context.stack.top;
                        try context.stack.entity.putNoClobber(copying_typed_let.destination_entity, result_offset);
                        try context.entities.types.putNoClobber(copying_typed_let.destination_entity, copying_typed_let.type_entity);
                        const eight = try internInt(context, 8);
                        try opRegLiteral(context, .Sub, .Rsp, eight);
                        try opRegByte(context, .Mov, .Rdi, null_terminated_string);
                        try opStackReg(context, .Mov, result_offset, .Rdi);
                    },
                    else => unreachable,
                }
            } else {
                assert(type_of == copying_typed_let.type_entity);
            }
        },
    }
    const literal = context.entities.literals.get(copying_typed_let.source_entity).?;
    try context.entities.literals.putNoClobber(copying_typed_let.destination_entity, literal);
}

fn codegenCall(context: Context, call_index: usize) error{OutOfMemory}!void {
    const call = context.ir_block.calls.items[context.ir_block.indices.items[call_index]];
    const name = context.entities.names.get(call.function_entity).?;
    switch (name) {
        @enumToInt(Builtins.Add) => try codegenBinaryOp(context, call, AddOps),
        @enumToInt(Builtins.Sub) => try codegenBinaryOp(context, call, SubOps),
        @enumToInt(Builtins.Mul) => try codegenBinaryOp(context, call, MulOps),
        @enumToInt(Builtins.Div) => try codegenDivide(context, call),
        @enumToInt(Builtins.Bit_Or) => try codegenBitOr(context, call),
        @enumToInt(Builtins.Print) => try codegenPrint(context, call),
        @enumToInt(Builtins.Open) => try codegenOpen(context, call),
        @enumToInt(Builtins.Close) => try codegenClose(context, call),
        @enumToInt(Builtins.Lseek) => try codegenLseek(context, call),
        @enumToInt(Builtins.Mmap) => try codegenMmap(context, call),
        @enumToInt(Builtins.Munmap) => try codegenMunmap(context, call),
        @enumToInt(Builtins.Read) => try codegenRead(context, call),
        @enumToInt(Builtins.Ptr) => try codegenPtr(context, call),
        @enumToInt(Builtins.Deref) => try codegenDeref(context, call),
        else => {
            const index = context.ir.name_to_index.get(name).?;
            assert(context.ir.kinds.items[index] == DeclarationKind.Function);
            const function = &context.ir.functions.items[context.ir.indices.items[index]];
            assert(function.overloads.length == 1);
            const overload = &function.overloads.items[0];
            const overload_index = context.entities.overload_index.get(function.entities.items[0]).?;
            const int_registers = [_]Register{ .Rdi, .Rsi, .Rdx, .Rcx, .R8, .R9 };
            const float_registers = [_]SseRegister{ .Xmm0, .Xmm1, .Xmm2, .Xmm3, .Xmm4, .Xmm5 };
            if (context.entities.overloads.status.items[overload_index] == .Unanalyzed) {
                const type_block_indices = overload.parameter_type_block_indices;
                assert(type_block_indices.len == call.argument_entities.len);
                const parameter_entities = overload.parameter_entities;
                const parameter_types = try context.allocator.alloc(Entity, parameter_entities.len);
                for (type_block_indices) |type_block_index, argument_index| {
                    assert(argument_index < int_registers.len);
                    const type_block = &overload.blocks.items[type_block_index];
                    assert(type_block.kinds.length == 1);
                    assert(type_block.kinds.items[0] == .Return);
                    const parameter_type = type_block.returns.items[type_block.indices.items[0]];
                    const argument_entity = call.argument_entities[argument_index];
                    const argument_type = context.entities.types.get(argument_entity).?;
                    switch (parameter_type) {
                        I64 => {
                            assert(argument_type == Int or argument_type == I64);
                            try moveToRegister(context, int_registers[argument_index], argument_entity);
                        },
                        F64 => {
                            assert(argument_type == Int or argument_type == Float or argument_type == F64);
                            try moveToSseRegister(context, float_registers[argument_index], argument_entity);
                        },
                        else => unreachable,
                    }
                    try context.entities.types.putNoClobber(parameter_entities[argument_index], parameter_type);
                    parameter_types[argument_index] = parameter_type;
                }
                const x86_block_result = try context.x86.blocks.addOne();
                const align_offset = try alignStackTo16Bytes(context);
                try opLabel(context, .Call, x86_block_result.index);
                try restoreStack(context, align_offset);
                const return_type_block = &overload.blocks.items[overload.return_type_block_index];
                assert(return_type_block.kinds.length == 1);
                assert(return_type_block.kinds.items[0] == .Return);
                const return_type = return_type_block.returns.items[return_type_block.indices.items[0]];
                const eight = try internInt(context, 8);
                try opRegLiteral(context, .Sub, .Rsp, eight);
                context.stack.top += 8;
                try context.stack.entity.putNoClobber(call.result_entity, context.stack.top);
                switch (return_type) {
                    I64 => try opStackReg(context, .Mov, context.stack.top, .Rax),
                    F64 => try opStackSseReg(context, .Movsd, context.stack.top, .Xmm0),
                    else => unreachable,
                }
                try context.entities.types.putNoClobber(call.result_entity, return_type);
                context.entities.overloads.parameter_types.items[overload_index] = parameter_types;
                context.entities.overloads.return_type.items[overload_index] = return_type;
                context.entities.overloads.block.items[overload_index] = x86_block_result.index;
                context.entities.overloads.status.items[overload_index] = .Analyzed;
                const x86_block = x86_block_result.ptr;
                x86_block.instructions = List(Instruction).init(context.allocator);
                x86_block.operand_kinds = List([]const Kind).init(context.allocator);
                x86_block.operands = List([]const usize).init(context.allocator);
                var stack = Stack{
                    .entity = Map(Entity, usize).init(context.allocator),
                    .top = 0,
                };
                const overload_context = Context{
                    .allocator = context.allocator,
                    .overload = overload,
                    .x86 = context.x86,
                    .x86_block = x86_block,
                    .ir = context.ir,
                    .ir_block = &overload.blocks.items[overload.body_block_index],
                    .stack = &stack,
                    .entities = context.entities,
                    .interned_ints = context.interned_ints,
                };
                try opReg(overload_context, .Push, .Rbp);
                try opRegReg(overload_context, .Mov, .Rbp, .Rsp);
                const parameter_offset = parameter_entities.len * 8;
                const interned_int = try internInt(overload_context, parameter_offset);
                overload_context.stack.top = parameter_offset;
                try opRegLiteral(overload_context, .Sub, .Rsp, interned_int);
                for (parameter_entities) |parameter_entity, i| {
                    const offset = (i + 1) * 8;
                    switch (parameter_types[i]) {
                        I64 => try opStackReg(overload_context, .Mov, offset, int_registers[i]),
                        F64 => try opStackSseReg(overload_context, .Movsd, offset, float_registers[i]),
                        else => unreachable,
                    }
                    try overload_context.stack.entity.putNoClobber(parameter_entity, offset);
                }
                for (overload_context.ir_block.kinds.slice()) |expression_kind, i| {
                    switch (expression_kind) {
                        .Return => {
                            const ret = overload_context.ir_block.returns.items[overload_context.ir_block.indices.items[i]];
                            if (stack.entity.get(ret)) |offset| {
                                switch (return_type) {
                                    I64 => try opRegStack(overload_context, .Mov, .Rax, offset),
                                    F64 => try opSseRegStack(overload_context, .Movsd, .Xmm0, offset),
                                    else => unreachable,
                                }
                            } else if (context.entities.literals.get(ret)) |value| {
                                switch (return_type) {
                                    I64 => try opRegLiteral(overload_context, .Mov, .Rax, value),
                                    F64 => {
                                        try insertUniqueId(&context.x86.quad_words, value);
                                        try opSseRegRelQuadWord(context, .Movsd, .Xmm0, value);
                                    },
                                    else => unreachable,
                                }
                            } else {
                                unreachable;
                            }
                            if (overload_context.stack.top > 0) {
                                const offset = try internInt(overload_context, overload_context.stack.top);
                                try opRegLiteral(overload_context, .Add, .Rsp, offset);
                            }
                            try opReg(overload_context, .Pop, .Rbp);
                            try opNoArgs(x86_block, .Ret);
                        },
                        .Call => try codegenCall(overload_context, i),
                        else => unreachable,
                    }
                }
            } else {
                const parameter_types = context.entities.overloads.parameter_types.items[overload_index];
                assert(parameter_types.len == call.argument_entities.len);
                for (parameter_types) |parameter_type, argument_index| {
                    assert(argument_index < int_registers.len);
                    const argument_entity = call.argument_entities[argument_index];
                    const argument_type = context.entities.types.get(argument_entity).?;
                    switch (parameter_type) {
                        I64 => {
                            assert(argument_type == Int or argument_type == I64);
                            try moveToRegister(context, int_registers[argument_index], argument_entity);
                        },
                        F64 => {
                            assert(argument_type == Int or argument_type == Float or argument_type == F64);
                            try moveToSseRegister(context, float_registers[argument_index], argument_entity);
                        },
                        else => unreachable,
                    }
                }
                const block_index = context.entities.overloads.block.items[overload_index];
                const align_offset = try alignStackTo16Bytes(context);
                try opLabel(context, .Call, block_index);
                try restoreStack(context, align_offset);
                const eight = try internInt(context, 8);
                try opRegLiteral(context, .Sub, .Rsp, eight);
                context.stack.top += 8;
                try context.stack.entity.putNoClobber(call.result_entity, context.stack.top);
                const return_type = context.entities.overloads.return_type.items[overload_index];
                try context.entities.types.putNoClobber(call.result_entity, return_type);
                switch (return_type) {
                    I64 => try opStackReg(context, .Mov, context.stack.top, .Rax),
                    F64 => try opStackSseReg(context, .Movsd, context.stack.top, .Xmm0),
                    else => unreachable,
                }
            }
        },
    }
}

fn codegenStart(x86: *X86, entities: *Entities, ir: Ir) !void {
    const name = entities.interned_strings.mapping.get("start").?;
    const index = ir.name_to_index.get(name).?;
    const declaration_kind = ir.kinds.items[index];
    assert(declaration_kind == DeclarationKind.Function);
    assert(name == ir.names.items[index]);
    const function = &ir.functions.items[ir.indices.items[index]];
    assert(function.overloads.length == 1);
    const allocator = &x86.arena.allocator;
    const x86_block = (try x86.blocks.addOne()).ptr;
    x86_block.instructions = List(Instruction).init(allocator);
    x86_block.operand_kinds = List([]const Kind).init(allocator);
    x86_block.operands = List([]const usize).init(allocator);
    const overload = &function.overloads.items[0];
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
        .ir = &ir,
        .ir_block = &overload.blocks.items[overload.body_block_index],
        .stack = &stack,
        .entities = entities,
        .interned_ints = &interned_ints,
    };
    try opReg(context, .Push, .Rbp);
    try opRegReg(context, .Mov, .Rbp, .Rsp);
    for (context.ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Return => {
                const ret = context.ir_block.returns.items[context.ir_block.indices.items[i]];
                assert(entities.types.get(ret).? == I64 or entities.types.get(ret).? == Int);
                if (stack.entity.get(ret)) |offset| {
                    try opRegStack(context, .Mov, .Rdi, offset);
                } else if (context.entities.literals.get(ret)) |value| {
                    try opRegLiteral(context, .Mov, .Rdi, value);
                } else {
                    unreachable;
                }
                const sys_exit = try internString(entities, "0x02000001");
                try opRegLiteral(context, .Mov, .Rax, sys_exit);
                try opNoArgs(x86_block, .Syscall);
            },
            .Call => try codegenCall(context, i),
            .TypedLet => try codegenTypedLet(context, i),
            .CopyingLet => try codegenCopyingLet(context, i),
            .CopyingTypedLet => try codegenCopyingTypedLet(context, i),
            else => unreachable,
        }
    }
}

pub fn codegen(allocator: *Allocator, entities: *Entities, ir: Ir) !X86 {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    var x86 = X86{
        .arena = arena,
        .externs = Set(InternedString).init(&arena.allocator),
        .bytes = initUniqueIds(&arena.allocator),
        .quad_words = initUniqueIds(&arena.allocator),
        .blocks = List(X86Block).init(&arena.allocator),
    };
    try codegenStart(&x86, entities, ir);
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
        .Or => try output.insertSlice("or"),
        .Call => try output.insertSlice("call"),
        .Syscall => try output.insertSlice("syscall"),
        .Cqo => try output.insertSlice("cqo"),
        .Ret => try output.insertSlice("ret"),
    }
}

fn writeRegister(output: *List(u8), register: Register) !void {
    switch (register) {
        .Rax => try output.insertSlice("rax"),
        .Eax => try output.insertSlice("eax"),
        .Ah => try output.insertSlice("ah"),
        .Al => try output.insertSlice("al"),
        .Rbx => try output.insertSlice("rbx"),
        .Ebx => try output.insertSlice("ebx"),
        .Bh => try output.insertSlice("bh"),
        .Bl => try output.insertSlice("bl"),
        .Rcx => try output.insertSlice("rcx"),
        .Ecx => try output.insertSlice("ecx"),
        .Ch => try output.insertSlice("ch"),
        .Cl => try output.insertSlice("cl"),
        .Rdx => try output.insertSlice("rdx"),
        .Edx => try output.insertSlice("edx"),
        .Dh => try output.insertSlice("dh"),
        .Dl => try output.insertSlice("dl"),
        .Rbp => try output.insertSlice("rbp"),
        .Ebp => try output.insertSlice("ebp"),
        .Bpl => try output.insertSlice("bpl"),
        .Rsp => try output.insertSlice("rsp"),
        .Esp => try output.insertSlice("esp"),
        .Spl => try output.insertSlice("spl"),
        .Rsi => try output.insertSlice("rsi"),
        .Esi => try output.insertSlice("esi"),
        .Sil => try output.insertSlice("sil"),
        .Rdi => try output.insertSlice("rdi"),
        .Edi => try output.insertSlice("edi"),
        .Dil => try output.insertSlice("dil"),
        .R8 => try output.insertSlice("r8"),
        .R8d => try output.insertSlice("r8d"),
        .R8b => try output.insertSlice("r8b"),
        .R9 => try output.insertSlice("r9"),
        .R9d => try output.insertSlice("r9d"),
        .R9b => try output.insertSlice("r9b"),
        .R10 => try output.insertSlice("r10"),
        .R10d => try output.insertSlice("r10d"),
        .R10b => try output.insertSlice("r10b"),
        .R11 => try output.insertSlice("r11"),
        .R11d => try output.insertSlice("r11d"),
        .R11b => try output.insertSlice("r11b"),
        .R12 => try output.insertSlice("r12"),
        .R12d => try output.insertSlice("r12d"),
        .R12b => try output.insertSlice("r12b"),
        .R13 => try output.insertSlice("r13"),
        .R13d => try output.insertSlice("r13d"),
        .R13b => try output.insertSlice("r13b"),
        .R14 => try output.insertSlice("r14"),
        .R14d => try output.insertSlice("r14d"),
        .R14b => try output.insertSlice("r14b"),
        .R15 => try output.insertSlice("r15"),
        .R15d => try output.insertSlice("r15d"),
        .R15b => try output.insertSlice("r15b"),
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

fn uniqueIdString(output: *List(u8), prefix: []const u8, suffix: []const u8, ids: UniqueIds, entities: Entities) !void {
    var i: usize = 0;
    while (i < ids.next_index) : (i += 1) {
        try output.insertSlice(prefix);
        try output.insertFormatted("{}", .{i});
        try output.insertSlice(": ");
        try output.insertSlice(suffix);
        _ = try output.insert(' ');
        const interned_string = ids.index_to_string.items[i];
        try output.insertSlice(entities.interned_strings.data.items[interned_string]);
        _ = try output.insert('\n');
    }
}

pub fn x86String(allocator: *Allocator, x86: X86, entities: Entities) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    try output.insertSlice("    global _main\n");
    var extern_iterator = x86.externs.iterator();
    while (extern_iterator.next()) |entry| {
        try output.insertSlice("    extern ");
        try output.insertSlice(entities.interned_strings.data.items[entry.key]);
        _ = try output.insert('\n');
    }
    if ((x86.bytes.next_index + x86.quad_words.next_index) > 0) {
        try output.insertSlice("\n    section .data\n\n");
    }
    try uniqueIdString(&output, "byte"[0..], "db"[0..], x86.bytes, entities);
    try uniqueIdString(&output, "quad_word"[0..], "dq"[0..], x86.quad_words, entities);
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
                    .Literal => try output.insertSlice(entities.interned_strings.data.items[operands[k]]),
                    .Byte => try output.insertFormatted("byte{}", .{x86.bytes.string_to_index.get(operands[k]).?}),
                    .QuadWord => try output.insertFormatted("quad_word{}", .{x86.quad_words.string_to_index.get(operands[k]).?}),
                    .RelativeQword => try output.insertFormatted("[rel quad_word{}]", .{x86.quad_words.string_to_index.get(operands[k]).?}),
                    .StackOffsetQword => try output.insertFormatted("qword [rbp-{}]", .{operands[k]}),
                    .StackOffsetDword => try output.insertFormatted("dword [rbp-{}]", .{operands[k]}),
                    .StackOffsetByte => try output.insertFormatted("byte [rbp-{}]", .{operands[k]}),
                    .BytePointer => {
                        try output.insertSlice("byte [");
                        try writeRegister(&output, @intToEnum(Register, operands[k]));
                        _ = try output.insert(']');
                    },
                }
            }
        }
    }
    return output;
}
