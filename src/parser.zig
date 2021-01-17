const Module = @import("module.zig").Module;
const list = @import("list.zig");
const ast = @import("ast.zig");

const Source = struct {
    input: []const u8
};

fn number(module: *Module, source: *Source) !usize {
    var i: usize = 0;
    while (i < source.input.len) : (i += 1) {
        switch (source.input[i]) {
            '0'...'9' => continue,
            else => break,
        }
    }
    const kind_index = try list.insert(ast.Kind, &module.ast.kinds, .Int);
    const literal_index = try list.insert([]const u8, &module.ast.literals, source.input[0..i]);
    _ = try list.insert(usize, &module.ast.indices, literal_index);
    source.input = source.input[i..];
    return kind_index;
}

fn parens(module: *Module, source: *Source) !usize {
    source.input = source.input[1..];
    var children = list.init(usize, &module.arena.allocator);
    while (source.input.len > 0 and source.input[0] != ')') {
        const index = try expression(module, source);
        _ = try list.insert(usize, &children, index);
    }
    source.input = source.input[1..];
    const kind_index = try list.insert(ast.Kind, &module.ast.kinds, .Parens);
    const children_index = try list.insert([]const usize, &module.ast.children, list.slice(usize, children));
    _ = try list.insert(usize, &module.ast.indices, children_index);
    return kind_index;
}

fn reservedChar(char: u8) bool {
    return switch (char) {
        ' ', '\n', '(', ')' => true,
        else => false,
    };
}

fn identifier(kind: ast.Kind, module: *Module, source: *Source) !usize {
    var i: usize = 0;
    while (i < source.input.len and !reservedChar(source.input[i])) : (i += 1) {}
    const kind_index = try list.insert(ast.Kind, &module.ast.kinds, kind);
    const literal_index = try list.insert([]const u8, &module.ast.literals, source.input[0..i]);
    _ = try list.insert(usize, &module.ast.indices, literal_index);
    source.input = source.input[i..];
    return kind_index;
}

fn trimWhitespace(source: *Source) void {
    var i: usize = 0;
    while (i < source.input.len and source.input[i] == ' ') : (i += 1) {}
    source.input = source.input[i..];
}

fn expression(module: *Module, source: *Source) error{OutOfMemory}!usize {
    trimWhitespace(source);
    return switch (source.input[0]) {
        '0'...'9' => try number(module, source),
        '(' => try parens(module, source),
        ':' => try identifier(.Keyword, module, source),
        else => try identifier(.Symbol, module, source),
    };
}

pub fn parse(module: *Module, input: []const u8) !void {
    var source = Source{ .input = input };
    while (source.input.len > 0) {
        const index = try expression(module, &source);
        _ = try list.insert(usize, &module.ast.top_level, index);
    }
}
