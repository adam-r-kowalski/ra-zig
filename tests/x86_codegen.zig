const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const ra = @import("ra");
const parse = ra.parse;
const lower = ra.lower;
const Map = ra.data.Map;
const Entity = ra.data.ir.Entity;

test "trivial" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source = "(fn start :args () :ret i32 :body 42)";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 42
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
            \\(fn start :args () :ret i32
            \\  :body
            \\  (let x 10)
            \\  (let y 15)
            \\  ({s} x y)
            \\  0)
        , .{op});
        var entities = try ra.data.Entities.init(&gpa.allocator);
        var ast = try ra.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try ra.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try ra.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try ra.x86String(allocator, x86, entities);
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
            \\    mov edi, 0
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
            \\(fn start :args () :ret i32
            \\  :body
            \\  (let a 10)
            \\  (let b 15)
            \\  (let c ({s} a b))
            \\  (let d 20)
            \\  ({s} c d)
            \\  0)
        , .{ op, op });
        var entities = try ra.data.Entities.init(&gpa.allocator);
        var ast = try ra.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try ra.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try ra.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try ra.x86String(allocator, x86, entities);
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
            \\    mov edi, 0
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let x 20)
        \\  (let y 4)
        \\  (/ x y)
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 0
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
            \\(fn start :args () :ret i32
            \\  :body
            \\  (let x 10.3)
            \\  (let y 30.5)
            \\  (let z ({s} x y))
            \\  0)
        , .{op});
        var entities = try ra.data.Entities.init(&gpa.allocator);
        var ast = try ra.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try ra.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try ra.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try ra.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word0: dq 10.3
            \\quad_word1: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word0]
            \\    movsd xmm1, [rel quad_word1]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    mov edi, 0
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
            \\(fn start :args () :ret i32
            \\  :body
            \\  (let x 10.3)
            \\  (let y 30)
            \\  (let z ({s} x y))
            \\  0)
        , .{op});
        var entities = try ra.data.Entities.init(&gpa.allocator);
        var ast = try ra.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try ra.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try ra.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try ra.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word0: dq 10.3
            \\quad_word1: dq 30.0
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word0]
            \\    movsd xmm1, [rel quad_word1]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    mov edi, 0
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
            \\(fn start :args () :ret i32
            \\  :body
            \\  (let x 10)
            \\  (let y 30.5)
            \\  (let z ({s} x y))
            \\  0)
        , .{op});
        var entities = try ra.data.Entities.init(&gpa.allocator);
        var ast = try ra.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try ra.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try ra.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try ra.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word0: dq 10.0
            \\quad_word1: dq 30.5
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word0]
            \\    movsd xmm1, [rel quad_word1]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    mov edi, 0
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
            \\(fn start :args () :ret i32
            \\  :body
            \\  (let a 10.3)
            \\  (let b 30.5)
            \\  (let c ({s} a b))
            \\  (let d ({s} c 40.2))
            \\  0)
        , .{ op, op });
        var entities = try ra.data.Entities.init(&gpa.allocator);
        var ast = try ra.parse(&gpa.allocator, &entities, source);
        allocator.free(source);
        var ir = try ra.lower(&gpa.allocator, &entities, ast);
        ast.deinit();
        var x86 = try ra.codegen(allocator, &entities, ir);
        ir.deinit();
        var x86_string = try ra.x86String(allocator, x86, entities);
        entities.deinit();
        x86.deinit();
        const expected = try std.fmt.allocPrint(allocator,
            \\    global _main
            \\
            \\    section .data
            \\
            \\quad_word0: dq 10.3
            \\quad_word1: dq 30.5
            \\quad_word2: dq 40.2
            \\
            \\    section .text
            \\
            \\_main:
            \\    push rbp
            \\    mov rbp, rsp
            \\    movsd xmm0, [rel quad_word0]
            \\    movsd xmm1, [rel quad_word1]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-8], xmm0
            \\    movsd xmm0, qword [rbp-8]
            \\    movsd xmm1, [rel quad_word2]
            \\    {s} xmm0, xmm1
            \\    sub rsp, 8
            \\    movsd qword [rbp-16], xmm0
            \\    mov edi, 0
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
        \\(fn start :args () :ret i32
        \\  :body (print 12345))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rsi, 12345
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print three signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a 10)
        \\  (print a)
        \\  (let b 20)
        \\  (print b)
        \\  (let c 30)
        \\  (print c))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rsi, 10
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov rsi, 20
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    sub rsp, 12
        \\    call _printf
        \\    add rsp, 12
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov rsi, 30
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 4
        \\    mov dword [rbp-12], eax
        \\    mov edi, dword [rbp-12]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print a signed float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source = "(fn start :args () :ret i32 :body (print 12.345))";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%f", 10, 0
        \\quad_word0: dq 12.345
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word0]
        \\    mov rdi, byte0
        \\    mov rax, 1
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print three signed floats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a 10.2)
        \\  (print a)
        \\  (let b 21.4)
        \\  (print b)
        \\  (let c 35.7)
        \\  (print c))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%f", 10, 0
        \\quad_word0: dq 10.2
        \\quad_word1: dq 21.4
        \\quad_word2: dq 35.7
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word0]
        \\    mov rdi, byte0
        \\    mov rax, 1
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    movsd xmm0, [rel quad_word1]
        \\    mov rdi, byte0
        \\    mov rax, 1
        \\    sub rsp, 12
        \\    call _printf
        \\    add rsp, 12
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    movsd xmm0, [rel quad_word2]
        \\    mov rdi, byte0
        \\    mov rax, 1
        \\    sub rsp, 8
        \\    call _printf
        \\    add rsp, 8
        \\    sub rsp, 4
        \\    mov dword [rbp-12], eax
        \\    mov edi, dword [rbp-12]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print string literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body (print "hello world"))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "hello world", 0
        \\byte1: db "%s", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rsi, byte0
        \\    mov rdi, byte1
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "print char literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body (print 'a'))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%c", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov sil, 97
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    );
}

