const tok = @import("tok");
const std = @import("std");

const SymbolType = usize;

const ArrayList = std.ArrayList;
const SymbolMap = std.StaticStringMap(Symbol);

const SymbolProps = enum(usize) {
    OpenBracket    = 0b1,
    CloseBracket   = 0b10,
    NaryOp         = 0b100,
    CanCommute     = 0b1000,
};

const Symbol = struct {
    const Self = @This();

    symbolType: SymbolType,
    value: [] const u8,
    symbolProps: SymbolProps,
    nChildren: usize,


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
    children: ArrayList(*Self),
    kind: ?Symbol,

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const node: *ASTNode = try allocator.create(Self);
        node.* = .{
            .parent = null,
            .value = null,
            .children = ArrayList(*Self).init(allocator),
            .kind = null,
        };
        return node;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
    }
};

pub fn AST(comptime symbolMap: SymbolMap, comptime Tok: tok.Tokenizer, tokenizer: Tok) type {
    return struct {
        const Self = @This();

        root: ASTNode,

        pub fn init(allocator: std.mem.Allocator) !Self {
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
                } else if (symbol.isCloseBracket()) {
                    try self.handleCloseBracket();
                } else if (symbol.isNaryOp()) {
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
            try self.current_node.children.append(new_node);
            self.current_node = new_node;
        }

        fn handleCloseBracket(self: *Self) !void {
            if (self.current_node.parent) |parent| {
                self.current_node = parent;
            }
        }

        fn handleNaryOp(self: *Self, symbol: Symbol, value: []const u8) !void {
            var new_node = try ASTNode.init(self.allocator);
            new_node.kind = symbol;
            new_node.value = value;
            new_node.parent = self.current_node;
            try self.current_node.children.append(new_node);
            self.current_node = new_node;
        }

        fn handleLiteral(self: *Self, value: []const u8) !void {
            var new_node = try ASTNode.init(self.allocator);
            new_node.value = value;
            new_node.parent = self.current_node;
            try self.current_node.children.append(new_node);
        }
    };
}
