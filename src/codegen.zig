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
const Labels = data.x86.Labels;
const Instruction = data.x86.Instruction;
const Kind = data.x86.Kind;
const Register = data.x86.Register;
const List = data.List;
const Map = data.Map;
const Overload = data.ir.Overload;
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
    register_map.registers[n - register_map.length] = register;
}

fn popFreeRegister(register_map: *RegisterMap) Register {
    const n = register_map.free_registers.len;
    assert(register_map.length > 0);
    const register = register_map.free_registers[n - register_map.length];
    register_map.length -= 1;
    return register;
}

fn opLabel(allocator: *Allocator, x86_block: *X86Block, op: Instruction, label: Label) !void {
    _ = try x86_block.instructions.insert(op);
    const operand_kinds = try allocator.alloc(Kind, 1);
    operand_kinds[0] = .Label;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 1);
    operands[0] = label;
    _ = try x86_block.operands.insert(operands);
}

fn opRegReg(allocator: *Allocator, x86_block: *X86Block, op: Instruction, to: Register, from: Register) !void {
    _ = try x86_block.instructions.insert(op);
    const operand_kinds = try allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Register;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = @enumToInt(from);
    _ = try x86_block.operands.insert(operands);
}

fn opRegImm(allocator: *Allocator, x86_block: *X86Block, op: Instruction, to: Register, imm: Immediate) !void {
    _ = try x86_block.instructions.insert(op);
    const operand_kinds = try allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Immediate;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = imm;
    _ = try x86_block.operands.insert(operands);
}

fn opRegLiteral(allocator: *Allocator, x86_block: *X86Block, op: Instruction, to: Register, lit: InternedString) !void {
    _ = try x86_block.instructions.insert(op);
    const operand_kinds = try allocator.alloc(Kind, 2);
    operand_kinds[0] = .Register;
    operand_kinds[1] = .Literal;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = lit;
    _ = try x86_block.operands.insert(operands);
}

fn opReg(allocator: *Allocator, x86_block: *X86Block, op: Instruction, reg: Register) !void {
    _ = try x86_block.instructions.insert(op);
    const operand_kinds = try allocator.alloc(Kind, 1);
    operand_kinds[0] = .Register;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 1);
    operands[0] = @enumToInt(reg);
    _ = try x86_block.operands.insert(operands);
}

fn opNoArgs(x86_block: *X86Block, op: Instruction) !void {
    _ = try x86_block.instructions.insert(op);
    _ = try x86_block.operand_kinds.insert(&.{});
    _ = try x86_block.operands.insert(&.{});
}

fn entryPoint(x86: *X86) !void {
    const allocator = &x86.arena.allocator;
    const x86_block = (try x86.blocks.addOne()).ptr;
    x86_block.instructions = List(Instruction).init(allocator);
    x86_block.operand_kinds = List([]const Kind).init(allocator);
    x86_block.operands = List([]const usize).init(allocator);
    try opLabel(allocator, x86_block, .Call, @enumToInt(Labels.Main));
    try opRegReg(allocator, x86_block, .Mov, .Rdi, .Rax);
    try opRegImm(allocator, x86_block, .Mov, .Rax, 0x02000001);
    try opNoArgs(x86_block, .Syscall);
}

fn moveEntityToRegister(allocator: *Allocator, overload: Overload, x86_block: *X86Block, register_map: *RegisterMap, entity: Entity) !Register {
    if (register_map.entity_to_register.get(entity)) |register| return register;
    const value = overload.entities.values.get(entity).?;
    const register = popFreeRegister(register_map);
    try opRegLiteral(allocator, x86_block, .Mov, register, value);
    try register_map.entity_to_register.put(entity, register);
    try register_map.register_to_entity.put(register, entity);
    return register;
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
    const overload = overloads.items[0];
    const allocator = &x86.arena.allocator;
    const x86_block = (try x86.blocks.addOne()).ptr;
    x86_block.instructions = List(Instruction).init(allocator);
    x86_block.operand_kinds = List([]const Kind).init(allocator);
    x86_block.operands = List([]const usize).init(allocator);
    try opReg(allocator, x86_block, .Push, .Rbp);
    try opRegReg(allocator, x86_block, .Mov, .Rbp, .Rsp);
    const ir_block = &overload.blocks.items[overload.body_block_index];
    for (ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Return => {
                try opReg(allocator, x86_block, .Pop, .Rbp);
                try opNoArgs(x86_block, .Ret);
            },
            .Call => {
                const call = ir_block.calls.items[ir_block.indices.items[i]];
                switch (overload.entities.names.get(call.function_entity).?) {
                    @enumToInt(Strings.Add) => {
                        assert(call.argument_entities.len == 2);
                        const lhs_reg = try moveEntityToRegister(allocator, overload, x86_block, &register_map, call.argument_entities[0]);
                        const rhs_entity = call.argument_entities[1];
                        const rhs_reg = try moveEntityToRegister(allocator, overload, x86_block, &register_map, rhs_entity);
                        try opRegReg(allocator, x86_block, .Add, lhs_reg, rhs_reg);
                        try register_map.entity_to_register.put(call.result_entity, lhs_reg);
                        try register_map.register_to_entity.put(lhs_reg, call.result_entity);
                        register_map.entity_to_register.removeAssertDiscard(rhs_entity);
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
    try entryPoint(&x86);
    try main(&x86, ir, interned_strings);
    return x86;
}

fn writeLabel(output: *List(u8), label: Label) !void {
    switch (label) {
        @enumToInt(Labels.EntryPoint) => try output.insertSlice("_main"),
        @enumToInt(Labels.Main) => try output.insertSlice("main"),
        else => unreachable,
    }
}

fn writeInstruction(output: *List(u8), instruction: Instruction) !void {
    switch (instruction) {
        .Mov => try output.insertSlice("mov"),
        .Push => try output.insertSlice("push"),
        .Pop => try output.insertSlice("pop"),
        .Add => try output.insertSlice("add"),
        .Call => try output.insertSlice("call"),
        .Syscall => try output.insertSlice("syscall"),
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