test "user defined function single int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn square :args ((x i32)) :ret i32
        \\  :body (* x x))
        \\
        \\(fn start :args () :ret i32
        \\  :body (square 6))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov edi, 6
        \\    call label1
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 4
        \\    mov dword [rbp-4], edi
        \\    mov eax, dword [rbp-4]
        \\    imul eax, dword [rbp-4]
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov eax, dword [rbp-8]
        \\    add rsp, 8
        \\    pop rbp
        \\    ret
    );
}

test "user defined function four ints" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn slope :args ((x1 i32) (x2 i32) (y1 i32) (y2 i32)) :ret i32
        \\  :body (/ (- y2 y1) (- x2 x1)))
        \\
        \\(fn start :args () :ret i32
        \\  :body (slope 0 10 5 20))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov edi, 0
        \\    mov esi, 10
        \\    mov edx, 5
        \\    mov ecx, 20
        \\    call label1
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 16
        \\    mov dword [rbp-4], edi
        \\    mov dword [rbp-8], esi
        \\    mov dword [rbp-12], edx
        \\    mov dword [rbp-16], ecx
        \\    mov eax, dword [rbp-16]
        \\    sub eax, dword [rbp-12]
        \\    sub rsp, 4
        \\    mov dword [rbp-20], eax
        \\    mov eax, dword [rbp-8]
        \\    sub eax, dword [rbp-4]
        \\    sub rsp, 4
        \\    mov dword [rbp-24], eax
        \\    mov eax, dword [rbp-20]
        \\    cdq
        \\    idiv dword [rbp-24]
        \\    sub rsp, 4
        \\    mov dword [rbp-28], eax
        \\    mov eax, dword [rbp-28]
        \\    add rsp, 28
        \\    pop rbp
        \\    ret
    );
}

