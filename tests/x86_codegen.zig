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

test "trivial" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source = "(fn main :args () :ret i64 :body 42)";
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    var ir = try lang.lower(&gpa.allocator, ast);
    ast.deinit();
    var x86 = try lang.codegen(allocator, ir, &interned_strings);
    ir.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    interned_strings.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rdi, 42
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "binary op between two signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const ops = [_][]const u8{ "+", "-", "*" };
    const instructions = [_][]const u8{ "add", "sub", "imul" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn main :args () :ret i64
            \\  :body
            \\  (const x 10)
            \\  (const y 15)
            \\  ({s} x y))
        , .{op});
        var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, ir, &interned_strings);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, interned_strings);
        interned_strings.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rax, 10
            \\    mov rcx, 15
            \\    mov rdx, rax
            \\    {s} rax, rcx
            \\    mov rdi, rax
            \\    mov rax, 0x02000001
            \\    syscall
        , .{instructions[i]});
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
}

test "binary op between three signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const ops = [_][]const u8{ "+", "-", "*" };
    const instructions = [_][]const u8{ "add", "sub", "imul" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn main :args () :ret i64
            \\  :body
            \\  (const a 10)
            \\  (const b 15)
            \\  (const c ({s} a b))
            \\  (const d 20)
            \\  ({s} c d))
        , .{ op, op });
        var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, ir, &interned_strings);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, interned_strings);
        interned_strings.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rax, 10
            \\    mov rcx, 15
            \\    mov rdx, rax
            \\    {s} rax, rcx
            \\    mov rsi, 20
            \\    mov rdi, rax
            \\    {s} rax, rsi
            \\    mov rdi, rax
            \\    mov rax, 0x02000001
            \\    syscall
        , .{ instructions[i], instructions[i] });
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
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
        \\    mov r11, 4
        \\    mov rcx, rax
        \\    cqo
        \\    idiv r11
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
        \\    mov rax, 2
        \\    mov rcx, 3
        \\    mov rdx, rax
        \\    add rax, rcx
        \\    mov rsi, rdx
        \\    mov rdi, rax
        \\    mov rax, 30
        \\    mov r8, rax
        \\    cqo
        \\    idiv rdi
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
        \\    mov rax, 10
        \\    mov rcx, 7
        \\    mov rdx, rax
        \\    sub rax, rcx
        \\    mov rsi, 3
        \\    mov rdi, rax
        \\    imul rax, rsi
        \\    mov r8, 15
        \\    mov r9, rax
        \\    add rax, r8
        \\    mov r10, rdx
        \\    mov r11, 2
        \\    push r14
        \\    mov r14, rax
        \\    cqo
        \\    idiv r11
        \\    mov rdi, rax
        \\    mov r14, qword [rbp-8]
        \\    add rsp, 8
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
        \\  (/ c a))
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
        \\    mov rax, 2
        \\    mov rcx, 3
        \\    mov rdx, rax
        \\    add rax, rcx
        \\    mov rsi, rdx
        \\    mov rdi, rax
        \\    cqo
        \\    idiv rsi
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "binary op between two signed floats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const ops = [_][]const u8{ "+", "-", "*", "/" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn main :args () :ret i64
            \\  :body
            \\  (const x 10.3)
            \\  (const y 30.5)
            \\  (const z ({s} x y))
            \\  0)
        , .{op});
        var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, ir, &interned_strings);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, interned_strings);
        interned_strings.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word15: dq 10.3
            \\quad_word17: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    movsd xmm0, [rel quad_word15]
            \\    movsd xmm1, [rel quad_word17]
            \\    movsd xmm2, xmm0
            \\    {s} xmm0, xmm1
            \\    mov rdi, 0
            \\    mov rax, 0x02000001
            \\    syscall
        , .{instructions[i]});
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
}

test "binary op between two signed floats left is comptime int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const ops = [_][]const u8{ "+", "-", "*", "/" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn main :args () :ret i64
            \\  :body
            \\  (const x 10)
            \\  (const y 30.5)
            \\  (const z ({s} x y))
            \\  0)
        , .{op});
        var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, ir, &interned_strings);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, interned_strings);
        interned_strings.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word15: dq 10
            \\quad_word17: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    movsd xmm0, [rel quad_word15]
            \\    movsd xmm1, [rel quad_word17]
            \\    movsd xmm2, xmm0
            \\    {s} xmm0, xmm1
            \\    mov rdi, 0
            \\    mov rax, 0x02000001
            \\    syscall
        , .{instructions[i]});
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
}

test "binary op between two signed floats right is comptime int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const ops = [_][]const u8{ "+", "-", "*", "/" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn main :args () :ret i64
            \\  :body
            \\  (const x 30.5)
            \\  (const y 10)
            \\  (const z ({s} x y))
            \\  0)
        , .{op});
        var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, ir, &interned_strings);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, interned_strings);
        interned_strings.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word15: dq 30.5
            \\quad_word17: dq 10
            \\
            \\    section .text
            \\
            \\_main:
            \\    movsd xmm0, [rel quad_word15]
            \\    movsd xmm1, [rel quad_word17]
            \\    movsd xmm2, xmm0
            \\    {s} xmm0, xmm1
            \\    mov rdi, 0
            \\    mov rax, 0x02000001
            \\    syscall
        , .{instructions[i]});
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
}

