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
        \\(int 123)
        \\(int 475)
        \\(int -923)
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
        \\(float 12.3)
        \\(float 4.75)
        \\(float .923)
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
        \\(symbol foo)
        \\(symbol bar)
        \\(symbol baz)
        \\(symbol -)
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
        \\(keyword :foo)
        \\(keyword :bar)
        \\(keyword :baz)
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
        \\(char 'a')
        \\(char 'b')
        \\(char 'c')
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
        \\(string "foo")
        \\(string "bar")
        \\(string "baz")
    );
}

test "parens" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "(add 3 7 (mul 9 5))";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(parens
        \\  (symbol add)
        \\  (int 3)
        \\  (int 7)
        \\  (parens
        \\    (symbol mul)
        \\    (int 9)
        \\    (int 5)))
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
    const source = "(fn start :args () :ret i32 :body 0)";
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(parens
        \\  (symbol fn)
        \\  (symbol start)
        \\  (keyword :args)
        \\  (parens)
        \\  (keyword :ret)
        \\  (symbol i32)
        \\  (keyword :body)
        \\  (int 0))
    );
}
