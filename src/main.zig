const std = @import("std");
const lang = @import("lang");

pub fn main() anyerror!void {
    var timer = try std.time.Timer.start();
    const t0 = timer.read();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = &arena.allocator;
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer std.debug.assert(!gpa.deinit());
    // const allocator = &gpa.allocator;
    const t1 = timer.read();
    var args = std.process.args();
    _ = args.skip();
    const filename = try args.next(allocator).?;
    defer allocator.free(filename);
    const t2 = timer.read();
    const cwd = std.fs.cwd();
    const source_file = try cwd.openFileZ(filename, .{ .read = true });
    defer source_file.close();
    const source = try source_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(source);
    const t3 = timer.read();
    var module = try lang.module.init(allocator);
    defer lang.module.deinit(&module);
    try lang.parse(&module, source);
    const t4 = timer.read();
    var x86 = try lang.codegen(allocator, module);
    defer lang.list.deinit(u8, &x86);
    const t5 = timer.read();
    const asm_file = try cwd.createFile("temp/code.asm", .{});
    defer asm_file.close();
    try asm_file.writeAll(lang.list.slice(u8, x86));
    const t6 = timer.read();
    _ = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "nasm", "-fmacho64", "temp/code.asm" },
    });
    const t7 = timer.read();
    _ = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "ld", "temp/code.o", "-lSystem", "-o", "temp/code" },
    });
    const t8 = timer.read();
    std.debug.print(
        \\initialize allocator {}
        \\collecting args      {}
        \\reading source file  {}
        \\parsing              {}
        \\codegen              {}
        \\writing asm file     {}
        \\nasm                 {}
        \\ld                   {}
        \\total                {}
    , .{
        t1 - t0,
        t2 - t1,
        t3 - t2,
        t4 - t3,
        t5 - t4,
        t6 - t5,
        t7 - t6,
        t8 - t7,
        t8 - t0,
    });
}
