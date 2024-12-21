const std = @import("std");
const tok = @import("tokenizer.zig");

test "Test tokenizer" {
    const delims = " \n\r";
    const tokenMap = tok.TokenMap.initComptime(&.{
        .{"a", tok.TokenType{.tokenType = 1}},
        .{"ab", tok.TokenType{.tokenType = 10, .priority = 0}},
    });
    const MyTokenizer = tok.Tokenizer(tokenMap, delims);

    const str = "  abcd\nacbd\r\nbaaba\r\naba\nac";
    var tk = MyTokenizer{
        .in_stream = str[0..],
        .cur_idx = 0,
    };

    var token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, 10);
    try std.testing.expectEqual(token.tokenType.priority, 0);
    try std.testing.expect(std.mem.eql(u8, token.value, "ab"));

    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, null);
    try std.testing.expectEqual(token.tokenType.priority, std.math.minInt(isize));
    try std.testing.expect(std.mem.eql(u8, token.value, "cd"));

    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, 1);
    try std.testing.expectEqual(token.tokenType.priority, std.math.minInt(isize));
    try std.testing.expect(std.mem.eql(u8, token.value, "a"));

    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, null);
    try std.testing.expectEqual(token.tokenType.priority, std.math.minInt(isize));
    try std.testing.expect(std.mem.eql(u8, token.value, "cbd"));

    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, null);
    try std.testing.expectEqual(token.tokenType.priority, std.math.minInt(isize));
    try std.testing.expect(std.mem.eql(u8, token.value, "baaba"));

    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, 10);
    try std.testing.expectEqual(token.tokenType.priority, 0);
    try std.testing.expect(std.mem.eql(u8, token.value, "ab"));

    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, 1);
    try std.testing.expectEqual(token.tokenType.priority, std.math.minInt(isize));
    try std.testing.expect(std.mem.eql(u8, token.value, "a"));

    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, 1);
    try std.testing.expectEqual(token.tokenType.priority, std.math.minInt(isize));
    try std.testing.expect(std.mem.eql(u8, token.value, "a"));


    token = tk.get_next_token() catch |err| {
        std.debug.print("Error: out of input stream\n", .{});
        return err;
    };
    try std.testing.expectEqual(token.tokenType.tokenType, null);
    try std.testing.expectEqual(token.tokenType.priority, std.math.minInt(isize));
    try std.testing.expect(std.mem.eql(u8, token.value, "c"));
}
