const std = @import("std");

const list = @import("lang").list;

test "list insert and lookup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const iterations = 10;
    var ints = list.init(usize, &gpa.allocator);
    defer list.deinit(usize, &ints);
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const index = try list.insert(usize, &ints, i);
        std.testing.expectEqual(index, i);
    }
    i = 0;
    while (i < iterations) : (i += 1) {
        std.testing.expectEqual(ints.items[i], i);
    }
}

test "list insert slice" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    var ints = list.init(usize, &gpa.allocator);
    defer list.deinit(usize, &ints);
    try list.insertSlice(usize, &ints, &[_]usize{ 3, 2, 1 });
    std.testing.expectEqual(ints.length, 3);
    std.testing.expectEqual(ints.items[0], 3);
    std.testing.expectEqual(ints.items[1], 2);
    std.testing.expectEqual(ints.items[2], 1);
}

test "list add one" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const iterations = 10;
    var ints = list.init(usize, &gpa.allocator);
    defer list.deinit(usize, &ints);
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = try list.addOne(usize, &ints);
        result.ptr.* = i;
        std.testing.expectEqual(i, result.index);
    }
    i = 0;
    while (i < iterations) : (i += 1) {
        std.testing.expectEqual(ints.items[i], i);
    }
}
