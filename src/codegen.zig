const std = @import("std");
const assert = std.debug.assert;
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const data = @import("data.zig");
const InternedStrings = data.interned_strings.InternedStrings;
const InternedString = data.interned_strings.InternedString;
const Strings = data.interned_strings.Strings;
const DeclarationKind = data.ir.DeclarationKind;
const IrBlock = data.ir.Block;
const Ir = data.ir.Ir;
const X86 = data.x86.X86;
const X86Block = data.x86.Block;
const Instruction = data.x86.Instruction;
const Kind = data.x86.Kind;
const Register = data.x86.Register;
const List = data.List;
const Map = data.Map;
const Overload = data.ir.Overload;
const Call = data.ir.Call;
const Label = usize;
const Immediate = usize;
const Entity = usize;

const RegisterMap = struct {
    entity_to_register: Map(Entity, Register),
    register_to_entity: Map(Register, Entity),
    free_registers: [14]Register,
    length: u8,
};

fn pushFreeRegister(register_map: *RegisterMap, register: Register) void {
    const n = register_map.free_registers.len;
    assert(register_map.length < n);
    register_map.length += 1;
    register_map.free_registers[n - register_map.length] = register;
}

fn popFreeRegister(register_map: *RegisterMap) Register {
    const n = register_map.free_registers.len;
    assert(register_map.length > 0);
    const register = register_map.free_registers[n - register_map.length];
    register_map.length -= 1;
    return register;
}

const Context = struct {
    allocator: *Allocator,
    overload: *const Overload,
    x86_block: *X86Block,
    register_map: *RegisterMap,
};

