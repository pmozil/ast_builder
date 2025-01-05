const std = @import("std");
const tok = @import("tok");
const lex = @import("lex");
const ast = @import("ast");

const ArrayList = std.ArrayList;

fn printSymbol(sym: *const lex.ASTNode, indent: usize) void {
    for (0..indent) |_| {
        std.debug.print("\t", .{});
    }
    std.debug.print("Symbol: \"{s}\"\n", .{sym.value orelse "nothing"});
}

fn printSymbols(vals: *const ArrayList(*lex.ASTNode), indent: usize) void {
    for (vals.items) |sym| {
        printSymbol(sym, indent);
        if (sym.children.items.len > 0) {
            for (0..(indent+1)) |_| {
                std.debug.print("\t", .{});
            }
            std.debug.print("Children: \n\n", .{});

            printSymbols(&sym.children, indent + 1);

            for (0..(indent+1)) |_| {
                std.debug.print("\t", .{});
            }
            std.debug.print("End Children: \n\n", .{});
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    const delims = " \n\r";
    const tokenMap = tok.TokenMap.initComptime(&.{
        .{"(",   tok.TokenType{.tokenType = 1, .priority = 0, .breakOnToken = true}},
        .{")",   tok.TokenType{.tokenType = 2, .priority = 0, .breakOnToken = true}},
        .{"\"",  tok.TokenType{.tokenType = 3, .priority = 0, .breakOnToken = true}},
        .{"+",   tok.TokenType{.tokenType = 4, .priority = 0, .breakOnToken = true}},
        .{"*",   tok.TokenType{.tokenType = 5, .priority = 0, .breakOnToken = true}},
        .{";",   tok.TokenType{.tokenType = 6, .priority = 0, .breakOnToken = true}},
        .{"{",   tok.TokenType{.tokenType = 7, .priority = 0, .breakOnToken = true}},
        .{"}",   tok.TokenType{.tokenType = 8, .priority = 0, .breakOnToken = true}},
        .{"=",   tok.TokenType{.tokenType = 9, .priority = 0, .breakOnToken = true}},
        .{"if",  tok.TokenType{.tokenType = 10, .priority = 0, .breakOnToken = true}},
    });
    const TokenizerType: type = tok.Tokenizer(tokenMap, delims);

    const string: []const u8 =
        \\ {
        \\ if (a * b) {
        \\   c = 10 * x;
        \\ }
        \\ }
    ;
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
                        .nChildren  = 2,
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
        .{"{",
            lex.Symbol{
                .symbolType = 6,
                .symbolProps = lex.SymbolFlags.OpenBracket.asInt(),
                .props = lex.SymbolProps{
                    .bracket = lex.BracketProps{
                        .open = "{",
                        .close = "}",
                        .stacking = true,
                    }
                }
            }
        },
        .{"}",
            lex.Symbol{
                .symbolType = 7,
                .symbolProps = lex.SymbolFlags.CloseBracket.asInt(),
                .props = lex.SymbolProps{
                    .bracket = lex.BracketProps{
                        .open = "{",
                        .close = "}",
                        .stacking = true,
                    }
                }
            }
        },
        .{"=",
            lex.Symbol{
                .symbolType = 8,
                .symbolProps = lex.SymbolFlags.Operator.asInt(),
                .props = lex.SymbolProps{
                    .operator = lex.OperatorProps{
                        .opPriority = -100,
                        .nChildren  = 2,
                    },
                }
            }
        },
        .{"if",
            lex.Symbol{
                .symbolType = 9,
                .symbolProps = lex.SymbolFlags.Operator.asInt(),
                .props = lex.SymbolProps{
                    .operator = lex.OperatorProps{
                        .opPriority = -10,
                        .nChildren  = 2,
                    },
                }
            }
        },
    });
    const LexerType: type = lex.Lexer(lexerMap);
    var lexer = LexerType.init(alloc);
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

    const theAst = try ast.AST.init(&lexer.symStack, alloc);
    defer theAst.deinit();
    printSymbols(&theAst.root.*.children, 0);
}
