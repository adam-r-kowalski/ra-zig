const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const lang = @import("lang");
const parse = lang.parse;
var astString = lang.astString;

test "int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "123 475 923";
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
    defer ast_string.deinit();
    expectEqualStrings(ast_string.slice(),
        \\(int 123)
        \\(int 475)
        \\(int 923)
    );
}

test "float" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "12.3 4.75 .923";
    var entities = try lang.data.Entities.init(&gpa.allocator);
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
    const source = "foo bar baz";
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
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
    var entities = try lang.data.Entities.init(&gpa.allocator);
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

test "parens" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const source = "(+ 3 7 (* 9 5))";
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
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
    var entities = try lang.data.Entities.init(&gpa.allocator);
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
    const source = "(fn main :args () :ret i64 :body 0)";
    var entities = try lang.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ast_string = try astString(&gpa.allocator, ast, entities);
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
