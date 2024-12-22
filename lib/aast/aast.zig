const tok = @import("tok");
const std = @import("std");

const SymbolType = usize;

const ArrayList = std.ArrayList;
const SymbolMap = std.StaticStringMap(Symbol);

const SyntacticError = error {
    UnclosedBracket,
    TooManyOperands,
};

const SymbolProps = enum(usize) {
    OpenBracket    = 0b1,
    CloseBracket   = 0b10,
    NaryOp         = 0b100,
    CanCommute     = 0b1000,
};

const Symbol = struct {
    const Self = @This();

    symbolType: SymbolType,
    symbolProps: SymbolProps,
    value: [] const u8,
    nChildrenPre: ?usize,
    nChildrenPost: ?usize,

    pub fn isOpenBracket(self: *const Self) bool {
        return (self.symbolProps & SymbolProps.OpenBracket) == SymbolProps.OpenBracket;
    }

    pub fn isCloseBracket(self: *const Self) bool {
        return (self.symbolProps & SymbolProps.CloseBracket) == SymbolProps.CloseBracket;
    }

    pub fn isNaryOp(self: *const Self) bool {
        return (self.symbolProps & SymbolProps.NaryOp) == SymbolProps.NaryOp;
    }

    pub fn childrenCommute(self: *const Self) bool {
        return (self.symbolProps & SymbolProps.CanCommute) == SymbolProps.CanCommute;
    }
};

const ASTNode =  struct {
    const Self = @This();

    parent: ?*Self,
    value: ?[] const u8,
    kind: ?Symbol,
    children: ArrayList(*Self),

    pub fn init(allocator: *std.mem.Allocator) !*Self {
        const node: *ASTNode = try allocator.create(Self);
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

pub fn AST(comptime symbolMap: SymbolMap, comptime Tok: tok.Tokenizer) type {
    return struct {
        const Self = @This();

        alocator: *std.mem.Allocator,
        root: *ASTNode,
        current_node: *ASTNode,
        tokenizer: *Tok,

        pub fn init(allocator: *std.mem.Allocator, tokenizer: *Tok) !Self {
            const root: *ASTNode = try ASTNode.init(allocator);
            return Self{
                .allocator = allocator,
                .root = root,
                .current_node = root,
                .tokenizer = tokenizer,
            };
        }

        pub fn deinit(self: *Self) void {
            self.root.deinit(self.allocator);
        }

        pub fn construct(self: *Self) !void {
            while (true) {
                const token = self.tokenizer.get_next_token() catch |err| switch (err) {
                    error.IdxError => break,
                    else => return err,
                };

                try self.processToken(token);
            }
        }

        fn processToken(self: *Self, token: tok.Token) !void {
            // Check if token has a corresponding symbol in our map
            if (symbolMap.get(token.value)) |symbol| {
                if (symbol.isOpenBracket()) {
                    try self.handleOpenBracket(symbol, token.value);
                }
                if (symbol.isCloseBracket()) {
                    try self.handleCloseBracket(token.value);
                }
                if (symbol.isNaryOp()) {
                    try self.handleNaryOp(symbol, token.value);
                }
            } else {
                // Token is a literal/identifier
                try self.handleLiteral(token.value);
            }
        }

        fn handleOpenBracket(self: *Self, symbol: Symbol, value: []const u8) !void {
            var new_node = try ASTNode.init(self.allocator);
            new_node.kind = symbol;
            new_node.value = value;
            new_node.parent = self.current_node;

            try self.appendNode(new_node);
            self.current_node = new_node;
        }

        fn handleCloseBracket(self: *Self, value: []const u8) !void {
            var cur: ?*ASTNode = self.current_node.parent;
            while (cur != null) : (cur = cur.parent) {
                if (cur.kind != null and std.mem.eql(u8, cur.kind.value, value)) {
                    self.current_node = cur;
                    return;
                }
            }

            return SyntacticError.UnclosedBracket;
        }

        fn handleNaryOp(self: *Self, symbol: Symbol, value: []const u8) !void {
            var new_node = try ASTNode.init(self.allocator);
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

        fn appendNode(self: *Self, node: *ASTNode) !void {
            const curNode: *ASTNode = self.current_node;
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
            var new_node: *ASTNode = try ASTNode.init(self.allocator);
            new_node.value = value;
            new_node.parent = self.current_node;
            try self.appendNode(new_node);
        }
    };
}
