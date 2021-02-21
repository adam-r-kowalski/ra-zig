const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const expectEqualStrings = std.testing.expectEqualStrings;
const lang = @import("lang");
const parse = lang.parse;
const lower = lang.lower;

test "add" {
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
        \\    mov rdx, 10
        \\    mov rax, 15
        \\    add rax, rdx
        \\    pop rbp
        \\    ret
    );
}
