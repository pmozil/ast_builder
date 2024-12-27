const std = @import("std");
const tok = @import("tok");
const lex = @import("lex");

const ArrayList = std.ArrayList;

pub const AST = struct {
    const Self = @This();

    symbols: ArrayList(*lex.ASTNode),

    pub fn init(symArray: *ArrayList(*lex.ASTNode), alloc: std.mem.Allocator) !Self {
        const result: Self = .{
            .symbols = try sortSymbols(alloc, symArray),
        };
        return result;
    }

    fn checkPriority(priority: isize, nodeOpt: ?*lex.ASTNode) bool {
        if (nodeOpt) |node| {
            if (node.*.kind) |nodeKind| {
                if (nodeKind.isNaryOp()) {
                    const nodeProps: lex.NaryOpProps = nodeKind.props.nAryOp;
                    return priority <= nodeProps.opPriority;
                }
            }
        }

        return true;
    }

    fn sortSymbols(alloc: std.mem.Allocator,
        vals: *ArrayList(*lex.ASTNode)) !ArrayList(*lex.ASTNode)
    {
        defer vals.clearAndFree();
        var stack = ArrayList(*lex.ASTNode).init(alloc);
        defer stack.deinit();

        var result = ArrayList(*lex.ASTNode).init(alloc);

        for (vals.items) |node| {
            if (node.*.children.items.len > 0) {
                node.*.children = try sortSymbols(alloc, &node.*.children);
            }

            if (node.*.kind) |nodeKind| {
                if (nodeKind.isNaryOp()) {
                    const priority: isize = nodeKind.props.nAryOp.opPriority;
                    while (stack.items.len > 0 and
                        checkPriority(priority, stack.getLastOrNull())) {
                        try result.append(stack.pop());
                    }
                }
            }
            try stack.append(node);
        }

        while (stack.items.len > 0) {
            try result.append(stack.pop());
        }

        return result;
    }
};
