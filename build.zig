const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glad = b.addStaticLibrary(.{
        .name = "glad",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    glad.addCSourceFile(.{ .file = .{ .path = "glad/src/glad.c" }, .flags = &.{} });
    glad.addIncludePath(.{ .path = "glad/include" });

    const exe = b.addExecutable(.{
        .name = "gl-sandbox",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.linkLibrary(glad);
    exe.addIncludePath(.{ .path = "glad/include" });
    exe.linkSystemLibrary("glfw3");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
