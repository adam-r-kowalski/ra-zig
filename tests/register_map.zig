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
    var registers: [14]Register = undefined;
    var i: usize = 0;
    while (i < 14) : (i += 1) {
        registers[i] = popFreeRegister(&register_map).?;
    }
    expectEqual(registers, .{
        .Rbx, .R12, .R13, .R14, .R15, .Rax, .Rcx,
        .Rdx, .Rsi, .Rdi, .R8,  .R9,  .R10, .R11,
    });
    expectEqual(popFreeRegister(&register_map), null);
}
