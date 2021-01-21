const std = @import("std");
const lang = @import("lang");

test "distance" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn distance :args (x f64 y f64) :ret f64
        \\  :body (sqrt (+ (pow x 2) (pow y 2))))
    ;
    var module = try lang.module.init(allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    try lang.lower(&module);
    var ssa_string = try lang.testing.ssaString(allocator, module);
    defer lang.list.deinit(u8, &ssa_string);
    std.testing.expectEqualStrings(lang.list.slice(u8, ssa_string),
        \\(fn distance
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  (block %b0
        \\    (ret f64))
        \\  (block %b1
        \\    (ret f64))
        \\  (block %b2
        \\    (ret f64))
        \\  (block %b3
        \\    (let %t0 (pow x 2))
        \\    (let %t1 (pow y 2))
        \\    (let %t2 (+ %t0 %t1))
        \\    (let %t3 (sqrt %t2))
        \\    (ret %t3)))
    );
}
