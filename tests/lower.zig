const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const ra = @import("ra");

test "start" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body 0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
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
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return %t0)))
    );
}

test "let binding" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let x 0)
        \\  x)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name x :value 0))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return x)))
    );
}

test "explicitly typed let" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let x i32 0)
        \\  x)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name x :value 0))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return x)))
    );
}

test "copying let" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let x 0)
        \\  (let y x)
        \\  y)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name x :value 0)
        \\    (entity :name y))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (let y x)
        \\    (return y)))
    );
}

test "copying typed let" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let x i32 0)
        \\  (let y i32 x)
        \\  y)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name x :value 0)
        \\    (entity :name y))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (let y x)
        \\    (return y)))
    );
}

test "compound expressions" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn distance :args ((x f64) (y f64)) :ret f64
        \\  :body (sqrt (+ (^ x 2) (^ y 2))))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn distance
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name sqrt)
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
        \\    (let %t1 (^ x %t0))
        \\    (let %t3 (^ y %t2))
        \\    (let %t4 (+ %t1 %t3))
        \\    (let %t5 (sqrt %t4))
        \\    (return %t5)))
    );
}

test "conditionals" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn max :args ((x i32) (y i32)) :ret i32
        \\  :body (if (greater x y) x y))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn max
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name greater))
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
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return i32))
        \\  (block %b2 :scopes (%external %function %s2)
        \\    :expressions
        \\    (return i32))
        \\  (block %b3 :scopes (%external %function %s3)
        \\    :expressions
        \\    (let %t0 (greater x y))
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

test "int literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn sum-of-squares :args ((x i32) (y i32)) :ret i32
        \\  :body
        \\  (let x2 (^ x 2))
        \\  (let y2 (^ y 2))
        \\  (+ x2 y2))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn sum-of-squares
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name ^))
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
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return i32))
        \\  (block %b2 :scopes (%external %function %s2)
        \\    :expressions
        \\    (return i32))
        \\  (block %b3 :scopes (%external %function %s3)
        \\    :expressions
        \\    (let x2 (^ x %t0))
        \\    (let y2 (^ y %t1))
        \\    (let %t2 (+ x2 y2))
        \\    (return %t2)))
    );
}

test "float literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn sum-of-squares :args ((x f64) (y f64)) :ret f64
        \\  :body
        \\  (let x2 (^ x 2.0))
        \\  (let y2 (^ y 2.0))
        \\  (+ x2 y2))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn sum-of-squares
        \\  :parameter-names (x y)
        \\  :parameter-type-blocks (%b0 %b1)
        \\  :return-type-blocks %b2
        \\  :body-block %b3
        \\  :scopes
        \\  (scope %external
        \\    (entity :name ^))
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
        \\    (let x2 (^ x %t0))
        \\    (let y2 (^ y %t1))
        \\    (let %t2 (+ x2 y2))
        \\    (return %t2)))
    );
}

test "string literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let filename "train.csv")
        \\  (open filename))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name filename :value "train.csv")
        \\    (entity :name %t0))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (let %t0 (open filename))
        \\    (return %t0)))
    );
}

test "char literal" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (let a 'a')
        \\  0)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name a :value 'a')
        \\    (entity :name %t0 :value 0))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return %t0)))
    );
}

test "overloading" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn area :args ((c circle)) :ret f64
        \\  :body (* pi (^ (radius c) 2)))
        \\
        \\(fn area :args ((r rectangle)) :ret f64
        \\  :body (* (width r) (height r)))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
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
        \\    (entity :name pi)
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
        \\    (let %t0 (radius c))
        \\    (let %t2 (^ %t0 %t1))
        \\    (let %t3 (* pi %t2))
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
        \\    (let %t0 (width r))
        \\    (let %t1 (height r))
        \\    (let %t2 (* %t0 %t1))
        \\    (return %t2)))
    );
}

test "var binding with 1 set" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (var x 0)
        \\  (set! x 5)
        \\  x)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name x :value 0)
        \\    (entity :name %t0 :value 5))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return %t0)))
    );
}

test "var binding with 2 sets" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (var x 0)
        \\  (set! x 5)
        \\  (set! x 10)
        \\  x)
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name x :value 0)
        \\    (entity :name %t0 :value 5)
        \\    (entity :name %t1 :value 10))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (return %t1)))
    );
}

test "when" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(fn start :args () :ret i32
        \\  :body
        \\  (var a 10)
        \\  (let b u8 1)
        \\  (when b
        \\    (let c 25)
        \\    (set! a (+ a c)))
        \\  (print a))
    ;
    var entities = try ra.data.Entities.init(&gpa.allocator);
    defer entities.deinit();
    var ast = try ra.parse(&gpa.allocator, &entities, source);
    defer ast.deinit();
    var ir = try ra.lower(&gpa.allocator, &entities, ast);
    defer ir.deinit();
    var ir_string = try ra.irString(&gpa.allocator, entities, ir);
    defer ir_string.deinit();
    std.testing.expectEqualStrings(ir_string.slice(),
        \\(fn start
        \\  :parameter-names ()
        \\  :parameter-type-blocks ()
        \\  :return-type-blocks %b0
        \\  :body-block %b1
        \\  :scopes
        \\  (scope %external)
        \\  (scope %function)
        \\  (scope %s0)
        \\  (scope %s1
        \\    (entity :name a :value 10)
        \\    (entity :name b :value 1))
        \\  (scope %s2
        \\    (entity :name %t0 :value unit))
        \\  (scope %s3
        \\    (entity :name c :value 25)
        \\    (entity :name %t1)
        \\    (entity :name %t2 :value unit))
        \\  (scope %s4
        \\    (entity :name %t1))
        \\  :blocks
        \\  (block %b0 :scopes (%external %function %s0)
        \\    :expressions
        \\    (return i32))
        \\  (block %b1 :scopes (%external %function %s1)
        \\    :expressions
        \\    (branch b %b2 %b3))
        \\  (block %b2 :scopes (%external %function %s2)
        \\    :expressions
        \\    (jump %b4))
        \\  (block %b3 :scopes (%external %function %s3)
        \\    :expressions
        \\    (let %t2 (+ a c))
        \\    (jump %b4))
        \\  (block %b3 :scopes (%external %function %s3)
        \\    :expressions
        \\    (let %t3 (phi (%b2 %t0) (%b3 %t1)))
        \\    (let %t4 (phi (%b2 a) (%b3 %t2)))
        \\    (let %t5 (print %t4))
        \\    (return %t5)))
    );
}
