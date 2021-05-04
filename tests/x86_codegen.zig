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
    const source = "(fn start :args () :ret i64 :body 42)";
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
        \\    push rbp
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
    const ops = [_][]const u8{ "add", "sub", "mul" };
    const instructions = [_][]const u8{ "add", "sub", "imul" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn start :args () :ret i64
            \\  :body
            \\  (let x 10)
            \\  (let y 15)
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
            \\    push rbp
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
    const ops = [_][]const u8{ "add", "sub", "mul" };
    const instructions = [_][]const u8{ "add", "sub", "imul" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn start :args () :ret i64
            \\  :body
            \\  (let a 10)
            \\  (let b 15)
            \\  (let c ({s} a b))
            \\  (let d 20)
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
            \\    push rbp
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
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let x 20)
        \\  (let y 4)
        \\  (div x y))
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
        \\    push rbp
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
    const ops = [_][]const u8{ "add", "sub", "mul", "div" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn start :args () :ret i64
            \\  :body
            \\  (let x 10.3)
            \\  (let y 30.5)
            \\  (let z ({s} x y))
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
            \\quad_word31: dq 10.3
            \\quad_word33: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word31]
            \\    movsd xmm1, [rel quad_word33]
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
    const ops = [_][]const u8{ "add", "sub", "mul", "div" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn start :args () :ret i64
            \\  :body
            \\  (let x 10.3)
            \\  (let y 30)
            \\  (let z ({s} x y))
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
            \\quad_word31: dq 10.3
            \\quad_word35: dq 30.0
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word31]
            \\    movsd xmm1, [rel quad_word35]
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
    const ops = [_][]const u8{ "add", "sub", "mul", "div" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn start :args () :ret i64
            \\  :body
            \\  (let x 10)
            \\  (let y 30.5)
            \\  (let z ({s} x y))
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
            \\quad_word35: dq 10.0
            \\quad_word33: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word35]
            \\    movsd xmm1, [rel quad_word33]
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
    const ops = [_][]const u8{ "add", "sub", "mul", "div" };
    const instructions = [_][]const u8{ "addsd", "subsd", "mulsd", "divsd" };
    for (ops) |op, i| {
        const source = try std.fmt.allocPrint(allocator,
            \\(fn start :args () :ret i64
            \\  :body
            \\  (let a 10.3)
            \\  (let b 30.5)
            \\  (let c ({s} a b))
            \\  (let d ({s} c 40.2))
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
            \\quad_word31: dq 10.3
            \\quad_word36: dq 40.2
            \\quad_word33: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word31]
            \\    movsd xmm1, [rel quad_word33]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    movsd xmm0, qword [rbp-8]
            \\    movsd xmm1, [rel quad_word36]
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
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a 12345)
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
        \\byte32: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rsi, 12345
        \\    mov rdi, byte32
        \\    xor rax, rax
        \\    call _printf
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
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a 10)
        \\  (print a)
        \\  (let b 20)
        \\  (print b)
        \\  (let c 30)
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
        \\byte36: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rsi, 10
        \\    mov rdi, byte36
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rsi, 20
        \\    mov rdi, byte36
        \\    xor rax, rax
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rsi, 30
        \\    mov rdi, byte36
        \\    xor rax, rax
        \\    call _printf
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
    const source = "(fn start :args () :ret i64 :body (print 12.345))";
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
        \\byte31: db "%f", 10, 0
        \\quad_word30: dq 12.345
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word30]
        \\    mov rdi, byte31
        \\    mov rax, 1
        \\    call _printf
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
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a 10.2)
        \\  (print a)
        \\  (let b 21.4)
        \\  (print b)
        \\  (let c 35.7)
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
        \\byte36: db "%f", 10, 0
        \\quad_word31: dq 10.2
        \\quad_word35: dq 35.7
        \\quad_word33: dq 21.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word31]
        \\    mov rdi, byte36
        \\    mov rax, 1
        \\    call _printf
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    movsd xmm0, [rel quad_word33]
        \\    mov rdi, byte36
        \\    mov rax, 1
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    movsd xmm0, [rel quad_word35]
        \\    mov rdi, byte36
        \\    mov rax, 1
        \\    call _printf
        \\    sub rsp, 8
        \\    mov qword [rbp-24], rax
        \\    mov rdi, qword [rbp-24]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print string literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body (print "hello world"))
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
        \\byte31: db "hello world", 0
        \\byte32: db "%s", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rsi, byte31
        \\    mov rdi, byte32
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
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
        \\  :body (mul x x))
        \\
        \\(fn start :args () :ret i64
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rdi, 6
        \\    call label1
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
        \\  :body (div (sub y2 y1) (sub x2 x1)))
        \\
        \\(fn start :args () :ret i64
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rdi, 0
        \\    mov rsi, 10
        \\    mov rdx, 5
        \\    mov rcx, 20
        \\    call label1
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
        \\  :body (div (sub y2 y1) (sub x2 x1)))
        \\
        \\(fn square :args ((x i64)) :ret i64
        \\  :body (mul x x))
        \\
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a (slope 0 10 5 20))
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rdi, 0
        \\    mov rsi, 10
        \\    mov rdx, 5
        \\    mov rcx, 20
        \\    call label1
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    sub rsp, 8
        \\    call label2
        \\    add rsp, 8
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
        \\  :body (mul x x))
        \\
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a (square 10))
        \\  (let b (square 15))
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rdi, 10
        \\    call label1
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, 15
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
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
        \\  :body (mul x x))
        \\
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a (square 6.4))
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
        \\quad_word33: dq 6.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word33]
        \\    call label1
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
        \\  :body (div (add x y) 2))
        \\
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a (mean 10 20))
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
        \\quad_word37: dq 10.0
        \\quad_word38: dq 20.0
        \\quad_word41: dq 2.0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word37]
        \\    movsd xmm1, [rel quad_word38]
        \\    call label1
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
        \\    movsd xmm1, [rel quad_word41]
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
        \\  :body (mul x x))
        \\
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let a (square 6.4))
        \\  (let b (square 10.4))
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
        \\quad_word35: dq 10.4
        \\quad_word33: dq 6.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word33]
        \\    call label1
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    movsd xmm0, [rel quad_word35]
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
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

