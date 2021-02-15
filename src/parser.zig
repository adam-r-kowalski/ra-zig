const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const assert = std.debug.assert;
const data = @import("data.zig");
const Ast = data.ast.Ast;
const Kind = data.ast.Kind;
const Strings = data.ast.Strings;
const InternedStrings = data.ast.InternedStrings;
const Source = data.ast.Source;
const List = data.List;
const Map = data.Map;

fn intern(interned_strings: *InternedStrings, string: []const u8) !usize {
    const result = try interned_strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const index = try interned_strings.data.insert(string);
    result.entry.value = index;
    return index;
}

fn reservedChar(char: u8) bool {
    return switch (char) {
        ' ', '\n', '(', ')' => true,
        else => false,
    };
}

fn insert(kind: Kind, ast: *Ast, source: *Source, length: usize) !usize {
    const string_index = try intern(&ast.interned_strings, source.input[0..length]);
    const kind_index = try ast.kinds.insert(kind);
    _ = try ast.indices.insert(string_index);
    source.input = source.input[length..];
    return kind_index;
}

fn number(ast: *Ast, source: *Source) !usize {
    var length: usize = 0;
    while (length < source.input.len) : (length += 1) {
        switch (source.input[length]) {
            '0'...'9' => continue,
            else => break,
        }
    }
    return try insert(.Int, ast, source, length);
}

fn identifier(kind: Kind, ast: *Ast, source: *Source) !usize {
    var length: usize = 0;
    while (length < source.input.len and !reservedChar(source.input[length])) : (length += 1) {}
    return try insert(kind, ast, source, length);
}

fn list(kind: Kind, delimiter: u8, ast: *Ast, source: *Source) !usize {
    source.input = source.input[1..];
    var children = List(usize).init(ast.children.allocator);
    while (source.input.len > 0 and source.input[0] != delimiter) {
        const id = try expression(ast, source);
        _ = try children.insert(id);
    }
    source.input = source.input[1..];
    const children_index = try ast.children.insert(children);
    const kind_index = try ast.kinds.insert(kind);
    _ = try ast.indices.insert(children_index);
    return kind_index;
}

fn isWhitespace(char: u8) bool {
    return switch (char) {
        ' ', '\n' => true,
        else => false,
    };
}

fn trimWhitespace(source: *Source) void {
    var i: usize = 0;
    while (i < source.input.len and isWhitespace(source.input[i])) : (i += 1) {}
    source.input = source.input[i..];
}

fn expression(ast: *Ast, source: *Source) error{OutOfMemory}!usize {
    trimWhitespace(source);
    return switch (source.input[0]) {
        '0'...'9' => try number(ast, source),
        '(' => try list(.Parens, ')', ast, source),
        '[' => try list(.Brackets, ']', ast, source),
        ':' => try identifier(.Keyword, ast, source),
        else => try identifier(.Symbol, ast, source),
    };
}

fn primeStrings(interned_strings: *InternedStrings) !void {
    const fn_symbol = try intern(interned_strings, "fn");
    const args_keyword = try intern(interned_strings, ":args");
    const ret_keyword = try intern(interned_strings, ":ret");
    const body_keyword = try intern(interned_strings, ":body");
    const if_symbol = try intern(interned_strings, "if");
    const const_symbol = try intern(interned_strings, "const");
    assert(fn_symbol == @enumToInt(Strings.Fn));
    assert(args_keyword == @enumToInt(Strings.Args));
    assert(ret_keyword == @enumToInt(Strings.Ret));
    assert(body_keyword == @enumToInt(Strings.Body));
    assert(if_symbol == @enumToInt(Strings.If));
    assert(const_symbol == @enumToInt(Strings.Const));
}

pub fn parse(arena: *Arena, input: []const u8) !Ast {
    var ast = Ast{
        .kinds = List(Kind).init(&arena.allocator),
        .indices = List(usize).init(&arena.allocator),
        .children = List(List(usize)).init(&arena.allocator),
        .top_level = List(usize).init(&arena.allocator),
        .interned_strings = InternedStrings{
            .data = List([]const u8).init(&arena.allocator),
            .mapping = Map([]const u8, usize).init(&arena.allocator),
        },
        .arena = arena,
    };
    try primeStrings(&ast.interned_strings);
    var source = Source{ .input = input };
    while (source.input.len > 0) {
        const id = try expression(&ast, &source);
        _ = try ast.top_level.insert(id);
        trimWhitespace(&source);
    }
    return ast;
}

fn writeString(output: *List(u8), interned_strings: InternedStrings, kind: []const u8, index: usize) !void {
    _ = try output.insert('(');
    try output.insertSlice(kind);
    _ = try output.insert(' ');
    try output.insertSlice(interned_strings.data.items[index]);
    _ = try output.insert(')');
}

fn writeList(output: *List(u8), ast: Ast, kind: []const u8, index: usize, depth: usize) !void {
    _ = try output.insert('(');
    try output.insertSlice(kind);
    for (ast.children.items[index].slice()) |child| {
        _ = try output.insert('\n');
        try expressionString(output, ast, child, depth + 2);
    }
    _ = try output.insert(')');
}

fn expressionString(output: *List(u8), ast: Ast, index: usize, depth: usize) error{OutOfMemory}!void {
    var i: usize = 0;
    while (i < depth) : (i += 1) _ = try output.insert(' ');
    const data_index = ast.indices.items[index];
    switch (ast.kinds.items[index]) {
        .Int => try writeString(output, ast.interned_strings, "int", data_index),
        .Symbol => try writeString(output, ast.interned_strings, "symbol", data_index),
        .Keyword => try writeString(output, ast.interned_strings, "keyword", data_index),
        .Parens => try writeList(output, ast, "parens", data_index, depth),
        .Brackets => try writeList(output, ast, "brackets", data_index, depth),
    }
}

pub fn astString(allocator: *Allocator, ast: Ast) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    const length = ast.top_level.length;
    for (ast.top_level.slice()) |index, i| {
        try expressionString(&output, ast, index, 0);
        if (i < length - 1) _ = try output.insert('\n');
    }
    return output;
}
