const std = @import("std");
const list = @import("list.zig");

pub const Strings = struct {
    data: list.List([]const u8),
    mapping: std.StringHashMap(usize),
};

pub fn init(allocator: *std.mem.Allocator) Strings {
    return .{
        .data = list.init([]const u8, allocator),
        .mapping = std.StringHashMap(usize).init(allocator),
    };
}

pub fn intern(strings: *Strings, string: []const u8) !usize {
    const result = try strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const index = try list.insert([]const u8, &strings.data, string);
    result.entry.value = index;
    return index;
}
