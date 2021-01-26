const std = @import("std");
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const List = @import("list.zig").List;
const Map = @import("map.zig").Map;

const Source = struct {
    input: []const u8
};

pub const Kind = enum(u8) {
    Int,
    Symbol,
    Keyword,
    Parens,
    Brackets,
};

const Strings = struct {
    data: List([]const u8),
    mapping: Map([]const u8, usize),
};

pub const Ast = struct {
    kinds: List(Kind),
    indices: List(usize),
    children: List(List(usize)),
    top_level: List(usize),
    strings: Strings,
    arena: Arena,
};

fn intern(strings: *Strings, string: []const u8) !usize {
    const result = try strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const index = try strings.data.insert(string);
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
    const string_index = try intern(&ast.strings, source.input[0..length]);
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

pub fn parse(allocator: *Allocator, input: []const u8) !Ast {
    var ast: Ast = undefined;
    ast.arena = Arena.init(allocator);
    ast.kinds = List(Kind).init(&ast.arena.allocator);
    ast.indices = List(usize).init(&ast.arena.allocator);
    ast.children = List(List(usize)).init(&ast.arena.allocator);
    ast.top_level = List(usize).init(&ast.arena.allocator);
    ast.strings.data = List([]const u8).init(&ast.arena.allocator);
    ast.strings.mapping = Map([]const u8, usize).init(&ast.arena.allocator);
    var source = Source{ .input = input };
    while (source.input.len > 0) {
        const id = try expression(&ast, &source);
        _ = try ast.top_level.insert(id);
        trimWhitespace(&source);
    }
    return ast;
}

fn writeString(output: *List(u8), strings: Strings, kind: []const u8, index: usize) !void {
    _ = try output.insert('(');
    try output.insertSlice(kind);
    _ = try output.insert(' ');
    try output.insertSlice(strings.data.items[index]);
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
        .Int => try writeString(output, ast.strings, "int", data_index),
        .Symbol => try writeString(output, ast.strings, "symbol", data_index),
        .Keyword => try writeString(output, ast.strings, "keyword", data_index),
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
