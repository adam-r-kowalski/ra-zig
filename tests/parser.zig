const std = @import("std");
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const lang = @import("lang");
const parse = lang.parse;
var astString = lang.astString;

test "int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "123 475 923";
    var ast = try parse(&gpa.allocator, source);
    defer ast.arena.deinit();
    var ast_string = try astString(&gpa.allocator, ast);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(int 123)
        \\(int 475)
        \\(int 923)
    );
}

test "symbol" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "foo bar baz";
    var ast = try parse(&gpa.allocator, source);
    defer ast.arena.deinit();
    var ast_string = try astString(&gpa.allocator, ast);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(symbol foo)
        \\(symbol bar)
        \\(symbol baz)
    );
}

test "keyword" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = ":foo :bar :baz";
    var ast = try parse(&gpa.allocator, source);
    defer ast.arena.deinit();
    var ast_string = try astString(&gpa.allocator, ast);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(keyword :foo)
        \\(keyword :bar)
        \\(keyword :baz)
    );
}

test "parens" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "(+ 3 7 (* 9 5))";
    var ast = try parse(&gpa.allocator, source);
    defer ast.arena.deinit();
    var ast_string = try astString(&gpa.allocator, ast);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(parens
        \\  (symbol +)
        \\  (int 3)
        \\  (int 7)
        \\  (parens
        \\    (symbol *)
        \\    (int 9)
        \\    (int 5)))
    );
}

test "brackets" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "[[1 2] [3 4]]";
    var ast = try parse(&gpa.allocator, source);
    defer ast.arena.deinit();
    var ast_string = try astString(&gpa.allocator, ast);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(brackets
        \\  (brackets
        \\    (int 1)
        \\    (int 2))
        \\  (brackets
        \\    (int 3)
        \\    (int 4)))
    );
}

test "entry point" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "(fn main :args () :ret i64 :body 0)";
    var ast = try parse(&gpa.allocator, source);
    defer ast.arena.deinit();
    var ast_string = try astString(&gpa.allocator, ast);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(parens
        \\  (symbol fn)
        \\  (symbol main)
        \\  (keyword :args)
        \\  (parens)
        \\  (keyword :ret)
        \\  (symbol i64)
        \\  (keyword :body)
        \\  (int 0))
    );
}
