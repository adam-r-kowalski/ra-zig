const std = @import("std");

pub fn List(comptime T: type) type {
    const Result = struct {
        ptr: *T,
        index: usize,
    };

    return struct {
        allocator: *std.mem.Allocator,
        items: []T,
        length: usize,

        const Self = @This();

        pub fn init(allocator: *std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .items = &[_]T{},
                .length = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        fn ensureCapacity(self: *Self) !void {
            if (self.length < self.items.len)
                return;
            const capacity = std.math.max(self.items.len * 32, 2);
            const items = try self.allocator.alloc(T, capacity);
            for (self.items) |e, i| items[i] = e;
            self.allocator.free(self.items);
            self.items = items;
        }

        pub fn insert(self: *Self, value: T) !usize {
            const length = self.length;
            try self.ensureCapacity();
            self.items[length] = value;
            self.length += 1;
            return length;
        }

        pub fn insertSlice(self: *Self, values: []const T) !void {
            for (values) |value| _ = try self.insert(value);
        }

        pub fn insertFormatted(self: *Self, comptime format: []const u8, args: anytype) !void {
            const buffer = try std.fmt.allocPrint(self.allocator, format, args);
            defer self.allocator.free(buffer);
            return try self.insertSlice(buffer);
        }

        pub fn addOne(self: *Self) !Result {
            const length = self.length;
            try self.ensureCapacity();
            self.length += 1;
            return Result{
                .ptr = &self.items[length],
                .index = length,
            };
        }

        pub fn slice(self: Self) []T {
            return self.items[0..self.length];
        }
    };
}
