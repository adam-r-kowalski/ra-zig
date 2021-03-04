const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Set = @import("lang").data.Set;

test "set insert and lookup" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    var set = Set(usize).init(&gpa.allocator);
    defer set.deinit();
    expect(!set.contains(1));
    try set.insert(1);
    expect(set.contains(1));
    expect(!set.contains(2));
    try set.insert(2);
    expect(set.contains(1));
    expect(set.contains(2));
    expect(!set.contains(3));
    try set.insert(3);
    expect(set.contains(1));
    expect(set.contains(2));
    expect(set.contains(3));
    expectEqual(set.count(), 3);
    {
        var iterator = set.iterator();
        expectEqual(iterator.next().?.key, 1);
        expectEqual(iterator.next().?.key, 2);
        expectEqual(iterator.next().?.key, 3);
        expectEqual(iterator.next(), null);
    }
    try set.insert(2);
    try set.insert(3);
    try set.insert(4);
    try set.insert(5);
    expectEqual(set.count(), 5);
    {
        var iterator = set.iterator();
        expectEqual(iterator.next().?.key, 1);
        expectEqual(iterator.next().?.key, 2);
        expectEqual(iterator.next().?.key, 4);
        expectEqual(iterator.next().?.key, 5);
        expectEqual(iterator.next().?.key, 3);
        expectEqual(iterator.next(), null);
    }
}
