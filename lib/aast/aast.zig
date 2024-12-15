const std = @import("std");
const StringHashMap = std.StringHashMap;
const ArrayList = std.ArrayList;
const testing = std.testing;

pub fn ASTNode(comptime NodeTypeEnum: type, comptime ValueType: type) type {
    return struct {
        const Self = @This();

        parent: ?*Self,
        kind: ?NodeTypeEnum,
        value: ?ValueType,
        children: ArrayList(?*Self),
    };
}

// pub fn AST(comptime NodeTypeEnum: type, comptime ValueType: type, comptime typeMap: StringHashMap(NodeTypeEnum), comptime delims: std.ArrayList([]const u8)) type {
pub fn AST(comptime NodeTypeEnum: type, comptime ValueType: type) type {
    return struct {
        const Self = @This();

        root: ASTNode(NodeTypeEnum, ValueType),

        // pub fn construct(string: []const u8) Self {}
    };
}

test "basic add functionality" {}
