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

const ASTNode =  struct {
    const Self = @This();

    parent: ?*Self,
    value: ?[] const u8,
    kind: ?Symbol,
    children: ArrayList(*Self),

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const node: *ASTNode = try allocator.create(Self);
        node.* = .{
            .parent = null,
            .value = null,
            .kind = null,
            .children = ArrayList(*Self).init(allocator),
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

pub fn Lexer(comptime symbolMap: SymbolMap) type {
    return struct {
        const Self = @This();

        alloc: std.mem.Allocator,
        symStack: ArrayList(*ASTNode),

        pub fn init(alloc: std.mem.Allocator) !Self {
            return Self {
                .alloc = alloc,
                .symStack = try ArrayList(Symbol).init(alloc),
            };
        }

        pub fn popUntilBracket(self: *Self, kind: Symbol) !void {
            const bracketKind: BracketProps = kind.props.bracket;
            const curNodeIdx: usize = self.symStack.items.len - 1;
            while (curNodeIdx > 0) : (curNodeIdx -= 1) {
                const curNode: *ASTNode = self.symStack[curNodeIdx];
                if (curNode.*.kind) |nodeKind| {
                    if (nodeKind.isOpenBracket()) {
                        continue;
                    }

                    if (!std.mem.eql(u8, nodeKind.value, bracketKind.open)) {
                        continue;
                    }

                    if (curNode.children.items.len > 0) {
                        continue;
                    }

                    try curNode.children.appendSlice(self.symStack.items[(curNodeIdx+1)..]);
                    self.symStack.shrinkRetainingCapacity(curNodeIdx + 1);
                }
            }

            return SyntacticError.UnclosedBracket;
        }

        pub fn addToken(self: *Self, token: tok.Token) !void {
            const newNode: ASTNode = ASTNode.init(self.alloc);
            newNode.value = token.value;
            newNode.kind  = symbolMap.get(token.value);

            if (newNode.kind) |kind| {
                if (kind.isCloseBracket()) {
                    self.popUntilBracket(kind);
                }
            }

            try self.symStack.append(newNode);
        }
    };
}
