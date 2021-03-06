const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const lang = @import("lang");
const parse = lang.parse;
const lower = lang.lower;
const Map = lang.data.Map;
const Entity = lang.data.ir.Entity;


test "prefer callee saved registers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var arena = Arena.init(&gpa.allocator);
    defer arena.deinit();
    var register_map = lang.data.x86.RegisterMap{
        .entity_to_register = Map(Entity, lang.data.x86.Register).init(&arena.allocator),
        .register_to_entity = .{null} ** lang.data.x86.total_available_registers,
        .free_callee_saved_registers = lang.data.x86.callee_saved_registers,
        .free_callee_saved_length = lang.data.x86.callee_saved_registers.len,
        .free_caller_saved_registers = lang.data.x86.caller_saved_registers,
        .free_caller_saved_length = lang.data.x86.caller_saved_registers.len,
    };
    const n = lang.data.x86.total_available_registers;
    var registers: [n]lang.data.x86.Register = undefined;
    var i: usize = 0;
    while (i < n) : (i += 1)
        registers[i] = lang.x86_codegen.popFreeRegister(&register_map).?;
    expectEqual(registers, .{
        .Rbx, .R12, .R13, .R14, .R15, .Rax, .Rcx,
        .Rdx, .Rsi, .Rdi, .R8,  .R9,  .R10, .R11,
    });
    expectEqual(lang.x86_codegen.popFreeRegister(&register_map), null);
}

test "pop caller saved registers in reverse order as pushed" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var arena = Arena.init(&gpa.allocator);
    defer arena.deinit();
    var register_map = lang.data.x86.RegisterMap{
        .entity_to_register = Map(Entity, lang.data.x86.Register).init(&arena.allocator),
        .register_to_entity = .{null} ** lang.data.x86.total_available_registers,
        .free_callee_saved_registers = lang.data.x86.callee_saved_registers,
        .free_callee_saved_length = lang.data.x86.callee_saved_registers.len,
        .free_caller_saved_registers = lang.data.x86.caller_saved_registers,
        .free_caller_saved_length = lang.data.x86.caller_saved_registers.len,
    };
    {
        const n = lang.data.x86.total_available_registers;
        var i: usize = 0;
        while (i < n) : (i += 1)
            _ = lang.x86_codegen.popFreeRegister(&register_map).?;
    }
    for (lang.data.x86.caller_saved_registers) |register|
        lang.x86_codegen.pushFreeRegister(&register_map, register);
    {
        const n = lang.data.x86.caller_saved_registers.len;
        var registers: [n]lang.data.x86.Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = lang.x86_codegen.popFreeRegister(&register_map).?;
        expectEqual(registers, .{ .R11, .R10, .R9, .R8, .Rdi, .Rsi, .Rdx, .Rcx, .Rax });
        expectEqual(lang.x86_codegen.popFreeRegister(&register_map), null);
    }
}

test "pop callee saved registers in reverse order as pushed" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var arena = Arena.init(&gpa.allocator);
    defer arena.deinit();
    var register_map = lang.data.x86.RegisterMap{
        .entity_to_register = Map(Entity, lang.data.x86.Register).init(&arena.allocator),
        .register_to_entity = .{null} ** lang.data.x86.total_available_registers,
        .free_callee_saved_registers = lang.data.x86.callee_saved_registers,
        .free_callee_saved_length = lang.data.x86.callee_saved_registers.len,
        .free_caller_saved_registers = lang.data.x86.caller_saved_registers,
        .free_caller_saved_length = lang.data.x86.caller_saved_registers.len,
    };
    {
        const n = lang.data.x86.total_available_registers;
        var i: usize = 0;
        while (i < n) : (i += 1)
            _ = lang.x86_codegen.popFreeRegister(&register_map).?;
    }
    for (lang.data.x86.callee_saved_registers) |register|
        lang.x86_codegen.pushFreeRegister(&register_map, register);
    {
        const n = lang.data.x86.callee_saved_registers.len;
        var registers: [n]lang.data.x86.Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = lang.x86_codegen.popFreeRegister(&register_map).?;
        expectEqual(registers, .{ .R15, .R14, .R13, .R12, .Rbx });
        expectEqual(lang.x86_codegen.popFreeRegister(&register_map), null);
    }
}

