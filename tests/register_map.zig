const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const lang = @import("lang");
const RegisterMap = lang.data.RegisterMap;
const pushFreeRegister = lang.register_map.pushFreeRegister;
const popFreeRegister = lang.register_map.popFreeRegister;
const initRegisterMap = lang.register_map.initRegisterMap;
const deinitRegisterMap = lang.register_map.deinitRegisterMap;
const Register = lang.data.x86.Register;

test "prefer callee saved registers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var register_map = try initRegisterMap(allocator);
    defer deinitRegisterMap(&register_map);
    const n = lang.register_map.total_available_registers;
    var registers: [n]Register = undefined;
    var i: usize = 0;
    while (i < n) : (i += 1)
        registers[i] = popFreeRegister(&register_map).?;
    expectEqual(registers, .{
        .Rbx, .R12, .R13, .R14, .R15, .Rax, .Rcx,
        .Rdx, .Rsi, .Rdi, .R8,  .R9,  .R10, .R11,
    });
    expectEqual(popFreeRegister(&register_map), null);
}

test "pop caller saved registers in reverse order as pushed" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var register_map = try initRegisterMap(allocator);
    defer deinitRegisterMap(&register_map);
    {
        const n = lang.register_map.total_available_registers;
        var i: usize = 0;
        while (i < n) : (i += 1)
            _ = popFreeRegister(&register_map).?;
    }
    for (lang.register_map.caller_saved_registers) |register|
        pushFreeRegister(&register_map, register);
    {
        const n = lang.register_map.caller_saved_registers.len;
        var registers: [n]Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = popFreeRegister(&register_map).?;
        expectEqual(registers, .{ .R11, .R10, .R9, .R8, .Rdi, .Rsi, .Rdx, .Rcx, .Rax });
        expectEqual(popFreeRegister(&register_map), null);
    }
}

test "pop callee saved registers in reverse order as pushed" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var register_map = try initRegisterMap(allocator);
    defer deinitRegisterMap(&register_map);
    {
        const n = lang.register_map.total_available_registers;
        var i: usize = 0;
        while (i < n) : (i += 1)
            _ = popFreeRegister(&register_map).?;
    }
    for (lang.register_map.callee_saved_registers) |register|
        pushFreeRegister(&register_map, register);
    {
        const n = lang.register_map.callee_saved_registers.len;
        var registers: [n]Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = popFreeRegister(&register_map).?;
        expectEqual(registers, .{ .R15, .R14, .R13, .R12, .Rbx });
        expectEqual(popFreeRegister(&register_map), null);
    }
}

test "if caller saved and callee saved registers are available prefer callee saved" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var register_map = try initRegisterMap(allocator);
    defer deinitRegisterMap(&register_map);
    {
        const n = lang.register_map.total_available_registers;
        var i: usize = 0;
        while (i < n) : (i += 1)
            _ = popFreeRegister(&register_map).?;
    }
    for (lang.register_map.callee_saved_registers) |register|
        pushFreeRegister(&register_map, register);
    for (lang.register_map.caller_saved_registers) |register|
        pushFreeRegister(&register_map, register);
    {
        const n = lang.register_map.total_available_registers;
        var registers: [n]Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = popFreeRegister(&register_map).?;
        expectEqual(registers, .{
            .R15, .R14, .R13, .R12, .Rbx, .R11, .R10,
            .R9,  .R8,  .Rdi, .Rsi, .Rdx, .Rcx, .Rax,
        });
        expectEqual(popFreeRegister(&register_map), null);
    }
    for (lang.register_map.caller_saved_registers) |register|
        pushFreeRegister(&register_map, register);
    for (lang.register_map.callee_saved_registers) |register|
        pushFreeRegister(&register_map, register);
    {
        const n = lang.register_map.total_available_registers;
        var registers: [n]Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = popFreeRegister(&register_map).?;
        expectEqual(registers, .{
            .R15, .R14, .R13, .R12, .Rbx, .R11, .R10,
            .R9,  .R8,  .Rdi, .Rsi, .Rdx, .Rcx, .Rax,
        });
        expectEqual(popFreeRegister(&register_map), null);
    }
}
