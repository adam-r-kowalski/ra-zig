test "all tests" {
    _ = @import("x86_codegen.zig");
    _ = @import("list.zig");
    _ = @import("lower.zig");
    _ = @import("parser.zig");
    _ = @import("set.zig");
}
