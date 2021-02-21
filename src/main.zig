const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const lang = @import("lang");

pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();
    const t0 = timer.read();
    // const allocator = std.heap.page_allocator;
    // var arena = Arena.init(allocator);
    // defer arena.deinit();
    // const temp_allocator = &arena.allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;
    const temp_allocator = &gpa.allocator;
    const t1 = timer.read();
    var args = std.process.args();
    _ = args.skip();
    const filename = try args.next(temp_allocator).?;
    defer temp_allocator.free(filename);
    const t2 = timer.read();
    const cwd = std.fs.cwd();
    const source_file = try cwd.openFileZ(filename, .{ .read = true });
    defer source_file.close();
    const source = try source_file.readToEndAlloc(temp_allocator, std.math.maxInt(usize));
    defer temp_allocator.free(source);
    const t3 = timer.read();
    var interned_strings = try lang.data.interned_strings.prime(allocator);
    defer interned_strings.deinit();
    const t4 = timer.read();
    var ast = try lang.parse(allocator, &interned_strings, source);
    defer ast.deinit();
    const t5 = timer.read();
    var ir = try lang.lower(allocator, ast);
    defer ir.deinit();
    const t6 = timer.read();
    var x86 = try lang.codegen(allocator, ir, interned_strings);
    defer x86.deinit();
    const t7 = timer.read();
    var x86_string = try lang.x86String(allocator, x86, interned_strings);
    defer x86_string.deinit();
    const t8 = timer.read();
    const asm_file = try cwd.createFile("temp/code.asm", .{});
    defer asm_file.close();
    try asm_file.writeAll(x86_string.slice());
    const t9 = timer.read();
    _ = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "nasm", "-fmacho64", "temp/code.asm" },
    });
    const t10 = timer.read();
    _ = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "ld", "temp/code.o", "-lSystem", "-o", "temp/code" },
    });
    const t11 = timer.read();
    std.debug.print(
        \\initialize allocator  {}
        \\collecting args       {}
        \\reading source file   {}
        \\init interned strings {}
        \\parsing               {}
        \\lowering              {}
        \\codegen               {}
        \\x86 string            {}
        \\writing asm file      {}
        \\nasm                  {}
        \\ld                    {}
        \\total                 {}
        \\
    , .{
        t1 - t0,
        t2 - t1,
        t3 - t2,
        t4 - t3,
        t5 - t4,
        t6 - t5,
        t7 - t6,
        t8 - t7,
        t9 - t8,
        t10 - t9,
        t11 - t10,
        t11 - t0,
    });
}
