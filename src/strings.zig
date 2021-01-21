const std = @import("std");
const List = @import("list.zig").List;

pub const Strings = struct {
    data: List([]const u8),
    mapping: std.StringHashMap(usize),
};

pub fn init(allocator: *std.mem.Allocator) Strings {
    return .{
        .data = List([]const u8).init(allocator),
        .mapping = std.StringHashMap(usize).init(allocator),
    };
}

pub fn intern(strings: *Strings, string: []const u8) !usize {
    const result = try strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const index = try strings.data.insert(string);
    result.entry.value = index;
    return index;
}
