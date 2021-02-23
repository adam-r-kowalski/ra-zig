const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const lang = @import("lang");
const parse = lang.parse;
const lower = lang.lower;

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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 10
        \\    mov rbx, 15
        \\    add rax, rbx
        \\    pop rbp
        \\    ret
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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 10
        \\    mov rbx, 20
        \\    add rax, rbx
        \\    mov rcx, 30
        \\    add rax, rcx
        \\    pop rbp
        \\    ret
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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 10
        \\    mov rbx, 15
        \\    sub rax, rbx
        \\    pop rbp
        \\    ret
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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 10
        \\    mov rbx, 15
        \\    imul rax, rbx
        \\    pop rbp
        \\    ret
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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 20
        \\    mov rbx, 4
        \\    cqo
        \\    idiv rbx
        \\    pop rbp
        \\    ret
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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 2
        \\    mov rbx, 3
        \\    add rax, rbx
        \\    mov rcx, rax
        \\    mov rax, 30
        \\    cqo
        \\    idiv rcx
        \\    pop rbp
        \\    ret
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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 10
        \\    mov rbx, 7
        \\    sub rax, rbx
        \\    mov rcx, 3
        \\    imul rax, rcx
        \\    mov rdx, 15
        \\    add rax, rdx
        \\    mov rsi, 2
        \\    mov rdi, rdx
        \\    cqo
        \\    idiv rsi
        \\    pop rbp
        \\    ret
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
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    std.testing.expectEqualStrings(x86_string.slice(),
        \\    global _main
        \\
        \\    section .text
        \\
        \\_main:
        \\    call label0
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\label0:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 2
        \\    mov rbx, 3
        \\    add rax, rbx
        \\    mov rcx, 10
        \\    imul rax, rcx
        \\    mov rdx, 5
        \\    mov rsi, rdx
        \\    cqo
        \\    idiv rsi
        \\    pop rbp
        \\    ret
    );
}