test "two user defined functions taking ints" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn slope :args ((x1 i32) (x2 i32) (y1 i32) (y2 i32)) :ret i32
        \\  :body (/ (- y2 y1) (- x2 x1)))
        \\
        \\(fn square :args ((x i32)) :ret i32
        \\  :body (* x x))
        \\
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a (slope 0 10 5 20))
        \\  (square a))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov edi, 0
        \\    mov esi, 10
        \\    mov edx, 5
        \\    mov ecx, 20
        \\    call label1
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    sub rsp, 12
        \\    call label2
        \\    add rsp, 12
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov edi, dword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 16
        \\    mov dword [rbp-4], edi
        \\    mov dword [rbp-8], esi
        \\    mov dword [rbp-12], edx
        \\    mov dword [rbp-16], ecx
        \\    mov eax, dword [rbp-16]
        \\    sub eax, dword [rbp-12]
        \\    sub rsp, 4
        \\    mov dword [rbp-20], eax
        \\    mov eax, dword [rbp-8]
        \\    sub eax, dword [rbp-4]
        \\    sub rsp, 4
        \\    mov dword [rbp-24], eax
        \\    mov eax, dword [rbp-20]
        \\    cdq
        \\    idiv dword [rbp-24]
        \\    sub rsp, 4
        \\    mov dword [rbp-28], eax
        \\    mov eax, dword [rbp-28]
        \\    add rsp, 28
        \\    pop rbp
        \\    ret
        \\
        \\label2:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 4
        \\    mov dword [rbp-4], edi
        \\    mov eax, dword [rbp-4]
        \\    imul eax, dword [rbp-4]
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov eax, dword [rbp-8]
        \\    add rsp, 8
        \\    pop rbp
        \\    ret
    );
}

test "call user defined int function twice" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn square :args ((x i32)) :ret i32
        \\  :body (* x x))
        \\
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a (square 10))
        \\  (let b (square 15))
        \\  b)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov edi, 10
        \\    call label1
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, 15
        \\    sub rsp, 12
        \\    call label1
        \\    add rsp, 12
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov edi, dword [rbp-8]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 4
        \\    mov dword [rbp-4], edi
        \\    mov eax, dword [rbp-4]
        \\    imul eax, dword [rbp-4]
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov eax, dword [rbp-8]
        \\    add rsp, 8
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a (square 6.4))
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .data
        \\
        \\quad_word0: dq 6.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word0]
        \\    call label1
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    mov edi, 0
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a (mean 10 20))
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .data
        \\
        \\quad_word0: dq 10.0
        \\quad_word1: dq 20.0
        \\quad_word2: dq 2.0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word0]
        \\    movsd xmm1, [rel quad_word1]
        \\    call label1
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    mov edi, 0
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
        \\    movsd xmm1, [rel quad_word2]
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a (square 6.4))
        \\  (let b (square 10.4))
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .data
        \\
        \\quad_word0: dq 6.4
        \\quad_word1: dq 10.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    movsd xmm0, [rel quad_word0]
        \\    call label1
        \\    sub rsp, 8
        \\    movsd qword [rbp-8], xmm0
        \\    movsd xmm0, [rel quad_word1]
        \\    sub rsp, 8
        \\    call label1
        \\    add rsp, 8
        \\    sub rsp, 8
        \\    movsd qword [rbp-16], xmm0
        \\    mov edi, 0
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
        \\(fn f :args ((x i32) (y f64)) :ret i32
        \\  :body
        \\  (print x)
        \\  (print y))
        \\
        \\(fn start :args () :ret i32
        \\  :body
        \\  (f 5 3.4))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    defer x86.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%d", 10, 0
        \\byte1: db "%f", 10, 0
        \\quad_word0: dq 3.4
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov edi, 5
        \\    movsd xmm1, [rel quad_word0]
        \\    call label1
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 12
        \\    mov dword [rbp-4], edi
        \\    movsd qword [rbp-12], xmm1
        \\    mov esi, dword [rbp-4]
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    sub rsp, 4
        \\    call _printf
        \\    add rsp, 4
        \\    sub rsp, 4
        \\    mov dword [rbp-16], eax
        \\    movsd xmm0, qword [rbp-12]
        \\    mov rdi, byte1
        \\    mov rax, 1
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-20], eax
        \\    mov eax, dword [rbp-20]
        \\    add rsp, 20
        \\    pop rbp
        \\    ret
    );
}

