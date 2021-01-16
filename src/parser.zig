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

fn trimWhitespace(source: *Source) void {
    var i: usize = 0;
    while (i < source.input.len and source.input[i] == ' ') : (i += 1) {}
    source.input = source.input[i..];
}

fn expression(module: *Module, source: *Source) !usize {
    trimWhitespace(source);
    return switch (source.input[0]) {
        '0'...'9' => try number(module, source),
        else => @panic("not supported"),
    };
}

pub fn parse(module: *Module, input: []const u8) !void {
    var source = Source{ .input = input };
    while (source.input.len > 0) {
        const index = try expression(module, &source);
        _ = try list.insert(usize, &module.ast.top_level, index);
    }
}
