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
        \\  :scopes
        \\  (scope %external
        \\    (entity :name f64)
        \\    (entity :name sqrt)
        \\    (entity :name +)
        \\    (entity :name pow))
        \\  (scope %function
        \\    (entity :name x)
        \\    (entity :name y))
        \\  (scope %s0)
        \\  (scope %s1)
        \\  (scope %s2)
        \\  (scope %s3
        \\    (entity :name %t0 :value 2)
        \\    (entity :name %t1)
        \\    (entity :name %t2 :value 2)
        \\    (entity :name %t3)
        \\    (entity :name %t4)
        \\    (entity :name %t5))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return f64))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return f64))
        \\  (block %b2 :scopes (%external %function %s2)
        \\    :expressions
        \\    (return f64))
        \\  (block %b3 :scopes (%external %function %s3)
        \\    :expressions
        \\    (let %t1 (pow x %t0))
        \\    (let %t3 (pow y %t2))
        \\    (let %t4 (+ %t1 %t3))
        \\    (let %t5 (sqrt %t4))
        \\    (return %t5)))
    );
}

test "max" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn max :args ((x i64) (y i64)) :ret i64
        \\  :body (if (> x y) x y))
    ;
    var ast = try lang.parse(allocator, source);
    defer ast.arena.deinit();
    var ssa = try lang.lower(allocator, ast);
    defer ssa.arena.deinit();
    var ssa_string = try lang.ssaString(allocator, ast.strings, ssa);
    defer ssa_string.deinit();
    std.testing.expectEqualStrings(ssa_string.slice(),
        \\(fn max
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name i64)
        \\    (entity :name >))
        \\  (scope %function
        \\    (entity :name x)
        \\    (entity :name y))
        \\  (scope %s0)
        \\  (scope %s1)
        \\  (scope %s2)
        \\  (scope %s3
        \\    (entity :name %t0))
        \\  (scope %s4)
        \\  (scope %s5)
        \\  (scope %s6
        \\    (entity :name %t1))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i64))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return i64))
        \\  (block %b2 :scopes (%external %function %s2)
        \\    :expressions
        \\    (return i64))
        \\  (block %b3 :scopes (%external %function %s3)
        \\    :expressions
        \\    (let %t0 (> x y))
        \\    (branch %t0 %b4 %b5))
        \\  (block %b4 :scopes (%external %function %s3 %s4)
        \\    :expressions
        \\    (jump %b6))
        \\  (block %b5 :scopes (%external %function %s3 %s5)
        \\    :expressions
        \\    (jump %b6))
        \\  (block %b6 :scopes (%external %function %s3 %s6)
        \\    :expressions
        \\    (let %t1 (phi (%b4 x) (%b5 y)))
        \\    (return %t1)))
    );
}
