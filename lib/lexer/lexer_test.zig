const std = @import("std");
const tok = @import("tok");
const lex = @import("lexer.zig");

const ArrayList = std.ArrayList;

fn testEq(fst: [] ?[] const u8, snd: ArrayList(*lex.ASTNode)) bool {
    if (fst.len != snd.items.len) {
        return false;
    }

    for (0..fst.len) |nodeIdx| {
        if (fst[nodeIdx] == null) {
            if (snd.items[nodeIdx].value != null) {
                return false;
            }
            continue;
        }

        if (!std.mem.eql(u8, fst[nodeIdx].?, snd.items[nodeIdx].value.?)) {
           std.debug.print("Unequal Values: first: {s}, second: {s}\n",
                .{fst[nodeIdx].?, snd.items[nodeIdx].value.?});
            return false;
        }
    }

    return true;
}

test "Test tokenizer" {
    const delims = " \n\r";
    const tokenMap = tok.TokenMap.initComptime(&.{
        .{"(",  tok.TokenType{.tokenType = 1, .priority = 0, .breakOnToken = true}},
        .{")",  tok.TokenType{.tokenType = 2, .priority = 0, .breakOnToken = true}},
        .{"\"", tok.TokenType{.tokenType = 3, .priority = 0, .breakOnToken = true}},
    });
    const TokenizerType: type = tok.Tokenizer(tokenMap, delims);

    const string: []const u8 = "(open bracket(inner bracket \"another\") (other inner bracket (third level \"also other here\"))) \"abcd\" () (\"\")";
    var tokenizer: TokenizerType = TokenizerType.init(string);

    const lexerMap = lex.SymbolMap.initComptime(&.{
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
    });
    const LexerType: type = lex.Lexer(lexerMap);
    var lexer = LexerType.init(std.heap.page_allocator);
    defer lexer.deinit();

    while (true) {
        const token = tokenizer.get_next_token() catch {
            break;
        };
        lexer.addToken(token) catch |err| switch (err) {
            lex.SyntacticError.UnclosedBracket => {
                std.debug.print("Error! Unclosed bracket\n", .{});
            },
            else => return err,
        };
    }

    var rootLstArr = [_] ?[]const u8{
        "(",
        "\"",
        "(",
        "(",
    };
    var rootLst: []?[]const u8 = rootLstArr[0..];
    try std.testing.expect(testEq(rootLst, lexer.symStack));

    rootLstArr = [_] ?[]const u8{
        "open",
        "bracket",
        "(",
        "(",
    };
    rootLst = rootLstArr[0..];
    try std.testing.expect(testEq(rootLst, lexer.symStack.items[0].children));

    var newRootLstArr = [_] ?[]const u8{
        "inner",
        "bracket",
        "\"",
    };
    rootLst = newRootLstArr[0..];
    try std.testing.expect(testEq(rootLst, lexer.symStack.items[0].children.items[2].children));

    var thirdRootLstArr = [_] ?[]const u8{
        "another",
    };
    rootLst = thirdRootLstArr[0..];
    try std.testing.expect(testEq(rootLst,
            lexer.symStack.items[0].children.items[2].children.items[2].children));

    rootLstArr = [_] ?[]const u8{
        "other",
        "inner",
        "bracket",
        "(",
    };
    rootLst = rootLstArr[0..];
    try std.testing.expect(testEq(rootLst, lexer.symStack.items[0].children.items[3].children));

    newRootLstArr = [_] ?[]const u8{
        "third",
        "level",
        "\"",
    };
    rootLst = newRootLstArr[0..];
    try std.testing.expect(testEq(rootLst, lexer.symStack.items[0].children.items[3].children.items[3].children));

    newRootLstArr = [_] ?[]const u8{
        "also",
        "other",
        "here",
    };
    rootLst = newRootLstArr[0..];
    try std.testing.expect(testEq(rootLst, lexer.symStack.items[0].children.items[3].children.items[3].children.items[2].children));
}
