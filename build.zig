const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("ra", "src/main.zig");
    exe.addPackage(.{ .name = "ra", .path = "src/ra.zig" });
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

    const ra_tests = b.addTest("tests/ra.zig");
    ra_tests.addPackage(.{ .name = "ra", .path = "src/ra.zig" });
    ra_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run ra tests");
    test_step.dependOn(&ra_tests.step);
}