test "call user defined function with heterogeneous" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn f :args ((x i64) (y f64)) :ret i64
        \\  :body
        \\  (print x)
        \\  (print y))
        \\
        \\(fn start :args () :ret i64
        \\  :body
        \\  (f 5 3.4))
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
        \\byte37: db "%ld", 10, 0
        \\byte39: db "%f", 10, 0
        \\quad_word34: dq 3.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rdi, 5
        \\    movsd xmm1, [rel quad_word34]
        \\    call label1
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 16
        \\    mov qword [rbp-8], rdi
        \\    movsd qword [rbp-16], xmm1
        \\    mov rsi, qword [rbp-8]
        \\    mov rdi, byte37
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 8
        \\    mov qword [rbp-24], rax
        \\    movsd xmm0, qword [rbp-16]
        \\    mov rdi, byte39
        \\    mov rax, 1
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    mov qword [rbp-32], rax
        \\    mov rax, qword [rbp-32]
        \\    add rsp, 32
        \\    pop rbp
        \\    ret
    );
}

test "open syscall" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let o-rdonly 0)
        \\  (let fd (open "file.txt" o-rdonly))
        \\  (print fd))
    ;
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
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte36: db "%d", 10, 0
        \\byte34: db "file.txt", 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 0x2000005
        \\    mov rdi, byte34
        \\    mov esi, 0
        \\    xor rdx, rdx
        \\    syscall
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov esi, dword [rbp-4]
        \\    mov rdi, byte36
        \\    xor rax, rax
        \\    sub rsp, 12
        \\    call _printf
        \\    add rsp, 12
        \\    sub rsp, 8
        \\    mov qword [rbp-12], rax
        \\    mov rdi, qword [rbp-12]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "lseek syscall" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let fd 2)
        \\  (let seek-end 2)
        \\  (lseek fd 0 seek-end))
    ;
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 0x20000C7
        \\    mov edi, 2
        \\    mov rsi, 0
        \\    mov edx, 2
        \\    syscall
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "bit-or" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let prot-read 1)
        \\  (let prot-write 2)
        \\  (bit-or prot-read prot-write))
    ;
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 1
        \\    mov rcx, 2
        \\    or rax, rcx
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "let with explicit type" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let prot-read i32 1)
        \\  (let prot-write i32 2)
        \\  (let data (bit-or prot-read prot-write))
        \\  0)
    ;
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov eax, 1
        \\    mov ecx, 2
        \\    or eax, ecx
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov rdi, 0
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "mmap syscall" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body
        \\  (let prot-read i32 1)
        \\  (let prot-write i32 2)
        \\  (let map-private i32 0)
        \\  (let map-anonymous i32 1)
        \\  (let prot (bit-or prot-read prot-write))
        \\  (let flags (bit-or map-private map-anonymous))
        \\  (let len 4096)
        \\  (let data (ptr u8) (mmap null len prot flags -1 0))
        \\  0)
    ;
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov eax, 1
        \\    mov ecx, 2
        \\    or eax, ecx
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov eax, 0
        \\    mov ecx, 1
        \\    or eax, ecx
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov rax, 0x20000C5
        \\    mov rdi, 0
        \\    mov rsi, 4096
        \\    mov edx, dword [rbp-4]
        \\    mov ecx, dword [rbp-8]
        \\    mov r8d, -1
        \\    mov r9, 0
        \\    mov r10, 0x1002
        \\    syscall
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rdi, 0
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "read syscall" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body (read -1 null 100))
    ;
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 0x2000003
        \\    mov edi, -1
        \\    mov rsi, 0
        \\    mov rdx, 100
        \\    syscall
        \\    sub rsp, 8
        \\    mov qword [rbp-8], rax
        \\    mov rdi, qword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "close syscall" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body
        \\  (close -1)
        \\  0)
    ;
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 0x2000006
        \\    mov edi, -1
        \\    syscall
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov rdi, 0
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "munmap syscall" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i64
        \\  :body
        \\  (munmap null 0)
        \\  0)
    ;
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
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 0x2000049
        \\    mov rdi, 0
        \\    mov rsi, 0
        \\    syscall
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov rdi, 0
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}
