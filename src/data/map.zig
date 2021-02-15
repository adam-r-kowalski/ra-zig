const std = @import("std");

pub fn Map(comptime Key: type, comptime Value: type) type {
    return if (Key == []const u8) std.StringHashMap(Value) else std.AutoHashMap(Key, Value);
}
