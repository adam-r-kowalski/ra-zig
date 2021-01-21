const std = @import("std");
const Allocator = std.mem.Allocator;
const TypeInfo = std.builtin.TypeInfo;
const StructField = TypeInfo.StructField;
const Declaration = TypeInfo.Declaration;

fn Data(comptime fields: []const StructField) type {
    var new_fields: [fields.len]StructField = undefined;
    for (fields) |field, i| {
        const default_value: []field.field_type = &[_]field.field_type{};
        new_fields[i] = StructField{
            .name = field.name,
            .field_type = []field.field_type,
            .default_value = default_value,
            .is_comptime = field.is_comptime,
            .alignment = field.alignment,
        };
    }
    return @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &new_fields,
            .decls = &[_]Declaration{},
            .is_tuple = false,
        },
    });
}

pub fn Id(comptime name: []const u8) type {
    return struct {
        index: usize,
    };
}

const Config = struct {
    name: []const u8,
    columns: type,
    unique: []const []const u8 = &[_][]const u8{},
};

pub fn Table(comptime config: Config) type {
    const fields = @typeInfo(config.columns).Struct.fields;
    const DataT = Data(fields);
    const IdT = Id(config.name);
    var field_names: [fields.len][]const u8 = undefined;
    var field_types: [fields.len]type = undefined;
    inline for (fields) |field, i| {
        field_names[i] = field.name;
        field_types[i] = field.field_type;
    }
    return struct {
        data: DataT,
        rows: usize,
        capacity: usize,
        allocator: *Allocator,

        const Self = @This();

        pub fn init(allocator: *Allocator) Self {
            return Self{
                .data = DataT{},
                .rows = 0,
                .capacity = 0,
                .allocator = allocator,
            };
        }

        fn ensureCapacity(self: *Self) !void {
            if (self.rows < self.capacity)
                return;
            const capacity = std.math.max(32, self.capacity * 2);
            inline for (field_names) |name, i| {
                const data = try self.allocator.alloc(field_types[i], capacity);
                for (@field(self.data, name)) |e, j| data[j] = e;
                self.allocator.free(@field(self.data, name));
                @field(self.data, name) = data;
            }
            self.capacity = capacity;
        }

        pub fn insert(self: *Self, row: config.columns) !IdT {
            comptime if (config.unique.len > 0)
                @compileError("Cannot insert a row when a table has a unique column");
            try self.ensureCapacity();
            const rows = self.rows;
            inline for (field_names) |name, i|
                @field(self.data, name)[rows] = @field(row, name);
            self.rows += 1;
            return IdT{ .index = rows };
        }

        pub fn lookup(self: Self, id: IdT) config.columns {
            var row: config.columns = undefined;
            inline for (field_names) |name|
                @field(row, name) = @field(self.data, name)[id.index];
            return row;
        }
    };
}
