const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;
const Database = @import("lang").Database;

const Name = struct {
    value: []const u8,
};

const Age = struct {
    value: usize,
};

test "create database, create entities, read, and write components" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var people = try Database(.{ .components = &.{ Name, Age } }).init(allocator);
    defer people.deinit();
    const joe = people.createEntity();
    (try people.write(joe, Name)).value = "joe";
    (try people.write(joe, Age)).value = 20;
    expectEqualStrings(people.read(joe, Name).value, "joe");
    expectEqual(people.read(joe, Age).value, 20);
}

test "read and write component groups" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var people = try Database(.{ .components = &.{ Name, Age } }).init(allocator);
    defer people.deinit();
    const joe = people.createEntity();
    const write = try people.writeGroup(joe, &.{ Name, Age });
    write.Name.value = "joe";
    write.Age.value = 20;
    const read = people.readGroup(joe, &.{ Name, Age });
    expectEqualStrings(read.Name.value, "joe");
    expectEqual(read.Age.value, 20);
}

test "iterate components" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer expect(!gpa.deinit());
    const allocator = &gpa.allocator;
    var people = try Database(.{ .components = &.{ Name, Age } }).init(allocator);
    defer people.deinit();
    {
        const joe = people.createEntity();
        const write = try people.writeGroup(joe, &.{ Name, Age });
        write.Name.value = "joe";
        write.Age.value = 20;
    }
    {
        const sally = people.createEntity();
        const write = try people.writeGroup(sally, &.{ Name, Age });
        write.Name.value = "sally";
        write.Age.value = 24;
    }
    {
        const bob = people.createEntity();
        (try people.write(bob, Name)).value = "bob";
    }
    var iterator = people.readIterator(Age);
    {
        const entry = iterator.next().?;
        expectEqual(entry.data.value, 20);
        expectEqualStrings(people.read(entry.entity, Name).value, "joe");
    }
    {
        const entry = iterator.next().?;
        expectEqual(entry.data.value, 24);
        expectEqualStrings(people.read(entry.entity, Name).value, "sally");
    }
    expectEqual(iterator.next(), null);
}
