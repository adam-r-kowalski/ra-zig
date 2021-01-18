const std = @import("std");
const list = @import("lang").list;

const Strings = struct {
    data: list.List([]const u8),
    mapping: std.StringHashMap(usize),
};

fn init(allocator: *std.mem.Allocator) Strings {
    return .{
        .data = list.init([]const u8, allocator),
        .mapping = std.StringHashMap(usize).init(allocator),
    };
}

fn intern(strings: *Strings, string: []const u8) !usize {
    const result = try strings.mapping.getOrPut(string);
    if (result.found_existing)
        return result.entry.value;
    const index = try list.insert([]const u8, &strings.data, string);
    result.entry.value = index;
    return index;
}

fn randomString(allocator: *std.mem.Allocator, random: *std.rand.Random) ![]const u8 {
    const length = random.intRangeAtMost(usize, 1, 100);
    const string = try allocator.alloc(u8, length);
    var i: usize = 0;
    while (i < length) : (i += 1) {
        string[i] = random.int(u8);
    }
    return string;
}

test "string interning" {
    const total_strings = 1000;
    const insertions = 100000;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var strings = init(&arena.allocator);
    var prng = std.rand.DefaultPrng.init(0);
    var i: usize = 0;
    var random_strings = try arena.allocator.alloc([]const u8, total_strings);
    while (i < total_strings) : (i += 1) {
        random_strings[i] = try randomString(&arena.allocator, &prng.random);
    }
    i = 0;
    while (i < insertions) : (i += 1) {
        const index = prng.random.intRangeLessThan(usize, 0, total_strings);
        _ = try intern(&strings, random_strings[index]);
    }
    std.testing.expectEqual(strings.data.length, total_strings);
    std.testing.expectEqual(strings.mapping.count(), total_strings);
    i = 0;
    while (i < total_strings) : (i += 1) {
        const index = strings.mapping.get(random_strings[i]).?;
        std.testing.expectEqualStrings(strings.data.items[index], random_strings[i]);
    }
}
