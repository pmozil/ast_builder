const tok = @import("tok");
const std = @import("std");

const SymbolType = usize;

const ArrayList = std.ArrayList;
const SymbolMap = std.StaticStringMap(Symbol);

const SyntacticError = error {
    UnclosedBracket,
    TooManyOperands,
};

const SymbolFlags = enum(usize) {
    OpenBracket    = 0b1,
    CloseBracket   = 0b10,
    NaryOp         = 0b100,
    CanCommute     = 0b1000,
};

const NaryOpProps = struct {
    nChildrenPre: usize = 1,
    nChildrenPost: usize = 1,
    opPriority: isize = 0,
};

const BracketProps = struct {
    open: [] const u8,
    close: [] const u8,
};

const SymbolProps = union {
    bracket: BracketProps,
    nAryOp: NaryOpProps,
    other: [] const u8,
};

const Symbol = struct {
    const Self = @This();

    symbolType: SymbolType,
    symbolProps: SymbolFlags,
    props: SymbolProps,

    pub fn isOpenBracket(self: *const Self) bool {
        return (self.symbolProps & SymbolFlags.OpenBracket) == SymbolFlags.OpenBracket;
    }

    pub fn isCloseBracket(self: *const Self) bool {
        return (self.symbolProps & SymbolFlags.CloseBracket) == SymbolFlags.CloseBracket;
    }

    pub fn isNaryOp(self: *const Self) bool {
        return (self.symbolProps & SymbolFlags.NaryOp) == SymbolFlags.NaryOp;
    }

    pub fn childrenCommute(self: *const Self) bool {
        return (self.symbolProps & SymbolFlags.CanCommute) == SymbolFlags.CanCommute;
    }
};

const ParserTreeNode =  struct {
    const Self = @This();

    parent: ?*Self,
    value: ?[] const u8,
    kind: ?Symbol,
    children: ArrayList(*Self),

    pub fn init(allocator: *std.mem.Allocator) !*Self {
        const node: *ParserTreeNode = try allocator.create(Self);
        node.* = .{
            .parent = null,
            .value = null,
            .kind = null,
            .children = ArrayList(*Self).init(allocator),
        };
        return node;
    }

    pub fn deinit(self: *Self, allocator: *std.mem.Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
    }
};

pub fn ParserTree(comptime symbolMap: SymbolMap) type {
    return struct {
        const Self = @This();

        alocator: *std.mem.Allocator,
        root: *ParserTreeNode,
        current_node: *ParserTreeNode,

        pub fn init(allocator: *std.mem.Allocator) !Self {
            const root: *ParserTreeNode = try ParserTreeNode.init(allocator);
            return Self{
                .allocator = allocator,
                .root = root,
                .current_node = root,
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
        }

        pub fn construct(self: *Self, tokenizer: *tok.Tokenizer, nTokens: isize) !void {
            if (nTokens < 0) {
                nTokens = std.math.maxInt(isize);
            }

            for (0..nTokens) |_| {
                const token = tokenizer.get_next_token() catch |err| switch (err) {
                    error.IdxError => break,
                    else => return err,
                };

                try self.processToken(token);
            }
        }

        pub fn processToken(self: *Self, token: tok.Token) !void {
            // Check if token has a corresponding symbol in our map
            if (symbolMap.get(token.value)) |symbol| {
                if (symbol.isCloseBracket()) {
                    self.handleCloseBracket(token.value) catch |err| switch (err) {
                        error.UnclosedBracket => {
                            if (!symbol.isOpenBracket()) {
                                return err;
                            }
                        },
                        else => return err,
                    };
                    return;
                }
                if (symbol.isOpenBracket()) {
                    try self.handleOpenBracket(symbol, token.value);
                    return;
                }
                if (symbol.isNaryOp()) {
                    try self.handleNaryOp(symbol, token.value);
                    return;
                }
            }
            try self.handleLiteral(token.value);
        }

        fn handleOpenBracket(self: *Self, symbol: Symbol, value: []const u8) !void {
            var new_node = try ParserTreeNode.init(self.allocator);
            new_node.kind = symbol;
            new_node.value = value;
            new_node.parent = self.current_node;

            try self.appendNode(new_node);
            self.current_node = new_node;
        }

        fn handleCloseBracket(self: *Self, value: []const u8) !void {
            var cur: ?*ParserTreeNode = self.current_node;

            while (cur != null) : (cur = cur.parent) {
                const kindIsNull: bool = cur.?.kind == null;
                if (kindIsNull) {
                    continue;
                }

                const isOpenBracket: bool = cur.?.kind.?.isOpenBracket();
                if (!isOpenBracket) {
                    continue;
                }

                const val: BracketProps = cur.?.kind.?.props.bracket;
                if (!std.mem.eql(u8, val.close, value)) {
                    continue;
                }

                if (cur.?.parent == null) {
                    return SyntacticError.UnclosedBracket;
                }

                self.current_node = cur.parent;
                return;
            }

            return SyntacticError.UnclosedBracket;
        }

        // Todo: handle restructuring with different priorities.
        // Include handling brackets
        fn handleNaryOp(self: *Self, symbol: Symbol, value: []const u8) !void {
            var new_node = try ParserTreeNode.init(self.allocator);
            new_node.kind = symbol;
            new_node.value = value;
            new_node.parent = self.current_node;

            // Take n children before
            const startIdx = self.current_node.children.items.len - symbol.kind.nChildrenPre;
            try new_node.children.appendSlice(self.current_node.children.items[startIdx..]);
            self.current_node.children.shrinkRetainingCapacity(startIdx);

            try self.appendNode(new_node);
            self.current_node = new_node;
        }

        fn appendNode(self: *Self, node: *ParserTreeNode) !void {
            const curNode: *ParserTreeNode = self.current_node;
            const symKind: *?Symbol = &curNode.kind;
            const actNChildren = self.current_node.children.items.len;
            var nChildren: ?usize = null;

            if (symKind) |symbol| {
                nChildren = symbol.nChildrenPre + symbol.nChildrenPost;
            }

            if (nChildren != null and nChildren <= actNChildren) {
                self.current_node = self.current_node.parent orelse {
                    return SyntacticError.TooManyOperands;
                };
            }

            try self.current_node.children.append(node);
        }

        fn handleLiteral(self: *Self, value: []const u8) !void {
            var new_node: *ParserTreeNode = try ParserTreeNode.init(self.allocator);
            new_node.value = value;
            new_node.parent = self.current_node;
            try self.appendNode(new_node);
        }
    };
}
