const std = @import("std");
const list = @import("list.zig");
const parser = @import("parser.zig");

test "" {
    std.testing.refAllDecls(@This());
}
