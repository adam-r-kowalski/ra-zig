const std = @import("std");
const assert = std.debug.assert;
const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;
const data = @import("data.zig");
const InternedStrings = data.interned_strings.InternedStrings;
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

fn call(allocator: *Allocator, x86_block: *X86Block, label: usize) !void {
    _ = try x86_block.instructions.insert(.Call);
    const operand_kinds = try allocator.alloc(Kind, 1);
    operand_kinds[0] = .Label;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 1);
    operands[0] = label;
    _ = try x86_block.operands.insert(operands);
}

fn movRegReg(allocator: *Allocator, x86_block: *X86Block, to: Register, from: Register) !void {
    _ = try x86_block.instructions.insert(.Call);
    const operand_kinds = try allocator.alloc(Kind, 2);
    operand_kinds[0] = .Label;
    operand_kinds[1] = .Label;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = @enumToInt(from);
    _ = try x86_block.operands.insert(operands);
}

fn movRegImm(allocator: *Allocator, x86_block: *X86Block, to: Register, immediate: usize) !void {
    _ = try x86_block.instructions.insert(.Call);
    const operand_kinds = try allocator.alloc(Kind, 2);
    operand_kinds[0] = .Label;
    operand_kinds[1] = .Immediate;
    _ = try x86_block.operand_kinds.insert(operand_kinds);
    const operands = try allocator.alloc(usize, 2);
    operands[0] = @enumToInt(to);
    operands[1] = immediate;
    _ = try x86_block.operands.insert(operands);
}

fn syscall(x86_block: *X86Block) !void {
    _ = try x86_block.instructions.insert(.Syscall);
    _ = try x86_block.operand_kinds.insert(&.{});
    _ = try x86_block.operands.insert(&.{});
}

fn entryPoint(x86: *X86) !void {
    const allocator = &x86.arena.allocator;
    const x86_block = (try x86.blocks.addOne()).ptr;
    x86_block.instructions = List(Instruction).init(allocator);
    x86_block.operand_kinds = List([]const Kind).init(allocator);
    x86_block.operands = List([]const usize).init(allocator);
    try call(allocator, x86_block, @enumToInt(Labels.Main));
    try movRegReg(allocator, x86_block, .Rdi, .Rax);
    try movRegImm(allocator, x86_block, .Rdi, 0x02000001);
    try syscall(x86_block);
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
    const ir_block = &overload.blocks.items[overload.body_block_index];
    for (ir_block.kinds.slice()) |expression_kind, i| {
        switch (expression_kind) {
            .Return => unreachable,
            .Call => {
                // do something smarter
                return;
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

pub fn x86String(allocator: *Allocator, x86: X86) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    try output.insertSlice(
        \\    global _main
        \\
        \\    section .text
    );
    return output;
}