fn opLabel(context: Context, op: Instruction, label: Label) !void {
    _ = try x86_block.instructions.insert(op);
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

fn opRegImm(context: Context, op: Instruction, to: Register, imm: Immediate) !void {
    _ = try context.x86_block.instructions.insert(op);
    const operand_kinds = try context.allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Immediate;
    _ = try context.x86_block.operand_kinds.insert(operand_kinds);
    const operands = try context.allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = imm;
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
    const register = popFreeRegister(context.register_map);
    try opRegLiteral(context, .Mov, register, value);
    try context.register_map.entity_to_register.put(entity, register);
    try context.register_map.register_to_entity.put(register, entity);
    return register;
}

fn moveEntityToSpecificRegister(context: Context, entity: Entity, register: Register) !void {
    if (context.register_map.register_to_entity.get(register)) |entity_in_register| {
        if (entity_in_register == entity) return;
        const free_register = popFreeRegister(context.register_map);
        try opRegReg(context, .Mov, free_register, register);
        try context.register_map.entity_to_register.put(entity_in_register, free_register);
        try context.register_map.register_to_entity.put(free_register, entity_in_register);
    } else {
        const length = context.register_map.length - 1;
        for (context.register_map.free_registers[0..length]) |current_register, i| {
            if (current_register == register) {
                context.register_map.free_registers[i] = context.register_map.free_registers[length];
                context.register_map.free_registers[length] = context.register_map.free_registers[i];
            }
        }
        context.register_map.length = length;
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
    try context.register_map.register_to_entity.put(register, entity);
}

fn signedIntegerBinaryOperation(context: Context, call: Call, op: Instruction) !void {
    assert(call.argument_entities.len == 2);
    const lhs_entity = call.argument_entities[0];
    const lhs_register = try moveEntityToRegister(context, lhs_entity);
    const rhs_entity = call.argument_entities[1];
    const rhs_register = try moveEntityToRegister(context, rhs_entity);
    try opRegReg(context, op, lhs_register, rhs_register);
    try context.register_map.entity_to_register.put(call.result_entity, lhs_register);
    try context.register_map.register_to_entity.put(lhs_register, call.result_entity);
    context.register_map.entity_to_register.removeAssertDiscard(rhs_entity);
}

fn main(x86: *X86, ir: Ir, interned_strings: InternedStrings) !void {
    var register_map = RegisterMap{
        .entity_to_register = Map(Entity, Register).init(&x86.arena.allocator),
        .register_to_entity = Map(Register, Entity).init(&x86.arena.allocator),
        .free_registers = .{
            .Rax, .Rbx, .Rcx, .Rdx, .Rsi, .Rdi, .R8,
            .R9,  .R10, .R11, .R12, .R13, .R14, .R15,
        },
        .length = 14,
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
    const context = Context{
        .allocator = allocator,
        .overload = &overloads.items[0],
        .x86_block = x86_block,
        .register_map = &register_map,
    };
    try opReg(context, .Push, .Rbp);
    try opRegReg(context, .Mov, .Rbp, .Rsp);
    const ir_block = &context.overload.blocks.items[context.overload.body_block_index];
    for (ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Return => {
                const ret = ir_block.returns.items[ir_block.indices.items[i]];
                const reg = register_map.entity_to_register.get(ret).?;
                if (reg != .Rax) try opRegReg(context, .Mov, .Rax, reg);
                try opReg(context, .Pop, .Rbp);
                try opNoArgs(x86_block, .Ret);
            },
            .Call => {
                const call = ir_block.calls.items[ir_block.indices.items[i]];
                switch (context.overload.entities.names.get(call.function_entity).?) {
                    @enumToInt(Strings.Add) => try signedIntegerBinaryOperation(context, call, .Add),
                    @enumToInt(Strings.Subtract) => try signedIntegerBinaryOperation(context, call, .Sub),
                    @enumToInt(Strings.Multiply) => try signedIntegerBinaryOperation(context, call, .Imul),
                    @enumToInt(Strings.Divide) => {
                        assert(call.argument_entities.len == 2);
                        const lhs_entity = call.argument_entities[0];
                        const lhs_register = .Rax;
                        try moveEntityToSpecificRegister(context, lhs_entity, lhs_register);
                        const rhs_entity = call.argument_entities[1];
                        var rhs_register = try moveEntityToRegister(context, rhs_entity);
                        if (register_map.register_to_entity.get(.Rdx)) |entity| {
                            const register = popFreeRegister(&register_map);
                            try opRegReg(context, .Mov, register, .Rdx);
                            try register_map.register_to_entity.put(register, entity);
                            try register_map.entity_to_register.put(entity, register);
                            if (entity == rhs_entity) rhs_register = register;
                        }
                        try opNoArgs(x86_block, .Cqo);
                        try opReg(context, .Idiv, rhs_register);
                        try context.register_map.entity_to_register.put(call.result_entity, lhs_register);
                        try context.register_map.register_to_entity.put(lhs_register, call.result_entity);
                        context.register_map.entity_to_register.removeAssertDiscard(rhs_entity);
                    },
                    else => unreachable,
                }
            },
            .Branch => unreachable,
            .Phi => unreachable,
            .Jump => unreachable,
        }
    }
}

pub fn codegen(allocator: *Allocator, ir: Ir, interned_strings: InternedStrings) !X86 {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    var x86 = X86{
        .arena = arena,
        .blocks = List(X86Block).init(&arena.allocator),
    };
    try main(&x86, ir, interned_strings);
    return x86;
}

fn writeLabel(output: *List(u8), label: Label) !void {
    try output.insertFormatted("label{}", .{label});
}

fn writeInstruction(output: *List(u8), instruction: Instruction) !void {
    switch (instruction) {
        .Mov => try output.insertSlice("mov"),
        .Push => try output.insertSlice("push"),
        .Pop => try output.insertSlice("pop"),
        .Add => try output.insertSlice("add"),
        .Sub => try output.insertSlice("sub"),
        .Imul => try output.insertSlice("imul"),
        .Idiv => try output.insertSlice("idiv"),
        .Call => try output.insertSlice("call"),
        .Syscall => try output.insertSlice("syscall"),
        .Cqo => try output.insertSlice("cqo"),
        .Ret => try output.insertSlice("ret"),
    }
}

fn writeRegister(output: *List(u8), register: Register) !void {
    switch (register) {
        Register.Rax => try output.insertSlice("rax"),
        Register.Rbx => try output.insertSlice("rbx"),
        Register.Rcx => try output.insertSlice("rcx"),
        Register.Rdx => try output.insertSlice("rdx"),
        Register.Rbp => try output.insertSlice("rbp"),
        Register.Rsp => try output.insertSlice("rsp"),
        Register.Rsi => try output.insertSlice("rsi"),
        Register.Rdi => try output.insertSlice("rdi"),
        Register.R8 => try output.insertSlice("r8"),
        Register.R9 => try output.insertSlice("r9"),
        Register.R10 => try output.insertSlice("r10"),
        Register.R11 => try output.insertSlice("r11"),
        Register.R12 => try output.insertSlice("r12"),
        Register.R13 => try output.insertSlice("r13"),
        Register.R14 => try output.insertSlice("r14"),
        Register.R15 => try output.insertSlice("r15"),
    }
}

pub fn x86String(allocator: *Allocator, x86: X86, interned_strings: InternedStrings) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    try output.insertSlice(
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
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
                    .Label => try writeLabel(&output, operands[k]),
                    .Literal => try output.insertSlice(interned_strings.data.items[operands[k]]),
                }
            }
        }
    }
    return output;
}
