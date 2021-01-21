const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const lang = @import("lang");
const Table = lang.Table;

test "type info" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const people = Table(.{
        .name = "people",
        .columns = struct {
            name: []const u8,
            age: u8,
        },
    }).init(allocator);
    const type_info = @typeInfo(@TypeOf(people.data)).Struct;
    expectEqual(type_info.layout, .Auto);
    expectEqual(type_info.fields.len, 2);
    {
        const field = type_info.fields[0];
        expectEqualStrings(field.name, "name");
        expectEqual(field.field_type, [][]const u8);
        expectEqual(field.default_value, &[_][]const u8{});
        expect(!field.is_comptime);
        expectEqual(field.alignment, 8);
    }
    {
        const field = type_info.fields[1];
        expectEqualStrings(field.name, "age");
        expectEqual(field.field_type, []u8);
        expectEqual(field.default_value, &[_]u8{});
        expect(!field.is_comptime);
        expectEqual(field.alignment, 8);
    }
    expectEqual(type_info.decls.len, 0);
    expect(!type_info.is_tuple);
}

test "create table, insert and lookup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;
    var people = Table(.{
        .name = "people",
        .columns = struct {
            name: []const u8,
            age: u8,
        },
    }).init(allocator);
    const id = try people.insert(.{ .name = "joe", .age = 20 });
    const joe = people.lookup(id);
    expectEqualStrings(joe.name, "joe");
    expectEqual(joe.age, 20);
}

test "create many" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;
    var table = Table(.{
        .name = "table",
        .columns = struct {
            i: usize,
            j: usize,
            k: usize,
        },
    }).init(allocator);
    const Id = lang.Id("table");
    var i: usize = 0;
    const iterations = 1000;
    while (i < iterations) : (i += 1)
        _ = try table.insert(.{ .i = i, .j = i * 2, .k = i * 3 });
    i = 0;
    while (i < iterations) : (i += 1) {
        const row = table.lookup(Id{ .index = i });
        expectEqual(row.i, i);
        expectEqual(row.j, i * 2);
        expectEqual(row.k, i * 3);
    }
}

test "unique" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;
    var table = Table(.{
        .name = "table",
        .unique = &.{"i"},
        .columns = struct {
            i: usize,
            j: usize,
            k: usize,
        },
    }).init(allocator);
    const Id = lang.Id("table");
    var i: usize = 0;
    const iterations = 1000;
}
