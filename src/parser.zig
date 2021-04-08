const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const assert = std.debug.assert;
const data = @import("data.zig");
const Ast = data.ast.Ast;
const Kind = data.ast.Kind;
const Source = data.ast.Source;
const InternedStrings = data.entity.InternedStrings;
const Strings = data.entity.Strings;
const internString = data.entity.internString;
const Entities = data.entity.Entities;
const List = data.List;
const Map = data.Map;

fn reservedChar(char: u8) bool {
    return switch (char) {
        ' ', '\n', '(', ')' => true,
        else => false,
    };
}

fn insert(kind: Kind, ast: *Ast, entities: *Entities, source: *Source, length: usize) !usize {
    const string_index = try internString(entities, source.input[0..length]);
    const kind_index = try ast.kinds.insert(kind);
    _ = try ast.indices.insert(string_index);
    source.input = source.input[length..];
    return kind_index;
}

fn number(ast: *Ast, entities: *Entities, source: *Source, seen_decimal: usize) !usize {
    var decimal_count = seen_decimal;
    var length: usize = 0;
    while (length < source.input.len) : (length += 1) {
        switch (source.input[length]) {
            '0'...'9' => continue,
            '.' => decimal_count += 1,
            else => break,
        }
    }
    const kind = if (decimal_count > 0) Kind.Float else Kind.Int;
    return try insert(kind, ast, entities, source, length);
}

fn identifier(kind: Kind, ast: *Ast, entities: *Entities, source: *Source) !usize {
    var length: usize = 0;
    while (length < source.input.len and !reservedChar(source.input[length])) : (length += 1) {}
    return try insert(kind, ast, entities, source, length);
}

fn list(kind: Kind, delimiter: u8, ast: *Ast, entities: *Entities, source: *Source) !usize {
    source.input = source.input[1..];
    var children = List(usize).init(ast.children.allocator);
    while (source.input.len > 0 and source.input[0] != delimiter) {
        const id = try expression(ast, entities, source);
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

fn expression(ast: *Ast, entities: *Entities, source: *Source) error{OutOfMemory}!usize {
    trimWhitespace(source);
    return switch (source.input[0]) {
        '0'...'9' => try number(ast, entities, source, 0),
        '.' => try number(ast, entities, source, 1),
        '(' => try list(.Parens, ')', ast, entities, source),
        '[' => try list(.Brackets, ']', ast, entities, source),
        ':' => try identifier(.Keyword, ast, entities, source),
        else => try identifier(.Symbol, ast, entities, source),
    };
}

pub fn parse(allocator: *Allocator, entities: *Entities, input: []const u8) !Ast {
    const arena = try allocator.create(Arena);
    arena.* = Arena.init(allocator);
    var ast = Ast{
        .arena = arena,
        .kinds = List(Kind).init(&arena.allocator),
        .indices = List(usize).init(&arena.allocator),
        .children = List(List(usize)).init(&arena.allocator),
        .top_level = List(usize).init(&arena.allocator),
    };
    var source = Source{ .input = input };
    while (source.input.len > 0) {
        const id = try expression(&ast, entities, &source);
        _ = try ast.top_level.insert(id);
        trimWhitespace(&source);
    }
    return ast;
}

fn writeString(output: *List(u8), entities: Entities, kind: []const u8, index: usize) !void {
    _ = try output.insert('(');
    try output.insertSlice(kind);
    _ = try output.insert(' ');
    try output.insertSlice(entities.interned_strings.data.items[index]);
    _ = try output.insert(')');
}

fn writeList(output: *List(u8), ast: Ast, entities: Entities, kind: []const u8, index: usize, depth: usize) !void {
    _ = try output.insert('(');
    try output.insertSlice(kind);
    for (ast.children.items[index].slice()) |child| {
        _ = try output.insert('\n');
        try expressionString(output, ast, entities, child, depth + 2);
    }
    _ = try output.insert(')');
}

fn expressionString(output: *List(u8), ast: Ast, entities: Entities, index: usize, depth: usize) error{OutOfMemory}!void {
    var i: usize = 0;
    while (i < depth) : (i += 1) _ = try output.insert(' ');
    const data_index = ast.indices.items[index];
    switch (ast.kinds.items[index]) {
        .Int => try writeString(output, entities, "int", data_index),
        .Float => try writeString(output, entities, "float", data_index),
        .Symbol => try writeString(output, entities, "symbol", data_index),
        .Keyword => try writeString(output, entities, "keyword", data_index),
        .Parens => try writeList(output, ast, entities, "parens", data_index, depth),
        .Brackets => try writeList(output, ast, entities, "brackets", data_index, depth),
    }
}

pub fn astString(allocator: *Allocator, ast: Ast, entities: Entities) !List(u8) {
    var output = List(u8).init(allocator);
    errdefer output.deinit();
    const length = ast.top_level.length;
    for (ast.top_level.slice()) |index, i| {
        try expressionString(&output, ast, entities, index, 0);
        if (i < length - 1) _ = try output.insert('\n');
    }
    return output;
}
