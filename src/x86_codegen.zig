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

const Context = struct {
    allocator: *Allocator,
    overload: *const Overload,
    x86: *X86,
    x86_block: *X86Block,
    ir: *const Ir,
    ir_block: *const IrBlock,
    stack: *Stack,
    entities: *Entities,
};

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

const Size = enum(u8) { Qword, Dword, Byte };

fn registerSize(reg: Register) Size {
    return switch (reg) {
        .Rax, .Rbx, .Rcx, .Rdx, .Rsp, .Rbp, .Rsi, .Rdi, .R8, .R9, .R10, .R11, .R12, .R13, .R14, .R15 => .Qword,
        .Eax, .Ebx, .Ecx, .Edx, .Esp, .Ebp, .Esi, .Edi, .R8d, .R9d, .R10d, .R11d, .R12d, .R13d, .R14d, .R15d => .Dword,
        .Al, .Ah, .Bl, .Bh, .Cl, .Ch, .Dl, .Dh, .Spl, .Bpl, .Sil, .Dil, .R8b, .R9b, .R10b, .R11b, .R12b, .R13b, .R14b, .R15b => .Byte,
    };
}

fn opRelativeCall(context: Context, lit: InternedString) !void {
    _ = try context.x86_block.instructions.insert(.Call);
    const operand_kinds = try context.allocator.alloc(Kind, 1);
    operand_kinds[0] = .RelativeLiteral;
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

fn opRegImmediate(context: Context, op: Instruction, to: Register, value: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Immediate;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = value;
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

fn sizeToKind(size: Size) Kind {
    return switch (size) {
        .Qword => .StackOffsetQword,
        .Dword => .StackOffsetDword,
        .Byte => .StackOffsetByte,
    };
}

fn opStackImmediate(context: Context, op: Instruction, size: Size, offset: usize, value: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = sizeToKind(size);
    operand_kinds[1] = .Immediate;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = offset;
    operands[1] = value;
    _ = try context.x86_block.operands.insert(operands);
}

fn opRegStack(context: Context, op: Instruction, reg: Register, offset: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = sizeToKind(registerSize(reg));
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

fn opStack(context: Context, op: Instruction, kind: Kind, offset: usize) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 1);
    operand_kinds[0] = kind;
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
    try opRegImmediate(context, .Sub, .Rsp, desired);
    context.stack.top += desired;
    return desired;
}

fn restoreStack(context: Context, offset: usize) !void {
    if (offset == 0) return;
    try opRegImmediate(context, .Add, .Rsp, offset);
    context.stack.top -= offset;
}

const RegisterAndSize = struct {
    register: Register,
    size: Size,
};

fn codegenBranch(context: Context, branch_index: usize, onReturn: fn (Context, Entity) error{OutOfMemory}!void) !void {
    const branch = context.ir_block.branches.items[context.ir_block.indices.items[branch_index]];
    const type_of = context.entities.types.get(branch.condition_entity).?;
    const register_and_size: RegisterAndSize = switch (type_of) {
        Int, I64 => .{ .register = .Rax, .size = .Qword },
        I32 => .{ .register = .Eax, .size = .Dword },
        U8 => .{ .register = .Al, .size = .Byte },
        else => unreachable,
    };
    const register = register_and_size.register;
    const size = register_and_size.size;
    if (context.entities.values.get(branch.condition_entity)) |value| {
        try opRegImmediate(context, .Mov, register, value);
        try opRegImmediate(context, .Cmp, register, 0);
    } else if (context.entities.literals.get(branch.condition_entity)) |literal| {
        try opRegLiteral(context, .Mov, register, literal);
        try opRegImmediate(context, .Cmp, register, 0);
    } else {
        const offset = context.stack.entity.get(branch.condition_entity).?;
        try opStackImmediate(context, .Cmp, size, offset, 0);
    }
    const else_x86_block_result = try context.x86.blocks.addOne();
    try opLabel(context, .Je, else_x86_block_result.index);
    const else_x86_block = else_x86_block_result.ptr;
    else_x86_block.instructions = List(Instruction).init(context.allocator);
    else_x86_block.operand_kinds = List([]const Kind).init(context.allocator);
    else_x86_block.operands = List([]const usize).init(context.allocator);
    var else_stack = context.stack.*;
    const else_context = Context{
        .allocator = context.allocator,
        .overload = context.overload,
        .x86 = context.x86,
        .x86_block = else_x86_block,
        .ir = context.ir,
        .ir_block = &context.overload.blocks.items[branch.else_block_index],
        .stack = &else_stack,
        .entities = context.entities,
    };
    const phi_x86_block_result = try context.x86.blocks.addOne();
    const phi_x86_block = phi_x86_block_result.ptr;
    phi_x86_block.instructions = List(Instruction).init(context.allocator);
    phi_x86_block.operand_kinds = List([]const Kind).init(context.allocator);
    phi_x86_block.operands = List([]const usize).init(context.allocator);
    for (context.overload.blocks.items[branch.then_block_index].kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Call => try codegenCall(context, i),
            .Jump => {
                const type_of_then = context.entities.types.get(branch.then_entity).?;
                switch (type_of_then) {
                    I32 => try moveToRegister(context, .Eax, branch.then_entity),
                    U8 => try moveToRegister(context, .Ah, branch.then_entity),
                    else => {
                        switch (context.entities.values.get(type_of_then).?) {
                            Array => try moveToRegister(context, .Rax, branch.then_entity),
                            else => unreachable,
                        }
                    },
                }
                try opLabel(context, .Jmp, phi_x86_block_result.index);
            },
            else => unreachable,
        }
    }
    for (else_context.ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Call => try codegenCall(else_context, i),
            .Jump => {
                const type_of_else = else_context.entities.types.get(branch.else_entity).?;
                switch (type_of_else) {
                    I32 => try moveToRegister(else_context, .Eax, branch.else_entity),
                    U8 => try moveToRegister(else_context, .Ah, branch.else_entity),
                    else => {
                        switch (context.entities.values.get(type_of_else).?) {
                            Array => try moveToRegister(else_context, .Rax, branch.else_entity),
                            else => unreachable,
                        }
                    },
                }
                try opLabel(else_context, .Jmp, phi_x86_block_result.index);
            },
            else => unreachable,
        }
    }
    var phi_stack = context.stack.*;
    const phi_context = Context{
        .allocator = context.allocator,
        .overload = context.overload,
        .x86 = context.x86,
        .x86_block = phi_x86_block,
        .ir = context.ir,
        .ir_block = &context.overload.blocks.items[branch.phi_block_index],
        .stack = &phi_stack,
        .entities = context.entities,
    };
    for (phi_context.ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Call => try codegenCall(phi_context, i),
            .Phi => {
                const phi_index = phi_context.ir_block.indices.items[i];
                const phi = phi_context.ir_block.phis.items[phi_context.ir_block.indices.items[phi_index]];
                const then_type = phi_context.entities.types.get(phi.then_entity).?;
                const else_type = phi_context.entities.types.get(phi.else_entity).?;
                switch (then_type) {
                    Int, I64 => {
                        assert(then_type == else_type);
                        phi_context.stack.top += 8;
                        const offset = phi_context.stack.top;
                        try phi_context.stack.entity.putNoClobber(phi.phi_entity, offset);
                        try opRegImmediate(phi_context, .Sub, .Rsp, 8);
                        try opStackReg(phi_context, .Mov, offset, .Rax);
                        try phi_context.entities.types.putNoClobber(phi.phi_entity, then_type);
                    },
                    I32 => {
                        assert(then_type == else_type);
                        phi_context.stack.top += 4;
                        const offset = phi_context.stack.top;
                        try phi_context.stack.entity.putNoClobber(phi.phi_entity, offset);
                        try opRegImmediate(phi_context, .Sub, .Rsp, 4);
                        try opStackReg(phi_context, .Mov, offset, .Eax);
                        try phi_context.entities.types.putNoClobber(phi.phi_entity, then_type);
                    },
                    U8 => {
                        assert(then_type == else_type);
                        phi_context.stack.top += 1;
                        const offset = phi_context.stack.top;
                        try phi_context.stack.entity.putNoClobber(phi.phi_entity, offset);
                        try opRegImmediate(phi_context, .Sub, .Rsp, 1);
                        try opStackReg(phi_context, .Mov, offset, .Ah);
                        try phi_context.entities.types.putNoClobber(phi.phi_entity, then_type);
                    },
                    else => {
                        const then_type_value = context.entities.values.get(then_type).?;
                        switch (then_type_value) {
                            Array => {
                                const else_type_value = context.entities.values.get(else_type).?;
                                assert(then_type_value == else_type_value);
                                phi_context.stack.top += 8;
                                const offset = phi_context.stack.top;
                                try phi_context.stack.entity.putNoClobber(phi.phi_entity, offset);
                                try opRegImmediate(phi_context, .Sub, .Rsp, 8);
                                try opStackReg(phi_context, .Mov, offset, .Rax);
                                try phi_context.entities.types.putNoClobber(phi.phi_entity, then_type);
                            },
                            else => unreachable,
                        }
                    },
                }
            },
            .Return => try onReturn(phi_context, branch.phi_entity),
            else => unreachable,
        }
    }
}

