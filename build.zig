const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const tok = b.addModule("tok", .{
        .root_source_file = b.path("lib/tokenizer/tokenizer.zig"),
        .target = target,
        .optimize = optimize,
    });

    const aast = b.addModule("aast", .{
        .root_source_file = b.path("lib/aast/aast.zig"),
        .target = target,
        .optimize = optimize,
    });
    aast.addImport("tok", tok);


    const exe = b.addExecutable(.{
        .name = "aast",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("aast", aast);
    exe.root_module.addImport("tok", tok);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_tok_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/tokenizer/tokenizer_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_tok_unit_tests = b.addRunArtifact(lib_tok_unit_tests);
    const test_tok_step = b.step("test_tok", "Run unit tests for tokenizer");
    test_tok_step.dependOn(&run_lib_tok_unit_tests.step);

    const lib_aast_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/aast/aast_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_aast_unit_tests = b.addRunArtifact(lib_aast_unit_tests);
    const test_aast_step = b.step("test_aast", "Run unit tests for tokenizer");
    test_aast_step.dependOn(&run_lib_aast_unit_tests.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_aast_unit_tests.step);
    test_step.dependOn(&run_lib_tok_unit_tests.step);
}
