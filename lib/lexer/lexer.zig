const tok = @import("tok");
const std = @import("std");

const ArrayList = std.ArrayList;

pub const SymbolType = usize;
pub const SymbolMap = std.StaticStringMap(Symbol);

pub const SyntacticError = error {
    UnclosedBracket,
    TooManyOperands,
};

pub const SymbolFlags = enum(usize) {
    OpenBracket    = 0b1,
    CloseBracket   = 0b10,
    Operator       = 0b100,

    pub fn asInt(self: SymbolFlags) usize {
        return @intFromEnum(self);
    }
};

pub const OperatorProps = struct {
    opPriority: isize = 0,
    nChildren: usize,
};

pub const BracketProps = struct {
    open: [] const u8,
    close: [] const u8,
    stacking: bool = false,
};

pub const SymbolProps = union {
    bracket:  BracketProps,
    operator: OperatorProps,
    other: ?[] const u8,
};

pub const Symbol = struct {
    const Self = @This();

    symbolType: ?SymbolType = null,
    symbolProps: usize      = 0,
    props: SymbolProps      = .{.other = null},

    pub fn isOpenBracket(self: *const Self) bool {
        return (self.symbolProps & SymbolFlags.OpenBracket.asInt()) == SymbolFlags.OpenBracket.asInt();
    }

    pub fn isCloseBracket(self: *const Self) bool {
        return (self.symbolProps & SymbolFlags.CloseBracket.asInt()) == SymbolFlags.CloseBracket.asInt();
    }

    pub fn isOperator(self: *const Self) bool {
        return (self.symbolProps & SymbolFlags.Operator.asInt()) == SymbolFlags.Operator.asInt();
    }
};

pub const ASTNode =  struct {
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
            allocator.destroy(child);
        }
        self.children.deinit();
    }
};

pub fn Lexer(comptime symbolMap: SymbolMap) type {
    return struct {
        const Self = @This();

        alloc: std.mem.Allocator,
        symStack: ArrayList(*ASTNode),

        pub fn init(alloc: std.mem.Allocator) Self {
            return Self {
                .alloc = alloc,
                .symStack = ArrayList(*ASTNode).init(alloc),
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.symStack.items) |astNode| {
                astNode.deinit(self.alloc);
                self.alloc.destroy(astNode);
            }
            self.symStack.deinit();
        }

        fn popUntilBracket(self: *Self, kind: Symbol) !void {
            const bracketKind: BracketProps = kind.props.bracket;
            var curNodeIdx_i: isize = @intCast(self.symStack.items.len - 1);
            while (curNodeIdx_i >= 0) : (curNodeIdx_i -= 1) {
                const curNodeIdx: usize = @intCast(curNodeIdx_i);
                const curNode: *ASTNode = self.symStack.items[curNodeIdx];
                if (curNode.*.kind) |nodeKind| {
                    if (!nodeKind.isOpenBracket()) {
                        continue;
                    }

                    const curProps: BracketProps = nodeKind.props.bracket;

                    if (!std.mem.eql(u8, curProps.open, bracketKind.open)) {
                        continue;
                    }

                    if (!std.mem.eql(u8, curProps.close, bracketKind.close)) {
                        continue;
                    }

                    if (curNode.children.items.len > 0) {
                        if (curProps.stacking) {
                            continue;
                        }
                        return SyntacticError.UnclosedBracket;
                    }

                    try curNode.children.appendSlice(self.symStack.items[(curNodeIdx+1)..]);
                    self.symStack.shrinkRetainingCapacity(curNodeIdx + 1);
                    for (curNode.children.items) |child| {
                        child.*.parent = curNode;
                    }
                    return;
                }
            }

            return SyntacticError.UnclosedBracket;
        }

        pub fn addToken(self: *Self, token: tok.Token) !void {
            var newNode: *ASTNode = try ASTNode.init(self.alloc);
            newNode.value = token.value;
            newNode.kind  = symbolMap.get(token.value);

            if (newNode.kind) |kind| {
                if (kind.isCloseBracket()) {
                    self.popUntilBracket(kind) catch |err| switch (err) {
                        error.UnclosedBracket => {
                            // In this case, the bracket is an open bracket
                            // Happens for cases line the string bracket - "
                            // We then just continue,
                            // and treat this one line an open bracket
                            if (!kind.isOpenBracket()) {
                                return err;
                            }
                            try self.symStack.append(newNode);
                            return;
                        },
                        else => {
                            return err;
                        },
                    };
                    newNode.deinit(self.alloc);
                    return;
                }
            }

            try self.symStack.append(newNode);
        }
    };
}
