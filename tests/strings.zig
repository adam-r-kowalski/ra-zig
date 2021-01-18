const std = @import("std");
const strings = @import("lang").strings;

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
    var pool = strings.init(&arena.allocator);
    var prng = std.rand.DefaultPrng.init(0);
    var i: usize = 0;
    var random_strings = try arena.allocator.alloc([]const u8, total_strings);
    while (i < total_strings) : (i += 1) {
        random_strings[i] = try randomString(&arena.allocator, &prng.random);
    }
    i = 0;
    while (i < insertions) : (i += 1) {
        const index = prng.random.intRangeLessThan(usize, 0, total_strings);
        _ = try strings.intern(&pool, random_strings[index]);
    }
    std.testing.expectEqual(pool.data.length, total_strings);
    std.testing.expectEqual(pool.mapping.count(), total_strings);
    i = 0;
    while (i < total_strings) : (i += 1) {
        const index = pool.mapping.get(random_strings[i]).?;
        std.testing.expectEqualStrings(pool.data.items[index], random_strings[i]);
    }
}
