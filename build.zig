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

    const lex = b.addModule("lex", .{
        .root_source_file = b.path("lib/lexer/lexer.zig"),
        .target = target,
        .optimize = optimize,
    });
    lex.addImport("tok", tok);

    const ast = b.addModule("ast", .{
        .root_source_file = b.path("lib/ast/ast.zig"),
        .target = target,
        .optimize = optimize,
    });
    ast.addImport("lex", lex);
    ast.addImport("tok", tok);


    const exe = b.addExecutable(.{
        .name = "ast",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("ast", ast);
    exe.root_module.addImport("lex", lex);
    exe.root_module.addImport("tok", tok);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TODO: Add lexer unit tests
    const lib_tok_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/tokenizer/tokenizer_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_tok_unit_tests = b.addRunArtifact(lib_tok_unit_tests);
    const test_tok_step = b.step("test_tok", "Run unit tests for tokenizer");
    test_tok_step.dependOn(&run_lib_tok_unit_tests.step);

    const lib_lex_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/lexer/lexer_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_lex_unit_tests.root_module.addImport("tok", tok);

    const run_lib_lex_unit_tests = b.addRunArtifact(lib_lex_unit_tests);
    const test_lex_step = b.step("test_lex", "Run unit tests for lexer");
    test_lex_step.dependOn(&run_lib_lex_unit_tests.step);

    const lib_ast_unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/ast/ast_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_ast_unit_tests.root_module.addImport("tok", tok);
    lib_ast_unit_tests.root_module.addImport("lex", lex);
    lib_ast_unit_tests.root_module.addImport("ast", ast);

    const run_lib_ast_unit_tests = b.addRunArtifact(lib_ast_unit_tests);
    const test_ast_step = b.step("test_ast", "Run unit tests for ast builder");
    test_ast_step.dependOn(&run_lib_ast_unit_tests.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_ast_unit_tests.step);
    test_step.dependOn(&run_lib_tok_unit_tests.step);
}
