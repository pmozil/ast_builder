const tok = @import("tok");
const std = @import("std");

const ArrayList = std.ArrayList;
//
// pub fn AST(comptime symbolMap: SymbolMap) type {
//     return struct {
//         const Self = @This();
//
//         alocator: std.mem.Allocator,
//         root: *ASTNode,
//         current_node: *ASTNode,
//
//         pub fn init(allocator: std.mem.Allocator) !Self {
//             const root: *ASTNode = try ASTNode.init(allocator);
//             return Self{
//                 .allocator = allocator,
//                 .root = root,
//                 .current_node = root,
//             };
//         }
//
//         pub fn deinit(self: *Self) void {
//             self.root.deinit(self.allocator);
//         }
//
//         pub fn construct(self: *Self, tokenizer: *tok.Tokenizer, nTokens: isize) !void {
//             if (nTokens < 0) {
//                 nTokens = std.math.maxInt(isize);
//             }
//
//             for (0..nTokens) |_| {
//                 const token = tokenizer.get_next_token() catch |err| switch (err) {
//                     error.IdxError => break,
//                     else => return err,
//                 };
//
//                 try self.processToken(token);
//             }
//         }
//
//         pub fn processToken(self: *Self, token: tok.Token) !void {
//             // Check if token has a corresponding symbol in our map
//             if (symbolMap.get(token.value)) |symbol| {
//                 if (symbol.isCloseBracket()) {
//                     self.handleCloseBracket(token.value) catch |err| switch (err) {
//                         error.UnclosedBracket => {
//                             if (!symbol.isOpenBracket()) {
//                                 return err;
//                             }
//                         },
//                         else => return err,
//                     };
//                     return;
//                 }
//                 if (symbol.isOpenBracket()) {
//                     try self.handleOpenBracket(symbol, token.value);
//                     return;
//                 }
//                 if (symbol.isNaryOp()) {
//                     try self.handleNaryOp(symbol, token.value);
//                     return;
//                 }
//             }
//             try self.handleLiteral(token.value);
//         }
//
//         fn handleOpenBracket(self: *Self, symbol: Symbol, value: []const u8) !void {
//             var new_node = try ASTNode.init(self.allocator);
//             new_node.kind = symbol;
//             new_node.value = value;
//             new_node.parent = self.current_node;
//
//             try self.appendNode(new_node);
//             self.current_node = new_node;
//         }
//
//         fn handleCloseBracket(self: *Self, value: []const u8) !void {
//             var cur: ?*ASTNode = self.current_node;
//
//             while (cur != null) : (cur = cur.parent) {
//                 const kindIsNull: bool = cur.?.kind == null;
//                 if (kindIsNull) {
//                     continue;
//                 }
//
//                 const isOpenBracket: bool = cur.?.kind.?.isOpenBracket();
//                 if (!isOpenBracket) {
//                     continue;
//                 }
//
//                 const val: BracketProps = cur.?.kind.?.props.bracket;
//                 if (!std.mem.eql(u8, val.close, value)) {
//                     continue;
//                 }
//
//                 if (cur.?.parent == null) {
//                     return SyntacticError.UnclosedBracket;
//                 }
//
//                 self.current_node = cur.parent;
//                 return;
//             }
//
//             return SyntacticError.UnclosedBracket;
//         }
//
//         // Todo: handle restructuring with different priorities.
//         // Include handling brackets
//         fn handleNaryOp(self: *Self, symbol: Symbol, value: []const u8) !void {
//             var new_node = try ASTNode.init(self.allocator);
//             new_node.kind = symbol;
//             new_node.value = value;
//             new_node.parent = self.current_node;
//
//             // Take n children before
//             const startIdx = self.current_node.children.items.len - symbol.kind.nChildrenPre;
//             try new_node.children.appendSlice(self.current_node.children.items[startIdx..]);
//             self.current_node.children.shrinkRetainingCapacity(startIdx);
//
//             try self.appendNode(new_node);
//             self.current_node = new_node;
//         }
//
//         fn appendNode(self: *Self, node: *ASTNode) !void {
//             const curNode: *ASTNode = self.current_node;
//             const symKind: *?Symbol = &curNode.kind;
//             const actNChildren = self.current_node.children.items.len;
//             var nChildren: ?usize = null;
//
//             if (symKind) |symbol| {
//                 nChildren = symbol.nChildrenPre + symbol.nChildrenPost;
//             }
//
//             if (nChildren != null and nChildren <= actNChildren) {
//                 self.current_node = self.current_node.parent orelse {
//                     return SyntacticError.TooManyOperands;
//                 };
//             }
//
//             try self.current_node.children.append(node);
//         }
//
//         fn handleLiteral(self: *Self, value: []const u8) !void {
//             var new_node: *ASTNode = try ASTNode.init(self.allocator);
//             new_node.value = value;
//             new_node.parent = self.current_node;
//             try self.appendNode(new_node);
//         }
//     };
// }
