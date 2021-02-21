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

const Label = usize;
const Immediate = usize;

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
    try opRegImm(allocator, x86_block, .Mov, .Rdi, 0x02000001);
    try opNoArgs(x86_block, .Syscall);
}

fn main(x86: *X86, ir: Ir, interned_strings: InternedStrings) !void {
    const name = interned_strings.mapping.get("main").?;
    const index = ir.name_to_index.get(name).?;
    const declaration_kind = ir.kinds.items[index];
    assert(declaration_kind == DeclarationKind.Function);
    assert(name == ir.names.items[index]);
    const overloads = &ir.functions.items[ir.indices.items[index]];
    assert(overloads.length == 1);
    const overload = &overloads.items[0];
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
                        const rdx_value = overload.entities.values.get(call.argument_entities[0]).?;
                        try opRegLiteral(allocator, x86_block, .Mov, .Rdx, rdx_value);
                        const rax_value = overload.entities.values.get(call.argument_entities[0]).?;
                        try opRegLiteral(allocator, x86_block, .Mov, .Rax, rax_value);
                        try opRegReg(allocator, x86_block, .Add, .Rax, .Rdx);
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

pub fn x86String(allocator: *Allocator, x86: X86, interned_strings: InternedStrings) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    try output.insertSlice(
        \\    global _main
        \\
        \\    section .text
    );
    return output;
}
