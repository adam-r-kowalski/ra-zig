const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

const List = @import("lang").data.List;

test "list insert and lookup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const iterations = 10;
    var ints = List(usize).init(&gpa.allocator);
    defer ints.deinit();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const index = try ints.insert(i);
        expectEqual(index, i);
    }
    i = 0;
    while (i < iterations) : (i += 1) {
        expectEqual(ints.items[i], i);
    }
}

test "list insert slice" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    var ints = List(usize).init(&gpa.allocator);
    defer ints.deinit();
    try ints.insertSlice(&[_]usize{ 3, 2, 1 });
    expectEqual(ints.length, 3);
    expectEqual(ints.items[0], 3);
    expectEqual(ints.items[1], 2);
    expectEqual(ints.items[2], 1);
}

test "list add one" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const iterations = 10;
    var ints = List(usize).init(&gpa.allocator);
    defer ints.deinit();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try ints.addOne();
        result.ptr.* = i;
        expectEqual(i, result.index);
    }
    i = 0;
    while (i < iterations) : (i += 1) {
        expectEqual(ints.items[i], i);
    }
}
