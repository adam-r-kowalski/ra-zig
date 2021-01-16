const std = @import("std");

pub fn List(comptime T: type) type {
    return struct {
        allocator: *std.mem.Allocator,
        items: []T,
        length: usize,
    };
}

pub fn init(comptime T: type, allocator: *std.mem.Allocator) List(T) {
    return List(T){
        .allocator = allocator,
        .items = &[_]T{},
        .length = 0,
    };
}

pub fn deinit(comptime T: type, list: *List(T)) void {
    list.allocator.free(list.items);
}

pub fn insert(comptime T: type, list: *List(T), value: T) !usize {
    const length = list.length;
    if (list.length == list.items.len) {
        const capacity = std.math.max(list.items.len * 2, 2);
        const items = try list.allocator.alloc(T, capacity);
        for (list.items) |e, i| items[i] = e;
        list.allocator.free(list.items);
        list.items = items;
    }
    list.items[length] = value;
    list.length += 1;
    return length;
}

pub fn insertSlice(comptime T: type, list: *List(T), values: []const T) !void {
    for (values) |value| _ = try insert(T, list, value);
}

pub fn slice(comptime T: type, list: List(T)) []const T {
    return list.items[0..list.length];
}