test "if caller saved and callee saved registers are available prefer callee saved" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var arena = Arena.init(&gpa.allocator);
    defer arena.deinit();
    var register_map = lang.data.x86.RegisterMap{
        .entity_to_register = Map(Entity, lang.data.x86.Register).init(&arena.allocator),
        .register_to_entity = .{null} ** lang.data.x86.total_available_registers,
        .free_callee_saved_registers = lang.data.x86.callee_saved_registers,
        .free_callee_saved_length = lang.data.x86.callee_saved_registers.len,
        .free_caller_saved_registers = lang.data.x86.caller_saved_registers,
        .free_caller_saved_length = lang.data.x86.caller_saved_registers.len,
    };
    {
        const n = lang.data.x86.total_available_registers;
        var i: usize = 0;
        while (i < n) : (i += 1)
            _ = lang.x86_codegen.popFreeRegister(&register_map).?;
    }
    for (lang.data.x86.callee_saved_registers) |register|
        lang.x86_codegen.pushFreeRegister(&register_map, register);
    for (lang.data.x86.caller_saved_registers) |register|
        lang.x86_codegen.pushFreeRegister(&register_map, register);
    {
        const n = lang.data.x86.total_available_registers;
        var registers: [n]lang.data.x86.Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = lang.x86_codegen.popFreeRegister(&register_map).?;
        expectEqual(registers, .{
            .R15, .R14, .R13, .R12, .Rbx, .R11, .R10,
            .R9,  .R8,  .Rdi, .Rsi, .Rdx, .Rcx, .Rax,
        });
        expectEqual(lang.x86_codegen.popFreeRegister(&register_map), null);
    }
    for (lang.data.x86.caller_saved_registers) |register|
        lang.x86_codegen.pushFreeRegister(&register_map, register);
    for (lang.data.x86.callee_saved_registers) |register|
        lang.x86_codegen.pushFreeRegister(&register_map, register);
    {
        const n = lang.data.x86.total_available_registers;
        var registers: [n]lang.data.x86.Register = undefined;
        var i: usize = 0;
        while (i < n) : (i += 1)
            registers[i] = lang.x86_codegen.popFreeRegister(&register_map).?;
        expectEqual(registers, .{
            .R15, .R14, .R13, .R12, .Rbx, .R11, .R10,
            .R9,  .R8,  .Rdi, .Rsi, .Rdx, .Rcx, .Rax,
        });
        expectEqual(lang.x86_codegen.popFreeRegister(&register_map), null);
    }
}

