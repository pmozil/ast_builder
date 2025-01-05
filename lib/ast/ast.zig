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

        preprocessSemicolons(symArray, alloc) catch |err| {
            for (symArray.*.items) |item| {
                const curAlloc = item.*.alloc;
                item.*.deinit();
                curAlloc.destroy(item);
            }
            symArray.*.deinit();
            return err;
        };

        node.*.children = try convertToAST(symArray, alloc);
        for (node.*.children.items) |item| {
            item.*.parent = node;
        }

        symArray.*.clearRetainingCapacity();

        return Self{
            .alloc = alloc,
            .root = node,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.root.*.deinit();
        const alloc: std.mem.Allocator = self.root.*.alloc;
        alloc.destroy(self.root);
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

    fn preprocessSemicolons(origVals: *ArrayList(*ASTNode), alloc: std.mem.Allocator) !void {
        var hasSemicolons: bool = false;
        for (origVals.*.items) |childNode| {
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

        for (origVals.*.items) |childNode| {
            if (childNode.kind) |childNodeKind| {
                if (childNodeKind.isSemicolon()) {
                    if (curNode.children.items.len == 0) {
                        continue;
                    }

                    vals.append(curNode) catch |err| {
                        for (vals.items) |item| {
                            const curAlloc = item.*.alloc;
                            item.*.deinit();
                            curAlloc.destroy(item);
                        }
                        vals.deinit();
                        curNode.deinit();
                        alloc.destroy(curNode);
                        return err;
                    };
                    curNode = ASTNode.init(alloc) catch |err| {
                        for (vals.items) |item| {
                            const curAlloc = item.*.alloc;
                            item.*.deinit();
                            curAlloc.destroy(item);
                        }
                        vals.deinit();
                        curNode.deinit();
                        alloc.destroy(curNode);
                        return err;
                    };
                    childNode.deinit();
                    const childAlloc = childNode.alloc;
                    childAlloc.destroy(childNode);
                    continue;
                }
            }

            if (childNode.children.items.len > 0) {
                preprocessSemicolons(&childNode.*.children, alloc) catch |err| {
                    for (vals.items) |item| {
                        const curAlloc = item.*.alloc;
                        item.*.deinit();
                        curAlloc.destroy(item);
                    }
                    vals.deinit();
                    curNode.deinit();
                    alloc.destroy(curNode);
                    return err;
                };
            }

            curNode.*.children.append(childNode) catch |err| {
                for (vals.items) |item| {
                    const curAlloc = item.*.alloc;
                    item.*.deinit();
                    curAlloc.destroy(item);
                    return err;
                }
                vals.deinit();
                curNode.deinit();
                alloc.destroy(curNode);
            };
            childNode.*.parent = curNode;
        }

        if (curNode.*.children.items.len > 0) {
            vals.append(curNode) catch |err| {
                for (vals.items) |item| {
                    const curAlloc = item.*.alloc;
                    item.*.deinit();
                    curAlloc.destroy(item);
                    return err;
                }
                vals.deinit();
                curNode.deinit();
                alloc.destroy(curNode);
            };
        } else {
            curNode.deinit();
            alloc.destroy(curNode);
        }

        origVals.*.deinit();
        origVals.* = vals;
    }

    fn convertToAST(vals: *ArrayList(*ASTNode), alloc: std.mem.Allocator) !ArrayList(*ASTNode)
    {
        var stack = ArrayList(*ASTNode).init(alloc);
        defer stack.deinit();

        var result = ArrayList(*ASTNode).init(alloc);

        for (vals.*.items) |node| {
            if (node.*.children.items.len > 0) {
                var array = node.*.children;
                node.*.children = convertToAST(&array, alloc) catch |err| {
                    for (result.items) |item| {
                        const curAlloc = item.*.alloc;
                        item.*.deinit();
                        curAlloc.destroy(item);
                    }
                    result.deinit();
                    return err;
                };
                for (node.*.children.items) |item| {
                    item.*.parent = node;
                }
                array.deinit();
            }

            if (node.*.kind) |nodeKind| {
                if (!nodeKind.isOperator()) {
                    result.append(node) catch |err| {
                        for (result.items) |item| {
                            const curAlloc = item.*.alloc;
                            item.*.deinit();
                            curAlloc.destroy(item);
                        }
                        result.deinit();
                        return err;
                    };
                    continue;
                }

                const operatorProps = nodeKind.props.operator;
                const priority = operatorProps.opPriority;
                while (stack.items.len > 0 and
                    hasLowerPriority(priority, stack.getLast()))
                {
                    const curNode: *ASTNode = stack.pop();
                    popIntoOperator(&result, curNode) catch |err| {
                        for (result.items) |item| {
                            const curAlloc = item.*.alloc;
                            item.*.deinit();
                            curAlloc.destroy(item);
                        }
                        result.deinit();
                        return err;
                    };
                    result.append(curNode) catch |err| {
                        for (result.items) |item| {
                            const curAlloc = item.*.alloc;
                            item.*.deinit();
                            curAlloc.destroy(item);
                        }
                        result.deinit();
                        return err;
                    };
                }
                stack.append(node) catch |err| {
                    for (result.items) |item| {
                        const curAlloc = item.*.alloc;
                        item.*.deinit();
                        curAlloc.destroy(item);
                    }
                    result.deinit();
                    return err;
                };

                continue;
            }

            result.append(node) catch |err| {
                for (result.items) |item| {
                    const curAlloc = item.*.alloc;
                    item.*.deinit();
                    curAlloc.destroy(item);
                }
                result.deinit();
                return err;
            };
        }

        while (stack.items.len > 0) {
            const curNode: *ASTNode = stack.pop();
            popIntoOperator(&result, curNode) catch |err| {
                for (result.items) |item| {
                    const curAlloc = item.*.alloc;
                    item.*.deinit();
                   curAlloc.destroy(item);
                }
                result.deinit();
                return err;
            };

            result.append(curNode) catch |err| {
                for (result.items) |item| {
                    const curAlloc = item.*.alloc;
                    item.*.deinit();
                    curAlloc.destroy(item);
                }
                result.deinit();
                return err;
            };
        }

        return result;
    }
};
