const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const ra = @import("ra");
const parse = ra.parse;
var astString = ra.astString;

test "int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "123 475 -923";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Int 123)
        \\(Int 475)
        \\(Int -923)
    );
}

test "float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "12.3 4.75 .923";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Float 12.3)
        \\(Float 4.75)
        \\(Float .923)
    );
}

test "symbol" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "foo bar baz -";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Symbol foo)
        \\(Symbol bar)
        \\(Symbol baz)
        \\(Symbol -)
    );
}

test "keyword" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = ":foo :bar :baz";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Keyword :foo)
        \\(Keyword :bar)
        \\(Keyword :baz)
    );
}

test "character literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source =
        \\'a' 'b' 'c'
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Char 'a')
        \\(Char 'b')
        \\(Char 'c')
    );
}

test "string" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source =
        \\"foo" "bar" "baz"
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(String "foo")
        \\(String "bar")
        \\(String "baz")
    );
}

test "parens" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "(+ 3 7 (* 9 5))";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Parens
        \\  (Symbol +)
        \\  (Int 3)
        \\  (Int 7)
        \\  (Parens
        \\    (Symbol *)
        \\    (Int 9)
        \\    (Int 5)))
    );
}

test "brackets" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "[[1 2] [3 4]]";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Brackets
        \\  (Brackets
        \\    (Int 1)
        \\    (Int 2))
        \\  (Brackets
        \\    (Int 3)
        \\    (Int 4)))
    );
}

test "entry point" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source =
        \\(let start
        \\  (Fn [] I32)
        \\  (fn [] 0))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(Parens
        \\  (Symbol let)
        \\  (Symbol start)
        \\  (Parens
        \\    (Symbol Fn)
        \\    (Brackets)
        \\    (Symbol I32))
        \\  (Parens
        \\    (Symbol fn)
        \\    (Brackets)
        \\    (Int 0)))
    );
}
