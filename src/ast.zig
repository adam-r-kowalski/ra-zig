const std = @import("std");
const list = @import("list.zig");
const List = list.List;
const table = @import("table.zig");
const Table = table.Table;

pub const EntityId = table.Id("ast entities");

pub const Kind = enum(u8) {
    Int,
    Symbol,
    Keyword,
    Parens,
    Brackets,
};

const Entities =
    Table(.{
    .name = "ast entities",
    .columns = struct {
        kind: Kind,
        foreign_id: usize,
    },
});

pub const Ast = struct {
    entities: Entities,
    children: List([]const EntityId),
    top_level: List(EntityId),
};

pub fn init(allocator: *std.mem.Allocator) Ast {
    return .{
        .entities = Entities.init(allocator),
        .children = List([]const EntityId).init(allocator),
        .top_level = List(EntityId).init(allocator),
    };
}
