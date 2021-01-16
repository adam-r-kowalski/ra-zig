const std = @import("std");
const lang = @import("lang");
const list = lang.list;

test "int" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source = "123 475 923";
    var module = try lang.module.init(&gpa.allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    var ast_string = try lang.testing.astString(&gpa.allocator, module);
    defer lang.list.deinit(u8, &ast_string);
    std.testing.expectEqualStrings(list.slice(u8, ast_string),
        \\(int 123)
        \\(int 475)
        \\(int 923)
    );
}
