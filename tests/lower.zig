const std = @import("std");
const lang = @import("lang");

test "ssa form" {
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
        \\    (const %t1 (pow x %t0))
        \\    (const %t3 (pow y %t2))
        \\    (const %t4 (+ %t1 %t3))
        \\    (const %t5 (sqrt %t4))
        \\    (return %t5)))
    );
}

test "conditionals" {
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
        \\    (const %t0 (> x y))
        \\    (branch %t0 %b4 %b5))
        \\  (block %b4 :scopes (%external %function %s3 %s4)
        \\    :expressions
        \\    (jump %b6))
        \\  (block %b5 :scopes (%external %function %s3 %s5)
        \\    :expressions
        \\    (jump %b6))
        \\  (block %b6 :scopes (%external %function %s3 %s6)
        \\    :expressions
        \\    (const %t1 (phi (%b4 x) (%b5 y)))
        \\    (return %t1)))
    );
}

test "constants" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    const source =
        \\(fn sum-of-squares :args ((x i64) (y i64)) :ret i64
        \\  :body
        \\  (const x2 (pow x 2))
        \\  (const y2 (pow y 2))
        \\  (+ x2 y2))
    ;
    var ast = try lang.parse(allocator, source);
    defer ast.arena.deinit();
    var ssa = try lang.lower(allocator, ast);
    defer ssa.arena.deinit();
    var ssa_string = try lang.ssaString(allocator, ast.strings, ssa);
    defer ssa_string.deinit();
    std.testing.expectEqualStrings(ssa_string.slice(),
        \\(fn sum-of-squares
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name i64)
        \\    (entity :name pow)
        \\    (entity :name +))
        \\  (scope %function
        \\    (entity :name x)
        \\    (entity :name y))
        \\  (scope %s0)
        \\  (scope %s1)
        \\  (scope %s2)
        \\  (scope %s3
        \\    (entity :name %t0 :value 2)
        \\    (entity :name x2)
        \\    (entity :name %t1 :value 2)
        \\    (entity :name y2)
        \\    (entity :name %t2))
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
        \\    (const x2 (pow x %t0))
        \\    (const y2 (pow y %t1))
        \\    (const %t2 (+ x2 y2))
        \\    (return %t2)))
    );
}
