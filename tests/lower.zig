const std = @import("std");
const lang = @import("lang");

test "distance" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn distance :args ((x f64) (y f64)) :ret f64
        \\  :body (sqrt (+ (pow x 2) (pow y 2))))
    ;
    var ast = try lang.parse(allocator, source);
    defer ast.arena.deinit();
    var ssa = try lang.lower(allocator, ast);
    defer ssa.arena.deinit();
    var ssa_string = try lang.ssaString(allocator, ast.strings, ssa);
    defer ssa_string.deinit();
    std.testing.expectEqualStrings(ssa_string.slice(),
        \\(fn distance
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :blocks
        \\  (block %b0
        \\    (return f64))
        \\  (block %b1
        \\    (return f64))
        \\  (block %b2
        \\    (return f64))
        \\  (block %b3
        \\    (const %t0 (pow x 2))
        \\    (const %t1 (pow y 2))
        \\    (const %t2 (+ %t0 %t1))
        \\    (const %t3 (sqrt %t2))
        \\    (return %t3)))
    );
}
