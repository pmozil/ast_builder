const std = @import("std");
const tok = @import("tok");


pub fn main() !void {
    const delims = " \n\r";
    const tokenMap = tok.TokenMap.initComptime(&.{
        .{"a", 10},
        .{"ab", 10},
    });
    const MyTokenizer = tok.Tokenizer(tokenMap, delims);

    const str = "  abcd abcd";
    var tk = MyTokenizer{
        .in_stream = str[0..],
        .cur_idx = 0,
    };

    while(true) {
        const token = tk.get_next_token() catch {
            std.debug.print("Error: out of input stream\n", .{});
            break;
        };
        std.debug.print("Type: {}, Value: {s}\n", .{token.tokenType orelse 0, token.value});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
