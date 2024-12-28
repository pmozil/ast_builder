const std = @import("std");
const tok = @import("tok");
const lex = @import("lex");

const ArrayList = std.ArrayList;

pub const ASTError = error {
    OperatorMisuse,
    NotAnOperator,
};

const ASTNode: type = lex.ASTNode;

pub const AST = struct {
    const Self = @This();

    symbols: ArrayList(*ASTNode),

    pub fn init(symArray: *ArrayList(*ASTNode), alloc: std.mem.Allocator) !Self {
        const result: Self = .{
            .symbols = try convertToAST(symArray, alloc),
        };
        symArray.* = ArrayList(*ASTNode).init(alloc);
        return result;
    }

    fn hasLowerPriority(priority: isize, nodeOpt: ?*ASTNode) bool {
        if (nodeOpt) |node| {
            if (node.*.kind) |nodeKind| {
                if (nodeKind.isOperator()) {
                    const nodeProps: lex.OperatorProps = nodeKind.props.operator;
                    return priority <= nodeProps.opPriority;
                }
            }
        }

        return true;
    }

    fn popIntoOperator(vals: *ArrayList(*ASTNode), node: *ASTNode) !void {
        const nodeKind: lex.Symbol = node.*.kind orelse {
            return ASTError.NotAnOperator;
        };
        if (!nodeKind.isOperator()) {
            return ASTError.NotAnOperator;
        }

        const operatorProps: lex.OperatorProps = nodeKind.props.operator;
        if (vals.*.items.len < operatorProps.nChildren) {
            return ASTError.OperatorMisuse;
        }

        const fstPoppedIdx: usize = vals.*.items.len - operatorProps.nChildren;
        try node.*.children.appendSlice(vals.*.items[fstPoppedIdx..]);
        vals.shrinkRetainingCapacity(fstPoppedIdx);
    }

    fn convertToAST(vals: *ArrayList(*ASTNode), alloc: std.mem.Allocator) !ArrayList(*ASTNode)
    {
        var stack = ArrayList(*ASTNode).init(alloc);
        defer stack.deinit();

        var result = ArrayList(*ASTNode).init(alloc);

        for (vals.*.items) |node| {
            if (node.*.children.items.len > 0) {
                var array = node.*.children;
                node.*.children = try convertToAST(&array, alloc);
                array.deinit();
            }

            if (node.*.kind) |nodeKind| {
                if (!nodeKind.isOperator()) {
                    try result.append(node);
                    continue;
                }

                const operatorProps = nodeKind.props.operator;
                const priority = operatorProps.opPriority;
                while (stack.items.len > 0 and
                    hasLowerPriority(priority, stack.getLast()))
                {
                    const curNode: *ASTNode = stack.pop();
                    try popIntoOperator(&result, curNode);
                    try result.append(curNode);
                }
                try stack.append(node);

                continue;
            }

            try result.append(node);
        }

        while (stack.items.len > 0) {
            const curNode: *ASTNode = stack.pop();
            try popIntoOperator(&result, curNode);
            try result.append(curNode);
        }

        return result;
    }
};