fn codegenPrintI64(context: Context, call: Call) !void {
    try moveToRegister(context, .Rsi, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%ld\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Lea, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opRelativeCall(context, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 4;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, result_offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenPrintI32(context: Context, call: Call) !void {
    try moveToRegister(context, .Esi, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%d\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Lea, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opRelativeCall(context, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 4;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, result_offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenPrintU8(context: Context, call: Call) !void {
    try moveToRegister(context, .Sil, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%c\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Lea, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opRelativeCall(context, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 4;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, result_offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenPrintF64(context: Context, call: Call) !void {
    try moveToSseRegister(context, .Xmm0, call.argument_entities[0]);
    const format_string = try internString(context.entities, "\"%f\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Lea, .Rdi, format_string);
    try opRegImmediate(context, .Mov, .Rax, 1);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opRelativeCall(context, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 4;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, result_offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
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
    try opRegByte(context, .Lea, .Rsi, null_terminated_string);
    try opRegByte(context, .Lea, .Rdi, format_string);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opRelativeCall(context, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 4;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, result_offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenPrintPtr(context: Context, call: Call, type_of: Entity) !void {
    const argument = call.argument_entities[0];
    const pointer_index = context.entities.pointer_index.get(type_of).?;
    assert(context.entities.pointers.items[pointer_index] == U8);
    const format_string = try internString(context.entities, "\"%s\", 10, 0");
    try insertUniqueId(&context.x86.bytes, format_string);
    try opRegByte(context, .Lea, .Rdi, format_string);
    const argument_offset = context.stack.entity.get(argument).?;
    try opRegStack(context, .Mov, .Rsi, argument_offset);
    try opRegReg(context, .Xor, .Rax, .Rax);
    const align_offset = try alignStackTo16Bytes(context);
    const printf = try internString(context.entities, "_printf");
    try context.x86.externs.insert(printf);
    try opRelativeCall(context, printf);
    try restoreStack(context, align_offset);
    context.stack.top += 4;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, result_offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
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
    if (context.entities.values.get(entity)) |value| {
        try opRegImmediate(context, .Mov, register, value);
        return;
    }
    if (context.entities.literals.get(entity)) |literal| {
        try opRegLiteral(context, .Mov, register, literal);
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

fn codegenGreaterI32I32(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Eax, lhs);
    if (context.entities.literals.get(rhs)) |value| {
        try opRegLiteral(context, .Cmp, .Eax, value);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opRegStack(context, .Cmp, .Eax, offset);
    } else {
        unreachable;
    }
    try opReg(context, .Setg, .Al);
    context.stack.top += 1;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    try opRegImmediate(context, .Sub, .Rsp, 1);
    try opStackReg(context, .Mov, offset, .Al);
    try context.entities.types.putNoClobber(call.result_entity, U8);
}

fn codegenGreater(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (context.entities.types.get(lhs).?) {
        Int, I32 => switch (context.entities.types.get(rhs).?) {
            Int, I32 => try codegenGreaterI32I32(context, call, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenBinaryOpI64I64(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
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
    try opRegImmediate(context, .Sub, .Rsp, 8);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenBinaryOpI32I32(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Eax, lhs);
    if (context.entities.literals.get(rhs)) |value| {
        assert(context.entities.types.get(rhs).? == @enumToInt(Builtins.Int));
        try opRegLiteral(context, op, .Eax, value);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opRegStack(context, op, .Eax, offset);
    } else {
        unreachable;
    }
    context.stack.top += 4;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenBinaryOpU8U8(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Al, lhs);
    if (context.entities.values.get(rhs)) |value| {
        try opRegImmediate(context, op, .Al, value);
    } else if (context.entities.literals.get(rhs)) |literal| {
        try opRegLiteral(context, op, .Al, literal);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opRegStack(context, op, .Al, offset);
    } else {
        unreachable;
    }
    context.stack.top += 1;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    try opRegImmediate(context, .Sub, .Rsp, 1);
    try opStackReg(context, .Mov, offset, .Al);
    try context.entities.types.putNoClobber(call.result_entity, U8);
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
    try opRegImmediate(context, .Sub, .Rsp, 8);
    try opStackSseReg(context, .Movsd, offset, .Xmm0);
    try context.entities.types.putNoClobber(call.result_entity, F64);
}

fn codegenBinaryOpPointerInt(context: Context, call: Call, op: Instruction, lhs: Entity, rhs: Entity) !void {
    assert(op == .Add or op == .Sub);
    const lhs_offset = context.stack.entity.get(lhs).?;
    try opRegStack(context, .Mov, .Rax, lhs_offset);
    if (context.entities.literals.get(rhs)) |value| {
        assert(context.entities.types.get(rhs).? == @enumToInt(Builtins.Int));
        try opRegLiteral(context, op, .Rax, value);
    } else if (context.stack.entity.get(rhs)) |rhs_offset| {
        try opRegStack(context, op, .Rax, rhs_offset);
    } else {
        unreachable;
    }
    context.stack.top += 8;
    const result_offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, result_offset);
    try opRegImmediate(context, .Sub, .Rsp, 8);
    try opStackReg(context, .Mov, result_offset, .Rax);
    const type_of = context.entities.next_entity;
    context.entities.next_entity += 1;
    try context.entities.types.putNoClobber(call.result_entity, type_of);
    try context.entities.values.putNoClobber(type_of, Ptr);
    const pointer_index = context.entities.pointer_index.get(context.entities.types.get(lhs).?).?;
    const index = try context.entities.pointers.insert(context.entities.pointers.items[pointer_index]);
    try context.entities.pointer_index.putNoClobber(type_of, index);
    try context.entities.types.putNoClobber(type_of, Type);
}

fn codegenBinaryOp(context: Context, call: Call, ops: BinaryOps) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    const lhs_type = context.entities.types.get(lhs).?;
    const rhs_type = context.entities.types.get(rhs).?;
    switch (lhs_type) {
        Int => switch (rhs_type) {
            Int, I64 => try codegenBinaryOpI64I64(context, call, ops.int, lhs, rhs),
            U8 => try codegenBinaryOpU8U8(context, call, ops.int, lhs, rhs),
            Float, F64 => try codegenBinaryOpFloatFloat(context, call, ops.float, lhs, rhs),
            else => unreachable,
        },
        I64 => switch (rhs_type) {
            Int, I64 => try codegenBinaryOpI64I64(context, call, ops.int, lhs, rhs),
            else => unreachable,
        },
        I32 => switch (rhs_type) {
            Int, I32 => try codegenBinaryOpI32I32(context, call, ops.int, lhs, rhs),
            else => unreachable,
        },
        U8 => switch (rhs_type) {
            Int, U8 => try codegenBinaryOpU8U8(context, call, ops.int, lhs, rhs),
            else => unreachable,
        },
        Float, F64 => switch (rhs_type) {
            Int, Float, F64 => try codegenBinaryOpFloatFloat(context, call, ops.float, lhs, rhs),
            else => unreachable,
        },
        else => {
            if (context.entities.values.get(lhs_type)) |value| {
                switch (value) {
                    Ptr => switch (rhs_type) {
                        Int => try codegenBinaryOpPointerInt(context, call, ops.int, lhs, rhs),
                        else => unreachable,
                    },
                    else => unreachable,
                }
            } else {
                unreachable;
            }
        },
    }
}

fn codegenDivideI64I64(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Rax, lhs);
    try opNoArgs(context.x86_block, .Cqo);
    if (context.entities.literals.get(rhs)) |value| {
        try opRegLiteral(context, .Mov, .Rcx, value);
        try opReg(context, .Idiv, .Rcx);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opStack(context, .Idiv, .StackOffsetQword, offset);
    } else {
        unreachable;
    }
    context.stack.top += 8;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    try opRegImmediate(context, .Sub, .Rsp, 8);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenDivideI32I32(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Eax, lhs);
    try opNoArgs(context.x86_block, .Cdq);
    if (context.entities.literals.get(rhs)) |value| {
        try opRegLiteral(context, .Mov, .Ecx, value);
        try opReg(context, .Idiv, .Ecx);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opStack(context, .Idiv, .StackOffsetDword, offset);
    } else {
        unreachable;
    }
    context.stack.top += 4;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
    try opStackReg(context, .Mov, offset, .Eax);
    try context.entities.types.putNoClobber(call.result_entity, I32);
}

fn codegenDivide(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (context.entities.types.get(lhs).?) {
        Int => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenDivideI64I64(context, call, lhs, rhs),
            Float, F64 => try codegenBinaryOpFloatFloat(context, call, .Divsd, lhs, rhs),
            else => unreachable,
        },
        I64 => switch (context.entities.types.get(rhs).?) {
            Int, I64 => try codegenDivideI64I64(context, call, lhs, rhs),
            else => unreachable,
        },
        I32 => switch (context.entities.types.get(rhs).?) {
            Int, I32 => try codegenDivideI32I32(context, call, lhs, rhs),
            else => unreachable,
        },
        Float, F64 => switch (context.entities.types.get(rhs).?) {
            Int, Float, F64 => try codegenBinaryOpFloatFloat(context, call, .Divsd, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenEqualU8(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Al, lhs);
    if (context.entities.values.get(rhs)) |value| {
        try opRegImmediate(context, .Cmp, .Al, value);
    } else if (context.entities.literals.get(rhs)) |literal| {
        try opRegLiteral(context, .Cmp, .Al, literal);
    } else if (context.stack.entity.get(rhs)) |offset| {
        try opRegStack(context, .Cmp, .Al, offset);
    } else {
        unreachable;
    }
    try opReg(context, .Sete, .Al);
    context.stack.top += 1;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    try opRegImmediate(context, .Sub, .Rsp, 1);
    try opStackReg(context, .Mov, offset, .Al);
    try context.entities.types.putNoClobber(call.result_entity, U8);
}

fn codegenEqual(context: Context, call: Call) !void {
    assert(call.argument_entities.len == 2);
    const lhs = call.argument_entities[0];
    const rhs = call.argument_entities[1];
    switch (context.entities.types.get(lhs).?) {
        Int => switch (context.entities.types.get(rhs).?) {
            U8 => try codegenEqualU8(context, call, lhs, rhs),
            else => unreachable,
        },
        U8 => switch (context.entities.types.get(rhs).?) {
            Int, U8 => try codegenEqualU8(context, call, lhs, rhs),
            else => unreachable,
        },
        else => unreachable,
    }
}

fn codegenBitOrI64(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Rax, lhs);
    if (context.entities.literals.get(rhs)) |value| {
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
    try opRegImmediate(context, .Sub, .Rsp, 8);
    try opStackReg(context, .Mov, offset, .Rax);
    try context.entities.types.putNoClobber(call.result_entity, I64);
}

fn codegenBitOrI32(context: Context, call: Call, lhs: Entity, rhs: Entity) !void {
    try moveToRegister(context, .Eax, lhs);
    if (context.entities.literals.get(rhs)) |value| {
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
    try opRegImmediate(context, .Sub, .Rsp, 4);
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
    try opRegByte(context, .Lea, .Rdi, null_terminated_string);
    const oflag = call.argument_entities[1];
    assert(context.entities.types.get(oflag).? == I32 or context.entities.types.get(oflag).? == Int);
    try moveToRegister(context, .Esi, oflag);
    try opRegReg(context, .Xor, .Rdx, .Rdx);
    try opNoArgs(context.x86_block, .Syscall);
    context.stack.top += 4;
    const offset = context.stack.top;
    try context.stack.entity.putNoClobber(call.result_entity, offset);
    try opRegImmediate(context, .Sub, .Rsp, 4);
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
    try opRegImmediate(context, .Sub, .Rsp, 8);
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
    try opRegImmediate(context, .Sub, .Rsp, 8);
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
    try opRegImmediate(context, .Sub, .Rsp, 4);
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
    try opRegImmediate(context, .Sub, .Rsp, 8);
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
    try opRegImmediate(context, .Sub, .Rsp, 4);
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
    try opRegImmediate(context, .Sub, .Rsp, 1);
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
                Int, I64, I32, U8 => try context.entities.types.put(typed_let.entity, typed_let.type_entity),
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
                        try opRegImmediate(context, .Sub, .Rsp, 8);
                        try opRegByte(context, .Lea, .Rdi, null_terminated_string);
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

const qword_registers = [_]Register{ .Rdi, .Rsi, .Rdx, .Rcx, .R8, .R9 };
const dword_registers = [_]Register{ .Edi, .Esi, .Edx, .Ecx, .R8d, .R9d };
const byte_registers = [_]Register{ .Dil, .Sil, .Dh, .Ch, .R8b, .R9b };
const xmm_registers = [_]SseRegister{ .Xmm0, .Xmm1, .Xmm2, .Xmm3, .Xmm4, .Xmm5 };

fn codegenReturn(context: Context, ret: Entity) !void {
    const return_type = context.entities.types.get(ret).?;
    if (context.stack.entity.get(ret)) |offset| {
        switch (return_type) {
            I64 => try opRegStack(context, .Mov, .Rax, offset),
            I32 => try opRegStack(context, .Mov, .Eax, offset),
            U8 => try opRegStack(context, .Mov, .Ah, offset),
            F64 => try opSseRegStack(context, .Movsd, .Xmm0, offset),
            else => unreachable,
        }
    } else if (context.entities.literals.get(ret)) |value| {
        switch (return_type) {
            I64 => try opRegLiteral(context, .Mov, .Rax, value),
            F64 => {
                try insertUniqueId(&context.x86.quad_words, value);
                try opSseRegRelQuadWord(context, .Movsd, .Xmm0, value);
            },
            else => unreachable,
        }
    } else {
        unreachable;
    }
    if (context.stack.top > 0) {
        try opRegImmediate(context, .Add, .Rsp, context.stack.top);
    }
    try opReg(context, .Pop, .Rbp);
    try opNoArgs(context.x86_block, .Ret);
}

fn codegenCall(context: Context, call_index: usize) error{OutOfMemory}!void {
    const call = context.ir_block.calls.items[context.ir_block.indices.items[call_index]];
    const name = context.entities.names.get(call.function_entity).?;
    switch (name) {
        @enumToInt(Builtins._add_) => try codegenBinaryOp(context, call, AddOps),
        @enumToInt(Builtins._sub_) => try codegenBinaryOp(context, call, SubOps),
        @enumToInt(Builtins._mul_) => try codegenBinaryOp(context, call, MulOps),
        @enumToInt(Builtins._div_) => try codegenDivide(context, call),
        @enumToInt(Builtins._eql_) => try codegenEqual(context, call),
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
        @enumToInt(Builtins._greater_) => try codegenGreater(context, call),
        else => {
            const index = lbl: {
                if (context.ir.name_to_index.get(name)) |i| {
                    break :lbl i;
                } else {
                    const literal = context.entities.interned_strings.data.items[name];
                    std.debug.print(
                        \\
                        \\
                        \\
                        \\-- NAMING ERROR ------------------------
                        \\
                        \\Cannot find function `{s}`
                        \\
                        \\
                        \\
                    , .{literal});
                    unreachable;
                }
            };
            assert(context.ir.kinds.items[index] == DeclarationKind.Function);
            const function = &context.ir.functions.items[context.ir.indices.items[index]];
            assert(function.overloads.length == 1);
            const overload = &function.overloads.items[0];
            const overload_index = context.entities.overload_index.get(function.entities.items[0]).?;
            if (context.entities.overloads.status.items[overload_index] == .Unanalyzed) {
                const type_block_indices = overload.parameter_type_block_indices;
                assert(type_block_indices.len == call.argument_entities.len);
                const parameter_entities = overload.parameter_entities;
                const parameter_types = try context.allocator.alloc(Entity, parameter_entities.len);
                for (type_block_indices) |type_block_index, argument_index| {
                    assert(argument_index < qword_registers.len);
                    const type_block = &overload.blocks.items[type_block_index];
                    assert(type_block.kinds.length == 1);
                    assert(type_block.kinds.items[0] == .Return);
                    const parameter_type = type_block.returns.items[type_block.indices.items[0]];
                    const argument_entity = call.argument_entities[argument_index];
                    const argument_type = context.entities.types.get(argument_entity).?;
                    switch (parameter_type) {
                        I64 => {
                            assert(argument_type == Int or argument_type == I64);
                            try moveToRegister(context, qword_registers[argument_index], argument_entity);
                        },
                        I32 => {
                            assert(argument_type == Int or argument_type == I32);
                            try moveToRegister(context, dword_registers[argument_index], argument_entity);
                        },
                        U8 => {
                            assert(argument_type == Int or argument_type == U8);
                            try moveToRegister(context, byte_registers[argument_index], argument_entity);
                        },
                        F64 => {
                            assert(argument_type == Int or argument_type == Float or argument_type == F64);
                            try moveToSseRegister(context, xmm_registers[argument_index], argument_entity);
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
                const size_of = context.entities.sizes.get(return_type).?;
                try opRegImmediate(context, .Sub, .Rsp, size_of);
                context.stack.top += size_of;
                try context.stack.entity.putNoClobber(call.result_entity, context.stack.top);
                switch (return_type) {
                    I64 => try opStackReg(context, .Mov, context.stack.top, .Rax),
                    I32 => try opStackReg(context, .Mov, context.stack.top, .Eax),
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
                };
                try opReg(overload_context, .Push, .Rbp);
                try opRegReg(overload_context, .Mov, .Rbp, .Rsp);
                const parameter_offsets = try context.allocator.alloc(usize, parameter_entities.len);
                var parameter_offset: usize = 0;
                for (parameter_types) |parameter_type, i| {
                    parameter_offset += context.entities.sizes.get(parameter_type).?;
                    parameter_offsets[i] = parameter_offset;
                }
                overload_context.stack.top = parameter_offset;
                try opRegImmediate(overload_context, .Sub, .Rsp, parameter_offset);
                for (parameter_entities) |parameter_entity, i| {
                    const offset = parameter_offsets[i];
                    switch (parameter_types[i]) {
                        I64 => try opStackReg(overload_context, .Mov, offset, qword_registers[i]),
                        I32 => try opStackReg(overload_context, .Mov, offset, dword_registers[i]),
                        U8 => try opStackReg(overload_context, .Mov, offset, byte_registers[i]),
                        F64 => try opStackSseReg(overload_context, .Movsd, offset, xmm_registers[i]),
                        else => unreachable,
                    }
                    try overload_context.stack.entity.putNoClobber(parameter_entity, offset);
                }
                for (overload_context.ir_block.kinds.slice()) |expression_kind, i| {
                    switch (expression_kind) {
                        .Return => {
                            const ret = overload_context.ir_block.returns.items[overload_context.ir_block.indices.items[i]];
                            try codegenReturn(overload_context, ret);
                        },
                        .Call => try codegenCall(overload_context, i),
                        .TypedLet => try codegenTypedLet(overload_context, i),
                        .CopyingLet => try codegenCopyingLet(overload_context, i),
                        .CopyingTypedLet => try codegenCopyingTypedLet(overload_context, i),
                        .Branch => try codegenBranch(overload_context, i, codegenReturn),
                        else => unreachable,
                    }
                }
            } else {
                const parameter_types = context.entities.overloads.parameter_types.items[overload_index];
                assert(parameter_types.len == call.argument_entities.len);
                for (parameter_types) |parameter_type, argument_index| {
                    assert(argument_index < qword_registers.len);
                    const argument_entity = call.argument_entities[argument_index];
                    const argument_type = context.entities.types.get(argument_entity).?;
                    switch (parameter_type) {
                        I64 => {
                            assert(argument_type == Int or argument_type == I64);
                            try moveToRegister(context, qword_registers[argument_index], argument_entity);
                        },
                        I32 => {
                            assert(argument_type == Int or argument_type == I32);
                            try moveToRegister(context, dword_registers[argument_index], argument_entity);
                        },
                        F64 => {
                            assert(argument_type == Int or argument_type == Float or argument_type == F64);
                            try moveToSseRegister(context, xmm_registers[argument_index], argument_entity);
                        },
                        else => unreachable,
                    }
                }
                const block_index = context.entities.overloads.block.items[overload_index];
                const align_offset = try alignStackTo16Bytes(context);
                try opLabel(context, .Call, block_index);
                try restoreStack(context, align_offset);
                const return_type = context.entities.overloads.return_type.items[overload_index];
                const size_of = context.entities.sizes.get(return_type).?;
                try opRegImmediate(context, .Sub, .Rsp, size_of);
                context.stack.top += size_of;
                try context.stack.entity.putNoClobber(call.result_entity, context.stack.top);
                switch (return_type) {
                    I32 => try opStackReg(context, .Mov, context.stack.top, .Eax),
                    I64 => try opStackReg(context, .Mov, context.stack.top, .Rax),
                    F64 => try opStackSseReg(context, .Movsd, context.stack.top, .Xmm0),
                    else => unreachable,
                }
                try context.entities.types.putNoClobber(call.result_entity, return_type);
            }
        },
    }
}

fn codegenSysExit(context: Context, ret: Entity) !void {
    assert(context.entities.types.get(ret).? == I32 or context.entities.types.get(ret).? == Int);
    if (context.stack.entity.get(ret)) |offset| {
        try opRegStack(context, .Mov, .Edi, offset);
    } else if (context.entities.literals.get(ret)) |value| {
        try opRegLiteral(context, .Mov, .Edi, value);
    } else {
        unreachable;
    }
    const sys_exit = try internString(context.entities, "0x02000001");
    try opRegLiteral(context, .Mov, .Rax, sys_exit);
    try opNoArgs(context.x86_block, .Syscall);
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
    var context = Context{
        .allocator = allocator,
        .overload = overload,
        .x86 = x86,
        .x86_block = x86_block,
        .ir = &ir,
        .ir_block = &overload.blocks.items[overload.body_block_index],
        .stack = &stack,
        .entities = entities,
    };
    try opReg(context, .Push, .Rbp);
    try opRegReg(context, .Mov, .Rbp, .Rsp);
    const kinds = context.ir_block.kinds.slice();

    for (kinds) |expression_kind, i| {
        switch (expression_kind) {
            .Return => {
                const ret = context.ir_block.returns.items[context.ir_block.indices.items[i]];
                try codegenSysExit(context, ret);
            },
            .Call => try codegenCall(context, i),
            .TypedLet => try codegenTypedLet(context, i),
            .CopyingLet => try codegenCopyingLet(context, i),
            .CopyingTypedLet => try codegenCopyingTypedLet(context, i),
            .Branch => try codegenBranch(context, i, codegenSysExit),
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
        .Lea => try output.insertSlice("lea"),
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
        .And => try output.insertSlice("and"),
        .Cmp => try output.insertSlice("cmp"),
        .Je => try output.insertSlice("je"),
        .Jmp => try output.insertSlice("jmp"),
        .Sete => try output.insertSlice("sete"),
        .Setg => try output.insertSlice("setg"),
        .Call => try output.insertSlice("call"),
        .Syscall => try output.insertSlice("syscall"),
        .Cqo => try output.insertSlice("cqo"),
        .Cdq => try output.insertSlice("cdq"),
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
    try output.insertSlice(
        \\    default rel
        \\    global _main
        \\
    );
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
                    .RelativeLiteral => try output.insertFormatted("[{s} wrt ..gotpcrel]", .{entities.interned_strings.data.items[operands[k]]}),
                    .Byte => try output.insertFormatted("[byte{}]", .{x86.bytes.string_to_index.get(operands[k]).?}),
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