test "open syscall" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let o-rdonly 0)
        \\  (let fd (open "file.txt" o-rdonly))
        \\  (print fd))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "file.txt", 0
        \\byte1: db "%d", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 0x2000005
        \\    mov rdi, byte0
        \\    mov esi, 0
        \\    xor rdx, rdx
        \\    syscall
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov esi, dword [rbp-4]
        \\    mov rdi, byte1
        \\    xor rax, rax
        \\    sub rsp, 12
        \\    call _printf
        \\    add rsp, 12
        \\    sub rsp, 4
        \\    mov dword [rbp-8], eax
        \\    mov edi, dword [rbp-8]
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let fd 2)
        \\  (let seek-end 2)
        \\  (let size (lseek fd 0 seek-end))
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 0
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let prot-read 1)
        \\  (let prot-write 2)
        \\  (let prot (bit-or prot-read prot-write))
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 0
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let prot-read i32 1)
        \\  (let prot-write i32 2)
        \\  (bit-or prot-read prot-write))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, dword [rbp-4]
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
        \\(fn start :args () :ret i32
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
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 0
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
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let bytes-read (read -1 null 100))
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 0
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
        \\(fn start :args () :ret i32
        \\  :body (close -1))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, dword [rbp-4]
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
        \\(fn start :args () :ret i32
        \\  :body (munmap null 0))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "copying let" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a 5)
        \\  (let b a)
        \\  (print b))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%ld", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rsi, 5
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "copying typed let" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a 5)
        \\  (let b i32 a)
        \\  (print b))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%d", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov esi, 5
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "pointer decay" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a "text")
        \\  (let p (ptr u8) a)
        \\  (let c (deref p))
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\
        \\    section .data
        \\
        \\byte0: db "text", 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    mov rdi, byte0
        \\    mov qword [rbp-8], rdi
        \\    sub rsp, 1
        \\    mov rdi, qword [rbp-8]
        \\    mov sil, byte [rdi]
        \\    mov byte [rbp-9], sil
        \\    mov edi, 0
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "read file contents to buffer" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let o-rdonly 0)
        \\  (let fd (open "/Users/adamkowalski/code/ra/examples/titanic/train.csv" o-rdonly))
        \\  (let seek-end 2)
        \\  (let len (lseek fd 0 seek-end))
        \\  (let seek-set 0)
        \\  (lseek fd 0 seek-set)
        \\  (let prot-read i32 1)
        \\  (let prot-write i32 2)
        \\  (let prot (bit-or prot-read prot-write))
        \\  (let map-private i32 0)
        \\  (let map-anonymous i32 1)
        \\  (let flags (bit-or map-private map-anonymous))
        \\  (let data (ptr u8) (mmap null len prot flags -1 0))
        \\  (let bytes (read fd data len))
        \\  (close fd)
        \\  (print data)
        \\  (munmap data len))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "/Users/adamkowalski/code/ra/examples/titanic/train.csv", 0
        \\byte1: db "%s", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 0x2000005
        \\    mov rdi, byte0
        \\    mov esi, 0
        \\    xor rdx, rdx
        \\    syscall
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov rax, 0x20000C7
        \\    mov edi, dword [rbp-4]
        \\    mov rsi, 0
        \\    mov edx, 2
        \\    syscall
        \\    sub rsp, 8
        \\    mov qword [rbp-12], rax
        \\    mov rax, 0x20000C7
        \\    mov edi, dword [rbp-4]
        \\    mov rsi, 0
        \\    mov edx, 0
        \\    syscall
        \\    sub rsp, 8
        \\    mov qword [rbp-20], rax
        \\    mov eax, 1
        \\    mov ecx, 2
        \\    or eax, ecx
        \\    sub rsp, 4
        \\    mov dword [rbp-24], eax
        \\    mov eax, 0
        \\    mov ecx, 1
        \\    or eax, ecx
        \\    sub rsp, 4
        \\    mov dword [rbp-28], eax
        \\    mov rax, 0x20000C5
        \\    mov rdi, 0
        \\    mov rsi, qword [rbp-12]
        \\    mov edx, dword [rbp-24]
        \\    mov ecx, dword [rbp-28]
        \\    mov r8d, -1
        \\    mov r9, 0
        \\    mov r10, 0x1002
        \\    syscall
        \\    sub rsp, 8
        \\    mov qword [rbp-36], rax
        \\    mov rax, 0x2000003
        \\    mov edi, dword [rbp-4]
        \\    mov rsi, qword [rbp-36]
        \\    mov rdx, qword [rbp-12]
        \\    syscall
        \\    sub rsp, 8
        \\    mov qword [rbp-44], rax
        \\    mov rax, 0x2000006
        \\    mov edi, dword [rbp-4]
        \\    syscall
        \\    sub rsp, 4
        \\    mov dword [rbp-48], eax
        \\    mov rdi, byte1
        \\    mov rsi, qword [rbp-36]
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-52], eax
        \\    mov rax, 0x2000049
        \\    mov rdi, qword [rbp-36]
        \\    mov rsi, qword [rbp-12]
        \\    syscall
        \\    sub rsp, 4
        \\    mov dword [rbp-56], eax
        \\    mov edi, dword [rbp-56]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "var binding with 1 set" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (var x 0)
        \\  (set! x 5)
        \\  x)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 5
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "var binding with 2 sets" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (var x 0)
        \\  (set! x 5)
        \\  (set! x 10)
        \\  x)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 10
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "pointer arithmetic" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a "hello")
        \\  (let p (ptr u8) a)
        \\  (let p2 (+ p 1))
        \\  (print p2))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "hello", 0
        \\byte1: db "%s", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    mov rdi, byte0
        \\    mov qword [rbp-8], rdi
        \\    mov rax, qword [rbp-8]
        \\    add rax, 1
        \\    sub rsp, 8
        \\    mov qword [rbp-16], rax
        \\    mov rdi, byte1
        \\    mov rsi, qword [rbp-16]
        \\    xor rax, rax
        \\    call _printf
        \\    sub rsp, 4
        \\    mov dword [rbp-20], eax
        \\    mov edi, dword [rbp-20]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "equality between two signed integers" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a u8 10)
        \\  (let b u8 'a')
        \\  (let c (= a b))
        \\  (let d (+ c 48))
        \\  (print d))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
    entities.deinit();
    x86.deinit();
    const expected =
        \\    global _main
        \\    extern _printf
        \\
        \\    section .data
        \\
        \\byte0: db "%c", 10, 0
        \\
        \\    section .text
        \\
        \\_main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov al, 10
        \\    cmp al, 97
        \\    sete al
        \\    sub rsp, 1
        \\    mov byte [rbp-1], al
        \\    mov al, byte [rbp-1]
        \\    add al, 48
        \\    sub rsp, 1
        \\    mov byte [rbp-2], al
        \\    mov sil, byte [rbp-2]
        \\    mov rdi, byte0
        \\    xor rax, rax
        \\    sub rsp, 14
        \\    call _printf
        \\    add rsp, 14
        \\    sub rsp, 4
        \\    mov dword [rbp-6], eax
        \\    mov edi, dword [rbp-6]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "conditional" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let conditional 1)
        \\  (let then i32 5)
        \\  (let else i32 7)
        \\  (if conditional then else))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    cmp rax, 0
        \\    je label1
        \\    mov rax, 5
        \\    jmp label2
        \\
        \\label1:
        \\    mov rax, 7
        \\    jmp label2
        \\
        \\label2:
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}