test "add two signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const x 10)
        \\  (const y 15)
        \\  (+ x y))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbx, 10
        \\    mov r12, 15
        \\    add rbx, r12
        \\    mov rdi, rbx
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "add three signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const x 10)
        \\  (const y 20)
        \\  (const z 30)
        \\  (+ (+ x y) z))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbx, 10
        \\    mov r12, 20
        \\    add rbx, r12
        \\    mov r13, 30
        \\    add rbx, r13
        \\    mov rdi, rbx
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "subtract two signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const x 10)
        \\  (const y 15)
        \\  (- x y))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbx, 10
        \\    mov r12, 15
        \\    sub rbx, r12
        \\    mov rdi, rbx
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "multiply two signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const x 10)
        \\  (const y 15)
        \\  (* x y))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbx, 10
        \\    mov r12, 15
        \\    imul rbx, r12
        \\    mov rdi, rbx
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "divide two signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const x 20)
        \\  (const y 4)
        \\  (/ x y))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rax, 20
        \\    mov rbx, 4
        \\    cqo
        \\    idiv rbx
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "divide two signed integers where lhs is not in rax" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a 2)
        \\  (const b 3)
        \\  (const c (+ a b))
        \\  (const d 30)
        \\  (/ d c))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbx, 2
        \\    mov r12, 3
        \\    add rbx, r12
        \\    mov rax, 30
        \\    cqo
        \\    idiv rbx
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "binary operators on signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a 10)
        \\  (const b 7)
        \\  (const c 3)
        \\  (const d 15)
        \\  (const e 2)
        \\  (/ (+ (* (- a b) c) d) e))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbx, 10
        \\    mov r12, 7
        \\    sub rbx, r12
        \\    mov r13, 3
        \\    imul rbx, r13
        \\    mov r14, 15
        \\    add rbx, r14
        \\    mov rax, rbx
        \\    mov rbx, 2
        \\    cqo
        \\    idiv rbx
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "denominator of division cannot be rdx" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a 2)
        \\  (const b 3)
        \\  (const c (+ a b))
        \\  (const d 10)
        \\  (const e (* c d))
        \\  (const f 5)
        \\  (/ e f))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbx, 2
        \\    mov r12, 3
        \\    add rbx, r12
        \\    mov r13, 10
        \\    imul rbx, r13
        \\    mov rax, rbx
        \\    mov rbx, 5
        \\    cqo
        \\    idiv rbx
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print a signed integer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a 12345)
        \\  (print a))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte17: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    sub rsp, 8
        \\    mov rsi, 12345
        \\    mov rbx, rsi
        \\    mov rdi, byte17
        \\    call _printf
        \\    add rsp, 8
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print three signed integer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a 10)
        \\  (print a)
        \\  (const b 20)
        \\  (print b)
        \\  (const c 30)
        \\  (print c))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte21: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    sub rsp, 8
        \\    mov rsi, 10
        \\    mov rbx, rsi
        \\    mov rdi, byte21
        \\    call _printf
        \\    add rsp, 8
        \\    mov r12, rax
        \\    sub rsp, 8
        \\    mov rsi, 20
        \\    mov r13, rsi
        \\    mov rdi, byte21
        \\    call _printf
        \\    add rsp, 8
        \\    mov r14, rax
        \\    sub rsp, 8
        \\    mov rsi, 30
        \\    mov r15, rsi
        \\    mov rdi, byte21
        \\    call _printf
        \\    add rsp, 8
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print a signed float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source = "(fn main :args () :ret i64 :body (print 12.345))";
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte16: db "%f", 10, 0
        \\quad_word14: dq 12.345
        \\
        \\    section .text
        \\
        \\_main:
        \\    sub rsp, 8
        \\    movsd xmm0, [rel quad_word14]
        \\    mov rdi, byte16
        \\    call _printf
        \\    add rsp, 8
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

// test "add two signed floats" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer std.testing.expect(!gpa.deinit());
//     const allocator = &gpa.allocator;
//     const source =
//         \\(fn main :args () :ret i64
//         \\  :body
//         \\  (const x 10.3)
//         \\  (const y 30.5)
//         \\  (const z (+ x y))
//         \\  0)
//     ;
//     var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
//     defer interned_strings.deinit();
//     var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
//     defer ast.deinit();
//     var ir = try lang.lower(&gpa.allocator, ast);
//     defer ir.deinit();
//     var x86 = try lang.codegen(allocator, ir, &interned_strings);
//     defer x86.deinit();
//     var x86_string = try lang.x86String(allocator, x86, interned_strings);
//     defer x86_string.deinit();
//     std.testing.expectEqualStrings(x86_string.slice(),
//         \\    global _main
//         \\
//         \\    section .data
//         \\
//         \\quad_word14: dq 10.3
//         \\quad_word15: dq 30.5
//         \\
//         \\    section .text
//         \\
//         \\_main:
//         \\    movsd xmm0, [rel quad_word14]
//         \\    movsd xmm1, [rel quad_word14]
//         \\    addsd xmm0, xmm1
//         \\    mov rdi, 0
//         \\    mov rax, 0x02000001
//         \\    syscall
//     );
// }
