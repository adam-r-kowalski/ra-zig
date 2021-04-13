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
    var entities = try lang.data.Entities.init(&gpa.allocator);
    var ast = try lang.parse(allocator, &entities, source);
    var ir = try lang.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
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
        var entities = try lang.data.Entities.init(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rbp, rsp
            \\    mov rax, 10
            \\    mov rcx, 15
            \\    {s} rax, rcx
            \\    sub rsp, 8
            \\    mov qword [rbp-8], rax
            \\    mov rdi, qword [rbp-8]
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
        var entities = try lang.data.Entities.init(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rbp, rsp
            \\    mov rax, 10
            \\    mov rcx, 15
            \\    {s} rax, rcx
            \\    sub rsp, 8
            \\    mov qword [rbp-8], rax
            \\    mov rax, qword [rbp-8]
            \\    mov rcx, 20
            \\    {s} rax, rcx
            \\    sub rsp, 8
            \\    mov qword [rbp-16], rax
            \\    mov rdi, qword [rbp-16]
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
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rax, 20
        \\    cqo
        \\    mov rcx, 4
        \\    idiv rcx
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
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
        var entities = try lang.data.Entities.init(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word19: dq 30.5
            \\quad_word17: dq 10.3
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word17]
            \\    movsd xmm1, [rel quad_word19]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    mov rdi, 0
            \\    mov rax, 0x02000001
            \\    syscall
        , .{instructions[i]});
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
}

test "binary op between signed float and comptime int" {
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
            \\  (const y 30)
            \\  (const z ({s} x y))
            \\  0)
        , .{op});
        var entities = try lang.data.Entities.init(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word22: dq 30.0
            \\quad_word17: dq 10.3
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word17]
            \\    movsd xmm1, [rel quad_word22]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    mov rdi, 0
            \\    mov rax, 0x02000001
            \\    syscall
        , .{instructions[i]});
        expectEqualStrings(x86_string.slice(), expected);
        x86_string.deinit();
        allocator.free(expected);
    }
}

test "binary op between comptime int and signed float" {
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
        var entities = try lang.data.Entities.init(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word19: dq 30.5
            \\quad_word22: dq 10.0
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word22]
            \\    movsd xmm1, [rel quad_word19]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
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
        var entities = try lang.data.Entities.init(&gpa.allocator);
        var ast = try lang.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try lang.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try lang.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try lang.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word19: dq 30.5
            \\quad_word22: dq 40.2
            \\quad_word17: dq 10.3
            \\
            \\    section .text
            \\
            \\_main:
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word17]
            \\    movsd xmm1, [rel quad_word19]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    movsd xmm0, qword [rbp-8]
            \\    movsd xmm1, [rel quad_word22]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-16], xmm0
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
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte18: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rsi, 12345
        \\    mov rdi, byte18
        \\    xor rax, rax
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print three signed integers" {
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
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte22: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rsi, 10
        \\    mov rdi, byte22
        \\    xor rax, rax
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rsi, 20
        \\    mov rdi, byte22
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rsi, 30
        \\    mov rdi, byte22
        \\    xor rax, rax
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-24], rax
        \\    mov rdi, qword [rbp-24]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "align stack before calling print" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a 3)
        \\  (const b 5)
        \\  (const c (+ a b))
        \\  (const d (+ a b))
        \\  (print a))
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte23: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rax, 3
        \\    mov rcx, 5
        \\    add rax, rcx
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rax, 3
        \\    mov rcx, 5
        \\    add rax, rcx
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rsi, 3
        \\    mov rdi, byte23
        \\    xor rax, rax
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-24], rax
        \\    mov rdi, qword [rbp-24]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print a signed float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source = "(fn main :args () :ret i64 :body (print 12.345))";
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte17: db "%f", 10, 0
        \\quad_word16: dq 12.345
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word16]
        \\    mov rdi, byte17
        \\    mov rax, 1
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print three signed floats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a 10.2)
        \\  (print a)
        \\  (const b 21.4)
        \\  (print b)
        \\  (const c 35.7)
        \\  (print c))
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte22: db "%f", 10, 0
        \\quad_word21: dq 35.7
        \\quad_word19: dq 21.4
        \\quad_word17: dq 10.2
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word17]
        \\    mov rdi, byte22
        \\    mov rax, 1
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    movsd xmm0, [rel quad_word19]
        \\    mov rdi, byte22
        \\    mov rax, 1
        \\    call _printf
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    movsd xmm0, [rel quad_word21]
        \\    mov rdi, byte22
        \\    mov rax, 1
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-24], rax
        \\    mov rdi, qword [rbp-24]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "user defined function single int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn square :args ((x i64)) :ret i64
        \\  :body (* x x))
        \\
        \\(fn main :args () :ret i64
        \\  :body (square 6))
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rdi, 6
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rdi
        \\    mov rax, qword [rbp-8]
        \\    imul rax, qword [rbp-8]
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rax, qword [rbp-16]
        \\    add rsp, 16
        \\    pop rbp
        \\    ret
    );
}