test "max" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn max :args ((x i32) (y i32)) :ret i32
        \\  :body (if (> x y) x y))
        \\
        \\(fn start :args () :ret i32
        \\  :body (max 5 7))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    var ast = try ra.parse(allocator, &entities, source);
    var ir = try ra.lower(allocator, &entities, ast);
    ast.deinit();
    var x86 = try ra.codegen(allocator, &entities, ir);
    ir.deinit();
    var x86_string = try ra.x86String(allocator, x86, entities);
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
        \\    mov edi, 5
        \\    mov esi, 7
        \\    call label1
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov edi, dword [rbp-4]
        \\    mov rax, 0x02000001
        \\    syscall
        \\
        \\label1:
        \\    push rbp
        \\    mov rbp, rsp
        \\    sub rsp, 8
        \\    mov dword [rbp-4], edi
        \\    mov dword [rbp-8], esi
        \\    mov eax, dword [rbp-4]
        \\    cmp eax, dword [rbp-8]
        \\    setg al
        \\    sub rsp, 1
        \\    mov byte [rbp-9], al
        \\    cmp byte [rbp-9], 0
        \\    je label2
        \\    mov eax, dword [rbp-4]
        \\    jmp label3
        \\
        \\label2:
        \\    mov eax, dword [rbp-8]
        \\    jmp label3
        \\
        \\label3:
        \\    sub rsp, 4
        \\    mov dword [rbp-4], eax
        \\    mov eax, dword [rbp-4]
        \\    pop rbp
        \\    ret
    ;
    expectEqualStrings(x86_string.slice(), expected);
    x86_string.deinit();
}
