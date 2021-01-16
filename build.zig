const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("lang", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lang_tests = b.addTest("tests/lang.zig");
    lang_tests.addPackage(.{ .name = "lang", .path = "src/lang.zig" });
    lang_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run lang tests");
    test_step.dependOn(&lang_tests.step);
}
