const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const lang = @import("lang");

test "main" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn main :args () :ret i64
        \\  :body 0)
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var ir_string = try lang.irString(&gpa.allocator, interned_strings, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn main
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name %t0 :value 0))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i64))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return %t0)))
    );
}

test "unicode characters and compound expressions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn distance :args ((x f64) (y f64)) :ret f64
        \\  :body (√ (+ (^ x 2) (^ y 2))))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var ir_string = try lang.irString(&gpa.allocator, interned_strings, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn distance
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name √)
        \\    (entity :name +)
        \\    (entity :name ^))
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
        \\    (const %t1 (^ x %t0))
        \\    (const %t3 (^ y %t2))
        \\    (const %t4 (+ %t1 %t3))
        \\    (const %t5 (√ %t4))
        \\    (return %t5)))
    );
}

test "conditionals" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn max :args ((x i64) (y i64)) :ret i64
        \\  :body (if (> x y) x y))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var ir_string = try lang.irString(&gpa.allocator, interned_strings, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn max
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
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

test "int constants" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn sum-of-squares :args ((x i64) (y i64)) :ret i64
        \\  :body
        \\  (const x2 (^ x 2))
        \\  (const y2 (^ y 2))
        \\  (+ x2 y2))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var ir_string = try lang.irString(&gpa.allocator, interned_strings, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn sum-of-squares
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name ^)
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
        \\    (const x2 (^ x %t0))
        \\    (const y2 (^ y %t1))
        \\    (const %t2 (+ x2 y2))
        \\    (return %t2)))
    );
}

test "float constants" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn sum-of-squares :args ((x f64) (y f64)) :ret f64
        \\  :body
        \\  (const x2 (^ x 2.0))
        \\  (const y2 (^ y 2.0))
        \\  (+ x2 y2))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var ir_string = try lang.irString(&gpa.allocator, interned_strings, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn sum-of-squares
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name ^)
        \\    (entity :name +))
        \\  (scope %function
        \\    (entity :name x)
        \\    (entity :name y))
        \\  (scope %s0)
        \\  (scope %s1)
        \\  (scope %s2)
        \\  (scope %s3
        \\    (entity :name %t0 :value 2.0)
        \\    (entity :name x2)
        \\    (entity :name %t1 :value 2.0)
        \\    (entity :name y2)
        \\    (entity :name %t2))
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
        \\    (const x2 (^ x %t0))
        \\    (const y2 (^ y %t1))
        \\    (const %t2 (+ x2 y2))
        \\    (return %t2)))
    );
}

test "overloading" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn area :args ((c circle)) :ret f64
        \\  :body (* π (^ (radius c) 2)))
        \\
        \\(fn area :args ((r rectangle)) :ret f64
        \\  :body (* (width r) (height r)))
    ;
    var interned_strings = try lang.data.interned_strings.prime(&gpa.allocator);
    defer interned_strings.deinit();
    var ast = try lang.parse(&gpa.allocator, &interned_strings, source);
    defer ast.deinit();
    var ir = try lang.lower(&gpa.allocator, ast);
    defer ir.deinit();
    var ir_string = try lang.irString(&gpa.allocator, interned_strings, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn area
        \\  :parameter-names (c)
        \\  :parameter-type-blocks (%b0)
        \\  :return-type-blocks %b1
        \\  :body-block %b2
        \\  :scopes
        \\  (scope %external
        \\    (entity :name circle)
        \\    (entity :name *)
        \\    (entity :name π)
        \\    (entity :name ^)
        \\    (entity :name radius))
        \\  (scope %function
        \\    (entity :name c))
        \\  (scope %s0)
        \\  (scope %s1)
        \\  (scope %s2
        \\    (entity :name %t0)
        \\    (entity :name %t1 :value 2)
        \\    (entity :name %t2)
        \\    (entity :name %t3))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return circle))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return f64))
        \\  (block %b2 :scopes (%external %function %s2)
        \\    :expressions
        \\    (const %t0 (radius c))
        \\    (const %t2 (^ %t0 %t1))
        \\    (const %t3 (* π %t2))
        \\    (return %t3)))
        \\
        \\(fn area
        \\  :parameter-names (r)
        \\  :parameter-type-blocks (%b0)
        \\  :return-type-blocks %b1
        \\  :body-block %b2
        \\  :scopes
        \\  (scope %external
        \\    (entity :name rectangle)
        \\    (entity :name *)
        \\    (entity :name width)
        \\    (entity :name height))
        \\  (scope %function
        \\    (entity :name r))
        \\  (scope %s0)
        \\  (scope %s1)
        \\  (scope %s2
        \\    (entity :name %t0)
        \\    (entity :name %t1)
        \\    (entity :name %t2))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return rectangle))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return f64))
        \\  (block %b2 :scopes (%external %function %s2)
        \\    :expressions
        \\    (const %t0 (width r))
        \\    (const %t1 (height r))
        \\    (const %t2 (* %t0 %t1))
        \\    (return %t2)))
    );
}
