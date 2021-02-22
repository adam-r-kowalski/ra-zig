const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const lang = @import("lang");
const parse = lang.parse;
const lower = lang.lower;

test "add two constants" {
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
        \\    call main
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\main:
        \\    push rbp
        \\    mov rbp, rsp
        \\    mov rax, 10
        \\    mov rbx, 15
        \\    add rax, rbx
        \\    pop rbp
        \\    ret
    );
}

test "add three constants" {
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
        \\    call main
        \\    mov rdi, rax
        \\    mov rax, 33554433
        \\    syscall
        \\
        \\main:
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
