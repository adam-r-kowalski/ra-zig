const Module = @import("module.zig").Module;
const List = @import("list.zig").List;
const ast = @import("ast.zig");
const strings = @import("strings.zig");
const EntityId = ast.EntityId;

const Source = struct {
    input: []const u8
};

fn reservedChar(char: u8) bool {
    return switch (char) {
        ' ', '\n', '(', ')' => true,
        else => false,
    };
}

fn insert(module: *Module, source: *Source, kind: ast.Kind, length: usize) !EntityId {
    const string_index = try strings.intern(&module.strings, source.input[0..length]);
    const id = try module.ast.entities.insert(.{ .kind = kind, .foreign_id = string_index });
    source.input = source.input[length..];
    return id;
}

fn number(module: *Module, source: *Source) !EntityId {
    var length: usize = 0;
    while (length < source.input.len) : (length += 1) {
        switch (source.input[length]) {
            '0'...'9' => continue,
            else => break,
        }
    }
    return try insert(module, source, .Int, length);
}

fn identifier(kind: ast.Kind, module: *Module, source: *Source) !EntityId {
    var length: usize = 0;
    while (length < source.input.len and !reservedChar(source.input[length])) : (length += 1) {}
    return try insert(module, source, kind, length);
}

fn listOfType(kind: ast.Kind, delimiter: u8, module: *Module, source: *Source) !EntityId {
    source.input = source.input[1..];
    var children = List(EntityId).init(&module.arena.allocator);
    while (source.input.len > 0 and source.input[0] != delimiter) {
        const id = try expression(module, source);
        _ = try children.insert(id);
    }
    source.input = source.input[1..];
    const children_index = try module.ast.children.insert(children.slice());
    const id = try module.ast.entities.insert(.{ .kind = kind, .foreign_id = children_index });
    return id;
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

fn expression(module: *Module, source: *Source) error{OutOfMemory}!EntityId {
    trimWhitespace(source);
    return switch (source.input[0]) {
        '0'...'9' => try number(module, source),
        '(' => try listOfType(.Parens, ')', module, source),
        '[' => try listOfType(.Brackets, ']', module, source),
        ':' => try identifier(.Keyword, module, source),
        else => try identifier(.Symbol, module, source),
    };
}

pub fn parse(module: *Module, input: []const u8) !void {
    var source = Source{ .input = input };
    while (source.input.len > 0) {
        const id = try expression(module, &source);
        _ = try module.ast.top_level.insert(id);
        trimWhitespace(&source);
    }
}