test "binary op between three signed floats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const ops = [_][]const u8{ "+", "-", "*", "/" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn main :args () :ret i64
            \\  :body
            \\  (const a 10.3)
            \\  (const b 30.5)
            \\  (const c ({s} a b))
            \\  (const d ({s} c 40.2))
            \\  0)
        , .{ op, op });
        var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, ir, &interned_strings);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, interned_strings);
        interned_strings.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word20: dq 40.2
            \\quad_word15: dq 10.3
            \\quad_word17: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    movsd xmm0, [rel quad_word15]
            \\    movsd xmm1, [rel quad_word17]
            \\    movsd xmm2, xmm0
            \\    {s} xmm0, xmm1
            \\    movsd xmm3, [rel quad_word20]
            \\    movsd xmm4, xmm0
            \\    {s} xmm0, xmm3
            \\    mov rdi, 0
            \\    mov rax, 0x02000001
            \\    syscall
        , .{ instructions[i], instructions[i] });
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
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
        \\byte16: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rsi, 12345
        \\    mov rdi, byte16
        \\    sub rsp, 8
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
        \\byte20: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rsi, 10
        \\    mov rdi, byte20
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    push r14
        \\    mov r14, rax
        \\    mov rsi, 20
        \\    mov rdi, byte20
        \\    call _printf
        \\    push r15
        \\    mov r15, rax
        \\    mov rsi, 30
        \\    mov rdi, byte20
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    mov rdi, rax
        \\    mov r14, qword [rbp-8]
        \\    mov r15, qword [rbp-16]
        \\    add rsp, 16
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print four signed integer" {
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
        \\  (print c)
        \\  (const d 30)
        \\  (print d))
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
        \\    mov rsi, 10
        \\    mov rdi, byte21
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    push r14
        \\    mov r14, rax
        \\    mov rsi, 20
        \\    mov rdi, byte21
        \\    call _printf
        \\    push r15
        \\    mov r15, rax
        \\    mov rsi, 30
        \\    mov rdi, byte21
        \\    call _printf
        \\
        \\    add rsp, 8
        \\    mov rdi, rax
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

// test "print signed integer after addition" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer std.testing.expect(!gpa.deinit());
//     const allocator = &gpa.allocator;
//     const source =
//         \\(fn main :args () :ret i64
//         \\  :body
//         \\  (const a 10)
//         \\  (const b 20)
//         \\  (const c (+ a b))
//         \\  (print c))
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
//         \\    extern _printf
//         \\
//         \\    section .data
//         \\
//         \\byte20: db "%ld", 10, 0
//         \\
//         \\    section .text
//         \\
//         \\_main:
//         \\    mov rax, 10
//         \\    mov rcx, 20
//         \\    add rax, rcx
//         \\    sub rsp, 8
//         \\    mov rbx, rax
//         \\    mov r12, rcx
//         \\    mov rsi, rbx
//         \\    mov rdi, byte20
//         \\    call _printf
//         \\    add rsp, 8
//         \\    mov rdi, rax
//         \\    mov rax, 0x02000001
//         \\    syscall
//     );
// }

// test "print a signed float" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer std.testing.expect(!gpa.deinit());
//     const allocator = &gpa.allocator;
//     const source = "(fn main :args () :ret i64 :body (print 12.345))";
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
//         \\    extern _printf
//         \\
//         \\    section .data
//         \\
//         \\byte16: db "%f", 10, 0
//         \\quad_word14: dq 12.345
//         \\
//         \\    section .text
//         \\
//         \\_main:
//         \\    sub rsp, 8
//         \\    movsd xmm0, [rel quad_word14]
//         \\    mov rdi, byte16
//         \\    call _printf
//         \\    add rsp, 8
//         \\    mov rdi, rax
//         \\    mov rax, 0x02000001
//         \\    syscall
//     );
// }

// test "print signed float after addition" {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer std.testing.expect(!gpa.deinit());
//     const allocator = &gpa.allocator;
//     const source =
//         \\(fn main :args () :ret i64
//         \\  :body
//         \\  (const a 10.4)
//         \\  (const b 20.5)
//         \\  (const c (+ a b))
//         \\  (print c))
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
//         \\    extern _printf
//         \\
//         \\    section .data
//         \\
//         \\byte20: db "%f", 10, 0
//         \\quad_word15: dq 10.4
//         \\quad_word17: dq 20.5
//         \\
//         \\    section .text
//         \\
//         \\_main:
//         \\    movsd xmm0, [rel quad_word15]
//         \\    movsd xmm1, [rel quad_word17]
//         \\    addsd xmm0, xmm1
//         \\    sub rsp, 8
//         \\    movsd xmm8, xmm0
//         \\    movsd xmm9, xmm1
//         \\    movsd xmm0, xmm8
//         \\    mov rdi, byte20
//         \\    call _printf
//         \\    add rsp, 8
//         \\    mov rdi, rax
//         \\    mov rax, 0x02000001
//         \\    syscall
//     );
// }
