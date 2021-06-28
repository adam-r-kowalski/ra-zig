const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const ra = @import("ra");

test "start" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.testing.expect(!gpa.deinit());
    const source =
        \\(let start
        \\  (Fn [] I32)
        \\  (fn [] 0))
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
        \\(let start
        \\  (Fn [] I32)
        \\  (fn []
        \\    (let x 0)
        \\    x))
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
        \\(let start
        \\  (Fn [] I32)
        \\  (fn []
        \\    (let x I32 0)
        \\    x))
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
        \\(let start
        \\  (Fn [] I32)
        \\  (fn []
        \\    (let x 0)
        \\    (let y x)
        \\    y))
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
        \\(let start
        \\  (Fn [] I32)
        \\  (fn []
        \\    (let x I32 0)
        \\    (let y I32 x)
        \\    y))
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
        \\(let distance
        \\  (Fn [F64 F64] F64)
        \\  (fn [x y] (sqrt (add (pow x 2) (pow y 2)))))
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
        \\(let max
        \\  (Fn [I32 I32] I32)
        \\  (fn [x y] (if (eql (cmp x y) 1) x y)))
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
        \\(let sum-of-squares
        \\  (Fn [I32 I32] I32)
        \\  (fn [x y]
        \\    (let x2 (pow x 2))
        \\    (let y2 (pow y 2))
        \\    (add x2 y2)))
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
        \\(let sum-of-squares
        \\  (Fn [F64 F64] F64)
        \\  (fn [x y]
        \\    (let x2 (pow x 2.0))
        \\    (let y2 (pow y 2.0))
        \\    (add x2 y2)))
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
        \\(let start
        \\  (Fn [] I32)
        \\  (fn []
        \\    (let filename "train.csv")
        \\    (open filename)))
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
        \\(let start :args () :ret i32
        \\  (Fn [] I32)
        \\  (fn []
        \\    (let a 'a')
        \\    0))
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
