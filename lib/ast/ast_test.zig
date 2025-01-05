const std = @import("std");
const testing = std.testing;
const tok = @import("tok");
const lex = @import("lex");
const ast = @import("ast");

const ArrayList = std.ArrayList;

const tokenMap: tok.TokenMap = tok.TokenMap.initComptime(&.{
    .{"(",  tok.TokenType{.tokenType = 1, .priority = 0, .breakOnToken = true}},
    .{")",  tok.TokenType{.tokenType = 2, .priority = 0, .breakOnToken = true}},
    .{"\"", tok.TokenType{.tokenType = 3, .priority = 0, .breakOnToken = true}},
    .{"+",  tok.TokenType{.tokenType = 4, .priority = 0, .breakOnToken = true}},
    .{"*",  tok.TokenType{.tokenType = 5, .priority = 0, .breakOnToken = true}},
    .{";",  tok.TokenType{.tokenType = 6, .priority = 0, .breakOnToken = true}},
});

const symbolMap: lex.SymbolMap = lex.SymbolMap.initComptime(&.{
    .{"(",
        lex.Symbol{
            .symbolType = 1,
            .symbolProps = lex.SymbolFlags.OpenBracket.asInt(),
            .props = lex.SymbolProps{
                .bracket = lex.BracketProps{
                    .open = "(",
                    .close = ")",
                    .stacking = true,
                }
            }
        }
    },
    .{")",
        lex.Symbol{
            .symbolType = 2,
            .symbolProps = lex.SymbolFlags.CloseBracket.asInt(),
            .props = lex.SymbolProps{
                .bracket = lex.BracketProps{
                    .open = "(",
                    .close = ")",
                    .stacking = true,
                }
            }
        }
    },
    .{"\"",
        lex.Symbol{
            .symbolType = 3,
            .symbolProps = lex.SymbolFlags.OpenBracket.asInt() |
                            lex.SymbolFlags.CloseBracket.asInt(),
            .props = lex.SymbolProps{
                .bracket = lex.BracketProps{
                    .open = "\"",
                    .close = "\"",
                    .stacking = false,
                }
            }
        }
    },
    .{"+",
        lex.Symbol{
            .symbolType = 4,
            .symbolProps = lex.SymbolFlags.Operator.asInt(),
            .props = lex.SymbolProps{
                .operator = lex.OperatorProps{
                    .opPriority = 0,
                    .nChildren = 2,
                },
            }
        }
    },
    .{"*",
        lex.Symbol{
            .symbolType = 5,
            .symbolProps = lex.SymbolFlags.Operator.asInt(),
            .props = lex.SymbolProps{
                .operator = lex.OperatorProps{
                    .opPriority = 1,
                    .nChildren = 2,
                },
            }
        }
    },
    .{";",
        lex.Symbol{
            .symbolType = 5,
            .symbolProps = lex.SymbolFlags.Semicolon.asInt(),
        }
    },
});

fn parseString(allocator: std.mem.Allocator, input: []const u8) !ast.AST {
    const TokenizerType = tok.Tokenizer(tokenMap, " \n\r");
    var tokenizer = TokenizerType.init(input);

    const LexerType = lex.Lexer(symbolMap);
    var lexer = LexerType.init(allocator);
    defer lexer.deinit();

    while (true) {
        const token = tokenizer.get_next_token() catch {
            break;
        };
        try lexer.addToken(token);
    }

    return try ast.AST.init(&lexer.symStack, allocator);
}

fn validateASTStructure(node: *const lex.ASTNode, expected_value: ?[]const u8, expected_children: usize) !void {
    try testing.expectEqual(expected_children, node.children.items.len);
    if (expected_value) |value| {
        try testing.expectEqualStrings(value, node.value.?);
    }
}

test "nested brackets with string literals" {
    const input = "(open bracket(inner  + bracket + \"another\") + (other + inner bracket (third level \"also other here\"))) \"abcd\" () (\"\")";
    var result = try parseString(testing.allocator, input);
    defer result.deinit();

    // Validate root structure
    try validateASTStructure(result.root, null, 4);
}

test "arithmetic with semicolons" {
    const input = "3 + 5; 1 + (2 + 3; 10);";
    var result = try parseString(testing.allocator, input);
    defer result.deinit();

    try validateASTStructure(result.root, null, 2);  // Expecting two top-level expressions separated by semicolon
}

test "multiplication precedence" {
    const input = "1 + 2 * 5 * (1 + 2 * 3)";
    var result = try parseString(testing.allocator, input);
    defer result.deinit();

    // Validate operator precedence
    try validateASTStructure(result.root, null, 1);
}

test "error cases" {
    // Test unclosed brackets
    {
        const input = "(1 + 2))";
        const result = parseString(testing.allocator, input);
        try testing.expectError(error.UnclosedBracket, result);
    }
}
