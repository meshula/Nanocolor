const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "nanocolor",
        .root_source_file = b.path("nanocolor.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const exe_tests = b.addTest(.{
        .root_source_file = b.path("nanocolor.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run the tests");
    test_step.dependOn(&exe_tests.step);
}
