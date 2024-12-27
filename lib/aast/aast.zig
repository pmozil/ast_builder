const std = @import("std");
const lex = @import("lex");

const ArrayList = std.ArrayList;

const AST = struct {
    const Self = @This();

    symbols: ArrayList(lex.Symbol),
};
