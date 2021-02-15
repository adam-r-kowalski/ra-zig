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
    var arena = Arena.init(allocator);
    defer arena.deinit();
    const ast = try parse(&arena, source);
    const ir = try lower(&arena, ast);
    var x86 = try lang.codegen(allocator, ir, ast.interned_strings);
    defer x86.arena.deinit();
}
