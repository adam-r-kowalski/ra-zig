const std = @import("std");
const Allocator = std.mem.Allocator;
const Map = @import("map.zig").Map;

pub fn Set(comptime T: type) type {
    const MapT = Map(T, void);

    return struct {
        map: MapT,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return .{
                .map = Map(T, void).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn insert(self: *Self, value: T) !void {
            try self.map.put(value, undefined);
        }

        pub fn contains(self: Self, value: T) bool {
            return self.map.get(value) != null;
        }

        pub fn count(self: Self) usize {
            return self.map.count();
        }

        pub fn iterator(self: *const Self) MapT.Iterator {
            return self.map.iterator();
        }
    };
}