test "user defined function four ints" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn slope :args ((x1 i64) (x2 i64) (y1 i64) (y2 i64)) :ret i64
        \\  :body (/ (- y2 y1) (- x2 x1)))
        \\
        \\(fn main :args () :ret i64
        \\  :body (slope 0 10 5 20))
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rdi, 0
        \\    mov rsi, 10
        \\    mov rdx, 5
        \\    mov rcx, 20
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 32
        \\    mov qword [rbp-8], rdi
        \\    mov qword [rbp-16], rsi
        \\    mov qword [rbp-24], rdx
        \\    mov qword [rbp-32], rcx
        \\    mov rax, qword [rbp-32]
        \\    sub rax, qword [rbp-24]
        \\    sub rsp, 8
        \\    mov qword [rbp-40], rax
        \\    mov rax, qword [rbp-16]
        \\    sub rax, qword [rbp-8]
        \\    sub rsp, 8
        \\    mov qword [rbp-48], rax
        \\    mov rax, qword [rbp-40]
        \\    cqo
        \\    idiv qword [rbp-48]
        \\    sub rsp, 8
        \\    mov qword [rbp-56], rax
        \\    mov rax, qword [rbp-56]
        \\    add rsp, 56
        \\    pop rbp
        \\    ret
    );
}

test "two user defined functions taking ints" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn slope :args ((x1 i64) (x2 i64) (y1 i64) (y2 i64)) :ret i64
        \\  :body (/ (- y2 y1) (- x2 x1)))
        \\
        \\(fn square :args ((x i64)) :ret i64
        \\  :body (* x x))
        \\
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a (slope 0 10 5 20))
        \\  (square a))
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rdi, 0
        \\    mov rsi, 10
        \\    mov rdx, 5
        \\    mov rcx, 20
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    call label2
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rdi, qword [rbp-16]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 32
        \\    mov qword [rbp-8], rdi
        \\    mov qword [rbp-16], rsi
        \\    mov qword [rbp-24], rdx
        \\    mov qword [rbp-32], rcx
        \\    mov rax, qword [rbp-32]
        \\    sub rax, qword [rbp-24]
        \\    sub rsp, 8
        \\    mov qword [rbp-40], rax
        \\    mov rax, qword [rbp-16]
        \\    sub rax, qword [rbp-8]
        \\    sub rsp, 8
        \\    mov qword [rbp-48], rax
        \\    mov rax, qword [rbp-40]
        \\    cqo
        \\    idiv qword [rbp-48]
        \\    sub rsp, 8
        \\    mov qword [rbp-56], rax
        \\    mov rax, qword [rbp-56]
        \\    add rsp, 56
        \\    pop rbp
        \\    ret
        \\
        \\label2:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rdi
        \\    mov rax, qword [rbp-8]
        \\    imul rax, qword [rbp-8]
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rax, qword [rbp-16]
        \\    add rsp, 16
        \\    pop rbp
        \\    ret
    );
}

test "call user defined int function twice" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn square :args ((x i64)) :ret i64
        \\  :body (* x x))
        \\
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a (square 10))
        \\  (const b (square 15))
        \\  b)
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    mov rdi, 10
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, 15
        \\    call label1
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rdi, qword [rbp-16]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rdi
        \\    mov rax, qword [rbp-8]
        \\    imul rax, qword [rbp-8]
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rax, qword [rbp-16]
        \\    add rsp, 16
        \\    pop rbp
        \\    ret
    );
}

test "user defined function single float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn square :args ((x f64)) :ret f64
        \\  :body (* x x))
        \\
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a (square 6.4))
        \\  5)
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .data
        \\
        \\quad_word19: dq 6.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word19]
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    mov rdi, 5
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    movsd xmm0, qword [rbp-8]
        \\    movsd xmm1, qword [rbp-8]
        \\    mulsd xmm0, xmm1
        \\    sub rsp, 8
        \\    movsd qword [rbp-16], xmm0
        \\    movsd xmm0, qword [rbp-16]
        \\    add rsp, 16
        \\    pop rbp
        \\    ret
    );
}

test "user defined function two floats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn mean :args ((x f64) (y f64)) :ret f64
        \\  :body (/ (+ x y) 2))
        \\
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a (mean 10 20))
        \\  0)
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .data
        \\
        \\quad_word24: dq 10.0
        \\quad_word25: dq 20.0
        \\quad_word28: dq 2.0
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word24]
        \\    movsd xmm1, [rel quad_word25]
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    mov rdi, 0
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 16
        \\    movsd qword [rbp-8], xmm0
        \\    movsd qword [rbp-16], xmm1
        \\    movsd xmm0, qword [rbp-8]
        \\    movsd xmm1, qword [rbp-16]
        \\    addsd xmm0, xmm1
        \\    sub rsp, 8
        \\    movsd qword [rbp-24], xmm0
        \\    movsd xmm0, qword [rbp-24]
        \\    movsd xmm1, [rel quad_word28]
        \\    divsd xmm0, xmm1
        \\    sub rsp, 8
        \\    movsd qword [rbp-32], xmm0
        \\    movsd xmm0, qword [rbp-32]
        \\    add rsp, 32
        \\    pop rbp
        \\    ret
    );
}

test "call user defined function float function twice" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn square :args ((x f64)) :ret f64
        \\  :body (* x x))
        \\
        \\(fn main :args () :ret i64
        \\  :body
        \\  (const a (square 6.4))
        \\  (const b (square 10.4))
        \\  5)
    ;
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try lang.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try lang.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .data
        \\
        \\quad_word21: dq 10.4
        \\quad_word19: dq 6.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word19]
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    movsd xmm0, [rel quad_word21]
        \\    call label1
        \\    sub rsp, 8
        \\    movsd qword [rbp-16], xmm0
        \\    mov rdi, 5
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    movsd xmm0, qword [rbp-8]
        \\    movsd xmm1, qword [rbp-8]
        \\    mulsd xmm0, xmm1
        \\    sub rsp, 8
        \\    movsd qword [rbp-16], xmm0
        \\    movsd xmm0, qword [rbp-16]
        \\    add rsp, 16
        \\    pop rbp
        \\    ret
    );
}
