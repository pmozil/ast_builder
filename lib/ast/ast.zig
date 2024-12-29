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

    alloc: std.mem.Allocator,
    root: *ASTNode,

    pub fn init(symArray: *ArrayList(*ASTNode), alloc: std.mem.Allocator) !Self {
        const node: *ASTNode = try ASTNode.init(alloc);
        node.*.children.deinit();
        node.*.children = symArray.*;

        symArray.* = ArrayList(*ASTNode).init(alloc);

        try preprocessSemicolons(node, alloc);
        node.*.children = try convertToAST(&node.*.children, alloc);

        return Self{
            .alloc = alloc,
            .root = node,
        };
    }

    pub fn deinit(self: *Self) !void {
        self.root.*.deinit();
        self.alloc.destroy(self.root);
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

    fn preprocessSemicolons(node: *ASTNode, alloc: std.mem.Allocator) !void {
        var hasSemicolons: bool = false;
        for (node.*.children.items) |childNode| {
            if (childNode.kind) |childNodeKind| {
                if (childNodeKind.isSemicolon()) {
                    hasSemicolons = true;
                    break;
                }
            }
        }
        if (!hasSemicolons) {
            return;
        }

        var vals: ArrayList(*ASTNode) = ArrayList(*ASTNode).init(alloc);
        var curNode: *ASTNode = try ASTNode.init(alloc);

        for (node.*.children.items) |childNode| {
            if (childNode.kind) |childNodeKind| {
                if (childNodeKind.isSemicolon()) {
                    if (curNode.children.items.len == 0) {
                        continue;
                    }

                    try vals.append(curNode);
                    curNode = try ASTNode.init(alloc);
                    childNode.deinit();
                    const childAlloc = childNode.alloc;
                    childAlloc.destroy(childNode);
                    continue;
                }
            }

            if (childNode.children.items.len > 0) {
                try preprocessSemicolons(childNode, alloc);
            }

            try curNode.*.children.append(childNode);
        }

        if (curNode.*.children.items.len > 0) {
            try vals.append(curNode);
        } else {
            curNode.deinit();
            alloc.destroy(curNode);
        }

        node.*.children.deinit();
        node.*.children = vals;
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
